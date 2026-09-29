# Great Guilds: logic audit and fix pass (2026-09-29)

Asked for: "do a full check for logical issues", then "Everything" - fix every Critical,
Important, minor and wording fault in one pass.

Ledger: `.superpowers/sdd/2026-09-29-great-guilds-logic-audit/progress.md` (the ruling notes
are there; `base/` holds the eight files as they were at `B69679D0`).

## 1. Builds

| Build | What | State |
|---|---|---|
| `B69679D0` | stage 2 after its final review | replaced; backup `.bak_logic_audit_20260929` |
| `8AA9DDC1` | this pass | **live in `data/`**; MD5 `8AA9DDC1ED5B070FCD504E1D3A7D6CBF`, 33,883,860 bytes. Not pushed; no Workshop copy of this pack exists |

## 2. How the audit ran

Seven read-only reviewers, one per slice: persistence and multiplayer, earning and the
ledger, the till and services, bounties, leadership and the Court, the campaign AI, and the
text (MCT, Help, feed, cards). Every finding was then checked against the code before it was
accepted. Two claims needed CA's own files to settle:

- `cm:region_slot_instantly_upgrade_building` is documented as returning nil, while CA's
  `custom_starts` reads a building from it. The payload now reads the slot back instead of
  trusting either.
- The Dwarf grudge scale: trespass 10, attacked 30, occupation 45 per tier. CA pays one
  battle's grudges as one change per winning army, so a flat sum per change paid a two-army
  win twice. The route now pays one Reputation per 5 points.

## 3. What was fixed

### Critical

| Id | Fault | Fix |
|---|---|---|
| C1 | After a load, the patron, the demand, the research subject, the bounty board and the world record were re-read only at the owner's turn start or when the panel opened, and the panel opens on one machine. `GG.service_cost` reads the patron, so one machine priced a sale with the discount and another without it: a multiplayer desync. | `GG.load_all()` at the first tick restores every record for every covered faction, the humans by name as well. The panel's own loads are gone. |

### Important

