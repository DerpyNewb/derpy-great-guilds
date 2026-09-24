# The Great Guilds - a log check, a gap audit, the dead building earn, and the Log tab

2026-09-23. Started as "check great guild mod logs", became "what else is missing", then
"do the bug fixes first, then do the log tab". This file is written BEFORE the fixes, at the
point the audit finished; section 6 is updated as the build lands.

## 0. Read this first

- **Buildings have never paid any guild, for any faction, since the mod shipped.** The
  `BuildingCompleted` listener reads `context:faction()`, which that event does not have.
- **AI factions never earn the Daemonsmiths either** - measured, cause not proven.
- **The Khanate is pinned at 0 by rivalry for the player too**, not only the AI, from turn 1.
- None of the three is visible to any offline check, and every offline check is green.

## 1. The log check (today's three script logs)

`script_log_230926_0732` (campaign, Azeros turns 23-24), `_0744` (a battle - no guild lines,
correct), `_0755` (campaign reload on turn 24). All three guild scripts load; no script error
names a guild file. Opener placed at x 1408-1428 on 1920x1080; the panel opened, paged
Bounty/Stand/Guilds, closed. Bounty board posted 3 offers on turns 23 and 24; one Overseers
bounty was withdrawn because its target region stopped being a target (intended).

**The one purchase is invisible in the log by design** - `GG.buy` traces nothing on success.
It was proven off the save string instead: `derpy_gg_<faction>` is
`rep,fav|... x6 ; cooldown x18`, and after the click Caravan Levy's cooldown read 7 and Brass
favour fell 178 -> 147 (-50 price, +19 income). The purchase was made during the AI turn
phase (End Turn at 373s, click at 530s, own turn at 629s) - the opener is parented to root
and stays live then. It worked; whether buying during the AI phase is wanted is undecided.

The minor faction's +120 Slavers in one turn (cap 80) is `demand_reward`, paid through
`GG.grant` directly and uncapped on purpose (`zzz_derpy_guilds.lua:1448`).

## 2. What the audit found

### 2a. The building earn is dead (BUG)

`gg_building` (`zzz_derpy_guilds.lua:2842`) opens with `faction_name_of(context)`, which does
`pcall(context:faction())`. CA's `scripting_doc.html` gives `BuildingCompleted` exactly two
accessors, `building` and `garrison_residence`. Every one of CA's shipped handlers reads
`context:building():faction()`; the three `context:faction()` hits inside 15 lines of a
`"BuildingCompleted"` string all belong to the NEXT listener. The pcall turns the missing
member into nil and the handler returns - for every building, every faction, every turn.

Measured: the Conclave campaign's last save (`script_log_180926_2208`, turn 83) has
Overseers `0,0` for all 9 AI factions; the player's 208 is missions. The Azeros turn 23->24
delta reconciles exactly with NO building income: +10 per guild from one mission less 4
from each rival's +10, +60 Daemonsmiths from one tech, +9 Brass from income.

**Why nothing caught it:** the harness's `build_ctx` (`tools/_guilds_harness.lua:4565`)
hands the handler a `faction` member the engine does not have. Same shape as the 09-16
patron bug (section 10a of that handoff): a stub that answers anything tests nothing.

### 2b. AI factions never earn the Daemonsmiths (MEASURED, cause unproven)

Every AI Chaos Dwarf faction reads Daemonsmiths `0,0` at turn 24 (Azeros, 17 factions) and
turn 83 (Conclave, 9). `GG.penalise` touches `rep` only, so `fav == 0` means nothing was
ever granted. The `ResearchCompleted` handler uses `context:faction()`, which CA DOES
document for that event, so the handler is not wrong the way 2a is. Most likely the engine
raises `ResearchCompleted` for human factions only - CA's own uses (`wh2_campaign_rites.lua`)
register for humans only, so they cannot settle it. The MCT debug option `log_accrual`
(`GG.logging`) has never been on in any of 415 logs since 09-10; one turn with it on answers
it.

