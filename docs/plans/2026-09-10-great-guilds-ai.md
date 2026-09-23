# The Great Guilds — Plan 3 of 3: the AI, the settings, and the league table

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI factions spend their standing on fifteen of the eighteen services, the player is
told when one lands on them, every number becomes MCT-tunable, and the Standings tab shows who
else is climbing.

**Architecture:** The accrual listeners from plan 1 already run for every faction, so the AI has
standing already — this plan adds only a spend policy, two target pickers and the reporting.
Every tunable number moves out of the two hard-coded tables into one MCT-driven table, snapshotted
into the save at the first turn start.

**Tech Stack:** Lua 5.1.5, MCT, `cm:show_message_event`, RPFM MCP.

**Spec:** `docs/superpowers/specs/2026-09-10-great-guilds-design.md`

**Depends on:** plans 1 and 2 complete and deployed.

## Global Constraints

Plan 1 and plan 2's Global Constraints still apply, unchanged. Additional to this plan:

- **One purchase per AI faction per turn.** Hard cap, not a tuning value.
- **`cm:show_message_event`'s last argument indexes `event_feed_message_events`** through a
  four-table chain. A wrong index draws **nothing** — no error, no feed entry.
- **MCT's own campaign gating is dead code.** Every economic value must be frozen into the save
  at the first turn start, exactly as the Exchange does it. The **debug** class is the
  exception: it reads MCT live and is deliberately not snapshotted.
- **An MCT settings file loads in MCT's environment and cannot see `GG`** — a mod script's
  globals are not `_G`. Reach the mod with `core:trigger_custom_event`, which is CA-documented
  and what MCT uses internally.
- **`military_force_list` counts garrisons.** An unfiltered army pick can hand a hired regiment
  to a city garrison.
- **`faction:effect_bundles()` lists bundles, not effects**, and a bundle-key filter works —
  call `duration()` to tell a timed one from a permanent one.

---

### Task 1: Finish the battle listener

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`
- Modify: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.on_battle` from plan 1 Task 4 (the handler exists; the listener is a stub).
- Produces: a working `gg_battle` listener, `GG.battle_award(winner_key, was_outnumbered)`.

- [ ] **Step 1: Read what the battle context actually offers**

```powershell
py -c "import io,re; s=io.open(r'Modding Files/reference/ca_script_docs_wh3/scripting_doc.html',encoding='utf-8',errors='replace').read(); i=s.find('BattleCompleted'); print(re.sub('<[^>]+>','',s[i-200:i+2500]))"
```

Record which of `pending_battle`, `attacker`, `defender`, `attacker_won` are available and
whether unit counts are reachable. **Do not guess** — plan 1 left this listener a stub
precisely because it was not verified.

- [ ] **Step 2: Write the failing harness assertions**

```lua
-- Attribution: only the winner is paid.
GG.state["cr_win"] = nil; GG.state["cr_lose"] = nil
GG.reset_turn("cr_win"); GG.reset_turn("cr_lose")
GG.battle_award("cr_win", false)
assert(select(1, GG.get("cr_win", "immortals")) == 15, "winner paid 15")
assert(select(1, GG.get("cr_lose", "immortals")) == 0, "loser paid nothing")

-- Outnumbered doubles it.
GG.reset_turn("cr_win2")
GG.battle_award("cr_win2", true)
assert(select(1, GG.get("cr_win2", "immortals")) == 30, "outnumbered win is 30")

-- A nil winner is a no-op, not an error.
GG.battle_award(nil, false)
```

- [ ] **Step 3: Run it to verify it fails, then implement**

```lua
function GG.battle_award(winner, outnumbered)
    if not winner then return end
    GG.load(winner)
    GG.on_battle(winner, outnumbered)
    GG.save(winner)
end
```

and replace the stub listener from plan 1 with the real one, using **only** the context members
step 1 confirmed. Wrap every context read in `pcall` — a listener condition that errors drops
with no log line at all.

