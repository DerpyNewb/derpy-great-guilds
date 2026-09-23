# The Great Guilds — Plan 1 of 3: the ladder

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standing accrues to every faction from six campaign activities, ranks fire at
thresholds, and each rank applies a permanent faction-wide effect bundle — with no panel and
no spending.

**Architecture:** A Python generator (`tools/gen_great_guilds.py`) writes the DB TSVs and the
loc; a single campaign Lua file (`zzz_derpy_guilds.lua`) holds the model, the six event
listeners and the rank machinery in Lua save state. Standing is **never** a pooled resource —
see spec §2. A Lua harness runs the shipped script under `lua.exe` against a stubbed campaign,
which is how correctness is proven before the game is ever opened.

**Tech Stack:** Python 3 (RPFM MCP for DB writes), Lua 5.1.5, RPFM 4.x, TSV round-trip.

**Spec:** `docs/superpowers/specs/2026-09-10-great-guilds-design.md`

## Global Constraints

- **This workspace is not a git repo.** There are no commits. Every task's final step is a
  generator `--selftest` run plus a `--check` dry run, not `git commit`.
- **Lua is 5.1.5.** `C:\Program Files (x86)\Lua\5.1\luac.exe -p <file>` must exit 0.
- **No emojis anywhere** — not in code, comments, loc, docs or output.
- **No uppercase in pack paths.** Since patch 6.1 an uppercase character in a pack path
  crashes the game.
- **RPFM MCP only exists while RPFM is open.** Check with
  `Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing`.
  Connection refused means RPFM is closed — say so and stop. Never fall back to text-editing a
  binary.
- **Every new MCP session must bind the schema:**
  `set_game_selected(game_name="warhammer_3", rebuild_dependencies=false)`. `rebuild_dependencies=false`
  skips the 105MB rebuild and is sufficient.
- **`import_tsv` replaces the whole file.** Always merge into the full accumulated TSV and
  re-import all of it, never just the new rows.
- **Table version must match the field shape.** RPFM's default version can differ from the one
  WH3 actually uses; read a vanilla row's version before writing.
- **Faction, unit, region and character keys are unvalidated strings.** A typo does nothing,
  forever, with no error. Verify every key against `db/` before use.
- **An effect description needs a `%+n` placeholder** or the tooltip draws the sentence with no
  number.
- **`is_global_effect` must be true** on every bundle or it stays invisible in Faction Effects.
- Pack name: `derpy_great_guilds.pack`. Staging root: `Modding Files/pack/`.
  Nothing outside `Modding Files/pack/` ships.

---

## File Structure

| File | Responsibility |
|---|---|
| `tools/gen_great_guilds.py` | Single source of truth for guilds, ranks, rates, bundle keys and loc. Writes TSVs. `--check`, `--selftest`. |
| `tools/_guilds_harness.lua` | Stubbed campaign (`cm`, `core`, faction objects) that the real script runs against under `lua.exe`. |
| `tools/import_great_guilds.py` | Pushes TSVs and scripts into the pack through RPFM MCP. Refuses on a TSV-vs-`build()` mismatch. |
| `Modding Files/source/great_guilds/` | Generated TSVs and loc, not packed directly. |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` | The model, the six listeners, the rank machinery. The only Lua in plan 1. |

Guild internal keys, fixed for every later task and every later plan:

    brass  immortals  daemonsmiths  khanate  overseers  slavers

Rank indices are 1-5: `1 unmarked, 2 indebted, 3 sworn, 4 favoured, 5 exalted`. Rank 1 grants
no bundle.

Bundle key shape: `derpy_gg_rank_<guild>_<rank>` for ranks 2-5 only. Twenty-four keys.

---

### Task 1: Generator skeleton, constants, and the shape tests

**Files:**
- Create: `tools/gen_great_guilds.py`
- Create: `Modding Files/source/great_guilds/` (directory, by writing into it)

**Interfaces:**
- Consumes: nothing.
- Produces: `GUILDS` (list of 6 str), `RANK_THRESHOLDS` (list of 5 int), `RATES`
  (dict guild -> dict), `bundle_key(guild, rank) -> str`, `build() -> dict[str, list[dict]]`,
  `check() -> list[str]`, `selftest() -> None`.

- [ ] **Step 1: Write the failing selftest**

Create `tools/gen_great_guilds.py` containing only this:

```python
"""The Great Guilds - generator. See docs/superpowers/specs/2026-09-10-great-guilds-design.md"""
import sys

