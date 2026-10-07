# Handover to Codex: humanize every player-facing text in The Great Guilds

Completed on 2026-10-07. See [the editing report](CODEX_GUILDS_TEXT_REPORT_20261007.md)
and [the handover to Claude](HANDOFF_20261007_GUILDS_TEXT_HUMANIZE_CLAUDE.md).
Source edited and TSVs regenerated; packing and deployment remain with Claude.

2026-10-07. Written for Codex working in this workspace (`G:\Modding for resources`). Read it
whole before editing anything. Every path below is relative to the workspace root, and
**every command must be run from the workspace root**: the generator opens its Lua inputs
by relative path and fails from anywhere else.

## 1. The job

The Great Guilds is a Total War: WARHAMMER III campaign mod. A player reads about 9,000
lines of its text: guild descriptions, service cards, Help pages, feed messages, bounty
missions, effect-bundle tooltips, hall building cards and the MCT settings page. They are
spread over ten race flavours.

Much of it reads as written by a machine. Typical faults:
- rule-text cadence ("This lasts as long as the rank does.");
- the same sentence shape on every card;
- explanations of the mechanism instead of the fiction;
- inconsistent capitals ("reputation" in one line, "Reputation" in the next);
- defensive over-explanation.

**Rewrite it so it reads as if a person wrote it for players.** Keep every fact, number,
rule and key exactly as it is. This is an editing job, not a design job: no mechanic
changes, no balance changes, no new strings.

**In scope:** the prose. That covers descriptions, blurbs, Help pages, feed titles and
bodies, mission titles and descriptions, bounty and demand text, tooltips, hall building
descriptions, effect-bundle titles and descriptions, the race-page lines and the MCT labels
and tooltips.

**Proposals only, do not apply:** NAMES. That means guild names, rank names, service
names, hall level names, the panel title and tab labels. They are lore-checked against CA's
own text and capped in length, and a name change ripples into feed titles, logs and checks.
List any name you would change in the report (section 7) with your reason, and leave the
code as it is.

## 2. Where the text lives (edit the source, never the output)

`Modding Files/source/great_guilds/loc.tsv` is **GENERATED**. Do not edit it by hand: the
next `--write` overwrites it, and the packer refuses a TSV that disagrees with the generator.
Read it to see the current rendered text. Its columns are key, text, `false`; one key per
race, suffixed with the flavour tag (none for Chaos Dwarfs).

The text comes from two files.

### A. `tools/gen_great_guilds.py` (about 7,700 lines): all of the loc

Search by name, because line numbers drift.

| Source | What it writes |
|---|---|
| `FLAVOURS[tag]` | per race: `guilds` (names), `ranks`, `services` (names), `blurbs` (service descriptions that differ from the Chaos Dwarf ones), `desc` (guild descriptions, `flavour||earn` split on `||`), `bounties` (mission titles and descriptions), `feed` (feed message lines), `pics` (images: do not touch) |
| `GUILD_DESC`, `SERVICE_BLURB`, `EFFECT_BLURB`, `EFFECT_BLURB_EXTRA`, `PATRON_BLURB`, `PATRON_NAME` | the Chaos Dwarf base text that other races fall back to |
| `POOL_NAMES`, `TEMPLE_NAMES`, `TEMPLE_FLAVOUR`, `TEMPLE_TEXT`, `RACE_TEXT` | pooled services, the seventh guild (the temple) and each race's Help page 6 (earn route and twist) |
| `BOUNTIES`, `BOUNTY_EXTRA`, `BOUNTY_TEXT`, `HERO_OBJECTIVE_TEXT`, `DEMAND_KINDS` | bounty missions, objectives and Court demands |
| `EARN_SHORT`, `HELP_PAGE_TITLES`, `help_pages()` | the Help tab |
| `HALL_RACES`, `HALL_BONUS`, `HALL_SET_NAME` | hall nouns and level names (names: proposals only) and the hall building descriptions |
| `_build_one()` | everything else: panel labels, card captions, the Log, the earnings sheet, promotion and leadership feed messages, rank-ladder sentences, tooltips. Mostly f-strings and `%` templates |

**To find where any line comes from:** take a distinctive phrase from `loc.tsv` and search
`gen_great_guilds.py` for it. If nothing matches, the line is assembled from parts: search
for a shorter piece, or for the loc key's prefix (for example `derpy_gg_needs`).

### B. `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua`: the MCT page

Hand-written, about 400 lines. Edit only the string literals passed to `set_description`,
`set_text`, `set_tooltip_text` and `add_new_section`, and the `LOCK_REASON` text.

