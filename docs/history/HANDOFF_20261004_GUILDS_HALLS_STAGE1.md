# Great Guilds: guild halls, stage 1 (Chaos Dwarfs), built, packed and deployed

**Superseded: the stage-2 build `9A81A01B` (md5 `9a81a01b6f33eb9bb486f1344d1d74c1`) is now live; see `HANDOFF_20261004_GUILDS_HALLS_STAGE2.md`.**

2026-10-04. **Build at the time of stage 1: `FBCC9948` (md5 `fbcc994896fd8810c6f1af89165ace25`)**, the final
fix wave (see "Final review" below), deployed to data/; the build it replaced, `D1CC4207` (md5
`d1cc42071f0316d7d73ab29145079b50`), is in `Modding Files/Backup/guilds_pre_final_fix_20261004/`.
The pre-halls live `bb2043255dc561fd6d82e247dca04cca` is in
`Modding Files/Backup/guilds_pre_halls_20261004/`. **Not yet seen in game.** The eight in-game
checks below are all OPEN. No Workshop copy of this pack exists (searched
`workshop/content/1142710` for `*great_guilds*`, nothing), so nothing went to a Workshop folder.

## Built

Plan `superpowers/plans/2026-10-04-great-guilds-halls-stage1.md`, tasks 1-7.

- **Six chains in one superchain**, three levels each, Chaos Dwarfs only (empty culture tag):
  superchain `derpy_gg_hall`, chain `derpy_gg_hall_<guild>`, level `derpy_gg_hall_<guild>_<n>`
  (n = 0, 1, 2), Seat bundle `derpy_gg_seat_<guild>`. Cloned from CA's K'daai chain.
- **Eleven new tables** (counts in the pack): superchains 1, chains 6, levels 18, upgrades
  junction 12, culture variants 18, chain set items 12, set-to-building junctions 6,
  availability sets 6, instances 7, units allowed 16, AI construction values 6. Plus 1762
  `building_effects_junction` rows in all (hall rows are the `derpy_gg_hall_*` ones), 696 bundles,
  762 bundle junctions, 6574 loc keys.
- **Lua** (`zzz_derpy_guilds.lua` HALLS block): per-faction locks through CA's restriction calls, a
  turn-start count through `region:building_exists`, Reputation through `GG.capped_grant`, a
  `hall_off` discount in `GG.service_cost` (3% a hall, max 15), and the Seat bundle while a faction
  holds a level-2 hall and leads the guild. MCT `guild_halls` (default on), `hall_rep` (100),
  `hall_off`.
- **Panel**: header "Halls n" and Help page 7, both gated on `guild_halls` being on.
- **Packing** (`tools/import_great_guilds.py`, this task):
  - the eleven tables are now in `DB_DEST` (the plan said the loop already followed
    `G.TSV_META`; it follows it for the version only, and the destination list is hand-written,
    so `--check` refused until they were added);
  - it packs exactly `ui/buildings/icons/derpy_gg_hall_*.png` (six files) and never the shared
    folder; `_check_hall_icons()` refuses if an icon stem a hall variant row names is not staged.

## Verified, and how

- `import_great_guilds.py --check`: verify ok, every TSV matches `build()` byte for byte, all 11
  new tables have a destination.
- Duplicate keys, checked before saving: no duplicate within the pack and no clash with
  `db.pack` for superchain, chain, level, instance, units-allowed key, variant building, bundle,
  or loc keys.
- Import saved the pack and re-opened it in a fresh session: every table's row count and cell
  content matched `build()` ("saved pack verified"). Versions written: chains 10, levels 3,
  variants 5, units allowed 4, bundles 4, bundle junctions 3, the rest 0.
- `read_pack_index.py` on the saved pack: 233 paths, none with an uppercase letter; the six hall
  icons, the four campaign scripts (plus the hub script) and the MCT settings file are present.
- `check_effect_bundle_loc.py`: 696 bundles, 0 findings. The six `derpy_gg_seat_<guild>` bundles
  each have title and description loc.
- `check_effect_signs.py`: exit 0, 54 penalty rows, none a hall or Seat row. The Seat bundles for
  Khanate (`agent_recruitment_cost_mod`) and Overseers (`building_construction_cost_mod_all_settlement`)
  carry -5 on cost effects, which are discounts. The tool reads bundle junctions only, so the
  hall levels' own effects (`building_effects_junction`) were read by hand: Overseers -5/-10/-15
  construction cost is a discount, every other hall effect is positive.
