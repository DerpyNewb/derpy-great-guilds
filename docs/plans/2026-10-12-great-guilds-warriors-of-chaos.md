# The Great Guilds: Warriors of Chaos ("The Dark Gods") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Warriors of Chaos (`_chs`, `wh_main_chs_chaos`) as a tenth race, with full parity, in one build. Their seven "guilds" are seven Chaos gods, and their Reputation is called Devotion.

**Architecture:** The Skaven recipe. Every place a race is declared gains a hand-written `_chs` entry: the Lua model, the panel Lua, the Python generator, the UI generator, the art tools and the test pins. Five code paths are new or widened:
- per-race rival pairs (`GG.RIVALS_RACE`, `GG.rival_of`);
- the Gifts route, whose pool names its god, with one remainder per god;
- the temple's `taint` naming its corruption resource (Skaven and Undivided);
- Necoho's rule: the Doubter never makes a demand;
- a per-race word pass in the generator (Reputation becomes Devotion, guild becomes god).

The generator writes the DB tables, the loc and the generated Lua blocks; the importer packs everything through RPFM.

**Tech Stack:** Lua 5.1 (game scripts), Python 3 (generators and checks), RPFM MCP (packing), TWUI Studio (headless previews).

**Spec:** `docs/superpowers/specs/2026-10-12-great-guilds-warriors-of-chaos-design.md`

## Global Constraints

- **The workspace is not a git repository.** There are no commit steps. Before Task 1, snapshot every file this plan touches into `$S/base_chs/` (list in Task 12 Step 1). A task's checkpoint is its check or harness going green. Back up packs to `Modding Files/Backup/`, never into `data/` or a Workshop folder.
- **Tag and culture:** `_chs` and `wh_main_chs_chaos`. NOT `wh3_main_chs_chaos`, which does not exist.
- **`_chs` goes before `_gen`** in `FLAVOURS`, with feed offset 100. `_gen` stays last.
- **The Warriors of Chaos race-service rows are appended AFTER the Skaven's three** (`breeding_season` is last today), in both `GG.SERVICES` and the generator's `SERVICES`. Cooldowns are saved by position.
- **No new `GG.TUNE_ORDER` key.** The Undivided's corruption reuses `rate_temple_taint`; the Gifts route has no rate.
- **The other nine races must not change.** Every rivalry, text, bundle and row they ship today ships byte for byte after this plan. Task 7 Step 9 proves it by diffing the generated TSVs of the nine against the snapshot.
- **Line endings.** Check each file with `file <path>` before the first edit.
  - LF: `gen_great_guilds.py`, `make_guild_icons.py`, `make_guild_backgrounds.py`, `make_guild_bundle_icons.py`, `mutate_guilds.py`, `check_guilds_ui.py`, `_guilds_bounty_harness.lua`, `zzz_derpy_guilds.lua`.
  - CRLF: `gen_guilds_ui.py`, `import_great_guilds.py`, `preview_guilds_panel.py`, `_guilds_harness.lua`, `zzz_derpy_guilds_ui.lua`, `zzz_derpy_guilds_ai.lua`, `script/mct/settings/derpy_great_guilds.lua`.
  - Edit CRLF files with the Edit tool or byte-level Python that keeps `\r\n`. Never `sed -i`. Never put a backslash or regex in a heredoc; write patch scripts with the Write tool.
- **Pins.** Every pinned total moves to the new counted total. A test is never loosened.
- **Player text.** Devotion and Favour for this race, plain words, no jargon, no "rung", no emojis. God names at most 22 characters and starting "The ", rank names at most 12.
- **Lua runs float32 in game.** Integer multiply then divide. In a function with over 255 constants, no number literal on the LEFT of an arithmetic operator (`py tools/check_lua_literal_left.py`).
- **Keys fail silently.** Every key in this plan was read from the installed `db.pack` or CA's 9.0 scripts on 2026-10-12 (Rulings). A key not listed there is checked the same way before use.
- **`tools/*.py` have no `--help`.** `import_great_guilds.py` BUILDS the pack on any unknown flag.
- **The mutation runner edits the shipped Lua in place.** Never build or deploy while it runs. Touch every generated file after it (memory: mutation runs leave generated files mutated).
- **The Great Guilds is Workshop-hosted** (item 3815248936). The deploy target is `F:\SteamLibrary\steamapps\workshop\content\1142710\3815248936\derpy_great_guilds.pack`, never `data/`. Diff before copying; a stale Modpacks copy can delete files.
- **Commands,** run from `G:\Modding for resources` in Git Bash:
  - `S` = the session's scratchpad directory
  - `M` = `"Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"`; `U` = the same folder's `zzz_derpy_guilds_ui.lua`
  - `H` = `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua`, which prints `harness ok` last
  - `BH` = `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua`, which prints `bounty harness ok`
  - `GEN` = `PYTHONIOENCODING=utf-8 py tools/gen_great_guilds.py` (`--selftest`, `--check`, `--write`). About 2 minutes; redirect to a file.
  - `UIGEN` = `PYTHONIOENCODING=utf-8 py tools/gen_guilds_ui.py` (`--selftest`, `--check`, `--write`)
  - `LUAC` = `"/c/Program Files (x86)/Lua/5.1/luac.exe" -p <file>`
  - `GG1(fn)` = `PYTHONIOENCODING=utf-8 py -c "import importlib.util as u; s=u.spec_from_file_location('g','tools/gen_great_guilds.py'); g=u.module_from_spec(s); s.loader.exec_module(g); r=g.<fn>(); print('\n'.join(r) or 'clean')"`, to run one generator check alone.

## Rulings (plan-time facts, 2026-10-12)

Read from the installed `db.pack`, CA's 9.0 scripts and docs, and CA's ui packs. Rulings 3, 4, 9 and 15, and Task 3's one Souls remainder per god (spec §3.2 had one per route, which would let Souls spent on Khorne finish a Devotion for Nurgle), change the spec; the handoff records each.

