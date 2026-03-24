package forge.data;

/**
 * Converts raw Meraki Analytics JSON (Dynamic) into typed data structures.
 * Shared between Browser and Offline data providers.
 */
class MerakiConverter {
	public static function parseChampion(c:Dynamic):ChampionDetail {
		var champKey:String = c.key;
		var abilities:Dynamic = c.abilities;

		// Build spells from Q/W/E/R
		var spells:Array<ChampionSpell> = [];
		for (slot in ["Q", "W", "E", "R"]) {
			var slotAbs:Array<Dynamic> = Reflect.field(abilities, slot);
			if (slotAbs == null || slotAbs.length == 0) {
				spells.push({
					id: slot,
					name: slot,
					description: "",
					tooltip: "",
					maxrank: 5,
					costType: "",
					datavalues: null,
					effect: [],
					vars: []
				});
				continue;
			}
			var ab:Dynamic = slotAbs[0];
			spells.push({
				id: slot,
				name: ab.name != null ? ab.name : slot,
				description: collectEffectText(ab.effects),
				tooltip: "",
				maxrank: 5,
				costType: "",
				datavalues: null,
				effect: [],
				vars: []
			});
		}

		// Passive
		var passiveName = "";
		var passiveDesc = "";
		var pSlot:Array<Dynamic> = Reflect.field(abilities, "P");
		if (pSlot != null && pSlot.length > 0) {
			var p:Dynamic = pSlot[0];
			passiveName = p.name != null ? p.name : "";
			passiveDesc = collectEffectText(p.effects);
		}

		// AP / AD scaling from ability modifiers
		var hasAp = false;
		var hasAd = false;
		var apCount = 0;
		var adCount = 0;
		if (abilities != null) {
			for (slot in ["P", "Q", "W", "E", "R"]) {
				var abs:Array<Dynamic> = Reflect.field(abilities, slot);
				if (abs == null)
					continue;
				for (ab in abs) {
					var effects:Array<Dynamic> = ab.effects;
					if (effects == null)
						continue;
					for (eff in effects) {
						var leveling:Array<Dynamic> = eff.leveling;
						if (leveling == null)
							continue;
						for (lev in leveling) {
							var modifiers:Array<Dynamic> = lev.modifiers;
							if (modifiers == null)
								continue;
							for (mod in modifiers) {
								var units:Array<String> = mod.units;
								if (units == null)
									continue;
								for (unit in units) {
									if (unit == null)
										continue;
									var u = unit.toLowerCase();
									if (u.indexOf("ap") >= 0) {
										hasAp = true;
										apCount++;
									}
									if (u.indexOf("ad") >= 0) {
										hasAd = true;
										adCount++;
									}
								}
							}
						}
					}
				}
			}
		}

		// Champion stats
		var ms:Dynamic = c.stats;
		var stats:ChampionStats = {
			hp: sFlat(ms, "health"),
			hpperlevel: sPL(ms, "health"),
			mp: sFlat(ms, "mana"),
			mpperlevel: sPL(ms, "mana"),
			movespeed: sFlat(ms, "movespeed"),
			armor: sFlat(ms, "armor"),
			armorperlevel: sPL(ms, "armor"),
			spellblock: sFlat(ms, "magicResistance"),
			spellblockperlevel: sPL(ms, "magicResistance"),
			attackrange: sFlat(ms, "attackRange"),
			hpregen: sFlat(ms, "healthRegen"),
			hpregenperlevel: sPL(ms, "healthRegen"),
			mpregen: sFlat(ms, "manaRegen"),
			mpregenperlevel: sPL(ms, "manaRegen"),
			crit: 0.0,
			critperlevel: 0.0,
			attackdamage: sFlat(ms, "attackDamage"),
			attackdamageperlevel: sPL(ms, "attackDamage"),
			attackspeedperlevel: sPL(ms, "attackSpeed"),
			attackspeed: sFlat(ms, "attackSpeed"),
		};

		// Info from attributeRatings
		var ar:Dynamic = c.attributeRatings;
		var damage:Int = ar != null && ar.damage != null ? ar.damage : 3;
		var toughness:Int = ar != null && ar.toughness != null ? ar.toughness : 3;
		var difficulty:Int = ar != null && ar.difficulty != null ? ar.difficulty : 2;
		var adaptiveType:String = c.adaptiveType != null ? c.adaptiveType : "";
		var magicRating = if (adaptiveType == "MAGIC_DAMAGE") 7 else if (hasAp) 5 else 2;

		return {
			id: champKey,
			name: c.name,
			title: c.title != null ? c.title : "",
			image: {full: champKey + ".png", sprite: "", group: ""},
			tags: rolesToTags(c.roles),
			partype: resourceToPartype(c.resource),
			stats: stats,
			passive: {
				name: passiveName,
				description: passiveDesc,
				image: {full: "", sprite: "", group: ""}
			},
			spells: spells,
			info: {
				attack: Std.int(Math.min(10, damage * 2)),
				defense: Std.int(Math.min(10, toughness * 2)),
				magic: magicRating,
				difficulty: Std.int(Math.min(10, difficulty * 2)),
			},
			lore: c.lore != null ? c.lore : "",
			hasApScaling: hasAp,
			hasAdScaling: hasAd,
			adaptiveType: c.adaptiveType != null ? c.adaptiveType : "",
			apModifierCount: apCount,
			adModifierCount: adCount,
			merakiRoles: rawRoles(c.roles),
		};
	}