| Id | Fault | Fix |
|---|---|---|
| I1 | A new campaign drew its first cards on turn 2, because no `FactionTurnStart` fires on turn 1, so the first period had the original cards and no race service. | `GG.first_cards()` at the first tick when `cm:is_new_game()`, in sorted faction order. |
| I2 | A loaded post left the patron bundle on the old army. | The save is now `guild,cqi,force`; an old `guild,cqi` save falls back to the lord's army. |
| I3 | Appoint accepted any selected lord, including an enemy's, whose army then kept the bundle for good. A hero ended the pick on a dead button. | `GG.force_cqi_of(cqi, faction)` checks the owner; a vacated post takes the bundle off; the panel's pick needs one of your own lords with an army (`GGUI.patron_cqi`). |
| I4 | A bounty could ask for a technology another faction owns (Aislinn's, Ostankya's, the Elector Counts'), which the player can never research. | `bounty_techs()` drops a node whose `faction_key` is another faction's; 164 such nodes sit on the race trees. `check_bounty_data` fails on one. |
| I5 | After a load, a lead held within the margin went to the rival silently. | `GG.hold_lead` reads the holder from who wears the lead bundle when this session has not looked yet. |
| I6 | The favour cap took favour already held: after a demotion, one point earned cost up to 700 favour. | The cap stops the gain and never takes. |
| I7 | The AI's once-per-round guard was session memory, so a load swept the round again: a second purchase for every rival. | Saved as `derpy_gg_ai_turn`. |
| I8 | Five MCT options changed rules mid-campaign. | Locked in a running campaign: `ai_spending`, `ai_bounties`, `hostile_services`, `guild_notices`, `lead_monopoly`. |
| I9 | Every promotion said "a service that was closed to you is open", including Exalted, which opens none, and Favoured, whose services are the leader's alone. | Per-rank text; `check_promotion_text` measures it against `SERVICES`. |
| I10 | The panel read the selection at click time, so a card drawn "Select" bought at once after an army was clicked, and a Confirm landed on whatever was selected at the second click. | Four selection listeners redraw an open panel and drop a pending Confirm. |
| I11 | The Ziggurat took the first upgrade, whatever its branch: Cathay's yin became yang. An upgrade the engine refused kept the favour. | Same-stem upgrade first; the slot is read back, and a mismatch throws, which refunds. |

### Minor

m1 a turn's earnings saved with the turn (`derpy_gg_gain_<f>`); m2 a race earning's
remainder saved (`derpy_gg_carry_<f>_<route>`); m3 no world gain across a change of hands;
m4 the roster refreshed each round; m5 one battle pays once per faction; m6 grudges per 5
points; m7 a lead that lapsed to nobody has its own Log line and no popup; m8 the MCT's dump
button is heard (`gg_dump`); m9 a demand's due turn counts as one left; m10 the patron op
sends `appoint|` or `dismiss|`, so a second press cannot undo the first; m11 Take sends the
offer's guild, not a board position; m12 the badge counts what the board shows; m13 the
Leaderboard explains a held lead; m14 Bought Loyalty and The Lady's Blessing say their own
rule; m15 the footer shows the favour of the guild on screen; m16 no "upkeep begins on turn
25" once it has begun; m17 the Reckoning needs a finished cycle; m18 Labour Gangs needs a
province with labour; m19 Hobgoblin Eyes says "for this turn", not "permanently"; m20 the AI
Court step skips an uncovered faction; m21 the AI never aims at a dead faction or the rebels,
and a settlement service needs an enemy with a settlement; m22 the standings still move with
the AI switched off; m23 the preset note on the custom sliders.

### Text

t1 raze "60% more" (MCT); t2 the patron "pays more" and costs "up to 10% less"; t3 the Easy
preset's description; t4 an ignored demand "can cost" a rank; t5 rivalry never takes a rank,
and the Help says so; t6 the failed-bounty feed names the favour and the card's sum; t7 every
static monopoly sentence carries "unless the settings say otherwise"; t8 the upkeep tooltip
names failed bounties; t9 the hidden-number check is a signed, delimited match
(`states_value`), where the substring test found the 1 of "+1" in "15 turns".

## 4. Rulings

- The favour-cap test starts at 290, not 500: the cap no longer takes.
- "A loaded post must re-assert its bundle once" became "re-applies nothing": the army is
  saved with the post.
- The change-of-hands world gain is 0, not 650: the tooltip reads "Leader gained N".
- The old grudge test expects 6, not 10 (30 points at one per 5). Balance only.
- t1 needed no generator edit: the Help says "more when razed", which is true.
- t2 is text, not numbers: the share is a 0-200 slider and the cut sits inside the -30%
  clamp. The patron's discount stays weak at a high rank.
- t7 uses the Help's own idiom on the static strings rather than a draw-time sentence: loc
  cannot read an MCT switch, and the panel's live lead lines are already gated on it.
- Rank 5's promotion says "There is no higher rank."; rank 4 names the lead condition.

## 5. Proof

- Every code fault was a failing harness test first, then green.
- Both harnesses green; `gen_great_guilds.py --selftest` and `--check` clean; `luac -p`,
  `check_lua_api`, `check_lua_literal_left` clean; `check_lua_undeclared` reports the same
  cross-file names as at `B69679D0`; `gen_guilds_ui.py --check` clean; line endings kept
  (model and bounty data LF, AI, UI and MCT CRLF).
- **Mutants: 167, all caught** (`tools/mutate_guilds.py`). 45 are new, one per guard this
  pass added. The first run left 11 of them alive, and each got a test:
  - the human's bounty board at the first tick;
  - the first tick drawing a new campaign's cards, and never a loaded one's;
  - a vacated post unbundling its army;
  - a saved post keeping its army when the lord moves to another;
  - a turn start clearing the saved earnings;
  - the dump listener hearing the event the MCT button raises, read out of the MCT file;
  - `pick_enemy` with `need_regions`;
  - `GGUI.patron_cqi`;
  - Take sending the offer's guild;
  - the footer's favour.
- It also exposed two older tests my fixes had disturbed:
  - "slot plus building key fires" passed the string `"slot_obj"` as a slot. Since the
    read-back, that sale refunded itself unseen. It now uses a real slot and asserts the
    sale stands.
  - The Reckoning's "a rival never holds it" passed only because the new cycle guard
    refused the rival first. The rival now has a running cycle.
- Generator checks were proven the same way: `check_bounty_data` reported 121
  faction-locked techs before the fix and 0 after. `check_promotion_text` fails 54 ways
  when the services move. `states_value` fails a stripped number that the old substring
  test passed.
- Fixture additions: `W.ci`'s army honours `t.force`; the listener stub records
  `EVENTS[name]`; `add_first_tick_callback` records `FIRST_TICK`.

## 6. In game, not yet seen

- A load mid-turn in multiplayer: both machines price a patron's guild the same.
- A new campaign's turn 1 shows a race service.
- Appoint with an enemy lord selected keeps the pick open.
- A Ziggurat on a yin building upgrades to yin.
- Hobgoblin Eyes' region closes again at the next turn (the wording now claims it does).
