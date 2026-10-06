# The Great Guilds: the seventh guild (faith and magic) - design

2026-10-04. Status: **design, awaiting the author's review. Nothing is built.** Brainstormed in
the session recorded in `docs/sessions/HANDOFF_20261004_GUILDS_HALLS_STAGE2.md`. Unit keys and
names in §5 were read from CA's `text/db/land_units.loc` with `tools/read_vanilla_loc.py`, and
building names and descriptions in §3.3 from `building_culture_variants` and
`building_short_description_texts`, on 2026-10-04. Everything this document has NOT read yet is
listed in §10 and is checked before any row is written.

## 1. What and why

Every supported race has six guilds, keyed after the Chaos Dwarf guilds: `brass` (merchants),
`immortals` (soldiers), `daemonsmiths` (learning), `khanate` (spies), `overseers` (builders),
`slavers` (raiders). None is a church or a magic order, so temples, shrines and wizard towers pay
the builders or the engineers, and a race's faith has no voice in the mod.

This adds a **seventh guild, key `temple`**, a full peer of the other six: reputation and favour,
five ranks, rank bonuses, earn routes, nine services, a bounty, a demand, a guild hall, a panel
page, a crest, a background and its own text, for each of the eight supported races.

Decisions taken by the author during the brainstorm:

| Question | Decision |
|---|---|
| Scope | Full peer of the other six |
| Identity | The most iconic faith or magic body per race (table in §2); where a race's learning guild is already its magic order, the seventh is its faith |
| Empire | **The Colleges of Magic**; the Engineers' School stays; no Cult of Sigmar |
| Earning | All four routes (§3.2), each race taking the ones its lore supports, plus temple buildings |
| Rival | None. The three existing rival pairs are unchanged |
| Backgrounds | Cropped from CA loading-screen paintings, every race including the Chaos Dwarfs |
| Delivery | **One build** (approach B): one spec, one plan, one build, one in-game check |
| Races | Only the eight supported races. No generic panel. Skaven later, as its own project |

