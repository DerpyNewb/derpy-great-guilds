# The Great Guilds: the Skaven (a ninth race) - design

**Status:** approved in conversation, section by section, on 2026-10-05; this file awaits the
author's review. Not built.

**Builds on:**
- `2026-09-23-great-guilds-flavours-design.md`, the flavour model;
- `2026-09-29-great-guilds-service-pools-and-races-design.md`, race services, earn routes and twists;
- `2026-10-04-great-guilds-halls-design.md`, halls;
- `2026-10-04-great-guilds-temple-guild-design.md`, the seventh guild.

## 1. What and why

The Great Guilds covers eight races. The temple spec deferred the Skaven "as its own project".
This is that project.

The Skaven have the strongest lore basis of any race left out: the Great Clans already are the
Under-Empire's guilds. That passes the lore-over-coverage rule.

| Decision | Ruling |
|---|---|
| Scope | Full parity with the other eight races, in ONE build: seven guilds, panel and card frame, art, building words, temple routes, halls, race services, earn route and twist |
| Approach | The proven recipe: hand-written Skaven data in every place a race is declared (§9 lists them), plus three Skaven-only code paths (§4). No generalising of the other eight races' lists |
| Tag and culture | `_skv`, `wh2_main_skv_skaven` |
| Placement | `_skv` goes before `_gen` in `FLAVOURS`, so `_gen` stays last. Feed offset 90 (5091-5096) |

**Not in scope:**
- a tenth race;
- generalising the hard-coded race lists;
- Skaven-only services beyond the three in §5;
- the public GitHub repo sync.

## 2. Identity

| Key | Skaven guild | Rival (unchanged pairs) | Earns from (unchanged) |
|---|---|---|---|
| brass | The Warpstone Traders | Clan Eshin | income every turn |
| immortals | The Stormvermin | Clan Skryre | battles won |
| daemonsmiths | Clan Skryre | The Stormvermin | technologies |
| khanate | Clan Eshin | The Warpstone Traders | successful hero actions |
| overseers | Clan Moulder | The Slave-Masters | settlements growing, buildings |
| slavers | The Slave-Masters | Clan Moulder | sacking and razing |
| temple | The Grey Seers | none | §3.2 |

- **Ranks:** Skavenslave, Clanrat, Clawleader, Chieftain, Warlord.
- **Name limits:** every name stays within `GUILD_NAME_MAX` 22 and `RANK_NAME_MAX` 12.
- **Clan Pestilens** gets no guild. The Grey Seers hold the faith-and-magic slot, by the author's ruling.

**Twist, "Treachery":** earning with a guild takes half again as much from its rival, and a demand
you let expire costs nothing. Both are existing dials, so no new code path:
`GG.TWISTS["wh2_main_skv_skaven"] = {rate_rivalry = 150, demand_penalty = 0}`. It is distinct
from the Dark Elf twist, which pairs rivalry with cheaper hostile services.

No race uses a 0 percentage yet. The plan confirms that `GG.twist`'s consumers and the
generator's twist checks accept 0, and pins it with the bounty harness case in §9.

**Earn route, "under-cities":** founding an under-city beneath another faction's settlement pays
Clan Eshin 40 Reputation (§4.2). Under-cities are infiltration, which is Eshin's trade.

## 3. Earning

### 3.1 Buildings

- **Race words.** `GG.BUILDING_THEME_RACE["_skv"]` covers the Skaven set `wh2_main_bas_skv`
  (115 chains in `db.pack`) and the clan factions' own sets (§10 item 2). It is mirrored and
  checked as for every race: each token must match a Skaven chain and nothing else's.
- **Under-city buildings** pay their guild by the same words (§4.3). Without this, a Skaven
  player's under-city construction would pay no guild, because it does not fire the ordinary
  building-completed event.

### 3.2 The Grey Seers' routes

| Route | Skaven rule |
|---|---|
| Priests | A successful action by a Grey Seer HERO subtype pays the Seers instead of Clan Eshin. If §10 item 1 finds the Grey Seer is a lord only (as in TW:W2), the route is DROPPED, not given to another unit, and the handoff says so |
| Holy war | Wins against `wh_main_dwf_dwarfs` and `wh2_main_lzd_lizardmen` (keys verified at plan time) |
| Taint (new, §4.1) | `rate_temple_taint` (default 2) per province carrying `wh3_main_corruption_skaven` above 0 |
| Devout | not used |
| Holding back Chaos | not used |

- Every route goes through `GG.capped_grant` and `cap_temple`.
- The taint route is also previewed in `GG.turn_start_pay`, so the lead hold sees it. This follows
  the 2026-10-05 fix that made the hold see the temple's turn-start routes.
- New ledger sources: `taint` and `undercity`.

## 4. The three new code paths

All three are pcall-wrapped like every listener. Each gets a harness case and a mutant.

