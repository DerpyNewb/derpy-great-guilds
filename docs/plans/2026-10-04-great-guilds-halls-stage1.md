# Great Guilds Halls, Stage 1 (Chaos Dwarfs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chaos Dwarf factions can build guild halls. There are six chains (one per guild)
in one superchain, three levels each, rank-locked. Halls pay reputation, give a local bonus,
cut that guild's service prices, and train one existing unit. The guild's leader gets a Seat
bundle while holding a level-2 hall.

**Architecture:** `tools/gen_great_guilds.py` gains a `HALLS` block and `hall_tables()`. These
emit every building row (cloned from CA's K'daai chain), the units, the AI values, the Seat
bundles and the loc into the existing TSV pipeline. `zzz_derpy_guilds.lua` gains a HALLS block:

- per-faction locks through CA's restriction calls;
- a turn-start count through `region:building_exists`;
- reputation through `GG.capped_grant`;
- a discount term in `GG.service_cost`;
- the Seat bundle.

Stage 2, the other seven races as data, gets its own plan after §10's in-game checks.

**Tech Stack:** Python 3 (generator and checks), Lua 5.1.5 (model and harness), RPFM MCP
(packing).

**Spec:** `docs/superpowers/specs/2026-10-04-great-guilds-halls-design.md`. Read it first.
Section numbers below (§N) are the spec's.

## Global Constraints

- All keys lowercase (the 6.1 rule). Keys: superchain `derpy_gg_hall`, chain
  `derpy_gg_hall_<guild>`, level `derpy_gg_hall_<guild>_<n>` (n = 0, 1, 2), Seat bundle
  `derpy_gg_seat_<guild>`. The Chaos Dwarf tag is the empty string.
- **Table versions are CA's live ones**, read from `db.pack` on 2026-10-04:

  | Table | Version |
  |---|---|
  | `building_superchains` | 0 |
  | `building_chains` | 10 |
  | `building_levels` | **3** (`Modding Files/templates/README.md` says 2 and is stale) |
  | `building_upgrades_junction` | 0 |
  | `building_culture_variants` | 5 |
  | `building_chain_set_items` | 0 |
  | `building_set_to_building_junctions` | 0 |
  | `building_chain_availability_sets` | 0 |
  | `building_instances` | 0 |
  | `building_units_allowed` | 4 |
  | `cai_construction_system_building_values` | 0 |
  | `building_effects_junction` | 0 |
  | `effect_bundles` | 4 |
  | `effect_bundles_to_effects_junctions` | 3 |

- **Loc-only text, no DB table for it:**
  - Building names: `building_culture_variants_name_<level>`.
  - Descriptions: `building_short_description_texts_short_description_<level>`, with the
    variant row's `short_description` cell = `<level>` and `description` =
    `wh_main_PLACEHOLDER`, as CA's K'daai rows have.
  - Lock tooltips: `campaign_localised_strings_string_<key>` (CA's Skarsnik lock precedent;
    `campaign_localised_strings_tables` has no rows in `db.pack`).
  - Chain name: `building_chains_chain_tooltip_<chain>`.
- Rank indices: Unmarked 1, Indebted 2, Sworn 3, Favoured 4, Exalted 5 (`GG.RANKS` is 1-based).
  Level 0 needs 2, level 1 needs 4, and level 2 needs 5 plus the lead.
- Numbers (§5):

  | | Level 0 | Level 1 | Level 2 |
  |---|---|---|---|
  | Cost / turns | 1500 / 3 | 3000 / 5 | 6000 / 8 |
  | Settlement level | 2 | 3 | 4 |
  | `faction_unique` | false | true | true |
  | Reputation per turn | 4 | 8 | 15 |
  | Unit `XP` | 0 | 1 | 2 |

  Discount: `hall_off` 3% per hall, `HALL_OFF_MAX` 15. MCT `hall_rep` default 100,
  `guild_halls` default on.
- **Player text**: plain words (Reputation, never "standing"), no emoji, guild names keep
  their article.
- **The game's Lua**:
  - Never pass `init` or `plain` to `string.find`.
  - No number literal on the LEFT of an arithmetic operator in a big function
    (`py tools\check_lua_literal_left.py`).
  - Integer multiply then divide; never `* 1.5`.
- `zzz_derpy_guilds_ui.lua`, `_guilds_harness.lua`, `gen_guilds_ui.py` and
  `preview_guilds_panel.py` are CRLF. Edit them with the Edit tool or bytes-mode Python;
  never `sed -i` (memory `git-bash-sed-strips-crlf`). Patch scripts go through the Write
  tool, never a heredoc (memory `bash-heredoc-eats-backslashes`).
- The workspace is not a git repo. "Checkpoint" steps run the gates instead of committing.
  The public repo is synced only when the author asks.
- **Never pass `--help` to a `tools/*.py`.** Several build on any unknown flag. Read the
  docstring.

## Review Focus

1. **A save from before halls.** No `guild_halls` in `derpy_gg_tuned`, no lock records, a
   faction already at Exalted. Expect: the first tick sweeps every level once, and an Exalted
   leader can raise a Seat at once. Pinned in Task 3.
2. **The Seat's settlement captured mid-turn by another faction.** Expect: the Seat bundle
   leaves the old owner at its next turn start, and no faction wears it without both the lead
   and the building. Pinned in Task 5.
3. **Leadership changing hands to and from an AI faction.** Expect: the loser's level-2 lock
   shuts and the winner's opens in the same sweep, and nobody else's records are touched.
   Pinned in Task 3.
4. **A hall level the faction may not build arriving anyway**, for example by script from
   another mod or a confederation inheriting halls. Expect: it still counts and pays; locks
   only stop construction. Pinned in Task 4.
5. **`guild_halls` off after halls exist.** Expect: every level locked, no reputation, no
   discount, no Seat bundle, and buildings left standing. Pinned in Tasks 3-5.

---

### Task 1: Generator - hall data and the building rows

**Files:**
- Modify: `tools/gen_great_guilds.py`:
  - a new `HALLS` block after `MINTED_EFFECTS`/`minted_tables()` (around line 1878);
  - `build()` (line 3032);
  - `TSV_META` (line 5247);
  - `selftest()` (line 5323).

**Interfaces:**
- Produces:
  - `HALL_TAGS: list[str]`, `HALL_RANK = [2, 4, 5]`, `HALL_REP = [4, 8, 15]`,
    `HALL_OFF_MAX = 15`;
  - `hall_key(guild, n, tag="") -> str`, `hall_chain(guild, tag="") -> str`,
    `hall_superchain(tag="") -> str`, `seat_key(guild, tag="") -> str`;
  - `hall_tables() -> dict[str, list[dict]]`.
  - All cell values are strings, as every other generator row is.

- [ ] **Step 1: Write the failing selftest assertions**

Append to `selftest()`:

```python
    # GUILD HALLS (spec 2026-10-04-great-guilds-halls-design.md)
    ht = hall_tables()
    assert [r["key"] for r in ht["building_superchains"]] == ["derpy_gg_hall"]
    assert sorted(r["key"] for r in ht["building_chains"]) == \
        sorted("derpy_gg_hall_" + g for g in GUILDS)
    levels = sorted(r["level_name"] for r in ht["building_levels"])
    assert levels == sorted("derpy_gg_hall_%s_%d" % (g, n) for g in GUILDS for n in range(3))
    assert all(r["building_superchain"] == "derpy_gg_hall" for r in ht["building_chains"])
    by_lv = {r["level_name"]: r for r in ht["building_levels"]}
    assert by_lv["derpy_gg_hall_brass_0"]["faction_unique"] == "false"
    assert by_lv["derpy_gg_hall_brass_1"]["faction_unique"] == "true"
    assert by_lv["derpy_gg_hall_brass_2"]["primary_slot_building_building_level_requirement"] == "4"
    assert by_lv["derpy_gg_hall_brass_2"]["create_cost"] == "6000"
    edges = {(r["from"], r["to"]) for r in ht["building_upgrades_junction"]}
    assert ("derpy_gg_hall_slavers_0", "derpy_gg_hall_slavers_1") in edges and len(edges) == 12
    inst = {r["key"]: r["num_instances"] for r in ht["building_instances"]}
    assert inst["derpy_gg_hall"] == "1", "one guild per settlement rides on this row"
    assert len(ht["building_chain_set_items"]) == 12
    assert {r["id"] for r in ht["building_chain_availability_sets"]} == {"wh3_dl23_bas_chd"}
    assert all(k.islower() for t in ht.values() for r in t for k in
               (r.get("key", ""), r.get("level_name", ""), r.get("building", "")))
```

