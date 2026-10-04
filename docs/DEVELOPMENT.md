# Development guide

How The Great Guilds works inside, how it is built and checked, and the engine behaviour
that shaped the code. For what the mod does from a player's side, see the
[README](../README.md).

This repo is mirrored from a larger modding workspace. The notes in `docs/history/` link
to reference docs in that workspace (`docs/CUSTOM_UI.md`, `docs/MISSIONS.md` and others),
which are not included here.

## 1. Shape

All the logic is Lua. The DB rows exist only because the engine needs a row to show
something: an effect bundle to apply, a mission to issue, an event-feed entry to raise.

| File | Global | Role |
|---|---|---|
| `zzz_derpy_guilds.lua` | `GG` | The model: reputation, earning, ranks, services, bounties, demands, patrons, leadership, the log, the per-source ledger, save state, the multiplayer transport. |
| `zzz_derpy_guilds_ai.lua` | `GGAI` | The AI's purchases, which go through the same `GG.buy` the player uses. |
| `zzz_derpy_guilds_ui.lua` | `GGUI` | The panel, its six tabs and the HUD opener. It reads `GG` and never writes reputation directly. |
| `zzz_derpy_guilds_bounty_data.lua` | `GG` | **Generated** by `gen_great_guilds.py --write`: the technologies a research job may name and the buildings each guild may request, per race. No script call can list either. |
| `script/mct/settings/derpy_great_guilds.lua` | none | The MCT page. It runs in MCT's own environment and cannot see `GG`. |

The code calls reputation *standing*; the player never sees that word. Reputation lives in
saved values rather than pooled resources. That keeps it culture-blind: a pooled resource
needs a row per campaign group, and a missing row fails silently.

**Coverage is the player's race, and only the eight races the mod writes guilds for**
(`GG.covered`, `GG.FLAVOURED`). Every faction of the human's culture earns, if that culture
is one of the eight. Any other culture gets nothing, not even when a human plays it: no
opener, no reputation, no messages. Before 2026-09-24 any culture a human played was
covered.

**Flavours.** Each of the eight races has a tag (`""` Chaos Dwarfs, `_emp`, `_dwf`, `_brt`,
`_cth`, `_ksl`, `_def`, `_hef`) appended to every key a player reads, and a feed offset
(0, 10, 20, 40, 50, 60, 70, 80) added to the feed indexes. A ninth, `_gen` at offset 30
(`GG.GENERIC`), is read only by a message to a human of an uncovered race whom a hostile
service hit in multiplayer. `GG.FLAVOURED` is mirrored by `FLAVOURS` in
`gen_great_guilds.py`, and `check_flavour_mirror()` refuses a mismatch.

## 2. Where reputation comes from

| Listener | Event | Pays |
|---|---|---|
| `gg_turn` | `FactionTurnStart` | Brass Tablets (from income). Also runs upkeep, cooldowns and the AI technology count; for humans, posts the bounty board, voids hero bounties whose target has gone, and runs the patron and the demand; for everyone, leadership. |
| `gg_battle` | `CharacterCompletedBattle` | Immortals, doubled when outnumbered (`pending_battle:attacker_is_stronger()`). |
| `gg_tech` | `ResearchCompleted` | Daemonsmiths, **for human factions only** (see section 7). |
| `gg_research_started` | `ResearchStarted` | Nothing. It records the current technology of a covered faction for Bound Blueprint. |
| `gg_agent_*` | `CharacterCharacterTargetAction`, `CharacterGarrisonTargetAction` | Khanate. Also counts progress on a taken hero bounty (`GG.hero_progress`). |
| `gg_building` | `BuildingCompleted` | The guild the building's chain belongs to (`GG.BUILDING_THEME`, longest token match), scaled by level. |
| `gg_sack_*` | `CharacterSackedSettlement`, `CharacterRazedSettlement` | Slavers, more for a raze. |
| `gg_mission` | `MissionSucceeded` | All six guilds, or instead the payout for a bounty mission (a bounty is not also paid the blanket rate). |
| `gg_bounty_MissionCancelled` | `MissionCancelled` | Nothing. A bounty the mod voided gets its favour stake back. |
| `gg_bounty_MissionFailed` | `MissionFailed` | A failed bounty takes back reputation (`rate_bounty_fail`), and its stake is lost. |
| `gg_character_destroyed` | `CharacterDestroyed` | Nothing. It withdraws a bounty whose target character is dead. |
| `gg_ai_turn` | `FactionTurnStart` (in `GGAI`) | Nothing. The AI's purchases, demands and patrons. |
| `gg_mp` | `UITrigger` | Nothing. The receiving end of the multiplayer transport (section 5). |

