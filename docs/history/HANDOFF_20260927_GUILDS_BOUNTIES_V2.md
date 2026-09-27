# Handoff 2026-09-27 - Great Guilds bounties v2 (built, not yet played)

Spec: `docs/superpowers/specs/2026-09-27-great-guilds-bounties-v2-design.md`.
Plan: `docs/superpowers/plans/2026-09-27-great-guilds-bounties-v2.md` (12 tasks, all done).

The player's complaint: the board offered missions against factions the player was already
fighting, which they would have done anyway, so the pay came free. v2 makes every offer a
choice.

## Build

| | |
|---|---|
| Pack | `Modding Files/Modpacks/derpy_great_guilds.pack` |
| MD5 | `7AB4585DC0B61C952AA5F151A69091D8` |
| Size | 32,469,435 bytes |
| Previous | `7F9D5CF2`, backed up as `derpy_great_guilds.pack.bak_20260927_pre_bounties_v2_7f9d5cf2` in `Modpacks/` and in `data/`. The pre-review build `6265B4FE` was deployed briefly, never played, and is kept as `data/derpy_great_guilds.pack.bak_20260927_6265b4fe_pre_review_fixes` |
| Verified | `import_great_guilds.py --verify-only` green; all five scripts in the pack are byte-identical to `Modding Files/pack/` |

Deployed to `data/` with the game closed, MD5 compared.

## What changed

- **Military offers** (§3): a far enemy (never an owned region, a region next to one, or a
  lord within squared distance 50000 of a player settlement or army), or, one roll in three,
  a **new war** on a faction the player is at peace with. A new war pays gold x2 and
  Reputation x1.5. Allies, pacts, vassals, clients, humans and the dead are never targets.
  The distance from the player adds to the price.
- **The favour stake** (§4): taking puts up `ceil(rep * rate_bounty_stake / 100)` favour
  (MCT, default 25; easy 15, hard 35, ultra 50). It is refunded on success or when the mod
  voids the offer, and lost on hand-back or failure. The card's price plate shows it, and
  Take is red and disabled when the player is short.
- **Jobs** (§5): Brass hold gold (the figure is fixed at take), Immortals a lord or hero at
  rank R, Daemonsmiths research a named tech, Slavers take N captives. Every guild can
  request a tier 3+ building it is paid for.
- **Hero bounties** (§5.5): Daemonsmiths sabotage a settlement (2 actions), Immortals harry a
  lord's army (2), Khanate wound or assassinate a named lord or hero (1). SCRIPTED
  objectives are counted off the agent-action events, the front is allowed, and they work for
  every race, including Dwarfs and Empire.
- **Mission rows**: 171 in all, one per guild per family (`bounty`, `job`, `build`, `hero`)
  per flavour (9).
- **The save**: five fields appended to each offer (`war`, `stake`, `amount`, `done`,
  `void`). An older save loads them as zero.

## Coverage (Task 6, generated into `zzz_derpy_guilds_bounty_data.lua`)

Techs a research job can name: chd 41, `_emp` 47, `_dwf` 39, `_brt` 34, `_cth` 37,
`_ksl` 41, `_def` 27, `_hef` 59, plus 17 for `wh_main_emp_empire_qb5`.

Buildings a request can name, per guild:

| Flavour | brass | immortals | daemonsmiths | khanate | overseers | slavers |
|---|---|---|---|---|---|---|
| chd | 0 | 6 | 2 | 0 | 2 | 1 |
| `_emp` | 0 | 3 | 2 | 0 | 7 | 0 |
| `_dwf` | 3 | 2 | 5 | 0 | 5 | 0 |
| `_brt` | 0 | 3 | 0 | 0 | 9 | 0 |
| `_cth` | 0 | 4 | 1 | 0 | 8 | 0 |
| `_ksl` | 5 | 3 | 0 | 0 | 11 | 0 |
| `_def` | 0 | 3 | 0 | 0 | 7 | 0 |
| `_hef` | 0 | 2 | 1 | 0 | 9 | 0 |

These are the numbers AFTER the final review's filter. The first build's lists were mostly
levels a player can only build in some places. `building_levels.resource_requirement` is
blank on every resource chain, so `bounty_buildings` now also drops:
- chains whose superchain is a resource, port, main-settlement, foreign, allied or special
  slot;
- chains named `special_`, CHD `_tower_`, `horde`, `spirit_of_grungni`, `dragonship`,
  `kislev_city`, `underdeep`, `bastion` or `sea_patrol`;
- any chain that no `building_chain_availabilities` set grants race-wide in every campaign.

`check_bounty_data` refuses all three.

A zero means that guild never asks for a building in that race; it falls back to its other
kinds. `_gen` has no building list, so generic factions get no building requests.

## Tests

