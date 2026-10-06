# Great Guilds: the seventh guild, the temple (2026-10-04/05)

**Status: built, packed and deployed to `data/`, not yet seen in game.**

- Pack: `data/derpy_great_guilds.pack`, MD5 `9e2db00e5981aa6f5f1011c63d4d7946` (same as `Modding Files/Modpacks/`).
- No Workshop copy of this pack exists.
- The previous build (`3a48ae51...`) is in `Modding Files/Backup/guilds_pre_temple_20261004/`.
- Spec: `docs/superpowers/specs/2026-10-04-great-guilds-temple-guild-design.md` (§11 records what shipped).
- Plan: `docs/superpowers/plans/2026-10-04-great-guilds-temple-guild.md`.

## What shipped

A seventh guild, key `temple`, appended last everywhere, with no rival:

| Tag | Name |
|---|---|
| (CHD) | The Temple of Hashut |
| `_emp` | The Colleges of Magic |
| `_dwf` | The Ancestor Temples |
| `_brt` | The Grail Pilgrims |
| `_cth` | The Celestial Temples |
| `_ksl` | The Great Orthodoxy |
| `_def` | The Brides of Khaine |
| `_hef` | The Cult of Asuryan |
| `_gen` | The Faith Guild (data shape only, no panel) |

### Earning

- **Buildings** through per-race token lists, `GG.BUILDING_THEME_RACE[tag]`, checked before the shared `GG.BUILDING_THEME`. The shared words are untouched.
- **Four turn and event routes** in `GG.TEMPLE_ROUTES`, with each route's races in spec §3.2:
  - devout provinces, counted per province;
  - provinces clean of all five Chaos corruptions, plus Vampiric for Bretonnia and Kislev;
  - holy war, through `cm:pending_battle_cache_faction_won_battle_against_culture`;
  - priest and wizard hero actions, which pay the temple instead of the spies.
- All of it goes through `GG.capped_grant`, `cap_temple` 40 (60 with the Seat). Ledger sources are `devout`, `chaos`, `holywar` and `priests`.
- The two turn-start routes are also previewed in `GG.turn_start_pay`, so `GG.hold_lead` sees them.

### Ranks, services and bounty

- **Rank ladder:** public order +1/+2/+3/+4.
- **Services:** nine; effects are in spec §11.
- **Bounty:** the army bounty is aimed at the holy-war cultures (`GG.holy_pool`). The building demand is the existing `job_build` bounty (plan ruling 1).

### Hall

- A seventh chain per race. Its local bonus is public order 2/4/6 in the province, and the Seat applies the same effect at faction level, 2.
- **Units:** Lammasu, Giant Slayers, Grail Knights (top level only), Terracotta Sentinel, War Bear Riders, Witch Elves, Phoenix Guard.
- **Empire:** no unit; the College raises the wizard cap by 1/2/3.

### MCT

`rate_temple_devout` (1), `rate_temple_chaos` (2), `rate_temple_holy` (10) and `cap_temple` (40), in all four presets. A frozen tune string reads the defaults.

### Panel and art

