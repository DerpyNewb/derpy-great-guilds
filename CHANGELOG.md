# Changelog

Builds of `derpy_great_guilds.pack`, newest first. The detail behind each entry is in
`docs/history/`.

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
