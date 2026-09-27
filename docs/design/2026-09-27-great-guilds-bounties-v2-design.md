# Great Guilds: bounties that cost a choice - design

2026-09-27. Mod: `derpy_great_guilds.pack`. Supersedes the "targets factions YOU are already
at war with" rule in `zzz_derpy_guilds.lua` (THE BOUNTY BOARD header) and in
`2026-09-10-great-guilds-design.md`.

## 1. The problem, in the player's words

"The bounty system currently is too exploitable, offering missions that the player will
always do with at war factions."

Today every offer names a region or a lord of a faction the player already fights
(`GG.bounty_target` walks `factions_at_war_with()` only), taking one is free, and handing
one back through the objectives panel is free. So the rational play is: take all three,
finish the ones the war finishes anyway, hand back the rest. The guild pays for the war
the player was already fighting.

## 2. What the player chose (2026-09-27)

| Question | Answer |
|---|---|
| Direction | **Both**: military bounties become real choices, and every guild gets a non-military kind |
| Military targets | **Mix, peace pays more**: a far enemy (a detour), or a faction you are at peace with (a new war) that pays much more. The front line is never offered |
| Cost of taking | **Favour stake**: taking spends favour with that guild; finishing refunds it, failing or handing back loses it |
| Non-military kinds | The six in §5, as proposed |

Success means: no offer on the board is something the player's current plans would
finish unchanged, and taking every offer blind is a loss.

## 3. Military bounties: far enemy or new war

The three existing kinds (`region_take`, `region_sack`, `lord_kill`) keep their objective
strings. What changes is WHICH targets they may name, and one new field on the offer:
`war` (0 = far enemy, 1 = new war).

### 3.1 Who may be a target

A candidate target faction must be: alive, not human, not the player, and none of
- a military or defensive ally of the player (`military_allies_with`, `defensive_allies_with`),
- the player's vassal or master, or a client state either way
  (`is_ally_vassal_or_client_state_of`, `is_vassal_of` both directions),
- a faction the player has a non-aggression pact with (`non_aggression_pact_with`),
- carrying CA's realm/rift bundles (`wh3_main_bundle_realm_factions`,
  `wh3_main_bundle_rift_factions`), which CA's own contract script also filters.

"Far enemy" candidates come from `factions_at_war_with()`. "New war" candidates come from
`factions_met()` minus the at-war set.

### 3.2 The front line is never offered

- **A region is on the front** if the player owns it, or it appears in
  `adjacent_region_list()` of any region the player owns.
