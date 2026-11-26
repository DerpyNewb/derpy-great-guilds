# Great Guilds: Norsca as the warrior cults of the North (2026-11-26)

Eleventh race of `derpy_great_guilds.pack`. Spec:
`docs/superpowers/specs/2026-11-26-great-guilds-norsca-design.md`. The author signed off §15 as
written, item 9 included, and asked for Norsca and the Tomb Kings to be built in parallel.

**Not built, not deployed.** All the work is in an isolated copy of the workspace,
`<scratchpad>/gg_nor` (the coordinator holds the full path). The pack was not built, and RPFM
was not used. The game was not launched. The coordinator merges this copy and the Tomb Kings'
copy into the workspace, then builds once. Every number below was measured in that copy,
which has no Tomb Kings rows.

## The race

Tag `_nor`, culture `wh_dlc08_nor_norsca`, feed 120 (the Tomb Kings have 110). There is no
word pass: the panel says "The Great Guilds", Reputation and Favour. Ranks are Bondsman,
Marauder, Huskarl, Chieftain and Champion. The race uses the global rival pairs and has no
`RIVALS_RACE` entry.

| Slot | Guild | Pays for | Rival | Hall trains |
|---|---|---|---|---|
| brass | The Monster Hunters | income; Spoils from the Monstrous Arcanum hunts, 1 per 25 | Skin Wolves | Marauder Hunters (`_hunters_1`) |
| immortals | The Berserkers | battles won, doubled when outnumbered | Shaman-Sorcerers | Berserkers |
| daemonsmiths | The Shaman-Sorcerers | technologies | Berserkers | nothing; Shaman-Sorcerer cap +1/2/3 |
| khanate | The Skin Wolves | hero actions, Shaman-Sorcerers' included | Monster Hunters | Skin Wolves |
| overseers | The Thralls | growth, unclaimed buildings | Reavers | nothing |
| slavers | The Reavers | sacking; razing pays more | Thralls | Chaos Marauders |
| temple | The Four | altars, wins over the Empire, Kislev, Bretonnia and Cathay, Kihar's and Killgore's actions | none | nothing; Chaos corruption +2/4/6 |

**New rules in the model** (`zzz_derpy_guilds.lua`):
- **The altars route.** `TEMPLE_ROUTES[...].altars = true`, and `GG.temple_altars(f)` reads each
  region's primary building chain. It counts the altars of the most-favoured god (the largest
  of the four counts) plus every Undivided altar. `temple_counts` returns it as a fourth value,
  and both `GG.temple_turn` and the preview `GG.turn_start_pay` pay it at `rate_temple_altar`.
- **`rate_temple_altar`:** a new MCT key, default 2 (easy 3, hard 1, ultra 1), appended to
  `TUNE_ORDER` and `PRESET_OWNED`. An old settings string reads the default.
- **Spoils.** `POOL_ROUTES.wh3_dlc27_nor_spoils = "spoils"`, `EARN_ROUTES.spoils` pays the brass
  guild per 25, and `pool_route_counts` accepts only the factor
  `wh3_dlc27_nor_spoils_monstrous_arcanum`. Pillage, events, buildings and the Tithe of Spoils
  pay nothing through it.
- **Boasts** (the twist): a failed bounty costs twice the usual Reputation, and a paid demand
  pays half again as much (`rate_bounty_fail` 200, `demand_reward` 150).
- **Recruiting**, first fit wins: the altars' god-marked `wh3_dlc27_{chs,kho,nur,sla,tze}_`
  units pay the Four. Chariots, horsemen and Marauders pay the Reavers (the chariot rule comes
  before the wolves). Berserkers, Champions, Bearmen, Spearmen and Flayerkin pay the Berserkers.
  Wolves and hounds pay the Skin Wolves, the monsters of the hunt pay the Monster Hunters,
  trolls pay the Thralls and mammoths pay the Shaman-Sorcerers. A captured port's foreign units
  pay nobody.
- **Building words** (`BUILDING_THEME_RACE._nor`): the smithy and the slaves chain go to the
  Thralls, the beasts chain to the Skin Wolves, and the creatures and offerings chains to the
  Monster Hunters. The port, loot, stables and raiding altars go to the Reavers.
- **Three race services**, rows 99-101 in this copy (102-104 after the merge):

  | Service | Guild, rank | Effect |
  |---|---|---|
  | Tithe of Spoils | Reavers, 2 | +200 Spoils (factor `events`) |
  | The Wolf-Kin | Skin Wolves, 3 | a unit of Skin Wolves and one of Ice Wolves join the selected army, if there is room |
  | The Hunters' Charge | Monster Hunters, 4, leader only | +15% charge bonus in all armies, 10 turns |

- **Hire unit:** Marauder Champions (Great Weapons), `wh_dlc08_nor_inf_marauder_champions_1`.

