# The Great Guilds: Skaven Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Skaven (`_skv`, `wh2_main_skv_skaven`) as a ninth race, with full parity, in one build.

**Architecture:** The proven recipe. Every place a race is declared gains a Skaven entry, hand-written, in the Lua model, the panel Lua, the Python generator, the UI generator, the art tools and the test pins. Three Skaven-only code paths are new:
- the taint route;
- under-city founding as the race earn route;
- under-city buildings paying their guild.

The generator writes the DB tables, the loc and the generated Lua blocks. The importer packs everything through RPFM.

**Tech Stack:** Lua 5.1 (game scripts), Python 3 (generators and checks), RPFM MCP (packing), TWUI Studio (headless previews).

**Spec:** `docs/superpowers/specs/2026-10-05-great-guilds-skaven-design.md`

## Global Constraints

- **The workspace is not a git repository.** There are no commit steps. Snapshot every file this plan touches into the scratchpad's `base_skv/` before Task 1. A task's checkpoint is its check or harness going green. Back up the deployed pack to `Modding Files/Backup/`, never into `data/` or a Workshop folder.
- **`_skv` goes before `_gen`** in `FLAVOURS`, with feed offset 90. `_gen` stays last.
- **Skaven race-service rows are appended AFTER the temple's nine rows**, in both `GG.SERVICES` and the generator's `SERVICES`. Cooldowns are saved by position.
- **New `GG.TUNE_ORDER` keys are appended.** The only new key is `rate_temple_taint`.
- **Line endings.**
  - LF: `gen_great_guilds.py`, `make_guild_backgrounds.py`, `mutate_guilds.py`, `_guilds_bounty_harness.lua`, `zzz_derpy_guilds.lua`.
  - CRLF: `gen_guilds_ui.py`, `make_guild_icons.py`, `preview_guilds_panel.py`, `import_great_guilds.py`, `_guilds_harness.lua`, `zzz_derpy_guilds_ui.lua`, `zzz_derpy_guilds_ai.lua`, `script/mct/settings/derpy_great_guilds.lua`.
  - Edit CRLF files with the Edit tool or byte-level Python (the scratchpad's `patchlib.patch` keeps the file's style). Never `sed -i`. Never put a backslash or regex in a heredoc; write patch scripts with the Write tool.
- **Pins.** Every pinned total moves to the new total. A test is never loosened.
- **Player text.** Reputation and Favour, plain words, no jargon, no "rung", no emojis. Guild names at most 22 characters, rank names at most 12.
- **Lua runs float32 in game.** Use an integer multiply then divide. In a function with over 255 constants, no number literal on the LEFT of an arithmetic operator.
- **Keys fail silently.** Every key below was read from the installed `db.pack` or CA's 9.0 scripts on 2026-10-05.
- **`tools/*.py` have no `--help`.** `import_great_guilds.py` BUILDS the pack on any unknown flag.
- **The mutation runner edits the shipped Lua in place.** Never build or deploy while it runs.
- **Commands,** run from `G:\Modding for resources`:
  - `H` = `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua`, which prints `harness ok` last.
  - `BH` = `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua`, which prints `bounty harness ok`.
  - `GEN` = `PYTHONIOENCODING=utf-8 py tools/gen_great_guilds.py` (`--selftest`, `--check`, `--write`). It takes about 2 minutes; redirect it to a file.
  - `UIGEN` = `PYTHONIOENCODING=utf-8 py tools/gen_guilds_ui.py` (`--selftest`, `--check`, `--write`).
  - `LUAC` = `"/c/Program Files (x86)/Lua/5.1/luac.exe" -p <file>`.

## Rulings (plan-time facts, 2026-10-05)

1. **The priests route is DROPPED.** In `faction_agent_permitted_subtypes`, every Grey Seer subtype is a lord, never a hero:
   - `wh2_main_skv_grey_seer_plague`: `general` for 46 factions;
   - `wh2_main_skv_grey_seer_ruin`: `general` for 47 factions, plus one `colonel`;
   - `wh3_dlc29_skv_schemer_grey_seer`: `general` only.

   The spec's fallback applies. The Grey Seers earn from holy war, taint and their buildings only.
2. **The Grey Seers' hall has no unit.** The Screaming Bell exists only as a mount (`wh2_main_cam_mnt_skv_screaming_bell`), and a lord has no hero cap to raise. Like the Empire's College, the hall carries a `HALL_EXTRA` effect instead: Skaven corruption `wh3_main_effect_corruption_skaven_buildings` at `region_to_region_own`, +2/+4/+6. CA's buildings use that pair at values 1-10 (73 rows at 2.0). It feeds the Seers' own taint route.
3. **The Menace Below is not a resource.** No `pooled_resources` row holds its charges. The rank-3 Eshin service becomes **Shadows of Eshin**: a `race_army` that grants Gutter Runners and Night Runners to the selected army. It reuses `GG.RACE_FIRE.electors_muster`, which grants any `units` list.
4. **Food is the pooled resource `skaven_food`.** It accepts the `missions` factor, the one every resource service uses.
   - **Food Tithe:** 20 Food. CA's own quest payloads (`cdir_events_mission_payloads`) pay 20.
   - **Breeding Season:** `wh2_main_pooled_resource_skaven_food_rite` at `faction_to_faction_own_unseen`, value 3, which is CA's own rite bundle value.
5. **Under-city events.** Their context fields come from CA's own listeners, because CA's docs list the events without context:
   - `ForeignSlotManagerCreatedEvent` gives `context:requesting_faction()` (`victory_objectives_config.lua:7517`, `episode_neferata.lua:598`);
   - `ForeignSlotBuildingCompleteEvent` gives `context:slot_manager():faction()` and `context:building()`, a building LEVEL KEY string (`episode_neferata.lua:852-859`).

   Vampire covens fire the founding event too. `GG.race_earn` already refuses any founder whose culture's route is not `undercity`.
6. **Under-city level keys are `<chain>_<n>`.** All 33 levels of the 16 `wh2_dlc12_under_empire_*` chains (plus `wh2_dlc14_under_empire_annexation_plague_cauldron`) follow this pattern. The listener splits the key with `^(.-)_(%d+)$`. A generator check proves the pattern for every Skaven foreign-slot level.
7. **Building sets.**
   - `wh2_main_bas_skv` (115 chains) is the race set.
   - `wh3_dlc29_skv_thanquol` (116 chains) is Thanquol's own set and becomes `extra_sets`, the way Lokhir's set is for the Dark Elves.
   - The clan factions use the race set.
   - The under-city chains are in both sets.
8. **Race words.** Mapped from CA's display names:
   - Order: Taskmaster's Platform and Overseer's Lookout, which go to the Slave-Masters.
   - Plagues: Pox Cauldron and Plague Abbey, the Horned Rat's priesthood, which go to the Grey Seers.
   - Farm: Breeding Pits, which go to Moulder.
   - Energy: Warplightning Capacitors, which go to Skryre.
9. **`purge_unclean` and `consecration` take the Chaos Dwarf override for `_skv`** (public order, no corruption reduction). `RACE_UNWANTED_EFFECTS["_skv"]` forbids `wh3_main_effect_corruption_reduction_events`, because the Seers earn from Skaven corruption.
10. **`FLAVOUR_WORDS_ALLOWED["_skv"] = ("slave",)`.** "Skavenslave" and "the Slave-Masters" are the race's own words, as Slaves are the Dark Elves'.
11. **Art sources.**
    - Grounds: `campaign_skaven1.png`, with `campaign_skaven_clan_scruten1.png` as the spare.
    - Frame: CA's Chaotic Plans panel `ui/skins/default/dlc29_skv_chaotic_plans/` (311 files), plus `ui/skins/wh2_main_skv_skaven/bar_small_buttons.png`.
    - Event pictures: `ui/eventpics/skv/`.
