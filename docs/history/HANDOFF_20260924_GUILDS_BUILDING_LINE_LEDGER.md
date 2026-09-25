# The Great Guilds - the building-card line, the "Reputation this turn" line, and plain words

2026-09-24. Built and packed (`Modding Files/Modpacks/derpy_great_guilds.pack`, MD5
`108e223bc4e178a65930a621de729df8`, 32,069,050 bytes, 140 files).
- The previous build (`efa60e77`, see `HANDOFF_20260924_GUILDS_DEF_HEF_GATE.md`) is backed
  up as `Modpacks/derpy_great_guilds.pack.bak_20260924_pre_ledger_efa60e77`.
- **Deployed to `data/` 2026-09-24**, once the game closed. MD5 matches.
- **Superseded 2026-09-25 by `edb15834`,** the patch 9.0 fix in section 6. `108e223b` would
  not load on 9.0.
- **The report:** "why cant i see an effect on the buildings that it actually adds something
  to the Guild".
- **The user's choices:**
  - options 1 and 3: a line on the building card, and a line on the panel;
  - the word "Reputation" (Influence belongs to the Hashut court mod);
  - "change the word standing for others, remove unnecessary jargon for the players".

## 1. Why nothing showed

A finished building pays its guild in script (`GG.on_building`), once, at 10 x its level.
The guild is picked by the words in the chain key (`GG.BUILDING_THEME`). A building card
lists only database effects, and the mod gave buildings none.

The panel didn't show it either. The payment shares the guild's per-turn limit with that
guild's other sources, so on a turn when income had already filled the Brass Tablets' 40, a
new market paid nothing and nothing said so.

## 2. The line on the building card

- **Text:** a yellow line, "Completing this earns reputation with the Daemonsmiths", in each
  race's own guild names. There's no number: the MCT rate, an undocumented level base and
  the per-turn limit all change the amount.
- **CA's own pattern:** `wh2_main_effect_building_major_settlement_only_dummy`, which has no
  bonus-value junction, value 1, and the scope `building_to_building_own`. That scope's
  suffix loc is empty.
- **Rows:** 48 `effects` rows (6 guilds x 8 races) and 1,714 `building_effects_junction`
  rows. Both tables are at version 0, which matches CA's. There are 48
  `effects_description_` loc lines.
  - Icon: the icon of the vanilla effect each guild's rank bundles use.
- **Scope:** every level of every chain in one covered race's availability sets. Left off:
  - `_ruin` levels;
  - levels hidden in the UI;
  - 48 chains more than one covered race can build (landmark `_other` variants). Those would
    print one line per race.

  All of these still pay, and so do a mod's chains.
- **Generator** (`gen_great_guilds.py`): `building_theme`, `guild_of_chain`,
  `covered_chains`, `built_tables`. The rows are added in `build()` after the per-flavour
  pass.
- **`check_built_effects`:**
  - Runs the shipped `GG.guild_of_chain` under `lua.exe` over every chain and refuses on any
    disagreement with the Python copy. A card that names one guild while the script pays
    another is worse than no line.
  - Also checks: every junction has an effect, every effect has loc, no duplicate pairs, and
    at least 100 rows per race.
  - Mutations: a tie-break change is caught (28 chains), and so is a broken culture key.
    Removing the lowercasing survived. That mutant is equivalent: 79 covered chains carry
    capitals ("HUMAN", "EMPIRE"), and none of those segments holds a matching word.

## 3. The "Reputation this turn" line

- **Model:**
  - `GG.grant(faction, guild, amount, source)` records every gain through
    `GG.ledger_add`.
  - `GG.capped_grant` records what the limit withheld.
  - Sources: income, battles, research, agents, buildings, settlements, missions, bounties,
    demands, other and withheld (`GG.LEDGER_SOURCES`).
- **The ledger:**
  - Humans only, and in the save only (`derpy_gg_earned_<faction>`), like the Log.
  - Two turns, keyed by turn number rather than cleared at `FactionTurnStart`. The order
    between that event and `BuildingCompleted` is undocumented.
  - `GG.earned(faction)` returns this turn and last turn.
- **Panel:** `gg_earned` at (20, 562, 750, 24), on the Guilds tab only, in the band between
  the third card and the pager.
  - `GGUI.earned_line` shows the total with at most three sources (biggest first), the
    withheld amount in red, and last turn's total.
  - `GGUI.earned_tip` shows both turns in full, plus this guild's limit.
- **Checks:**
  - `gen_guilds_ui.check()` refuses `gg_earned` outside the band.
  - `check_ledger_sources` requires a `src_` loc row for every source in every flavour. The
    Lua builds those keys at runtime, so `check_ui_loc_keys` can't see them.
- **Harness:** two blocks, watched failing first.
  - Ledger: all nine routes, withheld when partial and when full, save-only, rollover, and no
    AI ledger.
  - Line and tip text.
  - Seven model mutations, all caught.
- **The preview** draws only the Standings tab, where this line is hidden. The band check is
  what places it.

## 4. Plain words

- **"Standing" becomes "reputation" everywhere a player reads it:**
  - Help, tooltips and messages;
  - rank-up messages ("Your rank with ...");
  - the MCT menu, including the debug section.

  "Standing" survives only as ordinary English: "Stone Still Standing", "Leave the Walls
  Standing", "keep the Great Bastion standing". "Take it standing" is now "Take it intact",
  in all nine bounties.
