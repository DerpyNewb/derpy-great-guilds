# The Great Guilds: the seventh guild (temple) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a seventh guild, key `temple`, to The Great Guilds for the eight supported races: reputation, ranks, four earn routes, nine services, a bounty, a hall, a panel page, art and text, in one build.

**Architecture:** The campaign Lua (`zzz_derpy_guilds.lua`) is the model and runs in game; the generator (`tools/gen_great_guilds.py`) writes every DB row and loc line and mirrors the model's tables with checks; the panel Lua and `tools/gen_guilds_ui.py` draw it; two Lua harnesses and a mutation runner prove the rules. Every list that counts guilds is appended to, never reordered, because saves are positional.

**Tech Stack:** Lua 5.1 (game and `lua.exe`), Python 3 (`py`), RPFM MCP server for the pack build, PIL for art.

**Spec:** `docs/superpowers/specs/2026-10-04-great-guilds-temple-guild-design.md` (approved 2026-10-04, amended the same day with the rulings in "Rulings" below).

## Global Constraints

- The workspace is **not a git repository**. There are no commit steps. The checkpoint at the end of each task is its harness or check run going green. Back up the deployed pack to `Modding Files/Backup/` before a deploy, never into `data/` or a Workshop folder.
- `temple` is appended LAST everywhere a guild list exists (`GG.GUILDS`, `GUILDS`, `GGUI.GUILD_ORDER`, `GG.TUNE_ORDER`, `GG.SERVICES`, `GG.LEDGER_SOURCES`). Saves are positional.
- Line endings: **LF** in `gen_great_guilds.py`, `make_guild_backgrounds.py`, `mutate_guilds.py`, `_guilds_bounty_harness.lua`, `zzz_derpy_guilds.lua`. **CRLF** in `gen_guilds_ui.py`, `make_guild_icons.py`, `preview_guilds_panel.py`, `import_great_guilds.py`, `_guilds_harness.lua`, `zzz_derpy_guilds_ui.lua`, `zzz_derpy_guilds_ai.lua`, `script/mct/settings/derpy_great_guilds.lua`. Edit CRLF files with the Edit tool or byte-level Python, never `sed -i`. Never put a backslash or regex inside a heredoc.
- Every pinned total in a test moves to the new total. A test is never loosened.
- Player text: Reputation and Favour, plain words, no jargon, no "rung", no emojis.
- Lua runs float32 in game. An integer multiply then divide, never a decimal literal. In a function with over 255 constants, no number literal on the LEFT of an arithmetic operator.
- Keys fail silently. Every culture, subtype, unit and effect key below was read from the installed `db.pack` on 2026-10-04. Task 5's checks re-read them on every build.
- `tools/*.py` have no `--help`. `import_great_guilds.py` BUILDS the pack on any unknown flag.
- The mutation runner edits the shipped Lua in place. Never build or deploy while it runs.
- Commands, from `G:\Modding for resources`:
  - `H` = `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua` (prints `harness ok` last)
  - `BH` = `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua` (prints `bounty harness ok`)
  - `GEN` = `py tools/gen_great_guilds.py` (`--selftest`, `--check`, `--write`; about 2 minutes, run it in the background)
  - `LUAC` = `"/c/Program Files (x86)/Lua/5.1/luac.exe" -p <file>`

## Rulings (decided at plan time, for the author's review)

1. **Bounty, not demand.** The code has no building demand. Demands are `tribute` and `renounce` only, and the temple, having no rival, only ever rolls `tribute`. The spec's "demand: complete a temple" is the `job_build` bounty every guild already posts. Its targets come from the generated `GG.BOUNTY_BUILDINGS`, which lists only the third or later level of a chain. A race whose temple chains are shorter gets no temple build job. Task 10 reports which races have one.
2. **AI buying needs no code.** `GGAI.choose` weights every buyable service by `cost/50`, so the nine rows join on their own.
3. **The temple's routes are not behind `race_differences`.** They are the guild's base income, as battles are the soldiers'. Switching race differences off still leaves the temple an income.
4. **Devout counts provinces, not settlements.** Public order belongs to the province, so counting regions would pay one province once per settlement in it.
5. **Three hall units would duplicate an existing hall.** Dwarf Slayers are the Grudge-Settlers' hall unit, Bretonnian Battle Pilgrims the Crusaders', High Elf Phoenix Guard the Loremasters'. Picks:
   - Dwarfs: **Giant Slayers** `wh2_dlc10_dwf_inf_giant_slayers` (unit level 0, owned by every Dwarf player).
   - Bretonnia: **Grail Knights** `wh_main_brt_cav_grail_knights` (level 2: trained from the top hall level only).
   - High Elves: **Phoenix Guard** stays, the one duplicate. It is the Cult of Asuryan's own order, and no other Asuryan unit is trained by any High Elf building (the two Phoenixes are not in the set).
6. **Rank ladder +1/+2/+3/+4 public order** needs a per-guild value table (`RANK_VALUES_OF`). The leader's bundle is +3, the rank-4 value, as for every guild.
7. **Hall bonus:** `wh_main_effect_public_order_base` at `province_to_province_own_unseen`, 2/4/6. It is CA's standard building public-order pair (642 rows, -10..20). The visible pair has two vanilla rows of 2, so 6 would fail the 1.5x range check. The card line is hidden, but the hall's description states it. The Seat uses the same effect at `faction_to_province_own` (7 rows, -7..10), value 2.
8. **Every temple bundle service carries its own effects.** The shared `SERVICE_VALUES` 20/32/45 would put +45 public order on a rank-4 bundle.
9. **MCT:** the three rate keys stay as specified (`rate_temple_devout`, `rate_temple_chaos`, `rate_temple_holy`). `check_mct_names` learns that the temple's rates are those three. Their labels name the route, not the race, and `GGUI.name_mct` renames `cap_temple` only.
10. **The generic flavour `_gen`** carries the full temple data shape (name, description, bounty, nine service names, an icon and a background), because the shape checks demand it. It still has no panel and no gameplay.
11. **Help page 2** stays at 18 lines. The seventh guild bullet costs one line, so the "#Every guild at once" heading goes, and its mission bullet moves up under the building bullet.
12. **Shared building words are untouched.** Bare `temple`/`shrine` catch the wrong chains, so every move is an explicit race-only token.
13. **The `gg_gtab_*` table stays hand-written** in the panel Lua. `gen_guilds_ui.py`'s existing `_lua_xy_tables` mirror check already fails on any drift.

## Review Focus

1. **An old six-guild save.** It loads with the temple at 0/0, and every cooldown stays on its own service. The drawn cards reset to defaults (an 18-key cards value is discarded). Pinned in Task 1.
2. **A campaign whose settings were frozen before the update.** Its tune string lacks the four new keys and must read the defaults (1, 2, 10, 40). Pinned in Task 1.
3. **A race with no route.** The Empire's devout provinces and Cathay's battles pay the temple nothing. Pinned in Task 3.
4. **A holy-war bounty when no faction of the holy cultures is at war with the player.** The army bounty gets no target, the guild posts another kind, and nothing throws. Pinned in Task 4.
5. **A foreign chain held by a covered race.** A Dwarf faction holding `wh2_main_special_shrine_of_asuryan_other` must not pay the Ancestor Temples, because race tokens are explicit and no shared word moves. Pinned in Task 2.

---

### Task 1: The temple in the model's tables

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`:
  - `GG.GUILDS` (line 14)
  - `GG.CAP` (~345)
  - `GG.BOUNTIES` / `GG.BOUNTY_EXTRA` (~768-783)
  - `GG.SERVICES` (end, ~3102)
  - `GG.TUNE_DEFAULTS` / `GG.TUNE_ORDER` / `GG.PRESETS` (~4571-4760)
  - `GG.LEDGER_SOURCES` (~5533)
- Modify: `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` (CRLF): `RATES`, `CAPS`, `PRESET_OWNED`
- Test: `tools/_guilds_harness.lua` (CRLF), `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Produces:
  - `GG.GUILDS[7] == "temple"`
  - the nine service keys `hashut_blessing, forge_sermons, temple_tithe, zeal, purge_unclean, anathema, holy_war, miracle, consecration`, in that order, after `asuryans_grace`
  - tune keys `rate_temple_devout` (1), `rate_temple_chaos` (2), `rate_temple_holy` (10), `cap_temple` (40)
  - ledger sources `devout, chaos, holywar, priests`

- [ ] **Step 1: Write the failing harness block.** Append before the final `print("harness ok")` in `tools/_guilds_harness.lua`, with CRLF line endings:

```lua
;(function()
    -- THE SEVENTH GUILD (temple spec 2026-10-04): appended last, and an old save reads.
    assert(#GG.GUILDS == 7 and GG.GUILDS[7] == "temple", "temple is the seventh guild")
    assert(GG.RIVALS.temple == nil, "the temple has no rival")
    assert(GG.CAP.temple == 40, "the temple's cap mirrors RATES")
    local keys = {}
    for i = 1, #GG.SERVICES do
        if GG.SERVICES[i].guild == "temple" then keys[#keys + 1] = GG.SERVICES[i].key end
    end
    assert(table.concat(keys, ",") == "hashut_blessing,forge_sermons,temple_tithe,zeal,"
        .. "purge_unclean,anathema,holy_war,miracle,consecration", "nine temple services")
    assert(GG.SERVICES[#GG.SERVICES].key == "consecration", "the temple's rows come last")
    -- AN OLD SAVE: six standing pairs and the 83 cooldowns it had before the temple.
    local F = "cr_temple_oldsave"
    local cds = {}
    for i = 1, 83 do cds[i] = "0" end
    cds[83] = "5"                                -- asuryans_grace, the old last row
    saved["derpy_gg_" .. F] = "10,1|20,2|30,3|40,4|50,5|60,6;" .. table.concat(cds, "|")
    GG.state[F], GG.cooldowns[F] = nil, nil
    GG.load(F)
    assert(select(1, GG.get(F, "slavers")) == 60, "the six pairs load where they were")
    local r, f = GG.get(F, "temple")
    assert(r == 0 and f == 0, "the temple starts at 0,0 in an old save")
    assert(GG.cooldowns[F].asuryans_grace == 5, "cooldowns keep their positions")
    assert((GG.cooldowns[F].consecration or 0) == 0, "a new row has no cooldown")
    -- A CAMPAIGN FROZEN BEFORE THE TEMPLE: its settings string lacks the four new keys.
    local fields = {}
    for v in string.gmatch(GG.pack_tune(GG.TUNE_DEFAULTS), "[^|]+") do fields[#fields + 1] = v end
    local t = GG.unpack_tune(table.concat(fields, "|", 1, #fields - 4))
    assert(t.rate_temple_devout == 1 and t.rate_temple_chaos == 2
           and t.rate_temple_holy == 10 and t.cap_temple == 40,
           "an old settings string reads the temple's defaults")
    for _, src in ipairs({"devout", "chaos", "holywar", "priests"}) do
        assert(GG.LEDGER_KNOWN[src], "ledger source " .. src)
    end
    GG.state[F], GG.cooldowns[F], saved["derpy_gg_" .. F] = nil, nil, nil
end)()
```

If the harness names its saved-value table differently, use the name its `cm.set_saved_value` stub writes into, which is `saved` at `tools/_guilds_harness.lua:25-47`.

- [ ] **Step 2: Run `H`.** Expected: FAIL. The first failure is `assert(#GG.GUILDS == 6, "six guilds")` at line 308, or the new block's "temple is the seventh guild".

- [ ] **Step 3: Implement the model tables.** In `zzz_derpy_guilds.lua`:

```lua
GG.GUILDS = {"brass", "immortals", "daemonsmiths", "khanate", "overseers", "slavers",
             "temple"}
```
```lua
GG.CAP = {brass = 40, immortals = 60, daemonsmiths = 0,
          khanate = 40, overseers = 40, slavers = 80, temple = 40}
```

`GG.BOUNTIES`: add `temple = "lord_kill",` (the holy war, Task 4).

