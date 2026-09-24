# The Great Guilds - every race, the whole AI, multiplayer

2026-09-24. Built and packed (`Modding Files/Modpacks/derpy_great_guilds.pack`, MD5
`fc95d1d1788358ca964852d26ea52b89`, 13,283,594 bytes, 73 files). **Deployed to `data/`
2026-09-24 09:36** (MD5 match; no Workshop copy of this mod exists). The previous build
(`0c3860ab`, the UI-scale one) is backed up as
`Modpacks/derpy_great_guilds.pack.bak_20260924_pre_gen_mp_0c3860ab`. Guild mod only.

The request was "build first the designed but never built, then fix the known issues".
Five items were built (1-3 below) and five issues fixed (4-8). The user made four of the
choices: role names for the fallback, the AI may buy Hobgoblin Eyes, Bound Blueprint plus
a no-repeats rule for AI balance, and 250 Oathgold.

## 1. A generic flavour for every other race (`_gen`)

Until now a Lizardmen, Greenskin or modded-culture player read the Chaos Dwarf names under
Hashut's crest. There is now a fourth flavour, `_gen`, with feed offset 30. The Lua side is
`GG.GENERIC` and `GG.flavour_of_culture`: a readable culture with no flavour of its own
gets `_gen`, and an unreadable one gets `""` as before.

- **Guild names:** the Merchant Houses, the Veterans' Company, the Artisans' Guild, the
  Shadow Guild, the Builders' Guild, the Raiders' Guild.
- **Ranks:** Stranger, Known, Trusted, Honoured, Exalted.
- **Other text:** services, blurbs, descriptions and bounties are written race-neutral.
  `check_flavours` refuses the Chaos Dwarf words in them.
- **Event pictures:** a folder swap does not work, because `all/` lacks
  `civilisation_up` and three of the other four names. `FLAVOURS["_gen"]["pictures"]`
  names each one outright, and `retag` goes through `picture()`. Every picture is one
  that vanilla's own rows use (`check_feed_images`):

  | Chaos Dwarf picture | Generic picture |
  |---|---|
  | civilisation_down | `all/wh2_rogue_army_encountered` |
  | messenger | `all/wh2_treasure_hunt_3` |
  | diplomacy | `all/nemesis_crown` |
  | civilisation_up | `all/wh2_sea_encounters_1` |

  Bounties use `all/queen_and_crone`.
- **Icons** (`make_guild_icons.py`): all seven are CA silhouettes that belong to no race's
  line.

  | Guild | CA icon |
  |---|---|
  | Brass | `war_coordination_outpost` (a handshake shield) |
  | Immortals | `wh_main_emp_academy` |
  | Daemonsmiths | `special_vauls_anvil` |
  | Khanate | `minor_cult_assassins_hideout` |
  | Overseers | `wh2_dlc15_special_massif_orcal_quarry` |
  | Slavers | `ogre_camp_loot_pile` |
  | Crest | `minor_cult_tilean_traders` |

- **Grounds** (`make_guild_backgrounds.py`): six windows of
  `prologue/battle_scene_b1.png`, with darkening factors of 0.31 to 0.39.
- **Hire unit:** a generic culture has none, so Hire the Veterans is refused with the
  existing `no_unit` line. Its blurb promises no unit by name.
- **Checks:** `check_flavour_mirror` reads `GG.GENERIC` as the `None`-culture entry.
  The preview reads each flavour's own lowest rank (`--flavour gen`).

## 2. The AI buys all eighteen services

`GGAI.EXCLUDED` and `GGAI.allowed` are deleted.
- **Hobgoblin Eyes:** `GGAI.pick_enemy_region` picks a region of a faction at war with
  the buyer.
- **Bound Blueprint:** `GGAI.pick_research` loads the saved ResearchStarted record. The
  ResearchStarted gate is widened from `GG.is_human` to `GG.covered`, which adds the AI of
  the player's culture (about 15 factions in Immortal Empires) and nobody else.
  `GG.research_target` now returns nil when `faction:has_technology(k)`, because
  ResearchCompleted never reaches the AI and so an AI's record outlives the research it
  names. The first time ResearchStarted reaches an AI faction in a session, it logs:
  `derpy_gg: ResearchStarted reached AI faction X - the AI can buy Bound Blueprint`.
  **No such line in a log with AI turns in it means the event does not reach the AI**,
  and the AI never buys this service.
- **Raise the Ziggurat:** the panel's slot walk moved into the model as
  `GG.upgrade_target(faction, region_key)`. The panel, `GGAI.pick_building` (which walks
  its own `region_list`) and the MP handler all build the target through it.
- **`GGAI.choose` returns the key and the target.** A service that needs a target is a
  candidate only once it has one. Choosing it blind spent the turn's one purchase on a
  sale that `GG.buy` then refused.

## 3. The Slave Tithe pays Dwarfs in Oathgold

`dwf_oathgold` +250 with factor `missions`. `dwf_oathgold_quest_rewards` binds that factor,
and it is the only one of the pool's nine factors that takes either sign. The pool's scope
is FACTION. The Empire and the generic races keep 3,000 gold. The Dwarf blurb now reads
"Adds 250 Oathgold."

## 4. No repeats

The AI never buys the same service twice in a row while anything else is affordable. The
last purchase is saved as `derpy_gg_ai_last_<faction>`: every machine runs the AI sweep,
and a value held only in session memory would be lost on a reload. The only affordable
service may still repeat.

