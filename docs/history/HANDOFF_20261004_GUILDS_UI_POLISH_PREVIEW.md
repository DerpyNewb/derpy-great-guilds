# Great Guilds UI check and polish - 2026-10-04

The user asked: "check for the derpy great guild mod if other UI stuff need updating, implement
front end design polish". **Build `2EDAC23F` is in data/** (MD5 `2EDAC23F7D11528714ADCB03BF767D66`,
34,734,051 bytes; built copy in `Modding Files/Modpacks/`). The previous build `D1E0DB29` (the
2026-10-01 HUD hub rebuild of `0A1DD16B`) is backed up as
`Modding Files/Backup/derpy_great_guilds.pack.bak_pre_ui_polish_20261004`. The repo working copy
`repos/derpy-great-guilds` is synced (16 files) but **not committed or pushed**. **Nothing here
has been seen in game.**

## 1. What was out of date

- **`tools/_guilds_harness.lua` was RED and nobody knew.** Since the 2026-09-30 title move
  (`gg_title` x 95 -> 55), its 2x-scale layout assert still expected 95. The 09-30 handoff's
  "verified" list never ran the harness. It is fixed.
- **The Guilds preview was the old kind.** It retyped the Lua's strings and laid the panel out
  from the generator's coordinates. The 2026-10-03 rule (memory
  `render-ui-preview-before-shipping`) says a preview must be drawn from the shipped Lua. Court
  and Help had never been previewed at all.