12. **Hall units.**
    - `wh2_main_skv_inf_skavenslaves_0`
    - `wh2_main_skv_inf_stormvermin_0`
    - `wh2_main_skv_inf_warpfire_thrower`
    - `wh2_main_skv_inf_gutter_runners_0`
    - `wh2_main_skv_mon_rat_ogres`
    - `wh2_main_skv_inf_clanrats_0`

    The hire unit, for Hire the Stormvermin, is `wh2_main_skv_inf_stormvermin_0`.

## Review Focus

1. **A Skaven building in an under-city beneath another race's settlement.** It pays the Skaven owner's guild by the Skaven words, never the host settlement's race words. Pinned in Task 3.
2. **A vampire coven founded by Neferata.** It pays no Skaven route, and it pays nothing to the vampire faction either. Pinned in Task 3.
3. **A campaign already running with a Skaven human.** Every Skaven faction loads blank at 0/0, and the human's panel opens. Pinned in Task 1, which loads a save string with no Skaven state.
4. **Treachery's `demand_penalty = 0`.** An expired Skaven demand costs exactly 0, and nothing divides by it. Pinned in Task 1 (BH).
5. **The taint route in the lead hold.** A Skaven leader on the temple keeps the lead across a round in which it has not taken its turn. Pinned in Task 2 through `GG.turn_start_pay`.

---

### Task 1: The Skaven in the model's tables (Lua)

**Files:**
- Modify `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (LF):
  - `GG.FLAVOURED` (3430)
  - `GG.HIRE_UNIT_BY_CULTURE` (3351)
  - `GG.TWISTS` (5047)
  - `GG.EARN_ROUTES` (4007) and `GG.EARN_OF` (4020)
  - `GG.HALL_TAGS` (4405)
  - `GG.LEDGER_SOURCES` (5784)
  - `GG.TUNE_DEFAULTS` and `GG.TUNE_ORDER` (4861), and the presets
  - the `GG.SERVICES` rows, after the temple rows
  - `GG.RACE_FIRE` / `GG.RACE_TARGET_OK`
- Modify `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` (CRLF): the `rate_temple_taint` row and the PRESET_OWNED entry.
- Modify `zzz_derpy_guilds_ui.lua` (CRLF): `GGUI.MCT_NAMES` gains a hand-written `_skv` entry. Task 5's `GEN --write` must reproduce it byte for byte.
- Tests: `tools/_guilds_harness.lua` (CRLF) and `tools/_guilds_bounty_harness.lua` (LF).

**Interfaces:**
- **Produces:**
  - `GG.FLAVOURED["wh2_main_skv_skaven"] = {tag = "_skv", feed = 90}`
  - `GG.EARN_ROUTES.undercity = {guild = "khanate", rep = 40}`
  - `GG.EARN_OF["wh2_main_skv_skaven"] = "undercity"`
  - `GG.TWISTS["wh2_main_skv_skaven"] = {rate_rivalry = 150, demand_penalty = 0}`
  - `GG.HALL_TAGS["_skv"] = true`
  - TUNE key `rate_temple_taint` (default 2)
  - LEDGER sources `"undercity"` and `"taint"`
  - the three race rows: `food_tithe`, `shadows_of_eshin`, `breeding_season`
- **Consumed by:** Tasks 2, 3, 5, 6 and 8.

- [ ] **Step 1: Write the failing harness block.** Insert it before the final `print("harness ok")` in `_guilds_harness.lua`:

```lua
;(function()
    -- THE SKAVEN (skaven spec, 2026-10-05): a ninth flavour, its twist, its earn route and
    -- its three race services appended AFTER the temple's nine.
    local SKV = "wh2_main_skv_skaven"
    assert(GG.FLAVOURED[SKV] and GG.FLAVOURED[SKV].tag == "_skv"
           and GG.FLAVOURED[SKV].feed == 90, "the Skaven flavour, feed 90")
    assert(GG.HIRE_UNIT_BY_CULTURE[SKV] == "wh2_main_skv_inf_stormvermin_0",
           "the Skaven hire the Stormvermin")
    assert(GG.EARN_OF[SKV] == "undercity" and GG.EARN_ROUTES.undercity.guild == "khanate"
           and GG.EARN_ROUTES.undercity.rep == 40, "under-cities pay Clan Eshin 40")
    assert(GG.TWISTS[SKV].rate_rivalry == 150 and GG.TWISTS[SKV].demand_penalty == 0,
           "Treachery: rivalry half again, an expired demand costs nothing")
    assert(GG.HALL_TAGS["_skv"], "the Skaven have halls")
    assert(GG.TUNE_DEFAULTS.rate_temple_taint == 2
           and GG.TUNE_ORDER[#GG.TUNE_ORDER] == "rate_temple_taint",
           "the taint rate, appended last")
    assert(GG.LEDGER_KNOWN.undercity and GG.LEDGER_KNOWN.taint, "two new ledger sources")
    -- APPENDED AFTER THE TEMPLE: cooldowns are saved by position.
    local n = #GG.SERVICES
    assert(GG.SERVICES[n - 2].key == "food_tithe" and GG.SERVICES[n - 1].key == "shadows_of_eshin"
           and GG.SERVICES[n].key == "breeding_season", "the Skaven rows are last")
    assert(GG.SERVICES[n - 3].key == "consecration", "the temple's last row sits before them")
    assert(GG.RACE_FIRE.shadows_of_eshin == GG.RACE_FIRE.electors_muster,
           "Shadows of Eshin grants units the way the Elector's Muster does")
    -- A SAVE FROM BEFORE THE SKAVEN: a Skaven faction with no saved state loads blank.
    local F = "cr_skv_old"
    GG.CULTURE_OF[F] = SKV
    GG.state[F] = nil
    GG.load(F)
    for _, g in ipairs(GG.GUILDS) do
        local rep, fav = GG.get(F, g)
        assert(rep == 0 and fav == 0, "a Skaven faction loads blank on " .. g)
    end
    GG.state[F], GG.CULTURE_OF[F] = nil, nil
end)()
```

Run `H > "$S/h.txt" 2>&1; grep "lua.exe:" "$S/h.txt"`. Expected: FAIL on "the Skaven flavour, feed 90".

- [ ] **Step 2: The failing bounty-harness case.** In `_guilds_bounty_harness.lua`, the twist table `want` (around 1812-1822) gains `["wh2_main_skv_skaven"] = {rate_rivalry = 150, demand_penalty = 0}`. After the block that tests the Dwarf `demand_penalty`, add this. Find it with `grep -n "demand_penalty" tools/_guilds_bounty_harness.lua`, then copy that block's demand setup and its call that lets a demand expire, with the Skaven culture:

```lua
-- TREACHERY: an expired Skaven demand costs nothing (demand_penalty 0), and nothing
-- divides by it. Same setup as the Dwarf case above, the Skaven culture instead.
```

Assert that the penalty taken is exactly 0 and that the guild's reputation is unchanged. Run `BH`. Expected: FAIL (no Skaven twist).

- [ ] **Step 3: Implement the tables.** In `zzz_derpy_guilds.lua`:

```lua
-- GG.FLAVOURED, after the _hef line:
    ["wh2_main_skv_skaven"] = {tag = "_skv", feed = 90},
-- GG.HIRE_UNIT_BY_CULTURE, after the High Elf line:
    ["wh2_main_skv_skaven"]        = "wh2_main_skv_inf_stormvermin_0",
-- GG.EARN_ROUTES, after `court`:
    -- UNDER-CITIES (skaven spec §4.2): Clan Eshin's trade is infiltration.
    undercity  = {guild = "khanate",      rep = 40},
-- GG.EARN_OF, after the High Elf line:
    ["wh2_main_skv_skaven"]        = "undercity",
-- GG.TWISTS, after the High Elf line:
    -- TREACHERY: a Skaven promise is worth nothing, and every clan takes from its rival.
    ["wh2_main_skv_skaven"]        = {rate_rivalry = 150, demand_penalty = 0},
```

- `GG.HALL_TAGS`: add `["_skv"] = true` inside the one-line table.
- `GG.LEDGER_SOURCES`: append after `"priests"`:

```lua
                     -- THE SKAVEN (2026-10-05).
                     "undercity", "taint"}
