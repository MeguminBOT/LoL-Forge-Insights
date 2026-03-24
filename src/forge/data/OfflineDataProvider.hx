package forge.data;

/**
 * Reads Meraki data from a local `data/` directory.
 * Used for the offline / sys / cpp target.
 *
 * Expects this layout (populated by scripts/fetch-data.js):
 *   data/
 *     version.txt
 *     meraki-champions.json
 *     meraki-items.json
 *     img/champion/<filename>
 *     img/item/<filename>
 */
class OfflineDataProvider implements IDataProvider {
	var dataRoot:String;
	#if sys
	var cachedChampData:Dynamic = null;
	var cachedItemData:Dynamic = null;
	#end

	public function new(dataRoot:String = "data") {
		this.dataRoot = dataRoot;
	}

	public function getVersion(cb:(String) -> Void):Void {
		#if sys
		var p = '$dataRoot/version.txt';
		if (sys.FileSystem.exists(p))
			cb(StringTools.trim(sys.io.File.getContent(p)));
		else
			cb("14.10.1");
		#end
	}

	public function getChampionList(version:String, cb:(Map<String, ChampionSummary>) -> Void):Void {
		#if sys
		var data = loadChampData();
		var map = new Map<String, ChampionSummary>();
		for (key in Reflect.fields(data)) {
			var c:Dynamic = Reflect.field(data, key);
			var champKey:String = c.key;
			map.set(champKey, {
				id: champKey,
				name: c.name,
				title: c.title,
				image: {full: champKey + ".png", sprite: "", group: ""},
				tags: MerakiConverter.rolesToTags(c.roles),
				partype: MerakiConverter.resourceToPartype(c.resource),
			});
		}
		cb(map);
		#end
	}

	public function getChampionDetail(version:String, championId:String, cb:(ChampionDetail) -> Void):Void {
		#if sys
		var data = loadChampData();
		var c:Dynamic = Reflect.field(data, championId);
		if (c == null) {
			for (k in Reflect.fields(data)) {
				var ch:Dynamic = Reflect.field(data, k);
				if (ch.key == championId) {
					c = ch;
					break;
				}
			}
		}
		if (c == null) {
			trace('Champion "$championId" not found in Meraki data');
			return;
		}
		cb(MerakiConverter.parseChampion(c));
		#end
	}

	public function getItemList(version:String, cb:(Map<String, ItemData>) -> Void):Void {
		#if sys
		var data = loadItemData();
		var map = new Map<String, ItemData>();
		for (key in Reflect.fields(data)) {
			var item:Dynamic = Reflect.field(data, key);
			if (item.removed == true)
				continue;
			var id = Std.string(item.id);
			map.set(id, MerakiConverter.parseItem(item));
		}
		cb(map);
		#end
	}

	public function championImageUrl(version:String, filename:String):String {
		return 'img/champion/$filename';
	}

	public function itemImageUrl(version:String, filename:String):String {
		return 'img/item/$filename';
	}

	// ── Data loaders (cached) ────────────────────────────────────────────────
	#if sys
	function loadChampData():Dynamic {
		if (cachedChampData != null)
			return cachedChampData;
		var p = '$dataRoot/meraki-champions.json';
		if (!sys.FileSystem.exists(p)) {
			trace('Missing $p — run: node scripts/fetch-data.js');
			return {};
		}
		cachedChampData = haxe.Json.parse(sys.io.File.getContent(p));
		return cachedChampData;
	}

	function loadItemData():Dynamic {
		if (cachedItemData != null)
			return cachedItemData;
		var p = '$dataRoot/meraki-items.json';
		if (!sys.FileSystem.exists(p)) {
			trace('Missing $p — run: node scripts/fetch-data.js');
			return {};
		}
		cachedItemData = haxe.Json.parse(sys.io.File.getContent(p));
		return cachedItemData;
	}
	#end
}
