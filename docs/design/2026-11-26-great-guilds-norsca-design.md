# The Great Guilds: Norsca as the warrior cults of the North (an eleventh race) - design

**Status:** a draft for the author's review, written 2026-11-26 from the scoping record's
§2.1 ruling. Every ruling below is a proposal with its reason, and none of them has been shown
to the author yet. Not built. §15 lists the rulings that need sign-off.

**Builds on:**
- `2026-11-26-great-guilds-tomb-kings-norsca-scoping.md` §2 and §2.1, the author's ruling:
  warrior cults and roles;
- `2026-10-12-great-guilds-warriors-of-chaos-design.md`, the last race added, and its §13
  (Norsca's starting facts; one of them is corrected in §3.3 here);
- `2026-10-05-great-guilds-skaven-design.md`, the recipe both races follow;
- `2026-10-04-great-guilds-temple-guild-design.md` and `2026-10-09-great-guilds-temple-lore-design.md`;
- `docs/sessions/HANDOFF_20261005_GUILDS_SKAVEN.md` "Adding a tenth race: every declaration
  point" and `docs/sessions/HANDOFF_20261012_GUILDS_WARRIORS_OF_CHAOS.md` "Adding an eleventh
  race".

**How it was checked.** RPFM was not used, because another agent shared the session. Every DB
key here was read offline out of the 9.0 `db.pack` with `tools/read_vanilla_db.py`, every loc
line out of CA's `text/db/*.loc` with `tools/read_vanilla_loc.py`, every script fact out of
`Modding Files/reference/ca_scripts_wh3/`, and every API call with
`py tools/check_lua_api.py --explain`. Lexicanum refused every request (HTTP 402 and a Cloudflare
403), so the lore rests on CA's own loc wherever CA says it, and otherwise on the Warhammer
Fantasy wiki (Fandom), which is flagged as a fan wiki in §12 each time.

## 1. What and why

Norsca joins the Great Guilds. Since dlc20 the culture `wh_dlc08_nor_norsca` holds the Norse,
the Kurgan (Dolgan, Kul, Tong, Yusak, Kuj, Avags) and the Hung (Aghol, Mung). CA's own loading
screen calls them all one people: "All are depraved Northmen, corrupted by the Dark Gods"
(`loading_screen_quotes_description_wh3_main_lore_16`). So every name and sentence here has to
read right for Sayl, who leads the Dolgan, as well as for Wulfrik and Throgg.

| Decision | Proposed ruling |
|---|---|
| Scope | Full parity with the other ten races in ONE build, the Skaven recipe: seven guilds, frame, art, building words, temple routes and lore, halls, race services, earn route, twist |
| Tag and culture | `_nor`, `wh_dlc08_nor_norsca` (subculture `wh_dlc08_sc_nor_norsca`). Playable: Wulfrik `wh_dlc08_nor_norsca`, Throgg `wh_dlc08_nor_wintertooth`, Sayl `wh3_dlc27_nor_sayl` |
| Placement | `_nor` goes before `_gen` in `FLAVOURS`, so `_gen` stays last |
| Feed offset | 120 (5121-5126). Tomb Kings is the other race scoped on 2026-11-26 and will most likely take 110, so 120 leaves that slot free whichever race ships first. Vanilla's 249 criteria values run -1 to 1978, so 5121-5126 are free |
| Words | No word pass. The panel keeps "The Great Guilds", the tab "Guilds", and Reputation and Favour stay as they are (§2.3) |
| Rivals | The global pairs, which already fit Norsca. No `GG.RIVALS_RACE` entry (§2.2) |
| Temple | One guild for all four gods. It pays for the altars of the faction's most-favoured god, which is new code (§3.3) |

**Not in scope:**
- **Trophies** (`wh3_dlc27_nor_trophies`). The pool is dead in 9.0: it has no factor junction,
  appears in no payload table and no CA script, carries the placeholder description "Trophies -
  gained from Monster Hunts", and is only seeded at 0. CA pays monster hunts in Spoils instead,
  so this design does too (§3.2).
- Throgg's Kinfolk pool (`wh3_dlc27_nor_kinfolk`). It belongs to one lord, and the guilds pay by
  culture.
- The seven Norse tribes as guilds. The author turned that down (scoping §2.1). Tribe names
  appear only as flavour, and only where the lore supports them.
- Generalising the per-race lists, and the public GitHub repo sync.

## 2. Identity

Sentences are built as "the {name}", so every name starts with "The " and the prose reads "the
Reavers", "the Four".

| Key | Earns from (unchanged) | Rival | Name on the card | Length |
|---|---|---|---|---|
| slavers | sacking and razing | overseers | The Reavers | 11 |
| immortals | battles won | daemonsmiths | The Berserkers | 14 |
| daemonsmiths | technologies | immortals | The Shaman-Sorcerers | 20 |
| khanate | hero actions | brass | The Skin Wolves | 15 |
| temple | faith | none | The Four | 8 |
| brass | income | khanate | The Monster Hunters | 19 |
| overseers | buildings, growth | slavers | The Thralls | 11 |

Every name is within `GUILD_NAME_MAX` 22.

- **The Reavers, not "the longship reavers".** A Kurgan raids on horseback, so "longship" would
  read wrong for Sayl. "Reaver" is CA's own Norscan word (`wh3_dlc27_anc_follower_nor_infamous_reaver`,
  "Infamous Reaver").
- **The Berserkers** stand for the soldiers, the Marauder Champions included. "The Berserkers and
  Marauder Champions" is 37 characters.
- **The Thralls**, as the author ruled. The guild is the captives themselves, set to work, which
  is also what makes the Reavers their natural rival. If a guild of captives reads oddly as
  something the player "deals with", the fallback is "The Thrall-Masters" (18), a guild of the
  men who drive them. This draft keeps the author's name.
- **The Four**, not a god's name, because the temple is one guild for all four gods (§3.3). The
  prose names them as CA does: the Hound, the Eagle, the Serpent and the Crow
  (`building_flavour_texts_flavour_wh_main_nor_monoliths`). "The Four Brothers" (16), from the
  same CA line ("the four brothers in darkness"), is the alternative.

**Ranks:** Bondsman, Marauder, Huskarl, Chieftain, Champion. All are within `RANK_NAME_MAX` 12.
"Huskarl" is CA's spelling (`wh_dlc08_anc_armour_huskarl_plates`); "Marauder" and "Chieftain" are
CA's unit and lord words for every Northman. "Bondsman" comes only from the fan wiki's summary of
*Tome of Corruption* (§12). "Thrall" is not used as a rank, because it is the builders' name and
the Warriors of Chaos already open with it. The Skaven also use "Chieftain"; a shared rank word
is harmless.

**Hire unit** (`GG.HIRE_UNIT_BY_CULTURE`): Marauder Champions (Great Weapons),
`wh_dlc08_nor_inf_marauder_champions_1`, tier 3 at 1,100, the culture's elite infantry.

### 2.1 The twist, "Boasts"