- `tools/_guilds_bounty_harness.lua` (new): one block per task, stub world, including the
  re-entrancy of `complete_scripted_mission_objective`.
- `tools/_guilds_harness.lua`: widened stubs, plus a Task 10 card block.
- `tools/mutate_guilds.py` (new): **12 mutants, 12 caught**, and the model and UI are
  byte-identical after the run. It found one missing test on its first run: hero progress
  not being saved as it is counted. That test is now in the Task 8 block.
- `gen_great_guilds.py --selftest/--check`, `import_great_guilds.py --check` (it now
  mirrors `GG.BOUNTY_EXTRA`), `gen_guilds_ui.py --check`, `check_guilds_ui.py`,
  `preview_guilds_panel.py --check`, `luac`, `check_lua_api`, `check_lua_literal_left` and
  `check_lua_undeclared`: all green.
- Preview: `.skilltree_cache/ui_preview/gg_bounties.png` shows a new-war card, a building
  request the player is short of favour for, and a taken sabotage at (1/2). No line runs
  past its card; `render_bounties` measures this rather than leaving it to the eye.

## The opener button missed turn 1 (reported from play, same day)

The script log from a Middenland load of 7F9D5CF2 (`script_log_270926_1108.txt`) shows
`GREAT GUILDS: GAVE UP - no usable resources_bar reading (unsettled)` at 115s. The intro
kept `resources_bar` off-screen until about 320s, when the Zharr Exchange placed its
button. `GGUI.BTN_TRIES` was 12, which is 24 seconds. The Exchange had measured this race
on 2026-09-06 and moved to 150, but the Guilds button never got the change. Nothing tried
again until turn 2 started, and the player first clicked the button at 574s.

Fixes, in build 91BCEAA8:
- `BTN_TRIES = 150` (5 minutes). The chain still stops at the first placement.
- `GGUI.btn_chain`: only one retry chain at a time. While the button is unplaced, each of
  the ~190 FactionTurnStarts a round would otherwise start its own chain.

The `_guilds_harness.lua` block "the opener outlasts the intro" failed on both counts
first: it gave up after 11 tries, and with the guard deleted a round queued 190 chains.

## The opener buttons now FOLLOW the strip's end (same day, after the revert below)

The player asked why the buttons did not adjust when the bar moved ("or stay still").
Placement ran only at load and turn start (and, for the Exchange, at panel open). There
is no event for a component changing size, so a bar that widened mid-turn slid under the
button, and the button jumped at the next turn start. Staying still beside a bar that
grows from its centre is not possible without being covered.

Both mods now poll on the UI clock:
- `cm:repeat_real_callback`, every 300ms, named `gg_follow_bar` / `zharr_follow_bar`;
- each poll re-reads the anchor, and calls MoveTo only when the answer changed;
- it does nothing until the button is placed, nothing while the strip is away, and the
  Exchange never follows onto its docker fallback;
- the refuse-or-clamp rule is now one function per mod (`GGUI.fit_opener`,
  `EX.fit_button`), shared by placement and the poll.

It is local and UI-only, so it cannot desync multiplayer. Tests, each failing first:
- the `_guilds_harness.lua` block "the opener follows the strip";
- the `followed` / `follow_away` asserts in `gen_zharr_exchange.py --selftest`.

Shipped as Guilds `7AB4585D` (`data/`) and Exchange `F4A8492D` (Workshop `3798516851`).
Only the one script in each pack changed; every DB table was decoded and matches the
previous build row for row.

## The two opener buttons kept moving (reported from play, same day) - TRIED AND REVERTED

**Reverted at the player's request, same day: "revert the changes, put it besides the top
bar".** Both buttons are back off the strip's right end, and move with it again. The shipped
packs are the pre-change ones, restored byte for byte: Guilds `91BCEAA8` in `data/`, and
Exchange `4D33C778` in the Workshop folder. The source, the tests and the
`gen_guilds_ui` pin were reverted with them. Build `219961E9` / `7020DE92` is what is
described below, kept as a record of what was measured and tried. Do not re-apply it
without asking: the player prefers the buttons beside the bar, even though they move.

Both the Guilds and the Zharr Exchange buttons were placed off the RIGHT END of
`resources_bar`. CA's `hud_campaign_resource_bar_wh3.twui.xml` (ui3.pack) docks that
strip `Top Center`, anchor 0.5, with a `HorizontalList sizetocontent="true"`, so it grows
both ways as effect icons and faction widgets come and go. Its right end measured
1294..1452 across the day's logs: Middenland's Drakwald threat bar alone moved the
Exchange from 1306 to 1441.

The top row has no fixed free spot. The top-right cluster `bar_small_top` is docked right
at 414-440 wide, so on a 1920 screen it starts at about x=1480, and the widest strip left
under 50px beside it. The player chose a second row under the strip.

