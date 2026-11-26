# The Great Guilds: the Tomb Kings (an eleventh race) - design

**Status:** written 2026-11-26 from the author's scoping decisions. Every ruling marked
**sign-off** in this file is a proposal awaiting the author's review. Nothing here is built.

**Builds on:**
- `2026-11-26-great-guilds-tomb-kings-norsca-scoping.md` §1, the author's settled decisions (the
  seven guilds, Lahmia as the Lahmian Sisterhood);
- `2026-09-23-great-guilds-flavours-design.md`, the flavour model;
- `2026-09-29-great-guilds-service-pools-and-races-design.md`, race services, earn routes and twists;
- `2026-10-04-great-guilds-halls-design.md`, halls;
- `2026-10-04-great-guilds-temple-guild-design.md` and `2026-10-09-great-guilds-temple-lore-design.md`;
- `2026-10-05-great-guilds-skaven-design.md` and `2026-10-12-great-guilds-warriors-of-chaos-design.md`,
  the last two races and the recipe this follows;
- `docs/sessions/HANDOFF_20261005_GUILDS_SKAVEN.md` and `HANDOFF_20261012_GUILDS_WARRIORS_OF_CHAOS.md`,
  where the builds departed from their specs (every declaration point, "the {guild}" grammar, the
  word pass, unitless halls, the per-race Buy frame, the Workshop-folder deploy).

Every key below was read on 2026-11-26 from the 9.0 game data with the offline readers
(`read_vanilla_db.py` on `db.pack`, `read_vanilla_loc.py`, `read_pack_index.py` on `ui.pack`) or from
CA's own scripts in `Modding Files/reference/ca_scripts_wh3/`. The RPFM MCP was not used. Keys that
could not be settled offline are listed in §11.

## 1. What and why

The Tomb Kings join the Great Guilds with full parity in one build: seven guilds, ranks, rivals, a
twist, an earn route, temple routes and lore, halls, race services, frame, art and every text family.

| Decision | Ruling |
|---|---|
| Tag and culture | `_tmb`, culture `wh2_dlc09_tmb_tomb_kings` (subculture `wh2_dlc09_sc_tmb_tomb_kings`, 19 factions, playable ones include `wh2_dlc09_tmb_khemri`, `_lybaras`, `_exiles_of_nehek`, `_followers_of_nagash`, `wh3_main_tmb_deserters_of_khatep`) |
| Placement | `_tmb` goes after `_chs` and before `_gen` in `FLAVOURS`, so `_gen` stays last and `GG.GENERIC` keeps feed 30 |
| Feed offset | 110, so the six records land on 5111-5116. The generator's comment puts vanilla's 229 indices at -1..1960 and `check()` refuses a collision |
| Words | Panel "The Great Guilds", tab "Guilds", Reputation and Favour unchanged. **Sign-off.** The Tomb Kings keep CA's own guild-like institutions (the Necrotects, the Liche Priesthood), so the Warriors of Chaos' vocabulary swap has no case here |
| Rivals | Per race, through `GG.RIVALS_RACE` (§4.3): the Sisterhood against the temple, the Tomb Guard against the Liche Priesthood, the Necrotects against the Charioteer Nobles; the Royal Treasury unpaired. **Sign-off** |
| Twist | "The dead remember": `{rate_rivalry = 150, rate_decay = 50}`. **Sign-off** |
| Earn route | "crafted": a completed Mortuary Cult crafting ritual pays the Liche Priesthood 40 (§3.2, new listener). **Sign-off** |
| Tithe | `slave_tithe` pays 150 Canopic Jars through the `missions` factor (§4.4). **Sign-off** on the amount |

**Not in scope:**
- Norsca, which has its own ruling in the scoping note §2.1 and gets its own spec.
- The name "Mortuary Cult" for any guild. It is CA's crafting panel, and the author ruled it out.
- Liche Priest actions paying the Liche Priesthood. That needs a hero-to-guild redirect the mod
  does not have (the `priests` route only redirects to the temple). Recorded in §12.
- Lahmia losing Reputation for battles against Neferata's faction. It would be new code for a rare
  event, and the rival pair already carries the shame (§2).
- Generalising the per-race lists, and the public GitHub repo sync.

## 2. Identity

Every sentence is built as "the {name}", so each name starts "The " and reads after "the".

| Key | Earns from (unchanged) | Rival | Name on the card | Who they are |
|---|---|---|---|---|
| overseers | buildings, growth | slavers | The Necrotects | The architects and taskmasters who raised Nehekhara and still drive its legions |
| daemonsmiths | technologies, crafting (§3.2) | immortals | The Liche Priesthood | The Mortuary Cult's undying priests, keepers of the lore of awakening |
| immortals | battles won | daemonsmiths | The Tomb Guard | The kings' elite guard, entombed to protect them in death |
| temple | faith (§3.3) | khanate | The Cults of the Gods | The priesthoods of Ptra, Asaph, Djaf and the rest of the pantheon |
| brass | income | none | The Royal Treasury | The kings' treasuries, which never stopped counting |
| slavers | sacking and razing | overseers | The Charioteer Nobles | The chariot-riding nobility, who hunt tomb robbers and bring the plunder home |
| khanate | hero actions | temple | The Lahmian Sisterhood | Neferata's vampires, the necessary evil the kings once marched against |

All seven fit `GUILD_NAME_MAX` 22 ("The Lahmian Sisterhood" is exactly 22).

**Names needing sign-off:**
- **The Cults of the Gods** (21). The author's words were "the priesthoods of the gods". "The Temple
  Priesthoods" (22) is the literal choice, but it puts "Priesthood" on two of seven tabs next to the
  Liche Priesthood, and a sentence such as "the Liche Priesthood's rival is the Tomb Guard" must never
  be misread as the temple. "Cult of" is the mod's own word for a temple already (the High Elves'
  "The Cult of Asuryan"), and CA calls a god's following a priesthood or a cult interchangeably
  (`missions_localised_description_wh3_dlc29_ie_qb_tmb_settra_the_armour_of_golden_magnificence`:
  "the death god's priesthood"). "The Priests of the Gods" is 23 and does not fit.