`GG.TWISTS["wh_dlc08_nor_norsca"] = {rate_bounty_fail = 200, demand_reward = 150}`. A failed
bounty costs twice the usual Reputation, and a demand that is met pays half again as much. CA's
own line for Wulfrik's curse is the basis: "Beware drunken boasts made in sight of the Dark Gods,
lest they hold you to such claims" (`character_skills_localised_description_wh_dlc08_skill_nor_wulfrik_unique_eternal_challenger`).
Both dials exist. No race uses `rate_bounty_fail` 200 (the Dwarfs use 150), so the pair is
distinct from all ten. The alternatives considered were `rate_rivalry` 200 (the tribes feud) and
`favour_cap` 50 (raiders spend what they take); both read as weaker fits for a culture whose
sagas run on boasts.

### 2.2 Rival pairs

The global pairs already describe Norsca, so no per-race table is needed:

- **The Reavers and the Thralls.** The Reavers carry off the captives the Thralls once were, and
  the Thralls need hands at home where the Reavers want warriors on the move. This matches the
  comment on `GG.RIVALS` itself.
- **The Berserkers and the Shaman-Sorcerers.** Warriors who trust their axes, against seers who
  claim to steer the tribe to war (CA: "Using his seer-craft, the Shaman-Sorcerer wrangles the
  Winds to guide the tribe towards war").
- **The Monster Hunters and the Skin Wolves.** Hunters who bring back the heads of beasts, against
  men who become beasts.

These pairings are rulings, not lore, and §12 records them that way.

### 2.3 Words

No word pass. The Warriors of Chaos renamed the panel and swapped Reputation for Devotion through
`CHS_WORDS`, and the final review then had to fix 47 titles that pass made ungrammatical. Norsca
gains nothing to set against that cost: no single noun covers berserkers, seers, monster hunters
and captives the way "the gods" covered the Warriors of Chaos. The Skaven kept the shared words
for the same reason. If the author wants one change, the panel title alone can be overridden
per flavour without touching any other string (for example "The Warrior Cults"); that is
offered, not proposed.

## 3. Earning

### 3.1 Shared routes (no code change)

Income pays the Monster Hunters, battles won the Berserkers, technologies the Shaman-Sorcerers
(Norsca has one tree, `nor_mil`, of 87 nodes), hero actions the Skin Wolves, sacking and razing
the Reavers, buildings and growth the Thralls, and missions every guild.

### 3.2 Race earn route, "Spoils"

Spoils (`wh3_dlc27_nor_spoils`) is Norsca's own currency. CA: "Spoils are required to occupy
non-Norscan regions ... Spoils are primarily gained by using the Pillage post-battle option to
raze defeated settlements" (`pooled_resources_description_wh3_dlc27_nor_spoils`). Its campaign
group `wh_dlc08_feature_norsca` takes every faction in the subculture (`wh_feature_norsca`), so
the Kurgan and the Hung hold it too.

Its factor junctions in 9.0:

| Factor | Sign | Who writes it |
|---|---|---|
| `wh3_dlc27_nor_spoils_instant_razing` | 0 or more | Pillage: the occupation decision's own transaction, and CA's `nor_pillaging:transfer_spoils_to_faction` when the pillaging force delivers |
| `wh3_dlc27_nor_spoils_monstrous_arcanum` | 0 or more | `wh_dlc08_monster_hunt.lua`: 200 per hunt stage by default; some hunts override a stage (100 and 300 are both used) |
| `events` | either | CA's victory payload (5,000) |
| `buildings`, `wh3_dlc27_treacheries` | either | buildings; Sayl's treacheries |
| `marauding_activities`, `settlements_captured`, `technology` | 0 or less | spending |

**Proposed:** Spoils from the Monstrous Arcanum pay the Monster Hunters **1 Reputation per 25
Spoils**, by the point with a carry, like the Warriors of Chaos' Gifts. A 200-Spoils hunt stage
pays 8.

```lua
GG.EARN_ROUTES.spoils = {guild = "brass", per = 25}
GG.EARN_OF["wh_dlc08_nor_norsca"] = "spoils"
GG.POOL_ROUTES.wh3_dlc27_nor_spoils = "spoils"
-- in GG.pool_route_counts:
if route == "spoils" then return factor == "wh3_dlc27_nor_spoils_monstrous_arcanum" end
```

**Pillage, and why the Reavers are not on this route by default.** CA's Pillage is an
occupation decision of type `occupation_decision_raze_without_occupy` (ids 1922893679 in
`wh_dlc08_occupation_decision_norsca` and 1924306848 in Sayl's group). That is the same type as
an ordinary raze. If `CharacterRazedSettlement` fires for it, the Reavers are already paid by the
shared raze route, and counting `instant_razing` as well would pay them twice for one act. Whether
it fires is not something any doc or CA script answers; it is in-game check 1 (§10). The rule:

- **If the raze event fires for Pillage** (the default this draft assumes), the route above is the
  whole of it. Spoils pays only the Monster Hunters.
- **If it does not**, the Reavers earn from `instant_razing` at the same rate. That needs a factor
  to name its guild, since today a pool names one guild: a new `GG.FACTOR_GUILD =
  {wh3_dlc27_nor_spoils_instant_razing = "slavers", wh3_dlc27_nor_spoils_monstrous_arcanum = "brass"}`,
  the route becomes `{per = 25, by_pool = true}` so each guild keeps its own remainder, and the
  listener passes `GG.POOL_GUILD[key] or GG.FACTOR_GUILD[factor]`. One line in the listener and one
  table, built only if the check says so.

Ledger source `spoils`; no MCT rate, like every race earn route. The mod's own Spoils grant (the
tithe, §5) uses factor `events`, which the route does not count, and `take_self` covers it as for
every other pool.

### 3.3 The Four's routes (temple), and how one guild serves four feuding gods

**Devotion sits beside CA's allegiance pools, not on them.** The Warriors of Chaos spec (§13)
recorded that `nor_progress_hound/eagle/serpent/crow` take the `buildings` factor and proposed
building on them. Reading CA's script overturns that. `wh_dlc08_norscan_gods.lua` rewrites each
pool every `FactionAboutToStartTurn`, first adding -99,999 and then adding
`cm:get_factions_bonus_value(faction, "nor_progress_<god>_count")`, and does so only for Wulfrik
and Throgg (`allegiance_factions`). The pools have a maximum of 15 and reset before income. So a
pool is a level, rewritten every turn, and not a flow; a `PooledResourceChanged` route on it would
see two large false changes every turn. The bonus value behind it is the honest figure: it comes
from `wh3_dlc27_pooled_resource_nor_progress_<god>_buildings` at `building_to_faction_own` value 1,
which sits on every level of every settlement altar chain of that god
(`wh3_dlc27_settlement_nor_chaos_altar_{kho,nur,sla,tze}` and their `_special_gate` and
`_special_port` variants, the captured-human-city levels included).

**Proposed routes:**

| Route | Rule |
|---|---|
| Altars (new, §4.1) | At turn start, `rate_temple_altar` (new MCT key, default 2) per altar settlement of the faction's **most-favoured god**, plus every Undivided altar |
| Holy war | Won battles against `wh_main_emp_empire`, `wh3_main_ksl_kislev`, `wh_main_brt_bretonnia` and `wh3_main_cth_cathay`, at `rate_temple_holy` |
| Priests | Kihar (`wh_dlc08_nor_kihar`) and Killgore Slaymaim (`wh3_main_ie_nor_killgore_slaymaim`), CA's own allegiance champions in `wh_dlc08_norscan_gods.lua`, pay the Four for their actions instead of the Skin Wolves |
| Devout, clean, taint | Not used |

**Why the most-favoured god.** CA's own text: "It is the goal of all Northmen to gain the
attention of one of these Ruinous Masters, worshipping a single deity above all others"
(`building_flavour_texts_flavour_wh_main_nor_monoliths`). A faction with five Hound altars and
two Serpent altars is paid for five. Raising altars to rival gods earns the Four nothing extra,
and CA's own champion invasions (`rivalry_conversion_table`: Hound against Serpent, Crow against
Eagle) already punish it. So the guild stays one temple while the gods' feud shapes what it
pays. The alternative, which needs sign-off if preferred, subtracts the rival god's altars from
each god's count before taking the largest.

