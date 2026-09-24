# The Great Guilds - Dark Elves, High Elves, and only the included races

2026-09-24. Built and packed (`Modding Files/Modpacks/derpy_great_guilds.pack`, MD5
`efa60e7720e07d8f65103c7a5fca62fd`, 31,843,912 bytes, 138 files). **Deployed to `data/`
2026-09-24 13:29** (MD5 match; no Workshop copy exists).
- The previous build (`6e9bede8`, see `HANDOFF_20260924_GUILDS_BRT_CTH_KSL.md`) is backed
  up as `Modpacks/derpy_great_guilds.pack.bak_20260924_pre_elves_6e9bede8`.
- **The request:** "now add support for dark elves and elves, the button shouldnt appear
  to other factions except the included ones".
- **The user's answers:** the names and text as drafted, Swordmasters of Hoeth for the
  High Elves (option A), and no Wood Elves ("only high elves").

## 1. Only the included races

**This changes the mod's scope.** Until now, any culture a human played was in the race,
and a race with no flavour of its own read the generic one. Now only these eight are
covered: Chaos Dwarfs, Empire, Dwarfs, Bretonnia, Cathay, Kislev, Dark Elves and High
Elves. Every other race gets nothing, even when a human plays it.

- **`GG.covered`:** refuses any culture outside `GG.FLAVOURED`.
  - The refusal comes before the unreadable-player fallback. Standing an older build gave
    such a race cannot let it back in.
  - This one gate means:
    - no standing;
    - no rank-up, leadership or demand messages;
    - no AI purchases;
    - the till refuses on `scope`.
- **`GGUI.place_opener`:** creates no button when the local player's flavour is the
  generic one.
  - An unreadable player is retried. That is loading, not a verdict.
  - The button is the panel's only way in (`GGUI.open` has one caller, the click
    handler).
- **The generic flavour (`_gen`) stays.** The only thing that still reads it is a message
  to an unsupported human that another player's hostile service hits in multiplayer.
  - Its panel art (seven icons, six grounds) still ships but can no longer be seen.
    Removing it touches the icon, ground, UI and preview tools; not done.
- **Harness, rewritten first and watched failing:**
  - **Coverage block.** An Empire player covers Empire factions and drops the Chaos
    Dwarfs. A Lizardmen player, and a culture some mod invents, are refused even when
    played. An unsupported faction holding old standing stays out when the player is
    unreadable.
  - **Hire block.** An unmapped culture is now refused with `scope`. The `no_unit` branch
    is kept tested by removing the Empire's regiment for one call.
  - **New opener block.** No button for a Lizardmen player and no retry; a button for an
    Empire player; a retry for an unreadable one.

## 2. Dark Elves and High Elves

| Tag | Culture | Feed offset | Hire unit | Pictures | Ground painting |
|---|---|---|---|---|---|
| `_def` | `wh2_main_def_dark_elves` | 70 | `wh2_main_def_inf_black_guard_0` (tier 3, 1,300) | `def/` | `campaign_dark_elves1.png` |
| `_hef` | `wh2_main_hef_high_elves` | 80 | `wh2_main_hef_inf_swordmasters_of_hoeth_0` (tier 3, 1,250) | `hef/` | `campaign_high_elves1.png` |

- **Text:** the names, ranks, services, prose and bounties are the approved spec,
  `docs/superpowers/specs/2026-09-24-great-guilds-def-hef-design.md`. They were
  transcribed into the generator by script, not retyped.
- **No overrides needed:** both races have all four feed pictures and their own
  `generic` mission picture.
- **"Slave" stays refused** by `check_flavours`, so the Dark Elves say captives, thralls
  and Corsairs.
