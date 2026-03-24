package forge;

import forge.data.*;
#if js
import forge.ui.Renderer;
#end

class Main {
	static var state:AppState;
	static var provider:IDataProvider;
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
		// Load overrides from embedded JS global
		var rawOverrides:Dynamic = js.Syntax.code("typeof window.__MERAKI_OVERRIDES__ !== 'undefined' ? window.__MERAKI_OVERRIDES__ : null");
		if (rawOverrides != null)
			state.overrides = rawOverrides;

		// Detect offline mode: if window.__OFFLINE__ is set (injected by local server/script),
		// use the offline provider. Otherwise use the CDN browser provider.
		var isOffline:Bool = js.Syntax.code("typeof window.__OFFLINE__ !== 'undefined' && window.__OFFLINE__");
		var dataRoot:String = js.Syntax.code("typeof window.__DATA_ROOT__ !== 'undefined' ? window.__DATA_ROOT__ : 'data'");

		provider = isOffline ? new OfflineDataProvider(dataRoot) : new BrowserDataProvider();

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
				if (champsLoaded && itemsLoaded)
					onAllLoaded();
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

		// Load overrides from filesystem
		if (sys.FileSystem.exists("data/overrides.json")) {
			try {
				var ovContent = sys.io.File.getContent("data/overrides.json");
				state.overrides = haxe.Json.parse(ovContent);
				trace("Loaded overrides from data/overrides.json");
			} catch (e:Dynamic) {
				trace("Warning: Failed to parse overrides.json: " + Std.string(e));
			}
		}

		provider.getVersion(function(version) {
			state.version = version;

			var champsLoaded = false;
			var itemsLoaded = false;

			provider.getChampionList(version, function(champs) {
				state.champions = champs;
				state.isLoadingChampions = false;
				trace("Loaded " + champs.keys().length + " champions");
				champsLoaded = true;
				if (champsLoaded && itemsLoaded)
					onAllLoaded();
			});

			provider.getItemList(version, function(items) {
				state.items = items;
				state.isLoadingItems = false;
				state.rebuildFilteredItems();
				trace("Loaded " + items.keys().length + " items");
				itemsLoaded = true;
				if (champsLoaded && itemsLoaded)
					onAllLoaded();
			});
		});
		#else
		provider = new BrowserDataProvider();
		#end
	}

	static function onAllLoaded():Void {
		#if js
		renderer.renderChampionGrid();
		renderer.renderItemsGrid();
		#elseif sys
		var champCount = state.champions != null ? state.champions.keys().length : 0;
		var itemCount = state.items != null ? state.items.keys().length : 0;
		trace("All loaded: " + champCount + " champions, " + itemCount + " items");
		#end
	}

	// ── Event handlers ────────────────────────────────────────────────────────

	static function onChampClick(championId:String):Void {
		if (state.isLoadingDetail)
			return;
		state.isLoadingDetail = true;
		renderer.renderChampionInfoBar();

		provider.getChampionDetail(state.version, championId, function(detail) {
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
}
