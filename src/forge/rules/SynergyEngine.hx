package forge.rules;

import forge.data.SynergyResult;
import forge.data.SynergyTier;

/**
 * Scores how well an item synergises with a champion profile.
 *
 * Rules are one-directional and non-overlapping — each condition fires
 * at most once. Starting score is 5 (neutral). Rules add or subtract.
 * Final score is clamped [0..10] then bucketed into a SynergyTier.
 *
 * Tier thresholds:
 *   9–10  Core        (build this every game)
 *   7–8   Good        (strong pick)
 *   5–6   Situational (fine, not optimal)
 *   3–4   Weak        (rarely worth it)
 *   0–2   Trap        (wastes primary stats)
 */
class SynergyEngine {
	public static function score(champ:ChampionProfile, item:ItemProfile):SynergyResult {
		var s = 5;
		var reasons:Array<{delta:Int, r:String}> = [];

		inline function pos(n:Int, r:String) {
			s += n;
			reasons.push({delta: n, r: r});
		}
		inline function neg(n:Int, r:String) {
			s -= n;
			reasons.push({delta: -n, r: r});
		}

		// ── 1. SUPPORT ITEMS (not just income — all SUPPORT-tagged items) ──────
		if (item.isSupportItem && !item.isSupportIncome) {
			if (champ.isSupport)
				pos(2, "Support item fits support role");
			else
				neg(4, "Support item ineffective outside support role");
		}
		if (item.isSupportIncome) {
			if (champ.isSupport)
				pos(2, "Support income item fits support role");
			else
				neg(4, "Support income item wasted on non-support");
		}

		// ── 2. MANA / ENERGY STAT WASTE ────────────────────────────────────────
		if (champ.isManaless) {
			if (item.hasManaScaling)
				neg(6, "Mana-scaling passive completely useless without mana");
			else if (item.givesMana)
				neg(2, "Mana stat wasted — champion has no mana");
			if (item.givesManaRegen)
				neg(1, "Mana regen wasted — champion has no mana");
		}

		// ── 3. AP STAT ─────────────────────────────────────────────────────────
		if (item.givesAp) {
			if (champ.hasApScaling)
				pos(2, champ.name + " has AP scaling — amplifies ability damage");
			else
				neg(4, champ.name + " has no meaningful AP ratios — stat wasted");
		}

		// ── 4. MAGIC PENETRATION ───────────────────────────────────────────────
		if (item.givesMagicPen) {
			if (champ.hasApScaling)
				pos(2, "Magic pen amplifies " + champ.name + "'s AP damage");
			else
				neg(4, champ.name + " deals no magic damage — pen wasted");
		}

		// ── 5. AD STAT ─────────────────────────────────────────────────────────
		if (item.givesAd) {
			if (champ.hasAdScaling)
				pos(2, champ.name + " has AD scaling — scales abilities and autos");
			else if (champ.hasOnHit)
				pos(1, "AD mildly useful on " + champ.name + " (on-hit base)");
			else
				neg(3, champ.name + " has no AD scaling — stat wasted");
		}

		// ── 6. LETHALITY & ARMOR PENETRATION ──────────────────────────────────
		if (item.givesLethality || item.givesArmorPen) {
			if (champ.hasApScaling && !champ.hasAdScaling) {
				neg(4, "Armor pen wasted — champion deals magic not physical damage");
			} else if (champ.isAssassin) {
				pos(3, "Armor pen core on assassination kit");
			} else if (champ.hasAdScaling) {
				pos(1, "Armor pen helps physical damage");
			}
		}

		// ── 7. ATTACK SPEED ────────────────────────────────────────────────────
		if (item.givesAs) {
			if (champ.isMarksman)
				pos(2, "Attack speed core on " + champ.name + " (marksman)");
			else if (champ.hasOnHit || champ.hasAutoResets)
				pos(2, champ.name + " has on-hit/auto-reset kit — AS procs frequently");
			else if (champ.isFighter && champ.hasAdScaling)
				pos(1, "Attack speed helps auto-reliant " + champ.name);
			else if (champ.isMage && !champ.hasOnHit)
				neg(2, champ.name + " is ability-focused — AS wasted");
		}

		// ── 8. ON-HIT PASSIVE ──────────────────────────────────────────────────
		if (item.hasOnHitPassive && !item.isSupportOnHit) {
			if (champ.isMarksman)
				pos(2, "On-hit procs with every " + champ.name + " auto — ideal");
			else if (champ.hasOnHit || champ.hasAutoResets)
				pos(2, champ.name + " has on-hit/reset kit — passive synergises");
			else if (champ.isFighter && champ.hasAdScaling)
				pos(1, "On-hit has value on auto-attacking " + champ.name);
			else if (champ.isMage && !champ.hasOnHit)
				neg(2, champ.name + " rarely auto-attacks — on-hit wasted");
		}

		// ── 8b. SUPPORT ON-HIT (Ardent Censer, etc.) ──────────────────────────
		if (item.isSupportOnHit) {
			if (champ.isSupport && (champ.hasHeal || champ.hasShield))
				pos(2, "Support on-hit buff benefits allies through heal/shield triggers");
			else if (champ.isSupport)
				pos(1, "Support can occasionally proc ally on-hit buff");
			else
				neg(2, "Ally on-hit buff requires healing/shielding an ally to activate");
		}

		// ── 9. CRIT ────────────────────────────────────────────────────────────
		if (item.givesCrit) {
			if (champ.isMarksman) {
				pos(2, "Crit scales strongly with " + champ.name + "'s auto-attack kit");
			} else if (champ.hasCritSynergy) {
				pos(2, champ.name + " has crit-scaling abilities — amplified by crit");
			} else if (champ.hasAdScaling && champ.attackRating >= 8) {
				pos(1, champ.name + " auto-attacks enough for some crit value");
			} else {
				neg(4, champ.name + " doesn't rely on critical strikes — wasted");
			}
		}

		// ── 10. SPELLBLADE / SHEEN ─────────────────────────────────────────────
		if (item.hasSpellblade) {
			if (champ.hasAutoResets)
				pos(2, champ.name + " has auto resets — Spellblade procs frequently");
			else if (champ.isFighter && champ.hasAdScaling)
				pos(2, "Spellblade fits " + champ.name + "'s auto-weaving pattern");
			else if (champ.isMage && !champ.hasAutoResets)
				neg(1, champ.name + " struggles to proc Spellblade consistently");
		}

		// ── 11. LIFESTEAL ──────────────────────────────────────────────────────
		if (item.givesLifesteal) {
			if (champ.isMarksman || (champ.hasAdScaling && champ.attackRating >= 6))
				pos(2, "Lifesteal sustains through frequent autos");
			else if (champ.hasApScaling && !champ.hasAdScaling)
				neg(2, "Lifesteal only works on physical auto attacks");
		}

		// ── 12. OMNIVAMP ───────────────────────────────────────────────────────
		if (item.givesOmnivamp) {
			if (champ.hasApScaling || champ.hasAdScaling)
				pos(1, "Omnivamp sustains through all damage types");
			if (champ.hasDoT)
				pos(1, "Omnivamp applies to DoT damage — extra sustain");
		}

		// ── 13. MANA SCALING PASSIVES (Tear-family) ─────────────────────────
		if (item.hasManaScaling && !champ.isManaless) {
			if (champ.isHighMana && champ.isMage)
				pos(2, "Large mana pool maximises mana-scaling passive");
			else if (champ.isHighMana)
				pos(1, "Mana-scaling passive benefits from high mana");
		}

		// ── 14. MANA STAT ──────────────────────────────────────────────────────
		if (item.givesMana && !champ.isManaless) {
			if (champ.isMage || champ.isHighMana)
				pos(1, "Mana sustains extended spell casting");
		}

		// ── 15. ARMOR / MR / HP ────────────────────────────────────────────────
		if (item.givesArmor || item.givesMr || item.givesHp) {
			if (champ.isTank) {
				pos(2, "Defensive stats core on tank");
				if (item.givesArmor && item.givesHp)
					pos(1, "Dual defensive stats ideal for frontline");
			} else if (champ.defenseRating >= 6) {
				pos(1, "Defensive stats match durable playstyle");
			} else if (champ.isMarksman) {
				neg(1, "Defensive stats suboptimal — marksman needs offensive items");
			} else if (champ.isAssassin) {
				neg(1, "Defensive stats reduce burst window for assassin");
			}
		}

		// ── 16. TENACITY ───────────────────────────────────────────────────────
		if (item.givesTenacity) {
			if (champ.isTank || champ.isFighter)
				pos(1, "Tenacity valuable on melee frontliners");
		}

		// ── 17. MOVEMENT SPEED (non-boots) ────────────────────────────────────
		if (item.givesMs && !item.isBoots) {
			if (champ.hasDash || champ.isAssassin)
				pos(1, "Extra MS enhances mobility kit");
		}

		// ── 18. ABILITY HASTE ──────────────────────────────────────────────────
		if (item.givesAh) {
			if (champ.isMage || champ.isSupport)
				pos(1, "Ability haste improves spell uptime");
			if (champ.hasCc)
				pos(1, "More haste means more CC uptime");
			if (champ.isFighter && champ.hasAdScaling)
				pos(1, "Ability haste helps sustained fighter damage");
		}

		// ── 19. SHIELD PASSIVE ─────────────────────────────────────────────────
		if (item.hasShieldPassive) {
			if (champ.isTank || champ.isSupport)
				pos(1, "Shield passive aids frontline or support role");
			if (champ.hasShield)
				pos(1, "Stacks with champion's own shielding kit");
		}

		// ── 20. ANTI-HEAL ──────────────────────────────────────────────────────
		// Situational by nature — we don't adjust score by kit.
		// Leave as neutral contribution.

		// ── 21. EXECUTE PASSIVE ────────────────────────────────────────────────
		if (item.hasExecutePassive) {
			if (champ.isAssassin)
				pos(1, "Execute passive helps secure kills");
			if (champ.hasExecute)
				pos(1, "Stacks with champion's own execute mechanic");
		}

		// ── 22. DOT PASSIVE ────────────────────────────────────────────────────
		if (item.hasDoTPassive && champ.hasDoT) {
			pos(1, "Item DoT complements champion's own damage-over-time");
		}

		// ── 23. DASH ACTIVE ────────────────────────────────────────────────────
		if (item.hasDashActive) {
			if (champ.isAssassin || champ.isFighter)
				pos(1, "Active dash enables repositioning in melee range");
			else if (champ.isTank)
				neg(1, "Active dash less useful on engage tank with own CC");
		}

		// ── 24. SUPPORT-INCOME ITEM AP/AH BONUS ───────────────────────────────
		// Some support income items (e.g. Shard of True Ice) give AP + AH.
		// Already handled by AP/AH rules above. No double-count needed.

		// ── 25. HEALING/SHIELDING ENHANCEMENT (Spirit Visage etc.) ────────────
		if (item.enhancesHealing) {
			if (champ.hasHeal || champ.hasShield)
				pos(2, "Enhances champion's self-healing and shielding");
			if (champ.isTank || champ.defenseRating >= 6)
				pos(1, "Healing enhancement benefits durable frontliner");
		}

		// ── 26. RANGED-ONLY ITEMS (Runaan's Hurricane etc.) ───────────────────
		if (item.isRangedOnly && champ.range == RangeType.Melee) {
			s = 0;
			reasons = [{delta: -10, r: "Item only works on ranged champions — useless on melee"}];
		}

		// ── SPECIAL CASES: Boots ───────────────────────────────────────────────
		if (item.isBoots) {
			// Reset to 5 and re-evaluate just for boots-specific logic
			s = 5;
			reasons = [];
			if (item.givesMagicPen && champ.hasApScaling) {
				pos(2, "Magic pen boots amplify AP damage");
			} else if (item.givesMagicPen && !champ.hasApScaling) {
				neg(2, "Magic pen boots wasted — no magic damage");
			}
			if (item.givesAs && (champ.isMarksman || champ.hasOnHit)) {
				pos(2, "Attack speed boots suit auto-attack kit");
			} else if (item.givesAs && champ.isMage) {
				neg(1, "Attack speed boots wasteful on mage");
			}
			if (item.givesLethality && champ.isAssassin) {
				pos(2, "Lethality boots fit assassination playstyle");
			} else if (item.givesLethality && champ.hasApScaling && !champ.hasAdScaling) {
				neg(2, "Lethality boots wasted on AP champion");
			}
			if (item.givesAh) {
				pos(1, "Ability haste boots broadly useful");
			}
			if (item.givesTenacity) {
				pos(1, "Tenacity boots useful into CC-heavy compositions");
			}
			if (item.givesMs && champ.isMage) {
				pos(1, "Mobility boots help mage kite and dodge");
			}
		}

		// ── TRINKETS: always neutral ───────────────────────────────────────────
		if (item.isTrinket) {
			s = 5;
			reasons = [];
		}

		// ── CLAMP & TIER ──────────────────────────────────────────────────────
		var clamped = Std.int(Math.max(0, Math.min(10, s)));

		var tier:SynergyTier = switch clamped {
			case 9 | 10: Core;
			case 7 | 8: Good;
			case 5 | 6: Situational;
			case 3 | 4: Weak;
			default: Trap;
		}

		// Return top 5 reasons by absolute impact, prefixed with delta sign
		reasons.sort(function(a, b) return Std.int(Math.abs(b.delta) - Math.abs(a.delta)));
		var topReasons = reasons.slice(0, 5).map(function(x) {
			var sign = x.delta >= 0 ? "+" : "";
			return sign + Std.string(x.delta) + " " + x.r;
		});

		return {
			itemId: item.id,
			score: clamped,
			tier: tier,
			reasons: topReasons,
			// Kept for compatibility — empty since we removed per-ability tracking
			affectedAbilities: [],
		};
	}
}
