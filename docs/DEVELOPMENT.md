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
| `zzz_derpy_guilds.lua` | `GG` | The model: standing, earning, ranks, services, bounties, demands, patrons, leadership, the log, save state. |
| `zzz_derpy_guilds_ai.lua` | `GGAI` | The AI's purchases, which go through the same `GG.buy` the player uses. |
| `zzz_derpy_guilds_ui.lua` | `GGUI` | The panel, its six tabs and the HUD opener. It reads `GG` and never writes standing directly. |
| `script/mct/settings/derpy_great_guilds.lua` | none | The MCT page. It runs in MCT's own environment and cannot see `GG`. |

Standing lives in saved values rather than pooled resources. That keeps it culture-blind:
a pooled resource needs a row per campaign group, and a missing row fails silently.

**Coverage is the player's culture** (`GG.covered`). Every faction of that culture earns,
and nobody else does. The culture is read off the human faction at runtime, so a culture
added by another mod is covered as soon as somebody plays it.

## 2. Where standing comes from

| Listener | Event | Pays |
|---|---|---|
| `gg_turn` | `FactionTurnStart` | Brass Tablets (from income). Also runs upkeep, cooldowns, the AI technology count, bounties, patrons, demands and leadership. |
| `gg_battle` | `CharacterCompletedBattle` | Immortals, doubled when outnumbered. |
| `gg_tech` | `ResearchCompleted` | Daemonsmiths, **for human factions only** (see section 7). |
| `gg_research_started` | `ResearchStarted` | Nothing. It records the human's current technology for Bound Blueprint. |
| `gg_agent_*` | `CharacterCharacterTargetAction`, `CharacterGarrisonTargetAction` | Khanate. |
| `gg_building` | `BuildingCompleted` | The guild the building's chain belongs to (`GG.BUILDING_THEME`, longest token match), scaled by level. |
| `gg_sack_*` | `CharacterSackedSettlement`, `CharacterRazedSettlement` | Slavers, more for a raze. |
| `gg_mission` | `MissionSucceeded` | All six guilds, plus the payout for a bounty mission. |
| `gg_bounty_*` | `MissionFailed`, `MissionCancelled` | A failed bounty takes back what finishing it would have paid. |
| `gg_character_destroyed` | `CharacterDestroyed` | Nothing. It withdraws a bounty whose target lord is dead. |

Every earn route goes through `GG.grant`, which applies the per-turn cap, the patron share
and the rivalry term. Demand rewards and bounty payouts bypass the cap on purpose.

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
| `derpy_gg_<faction>` | six `rep,fav` pairs in `GG.GUILDS` order (brass, immortals, daemonsmiths, khanate, overseers, slavers), then `;`, then 18 cooldowns in `GG.SERVICES` order |
| `derpy_gg_world` | the leadership table: `turn|...;culture/guild,rep,margin,leader,flag|...` |
| `derpy_gg_bounties_<faction>` | the bounty board |
| `derpy_gg_demand_<faction>` | the open demand |
| `derpy_gg_patron_<faction>` | the appointed patron |
| `derpy_gg_research_<faction>` | the human's technology in progress |
| `derpy_gg_techs_<faction>` | the AI's completed-technology count (the first read is a baseline, not income) |
| `derpy_gg_log_<faction>` | the Log: `turn,kind,guild,a,b` joined by `|`, newest first, 100 entries, humans only |
| `derpy_gg_tuned` | the MCT values, frozen at the first turn of a campaign |

Rank bundles are **not** tracked in the save. On every load, the first turn start
re-applies each guild's current rank bundle once (`GG.assert_ranks`). That is what lets the
mod join a campaign already in progress, or heal a save written by a build that never
applied a bundle.

## 4. Keys the engine reads

| Kind | Key |
|---|---|
| Rank bundle | `derpy_gg_rank_<guild>_<rank>`, ranks 2-5 (rank 1 grants nothing) |
| Leader bundle | `derpy_gg_lead_<guild>`, swept per culture so two races can each have a leader |
| Service bundle | `derpy_gg_svc_<service>`, with the service's duration |
| Patron bundle | `derpy_gg_patron`, applied to a force |
| Bounty mission | `derpy_gg_bounty_<guild>`, one live mission per guild per faction |
| Feed messages | `message_event_text_text_derpy_gg_<stem>_title` / `_primary` / `_secondary` |
| Feed indexes | 5001 hostile hit, 5002 demand, 5003 leadership, 5004 rank |
| Panel text | `derpy_gg_<key>`, resolved by `GGUI.loc` at draw time |

