# Great Guilds Temple Lore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each race's temple guild effects drawn from its own lore. That covers the rank, leader, hall and seat layers, plus three themed services per race. The Empire's Winds of Magic service moves from the Engineers' School to the Colleges.

**Architecture:** All changes are data in `tools/gen_great_guilds.py`. One new per-race table, `TEMPLE_LORE`, is read through small `(guild, tag)` helpers. Every site that reads the temple's rank, leader, hall or seat data today goes through those helpers instead. Services use the file's existing `for_tag` override. No Lua changes: the Lua mirrors no effect, value or text of these layers.

**Tech Stack:** Python 3 (`py`), Lua 5.1.5 harness, RPFM MCP server (packing only), the repo's offline readers.

**Spec:** `docs/superpowers/specs/2026-10-09-great-guilds-temple-lore-design.md`

## Global Constraints

- **Workspace:** not a git repo. Never run `git`. Where a task says "record", that means one line in `docs/SESSION_INDEX.md` at the end (Task 4).
- **Tag keys:** a race is a flavour tag. `""` is the Chaos Dwarfs; the others are `_emp`, `_dwf`, `_brt`, `_cth`, `_ksl`, `_def`, `_hef`, `_skv` and `_gen`. `_gen` has no halls (`HALL_TAGS` lacks it).
- **Effect pairs:** every (effect, scope) pair must be one vanilla ships. `check()` / `check_halls()` enforce this and hold values to 1.5x vanilla's largest magnitude.
- **Unchanged:** service names, kinds, costs, cooldowns and durations, apart from the one Empire rename in Task 3.
- **Player text:** plain words; "Reputation" and "Favour" are capitalised; no jargon (memory `player-text-plain-words`); no emojis anywhere.
- **Pack:** packed only with `py tools/import_great_guilds.py` while RPFM is open.
- **Deploy:** the Workshop folder only, `F:\SteamLibrary\steamapps\workshop\content\1142710\3815248936\derpy_great_guilds.pack`. **Never `data/`.** Back up to `Modding Files/Backup/` first.
- **Ask first:** uploading to Steam and syncing GitHub are separate steps that need the author's approval.

## Review Focus

1. **The Chaos Dwarf tag `""`** must resolve through `TEMPLE_LORE` like every other tag. The empty string is falsy, but it is a real key, so lookups must use `.get(tag)`, never `if tag`. The Task 1 asserts cover `""`.
2. **The Empire seat is negative-good** (spell cost -5). Its loc must read "-5%", never "--5" or "+-5", and the sign check must accept it. Covered in Task 2.
3. **`_gen` gets the leadership ladder but has no halls.** There must be no `_gen` hall or seat rows, and its rank bundles must carry leadership. Covered in Tasks 1 and 2.
4. **A damaged hall pays half, rounded toward zero.** The Dark Elf level-0 and level-1 halls (value 1) pay 0 while damaged. That is intended and matches vanilla; Task 2 pins it so nobody "fixes" it.
5. **Existing saves:** bundle and building keys don't change, so a running campaign shows the new effects on load. Only an in-game check can prove it; it is listed as owed in Task 4.

---

### Task 1: Per-race rank and leader bundles

**Files:**
- Modify: `tools/gen_great_guilds.py`
  - `rank_value` at line ~144
  - `lead_value` at line ~664
  - the new block after `HALL_EXTRA` at line ~2163
  - `_build_one` lines ~3130-3216
  - `built_tables` line ~5028
  - `check()` lines ~6597-6624
  - `selftest()`, before its final `print("selftest ok...`

**Interfaces:**
- Produces:
  - the `TEMPLE_LORE` dict (shape below)
  - `_lore(guild, tag, field) -> value | None`
  - `rank_effect(g, tag="") -> (effect, scope)`
  - `effect_blurb(g, tag="") -> (blurb, reach)`
  - `good_sign(g, tag="") -> int`
  - `rank_value(g, rank, tag="") -> int`
  - `lead_value(g, tag="") -> int`
  - Task 2 adds the `hall`, `hall_text`, `seat` and `seat_text` fields to the same dict.

- [ ] **Step 1: Write the failing asserts**

In `selftest()`, find the line `print("selftest ok: %d guilds, %d services, %d bundles, %d loc"` and insert this block directly above it. `full` is already bound earlier in `selftest()` by `full = build()`:

```python
    # THE TEMPLE BY ITS OWN LORE (2026-10-09 spec §3.1): rank and leader per race.
    _w = "wh3_main_effect_winds_of_magic_pool_cap"
    want_rank = {
        "": (_w, [3, 6, 10, 15], 10), "_emp": (_w, [3, 6, 10, 15], 10),
        "_cth": (_w, [3, 6, 10, 15], 10), "_skv": (_w, [3, 6, 10, 15], 10),
        "_dwf": ("wh_main_effect_force_stat_magic_resistance", [3, 6, 10, 15], 10),
        "_brt": ("wh_main_effect_force_stat_ward_save", [2, 4, 6, 8], 5),
        "_hef": ("wh_main_effect_force_stat_ward_save", [2, 4, 6, 8], 5),
        "_ksl": ("wh_main_effect_force_stat_leadership", [2, 4, 6, 8], 5),
        "_gen": ("wh_main_effect_force_stat_leadership", [2, 4, 6, 8], 5),
        "_def": ("wh_main_effect_force_stat_melee_attack", [2, 3, 4, 6], 4),
    }
    jn = {}
    for r in full["effect_bundles_to_effects_junctions"]:
        jn.setdefault(r["effect_bundle_key"], []).append(r)
    for t, (ek, ladder, lead) in want_rank.items():
        for rank, v in zip(range(2, 6), ladder):
            rows = jn[bundle_key("temple", rank) + t]
            assert [(r["effect_key"], r["effect_scope"], r["value"]) for r in rows] == \
                [(ek, "faction_to_force_own", str(v))], (t, rank, rows)
        rows = jn[lead_key("temple") + t]
        assert [(r["effect_key"], r["value"]) for r in rows] == [(ek, str(lead))], (t, rows)
    # Every other guild is untouched.
    assert jn[bundle_key("brass", 2) + "_emp"][0]["effect_key"] == RANK_EFFECTS["brass"][0]
    lt = {r["key"]: r["text"] for r in full["loc"]}
    assert "+15% Winds of Magic reserve capacity for every army" in \
        lt["effect_bundles_localised_description_" + bundle_key("temple", 5) + "_emp"]
```

