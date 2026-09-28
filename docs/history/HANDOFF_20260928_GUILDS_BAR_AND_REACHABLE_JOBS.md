# Handoff 2026-09-28 - Great Guilds: the guild-button bar, and jobs the player can actually do

Three builds of `derpy_great_guilds.pack` this session, each deployed to the game's `data/`
folder (the Guilds have no Workshop item) with the MD5 of the built and live files matched.
Not uploaded to the Workshop. Pushed to GitHub with a CHANGELOG entry for `FF48368B`.

| Build (MD5) | What | Backup of the previous live pack |
|---|---|---|
| `8298EDCA` | bar moved 4px down (superseded, see below) | `data/derpy_great_guilds.pack.bak_gbar_20260928` |
| `20C88DBC` | bar closed top and bottom; research job asks only for a reachable tech | `.bak_research_20260928` |
| `FF48368B` | building job asks only for an upgrade the player can make now | `.bak_build_jobs_20260928` |
| `33819446` | Guilds button greyed outside the player's turn; tooltips cut to 10 lines or fewer | `.bak_opener_grey_20260928` (= `FF48368B`) |

The live pack before this session was `60CA7EAD` (bounty card tooltips, repo commit
`e260cb3`), one build after the `7AB4585D` the docs-refresh handoff names.

## 1. The bar under the six guild buttons

**Symptom (screenshot, twice):** the bottom of the guild buttons looked cut off.

**Cause:** CA's `dlc23_chd_hell_forge/buttons_holder.png` (419x34) has a bright rim and
angled end caps along its TOP only; its bottom rows are plain dark wood. CA docks it
`Bottom Center` on the Hell-Forge's panel border (`hellforge_panel_category_tab.twui.xml`,
`button_list`, image offset `0,22`, `dockpoint="Bottom Left"`), so the border hides the open
edge. Mid-panel the open edge shows. Nothing clips anything - the round plate's ring is rows
2..35 of 38 and ended on the bar's last row, which read as the buttons being sliced.

**First attempt (`8298EDCA`) was not enough:** moving the bar 4px down made the rings whole
but left the bar's own flat bottom edge, which still read as a cut. The user said so.

