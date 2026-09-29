# Great Guilds: service pools, stage 1 - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every guild card draws from a pool of three services and the draw rotates every N turns. This adds 36 new shared services and four new service kinds. The Hire service's broken unit grant is fixed first.

**Architecture:**
- **One catalogue.** `GG.SERVICES` is append-only; a row's `rank` is its tier.
- **Cards per faction.** Each faction holds 18 drawn service keys (`GG.cards`), saved in `derpy_gg_cards_<faction>`. `GG.rotate_cards` redraws them from turn handlers when `floor(turn / N)` advances.
- **One gate.** `GG.can_buy` refuses anything not on the faction's cards. The panel, the purchase and the rivals already go through it, so all three respect the draw.
- **Old saves.** A faction with no cards reads today's 18.
- **Generator.** It gains per-service `effects` lists, so a service can carry effects of its own instead of its guild's rank effect.

**Tech Stack:** WH3 campaign Lua 5.1 (float32 numbers in game), Python 3 generator (`tools/gen_great_guilds.py`), Lua 5.1.5 harnesses, RPFM MCP server for the pack build.

**Spec:** `docs/superpowers/specs/2026-09-29-great-guilds-service-pools-and-races-design.md`
- In scope: §3, §4, §5, §8 (`rotate_turns` only), the stage-1 parts of §9 and §10, §11 and §12.
- Stage 2 gets its own plan once this one is built: race services, Empire politics and lords, Slave Tithe payouts, earn routes, twists, `race_differences`, the Help page, and draw rule 2 (a race service always on show).
- Five corrections found while planning are written into the spec (§5, §8, §9, §12):
  - the rotation Log line goes under the Mine filter;
  - the countdown goes in the footer;
  - `rotate_turns` is read on every preset and locked in campaign;
  - the rival picks for `ranks` and `settlement`;
  - Hire's target is now checked.

## Global Constraints

- **Lua and numbers:** Lua 5.1; the game's Lua is float32, so every number stored or compared is an integer.
- **Multiplayer:** every roll is `GG.roll`, called only from turn handlers (`gg_turn`, `GGAI.run_turn`). The panel never rolls and never draws.
- **No loc calls from a turn handler.** Turn code stores keys; the panel resolves the text.
- **Line endings, checked 2026-09-29 by byte count:**
  - CRLF: `zzz_derpy_guilds_ai.lua`, `zzz_derpy_guilds_ui.lua`, `script/mct/settings/derpy_great_guilds.lua`.
  - LF: `zzz_derpy_guilds.lua`, both harnesses, `gen_great_guilds.py`, `gen_guilds_ui.py`, `mutate_guilds.py`.
  - Edit with the Edit tool or byte-level Python; never `sed -i`.
- **`GG.SERVICES` is append-only**, because cooldowns are saved by position. Each Lua row stays on ONE line: `import_great_guilds.py` mirrors rank, cost and cd with the single-line regex `key="x".*?rank=(\d+)`.
- **`GG.TUNE_ORDER` is append-only**, because the multiplayer settings string is positional.
- **Every effect key, scope and value is from the spec §5 table** (verified against vanilla 2026-09-29). A different one is a spec change, not a plan edit.
- **Player text:** plain words, "Reputation" never "standing", no emojis anywhere.
- **Progress:** the workspace is not a git repo, so there are no commits. Progress goes in the ledger at `.superpowers/sdd/2026-09-29-great-guilds-service-pools-stage1/progress.md`.
- **Harness runs**, from the workspace root:
  - `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua` must end `bounty harness ok`.
  - `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua` must end `harness ok`.
  - Redirect output to `$TEMP` and read the tail.
  - The `RANDOM` stub rolls 1 unless a test replaces it.
- **Tests must survive Task 7.** Task 7 gives every card three services, so a test written in Tasks 2-5 asserts on the pool it reads, never on which key a roll of 1 lands on in a pool Task 7 will grow.

## Review Focus

1. **An existing save mid-campaign** (18 cooldowns, no cards). The panel must show and sell today's 18, and the first draw must happen at the next turn start, never from the panel. Pinned in Tasks 2 and 3.
2. **A friendly service aimed at the wrong thing:**
   - an enemy army selected for Forced March;
   - an enemy settlement selected for Granaries;
   - an enemy lord selected for Warlord's Honour;
   - an enemy general selected for Hire.

   The buff must never land on the enemy. Pinned in Task 5.
3. **The panel reading cards must not roll**, because a roll outside a turn handler desyncs multiplayer. Pinned in Task 2.
4. **A service rotated off its card while the player is picking a target for it** must be refused (`"card"`), not bought. Pinned in Task 3.
5. **`hostile_services` off:** Sow Discord, Poisoned Wells and Scorched Earth must never be drawn or sold, and The Khan's Price stays refused. Pinned in Tasks 3 and 5.

## File map

| File | Change |
|---|---|
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (LF) | Hire lookup fix; cards state, draw, rotation and notice; new kinds' payloads, target check and wire; 36 service rows; `rotate_turns` setting and its every-preset read |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua` (CRLF) | rotate in the rivals' round; pickers for the new kinds |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` (CRLF) | cards read per faction; hints and pickers for the new kinds; confirm for enemy settlements; footer countdown; `rotation` Log line |
| `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` (CRLF) | `rotate_turns` slider; `hostile_services` tooltip |
| `tools/gen_great_guilds.py` (LF) | per-service effects, bundle target by kind, service text, inverted-sign set, rotation feed record, 36 rows and their names in nine flavours, new UI loc, `check_presets` exemption, selftest counts |
| `tools/gen_guilds_ui.py` (LF) | card-slot check counts ranks, not services |
| `tools/_guilds_bounty_harness.lua` (LF) | stubs for the new engine calls; tests for Tasks 1-5 and 7 |
| `tools/_guilds_harness.lua` (LF) | `char_lookup_str` stub; owner-aware character stub; fixtures that now need an owned target; the `rotation` Log line |
| `tools/mutate_guilds.py` (LF) | mutants for the draw, the card gate and the target check |

**Test placement ruling** (same as the rival-bounties plan): stage-1 tests go at the end of the bounty harness, under `-- SERVICE POOLS` headers, before `print("bounty harness ok")`. The bounty harness already stubs a world of factions, regions and characters, which every new test needs. `_guilds_harness.lua` is within a handful of Lua's 200-local ceiling, so anything added there goes in an IIFE or a `do` block.

---

### Task 1: Hire's unit grant takes a lookup string

**Files:**
- Modify: `zzz_derpy_guilds.lua` (`GG.payload`, `kind == "unit"` branch)
- Test: `tools/_guilds_bounty_harness.lua`, `tools/_guilds_harness.lua`

**Interfaces:**
- Produces two harness stubs that later tasks' character calls use the same way:
  - `cm:char_lookup_str(c)` returns `"character_cqi:" .. cqi`;
  - `cm:grant_unit_to_character(lookup, unit)` records `"grant"`.

- [ ] **Step 1: Stubs and failing tests**

In the bounty harness `cm = { ... }` table, after the `show_message_event_located` entry, add:

```lua
    -- CA's campaign_manager builds "character_cqi:<n>" from a character or a cqi
    -- (lib_campaign_manager.lua:5558); the character calls below take that string.
    char_lookup_str = function(_, c)
        if type(c) == "table" then c = c:command_queue_index() end
        return "character_cqi:" .. tostring(c)
    end,
    grant_unit_to_character = function(_, lookup, unit) rec("grant", lookup, unit) end,
```

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------- SERVICE POOLS: Hire's grant --
do
    -- CA documents grant_unit_to_character's first argument as a character LOOKUP
    -- STRING and every CA call builds one with cm:char_lookup_str; a bare cqi is not one.
    W.reset()
    W.char(70, {faction = "me", general = true, x = 0, y = 0})
    F.me.lords = {70}
    GG.CULTURE_OF.me = GG.CHD_CULTURE
    GG.payload("me", GG.service("hire_immortals"), 70)
    assert(CALLS.grant and #CALLS.grant == 1, "one unit granted")
    assert(CALLS.grant[1][1] == "character_cqi:70",
           "the grant takes a lookup string, got " .. tostring(CALLS.grant[1][1]))
    ok("Hire grants its unit through a character lookup string")
end
```

In `tools/_guilds_harness.lua`, after the line `cm.grant_unit_to_character = function(_, cqi, u) units[#units + 1] = {cqi, u} end`, add:

```lua
cm.char_lookup_str = function(_, c) return "character_cqi:" .. tostring(c) end
```

and change

```lua
assert(units[#units][1] == 42, "granted to the given cqi")
```

to

```lua
assert(units[#units][1] == "character_cqi:42",
       "granted through a lookup string for the given cqi, got " .. tostring(units[#units][1]))
```

- [ ] **Step 2: Run both and watch them fail**

Run the two harness commands.
Expected: both exit 1. The bounty harness reports `the grant takes a lookup string, got 70`; the main harness reports `granted through a lookup string for the given cqi, got 42`.

- [ ] **Step 3: Fix the payload**

In `GG.payload`, replace

```lua
        if target and unit then cm:grant_unit_to_character(target, unit) end
```

with

```lua
        -- A LOOKUP STRING, NOT A CQI. CA documents the first argument as a character
        -- lookup string and every CA call builds one with cm:char_lookup_str; the cqi
        -- off the wire was passed bare from the first build (found 2026-09-29).
        if target and unit then
            cm:grant_unit_to_character(cm:char_lookup_str(target), unit)
        end
```

- [ ] **Step 4: Run both harnesses**

Expected: `bounty harness ok` and `harness ok`, exit 0.

- [ ] **Step 5: Ledger**

`Task 1: complete (both harnesses ok; RED seen: got 70 / got 42)`.

---

### Task 2: A faction's cards, and the gate that honours them

**Files:**
- Modify: `zzz_derpy_guilds.lua` (new section after `GG.service`; `GG.can_buy`; `GG.load`)
- Modify: `zzz_derpy_guilds_ui.lua` (`GGUI.services_of` and its three callers)
- Test: `tools/_guilds_bounty_harness.lua` (`W.reset`, new tests)

**Interfaces:**
- Consumes: `GG.SERVICES`, `GG.GUILDS`, `GG.service`.
- Produces:
  - `GG.CARD_RANKS = {2, 3, 4}`
  - `GG.cards[faction] = {turn = n, keys = {18 keys}}`
  - `GG.default_card(guild, rank) -> key`: the first row of that guild and rank, which is today's service.
  - `GG.cards_of(faction) -> {18 keys}`: in `GG.GUILDS` order, ranks 2-4 within each guild. Returns the defaults when the faction has no cards. Never rolls.
  - `GG.guild_cards(faction, guild) -> {3 service rows}`: ranks 2, 3, 4.
  - `GG.on_card(faction, key) -> bool`
  - `GG.cards_key(faction)`, `GG.save_cards(faction)`, `GG.load_cards(faction)`
  - `GG.can_buy` refuses `"card"` for a service not on the faction's cards, before any other check but `"unknown"`.
  - `GGUI.services_of(guild, faction)` returns `GG.guild_cards(faction, guild)`.

- [ ] **Step 1: Failing tests**

In the bounty harness `W.reset()`, after `GG.CULTURE_OF = {}`, add:

```lua
    GG.cards = {}
```

Append the tests:

```lua
-- ------------------------------------------------- SERVICE POOLS: the cards --
do
    -- REVIEW FOCUS 1 and 3: a faction with no cards holds today's 18, and reading them
    -- never rolls - the panel reads this, and a roll from UI code desyncs multiplayer.
    W.reset()
    local rolls = 0
    RANDOM = function(n) rolls = rolls + 1 return 1 end
    local keys = GG.cards_of("me")
    assert(#keys == 18, "18 cards, got " .. #keys)
    assert(keys[1] == "caravan_levy" and keys[4] == "oathbound_draft"
           and keys[18] == "great_coffle", "defaults are today's services in card order")
    local g = GG.guild_cards("me", "khanate")
    assert(#g == 3 and g[1].key == "hobgoblin_eyes" and g[3].key == "khans_price",
           "a guild's three cards, ranks 2-4")
    assert(GG.on_card("me", "forge_rite") and not GG.on_card("me", "no_such"),
           "on_card answers from the cards")
    assert(rolls == 0, "reading cards rolled " .. rolls .. " times")
    assert(cm:get_saved_value(GG.cards_key("me")) == nil, "reading cards wrote nothing")
    ok("no cards means today's 18, read without a roll")
end

do
    W.reset()
    GG.cards.me = {turn = 3, keys = GG.cards_of("me")}
    GG.cards.me.keys[3] = "long_ledger"               -- slot 3 is brass rank 4 already
    GG.save_cards("me")
    GG.cards.me = nil
    GG.load_cards("me")
    assert(GG.cards.me and GG.cards.me.turn == 3 and GG.cards.me.keys[3] == "long_ledger",
           "cards survive a save")
    -- A KEY THIS BUILD DOES NOT SELL, or one in the wrong slot, reads as that slot's
    -- default rather than nil.
    cm:set_saved_value(GG.cards_key("me"), "4;gone_service" .. string.rep(",caravan_levy", 17))
    GG.load_cards("me")
    assert(GG.cards.me.keys[1] == "caravan_levy" and GG.cards.me.keys[4] == "oathbound_draft",
           "an unknown or misplaced key reads as that slot's default")
    cm:set_saved_value(GG.cards_key("me"), "garbage")
    GG.load_cards("me")
    assert(GG.cards.me == nil, "an unreadable value is no cards at all")
    ok("cards save and load, and a bad value falls back")
end

do
    -- THE GATE: not on a card, not for sale.
    W.reset()
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
    GG.cooldowns.me = {}
    GG.CULTURE_OF.me = GG.CHD_CULTURE
    assert(GG.can_buy("me", "forge_rite"), "setup: a default card sells")
    GG.cards.me = {turn = 1, keys = GG.cards_of("me")}
    GG.cards.me.keys[7] = "bound_blueprint"            -- the daemonsmiths rank-2 slot
    local okb, why = GG.can_buy("me", "forge_rite")
    assert(not okb and why == "card", "off the cards is refused as card, got " .. tostring(why))
    ok("a service not on the faction's cards is refused")
end
```