	public static function parseItem(item:Dynamic):ItemData {
		var shop:Dynamic = item.shop;
		var prices:Dynamic = shop != null ? shop.prices : null;

		// Description from passives + active text
		// Prefer passives/active effects over simpleDescription (which is often wrong)
		var descParts:Array<String> = [];
		var hasEffects = false;
		var passives:Array<Dynamic> = item.passives;
		if (passives != null)
			for (p in passives)
				if (p.effects != null && p.effects != "") {
					var label = p.name != null && p.name != "" ? p.name + ": " : "";
					descParts.push(label + p.effects);
					hasEffects = true;
				}
		var active:Array<Dynamic> = item.active;
		if (active != null)
			for (a in active)
				if (a.effects != null && a.effects != "") {
					var label = a.name != null && a.name != "" ? a.name + ": " : "";
					descParts.push(label + a.effects);
					hasEffects = true;
				}
		// Only fall back to simpleDescription when no passive/active effects exist
		if (!hasEffects && item.simpleDescription != null && item.simpleDescription != "")
			descParts.push(item.simpleDescription);
		var desc = stripWikiMarkup(descParts.join(" "));

		// Tags from rank + shop.tags
		var tags:Array<String> = [];
		var rank:Array<Dynamic> = item.rank;
		if (rank != null)
			for (r in rank)
				if (Std.string(r) == "BOOTS")
					tags.push("Boots");
		var shopTags:Array<Dynamic> = shop != null ? shop.tags : null;
		if (shopTags != null)
			for (st in shopTags)
				tags.push(Std.string(st));

		// buildsFrom / buildsInto  (int[] → String[])
		var from:Array<String> = intArrToStr(item.buildsFrom);
		var into:Array<String> = intArrToStr(item.buildsInto);

		return {
			name: item.name,
			description: desc,
			image: {full: Std.string(item.id) + ".png", sprite: "", group: ""},
			gold: {
				base: prices != null && prices.combined != null ? prices.combined : 0,
				total: prices != null && prices.total != null ? prices.total : 0,
				sell: prices != null && prices.sell != null ? prices.sell : 0,
				purchasable: shop != null && shop.purchasable == true,
			},
			tags: tags,
			maps: null,
			stats: item.stats,
			from: from,
			into: into,
			depth: item.tier,
			consumed: false,
			inStore: shop != null && shop.purchasable == true,
			hideFromAll: item.removed == true,
			requiredChampion: item.requiredChampion,
			requiredAlly: item.requiredAlly,
			effect: null,
			merakiTags: merakiShopTags(shop),
		};
	}

	// ── Helpers ──────────────────────────────────────────────────────────────

	public static function rawRoles(roles:Dynamic):Array<String> {
		var result:Array<String> = [];
		var arr:Array<Dynamic> = roles;
		if (arr == null)
			return result;
		for (role in arr)
			result.push(Std.string(role));
		return result;
	}

	static function merakiShopTags(shop:Dynamic):Array<String> {
		var result:Array<String> = [];
		if (shop == null)
			return result;
		var tags:Array<Dynamic> = shop.tags;
		if (tags == null)
			return result;
		for (t in tags)
			result.push(Std.string(t));
		return result;
	}

