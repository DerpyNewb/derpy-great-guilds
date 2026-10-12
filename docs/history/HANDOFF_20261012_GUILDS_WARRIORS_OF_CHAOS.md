# Great Guilds: the Warriors of Chaos as "The Dark Gods" (2026-10-12)

Tenth race of `derpy_great_guilds.pack`. Spec:
`docs/superpowers/specs/2026-10-12-great-guilds-warriors-of-chaos-design.md`. Plan, with its 16
plan-time rulings: `docs/superpowers/plans/2026-10-12-great-guilds-warriors-of-chaos.md`.

**Built** 2026-10-12 13:00 after the final review's fix pass and the MCT taint tooltip fix,
MD5 `1c79fd97ef4b0ccaae83ab1e49eb401f` (55,227,622 bytes, 544 files). Saved pack verified by the
importer. **Deployed to the Workshop folder** (item 3815248936); the MD5s match. Not in `data/`.
**Not uploaded**: that is the author's call.

The pre-build copies (`bb7a22ce`, Modpacks and Workshop identical) are in
`Modding Files/Backup/guilds_pre_chs_20261012/`; the first build, `9ed7d543`, is in
`Modding Files/Backup/guilds_pre_review_fix_20261012/`, and the review-fix build, `658bf0e1`,
in `Modding Files/Backup/guilds_pre_mct_fix_20261012/`.

## The race

Tag `_chs`, culture `wh_main_chs_chaos`, feed 100. Gods, not guilds; Devotion (rank) and Favour
(spent). A word pass (`CHS_WORDS`, `CHS_EXACT` in `gen_great_guilds.py`) rewrites every `_chs` loc
line after it is built: guild to god, Reputation to Devotion, leader to Champion, and singular
verbs for a god's name ("The Blood God has ordered").

| Slot | God | Pays for | Rival | Hall's second effect |
|---|---|---|---|---|
| immortals | The Blood God (Khorne) | battles won, doubled when outnumbered | Dark Prince | Marauders of Khorne in the province +1/2/3 |
| slavers | The Dark Prince (Slaanesh) | sacking; razing pays more | Blood God | Marauders of Slaanesh +1/2/3 |
| overseers | The Plague Lord (Nurgle) | growth, unclaimed buildings | Changer of Ways | Marauders of Nurgle +1/2/3 |
| daemonsmiths | The Changer of Ways (Tzeentch) | technologies | Plague Lord | Marauders of Tzeentch +1/2/3 |
| brass | The Doubter (Necoho) | income | Undoer | none (its hall effect is income) |
| khanate | The Undoer (Zuvassin) | hero actions | Doubter | enemy heroes' success there -10/-15/-20% |
| temple | The Undivided | Chaos Undivided corruption, wins over the Empire, Kislev and Cathay, unmarked Sorcerers | none | Chaos Undivided corruption +2/4/6 |

**New rules in the model** (`zzz_derpy_guilds.lua`):
- **Per-race rivals.** `GG.RIVALS_RACE` and `GG.rival_of(faction, guild)`. All eight reads of
  `GG.RIVALS` go through it, and the other nine races keep the global table.
