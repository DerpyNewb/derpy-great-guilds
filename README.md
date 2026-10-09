# The Great Guilds

A campaign mod for **Total War: WARHAMMER III**. Seven guilds span the world, and every
faction of your race earns reputation with them just by playing its campaign: trading,
fighting, researching, sending out heroes, building, raiding and keeping the faith. You spend the favour that
comes with it on services, take on guild bounties, answer their demands, and compete with
the AI factions of your own race to lead each guild.

It is script-driven and self-contained. It overrides no CA file, and every DB row it adds
has its own key.

**Status:** playable, and tested live in Chaos Dwarf and Empire campaigns. It is on the Steam
Workshop as [Derpy's Great Guilds](https://steamcommunity.com/sharedfiles/filedetails/?id=3815248936). Nine races take part, each with its own guild names, ranks, services and
bounties (see [Which races take part](#which-races-take-part)).

## The seven guilds

Named here as the Chaos Dwarfs know them; every race has its own names for the same seven.

| Guild | Pays for | Its bonus scales with rank |
|---|---|---|
| The Brass Tablets | your income, every turn | income from all buildings |
| The Immortals | battles won, doubled when outnumbered | replenishment rate |
| The Daemonsmiths | technologies completed | research rate |
| The Khanate | successful hero actions | cheaper hero recruitment |
| The Overseers | settlements growing a level, and buildings no other guild claims | cheaper construction |
| The Slavers | settlements sacked, more when razed | income from sacking and razing |
| The Temple of Hashut | devout provinces, and battles won against the Dwarfs | Winds of Magic reserve |

A finished building also pays the guild it belongs to (a forge pays the Daemonsmiths, a
dock the Brass Tablets, a barracks the Immortals), and pays more at higher levels. Every
building card says which guild it pays. Completing any mission raises your reputation with
every guild at once.

The temple earns differently for each race: from devout provinces, provinces kept clean of
Chaos, holy war against the race's old enemies, or its priests' and wizards' hero actions,
and for the Skaven from provinces carrying Skaven corruption. Its bonuses follow each
race's own faith too: spell resistance for the Ancestor Temples, ward save for the Grail
and Asuryan, melee attack for Khaine, leadership for the Orthodoxy, and the Winds of Magic
for the Colleges, the Celestial Temples, the Grey Seers and Hashut, with three services of
its own for each race.

## How it plays

- **Two numbers per guild.** *Reputation* is earned by playing and is never spent, and it
  alone sets your rank. *Favour* is earned alongside it and is the currency services are
  bought with. Spending favour never costs you rank.
- **Five ranks:** Unmarked 0, Indebted 100, Sworn 300, Favoured 700, Exalted 1500 (the
  names change with your race). Each rank gives a bonus that lasts as long as you hold it.
- **A limit each turn.** Most guilds pay only so much per turn. The Guilds tab shows what
  each guild paid you this turn and last, from which sources, and anything the limit held
  back.
- **Services,** unlocked by rank and paid for in favour, each with a cooldown. Each guild
  shows one service card at Indebted, one at Sworn and one at Favoured, each drawn from a
  pool of three, and
  the cards change every 10 turns (5 to 30 in MCT). Every race also has services of its own
  that no other race gets, at least one on show each period: 95 services in all. Examples:
  an instant gold levy, an elite regiment added to an army, finishing your current
  technology, revealing a region through the shroud, a free building upgrade, and a paid
  malus placed on an enemy. The price drops with a guild that knows you and rises with one
  whose rival you have been courting.
- **Rivalry.** Three pairs of guilds argue: Brass Tablets and Khanate, Immortals and
  Daemonsmiths, Overseers and Slavers. Earning with one takes reputation from its rival
  once you reach Indebted there, but never a rank you have reached. The temple has no rival.
- **Bounties.** A board of three offers drawn from every guild. Taking one turns it into
  a real mission that pays gold and a large amount of reputation, and puts up favour with
  that guild, which you get back when you finish and lose if you fail or hand it back.
  Guilds never ask for your front line: they name land or a lord far from your borders,
  or of a faction you are at peace with (which means war, and pays double). They also
  post jobs (hold gold, raise a champion, research a named technology, take captives),
  ask you to build one of their own buildings, or set your heroes on a named settlement,
  army or character. Every race's heroes can do it. The price reflects the target and its
  distance, rated Routine, Hard or Grim.
- **Leadership.** Whichever faction of your race holds the most reputation with a guild
  leads it. The leader gets an extra bonus, and nobody else can buy that guild's finest
  service. The Leaderboard tab shows who leads each guild.
- **The Court.** Guilds that know you make demands with a deadline: gold, or the favour you
  hold with their rival. Pay and your reputation jumps; ignore it and it falls. You can also
  appoint one lord as a guild's Patron, which gives their army replenishment and movement
  and makes that guild's reputation pay half again.
- **Guild halls.** Each guild has a building of its own, raised in your settlements from a
  Guild Halls tab in the building browser, one hall per settlement. It has three levels: the
  first needs Indebted, the second Favoured, the third Exalted and the lead of that guild.
  A hall pays its guild 4, 8 or 15 reputation and favour a turn, gives a local bonus, trains
  a unit of the guild's trade, and makes that guild's services 3% cheaper (15% at most). Lead
  a guild while holding its top hall and you hold its **Seat**: the hall's bonus spreads to
  all your lands at a third of its strength (the temple's Seat has a bonus of its own), and
  the guild's per-turn limit rises by half.
- **Upkeep.** After the opening turns, each guild takes back a little reputation every
  turn, more at higher ranks, so a guild you stop feeding slides back down the ladder.
- **The AI plays it too.** AI factions of your race earn, buy services (never the
  same one twice in a row while anything else is affordable), answer demands, appoint
  patrons, take bounties of their own and take guilds off you. A rival's bounty can name
  your land, and the feed warns you when it does. The feed tells you when a guild changes hands and you
  are one of the two parties.
- **The Log tab** records your rank changes, your purchases, AI purchases in your race and
  hostile services used against you, newest first.

The panel opens from a crest button at the top of the campaign screen. It has six tabs:
Guilds, Leaderboard, Bounties, Court, Log and Help. The in-game Help tab explains all of the
above. The panel grows with your resolution, so it is not a postage stamp at 1440p or 4K.

### Which races take part

The guilds belong to **the player's race**, and nine races have them:

| Race | The seven guilds |
|---|---|
| Chaos Dwarfs | The Brass Tablets, The Immortals, The Daemonsmiths, The Khanate, The Overseers, The Slavers, The Temple of Hashut |
| Empire | The Merchant Guilds, The Greatswords, The Engineers' School, The Thieves' Guild, The Masons' Guild, The Free Companies, The Colleges of Magic |
| Dwarfs | The Merchant Clans, The Hammerers, The Engineers' Guild, The Rangers, The Miners' Guild, The Grudge-Settlers, The Ancestor Temples |
| Bretonnia | The Wine Merchants, The Knights Errant, The Grail Damsels, The Forest Outlaws, The Castle-Wrights, The Crusaders, The Grail Pilgrims |
| Grand Cathay | The Caravan Masters, The Dragon Guard, The Imperial Academy, The Crow Society, The Bastion Builders, The Punitive Host, The Celestial Temples |
| Kislev | The Erengrad Merchants, The Tzar Guard, The Ice Court, The Oblast Smugglers, The Stanitsa Builders, The Ungol Raiders, The Great Orthodoxy |
| Dark Elves | The Karond Kar Traders, The Black Guard, The Convent of Ghrond, The Khainite Assassins, The Naggarond Builders, The Black Ark Corsairs, The Brides of Khaine |
| High Elves | The Lothern Merchants, The Swordmasters, The Loremasters, The Shadow Warriors, The Ulthuan Masons, The Ellyrian Reavers, The Cult of Asuryan |
| Skaven | The Warpstone Traders, The Stormvermin, The Skryre Warlocks, The Eshin Assassins, The Moulder Breeders, The Slave-Masters, The Grey Seers |

In a campaign played as one of these, every faction of that race runs the guilds and nobody
else does. Any other race gets nothing: no button, no messages and no AI spending.

**Multiplayer:** every panel action goes through the multiplayer transport, and the host's
MCT settings are sent to every player when the campaign starts, so it should stay in sync.
No two-machine campaign has tested it yet.

## Installing

1. Put `derpy_great_guilds.pack` in `Total War WARHAMMER III/data/`.
2. Enable it in the launcher or in the WH3 Mod Manager.

It can be added to a campaign already in progress: rank bonuses are re-applied on the
first turn after loading.

**Mod Configuration Tool (optional).** If MCT is installed, the mod adds a settings page:
a difficulty preset (Easy, Default, Hard, Brutal, or Custom with every earn rate and
limit exposed), switches for AI spending, hostile services, guild notices on the feed, the
leader's monopoly on each guild's top service, race differences and guild halls, a panel
size (Small, Medium or Large) and a debug log option. The values are
read once, when a campaign starts, and are fixed for the life of that save. The panel size
and the debug log option are the exceptions: they can be changed at any time and take effect
the next time the panel opens. In multiplayer the host's settings are used for every player;
the panel size and the debug log option stay each player's own. Without MCT, or with a host
who has no MCT, the defaults apply.

## This repository

The repo holds the mod's source and the tools that generate, check and pack it. The layout
mirrors the in-pack paths, so the tools run from the repo root unchanged.

| Path | What it is |
|---|---|
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` | the model: reputation, earning, ranks, services, bounties, Court, leadership, save state |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua` | the AI's spending |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` | the panel and the HUD opener |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua` | what a bounty may ask for, per race: the technologies and the buildings (generated) |
| `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` | the MCT settings page |
| `Modding Files/pack/ui/campaign ui/` | the `.twui.xml` layouts, shared and per race (generated) |
| `Modding Files/source/great_guilds/` | the DB rows and loc as TSV (generated), which the importer packs |
| `tools/` | generators, checks, the Lua test harness, the preview renderer and the packer |
| `docs/design/` | design specs |
| `docs/plans/` | the implementation plans the mod was built from |
| `docs/history/` | dated handoff notes: what was built, measured and fixed, and why |

**[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** covers how the mod works inside, the build
pipeline, every check, and the engine behaviour that shaped the code.
**[CHANGELOG.md](CHANGELOG.md)** lists the builds.

## Building from source

You need:

- Python 3 with Pillow
- Lua 5.1.5 (the game's version), for the test harness and `luac -p`
- [RPFM](https://github.com/Frodo45127/rpfm) with its MCP server running, for packing
- A WH3 install, and a dump of the vanilla tables the checks read, in `.skilltree_cache/`
  (not included, because it is CA's data)

```sh
lua tools/_guilds_harness.lua              # the model and panel against a stubbed campaign
lua tools/_guilds_bounty_harness.lua       # the bounty board against a stubbed world
py tools/mutate_guilds.py                  # break the rules 239 ways; a harness must notice each
py tools/gen_great_guilds.py --check       # DB rows, loc and every design rule
py tools/gen_great_guilds.py --write       # regenerate the TSVs
py tools/gen_guilds_ui.py --write          # regenerate the .twui.xml layouts
py tools/check_guilds_ui.py                # layouts against what the Lua reaches for
py tools/preview_guilds_panel.py           # render the panel to a PNG with the game shut
py tools/import_great_guilds.py            # pack, save and verify the saved pack
```

The generators, `check_guilds_ui.py`, the preview, `mutate_guilds.py` and the three art
tools also take `--selftest`, which proves each still catches a fault it was built to catch.

**No art is included.** The guild icons, the crest, the effect icons and the panel
backgrounds are derived from Creative Assembly's art, so they ship inside the `.pack` and
are not published here. `tools/make_guild_icons.py`, `tools/make_guild_backgrounds.py` and
`tools/make_guild_bundle_icons.py` rebuild them from art you extract from your own copy of
the game. Without them the scripts still run, but the
panel draws blank squares where the art should be, and the checks that measure the shipped
art report it missing.

## Licence and legal

The code and documentation in this repository are released under the
[MIT License](LICENSE).

This is an unofficial, fan-made mod. It is not made, endorsed or supported by Games
Workshop, Creative Assembly or SEGA.

- **No game files or assets are included.** The repository contains no art, models,
  sounds or game data files from Total War: WARHAMMER III. The mod references the game's own
  data by key at runtime, and you need your own copy of the game to use or build it.
- Warhammer, the Chaos Dwarfs and the names, places and characters of the Warhammer world
  are trademarks and/or copyright of Games Workshop Limited. Total War and Total War:
  WARHAMMER are trademarks and/or copyright of The Creative Assembly Limited and SEGA.
  All are used here for identification only.
- The MIT License covers only the original work in this repository. It grants no rights
  in any Games Workshop, Creative Assembly or SEGA property.
