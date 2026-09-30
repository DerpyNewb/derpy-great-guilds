# Great Guilds panel polish - 2026-09-30

How the panel looks, in four passes on one day: frame edge and main-menu smoke, title and
icons, per-race frame repair, and the Dwarfs' own backgrounds. **Current build `0A1DD16B`,
in data/ and pushed to GitHub.** None of it has been seen in game except smoke v1.

## 1. Builds

| Build | What | Where |
| --- | --- | --- |
| (unnamed, after `4C532CBB`) | ground inset 4px under the border; smoke v1 (`8.00,10.00`, `#FF822EFF`) | data/, backup `.bak_smoke_border_20260930` = `4C532CBB` |
| (unnamed) | smoke v2 (`2.00,10.00`, `#FF822E3C`) | data/, copied while the game ran at the user's "deploy"; backup `.bak_smoke_subtle_20260930` |
| `B77AA0A1` | title plate 680 wide at x=55; 63 guild icons at 148px | data/, backup `.bak_title_icons_20260930`; GitHub `8076c83` |
| `A7EBBBB4` | per-race frame repair (section 5) | data/, backup `.bak_race_frames_fix_20260930` = `B77AA0A1` |
| `0A1DD16B` | the Dwarfs' six own backgrounds (section 6) | data/, backup `.bak_dwarf_grounds_20260930` = `A7EBBBB4`; pushed to GitHub with the docs refresh |

`0A1DD16B`: MD5 `0A1DD16BB1C92BE574DC5BCC673ADD2D`, 34,642,231 bytes. The mod has no Workshop
entry; it lives in data/ with its built copy in `Modding Files/Modpacks/`.

Every deploy followed the same steps:

1. Diff Modpacks against data/ per file with `read_pack_index`, skipping the first 80 bytes of each db entry. Only the intended files changed.
2. Back up the data/ copy.
3. Copy, then md5 both files.

## 2. Frame edge, smoke, title, icons

- **Ground inset.** `GROUND_INSET = 4` in `tools/gen_guilds_ui.py`. The tile, art, smoke and scrim
  draw at (4,4), 782x692. `panel_back_border.png` is transparent for its outer 3px (alpha
  0,0,0,25, then 255 at pixel 4, on every side and corner). A ground drawn to the component
  edge therefore showed past the brown line.
- **Main-menu smoke.** `PANEL_SMOKE` is an image layer placed after the art and before the
  scrim, so the art stays image index 1 (`GGUI.BG_INDEX`). Panel layers, in order: tile, art,
  smoke, scrim, border.
  - The shader is `smoke_overlay_t0`, set on the `<image>` with `shader_name` +
    `shadertechnique_vars`, which `tools/gen_guilds_emitter.py` now writes.
  - The mask is `ui/skins/default/panel_back_smoke.png`.
  - v1 was seen in game and was too strong and too dense. v2 uses `2.00,10.00` at alpha `3C`,
    and both numbers are CA's own.
- **Title.** `gg_title` is (55,0,680,54), set in both `PANEL_LAYOUT` and `GGUI.PANEL_XY` in
  `zzz_derpy_guilds_ui.lua`; check() compares the two.
- **Icons.** `upscale()` in `tools/make_guild_icons.py`:
  1. alpha LANCZOS to 4x;
  2. steepen the ramp by `EDGE=2.0` about 128;
  3. BOX back down to 2x.

  `build()` rewrites the 63 entries in `tools/ui_icon_sizes.json` itself. A side effect: the
  faint haze around the furnace icon is gone.

## 3. Verified, and how

These pass:

- `gen_guilds_ui.py --check` and `--selftest` (2319 guids);
- `check_guilds_ui.py`, 0 problems;
- the TWUI reader (`preview_guilds_panel.py --check`);
- `check_lua_api.py`;
- `luac -p`;
- `make_guild_icons.py --selftest`;
- `make_guild_backgrounds.py --check` / `--selftest`;
- `make_ic_backdrop.py --check`.

The preview contrast check is clean on all five views of all nine flavours; the last full run
was at the end of the day. Renders are in `.skilltree_cache/ui_preview/`, with the six Dwarf
Leaderboards as `gg_standings_<guild>_dwf.png` and on one sheet, `gg_dwf_grounds_sheet.png`.

## 4. Corrections found the hard way

- **`smoke_overlay_t0` is undocumented.** It is absent from the shader table in
  `uicomponent.html`, so its values are copied from CA, never derived:
  - the main menu's idle state is `8,10,0,0`;
  - the hover, selected and new states drop the first number to 4, 2 and 1.

  At 8 on a 790px panel it drew a dense orange mottle. The first number is assumed to be
  grain density (unconfirmed).
- **The main menu's mask is the wrong donor.** `porthole_back.png` is an opaque grey texture,
  so on a panel it would cover the art. `panel_back_smoke.png` (flat black, alpha 102) is
  CA's panel-sized mask; the Silent Sanctum confirm box and the Oxyotl drop-down use it.
- **State-level vs image-level.** On a `<state>` the attribute is `shadervars` and applies to
  every layer. On an `<image>` it is `shadertechnique_vars`. 44 of CA's campaign uses are
  image-level.