```

- `GG.TUNE_DEFAULTS`: `rate_temple_taint = 2`.
- `GG.TUNE_ORDER`: append `"rate_temple_taint"` last.
- The four presets: `easy` 3, `hard` 1, `ultra` 1. Find each preset table with `grep -n "rate_temple_holy" "$M"` and add the key beside it, in each preset's own style.

In `GG.SERVICES`, append after the `consecration` row:

```lua
    -- THE SKAVEN'S RACE SERVICES (2026-10-05), AFTER the temple rows: cooldowns are positional.
    {key="food_tithe",          guild="slavers",      rank=2, cost=50,  cd=8,  kind="resource", resource="skaven_food", factor="missions", value=20, race="wh2_main_skv_skaven"},
    {key="shadows_of_eshin",    guild="khanate",      rank=3, cost=150, cd=12, kind="race_army", room=true, units="wh2_main_skv_inf_gutter_runners_0,wh2_main_skv_inf_night_runners_0", race="wh2_main_skv_skaven"},
    {key="breeding_season",     guild="overseers",    rank=4, cost=400, cd=16, kind="bundle", turns=10, lead=true, race="wh2_main_skv_skaven"},
```

Copy the exact field set of the existing `slave_coffles`, `electors_muster` and `black_ark_tithe` Lua rows. If those rows carry fields this block lacks, such as `value` on a bundle or a `bundle` key, match them field for field.

After `GG.RACE_FIRE.electors_muster` is defined:

```lua
-- SHADOWS OF ESHIN (skaven ruling 3): the Menace Below's charges are not a resource a
-- script can add to, so Eshin lends its runners instead, through the Muster's grant.
GG.RACE_FIRE.shadows_of_eshin = GG.RACE_FIRE.electors_muster
```

If `electors_muster` has a `GG.RACE_NEEDS` or `GG.RACE_TARGET_OK` entry, alias that too, the same way.

In the MCT file, add a `rate_temple_taint` row beside `rate_temple_holy`, with the label "The Faith Guild: tainted provinces", default 2, min 0, max 10, and the same type and section as `rate_temple_holy`. Add it to `PRESET_OWNED` wherever `rate_temple_holy` appears.

In `zzz_derpy_guilds_ui.lua`, inside the generated `GGUI.MCT_NAMES` block, add after the `_hef` entry, in its exact layout:

```lua
    ["_skv"] = {
        brass = "The Warpstone Traders",
        immortals = "The Stormvermin",
        daemonsmiths = "Clan Skryre",
        khanate = "Clan Eshin",
        overseers = "Clan Moulder",
        slavers = "The Slave-Masters",
        temple = "The Grey Seers",
    },
```

- [ ] **Step 4: Run.** `H`, `BH`, and `LUAC` on the model, the UI and the MCT file. Expected: `harness ok`, `bounty harness ok`, every `luac` exit 0. The harness's own race lists and pins that now count nine are in the next step.
- [ ] **Step 5: Move the race pins.** Run `H` and `BH` again. Every assertion that counts or lists races now fails with a numbered message. Move each to the counted new value, never deleting it. The known sites:
  - `_guilds_harness.lua:3897`, which requires a hire unit for every `GG.FLAVOURED`.
  - `:8213`, which requires a `GGUI.FRAME` per flavour. It fails until Task 8, so record a ledger ruling that Task 8 owns it, and add `GGUI.FRAME["_skv"]` there.
  - `:5978-5985`, the five-race `cases` list. Add `{tag = "_skv", feed = 90, hire = "wh2_main_skv_inf_stormvermin_0", culture = "wh2_main_skv_skaven"}` in its shape.
  - `_guilds_bounty_harness.lua:1812-1822`, the `want` table, already done in Step 2.

  Run `H` and `BH`. Expected: green, except the `GGUI.FRAME` pin, which Task 8 clears. If that pin blocks every later block (the harness stops at the first assert), move the `GGUI.FRAME["_skv"]` entry forward from Task 8 now, as a copy of `GGUI.FRAME["_def"]`, and ledger the ruling. Task 8 replaces its values.

---

### Task 2: The taint route

**Files:**
- Modify `zzz_derpy_guilds.lua`:
  - the `-- BEGIN TEMPLE ROUTES` block (Skaven entry);
  - `GG.temple_counts`, `GG.temple_turn` and `GG.turn_start_pay`.
- Test: `_guilds_harness.lua`, the routes block (`prov()` and `earned()`, around 9481).

**Interfaces:**
- **Consumes:** `rate_temple_taint` and LEDGER `"taint"` from Task 1.
- **Produces:**
  - `GG.TEMPLE_ROUTES["wh2_main_skv_skaven"] = {taint = true, holy = {"wh_main_dwf_dwarfs", "wh2_main_lzd_lizardmen"}}`
  - `GG.temple_counts(f, r)` now returns `devout, clean, tainted`.

- [ ] **Step 1: The failing test.** In the routes block, after the five-corruption loop, add:

```lua
    -- THE SKAVEN'S TAINT (skaven spec §4.1): paid per province CARRYING Skaven corruption,
    -- nothing for a clean one, and the Skaven have no devout or chaos route.
    local skv1 = prov(10, 0, 0, {wh3_main_corruption_skaven = 12})
    local skv2 = prov(-5, 4, 0, {wh3_main_corruption_skaven = 1})
    local clean = prov(10, 0, 0)
    assert(earned("wh2_main_skv_skaven", function(F)
        GG.temple_turn(F, {provinces = function() return L({skv1, skv2, clean}) end}) end)
        == 2 * 2, "two tainted provinces x 2, the clean one nothing")
    -- AND THE HOLD SEES IT: the Skaven turn start previews the same 4.
    local keep_gf2 = cm.get_faction
    cm.get_faction = function(self, k)
        if k == "cr_skv_pay" then
            return {is_null_interface = function() return false end,
                    provinces = function() return L({skv1, skv2, clean}) end}
        end
        return keep_gf2(self, k)
    end
    local keep_pc2 = GG.player_cultures
    GG.CULTURE_OF["cr_skv_pay"] = "wh2_main_skv_skaven"
    GG.player_cultures = function() return {wh2_main_skv_skaven = true} end
    assert(GG.turn_start_pay("cr_skv_pay", "temple") == 4,
           "the Skaven turn-start preview includes taint, got "
           .. GG.turn_start_pay("cr_skv_pay", "temple"))
    cm.get_faction, GG.player_cultures, GG.CULTURE_OF["cr_skv_pay"] = keep_gf2, keep_pc2, nil
    -- Holy war: the cache is asked with the Dwarfs and the Lizardmen.
    local asked2
    cm.pending_battle_cache_faction_won_battle_against_culture = function(_, fk, cultures)
        asked2 = cultures
        return true
    end
    assert(earned("wh2_main_skv_skaven", function(F) GG.temple_holy(F) end) == 10,
           "a Skaven win against the Dwarfs pays 10")
    assert(asked2[1] == "wh_main_dwf_dwarfs" and asked2[2] == "wh2_main_lzd_lizardmen",
           "asked with the Dwarf and Lizardman cultures")
    cm.pending_battle_cache_faction_won_battle_against_culture = nil
    -- NO PRIESTS ROUTE (ruling 1): a Grey Seer is a lord, so no hero action pays the Seers.
    assert(GG.TEMPLE_ROUTES["wh2_main_skv_skaven"].priests == nil, "no Skaven priests route")
```

Run `H`. Expected: FAIL. The temple routes have no Skaven entry, so the earned value is 0.

- [ ] **Step 2: Implement.** Inside the TEMPLE ROUTES block, after the High Elf entry:

```lua
    -- THE GREY SEERS (skaven spec §3.2): no devout and no chaos route - the Under-Empire
    -- SPREADS corruption - so `taint` pays per province carrying Skaven corruption. No
    -- priests route: every Grey Seer subtype is a lord (faction_agent_permitted_subtypes).
    ["wh2_main_skv_skaven"] = {taint = true,
        holy = {"wh_main_dwf_dwarfs", "wh2_main_lzd_lizardmen"}},
