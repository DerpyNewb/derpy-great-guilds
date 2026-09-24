# The Great Guilds - Empire and Dwarf flavours, built

2026-09-23. Built from `docs/superpowers/plans/2026-09-23-great-guilds-flavours.md` against
`docs/superpowers/specs/2026-09-23-great-guilds-flavours-design.md`. Packed and **deployed to `data/` 2026-09-23 18:47** (MD5 match; previous pack backed up
as `Modpacks/derpy_great_guilds.pack.bak_20260923_deployed_1fc5d725`). Not on the Workshop.

## 0. Read this first

- A player of `wh_main_emp_empire` or `wh_main_dwf_dwarfs` now sees their own race's guilds:
  names, ranks, services, blurbs, bounties, messages, icons, crest and panel grounds. Every
  other culture, Chaos Dwarfs included, is unchanged (one Help bullet aside, section 3).
- **One tag per culture**, appended to every key a player reads: `""` Chaos Dwarfs, `_emp`,
  `_dwf`. Whose tag is used: rank/lead/bounty = the holder's; a service bundle = the BUYER's
  (on a hostile target too); a message = the receiver's; the panel = the local player's.
- Feed indexes are 5001-5004 plus an offset per flavour: 0, 10, 20.
- The patron bundle is shared across all three; it is never tagged.

## 1. What shipped

`Modding Files/Modpacks/derpy_great_guilds.pack`, MD5 `8b5358255c8c4cf7b11f1be94ac092af`,
10,835,304 bytes, 60 files (the rank-flip build: 4,182,228 bytes, 34 files).

| Table / folder | Rows / files |
|---|---|
| `effect_bundles` | 127 (43 Chaos Dwarf + 42 per new flavour) |
| `effect_bundles_to_effects_junctions` | 137 |
| `missions` | 18 (6 bounties x 3) |
| `event_feed_message_events` | 12 (4 x 3) |
| loc | 1,250 |
| `ui/campaign ui/derpy_gg_icons/` | 21 (6 guilds + crest, x 3), all 74x74 flat silhouettes |
| `ui/campaign ui/derpy_gg_bg/` | 18 grounds, 790x700 |

Art sources, all CA's own and read offline out of `ui.pack`:

- **Icons:** CA's Empire and Dwarf building icons for the same trades (`empire_port`,
  `dwarf_trade_depot`, ...). Crests are `empire_imperial_cult` and `dwarf_city_karaz_a_karak`.
  `dwarf_hall_of_oaths` and `dwf_underdeep_grudges` were the first picks and are textured
  (51% / 69% commonest colour), so `make_guild_icons.py` refuses them.
- **Grounds:** six 790x700 windows panned across one loading-screen painting per race
  (`campaign_empire1.png`, `campaign_dwarfs1.png`), so paging from guild to guild moves across
  one picture. Same brightness gate as the Chaos Dwarf grounds (p99 34 under the scrim); they
  bake at x0.34-0.50, darker than the Chaos Dwarf x0.42-0.67 but readable in the previews.

None of the art goes to the public repo: `sync_guilds_repo.py`'s MANIFEST gained the plan and
this handoff only.

## 2. Code touched