- Do not touch the block between `-- BEGIN GENERATED: GGUI.MCT_NAMES` and
  `-- END GENERATED`: the generator rewrites it.
- **Known stale line:** `set_description` still says "Six guilds". There are seven. Fix it.

The panel Lua (`zzz_derpy_guilds*.lua`) has no player English of its own: every label is
looked up by key. Do not edit those files.

## 3. Hard rules: break one and the mod breaks or a check fails

1. **Never change a loc key, a dict key, a service `key`, a guild slug or a flavour tag.**
   Change values only.
2. **Never retype a number.** Most numbers are formatted in from data (`%d`, `%s`, `{}`,
   `+%d%%`, `RANK_VALUES`, `HALL_REP`, and so on). Keep every placeholder and its order. If a
   sentence needs reordering around a placeholder, keep the placeholder intact.
   `check_promotion_text` and `states_value` assert that a bundle's description prints its
   own value.
3. **Markup survives byte for byte:**
   - `||` is a line break.
   - In Help pages a line starting `#` is a heading and `-` is a bullet. Every page must
     open with a heading, and no single line may contain `||`.
   - `[[col:yellow]]`, `[[col:red]]` and `[[/col]]` are colour tags.
   - `[[img:path]]` is an inline icon. Keep it where it is, usually at the start of a
     service description.
4. **Length.**
   - The game's font is about 25-30% wider than any preview, and the panel does not clip.
     The Leaderboard tab label overflowed its frame today for exactly this reason.
   - **Fixed-width labels must not get longer at all.** These are tab labels, button
     captions, card titles, rank and guild names, header fragments, the `derpy_gg_needs*`
     and `derpy_gg_cost*` keys, and Log filter labels.
   - **Everything else should come out the same length or shorter.** Treat +10% on a
     single string as the ceiling, and check that the total per family went down.
   - Help pages have 21 line slots. `check_help_pages` fails a page over the limit and
     warns within 3 of it, before any wrapping.
   - The harness fails any tooltip that would draw too many lines, at about 55 characters
     a line.
5. **Feed titles keep the article:** "The Brass Tablets", never "Brass Tablets" mid-title
   (`check_titles`). Every guild name starts with "The ".
6. **Fixed sentences the checks look for** (`check_promotion_text`). Keep these exact
   strings in the rank promotion messages:
   - "A service that was closed to you is open."
   - "There is no higher rank."
   - "only to whoever leads them"
   - "You may now raise a <hall name>."

   If you want to change one, propose it in the report and leave the check alone.
7. **Lore words stay in their own race.**
   - `CHD_ONLY_WORDS` (Hashut, Zharr, Dark Lands, slave, Hobgoblin, Infernal, Daemon)
     must not appear in another race's text. `FLAVOUR_WORDS_ALLOWED` lets `slave` through
     for the Dark Elves and the Skaven only.
   - Do not invent lore: no new place, god, title or unit name that is not already in the
     text or in CA's game.
   - If unsure, keep the existing noun.
8. **The author's word rules** (standing rules, not taste):
   - **Reputation** and **Favour**, capitalised, wherever they name the guild currencies.
     British spelling (Favour, honour, armour).
   - Never "standing". "Influence" is a different mod's word, so do not use it.
   - No developer jargon in player text: not cap, accrue, rep, ratchet, gated, tick, AI,
     HUD, agent, buff, proc, "by default", "league table". Say "limit each turn", "rivals",
     "heroes", "the settings".
   - Never the word "rung". Use tier, level, step or band.
   - No emojis anywhere.
9. **Plain over ornate.** Every race's guilds should sound like that race (Chaos Dwarf
   ledgers and chains, Bretonnian chivalry, Skaven scheming), but a sentence a player has to
   read twice is worse than a flat one. In flavour lines, one vivid clause beats three
   adjectives. In mechanical text (tooltips, Help, costs), say what happens in the fewest
   ordinary words.

## 4. What good looks like

Before (`derpy_gg_rank_brass_3` bundle description, current):

> Rank 3 of 5 with The Brass Tablets, reached at 300 reputation. +6% income from all
> buildings, for every region you own. This lasts as long as the rank does.

After (same facts, same placeholders):

> Sworn with the Brass Tablets (300 Reputation): +6% income from all buildings in every
> region you own, for as long as you keep the rank.

This is an illustration, not a template. If every bundle ends up with this exact shape, the
job has failed in a new way. Vary the shape across families and races.

Keep what already works. The bounty descriptions such as "The Tablets want the tolls of that
place counted in our column. Take it intact." already have voice: tighten them, do not
flatten them.

## 5. Order of work

Do one family at a time, and run the checks after each:

1. Help pages (`help_pages()`, `EARN_SHORT`, `RACE_TEXT`): the most-read and most-constrained.
2. Guild descriptions (`GUILD_DESC`, `FLAVOURS[*]["desc"]`, `TEMPLE_FLAVOUR`).
3. Service descriptions (`SERVICE_BLURB`, `FLAVOURS[*]["blurbs"]`, `POOL_NAMES` prose, the temple's).
4. Effect-bundle titles and descriptions (rank, leader, service, Seat, patron).
5. Feed messages (promotion, leadership, demand, hostile hit, rival bounty, rotation).
6. Bounties, objectives and demands.
7. Hall building descriptions.
8. Panel labels, tooltips, Log and earnings lines (the length rule bites hardest here).
9. The MCT page.

All nine races, every family. Tags: `""` Chaos Dwarfs, `_emp`, `_dwf`, `_brt`, `_cth`,
`_ksl`, `_def`, `_hef`, `_skv`. `_gen` is data only (an MP fallback); keep it consistent but
low priority.

## 6. Checks: run after every family, all must pass

```powershell
py tools\gen_great_guilds.py --write        # regenerate loc.tsv and the TSVs from your edits
py tools\gen_great_guilds.py --check        # exit 0 required (~25 s)
py tools\gen_great_guilds.py --selftest     # "selftest ok: 7 guilds, 95 services, 90 bundles, 774 loc" (the loc count may change only if a template's line count changed)
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua         # "harness ok" (reads loc.tsv: run --write first)
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_bounty_harness.lua  # "bounty harness ok"
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\mct\settings\derpy_great_guilds.lua"
```

**Baseline on 2026-10-07, before any edit:** all of the above pass, and
`gen_great_guilds.py --check` exits 0.

The `--check` exit code is the gate. If a check fails, fix the text; do not edit the check.

Then render the panel for at least the Chaos Dwarfs and two other races and look at the PNGs
in `.skilltree_cache/ui_preview/`:

```powershell
py tools\preview_guilds_panel.py --flavour hef
py tools\preview_guilds_panel.py --flavour skv --help-page 1
```

- It exits 1 on text wider than its box or on low contrast.
- **Known before your work:** `LOW CONTRAST 4.2:1 ... Buy` on `hef`. It is not yours; ignore
  it, but report any NEW finding.
- The preview's font is narrower than the game's, so a pass is necessary but not proof of
  fit. That is why the length rule in section 3 exists.

## 7. Do not

- Do not edit `loc.tsv` or any other generated TSV by hand. Do not edit any `.pack`, `.lua`
  under `script/campaign/mod/`, `.twui.xml`, any check function or any test.
- Do not run `tools\import_great_guilds.py` (it packs through RPFM), copy anything into the
  game's `data/` folder or the Steam Workshop folder, or touch `repos\`. Packing, deploying
  and the GitHub sync are done afterwards by the author's other agent.
- Do not run `tools\mutate_guilds.py`. It mutates the shipped Lua and takes a long time,
  and a text pass does not need it.
- Do not create new loc keys, and do not delete any.

## 8. What to hand back

1. The edited `tools/gen_great_guilds.py` and `derpy_great_guilds.lua` (MCT), with
   `loc.tsv` and the other TSVs regenerated by `--write`.
2. A report at `docs/sessions/CODEX_GUILDS_TEXT_REPORT_20261007.md` with:
   - per family: what kind of change was made, two or three before/after pairs, and the
     character count before and after (sum of that family's loc text across all races);
   - **name proposals** (section 1), not applied: old name, proposed name, race, reason;
   - **sentences you wanted to change but could not** (fixed check strings, placeholders
     that forced an awkward order), so the author can decide;
   - anything that looked factually wrong while you read it (a number that disagrees with
     another line, a rule described two ways). Report it; do not "fix" a fact;
   - the output tail of every command in section 6.
3. A stop condition: if any check cannot be made to pass without breaking a rule above,
   stop, revert that family, and say so in the report.

## 9. Context the author has already settled

- The mod covers exactly nine races. Any other race gets no guilds: do not write text
  implying a tenth.
- Each race has seven guilds; the seventh is the temple (faith and magic), which has no
  rival.
- Halls have three levels per guild, one hall per settlement. The **Seat** is held by
  leading a guild while holding its top hall.
- The Skaven twist is Treachery: rivalry hits harder, and an expired demand costs nothing.
  Every expired-demand sentence for the Skaven already branches on this. Keep the branch.
- The author's own docs on the mod are `repos/derpy-great-guilds/README.md` (the player's
  view) and `repos/derpy-great-guilds/docs/DEVELOPMENT.md` (internals). Read the README
  first for tone and facts.