- [ ] **Step 2: Run it and watch it fail**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: `AssertionError` on the first `want_rank` tag, showing `wh_main_effect_public_order_events` rows. It takes a few minutes; run it in the background if needed.

- [ ] **Step 3: Add `TEMPLE_LORE` and the helpers**

Insert directly after the closing `}` of `HALL_EXTRA = {...}` (line ~2163). This step fills only the rank fields; Task 2 adds the hall and seat fields to the same entries.

```python
# THE TEMPLE BY ITS OWN LORE (2026-10-09 spec, docs/superpowers/specs/
# 2026-10-09-great-guilds-temple-lore-design.md). The temple began as the Temple of Hashut
# renamed per race, so every race's temple paid public order on every layer; a player
# backing the Colleges of Magic asked where the magic was. Each tag here is that race's
# order as the lore has it - the Dwarfs get no magic. Pairs read from 9.0 db.pack; check()
# holds them to vanilla. A field a tag leaves out falls back to the guild-wide table.
_TEMPLE_WINDS = ("wh3_main_effect_winds_of_magic_pool_cap", "faction_to_force_own")
_TEMPLE_PCT = [None, None, 3, 6, 10, 15]     # a percentage, like the shared ladder
_TEMPLE_FLAT = [None, None, 2, 4, 6, 8]      # a flat count every army carries
_WINDS_LORE = {"rank": _TEMPLE_WINDS, "ladder": _TEMPLE_PCT, "lead": 10, "sign": 1,
               "blurb": ("%+d%% Winds of Magic reserve capacity", "every army")}
TEMPLE_LORE = {
    "": dict(_WINDS_LORE),
    "_emp": dict(_WINDS_LORE),
    "_cth": dict(_WINDS_LORE),
    "_skv": dict(_WINDS_LORE),
    "_dwf": {"rank": ("wh_main_effect_force_stat_magic_resistance", "faction_to_force_own"),
             "ladder": _TEMPLE_PCT, "lead": 10, "sign": 1,
             "blurb": ("%+d%% spell resistance", "every army")},
    "_brt": {"rank": ("wh_main_effect_force_stat_ward_save", "faction_to_force_own"),
             "ladder": _TEMPLE_FLAT, "lead": 5, "sign": 1,
             "blurb": ("%+d%% ward save", "every army")},
    "_hef": {"rank": ("wh_main_effect_force_stat_ward_save", "faction_to_force_own"),
             "ladder": _TEMPLE_FLAT, "lead": 5, "sign": 1,
             "blurb": ("%+d%% ward save", "every army")},
    "_ksl": {"rank": ("wh_main_effect_force_stat_leadership", "faction_to_force_own"),
             "ladder": _TEMPLE_FLAT, "lead": 5, "sign": 1,
             "blurb": ("%+d leadership", "every army")},
    "_gen": {"rank": ("wh_main_effect_force_stat_leadership", "faction_to_force_own"),
             "ladder": _TEMPLE_FLAT, "lead": 5, "sign": 1,
             "blurb": ("%+d leadership", "every army")},
    "_def": {"rank": ("wh_main_effect_force_stat_melee_attack", "faction_to_force_own"),
             "ladder": [None, None, 2, 3, 4, 6], "lead": 4, "sign": 1,
             "blurb": ("%+d melee attack", "every army")},
}


def _lore(guild, tag, field):
    """The temple's per-race `field`, or None - for every other guild, and for a tag that
    leaves the field out. .get(tag), never `if tag`: "" is the Chaos Dwarfs."""
    if guild != "temple":
        return None
    return TEMPLE_LORE.get(tag, {}).get(field)


def rank_effect(g, tag=""):
    return _lore(g, tag, "rank") or RANK_EFFECTS[g]


def effect_blurb(g, tag=""):
    return _lore(g, tag, "blurb") or EFFECT_BLURB[g]


def good_sign(g, tag=""):
    return _lore(g, tag, "sign") or EFFECT_GOOD_SIGN[g]
```

`%%` is a literal percent sign: the blurb is %-formatted with the signed value.

- [ ] **Step 4: Make `rank_value` and `lead_value` take the tag**

Replace `def rank_value(g, rank):` and its body (line ~144):

```python
def rank_value(g, rank, tag=""):
    return (_lore(g, tag, "ladder") or RANK_VALUES_OF.get(g, RANK_VALUES))[rank]
```

Replace `def lead_value(g):` and its body (line ~664):

```python
def lead_value(g, tag=""):
    return _lore(g, tag, "lead") or LEAD_VALUE_OF.get(g, LEAD_VALUE)
```

- [ ] **Step 5: Route `_build_one` through the helpers**