(`bound_blueprint` is rank 3. It sits in a rank-2 slot here only to take `forge_rite` off the cards; Task 3's draw never does this.)

- [ ] **Step 2: Run and watch it fail**

Run the bounty harness command.
Expected: exit 1, `attempt to call field 'cards_of' (a nil value)`.

- [ ] **Step 3: Implement the cards**

In `zzz_derpy_guilds.lua`, directly after `function GG.service(key) ... end`, add:

```lua
-- ---------------------------------------------------------------- the cards --
-- EIGHTEEN CARDS PER FACTION, one per guild per rank, each holding one service drawn from
-- that guild and rank's pool (spec 2026-09-29-great-guilds-service-pools-and-races §4).
-- A faction with no cards holds each card's FIRST row - today's service - so an old save,
-- the panel before the first turn and every test that never draws all read the
-- eighteen the mod always sold. Reading cards never rolls: the panel reads them, and a
-- roll from UI code runs on one machine and desyncs multiplayer.
GG.CARD_RANKS = {2, 3, 4}
GG.cards = GG.cards or {}   -- [faction] = {turn = n, keys = {18 service keys}}

function GG.default_card(guild, rank)
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if s.guild == guild and s.rank == rank then return s.key end
    end
    return nil
end

function GG.cards_of(faction)
    local c = faction and GG.cards[faction]
    if c and c.keys and #c.keys == #GG.GUILDS * #GG.CARD_RANKS then return c.keys end
    local out = {}
    for gi = 1, #GG.GUILDS do
        for ri = 1, #GG.CARD_RANKS do
            out[#out + 1] = GG.default_card(GG.GUILDS[gi], GG.CARD_RANKS[ri])
        end
    end
    return out
end

function GG.guild_cards(faction, guild)
    local keys, out = GG.cards_of(faction), {}
    for gi = 1, #GG.GUILDS do
        if GG.GUILDS[gi] == guild then
            for ri = 1, #GG.CARD_RANKS do
                local s = GG.service(keys[(gi - 1) * #GG.CARD_RANKS + ri])
                if s then out[#out + 1] = s end
            end
        end
    end
    return out
end

function GG.on_card(faction, key)
    local keys = GG.cards_of(faction)
    for i = 1, #keys do
        if keys[i] == key then return true end
    end
    return false
end

function GG.cards_key(faction) return "derpy_gg_cards_" .. faction end

-- "<turn drawn>;<key>,<key>,...". Keys, not indices: a key survives the table growing.
function GG.save_cards(faction)
    local c = GG.cards[faction]
    if not c then return end
    cm:set_saved_value(GG.cards_key(faction),
                       tostring(c.turn or 0) .. ";" .. table.concat(c.keys, ","))
end

-- A key this build does not sell, or one saved in the wrong slot, reads as that slot's
-- default; an unreadable value is no cards at all, so the faction reads today's services
-- until its next turn draws.
function GG.load_cards(faction)
    GG.cards[faction] = nil
    local s = cm:get_saved_value(GG.cards_key(faction))
    if type(s) ~= "string" then return end
    local turn, list = string.match(s, "^(%d+);(.+)$")
    if not turn then return end
    local keys, i = {}, 0
    for k in string.gmatch(list, "[^,]+") do
        i = i + 1
        local g = GG.GUILDS[math.floor((i - 1) / #GG.CARD_RANKS) + 1]
        local rank = GG.CARD_RANKS[((i - 1) % #GG.CARD_RANKS) + 1]
        if not g then break end
        local svc = GG.service(k)
        keys[i] = (svc and svc.guild == g and svc.rank == rank) and k
                  or GG.default_card(g, rank)
    end
    if #keys ~= #GG.GUILDS * #GG.CARD_RANKS then return end
    GG.cards[faction] = {turn = tonumber(turn), keys = keys}
end
```

In `GG.can_buy`, directly after `if not s then return false, "unknown" end`, add:

```lua
    -- ON ONE OF THIS FACTION'S CARDS, or not for sale. The panel, GG.buy and GGAI.choose
    -- all come through here, so this one line is what makes all three honour the draw.
    if not GG.on_card(faction, service_key) then return false, "card" end
```

In `function GG.load(faction)`, add as its FIRST statement, before the saved-value read that returns early on an empty save:

```lua
    GG.load_cards(faction)
```

- [ ] **Step 4: The panel reads the faction's cards**

In `zzz_derpy_guilds_ui.lua` (CRLF), replace `GGUI.services_of`:

```lua
-- THE FACTION'S THREE CARDS for this guild (spec 2026-09-29 pools §4), never the whole
-- catalogue: a guild now holds more services than it has cards.
function GGUI.services_of(guild, faction)
    return GG.guild_cards(faction or GGUI.me(), guild)
end
```

Pass `faction` at the three callers (each has a `faction` local, checked 2026-09-29):
- `GGUI.refresh`: `local mine = GGUI.services_of(guild)` becomes `GGUI.services_of(guild, faction)`
- `GGUI.ready_in(faction, guild)`: `GGUI.services_of(guild)` becomes `GGUI.services_of(guild, faction)`
- `GGUI.on_buy_click`: `GGUI.services_of(GGUI.current_guild())` becomes `GGUI.services_of(GGUI.current_guild(), faction)`

- [ ] **Step 5: Run both harnesses**

Expected: both ok. The new gate refuses nothing on the default cards.

- [ ] **Step 6: Ledger**

`Task 2: complete (both harnesses ok; RED seen: cards_of nil)`.

---

### Task 3: The draw, the rotation and `rotate_turns`

**Files:**
- Modify: `zzz_derpy_guilds.lua` (cards section; `GG.TUNE_DEFAULTS`, `GG.TUNE_ORDER`, `GG.read_mct_or_defaults`; `gg_turn`)
- Modify: `zzz_derpy_guilds_ai.lua` (`GGAI.run_turn`)
- Modify: `script/mct/settings/derpy_great_guilds.lua` (CRLF)
- Modify: `tools/gen_great_guilds.py` (`check_presets`)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: Task 2's cards API, `GG.roll(n)`, `GG.turn_now()`, `GG.covered(faction)`.
- Produces:
  - `GG.pool_ok(faction, s) -> bool` (stage 2 widens it for `race` rows)
  - `GG.pool(faction, guild, rank) -> {service rows}`
  - `GG.rotation_turns() -> n`: `rotate_turns`, or 10 when it is unset or below 1
  - `GG.draw_cards(faction, turn)`
  - `GG.rotate_cards(faction, turn) -> bool`: true when it drew. Covered factions only.
  - `GG.EVERY_PRESET = {rotate_turns = true}`: numbers read from MCT under every preset
- Calls `GG.announce_rotation(faction)` on any redraw but the first. Task 4 defines it; until then the call is guarded with `if GG.announce_rotation then`.

- [ ] **Step 1: Failing tests**

Append to the bounty harness. Two temporary brass rank-2 rows give the draw something to choose between before Task 7 exists. The assertions read the pool, so they hold after Task 7 too:

```lua
-- ------------------------------------------------- SERVICE POOLS: the draw --
local function with_pool_rows(fn)
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_brass2_a", guild = "brass", rank = 2, cost = 50, cd = 8,
                          kind = "bundle", turns = 5}
    GG.SERVICES[n + 2] = {key = "t_brass2_b", guild = "brass", rank = 2, cost = 50, cd = 8,
                          kind = "bundle", turns = 5}
    local okf, err = pcall(fn)
    GG.SERVICES[n + 2], GG.SERVICES[n + 1] = nil, nil
    if not okf then error(err, 0) end
end

do
    with_pool_rows(function()
        W.reset()
        local p = GG.pool("me", "brass", 2)
        assert(#p >= 3 and p[1].key == "caravan_levy",
               "a card's pool is its guild and rank, today's service first")
        -- NEVER THE SAME TWICE: the stub rolls 1, so without the rule every draw would
        -- land on the pool's first row.
        GG.draw_cards("me", 10)
        local first = GG.cards_of("me")[1]
        assert(first ~= "caravan_levy", "the first draw leaves today's service")
        GG.draw_cards("me", 20)
        assert(GG.cards_of("me")[1] ~= first, "and the next leaves that one")
        assert(cm:get_saved_value(GG.cards_key("me")) ~= nil, "a draw is saved")
        -- A POOL OF ONE keeps its one; an EMPTY pool keeps what the card held.
        local real = GG.pool
        GG.pool = function(f, g, r)
            if g == "immortals" and r == 2 then return {GG.service("oathbound_draft")} end
            if g == "immortals" and r == 3 then return {} end
            return real(f, g, r)
        end
        GG.cards.me.keys[5] = "hire_immortals"
        GG.draw_cards("me", 30)
        GG.pool = real
        assert(GG.cards_of("me")[4] == "oathbound_draft", "a pool of one keeps its row")
        assert(GG.cards_of("me")[5] == "hire_immortals", "an empty pool keeps the card")
    end)
    ok("a draw never repeats a card when the pool has another")
end

do
    with_pool_rows(function()
        W.reset()
        GG.TUNE.rotate_turns = 10
        assert(GG.rotate_cards("me", 3) == true, "no cards: the first turn draws")
        assert(GG.rotate_cards("me", 9) == false, "same period: no redraw")
        assert(GG.rotate_cards("me", 10) == true, "turn 10 starts a new period")
        assert(GG.rotate_cards("me", 10) == false, "and draws once, whoever calls it again")
        assert(GG.rotate_cards("me", 37) == true, "a skipped period catches up once")
        assert(GG.rotate_cards("me", 39) == false, "not twice")
        GG.TUNE.rotate_turns = 0
        assert(GG.rotation_turns() == 10, "an unusable setting reads as 10")
    end)
    ok("the clock is the turn number, and each period draws once")
end

do
    -- REVIEW FOCUS 4: a service rotated off its card while a pick is open is refused.
    with_pool_rows(function()
        W.reset()
        GG.state.me = {}
        for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
        GG.cooldowns.me = {}
        GG.CULTURE_OF.me = GG.CHD_CULTURE
        assert(GG.can_buy("me", "caravan_levy"), "setup: today's card sells")
        GG.draw_cards("me", 10)                       -- caravan_levy leaves its card
        local okb, why = GG.buy("me", "caravan_levy", nil)
        assert(not okb and why == "card", "a rotated-off service is refused, got " .. tostring(why))
    end)
    ok("a purchase of a service that just rotated off is refused")
end

do
    -- REVIEW FOCUS 5: hostile services off - never drawn.
    W.reset()
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_khan4", guild = "khanate", rank = 4, cost = 400, cd = 16,
                          kind = "enemy_settlement", turns = 5, lead = true}
    GG.TUNE.hostile_services = false
    local off = GG.pool("me", "khanate", 4)
    GG.TUNE.hostile_services = true
    local on = GG.pool("me", "khanate", 4)
    GG.SERVICES[n + 1] = nil
    for _, s in ipairs(off) do
        assert(not s.hostile and s.kind ~= "enemy_settlement",
               s.key .. " is in a pool with hostile services off")
    end
    assert(#off < #on, "the switch takes something out of the pool")
    ok("hostile services off keeps them out of every pool")
end

do
    -- THE RIVALS' ROUND DRAWS TOO, so a rival whose own turn comes later in the round
    -- still buys from this period's cards. Never a human's: its own turn start does that.
    worldA()
    GG.TUNE.rotate_turns = 10
    TURN = 20
    local cs, st, sw = GGAI.court_step, GGAI.step, GG.snapshot_world
    GGAI.court_step = function() return false end
    GGAI.step = function() return false end
    GG.snapshot_world = function() end
    GGAI.run_turn()
    GGAI.court_step, GGAI.step, GG.snapshot_world = cs, st, sw
    assert(GG.cards.rival and GG.cards.rival.turn == 20, "the round drew the rival's cards")
    assert(GG.cards.me == nil, "and not the human's")
    ok("the rivals' round draws a rival's cards")
end

do
    -- Read on every preset, like the switches: it sits in the systems section, and a
    -- slider that only counts under Custom would look live and do nothing.
    local found = false
    for _, k in ipairs(GG.TUNE_ORDER) do if k == "rotate_turns" then found = true end end
    assert(found and GG.TUNE_DEFAULTS.rotate_turns == 10, "rotate_turns is a setting, default 10")
    assert(GG.EVERY_PRESET and GG.EVERY_PRESET.rotate_turns, "read on every preset")
    ok("rotate_turns is a setting read on every preset")
end
```

- [ ] **Step 2: Run and watch it fail**

Expected: exit 1, `attempt to call field 'pool' (a nil value)`.

- [ ] **Step 3: Implement the draw**

Append to the cards section, after `GG.load_cards`:

```lua
-- WHAT A CARD MAY DRAW. Stage 2 opens `race` rows; until then they are never drawn.
-- A `needs` check reads only world state every machine shares, and a throw is a no.
function GG.pool_ok(faction, s)
    if s.race ~= nil then return false end
    if (s.hostile or s.kind == "enemy_settlement")
       and GG.setting("hostile_services") == false then
        return false
    end
    if s.needs then
        local okn, yes = pcall(s.needs, faction)
        if not okn or yes ~= true then return false end
    end
    return true
end

function GG.pool(faction, guild, rank)
    local out = {}
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if s.guild == guild and s.rank == rank and GG.pool_ok(faction, s) then
            out[#out + 1] = s
        end
    end
    return out
end

function GG.rotation_turns()
    local n = tonumber(GG.setting("rotate_turns")) or 10
    if n < 1 then n = 10 end
    return math.floor(n)
end

-- EVERY CARD IN ORDER, one GG.roll each - the order is fixed, so every machine rolls the
-- same numbers for the same cards. Never the card's last service when the pool has
-- another. An empty pool (every row refused) keeps what the card held.
function GG.draw_cards(faction, turn)
    local old, keys, i = GG.cards_of(faction), {}, 0
    for gi = 1, #GG.GUILDS do
        for ri = 1, #GG.CARD_RANKS do
            i = i + 1
            local pool = GG.pool(faction, GG.GUILDS[gi], GG.CARD_RANKS[ri])
            local pick = old[i]
            if #pool > 0 then
                local fresh = {}
                for j = 1, #pool do
                    if pool[j].key ~= old[i] then fresh[#fresh + 1] = pool[j] end
                end
                if #fresh == 0 then fresh = pool end
                pick = fresh[GG.roll(#fresh)].key
            end
            keys[i] = pick
        end
    end
    GG.cards[faction] = {turn = turn, keys = keys}
    GG.save_cards(faction)
end

-- ONCE PER PERIOD, whoever asks: gg_turn and the rivals' round both call this, and the
-- second call in a period does nothing. A period missed (a save loaded late, a faction
-- that did not exist) catches up once. Covered factions only - the rivals' round walks
-- every faction in the world, and a card set is a saved value. No notice on the first
-- draw.
function GG.rotate_cards(faction, turn)
    if not GG.covered(faction) then return false end
    local c = GG.cards[faction]
    local n = GG.rotation_turns()
    if c and c.turn and math.floor(turn / n) <= math.floor(c.turn / n) then return false end
    local first = (c == nil)
    GG.draw_cards(faction, turn)
    if not first and GG.announce_rotation then GG.announce_rotation(faction) end
    return true
end
```

- [ ] **Step 4: The setting**

- In `GG.TUNE_DEFAULTS`, after `ai_bounties = true,`, add `rotate_turns = 10,`.
- In `GG.TUNE_ORDER`, after `"ai_bounties",`, add `"rotate_turns",` (append only).

Above `function GG.read_mct_or_defaults()` add:

```lua
-- NUMBERS READ UNDER EVERY PRESET. The presets own the tuning; these are systems, sit in
-- the systems section, and would otherwise look editable and be ignored off Custom.
GG.EVERY_PRESET = {rotate_turns = true}
```

In `GG.read_mct_or_defaults`'s switches loop (the first `for i = 1, #GG.TUNE_ORDER do`), change

```lua
            if type(GG.TUNE_DEFAULTS[key]) == "boolean" then
```

to

```lua
            if type(GG.TUNE_DEFAULTS[key]) == "boolean" or GG.EVERY_PRESET[key] then
```

and inside that branch change `if type(val) == "boolean" then t[key] = val end` to

```lua
                    if type(val) == type(GG.TUNE_DEFAULTS[key]) then t[key] = val end
```

`GG.apply_preset` copies only the keys a preset names, and no preset names `rotate_turns`, so the value read here survives every preset.

In `script/mct/settings/derpy_great_guilds.lua` (CRLF, Edit tool), after the `o_aib` block add:

```lua
local o_rot = m:add_new_option("rotate_turns", "slider")
o_rot:set_text("Services change every")
o_rot:set_tooltip_text("The guilds change the services they offer every this many turns. "
    .. "Each guild still offers three at a time, drawn from a larger set.")
o_rot:slider_set_min_max(5, 30)
o_rot:slider_set_step_size(1)
o_rot:set_default_value(10)
o_rot:set_assigned_section("systems")
if IN_CAMPAIGN then o_rot:set_locked(true, LOCK_REASON) end
```

Do NOT add it to `PRESET_OWNED`: no preset sets it.

In `tools/gen_great_guilds.py` `check_presets`, directly after the line `numeric = [k for k in keys if k not in bools]`, add:

```python
    # READ ON EVERY PRESET (GG.EVERY_PRESET): a system number, like the switches. Owned by
    # no preset, so it must not be in PRESET_OWNED - that would grey it for nothing.
    every = re.search(r"^GG\.EVERY_PRESET = \{(.*?)\}", lua, re.M)
    every_keys = set(re.findall(r"([a-z_0-9]+)\s*=\s*true", every.group(1))) if every else set()
    numeric = [k for k in numeric if k not in every_keys]
```

and directly before its final `return out`:

```python
    for k in sorted(every_keys & listed):
        out.append("%s is read on every preset and PRESET_OWNED greys it - no preset "
                   "sets it, so the player could never change it" % k)
```

- [ ] **Step 5: Draw in the turn handlers**

In `gg_turn` (`zzz_derpy_guilds.lua`), directly after `GG.tick_cooldowns(name)`:

```lua
        -- THE CARDS, once a period (spec 2026-09-29 pools §4). Before income and grants,
        -- so a faction reads this period's cards for everything it does this turn.
        GG.rotate_cards(name, GG.turn_now())
```

In `GGAI.run_turn`'s per-faction loop (`zzz_derpy_guilds_ai.lua`, CRLF), directly after `GG.load(name)`:

```lua
                -- THIS PERIOD'S CARDS before anything is bought: this sweep runs at the
                -- round's first turn start, before this faction's own gg_turn.
                GG.rotate_cards(name, turn)
```

- [ ] **Step 6: Run everything and prove the preset check**

Run both harnesses, then `py tools/gen_great_guilds.py --check`.
Expected: both harnesses ok; `--check` exit 0.

Prove the new `check_presets` half:
1. Add `"rotate_turns",` to `PRESET_OWNED` in the MCT file.
2. Run `--check`. Expected: `rotate_turns is read on every preset and PRESET_OWNED greys it`.
3. Restore the file byte for byte.

If a main-harness test pins the length of `GG.TUNE_ORDER` or the packed settings, update the pinned number and ledger it: a new setting was meant to be appended.

- [ ] **Step 7: Ledger**

`Task 3: complete (both harnesses ok; gen --check 0; RED seen: pool nil; preset check proven)`.

---

### Task 4: The rotation notice, the Log line and the countdown

**Files:**
- Modify: `zzz_derpy_guilds.lua` (`GG.FEED_INDEX_ROTATION`, `GG.announce_rotation`)
- Modify: `zzz_derpy_guilds_ui.lua` (`GGUI.log_text`, `GGUI.LOG_FILTERS.mine`, footer)
- Modify: `tools/gen_great_guilds.py` (feed record 5006 and its four table lists, loc; `check_feed_mirror`; selftest)
- Test: `tools/_guilds_bounty_harness.lua`, `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.rotate_cards` (Task 3), `GG.log_add`, `GG.feed`, `GG.tag`, `GG.is_human`, `GGUI.fill`.
- Produces:
  - `GG.FEED_INDEX_ROTATION = 5006`
  - Log kind `rotation` (no guild, empty a and b)
  - UI loc keys `log_rotation` and `next_services`

- [ ] **Step 1: Failing tests**

In the bounty harness `cm` stub, after `show_message_event_located`, add:

```lua
    show_message_event = function(_, f, t, p, s, persistent, idx)
        rec("message", f, t, p, s, persistent, idx)
    end,
```

Append:

```lua
-- ------------------------------------------------- SERVICE POOLS: the notice --
do
    W.reset()
    GG.TUNE.rotate_turns = 10
    GG.rotate_cards("me", 1)                          -- first draw: silent
    assert(not CALLS.message and #GG.log_entries("me") == 0, "the first draw says nothing")
    GG.rotate_cards("me", 10)
    assert(CALLS.message and #CALLS.message == 1, "a rotation raises one message")
    local c = CALLS.message[1]
    assert(c[1] == "me" and c[2] == "message_event_text_text_derpy_gg_rotation_title"
           and c[5] == true and c[6] == GG.FEED_INDEX_ROTATION,
           "to me, persistent, at the rotation index")
    assert(GG.log_entries("me")[1].kind == "rotation", "and one Log line")
    -- Not for a rival, and not with notices off.
    W.faction("ai1", {})
    GG.rotate_cards("ai1", 1)
    GG.rotate_cards("ai1", 10)
    assert(#CALLS.message == 1, "a rival's rotation is silent")
    GG.TUNE.guild_notices = false
    GG.rotate_cards("me", 20)
    assert(#CALLS.message == 1, "notices off: no message")
    assert(#GG.log_entries("me") == 2, "but the Log still records it")
    ok("a rotation tells a human once, and never a rival")
end
```

In `tools/_guilds_harness.lua`, a new IIFE before `print("harness ok")`:

```lua
-- THE ROTATION LOG LINE (2026-09-29 pools): no guild, not bad news, under Mine.
;(function()
    local line, bad = GGUI.log_text({turn = 12, kind = "rotation", guild = "", a = "", b = ""})
    assert(type(line) == "string" and line:find(GGUI.loc("log_rotation"), 1, true),
           "the rotation Log line says so, got " .. tostring(line))
    assert(not bad, "a rotation is not bad news")
    assert(GGUI.LOG_FILTERS.mine.rotation, "it is under the Mine filter")
end)()
```

- [ ] **Step 2: Run and watch both fail**

Expected: the bounty harness fails `a rotation raises one message`; the main harness fails `the rotation Log line says so, got nil`.

- [ ] **Step 3: The Lua**

In `zzz_derpy_guilds.lua`, after the cards section:

```lua
-- 5006: the guilds changed their services. Minted by tools/gen_great_guilds.py with its
-- rows; check_feed_mirror pins this number. A scripted_persistent_event record with
-- instant_open false, so it waits in the feed rather than opening a panel every period.
GG.FEED_INDEX_ROTATION = 5006

function GG.announce_rotation(faction)
    if not GG.is_human(faction) then return end
    GG.log_add(faction, "rotation", "", "", "")
    if GG.setting("guild_notices") == false then return end
    local k = "message_event_text_text_derpy_gg_rotation" .. GG.tag(faction)
    pcall(function()
        -- true: the record is a scripted_persistent_event and the flag must agree.
        cm:show_message_event(faction, k .. "_title", k .. "_primary", k .. "_secondary",
                              true, GG.feed(faction, GG.FEED_INDEX_ROTATION))
    end)
end
```

In `zzz_derpy_guilds_ui.lua` `GGUI.log_text`, add this branch directly before the final `else return nil`:

```lua
    elseif k == "rotation" then
        -- NO GUILD: every guild's services changed at once, so no guild prefix.
        return GGUI.loc("log_turn") .. " " .. e.turn .. "   " .. GGUI.loc("log_rotation")
               .. ".", false
```

In `GGUI.LOG_FILTERS`, change `mine   = {buy = true, rank = true, lead_won = true},` to

```lua
    mine   = {buy = true, rank = true, lead_won = true, rotation = true},
```

The line goes under Mine, not a fifth button: a new filter is a new panel component and a layout pass, and Mine already holds the player's own guild events.

Footer: replace

```lua
    set_named_text("gg_footer", GGUI.loc("favour") .. ": " .. fav)
```

with

```lua
    -- THE COUNTDOWN (spec §9), here because the footer carries one short number on a
    -- 750px line; the rank and earned lines are full.
    local every = GG.rotation_turns()
    set_named_text("gg_footer", GGUI.loc("favour") .. ": " .. fav .. "   "
                   .. GGUI.fill(GGUI.loc("next_services"), every - GG.turn_now() % every))
```

- [ ] **Step 4: The generator**

In `tools/gen_great_guilds.py`, after `FEED_INDEX_HUNTED = 5005`:

```python
# A SIXTH RECORD: the guilds changed the services they offer (2026-09-29 pools spec §4).
# Persistent like the promotion, but instant_open false: it arrives every N turns and
# should wait in the feed, not open a panel.
FEED_GROUP_ROTATION = "derpy_gg_event_feed_rotation"
FEED_INDEX_ROTATION = 5006
```

After the `FEED_ROW_HUNTED = ...` statement:

```python
FEED_ROW_ROTATION = dict(FEED_ROW, group=FEED_GROUP_ROTATION, image="chd/messenger",
                         instant_open="false")
```

In `_build_one`'s return dict, append one rotation entry to each of the four lists, after the hunted one:
- `campaign_groups`: `{"id": FEED_GROUP_ROTATION}`
- `campaign_group_members`: `{"group": FEED_GROUP_ROTATION, "id": FEED_GROUP_ROTATION, "priority": "0"}`
- `campaign_group_member_criteria_values`: `{"member": FEED_GROUP_ROTATION, "value": str(FEED_INDEX_ROTATION)}`
- `event_feed_message_events`: `dict(FEED_ROW_ROTATION)`

Directly after the three `message_event_text_text_derpy_gg_hunted_*` loc appends:

```python
    for part, text in (("title", "New Services"),
                       ("primary", "The guilds have changed what they offer."),
                       ("secondary", "Each guild's three services have been drawn again. "
                                     "Open the Guilds panel to see them.")):
        loc.append({"key": "message_event_text_text_derpy_gg_rotation_" + part,
                    "text": text, "tooltip": "false"})
```

In the UI loc tuples, after `("log_hunt_void", "withdrew its price on"),`:

```python
                      # SERVICE POOLS (2026-09-29). No full stop: log_text adds it.
                      ("log_rotation", "The guilds changed the services they offer"),
                      ("next_services", "New services in %n turns"),
```

In `check_feed_mirror`:
- Add `("GG.FEED_INDEX_ROTATION", FEED_INDEX_ROTATION)` to the tuple list after the HUNTED entry.
- After the hunted loc loop, add:

```python
    for tag in FLAVOURS:
        for part in ("title", "primary", "secondary"):
            k = "message_event_text_text_derpy_gg_rotation%s_%s" % (tag, part)
            if k not in shipped:
                out.append("GG.announce_rotation builds %s and no loc row ships it" % k)
```

In `selftest()`, change `assert len(full["event_feed_message_events"]) == 5 * n` to `== 6 * n`. After the `assert idx[FEED_GROUP_HUNTED] == "5005" ...` line, add:

```python
    rot = [r for r in full["event_feed_message_events"]
           if r["group"].startswith(FEED_GROUP_ROTATION)]
    assert len(rot) == n and all(r["event"] == "scripted_persistent_event"
                                 and r["instant_open"] == "false" for r in rot), rot
    assert idx[FEED_GROUP_ROTATION] == "5006" and idx[FEED_GROUP_ROTATION + "_emp"] == "5016"
```

- [ ] **Step 5: Run everything and prove the mirror**

Run:
- both harnesses;
- `py tools/gen_great_guilds.py --check`, then `--selftest`, then `--write`;
- `py tools/gen_guilds_ui.py --check`.

Expected: both harnesses ok; `--check` 0; `selftest ok`; `--write` ok; UI check 0.

Prove the new mirror check:
1. Change `GG.FEED_INDEX_ROTATION = 5006` to `5007`.
2. Run `--check`. Expected: `GG.FEED_INDEX_ROTATION is 5007 in the Lua and 5006 here`.
3. Restore byte for byte.
4. Re-run `--write`, because a mutated `--write` leaves generated files mutated.

- [ ] **Step 6: Ledger**

- `Task 4: complete (...)`
- `Task 4: Ruling: rotation Log line under the Mine filter, not a new filter button - a fifth button is a new component and a layout pass - cost if wrong: one filter button later`.

---

### Task 5: The four new kinds, their targets and the compound services

**Files:**
- Modify: `zzz_derpy_guilds.lua` (`GG.payload`, `GG.needs_target`, new `GG.target_ok`, `GG.buy`, `GG.target_from_wire`, `GG.can_buy`'s hostile line)
- Modify: `zzz_derpy_guilds_ui.lua` (`GGUI.target_hint`, `GGUI.pick_target`, `GGUI.needs_confirm`)
- Modify: `zzz_derpy_guilds_ai.lua` (`GGAI.pick_building` refactor, new `GGAI.own_regions` and `GGAI.pick_own_region`, `GGAI.pick_target`)
- Modify: `script/mct/settings/derpy_great_guilds.lua` (`hostile_services` tooltip)
- Modify: `tools/gen_great_guilds.py` (three hint loc keys)
- Test: `tools/_guilds_bounty_harness.lua`, `tools/_guilds_harness.lua` (fixtures)

**Interfaces:**
- Produces four new kinds, each with the target it takes:

  | Kind | Target |
  |---|---|
  | `army` | a character cqi: the army's general, as Hire takes |
  | `settlement` | a region key of the buyer's own |
  | `enemy_settlement` | a region key owned by a faction at war with the buyer |
  | `ranks` | a character cqi of the buyer's own |

- Produces two flags:
  - `with_bundle = true`: a `gold` or `research` service that also applies its bundle to the buyer;
  - `heal = true`: an `army` service that also heals the army.
- Produces `GG.target_ok(faction, s, target) -> bool`. `GG.buy` refuses `"target"` when it is false. `unit` is checked like `army`.
- Produces UI loc keys `needs_char`, `needs_settlement_own`, `needs_region_enemy`.

- [ ] **Step 0: Read the doc entries**

Run `py tools/check_lua_api.py --explain <member>` for each of:
- `apply_effect_bundle_to_force`
- `apply_effect_bundle_to_region`
- `heal_military_force`
- `add_agent_experience`
- `get_character_by_cqi`

Expected, per spec §5:
- the force call takes a NUMBER force cqi and a turn count;
- the region call takes a region key string and turns;
- heal takes a military force interface;
- `add_agent_experience(lookup, n, true)` adds n ranks.

If any entry disagrees, stop and ledger a ruling before Step 4.

- [ ] **Step 1: Harness stubs**

In the bounty harness `cm` stub:
- Replace `apply_effect_bundle = function() end,` with a recorder.
- Add the new calls.

```lua
    apply_effect_bundle = function(_, k, f, turns) rec("bundle", k, f, turns) end,
    get_character_by_cqi = function(_, cqi)
        if not C[tostring(cqi)] then return NULL() end
        return W.ci(cqi)
    end,
    apply_effect_bundle_to_force = function(_, k, cqi, turns) rec("force_bundle", k, cqi, turns) end,
    apply_effect_bundle_to_region = function(_, k, r, turns) rec("region_bundle", k, r, turns) end,
    heal_military_force = function(_, mf) rec("heal", mf:command_queue_index()) end,
    add_agent_experience = function(_, lookup, n, ranks) rec("ranks", lookup, n, ranks) end,
```

In `W.ci`, change the `military_force` return to carry a force cqi and the garrison flag:

```lua
            return {is_null_interface = function() return false end,
                    command_queue_index = function() return 1000 + cqi end,
                    is_armed_citizenry = function() return false end,
                    unit_list = function() return {num_items = function() return n end} end}
```

In `tools/_guilds_harness.lua`, replace the `CHAR_FORCE` stub block (from `CHAR_FORCE = {}` through the end of `cm.get_character_by_cqi = function ... end`) with:

```lua
CHAR_FORCE = {}
-- [character cqi] = the faction that owns them. GG.target_ok (2026-09-29 pools) refuses a
-- friendly service aimed at anyone else's character, so a fixture that sells one names
-- its owner here.
CHAR_OWNER = {}
cm.get_character_by_cqi = function(_, cqi)
    local force = CHAR_FORCE[tostring(cqi)]
    if force == nil then return NULL() end
    return {is_null_interface = function() return false end,
            faction = function()
                return {is_null_interface = function() return false end,
                        name = function() return CHAR_OWNER[tostring(cqi)] end}
            end,
            has_military_force = function() return force ~= false end,
            military_force = function()
                if force == false then return NULL() end
                return {is_null_interface = function() return false end,
                        command_queue_index = function() return force end,
                        is_armed_citizenry = function() return false end}
            end}
end
```

- [ ] **Step 2: Failing tests**

Append to the bounty harness:

```lua
-- ------------------------------------------- SERVICE POOLS: the new kinds --
local function kinds_world()
    worldA()                                   -- me at war with foe; 10 is my lord
    GG.CULTURE_OF.me = GG.CHD_CULTURE
    W.char(71, {faction = "me", general = true, x = 0, y = 0})
    W.char(72, {faction = "me", x = 0, y = 0})             -- a hero of mine
    F.me.lords, F.me.heroes = {10, 71}, {72}
end

do
    kinds_world()
    GG.payload("me", {key = "t_army", guild = "immortals", kind = "army", turns = 3,
                      heal = true}, 71)
    assert(CALLS.force_bundle[1][1] == "derpy_gg_svc_t_army"
           and CALLS.force_bundle[1][2] == 1071 and CALLS.force_bundle[1][3] == 3,
           "an army bundle lands on the general's FORCE cqi")
    assert(CALLS.heal and CALLS.heal[1][1] == 1071, "heal = true heals that force")
    GG.payload("me", {key = "t_set", guild = "overseers", kind = "settlement", turns = 8},
               "home")
    assert(CALLS.region_bundle[1][2] == "home" and CALLS.region_bundle[1][3] == 8,
           "a settlement bundle lands on the region")
    GG.payload("me", {key = "t_rk", guild = "khanate", kind = "ranks", value = 3}, 72)
    assert(CALLS.ranks[1][1] == "character_cqi:72" and CALLS.ranks[1][2] == 3
           and CALLS.ranks[1][3] == true, "ranks: lookup string, n, and true for ranks")
    GG.payload("me", {key = "t_loan", guild = "brass", kind = "gold", value = 6000,
                      turns = 10, with_bundle = true}, nil)
    assert(CALLS.treasury[#CALLS.treasury][2] == 6000, "the loan pays")
    local found = false
    for _, c in ipairs(CALLS.bundle or {}) do
        if c[1] == "derpy_gg_svc_t_loan" and c[2] == "me" and c[3] == 10 then found = true end
    end
    assert(found, "and applies its bundle to the buyer")
    ok("each new kind calls the game the way CA documents it")
end

do
    -- REVIEW FOCUS 2: a buff never lands on an enemy.
    kinds_world()
    local army = {key = "t_army", guild = "immortals", kind = "army", turns = 3}
    assert(GG.target_ok("me", army, 71), "my general's army is a target")
    assert(not GG.target_ok("me", army, 30), "an enemy general's army is not")
    assert(not GG.target_ok("me", army, 72), "a hero has no army")
    local rk = {key = "t_rk", guild = "khanate", kind = "ranks", value = 3}
    assert(GG.target_ok("me", rk, 72) and not GG.target_ok("me", rk, 30),
           "ranks go to my own characters only")
    local settle = {key = "t_set", guild = "overseers", kind = "settlement", turns = 8}
    assert(GG.target_ok("me", settle, "home") and not GG.target_ok("me", settle, "foe_near"),
           "a settlement service takes my own settlement only")
    local hostile = {key = "t_en", guild = "khanate", kind = "enemy_settlement", turns = 5}
    assert(GG.target_ok("me", hostile, "foe_near"), "an enemy settlement is a target")
    assert(not GG.target_ok("me", hostile, "home"), "my own is not")
    assert(not GG.target_ok("me", hostile, "friend_town"), "a faction I am not at war with is not")
    assert(not GG.target_ok("me", GG.service("hire_immortals"), 30),
           "Hire never gives an enemy general a regiment")
    assert(not GG.target_ok("me", army, nil), "nothing selected is no target")
    ok("a friendly service never targets an enemy, a hostile one only an enemy")
end

do
    kinds_world()
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
    GG.cooldowns.me = {}
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_army", guild = "immortals", rank = 2, cost = 50, cd = 8,
                          kind = "army", turns = 3}
    GG.cards.me = {turn = 1, keys = GG.cards_of("me")}
    GG.cards.me.keys[4] = "t_army"
    local okb, why = GG.buy("me", "t_army", 30)
    local okc = GG.buy("me", "t_army", 71)
    GG.SERVICES[n + 1] = nil
    assert(not okb and why == "target", "the till refuses a bad target, got " .. tostring(why))
    assert(okc, "and sells on a good one")
    -- The hostile switch covers enemy-settlement services at the till too.
    GG.TUNE.hostile_services = false
    GG.SERVICES[n + 1] = {key = "t_en", guild = "khanate", rank = 3, cost = 150, cd = 12,
                          kind = "enemy_settlement", turns = 5}
    GG.cards.me.keys[11] = "t_en"                    -- the khanate rank-3 slot
    local okh, whyh = GG.can_buy("me", "t_en")
    GG.SERVICES[n + 1] = nil
    GG.TUNE.hostile_services = true
    assert(not okh and whyh == "disabled",
           "hostile services off refuses an enemy-settlement service, got " .. tostring(whyh))
    ok("the till checks the target, and the hostile switch covers enemy settlements")
end
```

- [ ] **Step 3: Run and watch it fail**

Expected: exit 1 in the first new block. `CALLS.force_bundle` is nil because `GG.payload` has no `army` branch.

- [ ] **Step 4: Implement the model**

In `GG.payload`, the `elseif s.kind == "pooled" then ... end` chain ends with `end` before the function's closing `end`. Insert these branches before that chain-closing `end`, then add the `with_bundle` block after it:

```lua
    elseif s.kind == "army" then
        -- A CHARACTER cqi on the wire (the army's general, as Hire takes), turned into
        -- the FORCE cqi apply_effect_bundle_to_force documents.
        local okf, force = pcall(function()
            local c = cm:get_character_by_cqi(target)
            if not c or c:is_null_interface() or not c:has_military_force() then return nil end
            return c:military_force()
        end)
        if okf and force then
            cm:apply_effect_bundle_to_force("derpy_gg_svc_" .. s.key .. GG.tag(faction),
                                            force:command_queue_index(), s.turns)
            if s.heal then cm:heal_military_force(force) end
        end

    elseif s.kind == "settlement" or s.kind == "enemy_settlement" then
        -- The BUYER's tag on an enemy's region too, as The Khan's Price does: the victim
        -- reads who did it.
        if target then
            cm:apply_effect_bundle_to_region("derpy_gg_svc_" .. s.key .. GG.tag(faction),
                                             target, s.turns)
        end

    elseif s.kind == "ranks" then
        -- The third argument makes the number RANKS, not experience points
        -- (lib_campaign_manager.lua:7964).
        if target then cm:add_agent_experience(cm:char_lookup_str(target), s.value, true) end
    end
    -- A GOLD OR RESEARCH SERVICE MAY CARRY A BUNDLE TOO (the Guild Loan, The Great Work).
    if s.with_bundle and (s.kind == "gold" or s.kind == "research") then
        cm:apply_effect_bundle("derpy_gg_svc_" .. s.key .. GG.tag(faction), faction, s.turns)
    end
```

`GG.needs_target`, replace its `return` line:

```lua
    return s.kind == "unit" or s.kind == "research" or s.kind == "shroud"
        or s.kind == "building" or s.kind == "army" or s.kind == "settlement"
        or s.kind == "enemy_settlement" or s.kind == "ranks"
```

After `GG.needs_target`, add:

```lua
-- THE RIGHT KIND OF TARGET, OWNED BY THE RIGHT SIDE. A buff aimed at a selected enemy
-- army would land on the enemy; the map selection is whatever the player last clicked.
-- Reads world state only, so every machine answers alike. A read that throws is a no.
-- Kinds it does not judge (research, shroud, building, a hostile bundle) pass on any
-- target; nil is never a target.
function GG.target_ok(faction, s, target)
    if not s or target == nil then return false end
    local okr, yes = pcall(function()
        if s.kind == "army" or s.kind == "unit" or s.kind == "ranks" then
            local c = cm:get_character_by_cqi(target)
            if not c or c:is_null_interface() then return false end
            if c:faction():name() ~= faction then return false end
            if s.kind == "ranks" then return true end
            if not c:has_military_force() then return false end
            return not c:military_force():is_armed_citizenry()
        end
        if s.kind == "settlement" or s.kind == "enemy_settlement" then
            local r = cm:get_region(target)
            if not r or r:is_null_interface() then return false end
            local owner = r:owning_faction()
            if not owner or owner:is_null_interface() then return false end
            if s.kind == "settlement" then return owner:name() == faction end
            return cm:get_faction(faction):at_war_with(owner)
        end
        return true
    end)
    return okr and yes == true
end
```

`GG.buy`: replace

```lua
    -- No target, no sale.
    if GG.needs_target(s) and not target then return false, "target" end
```

with

```lua
    -- No target, or the wrong one, no sale.
    if GG.needs_target(s) and not GG.target_ok(faction, s, target) then return false, "target" end
```

`GG.can_buy`: replace

```lua
    if s.hostile and GG.setting("hostile_services") == false then
```

with

```lua
    if (s.hostile or s.kind == "enemy_settlement")
       and GG.setting("hostile_services") == false then
```

`GG.target_from_wire`: replace `if s.kind == "unit" then return tonumber(t) end` with

```lua
    if s.kind == "unit" or s.kind == "army" or s.kind == "ranks" then return tonumber(t) end
```

- [ ] **Step 5: The panel, the rivals and the switch's text**

UI (`zzz_derpy_guilds_ui.lua`, CRLF), `GGUI.target_hint`:

```lua
function GGUI.target_hint(s)
    if not s then return "needs_target" end
    if s.hostile then return "needs_target" end
    if s.kind == "unit" or s.kind == "army" then return "needs_army" end
    if s.kind == "ranks" then return "needs_char" end
    if s.kind == "settlement" then return "needs_settlement_own" end
    if s.kind == "enemy_settlement" then return "needs_region_enemy" end
    if s.kind == "shroud" then return "needs_region_any" end
    if s.kind == "building" then return "needs_region_own" end
    if s.kind == "research" then return "needs_research" end
    return "needs_target"
end
```

In `GGUI.pick_target`, replace `if s.kind == "unit" then return GGUI.selected_force_cqi() end` with:

```lua
    -- A SELECTION THAT FAILS GG.target_ok IS NO SELECTION: the card keeps waiting, and a
    -- friendly service can never be pointed at an enemy army or town.
    if s.kind == "unit" or s.kind == "army" or s.kind == "ranks" then
        local c = GGUI.selected_force_cqi()
        if c and GG.target_ok(faction, s, c) then return c end
        return nil
    end
    if s.kind == "settlement" or s.kind == "enemy_settlement" then
        local r = GGUI.selected_region()
        if r and GG.target_ok(faction, s, r) then return r end
        return nil
    end
```

`GGUI.needs_confirm`: after `if s.hostile then return true end` add

```lua
    if s.kind == "enemy_settlement" then return true end
```

AI (`zzz_derpy_guilds_ai.lua`, CRLF): replace `GGAI.pick_building` with the region walk pulled out, and add the settlement picker:

```lua
-- THE AI'S OWN REGION KEYS, for the two services that take one of its settlements.
function GGAI.own_regions(faction)
    if GGAI.TEST_REGIONS then return GGAI.TEST_REGIONS end
    local keys = {}
    pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then return end
        local rl = f:region_list()
        for i = 0, rl:num_items() - 1 do keys[#keys + 1] = rl:item_at(i):name() end
    end)
    return keys
end

-- THE FIRST UPGRADE IN ANY OF THE AI'S OWN REGIONS, for Raise the Ziggurat, through the
-- same GG.upgrade_target the panel uses.
function GGAI.pick_building(faction)
    local keys = GGAI.own_regions(faction)
    for i = 1, #keys do
        local t = GG.upgrade_target(faction, keys[i])
        if t then return t end
    end
    return nil
end

-- ONE OF THE AI'S OWN REGIONS, rolled, for a settlement service.
function GGAI.pick_own_region(faction)
    local keys = GGAI.own_regions(faction)
    if #keys == 0 then return nil end
    return keys[GGAI.roll(#keys)]
end
```

In `GGAI.pick_target`, after the `unit` line add:

```lua
    if s.kind == "army" or s.kind == "ranks" then return GGAI.pick_army(faction) end
    if s.kind == "settlement" then return GGAI.pick_own_region(faction) end
    if s.kind == "enemy_settlement" then return GGAI.pick_enemy_region(faction) end
```

MCT file (CRLF), the `o_hostile` tooltip becomes:

```lua
o_hostile:set_tooltip_text("Services aimed at another faction: The Khan's Price, and the "
    .. "services that strike an enemy settlement. Off, no faction may buy them - you included.")
```

Generator UI loc tuples, after the `needs_army` entry:

```python
                      ("needs_char", "Select one of your own lords or heroes on the "
                                     "campaign map first."),
                      ("needs_settlement_own", "Select one of your OWN settlements on the "
                                               "campaign map first."),
                      ("needs_region_enemy", "Select a settlement of a faction you are at "
                                             "war with on the campaign map first."),
```

- [ ] **Step 6: The main harness fixtures that now need an owned target**

`GG.buy` and `GGUI.pick_target` now refuse a character nobody owns. Give each fixture its owner:

1. Before `GG.buy("cr_target", "hire_immortals", 42)`, add:

   ```lua
   CHAR_FORCE["42"], CHAR_OWNER["42"] = 4200, "cr_target"
   ```

2. Before `assert(GGUI.pick_target(GG.service("hire_immortals"), "cr_sel") == 4242,`, add:

   ```lua
       CHAR_FORCE["4242"], CHAR_OWNER["4242"] = 1, "cr_sel"
   ```

3. In the needs-target IIFE (`local F = "cr_no_target"`), replace

   ```lua
                   local sold2 = GG.buy(F, s.key, "cr_some_target")
   ```

   with

   ```lua
                   -- A TARGET THE TILL ACCEPTS for this kind: GG.target_ok refuses a
                   -- character that is not the buyer's (2026-09-29 pools).
                   local good = "cr_some_target"
                   if s.kind == "unit" or s.kind == "army" or s.kind == "ranks" then
                       CHAR_FORCE["5150"], CHAR_OWNER["5150"] = 5151, F
                       good = 5150
                   end
                   local sold2 = GG.buy(F, s.key, good)
   ```

Another main-harness test may fail on `"target"` because its character has a `CHAR_FORCE` entry and no owner. Fix it the same way, by adding `CHAR_OWNER["<cqi>"] = "<buyer>"` beside that entry, and ledger each site. The fixture was wrong: the sale was never meant to reach an unowned character.

- [ ] **Step 7: Run everything**

Run:
- both harnesses;
- `py tools/gen_great_guilds.py --check` and `--write`;
- `py tools/gen_guilds_ui.py --check`;
- `luac -p` on the model, AI and UI files;
- `py tools/check_lua_api.py` on those three files.

Expected: all green; `check_lua_api` reports 0 findings on the guild files.

- [ ] **Step 8: Ledger**

- `Task 5: complete (...)`
- `Task 5: Ruling: Hire (unit) is target-checked like army - an enemy general selected could be handed a regiment before - cost if wrong: none, the old behaviour was the fault`
- One ruling line per extra main-harness fixture given an owner in Step 6.

---

### Task 6: The generator carries a service's own effects

**Files:**
- Modify: `tools/gen_great_guilds.py` (new `bundle_target_of`, `inverted`, `service_text`; `_build_one`'s service loop; `check()`; selftest)

**Interfaces:**
- Consumes: SERVICES rows that may carry:
  - `effects: [(effect_key, scope, value), ...]`
  - `text`: a `str.format` template with `{v0}`, `{v1}`, `{turns}` and `{value}`
  - `drawback: True`
- Produces:
  - `service_text(s) -> str`
  - `bundle_target_of(s) -> "force" | "region" | "faction"`
  - `inverted(s) -> bool`: true for `hostile`, `kind == "enemy_settlement"`, or `drawback`
  - A service with `effects` emits one bundle `derpy_gg_svc_<key>` with one junction row per effect and its `bundle_target` set by kind. `check()` validates every effect pair, magnitude and sign.

- [ ] **Step 1: Failing selftest**

At the end of `selftest()`, before its closing `print("selftest ok: ...")`, add:

```python
    # PER-SERVICE EFFECTS (2026-09-29 pools): a probe row through the real emitter and the
    # real check(), then removed.
    probe = {"key": "t_probe", "guild": "immortals", "rank": 2, "cost": 50, "cd": 8,
             "kind": "army", "turns": 3, "name": "Probe",
             "effects": [("wh_main_effect_force_all_campaign_movement_range",
                          "force_to_force_own", 20)],
             "text": "{v0:+d}% campaign movement for the army you select, for {turns} turns."}
    SERVICES.append(probe)
    for F in FLAVOURS.values():
        F["services"]["t_probe"] = "Probe"
    try:
        t = _build_one("")
        b = [r for r in t["effect_bundles"] if r["key"] == "derpy_gg_svc_t_probe"]
        assert len(b) == 1 and b[0]["bundle_target"] == "force", b
        j = [r for r in t["effect_bundles_to_effects_junctions"]
             if r["effect_bundle_key"] == "derpy_gg_svc_t_probe"]
        assert [(r["effect_key"], r["effect_scope"], r["value"]) for r in j] == [
            ("wh_main_effect_force_all_campaign_movement_range", "force_to_force_own", "20")], j
        d = [r for r in t["loc"] if r["key"] == "derpy_gg_service_desc_t_probe"][0]["text"]
        assert d.startswith("+20% campaign movement for the army you select, for 3 turns."), d
        # A buyer-side effect at the wrong sign is reported...
        probe["effects"] = [("wh_main_effect_force_all_campaign_movement_range",
                             "force_to_force_own", -20)]
        assert any("t_probe" in x and "fights" in x for x in check()), "sign not caught"
        # ...and a declared drawback is the one place that sign is accepted.
        probe["drawback"] = True
        assert not any("t_probe" in x and "fights" in x for x in check()), \
            "drawback not honoured"
    finally:
        SERVICES.remove(probe)
        for F in FLAVOURS.values():
            F["services"].pop("t_probe", None)
```

- [ ] **Step 2: Run and watch it fail**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: an AssertionError at `assert len(b) == 1 ...`. No bundle is emitted because `kind` is not `bundle`.

- [ ] **Step 3: Implement**

After `def service_bundle_key(...)`:

```python
def bundle_target_of(s):
    """Where the engine applies this service's bundle: an army, a region, or the faction."""
    if s["kind"] == "army":
        return "force"
    if s["kind"] in ("settlement", "enemy_settlement"):
        return "region"
    return "faction"


def inverted(s):
    """A bundle that must be BAD for whoever holds it: aimed at an enemy, or a drawback."""
    return bool(s.get("hostile") or s["kind"] == "enemy_settlement" or s.get("drawback"))


def service_text(s):
    """A service's player sentence, its numbers filled from its own effects and turns so
    the words cannot drift from the rows."""
    vals = dict(("v%d" % i, int(e[2])) for i, e in enumerate(s.get("effects", [])))
    return s["text"].format(turns=s.get("turns", 0), value=s.get("value", 0), **vals)
```

In `_build_one`'s service loop, replace

```python
        body = SERVICE_BLURB[s["key"]]
        if body is None and s.get("hostile"):
```

with

```python
        body = SERVICE_BLURB[s["key"]]
        if body is None and s.get("text"):
            body = service_text(s)
        elif body is None and s.get("hostile"):
```

In the same loop, replace

```python
        if s["kind"] != "bundle":
            continue
```

with

```python
        if s.get("effects"):
            # ITS OWN EFFECTS, not the guild's rank effect (2026-09-29 pools).
            key = service_bundle_key(s["key"])
            bundles.append({
                "key": key, "localised_description": "",
                "localised_title": SERVICE_NAMES[s["key"]],
                "bundle_target": bundle_target_of(s), "priority": "1",
                "ui_icon": bundle_icon(s["guild"]), "is_global_effect": "true",
                "show_in_3d_space": "false", "owner_only": "true",
            })
            for ek, sc, v in s["effects"]:
                junctions.append({"effect_bundle_key": key, "effect_key": ek,
                                  "effect_scope": sc, "value": str(int(v)),
                                  "advancement_stage": STAGE})
            loc.append({"key": "effect_bundles_localised_title_%s" % key,
                        "text": SERVICE_NAMES[s["key"]], "tooltip": "false"})
            loc.append({"key": "effect_bundles_localised_description_%s" % key,
                        "text": ("Inflicted by %s. %s" if s["kind"] == "enemy_settlement"
                                 else "Bought from %s with favour. %s")
                                % (GUILD_NAMES[s["guild"]], service_text(s)),
                        "tooltip": "false"})
            continue
        if s["kind"] != "bundle":
            continue
```

The rank-effect bundle code after it is unchanged.

In `check()`, after `pairs_to_check += [("patron", k, sc) for k, sc, _v in PATRON_EFFECTS]`, add:

```python
        pairs_to_check += [(s["key"], ek, sc) for s in SERVICES
                           for ek, sc, _v in s.get("effects", [])]
```

In the `hostile_keys` set comprehension, change `for x in SERVICES if x.get("hostile")` to `for x in SERVICES if inverted(x)`.

- [ ] **Step 4: Run**

Run `py tools/gen_great_guilds.py --selftest`, then `--check`.
Expected: `selftest ok`; `--check` 0.

- [ ] **Step 5: Ledger**

`Task 6: complete (selftest ok, --check 0; RED seen: no bundle for the probe)`.

---

### Task 7: The 36 services

**Files:**
- Modify: `tools/gen_great_guilds.py` (`SERVICES` rows; every non-Chaos-Dwarf `FLAVOURS[tag]["services"]`; selftest counts)
- Modify: `tools/gen_guilds_ui.py` (card-slot check)
- Modify: `zzz_derpy_guilds.lua` (`GG.SERVICES` rows, appended)
- Test: `tools/_guilds_bounty_harness.lua`, `tools/_guilds_harness.lua` (the brass monopoly fixture)

**Interfaces:**
- Consumes: Task 5's kinds and flags; Task 6's `effects`, `text` and `drawback`.
- Produces: 54 service rows, three per card.

- [ ] **Step 1: Failing test**

Append to the bounty harness:

```lua
-- ------------------------------------------------ SERVICE POOLS: the catalogue --
do
    -- THREE PER CARD, and every new row a shape the payload knows.
    W.reset()
    local kinds = {bundle = 1, gold = 1, research = 1, unit = 1, shroud = 1, building = 1,
                   pooled = 1, army = 1, settlement = 1, enemy_settlement = 1, ranks = 1}
    for _, g in ipairs(GG.GUILDS) do
        for _, r in ipairs(GG.CARD_RANKS) do
            local p = GG.pool("me", g, r)
            assert(#p == 3, g .. " rank " .. r .. " has " .. #p .. " services, not 3")
        end
    end
    assert(#GG.SERVICES == 54, "54 services, got " .. #GG.SERVICES)
    for i = 19, #GG.SERVICES do
        local s = GG.SERVICES[i]
        assert(kinds[s.kind], s.key .. " has kind " .. tostring(s.kind))
        assert((s.rank == 4) == (s.lead == true), s.key .. ": lead exactly on rank 4")
        assert(s.cost == ({50, 150, 400})[s.rank - 1] and s.cd == ({8, 12, 16})[s.rank - 1],
               s.key .. ": cost and cooldown follow its rank")
        assert(s.kind ~= "bundle" or (s.turns or 0) > 0, s.key .. ": a bundle needs turns")
    end
    ok("every card has three services, and every new one is a known shape")
end
```

- [ ] **Step 2: Run and watch it fail**

Expected: `brass rank 2 has 1 services, not 3`.

- [ ] **Step 3: The Lua rows**

In `GG.SERVICES`, after the `great_coffle` row: append only, one line each.

```lua
    -- THE POOLS (2026-09-29, spec §5): two more per card. Effects and values live in the
    -- generator; these rows carry what the payload reads.
    {key="alms_and_bribes",    guild="brass",        rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="mercenary_contract", guild="brass",        rank=2, cost=50,  cd=8,  kind="bundle",   turns=6},
    {key="guild_loan",         guild="brass",        rank=3, cost=150, cd=12, kind="gold",     value=6000, turns=10, with_bundle=true},
    {key="industry_charter",   guild="brass",        rank=3, cost=150, cd=12, kind="bundle",   turns=10},
    {key="treasury_seal",      guild="brass",        rank=4, cost=400, cd=16, kind="bundle",   turns=12, lead=true},
    {key="bought_peace",       guild="brass",        rank=4, cost=400, cd=16, kind="bundle",   turns=12, lead=true},
    {key="forced_march",       guild="immortals",    rank=2, cost=50,  cd=8,  kind="army",     turns=3},
    {key="drillmasters",       guild="immortals",    rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="battle_standard",    guild="immortals",    rank=3, cost=150, cd=12, kind="army",     turns=5},
    {key="field_surgeons",     guild="immortals",    rank=3, cost=150, cd=12, kind="army",     turns=2, heal=true},
    {key="veteran_cadre",      guild="immortals",    rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true},
    {key="warlords_honour",    guild="immortals",    rank=4, cost=400, cd=16, kind="ranks",    value=3, lead=true},
    {key="ward_runes",         guild="daemonsmiths", rank=2, cost=50,  cd=8,  kind="army",     turns=5},
    {key="spirit_siphon",      guild="daemonsmiths", rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="forged_arms",        guild="daemonsmiths", rank=3, cost=150, cd=12, kind="bundle",   turns=8},
    {key="master_gunners",     guild="daemonsmiths", rank=3, cost=150, cd=12, kind="bundle",   turns=10},
    {key="great_work",         guild="daemonsmiths", rank=4, cost=400, cd=16, kind="research", turns=10, with_bundle=true, lead=true},
    {key="arsenal",            guild="daemonsmiths", rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true},
    {key="bribed_guards",      guild="khanate",      rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="blooded_agents",     guild="khanate",      rank=2, cost=50,  cd=8,  kind="bundle",   turns=10},
    {key="hired_blade",        guild="khanate",      rank=3, cost=150, cd=12, kind="ranks",    value=3},
    {key="sow_discord",        guild="khanate",      rank=3, cost=150, cd=12, kind="enemy_settlement", turns=5},
    {key="web_of_whispers",    guild="khanate",      rank=4, cost=400, cd=16, kind="bundle",   turns=15, lead=true},
    {key="poisoned_wells",     guild="khanate",      rank=4, cost=400, cd=16, kind="enemy_settlement", turns=8, lead=true},
    {key="granaries",          guild="overseers",    rank=2, cost=50,  cd=8,  kind="settlement", turns=8},
    {key="road_gangs",         guild="overseers",    rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="enforcers",          guild="overseers",    rank=3, cost=150, cd=12, kind="settlement", turns=8},
    {key="fortify",            guild="overseers",    rank=3, cost=150, cd=12, kind="settlement", turns=8},
    {key="master_builders",    guild="overseers",    rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true},
    {key="public_works",       guild="overseers",    rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true},
    {key="raiding_parties",    guild="slavers",      rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="captive_markets",    guild="slavers",      rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="slave_levy",         guild="slavers",      rank=3, cost=150, cd=12, kind="bundle",   turns=6},
    {key="pit_fights",         guild="slavers",      rank=3, cost=150, cd=12, kind="bundle",   turns=10},
    {key="great_hunt",         guild="slavers",      rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true},
    {key="scorched_earth",     guild="slavers",      rank=4, cost=400, cd=16, kind="enemy_settlement", turns=8, lead=true},
```

`public_works` is the spec's "Great Works". It gets its own key so it cannot be confused with `great_work`; its player name stays per flavour.

- [ ] **Step 4: The generator rows**

Append to `SERVICES` in `tools/gen_great_guilds.py`, in the same order. `name` is the Chaos Dwarf name, which `FLAVOURS[""]["services"]` is built from. Effects and values are the spec §5 table verbatim. `SERVICE_BLURB` needs no entries, because Task 6 builds these sentences from `text`.

```python
    # THE POOLS (2026-09-29 pools spec §5). Every (effect, scope) is a pair vanilla uses,
    # checked with this file's own rules; `text` fills its numbers from `effects`.
    {"key": "alms_and_bribes", "guild": "brass", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Temple Bribes",
     "effects": [("wh3_main_effect_corruption_reduction_events", "faction_to_province_own", -5)],
     "text": "{v0:+d} corruption in every province you hold, for {turns} turns."},
    {"key": "mercenary_contract", "guild": "brass", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 6, "name": "Hobgoblin Contracts",
     "effects": [("wh_main_effect_force_all_campaign_recruitment_cost_all", "faction_to_force_own", -15)],
     "text": "{v0:+d}% recruitment cost in all your armies, for {turns} turns."},
    {"key": "guild_loan", "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "gold", "value": 6000, "turns": 10, "with_bundle": True, "drawback": True,
     "name": "Brass Loan",
     "effects": [("wh_main_effect_economy_gdp_mod_all", "faction_to_region_own", -10)],
     "text": "Adds {value:,} gold to your treasury at once. Repaid as {v0:+d}% income from "
             "all buildings, for {turns} turns."},
    {"key": "industry_charter", "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 10, "name": "Furnace Charter",
     "effects": [("wh_dlc07_effect_economy_gdp_mod_industry", "faction_to_region_own", 20)],
     "text": "{v0:+d}% income from industry buildings, for {turns} turns."},
    {"key": "treasury_seal", "guild": "brass", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 12, "name": "The Tablet Seal",
     "effects": [("wh_main_effect_force_all_campaign_upkeep", "faction_to_force_own", -20)],
     "text": "{v0:+d}% upkeep for all your units, for {turns} turns."},
    {"key": "bought_peace", "guild": "brass", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 12, "name": "Bought Obedience",
     "effects": [("wh_main_effect_public_order_events", "faction_to_province_own", 3)],
     "text": "{v0:+d} public order in every province you hold, for {turns} turns."},
    {"key": "forced_march", "guild": "immortals", "rank": 2, "cost": 50, "cd": 8,
     "kind": "army", "turns": 3, "name": "Forced March",
     "effects": [("wh_main_effect_force_all_campaign_movement_range", "force_to_force_own", 20)],
     "text": "{v0:+d}% campaign movement for the army you select, for {turns} turns."},
    {"key": "drillmasters", "guild": "immortals", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Drillmasters",
     "effects": [("wh_main_effect_force_all_campaign_experience_base_all", "faction_to_force_own", 1)],
     "text": "Units you recruit start {v0:+d} rank higher, for {turns} turns."},
    {"key": "battle_standard", "guild": "immortals", "rank": 3, "cost": 150, "cd": 12,
     "kind": "army", "turns": 5, "name": "Bull Standard",
     "effects": [("wh_main_effect_force_stat_leadership", "force_to_force_own", 8)],
     "text": "{v0:+d} leadership for the army you select, for {turns} turns."},
    {"key": "field_surgeons", "guild": "immortals", "rank": 3, "cost": 150, "cd": 12,
     "kind": "army", "turns": 2, "heal": True, "name": "Flesh-Menders",
     "effects": [("wh_main_effect_force_all_campaign_replenishment_rate", "force_to_force_own", 30)],
     "text": "Heals the army you select at once, then {v0:+d}% replenishment for it, for "
             "{turns} turns."},
    {"key": "veteran_cadre", "guild": "immortals", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "name": "Blooded Cadre",
     "effects": [("wh_main_effect_force_all_campaign_experience_base_all", "faction_to_force_own", 3)],
     "text": "Units you recruit start {v0:+d} ranks higher, for {turns} turns."},
    {"key": "warlords_honour", "guild": "immortals", "rank": 4, "cost": 400, "cd": 16,
     "kind": "ranks", "value": 3, "name": "Honour of the Immortals",
     "text": "Adds {value} ranks to the lord or hero you select."},
    {"key": "ward_runes", "guild": "daemonsmiths", "rank": 2, "cost": 50, "cd": 8,
     "kind": "army", "turns": 5, "name": "Daemonic Wards",
     "effects": [("wh_main_effect_force_stat_ward_save", "force_to_force_own", 10)],
     "text": "{v0:+d}% ward save for the army you select, for {turns} turns."},
    {"key": "spirit_siphon", "guild": "daemonsmiths", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Siphon the Winds",
     "effects": [("wh3_main_effect_winds_of_magic_events", "faction_to_force_own", 5)],
     "text": "{v0:+d} Winds of Magic power reserve for all your armies, for {turns} turns."},
    {"key": "forged_arms", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 8, "name": "Daemon-Forged Arms",
     "effects": [("wh_main_effect_force_stat_weapon_strength", "faction_to_force_own", 10)],
     "text": "{v0:+d}% weapon strength for all your armies, for {turns} turns."},
    {"key": "master_gunners", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 10, "name": "Gunnery Masters",
     "effects": [("wh_main_effect_force_stat_missile_damage_artillery", "faction_to_force_own", 20)],
     "text": "{v0:+d}% missile damage for all your artillery, for {turns} turns."},
    {"key": "great_work", "guild": "daemonsmiths", "rank": 4, "cost": 400, "cd": 16,
     "kind": "research", "turns": 10, "with_bundle": True, "name": "The Great Work",
     "effects": [("wh_main_effect_technology_research_rate_mod", "faction_to_faction_own", 30)],
     "text": "Completes the technology you are researching at once, then {v0:+d}% research "
             "rate, for {turns} turns."},
    {"key": "arsenal", "guild": "daemonsmiths", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "name": "Arsenal of Zharr",
     "effects": [("wh_main_effect_force_stat_missile_damage", "faction_to_force_own", 15)],
     "text": "{v0:+d}% missile damage for all your armies, for {turns} turns."},
    {"key": "bribed_guards", "guild": "khanate", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Bribed Guards",
     "effects": [("wh_main_effect_agent_action_success_chance", "faction_to_character_own", 15)],
     "text": "{v0:+d}% success chance for your heroes' actions, for {turns} turns."},
    {"key": "blooded_agents", "guild": "khanate", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 10, "name": "Blooded Agents",
     "effects": [("wh_main_effect_agent_recruitment_xp_all_agents", "faction_to_province_own", 2)],
     "text": "Heroes you recruit start {v0:+d} ranks higher, for {turns} turns."},
    {"key": "hired_blade", "guild": "khanate", "rank": 3, "cost": 150, "cd": 12,
     "kind": "ranks", "value": 3, "name": "Hired Blade",
     "text": "Adds {value} ranks to the lord or hero you select."},
    {"key": "sow_discord", "guild": "khanate", "rank": 3, "cost": 150, "cd": 12,
     "kind": "enemy_settlement", "turns": 5, "name": "Sow Discord",
     "effects": [("wh_main_effect_public_order_events", "region_to_province_own_unseen", -8)],
     "text": "{v0:+d} public order in the enemy province you select, for {turns} turns."},
    {"key": "web_of_whispers", "guild": "khanate", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 15, "name": "Web of Whispers",
     "effects": [("wh2_main_effect_agent_cap_increase_all_heroes", "faction_to_faction_own_unseen", 1)],
     "text": "{v0:+d} to the number of each kind of hero you may recruit, for {turns} turns."},
    {"key": "poisoned_wells", "guild": "khanate", "rank": 4, "cost": 400, "cd": 16,
     "kind": "enemy_settlement", "turns": 8, "name": "Poisoned Wells",
     "effects": [("wh_main_effect_province_growth_events", "region_to_province_own", -25),
                 ("wh_main_effect_force_all_campaign_replenishment_rate", "region_to_force_own", -25)],
     "text": "{v0:+d} growth in the enemy province you select, and {v1:+d}% replenishment "
             "for armies there, for {turns} turns."},
    {"key": "granaries", "guild": "overseers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "settlement", "turns": 8, "name": "Fattened Herds",
     "effects": [("wh_main_effect_province_growth_events", "region_to_province_own", 25)],
     "text": "{v0:+d} growth in the province of the settlement you select, for {turns} turns."},
    {"key": "road_gangs", "guild": "overseers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Road Gangs",
     "effects": [("wh_main_effect_force_all_campaign_movement_range", "faction_to_force_own", 10)],
     "text": "{v0:+d}% campaign movement for all your armies, for {turns} turns."},
    {"key": "enforcers", "guild": "overseers", "rank": 3, "cost": 150, "cd": 12,
     "kind": "settlement", "turns": 8, "name": "Overseer Enforcers",
     "effects": [("wh_main_effect_public_order_events", "region_to_province_own_unseen", 6)],
     "text": "{v0:+d} public order in the province of the settlement you select, for "
             "{turns} turns."},
    {"key": "fortify", "guild": "overseers", "rank": 3, "cost": 150, "cd": 12,
     "kind": "settlement", "turns": 8, "name": "Fortify the Walls",
     "effects": [("wh_main_effect_force_stat_melee_defence", "region_to_force_own", 10),
                 ("wh_main_effect_force_army_campaign_siege_defend_attrition", "region_to_force_own", -20)],
     "text": "{v0:+d} melee defence for the defenders of the settlement you select, and "
             "{v1:+d}% attrition for them under siege, for {turns} turns."},
    {"key": "master_builders", "guild": "overseers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "name": "Master Builders",
     "effects": [("wh3_main_effect_building_construction_time_add_mod_all", "faction_to_region_own", -1)],
     "text": "{v0:+d} turn to every building's construction time (never below one), for "
             "{turns} turns."},
    {"key": "public_works", "guild": "overseers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "name": "Monuments to Hashut",
     "effects": [("wh_main_effect_public_order_events", "faction_to_province_own", 4),
                 ("wh_main_effect_province_growth_events", "faction_to_province_own", 30)],
     "text": "{v0:+d} public order and {v1:+d} growth in every province you hold, for "
             "{turns} turns."},
    {"key": "raiding_parties", "guild": "slavers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Raiding Parties",
     "effects": [("wh_main_effect_force_all_campaign_raid_income", "faction_to_force_own", 50)],
     "text": "{v0:+d}% income from raiding for all your armies, for {turns} turns."},
    {"key": "captive_markets", "guild": "slavers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "bundle", "turns": 8, "name": "Captive Markets",
     "effects": [("wh_main_effect_force_all_campaign_post_battle_loot_mod", "faction_to_faction_own", 20)],
     "text": "{v0:+d}% gold from battles you win, for {turns} turns."},
    {"key": "slave_levy", "guild": "slavers", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 6, "name": "Slave Levy",
     "effects": [("wh_main_effect_unit_recruitment_points", "faction_to_province_own", 1)],
     "text": "{v0:+d} local recruitment capacity in every province you hold, for "
             "{turns} turns."},
    {"key": "pit_fights", "guild": "slavers", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 10, "name": "Pit Fights",
     "effects": [("wh3_dlc20_effect_xp_gain_all_units", "faction_to_force_own", 25)],
     "text": "{v0:+d}% experience from battle for all your units, for {turns} turns."},
    {"key": "great_hunt", "guild": "slavers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "name": "The Great Hunt",
     "effects": [("wh_main_effect_force_all_campaign_movement_range", "faction_to_force_own", 15),
                 ("wh_main_effect_force_all_campaign_raid_income", "faction_to_force_own", 50)],
     "text": "{v0:+d}% campaign movement and {v1:+d}% raiding income for all your armies, "
             "for {turns} turns."},
    {"key": "scorched_earth", "guild": "slavers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "enemy_settlement", "turns": 8, "name": "Scorched Earth",
     "effects": [("wh_main_effect_economy_gdp_mod_all", "region_to_region_own", -25)],
     "text": "{v0:+d}% income from buildings in the enemy settlement you select, for "
             "{turns} turns."},
```

- [ ] **Step 5: The names in the other eight flavours**

Add each key to each flavour's `"services"` dict:

| key | `_emp` | `_dwf` | `_brt` | `_cth` |
|---|---|---|---|---|
| alms_and_bribes | Alms to the Temples | Ancestor Offerings | Alms for the Grail Chapels | Temple Offerings |
| mercenary_contract | Sell-Sword Contracts | Clan Contracts | Hired Men-at-Arms | Bought Levies |
| guild_loan | A Loan from Marienburg | A Loan in Gold | A Merchant's Loan | Jade Loan |
| industry_charter | Guild Charter of Nuln | Forge Charter | Vintners' Charter | Workshop Mandate |
| treasury_seal | The Imperial Seal | The Hold's Seal | The Duke's Seal | The Celestial Seal |
| bought_peace | Bread and Circuses | Ale for the Hold | Feast Days | Festival of Lanterns |
| forced_march | Forced March | Long March | Ride Through the Night | Swift Columns |
| drillmasters | Drill Sergeants | Shieldwall Drill | Squires' Training | Drill Masters |
| battle_standard | The Regimental Colours | The Clan Banner | The Lady's Pennant | Dragon Banner |
| field_surgeons | Barber-Surgeons | Hold Healers | Chapel Healers | Jade Physicians |
| veteran_cadre | Old Soldiers | Longbeard Mentors | Knights of the Realm | Veteran Officers |
| warlords_honour | The Emperor's Honours | Honours of the Hold | An Accolade | Imperial Honours |
| ward_runes | Blessed Wards | Runes of Warding | The Lady's Grace | Jade Wards |
| spirit_siphon | The Colleges' Tithe | Runelord's Anvil | Waters of the Grail | Wind Channelling |
| forged_arms | Nuln Steel | Gromril Edges | Castle Smiths | Celestial Steel |
| master_gunners | Master Gunners | Master Engineers | Trebuchet Masters | Master Gunners |
| great_work | The Grand Treatise | The Engineers' Masterwork | Wisdom of the Damsels | The Academy's Treatise |
| arsenal | The Imperial Arsenal | Hold Arsenal | Bowyers' Guild | Imperial Arsenal |
| bribed_guards | Bribed Watchmen | Paid Guides | Paid Poachers | Paid Informers |
| blooded_agents | Seasoned Agents | Seasoned Rangers | Hardened Paladins | Seasoned Agents |
| hired_blade | A Name in the Ledger | Old Ranger's Lessons | A Hero's Errand | A Crow's Training |
| sow_discord | Rumours in the Taverns | Stir the Grudges | Outlaw Mischief | Whispered Slanders |
| web_of_whispers | Every Street Corner | Paths Under the Mountain | Friends in the Greenwood | A Thousand Crows |
| poisoned_wells | Bad Water | Foul the Springs | Blight the Fields | Poisoned Wells |
| granaries | Full Granaries | Brewhouse Stores | Harvest Tithe | Rice Stores |
| road_gangs | Road Wardens | Underway Tunnels | The King's Roads | Ivory Road Wardens |
| enforcers | The Watch | Hold Wardens | The Sheriff's Men | Magistrates |
| fortify | Shore Up the Walls | Reinforce the Gates | Raise the Palisades | Raise the Ramparts |
| master_builders | Master Masons | Master Stonemasons | Master Castle-Wrights | Master Builders |
| public_works | Civic Works | Carved Halls | Grail Chapels | Temples and Canals |
| raiding_parties | Foraging Parties | Reclaiming Parties | Foraging Knights | Foraging Columns |
| captive_markets | Ransom Brokers | Salvage Rights | Ransom of Nobles | Tribute of the Defeated |
| slave_levy | Press Gangs | Clan Muster | Peasant Muster | Conscription |
| pit_fights | Tourney Grounds | Trial of Axes | The Joust | Martial Trials |
| great_hunt | The Long Ride | The Great Reclaiming | The Grand Crusade | The Long Pursuit |
| scorched_earth | Burn the Fields | Collapse the Mines | Salt the Earth | Scorched Earth |

| key | `_ksl` | `_def` | `_hef` | `_gen` |
|---|---|---|---|---|
| alms_and_bribes | Offerings to the Gods | Tithes to Khaine | Offerings to Asuryan | Alms and Bribes |
| mercenary_contract | Hired Kossars | Bought Blades | Hired Sea Guard | Mercenary Contract |
| guild_loan | An Erengrad Loan | A Corsair's Loan | A Lothern Loan | Guild Loan |
| industry_charter | Workshop Charter | Forge Charter | Artisans' Charter | Industry Charter |
| treasury_seal | The Tzarina's Seal | The Witch King's Seal | The Phoenix Seal | Treasury Seal |
| bought_peace | Kvas for the People | Public Executions | Festivals of Ulthuan | Bought Peace |
| forced_march | Sledge March | Driven March | Swift March | Forced March |
| drillmasters | Kossar Drill | Black Guard Drill | Citizen Drill | Drillmasters |
| battle_standard | The Bear Standard | The Dread Banner | The Phoenix Banner | Battle Standard |
| field_surgeons | Village Healers | Flesh-Stitchers | Healers of Isha | Field Surgeons |
| veteran_cadre | Veteran Streltsi | Blooded Veterans | Veteran Wardens | Veteran Cadre |
| warlords_honour | The Tzar's Favour | Malekith's Favour | The Phoenix King's Honour | Warlord's Honour |
| ward_runes | Frost Wards | Dark Wards | Wards of Hoeth | Ward Runes |
| spirit_siphon | Draw on the Ice | Drain the Winds | The Vortex's Tide | Spirit Siphon |
| forged_arms | Frost-Tempered Steel | Har Ganeth Steel | Ithilmar Blades | Forged Arms |
| master_gunners | Master Gunners | Reaper Crews | Bolt Thrower Crews | Master Gunners |
| great_work | The Frost Maiden's Lore | Secrets of Ghrond | The White Tower's Lore | The Great Work |
| arsenal | Streltsi Armoury | The Black Armoury | Lothern Armoury | Arsenal |
| bribed_guards | Paid Border Guards | Paid Traitors | Paid Watchers | Bribed Guards |
| blooded_agents | Hardened Agents | Blooded Assassins | Seasoned Agents | Blooded Agents |
| hired_blade | A Smuggler's Lessons | Khaine's Tutelage | Shadow Training | Hired Blade |
| sow_discord | Stir the Oblast | Seeds of Betrayal | Whispers of Doubt | Sow Discord |
| web_of_whispers | Every Road North | Knives Everywhere | Shadows in Every Court | Web of Whispers |
| poisoned_wells | Frozen Wells | Poisoned Wells | Poisoned Wells | Poisoned Wells |
| granaries | Winter Stores | Thrall Rations | Harvest of Ulthuan | Granaries |
| road_gangs | Sledge Roads | Thrall Roads | Elven Roads | Road Gangs |
| enforcers | The Tzar's Wardens | Dreadspear Patrols | City Wardens | Enforcers |
| fortify | Ice Walls | Raise the Spikes | Raise the Wards | Fortify |
| master_builders | Master Builders | Master Builders | Master Masons | Master Builders |
| public_works | Stanitsa Works | Towers of Naggarond | Shrines of Ulthuan | Public Works |
| raiding_parties | Steppe Riders | Slave Raids | Reaver Scouts | Raiding Parties |
| captive_markets | Ransom Market | Slave Markets | Spoils of Victory | Captive Markets |
| slave_levy | Village Muster | Thrall Levy | Levy of the Isles | Extra Levies |
| pit_fights | Bear Pits | Arena of Khaine | Martial Contests | Pit Fights |
| great_hunt | The Great Ride | The Great Harvest | The Long Ride | The Great Hunt |
| scorched_earth | Scorch the Steppe | Leave Nothing Standing | Burn the Stores | Scorched Earth |

`check_flavours` may report a name, for example a word belonging to another race, or one the length limit clips. If so, change that name and ledger it.

- [ ] **Step 6: The counts the 18 pinned**

`selftest()` in `tools/gen_great_guilds.py`:
- `assert len(SERVICES) == 18` and the unique-keys line become `54`.
- The per-guild loop becomes:

  ```python
      for g in GUILDS:
          mine = [s for s in SERVICES if s["guild"] == g]
          assert len(mine) == 9, "%s has %d services, want 9" % (g, len(mine))
          assert sorted(s["rank"] for s in mine) == [2] * 3 + [3] * 3 + [4] * 3, "%s ranks" % g
          assert sorted(s["cost"] for s in mine) == [50] * 3 + [150] * 3 + [400] * 3, "%s costs" % g
  ```

- `assert len(bundled) == 12` becomes `== 34`.
- The `want_eb` pair becomes:

  ```python
      minted = [s for s in SERVICES if s.get("effects")]
      assert len(minted) == 34, "34 services with their own effects, got %d" % len(minted)
      want_eb = 24 + 12 + len(minted) + len(GUILDS) + 1
      assert len(eb) == want_eb, (
          "24 rank + 12 service + %d own-effect + %d leadership + 1 patron = %d, got %d"
          % (len(minted), len(GUILDS), want_eb, len(eb)))
  ```

- `assert len(LEAD_SERVICES) == len(GUILDS)` becomes `== 3 * len(GUILDS)`, with the message `"three monopoly services per guild, one per card of rank 4, got %d"`.
- The kind tuple gains `"army", "settlement", "enemy_settlement", "ranks"`.
- The turns check becomes `if s["kind"] == "bundle" or s.get("effects"):`.

`tools/gen_guilds_ui.py`: replace the `per_guild` line with

```python
    # ONE CARD PER RANK: a guild holds a POOL of services per rank since 2026-09-29.
    per_guild = max(len(set(s["rank"] for s in G.SERVICES if s["guild"] == g))
                    for g in G.GUILDS)
```

and change the message to `"%d card slots but %d ranks per guild"`.

`tools/_guilds_harness.lua`: replace

```lua
local top = nil
for i = 1, #GG.SERVICES do
    if GG.SERVICES[i].guild == "brass" and GG.SERVICES[i].lead then
        top = GG.SERVICES[i]
    end
end
assert(top, "brass must have exactly one monopoly service")
```

with

```lua
-- THE MONOPOLY ON TODAY'S CARD. Brass has three rank-4 services since the pools
-- (2026-09-29); the first is the one on the card when nothing has been drawn.
local top = GG.service(GG.default_card("brass", 4))
assert(top and top.lead, "brass's rank-4 card is a monopoly service")
```

Another main-harness test may fail on `card` because it fired the turn handler for a faction and then bought one of the original 18: the turn drew that faction's cards. Clear them at the purchase with `GG.cards[<faction>] = nil`, which reads today's 18, and ledger each site.

- [ ] **Step 7: Run everything and prove the effect check**

Run:
- both harnesses;
- `py tools/gen_great_guilds.py --check`, `--selftest`, `--write`;
- `py tools/import_great_guilds.py --check`;
- `py tools/gen_guilds_ui.py --check`;
- `luac -p` on the model, AI and UI files.

Expected: all green.
- `import --check` compares all 54 Lua rows' rank, cost and cd.
- `--check` validates every new effect pair, value range and sign. Sow Discord, Poisoned Wells, Scorched Earth and the Guild Loan are inverted.

Prove the range check:
1. Change `industry_charter`'s value to `2000`.
2. Run `--check`. Expected: the "used ... too hard" finding for `derpy_gg_svc_industry_charter`.
3. Restore, and re-run `--write`.

- [ ] **Step 8: Ledger**

`Task 7: complete (...)`, plus any name or fixture changes as rulings.

---

### Task 8: Mutants

**Files:**
- Modify: `tools/mutate_guilds.py`

- [ ] **Step 1: Add the mutants**

Append to `MUTANTS`. `M` is the model file (LF) and `A` is the AI file (CRLF); every `A` anchor is one line.

```python
    # SERVICE POOLS (2026-09-29).
    ("a service off the cards still sold", M,
     b"    if not GG.on_card(faction, service_key) then return false, \"card\" end",
     b""),
    ("a draw that repeats the card's last service", M,
     b"                    if pool[j].key ~= old[i] then fresh[#fresh + 1] = pool[j] end",
     b"                    fresh[#fresh + 1] = pool[j]"),
    ("a redraw every turn instead of every period", M,
     b"    if c and c.turn and math.floor(turn / n) <= math.floor(c.turn / n) then return false end",
     b"    if c and c.turn == turn then return false end"),
    ("hostile services drawn with the switch off", M,
     b"       and GG.setting(\"hostile_services\") == false then\n        return false\n    end\n    if s.needs then",
     b"       and false then\n        return false\n    end\n    if s.needs then"),
    ("a friendly service aimed at an enemy army", M,
     b"            if c:faction():name() ~= faction then return false end",
     b""),
    ("an enemy settlement service on a friend", M,
     b"            return cm:get_faction(faction):at_war_with(owner)",
     b"            return true"),
    ("a sale to the wrong target", M,
     b"    if GG.needs_target(s) and not GG.target_ok(faction, s, target) then return false, \"target\" end",
     b"    if GG.needs_target(s) and not target then return false, \"target\" end"),
    ("an army bundle on the character cqi", M,
     b"                                            force:command_queue_index(), s.turns)",
     b"                                            target, s.turns)"),
    ("the rivals' round buying from last period's cards", A,
     b"                GG.rotate_cards(name, turn)",
     b"                local _ = turn"),
    ("the rotation announced to rivals", M,
     b"    if not GG.is_human(faction) then return end\n    GG.log_add(faction, \"rotation\"",
     b"    GG.log_add(faction, \"rotation\""),
```

- [ ] **Step 2: Run**

Run `py tools/mutate_guilds.py --selftest`, then
`py tools/mutate_guilds.py > "$TEMP/mut.txt" 2>&1; echo $?; grep PROBLEM "$TEMP/mut.txt"`.

Expected: `selftest ok: 51 mutants anchored`; exit 0 with no PROBLEM. Every mutant should be caught:

| Mutant | Caught by |
|---|---|
| off-cards | the gate test |
| repeat | the draw test |
| every turn | the clock test |
| hostile | the pool test |
| friendly on enemy | the target test |
| enemy on friend | the target test |
| wrong target | the till test |
| character cqi | the kinds test |
| rivals' round | the round test |
| announced to rivals | the notice test |

A survivor means a missing test: write that test (RED first), not a weaker mutant.

After the run, re-run `py tools/gen_great_guilds.py --write`, because a mutation run leaves generated files mutated.

- [ ] **Step 3: Ledger**

`Task 8: complete (mutate 51/51 caught)`.

---

### Task 9: Build, deploy, record

- [ ] **Step 1: Static checks**

Run on the model, AI and UI files:
- `luac -p`;
- `py tools/check_lua_api.py` (0 findings);
- `py tools/check_lua_literal_left.py` (0);
- `py tools/check_lua_undeclared.py` on the model and AI together (only the three pre-existing bounty-data names).

Byte-count line endings on the AI, UI and MCT files: every `\n` is still `\r\n`.

- [ ] **Step 2: Build**

RPFM must be open: `Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing`. Connection refused means stop and say so.

Run `py tools/import_great_guilds.py`.
Expected: `saved pack verified - every table holds this build's rows`.

Byte-compare the four packed scripts against disk with `read_pack_index.read(pack, "script/")`.

- [ ] **Step 3: Deploy**

If `Warhammer3.exe` is not running:
1. Back up `data/derpy_great_guilds.pack` to `.bak_pools_stage1_20260929`.
2. Copy the build in.
3. Compare MD5s.

- [ ] **Step 4: Record**

- `docs/sessions/HANDOFF_20260929_GUILDS_POOLS_STAGE1.md`: what shipped, the build MD5, the backup, the rulings, and the in-game checks:
  1. Hire now grants its unit.
  2. A rotation at turn 10 raises the feed message without opening a panel.
  3. Each new kind lands: Forced March on an army, Granaries on a province, Sow Discord on an enemy province, Warlord's Honour's ranks.
  4. Field Surgeons heals.
  5. The three `_unseen` lines show nothing in the breakdown, but their numbers are in the card text.
  6. A hostile region bundle behaves correctly after the region changes hands.
- `docs/SESSION_INDEX.md`: one line.
- `repos/derpy-great-guilds/CHANGELOG.md`: an entry in player words.
- `tools/sync_guilds_repo.py` manifest: add the spec (`docs/design/`), this plan (`docs/plans/`) and the handoff (`docs/history/`). Run `--check`, then the sync. Do not push.
