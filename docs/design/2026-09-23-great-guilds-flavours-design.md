# The Great Guilds: Empire and Dwarf flavours - design

Date: 2026-09-23. Status: approved in conversation section by section; this file awaits review.

## 1. Goal

A player who runs the Empire or the Dwarfs sees their own race's six guilds everywhere the
mod speaks: the panel, Help, the Log, event messages, Faction Effects bundle titles, bounty
missions, icons, panel grounds and the crest. Chaos Dwarfs see exactly what they see today.

What the user decided:

| Question | Answer |
|---|---|
| Depth | Everywhere: panel, Help, event messages, Faction Effects titles, bounty missions |
| Art | Icons and backgrounds, both from CA's own Empire/Dwarf art |
| Approach | Flavour tag on keys (not panel-only text, not separate guilds per race) |
| Names | As in section 3, approved as written |
| Backgrounds | Pan one painting: six windows out of each race's loading-screen art |

## 2. Scope

In:
- Empire (`wh_main_emp_empire`) and Dwarfs (`wh_main_dwf_dwarfs`).
- Names, ranks, services, guild descriptions, six hand-written service blurbs, bounty
  titles and texts, every message-event text, Help, the Log.
- 42 effect bundles, 6 bounty missions and 4 feed events per race, each a copy of the
  Chaos Dwarf row with its own key, title and picture.
- Icons, grounds and crest per race.

Out:
- Any other culture. Lizardmen, Araby and the rest keep the Chaos Dwarf names, as they do now.
  A generic neutral set is deferred.
- Different mechanics per race. Effects, values, costs, cooldowns, rivalries and earn routes
  stay identical. Only the hire unit already differs per culture, and still does.
- Save migration. The mod is unpublished and the only saves in existence are the user's own
  Chaos Dwarf campaigns, whose keys do not change. An Empire or Dwarf save carrying guild
  standing from an earlier build would keep its untagged rank bundles next to the new ones;
  the fix is a one-time sweep of about five lines, added only if such a save exists.
- The Patron bundle. It stays one shared row: "Guild Patron" names no guild.
- The panel title stays "The Great Guilds" for everyone (the title plate clips at about 19
  characters).

## 3. Names

Guild ids, rivalries (`brass`/`khanate`, `immortals`/`daemonsmiths`, `overseers`/`slavers`)
and mechanics stay the same. Every name is 22 characters or fewer and starts with "The".

| Id (what it does) | Chaos Dwarfs (unchanged) | Empire | Dwarfs |
|---|---|---|---|
| brass (building income) | The Brass Tablets | The Merchant Guilds | The Merchant Clans |
| immortals (replenishment, hire unit) | The Immortals | The Greatswords | The Hammerers |
| daemonsmiths (research) | The Daemonsmiths | The Engineers' School | The Engineers' Guild |
| khanate (agents, scouting) | The Khanate | The Thieves' Guild | The Rangers |
| overseers (construction) | The Overseers | The Masons' Guild | The Miners' Guild |
| slavers (sacking, razing) | The Slavers | The Free Companies | The Grudge-Settlers |

Ranks 1-5:
- Chaos Dwarfs: Unmarked / Indebted / Sworn / Favoured / Exalted (unchanged)
- Empire: Outsider / Apprentice / Journeyman / Master / Grand Master
- Dwarfs: Stranger / Beardling / Oathsworn / Longbeard / Elder

Services, in SERVICES order (rank 2 / 3 / 4 per guild):