- Gates: `gen_great_guilds --check` and `--selftest` (6 guilds, 83 services, 77 bundles, 72 loc),
  `_guilds_harness.lua` ok, `_guilds_bounty_harness.lua` ok, `check_guilds_ui` 0 problems,
  `gen_guilds_ui --check` exit 0, `check_lua_literal_left` 0 sites, `mutate_guilds` 184 caught
  (task 6; no Lua changed since).
- Deployed after `Warhammer3.exe` was confirmed shut; MD5 of the Modpacks copy equals data/.

## Corrections to the plan and spec

- `building_levels.building_instance_key` is `"derpy_gg_hall"`, the shared capped key, not `""`
  (task 1). With `""` no cap applies. Spec 3.1 corrected.
- `building_units_allowed.conditions` is int 0, not `""` (task 2).
- `GG.first_halls` iterates covered factions the way `GG.load_all` does (scan_world plus human
  factions), plus a once-per-session sweep in `gg_turn` when `GG.halls_locked[name]` is nil. The
  plan iterated `GG.state`, which is empty in a fresh campaign, so nothing was locked (task 3).
- `zzz_derpy_guilds_ui.lua` was edited in task 5: `GGUI.earned_tip` rebuilt the cap from settings
  and showed 40 while a seated leader was paid to 60; it now uses `GG.guild_cap`.
- Task 6 re-aimed one stale mutant to the shipped code and fixed `TUNE_ORDER` (it lacked
  `guild_halls`, `hall_rep`, `hall_off`).
- `Modding Files/templates/README.md` now says `building_levels` is v3 / 27 fields (the
  controller fixed it from the shipped TSV header), with the shared `building_instance_key` cap rule.
- The importer's `DB_DEST` is hand-written (above).

## Final review

A whole-branch review found ten items (2 Important, 8 Minor). Rulings and what was done:

- **F1 (Important), uncovered Chaos Dwarf AIs were unlocked** in another race's campaign. New
  `GG.hall_culture(faction)` (a hall race, covered or not) gates `GG.lock_halls`, `GG.first_halls`
  and the turn-start sweep; `GG.hall_open` returns false for an uncovered faction, so all 18 levels
  shut. `count_halls`, `pay_halls`, `assert_seat` stay on `GG.halls_here` (covered). Harness block
  plus three mutants.
- **F2 (Important), AI values all cloned K'daai.** Each guild's row is now cloned from a Chaos
  Dwarf donor of its role, picked by rule in `_cai_donor` and printed by `--check`: brass and
  slavers `outpost_scavangers_hovel` (support, 125->2), immortals `military_chaos_dwarf_infantry`
  (2500->2400), daemonsmiths `military_kdaai` (2500->2400), khanate `military_hobgoblins`
  (1250->1050), overseers `outpost_mine` (support, 1000->20). Per-faction limit kept at 3. Finding,
  not fixed: vanilla never pairs a positive limit with a zero discount (0 of 17 rows), so for brass,
  slavers and overseers the limit of 3 is inert; for the three military-group halls, three per guild
  score at the donor's full value where CA's own chain (limit 0) scores one. In-game check 5 watches.
- **F3, Seat bundle** is now the hall's own effect, faction-wide, at a third of level 2 rounded away
  from zero: brass +5 `faction_to_region_own`, immortals +5 `faction_to_force_own`, daemonsmiths
  +2 `faction_to_faction_own`, khanate +1 `faction_to_province_own`, overseers -5
  `faction_to_region_own`, slavers +10 `faction_to_faction_own`. Each pair is one vanilla uses in a
  bundle. Khanate's hall effect is agent recruitment XP, so its Seat is positive. Help page 7 and
  the bundle description say so. The old deferred minor "Seat bundles use RANK_EFFECTS only" is moot.
- **F4, wording**: "their" leader / Seat, "Holds the Seat", Brass and Overseers "in this province".
- **F5, no fixed numbers**: hall descriptions and Help say "a bigger hall pays more". The promotion's
  hall line is its own key `..._primary_hall`, picked only while `guild_halls` is on.