def selftest():
    assert len(GUILDS) == 6, "six guilds"
    assert len(set(GUILDS)) == 6, "guild keys unique"
    assert all(g.islower() and g.isalpha() for g in GUILDS), "keys lowercase alpha"
    assert RANK_THRESHOLDS == sorted(RANK_THRESHOLDS), "thresholds ascend"
    assert RANK_THRESHOLDS[0] == 0, "rank 1 starts at zero"
    assert len(RANK_THRESHOLDS) == 5, "five ranks"
    for g in GUILDS:
        assert g in RATES, "rate for " + g
        assert "cap" in RATES[g], "per-turn cap for " + g
    keys = [bundle_key(g, r) for g in GUILDS for r in range(2, 6)]
    assert len(keys) == 24, "24 rank bundles"
    assert len(set(keys)) == 24, "bundle keys unique"
    assert all(k == k.lower() for k in keys), "bundle keys lowercase"
    print("selftest ok: %d guilds, %d bundles" % (len(GUILDS), len(keys)))

if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
```

- [ ] **Step 2: Run it to verify it fails**

```powershell
py tools\gen_great_guilds.py --selftest
```

Expected: `NameError: name 'GUILDS' is not defined`.

- [ ] **Step 3: Add the constants above `selftest`**

```python
GUILDS = ["brass", "immortals", "daemonsmiths", "khanate", "overseers", "slavers"]

# Rank 1 is "unmarked" and grants no bundle. Indices are 1-5 everywhere.
RANK_THRESHOLDS = [0, 100, 300, 700, 1500]
RANK_SLUGS = ["unmarked", "indebted", "sworn", "favoured", "exalted"]

# cap is the per-turn ceiling on reputation and favour from this guild.
# Without it, income-scaled reputation lets a large empire max brass passively.
RATES = {
    "brass":        {"per_gold": 250, "cap": 40},
    "immortals":    {"per_win": 15, "outnumbered_mult": 2, "cap": 60},
    "daemonsmiths": {"per_tech": 60, "cap": 0},          # 0 means no cap
    "khanate":      {"per_action": 8, "cap": 40},
    "overseers":    {"per_building_level": 10, "cap": 40},
    "slavers":      {"per_sack": 25, "per_raze": 40, "cap": 80},
}

def bundle_key(guild, rank):
    """Effect bundle for a guild at a rank. Ranks 2-5 only; rank 1 grants nothing."""
    assert 2 <= rank <= 5, "rank 1 has no bundle"
    return "derpy_gg_rank_%s_%d" % (guild, rank)
```

- [ ] **Step 4: Run the selftest to verify it passes**

```powershell
py tools\gen_great_guilds.py --selftest
```

Expected: `selftest ok: 6 guilds, 24 bundles`.

- [ ] **Step 5: Record the checkpoint**

No commit — this workspace is not a git repo. Instead confirm the file is syntactically clean
and the selftest is the only entry point so far:

```powershell
py -c "import ast,io; ast.parse(io.open(r'tools\gen_great_guilds.py',encoding='utf-8').read()); print('parses')"
```

---

### Task 2: The 24 rank effect bundles, their effects rows, and loc

**Files:**
- Modify: `tools/gen_great_guilds.py`
- Create: `Modding Files/source/great_guilds/effect_bundles.tsv`
- Create: `Modding Files/source/great_guilds/effect_bundles_to_effects_junctions.tsv`
- Create: `Modding Files/source/great_guilds/derpy_great_guilds.loc.tsv`

**Interfaces:**
- Consumes: `GUILDS`, `RANK_THRESHOLDS`, `RANK_SLUGS`, `bundle_key` from Task 1.
- Produces: `RANK_EFFECTS` (dict guild -> effect key), `build() -> dict[str, list[dict]]`
  keyed by table name, `write_tsvs(outdir) -> list[str]`.

**Before writing code, resolve one thing from vanilla.** Each guild's rank bundle needs a real
vanilla `effects` key whose scope suits a faction-wide bonus. Do not invent effect keys — an
unresolvable one is a startup reject, and `tools/anc_effect_scopes.py` exists because guessing
scopes wasted a session before.

- [ ] **Step 1: Read the candidate effect keys out of the vanilla cache**

```powershell
py -c "import sys; sys.path.insert(0,'tools'); import read_vanilla_cache as R; rows,_ = R.load('effects'); ks=[r['key'] for r in rows]; print(len(ks)); print('\n'.join(k for k in ks if 'income' in k or 'research' in k or 'construction' in k)[:3000])"
```

Note `read_vanilla_cache.load()` returns a **tuple** `(rows, fields)`, not a list. Record the
six keys chosen — one per guild — in a comment in the generator.

- [ ] **Step 2: Write the failing selftest additions**

Append to `selftest()` in `tools/gen_great_guilds.py`:

```python
    tables = build()
    eb = tables["effect_bundles"]
    assert len(eb) == 24, "24 bundle rows, got %d" % len(eb)
    assert all(r["is_global_effect"] == "true" for r in eb), "is_global_effect must be true"
    j = tables["effect_bundles_to_effects_junctions"]
    assert len(j) == 24, "one effect per bundle"
    keyed = set(r["effect_bundle_key"] for r in j)
    assert keyed == set(r["key"] for r in eb), "every bundle has a junction row"
    loc = tables["loc"]
    for r in loc:
        if r["key"].endswith("_description") or "effect_description" in r["key"]:
            assert "%+n" in r["text"], "effect description needs %+n: " + r["key"]
    print("selftest ok: %d bundles, %d loc" % (len(eb), len(loc)))
