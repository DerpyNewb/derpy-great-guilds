# The Great Guilds: Bretonnia, Cathay and Kislev flavours - design

2026-09-24. **Approved and built the same day** - see
`docs/sessions/HANDOFF_20260924_GUILDS_BRT_CTH_KSL.md`. This adds three more flavours in
exactly the shape of the Empire and Dwarf ones
(`2026-09-23-great-guilds-flavours-design.md`). All the machinery already exists and is
checked: tags, feed offsets, picture overrides, MCT renaming, and the text and length
checks. This file is the data.

## 1. What stays the same

- Guild ids, rivalries (`brass`/`khanate`, `immortals`/`daemonsmiths`,
  `overseers`/`slavers`), mechanics, prices and effects.
- The shared "Reputation accrues from..." earn sentences.
- The Slave Tithe pays 3,000 gold to all three races. None has a pooled resource that fits
  the way Oathgold fits the Dwarfs.
- **Limits:** every guild name starts with "The" and is 22 characters or fewer; ranks are
  12 or fewer. `check_flavours` refuses "Hashut", "Zharr", "Dark Lands", "slave",
  "Hobgoblin", "Infernal" and "Daemon" anywhere in the text.
- **Lore words** are checked against CA's own loc (2026-09-24). Bordeleaux, Errantry, the
  Ivory Road, Astromancers, the Great Bastion, Disharmony, Erengrad, stanitsa, Ungol,
  Druzhina, Boyar and Ataman all appear there. "Herrimault" and "Mandarin" do not, so
  neither is used.

## 2. Tags and cultures

| Tag | Culture key | Feed offset | Event pictures | Hire unit |
|---|---|---|---|---|
| `_brt` | `wh_main_brt_bretonnia` | 40 | `brt/` (all four present) | `wh_main_brt_cav_knights_of_the_realm` Knights of the Realm - tier 2, 950 gold, 60 men (section 7) |
| `_cth` | `wh3_main_cth_cathay` | 50 | `cth/` (all four present) | `wh3_main_cth_inf_dragon_guard_0` Celestial Dragon Guard - tier 3, 1,050 gold, 100 men |
| `_ksl` | `wh3_main_ksl_kislev` | 60 | `ksl/` (all four present) | `wh3_main_ksl_inf_tzar_guard_1` Tzar Guard (Great Weapons) - tier 3, 1,100 gold, 80 men |

- **Comparison hire units:** Greatswords (tier 3, 850 gold, 120 men) and Hammerers (tier
  3, 1,200 gold, 100 men).
- **Bounty picture:** Kislev has no `ksl/generic` mission picture. It gets a named one
  through the `mission_pic` override: `emp/generic`, which is what CA's own Kislev missions
  use (97 rows).

## 3. Names

| Id (what it earns from) | Bretonnia | Cathay | Kislev |
|---|---|---|---|
| brass (trade and treasury income) | The Wine Merchants | The Caravan Masters | The Erengrad Merchants |
| immortals (battles won) | The Knights Errant | The Dragon Guard | The Tzar Guard |
| daemonsmiths (technologies) | The Grail Damsels | The Imperial Academy | The Ice Court |
| khanate (agent actions) | The Forest Outlaws | The Crow Society | The Oblast Smugglers |
| overseers (buildings) | The Castle-Wrights | The Bastion Builders | The Stanitsa Builders |
| slavers (sacking, razing) | The Crusaders | The Punitive Host | The Ungol Raiders |

**The rival pairs read as real frictions:**
- Bretonnia: merchants against outlaws, knights against the Damsels, masons against
  crusaders.
- Cathay: caravans against court spies, soldiers against scholars, builders against the
  punitive host.
- Kislev: merchants against smugglers, the Tzar's guard against the witches, builders
  against raiders.

**Ranks 1-5:**
- Bretonnia: Peasant / Yeoman / Squire / Knight / Paladin
- Cathay: Commoner / Scholar / Official / Magistrate / Minister
- Kislev: Serf / Kossar / Druzhina / Boyar / Ataman

**Services**, in SERVICES order (rank 2 / 3 / 4 per guild):

