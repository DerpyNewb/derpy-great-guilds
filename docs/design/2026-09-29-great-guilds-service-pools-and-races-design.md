# Great Guilds: service pools and race mechanics - design

2026-09-29. Mod: `derpy_great_guilds.pack`. Sub-projects 2 and 3 of 3 asked for on 2026-09-29
("more guild offering variety" and "different mechanic flavour per supported race"), in one
spec as the user chose. Sub-project 1 was `2026-09-29-great-guilds-ai-bounties-design.md`.

Reverses two standing decisions, on the user's word: the flavours spec's "Effects, values,
costs, cooldowns, rivalries and earn routes stay identical" per race
(`2026-09-23-great-guilds-flavours-design.md`:36-37), and the first design's "more than three
services per guild" deferral (`2026-09-10-great-guilds-design.md` §12) - as pools behind the
same three cards rather than more cards.

## 1. The problem

Eighteen services, three per guild, and 12 of them are the same thing: the guild's one effect
switched on for N turns at +20 / +32 / +45 by rank. Every campaign offers the same eighteen,
and every race plays them identically - the flavours rename them and change the art, and only
the hired unit and Slave Tithe's payout differ.

## 2. What the user chose (2026-09-29)

| Question | Answer |
|---|---|
| Where the variety comes from | **A pool of services behind each card**, one drawn per card |
| When a card is drawn | **It rotates every N turns** (B) |
| How the rotation runs | **One clock for every guild** (A): every card redraws on the same turn |
| Pool size | **Three shared services per card** (B): today's plus two new, 36 new in all |
| How deep race differences go | **All three** (D): race-only services, a race earn route, a race twist |
| Which guild a race earn route pays | **The guild of that trade** (A), as buildings already do |
| Architecture | **One catalogue with a race tag** (approach 1) |
| The Empire's politics | **Karl Franz's Elector Counts, plus one variant per legendary lord** (B) |

Success means: two stretches of one campaign offer different services; each race has
services, an earning and a rule no other race has; the panel still shows three cards per guild;
an old save loads and keeps its cooldowns; multiplayer never desyncs on a draw.

## 3. The catalogue

- `GG.SERVICES` rows gain three optional fields:
  - `race` - a culture key. Nil means shared.
  - `needs` - a check function, `needs(faction) -> bool`, for a hook that may be absent (a
    resource this faction does not have, a CA global not loaded in this campaign, a campaign
    feature). Nil means always available.
  - `effects` - the service's own effect list, replacing "the guild's one rank effect" for
    services that name one (§5). Nil keeps today's behaviour.
- **Append only.** Cooldowns are saved by position (`GG.save`, the `cds` loop), so every new
  row goes at the end and the first 18 keep their slots. An old save's 18 cooldowns land on
  the right services.
- `rank` is already the tier (2, 3 or 4). `lead = true` on every rank-4 row, new ones
  included, so the rank-4 card stays leader-only whatever it draws.
- **A card's pool** is every row with that `guild` and `rank` whose `race` is nil or the
  faction's culture, and whose `needs` (if any) answers true. With race differences off (§8),
  `race` rows are excluded.

## 4. The draw and the rotation

- **Each faction holds 18 cards**, one per guild per rank, in `GG.GUILDS` order then rank 2, 3,
  4. Saved as `derpy_gg_cards_<faction>` = `"<turn drawn>;<key>,<key>,...<18 keys>"`.
- **The clock is the turn number.** Cards redraw on every turn that is a multiple of N
  (`rotate_turns`, default 10). A faction redraws when `floor(turn / N) > floor(drawn / N)`,
  so a missed turn (a faction that did not exist, a save loaded mid-period) catches up once,
  not repeatedly. Nothing else is saved; the countdown is `N - turn % N`.
- **First draw:** a faction with no saved cards draws at once - a new campaign, or an existing
  save meeting this build.
- **Where it runs:** `GG.rotate_cards(faction, turn)`, idempotent within a period, called from
  the `gg_turn` FactionTurnStart handler after `GG.tick_cooldowns`, and from `GGAI.run_turn`'s
  per-faction loop before `court_step` / `step` - so a rival buys from this period's cards even
  when its own turn start comes later in the round. Covered factions only (`GG.covered`).
