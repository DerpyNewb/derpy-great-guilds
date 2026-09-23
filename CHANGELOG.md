# Changelog

Builds of `derpy_great_guilds.pack`, newest first. The detail behind each entry is in
`docs/history/`.

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
