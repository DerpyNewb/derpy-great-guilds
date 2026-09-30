# Changelog

Builds of `derpy_great_guilds.pack`, newest first. The detail behind each entry is in
`docs/history/`.

## 2026-09-30 - build 0A1DD16B

MD5 `0A1DD16BB1C92BE574DC5BCC673ADD2D`, 34,642,231 bytes. Includes build A7EBBBB4, which
was not released on its own.

How the other races' panels look.

- **Every race's frames rebuilt.** No more cut-off plates, half frames or tab ornaments
  running into each other.
- **Sharper holders and bars.** Pieces are now drawn at or near the size they were made
  for, instead of stretched and blurry. The Chaos Dwarfs' icon ring is new and crisp too.
- **The guild buttons clear their bar's ends** on every race.
- **The Dwarf price box is readable** when a service is running: it has a dark ground under
  its frame.
- **The Dwarfs get their own backgrounds.** Each of the six Dwarf guilds now has its own
  painting behind the panel, instead of six crops of one picture.

## 2026-09-30 - build B77AA0A1

MD5 `B77AA0A19E89CBB7A2C7A76DE0B7BF86`, 34,196,301 bytes.

How the panel looks.

- **The panel's frame is its outer edge.** The background picture used to show a few
  pixels past the border.
- **A slow drifting smoke over the background**, the same effect as the game's main menu,
  kept faint so text stays easy to read.
- **The title has room.** The title plate is wider, so "The Great Guilds" no longer touches
  its ends.
- **Sharper guild icons.** The icons now ship at twice the size, so they stay crisp at
  larger UI scales.
- **Text in the other races' frames sits where it should:** the rank line clears the ends
  of its bar, and card and tab text keep inside their plates.

## 2026-09-29 - build 8AA9DDC1

MD5 `8AA9DDC1ED5B070FCD504E1D3A7D6CBF`, 33,883,860 bytes.

A full check of the mod's rules, with every fault it found fixed.

- **Multiplayer: after a load, both machines now agree.** When the campaign loads, every
  machine reads back your patron, any guild's demand, the technology you are researching,
  your bounty board and the Leaderboard's records. Some of these used to come back only
  when one player opened the panel, so a patron's discount could apply on one machine and
  not on the other.
- **A new campaign shows its first services on turn 1**, your race's own included. They
  used to arrive on turn 2.
- **Patrons:**
  - Only one of your own lords with an army can be appointed. Selecting an enemy lord no
    longer gives their army your patron's bonus.
  - A patron who loses their army, dies or leaves your faction takes the bonus off that
    army with them.
  - After a load, the bonus is no longer left on an army the patron has since left.
  - In multiplayer, pressing Appoint twice no longer dismisses the patron.
- **Bounties no longer ask for a technology that only another faction can research**, such
  as Aislinn's, Ostankya's or the Elector Counts'.
- **Leading a guild:**
  - After a load, a guild you lead by a small margin stays yours. It used to go to the
    rival.
  - When your Reputation drains away and nobody takes the lead, the Log says so, and no
    message claims that a rival took it.
  - The Leaderboard explains when the faction at the top is not yet the leader.
- **Earning never costs favour.** After losing a rank, one more point of Reputation could
  cut your favour down to the new rank's limit.
- **Rival factions:**
  - They buy once per round, even when a save is loaded mid-round.
  - They never aim a service at a dead faction or at the rebels.
  - A service that needs an enemy settlement is aimed at an enemy that has one.
  - The Leaderboard keeps moving when rival factions are set not to use the guilds.
- **A load no longer resets a guild's limit for the turn**, and a race's own earning keeps
  its progress towards the next point.
- **One battle pays once**, however many of your generals and heroes fought in it.
- **Dwarfs: settling grudges now pays 1 Reputation for every 5 grudge points.** It used to
  pay a flat sum for every army that won a battle, so one battle could pay twice.
- **The Ziggurat service upgrades a building along its own line**, so Cathay's yin stays
  yin. If the game refuses the upgrade, your favour is returned.
- **Call the Reckoning** is offered only once a grudge cycle has run. **Labour Gangs** is
  offered only while you hold a province with labour.