- **Never drawn from the panel.** A roll from UI code runs on one machine only and desyncs a
  multiplayer game. The panel only reads cards; a faction with none shows each card's first
  pool row (today's service) until its first turn draws.
- **Rules of the draw**, each card in order, every roll `GG.roll`:
  1. Never the service the card held before, when the pool has another.
  2. **At least one race service on show.** When race differences are on and the faction's
     race has services, and no card drew one, one card - rolled among those whose pool holds a
     race service - is redrawn to that race service. Without this, about one rotation in three
     would show none.
- **Cooldowns stay per service.** A service that rotates out keeps ticking; it comes back
  showing what is left.
- `GG.can_buy(faction, key)` gains one check, first: the service is on one of the faction's
  cards (`"card"` refusal). The panel, the purchase path and `GGAI.choose` all go through
  `GG.can_buy`, so nothing else needs to know about the draw.
- **The notice:** on a rotation, a human gets one feed message ("The guilds have new services",
  new record 5006 + the race offset, a good-news event under the `guild_notices` setting) and a
  Log line. No message on the first draw.

## 5. The 36 shared services

**Four new service kinds**, each on a map picker that already exists:

| Kind | Does | Target | Picker (panel / rival) |
|---|---|---|---|
| `army` | a timed bundle on one army, `cm:apply_effect_bundle_to_force` | own army | the Hire picker / `GGAI.pick_army` |
| `settlement` | a timed bundle on one region, `cm:apply_effect_bundle_to_region` | own settlement | the selected settlement / `GGAI.pick_own_region` |
| `enemy_settlement` | the same, on an enemy's region | enemy settlement | the selected settlement / `GGAI.pick_enemy_region` |
| `ranks` | experience for one character | own lord or hero | the selected character / `GGAI.pick_army` |

Every pick passes `GG.target_ok` (§9): the buyer's own for the three friendly kinds, a faction
at war with the buyer for `enemy_settlement`. The `hostile_services` switch covers
`enemy_settlement` services as well as The Khan's Price: off, they are never drawn and never
sold, and the switch's MCT tooltip names both.

**One general rule:** a service may carry a timed bundle alongside its action (`gold` +
bundle, `research` + bundle). A bundle that is a deliberate drawback (the Guild Loan) carries
`drawback = true`; `check()` accepts its reversed sign on that flag and nowhere else, and the
card text states the drawback.

Every other new service is a faction bundle (`kind = "bundle"`) with its own `effects`.

**Every effect below is a pair CA uses** (`effect_bundles_to_effects_junctions`), checked
2026-09-29 with the generator's own rules: the key exists, vanilla pairs it with that scope,
the value is within 1.5x vanilla's largest on that pair where vanilla has 3+ rows, and the sign
agrees with `is_positive_value_good` (a cost effect helps at a negative value). "Unguarded"
means vanilla has fewer than 3 rows, so the value is a judgement.

| Guild | R | Service | Kind | Effect (scope) | Value | Turns |
|---|---|---|---|---|---|---|
| brass | 2 | Alms and Bribes | bundle | `wh3_main_effect_corruption_reduction_events` (faction_to_province_own); **Chaos Dwarfs: `wh3_main_effect_corruption_chaos_events` +5** instead - their public order rises with Chaos corruption (found in game 2026-09-29, `for_tag`) | -5 | 8 |
| brass | 2 | Mercenary Contract | bundle | `wh_main_effect_force_all_campaign_recruitment_cost_all` (faction_to_force_own) | -15 | 6 |
| brass | 3 | Guild Loan | gold + bundle | 6,000 gold now; `wh_main_effect_economy_gdp_mod_all` (faction_to_region_own), drawback | -10 | 10 |
| brass | 3 | Industry Charter | bundle | `wh_dlc07_effect_economy_gdp_mod_industry` (faction_to_region_own) | +20 | 10 |
| brass | 4 | Treasury Seal | bundle | `wh_main_effect_force_all_campaign_upkeep` (faction_to_force_own) | -20 | 12 |
| brass | 4 | Bought Peace | bundle | `wh_main_effect_public_order_events` (faction_to_province_own) | +3 | 12 |
| immortals | 2 | Forced March | army | `wh_main_effect_force_all_campaign_movement_range` (force_to_force_own) | +20 | 3 |
| immortals | 2 | Drillmasters | bundle | `wh_main_effect_force_all_campaign_experience_base_all` (faction_to_force_own) | +1 | 8 |
| immortals | 3 | Battle Standard | army | `wh_main_effect_force_stat_leadership` (force_to_force_own) | +8 | 5 |
| immortals | 3 | Field Surgeons | army | heals the army now; `wh_main_effect_force_all_campaign_replenishment_rate` (force_to_force_own) | +30 | 2 |
| immortals | 4 | Veteran Cadre | bundle | `wh_main_effect_force_all_campaign_experience_base_all` (faction_to_force_own) | +3 | 10 |
| immortals | 4 | Warlord's Honour | ranks | (§5 ranks) | 5 ranks (3 as first built; raised 2026-09-29) | - |
| daemonsmiths | 2 | Ward Runes | army | `wh_main_effect_force_stat_ward_save` (force_to_force_own), unguarded | +10 | 5 |
| daemonsmiths | 2 | Spirit Siphon | bundle | `wh3_main_effect_winds_of_magic_events` (faction_to_force_own); **Dwarfs: `wh_main_effect_force_stat_magic_resistance` +10** - no spellcasters (audit 2026-09-29) | +5 | 8 |
| daemonsmiths | 3 | Forged Arms | bundle | `wh_main_effect_force_stat_weapon_strength` (faction_to_force_own) | +10 | 8 |
| daemonsmiths | 3 | Master Gunners | bundle | `wh_main_effect_force_stat_missile_damage_artillery` (faction_to_force_own), unguarded; **Chaos Dwarfs: `wh3_dlc23_effect_force_stat_missile_strength_chd_artillery` +20; Kislev: minted `derpy_gg_effect_missile_strength_ksl_war_machines` +20 (War Sleds and Little Grom)** - `all_land_artillery` misses both rosters, whose war machines are class chariot (audit 2026-09-29) | +20 | 10 |
| daemonsmiths | 4 | The Great Work | research + bundle | finishes current research; `wh_main_effect_technology_research_rate_mod` (faction_to_faction_own) | +30 | 10 |
| daemonsmiths | 4 | Arsenal | bundle | `wh_main_effect_force_stat_missile_damage` (faction_to_force_own) | +15 | 10 |
| khanate | 2 | Bribed Guards | bundle | `wh_main_effect_agent_action_success_chance` (faction_to_character_own) | +15 | 8 |
| khanate | 2 | Blooded Agents | bundle | `wh_main_effect_agent_recruitment_xp_all_agents` (faction_to_province_own) | +2 | 10 |
| khanate | 3 | Hired Blade | ranks | (§5 ranks) | 3 ranks | - |
| khanate | 3 | Sow Discord | enemy_settlement | `wh_main_effect_public_order_events` (region_to_province_own_unseen) | -8 | 5 |
| khanate | 4 | Web of Whispers | bundle | `wh2_main_effect_agent_cap_increase_all_heroes` (faction_to_faction_own_unseen) | +1 | 15 |
| khanate | 4 | Poisoned Wells | enemy_settlement | `wh_main_effect_province_growth_events` (region_to_province_own) -25, unguarded; `wh_main_effect_force_all_campaign_replenishment_rate` (region_to_force_own) -25 | | 8 |
| overseers | 2 | Granaries | settlement | `wh_main_effect_province_growth_events` (region_to_province_own), unguarded | +25 | 8 |
| overseers | 2 | Road Gangs | bundle | `wh_main_effect_force_all_campaign_movement_range` (faction_to_force_own) | +10 | 8 |
| overseers | 3 | Enforcers | settlement | `wh_main_effect_public_order_events` (region_to_province_own_unseen) | +6 | 8 |
| overseers | 3 | Fortify | settlement | `wh_main_effect_force_stat_melee_defence` (region_to_force_own) +10; `wh_main_effect_force_army_campaign_siege_defend_attrition` (region_to_force_own) -20 | | 8 |
| overseers | 4 | Master Builders | bundle | `wh3_main_effect_building_construction_time_add_mod_all` (faction_to_region_own), unguarded | -1 | 10 |
| overseers | 4 | Great Works | bundle | `wh_main_effect_public_order_events` +4 and `wh_main_effect_province_growth_events` +30 (both faction_to_province_own) | | 10 |
| slavers | 2 | Raiding Parties | bundle | `wh_main_effect_force_all_campaign_raid_income` (faction_to_force_own) | +50 | 8 |
| slavers | 2 | Captive Markets | bundle | `wh_main_effect_force_all_campaign_post_battle_loot_mod` (faction_to_faction_own) | +20 | 8 |
| slavers | 3 | Slave Levy | bundle | `wh_main_effect_unit_recruitment_points` (faction_to_province_own) | +1 | 6 |
| slavers | 3 | Pit Fights | bundle | `wh3_dlc20_effect_xp_gain_all_units` (faction_to_force_own), unguarded | +25 | 10 |
| slavers | 4 | The Great Hunt | bundle | `..._movement_range` +15 and `wh_main_effect_force_all_campaign_raid_income` +50 (both faction_to_force_own) | | 10 |
| slavers | 4 | Scorched Earth | enemy_settlement | `wh_main_effect_economy_gdp_mod_all` (region_to_region_own) | -25 | 8 |

Every new service, shared or race, costs its rank's favour (50 / 150 / 400) with a cooldown of
8 / 12 / 16 turns, and takes the existing price modifiers. The 18 keep their own numbers.

**Changed from the chat draft, and why:**
- *Tax Farmers* became **Alms and Bribes**: no vanilla bundle carries a tax effect, and income
  from all buildings is the Merchants' own rank effect.
- *Trade Charter* became **Industry Charter**: trade tariff income is zero without trade
  agreements - the exact fault removed from the Merchants' ladder on 2026-09-16.
- *Engines of War* became **Master Gunners**: vanilla has no all-race war-machine upkeep effect.
- *Road Gangs* applies everywhere: no vanilla pair limits movement to friendly territory.
- *Fortify* protects the defenders: walls and garrison size have no bundle effect.
- *Slave Levy* is local recruitment capacity: the global slot effect is the one the Soldiers'
  rank ladder already takes to vanilla's ceiling of 3.
- *Field Surgeons* heals the army at once, `cm:heal_military_force(force)` (a force interface;
  CA uses it at `wh3_campaign_great_game.lua:442`), and adds the two-turn replenishment surge.
- Three lines draw hidden in the game's breakdown (`_unseen` scopes: Sow Discord, Enforcers,
  Web of Whispers) - vanilla has no visible pair for them - so each card and bundle description
  states the number itself.

