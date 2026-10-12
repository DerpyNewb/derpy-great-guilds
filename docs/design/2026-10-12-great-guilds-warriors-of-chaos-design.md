# The Great Guilds: the Warriors of Chaos as "The Dark Gods" (a tenth race) - design

**Status:** approved in conversation, section by section, on 2026-10-12. §6 (the Undivided's
temple lore) and the hire unit in §2 were added while writing and were NOT shown in
conversation; they await the author's review with the rest of this file. Not built.

**Builds on:**
- `2026-09-23-great-guilds-flavours-design.md`, the flavour model;
- `2026-09-29-great-guilds-service-pools-and-races-design.md`, race services, earn routes and twists;
- `2026-10-04-great-guilds-halls-design.md`, halls;
- `2026-10-04-great-guilds-temple-guild-design.md` and `2026-10-09-great-guilds-temple-lore-design.md`, the temple;
- `2026-10-05-great-guilds-skaven-design.md`, the last race added and the recipe this follows;
- `docs/sessions/HANDOFF_20261005_GUILDS_SKAVEN.md` "Adding a tenth race: every declaration point".

## 1. What and why

The Warriors of Chaos join the Great Guilds. They have no guilds: they have gods. Each of the
seven slots becomes a Chaos god the faction worships, drawn from the major and minor gods on
the Warhammer Fantasy wiki's "Chaos Gods" page ("Notable Chaos Gods and Aliases"), the Horned
Rat excluded.

| Decision | Ruling |
|---|---|
| Scope | Full parity with the other nine races in ONE build, the Skaven recipe: seven gods, panel and card frame, art, building words, temple routes and lore, halls, race services, earn route, twist |
| Tag and culture | `_chs`, `wh_main_chs_chaos`. **Not** `wh3_main_chs_chaos`, which does not exist: CA's `cultures` table and `wh3_dlc20_campaign_chs_dark_authority.lua` both use `wh_main_chs_chaos` |
| Placement | `_chs` goes before `_gen` in `FLAVOURS`, so `_gen` stays last. Feed offset 100 (5101-5106) |
| Words | Panel "The Dark Gods", tab "Gods". Reputation is **Devotion** in every Warriors of Chaos string; Favour stays Favour. The leadership title is "Champion" |
| Rivals | Per race, new code (§4.1): the canonical feuds Khorne-Slaanesh and Nurgle-Tzeentch |

**Not in scope:**
- **Norsca.** Lore-sound (same Four, CA calls them the Hound, Eagle, Serpent and Crow), but it
  shares almost nothing with this build: no Souls, so no Gifts route; Necoho and Zuvassin have
  no Norscan basis; its own names, frame, art, halls and roster. Its own spec later (§13).
- The four daemon cultures (Khorne, Nurgle, Slaanesh, Tzeentch, Daemons of Chaos).
- Generalising the per-race lists.
- The public GitHub repo sync.

## 2. Identity

Sentences are built as "the {name}" (the Skaven build learned that "the Clan Eshin" reads
wrong), so a card carries the god's epithet and the prose names the god ("Khorne, the Blood
God, ...").

| Key | Earns from (unchanged) | Rival (§4.1) | Name on the card | God |
|---|---|---|---|---|
| immortals | battles won | slavers | The Blood God | Khorne |
| slavers | sacking and razing | immortals | The Dark Prince | Slaanesh |
| overseers | buildings, growth | daemonsmiths | The Plague Lord | Nurgle |
| daemonsmiths | technologies | overseers | The Changer of Ways | Tzeentch |
| brass | income | khanate | The Doubter | Necoho |
| khanate | hero actions | brass | The Undoer | Zuvassin |
| temple | faith | none | The Undivided | Chaos Undivided |

