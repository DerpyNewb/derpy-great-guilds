# The Great Guilds - lead flicker, the rivalry floor, and the save-load reset

2026-09-15 / 2026-09-16. Four bug reports from a live campaign, five faults found, four
fixed and one measured and found insufficient. Everything here is in
`derpy_great_guilds.pack`, deployed 2026-09-16. **Sections 1-8 are the first round,
section 9 the second, section 10 the third - and section 10 is the one to read if you only
read one: it is the fault that was reported FIRST and that I misread, and it had been
disabling three services since the mod shipped.**

## 0. Read this first

The third bug is the important one and it was found last. **`GG.state` - the reputation
and favour table the whole mod is about - was session memory with no restore path.** A
save loaded mid-turn left it empty for the rest of that turn, so the Standings tab showed
six empty tables and no guild had a leader.

That matters retroactively: **bug 2 below ("rival factions show zero in the Standings")
was investigated on the assumption that the zeros were earned, and they were not.** The
rivalry drain is real and measurable in the harness, but it is not what the player saw.
Do not re-derive the drain analysis as if it explained the report.

Files touched:

| File | What |
|---|---|
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` | `GG.hold_lead` (new), `GG.rival_cost` floor, `GG.load_all` (new), `GG.save` before `GG.payload` in `GG.buy` |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` | `GGUI.selected_force_cqi` - the wrong `campaign_ui_manager` member (section 10) |
| `tools/gen_great_guilds.py` | the Brass effect swapped off trade tariffs (section 9b) |
| `tools/check_lua_api.py` | new `CHAINED` rule for `cm:<accessor>():<member>` |
| `tools/_guilds_harness.lua` | 4 new blocks, 3 fixtures moved off a threshold, 1 assertion split, 1 faction-key collision fixed |

## 1. Bug 1 - a guild changed hands twice a round, forever

**Report:** "multiple instances where one of the guilds will be not indebted to you event,
then indebted to you event again."

**Log evidence** (`script_log_*.txt`, the lead-change feed messages): LOST at 351.3s, WON
at 400.6s, LOST at 573.9s, WON at 578.4s, LOST at 832.0s, WON at 836.4s, LOST at 1008.7s.
The pairs are 4.4-4.5 seconds apart - that is two faction turns, not two rounds.

**Root cause.** Every faction pays its guild upkeep at its *own* turn start, and
`GG.reassert_leaders()` runs at every faction's turn start *after* that. So for most of a
round the world is half-charged: whoever has already paid sits temporarily below whoever
has not. Any gap smaller than one upkeep tick therefore inverts twice every round - once
when the leader pays, once when the challenger does - with neither faction having earned
anything. Each inversion moves a permanent effect bundle, revokes a service monopoly and
fires a feed popup.

**Fix.** `GG.hold_lead`, called from `GG.leader_of`. The incumbent keeps the guild unless
the top row is ahead by more than one turn's upkeep. The margin is
`math.max(decay_amount(rank_of(top_rep)), decay_amount(rank_of(held_rep)))` - the upkeep
itself, not a new tunable, so it scales with rank and with `rate_decay` for free and needs
no MCT option, no loc and no DB row.

**It is in `GG.leader_of` and not in `GG.reassert_leaders`, and that is load-bearing.**
The sweep owns the bundle and the message, but `_ui.lua:887` (the "Led by" line),
`GGUI.leaders` (`_ui.lua:1214`), the monopoly label (`_ui.lua:551`), `GG.can_buy` and
`GG.snapshot_world` all call `GG.leader_of` directly. A rule applied only at the sweep
would put the bundle on one faction while five other readers named another.

Ties were already resolved by `GG.standings`' faction-key order, so a challenger that
merely draws level never takes it either.

## 2. Bug 2 - rivals at zero in the Standings

**Report:** "it seems that other factions reset to zero in the standings."

**What was found.** `GG.on_turn_start` grants brass reputation from
`net_income / rate_brass` every turn to every faction, and it is the *only* passive income
source in the mod. `GG.rival_cost` then takes 40% of that back out of brass's rival, the
khanate. The same holds for slavers, the rival of overseers, which buildings feed.

