# Great Guilds: guild halls, stage 2 (the other seven races), built, packed and deployed

2026-10-04. **Current build `9FC1E42F` (md5 `9fc1e42ffa81233a8612309826d5f07f`), deployed to data/, adds the Chaos Dwarf settlement-type rows (last section); the build before it:** `9DEF04A4` (md5 `9def04a451a727cf969d9231e3c48099`), built in
`Modding Files/Modpacks/` and **deployed to data/** once the game closed (MD5 match); the prior
`9A81A01B` is backed up in `Modding Files/Backup/guilds_pre_category_20261004/`. It adds the Guild
Halls category (last section). Stage 2's own build `9A81A01B` superseded stage 1's `FBCC9948`, which
is in `Modding Files/Backup/guilds_pre_halls_stage2_20261004/`. **The CHD Guild Halls tab is seen working in game on `9FC1E42F` (last section); the other races are not.** Stage 1's eight
in-game checks are still unrun and come first; the stage-2 checks are in OPEN below. No Workshop
copy of this pack exists, so nothing went to a Workshop folder.

Stage 1 (the Chaos Dwarfs, the design, the Lua and every do-not-re-derive fact that still holds) is
`docs/sessions/HANDOFF_20261004_GUILDS_HALLS_STAGE1.md`. Read it first.

## Built

Plan `superpowers/plans/2026-10-04-great-guilds-halls-stage2.md`, tasks 1-4, then a final review and
a fix wave before the pack was built once.

- **Seven more races**: Empire (`_emp`), Dwarfs (`_dwf`), Bretonnia (`_brt`), Grand Cathay (`_cth`),
  Kislev (`_ksl`), Dark Elves (`_def`), High Elves (`_hef`). Eight races with the Chaos Dwarfs, six
  guilds each, three levels each.
- **Pack contents**: 144 hall levels, 48 chains, 8 superchains, one `derpy_gg_hall` instances row,
  48 Seat bundles, 48 hall icons at `ui/buildings/icons/derpy_gg_hall_*.png` (42 new), 142 units
  allowed rows, 48 AI construction values, 96 upgrade edges, 96 chain set items, 48 set-to-building
  rows, 144 culture variants, 2014 `building_effects_junction` rows, 738 bundles, 804 bundle
  junctions, 7188 loc keys.
- **Availability sets**: 66 rows, the 48 base ones plus 18 extra-set rows (Lokhir, Aislinn and
  Bhashiva, 6 each).
- **Generator**: `hall_tables()` loops `HALL_TAGS`; `HALL_RACES` holds the seven new entries; the
  donor chain per race is picked by rule (`_hall_donor`: in the race's set, trains a unit, shown in
  the UI panel set; printed by `--check`). `check_halls()` gained the DLC rule, the description-vs-rows
  rule, the availability-set coverage rule and the panel-set rule, each with a `--selftest` break.
- **Lua**: tag-aware roster, one shared instance key, per-race header (below), `hall_cut` scaled by
  `hostile_price`, "Needs the rank of X with Y" for all eight races.

## Verified, and how

- `import_great_guilds.py --check`: every TSV matches `build()`, exit 0.
- Duplicate keys, checked before saving against `db.pack`: no duplicate within the pack and no
  clash with vanilla for building levels (144), chains (48), superchains (8), instances (1), units
  allowed keys (142), bundles (738) or culture variant buildings (144).
- Import saved the pack and re-opened it in a fresh session: "saved pack verified - every table
  holds this build's rows" (content compared against `build()`, not counts alone).
- Row counts read independently from the saved pack with `read_vanilla_db`: availability sets 66,
  set items 96, chains 48, culture variants 144, effects junction 2014, instances 1, levels 144,
  set-to-building 48, superchains 8, units allowed 142, upgrades 96, AI values 48, bundles 738,
  bundle junctions 804, effects 49. Each equals its TSV.
- `read_pack_index.py`: 275 paths, none with an uppercase letter; 48 `derpy_gg_hall_*.png`; the four
  `zzz_derpy_guilds*.lua` scripts and the MCT file are byte-identical to the staged copies.
- `check_effect_bundle_loc.py`: 738 bundles, 7188 loc keys, 0 findings. All 48 `derpy_gg_seat_*`
  bundles have title and description loc.
- `check_effect_signs.py`: exit 0, 804 junction rows, 54 penalty rows, all `derpy_gg_svc_*` service
  rows (deliberate downsides to a rival). No hall or Seat row. The tool reads bundle junctions only,
  so hall levels' own effects were read by hand: the only negative values are the Overseers
  construction cost rows (-5/-10/-15), a discount; every other hall effect is positive.
- Deployed after `Warhammer3.exe` was confirmed shut; MD5 of the Modpacks copy equals data/.
- Code gates passed in the tasks and the final fix wave: gen `--check` and `--selftest`, both
  harnesses, `mutate_guilds` 196/196 caught, preview width checks.

## Corrections to the plan and spec

- **One instance key for all 144 levels** (`derpy_gg_hall`), not one per race. Spec §1: one hall
  per settlement. A captured city holding another race's hall cannot take the new owner's hall
  until the old one is demolished.
- **DLC rule is overlap, not subset.** Spec §8.2 says any one product will do; a subset test would
  reject every base-game fallback.
- **`race_products`** is the majority product of a race's non-rebel factions. Cathay and Kislev rest
  on 9 vs 7; no base unit was misflagged as DLC.
- **Donor rule** tightened in review: the donor must be in the race's set, in the generic minor
  group, have a panel row, name the race's culture (empty culture is the fallback; Dwarfs, Dark Elves
  and High Elves ship it empty) and train a unit. The first rule picked `wh3_main_foreign_slot_endgame`
  for Empire and Cathay.
- **AI donors** (`_cai_donor`) fall back to the race's hall donor; zero-score rows are excluded and
  asserted positive (Cathay overseers use `wh3_main_cth_cavalry`, 1100/1500).
- **Extra availability sets** (final review I1): Lokhir (`wh3_main_def_lokhir`), Aislinn
  (`wh3_dlc27_bas_aislinn`) and Bhashiva (`wh3_cp1_bas_cth_bhashiva`) are playable factions with
  their own sets. Without them they would see no halls. `HALL_SET_EXCEPTIONS` holds one entry.
- **Southern Realms exception**: `wh_main_bas_teb` (Tilea, Estalia, the Border Princes; Empire
  culture, 10 factions, none playable) gets no halls. They are not the Empire's guilds. Cost: the
  Tilean and Estalian AIs build no halls. Lore over coverage.
- **Dwarf panel set**: the donor's panel row must be in a set with `show_in_ui` true. The first
  pick was `wh3_dlc29_set_dwf_military_support_partial`, which is hidden.
- **Per-race header table**: Lua cannot measure pixel width, and a character budget does not track it
  (Empire fits at 100 chars, Cathay overflows at 95). The "Halls n" figure sits on the header bar for
  the Chaos Dwarfs, Empire and Dwarfs, and in the header's hover for Bretonnia, Cathay, Kislev, Dark
  Elves and High Elves (`GGUI.HALLS_IN_HEADER`, with an assertion and a mutant). The preview's width
  check guards later drift.
- **Cathay Khanate level 0 text** names the DLC unit alone for a non-owner; the text now says "if you
  own the pack that adds it". A `check_halls` rule compares each description's units with the
  `building_units_allowed` rows.
- **The Dark Elf `hostile_price` twist** now scales `hall_cut`, closing stage 1's deferred minor.

## Do-not-re-derive facts

- `hall_tag_of`, `HALL_TAGS` (8) and `GG.hall_key(guild, n, tag)` are the only places a tag is built.
- Level nouns: Empire Guildhouse/Guildhall/Grand Guildhall; Dwarfs and Kislev Lodge/Hall/Great Hall;
  Bretonnia Chapterhouse/Commandery/Grand Commandery; Cathay Pavilion/Hall/Palace; Dark Elves and
  High Elves Lodge/Hall/Tower.
- Effects are the same six at the same values for every race; the Seat follows `HALL_SEAT_SCOPE`.
- Stage 1's facts (rank indices, costs, `faction_unique`, locks stop construction only, icons ship
  from a shared folder and are packed by prefix) all still hold.
- An AI faction of a hall race in a campaign where the player is another hall race has all 18 levels
  shut (`GG.hall_culture`). Two humans of different hall races are each locked and paid by their own
  race's keys. Both have harness blocks.
- The `ui/buildings/icons` art is CA-derived and ships in the pack only, never a public repo.

## OPEN

Run these on the Default preset.

**1. Stage 1's eight in-game checks** are still unrun and come first. They are in
`docs/sessions/HANDOFF_20261004_GUILDS_HALLS_STAGE1.md`, section OPEN. If check 1 (one hall per
settlement) fails, stop: the fallback is the per-region chain lock in spec §10, which is script-side
and generic, so stage 2's data survives.

**2. Every new race.**
- **Setup:** through the bridge, raise one guild to that race's level-0 rank. Then open an empty
  secondary slot in a settlement of level 2 or higher.
- **Before the promotion:** all six halls show CA's restricted icon, with the red tooltip "Needs the
  rank of <rank> with <guild>." in that race's rank and guild names.
- **After the promotion:** the level-0 hall can be built. Its card shows the race's noun, its own
  icon, its own description, and a category icon, not a placeholder.
- **Once built:** its bonus shows on the settlement; its unit is in the recruit list at rank 0; the
  next turn's Reputation tooltip has a "Halls" line.
- **The "Halls n" figure:** on the header bar for the Chaos Dwarfs, Empire and Dwarfs; in the
  header's hover for the other five races.

| Race | Play as | Build | Pass |
|---|---|---|---|
| Empire | Karl Franz | Merchant Guilds Guildhouse; Thieves' Guild Guildhouse | The Merchant Guilds Guildhouse gives Pistoliers. The Thieves' Guild Guildhouse trains Crossbowmen only; its Guildhall adds Huntsmen at 1 chevron |
| Dwarfs | Thorgrim | Merchant Clans Lodge; Rangers Lodge | Thunderers. Rangers and Quarrellers. The card carries the Dwarf military support category art |
| Bretonnia | Louen | Wine Merchants and Knights Errant Chapterhouses | Mounted Yeomen. Knights Errant at level 0 |
| Cathay | Miao Ying, then Bhashiva | Caravan Masters and Crow Society Pavilions | Peasant Horsemen. Onyx Crowmen only at the Pavilion ("if you own the pack that adds it"); Crane Gunners from the Hall. **As Bhashiva, halls appear** |
| Kislev | Katarin | Stanitsa Builders Lodge; Oblast Smugglers Lodge | Kossars, and -5% construction cost in the province. Akshina Ambushers and Horse Archers |
| Dark Elves | Malekith, then **Lokhir** | Karond Kar Traders Lodge; Convent of Ghrond Lodge | Dark Riders. Doomfire Warlocks and Reaper Bolt Throwers. **As Lokhir, halls appear** |
| High Elves | Tyrion, then **Aislinn** | Lothern Merchants Lodge; Shadow Warriors Lodge | Lothern Sea Guard. Shadow Warriors and Archers. **As Aislinn, halls appear** |

**3. Also watch for.**
- **The Cathay AI.** In a Cathay campaign, after about 20 turns, at least one Cathay AI that is
  Indebted or higher with the Bastion Builders owns one of their halls.
- **The Dark Elf price line.** With the hostile-price twist, the "Includes halls" line matches the cut
  actually taken off the price.
- **The cost of the lock sweep (final review M2).** The first tick of a session writes up to about
  3,400 lock records: one per level, for every faction of a hall race. Time the first tick on a load.
  Save, then reload three times, and compare the save file sizes. They should not grow by thousands
  of records each time.

**4. Spec §10.8, DLC hiding (the seven DLC units).**
1. Through the bridge, call `cm:faction_has_dlc_or_is_ai(p, <human>)` for each of
   `TW_WH2_DLC13_HUNTER`, `TW_WH1_LORDS_AND_UNITS_1`, `TW_WH1_LORDS_AND_UNITS_2`,
   `TW_WH3_SHADOWS_OF_CHANGE_CTH`, `TW_WH3_SHADOWS_OF_CHANGE` / `_KSL`, `TW_WH2_DLC10_QUEEN_CRONE`.
2. For each product the call reports **false**: play that race and build the hall level that holds
   the DLC unit. **Pass:** the DLC unit is missing from the recruit list and its fallback is there.
   **Fail:** the DLC unit can be recruited; the fallback plan is spec §10's script restriction.
3. For each product that reports **true**, both units appear.
4. If every product reports true, §10.8 stays OPEN until it is tested on an account missing one.

**5. Deferred minors.**
- Stage 1's deferred minors in its handoff still stand (dead per-chain instances rows, lowercase
  selftest coverage, flat `additional_loot_value`, AI price one-turn lag, unclamped `hall_rep`,
  Help page 7 never seen in game, `check_lua_api.py` on `ai_test_tower_of_zharr.lua`, AI scores
  inferred not watched). Its `hostile_price` item is closed here.
- **AI donors by rule 1** (the hall's own effect, for example Immortals to replenishment chains)
  stand; values only, no gating copied. If AI build priority is off, stage 1's check 5 shows it.
- **Emblem icons**: Empire brass and Cathay khanate reuse CA's chain icons, which are emblems shared
  with the cards. Accepted.
- **Pre-existing, not stage 2**: `preview_guilds_panel.py --flavour cth` reports LOW CONTRAST 4.3:1 on
  `gg_gtab_1`'s "1", present without halls.
- **Southern Realms** (Tilea, Estalia, Border Princes) and any other Empire-culture AI faction on
  `wh_main_bas_teb` build no halls, by design.

## Guild Halls category (2026-10-04, after the first in-game look)

**What changed.** The halls were not on the Chaos Dwarf Advanced Military tab. They now have a tab
of their own: one `building_sets` row per hall race, `derpy_gg_set_guild_halls<tag>` (8 rows), cloned
field for field from the race's old panel set, with a new key and a full-path lowercase tab icon
`ui/buildings/icons/derpy_gg_tab_halls<tag>.png`. `sort_order` is the donor's plus one, moved up past
any number the race already shows (7 for Chaos Dwarfs, Cathay and Kislev; 9 for the rest). Every hall
chain's `building_set_to_building_junctions` row (48) points at its race's set and nothing else. Loc:
`building_sets_onscreen_name_` is "Guild Halls", and the description names the race's own rank word
(Indebted, Apprentice...). Help page 7 gained one line about the tab. The eight icons are each race's
own category scroll with the glyph painted out and the race's guild crest drawn in gold
(`make_guild_icons.py build_tabs`). `import_great_guilds.py` packs `derpy_gg_tab_halls*.png` and
refuses a build whose set icon is not staged. Spec section 3.2 is amended (the panel set is minted).

**Why they did not show (inferred, not watched - and WRONG, see the last section: the cause was the settlement-type gate, and a locked hall draws greyed).** CA's `building_browser.twui.xml` lists a
category's chains with `BuildingChainList.Filter(LevelsList.FirstContext.HasLifecycleState)`. Below
Indebted, a hall's first level is event-restricted by `GG.lock_halls`, so the chain probably fails
that filter and is not drawn. The lock is unchanged: a guild's halls appear once you are Indebted.

**New in-game check.** For each race: the Guild Halls tab shows with its own icon and no magenta
square; it is empty or absent below Indebted; it lists the guild's halls once Indebted. If the tab
shows but the halls do not, the filter inference holds; if the tab itself never draws, a minted set
did not draw and the rollback is the backup above.

## Chaos Dwarf settlement types (2026-10-04, found live through the bridge)

**The Chaos Dwarf halls were buildable nowhere**, whatever the lock or the tab. Probed in
the author's IEE Conclave campaign: `CcoCampaignSettlement.BuildingSlotList.At(i)
.PossibleBuildingChainsList` offered no hall chain in any slot of a factory (Falls of Doom),
an outpost (Gash Kadrak) or the tower (Zharr-Naggrund), even with `derpy_gg_hall_brass_0`'s
lock lifted by hand.

**Cause: `settlement_type_to_building_chains_junctions`.** Every Chaos Dwarf settlement is
a `wh3_dlc23_chd_factory`, `_outpost` or `_tower`, and its slots offer only the chains that
table lists for that type. CA's own chains carry it (tower on 53 of the 72 CHD-only chains,
factory 47, outpost 45; K'daai and Beasts are tower-only, War Machines factory and tower).
The halls had no rows. No other hall race is gated this way: their own chains carry only
scattered occupation types (Norscan altars, daemon realms), never a majority.

**Fix:** `HALL_RACES[""]["settlement_types"]` lists all three, so a Chaos Dwarf hall can be
raised in any of them (18 rows). `check_halls()`'s `_stype_problems` derives, per race, the
types most of that race's own chains carry, and fails a hall chain missing one, or carrying
one the race does not mostly use (that would hide it everywhere else). It reported all 18
missing rows against the shipped data before the fix; selftest break `stype`.

**Seen in game on `9FC1E42F` (2026-10-04, the author's Conclave campaign, a CHD settlement):**
the Guild Halls tab draws with its icon and its "Guild Halls" name, and lists all six CHD hall
chains at levels II-IV. Below Indebted every level is drawn greyed with a red cross, NOT hidden,
and the hover shows the hall's name, set name, description, rep line, income effect and unit,
with the red footer "Needs the rank of Indebted with the Brass Tablets." So the
`HasLifecycleState` filter inference in the category section above was **wrong**: an
event-restricted first level does not hide a chain, and the lock reads as intended. The other
seven races' tabs are still unseen.

**The unlock, driven live through the bridge (same session, save `claude_unlock_debug` taken
first):** `GG.grant(conclave, "brass", 85)` took Brass from 15 to 100 (rank 2, Indebted);
`apply_rank` -> `lock_halls` released `derpy_gg_hall_brass_0` and kept `_1`/`_2` shut, and the
browser then drew level II as constructible ("Left-click to construct") while III and IV kept
their crosses. The whole chain from promotion to engine works on the Chaos Dwarfs. Not yet seen:
the rank 4 unlock of level III, and the leader-only level IV.
**Debug trap:** a bare `GG.grant` from the bridge lives in memory only - the next listener's
`GG.load` reverted it (100 back to 15, then +10 for a building), and the Caravan Levy the
player then tried was refused on rank with no log line. A live grant must be
`GG.load(f); GG.grant(...); GG.save(f)`.

## Build `AED8DFF1` (2026-10-04, deployed to data/, MD5 match; `9FC1E42F` backed up in `Modding Files/Backup/guilds_pre_hall_numbers_20261004/`)

- **Court header overlap, fixed.** In game "The Daemonsmiths" plus "Demands, patronage and who
  leads.   Favoured   Reputation 1180" ran the two header cells into each other. The tagline is
  gone from the Court's figures (`zzz_derpy_guilds_ui.lua`, TAB 4); the `hdr_court` loc row
  still ships, unused. The preview's overlap check never saw it: it draws one guild (Brass,
  150) and PIL's font is narrower than the game's. Its worst case is still unmeasured.
- **Hall text gives the numbers.** `hall_desc` now reads "Earns 4/8/15 Reputation and 4/8/15
  Favour with ... each turn" from `HALL_REP` (GG.grant adds to both), and Help page 7 says
  "4, 8 or 15 by level". Before, it said only "a bigger hall pays more". The figure is the
  default; the `hall_rep` MCT slider scales the real payment and the text does not follow it.

## Bound Blueprint's research reverts (found live 2026-10-04; FIXED, see the end of this section)

Measured through the bridge in the author's Conclave campaign:
- Bound Blueprint was bought (favour taken, cooldown 14, no refund), yet the technology was not
  held afterwards.
- `cm:instantly_research_technology` on the CURRENT research (`military_4`, Hollow Rounds):
  `has_technology` true at once and 3 s later, and `ResearchCompleted` fired synchronously. When
  the player then changed the research queue, `has_technology` went back to **false**. The
  technology sat in the queue at "1 turn", and CCO `CurrentResearchingTechnologyContext
  .ResearchPointsCost` read 0, so the engine took the technology back but kept it fully paid.
- The same call on a technology that was NOT the current research (`military_3`) held through
  a queue change.
- So the engine undoes an instant completion of the in-progress research when the queue is
  re-planned. Bound Blueprint always targets the in-progress research (`GG.research_target`
  reads the ResearchStarted memo), so it always hits this.
- **Still open:** whether the paid-off technology completes on its own at the next turn start
  (the game closed before an end turn). If it does, the likely fix is `cm:grant_research_points`
  for the remaining cost, which goes through the queue and cannot be taken back. Note
  `ResearchPointsCost` must be read BEFORE paying. Great Work (`kind="research"`) uses the same
  payload.
- **Minor, same area:** `gg_tech`'s `ResearchCompleted` listener clears the research memo
  unconditionally, so finishing any other technology also empties Bound Blueprint's target
  until the next ResearchStarted.
- The test left the save in an odd state: Hollow Rounds was held without Call to War for a while.
  The save `claude_unlock_debug` predates all of the bridge changes.
- **Reproduced, and the fix proven live.** In a second session the player bought Bound
  Blueprint again and saw it revert again. Through the bridge, `cm:grant_research_points(f,
  ResearchPointsCost)` (300 for Hollow Rounds) completed the current research at once:
  `ResearchCompleted` fired, the queue emptied, and the tech HELD after the player clicked
  another one.
- **The fix.** `GGUI.wire_target` sends the points left on the current research, read off CCO
  on the buyer's machine (`GGUI.research_left`), as the research service's wire field.
  `GG.MP_OPS.buy` parses them (1..`GG.RESEARCH_POINTS_MAX`, else nil) and passes them through
  `GG.buy(..., points)` to `GG.payload`, which calls `cm:grant_research_points`. No points
  (the AI, or an unreadable CCO) keeps the old `instantly_research_technology`. CCO is read
  only in the UI because the payload runs on every machine in multiplayer. Harness block "A
  RESEARCH SERVICE PAYS POINTS" was seen failing with each half broken; `mutate_guilds.py`
  has two new mutants and its `pcall(GG.payload...)` anchor was updated.
  Not yet seen in game: Great Work, which uses the same path, and multiplayer.
- **Shipped in build `577B5FEB`** (md5 `577b5feb2f5c60b8e6c9a21e08347a30`), deployed to data/
  with an MD5 match. `AED8DFF1` is backed up in
  `Modding Files/Backup/guilds_pre_research_points_20261004/`. Mutation run: 198 of 198 caught,
  no stale anchors.

## Build `2783BB4B` (2026-10-04, deployed to data/, MD5 match; `577B5FEB` backed up in `Modding Files/Backup/guilds_pre_built_numbers_20261004/`)

**Every building's guild line gives the number.** "Completing this earns reputation with the
X" now reads "Completing this earns %n Reputation and %n Favour with the X". The `%n` is
the `derpy_gg_built_*` junction value, which is `built_rep(level)` = 10 x the DB `level`
clamped to 1..10: `GG.on_building`'s own formula, since `building_level()` returns that column.
Halls print 10, 10 and 20. The CHD buildings print 10 to 50. **Wrong in that build:** the text
carried two `%n`, and in game the engine filled only the first ("earns 10 Reputation and %n
Favour"); reading Greasus' two-`%+n` effect as proof was an inference. The next build has one
`%n` ("...earns %n Reputation with the X, and the same in Favour"), and `check_built_effects`
now fails any effect text with two placeholders. That build is `42AB22B7` (md5
`42ab22b7affe9a56e6cfbfc7946afc4d`), built and verified in `Modding Files/Modpacks/`, and
superseded before it was deployed by the build below.

## Build `3A48AE51` (2026-10-04, deployed to data/, MD5 match; `2783BB4B` backed up in `Modding Files/Backup/guilds_pre_dwarf_words_20261004/`)

It carries the one-`%n` text above, plus **Dwarf words in `GG.BUILDING_THEME`**. The theme was
tuned on Chaos Dwarf chains, and 50% of Dwarf building reputation went to the Miners' Guild (the
Overseers slot), 62% of it through the no-match default. The Rangers and the Grudge-Settlers
earned nothing from buildings. New tokens:
- slavers (Grudge-Settlers): `slayer`, `grudge`, `oaths`. NOT `oath`, which is inside every
  race's Galbaraz `oathgold` and would have moved gold landmarks off brass.
- khanate (Rangers): `ranger`.
- brass (Merchant Clans): `tavern`, `brewery`, `drinking`, `beer`, `counting`.
- daemonsmiths (Engineers): `engines`.

The changed chains were listed against every vanilla chain before the edit, 22 of them in all.
Side effects across races: the Empire and Bretonnian taverns now pay brass (they paid the
default); `wh2_main_special_smithys_tavern` moves from daemonsmiths to brass; the minor cult
`dwarf_rangers` now pays khanate; Underdeep `defence_slayers` stays with immortals (`defence`
is the longer token). Dwarf shares after the change: Miners 41%, Merchant Clans 40%, Engineers
7%, Hammerers 5%, Grudge-Settlers 3%, Rangers 1%. The ceiling is vanilla's roster: Dwarfs have
few ranger or grudge buildings. Settlements stay with the Miners, by the author's choice. `check_built_effects` also fails a row whose value is not
`built_rep` (1726 findings when broken by one) and fails if the Lua's rate or clamp moves.
The figure is the default: the `rate_overseers` MCT slider and the per-turn guild cap change
what is actually paid, and the text does not follow either. Not yet seen in game: that `%n`
draws as a whole number.