- **Ranks** (the Path to Glory): Thrall, Marauder, Warrior, Chosen, Exalted.
- **Name limits:** every name within `GUILD_NAME_MAX` 22, every rank within `RANK_NAME_MAX` 12.
- **Hire unit** (`GG.HIRE_UNIT_BY_CULTURE`, the shared service that hires the race's elite):
  Chosen, unmarked. Key verified at plan time (§11 item 1). *Added while writing; review.*

**Twist, "The Fickle Gods"** (the wiki: "jealous and fickle deities"):
`GG.TWISTS["wh_main_chs_chaos"] = {rate_decay = 150, demand_reward = 150}`. Devotion fades half
again as fast when a god is not fed; a god's demand pays half again as much. No race uses a
decay above 100, so it is distinct from all nine. Both are existing dials.

**Necoho's rule:** "Necoho requires nothing from his followers" (wiki), so the Doubter never
issues a demand (§4.4).

## 3. Earning

### 3.1 Shared routes (no code change)

Income pays the Doubter, battles won the Blood God, technologies the Changer of Ways, hero
actions the Undoer, sacking and razing the Dark Prince, missions every god.

### 3.2 Race earn route, "Gifts of the Gods"

Spending Souls on a god's gifts pays that god **1 Devotion per 25 Souls**, points-based with a
carry like Grudges (`derpy_gg_carry_<faction>_gifts`).

| Vanilla pool (engine-written; CA reads it in its own victory objectives) | God |
|---|---|
| `wh3_dlc20_chs_souls_spent_kho` | the Blood God |
| `wh3_dlc20_chs_souls_spent_nur` | the Plague Lord |
| `wh3_dlc20_chs_souls_spent_sla` | the Dark Prince |
| `wh3_dlc20_chs_souls_spent_tze` | the Changer of Ways |
| `wh3_dlc20_chs_souls_spent_und` | the Undivided |

- Scale: CA's victory asks 5,000 / 15,000 Souls to one god (short / long). 15,000 Souls is 600
  Devotion over a campaign, under each god's per-turn cap.
- The Doubter and the Undoer get nothing from Souls: the Four do not deal with renegades.
- New code, §4.2. Ledger source `gifts`. No MCT rate, like every race earn route.

### 3.3 The Undivided's routes (temple)

| Route | Rule |
|---|---|
| Corruption | `rate_temple_taint` per province carrying Undivided corruption, `wh3_main_corruption_chaos` above 0 (§4.3) |
| Holy war | Wins against `wh_main_emp_empire`, `wh3_main_ksl_kislev`, `wh3_main_cth_cathay` (keys already in `GG.TEMPLE_ROUTES`) |
| Priests | Unmarked Chaos Sorcerer heroes pay the Undivided instead of the Undoer: `wh_main_chs_chaos_sorcerer_fire`, `_death`, `_metal`, `wh_dlc07_chs_chaos_sorcerer_shadow` (confirmed as heroes at plan time). Marked Sorcerers and every Exalted Hero still pay the Undoer, so Zuvassin keeps an income |
| Devout, clean provinces | not used: the Warriors of Chaos are the corruption |

All through `GG.capped_grant` and `cap_temple`; the corruption route is previewed in
`GG.turn_start_pay` like the Skaven's.

### 3.4 Recruiting (`GG.RECRUIT_ROUTES`, first fit wins)

| Units | God |
|---|---|
| `_mkho` | the Blood God |
| `_mnur`, and the Nurgle-named DLC units without the suffix (Blightkings, Glottkin's) | the Plague Lord |
| `_msla` | the Dark Prince |
| `_mtze` | the Changer of Ways |
| unmarked | the Undivided |

No recruit pays the Doubter or the Undoer: they have no warriors. The race opens with its hall
families, per the 2026-10-11 recruiting rule. `check_recruit_routes()` runs it against the whole
vanilla roster (319 `_chs_` main units).

### 3.5 Buildings (`GG.BUILDING_THEME_RACE["_chs"]`)

The race's chains are `woc`-named: 54 in `wh_main_bas_chs`, 67 in Glottkin's
`wh3_dlc29_woc_glottkin`. None belongs to a god except Glottkin's Nurgle gardens, so words go
by trade. Settled at plan time by the generator's one-race match and share table:

| Chain words | God |
|---|---|
| `shrine`, `chaos_altar_corruption` | the Undivided |
| `growth`, `nurgle_garden` | the Plague Lord |
| `income`, `woc_resource_` | the Doubter |
| `warriors`, `knights`, `marauder`, `chaos_altar_recruit` | the Blood God |
| `monsters` (spawn and mutation) | the Changer of Ways |
| `vassals` | the Dark Prince |
| `towers`, `garrison` | the Undoer |

## 4. New code paths

Each is pcall-wrapped like every listener, and gets a harness case and a mutant.

1. **Per-race rivals.** `GG.RIVALS` stays the global table. A new
   `GG.RIVALS_RACE["wh_main_chs_chaos"] = {immortals = "slavers", slavers = "immortals",
   overseers = "daemonsmiths", daemonsmiths = "overseers", brass = "khanate", khanate = "brass"}`
   and `GG.rival_of(faction, guild)` returning the race's table or the global one. Every read of
   `GG.RIVALS` goes through it. 14 lines of `zzz_derpy_guilds.lua` and 3 of the UI name
   `GG.RIVALS` or `GG.rival*`, the declaration and the `rival_loss` / `rival_cost` helpers among
   them; the actual read sites are listed at plan time. `RIVAL_PAIRS` in the generator gains a per-tag mirror, and the Help text names the
   race's pairs.
2. **Gifts.** `GG.EARN_ROUTES.gifts = {per = 25}` and `GG.EARN_OF["wh_main_chs_chaos"] = "gifts"`.
   The five pools join `GG.POOL_ROUTES` as `gifts`, and a new `GG.POOL_GUILD` names each pool's
   god, because today a route names one guild. `GG.pool_route_counts` decides the factor (§11 item 3).
3. **Taint names its resource.** `GG.TEMPLE_ROUTES[...].taint` becomes the resource key instead of
   `true`: the Skaven `"wh3_main_corruption_skaven"`, the Warriors of Chaos
   `"wh3_main_corruption_chaos"`. `GG.temple_counts` reads that key. The generator's mirror
   follows.
4. **Necoho's rule.** `GG.NO_DEMAND = {["wh_main_chs_chaos"] = {brass = true}}`; the demand picker
   skips a guild listed for the faction's culture. Mirrored in the generator; the Help page says
   the Doubter asks nothing.
5. **Possibly: a hall with no unit outside the temple** (the Doubter's and the Undoer's, §7). The
   Grey Seers' and the Empire College's unitless halls are both temple halls. If the hall Lua or
   the generator assumes a unit for every non-temple guild, this is new code; §11 item 12 decides.

## 5. Race services

Three, priced by `RACE_PRICE` (50/150/400 Favour, cooldowns 8/12/16, rank 4 `lead`), appended
AFTER the Skaven rows because cooldowns are saved by position. The harness pin moves from
"Skaven rows last" to "Warriors of Chaos rows last".

| Rank | God | Key | Name | Effect |
|---|---|---|---|---|
| 2 | slavers | `soul_tithe` | Tithe of Souls | adds Souls (`wh3_dlc20_chs_souls`), sized against CA's own 500-Soul mission payload (factor `wh3_dlc20_souls_other`) |
| 3 | daemonsmiths | `eye_turns` | The Eye Turns | adds progress toward CA's Eye of the Gods, if a script can add to that resource. Otherwise a Tzeentch alternative from documented calls, recorded as a ruling (the Menace Below precedent) |
| 4 | immortals | `skull_throne` | Skulls for the Skull Throne | bundle, lead: 10 turns, melee attack and battle experience for every army |

## 6. The Undivided by its own lore (temple lore) - *added while writing; review*

The 2026-10-09 temple-lore build gives every race its own temple effects in `TEMPLE_LORE` and
three signature temple services through `for_tag` on `hashut_blessing`, `zeal` and `holy_war`.
Section 3 of the conversation did not cover the Undivided. Proposed:

| Field | Proposal | Shape it copies |
|---|---|---|
| Rank | Winds of Magic reserve capacity for every army, the shared `_WINDS_LORE` ladder | Chaos Dwarfs, Empire, Cathay, Skaven. The Undivided's priests are the Sorcerers (§3.3) |
| Hall | Undivided corruption +2/+4/+6 in the settlement, which feeds the Undivided's own corruption route | the Skaven's hall (`wh3_main_effect_corruption_skaven_buildings`), with the Undivided key found at plan time |
| Seat | Undivided corruption +2 in every province | the Skaven's seat |
| Three services | the race's own names and blurbs on `hashut_blessing`, `zeal` and `holy_war`; holy war names the Empire, Kislev and Cathay | every race since 2026-10-09 |

## 7. Halls

The Warriors of Chaos join `HALL_TAGS` / `GG.HALL_TAGS` and `HALL_RACES["_chs"]`:
- **`set`:** `wh_main_bas_chs`. **`extra_sets`:** `wh3_dlc29_woc_glottkin`, and any other
  lord's own set found at plan time.
- **Nouns:** Idol / Altar / Monolith.
- **AI donor:** the existing rule.

| God | Hall |
|---|---|
| the Blood God | Chosen, Mark of Khorne (`wh3_dlc20_chs_inf_chosen_mkho`, the key CA's own Norsca script spawns) |
| the Plague Lord | Chosen, Mark of Nurgle |
| the Dark Prince | Chosen, Mark of Slaanesh |
| the Changer of Ways | Chosen, Mark of Tzeentch |
| the Undivided | no unit; §6's hall effect |
| the Doubter | no unit (he has no warriors); province income up. His followers waste nothing on altars |
| the Undoer | no unit; enemy hero actions in the province fail more often. The wiki's one recorded blessing of Zuvassin: "enemies automatically failing all of what they plan" |

Every key and effect scope is checked at plan time; the generator already refuses an unknown
key or a scope vanilla never pairs with an effect. Hall icons: seven, from CA's Warriors of
Chaos building icons.

## 8. Panel, art and text

- **Frame.** `FRAMES["_chs"]` / `GGUI.FRAME["_chs"]`. CA's Warriors of Chaos skin
  (`ui/skins/wh3_dlc20_chs_chaos/`) is 27 files with no card frames, so the frame comes from a
  Warriors of Chaos panel: the Gifts of Chaos (Souls) panel first, confirmed at plan time.
  Briefed against that named panel and a reference screenshot, per `docs/CUSTOM_UI.md`
  "Design direction". `RANK_STATS_PAD["_chs"]` and `GGUI.HALLS_IN_HEADER` are decided by the
  preview.
- **Grounds.** One CA painting per god where one exists, as for the Chaos Dwarfs and Dwarfs:
  - the Four: `ui/loading_ui/load_images/campaign_khorne1.png`, `campaign_nurgle1`,
    `campaign_slaanesh1`, `campaign_tzeentch1`;
  - the Undivided: `campaign_daemons1`;
  - the Doubter and the Undoer: two windows of `campaign_chaos1`.

  All dimmed to the panel's measured ceiling; `campaign_chaos_host_of_the_triplets1` is the spare.
- **Crests.**
  - The Four: CA's mark icons (`ui/ancillaries/wh_main_anc_mark_of_chaos_mark_of_*`, the
    Khorne one from `ui/ability_icons/`), each measured flat before it is picked.
  - The Undivided: the Star of Chaos if CA ships it flat, otherwise the race crest.
  - The Doubter: plain. The wiki: "Necoho has no known symbol."
  - The Undoer: a CA icon chosen at plan time. His real symbol ("a double-ended Y-shape,
    normally incomplete or incorrectly drawn") is drawn only if the author asks for Codex art,
    and then judged by antislop before use.
- **Text**, every family the other nine carry, with Devotion and the epithets:
  - names, descriptions, ranks;
  - the 63 shared and 3 race service names and blurbs, and §6's three temple services;
  - bounties, feed messages;
  - the Help pages, including the halls page, the Gifts route, the Fickle Gods, the race's own
    rival pairs and "the Doubter asks nothing";
  - ledger sources: `gifts` new; `taint` reads "Undivided corruption" for this race;
  - MCT names (`GGUI.MCT_NAMES["_chs"]`). The MCT page itself is shared by every race and keeps
    saying Reputation.

  Plain words, no jargon; every lore word checked against CA's loc.
- **Previews:** a god's page, the Undivided's, the Leaderboard, the Court and Help, rendered from
  the shipped Lua (`GG_DUMP_TAG=_chs`) and compared with the reference. Contrast and fit green.

## 9. Save safety, AI and MCT

- A campaign already running with a Warriors of Chaos human starts its Warriors of Chaos
  factions blank (0/0 on every god), the path `GG.load` takes for any new faction.
- Nothing stored changes shape. Per-race rivals and Necoho's rule are code, not save state.
- `_gen` stays last, so `GG.GENERIC` (30) and every existing feed slot are unchanged.
- AI Warriors of Chaos earn only when a Warriors of Chaos human plays (`GG.covered`). AI buying
  needs no code.
- No new MCT key: the Undivided's corruption reuses `rate_temple_taint`; the Gifts route has no
  rate.

## 10. Tests

Nothing ships until all are green.

- **Generator `--check` and `--selftest`.**
  - Every nine-race pin moves to ten; each is counted, not loosened.
  - Every mirror gains `_chs`: `check_race_mirror`, `check_hire_units`, `check_frame_mirror`,
    `check_hall_mirror`, `check_temple_routes`, `check_flavour_mirror`, `check_mct_names`.
  - New mirrors: the per-race rival table, `GG.POOL_GUILD`, `GG.NO_DEMAND`.
  - Every new key is read from `db.pack` (`check_live_references`); the race words match
    Warriors of Chaos chains only.
- **`_guilds_harness.lua`:**
  - Warriors of Chaos rivals use their own pairs, and each of the other nine races still uses the
    global table (one pin per race);
  - Gifts pays the right god per 25 Souls with a carry, and pays the Doubter and the Undoer
    nothing;
  - the Undivided corruption route pays per province and nothing for a clean one; the Skaven
    taint still reads only Skaven corruption;
  - an unmarked Sorcerer's action pays the Undivided, a marked one's the Undoer;
  - recruiting pays by mark, and nothing pays the Doubter or the Undoer;
  - the Doubter never issues a demand;
  - the turn-start preview includes the Undivided corruption.
- **`_guilds_bounty_harness.lua`:** the Fickle Gods dials and the twist table entry.
- **`mutate_guilds.py`:** a mutant per new rule; the full run with no survivor and no stale anchor.
- **Build:**
  1. `import_great_guilds.py --check`, then the build; the saved pack verified;
  2. a backup to `Modding Files/Backup/`;
  3. a deploy to the **Workshop folder** (the Great Guilds is Workshop-hosted, item 3815248936;
     it never goes in `data/`), diffed first;
  4. an MD5 compare.

**In game after the build:**
1. The Warriors of Chaos panel opens with its frame and reads "The Dark Gods".
2. Souls spent on a god's gifts pays that god.
3. Undivided corruption shows on the earnings sheet.
4. A hall builds, including a unitless one.
5. Each rival pair takes from the right god.
6. The Doubter never issues a demand.
7. A save from before the update loads.

## 11. To read before writing (plan-time checks)

1. **Unit keys:** the four marked Chosen and the unmarked Chosen (hire unit), and `_unit_level` for
   each in `wh_main_bas_chs`.
2. **Building sets** of every Warriors of Chaos lord (Archaon, Kholek, Sigvald, Be'lakor, Festus,
   Valkia, Vilitch, Azazel, the Glottkin, and the rest), against `covered_chains`'s one-race rule.
3. **The Souls-spent pools:** which factor they change by, whether `PooledResourceChanged` fires
   for them, and whether it fires for AI factions.
4. **Souls and Eye of the Gods:** the Souls payload factor; whether
   `wh3_dlc20_chs_eye_of_the_gods` can be added to by script.
5. **Hero subtypes:** that the four unmarked Sorcerer subtypes are heroes
   (`faction_agent_permitted_subtypes`), and which subtypes are marked.
6. **Effects and scopes:** the Doubter's and the Undoer's hall effects, the Khorne bundle, §6's
   hall and seat (the Undivided corruption keys).
7. **The frame panel's art** and the reference screenshot; the crest and hall icon stems.
8. **Feed indexes 5101-5106** free in vanilla.
9. **Every read of `GG.RIVALS`** (17 lines name it across the model and UI; not all are reads), and whether the AI or the bounty code reads
   rivals elsewhere.
10. **Every building word** against the race's chains, and the share table after.
11. **The `_mkho` count.** Only 23 Khorne-marked units against 39-43 for the others; check whether
    Khorne units use another suffix, so the recruit route does not starve the Blood God.
12. **Unitless non-temple halls:** whether the hall Lua and the generator accept a brass or khanate
    hall with no unit (§4.5).

## 12. Lore rulings

- **The seven:** Chaos Undivided and the Four, plus Necoho and Zuvassin. These are GW's two
  Renegade gods that replaced Malal. The author's choice over Hashut + Zuvassin and Malal +
  Zuvassin, 2026-10-12.
- **Excluded:** the Horned Rat (author), and Kweethul with it (the wiki: "some scholars believe this
  may simply be another name for the Horned Rat"); Hashut, who stays the Chaos Dwarfs' god and
  their temple; Malal, whose name GW lost the rights to.
- **The minor gods' basis is thin, and recorded as a ruling, not as lore.** The wiki places
  Necoho's only worship and Zuvassin's only temple in Bolgasgrad (Kislev), and their other
  cults in the Old World, not among the northern tribes. What does hold: Zuvassin is "nominally
  an enemy of Chaos in all its forms, including the other Renegade Gods", which grounds the
  Doubter-Undoer rivalry, and Necoho "is generally opposed to all other cults of all kinds",
  which grounds his asking nothing and taking no Souls.
- **Rivalries:** Khorne-Slaanesh and Nurgle-Tzeentch, as lore has them and as CA's own
  `wh_dlc08_norscan_gods.lua` encodes them (`rivalry_conversion_table`). An earlier draft of this
  design claimed the mod's existing pairs already matched; they do not, hence §4.1.

## 13. Norsca, for its own spec

Recorded so the follow-up starts from it:
- Culture `wh_dlc08_nor_norsca`.
- CA's own vocabulary: the Hound (Khorne), the Eagle (Tzeentch), the Serpent (Slaanesh), the
  Crow (Nurgle). Norscan names on the wiki: Kharnath / Arkhar, Tchar, Shornaal / Lanshor,
  Neiglen / Nurglitch / Onogal.
- Its natural earn route is CA's allegiance counters `nor_progress_crow/eagle/hound/serpent`
  (factor `buildings`, raised by altars), so the mod's Devotion builds on CA's figure instead of
  sitting beside it as a second standing.
- Its two minor slots need their own ruling: Necoho and Zuvassin have no Norscan basis.

## 14. As shipped

Built 2026-10-12 as 33EF1D54 (after the final review, the Buy button and the wrap fix), deployed to the Workshop folder, not uploaded:
`docs/sessions/HANDOFF_20261012_GUILDS_WARRIORS_OF_CHAOS.md`. Where it differs from this spec:
- **§7 halls:** built in Dark Fortresses and the Glottkin's gardens, never Chaos Altars (the altar
  stops at level 2). No hall trains a unit; the Four's halls widen their Marauder pool and the
  Undoer's makes enemy heroes fail (plan Ruling 3).
- **§3.2 Gifts:** one remainder per god, not per route.
- **§2 hire unit:** the Chosen of Khorne (plan Ruling 4).
- **§3.4 recruiting:** a `UnitUpgraded` listener as well (plan Ruling 9).
- **§8 text:** the word pass also makes a god singular ("has", "wants") and calls the lead a
  Champion; "Chaos Undivided corruption" is CA's name.
- **§8 art:** the Four are CA's tech-tree watermarks, not the mark icons (plan Ruling 15).
- No `zeal` override: the base zeal fits.