**The Four by their own lore:**
- Rank and lead bonus: leadership +2/4/6/8, and 5 for the leader.
- Hall: Chaos corruption +2/4/6. Seat: Chaos corruption events +2.
- Temple Bribes: +5 Chaos corruption.
- Purge and Consecration give public order only.
- Eyes of the Four: +10% ward save for one army.
- War on the South: +4 melee attack and +6 leadership in all armies.

**Halls:**
- Lodge / Longhouse / Great Hall, and Totem / Altar / Monolith of the Four for the temple.
- Cloned from `wh_main_NORSCA_creatures`, which the donor rule finds on its own.
- Only the Norscan core settlement type (`wh3_dlc27_norsca_core_settlement`) takes a hall. The
  Help says "An altar to the gods is too small to hold one." The outposts are untyped chains.
- Sayl's and Throgg's availability sets offer the halls too.

**Panel frame:** the Norscan legacy leather is dimmed to `#A0A0A0` and sliced at 4px, with its
centre tiled. The heat glow and rim are CA's frost blue (`ui_font_blue_light`). The holder is
the allegiance panel's god button. The cost plate and tabs use the troll expansion's banner,
with the tutorial glow on the open tab. The rank strip and button bar are the Norscan HUD bars,
the bar at 90%. The track is the Souls bar.

**Art:**
- Cards: CA's `nor_*` building icons (`nor_loot_plunder` for the Reavers). Crest:
  `nor_settlement`. Tab: `nor_cat_recruitment`.
- Grounds: seven windows of `campaign_norsca1`, CA's only Norsca loading screen.
- Bundle icons: the seven new ones from `make_guild_bundle_icons.py`. The other 78 came out
  byte-identical to the live copies.

## Deviations from the spec, and why

1. **Marauders pay the Reavers**, not the Berserkers. The Reavers' hall trains them, and every
   race's hall unit pays its hall's guild.
2. **Temple Bribes has a `_nor` override** of +5 Chaos corruption. The shared service lowers
   corruption, which §6 turns away from this race.
3. **Service rows 99-101 in this copy.** The Tomb Kings' rows were not there to build after.
4. **The Warriors of Chaos harness pin is positional** (rows 96-98, Skaven 95). It used to say
   "the last three rows", which Norsca broke.
5. **The Great Hunt became "The Hunters' Charge", key `monster_hunt`, +15% charge bonus.**
   `great_hunt` is already a shared pool service named "The Great Hunt" in three flavours, and
   plan-time check 6 failed: `wh2_dlc09_effect_force_stat_melee_attack_monsters` does not reach
   Norsca's monsters. The charge bonus is the spec's own fallback.
6. **The shared `great_hunt` pool service reads "The Long Raid"** for Norsca, so the two names
   do not collide.
7. **No `hellcannon` recruit token.** It matched no unit in Norsca's roster; the only Hellcannon
   is a Regiment of Renown. The recruit sentence no longer mentions it.
8. **Hall settlement type is the core settlement only**, with `_stype_problems` extended to
   count the chains a type offers. The count stays confined; every other race's result is
   unchanged.
9. **`HELP_BUILDINGS`** (new, confined): Help page 2's example now reads "a forge the Thralls, a
   dock the Reavers, a barracks the Berserkers" for Norsca. The shared example named the wrong
   guilds for this race.
10. **The Reavers' card is `nor_loot_plunder`.**
11. **Frame donors.** The Monstrous Arcanum's cloth and tab art is light parchment, and cream
    text cannot sit on it. The holder, cost plate and tabs therefore come from the allegiance
    button and the troll banner.
12. **`Modding Files/source/guild_icons` is a local partial copy.** It was a junction, and
    `make_guild_icons.py` writes its `fetch()` output there, which would have written into the
    live workspace.
13. **`RANK_STATS_PAD._nor` is 76, and `GGUI.HEADER_INSET._nor` is 146.** At the spec's 66, the
    Small panel's "Halls 6" ran 3px into the Norscan bar's spikes.

## Verified offline, in the copy

- **Generator:** `--selftest` printed 7 guilds, 101 services, 90 bundles and 946 loc. `--write`
  and `--check` both exit 0. New selftest pins cover the Norsca hall units, the wizard cap, the
  settlement type, the temple lore, the services and Help page 2.
- **Other races:** compared with the live TSVs, no non-Norsca row changed. Two rows were removed
  by the generator's existing rule (`covered_chains` leaves a building-card line off a chain
  that two covered races can build):
  - the Ziggurat of Dawn beacon's `_chs` variant, which Norsca can now also build;
  - `wh3_dlc27_nor_special_shrine_of_asavar_kul`, which Norsca can now also build.
  Both still pay; they lose only the card's line. The 33 non-Norsca loc additions are the three
  new ledger and log keys under all 11 flavours, as the Warriors of Chaos added theirs.
