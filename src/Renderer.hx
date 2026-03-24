#if js
package forge.ui;

import js.html.*;
import forge.AppState;
import forge.data.Types;
import forge.data.GameModes;
import forge.data.IDataProvider;
#end

/**
 * All DOM rendering lives here.
 * Called by Main whenever state changes.
 */
class Renderer {

	var state: AppState;
	var provider: IDataProvider;
	var onChampClick: (String) -> Void;
	var onModeClick: (String) -> Void;
	var onFilterClick: (FilterType) -> Void;
	var onChampSearch: (String) -> Void;
	var onItemSearch: (String) -> Void;

	// Cached DOM nodes
	var champGrid: Element;
	var champInfoBar: Element;
	var itemsToolbar: Element;
	var mainContent: Element;
	var tooltip: Element;

	public function new(
		state: AppState,
		provider: IDataProvider,
		onChampClick: (String) -> Void,
		onModeClick: (String) -> Void,
		onFilterClick: (FilterType) -> Void,
		onChampSearch: (String) -> Void,
		onItemSearch: (String) -> Void
	) {
		this.state = state;
		this.provider = provider;
		this.onChampClick = onChampClick;
		this.onModeClick = onModeClick;
		this.onFilterClick = onFilterClick;
		this.onChampSearch = onChampSearch;
		this.onItemSearch = onItemSearch;

		champGrid    = js.Browser.document.getElementById("championGrid");
		champInfoBar = js.Browser.document.getElementById("championInfoBar");
		itemsToolbar = js.Browser.document.getElementById("itemsToolbar");
		mainContent  = js.Browser.document.getElementById("mainContent");
		tooltip      = js.Browser.document.getElementById("itemTooltip");

		bindStaticEvents();
	}

	// ── Champion Grid ─────────────────────────────────────────────────────────

	public function renderChampionGrid(): Void {
		if (state.isLoadingChampions) {
			champGrid.innerHTML = '<div class="loading-msg">Loading champions…</div>';
			return;
		}
		var champs = state.filteredChampions();
		if (champs.length == 0) {
			champGrid.innerHTML = '<div class="loading-msg">No champions found</div>';
			return;
		}

		var html = new StringBuf();
		for (c in champs) {
			var sel = state.selectedChampion != null && state.selectedChampion.id == c.id ? " selected" : "";
			var imgUrl = provider.championImageUrl(state.version, c.image.full);
			html.add('<div class="champ-portrait$sel" data-id="${c.id}" title="${c.name}">');
			html.add('<img src="$imgUrl" alt="${c.name}" loading="lazy">');
			html.add('<div class="champ-name">${c.name}</div>');
			html.add('</div>');
		}
		champGrid.innerHTML = html.toString();

		// Bind click events
		var portraits = champGrid.querySelectorAll(".champ-portrait");
		for (i in 0...portraits.length) {
			var el: Element = cast portraits.item(i);
			el.addEventListener("click", function(_) {
				var id = el.getAttribute("data-id");
				if (id != null) onChampClick(id);
			});
		}
	}

	// ── Champion Info Bar ─────────────────────────────────────────────────────