**Fix (`20C88DBC`):** `gg_gbar` is now `(240, 595, 310, 40)` and draws the holder TWICE - two
20px halves, the lower one `y_flipped="true"`, each squashed 34->20 and sliced left/right
only (margin `0,20,0,20`, no `tile`). The bar has a rim and caps top and bottom and the rings
sit centred in it. Files: `tools/gen_guilds_ui.py` (`GBAR_LAYERS`, `PANEL_LAYOUT["gg_gbar"]`),
`zzz_derpy_guilds_ui.lua` `GGUI.PANEL_XY.gg_gbar`, `tools/gen_guilds_emitter.py` (new `vflip`
layer key -> `y_flipped`), `tools/preview_guilds_panel.py` (now honours `x_flipped` and
`y_flipped`; TWUI Studio's `rendering.raster` ignores both).

## 2. Research job asked for late-game techs

**Symptom:** on turn 8 the Daemonsmiths asked for Labour Organisation
(`wh3_dlc23_tech_chd_industry_23`, the top of the industry lane).

**Cause:** `bounty_techs()` shipped "the upper half of each tree" and the Lua picked from it
at random with no reachability test.

**Fix:** `bounty_techs()` now ships every node as `{tech, tier, need, {parent techs}}`, built
from `technology_node_links` (node keys mapped to tech keys) and `required_parents`, dropping
the 79 building-gated techs (`technology_required_building_levels_junctions`) as well as the
script-locked ones. `GG.BOUNTY_PICK.research` offers a tech only when at least `need` parents
are researched. The upper-half cut is gone; tier still prices the job (`a * 15`).

## 3. Building job asked for levels the player could not reach

Same shape, applied at the user's request. `bounty_buildings()` rows are now
`{level, rank, {levels that upgrade into it}}`, read off `building_upgrades_junction`
(`from`/`to` columns). `GG.BOUNTY_PICK.build` offers a level only when the player owns one of
its `from` levels and not the level itself. `check_bounty_data()` now fails on a level with no
`from` (it could never be offered) or a `from` the installed game lacks.

## 4. The HUD opener greys outside the player's turn (build `8E611147`, after the push)

Asked for from a screenshot showing the Exchange's button greyed mid-round and ours not.
Mirrors the Exchange (`EX.player_turn`, `EX.gate_button`, `EX.set_off`):
`GGUI.player_turn()` asks `world:is_factions_turn_by_key` and FAILS OPEN on a throw;
`GGUI.gate_opener(on)` is `SetDisabled` plus `set_greyscale_t0` on all states and the count
text (SetDisabled alone draws a live-looking button - the opener has no inactive state). Called
from `place_opener`, from the `gg_opener_place` FactionTurnStart listener DIRECTLY (placement
bails while the top bar is still sliding in, which is exactly the player's turn start), and from
a new `gg_opener_turn_end` listener that also ends a target pick and closes the panel. The click
handler refuses the opener mid-round regardless. Harness block at the end of
`_guilds_harness.lua` (an IIFE: that file's main chunk is at Lua's 200-local limit); three
mutants, 18 in all, every one caught. `zzz_derpy_guilds_ui.lua` is CRLF - a two-line mutant
anchor needs `\r\n`, and Git Bash's `grep -c $'\r$'` reported 0 CRs on it.

Built and verified; deployed with section 5 as `33819446`.

## 5. Tooltips cut to fit (build `33819446`, includes section 4; deployed to `data/`, pushed)

Screenshot: a Court demand card's tooltip ran to 17 lines. Every Court card appended the whole
801-character `court_help`. Measured, not eyeballed: a new block at the end of the fake-UI IIFE
in `_guilds_harness.lua` loads `loc.tsv`'s real English, stands a demand (renounce, tribute,
none), bounties and six guild standings, refreshes all six tabs x six pages, and asserts no
tooltip draws more than 10 lines (55 characters a line, `||` breaks, markup free). `GG_TIPS=1`
prints the ranking. Before: Court cards 16-21, Guilds rank line 17, Leaderboard rows 11-14.
After: worst is 9.

- `court_help` is gone; `court_intro` (Court rank line), `court_help_lead`, `_demand`,
  `_no_demand`, `_patron` - one part per card. The Help tab's Court page has the full rules.
- Leaderboard rows: the table only, no guild description (one click away on the Guilds tab).
- Guild descriptions: the ladder says its phrase once (`_ladder()` in `gen_great_guilds.py`,
  doctested, falls back to the long form if the phrase differs between ranks).
- Upkeep on the Guilds rank line: "Upkeep: -12/turn. Stop earning and you slide back down."
- A mutant putting the description back on Leaderboard rows is caught; 19 mutants in all.
- MCT tooltips (longest 6 lines) and every other loc string (longest 8) checked and left.

## Verified

- `gen_guilds_ui.py --check` and `--selftest`, `gen_great_guilds.py --check`: clean.
- `_guilds_harness.lua` -> `harness ok`; `_guilds_bounty_harness.lua` -> `bounty harness ok`.
  The research and build tests list the must-be-refused rows FIRST, because the harness's
  `RANDOM` stub always rolls 1 - a sampling test cannot fail there (the first draft of this
  test did exactly that and passed nothing).
- `mutate_guilds.py`: 15 mutants, all caught. Three new ones (research gate dropped,
  `required_parents` read as all parents, building upgrade gate dropped) plus the existing
  "a researched tech still offered", whose anchor went stale with the rewrite and was re-aimed.
- `import_great_guilds.py` saved and re-verified the pack each time.
- Offline preview `gg_guilds.png` shows the closed bar. The user's third screenshot (in game,
  after `FF48368B`) shows it closed too.
- Data spot checks: `industry_23` ships with parent `industry_20`; `cth_growth_yang_3` ships
  with both `yang_2` and `yin_2` as `from`.

## Do not re-derive

- `required_parents = 0` means EVERY parent: it is 0 on 1,844 of 1,999 nodes including 75
  with several parents. A nonzero value is how many parents suffice.
- `technology_node_links` columns are `parent_key`/`child_key` and hold NODE keys, not
  technology keys.
- `building_upgrades_junction` columns are `from`/`to`. All 104 bounty levels have a `from`;
  eight Cathay yin/yang level 3s have two. Two Kislev chains (`ksl_court`, `ksl_gold`) branch
  by level number, which is why level-minus-one is wrong.
- The twui image attribute is `y_flipped`, used 319 times in CA's ui packs, alongside
  `x_flipped`. Neither is in TWUI Studio's rasteriser.
- `gen_great_guilds.py --write` also rewrites `zzz_derpy_guilds_ui.lua`; hand edits to
  `GGUI.PANEL_XY` survived it this session.

## Open

- Settlement level still caps a building upgrade (`primary_slot_building_building_level_
  requirement`, no script interface), so a building job can wait on a settlement upgrade first.
  Reachable, not immediate. Accepted.
- A job stays valid if the player loses the region holding the `from` level.
- The ten in-game checks in `HANDOFF_20260927_GUILDS_BOUNTIES_V2.md` are still unplayed.
