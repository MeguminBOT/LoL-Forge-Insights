package forge.data;

/**
 * Fetches data from Meraki Analytics CDN (champions + items).
 * DDragon is used only for the version number and image URLs.
 */
class BrowserDataProvider implements IDataProvider {
	static final DDRAGON = "https://ddragon.leagueoflegends.com";

	var cachedChampions:Dynamic = null;
	var cachedItems:Dynamic = null;
	var dataRoot:String;

	public function new(dataRoot:String = "data") {
		this.dataRoot = dataRoot;
	}

	public function getVersion(cb:(String) -> Void):Void {
		fetchJson('$DDRAGON/api/versions.json', function(data:Dynamic) {
			var versions:Array<String> = data;
			cb(versions[0]);
		});
	}

	public function getChampionList(version:String, cb:(Map<String, ChampionSummary>) -> Void):Void {
		loadChampions(function(data:Dynamic) {
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
		});
	}

	public function getChampionDetail(version:String, championId:String, cb:(ChampionDetail) -> Void):Void {
		loadChampions(function(data:Dynamic) {
			var c:Dynamic = Reflect.field(data, championId);
			if (c == null) {
				// Try finding by key field
				for (k in Reflect.fields(data)) {
					var ch:Dynamic = Reflect.field(data, k);
					if (ch.key == championId) {
						c = ch;
						break;
					}
				}
			}
			if (c == null) {
				trace('Champion $championId not found in Meraki data');
				return;
			}
			cb(MerakiConverter.parseChampion(c));
		});
	}

	public function getItemList(version:String, cb:(Map<String, ItemData>) -> Void):Void {
		loadItems(function(data:Dynamic) {
			var map = new Map<String, ItemData>();
			for (key in Reflect.fields(data)) {
				var item:Dynamic = Reflect.field(data, key);
				if (item.removed == true)
					continue;
				var id = Std.string(item.id);
				map.set(id, MerakiConverter.parseItem(item));
			}
			cb(map);
		});
	}

	public function championImageUrl(version:String, filename:String):String {
		return '$DDRAGON/cdn/$version/img/champion/$filename';
	}

	public function itemImageUrl(version:String, filename:String):String {
		return '$DDRAGON/cdn/$version/img/item/$filename';
	}

	// ── Data loaders ─────────────────────────────────────────────────────────

	function loadChampions(cb:(Dynamic) -> Void):Void {
		if (cachedChampions != null) {
			cb(cachedChampions);
			return;
		}
		#if js
		var embedded:Dynamic = js.Syntax.code("window.__MERAKI_CHAMPIONS__");
		if (embedded != null) {
			cachedChampions = embedded;
			cb(embedded);
			return;
		}
		#end
		fetchJson('$dataRoot/meraki-champions.json', function(data:Dynamic) {
			cachedChampions = data;
			cb(data);
		});
	}

	function loadItems(cb:(Dynamic) -> Void):Void {
		if (cachedItems != null) {
			cb(cachedItems);
			return;
		}
		#if js
		var embedded:Dynamic = js.Syntax.code("window.__MERAKI_ITEMS__");
		if (embedded != null) {
			cachedItems = embedded;
			cb(embedded);
			return;
		}
		#end
		fetchJson('$dataRoot/meraki-items.json', function(data:Dynamic) {
			cachedItems = data;
			cb(data);
		});
	}

	// ── XHR fetch ────────────────────────────────────────────────────────────

	static function fetchJson(url:String, cb:(Dynamic) -> Void):Void {
		#if js
		var xhr = new js.html.XMLHttpRequest();
		xhr.open("GET", url);
		xhr.onload = function(_) {
			if (xhr.status == 200 || xhr.status == 0) {
				try {
					cb(js.Syntax.code("JSON.parse({0})", xhr.responseText));
				} catch (e:Dynamic) {
					trace('Parse error for $url: $e');
				}
			} else {
				trace('HTTP error ${xhr.status} for $url');
			}
		};
		xhr.onerror = function(_) {
			trace('Network error for $url');
		};
		xhr.send();
		#end
	}
}