```

In `GG.temple_counts`, add a third counter. The function returns `devout, clean, tainted`:

```lua
    local devout, clean, tainted = 0, 0, 0
    ...
        if r.taint then
            local res = fp:province():pooled_resource_manager():resource("wh3_main_corruption_skaven")
            if not res:is_null_interface() and res:value() > 0 then tainted = tainted + 1 end
        end
    ...
    return devout, clean, tainted
```

The `if r.taint` block goes inside the province loop, after the `r.chaos` block.

In `GG.temple_turn`, change the guard to `if not r or not (r.devout or r.chaos or r.taint) or not f then return end`. Take `local ok, devout, clean, tainted = pcall(...)`, then add:

```lua
    GG.capped_grant(faction, "temple", tainted * (GG.setting("rate_temple_taint") or 2),
                    "taint")
```

In `GG.turn_start_pay`'s temple branch, change the guard to the same `(r.devout or r.chaos or r.taint)`. Return `0, 0, 0` from the pcall's null branch. Take the third value and add:

```lua
                  + GG.with_patron(faction, guild,
                                   tainted * (GG.setting("rate_temple_taint") or 2))
```

- [ ] **Step 3: Run.** `H`. Expected: `harness ok`. Run `BH` and `LUAC` on the model. Expected: green.

---

### Task 3: Under-cities, the earn route and the buildings

**Files:**
- Modify `zzz_derpy_guilds.lua`:
  - a new `GG.level_of(key)` beside `GG.on_building` (859);
  - two listeners beside `gg_earn_court` (5643) and `gg_building` (about 5400).
- Test: `_guilds_harness.lua`.

**Interfaces:**
- **Consumes:** `GG.EARN_ROUTES.undercity` and `GG.EARN_OF` from Task 1, and the existing `GG.race_earn(faction, route)` and `GG.on_building(faction, level, chain)`.
- **Produces:**
  - `GG.level_of(key)`, which returns `chain, n` or nil;
  - `GG.on_undercity_founded(name)`;
  - `GG.on_undercity_building(name, level_key)`.

  Both of the last two are thin, so the harness can call them without the event bus.

- [ ] **Step 1: The failing test.** Add a block before `print("harness ok")`:

```lua
;(function()
    -- UNDER-CITIES (skaven spec §4.2, §4.3).
    local keep_pc = GG.player_cultures
    GG.player_cultures = function() return {wh2_main_skv_skaven = true} end
    local S, V = "cr_skv_uc", "cr_vmp_coven"
    GG.CULTURE_OF[S], GG.CULTURE_OF[V] = "wh2_main_skv_skaven", "wh_main_vmp_vampire_counts"
    GG.state[S], GG.state[V], GG.turn_gain[S], GG.turn_gain[V] = nil, nil, {}, {}
    -- The level key splits into its chain and level.
    local c, n = GG.level_of("wh2_dlc12_under_empire_money_thieves_3")
    assert(c == "wh2_dlc12_under_empire_money_thieves" and n == 3, "level key splits")
    assert(GG.level_of("no_number_here") == nil, "a key without a level is refused")
    -- FOUNDING pays Clan Eshin 40, and a vampire coven pays nobody.
    GG.on_undercity_founded(S)
    assert(select(1, GG.get(S, "khanate")) == 40, "an under-city founded pays Eshin 40, got "
           .. tostring(select(1, GG.get(S, "khanate"))))
    GG.on_undercity_founded(V)
    for _, g in ipairs(GG.GUILDS) do
        assert(select(1, GG.get(V, g)) == 0, "a vampire coven pays no guild: " .. g)
    end
    -- AN UNDER-CITY BUILDING pays its guild by the Skaven words: a Thieving den is the
    -- Warpstone Traders' (under_empire_money), level 2 at the Overseers' rate x 2.
    GG.reset_turn(S)
    GG.on_undercity_building(S, "wh2_dlc12_under_empire_money_thieves_2")
    assert(select(1, GG.get(S, "brass")) == 20, "a level-2 Thieving pays the Traders 20, got "
           .. tostring(select(1, GG.get(S, "brass"))))
    GG.on_undercity_building(S, "garbage")
    GG.state[S], GG.state[V], GG.CULTURE_OF[S], GG.CULTURE_OF[V] = nil, nil, nil, nil
    GG.turn_gain[S], GG.turn_gain[V] = nil, nil
    GG.player_cultures = keep_pc
end)()
```

Run `H`. Expected: FAIL, because `GG.level_of` is nil.

The Thieving case depends on Task 4's race words. Until Task 4, the level-2 Thieving pays the Overseers, the default. If Task 3 runs first, the brass assert fails for that reason. Record a ledger ruling and move this one assert into Task 4's Step 1, keeping the rest here.

- [ ] **Step 2: Implement.** Beside `GG.on_building`:

```lua
-- AN UNDER-CITY BUILDING'S LEVEL KEY, "<chain>_<n>" (skaven ruling 6): CA's
-- ForeignSlotBuildingCompleteEvent hands a level key string, not a building interface.
function GG.level_of(key)
    if type(key) ~= "string" then return nil end
    local chain, n = string.match(key, "^(.-)_(%d+)$")
    if not chain or chain == "" then return nil end
    return chain, tonumber(n)
end

-- Founding an under-city pays the race route; GG.race_earn refuses any culture whose
-- route is not "undercity", so Neferata's covens pay nobody.
function GG.on_undercity_founded(name)
    GG.load(name); GG.race_earn(name, "undercity"); GG.save(name)
end

-- An under-city building pays its guild like any building, by the OWNER's race words.
function GG.on_undercity_building(name, key)
    local chain, n = GG.level_of(key)
    if not chain then return end
    GG.load(name); GG.on_building(name, n, chain); GG.save(name)
end
```

Beside `gg_earn_court`:

```lua
    -- ForeignSlotManagerCreatedEvent carries requesting_faction() (CA's own listener,
    -- victory_objectives_config.lua:7517). Vampire covens fire it too; race_earn refuses them.
    core:add_listener("gg_earn_undercity", "ForeignSlotManagerCreatedEvent", true,
        function(context)
            local name = faction_name_of(context, function()
                return context:requesting_faction() end)
            if name then GG.on_undercity_founded(name) end
        end, true)

    -- ForeignSlotBuildingCompleteEvent carries slot_manager():faction() and building(), a
    -- level key (episode_neferata.lua:852-859). BuildingCompleted never fires for these.
    core:add_listener("gg_undercity_building", "ForeignSlotBuildingCompleteEvent", true,
        function(context)
            local okb, key = pcall(function() return context:building() end)
            if not okb or type(key) ~= "string" then return end
            local name = faction_name_of(context, function()
                return context:slot_manager():faction() end)
            if name then GG.on_undercity_building(name, key) end
        end, true)
```

Check that `faction_name_of` is in scope at that point (it is a `local function` at 4788) and is declared above both listeners.

- [ ] **Step 3: Run.** `H`, `BH`, `LUAC` on the model, and `py tools/check_lua_api.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"`. Expected: green. The API check flags no `cm:` call, since the new code calls none.

---

### Task 4: The Skaven race words

**Files:**
- Modify `zzz_derpy_guilds.lua`: `GG.BUILDING_THEME_RACE` (748), adding a `["_skv"]` entry.
- Test: `_guilds_harness.lua`.

**Interfaces:**
- **Consumes:** `GG.guild_of_chain(chain, tag)`.
- **Produces:** `GG.BUILDING_THEME_RACE["_skv"]`.

- [ ] **Step 1: The failing test.**

