# The Great Guilds: Dark Elf and High Elf flavours - design

2026-09-24. **Approved the same day** ("yes, do A for 2, 3. only high elves"): the names
and text as written, Swordmasters for the High Elves, and no Wood Elves. Two more
flavours, built exactly the way the Bretonnia, Cathay and Kislev ones were
(`2026-09-24-great-guilds-brt-cth-ksl-design.md`). This file holds only the data.

The same request also gated the mod to the races it includes, and that part is already
built. `GG.covered` now refuses any culture outside `GG.FLAVOURED`, even when a human
plays it, and `GGUI.place_opener` creates no button for such a player. Tests for both
were watched failing first.

## 1. What stays the same

- Guild ids, rivalries (`brass`/`khanate`, `immortals`/`daemonsmiths`,
  `overseers`/`slavers`), mechanics, prices and effects.
- The Slave Tithe pays both races 3,000 gold. The Dark Elves' Slaves resource is kept per
  province, and script cannot reach a per-province pool
  (`wh3-faction-province-pool-unreachable`).
- **Limits:**
  - Guild names start with "The" and are 22 characters or fewer.
  - Ranks are 12 characters or fewer.
  - Service names are 21 characters or fewer, the longest any race ships.
  - `check_flavours` refuses "Hashut", "Zharr", "Dark Lands", "slave", "Hobgoblin",
    "Infernal" and "Daemon" anywhere in the text. That rules out the obvious Dark Elf
    word, so this draft says "captives", "thralls" and "Corsairs" instead.
- **Lore words, checked against CA's own loc (2026-09-24):**
  - **Dark Elves:** Karond Kar, Naggarond, Black Ark, Corsair, Khaine, Khainite, Ghrond,
    the Convent, Morathi, Malekith, Witch King, Dreadspear, Highborn, Dreadlord, Thrall
    and Tyrant.
  - **High Elves:** Lothern, Hoeth, White Tower, Loremaster, Swordmaster, Nagarythe,
    Shadow Warrior, Ellyrian Reaver, Ulthuan, Sea Lord, Phoenix King, Warden, Citizen and
    Regent.
  - **Absent from CA's loc, so not used:** "Kinsman" and "High Prince" (no hits).
    "Merchant Prince" (3 hits, none of them the High Elves).

## 2. Tags and cultures

| Tag | Culture key | Feed offset | Event pictures | Hire unit |
|---|---|---|---|---|
| `_def` | `wh2_main_def_dark_elves` | 70 | `def/` (all four present) | `wh2_main_def_inf_black_guard_0` Black Guard of Naggarond - tier 3, 1,300 gold, 100 men |
| `_hef` | `wh2_main_hef_high_elves` | 80 | `hef/` (all four present) | `wh2_main_hef_inf_swordmasters_of_hoeth_0` Swordmasters of Hoeth - tier 3, 1,250 gold, 100 men (section 7) |

- **Comparison hire units:** Hammerers (tier 3, 1,200 gold) and Tzar Guard (tier 3,
  1,100 gold). Black Guard is the most expensive hire in the mod, by 100 gold.
- **Bounty pictures:** both races have their own, `def/generic` and `hef/generic`, which
  CA's missions use. No override is needed.
- **Feed offsets:** 70 and 80 on bases 5001-5004 reach 5084. No vanilla feed record
  sits in that range.

## 3. Names

| Id (what it earns from) | Dark Elves | High Elves |
|---|---|---|
| brass (trade and treasury income) | The Karond Kar Traders | The Lothern Merchants |
| immortals (battles won) | The Black Guard | The Swordmasters |
| daemonsmiths (technologies) | The Convent of Ghrond | The Loremasters |
| khanate (agent actions) | The Khainite Assassins | The Shadow Warriors |
| overseers (buildings) | The Naggarond Builders | The Ulthuan Masons |
| slavers (sacking, razing) | The Black Ark Corsairs | The Ellyrian Reavers |

**The rival pairs read as real frictions:**
- **Dark Elves:**
  - traders against assassins;
  - the Witch King's guard against his mother's sorceresses;
  - builders against the raiders who bring the thralls home.
- **High Elves:**
  - Lothern's open trade against Nagarythe's secret war;
  - the blade against the book, the two orders of the White Tower;
  - masons against riders.

**Ranks 1-5:**
- Dark Elves: Thrall / Corsair / Highborn / Dreadlord / Tyrant
- High Elves: Citizen / Warden / Noble / Prince / Regent