| Key | Chaos Dwarfs | Empire | Dwarfs |
|---|---|---|---|
| caravan_levy | Caravan Levy | Call in the Debts | Road-Toll |
| writ_monopoly | Writ of Monopoly | Imperial Charter | Hold Charter |
| long_ledger | The Long Ledger | The Altdorf Exchange | The Clan Ledger |
| oathbound_draft | Oathbound Draft | Muster Roll | Call to the Hold |
| hire_immortals | Hire the Immortals | Hire the Greatswords | Hire the Hammerers |
| astragoths_levy | Astragoth's Levy | The Emperor's Levy | The High King's Levy |
| forge_rite | Forge-Rite | Proving Grounds | Guild Workshop |
| bound_blueprint | Bound Blueprint | The School's Treatise | Guild Secrets |
| bound_ordnance | Daemon-Bound Ordnance | Guns of Nuln | Guild Artillery |
| hobgoblin_eyes | Hobgoblin Eyes | Eyes in Every Tavern | Ranger's Report |
| knife_in_dark | Knife in the Dark | Knife in the Alley | Ambush in the Passes |
| khans_price | The Khan's Price | Protection Money | Cut Their Roads |
| lash_the_gangs | Lash the Gangs | Overtime Wages | Double Shift |
| raise_ziggurat | Raise the Ziggurat | Master's Commission | Delve Deeper |
| works_of_zharr | Works of Zharr | The Emperor's Works | Works of Grungni |
| coffle_drive | Coffle Drive | Plunder Rights | Settle the Account |
| slave_tithe | Slave Tithe | The Company's Cut | Weregild |
| great_coffle | The Great Coffle | The Grand Pillage | The Great Reckoning |

## 4. Prose

The generator's `GUILD_DESC` strings are two halves joined by `||`: a flavour sentence and
the earn sentence ("Reputation accrues from..."). The earn sentence is mechanical and is
shared by all three races; only the flavour half is written per race. The Chaos Dwarf
halves stay verbatim.

### 4a. Guild descriptions (flavour half)

Empire:
- brass: "The counting-houses of Altdorf and Nuln. Every road toll, river tariff and letter of
  credit in the Empire passes through their books."
- immortals: "Veterans who swore their lives to an Elector Count's banner. They sell that oath
  now, to whoever can carry it."
- daemonsmiths: "Altdorf's engineers, who build what should not work and make it fire. They
  sell what they know, in instalments."
- khanate: "Every tavern has a back room, and every back room has an ear. Their knives are for
  hire to anyone, including against you."
- overseers: "The builders of every wall and temple from the Reikland to Ostland, and the only
  ones who know where the foundations are weak."
- slavers: "Sell-swords and road-wardens paid in plunder. Their ledger is measured in what they
  carry home."

Dwarfs:
- brass: "The traders of the Karaks, who remember every debt for as long as there is stone
  to write it on."
- immortals: "The king's own guard, sworn to the throne of their hold. Their oath can be lent,
  never broken."
- daemonsmiths: "Keepers of secrets guarded since the first hold was dug. They share them
  slowly, and never twice."
- khanate: "Dwarfs who left the holds to watch the passes. They see everything that moves
  above ground, and sell it dearly."
- overseers: "The delvers and stone-cutters who carved every hold. Nothing is built in the
  mountains without them."
- slavers: "The clans who take the Book of Grudges at its word. Every line struck out is paid
  for in plunder."

### 4b. The six hand-written service blurbs

The other twelve are built from `EFFECT_BLURB` and the values, and carry over unchanged. The
mechanical sentence in each blurb below is what the payload does for a non-Chaos Dwarf
faction: `slave_tithe` pays 3,000 gold, because `is_chd` is false for both races.

Empire:
- caravan_levy: "The Merchant Guilds call in what they are owed. Adds 2,500 gold to your
  treasury at once."
- hire_immortals: "A company already sworn and already armed. Adds one unit of Greatswords to
  an army of your choosing."
- bound_blueprint: "The Engineers' School hands over work already done. Completes the
  technology you are currently researching, at once."
- hobgoblin_eyes: "The Thieves' Guild sells what its ears have heard. Reveals one region
  through the shroud, permanently."
- raise_ziggurat: "The Masons' Guild works through the night. Upgrades one of your buildings to
  its next level at once, and free."
- slave_tithe: "The Free Companies send you your share of the take. Adds 3,000 gold to your
  treasury."

Dwarfs:
- caravan_levy: "The Merchant Clans collect on every road between the holds. Adds 2,500 gold
  to your treasury at once."
- hire_immortals: "A company already sworn and already armed. Adds one unit of Hammerers to an
  army of your choosing."
- bound_blueprint: "The Engineers' Guild parts with a secret, once. Completes the technology
  you are currently researching, at once."