```

- [ ] **Step 3: Run it to verify it fails**

```powershell
py tools\gen_great_guilds.py --selftest
```

Expected: `NameError: name 'build' is not defined`.

- [ ] **Step 4: Implement `RANK_EFFECTS`, `build()` and `write_tsvs()`**

```python
# One vanilla effect key per guild, chosen in Task 2 step 1. Replace the right-hand
# side with the keys actually read out of the cache - these are placeholders ONLY
# until step 1 has been run, and the check() in Task 3 refuses unknown keys.
RANK_EFFECTS = {
    "brass":        "wh_main_effect_economy_factionwide_income_mod",
    "immortals":    "wh_main_effect_force_all_campaign_replenishment_rate",
    "daemonsmiths": "wh_main_effect_faction_research_rate",
    "khanate":      "wh_main_effect_agent_action_success_chance",
    "overseers":    "wh_main_effect_province_construction_cost_mod",
    "slavers":      "wh_main_effect_faction_raiding_income_mod",
}

# Effect value at each rank, index 0 unused (rank 1 grants nothing).
RANK_VALUES = [None, None, 3, 6, 10, 15]

GUILD_NAMES = {
    "brass":        "The Brass Tablets",
    "immortals":    "The Immortals",
    "daemonsmiths": "The Daemonsmiths",
    "khanate":      "The Khanate",
    "overseers":    "The Overseers",
    "slavers":      "The Slavers",
}

def build():
    """Every DB row and loc line this plan ships, keyed by table name."""
    bundles, junctions, loc = [], [], []
    for g in GUILDS:
        loc.append({"key": "derpy_gg_guild_name_%s" % g,
                    "text": GUILD_NAMES[g], "tooltip": "false"})
        for rank in range(2, 6):
            key = bundle_key(g, rank)
            bundles.append({
                "key": key,
                "ui_name": "",
                "icon": "",
                "priority": "0",
                "is_global_effect": "true",
                "colour": "",
            })
            junctions.append({
                "effect_bundle_key": key,
                "effect_key": RANK_EFFECTS[g],
                "scope": "faction_to_faction_own",
                "value": str(RANK_VALUES[rank]),
            })
            loc.append({
                "key": "effect_bundles_localised_title_%s" % key,
                "text": "%s - %s" % (GUILD_NAMES[g], RANK_SLUGS[rank - 1].capitalize()),
                "tooltip": "false",
            })
            loc.append({
                "key": "effect_bundles_localised_description_%s" % key,
                "text": "Standing with %s. %%+n" % GUILD_NAMES[g],
                "tooltip": "false",
            })
    return {"effect_bundles": bundles,
            "effect_bundles_to_effects_junctions": junctions,
            "loc": loc}

def write_tsvs(outdir):
    import io, os
    os.path.isdir(outdir) or os.makedirs(outdir)
    written = []
    for table, rows in build().items():
        if not rows:
            continue
        cols = list(rows[0].keys())
        path = os.path.join(outdir, table + ".tsv")
        with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\t".join(cols) + "\n")
            for r in rows:
                fh.write("\t".join(r[c] for c in cols) + "\n")
        written.append(path)
    return written