- [ ] **Step 2: Run it and watch it fail**

Run: `py tools\gen_great_guilds.py --selftest`
Expected: FAIL with `NameError: name 'hall_tables' is not defined`.

- [ ] **Step 3: Write the data and `hall_tables()` (building rows only)**

Insert after `minted_tables()`:

```python
# ------------------------------------------------------------------ GUILD HALLS --
# Spec: docs/superpowers/specs/2026-10-04-great-guilds-halls-design.md. Mirrored by the
# GG.HALL_* block in zzz_derpy_guilds.lua; check_hall_mirror() compares the two.
HALL_TAGS = [""]                 # races with halls. Stage 2 appends the other seven.
HALL_RANK = [2, 4, 5]            # rank needed for level 0, 1, 2 (level 2 also needs the lead)
HALL_REP = [4, 8, 15]            # reputation per turn, per hall, by level
HALL_OFF_MAX = 15                # most % a guild's halls take off its services
HALL_COST = [(1500, 3), (3000, 5), (6000, 8)]     # create_cost, create_time
HALL_SETTLEMENT = [2, 3, 4]      # primary_slot_building_building_level_requirement
HALL_XP = [0, 1, 2]              # building_units_allowed.XP, by level
# The local bonus: one effect per guild ROLE, the same for every race (spec §8.1). Every
# pair is one CA puts on a Chaos Dwarf building; check_halls() holds the values to 1.5x
# vanilla's largest magnitude on that pair.
HALL_EFFECT = {
    "brass":        ("wh_main_effect_economy_gdp_mod_all", "province_to_region_own",
                     [5, 10, 15]),
    "immortals":    ("wh_main_effect_force_all_campaign_replenishment_rate",
                     "province_to_force_own_provincewide", [5, 10, 15]),
    "daemonsmiths": ("wh_main_effect_technology_research_rate_mod", "building_to_faction_own",
                     [2, 4, 6]),
    "khanate":      ("wh_main_effect_agent_recruitment_xp_all_agents",
                     "building_to_province_own", [1, 2, 3]),
    "overseers":    ("wh_main_effect_building_construction_cost_mod", "province_to_region_own",
                     [-5, -10, -15]),
    "slavers":      ("wh_main_effect_force_all_campaign_post_battle_loot_mod",
                     "building_to_character_own_in_adjacent_regions", [10, 20, 30]),
}
# Per race: the availability set, the donor chain whose rows the placement and level rows
# are cloned from, the three level nouns, and one existing unit per guild (spec §8.2).
HALL_RACES = {
    "": {"set": "wh3_dl23_bas_chd", "donor": "wh3_dlc23_chd_military_kdaai",
         "culture": "wh3_dlc23_chd_chaos_dwarfs",
         "nouns": ("Lodge", "Hall", "Ziggurat"),
         "units": {"brass": "wh3_dlc23_chd_cav_hobgoblin_wolf_raiders_bows",
                   "immortals": "wh3_dlc23_chd_inf_infernal_guard",
                   "daemonsmiths": "wh3_dlc23_chd_mon_kdaai_fireborn",
                   "khanate": "wh3_dlc23_chd_inf_hobgoblin_sneaky_gits",
                   "overseers": "wh3_dlc23_chd_inf_chaos_dwarf_warriors",
                   "slavers": "wh3_dlc23_chd_inf_hobgoblin_cutthroats"}},
}
# A DLC unit's base-game stand-in (spec §8.2). Both go on the hall level; the engine's own
# ownership gating hides the DLC one from a non-owner. Used from stage 2; listed whole now so
# check_halls() can hold every pick to the rule.
HALL_FALLBACK = {
    "wh2_dlc13_emp_inf_huntsmen_0": "wh_main_emp_inf_crossbowmen",
    "wh_dlc04_emp_inf_free_company_militia_0": "wh_main_emp_inf_swordsmen",
    "wh_dlc06_dwf_inf_rangers_0": "wh_main_dwf_inf_quarrellers_0",
    "wh3_dlc24_cth_inf_onyx_crowmen": "wh3_main_cth_inf_crane_gunners_0",
    "wh3_dlc24_ksl_inf_akshina_ambushers": "wh3_main_ksl_cav_horse_archers_0",
    "wh2_dlc10_def_cav_doomfire_warlocks_0": "wh2_main_def_art_reaper_bolt_thrower",
    "wh2_dlc10_hef_inf_shadow_warriors_0": "wh2_main_hef_inf_archers_0",
}


def hall_superchain(tag=""):
    return "derpy_gg_hall" + tag


def hall_chain(guild, tag=""):
    return "derpy_gg_hall_%s%s" % (guild, tag)


def hall_key(guild, n, tag=""):
    return "derpy_gg_hall_%s_%d%s" % (guild, n, tag)


def seat_key(guild, tag=""):
    return "derpy_gg_seat_%s%s" % (guild, tag)


def _s(v):
    """A DB cell as the TSV writer wants it."""
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def _donor(table, field, value):
    rows = [r for r in live_rows(table) if r[field] == value]
    if not rows:
        raise RuntimeError("no %s row with %s = %s to clone" % (table, field, value))
    return rows


def hall_tables():
    """Every building row the halls ship, cloned from each race's donor chain."""
    t = {k: [] for k in ("building_superchains", "building_chains", "building_levels",
                         "building_upgrades_junction", "building_culture_variants",
                         "building_chain_set_items", "building_set_to_building_junctions",
                         "building_chain_availability_sets", "building_instances")}
    for tag in HALL_TAGS:
        R = HALL_RACES[tag]
        d_chain = _donor("building_chains", "key", R["donor"])[0]
        d_level = sorted(_donor("building_levels", "chain", R["donor"]),
                         key=lambda r: r["level"])[0]
        d_var = _donor("building_culture_variants", "building", d_level["level_name"])[0]
        d_sets = _donor("building_chain_set_items", "chain", R["donor"])
        d_panel = _donor("building_set_to_building_junctions", "building_chain", R["donor"])[0]
        sc = hall_superchain(tag)
        t["building_superchains"].append({"key": sc})
        t["building_instances"].append({"key": sc, "num_instances": "1"})
        for g in GUILDS:
            ch = hall_chain(g, tag)
            t["building_chains"].append({k: _s(v) for k, v in dict(
                d_chain, key=ch, building_superchain=sc).items()})
            t["building_instances"].append({"key": ch, "num_instances": "1"})
            t["building_chain_availability_sets"].append(
                {"building_chain": ch, "id": R["set"]})
            t["building_set_to_building_junctions"].append({k: _s(v) for k, v in dict(
                d_panel, building_chain=ch, building_level="").items()})
            for s in ("wh3_main_secondary_core_generic_minor",
                      "wh3_main_secondary_core_generic_major"):
                base = next((r for r in d_sets if r["set"] == s), d_sets[0])
                t["building_chain_set_items"].append({k: _s(v) for k, v in dict(
                    base, chain=ch, set=s, remove=False).items()})
            for n in range(3):
                lv = hall_key(g, n, tag)
                cost, turns = HALL_COST[n]
                t["building_levels"].append({k: _s(v) for k, v in dict(
                    d_level, level_name=lv, chain=ch, level=n, create_cost=cost,
                    create_time=turns, upkeep_cost=0, faction_unique=(n > 0),
                    only_in_capital=False, first_in_world_bundle="",
                    primary_slot_building_building_level_requirement=HALL_SETTLEMENT[n],
                    building_instance_key="", resource_cost="",
                    resource_transaction_on_complete="").items()})
                t["building_culture_variants"].append({k: _s(v) for k, v in dict(
                    d_var, building=lv, icon=d_var["icon"], short_description=lv).items()})
                if n:
                    t["building_upgrades_junction"].append(
                        {"from": hall_key(g, n - 1, tag), "to": lv})
    return t
```