- hobgoblin_eyes: "The Rangers report what they have seen from the high passes. Reveals one
  region through the shroud, permanently."
- raise_ziggurat: "The Miners' Guild works a double shift. Upgrades one of your buildings to its
  next level at once, and free."
- slave_tithe: "Gold paid to settle a grudge, and passed on to you. Adds 3,000 gold to your
  treasury."

The unit names in the two `hire_immortals` blurbs must match vanilla's display names for
`wh_main_emp_inf_greatswords` and `wh_main_dwf_inf_hammerers`, read with
`tools/read_vanilla_loc.py`.

### 4c. Bounties (title, text)

The kind per guild is unchanged: brass and overseers take a region, immortals and khanate
kill a lord, daemonsmiths and slavers sack.

Empire:
- brass: "Open the Market" - "The Merchant Guilds want that town's tolls paid in Altdorf.
  Take it standing."
- immortals: "A Duel for the Banner" - "A general is being spoken of with respect. The
  Greatswords would like that corrected."
- daemonsmiths: "Salvage the Works" - "Whatever that place has built, the School wants on its
  own benches. Bring it back in pieces."
- khanate: "A Name Crossed Out" - "The Guild does not care how it is done, only that the
  name stops being used."
- overseers: "Stone Still Standing" - "Take it whole. The Masons want the walls left up, so
  they can be paid to mend them."
- slavers: "Pay Day" - "Empty it. The companies are owed, and that place can pay them."

Dwarfs:
- brass: "Reopen the Road" - "The Merchant Clans want that place back in their ledgers. Take
  it standing."
- immortals: "A Grudge on a Name" - "A general has been boasting. The Hammerers would like
  that settled."
- daemonsmiths: "Recover the Craft" - "Whatever was forged in that place was likely stolen
  from us first. Bring it back in pieces."
- khanate: "Silence in the Passes" - "The Rangers want the name stopped. How is their
  affair."
- overseers: "Reclaim the Hold" - "Take it whole. The Miners' Guild wants tunnels, not
  rubble."
- slavers: "Strike a Line" - "Sack it. One more grudge struck from the Book, and paid for."

### 4d. Generated text that has to stop hardcoding Chaos Dwarf words

- The "half" notice says "At Indebted they open their first service to you." It takes
  `rank_names[1]` instead.
- Help page 2 says "a forge the Daemonsmiths, a dock the Brass Tablets, a barracks the
  Immortals". It is derived from each race's names instead. Page 2 is at 21 of 21 lines
  today, so longer names can push it over; `check_help_pages` runs per race and refuses.
  If it does, the fix is to shorten wording on that page, not to drop a line.
- Message titles use collective plural verbs ("The Masons' Guild Have Noticed You"). That is
  British usage and already how "The Khanate" reads; no per-guild verb table.

## 5. The flavour tag

`GG.FLAVOURED` in `zzz_derpy_guilds.lua` changes from `culture = true` to
`culture = {tag = ..., feed = ...}`:

| Culture | tag | feed offset |
|---|---|---|
| `wh3_dlc23_chd_chaos_dwarfs` | `""` | 0 |
| `wh_main_emp_empire` | `"_emp"` | 10 |
| `wh_main_dwf_dwarfs` | `"_dwf"` | 20 |

`GG.tag(faction)` returns the tag of the faction's culture (via `GG.CULTURE_OF`), and `""`
for any other or unreadable culture. `GG.feed(faction, base)` returns `base` plus the offset.
Both are pure lookups; neither calls the engine beyond what `GG.covered` already caches.

**One rule: every key the player reads gets the tag appended.**

