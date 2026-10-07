# Great Guilds player text: Codex editing report

2026-10-07. Completed the text pass described in [the work brief](HANDOFF_20261007_GUILDS_TEXT_HUMANIZE_CODEX.md). The [handover to Claude](HANDOFF_20261007_GUILDS_TEXT_HUMANIZE_CLAUDE.md) covers review and release work.

Reviewed all nine supported races and the generic fallback. Changed 3,440 of 8,980 generated localisation rows. Total localisation text fell from 728,562 to 685,149 characters, a reduction of 43,413 (6.0%). Good flavour text and concise labels were kept. This is a source and generated-text change; it has not been packed, deployed, uploaded or tested in game.

## Files changed

- Maintained source: `tools/gen_great_guilds.py` and `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua`.
- Regenerated outputs with changed bytes: `Modding Files/source/great_guilds/loc.tsv` and `missions.tsv` in the same folder.
- The other generated TSVs are byte-identical to the baseline. The generator also rewrote the MCT-name block in `zzz_derpy_guilds_ui.lua` and the generated bounty-data script; both campaign files are byte-identical to the baseline. No campaign logic, panel XML, check function or existing test was edited.
- Baselines, full command output, isolated editing copies and the comparison check are in `.skilltree_cache/guilds_text_20261007/`. That folder is working evidence, not a pack input.

## Changes by text family

Counts sum the rendered text across all nine races plus `_gen`, including unchanged names in the listed family. Families partition all 8,980 localisation rows. The MCT row counts its source string expressions, including unchanged labels and keys; it is separate from localisation.

| Family | Before | After | Changed rows |
|---|---:|---:|---:|
| Guild descriptions and names | 24,873 | 24,030 | 70 |
| Service descriptions and names | 154,104 | 151,360 | 662 |
| Effect bundles | 155,256 | 143,990 | 960 |
| Panel, Log and earnings | 62,043 | 55,730 | 390 |
| Bounties, objectives and demands | 41,358 | 38,682 | 432 |
| Help pages | 60,925 | 56,726 | 69 |
| Feed messages | 166,858 | 152,164 | 765 |
| Halls and building cards | 63,145 | 62,467 | 92 |
| MCT source strings | 8,412 | 7,454 | 39 expressions |

### Help pages

Shortened instructions, removed feeding/ladder metaphors and capitalised the currencies. Kept every heading/bullet position, placeholder and race branch. The Seat still raises the earnings limit, rather than the amount earned.

`derpy_gg_help_p1` (excerpt)

**Before:** -REPUTATION is earned by playing and is never spent. It alone sets your rank.

**After:** -Earn Reputation as you play. You never spend it; it alone sets your rank.

`derpy_gg_help_p7` (excerpt)

**Before:** -Each guild has halls of its own, raised in your settlements. One settlement holds one hall, so choose which guild it serves.

**After:** -Build guild halls in your settlements. Each settlement holds one hall, so choose which guild it serves.

### Guild descriptions and names

Tightened introductions and earning instructions. Kept the industrial Chaos Dwarf voice and each race's existing nouns. Guild and rank names are unchanged.

`derpy_gg_guild_desc_brass`

**Before:** Tally-keepers and caravan masters. They record every debt in the Dark Lands and forgive none of them.||You earn reputation from your income every turn, and from their own buildings.||By rank, for every region you own: income from all buildings +3% / +6% / +10% / +15% at 100 / 300 / 700 / 1500 reputation.

**After:** Tally-keepers and caravan masters. They record every debt in the Dark Lands and forgive none.||Earn Reputation from your income each turn and by completing their buildings.||By rank, for every region you own: income from all buildings +3% / +6% / +10% / +15% at 100 / 300 / 700 / 1500 Reputation.

`derpy_gg_guild_desc_immortals`

**Before:** The oath-sworn companies who fight for whoever holds their bond, and never break it.||You earn reputation from battles you win - double when you win outnumbered - and from their own buildings.||By rank, for every army: replenishment rate +3% / +6% / +10% / +15% at 100 / 300 / 700 / 1500 reputation. For your faction: recruitment capacity +1 / +2 / +3 at 300 / 700 / 1500.

**After:** Oath-sworn companies. They fight for whoever holds their bond and never break it.||Earn Reputation by winning battles, double when outnumbered, and completing their buildings.||By rank, for every army: replenishment rate +3% / +6% / +10% / +15% at 100 / 300 / 700 / 1500 Reputation. For your faction: recruitment capacity +1 / +2 / +3 at 300 / 700 / 1500.

