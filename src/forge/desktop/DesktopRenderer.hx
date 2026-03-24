package forge.desktop;

import haxe.ui.Toolkit;
import haxe.ui.HaxeUIApp;
import haxe.ui.containers.*;
import haxe.ui.components.*;
import haxe.ui.events.UIEvent;
import haxe.ui.events.MouseEvent;
import forge.AppState;
import forge.FilterType;
import forge.ItemCategory;
import forge.data.*;
import forge.data.GameModes;

/**
 * Desktop renderer using HaxeUI widgets.
 * Mirrors the browser UI: left champion sidebar, top info bar, centre item grid.
 */
class DesktopRenderer {
	var state:AppState;
	var provider:IDataProvider;
	var onChampClick:(String) -> Void;
	var onModeClick:(String) -> Void;
	var onFilterClick:(FilterType) -> Void;
	var onChampSearch:(String) -> Void;
	var onItemSearch:(String) -> Void;

	// Root containers
	var root:VBox;
	var champGrid:ScrollView;
	var champGridInner:Grid;
	var champInfoBox:HBox;
	var modeBar:HBox;
	var filterBar:HBox;
	var itemSearchField:TextField;
	var itemGrid:ScrollView;
	var itemGridContent:VBox;
	var statsLabel:Label;

	public function new(
		state:AppState,
		provider:IDataProvider,
		onChampClick:(String) -> Void,
		onModeClick:(String) -> Void,
		onFilterClick:(FilterType) -> Void,
		onChampSearch:(String) -> Void,
		onItemSearch:(String) -> Void
	) {
		this.state = state;
		this.provider = provider;
		this.onChampClick = onChampClick;
		this.onModeClick = onModeClick;
		this.onFilterClick = onFilterClick;
		this.onChampSearch = onChampSearch;
		this.onItemSearch = onItemSearch;
		buildLayout();
	}