In `_build_one(tag)`, in the `for g in GUILDS:` loop (lines ~3130-3216), make these replacements:
- `effect_key, scope = RANK_EFFECTS[g]` becomes `effect_key, scope = rank_effect(g, tag)`.
- Both occurrences of `blurb, reach = EFFECT_BLURB[g]` become `blurb, reach = effect_blurb(g, tag)`.
- Every `rank_value(g, r)` becomes `rank_value(g, r, tag)`, and every `rank_value(g, rank)` becomes `rank_value(g, rank, tag)`.
- Every `lead_value(g)` becomes `lead_value(g, tag)`.
- Every `EFFECT_GOOD_SIGN[g]` in this loop becomes `good_sign(g, tag)`.

There are 9 sites in all. Afterwards, `grep -n "EFFECT_GOOD_SIGN\[g\]\|EFFECT_BLURB\[g\]\|RANK_EFFECTS\[g\]" tools/gen_great_guilds.py` must print only lines outside `_build_one`: the `check()` loop, which Step 7 replaces, and `built_tables`, which Step 6 replaces.

Leave `service_sign`, `EFFECT_BLURB[s["guild"]]` and `RANK_EFFECTS[s["guild"]]` in the service loop alone. They only reach services that have no effects of their own, and every temple service has its own.

- [ ] **Step 6: The built-effect icon follows the race**

In `built_tables()` (line ~5028), replace `icon = icon_of[RANK_EFFECTS[g][0]]` with:

```python
            icon = icon_of[rank_effect(g, tag)[0]]
```

- [ ] **Step 7: `check()` checks every race's pair and sign**

In `check()`, after the line `pairs_to_check += [(g, x[0], x[1]) for g, x in RANK_EFFECTS_EXTRA.items()]`, add:

```python
        pairs_to_check += [("temple" + t, L["rank"][0], L["rank"][1])
                           for t, L in TEMPLE_LORE.items() if "rank" in L]
```

Replace the loop `for g, (k, sc) in RANK_EFFECTS.items():` that compares `EFFECT_GOOD_SIGN.get(g)` with:

```python
        for g, t in [(g, "") for g in GUILDS] + [("temple", t) for t in TEMPLE_LORE]:
            k = rank_effect(g, t)[0]
            if k not in good:
                continue
            want = 1 if good[k] else -1
            if good_sign(g, t) != want:
                out.append("%s%s: %s has is_positive_value_good=%s so the value must be "
                           "%s, but its sign is %+d"
                           % (g, t, k, good[k], "positive" if want > 0 else "negative",
                              good_sign(g, t)))
```

- [ ] **Step 8: Run the asserts and watch them pass**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: `selftest ok: ...`.

If an existing assert elsewhere in `selftest()` pins a temple public-order rank value, update it to the `want_rank` value and say so in the task report. Do not delete it.

- [ ] **Step 9: Prove the asserts measure**

Temporarily change `"_def"`'s `"ladder"` to `[None, None, 2, 3, 4, 7]` and run `--selftest`. Expected: `AssertionError` naming `_def`. Restore `6`, re-run, and expect `selftest ok`.

- [ ] **Step 10: `--check` is clean**

Run: `py tools/gen_great_guilds.py --check`
Expected: exit 0 and no `PROBLEM:` lines.

---

### Task 2: Per-race halls and seats

**Files:**
- Modify: `tools/gen_great_guilds.py`
  - `TEMPLE_LORE` (Task 1)
  - `HALL_EXTRA` line ~2160
  - `hall_tables()` lines ~2575 and ~2637-2650
  - `hall_desc()` line ~2691
  - `check()` lines ~6600 and ~6626-6631
  - `selftest()` lines ~7342-7346, ~7364 and ~7370

**Interfaces:**
- Consumes: `TEMPLE_LORE` and `_lore` from Task 1.
- Spec deviation: the spec's `_gen` seat row is dropped. `_gen` has no halls (`HALL_TAGS`), so it has no seat to carry it.
- Produces:
  - `hall_effect(g, tag="") -> (effect, scope, [v0, v1, v2])`
  - `hall_bonus_text(g, tag="") -> str` with one `%d`
  - `seat_effect(g, tag="") -> (effect, scope, value)`
  - `seat_text(g, tag="") -> str`, a whole sentence with no trailing full stop

- [ ] **Step 1: Write the failing asserts**

In `selftest()`, directly BELOW the Task 1 block (still above the final `print`), add:

```python
    # THE TEMPLE'S HALLS AND SEATS BY LORE (2026-10-09 spec §3.2-§3.3).
    ht2 = hall_tables()
    hj = {}
    for r in ht2["building_effects_junction"]:
        hj.setdefault(r["building"], []).append(r)
    want_hall = {
        "_emp": ("wh_main_effect_agent_recruitment_xp_wizard_empire", [1, 2, 3]),
        "_dwf": ("wh_main_effect_agent_recruitment_xp_runesmith", [1, 2, 3]),
        "_brt": ("wh_dlc07_effect_chivalry_building", [10, 20, 30]),
        "_cth": ("wh3_main_effect_agent_recruitment_xp_cth_astromancer", [1, 2, 3]),
        "_ksl": ("wh3_main_effect_ksl_orthodoxy_support_buildings", [1, 2, 3]),
        "_def": ("wh2_main_effect_building_unit_xp_levels_def_resource_medicine", [1, 1, 2]),
        "_hef": ("wh2_main_effect_agent_recruitment_xp_hef_mage", [1, 2, 3]),
        "_skv": ("wh3_main_effect_corruption_skaven_buildings", [2, 4, 6]),
        "": ("wh3_dlc23_effect_pooled_resource_conclave_influence_gain_temples", [5, 10, 15]),
    }
    for t, (ek, vals) in want_hall.items():
        for n in range(3):
            got = [r for r in hj[hall_key("temple", n, t)] if r["effect"] == ek]
            assert len(got) == 1 and got[0]["value"] == str(vals[n]), (t, n, hj[hall_key("temple", n, t)])
            assert got[0]["value_damaged"] == str(int(vals[n] / 2)), got   # Review Focus 4
        assert not any(r["effect"] == "wh_main_effect_public_order_base"
                       for n in range(3) for r in hj[hall_key("temple", n, t)]), t
    # The Empire keeps its wizard cap; the Skaven extra became the main effect, once.
    assert sum(r["effect"] == "wh_main_effect_agent_cap_increase_wizard_empire"
               for r in hj[hall_key("temple", 2, "_emp")]) == 1
    assert sum(r["effect"] == "wh3_main_effect_corruption_skaven_buildings"
               for r in hj[hall_key("temple", 2, "_skv")]) == 1
    sj = {r["effect_bundle_key"]: r for r in ht2["effect_bundles_to_effects_junctions"]}
    want_seat = {
        "_emp": ("wh2_dlc14_effect_magic_cost_all_lores_percentage", "-5"),
        "_dwf": ("wh_main_effect_force_stat_leadership", "3"),
        "_brt": ("wh_main_effect_agent_recruitment_xp_wizard_bretonnia", "2"),
        "_cth": ("wh_main_effect_technology_research_points", "5"),
        "_ksl": ("wh3_main_effect_agent_recruitment_xp_ksl_frost_maiden", "2"),
        "_def": ("wh2_main_effect_agent_cap_increase_def_death_hag", "1"),
        "_hef": ("wh_main_effect_force_stat_magic_resistance", "5"),
        "_skv": ("wh3_main_effect_corruption_skaven_events", "2"),
        "": ("wh_main_effect_force_stat_magic_resistance", "5"),
    }
    for t, (ek, v) in want_seat.items():
        r = sj[seat_key("temple", t)]
        assert (r["effect_key"], r["value"]) == (ek, v), (t, r)
    hl = {r["key"]: r["text"] for r in ht2["loc"]}
    seat_emp = hl["effect_bundles_localised_description_" + seat_key("temple", "_emp")]
    assert "Spell cost -5% in every army" in seat_emp and "--" not in seat_emp, seat_emp  # Review Focus 2
    assert not any(seat_key("temple", "_gen") in k for k in sj), "_gen has no halls"     # Review Focus 3
    assert "Battle Wizards recruited in this province start at rank +1" in \
        hall_desc("temple", 0, "_emp"), hall_desc("temple", 0, "_emp")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: `KeyError` or `AssertionError` in the new block. The halls still carry public order.

- [ ] **Step 3: Add the hall and seat fields to `TEMPLE_LORE`**

Directly after the `TEMPLE_LORE = {...}` dict from Task 1, add:

```python
# Halls stay LOCAL - a lodge goes in any settlement, so a faction-wide effect would stack
# once per lodge - except per-turn resources CA itself puts on buildings at faction scope
# (Kislev's Orthodoxy Support, the Chaos Dwarfs' Conclave Influence, both off CA's own
# religion buildings). The seat is its own effect per race: most local effects have no
# faction-wide twin. Hidden (_unseen) effects say their number in hall_text / seat_text.
_TEMPLE_HALL_SEAT = {
    "": ("wh3_dlc23_effect_pooled_resource_conclave_influence_gain_temples",
         "building_to_faction_own", [5, 10, 15], "Conclave Influence +%d each turn",
         ("wh_main_effect_force_stat_magic_resistance", "faction_to_force_own", 5),
         "Spell resistance +5% in every army"),
    "_emp": ("wh_main_effect_agent_recruitment_xp_wizard_empire",
             "province_to_province_own_unseen", [1, 2, 3],
             "Battle Wizards recruited in this province start at rank +%d",
             ("wh2_dlc14_effect_magic_cost_all_lores_percentage", "faction_to_force_own", -5),
             "Spell cost -5% in every army"),
    "_dwf": ("wh_main_effect_agent_recruitment_xp_runesmith",
             "province_to_province_own_unseen", [1, 2, 3],
             "Runesmiths recruited in this province start at rank +%d",
             ("wh_main_effect_force_stat_leadership", "faction_to_force_own", 3),
             "Leadership +3 in every army"),
    "_brt": ("wh_dlc07_effect_chivalry_building", "region_to_region_own", [10, 20, 30],
             "Chivalry +%d each turn",
             ("wh_main_effect_agent_recruitment_xp_wizard_bretonnia",
              "faction_to_province_own", 2),
             "Damsels you recruit start at rank +2"),
    "_cth": ("wh3_main_effect_agent_recruitment_xp_cth_astromancer",
             "province_to_province_own_unseen", [1, 2, 3],
             "Astromancers recruited in this province start at rank +%d",
             ("wh_main_effect_technology_research_points", "faction_to_faction_own_unseen", 5),
             "Research points +5 each turn"),
    "_ksl": ("wh3_main_effect_ksl_orthodoxy_support_buildings",
             "faction_to_faction_own_unseen", [1, 2, 3], "Orthodoxy Support +%d each turn",
             ("wh3_main_effect_agent_recruitment_xp_ksl_frost_maiden",
              "faction_to_province_own_unseen", 2),
             "Frost Maidens you recruit start at rank +2"),
    "_def": ("wh2_main_effect_building_unit_xp_levels_def_resource_medicine",
             "province_to_province_own", [1, 1, 2],
             "Witch Elves and Sisters of Slaughter recruited in this province start at rank +%d",
             ("wh2_main_effect_agent_cap_increase_def_death_hag",
              "faction_to_faction_own_unseen", 1),
             "Death Hags you may recruit +1"),
    "_hef": ("wh2_main_effect_agent_recruitment_xp_hef_mage",
             "province_to_province_own_unseen", [1, 2, 3],
             "Mages recruited in this province start at rank +%d",
             ("wh_main_effect_force_stat_magic_resistance", "faction_to_force_own", 5),
             "Spell resistance +5% in every army"),
    "_skv": ("wh3_main_effect_corruption_skaven_buildings", "region_to_region_own",
             [2, 4, 6], "Skaven corruption +%d in this settlement",
             ("wh3_main_effect_corruption_skaven_events", "faction_to_province_own", 2),
             "Skaven corruption +2 in every province"),
}
for _t, (_he, _hs, _hv, _ht, _seat, _st) in _TEMPLE_HALL_SEAT.items():
    TEMPLE_LORE[_t].update(hall=(_he, _hs, _hv), hall_text=_ht, seat=_seat, seat_text=_st)