- **The panel:**
  - It redraws when you select something else while it is open, and any pending Confirm
    is dropped.
  - Take on a bounty always takes the bounty on the card you clicked.
  - The guild button's badge counts only bounties the board shows.
  - On a demand's last payable turn, the turns left show as 1, not 0.
  - The footer shows your favour with the guild on screen.
- **Five settings are now locked once a campaign is running:**
  - rival factions spending favour;
  - rival factions taking bounties;
  - services aimed at enemies;
  - guild notices;
  - "Only the leader buys the finest service".
- The settings' "Write every reputation to the log" button now works.
- **Text corrections:**
  - Rank-up messages say what each rank opens.
  - Hobgoblin Eyes says it reveals a region for this turn.
  - The patron's texts no longer promise a fixed "half again" or a flat 10%.
  - Letting a demand lapse "can" cost a rank, rather than always costing one.
  - The Help says a rival guild never takes a rank you have reached.
  - The failed-bounty message names what you lost.
  - The "only the leader" texts note that a setting can turn it off.
  - Bought Loyalty and The Lady's Blessing say which army they need.
  - The settings' descriptions for Easy, upkeep and razing are corrected.

## 2026-09-29 - build B69679D0

MD5 `B69679D0500C398334DFDEDAC146DEC5`, 33,839,402 bytes.

- **New: every race has services of its own.** 29 new services, drawn only for their
  own race. At least one is on show in every period, and its card carries a yellow label
  with your race's name.
  - The Empire's include five tied to its lords: Elspeth's Schematics, Gelt's Arcane
    Essays, Todbringer's Fervour, Karl Franz's Elector's Favour and Wulfhart's Imperial
    Supply Train.
- **New: every race earns guild Reputation in its own way**, each with a Log line under
  Mine:
  - a caravan arriving (Chaos Dwarfs, Cathay);
  - settling grudges (Dwarfs);
  - taking back the old Empire's lands (Empire);
  - beginning a Motherland ritual (Kislev);
  - gaining Chivalry (Bretonnia);
  - gaining Slaves (Dark Elves);
  - a court action that succeeds (High Elves).
- **New: every race bends one guild rule.**
  - Chaos Dwarf demands come more often and pay more.
  - Dwarfs lose more for a failed bounty or an expired demand.
  - Bretonnian demands pay more when met and cost more when missed.
  - The Empire and the Dark Elves lose more to rival guilds, Cathay less.
  - Kislev pays half the upkeep.
  - Dark Elf services aimed at enemies cost a quarter less.
  - The High Elves can hold half again as much favour.
- **New: Slave Tithe now pays Kislev 150 Devotion and the Dark Elves 1,000 Slaves.**
- **New: a sixth Help page, "Your race",** explains all of this for your race.
- **New setting: Race differences**, on by default. Turn it off when starting a campaign
  to play without any of the above. It cannot be changed once the campaign is running.
- A service whose requirement has gone since it was put on show, such as a caravan that
  has already come home, now shows "Unavailable". It cannot be bought, and no favour is
  taken.

## 2026-09-29 - build F3F6FE85

MD5 `F3F6FE853C70DEA9F720EF22442E241A`, 33,755,888 bytes.

- **Fixed: The Khan's Price can only be used on a faction you are at war with**, as its
  card says. It used to accept any faction, including your allies.
- **Fixed: the map reveal can no longer be bought for your own region**, which you can
  already see.
- **Fixed: a new campaign can now offer the original services in its first period.**
  An existing save keeps its current services until the countdown ends, and the
  change is announced, instead of every card changing at once without a word.
- The footer says "New services next turn" instead of "in 1 turns".
- The Guild Loan and The Great Work now light their card while their effect runs.
- The guild notices setting now says it also covers the services changing.

## 2026-09-29 - build DF0221CE

MD5 `DF0221CE230F2E9530234D2809592104`, 33,751,530 bytes.

- **Fixed: a regiment can no longer be bought for a full army.** It used to take your
  favour and start the cooldown, and no regiment arrived. The card now asks for an army
  with room, and armies from mods that raise the limit are counted correctly.
- **Fixed: Warlord's Honour and Hired Blade can no longer be bought for a lord or hero
  already at the highest rank.**
- **New: if a service fails to arrive for any reason, your favour is returned** and the
  cooldown does not start. The Log says so.
- Rival factions now hire into an army that has room, instead of always trying their
  first army.
- The hint for army services no longer says a regiment will join.

