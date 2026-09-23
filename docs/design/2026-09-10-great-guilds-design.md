# The Great Guilds — design

Approved in conversation 2026-09-10. A new mod, not an extension of any existing pack:
`derpy_great_guilds.pack`. It depends on nothing and nothing depends on it.

Six world-spanning guilds. Every faction earns standing with them by playing its campaign,
and spends that standing on services. Chaos Dwarfs ship first; Dwarfs and the Empire follow
as loc-and-icon layers with no logic changes.

Implementation plan: not yet written.

---

## 1. The gap this fills

The mod set already manages finance (the Zharr Exchange), territory and politics (Tower of
Zharr seats), items (430 house ancillaries and four acquisition flows), progression (skill
trees, victory routes, quests) and armies (units, naval hordes). Every one of those is
Chaos-Dwarf-bound.

This is the first gameplay mod in the set that is **not** race-locked. That is the point of
it, and it is the constraint every decision below answers to.

The mechanic itself is old and proven in other games: a reputation ladder with sinks. What
makes it cheap here is that the earn signals are things *every* culture in Warhammer III
already generates, so there is no per-race behaviour table anywhere in the design — only
per-race names.

---

## 2. Decisions taken 2026-09-10

| Question | Answer | Why |
|---|---|---|
| Scope | Universal architecture, **Chaos Dwarfs first**, then Dwarfs, then Empire | Phases 2 and 3 are loc plus icons, no logic. The architecture is what makes that true; shipping CHD first is only a content decision. |
| Earn loop | **Passive earn, active spend** | Standing accrues from what the player already does. The decision is when and where to cash it in, not an added chore. |
| Rewards | **Ranks gate services** | Ranks are permanent progress, services are the repeatable spend. Either alone degenerates: ranks-only is a progress bar you fill and forget, services-only has no long game. |
| Where standing lives | **Lua save state**, not pooled resources | Culture-blind by construction, which is the requirement. `campaign_group_pooled_resources` would need a row per campaign group for universal coverage; it is the table with no other reference leading to it, and its absence produces three silent symptoms with clean diagnostics. Save state cannot have that bug and covers modded factions for free. |
| How services fire | **Panel buttons running Lua**, not rituals | The Exchange settled this: `EX.apply_trade` is a panel button, not a rite. Lua payloads also get effect-bundle **durations**, which DB ritual payloads cannot express. |
| UI | **Own runtime-created panel**, four tabs | Chosen over the free rites panel. The rites panel header reads `PooledResourceTransactionList.FirstContext`, so with six currencies it would show one and hide five. |
| AI | **Accrues and spends**, 15 of the 18 services | Makes the guilds part of the world rather than a player menu, and gives the Standings tab something to show. |
| Guild count | **Six** | Merchants, mercenaries, scholars, shadows, masons, reavers. Six covers tall, wide, peaceful, military, agent-heavy and raiding play. |

---

## 3. The six guilds

The **skeleton is universal**; the names are a loc layer keyed by subculture with a generic
fallback. This is the Exchange's race-profile-plus-fallback pattern with the numbers removed.

Guilds are **not** houses. Houses are dynastic and political — Tower of Zharr seats. Guilds
are professional and institutional; they sell services. If a player reads the panel and
thinks "these are houses again", the mod has failed. That distinction belongs in the loc, the
icons and the panel copy.

### 3.1 Chaos Dwarf flavour (phase 1)

| Track | Guild | Lore basis |
|---|---|---|
| Merchants | **The Brass Tablets** | Arms and slave contracts, Babylonian tablet-law. The one invented name. |
| Mercenaries | **The Immortals** | Astragoth's oath-bound elite guard. |
| Scholars | **The Daemonsmiths** | The engineer-priests who bind daemons into machines. |
| Shadows | **The Khanate** | Hobgoblin cutthroats and overseers. |
| Masons | **The Overseers** | Slave-driven construction. |
| Reavers | **The Slavers** | Raids taken for chattel, not plunder. |

Five of the six are named lore institutions.

**One rank ladder, shared by all six guilds.** Chaos Dwarf society runs on debt and oath, so
the ladder is a debt ladder:

    Unmarked -> Indebted -> Sworn -> Favoured -> Exalted