### Service descriptions and names

Shortened repeated research, recruitment and upgrade clauses. Removed awkward comma chains from mechanical descriptions. Retained costs, cooldowns, rank requirements, targets and effect icons.

`derpy_gg_service_desc_bound_blueprint_emp` (excerpt)

**Before:** The Engineers' School hands over work already done. Completes the technology you are currently researching, at once.

**After:** The Engineers' School hands over its finished plans. Finishes your current research immediately.

`derpy_gg_service_desc_hire_immortals_skv` (excerpt)

**Before:** Black-furred and loyal for as long as the pay holds. Adds one unit of Stormvermin to an army of your choosing.

**After:** Black-furred and loyal for as long as the pay holds. Adds one unit of Stormvermin to your chosen army.

### Effect bundles

Replaced repetitive rule prose with shorter descriptions of rank, leadership, patron and purchased-service benefits. Retained every effect value, duration, scope and title.

`effect_bundles_localised_description_derpy_gg_rank_brass_3`

**Before:** Rank 3 of 5 with The Brass Tablets, reached at 300 reputation. +6% income from all buildings, for every region you own. This lasts as long as the rank does.

**After:** Rank 3 of 5 with The Brass Tablets at 300 Reputation. +6% income from all buildings for every region you own. Keep this rank to keep the bonus.

`effect_bundles_localised_description_derpy_gg_patron`

**Before:** This lord speaks for one of the Great Guilds, and the guild answers. +10% replenishment and +10% campaign movement for their army. While they hold the post, that guild's reputation pays more and its services cost up to 10% less. Only one lord may hold it.

**After:** This lord serves as a guild Patron. +10% replenishment and +10% campaign movement for their army. While appointed, they increase earnings with that guild and reduce its service prices by up to 10%. Only one lord can hold the post.

### Feed messages

Made notices and failures direct, shortened repeated leadership explanations and retained the required promotion sentences and articles before guild names.

`message_event_text_text_derpy_gg_bounty_fail_primary`

**Before:** Work you took from a guild has gone undone. The favour you put up is lost, and reputation with the guild with it; the card named the sum. Handing an offer back costs only the favour.

**After:** You failed a guild bounty. You lose your Favour stake and the Reputation shown on the card. Returning a bounty costs only the stake.

`message_event_text_text_derpy_gg_lead_won_brass_primary`

**Before:** You now hold more reputation with The Brass Tablets than any other power in the world. Their leader's bonus is yours, and, unless the settings say otherwise, their finest service is sold to nobody else.

**After:** You now lead The Brass Tablets. You gain their leader's bonus and, unless the settings say otherwise, exclusive access to their finest service.

### Bounties, objectives and demands

Tightened mission instructions and demand descriptions. Hero objectives still require two successful actions where specified. Kill objectives were not narrowed to battle kills.

`missions_localised_description_derpy_gg_job_brass`

**Before:** The Brass Tablets want to see your treasury full, and kept full. Hold the sum named on the Great Guilds panel.

**After:** The Brass Tablets demand full coffers. Hold the amount shown on the Great Guilds panel.

`mission_text_text_derpy_gg_hero_sabotage`

**Before:** Succeed with two hero actions against the settlement named on the Great Guilds panel.

**After:** Complete two successful hero actions against the settlement shown on the Great Guilds panel.

### Halls and building cards

Shortened the building reward line, hall-browser description and DLC fallback clauses. Common hall descriptions are constrained by exact self-test expectations and were kept; see the fixed-text notes below.

`effects_description_derpy_gg_built_brass`

**Before:** [[col:yellow]]Completing this earns %n Reputation with the Brass Tablets, and the same in Favour[[/col]]

**After:** [[col:yellow]]Complete this for %n Reputation with the Brass Tablets and matching Favour[[/col]]

`building_sets_onscreen_description_derpy_gg_set_guild_halls`

**Before:** Raise halls for the guilds that favour you. A guild's halls appear here once you are Indebted with it.

**After:** Build halls for your guilds. Their halls appear here once you reach Indebted with them.

### Panel, Log and earnings

Shortened selection instructions, price explanations, Court tooltips and Log descriptions. Kept fixed labels no longer than before and preserved every runtime placeholder.