## 2026-09-29 - build 25DD78AF

MD5 `25DD78AF710F1B64BB03257C67692A4D`, 33,745,181 bytes.

- **Changed: Warlord's Honour now adds 5 ranks** to the lord or hero you select (was 3).
  Only the faction that leads the guild can buy it, and it cost 400 favour for the same
  3 ranks the 150-favour Hired Blade gives.

## 2026-09-29 - build 2B9176F5

MD5 `2B9176F5E5ECD48C084B9E9F6E5CC539`, 33,745,181 bytes.

- **New: every race now has its own panel frame.** The Empire, Dwarfs, High Elves,
  Cathay, Kislev, Bretonnia and Dark Elves each get their own cards, tabs, bars and
  borders, all taken from the game's own art for that race. The Chaos Dwarf panel is
  unchanged. Before this, every race's panel used the Chaos Dwarf frame.
- A running service now lights its card in the race's own colour.

## 2026-09-29 - build 3CA24F72

MD5 `3CA24F723D356E241B102133DD90874B`, 32,942,516 bytes.

- **Fixed: Kislev's Master Gunners now strengthens Kislev's artillery**: +20% missile
  damage for your War Sleds and Little Grom, for 10 turns. The game counts neither as
  artillery, so the old version reached none of them, and the last build swapped it for
  a missile infantry bonus instead.

## 2026-09-29 - build E3C2984B

MD5 `E3C2984B1F01C0D0F594F7F78F1BBA66`, 32,941,773 bytes. Every service checked against
every race.

- **Fixed: Temple Bribes now raises Chaos corruption for the Chaos Dwarfs** (+5 in every
  province you hold, for 8 turns). It used to lower corruption, which costs a Chaos Dwarf
  realm public order. Every other race still gets -5 corruption.
- **Fixed: Gunnery Masters now reaches the Chaos Dwarfs' war machines.** +20% missile
  damage for your artillery and Iron Daemons - Magma Cannons, Dreadquake Mortars,
  Deathshrieker Rockets and Bolt Throwers. It used to reach the Bolt Thrower only.
- Kislev's version became Streltsi Marksmen, +15% missile damage for missile infantry,
  because it reached none of Kislev's units. Replaced in the next build by a version for
  Kislev's actual artillery.
- **Fixed: the Dwarfs' Runelord's Anvil now gives +10% spell resistance** to all your
  armies. It gave Winds of Magic, and the Dwarfs have no wizards to use them.
- The Slavers' texts now say "income from sacking settlements". They said "sacking and
  razing", but razing never paid anything extra.

## 2026-09-29 - build F6F81565

MD5 `F6F815651008F8D56D947B5A26F04A42`, 32,941,490 bytes.

- **The guilds now have 54 services between them, not 18.** Every rank of every guild has
  three services, and one of them is on offer at a time. The offer changes every 10 turns, all
  guilds together, and a card never shows the same service twice in a row. The Guilds
  panel shows how many turns are left before the next change, and you get a message when
  it happens.
- **New option, "Services change every"**, from 5 to 30 turns, default 10. It can only be
  set before the campaign starts.