- **Gifts.** Souls spent into CA's five `wh3_dlc20_chs_souls_spent_*` pools pay that god, 1 Devotion
  per 25. Each god keeps its own remainder (`GG.POOL_GUILD`, `race_earn`'s fourth argument).
- **Taint by resource.** `TEMPLE_ROUTES.taint` names its pooled resource, so the Skaven read Skaven
  corruption and the Undivided read Chaos Undivided corruption.
- **The Doubter never makes a demand** (`GG.NO_DEMAND`).
- **The Fickle Gods** (twist): upkeep x1.5, and a paid demand pays x1.5.
- **Recruiting by mark** (`_mkho`/`_mnur`/`_msla`/`_mtze` and the god-culture keys). Unmarked units
  pay the Undivided. A new `UnitUpgraded` listener pays the god of the unit an upgrade made
  (`GG.UPGRADE_PAYS`, this race only).
- **Three race services:**

  | Service | God, rank | Effect |
  |---|---|---|
  | Tithe of Souls | Dark Prince, 2 | +500 Souls |
  | The Eye Turns | Changer, 3 | +15 Eye of the Gods |
  | Skulls for the Skull Throne | Blood God, 4 | +6 melee and +25% battle experience, all armies, 10 turns |

- **Hire unit:** Chosen of Khorne.

**Halls:**
- Idol / Altar / Monolith of each god; the Undivided's are Shrine / Temple / Monolith.
- Built in Dark Fortresses and the Glottkin's two gardens, **not** in Chaos Altars: the altar's main
  building stops at level 2 and a hall's first level needs 3.
- No hall trains a unit, since no building of the race does.
- Rows are cloned from `wh3_dlc20_woc_dark_fortress_warriors`, named in `HALL_RACES`.
- AI value donors come from the Dark Fortress's own slot set (`_cai_donor` now accepts a named
  donor's set).

**Panel frame:**
- Card: Tamurkhan's chieftain text plate, rim and hanging spikes kept whole.
- Heat glow: the Path to Glory's orange. Rim and open tab: the Path to Glory's selection stroke.
- Icon holder: the Gifts of Chaos Undivided slot. Cost: Tamurkhan's number plate. Tabs: his
  subtitle bar.
- Rank strip and button bar: the race's own HUD bars. Reputation track: the Souls bar.

**Art:**
- Cards: the Four's tech-tree watermarks; the Undivided's star (`chaos_worship`); the Doubter's
  standing stones; the Undoer's cracked cog. Crest: the Dark Fortress.
- Hall icons: CA's `chaos_*` building icons.
- Grounds: window 7 of each god's loading screen, the Daemons' for the Undivided, and windows 5
  and 6 of `campaign_chaos1` for the renegades.

## Rulings made while building (the ledger's, in order)

The plan's 16 plan-time rulings stand as written. These were made on top of them:

1. No git here, so no commits; each task was diffed against a snapshot.
2. The hire unit stayed the Chosen of Khorne: the question went unanswered at handoff.
3. `LEDGER_SOURCES` gained `gifts` before `recruits`. The saved ledger is parsed by name.
4. The Skaven's "rows are last" service pin became absolute rows 93-95; the count went 95 to 98.
5. The rival tests set `GG.player_cultures`. Without it every faction reads the global table and
   the other-races loop proves nothing.
6. The marked-Sorcerer test runs with a Warriors of Chaos player, or `GG.covered` refuses it.
7. **No `zeal` override.** Zeal is a one-army service. The plan's override was all-armies text, and
   the same pair the race's holy war gives. The base zeal (+6 melee, +10% charge) fits.
8. **The word pass grew** after reading all 185 touched lines (see "The race").
   `check_chs_words` refuses "guild", "reputation", "foremost", "great gods", "god hall", "you lead",
   a bare "Leader", and a god's name with a plural verb.
9. The halls Help line reads "No hall trains a unit; 5 of the 7 carry a second bonus instead" for
   this race, counted off `HALL_EXTRA`.
10. "Chaos Undivided corruption" is CA's own name for it.
11. `check_flavours` wants a recruit line only for a god that recruiting pays. The Doubter and the
    Undoer have no warriors, and the panel prints nothing for a missing line.
12. **`POOL_RECRUITED` / `_pool_roster`.** The race's roster is its pools' units plus their upgrades:
    179 units. `check_recruit_routes` had nothing to read before.
13. Tasks 7-9 were verified together: the halls check needs the hall icons.
14. The hall donor is named explicitly, with Dark Fortress and garden settlement types (no altars).
15. The Four's watermarks fill 0.76 of their box, CA's own icons' margin, not edge to edge.
16. The renegades' grounds are windows 5 and 6 of `campaign_chaos1`. Windows 1 and 3 run into its
    painted frame.
17. **The card plate overhangs only its faint edge.** That is 2px a side and 4 below, measured by
    peak alpha. The rim lands at card rows 96-102, and the Buy button's foot sits 3px on it.
18. The rank strip uses the race's HUD bar squeezed to 46 rows, ends native, as Kislev's.
19. The Souls track is two fitted layers, the back under the frame, on the frame's measured
    opening.
20. `GGUI.HALLS_IN_HEADER` no longer exists: `GGUI.header_fits` replaced it on 2026-10-05.
21. The leader column's label reads "Champion" for this race (`CHS_EXACT`).
22. Mutation: one stale anchor re-aimed. Two survivors, the price and the Court's renounce line
    reading the global rival, now each have a harness case that catches them.

## Share of building Devotion

The method: each level of each chain in `wh_main_bas_chs` plus the Glottkin's set pays its tier
(DB level + 1) to `guild_of_chain(chain, "_chs")`, else to the Overseers' default, as
`GG.on_building` does. Halls are left out. The Skaven handoff measured differently, from the
generated junctions; this method gives the Skaven 47% Moulder and 16% default against its 49% and
29%.

| God | Share |
|---|---|
| The Doubter | 13% |
| The Blood God | 6% |
| The Changer of Ways | 2% |
| The Undoer | 5% |
| The Plague Lord | 70% |
| The Dark Prince | 2% |
| The Undivided | 2% |

7% falls to the default.

**The Plague Lord takes 70%.** The Overseers' role is the building trade, and the Glottkin's 14
garden chains all match `nurgle_garden`. That is a balance question for the author.

### Build jobs (`GG.BOUNTY_BUILDINGS._chs`)

| God | Build jobs |
|---|---|
| Doubter | `wh3_dlc20_woc_dark_fortress_income_3`, `_income_4` |
| Blood God | `_knights_3`, `_marauder_3`, `_warriors_3` (all `wh3_dlc20_woc_dark_fortress_`) |
| Changer | `wh3_dlc20_woc_dark_fortress_large_monsters_3` |
| Undoer | `wh3_dlc20_woc_dark_fortress_towers_3` |
| Plague Lord | `wh3_dlc20_woc_dark_fortress_growth_3`, `_growth_4` |
| Undivided | `wh3_dlc20_woc_dark_fortress_shrine_3` |
| **Dark Prince** | **none**: his chain stops below level 3 |

## Verified offline

- **Generator:** `--selftest` 7 guilds, 98 services, 90 bundles, 860 loc. `--check` exit 0.
- **The other nine races:** no non-`_chs` TSV row changed or removed. The only additions are two
  ledger loc keys under every flavour, the Skaven's under-city pattern.
- **UI:** `gen_guilds_ui.py` `--check` / `--selftest` green (70 files); `check_guilds_ui` 0.
- **Previews:** `preview_guilds_panel.py --flavour chs` exit 0 with no TOO WIDE and no LOW
  CONTRAST. The Gods (pages 1 and 7), Leaderboard, Bounties, Court and Help pages 2 and 7 were read.
- **Harnesses:** both green.
- **Mutation:** 281 of 281 caught, 14 new.
- **Lua:** luac on all five Lua files, `check_lua_api` 0, `check_lua_literal_left` 0,
  `check_lua_undeclared` 0 (baseline 0).
- **Pack:** duplicated combined keys 0 across 23 DB tables (schema `is_key`).
  `check_effect_bundle_loc` 0. `check_effect_signs`: the seven `_chs` penalty rows are the shared
  enemy-targeted services and the loan's downside.

## In game, open

1. The panel opens with its frame and reads "The Dark Gods".
2. Souls spent on a god's gifts pay that god.
3. Chaos Undivided corruption shows on the earnings sheet.
4. A hall builds, unitless, in a Dark Fortress and in a Glottkin garden.
5. Each rival pair takes from the right god.
6. The Doubter never issues a demand.
7. A save from before the update loads.
8. (Plan Ruling 5) The Glottkin's Souls spending reaches the `souls_spent` pools; their factor is
   limited to `wh3_dlc29_all_chs_except_glottkin`.
9. (Ruling 7) The Eye of the Gods accepts an addition through `gifts_of_chaos`.
10. (Ruling 9) `UnitTrained` fires for a pool recruit. `UnitUpgraded`'s `unit` is the unit
    after the upgrade by CA's own reading (`victory_objectives_config.lua:9621` tests it against
    the upgrade targets), so only the first half is open.