**Undivided altars** (`wh3_dlc27_settlement_nor_chaos_altar_und*`, in all three sets) carry no
allegiance bonus value. They are counted on their own and added, so Sayl, whose set raises only
Undivided altars, earns from this route like Wulfrik and Throgg.

**Why not the taint route.** Paying per province carrying Chaos corruption would cost no new
code, but it repeats the Warriors of Chaos' temple, and it ignores the Four, which the scoping
record names as the temple's whole basis.

**Holy war targets.** CA's loc names the Empire and Bretonnia as the Norse raiders' prey ("Each
raid along the coasts of the Empire and Bretonnia", `building_flavour_texts_flavour_wh_main_nor_slaves_3`)
and Cathay's Great Bastion as the Kurgan and Hung's wall (`loading_screen_quotes_description_wh3_main_lore_16`).
Kislev is a ruling rather than a quotation: it stands between the North and the Empire, and the
Warriors of Chaos' holy-war list already names it. High Elves are a candidate the author may add;
this draft leaves them out.

**Priest candidates.** Styrkaar the Sortsvinaer (`wh3_dlc27_sla_styrkaar_the_sortsvinaer`) and
Scyla Anfingrimm (`wh3_dlc26_kho_scyla_anfingrimm`) are also god-marked heroes Norsca can field.
They are left on the Skin Wolves' route unless the author adds them.

### 3.4 Hero actions

`GG.on_agent_action` pays the spies for every successful hero action unless the subtype is one
of the temple's priests. Norsca's heroes (from `faction_agent_permitted_subtypes`):

| Hero | Subtype | Pays |
|---|---|---|
| Skin Wolf Werekin | `wh_dlc08_nor_skin_wolf_werekin` | the Skin Wolves |
| Shaman-Sorcerers | `wh_dlc08_nor_shaman_sorcerer_death`, `_fire`, `_metal` | the Skin Wolves |
| Fimir Balefiends, Fimir Noble | `wh_dlc08_nor_fimir_balefiend_fire`, `_shadow`, `wh3_dlc27_nor_fimir_noble` | the Skin Wolves |
| Beorg Bearstruck | `wh3_dlc27_nor_beorg_bearstruck` | the Skin Wolves |
| Kihar, Killgore Slaymaim | as §3.3 | the Four |
| Styrkaar, Scyla, Gutrot Spume | `wh3_dlc27_sla_styrkaar_the_sortsvinaer`, `wh3_dlc26_kho_scyla_anfingrimm`, `wh3_dlc29_chs_gutrot_spume` | the Skin Wolves |

**The Shaman-Sorcerers' actions pay the Skin Wolves**, as every race's scholar heroes pay its
spies: Chaos Dwarf Daemonsmiths pay the Khanate, Skryre Warlock Engineers pay Clan Eshin, marked
Chaos Sorcerers pay the Undoer. The scholars earn from technologies, and recruiting a
Shaman-Sorcerer pays them (§3.5). The alternative, a new per-culture `GG.HERO_GUILD` table that
sends a subtype's actions to the scholars, is new code and needs sign-off. The Great Shamans
(`wh3_dlc27_nor_great_shaman_sorcerer_death`, `_fire`, `_metal`) are lords, so they make no hero
actions at all.

### 3.5 Recruiting (`GG.RECRUIT_ROUTES`, first fit wins)

Keys are matched with `string.find` and no init argument, like every race, and every token is
free of pattern magic. Order matters where one key holds two tokens; the chariot rule goes before
the wolves rule because `wh_dlc08_nor_veh_marauder_warwolves_chariot_0` holds both.

| Order | Token | Units it catches (CA names) | Guild |
|---|---|---|---|
| 1 | `wh3_dlc27_chs_`, `wh3_dlc27_kho_`, `wh3_dlc27_nur_`, `wh3_dlc27_sla_`, `wh3_dlc27_tze_` | the god-marked Chaos Warriors and Spawn that the dlc27 recruitment altars train | the Four |
| 2 | `chariot` | Marauder Chariots, Marauder Ice Wolf Chariots | the Reavers |
| 3 | `horsemen`, `horsemasters` | Marauder Horsemen, Horsemasters, Kurgan Horsemen | the Reavers |
| 4 | `berserkers`, `marauder_champions`, `bearmen`, `chaos_marauders`, `spearman`, `flayerkin` | Berserkers, Champions, Bearmen, Marauders, Spearmen, Flayerkin | the Berserkers |
| 5 | `skinwolves`, `warwolves`, `warhounds` | Skin Wolves, Norscan Ice Wolves, Norscan Warhounds | the Skin Wolves |
| 6 | `hunters`, `fimir`, `manticore`, `chimera`, `frost_wyrm`, `dread_maw`, `giant`, `ettin` | Marauder Hunters and the monsters the hunts bring in | the Monster Hunters |
| 7 | `troll` | Norscan Trolls, Ice Trolls, Throgg's trolls | the Thralls |
| 8 | `mammoth`, `hellcannon` | Feral and War Mammoths; the Ice-Forged Legion | the Shaman-Sorcerers |

Trolls go to the Thralls on CA's own words for them: "those of their kind compliant enough to
build, enforce and serve" (`pooled_resources_description_wh3_dlc27_nor_kinfolk`). Mammoths go to
the Shaman-Sorcerers because CA's chaos chain, the seers' building, is what enables them (§3.6).

Units no rule names pay nothing. In the three Norsca sets, 23 units trained by Norsca's own
buildings lack `_nor_` in their key. The altars' god-marked units take row 1, Throgg's
`wh3_dlc27_throgg_mon_*` trolls take `troll`, and the Ogham Stones' two giants take `giant`.
Flayerkin (`wh3_dlc29_chs_inf_flayerkin`), which CA's own military chain trains, needs one more
Berserkers token, `flayerkin`. That leaves only the Vampire Coast hulks and the Black Ark
Corsairs of the captured foreign ports unpaid. Units that Sayl's treacheries take in other
races' settlements come from those races' sets and were not traced here; `check_recruit_routes`
lists them at plan time, and the author decides whether they stay unpaid or a last rule sends
every foreign recruit to the Skin Wolves.

Characters:

| Token | Guild |
|---|---|
| `kihar`, `killgore`, `styrkaar`, `scyla`, `gutrot` | the Four |
| `shaman_sorcerer` (heroes and Great Shamans), `sayl` | the Shaman-Sorcerers |
| `skin_wolf`, `fimir`, `beorg` | the Skin Wolves |
| `wulfrik`, `marauder_chieftain`, `throgg`, then agent `general` and agent `champion` | the Berserkers |

`check_recruit_routes()` runs the table against the whole vanilla roster. `GG.UPGRADE_PAYS`
gets no entry: Norsca recruits from buildings, not by upgrading.

### 3.6 Buildings (`GG.BUILDING_THEME_RACE["_nor"]`)

The race's chains are in `wh_main_bas_nor` (the race), `wh3_dlc27_nor_sayl` and
`wh3_dlc27_nor_throgg`, 127 chains in all. The prologue set `wh3_main_pro_bas_nor` is not a
campaign faction's set. Chain keys are matched lowercased, so `wh_main_NORSCA_military` is
matched as `wh_main_norsca_military`. Every token below matches at least one chain in those
sets and holds none of `^$()%.[]*+-?`; that was run against the vanilla tables on 2026-11-26.

| Guild | Race tokens | What CA puts in those chains |
|---|---|---|
| the Four | `norsca_worship`, `settlement_nor_chaos_altar` | Ruinous Altar to Vitki Temple; the god altars that settle a captured city |
| the Berserkers | `_recruitment`, `_replenishment`, `outpost_experience`, `special_gate_towers` | the dlc27 altars that train and refill armies; the Tattooist; the gate altar's towers |
| the Shaman-Sorcerers | `norsca_chaos` | Chaos Totem to Shamanic Pyre: Shaman-Sorcerers, research, the Winds |
| the Skin Wolves | `norsca_beasts`, `trap_core_`, `foreign_slot_discovery_nor` | warhounds and Skin Wolves; Sayl's infiltration chains; the foreign-slot discovery chain |
| the Monster Hunters | `norsca_creatures`, `norsca_offerings`, `monster_den` | Fimir, manticores, chimeras, frost wyrms; trolls, giants and Ettins; Throgg's monster den |
| the Reavers | `norsca_loot`, `outpost_income`, `norsca_port`, `nor_port_altar`, `_raiding`, `norsca_stables`, `outpost_stables`, `nor_allied_outpost` | loot and raid income; the Raiding Port and Longship Builder; the raiding altars; horses |
| the Thralls | `norsca_slaves`, `norsca_smith`, `special_throgg_`, `trolls_woods_altar` | Fur Stash to Longhouse Under-Hall; the smithy; Throgg's troll dens |

Two tokens overrule a shared word on lore grounds:
- **The smithy goes to the Thralls, not the Shaman-Sorcerers.** The shared word `smith` would
  send it to the scholars, but CA says the smith is "a slave taken from the southlands and only
  kept alive due to his useful skills" (`building_flavour_texts_flavour_wh_main_nor_smith_1`).
- **The slaves chain goes to the Thralls, not the Reavers.** The shared word `slave` would send it
  to the raiders, but CA's Fur Stash, Beast Tanner and Slaver's Camp are where "any slaves
  observed to be adept at beast tanning or metalwork ... live the short remainder of their
  able-bodied lives doing hard labour" (`building_flavour_texts_flavour_wh_main_nor_slaves_3`).

Garrison, walls, the military chain and the outpost military chain keep the shared words
(Berserkers); settlements and growth keep theirs (Thralls); resources and the foreign ports keep
theirs (Monster Hunters, whose furs and ivory fit).

**Share of building Reputation**, measured the Warriors of Chaos way (each level of each chain
pays its tier, DB level + 1, to `guild_of_chain(chain, "_nor")`, else to the default; halls
left out), 759 points in all:

| Guild | Shared words only | With the race words |
|---|---|---|
| the Berserkers | 20% | 27% |
| the Thralls (named) | 40% | 22% |
| the default (the Thralls) | 26% | 6% |
| the Four | 0% | 17% |
| the Monster Hunters | 11% | 14% |
| the Reavers | 1% | 10% |
| the Skin Wolves | 0% | 3% |
| the Shaman-Sorcerers | 1% | 1% |

The 6% default is landmarks (`wh3_dlc27_nor_special_*`, the foreign wonders) that share no word
with anything. The Shaman-Sorcerers' 1% is a balance question for the author, not a bug: their
route is technologies, and the Skin Wolves' is hero actions, which is the same shape as the
Warriors of Chaos' Changer of Ways at 2%.

## 4. New code paths

Each is pcall-wrapped like every listener, and gets a harness case and a mutant.

1. **The altars route.** A new `altars = true` field in `GG.TEMPLE_ROUTES`, read by a new
   function that walks the faction's regions once:

   ```lua
   GG.ALTAR_GODS = {"settlement_nor_chaos_altar_kho", "settlement_nor_chaos_altar_nur",
                    "settlement_nor_chaos_altar_sla", "settlement_nor_chaos_altar_tze"}
   function GG.temple_altars(f)
       local count, und = {0, 0, 0, 0}, 0
       local rl = f:region_list()
       for i = 0, rl:num_items() - 1 do
           local chain = string.lower(rl:item_at(i):settlement():primary_building_chain())
           if string.find(chain, "settlement_nor_chaos_altar_und") then
               und = und + 1
           else
               for g = 1, 4 do
                   if string.find(chain, GG.ALTAR_GODS[g]) then count[g] = count[g] + 1 end
               end
           end
       end
       return math.max(count[1], count[2], count[3], count[4]) + und
   end
   ```

   `faction:region_list()` and `settlement:primary_building_chain()` are both documented, and CA
   tests the same chain names with `string.find` in its own scripts. Two-argument `string.find`
   only: the plain flag is banned in this file (it corrupts the string library process-wide), and
   the tokens carry no pattern magic. The region walk is used instead of CA's four bonus values
   because it also sees the Undivided altars, which have none, and because it reads one thing for
   all three lords. `GG.temple_turn` grants `altars * rate_temple_altar` through
   `GG.capped_grant` with ledger source `altars`; its early-return guard and the turn-start
   preview in `GG.turn_start_pay` both gain the new term. The generator's `TEMPLE_ROUTES` mirror
   and the lua.exe block comparison follow.
2. **`rate_temple_altar`.** A new MCT key: `TUNE_DEFAULTS` (2), `TUNE_ORDER` (appended), the four
   presets, the MCT row, `PRESET_OWNED`, `TEMPLE_RATE_KEYS`. Reusing `rate_temple_taint` would
   skip all six declaration points, but its MCT label says corruption, which would be wrong for
   Norsca; this draft does not reuse it.
3. **Possibly `GG.FACTOR_GUILD`**, only if in-game check 1 says Pillage escapes the raze event
   (§3.2).

Nothing else is new. Rivals, demands, upgrades and recruiting all reuse existing paths.

## 5. Race services

Three, priced by `RACE_PRICE` (50/150/400 Favour, cooldowns 8/12/16, rank 4 `lead`), appended
after the last race's rows because cooldowns are saved by position. The Warriors of Chaos hold
rows 96-98, so these are 99-101 if Norsca ships before Tomb Kings and 102-104 if after. The
harness pin moves to "Norsca rows last" in whichever build is second.

| Rank | Guild | Key | Name | Effect |
|---|---|---|---|---|
| 2 | the Reavers | `spoils_tithe` | Tithe of Spoils | adds 200 Spoils (`wh3_dlc27_nor_spoils`), through factor `events` |
| 3 | the Skin Wolves | `wolf_kin` | The Wolf-Kin | `race_army`, `room = True`: a unit of Skin Wolves (`wh_dlc08_nor_mon_skinwolves_0`) and one of Norscan Ice Wolves (`wh_dlc08_nor_mon_warwolves_0`) join the army you select, if there is room |
| 4 | the Monster Hunters | `great_hunt` | The Great Hunt | bundle, lead, 10 turns: `wh2_dlc09_effect_force_stat_melee_attack_monsters` at `faction_to_force_own`, +10 |

- **Tithe of Spoils.** `events` is junctioned to Spoils in both directions and is the factor CA's
  own victory payload uses, so a script grant lands; `missions`, the Chaos Dwarf trap, has no
  Spoils junction at all. 200 is CA's default per-stage hunt payload (`global_resource_rewards`
  in `wh_dlc08_monster_hunt.lua`). It is the Skaven's Food Tithe and the Warriors of Chaos'
  Tithe of Souls in shape. The shared `slave_tithe` keeps paying Norsca 3,000 gold, as it does
  every race without its own branch; Norsca's tithe is this race service instead.
