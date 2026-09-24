# Great Guilds Flavours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Empire or Dwarf player sees their own race's six guilds everywhere the Great Guilds speaks (panel, Help, Log, event messages, Faction Effects titles, bounty missions, icons, grounds, crest), while a Chaos Dwarf player sees exactly what ships today.

**Architecture:** One flavour tag per culture (`""`, `"_emp"`, `"_dwf"`) is appended to every key the player reads. The generator emits every loc row, bundle, bounty mission and feed record once per tag from a `FLAVOURS` table; the model Lua appends the holder's or receiver's tag when it builds a key; the panel Lua appends the local player's tag when it reads loc or art. Chaos Dwarf keys carry the empty tag, so they are unchanged.

**Tech Stack:** Python 3 (`py`), Lua 5.1.5 (the game's version, at `C:\Program Files (x86)\Lua\5.1\`), Pillow, RPFM's MCP server for packing.

**Spec:** `docs/superpowers/specs/2026-09-23-great-guilds-flavours-design.md` - read it alongside this plan. Every name, rank, service name and prose string in Task 1 is copied from its sections 3 and 4.

## Global Constraints

- Chaos Dwarf keys, rows and texts stay byte-identical, with ONE exception: the MISSION bullet on Help page 2 (`derpy_gg_help_p2`) is shortened for every race (spec 4d).
- Tags and feed offsets: `wh3_dlc23_chd_chaos_dwarfs` -> `""` / 0, `wh_main_emp_empire` -> `"_emp"` / 10, `wh_main_dwf_dwarfs` -> `"_dwf"` / 20. Base feed indexes stay 5001 (hit), 5002 (demand), 5003 (lead), 5004 (rank).
- The tag goes on the END of a key, except a message-event key, where it goes before the engine's own `_title` / `_primary` / `_secondary`.
- Whose tag: rank, lead and bounty keys use the HOLDER's; service bundles the BUYER's (also the hostile one on a target); messages the RECEIVER's; the panel the LOCAL player's.
- Every guild name is 22 characters or fewer and starts with "The ".
- The Patron bundle stays one shared row (`derpy_gg_patron`). The panel title stays "The Great Guilds".
- No save migration (spec section 2).
- Loc is resolved only from draw paths - never from a turn handler, never at script root.
- New harness tests go in `;(function() ... end)()` blocks: the main chunk is near Lua 5.1's 200-local ceiling.
- Binary files (`.pack`, `db/`, `.loc`) are never edited as text. Packing needs RPFM open; if `http://127.0.0.1:45127/sessions` refuses, stop and say so.
- No art or game files go to the public GitHub repo (the user's ruling, 2026-09-23). `sync_guilds_repo.py` MANIFEST stays code and docs only.
- This workspace is NOT a git repository. Each task ends with its gate run instead of a commit.
- No emojis anywhere. Never use the word "rung".
- Pack paths are lowercase.
- Deploying to the game's `data/` folder happens only when the user asks, and only with the game closed.

## Review Focus

1. **A player of a culture with no flavour (Lizardmen, Araby, anything modded)** - expects the Chaos Dwarf words and art, never a raw key or a blank square. Pinned in Task 2 (`GG.tag` returns `""` for Lizardmen and for an unreadable culture) and Task 3 (a Lizardmen local player reads untagged keys and art and nothing is repainted).
2. **Head-to-head multiplayer, Empire against Dwarfs, with the hostile service** - expects the bundle on the victim to carry the buyer's tag and the feed message to arrive in the victim's own words at the victim's feed index. Pinned in Task 2 (service test and the `GGAI.report` line of the message test).
3. **The Empire's longer names overflowing Help page 2** - expects every line on screen, because `GGUI.help_lines` drops the overflow silently. Measured while planning at 22 of 21 lines; Task 1 shortens the MISSION bullet and runs `check_help_fits` per flavour.
4. **A flavoured icon, crest or ground missing from the pack** - expects a real picture; a missing path draws a blank square with no log line. Pinned in Task 4 (`gen_guilds_ui.py --check` asserts every tagged path is staged, and every tagged icon's native size).
5. **Any Chaos Dwarf regression** - expects today's keys and texts. Pinned in Task 1 (a snapshot of today's `build()` compared row for row) and by every existing harness test passing unedited (one shape assertion is edited, Task 2 Step 5).

---

### Task 1: Generator - FLAVOURS, per-tag emission and checks

**Files:**
- Modify: `tools/gen_great_guilds.py`
- Modify: `tools/gen_guilds_ui.py` (`check_help_fits`, lines 720-772)
- Write (generated): `Modding Files/source/great_guilds/*.tsv`

**Interfaces:**
- Consumes: nothing new.
- Produces (Python, module `gen_great_guilds`):
  - `FLAVOURS`: ordered dict `tag -> {"culture": str, "pics": str, "feed": int, "guilds": {guild: str}, "ranks": [5 str], "services": {service_key: str}, "blurbs": {service_key: str}, "desc": {guild: str}, "bounties": {guild: (title, text)}}`, in the order `""`, `"_emp"`, `"_dwf"`.
  - `GUILD_FLAVOUR`, `GUILD_EARN`: `{guild: str}`, the two halves of `GUILD_DESC`.
  - `short_name(guild, tag="") -> str`, `help_pages(tag="") -> [[str]]`.
  - `_build_one(tag) -> {table: [row]}` with UNTAGGED keys.
  - `tag_loc_key(key, tag) -> str`, `retag(tables, tag) -> {table: [row]}`.
  - `build() -> {table: [row]}`: every flavour, Chaos Dwarf pass first.
  - `check_flavour_shape() -> [str]`, `check_flavours() -> [str]`.

- [ ] **Step 1: Snapshot today's Chaos Dwarf build**

Before touching the generator. From the workspace root, in Bash:

```bash
cd "/g/Modding for resources" && py -c "
import io, json, sys; sys.path.insert(0, 'tools'); import gen_great_guilds as G
json.dump(G.build(), io.open('.skilltree_cache/gg_build_chd_before.json', 'w', encoding='utf-8'), ensure_ascii=False)
print('snapshot written')" < /dev/null
```

Expected: `snapshot written`.

- [ ] **Step 2: Write the failing selftest**

In `tools/gen_great_guilds.py`, `selftest()`: make the existing assertions run against the Chaos Dwarf pass only. Replace

```python
    assert all(k == k.lower() for k in keys), "bundle keys lowercase"
    tables = build()
```

with

```python
    assert all(k == k.lower() for k in keys), "bundle keys lowercase"
    # THE CHAOS DWARF PASS. Every count below is one flavour's; the block at the end of
    # this function holds build(), which ships all of them, to the same shape.
    tables = _build_one("")
```

Then, directly after these two existing lines near the end of `selftest()`:

```python
    hostile = [s for s in SERVICES if s.get("hostile")]
    assert len(hostile) == 1, "exactly one outward-facing service, got %d" % len(hostile)
```

insert:

```python
    # ------------------------------------------------------------ the flavours ---
    assert list(FLAVOURS) == ["", "_emp", "_dwf"], list(FLAVOURS)
    full = build()
    n = len(FLAVOURS)
    assert len(full["missions"]) == len(GUILDS) * n, len(full["missions"])
    # Every bundle once per flavour, except the patron, which is one shared row.
    assert len(full["effect_bundles"]) == (want_eb - 1) * n + 1, len(full["effect_bundles"])
    assert len(full["event_feed_message_events"]) == 4 * n
    text = dict((r["key"], r["text"]) for r in full["loc"])
    assert len(text) == len(full["loc"]), "a loc key is emitted twice"
    assert text["derpy_gg_guild_name_brass"] == "The Brass Tablets"
    assert text["derpy_gg_guild_name_brass_emp"] == "The Merchant Guilds"
    assert text["derpy_gg_rank_name_5_dwf"] == "Elder"
    assert text["derpy_gg_service_name_slave_tithe_dwf"] == "Weregild"
    assert text["missions_localised_title_derpy_gg_bounty_slavers_dwf"] == "Strike a Line"
    assert (text["effect_bundles_localised_title_derpy_gg_rank_brass_3_emp"]
            == "The Merchant Guilds - Journeyman")
    assert (text["message_event_text_text_derpy_gg_rank_brass_3_emp_title"]
            == "The Merchant Guilds Name You Journeyman")
    assert "At Apprentice they open" in \
        text["message_event_text_text_derpy_gg_notice_half_brass_emp_primary"]
    assert "At Indebted they open" in \
        text["message_event_text_text_derpy_gg_notice_half_brass_primary"]
    assert "a forge the Engineers' School" in text["derpy_gg_help_p2_emp"]
    assert "a forge the Daemonsmiths, a dock the Brass Tablets" in text["derpy_gg_help_p2"]
    assert "effect_bundles_localised_title_%s_emp" % PATRON_BUNDLE not in text, \
        "the patron is one shared row"
    crit = dict((r["member"], r["value"])
                for r in full["campaign_group_member_criteria_values"])
    assert crit["derpy_gg_event_feed_hit"] == "5001", crit
    assert crit["derpy_gg_event_feed_rank_emp"] == "5014", crit
    assert crit["derpy_gg_event_feed_hit_dwf"] == "5021", crit
    img = dict((r["group"], r["image"]) for r in full["event_feed_message_events"])
    assert img["derpy_gg_event_feed_rank_dwf"] == "dwf/civilisation_up", img
    ui = dict((r["key"], r["ui_image"]) for r in full["missions"])
    assert ui["derpy_gg_bounty_brass"] == "chd/generic", ui
    assert ui["derpy_gg_bounty_brass_emp"] == "emp/generic", ui
    assert (tag_loc_key("message_event_text_text_derpy_gg_demand_fail_title", "_emp")
            == "message_event_text_text_derpy_gg_demand_fail_emp_title")
    assert tag_loc_key("derpy_gg_guild_name_brass", "_dwf") == "derpy_gg_guild_name_brass_dwf"
    # THE FLAVOUR CHECKS MUST BE ABLE TO FAIL, or a clean run proves nothing.
    keep = FLAVOURS["_emp"]["guilds"]["brass"]
    try:
        FLAVOURS["_emp"]["guilds"]["brass"] = "The Hashut Guild"
        assert any("Hashut" in p for p in check_flavours()), "a Chaos Dwarf word slipped by"
        FLAVOURS["_emp"]["guilds"]["brass"] = "The Very Long Merchant Guilds"
        assert any("22" in p for p in check_flavours()), "an overlong name slipped by"
    finally:
        FLAVOURS["_emp"]["guilds"]["brass"] = keep
    keep = FLAVOURS["_dwf"]["services"].pop("great_coffle")
    try:
        assert any("great_coffle" in p for p in check_flavour_shape()), \
            "a missing service name slipped by"
    finally:
        FLAVOURS["_dwf"]["services"]["great_coffle"] = keep
    assert not check_flavour_shape(), check_flavour_shape()
    assert not check_flavours(), check_flavours()
```

- [ ] **Step 3: Run the selftest to verify it fails**

Run: `cd "/g/Modding for resources" && py tools/gen_great_guilds.py --selftest`
Expected: FAIL with `NameError: name '_build_one' is not defined`.

- [ ] **Step 4: Split GUILD_DESC into its two halves**

Replace the end of the `GUILD_DESC` dict:

```python
    "slavers":      "The coffle-drivers. Their ledger is measured in bodies, and it is "
                    "always growing.||Reputation accrues from settlements you sack, and "
                    "more from those you raze.",
}
```

with

```python
    "slavers":      "The coffle-drivers. Their ledger is measured in bodies, and it is "
                    "always growing.||Reputation accrues from settlements you sack, and "
                    "more from those you raze.",
}
# THE TWO HALVES. The flavour sentence is written per race in FLAVOURS below; the earn
# sentence is mechanical and every race shares it.
GUILD_FLAVOUR = dict((g, d.split("||", 1)[0]) for g, d in GUILD_DESC.items())
GUILD_EARN = dict((g, d.split("||", 1)[1]) for g, d in GUILD_DESC.items())
```

- [ ] **Step 5: Add FLAVOURS**

Insert immediately above the line `# The one-line version of each guild's earn route. GUILD_DESC carries the full sentence`:

```python
# ------------------------------------------------------------- the flavours ---
# ONE TAG PER CULTURE, APPENDED TO EVERY KEY THE PLAYER READS. The Chaos Dwarf entry is
# the empty tag and is read off the tables above rather than restated, so the pass that
# ships today's keys cannot drift from them. Names, ranks, services and prose are the
# spec's sections 3 and 4, approved as written. `culture` and `feed` are mirrored in
# GG.FLAVOURED in the model Lua, and check_flavour_mirror() compares the two. `pics` is
# the eventpics folder; every picture used under it is one vanilla's own rows use.
FLAVOURS = {
    "": {
        "culture": "wh3_dlc23_chd_chaos_dwarfs", "pics": "chd", "feed": 0,
        "guilds": GUILD_NAMES,
        "ranks": RANK_NAMES,
        "services": dict((s["key"], s["name"]) for s in SERVICES),
        "blurbs": dict((k, v) for k, v in SERVICE_BLURB.items() if v is not None),
        "desc": GUILD_FLAVOUR,
        "bounties": dict((g, (b[1], b[2])) for g, b in BOUNTIES.items()),
    },
    "_emp": {
        "culture": "wh_main_emp_empire", "pics": "emp", "feed": 10,
        "guilds": {
            "brass": "The Merchant Guilds",
            "immortals": "The Greatswords",
            "daemonsmiths": "The Engineers' School",
            "khanate": "The Thieves' Guild",
            "overseers": "The Masons' Guild",
            "slavers": "The Free Companies",
        },
        "ranks": ["Outsider", "Apprentice", "Journeyman", "Master", "Grand Master"],
        "services": {
            "caravan_levy": "Call in the Debts",
            "writ_monopoly": "Imperial Charter",
            "long_ledger": "The Altdorf Exchange",
            "oathbound_draft": "Muster Roll",
            "hire_immortals": "Hire the Greatswords",
            "astragoths_levy": "The Emperor's Levy",
            "forge_rite": "Proving Grounds",
            "bound_blueprint": "The School's Treatise",
            "bound_ordnance": "Guns of Nuln",
            "hobgoblin_eyes": "Eyes in Every Tavern",
            "knife_in_dark": "Knife in the Alley",
            "khans_price": "Protection Money",
            "lash_the_gangs": "Overtime Wages",
            "raise_ziggurat": "Master's Commission",
            "works_of_zharr": "The Emperor's Works",
            "coffle_drive": "Plunder Rights",
            "slave_tithe": "The Company's Cut",
            "great_coffle": "The Grand Pillage",
        },
        # The unit name matches vanilla's land_units_onscreen_name for
        # wh_main_emp_inf_greatswords, read with read_vanilla_loc on 2026-09-23.
        "blurbs": {
            "caravan_levy": "The Merchant Guilds call in what they are owed. Adds 2,500 "
                            "gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of Greatswords to an army of your choosing.",
            "bound_blueprint": "The Engineers' School hands over work already done. "
                               "Completes the technology you are currently researching, "
                               "at once.",
            "hobgoblin_eyes": "The Thieves' Guild sells what its ears have heard. Reveals "
                              "one region through the shroud, permanently.",
            "raise_ziggurat": "The Masons' Guild works through the night. Upgrades one of "
                              "your buildings to its next level at once, and free.",
            "slave_tithe": "The Free Companies send you your share of the take. Adds "
                           "3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "The counting-houses of Altdorf and Nuln. Every road toll, river "
                     "tariff and letter of credit in the Empire passes through their "
                     "books.",
            "immortals": "Veterans who swore their lives to an Elector Count's banner. "
                         "They sell that oath now, to whoever can carry it.",
            "daemonsmiths": "Altdorf's engineers, who build what should not work and make "
                            "it fire. They sell what they know, in instalments.",
            "khanate": "Every tavern has a back room, and every back room has an ear. "
                       "Their knives are for hire to anyone, including against you.",
            "overseers": "The builders of every wall and temple from the Reikland to "
                         "Ostland, and the only ones who know where the foundations are "
                         "weak.",
            "slavers": "Sell-swords and road-wardens paid in plunder. Their ledger is "
                       "measured in what they carry home.",
        },
        "bounties": {
            "brass": ("Open the Market",
                      "The Merchant Guilds want that town's tolls paid in Altdorf. Take "
                      "it standing."),
            "immortals": ("A Duel for the Banner",
                          "A general is being spoken of with respect. The Greatswords "
                          "would like that corrected."),
            "daemonsmiths": ("Salvage the Works",
                             "Whatever that place has built, the School wants on its own "
                             "benches. Bring it back in pieces."),
            "khanate": ("A Name Crossed Out",
                        "The Guild does not care how it is done, only that the name "
                        "stops being used."),
            "overseers": ("Stone Still Standing",
                          "Take it whole. The Masons want the walls left up, so they can "
                          "be paid to mend them."),
            "slavers": ("Pay Day",
                        "Empty it. The companies are owed, and that place can pay them."),
        },
    },
    "_dwf": {
        "culture": "wh_main_dwf_dwarfs", "pics": "dwf", "feed": 20,
        "guilds": {
            "brass": "The Merchant Clans",
            "immortals": "The Hammerers",
            "daemonsmiths": "The Engineers' Guild",
            "khanate": "The Rangers",
            "overseers": "The Miners' Guild",
            "slavers": "The Grudge-Settlers",
        },
        "ranks": ["Stranger", "Beardling", "Oathsworn", "Longbeard", "Elder"],
        "services": {
            "caravan_levy": "Road-Toll",
            "writ_monopoly": "Hold Charter",
            "long_ledger": "The Clan Ledger",
            "oathbound_draft": "Call to the Hold",
            "hire_immortals": "Hire the Hammerers",
            "astragoths_levy": "The High King's Levy",
            "forge_rite": "Guild Workshop",
            "bound_blueprint": "Guild Secrets",
            "bound_ordnance": "Guild Artillery",
            "hobgoblin_eyes": "Ranger's Report",
            "knife_in_dark": "Ambush in the Passes",
            "khans_price": "Cut Their Roads",
            "lash_the_gangs": "Double Shift",
            "raise_ziggurat": "Delve Deeper",
            "works_of_zharr": "Works of Grungni",
            "coffle_drive": "Settle the Account",
            "slave_tithe": "Weregild",
            "great_coffle": "The Great Reckoning",
        },
        # The unit name matches vanilla's land_units_onscreen_name for
        # wh_main_dwf_inf_hammerers, read with read_vanilla_loc on 2026-09-23.
        "blurbs": {
            "caravan_levy": "The Merchant Clans collect on every road between the holds. "
                            "Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of Hammerers to an army of your choosing.",
            "bound_blueprint": "The Engineers' Guild parts with a secret, once. Completes "
                               "the technology you are currently researching, at once.",
            "hobgoblin_eyes": "The Rangers report what they have seen from the high "
                              "passes. Reveals one region through the shroud, "
                              "permanently.",
            "raise_ziggurat": "The Miners' Guild works a double shift. Upgrades one of "
                              "your buildings to its next level at once, and free.",
            "slave_tithe": "Gold paid to settle a grudge, and passed on to you. Adds "
                           "3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "The traders of the Karaks, who remember every debt for as long as "
                     "there is stone to write it on.",
            "immortals": "The king's own guard, sworn to the throne of their hold. Their "
                         "oath can be lent, never broken.",
            "daemonsmiths": "Keepers of secrets guarded since the first hold was dug. They "
                            "share them slowly, and never twice.",
            "khanate": "Dwarfs who left the holds to watch the passes. They see "
                       "everything that moves above ground, and sell it dearly.",
            "overseers": "The delvers and stone-cutters who carved every hold. Nothing is "
                         "built in the mountains without them.",
            "slavers": "The clans who take the Book of Grudges at its word. Every line "
                       "struck out is paid for in plunder.",
        },
        "bounties": {
            "brass": ("Reopen the Road",
                      "The Merchant Clans want that place back in their ledgers. Take it "
                      "standing."),
            "immortals": ("A Grudge on a Name",
                          "A general has been boasting. The Hammerers would like that "
                          "settled."),
            "daemonsmiths": ("Recover the Craft",
                             "Whatever was forged in that place was likely stolen from us "
                             "first. Bring it back in pieces."),
            "khanate": ("Silence in the Passes",
                        "The Rangers want the name stopped. How is their affair."),
            "overseers": ("Reclaim the Hold",
                          "Take it whole. The Miners' Guild wants tunnels, not rubble."),
            "slavers": ("Strike a Line",
                        "Sack it. One more grudge struck from the Book, and paid for."),
        },
    },
}

# What check_flavours() refuses in a non-Chaos Dwarf flavour's text, and how long a name
# may run. 22 is the spec's limit for guild names. 12 is the longest approved rank name
# ("Grand Master"); whether it reads well on the Standings row is the preview's question.
CHD_ONLY_WORDS = ("Hashut", "Zharr", "Dark Lands", "slave", "Hobgoblin", "Infernal",
                  "Daemon")
GUILD_NAME_MAX = 22
RANK_NAME_MAX = 12

```

- [ ] **Step 6: Make short_name and help_pages take the flavour**

Replace

```python
def short_name(guild):
    """The guild's name without its leading article, for a compact list."""
    name = GUILD_NAMES[guild]
```

with

```python
def short_name(guild, tag=""):
    """The guild's name without its leading article, for a compact list."""
    name = FLAVOURS[tag]["guilds"][guild]
```

Replace

```python
def help_pages():
    """[[line, ...], ...] - one list per page, in the order the pager turns them."""
```

with

```python
def help_pages(tag=""):
    """[[line, ...], ...] - one list per page, in the order the pager turns them.

    The two names below SHADOW the module tables on purpose: assigned here, they are
    local for the whole function, so every line reads this flavour's words unedited.
    """
    GUILD_NAMES = FLAVOURS[tag]["guilds"]
    RANK_NAMES = FLAVOURS[tag]["ranks"]
```

Replace (the building sentence and the MISSION bullet, which is the one Chaos Dwarf text this work changes - measured at 22 of 21 lines for the Empire otherwise)

```python
        "-And a completed BUILDING pays whichever guild it belongs to - a forge the "
        "Daemonsmiths, a dock the Brass Tablets, a barracks the Immortals - more at "
        "higher levels.",
        "#Every guild at once",
        "-Completing any MISSION raises your standing with all six. It is the only "
        "thing that does, and it is how a guild whose trade you never touch comes to "
        "know your name.",
```

with

```python
        # Derived per flavour, so an Empire page names the Engineers' School and not the
        # Daemonsmiths. Same three guilds, same order as the Chaos Dwarf sentence.
        "-And a completed BUILDING pays whichever guild it belongs to - a forge the "
        "%s, a dock the %s, a barracks the %s - more at higher levels."
        % (short_name("daemonsmiths", tag), short_name("brass", tag),
           short_name("immortals", tag)),
        "#Every guild at once",
        # ONE LINE, NOT TWO (2026-09-23). The Empire's rivalry bullet below wraps where
        # ours does not and put this page at 22 of the panel's 21 slots; shortening this
        # bullet is the fix the flavours spec names, and it applies to every race.
        "-Every completed MISSION raises your standing with all six guilds - nothing "
        "else does.",
```

Replace

```python
        "-" + " / ".join("%s and %s" % (short_name(a), short_name(b))
                         for a, b in RIVAL_PAIRS),
```

with

```python
        "-" + " / ".join("%s and %s" % (short_name(a, tag), short_name(b, tag))
                         for a, b in RIVAL_PAIRS),
```

- [ ] **Step 7: Turn build() into one flavour's pass**

Replace

```python
def build():
    """Every DB row and loc line this plan ships, keyed by table name."""
    bundles, junctions, loc = [], [], []
```

with

```python
def _build_one(tag):
    """One flavour's rows, under the Chaos Dwarf keys. build() tags them.

    THE FOUR TABLES BELOW SHADOW THE MODULE ONES ON PURPOSE. Assigned here, they are
    local for the whole body, so every line of it reads this flavour's words without
    being edited - while the module tables, which other tools import, keep the Chaos
    Dwarf values.
    """
    F = FLAVOURS[tag]
    GUILD_NAMES = F["guilds"]
    RANK_NAMES = F["ranks"]
    SERVICE_NAMES = F["services"]
    SERVICE_BLURB = dict((s["key"], F["blurbs"].get(s["key"])) for s in SERVICES)
    GUILD_DESC = dict((g, F["desc"][g] + "||" + GUILD_EARN[g]) for g in GUILDS)
    bundles, junctions, loc = [], [], []
```

Replace every `s["name"]` in the file with `SERVICE_NAMES[s["key"]]` - there are exactly three, all inside `_build_one` (the `derpy_gg_service_name_` loc row, the service bundle's `localised_title`, and its `effect_bundles_localised_title_` loc row). Confirm with `grep -n 's\["name"\]' tools/gen_great_guilds.py` that none remain.

Replace

```python
    pages = help_pages()
    for _i, _lines in enumerate(pages):
```

with

```python
    pages = help_pages(tag)
    for _i, _lines in enumerate(pages):
```

Replace

```python
                 "You are halfway to a standing %s will act on. At Indebted they open "
                 "their first service to you.",
```

with

```python
                 "You are halfway to a standing %s will act on. At " + RANK_NAMES[1]
                 + " they open their first service to you.",
```

Replace

```python
        kind, title, desc = BOUNTIES[g]
```

with

```python
        kind = BOUNTIES[g][0]
        title, desc = F["bounties"][g]
```

Insert immediately above `def check_table_versions():`:

```python
def tag_loc_key(key, tag):
    """Where a flavour's tag goes in a loc key - the same place the Lua puts it.

    Before the engine's own suffix on a message-event key, because the Lua passes a stem
    and appends _title / _primary / _secondary itself. At the end of everything else.
    """
    m = re.match(r"(message_event_text_text_.+?)(_title|_primary|_secondary)$", key)
    if m:
        return m.group(1) + tag + m.group(2)
    return key + tag


def retag(tables, tag):
    """One flavour's rows under its own keys. The Chaos Dwarf pass comes back as it is.

    The patron's bundle, junctions and loc are dropped from a tagged pass: "Guild Patron"
    names no guild, so it stays one shared row.
    """
    if not tag:
        return tables
    F = FLAVOURS[tag]
    patron_loc = ("effect_bundles_localised_title_" + PATRON_BUNDLE,
                  "effect_bundles_localised_description_" + PATRON_BUNDLE)
    out = {
        "loc": [dict(r, key=tag_loc_key(r["key"], tag))
                for r in tables["loc"] if r["key"] not in patron_loc],
        "effect_bundles": [dict(r, key=r["key"] + tag)
                           for r in tables["effect_bundles"]
                           if r["key"] != PATRON_BUNDLE],
        "effect_bundles_to_effects_junctions": [
            dict(r, effect_bundle_key=r["effect_bundle_key"] + tag)
            for r in tables["effect_bundles_to_effects_junctions"]
            if r["effect_bundle_key"] != PATRON_BUNDLE],
        "missions": [dict(r, key=r["key"] + tag, ui_image=F["pics"] + "/generic")
                     for r in tables["missions"]],
        "campaign_groups": [dict(r, id=r["id"] + tag)
                            for r in tables["campaign_groups"]],
        "campaign_group_members": [dict(r, group=r["group"] + tag, id=r["id"] + tag)
                                   for r in tables["campaign_group_members"]],
        "campaign_group_member_criteria_values": [
            dict(r, member=r["member"] + tag, value=str(int(r["value"]) + F["feed"]))
            for r in tables["campaign_group_member_criteria_values"]],
        "event_feed_message_events": [
            dict(r, group=r["group"] + tag,
                 image=F["pics"] + "/" + r["image"].split("/", 1)[1])
            for r in tables["event_feed_message_events"]],
    }
    # A TABLE WITH NO RULE HERE WOULD SHIP UNTAGGED, or not at all, for two races.
    missing = sorted(set(tables) - set(out))
    assert not missing, "retag has no rule for %s" % ", ".join(missing)
    return out


def build():
    """Every DB row and loc line this plan ships, keyed by table name.

    One pass per flavour, the Chaos Dwarf pass first and unchanged.
    """
    out = {}
    for tag in FLAVOURS:
        for table, rows in retag(_build_one(tag), tag).items():
            out.setdefault(table, []).extend(rows)
    return out


def check_flavour_shape():
    """Every flavour must name everything the Chaos Dwarf one does.

    Run before anything that calls build(): _build_one indexes these tables and would
    raise on a gap, which is a crash where a finding was wanted.
    """
    out = []
    base = FLAVOURS[""]
    for tag, F in FLAVOURS.items():
        for k in ("culture", "pics", "feed"):
            if k not in F:
                out.append("flavour %r has no %s" % (tag, k))
        for part in ("guilds", "services", "blurbs", "desc", "bounties"):
            missing = sorted(set(base[part]) - set(F.get(part, {})))
            if missing:
                out.append("flavour %r has no %s for: %s"
                           % (tag, part, ", ".join(missing)))
        if len(F.get("ranks", [])) != len(RANK_THRESHOLDS):
            out.append("flavour %r names %d ranks and the ladder has %d"
                       % (tag, len(F.get("ranks", [])), len(RANK_THRESHOLDS)))
    return out


def check_flavours():
    """Every flavour must fit, speak its own race's words, and mirror the Chaos Dwarf keys
    and effects exactly.

    Each fault here is silent in game: a key the Lua builds and no row ships draws itself,
    a bundle with different effect rows pays one race a different bonus.
    """
    out = []
    for tag, F in FLAVOURS.items():
        for g, name in sorted(F["guilds"].items()):
            if len(name) > GUILD_NAME_MAX or not name.startswith("The "):
                out.append("flavour %r names %s %r - a guild name must start with "
                           "\"The \" and fit %d characters" % (tag, g, name, GUILD_NAME_MAX))
        for r in F["ranks"]:
            if len(r) > RANK_NAME_MAX:
                out.append("flavour %r has rank %r, longer than %d characters"
                           % (tag, r, RANK_NAME_MAX))
    feeds = [F["feed"] for F in FLAVOURS.values()]
    if len(set(feeds)) != len(feeds):
        out.append("two flavours share a feed offset, so one race's messages resolve to "
                   "the other's records: %r" % feeds)
    one = _build_one("")
    patron_loc = ("effect_bundles_localised_title_" + PATRON_BUNDLE,
                  "effect_bundles_localised_description_" + PATRON_BUNDLE)
    base_keys = set(r["key"] for r in one["loc"] if r["key"] not in patron_loc)
    base_fx = {}
    for r in one["effect_bundles_to_effects_junctions"]:
        base_fx.setdefault(r["effect_bundle_key"], []).append(
            (r["effect_key"], r["effect_scope"], r["value"]))
    for tag in FLAVOURS:
        if not tag:
            continue
        t = retag(_build_one(tag), tag)
        got = set(r["key"] for r in t["loc"])
        want = set(tag_loc_key(k, tag) for k in base_keys)
        for k in sorted(want - got)[:5]:
            out.append("flavour %r ships no %s, so it draws its own key" % (tag, k))
        for k in sorted(got - want)[:5]:
            out.append("flavour %r ships %s, which has no Chaos Dwarf twin" % (tag, k))
        fx = {}
        for r in t["effect_bundles_to_effects_junctions"]:
            fx.setdefault(r["effect_bundle_key"], []).append(
                (r["effect_key"], r["effect_scope"], r["value"]))
        for bk, rows in sorted(base_fx.items()):
            if bk == PATRON_BUNDLE:
                continue
            if sorted(fx.get(bk + tag, [])) != sorted(rows):
                out.append("%s%s does not carry exactly the effects of %s - that race's "
                           "bonus differs" % (bk, tag, bk))
        for r in t["loc"]:
            for w in CHD_ONLY_WORDS:
                if w.lower() in r["text"].lower():
                    out.append("%s says %r - a Chaos Dwarf word in the %s flavour"
                               % (r["key"], w, tag))
    return out

```

- [ ] **Step 8: Run the selftest to verify it passes**

Run: `cd "/g/Modding for resources" && py tools/gen_great_guilds.py --selftest`
Expected: `selftest ok: 6 guilds, 18 services, 43 bundles, <n> loc` and no traceback.

- [ ] **Step 9: Compare the Chaos Dwarf pass against the snapshot**

```bash
cd "/g/Modding for resources" && py -c "
import io, json, sys; sys.path.insert(0, 'tools'); import gen_great_guilds as G
before = json.load(io.open('.skilltree_cache/gg_build_chd_before.json', encoding='utf-8'))
one, full, bad = G._build_one(''), G.build(), []
for t, rows in before.items():
    got = one[t]
    if t == 'loc':
        rows = [r for r in rows if r['key'] != 'derpy_gg_help_p2']
        got = [r for r in got if r['key'] != 'derpy_gg_help_p2']
    if got != rows: bad.append(t)
    if full[t][:len(one[t])] != one[t]: bad.append('build() does not lead with ' + t)
old = [r['text'] for r in before['loc'] if r['key'] == 'derpy_gg_help_p2'][0]
new = [r['text'] for r in one['loc'] if r['key'] == 'derpy_gg_help_p2'][0]
OLD = ('Completing any MISSION raises your standing with all six. It is the only thing '
       'that does, and it is how a guild whose trade you never touch comes to know your name.')
NEW = 'Every completed MISSION raises your standing with all six guilds - nothing else does.'
if old.replace(OLD, NEW) != new: bad.append('help_p2 changed beyond the MISSION bullet')
print('CHD pass unchanged' if not bad else 'CHANGED: %r' % bad)" < /dev/null
```

Expected: `CHD pass unchanged`. Anything else is a regression - fix the edit, not the comparison.

- [ ] **Step 10: Make the existing checks cover every flavour**

`check_bounties()`: replace

```python
    if len(rows) != len(GUILDS):
        out.append("one bounty per guild: %d rows for %d guilds"
                   % (len(rows), len(GUILDS)))
```

with

```python
    if len(rows) != len(GUILDS) * len(FLAVOURS):
        out.append("one bounty per guild per flavour: %d rows for %d guilds and %d "
                   "flavours" % (len(rows), len(GUILDS), len(FLAVOURS)))
```

`check_help_pages()`: replace

```python
def check_help_pages():
    """Every page must be renderable, and the panel must know how many there are."""
    out = []
    pages = help_pages()
```

with

```python
def check_help_pages():
    """Every flavour's pages must fit - the Empire's longer names wrap where ours do not."""
    out = []
    for tag in FLAVOURS:
        out += ["[%s] %s" % (tag or "chd", p) for p in _check_help_pages_for(tag)]
    return out


def _check_help_pages_for(tag):
    """Every page must be renderable, and the panel must know how many there are."""
    out = []
    pages = help_pages(tag)
```

`check_feed_mirror()`: replace everything from

```python
    # The leadership message keys are built by concatenation in GG.announce_lead, so no
```

down to (not including) `def check_hire_units():` with

```python
    # The leadership, promotion and notice keys are built by concatenation in the Lua, so
    # no literal-key scan can reach them. Check the set this file must ship instead - for
    # every flavour, with the tag where the Lua puts it: before the engine's suffix.
    shipped = set(r["key"] for r in build()["loc"])
    for tag in FLAVOURS:
        for g in GUILDS:
            for part in ("title", "primary", "secondary"):
                for stem in ("won", "lost"):
                    k = ("message_event_text_text_derpy_gg_lead_%s_%s%s_%s"
                         % (stem, g, tag, part))
                    if k not in shipped:
                        out.append("GG.announce_lead builds %s and no loc row ships it, "
                                   "so that announcement draws nothing" % k)
                for r in range(2, len(RANK_NAMES) + 1):
                    k = ("message_event_text_text_derpy_gg_rank_%s_%d%s_%s"
                         % (g, r, tag, part))
                    if k not in shipped:
                        out.append("GG.announce_rank builds %s and no loc row ships it, "
                                   "so that promotion draws nothing" % k)
                for notice in ("first", "half"):
                    k = ("message_event_text_text_derpy_gg_notice_%s_%s%s_%s"
                         % (notice, g, tag, part))
                    if k not in shipped:
                        out.append("GG.notice_once builds %s and no loc row ships it, so "
                                   "that notice draws nothing" % k)
    return out


```

`check_titles()`: replace the whole function body from `    out = []` through its `    return out` with

```python
    out = []
    for tag, F in FLAVOURS.items():
        for row in _build_one(tag)["loc"]:
            key, text = row["key"], row["text"]
            if not key.startswith("message_event_text_text_derpy_gg_"):
                continue
            if not key.endswith("_title"):
                continue
            for g in GUILDS:
                full, short = F["guilds"][g], short_name(g, tag)
                if full == short:
                    continue                  # no article to lose
                at = text.find(short)
                while at != -1:
                    if not text[:at].rstrip().endswith(full[:-len(short)].strip()):
                        out.append("%s%s reads %r - %r drops the article that %r "
                                   "carries, which reads as a headline for a plural "
                                   "guild and as a mistake for a singular one"
                                   % (key, tag, text, short, full))
                        break
                    at = text.find(short, at + 1)
    return out
```

`check_ui_loc_keys()`: replace

```python
        for m in re.finditer(r'GGUI\.loc\(\s*"([a-z0-9_]+)"(?!\s*\.\.)', src):
            if "derpy_gg_" + m.group(1) not in have:
                bad.append("%s reads GGUI.loc(\"%s\") and no loc row defines it"
                           % (stem, m.group(1)))
```

with

```python
        # GGUI.loc appends the local player's flavour tag, so every literal must ship
        # under every tag.
        for m in re.finditer(r'GGUI\.loc\(\s*"([a-z0-9_]+)"(?!\s*\.\.)', src):
            for tag in FLAVOURS:
                if "derpy_gg_" + m.group(1) + tag not in have:
                    bad.append("%s reads GGUI.loc(\"%s\") and no loc row defines it for "
                               "flavour %r" % (stem, m.group(1), tag))
```

and replace

```python
                for k in re.findall(r'return\s+"([a-z0-9_]+)"', fn.group(1)):
                    if "derpy_gg_" + k not in have:
                        bad.append("GGUI.target_hint returns \"%s\" and no loc row "
                                   "defines it" % k)
```

with

```python
                for k in re.findall(r'return\s+"([a-z0-9_]+)"', fn.group(1)):
                    for tag in FLAVOURS:
                        if "derpy_gg_" + k + tag not in have:
                            bad.append("GGUI.target_hint returns \"%s\" and no loc row "
                                       "defines it for flavour %r" % (k, tag))
```

`check_feed_images()`: replace

```python
    for name, row in (("hit", FEED_ROW), ("demand", FEED_ROW_DEMAND),
                      ("lead", FEED_ROW_LEAD), ("rank", FEED_ROW_RANK)):
        img = row.get("image")
        if img not in known:
            near = sorted(k for k in known if k.startswith("chd/"))
            out.append("the %s feed record draws %r, which no vanilla row uses - a "
                       "missing event picture is a black rectangle on the panel, not an "
                       "error. Chaos Dwarf pictures vanilla uses: %s"
                       % (name, img, ", ".join(near)))
    return out
```

with

```python
    # EVERY FLAVOUR'S RECORDS, read off build() - the emp/ and dwf/ copies are made by
    # retag() swapping the folder, and nothing else checks that the swap lands on a
    # picture that exists.
    tables = build()
    for row in tables["event_feed_message_events"]:
        img = row.get("image")
        if img not in known:
            folder = img.split("/", 1)[0] + "/"
            near = sorted(k for k in known if k.startswith(folder))
            out.append("the %s feed record draws %r, which no vanilla row uses - a "
                       "missing event picture is a black rectangle on the panel, not an "
                       "error. Pictures vanilla uses there: %s"
                       % (row["group"], img, ", ".join(near)))
    try:
        mrows, _ = load("missions")
        mknown = set(r.get("ui_image") for r in mrows if r.get("ui_image"))
        for row in tables["missions"]:
            if row["ui_image"] not in mknown:
                out.append("bounty %s draws %r, which no vanilla mission uses"
                           % (row["key"], row["ui_image"]))
    except Exception as exc:                                   # noqa: BLE001
        out.append("cannot read vanilla missions to check bounty pictures: %s" % exc)
    return out
```

`check()`: replace

```python
    if out:
        return out          # build() would raise on these
    out += check_favour_floor()
```

with

```python
    if out:
        return out          # build() would raise on these
    out += check_flavour_shape()
    if out:
        return out          # build() would raise on an incomplete flavour
    out += check_flavours()
    out += check_favour_floor()
```

and replace

```python
        hostile_keys = set(service_bundle_key(x["key"])
                           for x in SERVICES if x.get("hostile"))
```

with

```python
        # EVERY FLAVOUR'S COPY of the hostile bundle, or the tagged ones read as a malus
        # on the buyer's own sign and are reported as inverted.
        hostile_keys = set(service_bundle_key(x["key"]) + t
                           for x in SERVICES if x.get("hostile") for t in FLAVOURS)
```

- [ ] **Step 11: Make gen_guilds_ui's help-fit check cover every flavour**

In `tools/gen_guilds_ui.py`, `check_help_fits()`: replace

```python
    try:
        import gen_great_guilds as GG
        pages = GG.help_pages()
    except Exception as e:
        return ["help fit check could not read the pages: %r" % (e,)]
```

with

```python
    try:
        import gen_great_guilds as GG
        # EVERY FLAVOUR. The Empire's names are longer and wrap where ours do not, so a
        # page that fits in Chaos Dwarf can drop its last line for an Empire player.
        flavours = [(tag, GG.help_pages(tag)) for tag in GG.FLAVOURS]
    except Exception as e:
        return ["help fit check could not read the pages: %r" % (e,)]
```

and replace the page loop at the end of the function:

```python
    for i, lines in enumerate(pages):
        n = 0
        for j, line in enumerate(lines):
            if line == "":
                n += 1
            elif line.startswith("#"):
                if j:
                    n += 1          # the blank above every heading but the first
                n += 1
            elif line.startswith("-"):
                n += max(1, len(textwrap.wrap(line[1:], WIDTH - INDENT)))
            else:
                n += max(1, len(textwrap.wrap(line, WIDTH)))
        if n > HELP_SLOTS:
            out.append("help page %d needs about %d lines and there are %d slots - the "
                       "text past the last one is dropped in silence"
                       % (i + 1, n, HELP_SLOTS))
    return out
```

with

```python
    for tag, pages in flavours:
        for i, lines in enumerate(pages):
            n = 0
            for j, line in enumerate(lines):
                if line == "":
                    n += 1
                elif line.startswith("#"):
                    if j:
                        n += 1      # the blank above every heading but the first
                    n += 1
                elif line.startswith("-"):
                    n += max(1, len(textwrap.wrap(line[1:], WIDTH - INDENT)))
                else:
                    n += max(1, len(textwrap.wrap(line, WIDTH)))
            if n > HELP_SLOTS:
                out.append("help page %d (%s) needs about %d lines and there are %d slots "
                           "- the text past the last one is dropped in silence"
                           % (i + 1, tag or "chd", n, HELP_SLOTS))
    return out
```

- [ ] **Step 12: Gate**

```bash
cd "/g/Modding for resources" && py tools/gen_great_guilds.py --selftest && py tools/gen_great_guilds.py --check && py tools/gen_guilds_ui.py --check && py tools/gen_great_guilds.py --write && py tools/import_great_guilds.py --check
```

Expected: selftest ok; `--check` exits 0 with no `PROBLEM:` lines; `gen_guilds_ui.py --check` exits 0 (no help page over 21 for any flavour); `--write` lists 8 TSVs; `import_great_guilds.py --check` prints `verify ok - 127 bundles, ...`. If `gen_guilds_ui.py --check` reports a help page over, the fix is rewording on that page per spec 4d, never dropping a line.

---

### Task 2: Model Lua - the tag, the feed offset and the five key sites

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua` (lines 34-37, 78, 82, 93, 95, 620-622, 1067-1069, 1089, 1887, 1945, 1983, 2176-2180, after 2215, 2230-2232, 3087-3094, 3116-3122, 3204-3207, 3279-3286, 3314-3317)
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua` (lines 228-233)
- Modify: `tools/_guilds_harness.lua` (line 3404, and new blocks at the end)
- Modify: `tools/gen_great_guilds.py` (new `lua_flavoured`, `check_flavour_mirror`)

**Interfaces:**
- Consumes: from Task 1, `FLAVOURS[tag]["culture"]` and `["feed"]`; the loc keys `retag` ships (tag on the end, or before `_title`/`_primary`/`_secondary`).
- Produces (Lua):
  - `GG.FLAVOURED[culture] = {tag = string, feed = number}`
  - `GG.flavour_of(faction) -> entry | nil`
  - `GG.tag(faction) -> string` (`""` for nil, unflavoured or unreadable)
  - `GG.feed(faction, base) -> number`
  - `GG.bundle_key(guild, rank, faction)`, `GG.lead_key(guild, culture)`, `GG.bounty_mission_key(guild, faction)` - the extra argument may be nil, which gives the untagged key.
- Produces (Python): `lua_flavoured(lua_text) -> {culture: (tag, feed)} | None`, `check_flavour_mirror() -> [str]`.

- [ ] **Step 1: Write the failing harness tests**

In `tools/_guilds_harness.lua`, insert immediately above the final `print("harness ok")`:

```lua
-- ------------------------------------------------------------- the flavours --
-- ONE TAG PER CULTURE ON EVERY KEY THE PLAYER READS. Chaos Dwarfs carry the empty tag, so
-- every test above this line is also the proof that their keys did not move.
;(function()
    local E, D, L, X = "cr_flav_emp", "cr_flav_dwf", "cr_flav_lzd", "cr_flav_gone"
    CULTURE[E], CULTURE[D] = "wh_main_emp_empire", "wh_main_dwf_dwarfs"
    CULTURE[L] = "wh2_main_lzd_lizardmen"
    NO_SUCH_FACTION[X] = true
    for _, f in ipairs({E, D, L, X, THE_PLAYER}) do GG.CULTURE_OF[f] = nil end
    assert(GG.tag(THE_PLAYER) == "", "Chaos Dwarfs carry the empty tag")
    assert(GG.tag(E) == "_emp", "the Empire's tag, got " .. tostring(GG.tag(E)))
    assert(GG.tag(D) == "_dwf", "the Dwarfs' tag, got " .. tostring(GG.tag(D)))
    assert(GG.tag(L) == "", "a culture with no flavour reads the Chaos Dwarf words")
    assert(GG.tag(X) == "", "an unreadable culture reads the Chaos Dwarf words")
    assert(GG.tag(nil) == "", "no faction is the untagged key")
    assert(GG.feed(E, 5004) == 5014 and GG.feed(D, 5004) == 5024,
           "feed offsets 10 and 20, got " .. GG.feed(E, 5004) .. " and " .. GG.feed(D, 5004))
    assert(GG.feed(THE_PLAYER, 5004) == 5004 and GG.feed(L, 5001) == 5001,
           "Chaos Dwarfs and the unflavoured keep the base index")
    CULTURE[E], CULTURE[D], CULTURE[L], NO_SUCH_FACTION[X] = nil, nil, nil, nil
    for _, f in ipairs({E, D, L, X}) do GG.CULTURE_OF[f] = nil end
end)()

-- AN EMPIRE RANK IS AN EMPIRE BUNDLE, and the sweep that clears the other ranks clears
-- only the Empire's own - never another race's.
;(function()
    local E = "cr_flav_rank_emp"
    CULTURE[E] = "wh_main_emp_empire"
    GG.CULTURE_OF[E] = nil
    local a0, r0 = #applied, #removed
    GG.apply_rank(E, "brass", 2, 3)
    assert(removed[r0 + 1] and removed[r0 + 1][1] == "derpy_gg_rank_brass_2_emp",
           "the old Empire rank must go by its tagged key, got "
           .. tostring(removed[r0 + 1] and removed[r0 + 1][1]))
    assert(applied[a0 + 1] and applied[a0 + 1][1] == "derpy_gg_rank_brass_3_emp",
           "the new Empire rank must land by its tagged key, got "
           .. tostring(applied[a0 + 1] and applied[a0 + 1][1]))
    GG.state[E] = {brass = {rep = 300, fav = 0}}
    GG.asserted[E] = nil
    a0, r0 = #applied, #removed
    GG.assert_ranks(E)
    assert(#removed > r0, "assert_ranks must clear the other ranks")
    for i = r0 + 1, #removed do
        assert(string.sub(removed[i][1], -4) == "_emp",
               "an Empire sweep removed " .. removed[i][1] .. ", another race's bundle")
    end
    assert(applied[#applied][1] == "derpy_gg_rank_brass_3_emp",
           "assert_ranks must apply the tagged bundle, got " .. applied[#applied][1])
    assert(GG.bundle_key("brass", 3, THE_PLAYER) == "derpy_gg_rank_brass_3",
           "a Chaos Dwarf rank key must not move")
    GG.state[E], GG.asserted[E], CULTURE[E], GG.CULTURE_OF[E] = nil, nil, nil, nil
end)()

-- THE LEAD BUNDLE IS PER CULTURE, and reassert_leaders hands the engine that key.
-- leader_of and the culture list are stubbed: what is under test is which key the sweep
-- uses, not who wins.
;(function()
    local E = "cr_flav_lead_emp"
    assert(GG.lead_key("brass", "wh_main_emp_empire") == "derpy_gg_lead_brass_emp")
    assert(GG.lead_key("brass", "wh_main_dwf_dwarfs") == "derpy_gg_lead_brass_dwf")
    assert(GG.lead_key("brass", GG.CHD_CULTURE) == "derpy_gg_lead_brass")
    assert(GG.lead_key("brass", "wh2_main_lzd_lizardmen") == "derpy_gg_lead_brass")
    local prev_leader, prev_cip, prev_now = GG.leader_of, GG.cultures_in_play, GG.leaders_now
    GG.cultures_in_play = function() return {["wh_main_emp_empire"] = true} end
    GG.leader_of = function(guild, _culture)
        if guild == "brass" then return E end
        return nil
    end
    GG.leaders_now = {}
    local a0, ok = #applied, false
    GG.reassert_leaders()
    for i = a0 + 1, #applied do
        assert(applied[i][1] ~= "derpy_gg_lead_brass",
               "an Empire leader was handed the Chaos Dwarf lead bundle")
        if applied[i][1] == "derpy_gg_lead_brass_emp" and applied[i][2] == E then ok = true end
    end
    assert(ok, "the Empire's foremost must be given derpy_gg_lead_brass_emp")
    GG.leader_of, GG.cultures_in_play, GG.leaders_now = prev_leader, prev_cip, prev_now
end)()

-- A SERVICE CARRIES THE BUYER'S TAG, the hostile one included: its victim is of another
-- race and reads the name of who did it to them. And a bounty is keyed per holder.
;(function()
    local E, D = "cr_flav_svc_emp", "cr_flav_svc_dwf"
    CULTURE[E], CULTURE[D] = "wh_main_emp_empire", "wh_main_dwf_dwarfs"
    GG.CULTURE_OF[E], GG.CULTURE_OF[D] = nil, nil
    GG.payload(E, GG.service("writ_monopoly"))
    assert(applied[#applied][1] == "derpy_gg_svc_writ_monopoly_emp"
           and applied[#applied][2] == E,
           "an Empire purchase must land the _emp bundle on the buyer, got "
           .. applied[#applied][1])
    GG.payload(E, GG.service("khans_price"), D)
    assert(applied[#applied][1] == "derpy_gg_svc_khans_price_emp"
           and applied[#applied][2] == D,
           "the hostile service must land the BUYER's tag on the target, got "
           .. applied[#applied][1] .. " on " .. tostring(applied[#applied][2]))

    assert(GG.bounty_mission_key("brass", E) == "derpy_gg_bounty_brass_emp")
    assert(GG.bounty_mission_key("brass") == "derpy_gg_bounty_brass",
           "no faction is the Chaos Dwarf key")
    local str = GG.bounty_string(E, {guild = "brass", kind = "region_take",
                                     target = "r", gold = 100})
    assert(str and string.find(str, "key derpy_gg_bounty_brass_emp;", 1, true),
           "an Empire bounty must be issued under its tagged key: " .. tostring(str))
    local prev = GG.bounties[E]
    GG.bounties[E] = {{guild = "brass", taken = true, rep = 0}}
    assert(GG.bounty_done(E, "derpy_gg_bounty_brass") == false,
           "the untagged key must not pay an Empire bounty")
    assert(GG.bounty_done(E, "derpy_gg_bounty_brass_emp") == true,
           "the Empire's own key must pay it")
    GG.bounties[E] = prev
    CULTURE[E], CULTURE[D], GG.CULTURE_OF[E], GG.CULTURE_OF[D] = nil, nil, nil, nil
end)()

-- EVERY MESSAGE IN ITS RECEIVER'S WORDS, at its receiver's feed index.
;(function()
    local E, D, X = "cr_flav_msg_emp", "cr_flav_msg_dwf", "cr_flav_msg_chd"
    CULTURE[E], CULTURE[D] = "wh_main_emp_empire", "wh_main_dwf_dwarfs"
    CULTURE[X] = "wh3_dlc23_chd_chaos_dwarfs"
    for _, f in ipairs({E, D, X}) do GG.CULTURE_OF[f] = nil end
    local prev_humans = cm.get_human_factions
    cm.get_human_factions = function() return {E, D, X} end
    GG.humans, GG.player_cultures_cache = nil, nil

    local function heard(f, title, idx, why)
        local l = feed[#feed]
        assert(l and l[1] == f and l[2] == title and l[3] == idx,
               why .. ": wanted " .. f .. " / " .. title .. " / " .. idx .. ", got "
               .. tostring(l and l[1]) .. " / " .. tostring(l and l[2]) .. " / "
               .. tostring(l and l[3]))
    end

    GG.announce_rank(E, "brass", 1, 3)
    heard(E, "message_event_text_text_derpy_gg_rank_brass_3_emp_title", 5014,
          "an Empire promotion")
    GG.announce_rank(D, "brass", 1, 3)
    heard(D, "message_event_text_text_derpy_gg_rank_brass_3_dwf_title", 5024,
          "a Dwarf promotion")
    GG.announce_rank(X, "brass", 1, 3)
    heard(X, "message_event_text_text_derpy_gg_rank_brass_3_title", 5004,
          "a Chaos Dwarf promotion must not move")
    GG.announce_lead("brass", E, "cr_flav_nobody")
    heard(E, "message_event_text_text_derpy_gg_lead_won_brass_emp_title", 5013,
          "an Empire lead won")
    GG.announce_demand(D, "expired")
    heard(D, "message_event_text_text_derpy_gg_demand_fail_dwf_title", 5022,
          "a Dwarf demand expiring")
    GG.announce_bounty_fail(E, "brass", 100)
    heard(E, "message_event_text_text_derpy_gg_bounty_fail_emp_title", 5012,
          "an Empire bounty failing")
    assert(GG.notice_once(D, "first", "khanate") == true, "the notice must fire")
    heard(D, "message_event_text_text_derpy_gg_notice_first_khanate_dwf_title", 5024,
          "a Dwarf notice")
    -- HEAD-TO-HEAD: an Empire rival's hostile service lands on a Dwarf player, who reads
    -- it in their own race's words.
    GGAI.report(E, GG.service("khans_price"), D)
    heard(D, "message_event_text_text_derpy_gg_hit_dwf_title", 5021,
          "an Empire hit landing on a Dwarf player")

    cm.get_human_factions = prev_humans
    GG.humans, GG.player_cultures_cache = nil, nil
    for _, f in ipairs({E, D, X}) do CULTURE[f], GG.CULTURE_OF[f] = nil, nil end
    fmark = #feed
end)()
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `cd "/g/Modding for resources" && "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua`
Expected: FAIL with `attempt to call field 'tag' (a nil value)`.

- [ ] **Step 3: Add the generator's mirror test**

In `tools/gen_great_guilds.py`, `selftest()`, directly after the line `assert not check_flavours(), check_flavours()` from Task 1, insert:

```python
    sample = ('GG.CHD_CULTURE = "wh3_dlc23_chd_chaos_dwarfs"\n'
              'GG.FLAVOURED = {\n'
              '    [GG.CHD_CULTURE]       = {tag = "",     feed = 0},\n'
              '    ["wh_main_emp_empire"] = {tag = "_emp", feed = 10},\n'
              '}\n')
    assert lua_flavoured(sample) == {"wh3_dlc23_chd_chaos_dwarfs": ("", 0),
                                     "wh_main_emp_empire": ("_emp", 10)}, \
        lua_flavoured(sample)
    assert lua_flavoured("GG.FLAVOURED = nil") is None
```

Run: `py tools/gen_great_guilds.py --selftest`
Expected: FAIL with `NameError: name 'lua_flavoured' is not defined`.

- [ ] **Step 4: Implement the Lua**

In `zzz_derpy_guilds.lua`, replace

```lua
function GG.bundle_key(guild, rank)
    if rank < 2 then return nil end
    return "derpy_gg_rank_" .. guild .. "_" .. rank
end
```

with

```lua
-- THE HOLDER'S FLAVOUR TAG ON THE END: derpy_gg_rank_brass_3 for a Chaos Dwarf faction,
-- derpy_gg_rank_brass_3_emp for an Empire one. A nil faction is the untagged key.
function GG.bundle_key(guild, rank, faction)
    if rank < 2 then return nil end
    return "derpy_gg_rank_" .. guild .. "_" .. rank .. GG.tag(faction)
end
```

In `GG.assert_ranks`: `local k = GG.bundle_key(guild, r)` becomes `local k = GG.bundle_key(guild, r, faction)`, and `local key = GG.bundle_key(guild, rank)` becomes `local key = GG.bundle_key(guild, rank, faction)`.

In `GG.apply_rank`: `local old_key = GG.bundle_key(guild, old_rank)` becomes `local old_key = GG.bundle_key(guild, old_rank, faction)`, and `local new_key = GG.bundle_key(guild, new_rank)` becomes `local new_key = GG.bundle_key(guild, new_rank, faction)`.

Replace

```lua
function GG.bounty_mission_key(guild)
    return "derpy_gg_bounty_" .. guild
end
```

with

```lua
-- Per holder: an Empire faction's bounty is derpy_gg_bounty_brass_emp, which is the row
-- whose title and picture are the Empire's. A nil faction is the untagged key.
function GG.bounty_mission_key(guild, faction)
    return "derpy_gg_bounty_" .. guild .. GG.tag(faction)
end
```

Replace all three `GG.bounty_mission_key(o.guild)` in this file with `GG.bounty_mission_key(o.guild, faction)` (in `GG.bounty_string(faction, o)`, `GG.bounty_done(faction, mission_key)` and `GG.take_bounty_slot(faction, mission_key)`; `faction` is a parameter of all three).

Replace

```lua
function GG.lead_key(guild)
    return "derpy_gg_lead_" .. guild
end
```

with

```lua
-- One bundle per guild PER CULTURE: an Empire foremost holds derpy_gg_lead_brass_emp.
-- The sweep in reassert_leaders is already scoped to one culture, so it passes it here.
function GG.lead_key(guild, culture)
    local f = GG.FLAVOURED[culture]
    return "derpy_gg_lead_" .. guild .. (f and f.tag or "")
end
```

and in `GG.reassert_leaders`, `local key = GG.lead_key(guild)` becomes `local key = GG.lead_key(guild, culture)`.

Replace

```lua
-- The cultures this mod ships flavour for. Not a gate - purely which ones have their own
-- guild names, rank names and hire unit rather than the generic fallback.
GG.FLAVOURED = {
    [GG.CHD_CULTURE] = true,
    ["wh_main_dwf_dwarfs"] = true,
    ["wh_main_emp_empire"] = true,
}
```

with

```lua
-- The cultures this mod ships flavour for. Not a gate - purely which ones have their own
-- guild names, rank names, art and hire unit rather than the Chaos Dwarf fallback.
--
-- `tag` goes on the end of every key the player reads (before the engine's own _title /
-- _primary / _secondary on a message), and `feed` is added to the four feed indexes.
-- tools/gen_great_guilds.py mints the rows behind both and check_flavour_mirror() there
-- compares this table against its own; a mismatch is a raw key or a message that draws
-- nothing, with no error either way.
GG.FLAVOURED = {
    [GG.CHD_CULTURE]       = {tag = "",     feed = 0},
    ["wh_main_emp_empire"] = {tag = "_emp", feed = 10},
    ["wh_main_dwf_dwarfs"] = {tag = "_dwf", feed = 20},
}
```

Insert directly after the end of `GG.covered` (after its closing lines `    return mine[c] == true` / `end`):

```lua

-- WHICH FLAVOUR A FACTION READS: its culture's entry, or nil for a culture with none and
-- for one that cannot be read. Fills GG.CULTURE_OF through GG.covered the first time.
function GG.flavour_of(faction)
    if not faction then return nil end
    if GG.CULTURE_OF[faction] == nil then GG.covered(faction) end
    return GG.FLAVOURED[GG.CULTURE_OF[faction]]
end

-- "" for Chaos Dwarfs, for every culture with no flavour and for nil - so every Chaos
-- Dwarf key, and every key built without a faction, is exactly what it was.
function GG.tag(faction)
    local f = GG.flavour_of(faction)
    return f and f.tag or ""
end

-- A feed index for the faction that RECEIVES the message: the base plus its offset.
function GG.feed(faction, base)
    local f = GG.flavour_of(faction)
    return base + (f and f.feed or 0)
end
```

In `GG.payload`, replace both `"derpy_gg_svc_" .. s.key` with `"derpy_gg_svc_" .. s.key .. GG.tag(faction)` - the BUYER's tag in both branches, including the hostile one that lands on `target`.

In `GG.announce_demand`, replace

```lua
    local stem = "message_event_text_text_derpy_gg_demand"
    if what == "expired" then stem = stem .. "_fail" end
```

with

```lua
    local stem = "message_event_text_text_derpy_gg_demand"
    if what == "expired" then stem = stem .. "_fail" end
    stem = stem .. GG.tag(faction)
```

In `GG.announce_bounty_fail`, replace `local stem = "message_event_text_text_derpy_gg_bounty_fail"` with `local stem = "message_event_text_text_derpy_gg_bounty_fail" .. GG.tag(faction)`.

Replace both occurrences of `true, GG.FEED_INDEX_DEMAND)` with `true, GG.feed(faction, GG.FEED_INDEX_DEMAND))` (one in each of the two functions above; `faction` is in scope in both).

In `GG.announce_lead`, replace

```lua
            local k = "message_event_text_text_derpy_gg_lead_" .. stem .. "_" .. guild
            pcall(function()
                cm:show_message_event(me, k .. "_title", k .. "_primary",
                                      k .. "_secondary", true, GG.FEED_INDEX_LEAD)
            end)
```

with

```lua
            local k = "message_event_text_text_derpy_gg_lead_" .. stem .. "_" .. guild
                      .. GG.tag(me)
            pcall(function()
                cm:show_message_event(me, k .. "_title", k .. "_primary",
                                      k .. "_secondary", true,
                                      GG.feed(me, GG.FEED_INDEX_LEAD))
            end)
```

In `GG.announce_rank`, replace

```lua
            local k = "message_event_text_text_derpy_gg_rank_"
                      .. guild .. "_" .. new_rank
```

with

```lua
            local k = "message_event_text_text_derpy_gg_rank_"
                      .. guild .. "_" .. new_rank .. GG.tag(faction)
```

In `GG.notice_once`, replace `local k = "message_event_text_text_derpy_gg_notice_" .. tag .. "_" .. guild` with `local k = "message_event_text_text_derpy_gg_notice_" .. tag .. "_" .. guild .. GG.tag(faction)` (`tag` there is the notice's own "first"/"half" argument; `GG.tag` is the function).

Replace both occurrences of `true, GG.FEED_INDEX_RANK)` with `true, GG.feed(faction, GG.FEED_INDEX_RANK))` (one in `GG.announce_rank`, one in `GG.notice_once`; `faction` is in scope in both).

In `zzz_derpy_guilds_ai.lua`, `GGAI.report`, replace

```lua
            pcall(function()
                cm:show_message_event(target,
                    "message_event_text_text_derpy_gg_hit_title",
                    "message_event_text_text_derpy_gg_hit_primary",
                    "message_event_text_text_derpy_gg_hit_secondary",
                    true, GG.FEED_INDEX)
            end)
```

with

```lua
            -- IN THE RECEIVER'S WORDS: the target is who reads it.
            local k = "message_event_text_text_derpy_gg_hit" .. GG.tag(target)
            pcall(function()
                cm:show_message_event(target, k .. "_title", k .. "_primary",
                                      k .. "_secondary", true,
                                      GG.feed(target, GG.FEED_INDEX))
            end)
```

- [ ] **Step 5: Edit the one harness assertion about the table's shape**

`GG.FLAVOURED` values are now tables, not `true`. In `tools/_guilds_harness.lua` (line 3404), replace

```lua
        assert(GG.FLAVOURED[culture] == true,
```

with

```lua
        assert(GG.FLAVOURED[culture] ~= nil,
```

This is the only existing test edited; it asserts membership, which is unchanged.

- [ ] **Step 6: Implement the generator's mirror check**

In `tools/gen_great_guilds.py`, insert directly above `def check_hire_units():`:

```python
def lua_flavoured(lua):
    """{culture: (tag, feed)} read out of GG.FLAVOURED in the model Lua's text, or None."""
    block = re.search(r"^GG\.FLAVOURED = \{(.*?)\n\}", lua, re.S | re.M)
    chd = re.search(r'^GG\.CHD_CULTURE = "([a-z0-9_]+)"', lua, re.M)
    if not block or not chd:
        return None
    got = {}
    for key, tag, feed in re.findall(
            r'\[(GG\.CHD_CULTURE|"[a-z0-9_]+")\]\s*=\s*\{\s*tag\s*=\s*"([_a-z]*)"\s*,'
            r'\s*feed\s*=\s*(\d+)\s*\}', block.group(1)):
        culture = chd.group(1) if key == "GG.CHD_CULTURE" else key.strip('"')
        got[culture] = (tag, int(feed))
    return got


def check_flavour_mirror():
    """GG.FLAVOURED must hand each culture the tag and feed offset minted here.

    A tag the Lua builds and no row ships is a raw key on screen; a feed offset that
    disagrees is a message that logs and draws nothing. Both are silent.
    """
    path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    try:
        lua = io.open(path, encoding="utf-8").read()
    except IOError:
        return ["cannot read %s to check GG.FLAVOURED" % path]
    got = lua_flavoured(lua)
    if got is None:
        return ["GG.FLAVOURED or GG.CHD_CULTURE is not declared in " + path]
    want = dict((F["culture"], (tag, F["feed"])) for tag, F in FLAVOURS.items())
    out = []
    for c in sorted(set(want) | set(got)):
        if got.get(c) != want.get(c):
            out.append("GG.FLAVOURED gives %s %r and the generator mints %r - that race "
                       "reads raw keys or messages that draw nothing"
                       % (c, got.get(c), want.get(c)))
    return out


```

In `check()`, replace `    out += check_hire_units()` with

```python
    out += check_hire_units()
    out += check_flavour_mirror()
```

- [ ] **Step 7: Run the harness and the generator to verify they pass**

```bash
cd "/g/Modding for resources" && "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua && py tools/gen_great_guilds.py --selftest && py tools/gen_great_guilds.py --check
```

Expected: `harness ok`; `selftest ok: ...`; `--check` exits 0 with no `PROBLEM:` lines.

- [ ] **Step 8: Gate**

```bash
cd "/g/Modding for resources" && for f in zzz_derpy_guilds zzz_derpy_guilds_ai; do "/c/Program Files (x86)/Lua/5.1/luac.exe" -p "Modding Files/pack/script/campaign/mod/$f.lua" || echo "LUAC FAILED $f"; done; py tools/check_lua_api.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua" "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua"; py tools/check_lua_undeclared.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua" "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua"; py tools/import_great_guilds.py --check
```

Expected: no `LUAC FAILED`, both checkers report nothing and exit 0, `verify ok`. (`check_lua_api.py` takes one path per run in some versions - if it rejects two, run it once per file.)

---

### Task 3: Panel Lua - loc, art paths, crest and opener

**Files:**
- Modify: `Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua` (lines 121-127, 156, 534, 607, 734, 740, 856, 870, 900, `GGUI.refresh` near 928, `GGUI.place_opener` near 2073)
- Modify: `tools/_guilds_harness.lua` (new block at the end)
- Modify: `tools/gen_guilds_ui.py` (new `check_opener_crest`, wired into `check()`)

**Interfaces:**
- Consumes: `GG.tag(faction)`, `GG.bounty_mission_key(guild, faction)` from Task 2; the tagged loc keys from Task 1.
- Produces (Lua): `GGUI.me() -> faction | nil`, `GGUI.tag() -> string`, `GGUI.art(path) -> path | nil`, `GGUI.icon(guild) -> path | nil`, `GGUI.CREST` (the untagged crest path), `GGUI.paint_crest()`, `GGUI.paint_opener(b)`.
- Produces (Python): `gen_guilds_ui.check_opener_crest(lua) -> [str]`.

- [ ] **Step 1: Write the failing harness test**

In `tools/_guilds_harness.lua`, insert immediately above the final `print("harness ok")`:

```lua
-- THE PANEL READS THE LOCAL PLAYER'S FLAVOUR: tagged loc keys, tagged art, and the crest
-- and the opener repainted - and a player of a culture with no flavour reads the Chaos
-- Dwarf words and art, with nothing repainted.
;(function()
    local E, L = "cr_flav_ui_emp", "cr_flav_ui_lzd"
    CULTURE[E], CULTURE[L] = "wh_main_emp_empire", "wh2_main_lzd_lizardmen"
    GG.CULTURE_OF[E], GG.CULTURE_OF[L] = nil, nil
    local prev_local, me = cm.get_local_faction_name, E
    cm.get_local_faction_name = function() return me end
    local asked = {}
    common = {get_localised_string = function(k) asked[#asked + 1] = k return "x" end}

    GGUI.loc("guild_name_brass")
    assert(asked[#asked] == "derpy_gg_guild_name_brass_emp",
           "an Empire player's panel must ask for the _emp key, asked "
           .. tostring(asked[#asked]))
    GGUI.bounty_title({guild = "brass"})
    assert(asked[#asked] == "missions_localised_title_derpy_gg_bounty_brass_emp",
           "an Empire bounty's title is the Empire row's, asked " .. tostring(asked[#asked]))
    assert(GGUI.icon("brass") == "ui/campaign ui/derpy_gg_icons/brass_emp.png",
           tostring(GGUI.icon("brass")))
    assert(GGUI.art(GGUI.PANEL_BG.brass) == "ui/campaign ui/derpy_gg_bg/brass_emp.png")
    assert(GGUI.art(GGUI.CREST) == "ui/campaign ui/derpy_gg_icons/crest_emp.png")
    assert(GGUI.art(nil) == nil, "no path stays no path")

    local painted = {}
    local fake = {SetImagePath = function(_, p, i) painted[#painted + 1] = p .. "#" .. i end}
    local prev_find, prev_is = find_uicomponent, is_uicomponent
    find_uicomponent = function(_, name)
        if name == "gg_crest" then return fake end
        return nil
    end
    is_uicomponent = function(x) return x == fake end
    GGUI.paint_crest()
    GGUI.paint_opener(fake)
    local c = "ui/campaign ui/derpy_gg_icons/crest_emp.png"
    assert(table.concat(painted, ",") == c .. "#0," .. c .. "#2," .. c .. "#5",
           "the crest is image 0 of gg_crest and images 2 and 5 of the opener, got "
           .. table.concat(painted, ","))

    me = L
    painted = {}
    GGUI.loc("guild_name_brass")
    assert(asked[#asked] == "derpy_gg_guild_name_brass",
           "a Lizardmen player reads the untagged key, asked " .. tostring(asked[#asked]))
    assert(GGUI.icon("brass") == GGUI.GUILD_ICON.brass)
    GGUI.paint_crest()
    GGUI.paint_opener(fake)
    assert(#painted == 0, "an untagged crest is left as the .twui.xml drew it")

    find_uicomponent, is_uicomponent = prev_find, prev_is
    common = nil
    cm.get_local_faction_name = prev_local
    CULTURE[E], CULTURE[L], GG.CULTURE_OF[E], GG.CULTURE_OF[L] = nil, nil, nil, nil
end)()
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `cd "/g/Modding for resources" && "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua`
Expected: FAIL with `an Empire player's panel must ask for the _emp key, asked derpy_gg_guild_name_brass`.

- [ ] **Step 3: Implement the panel Lua**

In `zzz_derpy_guilds_ui.lua`, replace

```lua
function GGUI.loc(key)
    local ok, s = pcall(function()
        return common.get_localised_string("derpy_gg_" .. key)
    end)
```

with

```lua
-- WHOSE FLAVOUR THE PANEL SPEAKS: the local player's. Forced read, because an unforced
-- get_local_faction_name throws in multiplayer; nil when it cannot be read.
function GGUI.me()
    local ok, me = pcall(function() return cm:get_local_faction_name(true) end)
    if ok and me then return me end
    return nil
end

function GGUI.tag() return GG.tag(GGUI.me()) end

-- OUR ART IN THE READER'S FLAVOUR: the tag goes before ".png", so brass.png is
-- brass_emp.png for an Empire player. gen_guilds_ui.check() asserts every tagged path is
-- staged - a missing one draws a blank square and logs nothing.
function GGUI.art(path)
    if not path then return nil end
    local tag = GGUI.tag()
    if tag == "" then return path end
    return (string.gsub(path, "%.png$", tag .. ".png"))
end

function GGUI.icon(guild) return GGUI.art(GGUI.GUILD_ICON[guild]) end

-- The crest beside the title and on the HUD opener. Both .twui.xml files draw this path;
-- a flavoured player's is repainted over it by GGUI.paint_crest and GGUI.paint_opener.
GGUI.CREST = "ui/campaign ui/derpy_gg_icons/crest.png"

function GGUI.loc(key)
    local ok, s = pcall(function()
        return common.get_localised_string("derpy_gg_" .. key .. GGUI.tag())
    end)
```

In `GGUI.paint_ground`, replace `local path = GGUI.PANEL_BG[guild]` with `local path = GGUI.art(GGUI.PANEL_BG[guild])`.

Replace both occurrences of `GG.bounty_mission_key(o.guild)` in this file with `GG.bounty_mission_key(o.guild, GGUI.me())` (in `GGUI.bounty_title` and in the bounty card's tooltip).

Replace `ic:SetImagePath(GGUI.GUILD_ICON[GGUI.current_guild()] or "", 0)` with `ic:SetImagePath(GGUI.icon(GGUI.current_guild()) or "", 0)`.
Replace `ic:SetImagePath(GGUI.GUILD_ICON[o.guild] or "", 0)` with `ic:SetImagePath(GGUI.icon(o.guild) or "", 0)`.
Replace `GGUI.write_card(1, GGUI.GUILD_ICON[d.guild],` with `GGUI.write_card(1, GGUI.icon(d.guild),`.
Replace both occurrences of `GGUI.GUILD_ICON[guild],` with `GGUI.icon(guild),` (cards 2 and 3).
Confirm with `grep -n "GUILD_ICON\[" "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua"` that only `GGUI.icon`'s own line remains.

Directly below `function GGUI.paint_ground(guild) ... end` insert:

```lua

-- THE CREST BESIDE THE TITLE, in the reader's flavour. Image 0 is its only image. A
-- Chaos Dwarf player keeps what the .twui.xml draws, so nothing is called for them.
function GGUI.paint_crest()
    local path = GGUI.art(GGUI.CREST)
    if path == GGUI.CREST then return end
    local c = comp("gg_crest")
    if c then pcall(function() c:SetImagePath(path, 0) end) end
end

-- AND ON THE HUD OPENER. Images 2 and 5 are the glyph in the standard and hover states -
-- derpy_gg_opener.twui.xml lists the standard layers and then the hover ones, three each,
-- and gen_guilds_ui.check_opener_crest pins both numbers against that order.
function GGUI.paint_opener(b)
    local path = GGUI.art(GGUI.CREST)
    if path == GGUI.CREST then return end
    pcall(function()
        b:SetImagePath(path, 2)
        b:SetImagePath(path, 5)
    end)
end
```

In `GGUI.refresh`, replace

```lua
    GGUI.paint_ground(GGUI.ground_guild())
```

with

```lua
    GGUI.paint_ground(GGUI.ground_guild())
    GGUI.paint_crest()
```

In `GGUI.place_opener`, replace

```lua
    set_tooltip(b, GGUI.loc("panel_title") .. "||" .. GGUI.loc("standing_help"))
```

with

```lua
    set_tooltip(b, GGUI.loc("panel_title") .. "||" .. GGUI.loc("standing_help"))
    GGUI.paint_opener(b)
```

- [ ] **Step 4: Pin the opener's image numbers in gen_guilds_ui**

In `tools/gen_guilds_ui.py`, insert directly above `def check():` (the one whose docstring is "Refuses to write on anything that is a silent non-draw in game."):

```python
def check_opener_crest(lua):
    """The crest repaints go by IMAGE INDEX, so their numbers must be where the crest sits.

    derpy_gg_opener lists OPENER_LAYERS and then OPENER_HOVER; gg_crest has CREST_LAYERS.
    A wrong number repaints the button's plate with a crest and leaves the old crest on
    top, which is wrong on screen and says nothing.
    """
    out = []
    for fn_name, layers, crest in (
            ("paint_opener", OPENER_LAYERS + OPENER_HOVER, OPENER_ICON),
            ("paint_crest", CREST_LAYERS, CREST_LAYERS[0]["path"])):
        want = [i for i, l in enumerate(layers) if l["path"] == crest]
        fn = re.search(r"function GGUI\.%s\(b?\)(.*?)\nend" % fn_name, lua, re.S)
        if not fn:
            out.append("zzz_derpy_guilds_ui.lua has no GGUI.%s, so a flavoured player "
                       "keeps the Chaos Dwarf crest there" % fn_name)
            continue
        got = sorted(int(x) for x in re.findall(r"SetImagePath\(path,\s*(\d+)\)",
                                                 fn.group(1)))
        if got != want:
            out.append("GGUI.%s repaints image(s) %r and the crest is image(s) %r"
                       % (fn_name, got, want))
    return out


```

and in `check()`, replace `        out += check_panel_bg(lua_src)` with

```python
        out += check_panel_bg(lua_src)
        out += check_opener_crest(lua_src)
```

- [ ] **Step 5: Run the harness to verify it passes**

Run: `cd "/g/Modding for resources" && "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua`
Expected: `harness ok`.

- [ ] **Step 6: Gate**

```bash
cd "/g/Modding for resources" && "/c/Program Files (x86)/Lua/5.1/luac.exe" -p "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua" && py tools/check_lua_api.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua" && py tools/check_lua_undeclared.py "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua" && py tools/gen_guilds_ui.py --selftest && py tools/gen_guilds_ui.py --check && py tools/check_guilds_ui.py && py tools/check_guilds_anchor.py && py tools/gen_great_guilds.py --check
```

Expected: every command exits 0. The flavoured art is not checked until Task 4 Step 1, so `gen_guilds_ui.py --check` is clean here; if it reports a `paint_opener` or `paint_crest` line, the image numbers in Step 3 are wrong.

---

### Task 4: Art - icons, grounds, their checks, and the flavoured preview

**Files:**
- Modify: `tools/gen_guilds_ui.py` (new `flavoured`; GUILD_ICON block near 1175; sizes block near 1103-1113; `check_panel_bg` near 973-987)
- Modify: `tools/make_guild_icons.py`
- Modify: `tools/make_guild_backgrounds.py`
- Modify: `tools/ui_icon_sizes.json`
- Modify: `tools/preview_guilds_panel.py`
- Write (generated, never published): `Modding Files/source/guild_icons/*.png` (14 new), `Modding Files/pack/ui/campaign ui/derpy_gg_icons/*_emp.png|*_dwf.png` (14), `Modding Files/pack/ui/campaign ui/derpy_gg_bg/*_emp.png|*_dwf.png` (12)

**Interfaces:**
- Consumes: `gen_great_guilds.FLAVOURS` and `.GUILDS` (Task 1); the paths `GGUI.art` builds (Task 3: tag before ".png").
- Produces: `gen_guilds_ui.flavoured(path, tag) -> str`; `make_guild_icons.fetch(stem) -> None | str`; `make_guild_backgrounds.CA_ART`, `WINDOWS`, `CA_BACKGROUNDS`, `ca_picture(pack_path)`; `preview_guilds_panel.render(path=None, guild=None, tag="")` and the `--flavour emp|dwf` option.

- [ ] **Step 1: Write the failing art checks**

In `tools/gen_guilds_ui.py`, insert directly above `def _assets():`:

```python
def flavoured(path, tag):
    """The path the panel Lua builds for a flavour: the tag before ".png" (GGUI.art)."""
    return path[:-len(".png")] + tag + ".png" if tag else path


```

In the GUILD_ICON block of `check()`, replace

```python
                for g in GEN.GUILDS:
                    if g not in named:
                        out.append("GGUI.GUILD_ICON has no entry for %s" % g)
                    elif named[g] not in assets:
                        out.append("GGUI.GUILD_ICON[%s] does not exist in any ui "
                                   "pack: %s" % (g, named[g]))
```

with

```python
                tags = [t for t in GEN.FLAVOURS if t]
                for g in GEN.GUILDS:
                    if g not in named:
                        out.append("GGUI.GUILD_ICON has no entry for %s" % g)
                    elif named[g] not in assets:
                        out.append("GGUI.GUILD_ICON[%s] does not exist in any ui "
                                   "pack: %s" % (g, named[g]))
                    else:
                        for tag in tags:
                            if flavoured(named[g], tag) not in assets:
                                out.append("GGUI.GUILD_ICON[%s] has no %s copy - %s is "
                                           "not staged, so that race's cards draw a "
                                           "blank square"
                                           % (g, tag, flavoured(named[g], tag)))
                for tag in tags:
                    if flavoured(OPENER_ICON, tag) not in assets:
                        out.append("the %s crest %s is not staged - GGUI.paint_crest and "
                                   "GGUI.paint_opener would paint a blank square"
                                   % (tag, flavoured(OPENER_ICON, tag)))
```

In the sizes block, replace

```python
                for _g, _p in re.findall(r'(\w+)\s*=\s*"([^"]+)"', m.group(1)):
                    drawn.append((_p, box))
        for path, px in drawn:
```

with

```python
                for _g, _p in re.findall(r'(\w+)\s*=\s*"([^"]+)"', m.group(1)):
                    drawn.append((_p, box))
        # EVERY FLAVOUR'S COPY is drawn in the same box as ours.
        ours = [(p, px) for p, px in drawn if "derpy_gg_icons/" in p]
        for tag in [t for t in G.FLAVOURS if t]:
            drawn += [(flavoured(p, tag), px) for p, px in ours]
        for path, px in drawn:
```

In `check_panel_bg()`, replace

```python
    for extra in sorted(set(got) - set(G.GUILDS)):
```

with

```python
    for tag in [t for t in G.FLAVOURS if t]:
        for guild in G.GUILDS:
            path = got.get(guild)
            if not path:
                continue
            fpath = flavoured(path, tag)
            disk = os.path.join(ROOT, "Modding Files", "pack", *fpath.split("/"))
            if not os.path.isfile(disk):
                out.append("GGUI.PANEL_BG[%s] has no %s ground - %s is not staged, so "
                           "that race's panel keeps whichever ground was painted last"
                           % (guild, tag, fpath))
    for extra in sorted(set(got) - set(G.GUILDS)):
```

In `tools/make_guild_icons.py`, `selftest()`, insert directly above `print("selftest ok: ...")`:

```python
    # EVERY FLAVOUR has all six guild icons and a crest, each from its own source.
    names = set(ICONS.values())
    assert len(names) == len(ICONS), "two sources ship under one name"
    for tag in ("", "_emp", "_dwf"):
        for g in ("brass", "immortals", "daemonsmiths", "khanate", "overseers",
                  "slavers", "crest"):
            assert g + tag in names, "no icon ships as " + g + tag
```

In `tools/make_guild_backgrounds.py`, `selftest()`, insert directly above its `print("selftest ok: ...")`:

```python
    # EVERY FLAVOUR has a ground per guild, each a different window of its race's picture,
    # and every window is the panel's size and inside the painting.
    for race in CA_ART:
        mine = dict((n[:-len(race) - 1], w) for n, (r, w) in CA_BACKGROUNDS.items()
                    if r == race)
        assert sorted(mine) == sorted(BACKGROUNDS), (race, sorted(mine))
        assert sorted(mine.values()) == sorted(WINDOWS), (race, mine)
    for x0, y0, x1, y1 in WINDOWS.values():
        assert (x1 - x0, y1 - y0) == (PANEL_W, PANEL_H), (x0, y0, x1, y1)
        assert 0 <= x0 and x1 <= 1920 and 0 <= y0 and y1 <= 1200, (x0, y0, x1, y1)
```

- [ ] **Step 2: Run the checks to verify they fail**

```bash
cd "/g/Modding for resources" && py tools/gen_guilds_ui.py --check | grep -c "_emp\|_dwf"; py tools/make_guild_icons.py --selftest; py tools/make_guild_backgrounds.py --selftest
```

Expected: a non-zero count of `_emp`/`_dwf` findings (icons, crests, grounds); `make_guild_icons.py --selftest` FAILS with `no icon ships as brass_emp`; `make_guild_backgrounds.py --selftest` FAILS with `NameError: name 'CA_ART' is not defined`.

- [ ] **Step 3: Implement the icons**

In `tools/make_guild_icons.py`, replace

```python
    "chd_tower_tribute_halls": "crest",
}
```

with

```python
    "chd_tower_tribute_halls": "crest",
    # EMPIRE and DWARFS. CA's own building icons for the same six trades, each measured a
    # flat silhouette (commonest colour 100% of visible pixels, 74x74, 2026-09-23).
    # dwarf_hall_of_oaths (51%) and dwf_underdeep_grudges (69%) were the first picks and
    # are textured - build() refuses them, which is why the crest and the Grudge-Settlers
    # are the Karaz-a-Karak and slayer-cult icons instead.
    "empire_port": "brass_emp",
    "empire_barracks": "immortals_emp",
    "empire_gunnery_school": "daemonsmiths_emp",
    "empire_tavern": "khanate_emp",
    "empire_walls": "overseers_emp",
    "empire_shooting_range": "slavers_emp",
    "empire_imperial_cult": "crest_emp",
    "dwarf_trade_depot": "brass_dwf",
    "dwarf_barracks": "immortals_dwf",
    "dwarf_engineering": "daemonsmiths_dwf",
    "dwarf_rangers": "khanate_dwf",
    "dwarf_industry": "overseers_dwf",
    "dwarf_slayer_cult": "slavers_dwf",
    "dwarf_city_karaz_a_karak": "crest_dwf",
}

UI_PACK = os.path.join(r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III",
                       "data", "ui.pack")
CA_ICON = "ui/buildings/icons/%s.png"


def fetch(stem):
    """Copy CA's original of one source icon into SRC, read offline out of ui.pack.

    CA's ui art is COMPRESSED in the pack - a u32 length and then a zstd frame - so a
    byte-grep finds the path and not a usable PNG; read_vanilla_loc._decompress strips
    that wrapper. Returns None on success, or why it could not.
    """
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import read_pack_index as rpi
    import read_vanilla_loc as rvl
    want = CA_ICON % stem
    try:
        hits = [h for h in rpi.read(UI_PACK, want) if h[0].lower() == want]
    except (IOError, OSError, ValueError) as e:
        return "cannot read %s: %s" % (UI_PACK, e)
    if not hits:
        return "%s is not in %s" % (want, UI_PACK)
    _path, comp, data = hits[0]
    if comp:
        data = rvl._decompress(data)
    if not os.path.isdir(SRC):
        os.makedirs(SRC)
    with open(os.path.join(SRC, stem + ".png"), "wb") as fh:
        fh.write(data)
    return None
```

In `build()`, replace

```python
        src = os.path.join(SRC, stem + ".png")
        if not os.path.isfile(src):
            out.append("missing source icon: %s" % src)
            continue
```

with

```python
        src = os.path.join(SRC, stem + ".png")
        if not os.path.isfile(src) and write:
            why = fetch(stem)
            if why:
                out.append("%s: %s" % (stem, why))
                continue
        if not os.path.isfile(src):
            out.append("missing source icon: %s" % src)
            continue
```

- [ ] **Step 4: Implement the grounds**

In `tools/make_guild_backgrounds.py`, insert directly after the `BACKGROUNDS = { ... }` dict:

```python

# THE EMPIRE AND THE DWARFS PAN ONE PAINTING EACH: six 790x700 windows out of the race's
# loading-screen art, so paging from guild to guild moves across one picture. Native
# resolution, so no crop-and-scale; the brightness gate below is the same one. Boxes
# chosen by rendering all six and looking (2026-09-23): the top row starts at y=200
# because at y=160 the frame's foliage showed.
GAME_UI = os.path.join(r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III",
                       "data", "ui.pack")
CA_ART = {
    "emp": "ui/loading_ui/load_images/campaign_empire1.png",
    "dwf": "ui/loading_ui/load_images/campaign_dwarfs1.png",
}
WINDOWS = {
    1: (200, 200, 990, 900), 2: (565, 200, 1355, 900), 3: (930, 200, 1720, 900),
    4: (200, 330, 990, 1030), 5: (565, 330, 1355, 1030), 6: (930, 330, 1720, 1030),
}
CA_BACKGROUNDS = {
    "brass_emp": ("emp", 1), "overseers_emp": ("emp", 2),
    "daemonsmiths_emp": ("emp", 3), "immortals_emp": ("emp", 4),
    "slavers_emp": ("emp", 5), "khanate_emp": ("emp", 6),
    "brass_dwf": ("dwf", 1), "immortals_dwf": ("dwf", 2),
    "slavers_dwf": ("dwf", 3), "overseers_dwf": ("dwf", 4),
    "khanate_dwf": ("dwf", 5), "daemonsmiths_dwf": ("dwf", 6),
}
_PICTURES = {}


def ca_picture(pack_path):
    """A CA ui picture, read offline: zstd behind a u32 length when compressed."""
    if pack_path not in _PICTURES:
        import io
        from PIL import Image
        sys.path.insert(0, os.path.join(ROOT, "tools"))
        import read_pack_index as rpi
        import read_vanilla_loc as rvl
        hits = [h for h in rpi.read(GAME_UI, pack_path) if h[0].lower() == pack_path]
        if not hits:
            raise IOError("%s is not in %s" % (pack_path, GAME_UI))
        _path, comp, data = hits[0]
        if comp:
            data = rvl._decompress(data)
        _PICTURES[pack_path] = Image.open(io.BytesIO(data)).convert("RGB")
    return _PICTURES[pack_path]
```

In `build()`, replace

```python
    return out, made


def check():
```

with

```python
    for name in sorted(CA_BACKGROUNDS):
        race, window = CA_BACKGROUNDS[name]
        try:
            src = ca_picture(CA_ART[race])
        except (IOError, OSError, ValueError) as e:
            out.append("%s: %s" % (name, e))
            continue
        im, factor = darken(src.crop(WINDOWS[window]), max_p99, max_peak)
        p99, peak = measure(im)
        if p99 > max_p99 + 0.5 or peak > max_peak + 0.5:
            out.append("%s: window %d of %s cannot be darkened into the ground's numbers"
                       % (name, window, CA_ART[race]))
            continue
        dst = os.path.join(DST, name + ".png")
        if write:
            im.save(dst, optimize=True)
        made.append((name, "%s #%d" % (CA_ART[race].rsplit("/", 1)[-1], window), factor,
                     p99, peak, os.path.getsize(dst) if os.path.isfile(dst) else 0))
    return out, made


def check():
```

In `check()`, replace `    for guild in sorted(BACKGROUNDS):` with `    for guild in sorted(BACKGROUNDS) + sorted(CA_BACKGROUNDS):` (the loop in `check()`, not the one in `build()`).

- [ ] **Step 5: Build the art and record the icon sizes**

```bash
cd "/g/Modding for resources" && py tools/make_guild_icons.py --selftest && py tools/make_guild_icons.py && py tools/make_guild_backgrounds.py --selftest && py tools/make_guild_backgrounds.py && py -c "
import io, json
from PIL import Image
p = 'tools/ui_icon_sizes.json'
d = json.load(io.open(p, encoding='utf-8'))
for tag in ('_emp', '_dwf'):
    for n in ('brass', 'immortals', 'daemonsmiths', 'khanate', 'overseers', 'slavers', 'crest'):
        rel = 'ui/campaign ui/derpy_gg_icons/%s%s.png' % (n, tag)
        d[rel] = Image.open('Modding Files/pack/' + rel).size[0]
json.dump(d, io.open(p, 'w', encoding='utf-8'), indent=1, sort_keys=True)
print('sizes recorded')" < /dev/null
```

Expected: both selftests ok; `make_guild_icons.py` lists 21 icons at 74x74 with no `PROBLEM:`; `make_guild_backgrounds.py` lists 18 grounds, each with a factor at or below 1.00, no `PROBLEM:`; `sizes recorded`.

- [ ] **Step 6: Run the checks to verify they pass**

```bash
cd "/g/Modding for resources" && py tools/make_guild_backgrounds.py --check && py tools/gen_guilds_ui.py --check
```

Expected: both exit 0 with no `PROBLEM:` lines.

- [ ] **Step 7: Give the preview a flavour**

In `tools/preview_guilds_panel.py`, delete the `DEMO_GUILDS = (...)` constant (two lines). Replace

```python
def render(path=None, guild=None):
```

with

```python
def render(path=None, guild=None, tag=""):
```

Replace

```python
        ground = Path(os.path.join(OURS, "derpy_gg_bg", guild + ".png"))
```

with

```python
        ground = Path(os.path.join(OURS, "derpy_gg_bg", guild + tag + ".png"))
```

Replace

```python
            if ground is not None and p == G.PANEL_ART:
                asset = ground
```

with

```python
            if ground is not None and p == G.PANEL_ART:
                asset = ground
            # OUR OWN ART is not in CA's packs, so it is read where it is staged, in the
            # flavour asked for - the Lua appends the same tag at runtime (GGUI.art).
            if p.startswith("ui/campaign ui/derpy_gg_"):
                stem, ext = os.path.splitext(os.path.relpath(p, "ui/campaign ui"))
                asset = Path(os.path.join(OURS, stem + tag + ext))
```

Replace

```python
    for i, g in enumerate(DEMO_GUILDS):
```

with

```python
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import gen_great_guilds as GEN
    for i, g in enumerate(GEN.FLAVOURS[tag]["guilds"][k] for k in GEN.GUILDS):
```

Replace

```python
    out = path or os.path.join(CACHE, "gg_standings%s.png"
                               % (guild and "_" + guild or ""))
```

with

```python
    out = path or os.path.join(CACHE, "gg_standings%s%s.png"
                               % (guild and "_" + guild or "", tag))
```

In the `__main__` block, replace

```python
        want = [a for a in sys.argv[1:] if not a.startswith("--")]
        out, n_art, missing, (shown, total) = render(guild=want[0] if want else None)
```

with

```python
        args = sys.argv[1:]
        tag = ""
        if "--flavour" in args:
            at = args.index("--flavour")
            tag = "_" + args[at + 1]
            del args[at:at + 2]
        want = [a for a in args if not a.startswith("--")]
        out, n_art, missing, (shown, total) = render(guild=want[0] if want else None,
                                                     tag=tag)
```

- [ ] **Step 8: Look at each race's panel**

```bash
cd "/g/Modding for resources" && py tools/preview_guilds_panel.py --selftest && for g in brass immortals daemonsmiths khanate overseers slavers; do py tools/preview_guilds_panel.py $g --flavour emp; py tools/preview_guilds_panel.py $g --flavour dwf; done; py tools/preview_guilds_panel.py brass
```

Expected: `selftest ok`, then one `wrote ...gg_standings_<guild>_emp.png` / `_dwf.png` line per run. Open at least `gg_standings_brass_emp.png`, `gg_standings_khanate_dwf.png` and `gg_standings_brass.png` in `.skilltree_cache/ui_preview/` with the Read tool and confirm: the six names are that race's, the crest is that race's, the ground is a window of that race's painting and not a frame edge, and the Chaos Dwarf one looks as it did. Glyph widths are PIL's, so this answers "is it the right art and the right words", not "does the label fit".

---

### Task 5: Pack, verify and record

**Files:**
- Write: `Modding Files/Modpacks/derpy_great_guilds.pack` (via `import_great_guilds.py`)
- Modify: `tools/sync_guilds_repo.py` (MANIFEST: add this plan)
- Modify: `docs/SESSION_INDEX.md` (one line)
- Create: `docs/sessions/HANDOFF_20260923_GUILDS_FLAVOURS.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a packed build and its handoff.

- [ ] **Step 1: The full gate**

```bash
cd "/g/Modding for resources" && "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_harness.lua && for f in zzz_derpy_guilds zzz_derpy_guilds_ai zzz_derpy_guilds_ui; do "/c/Program Files (x86)/Lua/5.1/luac.exe" -p "Modding Files/pack/script/campaign/mod/$f.lua" || echo "LUAC FAILED $f"; done; py tools/gen_great_guilds.py --selftest && py tools/gen_great_guilds.py --write && py tools/gen_great_guilds.py --check && py tools/gen_guilds_ui.py --selftest && py tools/gen_guilds_ui.py --check && py tools/check_guilds_ui.py && py tools/check_guilds_anchor.py && py tools/make_guild_icons.py --check && py tools/make_guild_backgrounds.py --check && py tools/preview_guilds_panel.py --check && py tools/import_great_guilds.py --check
```

Expected: `harness ok`, no `LUAC FAILED`, every tool exits 0, `verify ok - 127 bundles, ...`.

- [ ] **Step 2: Confirm RPFM is open**

In PowerShell: `Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing`
Expected: HTTP 200. Connection refused means RPFM is closed - say so to the user and stop here; never fall back to editing the pack as text.

- [ ] **Step 3: Pack**

Run: `cd "/g/Modding for resources" && py tools/import_great_guilds.py`
Expected: `verify ok`, the import log, then the post-save read-back with no `FAILED:` lines.

- [ ] **Step 4: Verify the pack's content, not just its presence**

```bash
cd "/g/Modding for resources" && py -c "
import sys; sys.path.insert(0, 'tools'); import read_pack_index as rpi
ps = rpi.paths('Modding Files/Modpacks/derpy_great_guilds.pack')
icons = [p for p in ps if 'derpy_gg_icons/' in p]
grounds = [p for p in ps if 'derpy_gg_bg/' in p]
print(len(icons), 'icons', len(grounds), 'grounds')
for want in ('ui/campaign ui/derpy_gg_icons/crest_emp.png', 'ui/campaign ui/derpy_gg_icons/crest_dwf.png',
             'ui/campaign ui/derpy_gg_bg/brass_emp.png', 'ui/campaign ui/derpy_gg_bg/daemonsmiths_dwf.png'):
    print(want in ps, want)" < /dev/null
```

Expected: `21 icons 18 grounds` and four `True` lines. Also compare the pack's size and file count against the pre-flavour build `Modding Files/Modpacks/derpy_great_guilds.pack.bak_20260923_pre_rankflip`: roughly 7.7MB larger, 26 more files.

- [ ] **Step 5: Record**

Add `("docs/superpowers/plans/2026-09-23-great-guilds-flavours.md", "docs/plans/2026-09-23-great-guilds-flavours.md"),` to the doc list in `tools/sync_guilds_repo.py`'s MANIFEST, after the notices plan's entry. No art entries - the NO ART comment there stays true.

Write `docs/sessions/HANDOFF_20260923_GUILDS_FLAVOURS.md`: what shipped (tags, row counts, art), the MD5 of the packed build, the one Chaos Dwarf text change (the MISSION bullet), the known ceiling (an Empire or Dwarf save from an earlier build keeps its untagged bundles - spec section 2), and the in-game checks still owed:

1. Start an Empire campaign: panel names, crest on the HUD opener and beside the title, ground changes per guild.
2. Reach rank 2 with any guild: the promotion message in Empire words with the `emp/civilisation_up` picture; the Faction Effects title of the rank bundle.
3. Take a bounty: its title and `emp/generic` picture in the objectives panel.
4. Repeat 1-3 in a Dwarf campaign.
5. A Chaos Dwarf campaign: nothing changed except the one Help bullet.

Add ONE line to `docs/SESSION_INDEX.md` pointing at the handoff.

- [ ] **Step 6: Deploy only on request**

Do not copy the pack into the game's `data/` folder or the Workshop folder unless the user asks. When they do: confirm the game is closed (`tasklist | findstr /i Warhammer3` prints nothing), back up the current `data/derpy_great_guilds.pack`, copy, and compare MD5s of the copy and the source.