	function buildLayout():Void {
		var app = HaxeUIApp.instance;
		root = new VBox();
		root.percentWidth = 100;
		root.percentHeight = 100;
		root.styleString = "background-color: #08080E;";

		// ── Header ──
		var header = new HBox();
		header.percentWidth = 100;
		header.height = 52;
		header.styleString = "padding: 0 20px; background-color: #0A0A14; border-bottom: 1px solid rgba(200,155,60,0.25);";

		var logoBox = new VBox();
		logoBox.styleString = "padding-top: 8px;";
		var logo = new Label();
		logo.text = "FORGE INSIGHT";
		logo.styleString = "font-size: 16px; color: #C89B3C; font-weight: bold; letter-spacing: 1;";
		logoBox.addComponent(logo);
		var subtitle = new Label();
		subtitle.text = "LOL ITEM SYNERGY ANALYZER";
		subtitle.styleString = "font-size: 9px; color: #807060; letter-spacing: 2;";
		logoBox.addComponent(subtitle);
		header.addComponent(logoBox);

		// Separator
		var sep = new Spacer();
		sep.width = 20;
		header.addComponent(sep);

		// Mode tabs
		modeBar = new HBox();
		modeBar.styleString = "gap: 4px; padding-top: 12px;";
		for (mode in GameModes.ALL) {
			var btn = new Button();
			btn.text = mode.label;
			btn.userData = mode.id;
			btn.toggle = true;
			btn.selected = mode.id == state.currentMode.id;
			btn.styleString = "font-size: 11px; padding: 4px 10px;";
			btn.onClick = function(_) {
				onModeClick(mode.id);
			};
			modeBar.addComponent(btn);
		}
		header.addComponent(modeBar);

		root.addComponent(header);

		// ── Body (sidebar + main) ──
		var body = new HBox();
		body.percentWidth = 100;
		body.percentHeight = 100;

		// -- Left sidebar: champion search + grid --
		var sidebar = new VBox();
		sidebar.width = 260;
		sidebar.percentHeight = 100;
		sidebar.styleString = "background-color: #0D0D18; border-right: 1px solid rgba(200,155,60,0.25);";

		// Section label
		var sectionLabel = new Label();
		sectionLabel.text = "CHAMPION";
		sectionLabel.styleString = "font-size: 9px; color: #807060; letter-spacing: 2; padding: 10px 12px 4px 12px;";
		sidebar.addComponent(sectionLabel);

		var champSearchField = new TextField();
		champSearchField.placeholder = "Search...";
		champSearchField.percentWidth = 100;
		champSearchField.styleString = "margin: 0 10px 6px 10px; background-color: #111120; color: #DDD0A8; border: 1px solid rgba(200,155,60,0.25); border-radius: 3px; padding: 5px 8px; font-size: 12px;";
		champSearchField.onChange = function(_) {
			onChampSearch(champSearchField.text);
		};
		sidebar.addComponent(champSearchField);

		champGrid = new ScrollView();
		champGrid.percentWidth = 100;
		champGrid.percentHeight = 100;
		champGrid.styleString = "padding: 4px 8px;";
		champGridInner = new Grid();
		champGridInner.columns = 4;
		champGridInner.percentWidth = 100;
		champGrid.addComponent(champGridInner);
		sidebar.addComponent(champGrid);

		body.addComponent(sidebar);

		// -- Main panel --
		var mainPanel = new VBox();
		mainPanel.percentWidth = 100;
		mainPanel.percentHeight = 100;
		mainPanel.styleString = "background-color: #08080E;";

		// Champion info bar
		champInfoBox = new HBox();
		champInfoBox.percentWidth = 100;
		champInfoBox.styleString = "padding: 12px 20px; background-color: #0D0D18; min-height: 80px; border-bottom: 1px solid rgba(200,155,60,0.25);";
		var hintLabel = new Label();
		hintLabel.text = "Select a champion to begin";
		hintLabel.styleString = "color: #3A3630; font-size: 13px;";
		champInfoBox.addComponent(hintLabel);
		mainPanel.addComponent(champInfoBox);

		// Filter toolbar
		var toolbar = new HBox();
		toolbar.percentWidth = 100;
		toolbar.styleString = "padding: 6px 20px; background-color: #0D0D18; gap: 6px; border-bottom: 1px solid rgba(200,155,60,0.08);";

		filterBar = new HBox();
		filterBar.styleString = "gap: 4px;";
		var filters:Array<{label:String, type:FilterType}> = [
			{label: "All", type: All},
			{label: "Core", type: Core},
			{label: "Good", type: Good},
			{label: "Situational", type: Situational},
			{label: "Weak", type: Weak},
			{label: "Trap", type: Trap},
		];
		for (f in filters) {
			var btn = new Button();
			btn.text = f.label;
			btn.toggle = true;
			btn.selected = f.type == state.currentFilter;
			btn.styleString = "font-size: 11px; padding: 3px 10px;";
			btn.onClick = function(_) {
				onFilterClick(f.type);
			};
			filterBar.addComponent(btn);
		}
		toolbar.addComponent(filterBar);

		// Spacer
		var spacer = new Spacer();
		spacer.percentWidth = 100;
		toolbar.addComponent(spacer);

		itemSearchField = new TextField();
		itemSearchField.placeholder = "Filter items...";
		itemSearchField.width = 180;
		itemSearchField.styleString = "background-color: #111120; color: #DDD0A8; border: 1px solid rgba(200,155,60,0.25); border-radius: 3px; padding: 3px 9px; font-size: 12px;";
		itemSearchField.onChange = function(_) {
			onItemSearch(itemSearchField.text);
		};
		toolbar.addComponent(itemSearchField);

		mainPanel.addComponent(toolbar);

		// Stats summary
		statsLabel = new Label();
		statsLabel.percentWidth = 100;
		statsLabel.styleString = "padding: 4px 20px; font-size: 11px; color: #807060; background-color: #0D0D18; border-bottom: 1px solid rgba(200,155,60,0.06);";
		mainPanel.addComponent(statsLabel);

		// Items grid (VBox for category sections)
		itemGrid = new ScrollView();
		itemGrid.percentWidth = 100;
		itemGrid.percentHeight = 100;
		itemGrid.styleString = "background-color: #08080E;";
		itemGridContent = new VBox();
		itemGridContent.percentWidth = 100;
		itemGrid.addComponent(itemGridContent);
		mainPanel.addComponent(itemGrid);

		body.addComponent(mainPanel);
		root.addComponent(body);
		app.addComponent(root);
	}

	// ── Champion Grid ──────────────────────────────────────────────────────

