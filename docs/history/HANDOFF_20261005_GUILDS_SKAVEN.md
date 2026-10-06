# Great Guilds: the Skaven, the ninth race (2026-10-05)

Spec: `docs/superpowers/specs/2026-10-05-great-guilds-skaven-design.md`.
Plan: `docs/superpowers/plans/2026-10-05-great-guilds-skaven.md`.

Built and packed: `Modding Files/Modpacks/derpy_great_guilds.pack`, MD5 `c3140f927fdecd0974719610fcf729f9` (45,700,250 bytes), after the deferred-minor fixes below. 7F7423DC, the final-review build, was the first seen in game.

Deployed to `data/` with the MD5 equal on both sides (2026-10-05). It replaced 7F7423DC.

The pre-Skaven build, 9E2DB00E, is backed up twice in
`Modding Files/Backup/guilds_pre_skaven_20261005/` (`modpacks/` and `data/`).

## What shipped

`_skv`, culture `wh2_main_skv_skaven`, feed offset 90, before `_gen`. Full parity with the other eight races.

| Role | Guild | Hall unit |
|---|---|---|
| brass | The Warpstone Traders | Skavenslaves |
| immortals | The Stormvermin | Stormvermin |
| daemonsmiths | The Skryre Warlocks | Warpfire Throwers |
| khanate | The Eshin Assassins | Gutter Runners |
| overseers | The Moulder Breeders | Rat Ogres |
| slavers | The Slave-Masters | Clanrats |
| temple | The Grey Seers | none: Skaven corruption +2/+4/+6 in the settlement |

- **Ranks:** Skavenslave, Clanrat, Clawleader, Chieftain, Warlord.
- **Twist, Treachery:**
  - rivalry takes 150%;
  - an expired demand costs nothing. `GG.setting_for` now returns 0 for an explicit 0 twist instead of clamping it to 1.
  - Every text about an expired demand branches on `expiry_free(tag)`: Help pages 1 and 5, the Court card, the feed.
- **Earn route, under-cities founded:**
  - `ForeignSlotManagerCreatedEvent` pays the Eshin Assassins 40;
  - allied outposts are refused through `context:is_allied()`;
  - Neferata's covens are refused by `GG.race_earn`.
- **Under-city buildings:** `ForeignSlotBuildingCompleteEvent` hands over a level key, which `GG.level_of` splits as `<chain>_<n>`. It then goes through `GG.on_building` by the owner's race words.
- **Grey Seers' routes:**
  - holy war against the Dwarfs and the Lizardmen;
  - **taint**: `rate_temple_taint` (default 2, MCT 0-10) per province carrying `wh3_main_corruption_skaven` above 0, previewed in `GG.turn_start_pay` for the lead hold.
  - No priests route: every Grey Seer subtype is a lord.
- **Race services**, rows 93-95, after the temple's:
  - Food Tithe (Slave-Masters, rank 2): 20 `skaven_food`.
  - Shadows of Eshin (Eshin, rank 3): Gutter Runners and Night Runners join the selected army, through `GG.RACE_FIRE.electors_muster`.
  - Breeding Season (Moulder, rank 4, leader only): +3 Food every turn for 10 turns.
