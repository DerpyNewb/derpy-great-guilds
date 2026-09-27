# Great Guilds: Bounties That Cost a Choice - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Great Guilds bounty board stop paying for the war the player is already
fighting. Military offers become a far enemy or a new war. Taking an offer stakes favour.
Every guild gains non-military jobs, building requests and (three guilds) hero bounties.

**Architecture:** The model (`zzz_derpy_guilds.lua`) keeps one list of offers per human
faction. Each offer gains five saved fields and a kind drawn from a larger
`GG.BOUNTY_KINDS`. Target picking moves behind two small layers:
- `GG.bounty_pool`: which factions may be targets;
- `GG.front_regions` / `GG.front_points`: what counts as the front.

The generator (`gen_great_guilds.py`) owns the DB mission rows and loc, mirrors the kind
tables, and newly writes a data file `zzz_derpy_guilds_bounty_data.lua`. That file lists
each race's technologies and each guild's buildings, which no script call can list. Hero
bounties are SCRIPTED missions, completed by the mod from the agent-action events it
already listens to.

**Tech Stack:** Lua 5.1.5 (game scripts + stub harness), Python 3 (generator, importer,
checks), RPFM MCP (packing only, final task).

**Spec:** `docs/superpowers/specs/2026-09-27-great-guilds-bounties-v2-design.md`

## Global Constraints

- The workspace is NOT a git repository. Where a step says "Checkpoint", run the suite
  command given there and record the result. There is no commit.
- Lua is 5.1.5: `"/c/Program Files (x86)/Lua/5.1/lua.exe"`. Run everything from the
  workspace root `g:/Modding for resources`.
- **Line endings.** Edit these with the Edit tool or bytes-level Python, NEVER `sed -i`
  (it rewrites CRLF as LF):
  - `zzz_derpy_guilds.lua`: LF
  - `zzz_derpy_guilds_ui.lua`: CRLF
  - `import_great_guilds.py`: CRLF
  - `script/mct/settings/derpy_great_guilds.lua`: CRLF
  - `_guilds_harness.lua`: LF
  - `gen_great_guilds.py`: LF
- **Game compiler trap.** In a function with over 255 constants, a number literal on the
  LEFT of an arithmetic operator is miscompiled. Write `turn * 10 + 300`, never
  `300 + 10 * turn`. `py tools/check_lua_literal_left.py` must stay clean.
- **Saved data is append-only.** New offer fields go at the END of the packed string. A
  new setting goes at the END of `GG.TUNE_ORDER`. Anything else shifts every later value
  in an old save.
- **Engine calls that can re-enter script:**
  - `cm:trigger_custom_mission_from_string`
  - `cm:cancel_custom_mission`
  - `cm:complete_scripted_mission_objective`

  Any of these can raise a mission event whose handler RELOADS `GG.bounties[faction]`.
  Mark and save the offer BEFORE the call, and never save a list you held across the call.
- **Player text:** plain words (Reputation, favour, gold). No "cap", "rep", "accrue",
  "AI", "HUD". No emojis anywhere. Never the word "rung".
- **All keys lowercase.**
- **Never** publish to GitHub or Steam in this plan. **Never** run `update_anim_ids`.
- **Deploy** (Task 12) only with the game closed: back up `data/`, copy, MD5-compare.
- A kind key is unique in the whole Lua file: `region_take`, `region_sack`, `lord_kill`,
  `job_coffers`, `job_champion`, `job_research`, `job_captives`, `job_build`,
  `hero_sabotage`, `hero_harry`, `hero_strike`. The importer finds kinds by regex on
  `<kind> = {`.

## Review Focus

1. **An old save with a taken bounty from the previous build loads.** Expected: it reads
   as a far-enemy offer with stake 0, pays normally on success, refunds 0 favour and does
   not crash. Test in Task 1.
2. **A mission event fires INSIDE a completion call and reloads the board** (the
   re-entrancy the Global Constraints describe). Expected: no offer comes back after it
   was paid, and no offer pays twice. Tests in Task 8.
3. **Turn 1: at war with nobody, met nobody, owns one settlement.** Expected: the board
   posts only kinds with a target (jobs, buildings) and never errors. Test in Task 4.
4. **A race whose tech list is exhausted, or whose guild has no buildings.** Expected:
   that kind is skipped and the guild posts another kind; nothing errors. Test in Task 7.
5. **In multiplayer, the stake is spent and the standings saved on every machine.**
   Expected: after `GG.MP_OPS.bounty`, the saved standings value shows the lower favour.
   Test in Task 5.

---

## File map

| File | Responsibility | Tasks |
|---|---|---|
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` | model: offers, targets, pricing, stake, hero progress, listeners | 1-5, 7, 8 |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua` | GENERATED: techs per race, buildings per race and guild, building loc keys | 6 |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` | the bounty card: labels, war line, stake plate, disabled Take, progress | 10 |
| `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` | the `rate_bounty_stake` slider | 5 |
| `tools/_guilds_bounty_harness.lua` | NEW: every v2 rule, own stub world | 1-5, 7, 8 |
| `tools/_guilds_harness.lua` | existing harness: stubs widened, old board block kept meaningful | 2, 4, 5 |
| `tools/gen_great_guilds.py` | kind mirror, mission rows, loc, help text, data file, checks | 6, 9, 10 |
| `tools/import_great_guilds.py` | ship the data file; mirror checks for the new tables | 6, 9 |
| `tools/mutate_guilds.py` | NEW: mutation runner for the bounty rules | 11 |
| `tools/preview_guilds_panel.py` | a bounty-tab render | 10 |
| docs: handoff, CHANGELOG, SESSION_INDEX | | 12 |

**The suite** (the Checkpoint command every task ends with):

```bash
cd "g:/Modding for resources"
L="/c/Program Files (x86)/Lua/5.1/lua.exe"
"$L" tools/_guilds_harness.lua && "$L" tools/_guilds_bounty_harness.lua \
 && "/c/Program Files (x86)/Lua/5.1/luac.exe" -p "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua" \
 && py tools/check_lua_api.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua" \
 && py tools/check_lua_literal_left.py && py tools/check_lua_undeclared.py \
 && py tools/gen_great_guilds.py --check && py tools/import_great_guilds.py --check \
 && echo SUITE-GREEN
```

Until Task 1 creates the new harness, run the suite without the
`_guilds_bounty_harness.lua` term.

---

### Task 1: Offer record v2 and the new harness

**Files:**
- Create: `tools/_guilds_bounty_harness.lua`
- Modify: `zzz_derpy_guilds.lua`: `GG.save_bounties`, `GG.load_bounties` (around line 2198-2234)

**Interfaces:**
- Produces:
  - The offer fields `war` (0/1), `stake` (int), `amount` (int), `done` (int) and `void`
    (bool), saved in that order after `diff`.
  - The harness stub helpers `W.faction(key, t)`, `W.region(key, t)`, `W.char(cqi, t)`,
    `W.reset()` and `ok(name)`, used by every later task.

- [ ] **Step 1: Create the harness with its stub world and the first failing test**

`tools/_guilds_bounty_harness.lua`:

```lua
-- The bounty board, version 2 (docs/superpowers/specs/2026-09-27-great-guilds-bounties-v2-design.md).
-- Run from the workspace root:
--   "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua
--
-- ITS OWN FILE AND ITS OWN WORLD. _guilds_harness.lua is within a handful of Lua 5.1's
-- 200-locals ceiling, and its stubs model a world where every faction is an enemy with no
-- position. The rules here are about who is at peace, who is an ally, and how far away a
-- thing is, so the world is built to answer exactly those questions.
--
-- NEW TESTS GO IN A `do ... end` BLOCK, one rule per block.

local saved = {}
HANDLERS = {}
CALLS = {}          -- [cm member] = { {args...}, ... }
local function rec(name, ...)
    CALLS[name] = CALLS[name] or {}
    table.insert(CALLS[name], {...})
end

W = {}
local F, R, C = {}, {}, {}    -- factions, regions, characters by key / cqi string

