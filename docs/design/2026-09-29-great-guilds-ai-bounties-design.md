# Great Guilds: rivals take bounties - design

2026-09-29. Mod: `derpy_great_guilds.pack`. Sub-project 1 of 3 asked for on 2026-09-29 (the
other two, more offer variety and per-race mechanics, get one spec between them, later).
Lifts "The AI taking bounties" out of the out-of-scope list of
`2026-09-27-great-guilds-bounties-v2-design.md` §10. Nothing else in that spec changes.

## 1. The problem

The bounty board is human-only (`gg_turn` posts it under `if human then`). A finished bounty
is the largest single Reputation payment in the mod, so every AI rival on the Leaderboard
races without it. And no guild ever sets a price on the player: the board only ever points
outward.

## 2. What the player chose (2026-09-29)

| Question | Answer |
|---|---|
| What AI bounties are for | **A fair race** (rivals take and finish bounties and earn by them) **and bounties against you** (a guild sets a rival on your regions and lords) |
| Does a bounty on you change what the AI does? | **No.** Only a rival already at war with you gets one; the AI plays as it would. You are warned |
| A bounty on you runs out | **The rival pays for failing**, by the same rule you do. Nothing extra for you |
| How the mod tracks an AI bounty | **The mod scores it itself** from the world state and the events it already hears. No engine mission is issued to an AI faction |

Success means: a rival's Leaderboard Reputation includes bounty income; every bounty on a
human is announced; the player's own board behaves exactly as before; the added turn time
is not noticeable.

**Correction found while planning (2026-09-29):** `GG.covered` is true only for a culture a
human plays, so only rivals of the player's OWN race hold guild standing and can take
bounties. A bounty on the player therefore comes from a same-race rival at war with them
(common for the Empire and the Dark Elves, rarer for the Dwarfs and the High Elves). The
design conversation assumed any covered race could; widening that is a separate change.

Why not issue real missions to the AI: nothing in this workspace has measured whether the
engine tracks objectives for an AI faction, CA's own contracts go to humans only, and a
failure there is silent (the rival never finishes anything). The mod already has every
signal it needs to score the work itself.

## 3. State

- `GGAI.bounty[faction]`: at most ONE live bounty per AI faction, an offer table with the
  player board's fields (`guild`, `kind`, `target`, `owner`, `gold`, `rep`, `diff`, `stake`,
  `amount`, `done`, `void`, `posted`) plus `issued` (the turn it was taken). `taken` is always
  true.
- Saved in its own value, `derpy_gg_ai_bounty_<faction>`, empty string when none.
- **Kept out of `GG.bounties`.** `GG.drop_bounty_target`, `GG.hero_progress` and
  `GG.void_bounty` walk every list in `GG.bounties` and call
  `cm:complete_scripted_mission_objective` / `cm:cancel_custom_mission` on what they find. An
  AI bounty has no mission behind it.
- **One offer format.** The per-offer packing inside `GG.save_bounties` / `GG.load_bounties`
  moves into `GG.pack_offer(o)` / `GG.unpack_offer(str)`. Both boards use them; the player's
  saved string is byte-identical to today's, so old saves load unchanged.
- An old save has no AI bounty value; rivals start taking bounties on the next round.

## 4. Taking a bounty

Runs in `GGAI.run_turn`'s existing once-a-round sweep, per faction, after `court_step` and
`step`, under `GGAI.enabled()`, the new `ai_bounties` setting and `GG.bounty_pay() > 0` (the
same gate `GG.post_bounties` has). Only factions with `GG.state[name]` (someone who has
earned from a guild) and `GG.covered(name)`.

**Before the per-faction loop,** one pass loads every such faction's saved bounty and builds
`GGAI.by_target` (target -> holder). Its keys are the `used` set of step 6, so a faction early
in the loop cannot take a target held by one later in it.

1. **Settle first** (§5). A faction whose bounty just ended can take a new one next round,
   not this one.
2. **Only when it holds none.** No roll and no cooldown: one at a time against the player's
   three is already the slower pace.
3. **The guild:** start from `GG.roll(#GG.GUILDS)` and try each guild in order, as
   `GG.post_bounties` does. The first offer that can be built AND whose stake
   `GG.stake_affordable(faction, o)` passes is taken. A faction with no favour anywhere takes
   nothing.
