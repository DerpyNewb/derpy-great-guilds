# The Great Guilds - Bretonnia, Cathay and Kislev

2026-09-24. Built and packed (`Modding Files/Modpacks/derpy_great_guilds.pack`, MD5
`6e9bede837f0e240ec5ab9dbb73584a6`, 24,327,043 bytes, 112 files). **Deployed to `data/`
2026-09-24 11:43** (MD5 match; no Workshop copy exists).
- The previous build (`fc95d1d1`, see `HANDOFF_20260924_GUILDS_GENERIC_AI_MP.md`) is backed
  up as `Modpacks/derpy_great_guilds.pack.bak_20260924_pre_brt_cth_ksl_fc95d1d1`.
- **The names, prose and bounties** are the approved spec,
  `docs/superpowers/specs/2026-09-24-great-guilds-brt-cth-ksl-design.md`, transcribed into
  the generator by script rather than retyped.
- **Bretonnia's hire unit:** the user chose Knights of the Realm (option A).

## 1. What was added

| Tag | Culture | Feed offset | Hire unit | Pictures | Background painting |
|---|---|---|---|---|---|
| `_brt` | `wh_main_brt_bretonnia` | 40 | `wh_main_brt_cav_knights_of_the_realm` | `brt/` | `campaign_bretonnia1.png` |
| `_cth` | `wh3_main_cth_cathay` | 50 | `wh3_main_cth_inf_dragon_guard_0` | `cth/` | `campaign_cathay1.png` |
| `_ksl` | `wh3_main_ksl_kislev` | 60 | `wh3_main_ksl_inf_tzar_guard_1` | `ksl/`, bounties `emp/generic` | `campaign_kislev1.png` |

- **Kislev's bounty picture:** Kislev has no mission picture anywhere in vanilla. CA's own
  Kislev missions use `emp/generic` (97 rows), so its bounties do too, through the
  `mission_pic` override.
- **Bretonnia's hire unit is cavalry:** it is the one hire in the mod that is not an
  infantry regiment. It is tier 2 at 950 gold, the Greatswords' price. Bretonnia's best
  infantry is tier 2 at 750.
- **Icons** are seven per race from each race's own building line, all flat silhouettes
  (97-100% one colour). Each was chosen from a rendered sheet of every candidate.

  | Guild | Bretonnia | Cathay | Kislev |
  |---|---|---|---|
  | Brass | wine market | merchant stall (`gold_yin`) | Erengrad trading port |
  | Immortals | tournament grounds | celestial barracks | royal guards |
  | Daemonsmiths | Tower of the Enchantress | scrolls (`growth_yin`) | Frosthome |
  | Khanate | tavern | House of Secrets | trade-order barrels |
  | Overseers | carpenter | walls (`yang`) | timber |
  | Slavers | barracks | jade barracks | Ungol quarters |
  | Crest | the Grail (`worship`) | the Celestial Palace | the bears |

- **Backgrounds** are six windows of each race's loading screen, at darkening factors
  0.30-0.41: the same band as the Empire's and the Dwarfs'. Windows went by content: the
  castle to the builders, the riders to the raiders, the lead knight or guard to the
  soldiers.
- **MCT page:** `GGUI.MCT_NAMES` was regenerated, so it names each race's guilds in
  campaign.

## 2. Files

- **Model Lua (`zzz_derpy_guilds.lua`):** three `GG.FLAVOURED` rows and three
  `GG.HIRE_UNIT_BY_CULTURE` rows. The table's header comment now says Bretonnia's is tier
  2 knights.
- **UI Lua:** only the regenerated names table changed.
- **`gen_great_guilds.py`:** the three `FLAVOURS` entries, and the selftest's flavour
  list.
- **`make_guild_icons.py`:** 21 `ICONS` rows, and the selftest's tag loop.
  `tools/ui_icon_sizes.json` gained 21 entries at 74.
- **`make_guild_backgrounds.py`:** three `CA_ART` rows and 18 `CA_BACKGROUNDS` rows.
- **`_guilds_harness.lua`:** a block asserting each culture's tag, feed offset, lead bundle
  key and hire unit. It was watched failing (Bretonnia read `_gen`) before the Lua rows
  went in.

## 3. Verification

- **Dry run:** before approval, the draft spec went through `check_flavour_shape`,
  `check_flavours` (lengths and the refused words), `check_titles` and `check_help_fits`
  (every Help page within 21 lines) in memory, all clean.
- **After the build, green:**
  - the harness
  - `gen_great_guilds --check/--selftest`
  - `gen_guilds_ui --check/--selftest`
  - `check_guilds_ui` and its selftest
  - `check_guilds_anchor`
  - `preview_guilds_panel --check/--selftest`
  - `import_great_guilds --check`, and its post-save verify
  - `make_guild_icons` and `make_guild_backgrounds` `--check/--selftest`
  - `luac`
  - `check_lua_api`
- **Pack contents:** the four packed scripts are byte-identical to staging.
- **Previews** (`--flavour brt|cth|ksl`, with and without a guild) draw each race's names,
  ranks, crest and background.

## 4. In-game checks owed, per race

1. Start a Bretonnia, a Cathay and a Kislev campaign. The panel should show that race's six
   guild names, its crest, and its backgrounds as you page through the guilds.
2. A rank-up or leadership message draws that race's picture, not a black rectangle.
3. The Soldiers guild's hire adds Knights of the Realm, Celestial Dragon Guard or Tzar
   Guard (Great Weapons) to the selected army.
4. A Kislev bounty shows the Empire's generic mission picture.
5. The MCT page opened in campaign names the race's guilds.