Measured against the shipped Lua with an active rival, turn 60, all six guilds starting at
120:

| | khanate | slavers |
|---|---|---|
| upkeep 100 + rivalry 40 (shipping) | 8 | 0 |
| upkeep off, rivalry 40 | 108 | 100 |
| upkeep 100, rivalry off | 106 | 74 |
| both off | 176 | 120 |

**Neither lever alone zeroes anything. They ratchet together:** upkeep demotes a guild
through a rank threshold, the lower rank has a lower floor, rivalry drains into the new
room, repeat.

**Fix, as chosen by the author** ("floor the drain at the rank held"): `GG.rival_cost` may
push a guild down *within* its rank but never below the threshold it has already reached.

```lua
local floor_at = GG.RANKS[GG.rank_of(t.rep)] or 0
if t.rep <= floor_at then return 0 end
if loss > t.rep - floor_at then loss = t.rep - floor_at end
```

**It did not remove the zeros, and that was measured rather than assumed.** It holds for
about ten turns (khanate at 102 on turn 30), then upkeep demotes through the threshold and
re-opens the floor underneath. It is strictly better than what shipped and it is deployed,
but it is not a solution to the report.

**And the report itself has a simpler explanation - see section 3.** The drain is real in
the harness; what the player was looking at was almost certainly an empty `GG.state`.

Two options were put to the author and neither was taken up: floor the drain at the
*highest rank ever reached* (needs a third field in the save string, which packs only
`rep,fav` per guild today), or give the five non-brass guilds an AI-reachable income.
Underneath both: all six guilds pay upkeep every turn and only brass has a reliable
per-turn income, so the khanate nets about -0.4 a turn from upkeep alone for an AI even
with rivalry switched off.

## 3. Bug 3 - the rankings reset after loading a save, and no guild has a leader

**Report (2026-09-16):** "cannot assign leader of guild, the rankings are also restarting
after load of save."

**Root cause.** `GG.state` is session memory. It was refilled lazily and only lazily:

- `GG.load(faction)` at that faction's **own** `FactionTurnStart`
- `GGAI.run_turn` loads every non-human faction, **once a round**, at the first faction
  turn start of the round

Neither has happened when a save is loaded mid-turn - which is every save a player makes.
So `GG.state` is `{}` for the rest of that turn. `GG.standings` reads `GG.state`, so every
guild's table is empty and `GG.leader_of` returns nil for all six.

It is worse than a blank panel. `GG.reassert_leaders` runs at the next faction turn start
against whatever fraction of the world has reloaded by then, so the crown lands on the
first faction to take its turn and walks down the table as the round refills it - moving a
permanent bundle and a service monopoly at each step.

**The tell that this was the gap and not a theory:** every *other* record already had a
restore path outside the turn handler. Bounties, the demand, the patron, the research
subject and the world record are all re-read when the panel opens
(`zzz_derpy_guilds_ui.lua` lines 666, 828, 829, 919). The standings were the only record
with none.

**Fix.** `GG.load_all()`, called from the existing first-tick callback:

```lua
cm:add_first_tick_callback(function() GG.load_all(); GG.register() end)

function GG.load_all()
    for _, list in pairs(GG.scan_world()) do
        for i = 1, #list do GG.load(list[i]) end
    end
end
```

`cm:add_first_tick_callback` is documented as firing "regardless of what mode the campaign
is being loaded in", so it runs on a save load as well as a new campaign - checked with
`py tools/check_lua_api.py --explain add_first_tick_callback`, not assumed.

**At the tick, not inside `GG.standings`.** Standings is a draw-time read that runs once
per guild per panel refresh; a `get_saved_value` per faction per row is the same work
several hundred times over on every panel open. `GG.scan_world` is the walk the mod
already does and caches, so this costs one saved-value read per present faction, once a
session.

