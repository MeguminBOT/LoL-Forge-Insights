package tools;

import forge.rules.ItemClassifier;
import forge.rules.ProfileBuilder;
import forge.rules.SynergyEngine;
import forge.data.ItemData;
import forge.data.ChampionDetail;

class DebugSynergy {
	static public function main() {
		// Minimal Kayn-like champion profile
		var kayn:ChampionDetail = {
			id: "Kayn",
			name: "Kayn",
			title: "the Shadow Reaper",
			image: null,
			tags: ["Fighter", "Assassin"],
			partype: "None",
			stats: {
				hp: 655,
				hpperlevel: 90,
				mp: 0,
				mpperlevel: 0,
				movespeed: 340,
				armor: 32,
				armorperlevel: 3.5,
				spellblock: 32,
				spellblockperlevel: 1.25,
				attackrange: 175,
				hpregen: 8,
				hpregenperlevel: 0.8,
				mpregen: 0,
				mpregenperlevel: 0,
				crit: 0,
				critperlevel: 0,
				attackdamage: 68,
				attackdamageperlevel: 4.5,
				attackspeedperlevel: 0.02,
				attackspeed: 0.67
			},
			passive: null,
			spells: [],
			info: {
				attack: 6,
				defense: 4,
				magic: 2,
				difficulty: 3
			},
			lore: ""
		};

		var champProfile = ProfileBuilder.build(kayn);

		var rift:ItemData = {
			name: "Riftmaker",
			description: "70 Ability Power350 Health15 Ability HasteVoid CorruptionFor each second in combat with enemy champions, deal 2% bonus damage, up to 8%. At maximum strength, gain Omnivamp.",
			image: null,
			gold: {
				total: 3100,
				base: 0,
				sell: 0,
				purchasable: true
			},
			tags: [],
			maps: null,
			stats: {abilityPower: {flat: 70, percent: 0}},
			from: null,
			into: null,
			depth: 3,
			consumed: false,
			inStore: true,
			hideFromAll: false,
			requiredChampion: null,
			requiredAlly: null,
			effect: null,
		};

		var ardent:ItemData = {
			name: "Ardent Censer",
			description: "When you heal or shield an allied champion, grant them bonus attack speed and on-hit magic damage for a short time.",
			image: null,
			gold: {
				total: 2500,
				base: 0,
				sell: 0,
				purchasable: true
			},
			tags: [],
			maps: null,
			stats: {abilityPower: {flat: 60, percent: 0}},
			from: null,
			into: null,
			depth: 3,
			consumed: false,
			inStore: true,
			hideFromAll: false,
			requiredChampion: null,
			requiredAlly: null,
			effect: null,
		};

		var riftProfile = ItemClassifier.classify("riftmaker", rift);
		var ardentProfile = ItemClassifier.classify("ardent", ardent);

		var riftScore = SynergyEngine.score(champProfile, riftProfile);
		var ardentScore = SynergyEngine.score(champProfile, ardentProfile);

		trace("Champion: " + champProfile.name);
		trace("Item: "
			+ riftProfile.name
			+ " => score="
			+ riftScore.score
			+ " tier="
			+ riftScore.tier
			+ " reasons="
			+ riftScore.reasons.join(", "));
		trace("Item: "
			+ ardentProfile.name
			+ " => score="
			+ ardentScore.score
			+ " tier="
			+ ardentScore.tier
			+ " reasons="
			+ ardentScore.reasons.join(", "));
	}
}