`derpy_gg_needs_region_own`

**Before:** Select one of your OWN settlements on the campaign map first, with a building that still has somewhere to go.

**After:** Select one of your settlements on the campaign map with a building that can be upgraded.

`derpy_gg_log_help`

**Before:** Every rank you gain or lose, every service you buy, every service your rivals buy or use against you, every price a guild puts on you, and every guild lead that changes hands. The most recent entries are kept.

**After:** Records rank changes, your purchases, rivals' services, bounties on you and changes in guild leadership. Keeps the most recent entries.

### MCT

Rewrote 39 descriptions or label strings. Edited strings total 5,840 to 4,882 characters; the whole source-string sum is shown above. Capitalised Reputation in two logging labels without changing their length. Corrected the explicitly identified stale description from Six guilds to Seven guilds. Option keys, values, comments, generated names and Lua control flow are unchanged.

**Before:** Six guilds span the world. Earn their favour by playing your campaign, spend it on services. These values are read once, when a campaign starts, and are then fixed for the life of that save - change them from the main menu before starting a new one. In multiplayer the host's settings are used for every player.

**After:** Seven guilds span the world. Earn their Favour during your campaign and spend it on services. Settings are fixed when a campaign starts. Change them from the main menu before starting a new one. In multiplayer, every player uses the host's settings.

**Before:** The guilds change the services they offer every this many turns. Each guild still offers three at a time, drawn from a larger set.

**After:** Turns between changes to the services on offer. Each guild offers three at a time, chosen from a larger set.

**Before:** What reputation costs to hold. Every guild you have reputation with charges some back each turn, scaled by the rank you hold there - 100 means one point a turn at Unmarked and five at Exalted, so the top of the ladder is the dearest seat. 0 switches it off and reputation only ever falls to a rival, a demand or a failed bounty.

**After:** Each guild charges Reputation every turn according to your rank. At 100, Unmarked costs one point a turn and Exalted costs five. 0 switches upkeep off: only rivalry, demands and failed bounties can then reduce Reputation.

## Name proposals, not applied

| Existing name | Proposal | Race | Reason |
|---|---|---|---|
| Losing reputation | Losing Reputation | All flavours | Capitalise the guild currency. Same length, but kept unchanged because Help titles are names. |

No guild, rank, service, hall-level, panel-title or tab-name changes are proposed.

## Text kept because checks depend on it

- The four promotion phrases in the brief remain exact: `A service that was closed to you is open.`, `There is no higher rank.`, `only to whoever leads them` and `You may now raise a <hall name>.` A shorter first phrase such as "A new service is available." would require the author to approve a check update.
- `selftest()` also looks for `fallen` in the demand-failure message, `falls` in the Court demand tooltip, `it falls` in Help, and the expired-demand heading. The first wording pass failed that assertion despite keeping the meaning. The prose was adjusted to retain these phrases; the checks were not changed. Skaven still omit the loss clauses.
- `selftest()` asserts complete Chaos Dwarf level-2 hall descriptions and the Empire level-0 temple description. Their repeated "Earns ...", "Lowers the price ..." and "Trains ..." clauses remain. The hall unit check parses `Trains` and requires `if you own the pack` when a DLC unit has no fallback at that level. Any later rewrite must preserve those contracts or receive approval to revise the checks.
- Kept the Help-page building examples that self-tests identify by exact wording, the generic fallback's `no services` phrase, and the numeric/markup formatting that the generator and Lua harness consume.
- High Elf `Influence` was retained where it names the actual vanilla resource. It was not used for guild Reputation. Deleting or replacing that resource name would change the stated service reward.

## Existing factual questions for the author

These were preserved for review rather than corrected during a wording pass.

1. Help page 5 still says four things reduce Reputation and three can cost a rank. The Skaven branch removes expired-demand losses, so those counts do not match its own list. The counts are written as words; no factual correction was applied.
2. The same Help page says ignoring a demand costs more than meeting it asks for. The MCT presets describe different rewards and penalties, and the payment may be gold or Favour while the penalty is Reputation. The claim needs a mechanical review.
3. The MCT demand deadline and penalty tooltips describe the common loss rule without the Skaven exception. The in-game Skaven Court, failure message and Help branch retain the free-expiry rule.
4. The `_gen` hire blurb conditionally promises elite infantry "where the Company keeps one", while source comments say unsupported races have no hire unit. The generic flavour is a data fallback; its original conditional claim was kept.
5. Help describes a bonus at each rank, while the generator explicitly grants no bundle at Unmarked/rank 1. The existing general claim was not changed into a new rule.