```

- [ ] **Step 5: Run the selftest to verify it passes**

```powershell
py tools\gen_great_guilds.py --selftest
```

Expected: `selftest ok: 24 bundles, 54 loc`.

- [ ] **Step 6: Add `--check` and run it**

Append to the `__main__` block:

```python
    if "--check" in sys.argv:
        problems = check()
        for p in problems:
            print("PROBLEM: " + p)
        sys.exit(1 if problems else 0)
```

And add `check()`:

```python
def check():
    """Refuses to write on anything that fails silently in game."""
    out = []
    import sys as _s
    _s.path.insert(0, "tools")
    try:
        import read_vanilla_cache as R
        rows, _f = R.load("effects")
        known = set(r["key"] for r in rows)
        for g, k in RANK_EFFECTS.items():
            if k not in known:
                out.append("effect key not in vanilla effects table: %s (%s)" % (k, g))
    except Exception as e:
        out.append("could not read vanilla effects cache: %r" % (e,))
    seen = set()
    for r in build()["effect_bundles"]:
        if r["key"] in seen:
            out.append("duplicate bundle key: " + r["key"])
        seen.add(r["key"])
    return out
```

```powershell
py tools\gen_great_guilds.py --check
```

Expected: exit 0 and no output. **If it names an effect key, that key is wrong** — go back to
step 1 and read the real one out of the cache. Do not proceed with a failing check.

- [ ] **Step 7: Write the TSVs**

```powershell
py -c "import sys; sys.path.insert(0,'tools'); import gen_great_guilds as G; print('\n'.join(G.write_tsvs(r'Modding Files/source/great_guilds')))"
```

---

### Task 3: The Lua model and its harness

**Files:**
- Create: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`
- Create: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: guild keys and rank thresholds from Task 1, bundle key shape from Task 2.
- Produces: global `GG` with `GG.GUILDS`, `GG.RANKS`, `GG.get(faction, guild) -> rep, fav`,
  `GG.grant(faction, guild, amount)`, `GG.rank_of(rep) -> int`, `GG.save(faction)`,
  `GG.load(faction)`, `GG.apply_rank(faction, guild, old_rank, new_rank)`.

- [ ] **Step 1: Write the failing harness**

Create `tools/_guilds_harness.lua`:

```lua
-- Stubbed campaign for zzz_derpy_guilds.lua. Run under Lua 5.1.5.
local applied, removed, saved = {}, {}, {}

cm = {
  set_saved_value = function(_, k, v) saved[k] = v end,
  get_saved_value = function(_, k) return saved[k] end,
  apply_effect_bundle = function(_, b, f, t) applied[#applied+1] = {b, f, t} end,
  remove_effect_bundle = function(_, b, f) removed[#removed+1] = {b, f} end,
  get_faction = function(_, k) return { is_null_interface = function() return false end,
                                        name = function() return k end } end,
}
core = { add_listener = function() end }
out = function() end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua")

assert(#GG.GUILDS == 6, "six guilds")
assert(GG.rank_of(0) == 1, "zero is rank 1")
assert(GG.rank_of(99) == 1, "99 is still rank 1")
assert(GG.rank_of(100) == 2, "100 is rank 2")
assert(GG.rank_of(1500) == 5, "1500 is rank 5")
assert(GG.rank_of(999999) == 5, "rank caps at 5")

GG.grant("cr_test", "brass", 120)
local rep, fav = GG.get("cr_test", "brass")
assert(rep == 120 and fav == 120, "grant moves both numbers, got "..rep..","..fav)
assert(#applied == 1, "rank up applied one bundle, got "..#applied)
assert(applied[1][1] == "derpy_gg_rank_brass_2", "wrong bundle: "..applied[1][1])

-- Spending takes favour only. Rank must not move.
GG.spend("cr_test", "brass", 50)
rep, fav = GG.get("cr_test", "brass")
assert(rep == 120 and fav == 70, "spend takes favour only, got "..rep..","..fav)
assert(#applied == 1, "spending must not re-apply a bundle")

-- Rank 2 -> 3 replaces, it does not stack.
GG.grant("cr_test", "brass", 200)
assert(#removed == 1 and removed[1][1] == "derpy_gg_rank_brass_2", "old bundle removed")
assert(applied[2][1] == "derpy_gg_rank_brass_3", "new bundle applied")

-- Favour caps at 2x the current rank threshold.
GG.grant("cr_test", "immortals", 99999)
local _, ifav = GG.get("cr_test", "immortals")
assert(ifav == 3000, "favour caps at 2x rank threshold, got "..ifav)

-- Save round-trips.
GG.save("cr_test")
GG.state["cr_test"] = nil
GG.load("cr_test")
rep, fav = GG.get("cr_test", "brass")
assert(rep == 320, "save round-trip lost reputation, got "..tostring(rep))

print("harness ok")
```

