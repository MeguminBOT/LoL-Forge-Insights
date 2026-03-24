package forge;

enum ItemCategory {
	Mage;
	Marksman;
	Assassin;
	Fighter;
	Tank;
	Support;
	Boots;
	Other;
}

class ItemCategoryTools {
	public static function fromTags(tags:Array<String>):ItemCategory {
		if (tags == null)
			return Other;
		if (tags.indexOf("Boots") >= 0)
			return Boots;
		// Primary class tags in priority order
		if (tags.indexOf("MAGE") >= 0)
			return Mage;
		if (tags.indexOf("ASSASSIN") >= 0)
			return Assassin;
		if (tags.indexOf("MARKSMAN") >= 0)
			return Marksman;
		if (tags.indexOf("FIGHTER") >= 0)
			return Fighter;
		if (tags.indexOf("TANK") >= 0)
			return Tank;
		if (tags.indexOf("SUPPORT") >= 0)
			return Support;
		return Other;
	}

	public static function label(cat:ItemCategory):String {
		return switch cat {
			case Mage: "Mage";
			case Marksman: "Marksman";
			case Assassin: "Assassin";
			case Fighter: "Fighter";
			case Tank: "Tank";
			case Support: "Support";
			case Boots: "Boots";
			case Other: "Other";
		};
	}

	public static var displayOrder:Array<ItemCategory> = [Mage, Assassin, Marksman, Fighter, Tank, Support, Boots, Other];
}