- **Tab renamed:** Standings is now Leaderboard (loc `tab_stand`; the key is unchanged).
- **Jargon replaced:**

  | Was | Now |
  |---|---|
  | accrues | earned |
  | rep | reputation |
  | "not a ratchet" | "can fall" |
  | Ranks pay | Each rank gives |
  | Per-turn caps / max one passively | A limit each turn |
  | gated | opened by a rank |
  | grant / monopoly (the leader's) | bonus / sole right |
  | league table | leaderboard |
  | patrons afield | patrons appointed |
  | on the round just past | last turn |
  | HUD | top of your screen |
  | agent | hero |
  | you or an AI | you or a rival |
  | by default | dropped |
  | "<guild> cap" slider labels | "<guild> limit" |
- **Two statements that were false, fixed:**
  - The title tooltip said reputation "only rises".
  - The Overseers' description said all buildings paid them. Since 2026-09-23 each building
    pays its own guild. Every guild's description now says "and from their own buildings".
- **The MCT Builders' rate tooltip** now says it pays whichever guild the building belongs
  to.
- **Help page 2** still fits its 21 lines for every race, after two bullets were shortened.

## 5. Deploy and in-game checks owed

1. **Deployed.** `data/` now holds `108e223b`, the same MD5 as `Modpacks/`.
2. **Building cards:** hover a Chaos Dwarf forge or port and an Empire barracks. Each should
   show one yellow line naming that race's guild. Check the effect icon draws.
3. **The Guilds tab line:**
   - At the start of a turn in which a building finished, it should read
     "Reputation this turn: +N (buildings N ...)".
   - On a rich turn, a new market should show the red "over this turn's limit" figure.
   - Check the line sits clear of the third card and the pager, at 1080p and at 4K.
4. **The Leaderboard tab label** fits its 125px plate.

## 6. Patch 9.0: a removed building (2026-09-25)

- **The fault.** 9.0 deleted `wh_main_special_great_temple_of_ulric`. The `108e223b` build
  shipped a building-card junction row for it, read out of `.skilltree_cache`, which is 8.x.
  A reference to a missing row is a load-time reject that drops the whole pack.
- **Why nothing caught it.** Every table version was still current. A version says nothing
  about whether the keys inside a row still exist.
- **The fix.** The building-line tables are read from the installed `db.pack` through
  `read_vanilla_db` (`live_rows()` in `gen_great_guilds.py`), never from the cache. 9.0 also
  added 419 building levels, so the card line now covers 1,726 levels, up from 1,714.
- **The new check.** `check_live_references()` runs in `--check`. It reads each column's
  reference out of RPFM's `schema_wh3.ron` and resolves every value this pack ships against
  the installed `db.pack` plus the pack's own rows. That is RPFM's InvalidReference, offline.
  - Tables with no file in `db.pack` are Assembly Kit only and are skipped:
    `effect_bundle_targets`, `mission_types`, `message_event_layout_types`.
  - Proven: injecting the removed temple key fails it by name.
- **Deployed.** `edb15834c791b393be645a2e837a8e18` is in `data/`, MD5 matched. The backup is
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_90keys_108e223b`.
- **Not pushed to GitHub yet.** Pushing needs the user's approval.

## 7. Leaderboard icons, the leader's flag, a larger title (2026-09-25)

- **The request:** a guild icon at the start of each Leaderboard row; instead of
  `Leader: You`, `Leader:` and the leading faction's flag; the title larger and centred.
- **Row icon.** A new `row_icon` child, 36x36 at (6,2) in the 40-tall row, repainted per
  guild with `GGUI.icon`. `row_guild` moved to x=46 and narrowed to 160px.
- **Leader flag.** `GGUI.leader_text` draws the flag as inline `[[img:]]` markup, as the
  faction list below it already does (`GGUI.flag_img`, shared by both).
  - You lead: `Leader:` and your flag, with no word after it.
  - A rival leads: the flag, then its name and rank.
  - Nobody leads: `Leader: Nobody`, with no flag.
  - The yellow changed-hands mark wraps the text only, never the flag.
- **The line now shortens itself.** Rival lines could already overflow the 324px column:
  about 416px for `The Huntsmarshal's Expedition (Grand Master) +120`, estimated from
  the loc names of all eight races. The flag adds about 45px. `GGUI.leader_fit` measures
  with `TextDimensionsForText`, as `GGUI.wrap` does, and drops the rank, then the name.
  The markup is stripped before measuring and the flag is charged as `GGUI.FLAG_W` = 30,
  because whether the measure reads `[[img:]]` as a picture is not in CA's reference.
- **Title.** `gg_title` is (60,8) 670x34, which centres it on the panel, in
  `header_24_bold` (CA's largest bold header), aligned Center. It was `header_18_bold`,
  left-aligned, at (54,14).
- **Tests.** The harness covers `leader_text`, `leader_fit`, and a fake-panel
  `draw_standings` that must paint every row's icon and fit the leader cell. Seven
  mutations were run and all were caught. `preview_guilds_panel.py` now reads the title
  and row positions from the generator instead of hard-coding them.
- **Built and deployed:** `7dbe88c685d5a21089ba70d19a9153cf`, 32,073,727 bytes, MD5
  matched in `data/`. The backup is
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_leaderboard_edb15834`.
- **Owed in game:**
  - Does the flag draw after `Leader:`?
  - Is the icon crisp at 36px?
  - Does a long rival line shorten and not overflow?
  - Does the title sit centred between the crest and the close cross?
  - Does the log line `text measures x...` still read correctly at UI Scale 50%?
- **Not pushed to GitHub.**