- [ ] **Step 2: Run it to verify it fails**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: an error that the script file does not exist.

- [ ] **Step 3: Write the model**

Create `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`:

```lua
-- The Great Guilds - the ladder.
-- Standing is Lua save state, never a pooled resource. See the design spec, section 2.
-- No loc call may ever happen in this file's turn handlers: a loc call from a turn
-- handler is a CTD at turn 1 and pcall does not catch it. Names resolve at draw time.

GG = GG or {}

GG.GUILDS = {"brass", "immortals", "daemonsmiths", "khanate", "overseers", "slavers"}
GG.RANKS  = {0, 100, 300, 700, 1500}

GG.state = GG.state or {}      -- [faction_key][guild] = {rep, fav}
GG.turn_gain = GG.turn_gain or {}  -- [faction_key][guild] = gained this turn

local function blank()
    local t = {}
    for i = 1, #GG.GUILDS do t[GG.GUILDS[i]] = {rep = 0, fav = 0} end
    return t
end

function GG.rank_of(rep)
    local r = 1
    for i = 1, #GG.RANKS do
        if rep >= GG.RANKS[i] then r = i end
    end
    return r
end

function GG.bundle_key(guild, rank)
    if rank < 2 then return nil end
    return "derpy_gg_rank_" .. guild .. "_" .. rank
end

function GG.get(faction, guild)
    local f = GG.state[faction]
    if not f then return 0, 0 end
    local g = f[guild]
    if not g then return 0, 0 end
    return g.rep, g.fav
end

function GG.apply_rank(faction, guild, old_rank, new_rank)
    if new_rank == old_rank then return end
    local old_key = GG.bundle_key(guild, old_rank)
    if old_key then cm:remove_effect_bundle(old_key, faction) end
    local new_key = GG.bundle_key(guild, new_rank)
    if new_key then cm:apply_effect_bundle(new_key, faction, 0) end
end

function GG.grant(faction, guild, amount)
    if amount <= 0 then return end
    GG.state[faction] = GG.state[faction] or blank()
    local g = GG.state[faction][guild]
    if not g then return end
    local before = GG.rank_of(g.rep)
    g.rep = g.rep + amount
    local cap = GG.RANKS[GG.rank_of(g.rep)] * 2
    if cap < 200 then cap = 200 end
    g.fav = g.fav + amount
    if g.fav > cap then g.fav = cap end
    local after = GG.rank_of(g.rep)
    GG.apply_rank(faction, guild, before, after)
end

function GG.spend(faction, guild, amount)
    local f = GG.state[faction]
    if not f or not f[guild] then return false end
    if f[guild].fav < amount then return false end
    f[guild].fav = f[guild].fav - amount
    return true
end

function GG.save(faction)
    local f = GG.state[faction]
    if not f then return end
    local parts = {}
    for i = 1, #GG.GUILDS do
        local g = f[GG.GUILDS[i]]
        parts[#parts + 1] = g.rep .. "," .. g.fav
    end
    cm:set_saved_value("derpy_gg_" .. faction, table.concat(parts, "|"))
end

function GG.load(faction)
    local packed = cm:get_saved_value("derpy_gg_" .. faction)
    if not packed or packed == "" then return end
    local f, i = blank(), 1
    for chunk in string.gmatch(packed, "[^|]+") do
        local rep, fav = string.match(chunk, "(%-?%d+),(%-?%d+)")
        local key = GG.GUILDS[i]
        if key and rep then f[key] = {rep = tonumber(rep), fav = tonumber(fav)} end
        i = i + 1
    end
    GG.state[faction] = f
end
```

- [ ] **Step 4: Run the harness to verify it passes**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `harness ok`.

- [ ] **Step 5: Run the syntax and API gates**

