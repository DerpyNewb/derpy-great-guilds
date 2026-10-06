# Great Guilds Halls, Stage 2 (the other seven races) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Empire, Dwarfs, Bretonnia, Grand Cathay, Kislev, Dark Elves and High Elves the same guild halls the Chaos Dwarfs got in stage 1: 18 levels per race, 144 in all.

**Architecture:**
- Stage 1 built the halls generically over the flavour tag, in both the generator (`hall_tables()` loops `HALL_TAGS`) and the Lua (`GG.hall_key(guild, n, tag)`).
- Stage 2 is mostly data: seven `HALL_RACES` entries, seven tags in `HALL_TAGS`, and 42 icons.
- It also fixes the stage-1 code that only worked because there was one race:
  - the roster check that `endswith("")` matched everywhere;
  - the per-race instance key;
  - a donor rule that does not exist yet;
  - the DLC rule that `check_halls()` never enforced.

**Tech Stack:** Python 3 (`py`), generator `tools/gen_great_guilds.py`; Lua 5.1.5 at `C:\Program Files (x86)\Lua\5.1\`; RPFM MCP for the pack step.

**Spec:** `docs/superpowers/specs/2026-10-04-great-guilds-halls-design.md`. Stage 1's results and rulings are in `docs/sessions/HANDOFF_20261004_GUILDS_HALLS_STAGE1.md`.

## Global Constraints

- **Keys.**
  - All keys are lowercase (the 6.1 rule).
  - `<tag>` is one of `""`, `_emp`, `_dwf`, `_brt`, `_cth`, `_ksl`, `_def`, `_hef`.
  - Chain keys are `derpy_gg_hall_<guild><tag>`, level keys `derpy_gg_hall_<guild>_<n><tag>` and Seat keys `derpy_gg_seat_<guild><tag>`.
  - Every key that names a vanilla row is verified against the installed `db.pack` through `live_rows()`, never typed from memory.
- **Level nouns (spec §2):**

  | Tag | Level 0 | Level 1 | Level 2 |
  |---|---|---|---|
  | `_emp` | Guildhouse | Guildhall | Grand Guildhall |
  | `_dwf` | Lodge | Hall | Great Hall |
  | `_brt` | Chapterhouse | Commandery | Grand Commandery |
  | `_cth` | Pavilion | Hall | Palace |
  | `_ksl` | Lodge | Hall | Great Hall |
  | `_def` | Lodge | Hall | Tower |
  | `_hef` | Lodge | Hall | Tower |

- **Units:** spec §8.2's table, verbatim. Every DLC pick also lists its base-game fallback from `HALL_FALLBACK`.
- **Effects:** the same six effects and values for every race (spec §8.1, `HALL_EFFECT`). The Seat follows `HALL_SEAT_SCOPE` and `seat_value()`.
- **Player text:**
  - Plain words: "Reputation", never "standing".
  - None of the words cap, rep, accrue, AI, HUD or rung.
  - No emojis.
  - No fixed Reputation numbers (the presets change them).
  - Guild names take "their".
- **Files and tools:**
  - The UI Lua and both harnesses are CRLF; the model Lua is LF.
  - No `sed -i`. No Bash heredocs for code.
  - Never pass `--help` or an unknown flag to any `tools/*.py`. `import_great_guilds.py` builds on an unknown flag.
- **Game Lua:**
  - Numbers are float32.
  - In big functions, no number literal on the LEFT of an arithmetic operator.
  - No init or plain arguments to `string.find`.
  - New harness blocks go in IIFEs.
- **Off limits:**
  - Do not edit `tools/gen_guilds_ui.py`, or any Iron Court or Zharr Exchange file.
  - Do not rename existing loc keys; a peer session reads the dwf guild keys.
- **Art:** CA-derived icons ship in the pack only and never reach a public repo.

## Review Focus

1. **A conquered settlement already holding another race's hall.** It must not take a second hall, and the new owner must not count or be paid for the foreign one. Task 1 pins the shared instance key; Task 3 has a harness case.
2. **A player who does not own a hall unit's DLC.** The base-game fallback must sit on the same hall level or later, and never earlier than vanilla gives it. Task 1 adds the DLC rule to `check_halls()`, with a `--selftest` break.
3. **An AI faction of a hall race in a campaign where the player is a different hall race** (an Empire AI in a Chaos Dwarf game). All 18 of its levels must be shut. Task 3 has a harness case.
4. **Two humans of different hall races in multiplayer.** Each must be locked and paid by its own race's keys. Task 3 has a harness case.
5. **Every race's player text.**
   - Help page 7 must fit in 21 lines for all eight.
   - The "Halls n" header must fit for all eight.
   - Every hall name, description and tooltip must read with the right article and noun.

   Task 2 covers the loc check and Task 3 the preview.

---

### Task 1: Make the hall code multi-race (no new race yet)

**Files:**
- Modify: `tools/gen_great_guilds.py`. This touches the HALLS block (`HALL_RACES`, `hall_tables()`, `hall_desc()`), `check_halls()` and `selftest()`.

**Interfaces:**
- Consumes: stage 1's `HALL_*`, `hall_tables()`, `_unit_level()`, `_unit_row()`, `_cai_donor()`, `live_rows()`, `FLAVOURS[tag]["culture"]`.
- Produces:
  - `HALL_INSTANCE = "derpy_gg_hall"`;
  - `_hall_donor(tag) -> str`, the donor chain key, printed in `--check`;
  - `hall_tag_of(level_key) -> str`;
  - `unit_products(unit) -> set[str]`;
  - `race_products(tag) -> set[str]`;
  - `unit_name(unit) -> str`;
  - `HALL_RACES[tag]` keys reduced to `{"set", "nouns", "units"}` plus an optional `"donor"`. `culture` is read from `FLAVOURS`, and `unit_names` from vanilla loc.

- [ ] **Step 1: One instance key for every race.** This is the spec §1 rule, one guild hall per settlement, ever. A conquered city must not hold two halls.

```python
HALL_INSTANCE = "derpy_gg_hall"   # every hall level of every race names this key; capped at 1
```

In `hall_tables()`:
- Set `building_instance_key=HALL_INSTANCE` on every level, replacing `sc`.
- Emit ONE `building_instances` row, `{"key": HALL_INSTANCE, "num_instances": "1"}`, outside the tag loop.
- Delete the per-superchain and per-chain instances rows. Stage 1's ledger lists them as dead.

Replace the `check_halls()` superchain test with:

```python
    inst = [r for r in ht["building_instances"] if r["key"] == HALL_INSTANCE]
    if len(inst) != 1 or inst[0]["num_instances"] != "1":
        out.append("%s is not one row capped at 1 - two halls could share a settlement"
                   % HALL_INSTANCE)
    for r in ht["building_levels"]:
        if r["building_instance_key"] != HALL_INSTANCE:
            out.append("%s names instance key %r, not %s - it escapes the one-per-settlement cap"
                       % (r["level_name"], r["building_instance_key"], HALL_INSTANCE))
```

Drop `"building_instances"` from the per-chain loop in `check_halls()`, because chains no longer have rows.

`check_halls` reads `building_instances` rows as they are. Do not touch `tools/import_great_guilds.py` in this task; Task 4 verifies the pack.

- [ ] **Step 2: Make the roster check tag-aware.** Stage 1's `r["building"].endswith(tag)` is true for every key when `tag == ""`. Add:

```python
def hall_tag_of(level_key):
    """The flavour tag a hall level key ends in ('' for the Chaos Dwarfs)."""
    for t in sorted(HALL_RACES, key=len, reverse=True):
        if t and level_key.endswith(t):
            return t
    return ""
```

In `check_halls()`, replace `if r["building"].endswith(tag) and ...` with `if hall_tag_of(r["building"]) == tag and ...`.

- [ ] **Step 3: The DLC rule (spec §8.2).** Read the three ownership tables through `live_rows()`. Confirm each exists in `db.pack` first (`py tools\read_vanilla_db.py`; read its docstring).

```python
def unit_products(unit):
    """Products that grant `unit`; empty = base content. Several requirement sets on one
    pack mean any one product will do."""
    packs = {r["content_pack"] for r in live_rows("main_unit_ownership_content_pack_junctions")
             if r["unit"] == unit}
    sets = {r["requirement_set"] for r in live_rows("ownership_content_pack_requirements")
            if r["content_pack"] in packs}
    return {r["product"] for r in live_rows("ownership_content_pack_required_products")
            if r["requirement_set"] in sets}


def race_products(tag):
    """The products a player of this race necessarily owns: those of its base roster,
    read as the products every one of its vanilla generic infantry needs."""
```

Before writing these, read the three tables' real column names and fix the field names in the snippet to match.

For `race_products`, choose the simplest definition the data supports, and say which in the report. For example: the products of the race's own lord, or of a unit in its starting army. The Chaos Dwarf result must be `{"TW_WH3_CHAOS_DWARFS"}`, or include it.

In `check_halls()`, for each tag in `HALL_TAGS` and each guild:
- if the unit's products are not a subset of `race_products(tag)`, the unit MUST have a `HALL_FALLBACK` entry;
- the fallback's products must be a subset of `race_products(tag)`;
- the fallback must be on the race's roster (the Step 2 roster).

- [ ] **Step 4: Place each unit at its own first level.** In `hall_tables()`, place the fallback at its OWN `_unit_level(fallback, R["set"])`, not at the DLC unit's level, so that neither comes earlier than vanilla. Both use `HALL_XP[n]`.

- [ ] **Step 5: Unit names from vanilla loc.** Do not hand-type unit names.

```python
def unit_name(unit):
    """The unit's on-screen name from CA's own loc: main_units.land_unit -> land_units_onscreen_name_*."""
```

- Use `tools/read_vanilla_loc.py`; read its docstring for the call. It reads `text/db/*.loc` with RPFM shut.
- Raise if the name is missing.
- Delete `HALL_RACES[""]["unit_names"]`.
- `hall_desc()` calls `unit_name()`. When a unit has a fallback, the text reads: "Trains Huntsmen, or Crossbowmen without the pack that adds Huntsmen."
- The Chaos Dwarf descriptions must come out the same as before. The selftest asserts this against the six stage-1 strings, captured before the edit.

- [ ] **Step 6: The donor rule (spec §3.2).**

```python
def _hall_donor(tag):
    """The chain whose rows a race's halls clone: HALL_RACES[tag]["donor"] when named (the
    Chaos Dwarfs: wh3_dlc23_chd_military_kdaai), else by rule - a chain in the race's
    availability set, in wh3_main_secondary_core_generic_minor, with a
    building_set_to_building_junctions row and at least three levels; ties to the key."""
```

- The CHD donor stays `wh3_dlc23_chd_military_kdaai`. Stage 1 rows must not change.
- `--check` prints one line per tag: `hall donor <tag>: <chain> (panel set <set>)`.
- `hall_tables()` reads `d_var` as the donor's level-0 variant whose `culture` column equals `FLAVOURS[tag]["culture"]` or is empty, raising if there is none. Read the column names first.

- [ ] **Step 7: Self-test each rule broken once.** Add to `selftest()`; each line must fail before its rule exists:
  - an instance key changed on one level is reported;
  - the per-race roster check is applied to an `_emp` level's row (use a monkeypatched `HALL_TAGS` and `HALL_RACES` holding one `_emp` entry from Task 2's data, or a synthetic one);
  - a DLC unit with its fallback removed is reported;
  - `hall_tag_of("derpy_gg_hall_brass_0_emp") == "_emp"` and `hall_tag_of("derpy_gg_hall_brass_0") == ""`;
  - the six CHD descriptions are unchanged.

Run: `py tools\gen_great_guilds.py --selftest`. Expected: `selftest ok: ...`.

Run: `py tools\gen_great_guilds.py --check`. Expected: exit 0, printing `hall donor : wh3_dlc23_chd_military_kdaai ...`.

Then `--write` regenerates the TSVs. Diff `building_instances.tsv`: it should hold one hall row instead of seven. Diff `building_levels.tsv`: the instance key is unchanged for the CHD levels, which already named `derpy_gg_hall`.

- [ ] **Step 8: Gates.**
  - Run both harnesses.
  - Run `py tools\mutate_guilds.py --selftest`, which must report 190 anchored.
  - Run `py tools\import_great_guilds.py --check`.

---

### Task 2: The seven races' data, icons and the Lua mirror

**Files:**
- Modify: `tools/gen_great_guilds.py`: `HALL_TAGS`, `HALL_RACES`, `HALL_ICON`.
- Modify: `tools/make_guild_icons.py`: `HALL_ICONS`.
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`: `GG.HALL_TAGS` (LF).
- Regenerate: the TSVs in `Modding Files/source/great_guilds/`.

**Interfaces:**
- Consumes: Task 1's `_hall_donor`, `unit_products`, `race_products`, `unit_name`, `hall_tag_of`, `HALL_INSTANCE`.
- Produces: `HALL_TAGS = ["", "_emp", "_dwf", "_brt", "_cth", "_ksl", "_def", "_hef"]`, `GG.HALL_TAGS` with the same eight, and `HALL_ICON[(guild, tag)]`.

- [ ] **Step 1: `HALL_RACES` for the seven tags.** Use the sets from spec §3.2, the nouns from Global Constraints, and the units from spec §8.2, all verbatim. `"donor"` is omitted (by rule).

| Tag | Set |
|---|---|
| `_emp` | `wh_main_bas_emp` |
| `_dwf` | `wh_main_bas_dwf` |
| `_brt` | `wh_main_bas_brt` |
| `_cth` | `wh3_main_bas_cth` |
| `_ksl` | `wh3_main_bas_ksl` |
| `_def` | `wh2_main_bas_def` |
| `_hef` | `wh2_main_bas_hef` |

Verify each set key against `live_rows("building_chain_availability_sets")` first.

- [ ] **Step 2: Icons, one per guild per race (spec §8.3).**
- `HALL_ICON` becomes keyed `(guild, tag)`, with stem `"derpy_gg_hall_%s%s" % (guild, tag)`.
- The CHD stems are unchanged, because the tag is empty.
- In `tools/make_guild_icons.py`, extend `HALL_ICONS` with one CA source stem per new `(guild, tag)`. Choose each from that race's own CA building icons, the same way the stage-1 CHD six were chosen (read the comment at its `HALL_ICONS`).
- Where the race's guild card already uses a CA building silhouette, use the same stem, so the card and the hall read as one trade.
- Every source must exist in CA's ui packs. The tool fetches it offline, so read its docstring.
- Update its selftest count from 6 to 48.
- Run `py tools\make_guild_icons.py`, then `--check`.

- [ ] **Step 3: Extend `HALL_TAGS` in both mirrors.**
  - Generator: `HALL_TAGS = ["", "_emp", "_dwf", "_brt", "_cth", "_ksl", "_def", "_hef"]`.
  - Lua: `GG.HALL_TAGS = {[""] = true, ["_emp"] = true, ["_dwf"] = true, ["_brt"] = true, ["_cth"] = true, ["_ksl"] = true, ["_def"] = true, ["_hef"] = true}`.

- [ ] **Step 4: Check.** Run `py tools\gen_great_guilds.py --check`. Expected: exit 0, with eight `hall donor` lines and eight sets of six `hall AI donor` lines.

  If `_cai_donor` raises for a race, make the narrowest fix to its rule (a fallback order, never a hand-typed key). Record it in the report, and print why.

- [ ] **Step 5: Read the player text.** Print every new hall loc row. One way: `py -c "import sys; sys.path.insert(0,'tools'); import gen_great_guilds as G; [print(r['key'], '|', r['text']) for r in G.hall_tables()['loc']]"`. Read all of it, about 280 rows. Check:
  - each name is "<noun> of <guild with article>";
  - each tooltip uses that race's rank names;
  - every description names a real unit;
  - the plain-words rules hold.

  List any line that reads wrong, and fix it at its source.

- [ ] **Step 6: Write.**
  - Run `py tools\gen_great_guilds.py --write`.
  - The row counts must be: `building_levels` 144, `building_chains` 48, `building_superchains` 8, `building_instances` 1 hall row, `building_upgrades_junction` 96, `building_culture_variants` 144, `building_chain_set_items` 96, `building_set_to_building_junctions` 48, `building_chain_availability_sets` 48, `cai_construction_system_building_values` 48, and 48 Seat bundles.
  - Report the counts.

- [ ] **Step 7: Gates.**
  - `gen --check` and `--selftest`;
  - both harnesses;
  - `mutate_guilds.py --selftest`;
  - `import_great_guilds.py --check`;
  - `make_guild_icons.py --check`.

---

### Task 3: Every race in the script, the panel and the mutants

**Files:**
- Modify: `tools/_guilds_harness.lua` (CRLF).
- Modify: `tools/mutate_guilds.py`.
- Modify only where a race-specific gap shows: `zzz_derpy_guilds.lua` (LF), `zzz_derpy_guilds_ui.lua` (CRLF).
- Run: `tools/preview_guilds_panel.py`.

**Interfaces:**
- Consumes: `GG.HALL_TAGS` (8), `GG.hall_key`, `GG.hall_culture`, `GG.halls_here`, `GG.count_halls`, `GG.lock_halls`, `GG.assert_seat`, `GG.seat_key`.
- Produces: harness coverage for non-CHD races, and the new mutants.

- [ ] **Step 1: Harness block for a second race.** Add an IIFE that resets `GG.halls`, `GG.halls_locked`, `GG.halls_swept` and `GG.seat_on` first.
  - **An Empire faction covered, at Indebted with brass.** `lock_halls` shuts `derpy_gg_hall_brass_1_emp` and `_2_emp` with tooltip keys `derpy_gg_hall_tip_1_brass_emp` and `derpy_gg_hall_tip_lead_brass_emp`, and opens `_0_emp`. Assert on the recorded `cm:add/remove_event_restricted_building_record_for_faction` calls.
  - **Counting.** A stubbed region offers ONLY `building_exists` and answers true for `derpy_gg_hall_brass_0_emp`. `GG.count_halls` gives `brass.n == 1`.
    - The same region answering for the CHD key `derpy_gg_hall_brass_0` gives 0 for the Empire faction. This is Review Focus 1: a foreign race's hall does not count.
  - **Seat.** An Empire leader of brass with an `_2_emp` hall gets `derpy_gg_seat_brass_emp` applied.
  - **Review Focus 3.** An uncovered Empire AI, in a world where the covered culture is the Chaos Dwarfs, gets all 18 `_emp` levels shut.
  - **Review Focus 4.** With two covered cultures (stub `GG.covered` true for both, or whatever the existing MP helpers in the harness offer), a CHD faction and an Empire faction each get their own race's keys locked, and neither gets the other's.

Watch each assertion fail first: temporarily drop the tag from `GG.hall_key` in the shipped Lua, run, see red, restore, run green.

- [ ] **Step 2: Mutants.** Append to `MUTANTS` in `tools/mutate_guilds.py`. Aim the anchors at the shipped text; each must anchor once.

```python
    ("hall keys built without the race tag", M,
     b'function GG.hall_key(guild, n, tag) return "derpy_gg_hall_" .. guild .. "_" .. n .. (tag or "") end',
     b'function GG.hall_key(guild, n, tag) return "derpy_gg_hall_" .. guild .. "_" .. n end'),
    ("seat bundle key without the race tag", M,
     b'function GG.seat_key(guild, tag) return "derpy_gg_seat_" .. guild .. (tag or "") end',
     b'function GG.seat_key(guild, tag) return "derpy_gg_seat_" .. guild end'),
```

- Run `py tools\mutate_guilds.py --selftest`. Expected: `selftest ok: 192 mutants anchored`.
- Then run the full `py tools\mutate_guilds.py`. Every mutant must be caught. On a survivor, add the missing assertion to Step 1's block; never delete the mutant.

- [ ] **Step 3: Panel for all eight races.**
  - Run the harness with `GG_DUMP` set, then `py tools\preview_guilds_panel.py --check`. Expected: exit 0, with no OVER or LOW CONTRAST on `gg_rank_stats` for any flavour. Read the docstring for how `--flavour` selects a race.
  - Render the Help page 7 for at least `--flavour emp`, `dwf` and `cth` (`--help-page 7`), and Read each PNG.
  - Check that Help page 7's text uses that race's nouns and fits.
  - Run `check_help_pages()` through `gen --check`. It enforces the 21-line limit for every flavour.
  - Confirm the promotion line for every race names that race's level-0 and level-1 nouns. The `--check`'s `check_promotion_text` covers it; read its output.

- [ ] **Step 4: Gates.**
  - `gen --check`, `--selftest`;
  - both harnesses;
  - the full `mutate_guilds.py`;
  - `check_guilds_ui.py`;
  - `gen_guilds_ui.py --check`;
  - `preview_guilds_panel.py --check`;
  - `check_lua_literal_left.py`;
  - `check_lua_undeclared.py`;
  - `luac -p` on the four scripts.

  `check_lua_api.py` has one known unrelated finding, `ai_test_tower_of_zharr.lua:35`.

---

### Task 4: Pack, verify, deploy, handoff

**Files:**
- Write: `docs/sessions/HANDOFF_20261004_GUILDS_HALLS_STAGE2.md`, and one line in `docs/SESSION_INDEX.md`.

- [ ] **Step 1:** Run `py tools\import_great_guilds.py --check`. Expected: every TSV matches `build()`.
- [ ] **Step 2: Pack.**
  - Check RPFM is open: `Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing`. If it is closed, stop and report BLOCKED.
  - Back up the `data/` pack to `Modding Files/Backup/guilds_pre_halls_stage2_20261004/`.
  - Check duplicate keys against vanilla and within the pack.
  - Run `py tools\import_great_guilds.py`.
  - Re-open the saved pack and count every hall table's rows against `build()`.
  - List the pack's paths with `py tools\read_pack_index.py`. All 48 hall icons must be present, and every path lowercase.
- [ ] **Step 3: Deploy.** If `Warhammer3.exe` is not running, copy the pack to `data/` and compare MD5s. There is no Workshop copy.
- [ ] **Step 4: Effect tools.** Run `py tools\check_effect_signs.py` and `py tools\check_effect_bundle_loc.py` on the built pack. All 48 Seat bundles must carry loc.
- [ ] **Step 5: Handoff.** Write it in the shape of the stage-1 handoff:
  - built;
  - verified, and how;
  - corrections;
  - do-not-re-derive;
  - OPEN.

  OPEN holds:
  - stage 1's eight in-game checks, still unrun;
  - spec §10.8 (DLC hiding) per race, with the seven DLC units named;
  - one in-game check per new race: a hall of one guild builds, names, recruits and pays;
  - the deferred minors carried from stage 1;
  - every new one.

  Add one line to `docs/SESSION_INDEX.md` and update the stage-1 line to say it was superseded by stage 2.
