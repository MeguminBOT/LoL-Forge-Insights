package forge.data;

/**
 * Game mode definitions and per-mode item eligibility.
 */
class GameModes {
	public static final ALL:Array<GameMode> = [
		{
			id: "CLASSIC",
			label: "Summoner's Rift",
			mapId: 11,
			excludeTags: []
		},
		{
			id: "ARAM",
			label: "ARAM",
			mapId: 12,
			excludeTags: ["Trinket"]
		},
		{
			id: "MAYHEM",
			label: "Mayhem",
			mapId: 12,
			excludeTags: ["Trinket"]
		},
		{
			id: "BRAWL",
			label: "Brawl",
			mapId: 12,
			excludeTags: ["Trinket"]
		},
		{
			id: "CHERRY",
			label: "Arena",
			mapId: 30,
			excludeTags: ["Trinket", "GoldPer"]
		},
		{
			id: "URF",
			label: "URF",
			mapId: 11,
			excludeTags: []
		},
		{
			id: "ONEFORALL",
			label: "One for All",
			mapId: 11,
			excludeTags: []
		},
	];

	/**
	 * Returns true if an item is available in the given game mode.
	 * Uses the item's `maps` field (keyed by map ID string).
	 */
	public static function isAvailable(item:ItemData, mode:GameMode):Bool {
		if (item.gold == null || !item.gold.purchasable)
			return false;
		if (item.consumed == true)
			return false;
		if (item.inStore == false)
			return false;
		if (item.hideFromAll == true)
			return false;
		if (item.requiredChampion != null && item.requiredChampion != "")
			return false;

		// Check map availability
		var mapKey = Std.string(mode.mapId);
		var maps:Dynamic = item.maps;
		if (maps != null) {
			var available:Dynamic = Reflect.field(maps, mapKey);
			// DataDragon uses booleans here
			if (available == false || available == null)
				return false;
		}

		// Exclude by tag
		var tags = item.tags != null ? item.tags : [];
		for (excluded in mode.excludeTags) {
			if (tags.indexOf(excluded) >= 0)
				return false;
		}

		// Require minimum cost (filters out quest items, etc.)
		var totalCost = item.gold != null ? item.gold.total : 0;
		if (totalCost < 300)
			return false;

		return true;
	}

	/**
	 * Returns only purchasable full items + boots (not base components unless they have no build path).
	 * "Finished" = no 'into' entries, meaning nothing builds out of it.
	 */
	public static function isFinishedItem(item:ItemData):Bool {
		// No build path out = finished item
		if (item.into == null || item.into.length == 0)
			return true;
		// Or it's an Ornn item (requiredAlly = "Ornn") — exclude those
		if (item.requiredAlly != null && item.requiredAlly != "")
			return false;
		return false;
	}

	public static function byId(id:String):Null<GameMode> {
		for (m in ALL)
			if (m.id == id)
				return m;
		return null;
	}
}
