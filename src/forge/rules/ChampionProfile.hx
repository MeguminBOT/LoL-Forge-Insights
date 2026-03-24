package forge.rules;

typedef ChampionProfile = {
	var id:String;
	var name:String;
	var tags:Array<String>;

	// ── Resource and range ────────────────────────────────────────────────────
	var resource:ResourceType;
	var range:RangeType;
	var attackRange:Float;

	// ── Damage scaling ────────────────────────────────────────────────────────
	// Derived from info.attack/magic ratings and champion tags.
	// NOT from tooltip damage-type HTML tags.
	var primaryDamage:DamageType;
	var hasApScaling:Bool;
	var hasAdScaling:Bool;

	// ── Ability traits ────────────────────────────────────────────────────────
	var hasOnHit:Bool; // strict: "on-hit" or "on hit" only
	var hasAutoResets:Bool; // ability resets/empowers next auto
	var hasDoT:Bool;
	var hasDash:Bool;
	var hasShield:Bool;
	var hasHeal:Bool;
	var hasCc:Bool; // any hard or soft CC
	var hasSlow:Bool;
	var hasStun:Bool; // stun or root
	var hasKnockup:Bool;
	var hasSilence:Bool;
	var hasExecute:Bool;
	var hasStealth:Bool;
	var hasGlobalUlt:Bool;
	var hasCritSynergy:Bool; // abilities that scale with or benefit from crit

	// ── Stat ratings (Riot's own 1–10 info block) ────────────────────────────
	var defenseRating:Int;
	var attackRating:Int;
	var magicRating:Int;
	var autoAttackPriority:Float; // 0.0–1.0 weight for how reliant on autos

	// ── Derived stat flags ────────────────────────────────────────────────────
	var isHighAttackSpeed:Bool; // base AS >= 0.65
	var isManaless:Bool; // Manaless or Energy
	var isLowMana:Bool; // Mana && base mp < 300
	var isHighMana:Bool; // Mana && base mp >= 400

	// ── Role flags ────────────────────────────────────────────────────────────
	var isMarksman:Bool;
	var isMage:Bool;
	var isSupport:Bool;
	var isAssassin:Bool;
	var isTank:Bool;
	var isFighter:Bool;
}
