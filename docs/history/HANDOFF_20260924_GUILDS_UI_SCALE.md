# The Great Guilds - the panel scales with the screen

2026-09-24. Built and packed (`Modding Files/Modpacks/derpy_great_guilds.pack`, MD5
`0c3860ab3c96803487bbf4caa57076b3`, 10,856,210 bytes, 60 files). **Deployed to `data/`
2026-09-24 08:36** (MD5 match; no Workshop copy of this mod exists). The previous build, which
`data/` held until then, is backed up as
`Modpacks/derpy_great_guilds.pack.bak_20260924_pre_scale_8b535825`. Guild panel only: the Iron Court and the Zharr Exchange
have their own sessions and were not touched.

## 1. The complaint, and what the engine actually does

4K players reported the guild panel's text and art as too small. The panel is a fixed
790x700.

**The screen a script sees is the window divided by UI Scale.** Two independent readings:

- CA's dev UI Scale slider (`ui/dev_ui/custom_dev_ui/common/ui_scale.twui.xml`) gates
  scale-up on `RootComponent.Dimensions.y * GameCoreContext.DevUiScale >= 1440`, so the
  physical height is the root height times the scale.
- This machine, 2026-09-24: `preferences.script.txt` had a 1280x720 window at `ui_scale 1`,
  and `core:get_screen_resolution()` reported **1600x900** in all four sessions. The engine
  clamps its layout screen to at least 1600x900 and shrinks the whole UI to fit the window.

So the panel already follows the player's UI Scale setting, exactly like CA's UI. What never
changed its size was resolution. A 4K player at 100% reports 3840x2160, where the panel covers
a quarter of the area it does at 1080p. CA's UI Scale option is manual ("Apply UI scale",
disabled below 1440p). Nothing in CA's loc or panels suggests an automatic one.

## 2. What was built

`GGUI.scale_for(sw, sh)` = `min(sw/1920, sh/1080)`, rounded to hundredths, never below 1.
Computed on every open from the root's `Dimensions()`.

| Screen reported | Factor |
|---|---|
| 1920x1080, 1600x900, 1280x720 | 1 (unchanged) |
| 2560x1440 (1440p at 100%) | 1.33 |
| 3840x2160 (4K at 100%) | 2 |
| 1920x1080 from 4K at 200% | 1 - the engine has already doubled it |
| 5120x1440 ultrawide | 1.33 (height-led, capped by width) |

- **Sizes.** `GGUI.scale_tree(panel)` walks the tree parent-first once, straight after
  creation. It calls `SetCanResizeWidth/Height(true)` and then `Resize` on every part, at
  GGUI.S times what the part measures. Faction rows in the list are scaled as
  `draw_faction_list` creates them. Art follows its box because it is the default: CA writes
  `canresizewidth` on an image only as `"false"` (7,585 times) and never as `"true"`.
- **Text.** Font categories stop at body_16, so a category swap tops out near 1.33x. The only
  route to any size is `font_scale`. Every text cell (44 of them, opener excluded) now carries
  a zero-length animation `derpy_gg_scale`: one frame, `interpolationpropertymask="512"`,
  `targetmetrics_m_font_scale="1"`. Its tag, id and position (after `<states>`, before
  `<LayoutEngine>`) are copied from CA's `ui/common ui/scripted_topic_leader.twui.xml`. The Lua
  rewrites the frame with `SetAnimationFrameProperty(anim, 0, "font_scale", S)` and plays it,
  which is exactly how CA's `lib_topic_leader.lua` shrinks its text. It also writes the grown
  size into the frame's `"scale"`, so a frame that applied its width and height despite the
  mask could not shrink the part back.
- **Positions.** Every offset in `GGUI.layout()` goes through `GGUI.px`. The panel is centred
  after the scale, on its new size.
- **Help-tab wrapping.** CA's reference does not say whether `TextDimensionsForText` measures
  at the scaled font. `GGUI.text_ratio()` measures a probe string on `gg_help_01` before the
  scale and again at wrap time. `GGUI.wrap` then puts its budget in the same units
  (`w * ratio / S`), so lines break where they do at 1x under either engine behaviour.
- **Slider travel.** `vslider.maxValue` and `handle.max_height` are user properties, not sizes.
  They are read with `GetProperty` and written back at GGUI.S times.
- **The HUD opener is not scaled.** It sits beside CA's resource strip and stays HUD-sized.
- Logged on every open: `GREAT GUILDS: panel scale S on a WxH screen, panel PWxPH`. Logged
  whenever it changes: `text measures xR at panel scale S`.

## 3. Files

- `zzz_derpy_guilds_ui.lua`: the scale block (`DESIGN_W/H`, `S`, `scale_for`, `px`,
  `SCALE_ANIM`, `scale_tree`, `PROBE`, `text_ratio`), plus changes to `layout`, `open`, the
  rep bar `Resize`, `draw_faction_list` and `wrap`. CRLF kept.
- `tools/gen_guilds_emitter.py`: `font_anim` emits the animation block.
- `tools/gen_guilds_ui.py`: `SCALE_ANIM`, `UNSCALED_FILES`, the `build_xml` pass that tags
  every text cell, and `check_scale_anim` (refuses a text cell without it, and pins the Lua's
  name). Watched failing on 44 cells before the emitter change.
- The six `.twui.xml` files were regenerated. They only gain lines: 13 per text cell. List and
  opener are byte-identical.
- `tools/_guilds_harness.lua`: a scale block covering 8 screen sizes; `scale_tree` against a
  fake tree at 1x (no calls) and 2x (exact call order); layout offsets at 2x; Help wrapping at
  2x measured both ways, equal to 1x.

Green: harness, `gen_guilds_ui --check/--selftest`, `check_guilds_ui` and its selftest,
`check_guilds_anchor`, `preview_guilds_panel --check/--selftest` (TWUI Studio's reader),
`gen_great_guilds --check`, `import_great_guilds --check`, luac, `check_lua_api`.
`check_lua_undeclared` reports the same ten cross-file names it reported before the change.

## 4. In-game checks owed

No 4K monitor is needed. At 1920x1080, set UI Scale to 50%, or set `ui_scale 0.5;` in
`%APPDATA%\The Creative Assembly\Warhammer3\scripts\preferences.script.txt`. The game should
then report 3840x2160, which is a 4K player at 100%.

1. At 100%: log `panel scale 1.00 on a 1920x1080 screen, panel 790x700`, and the panel looks
   as it did yesterday.
2. At 50%: log `panel scale 2.00 on a 3840x2160 screen, panel 1580x1400`. CA's HUD is half
   size, and the guild panel and its text are the size they are at 100%.
3. **Text keeps its size after the zero-length animation ends.** This is the one behaviour
   CA's code does not show: its topic leader destroys the component when the shrink ends.
4. Each part's art stretches with its box. Watch the Buy and tab plates: their pill offset is
   authored in design pixels.
5. The Help tab breaks its lines where it does at 100%. The `text measures x...` line says
   whether the engine measures scaled text (x2.00) or not (x1.00).
6. Standings list: rows fill the width, crests sit in line, and the handle travels the whole
   track.

If check 3 fails (text snaps back to 1x), the alternative is a two-frame animation whose last
frame holds the value. CA's `rite_performed` text ends that way.

## 5. Not done

- No `UiScaleChanged` listener. A player who changes UI Scale with the panel open gets the
  new size on the next open.
- `docs/CUSTOM_UI.md` gains the scale model and the font_scale route once check 3 is measured.