4. **The kind:** `GG.guild_kinds(guild)` minus `job_captives` (no script call counts battle
   captives), starting from a rolled kind, as `GG.make_bounty` does. **Changed at the final
   review:** `hero_harry` and `hero_sabotage` are skipped too - two hits on one named target
   from heroes nobody aims is close to never - and a guild whose favour is below
   `GG.bounty_stake(GG.bounty_pay())` is skipped before any walk.
5. **The target:**
   - Military and hero kinds: `GG.bounty_target` gains a sixth argument, `ai`. When true,
     (a) the pool is `factions_at_war_with()` only, never `factions_met()`; (b)
     `GG.bounty_rival_ok` is called with `human_ok = true`, which skips its `is_human()`
     exclusion and nothing else; (c) **changed at the final review:** the front filter is
     INVERTED, not skipped - a rival names only regions it owns or borders, and lords and
     heroes within `GG.BOUNTY_FRONT_DIST2` of its settlements or armies. A target across the
     map is one it never reaches, and at the default failure cost a rival finishing under
     56% of its bounties loses Reputation by taking them. With `ai` nil, every line of the
     player's path is unchanged.
   - No war roll: an AI offer is always `war = 0`. No guild starts a war.
   - Jobs use the existing `GG.BOUNTY_PICK` functions, which already take the faction.
     (`GG.player_has_building` and `GG.upgrade_open` are faction-keyed despite the name.)
6. **No two rivals on one target.** `used` is the key set of `GGAI.by_target`, passed to the
   picker; a take adds its target to the index and a settle removes it.
7. **Price and stake:** `GG.make_offer`'s own difficulty, price and stake, with `war = 0`.
8. **Take:** `GG.spend(faction, guild, stake)`; on refusal nothing is taken. For
   `job_coffers`, `amount = treasury now + ask`, as `GG.take_bounty` does. Set
   `issued = GG.turn_now()`, save the bounty and `GG.save(faction)`.
9. **Warn** if the target belongs to a human (§6).

## 5. Ending a bounty

Event-driven kinds only MARK the bounty (`o.done`). All payment happens in one function,
`GGAI.settle_bounty(faction, turn)`, called from the sweep, so there is one payout path.

### 5.1 Done

