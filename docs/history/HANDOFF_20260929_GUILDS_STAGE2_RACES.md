# Great Guilds: stage 2, race mechanics (2026-09-29)

Plan: `docs/superpowers/plans/2026-09-29-great-guilds-stage2-race-mechanics.md`.
Spec: `docs/superpowers/specs/2026-09-29-great-guilds-service-pools-and-races-design.md`
§6-§9. Its tables now carry *Built:* notes wherever the build differs.
Ledger: `.superpowers/sdd/2026-09-29-great-guilds-stage2-race-mechanics/progress.md`.

## 1. Builds

| Build | What | State |
|---|---|---|
| `E6539153` | stage 2: race services, earnings, twists, Help page 6 | deployed, then replaced after the final review (backup `.bak_stage2_review_20260929`) |
| `B69679D0` | the review's two fixes (§3) | **live in `data/`**; MD5 `B69679D0500C398334DFDEDAC146DEC5`, 33,839,402 bytes; backup of the stage 1 build `.bak_stage2_races_20260929` = `F3F6FE85`. Not pushed; no Workshop copy of this pack exists |

Stage 1 ended at `F3F6FE85` (`HANDOFF_20260929_GUILDS_POOLS_STAGE1.md`).

## 2. What shipped

Every race now gets three things no other race has. All three sit behind a new MCT checkbox,
**Race differences** (`race_differences`, systems section, on by default, locked in a running
campaign):

1. **Its own services.** There are 29 race rows in `GG.SERVICES` (83 rows in all),
   appended in race order and each tagged `race = <culture>`. A race row is drawn only for
   its own race, and only while race differences are on. Rule 2 of the draw
   (`GG.show_race_service`) puts at least one on show every period.
   - The Empire has its three race services plus five lord services. Each lord service
     follows a pool, not a faction name: Elspeth's Schematics, Gelt's Arcane Essays,
     Todbringer's Fervour. The other two are Karl Franz's Elector's Favour (the politics
     feature) and Wulfhart's Imperial Supply Train (his faction, human only).
2. **An earning of its own.** There are seven routes (`GG.EARN_ROUTES`), paid through
   `GG.capped_grant`, so the turn limit, the rival's share and the patron all apply:

   | Race | Route | Guild key | Reputation |
   |---|---|---|---|
   | Chaos Dwarfs | a caravan (convoy) completed | brass | 60 |
   | Cathay | a caravan completed | brass | 60 |
   | Dwarfs | settled grudges | immortals | 1 per 5 points (was 10 per rise until the 2026-09-29 logic audit) |
   | Empire | land of the old Empire taken back | immortals | 50 |
   | Kislev | a Motherland ritual begun | daemonsmiths | 40 |
   | Bretonnia | Chivalry | immortals | 1 per 5 |
   | Dark Elves | Slaves from raiding or battle | slavers | 1 per 20 |
   | High Elves | a court action that succeeded | khanate | 40 |

   Each earning writes one Log line under Mine, stating what the guild actually gained,
   and writes nothing when that is 0.
3. **One rule bent** (`GG.TWISTS`, whole percentages, applied by `GG.setting_for`):

   | Race | Rule |
   |---|---|
   | Chaos Dwarfs | demands every 8 turns and paid at 180 |
   | Dwarfs | a failed bounty costs 150%, an expired demand 200% |
   | Empire | rivalry 60% |
   | Kislev | upkeep halved |
   | Bretonnia | a paid demand 150%, an expired one 200% |
   | Cathay | rivalry 20% |
   | Dark Elves | rivalry 60%, hostile services 75% of the price |
   | High Elves | favour cap 3x the rank's threshold |

   A rule at 0 stays 0, and a rule that is on never rounds down to off.

Also in this build:
- **Slave Tithe** now pays Kislev 150 Devotion (gold for a Kislev faction without it) and
  the Dark Elves 1,000 Slaves.
- **A race card says so**, with a yellow race label before its text (`GGUI.card_body`).
- **Help page 6, "Your race"**, per flavour: the rotation, the race's own services, its
  earning, its rule, and the off-switch.
- **A service whose hook has gone since the draw** (a caravan home, a pool lost, the
  grudge cycle resolved) is refused at the till as "Unavailable", and costs no favour.

## 3. Rulings and findings

From the ledger:
- **`is_chd` read an unfilled culture cache as Chaos Dwarf.** A payload reached before any
  `GG.covered` call would pay a Kislev faction armaments. It was unreachable in game,
  because `can_buy` fills the cache first. It now fills the cache itself, as
  `GG.flavour_of` does.