- [ ] **Step 4: Run the harness and all three gates**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_api.py ; py tools\check_lua_undeclared.py
```

---

### Task 2: The AI spend policy

**Files:**
- Create: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua`
- Modify: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.can_buy`, `GG.buy`, `GG.SERVICES`, `GG.get` from plan 2.
- Produces: `GGAI.ALLOWED` (set of 15 service keys), `GGAI.choose(faction) -> service_key or nil`,
  `GGAI.step(faction)`, `GGAI.run_turn()`.

- [ ] **Step 1: Write the failing harness assertions**

```lua
-- The three cut services are never chosen, however rich the faction is.
GG.state["cr_ai"] = nil
for _, g in ipairs(GG.GUILDS) do GG.grant("cr_ai", g, 5000) end
local picked = {}
for _ = 1, 200 do
    local k = GGAI.choose("cr_ai")
    if k then picked[k] = true end
end
assert(not picked["hobgoblin_eyes"], "AI must not buy hobgoblin_eyes")
assert(not picked["bound_blueprint"], "AI must not buy bound_blueprint")
assert(not picked["raise_ziggurat"], "AI must not buy raise_ziggurat")
local n = 0; for _ in pairs(picked) do n = n + 1 end
assert(n >= 10, "AI should reach most of the 15 over 200 rolls, got "..n)

-- One purchase per faction per turn, hard cap.
GG.state["cr_ai2"] = nil
for _, g in ipairs(GG.GUILDS) do GG.grant("cr_ai2", g, 5000) end
local before = select(2, GG.get("cr_ai2", "brass"))
GGAI.step("cr_ai2"); GGAI.step("cr_ai2"); GGAI.step("cr_ai2")
local spent = 0
for _, g in ipairs(GG.GUILDS) do
    spent = spent + (5000 - select(2, GG.get("cr_ai2", g)))
end
assert(spent <= 400, "at most one purchase a turn, spent "..spent)

-- A poor faction buys nothing and does not error.
GG.state["cr_broke"] = nil
assert(GGAI.choose("cr_broke") == nil, "poor faction picks nothing")
GGAI.step("cr_broke")
```

- [ ] **Step 2: Implement the policy**

```lua
-- The Great Guilds - AI. Accrual is shared with the player and lives in
-- zzz_derpy_guilds.lua; this file only spends.
GGAI = GGAI or {}

-- Fifteen of the eighteen. The three excluded are not "unimplemented" - they
-- are deliberately cut, see the design spec section 6.1:
--   hobgoblin_eyes   revealing shroud is meaningless for an AI
--   bound_blueprint  needs the AI's current research subject, call unverified
--   raise_ziggurat   needs a per-turn scan for in-progress construction
GGAI.EXCLUDED = {hobgoblin_eyes = true, bound_blueprint = true, raise_ziggurat = true}

GGAI.bought_this_turn = GGAI.bought_this_turn or {}

-- Replaced in Task 3. Until then every targeted service is skipped, which is
-- the correct behaviour anyway: a targeted service is never fired blind.
function GGAI.pick_target(faction, s) return nil end