| What | Built in | Chaos Dwarfs | Empire example |
|---|---|---|---|
| Panel text (every `derpy_gg_*` loc key) | `GGUI.loc` | `derpy_gg_guild_brass` | `derpy_gg_guild_brass_emp` |
| Rank bundle | `GG.bundle_key(guild, rank, faction)` | `derpy_gg_rank_brass_3` | `derpy_gg_rank_brass_3_emp` |
| Lead bundle | `GG.lead_key(guild, culture)` | `derpy_gg_lead_brass` | `derpy_gg_lead_brass_emp` |
| Service bundle | `GG.payload` | `derpy_gg_svc_writ_monopoly` | `derpy_gg_svc_writ_monopoly_emp` |
| Bounty mission | `GG.bounty_mission_key(guild, faction)` | `derpy_gg_bounty_brass` | `derpy_gg_bounty_brass_emp` |
| Message stems | every `show_message_event` site | `..._derpy_gg_rank_brass_3` | `..._derpy_gg_rank_brass_3_emp` |
| Feed index | every `show_message_event` site | 5001-5004 | 5011-5014 (Dwarfs 5021-5024) |

Whose tag:
- Rank, lead and bounty keys: the faction that holds them. Lead keys are already swept per
  culture, so the per-culture key changes nothing about the sweep.
- Service bundles: the buyer's, including the hostile `khans_price` that lands on a target.
  The victim reads the buyer's guild's name, which is who did it to them.
- Messages: the faction that receives the message, so the reader sees their own race's words.
  Coverage is the player's culture, so an AI buyer is of the same culture in every
  single-player campaign.
- Panel: the local player's, looked up at draw time (never at script root, never from a turn
  handler that also resolves loc).

The tag goes before the engine's own `_title` / `_primary` / `_secondary` suffixes, on the
stem. `bounty_done` and `take_bounty_slot` compare against the tagged key for that faction.

Plain chrome ("Buy", tab labels, "Favour cost") goes through `GGUI.loc` like everything
else, so the generator writes it once per tag with identical text. That keeps `GGUI.loc` free
of a list of exceptions.

## 6. Generator (`tools/gen_great_guilds.py`)

- The name and prose tables (`GUILD_NAMES`, `RANK_NAMES`, service `name`, the six
  `SERVICE_BLURB` strings, `GUILD_DESC` flavour halves, `BOUNTIES` titles and texts) move into
  one `FLAVOURS` dict keyed by tag. The `""` entry holds today's values verbatim.
- `build()` emits every loc row, bundle (with its effect junction rows), bounty mission and
  feed event once per tag. Missions use `emp/generic` and `dwf/generic`; the four feed rows
  use the same picture names as today under `emp/` and `dwf/`. All eight are pictures
  vanilla's own rows use (checked 2026-09-23).
- `help_pages`, `short_name` and the message templates take the flavour as an argument
  instead of reading module globals.
- `check_hire_units` reads the new `GG.FLAVOURED` shape.

Size: about 100 new DB rows per race; loc from 418 to about 1,250 rows.

## 7. Lua

`zzz_derpy_guilds.lua`: `GG.FLAVOURED` reshaped, `GG.tag` and `GG.feed` added, and the five
key sites in section 5 take the tag. Existing Chaos Dwarf behaviour is byte-identical in key
output.

`zzz_derpy_guilds_ai.lua`: the hostile-service ("hit") message takes the receiver's tag and
feed index.

`zzz_derpy_guilds_ui.lua`:
- `GGUI.loc` appends the local player's tag.
- `GGUI.GUILD_ICON` and `GGUI.PANEL_BG` become two helpers that build
  `ui/campaign ui/derpy_gg_icons/<guild><tag>.png` and
  `ui/campaign ui/derpy_gg_bg/<guild><tag>.png` (5 call sites).
- The crest beside the title (`gg_crest`) and the HUD opener's icon are repainted with
  `SetImagePath("ui/campaign ui/derpy_gg_icons/crest<tag>.png", 0)`. Both are fixed layers
  in the `.twui.xml` today and both have an image slot.

## 8. Art

### 8a. Icons

`tools/make_guild_icons.py`: the `ICONS` map grows; the transform does not change. It gains an
assertion that each source is a flat single-colour silhouette, because a few CA icons are
textured and would flatten into blobs.

| Output | Empire source | Dwarf source |
|---|---|---|
| brass | empire_port | dwarf_trade_depot |
| immortals | empire_barracks | dwarf_barracks |
| daemonsmiths | empire_gunnery_school | dwarf_engineering |
| khanate | empire_tavern | dwarf_rangers |
| overseers | empire_walls | dwarf_industry |
| slavers | empire_shooting_range | dwf_underdeep_grudges |
| crest | empire_imperial_cult | dwarf_hall_of_oaths |