Both mods now place from the strip's CENTRE, which does not move, one gap below its
bottom edge:
- Exchange: `x = centre + EX.BUTTON_ROW_RIGHT (380) - 48`;
- Guilds: 4px left of the Exchange, centred on its 48px row.

On 1920 that puts them at 1224 and 1272, y=60. 380 clears the two widgets CA hangs
below the strip's middle: the Drakwald bar (to x 1215, y 68) and the Dwarf grudge holder
(to x 1094, y 85). **Check in game** that nothing else hangs there for other races.

Tests, each failing first:
- `gen_zharr_exchange.py --selftest` expects `1774,60` and a `wider` case (the strip 300
  wider around the same centre must not move the button);
- `_guilds_harness.lua` has the same test for the Guilds, with and without the Exchange;
- `gen_guilds_ui.check()` pins the Guilds' fallback copy of `EX.BUTTON_ROW_RIGHT`, and was
  watched refusing 360.

The Exchange (MD5 `7020DE92`) is deployed to its Workshop folder
`3798516851`. The previous copy is kept as
`Modpacks/derpy_zharr_exchange.pack.bak_20260927_pre_button_row_4d33c778`.
`import_zharr_exchange.py` has no `--help` and builds on any flag; that is how this build
was made. Its DB tables were decoded and match the Workshop copy row for row.

## Final review (fresh reviewer, most capable model)

It found no Critical findings, two Important and six Minor, and all five Review Focus items
hold. Three fixes went in, each test-first (RED, then GREEN):
- **Building requests named levels most players cannot build.** Fixed by the filter above.
- **Lord and character offers were not withdrawn on peace or a pact** (spec 3.5).
  `bounty_still_valid` now applies the town rules to the lord's owner.
- **The stake was not saved before the trigger call.** A reload inside the call gave the
  bounty for free. `take_bounty` now calls `GG.save` next to `GG.save_bounties`. This was
  the reviewer's Minor, re-graded because it breaks the file's own save-first rule.

Deferred minors:
- the kind roll is not uniform;
- an untaken harry whose lord has lost his army stays on the board;
- research pricing hits the cap for four races;
- the opener badge counts offers the player cannot afford;
- the old harness never restores `GG.BOUNTY_EXTRA`.

## Rulings (each with its cost if wrong)

From the plan:
- **T4-R1**: a 3 on the d3 means new war, so a harness with no random source keeps the old
  meaning. *Cost:* none; the odds are the same.
- **T3-R1**: if the model cannot tell where the front is, the target counts as off the front.
  *Cost:* a broken lookup lets a front-line target through.
- **T5-R1**: the refund ignores the favour cap. *Cost:* a player can sit above the cap by one
  stake.
- **T7-R1**: a job with no map target stores its kind key as the target. *Cost:* none.
- **T7-R2**: the coffers figure is fixed at take. *Cost:* none.
- **T8-R1**: voids run after the turn's board save, one at a time, re-reading the board.
  *Cost:* none.
- **T9-R1**: one title per kind; the description names the race's own guild. *Cost:* a pass
  of flavour writing, with no code change.
- **T9-R2**: the research row's `mission_type` column says `RESEARCH_TECHNOLOGY`, while the
  string uses `RESEARCH_N_TECHS_INCLUDING`. *Cost:* none known; in-game check 7 covers the
  string route.
- **T10-R1**: the price plate shows the stake, not the gold. *Cost:* none.

Made during execution:
- `GG.BOUNTY_PICK` and `GG.BOUNTY_VALID` are declared early, because
  `check_lua_undeclared` refuses otherwise. *Cost:* none.
- The MCT `rate_bounty_fail` tooltip, `bounty_fail_primary` and help pages 3 and 5 no longer
  say a hand-back is free. *Cost:* none.
- `bounty_buildings` accepts culture-blank variant rows. An exact-culture match found 0
  Immortals buildings for CHD. *Cost:* none found.
- `take_bounty` order is stake, then coffers, then string, then mark, then trigger. A refused
  stake changes nothing. *Cost:* none.
- The old harness's board block runs with `GG.BOUNTY_EXTRA = {}`, and the new harness covers
  mixed boards. *Cost:* the old block no longer sees jobs.
- `hero_action_matches` uses `string.find` without the plain flag, because the plain flag
  breaks the game's string library. *Cost:* none; the words are plain.
- Every `GGUI.loc` key is spelled out whole, so `check_loc_keys` can verify each one.
  *Cost:* none.
- `mutate_guilds.py` reads only the first stderr line to decide whether a harness assertion
  was the catch. *Cost:* none; the selftest pins it.

## In game (the nine checks from spec §9, verbatim)

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

Added by the final review:

10. `cm:cancel_custom_mission` raises MissionCancelled. If it does not, a voided hero
    bounty never leaves the board and its stake is never refunded.

Not pushed to GitHub or the Workshop.