- **A lord or hero is on the front** if they stand within `GG.BOUNTY_FRONT_DIST2` (squared logical
  map distance, as CA's contract script compares it) of any settlement the player
  owns or any army the player has (`logical_position_x/y`).

Front targets are never posted. An UNTAKEN offer whose target moves onto the front is
withdrawn at the next turn start (`GG.purge_bounties`), with a trace line. A TAKEN offer is
never withdrawn for this: the deal was made.

`GG.BOUNTY_FRONT_DIST2 = 50000` (squared), the figure CA's contract script uses for "near"
(`max_distance_between_player_settlement_and_issuer_capital`). It is tuned from the trace
log in play; it is a constant, not an MCT slider.

### 3.3 The mix

For each guild that posts a military kind, roll `GG.roll(3) == 1` for "new war", otherwise
"far enemy". If the rolled pool is empty, try the other pool; if both are empty, the guild
posts nothing this turn (as now). A player at war with nobody now gets new-war offers
instead of an empty board.

### 3.4 Pricing

`GG.bounty_difficulty` keeps its score and adds a **distance** term: the shortest distance
from the target to any player settlement, `d`, adds `min(floor(d / 10), 60)`
(`GG.BOUNTY_DIFF.per_distance = 10`, `distance_max = 60`). The 200 ceiling (`GG.BOUNTY_DIFF_MAX`) still applies.

A new-war offer multiplies the priced result: gold x2, Reputation x1.5
(`GG.BOUNTY_WAR_GOLD = 200`, `GG.BOUNTY_WAR_REP = 150`, percentages).

### 3.5 Validity changes (`GG.bounty_still_valid`)

- A new-war offer stays valid when the player later goes to war with its owner. The offer
  keeps its new-war price, because declaring war was the point.
- ANY military offer becomes invalid when its owner turns into an ally, vassal, master or
  pact partner (§3.1), or its target is on the front (§3.2).
- The existing rules stay: invalid when the player owns the region; lords are dropped by
  `CharacterDestroyed` (`GG.drop_bounty_target`).

### 3.6 The card

A new-war card carries one extra line in red: **"Taking this means war with <faction>."**
(new loc key `bounty_war`). The far-enemy card is unchanged apart from its price.

## 4. The favour stake

| Event | Result |
|---|---|
| Take | Spend `stake` favour with the offer's guild via `GG.spend`. If favour < stake, nothing is issued. |
| Mission succeeded | Refund `stake` as favour only (no Reputation), then pay the reward as now. |
| Mission failed | Stake lost. Reputation penalty as now (`rate_bounty_fail`). |
| Mission cancelled (handed back) | Stake lost. No Reputation penalty. |

- `stake = ceil(o.rep * rate_bounty_stake / 100)`, fixed when the offer is posted and
  re-priced with it while untaken. The new MCT setting `rate_bounty_stake` defaults to 25,
  with 0 meaning free. It goes in all four presets: easy 15, default 25, hard 35, ultra 50.
- The refund is a raw favour add (new `GG.refund(faction, guild, amount)`), NOT `GG.grant`:
  a grant would also add Reputation and trigger the rivalry cost on money the player
  already had.
- **Panel:** when favour < stake, the Take button is disabled and its tooltip reads "Needs
  20 favour with the Brass Tablets. You have 12." (loc `bounty_stake_short`). The card
  shows the stake beside the pay (loc `bounty_stake`, "Stake: 20 favour").
- **Order inside `GG.take_bounty`:** spend, then mark `taken`, then save, then trigger, as
  now. If the trigger throws, refund the stake along with clearing `taken`.
- Multiplayer: `GG.MP_OPS.bounty` already routes the take; the spend happens inside it, so
  it applies on every machine. `GG.save(faction)` is added beside `GG.save_bounties`,
  because favour lives in the standings saved value.

## 5. Non-military kinds: a job per guild, and building requests for every guild

Each guild has up to four kinds: its military kind (§3), its job (the table below), a
building request (`build`, §5.4), and for the Daemonsmiths and Immortals a hero bounty
(§5.5). §5.4 and §5.5 were added at the player's request, 2026-09-27. Overseers' job IS the
building request, and the Khanate's job IS a hero bounty. Each post picks one kind uniformly out of those
that have a target right now. A guild with no target of any kind posts nothing, as now.

| Guild | Kind key | Card title (Chaos Dwarf; other races get their own) | Objective string | Target, set from where the player is now |
|---|---|---|---|---|
| Brass Tablets | `coffers` | Fill the Coffers | `type HAVE_AT_LEAST_X_MONEY;total <X>;` | X = treasury when TAKEN + max(5 x net income, 5000), rounded to 500 |
| Immortals | `champion` | Prove a Champion | `type ACHIEVE_CHARACTER_RANK;total 1;total2 <R>;include_generals;` | R = the player's highest character rank + 4, at most 40. Not posted if the highest rank is already 37 or more |
| Daemonsmiths | `research` | Commissioned Work | `type RESEARCH_N_TECHS_INCLUDING;total 1;technology <key>;` | A technology the player lacks, from the upper half of their tree's tiers |
| Khanate | `hero_strike` | A Quiet Word | (§5.5) | (§5.5): wound or assassinate a named enemy lord or hero |
| Overseers | `build` | (§5.4) | (§5.4) | (§5.4) |
| Slavers | `captives` | Fill the Pens | `type CAPTURE_X_BATTLE_CAPTIVES;total <N>;` | N = 300 + 10 x turn, at most 1500 |

Every objective string above is copied from CA's `generate_*_objective` helpers in
`campaign/main_warhammer/victory_objectives_config_utils.lua` (read 2026-09-27), which build
exactly these conditions. `KILL_CHARACTER_BY_ANY_MEANS` is the type CA's contract script
and this mod already issue.

### 5.1 Where the targets come from

- **coffers:** `faction:treasury()` and `faction:net_income()`. X is computed at TAKE, not at
  post, because the treasury moves while the offer waits. The card shows the ask
  ("Hold 5,000 more gold than you have"), not X.
- **champion:** the max of `rank()` over `faction:character_list()`.
- **research:** no script call lists technologies, so the generator writes a data table
  `GG.BOUNTY_TECHS[<culture>] = {key, ...}`. It holds the upper-half-tier nodes of every
  `technology_node_sets` row for that culture with an empty `faction_key`, read from the
  installed game via `live_rows`. The runtime filters out owned techs with
  `faction:has_technology`. Factions with their own node set (e.g. `emp_wulfhart`) get
  `GG.BOUNTY_TECHS_FACTION[<faction>]`, which the runtime checks first.
- **hero_strike / hero_sabotage / hero_harry:** see §5.5.
- **build:** see §5.4.
- **captives:** the turn number only.

### 5.2 Validity

| Kind | Untaken offer withdrawn when |
|---|---|
| coffers | never (the ask is relative) |
| champion | the player's highest rank reaches R |
| research | the player has the tech |
| hero_* | see §5.5 |
| build | the player already has the building |
| captives | never |

### 5.3 Pricing

Base gold per kind: coffers 1500, champion 2000, research 2000, build 2500, hero_strike 1200, hero_sabotage 1200, hero_harry 1200,
captives 1500. Difficulty scores (added to `GG.BOUNTY_DIFF`):
- coffers: the ask / 100
- champion: 10 per rank of the gap
- research: the node's tier x 15
- hero_*: the region or lord score of §3 (no distance term: the front is allowed, §5.5)
- build: the level's tier x 25
- captives: none

Reputation as §3.4. No war multiplier: hero bounties are at-war only (§5.5).

### 5.4 Building requests (`build`), every guild

`type CONSTRUCT_N_OF_A_BUILDING;total 1;faction <player>;building_level <key>;` (CA's
`generate_CONSTRUCT_N_OF_A_BUILDING_objective`). It asks for one building level that pays
THIS guild, of the player's race, that no region the player owns has yet. Each guild
titles it in its own voice (e.g. the Brass Tablets "Open a Counting-House", the Immortals
"Raise a Barracks").

**The candidate list is generated**, since no script call lists buildings:
`GG.BOUNTY_BUILDINGS[<tag>][<guild>] = {level_key, ...}`. A level is in it when:
- its chain is in `covered_chains()` for that flavour tag (one covered race only, so no
  shared landmarks);
- `GG.guild_of_chain` pays that chain to that guild. This is computed by running the SHIPPED
  Lua through `_lua_guilds_of`, the same run `check_built_effects` uses, so the request and
  the building card's yellow line cannot disagree. Unmatched chains fall back to the
  Overseers, as `GG.on_building` pays them;
- it is the THIRD or later non-ruin level of its chain. `building_levels.level` counts from
  0, but a landmark chain puts its `_ruin` at 0, so the rank is counted over non-ruin rows
  rather than read off the column;
- `visible_in_ui` is true, the level is not a `_ruin`, `resource_requirement` is empty
  (a resource building can only go where the resource is, so the request could be
  impossible), and the chain is not a main settlement chain (`settlement` in the chain key).

The runtime drops any level for which `region:building_exists(key)` is true in a region the
player owns, then picks one at random.

**Coverage, measured 2026-09-27** (tier 3+ levels per guild and race, before the resource
and settlement filters): Brass 18-40, Immortals 3-35, Overseers 25-72 in every race.
Daemonsmiths 0-6, Khanate 0-5, Slavers 0-2, and none at all in most races. So in practice
Brass, Immortals and Overseers ask for buildings; the other three rarely or never, and post
their other kinds instead. Widening those three guilds' building lists was offered and NOT
chosen, because it would also change what those buildings pay each turn.

### 5.5 Hero bounties: use your heroes on a named target

Added at the player's request 2026-09-27, "so players can be encouraged to use their heroes
to do something other than implementing the heroes on an army", and to apply to every
covered race including the Dwarfs and the Empire.

| Guild | Kind | Title (CHD) | Counts as progress | Needed | Target |
|---|---|---|---|---|---|
| Daemonsmiths | `hero_sabotage` | Crack the Walls | an action whose key contains `damage_building`, `damage_walls` or `assault_garrison`, against the named settlement | 2 | an enemy region |
| Immortals | `hero_harry` | Harry Their March | `assault_unit` (covers `assault_units`), `block_army` or `hinder_replenishment`, against the named lord's army | 2 | an enemy lord with an army |
| Khanate | `hero_strike` | A Quiet Word | `wound` or `assassinate`, against the named character | 1 | an enemy lord or hero |

**All races can do it.** `agent_actions` has no per-subculture rows (all 203 are generic),
and every one of the six agent types (champion, dignitary, engineer, runesmith, spy, wizard)
has at least one action in each of the three groups, measured 2026-09-27. A Dwarf Runesmith,
Engineer or Thane and an Empire Captain, Wizard, Warrior Priest or Engineer all qualify.
Actions whose key contains `convert` (the Nurgle conversions) never count.

**Objective: SCRIPTED.** No objective type counts N named hero actions against one target,
so these use the string-route SCRIPTED shape already proven in this workspace
(docs/MISSIONS.md §8):
`objective{type SCRIPTED;script_key derpy_gg_hero;override_text mission_text_text_derpy_gg_hero_<shape>;}`.
There is one generic loc line per shape, e.g. "Use your heroes against the target named on
the Guilds panel". The zoom-to target is set with `cm:set_scripted_mission_position`.

**Counting.** The existing `CharacterCharacterTargetAction` / `CharacterGarrisonTargetAction`
listeners gain one call, `GG.hero_progress(faction, context)`. It counts an action only when:
- the acting character's faction is the bounty holder;
- the result is `mission_result_success` or `mission_result_critial_success` (CA's
  spelling), so an opportune failure does not count;
- `agent_action_key()` matches the shape;
- the target matches: `garrison_residence():region():name()` for sabotage, the target
  character's family-member cqi for strike, and the target character being the named lord
  for harry.

Progress is stored on the offer as `done`. When `done >= amount`, the listener calls
`cm:complete_scripted_mission_objective(faction, key, "derpy_gg_hero", true)`, and payment
follows through the existing MissionSucceeded handler. The card shows "1 of 2".

**Targets.** Only factions the player is AT WAR with, filtered as in §3.1. **The front is
allowed**: getting a hero out of an army and working is the point, and the front is where
that happens. There is no "new war" variant, because whether heroes can act against a
faction at peace is unverified (§9). Pay is lower than the military kinds to match.

**A taken hero bounty whose target is gone** (region captured by anyone or no longer an
enemy's; lord or hero destroyed; lord without an army at turn start) is voided by the mod:
- set `o.void = true` and save,
- then `cm:cancel_custom_mission`.

`MissionCancelled` sees `void` and REFUNDS the stake with no penalty, because
`cm:cancel_custom_mission` raises the same event a hand-back does. There is one exception:
for `hero_strike` a destroyed target COMPLETES the bounty (whoever killed them, the Khanate
got what it paid for), matching the old kill-by-any-means behaviour. Untaken offers are
withdrawn under the same conditions.

## 6. Mission rows and loc

A mission key holds its own title and description, and the objectives panel reads them
from loc. So each family of kinds gets its OWN row per guild per flavour:
- `derpy_gg_bounty_<guild><tag>`: military, the existing row;
- `derpy_gg_job_<guild><tag>`: the job, for the five guilds whose job is not `build`
  (the Khanate's job row carries the SCRIPTED `hero_strike`);
- `derpy_gg_build_<guild><tag>`: the building request, for all six;
- `derpy_gg_hero_<guild><tag>`: the hero bounty, for the Daemonsmiths and Immortals.
- `GG.offer_mission_key(o, faction)` names an offer's row, keyed by `o.kind`'s family;
  `GG.bounty_mission_key(guild, faction)` stays as the military row's name.
- **One live bounty per guild** is unchanged (`GG.bounty_for_guild`), so a guild's keys never
  compete.
- The generator's `BOUNTY_KINDS` / `BOUNTIES` mirror gains the new kinds, and
  `import_great_guilds.py`'s mirror check covers them.
- AS BUILT (ruling T9-R1): job, build and hero titles are ONE per kind across all nine
  flavours, and each description names the flavour's own guild, which carries the race's
  voice. Hand-written per-race lines can replace them later as data only.
- New panel loc: `bounty_war`, `bounty_war_tip`, `bounty_stake_tip`, `bounty_stake_short`,
  `bounty_char`, and one `bounty_obj_*` line per new kind for the card.
- Player text uses plain words: Reputation, favour, gold. No "cap", "rep", "AI" or "HUD".

## 7. Save format

The offer string gets five fields APPENDED, as every packed field in this mod is:
`war` (0/1), `stake`, `amount` (X for coffers, R for champion, N for captives, the count
needed for hero bounties, else 0), `done` (hero progress), `void` (0/1).
A save written before this build reads them as 0, which means a far-enemy offer with no
stake, so an old offer already on the board keeps its old free terms until it expires.
`GG.load_bounties` accepts the new kind keys; an unknown kind is still dropped.

## 8. Help tab and changelog

- The Help tab's bounty paragraph is rewritten to cover the two kinds of target, the stake
  and the job kinds.
- The "Handing back is free" sentence goes.
- CHANGELOG entry in plain words.

## 9. Testing

**Harness** (`tools/_guilds_harness.lua`), each new rule tested in isolation, each test
watched failing first:
- a front region and a front lord are never posted; a region adjacent to the player is
  withdrawn when untaken and kept when taken;
- an allied, vassal or pact faction is never a target; an at-peace faction is a new-war
  target;
- the mix falls back to the other pool when one is empty; with no wars at all the board
  still posts;
- the new-war price multiplier is applied, and is kept after war is declared;
- the stake is spent on take, refunded on success with no Reputation, lost on fail and on
  cancel, refunded when the trigger throws; take is refused when favour is short;
- each job kind builds the exact objective string of §5, and its validity rules (§5.2) hold;
- save/load round-trips the five new fields, and an old-format string loads with zeros;
- hero progress: a matching success counts once; an opportune failure, another faction's
  hero, a scout or influence action, a `convert` action and a different target do not; the
  objective completes at `amount` exactly once;
- a voided hero bounty refunds the stake on its MissionCancelled, while a hand-back of the
  same bounty does not; a destroyed `hero_strike` target completes rather than voids;
- hero bounties post for a Dwarf and an Empire faction in the harness, not only Chaos
  Dwarfs.

**Mutations:** extend the guilds mutation set with: front check removed, pact filter
removed, stake not spent, refund via `GG.grant`, war multiplier dropped, opportune failure
counted, target match dropped, void flag ignored. Each must be
killed.

**Generator checks:**
- every `GG.BOUNTY_TECHS` key exists in the installed `technologies` table;
- every `GG.BOUNTY_BUILDINGS[tag][guild]` key exists in `building_levels`, passes every §5.4
  filter, and the shipped `GG.guild_of_chain` pays its chain to that guild;
- every covered culture has a non-empty tech list, and a non-empty building list for the
  Overseers (the only guild whose job is `build`, so an empty list would leave it with the
  military kind alone). Empty lists for the other guilds are expected and printed, not failed.

**Preview:** the bounty tab drawn with one new-war card, one job card and a short-favour
disabled Take.

**In game** (things no offline check can answer, listed in the handoff):
1. `CAPTURE_X_BATTLE_CAPTIVES` progresses for each of the 8 races. If one does not, that
   race's Slavers job falls back to `EARN_X_AMOUNT_FROM_RAIDING` (same `total` shape).
2. `HAVE_AT_LEAST_X_MONEY` without `additive`: does `total` mean the treasury figure or the
   gain since issue? Read it off the objectives panel. §5.1's X assumes the treasury figure.
3. `character:rank()`: CA's doc says "1-6", while the mod already uses it as the level.
   Confirm it returns the level that `total2` is compared against.
4. MissionCancelled is the hand-back and MissionFailed is the timeout, as the existing
   listener comments assume.
5. A new-war take: the war declaration is the player's, and the mission completes on capture.
6. `context:agent_action_key()` returns the `agent_actions.unique_id` (e.g.
   `wh2_main_agent_action_champion_hinder_settlement_damage_building`), which §5.5 matches
   on. If it returns something else, match on `ability()` plus the result instead, and log
   the key once so the right field can be found.
7. The SCRIPTED hero objective completes from `cm:complete_scripted_mission_objective` when
   issued by string with `script_key derpy_gg_hero`, and the zoom-to position works.
8. Whether heroes can act against a faction at peace (which decides whether §5.5 can ever
   get a "new war" variant).
9. One hero bounty of each shape completed as a Dwarf and as an Empire player.

## 10. Out of scope

- The AI taking bounties.
- More than one bounty per guild.
- More than three board slots.
- A gold deposit (considered and replaced by the favour stake, 2026-09-27).
- Guild-issued wars the player did not choose. A new-war offer is only ever an offer.