| Key | Bretonnia | Cathay | Kislev |
|---|---|---|---|
| caravan_levy | Wine Duties | Caravan Tolls | Erengrad Tolls |
| writ_monopoly | Ducal Charter | Seal of Trade | Tzarina's Charter |
| long_ledger | The Vintners' Accord | The Ivory Road | The Erengrad Exchange |
| oathbound_draft | Call the Banners | Fresh Levies | Call the Druzhina |
| hire_immortals | Hire the Knights | Hire the Dragon Guard | Hire the Tzar Guard |
| astragoths_levy | The King's Summons | The Emperor's Mandate | The Tzarina's Levy |
| forge_rite | Lessons of the Lady | Hall of Scholars | Winter Lessons |
| bound_blueprint | The Lady's Revelation | Archive Scrolls | Secrets of the Ice |
| bound_ordnance | Vision of the Grail | The Celestial Charts | The Ice Queen's Favour |
| hobgoblin_eyes | Word from the Woods | Eyes of the Crows | Smugglers' Trails |
| knife_in_dark | Arrows from Cover | A Quiet Poison | A Knife in the Snow |
| khans_price | The Outlaws' Toll | Sow Disharmony | Sabotage the Sledges |
| lash_the_gangs | Feudal Labour | Conscript Labour | Before the Thaw |
| raise_ziggurat | Raise the Keep | Raise the Pagoda | Raise the Palisade |
| works_of_zharr | The Duke's Works | Works of the Bastion | Walls Against Chaos |
| coffle_drive | Spoils of Crusade | Punitive Raids | Steppe Plunder |
| slave_tithe | The Crusaders' Share | The Host's Share | The Riders' Share |
| great_coffle | The Errantry War | The Great Expedition | The Long Raid |

## 4. Guild descriptions (flavour half)

**Bretonnia**
- brass: The vintners and shipping houses of Bordeleaux, whose casks reach every court in
  the Old World. Every duke owes them something.
- immortals: Young knights sworn to prove themselves in battle. Whoever gives them the
  field earns their lances.
- daemonsmiths: Handmaidens of the Lady who keep the old lore of Bretonnia. They share it
  only with those they judge worthy.
- khanate: Poachers and cutpurses who live beyond the law in the deep forests. They will
  rob anyone, including you.
- overseers: The master masons who raise every keep and curtain wall in the dukedoms, and
  who know where each one is weak.
- slavers: Knights and men-at-arms back from the Errantry Wars, paid in what they carry
  home.

**Cathay**
- brass: The masters of the Ivory Road, whose caravans cross half the world and come back
  heavier. Every province pays their tolls.
- immortals: The Emperor's own warriors, sworn to the Celestial Court. Their oath is lent
  to whoever the Court favours.
- daemonsmiths: The scholars and astromancers who keep the Empire's learning. They teach
  it slowly, and never for free.
- khanate: Informers, poisoners and watchers who sell what they learn at court. They work
  for anyone, including against you.
- overseers: The engineers who keep the Great Bastion standing, and who know where every
  wall is weak.
- slavers: Soldiers sent beyond the Bastion to punish the Emperor's enemies. Their pay is
  what they bring back.

**Kislev**
- brass: The traders of Erengrad, whose ships and sledges carry furs south and gold
  north. Every boyar owes them something.
- immortals: The Tzar's own guard, the finest warriors in Kislev. Their oath can be lent,
  never broken.
- daemonsmiths: The witches of the Ice Court, who keep what the winter teaches. They part
  with it slowly, and never for free.
- khanate: Smugglers who know every trail across the oblast and every ear in every
  stanitsa. They work for anyone, including against you.
- overseers: The builders of every palisade and stanitsa that holds the north, and the
  only ones who know where each is weak.
- slavers: Horse-raiders of the steppe who ride for pay and plunder. Their ledger is
  measured in what they carry home.

## 5. The six hand-written service blurbs

The second sentence of each is mechanical and matches the other races word for word.

**Bretonnia**
- caravan_levy: The Wine Merchants collect the duties owed on every cask. Adds 2,500 gold
  to your treasury at once.
- hire_immortals: A lance of knights, already sworn and already horsed. Adds one unit of
  Knights of the Realm to an army of your choosing.
- bound_blueprint: The Grail Damsels share what the Lady has shown them. Completes the
  technology you are currently researching, at once.
- hobgoblin_eyes: The Forest Outlaws sell what they have seen from the trees. Reveals one
  region through the shroud, permanently.
- raise_ziggurat: The Castle-Wrights work through the night. Upgrades one of your
  buildings to its next level at once, and free.
- slave_tithe: The Crusaders send home your share of the spoils. Adds 3,000 gold to your
  treasury.

**Cathay**
- caravan_levy: The Caravan Masters collect on every road they travel. Adds 2,500 gold to
  your treasury at once.
- hire_immortals: A company already sworn and already armed. Adds one unit of Celestial
  Dragon Guard to an army of your choosing.
- bound_blueprint: The Imperial Academy hands over work already done. Completes the
  technology you are currently researching, at once.
- hobgoblin_eyes: The Crow Society sells what its crows have seen. Reveals one region
  through the shroud, permanently.
- raise_ziggurat: The Bastion Builders work through the night. Upgrades one of your
  buildings to its next level at once, and free.
- slave_tithe: The Punitive Host sends back your share of the spoils. Adds 3,000 gold to
  your treasury.

**Kislev**
- caravan_levy: The Erengrad Merchants collect on every ship and sledge. Adds 2,500 gold
  to your treasury at once.
- hire_immortals: A company already sworn and already armed. Adds one unit of Tzar Guard
  (Great Weapons) to an army of your choosing.