### 2c. Rivalry pins the Khanate at 0 (DESIGN, open since 09-16)

The rivalry floor is the threshold of the rank held, and rank 1's threshold is 0. Brass
earns from income every turn and drains 40% of it from the Khanate, so a Khanate below
rank 2 never leaves 0. The Conclave player at turn 83: Khanate `0,200` - 200 favour banked
and unspendable, because every Khanate service needs rank 2. The 09-16 handoff measured the
ratchet with every guild starting at 120, which hides this case; it bites from turn 1,
before upkeep starts at turn 25.

Consequence of 2a+2b: the player leads the Daemonsmiths and the Overseers uncontested all
game, taking both leadership bundles and both top-service monopolies for nothing.

### 2d. Designed and never built

- **Dwarf and Empire flavour** (spec section 3.2 / phases 2-3) and the generic fallback.
  Only `GG.HIRE_UNIT_BY_CULTURE` has Dwarf/Empire rows. Loc keys are one set
  (`derpy_gg_guild_name_<g>`), so an Empire player (one was run to turn 4) sees Chaos
  Dwarf names. `GG.FLAVOURED`'s comment claims otherwise.
- **The Log tab** (spec section 7). Tabs are Guilds/Standings/Bounties/Court/Help. AI
  purchases appear nowhere; `zzz_derpy_guilds_ai.lua:220` still calls them "Log content".
- AI use of Hobgoblin Eyes / Bound Blueprint / Raise the Ziggurat - cut on purpose, still cut.

### 2e. Release housekeeping

- Not on the Workshop; no `MY_MODS.md` entry. The pack lives only in `data/`.
- `GREAT GUILDS: opener button at ...` debug print still ships.
- Staged `zzz_derpy_guilds_ui.lua` was 190 bytes ahead of the deployed pack at the start
  (an unused local removed, a comment added) - no behaviour change.
- Never seen live: the Khan's Price hit message (`derpy_gg_hit`, 0 of 415 logs); multiplayer.

## 3. Verified green at the start (and blind to all of section 2)

`luac -p` x3, `_guilds_harness.lua`, `check_lua_api.py` (0), `check_lua_undeclared.py`
(one false positive: `EX.BUTTON`, `EX.BUTTON_SIZE`, `EX.BUTTON_GAP` are declared by the
Exchange at `zzz_derpy_chd_exchange.lua:2041-2062`), `gen_great_guilds.py --check` and
`--selftest`, `preview_guilds_panel.py --check`, `check_guilds_ui.py`,
`check_guilds_anchor.py`, `check_effect_bundle_loc.py` (43 bundles, 405 loc, 0).

## 4. Do not re-derive

- The save string: `derpy_gg_<faction>` = six `rep,fav` pairs in `GG.GUILDS` order (brass,
  immortals, daemonsmiths, khanate, overseers, slavers), `;`, then 18 cooldowns in
  `GG.SERVICES` order. The log's `[savegame] Saving value saved_values` line carries every
  one, `;;;`-separated - a regex that stops at `;` drops the cooldowns.
- `derpy_gg_world` = `turn|?|?|?;culture/guild,rep,margin,leader,flag|...`.
- Rival pairs: brass<->khanate, immortals<->daemonsmiths, overseers<->slavers.
- `demand_reward` (120) and bounty payouts bypass the per-turn cap on purpose.
- `read_pack_index.read(pack, substring)` pulls a file's bytes out of the deployed pack
  with RPFM shut; guild pack files are all compression 0.

## 5. Open

