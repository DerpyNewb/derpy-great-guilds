# Handoff 2026-09-29 - Great Guilds: rivals take bounties

Spec: `docs/superpowers/specs/2026-09-29-great-guilds-ai-bounties-design.md`. Plan:
`docs/superpowers/plans/2026-09-29-great-guilds-ai-bounties.md`. Sub-project 1 of 3 the user
asked for on 2026-09-29; the other two (more offer variety, per-race mechanics) get one spec
between them, later.

| Build (MD5) | What | Backup of the previous live pack |
|---|---|---|
| `294B90A4` | rivals take bounties; a bounty on a human is announced | `data/derpy_great_guilds.pack.bak_ai_bounties_20260929` (= `C7DD5E99`) |
| `BB0FB116` | final-review fixes: a rival's targets only on its own front, no two-hit hero work, no walk when broke, a per-round count in the log | `data/derpy_great_guilds.pack.bak_ai_bounties_review_20260929` (= `294B90A4`) |

Deployed to the game's `data/` with the built and live MD5s matched. Not uploaded to the
Workshop (the Guilds have no Workshop item). Not pushed to GitHub.

## 1. What shipped

- **A rival holds at most one bounty** (`GGAI.bounty[faction]`, saved as
  `derpy_gg_ai_bounty_<faction>` in the player board's own offer format, now shared through
  `GG.pack_offer` / `GG.unpack_offer`). Kept out of `GG.bounties`, whose walkers call the
  engine's mission functions.
- **Taken in the AI round** (`GGAI.run_turn` -> `GGAI.bounty_sweep`): only a faction with
  standing and `GG.covered`, only when it holds nothing, from the first guild whose stake it can
  afford (checked before any walk). Targets are factions it is already at war with, humans
  allowed, **only on the rival's own front** (regions it owns or borders; lords and heroes
  near its settlements or armies), never a new war, never Fill the Pens, harry or sabotage,
  never a target another rival holds.
- **Scored by the mod**: region owned, treasury, highest rank, tech, building read at the sweep;
  a sack by the holder, N matching hero successes, and a target's death (by anyone) marked from
  the existing listeners. Done pays stake back + Reputation + gold; a hero target gone refunds
  with no penalty (harry/sabotage only, which rivals no longer take - the path stays for a
  bounty an earlier build left held, so `hunt_void` is now close to never seen); 20 turns from the take fails at the player's `rate_bounty_fail`.
- **A bounty on a human**: a transient LOCATED feed message (new record base 5005, per race
  5005 + offset) that zooms to the target, and a `hunted` Log line naming the target and the
  rival. Its end reaches the same human as `hunt_done` / `hunt_failed` / `hunt_void`.
- **The race**: when a rival of a human's race finishes any bounty on someone else, that human's
  Log gets `ai_bounty` ("Clan Y finished a bounty and earned 80 Reputation").
- **MCT**: "Rivals take bounties" (`ai_bounties`, default on, appended to `GG.TUNE_ORDER`).
  `rate_bounty = 0` also stops them.

## 2. The correction found while planning

`GG.covered` is true only for a culture a human plays, so only rivals of the player's OWN race
hold guild standing and can take bounties. A price on the player comes from a same-race rival
at war with them - common for the Empire and the Dark Elves, rare for the Dwarfs and High Elves.
The design conversation had assumed any covered race could; widening coverage is its own change.

## 3. The final review

A fresh reviewer (opus) found no Critical and one Important: at the default failure cost a
rival breaks even only if it finishes about 56% of its bounties (a failure costs the full
Reputation plus the stake), and it was picking targets uniformly from every enemy on the map
and taking two-hit hero work nobody aims. Fixed as above, plus the script log line
`derpy_gg: rivals' bounties turn N: a taken, b paid, c failed, d withdrawn` on every round
that did anything - the only record of a rival's failed bounty, and what the soak reads.
Its Minor 2 (walks before the stake check) was re-graded Important and fixed. Deferred:
the `hunt_failed` line says Reputation was lost when none was; a dead lord's name drops out
of his Log lines (`character_details()` might keep it, unmeasured); a reload during the
human's turn re-runs the round's sweep; a throw inside `GG.grant` loses a rival's payout; two
test gaps. All in the ledger's `Final:` lines, copied into the final message.

## 4. Rulings made while building (from the ledger)

- The model and AI tests went into `tools/_guilds_bounty_harness.lua`, not a new harness file:
  that harness already stubs a world with wars, regions, lords and positions, and
  `mutate_guilds.py` already runs it. The Log-text test is an IIFE at the end of
  `_guilds_harness.lua` (the only harness that loads the panel).
- Two existing mutant anchors (front line) moved with the `ai` flag and were re-aimed.
- `gen_great_guilds.py --selftest` pinned four feed records per race; it now pins five, and the
  fifth's type and indices.
- `hunt_failed` and `hunt_void` draw plain, not red: a hunt on you failing is good news.
- The `run_turn` wiring gets its own mutant, since its test never failed alone.

## Verified

- Both harnesses green; `mutate_guilds.py` 41/41 caught (17 new).
- `gen_great_guilds.py --check` / `--selftest` / `--write`, `gen_guilds_ui.py --check`,
  `import_great_guilds.py --check`: clean. The new `persistent=false` mirror check proven by
  flipping the Lua to `true` (caught; file restored byte-exact).
- `luac -p` on all five Lua files; `check_lua_api.py` 0 on the guild files;
  `check_lua_literal_left.py` 0; `check_lua_undeclared.py` unchanged from the pushed copies
  (pre-existing cross-file globals), AI file clean.
- `import_great_guilds.py` built and re-verified the saved pack; the packed model, AI, panel and
  MCT scripts are byte-identical to the workspace.

## In game (not yet played)

1. `GG.trace("agent action reached AI faction ...")` appears once a session after an AI turn -
   the proof that rivals' hero bounties can count at all. CA's followers script filtering these
   events with `is_human()` suggests they fire for the AI; unmeasured.
2. The located feed message draws in the strip and its zoom goes to the target.
3. A rival's Leaderboard Reputation moves after its bounty pays, and the Log says so.
4. **The soak:** 30+ turns with a same-race rival, then count the `rivals' bounties turn`
   lines. Paid over paid+failed below ~0.56 means rivals still lose Reputation on the
   default failure cost; the lever is `rate_bounty_fail` for rivals, not the targets.
5. The ten in-game checks in `HANDOFF_20260927_GUILDS_BOUNTIES_V2.md` are still unplayed.

## Do not re-derive

- A located feed call needs a `scripted_transient_located_event` / `_persistent_located_`
  record; against a plain one it logs success and draws nothing. The donor row is
  `wh2_dlc10_event_feed_scripted_defender_of_ulthuan_bad`.
- Feed indices 5001-5004 are hit, demand, lead, rank; 5005 is hunted. Each race adds its own
  offset (emp 10, dwf 20, gen 30, brt 40, cth 50, ksl 60, def 70, hef 80).
- A rival's bounty uses `posted` as the turn taken: a rival takes at the moment of posting.