**How the new kinds call the game** (CA's own doc entries and uses, checked 2026-09-29):
- `army`: `cm:apply_effect_bundle_to_force(key, force_cqi, turns)`, a NUMBER cqi; 0 or less is
  permanent, so turns is always given.
- `settlement` / `enemy_settlement`: `cm:apply_effect_bundle_to_region(key, region_key, turns)`
  takes no owner, and works on anyone's region (CA applies one to regions it has just left,
  `episode_vermintide.lua:1466`). A `region_to_*_own` effect hits whoever owns the region.
  Whether the bundle survives a change of owner is unmeasured, so every one has a finite
  duration.
- `ranks`: `cm:add_agent_experience(cm:char_lookup_str(cqi), n, true)` adds n RANKS
  (`lib_campaign_manager.lua:7964`; the third argument makes the number ranks, not XP).
- Every character call takes a lookup string built with `cm:char_lookup_str`, never a bare cqi
  (§12).

## 6. Race services

Each race's pool entries: a `race` row, placed in the guild of that trade, one per rank. The
Empire also has one row for Karl Franz's politics and one per legendary lord (§6.1). Each row's
`needs` names what it checks; a row whose check fails is never drawn, so it cannot take favour
and do nothing. **Six of these hooks exist only in Immortal Empires** (`chivalry`,
`Blessing_Character_Won`, the Gelt, Todbringer, Wulfhart and High Elf court scripts); each
`needs` checks that its CA global exists before anything else.

