# Great Guilds: race mechanics, stage 2 - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each of the eight races three things no other race has:
- services of its own (29 rows, the Empire's lords and politics included);
- an earning from something only that race does;
- one rule bent.

All three sit behind a `race_differences` switch. The same stage adds the new Slave Tithe payouts, a race label on the cards, and a Help page per race.

**Architecture:**
- **Race rows go in the one catalogue** (`GG.SERVICES`, append-only), tagged `race = <culture>`. `GG.pool_ok` draws them only for that race, and only while race differences are on.
- **Three new kinds.** `resource` is a pool grant on the row. `race` and `race_army` call one function per service in `GG.RACE_FIRE`. `race_army` is aimed at an army like `army`.
- **One table for character-target kinds.** `GG.CHAR_KINDS` replaces the five places that list the character kinds today.
- **One gate for what a service needs.** `GG.needs_ok` is read at the draw and again at the till, so a hook that disappears mid-period refuses the sale (`"unavailable"`) instead of taking favour.
- **Twists** are whole percentages in `GG.TWISTS`, applied by `GG.setting_for(faction, key)` at every call site that reads one of those settings for a faction.
- **Earn routes** are five listeners that pay through `GG.race_earn`, which calls `GG.capped_grant`, so the guild's turn limit, the rival's share and the patron all apply.

**Tech Stack:** WH3 campaign Lua 5.1 (float32 numbers in game), Python 3 generator (`tools/gen_great_guilds.py`), Lua 5.1.5 harnesses, RPFM MCP server for the pack build.

**Spec:** `docs/superpowers/specs/2026-09-29-great-guilds-service-pools-and-races-design.md`
- In scope: §6, §6.1, §6.2, §7, `race_differences` in §8, the stage-2 parts of §9 and §10, §11.
- Stage 1 is built and live (`F3F6FE85`). Its plan is `docs/superpowers/plans/2026-09-29-great-guilds-service-pools-stage1.md`.

**Every CA hook was re-read on 2026-09-29** in CA's 9.0 scripts (`Modding Files/reference/ca_scripts_wh3/`), CA's docs and the installed `db.pack`. Nine findings change the spec. Task 13 writes them into it:

| # | Service or route | Spec says | This plan does, and why |
|---|---|---|---|
| 1 | Hell-Forge Allotment | CA's Tower of Zharr route: bundle, `perform_ritual`, incident | CA's global `hellforge:modify_unit_cap(ritual, faction_iface, hellforge.unit_cap_modifiers_bundle_string)` (`wh3_dlc23_campaign_chd_hellforge.lua:376`), plus the incident by hand. See the note below the table. |
| 2 | Hell-Forge incident | built as `wh3_dlc23_chd_toz_cap_<ritual>` | Built the same way, except for the blunderbusses. CA's own key misses a row (the row is `..._unit_cap_dwarf_blunderbusses`), so CA's roll of that cap shows no message. |
| 3 | Imperial Supply Train | CA's `trigger_imperial_reinforcements_event()` | `cm:trigger_dilemma(wulfhart, "wh2_dlc13_wulfhart_imperial_guards_st_<1-3>")` at CA's own strength bands. CA's function also zeroes the file-local supply meter (`:668`), so it brings the next supply forward instead of adding one. |
| 4 | Elector's Favour | gate on `cm:faction_has_campaign_feature(f, "politics")` | Asked of the buyer only. The wrapper throws for a faction key the map lacks (`lib_campaign_manager.lua:17626`). |
| 5 | Empire earn route | `RegionFactionChangeEvent` | Also skips the reasons `abandoned`, `abandoned to rebels`, `startpos setup`, `cli command` and `diplomacy trade`. The last one is two players trading a region back and forth for Reputation. |
| 6 | Bretonnian earn route | a purchase record, as for Dwarfs | Excludes the `missions` factor instead. Tales of Valour grants through it, and CA's own chivalry writes never use it. |
| 7 | Cathay earn route | `CaravanCompleted` | Heard once. CA re-raises the same context as `ScriptEventCaravanCompleted` (`caravans_core.lua:816`), and listening to both would pay twice. |
| 8 | Realign the Compass | `set_next_..._cooldown(faction_iface, 0)` | Never drawn for the Celestial Court. Yuan Bo's jade compass is a different system that this call does not reach. |
| 9 | Bought Loyalty | the selected lord | Not the faction leader, who has no personal loyalty to buy. |

**Why Hell-Forge (finding 1) does not use the Tower's route.** CA's route performs a ritual. Two things go wrong with that:
- A second ritual can end the mod's own one-turn commission rite while it is in flight (`docs/RITUALS.md` §5), and nobody has measured whether a zero-cast-time ritual does the same.
- The listener that pays the Tower's ritual also raises the next paid purchase of that cap by 25%.

`modify_unit_cap` is the same +1 without either.

**Values the spec left open, chosen here** (the user reviews them with this plan):
- **Race rows cost and cool down like shared rows of their rank:**
  - rank 2: 50 favour, 8 turns;
  - rank 3: 150 favour, 12 turns;
  - rank 4: 400 favour, 16 turns.
- **Slave Tithe payouts:**
  - Kislev: 150 Devotion (Prayers, at rank 2, is 75);
  - Dark Elves: 1,000 Slaves (Slave Coffles, at rank 2, is 500).
  - The Slave Tithe stays on whatever the `race_differences` switch says, like the Chaos Dwarf and Dwarf payouts it already has. §8 names only race rows, earnings and twists.
- **Earnings paid per so many points keep the remainder** in session memory:
  - Chivalry: one per 5;
  - Slaves: one per 20.

  Without this, a raid that brings in 12 Slaves pays nothing, every turn, for ever.
- **The Log reports what a guild actually gained** after its turn limit, and writes nothing when that is 0.

## Global Constraints

- **Lua and numbers:** Lua 5.1; the game's Lua is float32, so every number stored or compared is an integer. Twists are whole percentages.
- **Multiplayer:**
  - Every roll is `GG.roll`.
  - The draw rolls only in turn handlers.
  - A payload rolls only inside `GG.buy`, which multiplayer runs on every machine through `GG.MP_OPS.buy`.
  - The panel never rolls.
  - A `needs` check reads only world state every machine shares.
- **No loc calls from a turn handler or a listener.** They store keys; the panel resolves the text.
- **Line endings, checked 2026-09-29:**
  - CRLF: `zzz_derpy_guilds_ai.lua`, `zzz_derpy_guilds_ui.lua`, `script/mct/settings/derpy_great_guilds.lua`.
  - LF: `zzz_derpy_guilds.lua`, both harnesses, `gen_great_guilds.py`, `mutate_guilds.py`.
  - Edit with the Edit tool or byte-level Python, never `sed -i`.
  - A patch script that contains a backslash goes through the Write tool, never a Bash heredoc.
- **`GG.SERVICES` is append-only**, because cooldowns are saved by position.
  - Each Lua row stays on ONE line: `import_great_guilds.py` and `check_service_mirror` read rows line by line.
  - Race rows are appended in this order: Chaos Dwarfs, Dwarfs, Empire, Kislev, Bretonnia, Cathay, Dark Elves, High Elves.
  - A function never goes on a row. Row functions live in `GG.RACE_FIRE`, `GG.RACE_NEEDS` and `GG.RACE_TARGET_OK`, keyed by service key.
- **`GG.TUNE_ORDER` is append-only.** `race_differences` goes after `rotate_turns`.
- **Every CA key, call and argument type is the one verified on 2026-09-29** (the table above and the task notes). A different one is a spec change, not a plan edit.
  - `cm:faction_add_pooled_resource`, `cm:change_influence` and `cm:trigger_dilemma` take a **faction key string**.
  - `cm:set_next_winds_of_magic_compass_selection_cooldown`, `hellforge:modify_unit_cap` and `empire_find_electors_with_loyalty` take a **faction interface**.
  - `cm:modify_character_personal_loyalty_factor` and `cm:grant_unit_to_character` take a **character lookup string** (`cm:char_lookup_str`).
- **CA's globals are read, never declared.** Never declare a mod global named `chivalry`, `def_slaves`, `caravans`, `hellforge` or `grudge_cycle`.
- **Player text:** plain words; "Reputation", never "standing"; no emojis anywhere; never "rung".
- **Progress:** the workspace is not a git repo, so there are no commits. The ledger is `.superpowers/sdd/2026-09-29-great-guilds-stage2-race-mechanics/progress.md`.
- **Harness runs**, from the workspace root. Redirect output to `$TEMP` and read the tail.
  - `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua` must end `bounty harness ok`.
  - `"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua` must end `harness ok`.
  - The `RANDOM` stub rolls 1 unless a test replaces it.
- **Generator runs:** `py tools/gen_great_guilds.py --selftest`, then `--check` (exit 0, no `PROBLEM:` line), then `--write`.
- **A pre-existing test that breaks because the Chaos Dwarfs now bend a rule** is fixed by pinning the plain rule, not by rewriting its numbers. Chaos Dwarf demands come every 8 turns and pay 180 from Task 1 on. Add `GG.TUNE.race_differences = false` (bounty harness) or the equivalent `GG.TUNE` setting (main harness) at the start of that test, since it is about the demand, not the race. Ledger each one as a ruling.

## Review Focus

1. **A hook that goes away after the draw.** Examples:
   - a caravan comes home;
   - a lord's pool is lost to a confederation;
   - the grudge cycle resolves on its own mid-period.

   The card is still on show. The till must refuse it as `"unavailable"`, and no favour is taken. Pinned in Task 2 (the till re-reads `needs`) and Task 5 (the Reckoning after the cycle drops).
2. **Race differences off in a running save.**
   - No race card is drawn, and rule 2 never forces one.
   - No earning pays.
   - Every twist reads the plain setting.

   Pinned in Tasks 1, 2, 3 and 10.
3. **A purchase that grants a pool an earning listens to** (Strike Lines from the Book, Tales of Valour).
   - It never pays itself, whether the engine raises the change inside the call or later.
   - A leftover record never eats the next turn's real earning.

   Pinned in Tasks 2, 7 and 10.
4. **A campaign without CA's script globals** (Realm of Chaos, the prologue): `hellforge`, `grudge_cycle`, `Blessing_Character_Won`, `chivalry` and the politics globals may be nil.
   - The service is never drawn.
   - A payload that throws anyway is refunded.

   Pinned in Tasks 2 and 5-8.
5. **A rival of the player's race.**
   - It never holds a service whose `needs` asks for a human (the Reckoning, the Supply Train).
   - It aims army services only at its own armies.
   - It earns by its race's route where CA raises the event for it.

   Pinned in Tasks 5, 6 and 10.

## File map

| File | Change |
|---|---|
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (LF) | `race_differences`, `GG.TWISTS`, `GG.setting_for` and its call sites; `GG.CHAR_KINDS`, `GG.needs_ok`, the `resource` / `race` / `race_army` kinds and the purchase record; rule 2 of the draw; 29 race rows and their `GG.RACE_FIRE` / `GG.RACE_NEEDS` / `GG.RACE_TARGET_OK`; Slave Tithe payouts; earn routes and five listeners |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua` (CRLF) | `GGAI.pick_target` through `GG.CHAR_KINDS`; `bounty_fail_cost` takes the faction |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` (CRLF) | `GG.CHAR_KINDS` in the pick; `race_army` hint; `"unavailable"` on the card; race label (`GGUI.card_body`); `earn` Log line under Yours; `GGUI.HELP_PAGES = 6`; the two twisted reads |
| `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` (CRLF) | `race_differences` checkbox |
| `tools/gen_great_guilds.py` (LF) | race rows' home (flavour merge, `drawn_in`, shape and flavour checks), mirror fields, `check_race_services`, `check_race_resources`, `check_race_keys`, `check_race_mirror`; 29 rows with names and text; the earn, twist, label and "unavailable" loc; Help page 6 per flavour; selftest counts |
| `tools/_guilds_bounty_harness.lua` (LF) | stubs for the new engine calls; the `race` helper; tests for Tasks 1-10 |
| `tools/_guilds_harness.lua` (LF) | panel tests: the `race_army` hint and pick, `GGUI.card_body`, the `earn` Log line |
| `tools/mutate_guilds.py` (LF) | the stage-2 mutants |

**Test placement** is the same as stage 1:
- Model and AI tests go at the end of the bounty harness, under `-- RACES:` headers, before `print("bounty harness ok")`, one rule per `do ... end` block. The bounty harness stubs the world every new test needs and registers the real listeners in `HANDLERS`.
- Panel tests go in `_guilds_harness.lua`, each in a `;(function() ... end)()` block before `print("harness ok")`. That file is at Lua's 200-local ceiling.

---

### Task 1: The race switch and the twists

**Files:**
- Modify: `zzz_derpy_guilds.lua`: `GG.TUNE_DEFAULTS`, `GG.TUNE_ORDER`, after `GG.setting`, `GG.rival_loss`, `GG.rival_cost`, `GG.decay_amount` and its three callers, `GG.turn_start_charge`, `GG.demand_tick`, `GG.pay_demand`, `GG.bounty_failed`, `GG.bounty_fail_cost`, `GG.grant`, `GG.service_cost`.
- Modify: `zzz_derpy_guilds_ai.lua` (`GGAI.settle_bounty`) and `zzz_derpy_guilds_ui.lua` (the rank line's upkeep, the bounty card's fail cost).
- Modify: `script/mct/settings/derpy_great_guilds.lua`.
- Test: `tools/_guilds_bounty_harness.lua`.

**Interfaces:**
- Produces:
  - `GG.race_on() -> bool`;
  - `GG.TWISTS[culture] = {key = percent}`;
  - `GG.twist(faction, key) -> percent` (100 when nothing is bent);
  - `GG.setting_for(faction, key) -> number`;
  - `GG.rival_loss(amount, faction)`, `GG.decay_amount(rank, faction)`, `GG.bounty_fail_cost(o, faction)`. Each second argument is new and optional; nil reads the plain rule.
- Produces for the harness:
  - `race(culture)`: a `W.reset()` world whose human `me` is of that culture;
  - `W.reset` also clears `GG.player_cultures_cache`.

- [ ] **Step 1: The harness helper and failing tests**

In `W.reset`, after `GG.humans = nil`, add:

```lua
    -- The player's culture is cached on first read; a test that changes it must drop it.
    GG.player_cultures_cache = nil
```

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------------ RACES: the twists --
-- A player of `culture`: the world reset, the human "me" of that race.
local function race(culture)
    W.reset()
    F.me.culture = culture
end

do
    -- EACH RACE'S RULE, read through GG.setting_for (spec §7), on the default settings:
    -- demand_every 12, demand_reward 120, demand_penalty 60, rate_bounty_fail 100,
    -- rate_rivalry 40, rate_decay 100.
    local want = {
        ["wh3_dlc23_chd_chaos_dwarfs"] = {demand_every = 8, demand_reward = 180},
        ["wh_main_dwf_dwarfs"]         = {rate_bounty_fail = 150, demand_penalty = 120},
        ["wh_main_emp_empire"]         = {rate_rivalry = 60},
        ["wh3_main_ksl_kislev"]        = {rate_decay = 50},
        ["wh_main_brt_bretonnia"]      = {demand_reward = 180, demand_penalty = 120},
        ["wh3_main_cth_cathay"]        = {rate_rivalry = 20},
        ["wh2_main_def_dark_elves"]    = {rate_rivalry = 60},
        ["wh2_main_hef_high_elves"]    = {},
    }
    for culture, bent in pairs(want) do
        race(culture)
        for _, key in ipairs({"demand_every", "demand_reward", "demand_penalty",
                              "rate_bounty_fail", "rate_rivalry", "rate_decay"}) do
            local expect = bent[key] or GG.TUNE_DEFAULTS[key]
            local got = GG.setting_for("me", key)
            assert(got == expect, culture .. " " .. key .. " reads " .. tostring(got)
                   .. ", want " .. expect)
        end
    end
    ok("each race bends its own rule and no other")
end

do
    -- 0 STAYS 0, A RULE ON NEVER ROUNDS TO OFF, AND OFF IS THE PLAIN RULE.
    race("wh3_main_cth_cathay")
    GG.TUNE.rate_rivalry = 0
    assert(GG.setting_for("me", "rate_rivalry") == 0, "a rivalry switched off stays off")
    GG.TUNE.rate_rivalry = 1
    assert(GG.setting_for("me", "rate_rivalry") == 1, "half of 1 is still on, not 0")
    GG.TUNE.rate_rivalry = 40
    assert(GG.setting_for(nil, "rate_rivalry") == 40, "no faction: the plain rule")
    GG.TUNE.race_differences = false
    assert(GG.setting_for("me", "rate_rivalry") == 40, "race differences off: the plain rule")
    ok("a twist keeps 0 at 0, never rounds a rule off, and stops with race differences")
end

do
    -- WHERE THE TWISTS BITE: rivalry, upkeep, a failed bounty, a paid demand, the favour
    -- cap and a hostile service's price, each read for the faction it applies to.
    race("wh3_main_cth_cathay")
    assert(GG.rival_loss(100, "me") == 20, "Cathay's rival takes half: "
           .. GG.rival_loss(100, "me"))
    assert(GG.rival_loss(100) == 40, "a loss with no faction is the plain rule")
    race("wh3_main_ksl_kislev")
    assert(GG.decay_amount(4, "me") == 2, "Kislev's upkeep at rank 4 is halved")
    race("wh_main_dwf_dwarfs")
    assert(GG.bounty_fail_cost({rep = 80}, "me") == 120, "a Dwarf's failed bounty is 150%")
    race("wh3_dlc23_chd_chaos_dwarfs")
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 100, fav = 0} end
    GG.demands.me = {guild = "brass", kind = "tribute", amount = 1, due = 99}
    F.me.treasury = 99999
    assert(GG.pay_demand("me"), "the demand is paid")
    assert(GG.get("me", "brass") == 280, "Hashut's tithe: a paid demand is 180, got "
           .. GG.get("me", "brass"))
    race("wh2_main_hef_high_elves")
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 100, fav = 500} end
    GG.grant("me", "brass", 50, "other")
    assert(select(2, GG.get("me", "brass")) == 300, "High Elves hold 3x the rank's "
           .. "threshold in favour, got " .. select(2, GG.get("me", "brass")))
    race("wh2_main_def_dark_elves")
    local price, mod = GG.service_cost("me", "sow_discord")
    assert(price == 112 and mod == -26, "a Dark Elf's hostile service costs 75%, got "
           .. price .. " at " .. mod .. "%")
    ok("the twists bite where each rule is applied")
end
```

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1, `attempt to call field 'setting_for' (a nil value)`.

- [ ] **Step 3: The switch and the table**

In `GG.TUNE_DEFAULTS`, directly after `rotate_turns = 10,`:

```lua
    -- RACE DIFFERENCES (2026-09-29, spec §8). Off: no race services, no race earnings, and
    -- no race bends a rule - every race plays alike, and still gets the changing services.
    race_differences = true,
```

In `GG.TUNE_ORDER`, directly after `"rotate_turns",`, add `"race_differences",`.

Directly after the `GG.setting` function, add:

```lua
-- RACE DIFFERENCES ON: a switch like the others, read on every preset.
function GG.race_on()
    return GG.setting("race_differences") ~= false
end

-- EACH RACE BENDS ONE RULE (spec §7), as whole percentages of a setting - the game's Lua
-- is float32, so 1.5 is never written. hostile_price and favour_cap are not settings;
-- they are read by GG.service_cost and GG.grant. Mirrored by TWISTS in
-- tools/gen_great_guilds.py, whose Help page names each rule; check_race_mirror compares
-- the two.
GG.TWISTS = {
    ["wh3_dlc23_chd_chaos_dwarfs"] = {demand_every = 67, demand_reward = 150},
    ["wh_main_dwf_dwarfs"]         = {rate_bounty_fail = 150, demand_penalty = 200},
    ["wh_main_emp_empire"]         = {rate_rivalry = 150},
    ["wh3_main_ksl_kislev"]        = {rate_decay = 50},
    ["wh_main_brt_bretonnia"]      = {demand_reward = 150, demand_penalty = 200},
    ["wh3_main_cth_cathay"]        = {rate_rivalry = 50},
    ["wh2_main_def_dark_elves"]    = {rate_rivalry = 150, hostile_price = 75},
    ["wh2_main_hef_high_elves"]    = {favour_cap = 150},
}

-- The percentage `faction`'s race puts on `key`: 100 when it bends nothing, when race
-- differences are off, and for a faction outside the race.
function GG.twist(faction, key)
    if not faction or not GG.race_on() then return 100 end
    local t = GG.TWISTS[GG.culture_of(faction) or ""]
    return (t and t[key]) or 100
end

-- A SETTING AS ONE FACTION PLAYS IT. 0 stays 0 - a rule switched off is off for every
-- race - and a rule switched on never rounds down to off.
function GG.setting_for(faction, key)
    local v = GG.setting(key)
    local p = GG.twist(faction, key)
    if type(v) ~= "number" or v <= 0 or p == 100 then return v end
    local n = math.floor(v * p / 100)
    if n < 1 then n = 1 end
    return n
end
```

- [ ] **Step 4: The call sites**

Each change is exact.

In `GG.rival_loss`, replace

```lua
function GG.rival_loss(amount)
    local share = GG.setting("rate_rivalry")
```

with

```lua
-- `faction` is whose rivalry it is: each race bends the share (GG.setting_for).
function GG.rival_loss(amount, faction)
    local share = GG.setting_for(faction, "rate_rivalry")
```

In `GG.rival_cost`:
- `    local share = GG.setting("rate_rivalry")` becomes `    local share = GG.setting_for(faction, "rate_rivalry")`.
- `    local loss = GG.rival_loss(amount)` becomes `    local loss = GG.rival_loss(amount, faction)`.
- `    local floor_at = (GG.RANKS[rank] or 0) + GG.decay_amount(rank)` becomes `    local floor_at = (GG.RANKS[rank] or 0) + GG.decay_amount(rank, faction)`.

Replace

```lua
function GG.decay_amount(rank)
    local share = GG.setting("rate_decay")
```

with

```lua
function GG.decay_amount(rank, faction)
    local share = GG.setting_for(faction, "rate_decay")