## 5. Multiplayer

All five panel mutations now go through `GG.mp_send(faction, op, arg)`. This is the Zharr
Exchange's transport: single-player applies directly, and multiplayer broadcasts
`gg1|op|arg` on the buyer's CQI. The `gg_mp` UITrigger listener then applies it on every
machine.

- **Ops:** `buy`, `bounty`, `demand`, `patron`. The patron op toggles: the sitting guild's
  button dismisses and any other appoints. It decides from the saved post on every machine.
- **State:** each op loads its state from the save first. After a reload mid-turn, only
  the machine that drew the panel has it in memory.
- **Targets on the wire:** a target travels as a string and `GG.target_from_wire`
  rebuilds it.
  - A building goes as its region key and is rebuilt through `GG.upgrade_target`.
  - Research goes as nothing; each machine reads its own record.
  - An army goes as a character CQI.
  - A hostile target goes as a faction key.
- **The board draw writes nothing any more.** It used to post and purge, on one machine
  only.
  - `GG.bounty_view` hides an offer that stopped being true mid-turn without removing it.
    Its indices are what a click sends (`GGUI.BOUNTY_AT`).
  - `GG.first_boards` posts an empty human board at the first tick.
  - Withdrawal and re-pricing now happen only at turn start.
- `GG.after_mp` redraws the panel when a change for the local player lands.
- **NOT VERIFIED IN A MULTIPLAYER CAMPAIGN.** No two-machine run has happened. If
  multiplayer misbehaves, suspect the round trip first.

## 6. The HUD opener's tooltip is written on hover

The tooltip moved out of `place_opener`, which runs from FactionTurnStart (the
no-loc-in-turn-handlers rule). It is now written by `gg_opener_tip`, a `ComponentMouseOn`
listener on `gg_opener`. The harness asserts that `place_opener`'s body contains no
`GGUI.loc`.

## 7. The MCT page names the guilds for the player

- **Frontend:** the settings file labels the twelve guild sliders with the generic role
  names, because the frontend has no race to name them for.
- **Campaign:** `GGUI.name_mct()` renames them at the first tick to the local player's
  flavour, from `GGUI.MCT_NAMES`. That is a literal table:
  `gen_great_guilds.py --write` rewrites it between the
  `-- BEGIN/END GENERATED: GGUI.MCT_NAMES` markers.
- **Check:** `check_mct_names` refuses a stale table and settings labels that drift from
  the generic names. It was watched refusing the empty block before the first `--write`.

## 8. Debug lines behind the MCT switch

`GGUI.info` prints only with "Log every accrual" on. Three lines moved to it:
- `panel scale S on a WxH screen`
- `text measures xR`
- `opener button at`

GAVE UP and MoveTo OVERRIDDEN stay on `GGUI.say` and always print. The harness asserts
that every remaining `GGUI.say` call is one of those two.

**This changes the UI-scale handoff's in-game checks:** its checks 1, 2 and 5 read the
scale lines, so turn "Log every accrual" on first.

## 9. Verification

Every item's test was written first and watched fail, then pass. The no-repeat rule and
the `has_technology` guard were also checked by mutating the shipped Lua; each mutant
failed its test.

Green:
- the harness
- `gen_great_guilds --check/--selftest`
- `gen_guilds_ui --check/--selftest`
- `check_guilds_ui` and its selftest
- `check_guilds_anchor`
- `preview_guilds_panel --check/--selftest`
- `import_great_guilds --check`, and its post-save `verify_saved`
- `make_guild_icons --check/--selftest`
- `make_guild_backgrounds --check/--selftest`
- `luac` on all four scripts
- `check_lua_api`

`check_lua_undeclared` reports only `EX.BUTTON*`, which is the Exchange's and is read
defensively. The four packed scripts are byte-identical to staging.

## 10. In-game checks owed

1. **A Lizardmen (or any non-Chaos Dwarf, non-Empire, non-Dwarf) campaign:**
   - the panel reads the Merchant Houses and the rest, with the handshake crest and the
     battle-sketch grounds;
   - a feed message shows its `all/` picture;
   - the MCT page (opened in campaign) names the same guilds.
2. **An Empire campaign:** the MCT page says the Merchant Guilds, and the frontend says
   the Merchant Houses.
3. **A Dwarf campaign:** the Slave Tithe (Weregild) adds 250 to Oathgold, not gold.
4. **Any campaign with a few AI turns:** the log has the `ResearchStarted reached AI
   faction` line. With "Log every accrual" on, AI purchases of Spies' Report, Bound
   Blueprint and Raise the Ziggurat appear in the Log tab over time.
5. **The opener's tooltip** appears on hover, and turn 1 does not crash.
6. **The bounty board is posted on the first load** of a campaign that adds the mod
   mid-turn. A target taken mid-turn disappears from the board without the board losing
   its other offers.
7. **Multiplayer**, when anyone can: a purchase, a bounty take, a demand payment and a
   patron change each land on both machines with no desync.

## 11. Gaps, stated

- **No construction-in-progress test** for Raise the Ziggurat, on the player's side or the
  AI's. No slot or region member in CA's docs reports it.
- **A war declared mid-turn** gives an empty board no offers until the next turn start.
  The draw used to post on demand, but that ran on one machine.
- **An offer's price** is re-read at turn start only, no longer on every draw.