Every earn route goes through `GG.grant`, which applies the per-turn cap, the patron share
and the rivalry term, and records the amount by source in the human's ledger (the "Reputation
this turn" line; `GG.LEDGER_SOURCES`, with what the cap held back as `withheld`). Demand
rewards and bounty payouts bypass the cap on purpose.

**Bounties** are real missions, issued with `cm:trigger_custom_mission_from_string` and
tracked by the engine's own objectives: `CAPTURE_REGIONS`,
`RAZE_OR_SACK_N_DIFFERENT_SETTLEMENTS_INCLUDING` and `KILL_CHARACTER_BY_ANY_MEANS` for
military offers; `HAVE_AT_LEAST_X_MONEY`, `ACHIEVE_CHARACTER_RANK`,
`RESEARCH_N_TECHS_INCLUDING`, `CAPTURE_X_BATTLE_CAPTIVES` and `CONSTRUCT_N_OF_A_BUILDING`
for jobs and building requests. Hero bounties use a `SCRIPTED` objective (`derpy_gg_hero`)
that the mod completes itself with `cm:complete_scripted_mission_objective`, counted off
the two agent-action events. The kinds and their prices are `GG.BOUNTY_KINDS`; the design is
`docs/design/2026-09-27-great-guilds-bounties-v2-design.md`.

**Rival bounties.** Every covered AI faction holds one bounty at a time, under the same
price, stake and failure rules as the player's. The mod scores it itself, because no engine
mission is issued for the AI. A rival's targets are on its own front, and a bounty on a
human's land warns them with a transient located feed message (index 5005). The MCT switch is
`ai_bounties`. Design: `docs/design/2026-09-29-great-guilds-ai-bounties-design.md`.

**Services and cards.** `GG.SERVICES` has 83 rows. It is append-only, because cooldowns are
saved by position (section 3). Each guild shows one card at each of ranks 2, 3 and 4
(`GG.CARD_RANKS`), drawn from that guild-and-rank pool by `GG.draw_cards`. Cards are drawn in
a fixed order, one `GG.roll` each, so every machine draws the same cards. A card never shows
its last service again when the pool has another. `GG.rotate_cards` redraws every
`rotate_turns` turns (MCT, default 10) and posts feed index 5006. `GG.pool_ok` refuses three
kinds of row:

- a hostile row while `hostile_services` is off;
- a row whose `needs` check fails;
- a row tagged `race = <culture>` for any other race.

Twenty-nine rows are race services. `GG.show_race_service` keeps at least one on show each
period.

**Race differences** (MCT `race_differences`, on by default) gate three things beyond the race
services:

- **An earn route of its own** (`GG.EARN_ROUTES` / `GG.EARN_OF`). Examples: caravans for
  Chaos Dwarfs and Cathay, grudges for Dwarfs, captives for Dark Elves.
- **A twist** that bends one rule as a whole percentage (`GG.TWISTS`). Examples: Kislev's
  upkeep at 50%, the High Elves' favour cap at 150%.
- **A Help page** naming the race's route and twist.

Design: `docs/design/2026-09-29-great-guilds-service-pools-and-races-design.md`.

