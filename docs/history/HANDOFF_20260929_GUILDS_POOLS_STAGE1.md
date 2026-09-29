# Handoff 2026-09-29 - Great Guilds: service pools, stage 1

Spec: `docs/superpowers/specs/2026-09-29-great-guilds-service-pools-and-races-design.md`. Plan:
`docs/superpowers/plans/2026-09-29-great-guilds-service-pools-stage1.md`. Stage 1 is the
spec's pool half (sub-project 2 of the three asked for on 2026-09-29). Stage 2 - the race-only
services, earn routes, twists, `race_differences`, the Help page and draw rule 2 - gets its own
plan.

| Build (MD5) | What |
|---|---|
| `A437C99B` | stage 1 as planned (never deployed) |
| `F6F81565` | final-review fixes: a rival's strike on a human's settlement is announced; six persistence, preset and routing paths now tested |
| `8CD80357` | Temple Bribes for the Chaos Dwarfs (§3b; never deployed) |
| `E3C2984B` | the offerings audit (§3c); backup `data/derpy_great_guilds.pack.bak_offerings_audit_20260929` = `F6F81565` |
| `3CA24F72` | Kislev's Master Gunners on its real artillery (§3d); backup `data/derpy_great_guilds.pack.bak_ksl_artillery_20260929` = `E3C2984B` |
| `2B9176F5` | every race in its own frame (§3e); backup `data/derpy_great_guilds.pack.bak_race_frames_20260929` = `3CA24F72` |
| `25DD78AF` | Warlord's Honour raised to 5 ranks (§3f); backup `data/derpy_great_guilds.pack.bak_warlords_honour_20260929` = `2B9176F5` |
| `DF0221CE` | nothing paid for that is not delivered (§3g); backup `data/derpy_great_guilds.pack.bak_safety_20260929` = `25DD78AF` |
| `F3F6FE85` | the two remaining gaps and the six deferred minors (§3h); **live**, backup `data/derpy_great_guilds.pack.bak_stage1_gaps_20260929` = `DF0221CE` |

`F6F81565` is `Modding Files/Modpacks/derpy_great_guilds.pack`, 32,941,490 bytes.
Deployed to the game's `data/` later on 2026-09-29, once the game was shut, with the built
and live MD5s matched. The previous live pack (`BB0FB116`) is backed up as
`data/derpy_great_guilds.pack.bak_pools_stage1_20260929`. Not pushed to GitHub.

## 1. What shipped

- **54 services, one card per rank.** Each guild's rank 2, 3 and 4 each hold a pool of three
  (the old 18 plus 36 new rows appended to `GG.SERVICES`, which stays append-only because
  cooldowns are saved by position). The panel shows one card per rank.
- **The cards** (`GG.cards[faction] = {turn, keys}`, saved as `derpy_gg_cards_<faction>`,
  keys not indices). No cards reads as each slot's first row - exactly the old 18 - so an
  existing save shows and sells what it did until its next turn start draws.
  `GG.load_cards` maps a key this build no longer sells, or one in the wrong slot, back to
  the slot's default.
- **The draw** (`GG.draw_cards`): every card in a fixed order, one `GG.roll` each, never the
  card's last service when the pool has another. `GG.pool_ok` refuses stage-2 `race` rows, the
  hostile ones while `hostile_services` is off, and a row whose `needs` check says no or
  throws. An empty pool keeps the card.
- **The clock** (`GG.rotate_cards`): once per `rotate_turns`-turn period (MCT slider 5-30,
  default 10, read on every preset, locked in campaign), called from `gg_turn` and from the
  rivals' round - the second call in a period does nothing. Covered factions only. A missed
  period catches up once. No notice on the first draw.
- **The notice**: feed record 5006 (+ the race offset), a `scripted_persistent_event` that
  waits in the feed, human only, behind `guild_notices`; a `rotation` Log line under the Mine
  filter; the panel footer counts down to the next change.
- **The till checks the card.** `GG.can_buy` refuses a service not on today's card
  (`"card"`), so a card that rotated while the player was picking a target cannot be bought.