- **Overrides for the Skaven:**
  - Temple Bribes adds +5 Skaven corruption (CA's own pair and value) instead of reducing corruption.
  - Purge and Consecration take the Chaos Dwarf public-order override.
- **Halls:** 7 chains and 21 levels in `wh2_main_bas_skv`, plus the `wh3_dlc29_skv_thanquol` and `wh3_main_skv_endgame` sets. The halls tab and the Seat bundles come with them.
- **Panel:**
  - from Thanquol's Chaotic Plans: small panel card, plan plate, sub-title chip, portrait ring;
  - from Ikit Claw's workshop: buttons as tabs, trough and green fill;
  - the Skaven HUD button bar;
  - CA's `green` (`#A0FF37`) for heat and the running glow.
  - The Halls figure sits in the header.
- **Art:**
  - 8 card icons and the crest, from CA Skaven building icons;
  - 7 hall icons and a tab;
  - 7 grounds from `campaign_skaven1.png`, all p99 34.1.

32 `_skv` files in the pack. 95 services; 218 mutants.

## Verification

- `gen_great_guilds.py`: `--selftest` "7 guilds, 95 services, 90 bundles, 774 loc", `--check` exit 0.
- `gen_guilds_ui.py`: `--check` and `--selftest` (22 files) green.
- `_guilds_harness.lua` and `_guilds_bounty_harness.lua` green.
- `luac` passes on all six Lua files.
- `check_lua_api` 0, `check_lua_literal_left` 0, `check_lua_undeclared` the same as before the Skaven.
- `mutate_guilds.py`:
  - the first run left 3 survivors, each now killed by a new assertion;
  - 217/217, then 218/218 after the fix pass; no stale anchors.
- Previews for `--flavour skv`: default, `--page 7`, `--help-page 1/2/5/7`. All exit 0, no TOO WIDE, no LOW CONTRAST.
  **Judged by measurement, never viewed: look at `.skilltree_cache/ui_preview/*_skv*.png`.**
- The importer: "saved pack verified - every table holds this build's rows", for both builds.
- 7F7423DC is deployed to `data/`, with the MD5 equal on both sides.

### Final review

An Opus reviewer read the diff of 11 files, read-only. Review Focus 1-5 all held.

- **Important, fixed:**
  - allied outposts paid the founding route;
  - six texts said an expired Skaven demand costs Reputation.

  Each fix has a test that failed first.
- **Minor, deferred:** listed under Open.

## Rulings

### Plan time (the twelve, in full in the plan)

1. Priests route dropped: the Grey Seers are lords only.
2. The Seers' hall has no unit (the Screaming Bell is a mount), so it raises Skaven corruption +2/+4/+6.
3. The Menace Below is not a resource, so the service is Shadows of Eshin.
4. Food is `skaven_food`, factor `missions`: Tithe 20, and Breeding Season is CA's rite bundle value of 3.
5. Under-city context fields come from CA's own listeners.
6. Level keys are `<chain>_<n>`, checked by `check_undercity_levels` for all 33.
7. Sets: `wh2_main_bas_skv` and Thanquol's set.
8. Race words come from CA's display names.
9. Purge and Consecration take the Chaos Dwarf override.
10. `slave` is allowed in the Skaven text.
11. Art sources.
12. Hall units.

### Executor (in the session ledger)

- **`GG.setting_for`:** an explicit 0 twist now returns 0. A twist that rounds below 1 is still held at 1.
- **Guild names:** "The Skryre Warlocks / The Eshin Assassins / The Moulder Breeders" replace the spec's "Clan ...". `check_flavours` requires "The ", because every sentence is built as "the {short name}". The clan names stay in the prose.
- **Temple Bribes** takes a Skaven override of +5 Skaven corruption, CA's `wh3_dlc29_skv_magic_pull_moon_filler_token_skaven_corruption` pair.
- **Under-city buildings** pay any covered owner; spec 4.3 has no race gate.
  - Vampires, Slaanesh and Tzeentch are not covered, so today only the Skaven gain from it.
  - The allied-outpost side of this is a deferred minor.
- **`wh3_main_skv_endgame`** (Vermintide) gets the halls; `_set_problems` refused to leave it out.
- **`brass_skv`** draws `skaven_resource_gold`: the warpstone refinery is 38% one colour, so it is not a silhouette.
- **Frame:**
  - tabs are Ikit's buttons (margins 12/3/10/3). The narrative tabs measure red/purple, 80 rows tall.
  - the track is Ikit's trough and fill, with no frame: Ikit's frame is 88 rows, so the trough would be 6.
  - the rim is the tinted tutorial glow: the rim slot is `clear.png` (128px) in the file, and CA's 98px slices do not fit it.
  - the rank bar is the Chaotic Plans sub-title chip, with `RANK_STATS_PAD` 48.
  - the Halls figure is in the header.
- **Tests:**
  - the plan's "race words are per tag" assert ended `or true`, so it was dropped;
  - three assertions were added after mutation survivors;
  - the text assertion was narrowed so it does not flag the race page's own rule.

## Share of building reputation (Skaven)

| Guild | Share |
|---|---|
| The Warpstone Traders | 26% |
| The Stormvermin | 7% |
| The Skryre Warlocks | 5% |
| The Eshin Assassins | 4% |
| The Moulder Breeders | 49% |
| The Slave-Masters | 3% |
| The Grey Seers | 1% |

29% falls to the default role. That is the same as the High Elves; the Overseers role is the default, which is why Moulder is large.
The Seers live on their routes, as every temple does.

### Build jobs (`GG.BOUNTY_BUILDINGS._skv`)

Every Skaven guild has at least one.

| Guild | Build jobs |
|---|---|
| Traders | `wh2_dlc12_under_empire_money_thieves_3` |
| Stormvermin | `wh2_main_skv_clanrats_3`, `wh2_main_skv_defence_major_3` |
| Skryre | `wh2_main_skv_energy_5`, `wh2_main_skv_engineers_3`, `wh2_main_skv_weaponteams_2` |
| Eshin | `wh2_main_skv_assassins_3`, `wh2_dlc14_skv_eshin_assassins_3` |
| Moulder | `wh2_main_skv_farm_3`, `wh2_main_skv_salvage_3`, `wh2_main_skv_monsters_3`, `wh2_main_skv_monsters_4` |
| Slave-Masters | `wh2_main_skv_order_3`, `wh2_main_skv_temple_1` |
| Seers | `wh2_main_skv_plagues_3` |

## Adding a tenth race: every declaration point

Each line is a place the Skaven needed a hand-written entry. The checks and pins that catch each omission are in brackets.

**`zzz_derpy_guilds.lua` (model)**
- `GG.FLAVOURED[culture] = {tag, feed}` (`check_flavour_mirror`).
- `GG.HIRE_UNIT_BY_CULTURE` (`check_hire_units`).
- `GG.EARN_OF`, and `GG.EARN_ROUTES.<route>` if the route is new (`check_race_mirror`).
- `GG.TWISTS` (`check_race_mirror`).
- `GG.HALL_TAGS` (`check_hall_mirror`).
- `GG.TEMPLE_ROUTES`, between the BEGIN/END markers (`check_temple_routes`).
- `GG.BUILDING_THEME_RACE[tag]` (`check_building_theme`, which needs `HALL_RACES[tag]` for the race's chains).
- Race service rows APPENDED at the end of `GG.SERVICES`, never inserted, since cooldowns are positional. Add `GG.RACE_FIRE` entries for new kinds.
- A new route adds:
  - `LEDGER_SOURCES` (appended);
  - `TUNE_DEFAULTS`, plus `TUNE_ORDER` (appended);
  - the presets.
- The listeners for any new event.

**`zzz_derpy_guilds_ui.lua`**
- `GGUI.FRAME[tag]` (`check_frame_mirror`, and the harness's every-flavour-has-a-frame pin).
- `GGUI.MCT_NAMES[tag]` (`check_mct_names`; `--write` regenerates it).
- `GGUI.HALLS_IN_HEADER`, only if the preview shows room.

**`script/mct/settings/derpy_great_guilds.lua`**
- The rows for any new rate.
- `PRESET_OWNED` (`_mct_label_problem` reads the label).

**`tools/gen_great_guilds.py`**
- `FLAVOURS[tag]`, before `_gen`.
- `POOL_NAMES`, `TEMPLE_NAMES`, `TEMPLE_FLAVOUR`, `RACE_TEXT`.
- `TEMPLE_ROUTES`, `EARN_ROUTES` / `EARN_OF`, `TWISTS`.
- `SERVICES` (appended), with `for_tag` overrides where an effect is unwanted.
- `RACE_UNWANTED_EFFECTS`, `FLAVOUR_WORDS_ALLOWED`.
- `HALL_TAGS`, `HALL_ICON`'s tag list, `HALL_RACES[tag]` (set, `extra_sets`, nouns, units, temple nouns), `HALL_EXTRA` for a unitless temple.
- The `src_` and `log_earn_` loc lists.
- `TEMPLE_RATE_KEYS`.
- The selftest pins: the race-service count, the `FLAVOURS` order, the (tag, set) tuple, the DLC-tag tuple, the `len(_hs)` hall-set count.

**`tools/gen_guilds_ui.py`**
- `FRAMES[tag]`, `RANK_STATS_PAD[tag]`.

**`tools/make_guild_icons.py`**
- `ICONS` (8 stems, each must be a flat silhouette), `TAB_FRAME[tag]`.
- The two tag loops, and the `HALL_ICONS` count.

**`tools/make_guild_backgrounds.py`**
- `CA_ART[race]` and the 7 `CA_BACKGROUNDS` windows.

**`tools/import_great_guilds.py`**
- The UI race tuple.

**`tools/_guilds_harness.lua` / `_guilds_bounty_harness.lua`**
- The race `cases` list.
- The temple-rows positional pin.
- The bounty harness `want` twist table.

**`tools/mutate_guilds.py`**
- One mutant per new rule.

## First look in game: three fixes (2026-10-05, build 852975C1)

The user's first two screenshots of the Skaven panel showed two overlaps and asked for effect icons.

1. **The header's name ran into its figures.**
   - "The Warpstone Traders" overlapped "Skavenslave Reputation 5 / 100 Rival: The Eshin Assassins".
   - Cause: the game's font is about a quarter wider than the preview's (x1.24 for headings, x1.29 for body, measured off the screenshot), so the per-race `HALLS_IN_HEADER` list was chosen from the wrong font.
   - Fix: the list is gone. `GGUI.header_fits` measures the name and the figures with `TextDimensionsForText` against the bar less `GGUI.HEADER_INSET[tag]` (rank_tx + RANK_STATS_PAD, mirrored by `gen_guilds_ui.check_header_inset`) and `HEADER_GAP` 24.
   - What gives way: the rival goes from its full name, to its name without "The ", to the hover. The Halls figure stays on the bar only when it fits.
   - When the engine will not measure, the rival stays on the bar (as before) and the Halls figure goes to the hover.
2. **The card's green line cut through the titles.**
   - The Chaotic Plans art draws its line 10-15px inside the file.
   - Fix: both Skaven card layers are drawn 8px past the card on every side (`offset (-8,-8)`, `dw/dh +16`).
   - The outside-the-component check now lets through an overhang whose band lies inside that side's slice margin and whose alpha is at most 32 (`overhang_faint`). The Skaven art measures 23 there.
3. **Effect icons.**
   - Every service that applies an effect now opens its description with CA's own effect icon or icons. That is the effects table's `icon`, from `ui/campaign ui/effect_bundles/`, the folder CA's own loc draws from. All 29 icons used were checked present in the ui packs.
   - Services that pay gold or hire units draw none.
   - `GGUI.wrap` keeps an `[[img:]]` as one word (the path has a space) and charges it `GGUI.FLAG_W` rather than measuring it as its path.
   - This applies to all nine races.

Tests: harness header and wrap blocks, each watched red. 11 new mutants, 229 in all, all caught (the first wrap test let one survive, and a mid-line case was added for it). One `HALLS_IN_HEADER` mutant was re-aimed at the measured branch.

Preview font caveat stands: it still cannot answer "does it fit". The header now does not need it to.

## Second look: the reason plate and the favour red (2026-10-05, build FE8EE639)

Asked in game:
- "Needs Sworn" / "Needs Favoured" blended into the panel.
- The red on unaffordable Buy buttons was gone.

1. **`card_need`**, a new card part. It holds CA's padlock and the reason in CA's red, on the race's own price-box plate, with a dark wash over the art.
   - `GGUI.show_need` places it after the name as the game measures it (`GGUI.text_w`), sizes it to its text, and keeps it clear of the price box (`NEED_RIGHT` 590).
   - It remembers its place per card (`NEED_DX`), so a re-layout keeps it.
   - It shows for rank, leader-only and unavailable. A cooldown and a missing target stay on the name line.
   - Every other card use hides it: an empty slot, the bounty board, the Court and the pick card.
2. **`PLATE_WASH`** (`#000000D0`, inset 3px) now sits over every race's price box and reason plate.
   - Red measured 2.3:1 to 4.49:1 on six races' plate art, and `ui_colours` has no brighter red.
   - All nine races now pass the preview's contrast check.
3. **Short of favour is red whatever else shuts the service.** That covers both the price and the Buy caption.
   - `can_buy` reports the rank first, so a card that was both rank-locked and unaffordable never went red.
   - The caption stays orange when only the rank shuts it.
   - **Red on the Buy button measures 3.2:1**, under the panel's 4.5:1 rule. This was chosen because the red hue was asked for. CA's nearest passing colour is `team_colour_enemy_3` (salmon, 4.85:1).

Tests: harness block, each part watched red. 8 new mutants (237 in all), each caught. The first draft let two survive, which needed a real bounty offer and a re-layout.

## The three deferred minors, fixed (2026-10-05, build C3140F92)

1. **Only an under-city's building pays.**
   - `ForeignSlotBuildingCompleteEvent` fires for every foreign slot: allied outposts, the Black Tower, Aislinn's sea patrols, cults and covens.
   - `gg_undercity_building` now pays only when `slot_manager():slot_set_key()` contains `_slot_set_underempire`.
   - That substring matches every `UNDEREMPIRE*` set, including `wh3_dlc29_slot_set_underempire_scruten_startpos`, which CA's own two-prefix test in `wh3_campaign_achievements.lua` misses.
   - It is a pattern find without the plain flag (the plain flag breaks the string library).
2. **Aislinn's letter-suffixed levels** never reach the payment now: sea-patrol outposts are not under-cities.
   - `check_undercity_levels` no longer scans by chain name. It walks CA's tables (slot set, template, chain set, chain or super chain) and keeps the chains `covered_chains()` gives the Skaven. That picks up the warlock lab and the endgame chains.
   - Every level of those chains splits as `<chain>_<n>`.
   - It also asserts the Lua's mark picks out exactly the `UNDEREMPIRE*` slot sets.
   - Selftest: fake rows prove a missed set, a wrongly caught set and an unsplittable level are each reported.
3. **The Grey Seers' text** now reads "A Dwarf or Lizardman general" and "wins over Dwarfs and Lizardmen", matching "the Dwarfs and the Lizardmen" in the same entry.

Tests: harness under-city block. The allied outpost, Black Tower and sea-patrol sets pay 0, and both under-city sets pay 20.
The first draft passed before the fix because the per-turn building cap answered 0, so each case now resets the turn.
2 new mutants, 239 in all, all caught.

## In-game checks (spec §9, open)

1. The Skaven panel opens with its frame. Look at the art as well: it was never viewed.
2. Founding an under-city pays the Eshin Assassins 40. An allied outpost does not.
3. An under-city building pays its guild, and only once: confirm `BuildingCompleted` does not also fire for it.
4. Grey Seer priests route: dropped, so there is nothing to check.
5. Taint income shows on the earnings sheet.
6. A Skaven hall builds.
7. A save from before the update loads.
8. The header's name and figures no longer meet, at the user's UI scale. The rival may read without "The" or sit in the hover.
9. The Skaven cards' line clears the titles, and nothing faint shows between the cards.
10. Effect icons draw in the card text and its hover, at text height.
11. The reason plate sits just past the name, fits its text in the game's font, and the red reads. A Buy caption short of favour is red, and readable enough.

## Open

- **Deferred minor still open:** the temple-routes mirror never prints `taint`. It is a developer check only, and players never see it.
- Not checked offline: scripted start under-cities may fire the founding event at turn 1, a one-time 40.
- GitHub `repos/derpy-great-guilds` is not synced, for this build or the temple's.
