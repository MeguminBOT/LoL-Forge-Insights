package forge.rules;

typedef ItemProfile = {
	var id:String;
	var name:String;
	var cost:Int;
	var tags:Array<String>;

	// ── Stats granted ─────────────────────────────────────────────────────────
	var givesAp:Bool; // FlatMagicDamageMod > 0  OR  SpellDamage tag
	var givesAd:Bool; // FlatPhysicalDamageMod > 0  OR  Damage tag
	var givesAs:Bool; // PercentAttackSpeedMod > 0  OR  AttackSpeed tag
	var givesArmor:Bool;
	var givesMr:Bool;
	var givesHp:Bool;
	var givesMana:Bool;
	var givesHpRegen:Bool;
	var givesManaRegen:Bool;
	var givesLethality:Bool; // ArmorPenetration tag or description
	var givesArmorPen:Bool; // same tag, covers % armor pen too
	var givesMagicPen:Bool; // MagicPenetration tag or description
	var givesLifesteal:Bool; // LifeSteal tag
	var givesOmnivamp:Bool; // SpellVamp tag or "omnivamp" in description
	var givesCrit:Bool; // FlatCritChanceMod > 0  OR  CriticalStrike tag
	var givesMs:Bool; // any movement speed stat or Boots
	var givesAh:Bool; // AbilityHaste tag or description
	var givesTenacity:Bool; // Tenacity tag or description

	// ── Passive types ─────────────────────────────────────────────────────────
	var hasOnHitPassive:Bool; // OnHit tag OR "on-hit"/"on hit" in description
	var hasSpellblade:Bool; // spellblade proc in description
	var hasManaScaling:Bool; // mana charge / bonus mana / Tear-family
	var hasShieldPassive:Bool; // grants a shield
	var hasHealPassive:Bool; // lifesteal/omnivamp or restores health
	var hasAntiHeal:Bool; // grievous wounds
	var hasExecutePassive:Bool; // execute / missing health threshold
	var hasDoTPassive:Bool; // per second / burn
	var hasDashActive:Bool; // active with a dash (Galeforce-style)
	var enhancesHealing:Bool; // increases healing/shielding (e.g. Spirit Visage)
	var isRangedOnly:Bool; // item only works on ranged champions
	var isSupportOnHit:Bool; // on-hit effect granted to allies, not wielder

	// ── Structural flags ──────────────────────────────────────────────────────
	var isBoots:Bool;
	var isTrinket:Bool;
	var isSupportIncome:Bool; // GoldPer tag
	var isSupportItem:Bool; // Meraki shop tags contain SUPPORT
	var isOrnn:Bool; // Ornn upgrade (requiredAlly set)
	var isComponent:Bool; // builds into something
	var isMythic:Bool; // "mythic passive" in description
}