All from `ui/buildings/icons/` in CA's ui packs, read offline (zstd behind a `u32` prefix).

### 8b. Grounds

`tools/make_guild_backgrounds.py` gains a second kind of source: a CA pack path plus a
native-resolution box. For each race the source is the loading-screen painting
(`ui/loading_ui/load_images/campaign_empire1.png` / `campaign_dwarfs1.png` in `ui.pack`,
1920x1200, about 1560x900 of painting inside a foliage frame). Six boxes per race, each
centred on a different part of the painting, all kept inside the frame. Paging between guilds
pans across one picture. The boxes are chosen by rendering the six and looking, then written
into the tool.

Each ground then goes through the existing pipeline unchanged: cover-crop to 790x700, then
multiply down until it measures what CA's `tier_01` ground measures under the scrim (p99
luminance 34, peak 131). `--check` re-measures all 18 shipped files.

About 640KB per ground, so 12 new grounds add roughly 7.7MB to the pack.

## 9. Checks and tests

### 9a. Harness (`tools/_guilds_harness.lua`), each watched fail first

- `GG.tag`: Chaos Dwarfs `""`, Empire `"_emp"`, Dwarfs `"_dwf"`, Lizardmen `""`,
  unreadable culture `""`.
- Empire rank-up applies `derpy_gg_rank_brass_3_emp` and removes only the `_emp` versions of
  the other ranks; `assert_ranks` the same.
- Lead bundle per culture; service bundle carries the buyer's tag, including the hostile one
  on a target of another culture; bounty key tagged, and `bounty_done` matches it.
- Message stems and feed index per receiver (5011+ Empire, 5021+ Dwarfs), including the AI
  file's hit message.
- UI: an Empire player's `GGUI.loc("guild_brass")` asks for `derpy_gg_guild_brass_emp`;
  icon, ground and crest paths carry the tag.
- Every existing Chaos Dwarf test passes without being edited.

### 9b. Generator `--check`, refusing on any finding

- The loc key set is identical under all three tags.
- Every tagged bundle has exactly the effect rows of its Chaos Dwarf twin.
- Guild names 22 characters or fewer; rank names fit the Standings row.
- `check_titles`, `check_help_pages` (21 lines) and `check_ui_loc_keys` run per tag.
- Feed indexes mirror the Lua per tag; `check_feed_images` covers the new rows.
- No duplicate keys across tags.
- No `_emp` or `_dwf` loc row contains a Chaos Dwarf-only word (Hashut, Zharr, Dark Lands,
  slave, Hobgoblin, Infernal, Daemon).
- Every art path the Lua can build exists in the pack; grounds pass the brightness gate;
  icons pass the flatness assertion.

### 9c. Offline look

`tools/preview_guilds_panel.py --flavour emp|dwf` renders each race's panel with the game
shut, for a look at names, icons and ground before packing.

### 9d. In game (owed after packing)

Start an Empire and a Dwarf campaign. Check the panel names, a rank-up message and its
picture, the Faction Effects title of a rank bundle, and a bounty's title and picture.

## 10. Build order

1. Generator: `FLAVOURS`, per-tag emission, checks.
2. Model Lua: `GG.FLAVOURED` reshape, `GG.tag`, `GG.feed`, the key sites (harness first).
3. Panel Lua: `GGUI.loc`, the art helpers, the crest and opener repaint (harness first).
4. Art tools: icons, then grounds.
5. `gen_guilds_ui.py --check`, preview per race, `import_great_guilds.py`, content-verify.

## 11. Risks

- **Help page 2 overflow** under the longer Empire names. Caught by `check_help_pages`; fixed
  by rewording.
- **Hidden hardcoded Chaos Dwarf words** in generated text that section 4d missed. Caught by
  the word check in 9b.
- **The pack is not deployed yet** at the time of writing: build 99A25F5C (tech-key fix)
  still waits for the game to be closed. This work builds on top of it.