- **The faction list kept the bare track and handle.** The Exchange moved to CA's whole
  event-message slider on 2026-10-04 (peer session 74's `ca_vslider` in `gen_guilds_ui.py`).

## 2. Built

### Tooling

- **`GG_DUMP` in the harness**, right after the tooltip sweep in the quality-of-life block.
  - With `GG_DUMP=<dir>` it opens the real panel on all six tabs over a demo save and writes
    `tab1..6.tsv`. Each row: key, x, y, resized w, h, visible, text, `index=path` images.
  - The demo save: the real `loc.tsv` English, a Slavers tribute due now, a Brass patron, the
    sweep's bounties, 32 log entries, and the longest Chaos Dwarf faction name for the rival.
  - `GG_DUMP_TAG=_emp` (etc) dumps it as that race.
  - The fake UI changed in three ways:
    1. `Position()` returns where a component was moved.
    2. `Resize` is recorded.
    3. `SIZE`, parsed from our twui files, answers `Dimensions()`, but only while dumping.
- **`tools/preview_guilds_panel.py` draws only from the dump.**
  - Functions: `snapshot`, `_where`, `draw_order`, `shown`, `write`, `render_tab`.
  - New checks:
    - `OVER`: a line wider than its box, and the header's heading plus figures wider than the bar;
    - LOW CONTRAST: as before.
    - Both make the exit code 1.
  - The selftest proves all six tabs dump and that the width check can fail.
  - The old hand-written views are deleted. No other tool imported them. The Iron Court, the
    Exchange, the Resource Vault and the hub import only `_studio`, `validate`, `extract_art`,
    `our_files`, `MARKUP`, `INK` and the path constants, and those are unchanged.
- **Harness block "THE HEADER, THE PLATES AND THE CARD TAGS"** and **four new mutants** in
  `tools/mutate_guilds.py`. All four are caught. The full run before the new four: exit 0.

### The panel (`gen_guilds_ui.py`, `zzz_derpy_guilds_ui.lua`, every `derpy_gg_*` twui)

1. **The header strip is two cells.**
   - `gg_rank_line` carries the heading at `header_18`: the guild on Guilds and Court, the
     chapter on Help, the view's name elsewhere.
   - The new `gg_rank_stats` carries the figures in body 12, right-aligned. Its inset is per
     race (`RANK_STATS_PAD`), because each race's bar ends in its own ornament.
   - `set_header()` sets the text and the hover on both cells.
   - "Hover a row for the full table" moved into the Leaderboard hover.
2. **A dark text field** (`gg_back_text` under the 21 Help/Log lines, `gg_back_list` under the
   faction list). It is a `#000000B4` wash ruled top and bottom with CA's
   `panel_back_divider.png`. It shows only on those tabs.
3. **Locked services** read `[padlock] Needs Sworn`. The padlock is CA's
   `ui/skins/default/icon_padlock.png`, inline, and the reason is in the name's own colour.
   - "Pick a target" is yellow, an instruction.
   - A cooldown reads "7 turns left", not "7t".
   - The dead Buy caption and the Court's deadline use `GGUI.LOCK_COL` = CA's `orange`.
4. **CA's whole slider on the faction list** (`ca_vslider`).
   - The track is at (732, 24) inside the list.
   - `GGUI.SLIDER_PARTS` MoveTo's the caps and arrows after the slider, guarded by a pcall.
   - `gen_guilds_ui.check_slider_parts()` pins the four rows to `CA_SLIDER`, as the Exchange
     pins `EX.SLIDER_PARTS` (peer 74's suggestion). The selftest proves an arrow 1px off is
     reported. The art under `ui/skins/default/` is red and brass; blue appears only under a
     player's UI colour theme, so a red preview is correct.
5. **Leaderboard cells**: `row_guild` widened 160 -> 170, `row_rank` moved 212 -> 222. "The
   Erengrad Merchants" and "The Naggarond Builders" overflowed. That fault was older than this
   session; the new width check found it.
6. The Cathay heading moved 98 in and 4px up, off the trident.

## 3. Verified, and how

- Every check passes:
  - `gen_guilds_ui.py --check` and `--selftest` (2494 guids);
  - `check_guilds_ui.py`, 0 problems;
  - `preview_guilds_panel.py --check` and `--selftest`;
  - both harnesses;
  - `mutate_guilds.py --selftest` (174 anchored);
  - `check_lua_api.py`, `check_lua_literal_left.py` and `luac -p`;
  - `import_great_guilds.py --check`.
- `check_lua_undeclared.py` lists 16 `GG.*` names. The list is identical on the pre-edit file:
  the names are declared in the model file, which a per-file scan cannot see.
- The preview is clean on **all eight flavours**: no low contrast, nothing too wide. The pictures
  are `.skilltree_cache/ui_preview/gg_<view><tag>.png`, and `gg_header_sheet.png` stacks the eight
  header bars.
- The importer's own verify passed. The saved pack was then read back with `read_pack_index`:
  every `.lua` and `.twui.xml` is byte-identical to the staged copy, and exactly 12 files
  differ from data/: the UI Lua, the 8 panels, row, list and frow. Nothing was removed.

## 4. Corrections found the hard way

- **`gen_guilds_ui.py` is shared, and was edited concurrently.**
  - Peer session 74 owns `SLIDER_ART` ... `ca_vslider_paths()`.
  - Peer 7c (Iron Court) imports `check_scroll_parts`, the scroll-list emitter, and
    `preview_guilds_panel`'s `_studio`, `validate`, `extract_art` and `CACHE`. Keep their
    signatures stable.
  - Run `ListAgents` before editing a shared generator.
- **"7t" is the game's text.** `draw_card` wrote it beside a service on cooldown.
- **Red does not read on the card bronze (2.2:1), and CA's orange does not either (4.4:1).**
  Neither reaches 4.5:1 on the Empire's lighter header bar (2.1 and 4.2:1). So the name-line
  tags and the header's upkeep and rival markers carry no colour; words and the padlock carry
  them. Orange stays only where it measured clear.
- **A right-aligned cell finds the bar's end ornament.** At one 48px inset, five races' figures
  sat on the ring, scroll, trident or horse heads. The left-aligned single line never reached it.
- **Bash heredocs broke twice** (an unmatched quote, eaten backslashes). Edit scripts went
  through the Write tool.
- `preview_guilds_panel.py`, `gen_guilds_ui.py`, the harness and the UI Lua are CRLF. Write
  them back with `newline="\r\n"`.

## 5. Do not re-derive

- The dump's positions are PANEL-RELATIVE: `reset()` clears the panel's own move.
- The engine stacks frows and owns the handle. The preview stacks the frows at `FROW_H` under
  `list_clip`, and puts the handle at the top of the track.
- `[[col:orange]]` resolves. CA's own loc uses `orange` 3 times and long keys such as
  `ui_font_green_light` too, so any `ui_colours` key works. `ui_font_inactive_grey_light` is
  never used by CA.
- The harness world shows raw keys (`cr_the_player`, `wh3_qol_r2`) and "No bounty on offer" on
  two cards. That is the demo world, not the panel.

## 6. Open

- **In game, unseen:**
  - the 18pt heading on every race's bar;
  - the padlock drawn inline at header_14;
  - the text field's rules under each culture skin;
  - CA's slider caps and arrows on the faction list, and whether it scrolls (the Exchange's
    copy was confirmed live);
  - the right inset on each race.
- **The Log still pages.** The Exchange's logs scroll now. The Guilds Log shares the Help tab's
  21 slots and paging works, so it was left as it is.
- **The Leaderboard's 32px band** under the header (y 138-170) is where the Guilds tab draws
  its reputation bar. It was left consistent across tabs.
- **The repo**: commit and push `repos/derpy-great-guilds` when the user says so.
- Still open from 09-30: the Cathay tab glyph against its octagon.