| Kind | Done when | Where it is seen |
|---|---|---|
| `region_take` | `cm:get_region(target):owning_faction():name() == faction` | the sweep |
| `region_sack` | a character of the holder sacks or razes the target settlement: `o.done = 1` | `gg_sack_*` listeners gain one call, `GGAI.on_sack(name, region_key)`; the region is `context:garrison_residence():region():name()` (CA's scripting_doc: the context carries `character` and `garrison_residence`) |
| `lord_kill` | the target character is destroyed, by anyone (the player's own objective is KILL_CHARACTER_BY_ANY_MEANS): `o.done = 1` | `gg_character_destroyed` gains one call, `GGAI.on_character_destroyed(cqi)` |
| `hero_strike` | as `lord_kill` (a destroyed target completes it), or 1 successful matching action | both of the above |
| `hero_sabotage`, `hero_harry` | `o.done >= k.needed` successful matching actions by the holder's heroes against the target | `gg_agent_*` listeners gain one call, `GGAI.hero_progress(name, akey, target, won)`, reusing `GG.hero_action_matches` |
| `job_coffers` | `faction:treasury() >= amount` | the sweep |
| `job_champion` | `GG.highest_rank(faction) >= amount` | the sweep |
| `job_research` | `faction:has_technology(target)` | the sweep |
| `job_build` | `GG.player_has_building(faction, target)` | the sweep |

The sack and hero listeners load only the acting faction's bounty. `CharacterDestroyed` does
not say who killed, so `GGAI.on_character_destroyed` looks the target up in
`GGAI.by_target` (§4). The index is rebuilt by every sweep and built lazily on first use in a
session by the same pass, so a death between a load and the first sweep is not missed.

**On done:** `GG.refund(faction, guild, stake)`, `GG.grant(faction, guild, rep, "bounties")`,
`cm:treasury_mod(faction, gold)` (CA: "This value must be positive"; `gold` always is), clear
the bounty, save both values, write the Log lines (§6).

### 5.2 Voided

A taken hero bounty whose target is gone, the same rule as the player's
(`GG.hero_target_alive(faction, o)`, which is faction-keyed): `hero_harry` whose lord has no
army, `hero_sabotage` whose region no longer belongs to an enemy of the holder. The stake is
refunded, no penalty. Military bounties are never voided once taken, as with the player's: a
region someone else captured can still be taken from its new owner.

### 5.3 Failed

`turn - issued >= GG.BOUNTY_TURN_LIMIT` (20) and not done. The stake is lost and the holder
pays `GG.penalise(faction, guild, GG.bounty_fail_cost(o))`, the player's rule and the same
`rate_bounty_fail` setting.

### 5.4 Order inside `GGAI.settle_bounty`

Done, then voided, then failed. A bounty finished on its last turn is paid.

### 5.5 A model that cannot answer

Every read is `pcall`-wrapped. A read that throws is "not done" and "not void": nothing is
paid or refunded on a question mark, and a bounty the model can never read runs out. The
holder dying ends nothing: the sweep does not visit dead factions and their saved value is
inert.

## 6. What the player sees

### 6.1 A bounty on you

Taken with a target whose owner is human (`GG.is_human(o.owner)`; `owner` is the target's
faction at the take and is kept, so the ending is reported to the same player).

**Feed message:** `cm:show_message_event_located(owner, title, primary, secondary, x, y,
false, GG.feed(owner, GG.FEED_INDEX_HUNTED))`, at `GG.target_pos(o)`, so the message zooms to
the target.
- A fifth record, base `GG.FEED_INDEX_HUNTED = 5005`, per flavour at `5005 + feed offset`, like
  the four existing bases (5001-5004). Its `event` is `scripted_transient_located_event`:
  it lands in the event-feed strip with a zoom button and does not take over the screen,
  because a big war can bring several in one round. `persistent` in the call is `false` to
  agree with it. A located call against a non-located record resolves, logs a line that
  reads like success and draws nothing (measured 2026-09-17), so the record type matters.
- The row is cloned field-for-field from a vanilla `scripted_transient_located_event` row in
  the cached `event_feed_message_events`, changing only `group` and `image`.
- Text is fixed, since feed strings cannot name a faction at runtime:
  title "A Price on Your Holdings", primary "A guild has hired a rival against you.",
  secondary "The Guilds panel's Log names who, and what they were paid to take." One line
  set, retagged per flavour like every other key.
- If `GG.target_pos(o)` returns nothing, no message: the Log line still records it.

**Log** (`GG.log_add`, keys only; the panel turns them into words at draw time):

| Kind | a | b | Draws as |
|---|---|---|---|
| `hunted` | target | rival | "Turn 12  The Khanate: put a price on Lord X, for Clan Y." |
| `hunt_done` | target | rival | "... Clan Y collected the price on Lord X." |
| `hunt_failed` | target | rival | "... Clan Y failed to collect the price on Lord X, and lost Reputation." |
| `hunt_void` | target | rival | "... withdrew its price on Lord X." |

A target that is a number is a character: named by `get_forename()` / `get_surname()`
(CA: "Returns the character forename"; the value is a `names_name_*` loc key, as CA's own
scripts compare it) through `GGUI.loc_raw` when the character can still be read, else the
generic `bounty_lord` / `bounty_char` word the bounty card already uses. Anything else is a
region, named by `regions_onscreen_<key>` as the card does. `hunted` and `hunt_done` draw red
(bad news); `hunt_failed` and `hunt_void` are good news for the reader and draw plain. All
four join the `rivals` Log filter.

### 6.2 The race

When a rival of the reader's culture finishes ANY bounty, each human of that culture gets
`ai_bounty` (a = Reputation paid, b = the rival): "Clan Y finished a bounty: +N Reputation."
Same audience rule as `ai_buy` (`GGAI.log_purchase`). Joins the `rivals` filter. A bounty on
that same human writes `hunt_done` instead, not both. No lines for rivals' takes or
failures.

## 7. Settings, cost, multiplayer

- **`ai_bounties`**, checkbox "Rivals take bounties", default on, in `TUNE_DEFAULTS` and in
  `script/mct/settings/derpy_great_guilds.lua` beside `ai_spending`. Off: the sweep makes no
  AI bounty call at all. A bounty already held when it is switched off is left as it is and
  resumes if it is switched back on. `ai_spending` off stops everything, since
  `GGAI.enabled()` gates the sweep.
- No new sliders: `rate_bounty_stake`, `rate_bounty_fail` and `rate_bounty` apply as they do
  to the player (`rate_bounty = 0` turns off both boards, since `GG.bounty_pay()` prices both).
- **Cost:** per covered faction per round, one settle (a few reads). The target walk runs
  only for a faction holding nothing, is the same walk as one guild of the player's board,
  and a faction then holds its bounty up to 20 rounds. The three listeners gain one
  saved-value read each, and only the destroyed-character one needs the index.
- **Multiplayer:** all rolls are `GG.roll` (`cm:random_number`), the sweep order is the
  faction list's, and the listener marks run on every machine. Same determinism as
  `GGAI.step`.

## 8. Code touched

| File | Change |
|---|---|
| `zzz_derpy_guilds.lua` | `GG.pack_offer` / `GG.unpack_offer` out of save/load; `GG.bounty_target(..., ai)`; `GG.bounty_rival_ok(pf, e, human_ok)`; `GG.bounty_pool(faction, war, human_ok)`; `GG.FEED_INDEX_HUNTED`; one call added in each of `gg_sack_*`, `gg_agent_*`, `gg_character_destroyed`; `ai_bounties` in `TUNE_DEFAULTS` and the settings list |
| `zzz_derpy_guilds_ai.lua` | `GGAI.bounty`, load/save, `take_bounty`, `settle_bounty`, `on_sack`, `on_character_destroyed`, `hero_progress`, `by_target`, the warn and log calls; one line in `run_turn` |
| `zzz_derpy_guilds_ui.lua` | five Log kinds in `GGUI.log_text`, the `rivals` filter, the character-name read |
| `script/mct/settings/derpy_great_guilds.lua` | the `ai_bounties` checkbox |
| `tools/gen_great_guilds.py` | the fifth feed record per flavour; loc for the feed text, the five Log kinds and the MCT option; `check()` learns that one record is `scripted_transient_located_event` (today it demands `scripted_persistent_event` of every record) |

## 9. Testing

**Harness**: the model and AI tests go in `tools/_guilds_bounty_harness.lua` (changed at
planning from a new file: that harness already has the world stub these tests need - factions
at war, regions, lords, positions - and `mutate_guilds.py` already runs it); the Log-text tests
go in an IIFE at the end of `tools/_guilds_harness.lua`, the only harness that loads the panel.
Each test watched failing first. Remember the `RANDOM` stub always rolls 1: a test that must refuse something lists the
refused case first.
- takes only when holding none; takes from the first affordable guild; nothing when no stake
  is affordable; the stake is spent;
- at-war targets only (a met-at-peace faction is never named); a human target is allowed;
  only a target on the rival's own front is named; `war` is always 0; `job_captives` is never taken; two rivals never
  hold one target;
- each success route: region owned; a sack by the holder counts and a sack by another faction
  does not; a lord destroyed counts whoever killed him; hero actions count to `needed` and an
  opportune failure does not; each of the four jobs;
- done pays refund + Reputation + gold, exactly once; void refunds with no penalty; failure at
  20 turns charges `bounty_fail_cost` and not before; done beats failure on the last turn;
- an unreadable model neither pays nor voids;
- a bounty on a human writes `hunted` and makes one located feed call with `persistent` false
  at the flavoured 5005 index; its ending writes `hunt_done` / `hunt_failed` / `hunt_void`; a
  non-human target writes nothing and calls nothing;
- a same-culture rival's finish writes `ai_bounty`; another culture's does not;
- `GG.bounties` is never written by any AI path; the AI bounty survives save and load; the
  player's board string is unchanged by the pack/unpack refactor;
- `ai_bounties` off: no call.

**Mutants** (`tools/mutate_guilds.py` runs the new harness too): the at-war-only pool widened
to `factions_met`; the human exclusion left on; the dedupe dropped; the stake not spent; the
failure cost not charged; a void that also penalises; an unreadable read that pays; the feed
call made for a non-human target; the settle order put failure before done.

**Generator checks:** 5005 plus every flavour offset clears vanilla's indices and the four
existing bases; the fifth record is `scripted_transient_located_event` and the Lua passes
`false`; every new loc key ships in all nine flavours.

**In game** (added to the handoff's list):
1. A rival's hero action reaches `gg_agent_*`: a trace line the first time an AI action is
   seen in a session, as `ResearchStarted` does. CA's followers script filters these events
   with `is_human()` inside the handler, which suggests they fire for AI factions too; not
   measured.
2. The located feed message draws in the strip and its zoom goes to the target.
3. A rival's Leaderboard Reputation moves after its bounty is paid, and the Log says so.

## 10. Out of scope

- Nudging the AI toward a bounty's target (stance or diplomatic-event levers). Revisit once
  play shows how often bounties on the player land.
- A rival at peace with the player taking a bounty on them (a guild-started war).
- A reward for the player when a bounty on them fails.
- A "bounties collected" count on the panel's activity line (the Log carries it).
- AI factions taking more than one bounty at a time.