1. **Taint.** `GG.temple_counts` gains a `taint` flag. With it, a province counts when it holds
   `wh3_main_corruption_skaven` above 0. It uses the same province walk and the same
   pooled-resource read as the chaos route. `GG.TEMPLE_ROUTES` gains `taint = true` for the Skaven,
   and the generator's mirror gains the flag.
2. **Under-city founding.** A listener on `ForeignSlotManagerCreatedEvent` pays the founding
   faction through the existing race earn-route pattern. That means a
   `GG.EARN_ROUTES.undercity = {guild = "khanate", rep = 40}` row (a fixed guild and amount, like
   `caravan` and `motherland`; earn routes have no MCT rate), `GG.EARN_OF`, ledger source
   `undercity`, and the `derpy_gg_log_earn_undercity_skv` loc.
3. **Under-city buildings.** A listener on `ForeignSlotBuildingCompleteEvent` calls the existing
   `GG.on_building` with the completed building's chain and the slot owner's faction. The context
   fields that name the faction and the building are confirmed with
   `check_lua_api.py --explain` (§10 item 5). If the event exposes no building key, this path is
   dropped and the handoff says so.

## 5. Race services

There are three, priced by `RACE_PRICE`: 50/150/400 favour, cooldowns 8/12/16, rank 4 `lead`.
They are appended AFTER the temple's nine rows, because cooldowns are saved by position. The
harness pin moves from "temple rows last" to "Skaven rows last".

| Rank | Guild | Key | Name | Kind | Effect |
|---|---|---|---|---|---|
| 2 | slavers | `food_tithe` | Food Tithe | resource | adds Food; amount set against CA's own Food payloads (§10 item 4) |
| 3 | khanate | `menace_below` | The Menace Below | race | adds a Menace Below charge, if the charges are a resource a script can add to. Otherwise an Eshin alternative chosen at plan time from documented calls, and ledgered as a ruling |
| 4 | overseers | `breeding_season` | Breeding Season | bundle, lead | Food every turn for 10 turns, the shape of the Dark Elf `black_ark_tithe` |

## 6. The hall

The Skaven are added to `HALL_TAGS` / `GG.HALL_TAGS` and `HALL_RACES["_skv"]`:
- **`set`:** `wh2_main_bas_skv`.
- **`extra_sets`:** the clan factions' own sets.
- **Nouns:** Den / Warren / Nest.
- **Grey Seer halls (`temple_nouns`):** Horned Shrine / Temple of the Horned Rat / Spire of the Seers.
- **AI donor:** the existing rule.

| Guild | Hall unit (key verified at plan time; `_unit_level` decides the level) |
|---|---|
| Warpstone Traders | Skavenslaves |
| Stormvermin | Stormvermin |
| Clan Skryre | Warpfire Thrower weapon team |
| Clan Eshin | Gutter Runners |
| Clan Moulder | Rat Ogres |
| Slave-Masters | Clanrats |
| Grey Seers | no unit. Amended 2026-10-05 at plan time: the Grey Seer is a lord in every faction (no hero cap to raise) and the Screaming Bell is only a lord's mount, so the hall spreads Skaven corruption instead, `wh3_main_effect_corruption_skaven_buildings` at `region_to_region_own`, +2/+4/+6, the Empire College's shape (`HALL_EXTRA`) |

Hall icons: seven, from CA's Skaven building icons.

## 7. Panel, art and text

- **Frame.** A `FRAMES["_skv"]` / `GGUI.FRAME["_skv"]` entry from CA's Skaven skin art: card, heat,
  rim, holder, cost, rank, bar, four tab states, track, fill.
  - Briefed against a named CA Skaven panel and a reference screenshot, per `docs/CUSTOM_UI.md`
    "Design direction".
  - `RANK_STATS_PAD["_skv"]` and `GGUI.HALLS_IN_HEADER` are decided by the preview.
- **Crests.** Eight from CA's Skaven building icons, the seven guilds plus the race crest, each
  measured flat before it is picked.
- **Grounds.** Seven windows of `ui/loading_ui/load_images/campaign_skaven1.png`, dimmed to the
  panel's measured ceiling. `campaign_skaven_clan_scruten1.png` is the spare if a window crops
  badly.
- **Text, every string the other races carry:**
  - names;
  - descriptions;
  - the 63 shared and 3 race service names, with blurbs;
  - bounties;
  - earn and twist lines;
  - the help pages, including the halls page;
  - the ledger sources;
  - MCT names.

  Plain words, Reputation and Favour, no jargon.
- **Previews:** the Guilds tab on guild 1 and on the Grey Seers (page 7), the standings, the Court and
  Help, rendered from the shipped Lua and compared with the reference. Contrast and fit checks
  green.

## 8. Save safety and AI

