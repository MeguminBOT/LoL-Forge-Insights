package forge.rules;

import forge.data.*;

/**
 * Builds a ChampionProfile from raw ChampionDetail.
 *
 * Ability/passive detection pipeline:
 *   1. All effect descriptions from passive + Q/W/E/R are joined and lowercased.
 *   2. Keywords detect: on-hit, auto-resets, CC types, mobility, sustain,
 *      stealth, execute, DoT, and critically — crit synergy.
 *   3. Crit synergy uses positive-match + negative-exclusion so "can critically
 *      strike" is detected but "cannot critically strike" is not.
 *
 * Scaling detection:
 *   1. Meraki ability data — AP/AD flags from modifier units.
 *   2. Fallback heuristic from Riot ratings + role tags.
 */
class ProfileBuilder {
	// ── Keyword lists ──────────────────────────────────────────────────────
	// On-hit: strict literal only
	static final ON_HIT_KW = ["on-hit", "on hit"];

	// Auto-reset / next-attack empowerment
	static final AUTO_RESET_KW = [
		"resets basic attack",
		"reset basic attack",
		"resets her basic attack",
		"resets his basic attack",
		"empowers next",
		"empowers his next",
		"empowers her next",
		"next basic attack",
		"next attack deals",
		"basic attack timer"
	];

	// Hard CC
	static final STUN_KW = ["stuns", " stun ", "stunned", "stunning"];
	static final ROOT_KW = [" roots ", " root ", " rooted ", "snare", "snaring", "immobiliz"];
	static final KNOCKUP_KW = ["knocks up", "knock up", "knocked up", "airborne", "knocks back", "knocked back"];
	static final SILENCE_KW = ["silences", "silence"];
	static final CHARM_KW = ["charms", " charm "];
	static final FEAR_KW = [" fears ", " fear ", "terrif"];
	static final TAUNT_KW = ["taunts", " taunt "];
	static final SUPP_KW = ["suppresses", "suppression"];

	// Soft CC
	static final SLOW_KW = ["slows", " slow ", "slowing"];

	// Mobility
	static final DASH_KW = [
		"dashes",
		" dash ",
		" leaps ",
		" blinks ",
		" jumps ",
		" vaults ",
		" lunges ",
		"teleports to"
	];

	// Sustain
	static final HEAL_KW = [
		"restores health",
		"restore health",
		" heals ",
		"heals for",
		"heals himself",
		"heals herself",
		"heals him",
		"heals her",
		"healing himself",
		"healing herself",
		"healing for",
		"life steal",
		"omnivamp",
		"physical vamp"
	];
	static final SHIELD_KW = [
		"shield",
		"grants a shield",
		"creates a shield",
		"gains a shield",
		"receives a shield",
		"generates a shield"
	];

	// Damage-over-time
	static final DOT_KW = [
		"per second",
		"each second",
		" burn",
		" bleed",
		" poison",
		"damage over time",
		"over 2",
		"over 3",
		"over 4"
	];

	// Stealth / Execute
	static final STEALTH_KW = ["invisible", "camouflage", "stealth", "unseen"];
	static final EXECUTE_KW = ["execute", "finishing blow"];

	// ── Crit synergy: positive indicators vs. negative blockers ─────────────
	//
	// Positive: ability text that says "can critically strike", "critical strike
	// chance is doubled", "based on critical strike chance", etc.
	// Negative: "cannot critically strike" must subtract from the positive count.
	//
	// Strategy: count positive occurrences, subtract negative occurrences.
	// If result > 0, champion has crit synergy.
	static final CRIT_POSITIVE = [
		"critical strike chance",
		"critically strike for",
		"can critically strike",
		"critically strike against",
		"affected by critical strike modifiers",
		"based on crit",
		"crit chance"
	];
	static final CRIT_NEGATIVE = [
		"cannot critically strike",
		"can not critically strike",
		"does not critically strike",
		"unable to critically strike"
	];

	// ── Build ──────────────────────────────────────────────────────────────

