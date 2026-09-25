"""The Great Guilds - generator. See docs/superpowers/specs/2026-09-10-great-guilds-design.md"""
import io
import os
import re
import sys

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


def extra_sentence(guild, rank):
    """The second effect's clause in a rank bundle's description, or nothing."""
    extra = RANK_EFFECTS_EXTRA.get(guild)
    if not extra or extra[2][rank] is None:
        return ""
    blurb, reach = EFFECT_BLURB_EXTRA[guild]
    return " %s, for %s." % (blurb % extra[2][rank], reach)


def bundle_key(guild, rank):
    """Effect bundle for a guild at a rank. Ranks 2-5 only; rank 1 grants nothing."""
    assert 2 <= rank <= 5, "rank 1 has no bundle"
    return "derpy_gg_rank_%s_%d" % (guild, rank)


# One (effect_key, effect_scope) pair per guild. Every pair below was read out of
# vanilla's own effect_bundles_to_effects_junctions on 2026-09-10 - these are
# combinations CA actually ships, not guesses. Scope is not a free choice, and an
# "_unseen" scope hides the effect from the player, so none of these carry it.
RANK_EFFECTS = {
    # NOT economy_trade_tariff_mod, which this shipped as. That effect is a percentage
    # of TRADE TARIFF income, and a Chaos Dwarf faction with no trade agreements has
    # none - so the whole Brass ladder and Writ of Monopoly paid exactly zero, correctly
    # wired, for the guild the player feeds most. Reported from a live campaign on
    # 2026-09-16 as "the trade per turn didn't work". gdp_mod_all is a percentage of
    # income from every building the faction owns, which is a base every faction has;
    # 29 vanilla rows on this exact pair, values -20 to +50, so the 3/6/10/15 ladder and
    # the service's 32 all sit inside vanilla's own range and check()'s magnitude guard
    # passes unchanged. The EARN route is untouched - reputation still accrues from net
    # income, which is what GUILD_DESC and EARN_SHORT describe.
    "brass":        ("wh_main_effect_economy_gdp_mod_all", "faction_to_region_own"),
    # NOT force_army_campaign_recruitment_points, which this shipped as. That effect
    # has 8 vanilla rows and a maximum value of 2 - it is a flat count of recruitment
    # slots, and the ladder was putting 15 on it while a rank-4 service put 60.
    # Replenishment is a percentage like the other five, and every number this mod
    # emits sits inside vanilla's own range for it (75 rows, -15 to +80).
    "immortals":    ("wh_main_effect_force_all_campaign_replenishment_rate",
                     "faction_to_force_own"),
    "daemonsmiths": ("wh_main_effect_technology_research_rate_mod", "faction_to_faction_own"),
    "khanate":      ("wh_main_effect_agent_recruitment_cost_mod", "faction_to_province_own"),
    "overseers":    ("wh2_dlc11_effect_building_construction_cost_mod_all_settlement",
                     "faction_to_region_own"),
    "slavers":      ("wh_main_effect_force_all_campaign_sacking_income",
                     "faction_to_faction_own"),
}

# A SECOND EFFECT ON THE RANK LADDER, for guilds that want one. Its own value ladder,
# indexed 1-5 like RANK_VALUES, because the shared 3/6/10/15 is built for percentages and
# this one is a flat count of recruitment slots whose vanilla maximum is 2. None at rank
# 2, then 1 / 2 / 3 - the top of which is exactly the range guard's ceiling.
#
# Services do NOT carry this: a rank bundle is permanent and a service is a burst, and
# stacking a temporary +2 on a permanent +3 would put five slots on one army from a
# system that is meant to top out at three.
RANK_EFFECTS_EXTRA = {
    "immortals": ("wh_main_effect_force_army_campaign_recruitment_points",
                  "faction_to_faction_own",
                  [None, None, None, 1, 2, 3]),
}

# How the second effect reads, alongside the guild's main one.
EFFECT_BLURB_EXTRA = {
    "immortals": ("%+d recruitment capacity", "your faction"),
}

# is_positive_value_good, read out of vanilla's own effects table on 2026-09-10.
# TWO of the six are FALSE, because they are *cost* modifiers: a positive value on
# agent_recruitment_cost_mod or building_construction_cost_mod_all_settlement makes
# the thing MORE expensive. Feeding those a positive rank value turns the whole
# ladder into a penalty that rises as the player earns it, drawn in red as a malus.
# So the value carries a sign per guild, and check() refuses if the two ever disagree.
EFFECT_GOOD_SIGN = {
    "brass":        1,    # income from all buildings - positive is good
    "immortals":    1,    # army replenishment rate  - positive is good
    "daemonsmiths": 1,    # research rate            - positive is good
    "khanate":      -1,   # agent recruitment COST   - positive is BAD
    "overseers":    -1,   # construction COST        - positive is BAD
    "slavers":      1,    # sacking income           - positive is good
}

# How each guild's effect reads to a player, and whether the number is a percentage.
# "%+d" is filled with the signed value, so a cost reduction reads "-15%".
# The same reach, told from the victim's side. A hostile service lands on the enemy,
# so "every province you own" would name the wrong faction's provinces.
EFFECT_REACH_THEIRS = {
    "brass":        "their regions",
    "immortals":    "their armies",
    "daemonsmiths": "their faction",
    "khanate":      "their provinces",
    "overseers":    "their regions",
    "slavers":      "their armies",
}

EFFECT_BLURB = {
    "brass":        ("%+d%% income from all buildings", "every region you own"),
    "immortals":    ("%+d%% replenishment rate", "every army"),
    "daemonsmiths": ("%+d%% research rate", "your faction"),
    "khanate":      ("%+d%% hero recruitment cost", "every province you own"),
    "overseers":    ("%+d%% building construction cost", "every region you own"),
    "slavers":      ("%+d%% income from sacking and razing", "every army"),
}

# 16,351 of vanilla's 16,430 junction rows use this stage. Nothing here needs another.
STAGE = "start_turn_completed"

# Effect value at each rank. Index 0 and 1 unused - rank 1 grants nothing.
RANK_VALUES = [None, None, 3, 6, 10, 15]

GUILD_NAMES = {
    "brass":        "The Brass Tablets",
    "immortals":    "The Immortals",
    "daemonsmiths": "The Daemonsmiths",
    "khanate":      "The Khanate",
    "overseers":    "The Overseers",
    "slavers":      "The Slavers",
}

RANK_NAMES = ["Unmarked", "Indebted", "Sworn", "Favoured", "Exalted"]

# The panel title plate clips silently past about 19 characters. gen_guilds_ui.py
# asserts the same string against that ceiling.
PANEL_TITLE = "The Great Guilds"


# The eighteen services. rank is the rank that unlocks it (2 indebted, 3 sworn,
# 4 favoured). kind decides which payload runs; only kind == "bundle" mints an
# effect bundle. Every cm: call named in a comment was verified present in
# campaign/episodic_scripting.html on 2026-09-10.
SERVICES = [
    # The Brass Tablets
    {"key": "caravan_levy",     "guild": "brass", "rank": 2, "cost": 50,  "cd": 8,
     "kind": "gold",   "value": 2500, "name": "Caravan Levy"},
    {"key": "writ_monopoly",    "guild": "brass", "rank": 3, "cost": 150, "cd": 12,
     "kind": "bundle", "turns": 10, "name": "Writ of Monopoly"},
    {"key": "long_ledger",      "guild": "brass", "rank": 4, "cost": 400, "cd": 20,
     "kind": "bundle", "turns": 15, "name": "The Long Ledger"},
    # The Immortals
    {"key": "oathbound_draft",  "guild": "immortals", "rank": 2, "cost": 50,  "cd": 6,
     "kind": "bundle", "turns": 5,  "name": "Oathbound Draft"},
    # Unit key read out of main_units on 2026-09-10. There is no trailing "_0"
    # on any Infernal Guard row - a typo'd unit key does nothing, forever, with
    # no error, so check() verifies this against the vanilla table.
    {"key": "hire_immortals",   "guild": "immortals", "rank": 3, "cost": 150, "cd": 10,
     "kind": "unit", "unit": "wh3_dlc23_chd_inf_infernal_guard_great_weapons",
     "name": "Hire the Immortals"},
    {"key": "astragoths_levy",  "guild": "immortals", "rank": 4, "cost": 400, "cd": 15,
     "kind": "bundle", "turns": 10, "name": "Astragoth's Levy"},
    # The Daemonsmiths
    {"key": "forge_rite",       "guild": "daemonsmiths", "rank": 2, "cost": 50,  "cd": 8,
     "kind": "bundle", "turns": 8,  "name": "Forge-Rite"},
    {"key": "bound_blueprint",  "guild": "daemonsmiths", "rank": 3, "cost": 150, "cd": 14,
     "kind": "research", "name": "Bound Blueprint"},
    {"key": "bound_ordnance",   "guild": "daemonsmiths", "rank": 4, "cost": 400, "cd": 15,
     "kind": "bundle", "turns": 10, "name": "Daemon-Bound Ordnance"},
    # The Khanate
    {"key": "hobgoblin_eyes",   "guild": "khanate", "rank": 2, "cost": 50,  "cd": 6,
     "kind": "shroud", "name": "Hobgoblin Eyes"},
    {"key": "knife_in_dark",    "guild": "khanate", "rank": 3, "cost": 150, "cd": 10,
     "kind": "bundle", "turns": 8,  "name": "Knife in the Dark"},
    {"key": "khans_price",      "guild": "khanate", "rank": 4, "cost": 400, "cd": 18,
     "kind": "bundle", "turns": 10, "hostile": True, "name": "The Khan's Price"},
    # The Overseers
    {"key": "lash_the_gangs",   "guild": "overseers", "rank": 2, "cost": 50,  "cd": 6,
     "kind": "bundle", "turns": 6,  "name": "Lash the Gangs"},
    {"key": "raise_ziggurat",   "guild": "overseers", "rank": 3, "cost": 150, "cd": 12,
     "kind": "building", "name": "Raise the Ziggurat"},
    {"key": "works_of_zharr",   "guild": "overseers", "rank": 4, "cost": 400, "cd": 15,
     "kind": "bundle", "turns": 12, "name": "Works of Zharr"},
    # The Slavers
    {"key": "coffle_drive",     "guild": "slavers", "rank": 2, "cost": 50,  "cd": 8,
     "kind": "bundle", "turns": 8,  "name": "Coffle Drive"},
    {"key": "slave_tithe",      "guild": "slavers", "rank": 3, "cost": 150, "cd": 10,
     "kind": "pooled", "name": "Slave Tithe"},
    {"key": "great_coffle",     "guild": "slavers", "rank": 4, "cost": 400, "cd": 18,
     "kind": "bundle", "turns": 12, "name": "The Great Coffle"},
]


def service_bundle_key(service_key):
    return "derpy_gg_svc_" + service_key


# --------------------------------------------------------- leading a guild ---
# WHAT LEADING ONE IS WORTH. GG.leader_of has always picked the top faction per guild
# and the Standings tab has always printed it; nothing paid for it, so the league table
# was a scoreboard for a race with no prize. One bundle per guild, on the guild's own
# effect, at the rank-4 value - so leading is worth another whole rung on top of
# whatever rank you hold, and losing it is felt.
LEAD_VALUE = 10


def lead_key(guild):
    return "derpy_gg_lead_" + guild


# THE MONOPOLY. The guild's dearest service is closed to everyone but its leader. This
# is the half that makes leadership a decision rather than a bonus: the thing you most
# want from a guild is the thing a rival can take away from you by out-earning you.
# The Lua mirrors it with `lead = true` on the same six keys, and check() compares them.
LEAD_SERVICES = set(s["key"] for s in SERVICES if s["rank"] == 4)


# ------------------------------------------------------------- the patron ---
# ONE BUNDLE, NOT SIX. The decision a patron creates is which guild gets the reputation
# and the discount; a different force buff per guild would be six effect keys, six sign
# checks and six loc entries for a difference no player would read off the tooltip.
#
# FORCE target and force_to_force_own scope, because this lands on one army rather than
# on the faction - cm:apply_effect_bundle_to_force. Both effects are
# is_positive_value_good=True, read out of vanilla's effects table on 2026-09-11, so
# both values are positive; vanilla's own maxima on these pairs are 50 and 90.
PATRON_BUNDLE = "derpy_gg_patron"
PATRON_EFFECTS = [
    ("wh_main_effect_force_all_campaign_replenishment_rate", "force_to_force_own", 10),
    ("wh_main_effect_force_all_campaign_movement_range", "force_to_force_own", 10),
]
PATRON_NAME = "Guild Patron"

# How each of them reads. Keyed by effect, not by position: the description used to index
# PATRON_EFFECTS[0] and [1], so a list of any other length raised out of build() instead
# of being reported by check().
PATRON_BLURB = {
    "wh_main_effect_force_all_campaign_replenishment_rate": "%+d%% replenishment",
    "wh_main_effect_force_all_campaign_movement_range": "%+d%% campaign movement",
}


def patron_clause():
    """The patron's effects as one readable list, in the order they are emitted."""
    return " and ".join(PATRON_BLURB[k] % v for k, _sc, v in PATRON_EFFECTS)

# What holding a patron is worth, mirrored in the Lua. The reputation share is the
# reason to appoint one at all; the discount is why you appoint them to the guild you
# actually buy from.
PATRON_REP_SHARE = 50     # % extra reputation earned for the patron's guild
PATRON_DISCOUNT = 10      # % off that guild's services


# ------------------------------------------------------------- the demands ---
# REPUTATION USED TO BE A RATCHET. Every route in the mod added to it and only the
# rivalry term ever took any away, so a guild courted once stayed courted for the rest
# of the campaign. A demand is the guild asking for something back, with a deadline.
#
# Two kinds, and neither is a new subsystem: a tribute is gold the engine already
# tracks, and a renunciation is favour this mod already holds. Nothing here needs a new
# DB table - only the loc, and one event-feed record so a demand cannot expire unseen.
DEMAND_KINDS = {
    "tribute":  {"name": "Tribute",
                 "blurb": "The guild wants gold, and it wants it now."},
    "renounce": {"name": "Renunciation",
                 "blurb": "The guild wants you to burn what you have built with its "
                          "rival. The favour goes; the reputation stays."},
}


# ---------------------------------------------------------------- event feed --
# cm:show_message_event's last argument is an INDEX, and it resolves through four
# tables. Miss any of them and the engine logs "showing event for faction [...]"
# and then draws NOTHING - no error, no feed entry.
#
#   event_feed_message_events.group  ->  campaign_groups.id
#                                    ->  campaign_group_members (group == id)
#                                    ->  campaign_group_member_criteria_values.value
#
# Vanilla's 229 indices run -1 .. 1960. 5001 is well clear of them; check()
# refuses if that ever stops being true.
FEED_GROUP = "derpy_gg_event_feed_hit"
FEED_INDEX = 5001

# A SECOND RECORD, for the demands. A demand that arrives with nothing on the feed is a
# deadline the player never saw, which is worse than no demand at all. One record covers
# both the arrival and the expiry - they differ only in their text, and the text is a loc
# key passed at the call site, not part of the record.
FEED_GROUP_DEMAND = "derpy_gg_event_feed_demand"
FEED_INDEX_DEMAND = 5002

# A THIRD RECORD, for leadership changing hands. Leading a guild carries a bundle and a
# monopoly on its dearest service, and until now the only way to learn you had lost
# either was to open the panel and read a name that had changed. A rival taking a guild
# off you is the loudest thing the AI does in this mod and it happened in silence.
#
# One record, twelve pairs of text keys: won and lost, per guild. The keys are passed at
# the call site, so naming the guild costs loc rows and not a second DB record - and it
# has to be loc rows, because cm:show_message_event takes KEYS and there is nowhere to
# interpolate a name into one.
FEED_GROUP_LEAD = "derpy_gg_event_feed_lead"
FEED_INDEX_LEAD = 5003

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

# Cloned field-for-field from wh2_main_event_feed_scripted_rite_expired_def,
# a working scripted_persistent_event, read 2026-09-10. Only group and image
# differ. `persistent` in the Lua call must agree with `event` here.
FEED_ROW = {
    "event": "scripted_persistent_event",
    "flavour_text": "wh_event_feed_string_all_null",
    "group": FEED_GROUP,
    # NOT "chd/generic", WHICH IS NOT A PICTURE. Every other culture has one -
    # def/generic, tmb/generic, skv/generic are all real - so cloning the donor row and
    # swapping the culture prefix produced a path with no file behind it, and a missing
    # imagepath draws a BLACK RECTANGLE in silence. Every event panel this mod raised
    # had one, from the first build until it was reported from play on 2026-09-12.
    #
    # The 24 real files are ui/eventpics/chd/*.png in ui2.pack. check_feed_images()
    # refuses any value vanilla's own table does not already use, which is a tighter
    # test than "the file exists" and catches the same fault a patch could reintroduce.
    # A rival's hostile service landing on you is the one bad-news record, so it gets
    # the bad-news picture; the other three override this below.
    "image": "chd/civilisation_down",
    "secondary_detail": "wh_event_feed_string_scripted_event_secondary_detail",
    "target": "event_feed_target_faction",
    "layout": "standard",
    "layout_data": "event_feed_none",
    "sound_event": "UI_CAM_POPUP_Message_Event_Neutral",
    "context_located": "event_feed_none",
    "override_icon": "event_rite_neutral.png",
    "instant_open": "true",
    "ignore_instant_open_filters": "false",
}

# Same shape, its own group. Only the group may differ freely; every other column is
# cloned from the working record above rather than authored, because an invented value
# in any of them is a load-time DB reject with no message the game says out loud.
# A PICTURE EACH, because the picture is the only part of these panels a player reads
# before the words. All four are values vanilla's own rows use for Chaos Dwarfs.
FEED_ROW_DEMAND = dict(FEED_ROW, group=FEED_GROUP_DEMAND,
                       # The Court sending word, and the messenger is the record that
                       # keeps the base row's picture: a demand arriving is the plainest
                       # "a message has reached you" this mod has.
                       image="chd/messenger")
FEED_ROW_LEAD = dict(FEED_ROW, group=FEED_GROUP_LEAD,
                     # Leadership changing hands is who stands where among factions.
                     image="chd/diplomacy")
FEED_ROW_RANK = dict(FEED_ROW, group=FEED_GROUP_RANK, image="chd/civilisation_up",
                     # The only column that differs from the three above. The other
                     # records use CA's neutral popup; a promotion is the one thing in
                     # this mod worth a positive sound.
                     sound_event="UI_CAM_POPUP_Message_Event_Positive")


# BY RANK, NOT A FLAT CONSTANT. A timed service pushes its guild's one effect, so with
# a single value the only thing a higher rank bought was a longer duration - the
# Daemonsmiths' rank-4 service was 8x the price of their rank-2 one for two more turns of
# the identical +20%. Indices are 1-5 like every other rank table here; rank 1 grants no
# service at all, so its entry is never read.
#
# Read against the ladder, which is 3/6/10/15 permanent: a service is a burst worth
# several ranks of it for a handful of turns, and rank 4's burst is worth the 400.
SERVICE_VALUES = [None, None, 20, 32, 45]

# check() refuses any emitted value whose magnitude exceeds VALUE_RANGE_TOLERANCE times
# the largest magnitude vanilla puts on that same (effect, scope), once vanilla has at
# least VALUE_RANGE_MIN_ROWS rows to judge by. 1.5 is the tightest tolerance this
# design passes, which is why the top service is 45 and not 60: the largest sacking
# income effect CA ships is +30%.
VALUE_RANGE_TOLERANCE = 1.5
VALUE_RANGE_MIN_ROWS = 3


def service_value(s):
    return SERVICE_VALUES[s["rank"]]


def service_sign(s):
    """A service bundle's sign.

    Every service but one lands on the buyer, so it carries the guild's good sign.
    The Khan's Price lands on the TARGET, so it must carry the opposite: a cost
    modifier that is a discount for the buyer is a discount for the victim too,
    which would make the mod's only hostile service a gift.
    """
    sign = EFFECT_GOOD_SIGN[s["guild"]]
    return -sign if s.get("hostile") else sign