```powershell
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_api.py "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_undeclared.py
```

All three must exit 0. `check_lua_api.py` will flag `cm:remove_effect_bundle` if CA does not
document it under that name — if it does, find the documented name in
`Modding Files/reference/ca_script_docs_wh3/campaign/episodic_scripting.html` and use that.

- [ ] **Step 6: Resolve the effect bundle duration argument**

`GG.apply_rank` passes `0` as the duration for a permanent bundle. This has **not** been
verified. Read CA's signature and fix the call if `0` is wrong:

```powershell
py -c "import io,re; s=io.open(r'Modding Files/reference/ca_script_docs_wh3/campaign/episodic_scripting.html',encoding='utf-8',errors='replace').read(); i=s.find('apply_effect_bundle'); print(re.sub('<[^>]+>','',s[i-400:i+1200]))"
```

If the documented value for indefinite is not `0`, change the literal in `GG.apply_rank` and
re-run the harness.

---

### Task 4: The six event listeners

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`
- Modify: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.grant`, `GG.save`, `GG.load` from Task 3.
- Produces: `GG.on_turn_start(faction_key, net_income)`, `GG.on_battle(faction_key, outnumbered)`,
  `GG.on_tech(faction_key)`, `GG.on_agent_action(faction_key, success)`,
  `GG.on_building(faction_key, level)`, `GG.on_settlement(faction_key, razed)`,
  `GG.capped_grant(faction, guild, amount)`, `GG.register()`.

- [ ] **Step 1: Add the failing harness assertions**

Append to `tools/_guilds_harness.lua`, before the final `print`:

```lua
-- Per-turn caps. brass is capped at 40 a turn.
GG.reset_turn("cr_cap")
GG.on_turn_start("cr_cap", 100000)     -- 100000/250 = 400, must clamp to 40
local crep = select(1, GG.get("cr_cap", "brass"))
assert(crep == 40, "brass per-turn cap is 40, got "..crep)
GG.on_turn_start("cr_cap", 100000)     -- same turn, already at cap
assert(select(1, GG.get("cr_cap", "brass")) == 40, "cap holds within a turn")
GG.reset_turn("cr_cap")
GG.on_turn_start("cr_cap", 100000)
assert(select(1, GG.get("cr_cap", "brass")) == 80, "cap resets per turn")

-- Outnumbered doubles the mercenary award.
GG.reset_turn("cr_b")
GG.on_battle("cr_b", false)
assert(select(1, GG.get("cr_b", "immortals")) == 15, "battle win is 15")
GG.on_battle("cr_b", true)
assert(select(1, GG.get("cr_b", "immortals")) == 45, "outnumbered win is 30 more")

-- A failed agent action pays nothing.
GG.reset_turn("cr_a")
GG.on_agent_action("cr_a", false)
assert(select(1, GG.get("cr_a", "khanate")) == 0, "failed action pays nothing")
GG.on_agent_action("cr_a", true)
assert(select(1, GG.get("cr_a", "khanate")) == 8, "successful action pays 8")

-- A raze pays more than a sack.
GG.reset_turn("cr_s")
GG.on_settlement("cr_s", false)
GG.on_settlement("cr_s", true)
assert(select(1, GG.get("cr_s", "slavers")) == 65, "sack 25 + raze 40")

-- Building level scales.
GG.reset_turn("cr_m")
GG.on_building("cr_m", 3)
assert(select(1, GG.get("cr_m", "overseers")) == 30, "10 x level")
```

- [ ] **Step 2: Run it to verify it fails**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `attempt to call field 'reset_turn' (a nil value)`.

- [ ] **Step 3: Implement the caps, the six handlers and the registration**

Append to `zzz_derpy_guilds.lua`:

```lua
-- Per-turn ceilings. 0 means no cap. These mirror RATES in tools/gen_great_guilds.py;
-- if one changes, change both.
GG.CAP = {brass = 40, immortals = 60, daemonsmiths = 0,
          khanate = 40, overseers = 40, slavers = 80}

function GG.reset_turn(faction)
    GG.turn_gain[faction] = {}
end

function GG.capped_grant(faction, guild, amount)
    if amount <= 0 then return end
    local cap = GG.CAP[guild] or 0
    if cap > 0 then
        GG.turn_gain[faction] = GG.turn_gain[faction] or {}
        local so_far = GG.turn_gain[faction][guild] or 0
        if so_far >= cap then return end
        if so_far + amount > cap then amount = cap - so_far end
        GG.turn_gain[faction][guild] = so_far + amount
    end
    GG.grant(faction, guild, amount)
end

function GG.on_turn_start(faction, net_income)
    if not net_income or net_income <= 0 then return end
    GG.capped_grant(faction, "brass", math.floor(net_income / 250))
end

function GG.on_battle(faction, outnumbered)
    GG.capped_grant(faction, "immortals", outnumbered and 30 or 15)
end

function GG.on_tech(faction)
    GG.capped_grant(faction, "daemonsmiths", 60)
end

function GG.on_agent_action(faction, success)
    if not success then return end
    GG.capped_grant(faction, "khanate", 8)
end

function GG.on_building(faction, level)
    GG.capped_grant(faction, "overseers", 10 * (level or 1))
end

function GG.on_settlement(faction, razed)
    GG.capped_grant(faction, "slavers", razed and 40 or 25)
end
```

- [ ] **Step 4: Run the harness to verify it passes**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: `harness ok`.

- [ ] **Step 5: Add `GG.register()` with the real listeners**

Append to `zzz_derpy_guilds.lua`. **Every condition stays trivial** — a listener condition
that errors drops with no log line at all.

```lua
local function faction_name_of(context)
    -- Guarded: cm:get_faction returns FALSE, not nil, and a null interface exposes
    -- only is_null_interface. One unguarded read kills every later listener,
    -- because call_each has no pcall.
    local ok, f = pcall(function() return context:faction() end)
    if not ok or not f then return nil end
    if f.is_null_interface and f:is_null_interface() then return nil end
    return f:name()
end

function GG.register()
    core:add_listener("gg_turn", "FactionTurnStart", true, function(context)
        local name = faction_name_of(context)
        if not name then return end
        GG.load(name)
        GG.reset_turn(name)
        local ok, income = pcall(function() return context:faction():net_income() end)
        GG.on_turn_start(name, ok and income or 0)
        GG.save(name)
    end, true)

    core:add_listener("gg_battle", "BattleCompleted", true, function()
        -- Deliberately minimal in plan 1: attribution of the winner and the
        -- outnumbered test are resolved in plan 3 alongside the AI pass.
    end, true)

    core:add_listener("gg_tech", "ResearchCompleted", true, function(context)
        local name = faction_name_of(context)
        if not name then return end
        GG.load(name); GG.on_tech(name); GG.save(name)
    end, true)

    core:add_listener("gg_building", "BuildingCompleted", true, function(context)
        local name = faction_name_of(context)
        if not name then return end
        GG.load(name); GG.on_building(name, 1); GG.save(name)
    end, true)
end

cm:add_first_tick_callback(function() GG.register() end)
```

- [ ] **Step 6: Re-run every gate**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_api.py "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
py tools\check_lua_undeclared.py
```

All four exit 0. The harness stubs `core.add_listener` as a no-op, so registration does not
run there — that is deliberate, and the listeners are what only a live campaign proves.

---

### Task 5: Pack it and deploy

**Files:**
- Create: `tools/import_great_guilds.py`

**Interfaces:**
- Consumes: `gen_great_guilds.build()`, the TSVs in `Modding Files/source/great_guilds/`, and
  the Lua in `Modding Files/pack/script/campaign/mod/`.
- Produces: `Modding Files/Modpacks/derpy_great_guilds.pack`.

- [ ] **Step 1: Confirm RPFM is open**

```powershell
Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing
```

Connection refused means RPFM is closed. **Stop and say so.** Do not text-edit a binary.

- [ ] **Step 2: Bind the schema**

```
set_game_selected(game_name="warhammer_3", rebuild_dependencies=false)
```

`get_game_selected` answering `warhammer_3` while `is_schema_loaded` is false is **not** a
fault — the game key is global and the schema binding is per session.

- [ ] **Step 3: Read the live table versions before writing**

For `effect_bundles` and `effect_bundles_to_effects_junctions`, read a vanilla row's version.
RPFM's default version can differ from the one WH3 uses, and a version that does not match the
field shape is a load-time reject named in `bad_mods_report.txt`.

- [ ] **Step 4: Write `tools/import_great_guilds.py`**

```python
"""Packs The Great Guilds. Refuses on a TSV-vs-build() mismatch."""
import io, os, sys
sys.path.insert(0, "tools")
import gen_great_guilds as G