- Seven guild buttons (232..520, step 48) on a 486-wide bar.
- Seven standings rows, 34 tall at a 38 step, ending at y=432.
- Nine crests, nine grounds (the seventh window of each race's CA painting), eight hall icon sets and nine bundle icons. All 35 temple files are in the pack.

## Verification

- `gen_great_guilds.py`: `--selftest` passes ("7 guilds, 92 services, 90 bundles, 688 loc") and `--check` exits 0.
- `gen_guilds_ui.py`: `--check` and `--selftest` pass.
- Both harnesses pass.
- `luac -p` passes on every guild Lua file; `check_lua_api` and `check_lua_literal_left` are clean. `check_lua_undeclared` reports the same names it reported before this work.
- `mutate_guilds.py`: 209 of 209 mutants caught, with no survivor and no stale anchor. Thirteen of them are new: the ten temple-rule mutants plus the three from the fix pass below.
- Importer `--check` passes, and the build reports "saved pack verified - every table holds this build's rows".
- Previews (`preview_guilds_panel.py`, which now takes `--page N`): page 7 for CHD, Empire and Dark Elves and the seven-row standings, judged by eye. Help page 2 was judged by exit code only, with no TOO WIDE and no LOW CONTRAST.

### Final review

A fresh Opus reviewer returned "with fixes": 0 Critical and 2 Important, both fixed test first.

1. **Lead flip-flop.** `GG.turn_start_pay` returned 0 for the temple, so two factions close on it would swap the lead every round.
2. **Chaos route read Undivided only.** It counted Saphery's 75 Slaanesh as clean. It now reads Khorne, Nurgle, Slaanesh and Tzeentch too; all keys were read from the installed `db.pack`.

## Rulings

### Plan time (the thirteen, in full in the plan)

1. Bounty, not demand: the temple's build job is the `job_build` bounty.
2. AI buying needs no code.
3. The routes are not behind `race_differences`.
4. Devout counts provinces.
5. Hall units: Giant Slayers and Grail Knights, with Phoenix Guard kept as the one duplicate.
6. A per-guild rank value table.
7. The hall bonus uses `public_order_base` at `province_to_province_own_unseen`.
8. Temple bundles carry their own effects.
9. MCT rate keys and labels.
10. `_gen` carries the full data shape.
11. Help page 2 stays at 18 lines.
12. Shared building words are untouched.
13. `gg_gtab_*` stays hand-written, guarded by the mirror check.

### Executor (in the session ledger)

- Panel icon and MCT names moved into Task 1. `--write` reproduced the block byte for byte.
- Guild-counting test pins were re-derived, never loosened.
- Harness stubs: the cm stub takes `self`, the routes test stubs `GG.player_cultures`, and the greenskin faction is named `a_orcs` in the holy-war test.
- `forge_sermons`, `purge_unclean` and `anathema` are allowed `_unseen` scopes.
- Four names were renamed to clear collisions: `_brt` "Blessing of the Grail" and "The Grail Crusade"; `_cth` "Temple Alms" and "The Dragon's War".
- "All six" wording fixed in three strings.
- `check_building_theme` accepts a guild paid by race lists only.
- The CHD temple hall's AI donor is pinned to `wh3_dlc23_chd_outpost_watch_towers`.
- The standings-row harness pin moved from 44 to 38.
- `wh3_main_corruption_nagash` is left out: it is in no `pooled_resources` row.

## Share of building reputation, per race

Measured from the generated junctions.

| Race | Temple share | Fallback to default |
|---|---|---|
| Chaos Dwarfs | 0% | 8% |
| Empire | 3% | 24% |
| Dwarfs | 2% | 23% |
| Bretonnia | 2% | 16% |
| Cathay | 0% | 43% |
| Kislev | 7% | 27% |
| Dark Elves | 4% | 17% |
| High Elves | 0% | 29% |

The temple's income is mostly its routes. Its race tokens match landmarks and short chains.

### Temple build jobs (`GG.BOUNTY_BUILDINGS[tag].temple`)

- Bretonnia: `wh_main_brt_worship_3`
- Dark Elves: `wh2_main_def_worship_3`
- Empire: `wh3_dlc25_emp_wizards_3`
- High Elves: `wh2_main_hef_worship_3`
- Kislev: `wh3_main_ksl_corruption_land_3`, `wh3_main_ksl_gold_3`, `wh3_main_ksl_gold_3a`
- **None** for the Chaos Dwarfs, Dwarfs and Cathay. Their temple chains stop below level 3, so their temple bounties never ask for a building.

## Open

**In game (spec §9):**

1. The seventh button and page.
2. The temple hall in the Guild Halls tab.
3. Each route on the earnings sheet.
4. An old save loading.
5. One purchase of each service kind.

**Deferred minors from the final review:**

- Stale comments: the MCT Lua's "all twelve guild sliders" and "ALL SIX", and the model's "the six standing pairs".
- The Empire bounty text "an army that marches with their wizards" names a condition the `lord_kill` bounty never checks.
- No mutant on the one-count-per-province rule.
- No harness cases for a temple purchase through `GG.MP_OPS.buy` or for the Seat raising `cap_temple`. The rival-free temple is asserted as table shape only.
- `GG.CHAOS_CULTURES` is declared and never read.
- `gen_great_guilds.py:159` `RANK_NAMES =[` spacing.

**Not done:** the public GitHub repo is not synced (`tools/sync_guilds_repo.py`).