	public function renderChampionInfoBar(): Void {
		if (state.isLoadingDetail) {
			champInfoBar.innerHTML = '<div class="loading-msg" style="width:100%">Loading…</div>';
			return;
		}
		var c = state.selectedChampion;
		if (c == null) {
			champInfoBar.innerHTML = '<p class="hint-text">← Select a champion to begin</p>';
			return;
		}

		var imgUrl = provider.championImageUrl(state.version, c.image.full);
		var tags = c.tags.map(t -> '<span class="champ-tag">$t</span>').join("");
		var st = c.stats;

		var profile = state.champProfile;
		var profileBadges = "";
		if (profile != null) {
			var badges: Array<String> = [];
			if (profile.hasApScaling) badges.push('<span class="badge badge-ap">AP scaling</span>');
			if (profile.hasAdScaling) badges.push('<span class="badge badge-ad">AD scaling</span>');
			if (profile.hasOnHit)     badges.push('<span class="badge badge-onhit">On-hit</span>');
			if (profile.hasDash)      badges.push('<span class="badge badge-mobility">Dash</span>');
			if (profile.hasShield)    badges.push('<span class="badge badge-shield">Shield</span>');
			if (profile.hasHeal)      badges.push('<span class="badge badge-heal">Heal</span>');
			if (profile.hasCc)        badges.push('<span class="badge badge-cc">CC</span>');
			if (profile.hasExecute)   badges.push('<span class="badge badge-execute">Execute</span>');
			if (profile.hasStealth)   badges.push('<span class="badge badge-stealth">Stealth</span>');
			if (profile.isManaless)   badges.push('<span class="badge badge-manaless">Manaless</span>');
			profileBadges = '<div class="profile-badges">${badges.join("")}</div>';
		}

		champInfoBar.innerHTML = '
			<img class="champ-big-portrait" src="$imgUrl" alt="${c.name}">
			<div class="champ-details">
				<h2>${c.name} <span class="champ-title">${c.title}</span></h2>
				<div class="champ-tags">$tags</div>
				<div class="stat-row">
					<span>AD <b>${Math.round(st.attackdamage)}</b></span>
					<span>HP <b>${Math.round(st.hp)}</b></span>
					<span>Armor <b>${Math.round(st.armor)}</b></span>
					<span>MR <b>${Math.round(st.spellblock)}</b></span>
					<span>Range <b>${Math.round(st.attackrange)}</b></span>
					<span>AS <b>${Math.round(st.attackspeed * 100) / 100}</b></span>
				</div>
				$profileBadges
			</div>
		';
	}

	// ── Items Toolbar ─────────────────────────────────────────────────────────

	public function renderItemsToolbar(): Void {
		var visible = state.selectedChampion != null;
		js.Lib.nativeThis; // suppress warning
		cast(itemsToolbar, HTMLElement).style.display = visible ? "flex" : "none";
		if (!visible) return;

		// Update filter button active states
		var btns = itemsToolbar.querySelectorAll(".filter-btn");
		for (i in 0...btns.length) {
			var btn: Element = cast btns.item(i);
			var f = btn.getAttribute("data-filter");
			var isActive = switch state.currentFilter {
				case All: f == "all";
				case Good: f == "good";
				case Weak: f == "weak";
				case Situational: f == "situational";
			};
			btn.className = 'filter-btn f-$f${isActive ? " active" : ""}';
		}

		// Update mode tabs
		var tabs = js.Browser.document.querySelectorAll(".mode-tab");
		for (i in 0...tabs.length) {
			var tab: Element = cast tabs.item(i);
			var isActive = tab.getAttribute("data-mode") == state.currentMode.id;
			tab.className = 'mode-tab${isActive ? " active" : ""}';
		}
	}

	// ── Items Grid ────────────────────────────────────────────────────────────

