package forge;

import forge.data.*;
import forge.rules.*;

/**
 * Central application state.
 * All UI reads from this; all mutations go through methods here.
 */
class AppState {
	public var version:String = "";
	public var champions:Map<String, forge.data.ChampionSummary> = new Map();
	public var items:Map<String, forge.data.ItemData> = new Map();

	public var selectedChampion:Null<forge.data.ChampionDetail> = null;
	public var champProfile:Null<forge.rules.ChampionProfile> = null;

	public var currentMode:GameMode = GameModes.ALL[0];
	public var currentFilter:FilterType = All;
	public var champSearch:String = "";
	public var itemSearch:String = "";

	// item id → synergy result (computed lazily when champion changes)
	public var synergies:Map<String, SynergyResult> = new Map();
	public var synergiesComputed:Bool = false;

	// Champion-specific item overrides: loaded from data/overrides.json
	// Structure: Dynamic { ChampionKey: { itemId: { tier: String, reason: String } } }
	public var overrides:Dynamic = null;

	public var isLoadingChampions:Bool = true;
	public var isLoadingItems:Bool = true;
	public var isLoadingDetail:Bool = false;

	// Computed once items + champion are loaded
	public var filteredItems:Array<{id:String, item:ItemData}> = [];

	public function new() {}

	public function selectMode(modeId:String):Void {
		var m = GameModes.byId(modeId);
		if (m != null) {
			currentMode = m;
			rebuildFilteredItems();
			if (selectedChampion != null)
				computeSynergies();
		}
	}

	public function setChampionDetail(detail:ChampionDetail):Void {
		selectedChampion = detail;
		champProfile = ProfileBuilder.build(detail);
		synergiesComputed = false;
		synergies = new Map();
		computeSynergies();
	}

	public function computeSynergies():Void {
		if (champProfile == null)
			return;
		synergies = new Map();

		// Look up champion overrides if available
		var champKey:String = selectedChampion != null ? selectedChampion.id : "";
		var champOverrides:Dynamic = null;
		if (overrides != null && champKey != "")
			champOverrides = Reflect.field(overrides, champKey);

		for (entry in filteredItems) {
			var iprof = ItemClassifier.classify(entry.id, entry.item);
			var result = SynergyEngine.score(champProfile, iprof);

			// Apply manual override if one exists for this champion + item
			if (champOverrides != null) {
				var ov:Dynamic = Reflect.field(champOverrides, entry.id);
				if (ov != null) {
					var tierStr:String = Reflect.field(ov, "tier");
					var reason:String = Reflect.field(ov, "reason");
					var overrideTier = parseTier(tierStr);
					if (overrideTier != null) {
						result.tier = overrideTier;
						result.score = tierToScore(overrideTier);
						result.reasons = reason != null ? ["[Override] " + reason] : ["[Manual override]"];
					}
				}
			}

			synergies.set(entry.id, result);
		}
		synergiesComputed = true;
	}

	static function parseTier(s:String):Null<SynergyTier> {
		if (s == null)
			return null;
		return switch (s.toLowerCase()) {
			case "core": Core;
			case "good": Good;
			case "situational": Situational;
			case "weak": Weak;
			case "trap": Trap;
			default: null;
		}
	}

	static function tierToScore(t:SynergyTier):Int {
		return switch (t) {
			case Core: 9;
			case Good: 7;
			case Situational: 5;
			case Weak: 3;
			case Trap: 1;
		}
	}

	public function rebuildFilteredItems():Void {
		filteredItems = [];
		for (id => item in items) {
			if (GameModes.isAvailable(item, currentMode) && GameModes.isFinishedItem(item)) {
				filteredItems.push({id: id, item: item});
			}
		}
		// Sort by cost descending (legendary first)
		filteredItems.sort((a, b) -> {
			var ca = a.item.gold != null ? a.item.gold.total : 0;
			var cb = b.item.gold != null ? b.item.gold.total : 0;
			return cb - ca;
		});
	}

	public function visibleItems():Array<{id:String, item:ItemData, synergy:Null<SynergyResult>}> {
		var search = itemSearch.toLowerCase();
		return filteredItems.filter(entry -> {
			// Name search
			if (search != "" && entry.item.name.toLowerCase().indexOf(search) < 0)
				return false;
			// Synergy filter
			if (synergiesComputed) {
				var syn = synergies.get(entry.id);
				return switch currentFilter {
					case All: true;
					case Core: syn != null && syn.tier == Core;
					case Good: syn != null && syn.tier == Good;
					case Situational: syn != null && syn.tier == Situational;
					case Weak: syn != null && syn.tier == Weak;
					case Trap: syn != null && syn.tier == Trap;
				}
			}
			return true;
		}).map(entry -> {
			return {id: entry.id, item: entry.item, synergy: synergies.get(entry.id)};
		});
	}

	public function filteredChampions():Array<ChampionSummary> {
		var q = champSearch.toLowerCase();
		var list = [for (_ => c in champions) c];
		if (q != "")
			list = list.filter(c -> c.name.toLowerCase().indexOf(q) >= 0);
		list.sort((a, b) -> a.name < b.name ? -1 : 1);
		return list;
	}
}