	public static function rolesToTags(roles:Dynamic):Array<String> {
		var tags:Array<String> = [];
		var arr:Array<Dynamic> = roles;
		if (arr == null)
			return tags;
		for (role in arr) {
			var tag = switch Std.string(role) {
				case "FIGHTER" | "JUGGERNAUT" | "SKIRMISHER" | "DIVER": "Fighter";
				case "MAGE" | "BURST" | "BATTLEMAGE" | "ARTILLERY": "Mage";
				case "MARKSMAN": "Marksman";
				case "ASSASSIN": "Assassin";
				case "TANK" | "VANGUARD" | "WARDEN": "Tank";
				case "SUPPORT" | "ENCHANTER" | "CATCHER": "Support";
				case _: null;
			};
			if (tag != null && tags.indexOf(tag) < 0)
				tags.push(tag);
		}
		return tags;
	}

	public static function resourceToPartype(resource:Dynamic):String {
		return switch Std.string(resource).toUpperCase() {
			case "MANA": "Mana";
			case "ENERGY": "Energy";
			case _: "None";
		};
	}

	static function sFlat(stats:Dynamic, key:String):Float {
		if (stats == null)
			return 0.0;
		var sub:Dynamic = Reflect.field(stats, key);
		if (sub == null)
			return 0.0;
		var f:Dynamic = Reflect.field(sub, "flat");
		return f != null ? f : 0.0;
	}

	static function sPL(stats:Dynamic, key:String):Float {
		if (stats == null)
			return 0.0;
		var sub:Dynamic = Reflect.field(stats, key);
		if (sub == null)
			return 0.0;
		var f:Dynamic = Reflect.field(sub, "perLevel");
		return f != null ? f : 0.0;
	}

	static function collectEffectText(effects:Dynamic):String {
		var parts:Array<String> = [];
		var arr:Array<Dynamic> = effects;
		if (arr == null)
			return "";
		for (eff in arr) {
			if (eff.description != null)
				parts.push(eff.description);
		}
		return parts.join(" ");
	}

	static function intArrToStr(arr:Dynamic):Array<String> {
		var raw:Array<Dynamic> = arr;
		if (raw == null || raw.length == 0)
			return null;
		var out:Array<String> = [];
		for (v in raw)
			out.push(Std.string(v));
		return out;
	}

	/**
	 * Strip Meraki wiki-style markup from item descriptions.
	 *   {{as|content}}  → content  (stat-colour template)
	 *   {{rd|val|…}}    → val      (range-by-level, keep first value)
	 *   {{tip|text}}    → text     (tooltip ref)
	 *   [[Page|display]] → display (wiki link)
	 *   [[Page]]         → Page
	 *   '''bold'''       → bold
	 *   ''italic''       → italic
	 */
	static function stripWikiMarkup(text:String):String {
		if (text == null || text == "")
			return "";

		// Iteratively strip innermost {{template|content}} (handles nesting)
		var innerTemplate = ~/\{\{([^{}]+)\}\}/;
		var safety = 0;
		while (safety < 30 && innerTemplate.match(text)) {
			safety++;
			var inner = innerTemplate.matched(1);
			var pipeIdx = inner.indexOf("|");
			var replacement:String;
			if (pipeIdx < 0) {
				replacement = inner;
			} else {
				// Content after first pipe; for multi-pipe templates keep only first segment
				var content = inner.substr(pipeIdx + 1);
				var nextPipe = content.indexOf("|");
				replacement = nextPipe >= 0 ? content.substr(0, nextPipe) : content;
			}
			text = innerTemplate.matchedLeft() + replacement + innerTemplate.matchedRight();
		}

		// Wiki links: [[page|display]] or [[page]]
		var wikiLink = ~/\[\[([^\]]+)\]\]/;
		safety = 0;
		while (safety < 50 && wikiLink.match(text)) {
			safety++;
			var inner = wikiLink.matched(1);
			var pipeIdx = inner.indexOf("|");
			var display = pipeIdx >= 0 ? inner.substr(pipeIdx + 1) : inner;
			text = wikiLink.matchedLeft() + display + wikiLink.matchedRight();
		}

		// Strip bold / italic wiki markers
		text = StringTools.replace(text, "'''", "");
		text = StringTools.replace(text, "''", "");

		return text;
	}
}