- **The Wolf-Kin** fires down the same path as the Skaven's Shadows of Eshin. Both keys are in
  `main_units` (950 and 625).
- **The Great Hunt.** CA's text for the effect is "Melee attack: %+n for Monster units". Vanilla
  pairs it with `faction_to_force_own` at 8 and 15, so +10 sits inside the range. There is no
  generic army-wide bonus-vs-large effect at any army scope in vanilla:
  `wh3_dlc29_effect_force_stat_bonus_vs_large` and
  `wh3_dlc27_effect_force_stat_bonus_vs_large_monsters_lords_heroes` exist but no junction table
  uses either, so neither is proven to work. Whether this effect's unit set reaches Norsca's
  monsters is plan-time check 6.

## 6. The Four by their own lore (temple lore)

| Field | Proposal | Pair, read from 9.0 `db.pack` |
|---|---|---|
| Rank | Leadership for every army, the flat ladder 2/4/6/8, lead 5 | `wh_main_effect_force_stat_leadership`, `faction_to_force_own` (vanilla 1 to 20); Kislev's and the generic shape |
| Hall | Chaos corruption +2/+4/+6 in the settlement | `wh3_main_effect_corruption_chaos_buildings`, `region_to_region_own` (vanilla 1 to 15). CA's own worship chain puts the same effect at 2/4/6 |
| Seat | Chaos corruption +2 in every province | `wh3_main_effect_corruption_chaos_events`, `faction_to_province_own`, the Warriors of Chaos' seat |
| `hashut_blessing` | +10% ward save for the army you select | `wh_main_effect_force_stat_ward_save`, `force_to_force_own` |
| `zeal` | unchanged | |
| `holy_war` | +4 melee attack and +6 leadership in all your armies; the text names the Empire, Kislev, Bretonnia and Cathay | the Warriors of Chaos' pair |