### 3.2 Later phases

Phase 2 (Dwarfs) and phase 3 (Empire) add one name set and one rank ladder each, plus icons.
No logic, no new tables beyond loc. Both cultures have guilds literally in lore — the Dwarf
Engineers' Guild, the Imperial Engineers School, the Wizards' Colleges, the merchant guilds
of Altdorf and Nuln — so both are straight translations rather than inventions.

An unmatched culture falls back to plain descriptive names. It is never left with nothing.

---

## 4. The two numbers

Each faction holds **two numbers per guild**:

| Number | Moves | Purpose |
|---|---|---|
| **Reputation** | only up, from play | Drives rank. Never spent. |
| **Favour** | up from play, down from spending | The currency. |

An earning event grants both, in equal amount. Spending takes only favour.

**This split is load-bearing.** With one number, spending demotes you, so players bank
forever and the spend half of the loop never runs. This is the single most likely way the
mod fails as a design, and the two-number split is the whole defence.

### 4.1 Rank thresholds

Lifetime reputation. Same ladder for all six guilds.

| Rank | Reputation |
|---|---|
| Unmarked | 0 |
| Indebted | 100 |
| Sworn | 300 |
| Favoured | 700 |
| Exalted | 1500 |

### 4.2 Earn rates

| Guild | Rate | Per-turn cap | Hook |
|---|---|---|---|
| Brass Tablets | `floor(net_income / 250)` | 40 | `FactionTurnStart` |
| Immortals | 15 per battle won, x2 if outnumbered | 60 | `BattleCompleted` |
| Daemonsmiths | 60 per technology | none | `ResearchCompleted` |
| Khanate | 8 per successful agent action | 40 | `CharacterCharacterTargetAction` |
| Overseers | 10 x building level completed | 40 | `BuildingCompleted` |
| Slavers | 25 per sack, 40 per raze | 80 | settlement events |

All six hooks confirmed present in CA's own docs under
`Modding Files/reference/ca_script_docs_wh3/`, 2026-09-10.

**The per-turn caps are not decoration.** Without them, income-scaled reputation lets a large
empire max the Brass Tablets passively while a small one never climbs. The cap flattens that.
It is the lazy fix and it is sufficient.

**The Slavers hook reads the past-tense settlement event only.** Settlement events come in
tense pairs and only the past-tense one carries usable data; a razed region answers with
nothing at all.

### 4.3 Favour cap

**Favour caps at 2x the current rank's threshold.** Self-scaling, and it pressures spending
rather than banking. At Sworn that is 600 favour, roughly two tier-2 services.

### 4.4 Arithmetic

WH3 Lua is **float32** — 1.05 evaluates as 1.0499999523163, and a .5 rounding boundary falls
the wrong way. Every rate above is `floor` on integers. The only multiplier is the Immortals'
x2, which is exact in binary.

### 4.5 Tuning

Every number in this section lives in one table, exposed through MCT with a difficulty preset
and frozen into the save at the first turn start. The established pattern from the Exchange,
no new mechanism.

**These are starting values, not measurements.** They are shaped so the first rank lands near
turn 15 and Exalted near turn 100 in focused play. Only a soak run settles them; see §11.

---

## 5. The eighteen services

Three per guild, rank-gated. Every `cm:` call named below was verified against
`campaign/episodic_scripting.html` on 2026-09-10.

**One call that was wanted does not exist:** `cm:add_faction_research_points`. Zero hits.
Replaced with `cm:instantly_research_technology`, which is present.

