# antislop audit 001 - The Great Guilds - 2026-10-09

**Mode:** after (session override). **Build audited:** `f41a33d9`.

**Scope:**
- Player text: `Modding Files/source/great_guilds/loc.tsv`, the MCT file, and `docs/workshop/great_guilds/WORKSHOP_PAGE.md`.
- The in-game panel: `tools/gen_guilds_ui.py` and `zzz_derpy_guilds_ui.lua`, with previews re-rendered at Small, Medium and Large for the Empire, Skaven and Dwarfs.
- Code comments in the six Guilds code files.

**Priority:**
- HIGH: a Hard Gate rule is broken, or a claim is wrong or misleading.
- MEDIUM: a Purpose-Gate rule is broken, or player-facing jargon or clarity suffers.
- LOW: quality and consistency.

Nothing has been changed. Pick the numbers to fix; numbers not named are left alone.

**Clean:**
- No em or en dashes and no emoji in any of the 8,980 loc rows or the MCT file.
- No banned jargon in player text.
- Every claim about the presets matches `GG.PRESETS`.
- Measured contrast passes: body text `#FFF8D7` 13-19:1, card text `#C9BFA8` 7.4:1, price red 5.4:1.

## HIGH

| # | Area | Finding | Rule | Fix |
|---|---|---|---|---|
| 1 | Workshop page l.95 | "One service at each of a guild's top three ranks". The services need ranks 2, 3 and 4, not 3-5. | R-38 | "One service each at ranks 2, 3 and 4, drawn from a pool." |
| 2 | Help p7 (9 races), Workshop l.142 | Promises a unit at every hall, but 34 of 189 hall levels train nothing (all three Empire Colleges halls, for example). | R-38 | "...and, at most halls, a unit of its trade" |
| 3 | 280 loc rows (`guild_desc_*`, rank and lead bundles) | "+3% income ... for every region you own" reads as +3% per region, as if it stacks. | R-36 (misleading size) | "in every region you own", matching the 102 rows that already say it that way |
| 4 | Workshop l.146 | "The hall's bonus spreads faction-wide at a third of its strength". This is false for the Temple Seat in every race. | R-38 | Add "(the temple's Seat has its own bonus)" |
| 5 | Workshop l.37 | The file's only em dash, in a heading. It sits outside the block that gets pasted to Steam. | R-02 | Use a colon |
| 6 | Panel: Buy / Take / Pay buttons | The red caption on a disabled button measures 2.85:1 at p90 against the red plate (the preview reports 4.2:1). | R-25 | Keep the caption `#FFF8D7` (9.9:1) and leave the red on the price |
| 7 | Panel: disabled buttons | A disabled button looks live: it ships only the standard and hover states, so the red caption is the only cue. | R-26, human "colour-only" | Grey it out, as the opener already does (`set_greyscale_t0`) |
| 8 | Panel at Small, every race | Log filter captions fail: All 1.6:1, the others 2.6:1. At Small the text sits on the plate's rim. | R-25 | Taller filter plate, or offset the caption at `_sm` |
| 9 | Panel at Small, Skaven | Tab captions measure 3.7-4.1:1 on the lime buttons, and the strip count 4.2:1. | R-25 | Dark wash under the caption in the `_skv` tab layers |
| 10 | Panel at Small and Large | "Needs Journeyman" overflows its plate: 132px in 127px at Small, 200px in 198px at Large. | R-03 analogue | Size the plate from the measured text at every size |
| 11 | `gen_great_guilds.py:7552` (my temple donor test) | The comment claims the donor follows the lore hall for every race, but 5 of 9 races fall back to the "order" role. The assert caught the old behaviour but cannot fail on that fallback path. | code: stale or wrong | Reword the comment, and assert the 4 races that match by their own effect |
| 12 | `gen_great_guilds.py` temple comments (l.71, 108, 141, 729, 2200, 2206, 2838, 7569; `HALL_AI_ROLE`) | Comments still say the temple pays public order, or that the Seat is "the hall's effect at a third". `TEMPLE_LORE` now overrides every one of these. | code: stale | Reword each as a fallback no race reaches, or note the temple exception |
| 13 | `gen_great_guilds.py:2877` | `HALL_BONUS["temple"]` "Public order +%d" is dead text: every race with halls uses `TEMPLE_LORE`. | code: dead | Mark it as unreached, or delete it |
| 14 | Six / eighteen counts in comments (MCT l.38, 41, 82, 216, 219, 362; `zzz_derpy_guilds.lua:4161`; `_ai.lua:11`; `gen_great_guilds.py:166`; `zzz_derpy_guilds.lua:4504`) | Wrong counts: there are 7 guilds, 95 services, 21 cards, 30 preset keys and 7 Systems switches. | code: stale | Fix the numbers or drop them |
| 15 | MCT renaming (code) | `GGUI.name_mct` renames 13 sliders. The temple's four earn-route sliders keep their generic labels, and the comment says "twelve". | code: stale, and a possible label gap | Correct the comment. Separately decide whether the temple's route sliders should get race labels |