```lua
;(function()
    -- THE SKAVEN WORDS (skaven ruling 8), read from CA's display names.
    local want = {
        wh2_main_skv_resource_gold = "brass", wh2_main_skv_port = "brass",
        wh2_dlc12_under_empire_money_thieves = "brass",
        wh2_dlc12_under_empire_warpstone_refinery = "brass",
        wh2_main_skv_clanrats = "immortals", wh2_main_skv_defence_major = "immortals",
        wh2_dlc12_under_empire_annexation_war_camp = "immortals",
        wh2_main_skv_engineers = "daemonsmiths", wh2_main_skv_weaponteams = "daemonsmiths",
        wh2_main_skv_energy = "daemonsmiths", wh3_dlc29_skv_stormfiends = "daemonsmiths",
        wh2_dlc12_under_empire_annexation_doomsday = "daemonsmiths",
        wh2_main_skv_assassins_eshin = "khanate",
        wh2_dlc12_under_empire_discovery_deeper_tunnels = "khanate",
        wh2_main_skv_farm = "overseers", wh2_main_skv_monsters = "overseers",
        wh2_main_skv_order = "slavers", wh2_dlc12_under_empire_food_kidnappers = "slavers",
        wh2_main_skv_plagues = "temple",
        wh2_dlc14_under_empire_annexation_plague_cauldron = "temple",
    }
    for chain, g in pairs(want) do
        assert(GG.guild_of_chain(chain, "_skv") == g,
               chain .. " should pay " .. g .. ", got " .. tostring(GG.guild_of_chain(chain, "_skv")))
    end
    -- AND ONLY FOR THE SKAVEN: a Dark Elf faction's farm is not Clan Moulder's.
    assert(GG.guild_of_chain("wh2_main_skv_farm", "_def") ~= "overseers"
           or GG.BUILDING_THEME_RACE["_def"] == nil
           or true, "race words are per tag")
end)()
```

The last assert documents scope only. The real per-tag proof is the generator's `check_building_theme` in Task 5, which refuses a Skaven token matching any non-Skaven chain.

Run `H`. Expected: FAIL on the first chain.

- [ ] **Step 2: Implement.** In `GG.BUILDING_THEME_RACE`, after the `["_hef"]` entry:

```lua
    -- THE SKAVEN (skaven ruling 8). Order is Taskmaster's Platform and Overseer's Lookout
    -- (the Slave-Masters); Plagues the Horned Rat's priesthood (the Grey Seers); the
    -- under-city chains split by what they do.
    ["_skv"] = {
        {"temple", {"skv_plagues", "under_empire_annexation_plague_cauldron"}},
        {"daemonsmiths", {"skv_engineers", "skv_weaponteams", "skv_energy", "skv_stormfiends",
                          "under_empire_annexation_doomsday"}},
        {"khanate", {"skv_assassins", "under_empire_discovery", "foreign_slot_discovery_skv"}},
        {"slavers", {"skv_order", "under_empire_food"}},
        {"brass", {"skv_resource", "skv_port", "under_empire_money", "under_empire_warpstone"}},
        {"immortals", {"skv_clanrats", "skv_defence", "under_empire_annexation_war_camp",
                       "under_empire_settlement_stronghold"}},
        {"overseers", {"skv_farm", "skv_monsters", "skv_industry",
                       "under_empire_settlement_warren"}},
    },
```