**Not in scope:** Skaven or any ninth race; race-only services for the new guild (the other
guilds' race services were added later, separately); two-machine multiplayer verification; a
Workshop upload; syncing the public GitHub repo (only when asked).

## 2. Identity

| Flavour | Name | What it is |
|---|---|---|
| Chaos Dwarfs (`""`) | The Temple of Hashut | Priests, sacrifice, the ziggurat rites. The Daemonsmiths stay the sorcerer-smiths |
| Empire (`_emp`) | The Colleges of Magic | The eight Colleges and their Battle Wizards |
| Dwarfs (`_dwf`) | The Ancestor Temples | Grungni, Valaya, Grimnir - and the Slayers |
| Bretonnia (`_brt`) | The Grail Pilgrims | Battle pilgrims and the grail shrines. The Grail Damsels stay the Lady's lore-keepers |
| Cathay (`_cth`) | The Celestial Temples | Dragon and ancestor worship, temple guardians |
| Kislev (`_ksl`) | The Great Orthodoxy | Ursun's priests, the Patriarch, shrines and oubliettes |
| Dark Elves (`_def`) | The Brides of Khaine | Witch elves, sisters of slaughter, hag queens. The Khainite Assassins stay the killers for hire |
| High Elves (`_hef`) | The Cult of Asuryan | The Phoenix Guard and the sacred flame |

Each gets a one-sentence description in the voice of its siblings (`FLAVOURS[tag]["desc"]`), and
uses the race's existing rank words. The generic flavour `_gen` has no panel and no gameplay
(`GG.covered` is false for every unsupported race since 2026-09-24); it gets only the name string
the flavour-shape check requires, which reaches a player only in the multiplayer message a hostile
service sends to an unsupported human.

## 3. Earning

### 3.1 Buildings

Completing a building pays its guild `built_rep(level)` = 10 x level, clamped to 1..10, as every
building does today, and the card line prints that number.

- **Shared words stay as they are** (amended 2026-10-04, plan-time reading): bare `temple`
  catches the Chaos Dwarf Fane Guard chain (`chd_tower_temple_guardhouse`) and bare `shrine` the
  foreign shrines a Dwarf faction can occupy (`shrine_of_asuryan_other`, ...). Every move is
  therefore an explicit race-only token, and the Empire needs no override.
- **Race-only word lists (new).** `GG.BUILDING_THEME_RACE[tag]`, checked BEFORE the shared list,
  so a word can mean different guilds in different races. `GG.guild_of_chain(chain, tag)` takes
  the tag; `GG.on_building` passes the owner's; the generator's mirror and `check_built_effects`
  take it too. Every race-only token must match a chain that race can build
  (`check_building_theme`'s existing rule, per race).
- **The Empire's temples stay with the Masons**, untouched, since nothing moves them.

### 3.2 The four routes

| Race | Devout provinces | Holding back Chaos | Holy war against | Priests and wizards |
|---|---|---|---|---|
| Chaos Dwarfs | yes | - | Dwarfs | - |
| Empire (Colleges) | - | yes | - | wizard heroes |
| Dwarfs | yes | - | Greenskins, Skaven | - |
| Bretonnia | yes | yes | Chaos, Vampire Counts | - |
| Cathay | yes | yes | - | - |
| Kislev | yes | yes | Chaos, Norsca | - |
| Dark Elves | - | - | High Elves | Death Hags |
| High Elves | yes | yes | Dark Elves | - |

- **Devout provinces** - at the faction's turn start, `rate_temple_devout` (default 1) for every
  settlement it holds with positive public order.
- **Holding back Chaos** - at turn start, `rate_temple_chaos` (default 2) per province with no
  Chaos corruption; for Bretonnia and Kislev, no Vampiric corruption either.
- **Holy war** - `rate_temple_holy` (default 10) per battle won against a faction of a listed
  culture, on top of the soldiers' battle reputation.
- **Priests and wizards** - a successful action by a listed hero subtype pays the temple
  `rate_khanate` instead of paying the spies. Heroes already tied to a learning guild (Damsels,
  Mages, Astromancers, Ice Witches) are not used.

All four go through `GG.capped_grant`, so `cap_temple` (default 40 per turn, half again with the
Seat) bounds them with the guild's other passive income. Each writes a ledger source
(`devout`, `chaos`, `holywar`, `priests`) so the earnings sheet names it. The routes are a
per-race table in the Lua, `GG.TEMPLE_ROUTES[tag]`, mirrored in the generator, so a race without
a route earns nothing from it and a test proves so.

### 3.3 The race word lists

The full mapping, read from CA's display names and descriptions (§10 item 7 verifies each
token against the chains before it is written). Only moves are listed.

- **Chaos Dwarfs:** the Temple of Hashut, the Great Temple of Hashut and the Defaced Shrine to
  the Temple (race tokens `temple_of_hashut`, `shrine`; the set has no altars).
- **Empire:**
  - Colleges: the Wizard's Conclave, the Altdorf Conclave of Battle Wizards, the Amethyst
    College, Elspeth's Black Tower, the Temple of Elemental Winds, the Tower of Prophecy, the
    Library of Hoeth.
  - Engineers' School: the Nuln Cannon Foundry.
  - Thieves' Guild: the Tap Room, the Red Moon Inn.
  - Free Companies: the Shooting Range, the Militia of Morr, the Empire Outpost.
  - Greatswords: the knightly chapterhouses (Reiksguard, Black Rose, Blazing Sun, Panther,
    White Wolf), the Stables, the Small Fort.
  - Masons' Guild: keeps the Shrines of Sigmar, Taal, Myrmidia and Ulric, the Temple of Morr and
    the great temples.
- **Dwarfs:**
  - Ancestor Temples: the Ancestors' Hall, the Slayer shrines and the Great Slayer Shrine (moved
    from the Grudge-Settlers).
  - Grudge-Settlers: keep grudges and oaths.
- **Bretonnia:**
  - Grail Pilgrims: the Grail Shrine, the Holy Monastery, the Abbey of the Grail Companions.
  - Grail Damsels: the Tower of the Enchantress.
  - Forest Outlaws: the Tap Room.
  - Knights Errant: the Stables, the Peaks of Parravon.
  - Crusaders: the Bretonnian Outpost, Copher Harbour.
  - Wine Merchants: the Cellar.
  - Castle-Wrights: the Smithy (off the Damsels).
- **Cathay:**
  - Celestial Temples: the Li Temple, the Phoenix Temple, the Temple of the Two Moons.
  - Imperial Academy: the Temple of the Jade-Blood Sorcerers (sorcery, not worship), the Nan-Gau
    Forge, the Powderhouse, the Alchemist Tower.
  - Crow Society: the Cathayan Outpost, the House of Secrets, the Sky Lantern Lookouts.
  - Punitive Host: the Conscription Office and Field, the Peasant Huts, the Bastion Gaol.
  - Dragon Guard: the Celestial Barracks, the Jade Muster, the Tiger Warrior Den.
  - Caravan Masters: the Wares and Spice Markets, the Great Embassy.