	public function renderChampionGrid():Void {
		champGridInner.removeAllComponents();
		var champs = state.filteredChampions();
		for (c in champs) {
			var cell = new VBox();
			var isSelected = state.selectedChampion != null && state.selectedChampion.id == c.id;
			cell.width = 56;
			cell.styleString = isSelected
				? "padding: 2px; cursor: pointer; background-color: rgba(200,155,60,0.2); border: 1px solid #C89B3C; border-radius: 3px;"
				: "padding: 2px; cursor: pointer; border: 1px solid transparent; border-radius: 3px;";

			// Champion portrait image
			var img = new Image();
			img.resource = provider.championImageUrl(state.version, c.image.full);
			img.width = 48;
			img.height = 48;
			img.styleString = "border-radius: 3px;";
			cell.addComponent(img);

			// Name label
			var nameLabel = new Label();
			nameLabel.text = c.name;
			nameLabel.styleString = "font-size: 8px; color: #DDD0A8; text-align: center; width: 48px; overflow: hidden;";
			cell.addComponent(nameLabel);

			var champId = c.id;
			cell.onClick = function(_) {
				onChampClick(champId);
			};

			champGridInner.addComponent(cell);
		}
	}

	// ── Champion Info Bar ──────────────────────────────────────────────────

	public function renderChampionInfoBar():Void {
		champInfoBox.removeAllComponents();
		var c = state.selectedChampion;
		if (c == null) {
			var hint = new Label();
			hint.text = "Select a champion to begin";
			hint.styleString = "color: #3A3630; font-size: 13px;";
			champInfoBox.addComponent(hint);
			return;
		}

		// Champion portrait
		var portrait = new Image();
		portrait.resource = provider.championImageUrl(state.version, c.image.full);
		portrait.width = 56;
		portrait.height = 56;
		portrait.styleString = "border-radius: 50%; border: 2px solid #C89B3C;";
		champInfoBox.addComponent(portrait);

		var spacer = new Spacer();
		spacer.width = 12;
		champInfoBox.addComponent(spacer);

		var details = new VBox();
		details.percentWidth = 100;

		// Name + title
		var titleRow = new HBox();
		titleRow.styleString = "gap: 8px;";
		var nameLabel = new Label();
		nameLabel.text = c.name;
		nameLabel.styleString = "font-size: 16px; font-weight: bold; color: #C89B3C;";
		titleRow.addComponent(nameLabel);
		var titleLabel = new Label();
		titleLabel.text = c.title;
		titleLabel.styleString = "font-size: 11px; color: #807060; padding-top: 5px;";
		titleRow.addComponent(titleLabel);
		details.addComponent(titleRow);

		// Tags
		var tagsRow = new HBox();
		tagsRow.styleString = "gap: 4px; padding-top: 3px;";
		for (tag in c.tags) {
			var badge = new Label();
			badge.text = tag.toUpperCase();
			badge.styleString = "font-size: 9px; padding: 1px 7px; border: 1px solid rgba(200,155,60,0.25); color: #807060; border-radius: 2px; letter-spacing: 1;";
			tagsRow.addComponent(badge);
		}
		details.addComponent(tagsRow);

		// Stats
		var st = c.stats;
		var statRow = new HBox();
		statRow.styleString = "gap: 10px; padding-top: 5px;";
		var statPairs:Array<{k:String, v:String}> = [
			{k: "AD", v: Std.string(Math.round(st.attackdamage))},
			{k: "HP", v: Std.string(Math.round(st.hp))},
			{k: "Armor", v: Std.string(Math.round(st.armor))},
			{k: "MR", v: Std.string(Math.round(st.spellblock))},
			{k: "Range", v: Std.string(Math.round(st.attackrange))},
			{k: "AS", v: Std.string(Math.round(st.attackspeed * 100) / 100)},
		];
		for (p in statPairs) {
			var lbl = new Label();
			lbl.text = p.k + " " + p.v;
			lbl.styleString = "font-size: 11px; color: #807060;";
			statRow.addComponent(lbl);
		}
		details.addComponent(statRow);

		// Profile badges
		var profile = state.champProfile;
		if (profile != null) {
			var badgeRow = new HBox();
			badgeRow.styleString = "gap: 4px; padding-top: 5px;";
			var badges:Array<{text:String, bg:String, bd:String, fg:String}> = [];
			if (profile.hasApScaling)  badges.push({text: "AP scaling",  bg: "#1A0A2A", bd: "#6A20AA", fg: "#CC80FF"});
			if (profile.hasAdScaling)  badges.push({text: "AD scaling",  bg: "#2A1500", bd: "#AA6020", fg: "#FFBB60"});
			if (profile.hasOnHit)      badges.push({text: "On-hit",      bg: "#001A2A", bd: "#1060AA", fg: "#60C0FF"});
			if (profile.hasDash)       badges.push({text: "Dash",        bg: "#002A1A", bd: "#10AA60", fg: "#60FFAA"});
			if (profile.hasShield)     badges.push({text: "Shield",      bg: "#00102A", bd: "#1040AA", fg: "#4080FF"});
			if (profile.hasHeal)       badges.push({text: "Heal",        bg: "#0A2000", bd: "#40AA10", fg: "#80FF40"});
			if (profile.hasCc)         badges.push({text: "CC",          bg: "#2A000A", bd: "#AA1040", fg: "#FF4080"});
			if (profile.hasExecute)    badges.push({text: "Execute",     bg: "#2A0A00", bd: "#AA3000", fg: "#FF7040"});
			if (profile.hasStealth)    badges.push({text: "Stealth",     bg: "#1A1A1A", bd: "#606060", fg: "#C0C0C0"});
			if (profile.isManaless)    badges.push({text: "Manaless",    bg: "#100A00", bd: "#605020", fg: "#C0A040"});
			for (b in badges) {
				var lbl = new Label();
				lbl.text = b.text;
				lbl.styleString = 'font-size: 9px; padding: 2px 7px; background-color: ${b.bg}; border: 1px solid ${b.bd}; color: ${b.fg}; border-radius: 2px; font-weight: bold;';
				badgeRow.addComponent(lbl);
			}
			details.addComponent(badgeRow);
		}

		champInfoBox.addComponent(details);
	}