Wire it into `build()`, before `return out`:

```python
    for table, rows in hall_tables().items():
        out.setdefault(table, []).extend(rows)
```

Add to `TSV_META`, with the versions from Global Constraints:

```python
    # GUILD HALLS (2026-10-04). Versions read from CA's db.pack with read_vanilla_db.
    "building_superchains": ("building_superchains_tables", 0),
    "building_chains": ("building_chains_tables", 10),
    "building_levels": ("building_levels_tables", 3),
    "building_upgrades_junction": ("building_upgrades_junction_tables", 0),
    "building_culture_variants": ("building_culture_variants_tables", 5),
    "building_chain_set_items": ("building_chain_set_items_tables", 0),
    "building_set_to_building_junctions": ("building_set_to_building_junctions_tables", 0),
    "building_chain_availability_sets": ("building_chain_availability_sets_tables", 0),
    "building_instances": ("building_instances_tables", 0),
```

The icon stays the donor's for now (`chd_military_kdaai`). Task 6 swaps in one per guild.

- [ ] **Step 4: Run the selftest and watch it pass**

Run: `py tools\gen_great_guilds.py --selftest`
Expected: the new assertions pass. If a donor field name differs from the ones overridden
above (`only_in_capital`, `building_instance_key`, and so on), the `dict(...)` call raises
`KeyError`-free but leaves the donor's value. Print one row and compare it with the
`building_levels` column list in the spec's §3.1 before moving on.

- [ ] **Step 5: Make `check_table_versions()` read versions offline**

`check_table_versions()` (line 3158) reads `.skilltree_cache`, which has none of the new
tables. Change its inner loop so a missing cache falls back to the live `db.pack`:

```python
            if R.have(table):
                ca = R.version(table)
            else:
                from read_vanilla_db import load, DB_PACK
                vers = {v for _p, v, _rows in load(DB_PACK, name)}
                if len(vers) != 1:
                    out.append("cannot read one live version of %s (got %r)" % (name, vers))
                    continue
                ca = vers.pop()
```

Then confirm it bites: temporarily set `building_levels` to version 2 in `TSV_META` and run
`py tools\gen_great_guilds.py --check`. Expected: "building_levels_tables is declared at
version 2 but CA's own file declares 3". Restore 3.

- [ ] **Step 6: Checkpoint**

Run: `py tools\gen_great_guilds.py --check`
Expected: no findings from the version check. Other new findings are Task 2's to fix.

---

### Task 2: Generator - effects, units, AI, Seat bundles, loc, and `check_halls()`

**Files:**
- Modify: `tools/gen_great_guilds.py`:
  - `hall_tables()` from Task 1;
  - `TSV_META`;
  - a new `check_halls()`, called from `check()` (line 5009);
  - `selftest()`.

**Interfaces:**
- Consumes: `hall_tables()`, `HALL_*`, `seat_key`, `RANK_EFFECTS`, `RANK_VALUES`,
  `short_name(guild, tag)`, `GUILD_NAMES`/`FLAVOURS`, `live_rows`.
- Produces:
  - `hall_tables()` also returns `building_effects_junction`, `building_units_allowed`,
    `cai_construction_system_building_values`, `effect_bundles`,
    `effect_bundles_to_effects_junctions` and `loc`;
  - `check_halls() -> list[str]`;
  - `hall_name(guild, n, tag) -> str`.

- [ ] **Step 1: Write the failing selftest assertions**

```python
    ht = hall_tables()
    bej = {(r["building"], r["effect"]): r for r in ht["building_effects_junction"]}
    assert ("derpy_gg_hall_brass_2", "derpy_gg_built_brass") in bej, "card line"
    assert bej[("derpy_gg_hall_overseers_2",
                "wh_main_effect_building_construction_cost_mod")]["value"] == "-15"
    units = {(r["building"], r["unit"]): r["XP"] for r in ht["building_units_allowed"]}
    assert units[("derpy_gg_hall_immortals_1", "wh3_dlc23_chd_inf_infernal_guard")] == "1"
    assert len({r["building_chain"] for r in
                ht["cai_construction_system_building_values"]}) == 6
    assert sorted(r["key"] for r in ht["effect_bundles"]) == sorted(seat_key(g) for g in GUILDS)
    loc = {r["key"]: r["text"] for r in ht["loc"]}
    assert loc["building_culture_variants_name_derpy_gg_hall_brass_0"] == \
        "Lodge of the Brass Tablets"
    assert "campaign_localised_strings_string_derpy_gg_hall_tip_lead_brass" in loc
    # check_halls bites: a placement table emptied, a unit off the roster, a value too big
    for breakage in ("placement", "unit", "value"):
        assert check_halls(_break=breakage), "check_halls missed " + breakage
    assert check_halls() == [], check_halls()
```

- [ ] **Step 2: Run it and watch it fail**

Run: `py tools\gen_great_guilds.py --selftest`
Expected: FAIL with `KeyError: 'building_effects_junction'`.

- [ ] **Step 3: Extend `hall_tables()`**

Add these keys to the `t = {...}` initialiser: `"building_effects_junction"`,
`"building_units_allowed"`, `"cai_construction_system_building_values"`, `"effect_bundles"`,
`"effect_bundles_to_effects_junctions"`, `"loc"`. Inside the per-guild loop:

```python
            eff, scope, vals = HALL_EFFECT[g]
            unit = R["units"][g]
            first = _unit_level(unit, R["set"])        # first hall level the unit may come at
            d_cai = _cai_donor(R, g)
            t["cai_construction_system_building_values"].append({k: _s(v) for k, v in dict(
                d_cai, building_chain=ch, building_instance="",
                building_or_building_range_start_inclusive="",
                building_range_end_inclusive="", building_super_chain="",
                per_faction_building_limit_start=3, per_faction_building_limit_end=3).items()})
            t["loc"].append({"key": "building_chains_chain_tooltip_" + ch,
                             "text": "Halls of %s" % _with_article(g, tag),
                             "tooltip": "false"})
            for n in range(3):
                lv = hall_key(g, n, tag)
                for e, sc_, v in ((eff, scope, vals[n]),
                                  (BUILT_EFFECT % (g, tag), BUILT_SCOPE, 1)):
                    t["building_effects_junction"].append({
                        "building": lv, "effect": e, "effect_scope": sc_,
                        "value": _s(v), "value_damaged": _s(v), "value_ruined": "0",
                        "context_requirement": ""})
                if n >= first:
                    for u in [unit] + ([HALL_FALLBACK[unit]] if unit in HALL_FALLBACK else []):
                        t["building_units_allowed"].append(_unit_row(lv, u, HALL_XP[n]))
                t["loc"].append({"key": "building_culture_variants_name_" + lv,
                                 "text": hall_name(g, n, tag), "tooltip": "false"})
                t["loc"].append({"key": "building_short_description_texts_short_description_"
                                 + lv, "text": hall_desc(g, n, tag), "tooltip": "false"})
            for n, why in ((0, "0"), (1, "1"), (2, "lead")):
                t["loc"].append({"key": "campaign_localised_strings_string_derpy_gg_hall_tip_%s_%s%s"
                                 % (why, g, tag), "text": hall_tip(g, n, tag),
                                 "tooltip": "false"})
            # THE SEAT BUNDLE (spec §4.5): the guild's own rank effect, faction-scoped and
            # already held to vanilla's range by check(), at a third of rank 5's value.
            sk = seat_key(g, tag)
            t["effect_bundles"].append(_seat_bundle_row(sk))
            r_eff, r_scope = RANK_EFFECTS[g][0], RANK_EFFECTS[g][1]
            t["effect_bundles_to_effects_junctions"].append(_bundle_junction_row(
                sk, r_eff, r_scope, RANK_VALUES[5] // 3))
            t["loc"].append({"key": "effect_bundles_localised_title_" + sk,
                             "text": "Seat of %s" % _with_article(g, tag), "tooltip": "false"})
            t["loc"].append({"key": "effect_bundles_localised_description_" + sk,
                             "text": "You lead %s and hold its seat." % _with_article(g, tag),
                             "tooltip": "false"})
```