Leadership is the ladder because Norsca's faith is a warrior's faith with no priestly order;
the fan wiki has the Norscans looking to Khorne "for strength" in battle (§12). The Winds ladder
would suit the Shaman-Sorcerers, but they are the scholars here, not the Four's priests.

**Purge the Unclean and Consecration take the `""` override for `_nor`** (public order only), and
`RACE_UNWANTED_EFFECTS["_nor"]` gains `wh3_main_effect_corruption_reduction_events`. The measured
reason: CA's own Norscan commandment, `wh3_main_ie_edict_nor_corruption`, raises Chaos corruption
by 3 on purpose, so a service that lowers it works against CA's design for the race. The loop at
`gen_great_guilds.py` line 698 gains `_nor`.

## 7. Halls

Norsca joins `HALL_TAGS` / `GG.HALL_TAGS` and `HALL_RACES["_nor"]`:
- **`set`:** `wh_main_bas_nor`. **`extra_sets`:** `wh3_dlc27_nor_sayl`, `wh3_dlc27_nor_throgg`.
- **Nouns:** Lodge / Longhouse / Great Hall.
- **Temple nouns:** Totem of the Four / Altar of the Four / Monolith of the Four. "Chaos Totem",
  "Ruinous Altar" and "Monolith" are all CA's own Norscan building words.
- **Settlement types and `where`:** decided at plan time (check 9). A settlement altar has two
  levels (three at a special gate), and a hall's first level needs the main building at level
  2, so the altar settlements may be too small, as the Warriors of Chaos' Chaos Altars were.

| Guild | Hall unit | Note |
|---|---|---|
| the Monster Hunters | Marauder Hunters (Javelins), `wh_dlc08_nor_inf_marauder_hunters_1` | CA: "The Hunter's javelin takes down the largest of wild beasts, and the most gargantuan of foes" |
| the Berserkers | Marauder Berserkers, `wh_dlc08_nor_inf_marauder_berserkers_0` | |
| the Shaman-Sorcerers | none | `HALL_EXTRA`: `wh_dlc08_effect_agent_cap_increase_wizard`, `faction_to_faction_own_unseen`, 1/2/3, "Shaman-Sorcerers you may recruit +%d". CA's own chaos chain uses this pair at 1 and 2. The Empire College's hall is the precedent for a faction-wide cap on a hall |
| the Skin Wolves | Skin Wolves, `wh_dlc08_nor_mon_skinwolves_0` | |
| the Thralls | none | Lore over coverage: CA has no thrall unit. The hall keeps the builders' shared effect, construction cost down in the province |
| the Reavers | Marauders, `wh_main_nor_inf_chaos_marauders_0` | the raiders on foot and on every coast; horsemen would read as Kurgan only |
| the Four | none | §6's hall effect |