	public static function build(c:ChampionDetail):ChampionProfile {
		var resource = detectResource(c.partype);
		var attackRange = c.stats.attackrange;
		var range = attackRange <= 200 ? RangeType.Melee : attackRange < 500 ? RangeType.Short : RangeType.Ranged;

		// ── Scaling: use Meraki modifiers + adaptiveType for accuracy ────────────
		//
		// Raw modifier presence (hasApScaling/hasAdScaling from MerakiConverter)
		// can be misleading: many AD champions have a single minor AP ratio
		// (e.g., MissFortune E, Renekton W) that doesn't make AP items worthwhile.
		//
		// Strategy:
		//   1. If adaptiveType is PHYSICAL_DAMAGE, the champion primarily uses AD.
		//      AP is only meaningful if there are ≥3 AP modifier entries.
		//   2. If adaptiveType is MAGIC_DAMAGE, AP is primary.
		//      AD is only meaningful if there are ≥3 AD modifier entries.
		//   3. Champions with auto-attack resets always benefit from AD (implicit
		//      total-AD scaling through enhanced autos).
		//   4. Fallback heuristic from Riot ratings + tags if data is missing.
		var hasAp:Bool;
		var hasAd:Bool;
		var adaptive:String = c.adaptiveType != null ? c.adaptiveType : "";
		// Use damage-only modifier counts when available: these exclude AP/AD
		// modifiers from pure-utility abilities (heals, shields, buffs) whose
		// damageType is null in the Meraki data.  This prevents champions like
		// Master Yi (AP only on self-heal W) from being flagged as AP-scaling.
		var apCount:Int = c.damageApModCount != null ? c.damageApModCount : (c.apModifierCount != null ? c.apModifierCount : 0);
		var adCount:Int = c.damageAdModCount != null ? c.damageAdModCount : (c.adModifierCount != null ? c.adModifierCount : 0);

		if (c.hasApScaling != null) {
			// Meraki data available — refine with adaptiveType
			if (adaptive == "PHYSICAL_DAMAGE") {
				// AD champion: AP only meaningful with enough AP ratios on damage abilities
				hasAd = true;
				hasAp = apCount >= 3;
			} else if (adaptive == "MAGIC_DAMAGE") {
				// AP champion: AD only meaningful with enough AD ratios on damage abilities
				hasAp = true;
				hasAd = adCount >= 3;
			} else {
				// Unknown adaptive: trust raw flags
				hasAp = c.hasApScaling;
				hasAd = c.hasAdScaling != null && c.hasAdScaling;
			}
		} else {
			hasAp = c.info.magic >= 6 || c.tags.indexOf("Mage") >= 0;
			hasAd = c.info.attack >= 6 || c.tags.indexOf("Marksman") >= 0 || c.tags.indexOf("Fighter") >= 0 || c.tags.indexOf("Assassin") >= 0;
		}

		// ── Collect combined ability text ─────────────────────────────────────
		var combined = collectText(c);

		// Champions with auto-attack resets implicitly scale with AD
		var hasAutoResets = containsAny(combined, AUTO_RESET_KW);
		if (hasAutoResets && !hasAd)
			hasAd = true;

		var primaryDmg = if (hasAp && hasAd) DamageType.Hybrid else if (hasAp) DamageType.Magic else DamageType.Physical;

		// ── Kit trait detection ───────────────────────────────────────────────
		var hasOnHit = containsAny(combined, ON_HIT_KW);

		// CC
		var hasStun = containsAny(combined, STUN_KW);
		var hasRoot = containsAny(combined, ROOT_KW);
		var hasKnockup = containsAny(combined, KNOCKUP_KW);
		var hasSlow = containsAny(combined, SLOW_KW);
		var hasSilence = containsAny(combined, SILENCE_KW);
		var hasCharm = containsAny(combined, CHARM_KW);
		var hasFear = containsAny(combined, FEAR_KW);
		var hasTaunt = containsAny(combined, TAUNT_KW);
		var hasSupp = containsAny(combined, SUPP_KW);
		var hasCc = hasStun || hasRoot || hasKnockup || hasSlow || hasSilence || hasCharm || hasFear || hasTaunt || hasSupp;

		// Mobility, sustain, utility
		var hasDash = containsAny(combined, DASH_KW);
		var hasDoT = containsAny(combined, DOT_KW);
		var hasShield = containsAny(combined, SHIELD_KW);
		var hasHeal = containsAny(combined, HEAL_KW);
		var hasStealth = containsAny(combined, STEALTH_KW);
		var hasExecute = containsAny(combined, EXECUTE_KW);

		// ── Crit synergy (positive minus negative) ────────────────────────────
		var critPositive = countMatches(combined, CRIT_POSITIVE);
		var critNegative = countMatches(combined, CRIT_NEGATIVE);
		var hasCritSynergy = (critPositive - critNegative) > 0;

		// ── Auto-attack priority weight ───────────────────────────────────────
		var autoAttackPriority:Float = if (c.tags.indexOf("Marksman") >= 0) 1.0 else if (hasOnHit || hasAutoResets) 0.85 else if (c.tags.indexOf("Fighter") >= 0
			|| c.tags.indexOf("Assassin") >= 0) 0.65 else if (c.tags.indexOf("Tank") >= 0) 0.40 else if (c.tags.indexOf("Support") >= 0) 0.25 else
			if (c.tags.indexOf("Mage") >= 0) 0.20 else 0.40;

		return {
			id: c.id,
			name: c.name,
			tags: c.tags,

			resource: resource,
			range: range,
			attackRange: attackRange,

			primaryDamage: primaryDmg,
			hasApScaling: hasAp,
			hasAdScaling: hasAd,

			hasOnHit: hasOnHit,
			hasAutoResets: hasAutoResets,
			hasDoT: hasDoT,
			hasDash: hasDash,
			hasShield: hasShield,
			hasHeal: hasHeal,
			hasCc: hasCc,
			hasSlow: hasSlow,
			hasStun: hasStun || hasRoot,
			hasKnockup: hasKnockup,
			hasSilence: hasSilence,
			hasExecute: hasExecute,
			hasStealth: hasStealth,
			hasGlobalUlt: detectGlobalUlt(c),
			hasCritSynergy: hasCritSynergy,

			defenseRating: c.info.defense,
			attackRating: c.info.attack,
			magicRating: c.info.magic,
			autoAttackPriority: autoAttackPriority,

			isHighAttackSpeed: c.stats.attackspeed >= 0.65,
			isManaless: resource == ResourceType.Manaless || resource == ResourceType.Energy,
			isLowMana: resource == ResourceType.Mana && c.stats.mp < 300,
			isHighMana: resource == ResourceType.Mana && c.stats.mp >= 400,

			isMarksman: c.tags.indexOf("Marksman") >= 0,
			isMage: c.tags.indexOf("Mage") >= 0,
			isSupport: c.tags.indexOf("Support") >= 0,
			isAssassin: c.tags.indexOf("Assassin") >= 0,
			isTank: c.tags.indexOf("Tank") >= 0,
			isFighter: c.tags.indexOf("Fighter") >= 0,
		};
	}