## Validation evidence

Baseline generator and Lua checks passed before integration. Checks were rerun against the combined regenerated outputs; the complete suite passed after restoring the demand phrases. Checks were run at baseline and after integration, rather than after each isolated family edit.

The comparison check also confirms equal localisation keys; unchanged names, numeric tokens, placeholders and markup; unchanged Help headings/bullet positions; no fixed label growth; no string over the +10% ceiling; and smaller totals for every family. The generator AST differs only in string values. Check functions, self-test source and docstrings match the baseline. MCT non-text tokens, comments and digit values also match.

Command tails follow. Full output is in `.skilltree_cache/guilds_text_20261007/`.

`py tools/gen_great_guilds.py --write` (exit 0)

```text
wrote Modding Files/source/great_guilds\cai_construction_system_building_values.tsv
wrote Modding Files/source/great_guilds\settlement_type_to_building_chains_junctions.tsv
wrote Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua
wrote Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua
```

`py tools/gen_great_guilds.py --check` (exit 0)

```text
hall AI donor: slavers role economy -> wh2_main_skv_monsters [cai_military_group]: has an effect naming economy_gdp
hall AI donor: temple role order -> wh2_main_skv_order [cai_support_group]: carries the hall's own effect wh_main_effect_public_order_base
```

`py tools/gen_great_guilds.py --selftest` (exit 0)

```text
selftest ok: 7 guilds, 95 services, 90 bundles, 774 loc
```

`"C:\Program Files (x86)\Lua\5.1\lua.exe" tools/_guilds_harness.lua` (exit 0)

```text
harness ok
```

`"C:\Program Files (x86)\Lua\5.1\lua.exe" tools/_guilds_bounty_harness.lua` (exit 0)

```text
bounty harness ok
```

`"C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files/pack/script/mct/settings/derpy_great_guilds.lua"` (exit 0)

```text
(no output)
```

`py .skilltree_cache/guilds_text_20261007/check_text.py` (exit 0)

```text
text audit ok: 3440 of 8980 loc rows changed; 728562 -> 685149 characters
Guild descriptions and names: 24873 -> 24030 (70 changed)
Service descriptions and names: 154104 -> 151360 (662 changed)
Effect bundles: 155256 -> 143990 (960 changed)
Panel, Log and earnings: 62043 -> 55730 (390 changed)
Bounties, objectives and demands: 41358 -> 38682 (432 changed)
Help pages: 60925 -> 56726 (69 changed)
Feed messages: 166858 -> 152164 (765 changed)
Halls and building cards: 63145 -> 62467 (92 changed)
Keys, names, placeholders, numbers, markup, fixed label lengths, Help structure, checks and non-text data preserved.
```

`py tools/preview_guilds_panel.py` (exit 1)

```text
wrote G:\Modding for resources\.skilltree_cache\ui_preview\gg_pick.png  (the instruction takes 2 of the card's 2 lines)
  LOW CONTRAST 4.2:1 at +0px  Buy
```

`py tools/preview_guilds_panel.py --flavour hef` (exit 1)

```text
wrote G:\Modding for resources\.skilltree_cache\ui_preview\gg_pick_hef.png  (the instruction takes 2 of the card's 2 lines)
  LOW CONTRAST 4.2:1 at +0px  Buy
```

`py tools/preview_guilds_panel.py --flavour skv --help-page 1` (exit 0)

```text
wrote G:\Modding for resources\.skilltree_cache\ui_preview\gg_help_p1_skv.png
```

Both the Chaos Dwarf and High Elf full previews exited 1 for the same pre-existing `LOW CONTRAST 4.2:1 ... Buy` warning. Both also reported it before this edit. Neither reported `TOO WIDE`, and no new contrast finding appeared. The Skaven Help-page preview exited 0.

Visually inspected the Chaos Dwarf and High Elf Guilds PNGs and Skaven Help page 1. The preview font is narrower than the game font; offline fit does not establish fit in game.

## Handover

Claude should review the fixed text and factual questions above, then handle packing, deployment and repository sync through the owning workflow. No importer, mutation runner, pack save, game-copy update or repository sync was performed by this pass.