	public function renderItemsGrid(): Void {
		if (state.selectedChampion == null) {
			mainContent.innerHTML = '
				<div class="placeholder">
					<div class="placeholder-icon">⚔</div>
					<p>Select a champion to see item synergies.<br>
					<span>The rules engine will evaluate each item based on abilities, scalings, and role.</span></p>
				</div>';
			return;
		}

		var items = state.visibleItems();
		if (items.length == 0) {
			mainContent.innerHTML = '<div class="placeholder"><p>No items match the current filter.</p></div>';
			return;
		}

		// Stats header
		var total = state.filteredItems.length;
		var coreCount = 0; var goodCount = 0; var sitCount = 0; var weakCount = 0; var trapCount = 0;
		for (_ => syn in state.synergies) {
			switch syn.tier {
				case Core:        coreCount++;
				case Good:        goodCount++;
				case Situational: sitCount++;
				case Weak:        weakCount++;
				case Trap:        trapCount++;
			}
		}

		var statsHtml = state.synergiesComputed ? '
			<div class="synergy-stats">
				<span class="ss-core">${coreCount} core</span> ·
				<span class="ss-good">${goodCount} good</span> ·
				<span class="ss-sit">${sitCount} situational</span> ·
				<span class="ss-weak">${weakCount} weak</span> ·
				<span class="ss-trap">${trapCount} trap</span>
				<span class="ss-mode">· ${state.currentMode.label}</span>
			</div>' : '';

		var html = new StringBuf();
		html.add(statsHtml);
		html.add('<div class="items-grid" id="itemsGrid">');

		for (entry in items) {
			var item = entry.item;
			var syn = entry.synergy;
			var imgUrl = provider.itemImageUrl(state.version, item.image.full);

			var tierClass = syn != null ? switch syn.tier {
				case Core: "tier-core";
				case Good: "tier-good";
				case Situational: "tier-sit";
				case Weak: "tier-weak";
				case Trap: "tier-trap";
			} : "";

			var badge = syn != null ? switch syn.tier {
				case Core: '<div class="syn-badge core">★</div>';
				case Good: '<div class="syn-badge good">✓</div>';
				case Situational: "";
				case Weak: '<div class="syn-badge weak">−</div>';
				case Trap: '<div class="syn-badge trap">✗</div>';
			} : "";

			var scoreStr = syn != null ? Std.string(syn.score) : "";
			var reasonsStr = syn != null ? syn.reasons.join("|") : "";
			var costStr = item.gold != null ? Std.string(item.gold.total) : "0";
			// Strip HTML from description for tooltip
			var cleanDesc = ~/(<[^>]+>)/g.replace(item.description != null ? item.description : "", "");
			cleanDesc = ~/\s+/g.replace(cleanDesc, " ").substr(0, 180);

			html.add('
				<div class="item-card $tierClass"
						data-id="${entry.id}"
						data-name="${escapeAttr(item.name)}"
						data-desc="${escapeAttr(cleanDesc)}"
						data-cost="$costStr"
						data-score="$scoreStr"
						data-tier="${tierClass}"
						data-reasons="${escapeAttr(reasonsStr)}">
					$badge
					<img src="$imgUrl" alt="${escapeAttr(item.name)}" loading="lazy">
					<div class="item-name">${item.name}</div>
				</div>');
		}

		html.add('</div>');
		mainContent.innerHTML = html.toString();

		// Bind tooltip events
		var cards = mainContent.querySelectorAll(".item-card");
		for (i in 0...cards.length) {
			var card: Element = cast cards.item(i);
			card.addEventListener("mouseenter", function(e) showTooltip(e, card));
			card.addEventListener("mouseleave", function(_) hideTooltip());
		}
	}

	// ── Tooltip ───────────────────────────────────────────────────────────────

	function showTooltip(e: Event, el: Element): Void {
		var name    = el.getAttribute("data-name") ?? "";
		var desc    = el.getAttribute("data-desc") ?? "";
		var cost    = el.getAttribute("data-cost") ?? "0";
		var score   = el.getAttribute("data-score") ?? "";
		var tier    = el.getAttribute("data-tier") ?? "";
		var reasons = el.getAttribute("data-reasons") ?? "";

		var reasonList = reasons != "" ? reasons.split("|") : [];
		var reasonHtml = "";
		if (reasonList.length > 0) {
			var items = reasonList.map(r -> '<li>$r</li>').join("");
			var cls = tier.indexOf("core") >= 0 || tier.indexOf("good") >= 0 ? "pos" : 
								tier.indexOf("weak") >= 0 || tier.indexOf("trap") >= 0 ? "neg" : "neu";
			var label = switch tier {
				case "tier-core": "★ Core item (${score}/10)";
				case "tier-good": "✓ Good pick (${score}/10)";
				case "tier-sit":  "◎ Situational (${score}/10)";
				case "tier-weak": "− Weak pick (${score}/10)";
				case "tier-trap": "✗ Stat trap (${score}/10)";
				default: "";
			};
			if (label != "") {
				reasonHtml = '<div class="tt-reasons $cls"><strong>$label</strong><ul>$items</ul></div>';
			}
		} else if (state.selectedChampion != null && !state.synergiesComputed) {
			reasonHtml = '<div class="tt-reasons neu"><em>Synergies not computed yet.</em></div>';
		}

		tooltip.innerHTML = '
			<div class="tt-header">
				<span class="tt-name">$name</span>
				<span class="tt-cost">🪙 ${formatCost(cost)}</span>
			</div>
			<div class="tt-desc">${desc}${desc.length >= 178 ? "…" : ""}</div>
			$reasonHtml
		';
		tooltip.className = "item-tooltip visible";
		positionTooltip(cast e);
	}

	function hideTooltip(): Void {
		tooltip.className = "item-tooltip";
	}

	function positionTooltip(e: MouseEvent): Void {
		var tt: HTMLElement = cast tooltip;
		var pad = 14;
		var x = e.clientX + pad;
		var y = e.clientY + pad;
		if (x + 280 > js.Browser.window.innerWidth)  x = e.clientX - 280 - pad;
		if (y + tt.offsetHeight > js.Browser.window.innerHeight) y = e.clientY - tt.offsetHeight - pad;
		tt.style.left = '${x}px';
		tt.style.top  = '${y}px';
	}

	// ── Static event binding ──────────────────────────────────────────────────

	function bindStaticEvents(): Void {
		// Mode tabs
		var modeTabs = js.Browser.document.querySelectorAll(".mode-tab");
		for (i in 0...modeTabs.length) {
			var tab: Element = cast modeTabs.item(i);
			tab.addEventListener("click", function(_) {
				var mode = tab.getAttribute("data-mode");
				if (mode != null) onModeClick(mode);
			});
		}

		// Filter buttons
		var filterBtns = js.Browser.document.querySelectorAll(".filter-btn");
		for (i in 0...filterBtns.length) {
			var btn: Element = cast filterBtns.item(i);
			btn.addEventListener("click", function(_) {
				var f = btn.getAttribute("data-filter");
				if (f == null) return;
				onFilterClick(switch f {
					case "good": Good;
					case "weak": Weak;
					case "situational": Situational;
					default: All;
				});
			});
		}

		// Champion search
		var champSearchEl: HTMLInputElement = cast js.Browser.document.getElementById("champSearch");
		if (champSearchEl != null) {
			champSearchEl.addEventListener("input", function(_) {
				onChampSearch(champSearchEl.value);
			});
		}

		// Item search
		var itemSearchEl: HTMLInputElement = cast js.Browser.document.getElementById("itemSearch");
		if (itemSearchEl != null) {
			itemSearchEl.addEventListener("input", function(_) {
				onItemSearch(itemSearchEl.value);
			});
		}

		// Tooltip tracking
		js.Browser.document.addEventListener("mousemove", function(e: Event) {
			if (tooltip.className.indexOf("visible") >= 0) {
				positionTooltip(cast e);
			}
		});
	}

	// ── Helpers ───────────────────────────────────────────────────────────────

	static function escapeAttr(s: String): String {
		return s.split('"').join("&quot;").split("'").join("&#39;");
	}

	static function formatCost(s: String): String {
		var n = Std.parseInt(s);
		if (n == null) return s;
		// Format with thousands separator
		var str = Std.string(n);
		var result = "";
		var count = 0;
		var i = str.length - 1;
		while (i >= 0) {
			if (count > 0 && count % 3 == 0) result = "," + result;
			result = str.charAt(i) + result;
			count++;
			i--;
		}
		return result;
	}
}
#end