- ~~2a, 2b, 2c~~ - fixed in 6a (2b's cause was proven from the save before fixing).
- ~~The Log tab~~ - built in 6b.
- The **live checks** in 6c (deployed; not yet played).
- 2d: Dwarf/Empire flavour names and the generic fallback.
- 2e: Workshop publish, `MY_MODS.md` entry, the `GREAT GUILDS: opener button` debug print.
- `GGUI.place_opener` resolves loc (`set_tooltip` -> `GGUI.loc`) from the
  `gg_opener_place` FactionTurnStart listener - a breach of the file's own no-loc-in-turn-
  handlers rule, found by the exploration pass. It has not crashed; it should not be
  copied.

## 6. Build log (this session)

### 6a. The three fixes - built, packed to Modpacks, NOT yet in data/ (game was running)

Each new assertion was watched to fail against the old code before the fix went in.

1. **Buildings pay.** `faction_name_of(context, get)` takes an optional getter;
   `gg_building` reads `context:building():faction()`, then
   `context:garrison_residence():faction()` (CA reads that 41 times), else pays nobody.
   Harness `build_ctx` now carries only `building` and `garrison_residence`; new cases for
   `faction()` throwing and for both routes failing. Every other guild listener was
   audited against scripting_doc's accessor lists - only this one was wrong.
2. **The AI earns the Daemonsmiths.** Proven first: `gg_tech` writes
   `derpy_gg_research_<faction>` unconditionally, and in both campaigns only the human had
   one - so `ResearchCompleted` never reaches an AI faction. `GG.on_tech_count(faction, n)`
   reads `faction:num_completed_technologies()` (CA: "How many technologies has this
   faction completed researching?") at a NON-human's turn start, stores it in
   `derpy_gg_techs_<faction>`, and pays `on_tech` once per new technology. **The first count
   is a baseline, not income** - otherwise the first turn after the update pays every AI
   for every technology it owns. `gg_tech` now returns early for non-humans, so a mod
   raising the event for an AI cannot pay twice. The Bound Blueprint re-entry test's fixture
   became a human (it is a human-only service) and moved into a function scope - the
   harness main chunk is at Lua 5.1's 200-local ceiling.
3. **Rivalry takes nothing below Indebted** (author's choice, 2026-09-23, from three
   options). `if GG.rank_of(t.rep) < 2 then return 0 end` ahead of the existing floor.
   Soak over 83 turns of an active AI (scratch script on the harness's own stubs): khanate
   0 -> 69, slavers 13 -> 102, the other four within 20. "Income exempt" fixed the khanate
   only - Overseers buildings still drained slavers once buildings paid. The old
   "stops at zero" test became "an Unmarked rival loses nothing". Help page 2's rivalry
   bullet now says so; page 2 had no spare line (`gen_great_guilds --check` refused a
   21st), so it was folded into the existing bullet and "You cannot court all six" went.

Gates: harness ok, luac, check_lua_api 0, check_lua_undeclared 0, gen --check/--selftest,
gen_guilds_ui --check, import --check, `import_great_guilds.py` saved + its own content
verify. `read_pack_index` on the saved pack: all three scripts byte-identical to staged,
each fix's line present, the help sentence present in the UTF-16 loc. Rollback copy:
`Modding Files/Modpacks/derpy_great_guilds.pack.bak_20260923_pre_fixes` (the 09-16 build).

### 6b. The Log tab - built, packed to Modpacks with 6a, NOT yet in data/

The panel had a Log tab before; `gen_great_guilds.py` said it was replaced by Bounties
because it "was a tab the panel switched to and then drew nothing into". Nothing ever
wrote a record. This build is the record plus the tab.

- **Record** (`zzz_derpy_guilds.lua`, beside `GG.announce_lead`): `GG.log_add(faction,
  kind, guild, a, b)` / `GG.log_entries(faction)`, saved value `derpy_gg_log_<faction>`,
  `turn,kind,guild,a,b` joined by `|`, newest first, `GG.LOG_MAX = 100`, humans only,
  read straight from the save on every draw (no session cache to lose on load). Keys and
  numbers only - every writer runs from a turn handler.
- **Writers:** `GG.grant` and `GG.penalise` (kind `rank`, both directions - a FALL had no
  record anywhere before, `announce_rank` is promotions only); `GG.buy` (`buy`, key and
  price - the AI calls the same function and `log_add` ignores it); `GGAI.log_purchase`
  called from `GGAI.step` (`ai_buy` to each human of the buyer's culture, or `hit` to a
  human a hostile service landed on - one line, not both); `GG.announce_lead` (`lead_won`
  / `lead_lost`, written before the feed call so `guild_notices` off still logs).
- **Tab:** `gen_guilds_ui.TABS` is now the one tab list (layout, button styling and both
  tab checks read it; the text-block check had lost `gg_tab_court`). Six at 125px fill
  x=20..770. `GGUI.TAB` 6 = Log, placed fifth on screen, so no tab renumbered. The body
  reuses the Help tab's 21 `gg_help_NN` slots and the shared pager (`GGUI.LOG_PAGE`);
  colour tags go on AFTER `GGUI.wrap`, per line, so no `[[col:]]` spans a wrap. An empty
  log draws `log_empty` rather than a blank tab. 13 loc keys (405 -> 418).
- **Not logged, deliberately:** demands and bounties (their own tabs and feed messages
  already carry them), AI-vs-AI lead changes (the Standings tab's job).

Tests (harness, each watched to fail first): promotion, demotion, AI ranks never logged,
player purchase with price, AI purchase reaching the human with the buyer's key, a hostile
hit as ONE entry, lead won/lost naming the other party, the cap dropping the oldest,
`GGUI.log_lines` carrying the turn, the empty log drawing one line. Plus every gate in 6a,
`gen_guilds_ui --write/--selftest` (227 GUIDs), `check_guilds_ui` + selftest, TWUI
Studio's reader over all six files, and a preview render showing six tabs, even margins.

**Saved pack:** `Modding Files/Modpacks/derpy_great_guilds.pack`, 4,182,030 bytes. Scripts
and panel xml byte-identical to staged.

**DEPLOYED 2026-09-23 10:33** with the game confirmed closed: copied to
`data/derpy_great_guilds.pack`, MD5 `340DBF5227CCB1496BE481FDD3D47DD3` on both sides,
`used_mods.txt` line 119 still enables it. (It was held back earlier because the game was
running - overwriting a pack it holds open is how you get a crash nobody can trace.)

### 6d. First live round (`script_log_230926_1106`, turns 30-32) - and one fix to the fix

Clean load, no guild error, the usual unrelated VCO error only. Read off the two autosaves:

- **Buildings pay - CONFIRMED.** At the turn-30 save no AI faction had any Daemonsmiths or
  Overseers reputation; after one round on the new code six did (Overseers 10-40,
  Daemonsmiths 10-40), all multiples of 10 = `rate_overseers` x building level.
- **Log tab - CONFIRMED writing and opened twice.** Player log at the turn-31 save:
  `31,buy,brass,caravan_levy,45` / `30,rank,daemonsmiths,3,4` /
  `30,ai_buy,brass,caravan_levy,wh3_dlc23_chd_conclave`. The rank-up's feed popup appeared on
  turn 31 but the entry says 30: `ResearchCompleted` fires before the round's turn number
  advances. Cosmetic, left.
- **AI Daemonsmiths - baselines written** (7-25 technologies per Chaos Dwarf AI); the first
  grant lands on the round after, so it is still owed at the time of writing.
- **FOUND: 277 `derpy_gg_techs_` keys in the save**, one per AI faction in the world. `gg_turn`
  fires for everyone and the count was gated on `not human` only. Now `not human and
  GG.covered(name)`; harness test watched to fail first. The 277 already written stay in that
  save as inert numbers - nothing reads a key for an uncovered faction.
- **Harness bug fixed on the way:** the no-target block (~line 3263) ended with
  `GG.humans, cm.get_human_factions = prev_humans, prev_getter`, two undeclared globals, so
  every test after it ran with NO human player. Removed; every later test still passed with
  the player restored.

Packed to `Modpacks/`, MD5 `99A25F5C5D60CEC9533FBC5B91323597`. **Not in data/ - the game was
running.** `data/` still holds `340DBF52...` (6b), which is correct apart from the key bloat.

### 6e. Second live round (`script_log_230926_1342`, turns 32-33) - and the rank flip

Clean load on 99A25F5C, no script error (the 30 "error" hits are CA's Great Game VFX lines).

- **AI Daemonsmiths from technologies - CONFIRMED.** Turn 32 -> 33 saves: Baal 20 -> 21
  techs and 60 -> 119 rep, Astragoth 23 -> 24 and 0 -> 60, Khorakk, Snakebeards, Uzkulak
  and Azgorh the same. The tech-key count stayed 273 across both saves (the 259 non-CHD
  keys are the inert leftovers from 6d; none new).
- Lead lost (Overseers, to the Conclave 108 v 95) and won (Slavers) both announced. The Log
  holds 25 entries; it was opened once, at about 12, so paging past 21 is still unseen.
- The Chaos Dwarf invasion faction `wh3_dlc25_chd_chaos_dwarfs_invasion` earns and buys
  (Forge-Rite). Chaos Dwarf culture, so covered by design.
- **FOUND: the player's Slavers rank flipped and re-announced.** Log: `31,rank,slavers,1,2`
  / `32,rank,slavers,2,1` / `32,rank,slavers,1,2`, and "Name You Indebted" popped in both
  sessions. `GG.rival_cost` floored at EXACTLY the held threshold, so Overseers income
  pinned the slavers at 100, the next turn start's upkeep charged 2 (rank 2), the save read
  98 - demoted - and the next sack promoted again. Rivalry cost a rank one turn late,
  contradicting the Help's "never a rank you hold".

**Fixed (author's choice, "both"):**
1. `GG.rival_cost` floors at `threshold + GG.decay_amount(rank)` - one turn's upkeep above
   the threshold. Upkeep still demotes an unfed guild; it now takes one turn longer after a
   rivalry pin. Two harness tests changed on purpose (they pinned the old exact-threshold
   floor) - the new one reproduces the live 100 -> 98 sequence and was watched to fail.
2. `GG.announce_rank` pops a promotion only when the rank beats the best that human has
   reached with that guild: `derpy_gg_best_<guild>_<faction>`, humans only. The bundle swap
   and the Log still record every crossing. A save from before this build has no record, so
   each guild can re-announce its current rank once more. New harness block, watched to fail.

Gates: harness ok, luac x3, check_lua_api 0, check_lua_undeclared 0, gen --check and
--selftest, check_guilds_anchor, import --check, packed and content-verified, all three
scripts byte-identical in the saved pack. **Packed to Modpacks, MD5
`1FC5D7257C516BF6279CF67B2B0D25C6`, DEPLOYED 15:11 (6c item 6).** Rollback:
`Modpacks/derpy_great_guilds.pack.bak_20260923_pre_rankflip` (= the deployed 99A25F5C).

### 6c. Live checks still owed

1. ~~A building completing pays its themed guild~~ - confirmed, 6d.
2. ~~After the SECOND round, an AI faction's Daemonsmiths reputation is above 0 from
   technologies~~ - confirmed, 6e.
3. ~~The Log tab opens and records~~ - confirmed, 6d. Paging past 21 lines not yet seen.
4. The six tab labels fit their 125px plates in game fonts (the preview uses PIL's font).
5. ~~Deploy `99A25F5C...` with the game closed~~ - DEPLOYED 2026-09-23 13:18, game confirmed
   closed, MD5 matched on both sides, `used_mods.txt` line 119 still enables it. The 340DBF52
   build it replaced is `Modpacks/derpy_great_guilds.pack.bak_20260923_deployed_340dbf52`.
6. ~~Deploy `1FC5D725...`~~ - DEPLOYED 2026-09-23 15:11, game confirmed closed, MD5 matched,
   `used_mods.txt` line 119 still enables it. Still owed live: a guild pinned by rivalry keeps its rank
   through the next turn start, and re-crossing a rank you already reached raises no popup.