## MEDIUM

| # | Area | Finding | Rule | Fix |
|---|---|---|---|---|
| 16 | Workshop l.98 | "Good standing = cheaper". "Standing" is a banned word. | author rule | "Higher Reputation = cheaper" |
| 17 | 12 rows of service names | "Blooded / Seasoned / Hardened Agents". WH3 calls them heroes. | author rule (plain words) | "... Heroes" or a lore name |
| 18 | 20 hall descriptions | "if you lack the pack for Huntsmen". "Pack" is dev jargon. | author rule | Name the DLC |
| 19 | 512 rows (219 on cards) | "unless the settings say otherwise", repeated on every leader-only card and message. | copy: settings leakage | Say it once in Help and in the MCT tooltip |
| 20 | `derpy_gg_help_t5*` (10 rows) | "Losing reputation": the only lowercase Reputation in the file. | author rule | "Losing Reputation" |
| 21 | MCT l.189, l.145 | Chaos Dwarf names in a menu every race reads: "Unmarked ... Exalted", "The Khan's Price". | copy: wrong audience | Rank numbers, and "services that raise an enemy's costs" |
| 22 | Several words for one mechanic | stake / deposit; finest / dearest / most expensive; you select / your chosen; at once / immediately. | copy: consistency | One word for each |
| 23 | `derpy_gg_guild_desc_temple_gen` | "through the faith's own routes": "routes" is an internal term. | copy: jargon | "by keeping order and defeating the faith's enemies" |
| 24 | High Elf and Chaos Dwarf service names | "Favours at Court", "The Phoenix King's Favour", "Conclave Favour" clash with the mod's Favour currency, and Conclave Favour actually adds Conclave Influence. | copy: ambiguity | Rename those services |
| 25 | Panel: "Needs X" plate | Red on the plate measures 4.07-4.53:1 at p90 for 14px text. | R-25 (borderline) | Darker `PLATE_WASH`, then re-measure |
| 26 | MCT "Panel size" | Does nothing on some screens: at 4K all three sizes draw the same panel, and at 1440p Medium and Large are identical. | R-26 analogue | Say so in the tooltip, or add an extra-large size |
| 27 | Panel at 4K | Large is the biggest size, so text draws at about half its 1080p physical size. Needs an in-game check at 4K with UI Scale 100%. | R-03 analogue | Check in game, then decide on #26 |
| 28 | Bounties tab, empty | Three identical "No bounty on offer" cards under a header that says "Three offers ... 0 / 3 Taken", and nothing says when new offers come. | R-27 | One card: "No bounties this turn. New offers in N turns." |
| 29 | `GGUI.open` failure | The pcall result is thrown away, so a failed open is silent and the opener just does nothing. | R-27 (error state) | Log the error |
| 30 | Help headings | Headings are 12px body text set apart only by yellow. | R-06, project rule (headers 18-24) | `header_18` for heading lines |
| 31 | Guilds tab cards | All three cards carry the same guild glyph; the rank hierarchy shows only as text. | R-14 | Rank glyph or the effect icon in `card_icon` |
| 32 | Panel colours | Five accents (gold, yellow, orange, red, green). "Selected" uses two colours and "blocked" uses two. | R-29, CUSTOM_UI.md | One colour for selected, one for blocked |
| 33 | Code comments, counts (23 lines across 5 files) | "six guilds" and similar, where there are now seven. | code: stale | "seven", or "every" |
| 34 | `_cai_donor` / `service_sign` docstrings, `gen_great_guilds.py:1943` | Incomplete rule list; "only hostile service" ignores the 4 enemy-settlement services; wrong row order. | code: stale | Reword |

## LOW

