# Changelog

Builds of `derpy_great_guilds.pack`, newest first. The detail behind each entry is in
`docs/history/`.

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