| Guild | Rank | Service | Favour | CD | Effect |
|---|---|---|---|---:|---|
| Brass Tablets | Indebted | Caravan Levy | 50 | 8 | +2500 gold, `cm:treasury_mod` |
| | Sworn | Writ of Monopoly | 150 | 12 | +15% trade and building income, 10 turns |
| | Favoured | The Long Ledger | 400 | 20 | -20% construction cost, +20% income, 15 turns |
| Immortals | Indebted | Oathbound Draft | 50 | 6 | +50% replenishment, 5 turns |
| | Sworn | Hire the Immortals | 150 | 10 | Elite regiment into an army, `cm:grant_unit_to_character` |
| | Favoured | Astragoth's Levy | 400 | 15 | Faction melee and leadership, 10 turns |
| Daemonsmiths | Indebted | Forge-Rite | 50 | 8 | +25% research rate, 8 turns |
| | Sworn | Bound Blueprint | 150 | 14 | Completes current technology, `cm:instantly_research_technology` |
| | Favoured | Daemon-Bound Ordnance | 400 | 15 | Artillery and missile damage, 10 turns |
| Khanate | Indebted | Hobgoblin Eyes | 50 | 6 | Reveals a region, `cm:make_region_visible_in_shroud` |
| | Sworn | Knife in the Dark | 150 | 10 | +25% agent action success, 8 turns |
| | Favoured | The Khan's Price | 400 | 18 | -public order **on a target enemy faction**, 10 turns |
| Overseers | Indebted | Lash the Gangs | 50 | 6 | -30% construction cost, 6 turns |
| | Sworn | Raise the Ziggurat | 150 | 12 | Completes a building, `cm:instantly_upgrade_building` |
| | Favoured | Works of Zharr | 400 | 15 | +growth, +public order, 12 turns |
| Slavers | Indebted | Coffle Drive | 50 | 8 | +50% sack and raid income, 8 turns |
| | Sworn | Slave Tithe | 150 | 10 | +armaments and raw materials, `cm:faction_add_pooled_resource` |
| | Favoured | The Great Coffle | 400 | 18 | Large one-off gold plus -upkeep, 12 turns |

**A service above the player's rank draws greyed with the rank it needs, not hidden.** A
visible locked thing is a goal; a hidden one is nothing.

### 5.1 Two services that carry the design

**The Khan's Price is the only outward-facing service.** `cm:apply_effect_bundle` takes a
faction key, so it can target an enemy. Without it the entire menu is self-buffs and the
guilds never touch the world.

**Slave Tithe is the only place culture matters**, and it is a two-line branch rather than a
profile table: Chaos Dwarfs receive `wh3_dlc23_chd_armaments` and `wh3_dlc23_chd_raw_materials`
(both `FACTION` scope, both reachable); every other culture receives gold. Phases 2 and 3 add
one line each if a culture has its own faction-scope resource worth granting.

### 5.2 Effect bundle volume

**Thirty-six bundles.** Twenty-four rank bundles — four per guild, Unmarked grants nothing —
plus twelve service bundles. Generated by script.

The other six services carry no bundle: Caravan Levy (gold), Hire the Immortals (unit grant),
Bound Blueprint (instant research), Hobgoblin Eyes (shroud), Raise the Ziggurat (instant
building) and Slave Tithe (pooled resource).

Two rules that are silent when broken, and both apply to all thirty-six:

- An effect description **needs a `%+n` placeholder** or the tooltip draws the sentence with
  no number.
- `is_global_effect` must be **true** or a live bundle stays invisible in Faction Effects.
  It is a display flag, not a targeting flag.

---

## 6. The AI

AI factions accrue identically — the same listeners run for every faction — and spend on a
simple per-turn policy.

**Bounds:** one purchase per AI faction per turn, and an MCT switch that turns AI spending off
entirely.

### 6.1 What the AI can buy: 15 of 18

**Thirteen need no target.** Faction-wide bundles, gold and pooled resources: Writ of
Monopoly, The Long Ledger, Oathbound Draft, Astragoth's Levy, Forge-Rite, Daemon-Bound
Ordnance, Knife in the Dark, Works of Zharr, Coffle Drive, Lash the Gangs, Caravan Levy,
Slave Tithe, The Great Coffle. Zero extra logic.

**Two are worth a one-line picker:**

| Service | Picker | Why include |
|---|---|---|
| Hire the Immortals | First non-garrison force | The most **visible** AI service — an elite regiment appears in an army the player fights |
| The Khan's Price | A faction it is at war with | The only service that can target the player. This is the mechanic having teeth |

**Three are cut from AI use in v1:**