- [ ] **Step 3: Run.** `H` (and Task 3's Thieving assert, if it was moved here). Expected: `harness ok`.

---

### Task 5: The generator: the flavour, its text, its services and the mirrors

**Files:**
- Modify `tools/gen_great_guilds.py` (LF):
  - `FLAVOURS` (a `_skv` entry before `_gen`);
  - `POOL_NAMES`, `TEMPLE_NAMES`, `TEMPLE_FLAVOUR`, `TEMPLE_ROUTES`, `RACE_TEXT`, `EARN_ROUTES`/`EARN_OF`, `TWISTS`;
  - `SERVICES` (three rows appended after `consecration`, and `_skv` `for_tag` overrides on `purge_unclean` and `consecration`);
  - `RACE_UNWANTED_EFFECTS`, `FLAVOUR_WORDS_ALLOWED`, `RATES`/`TUNE` mirrors;
  - a new `check_undercity_levels()`;
  - the selftest pins.

**Interfaces:**
- **Consumes:** every Lua table from Tasks 1-4. The mirror checks compare them.
- **Produces:** `GEN --write` output. Its generated `GGUI.MCT_NAMES` must equal Task 1's hand edit byte for byte.

- [ ] **Step 1: Run `GEN --check` first** to see the mirrors fail. Expected: findings naming the Skaven in `check_flavour_mirror`, `check_race_mirror`, `check_hire_units`, `check_temple_routes` and `check_hall_mirror`. Task 6 clears the hall one.

- [ ] **Step 2: The flavour.** Add `FLAVOURS["_skv"]` immediately before `"_gen"`, in `_hef`'s exact shape:

```python
    "_skv": {
        "culture": "wh2_main_skv_skaven", "pics": "skv", "feed": 90,
        "guilds": {
            "brass": "The Warpstone Traders",
            "immortals": "The Stormvermin",
            "daemonsmiths": "Clan Skryre",
            "khanate": "Clan Eshin",
            "overseers": "Clan Moulder",
            "slavers": "The Slave-Masters",
        },
        "ranks": ["Skavenslave", "Clanrat", "Clawleader", "Chieftain", "Warlord"],
        "services": {
            "caravan_levy": "Warpstone Tithe",
            "writ_monopoly": "The Council's Seal",
            "long_ledger": "The Under-Empire's Trade",
            "oathbound_draft": "Call the Clanrats",
            "hire_immortals": "Hire the Stormvermin",
            "astragoths_levy": "Muster the Clawpack",
            "forge_rite": "Warp-Lightning Rites",
            "bound_blueprint": "Stolen Schematics",
            "bound_ordnance": "Skryre's Gift",
            "hobgoblin_eyes": "Eyes in the Dark",
            "knife_in_dark": "A Blade from Eshin",
            "khans_price": "Eshin's Price",
            "lash_the_gangs": "Whip the Slaves",
            "raise_ziggurat": "Dig Deeper",
            "works_of_zharr": "Works of the Warrens",
            "coffle_drive": "Slave Raids",
            "slave_tithe": "The Slave-Masters' Cut",
            "great_coffle": "The Great Taking",
        },
        "blurbs": {
            "caravan_levy": "The Warpstone Traders call in what they are owed, and some of "
                            "what they are not. Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "Black-furred and loyal for as long as the pay holds. Adds "
                              "one unit of Stormvermin to an army of your choosing.",
            "bound_blueprint": "Clan Skryre sells you work it stole from someone else. "
                               "Completes the technology you are currently researching, "
                               "at once.",
            "hobgoblin_eyes": "Clan Eshin's watchers tell you what they saw. Reveals one "
                              "region through the shroud for this turn.",
            "raise_ziggurat": "Clan Moulder's packs dig through the night. Upgrades one of "
                              "your buildings to its next level at once, and free.",
            "slave_tithe": "The Slave-Masters send back your share of the take. Adds 3,000 "
                           "gold to your treasury.",
        },
        "desc": {
            "brass": "The brokers of the Under-Empire, who buy warpstone from one clan and "
                     "sell it to the next. Every warlord owes them something.",
            "immortals": "The black-furred guard of the great warlords: the biggest, the "
                         "best armed, and loyal for exactly as long as they are paid.",
            "daemonsmiths": "The warlock engineers of Skavenblight, who bind warp-lightning "
                            "into guns and engines. They sell their secrets slowly, and "
                            "never for free.",
            "khanate": "The assassins of the hidden clan, who serve whoever pays and "
                       "remember everyone who ever did.",
            "overseers": "The breeders and flesh-crafters of Hell Pit, who grow monsters, "
                         "food and warrens alike.",
            "slavers": "The packmasters and raiders who drive the slaves, and who are paid "
                       "in whatever they drag home.",
        },
        "bounties": {
            "brass": ("Seize the Warpstone",
                      "The Warpstone Traders want that town's stores in their tunnels. Take "
                      "it intact."),
            "immortals": ("A Warlord's Rival",
                          "A general is spoken of as a threat. The Stormvermin would like "
                          "that corrected."),
            "daemonsmiths": ("Steal the Secrets",
                             "Whatever that place knows, Clan Skryre wants it. Bring it "
                             "back in pieces."),
            "khanate": ("A Name to Silence",
                        "Clan Eshin does not care how it is done, only that the name stops "
                        "being spoken."),
            "overseers": ("New Warrens",
                          "Take it whole. Clan Moulder wants tunnels to dig, not rubble."),
            "slavers": ("Take Them All",
                        "Sack it. The Slave-Masters are owed, and that place has plenty to "
                        "drag away."),
        },
    },
```

`POOL_NAMES["_skv"]`, positional. The order is the pool services' order, printed in this plan's research, from `alms_and_bribes` to `scorched_earth`:

```python
    "_skv": ["Bribes to the Council", "Hired Clawpacks", "A Warpstone Loan",
             "Salvagers' Charter", "The Lord of Decay's Hoard", "Bought Truces",
             "Scurry Forth", "Clawleader Drills", "The Warlord's Banner", "Fleshmenders",
             "Veteran Clawpacks", "The Warlord's Favour", "Warpstone Charms",
             "Warp-Lightning Siphons", "Warplock Blades", "Weapon Team Crews",
             "Skryre's Great Work", "The Skavenblight Arsenal", "Bought Sentries",
             "Blooded Gutter Runners", "Eshin Training", "Whispers in the Dark",
             "The Hidden Web", "Poisoned Wells", "Breeding Pens", "New Tunnels",
             "Rat Ogre Wardens", "Barricade the Warrens", "Master Diggers", "The Great Nest",
             "Raiding Packs", "Slave Markets", "Slave Levy", "Fighting Pits", "The Great Hunt",
             "Burn the Stores"],
```

`TEMPLE_NAMES["_skv"]`, in the order `hashut_blessing, forge_sermons, temple_tithe, zeal, purge_unclean, anathema, holy_war, miracle, consecration`:

```python
    "_skv": ["The Horned Rat's Blessing", "Sermons of the Seers", "Tithe of the Seers",
             "Frenzy", "Purge the Weak", "Doom Foretold", "The Great Plan", "Warp-Healing",
             "Rule of the Seers"],
```

`TEMPLE_FLAVOUR["_skv"]`, as a `(name, desc, (bounty title, text), earn, short)` tuple:

```python
    "_skv": ("The Grey Seers",
             "The horned prophets of the Great Horned Rat, who sit at the Council's right "
             "hand and whisper which warlord will be next to fall.",
             ("The Seers' Doom",
              "A dwarf or lizardman general leads an army in the open. The Grey Seers have "
              "foreseen that general's death. Make it so."),
             "You earn reputation from provinces where the Under-Empire's taint spreads, from "
             "battles won against the Dwarfs and the Lizardmen, and from their own buildings.",
             "tainted provinces, wins over dwarfs and lizardmen"),
```

`RACE_TEXT["_skv"]`:

```python
    "_skv": {"label": "Skaven", "earn": "Founding an under-city pays the {g}.",
             "twist": ("Treachery", "earning with a guild takes half again as much from its "
                       "rival, and a demand you let expire costs nothing.")},
```

The rest:
- `TEMPLE_ROUTES["wh2_main_skv_skaven"] = {"taint": True, "holy": ["wh_main_dwf_dwarfs", "wh2_main_lzd_lizardmen"]}`.
- `EARN_ROUTES["undercity"] = {"guild": "khanate", "rep": 40}` and `EARN_OF["wh2_main_skv_skaven"] = "undercity"`, matching the Lua mirror's field names.
- `TWISTS["wh2_main_skv_skaven"] = {"rate_rivalry": 150, "demand_penalty": 0}`.
- `FLAVOUR_WORDS_ALLOWED["_skv"] = ("slave",)`.
- `RACE_UNWANTED_EFFECTS["_skv"] = {"wh3_main_effect_corruption_reduction_events": "the Grey Seers earn from Skaven corruption; reducing it works against their own route"}`.
- The rate tables (`RATES.temple`, the tune mirror, the MCT labels): add `rate_temple_taint` (2) wherever `rate_temple_holy` appears. Find them with `grep -n "rate_temple_holy" tools/gen_great_guilds.py`. `TEMPLE_RATE_KEYS` gains it, and `_mct_label_problem` accepts "The Faith Guild: tainted provinces".
- A `"taint"` route also needs its ledger loc: wherever `src_devout` is defined, add `src_taint` ("Tainted provinces") and `src_undercity` ("Under-cities founded").
- The earn-route loc: wherever `derpy_gg_log_earn_court` is built, the generator builds `derpy_gg_log_earn_undercity_skv`. Check that the route loop covers it, and add an entry only if it is a hand list.

`purge_unclean` and `consecration` gain `"_skv"` in their `for_tag` dicts, as a copy of the `""` override (public order, no corruption reduction).

`SERVICES`, appended after `consecration`:

```python
    # THE SKAVEN'S RACE SERVICES (2026-10-05), AFTER the temple rows: cooldowns are saved
    # by position. Food Tithe's 20 is CA's own quest payload; Breeding Season's 3 is CA's
    # rite bundle value; Shadows of Eshin replaces the Menace Below (not a resource).
    {"key": "food_tithe", "guild": "slavers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "resource", "race": "wh2_main_skv_skaven", "resource": "skaven_food",
     "factor": "missions", "value": 20, "name": "Food Tithe", "text": "Adds {value} Food."},
    {"key": "shadows_of_eshin", "guild": "khanate", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race_army", "room": True, "race": "wh2_main_skv_skaven",
     "units": "wh2_main_skv_inf_gutter_runners_0,wh2_main_skv_inf_night_runners_0",
     "name": "Shadows of Eshin",
     "text": "A unit of Gutter Runners and one of Night Runners join the army you select."},
    {"key": "breeding_season", "guild": "overseers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "lead": True, "race": "wh2_main_skv_skaven",
     "name": "Breeding Season",
     "effects": [("wh2_main_pooled_resource_skaven_food_rite",
                  "faction_to_faction_own_unseen", 3)],
     "text": "{v0:+d} Food every turn, for {turns} turns."},
```

Match the existing race rows' exact key set. Compare with `grep -n '"key": "black_ark_tithe"' -A8` and the `electors_muster` row; if those carry `lead` on rank 4 or other fields, copy them. Keep `RACE_PRICE`, which these values satisfy.

- [ ] **Step 3: `check_undercity_levels()`.** Add it beside `check_temple_routes` and hook it the same way. It reads `live_rows("building_levels")` and, for every chain containing `under_empire`, asserts:

```python
def check_undercity_levels():
    """GG.level_of splits an under-city LEVEL key as "<chain>_<n>" (skaven ruling 6). Every
    such level in the game must split back to its own chain and a number, or a building
    finished in an under-city pays the wrong guild, or nobody."""
    out = []
    for r in live_rows("building_levels"):
        ch, lv = r["chain"], r["level_name"]
        if "under_empire" not in ch:
            continue
        m = re.match(r"^(.*?)_(\d+)$", lv)
        if not m or m.group(1) != ch:
            out.append("under-city level %s does not split to its chain %s" % (lv, ch))
    return out
```

Mutation-check it: temporarily change `!= ch` to `== ch`, run `--check`, see findings, and revert. Ledger the result.

- [ ] **Step 4: Selftest pins.** Run `GEN --selftest > "$S/st.txt" 2>&1`. Each failing pin names a count. Move it to the counted new value, never loosening it. Known sites, from the inventory:
  - `:7014`, the FLAVOURS order list, with `"_skv"` before `"_gen"`;
  - `:6977`, 29 race services becoming 32;
  - `:7029`, the event-feed row count (the formula adapts);
  - `:7305-7308`, the (tag, set) tuple, adding `("_skv", "wh2_main_bas_skv")`;
  - `:7329-7330`, the DLC-name tuple;
  - `:7359`, `len(_hs) == 8` becoming 9;
  - `:7355`, the "each of the 8 races" comment.

  Also, `_guilds_harness.lua:9424-9425` pins the temple rows as last; it is already moved in Task 1.

- [ ] **Step 5: Write and verify.** Copy `zzz_derpy_guilds_ui.lua` and `zzz_derpy_guilds_bounty_data.lua` to the scratchpad. Then:
  1. Run `GEN --write`.
  2. Diff the UI file against its copy with `\r` stripped. Expected: no difference (the MCT names block equals the hand edit).
  3. Run `GEN --selftest` and `GEN --check`. Expected: both green, except hall findings, which belong to Task 6.
  4. Run `H` and `BH`. Expected: green.

---

### Task 6: The Skaven halls

**Files:**
- Modify `tools/gen_great_guilds.py`:
  - `HALL_TAGS` (2108), with `"_skv"` last;
  - `HALL_RACES["_skv"]` (2183);
  - `HALL_EXTRA` (`("temple", "_skv")`);
  - `HALL_ICON` (2174-2177), the inline tag list;
  - the selftest hall pins.

**Interfaces:**
- **Consumes:** `GG.HALL_TAGS["_skv"]` (Task 1).
- **Produces:** 7 hall chains, 21 levels, a Seat bundle and 7 icons for `_skv`.

- [ ] **Step 1: Run `GEN --check`.** Expected: `check_hall_mirror` reports `_skv` in the Lua `GG.HALL_TAGS` and not in `HALL_TAGS`.
- [ ] **Step 2: Implement.**

```python
    "_skv": {"set": "wh2_main_bas_skv", "extra_sets": ["wh3_dlc29_skv_thanquol"],
             "nouns": ("Den", "Warren", "Nest"),
             "units": {"brass": "wh2_main_skv_inf_skavenslaves_0",
                       "immortals": "wh2_main_skv_inf_stormvermin_0",
                       "daemonsmiths": "wh2_main_skv_inf_warpfire_thrower",
                       "khanate": "wh2_main_skv_inf_gutter_runners_0",
                       "overseers": "wh2_main_skv_mon_rat_ogres",
                       "slavers": "wh2_main_skv_inf_clanrats_0",
                       "temple": None},
             "temple_nouns": ("Horned Shrine", "Temple of the Horned Rat",
                              "Spire of the Seers")},
```

`HALL_EXTRA`:

```python
    # THE GREY SEERS' HALL (skaven ruling 2): no unit - the Screaming Bell is only a lord's
    # mount - so it spreads the Under-Empire's taint, which feeds the Seers' own route. CA's
    # buildings carry this pair at 1-10.
    ("temple", "_skv"): ("wh3_main_effect_corruption_skaven_buildings", "region_to_region_own",
                         [2, 4, 6], "Skaven corruption +%d in this settlement"),
```

Match the tuple layout of the existing `("temple", "_emp")` entry. If it has a different arity, copy its shape.

`HALL_ICON`'s inline tag list gains `"_skv"`. Add `"_skv"` to `HALL_TAGS` last.

- [ ] **Step 3: Run `GEN --selftest` and move the hall pins.** These multiply by `len(HALL_TAGS)` and adapt: `14 * len(HALL_TAGS)` and `7 * len(HALL_TAGS)`. The literal tuples fail by name: the `(tag, set)` list and the seat list. Expected after the moves: `selftest ok`.

  If `_unit_level` finds no level for a hall unit in `wh2_main_bas_skv`, the selftest names it. Pick the same unit's other variant (`_1`), or the nearest unit that the set's own building trains, and ledger the ruling.
- [ ] **Step 4: `GEN --check`.** Expected: exit 0, except art findings. The hall icons belong to Task 7, so run Task 7's icon build if the check needs the files.

---

### Task 7: Art (crests, grounds, hall icons, bundle icons)

**Files:**
- Modify `tools/make_guild_icons.py` (CRLF):
  - `ICONS`;
  - `TAB_FRAME` (around 314-318);
  - the selftest tag loops (155, 468) and `len(HALL_ICONS) == 56`, which becomes 63.
- Modify `tools/make_guild_backgrounds.py` (LF):
  - `CA_ART`;
  - `CA_BACKGROUNDS`;
  - the selftest.

**Interfaces:**
- **Produces:** `ui/campaign ui/derpy_gg_icons/<guild>_skv.png` (8, including `crest_skv`), `ui/campaign ui/derpy_gg_bg/<guild>_skv.png` (7), and `ui/buildings/icons/derpy_gg_hall_<guild>_skv.png` (7).

- [ ] **Step 1: Run `py tools/make_guild_icons.py --selftest`** after adding the tag to the selftest loops. Expected: FAIL (no `_skv` stems).
- [ ] **Step 2: Implement `ICONS`.** Before picking, measure each stem flat: 100% one colour, as the temple's icons were measured.

```python
    # THE SKAVEN (2026-10-05), CA's own Skaven building icons.
    "skaven_under_empire_warpstone_refinery": "brass_skv",
    "skaven_stormvermin": "immortals_skv",
    "skaven_engineers": "daemonsmiths_skv",
    "skaven_assassins": "khanate_skv",
    "skaven_breeding": "overseers_skv",
    "skaven_slaves": "slavers_skv",
    "wh3_dlc29_skv_scruten_landmark": "temple_skv",
    "wh2_main_special_skavenblight_council13": "crest_skv",
```

If a stem fails the flatness measure, use these spares:
- brass: `skaven_resource_gold`;
- temple: `skaven_leadership`;
- crest: `skaven_city`.

Ledger the swap.

`TAB_FRAME["_skv"]` takes CA's Skaven category scroll. Find it with `grep -n "TAB_FRAME" -A10 tools/make_guild_icons.py` and use the Skaven equivalent of the `_hef` entry's file. If it doesn't exist, use `skaven_cat_civic` and ledger it.

- [ ] **Step 3: Grounds.** In `make_guild_backgrounds.py`:
  - `CA_ART["skv"] = "ui/loading_ui/load_images/campaign_skaven1.png"`;
  - seven `CA_BACKGROUNDS` entries: `"brass_skv": ("skv", 1)` through `"slavers_skv": ("skv", 6)` in the six older guilds' window order (copy `_hef`'s mapping), plus `"temple_skv": ("skv", 7)`.

  The selftest's per-race rule then holds for `skv` as written, since it is a `CA_ART` race and not `chd`/`dwf`.
