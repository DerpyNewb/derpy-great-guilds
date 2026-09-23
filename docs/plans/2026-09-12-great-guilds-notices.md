# The Great Guilds — Notices and the Opener Badge: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the mod tell the player when something good happens, so the loop it already
has stops being invisible for the first fifteen turns of a campaign.

**Architecture:** One new event-feed record (index 5004) carries every positive
announcement; which announcement it is comes from the loc keys passed at the call site, the
same shape the leadership record already uses. `GG.grant` is the single choke point every
accrual route passes through and it already computes the rank before and after, so all three
notices hook there behind a cheap early return. The HUD opener gains a text block and a
count of what the player could act on right now.

**Tech Stack:** Lua 5.1.5 (game scripts), Python 3 generators, RPFM MCP for packing, the
project's own `tools/_guilds_harness.lua` for tests.

**Spec:** `docs/superpowers/specs/2026-09-10-great-guilds-design.md`

The spec does not cover notices — it predates them. This plan implements items 1-3 of the
2026-09-12 status review, recorded in the Great Guilds line of `docs/SESSION_INDEX.md`. The
diagnosis it argues from: all three of the mod's existing feed records carry **bad news**
(a rival's hostile service, a demand or its expiry, a guild lost), and `GG.apply_rank`
swaps a permanent effect bundle in silence. The mod interrupts the player only to take.

## Global Constraints

Copied from `CLAUDE.md` and the workspace's memory. Every task's requirements include these.

- **Binary — never edit as text:** `db/<table>_tables/<file>`, `text/db/*.loc`, `.pack`,
  `.dds`, `.anim`, `.anm.meta`, `.snd.meta`, `.xlsx`. RPFM is the only way in.
- **The RPFM MCP server only exists while RPFM is open.** Probe
  `http://127.0.0.1:45127/sessions` first. Connection refused means RPFM is closed — say so
  and stop, never fall back to text-editing a binary.
- **No loc calls from turn handlers.** A `common.get_localised_string` from a turn handler
  is a CTD at turn 1 and `pcall` does not catch it. `cm:show_message_event` takes loc KEYS,
  which is why it is safe; resolving a name to interpolate into one is not.
- **No emojis anywhere** — code, comments, docs, patch notes or replies.
- **No uppercase in pack paths** since patch 6.1.
- **`import_tsv` replaces the whole file** — always re-import the full accumulated TSV.
- **Keys fail silently.** Faction, unit, region and character keys are unvalidated strings.
- **This workspace is not a git repo.** There are no commits. Each task ends by running the
  gates listed in its final step; that is this project's equivalent.
- **Do not edit `tools/gen_exchange_ui.py`.** The Guilds use `tools/gen_guilds_emitter.py`,
  a deliberate copy, never an import.
- Game install: `F:\SteamLibrary\steamapps\common\Total War WARHAMMER III`.

---

## File Structure

| File | Responsibility in this plan |
|---|---|
| `tools/gen_great_guilds.py` | The fourth feed record (group, index 5004, row, all four tables) and every new loc row. Two new build-time checks. |
| `tools/gen_guilds_ui.py` | The opener component gains a text block so a count can be written onto it. |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` | `GG.FEED_INDEX_RANK`, `GG.announce_rank`, `GG.notice_once`, and their three call sites inside `GG.grant`. |
| `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` | `GGUI.actionable` and `GGUI.badge` — counting what the player could do now, and writing it onto the opener. |
| `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` | One checkbox, `guild_notices`, defaulting on. |
| `tools/_guilds_harness.lua` | Tests for all of the above. |

Nothing new is created. Four existing files gain code, one gains an option, one gains tests.

**Why one feed record and not three.** A record is presentation — icon, sound, layout. The
text is loc keys passed at the call site. The leadership record already proves this: one
record, twelve pairs of keys. Three new records would be three identical rows.

---

## Task 1: The rank-up announcement

Ranking up unlocks a service and applies a permanent faction-wide effect bundle. The player
is currently told nothing. This is the single highest-value gap in the mod.

**Files:**
- Modify: `tools/gen_great_guilds.py` — near line 300 (constants), line 1093 (`build()`),
  line 1295 (`check_feed_mirror`)
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` — line 154
  (`GG.grant`), and a new block beside `GG.announce_lead` at line 1810
- Modify: `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` — beside
  `o_hostile` at line 45
- Test: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.grant(faction, guild, amount)`, `GG.rank_of(rep)`,
  `GG.apply_rank(faction, guild, old_rank, new_rank)`, `GG.setting(key)`,
  `cm:get_human_factions()`, `cm:show_message_event(faction, title, primary, secondary,
  persistent, index)` — all already present.
- Produces:
  - `GG.FEED_INDEX_RANK` — number, 5004.
  - `GG.announce_rank(faction, guild, old_rank, new_rank)` — returns nothing. Silent unless
    `new_rank > old_rank`, `new_rank >= 2`, `faction` is a human faction, and the
    `guild_notices` setting is on.

    **RANKS ARE 1-BASED AND RANK 1 IS UNMARKED.** `GG.RANKS = {0, 100, 300, 700, 1500}`,
    `GG.rank_of` returns 1..5, `GG.bundle_key` returns nil below 2 and the Python
    `bundle_key` asserts `2 <= rank <= 5`. Every rank number in this plan is that
    numbering: 2 = Indebted, 3 = Sworn, 4 = Favoured, 5 = Exalted. `RANK_NAMES` in Python
    is 0-indexed, so the name for rank `r` is `RANK_NAMES[r - 1]`.
  - Python: `FEED_GROUP_RANK`, `FEED_INDEX_RANK`, `FEED_ROW_RANK`.
  - 72 loc keys shaped
    `message_event_text_text_derpy_gg_rank_<guild>_<rank>_{title,primary,secondary}`
    where `<rank>` is 2..5.

- [ ] **Step 1: Add the failing harness test**

Open `tools/_guilds_harness.lua` and find the line:

```lua
-- ----------------------------------------------- every signal has a listener --
```

Insert this block immediately **before** it:

```lua
-- ------------------------------------------------ the good news, at last --
-- All three of this mod's feed records carried bad news: a rival's hostile service, a
-- demand or its expiry, and a guild lost. GG.apply_rank swapped a permanent effect bundle
-- and said nothing, so the single most positive moment in the design - a rank that unlocks
-- a service and grants a faction-wide bundle - happened in silence.

local RHUMAN, RAI = "cr_rank_me", "cr_rank_ai"
cm.get_human_factions = function() return {RHUMAN} end
GG.state = {}
GG.state[RHUMAN] = {}
GG.state[RAI] = {}
for i = 1, #GG.GUILDS do
    GG.state[RHUMAN][GG.GUILDS[i]] = {rep = 0, fav = 0}
    GG.state[RAI][GG.GUILDS[i]] = {rep = 0, fav = 0}
end

local fmark = #feed
GG.announce_rank(RHUMAN, "brass", 1, 2)
assert(#feed == fmark + 1, "a promotion must reach the player's feed")
assert(feed[#feed][1] == RHUMAN,
       "addressed to the player, got " .. tostring(feed[#feed][1]))
assert(feed[#feed][3] == GG.FEED_INDEX_RANK,
       "on the rank record's index, got " .. tostring(feed[#feed][3]))
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_rank_brass_2_title",
       "naming the guild AND the rank reached - rank 2 is Indebted, because GG.RANKS is "
       .. "1-based and rank 1 is Unmarked, got " .. tostring(feed[#feed][2]))

-- A JUMP OF TWO RANKS ANNOUNCES THE RANK REACHED, not the one passed through. A single
-- large grant - a sacked capital, a finished technology - can cross two thresholds.
fmark = #feed
GG.announce_rank(RHUMAN, "slavers", 2, 4)
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_rank_slavers_4_title",
       "a two-rank jump announces the rank REACHED, got " .. tostring(feed[#feed][2]))

-- DEMOTIONS ARE SILENT. Rivalry and an expired demand both take reputation back, so
-- new_rank < old_rank is reachable - and this mod already has three records' worth of bad
-- news. The panel shows the loss; the feed does not need to.
fmark = #feed
GG.announce_rank(RHUMAN, "brass", 4, 2)
assert(#feed == fmark, "a demotion must not be announced")
GG.announce_rank(RHUMAN, "brass", 3, 3)
assert(#feed == fmark, "an unchanged rank must not be announced")

-- UNMARKED IS NOT A RANK REACHED. rank 0 is where everyone starts; announcing it would
-- fire six times on the first turn of every campaign.
GG.announce_rank(RHUMAN, "brass", 0, 1)
assert(#feed == fmark,
       "reaching rank 1 is reaching UNMARKED, where every faction already starts - "
       .. "announcing it would fire six times on turn 1 of every campaign")

-- AND NOT FOR THE AI. GG.grant runs for every faction in the world - about 190 of them in
-- Immortal Empires - so without this the player would be told about every rival's every
-- promotion, several times a round.
GG.announce_rank(RAI, "brass", 1, 2)
assert(#feed == fmark, "an AI faction's promotion is not an interrupt for the player")

-- THE MCT SWITCH MUST ACTUALLY GATE IT. Five of this mod's settings assertions have
-- previously passed while guarding nothing.
local real_setting = GG.setting
GG.setting = function(k)
    if k == "guild_notices" then return false end
    return real_setting(k)
end
GG.announce_rank(RHUMAN, "immortals", 1, 2)
assert(#feed == fmark, "guild_notices off must silence the announcement")
GG.setting = real_setting
GG.announce_rank(RHUMAN, "immortals", 1, 2)
assert(#feed > fmark, "and on must restore it")

-- IT MUST FIRE FROM GG.grant, not only when called directly. Every accrual route in the
-- mod goes through that one function; a notice wired anywhere else covers one route.
fmark = #feed
GG.state[RHUMAN]["overseers"].rep = 0
GG.grant(RHUMAN, "overseers", 150)
assert(#feed > fmark,
       "crossing a threshold through GG.grant must announce - that is the only path the "
       .. "six earning listeners take")
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_rank_overseers_2_title",
       "and it must name the guild granted to, got " .. tostring(feed[#feed][2]))

-- A GRANT THAT CROSSES NOTHING IS SILENT. GG.grant is the hottest function in the mod.
fmark = #feed
GG.grant(RHUMAN, "overseers", 5)
assert(#feed == fmark, "a grant that crosses no threshold must say nothing")

cm.get_human_factions = function() return {} end

```

- [ ] **Step 2: Run the harness and watch it fail**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: FAIL — `attempt to call field 'announce_rank' (a nil value)`.

- [ ] **Step 3: Mint the fourth feed record in the generator**

In `tools/gen_great_guilds.py`, immediately after the `FEED_GROUP_LEAD` / `FEED_INDEX_LEAD`
block (around line 300), add:

```python
# A FOURTH RECORD, and the first one that is good news. The three above are a rival's
# hostile service, a demand or its expiry, and a guild lost - so until now this mod
# interrupted the player only to take something, while the one moment worth interrupting
# for (a rank that unlocks a service and applies a permanent faction bundle) passed in
# silence inside GG.apply_rank.
#
# One record carries every positive notice. A record is presentation - icon, sound,
# layout; the text is loc keys passed at the call site, which is why the leadership
# record above serves twelve different messages from one row.
FEED_GROUP_RANK = "derpy_gg_event_feed_rank"
FEED_INDEX_RANK = 5004
```

Then, beside `FEED_ROW_DEMAND` / `FEED_ROW_LEAD`, add:

```python
FEED_ROW_RANK = dict(FEED_ROW, group=FEED_GROUP_RANK,
                     # The only column that differs from the three above. The other
                     # records use CA's neutral popup; a promotion is the one thing in
                     # this mod worth a positive sound.
                     sound_event="UI_CAM_POPUP_Message_Event_Positive")
```

- [ ] **Step 4: Wire the record into all four tables**

In `build()` (around line 1093), extend each of the four feed lists. The four must stay the
same length — `check()` refuses the build otherwise, and the chain check walks them by
index:

```python
            "campaign_groups": [{"id": FEED_GROUP}, {"id": FEED_GROUP_DEMAND},
                                {"id": FEED_GROUP_LEAD}, {"id": FEED_GROUP_RANK}],
            "campaign_group_members": [{"group": FEED_GROUP, "id": FEED_GROUP,
                                        "priority": "0"},
                                       {"group": FEED_GROUP_DEMAND,
                                        "id": FEED_GROUP_DEMAND, "priority": "0"},
                                       {"group": FEED_GROUP_LEAD,
                                        "id": FEED_GROUP_LEAD, "priority": "0"},
                                       {"group": FEED_GROUP_RANK,
                                        "id": FEED_GROUP_RANK, "priority": "0"}],
            "campaign_group_member_criteria_values":
                [{"member": FEED_GROUP, "value": str(FEED_INDEX)},
                 {"member": FEED_GROUP_DEMAND, "value": str(FEED_INDEX_DEMAND)},
                 {"member": FEED_GROUP_LEAD, "value": str(FEED_INDEX_LEAD)},
                 {"member": FEED_GROUP_RANK, "value": str(FEED_INDEX_RANK)}],
            "event_feed_message_events": [dict(FEED_ROW), dict(FEED_ROW_DEMAND),
                                          dict(FEED_ROW_LEAD), dict(FEED_ROW_RANK)],
```

- [ ] **Step 5: Generate the 72 loc rows**

In the same file, immediately after the leadership loc loop that ends with the
`lead_lost_%s_secondary` append (around line 1028), add:

```python
    # THE PROMOTION TEXT. One key set per guild per rank, 72 rows, for the same reason the
    # leadership set is 36: cm:show_message_event takes loc KEYS and there is nowhere to
    # interpolate a guild name or a rank name into one. Rank 0 (Unmarked) is where everyone
    # starts and is never announced.
    # range(2, 6), matching bundle_key's own `assert 2 <= rank <= 5`. Ranks are 1-based
    # and rank 1 is Unmarked; RANK_NAMES is a 0-indexed Python list, so the name for
    # rank r is RANK_NAMES[r - 1].
    for _g in GUILDS:
        _full, _short = GUILD_NAMES[_g], short_name(_g)
        for _r in range(2, len(RANK_NAMES) + 1):
            _rank = RANK_NAMES[_r - 1]
            _stem = "message_event_text_text_derpy_gg_rank_%s_%d" % (_g, _r)
            loc.append({"key": _stem + "_title",
                        "text": "%s Name You %s" % (_short, _rank),
                        "tooltip": "false"})
            loc.append({"key": _stem + "_primary",
                        "text": "Your standing with %s has risen to %s. Their grant to "
                                "you has grown, and a service that was closed to you is "
                                "open." % (_full, _rank),
                        "tooltip": "false"})
            loc.append({"key": _stem + "_secondary",
                        "text": "Favour is spent on the Guilds tab.",
                        "tooltip": "false"})
```

- [ ] **Step 6: Extend `check_feed_mirror` to cover the new index and keys**

A wrong index and a missing loc key both make `cm:show_message_event` log that it showed a
message and draw absolutely nothing. In `check_feed_mirror` (around line 1295), change the
index tuple to include the fourth:

```python
    for lua_name, mine in (("GG.FEED_INDEX", FEED_INDEX),
                           ("GG.FEED_INDEX_DEMAND", FEED_INDEX_DEMAND),
                           ("GG.FEED_INDEX_LEAD", FEED_INDEX_LEAD),
                           ("GG.FEED_INDEX_RANK", FEED_INDEX_RANK)):
```

and, after the leadership key loop and before `return out`, add:

```python
    # The promotion keys are built by concatenation in GG.announce_rank, so no literal-key
    # scan reaches them either.
    for g in GUILDS:
        for r in range(2, len(RANK_NAMES) + 1):
            for part in ("title", "primary", "secondary"):
                k = "message_event_text_text_derpy_gg_rank_%s_%d_%s" % (g, r, part)
                if k not in shipped:
                    out.append("GG.announce_rank builds %s and no loc row ships it, so "
                               "that promotion draws nothing" % k)
```

- [ ] **Step 7: Run the generator check**

```powershell
py tools\gen_great_guilds.py --check
```

Expected: findings naming `GG.FEED_INDEX_RANK` — "the Lua never declares GG.FEED_INDEX_RANK,
so that feed record is unreachable" — because the Lua half does not exist yet. That is the
check working.

- [ ] **Step 8: Write the Lua half**

In `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua`, after the
`GG.announce_lead` function (it ends around line 1832), add:

```lua
-- 5004, the fourth feed index and the first that carries good news. Minted by
-- tools/gen_great_guilds.py alongside the four rows that resolve it; check_feed_mirror
-- there pins this number against the one in the DB.
GG.FEED_INDEX_RANK = 5004

-- A PROMOTION. Called from GG.grant, which runs from six different turn handlers for
-- every faction in the world - so loc KEYS only, never a resolved name, and the cheap
-- tests come first.
--
-- 72 key sets rather than one generic pair: cm:show_message_event takes keys and there is
-- nowhere to interpolate the guild or the rank into one. The same reason announce_lead
-- above ships 36.
function GG.announce_rank(faction, guild, old_rank, new_rank)
    -- FIRST, AND IN THIS ORDER. GG.grant is the hottest function in the mod - every
    -- accrual route on every faction passes through it - and the overwhelming majority of
    -- calls cross no threshold at all. Nothing below this line runs on those.
    if not new_rank or not old_rank then return end
    if new_rank <= old_rank then return end
    -- RANK 1 IS UNMARKED, where every faction already starts - announcing it would fire
    -- six times on the first turn of every campaign. GG.RANKS is {0, 100, 300, 700, 1500}
    -- and GG.rank_of returns 1..5, which is why this reads 2 and not 1; GG.bundle_key uses
    -- the same boundary. Demotions fall out at the line above: rivalry and an expired
    -- demand both take reputation back, and this mod already has three records' worth of
    -- bad news.
    if new_rank < 2 then return end
    if not GG.is_guild(guild) then return end
    if GG.setting then
        local v = GG.setting("guild_notices")
        if v ~= nil and not v then return end
    end
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    for i = 1, #humans do
        if humans[i] == faction then
            local k = "message_event_text_text_derpy_gg_rank_"
                      .. guild .. "_" .. new_rank
            pcall(function()
                cm:show_message_event(faction, k .. "_title", k .. "_primary",
                                      -- true, not false: the record is a
                                      -- scripted_persistent_event and the flag has to
                                      -- agree with it or nothing draws.
                                      k .. "_secondary", true, GG.FEED_INDEX_RANK)
            end)
            return
        end
    end
end
```

- [ ] **Step 9: Call it from the one place every accrual passes**

In `GG.grant` (line 154), change the `GG.apply_rank` line so the announcement follows it:

```lua
    GG.apply_rank(faction, guild, before, after)
    -- AFTER apply_rank, so the bundle the message promises is already on the faction when
    -- the player clicks through to look. Before rival_cost, which can only subtract and
    -- therefore cannot promote anyone.
    GG.announce_rank(faction, guild, before, after)
```

- [ ] **Step 10: Add the MCT switch**

In `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua`, beside `o_hostile`
(line 45), add:

```lua
local o_notices = m:add_new_option("guild_notices", "checkbox")
o_notices:set_default_value(true)
o_notices:set_text("Guild notices")
o_notices:set_tooltip_text("Announce a rank gained, and the first time a guild takes "
                           .. "notice of you, on the event feed. Bad news - demands, a "
                           .. "guild lost, a rival's service landing on you - is always "
                           .. "announced and is not covered by this switch.")
```

`tools/import_great_guilds.py` refuses to pack if an MCT option is not read by name in a
script in the pack. Step 8 reads it, so this is satisfied — but the check is quoted and
whole, so the string must be exactly `"guild_notices"` on both sides.

- [ ] **Step 11: Run the harness and the generator check, both green**

```powershell
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
py tools\gen_great_guilds.py --check
```

Expected: `harness ok`, and `gen_great_guilds.py --check` exit 0.

- [ ] **Step 12: Fault-inject the new guards and watch each one fire**

A guard that has never been seen to fail is not a guard. Run these one at a time, confirm
the finding, then undo:

```powershell
py - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("g", "tools/gen_great_guilds.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("clean:", m.check_feed_mirror() or "no findings")
keep = m.FEED_INDEX_RANK
m.FEED_INDEX_RANK = 5009
print("index drift ->", [f for f in m.check_feed_mirror() if "RANK" in f][:1])
m.FEED_INDEX_RANK = keep
PY
```

Expected: the clean run reports no findings; the drifted run reports
`GG.FEED_INDEX_RANK is 5004 in the Lua and 5009 here`.

Then drop one loc row by hand — delete the `_secondary` append inside the promotion loop —
re-run `py tools\gen_great_guilds.py --check`, confirm it names the missing key, and put it
back.

- [ ] **Step 13: Regenerate the TSVs and run the whole gate**

`import_great_guilds.py` refuses to pack on a TSV-vs-`build()` row mismatch, and four feed
TSVs just gained a row each.

```powershell
py tools\gen_great_guilds.py --write
py tools\check_lua_api.py
py tools\check_lua_undeclared.py
py tools\import_great_guilds.py --check
```

Expected: all four exit 0, and `--check` prints `verify ok` with the loc count risen by 72.

---

## Task 2: The opener badge

The HUD opener is a 44x44 button with a crest on it and nothing else. It never says that
anything has happened, so there is no reason to click it.

**Files:**
- Modify: `tools/gen_guilds_ui.py` — `_opener()` at line 491
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` — new functions
  beside the opener block at line 1310, and a call in the existing `gg_opener_place`
  listener at line 1520
- Test: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.can_buy(faction, key)`, `GG.SERVICES`, `GG.bounties`, `GG.demands`,
  `GG.demand_payable(faction)`, `GGUI.BTN` (the string `"gg_opener"`), the file-local
  `comp(name)` and `set_text(c, text)` helpers — all already present.
- Produces:
  - `GGUI.actionable(faction)` — returns a number: how many distinct things the player
    could do in the panel right now.
  - `GGUI.badge(faction)` — writes that count onto the opener, or clears it at zero.
    Returns the count so a test can read it without a UI.

- [ ] **Step 1: Add the failing harness test**

In `tools/_guilds_harness.lua`, immediately after the block added in Task 1 and still before
`-- ----------------------------------------------- every signal has a listener --`, add:

```lua
-- ------------------------------------------------------ a reason to click --
-- The opener carried a crest and nothing else. A player who does not already know the mod
-- exists has no signal that the panel is ever worth opening, which is the whole problem
-- during the first fifteen turns when nothing is affordable yet.

local BHUMAN = "cr_badge_me"
GG.state = {}
GG.state[BHUMAN] = {}
for i = 1, #GG.GUILDS do
    GG.state[BHUMAN][GG.GUILDS[i]] = {rep = 0, fav = 0}
end
GG.bounties = {}
GG.demands = {}

assert(GGUI.actionable(BHUMAN) == 0,
       "a faction with no standing, no bounty and no demand can do nothing, got "
       .. tostring(GGUI.actionable(BHUMAN)))

-- AN AFFORDABLE, UNLOCKED SERVICE COUNTS. Reputation drives the rank that unlocks it and
-- favour is what pays; both have to be there, which is why this sets both.
GG.state[BHUMAN]["brass"].rep = 150
GG.state[BHUMAN]["brass"].fav = 150
local n = GGUI.actionable(BHUMAN)
assert(n >= 1, "an affordable unlocked service must count, got " .. tostring(n))

-- A SERVICE THE RANK DOES NOT REACH DOES NOT COUNT, however much favour is held. A badge
-- that counts things the player cannot buy sends them to a panel of greyed buttons, which
-- is worse than no badge.
GG.state[BHUMAN]["immortals"].rep = 0
GG.state[BHUMAN]["immortals"].fav = 9999
assert(GGUI.actionable(BHUMAN) == n,
       "favour without the rank must not count - can_buy is the gate, not the price")

-- A BOUNTY OFFER COUNTS. It is a decision waiting on the board with a life of six turns.
GG.bounties[BHUMAN] = {{guild = "brass", kind = "region_take", target = "wh3_main_x",
                        expires = 99}}
assert(GGUI.actionable(BHUMAN) == n + 1,
       "an offer on the board must count, got " .. tostring(GGUI.actionable(BHUMAN)))

-- AND A DEMAND THAT CAN BE PAID. One that cannot is not an action, it is a countdown.
GG.demands[BHUMAN] = {guild = "brass", kind = "tribute", amount = 1500, due = 99}
local with_demand = GGUI.actionable(BHUMAN)
assert(with_demand == n + 2,
       "a payable demand must count, got " .. tostring(with_demand))

-- THE BADGE RETURNS WHAT IT WROTE. There is no UI in the harness, so this is how the
-- count is checked without one - and the caller must not crash when the component is
-- absent, which is exactly the state on every turn before the opener is placed.
assert(GGUI.badge(BHUMAN) == with_demand,
       "badge must return the count it drew, got " .. tostring(GGUI.badge(BHUMAN)))
GG.bounties[BHUMAN] = nil
GG.demands[BHUMAN] = nil
```

- [ ] **Step 2: Run the harness and watch it fail**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: FAIL — `attempt to call field 'actionable' (a nil value)`.

- [ ] **Step 3: Give the opener a text block**

In `tools/gen_guilds_ui.py`, replace `_opener()` (line 491) with:

```python
def _opener():
    root = EU.C("root", OPENER_W, OPENER_H)
    # TEXT ON THE BUTTON ITSELF, not a separate badge component. A child would need its own
    # .twui.xml file, its own GUID range and its own placement call; the count is one or two
    # characters and the component is already here. Bottom-right, so it sits on the plate's
    # rim rather than over the crest, which is docked Center at 30x30 inside 44x44.
    #
    # EU._state emits component_text on EVERY state, so the number does not vanish on
    # hover. Writing it is SetText (all states), never SetStateText (current state only) -
    # that distinction is what made the Buy caption disappear on mouseover once already.
    root.add(EU.C("gg_opener", OPENER_W, OPENER_H, interactive=True,
                  sound=OPENER_SOUND, layers=OPENER_LAYERS, hover=OPENER_HOVER,
                  text=True, size=12, align="Right", valign="Bottom",
                  fontcat="header_14", leading=0,
                  # CA's gold. A count is a call to action, not body copy.
                  colour="#FFD37AFF",
                  tx="-4.00,0.00", ty="-2.00,0.00"))
    return root
```

- [ ] **Step 4: Regenerate the UI and confirm the text block landed**

```powershell
py tools\gen_guilds_ui.py --check
py tools\gen_guilds_ui.py --selftest
py tools\gen_guilds_ui.py --write
```

Then confirm the opener now carries text on both states:

```powershell
Select-String -Path "Modding Files\pack\ui\campaign ui\derpy_gg_opener.twui.xml" -Pattern "component_text" | Measure-Object | Select-Object -ExpandProperty Count
```

Expected: `2` — one for `standard`, one for `hover`. A `1` means the hover state lost its
text block and the number will vanish under the mouse.

- [ ] **Step 5: Write the counter**

In `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua`, in the opener section
(after `GGUI.BTN_SIZE` at line 1339), add:

```lua
-- WHAT THE PLAYER COULD DO RIGHT NOW. Three things count, and they are the three the panel
-- has a button for: a service they can actually buy, a bounty offer sitting on the board,
-- and a demand they can pay.
--
-- NO LOC IN HERE. This is called from a turn handler.
--
-- can_buy is the gate rather than the price, deliberately. A count that included services
-- the rank does not reach would send the player to a panel of greyed buttons, which is a
-- worse signal than no badge at all.
function GGUI.actionable(faction)
    if not faction or not GG.state or not GG.state[faction] then return 0 end
    local n = 0
    for i = 1, #GG.SERVICES do
        local ok, can = pcall(function()
            return GG.can_buy(faction, GG.SERVICES[i].key)
        end)
        if ok and can then n = n + 1 end
    end
    local offers = GG.bounties and GG.bounties[faction]
    if offers then n = n + #offers end
    if GG.demands and GG.demands[faction] then
        local ok, payable = pcall(function() return GG.demand_payable(faction) end)
        if ok and payable then n = n + 1 end
    end
    return n
end

-- WRITES IT, AND RETURNS IT. The return is not decoration: the harness has no UI, so the
-- number it drew is the only thing a test can read.
--
-- An empty string at zero, not "0". A badge that always shows something stops being a
-- signal - and during the first fifteen turns of a campaign zero is the honest answer.
function GGUI.badge(faction)
    local n = GGUI.actionable(faction)
    -- comp() returns nil until place_opener has run, which is every turn before the
    -- button exists. That is not a fault and must not be treated as one.
    local c = comp(GGUI.BTN)
    if c then set_text(c, n > 0 and tostring(n) or "") end
    return n
end
```

- [ ] **Step 6: Refresh it once a round**

The opener already re-places itself on every faction turn start. Extend that listener (line
1520) so the badge is refreshed at the same time:

```lua
core:add_listener("gg_opener_place", "FactionTurnStart", true, function()
    GGUI.place_opener(1)
    -- SAME LISTENER, deliberately. This fires once per faction - about 190 times a round -
    -- and both calls are idempotent and cheap: place_opener stops itself once btn_at is
    -- set, and the badge is eighteen can_buy calls against a table already in memory.
    -- Splitting them into a second listener would double the registrations for nothing.
    pcall(function()
        local me = cm:get_local_faction_name(true)
        if me then GGUI.badge(me) end
    end)
end, true)
```

- [ ] **Step 7: Refresh it after a purchase too**

Buying a service spends favour and may take the count to zero. Find `GGUI.refresh()` and add
as its last line, inside the existing function body:

```lua
    -- The count changes the moment favour is spent, and the panel is open when that
    -- happens - so the badge must not wait for the next turn to catch up.
    pcall(function()
        local me = cm:get_local_faction_name(true)
        if me then GGUI.badge(me) end
    end)
```

- [ ] **Step 8: Run every gate**

```powershell
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds_ui.lua"
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
py tools\check_lua_api.py
py tools\check_lua_undeclared.py
py tools\gen_guilds_ui.py --check
```

Expected: all exit 0, `harness ok`. `check_lua_undeclared.py` is known to report
`BUTTON`, `BUTTON_GAP` and `BUTTON_SIZE` in this file — those are pre-existing, verified
false positives (guarded cross-mod reads of the form `(EX and EX.BUTTON_SIZE) or 48`). Any
*new* name in its output is a real finding.

- [ ] **Step 9: Fault-inject the badge's one silent failure**

The badge's worst failure is counting services the player cannot buy — it looks like it
works and sends the player to a wall of greyed buttons. Prove the test catches it: in
`GGUI.actionable`, temporarily change the service loop's condition to count every service
unconditionally, run the harness, and confirm it fails on "favour without the rank must not
count". Then restore it.

---

## Task 3: The first fifteen turns

A player who reaches Indebted around turn 15 gets Task 1's message. Before that the mod is
silent, and there is no intro — it never announces itself at all, so a player who does not
notice a 44x44 button never finds it. Two one-time notices give the opening three beats:
first contact, halfway, Indebted.

**Files:**
- Modify: `tools/gen_great_guilds.py` — the loc block added in Task 1
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` — beside
  `GG.announce_rank`, and one more call in `GG.grant`
- Test: `tools/_guilds_harness.lua`

**Interfaces:**
- Consumes: `GG.FEED_INDEX_RANK` and the human/setting guards from Task 1;
  `cm:set_saved_value(key, value)` / `cm:get_saved_value(key)`; `GG.RANKS`.
- Produces:
  - `GG.notice_once(faction, tag, guild)` — fires the notice keyed
    `message_event_text_text_derpy_gg_notice_<tag>_<guild>_{title,primary,secondary}` at
    most once per campaign per tag, recorded in the save under
    `derpy_gg_notice_<tag>_<faction>`. Returns `true` if it fired.
  - Two tags: `"first"` and `"half"`.
  - 36 loc keys: 2 tags x 6 guilds x 3 parts.

- [ ] **Step 1: Add the failing harness test**

In `tools/_guilds_harness.lua`, after Task 2's block and still before
`-- ----------------------------------------------- every signal has a listener --`, add:

```lua
-- ----------------------------------------------- the first fifteen turns --
-- The first rank lands somewhere near turn 15 in focused play, and until then the panel
-- reads "Reputation 0 / 100" with three greyed cards and nothing has ever spoken. The mod
-- also never announced itself at all, so a player who did not notice a 44x44 button on the
-- HUD never found it. Two one-time notices give the opening three beats: first contact,
-- halfway, and Indebted.

local NHUMAN, NAI = "cr_notice_me", "cr_notice_ai"
cm.get_human_factions = function() return {NHUMAN} end
GG.state = {}
GG.state[NHUMAN] = {}
GG.state[NAI] = {}
for i = 1, #GG.GUILDS do
    GG.state[NHUMAN][GG.GUILDS[i]] = {rep = 0, fav = 0}
    GG.state[NAI][GG.GUILDS[i]] = {rep = 0, fav = 0}
end

local fmark = #feed
assert(GG.notice_once(NHUMAN, "first", "brass") == true,
       "the first notice must fire")
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_notice_first_brass_title",
       "naming the guild that noticed you, got " .. tostring(feed[#feed][2]))
assert(feed[#feed][3] == GG.FEED_INDEX_RANK,
       "on the same record as a promotion - both are good news, and a record is "
       .. "presentation, not text")

-- ONCE PER CAMPAIGN, NOT ONCE PER SESSION. The flag lives in the SAVE, because a flag held
-- only in memory means the message fires again on every load - and a load happens far more
-- often than a first accrual.
fmark = #feed
assert(GG.notice_once(NHUMAN, "first", "brass") == false,
       "it must not fire a second time")
assert(GG.notice_once(NHUMAN, "first", "slavers") == false,
       "and not for a different guild either - it is one notice per campaign, not one "
       .. "per guild")
assert(#feed == fmark, "so nothing more reaches the feed")

-- A DIFFERENT TAG IS A DIFFERENT NOTICE and has its own flag.
assert(GG.notice_once(NHUMAN, "half", "immortals") == true,
       "the halfway notice is its own one-time message")
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_notice_half_immortals_title",
       "got " .. tostring(feed[#feed][2]))

-- AI FACTIONS NEVER FIRE ONE. GG.grant runs for every faction in the world.
fmark = #feed
assert(GG.notice_once(NAI, "first", "brass") == false,
       "an AI faction has nobody to tell")
assert(#feed == fmark, "and must reach no feed")

-- IT MUST FIRE FROM GG.grant. The first accrual is the moment to say the mod exists, and
-- GG.grant is the only place that knows an accrual happened.
local GHUMAN = "cr_notice_grant"
cm.get_human_factions = function() return {GHUMAN} end
GG.state[GHUMAN] = {}
for i = 1, #GG.GUILDS do
    GG.state[GHUMAN][GG.GUILDS[i]] = {rep = 0, fav = 0}
end
fmark = #feed
GG.grant(GHUMAN, "khanate", 8)
assert(#feed == fmark + 1,
       "the very first accrual must announce the mod, got " .. (#feed - fmark)
       .. " messages")
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_notice_first_khanate_title",
       "got " .. tostring(feed[#feed][2]))

-- HALFWAY TO THE FIRST RANK. GG.RANKS[2] is the Indebted threshold; half of it is the
-- beat between "something is happening" and "a service is open".
fmark = #feed
GG.grant(GHUMAN, "khanate", math.floor(GG.RANKS[2] / 2))
assert(#feed == fmark + 1,
       "crossing halfway to the first rank must announce once, got " .. (#feed - fmark))
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_notice_half_khanate_title",
       "got " .. tostring(feed[#feed][2]))

-- AND NOT AGAIN ON THE WAY PAST. Reputation keeps climbing through the threshold every
-- turn after; without the saved flag this is a message every single turn.
fmark = #feed
GG.grant(GHUMAN, "khanate", 5)
GG.grant(GHUMAN, "khanate", 5)
assert(#feed == fmark, "the halfway notice must not repeat")

cm.get_human_factions = function() return {} end
```

- [ ] **Step 2: Run the harness and watch it fail**

```powershell
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
```

Expected: FAIL — `attempt to call field 'notice_once' (a nil value)`.

- [ ] **Step 3: Generate the 36 notice loc rows**

In `tools/gen_great_guilds.py`, immediately after the promotion loc loop added in Task 1,
add:

```python
    # THE TWO ONE-TIME NOTICES. First contact and halfway to the first rank, per guild
    # because the guild is the thing with flavour and the thing that tells the player where
    # to look. Both fire at most once per campaign, not once per guild - the guild in the
    # key is whichever one happened to trigger it.
    _NOTICE = {
        "first": ("%s Have Noticed You",
                  "Word of your doings has reached %s. They keep a ledger of every power "
                  "in the world, and your name is now in it. Standing with them is earned "
                  "by playing as you already play; what it buys is on the Guilds panel.",
                  "The crest on your HUD opens it."),
        "half": ("%s Are Watching Closely",
                 "You are halfway to a standing %s will act on. At Indebted they open "
                 "their first service to you.",
                 "The Guilds panel shows how far every guild has come."),
    }
    for _tag in ("first", "half"):
        _title, _primary, _secondary = _NOTICE[_tag]
        for _g in GUILDS:
            _full, _short = GUILD_NAMES[_g], short_name(_g)
            _stem = "message_event_text_text_derpy_gg_notice_%s_%s" % (_tag, _g)
            loc.append({"key": _stem + "_title", "text": _title % _short,
                        "tooltip": "false"})
            loc.append({"key": _stem + "_primary", "text": _primary % _full,
                        "tooltip": "false"})
            loc.append({"key": _stem + "_secondary", "text": _secondary,
                        "tooltip": "false"})
```

- [ ] **Step 4: Extend `check_feed_mirror` to cover them**

These keys are concatenated in Lua too, so no literal-key scan reaches them. In
`check_feed_mirror`, after the promotion key loop added in Task 1, add:

```python
    for tag in ("first", "half"):
        for g in GUILDS:
            for part in ("title", "primary", "secondary"):
                k = "message_event_text_text_derpy_gg_notice_%s_%s_%s" % (tag, g, part)
                if k not in shipped:
                    out.append("GG.notice_once builds %s and no loc row ships it, so that "
                               "notice draws nothing" % k)
```

- [ ] **Step 5: Write `GG.notice_once`**

In `zzz_derpy_guilds.lua`, after `GG.announce_rank`, add:

```lua
-- A ONE-TIME NOTICE, on the same feed record as a promotion: both are good news, and a
-- record is presentation - icon, sound, layout - while the text is the keys passed here.
--
-- THE FLAG LIVES IN THE SAVE. A flag held only in memory fires the message again on every
-- load, and a player loads far more often than they first meet a guild. cm:set_saved_value
-- is the same mechanism GG.save_patron and GG.save_demand already use.
--
-- Returns true only when it actually fired, so a caller can tell "already seen" from
-- "not eligible" and a test can read it without a UI.
function GG.notice_once(faction, tag, guild)
    if not faction or not tag or not GG.is_guild(guild) then return false end
    if GG.setting then
        local v = GG.setting("guild_notices")
        if v ~= nil and not v then return false end
    end
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return false end
    local mine = false
    for i = 1, #humans do
        if humans[i] == faction then mine = true break end
    end
    if not mine then return false end
    local flag = "derpy_gg_notice_" .. tag .. "_" .. faction
    local seen = cm:get_saved_value(flag)
    -- "" and nil both mean unseen. get_saved_value answers nil for a key never written and
    -- "" for one written empty, and only "1" means it has fired.
    if seen == "1" then return false end
    cm:set_saved_value(flag, "1")
    local k = "message_event_text_text_derpy_gg_notice_" .. tag .. "_" .. guild
    pcall(function()
        cm:show_message_event(faction, k .. "_title", k .. "_primary",
                              k .. "_secondary", true, GG.FEED_INDEX_RANK)
    end)
    return true
end
```

- [ ] **Step 6: Call both notices from `GG.grant`**

In `GG.grant`, after the `GG.announce_rank` line added in Task 1, add:

```lua
    -- THE OPENING. Both are one-time and both are cheap to skip: notice_once returns on a
    -- saved flag before it touches anything else, and the halfway test is one comparison.
    --
    -- `before` is the rank BEFORE this grant, so the halfway notice cannot fire for a
    -- faction that is already past the first rank - which is what stops it appearing at
    -- turn 40 for the fifth guild a large empire happens to start earning with.
    GG.notice_once(faction, "first", guild)
    -- before < 2 is "below Indebted": ranks are 1-based and rank 1 is Unmarked.
    if before < 2 then
        local half = GG.RANKS[2] / 2
        if g.rep >= half and (g.rep - amount) < half then
            GG.notice_once(faction, "half", guild)
        end
    end
```

- [ ] **Step 7: Run every gate**

```powershell
& "C:\Program Files (x86)\Lua\5.1\luac.exe" -p "Modding Files\pack\script\campaign\mod\zzz_derpy_guilds.lua"
& "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
py tools\gen_great_guilds.py --check
py tools\check_lua_api.py
py tools\check_lua_undeclared.py
```

Expected: all exit 0, `harness ok`.

- [ ] **Step 8: Fault-inject the saved flag**

The failure that matters is the one the save hides: a flag in memory rather than in the
save, which looks correct for a whole session and then fires on every load forever. Prove
the test catches it — replace the `cm:get_saved_value` / `cm:set_saved_value` pair with a
Lua table local to the file, run the harness, and confirm it still passes (it will, because
the harness never reloads). **Then add the reload test** so it does not:

```lua
-- A LOAD MUST NOT REPLAY IT. The flag that matters is the one in the save; one held in a
-- Lua local looks correct for an entire session and then fires on every single load.
GG.notice_once(GHUMAN, "first", "brass")     -- already fired above, no-op
fmark = #feed
-- Everything this mod holds in memory is rebuilt at load; only saved values survive.
GG.state, GG.demands, GG.patrons, GG.bounties = {}, {}, {}, {}
GG.state[GHUMAN] = {}
for i = 1, #GG.GUILDS do
    GG.state[GHUMAN][GG.GUILDS[i]] = {rep = 0, fav = 0}
end
GG.grant(GHUMAN, "brass", 8)
assert(#feed == fmark,
       "after a load the first-contact notice must stay quiet - the flag has to be in the "
       .. "SAVE, not in a Lua local that is rebuilt every time the campaign starts")
```

Add that block, restore the real `cm:*_saved_value` calls, and confirm the harness passes
with them and fails with the local table.

- [ ] **Step 9: Build and deploy**

```powershell
py tools\gen_great_guilds.py --write
py tools\gen_guilds_ui.py --write
py tools\import_great_guilds.py --check
```

Then, with RPFM open and the game closed:

```powershell
py tools\import_great_guilds.py
```

Expected: `saved pack verified - every table holds this build's rows`, with the loc count
risen by 108 (72 promotions + 36 notices) from 280 to 388.

Deploy:

```powershell
Copy-Item "G:\Modding for resources\Modding Files\Modpacks\derpy_great_guilds.pack" "F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\derpy_great_guilds.pack" -Force
```

---

## What this plan does not settle

Only a campaign answers these, and they are the reason to run one after the build:

1. **Whether the first-contact notice lands on turn 1 or turn 4.** It fires on the first
   accrual of any kind; which of the six routes fires first depends entirely on the faction.
2. **Whether the halfway beat is well placed.** Half of the Indebted threshold is 50
   reputation, a shape rather than a measurement, like every number in spec §4.
3. **Whether 72 promotion messages is too many over a long campaign.** Six guilds times four
   ranks is a ceiling of 24 messages across a whole campaign, roughly one every four turns
   at the design's intended pace. If it reads as noise, the fix is to announce ranks 2 and
   above only — a one-line change to the `new_rank < 1` guard.
4. **Whether the badge's number is legible at header_14 on a 44px plate.** Screenshot the
   HUD; if it is not, the fallback is a dot rather than a count, which needs no new file
   either.

## Self-review

**Spec coverage.** This plan implements the 2026-09-12 status review, not the spec, which
predates notices. Checked against the spec for conflicts: §4 (the two numbers) is untouched —
nothing here reads or writes reputation or favour; §5's "a service above the player's rank
draws greyed with the rank it needs, not hidden" is why `GGUI.actionable` gates on `can_buy`
rather than on price; §9.1's build-time gates are extended, not replaced. §11's list of what
only a live campaign settles gains four entries, recorded above.

**Placeholder scan.** No "TBD", no "add error handling", no "similar to Task N". Every code
step carries the code. Commit steps are replaced by gate runs, because this workspace is not
a git repo.

**Type consistency.** `GG.FEED_INDEX_RANK` (number 5004) is defined in Task 1 Step 8 and
consumed in Task 3 Step 5. `GG.announce_rank(faction, guild, old_rank, new_rank)` keeps that
signature in its test, definition and call site. `GG.notice_once(faction, tag, guild)`
returns a boolean in all three. `GGUI.actionable(faction)` and `GGUI.badge(faction)` both
take one argument and return a number. The loc key shapes in the Python loops match the
concatenations in the Lua character for character:
`message_event_text_text_derpy_gg_rank_<guild>_<rank>_<part>` and
`message_event_text_text_derpy_gg_notice_<tag>_<guild>_<part>`.