- **The Royal Treasury** (18), over "The Bhagar Merchants" (20; "The Merchants of Bhagar" is 23 and
  does not fit). Bhagar's merchant rulers rest on a Lexicanum search snippet citing White Dwarf 279,
  unread in full (§12). The treasury needs no citation. If the author wants Bhagar, the name swaps
  with no other change.
- **The Charioteer Nobles** (21). CA: "The pride of a Tomb King's army is his charioteer legions...
  chariots have been the chosen means of transport for the kings of Nehekhara"
  (`unit_description_historical_texts_text_wh2_dlc09_tmb_veh_skeleton_chariot`).

**Ranks** (**sign-off**): Peasant, Scribe, Vizier, Prince, Priest King. All within `RANK_NAME_MAX` 12
(Priest King is 11). The top three are CA's words: the Mortuary Cult served "their living kings as
advisors and viziers" and "the Tomb Kings of Nehekhara - or Priest Kings as they were"
(`frontend_faction_leaders_localised_description_wh2_dlc09_political_party_tmb_khatep`); the Tomb
Prince is CA's hero. CA writes "Priest Kings" without a hyphen in all 17 loc rows that use it.

**Rivals** (§4.3 is the code). Each pair has a CA basis:
- **The Lahmian Sisterhood and the Cults of the Gods.** Lahmia's vampirism was "an affront to all
  Nehekharans' reverence for death"
  (`building_short_description_texts_short_description_wh3_main_vmp_special_lahmia_temple_of_blood`),
  and Khalida, who serves the Asp-Goddess Asaph, harbours "a deep, eternal loathing... for all Vampires"
  (`frontend_faction_leaders_localised_description_wh2_dlc09_political_party_tmb_khalida`). This pair
  is how the shame of dealing with the Sisterhood reaches the player: every hero action pays the
  Sisterhood and costs the temples, and every holy-war victory over the vampires pays the temples
  and costs the Sisterhood.
- **The Tomb Guard and the Liche Priesthood.** The kings against the priests who woke them wrong:
  "this was not the Day of Awakening promised by the Mortuary Cult! Settra raged and banished Khatep
  from Khemri" (the Khatep text above).
- **The Necrotects and the Charioteer Nobles.** The builders against the raiders, the same rationale
  as every other race: one raises cities, the other tears them down.
- **The Royal Treasury** has no rival, as the temple has none elsewhere.

The alternative (**sign-off**) is no `RIVALS_RACE` entry at all. The global pairs already give the
Tomb Guard against the Liche Priesthood, and they would set the Sisterhood against the Treasury on
the strength of Neferata's tribute of 10,000 talents a year, which is a Lexicanum snippet only (§12).
That costs no code but loses the temple pair, which carries the Lahmia shame.

**Twist, "The dead remember"** (**sign-off**): `GG.TWISTS["wh2_dlc09_tmb_tomb_kings"] =
{rate_rivalry = 150, rate_decay = 50}`. Helping one guild costs its rival half again as much as usual,
and Reputation fades at half the usual speed. The Empire alone has rivalry 150 and Kislev alone has
decay 50, so the pair is distinct from all ten races. Both are existing dials. The lore is CA's:
the Tomb Guard "remember their duty" (`unit_description_historical_texts_text_wh2_dlc09_tmb_inf_tomb_guard`)
and serve "until death and beyond"
(`building_short_description_texts_short_description_wh2_dlc09_tmb_infantry_3`).

