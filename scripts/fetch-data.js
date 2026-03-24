#!/usr/bin/env node
/**
 * fetch-data.js
 * Downloads Meraki Analytics data + DDragon images for offline use.
 *
 * Usage:
 *   node scripts/fetch-data.js
 *
 * Output goes into:  data/
 */

const https = require("https");
const http = require("http");
const fs = require("fs");
const path = require("path");
const url = require("url");

const DDRAGON = "https://ddragon.leagueoflegends.com";
const MERAKI =
	"https://cdn.merakianalytics.com/riot/lol/resources/latest/en-US";
const DATA_DIR = path.join(__dirname, "..", "data");
const ASSETS_IMG = path.join(__dirname, "..", "assets", "img");

// ── Helpers ──────────────────────────────────────────────────────────────────

function mkdir(p) {
	if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true });
}

function fetchText(targetUrl) {
	return new Promise((resolve, reject) => {
		const parsed = url.parse(targetUrl);
		const mod = parsed.protocol === "https:" ? https : http;
		mod.get(targetUrl, { timeout: 30000 }, (res) => {
			if (
				res.statusCode >= 300 &&
				res.statusCode < 400 &&
				res.headers.location
			) {
				return fetchText(res.headers.location)
					.then(resolve)
					.catch(reject);
			}
			let data = "";
			res.setEncoding("utf8");
			res.on("data", (chunk) => (data += chunk));
			res.on("end", () => resolve(data));
		})
			.on("error", reject)
			.on("timeout", () => reject(new Error("timeout: " + targetUrl)));
	});
}

function fetchBinary(targetUrl, dest) {
	if (fs.existsSync(dest)) return Promise.resolve();
	return new Promise((resolve, reject) => {
		const parsed = url.parse(targetUrl);
		const mod = parsed.protocol === "https:" ? https : http;
		mod.get(targetUrl, { timeout: 15000 }, (res) => {
			if (
				res.statusCode >= 300 &&
				res.statusCode < 400 &&
				res.headers.location
			) {
				return fetchBinary(res.headers.location, dest)
					.then(resolve)
					.catch(reject);
			}
			if (res.statusCode !== 200) {
				res.resume();
				return reject(
					new Error(`HTTP ${res.statusCode} for ${targetUrl}`),
				);
			}
			const tmp = dest + ".tmp";
			const file = fs.createWriteStream(tmp);
			res.pipe(file);
			file.on("finish", () => {
				file.close();
				fs.renameSync(tmp, dest);
				resolve();
			});
		})
			.on("error", reject)
			.on("timeout", () => reject(new Error("timeout: " + targetUrl)));
	});
}

async function fetchJson(targetUrl) {
	const text = await fetchText(targetUrl);
	return JSON.parse(text);
}