Default rates (every one can be changed through MCT's Custom preset):

| Guild | Rate | Per-turn cap |
|---|---|---|
| Brass Tablets | 1 per 250 net income | 40 |
| Immortals | 15 per battle won, x2 outnumbered | 60 |
| Daemonsmiths | 60 per technology | none |
| Khanate | 8 per agent action | 40 |
| Overseers | 10 x building level | 40 |
| Slavers | 25 per sack, more per raze | 80 |
| All six | 10 per mission completed | - |

## 3. Save state

All keys are `cm:set_saved_value` strings.

| Key | Holds |
|---|---|
| `derpy_gg_<faction>` | six `rep,fav` pairs in `GG.GUILDS` order (brass, immortals, daemonsmiths, khanate, overseers, slavers), then `;`, then one cooldown per `GG.SERVICES` row, by position |
| `derpy_gg_cards_<faction>` | the service cards on show: `<turn drawn>;<key>,<key>,...`. Keys, not indexes, so a key survives the table growing; a key this build does not sell reads as its slot's default |
| `derpy_gg_gain_<faction>` | what each guild has paid since the faction's last turn start (`guild=n,...`), so saving and reloading cannot earn a turn's limit twice |
| `derpy_gg_carry_<faction>_<route>` | the remainder of a points-based race route (one per `per`) not yet paid out |
| `derpy_gg_world` | the leadership table: `turn|...;culture/guild,rep,margin,leader,flag|...` |
| `derpy_gg_bounties_<faction>` | the bounty board, offers joined by `;`. Five fields (`war`, `stake`, `amount`, `done`, `void`) were appended on 2026-09-27; an older save reads them as zero |
| `derpy_gg_demand_<faction>` | the open demand |
| `derpy_gg_patron_<faction>` | the appointed patron |
| `derpy_gg_research_<faction>` | the technology in progress, for Bound Blueprint |
| `derpy_gg_techs_<faction>` | the AI's completed-technology count (the first read is a baseline, not income) |
| `derpy_gg_earned_<faction>` | the ledger behind "Reputation this turn": this turn's and last turn's grants by guild and source, humans only |
| `derpy_gg_log_<faction>` | the Log: `turn,kind,guild,a,b` joined by `|`, newest first, 100 entries, humans only |
| `derpy_gg_best_<guild>_<faction>` | the highest rank reached, so a promotion message fires only the first time |
| `derpy_gg_notice_<tag>_<faction>` | a one-time notice (`first`, `half`) has fired |
| `derpy_gg_ai_last_<faction>` | the service this AI bought last, so it does not buy it twice running |
| `derpy_gg_tuned` | the MCT values. Single player freezes them at the first tick; multiplayer freezes the host's when the last part arrives (section 7) |

Rank bundles are **not** tracked in the save. On every load, the first turn start
re-applies each guild's current rank bundle once (`GG.assert_ranks`). That is what lets the
mod join a campaign already in progress, or heal a save written by a build that never
applied a bundle.

## 4. Keys the engine reads

`<tag>` is the flavour tag of section 1: empty for Chaos Dwarfs.

| Kind | Key |
|---|---|
| Rank bundle | `derpy_gg_rank_<guild>_<rank><tag>`, ranks 2-5 (rank 1 grants nothing) |
| Leader bundle | `derpy_gg_lead_<guild><tag>`, swept per culture so two races can each have a leader |
| Service bundle | `derpy_gg_svc_<service><tag>`, with the service's duration. The BUYER's tag, even on a hostile service's target, so the victim reads who did it |
| Patron bundle | `derpy_gg_patron`, applied to a force, untagged |
| Bounty mission | `derpy_gg_<family>_<guild><tag>`, family `bounty`, `job`, `build` or `hero`; one live mission per key per faction |
| Building-card line | `derpy_gg_built_<guild><tag>`, a dummy effect on every building level that pays that guild |
| Feed messages | `message_event_text_text_derpy_gg_<stem>_title` / `_primary` / `_secondary` |
| Feed indexes | 5001 hostile hit, 5002 demand, 5003 leadership, 5004 rank, 5005 a rival's bounty on your land (transient, located), 5006 services changed, each plus the receiver's flavour offset (`GG.feed`) |
| Panel text | `derpy_gg_<key>`, resolved by `GGUI.loc` at draw time |

The DB side is ten tables plus the loc. Row counts as of build BB204325:

| Table | Rows | Why |
|---|---|---|
| `effect_bundles` | 690 | rank 216, leader 54, service 419, patron 1 |
| `effect_bundles_to_effects_junctions` | 756 | |
| `effects` | 49 | the building-card lines, six guilds by eight races, plus one Kislev war-machine effect |
| `effect_bonus_value_ids_unit_sets` | 2 | that effect's two bonus values, bound to CA's `ksl_war_sleds_little_grom` unit set (Kislev's artillery) |
| `building_effects_junction` | 1,726 | one per building level that pays a guild. `gen_great_guilds.py` runs the Lua's own building-to-guild matching and refuses a line that names a different guild than the one paid |
| `missions` | 171 | 19 guild-and-family pairs by nine flavours |
| `event_feed_message_events` | 54 | six indexes by nine offsets |
| `campaign_groups`, `campaign_group_members`, `campaign_group_member_criteria_values` | 54 each | only to make the feed indexes resolve (section 7) |

## 5. The panel

The panel is **our own `.twui.xml`, created at runtime**. No CA layout is overridden.

- `tools/gen_guilds_ui.py` writes all six layouts from coordinate tables. GUIDs are
  deterministic per component name, in the `GG21` prefix.
- The engine ignores `dockpoint` on a runtime-created component. `GGUI` positions
  everything with `MoveTo`, which is why the layout files carry no offsets and a plain
  viewer stacks the panel in one corner.
- The tabs, in screen order: Guilds, Leaderboard, Bounties, Court, Log, Help. The code
  still calls the Leaderboard `standings`. The Help and Log tabs share 21 text slots
  (`gg_help_01`..`gg_help_21`) and one pager.
- The frames are CA's own art, referenced by path where the game already ships it. The
  Chaos Dwarfs use the Hell-Forge's header bar, card frames, price plates and square tabs,
  and the Tower of Zharr's glow round a card whose service is running (`GGUI.CARD_RIM`).
  That glow and the selected-guild marker `gg_gsel` breathe with CA's `glow_pulse_t0`
  shader, using values copied from CA's own Tower of Zharr and Hell-Forge panels. The shader
  sits on the image slot, so it survives `GGUI.light_card` swapping the art in with
  `SetImagePath`. A slot holding the clear image pulses nothing.
- The header strip is two cells: `gg_rank_line` holds the heading at 18pt, and
  `gg_rank_stats` holds the figures at 12pt, right-aligned. Its inset is set per race
  (`RANK_STATS_PAD`), because each race's bar ends in its own ornament.
- Locked services read as CA's padlock and "Needs Sworn" (or whichever rank). Text carries the state, not
  colour, because red measured 2.2:1 on the card bronze and CA's orange 4.4:1. The faction
  list uses CA's whole event-message slider (`ca_vslider`), whose caps and arrows are
  `MoveTo`'d by `GGUI.SLIDER_PARTS`.
  Each other race has its own panel and card file, built from its own culture's art in
  `gen_guilds_ui.FRAMES` and mirrored into `GGUI.FRAME`. Pieces are drawn at or near their
  native size, since a nine-slice stretched far past its file blurs, and `tile="true"`
  repeats a texture rather than scaling it. The guild-button bar is 438 wide at x=176 for
  every race so no end ornament sits under a button.
- The panel ground is image index 1 of five on the panel component (tile, art, smoke,
  scrim, border), and is repainted per guild and per race. The grounds are dimmed until they
  measure what CA's own `tier_01` ground measures under the scrim, so text keeps its contrast.
  The Chaos Dwarfs and Dwarfs have one painting per guild; the other races use six crops of
  one loading-screen painting each.
- The ground layers are inset 4px, because `panel_back_border.png` is transparent for its
  outer 3px; drawn to the edge, the picture showed outside the frame.
- The drifting smoke is CA's main-menu shader, `smoke_overlay_t0`, on
  `panel_back_smoke.png` at `2.00,10.00` and alpha `3C`. The shader is undocumented, so
  those values are copied from CA's own panels.
- **Scale.** `GGUI.scale_for` sizes the panel by `min(w/1920, h/1080)`, never below 1, so it
  grows at 1440p and 4K and is unchanged at 1080p. The screen a script reads is already
  divided by the game's UI Scale, so that setting still applies on top.
- The opener is a crest button parented to the HUD, off the right end of the top resource
  bar. It sits left of the Zharr Exchange's button when that mod is present, and takes the
  Exchange's slot otherwise (`GGUI.btn_anchor`, checked by `check_guilds_anchor.py`). The
  bar grows and shrinks as effects come and go, with no event for it, so a 300ms real-time
  poll (`gg_follow_bar`) moves the button when the anchor changes. Placement retries every
  2 seconds for up to 5 minutes (`GGUI.BTN_TRIES = 150`), because a long campaign intro
  keeps the bar off-screen that long.
- **Multiplayer.** Every panel action goes out as a `UITrigger` (the `gg1` transport,
  `GG.mp_send`) and is applied on every machine by `gg_mp`. Nothing in the panel writes
  the model directly.

## 6. Build pipeline

Run everything from the repo root.

| Step | Command | Notes |
|---|---|---|
| Parse | `luac -p <file>` for the four scripts | Lua 5.1.5 |
| Test | `lua tools/_guilds_harness.lua` | Runs the shipped Lua against a stubbed campaign and panel. Prints `harness ok`. |
| Bounties | `lua tools/_guilds_bounty_harness.lua` | The bounty board against a stubbed world. Prints `bounty harness ok`. |
| Mutation | `py tools/mutate_guilds.py` | Breaks the rules 174 ways, one at a time, in the shipped Lua; a harness must fail on each. Restores the file byte for byte. A mutant whose anchor no longer matches is reported, not skipped. |
| Opener maths | `py tools/check_guilds_anchor.py` | Extracts `GGUI.btn_anchor` from the shipped script and runs it against measured HUD geometry. |
| Data | `py tools/gen_great_guilds.py --check`, then `--write` | Builds every DB row and loc line, and `zzz_derpy_guilds_bounty_data.lua`, and refuses on a broken rule (below). |
| Layouts | `py tools/gen_guilds_ui.py --check`, then `--write` | Its XML emitter is `gen_guilds_emitter.py`, a deliberate copy of the Zharr Exchange's, so a fix made here cannot change that mod's output. |
| Layout vs Lua | `py tools/check_guilds_ui.py` | Every component name the Lua reaches for exists; GUID pairing is intact. |
| Look | `py tools/preview_guilds_panel.py` | Renders all six tabs to PNGs with the game shut, using TWUI Studio's modules (not included). It draws from the shipped Lua: `GG_DUMP=<dir> lua tools/_guilds_harness.lua` opens the real panel over a demo save and writes where the script moved, sized, wrote and hid every part. Without that, a preview of the layout alone stacks the panel in one corner. `GG_DUMP_TAG=_emp` (etc.) dumps a race. Exits 1 on low contrast or on text wider than its box. Glyph widths are approximate; positions are exact. |
| Art | `py tools/make_guild_icons.py`, `py tools/make_guild_backgrounds.py`, `py tools/make_guild_bundle_icons.py` | Icons are recoloured CA building icons; grounds are cropped and dimmed; effect-bundle icons put the guild's mark on the teal disc recovered from CA's own effect icons. `--check` re-measures what ships. **Neither the inputs nor the outputs are in this repo** (they are CA-derived); extract the sources from your own game install. |
| Pack | `py tools/import_great_guilds.py` | Needs RPFM's MCP server. Refuses if the TSVs disagree with `build()`, packs, saves, then re-opens the saved pack and counts every table's rows. `--verify-only` re-checks a saved pack. |

The generators, `check_guilds_ui.py`, the preview, `mutate_guilds.py` and the three art tools
take `--selftest`, which breaks something on purpose and proves the check still reports it.

What `gen_great_guilds.py --check` refuses on, among others: an effect value whose sign
fights `is_positive_value_good`; an effect key vanilla does not have, or a scope vanilla never
pairs it with; a value more than 1.5x the largest magnitude vanilla puts on that effect and
scope; a feed index that collides with vanilla's or disagrees with the Lua; an event picture no
vanilla row uses; a Help page over its 21 lines; a message title that names a guild without
its article; a building-theme token with Lua pattern magic in it, or one matching no CA
chain; a hire unit that is not a real vanilla key; a building-card line that names a
different guild than the Lua pays; a `GG.FLAVOURED` entry that disagrees with the
generator's; a bounty technology or building a player cannot reach; any key this pack names
that the installed game does not have (`check_live_references`, added after patch 9.0
removed a building the pack still named, which drops the whole pack at load).

Most data checks read a dump of vanilla tables in `.skilltree_cache/` (RPFM's JSON export);
the building, bounty and live-reference checks read the installed game's `db.pack` through
`read_vanilla_db.py`, and the unit names through `read_vanilla_loc.py`. Neither the dump nor
the game data is in this repo.

**Deploying:** copy the saved pack into `data/` **with the game closed**. The game holds its
packs open, and overwriting one under it causes crashes that cannot be traced. Keep the
previous pack as a backup and compare MD5s on both sides. A pack new to `data/` starts
disabled, so tick it in the launcher.

## 7. Engine behaviour that shaped the code

Each of these cost a bug or a build to learn. Most fail silently.

- **`BuildingCompleted` has no `faction()`.** Its only accessors are `building` and
  `garrison_residence`. Reading `context:faction()` inside a `pcall` returned nil for every
  building for thirteen days, and every check stayed green because the test stub offered a
  `faction()` the engine does not. The harness's fake events now carry exactly the
  documented accessors and nothing more.
- **`ResearchCompleted` never reaches AI factions.** This was proved from the save: only the
  human ever had a research key. The AI is paid by counting
  `faction:num_completed_technologies()` at its turn start instead. The first count is a
  baseline; otherwise the first turn after an update would pay every AI for every
  technology it owns.
- **No loc calls from turn handlers.** Resolving a localised string from a
  `FactionTurnStart` handler crashed the game at turn 1, and `pcall` does not catch it. The
  model stores keys only; the panel resolves names at draw time.
- **A `pcall` turns a missing member into a permanent silent nil.** So does a listener
  condition that errors. Check CA's `scripting_doc.html` for an event's accessors before
  reading any of them.
- **`cm:get_faction` returns `false`, not nil,** for a key it does not know.
- **Lua numbers are single-precision floats.** `1.05` is `1.0499999523163`, so a `.5`
  rounding boundary can fall the other way.
- **`cm:show_message_event`'s last argument is an index**, resolved through
  `event_feed_message_events` -> `campaign_groups` -> `campaign_group_members` ->
  `campaign_group_member_criteria_values`. Miss one and the log says the event was shown,
  and nothing is drawn.
- **An event picture no vanilla row uses draws a black rectangle.** The `image` column is a
  path fragment, not a foreign key, so nothing rejects it. Chaos Dwarfs have no
  `chd/generic` feed picture.
- **Effect bundle and mission titles come from loc keys** (`effect_bundles_localised_title_*`,
  the mission's loc), not from the row's own text columns. A bundle with correct row text
  and no loc draws with no title.
- **`cm:apply_effect_bundle(key, faction, -1)` is indefinite; `0` applies nothing,** for
  zero turns, silently.
- **Cost effects are signed backwards.** `is_positive_value_good` is false on every cost
  modifier, so `-10` is a discount. A hostile bundle on an enemy inverts it again.
- **MCT has no campaign gating.** Its context-specific setting is an empty function body.
  The mod snapshots every value into `derpy_gg_tuned` once and ignores later changes. It
  used to snapshot at the first `FactionTurnStart`, which comes after turn 1 has been
  played, so turn 1 ran on the defaults; it now snapshots at the first tick, by which time
  MCT's own `LoadingGame` handler has read the player's values.
- **MCT is local to each machine.** In multiplayer each machine reading its own would freeze
  a different economy into each copy of the save. Only the host
  (`core:svr_load_bool("mct_local_is_host")`, the flag MCT itself reads) sends its values,
  as `tune` messages of at most 100 characters each, the limit MCT's own multiplayer code
  works to. Every machine plays the defaults until the last part arrives, then freezes.
- **A tooltip on a non-interactive component is never shown.** The panel's tooltips were
  invisible until `set_tooltip` began calling `SetInteractive(true)`.
- **The game's `string.find` is not stock Lua.** An `init` argument makes it silently find
  nothing, and the `plain` flag corrupts the string library for every script until the
  game restarts. The harness runs on stock Lua and passes over both, so neither argument
  appears in the scripts.
- **Lua 5.1 allows 200 locals per function.** The harness's main chunk is near that
  ceiling, so new tests go inside `;(function() ... end)()`.

## 8. Where the design lives

- [docs/design/2026-09-10-great-guilds-design.md](design/2026-09-10-great-guilds-design.md):
  the original design. Parts are superseded: reputation now falls as well as rises, eight
  races take part rather than any culture, and the bounty rules are the v2 spec's.
- [docs/design/2026-09-23-great-guilds-flavours-design.md](design/2026-09-23-great-guilds-flavours-design.md):
  Empire and Dwarf versions of the guilds, and the tag and feed-offset machinery every
  later race reuses. Built 2026-09-23.
- [docs/design/2026-09-24-great-guilds-brt-cth-ksl-design.md](design/2026-09-24-great-guilds-brt-cth-ksl-design.md)
  and [docs/design/2026-09-24-great-guilds-def-hef-design.md](design/2026-09-24-great-guilds-def-hef-design.md):
  Bretonnia, Cathay, Kislev, Dark Elves and High Elves. Data only; built 2026-09-24.
- [docs/design/2026-09-27-great-guilds-bounties-v2-design.md](design/2026-09-27-great-guilds-bounties-v2-design.md):
  bounties that cost a choice (far enemies, new wars, the favour stake, jobs, building
  requests, hero bounties). Built 2026-09-27.
- [docs/design/2026-09-29-great-guilds-ai-bounties-design.md](design/2026-09-29-great-guilds-ai-bounties-design.md):
  rivals of your race take bounties too. Built 2026-09-29.
- [docs/design/2026-09-29-great-guilds-service-pools-and-races-design.md](design/2026-09-29-great-guilds-service-pools-and-races-design.md):
  service pools and rotating cards, then each race's own services, earn route and twist.
  Built 2026-09-29 in two stages.
- `docs/plans/`: the plans the ladder, panel, AI, notices, flavours, bounties v2, AI
  bounties and service pools were built from.
- `docs/history/`: dated handoffs, the most recent last. When a handoff and the code
  disagree, the code wins.