# What each service's payload actually does, in the player's words. Written per
# service rather than derived, because six of the eighteen run a payload no
# formula describes. Each is one sentence; the cost, cooldown, duration and rank
# requirement are appended from the SERVICES data so they cannot drift from it.
SERVICE_BLURB = {
    "caravan_levy":    "Calls in debts across the trade roads. Adds 2,500 gold to your "
                       "treasury at once.",
    "writ_monopoly":   None,
    "long_ledger":     None,
    "oathbound_draft": None,
    "hire_immortals":  "A company already sworn and already armed. Adds one unit of "
                       "Infernal Guard (Great Weapons) to an army of your choosing.",
    "astragoths_levy": None,
    "forge_rite":      None,
    "bound_blueprint": "The Daemonsmiths hand over work already done. Completes the "
                       "technology you are currently researching, at once.",
    "bound_ordnance":  None,
    "hobgoblin_eyes":  "Hobgoblin scouts sell what they have seen. Reveals one region "
                       "through the shroud, permanently.",
    "knife_in_dark":   None,
    "khans_price":     None,
    "lash_the_gangs":  None,
    "raise_ziggurat":  "Overseer gangs work through the night. Upgrades one of your "
                       "buildings to its next level at once, and free.",
    "works_of_zharr":  None,
    "coffle_drive":    None,
    "slave_tithe":     "A column of slaves, delivered. Adds 400 armaments and 800 raw "
                       "materials. A faction that keeps no such stockpiles is paid "
                       "3,000 gold instead.",
    "great_coffle":    None,
}

# What each guild is, how you earn its reputation, and what its ladder pays.
GUILD_DESC = {
    "brass":        "Tally-keepers and caravan masters. They record every debt in the "
                    "Dark Lands and forgive none of them.||You earn reputation from your "
                    "income every turn, and from their own buildings.",
    "immortals":    "The oath-sworn companies who fight for whoever holds their bond, "
                    "and never break it.||You earn reputation from battles you win - double "
                    "when you win outnumbered - and from their own buildings.",
    "daemonsmiths": "Those who bind daemons into iron. They sell knowledge, never "
                    "cheaply.||You earn reputation from technologies you complete, and "
                    "from their own buildings.",
    "khanate":      "Hobgoblin knives and hobgoblin eyes, for hire to anyone, "
                    "including against you.||You earn reputation when your heroes succeed "
                    "at an action, and from their own buildings.",
    "overseers":    "The gang-masters who drive the building of Zharr Naggrund and "
                    "everything like it.||You earn reputation when a settlement grows a "
                    "level, and from any building no other guild claims.",
    "slavers":      "The coffle-drivers. Their ledger is measured in bodies, and it is "
                    "always growing.||You earn reputation from settlements you sack - more "
                    "from those you raze - and from their own buildings.",
}
# THE TWO HALVES. The flavour sentence is written per race in FLAVOURS below; the earn
# sentence is mechanical and every race shares it.
GUILD_FLAVOUR = dict((g, d.split("||", 1)[0]) for g, d in GUILD_DESC.items())
GUILD_EARN = dict((g, d.split("||", 1)[1]) for g, d in GUILD_DESC.items())

# ------------------------------------------------------------------ bounties ---
# A CLONE OF CA'S OWN OGRE CONTRACTS, which its script calls `ogre_bounties`
# (script/campaign/wh3_campaign_ogre_contracts.lua in data_script.pack). CA's shape,
# read off that file on 2026-09-11: pick a target in Lua, issue the mission with
# cm:trigger_custom_mission_from_string, pay with a `money` payload, and let the DB row
# carry only the text and the category. Three objective types, and they are the three
# CA itself drives with generated targets - which is the whole reason to use these three
# and not the other 86 in docs/MISSIONS.md. A type CA never issues from a string is a
# type nobody has proven accepts a runtime target.
#
# `total 1` on the raze/sack type is CA's too: the objective counts DIFFERENT
# settlements, so without it the mission wants an unstated number of them.
# `mtype` is the DB row's mission_type column. `otype` is the objective type written
# into the mission string. THEY ARE NOT THE SAME THING, and CA's own contracts are the
# proof: all 23 wh3_main_mission_ogre_contract_defeat_lord_* rows carry mission_type
# ELIMINATE_CHARACTER_IN_BATTLE, while wh3_campaign_ogre_contracts.lua issues those very
# missions with `type KILL_CHARACTER_BY_ANY_MEANS`. The column is a label the panel and
# the CDIR read; the string carries the objective the game evaluates. Taking the column
# as the objective would have meant a bounty that only counts a kill won in a battle,
# which is not the bounty either guild is paying for.
BOUNTY_KINDS = {
    "region_take": {"mtype": "CAPTURE_REGIONS", "otype": "CAPTURE_REGIONS",
                    "obj": "region %s", "gold": 3000},
    "region_sack": {"mtype": "RAZE_OR_SACK_N_DIFFERENT_SETTLEMENTS_INCLUDING",
                    "otype": "RAZE_OR_SACK_N_DIFFERENT_SETTLEMENTS_INCLUDING",
                    "obj": "region %s;total 1", "gold": 2000},
    "lord_kill":   {"mtype": "ELIMINATE_CHARACTER_IN_BATTLE",
                    "otype": "KILL_CHARACTER_BY_ANY_MEANS",
                    "obj": "family_member %s", "gold": 1500},
}

# The three objective types CA's own contract script issues from a string against a
# target it picked at runtime, read out of ogre_bounties.mission_types in
# script/campaign/wh3_campaign_ogre_contracts.lua on 2026-09-11. This list is the
# evidence for `otype`; no DB table records it, because the script is the only place it
# exists.
CA_CONTRACT_OBJECTIVES = ("KILL_CHARACTER_BY_ANY_MEANS", "CAPTURE_REGIONS",
                          "RAZE_OR_SACK_N_DIFFERENT_SETTLEMENTS_INCLUDING")