- **New kinds of service.** Some are spent on one of your armies (Forced March, Field
  Surgeons), some on one of your settlements (Granaries, Fortify), some on an enemy's
  settlement (Sow Discord, Poisoned Wells, Scorched Earth), and some give one of your lords
  or heroes extra ranks (Warlord's Honour, Hired Blade). A service can only be spent on a
  target it fits: your own army, your own settlement, or a settlement of a faction you are
  at war with.
- **"Guilds can be turned on you" now also covers the services aimed at enemy
  settlements.** Turn it off and they are never offered.
- **When a rival's service hits one of your settlements, you are told.** You get a
  message, and the Log says which rival did it.
- **Fixed: Hire the Immortals now adds its regiment.** Before this, it took your favour
  and gave nothing.
- A save from an earlier build keeps its cooldowns. Its services stay as they were until
  your next turn starts.

## 2026-09-29 - build BB0FB116

MD5 `BB0FB116BBC06DB52C4965C32C4524C2`, 32,523,401 bytes.

- **Rival factions of your race take the guilds' bounties too.** Each one holds one bounty at
  a time, puts up favour for it the way you do, and earns Reputation and gold when it
  finishes. A bounty it cannot finish in 20 turns costs it Reputation. A rival only takes
  work near its own borders. This is a race you can lose: a rival working the bounty board
  climbs the Leaderboard.
- **A rival at war with you, whose borders touch yours, may be paid to take your
  settlements or kill your lords and heroes.** You are told the turn it happens - a message that shows you the target - and the
  Log says which rival, and what it was paid to take. You also hear when it collects, fails
  or gives up.
- **The Log's Rivals filter shows the race.** When a rival finishes a bounty against someone
  else, you see what it earned.
- **New option, "Rivals take bounties"**, on by default. Turn it off and only you take
  bounties, as before.

## 2026-09-29 - build C7DD5E99

MD5 `C7DD5E994D32A4CE78DA5B60C1F1F356`, 32,489,088 bytes.

- **The number on the Guilds button counts only bounties you can take.** An offer whose
  favour you cannot put up has a dead Take button, and the button no longer counts it.
- **A bounty to harry a lord goes when his army does.** It stayed on the board, asking
  heroes to harry a lord with nothing left to harry. A bounty to kill him still stands.
- **A building request only names an upgrade your settlement can hold.** Every level a guild
  asks for needs a settlement at level 3, 4 or 5, and a minor settlement stops at 3 - so a
  request could name an upgrade that could never be built where the building stood.
- **A building request you have not taken goes if you lose the region it needs.**
- **The greyed Guilds button's hover says "Opens again on your turn"**, not "Click to open".

## 2026-09-28 - build 33819446

MD5 `338194468A5A5449D21A9F248BD33E16`, 32,484,829 bytes.

- **The Guilds button greys out when your turn ends**, like the buttons beside it, and comes
  back when your turn starts. Clicking it in between does nothing. Ending the turn also
  closes the panel, and a target you were picking on the map.
- **Tooltips are short enough to read.** Every Court card repeated the whole of the Court's
  rules underneath its own line - seventeen lines over a three-line card. Each card now
  says its own part: what paying or missing a demand does, what a patron gives, what leading
  a guild gets you. The Help tab's Court page still has everything.
- **The Guilds tab's header hover is half the length.** A guild's rank bonuses are said once
  - "income from all buildings +3% / +6% / +10% / +15% at 100 / 300 / 700 / 1500
  reputation" - instead of repeating the phrase at every rank, and the upkeep note is one
  line.
- **A Leaderboard row's hover is the standings table.** The guild's full description
  followed it; that is on the Guilds tab.

## 2026-09-28 - build FF48368B

MD5 `FF48368B75306B4FB5CD78E24ED5DE91`, 32,499,828 bytes.

- **A research job asks for a technology you can start now.** It used to pick from the top
  half of your tree at random, so a turn-8 Chaos Dwarf could be asked for Labour
  Organisation, the last technology in its industry line. It now names a technology whose
  prerequisites you have already researched. Technologies that need a building first are
  never asked for. The deeper the technology, the more the job pays, as before.
- **A building job asks for an upgrade you can make now.** It names the next level of a
  building you already own, never one two steps up or in a line you have not started. Where
  either of two buildings upgrades into it (Cathay's yin and yang), owning either will do.
  Your settlement's level can still hold the upgrade back until you raise the settlement.
- **The bar under the six guild buttons is whole.** CA's picture has a rim along its top
  only, so the bottom edge looked cut off, and the buttons with it. The bar now has a rim
  top and bottom and the buttons sit in the middle of it.

## 2026-09-28 - build 60CA7EAD

MD5 `60CA7EAD2B8B631DBB25F41607FCDEF9`, 32,460,635 bytes.

- **A bounty card's tooltip is about that bounty.** It used to repeat the whole of the Help
  tab's Bounties page under every card. It now gives the job, then what failing it costs, as a
  number. The war, map and not-enough-favour lines are unchanged.
- **The guild's name is no longer printed twice** at the top of a job's tooltip.
- **The Help tab no longer overstates what a failed bounty costs.** It said "what finishing it
  would have paid", which is only true on the default preset. It now says each card gives the
  amount.

## 2026-09-27 - build 7AB4585D

MD5 `7AB4585DC0B61C952AA5F151A69091D8`, 32,469,435 bytes.

- **The Guilds button keeps to the end of the top bar.** The bar grows and shrinks as
  effects come and go. The button used to stay where the end had been until the next
  turn and then jump; now it moves with the bar as soon as the bar changes.

- **The Guilds button is there from the first turn.** On a campaign with a long opening it gave
  up waiting before the top bar had settled and only appeared at the next turn.

- **Bounties no longer pay you for the war you were already fighting.** A guild never asks
  for your front line. It names land or a lord far from your borders and armies, or one of
  a faction you are at peace with.
- **A bounty on a faction at peace means war, and pays for it:** twice the gold and half as
  much Reputation again. Allies, pacts and vassals are never named, and an offer is withdrawn if you make peace or a
  pact with its target before you take it.
- **Taking a bounty puts up favour with that guild.** It is the number on the card's plate.
  You get it back when you finish, and lose it if you fail or hand it back. The amount is a
  setting in the mod's options.
- **Every guild has a job as well as a fight:** hold a sum of gold, raise a champion,
  research a named technology or take captives in battle.
- **Every guild can ask you to build one of its own buildings**, and only ones you can build
  in an ordinary settlement: never one that needs a resource, a port, a landmark or a horde.
- **Hero work:** the Daemonsmiths want a settlement sabotaged, the Immortals want an army
  harried, and the Khanate wants a named lord or hero wounded or killed. Any hero can do it,
  including Dwarf and Empire heroes, and the card counts your progress.

## 2026-09-26 - build 7F9D5CF2

MD5 `7F9D5CF2E71EA5788DBC20AC21E16DBA`, 32,266,153 bytes.

- **No more streaks across the cards.** Build 1A9B7828 drew fragments of other game art
  over every card on the Guilds, Bounties and Court tabs.
- **A card with no price no longer shows an empty price bar**, for example the Court's
  demand and patron cards.

## 2026-09-26 - build 1A9B7828

MD5 `1A9B7828529AAD5F1784FB99F2D78362`, 32,265,300 bytes.

- **A service that is running lights up its card**, with the red glow the Hell-Forge and
  the Tower of Zharr use for something active.
- **Every Guild effect now has an icon** in the game's effect lists: the guild's mark on
  the same teal disc as the game's own effects. Before this they showed no picture.
- **Tab names and prices fit inside their plates.** They ran over the edges in the
  previous build.

## 2026-09-26 - build 54E67BC9

MD5 `54E67BC9EA44A86EF81FF7A3C6586907`, 32,157,758 bytes.

- **The panel wears the Chaos Dwarf frames the Hell-Forge uses.** These are the header bar,
  the round bronze holders around the guild icons, the bronze service cards, the price
  plates, and the large square tabs, with a distinct look for the open one. The reputation
  bar is now the convoy panel's segmented bar, and the six guild buttons sit on a bronze
  bar.
- **The title sits on the game's title plate.** For a Chaos Dwarf player it should be the
  spiked Chaos Dwarf plate (seen in game), and other races should get their own, the way
  the game's own panels do.
- All of it is the game's own art, used where it already is. The mod adds no new images.

## 2026-09-25 - build DA1C0218

MD5 `DA1C0218EA4134C3CF72A5755455D836`, 32,151,169 bytes.

- **A guild no longer changes hands and back in one round.** Each faction is paid its Brass
  Tablets income at the start of its own turn, so two factions whose reputations were
  close swapped the guild at every turn start. The message was "Turned Away", followed
  soon after by "Answer To You". A rival now has to be ahead by more than one turn's
  income to take the guild. The Khanate, which pays for that same income through rivalry,
  gets the same rule.

## 2026-09-25 - build A3918816

Deployed 2026-09-25. MD5 `A3918816471FF4C246A60A0D2BC86507`, 32,148,457 bytes.

Three fixes to build 74AFE8EA:

- **The numbers on the six guild buttons are readable.** Each icon now sits on a round plate
  with the count in the corner, instead of the count being printed over the icon.
- **Selecting a target:** the instruction on the card wraps onto a second line instead of
  running off the edge. "Press Escape or Cancel to go back" is in the card's hover text.
- The target card now uses the same text size as the panel when the panel is closed.

## 2026-09-25 - build 74AFE8EA

Deployed 2026-09-25. MD5 `74AFE8EAE3475FF3C20E2B63CC28E1DF`, 32,144,734 bytes.

- **Hover text now shows.** The panel's tooltips were set on components that could not be
  hovered, so most of them never appeared.
- **Escape closes the panel.**
- **The guild button on the campaign screen lists what is ready** when you hover it:
  services you can buy, bounties to take, and a demand you can pay. A bounty you have
  already taken no longer counts.
- **The arrows say where they go**, including how many services are ready in the next
  guild.
- **The tech tree, diplomacy and other full-screen panels close this one.**
- **A big purchase asks first.** A service aimed at another faction, or one that spends
  half or more of your favour with that guild, needs a second click on Confirm.
- **Select a target without closing the panel yourself.** A service that needs a target on
  the map has a Select button. The panel steps aside, and it comes back as soon as you
  select something that works. Escape or Cancel returns without choosing.
- **Map links.** Click a bounty to see its target, or a faction on the Leaderboard to see
  its capital.
- **Six guild buttons** between the arrows jump straight to any guild and show how many of
  its services are ready. Clicking a guild's icon on the Leaderboard opens that guild.
- **Log filters:** All, Yours, Rivals and Ranks.

## 2026-09-25 - build 40FE934A

Deployed 2026-09-25. MD5 `40FE934AD62DAC1982E6AEAC259815D5`, 32,077,286 bytes.

- **MCT works in multiplayer.** When a multiplayer campaign starts, the host's settings are
  sent to every player and fixed for the campaign. Until they arrive, every machine plays
  the defaults. It used to ignore MCT in multiplayer entirely. Not yet tested on two
  machines.
- **Turn 1 uses your settings.** They were read at the first turn start, after turn 1 had
  already been played on the defaults. They are now read when the campaign loads.
- The "Log every reputation gain" switch is each player's own in multiplayer.

## 2026-09-25 - build 7DBE88C6

Deployed 2026-09-25. MD5 `7DBE88C685D5A21089BA70D19A9153CF`, 32,073,727 bytes.

- **Leaderboard:** each row starts with the guild's icon, and the leader is shown by their
  flag. A rival's name and rank follow the flag, and are dropped when the line would not
  fit.
- **The panel title** is larger and centred.

## 2026-09-25 - build EDB15834

Deployed 2026-09-25. MD5 `EDB15834C791B393BE645A2E837A8E18`, 32,070,410 bytes.

- **Fixed for game patch 9.0.** Build 108E223B named a building that 9.0 removed (the Great
  Temple of Ulric), so the game would reject the whole pack. The building list is now read
  from the installed game instead of an older copy. 9.0's new buildings are included, and
  1,726 building cards carry the guild line.
- A new build check resolves every key the pack names against the installed game, so a
  removed key fails the build instead of the game load.

## 2026-09-24 - build 108E223B

Deployed 2026-09-24. MD5 `108E223BC4E178A65930A621DE729DF8`, 32,069,050 bytes.

New:

- **Every building card says which guild it pays.** A yellow line, in your race's own
  guild names, on 1,714 building levels across the eight races. A check runs the script's
  own building-to-guild matching over every building and refuses to pack if a card would
  name a different guild than the one paid. Shared landmarks, ruins and other mods'
  buildings get no line, but still pay.
- **"Reputation this turn" on the Guilds tab.** What the guild on screen paid you this turn
  and last, the biggest sources first, and in red anything the per-turn limit held back.
  Hover for the full list. Saved with the campaign.

Changed:

- **Plain words.** "Standing" is now "reputation" everywhere a player reads it, the
  Standings tab is now Leaderboard, and each per-turn cap is a "limit". Jargon such as
  accrues, rep, league table, HUD and agent (now hero) is gone.
- Two descriptions were wrong and are fixed: reputation does not "only rise", and the
  Overseers are no longer said to be paid for every building.

## 2026-09-24 - build EFA60E77

Deployed 2026-09-24. MD5 `EFA60E7720E07D8F65103C7A5FCA62FD`, 31,843,912 bytes.

- **Dark Elves and High Elves.** Their own guilds, ranks, services, bounties, icons and
  panel backgrounds. The Soldiers' hire is Black Guard of Naggarond and Swordmasters of
  Hoeth.
- **Only the eight included races take part.** Any other race gets no button, no
  reputation, no messages and no AI spending, even when a human plays it.

## 2026-09-24 - build 6E9BEDE8

Deployed 2026-09-24. MD5 `6E9BEDE837F0E240EC5AB9DBB73584A6`, 24,327,043 bytes.

- **Bretonnia, Grand Cathay and Kislev,** each with its own guilds, ranks, services,
  bounties, icons and panel backgrounds. The hires are Knights of the Realm, Celestial
  Dragon Guard and Tzar Guard.

## 2026-09-24 - build FC95D1D1

Deployed 2026-09-24. MD5 `FC95D1D1788358CA964852D26EA52B89`, 13,283,594 bytes.

- **The AI buys all eighteen services,** including Hobgoblin Eyes, Bound Blueprint and
  Raise the Ziggurat, which it now finds targets for. It never buys the same service twice
  in a row while anything else is affordable.
- **Multiplayer.** Every panel action goes through a broadcast that applies it on every
  machine. Not yet tested in a two-machine campaign.
- The Slave Tithe pays Dwarfs 250 Oathgold instead of gold.
- The MCT page names the guilds in the player's race.
- The HUD button's tooltip is written when you hover it, not from a turn handler.
- A generic set of names for any race without its own. Build EFA60E77 later removed those
  races from the mod.

## 2026-09-24 - build 0C3860AB

Deployed 2026-09-24. MD5 `0C3860AB3C96803487BBF4CAA57076B3`, 10,856,210 bytes.

- **The panel scales with your resolution:** 1.33x at 1440p and 2x at 4K, text included.
  1080p and below are unchanged, and the game's own UI Scale setting still applies on top.

## 2026-09-23 - build 8B535825

Deployed 2026-09-23. MD5 `8B5358255C8C4CF7B11F1BE94AC092AF`, 10,835,304 bytes.

- **Empire and Dwarfs get their own guilds:** names, ranks, services, bounties, messages,
  icons, crest and panel backgrounds. Chaos Dwarfs are unchanged.

## 2026-09-23 - build 99A25F5C

Deployed 2026-09-23. MD5 `99A25F5C5D60CEC9533FBC5B91323597`, 4,182,228 bytes.

Fixes:

- **Buildings pay their guild.** No building had paid any guild, for any faction, since the
  mod first shipped: the handler read `context:faction()`, which `BuildingCompleted` does not
  have. It now reads the owner off the building, with the garrison as a fallback. Confirmed
  live: six AI factions gained Overseers and Daemonsmiths reputation in the first round.
- **AI factions earn the Daemonsmiths.** The engine never raises `ResearchCompleted` for an
  AI faction, so the AI is now paid from its completed-technology count at turn start. The
  first count is a baseline, not income.
- **Rivalry takes nothing below Indebted.** The Khanate was pinned at 0 from turn 1, because
  Brass Tablets income drained it before it could reach its first rank.
- The technology count is kept only for factions of the player's culture. The previous build
  wrote a key for all 277 AI factions in the world.

New:

- **The Log tab.** Rank changes (up and down), your purchases, AI purchases in your race,
  hostile services used against you, and leadership won or lost. Newest first, 100
  entries, saved with the campaign.

## 2026-09-16

Deployed 2026-09-16.

- **Standings no longer reset after loading a save.** Reputation was held in session memory
  with no restore path, so a save loaded mid-turn showed empty tables and no leaders until
  the next turn.
- **A guild no longer changes hands twice a round.** Leadership is held until a rival
  actually overtakes, instead of flickering as each faction pays its upkeep on its own turn.
- **Rivalry is floored at the rank you hold,** so feeding one guild can no longer demote
  you with its rival.
- **Appointing a patron works,** and so do Hire the Immortals and The Khan's Price. All
  three read the selected army through a UI-manager method that does not exist, so they
  had been dead since the first build.
- Bound Blueprint and Raise the Ziggurat no longer refund themselves, and the Brass Tablets'
  rank bonus was moved off an effect that paid nothing.

## 2026-09-11 to 2026-09-15

Added over several builds (see `docs/plans/`): the bounty board (modelled on CA's own Ogre
contracts), the Court (demands and patrons), leadership and the Standings league table,
feed notices for rank-ups and first contact, reputation upkeep, and the MCT difficulty
presets.

## 2026-09-10 - first build

Designed, built and packed in one session: six guilds, reputation and favour, five ranks
with permanent bonuses, eighteen services, AI spending, and a four-tab panel. Chaos Dwarf
names only.