	// ── Mode Tabs ──────────────────────────────────────────────────────────

	public function renderModeTabs():Void {
		for (i in 0...modeBar.childComponents.length) {
			var btn:Button = cast modeBar.childComponents[i];
			var mode = GameModes.ALL[i];
			btn.selected = mode.id == state.currentMode.id;
		}
	}

	// ── Filter Buttons ─────────────────────────────────────────────────────

	public function renderFilterButtons():Void {
		var filters:Array<FilterType> = [All, Core, Good, Situational, Weak, Trap];
		for (i in 0...filterBar.childComponents.length) {
			var btn:Button = cast filterBar.childComponents[i];
			btn.selected = filters[i] == state.currentFilter;
		}
	}

	// ── Items Grid ─────────────────────────────────────────────────────────

	public function renderItemsGrid():Void {
		itemGridContent.removeAllComponents();

		if (state.selectedChampion == null) {
			var placeholder = new VBox();
			placeholder.percentWidth = 100;
			placeholder.styleString = "padding: 60px 20px; horizontal-align: center;";
			var icon = new Label();
			icon.text = "Select a champion to see item synergies";
			icon.styleString = "font-size: 14px; color: #3A3630; text-align: center;";
			placeholder.addComponent(icon);
			itemGridContent.addComponent(placeholder);
			statsLabel.text = "";
			return;
		}

		var items = state.visibleItems();
		if (items.length == 0) {
			var hint = new Label();
			hint.text = "No items match the current filter.";
			hint.styleString = "color: #3A3630; font-size: 14px; padding: 40px 20px;";
			itemGridContent.addComponent(hint);
			statsLabel.text = "";
			return;
		}

		// Stats summary
		if (state.synergiesComputed) {
			var coreCount = 0;
			var goodCount = 0;
			var sitCount = 0;
			var weakCount = 0;
			var trapCount = 0;
			for (_ => syn in state.synergies) {
				switch (syn.tier) {
					case Core: coreCount++;
					case Good: goodCount++;
					case Situational: sitCount++;
					case Weak: weakCount++;
					case Trap: trapCount++;
				}
			}
			statsLabel.text = coreCount + " core · " + goodCount + " good · " + sitCount + " situational · " + weakCount + " weak · " + trapCount + " trap · " + state.currentMode.label;
		}

		// Group items by category
		var grouped = new Map<Int, Array<{id:String, item:ItemData, synergy:Null<SynergyResult>}>>();
		for (entry in items) {
			var cat = ItemCategoryTools.fromTags(entry.item.tags);
			var idx = ItemCategoryTools.displayOrder.indexOf(cat);
			if (idx < 0)
				idx = ItemCategoryTools.displayOrder.length;
			if (!grouped.exists(idx))
				grouped.set(idx, []);
			grouped.get(idx).push(entry);
		}

		// Render each category
		for (cat in ItemCategoryTools.displayOrder) {
			var idx = ItemCategoryTools.displayOrder.indexOf(cat);
			var catItems = grouped.get(idx);
			if (catItems == null || catItems.length == 0)
				continue;

			var catLabel = ItemCategoryTools.label(cat);

			// Category header
			var catHeader = new HBox();
			catHeader.percentWidth = 100;
			catHeader.styleString = "padding: 6px 20px 4px 20px; border-bottom: 1px solid rgba(200,155,60,0.25); gap: 8px;";

			var catName = new Label();
			catName.text = catLabel;
			catName.styleString = "font-size: 14px; font-weight: bold; color: " + catColor(cat) + ";";
			catHeader.addComponent(catName);

			var catCount = new Label();
			catCount.text = Std.string(catItems.length);
			catCount.styleString = "font-size: 11px; color: #807060; padding-top: 3px;";
			catHeader.addComponent(catCount);

			itemGridContent.addComponent(catHeader);

			// Item cards grid
			var grid = new Grid();
			grid.columns = 8;
			grid.percentWidth = 100;
			grid.styleString = "padding: 10px 16px; gap: 5px;";

			for (entry in catItems) {
				var item = entry.item;
				var syn = entry.synergy;

				var card = new VBox();
				card.width = 88;
				card.styleString = buildCardStyle(syn);

				// Item icon
				var img = new Image();
				img.resource = provider.itemImageUrl(state.version, item.image.full);
				img.width = 44;
				img.height = 44;
				img.styleString = "border-radius: 3px; horizontal-align: center;";
				card.addComponent(img);

				// Item name
				var nameLabel = new Label();
				nameLabel.text = item.name;
				nameLabel.styleString = "font-size: 8px; text-align: center; width: 80px; color: " + nameColor(syn) + ";";
				card.addComponent(nameLabel);

				// Tier indicator
				if (syn != null) {
					var tierLabel = new Label();
					tierLabel.text = tierText(syn.tier) + " " + syn.score + "/10";
					tierLabel.styleString = "font-size: 8px; color: " + tierColor(syn.tier) + "; text-align: center; width: 80px;";
					card.addComponent(tierLabel);
				}

				// Cost
				var cost = item.gold != null ? item.gold.total : 0;
				if (cost > 0) {
					var costLabel = new Label();
					costLabel.text = formatCost(cost) + "g";
					costLabel.styleString = "font-size: 8px; color: #7A5C1E; text-align: center; width: 80px;";
					card.addComponent(costLabel);
				}

				grid.addComponent(card);
			}

			itemGridContent.addComponent(grid);
		}
	}