def hall_effect(g, tag=""):
    return _lore(g, tag, "hall") or HALL_EFFECT[g]


def hall_bonus_text(g, tag=""):
    return _lore(g, tag, "hall_text") or HALL_BONUS[g]


def seat_effect(g, tag=""):
    """(effect, scope, value) on the Seat bundle: the race's own for the temple, else the
    hall's effect faction-wide at a third of level 2 (the halls spec §4.5)."""
    return _lore(g, tag, "seat") or (HALL_EFFECT[g][0], HALL_SEAT_SCOPE[g], seat_value(g))


def seat_text(g, tag=""):
    return _lore(g, tag, "seat_text") or ("The hall's bonus applies to all your lands at "
                                          "a third of its strength")
```

`HALL_BONUS` is defined further down the file than this block. That is fine: the helpers read it when called, not when the module loads.

- [ ] **Step 4: Remove the Skaven `HALL_EXTRA` entry**

In `HALL_EXTRA` (line ~2160), delete the `("temple", "_skv"): (...)` entry and its comment. Its effect is now the Skaven hall's main effect. Leaving it would put Skaven corruption on the hall twice, and the Step 1 assert checks for exactly one.

- [ ] **Step 5: Route `hall_tables()` and `hall_desc()` through the helpers**

In `hall_tables()`:
- Replace `eff, scope, vals = HALL_EFFECT[g]` (line ~2575) with `eff, scope, vals = hall_effect(g, tag)`.
- Replace the seat junction and description (lines ~2644-2650) with:

```python
            s_eff, s_scope, s_val = seat_effect(g, tag)
            t["effect_bundles_to_effects_junctions"].append(_bundle_junction_row(
                sk, s_eff, s_scope, s_val))
            t["loc"].append({"key": "effect_bundles_localised_title_" + sk,
                             "text": seat_title, "tooltip": "false"})
            t["loc"].append({"key": "effect_bundles_localised_description_" + sk,
                             "text": "You lead %s and hold their Seat. %s. "
                                     "Your earnings limit each turn rises by half."
                                     % (_with_article(g, tag), seat_text(g, tag)),
                             "tooltip": "false"})
```

In `hall_desc()` (line ~2691), replace `HALL_BONUS[guild] % abs(HALL_EFFECT[guild][2][n]))` with:

```python
        hall_bonus_text(guild, tag) % abs(hall_effect(guild, tag)[2][n]))
```

- [ ] **Step 6: `check()` checks the seat pairs and signs per race**

In `check()`, replace
`pairs_to_check += [("seat_" + g, HALL_EFFECT[g][0], HALL_SEAT_SCOPE[g]) for g in GUILDS]` with:

```python
        pairs_to_check += [("seat_" + g + t, seat_effect(g, t)[0], seat_effect(g, t)[1])
                           for g in GUILDS for t in HALL_TAGS]
```

Replace the seat sign loop (`for g in GUILDS:` / `k = HALL_EFFECT[g][0]` / `if k in good and (seat_value(g) > 0) != good[k]:`) with:

```python
        for g in GUILDS:
            for t in HALL_TAGS:
                k, _sc, v = seat_effect(g, t)
                if k in good and (v > 0) != good[k]:
                    out.append("seat %s%s: %s has is_positive_value_good=%s, but the Seat "
                               "pays %+d" % (g, t, k, good[k], v))