| Service | Why cut |
|---|---|
| Hobgoblin Eyes | Revealing shroud is meaningless for an AI |
| Bound Blueprint | Needs a read of the AI's current research subject — call unverified |
| Raise the Ziggurat | Needs a per-turn scan for regions with construction in progress. Real cost, small payoff |

Adding the three later is additive and changes nothing else.

### 6.2 Two consequences

**An AI service that lands on the player must be announced.** An unexplained public-order
debuff is a bug report, not a mechanic. That needs an event feed message, and
`cm:show_message_event`'s last argument indexes `event_feed_message_events` through a
four-table chain — a wrong index draws nothing. Budgeted, not free.

**Hire the Immortals needs a garrison filter.** `military_force_list` counts garrisons, so an
unfiltered pick can hand an elite regiment to a city garrison instead of a field army.

---

## 7. The panel

Own runtime-created panel, its own `.twui.xml` files, **overriding no CA file** — so it
collides with nothing, the way the house ancillaries pack does.

**Four tabs.** The Exchange's strip was measured full at five 132px tabs; four fits with room.

| Tab | Content |
|---|---|
| **Guilds** | Six pages, one per guild. Header: name, rank, reputation X/Y to next, favour held. Body: three service cards |
| **Standings** | The player's six tracks at a glance, plus who holds top rank in each — the league table |
| **Log** | Rank-ups, the player's purchases, AI purchases, and any service used against the player |
| **Help** | Two pages of guide text |

**Service card:** name, favour cost, cooldown remaining, effect line, Buy button.

**Opener button** beside the rites button, placed exactly as the Exchange places its own.

### 7.1 Five build constraints this inherits

1. **A new GUID prefix, recorded in both ledgers.** `DE15xxxx` is retired and must not be
   reused — reusing a prefix against a save still holding the old component is a silent
   non-draw.
2. **Every component needs an entry in the hierarchy tree *and* the components block, bound by
   the same GUID.** Miss the hierarchy node and the file is valid, well-formed and never drawn.
3. **`MoveTo` is the only thing that positions a runtime component.** `dockpoint` is ignored
   outright, and a layout group beats `MoveTo`.
4. **Icons come out of CA's packs through RPFM, not a byte-grep.** `ui/**/*.png` is compressed
   in CA's packs, so a grep returns the path and not a usable PNG. Six guild icons plus five
   rank icons. A missing imagepath draws a blank square, silently.
5. **A build-time checker modelled on `tools/check_rite_panel_ui.py`** — component names the
   Lua reaches for, GUID hierarchy and definition pairing, root-versus-children extent, and
   visibility gates. Ten such checks each caught a fault *after* it had shipped on the last
   panel.

The panel is the largest single chunk of the build and the reason phase 1 is several sessions
rather than one.

---

## 8. Save state and multiplayer

**Save state:** one table keyed by faction key, holding per guild `{rep, favour, cooldowns}`.
Per-faction save keys, as the Exchange uses.

**Multiplayer is materially simpler here than in the Exchange.** The Exchange needed one
market shared across machines. Guilds need no shared state at all: standing is per faction,
accrual is driven by campaign events both machines observe, and nothing one player does
changes another player's numbers.

Three rules carry over unchanged:

- Forced local-faction read. An unforced `get_local_faction_name` **throws** in multiplayer,
  and a local-faction call at script root CTDs where pcall cannot catch it.
- Per-faction save keys.
- The turn round iterates `cm:get_human_factions()`.

**No `UITrigger` transport is needed** — there is no shared model to transport. That is the
single largest untested surface in the Exchange and this design does not inherit it.

The Standings league table is computed from the same save state on each machine, so it stays
in sync as long as accrual never reads anything machine-local.

---

## 9. Failure modes and guards

Five, each already established elsewhere in this workspace, each silent when unguarded.

1. **No loc calls from turn handlers.** CTD at turn 1, and pcall does not catch it. Guild
   names are loc strings and accrual runs at turn start — so **accrual stores keys and names
   resolve at draw time only**. This is the one that would bite hardest.
2. **A listener condition that errors drops with no log line.** Every condition stays trivial;
   the work happens in the handler.
