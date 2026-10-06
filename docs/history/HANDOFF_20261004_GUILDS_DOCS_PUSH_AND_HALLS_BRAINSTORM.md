# Great Guilds: stale docs pushed, open-items audit, guild halls brainstorm - 2026-10-04

Three asks in one session: compare the Great Guilds with Medieval 2's guilds, then "update stale
docs and push to github", then "what else is missing", then "plan for dedicated buildings for each
race". The first three are done. The fourth is **mid-brainstorm**: the questions are answered and
approach A is chosen. Next come the design sections, then the spec, then the plan. **No building
code, DB row or Lua has been written for it.**

## 1. Built and pushed

- **GitHub `DerpyNewb/derpy-great-guilds` commit `e0dbdbc`**, pushed to `main`. It carries the
  27 files that today's two UI sessions had synced but never committed (builds `2EDAC23F`,
  `7A568114` and `BB204325`), plus the doc updates below. No art: the staged-file scan for
  png/dds/jpg/pack was empty.
- **`README.md`** (repo-only file):
  - "Eighteen services, three per guild" became the pools: one card each at Indebted, Sworn and
    Favoured, drawn from a pool of three, rotating every 10 turns (5-30 in MCT), plus race
    services, 83 in all.
  - The AI bullet lost "buy all 18 services" and gained rival bounties.
  - The mutation line went from "12 ways" to "174 ways".