```

- [ ] **Step 7: Update the old selftest asserts this changes**

- Line ~7344, in the F3 seat loop: replace the `assert r["effect_key"] == HALL_EFFECT[g][0] and ...` line with:

  ```python
            assert (r["effect_key"], r["effect_scope"]) == seat_effect(g, t)[:2], (g, t, r)
  ```

- Line ~7364, the Chaos Dwarf level-2 `"temple": "Earns 15 Reputation ... Public order +6 in this province. ..."`: replace `Public order +6 in this province` with `Conclave Influence +15 each turn`.
- Line ~7370, the `_emp` level-0 assert: replace `Public order +2 in this province` with `Battle Wizards recruited in this province start at rank +1`.

- [ ] **Step 8: Run the asserts and watch them pass**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: `selftest ok: ...`.

- [ ] **Step 9: Prove the asserts measure**

Temporarily change `_TEMPLE_HALL_SEAT["_emp"]`'s seat value from `-5` to `5` and run `--check`. Expected: a `seat temple_emp: ... is_positive_value_good=False` PROBLEM line. Restore `-5`.

Next, temporarily restore the deleted Skaven `HALL_EXTRA` entry and run `--selftest`. Expected: the `sum(...) == 1` assert fails. Delete the entry again.

- [ ] **Step 10: The checks are clean**

Run: `py tools/gen_great_guilds.py --check`
Expected: exit 0. That run includes `check_halls`, which holds every hall pair to `building_effects_junction`.

---

### Task 3: The three signature services per race and the Empire Tithe

**Files:**
- Modify: `tools/gen_great_guilds.py`
  - `SERVICES` rows `hashut_blessing` (line ~521), `zeal` (~532), `holy_war` (~551) and `spirit_siphon` (~280)
  - `POOL_NAMES["_emp"]` (line ~1782)
  - `selftest()`

**Interfaces:**
- Consumes: the existing `service_effects(s, tag)` / `service_text(s, tag)` `for_tag` mechanism.
- Produces: per-tag bundle junctions on `derpy_gg_svc_<key><tag>`.

- [ ] **Step 1: Write the failing asserts**

In `selftest()`, directly BELOW the Task 2 block (still above the final `print`), add. It reads `jn` from the Task 1 block, so it must come after it:

```python
    # THE THREE SIGNATURE SERVICES PER RACE (2026-10-09 spec §4).
    def _svc(key, t):
        return sorted((r["effect_key"], r["effect_scope"], r["value"])
                      for r in jn[service_bundle_key(key) + t])
    F2F, FAC = "force_to_force_own", "faction_to_force_own"
    MR, MC = "wh_main_effect_force_stat_magic_resistance", "wh2_dlc14_effect_magic_cost_all_lores_percentage"
    WE, WS = "wh3_main_effect_winds_of_magic_events", "wh_main_effect_force_stat_ward_save"
    LD, MA = "wh_main_effect_force_stat_leadership", "wh_main_effect_force_stat_melee_attack"
    assert _svc("hashut_blessing", "_emp") == [(MR, F2F, "15")]
    assert _svc("zeal", "_emp") == [(MC, F2F, "-20")]
    assert _svc("holy_war", "_emp") == sorted([(WE, FAC, "5"), (MC, FAC, "-10")])
    assert _svc("hashut_blessing", "_brt") == [(WS, F2F, "15")]
    assert _svc("holy_war", "_skv") == sorted([(WE, FAC, "5"),
                                              ("wh_main_effect_character_stat_miscast", FAC, "-10")])
    assert _svc("hashut_blessing", "") == [("wh_main_effect_force_stat_physical_resistance", F2F, "10")]
    assert _svc("zeal", "_dwf") == _svc("zeal", "_gen"), "Slayer's Oath keeps the shared zeal"
    assert _svc("holy_war", "_gen") == sorted([(LD, FAC, "6"),
        ("wh_main_effect_force_all_campaign_replenishment_rate", FAC, "10")]), "_gen unchanged"
    assert not any(e[0] == WE for t in ("_dwf",) for k in ("hashut_blessing", "zeal", "holy_war")
                   for e in _svc(k, t)), "no Winds for the Dwarfs"
    # The Tithe left the Engineers for the Colleges.
    assert _svc("spirit_siphon", "_emp") == [("wh_main_effect_force_stat_physical_resistance", FAC, "5")]
    assert FLAVOURS["_emp"]["services"]["spirit_siphon"] == "Proofed Armour"