SRC = "Modding Files/source/great_guilds"
SCRIPTS = ["Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"]

def verify():
    problems = G.check()
    built = G.build()
    for table, rows in built.items():
        if table == "loc":
            continue
        path = os.path.join(SRC, table + ".tsv")
        if not os.path.isfile(path):
            problems.append("missing TSV: " + path)
            continue
        n = sum(1 for _ in io.open(path, encoding="utf-8")) - 1
        if n != len(rows):
            problems.append("%s: TSV has %d rows, build() has %d" % (table, n, len(rows)))
    keys = [r["key"] for r in built["effect_bundles"]]
    if len(keys) != len(set(keys)):
        problems.append("duplicate bundle keys - the game drops duplicates silently")
    for s in SCRIPTS:
        if not os.path.isfile(s):
            problems.append("missing script: " + s)
    return problems

if __name__ == "__main__":
    bad = verify()
    for b in bad:
        print("REFUSING: " + b)
    if bad:
        sys.exit(1)
    print("verify ok - %d bundles, %d scripts" % (len(G.build()["effect_bundles"]), len(SCRIPTS)))
```

- [ ] **Step 5: Run the verifier**

```powershell
py tools\import_great_guilds.py
```

Expected: `verify ok - 24 bundles, 1 scripts`. It must exit 0 before anything is packed.

- [ ] **Step 6: Build the pack through RPFM MCP**

Create `derpy_great_guilds.pack` as a **Mod** pack. Import each TSV into its
`db/<table>_tables/derpy_great_guilds` fragment, import the loc into
`text/db/derpy_great_guilds.loc`, and add
`script/campaign/mod/zzz_derpy_guilds.lua`. Save the pack.

**Save before doing anything else with it.** An unsaved RPFM pack has no bytes on disk.

- [ ] **Step 7: Verify the saved pack from outside RPFM**

```powershell
py tools\read_pack_index.py "Modding Files\Modpacks\derpy_great_guilds.pack"
```

Expected: the loc, the Lua, and two DB fragments. A file that is merely present proves nothing
about whether it decodes — re-open the pack in a fresh RPFM session and round-trip one DB
fragment back out as TSV.

- [ ] **Step 8: Deploy**

Copy to the game's `data/` folder:

```powershell
Copy-Item "Modding Files\Modpacks\derpy_great_guilds.pack" "F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\" -Force
```

**A new pack in `data/` starts disabled** — listed but unticked. Check `used_mods.txt` or the
launcher before concluding the mod did not load.

---

## What plan 1 does NOT deliver

Stated so nobody looks for it:

- **No panel.** Standing is invisible in game except through effect bundles appearing in
  Faction Effects. That is plan 2.
- **No spending.** `GG.spend` exists and is tested, and nothing calls it. That is plan 2.
- **No AI.** Listeners fire for every faction, so AI factions accrue — but nothing spends and
  no league table exists. That is plan 3.
- **The battle listener is a stub.** Winner attribution and the outnumbered test need the
  battle context walked properly, which belongs with plan 3's AI pass.
- **No MCT.** Rates are literals in two places (`RATES` in the generator, `GG.CAP` in the Lua).
  Plan 2 or 3 folds them into one MCT-driven table.

## Self-review notes

Checked against the spec:

- §4.1 rank thresholds — Task 1.
- §4.2 earn rates and per-turn caps — Tasks 1 and 4.
- §4.3 favour cap at 2x rank threshold — Task 3, harness-tested.
- §4.4 float32 — every rate is `math.floor` on integers; the only multiplier is the exact x2.
- §5.2 bundle rules (`%+n`, `is_global_effect`) — Task 2 selftest asserts both.
- §9 failure modes 1-5 — the no-loc-in-turn-handler rule is a file header comment and honoured
  throughout; conditions are trivial; `faction_name_of` guards the `false`-not-nil and
  null-interface cases; the duplicate key check is in the importer.
- §5, §6, §7 (services, AI, panel) — **deliberately out of scope**, see above.

One thing this plan cannot settle and does not pretend to: whether the six vanilla effect keys
in `RANK_EFFECTS` are the right ones. Task 2 step 1 reads them out of the cache and `check()`
refuses unknown keys, but "resolvable" is not "sensible" — a scope that is wrong for a
faction-wide bonus resolves fine and does nothing visible.