**Hire unit** (`GG.HIRE_UNIT_BY_CULTURE`, the soldiers' "Hire" service): Tomb Guard,
`wh2_dlc09_tmb_inf_tomb_guard_0` (tier 2, `campaign_cap` 0). **Sign-off.** The scoping table offered
Ushabti; this spec gives the Ushabti to the temple's hall (§7) and keeps the hire with the soldiers,
since every race's hire is its elite infantry and the service belongs to the soldiers. Because the
Tomb Guard is capped, the hire needs the cap refusal in §4.2.

## 3. Earning

### 3.1 Shared routes (no code change)

Income pays the Treasury, battles the Tomb Guard, technologies the Liche Priesthood (the scoping note
counts 74 technologies on a normal tree), successful hero actions the Sisterhood, sacking and razing
the Charioteer Nobles, buildings and growth the Necrotects. Tomb Kings buildings do grant growth
(51 `wh_main_effect_province_growth_building` rows on Tomb Kings chains), so the builders' growth
route works, unlike the Chaos Dwarfs'.

**Hero actions** (**sign-off**). The heroes are the Liche Priests (`wh2_dlc09_tmb_liche_priest_death`,
`_light`, `_nehekhara`, `_shadow`, `wh3_dlc29_tmb_liche_priest_undeath`), the Necrotect
(`wh2_dlc09_tmb_necrotect`, plus `wh2_dlc09_tmb_necrotect_ritual`, Ptra's Necrotect), the Tomb Prince
(`wh2_dlc09_tmb_tomb_prince`, a champion the scoping note missed) and the Tomb Herald
(`wh3_dlc29_tmb_tomb_herald`). The five Liche High Priests (`wh3_dlc29_tmb_liche_high_priest_*`) are
**lords** (agent `general`) and can never perform a hero action. Proposed: every successful hero
action pays the Sisterhood, and the temple takes no `priests`. The temple spec's rule is that heroes
tied to a learning guild are not used, and the Liche Priests are the Liche Priesthood's own. So the
Necrotect is the builders' figure and also pays the spies, exactly as every race's heroes do; the
overlap is resolved by recruiting, where a Necrotect pays the Necrotects (§3.4). The alternative is
`priests` = the five Liche Priest subtypes, which moves the largest hero family to the temple.

### 3.2 Race earn route, "crafted" (new listener, §4.1)

Completing a Mortuary Cult crafting ritual pays the Liche Priesthood 40 Reputation,
`GG.EARN_ROUTES.crafted = {guild = "daemonsmiths", rep = 40}`, the same 40 as the High Elves' court.

- CA's crafting is `rituals.category` `CRAFTING_RITUAL`: 65 Tomb Kings rows (48 `wh2_dlc09_ritual_crafting_tmb_*`,
  the rest `wh3_main_ritual_crafting_tmb_*` and `wh3_dlc29_ritual_crafting_tmb_*`), plus 95 Dwarf forge
  rows that share the category. `GG.race_earn` already refuses a faction whose culture's route is not
  "crafted", so Dwarf crafting pays nothing.
- Two rows are not crafts: `wh3_main_tmb_confederate_khalida` and `wh3_main_tmb_confederate_khatep`
  are confederation rites filed as crafting. The listener skips keys starting `wh3_main_tmb_confederate_`.
- CA's own Tomb Kings script listens the same way: `RitualCompletedEvent`, `context:succeeded()`,
  `context:ritual():ritual_key()`, `context:performing_faction()` (`wh2_dlc09_tomb_kings.lua:38-47`).
  CA's other scripts compare `context:ritual():ritual_category()` to a string
  (`episode_neferata.lua:1041`, `victory_objectives.lua:5020`).
- Ledger source `crafted`, appended; log loc `derpy_gg_log_earn_crafted_*`. No tunable, as the court
  has none.

The alternative is the four Great Incantations (`wh2_dlc09_ritual_tmb_ptra`, `_khsar`, `_geheb`,
`_tahoth`, category `STANDARD_RITUAL`, cooldowns 10-25) paying the temple. It is rarer and would be a
second route, which `GG.EARN_OF` does not allow.

### 3.3 The temple's routes

`GG.TEMPLE_ROUTES["wh2_dlc09_tmb_tomb_kings"] = {devout = true, holy = {"wh_main_vmp_vampire_counts",
"wh3_dlc29_nag_undead_legions"}}` (**sign-off**).

- **devout:** provinces in good order. The Priest Kings ruled as priests (the Khatep text).
- **holy:** victories over the Vampire Counts and over Nagash's undead legions. The Vampire Counts
  culture holds both Lahmian Sisterhood factions (`wh3_main_vmp_lahmian_sisterhood`, Neferata, and
  `wh2_dlc16_vmp_lahmian_sisterhood`); Nagash is `wh3_dlc29_nag_host_of_nagash` in culture
  `wh3_dlc29_nag_undead_legions`. Khalida's loathing covers "all Vampires", so the Vampire Coast
  (`wh2_dlc11_cst_vampire_coast`) is an option the author may add.
- **No `chaos` route.** Nothing in CA's Tomb Kings text sets the temples against Chaos corruption,
  and lore over coverage leaves it out.
- **Never `vampiric`.** Tomb Kings settlements SPREAD vampiric corruption: their settlement chains
  carry `wh3_main_effect_corruption_vampiric_buildings` +2. A vampiric-free route would fail every
  Tomb Kings province.
- **No `taint`, no `priests`** (§3.1).

### 3.4 Recruiting (`GG.RECRUIT_ROUTES`, first fit wins)

Opens with the hall families, then the rest. Match on keys, not on `agent`: the Tomb Herald is filed
as `engineer` in some factions' `faction_agent_permitted_subtypes` rows and as `dignitary` in others,
so an `agent = "engineer"` rule would pay the Necrotects for a Herald.

Units:

| Rule | Guild | Covers |
|---|---|---|
| `key = "tomb_guard"` | immortals | hall |
| `key = "ushabti"` | temple | hall; CA: statues of the gods, "physical embodiment of the everlasting gods" |
| `key = "chariot"` | slavers | hall (Skeleton Chariots), Skeleton Archer Chariots |
| `key = "necropolis_knights"` | daemonsmiths | hall; CA: the pit "next to every great temple of the Mortuary Cult" |
| `key = "nehekhara_horsemen"` | brass | hall |
| `key = "tomb_scorpion"` | overseers | hall; the Necrotect's own "Scorpion Carver" skill |
| `key = "sphinx"`, `"heirotitan"`, `"khemric_titan"`, `"bone_giant"` | overseers | the constructs Necrotects carve (CA spells it `heirotitan`) |
| `key = "sepulchral_stalkers"` | khanate | CA's Temple of Blood in Lahmia trains them |
| `key = "carrion"` | temple | CA: Carrion are "agents of Ualatp"; CA's Obelisk chain raises their cap |
| `key = "crypt_ghouls"`, `"cairn_wraiths"`, `"hexwraiths"`, `"spirit_host"`, `"fell_bats"`, `"dire_wolves"`, `"crypt_horrors"`, `"morghast"` | `false` | Arkhan's necromantic roster serves Nagash, not Nehekhara |
| `key = "skeleton_warriors"`, `"skeleton_spearmen"`, `"skeleton_archers"` | overseers | CA: Necrotects "lead the regiments like the work gangs of old" |
| `key = "nehekhara_warriors"` | immortals | the king's regulars |
| `caste = "cavalry"` | slavers | Skeleton Horsemen and Horse Archers |
| `caste = "engines"` | daemonsmiths | Screaming Skull Catapult, Casket of Souls |
| `caste = "infantry"` | immortals | anything else on foot |
| `caste = "beasts"` | overseers | anything else |

Characters: `key = "liche"` and `"khatep"` daemonsmiths; `"necrotect"` overseers; `"tomb_herald"`
immortals (CA: "a Tomb King's personal champion and most trusted bodyguard"); `"khalida"` temple (she
rises "at Asaph's bidding"); `"arkhan"` `false`; then `{"slavers"}` for every king, prince and Settra
(CA: the king's younger sons "served as the generals and lieutenants of his armies").

`RECRUIT_SAYS["_tmb"]` lists those troops per guild in plain words. `check_recruit_routes()` proves
every key matches a vanilla Tomb Kings unit and every hall unit pays its hall's guild.

### 3.5 Buildings (`GG.BUILDING_THEME_RACE["_tmb"]`)

The Tomb Kings build from one set, `wh2_dlc09_bas_tmb` (90 chains, 63 of them Tomb Kings only). Each
token below was checked against every chain in the game and matches exactly one Tomb Kings chain and
nothing else. Tokens are lowercase substrings with no Lua pattern magic; the longest token wins.

```lua
["_tmb"] = {
    {"temple",       {"tmb_ushabti", "tmb_public_order"}},
    {"daemonsmiths", {"tmb_estate", "arkhan_burial_mound"}},
    {"brass",        {"tmb_income"}},
    {"slavers",      {"tmb_chariots", "tmb_cavalry"}},
    {"immortals",    {"tmb_citadel"}},
    {"khanate",      {"foreign_slot_discovery_tmb", "tmb_allied_outpost", "lahmia_house"}},
    {"overseers",    {"tmb_hierotitan", "tmb_necrosphinx", "tmb_warsphinx", "tmb_scorpions"}},
},
```

The shared words already route the rest: settlements, specials and growth to the Necrotects,
infantry and defence to the Tomb Guard, ports and `resource_*` (including `wh3_main_tmb_resource_ivory`)
to the Treasury. `tmb_estate` (the Mortuary estates, which produce Canopic Jars) goes to the Liche
Priesthood, as does Arkhan's burial mound. `tmb_public_order` is the Obelisk / Sepulchre / Mortiferous
Sanctuary chain.

Share of the set, tier-weighted by the Warriors of Chaos method over all 90 chains, ruins excluded:
Necrotects 49%, Tomb Guard 23%, Treasury 17%, Sisterhood 3%, Charioteer Nobles 3%, Liche Priesthood
2%, temples 2%. No `wh2_dlc09_tmb_*` chain falls to the default. The 15% that does are shared
landmarks (the pyramids, the Black Tower, Nagashizzar, Morgheim, Quintex, the Great Desert,
Bordeleaux and the like), and the builders taking them is deliberate: CA's Ptra incantation credits
the sun-god's "builder-disciples" (`ui_text_replacements_localised_text_wh2_dlc09_ritual_tmb_ptra_description`).

## 4. New code paths

### 4.1 The crafting listener

One listener in the shape of `gg_earn_court`:

```lua
core:add_listener("gg_earn_crafted", "RitualCompletedEvent", true, function(context)
    local ok, cat, key, won = pcall(function()
        local r = context:ritual()
        return r:ritual_category(), r:ritual_key(), context:succeeded()
    end)
    if not ok or not won or cat ~= "CRAFTING_RITUAL" or type(key) ~= "string" then return end
    if string.sub(key, 1, 25) == "wh3_main_tmb_confederate_" then return end
    local name = faction_name_of(context, function() return context:performing_faction() end)
    if not name then return end
    GG.load(name); GG.race_earn(name, "crafted"); GG.save(name)
end, true)
```

Whether the AI's crafting raises the event is a plan-time check (§11); AI factions earn only while a
Tomb Kings human plays (`GG.covered`), as for every race.

### 4.2 The unit cap refusal

Tomb Kings units cost nothing and pay no upkeep: all 54 non-character rows in `main_units` have
`recruitment_cost` 0 and `upkeep_cost` 0. CA limits them by `campaign_cap` 0 ("capped by effects
only") and raises the cap with `unit_cap` effects on buildings, technologies and bundles. Only the
Skeleton Warriors and Skeleton Spearmen are uncapped (`campaign_cap` -1).

A service that hands over a capped unit must not exceed the cap. `GG.can_buy` gains one refusal for
`kind == "unit"` and for `race_army` rows: when the faction's `unit_cap_remaining(unit_key)` is 0 for the
unit to be granted, refuse with a new reason ("capped") and a plain loc line, for example "You have as
many Tomb Guard as your kings allow." -1 means unlimited, so every other race and every uncapped unit
passes. CA documents `unit_cap` and `unit_cap_remaining` on `FACTION_SCRIPT_INTERFACE` ("-1 if
unlimited"); the entry's parameter line names a different function (`unit_cap_available`), and no CA
script calls either, so the call's behaviour is an in-game check (§10).

The refusal is needed whatever `cm:grant_unit_to_character` does at the cap. Its doc says only "The
unit will only be created if there is room for it in the force". If the engine silently refuses a
capped unit, the player pays Favour for nothing, since `GG.buy` refunds only when the call throws.

### 4.3 A race whose temple has a rival

`GG.RIVALS_RACE["wh2_dlc09_tmb_tomb_kings"] = {khanate = "temple", temple = "khanate", immortals =
"daemonsmiths", daemonsmiths = "immortals", overseers = "slavers", slavers = "overseers"}`. `GG.rival_of`
already reads the race table first and returns nil for a guild it lacks, so the Treasury needs nothing.
What does change is every place that assumes the temple has no rival:
- the harness pins at `_guilds_harness.lua` 1375, 10039 and 10758, which assert the temple unpaired
  globally and for the Warriors of Chaos, gain a Tomb Kings case where it is paired and the Treasury
  is not;
- every Help, card or tooltip line that says the temple has no rival, which must become per race;
- the temple's earn routes paying through `GG.rival_cost`, which they skip today only because
  `rival_of` returns nil.

Read at plan time: how the devout route pays. If it grants one province at a time, the floor of 1 in
`GG.rival_loss` makes each 1-point grant cost the Sisterhood 1, which is 100% and not 60%. The floor at
the rank reached keeps it from demoting, but a harness case should measure a 10-province turn.

### 4.4 Canopic Jars as the tithe

The pooled branch of `slave_tithe` gains a Tomb Kings arm before the gold fallback:

```lua
elseif GG.culture_of(faction) == "wh2_dlc09_tmb_tomb_kings"
       and GG.has_resource(faction, "tmb_canopic_jars") then
    cm:faction_add_pooled_resource(faction, "tmb_canopic_jars", GG.TITHE_FACTOR, 150)
```

`missions` is a positive factor of `tmb_canopic_jars` and CA's own payload grants jars through it
(`lib_campaign_mission_manager.lua:2650-2656`, `payload.canopic_jars`). The factor list is battles,
buildings, characters, events, great_incantation_of_geheb, missions, other and settlements_captured
on the gain side. **Amount, sign-off:** 150 is CA's largest regular payload (seven quest battles; the
other 136 missions pay 50) and sits between the cheapest craft (100) and the median (250). CA's own
payload remapping would turn 3,000 gold into 60 jars (`wh3_campaign_payload_remapping.lua:372-384`),
which is the low alternative.

### 4.5 Halls that carry their unit's cap

Because every hall unit but the uncapped two has `campaign_cap` 0, a hall that only allows a unit
allows zero of it. Each Tomb Kings hall therefore carries its unit's `unit_cap` effect through
`HALL_EXTRA`, as CA's own buildings do (§7). A new generator check refuses any hall whose unit has
`campaign_cap` 0 and no cap effect naming it, so a later race cannot ship a hall that trains nothing.

### 4.6 Effects that do nothing for the Tomb Kings

Two shared services would be worthless, so they get `for_tag["_tmb"]` swaps and
`RACE_UNWANTED_EFFECTS["_tmb"]` gains both effects with the measured reason:

| Service | Shared effect | Why it fails | Tomb Kings swap (**sign-off**) |
|---|---|---|---|
| `mercenary_contract` (Treasury, rank 2, 6 turns) | `wh_main_effect_force_all_campaign_recruitment_cost_all` -15 | no Tomb Kings unit costs gold | `wh_main_effect_agent_recruitment_cost_mod` -15, `faction_to_province_own` (the pair the Sisterhood's rank bundle uses; CA: "Hero recruitment cost"). Tomb Kings heroes do cost gold: 550 for a Necrotect, 700 for a Tomb Prince or Herald, 800 for a Liche Priest (`agent_subtypes.cost`) |
| `treasury_seal` (Treasury, rank 4, 12 turns) | `wh_main_effect_force_all_campaign_upkeep` -20 | no Tomb Kings unit pays upkeep | `wh3_main_tmb_rite_cost_mod_crafting` -20, `faction_to_faction_own_unseen` ("Mortuary Cult crafting cost: %+n%"). -20 is CA's own value on Khatep's trait bundle; `is_positive_value_good` is false, so -20 is the discount |

Checked and fine as they are: `master_gunners` reaches the Screaming Skull Catapult (`art_fld`, inside
`all_land_artillery`); `public_works` growth works (§3.1); every Winds of Magic effect has casters to
reach; the temple's three default services (physical resistance; charge and melee attack; Winds and
leadership) all reach Tomb Kings armies, so §6 overrides none of them.

## 5. Race services

Appended after the Warriors of Chaos rows, never inserted, because cooldowns are saved by position.
Prices are `RACE_PRICE` (50/150/400, cooldowns 8/12/16). **All three need sign-off.**

| Key | Guild | Rank | Kind | Payload |
|---|---|---|---|---|
| `canopic_offering` | brass | 2 | resource | `tmb_canopic_jars`, factor `missions`, 50 (CA's standard mission payload) |
| `the_awakening` | daemonsmiths | 3 | race_army, `room = true` | one Skeleton Warriors and one Skeleton Spearmen (`wh2_dlc09_tmb_inf_skeleton_warriors_0`, `wh2_dlc09_tmb_inf_skeleton_spearmen_0`), through `GG.RACE_FIRE.electors_muster` |
| `kings_legions` | immortals | 4, lead | bundle, 10 turns | `wh3_dlc29_effect_unit_cap_tmb_all` +1, `faction_to_faction_own_unseen` ("Unit capacity: %+n / All units") |

- The Awakening grants only the two uncapped units, so it never touches a cap. CA: the Liche Priests
  are "the undying members of Nehekhara's Mortuary Cult"
  (`unit_description_historical_texts_text_wh2_dlc09_tmb_cha_liche_priest`), and they awaken the
  Ushabti (`unit_description_historical_texts_text_wh2_dlc09_tmb_mon_ushabti`).
- The King's Legions is the one bundle pair CA itself uses to raise every cap at faction scope: +2 on
  `wh3_dlc29_ie_tk_victory_conditions_lord_unit_capacity_long`, a victory payload applied to the
  faction (`victory_objectives_config.lua:4620-4632`). Unit-specific cap effects exist only at building
  scope, or at `force_to_faction_own_factionwide` for the Tomb Guard (`wh3_main_effect_unit_cap_tmb_tomb_guard`,
  Books of Nagash reward 5), so they cannot go on a faction bundle. What happens to units above the cap
  when the bundle expires is an in-game check (§10); if the engine disbands them, this service is
  withdrawn rather than shipped.
- Names, blurbs and the flavour line are written per §8. Flavour must never promise a mechanic.

## 6. The temple by its own lore

`TEMPLE_LORE["_tmb"]` and `_TEMPLE_HALL_SEAT["_tmb"]` (**sign-off**):
- **Rank:** ward save, the flat ladder Bretonnia and the High Elves use
  (`wh_main_effect_force_stat_ward_save`, `faction_to_force_own`, 2/4/6/8, lead 5). The gods' protection;
  CA calls the Ushabti "the physical embodiment of the everlasting gods"
  (`unit_description_short_texts_text_wh2_dlc09_tmb_mon_ushabti`).
- **Hall:** public order in the province (`wh_main_effect_public_order_base`,
  `province_to_province_own_unseen`, 2/4/6), CA's own Obelisk-chain pair (4/6/8 on
  `wh2_dlc09_tmb_public_order_1-3`).
- **Seat:** `wh_main_effect_public_order_events`, `faction_to_province_own`, +1, "Public order +1 in every
  province" (the pair `bought_peace` already ships).
- **No service overrides** (§4.6).

## 7. Halls

`HALL_TAGS` gains `_tmb`; `HALL_RACES["_tmb"] = {"set": "wh2_dlc09_bas_tmb", ...}` with no `extra_sets`
(no Tomb Kings lord builds from another set). Donor and settlement types follow the default rule;
confirmed at plan time.

| Guild | Unit (`_unit_level`) | `HALL_EXTRA["_tmb"]`, all CA building pairs at `building_to_faction_own` |
|---|---|---|
| immortals | Tomb Guard (0) | `wh2_dlc09_effect_unit_cap_tmb_inf_tomb_guard_0`; CA gives +1 at infantry_2 and +2 at infantry_3 |
| temple | Ushabti `wh2_dlc09_tmb_mon_ushabti_0` (0) | `wh2_dlc09_effect_unit_cap_tmb_mon_ushabti_0`; CA +1 / +2, +4 in the Great Desert |
| slavers | Skeleton Chariot `wh2_dlc09_tmb_veh_skeleton_chariot_0` (0) | `wh2_dlc09_effect_unit_cap_tmb_veh_skeleton_chariot_0`; CA +2 |
| overseers | Tomb Scorpion `wh2_dlc09_tmb_mon_tomb_scorpion_0` (0) | `wh2_dlc09_effect_unit_cap_tmb_mon_tomb_scorpion_0`; CA +2 |
| brass | Nehekharan Horsemen `wh2_dlc09_tmb_cav_nehekhara_horsemen_0` (0) | `wh2_dlc09_effect_unit_cap_tmb_cav_nehekhara_horsemen_0`; CA +1 |
| daemonsmiths | Necropolis Knights `wh2_dlc09_tmb_cav_necropolis_knights_0` (1) | `wh3_main_effect_unit_cap_tmb_cavalry_3_1`; CA +1 ("Necropolis Knights, Sepulchral Stalkers") |
| khanate | none (**sign-off**) | the Undoer's pair, `wh_main_effect_agent_action_success_chance_enemy_building`, `region_to_character_enemy`, -10/-15/-20 |

- The per-level values are CA's own per-building values or below them, so `check_halls` (1.5x vanilla)
  passes; the plan sets each ladder, for example [1, 1, 2] for the Tomb Guard.
- **The Sisterhood's hall is unitless** because the only Tomb Kings unit tied to Lahmia, the Sepulchral
  Stalkers, has no cap effect of its own: its one building pair is shared with the Necropolis Knights,
  so two halls would each raise the other's unit. The vampires are not a Tomb Kings unit at all. The
  alternative is Stalkers with the shared effect.
- **Nouns** (plan words, **sign-off**): halls "Sepulchre", "Mausoleum", "Necropolis"; temples "Shrine of
  the Gods", "Temple of the Gods", "Great Temple of the Gods". "Sepulchre" and "Necropolis" are CA's own
  Tomb Kings words.
- Hall icons from CA's Tomb Kings building icons; every unit key and pair verified again at plan time.

## 8. Panel, art and text

- **Frame.** `FRAMES["_tmb"]` / `GGUI.FRAME["_tmb"]`, briefed against a named CA panel and a reference
  screenshot per `docs/CUSTOM_UI.md` "Design direction". The candidate is CA's Mortuary Cult panel:
  `ui/skins/wh2_dlc09_tmb_tomb_kings/` holds 31 files, including `mortuary_cult_bottom_strip.png`,
  `mortuary_cult_crafted_anim_background.png` and `mortuary_cult_crafted_anim_text_holder.png`, and
  `ui/skins/default/` holds the panel's `mortuary_cult_panel_background.png`, `_title_frame.png` and
  `_decor_left/right.png`. Until it is measured, the frame starts as a copy of `_chs`, as the Warriors
  of Chaos started from `_skv`. `RANK_STATS_PAD["_tmb"]` is decided by the preview, and the per-race
  `buy` frame entry is filled.
- **Grounds** (`make_guild_backgrounds.py`). `CA_ART["tmb"] =
  "ui/loading_ui/load_images/campaign_tomb_kings1.png"`, 1920x1200, read offline. Six of the seven
  grounds are windows of it. A first contact sheet suggests: Tomb Guard window 4 (the shield wall),
  Charioteer Nobles 5 (the horsemen's charge), Necrotects 2 (the warsphinx), Liche Priesthood 3 (the
  Ushabti behind the stalker), Treasury 1 (the procession under the vultures), temple 7. The painting
  is framed, like `campaign_chaos1`, so the left windows are checked darkened before they are chosen.
  **The Sisterhood's ground is lent** (**sign-off**): `campaign_vampire_lahmian_sisterhood1.png`
  (1920x1080, Neferata and her sisters), one window chosen from a rendered sheet. This needs the
  `LENT` rule's selftest clause extended to `_tmb`, which today checks that a race's windows are all
  seven of one painting. Without the loan, all seven come from the Tomb Kings painting with no
  selftest change.
- **Crests and hall icons** from CA's Tomb Kings art, each measured flat before it is picked.
- **Event pictures.** `"pics": "tmb"` with no `pictures` overrides: every picture the feed records
  draw (`generic`, `messenger`, `diplomacy`, `civilisation_up`, `civilisation_down`) is used by vanilla
  rows under `tmb/`, and `tmb/generic` is a vanilla mission picture (`check_feed_images`).
- **Text.** Every family the other ten carry: names, descriptions, ranks; the 63 shared service names
  (18 base, 36 pool, 9 temple) and the 3 race services, with blurbs; bounties; feed messages; the Help
  pages, including the crafted route, "The dead remember", the race's own rival pairs and that the
  Treasury has no rival; `RECRUIT_SAYS`; MCT names. Rules, from the author's memory files: plain spoken
  English in CA's voice for that surface; Reputation, never "standing"; no cap, accrue, AI or HUD
  jargon; no "slave" in Tomb Kings text (`FLAVOUR_WORDS_ALLOWED` stays as it is), even though CA's
  Necrotect text uses it; flavour never promises a mechanic; every lore word checked against CA's loc.

Proposed starting text (**sign-off**; the plan writes the rest to match):

| Field | Text |
|---|---|
| desc overseers | The architects of Nehekhara, who raised its cities and pyramids. In death they still cannot stop building, and still drive the legions like work gangs. |
| desc daemonsmiths | The undying priests of the Mortuary Cult, who keep the lore of awakening. They promised the kings eternal life, and the kings have not forgotten how it turned out. |
| desc immortals | The kings' own guard, entombed beside them to protect them in death. They remember their duty when they remember little else. |
| desc temple | The priests of Ptra, Asaph, Djaf and the other gods of Nehekhara, whose temples stood in every city long before the dead walked. |
| desc brass | The royal treasuries, which kept count of every king's wealth in life and keep counting in death. |
| desc slavers | The nobles who ride to war in chariots, as the kings always have. They hunt down tomb robbers and bring back everything that was stolen. |
| desc khanate | Neferata's daughters, the vampires the kings once marched against. Every king despises them, and every king has used them. |
| hire blurb | The king's own guard, who stand between him and every blade. Adds one unit of Tomb Guard to the army you select. |
| slave_tithe blurb | The Charioteer Nobles bring back what the tomb robbers stole. Adds 150 Canopic Jars. |
| bounty khanate | ("A Quiet Death", "The Sisterhood wants that name silenced, and asks no questions about the method.") |
| bounty temple | ("Judgement of the Gods", "A vampire general walks the land. The temples want that general destroyed.") |
| twist | ("The dead remember", "Helping a guild costs you half again as much Reputation with its rival, and Reputation fades half as fast.") |
| earn | "Completing a crafting ritual pays the {g}." |

## 9. Save safety, AI and MCT

- A running campaign with a Tomb Kings human starts its Tomb Kings factions blank, the path `GG.load`
  takes for any new faction.
- Nothing stored changes shape. The race rival table, the crafted route and the cap refusal are code.
- `_gen` stays last, so `GG.GENERIC` (30) and every existing feed slot are unchanged.
- AI Tomb Kings earn only while a Tomb Kings human plays (`GG.covered`). AI buying needs no code; the
  cap refusal applies to it as to the player.
- No new MCT key: the crafted route has no rate, and the temple reuses `rate_temple_devout` and
  `rate_temple_holy`. `PRESET_OWNED` is untouched unless the plan adds a rate.

## 10. Tests

Nothing ships until all are green.

- **Generator `--check` and `--selftest`.** Every ten-race pin moves to eleven, each counted rather
  than loosened. Every mirror gains `_tmb` (`check_race_mirror`, `check_hire_units`, `check_frame_mirror`,
  `check_hall_mirror`, `check_temple_routes`, `check_flavour_mirror`, `check_mct_names`,
  `check_rival_mirror`, `check_building_theme`, `check_recruit_routes`, `check_feed_images`,
  `check_bounty_data`). New: the hall cap check (§4.5). Every new key read from `db.pack`
  (`check_live_references`).
- **`_guilds_harness.lua`:**
  - Tomb Kings rivals use their own pairs; the temple is paired for them and unpaired for the other
    ten; the Treasury earns with no rival cost;
  - a 10-province devout turn costs the Sisterhood what the twist says, and never below the rank
    reached (§4.3);
  - a crafting ritual pays the Liche Priesthood 40; a confederation rite, a failed ritual and a Dwarf
    forge craft pay nothing;
  - the hire refuses at `unit_cap_remaining` 0, passes at -1 and at 1;
  - the tithe pays 150 jars for a Tomb Kings faction holding the pool, and gold for one without it;
  - recruiting pays by the §3.4 table, Arkhan's units pay nothing, a Tomb Herald pays the Tomb Guard;
  - a hero action pays the Sisterhood and costs the temples; a holy-war win over a Vampire Counts or
    Nagash army pays the temples and costs the Sisterhood.
- **`_guilds_bounty_harness.lua`:** the twist dials and the `want` table entry.
- **`mutate_guilds.py`:** one mutant per new rule (the confederate skip, the category test, the cap
  refusal's -1, the jars branch, the temple pairing, the hall cap check); the full run with no
  survivor and no stale anchor.
- **Previews** from the shipped Lua (`GG_DUMP_TAG=_tmb`): a guild page, the temple, the Leaderboard,
  the Court and Help; contrast and fit green.
- **Build:** `import_great_guilds.py --check`, then the build and the saved pack verified; a backup to
  `Modding Files/Backup/`; a deploy to the **Workshop folder** (item 3815248936; never `data/`), diffed
  first, then an MD5 compare and the `loadfast_cache` cleared.

**In game after the build:**
1. The Tomb Kings panel opens with its frame, and the Sisterhood's ground is Neferata's painting.
2. A crafting ritual pays the Liche Priesthood; confederating Khalida pays nothing.
3. Hire Tomb Guard at the cap is refused with the new line; below the cap it grants, and whether
   `cm:grant_unit_to_character` itself respects the cap is recorded.
4. `unit_cap_remaining` returns the panel's numbers (CA's doc entry names another function).
5. The King's Legions raises every cap by one; at expiry, units above the cap are kept or the service
   is withdrawn.
6. The tithe's 150 jars show in the Canopic Jars tooltip under missions.
7. A hall raises its unit's cap, and the unitless Sisterhood hall builds.
8. A hero action costs the temples.
9. A save from before the update loads.

## 11. To read before writing (plan-time checks)

1. **Whether AI factions raise `RitualCompletedEvent` for crafting**, and whether the AI crafts at all.
2. **How the devout route pays** (one grant or one per province), for §4.3's floor.
3. **`unit_cap_remaining`** on a live faction; and `grant_unit_to_character` at the cap (in game).
4. **Over-cap units after a cap bundle expires** (in game), before §5's King's Legions ships.
5. **Every read of the temple's rival status** across the model, the UI and the bounty code.
6. **The hall donor and settlement types** for `wh2_dlc09_bas_tmb`, and each `_unit_level` again.
7. **The frame panel's art** and the reference screenshot; crest and hall icon stems.
8. **Feed indexes 5111-5116** against the vanilla table itself rather than the generator's comment.
9. **The research bounty** for a one-subculture tech tree (the Warriors of Chaos fix to `bounty_techs()`).
10. **The Lahmian painting's windows**, darkened, and the `LENT` selftest clause.
11. **White Dwarf 279 and the 8th-edition Tomb Kings army book** for Bhagar, if the author picks
    "The Bhagar Merchants".

## 12. Lore rulings

- **CA's loc is the citation of record.** Every in-game text claim above cites a CA loc key. The
  Necrotects as taskmasters over "tens of thousands" who "lead the regiments like the work gangs of
  old" (`unit_description_historical_texts_text_wh2_dlc09_tmb_cha_necrotect`); the firstborn given to
  the Mortuary Cult and the younger sons as generals (`..._wh2_dlc09_tmb_cha_tomb_prince`); the
  priesthood that "cursed itself" into servitude (`..._wh3_dlc29_tmb_cha_liche_high_priest`); the Tomb
  Herald as champion and bodyguard (`..._wh3_dlc29_tmb_cha_tomb_herald`); "the relentless reclamation
  of plundered glory" (`rituals_description_wh3_main_ritual_tmb_jars_b`), which grounds the Charioteer
  Nobles' tithe; Bhagar exists in CA's text only as the city of the Bone Giants
  (`unit_description_historical_texts_text_wh2_pro06_unit_long_text_tmb_mon_bone_giant`).
- **Flagged, Lexicanum search snippets only** (the pages returned 402/403 and were not read in full;
  Lexicanum marks them as needing citations): Bhagar ruled by merchants, known for cavalry and trade
  with the Lizardmen and Elves (citing White Dwarf 279); Neferata's tribute of 10,000 talents a year to
  rebuild Mahrak; 5,000 Hurusanni warrior priests at the Siege of Lahmia; the Hieratic Council seated
  in Mahrak; the Ushabti carved in the likeness of Djaf, Phakth and Ptra. None of these reaches
  player text unless the author confirms it from a GW source. The rulings above do not depend on
  them: the temple-Sisterhood rivalry stands on CA's Temple of Blood and Khalida texts.
- **Fan wiki or translations only:** nothing used.
- **Lore over coverage:** no Chaos-corruption route for the temples; Arkhan's necromantic units pay no
  guild; the Lahmian Sisterhood's hall trains no unit.
- **The Mortuary Cult** stays CA's panel. The Liche Priesthood is the same body of priests by another
  name, which is accurate: CA calls Khatep "the head of the Mortuary Cult's hieratic council"
  (`effect_bundles_localised_description_wh2_dlc09_lord_trait_tmb_khatep`).
- **Lahmia** is the author's ruling of 2026-11-26 (scoping note §1): the Sisterhood as a necessary
  evil. The rival pair and the twist carry the tension; nothing in player text should excuse it.

## 13. Every place a race must be declared

The Skaven handoff's list with the Warriors of Chaos additions, filled in for `_tmb`. Checks that
catch an omission are in brackets.

**`Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (model)**
- `GG.FLAVOURED["wh2_dlc09_tmb_tomb_kings"] = {tag = "_tmb", feed = 110}` (`check_flavour_mirror`).
- `GG.HIRE_UNIT_BY_CULTURE` = Tomb Guard (`check_hire_units`).
- `GG.EARN_ROUTES.crafted` and `GG.EARN_OF` (`check_race_mirror`).
- `GG.TWISTS` (`check_race_mirror`).
- `GG.RIVALS_RACE` (`check_rival_mirror`).
- `GG.HALL_TAGS` (`check_hall_mirror`).
- `GG.TEMPLE_ROUTES`, between the BEGIN/END markers (`check_temple_routes`).
- `GG.RECRUIT_ROUTES`, between its markers (`check_recruit_routes`).
- `GG.BUILDING_THEME_RACE["_tmb"]` (`check_building_theme`, which needs `HALL_RACES["_tmb"]`).
- Three race service rows appended to `GG.SERVICES`; `GG.RACE_FIRE.the_awakening = GG.RACE_FIRE.electors_muster`.
- `GG.LEDGER_SOURCES` gains `crafted`, appended.
- The `slave_tithe` jars arm (§4.4), the cap refusal in `GG.can_buy` (§4.2), the crafted listener (§4.1).
- Not needed: `GG.NO_DEMAND`, `GG.POOL_GUILD`, `GG.UPGRADE_PAYS`, `taint`, `TUNE_DEFAULTS`/`TUNE_ORDER`.

**`zzz_derpy_guilds_ui.lua`**
- `GGUI.FRAME["_tmb"]`, with the `buy` entry (`check_frame_mirror`, the every-flavour-has-a-frame pin).
- `GGUI.MCT_NAMES["_tmb"]` (`check_mct_names`; `--write` regenerates it).
- The rival lines that assume the temple is unpaired (§4.3).

**`script/mct/settings/derpy_great_guilds.lua`**
- Nothing, unless a rate is added.

**`tools/gen_great_guilds.py`**
- `FLAVOURS["_tmb"]` before `_gen`: culture, `"pics": "tmb"`, `"feed": 110`, guilds, ranks, services,
  blurbs, desc, bounties.
- `POOL_NAMES`, `TEMPLE_NAMES`, `TEMPLE_FLAVOUR`, `RACE_TEXT`, `RECRUIT_SAYS`.
- `TEMPLE_ROUTES`, `EARN_ROUTES` / `EARN_OF`, `TWISTS`, `RIVAL_PAIRS_RACE`.
- `SERVICES`, appended, and the `for_tag["_tmb"]` swaps on `mercenary_contract` and `treasury_seal`.
- `RACE_UNWANTED_EFFECTS["_tmb"]` (the two cost effects).
- `HALL_TAGS`, `HALL_ICON`'s tag list, `HALL_RACES["_tmb"]`, `HALL_EXTRA` for all seven halls,
  `TEMPLE_LORE["_tmb"]`, `_TEMPLE_HALL_SEAT["_tmb"]`.
- The `src_` and `log_earn_` loc lists (`crafted`).
- The new hall cap check (§4.5).
- The selftest pins: the race-service count, the `FLAVOURS` order, the (tag, set) tuple, the DLC-tag
  tuple, the hall-set count.

**`tools/gen_guilds_ui.py`**
- `FRAMES["_tmb"]`, `RANK_STATS_PAD["_tmb"]`; the inset probe's anchor in the selftest moves again.

**`tools/make_guild_icons.py`**
- `ICONS`, `TAB_FRAME["_tmb"]`, the two tag loops and the `HALL_ICONS` count (or an explicit
  `HALL_ICONS.update` if the cards are not building icons).

**`tools/make_guild_backgrounds.py`**
- `CA_ART["tmb"]`, `CA_ART["tmb_lah"]` if the loan is approved, the seven `CA_BACKGROUNDS` windows,
  and the selftest's `LENT` clause.

**`tools/import_great_guilds.py`**
- The UI race tuple.

**`tools/_guilds_harness.lua` / `_guilds_bounty_harness.lua`**
- The race `cases` list; the temple-rows positional pin; the three temple-unpaired pins; the bounty
  harness `want` twist table.

**`tools/mutate_guilds.py`**
- One mutant per new rule (§10).