Unitless non-temple halls already ship (all seven of the Warriors of Chaos'), so the Thralls and
the Shaman-Sorcerers need no new code. Each unit's `_unit_level` in the three sets and its
content pack (Norsca is itself DLC; `HALL_FALLBACK` and `check_halls` decide whether a stand-in is
needed) are plan-time check 4.

## 8. Panel, art and text

- **Frame.** `FRAMES["_nor"]` / `GGUI.FRAME["_nor"]`. CA's Norsca skin
  (`ui/skins/wh_dlc08_nor_norsca/`, in `ui2.pack`) has `bar_small_central_left.png` and
  `bar_small_buttons.png`, the same two files the Warriors of Chaos took from their own skin for
  the rank strip and the god bar. It has no card plate, tab or rim. Those come from a Norscan
  panel: CA's Monstrous Arcanum (`ui/skins/default/dlc27_monster_arcanum/`, 34 files plus 58 monster
  arts) first, its allegiance panel (`ui/skins/default/dlc27_nor_allegiance/`, 13 files) second.
  Briefed against the Monstrous Arcanum panel and a reference screenshot, per `docs/CUSTOM_UI.md`
  "Design direction", every plate measured with PIL before it is picked. `RANK_STATS_PAD["_nor"]`
  is decided by the preview.
- **Grounds.** One CA painting, `ui/loading_ui/load_images/campaign_norsca1.png` in `ui.pack`,
  1920x1080, read offline. It shows a dragon-prowed longship, a Chaos champion aboard it, a Skin
  Wolf charging out of the smoke and a shield-bearing Marauder behind it. All seven windows fit
  inside 1080 rows. A rendered sheet of the seven proposes:

  | Window | What it shows | Guild |
  |---|---|---|
  | 1 | the longship's prow and the champion aboard | the Reavers |
  | 4 | the longship's hull; thralls build the longships (§12) | the Thralls |
  | 2 | the Skin Wolf against the burning sky | the Skin Wolves |
  | 6 | the Marauder with his shield | the Berserkers |
  | 3 | the wolf and the Marauder under the pale sun | the Shaman-Sorcerers |
  | 5 | the wolf, close | the Monster Hunters |
  | 7 | the wolf and the champion together | the Four |

  Five windows share the wolf, so the pages will look alike; that is the cost of one painting.
  CA ships no other Norsca loading screen and no Sayl one, so there is nothing to lend.
- **Crests and hall icons.** CA's Norsca building icons (`ui/buildings/icons/nor_*` and
  `wh3_dlc27_nor_*`, 70 files) give a candidate per guild: `nor_loot_plunder` or `nor_port` (the
  Reavers), `nor_marauders` (the Berserkers), `nor_effigys_of_chaos` (the Shaman-Sorcerers),
  `nor_beast_packs` (the Skin Wolves), `nor_creatures_of_chaos` (the Monster Hunters), `nor_slaves`
  (the Thralls), `nor_chaos_worship` (the Four). Each must be measured as a flat silhouette
  before it is picked. Not `wh3_dlc27_nor_trap_core_sabotage`: the Warriors of Chaos' Undoer
  already uses it. `TAB_FRAME["_nor"]` = `nor_cat_recruitment`, which exists.
- **Event pictures.** `pics = "nor"`. All four feed pictures the generator draws
  (`civilisation_down`, `messenger`, `diplomacy`, `civilisation_up`) and the mission picture
  `nor/generic` are used by vanilla rows (`event_feed_message_events`; 97 vanilla missions use
  `nor/*`), which is the bar `check_feed_images` sets.
- **Text.** Every family the other ten carry, in CA's voice and plain words: names,
  descriptions, ranks, the 63 shared and 3 race service names and blurbs, §6's three temple
  services, bounties, feed messages, the Help pages (the halls page, the Spoils route, the altars
  route, Boasts), the ledger sources `spoils` and `altars`, and `GGUI.MCT_NAMES["_nor"]`. The
  words in `CHD_ONLY_WORDS` stay out, "slave" and "Daemon" included, so the Thralls are
  "captives" and "thralls" in every line and `FLAVOUR_WORDS_ALLOWED` needs no entry.
  Proposed guild descriptions (the flavour half; the earning half follows the shared pattern):

  | Guild | Description |
  |---|---|
  | the Reavers | Raiders who fall on the lands to the south and carry off everything worth taking, captives first. |
  | the Berserkers | Warriors who fight in a red frenzy, without armour and without fear, until nothing is left standing. |
  | the Shaman-Sorcerers | Seers who read the Winds of Magic and steer the tribes towards war. |
  | the Skin Wolves | Fallen champions who tear free of their own skins as wolves. The tribes fear them, and use them all the same. |
  | the Four | The Hound, the Eagle, the Serpent and the Crow. Every Northman hopes to catch the eye of one of them. |
  | the Monster Hunters | Hunters of the Monstrous Arcanum, who come home with hides, horns and heads. |
  | the Thralls | Captives carried home from the raids and worked until they drop. What the North builds, thralls build. |

  None of them promises a mechanic. Sayl reads them as naturally as Wulfrik: nothing says
  "longship", "Norse" or a tribe name.
- **Previews:** a guild page, the Four's page, the Leaderboard, the Court and Help, rendered from
  the shipped Lua (`GG_DUMP_TAG=_nor`) and compared with the reference. Contrast and fit green.

## 9. Save safety, AI and MCT

- A campaign already running with a Norsca human starts its Norsca factions at 0 in every guild,
  the path `GG.load` takes for any new faction.
- Nothing stored changes shape. The altars route is code; `rate_temple_altar` is a new setting
  with a default, so an old save reads the default.
- `_gen` stays last, so `GG.GENERIC` (30) and every existing feed slot are unchanged.
- AI Norsca factions earn only when a Norsca human plays (`GG.covered`). The temple turn runs for
  AI factions too, as it does for every race.
- One new MCT key, `rate_temple_altar` (§4.2).

## 10. Tests

Nothing ships until all are green.

- **Generator `--check` and `--selftest`.**
  - Every ten-race pin moves to eleven (or twelve after Tomb Kings); each is counted, not
    loosened: the race-service count, the `FLAVOURS` order, the (tag, set) tuple, the DLC-tag
    tuple, the hall-set count.
  - Every mirror gains `_nor`: `check_race_mirror`, `check_hire_units`, `check_frame_mirror`,
    `check_hall_mirror`, `check_temple_routes` (with the `altars` field), `check_flavour_mirror`,
    `check_mct_names`, `check_recruit_routes`.
  - Every new key is read from `db.pack` (`check_live_references`); the race words match
    Norsca chains only (`check_building_theme`).
- **`_guilds_harness.lua`:**
  - the altars route pays the most-favoured god's count plus the Undivided altars, and nothing
    for a faction with no altar; a faction with altars to two rival gods is paid for the larger
    count only;
  - Spoils from `monstrous_arcanum` pay the Monster Hunters per 25 with a carry, and Spoils from
    `events`, `buildings` and `instant_razing` pay nothing (or, under the `FACTOR_GUILD` branch,
    `instant_razing` pays the Reavers);
  - Kihar's and Killgore's actions pay the Four, a Shaman-Sorcerer's pays the Skin Wolves;
  - recruiting pays by §3.5, the chariot rule before the wolves rule;
  - Norsca uses the global rival pairs;
  - the turn-start preview includes the altars term.