`GG.BOUNTY_EXTRA`: add `temple = {"job_build"},`.

After the `asuryans_grace` row, before the closing `}` of `GG.SERVICES`:
```lua
    -- THE TEMPLE (2026-10-04, temple spec §4). After every other row: cooldowns are saved by
    -- position, so a row anywhere else would move every saved cooldown after it.
    {key="hashut_blessing", guild="temple",       rank=2, cost=50,  cd=8,  kind="army",       turns=5},
    {key="forge_sermons",   guild="temple",       rank=2, cost=50,  cd=8,  kind="settlement", turns=8},
    {key="temple_tithe",    guild="temple",       rank=2, cost=50,  cd=8,  kind="gold",       value=2000},
    {key="zeal",            guild="temple",       rank=3, cost=150, cd=12, kind="army",       turns=5},
    {key="purge_unclean",   guild="temple",       rank=3, cost=150, cd=12, kind="settlement", turns=8},
    {key="anathema",        guild="temple",       rank=3, cost=150, cd=12, kind="enemy_settlement", turns=5},
    {key="holy_war",        guild="temple",       rank=4, cost=400, cd=16, kind="bundle",     turns=10, lead=true},
    {key="miracle",         guild="temple",       rank=4, cost=400, cd=16, kind="army",       turns=2, heal=true, lead=true},
    {key="consecration",    guild="temple",       rank=4, cost=400, cd=16, kind="bundle",     turns=12, lead=true},
```

`GG.TUNE_DEFAULTS`: after `rate_patron = 50,`, add:
```lua
    -- THE TEMPLE'S ROUTES (temple spec §3.2). Per province in good order, per province free
    -- of corruption, and per holy-war battle won.
    rate_temple_devout = 1, rate_temple_chaos = 2, rate_temple_holy = 10,
    cap_temple = 40,
```

`GG.TUNE_ORDER`: append after `"hall_off",`:
```lua
    "rate_temple_devout",
    "rate_temple_chaos",
    "rate_temple_holy",
    "cap_temple",
```

`GG.PRESETS`: add to each named preset, keeping each preset's direction (easy faster, hard and ultra slower):
- easy: `rate_temple_devout = 2, rate_temple_chaos = 3, rate_temple_holy = 15, cap_temple = 60,`
- hard: `rate_temple_devout = 1, rate_temple_chaos = 1, rate_temple_holy = 7, cap_temple = 30,`
- ultra: `rate_temple_devout = 1, rate_temple_chaos = 1, rate_temple_holy = 5, cap_temple = 22,`

`GG.LEDGER_SOURCES`: append after `"captives", "court"`:
```lua
                     -- THE TEMPLE'S ROUTES (2026-10-04).
                     "devout", "chaos", "holywar", "priests"}
```

- [ ] **Step 4: Implement the MCT rows** in `script/mct/settings/derpy_great_guilds.lua` (CRLF).

In `RATES`, after the `rate_slavers` row:
```lua
    {"rate_temple_devout", "The Faith Guild: provinces in good order", 1, 0, 10,
     "Points per province with public order above zero, every turn."},
    {"rate_temple_chaos", "The Faith Guild: provinces free of corruption", 2, 0, 10,
     "Points per province with no Chaos corruption, every turn."},
    {"rate_temple_holy", "The Faith Guild: holy wars", 10, 0, 60,
     "Points per battle won against the faith's sworn enemies."},
```

In `CAPS`, after `cap_slavers`: `{"cap_temple", "The Faith Guild", 40},`

In `PRESET_OWNED`, after `"hall_rep",`: `"rate_temple_devout", "rate_temple_chaos", "rate_temple_holy", "cap_temple",`

- [ ] **Step 5: Move the pinned totals** in `tools/_guilds_harness.lua`:
  - :308 `#GG.GUILDS == 6` becomes `== 7` ("seven guilds").
  - :874 `#L == 6` becomes `#L == 7`.
  - :6830 `n == 12` becomes `n == 14` ("seven rate and seven cap renames").
  - :8852, 8879, 8883, 9088, 9100, 9117, 9230, 9318: `18` becomes `21` (7 guilds x 3 hall levels). The hall chains do not exist until Task 6, so run `H` after Task 6 for those eight. This step only edits them.
  - :1318-1325, the rivals loop: skip a guild whose `GG.RIVALS[guild]` is nil, and keep `seen == #GG.GUILDS`.
  - In `tools/_guilds_bounty_harness.lua`, `#keys == 18` (:1391) counts cards, which become 21: `== 21`. `keys[18] == "great_coffle"` stays.

- [ ] **Step 6: Run `H` and `BH`.** Expected: the new block passes. The other failures allowed are these, each recorded with the task that clears it:
  - the hall totals of Step 5 (Task 6);
  - a panel block that reads `GGUI.GUILD_ICON.temple` or `GGUI.PANEL_BG.temple` (Task 7);
  - a panel block that reads `GGUI.GUILD_ORDER` against `GG.GUILDS` (Task 8).

  Anything else is this task's fault. Run `LUAC` on both edited Lua files: exit 0.

---

### Task 2: Race-only building words

**Files:**
- Modify: `zzz_derpy_guilds.lua`: `GG.guild_of_chain` (~619), `GG.on_building` (~656), new `GG.BUILDING_THEME_RACE` after `GG.BUILDING_THEME`
- Modify: `tools/gen_great_guilds.py`: `building_theme` (4518), `guild_of_chain` (4528), `built_tables` (4583), `_lua_guilds_of` (4622), `check_built_effects` (4647), `check_building_theme` (4368), `bounty_buildings` (~4902)
- Test: `tools/_guilds_harness.lua` (the block at :5074-5142)

**Interfaces:**
- Produces:
  - `GG.guild_of_chain(chain, tag)`, where `tag` is optional; nil means the shared words only.
  - `GG.longest_token(chain, theme)`
  - Python `building_theme_race() -> {tag: [(guild, [tokens])]}` and `guild_of_chain(chain, theme, race=None)`

- [ ] **Step 1: Write the failing test.** Append a block to `_guilds_harness.lua`:

```lua
;(function()
    -- RACE WORDS (temple spec §3.1): checked before the shared list, per flavour tag.
    local G = GG.guild_of_chain
    assert(G("wh3_dlc23_chd_tower_temple_of_hashut", "") == "temple", "CHD temple")
    assert(G("wh3_dlc23_chd_tower_temple_of_hashut") == "overseers", "no tag, shared words")
    assert(G("wh3_dlc23_chd_tower_temple_guardhouse", "") == "immortals", "Fane Guard stays")
    assert(G("wh2_main_special_ancestors_hall", "_dwf") == "temple", "Ancestors' Hall")
    assert(G("wh_main_DWARFS_slayers", "_dwf") == "temple", "Slayer shrine")
    assert(G("wh2_main_special_shrine_of_asuryan_other", "_dwf") ~= "temple",
           "a foreign shrine a Dwarf holds is not the Ancestor Temples'")
    assert(G("wh_main_empire_worship", "_emp") ~= "temple", "Shrines of Sigmar stay Masons")
    assert(G("wh2_main_def_worship", "_def") == "temple", "Altar of Khaine")
    assert(G("wh_main_EMPIRE_tavern", "_emp") == "khanate", "the Thieves' Guild's tap room")
    assert(G("wh_main_EMPIRE_tavern", "_brt") == "brass", "other races keep the shared word")
    -- What a completed building pays, with the owner's tag.
    local F = "cr_temple_build_chd"
    GG.CULTURE_OF[F] = "wh3_dlc23_chd_chaos_dwarfs"
    GG.state[F] = nil
    GG.on_building(F, 1, "wh3_dlc23_chd_tower_temple_of_hashut")
    assert(select(1, GG.get(F, "temple")) == 10, "a CHD temple pays the Temple of Hashut")
    assert(select(1, GG.get(F, "overseers")) == 0, "and not the Overseers")
    GG.state[F], GG.CULTURE_OF[F] = nil, nil
end)()
```
If `GG.on_building` needs `GG.turn_gain` reset for a fresh faction, set `GG.turn_gain[F] = {}` first. This is the shape the existing building blocks at :5074-5142 use.

- [ ] **Step 2: Run `H`.** Expected: FAIL at "CHD temple" (it returns `"overseers"`).

- [ ] **Step 3: Implement in the model.** Replace the body of `GG.guild_of_chain` and add the race table. Keep the existing pattern-matching comment verbatim inside `GG.longest_token`.

```lua
-- WORDS THAT MEAN ONE GUILD IN ONE RACE (temple spec §3.1, 2026-10-04), keyed by flavour tag
-- (GG.tag). Checked BEFORE the shared list: a chain one of these matches belongs to that
-- guild outright, so a word can mean the Thieves' Guild in the Empire and the Brass Tablets
-- everywhere else. Every token is a whole readable run verified against that race's chains;
-- the bare words temple and shrine are never used, because they catch the Chaos Dwarf Fane
-- Guard and the foreign shrines a faction can hold. check_building_theme mirrors this.
GG.BUILDING_THEME_RACE = {
    [""] = {
        {"temple", {"temple_of_hashut", "defaced_shrine"}},
    },
    ["_emp"] = {
        {"temple", {"empire_wizards", "college_of_magic", "spiriters_study",
                    "chamber_of_the_dark_lady", "elemental_temple",
                    "convent_of_sorcery_emp", "tower_of_hoeth_emp"}},
        {"daemonsmiths", {"nuln_gunnery"}},
        {"khanate", {"empire_tavern", "ubersreik_inn"}},
        {"slavers", {"shooting_range", "militia_of_morr", "emp_allied_outpost"}},
        {"immortals", {"chapterhouse", "empire_stables", "empire_fort_emp",
                       "castle_reikguard"}},
    },
    ["_dwf"] = {
        {"temple", {"ancestors_hall", "dwarfs_slayers", "slayer_shrine"}},
    },
    ["_brt"] = {
        {"temple", {"bretonnia_worship", "holy_monastery", "legendary_bretonnia"}},
        {"daemonsmiths", {"carcassonne"}},
        {"khanate", {"bretonnia_tavern"}},
        {"immortals", {"bretonnia_stables", "parravon_peaks"}},
        {"slavers", {"brt_allied_outpost", "copher_port"}},
        {"brass", {"industry_extra"}},
        {"overseers", {"bretonnia_smith"}},
    },
    ["_cth"] = {
        {"temple", {"li_temple", "phoenix_temple", "two_moons"}},
        {"daemonsmiths", {"jade_blood", "cth_gunners", "gunpowder", "cth_artillery"}},
        {"khanate", {"cth_allied_outpost", "house_of_secrets", "foreign_slot_discovery_cth"}},
        {"slavers", {"order_y", "peasants", "bastion_1"}},
        {"immortals", {"cth_celestial", "armoury_tigers", "cth_den"}},
        {"brass", {"income_y", "great_embassy"}},
    },
    ["_ksl"] = {
        {"temple", {"ksl_gold", "kislev_city_temple", "ksl_kislev_2", "corruption_land"}},
        {"daemonsmiths", {"ice_guard", "ksl_woods", "ostankyas_hut", "erengrad_1",
                          "main_ksl_bears"}},
        {"slavers", {"ksl_cavalry", "recruit_growth_xp"}},
        {"immortals", {"ksl_stables"}},
        {"khanate", {"growth_recruit_cost"}},
    },
    ["_def"] = {
        {"temple", {"worship", "bombardment_a", "temple_of_khaine", "shrine_of_khaine",
                    "hellebron_palace"}},
        {"khanate", {"def_murder"}},
        {"daemonsmiths", {"sorcery", "bombardment_b", "bombardment_c", "pleasure_cult"}},
        {"slavers", {"def_port", "exiles", "horde_def_military", "lokhir_military",
                     "dawns_harbour_def", "talon_of_agony", "underworld_sea_gate"}},
        {"immortals", {"naggarond_blackguard", "aristocracy", "coldones"}},
    },
    ["_hef"] = {
        {"temple", {"hef_worship", "shrine_of_asuryan_hef"}},
        {"daemonsmiths", {"hef_mages", "tower_of_hoeth", "convent_of_sorcery_hef",
                          "tower_of_the_stars", "yvresse_amphitheatre"}},
        {"khanate", {"aesanar_camp", "field_hq"}},
        {"slavers", {"stables", "tiranoc_palace"}},
        {"brass", {"income_branch", "supplies_income", "economy_income"}},
        {"overseers", {"hef_smith"}},
    },
}

-- The longest token of `theme` found in `chain` (already lowercased), or nil.
function GG.longest_token(chain, theme)
    local best, best_len = nil, 0
    for rank = 1, #theme do
        local guild = theme[rank][1]
        local toks = theme[rank][2]
        for i = 1, #toks do
            local t = toks[i]
            -- (the existing MATCHED AS A PATTERN comment, moved here unchanged)
            if string.find(chain, t) and #t > best_len then
                best, best_len = guild, #t
            end
        end
    end
    return best
end

-- The guild a chain belongs to, or nil when no word matches. `tag` is the owner's flavour;
-- without it only the shared words apply.
function GG.guild_of_chain(chain, tag)
    if type(chain) ~= "string" or chain == "" then return nil end
    chain = string.lower(chain)
    local race = tag and GG.BUILDING_THEME_RACE[tag]
    return (race and GG.longest_token(chain, race))
           or GG.longest_token(chain, GG.BUILDING_THEME)
end
```