- **F6, price hover** reads "Includes halls: -N%", N the cut applied after the -30 floor
  (`GG.service_cost`'s third return); no line when it is 0.
- **F7**: hall bonus `value_damaged` is half, rounded toward zero; `value_ruined` 0. The card line
  (`derpy_gg_built_*`) keeps 1 when damaged, as on every other building the pack marks.
- **F8**: no change (`faction_unique` per level matches the spec; check 3 observes it).
- **F9**: the once-a-session sweep keys on `GG.halls_swept[name]`, not `halls_locked`.
- **F10**: this section, the criteria above, the README line, MCT `guild_halls` tooltip now "for the
  races that have them".
- Gates: gen `--check`/`--selftest`, both harnesses, `mutate_guilds` 190/190 caught, `check_guilds_ui`,
  `gen_guilds_ui --check`, preview `--check` and Help page 7 render, literal-left 0, undeclared 0,
  `luac -p`. `check_effect_signs` 54 penalty rows, none hall or Seat; `check_effect_bundle_loc` 0.

## Do-not-re-derive facts

- `building_instance_key` "derpy_gg_hall" IS the one-guild-per-settlement cap. Cathay's yin/yang
  tiger levels share `wh3_main_cth_defence` the same way; 119 vanilla empty-key levels are uncapped.
- `building_units_allowed.conditions` is int 0; `key` = 1e9 + crc32 % 1e9, collision-checked
  against vanilla.
- Rank indices: Unmarked 1, Indebted 2, Sworn 3, Favoured 4, Exalted 5. Level 0 needs 2, level 1
  needs 4, level 2 needs 5 plus the guild lead.
- Cost / turns 1500/3, 3000/5, 6000/8; settlement level 2/3/4; `faction_unique` false/true/true;
  Reputation per turn 4/8/15; unit XP 0/1/2.
- Names, descriptions, lock tooltips and chain tooltips are loc-only, with no DB table.
- A save from before halls has no `guild_halls` in `derpy_gg_tuned` and no lock records: the first
  tick sweeps every level once.
- Locks stop construction only. A hall that arrives anyway still counts and pays.
- `guild_halls` off: every level locked, no Reputation, no discount, no Seat, buildings stand.
- The six hall icons ship from `ui/buildings/icons/`, a folder other mods share. Match the prefix.

## OPEN

**The eight in-game checks, with pass criteria** (from the final review, `final-review-criteria.md`). All OPEN.

Run these in a Chaos Dwarf campaign, on the Default preset.

1. **One hall per settlement.**
   - **Setup:** a settlement with a Lodge of guild A, both completed and under construction.
   - **Pass:** no other guild's hall can be queued in another slot of that settlement.
   - **Fail:** two `derpy_gg_hall_*` buildings in one settlement. If this fails, STOP: the
     fallback is the per-region chain lock in spec §10, which needs a spec amendment before any
     code.

2. **Locks.**
   - **At Unmarked:** all six chains show CA's restricted icon, with a red tooltip like "Needs
     Indebted with the X." Never a bare key.
   - **At Indebted:** the Lodge is buildable, and the Hall says "Needs Favoured...".
   - **At Exalted without the lead:** the Ziggurat says it needs Exalted and that only their
     leader may raise it.
   - **After a reload:** save, quit to the menu and reload. The same levels are locked, with the
     same text.
   - **Fail:** any lock lifted, or any text changed, after the reload.

3. **One Hall per guild.**
   - **Pass:** with a Hall of X standing or queued, no second Hall of X can be queued or
     upgraded to.
   - **Also note** whether, after upgrading that Hall to a Ziggurat, a second Hall of X becomes
     buildable. The DB says yes, because `faction_unique` is per level.

4. **Does a hall under construction count?**
   - **Setup:** on turn N, queue a Lodge of X.
   - **Read:** through the bridge, read `GG.count_halls(<you>)` then `GG.halls[<you>].X.n`.
     Read again at the start of turn N+1, with the Lodge still building.
   - **Pass:** the count and the "Reputation this turn" tooltip agree.
     - If n is 1, the tooltip shows a Halls line on turn N+1.
     - If n is 0, no Halls line appears until the turn after the Lodge completes.
   - **Write down which it was:** this decides whether a hall pays from the turn it is ordered.
   - **Fail:** counted but unpaid, or paid but not counted.

5. **AI building.**
   - **Setup:** after about 20 turns, print each Chaos Dwarf AI's `GG.halls[f]` and its rank in
     each guild, through the bridge.
   - **Pass:** at least one AI that is Indebted or higher with some guild owns a hall of that
     guild. No AI owns a level it is locked out of, unless it got it by confederation or
     capture.
   - **Fail:** zero halls among the AIs that are Indebted or higher.
   - **Also flag:** any AI with halls in most of its secondary slots, since the AI building
     values are inferred and not yet watched.
   - **Not your race:** in a campaign where you play another race, Chaos Dwarf AIs own no halls
     at all.

6. **Local effect.**
   - **Brass Tablets Lodge** (`wh_main_effect_economy_gdp_mod_all`, `province_to_region_own`):
     "Income from all buildings: +5%" appears on EVERY region you own in that province, not only
     the hall's own region. The building card shows its "pays the Brass Tablets" line.
   - **Optional, Overseers Lodge:** "Construction cost: -5% for all buildings" on the same
     regions.
   - **Damaged:** if the hall is damaged, the bonus halves.
   - **Fail:** the bonus is missing, has the wrong value, or shows only in the hall's own
     region.

7. **Units.**
   - **Brass Tablets Lodge:** Hobgoblin Wolf Raiders (Bows) appear in that settlement's
     recruitment list, at rank 0.
   - **Immortals Hall (level 1):** recruits Infernal Guard with 1 chevron.
   - **Immortals Lodge:** trains nothing, by design.
   - **Fail:** the unit is absent, or arrives at the wrong rank.

8. **Names, descriptions and icons.**
   - **Cards:** all 18 show "Lodge, Hall or Ziggurat of the X", that level's own description,
     and that guild's hall icon. No `wh_main_PLACEHOLDER`, no raw `derpy_gg_hall_*` key, no
     blank icon.
   - **Seat:** when you lead a guild and own its Ziggurat, the faction effects list shows "Seat
     of the X", with its icon, title and description. Its effect is the hall's own bonus at
     about a third of the Ziggurat's value.

**Spec 10.8 does not apply here.** Spec §10.8 (a DLC unit hidden from a player who does not own it) does not apply to the Chaos
Dwarfs, whose hall units are all base content. It moves to stage 2.

**Deferred minors** (from the task ledger):

- Task 1: six per-chain `building_instances` rows are dead (no level names them); harmless.
- Task 1: the lowercase selftest covers key, level_name and building only, not chain, from, to, id
  or building_chain.
- Task 1: `additional_loot_value` is a flat 2000 on all three levels (the donor ramps 2000/4000/8000).
- ~~Task 2: Seat bundles use the base `RANK_EFFECTS` only.~~ Moot: final review F3 moved the Seat
  to the hall's own effect.
- Task 4: GGAI prices every AI faction at the round's first FactionTurnStart, so an AI's hall
  discount reads last round's count (one-turn lag; Reputation is always current).
- Task 4: `hall_rep` is not clamped; a negative value pays nothing (safe).
- Task 5: the task 5 harness block leaves `GG.halls[F].brass/daemonsmiths` set; a later block must
  reset them.
- Task 6: Help page 7 was rendered and read in the preview, but never in game.
- `check_lua_api.py` exits 1 on `ai_test_tower_of_zharr.lua:35` (`cm:ritual_is_locked`). Unrelated
  to the guilds; no halls file is flagged.
- Final re-review: in `service_cost`, the Dark Elf `hostile_price` twist rescales `mod` but not
  `hall_cut`, so on a hostile card "Includes halls: -N%" shows the pre-twist figure. The price is
  right; only the line is slightly off. Dark Elves have no halls until stage 2, so fix it there.
- Final re-review: when halls alone cancel a rival surcharge (`cost_mod` 0), the hover shows
  "Includes halls" with no total line above it. Cosmetic.
- AI scores (F2): the limit of 3 does nothing where the donor's per-faction discount is 0, and
  Immortals and Daemonsmiths halls score 2500 for three builds each, level with CA's top Chaos
  Dwarf resource chains. Inferred from the columns, not watched; check 5 measures it.

## Stage 2

The other seven races as data. It is planned from this handoff's in-game results, not before.