11. The card's spikes and the Buy button's 3px on the rim read right at the author's UI scale.
12. The header's name and figures fit in the game's font (`header_fits` decides).

## Adding an eleventh race: the new declaration points

The Skaven handoff's checklist (`HANDOFF_20261005_GUILDS_SKAVEN.md`) still holds. Its
`GGUI.HALLS_IN_HEADER` line is obsolete. This race added these:

- **Model:**
  - `GG.RIVALS_RACE[culture]` (`check_rival_mirror`);
  - `GG.POOL_GUILD` for a by-pool route;
  - `GG.NO_DEMAND[culture]` (`check_no_demand_mirror`);
  - `GG.UPGRADE_PAYS[culture]`;
  - `taint` per `GG.TEMPLE_ROUTES` entry.
- **`gen_great_guilds.py`:**
  - `RIVAL_PAIRS_RACE` and `NO_DEMAND`;
  - `CHS_WORDS` / `CHS_EXACT` (a race with its own vocabulary);
  - `POOL_RECRUITED` (a race that recruits from pools);
  - `HALL_RACES[tag]` `donor` and `settlement_types` for a race whose settlements are typed or
    whose buildings train nothing, and `where` when those types leave most of the map out (the
    Help says it on the size line; a line of its own overflows page 7);
  - `RECRUIT_SAYS` only for gods that recruiting pays.
