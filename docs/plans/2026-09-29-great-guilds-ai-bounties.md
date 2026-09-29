# Great Guilds: rivals take bounties - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI rivals of the player's race take, finish and fail guild bounties scored by the mod itself, and a bounty on a human's region or lord is announced on the feed and in the Log.

**Architecture:** One live bounty per AI faction in `GGAI.bounty[faction]` (own saved value, the player board's offer format). Taken and settled in the once-a-round AI sweep; sacks, hero actions and character deaths mark progress from the listeners that already exist. The player's board (`GG.bounties`) is never touched. Target picking reuses `GG.bounty_target` / `GG.make_offer` behind one new `ai` flag.

**Tech Stack:** WH3 campaign Lua 5.1 (`zzz_derpy_guilds*.lua`), Python generator `tools/gen_great_guilds.py`, RPFM MCP for packing (`tools/import_great_guilds.py`), Lua 5.1.5 harnesses, `tools/mutate_guilds.py`.

**Spec:** `docs/superpowers/specs/2026-09-29-great-guilds-ai-bounties-design.md`

## Global Constraints

- Lua 5.1; no `string.find(..., true)` plain flag in shipped Lua (`check_lua_api.py` refuses it); no loc call from any turn handler (keys only in saved values and the Log).
- Line endings: `zzz_derpy_guilds_ai.lua`, `zzz_derpy_guilds_ui.lua` and the MCT file are CRLF; `zzz_derpy_guilds.lua`, the harnesses and `mutate_guilds.py` are LF. Keep each file's own.
- Every roll is `GG.roll` (`cm:random_number`), never `math.random`.
- New `GG.TUNE_ORDER` keys go on the END.
- Player text: plain words, "Reputation", no "AI"/"rep"/"cap".
- `cm:treasury_mod(faction key, amount)`: amount must be positive.
- The located feed call passes `persistent = false` and its record is `scripted_transient_located_event`.
- Feed base index `GG.FEED_INDEX_HUNTED = 5005`, per flavour `5005 + feed offset`.
- Harness `RANDOM` stub rolls 1: a test that must refuse something lists the refused case first.

## Review Focus

1. A save made before this build (no `derpy_gg_ai_bounty_*` value): rivals must start clean, and the player's board string must load byte-identical - pinned in Task 1.
2. A rival's bounty target owned by a human who later loses it: the ending must still reach the warned human (`o.owner` is kept) - pinned in Task 4 (hunt_done on a region the human no longer holds).
3. A lord killed between a game load and the first sweep (index empty): must still count - pinned in Task 5 (`GGAI.indexed = false` before the death).
4. `rate_bounty = 0` or `ai_bounties` off: no AI bounty call and no saved value written - pinned in Task 6.
5. A model read that throws mid-settle: nothing paid, nothing voided - pinned in Task 4.

---

### Task 1: One offer format for both boards

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (`GG.save_bounties` / `GG.load_bounties`, ~2833-2878)
- Test: `tools/_guilds_bounty_harness.lua` (append before `print("bounty harness ok")`)

**Interfaces:**
- Produces: `GG.pack_offer(o) -> string`, `GG.unpack_offer(str) -> offer table or nil` (nil for an unknown kind).

- [ ] **Step 1: failing test** - append:

```lua
-- ------------------------------------------------- AI bounties: one offer format --
do
    W.reset()
    local o = {guild = "brass", kind = "region_take", target = "r1", owner = "foe",
               gold = 3000, rep = 80, posted = 4, taken = true, diff = 12,
               war = 1, stake = 20, amount = 7, done = 1, void = true}
    local s = GG.pack_offer(o)
    assert(s == "brass,region_take,r1,foe,3000,80,4,1,12,1,20,7,1,1", "packed as " .. s)
    local back = GG.unpack_offer(s)
    for k, v in pairs(o) do
        assert(back[k] == v, k .. " did not round-trip: " .. tostring(back[k]))
    end
    assert(GG.unpack_offer("brass,no_such_kind,r1") == nil, "an unknown kind unpacks to nil")
    -- The player's board string is what it always was.
    GG.bounties.me = {o}
    GG.save_bounties("me")
    assert(cm:get_saved_value("derpy_gg_bounties_me") == s, "the board string changed")
    ok("one offer format, and the player's board string is unchanged")
end
```

- [ ] **Step 2: run, expect FAIL** `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua` -> `attempt to call field 'pack_offer' (a nil value)`.
- [ ] **Step 3: implement** - replace the bodies:

```lua
-- ONE OFFER, packed. Shared by the player's board and the rivals' single bounty
-- (2026-09-29), so the two cannot drift. Fields are keys and numbers only.
function GG.pack_offer(o)
    -- APPENDED, like every other packed field in this mod. unpack_offer walks these
    -- positionally, so a new field goes on the END and an older save reads it as zero.
    return table.concat({o.guild, o.kind, o.target, o.owner or "",
                         o.gold, o.rep, o.posted,
                         o.taken and 1 or 0, o.diff or 0,
                         -- v2, APPENDED (2026-09-27): a save from before reads these as zero.
                         o.war or 0, o.stake or 0, o.amount or 0,
                         o.done or 0, o.void and 1 or 0}, ",")
end

function GG.unpack_offer(chunk)
    local f = {}
    for field in string.gmatch(chunk .. ",", "([^,]*),") do f[#f + 1] = field end
    if not (f[1] and GG.BOUNTY_KINDS[f[2]]) then return nil end
    return {guild = f[1], kind = f[2], target = f[3], owner = f[4] or "",
            gold = tonumber(f[5]) or 0, rep = tonumber(f[6]) or 0,
            posted = tonumber(f[7]) or 0, taken = f[8] == "1",
            diff = tonumber(f[9]) or 0, war = tonumber(f[10]) or 0,
            stake = tonumber(f[11]) or 0, amount = tonumber(f[12]) or 0,
            done = tonumber(f[13]) or 0, void = f[14] == "1"}
end
```

`GG.save_bounties`: loop body becomes `parts[#parts + 1] = GG.pack_offer(list[i])` (keep its header comment). `GG.load_bounties`: loop body becomes `local o = GG.unpack_offer(chunk); if o then list[#list + 1] = o end`.

- [ ] **Step 4: run both harnesses, expect PASS** (`bounty harness ok`, `harness ok`).

### Task 2: The `ai` flag on target picking

**Files:**
- Modify: `zzz_derpy_guilds.lua` - `GG.bounty_rival_ok` (~1792), `GG.bounty_pool` (~1810), `GG.bounty_target` (~1911), `GG.make_offer` (~2311)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Produces: `GG.bounty_rival_ok(pf, e, human_ok)`, `GG.bounty_pool(faction, war, human_ok)`, `GG.bounty_target(faction, kind, used, war, guild, ai)`, `GG.make_offer(faction, guild, kind, turn, used, ai)`. With `ai` true: at-war pool only, humans allowed, no front filter, `war = 0`. With `ai` nil: unchanged.

- [ ] **Step 1: failing tests** - append:

```lua
-- ------------------------------------------ AI bounties: who a rival may name --
-- "rival" is a Chaos Dwarf AI faction, the player's own race: only those hold standing.
local function worldA()
    world4()
    F.me.lords = {10}
    W.char(10, {faction = "me", general = true, x = 0, y = 0})
    W.faction("rival", {regions = {"rival_home"}, lords = {60}})
    W.region("rival_home", {owner = "rival", x = 9000, y = 9000, adj = {"foe_near"}})
    W.char(60, {faction = "rival", general = true, x = 9000, y = 9000, rank = 5})
    F.rival.met = {"me", "foe", "friend"}
    F.rival.at_war = {me = true, foe = true}
    F.me.at_war.rival, F.foe.at_war.rival = true, true
end

do
    worldA()
    F.rival.at_war = {me = true}
    local t, owner = GG.bounty_target("rival", "region_take", {}, false, "brass", true)
    assert(t == "home" and owner == "me",
           "a rival at war with a human may name the human's region, got " .. tostring(t))
    assert(GG.bounty_target("rival", "region_take", {}, false, "brass") == nil,
           "without the flag a human is never a target")
    -- THE FRONT IS ALLOWED: foe_near touches the rival's own home.
    F.rival.at_war = {foe = true}
    assert(GG.bounty_target("rival", "region_take", {foe_far = true}, false, "brass") == nil,
           "setup: without the flag the front is refused")
    local near = GG.bounty_target("rival", "region_take", {foe_far = true}, false, "brass", true)
    assert(near == "foe_near", "a rival may name the front, got " .. tostring(near))
    ok("a rival may name a human's holdings and its own front")
end

do
    worldA()
    F.rival.at_war = {}
    RANDOM = function(n) if n == 3 then return 3 end return 1 end
    assert(GG.make_offer("rival", "brass", "region_take", 1, {}, true) == nil,
           "a rival at war with nobody names nothing, even on a new-war roll")
    F.rival.at_war = {foe = true}
    local o = GG.make_offer("rival", "brass", "region_take", 1, {}, true)
    assert(o and o.war == 0 and (o.target == "foe_near" or o.target == "foe_far"),
           "a rival's offer is a war it already fights, got " .. tostring(o and o.target))
    RANDOM = function(n) return 1 end
    ok("a rival's bounty is never a new war and never names a faction at peace")
end
```

- [ ] **Step 2: run, expect FAIL** on "a rival at war with a human may name...".
- [ ] **Step 3: implement**

```lua
function GG.bounty_rival_ok(pf, e, human_ok)
    local ok, yes = pcall(function()
        -- human_ok: a RIVAL's bounty may name a human (2026-09-29); the player's never does.
        if e:is_dead() or (e:is_human() and not human_ok) or e:name() == pf:name() then
            return false
        end
```
(rest unchanged). `GG.bounty_pool(faction, war, human_ok)`: pass `human_ok` to `GG.bounty_rival_ok(pf, e, human_ok)`.

In `GG.bounty_target(faction, kind, used, war, guild, ai)`:

```lua
        -- A RIVAL (ai) fights only the wars it has, may name a human, and has no front
        -- rule: the front stops the PLAYER farming work the war finishes anyway.
        local pool = GG.bounty_pool(faction, war == true and not ai, ai)
```
```lua
        local front = (not k.front_ok and not ai) and GG.front_regions(faction) or {}
```
```lua
                           and (k.front_ok or ai or not GG.char_on_front(faction, gen)) then
```

In `GG.make_offer(faction, guild, kind, turn, used, ai)`: change `if k.military then` to `if k.military and not ai then`, and the else branch to `target, owner, amount = GG.bounty_target(faction, kind, used, false, guild, ai)`.

- [ ] **Step 4: run both harnesses, expect PASS.**

### Task 3: A rival takes a bounty, and a human is warned

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua` (new section before `-- ---- turn ---`)
- Modify: `tools/_guilds_bounty_harness.lua` (stub + tests)

**Interfaces:**
- Consumes: Task 1, Task 2.
- Produces: `GGAI.bounty`, `GGAI.by_target`, `GGAI.indexed`, `GGAI.bounty_key(f)`, `GGAI.on_map(o)`, `GGAI.load_bounty(f) -> o|nil`, `GGAI.save_bounty(f)`, `GGAI.clear_bounty(f)`, `GGAI.index(names|nil)`, `GGAI.holder_of(target) -> faction|nil`, `GGAI.offer(f, guild, turn) -> o|nil`, `GGAI.take_bounty(f, turn) -> o|nil`, `GGAI.warn(f, o)`, `GG.FEED_INDEX_HUNTED = 5005`.

- [ ] **Step 1: harness stub.** After the `dofile` of the bounty data, add `dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua")`. In `cm`, add:

```lua
    show_message_event_located = function(_, f, t, p, s, x, y, persistent, idx)
        rec("located", f, t, p, s, x, y, persistent, idx)
    end,
```
change `treasury_mod = function() end` to `treasury_mod = function(_, f, n) rec("treasury", f, n) end`, and `model` to also answer a world:

```lua
    model = function()
        return {turn_number = function() return TURN end,
                world = function()
                    return {faction_list = function()
                        local keys = {}
                        for k in pairs(F) do keys[#keys + 1] = k end
                        table.sort(keys)
                        local out = {}
                        for _, k in ipairs(keys) do out[#out + 1] = fi(k) end
                        return LIST(out)
                    end}
                end}
    end,
```
In `W.reset()` add `GG.humans = nil` and `GGAI.bounty, GGAI.by_target, GGAI.indexed, GGAI.agent_seen = {}, {}, false, nil`.

- [ ] **Step 2: failing tests** - append:

```lua
-- ------------------------------------------------ AI bounties: taking one --
do
    worldA()
    F.rival.at_war = {foe = true}
    assert(GGAI.take_bounty("rival", 1) == nil, "no favour anywhere means no bounty")
    GG.grant("rival", "immortals", 400, "test")          -- the SECOND guild only
    local _, fav0 = GG.get("rival", "immortals")
    local o = GGAI.take_bounty("rival", 1)
    assert(o and o.guild == "immortals",
           "the first guild it can afford, got " .. tostring(o and o.guild))
    assert(o.taken and o.war == 0 and o.stake > 0, "taken, never a new war, with a stake")
    local _, fav1 = GG.get("rival", "immortals")
    assert(fav0 - fav1 == o.stake, "the stake is spent, spent " .. (fav0 - fav1))
    assert(GG.bounties.rival == nil, "a rival's bounty never touches the player's board")
    GGAI.bounty.rival = nil
    local back = GGAI.load_bounty("rival")
    assert(back and back.kind == o.kind and back.target == o.target, "it survives a save")
    ok("a rival takes from the first guild it can afford and spends the stake")
end

do
    worldA()
    F.rival.at_war = {}
    GG.grant("rival", "slavers", 400, "test")
    assert(GG.make_offer("rival", "slavers", "job_captives", 1, {}),
           "setup: the player's board would post Fill the Pens")
    assert(GGAI.offer("rival", "slavers", 1) == nil, "a rival never takes Fill the Pens")
    ok("a rival never takes Fill the Pens")
end

do
    worldA()
    W.faction("rival2", {met = {"me"}})
    F.rival.at_war, F.rival2.at_war = {me = true}, {me = true}
    GG.grant("rival", "brass", 400, "test")
    GG.grant("rival2", "brass", 400, "test")
    F.me.lords = {}
    local a = GGAI.take_bounty("rival", 1)
    local b = GGAI.take_bounty("rival2", 1)
    assert(a and a.target == "home", "setup: the first rival takes my only town")
    assert(b and b.target ~= "home", "two rivals never hold one target, got " .. tostring(b and b.target))
    ok("no two rivals hold one target")
end

do
    worldA()
    F.rival.at_war = {me = true}
    F.me.lords = {}
    GG.grant("rival", "brass", 400, "test")
    local o = GGAI.take_bounty("rival", 1)
    assert(o and o.target == "home" and o.owner == "me", "setup: a bounty on my town")
    local e = GG.log_entries("me")
    assert(e[1] and e[1].kind == "hunted" and e[1].guild == "brass" and e[1].a == "home"
           and e[1].b == "rival", "the hunted player's Log must say so")
    assert(CALLS.located and #CALLS.located == 1, "one located feed message")
    local c = CALLS.located[1]
    assert(c[1] == "me" and c[7] == false and c[8] == GG.FEED_INDEX_HUNTED,
           "to me, transient, at the hunted index: " .. tostring(c[7]) .. " " .. tostring(c[8]))
    assert(c[2] == "message_event_text_text_derpy_gg_hunted_title", c[2])
    -- NOT ON A HUMAN: nothing said, nothing called.
    worldA()
    F.rival.at_war = {foe = true}
    GG.grant("rival", "brass", 400, "test")
    GGAI.take_bounty("rival", 1)
    assert(not CALLS.located and #GG.log_entries("me") == 0, "a bounty on an AI is silent")
    ok("a bounty on a human is logged and announced where it stands")
end
```

- [ ] **Step 3: run, expect FAIL** (`GGAI.take_bounty` nil).
- [ ] **Step 4: implement** - in `zzz_derpy_guilds_ai.lua`, before the `-- turn ---` rule (CRLF):

```lua
-- --------------------------------------------------------------- bounties ---
-- RIVALS TAKE BOUNTIES (docs/superpowers/specs/2026-09-29-great-guilds-ai-bounties-design.md).
-- One at a time, scored by this file rather than by an engine mission: nothing measured
-- says the engine tracks objectives for an AI faction, and CA's contracts go to humans only.
--
-- KEPT OUT OF GG.bounties. GG.drop_bounty_target, GG.hero_progress and GG.void_bounty walk
-- every list in there and call the mission functions on what they find; a rival's bounty
-- has no mission behind it.

GGAI.bounty = GGAI.bounty or {}          -- [faction] = one taken offer
GGAI.by_target = GGAI.by_target or {}    -- [map target] = the rival holding it
GGAI.indexed = false                     -- by_target built this session?
-- No script call counts battle captives, so Fill the Pens could never be scored.
GGAI.SKIP_KINDS = {job_captives = true}

-- THE WARNING'S RECORD: scripted_transient_located_event, so it lands in the feed strip
-- with a zoom button. persistent must be false to agree with it (gen_great_guilds.py).
GG.FEED_INDEX_HUNTED = 5005

function GGAI.bounty_key(faction) return "derpy_gg_ai_bounty_" .. faction end

-- A target on the map, which is what the one-rival-per-target rule and the death lookup
-- index. A job's "target" is its kind key or a tech, and two rivals may share those.
function GGAI.on_map(o)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    return k ~= nil and (k.target == "region" or k.target == "lord"
                         or k.target == "character")
end

function GGAI.load_bounty(faction)
    local s = cm:get_saved_value(GGAI.bounty_key(faction))
    local o = nil
    if type(s) == "string" and s ~= "" then o = GG.unpack_offer(s) end
    GGAI.bounty[faction] = o
    if o and GGAI.on_map(o) then GGAI.by_target[o.target] = faction end
    return o
end

function GGAI.save_bounty(faction)
    local o = GGAI.bounty[faction]
    cm:set_saved_value(GGAI.bounty_key(faction), o and GG.pack_offer(o) or "")
end

function GGAI.clear_bounty(faction)
    local o = GGAI.bounty[faction]
    if o and GGAI.by_target[o.target] == faction then GGAI.by_target[o.target] = nil end
    GGAI.bounty[faction] = nil
    GGAI.save_bounty(faction)
end

-- Every held target, loaded fresh. names nil walks the world: the listeners' first use in
-- a session, so a lord killed between a load and the first sweep still counts.
function GGAI.index(names)
    GGAI.by_target = {}
    if not names then
        names = {}
        pcall(function()
            local fl = cm:model():world():faction_list()
            for i = 0, fl:num_items() - 1 do
                local f = fl:item_at(i)
                if not f:is_null_interface() and not f:is_human() and not f:is_dead() then
                    names[#names + 1] = f:name()
                end
            end
        end)
    end
    for i = 1, #names do GGAI.load_bounty(names[i]) end
    GGAI.indexed = true
end

function GGAI.holder_of(target)
    if not GGAI.indexed then GGAI.index(nil) end
    return GGAI.by_target[target]
end

-- One guild's offer for a rival: its kinds bar the unscorable ones, from a rolled start,
-- the first that names something the rival can stake.
function GGAI.offer(faction, guild, turn)
    local kinds, all = {}, GG.guild_kinds(guild)
    for i = 1, #all do
        if not GGAI.SKIP_KINDS[all[i]] then kinds[#kinds + 1] = all[i] end
    end
    local n = #kinds
    if n == 0 then return nil end
    local start = GG.roll(n)
    for step = 0, n - 1 do
        local o = GG.make_offer(faction, guild, kinds[((start + step - 1) % n) + 1], turn,
                                GGAI.by_target, true)
        if o and GG.stake_affordable(faction, o) then return o end
    end
    return nil
end

-- posted IS THE TURN TAKEN: a rival takes at the moment of posting, so the player
-- board's own field carries the 20-turn clock and no new field is needed.
function GGAI.take_bounty(faction, turn)
    local n = #GG.GUILDS
    local start = GG.roll(n)
    for step = 0, n - 1 do
        local guild = GG.GUILDS[((start + step - 1) % n) + 1]
        local o = GGAI.offer(faction, guild, turn)
        if o and GG.spend(faction, guild, o.stake or 0) then
            local k = GG.BOUNTY_KINDS[o.kind]
            -- Fill the Coffers is fixed at the take, as the player's is.
            if k.pick == "coffers" then
                pcall(function()
                    o.amount = cm:get_faction(faction):treasury() + (o.amount or 0)
                end)
            end
            o.taken = true
            GGAI.bounty[faction] = o
            if GGAI.on_map(o) then GGAI.by_target[o.target] = faction end
            GGAI.save_bounty(faction)
            GG.save(faction)
            GGAI.warn(faction, o)
            return o
        end
    end
    return nil
end

-- A PRICE ON A HUMAN'S HOLDINGS. The Log names who and what; the feed line cannot, since
-- feed strings are fixed text, so it zooms to the target instead.
function GGAI.warn(faction, o)
    local owner = o.owner
    if not owner or owner == "" or not GG.is_human(owner) then return end
    GG.log_add(owner, "hunted", o.guild, o.target, faction)
    local x, y = GG.target_pos(o)
    if not x then return end
    local k = "message_event_text_text_derpy_gg_hunted" .. GG.tag(owner)
    pcall(function()
        cm:show_message_event_located(owner, k .. "_title", k .. "_primary",
                                      k .. "_secondary", x, y, false,
                                      GG.feed(owner, GG.FEED_INDEX_HUNTED))
    end)
end
```

- [ ] **Step 5: run both harnesses, expect PASS.** Check `py -c "b=open(r'Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua','rb').read();print(b.count(b'\r\n'),b.count(b'\n'))"` prints two equal numbers.

### Task 4: Settling a rival's bounty

**Files:**
- Modify: `zzz_derpy_guilds_ai.lua` (after Task 3's block)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: Task 3.
- Produces: `GGAI.DONE[kind](f, o) -> bool`, `GGAI.need(o) -> number`, `GGAI.is_done(f, o) -> bool`, `GGAI.settle_bounty(f, turn) -> bool` (true when it ended the bounty), `GGAI.tell(f, o, kind)`.

- [ ] **Step 1: failing tests** - append:

```lua
-- --------------------------------------------- AI bounties: how one ends --
local function takenA(kind, target, extra)
    extra = extra or {}
    worldA()
    GG.grant("rival", "brass", 400, "test")
    local o = {guild = "brass", kind = kind, target = target, owner = extra.owner or "foe",
               gold = 1000, rep = 80, posted = 1, taken = true, diff = 0, war = 0,
               stake = 20, amount = extra.amount or 0, done = 0, void = false}
    GGAI.bounty.rival = o
    GGAI.save_bounty("rival")
    return o
end

do
    takenA("region_take", "foe_far")
    local rep0, fav0 = GG.get("rival", "brass")
    assert(GGAI.settle_bounty("rival", 2) == false, "not done yet: nothing happens")
    R.foe_far.owner = "rival"
    assert(GGAI.settle_bounty("rival", 3) == true, "the rival holds it: done")
    local rep1, fav1 = GG.get("rival", "brass")
    assert(rep1 - rep0 == 80, "done pays the Reputation, paid " .. (rep1 - rep0))
    assert(fav1 - fav0 == 100, "done returns the stake and pays favour, got " .. (fav1 - fav0))
    assert(CALLS.treasury and CALLS.treasury[1][1] == "rival" and CALLS.treasury[1][2] == 1000,
           "done pays the gold")
    assert(GGAI.bounty.rival == nil and cm:get_saved_value(GGAI.bounty_key("rival")) == "",
           "done clears the bounty and its save")
    assert(GGAI.settle_bounty("rival", 4) == false and #CALLS.treasury == 1, "paid once")
    ok("a finished bounty pays stake, Reputation and gold once")
end

do
    local o = takenA("region_take", "foe_far")
    local rep0 = GG.get("rival", "brass")
    assert(GGAI.settle_bounty("rival", GG.BOUNTY_TURN_LIMIT) == false,
           "one turn short of the limit is not a failure")
    assert(GGAI.settle_bounty("rival", 1 + GG.BOUNTY_TURN_LIMIT) == true, "the limit fails it")
    assert(rep0 - GG.get("rival", "brass") == GG.bounty_fail_cost(o),
           "a failure costs what the player's would")
    takenA("region_take", "foe_far")
    R.foe_far.owner = "rival"
    local r0 = GG.get("rival", "brass")
    GGAI.settle_bounty("rival", 1 + GG.BOUNTY_TURN_LIMIT)
    assert(GG.get("rival", "brass") - r0 == 80, "finished on its last turn is paid, not failed")
    ok("a rival's failure costs Reputation, and done beats the deadline")
end

do
    takenA("hero_sabotage", "foe_far", {amount = 2})
    local rep0, fav0 = GG.get("rival", "brass")
    R.foe_far.owner = "friend"            -- the rival is not at war with friend
    assert(GGAI.settle_bounty("rival", 2), "a sabotage target no enemy holds voids it")
    local rep1, fav1 = GG.get("rival", "brass")
    assert(fav1 - fav0 == 20 and rep1 == rep0, "a void refunds the stake with no penalty")
    ok("a void refunds the stake with no penalty")
end

do
    takenA("job_coffers", "job_coffers", {amount = 5000})
    F.rival.treasury = 4999
    assert(not GGAI.settle_bounty("rival", 2), "coffers one short")
    F.rival.treasury = 5000
    assert(GGAI.settle_bounty("rival", 2), "coffers met")
    takenA("job_champion", "job_champion", {amount = 9})
    C["60"].rank = 8
    assert(not GGAI.settle_bounty("rival", 2), "champion one rank short")
    C["60"].rank = 9
    assert(GGAI.settle_bounty("rival", 2), "champion met")
    takenA("job_research", "tech_x")
    assert(not GGAI.settle_bounty("rival", 2), "research not yet")
    F.rival.techs = {tech_x = true}
    assert(GGAI.settle_bounty("rival", 2), "research done")
    takenA("job_build", "lvl_x")
    assert(not GGAI.settle_bounty("rival", 2), "build not yet")
    R.rival_home.buildings = {lvl_x = true}
    assert(GGAI.settle_bounty("rival", 2), "build done")
    ok("each job is read off the rival itself")
end

do
    -- REVIEW FOCUS 5: a read that throws neither pays nor voids.
    takenA("region_take", "foe_far")
    local real = cm.get_region
    cm.get_region = function() error("unreadable") end
    assert(GGAI.settle_bounty("rival", 2) == false, "an unreadable region is not done")
    takenA("hero_sabotage", "foe_far", {amount = 2})
    cm.get_region = function() error("unreadable") end
    assert(GGAI.settle_bounty("rival", 2) == false, "an unreadable hero target is not void")
    cm.get_region = real
    ok("an unreadable model neither pays nor voids")
end

do
    -- REVIEW FOCUS 2: a bounty on my town reports its end to me even after I lost it.
    takenA("region_take", "home", {owner = "me"})
    R.home.owner = "rival"
    GGAI.settle_bounty("rival", 2)
    local e = GG.log_entries("me")
    assert(#e == 1 and e[1].kind == "hunt_done" and e[1].a == "home" and e[1].b == "rival",
           "the hunted player hears hunt_done and nothing else")
    takenA("region_take", "home", {owner = "me"})
    GGAI.settle_bounty("rival", 1 + GG.BOUNTY_TURN_LIMIT)
    assert(GG.log_entries("me")[1].kind == "hunt_failed", "a failed hunt is logged")
    takenA("hero_sabotage", "home", {owner = "me", amount = 2})
    R.home.owner = "friend"
    GGAI.settle_bounty("rival", 2)
    assert(GG.log_entries("me")[1].kind == "hunt_void", "a withdrawn hunt is logged")
    -- THE RACE: a same-race rival's finish on someone else.
    takenA("region_take", "foe_far")
    R.foe_far.owner = "rival"
    GGAI.settle_bounty("rival", 2)
    e = GG.log_entries("me")
    assert(e[1].kind == "ai_bounty" and e[1].b == "rival" and tonumber(e[1].a) == 80,
           "a rival of my race finishing a bounty is in my Log")
    takenA("region_take", "foe_far")
    -- Both: GG.covered caches the culture it read, and takenA may already have read it.
    F.rival.culture, GG.CULTURE_OF.rival = "wh_main_emp_empire", "wh_main_emp_empire"
    R.foe_far.owner = "rival"
    GGAI.settle_bounty("rival", 2)
    assert(#GG.log_entries("me") == 0, "another race's rival is not")
    ok("the hunted hear how it ended, and the race is in the Log")
end
```

- [ ] **Step 2: run, expect FAIL** (`settle_bounty` nil).
- [ ] **Step 3: implement** (after Task 3's block, CRLF):

```lua
-- DONE WHEN, read off the world. Sack, kill and hero work are marked by the listeners
-- instead (o.done), because only an event can say who did it.
GGAI.DONE = {
    region_take = function(f, o)
        return cm:get_region(o.target):owning_faction():name() == f
    end,
    job_coffers = function(f, o) return cm:get_faction(f):treasury() >= (o.amount or 0) end,
    job_champion = function(f, o) return GG.highest_rank(f) >= (o.amount or 0) end,
    job_research = function(f, o) return cm:get_faction(f):has_technology(o.target) == true end,
    job_build = function(f, o) return GG.player_has_building(f, o.target) end,
}

-- How many marks finish it: hero work counts to its number, everything else to one.
function GGAI.need(o)
    local k = GG.BOUNTY_KINDS[o.kind]
    if k and k.shape then return math.max(o.amount or 1, 1) end
    return 1
end

-- A READ THAT THROWS IS NOT DONE. Nothing is paid on a question mark.
function GGAI.is_done(faction, o)
    if (o.done or 0) >= GGAI.need(o) then return true end
    local test = GGAI.DONE[o.kind]
    if not test then return false end
    local ok, yes = pcall(test, faction, o)
    return ok and yes == true
end

-- Done, then voided, then failed: a bounty finished on its last turn is paid. Returns
-- true when it ended the bounty, so the sweep leaves the next take to the next round.
-- Cleared BEFORE the payout, as GG.bounty_done clears the player's: a grant can rank the
-- rival up and nothing may find the bounty still standing while it does.
function GGAI.settle_bounty(faction, turn)
    local o = GGAI.bounty[faction]
    if not o then return false end
    local k = GG.BOUNTY_KINDS[o.kind]
    if GGAI.is_done(faction, o) then
        GGAI.clear_bounty(faction)
        GG.refund(faction, o.guild, o.stake)
        GG.grant(faction, o.guild, o.rep, "bounties")
        if (o.gold or 0) > 0 then
            pcall(function() cm:treasury_mod(faction, o.gold) end)
        end
        GG.save(faction)
        GGAI.tell(faction, o, "hunt_done")
        return true
    end
    -- A STRIKE IS NEVER VOIDED: its target dying completes it, as the player's does.
    if k and k.shape and k.shape ~= "strike" and not GG.hero_target_alive(faction, o) then
        GGAI.clear_bounty(faction)
        GG.refund(faction, o.guild, o.stake)
        GG.save(faction)
        GGAI.tell(faction, o, "hunt_void")
        return true
    end
    if turn - (o.posted or turn) >= GG.BOUNTY_TURN_LIMIT then
        GGAI.clear_bounty(faction)
        GG.penalise(faction, o.guild, GG.bounty_fail_cost(o))
        GG.save(faction)
        GGAI.tell(faction, o, "hunt_failed")
        return true
    end
    return false
end

-- WHO HEARS HOW IT ENDED. The hunted human, by the kind; every other human of the
-- rival's race, when it was paid - the race is per culture (as GGAI.log_purchase).
function GGAI.tell(faction, o, kind)
    if o.owner ~= "" and GG.is_human(o.owner) then
        GG.log_add(o.owner, kind, o.guild, o.target, faction)
    end
    if kind ~= "hunt_done" then return end
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    local theirs = GG.culture_of(faction)
    for i = 1, #humans do
        local h = humans[i]
        if h ~= o.owner and theirs and GG.culture_of(h) == theirs then
            GG.log_add(h, "ai_bounty", o.guild, o.rep or 0, faction)
        end
    end
end
```

- [ ] **Step 4: run both harnesses, expect PASS.**

### Task 5: The listeners mark sacks, deaths and hero work

**Files:**
- Modify: `zzz_derpy_guilds.lua` - `gg_sack_*` (~4013), `gg_agent_*` (~3977), `gg_character_destroyed` (~3910)
- Modify: `zzz_derpy_guilds_ai.lua` (after Task 4's block)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: Tasks 3-4.
- Produces: `GGAI.on_sack(f, region) -> bool`, `GGAI.hero_progress(f, action_key, target, won) -> bool`, `GGAI.on_character_destroyed(cqi) -> bool`.

- [ ] **Step 1: failing tests** - append:

```lua
-- ------------------------------------ AI bounties: what the listeners mark --
do
    takenA("region_sack", "foe_far")
    local function sack(who, region)
        HANDLERS.gg_sack_CharacterSackedSettlement({
            character = function() return W.ci(who) end,
            garrison_residence = function() return W.ri(region):garrison_residence() end})
    end
    sack(30, "foe_far")                     -- the foe itself: not the holder
    sack(60, "foe_near")                    -- the holder, the wrong town
    assert(GGAI.load_bounty("rival").done == 0, "only the holder's sack of the target counts")
    sack(60, "foe_far")
    assert(GGAI.load_bounty("rival").done == 1, "the holder's sack of the target counts")
    assert(GGAI.settle_bounty("rival", 2), "and finishes it")
    ok("a sack counts only by the holder, on the target")
end

do
    -- REVIEW FOCUS 3: a new session - nothing indexed - then the lord dies.
    takenA("lord_kill", "31")
    GGAI.indexed, GGAI.by_target, GGAI.bounty = false, {}, {}
    HANDLERS.gg_character_destroyed({family_member = function() return W.ci(31):family_member() end})
    assert(GGAI.load_bounty("rival").done == 1, "a lord destroyed by anyone finishes the kill")
    assert(GGAI.settle_bounty("rival", 2), "and it is paid")
    ok("a death counts even before the first sweep of a session")
end

do
    takenA("hero_sabotage", "foe_far", {amount = 2})
    GGAI.hero_progress("rival", DMG, "foe_far", false)
    assert(GGAI.load_bounty("rival").done == 0, "an opportune failure does not count")
    GGAI.hero_progress("rival", SCOUT, "foe_far", true)
    assert(GGAI.load_bounty("rival").done == 0, "scouting does not count")
    GGAI.hero_progress("rival", DMG, "foe_far", true)
    assert(not GGAI.settle_bounty("rival", 2), "one of two is not done")
    GGAI.hero_progress("rival", DMG, "foe_far", true)
    assert(GGAI.settle_bounty("rival", 2), "two of two is")
    assert(GG.bounties.rival == nil, "no AI path writes the player's board")
    ok("a rival's hero work counts to its number")
end
```

- [ ] **Step 2: run, expect FAIL.**
- [ ] **Step 3: implement** in the AI file:

```lua
-- ------------------------------------------------ bounty marks, from listeners ---

function GGAI.on_sack(faction, region)
    if not region then return false end
    local o = GGAI.load_bounty(faction)
    if not o or o.kind ~= "region_sack" or o.target ~= region then return false end
    o.done = GGAI.need(o)
    GGAI.save_bounty(faction)
    return true
end

-- WHETHER THE ENGINE RAISES AGENT ACTIONS FOR AI FACTIONS is unmeasured (CA's followers
-- script filters them with is_human(), which suggests it does), so the first one seen is
-- said once a session. No line in a log that has an AI turn in it means it does not.
function GGAI.hero_progress(faction, action_key, target, won)
    if not GGAI.agent_seen and not GG.is_human(faction) then
        GGAI.agent_seen = true
        GG.trace("agent action reached AI faction " .. tostring(faction)
                 .. " - rivals' hero bounties can count")
    end
    if not won or target == nil then return false end
    local o = GGAI.load_bounty(faction)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    if not (k and k.shape and o.target == tostring(target)
            and GG.hero_action_matches(k.shape, action_key)) then
        return false
    end
    o.done = (o.done or 0) + 1
    GGAI.save_bounty(faction)
    return true
end

-- CharacterDestroyed does not say who killed, so this finds the holder by target. A kill
-- or a strike counts whoever did it, as the player's KILL_CHARACTER_BY_ANY_MEANS does.
function GGAI.on_character_destroyed(cqi)
    local key = tostring(cqi)
    local holder = GGAI.holder_of(key)
    if not holder then return false end
    local o = GGAI.load_bounty(holder)
    if not o or o.target ~= key then return false end
    if o.kind ~= "lord_kill" and o.kind ~= "hero_strike" then return false end
    o.done = GGAI.need(o)
    GGAI.save_bounty(holder)
    return true
end
```

In `zzz_derpy_guilds.lua` (LF):
- `gg_character_destroyed`: `if ok and cqi then GG.drop_bounty_target(cqi) end` becomes

```lua
            if ok and cqi then
                GG.drop_bounty_target(cqi)
                -- A RIVAL'S KILL OR STRIKE (2026-09-29). GGAI lives in the AI file.
                if GGAI and GGAI.on_character_destroyed then GGAI.on_character_destroyed(cqi) end
            end
```
- `gg_agent_*`: after the `if GG.hero_progress(...) ... end` block add

```lua
            if GGAI and GGAI.hero_progress then GGAI.hero_progress(name, akey, target, won) end
```
- `gg_sack_*`: after `GG.save(name)` add

```lua
            -- A RIVAL'S SACK BOUNTY. The region comes off the garrison, which this
            -- context carries (scripting_doc: character, garrison_residence).
            local region = nil
            pcall(function() region = context:garrison_residence():region():name() end)
            if GGAI and GGAI.on_sack then GGAI.on_sack(name, region) end
```

- [ ] **Step 4: run both harnesses, expect PASS.**

### Task 6: The switch and the sweep

**Files:**
- Modify: `zzz_derpy_guilds.lua` - `GG.TUNE_DEFAULTS`, `GG.TUNE_ORDER`
- Modify: `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` (CRLF) - checkbox after `o_ai`
- Modify: `zzz_derpy_guilds_ai.lua` - `GGAI.bounties_on`, `GGAI.bounty_sweep`, `GGAI.run_turn`
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: Tasks 3-5.
- Produces: `GGAI.bounties_on() -> bool`, `GGAI.bounty_sweep(names, turn) -> number settled`.

- [ ] **Step 1: failing tests** - append:

```lua
-- ------------------------------------------------ AI bounties: the sweep --
do
    worldA()
    GG.grant("rival", "brass", 400, "test")
    GGAI.bounty_sweep({"rival", "foe"}, 1)
    local o = GGAI.bounty.rival
    assert(o, "a rival with favour and no bounty takes one")
    assert(GGAI.bounty.foe == nil and cm:get_saved_value(GGAI.bounty_key("foe")) == nil,
           "a faction with no standing is not touched")
    local held = o.target
    GGAI.bounty_sweep({"rival"}, 2)
    assert(GGAI.bounty.rival.target == held, "a rival holding a bounty takes no second one")
    R[held].owner = "rival"
    assert(GGAI.bounty_sweep({"rival"}, 3) == 1, "the sweep settles it")
    assert(GGAI.bounty.rival == nil, "settled this round: no new take until the next")
    GGAI.bounty_sweep({"rival"}, 4)
    assert(GGAI.bounty.rival, "the next round takes again")
    ok("the sweep settles first, and takes only when a rival holds nothing")
end

do
    -- REVIEW FOCUS 4: off means no call and no write.
    for _, how in ipairs({"switch", "rate"}) do
        worldA()
        GG.grant("rival", "brass", 400, "test")
        if how == "switch" then GG.TUNE.ai_bounties = false else GG.TUNE.rate_bounty = 0 end
        GGAI.bounty_sweep({"rival"}, 1)
        assert(GGAI.bounty.rival == nil and cm:get_saved_value(GGAI.bounty_key("rival")) == nil,
               how .. " off: nothing taken, nothing written")
    end
    ok("ai_bounties off, or a bounty rate of 0, stops the rivals")
end

do
    -- THE ROUND ITSELF runs the sweep, and never for a human.
    worldA()
    GG.grant("rival", "brass", 400, "test")
    GG.save("rival")
    local cs, st, sw = GGAI.court_step, GGAI.step, GG.snapshot_world
    GGAI.court_step = function() return false end
    GGAI.step = function() return false end
    GG.snapshot_world = function() end
    GGAI.run_turn()
    GGAI.court_step, GGAI.step, GG.snapshot_world = cs, st, sw
    assert(GGAI.bounty.rival, "the round's sweep takes a rival's bounty")
    assert(cm:get_saved_value(GGAI.bounty_key("me")) == nil, "never a human's")
    ok("the AI round takes rivals' bounties")
end
```

- [ ] **Step 2: run, expect FAIL** (`bounty_sweep` nil).
- [ ] **Step 3: implement.** `GG.TUNE_DEFAULTS`: after `guild_notices = true,` add

```lua
    -- RIVALS TAKE BOUNTIES (2026-09-29). Off, rivals never take one; ai_spending off
    -- stops them too, since it stops the whole AI round.
    ai_bounties = true,
```
`GG.TUNE_ORDER`: append `"ai_bounties",` after `"rate_bounty_stake",`.

MCT file, after `o_ai:set_assigned_section("systems")`:

```lua

local o_aib = m:add_new_option("ai_bounties", "checkbox")
o_aib:set_text("Rivals take bounties")
o_aib:set_tooltip_text("Rival factions of your race take the guilds' bounties too, and "
    .. "earn reputation when they finish one. A rival at war with you may be paid to take "
    .. "your settlements or kill your lords - you are told when, and by whom.")
o_aib:set_default_value(true)
o_aib:set_assigned_section("systems")
```

AI file, after Task 5's block:

```lua
function GGAI.bounties_on()
    if GG.setting and GG.setting("ai_bounties") == false then return false end
    return GG.bounty_pay() > 0
end

-- THE ROUND'S BOUNTY PASS, after every faction's Court and service. Only a faction that
-- holds standing and is covered can hold a bounty - which is the player's own race.
function GGAI.bounty_sweep(names, turn)
    if not GGAI.bounties_on() then return 0 end
    local mine = {}
    for i = 1, #names do
        if GG.state[names[i]] and GG.covered(names[i]) then mine[#mine + 1] = names[i] end
    end
    -- ALL OF THEM FIRST, so a rival early in the list cannot take a target one later in
    -- it already holds.
    GGAI.index(mine)
    local settled = 0
    for i = 1, #mine do
        local f = mine[i]
        if GGAI.settle_bounty(f, turn) then
            settled = settled + 1
        elseif not GGAI.bounty[f] then
            GGAI.take_bounty(f, turn)
        end
    end
    return settled
end
```

`GGAI.run_turn`: declare `local names = {}` beside `local bought, demands, patrons = 0, 0, 0`; inside the loop after `local name = f:name()` add `names[#names + 1] = name`; after the loop's `end)` and before `GG.snapshot_world(...)` add

```lua
    -- OUTSIDE the pcall above and in its own: a sweep that died is traced, not silent.
    local okb, err = pcall(GGAI.bounty_sweep, names, turn)
    if not okb then GG.trace("rivals' bounty pass failed: " .. tostring(err)) end
```

- [ ] **Step 4: run both harnesses, expect PASS.**

### Task 7: The Log draws the new lines

**Files:**
- Modify: `zzz_derpy_guilds_ui.lua` (CRLF) - `GGUI.log_text`, `GGUI.LOG_FILTERS`, new `GGUI.hunt_target`
- Test: `tools/_guilds_harness.lua` (new IIFE before `print("harness ok")`)

**Interfaces:**
- Produces: `GGUI.hunt_target(a) -> string`; UI loc keys `log_hunted`, `log_for`, `log_hunt_done`, `log_hunt_failed`, `log_hunt_lost`, `log_hunt_void`, `log_ai_bounty`, `log_your_char` (Task 8 ships them).

- [ ] **Step 1: failing test** - before `print("harness ok")`:

```lua
;(function()
    -- RIVALS' BOUNTIES IN THE LOG (2026-09-29). With no loc a fragment reads as its key,
    -- so the assertions read keys; the names come from the stubbed loc below.
    local prev_fm, prev_common = cm.get_family_member_by_cqi, common
    cm.get_family_member_by_cqi = function()
        return {character = function()
            return {is_null_interface = function() return false end,
                    get_forename = function() return "names_name_7" end,
                    get_surname = function() return "" end}
        end}
    end
    common = {get_localised_string = function(k)
        if k == "names_name_7" then return "Drazhoath" end
        if k == "regions_onscreen_r1" then return "Zharr-Naggrund" end
        return ""
    end}
    local function line(kind, a) return GGUI.log_text({turn = 3, kind = kind,
        guild = "khanate", a = a, b = "cr_rival"}) end
    local t, bad = line("hunted", "7")
    assert(string.find(t, "log_hunted Drazhoath, log_for cr_rival", 1, true), t)
    assert(bad, "a price on you is bad news")
    t, bad = line("hunt_done", "r1")
    assert(string.find(t, "cr_rival log_hunt_done Zharr-Naggrund", 1, true), t)
    assert(bad, "a price collected is bad news")
    cm.get_family_member_by_cqi = function() error("gone") end
    t, bad = line("hunt_failed", "7")
    assert(string.find(t, "cr_rival log_hunt_failed log_your_char, log_hunt_lost", 1, true), t)
    assert(not bad, "a hunt that failed is not bad news for you")
    t = line("hunt_void", "r1")
    assert(string.find(t, "log_hunt_void Zharr-Naggrund", 1, true), t)
    t = line("ai_bounty", "80")
    assert(string.find(t, "cr_rival log_ai_bounty 80 reputation", 1, true), t)
    for _, kind in ipairs({"hunted", "hunt_done", "hunt_failed", "hunt_void", "ai_bounty"}) do
        assert(GGUI.LOG_FILTERS.rivals[kind], kind .. " must show under Rivals")
    end
    cm.get_family_member_by_cqi, common = prev_fm, prev_common
end)()
```

- [ ] **Step 2: run `lua.exe tools/_guilds_harness.lua`, expect FAIL** (`log_text` returns nil for `hunted` -> `bad argument to find`).
- [ ] **Step 3: implement** (CRLF). Before `function GGUI.log_text(e)`:

```lua
-- WHAT A BOUNTY ON YOU NAMED, at draw time. A number is a character, named off its own
-- name keys while it can still be read; anything else is a region.
function GGUI.hunt_target(a)
    if tonumber(a) then
        local name = ""
        pcall(function()
            local c = cm:get_family_member_by_cqi(tonumber(a)):character()
            if not c or c:is_null_interface() then return end
            name = GGUI.loc_raw(c:get_forename())
            local sn = GGUI.loc_raw(c:get_surname())
            if sn ~= "" then name = (name ~= "" and (name .. " ") or "") .. sn end
        end)
        if name ~= "" then return name end
        return GGUI.loc("log_your_char")
    end
    local r = GGUI.loc_raw("regions_onscreen_" .. tostring(a))
    if r ~= "" then return r end
    return tostring(a)
end
```
In `GGUI.log_text`, before `else return nil`:

```lua
    elseif k == "hunted" then
        bad = true
        body = GGUI.loc("log_hunted") .. " " .. GGUI.hunt_target(e.a) .. ", "
               .. GGUI.loc("log_for") .. " " .. GGUI.faction_name(e.b)
    elseif k == "hunt_done" then
        bad = true
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_hunt_done") .. " "
               .. GGUI.hunt_target(e.a)
    elseif k == "hunt_failed" then
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_hunt_failed") .. " "
               .. GGUI.hunt_target(e.a) .. ", " .. GGUI.loc("log_hunt_lost")
    elseif k == "hunt_void" then
        body = GGUI.loc("log_hunt_void") .. " " .. GGUI.hunt_target(e.a)
    elseif k == "ai_bounty" then
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_ai_bounty") .. " " .. e.a
               .. " " .. GGUI.loc("reputation")
```
`GGUI.LOG_FILTERS.rivals` becomes `{ai_buy = true, hit = true, lead_lost = true, hunted = true, hunt_done = true, hunt_failed = true, hunt_void = true, ai_bounty = true}`.

- [ ] **Step 4: run both harnesses, expect PASS.** Check CRLF counts as in Task 3.

### Task 8: The generator ships the record and the words

**Files:**
- Modify: `tools/gen_great_guilds.py`

**Interfaces:**
- Consumes: `GG.FEED_INDEX_HUNTED` (Task 3), the loc keys of Tasks 3 and 7.

- [ ] **Step 1: see it fail.** Run `py tools/gen_great_guilds.py --check`. Expected: `check_ui_loc_keys` findings for the eight new `log_*` keys (no row ships them). If it reports nothing for them, that check does not cover `GGUI.loc` literals in `log_text`, and Step 3's mirror check below is the only guard - note it in the handoff.
- [ ] **Step 2: implement.**
  - After `FEED_INDEX_RANK = 5004`:

```python
# A FIFTH RECORD, the first LOCATED one: a rival has been paid to take your settlement
# or kill your lord (2026-09-29). Transient, so it lands in the feed strip with a zoom
# button rather than taking the screen - a big war can bring several in a round.
FEED_GROUP_HUNTED = "derpy_gg_event_feed_hunted"
FEED_INDEX_HUNTED = 5005
```
  - After `FEED_ROW_RANK = ...`:

```python
# Cloned from wh2_dlc10_event_feed_scripted_defender_of_ulthuan_bad, a working
# scripted_transient_located_event, read from the cached table 2026-09-29: the event type,
# the negative sound, no icon and no instant open are its values. The Lua passes
# persistent=false to agree; a located call against a plain record draws nothing.
FEED_ROW_HUNTED = dict(FEED_ROW, group=FEED_GROUP_HUNTED,
                       event="scripted_transient_located_event",
                       sound_event="UI_CAM_POPUP_Message_Event_Negative",
                       override_icon="", instant_open="false")
```
  - In `_build_one`'s return, add `{"id": FEED_GROUP_HUNTED}` to `campaign_groups`, `{"group": FEED_GROUP_HUNTED, "id": FEED_GROUP_HUNTED, "priority": "0"}` to `campaign_group_members`, `{"member": FEED_GROUP_HUNTED, "value": str(FEED_INDEX_HUNTED)}` to `campaign_group_member_criteria_values`, and `dict(FEED_ROW_HUNTED)` to `event_feed_message_events` - each as the LAST entry, keeping the four lists index-aligned.
  - After the `derpy_gg_hit` loc block:

```python
    # A rival paid to take what is yours. Fixed text: the Log names who and what.
    loc.append({"key": "message_event_text_text_derpy_gg_hunted_title",
                "text": "A Price on Your Holdings", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_hunted_primary",
                "text": "A guild has hired a rival against you.", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_hunted_secondary",
                "text": "The Guilds panel's Log names who, and what they were paid to take.",
                "tooltip": "false"})
```
  - In the UI tuple list after `("log_from", "from"),`:

```python
                      # RIVALS' BOUNTIES (2026-09-29). Lower case, no full stop.
                      ("log_hunted", "put a price on"),
                      ("log_for", "for"),
                      ("log_hunt_done", "collected the price on"),
                      ("log_hunt_failed", "failed to collect the price on"),
                      ("log_hunt_lost", "and lost Reputation for it"),
                      ("log_hunt_void", "withdrew its price on"),
                      ("log_ai_bounty", "finished a bounty and earned"),
                      ("log_your_char", "one of your lords or heroes"),
```
  - `log_help` text becomes: "Every rank you gain or lose, every service you buy, every service your rivals buy or use against you, every price a guild puts on you, and every guild lead that changes hands. The most recent entries are kept."
  - In `check()`, replace the persistent loop with:

```python
    for r in tables["event_feed_message_events"]:
        want = ("scripted_transient_located_event"
                if r["group"].startswith(FEED_GROUP_HUNTED) else "scripted_persistent_event")
        if r["event"] != want:
            out.append("%s's event must be %s to agree with the Lua call's persistent flag"
                       % (r["group"], want))
```
  - In `check_feed_mirror`, add `("GG.FEED_INDEX_HUNTED", FEED_INDEX_HUNTED)` to the tuple, and before its final `return out`:

```python
    for tag in FLAVOURS:
        for part in ("title", "primary", "secondary"):
            k = "message_event_text_text_derpy_gg_hunted%s_%s" % (tag, part)
            if k not in shipped:
                out.append("GGAI.warn builds %s and no loc row ships it" % k)
    call = re.search(r"show_message_event_located\((.*?)GG\.FEED_INDEX_HUNTED", lua, re.S)
    if not call or ", false," not in call.group(1):
        out.append("the hunted feed call must pass persistent=false: its record is "
                   "scripted_transient_located_event, and a mismatch draws nothing")
```
- [ ] **Step 3: run** `py tools/gen_great_guilds.py --check` then `--selftest` if it has one (read its `__main__`), expect clean; then `py tools/gen_great_guilds.py --write`; then both harnesses (the main harness's tooltip sweep reads the regenerated `loc.tsv`).

### Task 9: Mutants

**Files:**
- Modify: `tools/mutate_guilds.py`

- [ ] **Step 1:** add `A = os.path.join(MOD, "zzz_derpy_guilds_ai.lua")   # CRLF` beside `U`, and append to `MUTANTS` (AI-file anchors are single lines, so CRLF does not matter):

```python
    ("a rival's pool widened past its wars", M,
     b"        local pool = GG.bounty_pool(faction, war == true and not ai, ai)",
     b"        local pool = GG.bounty_pool(faction, war == true or ai == true, ai)"),
    ("humans never a rival's target", M,
     b"        if e:is_dead() or (e:is_human() and not human_ok) or e:name() == pf:name() then",
     b"        if e:is_dead() or e:is_human() or e:name() == pf:name() then"),
    ("two rivals on one target", A,
     b"                                GGAI.by_target, true)",
     b"                                {}, true)"),
    ("a rival's stake not spent", A,
     b"        if o and GG.spend(faction, guild, o.stake or 0) then",
     b"        if o then"),
    ("a rival's failure not charged", A,
     b"        GG.penalise(faction, o.guild, GG.bounty_fail_cost(o))",
     b"        local _ = 0"),
    ("a void that also penalises", A,
     b"        GGAI.tell(faction, o, \"hunt_void\")",
     b"        GG.penalise(faction, o.guild, 999) GGAI.tell(faction, o, \"hunt_void\")"),
    ("an unreadable read that pays", A,
     b"    local ok, yes = pcall(test, faction, o)",
     b"    local ok, yes = pcall(test, faction, o) if not ok then return true end"),
    ("the feed call made for a non-human target", A,
     b"    if not owner or owner == \"\" or not GG.is_human(owner) then return end",
     b"    if not owner or owner == \"\" then return end"),
    ("a bounty done on its last turn failed instead", A,
     b"    if GGAI.is_done(faction, o) then",
     b"    if GGAI.is_done(faction, o) and turn - (o.posted or turn) < GG.BOUNTY_TURN_LIMIT then"),
    ("a sack of any town counted", A,
     b"    if not o or o.kind ~= \"region_sack\" or o.target ~= region then return false end",
     b"    if not o or o.kind ~= \"region_sack\" then return false end"),
    ("a second bounty taken while one is held", A,
     b"        elseif not GGAI.bounty[f] then",
     b"        else"),
```
- [ ] **Step 2: run** `py tools/mutate_guilds.py --selftest` (every anchor matches once) then `py tools/mutate_guilds.py`. Expected: every mutant `caught`, no PROBLEM line. A survivor means a test above does not measure its rule: fix the test, not the mutant.

### Task 10: Verify, build, deploy, record

- [ ] **Step 1: static checks** - `luac -p` on the three changed Lua files and the MCT file; `py tools/check_lua_api.py` (all pack Lua); `py tools/check_lua_literal_left.py`; `py tools/check_lua_undeclared.py` on the AI file. All clean.
- [ ] **Step 2: generators** - `py tools/gen_great_guilds.py --check`, `py tools/gen_guilds_ui.py --check`, `py tools/import_great_guilds.py --check`. Clean.
- [ ] **Step 3: build** - RPFM must be open (`Invoke-WebRequest http://127.0.0.1:45127/sessions`); if closed, stop and say so. Then `py tools/import_great_guilds.py` (verifies the saved pack itself).
- [ ] **Step 4: deploy** - if `Warhammer3.exe` is not running: back up `data/derpy_great_guilds.pack` to `.bak_ai_bounties_20260929`, copy the built pack in, compare MD5s.
- [ ] **Step 5: record** - `docs/sessions/HANDOFF_20260929_GUILDS_AI_BOUNTIES.md` (what shipped, the build MD5, the covered-race correction, the three in-game checks); update the spec's SESSION_INDEX line to BUILT with the handoff; a CHANGELOG entry in `repos/derpy-great-guilds/CHANGELOG.md`; `py tools/sync_guilds_repo.py --check` then the sync (add the handoff to its manifest). No push unless asked.