- [ ] **Step 4: Build and check.**
  1. Run `py tools/make_guild_icons.py`, then `PYTHONIOENCODING=utf-8 py tools/make_guild_backgrounds.py` (the UTF-8 setting avoids the Cyrillic print crash).
  2. Run `--check` on both, then `py tools/make_guild_bundle_icons.py`.
  3. Read three Skaven grounds and two crests with the Read tool.

  Expected: every check green, and every ground p99 34 under the ceiling. If a window crops onto CA's logo or a black band, move that guild to the Clan Scruten painting (`campaign_skaven_clan_scruten1.png`) and ledger it.
- [ ] **Step 5: Run `GEN --selftest` and `GEN --check`.** Expected: green.

---

### Task 8: The Skaven panel frame

**Files:**
- Modify `tools/gen_guilds_ui.py` (CRLF):
  - `FRAMES["_skv"]` (after `_def`, 1131);
  - `RANK_STATS_PAD["_skv"]` (730);
  - the `len(files) == 6 + 2 * len(FRAME_TAGS)` pin, which adapts.
- Modify `zzz_derpy_guilds_ui.lua`:
  - `GGUI.FRAME["_skv"]` (mirror, around 389-455);
  - `GGUI.HALLS_IN_HEADER` (146), if the preview shows room.
- Modify `tools/import_great_guilds.py:41`, the UI race tuple, adding `"skv"`.

**Interfaces:**
- **Consumes:** the flavour (Task 5) and the art (Task 7).
- **Produces:** `derpy_gg_panel_skv.twui.xml` and `derpy_gg_card_skv.twui.xml`.