- **Kislev:**
  - Great Orthodoxy: the Orthodoxy Shrine (off the Merchants), the Orthodoxy Oubliette, the
    Ursunite Groves, the Hallowed Wood.
  - Ice Court: the Convent of Ice, the Eerie Woods, the Cavern of Silk, Ostankya's Hut, the
    Spire of Ice.
  - Ungol Raiders: the Oblast Hollow (off the Tzar Guard), the Tribal Encampment.
  - Tzar Guard: the Royal Barracks.
  - Oblast Smugglers: the Roadhouse.
- **Dark Elves:**
  - Brides of Khaine: the Altars of Khaine, the Sacrificial Pit of Khaine, the Fiery Pits of
    Sacrifice, the Shrine of Widowmaker, Hellebron's Palace.
  - Khainite Assassins: the House of Assassins.
  - Convent of Ghrond: the Sorceress' Abode and Cabin, the Tower of Prophecy, the Brazen
    Cauldron, the Soul Brazier, the Cultist Gathering.
  - Black Ark Corsairs: the Dark Elf Landing (off the Traders), the Corsair Cabins, the Den of
    Outlaws, Dawn's Harbour, the Talon of Agony, the Underworld Sea gate.
  - Black Guard: the Towers of the Black Guard, the Dread Manse.
- **High Elves:**
  - Cult of Asuryan: the Shrine and the Sacred Flame of Asuryan.
  - Loremasters: the Archive, the Library of Hoeth, the Tower of Prophecy, the Loremaster's
    Watch, the Warden's Tower.
  - Shadow Warriors: the Aesanar Camp, the Mistwalkers' Sanctum.
  - Ellyrian Reavers: the Grazing Meadows, the Royal Ellyrian Stables, the Ellyrian Steading,
    the Hall of Charioteers.
  - Lothern Merchants: the Diplomat's Sanctum (off the Shadow Warriors), the Maritime Trade
    Hall, the Silversmith's Hall.
  - Ulthuan Masons: the Elven Workshop (off the Loremasters).

After the change the share table (`scratchpad/shares.py`, promoted into the generator as a
report) is re-run for every race and every chain that changed guild is listed for the author.

## 4. Ranks, services, bounty, demand

**Rank bonus:** public order in the faction's provinces, its own ladder +1/+2/+3/+4 for ranks
2-5 (`RANK_EFFECTS_EXTRA`'s pattern: the shared 3/6/10/15 is for percentages). The leading
guild's bundle as for the other six. Effect key and scope per §10 item 1.

**Services** - nine, three at each of ranks 2/3/4 costing 50/150/400 favour, every one an
existing payload kind. Chaos Dwarf names shown; every flavour gets its own names and blurbs.

| Rank | Key | Name (CHD) | Kind | Effect |
|---|---|---|---|---|
| 2 | `hashut_blessing` | Blessing of Hashut | army | +leadership, one army, 5 turns |
| 2 | `forge_sermons` | Sermons in the Forge | settlement | +public order, one settlement, 8 turns |
| 2 | `temple_tithe` | The Tithe | gold | +2,000 gold |
| 3 | `zeal` | Zeal | army | +melee attack and charge, one army, 5 turns |
| 3 | `purge_unclean` | Purge the Unclean | settlement | -corruption, one settlement, 8 turns |
| 3 | `anathema` | Anathema | enemy_settlement | -public order in an enemy settlement, 5 turns |
| 4 | `holy_war` | The Holy War | bundle, lead | +leadership and replenishment, all armies, 10 turns |
| 4 | `miracle` | Miracle | army, heal | heals one army, 2 turns |
| 4 | `consecration` | Consecration | bundle, lead | +public order everywhere, 12 turns |

The nine rows are appended after all 83 existing `GG.SERVICES` rows, in the order above.
`POOL_KEYS = SERVICES[18:]` becomes an explicit `pool` marker on each row, because the temple's
rows sit after the pools.

**Bounty:** the existing defeat-an-army kind, aimed at a faction of the race's holy-war cultures
(§3.2); a race with none aims it at any faction at war with the player. **Demand:** complete a
temple or shrine within the demand's turn limit, reusing the builders' building demand with the
temple's word lists.

## 5. The hall

A seventh chain per race, in the race's Guild Halls tab and the shared one-hall-per-settlement
instance (`derpy_gg_hall`). Levels II/III/IV unlock at rank 2, rank 4, and rank 5 while leading;
it pays 4/8/15 a turn (`HALL_REP`), discounts the guild's services, and on the Chaos Dwarfs
carries the factory, outpost and tower settlement-type rows that `_stype_problems` demands.
**Local bonus:** +public order in the province, 2/4/6 by level; the Seat spreads it at a third.

The shared nouns ("Lodge / Hall / Ziggurat of X") read badly with a faith body, so the temple
hall carries its own per race (`HALL_RACES[tag]["temple_nouns"]`):

| Race | Level II / III / IV | Trains (key, read from land_units loc) |
|---|---|---|
| Chaos Dwarfs | Shrine / Temple / High Temple of Hashut | Lammasu `wh3_dlc23_chd_mon_lammasu` |
| Empire | Wizard's Tower / College / Grand College | no unit: +1/+2/+3 wizard hero capacity, `wh_main_effect_agent_cap_increase_wizard_empire` at `faction_to_faction_own_unseen` (CA's own building pair, values 1-2). Amended 2026-10-04: the Luminark needs settlement level 5, above every hall level |
| Dwarfs | Ancestor Shrine / Temple / Great Temple | Slayers `wh_main_dwf_inf_slayers` |
| Bretonnia | Grail Shrine / Chapel / Grail Basilica | Battle Pilgrims `wh_dlc07_brt_inf_battle_pilgrims_0` |
| Cathay | Shrine / Temple / Celestial Temple | Terracotta Sentinel `wh3_main_cth_mon_terracotta_sentinel_0` |
| Kislev | Shrine / Church / Cathedral of Ursun | War Bear Riders `wh3_main_ksl_cav_war_bear_riders_1` |
| Dark Elves | Shrine / Temple / Great Temple of Khaine | Witch Elves `wh2_main_def_inf_witch_elves_0` |
| High Elves | Shrine / Temple / Sacred Flame of Asuryan | Phoenix Guard `wh2_main_hef_inf_phoenix_guard` |