	// ── Private helpers ───────────────────────────────────────────────────────

	/** Collect all description + tooltip text, strip HTML tags, lowercase. */
	static function collectText(c:ChampionDetail):String {
		var parts:Array<String> = [];
		if (c.passive != null) {
			if (c.passive.description != null)
				parts.push(c.passive.description);
		}
		for (spell in c.spells) {
			if (spell.description != null)
				parts.push(spell.description);
			if (spell.tooltip != null)
				parts.push(spell.tooltip);
		}
		var raw = parts.join(" ");
		// Strip HTML/XML tags
		raw = ~/(<[^>]+>)/g.replace(raw, " ");
		return raw.toLowerCase();
	}

	/** Returns true if text contains any of the keywords. */
	static function containsAny(text:String, keywords:Array<String>):Bool {
		for (kw in keywords)
			if (text.indexOf(kw) >= 0)
				return true;
		return false;
	}

	/** Count how many keywords from the list appear in the text. */
	static function countMatches(text:String, keywords:Array<String>):Int {
		var count = 0;
		for (kw in keywords)
			if (text.indexOf(kw) >= 0)
				count++;
		return count;
	}

	static function detectGlobalUlt(c:ChampionDetail):Bool {
		if (c.spells.length < 4)
			return false;
		var ult = c.spells[3];
		var text = ((ult.description != null ? ult.description : "") + " " + (ult.tooltip != null ? ult.tooltip : "")).toLowerCase();
		return text.indexOf("global") >= 0 || text.indexOf("anywhere on the map") >= 0;
	}

	static function detectResource(partype:String):ResourceType {
		return switch partype.toLowerCase() {
			case "mana": ResourceType.Mana;
			case "energy": ResourceType.Energy;
			case "none" | "no cost" | "": ResourceType.Manaless;
			// Rage, Fury, Ferocity, Grit, Heat, Crimson Rush, Blood Well, etc.
			default: ResourceType.Manaless;
		}
	}
}