- **`make_guild_icons.py`:** an explicit `HALL_ICONS.update` when the cards are not building icons.
- **`make_guild_backgrounds.py`:** the `LENT` rule, for a race whose grounds come from several CA
  paintings.
- **`gen_guilds_ui.py`:** the inset probe's anchor in the selftest moves when a race is appended
  after `_skv`.

## Final review (opus, read-only, 2026-10-12)

"With fixes": no Critical, five Important, nine Minor. Four Important were fixed, each with a
check watched failing first:

1. **A weapon swap paid as a mark.** CA's 25 `*_to_self` upgrade groups hand back the same unit
   for 150 gold; the `UnitUpgraded` listener now skips them off `upgrade_group():key()`, as CA's
   Glottkin script does. Harness case and mutant.
2. **47 ungrammatical titles** ("The Blood God Name You Marauder", "The Doubter Are Watching
   Closely", "raise a Idol") plus "whoever leads them" and "the lead of that god".
   `check_chs_words` now catches all of them; a/an is fixed where the hall line is built (`_a()`).
3. **No research bounty for the race.** Every Warriors of Chaos tree carries the culture's only
   subculture and `bounty_techs()` skipped any set with one. Such a set now counts as the race's;
   `check_bounty_data` fails a race with no list.
4. **The Help never said where halls stand.** It now says Dark Fortresses and the Glottkin's
   Gardens of Nurgle, never a Chaos Altar.

After the review, the MCT "tainted provinces" slider still said "Skaven corruption... Skaven
only" though it now pays the Warriors of Chaos too. It names both corruptions now, and
`check_mct_names` fails a taint race whose corruption that tooltip does not name.

Not fixed, a ruling: the Gifts route is uncapped for the Changer of Ways, because
`GG.CAP.daemonsmiths = 0` is every race's rule. A large Souls spend on Tzeentch can climb ranks
in one turn; a gifts-only limit is one number if it plays badly.

Deferred minors (the ledger has each):

- the UI frame comment still calls `_chs` a copy of `_skv`;
- `NO_DEMAND` ignores Race differences;
- five `rival_of` sites have no mutant;
- spec §10's `GG.POOL_GUILD` mirror check was never written;
- Help p2's example line and the Undivided's Sorcerers;
- the Doubter's "demands" bounty wording and his "Chaos corruption" service;
- "take the lead" survives the Champion pass.

## Open

- **GitHub:** synced 2026-10-12 as commit 8aa97a6 (build 1C79FD97), README, CHANGELOG and
  DEVELOPMENT updated. Re-sync after the upload if the build changes.
- **Norsca:** its own spec; §13 of this spec records the starting facts.
- **The Dark Prince's build job:** he has none.
- **The Plague Lord's 70% building share:** see above.
