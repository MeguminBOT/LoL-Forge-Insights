# LoL-Forge-Insights

Think beyond the meta. See the connections, master the kit.

This is a work in progress project that's not ready for usage yet.

The goal is to detect champion kits and then show a list of items that "theoretically" is viable options on that character, rather than listing meta items.

## Project goals

Build targets:

- Haxe Hxcpp for installable app.
- Javascript Web (Github Pages, pre-build api data due to limitations)

Core functionality

- Read champion descriptions, sort out their kit synergies and scalings (on-hit, ap, ad, aa-resets etc) and create the item list
- Item scoring system
- Override functionality for wrongful detections

Will expand to having:

- Matchup specific items
- Item build planner with items checking synergy with other items as well.
- Champion specific item interactions that are lesser known (e.g Katarina's Ultimate ability procs on hit effects at lower damage, but Statikk Shiv is excempt from this)
