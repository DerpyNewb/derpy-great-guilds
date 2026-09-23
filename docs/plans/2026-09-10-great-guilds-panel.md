# The Great Guilds — Plan 2 of 3: the panel and the eighteen services

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A runtime-created four-tab panel that shows the six guild ladders and lets the player
spend favour on eighteen rank-gated services.

**Architecture:** `tools/gen_guilds_ui.py` writes three `.twui.xml` files that the campaign Lua
creates components from at runtime with `CreateComponent` — the mod **overrides no CA file**,
so it collides with nothing. Service definitions live once, in `tools/gen_great_guilds.py`, and
both the DB rows and the Lua service table are generated from that one list.

**Tech Stack:** Python 3, Lua 5.1.5, `.twui.xml`, RPFM MCP, TheAssetEditor not required.

**Spec:** `docs/superpowers/specs/2026-09-10-great-guilds-design.md`

**Depends on:** `docs/superpowers/plans/2026-09-10-great-guilds-ladder.md` (plan 1) complete and
deployed. `GG.spend`, `GG.get`, `GG.rank_of` and the save format come from there.

## Global Constraints

Everything in plan 1's Global Constraints still applies, unchanged. Additional to this plan:

- **A new GUID prefix, ledgered in two places.** `DE15xxxx` is **retired** and must never be
  reused — reusing a prefix against a save still holding the old component is a silent
  non-draw. This plan uses **`GG21xxxx`**. Record it in `tools/gen_exchange_ui.py`'s ledger and
  in `docs/CUSTOM_UI.md`'s ledger before writing any XML.
- **GUID format is 8-4-4-16.** Every component needs an entry in the `<hierarchy>` tree **and**
  in the flat `<components>` block, bound by the same `this=` GUID. Miss the hierarchy node and
  the file is valid, well-formed, and never drawn.
- **`dockpoint` is ignored on a runtime component. `MoveTo` is the only thing that positions
  one**, and a layout group beats `MoveTo`. No parent in this panel may be a layout group.
- **A runtime component inherits no context.** `SetContextObject` revives one only for a CCO.
- **`Bounds()` includes children; `Dimensions()` does not.** `get_screen_resolution()` is
  `Dimensions()`. The ui root is not an exception.
- **A missing imagepath draws a blank square, silently.** A byte-grep finding the path is not
  proof the image loads.
- **`SetStateText` is per state.** A dynamic label written to only one state vanishes on
  mouseover. Write every state, and a state with no transitionmap edge pointing at it is never
  entered.
- **Never cache a `UIComponent` handle.** `is_uicomponent()` is a type test and a destroyed
  component still passes it.
- **A panel title plate cannot widen** — a renamed header clips silently at about 19
  characters.
- **`GetTooltipText` and `GetImagePath` hard-crash on HUD buttons.** Write, never read.
- **`ui/**/*.png` in CA's packs is compressed** — a byte-grep gets the path, not a usable PNG.
  RPFM must do icon extraction.

---

## File Structure

| File | Responsibility |
|---|---|
| `tools/gen_great_guilds.py` (modify) | Gains `SERVICES`, the 12 service bundles, service loc. Still the only source of truth. |
| `tools/gen_guilds_ui.py` | Writes the three `.twui.xml` files. Owns the `GG21xxxx` GUID ledger. `--check`, `--selftest`. |
| `tools/check_guilds_ui.py` | Build-time UI checker modelled on `check_rite_panel_ui.py`. `--selftest` breaks each fault in memory and confirms it is caught. |
| `Modding Files/pack/ui/campaign ui/derpy_gg_panel.twui.xml` | Panel frame, tab strip, pager. |
| `Modding Files/pack/ui/campaign ui/derpy_gg_card.twui.xml` | One service card template. |
| `Modding Files/pack/ui/campaign ui/derpy_gg_row.twui.xml` | One standings row template. |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` | Panel creation, tabs, pages, buy handlers, opener button. |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (modify) | Gains `GG.SERVICES`, `GG.buy`, cooldowns. |

---

### Task 1: The eighteen service definitions and their twelve bundles

**Files:**
- Modify: `tools/gen_great_guilds.py`
- Modify: `Modding Files/source/great_guilds/effect_bundles.tsv` (regenerated)
- Modify: `Modding Files/source/great_guilds/effect_bundles_to_effects_junctions.tsv` (regenerated)
- Modify: `Modding Files/source/great_guilds/derpy_great_guilds.loc.tsv` (regenerated)

**Interfaces:**
- Consumes: `GUILDS`, `RANK_EFFECTS`, `build()` from plan 1.
- Produces: `SERVICES` (list of 18 dicts), `service_bundle_key(service_key) -> str`,
  `lua_service_table() -> str`.

- [ ] **Step 1: Write the failing selftest additions**

Append to `selftest()` in `tools/gen_great_guilds.py`:

```python
    assert len(SERVICES) == 18, "18 services, got %d" % len(SERVICES)
    assert len(set(s["key"] for s in SERVICES)) == 18, "service keys unique"
    for g in GUILDS:
        mine = [s for s in SERVICES if s["guild"] == g]
        assert len(mine) == 3, "%s has %d services, want 3" % (g, len(mine))
        assert sorted(s["rank"] for s in mine) == [2, 3, 4], "%s ranks must be 2,3,4" % g
        assert sorted(s["cost"] for s in mine) == [50, 150, 400], "%s costs" % g
    bundled = [s for s in SERVICES if s["kind"] == "bundle"]
    assert len(bundled) == 12, "12 bundle services, got %d" % len(bundled)
    eb = build()["effect_bundles"]
    assert len(eb) == 36, "24 rank + 12 service = 36, got %d" % len(eb)
    assert all(r["is_global_effect"] == "true" for r in eb), "is_global_effect"
    for s in SERVICES:
        assert s["cd"] >= 5, "cooldown floor is 5 turns: " + s["key"]
        assert s["kind"] in ("bundle", "gold", "unit", "research",
                            "shroud", "building", "pooled"), "kind: " + s["kind"]
    print("selftest ok: %d services, %d bundles" % (len(SERVICES), len(eb)))
