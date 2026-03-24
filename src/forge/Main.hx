package forge;

import forge.data.*;
#if js
import forge.ui.Renderer;
#end

class Main {
	static var state:AppState;
	static var provider:IDataProvider;
	static var championDetailCache:Map<String, Dynamic> = new Map();
	static var championDetailsLoaded:Bool = false;
	#if js
	static var renderer:Renderer;
	#end

	static function main():Void {
		#if js
		js.Browser.window.addEventListener("DOMContentLoaded", function(_) {
			init();
		});
		#elseif sys
		init();
		#else
		init();
		#end
	}

	static function init():Void {
		state = new AppState();

		#if js
		// Detect offline mode: if window.__OFFLINE__ is set (injected by local server/script),
		// use the offline provider. Otherwise use the CDN browser provider.
		var isOffline:Bool = js.Syntax.code("typeof window.__OFFLINE__ !== 'undefined' && window.__OFFLINE__");
		var dataRoot:String = js.Syntax.code("typeof window.__DATA_ROOT__ !== 'undefined' ? window.__DATA_ROOT__ : 'data'");

		provider = isOffline ? new OfflineDataProvider(dataRoot) : new BrowserDataProvider(dataRoot);

		renderer = new Renderer(state, provider, onChampClick, onModeClick, onFilterClick, onChampSearch, onItemSearch);

		// Initial renders (loading state)
		renderer.renderChampionGrid();
		renderer.renderChampionInfoBar();
		renderer.renderItemsToolbar();
		renderer.renderItemsGrid();

		// Load version, then champions + items in parallel
		provider.getVersion(function(version) {
			state.version = version;

			var champsLoaded = false;
			var itemsLoaded = false;

			provider.getChampionList(version, function(champs) {
				state.champions = champs;
				state.isLoadingChampions = false;
				renderer.renderChampionGrid();
				champsLoaded = true;
				if (champsLoaded && itemsLoaded) {
					loadChampionDetailsCache(version);
					onAllLoaded();
				}
			});

			provider.getItemList(version, function(items) {
				state.items = items;
				state.isLoadingItems = false;
				state.rebuildFilteredItems();
				itemsLoaded = true;
				if (champsLoaded && itemsLoaded)
					onAllLoaded();
			});
		});
		#elseif sys
		provider = new OfflineDataProvider("data");
		trace("Running in sys/cpp mode with data root: data");

		provider.getVersion(function(version) {
			state.version = version;

			var champsLoaded = false;
			var itemsLoaded = false;

			provider.getChampionList(version, function(champs) {
				state.champions = champs;
				state.isLoadingChampions = false;
				var count = 0;
				for (_ in champs.keys())
					count++;
				trace("Loaded " + count + " champions");
				champsLoaded = true;
				if (champsLoaded && itemsLoaded) {
					loadChampionDetailsCache(version);
					onAllLoaded();
				}
			});

			provider.getItemList(version, function(items) {
				state.items = items;
				state.isLoadingItems = false;
				state.rebuildFilteredItems();
				var count = 0;
				for (_ in items.keys())
					count++;
				trace("Loaded " + count + " items");
				itemsLoaded = true;
				if (champsLoaded && itemsLoaded)
					onAllLoaded();
			});
		});
		#else
		provider = new BrowserDataProvider();
		#end
	}

	public static function loadChampionDetailsCache(version:String):Void {
		#if js
		var storageKey = "championDetails:" + version;
		var localStorage = js.Browser.window.localStorage;

		if (localStorage != null) {
			var existing = localStorage.getItem(storageKey);
			if (existing != null) {
				try {
					var parsed:Dynamic = haxe.Json.parse(existing);
					for (id in Reflect.fields(parsed)) {
						var detail = Reflect.field(parsed, id);
						championDetailCache.set(id, detail);
					}
					championDetailsLoaded = true;
					trace("Loaded champion details from localStorage");
					return;
				} catch (e:Dynamic) {
					trace("Failed to parse local champion details, refetching");
				}
			}
		}
		// fetch all champion details and persist in localStorage
		fetchAllChampionDetails(version, storageKey);
		#elseif sys
		// offline mode should already have local files; we still warm cache from provider on first champ selection
		championDetailsLoaded = true;
		#end
	}

	public static function fetchAllChampionDetails(version:String, storageKey:String):Void {
		#if js
		if (state.champions == null)
			return;
		var keys = [for (id => _ in state.champions) id];
		if (keys.length == 0) {
			championDetailsLoaded = true;
			return;
		}
		var loaded = 0;
		for (id in keys) {
			provider.getChampionDetail(version, id, function(detail) {
				if (detail != null) {
					championDetailCache.set(id, detail);
				}
				loaded++;
				if (loaded == keys.length) {
					championDetailsLoaded = true;
					saveChampionDetailsCache(version, storageKey);
					trace("Champion details cached for version " + version);
				}
			});
		}
		#end
	}