- **New kinds**: `army` (bundle on the general's force), `settlement` / `enemy_settlement`
  (bundle on a region, the buyer's race tag), `ranks` (`cm:add_agent_experience`, Warlord's
  Honour and Hired Blade). `GG.target_ok` checks every targeted buy: an army or lord must be
  the buyer's own, a settlement the buyer's, an enemy settlement a faction the buyer is at war
  with. Hire is checked the same way.
- **Hire fixed**: `cm:grant_unit_to_character` takes a lookup string; it was given a bare cqi
  and granted nothing.
- **Three hidden lines**: Sow Discord, Enforcers and Web of Whispers use `_unseen` scopes
  (vanilla has no visible pair), so their numbers are written into the card and bundle text.
  The selftest allows exactly these three and asserts each description states its number.
- **Generator**: per-service effects with their own sign rules (`inverted()` for enemy
  settlements, hostile and drawback rows), `bundle_target` by kind, the 36 names in all nine
  flavours, a duplicate-name check in `check_flavours`, `check_presets` exempts every-preset
  keys.

## 2. Found while building

- The plan's Dark Elf names "Slave Raids" / "Slave Markets" fail the flavour word check
  (`slave` is Chaos Dwarf only); and three Dark Elf pool names repeated an older service's name
  in the same flavour ("The Witch King's Seal", "Secrets of Ghrond", "Corsair Raids"). Nothing
  checked for that; `check_flavours` does now. Renamed: "The Drachau's Seal", "Hag Graef's
  Masterwork", "Dark Rider Raids", "Thrall Markets".
- The main harness had no stubs for three of the new engine calls, so the first mutation run
  crashed it instead of failing an assertion. 51 of 51 mutants are caught.

## 3. The final review

A fresh reviewer (opus) found no Critical and two Important issues:

- **A rival's enemy-settlement service hit the player silently.** `GGAI.report` and
  `GGAI.log_purchase` only knew a hostile service's target as a faction key, and Sow
  Discord's line is `_unseen`, so the player lost public order with no message. This broke
  the `guild_notices` tooltip's promise. Fixed: `GGAI.victim` resolves the region's owner at
  purchase, and the existing hit message and Log line follow.
- **The card persistence path could break with no test failing.** Five mutants survived:
  load answering the defaults, `GG.load` skipping the cards, `rotate_turns` read under Custom
  only, rivals aiming a settlement service at an enemy, and uncovered factions drawing. The
  round-trip test also saved a default key, so it could not tell. All are tested now, and
  `mutate_guilds.py` holds 57 mutants, all caught.

Eight Minor issues were deferred, listed in the ledger's `Final:` lines. **All eight are
closed as of `F3F6FE85`** (§3g, §3h). Two would have been seen in game:

- **The first draw moves every card off its default.** A new campaign never shows the
  original 18 in its first period. An existing save's cards all change at the next turn
  start, with no notice, while the footer was counting down. The plan pinned this.
- **"New services in 1 turns"** on a period's last turn.

## 3b. Found in game: Temple Bribes cut the Chaos Dwarfs' corruption

Temple Bribes (`alms_and_bribes`) gave every race -5 corruption
(`wh3_main_effect_corruption_reduction_events`), because a service's effects are copied
unchanged to all nine flavours. The Chaos Dwarfs' public order RISES with Chaos corruption
(vanilla's `wh3_main_corruption_chaos_chd_*` ladder, +1 to +5), so for them it was a
penalty drawn in green. No check could see it: the sign rule reads the effect's own flag,
which calls a corruption cut good for everyone.

Build `8CD80357`: a service row may carry `for_tag` - per-flavour effects and text, read
through `service_effects(s, tag)` / `service_text(s, tag)`. Temple Bribes is now +5 Chaos
corruption (`wh3_main_effect_corruption_chaos_events`, faction_to_province_own, a vanilla
pair with a max of 20) for the Chaos Dwarfs and -5 corruption for the other eight.
`check_flavours` now refuses any Chaos Dwarf bundle carrying an effect in
`CHD_UNWANTED_EFFECTS`; it failed on exactly this bundle before the fix. No other service
touches corruption.

## 3c. Every offering audited against every race (build `E3C2984B`, deployed)

All 54 services dumped with each effect's vanilla description, `is_positive_value_good`
and direction, then each race's reach measured from vanilla data. Found and fixed:

- **Gunnery Masters** used `missile_damage_artillery`, whose unit set `all_land_artillery`
  is classes `art_fix`/`art_fld`/`art_siege`. Kislev fields none of those, so it did
  nothing. The Chaos Dwarfs field one, the Hobgoblin Bolt Thrower: their Magma Cannon,
  Dreadquake, Deathshrieker and Iron Daemon are class `chariot`. The Chaos Dwarfs now use
  CA's own `wh3_dlc23_effect_force_stat_missile_strength_chd_artillery`
  (set `wh3_dlc23_chd_all_artillery`) at +20. Kislev now uses
  `wh_main_effect_force_stat_missile_damage_infantry` at +15, vanilla's own value, renamed
  "Streltsi Marksmen".
- **Spirit Siphon** (Dwarfs: Runelord's Anvil) fed the Winds of Magic, and the Dwarfs have
  no spellcasters. It is now `wh_main_effect_force_stat_magic_resistance` +10, faction_to_force_own
  (23 vanilla rows, max 25).
- **The Slavers' effect text** said "sacking and razing". Vanilla's
  `force_all_campaign_sacking_income` is "Income from sacking settlements", so the text
  now says that.
- `CHD_UNWANTED_EFFECTS` became `RACE_UNWANTED_EFFECTS` ({tag: {effect: measured reason}}),
  checked over every flavour's rows. It failed on exactly these three before the fixes.

Checked and sound: the other effects' sign and direction, bundle scopes against bundle
targets, every race's card text for the original 18 against its payload, raiding (no race
is barred), and Furnace Charter (every race has manufacture-income buildings).

**A balance question for the user, since settled (§3f):** Warlord's Honour (Immortals,
rank 4, leader only, 400 favour) and Hired Blade (Khanate, rank 3, 150) both added 3
ranks, so the monopoly service was the worse buy.

## 3d. Kislev has artillery (build `3CA24F72`, deployed)

§3c's "Kislev fields no artillery" was the unit CLASS talking. The user pointed out that
Kislev's artillery is Little Grom (a cannon) and the Light and Heavy War Sleds, all
class `chariot`, which is exactly the Chaos Dwarf case. CA names them "artillery" in its own
`..._ksl_artillery_sleds_rank7` effects. Vanilla gives them ammunition, armour, upkeep and
reload effects, but no missile-damage effect on any scope, so there was nothing to reuse.

Minted `derpy_gg_effect_missile_strength_ksl_war_machines` (`MINTED_EFFECTS`): a clone of
`wh3_dlc23_effect_force_stat_missile_strength_chd_artillery`. It copies that effect's row
and its two bonus ids (`missile_damage_mod_mult`, `missile_damage_ap_mod_mult`), and points
them at CA's own `ksl_war_sleds_little_grom` set, which has no rank range. That set is not
`ksl_war_sleds_little_grom_rank_7`, which applies only at unit rank 7 to 9. It needed one
new table in the pack, `effect_bonus_value_ids_unit_sets` (version 0, pinned by
`check_table_versions`). `check()` judges a minted effect by its DONOR's vanilla pairs,
range and sign; both a wrong scope and a flipped sign are proven to fail. The selftest
asserts Kislev's Master Gunners reaches exactly that set, and it failed before the mint.
+20% for 10 turns, the same as every other race; the donor's vanilla maximum is 25.

## 3e. Every race in its own frame (build `2B9176F5`, deployed)

Asked for 2026-09-29: "switch the frames to be on their faction flavour, check first using the
preview tools before deploying". Before this, all eight races drew the Chaos Dwarf chrome
(Hell-Forge card, Tower of Zharr tabs and bars); only the grounds and icons were flavoured.

**How.** Each of the seven other races ships its own `derpy_gg_panel_<tag>.twui.xml` and
`derpy_gg_card_<tag>.twui.xml`, so there are 14 new files. Each is the base file's tree with
the same components and the same GUIDs; only the art, margins and colours differ.
`GGUI.frame_path(base)` creates the reader's copy. The Chaos Dwarf files are byte-identical
to before. The Lua still repaints two things at runtime, the lit card's two glows and the
open tab's plates, so `GGUI.FRAME` mirrors `gen_guilds_ui.FRAMES` for those.
`GGUI.paint_tab` handles tabs of any depth: Kislev and Bretonnia have two layers, so with n
layers per state the hover images sit at n..2n-1. Every pick is CA art from the race's own
DLC panels or its culture skin (the table is in `FRAMES`). No race outside the Chaos Dwarfs
draws anything under `dlc23_chd_`, `dlc23_tower_of_zharr` or the CHD skin, and
`check_frame_files` enforces that.

**New checks.**
- `check_frame_mirror` compares the Lua's copy with `FRAMES` race by race and layer by layer,
  and checks that every path is in a ui pack.
- `check_frame_files` checks that each copy has the base file's hierarchy and component
  names, and no Chaos Dwarf art.
- The overhang and margin checks now run over every race's layers, including the paths the
  Lua swaps in through another layer's slot.
- The selftest breaks seven of these and sees each one fail.
- The harness's "every race in its own frame" block failed before the Lua change.

**`preview_guilds_panel.py` now:**
- draws each race from its own files;
- substitutes a culture skin's copy for a generic `ui/skins/default/X.png`, as the game does
  (the title plate is the reader's culture's);
- measures every line of text against what it is drawn on, taking the brightest tenth of the
  pixels under it, and reports `LOW CONTRAST` under 4.5:1.

**What the preview caught.** Each of these looked plausible by filename:
- **`tab_shadow` as the tinted glow.** It is a flat plateau with 20px soft edges, and
  stretched to 300px it drew a lit block that stopped a third of the way across the card.
  It was replaced by Ulric's `fx_radial_blur`, which is neutral grey and falls off radially
  the way `heat_glow` does.
- **`tile` tiles the middle in both axes.** Tiled, Cathay's bronze frame repeated its rails
  down the card and through the text; it is now stretched.
- **Bretonnia's `legacy/` pair is not the generic pair.**
  - `panel_back_tile` has a 4px black edge, which drew a seam every 256px until the margin
    was set to 5.
  - `panel_back_border` has a 33px band and 40px corners. CA's 30px slices are for the
    thinner generic file; on this one the band's edge fell in the tiled middle and drew a
    rail every 196px. The margin is now 42, measured as the smallest value with an empty
    middle and no corner pieces in the edge slices.
- **Transparent or empty-looking art.**
  - The Dwarfs' Mortuary Cult title plate is a pointed outline at card size.
  - The High Elves' `progress_bg` is a thin bar in a 678x191 canvas.
  - Hag Graef's `bar_top_center` is a 200px plate in a 399px texture.
  - The Forge of Daith's tabs are Wood Elf art.
- **Cathay's glowing selected octagon** put the open tab's yellow caption at 3.5:1. The open
  tab now uses the Tiger Court's jade banner.

**The importer would have shipped none of it.** `UI_FILES` is a hand-written list, and its
guard compared it against `gen_guilds_ui.FILES`, the six Chaos Dwarf files. It passed, and
every other race's panel would have been created from a file that was not in the pack, which
draws nothing and reports nothing. The guard now compares against `frame_files()`; it
refused, naming all 14 files, until they were listed. The saved pack's 20 twui and 2 Lua
files were byte-compared with the staged copies.

**The asset cache was stale.** `.skilltree_cache/ui_asset_paths.json` lacked 3,281 files,
all of dlc29 among them, so `_assets()` reported Ulric's art as missing. It was renamed
`.stale_20260929` and rebuilt by `gen_guilds_ui._game_assets()`. **Delete it after any game
patch**, along with the rest of `.skilltree_cache/`.

**Checks run.** All of these passed:
- `gen_guilds_ui.py --check` and `--selftest` (20 files, 2239 GUIDs)
- `preview_guilds_panel.py --check` and `--selftest`
- both harnesses
- `gen_great_guilds.py --check` and `--selftest`
- `check_guilds_ui.py`, `check_guilds_anchor.py`
- `check_lua_api.py`, `check_lua_literal_left.py`, and `check_lua_undeclared.py` over all
  five guild files
- `mutate_guilds.py`: every mutant caught

## 3f. Warlord's Honour gives 5 ranks (build `25DD78AF`, deployed)

The user chose 5, which was the recommendation. Hired Blade stays at 3, so the rank-4 service
for the guild's leader now gives more than the rank-3 one. Nine card texts changed, one per
race, and nothing else.

**Nothing tied the card to the grant.** The card text comes from `SERVICES` in
`gen_great_guilds.py`, but the game pays, times and grants from the Lua's own
`GG.SERVICES`. Nothing compared their numbers, so raising one side alone would have given
a card promising 5 and a grant of 3, and every check would have passed. Three changes fix
that:

- **`check_service_mirror()`.** It compares guild, rank, cost, cooldown, kind, turns and
  value for all 54 services, and it flags a service present on one side only.
- **It measures.** It failed on the real drift (card 5, Lua 3) before the Lua was raised.
- **The selftest breaks the shipped Lua in memory three ways.** A drifted value, a dropped
  value and a missing row must each fail it. The dropped-value case was a no-op on its
  first run, because the Lua pads `value=` with spaces, so it now matches any spacing.

## 3g. Nothing paid for that is not delivered (build `DF0221CE`, deployed)

The user asked how Hire works, then asked for "safety features and error protection". Four
paths took the favour, started the cooldown and delivered nothing:

- **A regiment for a full army.** CA documents that `grant_unit_to_character`'s unit "will
  only be created if there is room for it in the force". `GG.target_ok` now refuses a full
  army for the `unit` kind. It measures room the way CA's caravans do
  (`wh3_campaign_caravans_core.lua:1618`), from the force's own `unit_count_limit()`, so a
  mod that raises the limit is honoured. Army buffs still take a full army.
- **Ranks for a character at the top rank.** No interface reports the top rank. CA's
  wrapper clamps level-ups to `#cm.character_xp_per_level`, which is 50 in 9.0, and five CA
  scripts read that table directly (the Slaanesh realm clamps to `math.min(..., 50)`).
  `GG.max_rank()` reads it at runtime. If the table is unknown, no one is refused.
  Lords in campaigns other than Immortal Empires and Realm of Chaos top out lower (41 per
  `character_experience_skill_tiers`), so there this check can still pass a lord who cannot
  rank up. That is the one known gap.
- **A payload that throws.** `GG.payload` ran bare, after the spend and the save. An engine
  call that raised kept the payment, and the error escaped into the caller: the click
  handler, the multiplayer handler, or the rivals' turn loop, which then skipped every
  faction after the one that failed. It now runs under `pcall`. On failure,
  `GG.refund_purchase` returns the favour, clears the cooldown, saves both, writes a Log
  line ("could not be delivered and your favour was returned", bad news, under Yours) and
  prints to the script log.
- **The rivals' Hire.** `GGAI.pick_army` returned the first field army whatever it held,
  so once the till refused full armies, a rival whose first army was full would never hire
  again. It now returns the first army the till accepts for that service.

The hints changed too:
- **Hire** says "with room for another regiment".
- **The two rank services** say "below the highest rank".
- **`needs_army` drops "the regiment joins whoever is selected".** It was also shown for
  Forced March and Field Surgeons, which add no regiment.

**Found on the way: `GG.refund` already existed.** The first draft named the new function
`GG.refund`. That silently replaced the bounty stake refund, which takes different
arguments, and only a bounty test that used the old one noticed. It is now
`GG.refund_purchase`. A new build check, `check_no_redefinition()`, fails on any `GG`, `GGUI`
or `GGAI` function defined twice across the guild Lua. It found no duplicates among 333
definitions, and its selftest catches one in either spelling, across files.

**Tests.**
- A new harness block failed on its first assertion before any code changed.
- The force stub gained `unit_count_limit` and `unit_list`, with defaults of 1 unit of 20,
  and characters gained `rank`, default 1. Existing fixtures keep their meaning.
- One existing test was changed on purpose: the rivals' Hire pick at line 655 now needs its
  army to belong to the buyer, because the pick has to pass the till.
- There are 12 new mutants, 69 in all, and every one is caught. The first run reported one
  stale anchor, a UI comment still naming `GG.refund`; the comment was corrected.

## 3h. The last stage 1 gaps and the deferred minors (build `F3F6FE85`, deployed)

The user asked for these before stage 2.

**Two gaps where a purchase could be wasted:**
- **The Khan's Price on a faction at peace.** Its card says "a faction you are at war with",
  but the till took any faction other than the buyer's, allies included. `GG.target_ok` now
  requires the war. The buyer is refused too, because no faction is at war with itself.
  The first draft kept a separate self-check, which no test could break, so it was deleted.
- **The map reveal on the buyer's own region.** You paid to reveal what you already see.
  `GG.target_ok` now refuses the buyer's own region. An abandoned region is still a target,
  since it can be under the shroud.
- `GGUI.pick_target` puts both through `GG.target_ok`, as the army and settlement picks
  already did, so the pick card waits instead of returning to a refusal. Both hints now say
  what is needed.

**One gap not fixed, by ruling.** Outside Immortal Empires and Realm of Chaos, lords top out
at rank 41. The extra tiers in `character_experience_skill_tiers` exist only for
`wh3_main_chaos` and `wh3_main_combi`, so this affects only the prologue. Fixing it would
mean trusting `cm:get_campaign_name()`, which `docs/VICTORY_CONDITIONS.md` §11 records as
unreliable.

**The deferred minors, all closed:**
1. **The first draw.** It never kept a card's current service, and on the first draw that
   service is the original default. So a new campaign never showed the original 18 in its
   first period, and a save from before the pools had every card replaced at the next turn
   start, with no notice, while the countdown still ran. Now there are two cases:
   - On turn 1 the draw takes from the whole pool.
   - A faction with no cards past turn 1 records the originals as this period's cards. They
     change at the period boundary, with the notice.

   This reverses the plan's pinned behaviour, so the bounty harness's rotation test was
   updated.
2. **"New services in 1 turns".** `GGUI.countdown(n)` now uses its own line for one turn,
   "New services next turn".
3. **The notices setting's tooltip** now names the rotation notice. The MCT settings file is
   hand-written, not generated.
4. **The Lua/Python mirror.** `check_service_mirror` now also compares `with_bundle`, `heal`
   and `hostile`, with a missing flag read as false, the way Lua reads it. The selftest
   drops the Guild Loan's `with_bundle` and sees the check fail.
5. **Unlit side bundles.** `GGUI.service_running` now lights a service whose bundle is
   running, so the Guild Loan's drawback and The Great Work light their cards.
6. **The no-target loop.** It now puts every targeted service on its card, lifts the
   monopoly for the loop, and gives each kind a target the till accepts. It tests all 18,
   up from a floor of 4, and asserts that the tested count equals the targeted count.
7. The `feeds =[` typo.
8. (Ranks for a max-rank character: closed in §3g.)

**Fixtures corrected, not weakened.** Four existing fixtures had relied on what the gaps
allowed:
- two Khan's Price buys on factions they were not at war with;
- the rivals' reveal of a region the fixture's map did not contain, whose
  `owning_faction()` also lacked `is_null_interface`, which every real faction interface has;
- the pick-mode test's reveal of a region nobody owned.

Each now declares what the card requires.

**Tests.** The new harness block failed before each fix. There are 9 new mutants, 78 in
all, and every one is caught.

## 4. Check in game

1. Hire now grants its unit.
2. A rotation at turn 10 raises the feed message without opening a panel.
3. Each new kind lands: Forced March on an army, Granaries on a province, Sow Discord on an
   enemy province, Warlord's Honour's ranks.
4. Field Surgeons heals.
5. The three `_unseen` lines show nothing in the breakdown, but their numbers are in the card
   text.
6. A hostile region bundle behaves correctly after the region changes hands.
7. Each race's frame (§3e). Check it as at least one two-layer race (Kislev or Bretonnia)
   and one other:
   - the panel opens in that race's frame, not a blank one;
   - clicking a tab moves the open plate;
   - hovering brightens a closed tab;
   - a running service lights its card in the race's colour, with a soft glow and no
     hard edge.
   The preview's nine-slice and tiling are an approximation of the engine's.
8. Hire with a full army selected: the card keeps asking for an army with room, and
   Select does not bring the panel back on that army. Then with an army of 19: it buys
   and the regiment arrives.
9. The Khan's Price with an ally's lord selected: the pick card keeps waiting. Then
   with the lord of a faction you are at war with: it buys. Hobgoblin Eyes (or your
   race's reveal) with your own town selected: it keeps waiting.
10. An existing save loaded into this build keeps its cards until the countdown ends,
    and the change arrives with the notice. On the last turn of a period, the footer
    reads "New services next turn".