- **"Whispers at Court" became "Favours at Court".** The High Elf flavour already names the
  shared Khan's Price that, and `check_flavours` refuses two cards of one name.
- **Six pre-existing tests now pin `race_differences = false`**, because they are about
  demands, the ledger or the first draw, and their factions are Chaos Dwarfs, whose rules
  are now bent:
  - three main-harness sections, plus the first-draw block;
  - the stage 1 catalogue test, which now counts shared rows only.
- **Three mutant anchors went stale and were moved**, each to the code its check aims at:
  - a rival's failed bounty now passes the faction;
  - the pool's hostile check now precedes `GG.needs_ok`;
  - the unit room check now also reads `s.room`.
- **Probes added so every new generator check is proven by breaking it once** (spec §11):
  - a misspelt Hell-Forge ritual;
  - the blunderbuss message fix removed. This also proves CA's own key names no incident;
  - a literal Lua pool grant moved to an unbound factor;
  - a drifted earn route;
  - a drifted twist.
- **`check_race_keys` reads `group_key`** (the key column of `region_groups`) as well as
  `key` and `unit`.
- **Mutants:** 122, all caught. The first run had two survivors:
  - "a race service forced with race differences off" was an equivalent mutant: with race
    differences off, the pools hold no race row. The dead guard and its mutant were deleted.
  - "a demand's timing read without the race" was a real gap. It is now pinned by a Chaos
    Dwarf 8-turn demand and a Dwarf 200% expired demand, plus a penalty mutant.

**The final review** (Opus, fresh context, whole diff) found no Critical faults. Two fixes:
- **Slave Coffles ate the next raid's earning.** Every pool purchase was recorded as the
  buyer's own, including one granted through a factor the route ignores (`missions`). That
  record was never spent by its own change, so it swallowed the next real Slaves. Now a
  purchase is recorded only when its route counts its factor.
- **A refused Supply Train kept the favour.** `cm:trigger_dilemma` answers false when the
  director declines, and multiplayer triggers it directly. The payload now throws on false,
  so `GG.buy` refunds, as stage 1 promised for any service that fails to arrive.

Also corrected, records only: the reason the Bretonnian route skips `missions`. CA's
`payload.chivalry` grants every mission's Chivalry reward through it, and the mission
already pays the guilds.

Deferred, player-visible:
- The Dark Elf discount is explained as the guild knowing you.
- The Bretonnian Help text says all Chivalry pays, but mission Chivalry does not.
- `whispers_at_court` is the key of "Favours at Court".
- Nothing asserts that every race row has its `GG.RACE_FIRE`.

The full ruling list is in the ledger.

## 4. Check in game

Nothing offline can prove these:
1. **Labour Gangs** puts labour into a province. A stored note contests per-province pools,
   but CA's own `labour_loss.lua` uses this exact route.
2. **Hell-Forge Allotment** raises a cap with a commission rite in flight. The rite
   survives, and the next paid cap is not dearer. Roll the blunderbusses once and see the
   message.
3. **The Lady's Blessing and Tales of Valour**, called from a mod.
4. **Call the Reckoning:**
   - offered only at the top level;
   - resolves at the next turn start and pays that level;
   - the card goes Unavailable if the cycle resolves first.
5. **Other CA hooks:**
   - the Compass can be turned again at once (a cooldown of 0 was only ever inferred). Also
     buy it with the compass already free: it is sold, and does nothing;
   - caravan cargo rises;
   - Elector's Favour lands on the least loyal Elector;
   - the Supply Train dilemma's reinforcements arrive.
6. **High King's Decree** persists across a turn (`reset_before_income` is set on the pool).
7. **The hidden-line bundles** (Witch Hunters' Warrant, Peasant Levies, Black Ark Tithe):
   the number is in the text.
8. **Bought Loyalty** raises a lord's loyalty.
9. **Each earning writes its Log line:** a caravan, a grudge, a reclaimed settlement, a
   Motherland ritual, Chivalry, Slaves, a court action.
10. **The Phoenix King's Favour** at its cap: the excess is cut off silently.
11. **A long race card reads in full** with its yellow label. `GGUI.wrap` measures the
    `[[col:]]` tags with `TextDimensionsForText`, which may count them as width. If it does,
    the card cuts one word early with " ...", and the tooltip keeps the full text.
12. **Race differences off in a new campaign:** no race card, no earning Log lines, and
    Chaos Dwarf demands every 12 turns.