```

- [ ] **Step 2: Run it to verify it fails**

```powershell
py tools\gen_great_guilds.py --selftest
```

Expected: `NameError: name 'SERVICES' is not defined`.

- [ ] **Step 3: Add `SERVICES` and `service_bundle_key`**

```python
# The eighteen services. rank is the rank that unlocks it (2 indebted, 3 sworn,
# 4 favoured). kind decides which payload runs; only kind == "bundle" mints an
# effect bundle. Every cm: call named in a comment was verified present in
# campaign/episodic_scripting.html on 2026-09-10.
SERVICES = [
    # Brass Tablets
    {"key": "caravan_levy",     "guild": "brass", "rank": 2, "cost": 50,  "cd": 8,
     "kind": "gold",   "value": 2500, "name": "Caravan Levy"},
    {"key": "writ_monopoly",    "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 10, "name": "Writ of Monopoly"},
    {"key": "long_ledger",      "guild": "brass", "rank": 4, "cost": 400, "cd": 20,
     "kind": "bundle", "turns": 15, "name": "The Long Ledger"},
    # Immortals
    {"key": "oathbound_draft",  "guild": "immortals", "rank": 2, "cost": 50,  "cd": 6,
     "kind": "bundle", "turns": 5,  "name": "Oathbound Draft"},
    {"key": "hire_immortals",   "guild": "immortals", "rank": 3, "cost": 150, "cd": 10,
     "kind": "unit",   "unit": "wh3_dlc23_chd_inf_infernal_guard_0",
     "name": "Hire the Immortals"},
    {"key": "astragoths_levy",  "guild": "immortals", "rank": 4, "cost": 400, "cd": 15,
     "kind": "bundle", "turns": 10, "name": "Astragoth's Levy"},
    # Daemonsmiths
    {"key": "forge_rite",       "guild": "daemonsmiths", "rank": 2, "cost": 50,  "cd": 8,
     "kind": "bundle", "turns": 8,  "name": "Forge-Rite"},
    {"key": "bound_blueprint",  "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 14,
     "kind": "research", "name": "Bound Blueprint"},
    {"key": "bound_ordnance",   "guild": "daemonsmiths", "rank": 4, "cost": 400, "cd": 15,
     "kind": "bundle", "turns": 10, "name": "Daemon-Bound Ordnance"},
    # Khanate
    {"key": "hobgoblin_eyes",   "guild": "khanate", "rank": 2, "cost": 50,  "cd": 6,
     "kind": "shroud", "name": "Hobgoblin Eyes"},
    {"key": "knife_in_dark",    "guild": "khanate", "rank": 3, "cost": 150, "cd": 10,
     "kind": "bundle", "turns": 8,  "name": "Knife in the Dark"},
    {"key": "khans_price",      "guild": "khanate", "rank": 4, "cost": 400, "cd": 18,
     "kind": "bundle", "turns": 10, "hostile": True, "name": "The Khan's Price"},
    # Overseers
    {"key": "lash_the_gangs",   "guild": "overseers", "rank": 2, "cost": 50,  "cd": 6,
     "kind": "bundle", "turns": 6,  "name": "Lash the Gangs"},
    {"key": "raise_ziggurat",   "guild": "overseers", "rank": 3, "cost": 150, "cd": 12,
     "kind": "building", "name": "Raise the Ziggurat"},
    {"key": "works_of_zharr",   "guild": "overseers", "rank": 4, "cost": 400, "cd": 15,
     "kind": "bundle", "turns": 12, "name": "Works of Zharr"},
    # Slavers
    {"key": "coffle_drive",     "guild": "slavers", "rank": 2, "cost": 50,  "cd": 8,
     "kind": "bundle", "turns": 8,  "name": "Coffle Drive"},
    {"key": "slave_tithe",      "guild": "slavers", "rank": 3, "cost": 150, "cd": 10,
     "kind": "pooled", "name": "Slave Tithe"},
    {"key": "great_coffle",     "guild": "slavers", "rank": 4, "cost": 400, "cd": 18,
     "kind": "bundle", "turns": 12, "name": "The Great Coffle"},
]

def service_bundle_key(service_key):
    return "derpy_gg_svc_" + service_key
```

- [ ] **Step 4: Extend `build()` to emit the twelve service bundles**

Inside `build()`, after the rank loop and before the `return`:

```python
    for s in SERVICES:
        loc.append({"key": "derpy_gg_service_name_%s" % s["key"],
                    "text": s["name"], "tooltip": "false"})
        if s["kind"] != "bundle":
            continue
        key = service_bundle_key(s["key"])
        bundles.append({"key": key, "ui_name": "", "icon": "", "priority": "0",
                        "is_global_effect": "true", "colour": ""})
        junctions.append({"effect_bundle_key": key,
                          "effect_key": RANK_EFFECTS[s["guild"]],
                          "scope": "faction_to_faction_own",
                          "value": "10"})
        loc.append({"key": "effect_bundles_localised_title_%s" % key,
                    "text": s["name"], "tooltip": "false"})
        loc.append({"key": "effect_bundles_localised_description_%s" % key,
                    "text": "%s. %%+n" % s["name"], "tooltip": "false"})
```

- [ ] **Step 5: Run the selftest to verify it passes**

```powershell
py tools\gen_great_guilds.py --selftest ; py tools\gen_great_guilds.py --check
```

Expected: `selftest ok: 18 services, 36 bundles`, then `--check` exits 0.

- [ ] **Step 6: Verify the one unit key against the DB**

`hire_immortals` names `wh3_dlc23_chd_inf_infernal_guard_0`. **A typo'd unit key does nothing,
forever, with no error.** Confirm it exists:

```powershell
py -c "import sys; sys.path.insert(0,'tools'); import read_vanilla_cache as R; rows,_=R.load('main_units'); ks=set(r['unit'] for r in rows) | set(r.get('land_unit','') for r in rows); print([k for k in ks if 'infernal_guard' in str(k)][:20])"
```

Replace the literal with a key that appears in that output. Then re-run `--check`.

- [ ] **Step 7: Regenerate the TSVs**

```powershell
py -c "import sys; sys.path.insert(0,'tools'); import gen_great_guilds as G; print('\n'.join(G.write_tsvs(r'Modding Files/source/great_guilds')))"
```

---

### Task 2: The spend path, cooldowns and the rank gate

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`
- Modify: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.get`, `GG.spend`, `GG.rank_of` from plan 1.
- Produces: `GG.SERVICES` (array of tables), `GG.service(key) -> table`,
  `GG.can_buy(faction, service_key) -> bool, reason_key`,
  `GG.buy(faction, service_key, target) -> bool, reason_key`,
  `GG.cooldown_left(faction, service_key) -> int`, `GG.tick_cooldowns(faction)`.

**Reason keys are keys, never sentences.** A loc call from a turn handler is a CTD at turn 1
and pcall does not catch it, so `can_buy` returns a key and the panel resolves it at draw time.

- [ ] **Step 1: Write the failing harness assertions**

Append to `tools/_guilds_harness.lua`, before the final `print`:

```lua
-- Rank gate: a service above your rank refuses.
GG.state["cr_buy"] = nil
GG.grant("cr_buy", "brass", 120)          -- rank 2, 120 favour
local ok, why = GG.can_buy("cr_buy", "writ_monopoly")   -- needs rank 3
assert(ok == false and why == "rank", "rank gate, got "..tostring(why))

-- Affordability.
ok, why = GG.can_buy("cr_buy", "caravan_levy")          -- rank 2, costs 50
assert(ok == true, "should be buyable, got "..tostring(why))
assert(GG.buy("cr_buy", "caravan_levy") == true, "buy succeeds")
local _, fav = GG.get("cr_buy", "brass")
assert(fav == 70, "buy took 50 favour, got "..fav)

-- Cooldown blocks an immediate repeat.
ok, why = GG.can_buy("cr_buy", "caravan_levy")
assert(ok == false and why == "cooldown", "cooldown blocks, got "..tostring(why))
assert(GG.cooldown_left("cr_buy", "caravan_levy") == 8, "8 turn cooldown")

-- Cooldown ticks down and clears.
for _ = 1, 8 do GG.tick_cooldowns("cr_buy") end
assert(GG.cooldown_left("cr_buy", "caravan_levy") == 0, "cooldown cleared")

-- Poverty.
GG.state["cr_poor"] = nil
GG.grant("cr_poor", "brass", 100)
GG.spend("cr_poor", "brass", 99)
ok, why = GG.can_buy("cr_poor", "caravan_levy")
assert(ok == false and why == "favour", "poverty refuses, got "..tostring(why))

-- Buying must never move reputation, so it can never demote.
local rrep = select(1, GG.get("cr_buy", "brass"))
assert(rrep == 120, "buying moved reputation - the design's core invariant, got "..rrep)
```

- [ ] **Step 2: Run it to verify it fails**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `attempt to call field 'can_buy' (a nil value)`.

- [ ] **Step 3: Implement the spend path**

Append to `zzz_derpy_guilds.lua`. `GG.SERVICES` mirrors `SERVICES` in the generator — if one
changes, change both, and Task 7's importer refuses on a mismatch.

```lua
-- Mirrors SERVICES in tools/gen_great_guilds.py. rank gates it, cost is favour,
-- cd is the cooldown in turns. kind decides the payload; see GG.payload.
GG.SERVICES = {
    {key="caravan_levy",    guild="brass",        rank=2, cost=50,  cd=8,  kind="gold",     value=2500},
    {key="writ_monopoly",   guild="brass",        rank=3, cost=150, cd=12, kind="bundle",   turns=10},
    {key="long_ledger",     guild="brass",        rank=4, cost=400, cd=20, kind="bundle",   turns=15},
    {key="oathbound_draft", guild="immortals",    rank=2, cost=50,  cd=6,  kind="bundle",   turns=5},
    {key="hire_immortals",  guild="immortals",    rank=3, cost=150, cd=10, kind="unit"},
    {key="astragoths_levy", guild="immortals",    rank=4, cost=400, cd=15, kind="bundle",   turns=10},
    {key="forge_rite",      guild="daemonsmiths", rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="bound_blueprint", guild="daemonsmiths", rank=3, cost=150, cd=14, kind="research"},
    {key="bound_ordnance",  guild="daemonsmiths", rank=4, cost=400, cd=15, kind="bundle",   turns=10},
    {key="hobgoblin_eyes",  guild="khanate",      rank=2, cost=50,  cd=6,  kind="shroud"},
    {key="knife_in_dark",   guild="khanate",      rank=3, cost=150, cd=10, kind="bundle",   turns=8},
    {key="khans_price",     guild="khanate",      rank=4, cost=400, cd=18, kind="bundle",   turns=10, hostile=true},
    {key="lash_the_gangs",  guild="overseers",    rank=2, cost=50,  cd=6,  kind="bundle",   turns=6},
    {key="raise_ziggurat",  guild="overseers",    rank=3, cost=150, cd=12, kind="building"},
    {key="works_of_zharr",  guild="overseers",    rank=4, cost=400, cd=15, kind="bundle",   turns=12},
    {key="coffle_drive",    guild="slavers",      rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="slave_tithe",     guild="slavers",      rank=3, cost=150, cd=10, kind="pooled"},
    {key="great_coffle",    guild="slavers",      rank=4, cost=400, cd=18, kind="bundle",   turns=12},
}

GG.cooldowns = GG.cooldowns or {}   -- [faction][service_key] = turns remaining

function GG.service(key)
    for i = 1, #GG.SERVICES do
        if GG.SERVICES[i].key == key then return GG.SERVICES[i] end
    end
    return nil
end

function GG.cooldown_left(faction, service_key)
    local f = GG.cooldowns[faction]
    if not f then return 0 end
    return f[service_key] or 0
end

function GG.tick_cooldowns(faction)
    local f = GG.cooldowns[faction]
    if not f then return end
    for k, v in pairs(f) do
        if v > 0 then f[k] = v - 1 end
    end
end

function GG.can_buy(faction, service_key)
    local s = GG.service(service_key)
    if not s then return false, "unknown" end
    local rep, fav = GG.get(faction, s.guild)
    if GG.rank_of(rep) < s.rank then return false, "rank" end
    if GG.cooldown_left(faction, service_key) > 0 then return false, "cooldown" end
    if fav < s.cost then return false, "favour" end
    return true, nil
end

function GG.buy(faction, service_key, target)
    local ok, why = GG.can_buy(faction, service_key)
    if not ok then return false, why end
    local s = GG.service(service_key)
    if not GG.spend(faction, s.guild, s.cost) then return false, "favour" end
    GG.cooldowns[faction] = GG.cooldowns[faction] or {}
    GG.cooldowns[faction][service_key] = s.cd
    GG.payload(faction, s, target)
    return true, nil
end
```

- [ ] **Step 4: Run the harness to verify it passes**

`GG.payload` does not exist yet, so stub it at the top of the block you just added:

```lua
function GG.payload(faction, service, target) end  -- replaced in Task 3
```

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `harness ok`.

- [ ] **Step 5: Save the cooldowns**

Cooldowns must survive a reload or every service is free after one save. Extend `GG.save` and
`GG.load` to pack them after the six standing pairs, separated by a `;`:

```lua
-- in GG.save, before cm:set_saved_value:
    local cds = {}
    local f_cd = GG.cooldowns[faction] or {}
    for i = 1, #GG.SERVICES do
        cds[#cds + 1] = tostring(f_cd[GG.SERVICES[i].key] or 0)
    end
    cm:set_saved_value("derpy_gg_" .. faction,
                       table.concat(parts, "|") .. ";" .. table.concat(cds, "|"))
```

and in `GG.load`, split on `;` first, parse the left half as before, then:

```lua
    local body, cdpart = string.match(packed, "^([^;]*);?(.*)$")
    -- ... existing pair loop over body ...
    if cdpart and cdpart ~= "" then
        local j = 1
        GG.cooldowns[faction] = {}
        for chunk in string.gmatch(cdpart, "[^|]+") do
            local s = GG.SERVICES[j]
            if s then GG.cooldowns[faction][s.key] = tonumber(chunk) or 0 end
            j = j + 1
        end
    end
```

Add a harness assertion that a cooldown survives a save/load round trip, then re-run.

---

### Task 3: The six non-bundle payloads

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`
- Modify: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.service`, `GG.SERVICES` from Task 2.
- Produces: `GG.payload(faction, service, target)`.

Twelve services apply an effect bundle. The other six do six different things, and each names a
`cm:` call verified present on 2026-09-10.

- [ ] **Step 1: Extend the harness stubs and add the failing assertions**

In `tools/_guilds_harness.lua`, extend the `cm` stub:

```lua
local gold, units, research, shroud, built, pooled = {}, {}, {}, {}, {}, {}
cm.treasury_mod = function(_, f, n) gold[#gold+1] = {f, n} end
cm.grant_unit_to_character = function(_, cqi, u) units[#units+1] = {cqi, u} end
cm.instantly_research_technology = function(_, f, t) research[#research+1] = {f, t} end
cm.make_region_visible_in_shroud = function(_, f, r) shroud[#shroud+1] = {f, r} end
cm.instantly_upgrade_building = function(_, r) built[#built+1] = {r} end
cm.faction_add_pooled_resource = function(_, f, res, fac, n)
    pooled[#pooled+1] = {f, res, fac, n} end
```

and after the buy tests:

```lua
GG.state["cr_pay"] = nil
GG.grant("cr_pay", "brass", 200)
GG.buy("cr_pay", "caravan_levy")
assert(#gold == 1 and gold[1][2] == 2500, "caravan levy pays 2500")

GG.state["cr_pay2"] = nil
GG.grant("cr_pay2", "slavers", 400)
GG.buy("cr_pay2", "slave_tithe")
assert(#pooled == 2, "slave tithe grants two CHD resources, got "..#pooled)
assert(pooled[1][2] == "wh3_dlc23_chd_armaments", "armaments first")

-- A non-Chaos-Dwarf faction gets gold instead, never a resource it does not own.
GG.CULTURE_OF = {cr_human = "wh_main_emp_empire"}
GG.state["cr_human"] = nil
GG.grant("cr_human", "slavers", 400)
GG.buy("cr_human", "slave_tithe")
assert(#pooled == 2, "no pooled grant for a non-CHD culture, got "..#pooled)
assert(#gold == 2, "non-CHD slave tithe pays gold instead")
```

- [ ] **Step 2: Run it to verify it fails**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: an assertion failure on `caravan levy pays 2500`, because `GG.payload` is the stub.

- [ ] **Step 3: Replace the stub with the real payload**

```lua
-- The one place culture matters in this mod, and it is a branch, not a profile table.
GG.CHD_CULTURE = "wh3_dlc23_chd_chaos_dwarfs"
GG.CULTURE_OF = GG.CULTURE_OF or {}   -- filled at turn start; harness overrides it

local function is_chd(faction)
    return (GG.CULTURE_OF[faction] or GG.CHD_CULTURE) == GG.CHD_CULTURE
end

function GG.payload(faction, s, target)
    if s.kind == "bundle" then
        local who = (s.hostile and target) or faction
        cm:apply_effect_bundle("derpy_gg_svc_" .. s.key, who, s.turns)

    elseif s.kind == "gold" then
        cm:treasury_mod(faction, s.value)

    elseif s.kind == "unit" then
        if target then cm:grant_unit_to_character(target, GG.HIRE_UNIT) end

    elseif s.kind == "research" then
        if target then cm:instantly_research_technology(faction, target) end

    elseif s.kind == "shroud" then
        if target then cm:make_region_visible_in_shroud(faction, target) end

    elseif s.kind == "building" then
        if target then cm:instantly_upgrade_building(target) end

    elseif s.kind == "pooled" then
        if is_chd(faction) then
            cm:faction_add_pooled_resource(faction, "wh3_dlc23_chd_armaments",
                                           "derpy_gg_tithe", 400)
            cm:faction_add_pooled_resource(faction, "wh3_dlc23_chd_raw_materials",
                                           "derpy_gg_tithe", 800)
        else
            cm:treasury_mod(faction, 3000)
        end
    end
end
```

- [ ] **Step 4: Run the harness to verify it passes**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `harness ok`.

- [ ] **Step 5: Resolve `GG.HIRE_UNIT` and the pooled resource factor**

Two literals above are unverified and both fail silently if wrong.

```powershell
py -c "import sys; sys.path.insert(0,'tools'); import read_vanilla_cache as R; rows,_=R.load('pooled_resource_factors'); print([r['key'] for r in rows][:40])"
```

`derpy_gg_tithe` is a **factor key**, and a pooled resource payload's factor is a junction id in
DB but a factor key in Lua — the two are not interchangeable. Either use an existing CA factor
that accepts a grant, or add the factor row to the generator in Task 1 and regenerate. Set
`GG.HIRE_UNIT` to the key confirmed in Task 1 step 6.

- [ ] **Step 6: Run every gate**

```powershell
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_api.py "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_undeclared.py
```

`check_lua_api.py` will name any `cm:` member CA does not document. Fix by finding the
documented name, never by suppressing the finding.

---

### Task 4: The three `.twui.xml` files and the GUID ledger

**Files:**
- Create: `tools/gen_guilds_ui.py`
- Create: `Modding Files/pack/ui/campaign ui/derpy_gg_panel.twui.xml`
- Create: `Modding Files/pack/ui/campaign ui/derpy_gg_card.twui.xml`
- Create: `Modding Files/pack/ui/campaign ui/derpy_gg_row.twui.xml`
- Modify: `docs/CUSTOM_UI.md` (ledger)
- Modify: `tools/gen_exchange_ui.py` (ledger)

**Interfaces:**
- Consumes: `SERVICES` from Task 1 (for card count only).
- Produces: `GUID_PREFIX = "GG21"`, `guid(n) -> str`, `PANEL_LAYOUT` (dict name -> (x, y, w, h)),
  `write_ui(outdir) -> list[str]`, `check() -> list[str]`, `selftest()`.

- [ ] **Step 1: Claim the GUID prefix in both ledgers first**

Before writing any XML, add to the ledger in `docs/CUSTOM_UI.md` and the ledger comment in
`tools/gen_exchange_ui.py`:

    GG21xxxx  derpy_great_guilds  (claimed 2026-09-10)
    DE15xxxx  RETIRED, do not reuse

Reusing a prefix against a save that still holds the old component is a silent non-draw, which
is the failure mode the ledger exists to prevent.

- [ ] **Step 2: Write the failing selftest**

Create `tools/gen_guilds_ui.py` with only:

```python
"""The Great Guilds - UI generator. Owns the GG21xxxx GUID prefix."""
import sys

def selftest():
    seen = {}
    for name in PANEL_LAYOUT:
        g = guid_for(name)
        assert g.startswith(GUID_PREFIX), "guid prefix: " + g
        assert len(g) == 8 + 1 + 4 + 1 + 4 + 1 + 16, "guid is 8-4-4-16: " + g
        assert g not in seen, "duplicate guid %s on %s and %s" % (g, name, seen.get(g))
        seen[g] = name
    files = build_xml()
    assert len(files) == 3, "three xml files, got %d" % len(files)
    for path, text in files.items():
        for name in xml_component_names(text):
            assert text.count('this="%s"' % guid_for(name)) >= 2, (
                "%s in %s must appear in BOTH hierarchy and components" % (name, path))
    print("selftest ok: %d files, %d guids" % (len(files), len(seen)))

if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
```

- [ ] **Step 3: Run it to verify it fails**

```powershell
py tools\gen_guilds_ui.py --selftest
```

Expected: `NameError: name 'PANEL_LAYOUT' is not defined`.

- [ ] **Step 4: Read the Exchange's generator as the working model**

```powershell
py -c "import io; s=io.open(r'tools/gen_exchange_ui.py',encoding='utf-8').read(); print(len(s)); print(s[:6000])"
```

Copy its GUID minting, its hierarchy-plus-components emitter and its file writer. **Do not
invent a second way of emitting `.twui.xml`** — one working emitter already exists in this
workspace and it is the one the UI checker understands.

- [ ] **Step 5: Implement `PANEL_LAYOUT`, `guid_for`, `build_xml`, `write_ui`, `check`**

Follow `gen_exchange_ui.py` exactly. Panel geometry, in the Exchange's own units:

```python
GUID_PREFIX = "GG21"

# name -> (x, y, width, height). Absolute offsets: dockpoint is ignored on a
# runtime component and MoveTo is the only thing that positions one.
PANEL_LAYOUT = {
    "gg_frame":      (0,   0,   790, 700),
    "gg_title":      (20,  14,  400, 30),
    "gg_tab_guilds": (20,  56,  132, 34),
    "gg_tab_stand":  (152, 56,  132, 34),
    "gg_tab_log":    (284, 56,  132, 34),
    "gg_tab_help":   (416, 56,  132, 34),
    "gg_rank_line":  (20,  104, 750, 26),
    "gg_rep_bar":    (20,  134, 750, 18),
    "gg_card_1":     (20,  170, 750, 120),
    "gg_card_2":     (20,  300, 750, 120),
    "gg_card_3":     (20,  430, 750, 120),
    "gg_prev":       (20,  600, 40,  34),
    "gg_next":       (730, 600, 40,  34),
    "gg_footer":     (20,  640, 750, 30),
}
```

The title plate clips silently at about 19 characters, so `gg_title` never receives a guild
name longer than that — the guild name goes in `gg_rank_line`, which is a plain text component
and does not clip.

- [ ] **Step 6: Run the selftest to verify it passes**

```powershell
py tools\gen_guilds_ui.py --selftest ; py tools\gen_guilds_ui.py --check
```

Expected: `selftest ok: 3 files, 14 guids`, then `--check` exits 0.

- [ ] **Step 7: Write the XML**

```powershell
py -c "import sys; sys.path.insert(0,'tools'); import gen_guilds_ui as U; print('\n'.join(U.write_ui(r'Modding Files/pack/ui/campaign ui')))"
```

All three paths must be lowercase — since patch 6.1 an uppercase character in a pack path
crashes the game.

---

### Task 5: Creating the panel at runtime

**Files:**
- Create: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua`

**Interfaces:**
- Consumes: `GG.SERVICES`, `GG.can_buy`, `GG.buy`, `GG.get`, `GG.rank_of`,
  `GG.cooldown_left` from Tasks 2 and 3; `PANEL_LAYOUT` names from Task 4.
- Produces: `GGUI.open()`, `GGUI.close()`, `GGUI.refresh()`, `GGUI.set_tab(n)`,
  `GGUI.set_page(n)`, `GGUI.place_opener()`.

- [ ] **Step 1: Write the file**

```lua
-- The Great Guilds - panel. Creates its own components from the mod's own
-- .twui.xml files; overrides no CA file, so it collides with nothing.
--
-- Rules that are silent when broken, all of them learned the hard way:
--   * dockpoint is ignored. MoveTo is the only thing that positions a runtime
--     component, and a layout group beats MoveTo.
--   * Never cache a UIComponent handle. is_uicomponent() is a type test and a
--     destroyed component still passes it. Re-find every time.
--   * SetStateText is per state. Write every state or a label vanishes on hover.
--   * Bounds() includes children, Dimensions() does not.

GGUI = GGUI or {}
GGUI.TAB = 1
GGUI.PAGE = 1
GGUI.ROOT = "derpy_gg_panel"

GGUI.GUILD_ORDER = {"brass", "immortals", "daemonsmiths", "khanate",
                    "overseers", "slavers"}

local function root()
    return core:get_ui_root()
end

local function comp(name)
    -- Never cached. Returns nil rather than throwing, so a missing component
    -- degrades to a blank cell instead of killing the refresh.
    local ok, c = pcall(function() return find_uicomponent(root(), name) end)
    if ok and c and is_uicomponent(c) then return c end
    return nil
end

local function set_text(name, text)
    local c = comp(name)
    if not c then return end
    for _, state in ipairs({"default", "hover", "selected", "active"}) do
        pcall(function() c:SetStateText(text, state) end)
    end
end

function GGUI.current_guild()
    return GGUI.GUILD_ORDER[GGUI.PAGE] or GGUI.GUILD_ORDER[1]
end

function GGUI.refresh()
    local faction = cm:get_local_faction_name(true)   -- forced: unforced throws in MP
    if not faction then return end
    local guild = GGUI.current_guild()
    local rep, fav = GG.get(faction, guild)
    local rank = GG.rank_of(rep)
    local next_at = GG.RANKS[math.min(rank + 1, #GG.RANKS)]

    set_text("gg_rank_line", GGUI.loc_guild(guild) .. "   " ..
             GGUI.loc_rank(rank) .. "   " .. rep .. " / " .. next_at)
    set_text("gg_footer", GGUI.loc("favour") .. ": " .. fav)

    local n = 0
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if s.guild == guild then
            n = n + 1
            GGUI.draw_card(faction, "gg_card_" .. n, s)
        end
    end
end

function GGUI.draw_card(faction, slot, s)
    local ok, why = GG.can_buy(faction, s.key)
    local label = GGUI.loc_service(s.key)
    if not ok and why == "rank" then
        label = label .. "   [[col:red]]" .. GGUI.loc_rank(s.rank) .. "[[/col]]"
    elseif not ok and why == "cooldown" then
        label = label .. "   " .. GG.cooldown_left(faction, s.key) .. "t"
    end
    set_text(slot .. "_name", label)
    set_text(slot .. "_cost", tostring(s.cost))
    local btn = comp(slot .. "_buy")
    if btn then pcall(function() btn:SetDisabled(not ok) end) end
end
```

- [ ] **Step 2: Add the loc resolvers, which run only at draw time**

```lua
-- Every one of these is a loc call and MUST NOT be reached from a turn handler.
-- A loc call from a turn handler is a CTD at turn 1 and pcall does not catch it.
function GGUI.loc(k)          return effect.get_localised_string("derpy_gg_" .. k) end
function GGUI.loc_guild(g)    return effect.get_localised_string("derpy_gg_guild_name_" .. g) end
function GGUI.loc_service(k)  return effect.get_localised_string("derpy_gg_service_name_" .. k) end
function GGUI.loc_rank(r)     return effect.get_localised_string("derpy_gg_rank_name_" .. r) end
```

- [ ] **Step 3: Wire the buy buttons and the tabs**

```lua
core:add_listener("gg_clicks", "ComponentLClickUp", true, function(context)
    local id = context.string
    if not id then return end
    if string.sub(id, 1, 8) == "gg_card_" and string.find(id, "_buy") then
        local slot = tonumber(string.sub(id, 9, 9))
        local guild = GGUI.current_guild()
        local nth = 0
        for i = 1, #GG.SERVICES do
            local s = GG.SERVICES[i]
            if s.guild == guild then
                nth = nth + 1
                if nth == slot then
                    local faction = cm:get_local_faction_name(true)
                    GG.buy(faction, s.key, GGUI.pick_target(s))
                    GG.save(faction)
                    GGUI.refresh()
                    return
                end
            end
        end
    elseif id == "gg_next" then
        GGUI.PAGE = math.min(GGUI.PAGE + 1, #GGUI.GUILD_ORDER); GGUI.refresh()
    elseif id == "gg_prev" then
        GGUI.PAGE = math.max(GGUI.PAGE - 1, 1); GGUI.refresh()
    end
end, true)
```

- [ ] **Step 4: Place the opener button at turn start, not at UICreated**

```lua
-- UICreated fires before the world exists and the first tick is not the fix
-- either. Brand at turn start.
core:add_listener("gg_opener", "FactionTurnStart", true, function()
    GGUI.place_opener()
end, true)
```

- [ ] **Step 5: Run the gates**

```powershell
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds_ui.lua"
py tools\check_lua_api.py "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds_ui.lua"
py tools\check_lua_undeclared.py
```

`GGUI.pick_target` and `GGUI.place_opener` are referenced and not yet defined — `luac -p` will
pass anyway, because an undeclared Lua global is nil rather than an error. That is exactly why
`check_lua_undeclared.py` exists and it will name both. Define them before proceeding.

---

### Task 6: The UI checker

**Files:**
- Create: `tools/check_guilds_ui.py`

**Interfaces:**
- Consumes: the three `.twui.xml` files, `zzz_derpy_guilds_ui.lua`, `gen_guilds_ui.PANEL_LAYOUT`.
- Produces: `check() -> list[str]`, `selftest()`.

- [ ] **Step 1: Read the model checker**

```powershell
py -c "import io; print(io.open(r'tools/check_rite_panel_ui.py',encoding='utf-8').read()[:8000])"
```

- [ ] **Step 2: Write the checker with these five checks**

Each of these caught a real shipped fault on the last panel:

```python
def check():
    out = []
    out += check_guid_pairing()      # every this= appears in hierarchy AND components
    out += check_names_reached()     # every name the Lua find_uicomponent's exists in XML
    out += check_extent()            # no child sits outside its declared parent box
    out += check_imagepaths()        # every imagepath resolves to a file in the pack
    out += check_states()            # every state has a transitionmap edge pointing at it
    return out
```

- [ ] **Step 3: Write `selftest()` that breaks each fault in memory**

```python
def selftest():
    for breaker, expect in [
        (drop_hierarchy_node,  "hierarchy"),
        (rename_lua_target,    "not in xml"),
        (oversize_child,       "outside"),
        (bad_imagepath,        "imagepath"),
        (orphan_state,         "transitionmap"),
    ]:
        problems = check_against(breaker(load_all()))
        assert any(expect in p for p in problems), "fault not caught: " + expect
    print("selftest ok: 5/5 faults caught")
```

- [ ] **Step 4: Run both**

```powershell
py tools\check_guilds_ui.py --selftest ; py tools\check_guilds_ui.py
```

Expected: `selftest ok: 5/5 faults caught`, then a clean run.

---

### Task 7: Pack, deploy, and verify in game

**Files:**
- Modify: `tools/import_great_guilds.py`

- [ ] **Step 1: Extend the importer's `verify()`**

```python
    # The Lua service table and the Python one must not drift.
    lua = io.open("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua",
                  encoding="utf-8").read()
    for s in G.SERVICES:
        if ('key="%s"' % s["key"]) not in lua and ("key=\"%s\"" % s["key"]) not in lua:
            problems.append("service missing from Lua table: " + s["key"])
    import gen_guilds_ui as U
    problems += U.check()
    import check_guilds_ui as C
    problems += C.check()
```

Add the three UI files and the second script to `SCRIPTS` / a new `UI_FILES` list.

- [ ] **Step 2: Run every gate in order**

```powershell
py tools\gen_great_guilds.py --selftest ; py tools\gen_great_guilds.py --check
py tools\gen_guilds_ui.py --selftest ; py tools\gen_guilds_ui.py --check
py tools\check_guilds_ui.py --selftest ; py tools\check_guilds_ui.py
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
py tools\check_lua_api.py ; py tools\check_lua_undeclared.py
py tools\import_great_guilds.py
```

All must exit 0. The importer refuses to pack if any of them did not.

- [ ] **Step 3: Extract the icons**

Six guild icons and five rank icons, out of CA's packs **through RPFM**. A byte-grep gets the
path and not a usable PNG, because `ui/**/*.png` is compressed in CA's packs.
`tools/export_exchange_icons.py` is the working model for resolving which pack holds what.

- [ ] **Step 4: Pack through RPFM MCP and deploy**

Confirm RPFM is open, bind the schema, import the regenerated TSVs (remember: `import_tsv`
replaces the whole file, so re-import the full accumulated TSV), add the two scripts, the three
UI files and the icons. **Save the pack**, then verify from outside:

```powershell
py tools\read_pack_index.py "Modding Files\Modpacks\derpy_great_guilds.pack"
Copy-Item "Modding Files\Modpacks\derpy_great_guilds.pack" "F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\" -Force
```

- [ ] **Step 5: The in-game checks the offline gates cannot make**

Open the panel and confirm, in this order — each one is a silent failure if wrong:

1. The panel **draws at all**. A GUID pairing fault is a silent non-draw.
2. All six guild pages page through with the arrows.
3. Every card's name, cost and button state renders. A blank square is a missing imagepath.
4. A locked service greys with its rank shown rather than disappearing.
5. One purchase of each of the six `kind`s. Watch favour fall, the cooldown appear, and the
   effect land — read Faction Effects for the bundle kinds.

---

## What plan 2 does NOT deliver

- **No AI spending.** AI factions accrue and never buy. Plan 3.
- **No league table content.** The Standings tab draws the player's six tracks; who else holds
  top rank needs the AI pass. Plan 3.
- **No MCT.** Rates and prices are still literals in two places. Plan 3.
- **No event feed message.** Nothing can yet hit the player, so nothing needs announcing. Plan 3.
- **`GGUI.pick_target` is minimal** — the four targeted services take whatever the player has
  selected. A proper target picker UI is out of scope.
