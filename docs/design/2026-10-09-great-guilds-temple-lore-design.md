# Great Guilds - the Temple per race, by its own lore

Date: 2026-10-09. Status: implemented in build `f41a33d9` (Workshop folder), unseen in game.

## 1. Why

A player on the Workshop page (Empire, Elspeth): "When I support the Colleges of Magic I expect
more magical rewards and buffs." The temple guild was built as the Temple of Hashut and renamed
per race (`TEMPLE_NAMES`, `TEMPLE_FLAVOUR`), so every race's temple pays public order on all four
permanent layers - rank, leader, hall, seat - and only one Empire reward of about sixteen is
magical (the hall's wizard cap, `HALL_EXTRA`). Meanwhile the Empire's Winds of Magic service sits
under the Engineers' School ("The Colleges' Tithe", `spirit_siphon`).

Goal: a player who backs their race's temple can name what it does from the rank bonus alone, and
it is what that order does in the lore. Lore over coverage: the Dwarfs get no magic.

## 2. Decisions taken (author, 2026-10-09)

- Theme per race follows each order's own lore (not "magic for everyone").
- Scope: the four permanent layers plus three signature services per race. Service names, kinds,
  costs and cooldowns are unchanged.
- The Empire's "The Colleges' Tithe" (Winds) moves to the Colleges; the Engineers' Empire slot gets
  an engineering effect. The same overlap for Cathay, Skaven and Chaos Dwarfs is left alone.
- Halls stay LOCAL (a lodge is buildable in any settlement, so a faction-wide hall effect would stack
  once per lodge). Exceptions are per-turn resource effects CA itself puts on buildings at faction
  scope (Kislev, Chaos Dwarfs), which stack by design in vanilla too.
- The seat gets its own per-race effect instead of "the hall's effect, faction-wide, at a third".

## 3. Permanent layers

Every pair below was read from 9.0 `db.pack` on 2026-10-09: bundle pairs from
`effect_bundles_to_effects_junctions`, hall pairs from `building_effects_junction`. "max" is
vanilla's largest magnitude; `check()` / `check_halls()` allow 1.5x it (bundles only when vanilla has
3+ rows on the pair).

### 3.1 Rank ladder (ranks 2-5) and leader bundle

| Tag | Effect | Scope | Ladder | Leader | Vanilla |
|---|---|---|---|---|---|
| `_emp`, `_cth`, `_skv`, `""` (Chaos Dwarfs) | `wh3_main_effect_winds_of_magic_pool_cap` | faction_to_force_own | 3/6/10/15 | 10 | 36 rows, 0..50 |
| `_dwf` | `wh_main_effect_force_stat_magic_resistance` | faction_to_force_own | 3/6/10/15 | 10 | 6 rows, 5..25 |
| `_brt`, `_hef` | `wh_main_effect_force_stat_ward_save` | faction_to_force_own | 2/4/6/8 | 5 | 6 rows, 5..20 |
| `_ksl`, `_gen` | `wh_main_effect_force_stat_leadership` | faction_to_force_own | 2/4/6/8 | 5 | 69 rows, -15..20 |
| `_def` | `wh_main_effect_force_stat_melee_attack` | faction_to_force_own | 2/3/4/6 | 4 | 25 rows, -10..15 |

All are `is_positive_value_good` true; every value is positive.

### 3.2 Hall local bonus (levels 1/2/3)

