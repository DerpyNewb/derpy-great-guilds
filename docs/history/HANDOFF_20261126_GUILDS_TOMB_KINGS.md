# Great Guilds: the Tomb Kings (2026-11-26)

Eleventh race of `derpy_great_guilds.pack`. Spec:
`docs/superpowers/specs/2026-11-26-great-guilds-tomb-kings-design.md`. The author accepted its
sign-off list as written and asked for the Tomb Kings and Norsca to be built in parallel.

**Not built, not deployed.** The work was done in an isolated copy of the workspace
(`gg_tmb` in the coordinator's scratchpad) with RPFM, the build, the deploy, the game and the
GitHub sync all off limits. The coordinator merges it with Norsca's copy, reconciles the shared
counts and pins, then builds. Nothing in the live workspace was touched except this file.

## The race

Tag `_tmb`, culture `wh2_dlc09_tmb_tomb_kings`, feed 110 (records 5111-5116). Ranks: Peasant,
Scribe, Vizier, Prince, Priest King.

| Slot | Guild | Pays for | Rival | Hall unit (cap effect, levels 1/2/3) |
|---|---|---|---|---|
| brass | The Royal Treasury | income | none | Nehekharan Horsemen (+1/+1/+1) |
| immortals | The Tomb Guard | battles won | Liche Priesthood | Tomb Guard (+1/+1/+2) |
| daemonsmiths | The Liche Priesthood | technologies; Mortuary Cult crafting | Tomb Guard | Necropolis Knights (the shared knights/stalkers cap, +1/+1/+1) |
| khanate | The Lahmian Sisterhood | hero actions | Cults of the Gods | none; the Undoer's pair, enemy heroes' success -10/-15/-20% |
| overseers | The Necrotects | growth, unclaimed buildings | Charioteer Nobles | Tomb Scorpion (+1/+2/+2) |
| slavers | The Charioteer Nobles | sacking; razing pays more | Necrotects | Skeleton Chariots (+1/+2/+2) |
| temple | The Cults of the Gods | loyal provinces; wins over the Vampire Counts and Nagash | Lahmian Sisterhood | Ushabti (+1/+1/+2) |

**New rules in the model** (`zzz_derpy_guilds.lua`):

- **The first race whose temple has a rival** and whose Treasury has none
  (`GG.RIVALS_RACE["wh2_dlc09_tmb_tomb_kings"]`). `GG.rival_of` already read the race table
  first, so no code changed; only tests did (below).
- **Crafting pays the Liche Priesthood 40** (`EARN_ROUTES.crafted`, ledger source `crafted`).
  A new `RitualCompletedEvent` listener, `gg_earn_crafted`, reads `ritual_category()`,
  `ritual_key()`, `succeeded()` and `performing_faction()`, the accessors CA's own Tomb Kings
  script uses. It skips the two confederation rites CA files as crafting
  (`wh3_main_tmb_confederate_*`). The Dwarf forge shares the category and pays nothing, because
  `GG.race_earn` gates on the culture's route.
- **The unit cap refusal** (`GG.unit_room`, reason `capped`). For a `unit` or `race_army`
  service, `GG.can_buy` asks `unit_cap_remaining` for each unit it would grant. It refuses only
  when every answer is 0; -1 (CA: unlimited), a positive number, a throw or a non-number all
  sell. The card reads "No room" and the tooltip "You already have as many of these units as
  your unit capacity allows."
- **Canopic Jars as the tithe:** 150 under `missions` for a Tomb Kings faction that holds
  `tmb_canopic_jars`, gold for one that does not.
- **The dead remember** (twist): rivalry x1.5, upkeep x0.5.
- **Recruiting by key**, as the spec's §3.4 table. Arkhan and his necromantic roster pay
  nobody. The Tomb Herald pays the Tomb Guard, whatever agent type his faction files him under.
- **Hire unit:** Tomb Guard.
- **Three race services**, rows 99-101 (Norsca takes 102-104):

  | Service | Guild, rank | Effect |
  |---|---|---|
  | The Royal Offering | Royal Treasury, 2 | +50 Canopic Jars; needs the pool |
  | The Awakening | Liche Priesthood, 3 | a Skeleton Warriors and a Skeleton Spearmen regiment for the selected army, if there is room |
  | The King's Legions | Tomb Guard, 4, lead | +1 unit capacity for every unit, 10 turns |

- **Shared services re-aimed for this race** (`for_tag`): the mercenary contract gives -15%
  hero recruitment cost (no Tomb Kings unit costs gold), and the treasury seal -20% Mortuary
  Cult crafting cost.

**Temple:** ward save at rank (the Bretonnian ladder, 2/4/6/8, leader 5). Hall: public order
+2/4/6 in the province, CA's own Obelisk pair. Seat: public order +1 in every province. The
holy war asks the battle cache about `wh_main_vmp_vampire_counts` and
`wh3_dlc29_nag_undead_legions`.

**Halls:** Sepulchre / Mausoleum / Necropolis; the temple's are Shrine of the Gods / Temple of
the Gods / Great Temple of the Gods. Set `wh2_dlc09_bas_tmb`; the donor rule picked
`wh2_dlc09_tmb_cavalry`. Every hall unit but the two Skeleton regiments has `campaign_cap` 0,
so each hall carries its unit's cap effect at CA's `building_to_faction_own`, at or under CA's
own per-building values (`HALL_EXTRA`).

## Panel, art and grounds

**Frame** (`FRAMES["_tmb"]`, `GGUI.FRAME._tmb`). The spec allowed a copy of `_chs` until the
Tomb Kings art was measured. It was measured: their skin has HUD bars and the Mortuary Cult's
button, but no card plate, no tab states and no empty holder. The Black Pyramid has all three,
and it is Nagash's. So the frame is the Warriors of Chaos frame (Tamurkhan's plate, number
plate and subtitle tabs, the Souls track, all bronze and rust with no god's mark) with these
changes:

- rank strip: the Tomb Kings' `bar_small_central_left`, a nemes-crowned skull at each end,
  measured to column 69 and from 671 (`rank_tx` 76, `RANK_STATS_PAD` 76, `HEADER_INSET` 152);
- guild bar: the Tomb Kings' `bar_small_buttons`, a winged scarab at each end;
- Buy button: the Mortuary Cult's craft button, `mortuary_cult_button_active`, 22px ends, with
  the turquoise ring on hover;
- heat, rim and open-tab ring: turquoise `#30F0E0`, the commonest saturated colour of CA's
  Tomb Kings rite flare (`rite_tmb_text_holder.png`). CA's `ui_colours_tables` has no Tomb
  Kings colour;
- icon holder: CA's round bronze holder, the Chaos Dwarf one. The Undivided slot's eight
  points are a Chaos star.

**Icons** (`make_guild_icons.py`): CA's own Tomb Kings building icons, each measured flat. The
Treasury takes the income icon, the Tomb Guard the infantry barracks, the Liche Priesthood the
winged sarcophagus (growth), the Sisterhood Lahmia's city icon, the Necrotects the settlement
pyramid, the Charioteers the chariot works, the Cults the Ushabti; the crest is Khemri. Hall
icons and the halls tab icon follow the same rule. Bundle icons came from
`make_guild_bundle_icons.py`.

**Grounds** (`make_guild_backgrounds.py`): windows of `campaign_tomb_kings1.png` as the spec
proposed (Treasury 1, Necrotects 2, Liche Priesthood 3, Tomb Guard 4, Charioteers 5, temple 7),
darkened by 0.31-0.36. The Sisterhood's is lent from `campaign_vampire_lahmian_sisterhood1.png`,
window 3, the white-haired sister. Windows 2 and 7 cut Neferata off at the face, and the
windows are shared, so no new one was added. The selftest's `LENT` clause now checks the Tomb
Kings by tag: six of their own windows and exactly one lent ground, the Sisterhood's.

## Rulings and deviations from the spec

1. **The frame**, above: measured and partly replaced rather than left a plain `_chs` copy.
2. **Spec §4.6's description of the temple's default services is wrong.** It says "physical
   resistance; charge and melee attack; Winds and leadership". The shared non-Chaos-Dwarf
   defaults are leadership +6 (the blessing), melee +6 and charge +10% (zeal), and leadership
   +6 with replenishment +10% (the holy war). No override was added, which is what the spec
   intended.
3. **A multi-unit grant is refused only when nothing fits.** The spec says to refuse when
   `unit_cap_remaining` is 0 "for the unit to be granted". The Awakening grants only the two
   uncapped units, so it never meets a cap; a future multi-unit service with capped units
   would sell a partial grant.
4. **The Sisterhood's ground is window 3 of the Lahmian painting**, not Neferata.
5. **The importer's race tuple** has `"tmb"` straight after `"chs"`, per the coordinator's merge
   rule, so it is no longer alphabetical.
6. **`Modding Files/source/guild_icons`** was a junction to the live folder in the copy, and
   `make_guild_icons.py` writes the CA sources it fetches into it. The junction was replaced
   with a real folder holding a copy of the 117 top-level PNGs and `cat/`; the live folder was
   checked unchanged (831 files before and after). The merge has to bring the fetched Tomb
   Kings stems across.
7. Hall text reads "Unit capacity for Tomb Guard +1" and so on, to match the other hall lines.

## Shared assertions changed (the temple-rival change and the counts)

- `_guilds_harness.lua`, per-race rivals block: the "every other race keeps the global table"
  loop now skips `wh2_dlc09_tmb_tomb_kings` as well as the Warriors of Chaos. A Tomb Kings case
  was added in the same block: the temple paired with the Sisterhood, the Treasury unpaired, and
  grants that cost the right guild.
- `_guilds_harness.lua` 1375 and 10039 (the global table leaves the temple unpaired) and 10758
  (the Undivided is unpaired) are unchanged and still true.
- `_guilds_harness.lua`: `#GG.SERVICES` 98 to 101; the Warriors' "rows are last" pin became
  absolute rows 96-98, as the Skaven's became 93-95.
- `gen_great_guilds.py` selftest: race services 35 to 38; `FLAVOURS` order gains `_tmb` before
  `_gen`; hall sets 10 to 11; the temple AI donor tuple gains `_tmb`; `want_hall`, `want_seat`
  and `want_rank` gain `_tmb`; the "no temple hall is public order" assertion skips `_tmb`,
  whose temple hall is public order by spec §6. A new `want_tmb` block pins the six hall cap
  effects, their scope and values, and that the Sisterhood's hall trains nothing.
- `make_guild_icons.py` selftest: hall icons 70 to 77.
- `_guilds_bounty_harness.lua`: the Tomb Kings in the `want` twist table, and their halved
  upkeep and 60% rivalry in "where the twists bite".

## Verified offline (all run inside the copy)

- **Generator:** `--write`; `--check` exit 0; `--selftest` 7 guilds, 101 services, 90 bundles,
  946 loc.
- **UI:** `gen_guilds_ui.py` `--write`, `--check` exit 0, `--selftest` 76 files, 12,200 GUIDs;
  `check_guilds_ui` 0 problems, its selftest 6/6. Only the six new `_tmb` panel and card files
  differ from the live set.
- **Grounds:** `make_guild_backgrounds.py` selftest ok, `--check` exit 0; only the seven new
  `_tmb` grounds differ from the live set.
- **Icons:** `make_guild_icons.py --selftest` ok; `make_guild_bundle_icons.py` selftest and
  `--check` ok. Only new `_tmb` files differ from the live set.
- **Harnesses:** `_guilds_harness.lua` "harness ok"; `_guilds_bounty_harness.lua` "bounty
  harness ok" (131 blocks).
- **Lua:** `luac -p` on all five files; `check_lua_api` 0 suspect calls;
  `check_lua_literal_left` 0; `check_lua_undeclared` reports `BUTTON`, `BUTTON_GAP`,
  `BUTTON_SIZE` and `DERPY_HUB` in the UI file, the same four the live files report.
- **Importer:** `import_great_guilds.py --check` exit 0: 1,154 bundles, 1,273 junctions, 11,197
  loc, 4 scripts, 76 UI files.
- **Effect signs and bundle loc:** `check_effect_signs.py` and `check_effect_bundle_loc.py` need
  RPFM and a built pack, so they were not run. Offline equivalents on the TSVs: every one of
  the 1,154 bundles has its title and description loc; the only penalty-signed `_tmb` rows are
  the seven every race has (the enemy-targeted services and the loan's downside).
- **Previews:** `preview_guilds_panel.py --flavour tmb` exit 0, no TOO WIDE, no LOW CONTRAST.
  Read: the Guilds tab (Treasury, Sisterhood and Cults pages), Leaderboard, Bounties, Court,
  Log, Help page 1 and the pick card; Help pages 2, 4, 5, 6 and 7 read as text.
- **Mutation:** `mutate_guilds.py` caught 302 of 302 (284 before, 18 new for this race), with
  no survivor, no stale anchor and no error, and the Lua restored byte for byte. The 18 cover
  the confederate skip, the category test, the failed craft, the craft's 40, the cap refusal's
  -1 and its throw, the hire's own unit, the refusal itself, both halves of the jars branch, the
  temple pairing, the twist's rivalry, Nagash in the holy war, the Herald, Arkhan, his ghouls,
  the Stalkers and the Awakening's grant. The halls' cap effects are DB rows no harness sees;
  the generator selftest's `want_tmb` pins them.
- **Comments:** the comments this work added were stripped afterwards (the author's global
  rule), keeping only the two that stop a fix from being undone: why the cap refusal exists and
  why characters route by key. Every check above was run again after the strip.

## In game, open

1. The panel opens with its frame, and the Sisterhood's page shows the Lahmian ground.
2. `unit_cap_remaining` returns the numbers the recruitment panel shows, and -1 for the
   Skeleton regiments. CA's doc entry names another function on its parameter line, and no CA
   script calls it.
3. What `grant_unit_to_character` does at the cap (the refusal guards against it either way).
4. Units over the cap when The King's Legions expires: whether the engine keeps or removes them.
5. An AI Tomb Kings craft fires `RitualCompletedEvent` the way the player's does.
6. The Canopic Jars tooltip shows the tithe and the Royal Offering under `missions`.
7. A hall raises its unit's cap on the recruitment panel.
8. A save from before the update loads (the harness proves a blank load; the game must agree).
9. The card's spikes and the Mortuary Cult Buy button read right at the author's UI scale.

## Open

- **The Liche Priesthood's only build jobs are Arkhan's burial mound** (levels 3 and 4,
  `GG.BOUNTY_BUILDINGS._tmb`), which only Arkhan's faction can build. Every other Tomb Kings
  player gets no Liche Priesthood build bounty, and **the Sisterhood has none** at all.
- The building share per guild was not measured.
- `docs/SESSION_INDEX.md` needs its one line for this handoff; the copy could not write it.

## Files changed in the copy

Paths are relative to the copy's root, which mirrors the workspace.

**Edited:**

- `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`
- `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` (hand edits, plus
  `GGUI.MCT_NAMES` regenerated)
- `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua` (generated)
- `Modding Files/source/great_guilds/*.tsv`, all 24 (generated)
- `tools/gen_great_guilds.py`, `tools/gen_guilds_ui.py`, `tools/make_guild_icons.py`,
  `tools/make_guild_backgrounds.py`, `tools/import_great_guilds.py`, `tools/mutate_guilds.py`,
  `tools/_guilds_harness.lua`, `tools/_guilds_bounty_harness.lua`, `tools/ui_icon_sizes.json`

**Added (44):**

- `Modding Files/pack/ui/campaign ui/derpy_gg_{panel,card}_tmb{,_sm,_lg}.twui.xml` (6)
- `Modding Files/pack/ui/campaign ui/derpy_gg_icons/{brass,immortals,daemonsmiths,khanate,overseers,slavers,temple,crest}_tmb.png` (8)
- `Modding Files/pack/ui/campaign ui/derpy_gg_bg/<guild>_tmb.png` (7)
- `Modding Files/pack/ui/campaign ui/effect_bundles/derpy_gg_<guild>_tmb.png` (7)
- `Modding Files/pack/ui/buildings/icons/derpy_gg_hall_<guild>_tmb.png` (7) and
  `derpy_gg_tab_halls_tmb.png` (1)
- `Modding Files/source/guild_icons/`: the eight CA Tomb Kings icon sources
  (`tmb_ income.png`, `tmb_ infantry_barracks.png`, `tmb_ growth.png`, `tmb_settlement.png`,
  `tmb_ chariot_artillery.png`, `tmb_ushabti.png`, `tomb_kings_city_lahmia.png`,
  `tomb_kings_city_khemri.png`) and `cat/tomb_kings_cat_basic_military.png` (9)

**Not this work:** `tools/gen_engine_reverse_anims.py` and `tools/gen_tank_controls.py` differ
too, because the live copies were edited this morning, after the copy was made. The copy's
versions are older, so they must not be merged back.
