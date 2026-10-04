# Great Guilds: CA's glow_pulse_t0 on the running card and the selected guild

2026-10-04. Build `BB2043255DC561FD6D82E247DCA04CCA`, deployed to data/. The previous live
`7A568114` is in `Modding Files/Backup/guilds_pre_glow_pulse_20261004/`. Repo synced, not pushed.
**Not yet seen in game.**

## What changed

Only `tools/gen_guilds_ui.py`. No Lua edits. Exactly 16 pack files differ from the last build:
the 8 card layouts and the 8 panel layouts.

- **A running service's card breathes.** `CARD_LAYERS[1]` (heat) and `[2]` (rim) carry
  `shader_name="glow_pulse_t0"` on the `<image>`. The shader belongs to the image slot, so it
  stays on when `GGUI.light_card` swaps the art in by `SetImagePath`. While the slot holds
  CLEAR it pulses nothing, so unlit cards, the pick card and bounties do not change.
  - The heat uses `0.80,1.00,0.50`, the Tower of Zharr torches' values. It never gets brighter
    than the shipped look, so the name drawn over it keeps its measured contrast.
  - The rim uses `1.00,1.20,1.00`, the Tower furnace `glow_02`'s values.
- **The selected-guild marker `gg_gsel` pulses** at `0.80,1.50,0.80`. Those are the Hell-Forge
  category block's values for its **`active`** and `cooldown` states, not its selected state.
  This was first written as "selected" and corrected the same day by re-reading `ui3.pack`.
- **Every value is CA's, copied.** See `CA_CHD_UI_FX_20260928.md` §2b.
- **New `check_pulses()` in `check()`.** It reads the emitted XML and requires exactly 2 pulsed
  images per card, both resolving through `component_image` to CLEAR, and a pulse in every panel.
  It was watched catching three faults: the rim shader dropped, a pulse put on the bronze, and
  the marker shader dropped.

## Verified

- `gen_guilds_ui.py --check` and `--selftest` pass (2494 guids).
- `check_guilds_ui.py` reports 0 problems.
- `preview_guilds_panel.py --check` passes.
- `import_great_guilds.py` saved the pack and its verify passed.
- A per-file diff against the old data/ copy shows only the 16 files.
- The deployed copy's md5 matches the build.

## Open

- **In game:**
  - Does the pulse survive `SetImagePath`? Not seen on the Guilds yet, but the same mechanism
    was seen in game on 2026-09-28. That was the Iron Court seat rim: a transparent slot,
    swapped in by index, with `glow_pulse_t0` on the layer (`CUSTOM_UI.md` "Effects on a runtime
    panel").
  - Is the heat's 0.5s torch interval too flickery behind text? If so, use the furnace's
    `1.00,1.30,0.80`.
  - Is the gold marker's pulse visible at 4px tall?
- **The preview cannot draw shaders**, so the pictures are unchanged.
- **Not done:** a one-shot burst at the moment of buying. That would be CA's Tower of Zharr
  claim starburst, a SpriteAnimation on a hidden child (§2c of the FX doc). It needs a new
  component and a callback the emitter does not write yet, and whether showing the child again
  replays the burst is unknown.