1. **Culture `wh_main_chs_chaos`** (`cultures`; CA's `wh3_dlc20_campaign_chs_dark_authority.lua`). Feed indexes 5101-5106 are free: vanilla's `campaign_group_member_criteria_values` tops out at 1978.
2. **Building sets.** The link is `building_chain_availabilities`, not `factions`.
   - `wh_main_bas_chs` (54 chains) is the culture's set and covers every Warriors of Chaos faction: Archaon `wh_main_chs_chaos`, `wh3_dlc20_chs_kholek`, `_sigvald`, `_festus`, `_valkia`, `_vilitch`, `_azazel`, Be'lakor's `wh3_main_chs_shadow_legion`, and the minors.
   - `wh3_dlc29_woc_glottkin` (67) is the Glottkin's faction set (`wh3_dlc29_chs_host_of_the_triplets`): it adds the 14 `nurgle_garden` chains and the Oak landmark. It becomes `extra_sets`, the way Thanquol's set is for the Skaven.
   - `covered_chains` refuses 8 chains of the two sets, all already shared by 8 or more races (`ogham_stones`, `galleons_graveyard_other`, and so on). No chain moves away from another race.
3. **The halls train no unit (changes spec §7).** No Warriors of Chaos building trains any unit: the race recruits from unit pools whose size its buildings set, and gets Chosen by UPGRADE (`unit_upgrade_to_unit_groups`: `wh3_dlc20_chs_warriors_<god>_to_chosen` at rank 7, `wh3_dlc20_chs_chosen_und_to_<god>` to mark). `_unit_level` raises for every Chosen. So all seven `units` are `None`, and each hall's second effect is the race's own idiom, through `HALL_EXTRA`:
   - the Four: that god's Marauder pool, `wh3_dlc20_effect_province_merc_capacity_marauders_{kho,nur,sla,tze}` at `province_to_province_own_unseen`. CA's Dark Fortress marauder chain uses this pair at 1, 1, 2; ours is 1, 2, 3, within the generator's 1.5x rule. No per-god Chosen or Warrior capacity effect is on any vanilla building or bundle.
   - the Undoer: `wh_main_effect_agent_action_success_chance_enemy_building` at `region_to_character_enemy`, -10/-15/-20, CA's own Warriors of Chaos Towers values. `is_positive_value_good` is false, so negative is the bonus.
   - the Doubter: none needed. `HALL_EFFECT["brass"]` already raises province income.
   - the Undivided: §6's temple hall (Undivided corruption).
4. **The hire unit is the Chosen of Khorne, `wh3_dlc20_chs_inf_chosen_mkho` (changes spec §2).** `hire_immortals` is the Blood God's own service. The key is in the cached `main_units`; `check_hire_units` passes; `cm:grant_unit_to_character` grants it.
5. **The Souls-spent pools** (`wh3_dlc20_chs_souls_spent_{kho,nur,sla,tze,und}`) are engine-written. Each `resource_cost_pooled_resource_junctions` cost debits Souls and credits the god's pool the same amount; no CA script writes or listens to them. Their factors are `path_to_glory` (marking a lord 3000, a hero 2000, a Daemon Prince 5000/10000), `gifts_of_chaos` (500/750/1500 tiers) and `gifts_of_chaos_upkeep` (50-350 a turn). All three count: `GG.pool_route_counts` returns true for `gifts`.
   - A single marking (3000 Souls, 120 Devotion) is more than a god's turn limit; the excess is withheld like any large earning, and the ledger shows it.
   - `PooledResourceChanged` carries `factor`, `amount`, `faction`, `has_faction`, `resource`, and fires for AI factions (`wh3_cp1_tiger_mercenaries.lua:923`).
   - The Glottkin's Souls `gifts_of_chaos` factor is limited to `wh3_dlc29_all_chs_except_glottkin`, so whether the Glottkin spend into these pools is unconfirmed: an in-game check.
6. **Tithe of Souls:** `wh3_dlc20_chs_souls`, factor `wh3_dlc20_souls_other` (CA's own script call, `wh3_campaign_bonus_values.lua:1037`), 500 (CA's narrative mission payload, `wh3_narrative_chaos_warriors.lua:38`). `missions` is NOT a Souls factor.
7. **The Eye Turns:** `wh3_dlc20_chs_eye_of_the_gods` is a faction pool, max 50, starting at 20, with factor `gifts_of_chaos` (positive). CA's script performs the Eye of the Gods ritual at a human's turn start when it reaches 50 (`wh3_dlc20_campaign_chs_eye_of_the_gods.lua:298-315`). The service is an ordinary `resource` row adding 15 through `gifts_of_chaos`, so no `GG.RACE_FIRE` entry. No CA script adds to this pool: an in-game check.
8. **Priests:** `wh_main_chs_chaos_sorcerer_fire`, `wh_main_chs_chaos_sorcerer_death`, `wh_main_chs_chaos_sorcerer_metal` and `wh_dlc07_chs_chaos_sorcerer_shadow` are `wizard` (heroes) for 19-26 Warriors of Chaos factions. The marked Sorcerers (`_mtze`, `_msla`, `_mnur`) are `wizard` too and pay the Undoer.
9. **Recruiting needs `UnitUpgraded` (changes spec §3.4).** Of 136 units in the race's pools only 5/8/4/3 carry `_m<god>`; marked units mostly arrive by upgrade. A new `gg_recruit_upgrade` listener pays the god of the unit an upgrade produced, for cultures in `GG.UPGRADE_PAYS` only (an upgrade is not a recruit for any other race). Documented accessors: `unit`, `upgrade_group`. Whether `UnitTrained` fires for pool recruits cannot be read offline: an in-game check.
   - Key words: `_mkho` (21 `_chs_` keys), `_mnur` (41), `_msla` (40), `_mtze` (37); god-culture keys the race also fields: `_kho_` (19: wrathmongers, skullcrushers, Valkia's upgrades `wh3_main_kho_cav_gorebeast_chariot` / `wh3_main_kho_cav_skullcrushers_0`), `_nur_` (26), `_sla_` (14), `_tze_` (19); unsuffixed Nurgle: `wh3_dlc29_chs_inf_putrid_blightkings_*`.
   - Characters: `wh3_dlc20_kho_valkia`, `wh3_dlc20_nur_festus`, `wh3_dlc20_sla_azazel`, `wh3_dlc20_tze_vilitch`, `wh_dlc01_chs_prince_sigvald` (Slaanesh), `wh_main_chs_archaon` and `wh_dlc01_chs_kholek_suneater` (Undivided), `wh3_dlc29_chs_glottkin`, `_gutrot_spume`, `_bloab`, `_morbidex`, `_orghotts` (Nurgle), `wh3_dlc20_chs_daemon_prince_{khorne,nurgle,slaanesh,tzeentch,undivided}`, `wh3_dlc20_chs_lord_m{kho,sla}`, `wh3_dlc24_chs_lord_mtze`, `wh3_dlc25_chs_lord_mnur`, `wh_main_chs_lord_of_change`.
10. **Effects** (key at scope, vanilla use):
    - Undivided corruption, hall: `wh3_main_effect_corruption_chaos_buildings` at `region_to_region_own` (213 building rows, 162 at +2).
    - Undivided corruption, Seat: `wh3_main_effect_corruption_chaos_events` at `faction_to_province_own` (bundles, 1-20).
    - Skulls for the Skull Throne: `wh_main_effect_force_stat_melee_attack` at `faction_to_force_own` (max +15) and `wh3_dlc20_effect_xp_gain_all_units` at `faction_to_force_own` (5-50).
    - `wh3_main_effect_winds_of_magic_pool_cap` at `faction_to_force_own` exists (the temple lore's Winds ladder).
11. **Building words.** The spec's `shrine`, `growth`, `income`, `knights`, `monsters`, `towers` and `garrison` each match other races' chains. These tokens match only Warriors of Chaos chains (every chain of both sets checked):
    - Undivided: `fortress_shrine`, `chaos_altar_corruption`
    - Plague Lord: `fortress_growth`, `nurgle_garden` (all 14 garden chains; wins on length over towers, garrison and income)
    - Doubter: `fortress_income`, `woc_resource_`
    - Blood God: `fortress_warriors`, `fortress_knights`, `fortress_marauder`, `chaos_altar_recruit`, `chaos_altar_replenishment`
    - Changer of Ways: `chaos_monsters`, `large_monsters`
    - Dark Prince: `fortress_vassals`, `chs_allied_outpost`
    - Undoer: `fortress_towers`, `woc_chaos_altar_special_gate_towers`, `woc_chaos_altar_garrison`, `foreign_slot_discovery_woc`

    Left to the shared words: `wh3_dlc29_chs_dark_fortress` (Immortals, by "fortress"), the settlements (Overseers), the ports (Brass).
12. **Event pictures:** `ui/eventpics/chs/` holds every picture the feed and bounties name (`civilisation_down`, `civilisation_up`, `messenger`, `diplomacy`, `generic`), so `pics = "chs"`.
13. **The Hellcannon** is class `art_fld`, inside `all_land_artillery`, so `master_gunners` needs no `RACE_UNWANTED_EFFECTS` entry.
14. **The frame** (no Warriors of Chaos panel has a card plate or tab states of its own; three CA panels plus the race's HUD bars, as the Skaven took two):

    | Slot | File (ui2.pack) | Size | Note |
    |---|---|---|---|
    | card | `ui/skins/default/dlc25_tamurkhans_chieftains/text_holder.png` | 395x200 | rusted ground, mean luminance ~30 under text; bronze rim rows ~3-12 and 172-178; spikes to row 190 must stay in the bottom slice. Spare: `path_to_glory/panel_back_frame_stroke.png` 256x256, CA slices 4 |
    | heat | `_GLOW` tinted `#FF8C00` | - | CA's Path to Glory tint (`active_glow_gadient.png` at `#FF8C0032`, slice 50) |
    | rim | `ui/skins/default/path_to_glory/panel_selection_stroke.png` | 256x256 | CA slices 4, tiled |
    | holder | `ui/skins/default/chaos_gifts/ritual_empty_slot_undivided.png` | 100x100 | opaque 11-88 |
    | cost | `ui/skins/default/dlc25_tamurkhans_chieftains/num_holder.png` | 68x28 | |
    | rank | `ui/skins/wh3_dlc20_chs_chaos/bar_small_central_left.png` | 740x58 | plate rows 5-57, ~24px star caps |
    | gbar | `ui/skins/wh3_dlc20_chs_chaos/bar_small_buttons.png` | 467x71 | the Skaven/High Elf bar shape, 85px ends |
    | tab | `ui/skins/default/dlc25_tamurkhans_chieftains/subtitle.png` | 406x46 | rows 2-41, ~40px ends; normal at `_DIM`, hover full, open = subtitle + `panel_selection_stroke` |
    | track / fill | `ui/skins/default/chaos_gifts/souls_bar_frame.png` + `souls_bar_back.png` (272x26, opening x 8-263, y ~10-16) / `souls_bar_fill_undiveded.png` (76x13, already used by `_emp` and `_brt`) | | native height, as `_dwf` |

    Reference panels to screenshot in game: `ui/campaign ui/character_details_panel_path_to_glory.twui.xml` (a Warriors of Chaos lord's Path to Glory tab), `ui/campaign ui/chaos_gifts.twui.xml`, `ui/campaign ui/dlc25_tamurkhan_chieftains.twui.xml`.
15. **Crests and icons (changes spec §8).** CA's mark icons are coloured orbs (2-35% flat) and `build()` refuses them.
    - The Four: `ui/skins/default/tech_watermark_{khorne,nurgle,slaanesh,tzeentch}.png` (ui2.pack, 100% flat, 429-604px wide). `fetch()` reads only `ui/buildings/icons/`, so they are staged by hand, pre-squared at 74px, into `Modding Files/source/guild_icons/`.
    - The Undivided: `chaos_worship` (an eight-pointed star, 100%). The race crest: `chaos_dark_fortress` (97%). The Doubter: `wh3_main_special_standing_stones` (100%, plain stones; "Necoho has no known symbol"). The Undoer: `wh3_dlc27_nor_trap_core_sabotage` (100%, a cracked cog).
    - Hall icons, from `building_culture_variants` for the culture: `chaos_worship` (Undivided), `chaos_growth` (Plague Lord), `chaos_income` (Doubter), `chaos_warriors` (Blood God), `chaos_magic` (Changer), `chaos_vassals` (Dark Prince), `chaos_towers` (Undoer, 98%). Written out explicitly: the stage-2 loop derives a hall icon from the race's card stem, and this race's cards are god symbols, not buildings.
    - `TAB_FRAME`: `chaos_cat_recruitment` (64x64).
16. **Grounds.** All seven paintings are in ui.pack, which `ca_picture` reads. The Four's and the Daemons' are 1920x1080 with no bars and no logo. `campaign_chaos1` is 1920x1200 with black bars (top 96, bottom 64 rows) and a painted frame about 200px wide; the painting inside runs x 200-1720, y 190-1030, and windows 1 and 3 sit inside it, overlapping 60px, for the Doubter and the Undoer.

## Review Focus

1. **Souls spent on two gods in one turn.** Each god gets its own Devotion and its own remainder; 20 Souls to Khorne and 10 to Nurgle never make one Devotion for whichever came last. Pinned in Task 3.
2. **The other nine races' rivalries after the refactor.** Every read of `GG.RIVALS` now goes through `GG.rival_of`, and an Empire faction's brass earning must still take from its Khanate, exactly as before. Pinned in Task 2, one assertion per race and one live grant.
3. **A Skaven save after `taint` became a string.** The Grey Seers still earn per province carrying Skaven corruption, and a Warriors of Chaos faction counts only Undivided corruption, never Skaven. Pinned in Task 4.
4. **The word pass leaking either way.** No `_chs` string says "guild" or "Reputation", and no other race's string changes. Pinned in Task 7 (the `check_chs_words` check and the nine-race TSV diff).
5. **A Warriors of Chaos faction known only to the Doubter.** It is never sent a demand, and the demand clock does not restart on a turn where no god asked. Pinned in Task 5.

---

### Task 1: The Warriors of Chaos in the model's tables (Lua)

**Files:**
- Modify `$M` (LF): `GG.FLAVOURED` (3827), `GG.HIRE_UNIT_BY_CULTURE` (3747), `GG.TWISTS` (5468), `GG.HALL_TAGS` (4809), `GG.LEDGER_SOURCES` (6280), the end of `GG.SERVICES` (after `breeding_season`, 3732). No `GG.RACE_FIRE` entry (Ruling 7).
- Modify `$U` (CRLF): `GGUI.MCT_NAMES` (3948) gains a hand-written `_chs` entry. Task 7's `GEN --write` must reproduce it byte for byte.
- Tests: `tools/_guilds_harness.lua` (CRLF), `tools/_guilds_bounty_harness.lua` (LF).

Line numbers are as of 2026-10-12; find each with `grep -n` before editing.

**Interfaces:**
- **Produces:**
  - `GG.FLAVOURED["wh_main_chs_chaos"] = {tag = "_chs", feed = 100}`
  - `GG.HIRE_UNIT_BY_CULTURE["wh_main_chs_chaos"] = "wh3_dlc20_chs_inf_chosen_mkho"`
  - `GG.TWISTS["wh_main_chs_chaos"] = {rate_decay = 150, demand_reward = 150}`
  - `GG.HALL_TAGS["_chs"] = true`
  - LEDGER source `"gifts"`
  - the three race rows `soul_tithe`, `eye_turns`, `skull_throne`, last in `GG.SERVICES`
- **Consumed by:** Tasks 3, 6, 7, 8 and 10.

- [ ] **Step 1: The failing harness block.** Insert before the final `print("harness ok")` in `_guilds_harness.lua`:

```lua
;(function()
    -- THE WARRIORS OF CHAOS (woc spec, 2026-10-12): a tenth flavour, its twist and its
    -- three race services appended AFTER the Skaven's three.
    local CHS = "wh_main_chs_chaos"
    assert(GG.FLAVOURED[CHS] and GG.FLAVOURED[CHS].tag == "_chs"
           and GG.FLAVOURED[CHS].feed == 100, "the Warriors of Chaos flavour, feed 100")
    assert(GG.HIRE_UNIT_BY_CULTURE[CHS] == "wh3_dlc20_chs_inf_chosen_mkho",
           "the Blood God's hire is the Chosen of Khorne")
    assert(GG.TWISTS[CHS].rate_decay == 150 and GG.TWISTS[CHS].demand_reward == 150,
           "the Fickle Gods: decay and a paid demand both half again")
    assert(GG.HALL_TAGS["_chs"], "the Warriors of Chaos have halls")
    assert(GG.LEDGER_KNOWN.gifts, "the gifts ledger source")
    -- APPENDED AFTER THE SKAVEN: cooldowns are saved by position.
    local n = #GG.SERVICES
    assert(GG.SERVICES[n - 2].key == "soul_tithe" and GG.SERVICES[n - 1].key == "eye_turns"
           and GG.SERVICES[n].key == "skull_throne", "the Warriors of Chaos rows are last")
    assert(GG.SERVICES[n - 3].key == "breeding_season", "the Skaven's last row sits before them")
    for i = n - 2, n do
        assert(GG.SERVICES[i].race == CHS, GG.SERVICES[i].key .. " is a Warriors of Chaos row")
    end
    -- A SAVE FROM BEFORE THE WARRIORS OF CHAOS: a faction with no saved state loads blank.
    local F = "cr_chs_old"
    GG.CULTURE_OF[F] = CHS
    GG.state[F] = nil
    GG.load(F)
    for _, g in ipairs(GG.GUILDS) do
        local rep, fav = GG.get(F, g)
        assert(rep == 0 and fav == 0, "a Warriors of Chaos faction loads blank on " .. g)
    end
    GG.state[F], GG.CULTURE_OF[F] = nil, nil
end)()
```

Run `H > "$S/h.txt" 2>&1; grep "lua.exe:" "$S/h.txt"`. Expected: FAIL on "the Warriors of Chaos flavour, feed 100".

- [ ] **Step 2: The failing bounty-harness pin.** In `_guilds_bounty_harness.lua`, the `want` table (around 1812-1823) gains, after the Skaven line:

```lua
        -- THE FICKLE GODS (woc spec §2): decay x1.5, a paid demand 120 x 1.5.
        ["wh_main_chs_chaos"]          = {rate_decay = 150, demand_reward = 180},
```

Run `BH`. Expected: FAIL on `wh_main_chs_chaos rate_decay`.

- [ ] **Step 3: Implement the tables** in `$M`:

```lua
-- GG.FLAVOURED, after the _skv line:
    ["wh_main_chs_chaos"] = {tag = "_chs", feed = 100},
-- GG.HIRE_UNIT_BY_CULTURE, after the Skaven line:
    ["wh_main_chs_chaos"]          = "wh3_dlc20_chs_inf_chosen_mkho",
-- GG.TWISTS, after the Skaven line:
    -- THE FICKLE GODS (woc spec §2): "jealous and fickle deities" - Devotion fades faster
    -- when a god is not fed, and a demand answered pays more.
    ["wh_main_chs_chaos"]          = {rate_decay = 150, demand_reward = 150},
```

- `GG.HALL_TAGS`: add `["_chs"] = true` inside the one-line table, after `["_skv"] = true`.
- `GG.LEDGER_SOURCES`: after the Skaven pair `"undercity", "taint",` add a line `-- THE WARRIORS OF CHAOS (2026-10-12).` and `"gifts",`, before the RECRUITING comment. Appending inside the list is safe: `LEDGER_SOURCES` is read by name, never by position (`GG.LEDGER_KNOWN`); confirm with `grep -n "LEDGER_SOURCES\[" "$M"` returning nothing.

In `GG.SERVICES`, append after the `breeding_season` row:

```lua
    -- THE WARRIORS OF CHAOS' RACE SERVICES (2026-10-12), AFTER the Skaven rows: cooldowns
    -- are positional.
    {key="soul_tithe",          guild="slavers",      rank=2, cost=50,  cd=8,  kind="resource", resource="wh3_dlc20_chs_souls", factor="wh3_dlc20_souls_other", value=500, race="wh_main_chs_chaos"},
    {key="eye_turns",           guild="daemonsmiths", rank=3, cost=150, cd=12, kind="resource", resource="wh3_dlc20_chs_eye_of_the_gods", factor="gifts_of_chaos", value=15, race="wh_main_chs_chaos"},
    {key="skull_throne",        guild="immortals",    rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true, race="wh_main_chs_chaos"},
```

Copy the exact field set of the Skaven `food_tithe` (resource) and `breeding_season` (bundle) Lua rows. If a row carries a field this block lacks, match it field for field.

The Eye Turns is an ordinary `resource` row (Ruling 7): `GG.buy` already calls `cm:faction_add_pooled_resource(faction, s.resource, s.factor, s.value)` for that kind, so no `GG.RACE_FIRE` entry is needed. Tithe of Souls adds to `wh3_dlc20_chs_souls`, which is not in `GG.POOL_ROUTES`, so `GG.note_self` is not involved.

In `$U`, inside the generated `GGUI.MCT_NAMES` block, add after the `_skv` entry, in its exact layout (CRLF):

```lua
    ["_chs"] = {
        brass = "The Doubter",
        immortals = "The Blood God",
        daemonsmiths = "The Changer of Ways",
        khanate = "The Undoer",
        overseers = "The Plague Lord",
        slavers = "The Dark Prince",
        temple = "The Undivided",
    },
```

- [ ] **Step 4: Run.** `H`, `BH`, and `LUAC` on `$M` and `$U`. Expected: the Step 1 block and the Step 2 pin pass. Race-counting pins elsewhere now fail; Step 5 moves them.
- [ ] **Step 5: Move the race pins.** Every assertion that counts or lists races fails with a numbered message. Move each to the new counted value, never deleting it. Known sites:
  - `_guilds_harness.lua` around 6031-6041, the flavour `cases` list. Add `{"cr_flav_chs", "wh_main_chs_chaos", "_chs", 100, "wh3_dlc20_chs_inf_chosen_mkho"},` after the Skaven case.
  - The harness pin requiring a `GGUI.FRAME` per flavour (`grep -n "GGUI.FRAME\[" tools/_guilds_harness.lua`). It fails until Task 10. Because the harness stops at the first failed assert, add `GGUI.FRAME["_chs"]` now as a copy of `GGUI.FRAME["_skv"]` in `$U` (CRLF), and record the ruling "Task 10 replaces the `_chs` frame values".
  - `_guilds_bounty_harness.lua:1882`, the list of races the demand cases visit (`race("wh2_main_skv_skaven")`). Leave it; Task 5 adds the Warriors of Chaos case.

  Run `H` and `BH`. Expected: `harness ok`, `bounty harness ok`.

---

### Task 2: Per-race rival pairs

**Files:**
- Modify `$M`: a new `GG.RIVALS_RACE` and `GG.rival_of` after `GG.RIVALS` (120-124); the seven reads at `GG.rival_cost` (144), `GG.turn_start_charge` (517), `GG.roll_demand` (2332), `GG.demand_payable` (2385), `GG.pay_demand` (2399), and the service price (4760).
- Modify `$U`: the demand line (1698-1699) and the rival label (1904).
- Modify `tools/gen_great_guilds.py`: `RIVAL_PAIRS` (1158) gains `RIVAL_PAIRS_RACE` and `rival_pairs(tag)`; the Help rivalry line (3241); `check_rival_mirror` (4615).
- Test: `_guilds_harness.lua`.

**Interfaces:**
- **Consumes:** `GG.culture_of(faction)` (1817).
- **Produces:** `GG.RIVALS_RACE[culture] = {guild = rival, ...}`; `GG.rival_of(faction, guild)` returns the rival guild key or nil; Python `rival_pairs(tag)` returns a list of `(a, b)` tuples.

- [ ] **Step 1: The failing test.** Before `print("harness ok")`:

```lua
;(function()
    -- PER-RACE RIVALS (woc spec §4.1): the gods' own feuds, Khorne against Slaanesh and
    -- Nurgle against Tzeentch, and the two renegades against each other.
    local W = "cr_chs_rivals"
    GG.CULTURE_OF[W] = "wh_main_chs_chaos"
    local want = {immortals = "slavers", slavers = "immortals",
                  overseers = "daemonsmiths", daemonsmiths = "overseers",
                  brass = "khanate", khanate = "brass"}
    for g, r in pairs(want) do
        assert(GG.rival_of(W, g) == r, "the " .. g .. " god's rival is " .. r .. ", got "
               .. tostring(GG.rival_of(W, g)))
    end
    assert(GG.rival_of(W, "temple") == nil, "the Undivided has no rival")
    -- EVERY OTHER RACE KEEPS THE GLOBAL TABLE, guild by guild.
    for culture in pairs(GG.FLAVOURED) do
        if culture ~= "wh_main_chs_chaos" then
            local f = "cr_rivals_" .. culture
            GG.CULTURE_OF[f] = culture
            for _, g in ipairs(GG.GUILDS) do
                assert(GG.rival_of(f, g) == GG.RIVALS[g], culture .. " " .. g
                       .. " must keep the global rival " .. tostring(GG.RIVALS[g]))
            end
            GG.CULTURE_OF[f] = nil
        end
    end
    -- AND THE RIVALRY IS WHAT A GRANT ACTUALLY TAKES. A Khorne earning costs Slaanesh and
    -- leaves Tzeentch alone; an Empire Immortals earning still costs its Daemonsmiths.
    local keep_pc = GG.player_cultures
    GG.player_cultures = function() return {wh_main_chs_chaos = true, wh_main_emp_empire = true} end
    local E = "cr_emp_rivals"
    GG.CULTURE_OF[E] = "wh_main_emp_empire"
    for _, f in ipairs({W, E}) do
        GG.state[f], GG.turn_gain[f] = nil, {}
        GG.load(f)
        for _, g in ipairs(GG.GUILDS) do GG.state[f][g] = {rep = 500, fav = 0} end
        GG.grant(f, "immortals", 100, "battles")
    end
    assert(GG.get(W, "slavers") < 500, "Khorne's earning takes from Slaanesh")
    assert(GG.get(W, "daemonsmiths") == 500, "and not from Tzeentch")
    assert(GG.get(E, "daemonsmiths") < 500, "the Empire's Immortals still take from the Daemonsmiths")
    assert(GG.get(E, "slavers") == 500, "and not from the Slavers")
    GG.state[W], GG.state[E], GG.CULTURE_OF[W], GG.CULTURE_OF[E] = nil, nil, nil, nil
    GG.turn_gain[W], GG.turn_gain[E] = nil, nil
    GG.player_cultures = keep_pc
end)()
```

Before running, read `GG.load` and the shape of `GG.state[f][g]` (`grep -n "^function GG.load" "$M"`). If a track is not `{rep, fav}`, build it the way `GG.load` does. Run `H`. Expected: FAIL, `attempt to call field 'rival_of'`.

- [ ] **Step 2: Implement** in `$M`, after the `GG.RIVALS` table:

```lua
-- EACH RACE MAY PAIR ITS OWN RIVALS (woc spec §4.1, 2026-10-12). The Warriors of Chaos
-- follow the gods' own feuds - Khorne against Slaanesh, Nurgle against Tzeentch, as CA's
-- own wh_dlc08_norscan_gods.lua pairs them - and the two renegade gods against each other.
-- Every other race keeps GG.RIVALS. Written both ways, like GG.RIVALS.
GG.RIVALS_RACE = {
    ["wh_main_chs_chaos"] = {
        immortals = "slavers",      slavers      = "immortals",
        overseers = "daemonsmiths", daemonsmiths = "overseers",
        brass     = "khanate",      khanate      = "brass",
    },
}

-- The rival of `guild` for `faction`'s race. EVERY rivalry read goes through here.
function GG.rival_of(faction, guild)
    local t = GG.RIVALS_RACE[GG.culture_of(faction) or ""] or GG.RIVALS
    return t[guild]
end
```

Replace each read, keeping everything else on the line:
- 144: `local rival = GG.RIVALS[guild]` -> `local rival = GG.rival_of(faction, guild)`
- 517: `if GG.RIVALS[guild] ~= "brass" then return 0 end` -> `if GG.rival_of(faction, guild) ~= "brass" then return 0 end`
- 2332: `local rival = GG.RIVALS[guild]` -> `local rival = GG.rival_of(faction, guild)`
- 2385: `local rival = GG.RIVALS[d.guild]` -> `local rival = GG.rival_of(faction, d.guild)`
- 2399: `GG.spend(faction, GG.RIVALS[d.guild], d.amount)` -> `GG.spend(faction, GG.rival_of(faction, d.guild), d.amount)`
- 4760: `local rival = GG.RIVALS[svc.guild]` -> `local rival = GG.rival_of(faction, svc.guild)`

In `$U` (CRLF):
- 1698-1699: `GG.RIVALS[d.guild]` (both) -> `GG.rival_of(faction, d.guild)`
- 1904: `local rival = GG.RIVALS[guild]` -> `local rival = GG.rival_of(faction, guild)`

Confirm `faction` is the function's own variable at each site (read three lines up). Then `grep -n "GG\.RIVALS\[" "$M" "$U" "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua"`. Expected: nothing.

- [ ] **Step 3: The generator mirror.** In `tools/gen_great_guilds.py`, after `RIVAL_PAIRS`:

```python
# A RACE'S OWN PAIRS, mirrored from GG.RIVALS_RACE (woc spec §4.1): the Warriors of Chaos
# follow the gods' feuds. check_rival_mirror() compares the two.
RIVAL_PAIRS_RACE = {"_chs": [("immortals", "slavers"), ("overseers", "daemonsmiths"),
                             ("brass", "khanate")]}


def rival_pairs(tag):
    return RIVAL_PAIRS_RACE.get(tag, RIVAL_PAIRS)
```

At 3241, the Help line's `for a, b in RIVAL_PAIRS),` becomes `for a, b in rival_pairs(tag)),`.

In `check_rival_mirror`, before `return out`:

```python
    # THE RACES' OWN PAIRS (woc spec §4.1). A culture's pairs here and there must agree,
    # and the help page names exactly those.
    race = re.search(r"^GG\.RIVALS_RACE = \{(.*?)\n\}", lua, re.S | re.M)
    theirs_race = {}
    if race:
        for culture, body in re.findall(r'\["([^"]+)"\]\s*=\s*\{(.*?)\}', race.group(1), re.S):
            theirs_race[culture] = set(tuple(sorted(p)) for p in
                                       re.findall(r"(\w+)\s*=\s*\"(\w+)\"", body))
    mine_race = dict((FLAVOURS[t]["culture"], set(tuple(sorted(p)) for p in ps))
                     for t, ps in RIVAL_PAIRS_RACE.items())
    if theirs_race != mine_race:
        out.append("GG.RIVALS_RACE pairs %r and RIVAL_PAIRS_RACE says %r"
                   % (theirs_race, mine_race))
```

`RIVAL_PAIRS_RACE` reads `FLAVOURS["_chs"]`, which Task 7 adds. Until then, run the check as `GG1(check_rival_mirror)` only after Task 7, and record that here.

- [ ] **Step 4: Run.** `H`, `BH`, `LUAC` on `$M` and `$U`. Expected: green.

---

### Task 3: The Gifts route (Souls spent pay that god)

**Files:**
- Modify `$M`: `GG.EARN_ROUTES` (4408), `GG.EARN_OF` (4423), `GG.POOL_ROUTES` (4435), a new `GG.POOL_GUILD`, `GG.race_earn` (4475), the `gg_earn_pool` listener (6055).
- Test: `_guilds_harness.lua`.

**Interfaces:**
- **Consumes:** LEDGER `"gifts"` (Task 1).
- **Produces:**
  - `GG.EARN_ROUTES.gifts = {per = 25, by_pool = true}`, `GG.EARN_OF["wh_main_chs_chaos"] = "gifts"`
  - `GG.POOL_GUILD[pool_key] = guild` for the five `wh3_dlc20_chs_souls_spent_*` pools
  - `GG.race_earn(faction, route, amount, guild)`: the fourth argument names the guild of a `by_pool` route; ignored otherwise.
  - saved remainder key `derpy_gg_carry_<faction>_gifts_<guild>`.

- [ ] **Step 1: The failing test.** Before `print("harness ok")`:

```lua
;(function()
    -- GIFTS OF THE GODS (woc spec §3.2): Souls spent on a god's gifts pay that god, one
    -- Devotion per 25, and each god keeps its own remainder.
    local keep_pc = GG.player_cultures
    GG.player_cultures = function() return {wh_main_chs_chaos = true} end
    local W = "cr_chs_gifts"
    GG.CULTURE_OF[W], GG.state[W], GG.turn_gain[W] = "wh_main_chs_chaos", nil, {}
    for _, g in ipairs(GG.GUILDS) do GG.earn_carry[W .. "|gifts_" .. g] = nil end
    GG.load(W)
    GG.race_earn(W, "gifts", 60, "immortals")
    assert(select(1, GG.get(W, "immortals")) == 2, "60 Souls to Khorne pay 2, got "
           .. tostring(select(1, GG.get(W, "immortals"))))
    assert(cm:get_saved_value("derpy_gg_carry_" .. W .. "_gifts_immortals") == 10,
           "Khorne keeps 10 towards the next")
    -- 20 TO NURGLE pays nothing, and is not added to Khorne's 10.
    GG.race_earn(W, "gifts", 20, "overseers")
    assert(select(1, GG.get(W, "overseers")) == 0, "20 Souls to Nurgle pay nothing yet")
    assert(select(1, GG.get(W, "immortals")) == 2, "and do not pay Khorne")
    GG.race_earn(W, "gifts", 15, "immortals")
    assert(select(1, GG.get(W, "immortals")) == 3, "Khorne's 10 + 15 make one more")
    -- NO GUILD NAMED, NOTHING PAID; ANOTHER RACE'S SPENDING PAYS NOTHING.
    assert(GG.race_earn(W, "gifts", 100, nil) == 0, "a gift with no god pays nothing")
    local K = "cr_skv_gifts"
    GG.CULTURE_OF[K] = "wh2_main_skv_skaven"
    assert(GG.race_earn(K, "gifts", 100, "immortals") == 0, "only the Warriors of Chaos")
    -- THE FIVE POOLS, AND NONE FOR THE RENEGADES.
    local n = 0
    for key, g in pairs(GG.POOL_GUILD) do
        n = n + 1
        assert(GG.POOL_ROUTES[key] == "gifts", key .. " routes to gifts")
        assert(g ~= "brass" and g ~= "khanate", "the Four do not deal with renegades: " .. key)
    end
    assert(n == 5, "five Souls pools, got " .. n)
    -- AND THE EVENT REACHES IT: a PooledResourceChanged on Tzeentch's pool pays Tzeentch.
    assert(handlers["gg_earn_pool"], "no PooledResourceChanged listener")
    local function fac(name)
        return {is_null_interface = function() return false end, name = function() return name end}
    end
    handlers["gg_earn_pool"]({
        resource = function() return {key = function() return "wh3_dlc20_chs_souls_spent_tze" end} end,
        has_faction = function() return true end,
        faction = function() return fac(W) end,
        amount = function() return 50 end,
        factor = function() return {is_null_interface = function() return true end} end,
    })
    assert(select(1, GG.get(W, "daemonsmiths")) == 2, "50 Souls to Tzeentch pay 2, got "
           .. tostring(select(1, GG.get(W, "daemonsmiths"))))
    GG.state[W], GG.state[K], GG.CULTURE_OF[W], GG.CULTURE_OF[K] = nil, nil, nil, nil
    GG.turn_gain[W] = nil
    GG.player_cultures = keep_pc
end)()
```

`handlers` is the table the Skaven block reads (`grep -n "local handlers" tools/_guilds_harness.lua`); if it is local to another block, copy that block's way of collecting it. Read how `faction_name_of` reads a context (`grep -n "local function faction_name_of" "$M"`) and give the fake context exactly the members it calls. Run `H`. Expected: FAIL (`gifts` is no route yet, so 0 paid).

- [ ] **Step 2: Implement.** `GG.EARN_ROUTES`, after `undercity`:

```lua
    -- GIFTS OF THE GODS (woc spec §3.2): Souls spent on a god's gifts, by the point. The
    -- pool names the god (GG.POOL_GUILD), and each god keeps its own remainder.
    gifts      = {per = 25, by_pool = true},
```

`GG.EARN_OF`, after the Skaven line: `["wh_main_chs_chaos"]         = "gifts",`

`GG.POOL_ROUTES` becomes:

```lua
GG.POOL_ROUTES = {wh3_dlc25_dwf_grudge_points = "grudges", brt_chivalry = "chivalry",
                  def_slaves = "captives",
                  -- THE WARRIORS OF CHAOS (woc spec §3.2): Souls spent, one pool per god.
                  wh3_dlc20_chs_souls_spent_kho = "gifts", wh3_dlc20_chs_souls_spent_nur = "gifts",
                  wh3_dlc20_chs_souls_spent_sla = "gifts", wh3_dlc20_chs_souls_spent_tze = "gifts",
                  wh3_dlc20_chs_souls_spent_und = "gifts"}
-- WHICH GOD A SOULS POOL PAYS. The Doubter and the Undoer have none: the Four do not deal
-- with renegades.
GG.POOL_GUILD = {wh3_dlc20_chs_souls_spent_kho = "immortals",
                 wh3_dlc20_chs_souls_spent_nur = "overseers",
                 wh3_dlc20_chs_souls_spent_sla = "slavers",
                 wh3_dlc20_chs_souls_spent_tze = "daemonsmiths",
                 wh3_dlc20_chs_souls_spent_und = "temple"}
```

`GG.pool_route_counts` needs no `gifts` branch: all three factors of the five pools (`path_to_glory`, `gifts_of_chaos`, `gifts_of_chaos_upkeep`) are Souls given to that god (Ruling 5), and its default returns true.

`GG.race_earn` becomes:

```lua
function GG.race_earn(faction, route, amount, guild)
    local r = GG.EARN_ROUTES[route]
    if not r or not faction or not GG.race_on() then return 0 end
    if GG.EARN_OF[GG.culture_of(faction) or ""] ~= route then return 0 end
    -- A BY-POOL ROUTE names its guild per call and keeps one remainder per guild: 20 Souls
    -- to Khorne and 10 to Nurgle are not one Devotion to whichever came last.
    local g = r.guild
    if r.by_pool then g = guild end
    if not g then return 0 end
    local n = r.rep
    if not n then
        -- SAVED AS IT CHANGES and read back when memory has none, so a load does not drop
        -- 19 Slaves towards the next point (logic audit, 2026-09-29).
        local sub = r.by_pool and ("_" .. g) or ""
        local k = faction .. "|" .. route .. sub
        local sk = "derpy_gg_carry_" .. faction .. "_" .. route .. sub
        if GG.earn_carry[k] == nil then
            GG.earn_carry[k] = tonumber(cm:get_saved_value(sk)) or 0
        end
        local have = GG.earn_carry[k] + (amount or 0)
        n = math.floor(have / r.per)
        GG.earn_carry[k] = have - n * r.per
        cm:set_saved_value(sk, GG.earn_carry[k])
    end
    if n <= 0 then return 0 end
    local before = GG.get(faction, g)
    GG.capped_grant(faction, g, n, route)
    local paid = GG.get(faction, g) - before
    if paid > 0 then GG.log_add(faction, "earn", g, route, paid) end
    return paid
end
```

The harness clears `GG.earn_carry[W .. "|gifts_" .. g]`, which matches `k` above (`faction .. "|" .. route .. "_" .. g`).

In `gg_earn_pool`, the last line becomes:

```lua
        GG.load(name); GG.race_earn(name, route, amount, GG.POOL_GUILD[key]); GG.save(name)
```

- [ ] **Step 3: Run.** `H`, `BH`, `LUAC` on `$M`, and `py tools/check_lua_api.py "$M"`. Expected: green; the existing grudges, chivalry and captives cases still pass, since their `guild` comes from `r.guild` as before.

---

### Task 4: The temple's taint names its resource, and the Undivided's routes

**Files:**
- Modify `$M`: the `-- BEGIN TEMPLE ROUTES` block (573-603); `GG.temple_counts` (950).
- Test: `_guilds_harness.lua`, inside the routes block (after `"no Skaven priests route"`, about 10140).

**Interfaces:**
- **Produces:** `GG.TEMPLE_ROUTES[culture].taint` is a corruption resource key string, or nil. `GG.TEMPLE_ROUTES["wh_main_chs_chaos"] = {taint = "wh3_main_corruption_chaos", holy = {...}, priests = {...}}`.
- **Consumed by:** Task 7 (the generator's `TEMPLE_ROUTES` mirror).

- [ ] **Step 1: The failing test.** Inside the routes block, after `assert(GG.TEMPLE_ROUTES["wh2_main_skv_skaven"].priests == nil, ...)` (it uses that block's local `prov`, `earned`, `L`):

```lua
    -- THE UNDIVIDED (woc spec §3.3): paid per province carrying UNDIVIDED Chaos corruption.
    -- A Skaven-only province pays the Undivided nothing, and an Undivided-only one pays the
    -- Grey Seers nothing: each taint names its own resource.
    local und1 = prov(10, 0, 0, {wh3_main_corruption_chaos = 30})
    local und2 = prov(-5, 4, 0, {wh3_main_corruption_chaos = 1, wh3_main_corruption_khorne = 9})
    local skv_only = prov(10, 0, 0, {wh3_main_corruption_skaven = 12})
    local kho_only = prov(10, 0, 0, {wh3_main_corruption_khorne = 40})
    assert(earned("wh_main_chs_chaos", function(F)
        GG.temple_turn(F, {provinces = function() return L({und1, und2, skv_only, kho_only}) end}) end)
        == 2 * 2, "two Undivided provinces x 2; Skaven and Khorne-only provinces nothing")
    assert(earned("wh2_main_skv_skaven", function(F)
        GG.temple_turn(F, {provinces = function() return L({und1, skv_only}) end}) end)
        == 1 * 2, "the Grey Seers still count only Skaven corruption")
    -- HOLY WAR: the cache is asked with the Empire, Kislev and Cathay.
    local asked3
    cm.pending_battle_cache_faction_won_battle_against_culture = function(_, fk, cultures)
        asked3 = cultures
        return true
    end
    assert(earned("wh_main_chs_chaos", function(F) GG.temple_holy(F) end) == 10,
           "a Warriors of Chaos win against the Empire pays 10")
    assert(asked3[1] == "wh_main_emp_empire" and asked3[2] == "wh3_main_ksl_kislev"
           and asked3[3] == "wh3_main_cth_cathay", "asked with the Empire, Kislev and Cathay")
    cm.pending_battle_cache_faction_won_battle_against_culture = nil
    -- PRIESTS: an unmarked Sorcerer's action pays the Undivided; a marked one the Undoer.
    assert(earned("wh_main_chs_chaos", function(F)
        GG.on_agent_action(F, true, "wh_main_chs_chaos_sorcerer_fire") end) == 8,
        "an unmarked Sorcerer pays the Undivided 8")
    local W = "cr_chs_priest"
    GG.CULTURE_OF[W], GG.state[W], GG.turn_gain[W] = "wh_main_chs_chaos", nil, {}
    GG.load(W)
    GG.on_agent_action(W, true, "wh3_dlc20_chs_sorcerer_metal_mtze")
    assert(select(1, GG.get(W, "khanate")) == 8 and select(1, GG.get(W, "temple")) == 0,
           "a marked Sorcerer pays the Undoer")
    GG.state[W], GG.CULTURE_OF[W], GG.turn_gain[W] = nil, nil, nil
    -- THE PREVIEW SEES THE UNDIVIDED (woc spec §10): GG.turn_start_pay must report the taint
    -- route's turn-start pay, or GG.hold_lead reads the leader as behind every round.
    local keep_gf2, keep_pc2 = cm.get_faction, GG.player_cultures
    local T2 = "cr_chs_pay"
    cm.get_faction = function(self, k)
        if k == T2 then
            return {is_null_interface = function() return false end,
                    provinces = function() return L({und1, und2, skv_only, kho_only}) end}
        end
        return keep_gf2(self, k)
    end
    GG.CULTURE_OF[T2] = "wh_main_chs_chaos"
    GG.player_cultures = function() return {wh_main_chs_chaos = true} end
    assert(GG.turn_start_pay(T2, "temple") == 2 * 2,
           "the Undivided's turn start pays two corrupted provinces x 2, got "
           .. GG.turn_start_pay(T2, "temple"))
    cm.get_faction, GG.player_cultures, GG.CULTURE_OF[T2] = keep_gf2, keep_pc2, nil
```

Read `earned` first: if it measures only the temple, the first priests assert is right; if it takes a guild argument, pass `"temple"`. If `GG.player_cultures` must include `wh_main_chs_chaos` for `W` to be covered, set it as the Skaven lines above do. Run `H`. Expected: FAIL (no Warriors of Chaos entry, so 0).

- [ ] **Step 2: Implement.** In the TEMPLE ROUTES block, the Skaven entry's `taint = true,` becomes `taint = "wh3_main_corruption_skaven",`. After the Skaven entry:

```lua
    -- THE UNDIVIDED (woc spec §3.3): the Warriors of Chaos ARE the corruption, so no devout
    -- or clean route - `taint` pays per province carrying Undivided Chaos corruption. Their
    -- priests are the UNMARKED Chaos Sorcerers; a marked one pays the Undoer like any hero.
    ["wh_main_chs_chaos"] = {taint = "wh3_main_corruption_chaos",
        holy = {"wh_main_emp_empire", "wh3_main_ksl_kislev", "wh3_main_cth_cathay"},
        priests = {"wh_main_chs_chaos_sorcerer_fire", "wh_main_chs_chaos_sorcerer_death",
                    "wh_main_chs_chaos_sorcerer_metal", "wh_dlc07_chs_chaos_sorcerer_shadow"}},
```

Update the block's header comment: `taint`: a province carrying the named corruption resource.

In `GG.temple_counts`, the taint lines become:

```lua
        -- A RACE'S TAINT: a province CARRYING the corruption its temple names (Skaven for
        -- the Grey Seers, Undivided for the Warriors of Chaos), the reverse of clean.
        if r.taint then
            local res = fp:province():pooled_resource_manager():resource(r.taint)
            if not res:is_null_interface() and res:value() > 0 then tainted = tainted + 1 end
        end
```

`GG.temple_turn` and `GG.turn_start_pay` test `r.taint` for truth only, so they need no change; confirm with `grep -n "r\.taint" "$M"`, which must show only the guards and this line.

- [ ] **Step 3: Run.** `H` (the Skaven taint and lead-hold cases must still pass), `BH`, `LUAC` on `$M`. Expected: green.

---

### Task 5: Necoho's rule (the Doubter never makes a demand)

**Files:**
- Modify `$M`: a new `GG.NO_DEMAND` before `GG.roll_demand` (2323); the pool loop in `GG.roll_demand`.
- Test: `_guilds_bounty_harness.lua`, after the Skaven expired-demand case (about 1890).

**Interfaces:**
- **Produces:** `GG.NO_DEMAND[culture] = {guild = true, ...}`.
- **Consumed by:** Task 7 (`NO_DEMAND` mirror and the Help line).

- [ ] **Step 1: The failing test.** In `_guilds_bounty_harness.lua`, after the Skaven case ends (`GG.demands.me, GG.demand_last.me = nil, nil`):

```lua
    -- THE DOUBTER ASKS NOTHING (woc spec §4.4): a faction known only to the Doubter is
    -- never sent a demand, and the clock does not restart; known to the Doubter and the
    -- Undoer, only the Undoer ever asks.
    race("wh_main_chs_chaos")
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 0, fav = 0} end
    GG.state.me.brass = {rep = 500, fav = 0}
    GG.demands.me, GG.demand_last.me = nil, nil
    assert(GG.roll_demand("me", 30) == nil, "the Doubter never asks")
    assert(GG.demand_tick("me", 40) == nil and GG.demand_last.me == nil,
           "no demand issued, so the clock is not stamped")
    GG.state.me.khanate = {rep = 500, fav = 0}
    for i = 1, 20 do
        GG.demands.me = nil
        local d = GG.roll_demand("me", 40 + i)
        assert(d and d.guild == "khanate", "only the Undoer asks, got " .. tostring(d and d.guild))
    end
    GG.demands.me, GG.demand_last.me = nil, nil
```

Run `BH`. Expected: FAIL on "the Doubter never asks".

- [ ] **Step 2: Implement.** Before `GG.roll_demand`:

```lua
-- THE DOUBTER ASKS NOTHING (woc spec §4.4): "Necoho requires nothing from his followers".
-- A guild listed for a culture is never the one a demand comes from. Every demand, AI and
-- human, is rolled here.
GG.NO_DEMAND = {["wh_main_chs_chaos"] = {brass = true}}
```

In `GG.roll_demand`, the pool loop becomes:

```lua
    local quiet = GG.NO_DEMAND[GG.culture_of(faction) or ""] or {}
    for i = 1, #GG.GUILDS do
        local g = GG.GUILDS[i]
        if (GG.get(faction, g)) > 0 and not quiet[g] then pool[#pool + 1] = g end
    end
```

Confirm no other code creates a demand: `grep -n "GG.demands\[[a-z]*\] *= *{" "$M" "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua"` must show only `GG.roll_demand`'s assignment (and a save loader, which restores and never rolls).

- [ ] **Step 3: Run.** `BH`, `H`, `LUAC` on `$M`. Expected: green.

---

### Task 6: Recruiting by mark, and the building words

**Files:**
- Modify `$M`: `GG.RECRUIT_ROUTES` (632, a new `["wh_main_chs_chaos"]` entry after the Skaven's, inside BEGIN/END RECRUIT ROUTES); `GG.BUILDING_THEME_RACE` (1103, a new `["_chs"]` entry after `["_skv"]`); `GG.UPGRADE_PAYS` (after `GG.RECRUIT_DOUBLE`, 900) and a `gg_recruit_upgrade` listener (after `gg_recruit_character`, 6006).
- Test: `_guilds_harness.lua`.

**Interfaces:**
- **Consumes:** `GG.recruit_guild(culture, list, t)`, `GG.guild_of_chain(chain, tag)`, `GG.on_recruit(faction, list, t)`.
- **Produces:** `GG.RECRUIT_ROUTES["wh_main_chs_chaos"]`, `GG.BUILDING_THEME_RACE["_chs"]`, `GG.UPGRADE_PAYS`, the `gg_recruit_upgrade` handler.

- [ ] **Step 1: The failing test.** Before `print("harness ok")`:

```lua
;(function()
    -- RECRUITING BY MARK (woc spec §3.4) and THE BUILDING WORDS (§3.5).
    local C = "wh_main_chs_chaos"
    local function u(key, caste, class)
        return GG.recruit_guild(C, "units", {key = key, caste = caste, class = class})
    end
    local function ch(key, agent, caster)
        return GG.recruit_guild(C, "characters", {key = key, agent = agent, caster = caster})
    end
    local units = {
        {"wh3_dlc20_chs_inf_chosen_mkho", "melee_infantry", "inf_mel", "immortals", "Chosen of Khorne"},
        {"wh3_main_kho_cav_skullcrushers_0", "monstrous_cavalry", "cav_shk", "immortals", "Skullcrushers (_kho_)"},
        {"wh3_dlc20_chs_inf_chosen_mnur", "melee_infantry", "inf_mel", "overseers", "Chosen of Nurgle"},
        {"wh3_dlc29_chs_inf_putrid_blightkings_great_weapons", "melee_infantry", "inf_mel", "overseers", "Blightkings"},
        {"wh3_dlc20_chs_inf_chosen_msla", "melee_infantry", "inf_mel", "slavers", "Chosen of Slaanesh"},
        {"wh3_dlc20_chs_inf_chosen_mtze", "melee_infantry", "inf_mel", "daemonsmiths", "Chosen of Tzeentch"},
        {"wh_main_chs_inf_chosen_0", "melee_infantry", "inf_mel", "temple", "unmarked Chosen"},
        {"wh_main_chs_art_hellcannon", "warmachine", "art_fld", "temple", "the Hellcannon"},
    }
    for _, c in ipairs(units) do
        local got = u(c[1], c[2], c[3])
        assert(got == c[4], c[5] .. " pay " .. c[4] .. ", got " .. tostring(got))
    end
    local chars = {
        {"wh3_dlc20_kho_valkia", "general", false, "immortals"},
        {"wh3_dlc20_chs_daemon_prince_khorne", "general", false, "immortals"},
        {"wh3_dlc20_nur_festus", "general", true, "overseers"},
        {"wh3_dlc29_chs_glottkin", "general", false, "overseers"},
        {"wh_dlc01_chs_prince_sigvald", "general", false, "slavers"},
        {"wh3_dlc20_sla_azazel", "general", false, "slavers"},
        {"wh3_dlc20_tze_vilitch", "general", true, "daemonsmiths"},
        {"wh3_dlc20_chs_sorcerer_metal_mtze", "wizard", true, "daemonsmiths"},
        {"wh_main_chs_archaon", "general", false, "temple"},
        {"wh_main_chs_chaos_sorcerer_fire", "wizard", true, "temple"},
        {"wh_main_chs_exalted_hero", "champion", false, "temple"},
    }
    for _, c in ipairs(chars) do
        local got = ch(c[1], c[2], c[3])
        assert(got == c[4], c[1] .. " pays " .. c[4] .. ", got " .. tostring(got))
    end
    -- NOTHING PAYS THE RENEGADES: they have no warriors.
    for _, list in ipairs({"units", "characters"}) do
        for _, r in ipairs(GG.RECRUIT_ROUTES[C][list]) do
            assert(r[1] ~= "brass" and r[1] ~= "khanate", "a recruit pays a renegade: "
                   .. tostring(r.key))
        end
    end
    local want = {
        wh3_dlc20_woc_dark_fortress_shrine = "temple",
        wh3_dlc20_woc_chaos_altar_corruption = "temple",
        wh3_dlc20_woc_dark_fortress_growth = "overseers",
        wh3_dlc29_bch_woc_nurgle_garden_growth = "overseers",
        wh3_dlc29_bch_woc_nurgle_garden_towers = "overseers",
        wh3_dlc29_bch_woc_nurgle_garden_garrison = "overseers",
        wh3_dlc20_woc_dark_fortress_income = "brass",
        wh3_dlc20_woc_resource_gold = "brass",
        wh3_dlc20_woc_dark_fortress_warriors = "immortals",
        wh3_dlc20_woc_dark_fortress_knights = "immortals",
        wh3_dlc20_woc_dark_fortress_marauder = "immortals",
        wh3_dlc20_woc_chaos_altar_recruit = "immortals",
        wh3_dlc20_woc_chaos_altar_replenishment = "immortals",
        wh3_dlc20_woc_dark_fortress_chaos_monsters = "daemonsmiths",
        wh3_dlc20_woc_dark_fortress_large_monsters = "daemonsmiths",
        wh3_dlc20_woc_dark_fortress_vassals = "slavers",
        wh3_main_chs_allied_outpost = "slavers",
        wh3_dlc20_woc_dark_fortress_towers = "khanate",
        wh3_dlc20_woc_chaos_altar_garrison = "khanate",
        wh3_dlc20_foreign_slot_discovery_woc = "khanate",
    }
    for chain, g in pairs(want) do
        assert(GG.guild_of_chain(chain, "_chs") == g, chain .. " should pay " .. g .. ", got "
               .. tostring(GG.guild_of_chain(chain, "_chs")))
    end
end)()
```

Run `H`. Expected: FAIL on the first recruit assert.

- [ ] **Step 2: Implement the recruit routes,** after the Skaven entry and before the closing `}` of `GG.RECRUIT_ROUTES`:

```lua
    -- THE WARRIORS OF CHAOS (woc spec §3.4): by the MARK in the key. Unmarked is the
    -- Undivided's, as a last rule that fits everything. Nothing pays the Doubter or the
    -- Undoer: the renegades have no warriors.
    ["wh_main_chs_chaos"] = {
        units = {
            {"immortals", key = "_mkho"},     -- the Mark of Khorne
            {"immortals", key = "_kho_"},
            {"overseers", key = "_mnur"},
            {"overseers", key = "_nur_"},
            {"overseers", key = "blightking"},
            {"slavers", key = "_msla"},
            {"slavers", key = "_sla_"},
            {"daemonsmiths", key = "_mtze"},
            {"daemonsmiths", key = "_tze_"},
            {"temple"},                       -- unmarked: the Undivided's
        },
        characters = {
            {"immortals", key = "_mkho"},
            {"immortals", key = "_kho_"},
            {"immortals", key = "khorne"},
            {"overseers", key = "_mnur"},
            {"overseers", key = "_nur_"},
            {"overseers", key = "nurgle"},
            {"overseers", key = "glottkin"},
            {"overseers", key = "gutrot"},
            {"overseers", key = "bloab"},
            {"overseers", key = "morbidex"},
            {"overseers", key = "orghotts"},
            {"slavers", key = "_msla"},
            {"slavers", key = "_sla_"},
            {"slavers", key = "slaanesh"},
            {"slavers", key = "sigvald"},
            {"daemonsmiths", key = "_mtze"},
            {"daemonsmiths", key = "_tze_"},
            {"daemonsmiths", key = "tzeentch"},
            {"daemonsmiths", key = "lord_of_change"},
            {"temple"},                       -- Archaon, Kholek, unmarked lords and heroes
        },
    },
```

`key` is a plain substring and may hold only `[a-z0-9_]`; `_mkho` and `_kho_` qualify.

- [ ] **Step 3: Implement the building words,** after the `["_skv"]` entry of `GG.BUILDING_THEME_RACE`:

```lua
    -- THE WARRIORS OF CHAOS (woc spec §3.5). No vanilla chain belongs to a god except the
    -- Glottkin's Nurgle gardens, so the words go by trade; read from CA's display names.
    ["_chs"] = {
        {"temple", {"fortress_shrine", "chaos_altar_corruption"}},
        {"overseers", {"fortress_growth", "nurgle_garden"}},
        {"brass", {"fortress_income", "woc_resource_"}},
        {"immortals", {"fortress_warriors", "fortress_knights", "fortress_marauder",
                       "chaos_altar_recruit", "chaos_altar_replenishment"}},
        {"daemonsmiths", {"chaos_monsters", "large_monsters"}},
        {"slavers", {"fortress_vassals", "chs_allied_outpost"}},
        {"khanate", {"fortress_towers", "woc_chaos_altar_special_gate_towers",
                     "woc_chaos_altar_garrison", "foreign_slot_discovery_woc"}},
    },
```

- [ ] **Step 4: An upgrade pays its god (Ruling 9).** The failing test, before `print("harness ok")`, copying the RECRUITING block's setup and teardown (around 10347):

```lua
;(function()
    -- AN UPGRADE PAYS ITS GOD (woc Ruling 9), for the Warriors of Chaos only. Driven
    -- through the handler with exactly the accessors scripting_doc lists for UnitUpgraded
    -- (unit, upgrade_group), and measured as Devotion that moved.
    local W, D = "cr_upgrade_chs", "cr_upgrade_chd"
    local prev_humans, prev_getter, keep = GG.humans, cm.get_human_factions, GG.TUNE
    GG.humans, GG.player_cultures_cache = nil, nil
    cm.get_human_factions = function() return {W, D} end
    GG.CULTURE_OF[W], GG.CULTURE_OF[D] = "wh_main_chs_chaos", "wh3_dlc23_chd_chaos_dwarfs"
    GG.TUNE = GG.unpack_tune(GG.pack_tune({}))
    assert(handlers["gg_recruit_upgrade"], "the upgrade listener must be registered")
    local function upgrade(f, key)
        handlers["gg_recruit_upgrade"]({
            unit = function() return {
                faction = function() return {name = function() return f end} end,
                unit_key = function() return key end,
                unit_caste = function() return "melee_infantry" end,
                unit_class = function() return "inf_mel" end} end,
            upgrade_group = function() return {} end})
    end
    local function total(f)
        local n = 0
        for _, g in ipairs(GG.GUILDS) do n = n + (GG.get(f, g)) end
        return n
    end
    for _, f in ipairs({W, D}) do
        GG.state[f] = nil; saved["derpy_gg_" .. f] = nil; GG.reset_turn(f)
    end
    local before = (GG.get(W, "immortals"))
    upgrade(W, "wh3_dlc20_chs_inf_chosen_mkho")
    local got = (GG.get(W, "immortals")) - before
    assert(got == 2, "Warriors upgraded to Chosen of Khorne pay the Blood God 2, paid " .. got)
    local chd = total(D)
    upgrade(D, "wh3_dlc23_chd_inf_infernal_guard")
    assert(total(D) == chd, "an upgrade pays nothing for a race outside GG.UPGRADE_PAYS")
    GG.TUNE, GG.humans, cm.get_human_factions = keep, prev_humans, prev_getter
    GG.player_cultures_cache = nil
    for _, f in ipairs({W, D}) do GG.state[f], GG.CULTURE_OF[f] = nil, nil end
end)()
```

Run `H`. Expected: FAIL on "the upgrade listener must be registered". Then in `$M`, after `GG.RECRUIT_DOUBLE`:

```lua
-- AN UPGRADE IS A RECRUIT ONLY WHERE THE RACE RECRUITS BY UPGRADING (woc Ruling 9): the
-- Warriors of Chaos get their marked units and their Chosen that way. For any other race
-- an upgrade is not a new warrior and pays nothing.
GG.UPGRADE_PAYS = {["wh_main_chs_chaos"] = true}
```

and after the `gg_recruit_character` listener:

```lua
    -- UnitUpgraded -> unit, upgrade_group (scripting_doc). Whether `unit` is the unit
    -- after the upgrade is an in-game check (woc spec §10).
    core:add_listener("gg_recruit_upgrade", "UnitUpgraded", true, function(context)
        local ok, name, t = pcall(function()
            local u = context:unit()
            return u:faction():name(),
                   {key = u:unit_key(), caste = u:unit_caste(), class = u:unit_class()}
        end)
        if not ok or not name or not GG.covered(name) then return end
        if not GG.UPGRADE_PAYS[GG.culture_of(name) or ""] then return end
        GG.load(name); GG.on_recruit(name, "units", t); GG.save(name)
    end, true)
```

`py tools/check_lua_api.py "$M"` must not flag `UnitUpgraded` (it checks members, not event names; the event name is from scripting_doc's event list).

- [ ] **Step 5: Run.** `H`. Expected: `harness ok`. Then `GG1(check_recruit_routes)` and `GG1(check_building_theme)` (the generator's two checks run the Lua blocks under lua.exe against vanilla). Both read `FLAVOURS`/`HALL_RACES` for `_chs` and may refuse until Tasks 7-8 add them; if so, record the findings and re-run in Task 8 Step 4. A finding that names a `_chs` key matching nothing, or a hall unit paying another god, is fixed here.

---

### Task 7: The generator: the flavour, its text, its services, the temple lore and the mirrors

**Files:**
- Modify `tools/gen_great_guilds.py` (LF):
  - `FLAVOURS` (1168): a `_chs` entry immediately before `"_gen"`;
  - `POOL_NAMES` (1849), `TEMPLE_NAMES` (1956), `TEMPLE_FLAVOUR` (1990), `RECRUIT_SAYS` (2094), `RACE_TEXT` (6659);
  - `TEMPLE_ROUTES` (2068): the Skaven `taint` and the new entry;
  - `EARN_ROUTES` / `EARN_OF` (6633), `TWISTS` (6644), and a new `NO_DEMAND`;
  - `SERVICES`: three rows appended after `breeding_season`; `_chs` overrides on `alms_and_bribes`, `purge_unclean`, `consecration`, `hashut_blessing`, `zeal`, `holy_war`;
  - `RACE_UNWANTED_EFFECTS`, `FLAVOUR_WORDS_ALLOWED` (2197);
  - `TEMPLE_LORE` (2322) and `_TEMPLE_HALL_SEAT` (2352);
  - the word pass, `CHS_WORDS` and `check_chs_words`;
  - `check_race_mirror` (gifts has no single guild), the two `EARN_ROUTES[...]` format sites (3341, 7878), the ledger-source loc (3660-3680), and `check_no_demand_mirror`;
  - the selftest pins.

**Interfaces:**
- **Consumes:** every Lua table from Tasks 1-6. The mirror checks compare them.
- **Produces:** `GEN --write` output. Its generated `GGUI.MCT_NAMES` must equal Task 1's hand edit byte for byte.

- [ ] **Step 1: Run `GEN --check > "$S/c0.txt" 2>&1` first** to see the mirrors fail. Expected: findings naming the Warriors of Chaos in `check_flavour_mirror`, `check_race_mirror`, `check_hire_units`, `check_temple_routes`, `check_hall_mirror`. Task 8 clears the hall one.

- [ ] **Step 2: The flavour.** Add `FLAVOURS["_chs"]` immediately before `"_gen"`, in `_skv`'s exact shape:

```python
    "_chs": {
        "culture": "wh_main_chs_chaos", "pics": "chs", "feed": 100,
        "guilds": {
            "brass": "The Doubter",
            "immortals": "The Blood God",
            "daemonsmiths": "The Changer of Ways",
            "khanate": "The Undoer",
            "overseers": "The Plague Lord",
            "slavers": "The Dark Prince",
        },
        "ranks": ["Thrall", "Marauder", "Warrior", "Chosen", "Exalted"],
        "services": {
            "caravan_levy": "The Doubter's Purse",
            "writ_monopoly": "No Tithe to the Gods",
            "long_ledger": "The Faithless Hoard",
            "oathbound_draft": "Blood Oath",
            "hire_immortals": "Hire the Chosen",
            "astragoths_levy": "The Skull Harvest",
            "forge_rite": "Rite of Change",
            "bound_blueprint": "A Secret Foretold",
            "bound_ordnance": "Flames of Change",
            "hobgoblin_eyes": "The Undoer's Eyes",
            "knife_in_dark": "Plans Gone Awry",
            "khans_price": "Everything Undone",
            "lash_the_gangs": "The Grandfather's Patience",
            "raise_ziggurat": "Rot and Regrowth",
            "works_of_zharr": "The Garden Grows",
            "coffle_drive": "The Revel",
            "slave_tithe": "Tithe of Excess",
            "great_coffle": "The Dark Prince's Procession",
        },
        "blurbs": {
            "caravan_levy": "The Doubter's followers keep what other faiths would tithe. "
                            "Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "Warriors marked by the Blood God, who will not leave the field "
                              "while there is blood on it. Adds one unit of Chosen of Khorne "
                              "to an army of your choosing.",
            "bound_blueprint": "Tzeentch shows you a secret before you have earned it. "
                               "Completes the technology you are currently researching, at "
                               "once.",
            "hobgoblin_eyes": "The Undoer's cultists tell you what they saw. Reveals one "
                              "region through the shroud for this turn.",
            "raise_ziggurat": "The Plague Lord's blessing swells whatever it touches. "
                              "Upgrades one of your buildings to its next level at once, and "
                              "free.",
            "slave_tithe": "The Dark Prince's raiders send back your share of the spoils. "
                           "Adds 3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "Necoho, the Doubter, who stands against every god and every cult, his "
                     "own included. He asks nothing of his few followers, and they put their "
                     "trust in their own coin.",
            "immortals": "Khorne, the Blood God, who cares not from where the blood flows, "
                         "only that it flows. Battle is the only worship he hears.",
            "daemonsmiths": "Tzeentch, the Changer of Ways and the Great Conspirator, lord of "
                            "sorcery and fate. Every secret learned is a thread in his plan.",
            "khanate": "Zuvassin, the Undoer, who spoils what others have done and what they "
                       "mean to do. He laughs when his own cults' plans fail as well.",
            "overseers": "Nurgle, the Plague Lord, the Grandfather who tends his garden of "
                         "rot. What he blesses grows, swells and never quite dies.",
            "slavers": "Slaanesh, the Dark Prince of excess, whose followers want everything "
                       "and then more. The Prince's raiders take what they please.",
        },
        "bounties": {
            "brass": ("Spoils for the Faithless",
                      "The Doubter's followers want that town's wealth for themselves. Take "
                      "it intact."),
            "immortals": ("A Skull for the Throne",
                          "A general is said to be the finest warrior in the field. The Blood "
                          "God wants that skull."),
            "daemonsmiths": ("Secrets for the Changer",
                             "Whatever that place knows, Tzeentch would know it too. Take it "
                             "and its scholars."),
            "khanate": ("Undo Their Plans",
                        "Someone's plans are going too well. The Undoer wants them ruined, "
                        "and the planner with them."),
            "overseers": ("A New Garden",
                          "Take it whole. The Plague Lord wants it to rot slowly, not burn."),
            "slavers": ("Take Everything",
                        "Sack it. The Dark Prince's raiders want every pleasure that place "
                        "holds."),
        },
    },
```

Before writing the blurbs' numbers, read the `_skv` blurbs and the rows they describe: if `caravan_levy` or `slave_tithe` pay other amounts than 2,500 and 3,000 today, use today's numbers. The hire blurb names the unit by CA's display name of `wh3_dlc20_chs_inf_chosen_mkho` (Rulings).

- [ ] **Step 3: The other text tables.**

`POOL_NAMES["_chs"]`, positional, in the pool order `alms_and_bribes` .. `scorched_earth`:

```python
    "_chs": ["Offerings to Chaos", "Faithless Sellswords", "A Doubter's Loan",
             "Tribute of the Mines", "Nothing Owed to Gods", "Bought Silence",
             "The Blood Trail", "Blooded in the Pits", "Banner of Skulls", "Rage Over Wounds",
             "Veterans of Slaughter", "Khorne's Regard", "Tzeentch's Ward", "Drink the Winds",
             "Warpforged Blades", "Hellcannon Crews", "The Great Conspiracy",
             "Bolts of Change", "Sabotaged Watch", "Tried in Ruin", "A Spoiler's Lessons",
             "Sow Discord", "Cults of the Undoer", "Spoiled Harvests", "Bountiful Rot",
             "The Rotting March", "Blightkings' Watch", "Walls of Filth",
             "The Grandfather's Builders", "The Garden of Nurgle", "Raids of Excess",
             "Spoils of Excess", "Thralls for the Warbands", "Pits of Delight",
             "The Great Revel", "Despoil Their Pleasures"],
```

`TEMPLE_NAMES["_chs"]`, in the order `hashut_blessing, forge_sermons, temple_tithe, zeal, purge_unclean, anathema, holy_war, miracle, consecration`:

```python
    "_chs": ["The Gods' Regard", "Sermons of Ruin", "The Dark Tithe", "Fervour of the Faithful",
             "Cull the Weak", "Curse of the Gods", "The Incursion", "Flesh Remade",
             "The Star of Chaos"],
```

`TEMPLE_FLAVOUR["_chs"]`:

```python
    "_chs": ("The Undivided",
             "The worship of the Four as one power, under the eight-pointed star. The warbands "
             "that answer the Everchosen's call fight in its name.",
             ("The Gods Demand",
              "A general of the Empire, Kislev or Cathay leads an army in the open. The "
              "Undivided want that general's skull. Take it."),
             "You earn Devotion from provinces where Chaos corruption spreads, from battles won "
             "against the Empire, Kislev and Cathay, from your unmarked Sorcerers' deeds, and "
             "from their own buildings.",
             "corrupted provinces, wins over the Empire, Kislev and Cathay"),
```

`RECRUIT_SAYS["_chs"]` (the Doubter and the Undoer have none, so `recruit_sentence` returns ""):

```python
    "_chs": {"immortals": "units and characters with the Mark of Khorne",
             "daemonsmiths": "units and characters with the Mark of Tzeentch",
             "overseers": "units and characters with the Mark of Nurgle, and the Glottkin's "
                          "host",
             "slavers": "units and characters with the Mark of Slaanesh",
             "temple": "unmarked units and characters"},
```

`RACE_TEXT["_chs"]`, before `"_gen"`:

```python
    "_chs": {"label": "Warriors of Chaos",
             "earn": "Spending Souls on a god's gifts pays that god: one Devotion for every "
                     "25 Souls.",
             "twist": ("The Fickle Gods", "Devotion fades half again as fast when you stop "
                       "feeding a god, and a demand you answer is worth half again as much.")},
```

- [ ] **Step 4: The race tables and their mirrors.**
- `TEMPLE_ROUTES`: the Skaven's `"taint": True` becomes `"taint": "wh3_main_corruption_skaven"`, and add `"wh_main_chs_chaos": {"taint": "wh3_main_corruption_chaos", "holy": ["wh_main_emp_empire", "wh3_main_ksl_kislev", "wh3_main_cth_cathay"], "priests": ["wh_main_chs_chaos_sorcerer_fire", "wh_main_chs_chaos_sorcerer_death", "wh_main_chs_chaos_sorcerer_metal", "wh_dlc07_chs_chaos_sorcerer_shadow"]}`. Read `check_temple_routes` first: if it compares `taint` as a boolean, compare the string.
- `EARN_ROUTES["gifts"] = None` (no single guild) and `EARN_OF["wh_main_chs_chaos"] = "gifts"`.
- `check_race_mirror`: after the `{guild = "..."}` findall, add the by-pool routes, so `got` holds `gifts: None`:

```python
    got.update((k, None) for k in re.findall(r'(\w+)\s*=\s*\{per\s*=\s*\d+,\s*by_pool\s*=\s*true\}',
                                              m.group(1)))
```

- The two format sites (3341 and 7878) read `EARN_ROUTES[EARN_OF[culture]]`. Give each a guard so a by-pool route formats with no guild:

```python
    _g = EARN_ROUTES[EARN_OF[culture]]
    ... R["earn"].format(g=short_name(_g, tag) if _g else "")
```

  (At 7878 the variable is `F["culture"]`.) The `_chs` earn text has no `{g}`.
- `TWISTS["wh_main_chs_chaos"] = {"rate_decay": 150, "demand_reward": 150}`.
- `NO_DEMAND`, beside `TWISTS`, and its mirror:

```python
# THE DOUBTER ASKS NOTHING, mirrored from GG.NO_DEMAND (woc spec §4.4).
NO_DEMAND = {"wh_main_chs_chaos": ["brass"]}


def check_no_demand_mirror(lua=None):
    """GG.NO_DEMAND must be NO_DEMAND: the Help page says which god never asks."""
    if lua is None:
        lua = io.open(MODEL_LUA, encoding="utf-8").read()
    m = re.search(r"^GG\.NO_DEMAND = \{(.*?)\}\}", lua, re.S | re.M)
    got = {}
    if m:
        for culture, body in re.findall(r'\["([^"]+)"\]\s*=\s*\{([^}]*)', m.group(1) + "}"):
            got[culture] = sorted(re.findall(r"(\w+)\s*=\s*true", body))
    want = dict((c, sorted(g)) for c, g in NO_DEMAND.items())
    return [] if got == want else ["GG.NO_DEMAND is %r and this file says %r" % (got, want)]
```

  Hook it into `--check` beside `check_race_mirror` (`grep -n "check_race_mirror()" tools/gen_great_guilds.py`). Mutation-check it: change `brass = true` to `khanate = true` in a copy of the Lua passed as `lua`, see the finding, and revert.
- The Help page that names the twist (`grep -n "R\[\"twist\"\]" tools/gen_great_guilds.py`) gains one line for a race in `NO_DEMAND`: `"-The %s never makes a demand." % short_name(g, tag)` for each guild listed. Re-run `check_help_pages`: the page must stay within 21 lines; if it does not, fold the line into the twist sentence instead.
- Ledger loc (3660-3680): add `("src_gifts", "Souls given")` beside `("src_undercity", ...)`. The Log line `derpy_gg_log_earn_gifts_chs` comes from the route loop; `check_race_mirror` reports it if missing.

- [ ] **Step 5: The services.** Append after `breeding_season`:

```python
    # THE WARRIORS OF CHAOS' RACE SERVICES (2026-10-12), AFTER the Skaven rows: cooldowns
    # are saved by position.
    # Tithe of Souls: CA's own narrative payload (500, wh3_dlc20_souls_other). The Eye Turns:
    # CA's Eye of the Gods pool takes gifts_of_chaos (Ruling 7). The Skull Throne: CA's own
    # pairs at faction_to_force_own, inside 1.5x vanilla's largest.
    {"key": "soul_tithe", "guild": "slavers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "resource", "race": "wh_main_chs_chaos", "resource": "wh3_dlc20_chs_souls",
     "factor": "wh3_dlc20_souls_other", "value": 500, "name": "Tithe of Souls",
     "text": "Adds {value} Souls."},
    {"key": "eye_turns", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "resource", "race": "wh_main_chs_chaos",
     "resource": "wh3_dlc20_chs_eye_of_the_gods", "factor": "gifts_of_chaos", "value": 15,
     "name": "The Eye Turns", "text": "Adds {value} to the Eye of the Gods."},
    {"key": "skull_throne", "guild": "immortals", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "race": "wh_main_chs_chaos",
     "name": "Skulls for the Skull Throne",
     "effects": [("wh_main_effect_force_stat_melee_attack", "faction_to_force_own", 6),
                 ("wh3_dlc20_effect_xp_gain_all_units", "faction_to_force_own", 25)],
     "text": '{v0:+d} melee attack and {v1:+d}% experience from battle in all your armies for {turns} turns.'},
```

Match the existing race rows' exact key set (`grep -n '"key": "food_tithe"' -A3` and `breeding_season`). Keep `RACE_PRICE`, which these values satisfy.

Overrides, each a dict entry inside the service's `for_tag`:
- `alms_and_bribes`: `"_chs": <a copy of the "" override>` (+5 Chaos corruption; the Undivided earn from it).
- `purge_unclean` and `consecration`: the loop at about 657 becomes `for _t in ("_skv", "_chs"): _s["for_tag"][_t] = _s["for_tag"][""]`.
- `hashut_blessing`: `"_chs": {"effects": [("wh_main_effect_force_stat_ward_save", "force_to_force_own", 10)], "text": '{v0:+d}% ward save for the army you select for {turns} turns.'}` (the Kislev and Dark Elf pair and value).
- `zeal`: `"_chs": {"effects": [("wh_main_effect_force_stat_melee_attack", "faction_to_force_own", 4), ("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6)], "text": '{v0:+d} melee attack and {v1:+d} leadership in all your armies for {turns} turns.'}` (the Dwarf and Dark Elf pair).
- `holy_war`: `"_chs"` the same two effects and text as `zeal`'s `_chs` (the Dark Elf shape, whose holy war is the same pair).

`RACE_UNWANTED_EFFECTS["_chs"] = {"wh3_main_effect_corruption_reduction_events": "the Undivided earn from Chaos corruption; reducing it works against their own route"}`.

`FLAVOUR_WORDS_ALLOWED["_chs"] = ("Daemon",)` - the Changer's and the Undivided's prose name daemons and Daemon Princes. Add `"slave"` only if a `_chs` string really needs it; none above does.

- [ ] **Step 6: The temple lore.**

```python
# THE UNDIVIDED (woc spec §6): the Sorcerers are its priests, so the Winds ladder, like the
# Chaos Dwarfs' and the Skaven's.
    "_chs": dict(_WINDS_LORE),
```

in `TEMPLE_LORE`, and in `_TEMPLE_HALL_SEAT`:

```python
    "_chs": ("wh3_main_effect_corruption_chaos_buildings", "region_to_region_own",
             [2, 4, 6], "Undivided corruption +%d in this settlement",
             ("wh3_main_effect_corruption_chaos_events", "faction_to_province_own", 2),
             "Undivided corruption %+d in every province"),
```

- [ ] **Step 7: The word pass.** After `RACE_TEXT`:

```python
# THE DARK GODS (woc spec §1): the Warriors of Chaos have gods, not guilds, and Devotion,
# not Reputation. Every loc line of that flavour passes through these, in order, after it
# is built - so no template above needs a second copy. The longest phrase first.
CHS_WORDS = [("The Great Guilds", "The Dark Gods"), ("Guild Halls", "Shrines of the Gods"),
             ("Foremost", "Champion"), ("Reputation", "Devotion"), ("reputation", "devotion"),
             ("Guilds", "Gods"), ("guilds", "gods"), ("Guild", "God"), ("guild", "god")]
_CHS_KEY = re.compile(r"_chs(_|$)")


def chs_words(text):
    for a, b in CHS_WORDS:
        text = text.replace(a, b)
    return text


def check_chs_words(tables=None):
    """No Warriors of Chaos line may say guild or Reputation, and no other line may have
    been touched by the pass (a key outside _chs that says God where it said Guild)."""
    t = build() if tables is None else tables
    out = []
    for r in t["loc"]:
        if _CHS_KEY.search(r["key"]):
            low = r["text"].lower()
            for w in ("guild", "reputation", "foremost"):
                if w in low:
                    out.append("%s still says %r" % (r["key"], w))
    return out
```

In `build()`, after the last `extend` and before `return out`:

```python
    # THE DARK GODS' WORDS (woc spec §1), on every Warriors of Chaos line wherever it was built.
    for r in out.get("loc", []):
        if _CHS_KEY.search(r["key"]):
            r["text"] = chs_words(r["text"])
```

Check the table name with `grep -n '"loc"' tools/gen_great_guilds.py | head`. If the bundle titles live in the DB tables' `localised_title` too, apply the same pass to `effect_bundles` rows whose `key` matches `_CHS_KEY`, since `check_effect_bundle_loc` compares them. Hook `check_chs_words` into `--check`. Its selftest: feed it `{"loc": [{"key": "derpy_gg_x_chs", "text": "a guild"}]}` and assert one finding, and `{"loc": [{"key": "derpy_gg_x_skv", "text": "a guild"}]}` and assert none.

- [ ] **Step 8: Selftest pins.** `GEN --selftest > "$S/st.txt" 2>&1`. Each failing pin names a count; move it to the counted value. Known sites:
  - `:7656`, the FLAVOURS order list, with `"_chs"` before `"_gen"`;
  - the race-service count (32 becomes 35);
  - the event-feed row count (the formula adapts);
  - `:8006`, the `(tag, set)` tuple, adding `("_chs", "wh_main_bas_chs")`;
  - `:7947`, the tag tuple, if the Warriors of Chaos belong in it (read what it asserts);
  - `:8103`, `:8128`, `:8144`, `:8186`, the temple-lore expectations, adding `_chs` entries built from Step 6's values;
  - the hall-set count `len(_hs)` (9 becomes 10) - Task 8.

- [ ] **Step 9: Write and verify.**
  1. Copy `$U`, `zzz_derpy_guilds_bounty_data.lua` and `Modding Files/source/great_guilds/*.tsv` to `$S/pre_write/`.
  2. `GEN --write > "$S/w.txt" 2>&1`.
  3. Diff `$U` against its copy with `\r` stripped. Expected: no difference (the MCT names block equals Task 1's hand edit).
  4. **The other nine races are unchanged:** for each TSV, `diff <(grep -v "_chs" "$S/pre_write/<t>.tsv") <(grep -v "_chs" "Modding Files/source/great_guilds/<t>.tsv")`. Expected: no difference in any table, except the rows whose ONLY change is the Skaven `taint` mirror, which ships no TSV row. A changed non-`_chs` row is a regression: find it before going on.
  5. `GEN --selftest`, `GEN --check`. Expected: green, except hall and art findings, which belong to Tasks 8 and 9.
  6. `H`, `BH`. Expected: green.
  7. Read ten `_chs` loc lines at random (`grep "_chs" "Modding Files/source/great_guilds/loc.tsv" | shuf -n 10`) for grammar the word pass broke ("a god hall", doubled words). Fix the source sentence or add a longer phrase to `CHS_WORDS` ahead of the short one.

---

### Task 8: The Warriors of Chaos halls

**Files:**
- Modify `tools/gen_great_guilds.py`: `HALL_TAGS` (2259) with `"_chs"` last; `HALL_RACES["_chs"]` (after `_skv`, 2560); `HALL_ICON`'s inline tag list (2463); `HALL_EXTRA` (2304, five `_chs` entries, Ruling 3); the selftest hall pins and a new `_chs` hall pin after the `_skv` corruption pin (around 8117).

**Interfaces:**
- **Consumes:** `GG.HALL_TAGS["_chs"]` (Task 1), `TEMPLE_LORE["_chs"]` (Task 7).
- **Produces:** 7 hall chains, 21 levels, a Seat bundle and 7 icon stems for `_chs`.

- [ ] **Step 1: Run `GG1(check_hall_mirror)`.** Expected: `_chs` in the Lua `GG.HALL_TAGS` and not in `HALL_TAGS`.
- [ ] **Step 2: Implement.**

```python
    "_chs": {"set": "wh_main_bas_chs",
             # The Glottkin's own set (still the Warriors of Chaos).
             "extra_sets": ["wh3_dlc29_woc_glottkin"],
             "nouns": ("Idol", "Altar", "Monolith"),
             "units": {"brass": None,
                       "immortals": None,
                       "daemonsmiths": None,
                       "khanate": None,
                       "overseers": None,
                       "slavers": None,
                       "temple": None},
             "temple_nouns": ("Shrine of the Undivided", "Temple of the Undivided",
                              "Monolith of the Undivided")},
```

`HALL_ICON`'s inline tag list gains `"_chs"`; `HALL_TAGS` gains `"_chs"` last.

`HALL_EXTRA` gains the five second effects of Ruling 3. Its text is formatted with the SIGNED value (`extra[3] % extra[2][n]`, 2979), so the Undoer's line prints "-10%":

```python
    # THE WARRIORS OF CHAOS RECRUIT FROM POOLS, NOT BUILDINGS (woc Ruling 3): no building of
    # theirs trains a unit, so a god's hall widens that god's Marauder pool - CA's own Dark
    # Fortress pair, 1-2 in vanilla - and the Undoer's makes enemy heroes fail there, CA's
    # own Towers values.
    ("immortals", "_chs"): ("wh3_dlc20_effect_province_merc_capacity_marauders_kho",
                            "province_to_province_own_unseen", [1, 2, 3],
                            "Marauders of Khorne you may recruit in this province +%d"),
    ("overseers", "_chs"): ("wh3_dlc20_effect_province_merc_capacity_marauders_nur",
                            "province_to_province_own_unseen", [1, 2, 3],
                            "Marauders of Nurgle you may recruit in this province +%d"),
    ("slavers", "_chs"): ("wh3_dlc20_effect_province_merc_capacity_marauders_sla",
                          "province_to_province_own_unseen", [1, 2, 3],
                          "Marauders of Slaanesh you may recruit in this province +%d"),
    ("daemonsmiths", "_chs"): ("wh3_dlc20_effect_province_merc_capacity_marauders_tze",
                               "province_to_province_own_unseen", [1, 2, 3],
                               "Marauders of Tzeentch you may recruit in this province +%d"),
    ("khanate", "_chs"): ("wh_main_effect_agent_action_success_chance_enemy_building",
                          "region_to_character_enemy", [-10, -15, -20],
                          "Enemy heroes' actions here: success chance %d%%"),
```

"Marauders of Khorne" and its three siblings are CA's own display names (`land_units_onscreen_name_wh3_dlc20_chs_inf_chaos_marauders_mkho` and siblings, read 2026-10-12). `check_effect_signs.py` will list the Undoer's row as a penalty-signed effect; that is the bonus side (Ruling 3).

- [ ] **Step 3: Seven unit-less halls, and the pin that reads them.** This race is the first whose every hall trains no unit (Ruling 3). The generator's unit reads are `None`-safe (`hall_desc` 2967, `_dlc_problems` 6811, `check_recruit_routes` 5256, the `firsts` loop in `hall_tables`), and `_unit_level` is never called for a `None` unit. `_cai_donor` (3109) treats `immortals`, `daemonsmiths` and `khanate` as `military` and looks for chains that train the hall's unit; with `None` it finds none and falls back to the race's hall donor. If `GEN --selftest` or `GG1(check_halls)` reports any `_chs` hall there, guard the read as `unit and unit in trains.get(c, ())` and ledger it.

  Add the pin, after the `_skv` corruption assertion in the selftest (same scope as `hj` and `ht2`):

```python
    # A WARRIORS OF CHAOS HALL TRAINS NOTHING (woc Ruling 3): a god's hall widens that
    # god's Marauder pool and the Undoer's makes enemy heroes fail. Read off the BUILT rows,
    # scope included, at all three levels.
    want_chs = {
        "immortals": ("wh3_dlc20_effect_province_merc_capacity_marauders_kho",
                      "province_to_province_own_unseen", [1, 2, 3]),
        "overseers": ("wh3_dlc20_effect_province_merc_capacity_marauders_nur",
                      "province_to_province_own_unseen", [1, 2, 3]),
        "slavers": ("wh3_dlc20_effect_province_merc_capacity_marauders_sla",
                    "province_to_province_own_unseen", [1, 2, 3]),
        "daemonsmiths": ("wh3_dlc20_effect_province_merc_capacity_marauders_tze",
                         "province_to_province_own_unseen", [1, 2, 3]),
        "khanate": ("wh_main_effect_agent_action_success_chance_enemy_building",
                    "region_to_character_enemy", [-10, -15, -20]),
    }
    for g, (ek, sc, vals) in want_chs.items():
        for n in range(3):
            rows = hj[hall_key(g, n, "_chs")]
            got = [r for r in rows if r["effect"] == ek]
            assert (len(got) == 1 and got[0]["effect_scope"] == sc
                    and got[0]["value"] == str(vals[n])), (g, n, rows)
    chs_halls = {hall_key(g, n, "_chs") for g in GUILDS for n in range(3)}
    assert not [r for r in ht2["building_units_allowed"] if r["building"] in chs_halls], \
        "a Warriors of Chaos hall trains a unit"
```

  Watch it fail once: comment out the `("khanate", "_chs")` entry of `HALL_EXTRA`, run `GEN --selftest`, see `('khanate', 0, ...)` named, restore it. (The mutation runner mutates Lua only, so this is where the Undoer's hall is proved covered.)
- [ ] **Step 4: Run `GEN --selftest` and move the hall pins.** `14 * len(HALL_TAGS)` and `7 * len(HALL_TAGS)` adapt; the literal `(tag, set)` and seat lists fail by name; `len(_hs) == 9` becomes 10. Then re-run Task 6's `GG1(check_recruit_routes)` and `GG1(check_building_theme)`. Expected: green.
- [ ] **Step 5: `GEN --check`.** Expected: exit 0, except art findings (Task 9).

---

### Task 9: Art (crests, grounds, hall icons, bundle icons)

**Files:**
- Modify `tools/make_guild_icons.py` (LF): `ICONS` (after the Skaven stems, 144), an explicit `HALL_ICONS.update` after the stage-2 loop (176-178, which does NOT gain `_chs`), `TAB_FRAME` (360), the selftest tag loop (511), and the `len(HALL_ICONS)` pin (63 becomes 70).
- Create `$S/stage_chs_watermarks.py` (scratchpad, one-off) and its four outputs in `Modding Files/source/guild_icons/`.
- Modify `tools/make_guild_backgrounds.py` (LF): `CA_ART`, `CA_BACKGROUNDS`, and the selftest's per-race rule (412-428).

**Interfaces:**
- **Produces:** `ui/campaign ui/derpy_gg_icons/<guild>_chs.png` (7 plus `crest_chs`), `ui/campaign ui/derpy_gg_bg/<guild>_chs.png` (7), `ui/buildings/icons/derpy_gg_hall_<guild>_chs.png` (7).

- [ ] **Step 1: Add `"_chs"` to the selftest tag loop (511) only; run `py tools/make_guild_icons.py --selftest`.** Expected: FAIL, "no icon ships as brass_chs". Do NOT add `_chs` to the stage-2 loop at 176: it derives a hall icon from the card stem, and this race's cards are god symbols, not buildings (Ruling 15).
- [ ] **Step 2a: Stage the Four's watermarks.** `fetch()` reads only `ui/buildings/icons/` in ui.pack; the watermarks live in `ui/skins/default/` in ui2.pack and are 429-604px wide. Write with the Write tool:

```python
"""Stage CA's four tech-tree watermarks as 74px square source icons. One-off (woc Ruling 15)."""
import io, os, sys
ROOT = r"G:\Modding for resources"
sys.path.insert(0, os.path.join(ROOT, "tools"))
import read_pack_index as rpi
import read_vanilla_loc as rvl
from PIL import Image

UI2 = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\ui2.pack"
SRC = os.path.join(ROOT, "Modding Files", "source", "guild_icons")
for god in ("khorne", "nurgle", "slaanesh", "tzeentch"):
    want = "ui/skins/default/tech_watermark_%s.png" % god
    hits = [h for h in rpi.read(UI2, want) if h[0].lower() == want]
    assert hits, want + " is not in ui2.pack"
    _path, comp, data = hits[0]
    im = Image.open(io.BytesIO(rvl._decompress(data) if comp else data)).convert("RGBA")
    im = im.crop(im.split()[3].getbbox())          # the mark only, no empty margin
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    out = os.path.join(SRC, "tech_watermark_%s.png" % god)
    sq.resize((74, 74), Image.LANCZOS).save(out)
    print(out, im.size, "->", (74, 74))
```

Run `py "$S/stage_chs_watermarks.py"`. Expected: four lines. Read one of the four PNGs with the Read tool: a single mark, centred, no box.

- [ ] **Step 2: `ICONS`.** Measure each stem flat (one colour, as the temple's were) before keeping it:

```python
    # THE WARRIORS OF CHAOS (2026-10-12), CA's own art.
    # The Four: CA's tech-tree watermarks, staged by hand (Step 2a) - the mark-of-chaos icons
    # are coloured orbs, 2-35% flat. The rest are CA's own building icons, each 97-100% flat.
    "tech_watermark_khorne": "immortals_chs",
    "tech_watermark_nurgle": "overseers_chs",
    "tech_watermark_slaanesh": "slavers_chs",
    "tech_watermark_tzeentch": "daemonsmiths_chs",
    "chaos_worship": "temple_chs",
    "wh3_main_special_standing_stones": "brass_chs",
    "wh3_dlc27_nor_trap_core_sabotage": "khanate_chs",
    "chaos_dark_fortress": "crest_chs",
```

After the stage-2 loop (and before `_RETIRED`), the hall icons, written out because they are buildings and the cards are not:

```python
# THE WARRIORS OF CHAOS' HALLS (2026-10-12): their cards are god symbols, so each hall takes
# CA's own building icon for its trade instead of its card's stem (woc Ruling 15).
HALL_ICONS.update({
    "chaos_worship": "derpy_gg_hall_temple_chs",
    "chaos_growth": "derpy_gg_hall_overseers_chs",
    "chaos_income": "derpy_gg_hall_brass_chs",
    "chaos_warriors": "derpy_gg_hall_immortals_chs",
    "chaos_magic": "derpy_gg_hall_daemonsmiths_chs",
    "chaos_vassals": "derpy_gg_hall_slavers_chs",
    "chaos_towers": "derpy_gg_hall_khanate_chs",
})
```

The selftest pin `len(HALL_ICONS) == 63 - 7 * len(HALL_LEVEL_ICON_TAGS)` becomes `70 - ...`.

`TAB_FRAME["_chs"] = "chaos_cat_recruitment"`.

- [ ] **Step 3: Grounds, one CA painting per god.**

```python
    # THE WARRIORS OF CHAOS (2026-10-12): one CA painting per god where CA has one - the
    # four gods' own loading screens and the Daemons' for the Undivided - and two windows of
    # the Warriors' own for the renegades, who have no art.
    "chs": "ui/loading_ui/load_images/campaign_chaos1.png",
    "chs_kho": "ui/loading_ui/load_images/campaign_khorne1.png",
    "chs_nur": "ui/loading_ui/load_images/campaign_nurgle1.png",
    "chs_sla": "ui/loading_ui/load_images/campaign_slaanesh1.png",
    "chs_tze": "ui/loading_ui/load_images/campaign_tzeentch1.png",
    "chs_dae": "ui/loading_ui/load_images/campaign_daemons1.png",
```

in `CA_ART`, and in `CA_BACKGROUNDS` (windows chosen in Step 5):

```python
    "immortals_chs": ("chs_kho", 7), "overseers_chs": ("chs_nur", 7),
    "slavers_chs": ("chs_sla", 7), "daemonsmiths_chs": ("chs_tze", 7),
    "temple_chs": ("chs_dae", 7), "brass_chs": ("chs", 1), "khanate_chs": ("chs", 3),
```

The selftest's per-race rule assumes one painting per race. Replace the loop head with:

```python
    # A RACE WHOSE GODS EACH LEND A PAINTING (2026-10-12): the Warriors of Chaos draw from six
    # CA pictures, so their seven grounds are checked together, by tag, not by picture.
    LENT = ("chs_kho", "chs_nur", "chs_sla", "chs_tze", "chs_dae")
    chs = dict((n[:-4], (r, w)) for n, (r, w) in CA_BACKGROUNDS.items() if n.endswith("_chs"))
    assert sorted(chs) == sorted(list(BACKGROUNDS) + ["temple"]), sorted(chs)
    assert len(set(chs.values())) == len(chs), "two Warriors of Chaos grounds share a window"
    for race in CA_ART:
        if race in LENT or race == "chs":
            continue
```

keeping the rest of the loop body as it is.

- [ ] **Step 4: Build and check.** `py tools/make_guild_icons.py`, `PYTHONIOENCODING=utf-8 py tools/make_guild_backgrounds.py`, `--check` on both, then `py tools/make_guild_bundle_icons.py` and its `--check`. Read three grounds and three crests with the Read tool. Expected: every check green; every ground at or under the measured ceiling.
- [ ] **Step 5: Choose the windows.** Render all seven windows of each painting (`make_guild_backgrounds.py` writes them; or crop with PIL into `$S/chs_windows/`) and read them. Pick, per god, the window that shows the god's own figure or host and no logo or black band; for the renegades, two windows of `campaign_chaos1` that differ. Update `CA_BACKGROUNDS`, rebuild, and ledger the choice.
- [ ] **Step 6: `GEN --selftest`, `GEN --check`.** Expected: green.

---

### Task 10: The Warriors of Chaos panel frame

**Files:**
- Modify `tools/gen_guilds_ui.py` (CRLF): `FRAMES["_chs"]` (after `_skv`, 1205), `RANK_STATS_PAD["_chs"]` (757).
- Modify `$U`: `GGUI.FRAME["_chs"]` (replacing Task 1's copy), `GGUI.HALLS_IN_HEADER` if the preview shows room.
- Modify `tools/import_great_guilds.py:41` (CRLF): the UI race tuple gains `"chs"`.

**Interfaces:**
- **Consumes:** the flavour (Task 7) and the art (Task 9).
- **Produces:** `derpy_gg_panel_chs.twui.xml`, `derpy_gg_card_chs.twui.xml`.

- [ ] **Step 1: The brief.** Per `docs/CUSTOM_UI.md` "Design direction", the reference is CA's Path to Glory panel (`ui/campaign ui/character_details_panel_path_to_glory.twui.xml`, the Path to Glory tab of a Warriors of Chaos lord), with the Gifts of Chaos panel (`ui/campaign ui/chaos_gifts.twui.xml`) for the holder and the Souls bar. Take a screenshot of both in game, or ask the author for one. Open its `.twui.xml` and note the plates, colours and type sizes. Measure each candidate file's size and border with PIL:

The files, sizes and measured opaque bands are Ruling 14's table. Re-measure each with PIL before trusting a number: the card's bottom slice must keep the hanging spikes (rows to 190), and the track draws at native height (opening only 7 rows).

Margins come from the measured border widths, recorded in each entry's comment as the other races' are. `heat` and `rim` use `_GLOW` / `_TUTGLOW` as `_skv` does, tinted with a colour read from `db/ui_colours_tables` (the way `[[col:]]` resolves), never picked by eye.
- [ ] **Step 2: Implement `FRAMES["_chs"]`** with `_skv`'s exact key set (`card`, `card_extra`, `heat`, `rim`, `holder`, `cost`, `rank`, `rank_tx`, `rank_ty`, `gbar`, `tab`, `track`, `fill`), every value from Step 1's measured files. Mirror it in `GGUI.FRAME["_chs"]`. Start with `RANK_STATS_PAD["_chs"] = 66`.
- [ ] **Step 3: `UIGEN --check`, `UIGEN --selftest`.** Expected: green (`check_frame_files` requires the shared hierarchy and no Chaos Dwarf art; `check_frame_mirror` requires the Lua to match). Then `UIGEN --write`, `py tools/check_guilds_ui.py`, and `H`.
- [ ] **Step 4: Render and judge.**

```
py tools/preview_guilds_panel.py --flavour chs
py tools/preview_guilds_panel.py --flavour chs --page 7
py tools/preview_guilds_panel.py --flavour chs --help-page 2
py tools/preview_guilds_panel.py --flavour chs --help-page 7
```

Expected: exit 0, no `TOO WIDE`, no `LOW CONTRAST`. Read `gg_guilds_chs.png`, `gg_guilds_chs_g7.png`, `gg_standings_chs.png` and `gg_court_chs.png` and compare them with the reference:
- does the card read as a Warriors of Chaos plate, not a Skaven one recoloured?
- is the header's figure clear of its edge? (tune `RANK_STATS_PAD`)
- do the button bar's end ornaments sit outside the end buttons?
- does the title read "The Dark Gods" and the tab "Gods"?
- does the Halls figure fit in the header? Add `_chs` to `GGUI.HALLS_IN_HEADER` only if it does.

Fix and render again until each holds. The first pass is never done.

---

### Task 11: Mutation coverage

**Files:**
- Modify `tools/mutate_guilds.py` (LF).

- [ ] **Step 1: Re-anchor.** `py tools/mutate_guilds.py --selftest`. Re-aim each stale anchor at the moved code with the same intent. Expect the `GG.RIVALS[...]` reads, `race_earn`'s carry lines, `temple_counts`' taint line and `roll_demand`'s pool loop.
- [ ] **Step 2: One mutant per new rule.** Each is `(description, M, anchor, replacement)`, the anchor matching once (read the exact text first):

| Description | Anchor | Replacement |
|---|---|---|
| "a race's rivals ignored" | `local t = GG.RIVALS_RACE[GG.culture_of(faction) or ""] or GG.RIVALS` | `local t = GG.RIVALS` |
| "Khorne's rival is Tzeentch again" | `immortals = "slavers",      slavers      = "immortals",` | `immortals = "daemonsmiths", slavers      = "immortals",` |
| "a price reads the global rival" | `local rival = GG.rival_of(faction, svc.guild)` | `local rival = GG.RIVALS[svc.guild]` |
| "the demand line reads the global rival" (UI) | `GG.rival_of(faction, d.guild)) .. ")"` | `GG.RIVALS[d.guild]) .. ")"` |
| "every god shares one Souls remainder" | `local sub = r.by_pool and ("_" .. g) or ""` | `local sub = ""` |
| "a gift pays the route's guild, not the pool's" | `if r.by_pool then g = guild end` | `if false then g = guild end` |
| "the pool listener names no god" | `GG.race_earn(name, route, amount, GG.POOL_GUILD[key])` | `GG.race_earn(name, route, amount)` |
| "taint reads Skaven corruption for everyone" | `resource(r.taint)` | `resource("wh3_main_corruption_skaven")` |
| "the Doubter asks after all" | `if (GG.get(faction, g)) > 0 and not quiet[g] then` | `if (GG.get(faction, g)) > 0 then` |
| "the Fickle Gods forget the decay" | `{rate_decay = 150, demand_reward = 150}` | `{demand_reward = 150}` |
| "an unmarked Sorcerer pays the Undoer" | `priests = {"wh_main_chs_chaos_sorcerer_fire", "wh_main_chs_chaos_sorcerer_death",` | `priests = {"wh_main_chs_chaos_sorcerer_death",` |
| "Khorne's marked units pay the Undivided" | `{"immortals", key = "_mkho"},     -- the Mark of Khorne` | `{"temple", key = "_mkho"},     -- the Mark of Khorne` |
| "an upgrade pays every race" | `if not GG.UPGRADE_PAYS[GG.culture_of(name) or ""] then return end` | `if false then return end` |

Every replacement must parse; `--selftest` proves it. The hall effects are DB rows the Lua harnesses never see; the Undoer's hall is proved covered by Task 8 Step 3's watched failure instead.
- [ ] **Step 3: The full run, in the background, to a file.** `PYTHONIOENCODING=utf-8 py tools/mutate_guilds.py > "$S/mutate_chs.txt" 2>&1`. Expected: exit 0, every mutant CAUGHT, no SURVIVED, no STALE. A survivor is a missing assertion: add it to the harness and re-run; never delete the mutant.
- [ ] **Step 4: The restore check.** Touch every generated file, `GEN --write`, then `H` and `BH`. Expected: green, and `$M` byte-identical to its state before the run (`md5sum` before and after).

---

### Task 12: Build, verify, deploy, write down

**Files:**
- The pack: `Modding Files/Modpacks/derpy_great_guilds.pack`, deployed to the Workshop folder.
- Create `docs/sessions/HANDOFF_20261012_GUILDS_WARRIORS_OF_CHAOS.md`.
- Modify `docs/SESSION_INDEX.md` (one line), `docs/MY_MODS.md` (ten races, its counts), `docs/knowledge-base/systems.md`, the spec (§14 "As shipped").

- [ ] **Step 1: The snapshot list** (taken before Task 1): `$M`, `$U`, `zzz_derpy_guilds_ai.lua`, `zzz_derpy_guilds_bounty_data.lua`, the MCT file, `tools/gen_great_guilds.py`, `tools/gen_guilds_ui.py`, `tools/make_guild_icons.py`, `tools/make_guild_backgrounds.py`, `tools/make_guild_bundle_icons.py`, `tools/import_great_guilds.py`, `tools/mutate_guilds.py`, `tools/_guilds_harness.lua`, `tools/_guilds_bounty_harness.lua`, `Modding Files/source/great_guilds/`.
- [ ] **Step 2: All checks.**
  - `GEN --selftest`, `GEN --check`, `UIGEN --check`, `py tools/check_guilds_ui.py`;
  - `H`, `BH`;
  - `LUAC` on all five guild Lua files;
  - `py tools/check_lua_api.py` on the three hand-written Lua files;
  - `py tools/check_lua_literal_left.py "$M"`;
  - `py tools/check_lua_undeclared.py`, compared with the pre-plan findings;
  - `py tools/check_effect_bundle_loc.py` and `py tools/check_effect_signs.py` on the built pack (Step 4).

  Expected: all clean; `check_lua_undeclared` returns the same findings as before.
- [ ] **Step 3: The share table.** Run the building share script the Skaven handoff used (`$S/shares.py`, or recreate it from `docs/sessions/HANDOFF_20261005_GUILDS_SKAVEN.md` "Share of building reputation") and save the `_chs` rows. List `GG.BOUNTY_BUILDINGS["_chs"]` per god from the regenerated bounty data, including which gods have no build job.
- [ ] **Step 4: Build.**
  1. RPFM is up: `curl -s -m 4 http://127.0.0.1:45127/sessions`. Connection refused: stop and tell the author.
  2. Back up the Modpacks copy and the Workshop copy to `Modding Files/Backup/guilds_pre_chs_20261012/`.
  3. `py tools/import_great_guilds.py --check`, then `py tools/import_great_guilds.py` (background, to a file). Expected: "saved pack verified - every table holds this build's rows". Count the `_chs` files with `read_pack_index.py`.
- [ ] **Step 5: Deploy.** If `Warhammer3.exe` is not running: diff the pack's file list against the Workshop copy's (`read_pack_index.py` both; a file in the Workshop copy and not in the new one is a deletion to explain before going on), copy the new pack over `F:\SteamLibrary\steamapps\workshop\content\1142710\3815248936\derpy_great_guilds.pack`, and compare MD5s. Not `data/`. No upload: that is the author's call.
- [ ] **Step 6: Write down.** The handoff covers: what shipped with its MD5; the Rulings above and every executor ruling from the ledger; the share table and the gods with no build job; the in-game checks, the spec §10 seven plus the four the Rulings add (Ruling 5: the Glottkin's Souls reach the pools; Ruling 7: the Eye of the Gods takes an addition; Ruling 9: `UnitTrained` fires for a pool recruit, and `UnitUpgraded`'s `unit` is the unit after the upgrade); and the add-a-race checklist updated with the five new declaration points (`GG.RIVALS_RACE`, `GG.POOL_GUILD`, `GG.NO_DEMAND`, `CHS_WORDS`, the backgrounds `LENT` rule). Then one line in `SESSION_INDEX.md`, `MY_MODS.md`, `systems.md`, and the spec's "As shipped".

## Final review

When Task 12's checks are green, dispatch the whole-branch reviewer per superpowers:executing-plans, on the most capable model, read-only, with: a diff package of every touched file against `$S/base_chs/`; this plan's Review Focus; and the ledger's rulings.