function GGAI.choose(faction)
    local affordable = {}
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if not GGAI.EXCLUDED[s.key] then
            if GG.can_buy(faction, s.key) then
                -- Weight by cost: a faction that can afford a tier-3 service
                -- should usually take it rather than dribbling on tier-1s.
                local weight = math.floor(s.cost / 50)
                for _ = 1, weight do affordable[#affordable + 1] = s.key end
            end
        end
    end
    if #affordable == 0 then return nil end
    return affordable[cm:random_number(#affordable)]
end

function GGAI.step(faction)
    if GGAI.bought_this_turn[faction] then return end
    local key = GGAI.choose(faction)
    if not key then return end
    local s = GG.service(key)
    local target = GGAI.pick_target(faction, s)
    if s.kind ~= "bundle" and s.kind ~= "gold" and s.kind ~= "pooled" and not target then
        return    -- a targeted service with no target is skipped, never fired blind
    end
    if GG.buy(faction, key, target) then
        GGAI.bought_this_turn[faction] = true
        GG.save(faction)
        GGAI.report(faction, s, target)
    end
end
```

- [ ] **Step 3: Add the harness stub for `cm:random_number` and run**

```lua
cm.random_number = function(_, n) return math.random(n) end
```

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `harness ok`.

---

### Task 3: The two target pickers

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua`
- Modify: `tools/_guilds_harness.lua`

**Interfaces:**
- Produces: `GGAI.pick_target(faction, service) -> target or nil`,
  `GGAI.pick_army(faction) -> cqi or nil`, `GGAI.pick_enemy(faction) -> faction_key or nil`.

- [ ] **Step 1: Write the failing harness assertions**

```lua
-- A garrison is never picked. military_force_list counts garrisons.
local forces = {
    {armed_citizenry = true,  cqi = 1},
    {armed_citizenry = false, cqi = 2},
}
GGAI.TEST_FORCES = forces
assert(GGAI.pick_army("cr_pick") == 2, "must skip the garrison, got "
       ..tostring(GGAI.pick_army("cr_pick")))

-- No field army at all is nil, not an error.
GGAI.TEST_FORCES = {{armed_citizenry = true, cqi = 1}}
assert(GGAI.pick_army("cr_pick") == nil, "garrison-only faction has no target")

-- An enemy is picked only from factions at war.
GGAI.TEST_WARS = {"cr_enemy"}
assert(GGAI.pick_enemy("cr_pick") == "cr_enemy", "picks a war target")
GGAI.TEST_WARS = {}
assert(GGAI.pick_enemy("cr_pick") == nil, "no war, no target")
```

- [ ] **Step 2: Implement**

```lua
function GGAI.pick_army(faction)
    -- military_force_list counts garrisons, so the filter is not optional:
    -- without it the hired regiment can land in a city garrison.
    local list = GGAI.TEST_FORCES
    if not list then
        local ok, f = pcall(function() return cm:get_faction(faction) end)
        if not ok or not f or f:is_null_interface() then return nil end
        local ok2, mfl = pcall(function() return f:military_force_list() end)
        if not ok2 or not mfl then return nil end
        list = {}
        for i = 0, mfl:num_items() - 1 do
            local mf = mfl:item_at(i)
            list[#list + 1] = {armed_citizenry = mf:is_armed_citizenry(),
                               cqi = mf:command_queue_index()}
        end
    end
    for i = 1, #list do
        if not list[i].armed_citizenry then return list[i].cqi end
    end
    return nil
end

function GGAI.pick_enemy(faction)
    local wars = GGAI.TEST_WARS
    if not wars then
        wars = {}
        local ok, f = pcall(function() return cm:get_faction(faction) end)
        if not ok or not f or f:is_null_interface() then return nil end
        local ok2, fl = pcall(function() return f:factions_at_war_with() end)
        if ok2 and fl then
            for i = 0, fl:num_items() - 1 do
                wars[#wars + 1] = fl:item_at(i):name()
            end
        end
    end
    if #wars == 0 then return nil end
    return wars[1]
end

function GGAI.pick_target(faction, s)
    if s.kind == "unit" then return GGAI.pick_army(faction) end
    if s.hostile then return GGAI.pick_enemy(faction) end
    return nil
end
```

- [ ] **Step 3: Verify the two interface calls exist**

`is_armed_citizenry` and `factions_at_war_with` are on non-singleton receivers, which
`check_lua_api.py` cannot resolve — it has no type inference. Check them by hand:

```powershell
py -c "import io,re; s=io.open(r'Modding Files/reference/ca_script_docs_wh3/scripting_doc.html',encoding='utf-8',errors='replace').read(); [print(n, s.count(n)) for n in ['is_armed_citizenry','factions_at_war_with','command_queue_index','num_items','item_at']]"
```

A zero count means the name is wrong. Find the real one before proceeding — a wrong method name
on a live interface throws, and the throw kills every listener queued after it.

- [ ] **Step 4: Run the harness and the gates**

---

### Task 4: Telling the player they were hit

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua`
- Modify: `tools/gen_great_guilds.py` (the four feed tables and their loc)

**Interfaces:**
- Produces: `GGAI.report(faction, service, target)`, and four new DB tables in `build()`.

An unexplained public-order debuff is a bug report, not a mechanic. This task is what makes The
Khan's Price legible.

- [ ] **Step 1: Read the four-table index chain**

```powershell
py -c "import io; s=io.open(r'docs/RITUALS.md',encoding='utf-8').read(); i=s.find('show_message_event'); print(s[i-3000:i+3000])"
```

`cm:show_message_event`'s last argument **indexes `event_feed_message_events`**. A wrong index
draws nothing at all. Record the four tables and the index this mod needs.

- [ ] **Step 2: Add the feed rows to `build()`**

Add the four tables the chain needs, with the index recorded in step 1, plus two loc keys —
title and body — for the hostile-service notification. Extend `selftest()` to assert the index
is a positive integer and that both loc keys exist.

- [ ] **Step 3: Implement `GGAI.report`**

```lua
function GGAI.report(faction, s, target)
    -- Only a service that landed on a human is announced. An AI buffing itself
    -- is Log content, not a feed interrupt.
    if not s.hostile or not target then return end
    local humans = cm:get_human_factions()
    for i = 1, #humans do
        if humans[i] == target then
            cm:show_message_event(target,
                "message_event_text_text_derpy_gg_hit_title",
                "message_event_text_text_derpy_gg_hit_primary",
                "message_event_text_text_derpy_gg_hit_secondary",
                true, GG.FEED_INDEX)
            return
        end
    end
end
```

`GG.FEED_INDEX` is the integer from step 1. **Do not leave it as a guess** — a wrong index is
silent.

---

### Task 5: MCT settings, frozen at first turn start

**Files:**
- Create: `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua`
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`

**Interfaces:**
- Produces: `GG.TUNE` (table, snapshotted), `GG.setting(key) -> value`,
  `GG.snapshot_settings()`, `GG.DEBUG` (live-read, never snapshotted).

- [ ] **Step 1: Move both hard-coded tables into one**

`RATES` in the generator and `GG.CAP` in the Lua are the same numbers written twice. Collapse
the Lua side into `GG.TUNE` with the rates, caps, rank thresholds, service costs and cooldowns,
and have `GG.capped_grant` and `GG.can_buy` read `GG.setting(...)` rather than the literals.

- [ ] **Step 2: Snapshot at the first turn start**

```lua
-- MCT's own campaign gating is dead code, so every economic value is frozen
-- into the save at the first turn start. The debug class is deliberately NOT
-- snapshotted: it reads MCT live, which is what makes it usable mid-campaign.
function GG.snapshot_settings()
    if cm:get_saved_value("derpy_gg_tuned") then
        GG.TUNE = GG.unpack_tune(cm:get_saved_value("derpy_gg_tuned"))
        return
    end
    GG.TUNE = GG.read_mct_or_defaults()
    cm:set_saved_value("derpy_gg_tuned", GG.pack_tune(GG.TUNE))
end
```

- [ ] **Step 3: Write the MCT settings file**

A difficulty preset (easy / default / hard / ultra / custom), sliders for the six rates and six
caps, the five rank thresholds, an **AI spending on/off switch**, and a debug section. Model it
on `Modding Files/pack/script/mct/settings/derpy_chd_zharr_exchange.lua`.

The settings file loads in MCT's environment and **cannot see `GG`** — a mod script's globals
are not `_G`. Any action button must fire `core:trigger_custom_event` and be caught in the mod.

- [ ] **Step 4: Add a harness test that a snapshot round-trips**

```lua
GG.TUNE = nil
saved["derpy_gg_tuned"] = nil
GG.snapshot_settings()
local first = GG.setting("cap_brass")
GG.TUNE = nil
GG.snapshot_settings()
assert(GG.setting("cap_brass") == first, "snapshot must not re-read after turn 1")
```

- [ ] **Step 5: Run every gate**

---

### Task 6: The Standings league table

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua`

**Interfaces:**
- Consumes: `GG.state` for every faction, `GG.rank_of`.
- Produces: `GGUI.leaders() -> table of {guild, faction_key, rank, rep}`.

- [ ] **Step 1: Implement the leaders scan**

```lua
function GGUI.leaders()
    local out = {}
    for gi = 1, #GG.GUILDS do
        local guild, best, best_rep = GG.GUILDS[gi], nil, -1
        for faction, tracks in pairs(GG.state) do
            local t = tracks[guild]
            if t and t.rep > best_rep then best, best_rep = faction, t.rep end
        end
        out[#out + 1] = {guild = guild, faction_key = best,
                         rank = GG.rank_of(best_rep >= 0 and best_rep or 0),
                         rep = best_rep >= 0 and best_rep or 0}
    end
    return out
end
```

`faction_key` is a **key**, not a display name — the row resolves it to a name at draw time,
never in a handler.

- [ ] **Step 2: Draw it on tab 2 and add a harness assertion**

```lua
GG.state = {a = {brass = {rep = 500, fav = 0}}, b = {brass = {rep = 900, fav = 0}}}
local l = GGUI.leaders()
assert(l[1].faction_key == "b", "highest reputation leads")
assert(l[1].rank == 4, "900 is favoured")
```

- [ ] **Step 3: Run the gates**

---

### Task 7: Pack, deploy, and soak

- [ ] **Step 1: Run every gate in order**

```powershell
py tools\gen_great_guilds.py --selftest ; py tools\gen_great_guilds.py --check
py tools\gen_guilds_ui.py --selftest ; py tools\check_guilds_ui.py --selftest ; py tools\check_guilds_ui.py
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
py tools\check_lua_api.py ; py tools\check_lua_undeclared.py
py tools\import_great_guilds.py
```

- [ ] **Step 2: Pack through RPFM MCP, save, verify from outside, deploy**

Same procedure as plan 2 Task 7 step 4, with the new AI script and MCT settings file added.

- [ ] **Step 3: The soak run — this is the point of the whole plan**

The spec's §11 test list, ordered by what a wrong answer costs. Run one campaign to turn 100
and record:

1. **The rate curve.** Did rank 2 land near turn 15? Is Exalted reachable by turn 100? Every
   number in the design is a shape, not a measurement — this is the run that turns them into
   measurements.
2. **AI spending balance.** Run it again with the MCT AI switch off and compare. If the two
   campaigns feel identical, the AI cap is too tight; if the AI feels unfair, it is too loose.
3. **The Khan's Price landing on you.** Confirm the feed message draws. If nothing appears, the
   `event_feed_message_events` index is wrong and it will be silent, not errored.
4. **Bundle visibility.** Open Faction Effects and confirm rank bundles and service bundles both
   appear with their numbers. A missing `%+n` draws the sentence with no number; a false
   `is_global_effect` draws nothing at all.
5. **Save and reload** mid-campaign. Standing, cooldowns and the tuning snapshot must all
   survive.

- [ ] **Step 4: Write the handoff**

`docs/sessions/HANDOFF_<date>_GREAT_GUILDS_LIVE.md` — what shipped, what the soak measured,
what the measurements changed, and what is still unproven. Then one line in
`docs/SESSION_INDEX.md`.

---

## What remains after plan 3

- **Multiplayer.** Two machines have never run this. The design argues it is simpler than the
  Exchange's, because there is no shared model to transport — that argument is untested.
- **Phase 2 (Dwarfs) and phase 3 (Empire).** Loc and icons only, per spec §10.
- **The three AI-cut services**, if the AI ever feels passive.
- **More than three services per guild**, once the loop is proven fun.