- **The game held data/ open but the copy still succeeded** (exit 0, md5 matched) while
  Warhammer3.exe ran. The running session keeps the old pack until a restart.
- **A literal path in a mutation test goes inert.** The selftest's Bretonnian mirror mutation
  named a tab file that the frame repair then replaced, so it stopped matching and still
  "passed". It now takes the path from `FRAMES` and asserts the mutation changes the Lua.

## 5. Per-race frame repair (`A7EBBBB4`)

The user sent a Dwarf screenshot: "so many ui getting cut-off and blurry ... fix the borders
on the other faction UIs".

What was wrong:

- **Cut off:**
  - Dwarf tabs (the Book of Grudges bookmarks, one end square);
  - Dwarf cost and rank, which used half-frames;
  - the Dark Elf and Kislev card plates, which stopped short of the card;
  - the High Elf card, which showed two edges;
  - the Bretonnian tab ornaments, which collided;
  - the guild-bar end brackets under the first and last buttons on five races.
- **Blurry:** every race's holder was upscaled 1.3-2.3x, the Chaos Dwarfs' included. The
  Cathay card was stretched 3.3x tall and the Dwarf fill 3.25x.

How it was fixed:

- Seven research agents, one per race, proposed replacement `FRAMES[tag]` entries from CA
  art at or near native size. All seven were integrated.
- The shared `gg_gbar` is **(176, 595, 438, 40)**. The races asked for 398 to 510; 438 clears
  every race's end ornament.
- The Dwarf gbar is `bar_small_central_left` scaled whole. The Kislev gbar is NOT tiled. The
  Bretonnian gbar keeps 8px top and bottom so its tile cannot crop the lower rim.
- The Dwarf cost has a dark `1x1_blank_white` ground under its open frame. Without it the lit
  rim ran behind "150" at 2.3:1, which the preview's contrast check caught.
- The Chaos Dwarf holder is `chd_labour_economy/surplus_holder.png` (129px, crisp), with
  `ICON_HOLDER_CX/CY` 0.5.
- `GGUI.FRAME` in the Lua was REGENERATED from `FRAMES` by script, not hand-edited.

Also: `.skilltree_cache/ui_png_sizes.json` indexes 35,403 CA ui PNG sizes, but it misses about
2,287 ui2.pack PNGs, so a size search there is not exhaustive.

## 6. The Dwarfs' own backgrounds (`0A1DD16B`)

The user asked why the Dwarfs had only one picture, then supplied
`Modding Files/reference/Dwarf/`, eight paintings.

- `make_guild_backgrounds.py` gained `RACE_ART` (file, crop anchor, footer 0). The Dwarfs'
  `CA_BACKGROUNDS` windows and `CA_ART["dwf"]` are gone, and the selftest refuses a race that
  appears in both.

| Guild | Painting |
| --- | --- |
| Merchant Clans | the hammer lord under the storm sky |
| Hammerers | Thorgrim on his throne above the army |
| Engineers' Guild | Malakai with the lightning |
| Rangers | the goblin battle |
| Miners' Guild | the Irondrakes in the tunnel (anchor 0.1, else heads are cut) |
| Grudge-Settlers | the Slayer against the Skaven |

- Unused: the Slayer character sheet and the 528px throne picture.
- Three sources are 600-611px wide, so they are drawn up about 1.3x to fill the 790px panel.
  Larger copies would fix that.
- All six pass the brightness gate: p99 34.1 against CA's `tier_01`.
- **The user moved the Chaos Dwarf art into `Modding Files/reference/Chaos Dwarf/`.**
  `BACKGROUNDS` and `make_ic_backdrop.py` `SRC` now point there. The six Chaos Dwarf grounds
  rebuilt byte-identical, and the Iron Court backdrop check passes.

## 7. Do not re-derive

- **Most races have one picture.** The other five races' grounds are six WINDOWS of one
  loading-screen painting per race (`CA_ART` / `WINDOWS`), because CA ships exactly one
  `campaign_<race>1.png` per race. The Dwarfs and Chaos Dwarfs have their own art from
  `reference/`.
- **Culture skins.** They override only top-level generic files (13-28 per race, such as
  panel_title, bar_small_* and tech_tree_bg); Empire and the Dark Elves have none. There is no
  ready per-race set, so pieces must be chosen by hand.
- **The preview does NOT apply culture skins.** In game the Dwarf Buy plate is blue; in the
  preview it is red.
- **The preview cannot draw shaders.** The smoke layer shows there only as a slight darkening.
- **`tile="true"` crops, it does not scale.** The preview draws it that way. Three agents
  described tiled layers as "downscaled", so look at the tiled bars in game.

## 8. Open

In game, not yet seen:

- smoke v2 strength and grain;
- the title's clearance;
- icon sharpness;
- every race's new frames, especially the tiled bars (crop vs scale);
- the Dwarf backgrounds;
- Help-tab text contrast over the smoke.

Also open:

- The Cathay tab: its 62px glyph overlaps the octagon's 54px centre.
- A see-through text box at the Log tab's right edge ("Every rank you gain...") is drawn over
  the frame, as seen in a screenshot. The user was asked whether it is intended; there is no
  answer yet.