| Tag | Effect | Scope | Values | Vanilla | Card |
|---|---|---|---|---|---|
| `_emp` | `wh_main_effect_agent_recruitment_xp_wizard_empire` | province_to_province_own_unseen | 1/2/3 | 5 rows, 2..5 | hidden: hall text states it |
| `_dwf` | `wh_main_effect_agent_recruitment_xp_runesmith` | province_to_province_own_unseen | 1/2/3 | 3 rows, 1..2 | hidden |
| `_brt` | `wh_dlc07_effect_chivalry_building` | region_to_region_own | 10/20/30 | 6 rows, 20..50 (CA's `brt_worship`) | shown |
| `_cth` | `wh3_main_effect_agent_recruitment_xp_cth_astromancer` | province_to_province_own_unseen | 1/2/3 | 1 row, 7 | hidden |
| `_ksl` | `wh3_main_effect_ksl_orthodoxy_support_buildings` | faction_to_faction_own_unseen | 1/2/3 | 13 rows, 1..25 (CA's religion buildings) | hidden; stacks per lodge, as CA's do |
| `_def` | `wh2_main_effect_building_unit_xp_levels_def_resource_medicine` | province_to_province_own | 1/1/2 | 2 rows, 1..2 | shown |
| `_hef` | `wh2_main_effect_agent_recruitment_xp_hef_mage` | province_to_province_own_unseen | 1/2/3 | 6 rows, 2..5 | hidden |
| `_skv` | `wh3_main_effect_corruption_skaven_buildings` | region_to_region_own | 2/4/6 | 134 rows, 1..15 | shown |
| `""` | `wh3_dlc23_effect_pooled_resource_conclave_influence_gain_temples` | building_to_faction_own | 5/10/15 | 3 rows, 5..25 (CA's temple guardhouse) | shown; stacks per lodge |
| `_gen` | unchanged: `wh_main_effect_public_order_base` | province_to_province_own_unseen | 2/4/6 | | hidden |

- `HALL_EXTRA[("temple", "_emp")]` (Battle Wizard cap +1/2/3) stays.
- `HALL_EXTRA[("temple", "_skv")]` is removed: its Skaven-corruption effect becomes the hall's main effect.

### 3.3 Seat bundle (while leading, fixed)

| Tag | Effect | Scope | Value | Vanilla |
|---|---|---|---|---|
| `_emp` | `wh2_dlc14_effect_magic_cost_all_lores_percentage` | faction_to_force_own | -5 | 7 rows, -25..15; good sign NEGATIVE |
| `_dwf` | `wh_main_effect_force_stat_leadership` | faction_to_force_own | 3 | 69 rows |
| `_brt` | `wh_main_effect_agent_recruitment_xp_wizard_bretonnia` | faction_to_province_own | 2 | 1 row, 4 |
| `_cth` | `wh_main_effect_technology_research_points` | faction_to_faction_own_unseen | 5 | 64 rows, -100..300 |
| `_ksl` | `wh3_main_effect_agent_recruitment_xp_ksl_frost_maiden` | faction_to_province_own_unseen | 2 | 1 row, 3 |
| `_def` | `wh2_main_effect_agent_cap_increase_def_death_hag` | faction_to_faction_own_unseen | 1 | 1 row, 2 |
| `_hef` | `wh_main_effect_force_stat_magic_resistance` | faction_to_force_own | 5 | 6 rows, 5..25 |
| `_skv` | `wh3_main_effect_corruption_skaven_events` | faction_to_province_own | 2 | 2 rows, 1..5 |
| `""` | `wh_main_effect_force_stat_magic_resistance` | faction_to_force_own | 5 | 6 rows |
| `_gen` | `wh_main_effect_force_stat_leadership` | faction_to_force_own | 3 | 69 rows |

**Correction to the chat design:** the Skaven seat was "Grey Seer recruit rank +3", but
`wh3_dlc29_effect_thanquol_levels_grey_seers` has building rows only and no bundle pair, so it can
never be a seat. The spec uses Skaven corruption +2 in every province instead, the bundle twin of
the hall's effect. Hidden seat effects (`_unseen`) are stated in the seat bundle's description.

The seat's script term (per-turn Reputation limit x1.5) is unchanged.

## 4. Signature services

Overrides go in the existing per-row `for_tag` dict on three temple services. Each override sets
`effects` and `text`. Duration, kind, cost and cooldown are unchanged: `hashut_blessing` is rank 2,
one army, 5 turns. `zeal` is rank 3, one army, 5 turns. `holy_war` is rank 4, faction-wide, 10 turns.

Army pairs use the `force_to_force_own` scope. Faction pairs use `faction_to_force_own`.

| Tag | `hashut_blessing` | `zeal` | `holy_war` |
|---|---|---|---|
| `_emp` | magic_resistance +15 | magic_cost -20 | winds_of_magic_events +5, magic_cost -10 |
| `_dwf` | magic_resistance +15 | unchanged | melee_attack +4, leadership +6 |
| `_brt` | ward_save +15 | leadership +10, charge_bonus_pct +10 | leadership +6, `wh2_dlc14_effect_force_charge_bonus_add` +10 |
| `_cth` | magic_cost -20 | winds_of_magic_events +8 | winds_of_magic_events +5, leadership +4 |
| `_ksl` | ward_save +10 | unchanged | leadership +6, melee_attack +4 |
| `_def` | ward_save +10 | melee_attack +8, weapon_strength +10 | melee_attack +4, leadership +6 |
| `_hef` | ward_save +15 | magic_cost -20, winds_of_magic_events +5 | leadership +6, magic_resistance +10 |
| `_skv` | magic_cost -20 | unchanged | winds_of_magic_events +5, `wh_main_effect_character_stat_miscast` -10 |
| `""` | physical_resistance +10 | unchanged | winds_of_magic_events +5, leadership +6 |
| `_gen` | unchanged | unchanged | unchanged |

Vanilla ranges for the `force_to_force_own` pairs:

| Effect | Rows | Range |
|---|---|---|
| magic_cost | 29 | -100..70 |
| winds_of_magic_events | 3 | -5..10, so the ceiling is 15 |
| magic_resistance | 3 | max 20 |
| ward_save | 1 | 15, too few rows for a ceiling |
| physical_resistance | 5 | -10..30 |
| melee_attack | 36 | |
| leadership | 66 | |
| weapon_strength | 37 | |

Faction-wide pairs: miscast on `faction_to_force_own` has 3 rows, -50..-8, and its good sign is
negative. charge_bonus_add on `faction_to_force_own` has 8 rows, 5..25.

The Engineers' `spirit_siphon` gains a `_emp` override: `wh_main_effect_force_stat_physical_resistance`,
faction_to_force_own, +5, 8 turns. That pair has 8 rows, 5..15. The Empire name
"The Colleges' Tithe" becomes "Nuln Steel" in `POOL_NAMES["_emp"]`. The service's `_dwf` override
stays.

## 5. Build

All changes are in `tools/gen_great_guilds.py`. The Lua mirrors no effect, value or text of these
layers: `check_service_mirror` covers keys and kinds only. Rank, leader, hall and seat effects are
DB rows on keys that already exist per tag.

- **Per-race lookups.** `RANK_EFFECTS`, `RANK_VALUES_OF`, `LEAD_VALUE_OF`, `EFFECT_BLURB`,
  `EFFECT_GOOD_SIGN`, `EFFECT_REACH_THEIRS`, `HALL_EFFECT` and `HALL_BONUS` gain optional
  `(guild, tag)` keys. One helper resolves them, `(guild, tag)` first and then `guild`. Every read
  site goes through it. Grep each table name for the read sites; none may still index by guild alone.
- **The seat.** A new `HALL_SEAT = {(guild, tag): (effect, scope, value, blurb)}` table, with
  `HALL_SEAT_SCOPE` / `seat_value` as the fallback.
- **Signs.** `EFFECT_GOOD_SIGN` and the seat sign check must read per tag, because the Empire's
  seat is negative-good.
- **Loc.** Rank, hall and seat descriptions are generated from the same tables. Hidden effects get
  their sentence from `HALL_BONUS` / `HALL_SEAT` text.
- **Saves.** Existing saves need nothing: bundle and building keys are unchanged, only their effect
  rows.

## 6. Tests

- **`--selftest`:** per tag, assert the emitted rank, leader, hall and seat junction rows and the
  three service bundles match §3-§4. Delete one override and watch the assert fail.
- **`--check`:** passes with zero PROBLEM lines. It holds every pair to vanilla, every value to its
  ceiling, and signs to `is_positive_value_good`.
- **Other checks:** `check_effect_signs.py` (review list), `check_effect_bundle_loc.py`, the guilds
  harness, and `import_great_guilds.py --check`.
- **Previews:** `preview_guilds_panel.py` for the Temple tab at `--flavour emp`, `dwf` and `skv`.
- **Pack:** packed and verified, then deployed to the Workshop folder only, with a backup. A
  Workshop pack never goes in `data/`.
- **Owed in game:** the Temple tab, one hall card and the seat bundle for one race.

## 7. Out of scope

- Separate religion guilds (Sigmar, Morr, Ulric), which the author dropped.
- The Engineers' Winds overlap for Cathay, Skaven and Chaos Dwarfs.
- Changing any service's name, kind, cost or cooldown.

## 8. Open risks

- `conclave_influence_gain_temples` only matters to Chaos Dwarf factions that have the Conclave
  resource. Verify which ones do before shipping; if any lack it, that hall bonus does nothing.
- Ward save +8% on every army at rank 5 is the strongest permanent number here. It was approved as
  is, and it stacks with Bretonnia's Blessing of the Lady.
