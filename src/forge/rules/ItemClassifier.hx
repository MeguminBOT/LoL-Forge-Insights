package forge.rules;

import forge.data.*;

/**
 * Classifies a raw ItemData into a structured ItemProfile.
 *
 * Stat detection reads Meraki-format nested stats:
 *   stats.abilityPower.flat / .percent
 *   stats.attackDamage.flat / .percent
 *   stats.attackSpeed.flat  / .percent
 *   stats.lethality.flat
 *   stats.armorPenetration.flat / .percent
 *   stats.magicPenetration.flat / .percent
 *   stats.lifesteal.percent
 *   stats.omnivamp.percent
 *   stats.abilityHaste.flat
 *   stats.tenacity.percent
 *   ... etc.
 *
 * For passive types (sheen, on-hit, etc.) we use description text keywords.
 */
class ItemClassifier {
	public static function classify(id:String, item:ItemData):ItemProfile {
		var tags = item.tags != null ? item.tags : [];
		var stats = item.stats != null ? item.stats : {};
		var rawDesc = item.description != null ? item.description : "";
		// Strip HTML/wiki markup brackets, lowercase — used for passive detection
		var desc = ~/(<[^>]+>)/g.replace(rawDesc, " ").toLowerCase();
		var cost = item.gold != null ? item.gold.total : 0;

		// ── Structural flags ──────────────────────────────────────────────────
		var isBoots = tags.indexOf("Boots") >= 0;
		var isTrinket = cost == 0 && tags.indexOf("Trinket") >= 0;
		var isSupportIncome = mStat(stats, "goldPer10") > 0;
		var isOrnn = item.requiredAlly != null && item.requiredAlly != "";
		var isComponent = item.into != null && item.into.length > 0;
		var isFinished = !isComponent && !isOrnn;
		var isMythic = desc.indexOf("mythic passive") >= 0;

		// ── Stat grants (Meraki nested stats) ─────────────────────────────────
		var givesAp = mStat(stats, "abilityPower") > 0;
		var givesAd = mStat(stats, "attackDamage") > 0;
		var givesAs = mStat(stats, "attackSpeed") > 0;
		var givesArmor = mStat(stats, "armor") > 0;
		var givesMr = mStat(stats, "magicResistance") > 0;
		var givesHp = mStat(stats, "health") > 0;
		var givesMana = mStat(stats, "mana") > 0;
		var givesHpRegen = mStat(stats, "healthRegen") > 0;
		var givesManaRegen = mStat(stats, "manaRegen") > 0;
		var givesCrit = mStat(stats, "criticalStrikeChance") > 0;
		var givesMs = mStat(stats, "movespeed") > 0 || isBoots;
		var givesLethality = mStat(stats, "lethality") > 0;
		var givesArmorPen = mStat(stats, "armorPenetration") > 0 || givesLethality;
		var givesMagicPen = mStat(stats, "magicPenetration") > 0;
		var givesLifesteal = mStat(stats, "lifesteal") > 0;
		var givesOmnivamp = mStat(stats, "omnivamp") > 0;
		var givesAh = mStat(stats, "abilityHaste") > 0;
		var givesTenacity = mStat(stats, "tenacity") > 0;

		// ── Passive-type detection (description text) ─────────────────────────

		var hasOnHitPassive = desc.indexOf("on-hit") >= 0 || desc.indexOf("on hit") >= 0;

		var hasSpellblade = desc.indexOf("spellblade") >= 0 || desc.indexOf("after using an ability, your next attack") >= 0;

		var hasManaScaling = desc.indexOf("mana charge") >= 0 || desc.indexOf("bonus mana") >= 0 || desc.indexOf("maximum mana") >= 0
			|| desc.indexOf("based on mana") >= 0;

		var hasShieldPassive = desc.indexOf("grants a shield") >= 0
			|| desc.indexOf("creates a shield") >= 0
			|| desc.indexOf("gains a shield") >= 0;

		var hasHealPassive = givesLifesteal || givesOmnivamp || desc.indexOf("restores health") >= 0;

		var hasAntiHeal = desc.indexOf("grievous wounds") >= 0;

		var hasExecutePassive = desc.indexOf("execute") >= 0 || desc.indexOf("missing health") >= 0;

		var hasDoTPassive = desc.indexOf("per second") >= 0 || desc.indexOf("each second") >= 0 || desc.indexOf(" burn") >= 0;

		var hasDashActive = desc.indexOf("dash") >= 0 || desc.indexOf("leap") >= 0;

		var enhancesHealing = desc.indexOf("increases all healing") >= 0
			|| desc.indexOf("increase healing") >= 0
			|| desc.indexOf("increases healing") >= 0
			|| desc.indexOf("enhance healing") >= 0;

		var isRangedOnly = desc.indexOf("ranged attacks") >= 0 || desc.indexOf("ranged only") >= 0 || desc.indexOf("ranged champions") >= 0;

		var isSupportItem = tags.indexOf("SUPPORT") >= 0;

		// Support on-hit: item grants on-hit effects to allies, not to the wielder
		var isSupportOnHit = hasOnHitPassive
			&& (desc.indexOf("allied") >= 0 || desc.indexOf("allies") >= 0 || desc.indexOf("ally") >= 0 || desc.indexOf("heal or shield") >= 0);

		return {
			id: id,
			name: item.name,
			cost: cost,
			tags: tags,

			givesAp: givesAp,
			givesAd: givesAd,
			givesAs: givesAs,
			givesArmor: givesArmor,
			givesMr: givesMr,
			givesHp: givesHp,
			givesMana: givesMana,
			givesHpRegen: givesHpRegen,
			givesManaRegen: givesManaRegen,
			givesLethality: givesLethality,
			givesArmorPen: givesArmorPen,
			givesMagicPen: givesMagicPen,
			givesLifesteal: givesLifesteal,
			givesOmnivamp: givesOmnivamp,
			givesCrit: givesCrit,
			givesMs: givesMs,
			givesAh: givesAh,
			givesTenacity: givesTenacity,

			hasOnHitPassive: hasOnHitPassive,
			hasSpellblade: hasSpellblade,
			hasManaScaling: hasManaScaling,
			hasShieldPassive: hasShieldPassive,
			hasHealPassive: hasHealPassive,
			hasAntiHeal: hasAntiHeal,
			hasExecutePassive: hasExecutePassive,
			hasDoTPassive: hasDoTPassive,
			hasDashActive: hasDashActive,
			enhancesHealing: enhancesHealing,
			isRangedOnly: isRangedOnly,
			isSupportOnHit: isSupportOnHit,

			isBoots: isBoots,
			isTrinket: isTrinket,
			isSupportIncome: isSupportIncome,
			isSupportItem: isSupportItem,
			isOrnn: isOrnn,
			isComponent: isComponent,
			isMythic: isMythic,
		};
	}

	/** Read a Meraki nested stat: stats.key.flat + stats.key.percent */
	static function mStat(stats:Dynamic, key:String):Float {
		var sub:Dynamic = Reflect.field(stats, key);
		if (sub == null)
			return 0.0;
		var f:Dynamic = Reflect.field(sub, "flat");
		var p:Dynamic = Reflect.field(sub, "percent");
		var fv:Float = f != null ? f : 0.0;
		var pv:Float = p != null ? p : 0.0;
		return fv + pv;
	}
}