Every unit ships with its race's own pack or the base game, so `HALL_FALLBACK` needs no entry. A
unit is granted only from the level where CA's own building would give it (`_unit_level`). Hall
icons: eight new sets of three, from CA's temple and college building icons
(`make_guild_icons.py`), joining the existing 48.

## 6. Panel, art and text

- **Guild buttons:** a seventh 38px button at the existing 48px step; `gg_gbar` widens from 438 to
  about 486px, centred between the page arrows (x 20 and 732). The Lua's hand-written
  `gg_gtab_1..6` table is replaced by the generator's coordinates, so the two cannot drift.
- **Standings:** seven rows inside the existing 260px - step 44 to 38, row height 40 to 34 - so
  the faction list keeps its five rows. Final numbers from the preview render.
- **Crests:** one per flavour from CA's building icons (`make_guild_icons.py`).
- **Backgrounds:** a SEVENTH crop window of each race's existing CA loading-screen painting
  (amended 2026-10-04: CA ships one painting per race, none of a temple or wizard, and windows
  1-6 are taken), cropped to 790x700 and dimmed until it measures CA's own panel ground under this
  panel's scrim (`make_guild_backgrounds.py`'s existing rule); the Chaos Dwarfs too.
- **Text, every flavour:** name, description, nine service names and blurbs, bounty and demand
  text, the earn-route lines in the guild's hover, the four ledger sources, building lines
  ("Completing this earns N Reputation with the Temple of Hashut, and the same in Favour"), Help's
  guild-list page and earning page. Plain words: Reputation and Favour, no jargon, no "rung".
- **Previews:** the Guilds tab with the temple selected, the seven-row standings, the Court and
  the touched Help pages for at least the Chaos Dwarfs, the Empire and the Dark Elves, rendered
  from the shipped Lua and compared with today's renders. Contrast and text-fit checks green.

## 7. AI and settings

- **AI earning:** the per-turn routes run on AI turns as the other guilds' passive income does.
- **AI buying:** weights for the nine services in `zzz_derpy_guilds_ai.lua`; `anathema` follows the
  existing hostile-service rules.
- **AI building:** every temple hall chain gets a `cai_building_value` row, donor by the existing
  rule (a vanilla chain carrying public order); the existing zero-score check covers it.
- **MCT:** `rate_temple_devout`, `rate_temple_chaos`, `rate_temple_holy`, `cap_temple`, appended
  to `GG.TUNE_ORDER`; the four presets name all four. A campaign frozen before the update reads
  the defaults.

## 8. Compatibility and save safety

- `temple` is appended LAST to `GG.GUILDS`, `GUILDS` and `GGUI.GUILD_ORDER`. A six-guild save
  string loads with the temple at 0,0 (`GG.load` fills from `blank()`).
- Services appended after row 83; cooldowns are positional, so nothing shifts. Cards fall back to
  defaults on the length check, as they do today.