- **UI:** `gen_guilds_ui.py` `--check` 0 and `--selftest` (76 files, 12,194 GUIDs);
  `check_guilds_ui` 0 problems; `preview_guilds_panel.py --check` 0.
- **Previews:** `--flavour nor` at Small, Medium and Large exit 0 with no TOO WIDE and no LOW
  CONTRAST. The Guilds tab (guilds 1, 3 and 7), Leaderboard, Bounties, Court, Log, the pick card
  and Help pages 1-7 were read. Two faults were fixed: an 8px seam every 256px across each
  card, and "Halls 6" touching the spikes at Small.
- **Harnesses:** both green.
- **Mutation:** 307 of 307 caught, with no stale anchor and no survivor. That includes 23 new
  Norsca mutants: the max over the four gods, the Undivided addition, both altar guards, the
  preview term, the `r.altars` gate, Killgore, Cathay, the Spoils factor test and pool, the
  Tithe's factor, Boasts, five recruit and building words, the Wolf-Kin's fire, the hire unit,
  the feed, the easy preset and the ledger. The Skaven's "hold blind to taint" anchor moved
  because the altars term now follows it. The generator and UI were regenerated after the
  run, and both harnesses are green again.
- **Lua:** luac on all five files 0; `check_lua_api` 0; `check_lua_literal_left` 0;
  `check_lua_undeclared` reports BUTTON, BUTTON_GAP, BUTTON_SIZE and DERPY_HUB, the same four the
  live files report (cross-mod names).
- **Effects:** both checks need a built pack through RPFM, so their own functions were run on the
  generated TSVs. Bundle loc: 1,154 bundles (97 Norsca), 0 findings. Signs: 152 Norsca rows, 7
  penalties, the same 7 the Warriors of Chaos carry (the enemy-targeted services and the loan).
- **Importer:** `import_great_guilds.py --check` printed "verify ok - 1154 bundles, 1272
  junctions, 11185 loc, 4 script(s), 76 ui file(s)". It refused until the bundle icons were
  made.
- **Plan-time check 2:** nothing infers a flavour from a vanilla key's `_nor` suffix. The Lua's
  only hall-key parse is anchored at `^derpy_gg_hall_`, and every `hall_tag_of` caller passes
  the mod's own hall rows.

## Merge notes

- **Race lists** have `_nor` after `_chs` and before `_gen`. The importer's tuple is alphabetical
  (`"ksl", "nor", "skv"`), so `"tmb"` goes after `"skv"`.
- **Count pins to re-count with the Tomb Kings:**
  - generator race services, 38 here (41 with the Tomb Kings);
  - hall sets, 11 here (12);
  - `make_guild_icons` `HALL_ICONS`, 77 here;
  - harness `#GG.SERVICES`, 101 here (104).
  The harness's Norsca block checks the last three rows. That holds if Norsca's rows come after
  the Tomb Kings'; a Tomb Kings "rows are last" pin would have to become positional.
- **Files to copy that are not code** (36 new under `pack/ui`, none changed):
  - `Modding Files/source/guild_icons/`: eight `nor_*.png` and `cat/nor_cat_recruitment.png`.
    Copy those nine files only. The copy's folder is partial (142 of the live 831 files), so
    never copy the folder itself over the live one;
  - `ui/buildings/icons/`: seven `derpy_gg_hall_*_nor.png` and `derpy_gg_tab_halls_nor.png`;
  - `ui/campaign ui/derpy_gg_bg/` and `derpy_gg_icons/`: seven grounds, seven cards and
    `crest_nor.png`;
  - `ui/campaign ui/effect_bundles/`: seven `derpy_gg_*_nor.png`;
  - `ui/campaign ui/`: `derpy_gg_card_nor*` and `derpy_gg_panel_nor*` at the three sizes.
- **Do not copy** `tools/gen_engine_reverse_anims.py` or `tools/gen_tank_controls.py` from
  the copy. They changed in the live workspace after the copy was made.
- **The mutation run** restores its source; regenerate after it as usual.

## In game, open

1. **Pillage and `CharacterRazedSettlement`.** Find out whether Pillage fires the raze event.
   If it does not, Pillage pays nobody, and the spec's `GG.FACTOR_GUILD` branch (Pillage Spoils
   to the Reavers) is needed. Run this first.
2. `PooledResourceChanged` fires for Spoils with the `monstrous_arcanum` factor when a hunt stage
   pays, for a human Norsca faction.
3. A Norsca panel opens with its frame, and Sayl's and Throgg's read right.
4. An altar raised to a god shows on the earnings sheet under "altars to the gods" the next turn,
   and the count follows the most-favoured god.
5. A hall builds in a core settlement, including a unitless one. Check whether an outpost
   (untyped) offers one too.
6. Each rival pair takes from the right guild.
7. A save from before the update loads.
8. The leather card, the banner tabs and the frost-blue rim look right at the author's UI scale.