local function LIST(items)
    return {num_items = function() return #items end,
            item_at = function(_, i) return items[i + 1] end,
            is_empty = function() return #items == 0 end}
end
local function NULL() return {is_null_interface = function() return true end} end

-- A FACTION. t: at_war = {key=true}, met = {keys}, allies/defensive/pact/vassal_of/
-- client = {key=true}, human, dead, bundles = {key=true}, regions = {keys},
-- lords = {cqis}, heroes = {cqis}, treasury, income, techs = {key=true}, culture.
function W.faction(key, t)
    t = t or {}
    t.at_war = t.at_war or {}
    F[key] = t
    return t
end

local function fi(key)
    local t = F[key]
    if not t then return nil end
    local self
    self = {
        is_null_interface = function() return false end,
        name = function() return key end,
        is_dead = function() return t.dead == true end,
        is_human = function() return t.human == true end,
        culture = function() return t.culture or "wh3_dlc23_chd_chaos_dwarfs" end,
        at_war_with = function(_, o) return t.at_war[o:name()] == true end,
        factions_at_war_with = function()
            local out = {}
            for k, v in pairs(t.at_war) do if v and F[k] then out[#out + 1] = fi(k) end end
            table.sort(out, function(a, b) return a:name() < b:name() end)
            return LIST(out)
        end,
        factions_met = function()
            local out = {}
            for _, k in ipairs(t.met or {}) do out[#out + 1] = fi(k) end
            return LIST(out)
        end,
        military_allies_with = function(_, o) return (t.allies or {})[o:name()] == true end,
        defensive_allies_with = function(_, o) return (t.defensive or {})[o:name()] == true end,
        non_aggression_pact_with = function(_, o) return (t.pact or {})[o:name()] == true end,
        is_vassal_of = function(_, o) return (t.vassal_of or {})[o:name()] == true end,
        is_ally_vassal_or_client_state_of = function(_, o)
            return (t.client or {})[o:name()] == true
        end,
        has_effect_bundle = function(_, b) return (t.bundles or {})[b] == true end,
        treasury = function() return t.treasury or 0 end,
        net_income = function() return t.income or 0 end,
        has_technology = function(_, k) return (t.techs or {})[k] == true end,
        region_list = function()
            local out = {}
            for _, k in ipairs(t.regions or {}) do out[#out + 1] = W.ri(k) end
            return LIST(out)
        end,
        military_force_list = function()
            local out = {}
            for _, cqi in ipairs(t.lords or {}) do
                local c = C[tostring(cqi)]
                if c and c.army ~= false then
                    out[#out + 1] = {
                        has_general = function() return true end,
                        is_armed_citizenry = function() return false end,
                        general_character = function() return W.ci(cqi) end,
                        unit_list = function() return LIST({}) end,
                    }
                end
            end
            return LIST(out)
        end,
        character_list = function()
            local out = {}
            for _, cqi in ipairs(t.lords or {}) do out[#out + 1] = W.ci(cqi) end
            for _, cqi in ipairs(t.heroes or {}) do out[#out + 1] = W.ci(cqi) end
            return LIST(out)
        end,
    }
    return self
end
W.fi = fi

-- A REGION. t: owner, x, y, adj = {keys}, buildings = {level=true}, worth = {n, cap, army}
function W.region(key, t)
    R[key] = t
    return t
end

function W.ri(key)
    local t = R[key]
    if not t then return NULL() end
    local w = t.worth or {}
    return {
        is_null_interface = function() return false end,
        name = function() return key end,
        owning_faction = function() return fi(t.owner) or NULL() end,
        adjacent_region_list = function()
            local out = {}
            for _, k in ipairs(t.adj or {}) do out[#out + 1] = W.ri(k) end
            return LIST(out)
        end,
        settlement = function()
            return {logical_position_x = function() return t.x or 0 end,
                    logical_position_y = function() return t.y or 0 end,
                    display_position_x = function() return t.x or 0 end,
                    display_position_y = function() return t.y or 0 end}
        end,
        building_exists = function(_, lvl) return (t.buildings or {})[lvl] == true end,
        num_buildings = function() return w[1] or 0 end,
        is_province_capital = function() return w[2] == true end,
        garrison_residence = function()
            return {is_null_interface = function() return false end,
                    has_army = function() return w[3] == true end,
                    region = function() return W.ri(key) end}
        end,
    }
end

-- A CHARACTER. t: faction, x, y, rank, general (bool), army (false = none), leader, units
function W.char(cqi, t)
    C[tostring(cqi)] = t
    return t
end

function W.ci(cqi)
    local t = C[tostring(cqi)]
    if not t then return NULL() end
    local fm = {is_null_interface = function() return false end,
                command_queue_index = function() return cqi end,
                character = function() return W.ci(cqi) end}
    return {
        is_null_interface = function() return false end,
        command_queue_index = function() return cqi end,
        family_member = function() return fm end,
        faction = function() return fi(t.faction) end,
        character_type = function(_, k) return (k == "general") == (t.general == true) end,
        has_region = function() return true end,
        has_military_force = function() return t.general == true and t.army ~= false end,
        logical_position_x = function() return t.x or 0 end,
        logical_position_y = function() return t.y or 0 end,
        display_position_x = function() return t.x or 0 end,
        display_position_y = function() return t.y or 0 end,
        rank = function() return t.rank or 1 end,
        is_faction_leader = function() return t.leader == true end,
        military_force = function()
            if t.army == false or not t.general then return NULL() end
            local n = t.units or 0
            return {is_null_interface = function() return false end,
                    unit_list = function() return {num_items = function() return n end} end}
        end,
    }
end

TURN = 1
RANDOM = function(n) return 1 end   -- tests replace this to steer a roll

cm = {
    set_saved_value = function(_, k, v) saved[k] = v end,
    get_saved_value = function(_, k) return saved[k] end,
    add_first_tick_callback = function() end,
    apply_effect_bundle = function() end,
    remove_effect_bundle = function() end,
    model = function() return {turn_number = function() return TURN end} end,
    random_number = function(_, n) return RANDOM(n) end,
    get_faction = function(_, k) return fi(k) or false end,
    get_region = function(_, k) return W.ri(k) end,
    get_family_member_by_cqi = function(_, cqi)
        if not C[tostring(cqi)] then return NULL() end
        return W.ci(cqi):family_member()
    end,
    get_human_factions = function() return {"me"} end,
    trigger_custom_mission_from_string = function(_, f, s) rec("trigger", f, s) end,
    cancel_custom_mission = function(_, f, k) rec("cancel", f, k) end,
    complete_scripted_mission_objective = function(_, f, k, sk, ok)
        rec("complete", f, k, sk, ok)
    end,
    set_scripted_mission_position = function(_, k, sk, x, y) rec("position", k, sk, x, y) end,
    treasury_mod = function() end,
}
core = {add_listener = function(_, name, _e, _c, fn) HANDLERS[name] = fn end}
out = function() end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua")
if io.open("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua") then
    dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua")
end

-- A fresh world: the player "me" (Chaos Dwarf), a board wiped, settings back to default
-- with the bounty rate at 80 and the stake at its default.
function W.reset()
    F, R, C = {}, {}, {}
    CALLS = {}
    TURN = 1
    RANDOM = function(n) return 1 end
    GG.bounties = {}
    GG.state = {}
    GG.turn_gain = {}
    GG.dead = {}
    GG.CULTURE_OF = {}
    GG.TUNE = {}
    for k, v in pairs(GG.TUNE_DEFAULTS) do GG.TUNE[k] = v end
    GG.TUNE.rate_bounty = 80
    for k in pairs(saved) do saved[k] = nil end
    W.faction("me", {human = true, regions = {}, lords = {}, heroes = {}})
end

function ok(name) print("ok   " .. name) end

-- ------------------------------------------------------------ Task 1: the record --
do
    W.reset()
    GG.bounties.me = {{guild = "brass", kind = "region_take", target = "r1", owner = "foe",
                       gold = 3000, rep = 80, posted = 4, taken = true, diff = 12,
                       war = 1, stake = 20, amount = 7, done = 1, void = true}}
    GG.save_bounties("me")
    GG.bounties.me = nil
    GG.load_bounties("me")
    local o = GG.bounties.me[1]
    assert(o.war == 1, "war did not survive a save, got " .. tostring(o.war))
    assert(o.stake == 20, "stake did not survive a save, got " .. tostring(o.stake))
    assert(o.amount == 7, "amount did not survive a save, got " .. tostring(o.amount))
    assert(o.done == 1, "done did not survive a save, got " .. tostring(o.done))
    assert(o.void == true, "void did not survive a save")
    ok("the five new offer fields survive a save")
end

do
    -- REVIEW FOCUS 1: a save written by the previous build has nine fields.
    W.reset()
    cm:set_saved_value("derpy_gg_bounties_me", "brass,region_take,r1,foe,3000,80,4,1,12")
    GG.load_bounties("me")
    local o = GG.bounties.me[1]
    assert(o and o.taken, "an old-format taken offer must load")
    assert(o.war == 0 and o.stake == 0 and o.amount == 0 and o.done == 0
           and o.void == false, "an old-format offer must load its new fields as zero")
    ok("an old save's offer loads as a far enemy with no stake")
end

print("bounty harness ok")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua`
Expected: FAIL: `war did not survive a save, got nil`.

- [ ] **Step 3: Extend the packed record**

In `GG.save_bounties`, replace the `parts[#parts + 1] = table.concat({...}, ",")` line with:

```lua
        parts[#parts + 1] = table.concat({o.guild, o.kind, o.target, o.owner or "",
                                          o.gold, o.rep, o.posted,
                                          o.taken and 1 or 0, o.diff or 0,
                                          -- v2, APPENDED (2026-09-27): a save from
                                          -- before reads these five as zero.
                                          o.war or 0, o.stake or 0, o.amount or 0,
                                          o.done or 0, o.void and 1 or 0}, ",")
```

In `GG.load_bounties`, replace the `list[#list + 1] = {...}` constructor with:

```lua
            list[#list + 1] = {guild = f[1], kind = f[2], target = f[3],
                               owner = f[4] or "", gold = tonumber(f[5]) or 0,
                               rep = tonumber(f[6]) or 0,
                               posted = tonumber(f[7]) or 0,
                               taken = f[8] == "1",
                               diff = tonumber(f[9]) or 0,
                               war = tonumber(f[10]) or 0,
                               stake = tonumber(f[11]) or 0,
                               amount = tonumber(f[12]) or 0,
                               done = tonumber(f[13]) or 0,
                               void = f[14] == "1"}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua`
Expected: two `ok` lines, then `bounty harness ok`.

- [ ] **Step 5: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`.

---

### Task 2: Who may be a target (spec §3.1)

**Files:**
- Modify: `zzz_derpy_guilds.lua`: add the functions just above `GG.bounty_target`
- Modify: `tools/_guilds_harness.lua`: widen two stubs so the old board still finds its enemies
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Produces:
  - `GG.bounty_rival_ok(pf, e) -> bool`, where `pf` and `e` are faction interfaces.
  - `GG.bounty_pool(faction_key, war) -> {faction interface...}`. With `war == false` it
    returns enemies you are at war with; with `war == true`, factions you have met and are
    at peace with.
  - `GG.BOUNTY_BLOCK_BUNDLES`.

- [ ] **Step 1: Write the failing test** (append before `print("bounty harness ok")`)

```lua
-- ------------------------------------------------------ Task 2: who is a target --
do
    W.reset()
    local me = F.me
    for _, k in ipairs({"foe", "ally", "defender", "pact", "master", "client", "human",
                        "dead", "realm", "friend"}) do
        W.faction(k, {})
    end
    me.at_war = {foe = true, ally = true, human = true, dead = true, realm = true}
    me.met = {"foe", "defender", "pact", "master", "client", "friend", "human"}
    me.allies = {ally = true}
    me.defensive = {defender = true}
    me.pact = {pact = true}
    me.vassal_of = {master = true}
    F.client.client = {me = true}
    F.human.human = true
    F.dead.dead = true
    F.realm.bundles = {wh3_main_bundle_realm_factions = true}
    for _, k in ipairs(me.met) do if not me.at_war[k] then F[k].at_war = {} end end

    local function names(list)
        local out = {}
        for i = 1, #list do out[#out + 1] = list[i]:name() end
        table.sort(out)
        return table.concat(out, ",")
    end
    assert(names(GG.bounty_pool("me", false)) == "foe",
           "the at-war pool must be only foe, got " .. names(GG.bounty_pool("me", false)))
    assert(names(GG.bounty_pool("me", true)) == "friend",
           "the peace pool must be only friend, got " .. names(GG.bounty_pool("me", true)))
    ok("allies, defensive allies, pacts, masters, clients, humans, the dead and realm "
       .. "factions are never targets")
end
```

- [ ] **Step 2: Run it.** Expected: FAIL: `attempt to call field 'bounty_pool' (a nil value)`.

- [ ] **Step 3: Implement** (insert above `function GG.bounty_target`)

```lua
-- WHO A GUILD MAY SEND YOU AFTER (spec 3.1). Never a friend of yours in any treaty
-- sense, never a human, never the dead, and never one of the realm or rift factions CA's
-- own contract script filters out. A question the model cannot answer is a no.
GG.BOUNTY_BLOCK_BUNDLES = {"wh3_main_bundle_realm_factions",
                           "wh3_main_bundle_rift_factions"}

function GG.bounty_rival_ok(pf, e)
    local ok, yes = pcall(function()
        if e:is_dead() or e:is_human() or e:name() == pf:name() then return false end
        if pf:military_allies_with(e) or pf:defensive_allies_with(e) then return false end
        if pf:non_aggression_pact_with(e) then return false end
        if pf:is_vassal_of(e) or e:is_vassal_of(pf) then return false end
        if pf:is_ally_vassal_or_client_state_of(e)
           or e:is_ally_vassal_or_client_state_of(pf) then return false end
        for i = 1, #GG.BOUNTY_BLOCK_BUNDLES do
            if e:has_effect_bundle(GG.BOUNTY_BLOCK_BUNDLES[i]) then return false end
        end
        return true
    end)
    return ok and yes == true
end

-- war = false: the enemies you already fight (a FAR ENEMY offer).
-- war = true: factions you have met and are at peace with (a NEW WAR offer).
function GG.bounty_pool(faction, war)
    local out = {}
    pcall(function()
        local pf = cm:get_faction(faction)
        if not pf or pf:is_null_interface() then return end
        local list = war and pf:factions_met() or pf:factions_at_war_with()
        for i = 0, list:num_items() - 1 do
            local e = list:item_at(i)
            if (not war or not pf:at_war_with(e)) and GG.bounty_rival_ok(pf, e) then
                out[#out + 1] = e
            end
        end
    end)
    return out
end
```

- [ ] **Step 4: Run the new harness.** Expected: the Task 2 `ok` line.

- [ ] **Step 5: Widen the old harness's stubs** (`tools/_guilds_harness.lua`)

`GG.bounty_target` switches to `GG.bounty_pool` in Task 4, and the old harness's `ENEMY`
has none of these methods, so every old board test would then find nobody. Do this now,
so the old harness proves Task 4 changes nothing it did not mean to. In `ENEMY` (line ~67),
add these fields to the returned table:

```lua
            is_human = function() return false end,
            has_effect_bundle = function() return false end,
            is_vassal_of = function() return false end,
            is_ally_vassal_or_client_state_of = function() return false end,
            character_list = function() return LIST({}) end,
```

In the Chaos Dwarf `cm.get_faction` stub (line ~120), add:

```lua
            is_human = function() return k == THE_PLAYER end,
            has_effect_bundle = function() return false end,
            military_allies_with = function() return false end,
            defensive_allies_with = function() return false end,
            non_aggression_pact_with = function() return false end,
            is_vassal_of = function() return false end,
            is_ally_vassal_or_client_state_of = function() return false end,
            factions_met = function() return LIST({}) end,
            region_list = function() return LIST({}) end,
            military_force_list = function() return LIST({}) end,
            character_list = function() return LIST({}) end,
```

- [ ] **Step 6: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`.

---

### Task 3: The front line (spec §3.2)

**Files:**
- Modify: `zzz_derpy_guilds.lua`: add below the Task 2 functions
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Produces:
  - `GG.BOUNTY_FRONT_DIST2 = 50000`.
  - `GG.front_regions(faction) -> {[region_key]=true}`: owned plus adjacent regions.
  - `GG.front_points(faction, with_armies) -> {{x,y}...}`.
  - `GG.nearest_d2(pts, x, y) -> number|nil`.
  - `GG.region_on_front(faction, key) -> bool`.
  - `GG.char_on_front(faction, c) -> bool`, where `c` is a character interface.

- [ ] **Step 1: Write the failing test**

```lua
-- ------------------------------------------------------- Task 3: the front line --
do
    W.reset()
    W.faction("foe", {})
    F.me.regions = {"home"}
    F.me.lords = {10}
    W.char(10, {faction = "me", general = true, x = 1000, y = 1000})
    W.region("home", {owner = "me", x = 0, y = 0, adj = {"border"}})
    W.region("border", {owner = "foe", x = 50, y = 0})
    W.region("far", {owner = "foe", x = 5000, y = 5000})
    assert(GG.region_on_front("me", "home"), "an owned region is on the front")
    assert(GG.region_on_front("me", "border"), "an adjacent region is on the front")
    assert(not GG.region_on_front("me", "far"), "a distant region is not on the front")

    W.char(20, {faction = "foe", general = true, x = 1100, y = 1000})  -- 100 from my army
    W.char(21, {faction = "foe", general = true, x = 150, y = 0})      -- 150 from home
    W.char(22, {faction = "foe", general = true, x = 3000, y = 3000})
    assert(GG.char_on_front("me", W.ci(20)), "a lord beside my army is on the front")
    assert(GG.char_on_front("me", W.ci(21)), "a lord beside my settlement is on the front")
    assert(not GG.char_on_front("me", W.ci(22)), "a distant lord is not on the front")
    ok("the front is owned and adjacent regions, and anything near a settlement or army")
end
```

The squared distances are 10,000 and 22,500, both under 50,000, and 3000² + 3000² for the
distant lord.

- [ ] **Step 2: Run it.** Expected: FAIL: `attempt to call field 'region_on_front'`.

- [ ] **Step 3: Implement**

```lua
-- THE FRONT LINE IS NEVER A BOUNTY (spec 3.2). Work the war finishes anyway is the
-- exploit this whole pass removes. A region is on the front when you own it or it
-- touches one you own; a character when it stands within GG.BOUNTY_FRONT_DIST2 (squared
-- logical distance) of any settlement or army of yours. 50000 is the figure CA's own
-- contract script uses for "near" (max_distance_between_player_settlement_and_issuer_capital).
--
-- A MODEL THAT CANNOT ANSWER MEANS NOT-ON-THE-FRONT. The offer is then posted, which is
-- the old behaviour, rather than the board going empty on a question mark.
GG.BOUNTY_FRONT_DIST2 = 50000

function GG.front_regions(faction)
    local set = {}
    pcall(function()
        local rl = cm:get_faction(faction):region_list()
        for i = 0, rl:num_items() - 1 do
            local r = rl:item_at(i)
            set[r:name()] = true
            local adj = r:adjacent_region_list()
            for j = 0, adj:num_items() - 1 do set[adj:item_at(j):name()] = true end
        end
    end)
    return set
end

function GG.front_points(faction, with_armies)
    local pts = {}
    pcall(function()
        local f = cm:get_faction(faction)
        local rl = f:region_list()
        for i = 0, rl:num_items() - 1 do
            local s = rl:item_at(i):settlement()
            pts[#pts + 1] = {s:logical_position_x(), s:logical_position_y()}
        end
        if not with_armies then return end
        local mfl = f:military_force_list()
        for i = 0, mfl:num_items() - 1 do
            local mf = mfl:item_at(i)
            if mf:has_general() and not mf:is_armed_citizenry() then
                local g = mf:general_character()
                pts[#pts + 1] = {g:logical_position_x(), g:logical_position_y()}
            end
        end
    end)
    return pts
end

function GG.nearest_d2(pts, x, y)
    local best = nil
    for i = 1, #pts do
        local dx, dy = pts[i][1] - x, pts[i][2] - y
        local d = dx * dx + dy * dy
        if not best or d < best then best = d end
    end
    return best
end

function GG.region_on_front(faction, key)
    return GG.front_regions(faction)[key] == true
end

function GG.char_on_front(faction, c)
    local ok, near = pcall(function()
        local d = GG.nearest_d2(GG.front_points(faction, true),
                                c:logical_position_x(), c:logical_position_y())
        return d ~= nil and d <= GG.BOUNTY_FRONT_DIST2
    end)
    return ok and near == true
end
```

- [ ] **Step 4: Run.** Expected: the Task 3 `ok` line.
- [ ] **Step 5: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`.

---

### Task 4: Far enemy or new war, pricing and validity (spec §3.3-3.6)

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - kind table `GG.BOUNTY_KINDS` (line ~666), adding `military = true` and
    `family = "bounty"` to the three rows;
  - `GG.bounty_target`, `GG.bounty_still_valid`, `GG.purge_bounties`,
    `GG.bounty_difficulty`, `GG.bounty_price`, `GG.make_bounty`;
  - new `GG.guild_kinds`, `GG.make_offer`, `GG.target_pos`,
    `GG.BOUNTY_WAR_GOLD`/`_REP`.
- Modify: `tools/_guilds_harness.lua`: the "AT PEACE, NOTHING IS POSTED" block (line ~1677)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: `GG.bounty_pool`, `GG.region_on_front`, `GG.char_on_front`,
  `GG.front_points`, `GG.nearest_d2`.
- Produces:
  - `GG.bounty_target(faction, kind, used, war) -> target, owner, amount`.
    `amount` is nil for the military kinds.
  - `GG.make_offer(faction, guild, kind, turn, used) -> offer|nil`.
  - `GG.guild_kinds(guild) -> {kind...}`: military first, then
    `GG.BOUNTY_EXTRA[guild]`, which is `{}` until Task 7.
  - `GG.bounty_difficulty(kind, target, o, faction)`: `o` and `faction` optional.
  - `GG.bounty_price(kind, diff, war) -> gold, rep`.
  - `GG.target_pos(o) -> x, y | nil`, in logical coordinates.
  - `GG.BOUNTY_EXTRA = {}`, which Task 7 fills.

- [ ] **Step 1: Write the failing tests**

```lua
-- ------------------------------------------------- Task 4: far enemy or new war --
local function world4()
    W.reset()
    W.faction("foe", {regions = {"foe_near", "foe_far"}, lords = {30, 31}})
    W.faction("friend", {regions = {"friend_town"}, lords = {40}})
    F.me.at_war = {foe = true}
    F.foe.at_war = {me = true}
    F.me.met = {"foe", "friend"}
    F.me.regions = {"home"}
    W.region("home", {owner = "me", x = 0, y = 0, adj = {"foe_near"}})
    W.region("foe_near", {owner = "foe", x = 60, y = 0})
    W.region("foe_far", {owner = "foe", x = 4000, y = 0})
    W.region("friend_town", {owner = "friend", x = 0, y = 4000})
    W.char(30, {faction = "foe", general = true, x = 100, y = 0, units = 10})
    W.char(31, {faction = "foe", general = true, x = 4000, y = 100, units = 10})
    W.char(40, {faction = "friend", general = true, x = 100, y = 4000, units = 10})
end

do
    world4()
    local t = GG.bounty_target("me", "region_take", {}, false)
    assert(t == "foe_far", "a far-enemy capture must skip the front, got " .. tostring(t))
    local l = GG.bounty_target("me", "lord_kill", {}, false)
    assert(l == "31", "a far-enemy lord must skip the front, got " .. tostring(l))
    local p = GG.bounty_target("me", "region_take", {}, true)
    assert(p == "friend_town", "a new-war capture names a faction at peace, got "
           .. tostring(p))
    ok("far enemy skips the front; new war names a faction at peace")
end

do
    world4()
    -- The mix: a roll of 3 asks for a new war, anything else a far enemy.
    RANDOM = function(n) if n == 3 then return 3 end return 1 end
    local o = GG.make_offer("me", "brass", "region_take", 1, {})
    assert(o and o.war == 1 and o.target == "friend_town",
           "a 3 must post a new war, got " .. tostring(o and o.target))
    RANDOM = function(n) return 1 end
    local far = GG.make_offer("me", "brass", "region_take", 1, {})
    assert(far.war == 0 and far.target == "foe_far", "a 1 must post a far enemy")
    -- New war doubles the gold and pays half again the reputation.
    local g0, r0 = GG.bounty_price("region_take", o.diff, 0)
    assert(o.gold == g0 * 2 and o.rep == math.floor(r0 * 3 / 2),
           "new war must pay x2 gold and x1.5 reputation, got " .. o.gold .. "/" .. o.rep)
    -- Fallback: nobody at peace, so a 3 still posts a far enemy.
    F.me.met = {"foe"}
    RANDOM = function(n) if n == 3 then return 3 end return 1 end
    local fb = GG.make_offer("me", "brass", "region_take", 1, {})
    assert(fb and fb.war == 0, "no peace pool must fall back to a far enemy")
    ok("the war roll, its price and its fallback")
end

do
    -- REVIEW FOCUS 3: turn 1, nobody at war, nobody met.
    world4()
    F.me.at_war = {}
    F.me.met = {}
    GG.post_bounties("me")
    assert(#(GG.bounties.me or {}) == 0, "a player who has met nobody has no military work")
    ok("turn one with nobody met posts no military offer and does not error")
end

do
    -- Validity: a new-war offer survives the declaration; a far offer does not survive
    -- peace; an untaken far offer on the front is withdrawn, a taken one is kept.
    world4()
    local nw = {guild = "brass", kind = "region_take", target = "friend_town",
                owner = "friend", war = 1, posted = 1}
    F.me.at_war.friend = true
    assert(GG.bounty_still_valid("me", nw), "a new-war offer must survive the war")
    F.me.pact = {friend = true}
    assert(not GG.bounty_still_valid("me", nw), "a pact must withdraw even a new-war offer")
    F.me.pact = {}
    local far = {guild = "brass", kind = "region_take", target = "foe_far",
                 owner = "foe", war = 0, posted = 1}
    F.me.at_war.foe = nil
    assert(not GG.bounty_still_valid("me", far), "peace must withdraw a far offer")
    F.me.at_war.foe = true
    R.home.adj = {"foe_near", "foe_far"}
    assert(not GG.bounty_still_valid("me", far), "an untaken offer on the front is withdrawn")
    far.taken = true
    assert(GG.bounty_still_valid("me", far), "a taken offer on the front is kept")
    ok("validity for new-war and far offers")
end

do
    -- Distance adds to the price: the same town, further away, pays more.
    world4()
    local near_d = GG.bounty_difficulty("region_take", "foe_near", nil, "me")
    local far_d = GG.bounty_difficulty("region_take", "foe_far", nil, "me")
    assert(far_d > near_d, "distance must raise the price: near " .. near_d .. " far " .. far_d)
    assert(far_d - near_d <= GG.BOUNTY_DIFF.distance_max,
           "the distance term is capped at " .. GG.BOUNTY_DIFF.distance_max)
    ok("distance raises the price, capped")
end
```

- [ ] **Step 2: Run.** Expected: FAIL at the first Task 4 assertion. The old `bounty_target`
  ignores the front and returns `foe_near`.

- [ ] **Step 3: Implement**

(a) In `GG.BOUNTY_KINDS`, add `military = true, family = "bounty",` to each of
`region_take`, `region_sack` and `lord_kill`. Keep `otype`, `obj`, `gold` and `target` as
they are. Below the table add:

```lua
-- THE OTHER KINDS EACH GUILD MAY POST, after its military one (spec 5). Filled by
-- Task 7; mirrored by BOUNTY_EXTRA in tools/gen_great_guilds.py.
GG.BOUNTY_EXTRA = GG.BOUNTY_EXTRA or {}

-- A NEW-WAR offer's premium, as percentages (spec 3.4).
GG.BOUNTY_WAR_GOLD = 200
GG.BOUNTY_WAR_REP = 150
```

Add to `GG.BOUNTY_DIFF`: `per_distance = 10, distance_max = 60,`.

(b) Replace `GG.bounty_target` with:

```lua
function GG.bounty_target(faction, kind, used, war)
    local k = GG.BOUNTY_KINDS[kind]
    if not k then return nil end
    used = used or {}
    if k.pick then return GG.BOUNTY_PICK[k.pick](faction, kind, used) end
    local why = "walk never started"
    local ok, target, owner = pcall(function()
        local pool = GG.bounty_pool(faction, war == true)
        if #pool == 0 then
            why = war and "nobody met and at peace" or "at war with nobody eligible"
            return nil
        end
        -- The front is never military work; hero work may be done there (spec 5.5).
        local front = (not k.front_ok) and GG.front_regions(faction) or {}
        local found = {}
        for i = 1, #pool do
            local e = pool[i]
            local ename = e:name()
            if k.target == "region" then
                local rl = e:region_list()
                for j = 0, rl:num_items() - 1 do
                    local key = rl:item_at(j):name()
                    if key and not used[key] and not front[key] then
                        found[#found + 1] = {key, ename}
                    end
                end
            else
                -- "lord": generals with an army. "character": those, plus heroes.
                local seen = {}
                local mfl = e:military_force_list()
                for j = 0, mfl:num_items() - 1 do
                    local mf = mfl:item_at(j)
                    if mf:has_general() and not mf:is_armed_citizenry() then
                        local gen = mf:general_character()
                        local cqi = tostring(gen:family_member():command_queue_index())
                        seen[cqi] = true
                        if gen:has_region() and not used[cqi]
                           and (k.front_ok or not GG.char_on_front(faction, gen)) then
                            found[#found + 1] = {cqi, ename}
                        end
                    end
                end
                if k.target == "character" then
                    local cl = e:character_list()
                    for j = 0, cl:num_items() - 1 do
                        local c = cl:item_at(j)
                        local cqi = tostring(c:family_member():command_queue_index())
                        if not seen[cqi] and not used[cqi] and c:has_region()
                           and not c:character_type("general")
                           and not c:character_type("colonel") then
                            found[#found + 1] = {cqi, ename}
                        end
                    end
                end
            end
        end
        if #found == 0 then
            why = "no unused " .. tostring(k.target) .. " off the front"
            return nil
        end
        local pick = found[GG.roll(#found)]
        return pick[1], pick[2]
    end)
    if ok and target then return target, owner end
    if not ok then
        GG.trace("bounty target walk ERRORED for " .. tostring(kind) .. ": "
                 .. tostring(target))
    else
        GG.trace("no " .. tostring(kind) .. " target: " .. tostring(why))
    end
    return nil
end

-- WHERE A TARGET STANDS, in logical coordinates, for the distance term. nil when it
-- has no place on the map (a job, a dead lord).
function GG.target_pos(o)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    if not k then return nil end
    local ok, x, y = pcall(function()
        if k.target == "region" then
            local s = cm:get_region(o.target):settlement()
            return s:logical_position_x(), s:logical_position_y()
        elseif k.target == "lord" or k.target == "character" then
            local c = cm:get_family_member_by_cqi(tonumber(o.target) or 0):character()
            if not c or c:is_null_interface() then return nil end
            return c:logical_position_x(), c:logical_position_y()
        end
        return nil
    end)
    if ok and x then return x, y end
    return nil
end
```

(c) In `GG.bounty_difficulty`, change the signature to `(kind, target, o, faction)`. Make
the region and lord branches `return` into a local `n` instead of returning directly, and
after the branch, before the ceiling clamp, add:

```lua
    -- DISTANCE (spec 3.4): the far edge of your reach pays more. Military only; hero
    -- work is done where the heroes are, and a job has no place.
    if k.military and faction then
        local x, y = GG.target_pos({kind = kind, target = target})
        if x then
            local d2 = GG.nearest_d2(GG.front_points(faction, false), x, y)
            if d2 then
                local add = math.floor(math.sqrt(d2) / D.per_distance)
                if add > D.distance_max then add = D.distance_max end
                score = score + add
            end
        end
    end
```

Here `score` is the value the existing pcall returned. The job branch comes in Task 7.

(d) Replace `GG.bounty_price`:

```lua
function GG.bounty_price(kind, diff, war)
    local k = GG.BOUNTY_KINDS[kind]
    if not k then return 0, 0 end
    diff = diff or 0
    local gm, rm = 100, 100
    if war == 1 then gm, rm = GG.BOUNTY_WAR_GOLD, GG.BOUNTY_WAR_REP end
    return math.floor(k.gold * (100 + diff) * gm / 10000),
           math.floor(GG.bounty_pay() * (200 + diff) * rm / 20000)
end
```

(`GG.bounty_pay() * (100 + diff / 2) / 100` equals `GG.bounty_pay() * (200 + diff) / 200`,
so this is the old reputation formula times `rm / 100`.)

(e) Replace `GG.make_bounty`, and add `GG.guild_kinds` and `GG.make_offer`:

```lua
function GG.guild_kinds(guild)
    local out = {GG.BOUNTIES[guild]}
    local extra = GG.BOUNTY_EXTRA[guild] or {}
    for i = 1, #extra do out[#out + 1] = extra[i] end
    return out
end

-- ONE OFFER OF ONE KIND, or nil when that kind has nothing to name.
-- THE WAR ROLL (spec 3.3): a 3 on a d3 asks for a new war, anything else a far enemy,
-- and each falls back to the other. A 3 rather than a 1 because a campaign with no
-- random source rolls 1 (GG.roll), and that must keep meaning "the war you are in".
function GG.make_offer(faction, guild, kind, turn, used)
    local k = GG.BOUNTY_KINDS[kind]
    if not k then return nil end
    local target, owner, amount, war = nil, nil, nil, 0
    if k.military then
        local first = (GG.roll(3) == 3)
        target, owner = GG.bounty_target(faction, kind, used, first)
        war = first and 1 or 0
        if not target then
            target, owner = GG.bounty_target(faction, kind, used, not first)
            war = first and 0 or 1
        end
    else
        target, owner, amount = GG.bounty_target(faction, kind, used, false)
    end
    if not target then return nil end
    local o = {guild = guild, kind = kind, target = target, owner = owner or "",
               posted = turn, taken = false, war = war, amount = amount or 0,
               done = 0, void = false}
    o.diff = GG.bounty_difficulty(kind, target, o, faction)
    o.gold, o.rep = GG.bounty_price(kind, o.diff, war)
    o.stake = GG.bounty_stake and GG.bounty_stake(o.rep) or 0
    return o
end

-- A GUILD'S OFFER THIS TURN: one of its kinds, starting from a rolled one and trying
-- the rest in order, so a kind with nothing to name gives way to one that has.
function GG.make_bounty(faction, guild, turn, used)
    local kinds = GG.guild_kinds(guild)
    local n = #kinds
    local start = GG.roll(n)
    for step = 0, n - 1 do
        local o = GG.make_offer(faction, guild, kinds[((start + step - 1) % n) + 1],
                                turn, used)
        if o then return o end
    end
    return nil
end
```

(f) Replace the body of `GG.bounty_still_valid`'s pcall with:

```lua
        local f = cm:get_faction(faction)
        if k.target == "region" then
            local r = cm:get_region(o.target)
            if not r or r:is_null_interface() then return false end
            local owner = r:owning_faction()
            if not owner or owner:is_null_interface() then return false end
            if owner:name() == faction then return false end
            local oe = cm:get_faction(owner:name())
            if f and not f:is_null_interface() and oe and not oe:is_null_interface() then
                -- A far offer is war work; a new-war offer survives the war it asked for.
                if o.war ~= 1 and not f:at_war_with(oe) then return false end
                if not GG.bounty_rival_ok(f, oe) then return false end
            end
            if k.military and not o.taken and GG.region_on_front(faction, o.target) then
                return false
            end
            return true
        elseif k.target == "lord" or k.target == "character" then
            local fm = cm:get_family_member_by_cqi(tonumber(o.target) or 0)
            if not fm or fm:is_null_interface() then return false end
            local c = fm:character()
            if not c or c:is_null_interface() then return false end
            if k.military and not o.taken and GG.char_on_front(faction, c) then
                return false
            end
            return true
        end
        -- Jobs (Task 7) answer through their own check.
        if k.valid then return GG.BOUNTY_VALID[k.valid](faction, o) end
        return true
```

(g) In `GG.purge_bounties`, change the re-price block to:

```lua
                local d = GG.bounty_difficulty(o.kind, o.target, o, faction)
                if d ~= o.diff then
                    o.diff = d
                    o.gold, o.rep = GG.bounty_price(o.kind, d, o.war)
                    o.stake = GG.bounty_stake and GG.bounty_stake(o.rep) or 0
                end
```

(h) In `GG.make_bounty`'s caller `GG.post_bounties`, nothing changes.

- [ ] **Step 4: Update the old harness's board block.** In `tools/_guilds_harness.lua`,
  replace the comment above `WARS[BF] = {}` ("AT PEACE, NOTHING IS POSTED ...") with:

```lua
-- AT PEACE WITH NOBODY MET, NOTHING IS POSTED. Since v2 a guild may ask for a new war
-- against a faction you have met; this world has met nobody (factions_met is empty), so
-- an empty war list still leaves an empty board rather than erroring.
```

The assertion stays as it is.

- [ ] **Step 5: Run both harnesses.** Expected: the four Task 4 `ok` lines, `bounty
  harness ok` and `harness ok`. If the old harness fails, read the assertion: the only
  intended changes are the front rule and the war roll, and the old world has no front
  and a roll of 1.

- [ ] **Step 6: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`.

---

### Task 5: The favour stake (spec §4)

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - `GG.TUNE_DEFAULTS`, `GG.TUNE_ORDER` and the four `GG.PRESETS` entries (lines
    ~2744-2880);
  - new `GG.bounty_stake` and `GG.refund`;
  - `GG.take_bounty`, `GG.bounty_done`, `GG.take_bounty_slot`, `GG.bounty_lost`;
  - new `GG.offer_mission_key` and `GG.bounty_cancelled`;
  - `GG.MP_OPS.bounty`, and the `gg_bounty_MissionCancelled` handler.
- Modify: `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` (CRLF)
- Modify: `tools/_guilds_harness.lua`: the board block sets the stake to 0
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Produces:
  - `GG.bounty_stake(rep) -> int`.
  - `GG.refund(faction, guild, amount)`: raw favour, no cap, no Reputation.
  - `GG.offer_mission_key(o, faction) -> "derpy_gg_<family>_<guild><tag>"`.
  - `GG.bounty_cancelled(faction, mission_key) -> offer|nil`: refunds the stake when
    `o.void`.
  - The setting `rate_bounty_stake`, which defaults to 25.

- [ ] **Step 1: Write the failing tests**

```lua
-- ------------------------------------------------------------- Task 5: the stake --
local function board5()
    world4()
    GG.bounties.me = {{guild = "brass", kind = "region_take", target = "foe_far",
                       owner = "foe", gold = 3000, rep = 80, posted = 1, taken = false,
                       diff = 0, war = 0, stake = 20, amount = 0, done = 0, void = false}}
    GG.state.me = nil
end

do
    board5()
    assert(GG.bounty_stake(80) == 20, "the stake is a quarter of the reputation")
    GG.TUNE.rate_bounty_stake = 0
    assert(GG.bounty_stake(80) == 0, "0 switches the stake off")
    GG.TUNE.rate_bounty_stake = 25
    -- Not enough favour: nothing is issued.
    assert(GG.take_bounty("me", 1) == false, "a take with no favour must be refused")
    assert(not CALLS.trigger, "a refused take must issue nothing")
    -- Enough favour: the stake is spent.
    GG.grant("me", "brass", 50, "test")
    local _, fav0 = GG.get("me", "brass")
    assert(GG.take_bounty("me", 1) == true, "a take with favour must succeed")
    local _, fav1 = GG.get("me", "brass")
    assert(fav0 - fav1 == 20, "taking must spend the stake, spent " .. (fav0 - fav1))
    -- Success refunds the stake as favour only.
    local rep1 = select(1, GG.get("me", "brass"))
    assert(GG.bounty_done("me", GG.offer_mission_key(GG.bounties.me[1], "me")))
    local rep2, fav2 = GG.get("me", "brass")
    assert(fav2 == fav1 + 20 + 80, "success must refund 20 and pay 80 favour, got "
           .. (fav2 - fav1))
    assert(rep2 - rep1 == 80, "the refund must not add reputation, got " .. (rep2 - rep1))
    ok("the stake is refused when short, spent on take and refunded on success")
end

do
    -- Hand-back loses the stake; a voided offer refunds it; failure loses it.
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.take_bounty("me", 1)
    local _, fav = GG.get("me", "brass")
    local key = GG.offer_mission_key(GG.bounties.me[1], "me")
    GG.bounty_cancelled("me", key)
    assert(select(2, GG.get("me", "brass")) == fav, "a hand-back must not refund")
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.take_bounty("me", 1)
    GG.bounties.me[1].void = true
    fav = select(2, GG.get("me", "brass"))
    GG.bounty_cancelled("me", key)
    assert(select(2, GG.get("me", "brass")) == fav + 20, "a voided offer must refund")
    ok("hand-back loses the stake, a void refunds it")
end

do
    -- A trigger that throws puts the stake back.
    board5()
    GG.grant("me", "brass", 50, "test")
    local _, fav = GG.get("me", "brass")
    local real = cm.trigger_custom_mission_from_string
    cm.trigger_custom_mission_from_string = function() error("boom") end
    assert(GG.take_bounty("me", 1) == false, "a throwing trigger must fail the take")
    cm.trigger_custom_mission_from_string = real
    assert(select(2, GG.get("me", "brass")) == fav, "a failed trigger must refund")
    assert(GG.bounties.me[1].taken == false, "a failed trigger must leave the offer untaken")
    ok("a trigger that throws refunds the stake")
end

do
    -- REVIEW FOCUS 5: the multiplayer path saves the standings too.
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.save("me")
    local before = cm:get_saved_value("derpy_gg_me")   -- GG.save writes "derpy_gg_" .. faction
    GG.MP_OPS.bounty("me", "1")
    local after = cm:get_saved_value("derpy_gg_me")
    assert(before ~= after, "the take must save the favour it spent")
    ok("the multiplayer take saves the standings")
end
```

- [ ] **Step 2: Run.** Expected: FAIL: `attempt to call field 'bounty_stake'`.

- [ ] **Step 3: Implement**

(a) Settings:
- `GG.TUNE_DEFAULTS`: add `rate_bounty_stake = 25,` with the comment "Favour a bounty
  stakes, as a percentage of the Reputation it pays. Returned on success, lost on failure
  or hand-back. 0 switches it off."
- Append `"rate_bounty_stake",` as the LAST entry of `GG.TUNE_ORDER`.
- `GG.PRESETS` (line ~2828): add `rate_bounty_stake = 15,` to `easy`, `35,` to `hard` and
  `50,` to `ultra`. `default = {}` stays EMPTY on purpose; it reads `GG.TUNE_DEFAULTS`,
  which is 25.

(b) New functions, placed after `GG.bounty_pay`:

```lua
-- THE STAKE (spec 4): favour put up to take a bounty. A quarter of what it pays in
-- reputation by default. Spent on take, handed back on success or when the mod itself
-- voids the offer, lost on failure or hand-back.
function GG.bounty_stake(rep)
    local pct = GG.setting("rate_bounty_stake") or 0
    if pct <= 0 or not rep or rep <= 0 then return 0 end
    return math.ceil(rep * pct / 100)
end

-- FAVOUR BACK, AND NOTHING ELSE. Not GG.grant: a grant is also reputation, and also
-- charges the rival guild, for favour the player already owned. And not capped: it was
-- theirs before they staked it.
function GG.refund(faction, guild, amount)
    if not amount or amount <= 0 then return end
    GG.state[faction] = GG.state[faction] or blank()
    local g = GG.state[faction][guild]
    if g then g.fav = g.fav + amount end
end

-- EACH FAMILY OF KIND HAS ITS OWN MISSION ROW (spec 6), because the objectives panel
-- reads the title off the key. One live bounty per guild keeps them from colliding.
function GG.offer_mission_key(o, faction)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    local fam = (k and k.family) or "bounty"
    return "derpy_gg_" .. fam .. "_" .. tostring(o and o.guild) .. GG.tag(faction)
end
```

`blank` is the file-local at line ~20. These functions sit below it, so it is in scope.

(c) In `GG.take_bounty`, after `if not str then return false end`, insert:

```lua
    -- THE STAKE, spent before anything is marked or issued: a refused spend leaves the
    -- offer exactly as it was.
    local stake = o.stake or 0
    if stake > 0 and not GG.spend(faction, o.guild, stake) then return false end
```

In its `if not ok then` branch, add `GG.refund(faction, o.guild, stake)` as the first line.

(d) In `GG.bounty_done` and `GG.take_bounty_slot`, replace
`GG.bounty_mission_key(o.guild, faction) == mission_key` with
`GG.offer_mission_key(o, faction) == mission_key`. In `GG.bounty_done`, just before
`GG.grant(faction, guild, rep, "bounties")`, add `GG.refund(faction, guild, o.stake)`.
Capture `o.stake` into a local beside `guild, rep` before the `table.remove`.

(e) Add, and route `GG.bounty_lost` through it:

```lua
-- CANCELLED: handed back by the player, or voided by the mod (spec 5.5). The engine
-- raises the same event for both, so the offer's own flag tells them apart.
function GG.bounty_cancelled(faction, mission_key)
    local o = GG.take_bounty_slot(faction, mission_key)
    if o and o.void then GG.refund(faction, o.guild, o.stake) end
    return o
end

function GG.bounty_lost(faction, mission_key)
    return GG.bounty_cancelled(faction, mission_key) ~= nil
end
```

(f) `GG.MP_OPS.bounty` becomes:

```lua
GG.MP_OPS.bounty = function(faction, arg)
    local n = tonumber(arg)
    if not n then return end
    GG.load(faction)
    GG.load_bounties(faction)
    if GG.take_bounty(faction, n) then
        GG.save_bounties(faction)
        -- THE STAKE LIVES IN THE STANDINGS, so both saved values are written.
        GG.save(faction)
    end
end
```

(g) In the `gg_bounty_MissionCancelled` handler, replace
`GG.load_bounties(name) if GG.bounty_lost(name, mkey) then GG.save_bounties(name) end` with:

```lua
            GG.load(name)
            GG.load_bounties(name)
            if GG.bounty_cancelled(name, mkey) then
                GG.save_bounties(name)
                GG.save(name)
            end
```

(h) Old harness: in `tools/_guilds_harness.lua`, directly after `GG.TUNE.rate_bounty = 80`
in the board block, add:

```lua
-- v2's stake is its own block in _guilds_bounty_harness.lua. Off here, so every test
-- below still means what it was written to mean: taking costs nothing.
GG.TUNE.rate_bounty_stake = 0
```

(i) MCT (`derpy_great_guilds.lua`, CRLF). After the `rate_bounty_fail` row, add:

```lua
    {"rate_bounty_stake", "Bounty stake", 25, 0, 100,
     "Favour you put up to take a bounty, as a percentage of the reputation it pays. You "
     .. "get it back when you finish the bounty, and lose it if you fail or hand it back. "
     .. "0 switches it off."},
```

Also add `"rate_bounty_stake"` to `PRESET_OWNED`.

- [ ] **Step 4: Run both harnesses.** Expected: the four Task 5 `ok` lines, `bounty harness
  ok` and `harness ok`.
- [ ] **Step 5: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`.

---

### Task 6: The generated data file - technologies and buildings (spec §5.1, §5.4)

**Files:**
- Modify: `tools/gen_great_guilds.py`: new `bounty_techs()`, `bounty_buildings()`,
  `bounty_data_lua()`, `write_bounty_data()` and `check_bounty_data()`; wire them into
  `--write`, `check()` and `selftest()`
- Create (generated): `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua`
- Modify: `tools/import_great_guilds.py` (CRLF): add the data file to `SCRIPTS`

**Interfaces:**
- Produces, in Lua:
  - `GG.BOUNTY_TECHS[<tag>] = {{"tech_key", tier}, ...}`
  - `GG.BOUNTY_TECHS_FACTION[<faction>] = {...}`
  - `GG.BOUNTY_BUILDINGS[<tag>][<guild>] = {{"level_key", rank}, ...}`
  - `GG.BOUNTY_BUILDING_LOC[<level_key>] = "building_culture_variants_name_..."`
- Produces, in Python: `BOUNTY_DATA_LUA` (path) and `check_bounty_data() -> [problem]`.

- [ ] **Step 1: Write the failing check first.** Add to `gen_great_guilds.py`, after
  `check_built_effects`:

```python
BOUNTY_DATA_LUA = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua"
TECH_SENTINEL_TIER = 900     # chd_mil carries a tier-999 node that is not on the tree


def check_bounty_data():
    """The data file must be current, and name only things the installed game has.

    A tech or building key the game does not have is a bounty nobody can finish, and the
    game would never say so.
    """
    out = []
    try:
        want = bounty_data_lua()
    except Exception as exc:                                   # noqa: BLE001
        return ["cannot build the bounty data: %r" % (exc,)]
    have = io.open(BOUNTY_DATA_LUA, encoding="utf-8").read() if os.path.isfile(
        BOUNTY_DATA_LUA) else ""
    if have != want:
        out.append("%s is stale - run gen_great_guilds.py --write" % BOUNTY_DATA_LUA)
    techs = {r["key"] for r in live_rows("technologies")}
    levels = {r["level_name"] for r in live_rows("building_levels")}
    sys.path.insert(0, "tools")
    import read_vanilla_loc as L
    bloc = dict(L.load("building_culture_variants"))
    per_tag, per_faction = bounty_techs()
    for tag, rows in per_tag.items():
        if not rows:
            out.append("flavour %r has no technology a bounty can ask for" % tag)
        for key, _tier in rows:
            if key not in techs:
                out.append("bounty tech %s is not in the installed game" % key)
    builds, locs = bounty_buildings()
    for tag, per_guild in builds.items():
        if not per_guild.get("overseers"):
            out.append("flavour %r: the Overseers have no building to ask for, and "
                       "building is their only job" % tag)
        for g, rows in per_guild.items():
            for lvl, _rank in rows:
                if lvl not in levels:
                    out.append("bounty building %s is not in the installed game" % lvl)
                if locs.get(lvl) not in bloc:
                    out.append("bounty building %s has no name in CA's loc (%s)"
                               % (lvl, locs.get(lvl)))
    return out
```

Add `problems += check_bounty_data()` to `check()` (find where `check()` builds its list).

- [ ] **Step 2: Run** `py tools/gen_great_guilds.py --check`. Expected: FAIL with
  `NameError: name 'bounty_data_lua' is not defined`, or a PROBLEM line reporting the same.

- [ ] **Step 3: Implement the builders**

```python
def _script_locked_techs():
    """Every technology CA's own scripts lock - a bounty must never ask for one.

    No script call answers "can this faction research X", so the filter is measured:
    every cm:lock_technology call in all 7,540 shipped script files.
    """
    root = "Modding Files/reference/ca_scripts_wh3"
    pat = re.compile(r'lock_technology\(\s*[^,]+,\s*"([^"]+)"')
    out = set()
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if name.endswith(".lua"):
                text = io.open(os.path.join(dirpath, name), encoding="utf-8",
                               errors="ignore").read()
                out.update(pat.findall(text))
    return out


def bounty_techs():
    """({tag: [(tech, tier)]}, {faction: [(tech, tier)]}) - the upper half of each tree.

    One node set per culture with no faction_key; a faction with its own set (the
    Empire's Wulfhart) gets its own list. Campaign-only nodes and the sentinel tier are
    dropped, and so is anything CA's scripts lock.
    """
    locked = _script_locked_techs()
    sets = live_rows("technology_node_sets")
    nodes = live_rows("technology_nodes")

    def upper(set_key):
        rows = [n for n in nodes if n["technology_node_set"] == set_key
                and not n["campaign_key"] and n["tier"] < TECH_SENTINEL_TIER
                and n["technology_key"] not in locked]
        if not rows:
            return []
        top = max(n["tier"] for n in rows)
        cut = (top + 1) // 2
        return sorted({(n["technology_key"], n["tier"]) for n in rows if n["tier"] >= cut})

    per_tag, per_faction = {}, {}
    for tag, F in FLAVOURS.items():
        if not F.get("culture"):
            continue
        for s in sets:
            if s["culture"] != F["culture"] or s["campaign_key"] or s["subculture"]:
                continue
            if s["faction_key"]:
                per_faction[s["faction_key"]] = upper(s["key"])
            else:
                per_tag[tag] = upper(s["key"])
    return per_tag, per_faction


def bounty_buildings():
    """({tag: {guild: [(level, rank)]}}, {level: loc key}).

    A level qualifies when its chain is one covered race's own, the SHIPPED
    GG.guild_of_chain pays it to that guild (unmatched chains fall back to the Overseers,
    as GG.on_building pays them), it is the third or later NON-RUIN level of its chain,
    it shows in the UI, it needs no resource, and the chain is not a main settlement.
    """
    owner = covered_chains()
    levels = live_rows("building_levels")
    by_chain = {}
    for r in levels:
        if r["chain"] in owner and not r["level_name"].endswith("_ruin"):
            by_chain.setdefault(r["chain"], []).append(r)
    lua = _lua_guilds_of(sorted(by_chain))
    variants = live_rows("building_culture_variants")
    out, locs = {}, {}
    for chain, rows in sorted(by_chain.items()):
        if "settlement" in chain:
            continue
        tag = owner[chain]
        culture = FLAVOURS[tag]["culture"]
        g = lua[chain] or "overseers"
        for rank, r in enumerate(sorted(rows, key=lambda r: r["level"]), start=1):
            if rank < 3 or not r["visible_in_ui"] or r["resource_requirement"]:
                continue
            lvl = r["level_name"]
            vs = [v for v in variants if v["building"] == lvl and v["culture"] == culture]
            vs.sort(key=lambda v: (v["subculture"] != "", v["faction"] != ""))
            if not vs:
                continue
            v = vs[0]
            locs[lvl] = ("building_culture_variants_name_" + v["building"] + v["culture"]
                         + v["subculture"] + v["faction"])
            out.setdefault(tag, {}).setdefault(g, []).append((lvl, rank))
    return out, locs


def bounty_data_lua():
    """The generated Lua, as text. Deterministic: sorted everywhere."""
    per_tag, per_faction = bounty_techs()
    builds, locs = bounty_buildings()
    L = ["-- GENERATED by tools/gen_great_guilds.py --write. Do not edit.",
         "-- What a bounty may ask for that no script call can list: the upper half of each",
         "-- race's technology tree, and the buildings each guild is paid for.",
         "GG = GG or {}",
         "GG.BOUNTY_TECHS = {"]
    for tag in sorted(per_tag):
        L.append('    [%r] = {%s},' % (tag, ", ".join('{"%s", %d}' % t for t in per_tag[tag])))
    L.append("}")
    L.append("GG.BOUNTY_TECHS_FACTION = {")
    for f in sorted(per_faction):
        L.append('    [%r] = {%s},' % (f, ", ".join('{"%s", %d}' % t for t in per_faction[f])))
    L.append("}")
    L.append("GG.BOUNTY_BUILDINGS = {")
    for tag in sorted(builds):
        L.append("    [%r] = {" % tag)
        for g in sorted(builds[tag]):
            L.append('        %s = {%s},' % (g, ", ".join('{"%s", %d}' % t
                                                            for t in builds[tag][g])))
        L.append("    },")
    L.append("}")
    L.append("GG.BOUNTY_BUILDING_LOC = {")
    for lvl in sorted(locs):
        L.append('    ["%s"] = "%s",' % (lvl, locs[lvl]))
    L.append("}")
    return "\n".join(L).replace("'", '"') + "\n"


def write_bounty_data():
    io.open(BOUNTY_DATA_LUA, "w", encoding="utf-8", newline="\n").write(bounty_data_lua())
    return BOUNTY_DATA_LUA
```

`%r` of a Python str prints `'...'`, and the final `.replace` turns that into Lua's `"`.
Keys hold no quotes, so the replace is safe.

In `__main__`'s `--write` branch, add `print("wrote " + write_bounty_data())`. In
`import_great_guilds.py`, add
`"Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua",` to `SCRIPTS`,
as the LAST entry, so `MODEL_LUA = SCRIPTS[0]` is unchanged.

- [ ] **Step 4: Generate and check.**

Run: `py tools/gen_great_guilds.py --write && py tools/gen_great_guilds.py --check`
Expected: `wrote ...zzz_derpy_guilds_bounty_data.lua`, then exit 0. If a PROBLEM names a
flavour with no Overseers building, or a tech that is not in the game, STOP. That is a
finding about the filters, not something to tune away. Record it and read the rows it
names.

Then print the coverage for the handoff:

```bash
py -c "import sys;sys.path.insert(0,'tools');import gen_great_guilds as G;b,_=G.bounty_buildings();t,f=G.bounty_techs();print({k:len(v) for k,v in t.items()},{k:len(v) for k,v in f.items()});print({tag:{g:len(r) for g,r in d.items()} for tag,d in b.items()})"
```

- [ ] **Step 5: Confirm the file loads in the game's Lua.**

Run: `"/c/Program Files (x86)/Lua/5.1/luac.exe" -p "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua"`
Expected: exit 0.

- [ ] **Step 6: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`. The new harness
  now dofiles the data file.

---

### Task 7: The job kinds and building requests (spec §5, §5.1-5.4)

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - the five `job_*` rows in `GG.BOUNTY_KINDS`;
  - `GG.BOUNTY_EXTRA` (without the hero kinds, which come in Task 8);
  - `GG.BOUNTY_PICK` and `GG.BOUNTY_VALID`;
  - `GG.bounty_string`;
  - the job branch of `GG.bounty_difficulty`;
  - `GG.take_bounty`, which sets the coffers figure;
  - helpers `GG.highest_rank` and `GG.player_has_building`.
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: `GG.BOUNTY_TECHS`, `GG.BOUNTY_TECHS_FACTION`, `GG.BOUNTY_BUILDINGS` (Task 6),
  `GG.make_offer` (Task 4).
- Produces:
  - Kind fields `pick`, `valid`, `arg` (`"target"|"amount"|"shape"`) and `with_faction`.
  - `GG.BOUNTY_PICK[name](faction, kind, used, guild) -> target, owner, amount`.
  - `GG.BOUNTY_VALID[name](faction, o) -> bool`.

- [ ] **Step 1: Write the failing tests**

```lua
-- -------------------------------------------------------------- Task 7: the jobs --
do
    W.reset()
    F.me.income = 1200
    F.me.treasury = 3000
    F.me.regions = {"home"}
    F.me.lords = {50}
    W.char(50, {faction = "me", general = true, rank = 10})
    W.region("home", {owner = "me", buildings = {}})

    -- coffers: the ask is 5 turns of income, at least 5000, in steps of 500.
    local o = GG.make_offer("me", "brass", "job_coffers", 1, {})
    assert(o.amount == 6000, "coffers must ask 6000, got " .. tostring(o.amount))
    F.me.income = 300
    o = GG.make_offer("me", "brass", "job_coffers", 1, {})
    assert(o.amount == 5000, "coffers has a 5000 floor, got " .. tostring(o.amount))

    -- champion: highest rank + 4.
    o = GG.make_offer("me", "immortals", "job_champion", 1, {})
    assert(o.amount == 14, "champion must ask rank 14, got " .. tostring(o.amount))
    C["50"].rank = 37
    assert(GG.make_offer("me", "immortals", "job_champion", 1, {}) == nil,
           "a rank-37 lord leaves no champion job")
    C["50"].rank = 10

    -- captives: turn * 10 + 300, at most 1500.
    TURN = 20
    o = GG.make_offer("me", "slavers", "job_captives", 20, {})
    assert(o.amount == 500, "captives on turn 20 must ask 500, got " .. tostring(o.amount))
    TURN = 500
    o = GG.make_offer("me", "slavers", "job_captives", 500, {})
    assert(o.amount == 1500, "captives cap at 1500, got " .. tostring(o.amount))
    TURN = 1
    ok("coffers, champion and captives ask what the spec says")
end

do
    -- research: a tech the player lacks, from the generated list; none left means none.
    W.reset()
    GG.BOUNTY_TECHS[""] = {{"tech_a", 5}, {"tech_b", 6}}
    F.me.techs = {tech_a = true}
    local o = GG.make_offer("me", "daemonsmiths", "job_research", 1, {})
    assert(o and o.target == "tech_b", "research must name the tech you lack")
    assert(GG.bounty_still_valid("me", o), "an unresearched tech is a valid offer")
    F.me.techs.tech_b = true
    assert(not GG.bounty_still_valid("me", o), "a researched tech withdraws the offer")
    -- REVIEW FOCUS 4: every tech researched; the guild posts another kind.
    assert(GG.make_offer("me", "daemonsmiths", "job_research", 1, {}) == nil,
           "no tech left means no research job")
    ok("research names a missing tech and is withdrawn once researched")
end

do
    -- build: a level the player has nowhere; one they have is skipped.
    W.reset()
    GG.BOUNTY_BUILDINGS[""] = GG.BOUNTY_BUILDINGS[""] or {}
    GG.BOUNTY_BUILDINGS[""].brass = {{"lvl_have", 3}, {"lvl_want", 4}}
    F.me.regions = {"home"}
    W.region("home", {owner = "me", buildings = {lvl_have = true}})
    local o = GG.make_offer("me", "brass", "job_build", 1, {})
    assert(o and o.target == "lvl_want", "build must skip a building you own")
    R.home.buildings.lvl_want = true
    assert(not GG.bounty_still_valid("me", o), "building it withdraws the offer")
    GG.BOUNTY_BUILDINGS[""].khanate = nil
    assert(GG.make_offer("me", "khanate", "job_build", 1, {}) == nil,
           "a guild with no buildings has no building job")
    ok("building requests skip what you own and are withdrawn once built")
end

do
    -- The objective strings (spec 5 table).
    W.reset()
    local function str(o) return GG.bounty_string("me", o) end
    local s = str({guild = "brass", kind = "job_coffers", target = "job_coffers", amount = 9000,
                   gold = 1500})
    assert(s:find("type HAVE_AT_LEAST_X_MONEY;total 9000;", 1, true), s)
    s = str({guild = "immortals", kind = "job_champion", target = "job_champion", amount = 14,
             gold = 2000})
    assert(s:find("type ACHIEVE_CHARACTER_RANK;total 1;total2 14;include_generals;", 1, true), s)
    s = str({guild = "daemonsmiths", kind = "job_research", target = "tech_b", gold = 2000})
    assert(s:find("type RESEARCH_N_TECHS_INCLUDING;total 1;technology tech_b;", 1, true), s)
    s = str({guild = "brass", kind = "job_build", target = "lvl_want", gold = 2500})
    assert(s:find("type CONSTRUCT_N_OF_A_BUILDING;faction me;total 1;building_level lvl_want;",
                  1, true), s)
    s = str({guild = "slavers", kind = "job_captives", target = "job_captives", amount = 500,
             gold = 1500})
    assert(s:find("type CAPTURE_X_BATTLE_CAPTIVES;total 500;", 1, true), s)
    assert(s:find("key derpy_gg_job_slavers;", 1, true), "a job uses the job row: " .. s)
    ok("every job builds the objective string CA's own helpers build")
end

do
    -- Coffers is fixed at TAKE: treasury then + the ask.
    W.reset()
    F.me.treasury = 4000
    F.me.income = 0
    GG.TUNE.rate_bounty_stake = 0
    GG.bounties.me = {GG.make_offer("me", "brass", "job_coffers", 1, {})}
    F.me.treasury = 7000
    GG.take_bounty("me", 1)
    local s = CALLS.trigger[1][2]
    assert(s:find("total 12000;", 1, true), "coffers must ask treasury-at-take + ask: " .. s)
    ok("the coffers figure is set when the bounty is taken")
end

do
    -- Every guild can post a building request; the board mixes kinds.
    W.reset()
    for i = 1, #GG.GUILDS do
        local ks = GG.guild_kinds(GG.GUILDS[i])
        local has = false
        for j = 1, #ks do if ks[j] == "job_build" then has = true end end
        assert(has, GG.GUILDS[i] .. " cannot post a building request")
    end
    ok("all six guilds can ask for a building")
end
```

- [ ] **Step 2: Run.** Expected: FAIL on the first job assertion, because `make_offer`
  returns nil for an unknown kind.

- [ ] **Step 3: Implement**

(a) Add to `GG.BOUNTY_KINDS`. The `otype`, `obj` and `gold` values must match the generator
in Task 9 exactly.

```lua
    -- THE JOBS (spec 5). Objective strings copied from CA's generate_*_objective
    -- helpers in campaign/main_warhammer/victory_objectives_config_utils.lua.
    job_coffers  = {otype = "HAVE_AT_LEAST_X_MONEY", obj = "total %s",
                    gold = 1500, target = "none", family = "job", pick = "coffers",
                    arg = "amount"},
    job_champion = {otype = "ACHIEVE_CHARACTER_RANK",
                    obj = "total 1;total2 %s;include_generals",
                    gold = 2000, target = "none", family = "job", pick = "champion",
                    valid = "champion", arg = "amount"},
    job_research = {otype = "RESEARCH_N_TECHS_INCLUDING", obj = "total 1;technology %s",
                    gold = 2000, target = "tech", family = "job", pick = "research",
                    valid = "research", arg = "target"},
    job_captives = {otype = "CAPTURE_X_BATTLE_CAPTIVES", obj = "total %s",
                    gold = 1500, target = "none", family = "job", pick = "captives",
                    arg = "amount"},
    job_build    = {otype = "CONSTRUCT_N_OF_A_BUILDING", obj = "total 1;building_level %s",
                    gold = 2500, target = "building", family = "build", pick = "build",
                    valid = "build", arg = "target", with_faction = true},
```

(b) `GG.BOUNTY_EXTRA`. Task 8 adds the hero kinds.

```lua
GG.BOUNTY_EXTRA = {
    brass        = {"job_coffers", "job_build"},
    immortals    = {"job_champion", "job_build"},
    daemonsmiths = {"job_research", "job_build"},
    khanate      = {"job_build"},
    overseers    = {"job_build"},
    slavers      = {"job_captives", "job_build"},
}
```

(c) Helpers, pickers and validity, placed after `GG.make_bounty`:

```lua
function GG.highest_rank(faction)
    local best = 0
    pcall(function()
        local cl = cm:get_faction(faction):character_list()
        for i = 0, cl:num_items() - 1 do
            local r = cl:item_at(i):rank() or 0
            if r > best then best = r end
        end
    end)
    return best
end

function GG.player_has_building(faction, level)
    local ok, has = pcall(function()
        local rl = cm:get_faction(faction):region_list()
        for i = 0, rl:num_items() - 1 do
            if rl:item_at(i):building_exists(level) then return true end
        end
        return false
    end)
    return ok and has == true
end

-- WHERE A JOB'S TARGET COMES FROM (spec 5.1). Each returns target, owner, amount - or
-- nil when there is nothing to ask for, and the guild posts another kind instead.
-- A job with no map target stores its kind key as the target, which keeps the board's
-- one-target-once rule working without a special case.
GG.BOUNTY_PICK = {
    coffers = function(faction, kind)
        local inc = 0
        pcall(function() inc = cm:get_faction(faction):net_income() or 0 end)
        local ask = inc * 5
        if ask < 5000 then ask = 5000 end
        ask = math.ceil(ask / 500) * 500
        return kind, "", ask
    end,
    champion = function(faction, kind)
        local top = GG.highest_rank(faction)
        if top >= 37 then return nil end
        return kind, "", top + 4
    end,
    research = function(faction, kind, used)
        local list = GG.BOUNTY_TECHS_FACTION and GG.BOUNTY_TECHS_FACTION[faction]
        if not list then list = GG.BOUNTY_TECHS and GG.BOUNTY_TECHS[GG.tag(faction)] end
        if not list then return nil end
        local f = cm:get_faction(faction)
        local found = {}
        for i = 1, #list do
            local key = list[i][1]
            local ok, has = pcall(function() return f:has_technology(key) end)
            if ok and not has and not used[key] then found[#found + 1] = list[i] end
        end
        if #found == 0 then return nil end
        local pick = found[GG.roll(#found)]
        return pick[1], "", pick[2]
    end,
    captives = function(_faction, kind)
        local n = GG.turn_now() * 10 + 300
        if n > 1500 then n = 1500 end
        return kind, "", n
    end,
    build = function(faction, kind, used, guild)
        local per = GG.BOUNTY_BUILDINGS and GG.BOUNTY_BUILDINGS[GG.tag(faction)]
        local list = per and per[guild]
        if not list then return nil end
        local found = {}
        for i = 1, #list do
            local lvl = list[i][1]
            if not used[lvl] and not GG.player_has_building(faction, lvl) then
                found[#found + 1] = list[i]
            end
        end
        if #found == 0 then return nil end
        local pick = found[GG.roll(#found)]
        return pick[1], "", pick[2]
    end,
}

GG.BOUNTY_VALID = {
    champion = function(faction, o) return GG.highest_rank(faction) < (o.amount or 0) end,
    research = function(faction, o)
        local ok, has = pcall(function()
            return cm:get_faction(faction):has_technology(o.target)
        end)
        return not (ok and has)
    end,
    build = function(faction, o) return not GG.player_has_building(faction, o.target) end,
}
```

Then, in `GG.bounty_target` from Task 4, change
`if k.pick then return GG.BOUNTY_PICK[k.pick](faction, kind, used) end` so it passes the
guild. `bounty_target` does not know the guild, so thread it through:
- `GG.make_offer` calls `GG.bounty_target(faction, kind, used, false, guild)`;
- `GG.bounty_target`'s signature becomes `(faction, kind, used, war, guild)`;
- the pick line becomes `return GG.BOUNTY_PICK[k.pick](faction, kind, used, guild)`.

(d) Difficulty for jobs. In `GG.bounty_difficulty`, before the region branch:

```lua
        if k.pick then
            local a = (o and o.amount) or 0
            if k.pick == "coffers" then return math.floor(a / 100) end
            if k.pick == "champion" then return 40 end
            if k.pick == "research" then return a * 15 end
            if k.pick == "build" then return a * 25 end
            return 0
        end
```

For research and build, `amount` holds the tier or rank, which is what these multiply.

(e) `GG.bounty_string`: replace the `objective{...}` concatenation with:

```lua
    local arg = o.target
    if k.arg == "amount" then arg = tostring(o.amount or 0)
    elseif k.arg == "shape" then arg = k.shape .. GG.tag(faction) end
    local body = string.format(k.obj, arg)
    if k.with_faction then body = "faction " .. faction .. ";" .. body end
```

and use `.. "objective{type " .. k.otype .. ";" .. body .. ";}"`. Replace the `key` line
with `.. "key " .. GG.offer_mission_key(o, faction) .. ";"`.

(f) `GG.take_bounty`: before `local str = GG.bounty_string(faction, o)`, add:

```lua
    -- COFFERS IS FIXED WHEN TAKEN (spec 5.1): the treasury moves while an offer waits,
    -- so the figure is what you hold now plus what the guild asked for.
    local k = GG.BOUNTY_KINDS[o.kind]
    if k and k.pick == "coffers" and not o.ask then
        o.ask = o.amount
        pcall(function() o.amount = cm:get_faction(faction):treasury() + o.ask end)
    end
```

`o.ask` is session-only and deliberately not saved. After a take, `amount` holds the full
figure, which is what the objective and the card both need. If the trigger fails, restore
`o.amount = o.ask; o.ask = nil` in the `if not ok then` branch, on the re-found offer.

- [ ] **Step 4: Run both harnesses.** Expected: the six Task 7 `ok` lines, and both
  harnesses finish.
- [ ] **Step 5: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`. The importer's mirror
  check will now report the new kinds as missing from the generator. That is expected
  until Task 9. Record it and continue.

---

### Task 8: Hero bounties (spec §5.5)

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - the three `hero_*` kinds, and `GG.BOUNTY_EXTRA` (immortals and daemonsmiths gain
    their hero kind; the khanate's list becomes `{"hero_strike", "job_build"}`);
  - `GG.HERO_SHAPES`, `GG.hero_action_matches`, `GG.hero_progress`, `GG.void_bounty`,
    `GG.hero_target_alive` and `GG.void_stale_hero_bounties`;
  - `GG.drop_bounty_target`;
  - the `gg_agent_*` listeners, the turn-start handler, and `GG.take_bounty` (which sets
    the mission's position).
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: `GG.offer_mission_key`, `GG.bounty_cancelled`, `GG.save_bounties`.
- Produces:
  - `GG.hero_progress(faction, action_key, target, won) -> offer|nil`.
  - `GG.void_bounty(faction, o)`.
  - `GG.void_stale_hero_bounties(faction)`.

- [ ] **Step 1: Write the failing tests**

```lua
-- --------------------------------------------------------- Task 8: hero bounties --
local function world8()
    world4()
    GG.TUNE.rate_bounty_stake = 0
    GG.bounties.me = {
        {guild = "daemonsmiths", kind = "hero_sabotage", target = "foe_far", owner = "foe",
         gold = 1200, rep = 80, posted = 1, taken = true, diff = 0, war = 0, stake = 0,
         amount = 2, done = 0, void = false},
        {guild = "khanate", kind = "hero_strike", target = "31", owner = "foe",
         gold = 1200, rep = 80, posted = 1, taken = true, diff = 0, war = 0, stake = 0,
         amount = 1, done = 0, void = false},
    }
end
local DMG = "wh2_main_agent_action_champion_hinder_settlement_damage_building"
local SCOUT = "wh2_main_agent_action_champion_hinder_settlement_scout_settlement"
local WOUND = "wh2_main_agent_action_spy_hinder_agent_wound"
local CONVERT = "wh3_dlc29_agent_action_spy_hinder_agent_wound_convert_to_nur_lord"

do
    world8()
    assert(not GG.hero_progress("me", DMG, "foe_far", false), "a failure must not count")
    assert(not GG.hero_progress("me", SCOUT, "foe_far", true), "scouting must not count")
    assert(not GG.hero_progress("me", DMG, "foe_near", true), "another town must not count")
    assert(not GG.hero_progress("other", DMG, "foe_far", true),
           "another faction's hero must not count")
    assert(not GG.hero_progress("me", CONVERT, "31", true), "a Nurgle conversion must not count")
    GG.hero_progress("me", DMG, "foe_far", true)
    assert(GG.bounties.me[1].done == 1 and not CALLS.complete, "one of two is progress only")
    GG.hero_progress("me", DMG, "foe_far", true)
    assert(CALLS.complete and #CALLS.complete == 1, "two of two completes the objective")
    assert(CALLS.complete[1][3] == "derpy_gg_hero", "it completes the hero script key")
    GG.hero_progress("me", DMG, "foe_far", true)
    assert(#CALLS.complete == 1, "a third success must not complete it again")
    ok("only matching successes on the named target count, and completion happens once")
end

do
    -- REVIEW FOCUS 2: completion fires MissionSucceeded synchronously, and its handler
    -- reloads and pays. The offer must not come back, and must pay once.
    world8()
    GG.bounties.me[2].amount = 1
    cm.complete_scripted_mission_objective = function(_, f, key)
        HANDLERS.gg_mission({faction = function() return W.fi(f) end,
                             mission = function()
                                 return {mission_record_key = function() return key end}
                             end})
    end
    local rep0 = select(1, GG.get("me", "khanate"))
    GG.hero_progress("me", WOUND, "31", true)
    local rep1 = select(1, GG.get("me", "khanate"))
    assert(rep1 - rep0 == 80, "the strike must pay once, paid " .. (rep1 - rep0))
    GG.load_bounties("me")
    assert(not GG.bounty_for_guild("me", "khanate"), "a paid strike must not come back")
    ok("a completion that re-enters the mission handler pays once and stays paid")
end

do
    -- The target is gone: sabotage voids and refunds; a dead strike target completes.
    world8()
    GG.bounties.me[1].stake = 20
    GG.save_bounties("me")
    R.foe_far.owner = "me"                        -- captured
    GG.void_stale_hero_bounties("me")
    assert(CALLS.cancel and CALLS.cancel[1][2] == "derpy_gg_hero_daemonsmiths",
           "a captured sabotage target must cancel the mission")
    GG.load_bounties("me")
    assert(GG.bounty_for_guild("me", "daemonsmiths").void == true,
           "the voided offer must be saved void before the cancel")
    CALLS = {}
    GG.drop_bounty_target(31)
    assert(CALLS.complete and CALLS.complete[1][2] == "derpy_gg_job_khanate",
           "a destroyed strike target completes the strike")
    ok("a vanished target voids sabotage and completes a strike")
end

do
    -- Hero bounties may name the front, and post for Dwarfs and Empire too.
    world4()
    local o = GG.make_offer("me", "daemonsmiths", "hero_sabotage", 1, {})
    assert(o and (o.target == "foe_near" or o.target == "foe_far"), "sabotage has a target")
    local near = GG.bounty_target("me", "hero_sabotage", {foe_far = true}, false)
    assert(near == "foe_near", "hero work may be done on the front")
    for _, c in ipairs({"wh_main_dwf_dwarfs", "wh_main_emp_empire"}) do
        world4()
        GG.CULTURE_OF.me = c
        local h = GG.make_offer("me", "immortals", "hero_harry", 1, {})
        assert(h, c .. " must get a hero bounty")
        local s = GG.bounty_string("me", h)
        assert(s:find("type SCRIPTED;script_key derpy_gg_hero;override_text "
                      .. "mission_text_text_derpy_gg_hero_harry" .. GG.tag("me") .. ";", 1, true), s)
    end
    ok("hero bounties allow the front and serve Dwarfs and Empire")
end
```

- [ ] **Step 2: Run.** Expected: FAIL: `attempt to call field 'hero_progress'`.

- [ ] **Step 3: Implement**

(a) Kinds:

```lua
    -- HERO WORK (spec 5.5): SCRIPTED, completed by the mod off the agent-action events.
    -- front_ok: the front is where heroes work, and the point is to get them working.
    hero_sabotage = {otype = "SCRIPTED",
                     obj = "script_key derpy_gg_hero;override_text mission_text_text_derpy_gg_hero_%s",
                     gold = 1200, target = "region", family = "hero", shape = "sabotage",
                     arg = "shape", front_ok = true, needed = 2},
    hero_harry    = {otype = "SCRIPTED",
                     obj = "script_key derpy_gg_hero;override_text mission_text_text_derpy_gg_hero_%s",
                     gold = 1200, target = "lord", family = "hero", shape = "harry",
                     arg = "shape", front_ok = true, needed = 2},
    hero_strike   = {otype = "SCRIPTED",
                     obj = "script_key derpy_gg_hero;override_text mission_text_text_derpy_gg_hero_%s",
                     gold = 1200, target = "character", family = "job", shape = "strike",
                     arg = "shape", front_ok = true, needed = 1},
```

In `GG.make_offer`, set `amount = k.needed` for a kind with `shape`. Put
`if k.shape then amount = k.needed end` after the target lines. Hero kinds are not
`military`, so they take the pool with `war == false` (at war only), as the spec requires.

(b) `GG.BOUNTY_EXTRA`:
- immortals: `{"job_champion", "job_build", "hero_harry"}`
- daemonsmiths: `{"job_research", "job_build", "hero_sabotage"}`
- khanate: `{"hero_strike", "job_build"}`

(c) Progress, void and staleness:

```lua
GG.HERO_SHAPES = {
    sabotage = {"damage_building", "damage_walls", "assault_garrison"},
    harry    = {"assault_unit", "block_army", "hinder_replenishment"},
    strike   = {"wound", "assassinate"},
}

-- Matched on the agent_actions unique_id, e.g.
-- wh2_main_agent_action_champion_hinder_settlement_damage_building. The ability alone
-- would also count scouting and treasure hunts, which share hinder_settlement.
function GG.hero_action_matches(shape, action_key)
    if type(action_key) ~= "string" then return false end
    if string.find(action_key, "convert", 1, true) then return false end
    local words = GG.HERO_SHAPES[shape] or {}
    for i = 1, #words do
        if string.find(action_key, words[i], 1, true) then return true end
    end
    return false
end

-- One successful hero action by `faction` against `target` (a region key or a family
-- member cqi as a string). SAVED BEFORE THE COMPLETION CALL: that call can raise
-- MissionSucceeded, whose handler reloads the board from the save and pays.
function GG.hero_progress(faction, action_key, target, won)
    if not won or target == nil then return nil end
    local list = GG.bounties[faction]
    if not list then return nil end
    for i = 1, #list do
        local o = list[i]
        local k = GG.BOUNTY_KINDS[o.kind]
        if o.taken and not o.void and k and k.shape and o.target == tostring(target)
           and GG.hero_action_matches(k.shape, action_key) then
            o.done = (o.done or 0) + 1
            GG.save_bounties(faction)
            if o.done == (o.amount or 1) then
                local key = GG.offer_mission_key(o, faction)
                pcall(function()
                    cm:complete_scripted_mission_objective(faction, key, "derpy_gg_hero", true)
                end)
            end
            return o
        end
    end
    return nil
end

-- THE MOD WITHDRAWS A TAKEN HERO BOUNTY whose target is gone. Flag and save FIRST: the
-- cancel raises MissionCancelled, whose handler reloads the board and refunds only an
-- offer it reads as void.
function GG.void_bounty(faction, o)
    o.void = true
    GG.save_bounties(faction)
    local key = GG.offer_mission_key(o, faction)
    pcall(function() cm:cancel_custom_mission(faction, key) end)
end

function GG.hero_target_alive(faction, o)
    local k = GG.BOUNTY_KINDS[o.kind]
    local ok, alive = pcall(function()
        if k.target == "region" then
            local r = cm:get_region(o.target)
            if not r or r:is_null_interface() then return false end
            local owner = r:owning_faction()
            if owner:is_null_interface() or owner:name() == faction then return false end
            return cm:get_faction(faction):at_war_with(owner)
        end
        local c = cm:get_family_member_by_cqi(tonumber(o.target) or 0):character()
        if not c or c:is_null_interface() then return false end
        if k.target == "lord" then return c:has_military_force() end
        return true
    end)
    if not ok then return true end     -- cannot tell: keep the contract
    return alive == true
end

-- ONE AT A TIME, RE-READING THE BOARD AFTER EACH: every void can reload it. Called at
-- turn start AFTER the board is saved (see the turn handler), never from inside
-- GG.purge_bounties, whose own save afterwards would bring a voided offer back.
function GG.void_stale_hero_bounties(faction)
    for _ = 1, GG.BOUNTY_SLOTS do
        GG.load_bounties(faction)
        local hit = nil
        for _, o in ipairs(GG.bounties[faction] or {}) do
            local k = GG.BOUNTY_KINDS[o.kind]
            if o.taken and not o.void and k and k.shape and k.shape ~= "strike"
               and not GG.hero_target_alive(faction, o) then
                hit = o
                break
            end
        end
        if not hit then return end
        GG.void_bounty(faction, hit)
    end
end
```

(d) `GG.drop_bounty_target`:
- In the untaken branch, extend the lord test to
  `(k.target == "lord" or k.target == "character")`.
- After the loop's `if hit then GG.save_bounties(faction) end`, add a second pass:

```lua
        -- A TAKEN STRIKE whose target died is DONE, whoever killed him; a taken HARRY
        -- has nothing left to harry and is voided. Each after the save above, because
        -- both calls can reload the board.
        for _, o in ipairs(GG.bounties[faction] or {}) do
            local k = GG.BOUNTY_KINDS[o.kind]
            if o.taken and not o.void and o.target == key and k and k.shape then
                if k.shape == "strike" then
                    o.done = o.amount
                    GG.save_bounties(faction)
                    local mk = GG.offer_mission_key(o, faction)
                    pcall(function()
                        cm:complete_scripted_mission_objective(faction, mk, "derpy_gg_hero", true)
                    end)
                elseif k.shape == "harry" then
                    GG.void_bounty(faction, o)
                end
                break
            end
        end
```

(e) Listeners. In the `gg_agent_` loop, after `GG.load(name); GG.on_agent_action(name, won); GG.save(name)`, add:

```lua
            -- HERO BOUNTIES (spec 5.5). The target is a settlement for a garrison action
            -- and a character otherwise. The action key is traced while a hero bounty is
            -- live, for the in-game check that it is agent_actions.unique_id.
            local akey, target = nil, nil
            pcall(function() akey = context:agent_action_key() end)
            if event == "CharacterGarrisonTargetAction" then
                pcall(function() target = context:garrison_residence():region():name() end)
            else
                pcall(function()
                    target = tostring(context:target_character():family_member()
                                          :command_queue_index())
                end)
            end
            GG.load_bounties(name)
            if GG.hero_progress(name, akey, target, won) then
                GG.trace("hero bounty progress: " .. tostring(akey) .. " on "
                         .. tostring(target))
            end
```

`GG.hero_progress` saves by itself, so the listener does not save the board.

In the turn-start handler's human branch, after `GG.save_bounties(name)` (the line after
`GG.post_bounties(name)`), add `GG.void_stale_hero_bounties(name)`.

(f) `GG.take_bounty`: after a successful trigger, when the kind has a `shape`, point the
mission at the target:

```lua
    if k and k.shape then
        local x, y = GG.target_pos(o)
        if x then
            local key = GG.offer_mission_key(o, faction)
            pcall(function() cm:set_scripted_mission_position(key, "derpy_gg_hero", x, y) end)
        end
    end
```

- [ ] **Step 4: Run both harnesses.** Expected: the four Task 8 `ok` lines, and both
  harnesses finish. If the re-entrancy test fails with "pays twice", the save-before-call
  order in (c) is wrong. Fix the order, not the test.
- [ ] **Step 5: Checkpoint.** Run the suite. As in Task 7, only the importer's
  generator-mirror findings may remain.

---

### Task 9: Generator - kind mirror, mission rows, loc, checks (spec §6)

**Files:**
- Modify: `tools/gen_great_guilds.py`:
  - `BOUNTY_KINDS` (line ~501), the new `BOUNTY_EXTRA` and `BOUNTY_TEXT`;
  - the missions block in `_build_one` (line ~2082);
  - `check_bounties` (line ~2328) and the selftest block (line ~3800).
- Modify: `tools/import_great_guilds.py` (CRLF): add a mirror for `GG.BOUNTY_EXTRA`
- Then regenerate the TSVs.

**Interfaces:**
- Consumes: the Lua kind rows from Tasks 4, 7 and 8.
- Produces: the mission rows `derpy_gg_bounty_*`, `derpy_gg_job_*`, `derpy_gg_build_*` and
  `derpy_gg_hero_*` for every guild and flavour that has that family, plus the loc
  `mission_text_text_derpy_gg_hero_<shape><tag>`.

- [ ] **Step 1: Write the failing checks.** Replace the start of `check_bounties` (the
  count check) with:

```python
    want = sum(len(bounty_families(g)) for g in GUILDS) * len(FLAVOURS)
    if len(rows) != want:
        out.append("one mission row per guild per family per flavour: %d rows, want %d"
                   % (len(rows), want))
    for g in GUILDS:
        if g not in BOUNTIES:
            out.append("no bounty defined for guild: " + g)
            continue
        fams = [BOUNTY_KINDS[k]["family"] for k in BOUNTY_EXTRA.get(g, [])]
        if len(fams) != len(set(fams)):
            out.append("%s: two kinds share a family, so one mission row would carry "
                       "two different titles" % g)
        for k in [BOUNTIES[g][0]] + BOUNTY_EXTRA.get(g, []):
            if k not in BOUNTY_KINDS:
                out.append("%s: bounty kind %r is not in BOUNTY_KINDS" % (g, k))
```

In the vanilla block, restrict the existing contract checks to military kinds
(`if BOUNTY_KINDS[BOUNTIES[g][0]]` is unchanged, since `BOUNTIES` stays military). Then add:

```python
        # THE OTHER FAMILIES: the row's mission_type must be one CA's own rows use, and
        # the objective must be one CA's victory helpers build (or SCRIPTED).
        vanilla_types = set(r["mission_type"] for r in mrows)
        helpers = io.open("Modding Files/reference/ca_scripts_wh3/campaign/main_warhammer/"
                          "victory_objectives_config_utils.lua", encoding="utf-8").read()
        for kind, spec in sorted(BOUNTY_KINDS.items()):
            if spec["family"] == "bounty":
                continue
            if spec["mtype"] not in vanilla_types:
                out.append("%s: mission_type %s is on no vanilla mission row"
                           % (kind, spec["mtype"]))
            if spec["otype"] != "SCRIPTED" and (
                    "generate_%s_objective" % spec["otype"]) not in helpers:
                out.append("%s: CA's victory helpers never build objective %s"
                           % (kind, spec["otype"]))
```

- [ ] **Step 2: Run** `py tools/gen_great_guilds.py --check`. Expected: FAIL with
  `NameError: bounty_families`.

- [ ] **Step 3: Implement.** Add `"family": "bounty"` to the three existing
  `BOUNTY_KINDS` entries, then add:

```python
    # v2 (2026-09-27). mtype is the DB column (a label); otype is what the string
    # carries. The mtype values are each on vanilla rows; RESEARCH_N_TECHS_INCLUDING has
    # none, so its row is labelled RESEARCH_TECHNOLOGY.
    "job_coffers":   {"mtype": "HAVE_AT_LEAST_X_MONEY", "otype": "HAVE_AT_LEAST_X_MONEY",
                      "obj": "total %s", "gold": 1500, "family": "job"},
    "job_champion":  {"mtype": "ACHIEVE_CHARACTER_RANK", "otype": "ACHIEVE_CHARACTER_RANK",
                      "obj": "total 1;total2 %s;include_generals", "gold": 2000,
                      "family": "job"},
    "job_research":  {"mtype": "RESEARCH_TECHNOLOGY", "otype": "RESEARCH_N_TECHS_INCLUDING",
                      "obj": "total 1;technology %s", "gold": 2000, "family": "job"},
    "job_captives":  {"mtype": "CAPTURE_X_BATTLE_CAPTIVES",
                      "otype": "CAPTURE_X_BATTLE_CAPTIVES", "obj": "total %s",
                      "gold": 1500, "family": "job"},
    "job_build":     {"mtype": "CONSTRUCT_N_OF_A_BUILDING",
                      "otype": "CONSTRUCT_N_OF_A_BUILDING",
                      "obj": "total 1;building_level %s", "gold": 2500, "family": "build"},
    "hero_sabotage": {"mtype": "SCRIPTED", "otype": "SCRIPTED",
                      "obj": "script_key derpy_gg_hero;override_text "
                             "mission_text_text_derpy_gg_hero_%s", "gold": 1200,
                      "family": "hero"},
    "hero_harry":    {"mtype": "SCRIPTED", "otype": "SCRIPTED",
                      "obj": "script_key derpy_gg_hero;override_text "
                             "mission_text_text_derpy_gg_hero_%s", "gold": 1200,
                      "family": "hero"},
    "hero_strike":   {"mtype": "SCRIPTED", "otype": "SCRIPTED",
                      "obj": "script_key derpy_gg_hero;override_text "
                             "mission_text_text_derpy_gg_hero_%s", "gold": 1200,
                      "family": "job"},
```

Below `BOUNTIES`:

```python
# Mirrors GG.BOUNTY_EXTRA in the campaign Lua; import_great_guilds.py compares the two.
BOUNTY_EXTRA = {
    "brass":        ["job_coffers", "job_build"],
    "immortals":    ["job_champion", "job_build", "hero_harry"],
    "daemonsmiths": ["job_research", "job_build", "hero_sabotage"],
    "khanate":      ["hero_strike", "job_build"],
    "overseers":    ["job_build"],
    "slavers":      ["job_captives", "job_build"],
}


def bounty_families(g):
    return ["bounty"] + sorted({BOUNTY_KINDS[k]["family"] for k in BOUNTY_EXTRA[g]})


def family_kind(g, fam):
    for k in BOUNTY_EXTRA[g]:
        if BOUNTY_KINDS[k]["family"] == fam:
            return k
    return None


# ONE TITLE PER KIND, the description naming the flavour's own guild (ruling T9-R1 in
# the plan: the spec asked for each race's own voice; the guild's name carries it, and
# 117 hand-written lines can replace any of these later as data only).
BOUNTY_TEXT = {
    "job_coffers":   ("Fill the Coffers", "{guild} want to see your treasury full, and "
                      "kept full. Hold the sum named on the Great Guilds panel."),
    "job_champion":  ("Prove a Champion", "{guild} want a champion worth the name. Raise "
                      "one of your lords or heroes to the rank named on the Great Guilds "
                      "panel."),
    "job_research":  ("Commissioned Work", "{guild} have paid in advance for a piece of "
                      "learning. Research the technology named on the Great Guilds panel."),
    "job_captives":  ("Fill the Pens", "{guild} are short of hands. Take the number of "
                      "captives named on the Great Guilds panel in your battles."),
    "job_build":     ("A Commission", "{guild} want one of their own buildings raised in "
                      "your lands. It is named on the Great Guilds panel."),
    "hero_sabotage": ("Crack the Walls", "{guild} want a settlement weakened from inside. "
                      "Send your heroes against the one named on the Great Guilds panel."),
    "hero_harry":    ("Harry Their March", "{guild} want an army slowed and bled before it "
                      "arrives. Send your heroes against the one named on the Great Guilds "
                      "panel."),
    "hero_strike":   ("A Quiet Word", "{guild} want a name to stop being spoken. Wound or "
                      "kill the lord or hero named on the Great Guilds panel with a hero."),
}
HERO_OBJECTIVE_TEXT = {
    "sabotage": "Succeed with two hero actions against the settlement named on the Great "
                "Guilds panel.",
    "harry": "Succeed with two hero actions against the army named on the Great Guilds "
             "panel.",
    "strike": "Wound or kill the character named on the Great Guilds panel with a hero.",
}
```

In `_build_one`'s missions block, after the existing per-guild row, loop over the other
families:

```python
        for fam in bounty_families(g)[1:]:
            kind = family_kind(g, fam)
            key = "derpy_gg_%s_%s" % (fam, g)
            title, desc = BOUNTY_TEXT[kind]
            desc = desc.format(guild=GUILD_NAMES[g])
            missions.append(dict(missions[-1] if False else {}, **{
                "key": key, "mission_type": BOUNTY_KINDS[kind]["mtype"],
                "localised_title": title, "localised_description": desc,
                "ui_image": "chd/generic", "ui_icon": "rom_event_mission.png",
                "generate": "false", "prioritised": "false",
                "event_category": BOUNTY_CATEGORY, "set_piece_battle": "",
                "location_x": "0", "location_y": "0",
                "quest_mission": "false", "quest_mission_final": "false",
                "trigger_radius": "0.0000", "quest_character": "",
                "sticky_by_default": "false",
                "localised_mission_completed_text": done,
                "can_be_manually_cancelled": "true"}))
            for field, text in (("title", title), ("description", desc),
                                ("mission_completed_text", done)):
                loc.append({"key": "missions_localised_%s_%s" % (field, key),
                            "text": text, "tooltip": "false"})
```

Simplify the `dict(missions[-1] if False else {}, **{...})` to a plain `{...}` literal when
typing it. It is written this way above only to make plain that nothing is inherited from
the military row. After the guild loop, add:

```python
    for shape, text in HERO_OBJECTIVE_TEXT.items():
        loc.append({"key": "mission_text_text_derpy_gg_hero_" + shape, "text": text,
                    "tooltip": "false"})
```

`retag` appends each flavour's tag to every key, which matches
`k.shape .. GG.tag(faction)` in the Lua.

In `selftest()`, replace
`assert len(tables["missions"]) == len(GUILDS), "one bounty mission row per guild"` with:

```python
    assert len(tables["missions"]) == sum(len(bounty_families(g)) for g in GUILDS), \
        "one mission row per guild per family"
```

In the loop below it, keep the `obj.count("%s") == 1` assertion for EVERY kind in
`BOUNTY_KINDS`, not only the military ones.

(b) Importer mirror, after the existing `GG.BOUNTIES` block:

```python
        extra = re.search(r"GG\.BOUNTY_EXTRA\s*=\s*\{(.*?)\n\}", lua, re.S)
        if not extra:
            problems.append("the Lua has no GG.BOUNTY_EXTRA table")
        else:
            for guild, kinds in sorted(G.BOUNTY_EXTRA.items()):
                m = re.search(r"%s\s*=\s*\{([^}]*)\}" % re.escape(guild), extra.group(1))
                got = re.findall(r'"([a-z_]+)"', m.group(1)) if m else None
                if got != kinds:
                    problems.append("%s: Lua BOUNTY_EXTRA is %r, generator says %r"
                                    % (guild, got, kinds))
```

The existing per-kind loop over `G.BOUNTY_KINDS` then checks every new kind's `otype`
and `gold` against the Lua, with no change.

- [ ] **Step 4: Regenerate and check.**
  Run: `py tools/gen_great_guilds.py --write && py tools/gen_great_guilds.py --selftest && py tools/gen_great_guilds.py --check && py tools/import_great_guilds.py --check`
  Expected: all exit 0. The importer compares the TSVs to `build()`, so it must be green
  after `--write`.
- [ ] **Step 5: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`, with no findings
  left over from Tasks 7 and 8.

---

### Task 10: The bounty card, the help text and the preview (spec §3.6, §4, §8)

**Files:**
- Modify: `zzz_derpy_guilds_ui.lua` (CRLF): `GGUI.bounty_title`,
  `GGUI.bounty_target_label`, `GGUI.bounty_pos`, `GGUI.draw_bounties`, and a new
  `GGUI.fill`
- Modify: `tools/gen_great_guilds.py`: the panel loc list (line ~1714), the
  `derpy_gg_bounty_help` text, `help_pages` pages 3 and 5, and `page1`'s bounty clause
- Modify: `tools/preview_guilds_panel.py`: `render_bounties()`
- Test: `tools/_guilds_harness.lua`, which already dofiles the UI (add one block);
  `import_great_guilds.py --check` (loc keys asked for versus emitted)

**Interfaces:**
- Consumes: the offer fields (`war`, `stake`, `amount`, `done`), `GG.offer_mission_key`,
  `GG.BOUNTY_BUILDING_LOC`.
- Produces: the loc keys `derpy_gg_` + `bounty_war`, `bounty_war_tip`, `bounty_stake_tip`,
  `bounty_stake_short`, `bounty_char`, `bounty_obj_coffers`, `bounty_obj_coffers_taken`,
  `bounty_obj_champion`, `bounty_obj_research`, `bounty_obj_build`, `bounty_obj_captives`,
  `bounty_obj_sabotage`, `bounty_obj_harry` and `bounty_obj_strike`.

- [ ] **Step 1: Write the failing test** in `tools/_guilds_harness.lua`, as a `do ... end`
  block just before `print("harness ok")`:

```lua
do
    -- THE BOUNTY CARD SAYS WHAT A v2 OFFER IS. Labels are asked for by key, so this
    -- checks which keys a job card and a war card ask for.
    local asked = {}
    common = {get_localised_string = function(k) asked[#asked + 1] = k return "x" end}
    local o = {guild = "brass", kind = "region_take", target = "t", owner = "f", war = 1}
    GGUI.bounty_target_label(o)
    local joined = table.concat(asked, " ")
    assert(joined:find("derpy_gg_bounty_war", 1, true), "a new-war card must say so")
    asked = {}
    GGUI.bounty_target_label({guild = "brass", kind = "job_coffers", target = "job_coffers",
                              amount = 6000})
    joined = table.concat(asked, " ")
    assert(joined:find("derpy_gg_bounty_obj_coffers", 1, true), "a coffers card names the ask")
    asked = {}
    GGUI.bounty_target_label({guild = "brass", kind = "job_build", target = "lvl_x"})
    joined = table.concat(asked, " ")
    assert(joined:find("derpy_gg_bounty_obj_build", 1, true), "a build card says Build")
    common = nil
end
```

`GGUI.loc(key)` asks for `"derpy_gg_" .. key .. GGUI.tag()`, so a `find` on
`derpy_gg_bounty_war` matches whatever the tag is.

- [ ] **Step 2: Run** `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua`.
  Expected: FAIL: `a new-war card must say so`.

- [ ] **Step 3: Implement the card.** Edit with the Edit tool; the file is CRLF.

```lua
-- %n in a loc line is the number the card fills in. One placeholder, one number: a
-- sentence with the number in the middle is easier to translate than one built in pieces.
function GGUI.fill(s, n)
    return (string.gsub(s, "%%n", tostring(n)))
end

function GGUI.bounty_title(o)
    local t = GGUI.loc_raw("missions_localised_title_" .. GG.offer_mission_key(o, GGUI.me()))
    if t ~= "" then return t end
    return GGUI.loc_guild(o.guild)
end

function GGUI.bounty_target_label(o)
    local k = GG.BOUNTY_KINDS[o.kind]
    if not k then return "" end
    local owner = GGUI.faction_name(GGUI.bounty_owner_now(o))
    local progress = ""
    if k.shape and o.taken then
        progress = "  (" .. (o.done or 0) .. "/" .. (o.amount or 1) .. ")"
    end
    local lead = ""
    if k.shape then lead = GGUI.loc("bounty_obj_" .. k.shape) .. ": " end
    if k.target == "region" then
        local nm = GGUI.loc_raw("regions_onscreen_" .. tostring(o.target))
        if nm == "" then nm = tostring(o.target) end
        if o.war == 1 then
            return lead .. nm .. "  [[col:red]]" .. GGUI.loc("bounty_war") .. " "
                   .. owner .. "[[/col]]"
        end
        return lead .. nm .. "  (" .. owner .. ")" .. progress
    elseif k.target == "lord" or k.target == "character" then
        local who = GGUI.loc(k.target == "lord" and "bounty_lord" or "bounty_char")
        if o.war == 1 then
            return lead .. who .. "  [[col:red]]" .. GGUI.loc("bounty_war") .. " "
                   .. owner .. "[[/col]]"
        end
        return lead .. who .. "  (" .. owner .. ")" .. progress
    elseif k.pick == "coffers" then
        if o.taken then return GGUI.fill(GGUI.loc("bounty_obj_coffers_taken"), o.amount) end
        return GGUI.fill(GGUI.loc("bounty_obj_coffers"), o.amount)
    elseif k.pick == "champion" then
        return GGUI.fill(GGUI.loc("bounty_obj_champion"), o.amount)
    elseif k.pick == "captives" then
        return GGUI.fill(GGUI.loc("bounty_obj_captives"), o.amount)
    elseif k.pick == "research" then
        local nm = GGUI.loc_raw("technologies_onscreen_name_" .. tostring(o.target))
        return GGUI.loc("bounty_obj_research") .. ": " .. (nm ~= "" and nm or tostring(o.target))
    elseif k.pick == "build" then
        local lk = GG.BOUNTY_BUILDING_LOC and GG.BOUNTY_BUILDING_LOC[o.target]
        local nm = lk and GGUI.loc_raw(lk) or ""
        return GGUI.loc("bounty_obj_build") .. ": " .. (nm ~= "" and nm or tostring(o.target))
    end
    return ""
end
```

In `GGUI.bounty_pos`, change `if k.target == "region" then ... end` to cover
`k.target == "lord" or k.target == "character"` in the else branch, and return nil for any
other target, so a job card has no map click.

In `GGUI.draw_bounties`, for an offer card:
- Replace both `GG.bounty_mission_key(o.guild, GGUI.me())` uses with
  `GG.offer_mission_key(o, GGUI.me())`.
- The price plate now shows the STAKE, as a service card shows its favour price:

```lua
            local stake = o.stake or 0
            GGUI.set_cost(card, (stake > 0 and not o.taken) and tostring(stake) or "")
            set_tooltip(comp("card_cost", card), GGUI.loc("bounty_stake_tip"))
```

- Add the war sentence to the card tooltip:
  `if o.war == 1 then tip = tip .. "||" .. GGUI.loc("bounty_war_tip") .. " " .. owner_name .. "." end`,
  with `owner_name = GGUI.faction_name(GGUI.bounty_owner_now(o))`.
- Button, for an untaken offer, following the service card's pattern:

```lua
                if not o.taken then
                    local _, fav = GG.get(faction, o.guild)
                    local short = (o.stake or 0) > (fav or 0)
                    set_text(btn, short and ("[[col:red]]" .. GGUI.loc("take") .. "[[/col]]")
                                       or GGUI.loc("take"))
                    pcall(function() btn:SetDisabled(short) end)
                    if short then
                        tip = tip .. "||" .. string.gsub(GGUI.fill(
                            GGUI.loc("bounty_stake_short"), o.stake), "%%m", tostring(fav or 0))
                        set_tooltip(card, tip)
                    end
                end
```

Move `set_tooltip(card, tip)` so it runs after this block, or call it again as shown.

(b) Loc (generator panel list, beside `("bounty_lord", "Their general")`):

```python
                      ("bounty_war", "War with"),
                      ("bounty_war_tip", "Taking this means war with"),
                      ("bounty_stake_tip", "Favour you put up to take this bounty. You "
                       "get it back when you finish, and lose it if you fail or hand it "
                       "back."),
                      ("bounty_stake_short", "Needs %n favour with this guild to take. "
                       "You have %m."),
                      ("bounty_char", "Their lord or hero"),
                      ("bounty_obj_coffers", "Save %n gold more than you hold now"),
                      ("bounty_obj_coffers_taken", "Hold %n gold"),
                      ("bounty_obj_champion", "A lord or hero at rank %n"),
                      ("bounty_obj_research", "Research"),
                      ("bounty_obj_build", "Build"),
                      ("bounty_obj_captives", "Take %n captives in battle"),
                      ("bounty_obj_sabotage", "Sabotage"),
                      ("bounty_obj_harry", "Harry"),
                      ("bounty_obj_strike", "Wound or kill"),
```

(c) Help. Replace `page3` with:

```python
    page3 = [
        "#The board",
        "-Three offers at a time, drawn from every guild. Taking one turns it into a "
        "real mission.",
        "-Taking one puts up FAVOUR with that guild - the number on its plate. You get "
        "it back when you finish, and lose it if you fail or hand it back.",
        "-Finish it and that guild pays gold and a large amount of reputation.",
        "#What the guilds ask for",
        "-Never your front line: land or a lord far from your borders and armies, or of "
        "a faction you are at peace with. That last kind means war, and pays far more.",
        "-Or a job: hold gold, raise a champion, research, build one of the guild's own "
        "buildings, or take captives.",
        "-Or hero work: send your heroes against a named settlement, army or character.",
        "#The price",
        "-Read off the target and the distance, rated Routine, Hard or Grim. An offer "
        "you have NOT taken re-prices as the world moves; one you HAVE taken keeps its "
        "price.",
    ]
```

In `page5`, replace the two bullets under "#A bounty you took and failed" with:

```python
        "-Handing one back costs the favour you put up to take it.",
        "-Failing one costs that too, and what finishing it would have paid.",
```

Rewrite the `derpy_gg_bounty_help` text to the same facts:

```python
                "text": "A guild posts work it wants done. Take one and it becomes a "
        "mission. Taking it puts up favour with that guild; you get it back when you "
        "finish, and lose it if you fail or hand it back."
        "||Guilds never ask for your front line. They name land or a lord far from your "
        "borders, or of a faction you are at peace with - which means war, and pays "
        "far more - or a job, a building, or work for your heroes."
        "||BUT DO NOT TAKE ONE AND FAIL IT. A bounty you accepted and did not finish "
        "before its deadline also costs that guild's reputation - what finishing it "
        "would have paid."
        "||The pay is read off the target and its distance. Each offer says whether the "
        "guild rates the job Routine, Hard or Grim. An offer you have not taken "
        "re-prices as the world moves; one you have taken keeps the price you agreed.",
```

Leave `page1`'s clause "to a bounty you took and did not finish" as it is. It is still true.

(d) Preview. In `tools/preview_guilds_panel.py`, add `render_bounties(path=None, tag="")`
modelled on `render_guilds`. It draws three `_card` calls:
- a new-war capture with the red "War with" line and a stake of 20;
- a building request;
- a taken sabotage showing `(1/2)`.

Wire it into `__main__` beside `render_guilds`. `_card(P, x, y, guild_key, name, desc,
cost, button, lit)` already exists; pass the label strings built with the loc defaults
from `L(...)`.

- [ ] **Step 4: Regenerate and run.**
  Run: `py tools/gen_great_guilds.py --write` and both harnesses, then
  `py tools/import_great_guilds.py --check` (the UI must ask only for loc keys the
  generator emits), `py tools/gen_guilds_ui.py --check`, `py tools/check_guilds_ui.py`,
  `py tools/preview_guilds_panel.py --check` and `py tools/preview_guilds_panel.py`.
  Expected: every one green. The help pages fit their 21 lines; the generator's own page
  check says so if they do not, and the fix is shorter bullets. Open the rendered bounty
  PNG and look at it: no line may run past its card.
- [ ] **Step 5: Checkpoint.** Run the suite. Expected: `SUITE-GREEN`.

---

### Task 11: Mutation runner for the bounty rules (spec §9)

**Files:**
- Create: `tools/mutate_guilds.py`

**Interfaces:**
- Consumes: both harnesses.
- Produces: `py tools/mutate_guilds.py [--selftest]`, exit 1 on any survivor or stale anchor.

- [ ] **Step 1: Write the runner with its selftest first**

```python
# -*- coding: utf-8 -*-
"""Break the Great Guilds' bounty rules one at a time and prove a harness notices.

Modelled on tools/mutate_iron_court.py, with two differences that matter:
- THE GUILDS HARNESSES FAIL BY assert, not by printing FAIL. A mutant is caught when a
  harness exits non-zero with a traceback naming a harness file; a crash naming the
  model file (a parse error) is an ERROR, not a catch.
- FILES ARE READ AND WRITTEN AS BYTES. The model is LF and the UI is CRLF; a text-mode
  round trip would rewrite one of them.

    py tools/mutate_guilds.py            # every mutant
    py tools/mutate_guilds.py --selftest
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "Modding Files", "pack", "script", "campaign", "mod")
M = os.path.join(MOD, "zzz_derpy_guilds.lua")
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
HARNESSES = [os.path.join(ROOT, "tools", "_guilds_harness.lua"),
             os.path.join(ROOT, "tools", "_guilds_bounty_harness.lua")]

# (what it breaks, file, code as it ships, the mistake). Anchors are CODE lines.
MUTANTS = [
    ("the front line allowed for military work", M,
     b"        local front = (not k.front_ok) and GG.front_regions(faction) or {}",
     b"        local front = {}"),
    ("a lord on the front posted", M,
     b"                           and (k.front_ok or not GG.char_on_front(faction, gen)) then",
     b"                           then"),
    ("a pact partner made a target", M,
     b"        if pf:non_aggression_pact_with(e) then return false end",
     b""),
    ("the stake not spent", M,
     b"    if stake > 0 and not GG.spend(faction, o.guild, stake) then return false end",
     b""),
    ("the refund paid as a grant", M,
     b"    if g then g.fav = g.fav + amount end",
     b"    if g then GG.grant(faction, guild, amount, \"refund\") return end"),
    ("the new-war premium dropped", M,
     b"    if war == 1 then gm, rm = GG.BOUNTY_WAR_GOLD, GG.BOUNTY_WAR_REP end",
     b""),
    ("an opportune failure counted", M,
     b"    if not won or target == nil then return nil end",
     b"    if target == nil then return nil end"),
    ("any target counted", M,
     b"        if o.taken and not o.void and k and k.shape and o.target == tostring(target)",
     b"        if o.taken and not o.void and k and k.shape"),
    ("the void flag ignored on cancel", M,
     b"    if o and o.void then GG.refund(faction, o.guild, o.stake) end",
     b""),
    ("a hero bounty completed on every success", M,
     b"            if o.done == (o.amount or 1) then",
     b"            if true then"),
    ("the progress saved after the completion call", M,
     b"            o.done = (o.done or 0) + 1\n            GG.save_bounties(faction)",
     b"            o.done = (o.done or 0) + 1"),
    ("a researched tech still offered", M,
     b"            if ok and not has and not used[key] then found[#found + 1] = list[i] end",
     b"            if not used[key] then found[#found + 1] = list[i] end"),
]


def run():
    worst = (0, [])
    for h in HARNESSES:
        p = subprocess.run([LUA, h], capture_output=True, cwd=ROOT)
        if p.returncode != 0:
            return p.returncode, (p.stdout + p.stderr).decode("utf-8", "replace")
    return 0, ""


def check(mutants, quiet=False):
    code, text = run()
    if code != 0:
        return [("the harnesses", "not green before anything was broken: " + text[-300:])]
    bad = []
    for what, path, old, new in mutants:
        src = open(path, "rb").read()
        if src.count(old) != 1:
            bad.append((what, "STALE ANCHOR - matched %d times, not 1" % src.count(old)))
            continue
        try:
            open(path, "wb").write(src.replace(old, new))
            code, text = run()
        finally:
            open(path, "wb").write(src)
        if code == 0:
            bad.append((what, "SURVIVED - both harnesses are green with this broken"))
        elif "_harness.lua:" not in text:
            bad.append((what, "ERROR - failed without a harness assertion: " + text[-200:]))
        elif not quiet:
            print("caught: " + what)
    if run()[0] != 0:
        bad.append(("the tree", "left BROKEN - a restore did not take"))
    return bad


def selftest():
    before = open(M, "rb").read()
    harmless = [("a comment nobody can test", M, b"function GG.bounty_stake(rep)",
                 b"-- selftest\nfunction GG.bounty_stake(rep)")]
    bad = check(harmless, quiet=True)
    assert len(bad) == 1 and "SURVIVED" in bad[0][1], bad
    bad = check([("a moved anchor", M, b"no such code anywhere", b"x")], quiet=True)
    assert len(bad) == 1 and "STALE" in bad[0][1], bad
    bad = check([("a parse error", M, b"function GG.bounty_stake(rep)",
                  b"function GG.bounty_stake(")], quiet=True)
    assert len(bad) == 1 and "ERROR" in bad[0][1], bad
    assert open(M, "rb").read() == before, "the selftest did not restore the model"
    for what, path, old, _new in MUTANTS:
        n = open(path, "rb").read().count(old)
        assert n == 1, "%s: anchor matches %d times" % (what, n)
    print("selftest ok: %d mutants anchored" % len(MUTANTS))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    bad = check(MUTANTS)
    for what, why in bad:
        print("PROBLEM: %s: %s" % (what, why))
    sys.exit(1 if bad else 0)
```

- [ ] **Step 2: Run** `py tools/mutate_guilds.py --selftest`. Expected: `selftest ok: 12
  mutants anchored`. A stale anchor here means the code in Tasks 2-8 was typed differently
  from the plan. Fix the anchor to the shipped line, and note it.
- [ ] **Step 3: Run** `py tools/mutate_guilds.py`. Expected: 12 `caught:` lines, exit 0.
  A SURVIVOR is a missing test. Write the test that kills it in the task's harness block
  (watch it fail with the mutant applied by hand), then re-run.
- [ ] **Step 4: Checkpoint.** Run `md5sum` on the model and UI files before and after
  the mutation run; they must match. Then run the suite. Expected: `SUITE-GREEN`.

---

### Task 12: Build, deploy and write it down

**Files:**
- `Modding Files/Modpacks/derpy_great_guilds.pack` (built)
- `F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\derpy_great_guilds.pack` (deployed)
- Create: `docs/sessions/HANDOFF_20260927_GUILDS_BOUNTIES_V2.md`
- Modify:
  - `repos/derpy-great-guilds/CHANGELOG.md`;
  - `docs/SESSION_INDEX.md`, which gets one line and changes the spec line from
    "DESIGN ONLY" to "BUILT";
  - `docs/superpowers/specs/2026-09-27-great-guilds-bounties-v2-design.md` §6, with ruling
    T9-R1's wording.

- [ ] **Step 1: RPFM must be open.**
  Run: `powershell -c "Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing"`
  If the connection is refused, STOP and tell the user that RPFM must be open to pack.
- [ ] **Step 2: Build.** Run `py tools/import_great_guilds.py`, then
  `py tools/import_great_guilds.py --verify-only`. Expected: both green. The verify pass
  re-opens the saved pack and round-trips every table.
- [ ] **Step 3: Deploy.** Check that the game is closed
  (`tasklist | grep -i Warhammer3`). If it is running, write a background script like
  the previous sessions' `scratchpad/deploy_7f9d5cf2.sh`. The script waits for the game to
  close, checks that `data/` still holds `7f9d5cf2`, copies the current pack to
  `data/derpy_great_guilds.pack.bak_<date>_pre_bounties_v2_7f9d5cf2`, copies the new
  pack in, and MD5-compares the two. Do the same backup in `Modpacks/` before the build.
- [ ] **Step 4: Handoff.** Write
  `docs/sessions/HANDOFF_20260927_GUILDS_BOUNTIES_V2.md`, covering:
  - the build MD5 and size;
  - every ruling below, with its cost if wrong;
  - the Task 6 coverage numbers;
  - the mutation result;
  - the nine in-game checks from spec §9, verbatim.
- [ ] **Step 5: CHANGELOG** entry in plain words, newest first, in the house style. Cover:
  - the front line is never offered;
  - "new war" offers pay double;
  - taking puts up favour;
  - the jobs;
  - building requests from every guild;
  - hero work.

  Add one `SESSION_INDEX.md` line pointing at the handoff.
- [ ] **Step 6: Final suite, the mutation run and the selftests.**
  `py tools/gen_great_guilds.py --selftest`, `py tools/gen_guilds_ui.py --selftest`,
  `py tools/check_guilds_ui.py --selftest`, `py tools/preview_guilds_panel.py --selftest`,
  `py tools/make_guild_bundle_icons.py --check`, and the suite. Expected: all green.

---

## Rulings made while writing this plan

- **T4-R1: a 3 on the d3 means new war, not a 1.** `GG.roll` returns 1 with no random
  source, which is how both harnesses run. So "1 = the war you are in" keeps every
  pre-existing board test meaning what it meant.
  *Cost if wrong:* none in game; the odds are the same one in three.
- **T3-R1: when the model cannot say where the front is, the target counts as off the
  front.** This is the old behaviour, so a lookup that throws leaves the board working.
  *Cost if wrong:* a broken lookup lets a front-line target through, and the trace log
  shows it.
- **T5-R1: the refund ignores the favour cap.** The favour was the player's before they
  staked it.
  *Cost if wrong:* a player can sit briefly above the cap by one stake's worth.
- **T7-R1: jobs with no map target store their kind key as the target**, so the board's
  existing one-target-once rule needs no special case.
- **T7-R2: the coffers figure is fixed at TAKE.** The ask is stored in `amount` until then,
  and the treasury-plus-ask total after. A failed trigger restores the ask.
- **T8-R1: voids run after the turn's board save, one at a time, re-reading the board.** A
  cancel can reload the board, and a save of a list held across it would bring the voided
  offer back.
- **T9-R1: job, build and hero titles are one per kind, and each description names the
  race's own guild.** The spec asked for each race's own voice. The guild name carries it,
  and 117 hand-written lines can be swapped in later as data only.
  *Cost if wrong:* a pass of flavour writing, with no code change.
- **T9-R2: the job research row is labelled `RESEARCH_TECHNOLOGY`.** The string's
  `RESEARCH_N_TECHS_INCLUDING` has no vanilla row, and the column must name a type CA's
  own rows use.
- **T10-R1: the bounty card's price plate shows the STAKE, not the gold.** A service card's
  plate is its favour price, and the stake is the favour price of a bounty. Gold stays on
  the pay line.