Add the helpers above `hall_tables()`:

```python
def hall_name(guild, n, tag=""):
    """'Lodge of the Brass Tablets': the noun, then the guild with its article."""
    return "%s of %s" % (HALL_RACES[tag]["nouns"][n], _with_article(guild, tag))


def hall_desc(guild, n, tag=""):
    return ("Pays %s Reputation each turn and lowers the price of its services."
            % _with_article(guild, tag))


def hall_tip(guild, n, tag=""):
    if n == 2:
        return "[[col:red]]Only the leader of %s may raise it.[[/col]]" % _with_article(guild, tag)
    return "[[col:red]]Needs %s with %s.[[/col]]" % (RANK_NAMES[HALL_RANK[n] - 1],
                                                     _with_article(guild, tag))


def _with_article(guild, tag):
    """The guild's display name as players read it, article included ('the Brass Tablets')."""
    name = FLAVOURS[tag]["guilds"][guild]          # "The Brass Tablets"
    return "the " + name[4:] if name.startswith("The ") else name


def _seat_bundle_row(key):
    """A Seat bundle row in the exact column set of the rank bundles _build_one makes."""
    proto = _build_one("")["effect_bundles"][0]
    return dict(proto, key=key)


def _bundle_junction_row(bundle, effect, scope, value):
    """A bundle-to-effect row in the exact column set _build_one uses."""
    row = dict(_build_one("")["effect_bundles_to_effects_junctions"][0])
    for k in row:
        if k.endswith("bundle_key"):
            row[k] = bundle
        elif k == "effect_key":
            row[k] = effect
        elif k == "effect_scope":
            row[k] = scope
        elif k == "value":
            row[k] = _s(value)
    return row


def _unit_level(unit, avail_set):
    """First hall level (0-2) whose settlement requirement covers the vanilla building that
    unlocks `unit` for this race - a hall never gives a unit earlier than vanilla does."""
    chains = {r["building_chain"] for r in live_rows("building_chain_availability_sets")
              if r["id"] == avail_set}
    lv = {r["level_name"]: r for r in live_rows("building_levels")}
    need = min(int(lv[r["building"]]["primary_slot_building_building_level_requirement"] or 0)
               for r in live_rows("building_units_allowed")
               if r["unit"] == unit and r["building"] in lv
               and lv[r["building"]]["chain"] in chains)
    return next(n for n in range(3) if HALL_SETTLEMENT[n] >= need)


def _unit_row(level, unit, xp):
    d = live_rows("building_units_allowed")[0]
    return {k: _s(v) for k, v in dict(d, building=level, unit=unit, XP=xp, faction="",
                                      enabled=False, conditions="",
                                      key="derpy_gg_%s_%s" % (level, unit)).items()}


def _cai_donor(R, guild):
    """CA's building_values row for the donor chain, cloned per hall (spec §6)."""
    rows = [r for r in live_rows("cai_construction_system_building_values")
            if r["building_chain"] == R["donor"]]
    if not rows:
        raise RuntimeError("no building_values row for donor " + R["donor"])
    return rows[0]
```

**The `key` column of `building_units_allowed`.** Read CA's own rows before trusting the format
above:

```
py -c "import sys; sys.path.insert(0,'tools'); from read_vanilla_db import load, DB_PACK; print([r for p,v,rs in load(DB_PACK,'building_units_allowed_tables') for r in rs][:3])"
```

Mirror CA's shape. If `key` is numeric, use a stable hash of `level|unit`.

`_seat_bundle_row` and `_bundle_junction_row` (above) clone the first rank-bundle row
`_build_one("")` makes, so the column set cannot drift from the bundles that already load.
Before trusting them, print one of each and compare it with a rank bundle's row: the title
and description columns must be empty or `PH`, as the rank bundles' are. Every panel reads
the `effect_bundles_localised_*` loc, never the row, and `py tools\check_effect_bundle_loc.py`
must pass on the built pack.

Add `TSV_META` entries:

```python
    "building_units_allowed": ("building_units_allowed_tables", 4),
    "cai_construction_system_building_values":
        ("cai_construction_system_building_values_tables", 0),
```

(`building_effects_junction`, `effect_bundles` and `effect_bundles_to_effects_junctions`
already exist.)

- [ ] **Step 4: Write `check_halls()`**

```python
def check_halls(_break=None):
    """What a hall needs to appear, unlock and be honest - each fails silently in game."""
    out = []
    ht = hall_tables()
    if _break == "placement":
        ht["building_chain_availability_sets"] = []
    if _break == "unit":
        ht["building_units_allowed"][0]["unit"] = "wh_main_emp_inf_greatswords"
    if _break == "value":
        for r in ht["building_effects_junction"]:
            if r["effect"] == HALL_EFFECT["khanate"][0]:
                r["value"] = "9"
    chains = [r["key"] for r in ht["building_chains"]]
    for table, col in (("building_chain_set_items", "chain"),
                       ("building_set_to_building_junctions", "building_chain"),
                       ("building_chain_availability_sets", "building_chain"),
                       ("building_instances", "key"),
                       ("cai_construction_system_building_values", "building_chain")):
        have = {r[col] for r in ht[table]}
        for c in chains:
            if c not in have:
                out.append("%s has no %s row - the chain never appears, or the AI never "
                           "builds it" % (c, table))
    for tag in HALL_TAGS:
        if not any(r["key"] == hall_superchain(tag) and r["num_instances"] == "1"
                   for r in ht["building_instances"]):
            out.append("superchain %s is not capped at 1 - two guilds could share a "
                       "settlement" % hall_superchain(tag))
    # Units: on that race's vanilla roster (fallbacks included), never a DLC unit alone.
    for tag in HALL_TAGS:
        R = HALL_RACES[tag]
        chains_r = {r["building_chain"] for r in live_rows("building_chain_availability_sets")
                    if r["id"] == R["set"]}
        lv_chain = {r["level_name"]: r["chain"] for r in live_rows("building_levels")}
        roster = {r["unit"] for r in live_rows("building_units_allowed")
                  if lv_chain.get(r["building"]) in chains_r}
        for r in ht["building_units_allowed"]:
            if r["building"].endswith(tag) and r["unit"] not in roster:
                out.append("%s unlocks %s, which no %s building does in vanilla"
                           % (r["building"], r["unit"], R["culture"]))
    # Effect values: within 1.5x of vanilla's largest magnitude on the same effect and scope.
    biggest = {}
    for r in live_rows("building_effects_junction"):
        k = (r["effect"], r["effect_scope"])
        biggest[k] = max(biggest.get(k, 0), abs(float(r["value"])))
    for r in ht["building_effects_junction"]:
        k = (r["effect"], r["effect_scope"])
        if r["effect"].startswith("derpy_gg_built_"):
            continue
        if k not in biggest:
            out.append("%s pairs %s with %s, which vanilla never does" % ((r["building"],) + k))
        elif abs(float(r["value"])) > biggest[k] * VALUE_RANGE_TOLERANCE:
            out.append("%s puts %s on %s, over 1.5x vanilla's largest (%s)"
                       % (r["building"], r["value"], k[0], biggest[k]))
    return out
```

Call it from `check()` next to `check_built_effects()`: `out += check_halls()`.

- [ ] **Step 5: Run the selftest and the check**

Run: `py tools\gen_great_guilds.py --selftest`, then `py tools\gen_great_guilds.py --check`.
Expected: selftest passes.

If `--check` reports a value over 1.5x (spec §8.1 flags the Brass Tablets' +15 and the
Khanate's 3), lower that value in `HALL_EFFECT` to the largest the check accepts. Do not
loosen the check. Record the value you settled on in the spec's §8.1 table.

`check_live_references` must also pass. It resolves the hall rows' own references (chain to
superchain, level to chain) against this pack's own rows, and the units, sets and effects
against `db.pack`.

- [ ] **Step 6: Write the TSVs and checkpoint**

Run: `py tools\gen_great_guilds.py --write`
Expected: new `Modding Files/source/great_guilds/<table>.tsv` files for the eleven new tables.
`effect_bundles` grows by 6 (690 to 696), and `building_effects_junction` by 36 (1,726 to
1,762).