```

The new name is **"Proofed Armour"**, not the spec's "Nuln Steel". `POOL_NAMES["_emp"]` already uses "Nuln Steel" for `forged_arms`, and two services must not share a name.

- [ ] **Step 2: Run it and watch it fail**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: `AssertionError` on the first `_svc("hashut_blessing", "_emp")`.

- [ ] **Step 3: Add the `for_tag` overrides**

Add a `"for_tag"` key to each of the three temple rows. Each of these rows has none today, so add it after the row's `"text"` entry. Every string uses `{vN}` exactly as the shared rows do:

```python
    # hashut_blessing - after its "text": ... line:
     # THE TEMPLE BY ITS OWN LORE (2026-10-09 spec §4): the single-army blessing per race.
     "for_tag": {
         "_emp": {"effects": [("wh_main_effect_force_stat_magic_resistance", "force_to_force_own", 15)],
                  "text": '{v0:+d}% spell resistance for the army you select for {turns} turns.'},
         "_dwf": {"effects": [("wh_main_effect_force_stat_magic_resistance", "force_to_force_own", 15)],
                  "text": '{v0:+d}% spell resistance for the army you select for {turns} turns.'},
         "_brt": {"effects": [("wh_main_effect_force_stat_ward_save", "force_to_force_own", 15)],
                  "text": '{v0:+d}% ward save for the army you select for {turns} turns.'},
         "_cth": {"effects": [("wh2_dlc14_effect_magic_cost_all_lores_percentage", "force_to_force_own", -20)],
                  "text": '{v0:+d}% spell cost for the army you select for {turns} turns.'},
         "_ksl": {"effects": [("wh_main_effect_force_stat_ward_save", "force_to_force_own", 10)],
                  "text": '{v0:+d}% ward save for the army you select for {turns} turns.'},
         "_def": {"effects": [("wh_main_effect_force_stat_ward_save", "force_to_force_own", 10)],
                  "text": '{v0:+d}% ward save for the army you select for {turns} turns.'},
         "_hef": {"effects": [("wh_main_effect_force_stat_ward_save", "force_to_force_own", 15)],
                  "text": '{v0:+d}% ward save for the army you select for {turns} turns.'},
         "_skv": {"effects": [("wh2_dlc14_effect_magic_cost_all_lores_percentage", "force_to_force_own", -20)],
                  "text": '{v0:+d}% spell cost for the army you select for {turns} turns.'},
         "": {"effects": [("wh_main_effect_force_stat_physical_resistance", "force_to_force_own", 10)],
              "text": '{v0:+d}% physical resistance for the army you select for {turns} turns.'}}},

    # zeal - after its "text": ... line (no override for _dwf, _ksl, _skv, "" or _gen):
     "for_tag": {
         "_emp": {"effects": [("wh2_dlc14_effect_magic_cost_all_lores_percentage", "force_to_force_own", -20)],
                  "text": '{v0:+d}% spell cost for the army you select for {turns} turns.'},
         "_brt": {"effects": [("wh_main_effect_force_stat_leadership", "force_to_force_own", 10),
                              ("wh_main_effect_force_stat_charge_bonus_pct", "force_to_force_own", 10)],
                  "text": '{v0:+d} leadership and {v1:+d}% charge bonus for the army you select for {turns} turns.'},
         "_cth": {"effects": [("wh3_main_effect_winds_of_magic_events", "force_to_force_own", 8)],
                  "text": '{v0:+d} Winds of Magic power reserve each turn for the army you select for {turns} turns.'},
         "_def": {"effects": [("wh_main_effect_force_stat_melee_attack", "force_to_force_own", 8),
                              ("wh_main_effect_force_stat_weapon_strength", "force_to_force_own", 10)],
                  "text": '{v0:+d} melee attack and {v1:+d}% weapon strength for the army you select for {turns} turns.'},
         "_hef": {"effects": [("wh2_dlc14_effect_magic_cost_all_lores_percentage", "force_to_force_own", -20),
                              ("wh3_main_effect_winds_of_magic_events", "force_to_force_own", 5)],
                  "text": '{v0:+d}% spell cost and {v1:+d} Winds of Magic power reserve each turn for the army you select for {turns} turns.'}}},

    # holy_war - after its "text": ... line (no override for _gen):
     "for_tag": {
         "_emp": {"effects": [("wh3_main_effect_winds_of_magic_events", "faction_to_force_own", 5),
                              ("wh2_dlc14_effect_magic_cost_all_lores_percentage", "faction_to_force_own", -10)],
                  "text": '{v0:+d} Winds of Magic power reserve each turn and {v1:+d}% spell cost in all your armies for {turns} turns.'},
         "_dwf": {"effects": [("wh_main_effect_force_stat_melee_attack", "faction_to_force_own", 4),
                              ("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6)],
                  "text": '{v0:+d} melee attack and {v1:+d} leadership in all your armies for {turns} turns.'},
         "_brt": {"effects": [("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6),
                              ("wh2_dlc14_effect_force_charge_bonus_add", "faction_to_force_own", 10)],
                  "text": '{v0:+d} leadership and {v1:+d} charge bonus in all your armies for {turns} turns.'},
         "_cth": {"effects": [("wh3_main_effect_winds_of_magic_events", "faction_to_force_own", 5),
                              ("wh_main_effect_force_stat_leadership", "faction_to_force_own", 4)],
                  "text": '{v0:+d} Winds of Magic power reserve each turn and {v1:+d} leadership in all your armies for {turns} turns.'},
         "_ksl": {"effects": [("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6),
                              ("wh_main_effect_force_stat_melee_attack", "faction_to_force_own", 4)],
                  "text": '{v0:+d} leadership and {v1:+d} melee attack in all your armies for {turns} turns.'},
         "_def": {"effects": [("wh_main_effect_force_stat_melee_attack", "faction_to_force_own", 4),
                              ("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6)],
                  "text": '{v0:+d} melee attack and {v1:+d} leadership in all your armies for {turns} turns.'},
         "_hef": {"effects": [("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6),
                              ("wh_main_effect_force_stat_magic_resistance", "faction_to_force_own", 10)],
                  "text": '{v0:+d} leadership and {v1:+d}% spell resistance in all your armies for {turns} turns.'},
         "_skv": {"effects": [("wh3_main_effect_winds_of_magic_events", "faction_to_force_own", 5),
                              ("wh_main_effect_character_stat_miscast", "faction_to_force_own", -10)],
                  "text": '{v0:+d} Winds of Magic power reserve each turn and {v1:+d}% miscast chance in all your armies for {turns} turns.'},
         "": {"effects": [("wh3_main_effect_winds_of_magic_events", "faction_to_force_own", 5),
                          ("wh_main_effect_force_stat_leadership", "faction_to_force_own", 6)],
              "text": '{v0:+d} Winds of Magic power reserve each turn and {v1:+d} leadership in all your armies for {turns} turns.'}}},
```

Each row's existing closing `}` becomes the `}` that ends the `for_tag` dict, followed by the row's own `}`.

Check `drawn_in` / `RACE_UNWANTED_EFFECTS`. `_dwf` must not carry `wh3_main_effect_winds_of_magic_events`, and it doesn't. The `""` tag must not carry `wh3_main_effect_corruption_reduction_events`, and it doesn't.

- [ ] **Step 4: The Empire Tithe becomes an Engineers' armour service**

In `spirit_siphon`'s existing `"for_tag": {"_dwf": {...}}`, add a sibling `_emp` entry:

```python
         "_emp": {
             # THE COLLEGES TOOK THE WINDS (2026-10-09 spec §4): the Engineers' Empire slot
             # is armour from the ironworks, not magic.
             "effects": [("wh_main_effect_force_stat_physical_resistance", "faction_to_force_own", 5)],
             "text": '{v0:+d}% physical resistance for all your armies for {turns} turns.'},
```

In `POOL_NAMES["_emp"]`, replace `"The Colleges' Tithe"` with `"Proofed Armour"`.

- [ ] **Step 5: Run the asserts and watch them pass**

Run: `py tools/gen_great_guilds.py --selftest`
Expected: `selftest ok: ...`.

- [ ] **Step 6: Prove the asserts measure**

Temporarily change `zeal._emp`'s `-20` to `-21` and run `--selftest`. Expected: `AssertionError` on `_svc("zeal", "_emp")`. Restore it.

- [ ] **Step 7: `--check` is clean**

Run: `py tools/gen_great_guilds.py --check`
Expected: exit 0, with every new service pair found in vanilla and inside its ceiling.

---

### Task 4: Write, verify, preview, pack and deploy

**Files:**
- Regenerated: `Modding Files/source/great_guilds/*.tsv`, `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` (MCT names block), `zzz_derpy_guilds_bounty_data.lua`
- Pack: `Modding Files/Modpacks/derpy_great_guilds.pack`
- Modify: `docs/SESSION_INDEX.md`, and the spec's `Status:` line

**Interfaces:**
- Consumes: Tasks 1-3.

- [ ] **Step 1: Write the TSVs and run every offline check**

```bash
cd "/g/Modding for resources"
py tools/gen_great_guilds.py --write
py tools/gen_great_guilds.py --check; echo "check exit $?"
py tools/check_effect_signs.py | tail -20
py tools/check_effect_bundle_loc.py; echo "bundle loc exit $?"
"/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua | tail -2
py tools/import_great_guilds.py --check; echo "import check exit $?"
```

Expected:
- `check exit 0`, `bundle loc exit 0`, `harness ok`, `import check exit 0`.
- `check_effect_signs.py` is a review list that always exits 0. Read every `derpy_gg_*temple*` and `spirit_siphon` row it prints. Each negative value (spell cost, miscast) must be a cost or chance effect where negative is the reward.

- [ ] **Step 2: Render the panel for three races and look at the pictures**

```bash
py tools/preview_guilds_panel.py --flavour emp
py tools/preview_guilds_panel.py --flavour dwf
py tools/preview_guilds_panel.py --flavour skv
```

Expected: each run exits 0 and writes its PNGs. Open the temple tab and the Help tab in each set. Check that:
- the temple's rank line reads the new effect (Winds of Magic, spell resistance, Winds of Magic);
- no text overflows its box;
- no line still says "public order" for the temple's rank bonus.

Report what was seen. Exit 0 alone does not count as reviewing the pictures.

- [ ] **Step 3: Pack, with RPFM open**

```bash
curl -s -m 4 http://127.0.0.1:45127/sessions | head -c 120     # must answer; else stop and say RPFM is closed
P="Modding Files/Modpacks/derpy_great_guilds.pack"
W="/f/SteamLibrary/steamapps/workshop/content/1142710/3815248936/derpy_great_guilds.pack"
cmp "$P" "$W" && echo "Modpacks == Workshop"                    # must match before building in place
cp "$P" "Modding Files/Backup/derpy_great_guilds.pack.bak_pre_temple_lore_20261009_$(md5sum "$P" | cut -c1-8)"
py tools/import_great_guilds.py; echo "import exit $?"
```

Expected:
- `Modpacks == Workshop`. If not, stop and diff per file first (memory `always-deploy-to-workshop-folder`).
- `import exit 0`, ending with `saved pack verified - every table holds this build's rows`.

- [ ] **Step 4: Read the new rows back out of the saved pack**

```bash
py tools/read_vanilla_db.py effect_bundles_to_effects_junctions_tables "$P" | grep -E "derpy_gg_rank_temple_5_emp|derpy_gg_seat_temple_emp|derpy_gg_svc_spirit_siphon_emp"
py tools/read_vanilla_db.py building_effects_junction_tables "$P" | grep "derpy_gg_hall_temple_2_emp"
```

Expected:
- `winds_of_magic_pool_cap ... 15` on the rank-5 bundle;
- `magic_cost_all_lores_percentage ... -5` on the seat;
- `physical_resistance ... 5` on `spirit_siphon_emp`;
- `agent_recruitment_xp_wizard_empire ... 3` and the wizard cap on the hall.

Then confirm no file was dropped:

```bash
py -c "import sys; sys.path.insert(0,'tools'); import read_pack_index as r; a=set(r.paths(sys.argv[1])); b=set(r.paths(sys.argv[2])); print(len(a), len(b), sorted(a-b))" "Modding Files/Backup/derpy_great_guilds.pack.bak_pre_temple_lore_20261009_"* "$P"
```

Expected: two equal counts and `[]`.

- [ ] **Step 5: Deploy to the Workshop folder only**

```bash
tasklist | grep -i warhammer3 && echo "GAME RUNNING - stop" || { cp "$P" "$W"; md5sum "$P" "$W" | cut -c1-8; }
ls "/f/SteamLibrary/steamapps/common/Total War WARHAMMER III/data/derpy_great_guilds.pack" 2>&1   # must say No such file
```

Expected: two identical MD5 prefixes, and no `data/` copy.

- [ ] **Step 6: Record**

Append one line to `docs/SESSION_INDEX.md`:

```
- 2026-10-09: **Great Guilds `<md5>` - the temple by its own lore** (spec/plan 2026-10-09-great-guilds-temple-lore): per-race rank/leader/hall/seat effects via `TEMPLE_LORE`, three signature services per race, the Empire Tithe moved off the Engineers (`spirit_siphon` _emp is now "Proofed Armour", physical resistance). Workshop folder only, backup `Backup/derpy_great_guilds.pack.bak_pre_temple_lore_20261009_<old md5>`; NOT uploaded, GitHub not synced. Owed in game: the temple tab, one hall card and the seat bundle for one race, and a mid-campaign save showing the new effects on load.
```

Set the spec's `Status:` line to `implemented in build <md5>, unseen in game`.

- [ ] **Step 7: Ask before going outward**

Tell the author the build is in the Workshop folder, then ask two separate questions:
- whether to upload it, which also carries `f08c99cc`'s sharp-text and feed-only fixes;
- whether to sync GitHub.
