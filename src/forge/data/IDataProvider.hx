package forge.data;

/**
 * Abstract data provider.
 * Browser target fetches from CDN; offline target reads from local files.
 */
interface IDataProvider {
	/** Returns the current patch version string, e.g. "14.10.1" */
	function getVersion(cb:(String) -> Void):Void;

	/** Returns champion summary map keyed by champion id */
	function getChampionList(version:String, cb:(Map<String, ChampionSummary>) -> Void):Void;

	/** Returns full champion detail for a specific champion */
	function getChampionDetail(version:String, championId:String, cb:(ChampionDetail) -> Void):Void;

	/** Returns item map keyed by item id */
	function getItemList(version:String, cb:(Map<String, ItemData>) -> Void):Void;

	/** Returns a URL for a champion square image */
	function championImageUrl(version:String, filename:String):String;

	/** Returns a URL for an item image */
	function itemImageUrl(version:String, filename:String):String;
}