**Services**, in SERVICES order (rank 2 / 3 / 4 per guild):

| Key | Dark Elves | High Elves |
|---|---|---|
| caravan_levy | Market Tithes | Lothern Tolls |
| writ_monopoly | The Witch King's Seal | The Phoenix Charter |
| long_ledger | The Karond Kar Ledger | The Sea Lanes |
| oathbound_draft | Call the Dreadspears | Call the Citizen Levy |
| hire_immortals | Hire the Black Guard | Hire the Swordmasters |
| astragoths_levy | Malekith's Summons | Summons of the Throne |
| forge_rite | Rites of the Convent | Lessons of Hoeth |
| bound_blueprint | Secrets of Ghrond | From the White Tower |
| bound_ordnance | Morathi's Favour | The Loremasters' Gift |
| hobgoblin_eyes | Eyes in the Shadows | Eyes of Nagarythe |
| knife_in_dark | A Knife for Khaine | An Arrow from Shadow |
| khans_price | The Assassins' Price | Whispers at Court |
| lash_the_gangs | Drive the Thralls | Citizen Labour |
| raise_ziggurat | Raise the Tower | Raise the Spire |
| works_of_zharr | Works of Naggarond | Works of Ulthuan |
| coffle_drive | Corsair Raids | Reaver Raids |
| slave_tithe | The Corsairs' Share | The Reavers' Share |
| great_coffle | The Black Ark Raid | Ulthuan's Vengeance |

## 4. Guild descriptions (flavour half)

**Dark Elves**
- brass: The counting-towers of Karond Kar, where every captive the Black Arks bring home
  is bought and sold. Every Highborn owes them something.
- immortals: The Witch King's own guard, sworn to Naggarond and nothing else. Their oath
  is lent only to those Malekith favours.
- daemonsmiths: The sorceresses of Ghrond, who keep the dark arts and answer to Morathi
  alone. They part with what they know slowly, and never for free.
- khanate: Assassins of the Temple of Khaine, who kill for the Lord of Murder and for
  pay. They work for anyone, including against you.
- overseers: The builders of every tower and wall in Naggaroth, raised by thralls in the
  cold. They know where each one is weak.
- slavers: The crews of the Black Arks, who raid every shore they can reach. Their pay is
  what they carry home.

**High Elves**
- brass: The merchant houses of Lothern, whose ships carry the trade of Ulthuan to every
  coast. Every Sea Lord owes them something.
- immortals: The warriors of the White Tower of Hoeth, sworn to the blade for centuries.
  Their oath is lent to whoever the Tower favours.
- daemonsmiths: The Loremasters of Hoeth, who keep the greatest library in the world.
  They teach it slowly, and never for free.
- khanate: The scouts of Nagarythe, who fight a secret war nobody else sees. They work
  for anyone, including against you.
- overseers: The masons who raise every tower and sea wall in Ulthuan, and who know where
  each one is weak.
- slavers: The riders of Ellyrion, who range far past the borders and bring back what
  they find. Their pay is what they carry home.

## 5. The six hand-written service blurbs

The second sentence of each is mechanical and matches the other races word for word.

**Dark Elves**
- caravan_levy: The Karond Kar Traders take their cut of every sale. Adds 2,500 gold to
  your treasury at once.
- hire_immortals: A company already sworn and already armed. Adds one unit of Black
  Guard of Naggarond to an army of your choosing.
- bound_blueprint: The Convent of Ghrond parts with a secret, once. Completes the
  technology you are currently researching, at once.
- hobgoblin_eyes: The Khainite Assassins sell what they have seen from the shadows.
  Reveals one region through the shroud, permanently.
- raise_ziggurat: The Naggarond Builders drive the thralls through the night. Upgrades
  one of your buildings to its next level at once, and free.
- slave_tithe: The Black Ark Corsairs send home your share of the plunder. Adds 3,000
  gold to your treasury.

**High Elves**
- caravan_levy: The Lothern Merchants collect on every ship that docks. Adds 2,500 gold
  to your treasury at once.
- hire_immortals: A company already sworn and already armed. Adds one unit of
  Swordmasters of Hoeth to an army of your choosing.
- bound_blueprint: The Loremasters hand over work already done. Completes the technology
  you are currently researching, at once.
- hobgoblin_eyes: The Shadow Warriors share what they have seen. Reveals one region
  through the shroud, permanently.
- raise_ziggurat: The Ulthuan Masons work through the night. Upgrades one of your
  buildings to its next level at once, and free.