	public static function saveChampionDetailsCache(version:String, storageKey:String):Void {
		#if js
		var localStorage = js.Browser.window.localStorage;
		if (localStorage == null)
			return;
		var out:Dynamic = {};
		for (id in championDetailCache.keys()) {
			Reflect.setField(out, id, championDetailCache.get(id));
		}
		localStorage.setItem(storageKey, haxe.Json.stringify(out));
		#end
	}

	public static function refreshData():Void {
		#if js
		var version = state.version;
		if (version == "")
			return;

		state.isLoadingChampions = true;
		state.isLoadingItems = true;
		renderer.renderChampionGrid();
		renderer.renderItemsToolbar();
		renderer.renderItemsGrid();

		// Clear cache and localStorage for fresh values
		var storageKey = "championDetails:" + version;
		var localStorage = js.Browser.window.localStorage;
		if (localStorage != null) {
			localStorage.removeItem(storageKey);
		}
		championDetailCache = new Map();
		championDetailsLoaded = false;

		// Reload champion and item lists
		provider.getChampionList(version, function(champs) {
			state.champions = champs;
			state.isLoadingChampions = false;
			renderer.renderChampionGrid();
			if (!state.isLoadingItems) {
				loadChampionDetailsCache(version);
				onAllLoaded();
			}
		});

		provider.getItemList(version, function(items) {
			state.items = items;
			state.isLoadingItems = false;
			state.rebuildFilteredItems();
			renderer.renderItemsToolbar();
			renderer.renderItemsGrid();
			if (!state.isLoadingChampions) {
				onAllLoaded();
			}
		});

		trace("Refreshing all data...");
		#end
	}

	public static function refetchChampionDetails():Void {
		#if js
		var version = state.version;
		if (version == "")
			return;
		var storageKey = "championDetails:" + version;
		var localStorage = js.Browser.window.localStorage;
		if (localStorage != null) {
			localStorage.removeItem(storageKey);
		}
		championDetailCache = new Map();
		championDetailsLoaded = false;
		fetchAllChampionDetails(version, storageKey);
		trace("Refetching champion details...");
		#end
	}

	public static function getChampionDetailFromCache(id:String, cb:(ChampionDetail) -> Void):Void {
		#if js
		var c = championDetailCache.get(id);
		if (c != null) {
			cb(c);
			return;
		}
		#end
		provider.getChampionDetail(state.version, id, function(detail) {
			if (detail != null) {
				championDetailCache.set(id, detail);
			}
			cb(detail);
		});
	}

	static function onAllLoaded():Void {
		#if js
		renderer.renderChampionGrid();
		renderer.renderItemsGrid();
		#elseif sys
		var champCount = 0;
		var itemCount = 0;
		if (state.champions != null) {
			for (k in state.champions.keys())
				champCount++;
		}
		if (state.items != null) {
			for (k in state.items.keys())
				itemCount++;
		}
		trace("All loaded: " + champCount + " champions, " + itemCount + " items");
		#end
	}

	// ── Event handlers ────────────────────────────────────────────────────────
	#if js
	static function onChampClick(championId:String):Void {
		if (state.isLoadingDetail)
			return;
		state.isLoadingDetail = true;
		renderer.renderChampionInfoBar();

		getChampionDetailFromCache(championId, function(detail) {
			state.isLoadingDetail = false;
			state.setChampionDetail(detail);
			renderer.renderChampionGrid(); // update selected highlight
			renderer.renderChampionInfoBar();
			renderer.renderItemsToolbar();
			renderer.renderItemsGrid();
		});
	}

	static function onModeClick(modeId:String):Void {
		state.selectMode(modeId);
		renderer.renderItemsToolbar();
		renderer.renderItemsGrid();
	}

	static function onFilterClick(filter:FilterType):Void {
		state.currentFilter = filter;
		renderer.renderItemsToolbar();
		renderer.renderItemsGrid();
	}

	static function onChampSearch(q:String):Void {
		state.champSearch = q;
		renderer.renderChampionGrid();
	}

	static function onItemSearch(q:String):Void {
		state.itemSearch = q;
		renderer.renderItemsGrid();
	}
	#elseif sys
	static function onChampClick(championId:String):Void {}

	static function onModeClick(modeId:String):Void {}

	static function onFilterClick(filter:FilterType):Void {}

	static function onChampSearch(q:String):Void {}

	static function onItemSearch(q:String):Void {}
	#end
}