- A campaign already running with a Skaven human starts its Skaven factions blank (0/0 on every
  guild), the path `GG.load` takes for any new faction. Nothing else in the save changes shape.
- `_gen` stays last, so `GG.GENERIC` (30) and every other feed slot are unchanged.
- AI Skaven earn only when a Skaven human plays (`GG.covered`). AI buying needs no code: weights come
  from cost.
- A new MCT key, `rate_temple_taint`, is appended to `GG.TUNE_ORDER` and named in all four
  presets. A frozen tune string reads the default. The under-city route has no MCT key, like every
  race earn route.

## 9. Tests

Nothing ships until all are green.

- **Generator `--check` and `--selftest`.**
  - Every eight-race pin moves to nine; each is counted, not loosened.
  - These mirrors gain the Skaven: `check_race_mirror`, `check_hire_units`, `check_frame_mirror`,
    `check_hall_mirror`, `check_temple_routes` and `check_flavour_mirror`.
  - New checks: every Skaven key is read from `db.pack`; the taint key exists; the race words
    match Skaven chains only.
- **Harness, `_guilds_harness.lua`:**
  - taint pays per tainted province and nothing for a clean one;
  - a founded under-city pays Clan Eshin 40, and nothing for a non-Skaven founder;
  - an under-city building pays its guild by race words;
  - the priests route pays, or is proven absent;
  - the turn-start preview includes taint.
- **Bounty harness, `_guilds_bounty_harness.lua`:** Treachery's two dials, an expired Skaven demand
  costing 0, and the Skaven entry in the twist table.
- **`mutate_guilds.py`:** a mutant per new rule; the full run with no survivor and no stale anchor.
- **Build:**
  - `import_great_guilds.py --check`, then the build;
  - the saved pack verified;
  - a backup to `Modding Files/Backup/`;
  - a deploy to `data/` with the game shut;
  - an MD5 compare.

**In game after the build:**
1. The Skaven panel opens with its frame.
2. Founding an under-city pays.
3. An under-city building pays its guild.
4. A Grey Seer action pays the Seers, if the route stands.
5. Taint income shows on the earnings sheet.
6. A Skaven hall builds.
7. A save from before the update loads.

## 10. To read before writing (plan-time checks)

1. **The Grey Seer agent type.** Which of `wh2_main_skv_grey_seer_plague`,
   `wh2_main_skv_grey_seer_ruin` and `wh3_dlc29_skv_schemer_grey_seer` are heroes. Lord-only drops
   the priests route.
2. **The clan factions' availability sets.** Pestilens, Skryre, Eshin, Moulder, Rictus and any
   other playable Skaven faction, checked against `covered_chains`'s one-race rule.
3. **Unit keys** for the seven hall units, and `_unit_level` for each in its set.
4. **The Food pooled-resource key** and CA's own Food payload sizes; whether Menace Below charges
   are a resource a script can add to.
5. **The context fields** of `ForeignSlotManagerCreatedEvent` and `ForeignSlotBuildingCompleteEvent`
   (`check_lua_api.py --explain`): the founding faction, and the building and its owner.
6. **A Grey Seer capacity effect key** at the Empire's scope, or its absence.
7. **The holy-war culture keys** for the Dwarfs and the Lizardmen.
8. **CA's Skaven skin art** under `ui/skins/` for the frame, and the reference panel.
9. **CA's Skaven building icon stems** for the crests and hall icons.
10. **Every race-word token** against `building_levels` for the Skaven sets, and the share table
    after.

## 11. As shipped (2026-10-05)

Build 7F7423DC; the full record is `docs/sessions/HANDOFF_20261005_GUILDS_SKAVEN.md`. Where it differs from this spec:

- **Three guild names.** The Skryre Warlocks, The Eshin Assassins and The Moulder Breeders replace Clan Skryre, Clan Eshin and Clan Moulder. Every sentence is built as "the {guild}", and "the Clan Eshin" reads wrong. The clans keep their names in the prose.
- **Priests route dropped** (§3.2's fallback): every Grey Seer subtype is a lord.
- **The Menace Below** is not a resource, so the rank-3 Eshin service is Shadows of Eshin: Gutter Runners and Night Runners.
- **The Seers' hall** has no unit. It carries Skaven corruption +2/+4/+6.
- **Temple Bribes** adds +5 Skaven corruption for the Skaven (CA's own pair) instead of reducing corruption.
- **Allied outposts** fire the founding event too. They are refused through `is_allied()` (final review).
- **Treachery's texts:** every line that said an expired demand costs Reputation branches for the Skaven (final review).
- **The frame:** Chaotic Plans plus Ikit Claw's workshop (tabs, bar). The plan's narrative tabs were red/purple and the Chaotic Plans bars are vertical. Judged by measurement; not yet viewed.
- **Open:** six in-game checks (§9; the priests check is moot) and three deferred minors.