---

### Task 3: Lua - hall keys, locks, and the sweep

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`:
  - a new HALLS block after `GG.service_cost` (around line 4130);
  - `GG.apply_rank` (line 100);
  - `GG.reassert_leaders` (line 1280);
  - the first-tick callback (line 5809);
  - `GG.TUNE_DEFAULTS` (line 4354).
- Test: `tools/_guilds_harness.lua`, a new IIFE block just before `print("harness ok")`.

**Interfaces:**
- Consumes: `GG.covered(f)`, `GG.tag(f)`, `GG.get(f, g)`, `GG.rank_of(rep)`,
  `GG.leader_of(g, culture)`, `GG.culture_of(f)`, `GG.setting(k)`, `GG.GUILDS`, `GG.state`.
- Produces:
  - `GG.HALL_TAGS`, `GG.HALL_RANK`, `GG.HALL_REP`, `GG.HALL_OFF_MAX`;
  - `GG.hall_key(guild, n, tag)` and `GG.hall_tip_key(guild, n, tag)`;
  - `GG.hall_open(faction, guild, n) -> bool`;
  - `GG.lock_halls(faction, guild)`;
  - `GG.halls_locked[faction][level_key] = bool`.

- [ ] **Step 1: Write the failing harness block**

```lua
-- GUILD HALLS: LOCKS (spec 2026-10-04 §4.1). One record per level whose answer changed.
;(function()
    local adds, rems = {}, {}
    cm.add_event_restricted_building_record_for_faction = function(_, b, f, tip)
        adds[#adds + 1] = {b, f, tip}
    end
    cm.remove_event_restricted_building_record_for_faction = function(_, b, f)
        rems[#rems + 1] = {b, f}
    end
    local F = THE_PLAYER
    GG.halls_locked[F] = nil
    GG.state[F] = nil; GG.load(F)
    GG.state[F].brass.rep = 0
    GG.lock_halls(F, "brass")
    assert(#adds == 3 and #rems == 0, "an Unmarked faction has all three levels shut")
    assert(adds[1][3] == "derpy_gg_hall_tip_0_brass", "with the level-0 tooltip key")
    adds, rems = {}, {}
    GG.lock_halls(F, "brass")
    assert(#adds == 0 and #rems == 0, "a second sweep with no change writes nothing")
    GG.state[F].brass.rep = 700                       -- Favoured
    GG.lock_halls(F, "brass")
    assert(#rems == 2, "Favoured opens levels 0 and 1, got " .. #rems)
    local prev = GG.leader_of
    GG.leader_of = function(g) return g == "brass" and F or nil end
    GG.state[F].brass.rep = 1500
    adds, rems = {}, {}
    GG.lock_halls(F, "brass")
    assert(#rems == 1 and rems[1][1] == "derpy_gg_hall_brass_2", "Exalted and leading opens 2")
    GG.leader_of = function() return "someone_else" end
    adds, rems = {}, {}
    GG.lock_halls(F, "brass")
    assert(#adds == 1 and adds[1][3] == "derpy_gg_hall_tip_lead_brass",
           "losing the lead shuts level 2 with the leader tooltip")
    GG.leader_of = prev
    -- guild_halls off shuts everything (Review Focus 5)
    local prev_s = GG.setting
    GG.setting = function(k) if k == "guild_halls" then return false end return prev_s(k) end
    adds = {}
    GG.lock_halls(F, "brass")
    assert(#adds == 2, "switch off shuts the two levels still open, got " .. #adds)
    GG.setting = prev_s
    -- A race without halls is never touched
    adds, rems = {}, {}
    local prev_t = GG.tag
    GG.tag = function() return "_emp" end
    GG.lock_halls(F, "immortals")
    assert(#adds == 0 and #rems == 0, "no records for a race with no halls")
    GG.tag = prev_t
end)()
```

- [ ] **Step 2: Run it and watch it fail**

Run: `& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua`
Expected: FAIL with `attempt to index field 'halls_locked' (a nil value)`.

- [ ] **Step 3: Implement the block**

```lua
-- ------------------------------------------------------------------ guild halls --
-- Spec: docs/superpowers/specs/2026-10-04-great-guilds-halls-design.md. Mirrored by HALL_*
-- in tools/gen_great_guilds.py (check_hall_mirror). Six chains per race share one
-- superchain capped at one instance, so a settlement holds one guild's hall - that is the
-- DB's job. This block decides who may BUILD which level, counts what stands, and pays.
GG.HALL_TAGS = {[""] = true}          -- races with halls; stage 2 adds the other seven
GG.HALL_RANK = {2, 4, 5}              -- rank for level 0, 1, 2; level 2 also needs the lead
GG.HALL_REP = {4, 8, 15}              -- reputation per hall per turn, by level
GG.HALL_OFF_MAX = 15                  -- most % a guild's halls take off its services

function GG.hall_key(guild, n, tag) return "derpy_gg_hall_" .. guild .. "_" .. n .. (tag or "") end

function GG.hall_tip_key(guild, n, tag)
    return "derpy_gg_hall_tip_" .. (n == 2 and "lead" or tostring(n)) .. "_" .. guild .. (tag or "")
end

function GG.halls_here(faction)
    return GG.covered(faction) and GG.HALL_TAGS[GG.tag(faction)] == true
end

function GG.hall_open(faction, guild, n)
    if GG.setting("guild_halls") == false then return false end
    local rank = GG.rank_of((GG.get(faction, guild)))
    if rank < GG.HALL_RANK[n + 1] then return false end
    if n == 2 then return GG.leader_of(guild, GG.culture_of(faction)) == faction end
    return true
end

-- WHAT WAS LAST WRITTEN, per faction and level: session memory. Empty after a load, so the
-- first sweep of a session writes every level once - the engine saves the records itself,
-- but a save from before halls has none, and this is what gives it some.
GG.halls_locked = GG.halls_locked or {}

function GG.lock_halls(faction, guild)
    if not faction or not GG.halls_here(faction) then return end
    local tag = GG.tag(faction)
    local memo = GG.halls_locked[faction] or {}
    GG.halls_locked[faction] = memo
    for n = 0, 2 do
        local key = GG.hall_key(guild, n, tag)
        local shut = not GG.hall_open(faction, guild, n)
        if memo[key] ~= shut then
            if shut then
                cm:add_event_restricted_building_record_for_faction(key, faction,
                    GG.hall_tip_key(guild, n, tag))
            else
                cm:remove_event_restricted_building_record_for_faction(key, faction)
            end
            memo[key] = shut
        end
    end
end
```

Add `guild_halls = true, hall_rep = 100, hall_off = 3,` to `GG.TUNE_DEFAULTS`.

Wire the sweep:

- **End of `GG.apply_rank`:** `GG.lock_halls(faction, guild)`.
- **`GG.reassert_leaders`, right after `GG.leaders_now[slot] = who`:**
  ```lua
              if type(was) == "string" then GG.lock_halls(was, guild) end
              if who then GG.lock_halls(who, guild) end
  ```
- **The first-tick callback, after `GG.first_cards()`:** `GG.first_halls()`, defined at the
  end of the HALLS block:
  ```lua
  function GG.first_halls()
      for faction, _ in pairs(GG.state) do
          if GG.halls_here(faction) then
              for i = 1, #GG.GUILDS do GG.lock_halls(faction, GG.GUILDS[i]) end
          end
      end
  end
  ```

- [ ] **Step 4: Run the harness and watch it pass**

Run: `& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua`
Expected: `harness ok`.

Then add a test that a pre-halls save gets swept (Review Focus 1). In the same block: set
`GG.halls_locked = {}`, put `THE_PLAYER` in `GG.state` at Exalted and leading, call
`GG.first_halls()`, and assert three `rems` for brass (all levels open, written once).

Then the AI hand-off (Review Focus 3): make `GG.leader_of` return `"cr_ai"` for brass, put
`cr_ai` (Exalted) in `GG.state`, call `GG.reassert_leaders()`, and assert one add for
`THE_PLAYER` level 2, one remove for `cr_ai` level 2, and nothing for any third faction.

- [ ] **Step 5: Checkpoint**

Run, in order:
1. `& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"`
2. `py tools\check_lua_api.py "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"`
3. `py tools\check_lua_literal_left.py`
4. `& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_bounty_harness.lua`

Expected: all clean. `check_lua_api` must not flag the two restriction calls, which CA
documents.

---

### Task 4: Lua - counting, reputation and the discount

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - the HALLS block;
  - `gg_turn` (line 4781);
  - `GG.on_building` (line 642);
  - `GG.service_cost` (line 4078);
  - `GG.LEDGER_SOURCES` (line 5298).
- Modify: `tools/gen_great_guilds.py`. `check_ledger_sources()` must know `halls`; add it
  wherever that check reads its list.
- Test: `tools/_guilds_harness.lua`, a new IIFE block.

**Interfaces:**
- Consumes: Task 3's `GG.hall_key`, `GG.halls_here`; `GG.capped_grant(f, g, amount,
  source)`.
- Produces:
  - `GG.halls[faction][guild] = {n = int, best = -1..2, lv = {c0, c1, c2}}`;
  - `GG.count_halls(faction) -> that table`;
  - `GG.pay_halls(faction)`;
  - `GG.hall_guild(chain) -> guild or nil`;
  - `GG.hall_discount(faction, guild) -> int` (percent, 0-15).

- [ ] **Step 1: Write the failing harness block**

```lua
-- GUILD HALLS: COUNTING, REPUTATION, DISCOUNT (spec §4.2-4.4). The region offers ONLY
-- building_exists - a stub richer than CA's interface hid a dead listener for 13 days.
;(function()
    local F = THE_PLAYER
    local function region(has) return {building_exists = function(_, k) return has[k] == true end} end
    local regions = {region({derpy_gg_hall_brass_2 = true}),
                     region({derpy_gg_hall_brass_0 = true}),
                     region({derpy_gg_hall_slavers_1 = true}),
                     region({})}
    local prev_gf = cm.get_faction
    cm.get_faction = function(self, k)
        local f = prev_gf(self, k)
        if k == F then f.region_list = function() return LIST(regions) end end
        return f
    end
    local h = GG.count_halls(F)
    assert(h.brass.n == 2 and h.brass.best == 2 and h.brass.lv[3] == 1 and h.brass.lv[1] == 1,
           "two brass halls, one of each counted level")
    assert(h.slavers.n == 1 and h.immortals.n == 0, "the others counted apart")
    -- Reputation: 15 + 4 brass, 8 slavers, through the capped funnel with source "halls"
    local grants = {}
    local prev_cg = GG.capped_grant
    GG.capped_grant = function(f, g, amt, src) grants[#grants + 1] = {g, amt, src} end
    GG.pay_halls(F)
    GG.capped_grant = prev_cg
    local got = {}
    for _, x in ipairs(grants) do assert(x[3] == "halls"); got[x[1]] = x[2] end
    assert(got.brass == 19 and got.slavers == 8, "pays 4/8/15 per hall by level")
    -- Discount: 2 halls x 3% = 6; capped at 15
    assert(GG.hall_discount(F, "brass") == 6, "3% a hall")
    GG.halls[F].brass.n = 9
    assert(GG.hall_discount(F, "brass") == 15, "capped at HALL_OFF_MAX")
    -- Completion pays the hall's own guild, ahead of the theme match
    assert(GG.hall_guild("derpy_gg_hall_khanate") == "khanate")
    assert(GG.hall_guild("derpy_gg_hall_nonsense") == nil)
    assert(GG.hall_guild("wh3_dlc23_chd_military_kdaai") == nil)
    -- A hall the faction could not have built still counts (Review Focus 4): counting
    -- never asks the locks.
    GG.state[F].slavers.rep = 0
    assert(GG.count_halls(F).slavers.n == 1, "an inherited hall still counts")
    -- Switch off: no reputation, no discount (Review Focus 5)
    local prev_s = GG.setting
    GG.setting = function(k) if k == "guild_halls" then return false end return prev_s(k) end
    grants = {}
    GG.capped_grant = function(f, g, amt, src) grants[#grants + 1] = {g, amt, src} end
    GG.pay_halls(F)
    GG.capped_grant = prev_cg
    assert(#grants == 0 and GG.hall_discount(F, "brass") == 0, "switch off pays nothing")
    GG.setting = prev_s
    cm.get_faction = prev_gf
end)()
```

- [ ] **Step 2: Run it and watch it fail**

Run: `& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua`
Expected: FAIL with `attempt to call field 'count_halls' (a nil value)`.

- [ ] **Step 3: Implement**

Append to the HALLS block:

```lua
-- WHAT STANDS, counted at turn start and never saved: the map is the record, so a reload
-- cannot desync it. A settlement holds one hall (the superchain is capped at one), so
-- the walk stops at the first hit per region.
GG.halls = GG.halls or {}

function GG.count_halls(faction)
    local out = {}
    for i = 1, #GG.GUILDS do out[GG.GUILDS[i]] = {n = 0, best = -1, lv = {0, 0, 0}} end
    GG.halls[faction] = out
    if not faction or not GG.halls_here(faction) then return out end
    local f = cm:get_faction(faction)
    if not f or f:is_null_interface() then return out end
    local tag = GG.tag(faction)
    local rl = f:region_list()
    for i = 0, rl:num_items() - 1 do
        local r = rl:item_at(i)
        local hit = false
        for gi = 1, #GG.GUILDS do
            local g = GG.GUILDS[gi]
            for n = 2, 0, -1 do
                if r:building_exists(GG.hall_key(g, n, tag)) then
                    local c = out[g]
                    c.n = c.n + 1
                    c.lv[n + 1] = c.lv[n + 1] + 1
                    if n > c.best then c.best = n end
                    hit = true
                    break
                end
            end
            if hit then break end
        end
    end
    return out
end

function GG.pay_halls(faction)
    if GG.setting("guild_halls") == false then return end
    local h = GG.halls[faction]
    if not h then return end
    local pct = tonumber(GG.setting("hall_rep")) or 100
    for i = 1, #GG.GUILDS do
        local g = GG.GUILDS[i]
        local c = h[g]
        local amt = c.lv[1] * GG.HALL_REP[1] + c.lv[2] * GG.HALL_REP[2] + c.lv[3] * GG.HALL_REP[3]
        amt = math.floor(amt * pct / 100)
        if amt > 0 then GG.capped_grant(faction, g, amt, "halls") end
    end
end

function GG.hall_discount(faction, guild)
    if GG.setting("guild_halls") == false then return 0 end
    local c = GG.halls[faction] and GG.halls[faction][guild]
    if not c or c.n <= 0 then return 0 end
    local off = c.n * (tonumber(GG.setting("hall_off")) or 3)
    if off > GG.HALL_OFF_MAX then off = GG.HALL_OFF_MAX end
    return off
end

function GG.hall_guild(chain)
    local g = chain and string.match(chain, "^derpy_gg_hall_(%l+)")
    for i = 1, #GG.GUILDS do if GG.GUILDS[i] == g then return g end end
    return nil
end
```

Wire it in:

- **`gg_turn`, right after `GG.rotate_cards(name, GG.turn_now())`:** `GG.count_halls(name)`.
- **`gg_turn`, right after `GG.on_turn_start(name, ...)`:** `GG.pay_halls(name)`.
- **`GG.first_halls()`:** count before locking, so the panel's discount is right before the
  first turn start:
  ```lua
          if GG.halls_here(faction) then
              GG.count_halls(faction)
              for i = 1, #GG.GUILDS do GG.lock_halls(faction, GG.GUILDS[i]) end
          end
  ```
- **`GG.on_building`:** replace
  `local guild = GG.guild_of_chain(chain) or "overseers"` with
  `local guild = GG.hall_guild(chain) or GG.guild_of_chain(chain) or "overseers"`.
- **`GG.service_cost`, right after the patron term and before the clamp:**
  ```lua
      -- HALLS: 3% a hall of this guild, at most 15 (spec §4.4). Before the clamp, so the
      -- -30 floor still bounds everything stacked together.
      mod = mod - GG.hall_discount(faction, svc.guild)
  ```
- **`GG.LEDGER_SOURCES`:** append `"halls"`.

- [ ] **Step 4: Run the harness, then the generator check**

Run the harness: expect `harness ok`. Then `py tools\gen_great_guilds.py --check`: expect
`check_ledger_sources` to be clean once `halls` has its loc line. Add the line to the
generator's ledger loc, worded "Halls".

- [ ] **Step 5: Checkpoint**

Same four commands as Task 3, Step 5.

---

### Task 5: Lua - the Seat bundle and the Seat's turn limit

**Files:**
- Modify: `zzz_derpy_guilds.lua`:
  - the HALLS block;
  - `GG.guild_cap` (line 409) and its two callers (lines 422 and 473);
  - `GG.reassert_leaders`;
  - `gg_turn`.
- Test: `tools/_guilds_harness.lua`, a new IIFE block.

**Interfaces:**
- Consumes: `GG.halls`, `GG.leader_of`, `GG.culture_of`, `GG.tag`.
- Produces:
  - `GG.seat_key(guild, tag)`;
  - `GG.has_seat(faction, guild) -> bool`;
  - `GG.assert_seat(faction, guild)`;
  - `GG.guild_cap(guild, faction)`, whose second argument is optional.

- [ ] **Step 1: Write the failing harness block**

```lua
-- GUILD HALLS: THE SEAT (spec §4.5). Lead + a level-2 hall, or no bundle.
;(function()
    local F = THE_PLAYER
    local prev_l = GG.leader_of
    GG.leader_of = function(g) return g == "brass" and F or nil end
    GG.halls[F] = GG.halls[F] or {}
    GG.halls[F].brass = {n = 1, best = 2, lv = {0, 0, 1}}
    GG.seat_on = {}
    local before = #applied
    GG.assert_seat(F, "brass")
    assert(#applied == before + 1 and applied[#applied][1] == "derpy_gg_seat_brass"
           and applied[#applied][3] == -1, "lead + seat applies the bundle, indefinitely")
    GG.assert_seat(F, "brass")
    assert(#applied == before + 1, "and only once")
    -- the turn limit, x1.5 while seated (cap_brass default 40 -> 60)
    assert(GG.guild_cap("brass", F) == 60, "seated cap is half again")
    assert(GG.guild_cap("brass") == 40, "no faction, no seat term")
    -- the settlement is lost (Review Focus 2): next count has no level-2 hall
    GG.halls[F].brass = {n = 0, best = -1, lv = {0, 0, 0}}
    local rb = #removed
    GG.assert_seat(F, "brass")
    assert(#removed == rb + 1 and removed[#removed][1] == "derpy_gg_seat_brass",
           "a lost Seat takes the bundle off")
    -- the lead is lost with the hall standing
    GG.halls[F].brass = {n = 1, best = 2, lv = {0, 0, 1}}
    GG.assert_seat(F, "brass")
    GG.leader_of = function() return "someone_else" end
    rb = #removed
    GG.assert_seat(F, "brass")
    assert(#removed == rb + 1, "losing the lead takes it off")
    GG.leader_of = prev_l
end)()
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL with `attempt to call field 'assert_seat' (a nil value)`.

- [ ] **Step 3: Implement**

```lua
function GG.seat_key(guild, tag) return "derpy_gg_seat_" .. guild .. (tag or "") end

function GG.has_seat(faction, guild)
    if GG.setting("guild_halls") == false then return false end
    local c = GG.halls[faction] and GG.halls[faction][guild]
    if not c or c.lv[3] <= 0 then return false end
    return GG.leader_of(guild, GG.culture_of(faction)) == faction
end

-- What was last applied, per faction and guild: session memory. Empty after a load, so
-- the first assertion of a session applies or removes once, which heals a save either way.
GG.seat_on = GG.seat_on or {}

function GG.assert_seat(faction, guild)
    if not faction or not GG.halls_here(faction) then return end
    local want = GG.has_seat(faction, guild)
    local k = faction .. "|" .. guild
    if GG.seat_on[k] == want then return end
    local key = GG.seat_key(guild, GG.tag(faction))
    if want then cm:apply_effect_bundle(key, faction, -1)
    else cm:remove_effect_bundle(key, faction) end
    GG.seat_on[k] = want
end
```

Change `GG.guild_cap`:

```lua
function GG.guild_cap(guild, faction)
    local cap = GG.setting("cap_" .. guild)
    if cap == nil then cap = GG.CAP[guild] or 0 end
    -- THE SEAT, half again (spec §5). Integer multiply then divide: the game's Lua is
    -- float32 and 1.5 is never written. 0 stays 0 - an uncapped guild stays uncapped.
    if faction and cap > 0 and GG.has_seat and GG.has_seat(faction, guild) then
        cap = math.floor(cap * 3 / 2)
    end
    return cap
end
```

Pass `faction` at both callers (`GG.capped_grant` line 422, and line 473). Grep the UI file
for `guild_cap(`. Every caller that has a faction passes it, so the panel shows the
seated limit.

Wire it in:

- **`gg_turn`, after `GG.pay_halls(name)`:**
  `for i = 1, #GG.GUILDS do GG.assert_seat(name, GG.GUILDS[i]) end`.
- **`GG.reassert_leaders`, beside Task 3's lock calls:**
  ```lua
              if type(was) == "string" then GG.assert_seat(was, guild) end
              if who then GG.assert_seat(who, guild) end
  ```
- **`GG.first_halls()`, after the locks:** the same per-guild `GG.assert_seat` loop.

- [ ] **Step 4: Run the harness and watch it pass**

Expected: `harness ok`.

- [ ] **Step 5: Checkpoint**

Same four commands as Task 3, Step 5.

---

### Task 6: Mirror check, mutants, MCT, panel text and icons

**Files:**
- Modify: `tools/gen_great_guilds.py`:
  - a new `check_hall_mirror()`, called from `check()`;
  - `help_pages(tag)`, a new chapter;
  - `check_promotion_text`'s source text, the promotion line;
  - `check_presets` for `hall_rep`.
- Modify: `tools/mutate_guilds.py`, the `MUTANTS` list.
- Modify: `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua`, which is written by
  hand: the switch and two sliders.
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` (CRLF):
  - `GGUI.set_header`'s stats text;
  - the price tooltip;
  - the Leaderboard hover.
- Modify: `tools/make_guild_icons.py`, six hall icons. They are CA-derived, so they ship in
  the pack only.
- Test: `_guilds_harness.lua` (GG_DUMP header), `preview_guilds_panel.py --check`, and
  `mutate_guilds.py`.

**Interfaces:**
- Consumes: everything above.
- Produces: `check_hall_mirror(lua=None) -> list[str]`, and loc keys
  `derpy_gg_halls_stat<tag>` and `derpy_gg_price_halls<tag>`.

- [ ] **Step 1: The mirror check, failing first**

```python
def check_hall_mirror(lua=None):
    """GG.HALL_RANK / HALL_REP / HALL_OFF_MAX and the HALL_TAGS set must equal the generator's."""
    lua = lua if lua is not None else io.open(MODEL_LUA, encoding="utf-8").read()
    out = []
    for name, want in (("HALL_RANK", HALL_RANK), ("HALL_REP", HALL_REP)):
        m = re.search(r"^GG\.%s = \{([^}]*)\}" % name, lua, re.M)
        got = [int(x) for x in re.findall(r"-?\d+", m.group(1))] if m else None
        if got != want:
            out.append("GG.%s is %r, the generator says %r" % (name, got, want))
    m = re.search(r"^GG\.HALL_OFF_MAX = (\d+)", lua, re.M)
    if not m or int(m.group(1)) != HALL_OFF_MAX:
        out.append("GG.HALL_OFF_MAX disagrees with the generator")
    m = re.search(r"^GG\.HALL_TAGS = \{([^}]*)\}", lua, re.M)
    tags = sorted(re.findall(r'\["([^"]*)"\] = true', m.group(1))) if m else None
    if tags != sorted(HALL_TAGS):
        out.append("GG.HALL_TAGS is %r, the generator builds %r" % (tags, HALL_TAGS))
    return out
```

Add to `selftest()`:
`assert check_hall_mirror(io.open(MODEL_LUA, encoding="utf-8").read().replace("GG.HALL_REP = {4, 8, 15}", "GG.HALL_REP = {4, 8, 16}"))`
and `assert check_hall_mirror() == []`. Run `--selftest`: the first fails before the function
exists, and both pass after.

- [ ] **Step 2: Mutants**

Append to `MUTANTS` in `tools/mutate_guilds.py`. M is the model file, LF.

```python
    ("a Seat opened without the lead", M,
     b"    if n == 2 then return GG.leader_of(guild, GG.culture_of(faction)) == faction end\n    return true",
     b"    return true"),
    ("the hall discount uncapped", M,
     b"    if off > GG.HALL_OFF_MAX then off = GG.HALL_OFF_MAX end",
     b""),
    ("counting stopping at level 0", M,
     b"            for n = 2, 0, -1 do",
     b"            for n = 0, 0, -1 do"),
    ("no lock sweep on a rank change", M,
     b"    GG.lock_halls(faction, guild)\nend",
     b"end"),
    ("the Seat bundle never removed", M,
     b"    else cm:remove_effect_bundle(key, faction) end",
     b"    end"),
    ("the halls switch ignored by the locks", M,
     b"    if GG.setting(\"guild_halls\") == false then return false end\n    local rank",
     b"    local rank"),
    ("hall completion paid by the theme match", M,
     b"GG.hall_guild(chain) or GG.guild_of_chain(chain)",
     b"GG.guild_of_chain(chain)"),
    ("the Seat's limit not raised", M,
     b"        cap = math.floor(cap * 3 / 2)",
     b"        cap = cap"),
    ("halls paid outside the turn limit", M,
     b"        if amt > 0 then GG.capped_grant(faction, g, amt, \"halls\") end",
     b"        if amt > 0 then GG.grant(faction, g, amt, \"halls\") end"),
    ("the old leader's level 2 left open", M,
     b"            if type(was) == \"string\" then GG.lock_halls(was, guild) end",
     b""),
```

Run: `py tools\mutate_guilds.py --selftest`. Expected: "selftest ok: 184 mutants anchored".
Then run `py tools\mutate_guilds.py` in full. Expected: every mutant caught. A survivor
means a harness assertion is missing. Add it to the owning task's block and re-run; never
delete the mutant.

The "paid outside the turn limit" mutant needs Task 4's block to cap brass. If it survives,
add an assertion that drives `GG.pay_halls` through the real `GG.capped_grant` with
`cap_brass` at 10, and reads back at most 10.

- [ ] **Step 3: MCT**

In `derpy_great_guilds.lua` (MCT), copy the existing `ai_bounties` checkbox block for
`guild_halls`: text "Guild halls", tooltip "Lets your race raise guild halls in its
settlements. Off locks them; halls already built stay but do nothing." Lock it in a running
campaign the way `race_differences` is locked.

Copy an existing Custom-preset slider block for `hall_rep` (0-300, step 10, default 100,
"Reputation from halls (%)") and for `hall_off` (0-10, default 3, "Price cut per hall
(%)").

Add both keys to the preset tables (`GG.PRESETS` in the model, around lines 4480-4520). Easy
120, Default 100, Hard 80, Cutthroat 60 for `hall_rep`. `hall_off` is not scaled.

Then run `py tools\gen_great_guilds.py --check`. `check_presets` and `check_mct_names` must
pass. If `check_mct_names` reports the generated `GGUI.MCT_NAMES` block stale, run
`py tools\gen_great_guilds.py --write`, which rewrites it.

- [ ] **Step 4: Panel text**

- **`GGUI.set_header`, the Guilds tab:** when `GG.halls[faction]` has `n > 0` for the
  selected guild, append the `derpy_gg_halls_stat` text "Halls %d" to the stats cell's
  string.
- **Price tooltip:** add a "Halls" line wherever the tooltip lists the loyalty, rivalry and
  patron terms, showing `-GG.hall_discount(faction, guild)`.
- **Leaderboard hover:** for the leader, append "Holds the seat" when `GG.has_seat(leader,
  guild)`.
- **Help:** a new chapter from `help_pages(tag)` for tags in `HALL_TAGS`, at most 21 lines.
  It covers the three levels and their ranks, one guild per settlement, reputation, the
  discount, the unit, and the Seat.
- **Promotion text:** reaching Indebted or Favoured adds "You may now raise a {noun} of
  {guild}."

Run: `$env:GG_DUMP="<scratch dir>"; & "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua`, then
`py tools\preview_guilds_panel.py --check`. Expected: exit 0, with no OVER finding on
`gg_rank_stats` for the eight flavours. Render `py tools\preview_guilds_panel.py` and look at
`gg_guilds.png` (memory `render-ui-preview-before-shipping`).

- [ ] **Step 5: Icons**

Extend `tools/make_guild_icons.py` (read its docstring first) to write one icon per hall
chain from a CA CHD building icon. Point the `building_culture_variants.icon` cells at them in
`hall_tables()` through a `HALL_ICON = {guild: icon stem}` dict. Run its `--check`.
`.gitignore` already blocks every image type, so they never reach the public repo.

- [ ] **Step 6: Checkpoint**

Run all gates:
1. `py tools\gen_great_guilds.py --check`
2. `py tools\gen_great_guilds.py --selftest`
3. the harness
4. the bounty harness
5. `py tools\mutate_guilds.py`
6. `py tools\check_guilds_ui.py`
7. `py tools\gen_guilds_ui.py --check`
8. `py tools\preview_guilds_panel.py --check`
9. `py tools\check_lua_api.py`
10. `py tools\check_lua_literal_left.py`
11. `luac -p` on all four scripts.

Expected: all green.

---

### Task 7: Pack, verify, deploy, and the in-game checks

**Files:**
- Modify: `tools/import_great_guilds.py`, only if its table loop does not already follow
  `G.TSV_META`. It does at line 419; confirm.
- Write: `docs/sessions/HANDOFF_<date>_GUILDS_HALLS_STAGE1.md` and its one line in
  `docs/SESSION_INDEX.md`.

- [ ] **Step 1: Verify without RPFM**

Run: `py tools\import_great_guilds.py --check`
Expected: every TSV matches `build()`, including the eleven new tables.

- [ ] **Step 2: Pack**

Check RPFM is open:
`Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing`. If the
connection is refused, stop and tell the author.

Back up the current pack to `Modding Files/Backup/guilds_pre_halls_<date>/`, never into
`data/`.

Run: `py tools\import_great_guilds.py`
Expected: it imports, saves, re-opens and counts every table's rows. Check duplicate keys
first (memory `wh3-check-duplicate-keys-before-packing`).

- [ ] **Step 3: Deploy**

If `Warhammer3.exe` is not running, copy the built pack into `data/` and compare MD5s
(memory `always-deploy-to-data-when-game-closed`). There is no Workshop copy of this pack, so
nothing goes to the Workshop folder.

- [ ] **Step 4: The in-game checks (spec §10), in a Chaos Dwarf campaign**

Run each and write down what you saw:

1. A second guild's hall cannot be started in a settlement that has one.
2. A locked level shows CA's restricted icon and our tooltip, and stays locked after a
   reload.
3. `faction_unique` refuses a second level-1 hall of the same guild.
4. `building_exists` during construction. Read `GG.halls` through the wh3 bridge on the turn
   the hall is ordered.
5. AI factions build halls. Give it about 20 turns, then read a rival's regions through the
   bridge.
6. The local effect shows on the settlement and province.
7. The hall unit recruits at the expected rank.
8. The building's name, description and icon draw, with no placeholder.

If check 1 fails, stop. The fallback is the spec §10 per-region chain lock, which needs a spec
amendment before any code.

- [ ] **Step 5: Handoff**

Write `docs/sessions/HANDOFF_<date>_GUILDS_HALLS_STAGE1.md` in the shape of the existing
ones: built, verified and how, corrections, do-not-re-derive, open. Add its one line to
`docs/SESSION_INDEX.md`. Stage 2's plan is written from that handoff's results.