- bound_blueprint: The Ice Court parts with a secret, once. Completes the technology you
  are currently researching, at once.
- hobgoblin_eyes: The Oblast Smugglers sell what they have seen on the trails. Reveals one
  region through the shroud, permanently.
- raise_ziggurat: The Stanitsa Builders work before the thaw. Upgrades one of your
  buildings to its next level at once, and free.
- slave_tithe: The Ungol Raiders send back your share of the take. Adds 3,000 gold to your
  treasury.

## 6. Bounties (title, text)

Each guild's bounty kind is fixed:
- **Take it standing:** brass and overseers.
- **Kill a named lord:** immortals and khanate.
- **Sack it:** daemonsmiths and slavers.

**Bretonnia**
- brass: Open the Cellars - The Wine Merchants want that town's trade flowing to
  Bordeleaux. Take it standing.
- immortals: A Challenge of Honour - A general is being spoken of with respect. The
  Knights Errant would like to test that.
- daemonsmiths: Out of Unworthy Hands - Whatever that place keeps, the Damsels want it
  taken from those who should not have it. Bring it back in pieces.
- khanate: A Name in the Forest - The Outlaws do not care how it is done, only that the
  name stops being used.
- overseers: A Keep Worth Keeping - Take it whole. The Castle-Wrights want a keep to
  improve, not rubble.
- slavers: A Crusade's Worth - Sack it. The Crusaders are owed, and that place can pay.

**Cathay**
- brass: Open the Road - The Caravan Masters want that town's markets on the Ivory Road.
  Take it standing.
- immortals: A Lesson in Respect - A general is being spoken of with respect. The Dragon
  Guard would like that corrected.
- daemonsmiths: Collect the Texts - Whatever that place has written down, the Academy
  wants in its archive. Bring it back in pieces.
- khanate: A Name Forgotten - The Society does not care how it is done, only that the
  name stops being used.
- overseers: Walls for the Empire - Take it whole. The Bastion Builders want walls to
  strengthen, not rubble.
- slavers: Punish Them - Sack it. The Host is owed, and that place can pay.

**Kislev**
- brass: Open the Market - The Erengrad Merchants want that town's trade in their
  ledgers. Take it standing.
- immortals: A Duel in the Snow - A general is being spoken of with respect. The Tzar
  Guard would like that corrected.
- daemonsmiths: Claim the Lore - Whatever that place knows, the Ice Court wants. Bring it
  back in pieces.
- khanate: Lost in the Snow - The Smugglers do not care how it is done, only that the
  name stops being used.
- overseers: Hold the Line - Take it whole. The Stanitsa Builders want walls that hold,
  not rubble.
- slavers: Ride and Take - Sack it. The Raiders are owed, and that place can pay.

## 7. Bretonnia's hire unit - decided: A

Bretonnia has no elite infantry. Its best foot unit is tier 2, and its elite is mounted.

| Option | Unit | Tier / cost / men | Reads as |
|---|---|---|---|
| A (recommended) | `wh_main_brt_cav_knights_of_the_realm` Knights of the Realm | 2 / 950 / 60 | Bretonnia's signature unit, at the Greatswords' price. A knight errant who has proven himself becomes a Knight of the Realm, which is exactly what the guild sells. |
| B | `wh_dlc07_brt_inf_foot_squires_0` Foot Squires | 2 / 750 / 120 | Keeps the service an infantry unit like the other races, but is the weakest hire in the mod. |

## 8. Art (chosen at build time, same rules as the Empire and Dwarfs)

- **Icons:** seven per race from CA's own building icons (17 Bretonnia, 48 Cathay,
  53 Kislev to choose from). Each must be a flat silhouette, which `make_guild_icons.py`
  refuses otherwise. Each is rendered and looked at before it ships.
- **Grounds:** six windows each out of `campaign_bretonnia1.png`, `campaign_cathay1.png`
  and `campaign_kislev1.png`, darkened to the Help tab's contrast gate by
  `make_guild_backgrounds.py`.
- **Previews:** `preview_guilds_panel.py --flavour brt|cth|ksl`.

## 9. Build and checks

These are the same steps as the Empire and Dwarf build:
1. `FLAVOURS` entries in `gen_great_guilds.py`.
2. `GG.FLAVOURED` and `GG.HIRE_UNIT_BY_CULTURE` entries in the model Lua.
3. Harness tag/feed cases, and the selftest's flavour list.
4. Regenerate the TSVs, loc and `GGUI.MCT_NAMES`.

Every existing check applies:
- name lengths, the refused words, and the Help pages fitting 21 lines;
- the flavour mirror, feed-offset uniqueness and the feed pictures;
- the hire unit existing in vanilla, and the icon sizes.

Then pack, deploy to `data/` and write a handoff. **Owed in game, per race:** start a
campaign, open the panel, and trigger one guild message.
