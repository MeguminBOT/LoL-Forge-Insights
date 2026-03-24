package tools;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import forge.data.*;
import forge.rules.*;

/**
 * Generates static JSON files per champion with profile + synergy data.
 *
 * Usage (after building):
 *   haxe build-generate.hxml
 *   ./build/generate/Main   (or Main.exe on Windows)
 *
 * Output: build/champion-data/<ChampionKey>.json
 *
 * Each JSON file contains:
 *   {
 *     "id": "...",
 *     "name": "...",
 *     "profile": { ... },
 *     "items": {
 *       "<itemId>": { "score": N, "tier": "...", "reasons": [...] },
 *       ...
 *     }
 *   }
 */
class GenerateChampionData {
	static var dataRoot = "data";
	static var outDir = "build/champion-data";

	public static function main():Void {
		trace("=== Forge Insight — Static Champion Data Generator ===");

		// Load raw data
		var champRaw = loadJson('$dataRoot/meraki-champions.json');
		var itemRaw = loadJson('$dataRoot/meraki-items.json');
		if (champRaw == null || itemRaw == null) {
			trace("ERROR: Could not load data files. Run: node scripts/fetch-data.js");
			return;
		}

		// Parse items
		var items = new Map<String, ItemData>();
		for (key in Reflect.fields(itemRaw)) {
			var item:Dynamic = Reflect.field(itemRaw, key);
			if (item.removed == true)
				continue;
			var id = Std.string(item.id);
			var parsed = MerakiConverter.parseItem(item);
			// Only include purchasable finished items
			if (parsed.gold != null && parsed.gold.purchasable && parsed.gold.total >= 300) {
				if (parsed.into == null || parsed.into.length == 0) {
					if (parsed.requiredAlly == null || parsed.requiredAlly == "") {
						if (parsed.requiredChampion == null || parsed.requiredChampion == "") {
							items.set(id, parsed);
						}
					}
				}
			}
		}

		var itemCount = 0;
		for (_ in items.keys())
			itemCount++;
		trace('Loaded $itemCount finished items');

		// Load overrides
		var overrides:Dynamic = null;
		var overridePath = '$dataRoot/overrides.json';
		if (FileSystem.exists(overridePath)) {
			overrides = loadJson(overridePath);
			trace("Loaded overrides.json");
		}

		// Create output directory
		mkdirp(outDir);

		// Process each champion
		var champCount = 0;
		var champKeys:Array<String> = Reflect.fields(champRaw);
		for (key in champKeys) {
			var c:Dynamic = Reflect.field(champRaw, key);
			if (c == null)
				continue;

			var detail = MerakiConverter.parseChampion(c);
			var profile = ProfileBuilder.build(detail);

			// Compute synergies for all items
			var champOverrides:Dynamic = null;
			if (overrides != null)
				champOverrides = Reflect.field(overrides, detail.id);

			var itemSynergies:Dynamic = {};
			for (id => item in items) {
				var iprof = ItemClassifier.classify(id, item);
				var result = SynergyEngine.score(profile, iprof);

				// Apply overrides
				if (champOverrides != null) {
					var ov:Dynamic = Reflect.field(champOverrides, id);
					if (ov != null) {
						var tierStr:String = Reflect.field(ov, "tier");
						var reason:String = Reflect.field(ov, "reason");
						var overrideTier = parseTier(tierStr);
						if (overrideTier != null) {
							result.tier = overrideTier;
							result.score = tierToScore(overrideTier);
							result.reasons = reason != null ? ["[Override] " + reason] : ["[Manual override]"];
						}
					}
				}

				Reflect.setField(itemSynergies, id, {
					score: result.score,
					tier: tierName(result.tier),
					reasons: result.reasons,
				});
			}

			// Build champion profile summary for output
			var profileOut:Dynamic = {
				primaryDamage: dmgName(profile.primaryDamage),
				hasApScaling: profile.hasApScaling,
				hasAdScaling: profile.hasAdScaling,
				hasOnHit: profile.hasOnHit,
				hasAutoResets: profile.hasAutoResets,
				hasCritSynergy: profile.hasCritSynergy,
				hasDoT: profile.hasDoT,
				hasDash: profile.hasDash,
				hasShield: profile.hasShield,
				hasHeal: profile.hasHeal,
				hasCc: profile.hasCc,
				hasExecute: profile.hasExecute,
				hasStealth: profile.hasStealth,
				isManaless: profile.isManaless,
				resource: resName(profile.resource),
				range: rangeName(profile.range),
				tags: profile.tags,
			};

			var championData:Dynamic = {
				id: detail.id,
				name: detail.name,
				profile: profileOut,
				items: itemSynergies,
			};

			var json = Json.stringify(championData, null, "  ");
			File.saveContent('$outDir/${detail.id}.json', json);
			champCount++;
		}

		trace('Generated $champCount champion JSON files in $outDir/');

		// Also generate an index file listing all champions
		var index:Array<Dynamic> = [];
		for (key in champKeys) {
			var c:Dynamic = Reflect.field(champRaw, key);
			if (c == null)
				continue;
			var champKey:String = c.key;
			index.push({
				id: champKey,
				name: c.name,
			});
		}
		index.sort(function(a:Dynamic, b:Dynamic) {
			var na:String = a.name;
			var nb:String = b.name;
			return na < nb ? -1 : na > nb ? 1 : 0;
		});
		File.saveContent('$outDir/_index.json', Json.stringify(index, null, "  "));
		trace('Generated _index.json with ${index.length} entries');
	}

	// ── Helpers ──────────────────────────────────────────────────────────────

	static function loadJson(path:String):Dynamic {
		if (!FileSystem.exists(path)) {
			trace('File not found: $path');
			return null;
		}
		return Json.parse(File.getContent(path));
	}

	static function mkdirp(path:String):Void {
		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);
	}

	static function tierName(t:SynergyTier):String {
		return switch t {
			case Core: "Core";
			case Good: "Good";
			case Situational: "Situational";
			case Weak: "Weak";
			case Trap: "Trap";
		};
	}

	static function dmgName(d:DamageType):String {
		return switch d {
			case Physical: "Physical";
			case Magic: "Magic";
			case Hybrid: "Hybrid";
		};
	}

	static function resName(r:ResourceType):String {
		return switch r {
			case Mana: "Mana";
			case Energy: "Energy";
			case Manaless: "Manaless";
		};
	}

	static function rangeName(r:RangeType):String {
		return switch r {
			case Melee: "Melee";
			case Short: "Short";
			case Ranged: "Ranged";
		};
	}

	static function parseTier(s:String):Null<SynergyTier> {
		if (s == null)
			return null;
		return switch (s.toLowerCase()) {
			case "core": Core;
			case "good": Good;
			case "situational": Situational;
			case "weak": Weak;
			case "trap": Trap;
			default: null;
		};
	}

	static function tierToScore(t:SynergyTier):Int {
		return switch t {
			case Core: 9;
			case Good: 7;
			case Situational: 5;
			case Weak: 3;
			case Trap: 1;
		};
	}
}
#end