- **`_guilds_bounty_harness.lua`:** the Boasts dials and the twist table entry.
- **`mutate_guilds.py`:** a mutant per new rule (the max over the four gods, the Undivided
  addition, the factor test, the priests list); the full run with no survivor and no stale anchor.
- **Lua:** luac, `check_lua_api`, `check_lua_literal_left`, `check_lua_undeclared`.
- **Build:** `import_great_guilds.py --check`, then the build; the saved pack verified; a backup
  to `Modding Files/Backup/`; a deploy to the Workshop folder (item 3815248936; never `data/`),
  diffed first; an MD5 compare; the loadfast cache deleted.

**In game after the build:**
1. **Pillage fires `CharacterRazedSettlement`, or not.** Decides §3.2's branch. Run before the
   route is finalised if possible.
2. `PooledResourceChanged` fires for Spoils with the `monstrous_arcanum` factor when a hunt stage
   pays, and for a human Norsca faction.
3. A Norsca panel opens with its frame; Sayl's reads right.
4. An altar raised to a god shows on the earnings sheet under `altars` the next turn.
5. A hall builds, including a unitless one.
6. Each rival pair takes from the right guild.
7. A save from before the update loads.

## 11. Plan-time checks

1. **Tomb Kings' state.** Whether `_tmb` shipped first: its feed slot, its service rows, its
   place in `FLAVOURS` and `HALL_TAGS`, and the selftest pins it moved.
2. **Every read of a race tag from a key suffix.** Vanilla chain keys end in `_nor`
   (`wh2_main_foreign_slot_discovery_nor`, `wh2_main_special_phoenix_king_court_nor`), so any code
   that infers a flavour from a trailing `_nor` must only ever see this mod's own keys.
3. **The hero list**, re-read from `faction_agent_permitted_subtypes` for all three lords' factions,
   and whether any dlc27 subtype was missed.
4. **Hall units:** each one's `_unit_level` in the three sets, its building in each set, and its
   `ownership_content_pack` against `HALL_FALLBACK`.
5. **Pool recruiting.** Whether any Norsca unit is recruited from a pool (`POOL_RECRUITED`); none
   is expected.
6. **The Great Hunt's unit set.** Which units `wh2_dlc09_effect_force_stat_melee_attack_monsters`
   reaches (`effect_bonus_value_ids_unit_sets`), and that it covers Norsca's mammoths, trolls and
   monsters. If it does not, the fallback is `wh_main_effect_force_stat_charge_bonus_pct` at
   `faction_to_force_own` (vanilla 8 to 25).
7. **The frame panel's art** and the reference screenshot; the crest and hall icon stems, each
   measured flat.
8. **The seven windows**, rendered dimmed, and the darkening factor each needs.
9. **Hall settlement types:** which primary chains a hall can sit beside (the Norscan
   settlements, the outposts, the altars), whether a `donor` must be named, and the Help's
   `where` line.
10. **Pillage amounts**, if the `FACTOR_GUILD` branch is taken: typical `loot` values, so 25
    Spoils per Reputation is checked against the per-turn cap.
11. **`rate_temple_altar`'s default** against a measured altar count late in a Wulfrik campaign,
    and against `cap_temple` 40.

## 12. Lore rulings, with sources

| Claim | Source | Status |
|---|---|---|
| Norse, Kurgan and Hung are all Northmen, the Kurgan and Hung trying "to cross the Dragon River or scale the Great Bastion" | CA, `loading_screen_quotes_description_wh3_main_lore_16` | verified in CA loc |
| The Four as the Hound, Eagle, Serpent and Crow; "It is the goal of all Northmen to gain the attention of one of these Ruinous Masters, worshipping a single deity above all others" | CA, `building_flavour_texts_flavour_wh_main_nor_monoliths` | verified in CA loc |
| The Norse and the Kurgan shared that heraldry (Bloodied Hound, Carrion Crow, Slithering Serpent, Fell Raptor) | Fandom, "Norsca", image caption citing its source 57 | fan wiki, unverified |
| Raids on the coasts of the Empire and Bretonnia bring back thralls; thralls skilled at tanning and metalwork do hard labour | CA, `building_flavour_texts_flavour_wh_main_nor_slaves_3` | verified in CA loc |
| The smith is "a slave taken from the southlands and only kept alive due to his useful skills" | CA, `building_flavour_texts_flavour_wh_main_nor_smith_1` | verified in CA loc |
| Thralls build the longships and work the fields | Fandom, "Norscan Thrall", citing *WFRP 2e: Tome of Corruption* p. 140 | fan wiki, unverified |
| Thralls sit at the bottom of Norscan society, below bondsmen and huskarls (the rank ladder) | Fandom, "Norsca", citing *Tome of Corruption* pp. 142-145 | fan wiki, unverified |
| The Shaman-Sorcerer's seer-craft guides the tribe to war | CA, `agent_subtypes_description_text_override_wh_dlc08_nor_shaman_sorcerer_fire` | verified in CA loc |
| Sayl is a shaman-sorcerer of the Dolgan | Fandom, "Shaman-Sorcerer", citing CA's Tides of Torment blog; CA's faction name for Sayl is "Dolgan" | faction name verified; the rest fan wiki |
| The Werekin are former champions | CA, `agent_subtypes_description_text_override_wh_dlc08_nor_skin_wolf_werekin` | verified in CA loc |
| Skin Wolves are found among Norscans, Kurgan and Hung; the tribes fear and respect the Werekin | Fandom, "Skin Wolves" | fan wiki, unverified |
| Berserkers are a warrior cult that fights unarmoured and mostly follows Khorne | Fandom, "Marauder Berserker", citing *Liber Chaotica: Khorne* and *Tome of Corruption* | fan wiki, unverified |
| The Norscans look to Khorne for strength in battle | Fandom, "Norsca", citing *Liber Carnagia* and *Tome of Corruption* | fan wiki, unverified |
| Wulfrik's curse came from a boast | CA, `character_skills_localised_description_wh_dlc08_skill_nor_wulfrik_unique_eternal_challenger`; Fandom, "Wulfrik the Wanderer", citing C. L. Werner's *Wulfrik*, ch. 2 | CA line verified; the story itself fan wiki |
| The Marauder Hunter's javelin "takes down the largest of wild beasts" | CA, `unit_description_short_texts_text_wh_dlc08_unit_short_text_nor_marauder_hunters_1` | verified in CA loc |
| Trolls are "compliant enough to build, enforce and serve" | CA, `pooled_resources_description_wh3_dlc27_nor_kinfolk` | verified in CA loc |
| "Reaver" and "Huskarl" are Norscan words | CA, `ancillaries_onscreen_name_wh3_dlc27_anc_follower_nor_infamous_reaver`, `ancillaries_onscreen_name_wh_dlc08_anc_armour_huskarl_plates` | verified in CA loc |
| Hound against Serpent, Crow against Eagle | CA, `rivalry_conversion_table` in `wh_dlc08_norscan_gods.lua` | verified in CA script |