	// ── Helpers ─────────────────────────────────────────────────────────────

	function buildCardStyle(syn:Null<SynergyResult>):String {
		if (syn == null)
			return "padding: 5px; background-color: #161625; border: 1px solid rgba(200,155,60,0.25); border-radius: 4px;";
		return switch (syn.tier) {
			case Core:        "padding: 5px; background-color: #1A2A10; border: 1px solid #3A6A1A; border-radius: 4px;";
			case Good:        "padding: 5px; background-color: #102A15; border: 1px solid #1A6030; border-radius: 4px;";
			case Situational: "padding: 5px; background-color: #1A1A0E; border: 1px solid #4A4A1A; border-radius: 4px;";
			case Weak:        "padding: 5px; background-color: #2A1510; border: 1px solid #603020; border-radius: 4px; opacity: 0.75;";
			case Trap:        "padding: 5px; background-color: #2A1010; border: 1px solid #6A1A1A; border-radius: 4px; opacity: 0.6;";
		};
	}

	static function nameColor(syn:Null<SynergyResult>):String {
		if (syn == null)
			return "#807060";
		return switch (syn.tier) {
			case Core: "#80EE50";
			case Good: "#50DA80";
			case Situational: "#C8C050";
			case Weak: "#DA8050";
			case Trap: "#EE5050";
		};
	}

	static function catColor(cat:ItemCategory):String {
		return switch (cat) {
			case Mage: "#7BA4F0";
			case Assassin: "#E06060";
			case Marksman: "#E0A050";
			case Fighter: "#C89B3C";
			case Tank: "#80A8C0";
			case Support: "#60D0A0";
			case Boots: "#B088D0";
			case Other: "#807060";
		};
	}

	static function tierText(tier:SynergyTier):String {
		return switch (tier) {
			case Core: "Core";
			case Good: "Good";
			case Situational: "Sit";
			case Weak: "Weak";
			case Trap: "Trap";
		};
	}

	static function tierColor(tier:SynergyTier):String {
		return switch (tier) {
			case Core: "#80EE50";
			case Good: "#50DA80";
			case Situational: "#C8C050";
			case Weak: "#DA8050";
			case Trap: "#EE5050";
		};
	}

	static function formatCost(n:Int):String {
		var str = Std.string(n);
		var result = "";
		var count = 0;
		var i = str.length - 1;
		while (i >= 0) {
			if (count > 0 && count % 3 == 0)
				result = "," + result;
			result = str.charAt(i) + result;
			count++;
			i--;
		}
		return result;
	}
}