In `GG.on_building`, change the guild line:
```lua
    local guild = GG.hall_guild(chain) or GG.guild_of_chain(chain, GG.tag(faction))
                  or "overseers"
```
This multi-line form changes the mutation anchor at `mutate_guilds.py:577`; Task 9 moves it.

- [ ] **Step 4: Mirror it in the generator.**

```python
def building_theme_race():
    """{tag: [(guild, [token, ...]), ...]} exactly as GG.BUILDING_THEME_RACE declares it."""
    lua = io.open(MODEL_LUA, encoding="utf-8").read()
    block = re.search(r"^GG\.BUILDING_THEME_RACE = \{(.*?)\n\}", lua, re.S | re.M)
    if not block:
        return {}
    out = {}
    for tag, body in re.findall(r'\["(_?[a-z]*)"\] = \{(.*?)\n    \},', block.group(1), re.S):
        out[tag] = [(g, re.findall(r'"([^"]*)"', toks))
                    for g, toks in re.findall(r'\{"([a-z_]+)",\s*\{(.*?)\}\}', body, re.S)]
    return out


def guild_of_chain(chain, theme, race=None):
    """GG.guild_of_chain: the race's words first, then the shared ones; the longest token
    wins, the first-listed guild on a tie, None when nothing matches."""
    chain = chain.lower()
    for words_of in ([race] if race else []) + [theme]:
        best, best_len = None, 0
        for guild, words in words_of:
            for w in words:
                if w and w in chain and len(w) > best_len:
                    best, best_len = guild, len(w)
        if best:
            return best
    return None
```

`built_tables`: add `race = building_theme_race()` after `theme = building_theme()`, and change the guild line to `g = guild_of_chain(r["chain"], theme, race.get(tag)) or "overseers"`. Make the same change in `bounty_buildings` wherever it calls `guild_of_chain`, using that row's tag.

`_lua_guilds_of(pairs)` now takes `[(chain, tag)]`:
- Extract `^GG\.BUILDING_THEME_RACE = \{.*?\n\}`, `^function GG\.longest_token\(chain, theme\)\n.*?\nend\n` and `^function GG\.guild_of_chain\(chain, tag\)\n.*?\nend\n` with the existing theme block.
- Feed it lines of `chain\ttag`.
- Run in Lua: `for line in io.lines() do local c, t = line:match("^(.-)\t(.*)$"); io.write((GG.guild_of_chain(c, t) or '-') .. '\n') end`.
- Return `{(chain, tag): guild}`.
- Update its callers in `check_built_effects` to pass `(chain, tag)` from `covered_chains()`.

`check_building_theme`: after the shared-list checks, for each `tag, entries in building_theme_race().items()`:
- every guild must be in `GUILDS`;
- no token may carry pattern magic (the same `MAGIC` set);
- no token may appear under two guilds within that tag;
- every token must match at least one chain of that race's availability sets (`HALL_RACES[tag]["set"]` plus `extra_sets`, read with `live_rows("building_chain_availability_sets")`, column `id` for the set and `building_chain` for the chain). Report a miss as "matches no chain that race can build".

- [ ] **Step 5: Move the harness's shared-word expectation.** The `:5091-5094` line asserting `wh3_dlc23_chd_tower_temple_of_hashut == "overseers"` stays true with no tag. Keep it. The new block covers the tagged answer.

- [ ] **Step 6: Run `H`, then `GEN --check` in the background.** Expected: `harness ok`. `--check` may still fail on Task 5's data (GUILDS has no temple yet), but it must report no `check_building_theme` or `check_built_effects` finding.

- [ ] **Step 7: Print the share table.** Run `py "C:/Users/GAYAO-~1/AppData/Local/Temp/claude/g--Modding-for-resources/7c00cf0a-c27a-4d9a-9874-39935f60d18f/scratchpad/shares.py"` after Task 5 makes `temple` a generator guild. It lists every chain that changed guild per race, for the handoff (Task 10).

---

### Task 3: The four earn routes

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - new routes block after `GG.on_agent_action` (~524)
  - `GG.on_agent_action`
  - the `gg_agent_*` listener (~5269)
  - `GG.battle_award` (~6013)
  - the `gg_turn` listener (~5033)