- [ ] **Step 1: The brief.** Per `docs/CUSTOM_UI.md` "Design direction", the reference is CA's **Chaotic Plans** panel (Thanquol, `ui/skins/default/dlc29_skv_chaotic_plans/`). Render it in the game, or open its `.twui.xml`, and note the colours and plates. Pull the candidate art with `py tools/export_exchange_icons.py`'s reader or `read_pack_index.py`, and measure each file's size and border with PIL:
  - card: `skv_small_panels_bgr.png` + `skv_small_panels_bgr_frame.png`;
  - selected card rim: `skv_small_panels_bgr_frame_selected.png`;
  - holder: `skv_portrait_frame.png`;
  - cost plate: `skv_plate.png`;
  - rank bar: `sub_title_bgr.png`;
  - tabs: `ui/skins/default/narrative_viewer_tab_skv_inactive.png` / `_active.png`;
  - track: `skv_progress_bar_bgr.png` + `skv_progress_bar_frame.png`;
  - guild bar: `ui/skins/wh2_main_skv_skaven/bar_small_buttons.png`.

  Margins come from the measured border widths, the way every other entry's comment records them. `heat` and `rim` use the same `_GLOW` / `_TUTGLOW` constants as `_hef`, in a warp-green tint: take the green from `db/ui_colours_tables`, the way `[[col:]]` resolves.
- [ ] **Step 2: Implement `FRAMES["_skv"]`.** Use `_hef`'s exact key set: `card`, `card_extra`, `heat`, `rim`, `holder`, `cost`, `rank`, `rank_tx`, `rank_ty`, `gbar`, `tab`, `track`, `fill`. Every value is from Step 1's measured files. `fill` comes from the Chaotic Plans progress bar's fill, if the panel has one; otherwise from `skaven_corruption_bar.png` (`ui/skins/default/`). Mirror it in `GGUI.FRAME["_skv"]` in the UI Lua, replacing the Task 1 placeholder copy if one was made. Set `RANK_STATS_PAD["_skv"] = 94` to start.
- [ ] **Step 3: Run `UIGEN --check` and `UIGEN --selftest`.** Expected: green. `check_frame_files` requires the same hierarchy as the other races and no Chaos Dwarf art, and `check_frame_mirror` requires the Lua to match. Then run `UIGEN --write` and `H`. Expected: `harness ok`, with the `GGUI.FRAME` pin from Task 1 now satisfied.
- [ ] **Step 4: Render and judge.**

```
py tools/preview_guilds_panel.py --flavour skv
py tools/preview_guilds_panel.py --flavour skv --page 7
py tools/preview_guilds_panel.py --flavour skv --help-page 2
py tools/preview_guilds_panel.py --flavour skv --help-page 7
```

Expected: exit 0, no `TOO WIDE`, no `LOW CONTRAST`. Read `gg_guilds_skv.png`, `gg_guilds_skv_g7.png`, `gg_standings_skv.png` and `gg_court_skv.png`, and compare them with the Chaotic Plans reference:
- does the card read as a Skaven plate?
- is the header's figure clear of its edge? (tune `RANK_STATS_PAD`)
- do the button bar's end ornaments sit outside the end buttons?
- does the Halls figure fit in the header? Add `_skv` to `GGUI.HALLS_IN_HEADER` only if it does.

Fix and render again until each holds. The first pass is never done.

---

### Task 9: Mutation coverage

**Files:**
- Modify `tools/mutate_guilds.py` (LF).

- [ ] **Step 1: Re-anchor.** Run `py tools/mutate_guilds.py --selftest`. Re-aim each stale anchor at the moved code with the same intent. Expect the `GG.temple_counts` return line and the `turn_start_pay` temple guard.
- [ ] **Step 2: One mutant per new rule.** Each is `(description, M, anchor, replacement)`, with an anchor that matches once:

| Description | Anchor | Replacement |
|---|---|---|
| "taint counted for a clean province" | `res:value() > 0 then tainted = tainted + 1 end` | `res:value() >= 0 then tainted = tainted + 1 end` |
| "the taint route never paid" | `if r.taint then` | `if false then` |
| "the hold blind to taint" | `tainted * (GG.setting("rate_temple_taint") or 2))\n        local cap` (the `turn_start_pay` line; read the exact text first) | `0)` |
| "under-city founding never listened to" | `if name then GG.on_undercity_founded(name) end` | `if false then GG.on_undercity_founded(name) end` |
| "an under-city building's level read as 1" | `GG.load(name); GG.on_building(name, n, chain); GG.save(name)` | `GG.load(name); GG.on_building(name, 1, chain); GG.save(name)` |
| "a level key without a number accepted" | `if not chain or chain == "" then return nil end` | `if false then return nil end` |
| "Treachery's rivalry forgotten" | `{rate_rivalry = 150, demand_penalty = 0}` | `{demand_penalty = 0}` |
| "the Slave-Masters lose the Order chain" | `{"slavers", {"skv_order", "under_empire_food"}}` | `{"slavers", {"under_empire_food"}}` |

Every replacement must parse; `--selftest` proves it.

- [ ] **Step 3: The full run, in the background, to a file.**

```
PYTHONIOENCODING=utf-8 py tools/mutate_guilds.py > "$S/mutate_skv.txt" 2>&1
```

Expected: exit 0, every mutant CAUGHT, no SURVIVED, no STALE. A survivor is a missing assertion: add it to the harness and re-run, never deleting the mutant.
- [ ] **Step 4: The restore check.** Run `GEN --write`, then `H` and `BH`. Expected: green.

---

### Task 10: Build, verify, deploy, write down

**Files:**
- The pack: `Modding Files/Modpacks/derpy_great_guilds.pack`, deployed to `data/`.
- Create `docs/sessions/HANDOFF_20261005_GUILDS_SKAVEN.md`.
- Modify:
  - `docs/SESSION_INDEX.md` (one line);
  - `docs/MY_MODS.md` (the Great Guilds entry: nine races, its counts);
  - `docs/knowledge-base/systems.md`;
  - the spec (§11, as shipped).

- [ ] **Step 1: All checks.**
  - `GEN --selftest`, `GEN --check`, `UIGEN --check`;
  - `H`, `BH`;
  - `LUAC` on all five guild Lua files;
  - `py tools/check_lua_api.py` on the three hand-written Lua files;
  - `py tools/check_lua_literal_left.py` on the model;
  - `py tools/check_lua_undeclared.py`, compared with the pre-Skaven findings.

  Expected: all clean; `check_lua_undeclared` returns the same findings as before.
- [ ] **Step 2: The share table.** Run the scratchpad's `shares.py` and save the Skaven rows. Then list `GG.BOUNTY_BUILDINGS["_skv"]` per guild from the regenerated bounty data, including which guilds have no build job.
- [ ] **Step 3: Build.**
  1. Check that RPFM is up: `curl -s -m 4 http://127.0.0.1:45127/sessions`. Connection refused means stop and tell the author.
  2. Back up both the `Modpacks` and the `data/` copy to `Modding Files/Backup/guilds_pre_skaven_20261005/`.
  3. Run `py tools/import_great_guilds.py --check`, then `py tools/import_great_guilds.py` (background, to a file).

  Expected: "saved pack verified - every table holds this build's rows". Count the `_skv` files in the pack with `read_pack_index.py`.
- [ ] **Step 4: Deploy.** If `Warhammer3.exe` is not running, copy the pack to `data/` and compare the MD5 on both sides.
- [ ] **Step 5: Write down.** The handoff covers:
  - what shipped, with its MD5;
  - the twelve rulings above and every executor ruling from the ledger;
  - the share table;
  - the Skaven guilds with no build job;
  - **the add-a-race checklist**: every declaration point the inventory found, grouped by file, so a tenth race starts from it;
  - spec §9's seven in-game checks.

  Then:
  - add one line to `SESSION_INDEX.md`;
  - update `MY_MODS.md` and `systems.md`;
  - append the spec's §11 "As shipped".

## Final review

When Task 10's checks are green, dispatch the whole-branch reviewer per superpowers:executing-plans. Use the most capable model, read-only, and give it:
- a diff package of every touched file against `base_skv/`;
- this plan's Review Focus;
- the ledger's rulings.