```

In `GG.decay`, `GG.decay_amount(GG.rank_of(t.rep))` becomes `GG.decay_amount(GG.rank_of(t.rep), faction)`.

In `GG.hold_lead`:
- `GG.decay_amount(GG.rank_of(top_rep))` becomes `GG.decay_amount(GG.rank_of(top_rep), top)`.
- `GG.decay_amount(GG.rank_of(rows[i].rep))` becomes `GG.decay_amount(GG.rank_of(rows[i].rep), held)`.

In `GG.turn_start_charge`, `return GG.rival_loss(GG.turn_start_pay(faction, "brass"))` becomes `return GG.rival_loss(GG.turn_start_pay(faction, "brass"), faction)`.

In `GG.demand_tick`:
- `GG.setting("demand_penalty")` becomes `GG.setting_for(faction, "demand_penalty")`.
- `GG.setting("demand_every")` becomes `GG.setting_for(faction, "demand_every")`.

In `GG.pay_demand`, `GG.setting("demand_reward")` becomes `GG.setting_for(faction, "demand_reward")`.

In `GG.bounty_failed`, `local cost = GG.bounty_fail_cost(o)` becomes `local cost = GG.bounty_fail_cost(o, faction)`. Replace

```lua
function GG.bounty_fail_cost(o)
    local share = GG.setting("rate_bounty_fail")
```

with

```lua
function GG.bounty_fail_cost(o, faction)
    local share = GG.setting_for(faction, "rate_bounty_fail")
```

In `GG.grant`, directly after `    if cap < 200 then cap = 200 end`, add:

```lua
    -- The High Elves' ancient houses hold more (GG.TWISTS favour_cap).
    cap = math.floor(cap * GG.twist(faction, "favour_cap") / 100)
```

In `GG.service_cost`, replace

```lua
    return math.floor(svc.cost * (100 + mod) / 100), mod
```

with

```lua
    local price = math.floor(svc.cost * (100 + mod) / 100)
    -- A SERVICE AIMED AT AN ENEMY, at the Dark Elves' price (GG.TWISTS hostile_price).
    -- After the clamps, so the twist is never lost to them, and the modifier returned is
    -- the whole difference, so the card's tooltip explains the number it shows.
    local p = (svc.hostile or svc.kind == "enemy_settlement")
              and GG.twist(faction, "hostile_price") or 100
    if p ~= 100 then
        price = math.floor(price * p / 100)
        mod = math.floor(price * 100 / svc.cost) - 100
    end
    return price, mod
```

In `zzz_derpy_guilds_ai.lua` `GGAI.settle_bounty`, `GG.penalise(faction, o.guild, GG.bounty_fail_cost(o))` becomes `GG.penalise(faction, o.guild, GG.bounty_fail_cost(o, faction))`.

In `zzz_derpy_guilds_ui.lua`:
- `local lose = GG.bounty_fail_cost(o)` becomes `local lose = GG.bounty_fail_cost(o, faction)`.
- `upkeep = GG.decay_amount(rank)` becomes `upkeep = GG.decay_amount(rank, faction)`.

- [ ] **Step 5: The MCT checkbox**

In `script/mct/settings/derpy_great_guilds.lua`, directly after the line `if IN_CAMPAIGN then o_rot:set_locked(true, LOCK_REASON) end`:

```lua

local o_race = m:add_new_option("race_differences", "checkbox")
o_race:set_text("Race differences")
o_race:set_tooltip_text("Each race's guilds offer services of their own, earn from something "
    .. "only that race does, and bend one rule. Off: every race plays alike, and still gets "
    .. "the changing services.")
o_race:set_default_value(true)
o_race:set_assigned_section("systems")
if IN_CAMPAIGN then o_race:set_locked(true, LOCK_REASON) end
```

- [ ] **Step 6: Run everything**

Run both harnesses, then the generator: `--selftest`, then `--check`.

Expected:
- `bounty harness ok` and `harness ok`, both exit 0.
- Selftest ok; check exit 0.
- Any other failure is a pre-existing test that assumed a Chaos Dwarf's plain demand. Pin it (Global Constraints) and ledger it.

`$ py tools/gen_great_guilds.py --check` must still pass. `race_differences` is a boolean, so `check_presets` keeps it out of `PRESET_OWNED`.

- [ ] **Step 7: Ledger**

`Task 1: complete (both harnesses ok, generator check 0; RED: setting_for nil; pinned: <list>)`.

---

### Task 2: The catalogue takes race rows

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - `GG.pool_ok`, `GG.can_buy`, `GG.needs_target`, `GG.target_ok`, `GG.payload`, `GG.target_from_wire`;
  - a new section after `GG.service`.
- Modify: `zzz_derpy_guilds_ai.lua` (`GGAI.pick_target`) and `zzz_derpy_guilds_ui.lua` (`GGUI.pick_target`, `GGUI.target_hint`, `GGUI.draw_card`).
- Modify: `tools/gen_great_guilds.py`: two UI loc lines.
- Test: both harnesses.

**Interfaces:**
- Consumes: `GG.race_on()` and `race(culture)` (Task 1).
- Produces:
  - `GG.CHAR_KINDS[kind] -> true` for `unit`, `army`, `ranks` and `race_army`;
  - `GG.has_resource(faction, key) -> bool`;
  - `GG.needs_ok(faction, s) -> bool`. It checks a `resource` row's pool, then `s.needs or GG.RACE_NEEDS[s.key]`.
  - `GG.RACE_FIRE[key] = function(faction, s, target)`;
  - `GG.RACE_NEEDS[key] = function(faction) -> bool`;
  - `GG.RACE_TARGET_OK[key] = function(faction, character) -> bool`;
  - `GG.note_self(faction, resource, n)`;
  - `GG.take_self(faction, resource, amount) -> amount left`;
  - can_buy's new refusal `"unavailable"`;
  - row fields `race`, `resource`, `factor`, `value2`, `units` and `room`.
- Produces for the harness:
  - `with_race_rows(fn)` adds two fixture rows, `t_dwf_pool` (a Dwarf `resource` row on overseers rank 2) and `t_dwf_army` (a Dwarf `race_army` row on immortals rank 3);
  - `stock(key)` puts a service on me's card with rank and favour;
  - `in_pool(key, guild, rank)`;
  - `t.resources = {key = value}` on a harness faction;
  - `t.limit` on a harness character (its army's unit limit, default 20).

- [ ] **Step 1: Stubs**

In the bounty harness faction interface (`fi`'s `self` table), after `has_technology`:

```lua
        -- t.resources = {key = value}; a key it lacks is CA's null interface.
        pooled_resource_manager = function()
            return {resource = function(_, k)
                local v = (t.resources or {})[k]
                if v == nil then return NULL() end
                return {is_null_interface = function() return false end,
                        key = function() return k end,
                        value = function() return v end}
            end}
        end,
```

In `W.ci`'s `military_force` table, after `is_armed_citizenry`:

```lua
                    unit_count_limit = function() return t.limit or 20 end,
                    has_effect_bundle = function(_, b) return (t.force_bundles or {})[b] == true end,
```

In the `cm = { ... }` table, after `show_message_event`:

```lua
    faction_add_pooled_resource = function(_, f, res, factor, n) rec("pooled", f, res, factor, n) end,
```

In `W.reset`, after `GG.cards = {}`:

```lua
    GG.self_grants = {}
```

- [ ] **Step 2: Failing tests**

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------- RACES: the catalogue --
-- Two fixture rows, appended and removed around each test: a Dwarf pool grant and a
-- Dwarf army service. Neither ships.
local function with_race_rows(fn)
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_dwf_pool", guild = "overseers", rank = 2, cost = 50, cd = 8,
                          kind = "resource", resource = "t_res", factor = "t_factor",
                          value = 7, race = "wh_main_dwf_dwarfs"}
    GG.SERVICES[n + 2] = {key = "t_dwf_army", guild = "immortals", rank = 3, cost = 150,
                          cd = 12, kind = "race_army", race = "wh_main_dwf_dwarfs"}
    local okf, err = pcall(fn)
    GG.SERVICES[n + 2], GG.SERVICES[n + 1] = nil, nil
    GG.RACE_FIRE.t_dwf_army, GG.RACE_TARGET_OK.t_dwf_army = nil, nil
    GG.RACE_NEEDS.t_dwf_pool = nil
    if not okf then error(err, 0) end
end

local function in_pool(key, guild, rank)
    for _, s in ipairs(GG.pool("me", guild, rank)) do
        if s.key == key then return true end
    end
    return false
end

-- A service on me's card with every rank, ample favour and no cooldown, so only what the
-- test is about can refuse it.
local function stock(key)
    local s = GG.service(key)
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
    GG.cooldowns.me = {}
    GG.TUNE.lead_monopoly = false
    GG.cards.me = {turn = 1, keys = GG.cards_of("me")}
    for gi, g in ipairs(GG.GUILDS) do
        if g == s.guild then
            GG.cards.me.keys[(gi - 1) * #GG.CARD_RANKS + s.rank - 1] = key
        end
    end
    return s
end

do
    -- A RACE'S ROW IS IN ITS OWN RACE'S POOL and nobody else's (spec §3).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        assert(in_pool("t_dwf_pool", "overseers", 2), "a Dwarf draws the Dwarf row")
        race("wh_main_emp_empire")
        F.me.resources = {t_res = 0}
        assert(not in_pool("t_dwf_pool", "overseers", 2), "the Empire never draws it")
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        GG.TUNE.race_differences = false
        assert(not in_pool("t_dwf_pool", "overseers", 2), "race differences off: never")
    end)
    ok("a race service is drawn for its own race, and only with race differences on")
end

do
    -- A POOL GRANT NEEDS THE POOL. Without it the row is never drawn, and the till refuses
    -- it: a pool lost after the draw is the same case (Review Focus 1).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        assert(not in_pool("t_dwf_pool", "overseers", 2), "no pool, no draw")
        stock("t_dwf_pool")
        local okb, why = GG.can_buy("me", "t_dwf_pool")
        assert(not okb and why == "unavailable", "no pool, no sale: got " .. tostring(why))
        F.me.resources = {t_res = 0}
        assert(GG.can_buy("me", "t_dwf_pool"), "with the pool it sells")
        GG.RACE_NEEDS.t_dwf_pool = function() return false end
        local okn, whyn = GG.can_buy("me", "t_dwf_pool")
        assert(not okn and whyn == "unavailable", "a failed needs refuses at the till too")
    end)
    ok("a service whose hook is gone is neither drawn nor sold")
end

do
    -- THE PAYLOADS: a pool grant by faction KEY, recorded before it is made; a race call
    -- handed the faction, the row and the target.
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        GG.payload("me", GG.service("t_dwf_pool"), nil)
        local c = CALLS.pooled and CALLS.pooled[1]
        assert(c and c[1] == "me" and c[2] == "t_res" and c[3] == "t_factor" and c[4] == 7,
               "a pool grant takes the faction key, the pool, the factor and the value")
        assert(GG.take_self("me", "t_res", 7) == 0, "and was recorded as the buyer's own")
        local got
        GG.RACE_FIRE.t_dwf_army = function(f, s, t) got = {f, s.key, t} end
        GG.payload("me", GG.service("t_dwf_army"), 10)
        assert(got and got[1] == "me" and got[2] == "t_dwf_army" and got[3] == 10,
               "a race call gets the faction, the row and the target")
    end)
    ok("a pool grant and a race call reach the game as documented")
end

do
    -- A RACE CALL THAT IS MISSING OR THROWS IS REFUNDED, never charged for nothing.
    with_race_rows(function()
        worldA()
        F.me.culture = "wh_main_dwf_dwarfs"
        stock("t_dwf_army")
        local fav0 = select(2, GG.get("me", "immortals"))
        local okb, why = GG.buy("me", "t_dwf_army", 10)
        assert(not okb and why == "failed", "no race call: refused, got " .. tostring(why))
        assert(select(2, GG.get("me", "immortals")) == fav0, "and the favour is back")
        GG.RACE_FIRE.t_dwf_army = function() rec("fired") end
        assert(GG.buy("me", "t_dwf_army", 10), "with its call it sells")
        assert(CALLS.fired, "and the call ran")
    end)
    ok("a race call that is missing is refunded")
end

do
    -- A RACE ARMY SERVICE is aimed at the buyer's own army. It may ask for room and may ask
    -- more of the army. The wire, the panel's pick and the rivals' pick all treat it as one.
    with_race_rows(function()
        worldA()
        F.me.culture = "wh_main_dwf_dwarfs"
        local s = GG.service("t_dwf_army")
        assert(GG.needs_target(s), "it needs a target")
        assert(GG.target_ok("me", s, 10), "my lord's army is a target")
        assert(not GG.target_ok("me", s, 30), "an enemy's is not")
        s.room = true
        C["10"].units = 20
        assert(not GG.target_ok("me", s, 10), "room asked: a full army is refused")
        C["10"].units = 19
        assert(GG.target_ok("me", s, 10), "and one with room taken")
        s.room = nil
        GG.RACE_TARGET_OK.t_dwf_army = function(_, c) return c:command_queue_index() ~= 10 end
        assert(not GG.target_ok("me", s, 10), "the race's own check on the army is honoured")
        GG.RACE_TARGET_OK.t_dwf_army = nil
        assert(GG.target_from_wire("me", s, "10") == 10, "the wire carries it as a cqi")
        local t = GGAI.pick_target("me", s)
        assert(t ~= nil and GG.target_ok("me", s, t), "the rivals pick an army the till takes")
    end)
    ok("a race army service is judged like an army, room and its own check included")
end

do
    -- A PURCHASE NEVER PAYS ITS OWN EARNING, and a record never outlives its turn (spec §7).
    W.reset()
    TURN = 5
    GG.note_self("me", "t_res", 200)
    assert(GG.take_self("me", "t_res", 200) == 0, "the purchase's own change pays nothing")
    assert(GG.take_self("me", "t_res", 30) == 30, "and the record is spent once")
    GG.note_self("me", "t_res", 200)
    TURN = 6
    assert(GG.take_self("me", "t_res", 30) == 30, "last turn's record eats nothing")
    ok("a recorded purchase is subtracted once, and only in its own turn")
end
```

In `tools/_guilds_harness.lua`, before `print("harness ok")`:

```lua
;(function()
    -- RACE ARMY SERVICES ON THE PANEL (2026-09-29 stage 2): the hint names what is needed,
    -- and the pick takes the selected army through the till's own test.
    assert(GGUI.target_hint({kind = "race_army", room = true}) == "needs_army_room",
           "a race army service that needs room says so")
    assert(GGUI.target_hint({kind = "race_army"}) == "needs_army", "and one that does not")
    local prev_sel, prev_ok = GGUI.selected_force_cqi, GG.target_ok
    GGUI.selected_force_cqi = function() return 77 end
    GG.target_ok = function() return true end
    local got = GGUI.pick_target({key = "t_race", kind = "race_army"}, "x")
    GGUI.selected_force_cqi, GG.target_ok = prev_sel, prev_ok
    assert(got == 77, "the pick takes the selected army for a race army service, got "
           .. tostring(got))
end)()
```

- [ ] **Step 3: Run both harnesses and watch them fail**

Expected: both exit 1.
- The bounty harness fails on the first new block: `a Dwarf draws the Dwarf row`. Today every `race` row is refused.
- The main harness fails on `a race army service that needs room says so`.

- [ ] **Step 4: The machinery**

Directly after `function GG.service(key) ... end`, add:

```lua
-- ------------------------------------------------------------ race services --
-- WHAT A RACE'S OWN SERVICE CALLS (spec §6), one function per service whose payload is not
-- a plain pool grant. Keyed by service key, because a GG.SERVICES row stays on one line.
-- A function that throws is refunded by GG.buy. Each hook was read in CA's 9.0 scripts
-- and DB on 2026-09-29; the note beside each names where.
GG.RACE_FIRE = {}
-- What a race service needs of the world beyond its pool, read at the draw and at the
-- till (GG.needs_ok).
GG.RACE_NEEDS = {}
-- What a race_army service asks of the army it is aimed at, beyond being the buyer's own.
GG.RACE_TARGET_OK = {}

-- A POOL THE FACTION HOLDS. CA's resource(key) answers a null interface, not nil, for a
-- pool the faction lacks ("Null if not present").
function GG.has_resource(faction, key)
    local okr, yes = pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then return false end
        return not f:pooled_resource_manager():resource(key):is_null_interface()
    end)
    return okr and yes == true
end

-- WHAT THE SERVICE WORKS ON IS THERE. A pool grant needs the pool; a row's own check asks
-- the rest. Read at the draw and again at the till, because a period is ten turns and the
-- world moves: a caravan comes home, a confederation takes a pool. A throw is a no.
function GG.needs_ok(faction, s)
    if s.kind == "resource" and not GG.has_resource(faction, s.resource) then return false end
    local need = s.needs or GG.RACE_NEEDS[s.key]
    if need then
        local okn, yes = pcall(need, faction)
        if not okn or yes ~= true then return false end
    end
    return true
end

-- WHAT A PURCHASE IS ABOUT TO GRANT, so the race earning that listens to the same pool
-- does not pay for it (spec §7). The engine raises the change inside the call or soon
-- after, so the record is session memory for this turn only: one that outlived its turn
-- would eat a real earning.
GG.self_grants = GG.self_grants or {}

function GG.note_self(faction, resource, n)
    local k, turn = faction .. "|" .. resource, GG.turn_now()
    local r = GG.self_grants[k]
    if not r or r.turn ~= turn then r = {n = 0, turn = turn} end
    r.n = r.n + (n or 0)
    GG.self_grants[k] = r
end

-- The part of `amount` that was not the faction's own purchase. The record is spent once.
function GG.take_self(faction, resource, amount)
    local k = faction .. "|" .. resource
    local r = GG.self_grants[k]
    if not r then return amount end
    GG.self_grants[k] = nil
    if r.turn ~= GG.turn_now() then return amount end
    local left = amount - r.n
    if left < 0 then left = 0 end
    return left
end
```

Replace the body of `GG.pool_ok` with:

```lua
function GG.pool_ok(faction, s)
    -- A RACE'S OWN SERVICE, for that race alone and only while race differences are on.
    if s.race ~= nil and (not GG.race_on() or s.race ~= GG.culture_of(faction)) then
        return false
    end
    if (s.hostile or s.kind == "enemy_settlement")
       and GG.setting("hostile_services") == false then
        return false
    end
    return GG.needs_ok(faction, s)
end
```

Also change the comment above `GG.pool_ok` from `-- WHAT A CARD MAY DRAW. Stage 2 opens `race` rows; until then they are never drawn.` to `-- WHAT A CARD MAY DRAW.`

In `GG.can_buy`, directly before `    if GG.cooldown_left(faction, service_key) > 0 then return false, "cooldown" end`:

```lua
    -- WHAT IT WORKS ON IS STILL THERE: the draw asked, and the world has moved since.
    if not GG.needs_ok(faction, s) then return false, "unavailable" end
```

Directly before `function GG.needs_target(s)`, add:

```lua
-- THE KINDS AIMED AT A CHARACTER. The till, the wire, the panel's pick and the rivals'
-- pick all ask this, so a new character kind is one line here rather than five.
GG.CHAR_KINDS = {unit = true, army = true, ranks = true, race_army = true}
```

In `GG.needs_target`, replace

```lua
    return s.kind == "unit" or s.kind == "research" or s.kind == "shroud"
        or s.kind == "building" or s.kind == "army" or s.kind == "settlement"
        or s.kind == "enemy_settlement" or s.kind == "ranks"
```

with

```lua
    if GG.CHAR_KINDS[s.kind] then return true end
    return s.kind == "research" or s.kind == "shroud" or s.kind == "building"
        or s.kind == "settlement" or s.kind == "enemy_settlement"
```

In `GG.target_ok`:
- `        if s.kind == "army" or s.kind == "unit" or s.kind == "ranks" then` becomes `        if GG.CHAR_KINDS[s.kind] then`.
- Replace

```lua
            if s.kind ~= "unit" then return true end
```

with

```lua
            -- A RACE SERVICE MAY ASK MORE OF ITS ARMY (not already blessed, not led by the
            -- faction leader); a unit grant, and a row with `room`, needs space in it.
            local more = GG.RACE_TARGET_OK[s.key]
            if more and not more(faction, c) then return false end
            if s.kind ~= "unit" and not s.room then return true end
```

In `GG.payload`, directly before the `-- A GOLD OR RESEARCH SERVICE MAY CARRY A BUNDLE TOO` comment, add:

```lua
    elseif s.kind == "resource" then
        -- A FACTION POOL (spec §6), by faction KEY. Recorded first, so a race earning that
        -- listens to this pool does not pay for the purchase (GG.take_self).
        GG.note_self(faction, s.resource, s.value)
        cm:faction_add_pooled_resource(faction, s.resource, s.factor, s.value)

    elseif s.kind == "race" or s.kind == "race_army" then
        -- A RACE'S OWN CALL. A missing one throws, and GG.buy refunds the purchase.
        GG.RACE_FIRE[s.key](faction, s, target)
```

(It goes inside the `if ... elseif ... end` chain, after the `ranks` branch and before its `end`.)

In `GG.target_from_wire`, `    if s.kind == "unit" or s.kind == "army" or s.kind == "ranks" then return tonumber(t) end` becomes `    if GG.CHAR_KINDS[s.kind] then return tonumber(t) end`.

In `zzz_derpy_guilds_ai.lua` `GGAI.pick_target`, `    if s.kind == "unit" or s.kind == "army" or s.kind == "ranks" then` becomes `    if GG.CHAR_KINDS[s.kind] then`.

In `zzz_derpy_guilds_ui.lua`:
- `GGUI.pick_target`: `    if s.kind == "unit" or s.kind == "army" or s.kind == "ranks" then` becomes `    if GG.CHAR_KINDS[s.kind] then`.
- `GGUI.target_hint`: directly after `    if s.kind == "army" then return "needs_army" end`, add:

```lua
    if s.kind == "race_army" then return s.room and "needs_army_room" or "needs_army" end
```

- `GGUI.draw_card`: directly after the `why == "target"` label branch (`label = label .. "  [[col:red]]" .. GGUI.loc("needs_target_short") .. "[[/col]]"`), add:

```lua
    elseif not ok and why == "unavailable" then
        label = label .. "  [[col:red]]" .. GGUI.loc("unavailable_short") .. "[[/col]]"
```

- The tooltip chain in the same function: directly after the `why == "no_unit"` branch's body (`tip = tip .. "||" .. GGUI.loc("no_unit")`), add:

```lua
    elseif not ok and why == "unavailable" then
        tip = tip .. "||" .. GGUI.loc("unavailable")
```

In `tools/gen_great_guilds.py`, in the UI loc tuple list that holds `("log_rotation", ...)`, add after `("next_services_1", "New services next turn"),`:

```python
                      # GG.can_buy "unavailable" (stage 2): what the service works on
                      # has gone since the draw - a caravan home, a pool lost.
                      ("unavailable_short", "Unavailable"),
                      ("unavailable", "What this service works on is not there for you "
                                      "right now, so it cannot be bought."),
```

- [ ] **Step 5: Run both harnesses and the generator**

Expected:
- `bounty harness ok` and `harness ok`.
- `--check` exit 0; `check_ui_loc_keys` finds both new keys.
- The stage 1 catalogue test (`every card has three services`) still passes, because no shipped row carries `race` yet.

- [ ] **Step 6: Ledger**

`Task 2: complete (both harnesses ok, generator check 0; RED: race row refused, race_army hint)`.

---

### Task 3: Rule 2 of the draw - a race service always on show

**Files:**
- Modify: `zzz_derpy_guilds.lua` (`GG.draw_cards`; new `GG.show_race_service`)
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: `GG.race_on()`, `with_race_rows`, `race` (Tasks 1-2).
- Produces: `GG.show_race_service(faction, old, keys, pools)`. It rewrites `keys` in place.

- [ ] **Step 1: Failing tests**

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------- RACES: rule 2 of the draw --
local function race_on_show()
    local n = 0
    for _, k in ipairs(GG.cards_of("me")) do
        if GG.service(k).race then n = n + 1 end
    end
    return n
end

do
    -- EVERY ROLL OF 1 lands each card on its first pool row, which is shared - so rule 2
    -- must put one race service on show. With race differences off, none (spec §4).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        GG.draw_cards("me", 10, true)
        assert(race_on_show() == 1, "one race service on show, got " .. race_on_show())
        GG.TUNE.race_differences = false
        GG.draw_cards("me", 20, false)
        assert(race_on_show() == 0, "race differences off drew one")
    end)
    ok("a draw always shows a race service, and none with race differences off")
end

do
    -- THE CARD IS ROLLED among those whose pool holds one: roll 19 picks the second of
    -- two candidates, the overseers' rank-2 card (slot 13), not immortals rank 3 (slot 5).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        local calls = 0
        RANDOM = function(n)
            calls = calls + 1
            if calls == 19 then return n end
            return 1
        end
        GG.draw_cards("me", 10, true)
        local keys = GG.cards_of("me")
        assert(keys[13] == "t_dwf_pool", "slot 13 was rolled, got " .. tostring(keys[13]))
        assert(keys[5] ~= "t_dwf_army", "and only that card changed")
        assert(calls == 19, "18 card rolls and one for the card, got " .. calls)
    end)
    ok("the card rule 2 changes is rolled among those that can hold a race service")
end

do
    -- A DRAW THAT ALREADY SHOWS ONE ROLLS NO MORE: every roll lands on the last row,
    -- which for these two cards is the race row.
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        local calls = 0
        RANDOM = function(n) calls = calls + 1 return n end
        GG.draw_cards("me", 10, true)
        assert(race_on_show() == 2, "both race rows drawn by the rolls themselves")
        assert(calls == 18, "and no extra roll, got " .. calls)
    end)
    ok("rule 2 does nothing when the draw already shows a race service")
