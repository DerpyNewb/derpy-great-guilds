# The Great Guilds - eleven quality-of-life changes to the panel, and the tooltips it never showed

2026-09-25. Built, packed and deployed to `data/`:

- `derpy_great_guilds.pack`, MD5 `a3918816471ff4c246a60a0d2bc86507`, 32,148,457 bytes. The MD5
  matched on both sides. This is the build after the preview (section 5).
- The first QoL build, `74afe8eae3475ff3c20e2b63cc28e1df` (32,144,734 bytes), is backed up as
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_preview_fixes_74afe8ea`.
- The build before QoL (`40fe934a`, see `HANDOFF_20260925_GUILDS_MP_MCT.md`) is backed up as
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_qol_40fe934a`.
- Not pushed to GitHub. Not uploaded to Steam.

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