**Built 2026-09-29 (stage 2).** Race rows cost and cool down like shared rows of their rank:
rank 2 is 50 favour and 8 turns, rank 3 is 150 and 12, rank 4 is 400 and 16, and every rank-4
row is a lead service. `needs` is also read at the till, so a hook that goes away after the
draw (a caravan home, a pool lost, a cycle resolved) refuses the sale as "unavailable" and
takes no favour. Corrections made while building are marked *Built:* in the tables below.

| Race | R | Guild | Service | Does (the call) | Value | `needs` |
|---|---|---|---|---|---|---|
| Chaos Dwarfs | 2 | khanate | Conclave Favour | `cm:faction_add_pooled_resource(f, "wh3_dlc23_chd_conclave_influence", "wh3_dlc23_chd_conclave_influence_gained_events", n)` | 40 | - |
| Chaos Dwarfs | 3 | daemonsmiths | Hell-Forge Allotment | a free unit cap for one of the 11 Hell-Forge units, rolled. *Built:* CA's own `hellforge:modify_unit_cap(ritual, faction_iface, hellforge.unit_cap_modifiers_bundle_string)` (`wh3_dlc23_campaign_chd_hellforge.lua:376`), not the Tower's ritual sequence - a second ritual can end the mod's one-turn commission rite in flight (`docs/RITUALS.md` §5), and the listener paying the Tower's ritual raises the next paid cap by 25%. Then the `wh3_dlc23_chd_toz_cap_<ritual>` incident for a human, except the blunderbusses, whose row is `..._unit_cap_dwarf_blunderbusses` (CA's own key misses it, so CA's roll of that cap shows nothing) | 1 cap | the `hellforge` global |
| Chaos Dwarfs | 4 | overseers | Labour Gangs | every province: `faction:provinces()` -> `pooled_resource_manager():resource("wh3_dlc23_chd_labour")` -> `cm:pooled_resource_factor_transaction(res, "other", n)`, skipping a null resource (CA's route, `labour_loss.lua:40-49`) | 200 each | - |
| Dwarfs | 2 | overseers | High King's Decree | `dwf_underdeeps`, factor `underdeep_faction` | 1 | - |
| Dwarfs | 3 | daemonsmiths | Strike Lines from the Book | `wh3_dlc25_dwf_grudge_points`, factor `settled`; CA's cycle listener counts it toward the grudge cycle | 200 | - |
| Dwarfs | 4 | immortals | Call the Reckoning | `grudge_cycle.faction_times[f] = 0`: the cycle resolves at the next turn start, as CA's Underdeep building does (`wh3_campaign_underdeep.lua:219-227`) | - | the `grudge_cycle` global; a human faction in a cycle; progress already at the cycle's top level - resolving early wipes progress and pays the CURRENT level, so it is only offered when waiting gains nothing |
| Empire | 2 | overseers | Witch Hunters' Warrant | settlement: `wh_main_effect_public_order_events` +8 and `wh3_main_effect_corruption_reduction_events` -5 (both region_to_province_own_unseen) | 8 turns | - |
| Empire | 3 | immortals | Elector's Muster | two regiments join the selected army, `cm:grant_unit_to_character(lookup, unit)`: `wh_main_emp_inf_swordsmen`, `wh_main_emp_inf_handgunners` (added only if the army has room) | 2 units | - |
| Empire | 4 | brass | Unity of the Empire | `wh_main_faction_political_diplomacy_mod_empire` (faction_to_faction_own) | +30, 15 turns | - |
| Kislev | 2 | daemonsmiths | Prayers to the Motherland | `wh3_main_ksl_devotion`, factor `events` | 75 | the resource is not a null interface (its reach is unverified) |
| Kislev | 3 | khanate | Court Favour | +support to the LOWER court's tracker (`wh3_main_ksl_support_tracker_ice_court` / `_orthodoxy`, factor `faction`), lower read from `..._support_level_*` as CA does (`kislev_motherland.lua:354`) | 30 | - |
| Kislev | 4 | immortals | Blessing of the Motherland | Devotion +100 and both courts' trackers +20 | | as Prayers |
| Bretonnia | 2 | immortals | The Lady's Blessing | `Blessing_Character_Won(general)` on the selected army's general | - | the global; the army is not already blessed |
| Bretonnia | 3 | brass | Peasant Levies | `wh_dlc07_effect_peasant_increase_base_amount` (faction_to_faction_own_unseen) | +3, 10 turns | - |
| Bretonnia | 4 | daemonsmiths | Tales of Valour | `chivalry:ModifyChivalry(f, "missions", n)` (runs CA's win check); the raw pooled-resource call if the global is missing | 150 | - |
| Cathay | 2 | daemonsmiths | Realign the Compass | `cm:set_next_winds_of_magic_compass_selection_cooldown(faction_iface, 0)` | - | *Built:* not the Celestial Court, whose jade compass this call does not reach |
| Cathay | 3 | brass | Ivory Road Cargo | every active caravan: `cm:set_caravan_cargo(caravan, cargo + n)` | +200 | an active caravan |
| Cathay | 4 | overseers | Mandate of Heaven | `wh_main_effect_public_order_events` +4 and `wh3_main_effect_corruption_reduction_events` -8 (both faction_to_province_own) | 10 turns | - |
| Dark Elves | 2 | slavers | Slave Coffles | `def_slaves`, factor `missions` | 500 | - |
| Dark Elves | 3 | khanate | Bought Loyalty | `cm:modify_character_personal_loyalty_factor(lookup, n)` on the selected lord | +3 | *Built:* not the faction leader, who has no personal loyalty to buy |
| Dark Elves | 4 | slavers | Black Ark Tithe | `wh3_main_pooled_resource_def_slaves_buildings_gained` (faction_to_faction_own_unseen) | +80/turn, 10 turns | - |
| High Elves | 2 | khanate | Favours at Court (*Built:* renamed from "Whispers at Court", the High Elf flavour's name for the shared Khan's Price) | `cm:change_influence(f, n)` | 30 | - |
| High Elves | 3 | brass | The Phoenix King's Favour | `wh3_dlc27_hef_favour`, factor `faction` | 50 | the resource exists |
| High Elves | 4 | daemonsmiths | Asuryan's Grace | Favour +150 and Influence +40 | | as above |

**Changed from the chat draft, and why:**
- *Harmony of Heaven and Earth* became **Mandate of Heaven**: Cathay's Harmony is one signed
  pool per province that resets every round, and the only bundle pair pushes every province
  toward Yang - not more harmony.
- *Warriors of the Motherland* (+Supporters) became **Blessing of the Motherland**:
  `wh3_main_ksl_followers` reaches no faction through any campaign group.
- *Imperial Gunnery School* became **Unity of the Empire**: it would have been the shared
  Arsenal's exact effect in the same guild and rank.
- *Call the Reckoning* gained its progress gate (above).

### 6.1 The Empire's politics and its lords

| Service | R | Guild | For | Does | `needs` |
|---|---|---|---|---|---|
| Elector's Favour | 3 | khanate | a faction with the politics feature (Karl Franz's Reikland in vanilla) | +1 Fealty (`emp_loyalty`, factor `events`, pool 0-10) to the least loyal Elector Count, via CA's global `empire_modify_elector_loyalty(elector, "events", 1)`; least loyal found with `empire_find_electors_with_loyalty` (`wh2_dlc13_empire_politics.lua:949`), which skips human and hostile electors | `cm:faction_has_campaign_feature(f, "politics")`, asked of the buyer only (*Built:* the wrapper throws for a faction key the map lacks, `lib_campaign_manager.lua:17626`); the globals; an elector below 10 |
| Gunnery School Schematics | 3 | daemonsmiths | Elspeth | `wh3_dlc25_emp_research`, factor `other`, +300 | the resource is not null |
| Arcane Essays | 3 | daemonsmiths | Gelt | `wh3_dlc25_emp_arcane_essays`, factor `other`, +300 | the resource is not null |
| Fervour | 3 | immortals | Todbringer | `wh3_dlc29_emp_fervour`, factor `missions`, +300 | the resource is not null |
| Imperial Supply Train | 3 | brass | Wulfhart | *Built:* `cm:trigger_dilemma(wulfhart, "wh2_dlc13_wulfhart_imperial_guards_st_<1-3>")` at CA's own strength bands on `emp_progress` (below 20, below 60, above). Not CA's `trigger_imperial_reinforcements_event()`: it also zeroes the file-local supply meter (`:668`), so it would only bring the next supply forward | faction `wh2_dlc13_emp_the_huntmarshals_expedition`; human (a dilemma); holds `emp_progress` |

Gating on the resource, not a faction name, keeps each variant working after a confederation.
These count as race services for the "at least one on show" rule.

### 6.2 Slave Tithe

Slave Tithe's per-race payout grows: **Kislev** 150 Devotion (`events`), or the gold for a
Kislev faction without Devotion, and **Dark Elves** 1,000 Slaves (`missions`). *Built:* not
gated by `race_differences`, like the Chaos Dwarf and Dwarf payouts it already had. The research overturned both earlier specs' "no pool fits"
(`2026-09-24-great-guilds-brt-cth-ksl-design.md`:15, `...def-hef-design.md`:18-20). Chaos
Dwarfs and Dwarfs keep theirs; everyone else keeps gold.

## 7. Race earn routes and twists

**Earn routes** pay the guild of that trade, through the same grant every other earning uses,
so they meet the guild's per-turn cap, cost the rival guild its share, and take the patron
bonus.

| Race | Event (context) | Filter | Guild | Reputation |
|---|---|---|---|---|
| Chaos Dwarfs | `CaravanCompleted` (`faction()`) | culture is Chaos Dwarf | brass | 60 |
| Dwarfs | `PooledResourceChanged` (`resource():key()`, `amount()`, `faction()` after `has_faction()`) | `wh3_dlc25_dwf_grudge_points`, amount > 0 | immortals | 1 per 5 (*logic audit 2026-09-29:* was 10 per change, and CA pays one battle's grudges as one change per winning army) |
| Empire | `RegionFactionChangeEvent` (`region()`, `previous_faction()`, `reason()`) | new owner Empire, previous not, region in `wh3_dlc25_imperial_authority_regions_main_warhammer` or `..._wh3_main_chaos` (both tested literally: CA builds the key from `cm:get_campaign_name()`, which is unreliable). *Built:* reasons `abandoned`, `abandoned to rebels`, `startpos setup`, `cli command` and `diplomacy trade` pay nothing - the last is two players trading a region back and forth | immortals | 50 |
| Kislev | `ScriptEventFactionPerformsMotherlandRitual` (`faction()`) | - (fires at ritual START, for AI and humans) | daemonsmiths | 40 |
| Bretonnia | `PooledResourceChanged` | `brt_chivalry`, amount > 0, *Built:* factor not `missions` (Tales of Valour grants through it, and so does every mission's Chivalry reward - CA's `payload.chivalry`, `lib_campaign_mission_manager.lua` - which the mission already pays the guilds for) | immortals | 1 per 5 |
| Cathay | `CaravanCompleted` | culture is Cathay. *Built:* heard once - CA re-raises the same context as `ScriptEventCaravanCompleted` (`caravans_core.lua:816`), and listening to both would pay twice | brass | 60 |
| Dark Elves | `PooledResourceChanged` | `def_slaves`, amount > 0, factor `raiding` or `battles` | slavers | 1 per 20 |
| High Elves | `RitualCompletedEvent` (`performing_faction()`, `ritual():ritual_category()`) | category starts `HEF_COURT_ACTION_` | khanate | 40 |

- **A purchase never earns for itself.** Before a race service grants a resource an earn route
  listens to (Dwarf grudge points, Bretonnian Chivalry), it records the amount it is about to
  grant for that faction; the listener subtracts a recorded amount once before paying. That
  holds whether the engine raises `PooledResourceChanged` inside the call or after it. The
  Dark Elf route needs no record: the services grant through `missions`, which it ignores.
  *Built:* the record lives for its own turn only, and the Bretonnian route needs none
  either (it ignores `missions`).
- *Built:* a route paid per so many points (Chivalry per 5, Slaves per 20) keeps the
  remainder for the next change, in session memory, so a raid of 12 Slaves is not lost.
- **Rivals earn too**, wherever CA raises the event for them. Dwarf grudge progress and
  Bretonnian vows come from scripts that run for humans only, so rivals of those two races
  rarely earn by them. That makes those two races' Leaderboards slightly easier; it is
  accepted, not fixed.
- Each earning writes one Log line ("The Brass Tablets: a caravan reached its destination
  (+60 Reputation)"), under the existing Mine filter (§9), stating what the guild actually
  gained after its turn limit, and nothing when that is 0. No feed message: they are too
  frequent.

**Twists** are multipliers, stored as whole percentages (the game's Lua is float32), applied by
a new `GG.setting_for(faction, key)` that returns `GG.setting(key)` scaled by the faction's
race. A rule switched off (value 0) stays off. Two twists are not settings today - the favour
cap (`GG.RANKS[rank] * 2` in `GG.grant`) and a hostile service's price - and become named
per-race values read at those two places.

| Race | Twist | Setting x percent |
|---|---|---|
| Chaos Dwarfs | *Hashut's tithe* | `demand_every` 67 (12 -> 8), `demand_reward` 150 |
| Dwarfs | *Never forgotten* | `rate_bounty_fail` 150, `demand_penalty` 200 |
| Empire | *Petty rivalries* | `rate_rivalry` 150 (40 -> 60) |
| Kislev | *Hardy folk* | `rate_decay` 50 |
| Bretonnia | *Noblesse oblige* | `demand_reward` 150, `demand_penalty` 200 |
| Cathay | *Harmony* | `rate_rivalry` 50 (40 -> 20) |
| Dark Elves | *Cutthroat* | `rate_rivalry` 150; hostile service price 75 |
| High Elves | *Ancient houses* | favour cap 150 (2x -> 3x the rank's threshold) |

Every call site that reads one of these settings for a faction switches to
`GG.setting_for(faction, key)`; a read with no faction keeps `GG.setting`.

## 8. Settings

Appended to `GG.TUNE_ORDER` and `GG.TUNE_DEFAULTS`, frozen into the save at the first turn like
every setting, MCT rows in the `systems` section:

| Key | Type | Default | Player text |
|---|---|---|---|
| `rotate_turns` | slider 5-30 | 10 | "Services change every" / "The guilds change the services they offer every this many turns." |
| `race_differences` | checkbox | on | "Race differences" / "Each race's guilds offer services of their own, earn from something only that race does, and bend one rule. Off: every race plays alike, and still gets the changing services." |

With `race_differences` off: no `race` rows in any pool, no earn-route listeners pay, and every
`GG.setting_for` returns the plain setting. The shared pools and rotation stay.

**Both are read on every difficulty preset**, like the four existing switches (corrected while
planning, 2026-09-29). `GG.read_mct_or_defaults` reads numbers only under Custom, and
`rotate_turns` is a system, not tuning: read only under Custom it would look editable and be
ignored. So `GG.EVERY_PRESET` lists it, it is left out of the MCT file's `PRESET_OWNED`, and
`check_presets` refuses it there. Like every other slider, it is locked once a campaign is
running.

## 9. The panel, the Log and the rivals

- **Cards:** each guild still shows three. A card shows the drawn service with its price,
  cooldown and rank lock as today. A race service carries a small race label.
- **Countdown:** "New services in N turns", appended to the footer after the favour figure
  (corrected while planning: the footer is a 750px line carrying one short number, while the
  rank and earned lines are full, and a new line would be a new component).
- **Help:** a new page - rotation, race services, your race's earn route and twist - written per
  flavour.
- **Log:** a rotation line; an earn-route line; both under the existing **Mine** filter
  (corrected while planning: a new filter is a new button component and a layout pass, and
  Mine already holds the player's own guild events).
- **Text:** every new shared service has a name and blurb in all nine flavours; every race
  service in its own race's flavour. `check_flavour_shape` already refuses a gap.
- **Rivals:** draw their own cards (§4), buy through `GG.can_buy`, and get a picker for each
  targeted kind: `GGAI.pick_army` (army, ranks, Field Surgeons, Lady's Blessing, Elector's
  Muster, Bought Loyalty), a rolled region of their own (settlement, `GGAI.pick_own_region`,
  which shares `GGAI.own_regions` with `GGAI.pick_building`), and `GGAI.pick_enemy_region`
  (enemy settlement). Corrected while planning: `pick_building` returns an upgrade target, not
  a region, and a separate highest-rank-lord picker was one more function for no difference a
  player would see. A service whose `needs` asks for a human (the Reckoning, the Supply Train)
  is never on a rival's card.
- **Every targeted pick is checked, `GG.target_ok`:** a friendly army, character or settlement
  service must be given the buyer's own; an enemy-settlement service a region of a faction at
  war with the buyer. The panel treats a failing selection as no selection, and `GG.buy`
  refuses it. Hire is held to the same check: before it, an enemy general selected on the map
  could be handed the regiment.

## 10. Old saves and multiplayer

- New services are appended, so an old save's 18 cooldowns land on the right rows. Cards are
  drawn at the first turn after loading. Nothing already saved changes shape.
- Every draw is `GG.roll`, from turn handlers only, in a fixed order; the panel never rolls. A
  `needs` check reads only world state every machine shares.
- The two new settings travel with the rest (`GG.send_tune`).

## 11. Testing

- **The Lua harnesses:**
  - a card's pool (shared, race, the lord's resource present or absent, a failed `needs`, race
    differences off);
  - never the same twice in a row; at least one race service on show;
  - the turn clock: redraw on a multiple of N, a missed period catches up once, no redraw
    within a period;
  - the first draw on a save with no cards; the panel reading a faction with none;
  - `GG.can_buy` refusing a service not on a card;
  - an old 18-cooldown save loading against the longer table;
  - each new kind's payload, each with its lookup string or number exactly as documented;
  - each earn route's filter, and that a service's own grant does not pay it;
  - each twist, and that a setting at 0 stays 0.
- **Generator checks, each proven by breaking it once:**
  - every service effect is a vanilla pair within the value rule (the existing rank-effect
    check, extended to every `effects` list); `drawback` is the only reversed sign it accepts;
  - every race service's pooled resource and factor exist in CA's tables, with positive
    bounds for a grant;
  - every service has its text in every flavour it can be drawn in.
- **Mutation run:** mutants for the draw, the pool filter, the card check, the earn-route
  subtraction and the twists.
- **In game, nothing offline can prove:**
  1. Labour into a province (the stored note that says per-province pools are unreachable is
     contested by CA's own code).
  2. Hell-Forge Allotment beside the mod's one-turn commission rites.
  3. The Lady's Blessing and `chivalry:ModifyChivalry` called from a mod.
  4. The Reckoning's gate and payout.
  5. The Compass cooldown, caravan cargo, Elector's Favour, the Supply Train dilemma.
  6. A hostile settlement bundle's effect on the owner, and whether it survives a capture.
  7. The three `_unseen` lines: the number is in the text.

## 12. Found while designing: the Hire service's unit grant

`GG.payload`'s `unit` branch passes a bare number (`GG.target_from_wire` returns
`tonumber(t)`) to `cm:grant_unit_to_character`, which CA documents as taking a **character
lookup string**; every CA call wraps it in `cm:char_lookup_str`
(`wh3_dlc27_nor_sayl_manipulation.lua:356`). No handoff records Hire working in game. If the
engine does not accept a number, Hire has spent favour and granted nothing since it shipped.
The fix is one wrapper; it goes first in the plan, with the new services' character calls
built the same way. The same plan also checks Hire's target (§9): the selected character must
be the buyer's own general with a field army.

## 13. Build order and scope

One spec; the plan builds it in two stages, each playable:
1. The catalogue fields, the draw and rotation, the four new kinds, the 36 shared services,
   the settings, the panel's countdown and the rotation notice. (§12's fix first.)
2. The race services, the Empire's politics and lords, Slave Tithe's payouts, the earn routes,
   the twists and the Help page.

**Out of scope:** more than three cards per guild; paying to redraw a card; more bounty kinds;
race services for the Generic flavour; lord variants outside the Empire; any change to how
rivals choose what to buy.