- Test: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.capped_grant(faction, guild, amount, source)`, `GG.culture_of(faction)`, `GG.setting(key)`
- Produces:
  - `GG.TEMPLE_ROUTES[culture] = {devout=bool, chaos=bool, vampiric=bool, holy={cultures}, priests={subtypes}}`
  - `GG.temple_counts(f, r) -> devout, clean`
  - `GG.temple_turn(faction, f)`
  - `GG.temple_holy(faction)`
  - `GG.on_agent_action(faction, success, subtype)`

- [ ] **Step 1: Check the API entries.** Run `py tools/check_lua_api.py --explain provinces`, then `regions`, `public_order`, `pooled_resource_manager`, `resource`, `character_subtype_key` and `pending_battle_cache_faction_won_battle_against_culture`. Each must be documented with the receiver used below:
  - `faction:provinces()` returns a list whose items are faction-province managers carrying `regions()` and `province()`.
  - `province:pooled_resource_manager():resource(key)` gives `is_null_interface()` and `value()`.
  - If an entry disagrees, follow the entry and note it in the handoff.

- [ ] **Step 2: Write the failing test.**

```lua
;(function()
    -- THE TEMPLE'S FOUR ROUTES (temple spec §3.2), each per race, each a no for a race
    -- without it.
    local function L(t)
        return {num_items = function() return #t end,
                item_at = function(_, i) return t[i + 1] end,
                is_empty = function() return #t == 0 end}
    end
    local function prov(order, chaos, vamp)
        local amounts = {wh3_main_corruption_chaos = chaos, wh3_main_corruption_vampiric = vamp}
        return {
            regions = function() return L({{public_order = function() return order end}}) end,
            province = function() return {pooled_resource_manager = function() return {
                resource = function(_, key)
                    local v = amounts[key]
                    return {is_null_interface = function() return v == nil end,
                            value = function() return v or 0 end}
                end} end} end,
        }
    end
    local world = {prov(10, 0, 0), prov(0, 0, 5), prov(-5, 3, 0)}
    local f = {provinces = function() return L(world) end}
    local keep = GG.TUNE
    GG.TUNE = nil
    local function earned(culture, fn)
        local F = "cr_temple_" .. culture
        GG.CULTURE_OF[F] = culture
        GG.state[F], GG.turn_gain[F] = nil, {}
        fn(F)
        local r = GG.get(F, "temple")
        local k = GG.get(F, "khanate")
        GG.state[F], GG.turn_gain[F], GG.CULTURE_OF[F] = nil, nil, nil
        return r, k
    end
    -- Devout: one province above zero. Chaos: two provinces with no Chaos corruption.
    assert(earned("wh3_dlc23_chd_chaos_dwarfs", function(F) GG.temple_turn(F, f) end) == 1,
           "CHD: devout only, 1 x 1")
    assert(earned("wh_main_emp_empire", function(F) GG.temple_turn(F, f) end) == 4,
           "Empire: no devout route, chaos 2 provinces x 2")
    assert(earned("wh3_main_ksl_kislev", function(F) GG.temple_turn(F, f) end) == 1 + 2,
           "Kislev: devout 1, and only one province free of BOTH taints x 2")
    assert(earned("wh2_main_def_dark_elves", function(F) GG.temple_turn(F, f) end) == 0,
           "Dark Elves earn nothing at turn start")
    -- Holy war: the cache is asked with the race's cultures; a race without any is not asked.
    local asked
    cm.pending_battle_cache_faction_won_battle_against_culture = function(fk, cultures)
        asked = cultures
        return true
    end
    assert(earned("wh2_main_def_dark_elves", function(F) GG.temple_holy(F) end) == 10,
           "a Dark Elf win against the asur pays 10")
    assert(asked[1] == "wh2_main_hef_high_elves", "asked with the High Elf culture")
    asked = nil
    assert(earned("wh3_main_cth_cathay", function(F) GG.temple_holy(F) end) == 0
           and asked == nil, "Cathay has no holy war and is never asked")
    cm.pending_battle_cache_faction_won_battle_against_culture = function() return false end
    assert(earned("wh2_main_def_dark_elves", function(F) GG.temple_holy(F) end) == 0,
           "a win against anyone else pays nothing")
    -- Priests: a listed subtype pays the temple instead of the spies.
    local r, k = earned("wh_main_emp_empire", function(F)
        GG.on_agent_action(F, true, "wh_main_emp_bright_wizard") end)
    assert(r == 8 and k == 0, "a Bright Wizard pays the Colleges, not the Thieves")
    r, k = earned("wh_main_emp_empire", function(F)
        GG.on_agent_action(F, true, "wh_main_emp_warrior_priest") end)
    assert(r == 0 and k == 8, "a Warrior Priest still pays the Thieves")
    r, k = earned("wh3_dlc23_chd_chaos_dwarfs", function(F)
        GG.on_agent_action(F, true, "wh_main_emp_bright_wizard") end)
    assert(r == 0 and k == 8, "a race without the priests route pays the spies")
    -- The cap: 40 a turn, whatever the routes add up to.
    local big = {}
    for i = 1, 60 do big[i] = prov(10, 0, 0) end
    assert(earned("wh2_main_hef_high_elves", function(F)
        GG.temple_turn(F, {provinces = function() return L(big) end}) end) == 40,
        "the temple's cap binds its routes")
    cm.pending_battle_cache_faction_won_battle_against_culture = nil
    GG.TUNE = keep
end)()
```

- [ ] **Step 3: Run `H`.** Expected: FAIL with `attempt to call field 'temple_turn' (a nil value)`.

- [ ] **Step 4: Implement.** After `GG.on_agent_action`:

```lua
-- THE TEMPLE'S ROUTES (temple spec §3.2, 2026-10-04), per culture. `devout`: a province in
-- good order. `chaos`: a province with no Chaos corruption, and `vampiric` adds the undead's.
-- `holy`: the cultures a won battle must be against. `priests`: the hero subtypes whose
-- successful actions pay the temple instead of the spies. Not behind race_differences:
-- this is the guild's base income. Mirrored by TEMPLE_ROUTES in tools/gen_great_guilds.py.
-- BEGIN TEMPLE ROUTES
GG.CHAOS_CULTURES = {"wh_main_chs_chaos", "wh3_main_kho_khorne", "wh3_main_nur_nurgle",
                     "wh3_main_sla_slaanesh", "wh3_main_tze_tzeentch", "wh3_main_dae_daemons"}
GG.TEMPLE_ROUTES = {
    ["wh3_dlc23_chd_chaos_dwarfs"] = {devout = true, holy = {"wh_main_dwf_dwarfs"}},
    ["wh_main_emp_empire"] = {chaos = true, priests = {
        "wh_main_emp_bright_wizard", "wh_main_emp_celestial_wizard", "wh_main_emp_light_wizard",
        "wh_dlc05_emp_jade_wizard", "wh_dlc05_emp_grey_wizard", "wh_dlc03_emp_amber_wizard",
        "wh2_pro07_emp_amethyst_wizard", "wh3_dlc25_emp_gold_wizard"}},
    ["wh_main_dwf_dwarfs"] = {devout = true,
        holy = {"wh_main_grn_greenskins", "wh2_main_skv_skaven"}},
    ["wh_main_brt_bretonnia"] = {devout = true, chaos = true, vampiric = true,
        holy = {"wh_main_chs_chaos", "wh3_main_kho_khorne", "wh3_main_nur_nurgle",
                "wh3_main_sla_slaanesh", "wh3_main_tze_tzeentch", "wh3_main_dae_daemons",
                "wh_main_vmp_vampire_counts"}},
    ["wh3_main_cth_cathay"] = {devout = true, chaos = true},
    ["wh3_main_ksl_kislev"] = {devout = true, chaos = true, vampiric = true,
        holy = {"wh_main_chs_chaos", "wh3_main_kho_khorne", "wh3_main_nur_nurgle",
                "wh3_main_sla_slaanesh", "wh3_main_tze_tzeentch", "wh3_main_dae_daemons",
                "wh_dlc08_nor_norsca"}},
    ["wh2_main_def_dark_elves"] = {holy = {"wh2_main_hef_high_elves"},
        priests = {"wh2_main_def_death_hag"}},
    ["wh2_main_hef_high_elves"] = {devout = true, chaos = true,
        holy = {"wh2_main_def_dark_elves"}},
}
-- END TEMPLE ROUTES

function GG.temple_routes(faction)
    return GG.TEMPLE_ROUTES[GG.culture_of(faction) or ""]
end

-- ONE COUNT PER PROVINCE, not per settlement: public order is the province's, so a region
-- count would pay one province once per settlement in it. Corruption lives on the province
-- too (CA reads region:province():pooled_resource_manager()). A missing resource is none.
function GG.temple_counts(f, r)
    local taints = {"wh3_main_corruption_chaos"}
    if r.vampiric then taints[2] = "wh3_main_corruption_vampiric" end
    local devout, clean = 0, 0
    local pl = f:provinces()
    for i = 0, pl:num_items() - 1 do
        local fp = pl:item_at(i)
        if r.devout then
            local regs = fp:regions()
            if regs:num_items() > 0 and regs:item_at(0):public_order() > 0 then
                devout = devout + 1
            end
        end
        if r.chaos then
            local prm = fp:province():pooled_resource_manager()
            local pure = true
            for j = 1, #taints do
                local res = prm:resource(taints[j])
                if not res:is_null_interface() and res:value() > 0 then pure = false end
            end
            if pure then clean = clean + 1 end
        end
    end
    return devout, clean
end

-- At the faction's turn start, AI included. `f` is the faction interface the listener holds.
function GG.temple_turn(faction, f)
    local r = GG.temple_routes(faction)
    if not r or not (r.devout or r.chaos) or not f then return end
    local ok, devout, clean = pcall(GG.temple_counts, f, r)
    if not ok then return end
    GG.capped_grant(faction, "temple", devout * (GG.setting("rate_temple_devout") or 1),
                    "devout")
    GG.capped_grant(faction, "temple", clean * (GG.setting("rate_temple_chaos") or 2),
                    "chaos")
end

-- A WON BATTLE AGAINST THE FAITH'S ENEMIES, off CA's pending-battle cache, which keeps the
-- battle until the next one and so still answers after the commanders have died. Called
-- from GG.battle_award, which the listener already deduplicates per battle.
function GG.temple_holy(faction)
    local r = GG.temple_routes(faction)
    if not r or not r.holy then return end
    local ok, won = pcall(function()
        return cm:pending_battle_cache_faction_won_battle_against_culture(faction, r.holy)
    end)
    if ok and won == true then
        GG.capped_grant(faction, "temple", GG.setting("rate_temple_holy") or 10, "holywar")
    end
end
```

Replace `GG.on_agent_action`:
```lua
-- `subtype`: the acting hero's agent subtype. A race's priests and wizards pay the temple
-- at the spies' rate instead of the spies (temple spec §3.2).
function GG.on_agent_action(faction, success, subtype)
    if not success then return end
    local guild, source = "khanate", "agents"
    local r = GG.temple_routes(faction)
    if r and r.priests and subtype then
        for i = 1, #r.priests do
            if r.priests[i] == subtype then guild, source = "temple", "priests" end
        end
    end
    GG.capped_grant(faction, guild, GG.setting("rate_khanate") or 8, source)
end
```

Note: `GG.temple_routes` is defined after `GG.on_agent_action` in the file. It is looked up at call time, so the order is fine. Keep the routes block directly after it anyway.

In the `gg_agent_` listener, replace `GG.load(name); GG.on_agent_action(name, won); GG.save(name)` with:
```lua
            local sub
            pcall(function() sub = context:character():character_subtype_key() end)
            GG.load(name); GG.on_agent_action(name, won, sub); GG.save(name)
```

In `GG.battle_award`, after `GG.on_battle(winner, outnumbered)`: `GG.temple_holy(winner)`.

In `gg_turn`, after `GG.pay_halls(name)`:
```lua
        local okf, fi = pcall(function() return context:faction() end)
        if okf then GG.temple_turn(name, fi) end
```

- [ ] **Step 5: Show the next turn's temple income.** `GG.turn_start_pay(faction, guild)` returns 0 for every guild but brass. Leave it alone: it is a preview used at line 1038 for the hold calculation, and the temple has no rival to hold against. Add one comment line above its `if guild ~= "brass"` saying the temple's turn-start routes are not previewed because no rival reads them.

- [ ] **Step 6: Run `H`, `BH`, `LUAC`.** Expected: `harness ok`, `bounty harness ok`, exit 0.

- [ ] **Step 7: Run `py tools/check_lua_api.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"`.** Expected: exit 0.

---

### Task 4: The holy-war bounty

**Files:**
- Modify: `zzz_derpy_guilds.lua`: new `GG.holy_pool`, one line in `GG.bounty_target` (~2020)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: `GG.temple_routes(faction)` (Task 3)
- Produces: `GG.holy_pool(faction, pool) -> pool`

- [ ] **Step 1: Write the failing test.** Add to `_guilds_bounty_harness.lua`, before the final `print`, using its world builder:

```lua
do
    -- THE TEMPLE'S BOUNTY IS A HOLY WAR (temple spec §4): its army bounty names a lord of the
    -- race's holy-war cultures only, and nothing when none is at war with the player.
    W.reset()
    W.faction("p_def", {culture = "wh2_main_def_dark_elves", human = true,
                        at_war = {"e_hef", "e_emp"}})
    W.faction("e_hef", {culture = "wh2_main_hef_high_elves", lords = 1})
    W.faction("e_emp", {culture = "wh_main_emp_empire", lords = 1})
    GG.CULTURE_OF["p_def"] = "wh2_main_def_dark_elves"
    for _ = 1, 20 do
        local t, owner = GG.bounty_target("p_def", "lord_kill", {}, false, "temple")
        assert(t == nil or owner == "e_hef", "the Brides' bounty names only an asur lord")
    end
    local _, owner = GG.bounty_target("p_def", "lord_kill", {}, false, "immortals")
    assert(owner ~= nil, "other guilds keep the whole pool")
    W.faction("p_def", {culture = "wh2_main_def_dark_elves", human = true,
                        at_war = {"e_emp"}})
    assert(GG.bounty_target("p_def", "lord_kill", {}, false, "temple") == nil,
           "no holy enemy at war: no target, no error")
    GG.CULTURE_OF["p_def"] = nil
    ok("the temple's bounty is a holy war")
end
```

Match `W.faction`'s option names to the ones the harness's builder declares (`at_war`, `culture`, `lords`, `human`). Read the builder at the top of the file and use its exact spelling. Lords must be placed off the player's front so the existing front rule does not empty the pool. Use the option the builder already offers for that (`far` or region distance), as the other `lord_kill` blocks in the file do.

- [ ] **Step 2: Run `BH`.** Expected: FAIL, "the Brides' bounty names only an asur lord".

- [ ] **Step 3: Implement.** After `GG.bounty_pool`:

```lua
-- THE TEMPLE'S BOUNTY IS A HOLY WAR (temple spec §4): its pool keeps only factions of the
-- race's holy-war cultures. A race with none keeps the whole pool; one with none at war gets
-- an empty pool, and the guild posts another kind.
function GG.holy_pool(faction, pool)
    local r = GG.temple_routes(faction)
    if not r or not r.holy then return pool end
    local want, out = {}, {}
    for i = 1, #r.holy do want[r.holy[i]] = true end
    for i = 1, #pool do
        local ok, c = pcall(function() return pool[i]:culture() end)
        if ok and want[c] then out[#out + 1] = pool[i] end
    end
    return out
end
```

In `GG.bounty_target`, directly after `local pool = GG.bounty_pool(faction, war == true and not ai, ai)` (leave that line byte-identical, since it is a mutation anchor), add:
```lua
        if guild == "temple" then pool = GG.holy_pool(faction, pool) end
```

- [ ] **Step 4: Run `BH` and `H`.** Expected: both ok. `GG.post_bounties` rolls a start guild with `GG.roll(#GG.GUILDS)`, so seven guilds shift the deterministic stub's sequence. If an existing bounty block fails only because a different guild drew first, re-derive its expected value from the stub's `RANDOM`, and say so in a comment. Never delete the assertion.

---

### Task 5: The temple in the generator

**Files:**
- Modify: `tools/gen_great_guilds.py`. Its data tables:
  - `GUILDS`, `RATES`, `RANK_EFFECTS`
  - `EFFECT_GOOD_SIGN`, `EFFECT_REACH_THEIRS`, `EFFECT_BLURB`
  - `GUILD_NAMES`, `SERVICES`, `SERVICE_BLURB`, `GUILD_DESC`
  - `BOUNTIES`, `BOUNTY_EXTRA`, `FLAVOURS`, `POOL_KEYS`
  - `EARN_SHORT`, `help_pages`, the ledger `src_*` list
  - `check_mct_names`, `selftest`
  - new `RANK_VALUES_OF` / `LEAD_VALUE_OF` / `TEMPLE_ROUTES` / `TEMPLE_NAMES` / `TEMPLE_TEXT`
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua`. Its generated `GGUI.MCT_NAMES` block is rewritten by `GEN --write`.

**Interfaces:**
- Consumes: the Lua tables from Tasks 1-4.
- Produces:
  - `rank_value(g, rank)`, `lead_value(g)`
  - `TEMPLE_ROUTES` (the Python mirror)
  - `check_temple_routes() -> [str]`
  - `TEMPLE_TEXT[tag] = {"earn": str, "short": str}`

- [ ] **Step 1: Make the selftest pins fail first.** In `selftest()`, change:
  - 6416: `len(GUILDS) == 7`
  - 6417: `len(set(GUILDS)) == 7`
  - 6446 and 6447: `len(keys) == 28` (the rank keys, 4 per guild)
  - 6468: `len(rank_rows) == 28`
  - 6544: `len(shared) == 63` (54 + 9)
  - 6554: `len(bundled) == 36` (+ `holy_war`, `consecration`)
  - 6556: `len(minted) == 42` (+ 8: every temple row but the gold one carries `effects`)
  - 6557: the literal `24` becomes `28`

  Run `GEN --selftest`. Expected: FAIL at `len(GUILDS) == 7`.

- [ ] **Step 2: The data tables.**

```python
GUILDS = ["brass", "immortals", "daemonsmiths", "khanate", "overseers", "slavers", "temple"]
```

`RATES`: `"temple": {"per_devout_province": 1, "per_clean_province": 2, "per_holy_win": 10, "cap": 40},`

`RANK_EFFECTS`: `"temple": ("wh_main_effect_public_order_events", "faction_to_province_own"),` with the comment "83 vanilla bundle rows, -20..15; the ladder is the temple's own (RANK_VALUES_OF)".

`EFFECT_GOOD_SIGN["temple"] = 1`. `EFFECT_REACH_THEIRS["temple"] = "their provinces"`. `EFFECT_BLURB["temple"] = ("%+d public order", "every province you own")`.

After `RANK_VALUES`:
```python
# THE TEMPLE'S OWN LADDER (temple spec §4). Public order is a flat count, not a percentage:
# the shared 3/6/10/15 would put +15 in every province at rank 5. Indexed like RANK_VALUES.
RANK_VALUES_OF = {"temple": [None, None, 1, 2, 3, 4]}


def rank_value(g, rank):
    return RANK_VALUES_OF.get(g, RANK_VALUES)[rank]
```

After `LEAD_VALUE = 10`:
```python
# The rank-4 value of the guild's own ladder, as LEAD_VALUE is of the shared one.
LEAD_VALUE_OF = {"temple": 3}


def lead_value(g):
    return LEAD_VALUE_OF.get(g, LEAD_VALUE)
```

In `_build_one`:
- replace `RANK_VALUES[r] * EFFECT_GOOD_SIGN[g]` with `rank_value(g, r) * EFFECT_GOOD_SIGN[g]` (2816);
- replace both `RANK_VALUES[rank] * EFFECT_GOOD_SIGN[g]` with `rank_value(g, rank) * EFFECT_GOOD_SIGN[g]` (2847, 2862);
- replace both `LEAD_VALUE * EFFECT_GOOD_SIGN[g]` with `lead_value(g) * EFFECT_GOOD_SIGN[g]` (2889, 2900).

Grep for any other `RANK_VALUES[` / `LEAD_VALUE` read inside `check()` and route the guild-specific ones the same way.

`GUILD_NAMES["temple"] = "The Temple of Hashut"`.

`SERVICES`: append after the `asuryans_grace` row, in this order:
```python
    # THE TEMPLE (temple spec §4, 2026-10-04). After every row, as in the Lua. Every bundle
    # row carries its own effects: SERVICE_VALUES' 45 would be +45 public order.
    {"key": "hashut_blessing", "guild": "temple", "rank": 2, "cost": 50, "cd": 8,
     "kind": "army", "turns": 5, "name": "Blessing of Hashut",
     "effects": [("wh_main_effect_force_stat_leadership", "force_to_force_own", 6)],
     "text": "{v0:+d} leadership for the army you select, for {turns} turns."},
    {"key": "forge_sermons", "guild": "temple", "rank": 2, "cost": 50, "cd": 8,
     "kind": "settlement", "turns": 8, "name": "Sermons in the Forge",
     "effects": [("wh_main_effect_public_order_events", "region_to_province_own_unseen", 4)],
     "text": "{v0:+d} public order in the province of the settlement you select, for "
             "{turns} turns."},
    {"key": "temple_tithe", "guild": "temple", "rank": 2, "cost": 50, "cd": 8,
     "kind": "gold", "value": 2000, "name": "The Tithe",
     "text": "Adds {value:,} gold to your treasury at once."},
    {"key": "zeal", "guild": "temple", "rank": 3, "cost": 150, "cd": 12,
     "kind": "army", "turns": 5, "name": "Zeal",
     "effects": [("wh_main_effect_force_stat_melee_attack", "force_to_force_own", 6),
                 ("wh_main_effect_force_stat_charge_bonus_pct", "force_to_force_own", 10)],
     "text": "{v0:+d} melee attack and {v1:+d}% charge bonus for the army you select, for "
             "{turns} turns."},
    {"key": "purge_unclean", "guild": "temple", "rank": 3, "cost": 150, "cd": 12,
     "kind": "settlement", "turns": 8, "name": "Purge the Unclean",
     "effects": [("wh3_main_effect_corruption_reduction_events",
                  "region_to_province_own_unseen", -6)],
     "text": "{v0:+d} corruption in the province of the settlement you select, for "
             "{turns} turns.",
     # The Chaos Dwarfs gain public order FROM Chaos corruption (RACE_UNWANTED_EFFECTS).
     "for_tag": {"": {
         "effects": [("wh_main_effect_public_order_events",
                      "region_to_province_own_unseen", 6)],
         "text": "{v0:+d} public order in the province of the settlement you select, for "
                 "{turns} turns."}}},
    {"key": "anathema", "guild": "temple", "rank": 3, "cost": 150, "cd": 12,
     "kind": "enemy_settlement", "turns": 5, "name": "Anathema",
     "effects": [("wh_main_effect_public_order_events", "region_to_province_own_unseen", -6)],
     "text": "{v0:+d} public order in the enemy province you select, for {turns} turns."},
    {"key": "holy_war", "guild": "temple", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "name": "The Holy War",
     "effects": [("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6),
                 ("wh_main_effect_force_all_campaign_replenishment_rate",
                  "faction_to_force_own", 10)],
     "text": "{v0:+d} leadership and {v1:+d}% replenishment in all your armies, for "
             "{turns} turns."},
    {"key": "miracle", "guild": "temple", "rank": 4, "cost": 400, "cd": 16,
     "kind": "army", "turns": 2, "heal": True, "name": "Miracle",
     "effects": [("wh_main_effect_force_stat_leadership", "force_to_force_own", 10)],
     "text": "Heals the army you select at once, then {v0:+d} leadership for it, for "
             "{turns} turns."},
    {"key": "consecration", "guild": "temple", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 12, "name": "Consecration",
     "effects": [("wh_main_effect_public_order_events", "faction_to_province_own", 4),
                 ("wh3_main_effect_corruption_reduction_events", "faction_to_province_own", -3)],
     "text": "{v0:+d} public order and {v1:+d} corruption in every province you hold, for "
             "{turns} turns.",
     "for_tag": {"": {
         "effects": [("wh_main_effect_public_order_events", "faction_to_province_own", 4)],
         "text": "{v0:+d} public order in every province you hold, for {turns} turns."}}},
```

Every (effect, scope) pair above was measured on vanilla bundles on 2026-10-04:
- leadership `force_to_force_own` (66 rows, -10..30)
- melee attack `force_to_force_own` (36, -8..30)
- charge bonus `force_to_force_own` (3, 6..12)
- public order `region_to_province_own_unseen` (20, -15..30)
- corruption reduction `region_to_province_own_unseen` (3, -5..-5; -6 is within 1.5x)
- leadership `faction_to_force_own` (69, -15..20)
- replenishment `faction_to_force_own` (75, -15..80)
- public order `faction_to_province_own` (83, -20..15)
- corruption reduction `faction_to_province_own` (27, -15..-1)

`check()` re-measures every one.

`SERVICE_BLURB`: no temple entries. The rows carry `text`.

`POOL_KEYS`: change to
```python
POOL_KEYS = [s["key"] for s in SERVICES[18:] if not s.get("race") and s["guild"] != "temple"]
```
with the comment: "the temple's rows sit after the race rows and are named by TEMPLE_NAMES".

`GUILD_DESC["temple"]` (CHD flavour half, then the earn half, which `TEMPLE_TEXT` overrides per tag):
```python
    "temple":       "The priests of the Father of Darkness, who tend his altars and feed his "
                    "fires with whatever the forges cannot use.||You earn reputation from "
                    "provinces in good order, from battles won against the Dwarfs, and from "
                    "their own buildings.",
```

`BOUNTIES["temple"]`:
```python
    "temple":       ("lord_kill", "An Offering for Hashut",
                     "A general of the Dwarfs leads an army in the open. The priests want "
                     "that life on the altar."),
```
`BOUNTY_EXTRA["temple"] = ["job_build"]`.

- [ ] **Step 3: The routes mirror and its check.**

```python
# THE TEMPLE'S ROUTES, mirroring GG.TEMPLE_ROUTES (between the BEGIN/END TEMPLE ROUTES lines
# of the model Lua). check_temple_routes() runs that block under lua.exe and compares.
CHAOS_CULTURES = ["wh_main_chs_chaos", "wh3_main_kho_khorne", "wh3_main_nur_nurgle",
                  "wh3_main_sla_slaanesh", "wh3_main_tze_tzeentch", "wh3_main_dae_daemons"]
TEMPLE_ROUTES = {
    "wh3_dlc23_chd_chaos_dwarfs": {"devout": True, "holy": ["wh_main_dwf_dwarfs"]},
    "wh_main_emp_empire": {"chaos": True, "priests": [
        "wh_main_emp_bright_wizard", "wh_main_emp_celestial_wizard", "wh_main_emp_light_wizard",
        "wh_dlc05_emp_jade_wizard", "wh_dlc05_emp_grey_wizard", "wh_dlc03_emp_amber_wizard",
        "wh2_pro07_emp_amethyst_wizard", "wh3_dlc25_emp_gold_wizard"]},
    "wh_main_dwf_dwarfs": {"devout": True,
                           "holy": ["wh_main_grn_greenskins", "wh2_main_skv_skaven"]},
    "wh_main_brt_bretonnia": {"devout": True, "chaos": True, "vampiric": True,
                              "holy": CHAOS_CULTURES + ["wh_main_vmp_vampire_counts"]},
    "wh3_main_cth_cathay": {"devout": True, "chaos": True},
    "wh3_main_ksl_kislev": {"devout": True, "chaos": True, "vampiric": True,
                            "holy": CHAOS_CULTURES + ["wh_dlc08_nor_norsca"]},
    "wh2_main_def_dark_elves": {"holy": ["wh2_main_hef_high_elves"],
                                "priests": ["wh2_main_def_death_hag"]},
    "wh2_main_hef_high_elves": {"devout": True, "chaos": True,
                                "holy": ["wh2_main_def_dark_elves"]},
}


def _route_line(culture, r):
    return "%s|%d|%d|%d|%s|%s" % (culture, bool(r.get("devout")), bool(r.get("chaos")),
                                  bool(r.get("vampiric")), ",".join(sorted(r.get("holy", []))),
                                  ",".join(sorted(r.get("priests", []))))


def check_temple_routes():
    """The Lua's routes equal the mirror, every culture and subtype key exists, and every
    covered culture has a route entry (a missing one earns the temple nothing, silently)."""
    import subprocess
    import tempfile
    out = []
    lua = io.open(MODEL_LUA, encoding="utf-8").read()
    block = re.search(r"-- BEGIN TEMPLE ROUTES\n(.*?)-- END TEMPLE ROUTES", lua, re.S)
    if not block:
        return ["GG.TEMPLE_ROUTES block markers not found in " + MODEL_LUA]
    prog = ("GG = {}\n" + block.group(1) + "\nfor c, r in pairs(GG.TEMPLE_ROUTES) do\n"
            "  local h, p = {}, {}\n"
            "  for _, v in ipairs(r.holy or {}) do h[#h + 1] = v end\n"
            "  for _, v in ipairs(r.priests or {}) do p[#p + 1] = v end\n"
            "  table.sort(h); table.sort(p)\n"
            "  local function b(x) return x and 1 or 0 end\n"
            "  io.write(c, '|', b(r.devout), '|', b(r.chaos), '|', b(r.vampiric), '|',\n"
            "           table.concat(h, ','), '|', table.concat(p, ','), '\\n')\n"
            "end\n")
    fd, path = tempfile.mkstemp(suffix=".lua")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(prog)
        got = subprocess.run([LUA_EXE, path], capture_output=True, text=True,
                             check=True).stdout.split()
    finally:
        os.remove(path)
    want = [_route_line(c, r) for c, r in TEMPLE_ROUTES.items()]
    if sorted(got) != sorted(want):
        out.append("GG.TEMPLE_ROUTES and TEMPLE_ROUTES differ:\n  lua %s\n  py  %s"
                   % (sorted(set(got) - set(want)), sorted(set(want) - set(got))))
    cultures = {r["key"] for r in live_rows("cultures")}
    subtypes = {r["key"] for r in live_rows("agent_subtypes")}
    for c, r in TEMPLE_ROUTES.items():
        for k in [c] + r.get("holy", []):
            if k not in cultures:
                out.append("temple route culture %s is not in cultures_tables" % k)
        for k in r.get("priests", []):
            if k not in subtypes:
                out.append("temple priest subtype %s is not in agent_subtypes_tables" % k)
    for tag, F in FLAVOURS.items():
        if F.get("culture") and F["culture"] not in TEMPLE_ROUTES:
            out.append("%s (%s) has no temple route" % (tag, F["culture"]))
    return out
```
Add `out += check_temple_routes()` to `check()` next to `check_race_mirror`. If `live_rows("cultures")` or `live_rows("agent_subtypes")` raises a `KeyError` on `key`, print one row's keys and use the column CA names the key column. Both tables key on `key` in `schema_wh3.ron` as of 9.0.

- [ ] **Step 4: Per-flavour text.** Add after `POOL_NAMES`:

```python
# THE TEMPLE'S NAMES per flavour (temple spec §2, §6), in SERVICES order: hashut_blessing,
# forge_sermons, temple_tithe, zeal, purge_unclean, anathema, holy_war, miracle,
# consecration. The Chaos Dwarf names are each row's "name".
TEMPLE_KEYS = [s["key"] for s in SERVICES if s["guild"] == "temple"]
TEMPLE_NAMES = {
    "_emp": ["Ward of Azyr", "Colleges' Proclamation", "College Endowment",
             "Flames of Aqshy", "Light of Hysh", "Curse of Shyish",
             "The Battle Colleges", "Ghyran's Mending", "Charter of Magic"],
    "_dwf": ["Grimnir's Blessing", "Valaya's Hearth", "Temple Tithe", "Slayer's Oath",
             "Valaya's Ward", "Ancestral Curse", "War of Vengeance", "Valaya's Mercy",
             "Rites of the Ancestors"],
    "_brt": ["The Lady's Blessing", "Pilgrims' Sermons", "Pilgrims' Alms", "Holy Fervour",
             "Cleansing Flame", "Excommunication", "The Errantry War", "Grail Miracle",
             "Hallowed Ground"],
    "_cth": ["Dragon's Blessing", "Temple Proclamations", "Temple Offerings",
             "Celestial Fury", "Cleansing Incense", "Heaven's Censure",
             "Mandate of Heaven", "Healing Waters", "Blessing of the Moons"],
    "_ksl": ["Ursun's Blessing", "Orthodox Sermons", "Church Tithe", "Bear's Fury",
             "Purifying Flame", "Anathema", "Ursun's Crusade", "Saint's Mercy",
             "Holy Icons"],
    "_def": ["Khaine's Blessing", "Blood Sermons", "Blood Tithe", "Murderous Frenzy",
             "Cleansing Blood", "Khaine's Curse", "The Death Night", "Cauldron's Gift",
             "Altars Run Red"],
    "_hef": ["Asuryan's Blessing", "Temple Sermons", "Temple Offerings", "Phoenix Fury",
             "Sacred Flame", "Asuryan's Judgement", "War of the Phoenix", "Phoenix Rebirth",
             "Flame Eternal"],
    "_gen": ["Blessing", "Sermons", "Tithe", "Zeal", "Purge the Unclean", "Anathema",
             "The Holy War", "Miracle", "Consecration"],
}
for _tag, _names in TEMPLE_NAMES.items():
    assert len(_names) == len(TEMPLE_KEYS), (_tag, len(_names), len(TEMPLE_KEYS))
    FLAVOURS[_tag]["services"].update(zip(TEMPLE_KEYS, _names))

# THE TEMPLE PER FLAVOUR: its name, what it is, its holy-war bounty, and how it is earned -
# the routes differ per race, so the earn sentence and Help's short line do too.
TEMPLE_FLAVOUR = {
    "_emp": ("The Colleges of Magic",
             "The eight Colleges of Altdorf, licensed by the Emperor and watched by the "
             "Witch Hunters. Their Battle Wizards march for whoever pays.",
             ("Proof of the Art", "The Colleges want a general of your enemies brought "
              "down by an army that marches with their wizards."),
             "You earn reputation from provinces free of Chaos corruption, from successful "
             "actions by your Battle Wizards, and from their own buildings.",
             "clean provinces, wizards' actions"),
    "_dwf": ("The Ancestor Temples",
             "The keepers of the shrines of Grungni, Valaya and Grimnir, and the Slayers who "
             "walk out of them to die well.",
             ("Hunt for the Slayers", "A general of the greenskins or the ratmen leads an "
              "army in the open. The temples want that general brought down."),
             "You earn reputation from provinces in good order, from battles won against "
             "greenskins and skaven, and from their own buildings.",
             "loyal provinces, wins over greenskins and skaven"),
    "_brt": ("The Grail Pilgrims",
             "Peasants who left their fields to follow the Grail, and the shrines where they "
             "wait for the Lady's sign.",
             ("The Grail Quest", "A general of the Ruinous Powers or the restless dead walks "
              "the land. The pilgrims pray for that general's end."),
             "You earn reputation from provinces in good order, from provinces free of Chaos "
             "and undead corruption, from battles won against Chaos and the undead, and from "
             "their own buildings.",
             "loyal and clean provinces, wins over Chaos and the undead"),
    "_cth": ("The Celestial Temples",
             "The priests of the Celestial Dragon and the ancestors, keepers of the temple "
             "guardians of stone.",
             ("Heaven's Judgement", "A general of your enemies offends the Celestial Dragon. "
              "The temples ask that the general be brought down."),
             "You earn reputation from provinces in good order, from provinces free of Chaos "
             "corruption, and from their own buildings.",
             "loyal and clean provinces"),
    "_ksl": ("The Great Orthodoxy",
             "Ursun's priests and the Patriarch's church, who bless the bears, the bells and "
             "the border forts.",
             ("Ursun's Hunt", "A general of the north leads an army against the Motherland. "
              "The Orthodoxy wants that general dead."),
             "You earn reputation from provinces in good order, from provinces free of Chaos "
             "and undead corruption, from battles won against Chaos and Norsca, and from "
             "their own buildings.",
             "loyal and clean provinces, wins over Chaos and Norsca"),
    "_def": ("The Brides of Khaine",
             "The witch elves of Khaine's temples, who bathe in blood and answer to the hag "
             "queens alone.",
             ("A Gift for Khaine", "An asur general still lives. The Brides want that heart "
              "on the altar."),
             "You earn reputation from battles won against the High Elves, from successful "
             "actions by your Death Hags, and from their own buildings.",
             "wins over the asur, Death Hags' actions"),
    "_hef": ("The Cult of Asuryan",
             "The guardians of Asuryan's sacred flame, who see what is to come and speak of "
             "it to no one.",
             ("Asuryan's Judgement", "A druchii general leads an army in the open. The Cult "
              "wants that general brought down."),
             "You earn reputation from provinces in good order, from provinces free of Chaos "
             "corruption, from battles won against the Dark Elves, and from their own "
             "buildings.",
             "loyal and clean provinces, wins over the druchii"),
    "_gen": ("The Faith Guild",
             "The priests and holy orders of the land, whose word moves crowds and whose "
             "blessings move armies.",
             ("The Holy War", "A general of the faith's enemies leads an army in the open. "
              "The priests want that general brought down."),
             "You earn reputation from the faith's own routes, and from their own buildings.",
             "the faith's own routes"),
}
TEMPLE_TEXT = {"": {"earn": GUILD_EARN["temple"],
                    "short": "loyal provinces, wins over the Dwarfs"}}
for _tag, (_name, _desc, _bounty, _earn, _short) in TEMPLE_FLAVOUR.items():
    FLAVOURS[_tag]["guilds"]["temple"] = _name
    FLAVOURS[_tag]["desc"]["temple"] = _desc
    FLAVOURS[_tag]["bounties"]["temple"] = _bounty
    TEMPLE_TEXT[_tag] = {"earn": _earn, "short": _short}
```

`EARN_SHORT["temple"] = TEMPLE_TEXT[""]["short"]`, so the shape check finds it. `help_pages` reads it per tag; see Step 5.

In `_build_one`, the `GUILD_DESC = dict(...)` line becomes:
```python
    GUILD_DESC = dict((g, F["desc"][g] + "||" + (TEMPLE_TEXT[tag]["earn"] if g == "temple"
                                                 else GUILD_EARN[g])) for g in GUILDS)
```

Ledger loc, in the `src_*` tuple list of `_build_one`, after `("src_court", "court actions")`:
```python
                      ("src_devout", "provinces in good order"),
                      ("src_chaos", "provinces free of corruption"),
                      ("src_holywar", "holy war"), ("src_priests", "wizards and priests"),
```

- [ ] **Step 5: The Help pages.** In `help_pages`, page 2:
  - the guild loop prints `TEMPLE_TEXT[tag]["short"]` for `gk == "temple"`, and `EARN_SHORT[gk]` otherwise;
  - delete the line `"#Every guild at once",`;
  - change `"-Every completed MISSION raises your reputation with all six guilds."` to `"-Every completed MISSION raises your reputation with every guild."`, keeping it where it is (now under the building bullet);
  - page 4's `"You cannot court all six at once."` becomes `"You cannot court them all at once."`;
  - the `derpy_gg_rivals_help` text's `"the same six guilds you are."` (3574) becomes `"the same guilds you are."`.

- [ ] **Step 6: MCT names.**

`check_mct_names`: for the rate keys, replace `("rate_" + g, "cap_" + g)` with
```python
        for key in TEMPLE_RATE_KEYS if g == "temple" else ("rate_" + g,):
```
plus the existing `"cap_" + g` handling, where `TEMPLE_RATE_KEYS = ("rate_temple_devout", "rate_temple_chaos", "rate_temple_holy")`. The MCT labels for those three are not the `_gen` guild name, so check that they START with `FLAVOURS["_gen"]["guilds"]["temple"] + ":"` instead of equalling it.

`mct_names_block` already loops `GUILDS`, so `--write` adds `temple = "<name>"` to each flavour's table in `GGUI.MCT_NAMES`.

- [ ] **Step 7: Run `GEN --selftest`.** Expected: `selftest ok`. A failure that names a hall table (hall_tables KeyError on `units["temple"]`) is Task 6's and is fixed there. Do Task 6 before re-running if that is the only failure.

- [ ] **Step 8: Run `GEN --check`.** Expected, after Task 6: exit 0. Read every finding. A `check_flavours` finding on a duplicate service name within a flavour means one of `TEMPLE_NAMES` collides with an existing name there. Rename the temple one; never the old one.

---

### Task 6: The temple's halls

**Files:**
- Modify: `tools/gen_great_guilds.py`:
  - `HALL_EFFECT`, `HALL_SEAT_SCOPE`, `HALL_ICON`, `HALL_RACES`
  - new `HALL_EXTRA`; `hall_tables`, `hall_name`, `HALL_BONUS`, `hall_desc`
  - `HALL_AI_ROLE`, `_ROLE_WORDS`, `_dlc_problems`
  - the promotion line (3517) and `check_promotion_text` (5189)
  - selftest hall pins (6783-6927)
- Test: `tools/_guilds_harness.lua` hall totals (moved in Task 1 Step 5)

**Interfaces:**
- Produces: `hall_key("temple", n, tag)` chains `derpy_gg_hall_temple_<n><tag>`, and `HALL_EXTRA[(guild, tag)] = (effect, scope, [v0, v1, v2], player_text_with_%d)`.

- [ ] **Step 1: Move the selftest hall pins.**
  - `12 * len(HALL_TAGS)` (6795) becomes `14 * len(HALL_TAGS)`.
  - The `6 * len(HALL_TAGS)` occurrences (6810, 6833, 6927) become `7 * len(HALL_TAGS)`.
  - 6839 `[seat_value(g) for g in GUILDS] == [5, 5, 2, 1, -5, 10, 2]`.
  - Add `"temple"` to the `donors` dict at 6821, with the donor chain Step 4's `_cai_donor` picks for the CHD temple (print it once and pin what it prints).
  - Add the temple to the `_chd_l2` pins (6824, the level-2 text per guild): `"Earns 15 Reputation and 15 Favour with the Temple of Hashut each turn. Public order +6 in this province. Lowers the price of their services. Trains %s." % unit_name("wh3_dlc23_chd_mon_lammasu")`. Lammasu's unit level is 1, so levels 1 and 2 train it and level 0 does not.
  - Pin the Empire's level-0 text too: `hall_desc("temple", 0, "_emp") == "Earns 4 Reputation and 4 Favour with the Colleges of Magic each turn. Public order +2 in this province. Lowers the price of their services. Wizards you may recruit +1."`.

  Run `GEN --selftest`. Expected: FAIL.

- [ ] **Step 2: Hall data.**

```python
    "temple":       ("wh_main_effect_public_order_base", "province_to_province_own_unseen",
                     [2, 4, 6]),
```
in `HALL_EFFECT`, with the comment: "CA's standard building public order (642 rows, -10..20); the visible pair has two vanilla rows of 2, so 6 would fail the range check - the card line is hidden and the hall's own text states it".

`HALL_SEAT_SCOPE["temple"] = "faction_to_province_own"`, with the comment `# (7)`.

`HALL_ICON`: add `"temple"` to the guild tuple in the comprehension.

```python
# A SECOND HALL EFFECT for one guild in one race (temple spec §5): the Empire's College of
# Magic trains no unit - the Luminark needs settlement level 5 - and instead raises the
# number of wizards the Empire may recruit, on CA's own building pair (values 1-2).
HALL_EXTRA = {
    ("temple", "_emp"): ("wh_main_effect_agent_cap_increase_wizard_empire",
                         "faction_to_faction_own_unseen", [1, 2, 3],
                         "Wizards you may recruit +%d"),
}
```

`HALL_RACES`: add `"temple"` to each race's `units`, and a `temple_nouns` tuple:

| tag | `units["temple"]` | `temple_nouns` |
|---|---|---|
| `""` | `"wh3_dlc23_chd_mon_lammasu"` | `("Shrine of Hashut", "Temple of Hashut", "High Temple of Hashut")` |
| `_emp` | `None` | `("Wizard's Tower", "College of Magic", "Grand College")` |
| `_dwf` | `"wh2_dlc10_dwf_inf_giant_slayers"` | `("Shrine of the Ancestors", "Temple of the Ancestors", "Great Temple of the Ancestors")` |
| `_brt` | `"wh_main_brt_cav_grail_knights"` | `("Grail Shrine", "Grail Chapel", "Grail Basilica")` |
| `_cth` | `"wh3_main_cth_mon_terracotta_sentinel_0"` | `("Celestial Shrine", "Celestial Temple", "Great Celestial Temple")` |
| `_ksl` | `"wh3_main_ksl_cav_war_bear_riders_1"` | `("Shrine of Ursun", "Church of Ursun", "Cathedral of Ursun")` |
| `_def` | `"wh2_main_def_inf_witch_elves_0"` | `("Shrine of Khaine", "Temple of Khaine", "Great Temple of Khaine")` |
| `_hef` | `"wh2_main_hef_inf_phoenix_guard"` | `("Shrine of Asuryan", "Temple of Asuryan", "Sacred Flame of Asuryan")` |

`HALL_BONUS["temple"] = "Public order +%d in this province"`.

`HALL_AI_ROLE["temple"] = "order"`, `_ROLE_WORDS["order"] = ("public_order",)`.

- [ ] **Step 3: Code paths for a hall without a unit, and the extra effect.**

`hall_name`:
```python
def hall_name(guild, n, tag=""):
    """'Lodge of the Brass Tablets': the noun, then the guild with its article. The temple's
    halls carry whole names of their own (temple_nouns): 'Shrine of Hashut', never 'Lodge of
    the Temple of Hashut'."""
    if guild == "temple":
        return HALL_RACES[tag]["temple_nouns"][n]
    return "%s of %s" % (HALL_RACES[tag]["nouns"][n], _with_article(guild, tag))
```

`hall_tables`, where it builds `firsts`:
```python
            firsts = [] if unit is None else [
                (u, _unit_level(u, R["set"]))
                for u in [unit] + ([HALL_FALLBACK[unit]] if unit in HALL_FALLBACK else [])]
```
After the per-level effect rows:
```python
                extra = HALL_EXTRA.get((g, tag))
                if extra:
                    t["building_effects_junction"].append({
                        "building": lv, "effect": extra[0], "effect_scope": extra[1],
                        "value": _s(extra[2][n]),
                        "value_damaged": _s(_half_toward_zero(extra[2][n])),
                        "value_ruined": "0", "context_requirement": ""})
```
The building name loc (`building_culture_variants_name_` + lv) must use `hall_name(g, n, tag)`. If it builds the string inline, change it to call `hall_name`.

`hall_desc`: guard `unit is None` (no "Trains" clause), and append the extra:
```python
    unit = R["units"][guild]
    fb = HALL_FALLBACK.get(unit) if unit else None
    here = [u for u in ([unit] if unit else []) + ([fb] if fb else [])
            if n >= _unit_level(u, R["set"])]
    ...
    extra = HALL_EXTRA.get((guild, tag))
    if extra:
        out += " %s." % (extra[3] % extra[2][n])
```
Place the extra sentence after `" Lowers the price of their services."`. Its text has no "Trains", which `_desc_problems` requires.

`_dlc_problems`: first line of the loop, `if u is None: continue`. Do the same in `_roster_problems` (5845 area) if it indexes `units[g]`.

The promotion line (3517-3521):
```python
                            "text": _body + " You may now raise a %s." % hall_name(
                                _g, HALL_RANK.index(_r), tag),
```
`check_promotion_text`: regex `r"message_event_text_text_derpy_gg_rank_([a-z]+)_(\d)_primary(_hall)?$"`, then `g = m.group(1)`, `r = int(m.group(2))`, the hall group is `m.group(3)` (replace each later `m.group(2)` with `m.group(3)`). The noun test becomes `if "You may now raise a %s." % hall_name(g, HALL_RANK.index(r), tag) not in row["text"]:`. `len(hall_keys) != len(GUILDS) * 2` is already derived.

- [ ] **Step 4: Run `GEN --selftest`, then `GEN --check` (background).** Expected: both green. Expect `check_halls` to report the hall icon files missing (`ui/buildings/icons/derpy_gg_hall_temple*.png`) until Task 7. Task 7 creates them; re-run after it.

- [ ] **Step 5: Run `H`.** Expected: `harness ok`, including the eight hall totals of 21 moved in Task 1. The Lua's hall code loops `GG.GUILDS`; nothing else changes. If `GG.hall_guild` rejects `temple`, check that its `string.match(chain, "^derpy_gg_hall_(%l+)")` result is compared against `GG.GUILDS`, which now holds it.

---

### Task 7: Icons and backgrounds

**Files:**
- Modify: `tools/make_guild_icons.py` (CRLF): `ICONS`, the `HALL_ICONS` loop, `selftest`
- Modify: `tools/make_guild_backgrounds.py` (LF): `CA_ART`, `WINDOWS`, `CA_BACKGROUNDS`, `selftest`
- Modify: `zzz_derpy_guilds_ui.lua` (CRLF): `GGUI.GUILD_ICON`, `GGUI.PANEL_BG`
- Create (generated): `Modding Files/pack/ui/campaign ui/derpy_gg_icons/temple*.png` (9), `Modding Files/pack/ui/buildings/icons/derpy_gg_hall_temple*.png` (8), `Modding Files/pack/ui/campaign ui/derpy_gg_bg/temple*.png` (9)

- [ ] **Step 1: Make the selftests fail.**
  - `make_guild_icons.py` selftest: add `"temple"` to the `g in (...)` tuple. `== 48` becomes `== 56`.
  - `make_guild_backgrounds.py` selftest: replace the two race loops with:

```python
    # EVERY FLAVOUR has a ground per guild: six windows of its race's picture for the six
    # older guilds (BACKGROUNDS / RACE_ART for the Chaos Dwarfs and the Dwarfs), and the
    # seventh window of that same CA picture for the temple.
    for race in CA_ART:
        mine = dict((n[:-len(race) - 1], w) for n, (r, w) in CA_BACKGROUNDS.items()
                    if r == race and n.endswith("_" + race))
        if race in ("chd", "dwf"):
            assert mine == ({"temple": 7} if race == "dwf" else {}), (race, mine)
            continue
        assert sorted(mine) == sorted(list(BACKGROUNDS) + ["temple"]), (race, sorted(mine))
        assert sorted(mine.values()) == sorted(WINDOWS), (race, mine)
    assert CA_BACKGROUNDS["temple"] == ("chd", 7), "the Chaos Dwarf temple ground"
    for race in set(n.rsplit("_", 1)[1] for n in RACE_ART):
        mine = [n[:-len(race) - 1] for n in RACE_ART if n.endswith("_" + race)]
        assert sorted(mine) == sorted(BACKGROUNDS), (race, sorted(mine))
        assert [n for n in CA_BACKGROUNDS if n.endswith("_" + race)] == ["temple_" + race], race
```

  Run both `--selftest`s. Expected: FAIL.

- [ ] **Step 2: Icons.** In `ICONS`, after the High Elf block:
```python
    # THE TEMPLE (2026-10-04), one CA temple or college icon per race, each measured a flat
    # silhouette (100% one colour, 74x74) before it was picked.
    "chd_tower_temple_of_hashut": "temple",
    "empire_altdorf_college": "temple_emp",
    "special_ancestors_hall": "temple_dwf",
    "bretonnia_abbey_of_the_grail_companions": "temple_brt",
    "wh3_main_special_cth_li_temple": "temple_cth",
    "kislev_great_orthodoxy": "temple_ksl",
    "special_har_ganeth_temple_of_khaine": "temple_def",
    "high_elves_worship": "temple_hef",
    "minor_cult_shallya": "temple_gen",
```
`HALL_ICONS`: add `"chd_tower_temple_of_hashut": "derpy_gg_hall_temple",` to the literal block, and `"temple"` to the `_g` tuple of the seven-race loop.

Alternates if a pick reads badly at 38px in the Task 8 render (all measured flat):
- `great_temple_of_hashut_chd`
- `cathay_special_phoenix_temple`
- `kislev_temple_of_ursen`
- `def_black_khaine_lash`
- `special_shrine_of_khaine_def`
- `high_elves_chamber_of_the_phoenix_crown`
- `minor_cult_illumination`

- [ ] **Step 3: Backgrounds.**
```python
    # THE TEMPLE'S GROUND for the two races whose other six come from BACKGROUNDS / RACE_ART.
    "chd": "ui/loading_ui/load_images/campaign_chaos_dwarfs1.png",
    "dwf": "ui/loading_ui/load_images/campaign_dwarfs1.png",
```
in `CA_ART`.
```python
    # THE TEMPLE (2026-10-04): a seventh window between the two rows, centred, so it differs
    # from all six and stays inside the 1080-tall Cathay and Kislev paintings.
    7: (565, 265, 1355, 965),
```
in `WINDOWS`.

`CA_BACKGROUNDS`:
```python
    "temple": ("chd", 7), "temple_emp": ("emp", 7), "temple_dwf": ("dwf", 7),
    "temple_brt": ("brt", 7), "temple_cth": ("cth", 7), "temple_ksl": ("ksl", 7),
    "temple_def": ("def", 7), "temple_hef": ("hef", 7), "temple_gen": ("gen", 7),
```
The selftest's `race in ("chd", "dwf")` branch reads `mine` by suffix: `"temple"` has no `_chd` suffix and is asserted separately.

- [ ] **Step 4: The panel Lua's two art tables.** Add to `GGUI.GUILD_ICON`:
```lua
    temple       = "ui/campaign ui/derpy_gg_icons/temple.png",
```
and to `GGUI.PANEL_BG`:
```lua
    temple       = "ui/campaign ui/derpy_gg_bg/temple.png",
```

- [ ] **Step 5: Build the art.** Run `py tools/make_guild_icons.py`, then `py tools/make_guild_backgrounds.py`. Then run each with `--check` and `--selftest`. Expected: all exit 0, and the backgrounds print a factor per new ground. Then run `py tools/make_guild_bundle_icons.py`, which derives the temple's effect-bundle icons from the card icons.

- [ ] **Step 6: Look at them.** Open `Modding Files/pack/ui/campaign ui/derpy_gg_bg/temple_*.png` and the nine icons with the Read tool. Rule: a ground whose window shows a cut-off face or a logo gets a different box at the same size. Change only window 7, and move it only within the 1920x1080 frame.

---

### Task 8: The panel

**Files:**
- Modify: `zzz_derpy_guilds_ui.lua` (CRLF):
  - `GGUI.PAGE` comment (31), `GGUI.GUILD_ORDER` (33)
  - `PANEL_XY` `gg_gtab_*` / `gg_gsel` / `gg_gbar` (294-301)
  - `ROW_CHILD_XY`, and the row placement at 775
- Modify: `tools/gen_guilds_ui.py` (CRLF):
  - `GUILD_BTNS`, `PANEL_LAYOUT` (100-115), `ROW_H`, `ROW_LAYOUT` (150-165)
  - the row-end check (2432), the pager check (2487)
- Modify: `tools/preview_guilds_panel.py` (CRLF): `("row", 6)` (546), the `--page` flag
- Modify: `tools/_guilds_harness.lua`: the dump's `GGUI.PAGE` (8033)

- [ ] **Step 1: Make the UI check fail.** In `gen_guilds_ui.py`:
  - :2487-2488 becomes a comparison against the Lua's order:
```python
    order = re.search(r"GGUI\.GUILD_ORDER = \{(.*?)\}", io.open(UI_LUA, encoding="utf-8").read(), re.S)
    names = re.findall(r'"([a-z]+)"', order.group(1)) if order else []
    if names != G.GUILDS:
        out.append("GGUI.GUILD_ORDER %s is not the generator's GUILDS %s" % (names, G.GUILDS))
```
  Use the module's existing name for the panel Lua path; grep `zzz_derpy_guilds_ui.lua` in the file.
  - :2432 becomes `rows_end = 170 + (len(G.GUILDS) - 1) * ROW_STEP + ROW_H`, with the message "the %d standings rows" % len(G.GUILDS).

  Run `py tools/gen_guilds_ui.py --check`. Expected: FAIL (GUILD_ORDER has six).

- [ ] **Step 2: Coordinates, generator side.**
```python
GUILD_BTNS = ["gg_gtab_%d" % (_i + 1) for _i in range(len(G.GUILDS))]
GTAB_W, GTAB_STEP = 38, 48
for _i, _name in enumerate(GUILD_BTNS):
    PANEL_LAYOUT[_name] = (232 + _i * GTAB_STEP, 596, GTAB_W, GTAB_W)
PANEL_LAYOUT["gg_gsel"] = (232, 590, GTAB_W, 4)
```
Update the comment above it to "seven glyph buttons ... (232..558 around 395)".

`PANEL_LAYOUT["gg_gbar"] = (152, 595, 486, 40)`. Update the comment: "486 wide at x=152, still 80px past each end button, clear of the pager (20..58, 732..770)". If `G` is not imported where `GUILD_BTNS` is defined, use a literal `range(7)` with a comment naming `G.GUILDS`, and keep the pager check from Step 1 as the guard.

`ROW_W, ROW_H = 750, 34`, and add `ROW_STEP = 38` with the comment "seven rows inside 170..436: the last ends at 170 + 6 * 38 + 34 = 432".

`ROW_LAYOUT`: `row_icon (6, 2, 30, 30)`, `row_guild (46, 5, 170, 24)`, `row_rank (222, 5, 186, 24)`, `row_leader (416, 5, 324, 24)`.

- [ ] **Step 3: Coordinates, Lua side.**
```lua
GGUI.PAGE = 1     -- which guild, 1..#GGUI.GUILD_ORDER

GGUI.GUILD_ORDER = {"brass", "immortals", "daemonsmiths", "khanate",
                    "overseers", "slavers", "temple"}
```
The `PANEL_XY` button rows: `gg_gtab_1 = {232, 596}` through `gg_gtab_7 = {520, 596}` (step 48), `gg_gsel = {232, 590}`, `gg_gbar = {152, 595}`. The comment becomes "The seven guild buttons".

The row placement: `row:MoveTo(px + P(20), py + P(170 + (i - 1) * GGUI.ROW_STEP))`, with `GGUI.ROW_STEP = 38` declared beside `GGUI.ROW_CHILD_XY`, and `ROW_CHILD_XY` updated to the Step 2 x/y values.

Run `py tools/gen_guilds_ui.py --check`. Expected: exit 0. The `_lua_xy_tables` mirror compares both sides. If a race's button-bar layer check (the GBAR_LAYERS / race bar fits at 2523/2541) reports a size mismatch against 486, rescale that race's bar entry to the new width by the same rule its comment states (whole-bar scale, or a slice). The render in Step 5 judges it.

- [ ] **Step 4: Preview knobs.**
  - `preview_guilds_panel.py:546`: `("row", 6)` becomes `("row", len(G.GUILDS))`. Import `gen_great_guilds as G` if the file does not have it; it reads the generator elsewhere, so use the existing alias.
  - Harness dump (:8033): `GGUI.TAB, GGUI.PAGE, GGUI.LOG_PAGE = tab, tonumber(os.getenv("GG_DUMP_PAGE")) or 1, 1`, with the comment "GG_DUMP_PAGE draws that guild's page; unset, page 1".
  - `preview_guilds_panel.py`: `snapshot(tag, help_page, page=None)` sets `env["GG_DUMP_PAGE"] = str(page)` when given, and the CLI takes `--page N` the way it takes `--flavour`. It renders into file names suffixed `_g<N>`.

- [ ] **Step 5: Render and judge.** Run:
```
py tools/preview_guilds_panel.py
py tools/preview_guilds_panel.py --page 7
py tools/preview_guilds_panel.py --flavour emp --page 7
py tools/preview_guilds_panel.py --flavour def --page 7
py tools/preview_guilds_panel.py --help-page 2
py tools/preview_guilds_panel.py --flavour emp --help-page 2
```
Expected: exit 0, no `TOO WIDE` and no `LOW CONTRAST`. Read each PNG with the Read tool and compare with the previous render in `.skilltree_cache/ui_preview/`:
- seven buttons centred on the bar, ends clear of the arrows;
- seven standings rows, the faction list starting below the last;
- the temple's cards and header on page 7;
- Help page 2 holding all seven bullets;
- the Court header fitting for a hall race (`GGUI.HALLS_IN_HEADER`).

Fix and render again until each holds. The first pass is never done.

- [ ] **Step 6: Run `H`.** Expected: `harness ok`.

---

### Task 9: Mutation coverage

**Files:**
- Modify: `tools/mutate_guilds.py` (LF)

- [ ] **Step 1: Re-anchor.** Run `py tools/mutate_guilds.py --selftest`. Every `STALE ANCHOR` line names an anchor this work moved; expect :577 (`GG.hall_guild(chain) or GG.guild_of_chain(chain)`). Re-aim each at the new code, keeping the same rule. For :577, aim it at `local guild = GG.hall_guild(chain) or GG.guild_of_chain(chain, GG.tag(faction))` with the same replacement intent.

- [ ] **Step 2: Add one mutant per new rule.** Each is `(description, M, anchor, replacement)`, an anchor that matches once:
  - "the race words never consulted": `local race = tag and GG.BUILDING_THEME_RACE[tag]` becomes `local race = nil`
  - "devout counted per settlement, not per province": `regs:item_at(0):public_order() > 0` becomes `regs:item_at(0):public_order() >= 0`
  - "vampiric corruption forgotten": `if r.vampiric then taints[2] = "wh3_main_corruption_vampiric" end` becomes `if false then taints[2] = "wh3_main_corruption_vampiric" end`
  - "holy war paid for any win": `if ok and won == true then` becomes `if ok then`
  - "priests paid to the spies": `guild, source = "temple", "priests"` becomes `guild, source = "khanate", "agents"`
  - "the temple's bounty aims anywhere": `if guild == "temple" then pool = GG.holy_pool(faction, pool) end` becomes `if false then pool = GG.holy_pool(faction, pool) end`
  - "a race with holy cultures keeps the whole pool": `if ok and want[c] then out[#out + 1] = pool[i] end` becomes `out[#out + 1] = pool[i]`
  - "the temple's cap forgotten": `khanate = 40, overseers = 40, slavers = 80, temple = 40}` becomes `khanate = 40, overseers = 40, slavers = 80}`, with `cap_temple = 40,` removed from `TUNE_DEFAULTS` by a second mutant on that line

  Every replacement must parse (`luac -p`). `--selftest` proves it.

- [ ] **Step 3: Run the full set in the background, output to a file.**
```
py tools/mutate_guilds.py > "C:/Users/GAYAO-~1/AppData/Local/Temp/claude/g--Modding-for-resources/7c00cf0a-c27a-4d9a-9874-39935f60d18f/scratchpad/mutate_temple.txt" 2>&1
```
Do not pipe it through `tail` (that loses the exit code), and do not build while it runs. Expected: exit 0, every mutant CAUGHT, no SURVIVED, no STALE. A survivor is a missing assertion. Add it to the harness and re-run, never delete the mutant.

- [ ] **Step 4: Restore check.** The runner restores the source, not generated files. Re-run `GEN --write` after it finishes, then `H` and `BH`. Expected: green.

---

### Task 10: Build, verify, deploy, write down

**Files:**
- Modify (generated): the pack `data/derpy_great_guilds.pack` (the importer's target), `zzz_derpy_guilds_bounty_data.lua`, `GGUI.MCT_NAMES`
- Create: `docs/sessions/HANDOFF_20261004_GUILDS_TEMPLE.md`
- Modify: `docs/SESSION_INDEX.md` (one line)

- [ ] **Step 1: Generate.** Run `GEN --write` (background), then `GEN --check` and `GEN --selftest`. Expected: exit 0 for all three. Then run `H`, `BH`, `LUAC` on all four guild Lua files, `py tools/check_lua_api.py`, `py tools/check_lua_undeclared.py` (if the importer does not already run it) and `py tools/check_lua_literal_left.py` on the model file. All must be clean.

- [ ] **Step 2: The share table.** Run the shares script from Task 2 Step 7 for every race, and save its output into the handoff. Also measure `GG.BOUNTY_BUILDINGS[tag]["temple"]` per race from the regenerated `zzz_derpy_guilds_bounty_data.lua` (Ruling 1), and list which races have no temple build job.

- [ ] **Step 3: Build the pack.** Check RPFM is open:
```powershell
Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing
```
Connection refused means stop and tell the author. Otherwise run `py tools/import_great_guilds.py --check`, then `py tools/import_great_guilds.py`. Expected: the importer's own verify passes (services, bounties, art dirs, bundle icons), and the saved pack's tables are exported back and counted.

- [ ] **Step 4: Deploy.** If `Warhammer3.exe` is not running:
  - copy the current `data/` pack to `Modding Files/Backup/guilds_pre_temple_20261004/`;
  - copy the new pack into `data/`;
  - compare MD5 of source and destination.

  There is no Workshop copy of this pack. If the game is running, leave it built and say so.

- [ ] **Step 5: Write the handoff.** Create `docs/sessions/HANDOFF_20261004_GUILDS_TEMPLE.md`:
  - what shipped, with the build MD5;
  - the thirteen rulings;
  - the share table;
  - the races with no temple build job;
  - the in-game checks still to do (spec §9's five).

  Add one line to `docs/SESSION_INDEX.md` pointing at it. Then append the amended §3.2 "per province" wording and the §4 service effects table to the spec, so the spec matches what shipped.