| # | Area | Finding | Rule | Fix |
|---|---|---|---|---|
| 35 | Guild descriptions across races | Repeated sentence shapes ("Every X owes them something", "work for anyone, including against you", and 4 more). | copy: templated | Rewrite 2-3 per group |
| 36 | 210 mission completion texts | Every one says "The work is done. The guild has paid your reward." | copy: templated | One line per guild |
| 37 | 60 rows | "start +1 rank higher for 8 turns" reads as if the rank lasts 8 turns; there is also a doubled "for ... for". | copy: clarity | "For 8 turns, units you recruit start 1 rank higher" |
| 38 | Greatswords-type rank 3-5 bundles | Stray comma: "+1 recruitment capacity, for your faction." | copy | Drop the comma |
| 39 | `derpy_gg_rivals_idle*` (10 rows) | A spaced hyphen used as a dash: "yet - end a turn". | copy | Use a full stop |
| 40 | Lead-won messages (70 rows), Help p4 | Unclear "it": "It is taken back the same way it was won", "Miss the deadline and it falls". | copy: clarity | Name the subject |
| 41 | Panel name | "the Great Guilds panel" / "the Guilds panel" / "Guilds Log" next to a "Log" tab. | copy: consistency | One name |
| 42 | `derpy_gg_help_p3*` | "The latter means war, and pays far more." is hard to parse. | copy: clarity | Rephrase |
| 43 | Empire service owners | "Witch Hunters' Warrant" is sold by the Masons; "Blessed Wards" by the Engineers. | copy: lore fit | Rename or reassign |
| 44 | `derpy_gg_guild_desc_temple` (Chaos Dwarfs) | "against the Dwarfs and their buildings": "their" reads as the Dwarfs'. | copy: clarity | "and the Temple's buildings" |
| 45 | Help p4 | Patron effects are named without their numbers; the Workshop page gives +10% / +10%. | copy: completeness | Put the figures in the loc |
| 46 | Workshop l.163 | "Other races get no button" may contradict the generic flavour's text, which implies the panel opens. | R-38 (check) | Confirm, then fix one of the two |
| 47 | MCT wording (l.16, 156, 256, rate tooltips) | Filler intro; "a guild lost"; "as a percentage earned"; "Points per ..." where the rest says Reputation. | copy | Reword |
| 48 | MCT preset name | The hardest preset is "Cutthroat", which is also the Dark Elf race rule's name. | copy: clash | Rename the preset |
| 49 | Court tab | "0 turns to pay" reads as already expired, and "1 turns" is also possible; the comment says red where the code uses orange. | copy, code | "Due this turn" plus a singular form |
| 50 | Leaderboard header, bounty turns | "1 services bought", "1 patrons appointed", "1 turns left". | copy: plurals | Add `_1` variants, as `next_services_1` does |
| 51 | Court tab | The same figure appears twice (900 in the box and in the line; score 0 in the price box). | UI: duplication | Price box for prices only |
| 52 | Court patron card | No icon, and two lines that read as contradicting each other. | UI | Add an icon and merge the two lines |
| 53 | Header crest | Shows the current guild's glyph on the Bounties, Log and Help tabs. | UI: hierarchy | Use the panel crest on tabs that are not per guild |
| 54 | Footer "Favour: N" | Does not say which guild (0 on Bounties, 150 on the Leaderboard). | UI: clarity | Name the guild, or hide it off the guild tabs |
| 55 | Leaderboard | A player who leads a guild sees only their flag, with no "You". | UI | Mark the player's row |
| 56 | Lua tooltips l.1134-1148 | Hard-coded English with lowercase "reputation" and "favour". | copy, localisation | Move to loc and capitalise |
| 57 | Help tab | Wraps about 100px short of its box; the bottom third of page 1 is empty. | UI: dead space | Widen the wrap |
| 58 | Empty card slot | A guild with fewer than three services would show a bare plate. | R-27 | Hide the slot, or add a message |
| 59 | `preview_guilds_panel.py:821` | `--size` together with `--page` overwrites the Medium previews. | tool | Add the size suffix to the file name |
| 60 | 70 decorative `# ---- label ---` banners; 6 guild-name labels above `SERVICES` rows | They restate what the code already says. This is house convention. | code: low-value comments | Leave, or reduce to plain labels |
| 61 | Flavour aphorisms ("A promise in the ledger is a debt."); ":D" on the Workshop page | Aphorism pattern and an emoticon. They suit the voice. | copy | Keep; your call on ":D" |

## Not applicable (game UI, not a website)

- **R-32** (keyboard, tab order): the engine has no tab focus. Escape does close the panel.
- **Touch targets, breakpoints and mobile navigation:** there is no touch input. The size sets (#8-10, 26, 27) are the closest equivalent.
- **R-21 / R-34** (light and dark themes): there is one game skin per race. The emp, skv and dwf skins were checked instead.
- **R-27 loading state:** the panel draws in one step.
- **R-01, R-07, R-10, R-11, R-12:** the panel is drawn from CA art, not web defaults.
- **R-05, R-15-R-18, R-28, R-36:** these are landing-page rules. They were applied to the Workshop page only (#1-5).
- **R-19 motion:** the panel has no animation.