3. **`cm:get_faction` returns `false`, not nil**, and `call_each` has no pcall — one bad
   faction silently kills every later listener.
4. **A null script interface exposes only `is_null_interface`.** Guard before any accessor.
5. **Duplicate key check before packing.** Mandatory; the game drops duplicates silently.

### 9.1 Build-time gates

All existing tools except the last:

- `luac -p` (Lua 5.1.5, matches the game)
- `tools/check_lua_api.py` — undocumented `cm:` / `core:` members and separator mismatches
- `tools/check_lua_undeclared.py` — ALL_CAPS globals nothing declares; the importer refuses to
  pack on a finding
- A generator `--selftest` that runs the shipped Lua under `lua.exe` against a stubbed campaign
- A new UI checker modelled on `check_rite_panel_ui.py`

None of these catch a typo'd faction, unit, region or character key. Those fail silently
forever and only an RPFM Global Search against `db/` finds them.

---

## 10. Phasing

| Phase | Content | Size |
|---|---|---|
| **1 — Chaos Dwarfs** | Save state, six tracks, ranks, 18 services, panel, AI, MCT | Several build sessions. The Exchange is the size comparison |
| **2 — Dwarfs** | Guild names, rank names, icons | Roughly one session |
| **3 — Empire** | Same | Roughly one session |

Phase 1 ships the Chaos Dwarf flavour layer **and** the generic fallback, so a non-Chaos-Dwarf
player who loads it sees plain descriptive names rather than nothing.

One Workshop page that gains races, not three pages.

---

## 11. What only a live campaign settles

Ordered by what a wrong answer costs.

| # | What | Why it is not provable offline | How to reach it |
|---|---|---|---|
| 1 | The rate curve | Whether rank 1 lands near turn 15 and Exalted near turn 100. Every number in §4 is a shape, not a measurement | A soak run to turn 100 on one faction |
| 2 | AI spending balance | Whether 15 services under a one-per-turn cap is invisible or oppressive | Long run with AI spending on versus off |
| 3 | The Khan's Price landing on the player | The feed message index chain, and whether the debuff reads as a mechanic or as a bug | Provoke an AI at Favoured rank in the Khanate |
| 4 | Bundle visibility | `is_global_effect` and the `%+n` placeholder are both silent when wrong, across 36 bundles | Buy one service of each shape and read Faction Effects |
| 5 | Multiplayer | Single-process runs cannot prove two machines agree | Two machines, two factions, compare standings at turn end |
| 6 | Panel draw | GUID pairing and `MoveTo` faults are silent non-draws that the build checker approximates but cannot confirm | Open every tab and every guild page once |

---

## 12. Not in v1

- **Rival guilds.** Raising one lowering another was considered and cut. It fights the passive
  earn loop, which rewards what the player already does rather than forcing a specialisation.
- **Exclusive top ranks.** A limited-seat contest like Tower of Zharr seats. Interesting, and
  the most that can go wrong in balance and save state.
- **Map-present chapter houses.** Guild buildings in real regions. The most invasive option to
  vanilla region data.
- **Guild units and guild buildings.** The one reward shape that needs unit art and per-culture
  rosters, which is exactly the per-race work this design exists to avoid.
- **AI use of Hobgoblin Eyes, Bound Blueprint and Raise the Ziggurat.** See §6.1.
- **More than three services per guild.** Eighteen is enough to prove the loop and few enough
  not to bury the build. Content scales after the loop is proven fun.

---

## 13. See also

- `docs/STOCK_MARKET_DESIGN.md` and `docs/ZHARR_EXCHANGE.md` — the architecture this borrows:
  save state over pooled resources, panel buttons over rituals, race profiles with a fallback
- `docs/CUSTOM_UI.md` — the panel rules in §7.1, and the GUID ledger
- `docs/RITUALS.md` §7 — the rites-panel ceilings that ruled out the free-UI route
- `docs/HELLFORGE_UNIT_CAPS.md` — the `campaign_group_pooled_resources` trap that ruled out
  pooled resources
- `docs/MISSIONS.md` §4 — the objective vocabulary, if a contract-board layer is ever added