async function downloadPool(tasks, concurrency = 10) {
	let idx = 0;
	async function worker() {
		while (idx < tasks.length) {
			const task = tasks[idx++];
			try {
				await task();
			} catch (e) {
				console.error("  warning: " + e.message);
			}
		}
	}
	await Promise.all(Array.from({ length: concurrency }, () => worker()));
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
	mkdir(DATA_DIR);

	// 1. DDragon version (for image URLs)
	console.log("Fetching latest version...");
	const versions = await fetchJson(`${DDRAGON}/api/versions.json`);
	const version = versions[0];
	console.log(`  Version: ${version}`);
	fs.writeFileSync(path.join(DATA_DIR, "version.txt"), version);

	// 2. Meraki champions
	console.log("Downloading Meraki champions data...");
	const champText = await fetchText(`${MERAKI}/champions.json`);
	fs.writeFileSync(path.join(DATA_DIR, "meraki-champions.json"), champText);
	const champData = JSON.parse(champText);
	const champKeys = Object.keys(champData);
	console.log(`  ${champKeys.length} champions`);

	// 3. Meraki items
	console.log("Downloading Meraki items data...");
	const itemText = await fetchText(`${MERAKI}/items.json`);
	fs.writeFileSync(path.join(DATA_DIR, "meraki-items.json"), itemText);
	const itemData = JSON.parse(itemText);
	const itemKeys = Object.keys(itemData);
	console.log(`  ${itemKeys.length} items`);

	// 4. Champion images (from DDragon) -> assets/img/champion/
	console.log("Downloading champion images...");
	mkdir(path.join(ASSETS_IMG, "champion"));
	const champImgTasks = champKeys.map((key) => {
		const filename = key + ".png";
		return async () => {
			const dest = path.join(ASSETS_IMG, "champion", filename);
			await fetchBinary(
				`${DDRAGON}/cdn/${version}/img/champion/${filename}`,
				dest,
			);
			process.stdout.write(".");
		};
	});
	await downloadPool(champImgTasks, 12);
	console.log("\n  Done.");

	// 5. Item images (from DDragon) -> assets/img/item/
	console.log("Downloading item images...");
	mkdir(path.join(ASSETS_IMG, "item"));
	const itemImgTasks = itemKeys.map((key) => {
		const item = itemData[key];
		const id = item.id;
		const filename = id + ".png";
		return async () => {
			const dest = path.join(ASSETS_IMG, "item", filename);
			await fetchBinary(
				`${DDRAGON}/cdn/${version}/img/item/${filename}`,
				dest,
			);
			process.stdout.write(".");
		};
	});
	await downloadPool(itemImgTasks, 12);
	console.log("\n  Done.");

	// 5b. Spell images (from DDragon) -> assets/img/spell/
	console.log("Downloading spell images...");
	mkdir(path.join(ASSETS_IMG, "spell"));
	const spellUrl = `${DDRAGON}/cdn/${version}/data/en_US/champion.json`;
	const ddragonChamps = await fetchJson(spellUrl);
	const spellFilenames = new Set();
	for (const [, champ] of Object.entries(ddragonChamps.data)) {
		for (const spell of champ.spells || []) {
			if (spell.image && spell.image.full) spellFilenames.add(spell.image.full);
		}
		if (champ.passive && champ.passive.image && champ.passive.image.full) {
			spellFilenames.add(champ.passive.image.full);
		}
	}
	const spellImgTasks = [...spellFilenames].map((filename) => {
		return async () => {
			const dest = path.join(ASSETS_IMG, "spell", filename);
			await fetchBinary(
				`${DDRAGON}/cdn/${version}/img/spell/${filename}`,
				dest,
			);
			process.stdout.write(".");
		};
	});
	await downloadPool(spellImgTasks, 12);
	console.log("\n  Done.");

	// 5c. Passive images (from DDragon) -> assets/img/passive/
	console.log("Downloading passive images...");
	mkdir(path.join(ASSETS_IMG, "passive"));
	const passiveFilenames = new Set();
	for (const [, champ] of Object.entries(ddragonChamps.data)) {
		if (champ.passive && champ.passive.image && champ.passive.image.full) {
			passiveFilenames.add(champ.passive.image.full);
		}
	}
	const passiveImgTasks = [...passiveFilenames].map((filename) => {
		return async () => {
			const dest = path.join(ASSETS_IMG, "passive", filename);
			await fetchBinary(
				`${DDRAGON}/cdn/${version}/img/passive/${filename}`,
				dest,
			);
			process.stdout.write(".");
		};
	});
	await downloadPool(passiveImgTasks, 12);
	console.log("\n  Done.");

	// 6. Generate meraki-data.js for browser (embeds data as JS globals)
	const browserDataDir = path.join(
		__dirname,
		"..",
		"build",
		"browser",
		"data",
	);
	mkdir(browserDataDir);
	fs.copyFileSync(
		path.join(DATA_DIR, "meraki-champions.json"),
		path.join(browserDataDir, "meraki-champions.json"),
	);
	fs.copyFileSync(
		path.join(DATA_DIR, "meraki-items.json"),
		path.join(browserDataDir, "meraki-items.json"),
	);
	fs.copyFileSync(
		path.join(DATA_DIR, "version.txt"),
		path.join(browserDataDir, "version.txt"),
	);

	const dataJs = `window.__MERAKI_VERSION__=${JSON.stringify(version)};\nwindow.__MERAKI_CHAMPIONS__=${champText};\nwindow.__MERAKI_ITEMS__=${itemText};\n`;
	// Append overrides if the combined overrides.json exists
	const overridesPath = path.join(DATA_DIR, "overrides.json");
	const overridesSnippet =
		fs.existsSync(overridesPath) ?
			`window.__MERAKI_OVERRIDES__=${fs.readFileSync(overridesPath, "utf8")};\n`
		:	"";
	fs.writeFileSync(
		path.join(browserDataDir, "meraki-data.js"),
		dataJs + overridesSnippet,
	);
	console.log("Generated build/browser/data/meraki-data.js");

	console.log(`\nAll data saved to ${DATA_DIR}/`);
	console.log(`  Version:   ${version}`);
	console.log(`  Champions: ${champKeys.length}`);
	console.log(`  Items:     ${itemKeys.length}`);
}

main().catch((e) => {
	console.error("Fatal:", e);
	process.exit(1);
});