- **Black Guard** is now the most expensive hire in the mod, 100 gold over Hammerers.
- **Icons:** 14, each from its race's building line and each a flat silhouette.

  | Guild | Dark Elves | High Elves |
  |---|---|---|
  | brass | port (anchor) | foreign trade market (stall) |
  | immortals | barracks | barracks |
  | daemonsmiths | cold ones (a spired tower) | embassy (scroll and quill) |
  | khanate | hired killers | aesanar (hood and arrows) |
  | overseers | defence major | defence major |
  | slavers | slaves | stables (horse and lance) |
  | crest | worship (Khaine's shrine) | sea patrol outpost beasts (a phoenix) |

  The spec's High Elf picks for the Loremasters (`high_elves_mages`) and the crest (the
  Phoenix Crown chamber) passed the silhouette check. At 74px, though, one sits in a haze
  and the other in a filled square, and both read as boxes, so they were swapped after
  looking. `dark_elves_sorcery` would have suited the Convent, but it is textured (70%)
  and the tool refuses it.
- **Grounds:** six windows of each race's loading screen, chosen by content (see the
  comment in `make_guild_backgrounds.py`). The Dark Elf art is already dark, so its
  darkening factors run 0.38-0.67 against 0.32-0.34 for the High Elves. All twelve meet
  the p99 34 gate.

## 3. Files

- **Model Lua:**
  - the coverage gate in `GG.covered`;
  - two `GG.FLAVOURED` rows and two `GG.HIRE_UNIT_BY_CULTURE` rows;
  - the coverage and `GG.GENERIC` comments rewritten for the new scope.
- **UI Lua:** the gate in `place_opener`, and the regenerated `GGUI.MCT_NAMES`.
- **`gen_great_guilds.py`:** the two `FLAVOURS` entries, the selftest's flavour list, and
  the `_gen` comment.
- **`make_guild_icons.py`:**
  - 14 `ICONS` rows;
  - the selftest's tag loop;
  - `ui_icon_sizes.json`, 14 entries at 74.
- **`make_guild_backgrounds.py`:** two `CA_ART` rows and 12 `CA_BACKGROUNDS` rows.
- **`_guilds_harness.lua`:**
  - the coverage, hire and opener blocks (section 1);
  - two cases in the per-culture flavour block, watched failing on `_gen` before the Lua
    rows went in.

## 4. Verification

- **Green:**
  - the harness
  - `gen_great_guilds --check/--selftest`
  - `gen_guilds_ui --check/--selftest`
  - `check_guilds_ui` and its selftest
  - `check_guilds_anchor`
  - `preview_guilds_panel --check/--selftest`
  - `make_guild_icons` and `make_guild_backgrounds` `--check/--selftest`
  - `import_great_guilds --check`, and its post-save verify (379 bundles, 407 junctions,
    3,746 loc)
  - `luac` on all four scripts
  - `check_lua_api`
  - `check_lua_literal_left`: 0 sites
- **`check_lua_undeclared`:** reports only the Exchange's `EX.BUTTON*`, as before.
- **Dry run before approval:** the draft went through the shape, word, title and
  Help-fit checks.
  - The Help-fit check was proved to see the new flavours by breaking one on purpose.
  - Guild descriptions are not on the Help pages, so a long one does not trip it.
- **Pack contents:** the four packed scripts are byte-identical to staging, and all 26
  elf art files are present.
- **Previews:** `--flavour def|hef`, with and without a guild, draw each race's names,
  ranks, crest and ground.

## 5. In-game checks owed

1. **A Lizardmen or Greenskin campaign:**
   - no Guilds button;
   - no guild messages;
   - no "ResearchStarted reached AI faction" line for that race's AI.
2. **A Dark Elf and a High Elf campaign:**
   - the button appears;
   - the panel shows the race's names, crest and grounds;
   - a rank-up message draws `def/` or `hef/` art, not a black rectangle;
   - the Soldiers' hire adds Black Guard of Naggarond or Swordmasters of Hoeth;
   - the MCT page opened in campaign names the race's guilds.
3. **A save from an unsupported race:** its old standing is frozen, and nothing is sold
   against it.