- `tools/gen_great_guilds.py` - `FLAVOURS`, `_build_one(tag)`, `retag()`; `build()` is the
  Chaos Dwarf pass (byte-identical to the pre-change snapshot except the one bullet) then one
  tagged pass per flavour. New checks: `check_flavour_shape`, `check_flavours`,
  `check_flavour_mirror` (the Lua's `GG.FLAVOURED` must match `FLAVOURS`), and every existing
  per-key check now runs per tag.
- `zzz_derpy_guilds.lua` / `_ai.lua` - `GG.flavour_of`, `GG.tag`, `GG.feed`; every key site
  takes the right faction's tag.
- `zzz_derpy_guilds_ui.lua` - `GGUI.tag`, `GGUI.art`, `GGUI.icon`, `GGUI.paint_crest`,
  `GGUI.paint_opener`; loc lookups append the local player's tag.
- `tools/gen_guilds_ui.py` - Help page fit and opener/crest checks per flavour.
- `tools/make_guild_icons.py`, `tools/make_guild_backgrounds.py` - fetch and bake the new art.
- `tools/preview_guilds_panel.py` - `--flavour emp|dwf`.
- `tools/_guilds_harness.lua` - tag/feed, Empire bundles, lead keys, service/bounty, messages
  and panel blocks; the old two-culture lead test now expects per-culture lead keys.

## 3. The one Chaos Dwarf text change

Help page 2's MISSION bullet was shortened for every race: the Empire's page 2 measured 22
lines of a 21-line page. Nothing else a Chaos Dwarf player reads changed.

## 4. Old saves, and what the final review changed

The spec assumed the only saves in existence are Chaos Dwarf ones whose keys do not move.
The final review found that is true of the player's keys and NOT of the AI: an earlier build
covered all three races at once, so a live Chaos Dwarf campaign can hold Empire and Dwarf AI
factions (Golden Order, Clan Angrund) wearing the UNTAGGED rank and lead bundles. Without a
fix they would have kept those AND gained the tagged ones - rank effects doubled, and the
untagged copy never removed again.

Fixed before packing (`zzz_derpy_guilds.lua`): `GG.assert_ranks` also removes the untagged
rank bundles, every rank, from a flavoured faction, and `GG.reassert_leaders` removes the
untagged lead bundle from every faction of a flavoured culture, the foremost included. Both
run on the first turn start after a load, so the stale copies go then. Harness block "A SAVE
FROM THE BUILD THAT COVERED ALL THREE RACES AT ONCE"; both halves proven by a mutant. A
Chaos Dwarf faction is untouched (its tag is `""`, so the extra removal never runs).

**Multiplayer is only half covered.** Review focus 2 (Empire against Dwarfs, hostile service)
holds for an AI buyer. A HUMAN purchase goes `ComponentLClickUp` -> `GG.buy` directly, not
through `CampaignUI.TriggerCampaignScriptEvent`, so in multiplayer it changes the model on one
machine only - pre-existing, not caused by this work, and not fixed here. Two MP-only side
effects of the tags follow from the spec's rules: a hostile service bought on one target by
buyers of two races lands two differently tagged bundles that stack, and the victim reads
the attack under two names (their Log in their words, Faction Effects in the buyer's).

## 5. In-game checks still owed

1. Start an Empire campaign: panel names, crest on the HUD opener and beside the title,
   ground changes per guild.
2. Reach rank 2 with any guild: the promotion message in Empire words with the
   `emp/civilisation_up` picture; the Faction Effects title of the rank bundle.
3. Take a bounty: its title and `emp/generic` picture in the objectives panel.
4. Repeat 1-3 in a Dwarf campaign.
5. A Chaos Dwarf campaign: nothing changed except the one Help bullet.
6. Load the CURRENT Chaos Dwarf save: at the first turn start, Empire and Dwarf AI factions
   that held standing lose their untagged `derpy_gg_rank_*` / `derpy_gg_lead_*` bundles and
   carry only the `_emp` / `_dwf` ones.
7. As the Empire, open Help page 2: every line on screen (measured 21 of 21 offline).

## 6. In game, 2026-09-23 evening

The user played both races on the deployed build and reports the panels look right. Logs:
Dwarfs `script_log_230926_1953`, Empire `_2001` (new game), `_2014` and `_2023` (reloads),
battles `_2010` / `_2017`. All three guild scripts load, the opener places, the panel opened on
every tab and paged, and the first-contact notices fired on tagged keys
(`derpy_gg_notice_first_brass_dwf_*`, `..._brass_emp_*`, `..._notice_half_immortals_emp_*`).
Bounty boards posted 3 offers each; one Dwarf bounty was withdrawn when its target died
(intended). No script error names a guild file (the one campaign error is VCO's
`vco-disable-ca-wincons.lua`, nil `victory_objectives_ie`, every campaign).

**Still turn 1 in both.** Neither log has a single `FactionTurnStart` after load (a Chaos
Dwarf session that ends a turn logs ~236), so no AI faction has taken a turn: no AI standing,
no tech baselines, no rank-up, lead or AI-service message yet. Checks 2 and the AI half of 4
stay owed until a few turns have passed.

**Later that evening, Empire turns 1-5** (`script_log_230926_2126`, playing
`wh_main_emp_wissenland` at 1600x900). Rank-ups `derpy_gg_rank_{immortals,overseers,daemonsmiths}_2_emp`,
lead won/lost messages on `_emp` keys (one change per guild per turn, real rivalry, no
flicker), and the AI side working: 22 AI Empire factions hold standing (including OvN's
`ovn_mar_house_den_euwe` and the `cr_emp_*` factions), all have tech baselines and patrons,
and the Log holds 15 AI purchases. 14 of the 15 are the Daemonsmiths' `forge_rite`: the AI
earns 60 Daemonsmiths per technology and, five turns in, spends almost only that. A balance
observation, not a flavour bug. No script error names a guild file. Check 2 is done for the
Empire; the Dwarfs still need a few turns.

**Dwarfs turns 1-3** (`script_log_230926_2204`, playing `wh3_dlc25_dwf_malakai`). Same picture
on `_dwf` keys: `derpy_gg_rank_daemonsmiths_2_dwf`, lead won/lost messages, the notices, a
board every turn. 21 AI Dwarf factions hold standing (the `cr_dwf_*` factions included), 21
tech baselines, 20 patrons. No AI purchase yet and every AI Daemonsmiths at 0 - consistent
with turn 2: no AI had finished a technology since its baseline. AI Slavers is 0 in both
new races, which is timing, not a gap: it comes from sacking and slave buildings, and the
turn-40 Chaos Dwarf save has AI Slavers up to 90. Turn 3's board posted 2 offers, not 3,
because Malakai is at war with one faction and it has no unused region or lord left (logged).
Check 2 done for both races. No script error names a guild file.