end
```

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1, `one race service on show, got 0`.

- [ ] **Step 3: The rule**

In `GG.draw_cards`:
- `    local old, keys, i = GG.cards_of(faction), {}, 0` becomes `    local old, keys, pools, i = GG.cards_of(faction), {}, {}, 0`.
- Directly after `            local pool = GG.pool(faction, GG.GUILDS[gi], GG.CARD_RANKS[ri])`, add `            pools[i] = pool`.
- Directly before `    GG.cards[faction] = {turn = turn, keys = keys}`, add `    GG.show_race_service(faction, old, keys, pools)`.

Directly after `GG.draw_cards`, add:

```lua
-- RULE 2 OF THE DRAW (spec §4): at least one race service on show. Without it about one
-- rotation in three shows none, and a race's own services are the point of the race. One
-- card, rolled among those whose pool holds one, is redrawn to a race service - not the
-- one it held last, when it has another. A draw that already shows one is left alone.
function GG.show_race_service(faction, old, keys, pools)
    if not GG.race_on() then return end
    local cands = {}
    for i = 1, #keys do
        local s = GG.service(keys[i])
        if s and s.race then return end
        local races = {}
        for j = 1, #(pools[i] or {}) do
            if pools[i][j].race then races[#races + 1] = pools[i][j] end
        end
        if #races > 0 then cands[#cands + 1] = {i = i, races = races} end
    end
    if #cands == 0 then return end
    local c = cands[GG.roll(#cands)]
    local fresh = {}
    for j = 1, #c.races do
        if c.races[j].key ~= old[c.i] then fresh[#fresh + 1] = c.races[j] end
    end
    if #fresh == 0 then fresh = c.races end
    keys[c.i] = fresh[GG.roll(#fresh)].key
end
```

- [ ] **Step 4: Run both harnesses**

Expected: `bounty harness ok` and `harness ok`.

- [ ] **Step 5: Ledger**

`Task 3: complete (both harnesses ok; RED: got 0)`.

---

### Task 4: The generator gives race rows a home

**Files:**
- Modify: `tools/gen_great_guilds.py`: `FLAVOURS[""]`, after the `POOL_NAMES` merge, `service_text`, `check_flavour_shape`, `_build_one`, `check_flavours`, `SERVICE_MIRROR_FIELDS`, `_MIRROR_FLAGS`, `check_service_mirror`, `check()`, the unit-key check, and `selftest`.

**Interfaces:**
- Produces:
  - `RACE_OF[culture] -> tag`;
  - `drawn_in(s, tag) -> bool`;
  - `RACE_KEYS` (a set) and `RACE_LOC` (the four loc keys of each race row);
  - `check_race_services()`;
  - `check_race_resources(lua=None)`;
  - `check_race_keys(lua=None)`;
  - `RACE_POOL_PAIRS`, the pool grants made in code rather than by a row;
  - `RACE_KEY_BLOCKS` and `RACE_KEY_SINGLES`. Later tasks add entries to these two;
  - generator row fields `race`, `resource`, `factor`, `value2`, `units`, `room` and `lord`, mirrored against the Lua except `lord`, which is Help text only.
- A race row's `name` and `text` are in its own race's words. It is emitted in that flavour only.

- [ ] **Step 1: Failing selftest**

In `selftest()`, directly before the line `    # KISLEV'S GUNNERY REACHES KISLEV'S GUNS.`:

```python
    # RACE ROWS (stage 2): a probe Empire pool row through the real emitter and checks.
    # It lands in the Empire's flavour only, the flavour checks stay clean, and a factor CA
    # never binds to the pool is reported.
    probe = {"key": "t_race_probe", "guild": "brass", "rank": 2, "cost": 50, "cd": 8,
             "kind": "resource", "race": "wh_main_emp_empire",
             "resource": "wh3_dlc25_emp_research", "factor": "other", "value": 10,
             "name": "Probe Grant", "text": "Adds {value} Schematics."}
    SERVICES.append(probe)
    RACE_KEYS.add("t_race_probe")
    RACE_LOC.update(p + "t_race_probe" for p in RACE_LOC_PREFIXES)
    FLAVOURS["_emp"]["services"]["t_race_probe"] = "Probe Grant"
    try:
        assert not check_flavour_shape(), check_flavour_shape()
        assert not check_flavours(), check_flavours()
        assert not check_race_services(), check_race_services()
        assert not [p for p in check_race_resources() if "t_race_probe" in p], \
            check_race_resources()
        assert any(r["key"] == "derpy_gg_service_name_t_race_probe_emp"
                   for r in build()["loc"]), "the Empire flavour names the probe"
        assert not any(r["key"].startswith("derpy_gg_service_name_t_race_probe")
                       and r["key"] != "derpy_gg_service_name_t_race_probe_emp"
                       for r in build()["loc"]), "no other flavour names a race row"
        probe["factor"] = "t_no_such_factor"
        assert any("t_race_probe" in p and "t_no_such_factor" in p
                   for p in check_race_resources()), "an unbound factor slipped by"
        probe["factor"] = "other"
        probe["cost"] = 75
        assert any("t_race_probe" in p for p in check_race_services()), \
            "a race row off its rank's price slipped by"
    finally:
        SERVICES.remove(probe)
        RACE_KEYS.discard("t_race_probe")
        RACE_LOC.difference_update(p + "t_race_probe" for p in RACE_LOC_PREFIXES)
        FLAVOURS["_emp"]["services"].pop("t_race_probe", None)
```

- [ ] **Step 2: Run the selftest and watch it fail**

Run `py tools/gen_great_guilds.py --selftest`.
Expected: `NameError: name 'RACE_KEYS' is not defined`.

- [ ] **Step 3: The home**

In `FLAVOURS[""]`, `"services": dict((s["key"], s["name"]) for s in SERVICES),` becomes

```python
        # SHARED rows only: a race row names itself in its own race's flavour, below.
        "services": dict((s["key"], s["name"]) for s in SERVICES if not s.get("race")),
```

Directly after the `POOL_NAMES` merge loop (`FLAVOURS[_tag]["services"].update(zip(POOL_KEYS, _names))`):

```python

# RACE SERVICES (stage 2, spec §6) are drawn for their own race only, so each is named and
# written in that race's flavour and emitted in no other. `name` and `text` on the row are
# in that race's words.
RACE_OF = dict((F["culture"], tag) for tag, F in FLAVOURS.items() if F["culture"])
RACE_KEYS = set(s["key"] for s in SERVICES if s.get("race"))
for _s in SERVICES:
    if _s.get("race"):
        FLAVOURS[RACE_OF[_s["race"]]]["services"][_s["key"]] = _s["name"]
# The four loc keys each service writes, so a race row's can be told from a shared one's.
RACE_LOC_PREFIXES = ("derpy_gg_service_name_", "derpy_gg_service_desc_",
                     "effect_bundles_localised_title_derpy_gg_svc_",
                     "effect_bundles_localised_description_derpy_gg_svc_")
RACE_LOC = set(p + k for k in RACE_KEYS for p in RACE_LOC_PREFIXES)


def drawn_in(s, tag):
    """Whether flavour `tag` can ever draw service `s`: a shared row always, a race row only
    in its own race's flavour."""
    return not s.get("race") or s["race"] == FLAVOURS[tag]["culture"]
```

`POOL_KEYS = [s["key"] for s in SERVICES[18:]]` must stay the 36 shared pool keys. Change it to `POOL_KEYS = [s["key"] for s in SERVICES[18:] if not s.get("race")]`.

In `service_text`, `    return text.format(turns=s.get("turns", 0), value=s.get("value", 0), **vals)` becomes `    return text.format(turns=s.get("turns", 0), value=s.get("value", 0), value2=s.get("value2", 0), **vals)`.

In `check_flavour_shape`, `            missing = sorted(set(base[part]) - set(F.get(part, {})))` becomes

```python
            # A race row lives in one flavour; every other flavour is not missing it.
            missing = sorted(set(k for k in base[part] if k not in RACE_KEYS)
                             - set(F.get(part, {})))
```

In `_build_one`, `    for s in SERVICES:` (the service loop, directly before `loc.append({"key": "derpy_gg_service_name_%s" % s["key"],`) becomes:

```python
    for s in SERVICES:
        if not drawn_in(s, tag):
            continue
```

In `check_flavours`:
- `    base_keys = set(r["key"] for r in one["loc"] if r["key"] not in patron_loc)` becomes `    base_keys = set(r["key"] for r in one["loc"] if r["key"] not in patron_loc and r["key"] not in RACE_LOC)`.
- `        got = set(r["key"] for r in t["loc"])` becomes

```python
        mine = set(tag_loc_key(k, tag) for k in RACE_LOC)
        got = set(r["key"] for r in t["loc"] if r["key"] not in mine)
```

- In the `for bk, rows in sorted(base_fx.items()):` loop, directly after `            if bk == PATRON_BUNDLE:\n                continue`, add:

```python
            if bk[len("derpy_gg_svc_"):] in RACE_KEYS:
                continue
```

Mirror fields:

```python
SERVICE_MIRROR_FIELDS = ("guild", "rank", "cost", "cd", "kind", "turns", "value",
                         "with_bundle", "heal", "hostile", "race", "resource", "factor",
                         "value2", "units", "room")
# A flag absent on one side is false there, as Lua reads a missing field.
_MIRROR_FLAGS = ("with_bundle", "heal", "hostile", "room")
```

In `check_service_mirror`, `            elif (a is None) != (b is None) and f in ("value", "turns"):` becomes `            elif (a is None) != (b is None) and f in ("value", "turns", "race", "resource", "factor", "value2", "units"):`.

Directly after `check_service_mirror`, add:

```python
# ---------------------------------------------------------------- race checks ---
RACE_PRICE = {2: (50, 8), 3: (150, 12), 4: (400, 16)}
RACE_KINDS = ("resource", "race", "race_army", "bundle", "settlement")


def check_race_services():
    """The race rows' shape (spec §3, §6).

    Each needs a race this file writes a flavour for, the price and cooldown of its rank,
    a known kind, and a name and text in its own race's words.
    """
    out = []
    for s in SERVICES:
        if not s.get("race"):
            continue
        k = s["key"]
        tag = RACE_OF.get(s["race"])
        if tag is None:
            out.append("%s is for %r, a race with no flavour here, so it is never drawn"
                       % (k, s["race"]))
            continue
        if (s["cost"], s["cd"]) != RACE_PRICE.get(s["rank"]):
            out.append("%s costs %d with a %d-turn cooldown; rank %d is %r"
                       % (k, s["cost"], s["cd"], s["rank"], RACE_PRICE.get(s["rank"])))
        if s["kind"] not in RACE_KINDS:
            out.append("%s has kind %r, which no race payload handles" % (k, s["kind"]))
        if not s.get("text") or not FLAVOURS[tag]["services"].get(k):
            out.append("%s has no name or no text in the %s flavour" % (k, tag or "chd"))
        if s["kind"] == "resource" and not (s.get("resource") and s.get("factor")
                                            and s.get("value", 0) > 0):
            out.append("%s is a pool grant without a pool, a factor and a positive value" % k)
        if s["kind"] in ("bundle", "settlement") and not (s.get("effects") and s.get("turns")):
            out.append("%s is a bundle with no effects or no turns" % k)
    return out


# POOLS GRANTED IN CODE THROUGH A TRANSACTION, where the pool is an object rather than a
# key the scan below can read. Every other grant is a row or a literal
# cm:faction_add_pooled_resource call in the model Lua, and both are read.
RACE_POOL_PAIRS = []


def check_race_resources(lua=None):
    """Every pool a service grants must exist, and CA must bind the factor to it with room
    for a positive grant. A grant through a factor the pool does not take is silently
    nothing (spec §11). Covers the rows, RACE_POOL_PAIRS, and every literal pair in the
    model Lua."""
    if lua is None:
        lua = io.open(MODEL_LUA, encoding="utf-8").read()
    pairs = [(s["resource"], s["factor"], s["key"]) for s in SERVICES
             if s["kind"] == "resource"]
    pairs += [(r, f, "RACE_POOL_PAIRS") for r, f in RACE_POOL_PAIRS]
    pairs += [(r, f, "the model Lua") for r, f in re.findall(
        r'faction_add_pooled_resource\(\s*[^,()]+,\s*"([^"]+)",\s*"([^"]+)"', lua)]
    pools = set(r["key"] for r in live_rows("pooled_resources"))
    junctions = live_rows("pooled_resource_factor_junctions")
    out = []
    for r, f, where in pairs:
        if r not in pools:
            out.append("%s grants %s, which is not a pooled resource" % (where, r))
            continue
        rows = [j for j in junctions if j["resource"] == r and j["factor"] == f]
        if not rows:
            out.append("%s grants %s through factor %s, which CA never binds to it - the "
                       "grant is nothing" % (where, r, f))
        elif max(int(j["maximum"]) for j in rows) <= 0:
            out.append("%s grants %s through factor %s, which allows no positive grant"
                       % (where, r, f))
    return out


# KEYS A RACE SERVICE NAMES IN CODE, read out of the Lua and checked against CA's tables -
# a typo'd key fails silently in game. A block is `GG.<NAME> = { "key", ... }`; a single is
# `GG.<NAME> = "key"`. Each names the table its keys must be in. Later tasks add entries.
RACE_KEY_BLOCKS = {}
RACE_KEY_SINGLES = {}


def check_race_keys(lua=None):
    if lua is None:
        lua = io.open(MODEL_LUA, encoding="utf-8").read()
    out = []
    for name, table in sorted(RACE_KEY_BLOCKS.items()):
        m = re.search(r"^GG\.%s = \{(.*?)\n\}" % name, lua, re.S | re.M)
        if not m:
            out.append("GG.%s is not declared in the model Lua" % name)
            continue
        have = set(str(r.get("key", r.get("unit", ""))) for r in live_rows(table))
        for k in re.findall(r'"([^"]+)"', m.group(1)):
            if k not in have:
                out.append("GG.%s names %s, which is not in %s" % (name, k, table))
    for name, table in sorted(RACE_KEY_SINGLES.items()):
        m = re.search(r'^GG\.%s = "([^"]+)"' % name, lua, re.M)
        if not m:
            out.append("GG.%s is not declared in the model Lua" % name)
            continue
        if m.group(1) not in set(r["key"] for r in live_rows(table)):
            out.append("GG.%s is %s, which is not in %s" % (name, m.group(1), table))
    return out
```

In `check()`, directly after `    out += check_service_mirror()`:

```python
    out += check_race_services()
    out += check_race_resources()
    out += check_race_keys()
```

In the unit-key block of `check()`, replace

```python
        for s in SERVICES:
            u = s.get("unit")
            if u and u not in known_units:
                out.append("unit key not in main_units: %s (%s)" % (u, s["key"]))
```

with

```python
        for s in SERVICES:
            for u in [s.get("unit")] + [x for x in s.get("units", "").split(",") if x]:
                if u and u not in known_units:
                    out.append("unit key not in main_units: %s (%s)" % (u, s["key"]))
```

- [ ] **Step 4: The selftest counts, restated for shared rows**

In `selftest()`:
- Replace the two lines `    assert len(SERVICES) == 54, ...` and `    assert len(set(s["key"] for s in SERVICES)) == 54, ...` with

```python
    shared = [s for s in SERVICES if not s.get("race")]
    assert len(shared) == 54, "54 shared services, got %d" % len(shared)
    assert len(set(s["key"] for s in SERVICES)) == len(SERVICES), "service keys unique"
```

- In the per-guild loop, `        mine = [s for s in SERVICES if s["guild"] == g]` becomes `        mine = [s for s in shared if s["guild"] == g]`.
- `    bundled = [s for s in SERVICES if s["kind"] == "bundle"]` becomes `    bundled = [s for s in shared if s["kind"] == "bundle"]`.
- `    minted = [s for s in SERVICES if s.get("effects")]` becomes `    minted = [s for s in SERVICES if s.get("effects") and drawn_in(s, "")]`.
- `    assert len(LEAD_SERVICES) == 3 * len(GUILDS), (` becomes `    assert len([k for k in LEAD_SERVICES if k not in RACE_KEYS]) == 3 * len(GUILDS), (`.
- In the kind assertion, add `"resource", "race", "race_army"` to the tuple.
- `    service_extra = sum(len(s["effects"]) - 1 for s in SERVICES if s.get("effects"))` becomes `    service_extra = sum(len(s["effects"]) - 1 for s in SERVICES if s.get("effects") and drawn_in(s, ""))`.
- `named = dict(... for s in SERVICES if s["kind"] in by_kind)` is harmless: it names bundles the CHD pass does not emit. Leave it.

- [ ] **Step 5: Run the selftest and the check**

Run `py tools/gen_great_guilds.py --selftest`, then `--check`.
Expected: `selftest ok: 6 guilds, 54 services, ...` (the counts unchanged), and check exit 0.

- [ ] **Step 6: Ledger**

`Task 4: complete (selftest ok, check 0; RED: RACE_KEYS undefined)`.

---

### Task 5: Chaos Dwarfs and Dwarfs

Six rows. CA's evidence:
- Conclave Favour: `tower_of_zharr.lua:606` makes the same call. Crossing 75 opens the Tower for a human (`:452-465`); that is the Tower's own rule.
- Hell-Forge Allotment: the table at the top of this plan.
- Labour Gangs: `labour_loss.lua:40-49`, the same shape. Labour is per FACTION-province: `faction:provinces()`, never `region:province()`.
- High King's Decree: `dwf_underdeeps` is "High King Decrees", one per Great Gate (`underdeep.lua:91`). CA grants it through `underdeep_faction` for techs and skills.
- Strike Lines: `settled` is the only factor for grudge points. CA's cycle counts every change (`grudge_cycles.lua:1108-1121`).
- Call the Reckoning:
  - `grudge_cycle` is global (`grudge_cycles.lua:7`), and `faction_times` is saved by CA.
  - Resolving pays `get_current_grudge_level`. Level 5 is the tracker at 100, not delayed, with the world minimum met (`:1385-1398`). Level 1 is a penalty.
  - The cycle runs for human Dwarfs only, and not with the bonus value `dwf_grudge_feature_off` set.

**Files:**
- Modify: `zzz_derpy_guilds.lua`: 6 rows at the end of `GG.SERVICES`; the Chaos Dwarf and Dwarf block after `GG.take_self`.
- Modify: `tools/gen_great_guilds.py`: 6 rows at the end of `SERVICES`; `RACE_POOL_PAIRS`; `RACE_KEY_BLOCKS`.
- Test: `tools/_guilds_bounty_harness.lua`.

**Interfaces:**
- Consumes: the Task 2 kinds and tables; `stock`, `race` and `in_pool`.
- Produces: rows `conclave_favour`, `hellforge_allotment`, `labour_gangs`, `high_kings_decree`, `strike_lines`, `call_reckoning`; `GG.HELLFORGE_CAPS`; `GG.HELLFORGE_INCIDENT_FIX`.

- [ ] **Step 1: Stubs and failing tests**

In `fi`'s `self` table, after `pooled_resource_manager`:

```lua
        -- t.provinces = {{key = "p1", labour = true}, ...}: a faction-province's labour pool.
        provinces = function()
            local out = {}
            for _, p in ipairs(t.provinces or {}) do
                out[#out + 1] = {pooled_resource_manager = function()
                    return {resource = function(_, k)
                        if k ~= "wh3_dlc23_chd_labour" or not p.labour then return NULL() end
                        return {is_null_interface = function() return false end,
                                key = function() return k end, province = p.key}
                    end}
                end}
            end
            return LIST(out)
        end,
```

In `cm = { ... }`, after `faction_add_pooled_resource`:

```lua
    pooled_resource_factor_transaction = function(_, res, factor, n)
        rec("transaction", res.province, res:key(), factor, n)
    end,
    trigger_incident = function(_, f, k, now) rec("incident", f, k, now) end,
    get_factions_bonus_value = function(_, f, k) return (BONUS or {})[f .. "|" .. k] or 0 end,
```

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------ RACES: Chaos Dwarfs and Dwarfs --
local CHD, DWF = "wh3_dlc23_chd_chaos_dwarfs", "wh_main_dwf_dwarfs"

do
    -- CONCLAVE FAVOUR, HIGH KING'S DECREE AND STRIKE LINES are pool grants on the pool CA
    -- itself grants through.
    race(CHD)
    F.me.resources = {wh3_dlc23_chd_conclave_influence = 0}
    stock("conclave_favour")
    assert(GG.buy("me", "conclave_favour"), "Conclave Favour sells")
    local c = CALLS.pooled[1]
    assert(c[2] == "wh3_dlc23_chd_conclave_influence"
           and c[3] == "wh3_dlc23_chd_conclave_influence_gained_events" and c[4] == 40,
           "Conclave Favour: 40 influence through the events factor")
    race(DWF)
    F.me.resources = {dwf_underdeeps = 0, wh3_dlc25_dwf_grudge_points = 0}
    stock("high_kings_decree")
    assert(GG.buy("me", "high_kings_decree"), "the Decree sells")
    stock("strike_lines")
    assert(GG.buy("me", "strike_lines"), "Strike Lines sells")
    assert(CALLS.pooled[1][2] == "dwf_underdeeps" and CALLS.pooled[1][4] == 1,
           "one High King Decree")
    assert(CALLS.pooled[2][2] == "wh3_dlc25_dwf_grudge_points"
           and CALLS.pooled[2][3] == "settled" and CALLS.pooled[2][4] == 200,
           "200 grudge points through settled")
    assert(GG.take_self("me", "wh3_dlc25_dwf_grudge_points", 200) == 0,
           "and the grudge points are recorded as the buyer's own")
    ok("the Chaos Dwarf and Dwarf pool grants reach CA's pools")
end

do
    -- HELL-FORGE ALLOTMENT: CA's own +1, never a ritual; the Tower's message, the
    -- blunderbusses' by its real key; nothing without CA's global.
    race(CHD)
    assert(not in_pool("hellforge_allotment", "daemonsmiths", 3), "no hellforge, no draw")
    local seen = {}
    hellforge = {unit_cap_modifiers_bundle_string = "wh3_dlc23_bundle_chd_unit_cap_rituals",
                 modify_unit_cap = function(_, rk, f, b) seen[#seen + 1] = {rk, f:name(), b} end}
    assert(in_pool("hellforge_allotment", "daemonsmiths", 3), "with it, drawn")
    RANDOM = function(n) return n end        -- the last cap: the blunderbusses
    stock("hellforge_allotment")
    assert(GG.buy("me", "hellforge_allotment"), "it sells")
    hellforge = nil
    assert(seen[1] and seen[1][1] == "wh3_dlc23_chd_ritual_unit_cap_chaos_dwarf_blunderbusses"
           and seen[1][2] == "me" and seen[1][3] == "wh3_dlc23_bundle_chd_unit_cap_rituals",
           "modify_unit_cap(ritual, faction interface, CA's cap bundle)")
    assert(CALLS.incident[1][2]
           == "wh3_dlc23_chd_toz_cap_wh3_dlc23_chd_ritual_unit_cap_dwarf_blunderbusses",
           "the blunderbusses' message by its real key")
    -- No ritual check here: cm has no perform_ritual stub, so a call to it would throw
    -- and the buy above would have been refunded.
    ok("Hell-Forge Allotment raises one cap through CA's own call")
end

do
    -- LABOUR GANGS: every province's own labour, skipping one without the pool.
    race(CHD)
    F.me.provinces = {{key = "p1", labour = true}, {key = "p2"}, {key = "p3", labour = true}}
    stock("labour_gangs")
    assert(GG.buy("me", "labour_gangs"), "Labour Gangs sells")
    assert(#CALLS.transaction == 2, "two provinces hold labour, got " .. #CALLS.transaction)
    for _, c in ipairs(CALLS.transaction) do
        assert(c[3] == "other" and c[4] == 200, "200 labour through other")
    end
    ok("Labour Gangs adds labour to every province that holds it")
end

do
    -- CALL THE RECKONING: only at the top level, for a human in a running cycle, and
    -- refused at the till once the cycle has dropped (Review Focus 1); never on a rival's
    -- card (Review Focus 5).
    race(DWF)
    local level = 5
    grudge_cycle = {faction_times = {me = 9},
                    get_current_grudge_level = function(_, fk) return level end}
    assert(in_pool("call_reckoning", "immortals", 4), "at the top level it is drawn")
    stock("call_reckoning")
    level = 3
    local okl, why = GG.can_buy("me", "call_reckoning")
    assert(not okl and why == "unavailable", "below the top level the till refuses: "
           .. tostring(why))
    level = 5
    BONUS = {["me|dwf_grudge_feature_off"] = 1}
    assert(select(2, GG.can_buy("me", "call_reckoning")) == "unavailable",
           "not with the grudge feature off")
    BONUS = nil
    assert(GG.buy("me", "call_reckoning"), "it sells")
    assert(grudge_cycle.faction_times.me == 0, "the cycle resolves at the next turn start")
    W.faction("rival_dwf", {culture = DWF, regions = {}, lords = {}, heroes = {}})
    assert(not in_pool_of("rival_dwf", "call_reckoning", "immortals", 4),
           "a rival never holds it")
    grudge_cycle = nil
    assert(not in_pool("call_reckoning", "immortals", 4), "no global, never drawn")
    ok("Call the Reckoning only at the top level, for a human, while it still is")
end
```

`in_pool_of(faction, key, guild, rank)` is `in_pool` for another faction. Add it beside `in_pool`:

```lua
local function in_pool_of(faction, key, guild, rank)
    for _, s in ipairs(GG.pool(faction, guild, rank)) do
        if s.key == key then return true end
    end
    return false
end
```

(`in_pool` may stay as it is.)

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1, `attempt to index local 's' (a nil value)` from `stock("conclave_favour")`.

- [ ] **Step 3: The rows and the calls**

At the end of `GG.SERVICES`, directly after the `scorched_earth` row:

```lua
    -- RACE SERVICES (2026-09-29, spec §6): drawn for their own race only, and only while
    -- race differences are on. What each calls is below GG.take_self.
    {key="conclave_favour",     guild="khanate",      rank=2, cost=50,  cd=8,  kind="resource", resource="wh3_dlc23_chd_conclave_influence", factor="wh3_dlc23_chd_conclave_influence_gained_events", value=40, race="wh3_dlc23_chd_chaos_dwarfs"},
    {key="hellforge_allotment", guild="daemonsmiths", rank=3, cost=150, cd=12, kind="race",     value=1, race="wh3_dlc23_chd_chaos_dwarfs"},
    {key="labour_gangs",        guild="overseers",    rank=4, cost=400, cd=16, kind="race",     value=200, lead=true, race="wh3_dlc23_chd_chaos_dwarfs"},
    {key="high_kings_decree",   guild="overseers",    rank=2, cost=50,  cd=8,  kind="resource", resource="dwf_underdeeps", factor="underdeep_faction", value=1, race="wh_main_dwf_dwarfs"},
    {key="strike_lines",        guild="daemonsmiths", rank=3, cost=150, cd=12, kind="resource", resource="wh3_dlc25_dwf_grudge_points", factor="settled", value=200, race="wh_main_dwf_dwarfs"},
    {key="call_reckoning",      guild="immortals",    rank=4, cost=400, cd=16, kind="race",     lead=true, race="wh_main_dwf_dwarfs"},
```

Directly after `GG.take_self`:

```lua
-- ------------------------------------------------- Chaos Dwarfs and Dwarfs --
-- HELL-FORGE ALLOTMENT: +1 to one Hell-Forge unit's cap, rolled from the eleven the Tower
-- of Zharr's seats grant (tower_of_zharr.lua:85-101). NOT by the Tower's route: that
-- performs a ritual, a second ritual can end the one-turn commission rite in flight
-- (docs/RITUALS.md §5), and the listener paying it raises the next paid cap by 25%. CA's
-- own hellforge:modify_unit_cap (hellforge.lua:376) is the same +1 without either.
GG.HELLFORGE_CAPS = {
    "wh3_dlc23_chd_ritual_unit_cap_bale_taurus",
    "wh3_dlc23_chd_ritual_unit_cap_bull_centaurs",
    "wh3_dlc23_chd_ritual_unit_cap_great_taurus",
    "wh3_dlc23_chd_ritual_unit_cap_kdaai_destroyer",
    "wh3_dlc23_chd_ritual_unit_cap_kdaai_fireborn",
    "wh3_dlc23_chd_ritual_unit_cap_lammasu",
    "wh3_dlc23_chd_ritual_unit_cap_infernal_ironsworn",
    "wh3_dlc23_chd_ritual_unit_cap_infernal_guard_fireglaives",
    "wh3_dlc23_chd_ritual_unit_cap_infernal_guard",
    "wh3_dlc23_chd_ritual_unit_cap_chaos_dwarf_warriors",
    "wh3_dlc23_chd_ritual_unit_cap_chaos_dwarf_blunderbusses",
}
-- The Tower's message for a cap is "wh3_dlc23_chd_toz_cap_" .. its ritual, except the
-- blunderbusses, whose incident row CA keyed differently - so CA's own roll of them shows
-- nothing.
GG.HELLFORGE_INCIDENT_FIX = {
    wh3_dlc23_chd_ritual_unit_cap_chaos_dwarf_blunderbusses =
        "wh3_dlc23_chd_toz_cap_wh3_dlc23_chd_ritual_unit_cap_dwarf_blunderbusses",
}
GG.RACE_NEEDS.hellforge_allotment = function()
    return type(hellforge) == "table" and type(hellforge.modify_unit_cap) == "function"
end
GG.RACE_FIRE.hellforge_allotment = function(faction)
    local rk = GG.HELLFORGE_CAPS[GG.roll(#GG.HELLFORGE_CAPS)]
    hellforge:modify_unit_cap(rk, cm:get_faction(faction),
                              hellforge.unit_cap_modifiers_bundle_string)
    if GG.is_human(faction) then
        cm:trigger_incident(faction, GG.HELLFORGE_INCIDENT_FIX[rk]
                                     or ("wh3_dlc23_chd_toz_cap_" .. rk), true)
    end
end

-- LABOUR GANGS: labour for every province, by CA's own route (labour_loss.lua:40-49).
-- Labour is held per FACTION-province, so it is faction:provinces(), never a region's
-- province. A province without the pool is skipped.
GG.RACE_FIRE.labour_gangs = function(faction, s)
    local provs = cm:get_faction(faction):provinces()
    for i = 0, provs:num_items() - 1 do
        local res = provs:item_at(i):pooled_resource_manager():resource("wh3_dlc23_chd_labour")
        if not res:is_null_interface() then
            cm:pooled_resource_factor_transaction(res, "other", s.value)
        end
    end
end

-- CALL THE RECKONING: the grudge cycle resolves at this faction's next turn start, as CA's
-- Underdeep building does (wh3_campaign_underdeep.lua:219-227). ONLY AT THE TOP LEVEL:
-- resolving pays the level reached, and level 1 is a penalty (grudge_cycles.lua:1385-1398),
-- so it is offered only when waiting gains nothing. Human Dwarfs only - CA runs the cycle
-- for no one else - and not with the grudge feature switched off. CA's bundle removal is
-- not copied: resolution replaces the bundles itself.
GG.RACE_NEEDS.call_reckoning = function(faction)
    if type(grudge_cycle) ~= "table" or type(grudge_cycle.faction_times) ~= "table" then
        return false
    end
    if not GG.is_human(faction) then return false end
    if cm:get_factions_bonus_value(faction, "dwf_grudge_feature_off") ~= 0 then return false end
    return grudge_cycle:get_current_grudge_level(faction) == 5
end
GG.RACE_FIRE.call_reckoning = function(faction)
    grudge_cycle.faction_times[faction] = 0
end
```

In `tools/gen_great_guilds.py`, at the end of `SERVICES`, directly before its closing `]`:

```python
    # ------------------------------------------------------------ race services ---
    # RACE SERVICES (2026-09-29 spec §6): drawn for their own race only, named and written
    # in that race's words. Mirrors the Lua rows field for field (check_service_mirror).
    {"key": "conclave_favour", "guild": "khanate", "rank": 2, "cost": 50, "cd": 8,
     "kind": "resource", "race": "wh3_dlc23_chd_chaos_dwarfs",
     "resource": "wh3_dlc23_chd_conclave_influence",
     "factor": "wh3_dlc23_chd_conclave_influence_gained_events", "value": 40,
     "name": "Conclave Favour", "text": "Adds {value} Conclave Influence."},
    {"key": "hellforge_allotment", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race", "race": "wh3_dlc23_chd_chaos_dwarfs", "value": 1,
     "name": "Hell-Forge Allotment",
     "text": "Raises the Hell-Forge limit of one unit, chosen at random, by {value}."},
    {"key": "labour_gangs", "guild": "overseers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "race", "race": "wh3_dlc23_chd_chaos_dwarfs", "value": 200,
     "name": "Labour Gangs", "text": "Adds {value} Labour to every province you hold."},
    {"key": "high_kings_decree", "guild": "overseers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "resource", "race": "wh_main_dwf_dwarfs", "resource": "dwf_underdeeps",
     "factor": "underdeep_faction", "value": 1, "name": "High King's Decree",
     "text": "Adds {value} High King Decree: one more Great Gate to the Deeps may be built."},
    {"key": "strike_lines", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "resource", "race": "wh_main_dwf_dwarfs",
     "resource": "wh3_dlc25_dwf_grudge_points", "factor": "settled", "value": 200,
     "name": "Strike Lines from the Book",
     "text": "Adds {value} Settled Grudges, which count toward this grudge cycle."},
    {"key": "call_reckoning", "guild": "immortals", "rank": 4, "cost": 400, "cd": 16,
     "kind": "race", "race": "wh_main_dwf_dwarfs", "name": "Call the Reckoning",
     "text": "Ends the grudge cycle at the start of your next turn, at the top level you "
             "have reached. Offered only once you reach it."},
```

In the generator:
- `RACE_POOL_PAIRS = []` becomes `RACE_POOL_PAIRS = [("wh3_dlc23_chd_labour", "other")]`.
- `RACE_KEY_BLOCKS = {}` becomes `RACE_KEY_BLOCKS = {"HELLFORGE_CAPS": "rituals"}`.
- At the end of `check_race_keys`, before `return out`, add:

```python
    # The Hell-Forge caps' messages: CA's key built from the ritual, or the fix's.
    fix = dict(re.findall(r'(\w+)\s*=\s*\n?\s*"(wh3_dlc23_chd_toz_cap_[^"]+)"', lua))
    caps = re.search(r"^GG\.HELLFORGE_CAPS = \{(.*?)\n\}", lua, re.S | re.M)
    if caps:
        incidents = set(r["key"] for r in live_rows("incidents"))
        for k in re.findall(r'"([^"]+)"', caps.group(1)):
            inc = fix.get(k, "wh3_dlc23_chd_toz_cap_" + k)
            if inc not in incidents:
                out.append("the Hell-Forge cap %s would show %s, which is not an incident"
                           % (k, inc))
```

- [ ] **Step 4: Run everything**

Run both harnesses, then the generator `--selftest`, then `--check`.

Expected:
- `bounty harness ok` and `harness ok`.
- Generator check exit 0, which means:
  - the mirror holds;
  - the three pool rows, the labour pair and every literal pair are bound;
  - all 11 caps are rituals, with incidents that exist.
- The stage 1 catalogue test (`every card has three services`, bounty harness) fails, because a Chaos Dwarf's khanate rank-2 pool now holds four. Change that test's pool read to count shared rows only:

```lua
            local p = {}
            for _, s in ipairs(GG.pool("me", g, r)) do
                if not s.race then p[#p + 1] = s end
            end
```

  In the same test, change `assert(#GG.SERVICES == 54, ...)` to count shared rows:

```lua
    local shared = 0
    for _, s in ipairs(GG.SERVICES) do if not s.race then shared = shared + 1 end end
    assert(shared == 54, "54 shared services, got " .. shared)
```

  and `for i = 19, #GG.SERVICES do` becomes `for i = 19, 54 do`. Ledger this as a ruling: the test is about the shared pools.

- [ ] **Step 5: Ledger**

`Task 5: complete (both harnesses ok, generator check 0; RED: stock nil)`.

---

### Task 6: The Empire

Eight rows: three race services, Karl Franz's politics, and four lords. CA's evidence:
- Witch Hunters' Warrant: both pairs are vanilla on `region_to_province_own_unseen`. Corruption at -5 matches CA's three rows exactly; `is_positive_value_good` is false, so -5 is good.
- Elector's Muster: both units exist; "only created if there is room".
- Unity of the Empire: +30 `faction_to_faction_own` matches `wh2_dlc16_wef_incursion_empire_spared`. It shifts relations with every Empire-subculture faction.
- Elector's Favour: `empire_find_electors_with_loyalty(player_iface, min, max)` (`:949`) and `empire_modify_elector_loyalty(name_or_key, factor, value)` (`:1943`) are globals. The feature group `politics` has one Empire member: Karl Franz's faction.
- The lords' pools each belong to one faction. On any other faction `resource(key)` is a null interface.
  - Schematics: `wh3_dlc25_emp_research`, factor `other`.
  - Arcane Essays: `wh3_dlc25_emp_arcane_essays`, factor `other`.
  - Fervour: `wh3_dlc29_emp_fervour`, factor `missions`.
- Imperial Supply Train: finding 3 in the table at the top.

**Files:**
- Modify: `zzz_derpy_guilds.lua`: 8 rows; the Empire block.
- Modify: `tools/gen_great_guilds.py`: 8 rows; `RACE_KEY_BLOCKS` and `RACE_KEY_SINGLES`.
- Test: `tools/_guilds_bounty_harness.lua`.

**Interfaces:**
- Produces:
  - rows `witch_hunters_warrant`, `electors_muster`, `unity_of_empire`, `electors_favour`, `gunnery_schematics`, `arcane_essays`, `fervour`, `supply_train`;
  - `GG.least_loyal_elector(faction)`;
  - `GG.WULFHART`;
  - `GG.SUPPLY_DILEMMAS`.

- [ ] **Step 1: Stubs and failing tests**

In `cm = { ... }`, after `get_factions_bonus_value`:

```lua
    trigger_dilemma = function(_, f, k) rec("dilemma", f, k) end,
    faction_has_campaign_feature = function(_, f, feat)
        return F[f] ~= nil and (F[f].features or {})[feat] == true
    end,
```

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------------- RACES: the Empire --
local EMP = "wh_main_emp_empire"

do
    -- THE WARRANT ON MY OWN SETTLEMENT; THE MUSTER'S TWO REGIMENTS, one per grant, on an
    -- army with room; UNITY ON THE FACTION.
    worldA()
    F.me.culture = EMP
    stock("witch_hunters_warrant")
    assert(not GG.buy("me", "witch_hunters_warrant", "foe_near"), "never an enemy's town")
    assert(GG.buy("me", "witch_hunters_warrant", "home"), "my own town")
    assert(CALLS.region_bundle[1][1] == "derpy_gg_svc_witch_hunters_warrant_emp"
           and CALLS.region_bundle[1][3] == 8, "the Warrant's bundle, 8 turns")
    stock("electors_muster")
    C["10"].units = 20
    assert(not GG.buy("me", "electors_muster", 10), "a full army is refused")
    C["10"].units = 18
    assert(GG.buy("me", "electors_muster", 10), "an army with room")
    assert(#CALLS.grant == 2 and CALLS.grant[1][1] == "character_cqi:10"
           and CALLS.grant[1][2] == "wh_main_emp_inf_swordsmen"
           and CALLS.grant[2][2] == "wh_main_emp_inf_handgunners",
           "Swordsmen then Handgunners, through a lookup string")
    stock("unity_of_empire")
    assert(GG.buy("me", "unity_of_empire"), "Unity sells")
    local u = CALLS.bundle[#CALLS.bundle]
    assert(u[1] == "derpy_gg_svc_unity_of_empire_emp" and u[2] == "me" and u[3] == 15,
           "Unity's bundle on the faction for 15 turns")
    ok("the Empire's three race services land where their cards say")
end

do
    -- ELECTOR'S FAVOUR: the least loyal Elector, through CA's own globals, for a faction
    -- with the politics feature - asked of the buyer, which is on the map.
    race(EMP)
    F.me.features = {politics = true}
    local loyal = {averland = 7, talabecland = 3, stirland = 3}
    local order = {"averland", "talabecland", "stirland"}
    empire_find_electors_with_loyalty = function(f, lo, hi)
        assert(f:name() == "me", "asked with the buyer's faction interface")
        local out = {}
        for _, e in ipairs(order) do
            if loyal[e] >= lo and loyal[e] <= hi then out[#out + 1] = {elector = e} end
        end
        return out
    end
    local moved
    empire_modify_elector_loyalty = function(e, factor, n) moved = {e, factor, n} end
    stock("electors_favour")
    assert(GG.buy("me", "electors_favour"), "it sells")
    assert(moved[1] == "talabecland" and moved[2] == "events" and moved[3] == 1,
           "+1 Fealty through events to the least loyal, first in CA's order")
    -- The buy set a cooldown, which would refuse everything below on its own.
    GG.cooldowns.me = {}
    local function why() return select(2, GG.can_buy("me", "electors_favour")) end
    loyal = {averland = 10, talabecland = 10, stirland = 10}
    assert(why() == "unavailable", "every Elector at 10: nothing to buy")
    F.me.features = {}
    loyal.averland = 2
    assert(why() == "unavailable", "no politics feature: not offered")
    F.me.features = {politics = true}
    assert(why() == nil, "and with it back, offered again")
    empire_find_electors_with_loyalty, empire_modify_elector_loyalty = nil, nil
    assert(why() == "unavailable", "no politics script: not offered")
    ok("Elector's Favour raises the least loyal Elector, where politics runs")
end

do
    -- THE LORDS' POOLS, each only on the faction that holds it.
    race(EMP)
    F.me.resources = {wh3_dlc29_emp_fervour = 0}
    assert(in_pool("fervour", "immortals", 3), "Todbringer's faction draws Fervour")
    assert(not in_pool("gunnery_schematics", "daemonsmiths", 3), "and not Elspeth's")
    stock("fervour")
    assert(GG.buy("me", "fervour"), "Fervour sells")
    local c = CALLS.pooled[1]
    assert(c[2] == "wh3_dlc29_emp_fervour" and c[3] == "missions" and c[4] == 300,
           "300 Fervour through missions")
    ok("each lord's service follows the pool, not a faction name")
end

do
    -- THE SUPPLY TRAIN: CA's dilemma at CA's strength, for a human Wulfhart only, never a
    -- rival. "me" is a human Empire player throughout, so the Empire stays covered and
    -- the AI case is refused by the human check, not by the culture gate.
    local W_ = "wh2_dlc13_emp_the_huntmarshals_expedition"
    race(EMP)
    W.faction(W_, {culture = EMP, resources = {emp_progress = 45},
                   regions = {}, lords = {}, heroes = {}})
    assert(not in_pool_of(W_, "supply_train", "brass", 3), "an AI Wulfhart never draws it")
    F[W_].human = true
    GG.humans = nil
    cm.get_human_factions = function() return {"me", W_} end
    assert(in_pool_of(W_, "supply_train", "brass", 3), "a human Wulfhart draws it")
    assert(not in_pool("supply_train", "brass", 3), "and no other Empire faction does")
    GG.state[W_] = {}
    for _, g in ipairs(GG.GUILDS) do GG.state[W_][g] = {rep = 99999, fav = 99999} end
    GG.cards[W_] = {turn = 1, keys = GG.cards_of(W_)}
    GG.cards[W_].keys[2] = "supply_train"                      -- brass, rank 3
    assert(GG.buy(W_, "supply_train"), "it sells")
    cm.get_human_factions = function() return {"me"} end
    GG.humans = nil
    assert(CALLS.dilemma[1][1] == W_
           and CALLS.dilemma[1][2] == "wh2_dlc13_wulfhart_imperial_guards_st_2",
           "Acclaim 45 is CA's middle strength")
    ok("the Supply Train raises CA's dilemma for a human Wulfhart only")
end
```

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1, `stock` fails on `witch_hunters_warrant` (a nil service).

- [ ] **Step 3: The rows and the calls**

At the end of `GG.SERVICES`, after `call_reckoning`:

```lua
    {key="witch_hunters_warrant", guild="overseers",  rank=2, cost=50,  cd=8,  kind="settlement", turns=8, race="wh_main_emp_empire"},
    {key="electors_muster",     guild="immortals",    rank=3, cost=150, cd=12, kind="race_army", room=true, units="wh_main_emp_inf_swordsmen,wh_main_emp_inf_handgunners", race="wh_main_emp_empire"},
    {key="unity_of_empire",     guild="brass",        rank=4, cost=400, cd=16, kind="bundle",   turns=15, lead=true, race="wh_main_emp_empire"},
    {key="electors_favour",     guild="khanate",      rank=3, cost=150, cd=12, kind="race",     value=1, race="wh_main_emp_empire"},
    {key="gunnery_schematics",  guild="daemonsmiths", rank=3, cost=150, cd=12, kind="resource", resource="wh3_dlc25_emp_research", factor="other", value=300, race="wh_main_emp_empire"},
    {key="arcane_essays",       guild="daemonsmiths", rank=3, cost=150, cd=12, kind="resource", resource="wh3_dlc25_emp_arcane_essays", factor="other", value=300, race="wh_main_emp_empire"},
    {key="fervour",             guild="immortals",    rank=3, cost=150, cd=12, kind="resource", resource="wh3_dlc29_emp_fervour", factor="missions", value=300, race="wh_main_emp_empire"},
    {key="supply_train",        guild="brass",        rank=3, cost=150, cd=12, kind="race",     race="wh_main_emp_empire"},
```

After the Chaos Dwarf and Dwarf block:

```lua
-- ---------------------------------------------------------------- the Empire --
-- ELECTOR'S MUSTER: its regiments, in order, one grant each. CA creates a unit "only if
-- there is room", so the second may not arrive; the row's `room` makes the till ask for
-- space for at least one.
GG.RACE_FIRE.electors_muster = function(faction, s, target)
    local lookup = cm:char_lookup_str(target)
    for unit in string.gmatch(s.units, "[^,]+") do cm:grant_unit_to_character(lookup, unit) end
end

-- ELECTOR'S FAVOUR: +1 Fealty to the least loyal Elector Count, through CA's own politics
-- globals (wh2_dlc13_empire_politics.lua:949, :1943). The finder keeps only electors
-- alive, not human and not at war with the buyer, so the least loyal is the first band of
-- loyalty with anyone in it. faction_has_campaign_feature throws for a key the map lacks
-- (lib_campaign_manager.lua:17626), so it is asked of the buyer alone.
function GG.least_loyal_elector(faction)
    local f = cm:get_faction(faction)
    for band = 0, 9 do
        local list = empire_find_electors_with_loyalty(f, band, band)
        if list and #list > 0 then return list[1].elector end
    end
    return nil
end
GG.RACE_NEEDS.electors_favour = function(faction)
    if type(empire_find_electors_with_loyalty) ~= "function"
       or type(empire_modify_elector_loyalty) ~= "function" then
        return false
    end
    if not cm:faction_has_campaign_feature(faction, "politics") then return false end
    return GG.least_loyal_elector(faction) ~= nil
end
GG.RACE_FIRE.electors_favour = function(faction, s)
    empire_modify_elector_loyalty(GG.least_loyal_elector(faction), "events", s.value)
end

-- THE IMPERIAL SUPPLY TRAIN: CA's supply dilemma now, at the strength CA's own meter would
-- pick (wh2_dlc13_wulfhart_imperial_reinforcement.lua:672-684). NOT CA's
-- trigger_imperial_reinforcements_event, which also zeroes that meter and so only brings
-- the next supply forward. CA's choice handler matches the dilemma by key (:358) and
-- spawns for Wulfhart's faction, so it is his faction only - and a human, since a dilemma
-- needs one.
GG.WULFHART = "wh2_dlc13_emp_the_huntmarshals_expedition"
GG.SUPPLY_DILEMMAS = {
    "wh2_dlc13_wulfhart_imperial_guards_st_1",
    "wh2_dlc13_wulfhart_imperial_guards_st_2",
    "wh2_dlc13_wulfhart_imperial_guards_st_3",
}
GG.RACE_NEEDS.supply_train = function(faction)
    return faction == GG.WULFHART and GG.is_human(faction)
           and GG.has_resource(faction, "emp_progress")
end
GG.RACE_FIRE.supply_train = function(faction)
    local v = cm:get_faction(faction):pooled_resource_manager():resource("emp_progress"):value()
    local band = (v < 20 and 1) or (v < 60 and 2) or 3
    cm:trigger_dilemma(faction, GG.SUPPLY_DILEMMAS[band])
end
```

In `tools/gen_great_guilds.py` `SERVICES`, after `call_reckoning`:

```python
    {"key": "witch_hunters_warrant", "guild": "overseers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "settlement", "turns": 8, "race": "wh_main_emp_empire",
     "name": "Witch Hunters' Warrant",
     "effects": [("wh_main_effect_public_order_events", "region_to_province_own_unseen", 8),
                 ("wh3_main_effect_corruption_reduction_events",
                  "region_to_province_own_unseen", -5)],
     "text": "{v0:+d} public order and {v1:+d} corruption in the province of the settlement "
             "you select, for {turns} turns."},
    {"key": "electors_muster", "guild": "immortals", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race_army", "room": True, "race": "wh_main_emp_empire",
     "units": "wh_main_emp_inf_swordsmen,wh_main_emp_inf_handgunners",
     "name": "Elector's Muster",
     "text": "A regiment of Swordsmen and one of Handgunners join the army you select, as "
             "far as it has room."},
    {"key": "unity_of_empire", "guild": "brass", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 15, "race": "wh_main_emp_empire",
     "name": "Unity of the Empire",
     "effects": [("wh_main_faction_political_diplomacy_mod_empire",
                  "faction_to_faction_own", 30)],
     "text": "{v0:+d} relations with every Empire faction, for {turns} turns."},
    {"key": "electors_favour", "guild": "khanate", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race", "race": "wh_main_emp_empire", "value": 1, "lord": "Karl Franz",
     "name": "Elector's Favour",
     "text": "Adds {value} Fealty to the least loyal Elector Count who is not at war with "
             "you."},
    {"key": "gunnery_schematics", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "resource", "race": "wh_main_emp_empire", "resource": "wh3_dlc25_emp_research",
     "factor": "other", "value": 300, "lord": "Elspeth von Draken",
     "name": "Gunnery School Schematics", "text": "Adds {value} Schematics."},
    {"key": "arcane_essays", "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 12,
     "kind": "resource", "race": "wh_main_emp_empire",
     "resource": "wh3_dlc25_emp_arcane_essays", "factor": "other", "value": 300,
     "lord": "Balthasar Gelt", "name": "Arcane Essays", "text": "Adds {value} Arcane Essays."},
    {"key": "fervour", "guild": "immortals", "rank": 3, "cost": 150, "cd": 12,
     "kind": "resource", "race": "wh_main_emp_empire", "resource": "wh3_dlc29_emp_fervour",
     "factor": "missions", "value": 300, "lord": "Boris Todbringer", "name": "Fervour",
     "text": "Adds {value} Fervour."},
    {"key": "supply_train", "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race", "race": "wh_main_emp_empire", "lord": "Markus Wulfhart",
     "name": "Imperial Supply Train",
     "text": "Imperial Supply arrives now: the choice of reinforcements it brings, at your "
             "current Acclaim."},
```

In the generator:
- `RACE_KEY_BLOCKS` gains `"SUPPLY_DILEMMAS": "dilemmas"`.
- `RACE_KEY_SINGLES = {}` becomes `RACE_KEY_SINGLES = {"WULFHART": "factions"}`.

- [ ] **Step 4: Run everything**

Run both harnesses, the generator `--selftest` and `--check`.

Expected:
- Both harnesses ok.
- Check exit 0:
  - the Warrant's and Unity's pairs are vanilla, in range, with the right sign;
  - both muster units are in `main_units`;
  - the three lords' pools are bound;
  - the dilemmas and Wulfhart's faction exist.
- The selftest's `_unseen` rule reads only the Chaos Dwarf pass, so the Warrant's hidden line is checked in Task 11. Ledger that.

- [ ] **Step 5: Ledger**

`Task 6: complete (both harnesses ok, generator check 0; RED: stock nil)`.

---

### Task 7: Kislev and Bretonnia

Six rows. CA's evidence:
- Devotion:
  - CA makes this call (`wh3_tol_something_rotten_in_kislev.lua:19`).
  - No DB table assigns Devotion, so not every minor Kislev faction can be shown to hold it. Hence the pool check.
- The courts' trackers go to every Kislev faction, factor `faction`. The lower court is read from the `_support_level_` pools as CA compares them (`kislev_motherland.lua:354-355`). A tie goes to the Ice Court.
- The Lady's Blessing:
  - `Blessing_Character_Won(character)` is a global (`wh_dlc07_blessing_of_the_lady.lua:91`). It does nothing, silently, for an army already blessed.
  - The till refuses such an army by CA's own `Has_Blessing_Already(force_cqi)` and by the bundle `wh_dlc07_blessing_of_the_lady` (`mf:has_effect_bundle`, as `wh_dlc07_bretonnia.lua:101` calls it).
- Peasant Levies: +3 on `faction_to_faction_own_unseen` sits inside vanilla's +5 to +15, all positive. CA's peasant script is human-only and recalculates at its own events, so the +3 can show a turn late.
- Tales of Valour: `chivalry:ModifyChivalry(faction_key, factor, value)` takes a colon (`wh_campaign_bretonnia_chivalry.lua:315`). It also runs the human win check at 8000.

**Files:**
- Modify: `zzz_derpy_guilds.lua`: 6 rows; the Kislev and Bretonnia block.
- Modify: `tools/gen_great_guilds.py`: 6 rows.
- Test: `tools/_guilds_bounty_harness.lua`.

**Interfaces:**
- Produces:
  - rows `prayers_motherland`, `court_favour`, `blessing_motherland`, `ladys_blessing`, `peasant_levies`, `tales_of_valour`;
  - `GG.lower_court(faction) -> "orthodoxy" | "ice_court"`.

- [ ] **Step 1: Failing tests**

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------ RACES: Kislev and Bretonnia --
local KSL, BRT = "wh3_main_ksl_kislev", "wh_main_brt_bretonnia"

do
    -- PRAYERS, THE LOWER COURT, AND THE BLESSING OF THE MOTHERLAND.
    race(KSL)
    F.me.resources = {wh3_main_ksl_devotion = 0, wh3_main_ksl_support_level_orthodoxy = 2,
                      wh3_main_ksl_support_level_ice_court = 1}
    stock("prayers_motherland")
    assert(GG.buy("me", "prayers_motherland"), "Prayers sells")
    stock("court_favour")
    assert(GG.buy("me", "court_favour"), "Court Favour sells")
    stock("blessing_motherland")
    assert(GG.buy("me", "blessing_motherland"), "the Blessing sells")
    local p = CALLS.pooled
    assert(p[1][2] == "wh3_main_ksl_devotion" and p[1][3] == "events" and p[1][4] == 75,
           "Prayers: 75 Devotion through events")
    assert(p[2][2] == "wh3_main_ksl_support_tracker_ice_court" and p[2][3] == "faction"
           and p[2][4] == 30, "the Ice Court is behind, so it gets the 30")
    assert(p[3][4] == 100 and p[4][4] == 20 and p[5][4] == 20
           and p[4][2] ~= p[5][2], "the Blessing: 100 Devotion and 20 to each court")
    F.me.resources.wh3_main_ksl_support_level_ice_court = 2
    assert(GG.lower_court("me") == "ice_court", "a tie goes to the Ice Court")
    F.me.resources.wh3_main_ksl_support_level_ice_court = 3
    assert(GG.lower_court("me") == "orthodoxy", "the Orthodoxy when it is behind")
    F.me.resources.wh3_main_ksl_devotion = nil
    assert(not in_pool("prayers_motherland", "daemonsmiths", 2)
           and not in_pool("blessing_motherland", "immortals", 4),
           "no Devotion, neither drawn")
    ok("Kislev's services reach Devotion and the court that is behind")
end

do
    -- THE LADY'S BLESSING on my army by CA's own call, refused on one already blessed;
    -- TALES OF VALOUR through CA's chivalry, or the plain grant without it.
    worldA()
    F.me.culture = BRT
    F.me.resources = {brt_chivalry = 0}
    local blessed, done = {}, {}
    Has_Blessing_Already = function(fcqi) return blessed[fcqi] == true end
    Blessing_Character_Won = function(c) done[#done + 1] = c:command_queue_index() end
    stock("ladys_blessing")
    blessed[1010] = true
    assert(not GG.buy("me", "ladys_blessing", 10), "an army already blessed is refused")
    blessed[1010] = nil
    C["10"].force_bundles = {wh_dlc07_blessing_of_the_lady = true}
    assert(not GG.buy("me", "ladys_blessing", 10), "and one carrying the bundle")
    C["10"].force_bundles = nil
    assert(GG.buy("me", "ladys_blessing", 10), "an army without it is blessed")
    assert(done[1] == 10, "through Blessing_Character_Won on its general")
    Has_Blessing_Already, Blessing_Character_Won = nil, nil
    assert(not in_pool("ladys_blessing", "immortals", 2), "no global, never drawn")
    local modified
    chivalry = {ModifyChivalry = function(self, f, factor, n) modified = {self, f, factor, n} end}
    stock("tales_of_valour")
    assert(GG.buy("me", "tales_of_valour"), "Tales sells")
    assert(modified[1] == chivalry and modified[2] == "me" and modified[3] == "missions"
           and modified[4] == 150, "chivalry:ModifyChivalry(me, missions, 150), with a colon")
    chivalry = nil
    stock("tales_of_valour")
    assert(GG.buy("me", "tales_of_valour"), "and without CA's chivalry")
    local c = CALLS.pooled[#CALLS.pooled]
    assert(c[2] == "brt_chivalry" and c[3] == "missions" and c[4] == 150,
           "the plain grant through missions")
    ok("Bretonnia's Blessing and Tales go through CA's own calls")
end
```

The blessed-army test reads force cqi `1010`: `W.ci` gives character `cqi`'s force the cqi `1000 + cqi`.

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1 on `stock("prayers_motherland")`.

- [ ] **Step 3: The rows and the calls**

At the end of `GG.SERVICES`, after `supply_train`:

```lua
    {key="prayers_motherland",  guild="daemonsmiths", rank=2, cost=50,  cd=8,  kind="resource", resource="wh3_main_ksl_devotion", factor="events", value=75, race="wh3_main_ksl_kislev"},
    {key="court_favour",        guild="khanate",      rank=3, cost=150, cd=12, kind="race",     value=30, race="wh3_main_ksl_kislev"},
    {key="blessing_motherland", guild="immortals",    rank=4, cost=400, cd=16, kind="race",     value=100, value2=20, lead=true, race="wh3_main_ksl_kislev"},
    {key="ladys_blessing",      guild="immortals",    rank=2, cost=50,  cd=8,  kind="race_army", race="wh_main_brt_bretonnia"},
    {key="peasant_levies",      guild="brass",        rank=3, cost=150, cd=12, kind="bundle",   turns=10, race="wh_main_brt_bretonnia"},
    {key="tales_of_valour",     guild="daemonsmiths", rank=4, cost=400, cd=16, kind="race",     value=150, lead=true, race="wh_main_brt_bretonnia"},
```

After the Empire block:

```lua
-- ------------------------------------------------------- Kislev and Bretonnia --
-- THE COURT THAT IS BEHIND, compared as CA compares them (kislev_motherland.lua:354-355):
-- a tie goes to the Ice Court. Each grant below is written out per court, so every pool
-- and factor is a literal the generator checks.
function GG.lower_court(faction)
    local prm = cm:get_faction(faction):pooled_resource_manager()
    local orth = prm:resource("wh3_main_ksl_support_level_orthodoxy"):value()
    local ice = prm:resource("wh3_main_ksl_support_level_ice_court"):value()
    return orth < ice and "orthodoxy" or "ice_court"
end
GG.RACE_NEEDS.court_favour = function(faction)
    return GG.has_resource(faction, "wh3_main_ksl_support_level_orthodoxy")
       and GG.has_resource(faction, "wh3_main_ksl_support_level_ice_court")
end
GG.RACE_FIRE.court_favour = function(faction, s)
    if GG.lower_court(faction) == "orthodoxy" then
        cm:faction_add_pooled_resource(faction, "wh3_main_ksl_support_tracker_orthodoxy",
                                       "faction", s.value)
    else
        cm:faction_add_pooled_resource(faction, "wh3_main_ksl_support_tracker_ice_court",
                                       "faction", s.value)
    end
end

-- THE BLESSING OF THE MOTHERLAND: Devotion as Prayers grants it, and both courts at once.
-- Not every minor Kislev faction can be shown to hold Devotion, so it is asked.
GG.RACE_NEEDS.blessing_motherland = function(faction)
    return GG.has_resource(faction, "wh3_main_ksl_devotion")
end
GG.RACE_FIRE.blessing_motherland = function(faction, s)
    cm:faction_add_pooled_resource(faction, "wh3_main_ksl_devotion", "events", s.value)
    cm:faction_add_pooled_resource(faction, "wh3_main_ksl_support_tracker_orthodoxy",
                                   "faction", s.value2)
    cm:faction_add_pooled_resource(faction, "wh3_main_ksl_support_tracker_ice_court",
                                   "faction", s.value2)
end

-- THE LADY'S BLESSING by CA's own call (wh_dlc07_blessing_of_the_lady.lua:91), which
-- returns nothing and does nothing for an army already blessed - so the till refuses one
-- first, by CA's own list and by the bundle itself.
GG.RACE_NEEDS.ladys_blessing = function()
    return type(Blessing_Character_Won) == "function"
       and type(Has_Blessing_Already) == "function"
end
GG.RACE_TARGET_OK.ladys_blessing = function(_faction, c)
    local mf = c:military_force()
    return not Has_Blessing_Already(mf:command_queue_index())
       and not mf:has_effect_bundle("wh_dlc07_blessing_of_the_lady")
end
GG.RACE_FIRE.ladys_blessing = function(_faction, _s, target)
    Blessing_Character_Won(cm:get_character_by_cqi(target))
end

-- TALES OF VALOUR: Chivalry through CA's chivalry:ModifyChivalry (wh_campaign_bretonnia_
-- chivalry.lua:315), which also runs the win check a human is owed at 8000; the plain
-- grant where that global is not loaded. Through "missions", which the Bretonnian earning
-- does not count, so the purchase does not pay itself.
GG.RACE_NEEDS.tales_of_valour = function(faction)
    return GG.has_resource(faction, "brt_chivalry")
end
GG.RACE_FIRE.tales_of_valour = function(faction, s)
    if type(chivalry) == "table" and type(chivalry.ModifyChivalry) == "function" then
        chivalry:ModifyChivalry(faction, "missions", s.value)
    else
        cm:faction_add_pooled_resource(faction, "brt_chivalry", "missions", s.value)
    end
end
```

In `tools/gen_great_guilds.py` `SERVICES`, after `supply_train`:

```python
    {"key": "prayers_motherland", "guild": "daemonsmiths", "rank": 2, "cost": 50, "cd": 8,
     "kind": "resource", "race": "wh3_main_ksl_kislev", "resource": "wh3_main_ksl_devotion",
     "factor": "events", "value": 75, "name": "Prayers to the Motherland",
     "text": "Adds {value} Devotion."},
    {"key": "court_favour", "guild": "khanate", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race", "race": "wh3_main_ksl_kislev", "value": 30, "name": "Court Favour",
     "text": "Adds {value} support to whichever court is behind, the Ice Court or the "
             "Orthodoxy."},
    {"key": "blessing_motherland", "guild": "immortals", "rank": 4, "cost": 400, "cd": 16,
     "kind": "race", "race": "wh3_main_ksl_kislev", "value": 100, "value2": 20,
     "name": "Blessing of the Motherland",
     "text": "Adds {value} Devotion, and {value2} support to both the Ice Court and the "
             "Orthodoxy."},
    {"key": "ladys_blessing", "guild": "immortals", "rank": 2, "cost": 50, "cd": 8,
     "kind": "race_army", "race": "wh_main_brt_bretonnia", "name": "The Lady's Blessing",
     "text": "The army you select receives the Blessing of the Lady, as if it had won a "
             "battle. Not an army already blessed."},
    {"key": "peasant_levies", "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 10, "race": "wh_main_brt_bretonnia", "name": "Peasant Levies",
     "effects": [("wh_dlc07_effect_peasant_increase_base_amount",
                  "faction_to_faction_own_unseen", 3)],
     "text": "{v0:+d} peasants available to your faction, for {turns} turns."},
    {"key": "tales_of_valour", "guild": "daemonsmiths", "rank": 4, "cost": 400, "cd": 16,
     "kind": "race", "race": "wh_main_brt_bretonnia", "value": 150,
     "name": "Tales of Valour", "text": "Adds {value} Chivalry."},
```

- [ ] **Step 4: Run everything**

Expected:
- Both harnesses ok.
- Check exit 0:
  - Devotion/`events`, both trackers/`faction` and `brt_chivalry`/`missions` are bound, read off the Lua literals;
  - the Peasant Levies pair is vanilla.

- [ ] **Step 5: Ledger**

`Task 7: complete (both harnesses ok, generator check 0; RED: stock nil)`.

---

### Task 8: Cathay, Dark Elves, High Elves

Nine rows. CA's evidence:
- Realign the Compass: the call takes a faction INTERFACE (`wh3_main_chaos/wh_start.lua:130`). The Celestial Court's jade compass is a different system.
- Ivory Road Cargo:
  - CA does exactly this (`wh3_campaign_ivory_road_events.lua:551`).
  - Enumerate with `world:caravans_system():faction_caravans(faction_iface):active_caravans()`, a 0-based list (`caravans_core.lua:716-726`).
  - A returning caravan is skipped.
- Mandate of Heaven: public order +4 matches seven vanilla bundles; corruption -8 matches `wh3_main_dilemma_cth_6_third`. Both are `faction_to_province_own`.
- Slaves: `def_slaves`/`missions` is CA's own payload pair (`lib_campaign_mission_manager.lua:2616`).
- Bought Loyalty: a lookup string and a number. Dark Elf loyalty is live (`wh_campaign_interventions.lua:797`).
- Black Ark Tithe: +80 sits inside vanilla's +10 to +100. The first Slaves arrive at the end of the round.
- Influence: `cm:change_influence(faction_key, n)` (`wh3_dlc27_valiant_imperatives.lua:131`). It is gated on the race, because the Empire turns influence into Prestige.
- The Phoenix King's Favour: every High Elf faction holds it. It is capped at 900, lower while others hold Ulthuan, and a grant above the cap is cut off silently.

**Files:**
- Modify: `zzz_derpy_guilds.lua`: 9 rows; the Cathay, Dark Elves and High Elves block.
- Modify: `tools/gen_great_guilds.py`: 9 rows; `RACE_KEY_SINGLES`; the Dark Elves' word; the race row count.
- Test: `tools/_guilds_bounty_harness.lua`.

**Interfaces:**
- Produces:
  - rows `realign_compass`, `ivory_cargo`, `mandate_of_heaven`, `slave_coffles`, `bought_loyalty`, `black_ark_tithe`, `whispers_at_court`, `phoenix_favour`, `asuryans_grace`;
  - `GG.caravans_out(faction)`;
  - `GG.CELESTIAL_COURT`.

- [ ] **Step 1: Stubs and failing tests**

In `cm = { ... }`, after `faction_has_campaign_feature`:

```lua
    set_next_winds_of_magic_compass_selection_cooldown = function(_, f, n)
        rec("compass", f:name(), n)
    end,
    set_caravan_cargo = function(_, c, n) rec("cargo", c.id, n) end,
    modify_character_personal_loyalty_factor = function(_, lookup, n) rec("loyalty", lookup, n) end,
    change_influence = function(_, f, n) rec("influence", f, n) end,
```

In the `cm.model()` world table, beside `faction_list`:

```lua
                        -- t.caravans = {{id = 1, cargo = 100, returning = false}, ...}
                        caravans_system = function()
                            return {faction_caravans = function(_, f)
                                local t = F[f:name()]
                                if not t or not t.caravans then return NULL() end
                                local list = {}
                                for _, c in ipairs(t.caravans) do
                                    list[#list + 1] = {id = c.id,
                                        cargo = function() return c.cargo end,
                                        is_returning = function() return c.returning == true end}
                                end
                                return {is_null_interface = function() return false end,
                                        active_caravans = function() return LIST(list) end}
                            end}
                        end,
```

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------ RACES: Cathay, Dark Elves, High Elves --
local CTH, DEF, HEF = "wh3_main_cth_cathay", "wh2_main_def_dark_elves", "wh2_main_hef_high_elves"

do
    -- THE COMPASS BY FACTION INTERFACE, never for the Celestial Court; CARGO FOR EVERY
    -- CARAVAN STILL OUT, and not offered once they are all home (Review Focus 1).
    race(CTH)
    stock("realign_compass")
    assert(GG.buy("me", "realign_compass"), "the Compass sells")
    assert(CALLS.compass[1][1] == "me" and CALLS.compass[1][2] == 0, "cooldown 0 for me")
    W.faction("wh3_dlc24_cth_the_celestial_court", {culture = CTH, regions = {}, lords = {}})
    assert(not in_pool_of("wh3_dlc24_cth_the_celestial_court", "realign_compass",
                          "daemonsmiths", 2), "never for the Celestial Court")
    F.me.caravans = {{id = 1, cargo = 100}, {id = 2, cargo = 50, returning = true},
                     {id = 3, cargo = 0}}
    stock("ivory_cargo")
    assert(GG.buy("me", "ivory_cargo"), "Cargo sells")
    assert(#CALLS.cargo == 2 and CALLS.cargo[1][1] == 1 and CALLS.cargo[1][2] == 300
           and CALLS.cargo[2][1] == 3 and CALLS.cargo[2][2] == 200,
           "+200 on each caravan still on its way, none on the one coming home")
    F.me.caravans = {{id = 2, cargo = 50, returning = true}}
    GG.cooldowns.me = {}                         -- the buy's cooldown would refuse it anyway
    assert(select(2, GG.can_buy("me", "ivory_cargo")) == "unavailable",
           "all home: unavailable at the till")
    ok("Cathay's Compass and Cargo reach CA's own systems")
end

do
    -- SLAVES AS CA PAYS THEM; LOYALTY FOR A LORD WHO IS NOT THE LEADER.
    worldA()
    F.me.culture = DEF
    F.me.resources = {def_slaves = 100}
    stock("slave_coffles")
    assert(GG.buy("me", "slave_coffles"), "Coffles sells")
    local c = CALLS.pooled[1]
    assert(c[2] == "def_slaves" and c[3] == "missions" and c[4] == 500, "500 Slaves")
    stock("bought_loyalty")
    C["10"].leader = true
    assert(not GG.buy("me", "bought_loyalty", 10), "never the faction leader")
    C["10"].leader = nil
    assert(GG.buy("me", "bought_loyalty", 10), "another lord")
    assert(CALLS.loyalty[1][1] == "character_cqi:10" and CALLS.loyalty[1][2] == 3,
           "+3 through a lookup string")
    ok("the Dark Elves' Slaves and loyalty land as CA documents")
end

do
    -- INFLUENCE AND THE PHOENIX KING'S FAVOUR, the Grace carrying both.
    race(HEF)
    F.me.resources = {wh3_dlc27_hef_favour = 0}
    stock("whispers_at_court")
    assert(GG.buy("me", "whispers_at_court"), "Whispers sells")
    stock("asuryans_grace")
    assert(GG.buy("me", "asuryans_grace"), "the Grace sells")
    assert(CALLS.influence[1][1] == "me" and CALLS.influence[1][2] == 30, "30 Influence")
    local c = CALLS.pooled[#CALLS.pooled]
    assert(c[2] == "wh3_dlc27_hef_favour" and c[3] == "faction" and c[4] == 150,
           "150 Favour of the Phoenix King")
    assert(CALLS.influence[2][2] == 40, "and 40 Influence")
    ok("the High Elves' services reach Influence and the Phoenix King's favour")
end
```

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1 on `stock("realign_compass")`.

- [ ] **Step 3: The rows and the calls**

At the end of `GG.SERVICES`, after `tales_of_valour`:

```lua
    {key="realign_compass",     guild="daemonsmiths", rank=2, cost=50,  cd=8,  kind="race",     race="wh3_main_cth_cathay"},
    {key="ivory_cargo",         guild="brass",        rank=3, cost=150, cd=12, kind="race",     value=200, race="wh3_main_cth_cathay"},
    {key="mandate_of_heaven",   guild="overseers",    rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true, race="wh3_main_cth_cathay"},
    {key="slave_coffles",       guild="slavers",      rank=2, cost=50,  cd=8,  kind="resource", resource="def_slaves", factor="missions", value=500, race="wh2_main_def_dark_elves"},
    {key="bought_loyalty",      guild="khanate",      rank=3, cost=150, cd=12, kind="race_army", value=3, race="wh2_main_def_dark_elves"},
    {key="black_ark_tithe",     guild="slavers",      rank=4, cost=400, cd=16, kind="bundle",   turns=10, lead=true, race="wh2_main_def_dark_elves"},
    {key="whispers_at_court",   guild="khanate",      rank=2, cost=50,  cd=8,  kind="race",     value=30, race="wh2_main_hef_high_elves"},
    {key="phoenix_favour",      guild="brass",        rank=3, cost=150, cd=12, kind="resource", resource="wh3_dlc27_hef_favour", factor="faction", value=50, race="wh2_main_hef_high_elves"},
    {key="asuryans_grace",      guild="daemonsmiths", rank=4, cost=400, cd=16, kind="race",     value=150, value2=40, lead=true, race="wh2_main_hef_high_elves"},
```

After the Kislev and Bretonnia block:

```lua
-- ------------------------------------------ Cathay, Dark Elves, High Elves --
-- REALIGN THE COMPASS: the Winds of Magic compass may be turned again now. The call takes a
-- faction INTERFACE (CA: wh3_main_chaos/wh_start.lua:130). Never for the Celestial Court,
-- whose jade compass is a different system this call does not reach.
GG.CELESTIAL_COURT = "wh3_dlc24_cth_the_celestial_court"
GG.RACE_NEEDS.realign_compass = function(faction) return faction ~= GG.CELESTIAL_COURT end
GG.RACE_FIRE.realign_compass = function(faction)
    cm:set_next_winds_of_magic_compass_selection_cooldown(cm:get_faction(faction), 0)
end

-- IVORY ROAD CARGO: every caravan still on its way carries more, as CA's own event adds it
-- (wh3_campaign_ivory_road_events.lua:551). A caravan coming home is skipped.
function GG.caravans_out(faction)
    local out = {}
    local fc = cm:model():world():caravans_system():faction_caravans(cm:get_faction(faction))
    if fc:is_null_interface() then return out end
    local list = fc:active_caravans()
    for i = 0, list:num_items() - 1 do
        local c = list:item_at(i)
        if not c:is_returning() then out[#out + 1] = c end
    end
    return out
end
GG.RACE_NEEDS.ivory_cargo = function(faction) return #GG.caravans_out(faction) > 0 end
GG.RACE_FIRE.ivory_cargo = function(faction, s)
    local list = GG.caravans_out(faction)
    for i = 1, #list do cm:set_caravan_cargo(list[i], list[i]:cargo() + s.value) end
end

-- BOUGHT LOYALTY for the lord of the selected army (CA: wh2_dlc14_malus_malekiths_favour
-- .lua:29), through a lookup string. Never the faction leader, who has no loyalty to buy.
GG.RACE_TARGET_OK.bought_loyalty = function(_faction, c) return not c:is_faction_leader() end
GG.RACE_FIRE.bought_loyalty = function(_faction, s, target)
    cm:modify_character_personal_loyalty_factor(cm:char_lookup_str(target), s.value)
end

-- INFLUENCE, by faction key (CA: wh3_dlc27_valiant_imperatives.lua:131). A High Elf
-- service only: the Empire's factions turn influence into Prestige.
GG.RACE_FIRE.whispers_at_court = function(faction, s) cm:change_influence(faction, s.value) end

-- ASURYAN'S GRACE: the Phoenix King's favour and influence at once. The favour pool caps at
-- 900, lower while others hold Ulthuan, and clips a grant above it in silence.
GG.RACE_NEEDS.asuryans_grace = function(faction)
    return GG.has_resource(faction, "wh3_dlc27_hef_favour")
end
GG.RACE_FIRE.asuryans_grace = function(faction, s)
    cm:faction_add_pooled_resource(faction, "wh3_dlc27_hef_favour", "faction", s.value)
    cm:change_influence(faction, s.value2)
end
```

In `tools/gen_great_guilds.py` `SERVICES`, after `tales_of_valour`:

```python
    {"key": "realign_compass", "guild": "daemonsmiths", "rank": 2, "cost": 50, "cd": 8,
     "kind": "race", "race": "wh3_main_cth_cathay", "name": "Realign the Compass",
     "text": "The Winds of Magic compass can be turned again at once."},
    {"key": "ivory_cargo", "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race", "race": "wh3_main_cth_cathay", "value": 200, "name": "Ivory Road Cargo",
     "text": "Adds {value} cargo to every caravan of yours still on its way."},
    {"key": "mandate_of_heaven", "guild": "overseers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "race": "wh3_main_cth_cathay", "name": "Mandate of Heaven",
     "effects": [("wh_main_effect_public_order_events", "faction_to_province_own", 4),
                 ("wh3_main_effect_corruption_reduction_events", "faction_to_province_own", -8)],
     "text": "{v0:+d} public order and {v1:+d} corruption in every province you hold, for "
             "{turns} turns."},
    {"key": "slave_coffles", "guild": "slavers", "rank": 2, "cost": 50, "cd": 8,
     "kind": "resource", "race": "wh2_main_def_dark_elves", "resource": "def_slaves",
     "factor": "missions", "value": 500, "name": "Slave Coffles",
     "text": "Adds {value} Slaves."},
    {"key": "bought_loyalty", "guild": "khanate", "rank": 3, "cost": 150, "cd": 12,
     "kind": "race_army", "race": "wh2_main_def_dark_elves", "value": 3,
     "name": "Bought Loyalty",
     "text": "{value:+d} loyalty for the lord of the army you select. Not your faction "
             "leader."},
    {"key": "black_ark_tithe", "guild": "slavers", "rank": 4, "cost": 400, "cd": 16,
     "kind": "bundle", "turns": 10, "race": "wh2_main_def_dark_elves", "name": "Black Ark Tithe",
     "effects": [("wh3_main_pooled_resource_def_slaves_buildings_gained",
                  "faction_to_faction_own_unseen", 80)],
     "text": "{v0:+d} Slaves every turn, for {turns} turns."},
    {"key": "whispers_at_court", "guild": "khanate", "rank": 2, "cost": 50, "cd": 8,
     "kind": "race", "race": "wh2_main_hef_high_elves", "value": 30,
     "name": "Whispers at Court", "text": "Adds {value} Influence."},
    {"key": "phoenix_favour", "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "resource", "race": "wh2_main_hef_high_elves", "resource": "wh3_dlc27_hef_favour",
     "factor": "faction", "value": 50, "name": "The Phoenix King's Favour",
     "text": "Adds {value} Favour of the Phoenix King."},
    {"key": "asuryans_grace", "guild": "daemonsmiths", "rank": 4, "cost": 400, "cd": 16,
     "kind": "race", "race": "wh2_main_hef_high_elves", "value": 150, "value2": 40,
     "name": "Asuryan's Grace",
     "text": "Adds {value} Favour of the Phoenix King and {value2} Influence."},
```

In the generator:
- `RACE_KEY_SINGLES` gains `"CELESTIAL_COURT": "factions"`.
- The Dark Elves' own pool is named Slaves in game, which `check_flavours` refuses as a Chaos Dwarf word. Directly after `CHD_ONLY_WORDS = (...)`:

```python
# A WORD ONE FLAVOUR MAY USE AFTER ALL: the Dark Elves' own pool is called Slaves in game
# (pooled_resources_display_name_def_slaves), and their race services name it.
FLAVOUR_WORDS_ALLOWED = {"_def": ("slave",)}
```

  In `check_flavours`, `            for w in CHD_ONLY_WORDS:` becomes

```python
            for w in CHD_ONLY_WORDS:
                if w in FLAVOUR_WORDS_ALLOWED.get(tag, ()):
                    continue
```

- In `selftest()`, after the shared count, add:

```python
    assert len(SERVICES) - len(shared) == 29, (
        "29 race services, got %d" % (len(SERVICES) - len(shared)))
```

- [ ] **Step 4: Run everything**

Expected:
- Both harnesses ok.
- Check exit 0:
  - Mandate's pairs are vanilla at the right sign;
  - Black Ark's pair is vanilla;
  - `def_slaves`/`missions` and `wh3_dlc27_hef_favour`/`faction` are bound;
  - the Celestial Court is a faction.
- Selftest ok, reporting 83 services.

- [ ] **Step 5: Ledger**

`Task 8: complete (both harnesses ok, generator check 0, selftest 83 services; RED: stock nil)`.

---

### Task 9: Slave Tithe's new payouts

**Files:**
- Modify: `zzz_derpy_guilds.lua` (`GG.payload`, `kind == "pooled"`)
- Modify: `tools/gen_great_guilds.py`: the `slave_tithe` blurbs in `_ksl` and `_def`.
- Test: `tools/_guilds_bounty_harness.lua`

**Interfaces:**
- Consumes: `GG.has_resource` (Task 2).

- [ ] **Step 1: Failing test**

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------- RACES: the Slave Tithe --
do
    -- KISLEV: Devotion through events where the faction holds it, gold where it does not.
    -- DARK ELVES: Slaves through missions (spec §6.2).
    race(KSL)
    F.me.resources = {wh3_main_ksl_devotion = 0}
    GG.payload("me", GG.service("slave_tithe"), nil)
    local c = CALLS.pooled and CALLS.pooled[1]
    assert(c and c[2] == "wh3_main_ksl_devotion" and c[3] == "events" and c[4] == 150,
           "Kislev's tithe is 150 Devotion")
    race(KSL)
    GG.payload("me", GG.service("slave_tithe"), nil)
    assert(CALLS.treasury and CALLS.treasury[1][2] == 3000 and not CALLS.pooled,
           "a Kislev faction without Devotion takes the gold")
    race(DEF)
    GG.payload("me", GG.service("slave_tithe"), nil)
    c = CALLS.pooled and CALLS.pooled[1]
    assert(c and c[2] == "def_slaves" and c[3] == "missions" and c[4] == 1000,
           "the Dark Elves' tithe is 1,000 Slaves")
    ok("the Slave Tithe pays Kislev in Devotion and the Dark Elves in Slaves")
end
```

- [ ] **Step 2: Run the bounty harness and watch it fail**

Expected: exit 1, `Kislev's tithe is 150 Devotion`.

- [ ] **Step 3: The payouts**

In `GG.payload`'s `pooled` branch, directly before its final `        else` (the gold fallback), add:

```lua
        -- GG.culture_of, not the raw GG.CULTURE_OF the Dwarf branch reads: it fills the
        -- cache itself, so a payload reached without a covered() call first is not gold.
        elseif GG.culture_of(faction) == "wh3_main_ksl_kislev"
               and GG.has_resource(faction, "wh3_main_ksl_devotion") then
            -- DEVOTION (2026-09-29, spec §6.2), through "events" as CA grants it
            -- (wh3_tol_something_rotten_in_kislev.lua:19). No DB table assigns Devotion,
            -- so a Kislev faction without it takes the gold below.
            cm:faction_add_pooled_resource(faction, "wh3_main_ksl_devotion", "events", 150)
        elseif GG.culture_of(faction) == "wh2_main_def_dark_elves" then
            -- SLAVES, through "missions" as CA's own payloads grant them
            -- (lib_campaign_mission_manager.lua:2616). Every Dark Elf faction holds them.
            cm:faction_add_pooled_resource(faction, "def_slaves", "missions", 1000)
```

In `tools/gen_great_guilds.py`:
- The `_ksl` flavour's `"slave_tithe"` blurb becomes `"The Ungol Raiders send back your share of the take. Adds 150 Devotion, or 3,000 gold to a faction without Devotion."`
- The `_def` flavour's becomes `"The Black Ark Corsairs send home your share of the plunder. Adds 1,000 Slaves."`

- [ ] **Step 4: Run everything**

Expected: both harnesses ok; generator check exit 0. Both new literals are bound pairs, and the `_def` text may say "Slaves".

- [ ] **Step 5: Ledger**

`Task 9: complete (both harnesses ok, generator check 0; RED: Kislev's tithe)`.

---

### Task 10: The earn routes

CA's evidence:
- `CaravanCompleted` carries `faction()`, for Chaos Dwarf convoys and Cathay's caravans alike. It is heard once (finding 7).
- `PooledResourceChanged` carries:
  - `resource()`, with a `key()`;
  - `amount()`, signed;
  - `factor()`, which may be null;
  - `faction()` behind `has_faction()`.

  It fires for AI factions and for script transactions.
- `RegionFactionChangeEvent` carries `region()`, `previous_faction()` and `reason()`, and has no `new_faction()`.
- `ScriptEventFactionPerformsMotherlandRitual` carries `faction()`. It fires at ritual start, for AI and humans (`generic_incidents.lua:24, :31`).
- `RitualCompletedEvent` carries `performing_faction()`, `ritual():ritual_category()` and `succeeded()`. The AI takes court seats without rituals, so in practice only humans earn by it.

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - after the High Elves block, `GG.EARN_ROUTES`, `GG.EARN_OF`, `GG.POOL_ROUTES`, `GG.pool_route_counts`, `GG.IMPERIAL_LANDS`, `GG.in_imperial_lands`, `GG.RECLAIM_SKIP`, `GG.reclaim_counts` and `GG.race_earn`;
  - `GG.LEDGER_SOURCES`;
  - the `GG.log_add` doc comment;
  - five listeners in `GG.register`.
- Modify: `zzz_derpy_guilds_ui.lua` (`GGUI.log_text`, `GGUI.LOG_FILTERS.mine`).
- Modify: `tools/gen_great_guilds.py`: the log and source loc; `EARN_ROUTES`, `EARN_OF`, `check_race_mirror`; `RACE_KEY_BLOCKS`.
- Test: both harnesses.

**Interfaces:**
- Produces:
  - `GG.race_earn(faction, route, amount) -> paid`;
  - ledger sources `caravan`, `grudges`, `reclaimed`, `motherland`, `chivalry`, `captives` and `court`;
  - Log kind `earn` (`a` = route, `b` = Reputation paid);
  - `GG.earn_carry[faction .. "|" .. route]`, the remainder kept between events.

- [ ] **Step 1: Failing tests**

In `W.reset`, after `GG.self_grants = {}`, add `GG.earn_carry = {}`.

At the end of the bounty harness, before `print("bounty harness ok")`:

```lua
-- ------------------------------------------------------- RACES: the earn routes --
-- A human of `culture` with standing saved, so a listener's GG.load finds it; no turn
-- limit on any guild unless a test sets one.
local function earner(culture)
    race(culture)
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 0, fav = 0} end
    for _, g in ipairs(GG.GUILDS) do GG.TUNE["cap_" .. g] = 0 end
    GG.save("me")
end

local function prc(key, amount, factor)
    return {resource = function() return {key = function() return key end} end,
            has_faction = function() return true end,
            faction = function() return W.fi("me") end,
            amount = function() return amount end,
            factor = function()
                if not factor then return NULL() end
                return {is_null_interface = function() return false end,
                        key = function() return factor end}
            end}
end

local function rep(guild) return (GG.get("me", guild)) end

do
    -- A CARAVAN PAYS THE MERCHANTS for Chaos Dwarfs and Cathay alike, and writes one Log
    -- line of what the guild gained.
    for _, culture in ipairs({CHD, CTH}) do
        earner(culture)
        HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
        assert(rep("brass") == 60, culture .. ": a caravan pays 60, got " .. rep("brass"))
    end
    local e = GG.log_entries("me")[1]
    assert(e and e.kind == "earn" and e.guild == "brass" and e.a == "caravan" and e.b == "60",
           "one Log line: earn, brass, caravan, 60")
    earner(DWF)
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 0, "a Dwarf caravan pays nothing")
    ok("a completed caravan pays the Merchants for the two caravan races")
end

do
    -- THE TURN LIMIT BINDS, and the Log says what was actually paid - nothing when nothing.
    earner(CTH)
    GG.TUNE.cap_brass = 40
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 40, "the Merchants' limit of 40 binds")
    assert(GG.log_entries("me")[1].b == "40", "and the Log says 40")
    local function earns()
        local n = 0
        for _, e in ipairs(GG.log_entries("me")) do if e.kind == "earn" then n = n + 1 end end
        return n
    end
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 40 and earns() == 1,
           "a second caravan over the limit pays nothing and writes nothing")
    ok("an earning meets its guild's turn limit, and the Log reports what was paid")
end

do
    -- GRUDGES: every rise pays, but not the part a purchase granted (Review Focus 3).
    earner(DWF)
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 30, "settled"))
    assert(rep("immortals") == 10, "a grudge settled pays 10")
    GG.note_self("me", "wh3_dlc25_dwf_grudge_points", 200)
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 200, "settled"))
    assert(rep("immortals") == 10, "Strike Lines' own 200 pays nothing")
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", -50, "settled"))
    assert(rep("immortals") == 10, "a fall pays nothing")
    ok("settled grudges pay the Ironbreakers, never for the purchase itself")
end

do
    -- CHIVALRY one per 5, the remainder kept; never through missions. CAPTIVES one per 20,
    -- from raiding and battles only.
    earner(BRT)
    HANDLERS.gg_earn_pool(prc("brt_chivalry", 12, "battles"))
    HANDLERS.gg_earn_pool(prc("brt_chivalry", 8, "battles"))
    assert(rep("immortals") == 4, "12 then 8 chivalry is 4 Reputation, got " .. rep("immortals"))
    HANDLERS.gg_earn_pool(prc("brt_chivalry", 150, "missions"))
    assert(rep("immortals") == 4, "chivalry through missions pays nothing")
    earner(DEF)
    HANDLERS.gg_earn_pool(prc("def_slaves", 45, "raiding"))
    HANDLERS.gg_earn_pool(prc("def_slaves", 20, "battles"))
    HANDLERS.gg_earn_pool(prc("def_slaves", 500, "missions"))
    HANDLERS.gg_earn_pool(prc("def_slaves", 60, nil))
    assert(rep("slavers") == 3, "65 Slaves by raid and battle is 3, got " .. rep("slavers"))
    ok("Chivalry and captives pay per so many, from the right sources only")
end

do
    -- LAND OF THE OLD EMPIRE TAKEN BACK, not handed over, traded or abandoned.
    earner(EMP)
    W.faction("vc", {culture = "wh_main_vmp_vampire_counts", regions = {}, lords = {}})
    W.faction("emp2", {culture = EMP, regions = {}, lords = {}})
    local function rfce(prev, why, in_lands)
        return {region = function()
                    return {owning_faction = function() return W.fi("me") end,
                            is_contained_in_region_group = function(_, g)
                                return in_lands and g == GG.IMPERIAL_LANDS[2] end}
                end,
                previous_faction = function() return prev and W.fi(prev) or NULL() end,
                reason = function() return why end}
    end
    HANDLERS.gg_earn_reclaimed(rfce("vc", "normal capture", true))
    assert(rep("immortals") == 50, "taken from the Vampire Counts: 50")
    HANDLERS.gg_earn_reclaimed(rfce("emp2", "normal capture", true))
    HANDLERS.gg_earn_reclaimed(rfce("vc", "diplomacy trade", true))
    HANDLERS.gg_earn_reclaimed(rfce("vc", "normal capture", false))
    assert(rep("immortals") == 50, "not from the Empire, not by trade, not outside the lands")
    HANDLERS.gg_earn_reclaimed(rfce(nil, "normal capture", true))
    assert(rep("immortals") == 100, "a ruin in the old lands counts")
    ok("the Empire earns for taking back its own lands, by conquest only")
end

do
    -- A MOTHERLAND RITUAL BEGUN; A COURT ACTION THAT SUCCEEDED.
    earner(KSL)
    HANDLERS.gg_earn_motherland({faction = function() return W.fi("me") end})
    assert(rep("daemonsmiths") == 40, "a Motherland ritual pays 40")
    earner(HEF)
    local function ritual(cat, won)
        return {ritual = function() return {ritual_category = function() return cat end} end,
                succeeded = function() return won end,
                performing_faction = function() return W.fi("me") end}
    end
    HANDLERS.gg_earn_court(ritual("HEF_COURT_ACTION_TAKE_PATRONAGE", true))
    assert(rep("khanate") == 40, "a court action pays 40")
    HANDLERS.gg_earn_court(ritual("HEF_COURT_ACTION_TRIBUTE", false))
    HANDLERS.gg_earn_court(ritual("TYRION_IMPERATIVE_HEIR", true))
    assert(rep("khanate") == 40, "not a failed one, not another category")
    ok("Kislev and the High Elves earn by their own rituals")
end

do
    -- RACE DIFFERENCES OFF: no earning at all (Review Focus 2).
    earner(CHD)
    GG.TUNE.race_differences = false
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 0, "race differences off: a caravan pays nothing")
    ok("no race earns with race differences off")
end
```

In `tools/_guilds_harness.lua`, before `print("harness ok")`:

```lua
;(function()
    -- A RACE EARNING IN THE LOG (2026-09-29 stage 2): what happened and what it paid,
    -- good news, under Yours.
    local line, bad = GGUI.log_text({turn = 9, kind = "earn", guild = "brass",
                                     a = "caravan", b = "60"})
    assert(type(line) == "string" and line:find("log_earn_caravan", 1, true)
           and line:find("60", 1, true), "the earn line names the route and the 60, got "
           .. tostring(line))
    assert(not bad, "an earning is good news")
    assert(GGUI.LOG_FILTERS.mine.earn, "it is under the Yours filter")
end)()
```

- [ ] **Step 2: Run both and watch them fail**

Expected:
- The bounty harness fails: `attempt to call field 'gg_earn_caravan' (a nil value)`.
- The main harness fails on `the earn line names the route and the 60`.

- [ ] **Step 3: The routes**

After the High Elves block:

```lua
-- ------------------------------------------------------------ race earnings --
-- WHAT ONLY ONE RACE DOES, paid to the guild of that trade (spec §7), through
-- GG.capped_grant like every other earning - so the guild's turn limit, the rival's share
-- and the patron all apply. The route key is the ledger source, so letters only. Mirrored
-- by EARN_ROUTES and EARN_OF in tools/gen_great_guilds.py (check_race_mirror), whose Help
-- page names the guild.
GG.EARN_ROUTES = {
    caravan    = {guild = "brass",        rep = 60},
    grudges    = {guild = "immortals",    rep = 10},
    reclaimed  = {guild = "immortals",    rep = 50},
    motherland = {guild = "daemonsmiths", rep = 40},
    chivalry   = {guild = "immortals",    per = 5},
    captives   = {guild = "slavers",      per = 20},
    court      = {guild = "khanate",      rep = 40},
}
-- Which race earns by which route. CaravanCompleted is raised for Chaos Dwarf convoys and
-- Cathay's caravans alike, so both earn by it.
GG.EARN_OF = {
    ["wh3_dlc23_chd_chaos_dwarfs"] = "caravan",
    ["wh3_main_cth_cathay"]        = "caravan",
    ["wh_main_dwf_dwarfs"]         = "grudges",
    ["wh_main_emp_empire"]         = "reclaimed",
    ["wh3_main_ksl_kislev"]        = "motherland",
    ["wh_main_brt_bretonnia"]      = "chivalry",
    ["wh2_main_def_dark_elves"]    = "captives",
    ["wh2_main_hef_high_elves"]    = "court",
}
-- The pools an earning listens to, and which of their factors count.
GG.POOL_ROUTES = {wh3_dlc25_dwf_grudge_points = "grudges", brt_chivalry = "chivalry",
                  def_slaves = "captives"}
-- Captives from raiding and battle only. Chivalry from anything but "missions", which Tales
-- of Valour grants through and CA's own chivalry writes never use.
function GG.pool_route_counts(route, factor)
    if route == "captives" then return factor == "raiding" or factor == "battles" end
    if route == "chivalry" then return factor ~= "missions" end
    return true
end

-- THE OLD EMPIRE'S LANDS: both of CA's region groups, tested by name. CA builds the key from
-- cm:get_campaign_name(), which answers a map name on some maps (docs/VICTORY_CONDITIONS.md
-- §11). A group this map lacks answers false.
GG.IMPERIAL_LANDS = {
    "wh3_dlc25_imperial_authority_regions_main_warhammer",
    "wh3_dlc25_imperial_authority_regions_wh3_main_chaos",
}
function GG.in_imperial_lands(region)
    for i = 1, #GG.IMPERIAL_LANDS do
        if region:is_contained_in_region_group(GG.IMPERIAL_LANDS[i]) then return true end
    end
    return false
end
-- TAKEN BACK, not handed over: from a faction that is not the Empire, and not by a trade two
-- players could repeat for ever, an abandonment, or the game setting itself up.
GG.RECLAIM_SKIP = {["abandoned"] = true, ["abandoned to rebels"] = true,
                   ["startpos setup"] = true, ["cli command"] = true,
                   ["diplomacy trade"] = true}
function GG.reclaim_counts(prev_culture, reason)
    return prev_culture ~= "wh_main_emp_empire" and not GG.RECLAIM_SKIP[reason or ""]
end

-- What a points route has not paid out yet, per faction and route: session memory, so a
-- raid of 12 Slaves is not lost every turn.
GG.earn_carry = GG.earn_carry or {}

-- PAYS `faction` BY `route` when that is its race's route: `rep` a time, or one per `per`
-- of `amount`. Returns what the guild gained after its turn limit, and writes the Log line
-- only when that is something.
function GG.race_earn(faction, route, amount)
    local r = GG.EARN_ROUTES[route]
    if not r or not faction or not GG.race_on() then return 0 end
    if GG.EARN_OF[GG.culture_of(faction) or ""] ~= route then return 0 end
    local n = r.rep
    if not n then
        local k = faction .. "|" .. route
        local have = (GG.earn_carry[k] or 0) + (amount or 0)
        n = math.floor(have / r.per)
        GG.earn_carry[k] = have - n * r.per
    end
    if n <= 0 then return 0 end
    local before = GG.get(faction, r.guild)
    GG.capped_grant(faction, r.guild, n, route)
    local paid = GG.get(faction, r.guild) - before
    if paid > 0 then GG.log_add(faction, "earn", r.guild, route, paid) end
    return paid
end
```

`GG.LEDGER_SOURCES` becomes:

```lua
GG.LEDGER_SOURCES = {"income", "battles", "research", "agents", "buildings",
                     "settlements", "missions", "bounties", "demands", "other",
                     "withheld",
                     -- THE RACE EARNINGS (stage 2), one per route, by name.
                     "caravan", "grudges", "reclaimed", "motherland", "chivalry",
                     "captives", "court"}
```

In the comment block above `GG.log_add`, after `--   lead_lost  a = the faction that took it`, add `--   earn       a = the race's route, b = Reputation the guild gained`.

In `GG.register`, directly before the `gg_battle` listener:

```lua
    -- --------------------------------------------------- race earnings (spec §7) --
    -- CaravanCompleted carries faction() (scripting_doc). CA re-raises the same context
    -- as ScriptEventCaravanCompleted (caravans_core.lua:816); only the engine's is heard,
    -- or every caravan would pay twice.
    core:add_listener("gg_earn_caravan", "CaravanCompleted", true, function(context)
        local name = faction_name_of(context)
        if not name then return end
        GG.load(name); GG.race_earn(name, "caravan"); GG.save(name)
    end, true)

    -- PooledResourceChanged fires for EVERY pool change in the game, so the key is read
    -- first. factor() may be null, and faction() is read only behind has_faction().
    core:add_listener("gg_earn_pool", "PooledResourceChanged", true, function(context)
        local okk, key = pcall(function() return context:resource():key() end)
        if not okk then return end
        local route = GG.POOL_ROUTES[key]
        if not route then return end
        local okh, has = pcall(function() return context:has_faction() end)
        if not okh or not has then return end
        local oka, amount = pcall(function() return context:amount() end)
        if not oka or type(amount) ~= "number" or amount <= 0 then return end
        local factor = ""
        pcall(function()
            local f = context:factor()
            if not f:is_null_interface() then factor = f:key() end
        end)
        if not GG.pool_route_counts(route, factor) then return end
        local name = faction_name_of(context)
        if not name then return end
        amount = GG.take_self(name, key, amount)
        if amount <= 0 then return end
        GG.load(name); GG.race_earn(name, route, amount); GG.save(name)
    end, true)

    -- RegionFactionChangeEvent carries region(), previous_faction() and reason() - no
    -- new_faction(), so the new owner is read off the region, as CA does
    -- (wh3_dlc25_imperial_authority.lua:89).
    core:add_listener("gg_earn_reclaimed", "RegionFactionChangeEvent", true, function(context)
        local okr, name, prev, why = pcall(function()
            local r = context:region()
            local o = r:owning_faction()
            if o:is_null_interface() or not GG.in_imperial_lands(r) then return nil end
            local p = context:previous_faction()
            return o:name(), (not p:is_null_interface()) and p:culture() or "",
                   context:reason()
        end)
        if not okr or not name or not GG.reclaim_counts(prev, why) then return end
        GG.load(name); GG.race_earn(name, "reclaimed"); GG.save(name)
    end, true)

    -- CA's own event, raised at a Motherland ritual's START for AI and humans alike
    -- (wh3_campaign_generic_incidents.lua:24, :31), carrying faction().
    core:add_listener("gg_earn_motherland", "ScriptEventFactionPerformsMotherlandRitual", true,
        function(context)
            local name = faction_name_of(context)
            if not name then return end
            GG.load(name); GG.race_earn(name, "motherland"); GG.save(name)
        end, true)

    -- RitualCompletedEvent carries performing_faction(), ritual() and succeeded(). Every
    -- High Elf court category starts HEF_COURT_ACTION_ (ritual_categories). The AI takes
    -- court seats without rituals (intrigue_at_the_court.lua:1707), so humans earn this.
    core:add_listener("gg_earn_court", "RitualCompletedEvent", true, function(context)
        local okc, cat, won = pcall(function()
            return context:ritual():ritual_category(), context:succeeded()
        end)
        if not okc or not won or type(cat) ~= "string" then return end
        if string.sub(cat, 1, 17) ~= "HEF_COURT_ACTION_" then return end
        local name = faction_name_of(context, function() return context:performing_faction() end)
        if not name then return end
        GG.load(name); GG.race_earn(name, "court"); GG.save(name)
    end, true)
```

In `zzz_derpy_guilds_ui.lua`:
- In `GGUI.log_text`, directly before `    elseif k == "rotation" then`, add:

```lua
    elseif k == "earn" then
        -- A RACE EARNING (stage 2): what the race did and what the guild gained for it.
        body = GGUI.loc("log_earn_" .. e.a) .. " (+" .. e.b .. " " .. GGUI.loc("reputation")
               .. ")"
```

- `GGUI.LOG_FILTERS`' `mine` line becomes `    mine   = {buy = true, refund = true, rank = true, lead_won = true, rotation = true, earn = true},`.

In `tools/gen_great_guilds.py`, in the UI loc tuple list, after the two `unavailable` lines:

```python
                      # THE RACE EARNINGS (stage 2): GGUI.log_text builds
                      # "log_earn_" .. route at draw time, so check_race_mirror proves
                      # each ships. Lower case, no full stop.
                      ("log_earn_caravan", "a caravan reached its destination"),
                      ("log_earn_grudges", "grudges were settled"),
                      ("log_earn_reclaimed", "land of the old Empire was taken back"),
                      ("log_earn_motherland", "a Motherland ritual was begun"),
                      ("log_earn_chivalry", "deeds of chivalry were done"),
                      ("log_earn_captives", "captives were taken"),
                      ("log_earn_court", "a court action succeeded"),
```

In the `src_` tuple list, after `("src_withheld", "Over the limit, not paid:")`:

```python
                      ("src_caravan", "caravans"), ("src_grudges", "grudges"),
                      ("src_reclaimed", "land taken back"),
                      ("src_motherland", "Motherland rituals"),
                      ("src_chivalry", "chivalry"), ("src_captives", "captives"),
                      ("src_court", "court actions"),
```

After `check_race_keys`:

```python
# THE RACE EARNINGS, mirrored from GG.EARN_ROUTES and GG.EARN_OF: the Help page names the
# guild each pays, and the Log line each writes is built from the route key.
EARN_ROUTES = {"caravan": "brass", "grudges": "immortals", "reclaimed": "immortals",
               "motherland": "daemonsmiths", "chivalry": "immortals",
               "captives": "slavers", "court": "khanate"}
EARN_OF = {"wh3_dlc23_chd_chaos_dwarfs": "caravan", "wh3_main_cth_cathay": "caravan",
           "wh_main_dwf_dwarfs": "grudges", "wh_main_emp_empire": "reclaimed",
           "wh3_main_ksl_kislev": "motherland", "wh_main_brt_bretonnia": "chivalry",
           "wh2_main_def_dark_elves": "captives", "wh2_main_hef_high_elves": "court"}


def check_race_mirror(lua=None):
    """The model's race tables must be this file's, and every route's Log line must ship."""
    if lua is None:
        lua = io.open(MODEL_LUA, encoding="utf-8").read()
    out = []
    m = re.search(r"^GG\.EARN_ROUTES = \{(.*?)\n\}", lua, re.S | re.M)
    got = dict(re.findall(r'(\w+)\s*=\s*\{guild\s*=\s*"(\w+)"', m.group(1))) if m else {}
    if got != EARN_ROUTES:
        out.append("GG.EARN_ROUTES pays %r and this file says %r" % (got, EARN_ROUTES))
    m = re.search(r"^GG\.EARN_OF = \{(.*?)\n\}", lua, re.S | re.M)
    got = dict(re.findall(r'\["([^"]+)"\]\s*=\s*"(\w+)"', m.group(1))) if m else {}
    if got != EARN_OF:
        out.append("GG.EARN_OF is %r and this file says %r" % (got, EARN_OF))
    have = set(r["key"] for r in build()["loc"])
    for route in sorted(EARN_ROUTES):
        for tag in FLAVOURS:
            if "derpy_gg_log_earn_" + route + tag not in have:
                out.append("no derpy_gg_log_earn_%s%s, so the Log prints the bare key"
                           % (route, tag))
    return out
```

In `check()`, after `    out += check_race_keys()`, add `    out += check_race_mirror()`.

`RACE_KEY_BLOCKS` gains `"IMPERIAL_LANDS": "region_groups"`. The installed table's key column must be `key`. If `check_race_keys` reports both groups missing, print one `live_rows("region_groups")` row, use its key column, and ledger a ruling.

In `selftest()`, before the race probe block:

```python
    # The race mirror measures: a route paying the wrong guild fails it.
    lua_bad = lua.replace('caravan    = {guild = "brass"', 'caravan    = {guild = "slavers"')
    assert any("EARN_ROUTES" in p for p in check_race_mirror(lua_bad)), \
        "a drifted earn route slipped by"
```

- [ ] **Step 4: Run everything**

Expected:
- `bounty harness ok` and `harness ok`.
- Generator check exit 0; `check_ledger_sources` finds all seven `src_` rows in every flavour.
- Selftest ok.

- [ ] **Step 5: Ledger**

`Task 10: complete (both harnesses ok, generator check 0; RED: gg_earn_caravan nil, earn line)`.

---

### Task 11: The panel - race label, twist mirror, Help page

**Files:**
- Modify: `zzz_derpy_guilds_ui.lua`: new `GGUI.card_body`; `GGUI.draw_card`; `GGUI.HELP_PAGES`.
- Modify: `tools/gen_great_guilds.py`: `TWISTS`, `RACE_TEXT`, `HELP_PAGE_TITLES`, `help_pages` page 6, the `race_label` loc per flavour, `check_race_mirror` (twists), the `_unseen` rule over every flavour, and selftest assertions.
- Test: `tools/_guilds_harness.lua`; generator selftest; `py tools/gen_guilds_ui.py --check`.

**Interfaces:**
- Consumes: `EARN_OF` and `EARN_ROUTES` (Task 10); the race rows' `lord` field (Task 6).
- Produces:
  - `GGUI.card_body(s, tip) -> string`;
  - loc `derpy_gg_race_label` + tag;
  - Help page 6, `derpy_gg_help_p6` + tag.

- [ ] **Step 1: Failing tests**

In `tools/_guilds_harness.lua`, before `print("harness ok")`:

```lua
;(function()
    -- A RACE'S OWN SERVICE SAYS SO ON ITS CARD (spec §9), ahead of what it does; a shared
    -- one does not.
    local tip = "Adds 40 Conclave Influence.||Costs 50 favour."
    local body = GGUI.card_body({key = "conclave_favour", race = "wh3_dlc23_chd_chaos_dwarfs"}, tip)
    assert(body:find("race_label", 1, true) and body:find("Adds 40 Conclave Influence.", 1, true)
           and not body:find("Costs", 1, true), "the race label, then the body, got " .. body)
    assert(GGUI.card_body({key = "forge_rite"}, tip) == "Adds 40 Conclave Influence.",
           "a shared service has no label")
    assert(GGUI.HELP_PAGES == 6, "the Help tab has the race page")
end)()
```

In the generator `selftest()`, at its end before the final `print`:

```python
    # THE RACE PAGE (stage 2): each covered race's page 6 names every one of its own
    # services, its earning's guild and its rule; the generic flavour says it has none.
    for tag, F in FLAVOURS.items():
        page = help_pages(tag)[5]
        text = " ".join(page)
        if not F["culture"]:
            assert "no services" in text, text
            continue
        for s in SERVICES:
            if s.get("race") == F["culture"] and not s.get("lord"):
                assert F["services"][s["key"]] in text, (tag, s["key"])
        g = F["guilds"][EARN_ROUTES[EARN_OF[F["culture"]]]]
        assert g in text, (tag, g)
        assert RACE_TEXT[tag]["twist"][0] in text, (tag, "twist")
    # The twist mirror measures: a drifted percentage fails it.
    lua_bad = lua.replace("demand_every = 67", "demand_every = 70")
    assert any("TWISTS" in p for p in check_race_mirror(lua_bad)), "a drifted twist slipped by"
```

- [ ] **Step 2: Run both and watch them fail**

Expected:
- The main harness fails: `attempt to call field 'card_body' (a nil value)`.
- The generator selftest fails with `IndexError` on `help_pages(tag)[5]`.

- [ ] **Step 3: The card**

In `zzz_derpy_guilds_ui.lua`, directly before `function GGUI.card_state(faction, s)`:

```lua
-- THE CARD'S TWO LINES: what the service does, the tooltip's first paragraph. A race's own
-- service says so first (spec §9), in yellow, so the one card no other race sees is found
-- at a glance.
function GGUI.card_body(s, tip)
    local body = tip:match("^(.-)||") or tip
    if s.race then
        body = "[[col:yellow]]" .. GGUI.loc("race_label") .. "[[/col]]  " .. body
    end
    return body
end
```

In `GGUI.draw_card`, `    local body = tip:match("^(.-)||") or tip` becomes `    local body = GGUI.card_body(s, tip)`.

`GGUI.HELP_PAGES  = 5` becomes `GGUI.HELP_PAGES  = 6`.

- [ ] **Step 4: The generator**

After `check_race_mirror`'s module tables (`EARN_OF`), add:

```python
# EACH RACE BENDS ONE RULE, mirrored from GG.TWISTS (whole percentages).
TWISTS = {
    "wh3_dlc23_chd_chaos_dwarfs": {"demand_every": 67, "demand_reward": 150},
    "wh_main_dwf_dwarfs": {"rate_bounty_fail": 150, "demand_penalty": 200},
    "wh_main_emp_empire": {"rate_rivalry": 150},
    "wh3_main_ksl_kislev": {"rate_decay": 50},
    "wh_main_brt_bretonnia": {"demand_reward": 150, "demand_penalty": 200},
    "wh3_main_cth_cathay": {"rate_rivalry": 50},
    "wh2_main_def_dark_elves": {"rate_rivalry": 150, "hostile_price": 75},
    "wh2_main_hef_high_elves": {"favour_cap": 150},
}

# EACH RACE'S OWN WORDS for its page and its cards: the label on a race card, how its
# guilds earn ({g} is that guild's name in this flavour), and the rule it bends.
RACE_TEXT = {
    "": {"label": "Chaos Dwarf",
         "earn": "A convoy that reaches its destination pays {g}.",
         "twist": ("Hashut's tithe", "the guilds make demands more often, and a demand "
                   "you pay is worth half again as much.")},
    "_emp": {"label": "Empire",
             "earn": "Taking back a settlement of the old Empire from a foreign power "
                     "pays {g}.",
             "twist": ("Petty rivalries", "earning with a guild takes half again as much "
                       "from its rival.")},
    "_dwf": {"label": "Dwarf",
             "earn": "Every grudge settled pays {g}.",
             "twist": ("Never forgotten", "a bounty you fail costs half again as much "
                       "Reputation, and a demand you let expire costs twice as much.")},
    "_brt": {"label": "Bretonnia",
             "earn": "Chivalry you earn pays {g}, a little for every five points.",
             "twist": ("Noblesse oblige", "a demand you pay is worth half again as much, "
                       "and one you let expire costs twice as much.")},
    "_cth": {"label": "Cathay",
             "earn": "A caravan that reaches its destination pays {g}.",
             "twist": ("Harmony", "earning with a guild takes only half as much from its "
                       "rival.")},
    "_ksl": {"label": "Kislev",
             "earn": "Beginning a Motherland ritual pays {g}.",
             "twist": ("Hardy folk", "the upkeep every guild charges is halved.")},
    "_def": {"label": "Dark Elf",
             "earn": "Slaves taken in battle or by raiding pay {g}, a little for every "
                     "twenty.",
             "twist": ("Cutthroat", "earning with a guild takes half again as much from "
                       "its rival, and services aimed at your enemies cost a quarter "
                       "less.")},
    "_hef": {"label": "High Elf",
             "earn": "A court action that succeeds pays {g}.",
             "twist": ("Ancient houses", "each guild lets you hold half again as much "
                       "favour.")},
    "_gen": {"label": "Own", "earn": None, "twist": None},
}
```

In `check_race_mirror`, before `return out`, add:

```python
    m = re.search(r"^GG\.TWISTS = \{(.*?)\n\}", lua, re.S | re.M)
    got = {}
    for c, body in re.findall(r'\["([^"]+)"\]\s*=\s*\{([^}]*)\}', m.group(1) if m else ""):
        got[c] = dict((k, int(v)) for k, v in re.findall(r"(\w+)\s*=\s*(\d+)", body))
    if got != TWISTS:
        out.append("GG.TWISTS is %r and this file says %r - the Help page describes a "
                   "rule the game does not apply" % (got, TWISTS))
```

`HELP_PAGE_TITLES` gains `"Your race"` at its end.

In `help_pages`, directly before `    return [page1, page2, page3, page4, page5]`:

```python
    # YOUR RACE (stage 2): the changing services, and what this race alone gets.
    page6 = [
        "#Services change",
        "-Every few turns - ten, unless the settings say otherwise - each guild changes the "
        "three services it offers. The footer counts down to the next change.",
        "-A service that goes keeps its cooldown, and comes back showing what is left of it.",
    ]
    culture = FLAVOURS[tag]["culture"]
    R = RACE_TEXT[tag]
    own = [s for s in SERVICES if s.get("race") and s["race"] == culture]
    if not own:
        page6 += ["#Your race", "-Your race has no services, earnings or rules of its own "
                                "here."]
    else:
        names = [FLAVOURS[tag]["services"][s["key"]] for s in own if not s.get("lord")]
        lords = [s["lord"] for s in own if s.get("lord")]
        listed = ", ".join(names[:-1]) + " and " + names[-1]
        line = ("-Only your race is offered %s, marked %s on the card. At least one of "
                "your own is always on show." % (listed, R["label"]))
        if lords:
            line = line[:-1] + (", and %s and %s each have one more of their own."
                                % (", ".join(lords[:-1]), lords[-1]))
        page6 += [
            "#Services of your own", line,
            "#What else pays",
            "-" + R["earn"].format(g=GUILD_NAMES[EARN_ROUTES[EARN_OF[culture]]]),
            "#One rule bent",
            "-%s: %s" % R["twist"],
            "-Race differences in the settings switches all of this off: then every race "
            "plays alike.",
        ]
```

and the return becomes `    return [page1, page2, page3, page4, page5, page6]`.

The Empire's lord line is a sentence change: when `lords` is not empty, the line ends "...always on show, and Karl Franz, Elspeth von Draken, Balthasar Gelt, Boris Todbringer and Markus Wulfhart each have one more of their own." `line[:-1]` drops the full stop before the clause is added.

In `_build_one`, directly after the loop appending `derpy_gg_rank_name_%d`:

```python
    loc.append({"key": "derpy_gg_race_label", "text": RACE_TEXT[tag]["label"],
                "tooltip": "false"})
```

The `_unseen` rule. In `selftest()`, directly after the existing `_unseen` loop, add:

```python
    # AND EVERY FLAVOUR'S RACE BUNDLES (stage 2): the Warrant, the Peasant Levies and the
    # Black Ark Tithe hide their line, so each description must state the number.
    full_loc = dict((r["key"], r["text"]) for r in build()["loc"])
    for r in build()["effect_bundles_to_effects_junctions"]:
        base = r["effect_bundle_key"]
        if "unseen" not in r["effect_scope"] or base in unseen_ok:
            continue
        n = str(abs(int(r["value"])))
        assert n in full_loc.get("effect_bundles_localised_description_" + base, ""), (
            "%s hides its line, so its description must state %s" % (base, n))
```

- [ ] **Step 5: Run everything**

Run both harnesses, the generator `--selftest`, `--check` and `--write`, then `py tools/gen_guilds_ui.py --check`.

Expected:
- `harness ok` and `bounty harness ok`.
- Selftest ok, check exit 0.
- `gen_guilds_ui.py --check` exit 0. Its real-font fit check passes page 6 in every flavour.

If a page 6 overflows its 21 slots, shorten its longest bullet, never the slots. The Empire's is the long one.

- [ ] **Step 6: Look at it**

Run `py tools/preview_guilds_panel.py` for the Chaos Dwarf and Empire flavours, and read the Help page 6 PNG and a card with a race row.

The preview's text is PIL's font, so it is a layout look, not a fit proof. That proof is `gen_guilds_ui.py --check`.

Ledger what was seen.

- [ ] **Step 7: Ledger**

`Task 11: complete (both harnesses ok, generator selftest/check 0, gen_guilds_ui check 0; RED: card_body nil, help page 6)`.

---

### Task 12: Mutants

**Files:**
- Modify: `tools/mutate_guilds.py`

- [ ] **Step 1: Add the mutants**

Append these to `MUTANTS`. `M` is the model file (LF) and `U` is the UI file (CRLF). Each anchor must occur exactly once. If one does not, because the code differs from this plan, widen it and ledger a ruling.

```python
    # RACE MECHANICS, stage 2 (2026-09-29).
    ("a race row drawn for another race", M,
     b"    if s.race ~= nil and (not GG.race_on() or s.race ~= GG.culture_of(faction)) then",
     b"    if s.race ~= nil and (not GG.race_on()) then"),
    ("race rows drawn with race differences off", M,
     b"    if s.race ~= nil and (not GG.race_on() or s.race ~= GG.culture_of(faction)) then",
     b"    if s.race ~= nil and (s.race ~= GG.culture_of(faction)) then"),
    ("a hook gone since the draw still sold", M,
     b"    if not GG.needs_ok(faction, s) then return false, \"unavailable\" end",
     b""),
    ("a pool grant without the pool", M,
     b"    if s.kind == \"resource\" and not GG.has_resource(faction, s.resource) then return false end",
     b""),
    ("no race service forced on show", M,
     b"    GG.show_race_service(faction, old, keys, pools)\n",
     b""),
    ("a race service forced with race differences off", M,
     b"function GG.show_race_service(faction, old, keys, pools)\n    if not GG.race_on() then return end",
     b"function GG.show_race_service(faction, old, keys, pools)"),
    ("a purchase paying its own earning", M,
     b"        amount = GG.take_self(name, key, amount)\n",
     b""),
    ("last turn's record eating a real earning", M,
     b"    if r.turn ~= GG.turn_now() then return amount end\n    local left",
     b"    local left"),
    ("an earning paid to another race", M,
     b"    if GG.EARN_OF[GG.culture_of(faction) or \"\"] ~= route then return 0 end",
     b""),
    ("an earning with race differences off", M,
     b"    if not r or not faction or not GG.race_on() then return 0 end",
     b"    if not r or not faction then return 0 end"),
    ("captives from any source", M,
     b"    if route == \"captives\" then return factor == \"raiding\" or factor == \"battles\" end",
     b""),
    ("chivalry through missions counted", M,
     b"    if route == \"chivalry\" then return factor ~= \"missions\" end",
     b""),
    ("land taken from the Empire itself paid", M,
     b"    return prev_culture ~= \"wh_main_emp_empire\" and not GG.RECLAIM_SKIP[reason or \"\"]",
     b"    return not GG.RECLAIM_SKIP[reason or \"\"]"),
    ("a remainder thrown away", M,
     b"        GG.earn_carry[k] = have - n * r.per",
     b"        GG.earn_carry[k] = 0"),
    ("a Log line for nothing paid", M,
     b"    if paid > 0 then GG.log_add(faction, \"earn\", r.guild, route, paid) end",
     b"    GG.log_add(faction, \"earn\", r.guild, route, paid)"),
    ("the twists ignored", M,
     b"    local p = GG.twist(faction, key)\n    if type(v)",
     b"    local p = 100\n    if type(v)"),
    ("a rule switched on rounded to off", M,
     b"    local n = math.floor(v * p / 100)\n    if n < 1 then n = 1 end",
     b"    local n = math.floor(v * p / 100)"),
    ("a rule switched off switched back on", M,
     b"    if type(v) ~= \"number\" or v <= 0 or p == 100 then return v end",
     b"    if type(v) ~= \"number\" or p == 100 then return v end"),
    ("twists with race differences off", M,
     b"    if not faction or not GG.race_on() then return 100 end",
     b"    if not faction then return 100 end"),
    ("rivalry read without the race", M,
     b"function GG.rival_loss(amount, faction)\n    local share = GG.setting_for(faction, \"rate_rivalry\")",
     b"function GG.rival_loss(amount, faction)\n    local share = GG.setting(\"rate_rivalry\")"),
    ("upkeep read without the race", M,
     b"    local share = GG.setting_for(faction, \"rate_decay\")",
     b"    local share = GG.setting(\"rate_decay\")"),
    ("a demand's timing read without the race", M,
     b"    local every = GG.setting_for(faction, \"demand_every\") or 0",
     b"    local every = GG.setting(\"demand_every\") or 0"),
    ("the favour cap without the race", M,
     b"    cap = math.floor(cap * GG.twist(faction, \"favour_cap\") / 100)\n",
     b""),
    ("a hostile service's price without the race", M,
     b"              and GG.twist(faction, \"hostile_price\") or 100",
     b"              and 100 or 100"),
    ("a failed bounty read without the race", M,
     b"    local share = GG.setting_for(faction, \"rate_bounty_fail\")",
     b"    local share = GG.setting(\"rate_bounty_fail\")"),
    ("a blessed army blessed again", M,
     b"    return not Has_Blessing_Already(mf:command_queue_index())\n       and not mf:has_effect_bundle(\"wh_dlc07_blessing_of_the_lady\")",
     b"    return true"),
    ("the Reckoning below the top level", M,
     b"    return grudge_cycle:get_current_grudge_level(faction) == 5",
     b"    return grudge_cycle:get_current_grudge_level(faction) >= 1"),
    ("the Reckoning on a rival's card", M,
     b"    if not GG.is_human(faction) then return false end\n    if cm:get_factions_bonus_value",
     b"    if cm:get_factions_bonus_value"),
    ("the blunderbusses' message by CA's broken key", M,
     b"        cm:trigger_incident(faction, GG.HELLFORGE_INCIDENT_FIX[rk]\n                                     or (",
     b"        cm:trigger_incident(faction, nil\n                                     or ("),
    ("the Muster on a full army", M,
     b"            if s.kind ~= \"unit\" and not s.room then return true end",
     b"            if s.kind ~= \"unit\" then return true end"),
    ("the court that is ahead", M,
     b"    return orth < ice and \"orthodoxy\" or \"ice_court\"",
     b"    return orth > ice and \"orthodoxy\" or \"ice_court\""),
    ("cargo on a caravan coming home", M,
     b"        if not c:is_returning() then out[#out + 1] = c end",
     b"        out[#out + 1] = c"),
    ("the Supply Train for a rival", M,
     b"    return faction == GG.WULFHART and GG.is_human(faction)",
     b"    return faction == GG.WULFHART"),
    ("the most loyal Elector favoured", M,
     b"    for band = 0, 9 do",
     b"    for band = 9, 0, -1 do"),
    ("loyalty bought for the faction leader", M,
     b"GG.RACE_TARGET_OK.bought_loyalty = function(_faction, c) return not c:is_faction_leader() end",
     b"GG.RACE_TARGET_OK.bought_loyalty = function(_faction, c) return true end"),
    ("Devotion for a Kislev faction without it", M,
     b"               and GG.has_resource(faction, \"wh3_main_ksl_devotion\") then",
     b"               then"),
    ("an earning filed outside Yours", U,
     b"rotation = true, earn = true},",
     b"rotation = true},"),
    ("a race card with no label", U,
     b"    if s.race then\r\n        body = \"[[col:yellow]]\"",
     b"    if false then\r\n        body = \"[[col:yellow]]\""),
```

`U` must be declared the way `A` is: `U = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua"`. If `mutate_guilds.py` already has a name for the UI file, use it. The `rotation = true, earn = true},` anchor is one line in the CRLF file and needs no `\r\n`.

- [ ] **Step 2: Run**

Run `py tools/mutate_guilds.py --selftest`, then `py tools/mutate_guilds.py > "$TEMP/mut2.txt" 2>&1; echo $?; grep -n "PROBLEM\|SURVIVED\|STALE" "$TEMP/mut2.txt"`.

Expected:
- `selftest ok: 116 mutants anchored` (78 + 38).
- Exit 0, and no survivor.

A survivor means a missing test. Write that test (RED first), not a weaker mutant.

After the run, re-run `py tools/gen_great_guilds.py --write`, because a mutation run leaves generated files mutated.

- [ ] **Step 3: Ledger**

`Task 12: complete (mutate 116/116 caught)`.

---

### Task 13: Build, deploy, record

- [ ] **Step 1: Static checks**

Run on the model, AI and UI files:
- `luac -p`;
- `py tools/check_lua_api.py` (0 findings);
- `py tools/check_lua_literal_left.py` (0);
- `py tools/check_lua_undeclared.py` on all four guild files together. Only the Exchange's pre-existing `EX_PRODUCTION` may remain.

`check_lua_api.py` flags any `cm:` member CA does not document. If one of the calls in this plan is flagged, run `--explain <member>` and ledger what CA says. Do not just silence it.

Byte-count line endings on the AI, UI and MCT files: every `\n` is still `\r\n`.

- [ ] **Step 2: Build**

RPFM must be open: `Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing`. Connection refused means stop and say so.

Run `py tools/import_great_guilds.py`.
Expected: `saved pack verified - every table holds this build's rows`.

Byte-compare the four packed scripts against disk with `read_pack_index.read(pack, "script/")`.

- [ ] **Step 3: Deploy**

If `Warhammer3.exe` is not running:
1. Back up `data/derpy_great_guilds.pack` to `.bak_stage2_races_20260929`.
2. Copy the build in.
3. Compare MD5s.

- [ ] **Step 4: Record**

- **The spec:** write the nine findings from this plan's table into §6, §6.1 and §7, and the chosen values into §6 and §6.2.
- **`docs/sessions/HANDOFF_20260929_GUILDS_STAGE2_RACES.md`:** what shipped, the build MD5, the backup and the rulings. It also carries the in-game checks nothing offline can prove:
  1. Labour Gangs puts labour into a province. This is contested by a stored note, and CA's own code says it works.
  2. Hell-Forge Allotment raises a cap with a commission rite in flight, the rite survives, and the next paid cap is not dearer. Roll the blunderbusses once and see the message.
  3. The Lady's Blessing and Tales of Valour, called from a mod.
  4. Call the Reckoning:
     - it is offered only at the top level;
     - it resolves at the next turn start and pays that level;
     - the card goes unavailable if the cycle resolves first.
  5. The Compass may be turned again at once (0 has only ever been inferred). Also check caravan cargo, Elector's Favour on the least loyal Elector, and the Supply Train dilemma's reinforcements arriving.
  6. High King's Decree persists across a turn (`reset_before_income` is set on the pool).
  7. The `_unseen` lines on the Warrant, Peasant Levies and Black Ark Tithe: the number is in the text.
  8. Bought Loyalty raises a lord's loyalty.
  9. Each earning writes its Log line: a caravan, a grudge, a reclaimed settlement, a Motherland ritual, Chivalry, Slaves, a court action.
  10. The Phoenix King's Favour at its cap.
- **`docs/SESSION_INDEX.md`:** one line.
- **`repos/derpy-great-guilds/CHANGELOG.md`:** an entry in player words.
- **`tools/sync_guilds_repo.py`:** add this plan (`docs/plans/`) and the handoff (`docs/history/`) to its manifest. Run `--check`, then the sync. Do not commit or push.