`GG.leaders_now` is deliberately **not** restored. It is session state on purpose, and
`reassert_leaders` skips its announcement when the slot is nil ("we have not looked yet
this session") rather than false ("nobody held it"), so the first sweep after a load
re-asserts all six guilds silently.

## 4. Do not re-derive

- **A save game is compressed. Byte-grep is not an instrument against it.** A grep for
  `derpy_gg_` in the save returned 0 hits. That was *not* treated as evidence, because a
  control probe for `derpy_coalitions_rung` - a value we had watched load out of that same
  save - also returned 0. Run the control before believing a zero.
- **Lua 5.1 allows 200 local variables per function and the harness main chunk is within a
  handful of the ceiling.** The error is "main function has more than 200 local variables"
  and it names a line hundreds away from the one that broke it. New harness tests go in a
  `do ... end` block; locals inside one are freed at its end. Two globals in the harness
  (`TUNE_BEFORE_LEAD`, `TURN_ORDER`) exist only because of this.
- **`read_pack_index.read(pack, fragment)` returns a list of `(path, compression, data)`
  tuples**, not bytes. Two different type errors came out of guessing otherwise.
- **`tools/import_great_guilds.py` writes to `Modding Files/Modpacks/`, not to the game.**
  Deploy is a manual copy to
  `F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\`. `used_mods.txt` lives
  in the **game root**, not in `data/`.
- **`GG.rival_cost`'s floor is not in `GG.penalise`.** Penalise is the shared debit used by
  expired demands and failed bounties, where falling through a threshold is the point. The
  floor belongs to the one caller that drains on someone else's behalf.
- **The MCP `mcp__rpfm__*` tools do not appear if RPFM was shut at session start** - the
  client binds once. The server itself does come up; check with
  `Invoke-WebRequest http://127.0.0.1:45127/sessions` and use the raw-HTTP fallback, or
  just run the packer, which talks to it through `rpfm_client`.

## 5. Harness corrections found the hard way

Three existing assertions broke when the `rival_cost` floor went in. **Two were stale
fixtures and one was a real design assertion, and telling them apart was the work.**

- Two fixtures sat exactly on the rank-2 threshold (100), where the new floor leaves no
  room at all, so the assertion could no longer fail whatever the code did. Moved to 150,
  and a dedicated threshold assertion added. The `rate_rivalry = 0` fixture was moved off
  the threshold in the same pass, before it became unbreakable for the same reason.
- "A RANK CAN FALL THROUGH THIS" was **not** stale. It is the coverage that a demotion
  removes the rank bundle. Split into a `do ... end` block: rivalry now stops at 300 and
  keeps rank 3, then `GG.decay(RV, 30)` demotes and `derpy_gg_rank_overseers_3` must appear
  in `removed`. The coverage is preserved, not deleted.

New in this pass, and the mechanism is worth keeping: **the harness now captures first-tick
callbacks instead of discarding them.** `cm.add_first_tick_callback` was `function() end`,
so anything the mod does to recover session state was unreachable from any test. It now
appends to `FIRST_TICKS`, and `MODEL_TICKS` marks where the model file's callbacks end -
the UI file registers its own further down and it *draws*, so a model test must not run it.
The save-load test drives the recovery **through the first tick** rather than by calling
`GG.load_all` directly, because a recovery function wired to nothing is the bug, unchanged.

## 6. Verification state

Run from the workspace root on 2026-09-16:

```
luac.exe -p zzz_derpy_guilds.lua                 exit 0
tools/_guilds_harness.lua                        harness ok
py tools/check_lua_api.py <file>                 1 file(s), 0 suspect call(s)
py tools/check_lua_undeclared.py <file>          1 file(s), 0 with undeclared names
py tools/import_great_guilds.py --check          verify ok - 43 bundles, 47 junctions,
                                                 405 loc, 3 scripts, 6 ui files
py tools/import_great_guilds.py                  saved, and the re-open verify passed
```

The save-load test was **watched to fail first**: "got 0 rows" against the unfixed Lua.

Deployed pack read back off disk with `read_pack_index.py`, a reader that never spoke to
RPFM: `script/campaign/mod/zzz_derpy_guilds.lua`, compression 0, 162,633 bytes, carrying
`function GG.load_all`, `GG.load_all(); GG.register()`, `function GG.hold_lead` and the
`GG.rival_cost` floor. `used_mods.txt` line 42 lists the pack.

**Not one turn has been played with the save-load fix in.** The lead-flicker fix shipped
2026-09-15 and the player has campaign time on it; bugs 2 and 3 have none.

## 7. Open

- **The upkeep/rivalry ratchet is unresolved.** The rank floor is a ten-turn reprieve. The
  two candidate fixes are in section 2 and neither has been chosen.
- **Debug prints are still in shipped Lua** and should come out before either mod goes to
  the Workshop: `GREAT GUILDS: opener button at ...` in this mod, `XXX derpy_ic ...` in the
  Iron Court.
- **`GG.load_all` walks `GG.scan_world()`, which lists only *present* factions** (one with
  a home region or a military force). A faction holding saved standing that has lost
  everything is not reloaded at the tick. `GG.standings` filters on presence anyway, and
  the faction still loads at its own turn start, so this is a deliberate limit rather than
  an oversight - but it means `reassert_leaders`' bundle sweep cannot reach such a faction
  until then.

## 8. Things worth carrying to other work

- **"The fix went green" is not "the symptom went away."** The rank floor passed every
  check and did not solve the report. Re-measure the symptom after the harness turns green,
  not instead of it.
- **A per-faction lazy cache needs a restore path that does not depend on the faction's own
  turn.** This mod had five records with one and one without, and the one without was the
  record the mod exists for. When adding session state, ask what reads it before the first
  `FactionTurnStart` of the session.
- **When a rule has several readers, put it where they all route through.** `GG.hold_lead`
  in `leader_of` rather than in the sweep is the same shape as every other fix in this
  workspace that stuck.
- **An assertion that can no longer fail is worse than a missing one.** Two of the three
  broken assertions here had quietly become unbreakable because their fixtures sat exactly
  on a boundary the new rule clamps to. When a fix makes a test pass by construction, move
  the fixture; when it makes a test fail, find out whether the test was describing the
  design or the accident.

## 9. Continued 2026-09-16 - two more service effects, both shipped

**Report:** "some effects also didn't work, like the instant research being reverted, or
the trade per turn. The 2500 gold levy works though."

Three services named, two faults, and they are unrelated to each other.

### 9a. Bound Blueprint and Raise a Ziggurat refunded themselves

**Root cause.** Two of the eighteen payloads raise an event this mod listens for:

| Service | Call | Event it raises | Listener |
|---|---|---|---|
| `bound_blueprint` | `cm:instantly_research_technology` | `ResearchCompleted` | `gg_tech` |
| `raise_ziggurat` | `cm:region_slot_instantly_upgrade_building` | `BuildingCompleted` | `gg_building` |

Every listener in the file opens with `GG.load(name)`, which overwrites **`GG.state` and
`GG.cooldowns`** from the saved value. `GG.buy` never saved - the save lived in the
*caller*, the panel's click handler (`_ui.lua:1724`) and GGAI's two. So the purchase
existed only in memory for exactly as long as the payload ran, and if the engine raises
the event inside the call, the favour just spent comes straight back and the cooldown
never starts.

That is "the instant research being reverted": the technology does complete. It is the
payment that is rolled back, and the panel's favour number goes down and back up.

`caravan_levy` works because `cm:treasury_mod` raises no event this mod listens for.

**Fix:** `GG.save(faction)` inside `GG.buy`, immediately before `GG.payload`. One line,
both callers, both re-entrant payloads, and correct whether the engine raises those events
synchronously or not - which is the part no offline check can settle, and which the
shipped code was silently assuming.

**The harness could not see this**, because `cm.instantly_research_technology` was a
recording stub that raised nothing. The new test re-points it to call `handlers["gg_tech"]`
inside the call, which is the engine behaviour being defended against. Mutation-proven: the
assertion fails with the save line removed, and the shipped Lua was restored byte for byte
afterwards.

**A harness fixture collision fell out of it.** `cr_build` was used by two unrelated blocks
- an early `raise_ziggurat` guard test and the `BuildingCompleted` handler block 3,900
lines later - and the second only worked because `GG.buy` never wrote a saved value.
Once it did, the later block's `GG.load` restored the earlier block's standing and four
guilds moved with nothing granting them. The early block now uses `cr_build_half`. **A
saved value outlives its block; a faction key is a shared resource in this harness.**

### 9b. The Brass Tablets paid nothing at all

**Root cause, and it is not a code fault.** `RANK_EFFECTS["brass"]` was
`wh_main_effect_economy_trade_tariff_mod` at `faction_to_faction_own`. The DB row is
correct, the scope has 17 vanilla precedents, the loc is complete and the bundle applies -
but the effect is a **percentage of trade tariff income**, and a Chaos Dwarf faction with
no trade agreements has none. Seven bundles paid exactly zero: the four rank bundles, the
leadership bundle, Writ of Monopoly and the Long Ledger.

It is the guild the player feeds most, because `GG.on_turn_start`'s brass grant is the
mod's only passive income source.

**Fix, as chosen by the author:** `wh_main_effect_economy_gdp_mod_all` at
`faction_to_region_own` - income from every building the faction owns, a base every
faction has. 29 vanilla rows on that exact pair, values -20 to +50, so the 3/6/10/15
ladder, the leadership bundle's 10 and the service's 32 all sit inside vanilla's own range
and `check()`'s magnitude guard passes untouched. `EFFECT_BLURB`, `EFFECT_REACH_THEIRS` and
the sign comment moved with it, and all the loc regenerated from the one table.

**The EARN route was not touched.** Reputation still accrues from net income, which is what
`GUILD_DESC` and `EARN_SHORT` describe - those strings were already about earning, not
about what the ladder pays.

**The Slavers have the same shape and were deliberately left alone.**
`wh_main_effect_force_all_campaign_sacking_income` pays only in the turns you sack or raze.
The author's call: that is the point of a slaver guild, and the player chooses when to
trigger it.

### 9c. Verification and deployment for section 9

```
tools/_guilds_harness.lua                   harness ok  (new test mutation-proven)
luac.exe -p zzz_derpy_guilds.lua            exit 0
py tools/check_lua_api.py <file>            1 file(s), 0 suspect call(s)
py tools/check_lua_undeclared.py <file>     1 file(s), 0 with undeclared names
py tools/gen_great_guilds.py --check        exit 0
py tools/gen_great_guilds.py --selftest     selftest ok: 6 guilds, 18 services,
                                            43 bundles, 405 loc
py tools/preview_guilds_panel.py --check    6 file(s) checked
py tools/import_great_guilds.py             saved, re-open verify passed
```

Deployed 2026-09-16, read back off disk with `read_pack_index.py`: the model Lua is 163,781
bytes at compression 0 carrying `GG.load_all`, the `GG.save` before `GG.payload`,
`GG.hold_lead` and the `rival_cost` floor; the junction table carries **7**
`wh_main_effect_economy_gdp_mod_all` rows (`derpy_gg_rank_brass_2..5`,
`derpy_gg_lead_brass`, `derpy_gg_svc_writ_monopoly`, `derpy_gg_svc_long_ledger`) and **0**
`wh_main_effect_economy_trade_tariff_mod` rows.

### 9d. Carry this

**An effect can be correctly wired, correctly scoped, correctly localised and still pay
nothing, because its BASE is zero.** No DB check catches it and no Lua check can see it -
`check()` validates the key, the scope and the magnitude, all of which were right.
When picking an effect for a reward, ask what revenue stream it multiplies and whether the
player has one. Two of this mod's six guilds were multiplying a stream most factions never
have; one of them was the guild with the only passive income in the mod.

**A payload that calls the engine can re-enter your own listeners.** If a handler reloads
state from the save, anything the caller has not saved yet is lost. The rule that falls out
of it: write the transaction down before you fire the side effect, not after.

## 10. The one that was actually reported first - appointing a patron

**Report:** "cannot assign leader of guild" (2026-09-16), clarified later the same day as
"assigning lord as guild leader".

**I read that as the guild crown and it was not.** Section 3's `GG.load_all` is a real fix
for the other half of that message ("the rankings are restarting after load of save"), but
"assigning a lord" is the **patron** - the Court tab's second card - and that is a
different mechanism entirely. Do not let section 3 stand as the answer to this report.

**Root cause.** `GGUI.selected_force_cqi` called
`cm:get_campaign_ui_manager():get_char_selected()`. **campaign_ui_manager has no such
member.** CA's `lib_campaign_ui.lua` declares exactly one `get_char` member and it is
`get_char_selected_cqi()` - verified by listing every `^function campaign_ui_manager:get_`
in CA's own lib, and by `--explain`, which answers `NOT DOCUMENTED` for the name that
shipped and returns a full entry for the real one.

The call sits inside a `pcall`, so the missing method became a permanent `nil`. **Three
things were dead from the day they shipped:**

| What | How it reads the selection |
|---|---|
| Appoint Patron | the button's enabled flag is `sel ~= nil` (`_ui.lua:876`), so it was greyed forever |
| Hire the Immortals | `GGUI.pick_target` for `kind == "unit"` |
| The Khan's Price | `GGUI.selected_enemy_faction`, which calls this first |

Hobgoblin Eyes was fine: it uses `get_selected_settlement_region()`, which does exist.

**Fix.** The right member, plus two guards that are not cosmetic:

```lua
local uim = cm:get_campaign_ui_manager()
if not uim then return nil end
local c = uim:get_char_selected_cqi()
if type(c) ~= "number" or c <= 0 then return nil end
return c
```

- **CA's field starts `nil` and `CharacterDeselected` sets it to `-1`**, not back to nil
  (`lib_campaign_ui.lua:460`). A bare nil test hands the payload character `-1`, an
  unvalidated key that fails forever in silence.
- **`cm:get_campaign_ui_manager()` can return `false`**: `campaign_ui_manager:new()`
  refuses to build one once the UI is up and `script_error`s instead. CA creates it during
  startup so this should not happen; the guard is cheaper than finding out that it did.

**Why no check caught it, and what now does.** `check_lua_api.py` resolves `cm:` / `core:`
/ `bm:` / `common.` receivers only - the receiver here is a *call expression*, which is the
"cannot resolve non-singleton receivers" limit the tool has always documented. It now
carries a `CHAINED` table mapping `cm:<accessor>()` to the doc receiver named on that
accessor's own "Returns:" line, with `get_campaign_ui_manager -> campaign_ui_manager` as
its first entry. `--selftest` watches both halves: the real member must pass and the
shipped typo must fail. Re-running the full scan over all 103 pack Lua files added **no
new findings**, so the rule is not noisy.

**Why the harness could not catch it either, and what now does.** There was no
`cm.get_campaign_ui_manager` stub at all - the pcall ate the error and the function
answered nil, so every test written against it passed with the call spelled any way at
all. The new block stubs **CA's object member for member**, with `get_char_selected_cqi`
and nothing that CA does not declare. A stub that answers whatever it is asked cannot tell
a real member from an invented one.

**Two pre-existing findings surfaced by the same scan and NOT fixed** - they belong to the
lords pack, not this mod:

- `cm:force_non_aggression_pact()` at lines 245 and 247 of all four Ghorth start scripts
  (`ime_derpy_ghorth.lua`, `cr_darklands`, `cr_oldworld`, `wh3_main_combi`). **Zero hits
  across all 5,778 of CA's shipped Lua files and zero in CA's docs.** The nearest real
  names are `force_break_non_aggression_pact` (the opposite action) and the faction-side
  reads `non_aggression_pact_with` / `non_aggression_pacts`.
- `cm:ritual_is_locked()` in `ai_test_tower_of_zharr.lua`, same zero-hit result.

**Deployed 2026-09-16.** `zzz_derpy_guilds_ui.lua` in the pack is 97,035 bytes at
compression 0, `get_char_selected_cqi()` present and `get_char_selected()` absent.

### 10a. Carry this

**A `pcall` around an engine call turns a wrong member name into a permanent, silent
default.** That is three separate bugs in this workspace now - `is_dead` on a character,
`is_unique` on a character, and this. The member list is in CA's shipped Lua
(`Modding Files/reference/ca_scripts_wh3/_lib/`), one grep away, and
`check_lua_api.py --explain <member>` answers `NOT DOCUMENTED` for an invented name.
**Check the member exists before wrapping the call in a pcall, because afterwards nothing
will ever tell you.**

**A stub that answers anything tests nothing.** The harness's missing
`get_campaign_ui_manager` was not a gap in coverage, it was a fixture that made the fault
unreachable. When stubbing an engine object, give it exactly the members the engine
declares.