Rulings, not lore: the three rival pairs (§2.2), the Monster Hunters as the merchants (the
scoping record rates it "workable"), the Skin Wolves as the spies and the Thralls as the
builders (both the author's), the trolls with the Thralls, and the mammoths with the
Shaman-Sorcerers. No tribe name appears in any text this draft proposes; if one is wanted, the
Skaelings as Khorne's tribe in the Berserkers' text is the scoping record's example, and the fan
wiki makes the Aeslings Khorne's too, so it would need a GW source first.

## 13. Every declaration point for `_nor`

The Skaven checklist plus the Warriors of Chaos additions, with Norsca's values:

**`zzz_derpy_guilds.lua`**
- `GG.FLAVOURED["wh_dlc08_nor_norsca"] = {tag = "_nor", feed = 120}`.
- `GG.HIRE_UNIT_BY_CULTURE`: `wh_dlc08_nor_inf_marauder_champions_1`.
- `GG.EARN_ROUTES.spoils`, `GG.EARN_OF`, `GG.POOL_ROUTES`, the `spoils` branch of
  `GG.pool_route_counts`; `GG.FACTOR_GUILD` only on the §3.2 branch.
- `GG.TWISTS`: Boasts.
- `GG.HALL_TAGS`.
- `GG.TEMPLE_ROUTES` between the markers, with `altars`, `holy` and `priests`; `GG.ALTAR_GODS`
  and `GG.temple_altars`; the `GG.temple_turn` guard and grant; the `GG.turn_start_pay` term.
- `GG.BUILDING_THEME_RACE["_nor"]`.
- `GG.RECRUIT_ROUTES["wh_dlc08_nor_norsca"]`.
- Race service rows appended at the end of `GG.SERVICES`.
- `LEDGER_SOURCES` (`spoils`, `altars`, appended); `TUNE_DEFAULTS` and `TUNE_ORDER`
  (`rate_temple_altar`); the presets.
- No entry in `GG.RIVALS_RACE`, `GG.NO_DEMAND`, `GG.UPGRADE_PAYS` or `GG.POOL_GUILD`.

**`zzz_derpy_guilds_ui.lua`:** `GGUI.FRAME["_nor"]`, `GGUI.MCT_NAMES["_nor"]` (`--write`).

**`script/mct/settings/derpy_great_guilds.lua`:** the `rate_temple_altar` row; `PRESET_OWNED`.

**`tools/gen_great_guilds.py`**
- `FLAVOURS["_nor"]` before `_gen`, `pics = "nor"`.
- `POOL_NAMES`, `TEMPLE_NAMES`, `TEMPLE_FLAVOUR`, `RACE_TEXT`, `RECRUIT_SAYS`.
- `TEMPLE_ROUTES`, `EARN_ROUTES` / `EARN_OF`, `TWISTS`.
- `SERVICES` (appended), the `for_tag` overrides on `hashut_blessing` and `holy_war`, and `_nor`
  in the purge/consecration loop.
- `RACE_UNWANTED_EFFECTS["_nor"]`.
- `HALL_TAGS`, `HALL_ICON`'s tag list, `HALL_RACES["_nor"]`, `HALL_EXTRA[("daemonsmiths", "_nor")]`,
  `TEMPLE_LORE["_nor"]` and `_TEMPLE_HALL_SEAT["_nor"]`.
- The `src_` and `log_earn_` loc lists; `TEMPLE_RATE_KEYS`.
- The selftest pins.
- Not touched: `RIVAL_PAIRS_RACE`, `NO_DEMAND`, `CHS_WORDS` / `CHS_EXACT`, `POOL_RECRUITED`,
  `FLAVOUR_WORDS_ALLOWED`.

**`tools/gen_guilds_ui.py`:** `FRAMES["_nor"]`, `RANK_STATS_PAD["_nor"]`, the inset probe's
anchor in the selftest if a race is appended after `_skv`.

**`tools/make_guild_icons.py`:** `ICONS` (eight stems, each flat), `TAB_FRAME["_nor"]`, the two tag
loops, the `HALL_ICONS` count.

**`tools/make_guild_backgrounds.py`:** `CA_ART["nor"]` and the seven `CA_BACKGROUNDS` windows. No
`LENT` entry: one painting.

**`tools/import_great_guilds.py`:** the UI race tuple.

**`tools/_guilds_harness.lua` / `_guilds_bounty_harness.lua`:** the race `cases` list, the
service-rows positional pin, the bounty harness `want` twist table.

**`tools/mutate_guilds.py`:** one mutant per new rule.

## 14. Coordination with Tomb Kings

Both races were scoped on the same day and both append. Whichever builds second:
- takes the later service rows (99-101 or 102-104) and moves the "rows last" pin;
- keeps its own feed slot (Tomb Kings 110, Norsca 120), so neither depends on the order;
- places itself between the other and `_gen` in `FLAVOURS` and appends to `HALL_TAGS`;
- re-counts every selftest pin the first one moved.

Nothing else is shared.

## 15. Rulings that need the author's sign-off

1. Names: the Reavers, the Berserkers, the Shaman-Sorcerers, the Skin Wolves, the Four, the
   Monster Hunters, the Thralls.
2. Ranks: Bondsman, Marauder, Huskarl, Chieftain, Champion.
3. No word pass: "The Great Guilds", "Guilds", Reputation and Favour kept.
4. Tag `_nor`, feed 120, before `_gen`.
5. The global rival pairs, with no per-race table.
6. The temple sits beside CA's allegiance pools and pays per altar of the most-favoured god
   plus every Undivided altar, a new route and a new MCT key `rate_temple_altar` (default 2).
7. Holy war against the Empire, Kislev, Bretonnia and Cathay; priests Kihar and Killgore.
8. Shaman-Sorcerer actions pay the Skin Wolves, with no new hero-to-guild table.
9. Spoils from the Monstrous Arcanum pay the Monster Hunters, 1 per 25; Pillage pays the Reavers
   through Spoils only if the raze event misses it.
10. Trophies not used: dead in 9.0.
11. The twist "Boasts": failed bounties cost double, met demands pay half again.
12. Race services: Tithe of Spoils (200), The Wolf-Kin, The Great Hunt.
13. The temple lore: leadership ladder, Chaos corruption hall and seat, and the corruption-reducing
    services turned to public order only.
14. The smithy and the slaves chain go to the Thralls, the beasts chain to the Skin Wolves, the
    creatures and offerings chains to the Monster Hunters, and the port, loot, stables and
    raiding altars to the Reavers.
15. Recruiting by §3.5, with the foreign ports' units and Sayl's foreign recruits paying nothing.
16. Halls: Hunters, Berserkers, Skin Wolves and Marauders train units; the Thralls, the
    Shaman-Sorcerers (who raise the wizard cap instead) and the Four do not.
17. Art: `campaign_norsca1` for all seven grounds, and the Monstrous Arcanum panel as the frame
    donor.