- `GG.RIVALS.temple` is nil; every rival read is nil-safe and a test proves the temple never
  costs or pays a rival.
- Hall locks for the new chains are written by the first turn-start sweep, as halls were for old
  saves.
- Every hard-coded six becomes `#GG.GUILDS` / `len(GUILDS)` where it counts guilds; asserts that
  pin a total are updated to the new total, not loosened.

## 9. Tests

Nothing ships until all are green.

- `gen_great_guilds.py --check` and `--selftest`, including new checks: every flavour has every
  temple text; every route's culture keys exist; rank and hall effects inside vanilla's range;
  the CHD settlement-type rows; building-line numbers equal what the Lua pays; every race-only
  token matches a chain of that race; every temple hall scored for the AI.
- `_guilds_harness.lua` blocks: each route per race, and a race without it paying nothing; the
  rival-free temple; a pre-change save string loading with every field intact; the cap and the
  Seat; a temple purchase through `GG.MP_OPS.buy`; the generic flavour having no panel.
- `_guilds_bounty_harness.lua` for the temple bounty.
- `mutate_guilds.py`: a mutant per new rule, each watched failing; the full run with no survivor
  and no stale anchor.
- `preview_guilds_panel.py` renders and checks (§6); `import_great_guilds.py --check`; the saved
  pack verified table by table; MD5 after deploy.

**In game after the build:**
1. The seventh button and page.
2. The temple hall in the Guild Halls tab.
3. Each route on the earnings sheet.
4. An old save loading.
5. One purchase of each service kind.

## 10. To read before writing (plan-time checks)

1. The public-order effect key and scope for the rank ladder, the hall bonus and the services,
   read from vanilla `effect_bundles_to_effects_junctions`, values inside vanilla's range.
2. The corruption API for "Holding back Chaos" (`check_lua_api.py --explain` on the region or
   province corruption reads) and the corruption pooled-resource or religion keys for Chaos and
   Vampiric.
3. The culture keys of every holy-war enemy (Dwarfs, Greenskins, Skaven, Chaos and its daemon
   cultures, Vampire Counts, Norsca, both elves).
4. The Empire wizard-hero subtypes and the Death Hag subtype, and which agent-action events
   carry the acting character's subtype.
5. The settlement-public-order read for "Devout provinces".
6. One CA loading-screen painting per race with a temple, priest or wizard subject.
7. Every §3.3 token against `building_levels` for that race, and the share table after.
8. Each hall unit's `_unit_level` in its race's set.

## 11. As shipped (amended 2026-10-05)

**§3.2, Devout provinces, as built:** one count per PROVINCE whose first region has public order
above 0, not one per settlement. Public order is the province's, so a settlement count would pay
one province once per settlement in it (plan ruling 4).

**§3.2, Holding back Chaos, as built:** a province counts as clean only when it holds none of the
five Chaos corruptions: `wh3_main_corruption_chaos`, `_khorne`, `_nurgle`, `_slaanesh` and
`_tzeentch`. For Bretonnia and Kislev it must also hold no `wh3_main_corruption_vampiric`. The
four god keys were added after the final review: with Undivided alone, CA's Saphery (75 Slaanesh)
counted as clean. The devout and chaos routes are also previewed in `GG.turn_start_pay`, so the
lead hold sees them.

**§4, service effects as shipped** (values for every flavour except where marked):

| Key | Kind | Turns | Favour | Effects |
|---|---|---|---|---|
| `hashut_blessing` | army | 5 | 50 | leadership +6 (`force_to_force_own`) |
| `forge_sermons` | settlement | 8 | 50 | public order +4 (`region_to_province_own_unseen`) |
| `temple_tithe` | gold | - | 50 | +2,000 gold |
| `zeal` | army | 5 | 150 | melee attack +6, charge bonus +10% (`force_to_force_own`) |
| `purge_unclean` | settlement | 8 | 150 | corruption -6 (`wh3_main_effect_corruption_reduction_events`, `region_to_province_own_unseen`); Chaos Dwarfs: public order +6 instead |
| `anathema` | enemy_settlement | 5 | 150 | public order -6 (`region_to_province_own_unseen`) |
| `holy_war` | bundle, lead | 10 | 400 | leadership +6, replenishment +10% (`faction_to_force_own`) |
| `miracle` | army, heal | 2 | 400 | heals the army; leadership +10 (`force_to_force_own`) |
| `consecration` | bundle, lead | 12 | 400 | public order +4 and corruption -3 (`faction_to_province_own`); Chaos Dwarfs: public order +4 only |

Public order is `wh_main_effect_public_order_events` throughout.
