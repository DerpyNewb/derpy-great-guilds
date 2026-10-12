# Great Guilds: Reputation from recruiting (2026-10-11)

A player asked on the Workshop: "it would be nice if you would get Reputation through recruiting
certain units, heroes and lords." It was never built and never planned; no guild doc listed
recruiting as an earn route. This session built it for all nine races. **Build `190DA0F2` is
packed and deployed to the Workshop folder (3815248936), NOT uploaded**, so the author can check
it in game ([patch notes](PATCH_NOTES_GREAT_GUILDS_20261011.md)). Eight of the nine tables below
are drafts the author has not yet reviewed; they ship in this test build as drafted. Backup of
the build before it (`9919edb7`, the published one):
`Modding Files/Backup/guilds_recruiting_20261011/`.

## What it does

- `UnitTrained` and `CharacterRecruited` pay the guild a recruit belongs to, for every covered
  faction (the player's race, human and AI alike).
- **Amounts** (`rate_recruit`, default 2): 2 per unit, 4 for a monster or war machine (caste
  `monster`, `monstrous_infantry`, `monstrous_cavalry`, `warmachine`, `chariot`), 8 for a hero or
  lord. No unit interface member reads a recruitment cost, so price cannot weight it.
- **Limit** (`cap_recruit`, default 20): recruiting pays each guild at most 20 a turn, inside
  that guild's own limit. Without it one big recruiting turn fills a guild's limit, so the battle
  won that turn pays nothing, and the Daemonsmiths (no limit) take whatever the turn recruits.
  The counter is `rec_<guild>` in the existing `derpy_gg_gain_<faction>` save, so a reload cannot
  pay it twice. Presets: easy 3/30, hard 1/15, ultra 1/10.
- **Ledger**: booked under the new source `recruits` ("recruits" on the panel); what the limit
  holds back is booked as `withheld`, as the guild limits already do.
- **Player text**: the Guilds tab's "Reputation this turn" hover ends with "Recruiting X pays this
  guild." in the reader's race. Help page 2's mission bullet now reads "Every mission pays every
  guild. Hover Reputation this turn to see which recruits pay a guild." First drafted into each
  guild's description, which pushed the header tooltip to 11 lines against the harness's ceiling
  of 10 (description, upkeep, rival and halls lines share it); the earnings hover measures 6.

## Rulings (author, this session)

1. **Match what a unit is, not a key list**, so modded units pay too.
2. **Chaos Dwarfs** as approved: Sorcerer-Prophets to the Temple, Labourers to the Overseers, the
   Siege Giant to the Slavers.
3. **Hall family wins**: a guild hall's own unit pays that hall's guild, every variant of it (all
   Lammasu to the Temple, both Wolf Raiders to the Brass Tablets, both Chaos Dwarf Warriors to
   the Overseers, Cutthroats to the Slavers). This overrode four cells of the first approved CHD
   table. `HALL_FALLBACK` units are deliberately NOT held to it: they are base-game line units
   (Crossbowmen, Swordsmen, Quarrellers...) and the ruling would hand every one of them to one
   guild.
4. **Scope (b)**: map all nine races before anything ships.

## How it is built

- **Why caste and class together.** `land_units.class` cannot tell a monster from infantry: CA
  files every monster, the vanilla Giant and every Bull Centaur as `inf_mel` (read out of
  `db.pack`, not the cache), and every Chaos Dwarf war machine as `chariot`. `main_units.caste`
  can, but gives Bull Centaurs and Wolf Raiders the same `melee_cavalry`. "Cavalry caste and class
  `inf_mel`" is a Bull Centaur's body, which is how the modded Temple Guard
  (`derpy_chd_temple_guard`, checked in the live `derpy_units_vraznak.pack`) pays the Temple
  with no key listed anywhere.
- `zzz_derpy_guilds.lua`, between `-- BEGIN RECRUIT ROUTES` and `-- END RECRUIT ROUTES`:
  `GG.CASTES` (four caste groups), `GG.RECRUIT_ROUTES[culture].units|characters` (ordered rules;
  first fit wins; `key` is a plain substring of the unit or subtype key; a guild of `false` pays
  nothing on purpose), and `GG.recruit_guild`. Then `GG.RECRUIT_DOUBLE` and `GG.on_recruit`. The
  gate is `GG.culture_of`, which answers nil for an uncovered faction; an explicit `GG.covered`
  guard there was redundant (its mutant survived) and was removed. Listeners `gg_recruit_unit`
  and `gg_recruit_character` in `GG.register`, gated on `GG.covered` before any load or save
  because both events fire for every faction in the campaign; that gate is a cost guard with no
  observable effect, so no test can fail on it.
- `GG.save_gain` writes `rec_<guild>` after the guild keys, in `GG.GUILDS` order (never `pairs`).
- Settings: `rate_recruit`, `cap_recruit` in `GG.TUNE_DEFAULTS`, appended to `GG.TUNE_ORDER`, in
  all three presets, and in the MCT file's `RATES`, `CAPS` (which now takes an optional tooltip)
  and `PRESET_OWNED`.
- `zzz_derpy_guilds_ui.lua`: `GGUI.earned_tip` appends `GGUI.loc("recruit_<guild>")` only when it
  resolves (the fallback is the bare key).
- `tools/gen_great_guilds.py`: `RECRUIT_SAYS[tag][guild]` (the words), `recruit_sentence`, loc
  rows `derpy_gg_recruit_<guild><tag>` (63) and `derpy_gg_src_recruits<tag>`.
  `check_recruit_routes()` runs the SHIPPED block under lua.exe against every race's vanilla
  roster (`_race_roster` of the hall availability set) and permitted subtypes, and refuses: a
  covered culture with no routes, an unknown guild, caste group or agent type, a `key` with a Lua
  pattern character or matching no vanilla unit/subtype of that race, a hall unit paying another
  guild, and a guild paid with no `RECRUIT_SAYS` words (or words for a guild never paid).
  `recruit_world()` is the ledger below.

## Checks

- `luac -p` on the model and UI. Harness: `harness ok`; bounty harness ok.
- New harness blocks, driven through the handlers with exactly the accessors scripting_doc lists
  (UnitTrained: `unit` -> `faction`, `unit_key`, `unit_caste`, `unit_class`; CharacterRecruited:
  `character` -> `faction`, `character_subtype_key`, `character_type_key`, `is_caster`), measured
  as Reputation that moved: every CHD row, a modded Bull Centaur and a modded wolf rider, the
  uncovered-race gate, the limit (whole, partial and the Daemonsmiths), reload, turn reset, both
  settings through `pack_tune`/`unpack_tune`, a `false` rule, the ledger, and the hover text for
  three races plus no bare key for the generic flavour.
- `mutate_guilds.py`: 18 new mutants (16 model, 2 UI), all caught. Full run: 252 of 257 caught, no survivors; the other 5 are UI anchors ("the footer showing the ground guild's favour off another guild", "the Buy caption red only when favour is the first reason", "a cooldown written as 7t", "the race's inset left out of the room", "the gap left out of the room") that matched nothing in the LIVE pack either - stale since the 2026-10-09 antislop pass, so mutate_guilds.py --selftest was already failing. Re-aimed later the same day at the code as it now ships: the footer's `select(2, GG.get(faction, g))`, the cooldown's `GGUI.count(...)`, the header room's `inset` local; the Buy caption is no longer recoloured, so that mutant became "a Buy short of favour left live" (`set_live(btn, true)`). All five caught by harness assertions; `--selftest` ok, 257 anchored. Gap left open: no mutant covers the Small-file inset charge `math.max(1, 1 / GGUI.F)`, and the header-room test never varies `GGUI.F`.
- `gen_great_guilds.py --check` exit 0; `--selftest` ok, including five planted recruit-route
  faults (typo'd key, hall unit sent elsewhere, pattern character, unknown caste group, guild
  paid with no words), each reported.
- Previews: Help page 2 for CHD and the Empire; the full panel for all eight other races
  (`--flavour`), whose harness run includes the ten-line tooltip check. All nine exit 0.

## Not done

1. **The author reviews the eight draft tables below** (the CHD one is approved). Calls most
   worth a look:
   - Empire: the cults of Ulric (Teutogen Guard, Warriors of Ulric, Wolf-kin), Flagellants,
     Volkmar and the Arch Lector fall to the Greatswords; Warrior Priests and Priests of Ulric pay
     nothing (the Empire's temple guild is the Colleges of Magic, not the church).
   - Dwarfs: Runesmiths and Runelords to the Ancestor Temples, not the Engineers' Guild (their
     rivals in lore).
   - Bretonnia: Men-at-Arms and every other foot soldier to the Crusaders.
   - Cathay: the line regiments to the Punitive Host; guardian lions and the Moon Bird to the
     Celestial Temples.
   - Kislev: Hag Witches pay nothing; war sleds and Little Grom to the Ungol Raiders.
   - Dark Elves: no guild takes the beasts (hydras, manticores, Kharibdyss, dragons, harpies) or
     the Slaanesh units; the Bloodwrack to the Brides of Khaine.
   - High Elves: the Phoenix Guard (both the Loremasters' and the Cult's hall unit) to the Cult;
     dragons, eagles, Treemen and the sea creatures pay nothing.
   - Skaven: Clan Pestilens (monks, censers, Plagueclaw, Pusbags, the Cauldron, plague priests)
     pays nothing; Stormfiends to the Moulder Breeders.
   - Every race: units a landmark trains from another race (Animated Hulks, Black Ark Corsairs,
     Tiranoc Chariots, giants, Fimir) fall into that race's caste fallbacks or pay nothing.
2. **In game**, before trusting it: that `UnitTrained` and `CharacterRecruited` reach AI factions
   (`ResearchCompleted` turned out never to; CA's own scripts filter both by `is_human`, which
   suggests they do, but that is not proof), and that `unit:unit_class()` returns the
   `land_units` class the Bull Centaur rule reads. Turn on the MCT debug log, recruit one Bull
   Centaur and one Overseer, end the turn, and read the `recruit <faction> <key> caste=...
   class=... -> <guild>` lines `GG.on_recruit` writes: Bull Centaurs must read
   `caste=melee_cavalry class=inf_mel -> temple`, and lines for AI Chaos Dwarf factions must
   appear after the AI round.
3. Then: upload (the Workshop folder holds `190DA0F2`), the repo's CHANGELOG, sync and push.
   The repo's `docs/DEVELOPMENT.md` is already updated locally (section 2).

## The draft tables (generated from the shipped rules)

### Chaos Dwarfs

| Guild | Units | Heroes and lords |
|---|---|---|
| The Brass Tablets | Hobgoblin Wolf Raiders (Bows), Hobgoblin Wolf Raiders (Spears) | Convoy Overseer |
| The Immortals | Black Ark Corsairs (Handbows), Chaos Dwarf Blunderbusses, Infernal Guard, Infernal Guard (Fireglaives), Infernal Guard (Great Weapons), Infernal Ironsworn | Infernal Castellan |
| The Daemonsmiths | Animated Hulks, Bale Taurus, Bloated Corpse, Deathshrieker Rocket Launcher, Dreadquake Mortar, Great Taurus, Hellcannon, Hobgoblin Bolt Thrower, Iron Daemon, Iron Daemon – Dreadquake Mortar, K'daai Destroyer, K'daai Fireborn, Magma Cannon, Skullcracker, Skullcracker – Dreadquake Mortar | Daemonsmith Sorcerer (Death), Daemonsmith Sorcerer (Fire), Daemonsmith Sorcerer (Hashut), Daemonsmith Sorcerer (Metal) |
| The Khanate | Hobgoblin Archers, Hobgoblin Sneaky Gits | Legendary Hero `wh3_dlc23_chd_gorduz_backstabber` |
| The Overseers | Chaos Dwarf Warriors, Chaos Dwarf Warriors (Great Weapons), Goblin Labourers, Orc Labourers | Overseer |
| The Slavers | Chaos Siege Giant, Hobgoblin Cutthroats | - |
| The Temple of Hashut | Bull Centaur Renders, Bull Centaur Renders (Dual Axes), Bull Centaur Renders (Great Weapons), Lammasu | Bull Centaur Taur'ruk, Sorcerer-Prophet (Death), Sorcerer-Prophet (Fire), Sorcerer-Prophet (Hashut), Sorcerer-Prophet (Metal) |
| *pays nothing* | - | - |

### Empire

| Guild | Units | Heroes and lords |
|---|---|---|
| The Merchant Guilds | Pistoliers | - |
| The Greatswords | Archers, Black Ark Corsairs (Handbows), Crossbowmen, Darkshards, Demigryph Knights, Demigryph Knights (Halberds), Empire Knights, Flagellants, Foot Squires, Greatswords, Handgunners, Hochland Long Rifles, Knights Panther, Knights of the Black Rose, Knights of the Blazing Sun, Knights of the White Wolf, Nuln Ironsides, Reiksguard, Spearmen, Spearmen (Shields), Swordsmen, Teutogen Guard, Warriors of Ulric, Wolf-kin | Arch Lector, Captain, Empire Captain, General of the Empire, Legendary Hero `wh3_dlc25_emp_theodore_bruckner`, Legendary Hero `wh3_dlc25_neu_gotrek_hero`, Legendary Lord `wh_dlc04_emp_volkmar`, Legendary Lord `wh_main_emp_karl_franz`, Lord `wh_main_teb_lord`, Seneschal, `wh_main_emp_lord_spawned_army` |
| The Engineers' School | Great Cannons, Helblaster Volley Guns, Helstorm Rocket Battery, Land Ship, Mortars, Outriders, Outriders (Grenade Launchers), Steam Tank, Steam Tank (Volley Gun), Tiranoc Chariots, War Wagons, War Wagons (Mortars) | `wh3_dlc25_emp_engineer`, `wh3_dlc25_emp_master_engineer` |
| The Thieves' Guild | Hunting Hounds, Huntsmen | Huntsman General, Legendary Lord `wh2_dlc13_emp_cha_markus_wulfhart`, Witch Hunter, Wulfhart's Hunter |
| The Masons' Guild | Halberdiers | - |
| The Free Companies | Free Company Militia | - |
| The Colleges of Magic | Celestial Hurricanum, Luminark of Hysh | Amber Wizard, Amethyst Wizard, Bright Wizard, Celestial Wizard, Gold Wizard, Grey Wizard, Jade Wizard, Legendary Hero `wh3_dlc23_neu_ulrika`, Legendary Lord `wh2_pro08_neu_gotrek`, Legendary Lord `wh3_dlc25_emp_elspeth_von_draken`, Legendary Lord `wh_main_emp_balthasar_gelt`, Light Wizard, `wh3_dlc29_emp_gold_wizard_general` |
| *pays nothing* | Animated Hulks, Bloated Corpse, Bone Giant, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Norscan Giant | Priest of Ulric, Warrior Priest, `wh3_dlc29_emp_cha_emil_valgeir` |

### Dwarfs

| Guild | Units | Heroes and lords |
|---|---|---|
| The Merchant Clans | Thunderers, Thunderers (Grudge-Rakers) | - |
| The Hammerers | Black Ark Corsairs (Handbows), Dwarf Warriors, Dwarf Warriors (Great Weapons), Foot Squires, Hammerers, Ironbreakers, Longbeards, Longbeards (Great Weapons), Quarrellers, Quarrellers (Great Weapons) | Great Axe Thane, Legendary Hero `wh3_dlc25_dwf_garagrim_ironfist`, Legendary Lord `wh2_dlc17_dwf_thorek`, Legendary Lord `wh3_dlc25_dwf_malakai_makaisson`, Legendary Lord `wh_dlc06_dwf_belegar`, Legendary Lord `wh_main_dwf_thorgrim_grudgebearer`, Legendary Lord `wh_main_dwf_ungrim_ironfist`, Legendary Lord `wh_pro01_dwf_grombrindal`, Lord `wh3_dlc25_dwf_lord_mikael_leadstrong`, Lord `wh_main_dwf_lord`, Thane |
| The Engineers' Guild | Bolt Throwers, Cannons, Flame Cannons, Goblin Hewers, Grudge Throwers, Gyrobombers, Gyrocopters, Gyrocopters (Brimstone Guns), Irondrakes, Irondrakes (Trollhammer Torpedoes), Organ Guns, Thunderbarge, Tiranoc Chariots | Master Engineer |
| The Rangers | Bugman's Rangers, Rangers, Rangers (Great Weapons) | - |
| The Miners' Guild | Miners, Miners (Blasting Charges) | - |
| The Grudge-Settlers | Doomseekers, Slayer Pirates, Slayers | - |
| The Ancestor Temples | Giant Slayers | Daemon Slayer, Dragon Slayer, Runelord, Runesmith, `wh3_dlc25_dwf_daemon_slayer_spawned_army` |
| *pays nothing* | Animated Hulks, Bloated Corpse, Bone Giant, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Norscan Giant | Legendary Hero `wh3_dlc23_neu_ulrika` |

### Bretonnia

| Guild | Units | Heroes and lords |
|---|---|---|
| The Wine Merchants | Mounted Yeomen, Mounted Yeomen Archers | - |
| The Knights Errant | Knights Errant, Knights of the Realm, Pegasus Knights, Royal Hippogryph Knights, Royal Pegasus Knights | Legendary Hero `wh_dlc07_brt_green_knight`, Legendary Lord `wh2_dlc14_brt_repanse`, Legendary Lord `wh_dlc07_brt_alberic`, Legendary Lord `wh_main_brt_louen_leoncouer`, Legendary Paladin `wh2_dlc14_brt_henri_le_massif`, Lord `wh_main_brt_lord`, Paladin |
| The Grail Damsels | Grail Reliquae | Damsel (Beasts), Damsel (Heavens), Damsel (Life), Legendary Lord `wh_dlc07_brt_fay_enchantress`, Prophetess (Beasts), Prophetess (Heavens), Prophetess (Life) |
| The Forest Outlaws | Peasant Bowmen, Peasant Bowmen (Fire Arrows), Peasant Bowmen (Pox Arrows) | - |
| The Castle-Wrights | Blessed Field Trebuchets, Field Trebuchets | - |
| The Crusaders | Battle Pilgrims, Foot Squires, Men-at-Arms, Men-at-Arms (Polearms), Men-at-Arms (Shields), Peasant Mob, Spearmen-at-Arms, Spearmen-at-Arms (Shields) | - |
| The Grail Pilgrims | Grail Guardians, Grail Knights, Questing Knights | - |
| *pays nothing* | Animated Hulks, Bloated Corpse, Bone Giant, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Norscan Giant, Tiranoc Chariots | - |

### Cathay

| Guild | Units | Heroes and lords |
|---|---|---|
| The Caravan Masters | Peasant Horsemen | Caravan Master, Sawai Mercenary |
| The Dragon Guard | Celestial Dragon Crossbows, Celestial Dragon Guard | Celestial General (Yang), Celestial General (Yin), Legendary Hero `wh3_cp1_cth_cha_taoyan`, Legendary Hero `wh3_dlc24_cth_saytang_the_watcher`, Legendary Lord `wh3_cp1_cth_bhashiva`, Lord Magistrate (Garrison Commander), Lord Magistrate (Yang), Lord Magistrate (Yin), `wh3_cp1_cth_sawai`, `wh3_dlc24_cth_gate_master` |
| The Imperial Academy | Fire Rain Rocket Battery, Grand Cannons, Sky Lantern, Sky-junk, Tiranoc Chariots, Wu Xing War Compass, Zhangu War Drum | Alchemist, Astromancer |
| The Crow Society | Onyx Crowmen | `wh3_cp1_cth_clawspeaker_beasts`, `wh3_cp1_cth_clawspeaker_life`, `wh3_cp1_cth_clawspeaker_shadows` |
| The Bastion Builders | Jade Warrior Crossbows, Jade Warrior Crossbows (Shields), Jade Warriors, Jade Warriors (Halberds) | - |
| The Punitive Host | Black Ark Corsairs (Handbows), Crane Gunners, Great Longma Riders, Iron Claw Tiger Warriors, Iron Hail Gunners, Jade Lancers, Nan-Gau Grenadiers, Peasant Archers, Peasant Long Spearmen, Tiger Warrior Stalkers, Tiger Warriors | - |
| The Celestial Temples | Celestial Lion, Great Moon Bird, Jade Lion, Jet Lion, Terracotta Sentinel | Dragon-Blooded Shugengan Lord (Yang), Dragon-Blooded Shugengan Lord (Yin), Legendary Lord `wh3_dlc24_cth_yuan_bo`, Legendary Lord `wh3_main_cth_miao_ying`, Legendary Lord `wh3_main_cth_zhao_ming` |
| *pays nothing* | Animated Hulks, Bloated Corpse, Bone Giant, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Norscan Giant | - |

### Kislev

| Guild | Units | Heroes and lords |
|---|---|---|
| The Erengrad Merchants | Streltsi | - |
| The Tzar Guard | Black Ark Corsairs (Handbows), Gryphon Legion, Kislevite Warriors, Tzar Guard, Tzar Guard (Great Weapons), Winged Lancers | Boyar, Druzhina, Legendary Lord `wh3_main_ksl_boris`, `wh3_main_ksl_ataman` |
| The Ice Court | Frost Wyrm, Ice Guard (Glaives), Ice Guard (Swords), Snow Leopard | Frost Maiden (Ice), Frost Maiden (Tempest), Ice Witch (Ice), Ice Witch (Tempest), Legendary Hero `wh3_dlc23_neu_ulrika`, Legendary Lord `wh3_dlc24_ksl_mother_ostankya`, Legendary Lord `wh3_main_ksl_katarin` |
| The Oblast Smugglers | Akshina Ambushers | - |
| The Stanitsa Builders | Armoured Kossars, Armoured Kossars (Great Weapons), Kossars, Kossars (Spears) | - |
| The Ungol Raiders | Heavy War Sleds, Horse Archers, Kossovite Dervishes, Light War Sleds, Little Grom, Tiranoc Chariots | - |
| The Great Orthodoxy | Elemental Bear, Feral Bears, Feral Ice Bears, War Bear Riders | Legendary Hero `wh3_dlc24_ksl_the_golden_knight`, Legendary Lord `wh3_main_ksl_kostaltyn`, Patriarch |
| *pays nothing* | Animated Hulks, Bloated Corpse, Bone Giant, Cave Bats, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Giant Spiders, Incarnate Elemental of Beasts, Norscan Giant, Spider Hatchlings, The Things in the Woods | Hag Witch (Beasts), Hag Witch (Death), Hag Witch (Hag), Hag Witch (Shadows) |

### Dark Elves

| Guild | Units | Heroes and lords |
|---|---|---|
| The Karond Kar Traders | Dark Riders, Dark Riders (Repeater Crossbows), Dark Riders (Shields) | - |
| The Black Guard | Black Guard of Naggarond, Cold One Chariots, Cold One Dread Knights, Cold One Knights | Dreadlord (Sword & Crossbow), Dreadlord (Sword & Shield), High Beastmaster, Legendary Dragon `wh2_dlc15_hef_black_dragon_boss_imrik`, Legendary Lord `wh2_dlc14_def_malus_darkblade`, Legendary Lord `wh2_twa03_def_rakarth`, Master |
| The Convent of Ghrond | Doomfire Warlocks | Legendary Lord `wh2_main_def_malekith`, Legendary Lord `wh2_main_def_morathi`, Sorceress (Beasts), Sorceress (Dark), Sorceress (Death), Sorceress (Fire), Sorceress (Shadows), Supreme Sorceress (Beasts), Supreme Sorceress (Dark), Supreme Sorceress (Death), Supreme Sorceress (Fire), Supreme Sorceress (Shadows) |
| The Khainite Assassins | Shades, Shades (Dual Weapons), Shades (Greatswords) | Khainite Assassin |
| The Naggarond Builders | Bleakswords, Darkshards, Darkshards (Shields), Dreadspears, Foot Squires, Reaper Bolt Throwers | - |
| The Black Ark Corsairs | Black Ark Corsairs, Black Ark Corsairs (Handbows) | Black Ark, Legendary Lord `wh2_dlc11_def_lokhir`, The Blessed Dread |
| The Brides of Khaine | Bloodwrack Medusa, Bloodwrack Shrine, Har Ganeth Executioners, Sisters of Slaughter, Witch Elves | Death Hag, Legendary Lord `wh2_dlc10_def_crone_hellebron` |
| *pays nothing* | Animated Hulks, Black Dragon, Bloated Corpse, Bone Giant, Daemonettes of Slaanesh, Devotees of Slaanesh, Devotees of Slaanesh (Crossbows), Exalted Daemonettes of Slaanesh, Feral Manticore, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Harpies, Kharibdyss, Norscan Giant, Scourgerunner Chariots, Tiranoc Chariots, War Hydra | Dreadlord (Sword & Crossbow), Druchii Anointed |

### High Elves

| Guild | Units | Heroes and lords |
|---|---|---|
| The Lothern Merchants | Lothern Sea Guard, Lothern Sea Guard (Shields), Lothern Skycutters, Lothern Skycutters (Bolt Throwers), Ship's Company | Dragonship Admiral, Sea Helm, `wh3_dlc27_hef_dragonship_captain_02`, `wh3_dlc27_hef_dragonship_captain_03`, `wh3_dlc27_hef_dragonship_captain_04`, `wh3_dlc27_hef_dragonship_captain_05` |
| The Swordmasters | Dragon Princes, Ithilmar Chariots, Knights of Tor Gaval, Lion Chariots of Chrace, Silver Helms, Silver Helms (Shields), Swordmasters of Hoeth, Tiranoc Chariots, White Lions of Chrace | Legendary Beast `wh2_dlc10_nor_phoenix_flamespyre_boss`, Legendary Lord `wh2_dlc15_hef_imrik`, Legendary Lord `wh2_main_hef_tyrion`, Legendary Lord `wh3_dlc27_hef_aislinn`, Noble, Noble (Militia Commander), Prince, Princess, `wh3_dlc27_hef_caradryan` |
| The Loremasters | - | Archmage (Beasts), Archmage (Death), Archmage (Fire), Archmage (Heavens), Archmage (High), Archmage (Life), Archmage (Light), Archmage (Metal), Archmage (Shadows), Legendary Lord `wh2_dlc10_hef_alarielle`, Legendary Lord `wh2_dlc15_hef_eltharion`, Legendary Lord `wh2_main_hef_teclis`, Loremaster of Hoeth, Mage (Beasts), Mage (Death), Mage (Fire), Mage (Heavens), Mage (High), Mage (Life), Mage (Light), Mage (Metal), Mage (Shadows), Mist Mage |
| The Shadow Warriors | Shadow Warriors, Shadow-walkers | Hand of the Shadow Crown, Legendary Lord `wh2_dlc10_hef_alith_anar` |
| The Ulthuan Masons | Archers, Archers (Light Armour), Athel Tamarha Faithbearers, Black Ark Corsairs (Handbows), Dryads, Eagle Claw Bolt Throwers, Foot Squires, Rangers, Sentinels of Astaril, Silverin Guard, Sisters of Avelorn, Spearmen, Spire Guard of Tor Yvresse, The Skyhawks | - |
| The Ellyrian Reavers | Ellyrian Reaver Archers, Ellyrian Reavers | - |
| The Cult of Asuryan | Arcane Phoenix, Flamespyre Phoenix, Frostheart Phoenix, Phoenix Guard | - |
| *pays nothing* | Animated Hulks, Bloated Corpse, Bone Giant, Fimir Warriors, Fimir Warriors (Great Weapons), Giant, Great Eagle, Merwyrm, Moon Dragon, Norscan Giant, Oceanids, Sea Elemental, Star Dragon, Sun Dragon, Tree Kin, Treeman, War Lions of Chrace | Handmaiden |

### Skaven

| Guild | Units | Heroes and lords |
|---|---|---|
| The Warpstone Traders | Skavenslave Slingers, Skavenslave Spears, Skavenslaves | - |
| The Stormvermin | Stormvermin (Halberds), Stormvermin (Swords & Shields) | Chieftain, Legendary Hero `wh2_dlc16_skv_ghoritch`, Legendary Lord `wh2_main_skv_queek_headtaker`, Warlord, Warlord Underling |
| The Skryre Warlocks | Death Globe Bombardiers, Doom-Flayers, Doomwheel, Poisoned Wind Globadiers, Poisoned Wind Mortars, Ratling Guns, Warp Lightning Cannons, Warp-Doom Magma-Cannon, Warp-Grinders, Warpfire Throwers, Warplock Jezzails | DOOOOM! Engineer, Legendary Lord `wh2_dlc12_skv_ikit_claw`, Warlock Engineer, Warlock Master, Warlock Master Underling |
| The Eshin Assassins | Death Runners, Eshin Triads, Gutter Runner Slingers, Gutter Runner Slingers (Poison), Gutter Runners, Gutter Runners (Poison), Night Runners, Night Runners (Slings) | Assassin, Eshin Sorcerer, Legendary Lord `wh2_dlc14_skv_deathmaster_snikch`, Master Assassin, Master Assassin Underling |
| The Moulder Breeders | Brood Horror, Hell Pit Abomination, Mutant Rat Ogre, Rat Ogres, Stormfiends (Doom-flayer Gauntlets), Stormfiends (Grinderfists), Stormfiends (Ratling Cannons), Stormfiends (Shock Gauntlets), Stormfiends (Warpfire Projectors), Stormfiends (Windlaunchers), Wolf Rats, Wolf Rats (Poison) | Legendary Lord `wh2_dlc16_skv_throt_the_unclean`, Packmaster |
| The Slave-Masters | Clanrat Spears, Clanrat Spears (Shields), Clanrats, Clanrats (Shields) | - |
| The Grey Seers | - | Grey Seer (Plague), Grey Seer (Ruin), Grey Seer Underling, Legendary Lord `wh3_dlc29_skv_skreech_verminking_general`, Verminlord Corruptor, Verminlord Deceiver, Verminlord Warbringer, Verminlord Warpseer, `wh3_dlc29_skv_skreech_verminking`, `wh3_dlc29_skv_thanquol` |
| *pays nothing* | Animated Hulks, Black Ark Corsairs (Handbows), Bloated Corpse, Bone Giant, Cauldron of a Thousand Poxes, Fimir Warriors, Fimir Warriors (Great Weapons), Foot Squires, Giant, Norscan Giant, Plague Monk Censer Bearers, Plague Monks, Plagueclaw Catapults, Pusbags, Tiranoc Chariots | Legendary Hero `wh2_dlc16_skv_ghoritch_boss`, Legendary Lord `wh2_dlc09_skv_tretch_craventail`, Legendary Lord `wh2_main_skv_lord_skrolk`, Pestilent Scheme Priest, Plague Priest |