# One bounty per guild, and the kind is the guild's own business: the Slavers want a
# settlement emptied, the Khanate wants a man dead, the Overseers want the walls left
# standing so there is something to work in.
#
# ONE ROW PER GUILD IS DELIBERATE. A mission key can hold one live mission per faction
# at a time, so six keys means at most six live bounties and the panel's own cap of
# three sits well inside that. Reusing one key for all six guilds would have them
# fighting over it, which is the trap docs/VICTORY_CONDITIONS.md records.
BOUNTIES = {
    "brass":        ("region_take", "Seize the Market",
                     "The Tablets want the tolls of that place counted in our "
                     "column. Take it intact."),
    "immortals":    ("lord_kill", "Break Their Champion",
                     "A general is being spoken of with respect. Correct that."),
    "daemonsmiths": ("region_sack", "Strip the Works",
                     "Everything in that place that was forged can be forged again, "
                     "here. Bring it back in pieces."),
    "khanate":      ("lord_kill", "A Knife for a Name",
                     "The Khanate does not care how it is done, only that the name "
                     "stops being used."),
    "overseers":    ("region_take", "Hands, Not Ashes",
                     "Take it whole. Ashes cannot be put to work, and the Overseers "
                     "are counting hands."),
    "slavers":      ("region_sack", "Fill the Coffles",
                     "Empty it. The column that leaves is the payment, and it is "
                     "measured in bodies."),
}
# The category is a REFERENCE to cdir_events_categories.category_key - confirmed in
# RPFM's own schema for missions_tables on 2026-09-11 - so a category invented for this
# mod is an unresolvable foreign key, which is a startup reject and not a warning.
# `Quest` is a vanilla row and is what this workspace's own shipped quests already use.
# WHO ARGUES WITH WHOM, mirrored from GG.RIVALS in the campaign Lua so the help cannot
# name a pairing the mod does not have. check_rival_mirror() compares the two.
RIVAL_PAIRS = [("brass", "khanate"), ("immortals", "daemonsmiths"),
               ("overseers", "slavers")]

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
                      "it intact."),
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
            "slave_tithe": "Oathgold paid to settle a grudge, and passed on to you. "
                           "Adds 250 Oathgold.",
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
                      "intact."),
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
    # BRETONNIA, CATHAY AND KISLEV. Approved 2026-09-24 as written in
    # docs/superpowers/specs/2026-09-24-great-guilds-brt-cth-ksl-design.md; every lore word
    # in them is one CA's own loc uses. All four feed pictures exist under each race's
    # folder. Kislev has no mission picture of its own anywhere in vanilla - CA gives its
    # Kislev missions emp/generic (97 rows), so the bounties do the same.
    "_brt": {
        "culture": "wh_main_brt_bretonnia", "pics": "brt", "feed": 40,
        "guilds": {
            "brass": "The Wine Merchants",
            "immortals": "The Knights Errant",
            "daemonsmiths": "The Grail Damsels",
            "khanate": "The Forest Outlaws",
            "overseers": "The Castle-Wrights",
            "slavers": "The Crusaders",
        },
        "ranks": ["Peasant", "Yeoman", "Squire", "Knight", "Paladin"],
        "services": {
            "caravan_levy": "Wine Duties",
            "writ_monopoly": "Ducal Charter",
            "long_ledger": "The Vintners' Accord",
            "oathbound_draft": "Call the Banners",
            "hire_immortals": "Hire the Knights",
            "astragoths_levy": "The King's Summons",
            "forge_rite": "Lessons of the Lady",
            "bound_blueprint": "The Lady's Revelation",
            "bound_ordnance": "Vision of the Grail",
            "hobgoblin_eyes": "Word from the Woods",
            "knife_in_dark": "Arrows from Cover",
            "khans_price": "The Outlaws' Toll",
            "lash_the_gangs": "Feudal Labour",
            "raise_ziggurat": "Raise the Keep",
            "works_of_zharr": "The Duke's Works",
            "coffle_drive": "Spoils of Crusade",
            "slave_tithe": "The Crusaders' Share",
            "great_coffle": "The Errantry War",
        },
        "blurbs": {
            "caravan_levy": "The Wine Merchants collect the duties owed on every cask. "
                            "Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "A lance of knights, already sworn and already horsed. "
                              "Adds one unit of Knights of the Realm to an army of your "
                              "choosing.",
            "bound_blueprint": "The Grail Damsels share what the Lady has shown them. "
                               "Completes the technology you are currently researching, "
                               "at once.",
            "hobgoblin_eyes": "The Forest Outlaws sell what they have seen from the "
                              "trees. Reveals one region through the shroud, "
                              "permanently.",
            "raise_ziggurat": "The Castle-Wrights work through the night. Upgrades one "
                              "of your buildings to its next level at once, and free.",
            "slave_tithe": "The Crusaders send home your share of the spoils. Adds 3,000 "
                           "gold to your treasury.",
        },
        "desc": {
            "brass": "The vintners and shipping houses of Bordeleaux, whose casks reach "
                     "every court in the Old World. Every duke owes them something.",
            "immortals": "Young knights sworn to prove themselves in battle. Whoever "
                         "gives them the field earns their lances.",
            "daemonsmiths": "Handmaidens of the Lady who keep the old lore of Bretonnia. "
                            "They share it only with those they judge worthy.",
            "khanate": "Poachers and cutpurses who live beyond the law in the deep "
                       "forests. They will rob anyone, including you.",
            "overseers": "The master masons who raise every keep and curtain wall in the "
                         "dukedoms, and who know where each one is weak.",
            "slavers": "Knights and men-at-arms back from the Errantry Wars, paid in "
                       "what they carry home.",
        },
        "bounties": {
            "brass": ("Open the Cellars",
                      "The Wine Merchants want that town's trade flowing to Bordeleaux. "
                      "Take it intact."),
            "immortals": ("A Challenge of Honour",
                          "A general is being spoken of with respect. The Knights Errant "
                          "would like to test that."),
            "daemonsmiths": ("Out of Unworthy Hands",
                             "Whatever that place keeps, the Damsels want it taken from "
                             "those who should not have it. Bring it back in pieces."),
            "khanate": ("A Name in the Forest",
                        "The Outlaws do not care how it is done, only that the name "
                        "stops being used."),
            "overseers": ("A Keep Worth Keeping",
                          "Take it whole. The Castle-Wrights want a keep to improve, not "
                          "rubble."),
            "slavers": ("A Crusade's Worth",
                        "Sack it. The Crusaders are owed, and that place can pay."),
        },
    },
    "_cth": {
        "culture": "wh3_main_cth_cathay", "pics": "cth", "feed": 50,
        "guilds": {
            "brass": "The Caravan Masters",
            "immortals": "The Dragon Guard",
            "daemonsmiths": "The Imperial Academy",
            "khanate": "The Crow Society",
            "overseers": "The Bastion Builders",
            "slavers": "The Punitive Host",
        },
        "ranks": ["Commoner", "Scholar", "Official", "Magistrate", "Minister"],
        "services": {
            "caravan_levy": "Caravan Tolls",
            "writ_monopoly": "Seal of Trade",
            "long_ledger": "The Ivory Road",
            "oathbound_draft": "Fresh Levies",
            "hire_immortals": "Hire the Dragon Guard",
            "astragoths_levy": "The Emperor's Mandate",
            "forge_rite": "Hall of Scholars",
            "bound_blueprint": "Archive Scrolls",
            "bound_ordnance": "The Celestial Charts",
            "hobgoblin_eyes": "Eyes of the Crows",
            "knife_in_dark": "A Quiet Poison",
            "khans_price": "Sow Disharmony",
            "lash_the_gangs": "Conscript Labour",
            "raise_ziggurat": "Raise the Pagoda",
            "works_of_zharr": "Works of the Bastion",
            "coffle_drive": "Punitive Raids",
            "slave_tithe": "The Host's Share",
            "great_coffle": "The Great Expedition",
        },
        "blurbs": {
            "caravan_levy": "The Caravan Masters collect on every road they travel. Adds "
                            "2,500 gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of Celestial Dragon Guard to an army of your choosing.",
            "bound_blueprint": "The Imperial Academy hands over work already done. "
                               "Completes the technology you are currently researching, "
                               "at once.",
            "hobgoblin_eyes": "The Crow Society sells what its crows have seen. Reveals "
                              "one region through the shroud, permanently.",
            "raise_ziggurat": "The Bastion Builders work through the night. Upgrades one "
                              "of your buildings to its next level at once, and free.",
            "slave_tithe": "The Punitive Host sends back your share of the spoils. Adds "
                           "3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "The masters of the Ivory Road, whose caravans cross half the world "
                     "and come back heavier. Every province pays their tolls.",
            "immortals": "The Emperor's own warriors, sworn to the Celestial Court. "
                         "Their oath is lent to whoever the Court favours.",
            "daemonsmiths": "The scholars and astromancers who keep the Empire's "
                            "learning. They teach it slowly, and never for free.",
            "khanate": "Informers, poisoners and watchers who sell what they learn at "
                       "court. They work for anyone, including against you.",
            "overseers": "The engineers who keep the Great Bastion standing, and who "
                         "know where every wall is weak.",
            "slavers": "Soldiers sent beyond the Bastion to punish the Emperor's "
                       "enemies. Their pay is what they bring back.",
        },
        "bounties": {
            "brass": ("Open the Road",
                      "The Caravan Masters want that town's markets on the Ivory Road. "
                      "Take it intact."),
            "immortals": ("A Lesson in Respect",
                          "A general is being spoken of with respect. The Dragon Guard "
                          "would like that corrected."),
            "daemonsmiths": ("Collect the Texts",
                             "Whatever that place has written down, the Academy wants in "
                             "its archive. Bring it back in pieces."),
            "khanate": ("A Name Forgotten",
                        "The Society does not care how it is done, only that the name "
                        "stops being used."),
            "overseers": ("Walls for the Empire",
                          "Take it whole. The Bastion Builders want walls to strengthen, "
                          "not rubble."),
            "slavers": ("Punish Them",
                        "Sack it. The Host is owed, and that place can pay."),
        },
    },
    "_ksl": {
        "culture": "wh3_main_ksl_kislev", "pics": "ksl", "feed": 60,
        "mission_pic": "emp/generic",
        "guilds": {
            "brass": "The Erengrad Merchants",
            "immortals": "The Tzar Guard",
            "daemonsmiths": "The Ice Court",
            "khanate": "The Oblast Smugglers",
            "overseers": "The Stanitsa Builders",
            "slavers": "The Ungol Raiders",
        },
        "ranks": ["Serf", "Kossar", "Druzhina", "Boyar", "Ataman"],
        "services": {
            "caravan_levy": "Erengrad Tolls",
            "writ_monopoly": "Tzarina's Charter",
            "long_ledger": "The Erengrad Exchange",
            "oathbound_draft": "Call the Druzhina",
            "hire_immortals": "Hire the Tzar Guard",
            "astragoths_levy": "The Tzarina's Levy",
            "forge_rite": "Winter Lessons",
            "bound_blueprint": "Secrets of the Ice",
            "bound_ordnance": "The Ice Queen's Favour",
            "hobgoblin_eyes": "Smugglers' Trails",
            "knife_in_dark": "A Knife in the Snow",
            "khans_price": "Sabotage the Sledges",
            "lash_the_gangs": "Before the Thaw",
            "raise_ziggurat": "Raise the Palisade",
            "works_of_zharr": "Walls Against Chaos",
            "coffle_drive": "Steppe Plunder",
            "slave_tithe": "The Riders' Share",
            "great_coffle": "The Long Raid",
        },
        "blurbs": {
            "caravan_levy": "The Erengrad Merchants collect on every ship and sledge. "
                            "Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of Tzar Guard (Great Weapons) to an army of your "
                              "choosing.",
            "bound_blueprint": "The Ice Court parts with a secret, once. Completes the "
                               "technology you are currently researching, at once.",
            "hobgoblin_eyes": "The Oblast Smugglers sell what they have seen on the "
                              "trails. Reveals one region through the shroud, "
                              "permanently.",
            "raise_ziggurat": "The Stanitsa Builders work before the thaw. Upgrades one "
                              "of your buildings to its next level at once, and free.",
            "slave_tithe": "The Ungol Raiders send back your share of the take. Adds "
                           "3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "The traders of Erengrad, whose ships and sledges carry furs south "
                     "and gold north. Every boyar owes them something.",
            "immortals": "The Tzar's own guard, the finest warriors in Kislev. Their "
                         "oath can be lent, never broken.",
            "daemonsmiths": "The witches of the Ice Court, who keep what the winter "
                            "teaches. They part with it slowly, and never for free.",
            "khanate": "Smugglers who know every trail across the oblast and every ear "
                       "in every stanitsa. They work for anyone, including against you.",
            "overseers": "The builders of every palisade and stanitsa that holds the "
                         "north, and the only ones who know where each is weak.",
            "slavers": "Horse-raiders of the steppe who ride for pay and plunder. Their "
                       "ledger is measured in what they carry home.",
        },
        "bounties": {
            "brass": ("Open the Market",
                      "The Erengrad Merchants want that town's trade in their ledgers. "
                      "Take it intact."),
            "immortals": ("A Duel in the Snow",
                          "A general is being spoken of with respect. The Tzar Guard "
                          "would like that corrected."),
            "daemonsmiths": ("Claim the Lore",
                             "Whatever that place knows, the Ice Court wants. Bring it "
                             "back in pieces."),
            "khanate": ("Lost in the Snow",
                        "The Smugglers do not care how it is done, only that the name "
                        "stops being used."),
            "overseers": ("Hold the Line",
                          "Take it whole. The Stanitsa Builders want walls that hold, "
                          "not rubble."),
            "slavers": ("Ride and Take",
                        "Sack it. The Raiders are owed, and that place can pay."),
        },
    },
    # DARK ELVES AND HIGH ELVES. Approved 2026-09-24 as written in
    # docs/superpowers/specs/2026-09-24-great-guilds-def-hef-design.md; every lore word
    # in them is one CA's own loc uses. Both races have all four feed pictures and a
    # generic mission picture of their own. "slave" is refused, so the Dark Elves say
    # captives, thralls and Corsairs.
    "_def": {
        "culture": "wh2_main_def_dark_elves", "pics": "def", "feed": 70,
        "guilds": {
            "brass": "The Karond Kar Traders",
            "immortals": "The Black Guard",
            "daemonsmiths": "The Convent of Ghrond",
            "khanate": "The Khainite Assassins",
            "overseers": "The Naggarond Builders",
            "slavers": "The Black Ark Corsairs",
        },
        "ranks": ["Thrall", "Corsair", "Highborn", "Dreadlord", "Tyrant"],
        "services": {
            "caravan_levy": "Market Tithes",
            "writ_monopoly": "The Witch King's Seal",
            "long_ledger": "The Karond Kar Ledger",
            "oathbound_draft": "Call the Dreadspears",
            "hire_immortals": "Hire the Black Guard",
            "astragoths_levy": "Malekith's Summons",
            "forge_rite": "Rites of the Convent",
            "bound_blueprint": "Secrets of Ghrond",
            "bound_ordnance": "Morathi's Favour",
            "hobgoblin_eyes": "Eyes in the Shadows",
            "knife_in_dark": "A Knife for Khaine",
            "khans_price": "The Assassins' Price",
            "lash_the_gangs": "Drive the Thralls",
            "raise_ziggurat": "Raise the Tower",
            "works_of_zharr": "Works of Naggarond",
            "coffle_drive": "Corsair Raids",
            "slave_tithe": "The Corsairs' Share",
            "great_coffle": "The Black Ark Raid",
        },
        "blurbs": {
            "caravan_levy": "The Karond Kar Traders take their cut of every sale. Adds "
                            "2,500 gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of Black Guard of Naggarond to an army of your choosing.",
            "bound_blueprint": "The Convent of Ghrond parts with a secret, once. "
                               "Completes the technology you are currently researching, "
                               "at once.",
            "hobgoblin_eyes": "The Khainite Assassins sell what they have seen from the "
                              "shadows. Reveals one region through the shroud, "
                              "permanently.",
            "raise_ziggurat": "The Naggarond Builders drive the thralls through the "
                              "night. Upgrades one of your buildings to its next level "
                              "at once, and free.",
            "slave_tithe": "The Black Ark Corsairs send home your share of the plunder. "
                           "Adds 3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "The counting-towers of Karond Kar, where every captive the Black "
                     "Arks bring home is bought and sold. Every Highborn owes them "
                     "something.",
            "immortals": "The Witch King's own guard, sworn to Naggarond and nothing "
                         "else. Their oath is lent only to those Malekith favours.",
            "daemonsmiths": "The sorceresses of Ghrond, who keep the dark arts and "
                            "answer to Morathi alone. They part with what they know "
                            "slowly, and never for free.",
            "khanate": "Assassins of the Temple of Khaine, who kill for the Lord of "
                       "Murder and for pay. They work for anyone, including against you.",
            "overseers": "The builders of every tower and wall in Naggaroth, raised by "
                         "thralls in the cold. They know where each one is weak.",
            "slavers": "The crews of the Black Arks, who raid every shore they can "
                       "reach. Their pay is what they carry home.",
        },
        "bounties": {
            "brass": ("Fresh Markets",
                      "The Karond Kar Traders want that town's trade in their ledgers. "
                      "Take it intact."),
            "immortals": ("A Test of Blades",
                          "A general is being spoken of with respect. The Black Guard "
                          "would like that corrected."),
            "daemonsmiths": ("Plunder the Lore",
                             "Whatever that place knows, the Convent wants. Bring it "
                             "back in pieces."),
            "khanate": ("A Name for Khaine",
                        "The Assassins do not care how it is done, only that the name "
                        "stops being used."),
            "overseers": ("A Tower Worth Taking",
                          "Take it whole. The Naggarond Builders want walls to raise "
                          "higher, not rubble."),
            "slavers": ("A Harvest of Captives",
                        "Sack it. The Corsairs are owed, and that place can pay."),
        },
    },
    "_hef": {
        "culture": "wh2_main_hef_high_elves", "pics": "hef", "feed": 80,
        "guilds": {
            "brass": "The Lothern Merchants",
            "immortals": "The Swordmasters",
            "daemonsmiths": "The Loremasters",
            "khanate": "The Shadow Warriors",
            "overseers": "The Ulthuan Masons",
            "slavers": "The Ellyrian Reavers",
        },
        "ranks": ["Citizen", "Warden", "Noble", "Prince", "Regent"],
        "services": {
            "caravan_levy": "Lothern Tolls",
            "writ_monopoly": "The Phoenix Charter",
            "long_ledger": "The Sea Lanes",
            "oathbound_draft": "Call the Citizen Levy",
            "hire_immortals": "Hire the Swordmasters",
            "astragoths_levy": "Summons of the Throne",
            "forge_rite": "Lessons of Hoeth",
            "bound_blueprint": "From the White Tower",
            "bound_ordnance": "The Loremasters' Gift",
            "hobgoblin_eyes": "Eyes of Nagarythe",
            "knife_in_dark": "An Arrow from Shadow",
            "khans_price": "Whispers at Court",
            "lash_the_gangs": "Citizen Labour",
            "raise_ziggurat": "Raise the Spire",
            "works_of_zharr": "Works of Ulthuan",
            "coffle_drive": "Reaver Raids",
            "slave_tithe": "The Reavers' Share",
            "great_coffle": "Ulthuan's Vengeance",
        },
        "blurbs": {
            "caravan_levy": "The Lothern Merchants collect on every ship that docks. "
                            "Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of Swordmasters of Hoeth to an army of your choosing.",
            "bound_blueprint": "The Loremasters hand over work already done. Completes "
                               "the technology you are currently researching, at once.",
            "hobgoblin_eyes": "The Shadow Warriors share what they have seen. Reveals "
                              "one region through the shroud, permanently.",
            "raise_ziggurat": "The Ulthuan Masons work through the night. Upgrades one "
                              "of your buildings to its next level at once, and free.",
            "slave_tithe": "The Ellyrian Reavers send back your share of the take. Adds "
                           "3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "The merchant houses of Lothern, whose ships carry the trade of "
                     "Ulthuan to every coast. Every Sea Lord owes them something.",
            "immortals": "The warriors of the White Tower of Hoeth, sworn to the blade "
                         "for centuries. Their oath is lent to whoever the Tower "
                         "favours.",
            "daemonsmiths": "The Loremasters of Hoeth, who keep the greatest library in "
                            "the world. They teach it slowly, and never for free.",
            "khanate": "The scouts of Nagarythe, who fight a secret war nobody else "
                       "sees. They work for anyone, including against you.",
            "overseers": "The masons who raise every tower and sea wall in Ulthuan, and "
                         "who know where each one is weak.",
            "slavers": "The riders of Ellyrion, who range far past the borders and bring "
                       "back what they find. Their pay is what they carry home.",
        },
        "bounties": {
            "brass": ("Open the Harbour",
                      "The Lothern Merchants want that town's trade on their ships. Take "
                      "it intact."),
            "immortals": ("A Lesson in Blades",
                          "A general is being spoken of with respect. The Swordmasters "
                          "would like that corrected."),
            "daemonsmiths": ("Recover the Lore",
                             "Whatever that place knows, the Loremasters want kept safe. "
                             "Bring it back in pieces."),
            "khanate": ("A Shadow Falls",
                        "The Shadow Warriors do not care how it is done, only that the "
                        "name stops being used."),
            "overseers": ("Walls for Ulthuan",
                          "Take it whole. The Masons want walls to strengthen, not "
                          "rubble."),
            "slavers": ("Reave It",
                        "Sack it. The Reavers are owed, and that place can pay."),
        },
    },
    # EVERY OTHER RACE. One race-neutral flavour for each culture this mod ships none for.
    # Since 2026-09-24 those races get no guilds and no button, so it is read only by an
    # unsupported human that a hostile service hits in multiplayer. The names say what
    # each guild does rather than whose it is. `culture` is None because it
    # is the fallback, not an entry: the Lua's GG.GENERIC mirrors it, and
    # check_flavour_mirror() compares the two.
    #
    # THE PICTURES CANNOT BE A FOLDER SWAP. all/ lacks civilisation_up and three of the
    # other four names the Chaos Dwarf rows draw, so `pictures` names each one outright.
    # Every value is one vanilla's own rows use, which check_feed_images() asserts.
    "_gen": {
        "culture": None, "pics": "all", "feed": 30,
        "pictures": {
            "civilisation_down": "all/wh2_rogue_army_encountered",
            "messenger": "all/wh2_treasure_hunt_3",
            "diplomacy": "all/nemesis_crown",
            "civilisation_up": "all/wh2_sea_encounters_1",
        },
        "mission_pic": "all/queen_and_crone",
        "guilds": {
            "brass": "The Merchant Houses",
            "immortals": "The Veterans' Company",
            "daemonsmiths": "The Artisans' Guild",
            "khanate": "The Shadow Guild",
            "overseers": "The Builders' Guild",
            "slavers": "The Raiders' Guild",
        },
        "ranks": ["Stranger", "Known", "Trusted", "Honoured", "Exalted"],
        "services": {
            "caravan_levy": "Collect the Tolls",
            "writ_monopoly": "Trade Charter",
            "long_ledger": "The Long Ledger",
            "oathbound_draft": "Call to Arms",
            "hire_immortals": "Hire the Veterans",
            "astragoths_levy": "Raise the Levy",
            "forge_rite": "The Proving Forge",
            "bound_blueprint": "The Artisans' Plans",
            "bound_ordnance": "Siege Engines",
            "hobgoblin_eyes": "Spies' Report",
            "knife_in_dark": "Knife in the Dark",
            "khans_price": "The Shadow Tax",
            "lash_the_gangs": "Work Through the Night",
            "raise_ziggurat": "Master Builder's Work",
            "works_of_zharr": "The Great Works",
            "coffle_drive": "Raiding Rights",
            "slave_tithe": "The Raiders' Cut",
            "great_coffle": "The Great Raid",
        },
        # NO RACE HERE HAS A HIRE UNIT, so GG.can_buy refuses hire_immortals for all of
        # them and the refusal line says why. The blurb still has to say what the service
        # is, and must not promise a unit by name.
        "blurbs": {
            "caravan_levy": "The Merchant Houses collect on every road they keep a ledger "
                            "for. Adds 2,500 gold to your treasury at once.",
            "hire_immortals": "A company already sworn and already armed. Adds one unit "
                              "of your people's elite infantry to an army of your "
                              "choosing, where the Company keeps one.",
            "bound_blueprint": "The Artisans' Guild hands over work already done. "
                               "Completes the technology you are currently researching, "
                               "at once.",
            "hobgoblin_eyes": "The Shadow Guild sells what its spies have seen. Reveals "
                              "one region through the shroud, permanently.",
            "raise_ziggurat": "The Builders' Guild works through the night. Upgrades one "
                              "of your buildings to its next level at once, and free.",
            "slave_tithe": "The Raiders' Guild sends you your share of the take. Adds "
                           "3,000 gold to your treasury.",
        },
        "desc": {
            "brass": "Traders and money-lenders who keep a ledger on every road. They "
                     "forget no debt and forgive fewer.",
            "immortals": "Old soldiers who sell their oath to whoever can pay for it, and "
                         "keep it once it is sold.",
            "daemonsmiths": "Craftsmen and inventors who build what others only draw. They "
                            "sell what they know, a piece at a time.",
            "khanate": "Spies, smugglers and knives for hire. They work for anyone, "
                       "including against you.",
            "overseers": "The builders of every wall and tower worth the name, and the "
                         "only ones who know where each one is weak.",
            "slavers": "Raiders paid in plunder. Their ledger is measured in what they "
                       "carry home.",
        },
        "bounties": {
            "brass": ("Take the Market",
                      "The Merchant Houses want that town's tolls paid to them. Take it "
                      "intact."),
            "immortals": ("A Challenge Answered",
                          "A general is being spoken of with respect. The Company would "
                          "like that corrected."),
            "daemonsmiths": ("Strip the Workshops",
                             "Whatever that place has built, the Artisans want on their "
                             "own benches. Bring it back in pieces."),
            "khanate": ("A Quiet Removal",
                        "The Guild does not care how it is done, only that the name "
                        "stops being used."),
            "overseers": ("Leave the Walls Standing",
                          "Take it whole. The Builders want walls to work on, not "
                          "rubble."),
            "slavers": ("A Raid Worth Taking",
                        "Sack it. The Guild is owed, and that place can pay."),
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

# The one-line version of each guild's earn route. GUILD_DESC carries the full sentence
# and it is one hover away on the Guilds tab; this is the four-word form a list needs.
EARN_SHORT = {
    "brass": "your income, every turn",
    "immortals": "battles won, doubled when outnumbered",
    "daemonsmiths": "technologies completed",
    "khanate": "successful hero actions",
    "overseers": "settlements growing a level, and buildings no other guild claims",
    "slavers": "settlements sacked, more when razed",
}

# ------------------------------------------------------------------- the help --
# FOUR PAGES OF TYPED LINES, not two paragraphs of prose. "#" is a heading, "-" a
# bullet, "" a blank, anything else a body line; the panel renders each differently and
# GGUI.HELP_PAGES must equal the number of pages here (checked).
# A FIFTH PAGE RATHER THAN A FIFTH SECTION ON AN EXISTING ONE. The upkeep had nowhere to
# go: check_help_pages measured page 2 at 22 of the panel's 21 slots with it and page 4 at
# 20 of 21, and GGUI.help_lines drops the overflow in silence. It also collects four rules
# that were scattered across pages 1, 2 and 4 - the rival, the demand, the failed bounty
# and the upkeep are one subject, and a player who has just watched a rank go backwards is
# looking for one page, not three.
HELP_PAGE_TITLES = ["The Guilds", "Earning", "Bounties", "The Court", "Losing reputation"]


def short_name(guild, tag=""):
    """The guild's name without its leading article, for a compact list."""
    name = FLAVOURS[tag]["guilds"][guild]
    if name.startswith("The "):
        return name[4:]
    return name


def help_pages(tag=""):
    """[[line, ...], ...] - one list per page, in the order the pager turns them.

    The two names below SHADOW the module tables on purpose: assigned here, they are
    local for the whole function, so every line reads this flavour's words unedited.
    """
    GUILD_NAMES = FLAVOURS[tag]["guilds"]
    RANK_NAMES = FLAVOURS[tag]["ranks"]
    ranks = " / ".join("%s %d" % (RANK_NAMES[i], RANK_THRESHOLDS[i]) for i in range(5))

    page1 = [
        "#Two numbers, per guild",
        "-REPUTATION is earned by playing and is never spent. It alone sets your rank.",
        "-It can also fall: to a rival you have been feeding, to a "
        "demand you let expire, to a bounty you took and did not finish, and to the "
        "upkeep every guild charges to keep you on its books.",
        "-FAVOUR is earned alongside it and is the currency services are bought with. "
        "Spending it never costs you rank, so there is no reason to hoard it.",
        "#The five ranks",
        "-" + ranks,
        "-Each rank gives a bonus that lasts exactly as long as the rank "
        "does. The Guilds tab names the one you hold.",
        "#Services",
        "-Each guild sells three, each opened by a rank and paid for in favour. Each "
        "has a cooldown.",
        "-The price moves with your reputation: a guild that knows you charges less, one "
        "whose rival you have been courting charges more.",
    ]

    page2 = ["#What each guild pays for"]
    for gk in GUILDS:
        page2.append("-%s: %s" % (GUILD_NAMES[gk], EARN_SHORT[gk]))
    page2 += [
        # Derived per flavour, so an Empire page names the Engineers' School and not the
        # Daemonsmiths. Same three guilds, same order as the Chaos Dwarf sentence.
        "-A finished BUILDING pays its own guild - a forge the %s, a dock the %s, a "
        "barracks the %s. Higher levels pay more, and its card names the guild."
        % (short_name("daemonsmiths", tag), short_name("brass", tag),
           short_name("immortals", tag)),
        "#Every guild at once",
        # ONE LINE, NOT TWO (2026-09-23). The Empire's rivalry bullet below wraps where
        # ours does not and put this page at 22 of the panel's 21 slots; shortening this
        # bullet is the fix the flavours spec names, and it applies to every race.
        "-Every completed MISSION raises your reputation with all six guilds.",
        "#Rivalry",
        # Names shortened for this one line only. At full length the three pairs run to
        # 105 characters and wrap to "The Overseers and The / Slavers", which is worse
        # than the four characters saved. Derived from GUILD_NAMES either way, so it
        # cannot drift from what the rest of the panel calls them.
        "-" + " / ".join("%s and %s" % (short_name(a, tag), short_name(b, tag))
                         for a, b in RIVAL_PAIRS),
        # Mirrors GG.rival_cost: floored at the rank held, and nothing at all below
        # Indebted (2026-09-23). Folded into this bullet because page 2 has no spare line.
        "-Earning with one takes reputation from its rival once you reach %s there - "
        "never a rank." % RANK_NAMES[1],
        "#A limit each turn",
        "-Most guilds pay only so much each turn. The Guilds tab shows what each paid.",
    ]

    page3 = [
        "#The board",
        "-Three offers at a time, drawn from every guild. Taking one turns it into a "
        "real mission.",
        "-Finish it and that guild pays gold and a large amount of reputation - far "
        "more than an ordinary mission.",
        "-Leave it alone, or hand it back, and nothing is lost but the offer.",
        "-Take it and FAIL it and that guild takes back what finishing it would have "
        "paid. Declining work is free; promising it and not delivering is not.",
        "#The price is the target",
        "-A defended provincial capital is worth several times a ruined border town.",
        "-A veteran faction leader several times a fresh general.",
        "-Every offer is rated Routine, Hard or Grim, which is the guild saying why the "
        "number is what it is.",
        "#Two rules about the price",
        "-An offer you have NOT taken re-prices as the world moves.",
        "-One you HAVE taken keeps the price you agreed.",
    ]

    page4 = [
        "#Leading a guild",
        "-Held by whichever faction in the world has the most reputation with it - you "
        "or a rival.",
        "-The leader carries an extra bonus, and the guild's dearest service is sold to "
        "nobody else.",
        "-It can be taken from you. The Leaderboard tab shows who leads each guild.",
        "#Demands",
        "-Every so often a guild that already knows you asks for something, with a "
        "deadline on it.",
        "-It wants either gold, or the favour you hold with its own rival.",
        "-Pay it and your reputation jumps. Let the deadline pass and it falls, far "
        "enough to cost you a rank.",
        "#A patron",
        "-One of your lords, bound to one guild. Select them on the campaign map, then "
        "press Appoint.",
        "-Their army gains replenishment and campaign movement.",
        "-That guild's reputation pays half again and its services cost less.",
        "-One lord, one guild. Appointing a second moves the post.",
    ]

    page5 = [
        "#Reputation can fall",
        "-It is earned by playing and never spent - but four things take it back, and "
        "all four can cost you a rank and the bonus that came with it.",
        "#Upkeep, every turn",
        "-After the opening turns, every guild you hold reputation with takes a little "
        "of it back each turn.",
        "-The higher your rank there, the more it costs to hold. A guild you stop "
        "feeding slides back down the ladder on its own.",
        "-The Guilds tab names the figure, in red, beside your reputation.",
        "#A rival you have been feeding",
        "-Earning with a guild takes reputation from the guild it argues with. You "
        "cannot court all six at once.",
        "#A demand you let expire",
        "-The Court tab holds the terms and the deadline. Silence costs more than the "
        "demand asked for.",
        "#A bounty you took and failed",
        "-Leaving an offer alone costs nothing, and handing one back costs nothing.",
        "-Failing one you accepted costs what finishing it would have paid.",
    ]

    return [page1, page2, page3, page4, page5]


BOUNTY_CATEGORY = "Quest"
BOUNTY_TURN_LIMIT = 20


def bounty_key(guild):
    return "derpy_gg_bounty_%s" % guild


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
    for i, name in enumerate(RANK_NAMES):
        loc.append({"key": "derpy_gg_rank_name_%d" % (i + 1),
                    "text": name, "tooltip": "false"})
    for g in GUILDS:
        effect_key, scope = RANK_EFFECTS[g]
        loc.append({"key": "derpy_gg_guild_name_%s" % g,
                    "text": GUILD_NAMES[g], "tooltip": "false"})
        blurb, reach = EFFECT_BLURB[g]
        ladder = " / ".join("%s at %d reputation"
                            % (blurb % (RANK_VALUES[r] * EFFECT_GOOD_SIGN[g]),
                               RANK_THRESHOLDS[r - 1])
                            for r in range(2, 6))
        desc = "%s||Each rank gives, for %s: %s." % (GUILD_DESC[g], reach, ladder)
        extra = RANK_EFFECTS_EXTRA.get(g)
        if extra:
            xblurb, xreach = EFFECT_BLURB_EXTRA[g]
            rungs = " / ".join("%s at %d reputation" % (xblurb % extra[2][r],
                                                 RANK_THRESHOLDS[r - 1])
                               for r in range(2, 6) if extra[2][r] is not None)
            desc += " And, for %s: %s." % (xreach, rungs)
        loc.append({"key": "derpy_gg_guild_desc_%s" % g,
                    "text": desc, "tooltip": "false"})
        for rank in range(2, 6):
            key = bundle_key(g, rank)
            title = "%s - %s" % (GUILD_NAMES[g], RANK_NAMES[rank - 1])
            bundles.append({
                "key": key,
                "localised_description": "",
                # Row text alone draws a nameless icon in Faction Effects, so the
                # loc keys below ship as well. Both are needed, not either.
                "localised_title": title,
                "bundle_target": "faction",
                "priority": "1",
                "ui_icon": "",
                "is_global_effect": "true",
                "show_in_3d_space": "false",
                "owner_only": "true",
            })
            junctions.append({
                "effect_bundle_key": key,
                "effect_key": effect_key,
                "effect_scope": scope,
                "value": str(RANK_VALUES[rank] * EFFECT_GOOD_SIGN[g]),
                "advancement_stage": STAGE,
            })
            extra = RANK_EFFECTS_EXTRA.get(g)
            if extra and extra[2][rank] is not None:
                junctions.append({
                    "effect_bundle_key": key,
                    "effect_key": extra[0],
                    "effect_scope": extra[1],
                    "value": str(extra[2][rank]),
                    "advancement_stage": STAGE,
                })
            loc.append({"key": "effect_bundles_localised_title_%s" % key,
                        "text": title, "tooltip": "false"})
            blurb, reach = EFFECT_BLURB[g]
            signed = RANK_VALUES[rank] * EFFECT_GOOD_SIGN[g]
            loc.append({
                "key": "effect_bundles_localised_description_%s" % key,
                "text": "Rank %d of 5 with %s, reached at %d reputation. %s, for %s.%s "
                        "This lasts as long as the rank does."
                        % (rank, GUILD_NAMES[g], RANK_THRESHOLDS[rank - 1],
                           blurb % signed, reach, extra_sentence(g, rank)),
                "tooltip": "false"})
        # LEADING THIS GUILD. One bundle per guild, applied to whoever tops the
        # league table for it and removed the moment they stop topping it.
        lkey = lead_key(g)
        ltitle = "%s - Foremost" % GUILD_NAMES[g]
        bundles.append({
            "key": lkey,
            "localised_description": "",
            "localised_title": ltitle,
            "bundle_target": "faction",
            "priority": "1",
            "ui_icon": "",
            "is_global_effect": "true",
            "show_in_3d_space": "false",
            "owner_only": "true",
        })
        junctions.append({
            "effect_bundle_key": lkey,
            "effect_key": effect_key,
            "effect_scope": scope,
            "value": str(LEAD_VALUE * EFFECT_GOOD_SIGN[g]),
            "advancement_stage": STAGE,
        })
        loc.append({"key": "effect_bundles_localised_title_%s" % lkey,
                    "text": ltitle, "tooltip": "false"})
        loc.append({
            "key": "effect_bundles_localised_description_%s" % lkey,
            "text": "You hold more reputation with %s than any other faction in the "
                    "world. %s, for %s, on top of whatever your rank already pays - "
                    "and their greatest service is open to you alone. This lasts only "
                    "while you lead them."
                    % (GUILD_NAMES[g], blurb % (LEAD_VALUE * EFFECT_GOOD_SIGN[g]),
                       reach),
            "tooltip": "false"})

    # ----------------------------------------------------------- the patron ---
    # ONE bundle for all six guilds. It lands on an ARMY rather than a faction, which is
    # the whole point of it - a patron is a lord, not a policy.
    bundles.append({
        "key": PATRON_BUNDLE,
        "localised_description": "",
        "localised_title": PATRON_NAME,
        # force, not faction. 922 vanilla rows use it; a faction-target bundle handed
        # to apply_effect_bundle_to_force is the kind of mismatch nothing reports.
        "bundle_target": "force",
        "priority": "1",
        "ui_icon": "",
        "is_global_effect": "true",
        "show_in_3d_space": "false",
        "owner_only": "true",
    })
    for pk, psc, pv in PATRON_EFFECTS:
        junctions.append({
            "effect_bundle_key": PATRON_BUNDLE,
            "effect_key": pk,
            "effect_scope": psc,
            "value": str(pv),
            "advancement_stage": STAGE,
        })
    loc.append({"key": "effect_bundles_localised_title_%s" % PATRON_BUNDLE,
                "text": PATRON_NAME, "tooltip": "false"})
    loc.append({
        "key": "effect_bundles_localised_description_%s" % PATRON_BUNDLE,
        "text": "This lord speaks for one of the Great Guilds, and the guild answers. "
                "%s for their army. While they hold the post, that guild's reputation "
                "pays half again and its services cost %d%% less. Only one lord may "
                "hold it."
                % (patron_clause(), PATRON_DISCOUNT),
        "tooltip": "false"})

    for s in SERVICES:
        loc.append({"key": "derpy_gg_service_name_%s" % s["key"],
                    "text": SERVICE_NAMES[s["key"]], "tooltip": "false"})
        blurb, reach = EFFECT_BLURB[s["guild"]]
        signed = service_value(s) * service_sign(s)
        body = SERVICE_BLURB[s["key"]]
        if body is None and s.get("hostile"):
            # Inflicted, not received. The sign is already inverted for this.
            body = ("Inflicts %s on a faction you are at war with, across %s, for "
                    "%d turns. You gain nothing directly - they simply pay more."
                    % (blurb % signed, EFFECT_REACH_THEIRS[s["guild"]], s["turns"]))
        elif body is None:
            # A bundle service has no bespoke sentence: its payload IS the effect.
            body = "%s, for %s, for %d turns." % (blurb % signed, reach, s["turns"])
        gate = ""
        if s["key"] in LEAD_SERVICES:
            gate = (" Only the faction that leads %s may buy it."
                    % GUILD_NAMES[s["guild"]])
        loc.append({
            "key": "derpy_gg_service_desc_%s" % s["key"],
            "text": "%s||Costs %d favour. Cooldown %d turns. Needs rank %d, %s.%s"
                    % (body, s["cost"], s["cd"], s["rank"],
                       RANK_NAMES[s["rank"] - 1], gate),
            "tooltip": "false"})
        if s["kind"] != "bundle":
            continue
        effect_key, scope = RANK_EFFECTS[s["guild"]]
        key = service_bundle_key(s["key"])
        bundles.append({
            "key": key,
            "localised_description": "",
            "localised_title": SERVICE_NAMES[s["key"]],
            "bundle_target": "faction",
            "priority": "1",
            "ui_icon": "",
            "is_global_effect": "true",
            "show_in_3d_space": "false",
            "owner_only": "true",
        })
        junctions.append({
            "effect_bundle_key": key,
            "effect_key": effect_key,
            "effect_scope": scope,
            # A service is a burst, not a rung: worth more than any rank bundle
            # but for a handful of turns. Same sign rule as the rank ladder.
            "value": str(service_value(s) * service_sign(s)),
            "advancement_stage": STAGE,
        })
        loc.append({"key": "effect_bundles_localised_title_%s" % key,
                    "text": SERVICE_NAMES[s["key"]], "tooltip": "false"})
        loc.append({
            "key": "effect_bundles_localised_description_%s" % key,
            "text": ("Inflicted by %s, bought with favour. %s, across %s. "
                     "Runs for %d turns."
                     % (GUILD_NAMES[s["guild"]], blurb % signed,
                        EFFECT_REACH_THEIRS[s["guild"]], s["turns"]))
                    if s.get("hostile") else
                    ("Bought from %s with favour. %s, for %s. Runs for %d turns."
                     % (GUILD_NAMES[s["guild"]], blurb % signed, reach, s["turns"])),
            "tooltip": "false"})

    # Panel chrome. Every key here is read by GGUI at draw time; a missing loc key
    # is not an error, GGUI.loc falls back to the key itself, so the symptom is a
    # raw key on screen rather than a crash.
    loc.append({"key": "derpy_gg_panel_title", "text": PANEL_TITLE,
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_favour", "text": "Favour", "tooltip": "false"})
    loc.append({"key": "derpy_gg_reputation", "text": "Reputation", "tooltip": "false"})
    loc.append({"key": "derpy_gg_you", "text": "You", "tooltip": "false"})
    # THE GUILDS TAB'S "REPUTATION THIS TURN" LINE and its hover (GGUI.earned_line).
    # One src_ row per GG.LEDGER_SOURCES entry - the Lua builds those keys at runtime, so
    # check_ledger_sources() is what proves every one of them ships.
    for key, text in (("earned_now", "Reputation this turn:"),
                      ("earned_last", "Last turn:"),
                      ("earned_none", "none"),
                      ("earned_more", "and more"),
                      ("earned_held", "over this turn's limit, not paid"),
                      ("earned_limit", "The most this guild pays you in one turn:"),
                      ("earned_no_limit", "This guild has no limit per turn."),
                      ("earned_help", "Bounties and paid demands always pay in full."),
                      ("src_income", "income"), ("src_battles", "battles"),
                      ("src_research", "research"), ("src_agents", "hero actions"),
                      ("src_buildings", "buildings"),
                      ("src_settlements", "settlements taken"),
                      ("src_missions", "missions"), ("src_bounties", "bounties"),
                      ("src_demands", "demands paid"), ("src_other", "other"),
                      ("src_withheld", "Over the limit, not paid:")):
        loc.append({"key": "derpy_gg_" + key, "text": text, "tooltip": "false"})

    # The two-currency split is the one thing about this mod a player cannot infer
    # from the panel, so it is stated outright in the title tooltip.
    #
    # TWO SENTENCES AND THE LADDER. This was five paragraphs and covered a quarter of
    # the screen on hover - reported from play, 2026-09-12, as "way too long". A tooltip
    # is read standing up, in the half second before the cursor moves on; the long
    # version of all of this is the Help tab, which is four pages and has room for it.
    # What survives here is only what a player cannot infer from the panel itself: that
    # there are two numbers and that spending one does not cost the other.
    loc.append({
        "key": "derpy_gg_standing_help",
        "text": "REPUTATION sets your rank, and it can fall. FAVOUR is earned "
                "alongside it and is what you spend - spending it never costs you rank."
                "||%s"
                "||Help tab: the full rules."
                % " / ".join("%s %d" % (RANK_NAMES[i], RANK_THRESHOLDS[i])
                             for i in range(5)),
        "tooltip": "false"})
    loc.append({"key": "derpy_gg_cost_label", "text": "Favour cost",
                "tooltip": "false"})
    # The tab row, the pager and the Buy button. Each of these is a button the Lua
    # writes text onto at draw time; without these keys they draw their own key.
    for key, text in (("tab_guilds", "Guilds"), ("tab_stand", "Leaderboard"),
                      # The Bounties tab. It replaced "Log", which was a tab the panel
                      # switched to and then drew nothing into.
                      ("tab_bounty", "Bounties"), ("tab_help", "Help"),
                      # THE LOG, BACK (2026-09-23), with a record behind it this time:
                      # GG.log_entries. The line reads "<Guild>:  <fragment> <name>.",
                      # so the fragments are lower-case and carry no full stop.
                      ("tab_log", "Log"),
                      ("hdr_log", "What has happened, newest first."),
                      ("log_help", "Every rank you gain or lose, every service you buy, "
                                   "every service your rivals buy or use against you, "
                                   "and every guild lead that changes hands. The most "
                                   "recent entries are kept."),
                      ("log_empty", "Nothing yet. Ranks gained and lost, services "
                                    "bought and leads changing hands are recorded "
                                    "here."),
                      ("log_turn", "Turn"),
                      ("log_rose", "you rose to"),
                      ("log_fell", "you fell to"),
                      ("log_bought", "you bought"),
                      ("log_ai_bought", "bought"),
                      ("log_hit", "was used against you by"),
                      ("log_lead_won", "you took the lead"),
                      ("log_lead_lost", "you lost the lead to"),
                      ("log_from", "from"),
                      ("take", "Take"), ("bounty_none", "No bounty on offer"),
                      ("bounty_taken", "Taken"), ("bounty_pays", "Pays"),
                      ("bounty_turns", "turns left"),
                      # A lord bounty names the owning faction, not the character: a
                      # character's own name needs a loc call this panel cannot make
                      # cheaply, and the faction is the part a player navigates by.
                      ("bounty_lord", "Their general"),
                      # Labels the standings' third column. Without it the row read
                      # "The Brass Tablets  Unmarked (63)  You Unmarked" - two ranks
                      # side by side and nothing saying which was whose.
                      ("leader", "Leader"),
                      # Shown when no faction has any reputation with a guild at all,
                      # which is every guild in a campaign's first turns.
                      ("nobody", "Nobody yet"),
                      # The three tabs that are not per-guild get a header naming the
                      # view, because the pager that used to change that line is
                      # hidden on them - it had nothing to page.
                      ("hdr_stand", "Hover a row for the full table."),
                      ("hdr_bounty", "Three offers, drawn from every guild."),
                      ("hdr_help", "How the Great Guilds work."),
                      # Reputation is the only number in the mod that can fall, so the
                      # guild that makes it fall has to be on screen.
                      ("rival", "Rival:"),
                      # A bounty's pay is read off its target, so three offers sit at
                      # three prices. Without a word for WHY, that reads as a bug.
                      ("bounty_routine", "Routine"),
                      ("bounty_hard", "Hard"),
                      ("bounty_grim", "Grim"),
                      # A service's price moves with your standing, so the card has to
                      # say what moved it or the number looks wrong.
                      ("cost_base", "base"),
                      ("cost_loyal", "The guild knows you, and charges less."),
                      ("cost_rival", "You wear their rival's mark, and they charge "
                                     "for it."),
                      # The hostile service reads its target from the campaign map's own
                      # selection, so the card has to say so rather than refusing a
                      # button that looked live.
                      ("needs_target", "Select an enemy character on the campaign map "
                                       "first - this service is aimed at their faction."),
                      ("needs_target_short", "Pick a target"),
                      # ONE REFUSAL STRING ANSWERED FOR ALL FIVE targeted services and
                      # was right for one of them. A player told to select an enemy, who
                      # does, and is refused anyway, is debugging the mod.
                      ("needs_army", "Select one of your own armies on the campaign map "
                                     "first - the regiment joins whoever is selected."),
                      ("needs_region_any", "Select a settlement on the campaign map "
                                           "first - its region is what gets revealed."),
                      ("needs_region_own", "Select one of your OWN settlements on the "
                                           "campaign map first, with a building that "
                                           "still has somewhere to go."),
                      ("needs_research", "Start researching something first - this "
                                         "finishes whatever technology you have queued "
                                         "in the tech tree."),
                      # Every culture in the campaign runs guilds now, and only three
                      # have a unit mapped. Refusing is right - the old fallback would
                      # have dropped a Chaos Dwarf regiment into an Araby army.
                      ("no_unit", "This guild keeps no regiment your people would "
                                  "muster. Their other services are open to you."),
                      # THE LEAGUE TABLE. The Standings tab printed one name per guild
                      # and threw the other five away, so nobody could see second place
                      # or their own position.
                      # THE UPKEEP. Medieval 2 charges a hidden point a turn and
                      # shows the player nothing anywhere, which is the one complaint
                      # the guide makes about it. This is that number, on screen.
                      # "/turn" with no space: it sits on a 750px line that already
                      # carries three numbers and the rival's name.
                      ("per_turn", "/turn"),
                      ("upkeep_on", "Upkeep, taken every turn:"),
                      ("upkeep_soon", "An upkeep begins on turn"),
                      ("upkeep_help", "Reputation has to be held, not just won. Every "
                                      "guild you have reputation with charges a little "
                                      "back each turn, and the higher your rank the "
                                      "more it costs to sit on - so a guild you stop "
                                      "feeding slides back down the ladder, and its "
                                      "bonus goes with it."),
                      ("table_head", "Reputation with this guild:"),
                      ("more", "more"),
                      ("unranked", "no reputation yet"),
                      ("buy", "Buy"), ("prev", "<"), ("next", ">"),
                      # THE COURT. The fifth tab, holding the two things that are done
                      # TO you and the one thing you do with a lord.
                      ("tab_court", "Court"),
                      ("hdr_court", "Demands, patronage and who leads."),
                      # Leadership, which until now was printed and never paid.
                      ("needs_lead", "Foremost only"),
                      ("lead_you", "You lead them"),
                      ("lead_by", "Led by"),
                      ("lead_title", "Foremost"),
                      ("lead_hint", "Only the faction holding the most reputation "
                                    "with this guild may buy this. Out-earn whoever "
                                    "holds it."),
                      # The patron.
                      ("patron_none", "No patron appointed"),
                      ("patron_appoint", "Appoint"),
                      ("patron_dismiss", "Dismiss"),
                      ("patron_of", "Patron"),
                      ("patron_needs_char", "Select one of your own lords on the "
                                            "campaign map, then press Appoint."),
                      ("patron_elsewhere", "Your patron already serves another guild. "
                                           "Appointing here moves them."),
                      # The demands.
                      ("demand_none", "No demand stands against you"),
                      ("demand_pay", "Pay"),
                      ("demand_owed", "They want"),
                      ("demand_due", "turns to pay"),
                      ("demand_short", "You cannot pay this yet"),
                      ("demand_gold", "gold"),
                      ("demand_favour", "favour"),
                      # Prefixes the rank a locked service wants, so the red text on
                      # the card reads as a requirement and not as a label.
                      ("needs", "Needs"),
                      # THE QUALITY-OF-LIFE PASS, 2026-09-25. The HUD opener's hover
                      # names what its count is counting.
                      ("opener_ready", "Ready to buy:"),
                      ("opener_none", "Nothing needs you right now."),
                      ("opener_bounties", "Bounties to take:"),
                      ("opener_demand", "A demand you can pay now:"),
                      ("opener_click", "Click to open."),
                      # The arrows and the six guild buttons say where they go.
                      ("pager_end", "Nothing further this way."),
                      ("pager_page_next", "Next page"),
                      ("pager_page_prev", "Previous page"),
                      ("ready", "ready to buy"),
                      # A big spend asks once before it goes.
                      ("confirm", "Confirm"),
                      ("confirm_tip", "This spends half or more of your favour with "
                                      "this guild, or is aimed at another faction. "
                                      "Press Confirm to go ahead."),
                      # A Leaderboard row's icon opens that guild.
                      ("open_guild", "Click to see this guild's services."),
                      # Picking a target with the panel out of the way.
                      ("pick_button", "Select"),
                      ("pick_help", "Press Select to move this panel aside while you "
                                    "choose on the map."),
                      ("pick_cancel", "Press Escape or Cancel to go back."),
                      ("cancel", "Cancel"),
                      # Map links on the bounty board and the Leaderboard's list.
                      ("map_tip", "Click the card to see the target on the map."),
                      ("frow_map", "Click to see their capital on the map."),
                      # The Log's filters.
                      ("lf_all", "All"), ("lf_mine", "Yours"),
                      ("lf_rivals", "Rivals"), ("lf_ranks", "Ranks"),
                      ("log_empty_filter", "Nothing of this kind yet. Press All to see "
                                           "every entry.")):
        loc.append({"key": "derpy_gg_" + key, "text": text, "tooltip": "false"})
    for dk, d in sorted(DEMAND_KINDS.items()):
        loc.append({"key": "derpy_gg_demand_name_" + dk, "text": d["name"],
                    "tooltip": "false"})
        loc.append({"key": "derpy_gg_demand_desc_" + dk, "text": d["blurb"],
                    "tooltip": "false"})

    # The Help tab. One key per page, lines joined by the same "||" every other
    # multi-paragraph string in this mod uses - so a blank line is an empty segment and
    # survives the split.
    pages = help_pages(tag)
    for _i, _lines in enumerate(pages):
        loc.append({"key": "derpy_gg_help_t%d" % (_i + 1),
                    "text": HELP_PAGE_TITLES[_i], "tooltip": "false"})
        loc.append({"key": "derpy_gg_help_p%d" % (_i + 1),
                    "text": "||".join(_lines), "tooltip": "false"})
    loc.append({"key": "derpy_gg_help_of", "text": "of", "tooltip": "false"})

    loc.append({"key": "derpy_gg_court_help",
                "text": "The Court holds the three things a guild does that you do not "
                        "choose."
                        "||LEADING a guild is held by whichever faction in the world "
                        "has the most reputation with it - you or a rival. The leader "
                        "carries an extra bonus for as long as they lead, and the "
                        "guild's dearest service is sold to nobody else. It can be "
                        "taken from you."
                        "||A DEMAND arrives every so often from a guild that already "
                        "knows you. Pay it and your reputation with them jumps; let the "
                        "deadline pass and it falls, far enough to cost you a rank. A "
                        "guild asks either for gold or for you to renounce the favour "
                        "you hold with its rival."
                        "||A PATRON is one of your lords, bound to one guild. Their "
                        "army is the better for it, that guild's reputation pays half "
                        "again, and its services cost less. One lord, one guild - "
                        "appointing a second moves the post.",
                "tooltip": "false"})

    # The feed, both halves. A demand that arrives silently is a deadline nobody saw.
    loc.append({"key": "message_event_text_text_derpy_gg_demand_title",
                "text": "A Guild Asks", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_demand_primary",
                "text": "One of the Great Guilds has made a demand of you. The Court "
                        "tab holds the terms and the deadline.", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_demand_secondary",
                "text": "They do not ask twice.", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_demand_fail_title",
                "text": "A Guild Is Answered With Silence", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_demand_fail_primary",
                "text": "The deadline has passed and nothing was paid. Your reputation "
                        "with that guild has fallen.", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_demand_fail_secondary",
                "text": "The ledger is kept whether you read it or not.",
                "tooltip": "false"})

    # A FAILED BOUNTY, on the demand record: a feed record is presentation, and a guild
    # taking reputation back for work not done looks the same whichever way it was owed.
    loc.append({"key": "message_event_text_text_derpy_gg_bounty_fail_title",
                "text": "A Guild Is Left Waiting", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_bounty_fail_primary",
                "text": "Work you took from a guild has gone undone, and its reputation "
                        "has been taken back. Handing an offer back costs nothing; "
                        "taking it and failing costs what finishing it would have paid.",
                "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_bounty_fail_secondary",
                "text": "A promise in the ledger is a debt.", "tooltip": "false"})

    loc.append({"key": "derpy_gg_bounty_help",
                "text": "A guild posts work it wants done. Take one and it becomes a mission; finish it "
        "and that guild pays gold and a large amount of reputation - far more than "
        "a normal mission. Leave an offer alone, or hand it back through the "
        "objectives panel, and nothing is lost but the offer."
        "||BUT DO NOT TAKE ONE AND FAIL IT. A bounty you accepted and did not "
        "finish before its deadline costs that guild's reputation - "
        "exactly what finishing it would have paid. Declining work is free; "
        "promising it and not delivering is not."
        "||The pay is read off the target, not fixed: a defended provincial capital "
        "is worth several times a ruined border town, and a rank-40 faction leader "
        "several times a fresh general. Each offer says whether the guild rates the "
        "job Routine, Hard or Grim. An offer you have not taken re-prices as the "
        "world moves; one you have taken keeps the price you agreed.",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_locked_hint",
                "text": "Your rank with this guild is too low. Keep earning reputation.",
                "tooltip": "false"})

    # The feed message the player sees when a hostile service lands on them.
    loc.append({"key": "message_event_text_text_derpy_gg_hit_title",
                "text": "A Guild Moves Against You", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_hit_primary",
                "text": "A rival has bought the favour of a guild, and it has been "
                        "spent on you.", "tooltip": "false"})
    loc.append({"key": "message_event_text_text_derpy_gg_hit_secondary",
                "text": "Their favour buys more than goods.", "tooltip": "false"})

    # ------------------------------------------------------------------------
    # THE AI, MADE VISIBLE. Everything below exists because the rivals were playing
    # this mod in complete silence. They accrued, bought services, answered demands,
    # appointed patrons and took guilds off the player, and the only trace of any of it
    # was a name on the Standings tab that was different from the last time you looked -
    # with nothing to say it had changed, when, or by how much.
    #
    # Leadership changing hands is announced on the feed, and only when the player is
    # one of the two parties. An AI taking a guild off another AI is a fact for the
    # panel, not an interrupt.
    #
    # TWELVE PAIRS, one per guild per direction, because cm:show_message_event takes loc
    # KEYS - there is nowhere to interpolate a guild's name into one, so naming it means
    # a key per guild.
    #
    # THE FULL NAME IN THE TITLE TOO. These twelve were the last strings still built from
    # short_name(), which strips the leading article: that reads as a headline for the
    # five plural guild names and as a mistake for the one singular one, and a player
    # screenshotted "Khanate Answer To You" on 2026-09-12. The promotion and notice
    # titles were moved to the full name for this reason already; these were left as out
    # of scope at the time and are the same defect. check_titles() now refuses any
    # message-event title that names a guild without its article.
    for _g in GUILDS:
        _full = GUILD_NAMES[_g]
        loc.append({"key": "message_event_text_text_derpy_gg_lead_won_%s_title" % _g,
                    "text": "%s Answer To You" % _full, "tooltip": "false"})
        loc.append({"key": "message_event_text_text_derpy_gg_lead_won_%s_primary" % _g,
                    "text": "You now hold more reputation with %s than any other power "
                            "in the world. Their leader's bonus is yours, and their "
                            "finest service is sold to nobody else." % _full,
                    "tooltip": "false"})
        loc.append({"key": "message_event_text_text_derpy_gg_lead_won_%s_secondary" % _g,
                    "text": "It is taken back the same way it was won.",
                    "tooltip": "false"})
        loc.append({"key": "message_event_text_text_derpy_gg_lead_lost_%s_title" % _g,
                    "text": "%s Have Turned Away" % _full, "tooltip": "false"})
        loc.append({"key": "message_event_text_text_derpy_gg_lead_lost_%s_primary" % _g,
                    "text": "A rival has out-earned you with %s. Their leader's bonus, "
                            "and the sole right to their finest service, went with them."
                            % _full,
                    "tooltip": "false"})
        loc.append({"key":
                    "message_event_text_text_derpy_gg_lead_lost_%s_secondary" % _g,
                    "text": "The Leaderboard tab names who holds it now.",
                    "tooltip": "false"})

    # THE PROMOTION TEXT. One key set per guild per rank, 72 rows, for the same reason the
    # leadership set is 36: cm:show_message_event takes loc KEYS and there is nowhere to
    # interpolate a guild name or a rank name into one. Rank 0 (Unmarked) is where everyone
    # starts and is never announced.
    # range(2, 6), matching bundle_key's own `assert 2 <= rank <= 5`. Ranks are 1-based
    # and rank 1 is Unmarked; RANK_NAMES is a 0-indexed Python list, so the name for
    # rank r is RANK_NAMES[r - 1].
    for _g in GUILDS:
        _full = GUILD_NAMES[_g]
        for _r in range(2, len(RANK_NAMES) + 1):
            _rank = RANK_NAMES[_r - 1]
            _stem = "message_event_text_text_derpy_gg_rank_%s_%d" % (_g, _r)
            # THE FULL NAME, NOT THE SHORT ONE. short_name() strips the leading article,
            # which is fine for five plural guild names but wrong for the one singular
            # one: "Khanate Name You Indebted" drops the article a singular collective
            # subject needs. The article is load-bearing here, so the full name is used.
            loc.append({"key": _stem + "_title",
                        "text": "%s Name You %s" % (_full, _rank),
                        "tooltip": "false"})
            loc.append({"key": _stem + "_primary",
                        "text": "Your rank with %s has risen to %s. Their bonus to "
                                "you has grown, and a service that was closed to you is "
                                "open." % (_full, _rank),
                        "tooltip": "false"})
            loc.append({"key": _stem + "_secondary",
                        "text": "Favour is spent on the Guilds tab.",
                        "tooltip": "false"})

    # THE TWO ONE-TIME NOTICES. First contact and halfway to the first rank, per guild
    # because the guild is the thing with flavour and the thing that tells the player where
    # to look. Both fire at most once per campaign, not once per guild - the guild in the
    # key is whichever one happened to trigger it.
    _NOTICE = {
        "first": ("%s Have Noticed You",
                  "Word of your doings has reached %s. They keep a ledger of every power "
                  "in the world, and your name is now in it. Reputation with them is earned "
                  "by playing as you already play; what it buys is on the Guilds panel.",
                  "The guild crest at the top of your screen opens it."),
        "half": ("%s Are Watching Closely",
                 "You are halfway to your first rank with %s. At " + RANK_NAMES[1]
                 + " they open their first service to you.",
                 "The Guilds panel shows how far every guild has come."),
    }
    for _tag in ("first", "half"):
        _title, _primary, _secondary = _NOTICE[_tag]
        for _g in GUILDS:
            _full = GUILD_NAMES[_g]
            _stem = "message_event_text_text_derpy_gg_notice_%s_%s" % (_tag, _g)
            # THE FULL NAME. Same reason as the promotion title just above: the Khanate
            # is the one singular guild name, and dropping its article for the short form
            # reads wrong for its entire earn route.
            loc.append({"key": _stem + "_title", "text": _title % _full,
                        "tooltip": "false"})
            loc.append({"key": _stem + "_primary", "text": _primary % _full,
                        "tooltip": "false"})
            loc.append({"key": _stem + "_secondary", "text": _secondary,
                        "tooltip": "false"})

    # The Standings tab's activity line and its row markers. Short fragments, because
    # the whole line has to fit 750px and it already carries three numbers.
    loc.append({"key": "derpy_gg_rivals", "text": "Rivals last turn:",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_rivals_bought", "text": "services bought",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_rivals_demands", "text": "demands paid",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_rivals_patrons", "text": "patrons appointed",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_rivals_idle",
                "text": "Rivals have not moved yet - end a turn.", "tooltip": "false"})
    loc.append({"key": "derpy_gg_rivals_help",
                "text": "What the other powers of the world did with their guilds "
                        "last turn: services they bought with favour, "
                        "demands they answered, and lords serving as guild "
                        "patrons.||Every one of these is a tool you have too. The "
                        "rivals are playing for the same six guilds you are."
                        "||Each row below names who leads that guild, how much "
                        "reputation the leader gained last turn, and marks the "
                        "name in yellow when the guild changed hands.",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_took", "text": "changed hands this turn",
                "tooltip": "false"})
    loc.append({"key": "derpy_gg_gained", "text": "gained", "tooltip": "false"})

    # THE BOUNTY MISSION ROWS. Shaped field-for-field like CA's own ogre contract
    # rows (69 of them, read out of the vanilla missions table on 2026-09-11): the real
    # objective type in mission_type rather than SCRIPTED, `generate false` so the CDIR
    # never issues one on its own, and can_be_manually_cancelled true so a player can
    # put a bounty back rather than carrying it to its expiry.
    #
    # The three localised columns are decoration. The runtime reads
    # missions_localised_{title,description,mission_completed_text}_<key> out of loc -
    # a missing one is a blank title in the objectives panel with nothing in any log -
    # so they are written below as well, and written the same.
    missions = []
    for g in GUILDS:
        kind = BOUNTIES[g][0]
        title, desc = F["bounties"][g]
        done = "The guild has been paid in full, and so have you."
        missions.append({
            "key": bounty_key(g), "mission_type": BOUNTY_KINDS[kind]["mtype"],
            "localised_title": title, "localised_description": desc,
            "ui_image": "chd/generic", "ui_icon": "rom_event_mission.png",
            "generate": "false", "prioritised": "false",
            "event_category": BOUNTY_CATEGORY, "set_piece_battle": "",
            "location_x": "0", "location_y": "0",
            "quest_mission": "false", "quest_mission_final": "false",
            "trigger_radius": "0.0000", "quest_character": "",
            "sticky_by_default": "false",
            "localised_mission_completed_text": done,
            "can_be_manually_cancelled": "true",
        })
        loc.append({"key": "missions_localised_title_%s" % bounty_key(g),
                    "text": title, "tooltip": "false"})
        loc.append({"key": "missions_localised_description_%s" % bounty_key(g),
                    "text": desc, "tooltip": "false"})
        loc.append({"key": "missions_localised_mission_completed_text_%s"
                    % bounty_key(g), "text": done, "tooltip": "false"})

    return {"missions": missions,
            "effect_bundles": bundles,
            "effect_bundles_to_effects_junctions": junctions,
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
            "loc": loc}


def tag_loc_key(key, tag):
    """Where a flavour's tag goes in a loc key - the same place the Lua puts it.

    Before the engine's own suffix on a message-event key, because the Lua passes a stem
    and appends _title / _primary / _secondary itself. At the end of everything else.
    """
    m = re.match(r"(message_event_text_text_.+?)(_title|_primary|_secondary)$", key)
    if m:
        return m.group(1) + tag + m.group(2)
    return key + tag


def picture(F, image):
    """A Chaos Dwarf event picture ("chd/messenger") in flavour F's own folder, or the
    picture F names for it outright."""
    name = image.split("/", 1)[1]
    return F.get("pictures", {}).get(name, F["pics"] + "/" + name)


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
        "missions": [dict(r, key=r["key"] + tag,
                          ui_image=F.get("mission_pic", F["pics"] + "/generic"))
                     for r in tables["missions"]],
        "campaign_groups": [dict(r, id=r["id"] + tag)
                            for r in tables["campaign_groups"]],
        "campaign_group_members": [dict(r, group=r["group"] + tag, id=r["id"] + tag)
                                   for r in tables["campaign_group_members"]],
        "campaign_group_member_criteria_values": [
            dict(r, member=r["member"] + tag, value=str(int(r["value"]) + F["feed"]))
            for r in tables["campaign_group_member_criteria_values"]],
        "event_feed_message_events": [
            dict(r, group=r["group"] + tag, image=picture(F, r["image"]))
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
    # Keyed per race already, so it is added once rather than retagged.
    for table, rows in built_tables().items():
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


def check_table_versions():
    """Every declared table version must be the one CA's own file declares.

    A wrong version is not a warning and not a refused import: the game parses the rows
    against the wrong field shape and dies during loading, before any script runs, with
    nothing written to bad_mods_report.txt and no minidump. That is what shipping
    missions_tables at version 6 did on 2026-09-11.
    """
    out = []
    try:
        sys.path.insert(0, "tools")
        import read_vanilla_cache as R
        for table, (name, ver) in sorted(TSV_META.items()):
            if table == "loc":
                continue        # Loc is not a DB table and has no vanilla counterpart
            if not R.have(table):
                out.append("no cached vanilla %s to check the version against - run "
                           "tools/fetch_vanilla_tables.py %s" % (table, table))
                continue
            ca = R.version(table)
            if ca != ver:
                out.append("%s is declared at version %d but CA's own file declares %d "
                           "- the game parses the rows against the wrong field shape and "
                           "crashes during loading" % (name, ver, ca))
    except Exception as e:
        out.append("table version checks could not run: %r" % (e,))
    return out


def check_bounties():
    """The three ways a bounty row fails without saying anything.

    1. event_category is a foreign key into cdir_events_categories. An invented value
       is a load-time DB reject, which surfaces as "Failed to load mod" or a line in
       bad_mods_report.txt, not as anything the game says out loud.
    2. mission_type must be one CA itself drives from a mission string, because that
       is the only evidence a type accepts a target chosen at runtime.
    3. The three localised_* columns are decoration; the runtime reads
       missions_localised_*_<key> from loc. A missing key draws a blank title with
       nothing in any log.
    """
    out = []
    tables = build()
    rows = tables["missions"]
    lockeys = set(r["key"] for r in tables["loc"])

    if len(rows) != len(GUILDS) * len(FLAVOURS):
        out.append("one bounty per guild per flavour: %d rows for %d guilds and %d "
                   "flavours" % (len(rows), len(GUILDS), len(FLAVOURS)))
    for g in GUILDS:
        if g not in BOUNTIES:
            out.append("no bounty defined for guild: " + g)
            continue
        kind = BOUNTIES[g][0]
        if kind not in BOUNTY_KINDS:
            out.append("%s: bounty kind %r is not in BOUNTY_KINDS" % (g, kind))

    keys = [r["key"] for r in rows]
    if len(set(keys)) != len(keys):
        out.append("duplicate bounty mission keys - the game drops duplicates silently")
    for k in keys:
        if k != k.lower():
            out.append("uppercase in a mission key: " + k)
        for field in ("title", "description", "mission_completed_text"):
            want = "missions_localised_%s_%s" % (field, k)
            if want not in lockeys:
                out.append("%s has no %s loc key - the panel draws it blank" % (k, field))

    try:
        sys.path.insert(0, "tools")
        import read_vanilla_cache as R
        cats = set(r["category_key"] for r in R.load("cdir_events_categories")[0])
        if BOUNTY_CATEGORY not in cats:
            out.append("event_category %r is not a cdir_events_categories row - an "
                       "unresolvable foreign key is a load-time reject"
                       % BOUNTY_CATEGORY)
        mrows, _ = R.load("missions")
        # The types CA issues from a string with a generated target, taken from the rows
        # it ships for its own contracts rather than from the type vocabulary at large.
        ca_contract_types = set(r["mission_type"] for r in mrows
                                if r.get("event_category") == "OgreContract")
        for g in GUILDS:
            kind = BOUNTY_KINDS[BOUNTIES[g][0]]
            if kind["mtype"] not in ca_contract_types:
                out.append("%s: no CA contract row carries mission_type %s, so the "
                           "column is guesswork" % (g, kind["mtype"]))
            if kind["otype"] not in CA_CONTRACT_OBJECTIVES:
                out.append("%s: CA's contract script never issues objective type %s "
                           "against a runtime target, so nothing proves it accepts one"
                           % (g, kind["otype"]))
    except Exception as e:
        out.append("bounty vanilla checks could not run: %r" % (e,))
    return out


# The deepest discount GG.service_cost can apply, mirrored from the Lua. A service
# whose base is low enough that the discount floors it at zero would be free, and the
# runtime cannot guard against that without a line that never fires.
FAVOUR_MIN_MOD = -30


def check_rival_mirror():
    """RIVAL_PAIRS must be exactly GG.RIVALS in the Lua.

    The help page names the three pairings. A pairing named here and absent there is a
    rule the panel teaches and the mod does not have, which is worse than saying nothing.
    """
    out = []
    path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    try:
        lua = io.open(path, encoding="utf-8").read()
    except IOError:
        return ["cannot read %s to check the rivalry mirror" % path]
    body = re.search(r"GG\.RIVALS\s*=\s*\{(.*?)\}", lua, re.S)
    if not body:
        return ["GG.RIVALS is not declared in " + path]
    theirs = set()
    for a, b in re.findall(r"(\w+)\s*=\s*\"(\w+)\"", body.group(1)):
        theirs.add(tuple(sorted((a, b))))
    mine = set(tuple(sorted(p)) for p in RIVAL_PAIRS)
    for p in sorted(mine - theirs):
        out.append("the help names %s and %s as rivals and the Lua does not pair them"
                   % p)
    for p in sorted(theirs - mine):
        out.append("the Lua pairs %s with %s and the help page never says so" % p)
    return out


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
    if len(pages) != len(HELP_PAGE_TITLES):
        out.append("%d help pages and %d titles" % (len(pages), len(HELP_PAGE_TITLES)))
    for gk in GUILDS:
        if gk not in EARN_SHORT:
            out.append("no one-line earn route for %s, so its help bullet is blank" % gk)
    for i, lines in enumerate(pages):
        if not lines:
            out.append("help page %d is empty" % (i + 1))
        # "||" is the separator. A line containing one would split into two, and the
        # halves would be rendered as whatever their first character happens to be.
        for line in lines:
            if "||" in line:
                out.append("help page %d has a line containing the separator: %r"
                           % (i + 1, line[:40]))
        # A page that opens on a bullet reads as the tail of something above it.
        if not lines[0].startswith("#"):
            out.append("help page %d does not open with a heading" % (i + 1))
    # AND EVERY PAGE MUST FIT THE PANEL'S SLOTS. GGUI.help_lines pushes through a guard
    # that DROPS anything past GGUI.HELP_SLOTS, so an overlong page loses its tail in
    # silence - no error, no clipping, just text that is not there. The UI file's own
    # comment has claimed since it was written that this function proved the fit; it did
    # not, and a page went over the moment three lines were added to it on 2026-09-13.
    #
    # A LOWER BOUND, NOT AN ESTIMATE. The real count needs the game's text ruler, which
    # is not reachable from here, so this counts only what is certain: every source line
    # takes at least one slot, and GGUI.help_lines pushes a BLANK before every heading
    # except one opening the page. Wrapping can only make it worse, never better - so a
    # page failing this is definitely over, and one passing it may still be. Keep a
    # margin rather than sitting on the boundary.
    path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua"
    try:
        lua = io.open(path, encoding="utf-8").read()
    except IOError:
        return out + ["cannot read %s to check the help pages against the panel" % path]
    slots = re.search(r"GGUI\.HELP_SLOTS\s*=\s*(\d+)", lua)
    if not slots:
        out.append("GGUI.HELP_SLOTS is not declared, so no page can be checked for fit")
    else:
        cap = int(slots.group(1))
        for i, lines in enumerate(pages):
            least = 0
            for j, line in enumerate(lines):
                least += 1
                if line.startswith("#") and j > 0:
                    least += 1          # help_lines pushes a blank above a heading
            if least > cap:
                out.append("help page %d needs at least %d of the panel's %d slots "
                           "before any wrapping - GGUI.help_lines DROPS the overflow "
                           "silently, so the tail of that page would simply not be on "
                           "screen" % (i + 1, least, cap))
            elif least > cap - 3:
                out.append("help page %d needs at least %d of %d slots before wrapping, "
                           "which leaves no margin - one long bullet wrapping to a "
                           "second line drops the end of the page with no error"
                           % (i + 1, least, cap))
    m = re.search(r"GGUI\.HELP_PAGES\s*=\s*(\d+)", lua)
    if not m:
        out.append("GGUI.HELP_PAGES is not declared, so the pager has no range")
    elif int(m.group(1)) != len(pages):
        out.append("GGUI.HELP_PAGES is %s and there are %d help pages - the extra ones "
                   "are unreachable" % (m.group(1), len(pages)))
    return out


def check_feed_mirror():
    """The Lua's feed indices must be the ones minted here, and its text keys must ship.

    Both halves fail the same way, which is why they are one check: a wrong index and a
    missing loc key both make cm:show_message_event log that it showed a message and
    draw absolutely nothing. There is no error, no feed entry and no log line saying
    why - so a leadership change worth a permanent bundle would simply never be
    announced, and nothing in a test run would look wrong.

    Nothing checked either of these until the third feed record was added; the first two
    indices have been declared twice, in two files, unpinned, since the mod shipped.
    """
    out = []
    lua = ""
    for name in ("zzz_derpy_guilds.lua", "zzz_derpy_guilds_ai.lua"):
        path = "Modding Files/pack/script/campaign/mod/" + name
        try:
            lua += io.open(path, encoding="utf-8").read()
        except IOError:
            return ["cannot read %s to check the feed indices" % path]

    for lua_name, mine in (("GG.FEED_INDEX", FEED_INDEX),
                           ("GG.FEED_INDEX_DEMAND", FEED_INDEX_DEMAND),
                           ("GG.FEED_INDEX_LEAD", FEED_INDEX_LEAD),
                           ("GG.FEED_INDEX_RANK", FEED_INDEX_RANK)):
        m = re.search(re.escape(lua_name) + r"\s*=\s*(\d+)", lua)
        if not m:
            out.append("the Lua never declares %s, so that feed record is unreachable"
                       % lua_name)
        elif int(m.group(1)) != mine:
            out.append("%s is %s in the Lua and %d here - one of them resolves to no "
                       "record and draws nothing" % (lua_name, m.group(1), mine))

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
    # The fallback every other culture reads, under the None the generator gives it.
    gen = re.search(r'^GG\.GENERIC = \{\s*tag\s*=\s*"([_a-z]*)"\s*,\s*feed\s*=\s*(\d+)'
                    r'\s*\}', lua, re.M)
    if gen:
        got[None] = (gen.group(1), int(gen.group(2)))
    return got


UI_LUA = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua"
MCT_LUA = "Modding Files/pack/script/mct/settings/derpy_great_guilds.lua"
MCT_BEGIN = "-- BEGIN GENERATED: GGUI.MCT_NAMES"
MCT_END = "-- END GENERATED: GGUI.MCT_NAMES"


def mct_names_block():
    """GGUI.MCT_NAMES as Lua: every flavour's six guild names, keyed by tag."""
    lines = ["GGUI.MCT_NAMES = {"]
    for tag, F in FLAVOURS.items():
        lines.append('    ["%s"] = {' % tag)
        for g in GUILDS:
            lines.append('        %s = "%s",' % (g, F["guilds"][g].replace('"', '\\"')))
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines)


def with_mct_names(src):
    """The panel Lua with the generated block rewritten, or None if the markers are gone.
    Line endings are the file's own - the panel is CRLF."""
    nl = "\r\n" if "\r\n" in src else "\n"
    a, b = src.find(MCT_BEGIN), src.find(MCT_END)
    if a < 0 or b < a:
        return None
    body = mct_names_block().replace("\n", nl)
    return src[:a + len(MCT_BEGIN)] + nl + body + nl + src[b:]


def write_mct_names():
    src = io.open(UI_LUA, encoding="utf-8", newline="").read()
    new = with_mct_names(src)
    assert new is not None, "the GGUI.MCT_NAMES markers are missing from " + UI_LUA
    if new != src:
        io.open(UI_LUA, "w", encoding="utf-8", newline="").write(new)
    return UI_LUA


def check_mct_names():
    """The campaign renames and the frontend labels must be this generator's names.

    GGUI.MCT_NAMES is what an Empire or Dwarf player reads on the MCT page; stale, it
    names guilds the panel no longer calls by that name. The settings file carries the
    generic flavour's role names, because the frontend has no race - and those twelve
    labels are typed there by hand, so they are compared here.
    """
    out = []
    src = io.open(UI_LUA, encoding="utf-8", newline="").read()
    new = with_mct_names(src)
    if new is None:
        out.append("the GGUI.MCT_NAMES markers are missing from " + UI_LUA)
    elif new != src:
        out.append("GGUI.MCT_NAMES in %s is stale - run gen_great_guilds.py --write"
                   % UI_LUA)
    mct = io.open(MCT_LUA, encoding="utf-8").read()
    for g in GUILDS:
        want = FLAVOURS["_gen"]["guilds"][g]
        for key in ("rate_" + g, "cap_" + g):
            m = re.search(r'\{"%s",\s*"([^"]*)"' % key, mct)
            if not m or m.group(1) != want:
                out.append("%s labels %s %r in the frontend, not the role name %r"
                           % (MCT_LUA, key, m and m.group(1), want))
    return out


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
    for c in sorted(set(want) | set(got), key=str):
        if got.get(c) != want.get(c):
            out.append("GG.FLAVOURED gives %s %r and the generator mints %r - that race "
                       "reads raw keys or messages that draw nothing"
                       % (c, got.get(c), want.get(c)))
    return out


def check_hire_units():
    """Every culture and hire-unit key in the model Lua must exist in vanilla.

    GG.CULTURES IS NO LONGER A GATE. It was three hardcoded keys and it silently excluded
    every culture a mod adds - Old World, IEE, the Hobgoblin Khanates, Araby, Tilea and
    the rest - so it is now discovered from the campaign at runtime and there is nothing
    here to check. What remains checkable is GG.FLAVOURED, the cultures this mod ships
    names and a hire unit for, and GG.HIRE_UNIT_BY_CULTURE, which decides what one service
    grants. Both are plain strings the engine never validates: a typo means favour spent
    on a unit that never arrives. Read back out of the shipped Lua rather than from
    constants here, because the Lua is what the game loads.

    Also asserts the two agree in the direction that matters: a unit mapped for a culture
    this mod does not claim to flavour is dead weight, and a flavoured culture with no
    unit now REFUSES the hire service rather than falling back, so the mismatch is a
    missing service rather than a wrong one.
    """
    out = []
    lua_path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    try:
        lua = io.open(lua_path, encoding="utf-8").read()
    except IOError as exc:
        return ["cannot read %s: %s" % (lua_path, exc)]

    cult = re.search(r"^GG\.FLAVOURED = \{(.*?)\n\}", lua, re.S | re.M)
    hire = re.search(r"^GG\.HIRE_UNIT_BY_CULTURE = \{(.*?)\n\}", lua, re.S | re.M)
    if not cult or not hire:
        return ["GG.FLAVOURED or GG.HIRE_UNIT_BY_CULTURE is not declared in " + lua_path]
    # THE GATE IS GONE ON PURPOSE, and must stay gone. A literal GG.CULTURES table would
    # mean the hardcoded three-culture list had been reinstated, which is invisible in
    # play: the excluded cultures do not error, they just never accrue anything.
    if re.search(r"^GG\.CULTURES = \{\s*\[", lua, re.M):
        return ["GG.CULTURES is a literal table again - culture coverage must be "
                "discovered from the campaign, or every culture a mod adds is silently "
                "excluded from the guilds forever"]

    # GG.CHD_CULTURE is used as a key in GG.CULTURES, so resolve it first.
    chd = re.search(r'^GG\.CHD_CULTURE = "([a-z0-9_]+)"', lua, re.M)
    cultures = set(re.findall(r'\["([a-z0-9_]+)"\]', cult.group(1)))
    if "GG.CHD_CULTURE" in cult.group(1) or "[GG.CHD_CULTURE]" in cult.group(1):
        if chd:
            cultures.add(chd.group(1))
    pairs = dict(re.findall(r'\["([a-z0-9_]+)"\]\s*=\s*"([a-z0-9_]+)"',
                            hire.group(1)))

    try:
        sys.path.insert(0, "tools")
        from read_vanilla_cache import load
        crows, _ = load("cultures")
        urows, _ = load("main_units")
    except Exception as exc:                                   # noqa: BLE001
        return ["cannot read the vanilla tables check_hire_units compares: %s" % exc]
    known_cultures = {r["key"] for r in crows if r.get("key")}
    known_units = {r["unit"] for r in urows if r.get("unit")}

    for c in sorted(cultures):
        if c not in known_cultures:
            out.append("GG.FLAVOURED names %r, which is not a vanilla culture key - its "
                       "guild names and hire unit would never resolve" % c)
        if c not in pairs:
            out.append("GG.FLAVOURED claims %r but GG.HIRE_UNIT_BY_CULTURE has no unit "
                       "for it - that culture is refused the hire service it is supposed "
                       "to have flavour for" % c)
    for c, u in sorted(pairs.items()):
        if c not in known_cultures:
            out.append("GG.HIRE_UNIT_BY_CULTURE is keyed on %r, which is not a vanilla "
                       "culture key" % c)
        if u not in known_units:
            out.append("GG.HIRE_UNIT_BY_CULTURE grants %r to %s, and no such unit exists "
                       "in main_units - the favour is spent and nothing arrives" % (u, c))
        if c not in cultures:
            out.append("GG.HIRE_UNIT_BY_CULTURE covers %r but GG.FLAVOURED does not - "
                       "either the culture lost its flavour or the unit is dead weight" % c)
    if not cultures:
        out.append("GG.FLAVOURED is empty - no culture has guild names or a hire unit")
    return out


def check_building_theme():
    """The building theme table must be matchable, unambiguous and real.

    Four ways it goes wrong, none of which raises anything in play:

    1. A TOKEN CONTAINING LUA PATTERN MAGIC. GG.guild_of_chain matches with string.find as
       a PATTERN, because the plain flag is banned - one such call corrupts the string
       subsystem process-wide for the whole game, CA's own lookups included, with no error
       and no recovery short of a restart. So a token holding `-` or `.` or `(` silently
       matches the wrong chains, or errors inside a pcall that swallows it.
    2. A TOKEN CLAIMED BY TWO GUILDS. Longest-match-wins resolves collisions BETWEEN
       different tokens; the same token in two lists is decided by nothing but list order,
       which is not a decision anybody made.
    3. A GUILD THAT IS NOT A GUILD. Guild keys are unvalidated strings like every other key
       here: GG.capped_grant looks the guild up in the faction's track table, finds nothing,
       and returns without error. That building would pay precisely nothing, forever.
    4. A TOKEN THAT MATCHES NO CHAIN CA SHIPS. Not fatal - the point of the table is that a
       mod's chains work without being listed, so a token can legitimately be aiming at
       something not in vanilla - but a token matching nothing is far more often a typo, and
       `scavanger` is spelled that way in CA's data on purpose. Reported, not refused.

    Also asserts the table actually covers the culture being played: every one of the Chaos
    Dwarf chains has to land somewhere, because those are the buildings that will be built.
    """
    out = []
    lua_path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    try:
        lua = io.open(lua_path, encoding="utf-8").read()
    except IOError as exc:
        return ["cannot read %s: %s" % (lua_path, exc)]

    block = re.search(r"^GG\.BUILDING_THEME = \{(.*?)\n\}", lua, re.S | re.M)
    if not block:
        return ["GG.BUILDING_THEME is not declared in " + lua_path]

    # One entry per guild: {"guild", {"tok", "tok", ...}}
    entries = re.findall(r'\{"([a-z_]+)",\s*\{(.*?)\}\}', block.group(1), re.S)
    if not entries:
        return ["GG.BUILDING_THEME declares no guild entries - every building would fall "
                "back to the Overseers, which is the behaviour this table replaced"]

    theme, owner = {}, {}
    MAGIC = set("^$()%.[]*+-?")
    for guild, toks in entries:
        if guild not in GUILDS:
            out.append("GG.BUILDING_THEME names the guild %r, which is not one of the six "
                       "- GG.capped_grant would find no track for it and the building "
                       "would pay nothing at all, silently" % guild)
        words = re.findall(r'"([^"]*)"', toks)
        theme[guild] = words
        for w in words:
            if not w:
                out.append("GG.BUILDING_THEME has an empty token under %r, which matches "
                           "every chain in the game" % guild)
                continue
            bad = sorted(MAGIC & set(w))
            if bad:
                out.append("GG.BUILDING_THEME token %r (%s) contains Lua pattern magic "
                           "%s - it is matched with string.find as a pattern, because the "
                           "plain flag corrupts the string subsystem process-wide, so this "
                           "matches the wrong chains or errors inside a pcall"
                           % (w, guild, bad))
            if w != w.lower():
                out.append("GG.BUILDING_THEME token %r (%s) is not lowercase - chain keys "
                           "are, so it can never match" % (w, guild))
            if w in owner and owner[w] != guild:
                out.append("GG.BUILDING_THEME token %r is claimed by both %s and %s - "
                           "longest-match-wins cannot separate two identical tokens, so "
                           "list order decides it and nobody chose that"
                           % (w, owner[w], guild))
            owner[w] = guild

    for g in GUILDS:
        if g not in theme:
            out.append("GG.BUILDING_THEME has no entry for %s, so no building in the game "
                       "can ever pay it" % g)

    # ------------------------------------------------- against CA's real chain keys ----
    try:
        sys.path.insert(0, "tools")
        from read_vanilla_cache import load
        rows, _f = load("building_levels")
    except Exception as exc:                                   # noqa: BLE001
        return out + ["cannot read building_levels to check the theme table: %s" % exc]
    # LOWERCASED, because GG.guild_of_chain lowercases before matching - some of
    # CA's chain keys carry uppercase segments (wh2_main_EMPIRE_academy). Measuring
    # a different string from the one the game matches makes this gate a guess.
    chains = sorted({r["chain"].lower() for r in rows if r.get("chain")})
    if not chains:
        return out + ["building_levels holds no chain keys"]

    ranks = {g: i for i, (g, _t) in enumerate(entries)}

    def guild_of(chain):
        best, best_len, best_rank = None, 0, len(entries) + 1
        for guild, words in theme.items():
            for w in words:
                if w and w in chain:
                    if len(w) > best_len or (len(w) == best_len
                                             and ranks.get(guild, 99) < best_rank):
                        best, best_len, best_rank = guild, len(w), ranks.get(guild, 99)
        return best

    for w in sorted(owner):
        if w and not any(w in c for c in chains):
            out.append("GG.BUILDING_THEME token %r (%s) matches none of CA's %d building "
                       "chains - a mod's chain could still carry it, but a typo looks "
                       "exactly like this" % (w, owner[w], len(chains)))

    # THE CULTURE BEING PLAYED HAS TO BE COVERED. A table that themes the rest of the world
    # and leaves the Chaos Dwarf chains on the default has changed nothing for this mod.
    chd = [c for c in chains if "_chd_" in c]
    missed = [c for c in chd if guild_of(c) is None]
    if chd and len(missed) > max(2, len(chd) // 10):
        out.append("%d of %d Chaos Dwarf chains match no token (%s...) - the table has to "
                   "cover the culture the content is for, or every building a Chaos Dwarf "
                   "builds still pays the Overseers"
                   % (len(missed), len(chd), ", ".join(missed[:3])))
    return out


# ------------------------------------------------ the line on every building card ----
# A finished building pays its guild in SCRIPT (GG.on_building), not through an effect, so
# its card said nothing and a player could not see that the forge they built paid the
# smiths (reported from play, 2026-09-24). Every level of every chain a covered race can
# build now carries one display-only effect naming the guild it pays. That is CA's own
# way to put a line of text on a building: wh2_main_effect_building_major_settlement_
# only_dummy has no bonus-value junction, value 1, and building_to_building_own, whose
# scope suffix is empty.
#
# NO NUMBER. The amount is an MCT rate times a building level CA does not document the
# base of, cut by a per-turn limit. The Guilds tab's "Reputation this turn" line shows
# the real figure.
#
# LEFT OFF: ruin levels, which nobody builds; and chains more than one covered race can
# build - 48 landmark variants, which would print one line per race, each naming a
# different guild. Those still pay, and so do a mod's chains; they just do not say so.
BUILT_EFFECT = "derpy_gg_built_%s%s"      # guild, flavour tag
BUILT_SCOPE = "building_to_building_own"
MODEL_LUA = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
LUA_EXE = r"C:\Program Files (x86)\Lua\5.1\lua.exe"


def building_theme():
    """[(guild, [token, ...]), ...] exactly as GG.BUILDING_THEME declares it, in order."""
    lua = io.open(MODEL_LUA, encoding="utf-8").read()
    block = re.search(r"^GG\.BUILDING_THEME = \{(.*?)\n\}", lua, re.S | re.M)
    if not block:
        return []
    return [(g, re.findall(r'"([^"]*)"', toks))
            for g, toks in re.findall(r'\{"([a-z_]+)",\s*\{(.*?)\}\}', block.group(1), re.S)]


def guild_of_chain(chain, theme):
    """GG.guild_of_chain: the longest token wins, the first-listed guild on a tie, None
    when nothing matches. check_built_effects runs the Lua itself to prove they agree."""
    chain = chain.lower()
    best, best_len = None, 0
    for guild, words in theme:
        for w in words:
            if w and w in chain and len(w) > best_len:
                best, best_len = guild, len(w)
    return best


_LIVE = {}


def live_rows(table):
    """CA's rows for `table` out of the INSTALLED db.pack - not .skilltree_cache.

    The building-card rows name CA's buildings, and a row naming a building the game no
    longer has is a load-time reject that drops the whole pack. The cache is whatever patch
    it was dumped under: patch 9.0 removed wh_main_special_great_temple_of_ulric, which the
    8.x cache still listed, and the 2026-09-24 build shipped a row for it. Reading the
    installed game means a rebuild after a patch follows that patch.
    """
    if table not in _LIVE:
        sys.path.insert(0, "tools")
        from read_vanilla_db import load, DB_PACK
        _LIVE[table] = [r for _p, _v, rows in load(DB_PACK, table + "_tables") for r in rows]
    return _LIVE[table]


def covered_chains():
    """{chain: flavour tag} for every chain exactly one covered race can build.

    Read off CA's availability sets, the same route tools/gen_ghorth_settlement_tiers.py
    uses to scope "every chain a Chaos Dwarf region can hold" - it picks up the landmarks,
    ports and gates that carry no race word in their key.
    """
    tag_of = {F["culture"]: t for t, F in FLAVOURS.items() if F.get("culture")}
    sub_culture = {r["subculture"]: r["culture"] for r in live_rows("cultures_subcultures")}
    fac_culture = {r["key"]: sub_culture.get(r["subculture"], "")
                   for r in live_rows("factions")}
    set_tags = {}
    for r in live_rows("building_chain_availabilities"):
        if r["campaign"]:
            continue                                  # the prologue's own sets
        tag = tag_of.get(r["culture"] or fac_culture.get(r["faction"], ""))
        if tag is not None:
            set_tags.setdefault(r["set_id"], set()).add(tag)
    chain_tags = {}
    for r in live_rows("building_chain_availability_sets"):
        chain_tags.setdefault(r["building_chain"], set()).update(set_tags.get(r["id"], ()))
    return {c: next(iter(t)) for c, t in chain_tags.items() if len(t) == 1}


def built_tables():
    """The effects rows, their building junction rows and their loc."""
    theme = building_theme()
    icon_of = {r["effect"]: r["icon"] for r in live_rows("effects")}
    effects, junction, loc = [], [], []
    for tag, F in FLAVOURS.items():
        if not F.get("culture"):
            continue                                  # the generic flavour has no buildings
        for g in GUILDS:
            key = BUILT_EFFECT % (g, tag)
            # The icon of the vanilla effect this guild's rank rewards already use.
            icon = icon_of[RANK_EFFECTS[g][0]]
            effects.append({"effect": key, "icon": icon, "priority": "1",
                            "icon_negative": icon, "category": "campaign",
                            "is_positive_value_good": "true"})
            loc.append({"key": "effects_description_" + key,
                        "text": "[[col:yellow]]Completing this earns reputation with the "
                                "%s[[/col]]" % short_name(g, tag),
                        "tooltip": "false"})
    owner = covered_chains()
    for r in sorted(live_rows("building_levels"), key=lambda r: r["level_name"]):
        tag = owner.get(r["chain"])
        if tag is None or r["level_name"].endswith("_ruin") or not r["visible_in_ui"]:
            continue
        # What GG.on_building pays when no word matches.
        g = guild_of_chain(r["chain"], theme) or "overseers"
        junction.append({"building": r["level_name"], "effect": BUILT_EFFECT % (g, tag),
                         "effect_scope": BUILT_SCOPE, "value": "1.0000",
                         "value_damaged": "1.0000", "value_ruined": "0.0000",
                         "context_requirement": ""})
    return {"effects": effects, "building_effects_junction": junction, "loc": loc}


def _lua_guilds_of(chains):
    """{chain: guild or None} from the SHIPPED GG.guild_of_chain, run under lua.exe."""
    import subprocess
    import tempfile
    lua = io.open(MODEL_LUA, encoding="utf-8").read()
    theme = re.search(r"^GG\.BUILDING_THEME = \{.*?\n\}", lua, re.S | re.M)
    fn = re.search(r"^function GG\.guild_of_chain\(chain\)\n.*?\nend\n", lua, re.S | re.M)
    if not theme or not fn:
        raise RuntimeError("GG.BUILDING_THEME or GG.guild_of_chain not found in " + MODEL_LUA)
    prog = ("GG = {}\n" + theme.group(0) + "\n" + fn.group(0)
            + "for c in io.lines() do io.write((GG.guild_of_chain(c) or '-') .. '\\n') end\n")
    fd, path = tempfile.mkstemp(suffix=".lua")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(prog)
        res = subprocess.run([LUA_EXE, path], input="\n".join(chains) + "\n",
                             capture_output=True, text=True, check=True)
    finally:
        os.remove(path)
    got = res.stdout.split()
    if len(got) != len(chains):
        raise RuntimeError("lua.exe answered %d of %d chains" % (len(got), len(chains)))
    return {c: (None if g == "-" else g) for c, g in zip(chains, got)}


def check_built_effects():
    """The building-card line must promise the guild the building actually pays.

    A card that names the smiths on a building the script pays to the Overseers is worse
    than no line at all, and nothing in the game would ever report it.
    """
    out = []
    try:
        t = built_tables()
    except Exception as exc:                                   # noqa: BLE001
        return ["cannot build the building-card rows: %r" % (exc,)]
    chain_of = {r["level_name"]: r["chain"] for r in live_rows("building_levels")}
    chains = sorted({chain_of[r["building"]] for r in t["building_effects_junction"]})
    try:
        lua = _lua_guilds_of(chains)
    except Exception as exc:                                   # noqa: BLE001
        return ["cannot run the shipped GG.guild_of_chain: %r" % (exc,)]
    theme = building_theme()
    for c in chains:
        if guild_of_chain(c, theme) != lua[c]:
            out.append("chain %s: the card would name %s and the script pays %s"
                       % (c, guild_of_chain(c, theme), lua[c]))
    for r in t["building_effects_junction"]:
        g = lua[chain_of[r["building"]]] or "overseers"
        if not r["effect"].startswith(BUILT_EFFECT % (g, "")):
            out.append("%s carries %s but pays %s" % (r["building"], r["effect"], g))
    keys = set(r["effect"] for r in t["effects"])
    described = set(r["key"][len("effects_description_"):] for r in t["loc"])
    for r in t["building_effects_junction"]:
        if r["effect"] not in keys:
            out.append("%s names an effect no row defines: %s" % (r["building"], r["effect"]))
    for k in sorted(keys - described):
        out.append("effect %s has no effects_description_ loc, so the card draws an "
                   "empty line" % k)
    pairs = [(r["building"], r["effect"]) for r in t["building_effects_junction"]]
    if len(pairs) != len(set(pairs)):
        out.append("duplicate building_effects_junction rows - the game drops the table")
    # EVERY RACE GETS ITS BUILDINGS. A culture key that stopped matching CA's sets would
    # otherwise leave that race with no line on any card and every check still green.
    tag_of_key = {BUILT_EFFECT % (g, tag): tag for tag in FLAVOURS for g in GUILDS}
    per_tag = {}
    for r in t["building_effects_junction"]:
        tag = tag_of_key.get(r["effect"])
        per_tag[tag] = per_tag.get(tag, 0) + 1
    for tag, F in FLAVOURS.items():
        if F.get("culture") and per_tag.get(tag, 0) < 100:
            out.append("flavour %r puts the line on only %d building levels - its culture "
                       "%s no longer matches CA's availability sets"
                       % (tag, per_tag.get(tag, 0), F["culture"]))
    return out


def check_live_references():
    """Every reference cell this pack ships must resolve against the INSTALLED game.

    A row naming a key the game does not have is a load-time reject that drops the whole
    pack. Patch 9.0 removed wh_main_special_great_temple_of_ulric, and the 2026-09-24 build
    shipped a building-card row for it: every version check was green, because a version
    says nothing about whether the keys inside a row still exist. This is RPFM's
    InvalidReference diagnostic done offline - the reference each column makes is read out
    of RPFM's schema, the values out of CA's db.pack and this pack's own rows.

    A referenced table with no file in db.pack (effect_bundle_targets, mission_types,
    message_event_layout_types) is Assembly Kit only and is not checked at load, so it is
    skipped rather than reported.
    """
    sys.path.insert(0, "tools")
    try:
        from read_vanilla_db import load, DB_PACK, SCHEMA
        schema = io.open(SCHEMA, encoding="utf-8").read()
    except Exception as exc:                                   # noqa: BLE001
        return ["cannot read the schema or db.pack for the reference check: %r" % (exc,)]
    built = build()
    own = {TSV_META[t][0][:-len("_tables")]: rows for t, rows in built.items() if t != "loc"}
    live = {}
    out = []
    for t, rows in sorted(built.items()):
        if t == "loc" or not rows:
            continue
        name, ver = TSV_META[t]
        i = schema.find('"%s": [' % name)
        blk = schema[i:schema.find('_tables": [', i + len(name) + 5)]
        m = re.search(r"version: %d,\s*fields: \[(.*?)\n {16}\]," % ver, blk, re.S)
        if i < 0 or not m:
            out.append("%s v%d is not in RPFM's schema, so its references cannot be "
                       "checked" % (name, ver))
            continue
        for f in re.split(r"\n {20}\(\n", m.group(1)):
            col = re.search(r'name: "([^"]+)"', f)
            ref = re.search(r'is_reference: Some\(\("([^"]+)", "([^"]+)"\)\)', f)
            if not col or not ref:
                continue
            col, (rt, rc) = col.group(1), ref.groups()
            if (rt, rc) not in live:
                files = load(DB_PACK, rt + "_tables")
                live[(rt, rc)] = None if not files else (
                    {str(r[rc]) for _p, _v, rs in files for r in rs}
                    | {r.get(rc, "") for r in own.get(rt, [])})
            ok = live[(rt, rc)]
            if ok is None:
                continue                                       # Assembly Kit only
            miss = sorted({r[col] for r in rows if r.get(col) and r[col] not in ok})
            if miss:
                out.append("%s.%s names %d key(s) the installed game has no %s.%s for "
                           "(%s) - a load-time reject that drops the whole pack"
                           % (t, col, len(miss), rt, rc, ", ".join(miss[:3])))
    return out


def check_player_scope():
    """Coverage must be read off the player, and it must not be a list.

    BOTH WAYS OF BREAKING THIS ARE INVISIBLE IN PLAY, which is the only reason a text
    check on the shipped Lua earns its keep. Narrow the scope back to a hardcoded set and
    the excluded cultures do not error - their factions simply never accrue anything,
    never appear in a table and never lead, for the whole campaign, with no log line.
    Widen it to everybody and the Empire and the Lizardmen quietly run their own copies
    of six Chaos Dwarf guilds, which is exactly what a player screenshotted on
    2026-09-12. Neither shows up in a crash, a log or a load-time report.

    Four things are checked, and they are the four that would have caught the two wrong
    builds this replaced:

    1. GG.covered consults GG.player_cultures. Without that call the scope is whatever
       else the function happens to test, and both wrong builds passed every other check
       in this file.
    2. GG.covered's answer is membership of that set, not merely that a culture could be
       read. `return c ~= false` is the open build, and it is a one-line edit away.
    3. GG.player_cultures reads cm:get_human_factions, so the culture comes off the
       faction at the keyboard rather than out of a table here.
    4. An empty answer is not cached. The local faction is not readable while a campaign
       is loading, and caching nothing there leaves the mod inert for the whole session -
       which is a bug with no symptom other than "nothing ever happens".
    """
    out = []
    lua_path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    try:
        lua = io.open(lua_path, encoding="utf-8").read()
    except IOError as exc:
        return ["cannot read %s: %s" % (lua_path, exc)]

    def body(name):
        """The source of one function, comments stripped, or None."""
        at = lua.find("\nfunction " + name + "(")
        if at == -1:
            return None
        end = lua.find("\nend", at)
        if end == -1:
            return None
        lines = []
        for line in lua[at:end].split("\n"):
            bare = line.strip()
            if bare.startswith("--"):
                continue
            lines.append(line)
        return "\n".join(lines)

    cov = body("GG.covered")
    if cov is None:
        out.append("GG.covered is not declared in " + lua_path)
    else:
        if "GG.player_cultures()" not in cov:
            out.append("GG.covered does not consult GG.player_cultures - the scope is no "
                       "longer the player's culture, and whichever way it moved is "
                       "silent: an excluded culture never earns and never errors, and an "
                       "included one runs its own copy of six Chaos Dwarf guilds")
        if "mine[c] == true" not in cov:
            out.append("GG.covered no longer answers with membership of the player's "
                       "cultures - a readable culture is not the same as a culture in "
                       "the race, and that difference is the whole gate")

    pc = body("GG.player_cultures")
    if pc is None:
        out.append("GG.player_cultures is not declared in " + lua_path)
    else:
        if "cm:get_human_factions()" not in pc:
            out.append("GG.player_cultures does not read cm:get_human_factions - the "
                       "culture has to come off the faction at the keyboard, or this "
                       "file is naming cultures again and no mod-added one can ever play")
        if "if not any then return {} end" not in pc:
            out.append("GG.player_cultures may cache an empty answer - the local faction "
                       "is not readable while a campaign loads, and caching nothing "
                       "there leaves the whole mod inert for the session with no error")
    return out


def check_titles():
    """No event-feed title may name a guild without its article.

    short_name() strips the leading "The". That is a headline convention and it reads
    fine for the five plural guild names - and wrong for the Khanate, which is singular,
    so every title built that way was a visible defect for one guild in six. It shipped
    in twelve leadership titles and a player screenshotted one on 2026-09-12.

    The test is on the SHIPPED STRING rather than on which helper produced it, so a new
    title written by hand with a bare guild name fails here too.
    """
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


def check_ledger_sources():
    """Every source the ledger can record must have its src_ loc row, for every flavour.

    GGUI.earned_line reads GGUI.loc("src_" .. source), a key built at runtime, so
    check_ui_loc_keys cannot see it - and a missing one prints "src_buildings" on the
    panel, on the one line that exists to explain what a building paid.
    """
    path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    lua = io.open(path, encoding="utf-8").read()
    m = re.search(r"^GG\.LEDGER_SOURCES = \{(.*?)\}", lua, re.S | re.M)
    if not m:
        return ["GG.LEDGER_SOURCES is not declared in " + path]
    sources = re.findall(r'"([a-z]+)"', m.group(1))
    if not sources:
        return ["GG.LEDGER_SOURCES lists no sources"]
    have = set(r["key"] for r in build()["loc"])
    return ["the ledger source %r has no derpy_gg_src_%s%s loc row, so the panel prints "
            "the bare key" % (src, src, tag)
            for src in sources for tag in FLAVOURS
            if "derpy_gg_src_" + src + tag not in have]


def check_ui_loc_keys():
    """Every GGUI.loc("x") in the shipped Lua must have a row in build()["loc"].

    A missing loc key is not an error in this engine - it draws an EMPTY tooltip and
    says nothing, which is the one failure shape a player cannot report usefully. The
    panel reads 67 of these by literal name and nothing checked them. Prefix forms
    (GGUI.loc("guild_name_" .. guild)) are skipped: the key is built at runtime and its
    halves are covered by check_presets.
    """
    have = set(r["key"] for r in build()["loc"])
    bad = []
    for stem in ("zzz_derpy_guilds", "zzz_derpy_guilds_ui", "zzz_derpy_guilds_ai"):
        path = "Modding Files/pack/script/campaign/mod/" + stem + ".lua"
        try:
            src = io.open(path, encoding="utf-8").read()
        except IOError:
            continue
        # The negative lookahead drops the concatenated prefix forms. The whitespace
        # belongs INSIDE the lookahead: with `\s*` before it the star matches zero
        # characters, the lookahead then reads the space rather than the dots, and every
        # prefix form is reported as missing.
        # GGUI.loc appends the local player's flavour tag, so every literal must ship
        # under every tag.
        for m in re.finditer(r'GGUI\.loc\(\s*"([a-z0-9_]+)"(?!\s*\.\.)', src):
            for tag in FLAVOURS:
                if "derpy_gg_" + m.group(1) + tag not in have:
                    bad.append("%s reads GGUI.loc(\"%s\") and no loc row defines it for "
                               "flavour %r" % (stem, m.group(1), tag))
        # GGUI.target_hint returns a BARE KEY NAME that GGUI.loc is then called on, so
        # the literal never appears inside a GGUI.loc(...) call. Checked by name.
        if stem == "zzz_derpy_guilds_ui":
            fn = re.search(r"function GGUI\.target_hint\(s\)(.*?)\nend", src, re.S)
            if fn:
                for k in re.findall(r'return\s+"([a-z0-9_]+)"', fn.group(1)):
                    for tag in FLAVOURS:
                        if "derpy_gg_" + k + tag not in have:
                            bad.append("GGUI.target_hint returns \"%s\" and no loc row "
                                       "defines it for flavour %r" % (k, tag))
    return bad


def check_feed_images():
    """Every event picture must be one vanilla's own feed rows use.

    The `image` column is a path fragment under ui/eventpics/, not a foreign key, so an
    invented value is accepted by the DB and draws a BLACK RECTANGLE on the event panel
    instead of erroring - which is how "chd/generic" shipped and survived every gate
    here until a player saw it. Chaos Dwarfs are the one culture with no `generic`.

    Vanilla's own table is the reference rather than the .png files in ui2.pack: it is
    cached and needs no game install to read, and a value CA uses is proof the engine
    resolves it, which the file's mere existence is not.
    """
    out = []
    try:
        sys.path.insert(0, "tools")
        from read_vanilla_cache import load
        rows, _ = load("event_feed_message_events")
    except Exception as exc:                                   # noqa: BLE001
        return ["cannot read vanilla event_feed_message_events to check pictures: %s"
                % exc]
    known = set()
    for r in rows:
        if r.get("image"):
            known.add(r["image"])
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


def check_presets():
    """The model Lua, the MCT file and each other must agree about difficulty.

    The harness already drives GG.PRESETS against the real Lua, so the ordering, the types
    and the cap_daemonsmiths rule are covered there. What NO Lua test can reach is the MCT
    settings file: it runs in MCT's own environment, cannot see GG, and is never loaded by
    the harness. Three ways that pair goes wrong, all of them silent:

      * a preset in GG.PRESETS with no dropdown value is unreachable - the player can
        never pick it and nothing anywhere says the difficulty exists;
      * a dropdown value with no preset behind it resolves to the shipped defaults, so
        picking "Hard" plays exactly like Default with a different word on the button;
      * a numeric option missing from the MCT file's PRESET_OWNED list stays EDITABLE
        under a preset that overrides it, so the player sets a number, the preset wins,
        and nothing on screen says which one is live.
    """
    out = []
    lua_path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    mct_path = "Modding Files/pack/script/mct/settings/derpy_great_guilds.lua"
    try:
        lua = io.open(lua_path, encoding="utf-8").read()
        mct = io.open(mct_path, encoding="utf-8").read()
    except IOError as exc:
        return ["cannot read the files check_presets compares: %s" % exc]

    block = re.search(r"^GG\.PRESETS = \{(.*?)\n\}", lua, re.S | re.M)
    if not block:
        return ["GG.PRESETS is not declared in " + lua_path]
    # One nesting level only, which is all this table has: `name = { ... },`
    presets = set(re.findall(r"(?m)^    ([a-z_]+) = \{", block.group(1)))

    drops = set(re.findall(r'add_dropdown_value\("([a-z_]+)"', mct))
    custom = "custom"
    if custom not in drops:
        out.append("the MCT dropdown offers no %r value, so the player can never reach "
                   "their own sliders" % custom)
    for name in sorted(presets - drops):
        out.append("GG.PRESETS has %r and the MCT dropdown does not offer it - a "
                   "difficulty nobody can pick" % name)
    for name in sorted(drops - presets - {custom}):
        out.append("the MCT dropdown offers %r and GG.PRESETS has no such table - picking "
                   "it plays exactly like Default, silently" % name)

    # Every NUMERIC tunable must be in the MCT file's lock list, and nothing else may be.
    order = re.search(r"^GG\.TUNE_ORDER = \{(.*?)\n\}", lua, re.S | re.M)
    defs = re.search(r"^GG\.TUNE_DEFAULTS = \{(.*?)\n\}", lua, re.S | re.M)
    if not order or not defs:
        out.append("GG.TUNE_ORDER or GG.TUNE_DEFAULTS is not declared in " + lua_path)
        return out
    keys = re.findall(r'"([a-z_0-9]+)"', order.group(1))
    bools = set(re.findall(r"([a-z_0-9]+)\s*=\s*(?:true|false)", defs.group(1)))
    numeric = [k for k in keys if k not in bools]

    owned = re.search(r"^local PRESET_OWNED = \{(.*?)\n\}", mct, re.S | re.M)
    if not owned:
        out.append("the MCT file declares no PRESET_OWNED list, so a preset greys nothing")
        return out
    listed = set(re.findall(r'"([a-z_0-9]+)"', owned.group(1)))
    for k in sorted(set(numeric) - listed):
        out.append("%s is a numeric setting and is not in the MCT file's PRESET_OWNED "
                   "list - it stays editable under a preset that overrides it" % k)
    for k in sorted(listed - set(numeric)):
        out.append("the MCT file's PRESET_OWNED list names %s, which is not a numeric "
                   "setting - a preset must never own a switch" % k)

    # And the switches must NOT be locked, which is the whole point of the split.
    for k in sorted(bools & listed):
        out.append("%s is a switch and PRESET_OWNED greys it - the four Systems switches "
                   "are the player's on every difficulty" % k)
    return out


def check_monopoly_mirror():
    """The Lua must lock the same services this file says are locked.

    The gate is enforced in GG.can_buy and advertised in the loc written here. Declared
    on one side only, it is either a promise the game does not keep or a lock the player
    is never told about - and neither shows up as an error anywhere.
    """
    out = []
    path = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua"
    try:
        lua = io.open(path, encoding="utf-8").read()
    except IOError:
        return ["cannot read %s to check the monopoly mirror" % path]
    body = re.search(r"GG\.SERVICES\s*=\s*\{(.*?)\n\}", lua, re.S)
    if not body:
        return ["GG.SERVICES is not declared in " + path]
    locked = set()
    for line in body.group(1).split("\n"):
        m = re.search(r'key\s*=\s*"([^"]+)"', line)
        if m and re.search(r"lead\s*=\s*true", line):
            locked.add(m.group(1))
    for k in sorted(LEAD_SERVICES - locked):
        out.append("%s is monopoly-locked here and carries no lead=true in the Lua, "
                   "so the loc promises a gate nothing enforces" % k)
    for k in sorted(locked - LEAD_SERVICES):
        out.append("%s carries lead=true in the Lua and is not in LEAD_SERVICES, so it "
                   "is locked with nothing on any card saying so" % k)
    return out


def check_favour_floor():
    out = []
    for s in SERVICES:
        cheapest = int(s["cost"] * (100 + FAVOUR_MIN_MOD) / 100)
        if cheapest < 1:
            out.append("%s costs %d favour, which the %d%% loyalty discount floors to "
                       "%d - a free service" % (s["key"], s["cost"], FAVOUR_MIN_MOD,
                                                cheapest))
    return out


def check_extra_effects():
    """The second-effect table, before anything tries to build from it.

    Order matters: extra_sentence() raises a KeyError inside build() when a blurb is
    missing, so these run ahead of every check that needs build() - a crash is a worse
    diagnostic than a sentence. And the guild key is checked BEFORE its blurb, or a
    typo'd guild is reported as a missing blurb it was never going to need.
    """
    out = []
    for g in RANK_EFFECTS_EXTRA:
        if g not in GUILDS:
            out.append("RANK_EFFECTS_EXTRA names %r, which is not a guild" % g)
            continue
        if g not in EFFECT_BLURB_EXTRA:
            out.append("%s has a second rank effect and no blurb for it - its number "
                       "would draw in Faction Effects with nothing to explain it" % g)
        ladder = RANK_EFFECTS_EXTRA[g][2]
        if len(ladder) != len(RANK_VALUES):
            out.append("%s: the second effect ladder must be indexed 1-5 like "
                       "RANK_VALUES, got %d entries" % (g, len(ladder)))
        elif all(v is None for v in ladder):
            out.append("%s has a second rank effect that never fires" % g)
    return out


def check():
    """Refuses to write on anything that fails silently in game."""
    out = []
    if not PATRON_EFFECTS:
        out.append("PATRON_EFFECTS is empty, so the patron bundle would carry no "
                   "effect at all - a post that grants nothing")
    for _k, _sc, _v in PATRON_EFFECTS:
        if _k not in PATRON_BLURB:
            out.append("patron effect %s has no phrase in PATRON_BLURB, so its number "
                       "would draw with nothing explaining it" % _k)
    if out:
        return out          # build() indexes PATRON_BLURB and would raise on these
    out += check_extra_effects()
    if out:
        return out          # build() would raise on these
    out += check_flavour_shape()
    if out:
        return out          # build() would raise on an incomplete flavour
    out += check_flavours()
    out += check_favour_floor()
    out += check_monopoly_mirror()
    out += check_rival_mirror()
    out += check_help_pages()
    out += check_feed_mirror()
    out += check_ui_loc_keys()
    out += check_ledger_sources()
    out += check_feed_images()
    out += check_titles()
    out += check_hire_units()
    out += check_flavour_mirror()
    out += check_mct_names()
    out += check_player_scope()
    out += check_building_theme()
    out += check_built_effects()
    out += check_live_references()
    out += check_presets()
    out += check_bounties()
    out += check_table_versions()
    try:
        sys.path.insert(0, "tools")
        import read_vanilla_cache as R
        eff_rows, _ = R.load("effects")
        known_effects = set(r["effect"] for r in eff_rows)
        jun_rows, _ = R.load("effect_bundles_to_effects_junctions")
        known_pairs = set((r["effect_key"], r["effect_scope"]) for r in jun_rows)
        # WHAT VALUES VANILLA ACTUALLY PUTS ON EACH PAIR. A key that exists and a scope
        # CA pairs with it are both true of an effect you are using thirty times too
        # hard: force_army_campaign_recruitment_points is real, correctly scoped, and
        # never carries more than 2.
        vanilla_range = {}
        for r in jun_rows:
            try:
                v = abs(float(r["value"]))
            except (TypeError, ValueError):
                continue
            pair = (r["effect_key"], r["effect_scope"])
            hi, n = vanilla_range.get(pair, (0.0, 0))
            vanilla_range[pair] = (max(hi, v), n + 1)
        pairs_to_check = [(g, k, sc) for g, (k, sc) in RANK_EFFECTS.items()]
        pairs_to_check += [(g, x[0], x[1]) for g, x in RANK_EFFECTS_EXTRA.items()]
        pairs_to_check += [("patron", k, sc) for k, sc, _v in PATRON_EFFECTS]
        for g, k, sc in pairs_to_check:
            if k not in known_effects:
                out.append("effect key not in vanilla effects table: %s (%s)" % (k, g))
            elif (k, sc) not in known_pairs:
                out.append("vanilla never pairs %s with scope %s (%s)" % (k, sc, g))
        # The sign trap. is_positive_value_good is False on every COST modifier, so a
        # positive value there makes the thing more expensive - a ladder that punishes
        # the player harder the more they earn, drawn in red, with nothing to catch it.
        good = dict((r["effect"], str(r.get("is_positive_value_good")).lower() == "true")
                    for r in eff_rows)
        for g, (k, sc) in RANK_EFFECTS.items():
            if k not in good:
                continue
            want = 1 if good[k] else -1
            if EFFECT_GOOD_SIGN.get(g) != want:
                out.append("%s: %s has is_positive_value_good=%s so the value must be "
                           "%s, but EFFECT_GOOD_SIGN is %+d"
                           % (g, k, good[k], "positive" if want > 0 else "negative",
                              EFFECT_GOOD_SIGN.get(g, 0)))
        for k, _sc, v in PATRON_EFFECTS:
            if k in good and good[k] and v <= 0:
                out.append("patron effect %s is is_positive_value_good, so %g makes "
                           "the army worse" % (k, v))
            if k in good and not good[k] and v >= 0:
                out.append("patron effect %s has is_positive_value_good=False, so %g "
                           "is a penalty drawn as a reward" % (k, v))

        # And the emitted rows must actually carry that sign.
        # EVERY FLAVOUR'S COPY of the hostile bundle, or the tagged ones read as a malus
        # on the buyer's own sign and are reported as inverted.
        hostile_keys = set(service_bundle_key(x["key"]) + t
                           for x in SERVICES if x.get("hostile") for t in FLAVOURS)
        for r in build()["effect_bundles_to_effects_junctions"]:
            # EVERY VALUE MUST SIT INSIDE VANILLA'S OWN RANGE for this exact
            # (effect, scope) pair. Nothing else catches an effect used at the wrong
            # magnitude: the key is real, the scope is precedented, the sign is right,
            # and the pack loads perfectly.
            seen = vanilla_range.get((r["effect_key"], r["effect_scope"]))
            # MAGNITUDE, not range: a value smaller than vanilla's is never the fault,
            # and a pair with one or two vanilla rows has no range worth the name.
            # 1.5x is the tightest tolerance this design passes and still catches what
            # it was written for.
            if seen and seen[1] >= VALUE_RANGE_MIN_ROWS:
                v_hi, v_n = seen
                v = abs(float(r["value"]))
                if v > v_hi * VALUE_RANGE_TOLERANCE:
                    out.append("%s puts %g on %s, and the largest magnitude vanilla "
                               "ever puts on that effect and scope is %g across %d "
                               "rows - the value ladder is being used %.0fx too hard"
                               % (r["effect_bundle_key"], float(r["value"]),
                                  r["effect_key"], v_hi, v_n, v / v_hi))
            if r["effect_key"] not in good:
                continue
            v = int(r["value"])
            # A hostile bundle lands on the enemy, so it must be BAD for its holder.
            want_positive = good[r["effect_key"]]
            if r["effect_bundle_key"] in hostile_keys:
                want_positive = not want_positive
            if v == 0 or (v > 0) != want_positive:
                out.append("junction %s: value %+d fights is_positive_value_good=%s%s"
                           % (r["effect_bundle_key"], v, good[r["effect_key"]],
                              " (hostile, so inverted)"
                              if r["effect_bundle_key"] in hostile_keys else ""))
    except Exception as e:
        out.append("could not read vanilla cache: %r" % (e,))
    # Every unit key a service grants must exist. Unvalidated strings fail silently.
    try:
        sys.path.insert(0, "tools")
        import read_vanilla_cache as R2
        mu_rows, _ = R2.load("main_units")
        known_units = set(str(r.get("unit", "")) for r in mu_rows)
        for s in SERVICES:
            u = s.get("unit")
            if u and u not in known_units:
                out.append("unit key not in main_units: %s (%s)" % (u, s["key"]))
    except Exception as e:
        out.append("could not read main_units: %r" % (e,))

    # The feed index must not collide with a vanilla one, and the chain must be
    # complete. A wrong or duplicate index draws nothing, silently.
    try:
        sys.path.insert(0, "tools")
        import read_vanilla_cache as R3
        cgv_rows, _ = R3.load("campaign_group_member_criteria_values")
        taken = set()
        for r in cgv_rows:
            v = str(r.get("value", ""))
            if v.lstrip("-").isdigit():
                taken.add(int(v))
        # READ OFF build(), not off a hand-written tuple of the constants. This check
        # named FEED_INDEX and FEED_INDEX_DEMAND literally, so adding a third feed
        # record left it passing while checking two thirds of the thing it guards -
        # and the collision it guards against draws nothing at all, in silence.
        _t = build()
        mine = [int(r["value"]) for r in _t["campaign_group_member_criteria_values"]]
        for idx in mine:
            if idx in taken:
                out.append("feed index %d collides with a vanilla index" % idx)
            if idx <= max(taken):
                out.append("feed index %d is inside vanilla's range (max %d) - pick "
                           "higher" % (idx, max(taken)))
        for idx in sorted(set(i for i in mine if mine.count(i) > 1)):
            out.append("%d feed records claim index %d, so all but one of them are "
                       "unreachable" % (mine.count(idx), idx))
        cg_rows, _ = R3.load("campaign_groups")
        vanilla_groups = set(r["id"] for r in cg_rows)
        for r in _t["campaign_groups"]:
            if r["id"] in vanilla_groups:
                out.append("feed group %s already exists in vanilla" % r["id"])
    except Exception as e:
        out.append("could not check the feed index: %r" % (e,))

    tables = build()
    for r in tables["event_feed_message_events"]:
        if r["event"] != "scripted_persistent_event":
            out.append("the Lua passes persistent=true, so %s's event must be "
                       "scripted_persistent_event" % r["group"])
    # THE ROW COUNTS FIRST, and the chain only if they agree. The other order raises an
    # IndexError out of check() the moment a record is dropped from one of the four
    # tables - which is a crash where a finding was wanted, and a crash is how the
    # positional PATRON_EFFECTS indexing hid its own fault report a week ago.
    feed_tables = ("campaign_groups", "campaign_group_members",
                   "campaign_group_member_criteria_values",
                   "event_feed_message_events")
    counts = set(len(tables[t]) for t in feed_tables)
    if len(counts) != 1:
        out.append("the four feed tables hold %r rows between them, so at least one "
                   "record is missing a link and resolves to nothing"
                   % (dict((t, len(tables[t])) for t in feed_tables),))
    else:
        # EVERY record's chain, not the first one's. The four tables are joined by a
        # group id repeated across all of them; a record whose five ids do not agree
        # resolves to no index and shows nothing, and the version of this check that
        # looked only at [0] would have passed a broken second or third record
        # without a word.
        for i in range(len(tables["campaign_groups"])):
            chain = [tables["campaign_groups"][i]["id"],
                     tables["campaign_group_members"][i]["group"],
                     tables["campaign_group_members"][i]["id"],
                     tables["campaign_group_member_criteria_values"][i]["member"],
                     tables["event_feed_message_events"][i]["group"]]
            if len(set(chain)) != 1:
                out.append("the four-table feed chain does not agree: %r" % (chain,))

    seen = set()
    for r in build()["effect_bundles"]:
        if r["key"] in seen:
            out.append("duplicate bundle key: " + r["key"])
        seen.add(r["key"])
    return out


# RPFM's TSV format carries a metadata line as ROW 2: "#<name>;<version>;<container path>",
# padded with tabs to the column count. Without it import_tsv refuses the whole file with
# "invalid version value at line 1" and imports nothing.
#
# Every version below is CA's LIVE one, read 2026-09-10 via
# get_table_version_from_dependency_pack_file. RPFM's schema default is not guaranteed to
# match it, and a version whose field shape disagrees loads as a corrupt table.
TSV_META = {
    "effect_bundles": ("effect_bundles_tables", 4),
    "effect_bundles_to_effects_junctions": ("effect_bundles_to_effects_junctions_tables", 3),
    "campaign_groups": ("campaign_groups_tables", 0),
    "campaign_group_members": ("campaign_group_members_tables", 1),
    "campaign_group_member_criteria_values":
        ("campaign_group_member_criteria_values_tables", 0),
    "event_feed_message_events": ("event_feed_message_events_tables", 1),
    # VERSION 0, MEASURED, NOT GUESSED. CA's own
    # db.pack/db/missions_tables/data__ declares 0 and carries all 19 columns, and so do
    # both other mod missions tables on this machine. RPFM's schema also holds a version
    # 6 with 17 fields - the OLDER shape, without localised_mission_completed_text or
    # can_be_manually_cancelled.
    #
    # Declaring 6 here shipped once and CRASHED THE GAME during loading: no
    # bad_mods_report.txt, no minidump, no script log at all, because the parse fails
    # before any script runs. check() now pins every version below to what CA's own file
    # declares, read offline via read_vanilla_cache.version().
    "missions": ("missions_tables", 0),
    # The building-card line. Both 0, what CA's own files declare.
    "effects": ("effects_tables", 0),
    "building_effects_junction": ("building_effects_junction_tables", 0),
    "loc": ("Loc", 1),
}
PACK_NAME = "derpy_great_guilds"


def container_path(table):
    if table == "loc":
        return "text/db/%s.loc" % PACK_NAME
    return "db/%s/%s" % (TSV_META[table][0], PACK_NAME)


def render_tsvs():
    """{table: exact file text}, without touching the disk.

    SPLIT OUT OF write_tsvs SO A CHECK CAN COMPARE CONTENT. import_great_guilds.verify()
    used to compare only the ROW COUNT of each TSV against build(), which says nothing
    about the values in them: on 2026-09-12 four event pictures and one loc string
    changed, no count moved, `--check` was green, and the pack was written from the
    previous build's TSVs. Only the read-back after saving caught it.

    Rendering rather than re-deriving the column order is the point - a second copy of
    that order in a checker is a checker that can disagree with the writer.
    """
    out = {}
    for table, rows in build().items():
        if not rows:
            continue
        cols = list(rows[0].keys())
        name, version = TSV_META[table]
        pad = "\t" * (len(cols) - 1)
        lines = ["\t".join(cols),
                 "#%s;%d;%s%s" % (name, version, container_path(table), pad)]
        for r in rows:
            lines.append("\t".join(r[c] for c in cols))
        out[table] = "\n".join(lines) + "\n"
    return out


def write_tsvs(outdir):
    import io
    import os
    if not os.path.isdir(outdir):
        os.makedirs(outdir)
    written = []
    for table, text in render_tsvs().items():
        path = os.path.join(outdir, table + ".tsv")
        with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        written.append(path)
    return written


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
    # THE CHAOS DWARF PASS. Every count below is one flavour's; the block at the end of
    # this function holds build(), which ships all of them, to the same shape.
    tables = _build_one("")
    # The bounties: one per guild, each naming a kind that exists, and the objective
    # template must carry exactly one %s or the target is never substituted in.
    assert len(tables["missions"]) == len(GUILDS), "one bounty mission row per guild"
    for g in GUILDS:
        kind = BOUNTIES[g][0]
        assert kind in BOUNTY_KINDS, "%s: unknown bounty kind %s" % (g, kind)
        assert BOUNTY_KINDS[kind]["obj"].count("%s") == 1, \
            "%s: objective template must take exactly one target" % kind
        assert BOUNTY_KINDS[kind]["gold"] > 0, "%s: a bounty must pay" % kind
    assert not check_bounties(), check_bounties()
    eb = tables["effect_bundles"]
    rank_rows = [r for r in eb if r["key"].startswith("derpy_gg_rank_")]
    assert len(rank_rows) == 24, "24 rank bundle rows, got %d" % len(rank_rows)
    assert all(r["is_global_effect"] == "true" for r in eb), "is_global_effect must be true"
    # EVERY bundle is faction-target EXCEPT the patron, which lands on one army. The
    # exception is named rather than loosened, so a second force bundle appearing by
    # accident still fails here.
    for r in eb:
        want = "force" if r["key"] == PATRON_BUNDLE else "faction"
        assert r["bundle_target"] == want, (
            "%s must be bundle_target %s, is %s" % (r["key"], want, r["bundle_target"]))
    j = tables["effect_bundles_to_effects_junctions"]
    # NOT one per bundle any more: a guild may carry a SECOND rank effect with its own
    # value ladder, which the Immortals do because a flat count of recruitment slots
    # cannot ride the shared percentage ladder. Counted exactly rather than loosened to
    # ">=", so an accidental duplicate row is still a failure.
    extra_rows = sum(1 for _gu, x in RANK_EFFECTS_EXTRA.items()
                     for rk in range(2, 6) if x[2][rk] is not None)
    # The patron bundle carries two effects, so it is one bundle and two junctions.
    patron_extra = len(PATRON_EFFECTS) - 1
    want = len(eb) + extra_rows + patron_extra
    assert len(j) == want, (
        "expected %d junctions (%d bundles + %d second effects + %d patron), got %d"
        % (want, len(eb), extra_rows, patron_extra, len(j)))
    # And no bundle may carry the same effect twice, which is how a second-effect
    # table with a typo'd key would show up.
    seen_pairs = set()
    for r in j:
        pair = (r["effect_bundle_key"], r["effect_key"])
        assert pair not in seen_pairs, "bundle %s carries %s twice" % pair
        seen_pairs.add(pair)
    assert set(r["effect_bundle_key"] for r in j) == set(r["key"] for r in eb), \
        "every bundle has a junction row"
    assert all(r["advancement_stage"] == "start_turn_completed" for r in j), \
        "advancement_stage must match vanilla's 16351-of-16430 default"
    assert all("unseen" not in r["effect_scope"] for r in j), \
        "an _unseen scope hides the effect the player is meant to read"
    loc = tables["loc"]
    # A %+n placeholder belongs on an EFFECT description, where the engine substitutes the
    # effect's value. A BUNDLE description has no value to substitute, so the placeholder
    # renders literally. Measured: 1 of 5,855 vanilla bundle descriptions contains one.
    for r in loc:
        if "effect_bundles_localised_description" in r["key"]:
            # A LITERAL percent sign is fine and vanilla uses it. What must not appear
            # is a substitution PLACEHOLDER - %n, %+n - because a bundle has no single
            # value to substitute and the placeholder renders as itself.
            assert not re.search(r"%[-+]?n", r["text"]),                 "a bundle description has no value to substitute: " + r["key"]
    assert len(SERVICES) == 18, "18 services, got %d" % len(SERVICES)
    assert len(set(s["key"] for s in SERVICES)) == 18, "service keys unique"
    for g in GUILDS:
        mine = [s for s in SERVICES if s["guild"] == g]
        assert len(mine) == 3, "%s has %d services, want 3" % (g, len(mine))
        assert sorted(s["rank"] for s in mine) == [2, 3, 4], "%s ranks must be 2,3,4" % g
        assert sorted(s["cost"] for s in mine) == [50, 150, 400], "%s costs" % g
    bundled = [s for s in SERVICES if s["kind"] == "bundle"]
    assert len(bundled) == 12, "12 bundle services, got %d" % len(bundled)
    want_eb = 24 + 12 + len(GUILDS) + 1
    assert len(eb) == want_eb, (
        "24 rank + 12 service + %d leadership + 1 patron = %d, got %d"
        % (len(GUILDS), want_eb, len(eb)))
    lead_rows = [r for r in eb if r["key"].startswith("derpy_gg_lead_")]
    assert len(lead_rows) == len(GUILDS), (
        "one leadership bundle per guild, got %d" % len(lead_rows))
    # The monopoly and the bundle are two halves of one feature: a guild with a
    # leadership bundle and no locked service pays a bonus and changes no decision.
    assert len(LEAD_SERVICES) == len(GUILDS), (
        "one monopoly service per guild, got %d" % len(LEAD_SERVICES))
    for s in SERVICES:
        if s["key"] in LEAD_SERVICES:
            assert s["rank"] == 4, "the monopoly is the top service: " + s["key"]
    for s in SERVICES:
        assert s["cd"] >= 5, "cooldown floor is 5 turns: " + s["key"]
        assert s["kind"] in ("bundle", "gold", "unit", "research",
                            "shroud", "building", "pooled"), "kind: " + s["kind"]
        if s["kind"] == "bundle":
            assert s.get("turns", 0) > 0, "a timed bundle needs turns: " + s["key"]
    hostile = [s for s in SERVICES if s.get("hostile")]
    assert len(hostile) == 1, "exactly one outward-facing service, got %d" % len(hostile)
    # ------------------------------------------------------------ the flavours ---
    assert list(FLAVOURS) == ["", "_emp", "_dwf", "_brt", "_cth", "_ksl", "_def", "_hef",
                             "_gen"], list(FLAVOURS)
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
    sample = ('GG.CHD_CULTURE = "wh3_dlc23_chd_chaos_dwarfs"\n'
              'GG.FLAVOURED = {\n'
              '    [GG.CHD_CULTURE]       = {tag = "",     feed = 0},\n'
              '    ["wh_main_emp_empire"] = {tag = "_emp", feed = 10},\n'
              '}\n')
    assert lua_flavoured(sample) == {"wh3_dlc23_chd_chaos_dwarfs": ("", 0),
                                     "wh_main_emp_empire": ("_emp", 10)}, \
        lua_flavoured(sample)
    assert lua_flavoured("GG.FLAVOURED = nil") is None
    print("selftest ok: %d guilds, %d services, %d bundles, %d loc"
          % (len(GUILDS), len(SERVICES), len(eb), len(loc)))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    if "--write" in sys.argv:
        for _p in write_tsvs("Modding Files/source/great_guilds"):
            print("wrote " + _p)
        print("wrote " + write_mct_names())
    if "--check" in sys.argv:
        problems = check()
        for p in problems:
            print("PROBLEM: " + p)
        sys.exit(1 if problems else 0)
