package forge.data;

typedef ChampionDetail = {
	var id:String;
	var name:String;
	var title:String;
	var image:ImageData;
	var tags:Array<String>;
	var partype:String;
	var stats:ChampionStats;
	var passive:PassiveSpell;
	var spells:Array<ChampionSpell>;
	var info:ChampionInfo;
	var lore:String;
	var ?hasApScaling:Bool;
	var ?hasAdScaling:Bool;
	var ?adaptiveType:String; // "PHYSICAL_DAMAGE" or "MAGIC_DAMAGE"
	var ?apModifierCount:Int; // count of AP-scaling modifiers across all abilities
	var ?adModifierCount:Int; // count of AD-scaling modifiers across all abilities
	var ?merakiRoles:Array<String>; // raw Meraki roles (SKIRMISHER, JUGGERNAUT, etc.)
}
