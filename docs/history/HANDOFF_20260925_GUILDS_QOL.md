# The Great Guilds - eleven quality-of-life changes to the panel, and the tooltips it never showed

2026-09-25. Built and packed:

- **Current, 2026-09-26:** MD5 `7f9d5cf2e71ea5788dbc20ac21e16dba`, 32,266,153 bytes. It
  fixes the card streaks and the empty price plates (section 9). Built while the game was
  running and deployed by a background copy once it closed, after checking that `data/`
  still held `1a9b7828`. MD5 matched. Not pushed, not uploaded.
- `1a9b7828529aad5f1784fb99f2d78362` (32,265,300 bytes) lit the card of a running service and
  gave every effect bundle an icon (section 8). Backed up with the suffix
  `.bak_20260926_pre_atlas_fix_1a9b7828`.
- `056810bc2182ed85082a51c681251c90` (32,157,734 bytes) fixed the tab and price text seen in
  game (section 8). It was deployed by a background copy once the game closed. Backed up with
  the suffix `.bak_20260926_pre_lit_cards_056810bc` in `Modpacks/` and `data/`.
- `54e67bc9ea44a86ef81ff7a3c6586907` (32,157,758 bytes) dressed the panel in CA's Chaos Dwarf
  frames (section 7). Backed up with the suffix `.bak_20260926_pre_text_fit_54e67bc9`. The
  `da1c0218` before it is backed up with the suffix `.bak_20260926_pre_chd_art_da1c0218`.
- `derpy_great_guilds.pack`, MD5 `da1c0218ea4134c3cf72a5755455d836`, 32,151,169 bytes. This
  build adds the leadership fix (section 6). It was built while the game was running and
  copied into `data/` once the game closed, after a check that `data/` still held
  `a3918816`. The MD5 matched on both sides.