- **`docs/DEVELOPMENT.md`** (repo-only):
  - New section-2 paragraphs on rival bounties, services and cards, and race differences
    (`GG.EARN_ROUTES`, `GG.EARN_OF`, `GG.TWISTS`).
  - Save-key rows for `derpy_gg_cards_`, `derpy_gg_gain_` and `derpy_gg_carry_<f>_<route>`; the
    cooldown row is now per `GG.SERVICES` position.
  - Feed indexes 5005 (a rival's bounty on your land) and 5006 (the services changed).
  - The DB table rewritten to build `BB204325`: ten tables plus the loc.
  - Panel bullets for the pulse, the two-cell header, the padlock and `ca_vslider`.
  - The pipeline rows for 174 mutants and the GG_DUMP preview.
  - The two 09-29 designs added to section 8.
- **`CHANGELOG.md`**: a `BB204325` entry that folds in `2EDAC23F` and `7A568114`.
- **`tools/sync_guilds_repo.py` MANIFEST**: the two 2026-10-04 Guilds handoffs added. The
  selftest passes and `--check` shows 0 drift.
- **Workspace**:
  - `docs/MY_MODS.md`: the Guilds row now names build `BB204325`, 33.1 MB, and **ten** DB
    tables. "twelve" was wrong.
  - `docs/SESSION_INDEX.md`: the two 10-04 Guilds lines now say pushed as `e0dbdbc`.

## 2. Verified, and how

- **Live pack**: data/ and `Modpacks/` both MD5 `bb2043255dc561fd6d82e247dca04cca`,
  34,736,634 bytes.
- **Row counts**: TSV line counts minus the two header lines in
  `Modding Files/source/great_guilds/`:

  | Table | Rows |
  |---|---|
  | `effect_bundles` | 690 (rank 216, lead 54, svc 419, patron 1) |
  | `effect_bundles_to_effects_junctions` | 756 |
  | `effects` | 49 (48 card lines + `derpy_gg_effect_missile_strength_ksl_war_machines`) |
  | `effect_bonus_value_ids_unit_sets` | 2 (CA's `ksl_war_sleds_little_grom`) |
  | `building_effects_junction` | 1,726 |
  | `missions` | 171 |
  | `event_feed_message_events` and each campaign_group table | 54 (6 indexes x 9 offsets) |

- **The pack's file list**, from `read_pack_index.py`: 10 `db/` tables, 5 campaign scripts
  (four guilds + the hub), the MCT file and 22 `.twui.xml` (20 `derpy_gg_*` + 2 hub).
- **Code facts**:
  - `GG.SERVICES` has 83 rows by regex: 26 at rank 2, 31 at rank 3, 26 at rank 4.
  - `GG.CARD_RANKS` are 2-4.
  - `mutate_guilds.py --selftest` reports "174 mutants anchored".

## 3. Corrections found the hard way

- **`7A568114` had no handoff.** It sits between `2EDAC23F` (backup
  `Modding Files/Backup/guild_building_theme_20261004/`) and `BB204325` (pre-pulse backup
  `guilds_pre_glow_pulse_20261004/`). A per-file MD5 diff of the three packs showed it
  changed `zzz_derpy_guilds.lua` and `_bounty_data.lua`:
  - `GG.BUILDING_THEME` gained `hobgoblin` for the Khanate and `military_kdaai` for the
    Daemonsmiths.
  - The K'daai level-3 building moved from the Immortals' bounty list to the Daemonsmiths'.

  Its 10 DB tables also differ, as does `BB204325`'s. That is the re-save of the building-card
  lines, not separately checked.
- **`read_pack_index.read(fp, substring)` returns `(path, compression, bytes)` tuples.**
  Use `read(pack, "")` to hash every file; calling it per path with the path as `substring`
  breaks.
- **Two items in older handoffs are CLOSED.** Do not list them as open again:
  - The `GREAT GUILDS:` debug print. `GGUI.info` is gated by MCT logging, and `GGUI.say` only
    reports faults.
  - The upkeep/rivalry ratchet. `GG` floors rivalry loss at one turn's upkeep ABOVE the rank
    threshold, around line 183.
- **The README's Status line** ("tested live in Chaos Dwarf and Empire campaigns") predates
  everything after 09-27. Nothing from the 10-04 builds is seen in game.

## 4. The open-items audit (answered to the user, not written elsewhere)

- **Never played**:
  - the ten bounty checks in `HANDOFF_20260927_GUILDS_BOUNTIES_V2.md` (captives per race,
    `HAVE_AT_LEAST_X_MONEY` meaning, `character:rank()`, `agent_action_key()`, the scripted
    hero objective, `cancel_custom_mission` raising MissionCancelled);
  - multiplayer on two machines;
  - all 09-30 and 10-04 UI.
- **Release**: no Workshop entry.
- **Small**:
  - the Cathay tab glyph against its octagon;
  - the Log tab's see-through box, the user's question unanswered since 09-30;
  - the Log pages where the Exchange's logs scroll;
  - no burst on buy;
  - the prologue's rank-41 limit (accepted).
- **Designed out**: 8 races only, by the lore rule; the AI never buys Hobgoblin Eyes, Bound
  Blueprint or Raise the Ziggurat; no physical guild presence. That last one is what the halls
  brainstorm is for.

## 5. Guild halls brainstorm - decisions so far

Path: **architectural** (brainstorming skill), so the order is questions, approaches, design
sections, spec in `docs/superpowers/specs/`, writing-plans. Answers, all from the user via
AskUserQuestion:

| Question | Answer |
|---|---|
| Role | **Guild hall tied to rank**: one hall chain per guild; your rank with that guild unlocks each level |
| Placement | **One guild per settlement**, in an ordinary building slot; picking one locks out the other five there |
| Tiers | **3 levels, Medieval 2 scarcity**: Guild House at Indebted, any settlement; Master Guild at Favoured, ONE per guild per faction; Headquarters at Exalted, only for the faction that LEADS the guild, one per race |
| Benefits | **All four**: reputation each turn (through the existing `GG.grant`), a local themed bonus, cheaper services per hall owned, recruitable units |
| Rank loss | **Halls stay, HQ goes quiet**: losing rank only blocks new or upgraded halls; the HQ's extra power is a script bundle live only while you lead |
| Units | **Existing units, guild-trained**: `building_units_allowed` plus an XP effect; no new unit keys, no art |
| Approach | **A**: everything in `derpy_great_guilds.pack`, generated by `gen_great_guilds.py` from one `HALLS` table; **Chaos Dwarfs end to end first**, live-checked, then the other seven races as data |

My assumption, stated to the user and not contradicted: **AI factions build halls**, so every
hall level needs a `cai_construction_system_building_values` row (memory
`wh3-ai-construction-needs-building-values-row`).

## 6. Do not re-derive (measured this session from CA's db.pack via `read_vanilla_db.py`)

- **One guild per settlement is free in DB: chains that share a SUPERCHAIN are mutually
  exclusive in a settlement.** Cathay's `wh3_cp1_cth_defence_yin_tigers` and `_yang_tigers`
  both sit in superchain `wh3_main_cth_walls_major`, and the Changeling's symbiotic and
  parasitic chains share `wh3_dlc24_sch_tze_the_changeling_growth`. 159 of 743 vanilla
  superchains hold more than one chain. Plan: six guild chains per race in one superchain.
- **Cross-chain upgrade edges exist.** `building_upgrades_junction` has 3,554 rows, 144
  levels with 2+ upgrades, and 35 that branch into a different chain (yin to yang). Not needed
  for the plan; recorded because it is how a switch between guilds could later work.
- **`building_levels` columns that matter**: `faction_unique` (the Master Guild's one per
  faction), `only_in_capital`, `first_in_world_bundle`,
  `primary_slot_building_building_level_requirement`, `create_cost`, `upkeep_cost`. 98
  chain-levels in vanilla carry alternatives at the same level number.
- **Rank gates**: `cm:add_event_restricted_building_record_for_faction(building_level_key,
  faction_key, [tooltip_loc_key])` is "saved into the campaign save file ... re-established
  when the campaign is reloaded". The tooltip key comes from `campaign_localised_strings`.
  Removed by `cm:remove_event_restricted_building_record_for_faction`. There is also a
  per-region chain lock, `add_event_restricted_building_chain_record_for_region`.
- **No downgrade call exists.** `cm:region_slot_instantly_upgrade_building(slot, key)` needs
  "a valid upgrade". Downgrading would be `region_slot_instantly_dismantle_building` plus
  `add_building_to_settlement`, never tested. The user's rank-loss answer avoids it.
- **A WH3 building set is 12 tables plus loc** (`Modding Files/templates/README.md`, "building/").
  Omitting any of the four placement tables (`building_chain_set_items`,
  `building_set_to_building_junctions`, `building_chain_availability_sets`, and
  `building_instances`, which sets how many per settlement) makes the chain never appear, silently. A chain is filed under ONE building set,
  so each race needs its own chains (memory `wh3-building-chain-one-set`).
- **`GG.BUILDING_THEME`** already pays a guild when any building completes, by longest token
  match on the chain key. A hall chain must be matched to its own guild, and
  `gen_great_guilds.py`'s card-line check will demand a `derpy_gg_built_<guild>` line on it.

## 7. Open, in order

**Update, same session:** all six design sections were approved, the seven other races' units
were picked (spec §8.2), and the spec is written:
`docs/superpowers/specs/2026-10-04-great-guilds-halls-design.md`. Next: the author's review of
the spec, then writing-plans. Items 1-3 below are folded into it.

1. **Present the design sections** to the user, getting approval after each:
   - the DB shape (superchain, chains, levels, placement sets per race, `faction_unique`);
   - the script rules (lock sweep at turn start and on rank change, the HQ leader gate,
     the hall reputation tick, the discount in `GG.service_cost`, the HQ bundle);
   - numbers;
   - the AI (`building_values`);
   - UI (building cards, the Guilds tab showing halls owned, the lock tooltips);
   - MCT (a `guild_halls` switch that locks every level when off);
   - testing (harness blocks, mutants, generator checks);
   - Chaos Dwarf content: which slot set, the six local bonuses, the six units with their
     rosters checked against `building_units_allowed`, and icons from CA's CHD building icons,
     never published.
2. Write the spec to `docs/superpowers/specs/2026-10-04-great-guilds-halls-design.md` and
   self-review it. Then the user reviews it, then writing-plans.
3. **Questions not yet asked**:
   - Can a hall be built in a minor settlement? (The answer "one guild per settlement, any
     settlement" implies yes.)
   - The hall's cost and build time against a vanilla tier-2 building.
   - Does the HQ need the capital?
   - What the six Chaos Dwarf local bonuses are.
   - How much discount each hall gives, and whether it is capped.
4. Unchanged from section 4: the ten bounty checks and the Workshop release.
