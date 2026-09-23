# Handoff — The Great Guilds: a culture-agnostic mechanic chosen and designed (2026-09-10)

**Designed, planned, built, packed, deployed, then rewritten for the player.**
`derpy_great_guilds.pack` is 112,815 bytes, 15 content files, sitting in the game's `data/`
(disabled, as a new pack always is). Every offline gate is green and the packed bytes were read
back out with RPFM shut. **Nothing has run in a campaign yet** - the soak run is the whole
remaining task. Sections 10 and 12 are the two rounds of bug-finding that packing and then
reading the loc produced.

Files produced:

    docs/superpowers/specs/2026-09-10-great-guilds-design.md
    docs/superpowers/plans/2026-09-10-great-guilds-ladder.md
    docs/superpowers/plans/2026-09-10-great-guilds-panel.md
    docs/superpowers/plans/2026-09-10-great-guilds-ai.md
    tools/gen_great_guilds.py
    tools/gen_guilds_ui.py
    tools/check_guilds_ui.py
    tools/import_great_guilds.py
    tools/_guilds_harness.lua
    Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua
    Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua
    Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua
    Modding Files/pack/script/mct/settings/derpy_great_guilds.lua
    Modding Files/pack/ui/campaign ui/derpy_gg_{panel,card,row,opener}.twui.xml
    Modding Files/source/great_guilds/*.tsv   (6 tables + loc)

Second design session of 2026-09-10, after `HANDOFF_20260910_EXCHANGE_ORDERS_DESIGN.md`. That
one designed the Exchange's last approved feature; this one answers a different question the
user asked — *what mechanic should be built next, for variety and campaign management* — and
the answer is a new mod, not more Exchange.

Read the spec before the plan, and the plan before writing any code. The plan is **not yet
written**.

---

## 1. What was decided

**A new mod: The Great Guilds** (`derpy_great_guilds.pack`). Six world-spanning guilds; every
faction earns standing by playing its campaign and spends it on services. Depends on nothing,
and nothing depends on it.

| Decision | Answer |
|---|---|
| Scope | Universal architecture, **Chaos Dwarfs first**, then Dwarfs, then Empire |
| Earn loop | Passive earn, active spend |
| Rewards | Ranks gate services — permanent rank bundles plus repeatable purchases |
| Standing lives in | **Lua save state**, not pooled resources |
| Services fire as | Panel buttons running Lua, not rituals |
| UI | Own runtime-created panel, four tabs |
| AI | Accrues and spends, **15 of 18** services |
| Guilds | Six: Brass Tablets, Immortals, Daemonsmiths, Khanate, Overseers, Slavers |

The full reasoning for each is §2 of the spec. Three of them are worth restating here because
they were reached by measurement rather than preference:

- **Save state beat pooled resources** because `campaign_group_pooled_resources` needs a row
  per campaign group for universal coverage, and it is the table with no other reference
  leading to it. Miss one culture's group and that race silently gets nothing, with clean
  diagnostics. Save state cannot have that bug and covers modded factions free.
- **A custom panel beat the free rites panel** because the rites panel header reads
  `PooledResourceTransactionList.FirstContext` — with six currencies it shows one and hides
  five.
- **Two numbers per guild, not one.** Reputation drives rank and is never spent; favour is the
  currency. With one number, spending demotes you, so players bank forever and the spend half
  of the loop never runs.

---

## 2. Verified, and how

Everything below was read out of the source or CA's own docs this session, not recalled.

**Seven campaign event hooks exist** in `Modding Files/reference/ca_script_docs_wh3/`:
`BattleCompleted`, `ResearchCompleted`, `BuildingCompleted`,
`CharacterCharacterTargetAction`, `FactionTurnStart`, `MissionSucceeded`,
`PositiveDiplomaticEvent`. Six of the seven are the earn hooks in the design.

**Twelve `cm:` calls checked against `campaign/episodic_scripting.html`**, hit counts in
parentheses: `apply_effect_bundle` (12), `treasury_mod` (2), `grant_unit_to_character` (2),
`instantly_research_technology` (2), `make_region_visible_in_shroud` (2),
`instantly_upgrade_building` (4), `add_building_to_force` (2), `faction_add_pooled_resource`
(2), `replenish_action_points` (2), `force_add_trait` (6), `add_ancillary_to_faction` (2).

**One does not exist: `cm:add_faction_research_points` — zero hits.** It was in the first
draft of the Daemonsmiths' tier-2 service. Replaced with `instantly_research_technology`.

**The thirteen Chaos Dwarf pooled resources and their scopes**, read from
`read_vanilla_cache.load("pooled_resources")` with RPFM shut — see §3 for the full list.

**`wh3_dlc23_chd_conclave_influence` is script-writable and already written to.**
`Modding Files/pack/script/campaign/<campaign>/mod/debug_conclave_influence.lua` grants 25 to
thirteen named factions at first tick via
`cm:faction_add_pooled_resource(key, "wh3_dlc23_chd_conclave_influence", "wh3_dlc23_chd_conclave_influence_gained_events", 25)`.

**Influence has exactly one class of sink.** `TOWER_OF_ZHARR_CUSTOM_SEATS.md`:
"Conclave influence is expended by 31 rituals and every one is a ToZ seat."

---

## 3. Do not re-derive

**`read_vanilla_cache.load(name)` returns a tuple `(rows, fields)`, not a list of dicts.**
`rows` is the list. A first attempt at `for r in load("pooled_resources")` failed with
`'list' object has no attribute 'get'` because it was iterating the two-element tuple. Correct
form:

    rows, fields = R.load("pooled_resources")

**The thirteen Chaos Dwarf pooled resources, with scope** — this is the table that decides
whether a script can reach a resource at all:

| Resource | Scope |
|---|---|
| `wh3_dlc23_chd_armaments` | FACTION |
| `wh3_dlc23_chd_conclave_influence` | FACTION (max 999999) |
| `wh3_dlc23_chd_raw_materials` | FACTION |
| `wh3_dlc23_chd_labour_global_temp` | **FACTION** |
| `wh3_dlc23_chd_hellforge_*_unlocker` (six) | FACTION |
| `wh3_dlc23_chd_efficiency` | FACTION_PROVINCE |
| `wh3_dlc23_chd_labour` | FACTION_PROVINCE |
| `wh3_dlc23_chd_workload` | FACTION_PROVINCE |

**`wh3_dlc23_chd_labour_global_temp` is FACTION scope**, which makes it the only
labour-flavoured resource a script could reach. It was found while ruling out a slave-economy
mechanic and is **unprobed** — the name suggests a transfer buffer CA uses internally, and
writing to it may do nothing or may corrupt the province-level labour economy. If a slave
mechanic is ever revisited, probe this before designing around it.

**A long spec does not survive a bash heredoc.** Writing the 430-line spec with
`cat > file <<'SPEC'` failed with `unexpected EOF while looking for matching quote` at line
143. The Write tool did it in one call. For anything with mixed backticks, apostrophes and
em-dashes at this length, do not use a heredoc.

---

## 4. Corrections found the hard way

**The first recommendation was scoped wrong, and the lesson generalises.**

The session's opening survey produced a strong pitch: house intrigue built on
`wh3_dlc23_chd_conclave_influence`, on the grounds that a real FACTION-scope currency already
exists, is already script-written by a shipped debug script, and has exactly one sink in the
entire game. Every one of those facts is true and every one was verified.

The user rejected it in one sentence: *"I want something that can be used by a lot of
factions, not only the Chaos Dwarfs."*

> **A currency that exists, is reachable and is under-used is an argument for building on
> it — never an argument that the mechanic is well-scoped. Establish the audience constraint
> before surveying for a hook, because a survey run against the wrong constraint returns
> confident, verified, useless answers.**

Two of the three initial candidates (house intrigue, slave economy) died on the same word.
The second pass, run against "culture-agnostic", produced a different and better set.

**The bundle count was wrong in the spec as first written: 37, actual 36.** It came from
counting *services* that sound like bundles rather than counting services that use one. Six of
the eighteen carry no bundle at all — Caravan Levy (gold), Hire the Immortals (unit grant),
Bound Blueprint (instant research), Hobgoblin Eyes (shroud), Raise the Ziggurat (instant
building), Slave Tithe (pooled resource). Corrected in three places during the spec
self-review, which is the only reason it was caught.

**Lore-friendliness needed to be raised, and was not.** The user asked *"is it lore friendly
to the Warhammer world?"* after the title and summary were produced. The honest answer is that
a single six-guild set spanning Greenskins, daemons and Tomb Kings is not — guilds are a
human-and-dwarf civilised-society institution in Warhammer. The fix (a loc-only reflavour
layer keyed by subculture, generic fallback) costs ~11 strings per culture family and no
logic. It should have been in the first universal pitch, not added after being asked.

---

## 5. What the design rules out, and why

Recorded so they are not re-proposed:

- **Rival guilds** (raising one lowers another) — fights the passive earn loop.
- **Exclusive top ranks** (a limited-seat contest like ToZ seats) — most that can go wrong in
  balance and save state.
- **Map-present chapter houses** — most invasive to vanilla region data.
- **Guild units and buildings** — the one reward shape needing unit art and per-culture
  rosters, which is the per-race work the design exists to avoid.
- **A slave economy as its own mod** — `wh3_dlc23_chd_labour` is FACTION_PROVINCE and both
  managers return a null interface. See §3 for the one unprobed alternative.
- **A contract board off CA's ~50 objective types** — a genuinely strong option, and the one
  that was recommended before the user chose guild standing. `MISSIONS.md` §4 holds the
  vocabulary if it is ever picked up. Its one unknown is whether the same mission key can be
  re-issued repeatedly; `MISSIONS.md` §12 does not answer it.

---

## 6. Still open

1. **The implementation plan is not written.** This is the immediate next step.
2. **Nothing is built.** No generator, no Lua, no UI, no pack.
3. **A GUID prefix has not been chosen** for the new panel. It must not be `DE15xxxx`, which
   is retired, and must be recorded in both ledgers (`tools/gen_exchange_ui.py` and
   `docs/CUSTOM_UI.md`).
4. **Every number in spec §4 is a shape, not a measurement.** Rank thresholds, earn rates,
   per-turn caps, service prices and cooldowns are all unvalidated. Spec §11 is the live test
   list, ordered by what a wrong answer costs.
5. **The settlement event pair for the Slavers hook is not named to a key.** The design says
   read the past-tense one; which key that is has not been resolved for this build.
6. **Phases 2 and 3** (Dwarfs, Empire) have no name sets written.

---

## 7. See also

- `docs/superpowers/specs/2026-09-10-great-guilds-design.md` — the design itself
- `docs/STOCK_MARKET_DESIGN.md`, `docs/ZHARR_EXCHANGE.md` — the architecture borrowed
- `docs/CUSTOM_UI.md` — the panel rules and the GUID ledger
- `docs/RITUALS.md` §7 — the rites-panel ceilings that ruled out the free-UI route
- `docs/HELLFORGE_UNIT_CAPS.md` — the `campaign_group_pooled_resources` trap
- `docs/MISSIONS.md` §4 — the objective vocabulary, if a contract board is ever revisited

---

## 8. What was built, and the gates it passes

All three plans implemented in order. **Every gate below was run and is green:**

    gen_great_guilds.py --selftest    6 guilds, 18 services, 36 bundles, 107 loc
    gen_great_guilds.py --check       exit 0 (vanilla effect keys, scopes, unit key, feed index)
    gen_guilds_ui.py --selftest       4 files, 54 guids
    gen_guilds_ui.py --check          exit 0
    check_guilds_ui.py --selftest     6/6 injected faults caught
    check_guilds_ui.py                0 problems
    luac -p                           4 files, all exit 0
    _guilds_harness.lua               harness ok (all three plans' assertions)
    check_lua_api.py                  3 files, 0 suspect calls
    check_lua_undeclared.py           9 files, 0 with undeclared names
    import_great_guilds.py            verify ok

Shipped content: 6 guilds, 5 ranks, 24 rank bundles + 12 service bundles = **36**, 18 services,
a 4-tab runtime panel from 4 `.twui.xml` files on the **GG21** GUID prefix, AI accrual and
spending on 15 of the 18, a minted event-feed chain, and an MCT settings file with 14 tunables
frozen into the save at the first turn start.

**GG21xxxx claimed in both ledgers** (`tools/gen_exchange_ui.py` and `docs/CUSTOM_UI.md`).

---

## 9. Eleven corrections found by building it

Every one of these was a silent failure. Nine were caught by a verification step the plan had
deliberately written as "read this, do not assume", which is the case for writing them that way.

1. **`cm:apply_effect_bundle`'s duration: `-1` is indefinite, not `0`.** CA's doc, verbatim:
   "-1 may be supplied to apply the effect indefinitely." The code shipped `0` first, which
   applies a bundle for **zero turns** - the rank ladder would have granted nothing, forever,
   with no error. The harness now pins `applied[1][3] == -1`.
2. **`cm:instantly_upgrade_building` does not exist.** `check_lua_api.py` caught it. The real
   call is `cm:region_slot_instantly_upgrade_building(slot, building_key)` and it takes a **slot
   object plus a building key**, not a region - so that service's target had to become a table
   of both.
3. **`BattleCompleted`'s context carries only `model`.** No faction, no attacker, no winner.
   `context:faction()` on it would throw and kill every listener registered after it. The
   working hook is **`CharacterCompletedBattle`**, which gives `pending_battle` *and*
   `character`, and `character:won_battle()` returns "was in the winning alliance".
4. **`wh3_dlc23_chd_raw_materials` has NO `events` factor junction.** Only `missions`, and that
   one is grant-only (min 0). Armaments accepts both. A `slave_tithe` paying through `events`
   would have granted armaments and silently nothing else. **`missions` is the only factor both
   pools take**, which is what the victory-routes work found independently.
5. **The `effects` table's key column is named `effect`, not `key`.**
6. **`effect_bundles_to_effects_junctions` columns are `effect_bundle_key, effect_key,
   effect_scope, value, advancement_stage`** - the scope column is `effect_scope`, and there is
   an `advancement_stage` column nothing in the plan knew about (16,351 of 16,430 vanilla rows
   are `start_turn_completed`).
7. **Only 40 distinct effect keys are used at plain `faction_to_faction_own`.** 3,107 rows use
   `faction_to_faction_own_unseen` instead, and `_unseen` hides the effect from the player. All
   six guild effects were re-picked from the 40, plus `faction_to_province_own` and
   `faction_to_region_own` for the two categories the 40 do not cover.
8. **No Infernal Guard unit key carries a `_0` suffix.** The real key is
   `wh3_dlc23_chd_inf_infernal_guard_great_weapons`.
9. **`floor(sack * 1.6)` is a float32 trap of my own making.** 1.6 is not exact in binary and
   WH3 Lua is single-precision, so a raze could have paid 39 instead of 40. Rewritten as
   `floor(sack * 8 / 5)` - integer multiply, then divide - and pinned by an assertion.
10. **`read_vanilla_cache.load()` returns a tuple `(rows, fields)`,** not a list.
11. **A 430-line file cannot be written through a bash heredoc** (unmatched-quote at line 143).

**And one thing the UI checker caught that no human would have:** the panel Lua created the HUD
opener button from the 750x40 standings-row template, which would have put a full-width row on
the campaign HUD. It also caught `draw_standings` using a string literal where every other call
site used `GGUI.ROW`, which its `_\d+$` normaliser could not match.

---

## 10. Packing, and the two bugs it found

**The registered RPFM MCP tools were not in the session** - the server was started after Claude
Code, so `ToolSearch` found none of the 150 even though `/sessions` answered 200. The fallback in
`MEMORY/rpfm-mcp-over-raw-http` is what did the work: `initialize` over `curl`, then every later
call carrying the returned `Mcp-Session-Id`. `generate_dependencies_cache` measured 54 s and
104,997,703 bytes, matching the 2026-09-03 figures exactly.

**Two real bugs surfaced only at pack time**, both invisible to every offline gate:

1. **The generated TSVs were not in RPFM's format.** RPFM refuses a plain header-plus-data file
   with `This TSV file has an invalid version value at line 1` and imports **nothing**. Row 2
   must be `#<table>_tables;<version>;<container path>`, tab-padded to the column count. Every
   other generator in this workspace already emitted that line; `gen_great_guilds.py` was
   written without it. Fixed at the source: `TSV_META` now carries CA's live version per table,
   `write_tsvs` emits the line, `--write` regenerates, and `import_great_guilds.py` verifies
   row 2 matches - so a stale TSV is now a refusal rather than a silent wrong-version import.
   Also: `import_tsv` writes into a file that must already exist, so each table needs a
   `new_packed_file` first. Both routes are now in `docs/MODDING_TOOLS.md`.

2. **All 36 bundle descriptions carried a `%+n` placeholder.** `%+n` belongs on an **effect**
   description, where the engine substitutes the effect's value. A **bundle** description has no
   value to substitute, so it renders literally. Measured against CA's own loc: **1 of 5,855**
   vanilla bundle descriptions contains a placeholder. The generator's selftest was asserting
   the bug (`assert "%+n" in r["text"]` over every description key); it now asserts the
   opposite for bundle descriptions specifically.

**CA's live table versions, read this session** (`get_table_version_from_dependency_pack_file`
wants the `_tables` suffix - the bare name answers `Table not found in the game files`, which
reads like absence rather than a misnamed argument):

| Table | Version |
|---|---|
| `effect_bundles_tables` | 4 |
| `effect_bundles_to_effects_junctions_tables` | 3 |
| `campaign_groups_tables` | 0 |
| `campaign_group_members_tables` | 1 |
| `campaign_group_member_criteria_values_tables` | 0 |
| `event_feed_message_events_tables` | 1 |

All six column sets match those versions field-for-field in raw order.

**No icons were needed.** The plan carried "extract 6 guild + 5 rank icons" as a task; the built
content references none. `effect_bundles.ui_icon` is empty on all 36 rows, and **1,159 of 5,855
vanilla rows leave it empty too**, so that task was an assumption, not a requirement.

**Verified from outside the tool that wrote the pack**, with RPFM shut, via
`tools/read_pack_index.py`: 15 content files, every fragment uncompressed; the loc parses as 107
entries with 107 unique keys and **zero** `%` placeholders; `effect_bundles` holds 24
`derpy_gg_rank_` and 12 `derpy_gg_svc_` keys; the junctions hold 36 effect keys with no
`_unseen` scope; and the model Lua carries the `-1` duration, the `* 8 / 5` raze arithmetic, the
`missions` tithe factor, `region_slot_instantly_upgrade_building` and
`CharacterCompletedBattle`, with no `BattleCompleted`.

A note on reading a packed loc: **do not substring-match the raw bytes.** The u16 length
prefixes interleave with the UTF-16LE text, so decoding the whole fragment as UTF-16 shifts
alignment and a key that is present reads as absent. Parse the LOC layout.

---

## 11. What is left

- **The soak run to turn 100** - plan 3's Task 7. Rate curve, AI spending balance, the Khan's
  Price feed message, rank bundle visibility in Faction Effects, and save/reload. Every number
  in the spec is still a shape rather than a measurement.
- **The pack is disabled.** A new pack in `data/` is listed and unticked; it must be enabled in
  the launcher or mod manager before it loads.
- `GG.was_outnumbered` returns `false` unconditionally - the strength comparison was
  deliberately deferred.
- `GGUI.selected_enemy_faction()` returns nil - the player-side enemy picker is still a stub.
- Phases 2 and 3 (Dwarfs, Empire): loc name sets and icons only, no logic.

---

## 12. The loc pass, and the sign bug it uncovered

The question that started this was simply *"are the locs user friendly, like a developer
explaining mechanics to a player?"* The answer was **no**, and answering it honestly required
reading all 107 strings rather than trusting that they resolved. They did resolve - no key drew
raw on screen - and they still taught the player nothing:

| Gap | Was |
|---|---|
| Service descriptions | **0 of 18.** A card read `Forge-Rite   Sworn   400` and nothing else - no effect, no duration, and `400` carried no unit, so a player could not tell favour from gold |
| Guild descriptions | **0 of 6.** Six names, no hint which guild rewarded what |
| Rank bundle descriptions | 36, but all four ranks of a guild said the identical `Standing with The Brass Tablets.` - four indistinguishable rows in Faction Effects |
| Reputation vs favour | **0.** The two-currency split is the core of the design and was explained nowhere in-game |
| Rank thresholds | 0. `Sworn` never said 300 |

Loc went **107 -> 135 rows**. Descriptions are now *generated from the SERVICES data* -
cost, cooldown, duration, rank requirement and effect value are all interpolated, so a
description cannot drift from the number it describes. The panel gained `set_tooltip`, wired onto
the service cards, the cost label, the rank line, the league-table rows and the panel title; the
title's tooltip is the reputation-vs-favour explainer. `set_tooltip` clears with
`SetTooltipText("", true)` before writing, because **SetTooltipText appends** and a tooltip
rewritten every refresh would grow without bound - the same idiom the shipped Zharr Exchange
uses.

**Writing the descriptions is what found the real bug.** To say what a rank grants you have to
know the sign, and two of the six guild effects have **`is_positive_value_good = False`**:

| Effect | Guild | is_positive_value_good |
|---|---|---|
| `wh_main_effect_agent_recruitment_cost_mod` | Khanate | **False** |
| `wh2_dlc11_effect_building_construction_cost_mod_all_settlement` | Overseers | **False** |

Both are **cost** modifiers, so the ladder's `+3 / +6 / +10 / +15` made agents and buildings
*dearer*. Two of six guilds punished the player harder the more reputation they earned, drawn in
red as a malus. Every earlier check passed it: the keys exist, the scopes are vanilla-precedented,
the junction rows are well-formed, the pack loads.

**And the hostile service inverted a second time.** The Khan's Price applies its bundle to the
**target**, so at the guild's own good sign it was `-20%` agent recruitment cost - a *discount for
the victim*. The mod's only aggressive service was a gift. `service_sign()` now flips the sign for
a hostile service, and its loc is written from the victim's side ("across their provinces", not
"every province you own").

`check()` now refuses on both: `EFFECT_GOOD_SIGN` must agree with vanilla's
`is_positive_value_good` per guild, **and** every emitted junction value must carry that sign,
with hostile bundles expected inverted. Verified in the packed binary, not just the TSV:
`derpy_gg_rank_khanate_5` = **-15**, `derpy_gg_rank_overseers_5` = **-15**,
`derpy_gg_svc_khans_price` = **+20**, `derpy_gg_rank_brass_5` = **+15**.

One correction to section 10 while here: the placeholder assertion added there
(`assert "%" not in text`) was **too strict** and had to be narrowed to
`re.search(r"%[-+]?n", text)`. A **literal** percent sign is correct and necessary - `-15%` reads
as a percentage - and only a substitution *placeholder* is the fault.

---

## 13. The opener button did not draw, and it was a repeat offence

First contact with a running campaign: the mod loaded and there was **no way into the panel**.

The opener was created like this:

    local host = comp("button_rituals") or comp("layout")
    host:CreateComponent("gg_opener", GGUI.PATH_OPENER)

Two faults, and **the Zharr Exchange had already paid for both**, in a comment block sitting in
this same workspace above `EX.place_button`:

1. **`button_rituals` is a member of a RadialList** (`starting_angle="3.64773798"`,
   `radius="95"`, declared in `ui3.pack/ui/campaign ui/hud_campaign.twui.xml`). A layout group
   OWNS its children's positions. MoveTo does not lose a fight with a layout engine - it never
   gets to have one. The Exchange measured this exact failure and wrote it down.
2. **Nothing positioned it at all**, and `dockpoint` is ignored on a runtime component, so even
   off a plain parent it would sit at the parent's origin.

The rewrite follows the Exchange's proven shape:

- **Created on the UI root**, which carries no LayoutEngine and is always present.
- **`resources_bar` is a RULER**, read for `Position()` and `Dimensions()` and never made the
  parent. The Exchange parks its opener off the strip's RIGHT end, so the guilds button goes off
  the **LEFT** end and the two cannot collide when both mods are installed.
- **Screen size from `core:get_screen_resolution()`**, which is `ui_root:Dimensions()`. Not
  `Bounds()` - that includes children, balloons while the HUD settles, and makes an off-screen
  position pass its own guard.
- **Retry chain** on `cm:callback`, because the HUD is not laid out when the first callback runs
  and a one-shot create silently does nothing forever. Creation retries, not just placement.
- **Anchor recomputed every call**, never cached, so a bad early read heals instead of becoming
  permanent.
- **Clamp a small overshoot, refuse a wild one.** `resources_bar` is animated and slides off the
  top during intros and end-turn; but a flat `y < 0` refusal is also wrong, because some cultures
  settle at `y = -5` and refusing those leaves the mod with no way in at all. Tolerance is one
  button.
- **Read the position back.** If what MoveTo was asked for is not what `Position()` returns,
  something else is laying the component out. Nothing in the engine reports that otherwise - the
  button simply appears elsewhere, or nowhere, which is exactly what happened.

**The checker missed it, and that is now fixed.** `gen_guilds_ui.py` only scanned `comp("...")`
calls, so the CA component name reached through `find_uicomponent` was never validated - a typo
there fails silently at runtime, which is the precise class of bug this check exists to catch. It
now scans both forms, and **strips Lua comments first**, because this file documents the
`button_rituals` mistake in prose and a raw-text scan reads those mentions as live references.
`HOST_COMPONENTS` went from `{"button_rituals", "layout"}` - neither of which the Lua touches any
more - to `{"resources_bar"}`. Fault-injected and confirmed: renaming the anchor to
`resources_barr` now fails the selftest.

**The lesson is not new, which is the point.** `MEMORY/wh3-layout-group-overrides-moveto` and
`docs/CUSTOM_UI.md` both already said it. Reading the shipped pack that solved the same problem
should have come before writing the opener, not after the button failed to appear.

## 14. The panel looked alpha, and four things were why

The mod ran clean - 314 factions tracked, purchases correctly gated, zero errors in the log -
and still read as a prototype. Four separate causes, none of which any check would have caught,
because every one of them is legal XML that draws *something*.

**1. `fontcat_name` is a fixed vocabulary, not a size.** `gen_exchange_ui._state` built the
category as `"body_%d" % size`, so every size-14 label shipped `fontcat_name="body_14"`. Counted
across `ui.pack`, `ui2.pack` and `ui3.pack`: **32 distinct values**, and the only body sizes CA
has are **10, 12 and 16**. An unknown value is not an error and not a blank - the engine falls
back, so every button caption and card label in both the Exchange and the Guilds rendered in a
font nobody chose. `EU.fontcat()` now snaps a size to the nearest real category or takes an
explicit `fontcat=`; `gen_guilds_ui.check()` refuses on any name outside `EU.FONTCATS`.
Fault-injected and confirmed.

**2. A 750px card was a stretched button plate.** `button_square_large_text_active.png` pulled
that wide is a smear. The card is now the same body-then-border pair as the panel frame
(`panel_back_tile` + `panel_back_border`), at a tighter border margin so the cards nest inside
it. The standings rows had the identical bug six times over and are now a flat tint.

**3. The card's middle was empty and the description was in a tooltip.** A 750x120 plate carried
a name in one corner and a number in the other. The service_desc loc is
`"<what it does>||<the terms>"`; the payload sentence now goes on the card as `card_desc` and the
terms stay in the tooltip, where the cost figure and the red rank tag already repeat them.

**4. Nothing said which guild.** Each card now carries a 44px glyph, swapped per guild at draw
time by `GGUI.GUILD_ICON` - the card is one template shared by all six guilds, so the icon cannot
be baked into the `.twui.xml`. `check()` parses that Lua table and asserts every path resolves in
a ui pack, the same guard the baked-in imagepaths get.

Also added: a `panel_back_divider` rule under the title, and a `gg_bar_track` behind the
reputation bar - deliberately named to sort *before* `gg_rep_bar`, because `PANEL_LAYOUT` is
emitted in `sorted()` order and a component declared later draws on top. Named `gg_rep_track` it
would have covered the fill completely.

**The log also carries 257,738 copies of one error, and none of them are ours.**
`jg77_legendary_lords_hunt.lua:11` calls `find_uicomponent` with a stale parent handle on a timer
callback; the script log for that session is 302 MB. Worth knowing before reading any log on this
install - a naive error grep drowns.