The DB side is seven tables plus the loc: `effect_bundles`,
`effect_bundles_to_effects_junctions`, `missions`, `event_feed_message_events`,
`campaign_groups`, `campaign_group_members` and `campaign_group_member_criteria_values`.
The last four exist only to make the feed indexes resolve (section 7).

## 5. The panel

The panel is **our own `.twui.xml`, created at runtime**. No CA layout is overridden.

- `tools/gen_guilds_ui.py` writes all six layouts from coordinate tables. GUIDs are
  deterministic per component name, in the `GG21` prefix.
- The engine ignores `dockpoint` on a runtime-created component. `GGUI` positions
  everything with `MoveTo`, which is why the layout files carry no offsets and a plain
  viewer stacks the panel in one corner.
- The tabs, in screen order: Guilds, Standings, Bounties, Court, Log, Help. The Help and
  Log tabs share 21 text slots (`gg_help_01`..`gg_help_21`) and one pager.
- The panel ground is image index 1 of four on the panel component, and is repainted per
  guild. The grounds are dimmed until they measure what CA's own `tier_01` ground measures
  under the scrim, so text keeps its contrast.
- The opener is a crest button parented to the HUD. It sits left of the Zharr Exchange's
  button when that mod is present, and stands alone otherwise (`GGUI.btn_anchor`, checked
  by `check_guilds_anchor.py`).

## 6. Build pipeline

Run everything from the repo root.

| Step | Command | Notes |
|---|---|---|
| Parse | `luac -p <file>` for the three scripts | Lua 5.1.5 |
| Test | `lua tools/_guilds_harness.lua` | Runs the shipped Lua against a stubbed campaign and panel. Prints `harness ok`. |
| Opener maths | `py tools/check_guilds_anchor.py` | Extracts `GGUI.btn_anchor` from the shipped script and runs it against measured HUD geometry. |
| Data | `py tools/gen_great_guilds.py --check`, then `--write` | Builds every DB row and loc line and refuses on a broken rule (below). |
| Layouts | `py tools/gen_guilds_ui.py --check`, then `--write` | |
| Layout vs Lua | `py tools/check_guilds_ui.py` | Every component name the Lua reaches for exists; GUID pairing is intact. |
| Look | `py tools/preview_guilds_panel.py` | Renders the panel to a PNG with the game shut, using the vendored source of TWUI Studio (not included). Glyph widths are approximate; positions are exact. |
| Art | `py tools/make_guild_icons.py`, `py tools/make_guild_backgrounds.py` | Icons are recoloured CA building icons; grounds are cropped and dimmed. `--check` re-measures what ships. **Neither the inputs nor the outputs are in this repo** (they are CA-derived); extract the sources from your own game install. |
| Pack | `py tools/import_great_guilds.py` | Needs RPFM's MCP server. Refuses if the TSVs disagree with `build()`, packs, saves, then re-opens the saved pack and counts every table's rows. |

The generators, `check_guilds_ui.py`, the preview and the two art tools take `--selftest`,
which breaks something on purpose and proves the check still reports it.

What `gen_great_guilds.py --check` refuses on, among others: an effect value whose sign
fights `is_positive_value_good`; an effect key vanilla does not have, or a scope vanilla never
pairs it with; a value more than 1.5x the largest magnitude vanilla puts on that effect and
scope; a feed index that collides with vanilla's or disagrees with the Lua; an event picture no
vanilla row uses; a Help page over its 21 lines; a message title that names a guild without
its article; a building-theme token with Lua pattern magic in it, or one matching no CA
chain; a hire unit that is not a real vanilla key.

The data checks read a dump of vanilla tables in `.skilltree_cache/` (RPFM's JSON
export), which is CA's data and is not in this repo.

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
  The mod snapshots every value into `derpy_gg_tuned` at the first turn and ignores later
  changes.
- **Lua 5.1 allows 200 locals per function.** The harness's main chunk is near that
  ceiling, so new tests go inside `;(function() ... end)()`.

## 8. Where the design lives

- [docs/design/2026-09-10-great-guilds-design.md](design/2026-09-10-great-guilds-design.md):
  the original design. Parts are superseded; for example, reputation now falls as well as
  rises.
- [docs/design/2026-09-23-great-guilds-flavours-design.md](design/2026-09-23-great-guilds-flavours-design.md):
  Empire and Dwarf versions of the guilds. Designed, not built.
- `docs/plans/`: the plans the ladder, panel, AI and notices were built from.
- `docs/history/`: dated handoffs, the most recent last. When a handoff and the code
  disagree, the code wins.
