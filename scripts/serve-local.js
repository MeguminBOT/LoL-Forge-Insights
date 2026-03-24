#!/usr/bin/env node
/**
 * serve-local.js
 * A tiny static HTTP server for offline use.
 * Injects window.__OFFLINE__ = true into index.html so
 * the Haxe app switches to the OfflineDataProvider path.
 *
 * Usage:
 *   node scripts/serve-local.js [port]
 *
 * Then open http://localhost:3000 in your browser.
 */

const http = require("http");
const fs = require("fs");
const path = require("path");
const url = require("url");

const ROOT = path.join(__dirname, "..");
const PORT = parseInt(process.argv[2] || "3000", 10);

const MIME = {
	".html": "text/html; charset=utf-8",
	".js": "application/javascript",
	".css": "text/css",
	".json": "application/json",
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".gif": "image/gif",
	".webp": "image/webp",
	".ico": "image/x-icon",
	".svg": "image/svg+xml",
	".woff": "font/woff",
	".woff2": "font/woff2",
	".ttf": "font/ttf",
};

const server = http.createServer((req, res) => {
	const parsed = url.parse(req.url);
	let filePath = path.join(
		ROOT,
		parsed.pathname === "/" ? "assets/index.html" : parsed.pathname,
	);
	const ext = path.extname(filePath).toLowerCase();

	// Security: prevent path traversal
	if (!filePath.startsWith(ROOT)) {
		res.writeHead(403);
		res.end("Forbidden");
		return;
	}

	fs.stat(filePath, (err, stat) => {
		if (err || stat.isDirectory()) {
			// Try index.html for directory
			filePath = path.join(filePath, "index.html");
		}

		fs.readFile(filePath, (err2, data) => {
			if (err2) {
				res.writeHead(404, { "Content-Type": "text/plain" });
				res.end("Not found: " + parsed.pathname);
				return;
			}

			const mime =
				MIME[path.extname(filePath).toLowerCase()] ||
				"application/octet-stream";
			res.writeHead(200, {
				"Content-Type": mime,
				"Cache-Control": "no-cache",
			});

			// Inject offline flag into index.html
			if (
				path.extname(filePath) === ".html" &&
				filePath.endsWith("index.html")
			) {
				let html = data.toString("utf8");
				const injection = `<script>
  window.__OFFLINE__ = true;
  window.__DATA_ROOT__ = 'data';
</script>`;
				// Insert just before closing </head>
				html = html.replace("</head>", injection + "\n</head>");
				res.end(html, "utf8");
			} else {
				res.end(data);
			}
		});
	});
});

server.listen(PORT, "127.0.0.1", () => {
	console.log(`\n⚔  Forge Insight — Offline Mode`);
	console.log(`   Server: http://localhost:${PORT}`);
	console.log(`   Data:   ${path.join(ROOT, "data")}`);
	console.log(`\n   Make sure you have run: node scripts/fetch-data.js`);
	console.log(`   Press Ctrl+C to stop.\n`);
});