- slave_tithe: The Ellyrian Reavers send back your share of the take. Adds 3,000 gold to
  your treasury.

## 6. Bounties (title, text)

Each guild's bounty kind is fixed:
- **Take it standing:** brass and overseers.
- **Kill a named lord:** immortals and khanate.
- **Sack it:** daemonsmiths and slavers.

**Dark Elves**
- brass: Fresh Markets - The Karond Kar Traders want that town's trade in their ledgers.
  Take it standing.
- immortals: A Test of Blades - A general is being spoken of with respect. The Black
  Guard would like that corrected.
- daemonsmiths: Plunder the Lore - Whatever that place knows, the Convent wants. Bring it
  back in pieces.
- khanate: A Name for Khaine - The Assassins do not care how it is done, only that the
  name stops being used.
- overseers: A Tower Worth Taking - Take it whole. The Naggarond Builders want walls to
  raise higher, not rubble.
- slavers: A Harvest of Captives - Sack it. The Corsairs are owed, and that place can
  pay.

**High Elves**
- brass: Open the Harbour - The Lothern Merchants want that town's trade on their ships.
  Take it standing.
- immortals: A Lesson in Blades - A general is being spoken of with respect. The
  Swordmasters would like that corrected.
- daemonsmiths: Recover the Lore - Whatever that place knows, the Loremasters want kept
  safe. Bring it back in pieces.
- khanate: A Shadow Falls - The Shadow Warriors do not care how it is done, only that
  the name stops being used.
- overseers: Walls for Ulthuan - Take it whole. The Masons want walls to strengthen, not
  rubble.
- slavers: Reave It - Sack it. The Reavers are owed, and that place can pay.

## 7. The High Elves' hire unit - decided: A

| Option | Unit | Tier / cost / men | Reads as |
|---|---|---|---|
| A (recommended) | `wh2_main_hef_inf_swordmasters_of_hoeth_0` Swordmasters of Hoeth | 3 / 1,250 / 100 | The White Tower's warrior order, and the other half of the Loremasters' rivalry. Priced next to Hammerers. |
| B | `wh2_main_hef_inf_phoenix_guard` Phoenix Guard | 3 / 1,400 / 100 | Asuryan's silent guard. The strongest hire, but it becomes the dearest in the mod, and the guild would be renamed "The Phoenix Guard". |

The Dark Elves have one obvious answer. The alternative, Har Ganeth Executioners (tier 3,
1,150), serves Khaine's temple, which is the assassins' guild here and not the guard's.

## 8. Art (chosen at build time, same rules as before)

- **Icons:** seven per race, from CA's own building icons (44 Dark Elf and 77 High Elf
  candidates were rendered and looked at). Every pick below measures 98-100% one colour,
  which `make_guild_icons.py` requires.

  | Guild | Dark Elves | High Elves |
  |---|---|---|
  | brass | `dark_elves_port` (anchor) | `hef_foreign_trade_market` (market stall) |
  | immortals | `dark_elves_barracks` | `high_elves_barracks` |
  | daemonsmiths | `dark_elves_cold_ones` (a spired tower) | `high_elves_mages` (the White Tower) |
  | khanate | `dark_elves_hired_killers` | `high_elves_aesanar` (hood and arrows) |
  | overseers | `dark_elves_defence_major` | `high_elves_defence_major` |
  | slavers | `dark_elves_slaves` | `high_elves_stables` (horse and lance) |
  | crest | `dark_elves_worship` (Khaine's shrine) | `high_elves_chamber_of_the_phoenix_crown` |

  `dark_elves_sorcery` would suit the Convent better but measures 70%, so the tool
  refuses it.
  **As built:** the High Elf daemonsmiths and crest became `high_elves_embassy` and
  `hef_sea_patrol_outpost_beasts`. The two above read as boxes at 74px. See the
  handoff, section 2.
- **Grounds:** six windows each of `campaign_dark_elves1.png` and
  `campaign_high_elves1.png` (both in `ui.pack`), darkened to the Help tab's contrast
  gate.
- **Previews:** `preview_guilds_panel.py --flavour def|hef`.

## 9. Build and checks

These are the same steps and checks as the Bretonnia, Cathay and Kislev build, then pack,
deploy to `data/` and write a handoff. RPFM must be open to pack. **Owed in game, per
race:** start a campaign, open the panel, trigger one guild message, and confirm a
Lizardmen or Greenskin campaign shows no guilds button.
