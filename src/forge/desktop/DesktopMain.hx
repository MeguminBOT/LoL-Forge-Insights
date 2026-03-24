package forge.desktop;

import openfl.display.Sprite;
import haxe.ui.Toolkit;
import forge.AppState;
import forge.data.*;
import forge.rules.*;

/**
 * OpenFL entry point for the desktop (hxcpp) build.
 * Initialises HaxeUI, loads data via OfflineDataProvider, then hands off to DesktopRenderer.
 */
class DesktopMain extends Sprite {
	static var state:AppState;
	static var provider:IDataProvider;
	static var renderer:DesktopRenderer;
	static var championDetailCache:Map<String, Dynamic> = new Map();
	static var championDetailsLoaded:Bool = false;

	public function new() {
		super();
		Toolkit.init();
		init();
	}

	static function init():Void {
		state = new AppState();
		provider = new OfflineDataProvider("data");

		renderer = new DesktopRenderer(state, provider, onChampClick, onModeClick, onFilterClick, onChampSearch, onItemSearch);

		// Load version, then champions + items
		provider.getVersion(function(version) {
			state.version = version;

			var champsLoaded = false;
			var itemsLoaded = false;

			provider.getChampionList(version, function(champs) {
				state.champions = champs;
				state.isLoadingChampions = false;
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
	}

	static function onAllLoaded():Void {
		renderer.renderChampionGrid();
		renderer.renderItemsGrid();
	}

	static function onChampClick(id:String):Void {
		if (championDetailsLoaded && championDetailCache.exists(id)) {
			state.setChampionDetail(championDetailCache.get(id));
			renderer.renderChampionInfoBar();
			renderer.renderItemsGrid();
			return;
		}
		state.isLoadingDetail = true;
		provider.getChampionDetail(state.version, id, function(detail) {
			state.isLoadingDetail = false;
			if (detail != null) {
				championDetailCache.set(id, detail);
				state.setChampionDetail(detail);
			}
			renderer.renderChampionInfoBar();
			renderer.renderItemsGrid();
		});
	}

	static function onModeClick(modeId:String):Void {
		state.selectMode(modeId);
		renderer.renderModeTabs();
		renderer.renderItemsGrid();
	}

	static function onFilterClick(filter:forge.FilterType):Void {
		state.currentFilter = filter;
		renderer.renderFilterButtons();
		renderer.renderItemsGrid();
	}

	static function onChampSearch(query:String):Void {
		state.champSearch = query;
		renderer.renderChampionGrid();
	}

	static function onItemSearch(query:String):Void {
		state.itemSearch = query;
		renderer.renderItemsGrid();
	}

	static function loadChampionDetailsCache(version:String):Void {
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
				if (detail != null)
					championDetailCache.set(id, detail);
				loaded++;
				if (loaded == keys.length)
					championDetailsLoaded = true;
			});
		}
	}
}