- `a3918816471ff4c246a60a0d2bc86507` (32,148,457 bytes), the build after the preview
  (section 5), was deployed and MD5-matched. It is backed up as
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_lead_margin_a3918816`.
- The first QoL build, `74afe8eae3475ff3c20e2b63cc28e1df` (32,144,734 bytes), is backed up as
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_preview_fixes_74afe8ea`.
- The build before QoL (`40fe934a`, see `HANDOFF_20260925_GUILDS_MP_MCT.md`) is backed up as
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_qol_40fe934a`.
- Pushed to GitHub on 2026-09-25 as commit `6998466`, which covers builds 7DBE88C6 through
  A3918816, and DA1C0218 as `c59e55b`. The repo copy of this handoff predates this line.
  Not uploaded to Steam.

The request was "find qol features that can be added on the UI". Eleven were proposed; the
answer was "do all". A twelfth, the tooltip fix, turned up while building them.

## 1. What was built

0. **Every tooltip in the panel can now be seen.** `docs/CUSTOM_UI.md` records that a tooltip
   on a component that is not interactive is never shown. 1,670 of CA's 1,747 component
   tooltips sit on interactive components. The panel's `set_tooltip` never set the flag, so
   none of these tooltips were ever shown:
   - the service cards (description, rank shortfall, cooldown);
   - the cost cell (why the price moved);
   - the rank line (upkeep and rival);
   - the footer and the earned line.

   Only the standings rows and the opener, which were already interactive, showed theirs.
   `set_tooltip` now calls `SetInteractive(true)`. The card and the faction row are also
   declared interactive in their `.twui.xml`, and `gen_guilds_ui.check()` asserts it.
1. **Escape closes the panel.**
   - The flow is `GGUI.hold_esc` / `GGUI.drop_esc` around `cm:steal_escape_key_with_callback`.
   - The panel tracks which names it holds, because CA's two calls are not symmetric. Stealing
     a name that is already held is a `script_error`. Releasing a name that is not held lets go
     of Escape outright once no entry is left, and that would include a plain
     `steal_escape_key` that some other script relies on.
   - A fired entry is removed by CA, so the callback clears its own mark before it runs.
   - No key is taken when `open()` did not actually create the panel.
2. **The HUD opener's tooltip lists what its count is counting:** each buyable service with
   its guild, the number of bounties to take, and a payable demand. With nothing waiting it
   says "Nothing needs you right now."
   - It no longer repeats the rules, which are on the panel title's hover.
   - `GGUI.actionable_items` builds the list. `GGUI.actionable` is now its length, so the
     badge and the tooltip cannot disagree.
   - **Changed count:** a TAKEN bounty offer no longer counts. It has no button on the board.
3. **The arrows say where they go.** On Guilds and Court an arrow names the next guild and
   how many of its services are ready. On Help and Log it says Next page or Previous page. At
   either end it says "Nothing further this way."
4. **A big CA panel closes this one.** This uses `PanelOpenedCampaign` with the whitelist
   `GGUI.CLOSE_FOR`. Every name in it is one CA's own scripts compare `context.string`
   against. The settlement and unit panels are deliberately left off, because a stray click
   on the map raises them.
5. **A big spend asks first.**
   - A hostile service, or one costing half or more of the favour held with that guild, turns
     its button into a yellow Confirm on the first click.
   - Changing tab or page forgets the question.
   - `GGUI.card_state` is now shared by the draw and the click, so they cannot disagree.
6. **A Leaderboard row's guild icon opens that guild's services.** The row itself still picks
   the faction list.
7. **Pick a target with the panel out of the way.**
   - A service waiting on a map target gets a live "Select" button in place of a dead Buy.
     Pressing it closes the panel and puts a card at the top of the screen saying what to
     select. The card is the card template, created on the root at design y 110.
   - `CharacterSelected` and `SettlementSelected` re-check 0.1 s later, because CA's
     `campaign_ui_manager` records the selection in its own listener for the same events.
   - The first selection that is a target reopens the panel on the same page. It buys
     nothing.
   - Escape, the card's Cancel and the HUD opener end the pick and reopen the panel. A big
     panel ends it and reopens nothing.
   - Research is excluded, because its target is picked in the tech tree.
   - The Court's Appoint with no lord selected picks one the same way.
8. **A bounty card on the board is a map link.**
   - A click pans to the settlement, or to the lord, through `display_position_x/y`.
   - It uses `cm:scroll_camera_from_current(true, 0.6, {x, y, d, b, h})`, with the camera's
     own distance, bearing and height read back, so the pan does not zoom.
   - The tooltip mentions the link only where a position exists; a dead lord has none.
9. **A faction in the Leaderboard's list pans to its capital.** This is promised only for a
   faction with a home region. `GGUI.LIST_FACTIONS` maps each row to its faction.
10. **Six guild buttons between the arrows**, on Guilds and Court only:
    - each is the guild's glyph at 38x38, with the badge's gold count of ready services in
      the corner;
    - a 4px gold bar marks the current page;
    - the six sit at 256..534, centred on the panel.
11. **Log filters:** All / Yours / Rivals / Ranks, on the Log only.
    - The buttons are 110x24, in the band the reputation bar uses on the Guilds tab.
    - A filter starts from the newest page.
    - An empty filter says "Nothing of this kind yet. Press All to see every entry." It does
      not say the log is empty.

## 2. Rulings

- **The card and the faction row have no click sound.** They are interactive for their
  tooltips and the map links. On the Guilds and Court tabs a click on the card body does
  nothing, and a sound would say that something happened. On the board and the list, the
  camera moving is the feedback.
- **The guild buttons have no plate:** just the glyph, the way the row icons are drawn. The
  tooltip and the gold bar do the work of a hover state.
- **Pick mode does not save the tab or page.** Nothing can change them while the panel is
  shut. The first version saved and restored them, and a mutation run showed the restore did
  nothing.
- **`||` in `SetTooltipText` is still unproven.** Memory `wh3-tooltip-pipe-split-needs-literal-text`
  says the split is verified only through the XML attribute. This panel has always put `||` in
  runtime tooltips. Until now most of them were unreachable, so the first hover of a service
  card in this build is the test.
- **Skipped:**
  - A draggable panel, because the pick mode covers the need.
  - A hotkey, because Escape is the only key a script can steal.
  - Reacting to UI Scale changes, because no event exists for them.

## 3. Tests

A new block in `tools/_guilds_harness.lua` builds a fake UI that answers lookups the way the
engine does:

- a component exists once something created it;
- a find from the root lands inside the panel;
- a destroyed panel takes its children with it;
- a missing component is `false`, not nil;
- the engine can refuse to create a component.

The block drives the real click and hover listeners. It stubs CA's Escape calls with CA's own
behaviour, and stubs the camera, the selection and `GG.mp_send`. There is one section per
feature.

**Mutation run:** 37 mutants, one or more per feature, and **all 37 killed**. The first run had
two survivors, and both were gaps in the tests rather than the code:

- the release count was sampled after Escape's own `close()` had already released;
- nothing tested an `open()` whose panel was never created.

Both tests were fixed. Last session's seven Leaderboard mutants still die.

**Also green:**

- `luac` on all four scripts;
- `check_lua_api`, `check_lua_literal_left` and `check_lua_undeclared`, which reports only the
  existing `BUTTON*` names;
- `gen_great_guilds --check` and `--selftest`;
- `gen_guilds_ui --check` and `--selftest`;
- `check_guilds_ui`;
- `preview_guilds_panel --check` and `--selftest`;
- the import's saved-pack verify, with the four scripts and six `.twui.xml` files in the pack
  byte-identical to staging.

`gen_guilds_ui.check()` caught all 22 new loc keys before they were added.

## 4. Owed: checks in game

1. **Hover a service card.** Check two things:
   - whether `||` breaks lines or prints as pipes;
   - whether a long description line wraps or clips. These tooltips have never been on screen.
2. **Escape** closes the panel, and then Escape opens the game menu as normal.
3. **Pick a target:**
   - where the pick card sits (design y 110, below CA's top bar?);
   - that selecting a settlement or an army reopens the panel;
   - that Hire the Immortals, The Khan's Price and Raise the Ziggurat each accept what their
     card asks for.
4. **A bounty card, and a faction in the list:**
   - the camera pans and keeps its zoom;
   - the mouse wheel still scrolls the list with the cursor over a row, now that rows are
     interactive.
5. **The tech tree and the diplomacy screen** each close the panel.
6. **The guild buttons:** the count is readable in the corner at 38px, on the round plate.
7. **The filter buttons:** the captions fit on 24px plates.

## 5. The preview, and the three faults it found

The request after this build was "generate preview". `tools/preview_guilds_panel.py` drew
only the Leaderboard. It now writes four pictures to `.skilltree_cache/ui_preview/`:

- `gg_standings.png`: the Leaderboard, unchanged.
- `gg_guilds.png`: the Guilds tab, with three cards showing the three button states (Select,
  a yellow Confirm, and a red Buy under a red "Needs" rank), the reputation bar, and the six
  guild buttons with their counts.
- `gg_log.png`: the Log with its filters, All lit in yellow.
- `gg_pick.png`: the pick card carrying the longest instruction any service has (Raise the
  Ziggurat).

Card text comes from the loc (`service_desc_<key>`), the same strings the game shows. The
colours are CA's own from `db/ui_colours_tables`, and `--selftest` asserts them when the cache
is present.

The pictures found three faults. All three were fixed in `a3918816`:

1. **The guild-button counts were unreadable.** The glyph was image 0, drawn edge to edge, so
   the gold number sat on top of the icon's own art. The buttons now wear the round plate
   (`ROUND_LAYERS`) with the glyph inset 5px as image 1. `GGUI.GUILD_BTN_ICON = 1` says which
   image the Lua repaints, and `gen_guilds_ui.check()` pins it to `GTAB_ICON`. Without the pin,
   the Lua repaints the plate instead and every button shows the placeholder brass glyph.
2. **The pick instruction ran off the card.** It was written as one line into `card_desc_1`,
   with "Press Escape or Cancel" in `card_desc_2`. The instruction now wraps across both lines
   (`GGUI.wrap`, two lines), and the Escape note moves to the card's tooltip.
3. **`text_ratio` returned 1 while the panel was shut.** It measures a label inside the panel,
   and the pick card is the one thing drawn while the panel is closed. It now falls back to
   `GGUI.RATIO_SEEN`, the last ratio measured, so the pick card wraps at the same scale the
   panel did.

**Tests.** The harness gained a wrap test, with a stubbed localiser returning "select a town
first" over two lines, and a `text_ratio`-with-the-panel-shut test. There are three new
mutants, **40 in all**, and 39 are killed by the harness. The survivor, `GUILD_BTN_ICON = 0`,
is expected, because the harness reads the constant. `gen_guilds_ui --check` catches it
instead: it exits 1 on the mutant and 0 on the restored file. Every check in section 3 was
rerun green on this build, and the packed scripts and `.twui.xml` files are byte-identical to
staging.

**What the preview cannot tell you.** Text is drawn in PIL's font, so a width is an estimate.
Whether a caption fits on its plate is still an in-game question (section 4, items 6 and 7).

## 6. The Brass Tablets changed hands twice in one round (build `da1c0218`)

**The report:** a screenshot of the event feed at the start of turn 2 showed "The Brass
Tablets Have Turned Away" and "The Brass Tablets Answer To You" together.
`script_log_250926_2144.txt` gives the order:

- 486.2s: the end-of-turn-1 autosave. You held brass on 8, all of it turn-1 income, and no
  AI faction had been paid anything yet.
- 492.9s: `lead_lost_brass`, during the AI turns. A rival's turn start paid it its income
  and put it ahead.
- 540.9s: `lead_won_brass`, at your turn-2 start, when your income put you back in front.

**Cause.** `GG.hold_lead` keeps a guild with its holder unless the challenger is more than
a margin ahead, and that margin was one upkeep tick. Upkeep does not start until turn 25,
so the margin was 1 point. But Brass Tablets income is paid at each faction's own turn
start, which is the same half-charged world the upkeep rule was written for. Two factions
closer than one turn's income swap the guild at every turn start: a bundle moved each time,
the monopoly moved with it, and a popup fired. The same payment also charges the Khanate
through rivalry, so the Khanate could swap the same way.

**Fix.** The margin is now the largest of:

- the upkeep, as before;
- `GG.turn_start_pay(held, guild)`: the holder's next turn-start pay, read live from its
  net income with the patron share and the cap applied. It is Brass Tablets only, and it
  covers a holder sitting low because it has not been paid yet;
- `GG.turn_start_charge(top, guild)`: the challenger's rivalry charge from that same
  payment. It is Khanate only, and it covers a challenger sitting high because it has not
  been charged yet.

The two terms point in opposite directions: an unpaid faction sits too low and an
uncharged one sits too high. `GG.with_patron`, `GG.guild_cap`, `GG.brass_from_income` and
`GG.rival_loss` were split out of the functions that pay, so that the margin and the
payment work from the same numbers.

**Tests.** Three scenarios in the harness, each played in the single-player turn order:

- you earn 8 and a rival earns 12: brass changes hands once, to the rival, and stays;
- a rich holder and a poorer challenger who sits just ahead: nothing moves;
- the Khanate charged 4 and 10 a turn: nothing moves.

Plus direct checks on the cap, the patron share, the campaign's own brass rate, and a
charge of zero on every guild but the Khanate. The first and third scenarios failed against
the old code with exactly the live pattern: moves "rival, you, rival" and "rival, you,
rival, you". Twelve mutants were all killed. Every check in section 3 was rerun green.

**What it costs.** A genuine overtake now takes a turn or two longer to register, because
the challenger has to get clear of one turn's pay.

**Owed in game:** watch the feed across the first five turns of a new campaign for any
guild announced lost and won in the same round.

## 7. Chaos Dwarf frames (build `54e67bc9`, 2026-09-26)

**The request:** a screenshot of CA's Hell-Forge panel and "use more of the chaos dwarf ui
borders and elements, the same as other factions".

**What CA does.** The Hell-Forge layout asks for `ui/skins/default/panel_title.png`, but the
screenshot shows the spiked Chaos Dwarf plate. That plate is
`ui/skins/wh3_dlc23_chd_chaos_dwarfs/panel_title.png`, a different file, so the game swaps a
default-skin path for the player's culture copy. Fifteen cultures ship their own
`panel_title.png`; Empire has none and gets the default. CA also reuses the Hell-Forge
frames in other factions' panels: `sub_title.png` in Nurgle's plagues and the convoys panel,
and the large square button in the High Elves' Valiant Imperatives.

**What changed.** Everything is CA's art, referenced by path, and nothing new ships. Every
margin is copied from the CA component that draws the same file (`hellforge_panel_*`,
`military_convoys`). The source list is `HF` and the layer lists above `_panel()` in
`tools/gen_guilds_ui.py`.

| Part | Now |
|---|---|
| Title | `panel_title.png` at 600x54, the default path so the culture swap applies |
| Header line | `cap_title_holder.png`, the bar "Melee Infantry" sits on; the text lifted onto its dark band (`RANK_TX`, `RANK_TY`) |
| Header glyph | new `gg_rank_mark`: `cap_category_iconm_holder.png` with the guild on screen (`GGUI.ground_guild`) at image 1 |
| Reputation bar | the convoys panel's segmented bar as the track, its own fill texture as the bar, in the trough (x 18..338, y 8..21 of 356x29) |
| Service cards | `cap_group_background.png`, sliced left and right only |
| Card glyph | in the round holder, 100x106, glyph 62 at image 1 (`GGUI.CARD_ICON_INDEX`) |
| Price | `sub_title.png` |
| Tabs | `button_square_extra_large_*`; the open tab wears `_selected` / `_selected_hover`, set by the Lua from `GGUI.TAB_PLATE` |
| Guild buttons | new `gg_gbar`: `buttons_holder.png` behind the six, shown with them |

Buy, Select, Confirm, the arrows, the close cross and the Log filters are unchanged.

**Code.**

- The emitter now writes a four-value margin (top, right, bottom, left, CA's order).
- The new glyph layers are placed by offset with no dockpoint, because the two stack on an
  image (`docs/CUSTOM_UI.md`).
- `holder_layers()` centres a glyph on the holder's dark disc, measured off the file at 0.484
  across and 0.455 down.
- Lua: the new layout coordinates, `REP_BAR_W` 714 and `REP_BAR_H` 13, three card repaints
  moved to `GGUI.CARD_ICON_INDEX`, the header glyph repaint, the open-tab plate, and `gg_gbar`
  shown and hidden with the guild buttons.

**Found by the preview.** The header holder was first named `gg_rank_icon`. That sorts
before `gg_rank_line`, so the bar drew over it and it vanished. It is now `gg_rank_mark`.

**New checks in `gen_guilds_ui.check()`:**

- the draw order of both new pieces;
- `CARD_ICON_INDEX`, `RANK_ICON_INDEX` and `TAB_PLATE` against the generator;
- all four tab plates exist;
- no nine-slice whose margins meet;
- the layer bounds check now covers every new layer list;
- the icon-size check now measures the card glyph, not its holder.

The preview extracts the selected tab plates, draws the open tab and both glyphs as the Lua
paints them, and crops the fill to the fraction earned.

**Tests.** Green:

- the harness, after one fix: its 2x scaling test hardcoded the title's old position;
- `gen_guilds_ui` `--check` and `--selftest`, and TWUI Studio's reader (`preview --check`,
  `--selftest`);
- `check_guilds_ui`, `gen_great_guilds --check`, `check_lua_api`, `check_lua_literal_left`
  and `check_lua_undeclared`;
- `luac` on the Lua.

The importer's verify passed, and the packed scripts and all six `.twui.xml` files are
byte-identical to staging.

**Owed in game:**

1. The title plate is the spiked Chaos Dwarf one. The swap has only been seen on CA's own
   panels, never on a component created by script. If it is the plain default, point
   `TITLE_PLATE` at `ui/skins/wh3_dlc23_chd_chaos_dwarfs/panel_title.png`; that loses the
   per-culture plate.
2. The open tab shows the selected plate, and hovering it shows the selected hover.
3. The reputation fill narrows correctly. It is a texture now, not a flat tint.
4. The header text sits on the bar's dark band, clear of the round holder.
5. The pick card, created on the root, draws the new plate and holder.

## 8. Text fit, lit cards and effect icons (builds `056810bc` and `1a9b7828`, 2026-09-26)

**Seen in game on `54e67bc9`**, with the report "the texts are off and overflowing":

- **The title plate did swap** to the spiked Chaos Dwarf plate on a script-created panel.
  Section 7's owed check 1 is settled.
- **Tab captions ran over the plate's frame lines.** The tab plate was sliced at its frame
  rows (10 and 12px), which left 12px of red at 34px tall. It is now sliced left and right
  only (`0,12,0,12`) and squashes as one picture, which leaves about 24px of red.
- **Prices sat on the plate's top rim.** The plate had been drawn 3px low to centre its art
  on the box. But the game font draws a Center-aligned line about 2px high, and the plate's
  own art already sits about 2px high (rows 1..24 of 30). It is back at the full box.

Built as `056810bc` while the game was running, and deployed by a background copy once it
closed. The copy first checked that `data/` still held `54e67bc9`.

**Then asked:** "active effects should also have the background have effects, similar to
the commission mod". Asked which effects; the answer was both of these:

- **A running service lights its card.** `GGUI.service_running` is true when the service is a
  bundle kind, is not hostile, and its tagged bundle `derpy_gg_svc_<key><tag>` is on the
  buyer (`faction:has_effect_bundle`). `GGUI.light_card` then swaps two card layers from CA's
  transparent `effect_bundles/icon_blank.png` to CA's own "active" art:
  - the Hell-Forge `heat_glow.png`, across the card's left 300px;
  - the Tower of Zharr `district_complete_glow_02.png`, as a rim with margin 40.

  The layers are indices 1 and 2 (`GGUI.CARD_HEAT_INDEX` and `CARD_RIM_INDEX`). Every refresh
  unlights all three cards first, because the bounty board and the Court reuse them.
- **Every effect bundle has an icon.** All 379 shipped `ui_icon = ""`, so the game's effect
  lists drew them bare. Each one now names `derpy_gg_<guild><tag>.png`: rank, lead and
  service bundles use their guild, and the patron uses the crest. The race pass re-tags the
  name the way it re-tags the key.
  - `tools/make_guild_bundle_icons.py` writes the 55 icons. Each is the guild mark over CA's
    teal disc, at 24x24 like all 1,115 of CA's.
  - CA ships no bare disc, so the tool recovers it on every run from the 520 CA icons that
    carry it. It fits the circle to the clean left and bottom arc (centre 11.0,13.1, radius
    10.0). The teal comes from CA's pixels where at least half those icons show it, and from
    a quadratic fit under the glyphs. The rim follows the measured radial profile.
  - The importer packs only `derpy_gg_*` files from that shared folder, and refuses when an
    icon a bundle names is missing.

**The rites panel's animated background** (smoke-particle emitters with a
`particle_move` animation, in `rituals_panel.twui.xml`) was found and **not** copied. That
may be what "effects similar to the commission mod" meant. It is the next thing to offer.

**Found, not ours:** while this was being built, `tools/gen_ic_ui.py` and all 13
`derpy_ic_*.twui.xml` files changed on disk (21:46), from something else working on the Iron
Court. Nothing here touched them.

**Tests.**

- A harness test for `service_running` and `light_card`. Four mutants were run against the
  shipped Lua and all four were killed: dropped hostile check, dropped race tag, swapped glow
  index, dropped kind check. The last survived at first, because the test never put a gold
  service's bundle on the faction; the test now does.
- `gen_guilds_ui --check` pins both indices and all three paths. It failed as expected on a
  drifted index and on a drifted path.
- `make_guild_bundle_icons --selftest` checks the fit on CA's clean arc: 18 levels on the
  disc face (limit 20) and 35 on the anti-aliased rim (limit 45). `--check` confirms every
  named icon is staged.
- Every section 3 check is green again, and the harness passes. The packed files and 3 of
  the icons are byte-identical to staging, and the pack holds 55 bundle icons, all ours.

**Owed in game:**

1. Buy a lasting service (Knife in the Dark, Writ of Monopoly): its card glows, and the glow
   clears on the Bounties and Court tabs and once the service expires.
2. The Faction Effects list shows each guild row with its mark on the teal disc.
3. The tab captions and prices sit inside their plates.

## 9. Streaks over every card, and empty price plates (build `7f9d5cf2`, 2026-09-26)

**Seen in game on `1a9b7828`** (three screenshots, with the question "are you using the
preview tool?"): streaks, gold arrows and red and blue bars across every card on the Guilds,
Bounties and Court tabs, and an empty dark price bar on the Court's demand and patron cards.

**The streaks: a 9-slice margin larger than its texture.** The card's rim layer had margin
40 and shipped, as its "off" image, CA's `icon_blank.png`. That file is 24x24, so the slices
reached outside it into the texture atlas and drew the art beside it.

The preview could not show this: TWUI Studio rasterises the PNG alone, with no atlas behind
it. The check for "margin under half the component" did not catch it either, because the
limit that matters is the texture's.

- **Fix:** the "off" image is now `derpy_gg_icons/clear.png`, our own fully transparent
  128px file, written by `gen_guilds_ui --write`.
- **New check:** `check_margins_fit_textures()` tests every layer of every file against its
  shipped texture, and also against every texture the Lua swaps in (the four tab plates and
  the two card glows). It reports exactly this fault when `icon_blank` is put back, and
  nothing else in the panel.

**The empty plates.** A price plate draws whether or not there is a number on it; the old
bare text was invisible when empty. `GGUI.set_cost` now owns every write to `card_cost`, so
the plate shows exactly when there is a price. There were four writes: an empty service
slot, a service, a bounty, and `fill_card`.

**Tests:** a harness test for `set_cost`, with two mutants run against the shipped Lua (plate
always shown, nil not treated as empty), both killed. Every check in section 3 was rerun
green. The packed Lua, the card and panel layouts and `clear.png` are byte-identical to
staging.

**Answer to the question.** The preview was used for every build. It showed the layout
correctly, but it cannot show engine-side sampling, which is what this fault was. The new
check covers that class of fault without the preview.
