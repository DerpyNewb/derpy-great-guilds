-- Stubbed campaign for zzz_derpy_guilds.lua. Run under Lua 5.1.5 from the
-- workspace root:
--   & "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\_guilds_harness.lua
--
-- A generator selftest proves the code does what it was written to do; this
-- proves the shipped Lua does what the design says. It cannot prove the game
-- agrees - that is what the live test list in the spec is for.
--
-- NEW TESTS GO IN A `do ... end` BLOCK. Lua 5.1 allows 200 locals per function and the
-- main chunk here is within a handful of that ceiling - adding three at the top level hit
-- it on 2026-09-13. The error is "main function has more than 200 local variables" and it
-- names a line hundreds away from the one that broke it, so it reads as a mystery.

local applied, removed, saved = {}, {}, {}

-- [faction key] = true for a faction the campaign has destroyed, and for one that was
-- never in this campaign at all. Two different states, and the mod must tell them apart:
-- a death is permanent and cacheable, an unreadable faction is not proof of anything.
DEAD_FACTIONS = {}
NO_SUCH_FACTION = {}

-- WHAT THE MOD REGISTERED FOR THE FIRST TICK, kept rather than discarded. A save load
-- re-runs the file and then the first tick; everything the mod does to recover session
-- state happens in there, so a stub that throws the callbacks away cannot tell a
-- recovery that works from one that was never written.
FIRST_TICKS = {}

cm = {
  set_saved_value = function(_, k, v) saved[k] = v end,
  get_saved_value = function(_, k) return saved[k] end,
  apply_effect_bundle = function(_, b, f, t) applied[#applied + 1] = {b, f, t} end,
  remove_effect_bundle = function(_, b, f) removed[#removed + 1] = {b, f} end,
  add_first_tick_callback = function(_, fn) FIRST_TICKS[#FIRST_TICKS + 1] = fn end,
  -- OVERRIDDEN BELOW, at the CULTURE block. Kept only so the table is complete if
  -- something reads it before then; the stub that matters is the later one.
  get_faction = function(_, k)
    return {is_null_interface = function() return false end,
            name = function() return k end}
  end,
}
-- Payload sinks, for the six non-bundle service kinds.
local gold, units, research, shroud, built, pooled = {}, {}, {}, {}, {}, {}
cm.treasury_mod = function(_, f, n) gold[#gold + 1] = {f, n} end
cm.grant_unit_to_character = function(_, cqi, u) units[#units + 1] = {cqi, u} end
cm.instantly_research_technology = function(_, f, t) research[#research + 1] = {f, t} end
cm.make_region_visible_in_shroud = function(_, f, r) shroud[#shroud + 1] = {f, r} end
cm.region_slot_instantly_upgrade_building = function(_, slot, bkey)
    built[#built + 1] = {slot, bkey}
end
cm.faction_add_pooled_resource = function(_, f, res, fac, n)
    pooled[#pooled + 1] = {f, res, fac, n}
end

-- ----------------------------------------------------------- bounty stubs ---
-- Enough campaign to run GG.bounty_target's walk for real. A stub that returns a
-- target without being walked would prove only that the arithmetic downstream works,
-- and the walk is where a wrong method name silently means "no bounties, ever".
local TURN = 1
local issued = {}
local WARS = {}

local function LIST(items)
    return {num_items = function() return #items end,
            item_at = function(_, i) return items[i + 1] end}
end

local function ENEMY(name, regions, generals)
    local rs, mfs = {}, {}
    for i = 1, #regions do
        local key = regions[i]
        rs[i] = {name = function() return key end}
    end
    for i = 1, #generals do
        local cqi = generals[i]
        mfs[i] = {
            has_general = function() return true end,
            is_armed_citizenry = function() return false end,
            general_character = function()
                return {has_region = function() return true end,
                        family_member = function()
                            return {command_queue_index = function() return cqi end}
                        end}
            end,
        }
    end
    return {name = function() return name end,
            is_dead = function() return false end,
            region_list = function() return LIST(rs) end,
            military_force_list = function() return LIST(mfs) end}
end

cm.model = function() return {turn_number = function() return TURN end} end
-- Deterministic on purpose: GG.roll falls back to 1 without this, and a harness that
-- rolls differently every run cannot assert which guilds are on the board.
cm.random_number = function(_, _n) return 1 end
cm.trigger_custom_mission_from_string = function(_, f, str)
    issued[#issued + 1] = {f, str}
end
-- A world the board can go stale against: who owns which region, who is at war with
-- whom, and which characters still exist.
local REGION_OWNER = {}
local AT_WAR = {}
local ALIVE_FM = {}

CULTURE = {}

-- A CHAOS DWARF AT THE KEYBOARD, from here to the end of the file.
--
-- The mod's scope is the PLAYER's culture, read off the human faction rather than listed
-- in the Lua - so with nobody human, nobody has a culture that counts and not one faction
-- in this harness earns anything. Declared HERE rather than beside the other cm stubs
-- further down, because the first block that grants reputation runs long before those.
--
-- The key is one no other block uses, so GG.announce_lead and its neighbours still fire
-- for nobody: they test `who == me`, and `me` never appears in them. A block that needs a
-- different human sets its own stub and clears GG.player_cultures_cache, which is why
-- that cache is a plain field rather than an upvalue.
THE_PLAYER = "cr_the_player"
CULTURE[THE_PLAYER] = "wh3_dlc23_chd_chaos_dwarfs"
cm.get_human_factions = function() return {THE_PLAYER} end

-- FACTIONS CAN DIE HERE, and this is the get_faction that is in force - the one in the
-- cm table above is overridden by this line. Without is_dead, GG.faction_dead's pcall
-- swallowed a "no such method" error and answered "alive" for every faction, so a test
-- of the dead-leader rule would have passed with the rule deleted. is_dead IS on the
-- real FACTION_SCRIPT_INTERFACE - CA's scripting_doc, "Returns true if the faction is
-- dead" - unlike the character interfaces, where no such call exists at all.
--
-- NO_SUCH_FACTION is the other state, and the mod must tell the two apart: a death is
-- permanent and worth caching, a faction this campaign does not have is not proof of
-- anything. cm:get_faction returns FALSE for the second, not nil.
cm.get_faction = function(_, k)
    if NO_SUCH_FACTION[k] then return false end
    return {is_null_interface = function() return false end,
            is_dead = function() return DEAD_FACTIONS[k] == true end,
            name = function() return k end,
            culture = function() return CULTURE[k] or "wh3_dlc23_chd_chaos_dwarfs" end,
            factions_at_war_with = function() return LIST(WARS[k] or {}) end,
            at_war_with = function(_, other)
                local mine = AT_WAR[k]
                return mine ~= nil and mine[other:name()] == true
            end,
            -- A demand for gold asks the faction what it has. Without this the tribute
            -- branch of GG.demand_payable is never actually exercised.
            treasury = function() return TREASURY[k] or 0 end}
end

TREASURY = {}

local function NULL() return {is_null_interface = function() return true end} end

REGION_WORTH = {}      -- [key] = {buildings, is_capital, has_army}
cm.get_region = function(_, key)
    local owner = REGION_OWNER[key]
    if not owner then return NULL() end
    local w = REGION_WORTH[key] or {}
    return {is_null_interface = function() return false end,
            owning_faction = function()
                return {is_null_interface = function() return false end,
                        name = function() return owner end}
            end,
            num_buildings = function() return w[1] or 0 end,
            is_province_capital = function() return w[2] == true end,
            garrison_residence = function()
                return {is_null_interface = function() return false end,
                        has_army = function() return w[3] == true end}
            end}
end

LORD_WORTH = {}        -- [cqi] = {rank, is_faction_leader, units}

-- ALIVE_FM MEANS "THIS CQI IS IN THE FAMILY TREE AT ALL", NOT "THIS LORD IS ALIVE.
-- A FAMILY MEMBER SURVIVES ITS CHARACTER'S DEATH. CA's model_hierarchy, verbatim: "The
-- family member script interface represents a character within a family tree. This
-- interface is persistent, even if the related character is destroyed and recreated."
-- So a dead lord must NOT be modelled by deleting him from this table: doing that gives
-- GG.bounty_still_valid a null interface to notice, which the real engine never hands it,
-- and the test would then prove the opposite of the truth. Death reaches the mod through
-- CharacterDestroyed and through nothing else - there is no is_dead on family_member, on
-- character or on character_details.
cm.get_family_member_by_cqi = function(_, cqi)
    if not ALIVE_FM[tostring(cqi)] then return NULL() end
    local w = LORD_WORTH[tostring(cqi)] or {}
    return {is_null_interface = function() return false end,
            character = function()
                return {is_null_interface = function() return false end,
                        rank = function() return w[1] or 0 end,
                        is_faction_leader = function() return w[2] == true end,
                        military_force = function()
                            if not w[3] then return NULL() end
                            return {is_null_interface = function() return false end,
                                    unit_list = function()
                                        local n = w[3]
                                        return {num_items = function() return n end}
                                    end}
                        end}
            end}
end

-- ------------------------------------------------------------ court stubs ---
-- The patron's bundle lands on a FORCE, which is a different pair of calls from the
-- faction bundles above, and a demand reaches the player through the event feed.
local force_applied, force_removed, feed = {}, {}, {}
cm.apply_effect_bundle_to_force = function(_, b, cqi, t)
    force_applied[#force_applied + 1] = {b, cqi, t}
end
cm.remove_effect_bundle_from_force = function(_, b, cqi)
    force_removed[#force_removed + 1] = {b, cqi}
end
cm.show_message_event = function(_, f, title, _primary, _secondary, _persist, idx)
    feed[#feed + 1] = {f, title, idx}
end

-- [character cqi] = the cqi of their army, or false for a lord who commands none, or
-- nil for a lord who no longer exists. All three are real states of a patron.
CHAR_FORCE = {}
cm.get_character_by_cqi = function(_, cqi)
    local force = CHAR_FORCE[tostring(cqi)]
    if force == nil then return NULL() end
    return {is_null_interface = function() return false end,
            military_force = function()
                if force == false then return NULL() end
                return {is_null_interface = function() return false end,
                        command_queue_index = function() return force end}
            end}
end

-- Listener registrations are RECORDED, not discarded. GG.on_agent_action and
-- GG.on_settlement shipped with no listener calling them at all, so two guilds could not
-- earn from their own route; nothing here noticed, because add_listener was a no-op.
-- AND THE HANDLER IS KEPT, not just the fact that something registered. A gate that
-- lives inside a listener body is unreachable from any test that calls the function the
-- listener calls - which is how GGAI's sweep ran on every one of ~190 faction turn
-- starts a round while a harness that drove GGAI.run_turn directly saw nothing wrong.
local listened, handlers = {}, {}
core = {add_listener = function(_, name, event, _cond, fn)
    listened[event] = true
    handlers[name] = fn
end}
out = function() end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua")

-- WHERE THE MODEL'S FIRST-TICK CALLBACKS END. The UI file registers its own further
-- down and it draws, so a test of the model's recovery must not run that one.
MODEL_TICKS = #FIRST_TICKS

-- Shape.
assert(#GG.GUILDS == 6, "six guilds")
assert(GG.rank_of(0) == 1, "zero is rank 1")
assert(GG.rank_of(99) == 1, "99 is still rank 1")
assert(GG.rank_of(100) == 2, "100 is rank 2")
assert(GG.rank_of(1500) == 5, "1500 is rank 5")
assert(GG.rank_of(999999) == 5, "rank caps at 5")

-- A grant moves both numbers and fires the rank bundle.
GG.grant("cr_test", "brass", 120)
local rep, fav = GG.get("cr_test", "brass")
assert(rep == 120 and fav == 120, "grant moves both numbers, got " .. rep .. "," .. fav)
assert(#applied == 1, "rank up applied one bundle, got " .. #applied)
assert(applied[1][1] == "derpy_gg_rank_brass_2", "wrong bundle: " .. applied[1][1])
-- -1 is CA's indefinite. 0 applies for zero turns and does nothing, silently.
assert(applied[1][3] == -1, "rank bundle must be indefinite (-1), got "
       .. tostring(applied[1][3]))

-- Spending takes favour only. Rank must not move.
GG.spend("cr_test", "brass", 50)
rep, fav = GG.get("cr_test", "brass")
assert(rep == 120 and fav == 70, "spend takes favour only, got " .. rep .. "," .. fav)
assert(#applied == 1, "spending must not re-apply a bundle")

-- Rank 2 -> 3 replaces, it does not stack.
GG.grant("cr_test", "brass", 200)
assert(#removed == 1 and removed[1][1] == "derpy_gg_rank_brass_2", "old bundle removed")
assert(applied[2][1] == "derpy_gg_rank_brass_3", "new bundle applied")

-- Favour caps at 2x the current rank threshold.
GG.grant("cr_test", "immortals", 99999)
local _, ifav = GG.get("cr_test", "immortals")
assert(ifav == 3000, "favour caps at 2x rank threshold, got " .. ifav)

-- Save round-trips.
GG.save("cr_test")
GG.state["cr_test"] = nil
GG.load("cr_test")
rep, fav = GG.get("cr_test", "brass")
assert(rep == 320, "save round-trip lost reputation, got " .. tostring(rep))

-- An unknown guild is a no-op, never an error.
GG.grant("cr_test", "not_a_guild", 50)

-- Per-turn caps. brass is capped at 40 a turn.
GG.reset_turn("cr_cap")
GG.on_turn_start("cr_cap", 100000)     -- 100000/250 = 400, must clamp to 40
local crep = select(1, GG.get("cr_cap", "brass"))
assert(crep == 40, "brass per-turn cap is 40, got " .. crep)
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
assert(select(1, GG.get("cr_s", "slavers")) == 65, "sack 25 + raze 40, got "
       .. select(1, GG.get("cr_s", "slavers")))
-- Pins the raze arithmetic. floor(25 * 1.6) can be 39 in float32; 25*8/5 is 40.
GG.reset_turn("cr_raze")
GG.state["cr_raze"] = nil
GG.on_settlement("cr_raze", true)
assert(select(1, GG.get("cr_raze", "slavers")) == 40,
       "raze must be exactly 40 at the default rate, got "
       .. select(1, GG.get("cr_raze", "slavers")))

-- Building level scales.
GG.reset_turn("cr_m")
GG.on_building("cr_m", 3)
assert(select(1, GG.get("cr_m", "overseers")) == 30, "10 x level")

-- daemonsmiths has no cap, so a run of techs in one turn all pay.
GG.reset_turn("cr_t")
for _ = 1, 5 do GG.on_tech("cr_t") end
assert(select(1, GG.get("cr_t", "daemonsmiths")) == 300, "uncapped guild pays every time")

-- Negative or zero income pays nothing and does not error.
GG.reset_turn("cr_z")
GG.on_turn_start("cr_z", -5000)
GG.on_turn_start("cr_z", 0)
assert(select(1, GG.get("cr_z", "brass")) == 0, "no reputation from a loss")

-- ---------------------------------------------------------------- plan 2 ----
-- Rank gate: a service above your rank refuses.
GG.state["cr_buy"] = nil
GG.grant("cr_buy", "brass", 120)                        -- rank 2, 120 favour
local ok, why = GG.can_buy("cr_buy", "writ_monopoly")   -- needs rank 3
assert(ok == false and why == "rank", "rank gate, got " .. tostring(why))

-- Affordability.
ok, why = GG.can_buy("cr_buy", "caravan_levy")          -- rank 2, costs 50
assert(ok == true, "should be buyable, got " .. tostring(why))
assert(GG.buy("cr_buy", "caravan_levy") == true, "buy succeeds")
local _, bfav = GG.get("cr_buy", "brass")
assert(bfav == 70, "buy took 50 favour, got " .. bfav)

-- Cooldown blocks an immediate repeat.
ok, why = GG.can_buy("cr_buy", "caravan_levy")
assert(ok == false and why == "cooldown", "cooldown blocks, got " .. tostring(why))
assert(GG.cooldown_left("cr_buy", "caravan_levy") == 8, "8 turn cooldown")

-- Cooldown ticks down and clears.
for _ = 1, 8 do GG.tick_cooldowns("cr_buy") end
assert(GG.cooldown_left("cr_buy", "caravan_levy") == 0, "cooldown cleared")

-- Poverty.
GG.state["cr_poor"] = nil
GG.grant("cr_poor", "brass", 100)
GG.spend("cr_poor", "brass", 99)
ok, why = GG.can_buy("cr_poor", "caravan_levy")
assert(ok == false and why == "favour", "poverty refuses, got " .. tostring(why))

-- Buying must never move reputation, so it can never demote. This is the
-- design's core invariant.
assert(select(1, GG.get("cr_buy", "brass")) == 120, "buying moved reputation")

-- An unknown service key refuses rather than throwing.
ok, why = GG.can_buy("cr_buy", "not_a_service")
assert(ok == false and why == "unknown", "unknown service, got " .. tostring(why))

-- Cooldowns survive a save/reload, or every service is free after one save.
GG.buy("cr_buy", "caravan_levy")
GG.save("cr_buy")
GG.cooldowns["cr_buy"] = nil
GG.state["cr_buy"] = nil
GG.load("cr_buy")
assert(GG.cooldown_left("cr_buy", "caravan_levy") == 8,
       "cooldown lost on reload, got " .. GG.cooldown_left("cr_buy", "caravan_levy"))

-- ------------------------------------------------- plan 2, task 3 payloads ---
-- Counts are RELATIVE: the plan-2 task 2 section above already bought
-- caravan_levy twice, so the sinks are not empty here.
local g0 = #gold
GG.state["cr_pay"] = nil
GG.grant("cr_pay", "brass", 200)
GG.buy("cr_pay", "caravan_levy")
assert(#gold == g0 + 1, "caravan levy paid once, got " .. (#gold - g0))
assert(gold[#gold][2] == 2500, "caravan levy pays 2500, got " .. gold[#gold][2])

-- A bundle service applies for its own turn count, not indefinitely.
GG.state["cr_pay_b"] = nil
GG.grant("cr_pay_b", "brass", 400)
local before_applied = #applied
GG.buy("cr_pay_b", "writ_monopoly")
assert(#applied == before_applied + 1, "bundle service applied one bundle")
assert(applied[#applied][1] == "derpy_gg_svc_writ_monopoly",
       "wrong service bundle: " .. applied[#applied][1])
assert(applied[#applied][3] == 10, "writ of monopoly runs 10 turns, got "
       .. tostring(applied[#applied][3]))

-- Chaos Dwarfs get two pooled resources; the factor must be one both pools accept.
GG.state["cr_pay2"] = nil
GG.grant("cr_pay2", "slavers", 400)
GG.buy("cr_pay2", "slave_tithe")
assert(#pooled == 2, "slave tithe grants two CHD resources, got " .. #pooled)
assert(pooled[1][2] == "wh3_dlc23_chd_armaments", "armaments first")
assert(pooled[2][2] == "wh3_dlc23_chd_raw_materials", "raw materials second")
assert(pooled[1][3] == "missions", "factor must be missions - raw_materials has no "
       .. "events junction, so events is a silent no-op there")

-- A NON-CHAOS-DWARF BUYER gets gold instead, never a resource it does not own. The
-- Chaos Dwarf pooled resources exist for Chaos Dwarf factions only, so the same service
-- has to pay a different currency depending on who bought it.
--
-- AND THE BUYER IS THE PLAYER, because the scope is the player's culture: an Empire
-- faction only ever reaches this till in an Empire campaign, and GG.can_buy refuses it
-- outright otherwise. Set here rather than assumed, since the rest of this file plays a
-- Chaos Dwarf.
local tithe_getter = cm.get_human_factions
CULTURE["cr_human"] = "wh_main_emp_empire"
cm.get_human_factions = function() return {"cr_human"} end
GG.player_cultures_cache = nil
GG.CULTURE_OF["cr_human"] = "wh_main_emp_empire"
GG.state["cr_human"] = nil
GG.grant("cr_human", "slavers", 400)
GG.buy("cr_human", "slave_tithe")
assert(#pooled == 2, "no pooled grant for a non-CHD culture, got " .. #pooled)
assert(#gold == g0 + 2, "non-CHD slave tithe pays gold instead, got " .. (#gold - g0))
cm.get_human_factions = tithe_getter
GG.player_cultures_cache = nil

-- The hostile service targets the enemy, not the buyer.
GG.state["cr_khan"] = nil
GG.grant("cr_khan", "khanate", 1500)
GG.buy("cr_khan", "khans_price", "cr_victim")
assert(applied[#applied][2] == "cr_victim",
       "khans price must land on the target, got " .. tostring(applied[#applied][2]))

-- A targeted service with no target must not fire blind.
-- BOTH ARE CHAOS DWARFS. Every culture in the campaign runs guilds now, but only the
-- flavoured ones have a regiment mapped - GG.can_buy refuses the hire outright for any
-- other, rather than handing an Araby army a Chaos Dwarf Infernal Guard.
GG.CULTURE_OF["cr_notarget"] = GG.CHD_CULTURE
GG.CULTURE_OF["cr_target"] = GG.CHD_CULTURE
GG.state["cr_notarget"] = nil
GG.grant("cr_notarget", "immortals", 400)
local u_before = #units
GG.buy("cr_notarget", "hire_immortals", nil)
assert(#units == u_before, "no target means no unit granted")

-- With a target it grants the verified unit key.
GG.state["cr_target"] = nil
GG.grant("cr_target", "immortals", 400)
GG.buy("cr_target", "hire_immortals", 42)
assert(#units == u_before + 1, "unit granted with a target")
assert(units[#units][1] == 42, "granted to the given cqi")
assert(units[#units][2] == "wh3_dlc23_chd_inf_infernal_guard_great_weapons",
       "wrong unit key: " .. tostring(units[#units][2]))

-- The building service needs BOTH a slot and a building key, or it does nothing.
-- ITS OWN FACTION KEY, not "cr_build". GG.buy now writes the purchase to the save
-- before it fires the payload, so a key reused by a later block arrives there carrying
-- this block's standing - and the BuildingCompleted block down at cr_build opens its
-- handler with GG.load, which restored it and moved four guilds nothing had granted.
GG.state["cr_build_half"] = nil
GG.grant("cr_build_half", "overseers", 400)
local b_before = #built
GG.buy("cr_build_half", "raise_ziggurat", {slot = "slot_obj"})   -- no building key
assert(#built == b_before, "a half-specified target must not fire")
GG.state["cr_build2"] = nil
GG.grant("cr_build2", "overseers", 400)
GG.buy("cr_build2", "raise_ziggurat", {slot = "slot_obj", building = "bkey"})
assert(#built == b_before + 1, "slot plus building key fires")
assert(built[#built][2] == "bkey", "building key passed through")

-- ---------------------------------------------------- plan 3, task 1 battle ---
-- Attribution: only the winner is paid.
GG.state["cr_win"] = nil
GG.state["cr_lose"] = nil
GG.reset_turn("cr_win")
GG.reset_turn("cr_lose")
GG.battle_award("cr_win", false)
assert(select(1, GG.get("cr_win", "immortals")) == 15, "winner paid 15")
assert(select(1, GG.get("cr_lose", "immortals")) == 0, "loser paid nothing")

-- Outnumbered doubles it.
GG.reset_turn("cr_win2")
GG.battle_award("cr_win2", true)
assert(select(1, GG.get("cr_win2", "immortals")) == 30, "outnumbered win is 30")

-- A nil winner is a no-op, not an error.
GG.battle_award(nil, false)

-- ------------------------------------------------------ plan 3, tasks 2-3 ----
cm.random_number = function(_, n) return math.random(n) end
cm.get_human_factions = function() return {THE_PLAYER} end
cm.show_message_event = function() end
cm.model = function() return nil end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua")

-- The three cut services are never chosen, however rich the faction is.
GG.state["cr_ai"] = nil
GG.cooldowns["cr_ai"] = nil
for _, g in ipairs(GG.GUILDS) do GG.grant("cr_ai", g, 5000) end
local picked = {}
for _ = 1, 300 do
    local k = GGAI.choose("cr_ai")
    if k then picked[k] = true end
end
assert(not picked["hobgoblin_eyes"], "AI must not buy hobgoblin_eyes")
assert(not picked["bound_blueprint"], "AI must not buy bound_blueprint")
assert(not picked["raise_ziggurat"], "AI must not buy raise_ziggurat")
local nkinds = 0
for _ in pairs(picked) do nkinds = nkinds + 1 end
assert(nkinds >= 10, "AI should reach most of the 15 over 300 rolls, got " .. nkinds)

-- One purchase per faction per turn, hard cap.
GGAI.reset_turn()
GG.state["cr_ai2"] = nil
GG.cooldowns["cr_ai2"] = nil
for _, g in ipairs(GG.GUILDS) do GG.grant("cr_ai2", g, 5000) end
GGAI.step("cr_ai2"); GGAI.step("cr_ai2"); GGAI.step("cr_ai2")
local spent = 0
for _, g in ipairs(GG.GUILDS) do
    local _, fv = GG.get("cr_ai2", g)
    spent = spent + (GG.RANKS[GG.rank_of(select(1, GG.get("cr_ai2", g)))] * 2 - fv)
end
assert(spent <= 400, "at most one purchase a turn, spent " .. spent)

-- A poor faction buys nothing and does not error.
GG.state["cr_broke"] = nil
assert(GGAI.choose("cr_broke") == nil, "poor faction picks nothing")
GGAI.step("cr_broke")

-- A garrison is never picked. military_force_list counts garrisons.
GGAI.TEST_FORCES = {{armed_citizenry = true, cqi = 1},
                    {armed_citizenry = false, cqi = 2}}
assert(GGAI.pick_army("cr_pick") == 2, "must skip the garrison, got "
       .. tostring(GGAI.pick_army("cr_pick")))

-- No field army at all is nil, not an error.
GGAI.TEST_FORCES = {{armed_citizenry = true, cqi = 1}}
assert(GGAI.pick_army("cr_pick") == nil, "garrison-only faction has no target")

-- An enemy is picked only from factions at war.
GGAI.TEST_WARS = {"cr_enemy"}
assert(GGAI.pick_enemy("cr_pick") == "cr_enemy", "picks a war target")
GGAI.TEST_WARS = {}
assert(GGAI.pick_enemy("cr_pick") == nil, "no war, no target")

-- A hostile service with nobody to hit is skipped, not fired at the buyer.
GGAI.reset_turn()
GGAI.TEST_WARS = {}
GG.state["cr_nowar"] = nil
GG.cooldowns["cr_nowar"] = nil
GG.grant("cr_nowar", "khanate", 1500)
local ap = #applied
GGAI.step("cr_nowar")
for _, a in ipairs({applied[#applied]}) do
    if a and a[1] == "derpy_gg_svc_khans_price" then
        error("khans price fired with no enemy to hit")
    end
end

-- pick_target routes by kind, not by guess.
assert(GGAI.pick_target("cr_x", GG.service("writ_monopoly")) == nil,
       "a self-buff needs no target")
GGAI.TEST_FORCES = {{armed_citizenry = false, cqi = 9}}
assert(GGAI.pick_target("cr_x", GG.service("hire_immortals")) == 9,
       "the unit service targets an army")

-- ------------------------------------------------- plan 3, task 6 standings ---
-- Enough of a UI environment to load the panel file and exercise its pure logic.
-- No component exists, so every comp() lookup returns nil and every draw is a
-- no-op - which is exactly what makes leaders() testable in isolation.
core.get_ui_root = function() return nil end
find_uicomponent = function() return nil end
is_uicomponent = function() return false end
effect = {get_localised_string = function(k) return k end}
cm.get_local_faction_name = function() return "cr_me" end
UIComponent = function(x) return x end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua")

GG.state = {a = {brass = {rep = 500, fav = 0}}, b = {brass = {rep = 900, fav = 0}}}
-- BOTH IN ONE CULTURE, and the table is read AS a member of it. Leadership is per
-- culture now: a faction with no culture on record races in nothing, and GGUI.leaders
-- needs to know whose league it is drawing or it draws nobody's.
GG.CULTURE_OF["a"], GG.CULTURE_OF["b"] = GG.CHD_CULTURE, GG.CHD_CULTURE
local L = GGUI.leaders("a")
assert(#L == 6, "one leader row per guild, got " .. #L)
assert(L[1].guild == "brass", "first row is brass")
assert(L[1].faction_key == "b", "highest reputation leads, got "
       .. tostring(L[1].faction_key))
assert(L[1].rank == 4, "900 is favoured, got " .. L[1].rank)

-- A guild nobody has touched leads with nobody and rank 1, not an error.
assert(L[2].faction_key == nil, "an untouched guild has no leader")
assert(L[2].rank == 1, "an untouched guild is rank 1, got " .. L[2].rank)
assert(L[2].rep == 0, "an untouched guild reads 0")

-- leaders() returns KEYS. A display name here would mean a loc call in a handler.
assert(L[1].faction_key == "b", "leaders must return keys, not names")

-- refresh() with no panel present must return quietly, not throw.
GGUI.refresh()

-- --------------------------------------------------- plan 3, task 5 settings ---
-- The snapshot is written ONCE. MCT's own campaign gating is dead code, so this
-- is the only thing that actually freezes the economy for a save.
GG.TUNE = nil
saved["derpy_gg_tuned"] = nil
GG.snapshot_settings()
local first = GG.setting("cap_brass")
assert(first == 40, "default brass cap is 40, got " .. tostring(first))

-- A second call must read the save back, not re-read MCT.
GG.TUNE = nil
GG.snapshot_settings()
assert(GG.setting("cap_brass") == first,
       "snapshot must not re-read after the first turn")

-- A frozen value survives a round trip through the packed string, booleans too.
local packed = GG.pack_tune({cap_brass = 5, rate_brass = 111,
                             ai_spending = false, hostile_services = true})
local back = GG.unpack_tune(packed)
assert(back.cap_brass == 5, "cap round-trip, got " .. tostring(back.cap_brass))
assert(back.rate_brass == 111, "rate round-trip, got " .. tostring(back.rate_brass))
assert(back.ai_spending == false, "false must survive as false, got "
       .. tostring(back.ai_spending))
assert(back.hostile_services == true, "true must survive as true")

-- The hostile_services switch actually gates the one outward-facing service.
GG.TUNE = GG.unpack_tune(GG.pack_tune({hostile_services = false}))
GG.state["cr_gate"] = nil
GG.cooldowns["cr_gate"] = nil
GG.grant("cr_gate", "khanate", 1500)
local gok, gwhy = GG.can_buy("cr_gate", "khans_price")
assert(gok == false and gwhy == "disabled",
       "hostile_services off must refuse khans_price, got " .. tostring(gwhy))
-- and leaves every other service alone.
assert(GG.can_buy("cr_gate", "knife_in_dark") == true,
       "the switch must not touch the other services")

-- A tuned rate is actually used by accrual.
GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_khanate = 3, cap_khanate = 0}))
GG.reset_turn("cr_tuned")
GG.state["cr_tuned"] = nil
GG.on_agent_action("cr_tuned", true)
assert(select(1, GG.get("cr_tuned", "khanate")) == 3,
       "a tuned rate must be used, got " .. select(1, GG.get("cr_tuned", "khanate")))

-- THE RE-ASSERT. A faction whose state says rank 2 but which carries no bundle -
-- the exact shape of a mod added to a campaign in progress - must be healed on its
-- next turn start, because apply_rank only ever fires on a CHANGE and there is no
-- change left to detect. Measured live at turn 10: rep 120, rank 2, no bundle.
local a0, r0 = #applied, #removed
GG.state["cr_midcampaign"] = {
    brass        = {rep = 0,   fav = 0},
    immortals    = {rep = 0,   fav = 0},
    daemonsmiths = {rep = 120, fav = 0},
    khanate      = {rep = 0,   fav = 0},
    overseers    = {rep = 0,   fav = 0},
    slavers      = {rep = 0,   fav = 0},
}
GG.asserted["cr_midcampaign"] = nil          -- as it is on a fresh load
GG.assert_ranks("cr_midcampaign")
local got
for i = a0 + 1, #applied do
    if applied[i][1] == "derpy_gg_rank_daemonsmiths_2" then got = applied[i] end
end
assert(got, "re-assert must apply the rank 2 daemonsmiths bundle")
assert(got[2] == "cr_midcampaign", "applied to the wrong faction: " .. tostring(got[2]))
assert(got[3] == -1, "the re-asserted bundle must be indefinite, got " .. tostring(got[3]))

-- Rank 1 guilds must not be given a bundle: there is no rank 1 bundle to give.
for i = a0 + 1, #applied do
    assert(not string.find(applied[i][1], "_1$"),
           "rank 1 has no bundle: " .. applied[i][1])
end

-- And the other rungs of that guild are cleared, so a faction cannot hold two.
local cleared = false
for i = r0 + 1, #removed do
    if removed[i][1] == "derpy_gg_rank_daemonsmiths_3" then cleared = true end
end
assert(cleared, "the other rungs of the guild must be removed")

-- Idempotent: a second call in the same session must do nothing at all.
local a1 = #applied
GG.assert_ranks("cr_midcampaign")
assert(#applied == a1, "re-assert must be idempotent within a session, applied "
       .. (#applied - a1) .. " more")

-- ------------------------------------------------------- missions pay all six --
-- The only signal that is not one guild's own business, and the floor under the
-- other six: measured on a naval horde at turn 10, three guilds were still on 0
-- because that faction runs no agents, builds nothing and had sacked nothing.
local MF = "cr_missions"
GG.state[MF] = nil
GG.turn_gain[MF] = nil
GG.on_mission(MF)
for i = 1, #GG.GUILDS do
    local g = GG.state[MF][GG.GUILDS[i]]
    assert(g and g.rep > 0,
           "a mission must pay every guild; " .. GG.GUILDS[i] .. " got nothing")
end
-- EVERY guild, not merely most: this is the whole point of the signal.
local paid = 0
for i = 1, #GG.GUILDS do
    if GG.state[MF][GG.GUILDS[i]].rep > 0 then paid = paid + 1 end
end
assert(paid == #GG.GUILDS, "missions paid " .. paid .. " of " .. #GG.GUILDS)

-- It goes through capped_grant, so a guild's own per-turn cap still binds it and
-- missions cannot be used to outrun one.
local CF = "cr_missions_cap"
GG.state[CF] = nil
GG.turn_gain[CF] = nil
local cap = GG.setting("cap_brass") or GG.CAP["brass"] or 0
if cap > 0 then
    for _ = 1, 200 do GG.on_mission(CF) end
    assert(GG.state[CF]["brass"].rep <= cap,
           "missions outran the per-turn cap: " .. GG.state[CF]["brass"].rep
           .. " > " .. cap)
end

-- A rate of 0 is the off switch the MCT slider offers, and it must pay nothing.
local ZF = "cr_missions_off"
GG.state[ZF] = nil
GG.turn_gain[ZF] = nil
-- GG.TUNE, not a table called settings: GG.setting reads GG.TUNE and falls back to
-- GG.TUNE_DEFAULTS. Written against the wrong name this test passed by skipping.
GG.TUNE = GG.TUNE or {}
local prev = GG.TUNE.rate_missions
GG.TUNE.rate_missions = 0
GG.on_mission(ZF)
assert(GG.setting("rate_missions") == 0, "the harness failed to set the rate to 0")
assert(GG.state[ZF] == nil or GG.state[ZF]["brass"].rep == 0,
       "rate_missions = 0 must pay nothing")
GG.TUNE.rate_missions = prev


-- --------------------------------------------- a hostile service needs a target --
-- `local who = (s.hostile and target) or faction` fell through to the BUYER when the
-- target was nil - and it was always nil, because the enemy picker was a stub. The mod's
-- one aggressive service cost 400 favour and applied its malus to the player.
local HF = "cr_hostile"
GG.TUNE = GG.TUNE or {}
GG.TUNE.hostile_services = true
GG.state[HF] = nil
GG.cooldowns[HF] = nil
GG.grant(HF, "khanate", 2000)
local before_fav = select(2, GG.get(HF, "khanate"))
local applied_before = #applied

local bought, bwhy = GG.buy(HF, "khans_price", nil)
assert(bought == false and bwhy == "target",
       "a hostile service with no target must be refused, got "
       .. tostring(bought) .. "/" .. tostring(bwhy))
assert(select(2, GG.get(HF, "khanate")) == before_fav,
       "a refused purchase must cost no favour")
assert(#applied == applied_before,
       "a refused purchase must apply no bundle, got " .. (#applied - applied_before))

-- With a target it lands on the TARGET, never on the buyer.
assert(GG.buy(HF, "khans_price", "cr_victim") == true, "a targeted purchase must succeed")
local last = applied[#applied]
assert(last[1] == "derpy_gg_svc_khans_price", "the wrong bundle was applied: " .. last[1])
assert(last[2] == "cr_victim",
       "the hostile bundle must land on the target, not " .. tostring(last[2]))
assert(last[2] ~= HF, "the hostile bundle landed on the buyer")

-- ------------------------------------------------ winning against the odds --
-- GG.was_outnumbered returned false unconditionally while the Immortals' description
-- promised "doubles when you win outnumbered". The engine's own verdict is
-- pending_battle:attacker_is_stronger().
local function CHAR(cqi)
    return {is_null_interface = function() return false end,
            command_queue_index = function() return cqi end}
end

local function BATTLE(me, attacker_cqi, secondary, attacker_stronger)
    local sec = {}
    for i = 1, #(secondary or {}) do sec[i] = CHAR(secondary[i]) end
    return {
        character = function() return CHAR(me) end,
        pending_battle = function()
            return {
                is_null_interface = function() return false end,
                has_attacker = function() return attacker_cqi ~= nil end,
                attacker = function() return CHAR(attacker_cqi) end,
                secondary_attackers = function() return LIST(sec) end,
                attacker_is_stronger = function() return attacker_stronger end,
            }
        end,
    }
end

-- An ATTACKER is outnumbered when the attacker was not the stronger side.
assert(GG.was_outnumbered(BATTLE(1, 1, {}, false)) == true,
       "an attacker who was weaker won against the odds")
assert(GG.was_outnumbered(BATTLE(1, 1, {}, true)) == false,
       "an attacker who was stronger did not")
-- A DEFENDER reads the same verdict the other way round.
assert(GG.was_outnumbered(BATTLE(2, 1, {}, true)) == true,
       "a defender facing the stronger side won against the odds")
assert(GG.was_outnumbered(BATTLE(2, 1, {}, false)) == false,
       "a defender who was the stronger side did not")
-- A SECONDARY attacker is still an attacker.
assert(GG.was_outnumbered(BATTLE(3, 1, {3}, false)) == true,
       "a secondary attacker counts as an attacker")
assert(GG.was_outnumbered(BATTLE(3, 1, {3}, true)) == false,
       "and reads the verdict the same way")
-- A context that cannot answer is not an error, and not a free double.
assert(GG.was_outnumbered({}) == false, "an unreadable battle must not double the award")

-- And the award actually doubles, which is the thing the description promises.
GG.state["cr_odds"] = nil
GG.reset_turn("cr_odds")
GG.on_battle("cr_odds", false)
local plain = select(1, GG.get("cr_odds", "immortals"))
GG.state["cr_odds"] = nil
GG.reset_turn("cr_odds")
GG.on_battle("cr_odds", true)
local doubled = select(1, GG.get("cr_odds", "immortals"))
assert(doubled == plain * 2,
       "winning outnumbered must pay double, got " .. doubled .. " against " .. plain)

-- --------------------------------- a service is priced off your standing --
-- 50/150/400 forever meant your relationship with a guild changed nothing about what it
-- charged you. Two terms now move it, both from state that already exists: your rank
-- above what the service requires takes a cut off, and the rival being ahead of the
-- guild puts it up.
local CF = "cr_costing"
GG.TUNE = GG.TUNE or {}
local prev_rivalry_rate = GG.TUNE.rate_rivalry
GG.TUNE.rate_rivalry = 0        -- isolate pricing from the rivalry DRAIN
GG.state[CF] = nil

-- forge_rite: daemonsmiths, rank 2, base 50. Its rival is the immortals.
local BASE = GG.service("forge_rite").cost

-- Exactly at the rank gate and no rival standing: the base price, unmodified.
GG.grant(CF, "daemonsmiths", 100)                -- rank 2
assert(GG.rank_of((GG.get(CF, "daemonsmiths"))) == 2, "setup: not rank 2")
local c, m = GG.service_cost(CF, "forge_rite")
assert(m == 0, "at the rank gate with no rival, the modifier must be 0, got " .. m)
assert(c == BASE, "the base price must be " .. BASE .. ", got " .. c)

-- LOYALTY: every rank above the requirement takes GG.FAVOUR_LOYALTY percent off.
-- TWO ranks above, not three: three hits the clamp, which the block below tests on its
-- own. A test that lands on a clamp cannot tell you the term underneath it is right.
GG.state[CF] = nil
GG.grant(CF, "daemonsmiths", 700)                -- rank 4
assert(GG.rank_of((GG.get(CF, "daemonsmiths"))) == 4, "setup: not rank 4")
local c4, m4 = GG.service_cost(CF, "forge_rite")
assert(m4 == -2 * GG.FAVOUR_LOYALTY,
       "two ranks above the gate should be " .. (-2 * GG.FAVOUR_LOYALTY)
       .. "%, got " .. m4)
assert(m4 > GG.FAVOUR_MIN_MOD, "this test must sit clear of the clamp to mean anything")
assert(c4 < BASE, "a Favoured member must pay less than the base, got " .. c4)

-- RIVALRY: the rival being AHEAD puts the price up. Being BEHIND is not a second
-- discount - the loyalty term already pays for your own standing, and counting it
-- twice would make a guild free.
GG.state[CF] = nil
GG.grant(CF, "daemonsmiths", 100)                -- rank 2
GG.grant(CF, "immortals", 1500)                  -- rank 5, three ahead
local cr, mr = GG.service_cost(CF, "forge_rite")
assert(mr == 3 * GG.FAVOUR_RIVALRY,
       "a rival three ranks ahead should be +" .. (3 * GG.FAVOUR_RIVALRY)
       .. "%, got " .. mr)
assert(cr > BASE, "courting the rival must cost more, got " .. cr)

-- A rival BEHIND you changes nothing on its own.
GG.state[CF] = nil
GG.grant(CF, "daemonsmiths", 100)                -- rank 2
GG.grant(CF, "immortals", 0)                     -- rank 1, behind
assert(select(2, GG.service_cost(CF, "forge_rite")) == 0,
       "a rival behind you is not a second discount")

-- THE CLAMPS ACTUALLY BIND, which is the point of testing them. Four ranks over a
-- gate of 2 reaches -36% and +40%, so a clamp set outside that could never fire - and
-- an unfireable guard is the exact fault this mod has now shipped three times.
assert(GG.FAVOUR_MIN_MOD > -3 * GG.FAVOUR_LOYALTY,
       "the discount clamp is outside the range the ranks can reach, so it never fires")
assert(GG.FAVOUR_MAX_MOD < 4 * GG.FAVOUR_RIVALRY,
       "the surcharge clamp is outside the range the ranks can reach")

GG.state[CF] = {daemonsmiths = {rep = 999999, fav = 0}, immortals = {rep = 0, fav = 0}}
assert(select(2, GG.service_cost(CF, "forge_rite")) == GG.FAVOUR_MIN_MOD,
       "the deepest discount must clamp to " .. GG.FAVOUR_MIN_MOD .. ", got "
       .. select(2, GG.service_cost(CF, "forge_rite")))
GG.state[CF] = {daemonsmiths = {rep = 0, fav = 0}, immortals = {rep = 999999, fav = 0}}
assert(select(2, GG.service_cost(CF, "forge_rite")) == GG.FAVOUR_MAX_MOD,
       "the steepest surcharge must clamp to " .. GG.FAVOUR_MAX_MOD .. ", got "
       .. select(2, GG.service_cost(CF, "forge_rite")))

-- And no service can be discounted to nothing. Asserted over EVERY service, because
-- the runtime has no floor - the invariant is that the cheapest base times the deepest
-- discount is still a real price.
for _, svc in ipairs(GG.SERVICES) do
    GG.state[CF] = {}
    GG.state[CF][svc.guild] = {rep = 999999, fav = 0}
    assert(GG.service_cost(CF, svc.key) >= 1,
           svc.key .. " can be discounted to nothing")
end

-- THE CARD AND THE TILL MUST AGREE. can_buy gates on the live price and GG.buy charges
-- it; if either had kept reading the static s.cost, a card would show one number and
-- the purchase would take another, which no offline check can see.
GG.state[CF] = nil
GG.cooldowns[CF] = nil
GG.grant(CF, "daemonsmiths", 1500)               -- rank 5, so the price is discounted
local want = GG.service_cost(CF, "forge_rite")
assert(want < BASE, "setup: the price should be discounted here")
GG.state[CF]["daemonsmiths"].fav = want          -- exactly enough, at the LIVE price
assert(GG.can_buy(CF, "forge_rite") == true,
       "can_buy must gate on the live price, not the base")
assert(GG.buy(CF, "forge_rite") == true, "the purchase must go through")
assert(select(2, GG.get(CF, "daemonsmiths")) == 0,
       "the till must charge exactly the price the card drew, left with "
       .. select(2, GG.get(CF, "daemonsmiths")))

-- One favour short of the live price is a refusal, not a rounding.
GG.state[CF] = nil
GG.cooldowns[CF] = nil
GG.grant(CF, "daemonsmiths", 1500)
GG.state[CF]["daemonsmiths"].fav = GG.service_cost(CF, "forge_rite") - 1
assert(select(2, GG.can_buy(CF, "forge_rite")) == "favour",
       "one short of the live price must be refused")

GG.TUNE.rate_rivalry = prev_rivalry_rate
GG.state[CF] = nil
GG.cooldowns[CF] = nil

-- ------------------------------------------ a bounty is priced off its target --
-- Every bounty of a kind used to pay the same: 3,000 for a region whether it was a
-- ruined hovel next door or an enemy capital behind a full stack.
local PF = "cr_pricing"
REGION_OWNER["hovel"] = "cr_foe"
REGION_OWNER["capital"] = "cr_foe"
REGION_WORTH["hovel"] = {1, false, false}
REGION_WORTH["capital"] = {8, true, true}

local easy = GG.bounty_difficulty("region_take", "hovel")
local hard = GG.bounty_difficulty("region_take", "capital")
assert(easy == 25, "a one-building hovel should score 25, got " .. easy)

-- The defended capital scores 8*25 + 40 + 35 = 275 and is CLAMPED. That is the test:
-- an unbounded score would let one lucky offer pay an arbitrary amount.
assert(hard == GG.BOUNTY_DIFF_MAX,
       "the difficulty ceiling must bind at " .. GG.BOUNTY_DIFF_MAX .. ", got " .. hard)

local g_easy, r_easy = GG.bounty_price("region_take", easy)
local g_hard, r_hard = GG.bounty_price("region_take", hard)
assert(g_easy == 3750, "the hovel should pay 3750 gold, got " .. g_easy)
assert(g_hard == 9000, "the capital should pay 9000 gold, got " .. g_hard)
assert(g_hard > g_easy * 2, "the hard target must pay more than twice the easy one")

-- REPUTATION SCALES AT HALF. It drives the rank ladder, whose thresholds are fixed, and
-- bounty reputation is the one grant that does not go through the per-turn cap.
assert(r_easy == 90, "the hovel should pay 90 reputation, got " .. r_easy)
assert(r_hard == 160, "the capital should pay 160 reputation, got " .. r_hard)
assert(r_hard * g_easy < r_easy * g_hard,
       "reputation must scale more slowly than gold")

-- A LORD is priced on rank, army and whether he leads his faction.
ALIVE_FM["501"] = true
ALIVE_FM["502"] = true
LORD_WORTH["501"] = {1, false, 2}                  -- a fresh general, two units
LORD_WORTH["502"] = {40, true, 20}                 -- a faction leader with a full stack
local fresh = GG.bounty_difficulty("lord_kill", "501")
local great = GG.bounty_difficulty("lord_kill", "502")
assert(fresh == 1 * 3 + 2 * 6, "a fresh lord should score 15, got " .. fresh)
assert(great == GG.BOUNTY_DIFF_MAX,
       "a rank-40 faction leader with a full stack should hit the ceiling, got " .. great)
assert(select(1, GG.bounty_price("lord_kill", great))
       > select(1, GG.bounty_price("lord_kill", fresh)) * 2,
       "a faction leader must be worth more than twice a fresh general")

-- AN UNREADABLE TARGET PRICES AT BASE, and is not a refusal: an offer that cannot be
-- priced is still a perfectly good offer, worth the minimum.
assert(GG.bounty_difficulty("lord_kill", "no_such_cqi") == 0,
       "an unreadable lord must price at base")
assert(GG.bounty_difficulty("region_take", "no_such_region") == 0,
       "an unreadable region must price at base")
assert(select(1, GG.bounty_price("region_take", 0)) == GG.BOUNTY_KINDS.region_take.gold,
       "a zero difficulty must pay exactly the base")

-- AN UNTAKEN OFFER RE-PRICES AS THE WORLD MOVES; a TAKEN one keeps its agreed price.
AT_WAR[PF] = {cr_foe = true}
GG.bounties[PF] = {
    {guild = "brass", kind = "region_take", target = "hovel", owner = "cr_foe",
     gold = 3750, rep = 90, diff = 25, posted = GG.turn_now(), taken = false},
    {guild = "overseers", kind = "region_take", target = "capital", owner = "cr_foe",
     gold = 3000, rep = 80, diff = 0, posted = GG.turn_now(), taken = true},
}
REGION_WORTH["hovel"] = {6, true, false}           -- they built it up
GG.purge_bounties(PF)
assert(GG.bounties[PF][1].gold > 3750,
       "an untaken offer must re-price as its target grows, got "
       .. GG.bounties[PF][1].gold)
assert(GG.bounties[PF][2].gold == 3000,
       "a TAKEN offer must keep the price it was taken at, got "
       .. GG.bounties[PF][2].gold)

-- And the score survives a save, while a save written before it existed still loads.
GG.save_bounties(PF)
GG.bounties[PF] = nil
GG.load_bounties(PF)
assert(GG.bounties[PF][1].diff > 25,
       "diff must survive a save, got " .. tostring(GG.bounties[PF][1].diff))
saved["derpy_gg_bounties_" .. PF] = "brass,region_take,hovel,cr_foe,3000,80,1,0"
GG.load_bounties(PF)
assert(#GG.bounties[PF] == 1 and GG.bounties[PF][1].diff == 0,
       "a save written before diff existed must still load, at base price")
GG.bounties[PF] = nil
AT_WAR[PF] = nil

-- --------------------------------------------------- guilds are rivals --
-- Six counters that only ever go up is a menu. Earning with one guild now costs
-- standing with the one across the table, which is what makes feeding a guild a choice.
local RV = "cr_rivals"
GG.state[RV] = nil
GG.reset_turn(RV)

-- The pairings are symmetric and total: every guild has exactly one rival, and its
-- rival's rival is itself. A half-declared pair would silently make rivalry one-way.
local seen = 0
for _, guild in ipairs(GG.GUILDS) do
    local r = GG.RIVALS[guild]
    assert(r, guild .. " has no rival")
    assert(r ~= guild, guild .. " is its own rival")
    assert(GG.RIVALS[r] == guild,
           guild .. "/" .. r .. " is a one-way rivalry")
    seen = seen + 1
end
assert(seen == #GG.GUILDS, "not every guild was checked")

-- Earning with the Slavers costs the Overseers 40% of the gain.
--
-- 150 AND NOT 100. Rivalry floors at the rank already reached, and 100 IS Indebted's
-- threshold - a fixture sitting exactly on it has no room to lose and measures the
-- floor rather than the 40%. The threshold case is asserted on its own below.
GG.grant(RV, "overseers", 150)
assert(select(1, GG.get(RV, "overseers")) == 150, "setup failed")
GG.grant(RV, "slavers", 50)
-- The slavers keep all 50: the overseers grant above cost them nothing, because a
-- rival already at zero has nothing to lose.
assert(select(1, GG.get(RV, "slavers")) == 50,
       "the slavers should hold 50, got " .. select(1, GG.get(RV, "slavers")))
assert(select(1, GG.get(RV, "overseers")) == 130,
       "the overseers should have lost 20, got "
       .. select(1, GG.get(RV, "overseers")))

-- AND A GUILD SITTING EXACTLY ON ITS THRESHOLD LOSES NOTHING. This is the rule that
-- stopped every AI rival reading as a column of zeros: brass is fed passively from
-- income every turn and its rival the khanate is not, so an unfloored 40% ground two
-- of the three pairs to nothing and pinned them there.
GG.state[RV] = nil
GG.grant(RV, "overseers", 100)
GG.grant(RV, "slavers", 50)
assert(select(1, GG.get(RV, "overseers")) == 100,
       "a guild on its rank threshold must lose nothing to rivalry, got "
       .. select(1, GG.get(RV, "overseers")))

-- FAVOUR IS UNTOUCHED. Reputation is standing, favour is the wallet already earned.
assert(select(2, GG.get(RV, "overseers")) == 100,
       "rivalry must not take favour, got " .. select(2, GG.get(RV, "overseers")))

-- A rival already at zero loses nothing, and never goes negative.
GG.state[RV] = nil
GG.grant(RV, "slavers", 500)
assert(select(1, GG.get(RV, "overseers")) == 0,
       "a rival at zero went to " .. select(1, GG.get(RV, "overseers")))

-- A RIVAL WITH LESS REPUTATION THAN THE LOSS IS NOT DRAINED AT ALL - it is Unmarked, and
-- since 2026-09-23 rivalry takes nothing below Indebted. This used to assert the clamp
-- (stop at 0, never at -30); the rank-1 rule now answers first, and it is also what makes
-- a negative unreachable from rivalry, since above rank 1 the floor is the threshold.
GG.state[RV] = nil
GG.grant(RV, "overseers", 10)
GG.grant(RV, "slavers", 100)
assert(select(1, GG.get(RV, "overseers")) == 10,
       "an Unmarked rival must lose nothing to rivalry, got "
       .. select(1, GG.get(RV, "overseers")))

-- A small gain still costs the floor of 1 rather than rounding to free.
-- 150, off the Indebted threshold, or the rank floor answers this instead of the
-- floor-of-1 does and the assertion stops being able to fail.
GG.state[RV] = nil
GG.grant(RV, "overseers", 150)
GG.grant(RV, "slavers", 1)
assert(select(1, GG.get(RV, "overseers")) == 149,
       "a 1-point gain must still cost 1, got " .. select(1, GG.get(RV, "overseers")))

-- rate_rivalry = 0 switches it off entirely.
GG.TUNE = GG.TUNE or {}
local prev_rival = GG.TUNE.rate_rivalry
GG.TUNE.rate_rivalry = 0
GG.state[RV] = nil
-- 150 for the same reason as above: on a rank threshold the floor would return this
-- guild untouched whether rate_rivalry were 0 or 40, and the switch would go untested.
GG.grant(RV, "overseers", 150)
GG.grant(RV, "slavers", 100)
assert(select(1, GG.get(RV, "overseers")) == 150,
       "rate_rivalry = 0 must cost nothing, got " .. select(1, GG.get(RV, "overseers")))
GG.TUNE.rate_rivalry = prev_rival

-- A RANK CANNOT FALL THROUGH RIVALRY - AND CAN STILL FALL THROUGH UPKEEP, with the
-- ladder bundle coming off when it does.
--
-- These were one test and are now two, because the two losses stopped meaning the same
-- thing. Rivalry floors at the rank already reached: it is fed by whatever the other
-- guild earns, and brass earns passively from income every turn, so an unfloored
-- rivalry was a one-way ratchet that pinned two of the three pairs on zero for every AI
-- in the world. Upkeep is the clock and demoting is its entire purpose, so it is NOT
-- floored - and the bundle-removal path is asserted through it, where it still runs.
do
    GG.state[RV] = nil
    GG.grant(RV, "overseers", 320)          -- rank 3 at 300
    assert(GG.rank_of(select(1, GG.get(RV, "overseers"))) == 3, "setup: not rank 3")

    -- RIVALRY TAKES IT TO THE THRESHOLD AND STOPS. 100 earned by the slavers is a 40
    -- loss unfloored, which would land on 280 and cost the rank.
    GG.grant(RV, "slavers", 100)
    assert(select(1, GG.get(RV, "overseers")) == 300,
           "rivalry must stop at the rank threshold, got "
           .. select(1, GG.get(RV, "overseers")))
    assert(GG.rank_of(select(1, GG.get(RV, "overseers"))) == 3,
           "and the rank must survive it")

    -- UPKEEP TAKES IT THROUGH. One turn at rank 3 is 3 points at the default rate,
    -- which is all it takes from a threshold.
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_decay = 100, decay_from = 25}))
    RM_BEFORE_DEMOTE = #removed
    GG.decay(RV, 30)
    assert(GG.rank_of(select(1, GG.get(RV, "overseers"))) == 2,
           "upkeep must still demote, got rep "
           .. select(1, GG.get(RV, "overseers")))
    DEMOTE_DROPPED = false
    for i = RM_BEFORE_DEMOTE + 1, #removed do
        if removed[i][1] == "derpy_gg_rank_overseers_3" then DEMOTE_DROPPED = true end
    end
    assert(DEMOTE_DROPPED, "a demotion left the higher rank's bundle applied")
end

-- AND THE INVARIANT THE ORDER PROTECTS, rather than the name of whichever key was last
-- when this was written. unpack_tune walks TUNE_ORDER positionally against a packed
-- string held in the save, so a save written before a key existed carries fewer fields
-- than the list has - and every one of those missing fields must land on its default.
-- Asserted against a string one field SHORT of every length, which is what every older
-- save looks like.
do
    local full = GG.pack_tune(GG.TUNE_DEFAULTS)
    local fields = {}
    for chunk in string.gmatch(full, "[^|]+") do fields[#fields + 1] = chunk end
    assert(#fields == #GG.TUNE_ORDER,
           "pack_tune must write one field per key, got " .. #fields
           .. " for " .. #GG.TUNE_ORDER .. " keys")
    for cut = 1, #GG.TUNE_ORDER - 1 do
        local short = table.concat(fields, "|", 1, cut)
        local got = GG.unpack_tune(short)
        for i = cut + 1, #GG.TUNE_ORDER do
            local key = GG.TUNE_ORDER[i]
            assert(got[key] == GG.TUNE_DEFAULTS[key],
                   "a save holding " .. cut .. " fields must leave " .. key
                   .. " on its default, got " .. tostring(got[key]))
        end
    end
end

GG.state[RV] = nil

-- ------------------------------- only the PLAYER's culture earns, and it is read --
-- Every listener in this mod is registered for ALL factions, so without a rule the
-- entire map accrued standing with six Chaos Dwarf guilds - and a Lizardmen faction
-- duly turned up leading the Brass Tablets in a live campaign.
--
-- TWO WRONG FIXES CAME BEFORE THIS ONE, in opposite directions. A hardcoded list of
-- three culture keys stopped the Lizardmen by stopping everyone outside Chaos Dwarfs,
-- Dwarfs and the Empire - which in a modded install is most of the map, and silently:
-- an excluded culture does not error, it just never accrues anything, forever. Opening
-- it to EVERY culture in the campaign then let the Empire and the Lizardmen quietly run
-- their own copies of six Chaos Dwarf guilds.
--
-- THE SCOPE IS THE PLAYER AND THE LOOKUP IS DYNAMIC, which are two different things.
-- The culture is read off the human faction, so this file names no culture at all: a
-- Chaos Dwarf campaign races Chaos Dwarfs, and a campaign whose player belongs to a
-- culture some mod invented races that. The pair of assertions below is the whole of it
-- - the same faction is covered or not depending only on who is at the keyboard.
local LZD = "cr_lizards"
CULTURE[LZD] = "wh2_main_lzd_lizardmen"
GG.CULTURE_OF[LZD] = nil
GG.state[LZD] = nil
GG.reset_turn(LZD)
assert(GG.covered(LZD) == false,
       "a Lizardmen faction is covered in a Chaos Dwarf campaign - this is the faction "
       .. "that turned up leading the Brass Tablets")
GG.capped_grant(LZD, "brass", 500)
assert(select(1, GG.get(LZD, "brass")) == 0,
       "and it earned " .. select(1, GG.get(LZD, "brass")) .. " anyway")

-- A Chaos Dwarf faction earns, or the rule has eaten the mod.
local CHD = "cr_dawi_zharr"
GG.CULTURE_OF[CHD] = nil
GG.state[CHD] = nil
GG.reset_turn(CHD)
assert(GG.covered(CHD) == true, "a Chaos Dwarf faction must be covered")
GG.capped_grant(CHD, "brass", 500)
assert(select(1, GG.get(CHD, "brass")) > 0, "a covered culture earned nothing")

-- NOW PUT A LIZARDMAN AT THE KEYBOARD. Nothing else changes - no list is edited, no
-- culture key appears anywhere in the mod - and coverage swaps over completely. This is
-- the assertion that separates "the player's culture" from "a hardcoded list that
-- happens to contain the player's culture", and a hardcoded list passes every other
-- assertion in this block.
local prev_getter = cm.get_human_factions
local LZD_PLAYER = "cr_lizard_player"
CULTURE[LZD_PLAYER] = "wh2_main_lzd_lizardmen"
GG.CULTURE_OF[LZD_PLAYER] = nil
cm.get_human_factions = function() return {LZD_PLAYER} end
GG.player_cultures_cache = nil
assert(GG.covered(LZD) == true,
       "with a Lizardman at the keyboard a Lizardmen faction must be covered - if it is "
       .. "not, the scope is still a list and no mod-added culture will ever play")
assert(GG.covered(CHD) == false,
       "and the Chaos Dwarfs must drop out, because it is not their campaign")
GG.state[LZD] = nil
GG.reset_turn(LZD)
GG.capped_grant(LZD, "brass", 500)
assert(select(1, GG.get(LZD, "brass")) > 0,
       "a Lizardmen faction must earn in a Lizardmen campaign")

-- A CULTURE NO MOD IN THIS GAME HAS IS STILL FINE. The scope never needs to know the
-- key, which is the whole point: a culture invented tomorrow works the same way.
local INVENTED = "cr_invented"
CULTURE[INVENTED] = "some_culture_that_ships_next_year"
GG.CULTURE_OF[INVENTED] = nil
assert(GG.covered(INVENTED) == false, "not this campaign's culture")
cm.get_human_factions = function() return {INVENTED} end
GG.player_cultures_cache = nil
GG.CULTURE_OF[INVENTED] = nil
assert(GG.covered(INVENTED) == true,
       "a culture this mod has never heard of must work the moment somebody plays it")

-- AN UNREADABLE PLAYER COVERS NOBODY NEW. get_human_factions is not answerable during
-- loading, and the two possible fallbacks are not equally bad: covering everyone writes
-- standing into the save for factions that should never have had it and that persists,
-- while covering nobody costs one turn of earning and self-corrects. A faction that is
-- ALREADY holding standing keeps earning, so a save mid-campaign does not stall.
cm.get_human_factions = function() return {} end
GG.player_cultures_cache = nil
local FRESH = "cr_no_player_fresh"
CULTURE[FRESH] = "wh2_main_lzd_lizardmen"
GG.CULTURE_OF[FRESH] = nil
GG.state[FRESH] = nil
assert(GG.covered(FRESH) == false,
       "with no readable player, a faction holding nothing must not start earning - "
       .. "standing granted wrongly stays in the save, a missed turn does not")
assert(GG.covered(LZD) == true,
       "but a faction already holding standing must keep earning, or one unreadable "
       .. "turn stalls the whole campaign")

-- AND THE TILL REFUSES IT TOO, not just the earning. Stopping a faction earning does
-- nothing about the standing a faction ALREADY HAS: a save written under the build that
-- let every culture race still has their rows in it, and those factions would go on
-- spending a balance they should never have had. GGAI buys on behalf of the AI, so it
-- would happen every turn with nobody watching.
--
-- The lead services were already safe, because GG.leader_of answers nil for a culture
-- that is not in the race. The other twelve were not.
cm.get_human_factions = prev_getter
GG.player_cultures_cache = nil
do
    local STALE = "cr_stale_save_empire"
    CULTURE[STALE] = "wh_main_emp_empire"
    GG.CULTURE_OF[STALE] = nil
    GG.state[STALE] = nil
    GG.grant(STALE, "brass", 99999)     -- what the old build wrote into the save
    GG.cooldowns[STALE] = {}
    assert(GG.covered(STALE) == false, "setup: this faction is not in the race")
    local sok, swhy = GG.can_buy(STALE, "caravan_levy")
    assert(sok == false and swhy == "scope",
           "a faction outside the race was sold a service on standing a previous build "
           .. "gave it, got " .. tostring(sok) .. "/" .. tostring(swhy))
    local gmark = #gold
    GG.buy(STALE, "caravan_levy")
    assert(#gold == gmark,
           "and the payload fired anyway - the refusal has to be at the till, because "
           .. "the AI buyer never reads a panel")
    GG.state[STALE] = nil
    GG.CULTURE_OF[STALE] = nil
end

cm.get_human_factions = prev_getter
GG.player_cultures_cache = nil
GG.state[LZD] = nil
GG.state[INVENTED] = nil
GG.CULTURE_OF[LZD] = nil
GG.CULTURE_OF[CHD] = nil
GG.state[CHD] = nil
GG.reset_turn(CHD)
GG.capped_grant(CHD, "brass", 500)
assert(select(1, GG.get(CHD, "brass")) > 0,
       "and the Chaos Dwarfs come back when the Chaos Dwarf player does")
assert(GG.hire_unit(CHD) == GG.HIRE_UNIT_BY_CULTURE[GG.CHD_CULTURE],
       "a flavoured culture must still get its own regiment")

-- AN UNREADABLE CULTURE IS NOT COVERED. The old code defaulted the unknown case to
-- Chaos Dwarf, which is how the whole world qualified.
local MUTE = "cr_no_such_faction"
GG.CULTURE_OF[MUTE] = nil
local real_get = cm.get_faction
cm.get_faction = function(_, k)
    if k == MUTE then return false end      -- what cm:get_faction really returns
    return real_get(nil, k)
end
assert(GG.covered(MUTE) == false, "an unreadable culture must not be covered")
cm.get_faction = real_get

-- And the leaderboard skips an uncovered faction even when the save already holds one,
-- which every save made before this gate does.
GG.state[LZD] = {brass = {rep = 99999, fav = 0}}
GG.CULTURE_OF[LZD] = "wh2_main_lzd_lizardmen"
local who = GG.leader_of("brass", GG.CHD_CULTURE)
assert(who ~= LZD, "the standings still lead with an uncovered faction")
GG.state[LZD] = nil

-- ------------------------------------------------------------- who leads a guild --
-- The league table crowned the player on every guild at 0 reputation: the old search
-- started from -1, so the first faction pairs() yielded won, and in a young campaign
-- that is the only faction in GG.state.
-- EVERY FACTION HERE IS A CHAOS DWARF, and the question is always asked of that
-- culture. GG.leader_of used to answer world-wide and a Chaos Dwarf campaign found The
-- Golden Order at the head of the Daemonsmiths - so the culture is now part of the
-- question, and a faction with none on record races in nothing.
local CHD = GG.CHD_CULTURE
for _, f in ipairs({"cr_zero_a", "cr_zero_b", "cr_led_a", "cr_led_b",
                    "cr_tie_a", "cr_tie_m", "cr_tie_z"}) do
    GG.CULTURE_OF[f] = CHD
end

GG.state = {}
local who, wrep = GG.leader_of("brass", CHD)
assert(who == nil and wrep == 0,
       "nobody leads a guild nobody has standing with, got leader=" .. tostring(who)
       .. " rep=" .. tostring(wrep))

GG.state["cr_zero_a"] = {brass = {rep = 0, fav = 0}}
GG.state["cr_zero_b"] = {brass = {rep = 0, fav = 0}}
assert(GG.leader_of("brass", CHD) == nil,
       "reputation 0 must not crown anyone, got "
       .. tostring(GG.leader_of("brass", CHD)))

GG.state["cr_led_b"] = {brass = {rep = 40, fav = 0}}
GG.state["cr_led_a"] = {brass = {rep = 90, fav = 0}}
who, wrep = GG.leader_of("brass", CHD)
assert(who == "cr_led_a" and wrep == 90,
       "the highest reputation leads, got " .. tostring(who) .. "/" .. tostring(wrep))

-- A FOREIGN CULTURE CANNOT TAKE A CHAOS DWARF GUILD, however far ahead it is. This is
-- the screenshot that started it: The Golden Order leading the Daemonsmiths and Clan
-- Angrund leading the Khanate in a Chaos Dwarf campaign.
--
-- TWO RULES HAVE TO BOTH HOLD FOR THAT, and the reputation here is deliberately absurd
-- so a break in either one shows up. The Empire faction is not in this campaign's race
-- at all, because the race is the player's culture - and even if a save from an older
-- build has already written standing for it, leadership is asked per culture, so it
-- cannot be the answer to a question about Chaos Dwarf guilds.
GG.CULTURE_OF["cr_empire"] = "wh_main_emp_empire"
GG.state["cr_empire"] = {brass = {rep = 100000, fav = 0}}
assert(GG.leader_of("brass", CHD) == "cr_led_a",
       "an Empire faction with a hundred thousand reputation took a Chaos Dwarf "
       .. "guild - and that is the screenshot, exactly")
-- AND IT LEADS NOTHING OF ITS OWN EITHER, because a Chaos Dwarf is at the keyboard. The
-- standing in GG.state is a leftover from the build that let every culture race; the
-- leadership sweep needs leader_of to answer nil here so the stale bundle comes back off
-- rather than sitting on a faction nobody can see.
assert(GG.leader_of("brass", "wh_main_emp_empire") == nil,
       "an Empire faction leads an Empire guild in a Chaos Dwarf campaign - the scope "
       .. "is the player's culture, and this is a leftover row in the save")
-- ASKED OF NO CULTURE, NOBODY LEADS. Guessing a default is how a faction ends up
-- holding a seat in a race it is not running in.
assert(GG.leader_of("brass") == nil,
       "a guild with no culture named has no leader")
assert(GG.leader_of("brass", "wh2_main_lzd_lizardmen") == nil,
       "and an uncovered culture has no guilds at all")
GG.state["cr_empire"] = nil
GG.CULTURE_OF["cr_empire"] = nil

-- A TIE MUST NOT DEPEND ON pairs() ORDER, which is not stable between runs - the panel
-- would name a different faction on different draws of the same state.
GG.state = {}
GG.state["cr_tie_z"] = {brass = {rep = 50, fav = 0}}
GG.state["cr_tie_a"] = {brass = {rep = 50, fav = 0}}
GG.state["cr_tie_m"] = {brass = {rep = 50, fav = 0}}
local first = GG.leader_of("brass", CHD)
assert(first == "cr_tie_a", "a tie must resolve by name, got " .. tostring(first))
for _ = 1, 20 do
    assert(GG.leader_of("brass", CHD) == first,
           "a tie must resolve the same way every call")
end
GG.state = {}

-- AN OLD SAVE MUST STILL LOAD. The settings string is positional, so every new key
-- goes on the END of GG.TUNE_ORDER: a save written before rate_missions and rate_bounty
-- existed carries 14 fields, and those two must come back on their defaults rather than
-- shifting every later value onto the wrong setting.
local fourteen = "250|15|60|8|10|25|40|60|0|40|40|80|1|1"
local old_tune = GG.unpack_tune(fourteen)
assert(old_tune.rate_brass == 250,
       "an old save must keep its own values, got " .. tostring(old_tune.rate_brass))
assert(old_tune.hostile_services == true,
       "a boolean must survive, got " .. tostring(old_tune.hostile_services))
assert(old_tune.rate_missions == GG.TUNE_DEFAULTS.rate_missions,
       "rate_missions must default on an old save, got " .. tostring(old_tune.rate_missions))
assert(old_tune.rate_bounty == GG.TUNE_DEFAULTS.rate_bounty,
       "rate_bounty must default on an old save, got " .. tostring(old_tune.rate_bounty))
local fields = 0
for _ in string.gmatch(GG.pack_tune(old_tune), "[^|]+") do fields = fields + 1 end
assert(fields == #GG.TUNE_ORDER,
       "re-packing that table wrote " .. fields .. " fields for " .. #GG.TUNE_ORDER .. " keys")

-- --------------------------------------------------------- the bounty board --
-- CA's own mechanic, cloned: offers on a board, taken by choice, paid on success.
local BF = "cr_bounty"
GG.TUNE = GG.TUNE or {}
GG.TUNE.rate_bounty = 80

-- THE AI SECTION ABOVE REPLACED BOTH OF THESE. It makes cm:model() return nil, to
-- prove the AI guards a missing model, and swaps the deterministic roll for a real
-- random. The board needs a real turn number - without one every offer is posted on
-- turn 0 and nothing ever expires - and a fixed roll, so the assertions can name which
-- guilds are on the board.
cm.model = function() return {turn_number = function() return TURN end} end
cm.random_number = function(_, _n) return 1 end
assert(GG.turn_now() == TURN, "the harness cannot read a turn number")

-- AT PEACE, NOTHING IS POSTED. A guild's bounty always names a faction you already
-- fight, so an empty war list must leave an empty board rather than erroring.
WARS[BF] = {}
GG.bounties[BF] = nil
GG.post_bounties(BF)
assert(#(GG.bounties[BF] or {}) == 0,
       "a faction at peace must be offered nothing, got "
       .. #(GG.bounties[BF] or {}))

-- One enemy with two regions and one general is enough for every kind.
WARS[BF] = {ENEMY("cr_foe", {"foe_region_a", "foe_region_b"}, {4242})}
GG.post_bounties(BF)
local board = GG.bounties[BF]
assert(#board == GG.BOUNTY_SLOTS,
       "the board holds " .. GG.BOUNTY_SLOTS .. " offers, got " .. #board)

-- One offer per guild: two live bounties on one key would fight over it.
local seen = {}
for i = 1, #board do
    assert(not seen[board[i].guild], "two offers for " .. board[i].guild)
    seen[board[i].guild] = true
    assert(GG.BOUNTY_KINDS[board[i].kind], "offer has no known kind")
    assert(board[i].target and board[i].target ~= "", "offer has no target")
    assert(board[i].owner == "cr_foe", "offer must name the owning faction, got "
           .. tostring(board[i].owner))
    assert(board[i].rep == 80, "offer pays rate_bounty, got " .. tostring(board[i].rep))
end

-- A second call on the same turn must not overfill or duplicate.
GG.post_bounties(BF)
assert(#GG.bounties[BF] == GG.BOUNTY_SLOTS, "re-posting must not grow the board")

-- NO TWO GUILDS POST THE SAME TARGET. Both lord_kill guilds used to walk to the first
-- general they found and stop, so the Immortals and the Khanate named the same
-- character: take one and the other still offered an objective already in hand.
local targets = {}
for i = 1, #board do
    assert(not targets[board[i].target],
           "two guilds posted the same target: " .. tostring(board[i].target))
    targets[board[i].target] = true
end


-- TAKING ONE ISSUES EXACTLY ONE MISSION, and the string is the objective the game
-- evaluates - the DB row's mission_type column is not.
local slot = 1
local o = board[slot]
local kind = GG.BOUNTY_KINDS[o.kind]
assert(GG.take_bounty(BF, slot) == true, "taking an offer must succeed")
assert(#issued == 1, "one mission issued, got " .. #issued)
assert(issued[1][1] == BF, "issued to the wrong faction")
local str = issued[1][2]
assert(string.find(str, "key " .. GG.bounty_mission_key(o.guild), 1, true),
       "mission string names the wrong key: " .. str)
assert(string.find(str, "type " .. kind.otype, 1, true),
       "mission string carries the wrong objective type: " .. str)
assert(string.find(str, o.target, 1, true), "mission string has no target: " .. str)
assert(string.find(str, "money " .. kind.gold, 1, true),
       "mission string does not pay its gold: " .. str)
assert(string.find(str, "turn_limit " .. GG.BOUNTY_TURN_LIMIT, 1, true),
       "mission string has no turn limit: " .. str)
assert(board[slot].taken == true, "the offer must be marked taken")

-- And it cannot be taken twice.
assert(GG.take_bounty(BF, slot) == false, "a taken offer must refuse a second take")
assert(#issued == 1, "a second take must not issue a second mission")

-- SUCCESS PAYS THAT GUILD, UNCAPPED. brass is capped at 40 a turn; a bounty pays 80
-- and must not be clipped to the cap, or the board is lying about what it pays.
local paid_guild = o.guild
GG.state[BF] = nil
GG.turn_gain[BF] = nil
GG.reset_turn(BF)
local before = select(1, GG.get(BF, paid_guild))
assert(GG.bounty_done(BF, GG.bounty_mission_key(paid_guild)) == true,
       "a completed bounty must be recognised")
local after = select(1, GG.get(BF, paid_guild))
assert(after - before == 80,
       "a bounty pays its full reputation, got " .. (after - before))
-- and the offer leaves the board
assert(GG.bounty_for_guild(BF, paid_guild) == nil, "a paid bounty must clear its slot")

-- A BOUNTY IS NOT ALSO A GENERIC MISSION. This is the order the MissionSucceeded
-- handler uses; the blanket rate must not also fire, or five guilds get paid for work
-- they never asked for.
GG.state[BF] = nil
GG.turn_gain[BF] = nil
GG.post_bounties(BF)
local o2 = GG.bounties[BF][1]
GG.take_bounty(BF, 1)
GG.state[BF] = nil
GG.reset_turn(BF)
if not GG.bounty_done(BF, GG.bounty_mission_key(o2.guild)) then
    GG.on_mission(BF)
end
for i = 1, #GG.GUILDS do
    local g = GG.GUILDS[i]
    local r = select(1, GG.get(BF, g))
    if g == o2.guild then
        assert(r == 80, "the bounty's own guild must be paid, got " .. r)
    else
        assert(r == 0, g .. " was paid for a bounty it did not post, got " .. r)
    end
end

-- A FAILED OR CANCELLED BOUNTY FREES THE SLOT and costs nothing.
GG.state[BF] = nil
GG.bounties[BF] = nil
GG.post_bounties(BF)
local o3 = GG.bounties[BF][1]
GG.take_bounty(BF, 1)
assert(GG.bounty_lost(BF, GG.bounty_mission_key(o3.guild)) == true,
       "a failed bounty must be recognised")
assert(GG.bounty_for_guild(BF, o3.guild) == nil, "a failed bounty must clear its slot")
assert(select(1, GG.get(BF, o3.guild)) == 0, "failing a bounty must cost nothing")

-- OFFERS EXPIRE, TAKEN ONES DO NOT. An untaken offer is withdrawn after
-- BOUNTY_OFFER_LIFE turns; a taken one is a live mission the game is timing.
GG.bounties[BF] = nil
GG.post_bounties(BF)
GG.take_bounty(BF, 1)
local kept = GG.bounties[BF][1].guild
local kept_posted = GG.bounties[BF][1].posted
TURN = TURN + GG.BOUNTY_OFFER_LIFE
GG.post_bounties(BF)
local still = GG.bounty_for_guild(BF, kept)
assert(still and still.taken and still.posted == kept_posted,
       "a taken bounty must survive the offer lifetime")
for i = 1, #GG.bounties[BF] do
    local b = GG.bounties[BF][i]
    assert(b.taken or b.posted == TURN,
           "an untaken offer older than the lifetime must be withdrawn")
end

-- THE BOARD SURVIVES A SAVE, taken flag and all.
GG.save_bounties(BF)
local want = #GG.bounties[BF]
GG.bounties[BF] = nil
GG.load_bounties(BF)
assert(#GG.bounties[BF] == want,
       "save round-trip lost offers: " .. #GG.bounties[BF] .. " of " .. want)
local back = GG.bounty_for_guild(BF, kept)
assert(back and back.taken == true, "save round-trip lost the taken flag")
assert(back.gold == GG.BOUNTY_KINDS[back.kind].gold, "save round-trip lost the gold")

-- AND A TARGET THAT CANNOT BE FOUND TWICE LEAVES A SLOT EMPTY, rather than being
-- offered twice. One region and one general between them means exactly two offers are
-- possible - one for a region guild, one for a lord guild - and the board must stop
-- there instead of filling to three with a repeat.
local SF = "cr_bounty_scarce"
WARS[SF] = {ENEMY("cr_lean", {"only_region"}, {77})}
GG.bounties[SF] = nil
GG.post_bounties(SF)
local scarce = GG.bounties[SF]
assert(#scarce == 2, "one region and one lord allow exactly two offers, got " .. #scarce)
assert(scarce[1].target ~= scarce[2].target, "the two offers must not share a target")

-- A taken offer keeps its target reserved: re-posting must not hand the same objective
-- to another guild while the first is still live.
GG.take_bounty(SF, 1)
local held = scarce[1].target
TURN = TURN + 1
GG.post_bounties(SF)
for i = 1, #GG.bounties[SF] do
    local b = GG.bounties[SF][i]
    if b.target == held then
        assert(b.taken, "the held target was re-offered as a new bounty")
    end
end

-- ------------------------------------------------- an offer must stay true --
-- The board is SAVED, so an offer outlives the world it was picked from. Reported from
-- play: a bounty to sack a settlement the player had since captured, sitting next to a
-- second offer naming the same place.
local VF = "cr_validate"
AT_WAR[VF] = {cr_enemy = true, cr_expeace = false}
REGION_OWNER["enemy_town"] = "cr_enemy"
REGION_OWNER["my_town"] = VF
REGION_OWNER["ex_enemy_town"] = "cr_expeace"
ALIVE_FM["500"] = true

local function offer(guild, kind, target, taken)
    return {guild = guild, kind = kind, target = target, owner = "cr_enemy",
            gold = 1000, rep = 80, posted = TURN, taken = taken or false}
end

-- A settlement you own is not a target, whatever the guild wanted with it.
-- AT_WAR[VF][VF] is set so this tests the OWNERSHIP rule and nothing else: without it
-- the "no longer at war with the owner" rule catches the case first - you are not at war
-- with yourself - and the ownership check could be deleted with this test still passing.
AT_WAR[VF][VF] = true
GG.bounties[VF] = {offer("slavers", "region_sack", "my_town")}
assert(GG.purge_bounties(VF) == 1, "a bounty on your own settlement must be withdrawn")
assert(#GG.bounties[VF] == 0, "the slot must be freed")
AT_WAR[VF][VF] = nil

-- Nor is one held by a faction you are no longer at war with: no guild opens a war.
GG.bounties[VF] = {offer("brass", "region_take", "ex_enemy_town")}
assert(GG.purge_bounties(VF) == 1, "peace must withdraw the bounty")

-- An enemy's settlement is still good work.
GG.bounties[VF] = {offer("brass", "region_take", "enemy_town")}
assert(GG.purge_bounties(VF) == 0, "an enemy settlement must survive the purge")
assert(#GG.bounties[VF] == 1, "and stay on the board")

-- A character who no longer exists cannot be killed for money.
GG.bounties[VF] = {offer("khanate", "lord_kill", "999")}
assert(GG.purge_bounties(VF) == 1, "a dead or missing target must be withdrawn")
GG.bounties[VF] = {offer("khanate", "lord_kill", "500")}
assert(GG.purge_bounties(VF) == 0, "a living target must survive")

-- A TAKEN offer is never purged: it is a live mission, and the game times it out.
GG.bounties[VF] = {offer("slavers", "region_sack", "my_town", true)}
assert(GG.purge_bounties(VF) == 0, "a taken bounty must not be withdrawn under you")
assert(#GG.bounties[VF] == 1, "the taken bounty stays")

-- A duplicate goes, and the TAKEN one is the one that stays.
GG.bounties[VF] = {offer("slavers", "region_sack", "enemy_town", true),
                   offer("brass", "region_take", "enemy_town")}
assert(GG.purge_bounties(VF) == 1, "the duplicate must be withdrawn")
assert(#GG.bounties[VF] == 1 and GG.bounties[VF][1].taken,
       "the taken offer is the one that survives")

-- WHEN THE MODEL CANNOT ANSWER, THE OFFER STAYS. Dropping on a question mark would
-- churn the whole board on any campaign where these lookups behave differently.
local real_get_region = cm.get_region
cm.get_region = function() error("model unavailable") end
GG.bounties[VF] = {offer("brass", "region_take", "enemy_town")}
assert(GG.purge_bounties(VF) == 0, "an unanswerable lookup must not withdraw the offer")
cm.get_region = real_get_region
GG.bounties[VF] = nil

-- rate_bounty 0 EMPTIES THE BOARD: the off switch the MCT slider offers.
GG.TUNE.rate_bounty = 0
GG.bounties[BF] = nil
GG.post_bounties(BF)
assert(#(GG.bounties[BF] or {}) == 0,
       "rate_bounty 0 must offer nothing, got " .. #(GG.bounties[BF] or {}))
GG.TUNE.rate_bounty = 80

-- --------------------------------------------------- the AI's half of the court --
-- The player had two reputation multipliers no rival could answer. These assert the AI
-- now has both, and the three ways the block must NOT misbehave: it must not touch a
-- faction no guild knows, it must not fill a post with nobody, and it must not move a
-- post that is already filled.
--
-- Stubs restored first; the AI section above left random_number on math.random and
-- model on nil, and both matter here.
cm.random_number = function(_, _n) return 1 end
TURN = 60
cm.model = function() return {turn_number = function() return TURN end} end

local AIF = "cr_ai_court"
GG.state[AIF] = nil
GG.demands[AIF] = nil
GG.demand_last[AIF] = nil
GG.patrons[AIF] = nil
GG.patron_forces[AIF] = nil
-- ONE guild only, so which one the demand names is deterministic: roll_demand picks
-- from the guilds that already know the faction, and with two of them a stubbed roll of
-- 1 names whichever comes first in GG.GUILDS - which is not the one this block is about.
GG.grant(AIF, "slavers", 800)
TREASURY[AIF] = 999999
GGAI.TEST_FORCES = {{armed_citizenry = true, cqi = 11},
                    {armed_citizenry = false, cqi = 12}}
CHAR_FORCE["12"] = 6060

assert(GGAI.best_guild(AIF) == "slavers",
       "an AI serves the guild it has the most reputation with, got "
       .. tostring(GGAI.best_guild(AIF)))

-- A DEMAND IS PAID. The clock has to have run, exactly as it does for the player.
GG.demand_last[AIF] = TURN - GG.setting("demand_every")
local rep_before = select(1, GG.get(AIF, "slavers"))
GGAI.court_step(AIF, TURN)
assert(GG.demands[AIF] == nil, "an affordable demand must be paid, not left standing")
assert(select(1, GG.get(AIF, "slavers"))
       == rep_before + GG.setting("demand_reward"),
       "paying must pay the AI its reputation too, got "
       .. select(1, GG.get(AIF, "slavers")) .. " from " .. rep_before)

-- AND THE POST IS FILLED, on the army rather than the garrison.
assert(GG.patrons[AIF] and GG.patrons[AIF].guild == "slavers",
       "the AI must appoint a patron to its best guild")
assert(GG.patron_forces[AIF] == 6060,
       "the bundle must land on the field army's force, got "
       .. tostring(GG.patron_forces[AIF]))

-- NEVER MOVED ONCE FILLED. Ranks move every turn; a post that chased the top guild
-- would take its bundle off one army and put it on another forever.
GG.state[AIF]["brass"] = {rep = 99999, fav = 0}
GGAI.court_step(AIF, TURN)
assert(GG.patrons[AIF].guild == "slavers",
       "a filled post must not chase the top guild")

-- A DEAD LORD VACATES IT, and the next step fills it again.
CHAR_FORCE["12"] = nil
GGAI.court_step(AIF, TURN)
assert(GG.patrons[AIF] == nil,
       "a post whose lord is gone must be vacant, and refilled only when an army exists")
CHAR_FORCE["12"] = 6060
GGAI.court_step(AIF, TURN)
assert(GG.patrons[AIF] ~= nil, "and refilled once one does")

-- NO FIELD ARMY IS NOT AN EMPTY POST. set_patron refuses rather than filling it with
-- nobody, which would pay the discount for an army that does not exist.
local NAF = "cr_ai_no_army"
GG.state[NAF] = nil
GG.patrons[NAF] = nil
GG.grant(NAF, "khanate", 400)
GGAI.TEST_FORCES = {{armed_citizenry = true, cqi = 21}}
GGAI.court_step(NAF, TURN)
assert(GG.patrons[NAF] == nil, "a garrison-only faction must hold no patron")

-- AND A FACTION NO GUILD KNOWS IS NOT TOUCHED AT ALL. This is what keeps the sweep off
-- the other ~190 factions in the world rather than writing two saved values for each.
local UNK = "cr_ai_unknown"
GG.state[UNK] = nil
GG.demands[UNK] = nil
saved["derpy_gg_demand_" .. UNK] = nil
saved["derpy_gg_patron_" .. UNK] = nil
GGAI.court_step(UNK, TURN)
assert(saved["derpy_gg_demand_" .. UNK] == nil
       and saved["derpy_gg_patron_" .. UNK] == nil,
       "a faction with no standing must not have saved values written for it")

-- AN AI THAT CANNOT PAY LOSES THE STANDING, exactly as a player who ignores one does.
local POOR = "cr_ai_poor"
GG.state[POOR] = nil
GG.demands[POOR] = nil
GG.grant(POOR, "overseers", 900)
TREASURY[POOR] = 0
GGAI.TEST_FORCES = {{armed_citizenry = false, cqi = 31}}
CHAR_FORCE["31"] = 7070
GG.demand_last[POOR] = TURN - GG.setting("demand_every")
GGAI.court_step(POOR, TURN)
local d_poor = GG.demands[POOR]
if d_poor and d_poor.kind == "tribute" then
    local before_poor = select(1, GG.get(POOR, "overseers"))
    GGAI.court_step(POOR, d_poor.due + 1)
    assert(select(1, GG.get(POOR, "overseers")) < before_poor,
           "an AI that lets a demand expire must lose reputation for it")
end

-- AND run_turn MUST ACTUALLY REACH IT. This is the fault this mod has already shipped
-- once: GG.on_agent_action existed, was commented, was harness-tested, and was called by
-- nothing at all - so the Khanate could not earn from its own route and every test
-- passed. A court_step nothing drives is the same bug with a different name, so the
-- world is stubbed far enough to run the real sweep.
local RUNF = "cr_ai_run"
GG.state[RUNF] = nil
GG.patrons[RUNF] = nil
GG.patron_forces[RUNF] = nil
GG.demands[RUNF] = nil
GG.grant(RUNF, "immortals", 700)
TREASURY[RUNF] = 999999
GGAI.TEST_FORCES = {{armed_citizenry = false, cqi = 41}}
CHAR_FORCE["41"] = 8080
GG.demand_last[RUNF] = TURN - GG.setting("demand_every")
cm.model = function()
    return {turn_number = function() return TURN end,
            world = function()
                return {faction_list = function()
                    return LIST({{is_null_interface = function() return false end,
                                  is_human = function() return false end,
                                  is_dead = function() return false end,
                                  name = function() return RUNF end}})
                end}
            end}
end
GGAI.reset_turn()
GGAI.run_turn()
assert(GG.patrons[RUNF] ~= nil,
       "GGAI.run_turn must reach court_step - a patron nothing ever appoints is a dead "
       .. "function that passes every test written against it directly")
assert(GG.demands[RUNF] == nil,
       "run_turn must tick and settle the demand as well")
assert(select(1, GG.get(RUNF, "immortals")) == 700 + GG.setting("demand_reward"),
       "and pay for it, got " .. select(1, GG.get(RUNF, "immortals")))

-- The switch covers the Court too: a player who turns the AI off wants rivals that
-- accrue and do nothing, and appointing a patron is doing something.
GG.TUNE.ai_spending = false
local OFF = "cr_ai_off"
GG.state[OFF] = nil
GG.patrons[OFF] = nil
GG.grant(OFF, "brass", 700)
cm.model = function()
    return {turn_number = function() return TURN end,
            world = function()
                return {faction_list = function()
                    return LIST({{is_null_interface = function() return false end,
                                  is_human = function() return false end,
                                  is_dead = function() return false end,
                                  name = function() return OFF end}})
                end}
            end}
end
GGAI.reset_turn()
GGAI.run_turn()
assert(GG.patrons[OFF] == nil,
       "ai_spending off must leave the AI's Court alone as well as its purse")
GG.TUNE.ai_spending = true

GGAI.TEST_FORCES = nil

-- ---------------------------------------------------------------------------
-- THE AI SECTION ABOVE RE-POINTED THREE STUBS AND NEVER PUT THEM BACK: random_number
-- became math.random, model became nil, and show_message_event became a no-op. Anything
-- written after it inherits that, so a test of the event feed silently recorded nothing
-- and a test that rolls silently rolled differently every run. Restored here, once.
cm.random_number = function(_, _n) return 1 end
cm.model = function() return {turn_number = function() return TURN end} end
cm.show_message_event = function(_, f, title, _primary, _secondary, _persist, idx)
    feed[#feed + 1] = {f, title, idx}
end

-- ------------------------------------------------------- who leads a guild --
-- GG.leader_of has always picked the top faction and the Standings tab has always
-- printed it. Nothing paid for it, so these assert the two things that make it a prize:
-- the bundle follows the crown, and it leaves the faction that loses it.
local L1, L2 = "cr_lead_a", "cr_lead_b"
GG.state = {}
GG.leaders_now = {}
GG.CULTURE_OF = {}
-- BOTH ARE CHAOS DWARFS. Leadership is per culture, and a faction with no culture on
-- record leads nothing - GG.grant does not set one (only GG.capped_grant gates on
-- culture), so a test that grants directly has to say who these factions are.
GG.CULTURE_OF[L1], GG.CULTURE_OF[L2] = GG.CHD_CULTURE, GG.CHD_CULTURE
local mark = #applied
GG.grant(L1, "brass", 200)
GG.reassert_leaders()
local crowned = nil
for i = mark + 1, #applied do
    if applied[i][1] == "derpy_gg_lead_brass" then crowned = applied[i][2] end
end
assert(crowned == L1, "the only faction with standing must lead brass, got "
       .. tostring(crowned))

local rmark = #removed
GG.grant(L2, "brass", 500)
GG.reassert_leaders()
local lost = false
for i = rmark + 1, #removed do
    if removed[i][1] == "derpy_gg_lead_brass" and removed[i][2] == L1 then
        lost = true
    end
end
assert(lost, "the faction that loses the crown must lose the bundle with it")
assert(GG.leaders_now[GG.lead_slot("brass", GG.CHD_CULTURE)] == L2,
       "the crown must move to the higher earner")

-- TWO CULTURES HOLD THE SAME BUNDLE RECORD AT ONCE, and crowning one must not uncrown
-- the other. A HEAD-TO-HEAD MULTIPLAYER CAMPAIGN is where that happens: the scope is
-- the player's culture and there are two players, so two races run side by side.
--
-- There is only ONE derpy_gg_lead_brass row in the DB, and each race has a foremost of
-- its own Brass Tablets, so that one bundle legitimately sits on two factions at the
-- same time. The sweep that takes it off the losers walks GG.state, which holds every
-- faction of every culture - so an unscoped sweep strips the Chaos Dwarf foremost the
-- moment the Dwarf one is crowned, and back again next turn, forever. No error, no log
-- line, and the bundle flickers off a player's faction every round.
--
-- This is also why GG.player_cultures reads EVERY human rather than the local one.
;(function()
    local CHD_LEAD, DWF_LEAD = "cr_sweep_chd", "cr_sweep_dwf"
    local DWF = "wh_main_dwf_dwarfs"
    local prev_getter = cm.get_human_factions
    local P1, P2 = "cr_sweep_player_chd", "cr_sweep_player_dwf"
    CULTURE[P1], CULTURE[P2] = GG.CHD_CULTURE, DWF
    cm.get_human_factions = function() return {P1, P2} end
    GG.player_cultures_cache = nil
    local mine = GG.player_cultures()
    assert(mine[GG.CHD_CULTURE] and mine[DWF],
           "both players' cultures must be in scope - reading only the first human is "
           .. "a multiplayer campaign where one side's guilds never start")
    -- BOTH TABLES ARE SWAPPED, not cleared: the block after this one asserts that a
    -- second sweep applies nothing, and it is measuring the crown the block BEFORE this
    -- one set. Leaving GG.leaders_now empty here re-crowns all six guilds there.
    local outer, outer_leaders = GG.state, GG.leaders_now
    GG.state = {}
    GG.leaders_now = {}
    GG.CULTURE_OF[CHD_LEAD] = GG.CHD_CULTURE
    GG.CULTURE_OF[DWF_LEAD] = DWF
    GG.grant(CHD_LEAD, "brass", 300)
    GG.grant(DWF_LEAD, "brass", 900)

    local mark, rmark = #applied, #removed
    GG.reassert_leaders()

    local crowned = {}
    for i = mark + 1, #applied do
        if applied[i][1] == "derpy_gg_lead_brass" then crowned[applied[i][2]] = true end
    end
    assert(crowned[CHD_LEAD] and crowned[DWF_LEAD],
           "each culture's foremost must get the bundle - CHD="
           .. tostring(crowned[CHD_LEAD] or false) .. " DWF="
           .. tostring(crowned[DWF_LEAD] or false))

    for i = rmark + 1, #removed do
        if removed[i][1] == "derpy_gg_lead_brass" then
            assert(removed[i][2] ~= CHD_LEAD and removed[i][2] ~= DWF_LEAD,
                   "crowning one culture's foremost stripped the other's bundle ("
                   .. tostring(removed[i][2]) .. ") - the sweep must only touch "
                   .. "factions of the culture it is settling")
        end
    end

    -- AND IT STAYS SETTLED. This runs on every faction's turn start, so a sweep that
    -- keeps taking the bundle off one culture and giving it back is two hundred calls a
    -- round and a bundle that blinks.
    local quiet_a, quiet_r = #applied, #removed
    GG.reassert_leaders()
    assert(#applied == quiet_a and #removed == quiet_r,
           "a second sweep changed something - two cultures are fighting over one "
           .. "bundle record and it will flicker every turn")

    GG.state = outer
    GG.leaders_now = outer_leaders
    GG.CULTURE_OF[CHD_LEAD], GG.CULTURE_OF[DWF_LEAD] = nil, nil
    cm.get_human_factions = prev_getter
    GG.player_cultures_cache = nil
end)()

-- IDEMPOTENT, because this runs on EVERY faction's turn start - two hundred a round.
-- A version that re-applied every time would be two hundred calls for no change.
local quiet = #applied
GG.reassert_leaders()
assert(#applied == quiet, "re-asserting an unchanged crown must apply nothing")

-- ------------------------------------------------------------ the monopoly --
-- The half that makes the league table a decision: the guild's dearest service is sold
-- to its leader and to nobody else.
local top = nil
for i = 1, #GG.SERVICES do
    if GG.SERVICES[i].guild == "brass" and GG.SERVICES[i].lead then
        top = GG.SERVICES[i]
    end
end
assert(top, "brass must have exactly one monopoly service")
GG.state[L1]["brass"] = {rep = 1500, fav = 9999}
GG.state[L2]["brass"] = {rep = 2000, fav = 9999}
GG.cooldowns[L1] = nil
GG.cooldowns[L2] = nil
assert(GG.leader_of("brass", GG.CHD_CULTURE) == L2, "setup: L2 must lead brass")
local okL, whyL = GG.can_buy(L1, top.key)
assert(okL == false and whyL == "lead",
       "a non-leader must be refused with 'lead', got " .. tostring(whyL))
assert(GG.can_buy(L2, top.key) == true, "the leader must be able to buy it")
-- Rank still gates it FIRST. A leader who has not earned the rank is not owed the
-- service, and reporting "lead" there would send the player after the wrong thing.
GG.state[L2]["brass"] = {rep = 0, fav = 9999}
assert(select(2, GG.can_buy(L2, top.key)) == "rank",
       "rank must be reported before the monopoly")
GG.state[L2]["brass"] = {rep = 2000, fav = 9999}
GG.TUNE.lead_monopoly = false
assert(GG.can_buy(L1, top.key) == true, "lead_monopoly off must reopen the service")
GG.TUNE.lead_monopoly = true

-- A FALL THROUGH A THRESHOLD TAKES THE BUNDLE WITH IT. GG.apply_rank is symmetric and
-- this is the only path that drives it downward across a rung.
local XF = "cr_fall"
GG.state[XF] = nil
GG.grant(XF, "overseers", 105)
local rm = #removed
GG.penalise(XF, "overseers", 10)
local fell = false
for i = rm + 1, #removed do
    if removed[i][1] == "derpy_gg_rank_overseers_2" then fell = true end
end
assert(fell, "falling through a threshold must remove the rank bundle")
assert(GG.penalise(XF, "overseers", 99999) == 95,
       "a penalty clamps to what is actually held")

-- ---------------------------------------------------------------- demands --
-- Reputation was a ratchet. A demand is the guild asking for something back.
local DF = "cr_demand"
GG.state[DF] = nil
GG.demands[DF] = nil
GG.grant(DF, "brass", 400)
TURN = 40
GG.demand_last[DF] = TURN
assert(GG.demand_tick(DF, TURN) == nil, "a demand must not arrive on the heels of one")
GG.demand_last[DF] = TURN - GG.setting("demand_every")
local what, d = GG.demand_tick(DF, TURN)
assert(what == "new" and d, "a demand must arrive once the clock has run")
assert(d.guild == "brass",
       "only a guild that already knows you may ask, got " .. tostring(d.guild))
assert(d.due == TURN + GG.setting("demand_turns"), "the deadline is the clock")

-- A guild nobody has any standing with asks for nothing.
local EF = "cr_demand_empty"
GG.state[EF] = nil
GG.demands[EF] = nil
GG.demand_last[EF] = 0
assert(GG.demand_tick(EF, TURN) == nil,
       "a faction no guild knows must not be asked for anything")
assert(GG.demand_last[EF] == 0,
       "a turn that issued nothing must not start the clock again")

-- PAYING IT.
TREASURY[DF] = 99999
local before_rep = select(1, GG.get(DF, "brass"))
local gmark = #gold
assert(GG.pay_demand(DF) == true, "a payable demand must go through")
assert(#gold == gmark + 1 and gold[#gold][2] == -d.amount,
       "the tribute must actually leave the treasury")
assert(select(1, GG.get(DF, "brass")) == before_rep + GG.setting("demand_reward"),
       "paying must pay the reputation")
assert(GG.demands[DF] == nil, "a paid demand is gone")

-- AN EMPTY TREASURY IS A REFUSAL, not a free demand.
GG.demand_last[DF] = TURN - GG.setting("demand_every")
what, d = GG.demand_tick(DF, TURN)
assert(what == "new", "setup: a second demand")
TREASURY[DF] = 0
local okd, whyd = GG.demand_payable(DF)
assert(okd == false and whyd == "gold",
       "an empty treasury must refuse with 'gold', got " .. tostring(whyd))
assert(GG.pay_demand(DF) == false, "an unpayable demand must not resolve")

-- THE DEADLINE.
local rep_before = select(1, GG.get(DF, "brass"))
local w2 = GG.demand_tick(DF, d.due + 1)
assert(w2 == "expired", "a demand past its deadline must expire, got " .. tostring(w2))
assert(select(1, GG.get(DF, "brass")) == rep_before - GG.setting("demand_penalty"),
       "an ignored demand must cost reputation")
assert(GG.demands[DF] == nil, "an expired demand is gone")

-- Round-trips through the save, deadline and all.
GG.demand_last[DF] = TURN - GG.setting("demand_every")
GG.demand_tick(DF, TURN)
GG.save_demand(DF)
local keep = GG.demands[DF]
GG.demands[DF] = nil
GG.load_demand(DF)
assert(GG.demands[DF] and GG.demands[DF].due == keep.due
       and GG.demands[DF].amount == keep.amount and GG.demands[DF].kind == keep.kind,
       "a demand must survive a save exactly")

-- 0 is the off switch the MCT slider offers.
GG.TUNE.demand_every = 0
GG.demands[DF] = nil
GG.demand_last[DF] = 0
assert(GG.demand_tick(DF, TURN) == nil, "demand_every 0 must issue nothing")
GG.TUNE.demand_every = 12

-- AND IT REACHES THE FEED. A demand nobody is told about is a deadline nobody saw.
local fm = #feed
GG.announce_demand(DF, "new", nil)
assert(#feed == fm + 1 and feed[#feed][3] == GG.FEED_INDEX_DEMAND,
       "a demand must reach the feed on the mod's own index")
assert(string.find(feed[#feed][2], "demand", 1, true),
       "the arrival must use the demand message")
GG.announce_demand(DF, "expired", nil)
assert(string.find(feed[#feed][2], "_fail", 1, true),
       "an expiry must use the failure message")

-- ----------------------------------------------------------------- patron --
local PF = "cr_patron"
GG.state[PF] = nil
CHAR_FORCE["777"] = 4242        -- a lord with an army
CHAR_FORCE["778"] = false       -- a lord with none
local fa = #force_applied
assert(GG.set_patron(PF, "daemonsmiths", 777) == true,
       "a lord with an army may hold the post")
assert(#force_applied == fa + 1 and force_applied[#force_applied][2] == 4242,
       "the bundle goes on the lord's ARMY, not on the lord")
assert(force_applied[#force_applied][3] == -1, "the patron bundle is indefinite")

local okp, whyp = GG.set_patron(PF, "brass", 778)
assert(okp == false and whyp == "army",
       "a lord with no army cannot hold the post, got " .. tostring(whyp))
assert(GG.patrons[PF] and GG.patrons[PF].guild == "daemonsmiths",
       "a refused appointment must not vacate the post that stands")
assert(GG.set_patron(PF, "not_a_guild", 777) == false, "an unknown guild is refused")

-- THE SHARE, and the cap still binding over it.
GG.reset_turn(PF)
GG.state[PF] = nil
GG.set_patron(PF, "daemonsmiths", 777)
GG.capped_grant(PF, "daemonsmiths", 100)        -- daemonsmiths are uncapped
assert(select(1, GG.get(PF, "daemonsmiths")) == 150,
       "the patron's guild must pay half again, got "
       .. select(1, GG.get(PF, "daemonsmiths")))
GG.reset_turn(PF)
GG.capped_grant(PF, "brass", 100)               -- not the patron's guild, cap 40
assert(select(1, GG.get(PF, "brass")) == 40,
       "another guild takes no share and is still capped")
GG.reset_turn(PF)
GG.clear_patron(PF)
GG.set_patron(PF, "immortals", 777)
GG.capped_grant(PF, "immortals", 100)           -- 150 after the share, cap 60
assert(select(1, GG.get(PF, "immortals")) == 60,
       "the per-turn cap must still bind on the patron's own guild, got "
       .. select(1, GG.get(PF, "immortals")))

-- THE DISCOUNT, and only on the guild served.
GG.state[PF] = nil
GG.cooldowns[PF] = nil
GG.clear_patron(PF)
GG.grant(PF, "daemonsmiths", 100)
local base = select(1, GG.service_cost(PF, "forge_rite"))
GG.set_patron(PF, "daemonsmiths", 777)
local with = select(1, GG.service_cost(PF, "forge_rite"))
assert(with < base,
       "the patron's guild must sell cheaper: " .. with .. " against " .. base)
GG.clear_patron(PF)
GG.set_patron(PF, "brass", 777)
assert(select(1, GG.service_cost(PF, "forge_rite")) == base,
       "a patron of another guild must not discount this one")

-- A LORD WHO IS GONE VACATES THE POST. The bundle went with the force; the discount
-- must not go on being paid for an army that no longer exists.
GG.clear_patron(PF)
GG.set_patron(PF, "daemonsmiths", 777)
CHAR_FORCE["777"] = nil
GG.assert_patron(PF)
assert(GG.patrons[PF] == nil, "a patron whose lord is gone must vacate the post")
CHAR_FORCE["777"] = 4242

-- Round-trips, and re-asserts EXACTLY ONCE after a load - the belief table is not
-- saved, so the first turn start after loading has to put the bundle back and then
-- go quiet.
GG.set_patron(PF, "khanate", 777)
GG.save_patron(PF)
GG.patrons[PF] = nil
GG.patron_forces[PF] = nil
GG.load_patron(PF)
assert(GG.patrons[PF] and GG.patrons[PF].guild == "khanate",
       "the post must survive a save")
local fa2 = #force_applied
GG.assert_patron(PF)
assert(#force_applied == fa2 + 1, "a loaded post must re-assert its bundle once")
GG.assert_patron(PF)
assert(#force_applied == fa2 + 1, "and exactly once")
GG.clear_patron(PF)
assert(force_removed[#force_removed][2] == 4242,
       "dismissing must take the bundle off the army it was put on")

-- --------------------------------------------- the rivals, made visible --
-- Everything the AI does in this mod happened in silence. It accrues, buys services,
-- answers demands, appoints patrons and takes guilds off the player, and the only trace
-- was a name on the Standings tab that was sometimes different from the last time you
-- looked - with nothing to say it had changed, when, or by how much.
--
-- These hold the record the panel reads to four things: it round-trips a save, it does
-- not invent movement on its first write, its counts come from the calls that did the
-- work, and a guild changing hands reaches the event feed.

-- get_human_factions has been {} since plan 3, and GG.announce_lead does nothing at all
-- without a human to be one of the two parties.
local HUMAN, RIVAL = "cr_world_me", "cr_world_rival"
cm.get_human_factions = function() return {HUMAN} end

local function fresh_world()
    GG.world = {turn = 0, bought = 0, demands = 0, patrons = 0,
                rep = {}, gain = {}, held = {}, moved = {}}
end

GG.state = {}
GG.leaders_now = {}
GG.CULTURE_OF = {}
-- BOTH CHAOS DWARFS, and the world record is keyed by culture AND guild now: the
-- panel's "changed hands" mark and its "+N this round" both read the leader, and a
-- leader is a per-culture thing since an Empire province was found at the head of the
-- Daemonsmiths. WBS and WSS are the two slots these assertions look at.
GG.CULTURE_OF[HUMAN], GG.CULTURE_OF[RIVAL] = GG.CHD_CULTURE, GG.CHD_CULTURE
local WBS = GG.lead_slot("brass", GG.CHD_CULTURE)
local WSS = GG.lead_slot("slavers", GG.CHD_CULTURE)
fresh_world()
GG.state[HUMAN] = {}
GG.state[RIVAL] = {}
for i = 1, #GG.GUILDS do
    GG.state[HUMAN][GG.GUILDS[i]] = {rep = 0, fav = 0}
    GG.state[RIVAL][GG.GUILDS[i]] = {rep = 0, fav = 0}
end
GG.state[HUMAN]["brass"].rep = 250

TURN = 90
GG.snapshot_world(90, 3, 2, 5)
assert(GG.world.held[WBS] == HUMAN,
       "the first snapshot must still RECORD the holder, got "
       .. tostring(GG.world.held[WBS]))
assert(GG.world.moved[WBS] == false,
       "the FIRST snapshot must claim no movement - against an empty record every guild "
       .. "has changed hands from nobody and its leader has gained their whole score, "
       .. "so a new campaign's opening round would light all six rows up")
assert(GG.world.gain[WBS] == 0,
       "and no gain either, got " .. tostring(GG.world.gain[WBS]))

-- IT MUST SURVIVE A SAVE. The panel re-reads this on every refresh, so a packing that
-- does not round-trip is a Standings tab that says the world stopped the moment you
-- loaded - which is exactly the impression this whole record exists to correct.
fresh_world()
GG.load_world()
assert(GG.world.turn == 90 and GG.world.bought == 3 and GG.world.demands == 2
       and GG.world.patrons == 5,
       "the four counts must round-trip, got "
       .. table.concat({GG.world.turn, GG.world.bought, GG.world.demands,
                        GG.world.patrons}, "/"))
assert(GG.world.held[WBS] == HUMAN and GG.world.rep[WBS] == 250,
       "and each guild's holder and score")
assert(GG.world.held[WSS] == "",
       "a guild nobody holds must round-trip as nobody, got "
       .. tostring(GG.world.held[WSS]))

-- A SECOND SNAPSHOT IS THE ONE THE PLAYER READS. Gain is the top score's movement over
-- the round, and `moved` is the crown changing hands - the two marks the Standings rows
-- draw.
GG.state[RIVAL]["brass"].rep = 900
TURN = 91
GG.snapshot_world(91, 1, 0, 4)
assert(GG.world.held[WBS] == RIVAL,
       "the rival out-earned the player and must hold brass")
assert(GG.world.moved[WBS] == true,
       "a guild that changed hands must be marked, or the panel's only way to say WHEN "
       .. "a name changed is gone")
assert(GG.world.gain[WBS] == 650,
       "the round's gain is the top score's movement (900 - 250), got "
       .. tostring(GG.world.gain[WBS]))
assert(GG.world.moved[WSS] == false,
       "a guild nobody touched must not be marked as moved")

-- REPUTATION CAN FALL. A rivalry drain, a penalty or an expired demand all take it
-- back, so the sign is read rather than assumed - the panel colours it red.
GG.state[RIVAL]["brass"].rep = 800
TURN = 92
GG.snapshot_world(92, 0, 0, 4)
assert(GG.world.gain[WBS] == -100,
       "a leader that slipped must report a negative gain, got "
       .. tostring(GG.world.gain[WBS]))

-- ------------------------------------------------- a guild changing hands --
-- Losing a guild costs a permanent bundle and the monopoly on that guild's dearest
-- service. Until now the only way to find out was to open the panel and notice a name.
local fmark = #feed
GG.announce_lead("khanate", RIVAL, HUMAN)
assert(#feed == fmark + 1, "losing a guild must reach the player's feed")
assert(feed[#feed][1] == HUMAN, "addressed to the player, got " .. tostring(feed[#feed][1]))
assert(feed[#feed][3] == GG.FEED_INDEX_LEAD,
       "on the leadership record's index, got " .. tostring(feed[#feed][3]))
assert(feed[#feed][2]
       == "message_event_text_text_derpy_gg_lead_lost_khanate_title",
       "naming the guild and the direction, got " .. tostring(feed[#feed][2]))

fmark = #feed
GG.announce_lead("khanate", HUMAN, RIVAL)
assert(feed[#feed][2]
       == "message_event_text_text_derpy_gg_lead_won_khanate_title",
       "and taking one must be the other message, got " .. tostring(feed[#feed][2]))

-- AI TO AI IS NOT AN INTERRUPT. Six guilds and a world of rivals would be several feed
-- popups a round over changes the player is not party to.
fmark = #feed
GG.announce_lead("brass", RIVAL, "cr_world_third")
assert(#feed == fmark,
       "a guild moving between two rivals must not interrupt the player - that is what "
       .. "the Standings tab is for")

-- AND NOT ON THE FIRST SWEEP AFTER A LOAD. GG.leaders_now is empty at load, so the next
-- faction turn start re-asserts all six guilds; announcing those would fire six popups
-- every single time the player loaded a save.
-- THE PLAYER MUST HOLD A GUILD GOING IN, or this proves nothing: with the crown on a
-- rival, an unguarded first sweep announces nothing either and the assertion passes
-- while measuring an empty room. Fault injection caught exactly that.
GG.state[HUMAN]["brass"].rep = 5000
GG.leaders_now = {}
fmark = #feed
GG.reassert_leaders()
assert(#feed == fmark,
       "the first assertion of a session is not news and must announce nothing - "
       .. "GG.leaders_now is empty after every load, so this is six popups every time "
       .. "the player loads a save")
-- A change made while the session is running IS news.
GG.state[RIVAL]["brass"].rep = 9000
GG.reassert_leaders()
assert(#feed > fmark, "a change made while the session is running must be announced")
assert(feed[#feed][2] == "message_event_text_text_derpy_gg_lead_lost_brass_title",
       "and it must be the player losing brass, got " .. tostring(feed[#feed][2]))

-- ------------------------------------ upkeep alone must not move the crown --
-- MEASURED IN A LIVE CAMPAIGN, turns 9-13: the Brass Tablets left the player and came
-- back seven times in one sitting, always as a "lost" four seconds before a "won", and
-- the two factions' scores never crossed. The cause is WHEN the comparison is made
-- rather than WHAT it compares. Every faction is charged its upkeep at its OWN turn
-- start and GG.reassert_leaders runs at every faction's turn start after it, so for
-- most of a round the world is half-charged: whoever has already paid is temporarily
-- behind whoever has not. A gap smaller than one upkeep tick therefore inverts twice
-- a round, forever, and each inversion moves a permanent effect bundle, takes the
-- monopoly off a service, and fires a feed popup.
--
-- The two here sit 2 apart at Indebted, where upkeep is 2 a turn at the default rate.
-- A GLOBAL, not a local: this chunk is within a handful of Lua 5.1's 200-local
-- ceiling and a new one there fails the whole harness to load.
TUNE_BEFORE_LEAD = GG.TUNE
GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_decay = 100, decay_from = 25}))
GG.state[HUMAN]["brass"].rep = 150
GG.state[RIVAL]["brass"].rep = 152
GG.leaders_now = {}
GG.reassert_leaders()
assert(GG.leaders_now[WBS] == RIVAL,
       "the rival is 2 ahead and must hold brass going in, got "
       .. tostring(GG.leaders_now[WBS]))

fmark = #feed
-- ONE ROUND, played the way the game plays it: each faction pays its upkeep at its own
-- turn start and the sweep runs after each. Nobody earns anything.
TURN_ORDER = {RIVAL, HUMAN}
for ti = 1, #TURN_ORDER do
    GG.decay(TURN_ORDER[ti], 30)
    GG.reassert_leaders()
end
assert(GG.state[RIVAL]["brass"].rep - GG.state[HUMAN]["brass"].rep == 2,
       "the round must leave the gap exactly where it found it, got "
       .. tostring(GG.state[RIVAL]["brass"].rep - GG.state[HUMAN]["brass"].rep))
assert(GG.leaders_now[WBS] == RIVAL,
       "and the rival must still hold brass at the end of it, got "
       .. tostring(GG.leaders_now[WBS]))
assert(#feed == fmark,
       "a round in which nobody earned and nobody was overtaken must announce nothing - "
       .. "got " .. (#feed - fmark) .. " popup(s), which is the half-charged world "
       .. "handing the guild back and forth")
GG.TUNE = TUNE_BEFORE_LEAD

-- ------------------------------ rivalry cannot take a rank off you --
-- MEASURED IN THE HARNESS against the shipped Lua, default tunables: a rival AI with
-- income and nothing else lost its whole khanate standing by turn 50 and stayed on
-- zero, and an ACTIVE one - a won battle every 2 turns, a building every 3, a
-- technology every 6, an agent action every 5 - still ended turn 60 with khanate 8 and
-- slavers 0. The Standings tab was columns of zeros.
--
-- The three pairs are symmetric on paper and are not in play. GG.on_turn_start grants
-- brass from net income EVERY TURN to EVERY faction, and nothing else in the mod pays
-- out passively - so brass's rival the khanate takes 40% of that income forever against
-- an income of its own that an AI essentially never earns. Same for slavers, whose
-- rival the overseers are fed by every building completed. Rivalry was a one-way
-- ratchet for two pairs of three.
--
-- THE RULE NOW: rivalry can push a guild down WITHIN the rank it holds but never below
-- the threshold it has already reached. Standing you earned stays earned; rivalry costs
-- progress, not history. Upkeep is deliberately NOT floored the same way - GG.decay is
-- the clock and demoting is its whole point - so the two are tested apart below.
do
    local R = "cr_rivalry_floor"
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_rivalry = 40, rate_decay = 100}))
    GG.CULTURE_OF[R] = GG.CHD_CULTURE
    GG.state[R] = {}
    for i = 1, #GG.GUILDS do GG.state[R][GG.GUILDS[i]] = {rep = 0, fav = 0} end
    -- Indebted is 100, so a khanate on 120 has 20 of room above the rank it holds.
    GG.state[R]["khanate"].rep = 120
    assert(GG.rank_of(GG.state[R]["khanate"].rep) == 2, "fixture must start at Indebted")

    -- IT MUST STILL BITE. A floor that stops rivalry costing anything is not a fix, it
    -- is switching the feature off, and a check that cannot fail proves nothing.
    GG.rival_cost(R, "brass", 25)
    assert(GG.state[R]["khanate"].rep == 110,
           "rivalry must still take its 40% inside the rank, got "
           .. tostring(GG.state[R]["khanate"].rep))

    -- AND IT MUST STOP AT THE THRESHOLD, not at zero. Twenty rounds of a brass income
    -- at the per-turn cap is far more than enough to clear 110 if nothing holds it.
    for _ = 1, 20 do GG.rival_cost(R, "brass", 40) end
    assert(GG.state[R]["khanate"].rep == 100,
           "rivalry must floor at the rank held (Indebted, 100), got "
           .. tostring(GG.state[R]["khanate"].rep))
    assert(GG.rank_of(GG.state[R]["khanate"].rep) == 2,
           "and the rank must survive it, since the bundle hangs off the rank")

    -- AND BELOW INDEBTED IT TAKES NOTHING AT ALL (2026-09-23, the author's choice). Rank
    -- 1's threshold is 0, so "floor at the rank held" let rivalry drain an Unmarked guild
    -- to nothing - and brass earns from income every turn, so the khanate never left 0.
    -- Measured live: the Conclave player at turn 83 held khanate 0 with 200 favour it
    -- could never spend, every khanate service being rank-gated. Once buildings paid (the
    -- same date) the overseers began doing the same to the slavers.
    GG.state[R]["slavers"].rep = 60
    for _ = 1, 20 do GG.rival_cost(R, "overseers", 40) end
    assert(GG.state[R]["slavers"].rep == 60,
           "rivalry drained a guild that has not reached Indebted - got "
           .. tostring(GG.state[R]["slavers"].rep) .. " from 60, so an Unmarked guild "
           .. "whose rival earns every turn can never climb")

    -- UPKEEP IS THE OTHER HALF AND IS UNCHANGED. GG.decay is the clock this mod was
    -- given on purpose - "dawdling does not merely delay a guild, it reverses one" - so
    -- it must still be able to take a faction through a threshold. If this ever starts
    -- failing, the floor has been put in GG.penalise instead of GG.rival_cost and the
    -- ladder has quietly become a ratchet nothing can undo.
    for turn = 26, 80 do GG.decay(R, turn) end
    assert(GG.rank_of(GG.state[R]["khanate"].rep) < 2,
           "upkeep must still be able to demote, got rep "
           .. tostring(GG.state[R]["khanate"].rep))
    GG.TUNE = TUNE_BEFORE_LEAD
end

-- ------------------------------------------- the counts come from the work --
-- The activity line is the one place in the mod that says out loud that the rivals are
-- playing it too, so its numbers have to be the actions that happened rather than a
-- second scan that could drift away from them.
local WF = "cr_world_ai"
GG.state = {}
GG.leaders_now = {}
GG.patrons = {}
GG.patron_forces = {}
GG.demands = {}
fresh_world()
GG.grant(WF, "immortals", 700)
TREASURY[WF] = 999999
GGAI.TEST_FORCES = {{armed_citizenry = false, cqi = 71}}
CHAR_FORCE["71"] = 7171
TURN = 120
GG.demand_last[WF] = TURN - GG.setting("demand_every")
cm.model = function()
    return {turn_number = function() return TURN end,
            world = function()
                return {faction_list = function()
                    return LIST({{is_null_interface = function() return false end,
                                  is_human = function() return false end,
                                  is_dead = function() return false end,
                                  name = function() return WF end}})
                end}
            end}
end
GGAI.reset_turn()
GGAI.run_turn()
assert(GG.world.turn == TURN,
       "run_turn must write the world record, got turn " .. tostring(GG.world.turn))
assert(GG.world.demands == 1,
       "the demand it paid must be counted, got " .. tostring(GG.world.demands))
assert(GG.world.patrons == 1,
       "the patron it appointed must be counted, got " .. tostring(GG.world.patrons))

-- ---------------------------------------------- once a round, not per faction --
-- FactionTurnStart fires for EVERY faction - about 190 of them in Immortal Empires -
-- and this handler ignores its context and sweeps the whole world. It was therefore
-- running that sweep 190 times a round, and GGAI.reset_turn at the top of each one
-- handed back the "one purchase per faction per turn" cap every time. The cap was real
-- and tested; the listener defeated it, and no test drove the listener.
assert(handlers["gg_ai_turn"], "the AI registers no turn handler at all")
local runs, real_run = 0, GGAI.run_turn
GGAI.run_turn = function(...) runs = runs + 1 return real_run(...) end
GGAI.last_turn = 0
TURN = 150
handlers["gg_ai_turn"]()
handlers["gg_ai_turn"]()
handlers["gg_ai_turn"]()
assert(runs == 1,
       "the world sweep must run ONCE a round however many faction turns start, got "
       .. runs .. " - at 190 factions that is 190 sweeps and 190 resets of the "
       .. "one-purchase-per-turn cap")
TURN = 151
handlers["gg_ai_turn"]()
assert(runs == 2, "and it must run again on the next round, got " .. runs)
GGAI.run_turn = real_run
GGAI.TEST_FORCES = nil
cm.get_human_factions = function() return {} end

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

-- THE MCT SWITCH MUST ACTUALLY GATE IT, THROUGH THE REAL PIPELINE. Overriding GG.setting
-- here would prove only that the function was called - and it was, against a key that was
-- registered nowhere, so GG.setting returned nil forever and the checkbox did nothing.
-- That is the fifth settings assertion in this mod to pass while guarding nothing.
assert(GG.TUNE_DEFAULTS.guild_notices == true,
       "guild_notices must have a default, or GG.setting answers nil and the guard that "
       .. "reads it can never fire")
local in_order = false
for i = 1, #GG.TUNE_ORDER do
    if GG.TUNE_ORDER[i] == "guild_notices" then in_order = true end
end
assert(in_order,
       "guild_notices must be in GG.TUNE_ORDER, which is the list read_mct_or_defaults "
       .. "walks to ingest MCT - a key missing from it is never read from MCT at all")
-- APPEND-ONLY, PINNED AS THE RULE RATHER THAN AS ONE KEY. This used to assert that
-- guild_notices was the last entry, which is not the rule - it is one consequence of the
-- rule at one moment, and it failed the first time a key was correctly appended after it.
--
-- The real property is that the ORDER OF THE EXISTING KEYS NEVER CHANGES: unpack_tune
-- walks this list positionally against a "|"-joined string in the save, so inserting a key
-- anywhere but the end shifts every value after it onto the wrong setting, in every save
-- already written, silently. The frozen prefix below is the order as shipped. Appending to
-- GG.TUNE_ORDER needs no change here; anything else fails, which is the point.
;(function()
local TUNE_FROZEN = {
    "rate_brass", "rate_immortals", "rate_daemonsmiths",
    "rate_khanate", "rate_overseers", "rate_slavers",
    "cap_brass", "cap_immortals", "cap_daemonsmiths",
    "cap_khanate", "cap_overseers", "cap_slavers",
    "ai_spending", "hostile_services",
    "rate_missions", "rate_bounty", "rate_rivalry", "lead_monopoly",
    "demand_every", "demand_turns", "demand_reward", "demand_penalty",
    "rate_patron", "guild_notices",
}
assert(#GG.TUNE_ORDER >= #TUNE_FROZEN,
       "GG.TUNE_ORDER has lost keys - every save already written indexes into this list "
       .. "by position, so a removal shifts everything after it onto the wrong setting")
for i = 1, #TUNE_FROZEN do
    assert(GG.TUNE_ORDER[i] == TUNE_FROZEN[i],
           "GG.TUNE_ORDER position " .. i .. " is " .. tostring(GG.TUNE_ORDER[i])
           .. " and must be " .. TUNE_FROZEN[i] .. " - a key was inserted or reordered "
           .. "rather than APPENDED, which silently shifts every setting after it onto "
           .. "the wrong value in every existing save")
end

-- AND AN OLDER SAVE MUST STILL READ CORRECTLY, which is what append-only buys. A string
-- written before the last few keys existed is short; unpack_tune seeds from TUNE_DEFAULTS
-- first, so the missing tail stays on its default instead of reading as 0 - and 0 on a
-- rate means OFF, which is how rate_missions once silenced every mission in the game.
do
    local full = GG.pack_tune(GG.TUNE_DEFAULTS)
    local fields = {}
    for chunk in string.gmatch(full, "[^|]+") do fields[#fields + 1] = chunk end
    assert(#fields == #GG.TUNE_ORDER,
           "pack_tune wrote " .. #fields .. " fields for " .. #GG.TUNE_ORDER .. " keys")
    -- Truncate to the length an older save has: everything up to guild_notices.
    local old = {}
    for i = 1, #TUNE_FROZEN do old[i] = fields[i] end
    local read = GG.unpack_tune(table.concat(old, "|"))
    for i = #TUNE_FROZEN + 1, #GG.TUNE_ORDER do
        local k = GG.TUNE_ORDER[i]
        assert(read[k] == GG.TUNE_DEFAULTS[k],
               k .. " reads " .. tostring(read[k]) .. " out of a save written before it "
               .. "existed, and must read its default " .. tostring(GG.TUNE_DEFAULTS[k])
               .. " - a rate that reads 0 there is a mechanic switched off in every "
               .. "campaign already in progress")
    end
end
end)()
-- And the round trip, which is what the game actually does at the first turn start.
local packed = GG.pack_tune({guild_notices = false})
GG.TUNE = GG.unpack_tune(packed)
GG.announce_rank(RHUMAN, "immortals", 1, 2)
assert(#feed == fmark, "guild_notices off must silence the announcement")
GG.TUNE = GG.unpack_tune(GG.pack_tune({guild_notices = true}))
GG.announce_rank(RHUMAN, "immortals", 1, 2)
assert(#feed > fmark, "and on must restore it")
GG.TUNE = nil

-- IT MUST FIRE FROM GG.grant, not only when called directly. Every accrual route in the
-- mod goes through that one function; a notice wired anywhere else covers one route.
--
-- RHUMAN has never been through GG.grant before this line, so without consuming its two
-- notice flags first, this call would ALSO be its first-ever accrual and its crossing of
-- the halfway mark - both true and both legitimate, but this test is about announce_rank's
-- wiring, not the notices. Consumed through the real function, not by poking the save
-- table directly, so this stays correct whichever store backs the flag underneath.
GG.notice_once(RHUMAN, "first", "brass")
GG.notice_once(RHUMAN, "half", "brass")
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
-- A tribute demand checks the faction's treasury (GG.demand_payable), same as the
-- existing demand tests further up this file (TREASURY[DF] = 99999) - the stub
-- defaults to 0, which would make this demand unpayable and silently prove nothing.
TREASURY[BHUMAN] = 99999
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

-- ----------------------------------------------- the first fifteen turns --
-- The first rank lands somewhere near turn 15 in focused play, and until then the panel
-- reads "Reputation 0 / 100" with three greyed cards and nothing has ever spoken. The mod
-- also never announced itself at all, so a player who did not notice a 44x44 button on the
-- HUD never found it. Two one-time notices give the opening three beats: first contact,
-- halfway, and Indebted.

local NHUMAN, NAI = "cr_notice_me", "cr_notice_ai"
cm.get_human_factions = function() return {NHUMAN} end
-- GG.humans is cached for the session by GG.is_human, and an earlier fixture's GG.grant
-- call (the RHUMAN section above) already forced that cache full of a different faction.
-- Cleared here so this fixture's own cm.get_human_factions answer is read fresh, exactly
-- as GG.state is reset per fixture below.
GG.humans = nil
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

-- AND AN AI FACTION MUST NOT COST AN ENGINE CALL TO REJECT. GG.notice_once is reached on
-- every grant for every faction in the world; the saved flag and the cached human list are
-- what keep that from being ~190 engine calls a round times every accrual event.
local engine_calls = 0
local real_humans = cm.get_human_factions
cm.get_human_factions = function(...) engine_calls = engine_calls + 1
                                      return real_humans(...) end
GG.humans = nil
GG.notice_once(NAI, "first", "brass")
GG.notice_once(NAI, "first", "brass")
GG.notice_once(NAI, "first", "brass")
assert(engine_calls <= 1,
       "the human list must be asked for ONCE and cached, got " .. engine_calls
       .. " engine calls for three rejections")
cm.get_human_factions = real_humans
GG.humans = nil

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

-- AND IT MUST BE IN THE SAVE STORE SPECIFICALLY. The reload block below clears the mod's
-- module tables and re-grants, which catches a flag parked on GG.state - but a flag parked
-- on a module table of its own (`GG.notices = GG.notices or {}`, the realistic mistake)
-- survives that block untouched and passes it. cm:get_saved_value is the only store that
-- actually reaches a saved game, so the flag is read back through it by name.
assert(cm:get_saved_value("derpy_gg_notice_first_" .. GHUMAN) == "1",
       "the one-time flag must be written through cm:set_saved_value under its own key - "
       .. "a flag held in any Lua table looks correct for a whole session and then fires "
       .. "on every single load forever, and no reload test built on clearing named "
       .. "globals can tell the difference")

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

cm.get_human_factions = function() return {} end
-- AND CLEAR THE SESSION CACHE WITH IT. GG.is_human memoises the human list, so leaving it
-- set hands the next section appended here a faction that is no longer the human one -
-- and a section that grants to a "human" who is not in that list asserts against notices
-- that never fire. This file is append-only; clean up on the way out, not on the way in.
GG.humans = nil

-- ----------------------------------------------- every signal has a listener --
GG.register()
for _, event in ipairs({
        "FactionTurnStart",             -- income, the Brass Tablets
        "ResearchCompleted",            -- the Daemonsmiths
        "BuildingCompleted",            -- the Overseers
        "CharacterCompletedBattle",     -- the Immortals
        "CharacterCharacterTargetAction",   -- the Khanate
        "CharacterGarrisonTargetAction",    -- the Khanate, against a settlement
        "CharacterSackedSettlement",    -- the Slavers
        "CharacterRazedSettlement",     -- the Slavers, paid more
        "MissionSucceeded",             -- every guild, and bounty payout
        "MissionFailed",                -- frees a bounty slot
        "MissionCancelled",             -- frees a bounty slot
}) do
    assert(listened[event], "nothing listens for " .. event
           .. ", so the signal it carries is dead")
end

-- ------------------------------------------------------- difficulty presets --
-- Twenty-four tunable values is a wall for anyone who just wants the climb slower. A
-- preset is one dropdown that owns the NUMBERS - and only the numbers.
--
-- IN AN ANONYMOUS FUNCTION, AND EVERY TEST APPENDED HERE FROM NOW ON MUST BE. Lua 5.1
-- allows 200 active locals per function and this file's MAIN CHUNK is already at that
-- ceiling - the first `local` these tests declared raised "main function has more than
-- 200 local variables" at COMPILE time, so the entire harness stopped running rather than
-- one test failing. A do...end block does not help: the count is already spent. A function
-- has its own budget, and calling it anonymously spends no name on the main chunk either.
;(function()
    -- Twenty-four tunable values is a wall for anyone who just wants the climb slower. A
    -- preset is one dropdown that owns the NUMBERS - and only the numbers.

    -- PRESETS OWN NUMBERS, NEVER SWITCHES. The Zharr Exchange's presets own both, so under
    -- any preset but custom its per-key options are read past entirely and every checkbox in
    -- that mod is inert unless the player picks Custom. Two of this mod's four switches are
    -- not difficulty at all - guild_notices is a notification preference and lead_monopoly is
    -- a rules toggle - and a switch that silently does nothing is the exact defect this mod
    -- shipped once already. So a preset here may not name a boolean key, and check_presets in
    -- tools/gen_great_guilds.py refuses the build if one does.
    for name, p in pairs(GG.PRESETS) do
        for k, v in pairs(p) do
            local in_order = false
            for i = 1, #GG.TUNE_ORDER do
                if GG.TUNE_ORDER[i] == k then in_order = true end
            end
            assert(in_order, "preset " .. name .. " names " .. k .. ", which is not in "
                   .. "GG.TUNE_ORDER - a key the snapshot never walks is set and then thrown "
                   .. "away, silently")
            assert(type(GG.TUNE_DEFAULTS[k]) == "number",
                   "preset " .. name .. " sets " .. k .. ", which is not a number. A preset "
                   .. "owns difficulty, not the player's switches")
            assert(type(v) == "number",
                   "preset " .. name .. " sets " .. k .. " to a " .. type(v))
        end
    end

    assert(next(GG.PRESETS[GG.PRESET_DEFAULT]) == nil,
           "the default preset must be EMPTY - the shipped TUNE_DEFAULTS are the default, and "
           .. "a second copy of them here is a second place to forget to update")

    -- THE BRASS TABLETS RATE IS A DIVISOR, NOT A RATE. Income reputation is
    -- floor(net_income / rate_brass), so LOWER is faster - it runs the opposite way to the
    -- other five. A preset built by making every number bigger for easy would leave the Brass
    -- Tablets the one guild that got SLOWER on easy and faster on ultra, and nothing else in
    -- this project would have noticed.
    local order = {"easy", "default", "hard", "ultra"}
    local function val(preset, key)
        local p = GG.PRESETS[preset]
        if p and p[key] ~= nil then return p[key] end
        return GG.TUNE_DEFAULTS[key]
    end
    for i = 1, #order - 1 do
        assert(val(order[i], "rate_brass") < val(order[i + 1], "rate_brass"),
               "rate_brass is a DIVISOR: it must RISE from easy to ultra, but "
               .. order[i] .. " is " .. val(order[i], "rate_brass") .. " and "
               .. order[i + 1] .. " is " .. val(order[i + 1], "rate_brass"))
        for _, k in ipairs({"rate_immortals", "rate_daemonsmiths", "rate_khanate",
                            "rate_overseers", "rate_slavers", "rate_patron"}) do
            assert(val(order[i], k) > val(order[i + 1], k),
                   k .. " must FALL from easy to ultra, but " .. order[i] .. " is "
                   .. val(order[i], k) .. " and " .. order[i + 1] .. " is "
                   .. val(order[i + 1], k))
        end
        -- The court presses harder as difficulty rises: demands arrive sooner and cost more
        -- to ignore.
        assert(val(order[i], "demand_every") > val(order[i + 1], "demand_every"),
               "demands must arrive SOONER as difficulty rises, at " .. order[i])
        assert(val(order[i], "demand_penalty") < val(order[i + 1], "demand_penalty"),
               "an ignored demand must cost MORE as difficulty rises, at " .. order[i])
    end

    -- ZERO MEANS UNCAPPED. cap_daemonsmiths is 0 by design: technologies are infrequent
    -- enough that a per-turn ceiling on them would do nothing but surprise. A preset that
    -- "raises the caps" and sets this to a number turns the one uncapped guild into a capped
    -- one - a restriction wearing a tuning value's clothes.
    for name, p in pairs(GG.PRESETS) do
        assert(p.cap_daemonsmiths == nil,
               "preset " .. name .. " sets cap_daemonsmiths, but 0 there means UNCAPPED - any "
               .. "number is a new restriction, not a relaxation")
    end

    -- RESOLUTION. apply_preset is the seam: pure, so it can be driven without MCT.
    local function fresh()
        local t = {}
        for k, v in pairs(GG.TUNE_DEFAULTS) do t[k] = v end
        return t
    end
    assert(GG.apply_preset(fresh(), "hard").rate_immortals
           == GG.PRESETS.hard.rate_immortals, "a named preset must land its numbers")
    assert(GG.apply_preset(fresh(), "default").rate_immortals
           == GG.TUNE_DEFAULTS.rate_immortals, "default leaves the shipped values alone")
    assert(GG.apply_preset(fresh(), GG.PRESET_CUSTOM).rate_immortals
           == GG.TUNE_DEFAULTS.rate_immortals,
           "custom applies no preset - the player's own sliders are read instead")
    -- An unknown or absent preset is the shipped default, never a crash and never nil.
    for _, bad in ipairs({"nonsense", "", "EASY"}) do
        assert(GG.apply_preset(fresh(), bad).rate_immortals
               == GG.TUNE_DEFAULTS.rate_immortals,
               "an unrecognised preset (" .. tostring(bad) .. ") must fall back to the "
               .. "shipped defaults")
    end
    assert(GG.apply_preset(fresh(), nil).rate_immortals == GG.TUNE_DEFAULTS.rate_immortals,
           "and so must no preset at all")
    -- A preset must not leave a switch changed, whatever it holds.
    assert(GG.apply_preset(fresh(), "ultra").guild_notices == true,
           "a preset must not move a player switch")

    -- MULTIPLAYER IGNORES MCT ENTIRELY. MCT is a LOCAL registry: nothing reconciles two
    -- machines, so a snapshot taken from it freezes a different economy into each save on the
    -- first turn. With per-key sliders that was a slow divergence; with a preset it is one
    -- click - host on Easy, client on Cutthroat - so the guard lands with the dropdown.
    -- A STANDING MCT, OR THIS PROVES NOTHING. Written first as "set multiplayer, read
    -- settings, assert they are the defaults" - which passed with the guard DELETED,
    -- because the harness has no get_mct and both paths therefore returned the defaults
    -- anyway. Fault injection is the only reason that was ever noticed. The stub below
    -- answers a value no default holds, so reading MCT and not reading it are finally
    -- different things.
    local real_mct = get_mct
    local MARK = 4242
    get_mct = function()
        return {
            get_mod_by_key = function(_, key)
                if key ~= "derpy_great_guilds" then return nil end
                return {
                    get_option_by_key = function(_, k)
                        return {get_finalized_setting = function()
                            -- Custom, so the per-key number reads are reached at all.
                            if k == "preset" then return "custom" end
                            if type(GG.TUNE_DEFAULTS[k]) == "boolean" then
                                return not GG.TUNE_DEFAULTS[k]
                            end
                            return MARK
                        end}
                    end,
                }
            end,
        }
    end

    local real_mp = cm.is_multiplayer
    -- SINGLE PLAYER FIRST, to prove the stub is actually reachable. Without this the
    -- multiplayer assertion below could pass for the old reason all over again.
    cm.is_multiplayer = function() return false end
    local sp = GG.read_mct_or_defaults()
    assert(sp.rate_immortals == MARK,
           "single player must READ MCT - the stub is not being reached, so the "
           .. "multiplayer assertion below would prove nothing again (got "
           .. tostring(sp.rate_immortals) .. ")")
    assert(sp.guild_notices == (not GG.TUNE_DEFAULTS.guild_notices),
           "and the switches too, on every preset")

    cm.is_multiplayer = function() return true end
    local mp = GG.read_mct_or_defaults()
    for i = 1, #GG.TUNE_ORDER do
        local k = GG.TUNE_ORDER[i]
        assert(mp[k] == GG.TUNE_DEFAULTS[k],
               "in multiplayer every value must be the SHIPPED default, but " .. k
               .. " came back as " .. tostring(mp[k]) .. " against "
               .. tostring(GG.TUNE_DEFAULTS[k]))
    end
    assert(GG.mp_ignores_mct() == true, "and the guard must say so out loud")
    cm.is_multiplayer = function() return false end
    assert(GG.mp_ignores_mct() == false, "single player reads MCT as before")

    -- AND A PRESET STILL OWNS THE NUMBERS WHILE THE SWITCHES STAY THE PLAYER'S. This is
    -- where this mod parts company with the Zharr Exchange, so it is asserted rather than
    -- left to the comment: under a named preset the sliders are ignored and the preset's
    -- numbers land, but a checkbox the player moved still moves.
    get_mct = function()
        return {
            get_mod_by_key = function(_, key)
                if key ~= "derpy_great_guilds" then return nil end
                return {
                    get_option_by_key = function(_, k)
                        return {get_finalized_setting = function()
                            if k == "preset" then return "hard" end
                            if type(GG.TUNE_DEFAULTS[k]) == "boolean" then
                                return not GG.TUNE_DEFAULTS[k]
                            end
                            return MARK
                        end}
                    end,
                }
            end,
        }
    end
    local hard = GG.read_mct_or_defaults()
    assert(hard.rate_immortals == GG.PRESETS.hard.rate_immortals,
           "under a named preset the preset owns the numbers, not the sliders (got "
           .. tostring(hard.rate_immortals) .. ")")
    assert(hard.guild_notices == (not GG.TUNE_DEFAULTS.guild_notices),
           "but a switch the player moved must still move - a preset owning the "
           .. "checkboxes is how the Exchange left all seven of its own inert")

    get_mct = real_mct
    cm.is_multiplayer = real_mp
    -- An engine that does not answer at all is NOT multiplayer. is_multiplayer behind a pcall
    -- returning nothing used to mean `ok and v == true` was false, which is the safe way
    -- round: a singleplayer campaign must not be locked out of its own settings.
    cm.is_multiplayer = function() error("no such call") end
    assert(GG.mp_ignores_mct() == false,
           "an engine call that errors must read as SINGLE player - locking singleplayer out "
           .. "of MCT because a call failed is a worse failure than the one being guarded")
    cm.is_multiplayer = real_mp
end)()

-- ---------------------------------------------- the board loses its own writes --
-- REPORTED FROM PLAY, 2026-09-12: "why does the mission bounty keeps aborting, since i
-- defeated the lord without taking the bounty but it still stays active". The script log
-- of that session (script_log_120926_1654.txt) has the same offer issued FOUR times -
-- 247.4s, 264.6s, 272.6s, 273.1s - byte-identical each time, target 19672, 2370 gold, and
-- the card_buy button still reading `visible: [true]` on the reopen between clicks. No
-- script error anywhere after 85.3s, so nothing threw: the offer simply read untaken
-- again a moment after being taken.
--
-- THE WRITE LANDED ON AN ORPHAN. GG.take_bounty triggers the mission and marks the offer
-- afterwards, and GG.load_bounties REPLACES GG.bounties[faction] with a brand new list
-- built from the saved value. The mod reloads the board inside three listeners -
-- gg_mission, gg_bounty_MissionFailed and gg_bounty_MissionCancelled - so if the engine
-- resolves the mission during the very call that created it (and a KILL_CHARACTER
-- objective naming a corpse is exactly that), the reload runs BEFORE `o.taken = true`.
-- The flag then lands on a table nothing points at, the board still says untaken, and the
-- player clicks again. Forever.
--
-- The rule this pins: the board must be COMMITTED TO THE SAVED VALUE BEFORE any engine
-- call that can re-enter script, never after.
;(function()
    local F = "cr_reentrant"
    local before_issued = #issued
    GG.bounties[F] = {
        {guild = "khanate", kind = "lord_kill", target = "19672", owner = "cr_enemy",
         gold = 2370, rep = 80, posted = GG.turn_now(), taken = false, diff = 0},
    }
    GG.save_bounties(F)   -- the board as the turn start left it: untaken

    -- The engine call re-enters. This is not a hypothetical shape: it is the body of
    -- gg_bounty_MissionCancelled, which the mod registers on MissionCancelled.
    local real_trigger = cm.trigger_custom_mission_from_string
    cm.trigger_custom_mission_from_string = function(self, f, str)
        real_trigger(self, f, str)
        GG.load_bounties(f)
    end
    local took = GG.take_bounty(F, 1)
    cm.trigger_custom_mission_from_string = real_trigger

    assert(took == true, "the take itself must still report success")
    assert(GG.bounties[F][1].taken == true,
           "the offer must read TAKEN after a reload inside the trigger - it reads "
           .. tostring(GG.bounties[F][1].taken) .. ", which is the four-missions-from-"
           .. "one-offer bug in the 2026-09-12 log")
    assert(GG.take_bounty(F, 1) == false,
           "and a second click must be refused, or the same mission is issued again on "
           .. "every click")
    assert(#issued == before_issued + 1,
           "exactly one mission from two clicks, got "
           .. (#issued - before_issued))

    -- SAME FAULT ON THE PAYOUT SIDE. GG.bounty_done removes the offer and then calls
    -- GG.grant, which can rank the player up, which shows a message event. Any reload
    -- reached from there would put the completed offer back on the board - and the
    -- MissionSucceeded handler saves afterwards, so it would be back for good.
    GG.state[F] = GG.state[F] or {}
    for i = 1, #GG.GUILDS do
        GG.state[F][GG.GUILDS[i]] = GG.state[F][GG.GUILDS[i]] or {rep = 0, fav = 0}
    end
    GG.bounties[F] = {
        {guild = "khanate", kind = "lord_kill", target = "19672", owner = "cr_enemy",
         gold = 2370, rep = 80, posted = GG.turn_now(), taken = true, diff = 0},
    }
    GG.save_bounties(F)
    local real_grant = GG.grant
    GG.grant = function(f, g, n)
        real_grant(f, g, n)
        GG.load_bounties(f)
    end
    local done = GG.bounty_done(F, GG.bounty_mission_key("khanate"))
    GG.grant = real_grant
    assert(done == true, "the completed bounty must be recognised")
    assert(#GG.bounties[F] == 0,
           "a paid bounty must be OFF the board even if the grant re-enters, board still "
           .. "holds " .. #GG.bounties[F])
    assert(select(1, GG.get(F, "khanate")) == 80,
           "and it must still have paid, got " .. select(1, GG.get(F, "khanate")))

    GG.bounties[F] = nil
    GG.state[F] = nil
end)()

-- ------------------------------------------------------ a target that has died --
-- THE OTHER HALF OF THE SAME REPORT: "i defeated the lord without taking the bounty but
-- it still stays active". GG.bounty_still_valid tests two things about a lord target -
-- that the family member resolves, and that its character resolves - and CA documents
-- the first as surviving the character outright. model_hierarchy, verbatim: "The family
-- member script interface represents a character within a family tree. This interface is
-- persistent, even if the related character is destroyed and recreated."
--
-- So that function could never answer no, and there is nothing to poll instead: no
-- is_dead on FAMILY_MEMBER_SCRIPT_INTERFACE, on CHARACTER_SCRIPT_INTERFACE or on
-- CHARACTER_DETAILS_SCRIPT_INTERFACE (the is_dead CA documents is on the FACTION
-- interface). The one signal the engine gives is CharacterDestroyed, whose context
-- carries `family_member` - "Family Member of the character that was destroyed", the same
-- cqi this mod stores as the target - and the mod listened for it nowhere.
;(function()
    local F = "cr_dead_target"
    ALIVE_FM["19672"] = true
    ALIVE_FM["19673"] = true
    GG.bounties[F] = {
        {guild = "khanate", kind = "lord_kill", target = "19672", owner = "cr_enemy",
         gold = 2370, rep = 80, posted = GG.turn_now(), taken = false, diff = 0},
        {guild = "immortals", kind = "lord_kill", target = "19673", owner = "cr_enemy",
         gold = 2370, rep = 80, posted = GG.turn_now(), taken = true, diff = 0},
    }
    GG.save_bounties(F)

    -- Nothing pollable changes when the lord dies, so purge cannot be the fix.
    assert(GG.purge_bounties(F) == 0, "a live board must purge nothing")

    assert(handlers["gg_character_destroyed"],
           "the mod registers no CharacterDestroyed listener, so a bounty whose target "
           .. "died is invisible to it - and there is no is_dead anywhere on the family "
           .. "member, the character or its details to poll instead")

    local function destroy(cqi)
        handlers["gg_character_destroyed"]({
            family_member = function()
                return {is_null_interface = function() return false end,
                        command_queue_index = function() return cqi end}
            end,
        })
    end

    destroy(19672)
    assert(#GG.bounties[F] == 1,
           "the untaken offer on a dead lord must be withdrawn, board still holds "
           .. #GG.bounties[F])
    assert(GG.bounties[F][1].target == "19673",
           "and it must be THAT offer that went, not the other one")
    assert(not string.find(tostring(cm:get_saved_value("derpy_gg_bounties_" .. F)),
                           "19672", 1, true),
           "the withdrawal must reach the SAVED value too, or the next reload puts the "
           .. "dead lord straight back on the board")

    -- A TAKEN BOUNTY IS LEFT ALONE. Its target dying is the mission being COMPLETED;
    -- withdrawing it on the kill would delete the contract at the moment it was earned,
    -- and MissionSucceeded is what clears it.
    destroy(19673)
    assert(#GG.bounties[F] == 1,
           "a taken bounty must survive its target's death - that death is how it is won")

    -- AND A DESTROYED CHARACTER NOBODY HAS A BOUNTY ON MUST COST NOTHING. This listener
    -- fires for every general lost by every faction on the map, so it may not write a
    -- saved value per death.
    local writes = 0
    local real_save = GG.save_bounties
    GG.save_bounties = function(f) writes = writes + 1; real_save(f) end
    destroy(4242)
    GG.save_bounties = real_save
    assert(writes == 0,
           "a death that matches no offer must not save anything, it saved " .. writes
           .. " time(s) - this listener fires for every general lost anywhere on the map")

    GG.bounties[F] = nil
end)()

-- ------------------------------------------- a targeted service with no target --
-- FIVE OF EIGHTEEN SERVICES TOOK THE FAVOUR AND DELIVERED NOTHING. Every payload shape
-- that reads a target does nothing without one - grant_unit_to_character,
-- instantly_research_technology, make_region_visible_in_shroud and
-- region_slot_instantly_upgrade_building are all inside `if target then`. GG.buy guarded
-- only `s.hostile`, because that one had a visible symptom (the malus landed on the
-- buyer). The other four had no symptom at all: the favour left the account, the cooldown
-- started, and nothing arrived.
--
-- The test is on GG.needs_target rather than on a hardcoded list of keys, so a service
-- added later with a targeted payload is covered the day it is written.
;(function()
    local F = "cr_no_target"
    GG.state[F] = GG.state[F] or {}
    for i = 1, #GG.GUILDS do
        GG.state[F][GG.GUILDS[i]] = {rep = 0, fav = 0}
    end
    GG.cooldowns[F] = {}

    local tested = 0
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if GG.needs_target(s) then
            -- Enough standing to reach the rank, and enough favour to pay twice over, so
            -- the only thing that can refuse the sale is the missing target.
            GG.state[F][s.guild] = {rep = GG.RANKS[s.rank] or 0, fav = 999999}
            GG.cooldowns[F][s.key] = 0
            local ok, why = GG.can_buy(F, s.key)
            if ok then
                tested = tested + 1
                local before = select(2, GG.get(F, s.guild))
                local sold, reason = GG.buy(F, s.key, nil)
                assert(sold == false,
                       s.key .. " sold with nothing selected - its payload reads a "
                       .. "target and does nothing without one, so this is favour taken "
                       .. "for nothing")
                assert(reason == "target",
                       s.key .. " refused for " .. tostring(reason)
                       .. ", it must refuse for the missing target")
                assert(select(2, GG.get(F, s.guild)) == before,
                       s.key .. " charged favour on a refused sale: " .. before .. " -> "
                       .. select(2, GG.get(F, s.guild)))
                assert(GG.cooldown_left(F, s.key) == 0,
                       s.key .. " started its cooldown on a refused sale, which locks "
                       .. "the player out of a service they never received")

                -- AND IT STILL SELLS WHEN SOMETHING IS SELECTED. A guard that refuses
                -- everything would pass every assertion above.
                local sold2 = GG.buy(F, s.key, "cr_some_target")
                assert(sold2 == true,
                       s.key .. " refused a sale WITH a target - the guard is refusing "
                       .. "everything, which passes the assertions above and breaks the "
                       .. "service")
                assert(select(2, GG.get(F, s.guild)) < before,
                       s.key .. " sold without charging anything")
            end
        end
    end
    assert(tested >= 4,
           "only " .. tested .. " targeted service(s) were reachable to test - there are "
           .. "five, and a test that silently covers one proves almost nothing")

    -- A SERVICE THAT NEEDS NOTHING SELECTED MUST STILL SELL. The guard must not spread.
    local untargeted = nil
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if not GG.needs_target(s) and not s.lead then untargeted = s break end
    end
    assert(untargeted, "every service reads a target, which cannot be right")
    GG.state[F][untargeted.guild] = {rep = GG.RANKS[untargeted.rank] or 0, fav = 999999}
    GG.cooldowns[F][untargeted.key] = 0
    assert(GG.buy(F, untargeted.key, nil) == true,
           untargeted.key .. " needs no target and was refused anyway")

    GG.state[F] = nil
    GG.cooldowns[F] = nil
    -- A "restore" of GG.humans and cm.get_human_factions from prev_humans / prev_getter
    -- stood here until 2026-09-23. This block never declared either - it never changes
    -- the humans at all - so the line assigned two undeclared globals, i.e. nil, and every
    -- test below it ran in a campaign with no human player.
end)()

-- -------------------------------------------------- the hire is per culture --
-- The mod's headline objective is that it is not race-locked, and GG.HIRE_UNIT was the
-- single thing standing in the way: one Chaos Dwarf unit key, granted to everyone.
;(function()
    local chd = GG.HIRE_UNIT_BY_CULTURE["wh3_dlc23_chd_chaos_dwarfs"]
    assert(chd, "the Chaos Dwarf hire unit must still be in the table")
    for culture, unit in pairs(GG.HIRE_UNIT_BY_CULTURE) do
        GG.CULTURE_OF["cr_hire_" .. culture] = culture
        assert(GG.hire_unit("cr_hire_" .. culture) == unit,
               culture .. " must be granted " .. unit .. ", got "
               .. tostring(GG.hire_unit("cr_hire_" .. culture)))
        -- EVERY MAPPED CULTURE IS ONE THIS MOD CLAIMS TO FLAVOUR. GG.CULTURES is no
        -- longer a list - it is discovered from the campaign - so the pairing to hold
        -- is with GG.FLAVOURED, the cultures that have their own names and regiment.
        assert(GG.FLAVOURED[culture] == true,
               culture .. " has a hire unit and is not in GG.FLAVOURED - either it lost "
               .. "its guild names or the unit is dead weight")
    end
    for culture, _ in pairs(GG.FLAVOURED) do
        assert(GG.HIRE_UNIT_BY_CULTURE[culture],
               culture .. " is flavoured but has no regiment, so it is refused the one "
               .. "service its flavour exists for")
    end

    -- AN UNMAPPED CULTURE GETS NOTHING, AND THAT IS THE POINT. This used to fall back to
    -- the Chaos Dwarf regiment, which was harmless while the mapped three were also the
    -- gate. They are not the gate any more: the scope is the player's culture, read off
    -- the human faction at runtime, so THE PLAYER CAN BELONG TO A CULTURE SOME MOD ADDED
    -- - and the fallback would drop Chaos Dwarf infantry into an Araby or Nippon army,
    -- bought with their own favour, a unit their roster cannot support.
    --
    -- SO THIS FACTION IS THE ONE AT THE KEYBOARD. Its culture is deliberately a key no
    -- table in this mod contains, which is the case that has to work.
    local UK = "cr_hire_unknown"
    local hire_getter = cm.get_human_factions
    CULTURE[UK] = "some_culture_nobody_mapped"
    cm.get_human_factions = function() return {UK} end
    GG.player_cultures_cache = nil
    GG.CULTURE_OF[UK] = "some_culture_nobody_mapped"
    assert(GG.covered(UK) == true,
           "a player of a culture this mod ships no flavour for must still be in their "
           .. "own race - flavour and scope are different questions")
    assert(GG.hire_unit(UK) == nil,
           "an unmapped culture was handed " .. tostring(GG.hire_unit(UK))
           .. " - a regiment from somebody else's roster")
    assert(GG.hire_unit("cr_hire_never_seen") == nil,
           "and a faction whose culture was never read must get nothing either")

    -- THE TILL REFUSES IT RATHER THAN CHARGING. A payload that cannot deliver must not
    -- be sold; this is the same rule the five targeted services were fixed under. The
    -- reason has to be 'no_unit' and not 'scope': this faction IS in the race, it just
    -- has no regiment, and the panel prints a different sentence for each.
    GG.state[UK] = nil
    GG.grant(UK, "immortals", 99999)
    GG.cooldowns[UK] = {}
    local uok, uwhy = GG.can_buy(UK, "hire_immortals")
    assert(uok == false and uwhy == "no_unit",
           "an unmapped culture must be refused the hire with 'no_unit', got "
           .. tostring(uwhy))
    -- AND ONLY THAT ONE SERVICE. Refusing a culture the whole board because one payload
    -- cannot be delivered would cost it seventeen services it can have.
    GG.grant(UK, "brass", 99999)
    GG.cooldowns[UK] = {}
    assert(GG.can_buy(UK, "caravan_levy") == true,
           "an unmapped culture must still be sold the services that do not hand out a "
           .. "regiment, got " .. tostring(select(2, GG.can_buy(UK, "caravan_levy"))))
    local before = #units
    GG.buy(UK, "hire_immortals", 77)
    assert(#units == before,
           "and no unit may be granted even if the sale is forced past the till")
    GG.state[UK] = nil
    cm.get_human_factions = hire_getter
    GG.player_cultures_cache = nil

    -- AND THE FLAVOUR LIST COVERS MORE THAN ONE RACE, which is the whole point.
    local n = 0
    for _ in pairs(GG.FLAVOURED) do n = n + 1 end
    assert(n >= 2,
           "GG.FLAVOURED covers " .. n .. " culture(s) - the mod is race-locked again")
end)()

-- --------------------------------------------- a guild led by a dead faction --
-- GG.leader_of picked the top faction by reputation and never asked whether it was
-- still in the campaign. Everything about leading a guild runs through that one
-- function - GG.reassert_leaders hangs the leader's bundle off it, and GG.can_buy sells
-- each guild's dearest service to the leader and to nobody else - so destroying the
-- faction that led a guild locked that guild's best service away from every living
-- faction INCLUDING THE PLAYER, permanently, and left a dead name on the Standings tab.
-- Six services, one per guild, could each be deleted from a campaign this way in
-- silence. High standing means an active warring faction, so being wiped out is an
-- ordinary thing for a leader to have happen.
;(function()
    local LIVE, DEAD = "cr_live_rival", "cr_dead_rival"
    for _, f in ipairs({LIVE, DEAD}) do
        GG.state[f] = {}
        for i = 1, #GG.GUILDS do GG.state[f][GG.GUILDS[i]] = {rep = 0, fav = 0} end
        GG.CULTURE_OF[f] = GG.CHD_CULTURE
    end
    DEAD_FACTIONS = {}
    GG.dead = {}

    -- The dead-to-be out-earns the other, so it holds the guild while it lives.
    GG.state[DEAD].brass.rep = 900
    GG.state[LIVE].brass.rep = 400
    assert(GG.leader_of("brass", GG.CHD_CULTURE) == DEAD,
           "the top faction must lead while it is alive, got "
           .. tostring(GG.leader_of("brass", GG.CHD_CULTURE)))

    -- DESTROYED. Its standing does not change - nothing in the mod edits it - and the
    -- only thing that has changed anywhere is the engine's answer to is_dead.
    DEAD_FACTIONS[DEAD] = true
    local who, rep = GG.leader_of("brass", GG.CHD_CULTURE)
    assert(who == LIVE,
           "a destroyed faction must not keep leading its guild - leadership is still "
           .. tostring(who) .. ", which locks that guild's dearest service away from "
           .. "every living faction including the player, forever")
    assert(rep == 400, "and the new leader's reputation must be its own, got " .. rep)

    -- THE BUNDLE AND THE MONOPOLY FOLLOW, because both read leader_of. This is the
    -- half a player actually feels.
    GG.leaders_now = {}
    GG.reassert_leaders()
    local bslot = GG.lead_slot("brass", GG.CHD_CULTURE)
    assert(GG.leaders_now[bslot] == LIVE,
           "the leadership bundle must move to the living faction, it sits on "
           .. tostring(GG.leaders_now[bslot]))

    -- A GUILD WHOSE ONLY CLAIMANT IS DEAD IS LED BY NOBODY, not by the corpse.
    GG.state[LIVE].immortals.rep = 0
    GG.state[DEAD].immortals.rep = 700
    assert(GG.leader_of("immortals", GG.CHD_CULTURE) == nil,
           "a guild whose only claimant is dead must be led by nobody, got "
           .. tostring(GG.leader_of("immortals", GG.CHD_CULTURE)))

    -- AND THE ANSWER IS CACHED ONE WAY ONLY. A faction that reads as alive must be
    -- asked again every time, or a faction that dies later never leaves the top.
    local LATER = "cr_dies_later"
    GG.state[LATER] = {}
    for i = 1, #GG.GUILDS do GG.state[LATER][GG.GUILDS[i]] = {rep = 0, fav = 0} end
    GG.CULTURE_OF[LATER] = GG.CHD_CULTURE
    GG.state[LATER].slavers.rep = 1200
    assert(GG.leader_of("slavers", GG.CHD_CULTURE) == LATER, "alive and top, so it leads")
    DEAD_FACTIONS[LATER] = true
    assert(GG.leader_of("slavers", GG.CHD_CULTURE) ~= LATER,
           "a faction that dies AFTER being read as alive must stop leading - the "
           .. "alive answer must not be cached")

    -- AN UNREADABLE FACTION IS NOT A DEATH. cm:get_faction answers FALSE for a key it
    -- does not know, and guessing "dead" there would cache a wrong answer forever.
    -- GG.covered already excludes such a faction, so nothing is lost by refusing to
    -- guess - and GG.faction_dead must say so plainly.
    NO_SUCH_FACTION["cr_not_in_this_campaign"] = true
    assert(GG.faction_dead("cr_not_in_this_campaign") == false,
           "an unreadable faction must not be recorded as dead")
    assert(GG.dead["cr_not_in_this_campaign"] == nil,
           "and must not be cached as dead either")

    NO_SUCH_FACTION = {}
    DEAD_FACTIONS = {}
    GG.dead = {}
    GG.state[LIVE], GG.state[DEAD], GG.state[LATER] = nil, nil, nil
    GG.leaders_now = {}
end)()

-- ------------------------------------------------ the league table, all of it --
-- SIX NAMES WERE COMPUTED AND FIVE THROWN AWAY. GG.leader_of scanned every faction
-- holding standing, kept the maximum and discarded the rest, so the Standings tab could
-- say who held a guild and nothing else: no second place, no way to tell a rival forty
-- reputation ahead from one four thousand ahead, and no way for a player to see their
-- own position at all. GG.standings returns the whole table and GG.leader_of is now its
-- verified first row, which is also the only way the two can never disagree.
;(function()
    local A, B, C, D = "cr_tab_a", "cr_tab_b", "cr_tab_c", "cr_tab_d"
    -- GG.state IS SWAPPED OUT, not added to. The table is global and earlier blocks
    -- leave factions holding a few reputation in it, so "how many rows" and "what
    -- position" can only be asserted against a world this block controls entirely.
    local outer_state = GG.state
    GG.state = {}
    for _, f in ipairs({A, B, C, D}) do
        GG.state[f] = {}
        for i = 1, #GG.GUILDS do GG.state[f][GG.GUILDS[i]] = {rep = 0, fav = 0} end
        GG.CULTURE_OF[f] = GG.CHD_CULTURE
    end
    DEAD_FACTIONS = {}
    GG.dead = {}

    GG.state[A].brass.rep = 400
    GG.state[B].brass.rep = 900
    GG.state[C].brass.rep = 400      -- ties with A, and sorts after it by key
    -- D has zero, and zero is NOT last place: a faction with no standing is not on the
    -- table at all, which is why position_of returns nil rather than #rows + 1.

    local rows = GG.standings("brass")
    assert(#rows == 3, "three factions hold standing, the table has " .. #rows .. " rows")
    assert(rows[1].faction == B and rows[1].rep == 900, "highest reputation leads")
    assert(rows[1].pos == 1 and rows[3].pos == 3,
           "each row must carry its own position - the panel prints it and an "
           .. "off-by-one here reads as correct")
    -- THE TIE-BREAK IS THE FACTION KEY, the same rule GG.leader_of always used. pairs()
    -- order is not stable between runs, so a table that leaves ties to it flickers.
    assert(rows[2].faction == A and rows[3].faction == C,
           "a tie must break on the faction key, every draw, or the table reorders "
           .. "itself while the player is reading it")

    -- THE TOP ROW AND GG.leader_of ARE THE SAME FACTION, by construction now. They were
    -- two separate scans and could have drifted apart.
    assert(GG.leader_of("brass", GG.CHD_CULTURE) == rows[1].faction,
           "leader_of and the table's first row must be the same faction")

    -- A FACTION WITH NO REPUTATION IS NOT ON THE STANDINGS, which is what keeps it from
    -- leading a guild. Whether it is listed in the PANEL is a different question, and
    -- GG.contenders answers it - see the block below.
    for i = 1, #rows do
        assert(rows[i].faction ~= D,
               "a faction with zero reputation is on the standings, which is what "
               .. "would let it hold a guild from turn one")
    end

    -- A DEAD FACTION LEAVES THE TABLE, not just the top of it. Leadership was the bug
    -- that was fixed; the rows underneath read from the same scan and must obey it too.
    DEAD_FACTIONS[B] = true
    assert(GG.leader_of("brass", GG.CHD_CULTURE) == A, "leader_of peels the dead off the top")
    local after = GG.standings("brass")
    assert(#after == 2, "the dead faction must be gone from the whole table, not just "
           .. "from first place - " .. #after .. " rows remain")
    for i = 1, #after do
        assert(after[i].faction ~= B, "a destroyed faction is still listed at position "
               .. i)
    end
    assert(after[1].pos == 1 and after[1].faction == A,
           "positions must renumber after a removal, or the table shows a gap where "
           .. "the corpse was")

    NO_SUCH_FACTION = {}
    DEAD_FACTIONS = {}
    GG.dead = {}
    GG.state = outer_state
end)()

-- --------------------------------------- Bound Blueprint finally has a target --
-- ONE OF EIGHTEEN SERVICES COULD NOT BE BOUGHT AT ALL. Bound Blueprint's payload is
-- cm:instantly_research_technology, which needs a technology key, and nothing on
-- FACTION_SCRIPT_INTERFACE returns the one a faction is researching - it has
-- is_currently_researching, research_queue_idle, has_technology,
-- has_available_technologies and num_completed_technologies, and not one of them names
-- the subject. ResearchStarted's context does: faction() and technology(), the second
-- documented as "Access the technology key in the event" with interface NONE.
;(function()
    local F = "cr_research"
    -- THE PLAYER, for the whole block. The ResearchStarted record is gated on
    -- GG.is_human now (it was GG.covered, which stopped being a gate when every culture
    -- became covered), and GG.is_human CACHES cm:get_human_factions into GG.humans - so
    -- the cache has to be swapped with the stub and put back at the end.
    local prev_humans, prev_getter = GG.humans, cm.get_human_factions
    GG.humans = nil
    cm.get_human_factions = function() return {F} end
    GG.state[F] = {}
    for i = 1, #GG.GUILDS do GG.state[F][GG.GUILDS[i]] = {rep = 0, fav = 0} end
    GG.CULTURE_OF[F] = GG.CHD_CULTURE
    GG.cooldowns[F] = {}

    -- NOTHING QUEUED IS A REFUSAL, and must stay one. Firing the payload with no key is
    -- the exact shape of the bug this service was fixed out of: favour taken, cooldown
    -- started, nothing delivered.
    GG.clear_research(F)
    assert(GG.research_target(F) == nil, "no research queued means no target")

    -- A NON-STRING IS NOT A TECHNOLOGY. context:technology() is documented as a key, but
    -- an interface returned instead would stringify into something that fails silently
    -- and forever at the payload.
    assert(GG.set_research(F, nil) == false, "nil is not a technology key")
    assert(GG.set_research(F, "") == false, "the empty string is not a technology key")
    assert(GG.set_research(F, 47) == false, "a number is not a technology key")
    assert(GG.research_target(F) == nil, "and none of those may leave a target behind")

    assert(GG.set_research(F, "tech_chd_test") == true, "a real key is recorded")
    assert(GG.research_target(F) == "tech_chd_test", "and is what the service buys")

    -- IT SURVIVES A SAVE. A subject held only in the session is one a player loses by
    -- saving mid-research, which is most of how anyone plays.
    GG.save_research(F)
    GG.researching[F] = nil
    assert(GG.research_target(F) == nil, "cleared in memory for the test to mean "
           .. "anything")
    GG.load_research(F)
    assert(GG.research_target(F) == "tech_chd_test",
           "the research subject must come back from the save, or Bound Blueprint "
           .. "refuses every time a player reloads mid-research")

    -- AND THE SALE GOES THROUGH, with the key reaching the payload. GG.buy is the till
    -- and the payload sink is the only proof the technology arrived.
    local svc
    for i = 1, #GG.SERVICES do
        if GG.SERVICES[i].key == "bound_blueprint" then svc = GG.SERVICES[i] end
    end
    assert(svc and svc.kind == "research", "bound_blueprint must still be the research "
           .. "service")
    GG.state[F][svc.guild] = {rep = GG.RANKS[svc.rank] or 0, fav = 999999}
    GG.cooldowns[F][svc.key] = 0
    assert(GG.buy(F, svc.key, GG.research_target(F)) == true,
           "bound_blueprint must sell once a technology is queued")

    -- COMPLETED RESEARCH IS NOT STILL PENDING. The service itself is what completes it,
    -- so leaving the subject set would let a player buy the same technology twice.
    GG.clear_research(F)
    GG.save_research(F)
    GG.load_research(F)
    assert(GG.research_target(F) == nil,
           "a completed technology must not stay on the books - the service would "
           .. "sell the same research again")

    -- ---- THE LISTENERS THEMSELVES, not just the functions they call ----------------
    -- The recording, the covered gate and the clearing all live inside listener bodies,
    -- and a gate inside a listener is unreachable from a test that only calls the
    -- function the listener calls. The harness keeps every handler it registers, so the
    -- events can be raised here for real.
    assert(handlers["gg_research_started"],
           "no ResearchStarted handler is registered, so nothing ever records what a "
           .. "faction is researching and Bound Blueprint can never have a target")
    assert(handlers["gg_tech"], "no ResearchCompleted handler is registered")

    local function ctx(name, tech)
        return {faction = function() return {name = function() return name end,
                                             is_null_interface = function()
                                                 return false end} end,
                technology = function() return tech end}
    end

    GG.clear_research(F)
    handlers["gg_research_started"](ctx(F, "tech_from_the_event"))
    assert(GG.research_target(F) == "tech_from_the_event",
           "ResearchStarted must record context:technology() - it is the only place the "
           .. "subject can be read, since no faction interface member names it")

    -- AND COMPLETING IT CLEARS IT, through the handler, so a player cannot buy the same
    -- technology a second time.
    handlers["gg_tech"](ctx(F, "tech_from_the_event"))
    assert(GG.research_target(F) == nil,
           "ResearchCompleted must clear the subject, or the service keeps selling a "
           .. "technology the faction already has")

    -- AN AI FACTION IS NOT RECORDED. The event fires for every faction in the campaign
    -- - about 190 in Immortal Empires - and a saved value each would put 190 keys in the
    -- save. This was gated on GG.covered, which stopped being a gate the moment every
    -- culture in the campaign became covered; GGAI.EXCLUDED keeps the AI off Bound
    -- Blueprint, so only the faction at the keyboard ever spends this record.
    local AIF = "cr_research_ai"
    handlers["gg_research_started"](ctx(AIF, "tech_ai_something"))
    assert(GG.research_target(AIF) == nil,
           "an AI faction's research was recorded - that is ~190 saved values for a "
           .. "service GGAI.EXCLUDED never lets the AI buy")
    -- and the human's still is.
    handlers["gg_research_started"](ctx(F, "tech_human_something"))
    assert(GG.research_target(F) == "tech_human_something",
           "the player's research must still be recorded")
    GG.clear_research(F)

    GG.state[F] = nil
    GG.cooldowns[F] = nil
end)()

-- ------------------------------------- the rivals exist before they earn --
-- THE STANDINGS TAB WAS EMPTY FOR THE FIRST STRETCH OF EVERY CAMPAIGN. GG.state is not
-- a roster - GG.load returns early for a faction with no saved value, so a faction only
-- appears in it once it has already earned - and every passive earn route runs through
-- GG.capped_grant, which needs net income over the brass divisor or an event that has
-- not happened yet. At turn two that is the player and nobody else: the tab read "1/1"
-- and "Nobody yet" six times, with the rival Chaos Dwarf factions alive, covered and
-- playing, and nothing on screen saying so.
--
-- AND THEN IT READ 1/127, which is not a league table, it is a phone book. The three
-- covered cultures share the guilds and their leadership, but a Chaos Dwarf player is
-- not racing the Empire's electoral provinces in any sense they can act on. The field a
-- player is shown is their OWN culture's; leadership stays world-wide.
;(function()
    local ME   = "cr_roster_me"
    local RIVAL1, RIVAL2 = "cr_roster_rival_a", "cr_roster_rival_b"
    local DWARF   = "cr_roster_dwarf"      -- covered, and a different culture
    local FOREIGN = "cr_roster_lizard"     -- not covered at all
    local DWF = "wh_main_dwf_dwarfs"
    local outer_state, outer_model = GG.state, cm.model
    GG.state = {}
    GG.dead = {}
    GG.roster_cache = nil
    for _, f in ipairs({ME, RIVAL1, RIVAL2, DWARF, FOREIGN}) do
        GG.CULTURE_OF[f] = nil
    end

    -- A WORLD WITH CULTURES ON IT. The stub used by the AI-sweep test has name,
    -- is_human, is_dead and is_null_interface and NO culture() - so GG.roster read
    -- nothing out of it and every assertion below would have passed with the roster
    -- deleted. A double that cannot express the thing under test proves nothing, which
    -- is the same trap the dead-leader stub set earlier in this file.
    -- `home` and `forces` are what GG.present reads. GHOST is the quest-battle shape:
    -- carries the culture, sits in faction_list from turn one, owns nothing and never
    -- will. Vanilla has four of them in the Chaos Dwarf subculture alone - _qb1, _qb2,
    -- _qb3 and the dlc25 invasion - so a roster built from culture alone lists four
    -- placeholders and calls them rivals.
    local GHOST = "cr_roster_questbattle"
    local HORDE = "cr_roster_horde"
    local WORLD = {
        {name = ME,      culture = GG.CHD_CULTURE, home = true},
        {name = RIVAL1,  culture = GG.CHD_CULTURE, home = true},
        {name = RIVAL2,  culture = GG.CHD_CULTURE, home = true},
        {name = HORDE,   culture = GG.CHD_CULTURE, home = false, forces = 1},
        {name = GHOST,   culture = GG.CHD_CULTURE, home = false, forces = 0},
        {name = DWARF,   culture = DWF,            home = true},
        {name = FOREIGN, culture = "wh2_main_lzd_lizardmen", home = true},
    }
    local function world_stub(entries)
        return function()
            return {turn_number = function() return TURN end,
                    world = function()
                        return {faction_list = function()
                            local items = {}
                            for i = 1, #entries do
                                local e = entries[i]
                                items[i] = {
                                    is_null_interface = function() return false end,
                                    is_human = function() return false end,
                                    is_dead = function() return false end,
                                    name = function() return e.name end,
                                    culture = function() return e.culture end,
                                    flag_path = function()
                                        return "ui/flags/" .. e.name end,
                                    has_home_region = function()
                                        return e.home == true end,
                                    military_force_list = function()
                                        return {num_items = function()
                                            return e.forces or 0 end} end}
                            end
                            return LIST(items)
                        end}
                    end}
        end
    end
    cm.model = world_stub(WORLD)

    -- THE ROSTER IS ONE CULTURE'S FACTIONS, not every covered culture at once.
    local r = GG.roster(GG.CHD_CULTURE)
    assert(#r == 4, "the Chaos Dwarf roster must hold its own four PRESENT factions, "
           .. "got " .. #r .. " - listing every covered culture is what produced 127 "
           .. "rivals in Immortal Empires")
    local in_roster = {}
    for i = 1, #r do in_roster[r[i]] = true end
    assert(in_roster[ME] and in_roster[RIVAL1] and in_roster[RIVAL2],
           "every faction of the player's own culture must be listed")
    assert(not in_roster[DWARF],
           "a DWARF faction is in a Chaos Dwarf's league table - this is the 127 bug, "
           .. "and the Dwarf is covered, so a covered-culture test does not catch it")
    assert(not in_roster[FOREIGN], "and an uncovered culture is not listed either")

    -- A FACTION THAT OWNS NOTHING IS NOT A RIVAL. The quest-battle factions sit in
    -- faction_list from turn one with no region and no army, and vanilla has four of
    -- them in this subculture - so a roster built from culture alone tells the player
    -- they are racing four factions that do not exist yet.
    assert(not in_roster[GHOST],
           "a faction with no home region and no army is listed as a rival - that is "
           .. "the quest-battle and invasion placeholders padding the count")
    -- BUT A HORDE OWNS NO REGION EITHER, and is absolutely a rival.
    assert(in_roster[HORDE],
           "a horde owns no region and must still be listed - filtering on territory "
           .. "alone deletes every horde faction from the table")

    -- AND THE CREST CAME OFF THE INTERFACE THE WALK ALREADY HELD.
    assert(GG.FLAG_OF[RIVAL1] == "ui/flags/" .. RIVAL1,
           "faction:flag_path() must be captured during the walk, so the panel needs no "
           .. "baked copy of the factions table and a modded faction gets its own crest")
    assert(GG.FLAG_OF[GHOST] == nil,
           "a faction that is not in the race needs no crest recorded")

    -- EACH CULTURE GETS ITS OWN BUCKET, from the one walk.
    assert(#GG.roster(DWF) == 1, "the Dwarf roster is the Dwarf faction")

    -- THE WALK KNOWS NO CULTURE LIST, and these two assertions are the proof. A culture
    -- this mod has never heard of gets a bucket and an entry in GG.CULTURES purely
    -- because a faction in the campaign belongs to it - which is what makes the scope
    -- able to follow the player into Old World, Immortal Empires Expanded, the Hobgoblin
    -- Khanates or anything shipped next year. WHO RACES is a separate question, asked
    -- below and answered by GG.covered: having a bucket is not being in the race.
    assert(#GG.roster("wh2_main_lzd_lizardmen") == 1,
           "a culture present in the campaign must get its own bucket from the walk - "
           .. "if this needs an entry in a list somewhere, the scope can never follow "
           .. "the player into a modded culture")
    assert(GG.CULTURES["wh2_main_lzd_lizardmen"] == true,
           "and the scan must have discovered it without being told")
    -- A CULTURE WITH NOBODY IN THIS CAMPAIGN HAS NO ROSTER, which is not the same thing.
    assert(#GG.roster("wh_main_grn_greenskins") == 0,
           "a culture with no faction in this campaign must have an empty roster")

    -- AND THE WALK CACHES THE CULTURE IT ALREADY READ, so GG.covered does not go back to
    -- the engine per faction afterwards.
    assert(GG.CULTURE_OF[RIVAL1] == GG.CHD_CULTURE,
           "the culture read during the walk must be cached")
    assert(GG.culture_of(ME) == GG.CHD_CULTURE, "a covered faction races in its own")
    -- AND THIS ONE RACES IN NOTHING, even though the walk read its culture and gave it a
    -- bucket. A Chaos Dwarf is at the keyboard, so the Lizardmen are not in the race -
    -- this is the pair that separates "the scan is dynamic" from "everybody plays".
    assert(GG.culture_of(FOREIGN) == nil,
           "a faction outside the player's culture races in nothing, whatever the walk "
           .. "discovered about it")
    -- A FACTION WHOSE CULTURE CANNOT BE READ RACES IN NOTHING EITHER, for a different
    -- reason, and both halves have to hold.
    NO_SUCH_FACTION["cr_roster_unreadable"] = true
    assert(GG.culture_of("cr_roster_unreadable") == nil,
           "a faction with no readable culture must race in nothing")
    NO_SUCH_FACTION["cr_roster_unreadable"] = nil

    -- ONE BAD FACTION COSTS ITS OWN ROW AND NOTHING ELSE. The walk crosses every faction
    -- in the campaign - about 190 in Immortal Empires, most of them nothing to do with
    -- this mod - so a single interface that throws must not take the roster with it.
    GG.roster_cache = nil
    cm.model = function()
        return {turn_number = function() return TURN end,
                world = function()
                    return {faction_list = function()
                        return LIST({
                            {is_null_interface = function() return false end,
                             name = function() return RIVAL1 end,
                             has_home_region = function() return true end,
                             flag_path = function() return "ui/flags/a" end,
                             culture = function() return GG.CHD_CULTURE end},
                            {is_null_interface = function() return false end,
                             name = function() error("this one is broken") end,
                             has_home_region = function() return true end,
                             flag_path = function() return "ui/flags/b" end,
                             culture = function() return GG.CHD_CULTURE end},
                            {is_null_interface = function() return false end,
                             name = function() return RIVAL2 end,
                             has_home_region = function() return true end,
                             flag_path = function() return "ui/flags/c" end,
                             culture = function() return GG.CHD_CULTURE end}})
                    end}
                end}
    end
    local partial = GG.roster(GG.CHD_CULTURE)
    assert(#partial == 2,
           "a faction whose interface throws must cost only its own row, got "
           .. #partial .. " - one bad faction out of 190 must not empty the roster")
    GG.roster_cache = nil
    cm.model = world_stub(WORLD)
    assert(#GG.roster(GG.CHD_CULTURE) == 4, "and the good world still reads four")

    -- A GHOST THAT BANKS SOMETHING MUST STILL NOT HOLD THE GUILD. GG.present was
    -- filtering only the ROSTER, which is where the zero-reputation padding comes from -
    -- a faction that has actually earned arrives through GG.state and skipped the check
    -- entirely. Found in a dry run of the shipped Lua, not by any assertion above:
    -- wh3_dlc23_chd_chaos_dwarfs_qb1, no region and no army, sat at the head of the
    -- Brass Tablets on 5000 reputation and pushed the player to second. A scripted
    -- placeholder holding a guild, its bundle and its monopoly.
    GG.grant(GHOST, "brass", 5000)
    assert(GG.leader_of("brass", GG.CHD_CULTURE) ~= GHOST,
           "a faction with no region and no army is holding a guild on 5000 "
           .. "reputation - presence has to gate the STANDINGS, not just the roster")
    local sg = GG.standings("brass", GG.CHD_CULTURE)
    for i = 1, #sg do
        assert(sg[i].faction ~= GHOST, "and it must not be in the table either")
    end
    local cg = GG.contenders("brass", GG.CHD_CULTURE)
    for i = 1, #cg do
        assert(cg[i].faction ~= GHOST, "nor among the contenders")
    end

    -- BUT AN UNREADABLE WORLD MUST NOT DELETE THE LEAGUE. An empty roster means the
    -- world could not be read, not that the culture has no factions - and gating on it
    -- there would strip every leadership bundle in the campaign at once.
    GG.roster_cache = nil
    local good_model = cm.model
    cm.model = function() return nil end
    assert(#GG.roster(GG.CHD_CULTURE) == 0, "setup: the world reads as nothing")
    assert(#GG.standings("brass", GG.CHD_CULTURE) > 0,
           "an unreadable world emptied the standings - every guild would lose its "
           .. "leader and every leadership bundle would be stripped")
    cm.model = good_model
    GG.roster_cache = nil
    GG.state[GHOST] = nil

    -- NOBODY HAS EARNED ANYTHING YET, which is the state the panel was blank in.
    assert(#GG.standings("brass") == 0, "no faction has any standing yet")
    local c = GG.contenders("brass", GG.CHD_CULTURE)
    assert(#c == 4,
           "all four present rivals must be listed before any of them earns - " .. #c
           .. " listed. This is the turn-two panel, and an empty one reads as broken")
    assert(c[1].pos == 1 and c[4].pos == 4, "contenders carry positions too")

    -- BUT NONE OF THEM LEADS. Leadership reads GG.standings and keeps its rep > 0 rule;
    -- if contenders fed leadership instead, every guild would be held from turn one by
    -- whichever faction key sorts first.
    assert(GG.leader_of("brass", GG.CHD_CULTURE) == nil,
           "a guild nobody has earned with must still be led by nobody - listing the "
           .. "rivals must not crown one")

    -- THE PLAYER HAS A PLACE NOW, against their own culture's field.
    local pos, total = GG.position_of(ME, "brass")
    assert(pos and total == 4,
           "the player must be placed against their own culture, got " .. tostring(pos)
           .. "/" .. tostring(total))
    -- THE LIZARDMEN FACTION HAS NO POSITION AT ALL, because there is no league it is
    -- in: the race is the player's culture. The panel reads position_of for the "4/9"
    -- tag, so a faction outside the race must answer nothing rather than 1/1.
    assert(GG.position_of(FOREIGN, "brass") == nil,
           "a faction outside the player's culture must have no place in any league")
    -- A FACTION WHOSE CULTURE CANNOT BE READ HAS NO POSITION EITHER, for its own reason.
    NO_SUCH_FACTION["cr_pos_unreadable"] = true
    assert(GG.position_of("cr_pos_unreadable", "brass") == nil,
           "a faction with no readable culture must have no position at all")
    NO_SUCH_FACTION["cr_pos_unreadable"] = nil

    -- A DWARF FACTION WITH 5000 REPUTATION HOLDS NOTHING. This is the screenshot that
    -- started the whole culture question: Clan Angrund at the head of the Khanate and
    -- The Golden Order at the head of the Daemonsmiths, in a Chaos Dwarf campaign.
    --
    -- GG.grant IS USED ON PURPOSE HERE rather than GG.capped_grant, so the row exists in
    -- GG.state exactly the way a save written by the earlier build has it. Both rules
    -- then have to hold: it is not in this campaign's race, and leadership is asked per
    -- culture - so no question anyone asks has this faction as its answer.
    GG.grant(DWARF, "brass", 5000)
    assert(GG.leader_of("brass", GG.CHD_CULTURE) == nil,
           "a Dwarf faction took a Chaos Dwarf guild with 5000 reputation - that is the "
           .. "screenshot, exactly")
    assert(GG.leader_of("brass", DWF) == nil,
           "and it must not hold a Dwarf seat either - a Chaos Dwarf is playing, so "
           .. "this row is a leftover and the sweep has to be able to clear its bundle")
    local c_chd = GG.contenders("brass", GG.CHD_CULTURE)
    for i = 1, #c_chd do
        assert(c_chd[i].faction ~= DWARF,
               "the Dwarf must not appear in the Chaos Dwarf table either")
    end

    -- EARNING SORTS YOU ABOVE THE FIELD, and the zero-rep rivals stay listed underneath.
    GG.grant(ME, "brass", 9)
    local c2 = GG.contenders("brass", GG.CHD_CULTURE)
    assert(#c2 == 4, "the field does not shrink when somebody earns, got " .. #c2)
    assert(c2[1].faction == ME and c2[1].rep == 9,
           "an earner sorts above the factions still on zero")
    assert(c2[2].rep == 0 and c2[4].rep == 0, "and the rest keep their zero")
    assert(select(1, GG.position_of(ME, "brass")) == 1,
           "who is first of their own field")

    -- A DESTROYED RIVAL LEAVES THE FIELD without the roster being walked again.
    GG.dead[RIVAL1] = true
    local c3 = GG.contenders("brass", GG.CHD_CULTURE)
    assert(#c3 == 3, "a destroyed faction must leave the list, " .. #c3 .. " remain")
    for i = 1, #c3 do
        assert(c3[i].faction ~= RIVAL1, "the destroyed rival is still listed")
    end

    -- AN UNREADABLE WORLD IS NOT AN EMPTY ONE. The world cannot be read before the
    -- campaign is built, and caching nothing there would leave the tab empty for the
    -- rest of the session.
    GG.roster_cache = nil
    GG.dead = {}
    cm.model = function() return nil end
    assert(#GG.roster(GG.CHD_CULTURE) == 0, "an unreadable world yields no roster")
    cm.model = world_stub(WORLD)
    assert(#GG.roster(GG.CHD_CULTURE) == 4,
           "and the roster must come back once the world is readable - a failed read "
           .. "that cached itself would blank the tab for the whole session")

    -- THE HARDER HALF OF THAT: a world that answers, with a list that answers, whose
    -- ITEMS throw. The outer pcall succeeds, every inner one fails, and the walk ends
    -- with an empty list that looks exactly like a culture with no factions in it.
    GG.roster_cache = nil
    cm.model = function()
        return {turn_number = function() return TURN end,
                world = function()
                    return {faction_list = function()
                        return {num_items = function() return 3 end,
                                item_at = function() error("interface not ready") end}
                    end}
                end}
    end
    assert(#GG.roster(GG.CHD_CULTURE) == 0,
           "a walk whose every item throws yields no roster")
    cm.model = world_stub(WORLD)
    assert(#GG.roster(GG.CHD_CULTURE) == 4,
           "an EMPTY roster must never be cached - the items were unreadable for a "
           .. "moment and the tab would have stayed blank for the whole session")

    GG.state = outer_state
    cm.model = outer_model
    GG.roster_cache = nil
    GG.dead = {}
    for _, f in ipairs({ME, RIVAL1, RIVAL2, DWARF, FOREIGN}) do
        GG.CULTURE_OF[f] = nil
    end
end)()


-- ============================================================== THE UPKEEP ==========
-- What standing costs to hold. Taken from Medieval 2, which bleeds 1 point a turn per
-- guild per city from turn 25 - the thing that makes guild progress a race rather than a
-- ratchet. Before this, reputation in this mod only ever fell to a rival earning or a
-- demand going unanswered, so an AI that banked 400 on turn 30 held the guild, its bundle
-- and its monopoly for the rest of the campaign.
;(function()
    local U = "cr_upkeep"
    local prev_tune = GG.TUNE
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_decay = 100, decay_from = 25}))

    -- THE GRACE PERIOD IS REAL. An upkeep running from turn 1 is not a clock, it is a tax
    -- on the opening, and Medieval 2's own 25 is the default.
    GG.state[U] = nil
    GG.CULTURE_OF[U] = GG.CHD_CULTURE
    GG.grant(U, "brass", 500)
    local before = select(1, GG.get(U, "brass"))
    assert(GG.decay(U, 24) == 0, "nothing may be charged before the grace period ends")
    assert(select(1, GG.get(U, "brass")) == before, "and the reputation must not move")
    assert(GG.decay(U, 25) > 0, "the upkeep must start on the turn it says it does")

    -- SCALED BY RANK, which is the one place this departs from Medieval 2. Its tiers are
    -- 100/250/500 and ours are 0/100/300/700/1500, so a flat point a turn would be 1% of
    -- the first rank and 0.07% of the last - the top of the ladder would be the one place
    -- the clock stopped, and the top of the ladder is what carries the bundle and the
    -- monopoly. Charging the rank index keeps the pressure proportional the whole way up.
    assert(GG.decay_amount(1) == 1, "Unmarked costs 1 a turn at the default rate")
    assert(GG.decay_amount(5) == 5, "and Exalted costs 5, got " .. GG.decay_amount(5))
    assert(GG.decay_amount(5) > GG.decay_amount(2),
           "a higher rank must cost more to hold, or the seat that carries the leadership "
           .. "bundle is the one seat with no upkeep on it")

    -- REPUTATION ONLY, NEVER FAVOUR. Favour is the currency and is already capped at twice
    -- the rank threshold; charging upkeep against it would punish the same turn twice and
    -- make a saved-up purchase impossible rather than merely costly.
    GG.state[U] = nil
    GG.grant(U, "brass", 500)
    local r0, f0 = GG.get(U, "brass")
    GG.decay(U, 60)
    local r1, f1 = GG.get(U, "brass")
    assert(r1 < r0, "reputation must fall")
    assert(f1 == f0, "favour must not: it is the currency, not the standing")

    -- IT DEMOTES, AND THE BUNDLE COMES OFF WITH THE RANK. A demotion that leaves the
    -- ladder buff applied is a bonus the player keeps for a rank they no longer hold.
    GG.state[U] = nil
    GG.grant(U, "brass", 100)          -- exactly rank 2, Indebted
    assert(GG.rank_of(select(1, GG.get(U, "brass"))) == 2, "setup: rank 2")
    local rmark = #removed
    GG.decay(U, 60)
    assert(GG.rank_of(select(1, GG.get(U, "brass"))) == 1, "the upkeep must be able to "
           .. "cost a rank, or it is a number that never reaches anything")
    local stripped = false
    for i = rmark + 1, #removed do
        if removed[i][1] == GG.bundle_key("brass", 2) and removed[i][2] == U then
            stripped = true
        end
    end
    assert(stripped,
           "the rank 2 bundle is still on a faction that has fallen to rank 1 - a "
           .. "demotion has to take the buff with it")

    -- IT CANNOT OVERDRAW, AND THE REASON IS WORTH PINNING. The charge is read off the rank
    -- CURRENTLY held, never a remembered one - so a faction whose reputation has fallen to
    -- 3 is charged 1, the Unmarked rate, and not the 5 it owed while it was Exalted. That
    -- is what makes the whole thing safe without a clamp: the smallest reputation at any
    -- rank is far above that rank's charge, so the two can never cross. A version that
    -- cached the rank would drive reputation negative, and a negative reputation reads as
    -- rank 1 forever while GG.standings filters the faction out on rep > 0 - a faction
    -- both in the save and absent from its own league, permanently.
    GG.state[U] = nil
    GG.grant(U, "brass", 1500)              -- Exalted: 5 a turn
    assert(GG.decay_amount(GG.rank_of(1500)) == 5, "setup: Exalted owes 5")
    GG.penalise(U, "brass", 1497)           -- leave 3, well below the Exalted charge
    assert(select(1, GG.get(U, "brass")) == 3, "setup: 3 reputation left")
    assert(GG.decay(U, 60) == 1,
           "the charge must follow the rank held NOW - a remembered rank would take 5 "
           .. "from a faction holding 3 and drive it negative")
    assert(select(1, GG.get(U, "brass")) == 2, "leaving 2")
    -- And the floor itself, on the function the charge goes through.
    assert(GG.penalise(U, "brass", 999) == 2,
           "GG.penalise must clamp to what is held, whatever it is asked for")
    assert(select(1, GG.get(U, "brass")) == 0, "landing on exactly zero, never below")
    assert(GG.decay(U, 60) == 0, "and a guild at zero must cost nothing more")

    -- IT TAKES MORE THAN ONE TURN TO DRAIN, which is the shape of the whole mechanic:
    -- Medieval 2's point is a slow bleed nobody notices until a tier is gone, not a wipe.
    GG.state[U] = nil
    GG.grant(U, "brass", 2)                 -- Unmarked: 1 a turn
    assert(GG.decay(U, 60) == 1 and select(1, GG.get(U, "brass")) == 1,
           "one turn at Unmarked costs exactly 1")
    assert(GG.decay(U, 61) == 1 and select(1, GG.get(U, "brass")) == 0,
           "and the second turn finishes it")

    -- EVERY GUILD, not just the one that earned. This walks GG.state, which is where the
    -- charge belongs: a faction only enters it once it has earned, so this touches exactly
    -- the factions with something to lose.
    GG.state[U] = nil
    GG.grant(U, "brass", 400)
    GG.grant(U, "slavers", 400)
    GG.decay(U, 60)
    assert(select(1, GG.get(U, "brass")) < 400
           and select(1, GG.get(U, "slavers")) < 400,
           "the upkeep must charge every guild with standing, not the first one found")

    -- AND A FACTION WITH NOTHING COSTS NOTHING, rather than erroring on a nil table.
    assert(GG.decay("cr_upkeep_never_seen", 60) == 0,
           "a faction with no standing at all must not be charged")

    -- ZERO IS THE OFF SWITCH, THROUGH THE REAL PIPELINE. Overriding GG.setting here would
    -- prove only that the function was called; this is the fifth settings assertion in
    -- this mod written that way after four earlier ones passed while guarding nothing.
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_decay = 0}))
    GG.state[U] = nil
    GG.grant(U, "brass", 400)
    assert(GG.decay_amount(5) == 0, "rate_decay 0 must charge nothing")
    assert(GG.decay(U, 999) == 0, "and the whole sweep must be a no-op")
    assert(select(1, GG.get(U, "brass")) == 400, "with the reputation untouched")

    -- SO IS decay_from 0, which is what the slider's own tooltip promises.
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_decay = 100, decay_from = 0}))
    assert(GG.decay_due(999) == false,
           "decay_from 0 must switch the upkeep off, as its slider says it does")

    -- A LOW RATE STILL COSTS SOMETHING rather than rounding to free - the same floor
    -- GG.rival_cost keeps, for the same reason.
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_decay = 1, decay_from = 25}))
    assert(GG.decay_amount(1) == 1,
           "a rate too small to floor above zero must still charge 1, or a slider at the "
           .. "bottom of its range reads as on and behaves as off")

    GG.state[U] = nil
    GG.CULTURE_OF[U] = nil
    GG.TUNE = prev_tune
end)()

-- ================================================== A BOUNTY TAKEN AND NOT DONE =====
-- Medieval 2 pays +10 and +20 for its guild missions and charges -10 and -20 for failing
-- them, the same magnitude either way, and its guide's whole advice is "do not fail them".
-- This mod charged nothing: one handler was registered for MissionFailed and
-- MissionCancelled together, so taking a job and not delivering cost exactly the offer.
;(function()
    local B = "cr_bfail"
    local prev_tune = GG.TUNE
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_bounty_fail = 100, rate_bounty = 80}))
    GG.CULTURE_OF[B] = GG.CHD_CULTURE

    local function offer(guild, rep, taken)
        GG.bounties[B] = {{guild = guild, kind = GG.BOUNTIES[guild], target = "r_x",
                           owner = "", gold = 1000, rep = rep, diff = 0,
                           posted = 1, taken = taken}}
    end

    -- FAILING COSTS WHAT FINISHING WOULD HAVE PAID. Priced off the offer's own stored rep,
    -- which GG.make_bounty already scaled by the job's difficulty - so a failed Grim job
    -- costs more than a failed Routine one with no second difficulty read.
    GG.state[B] = nil
    GG.grant(B, "brass", 500)
    offer("brass", 120, true)
    local guild, took = GG.bounty_failed(B, GG.bounty_mission_key("brass"))
    assert(guild == "brass", "the failure must name the guild whose work it was")
    assert(took == 120,
           "a failed bounty must cost what it would have paid, got " .. tostring(took))
    assert(select(1, GG.get(B, "brass")) == 380, "and the reputation must actually go")
    assert(#GG.bounties[B] == 0, "the slot must clear so the guild can post again")

    -- HANDING IT BACK IS FREE, and that distinction is the whole change. The old comment
    -- was right that a guild punishing you for DECLINING work is a guild you stop dealing
    -- with; it was being applied to failing as well, which is not the same thing.
    GG.state[B] = nil
    GG.grant(B, "brass", 500)
    offer("brass", 120, true)
    assert(GG.bounty_lost(B, GG.bounty_mission_key("brass")) == true,
           "a hand-back must still clear the slot")
    assert(select(1, GG.get(B, "brass")) == 500,
           "and must cost nothing - declining work is free, only failing is not")
    assert(#GG.bounties[B] == 0, "with the slot cleared either way")

    -- AN OFFER NOBODY TOOK CANNOT BE FAILED. It sits on the board, expires on its own
    -- clock and costs nothing; only a promise can be broken.
    GG.state[B] = nil
    GG.grant(B, "brass", 500)
    offer("brass", 120, false)
    assert(GG.bounty_failed(B, GG.bounty_mission_key("brass")) == nil,
           "an untaken offer must not be chargeable")
    assert(select(1, GG.get(B, "brass")) == 500, "with no reputation taken")
    assert(#GG.bounties[B] == 1, "and the offer still on the board")

    -- A MISSION KEY THIS MOD DID NOT ISSUE IS NOT OURS. Every mission in the campaign
    -- raises MissionFailed, including CA's own and every other mod's.
    offer("brass", 120, true)
    assert(GG.bounty_failed(B, "some_other_mods_mission") == nil,
           "a mission key from elsewhere must not charge a guild here")
    assert(#GG.bounties[B] == 1, "nor clear our own slot")

    -- ZERO IS THE OFF SWITCH, through pack_tune rather than by stubbing GG.setting.
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_bounty_fail = 0}))
    GG.state[B] = nil
    GG.grant(B, "brass", 500)
    offer("brass", 120, true)
    local g2, t2 = GG.bounty_failed(B, GG.bounty_mission_key("brass"))
    assert(g2 == "brass" and t2 == 0,
           "rate_bounty_fail 0 must clear the slot and charge nothing, got "
           .. tostring(t2))
    assert(select(1, GG.get(B, "brass")) == 500, "with the reputation untouched")
    assert(#GG.bounties[B] == 0, "and the slot still freed")

    -- IT IS SAID OUT LOUD. A reputation loss with no cause on screen is the exact fault
    -- this mod fixed on the demand clock; the upkeep is shown on the panel instead,
    -- because it arrives every turn and an interrupt every turn is not information.
    local prev_getter = cm.get_human_factions
    cm.get_human_factions = function() return {B} end
    local fmark = #feed
    GG.announce_bounty_fail(B, "brass", 120)
    assert(#feed > fmark, "a failed bounty must reach the event feed")
    assert(feed[#feed][3] == GG.FEED_INDEX_DEMAND,
           "on a real feed record index, or show_message_event draws nothing at all")
    -- AND NOT FOR AN AI. Every faction in the campaign raises MissionFailed.
    cm.get_human_factions = function() return {"cr_somebody_else"} end
    fmark = #feed
    GG.announce_bounty_fail(B, "brass", 120)
    assert(#feed == fmark, "an AI faction's failure is not an interrupt for the player")
    cm.get_human_factions = prev_getter

    GG.bounties[B] = nil
    GG.state[B] = nil
    GG.CULTURE_OF[B] = nil
    GG.TUNE = prev_tune
end)()

-- ====================================== THE WIRING, NOT THE FUNCTIONS ==============
;(function()
    assert(handlers["gg_turn"], "no FactionTurnStart handler is registered")
    assert(handlers["gg_bounty_MissionFailed"],
           "no MissionFailed handler is registered, so a bounty taken and not delivered "
           .. "costs nothing - which is the whole of what this change was")
    assert(handlers["gg_bounty_MissionCancelled"],
           "no MissionCancelled handler is registered, so handing work back leaves the "
           .. "slot filled and the guild can never post again")
    -- TWO HANDLERS, NOT ONE. They were registered together in a loop over both event
    -- names, which is exactly why failing was free: one body cannot charge for one event
    -- and not the other. If a later edit collapses them back into a loop, the two names
    -- resolve to the same function and this catches it.
    assert(handlers["gg_bounty_MissionFailed"] ~= handlers["gg_bounty_MissionCancelled"],
           "both mission events share one handler again - a single body cannot charge for "
           .. "a failure and not for a hand-back, which is the fault being fixed")

    local W = "cr_wired"
    CULTURE[W] = GG.CHD_CULTURE
    GG.CULTURE_OF[W] = GG.CHD_CULTURE
    local prev_getter = cm.get_human_factions
    cm.get_human_factions = function() return {W} end
    GG.player_cultures_cache = nil

    -- The settings the handler will snapshot. GG.snapshot_settings reads this saved value
    -- and freezes it into GG.TUNE, so seeding it here is how the real pipeline is driven
    -- rather than by assigning GG.TUNE and hoping the handler leaves it alone.
    saved["derpy_gg_tuned"] = GG.pack_tune({rate_decay = 100, decay_from = 25,
                                            rate_bounty_fail = 100, rate_brass = 250})

    local function turn_ctx(name, income, human, techs)
        return {faction = function()
            return {is_null_interface = function() return false end,
                    name = function() return name end,
                    net_income = function() return income end,
                    is_human = function() return human end,
                    -- scripting_doc: "How many technologies has this faction completed
                    -- researching?", returns int. nil here means the test does not care.
                    num_completed_technologies = function() return techs end}
        end}
    end

    -- THE UPKEEP IS ACTUALLY CALLED FROM THE TURN HANDLER. Zero income, so nothing is
    -- earned and the only thing that can move the number is the charge.
    -- SAVED, NOT JUST GRANTED. The handler's first act is GG.load, which replaces the
    -- live table with what is in the save - so a setup that only grants is quietly
    -- overwritten by whatever the previous sub-test left behind.
    GG.state[W] = nil
    GG.grant(W, "brass", 760)
    GG.save(W)
    TURN = 40
    handlers["gg_turn"](turn_ctx(W, 0, true))
    assert(select(1, GG.get(W, "brass")) == 756,
           "the turn handler must charge the upkeep - Favoured owes 4 and the reputation "
           .. "is " .. select(1, GG.get(W, "brass")) .. ", so the call is not wired in")

    -- AND IT IS SAVED. GG.save runs after the charge in that handler; without that the
    -- penalty lands on the live table and is thrown away at the next load, which is the
    -- exact fault the demand clock shipped with.
    GG.state[W] = nil
    GG.load(W)
    assert(select(1, GG.get(W, "brass")) == 756,
           "the charged reputation did not survive a reload - it read back as "
           .. select(1, GG.get(W, "brass")))

    -- NOT BEFORE THE GRACE PERIOD, through the handler rather than the function.
    GG.state[W] = nil
    GG.grant(W, "brass", 760)
    GG.save(W)
    TURN = 24
    handlers["gg_turn"](turn_ctx(W, 0, true))
    assert(select(1, GG.get(W, "brass")) == 760,
           "the handler charged before turn " .. GG.setting("decay_from"))

    -- THE AI IS CHARGED TOO, and it has to be: the upkeep exists so that an AI which
    -- banked 400 on turn 30 cannot hold a guild, its bundle and its monopoly for the rest
    -- of the campaign. Gating this on is_human would leave the league a ratchet for every
    -- faction except the one player.
    local WAI = "cr_wired_ai"
    CULTURE[WAI] = GG.CHD_CULTURE
    GG.CULTURE_OF[WAI] = GG.CHD_CULTURE
    GG.state[WAI] = nil
    GG.grant(WAI, "brass", 760)
    GG.save(WAI)
    TURN = 40
    handlers["gg_turn"](turn_ctx(WAI, 0, false))
    assert(select(1, GG.get(WAI, "brass")) == 756,
           "an AI faction was not charged the upkeep, so the standings stay a one-way "
           .. "ratchet for everyone but the player")

    -- THE AI'S DAEMONSMITHS COME OFF THE TECHNOLOGY COUNT, at its own turn start.
    -- ResearchCompleted never reaches an AI faction. Measured 2026-09-23: the handler saves
    -- derpy_gg_research_<faction> unconditionally, and in two campaigns (turns 24 and 83)
    -- only the human had the key - while every AI faction sat at Daemonsmiths 0,0.
    local function ds(f) return (select(1, GG.get(f, "daemonsmiths"))) end
    local rate_ds = GG.setting("rate_daemonsmiths")
    local TAI = "cr_wired_ai_tech"
    CULTURE[TAI] = GG.CHD_CULTURE
    GG.CULTURE_OF[TAI] = GG.CHD_CULTURE
    GG.state[TAI] = nil
    TURN = 10
    handlers["gg_turn"](turn_ctx(TAI, 0, false, 12))
    assert(ds(TAI) == 0,
           "the first count seen is a BASELINE, not income - a save loaded at turn 83 would "
           .. "otherwise pay every AI faction for thirty technologies at once; paid " .. ds(TAI))
    handlers["gg_turn"](turn_ctx(TAI, 0, false, 14))
    assert(ds(TAI) == 2 * rate_ds,
           "two technologies since last turn must pay the Daemonsmiths twice the rate ("
           .. 2 * rate_ds .. ") - paid " .. ds(TAI) .. ", so the AI still cannot earn them")
    handlers["gg_turn"](turn_ctx(TAI, 0, false, 14))
    assert(ds(TAI) == 2 * rate_ds, "an unchanged count must pay nothing")
    GG.state[TAI] = nil
    GG.load(TAI)
    assert(ds(TAI) == 2 * rate_ds,
           "the AI's Daemonsmiths did not survive a reload - GG.save must run after the count")

    -- THE PLAYER IS NOT PAID TWICE. ResearchCompleted does reach a human and already pays
    -- there, so the count must stay out of it.
    handlers["gg_turn"](turn_ctx(W, 0, true, 5))
    local w_before = ds(W)
    handlers["gg_turn"](turn_ctx(W, 0, true, 9))
    assert(ds(W) == w_before,
           "the turn-start count paid a HUMAN faction, which the event already pays - "
           .. "every technology would count twice")

    -- AND THE EVENT DOES NOT PAY AN AI, so a mod that raises ResearchCompleted for one
    -- (cm:instantly_research_technology on an AI faction would) cannot pay it twice either.
    local t_before = ds(TAI)
    handlers["gg_tech"]({faction = function()
                             return {is_null_interface = function() return false end,
                                     name = function() return TAI end} end,
                         technology = function() return "tech_forced_by_a_mod" end})
    assert(ds(TAI) == t_before,
           "ResearchCompleted paid an AI faction, which the turn-start count already pays")
    GG.state[TAI] = nil
    GG.CULTURE_OF[TAI] = nil

    -- A FACTION THE MOD DOES NOT COVER GETS NO COUNT AT ALL. Measured 2026-09-23 on the
    -- first live round: 277 derpy_gg_techs_ keys in the save, one per AI faction in the
    -- world, for the ~15 the grant can ever reach - the same bloat the ResearchStarted
    -- handler's comment already refuses.
    local UNC = "cr_wired_uncovered"
    CULTURE[UNC] = "wh2_main_lzd_lizardmen"
    GG.CULTURE_OF[UNC] = nil
    handlers["gg_turn"](turn_ctx(UNC, 0, false, 30))
    assert(saved["derpy_gg_techs_" .. UNC] == nil,
           "an uncovered faction was given a technology count - a saved value for every "
           .. "AI faction in the campaign, for a grant GG.covered refuses anyway")
    GG.CULTURE_OF[UNC] = nil

    -- THE TWO MISSION EVENTS, RAISED FOR REAL, one after the other on identical state.
    local function mission_ctx(name, mkey)
        return {faction = function()
                    return {is_null_interface = function() return false end,
                            name = function() return name end} end,
                mission = function()
                    return {mission_record_key = function() return mkey end} end}
    end
    local mk = GG.bounty_mission_key("brass")
    -- SAVED HERE TOO, for the same reason: the mission handlers open with
    -- GG.load_bounties, which replaces the board with what is in the save.
    local function board()
        GG.bounties[W] = {{guild = "brass", kind = GG.BOUNTIES["brass"], target = "r_x",
                           owner = "", gold = 3000, rep = 80, diff = 0,
                           posted = 1, taken = true}}
        GG.save_bounties(W)
    end

    GG.state[W] = nil
    GG.grant(W, "brass", 760)
    GG.save(W)
    board()
    handlers["gg_bounty_MissionFailed"](mission_ctx(W, mk))
    assert(select(1, GG.get(W, "brass")) == 680,
           "MissionFailed must charge the guild through the handler, got "
           .. select(1, GG.get(W, "brass")))
    assert(#GG.bounties[W] == 0, "and free the slot")
    -- SAVED, both halves: the board is one saved value and the standing is another, and
    -- the handler has to write both or the penalty is undone by the next load.
    GG.state[W] = nil
    GG.load(W)
    assert(select(1, GG.get(W, "brass")) == 680,
           "the failed bounty's penalty did not survive a reload, reading "
           .. select(1, GG.get(W, "brass")) .. " - GG.save is missing from the handler")

    GG.state[W] = nil
    GG.grant(W, "brass", 760)
    GG.save(W)
    board()
    handlers["gg_bounty_MissionCancelled"](mission_ctx(W, mk))
    assert(select(1, GG.get(W, "brass")) == 760,
           "MissionCancelled must cost nothing - handing work back is not failing it")
    assert(#GG.bounties[W] == 0, "and must still free the slot")

    -- ANOTHER MOD'S MISSION, through the handler. Every mission in the campaign raises
    -- these two events, including CA's own.
    GG.state[W] = nil
    GG.grant(W, "brass", 760)
    GG.save(W)
    board()
    handlers["gg_bounty_MissionFailed"](mission_ctx(W, "not_our_mission_at_all"))
    assert(select(1, GG.get(W, "brass")) == 760,
           "a mission from elsewhere charged one of our guilds")
    assert(#GG.bounties[W] == 1, "and took our offer off the board")

    GG.bounties[W] = nil
    GG.state[W] = nil
    GG.state[WAI] = nil
    GG.CULTURE_OF[W], GG.CULTURE_OF[WAI] = nil, nil
    cm.get_human_factions = prev_getter
    GG.player_cultures_cache = nil
    saved["derpy_gg_tuned"] = nil
    GG.TUNE = nil
end)()

-- ================================= BUILDINGS PAY THEIR OWN GUILD ==================
-- Every completed building used to pay the Overseers and nothing else, and the level was
-- thrown away: GG.on_building always took a level and multiplied by it, and the listener
-- always passed a hardcoded 1. So a tier-one hut paid what a tier-five fortress did, the
-- parameter was dead code, and the panel's own earning line promised "more at higher
-- levels" for a build that could not deliver it.
;(function()
    local B = "cr_build"
    CULTURE[B] = GG.CHD_CULTURE
    GG.CULTURE_OF[B] = GG.CHD_CULTURE
    local prev_getter = cm.get_human_factions
    cm.get_human_factions = function() return {B} end
    GG.player_cultures_cache = nil
    local prev_tune = GG.TUNE
    -- Caps off, so what a building pays can be read without the per-turn ceiling
    -- clipping it. The cap itself is tested elsewhere.
    GG.TUNE = GG.unpack_tune(GG.pack_tune({rate_overseers = 10, rate_decay = 0,
                                           cap_overseers = 0, cap_brass = 0,
                                           cap_immortals = 0, cap_daemonsmiths = 0,
                                           cap_khanate = 0, cap_slavers = 0}))

    -- ---- THE MAP, against CA's REAL chain keys ---------------------------------------
    -- These are not invented strings: every one is a chain that ships in the game, read
    -- out of building_levels. The generator's check_building_theme refuses any token that
    -- matches none of CA's 1,943 chains, because a token aimed at a chain nobody has
    -- looked at is indistinguishable from a typo.
    local REAL = {
        {"wh3_dlc23_chd_military_hobgoblins",     "immortals"},
        {"wh3_dlc23_chd_military_war_machines",   "immortals"},
        {"wh3_dlc23_chd_factory_assembly_line",   "daemonsmiths"},
        {"wh3_dlc23_chd_factory_refinery",        "daemonsmiths"},
        {"wh3_dlc23_chd_tower_furnace",           "daemonsmiths"},
        {"wh3_dlc23_chd_resource_gold",           "brass"},
        {"wh3_dlc23_chd_resource_obsidian",       "brass"},
        {"wh3_dlc23_chd_factory_port",            "brass"},
        {"wh3_dlc23_chd_tower_tribute_halls",     "brass"},
        {"wh3_dlc23_chd_outpost_watch_towers",    "khanate"},
        {"wh3_dlc23_chd_tower_patrol",            "khanate"},
        {"wh3_dlc23_chd_outpost_scavangers_hovel", "slavers"},
        {"wh3_dlc23_chd_settlement_factory",      "overseers"},
        {"wh3_dlc23_chd_outpost_mine",            "overseers"},
        {"wh3_dlc23_chd_tower_living_quaters",    "overseers"},
    }
    for i = 1, #REAL do
        local chain, want = REAL[i][1], REAL[i][2]
        assert(GG.guild_of_chain(chain) == want,
               chain .. " must belong to " .. want .. ", got "
               .. tostring(GG.guild_of_chain(chain)))
    end

    -- ---- LONGEST MATCH WINS, which is the rule that makes compounds work -------------
    -- These keys hold TWO tokens from different guilds, and list order decided them by
    -- accident of position before length did it by specificity.
    assert(GG.guild_of_chain("wh3_dlc23_chd_factory_port") == "brass",
           "a factory port is a port: `_port` must beat nothing, and a bare `factory` "
           .. "token would have taken it for the Daemonsmiths")
    assert(GG.guild_of_chain("wh3_dlc23_chd_military_kdaai") == "immortals",
           "military (8) must beat a shorter unit-name token, or one chain in a military "
           .. "group answers differently from its neighbours")
    assert(GG.guild_of_chain("wh3_dlc23_chd_tower_temple_guardhouse") == "immortals",
           "guardhouse (10) must beat temple (6)")
    assert(GG.guild_of_chain("wh3_dlc23_chd_tower_temple_of_hashut") == "overseers",
           "and a temple with no guardhouse in it stays a temple")

    -- ---- THE THREE BURIED MATCHES, each one a real false positive that shipped here --
    -- Found by scanning every token against every CA chain for a match not preceded by a
    -- word boundary. All three are the same shape: a short word inside a longer one.
    -- `support_artillery` is the case that FIRST showed the problem, and it cannot prove
    -- the fix: artillery (9) outranks port (4) either way. `ship_gunports` can - it holds
    -- no other token at all, so with a bare `port` it reads as a trade building and with
    -- `_port` it reads as nothing and falls to the Overseers, where a gun deck belongs
    -- rather less wrongly.
    assert(GG.guild_of_chain("wh2_dlc11_vampirecoast_ship_gunports") == nil,
           "`port` is buried in gun-PORTS - the token has to be `_port`, or 19 chains "
           .. "including every `support_` building read as trade")
    assert(GG.guild_of_chain("wh2_dlc11_vampirecoast_support_artillery") == "immortals",
           "and an artillery support building is still military")
    assert(GG.guild_of_chain("wh2_dlc17_bst_special_secondary_attributes") == nil,
           "`tribute` is buried in at-TRIBUTE-s - the token has to be `tribute_hall`")
    assert(GG.guild_of_chain("wh2_main_special_chamber_of_visions") == nil,
           "`amber` is buried in ch-AMBER - there is no amber chain to catch, so the "
           .. "token is gone entirely")

    -- ---- LENGTH BEATS ORDER, proved on a chain where the two disagree ---------------
    -- The three assertions above all happen to give the same answer under either rule,
    -- so none of them can tell length-wins from first-in-the-table-wins. This one can:
    -- the Khanate is listed BEFORE the Immortals and matches `patrol` (6), while the
    -- Immortals match `garrison` (8). A garrison is military, and only length says so.
    assert(GG.guild_of_chain("wh3_dlc27_hef_sea_patrol_outpost_defence_garrison")
           == "immortals",
           "garrison (8) must beat patrol (6) - if the table's own order decides this, "
           .. "then which guild a compound chain pays depends on where somebody happened "
           .. "to put a word in a list")

    -- ---- CASE, on the one chain where it actually changes the answer -----------------
    -- wh2_main_EMPIRE_academy matches either way, because `academy` is lowercase in it.
    -- This one does not: `beast` only appears once BEASTMEN is folded, and without that
    -- the chain falls to `_port` and pays the Brass Tablets instead of the Immortals.
    assert(GG.guild_of_chain("wh_dlc03_BEASTMEN_port") == "immortals",
           "wh_dlc03_BEASTMEN_port is spelled that way in CA's data - without lowercasing "
           .. "it reads as a port rather than a beast pen, and every token that lands on "
           .. "an uppercase segment is invisible")
    assert(GG.guild_of_chain("wh2_main_EMPIRE_academy") == "immortals",
           "and an uppercase segment must not stop a lowercase token matching either")

    -- ---- A CHAIN NOBODY CLAIMS, and the two unreadable cases ------------------------
    assert(GG.guild_of_chain("wh2_dlc09_tmb_ushabti") == nil,
           "a chain whose name shares no vocabulary must answer nil, not a guess - 40% "
           .. "of CA's chains are landmarks and race-specific names like this one")
    assert(GG.guild_of_chain(nil) == nil, "no chain, no guild")
    assert(GG.guild_of_chain("") == nil, "and an empty one is not a match on everything")

    -- ---- WHAT IT PAYS ---------------------------------------------------------------
    -- The themed guild, not the Overseers.
    GG.state[B] = nil
    GG.reset_turn(B)
    GG.on_building(B, 1, "wh3_dlc23_chd_military_hobgoblins")
    assert(select(1, GG.get(B, "immortals")) > 0,
           "a barracks must pay the Immortals")
    assert(select(1, GG.get(B, "overseers")) == 0,
           "and must NOT also pay the Overseers - one building, one guild, which is how "
           .. "Medieval 2 does it and what makes the choice of what to build a choice")

    -- AN UNCLAIMED CHAIN STILL PAYS THE OVERSEERS. This is the whole of the old
    -- behaviour, kept as the default, so nothing got quieter than it was.
    GG.state[B] = nil
    GG.reset_turn(B)
    GG.on_building(B, 1, "wh2_dlc09_tmb_ushabti")
    assert(select(1, GG.get(B, "overseers")) > 0,
           "a chain no guild claims must still pay the Overseers - they are the guild of "
           .. "building, and a building that pays nothing is a route gone silent")

    -- AND SO DOES NO CHAIN AT ALL, which is what a failed engine read looks like.
    GG.state[B] = nil
    GG.reset_turn(B)
    GG.on_building(B, 1, nil)
    assert(select(1, GG.get(B, "overseers")) > 0,
           "an unreadable chain must fall back rather than pay nobody")

    -- ---- THE LEVEL, WHICH IS THE HALF THAT WAS DEAD ---------------------------------
    local function paid(level, chain)
        GG.state[B] = nil
        GG.reset_turn(B)
        GG.on_building(B, level, chain)
        return select(1, GG.get(B, GG.guild_of_chain(chain) or "overseers"))
    end
    local CH = "wh3_dlc23_chd_resource_gold"
    assert(paid(5, CH) > paid(2, CH),
           "a higher level must pay more - the listener passed a hardcoded 1 for the "
           .. "whole life of this mod, so the panel's 'more at higher levels' was a lie")
    assert(paid(2, CH) > paid(1, CH), "and every step up must count")

    -- FLOORED AT 1, NOT TRUSTED. CA documents building_level() only as "Level of this
    -- building"; the DB's own level column is 0-BASED, with 1,943 of 5,259 rows at 0. So
    -- a 0 must pay the base rate rather than nothing, or the first tier of every chain
    -- would be silently free.
    assert(paid(0, CH) == paid(1, CH),
           "level 0 must pay the base rate - the DB column is 0-based, so if the engine "
           .. "call is too then the first tier of every building would pay nothing")
    assert(paid(-3, CH) == paid(1, CH), "and a negative cannot pay negatively")
    assert(paid(nil, CH) == paid(1, CH), "nor can an unreadable level pay nothing")

    -- CEILINGED, so a modded building reporting something strange cannot pay a hundred
    -- times the rate into a guild.
    assert(paid(9999, CH) == paid(10, CH),
           "an absurd level must clamp - paid " .. paid(9999, CH) .. " against a rate of "
           .. tostring(GG.setting("rate_overseers")))

    -- ---- THE LISTENER, which is where the bug actually lived ------------------------
    -- Every assertion above drives GG.on_building directly. The fault being fixed was in
    -- the HANDLER: it read neither the level nor the chain off the event and passed a
    -- hardcoded 1 with no chain at all, so all of the above would pass with the bug
    -- still shipping.
    assert(handlers["gg_building"], "no BuildingCompleted handler is registered")

    -- CA'S EVENT MEMBER FOR MEMBER: building and garrison_residence, and NOTHING ELSE.
    -- This fake used to carry a top-level faction() as well. BuildingCompleted has none -
    -- scripting_doc lists exactly those two accessors, and every one of CA's shipped
    -- handlers reads context:building():faction() - so the handler called context:faction(),
    -- the pcall around it ate the missing member, and every building for every faction paid
    -- nothing from the day the mod shipped. Measured 2026-09-23: Overseers 0,0 for all nine
    -- AI factions at turn 83. The fake answered a question the engine does not, which is
    -- the only reason this block ever passed.
    local function faction_iface(name)
        return {is_null_interface = function() return false end,
                name = function() return name end}
    end
    local function build_ctx(name, level, chain, broken)
        return {building = function()
                    if broken == "building" or broken == "both" then
                        error("no building on this event")
                    end
                    return {is_null_interface = function() return false end,
                            faction = function()
                                if broken == "faction" then error("no faction") end
                                return faction_iface(name) end,
                            building_level = function()
                                if broken == "level" then error("no level") end
                                return level end,
                            chain = function()
                                if broken == "chain" then error("no chain") end
                                return chain end}
                end,
                garrison_residence = function()
                    if broken == "both" then error("no garrison either") end
                    return {faction = function() return faction_iface(name) end}
                end}
    end

    -- MEASURED AS A DELTA, not against zero. GG.save RETURNS EARLY on a nil state, so
    -- clearing GG.state and saving does not clear the saved value - the handler's own
    -- GG.load then restores whatever the previous call left there, and a test that reads
    -- the absolute number is really reading the sum of every call before it.
    local function raised(level, chain, broken)
        GG.reset_turn(B)
        local function rep(g) return (select(1, GG.get(B, g))) end
        local was = {}
        for i = 1, #GG.GUILDS do was[GG.GUILDS[i]] = rep(GG.GUILDS[i]) end
        handlers["gg_building"](build_ctx(B, level, chain, broken))
        local moved = {}
        for i = 1, #GG.GUILDS do
            local g = GG.GUILDS[i]
            local d = rep(g) - was[g]
            if d ~= 0 then moved[g] = d end
        end
        return moved
    end

    local got = raised(3, "wh3_dlc23_chd_factory_refinery")
    assert(next(got) ~= nil,
           "a completed building paid NO guild at all - the handler must find the owner "
           .. "through context:building():faction(), because BuildingCompleted has no "
           .. "context:faction() and a pcall around one fails every time, silently")
    assert((got.daemonsmiths or 0) > 0,
           "the handler must read the CHAIN off the event - it passed no chain at all "
           .. "before, so a refinery paid the Overseers")
    assert(got.overseers == nil, "and not the Overseers as well")
    local three = got.daemonsmiths

    local one = raised(1, "wh3_dlc23_chd_factory_refinery")
    assert((one.daemonsmiths or 0) < three,
           "the handler must read the LEVEL off the event - it passed a hardcoded 1, so "
           .. "a tier-five fortress paid exactly what a tier-one hut did: level 1 raised "
           .. tostring(one.daemonsmiths) .. " and level 3 raised " .. three)

    -- AND IT SURVIVES A RELOAD, since GG.save runs after the grant in that handler.
    local banked = select(1, GG.get(B, "daemonsmiths"))
    GG.state[B] = nil
    GG.load(B)
    assert(select(1, GG.get(B, "daemonsmiths")) == banked,
           "the grant did not survive a reload - it read back as "
           .. select(1, GG.get(B, "daemonsmiths")) .. " against " .. banked
           .. ", so GG.save is missing from the handler")

    -- EACH OF THE THREE READS CAN FAIL AND THE BUILDING STILL PAYS. A guild that only
    -- earns when three engine calls all answer is a guild that goes quiet for a whole
    -- campaign the first time one of them does not.
    -- faction() is the fourth: the owner is read off the building first and off the
    -- garrison second, so either one alone is enough to find who gets paid.
    for _, broken in ipairs({"building", "level", "chain", "faction"}) do
        local d = raised(3, "wh3_dlc23_chd_factory_refinery", broken)
        local any = (d.daemonsmiths or 0) + (d.overseers or 0)
        assert(any > 0,
               "with " .. broken .. "() throwing, the building paid nothing at all - a "
               .. "failed read must cost the theme or the scaling, never the grant")
    end

    -- WITH NEITHER ROUTE TO THE OWNER, NOBODY IS PAID - and nothing throws. There is no
    -- faction to hand the grant to, and guessing one is how every faction in the game once
    -- read as Chaos Dwarf.
    local none = raised(3, "wh3_dlc23_chd_factory_refinery", "both")
    assert(next(none) == nil,
           "with no building and no garrison the handler must pay nobody")

    GG.state[B] = nil
    GG.CULTURE_OF[B] = nil
    cm.get_human_factions = prev_getter
    GG.player_cultures_cache = nil
    GG.TUNE = prev_tune
end)()

-- ================================ THE STANDINGS FACTION LIST =====================
-- The tab named the LEADER of each guild and where you sat ("4/9") and nothing in
-- between, so a player could see they were fourth and never learn who the three above
-- them were. The full table existed only as a five-deep hover.
--
-- WHAT IS TESTABLE HERE is the text of a row and which guild the list is about. Whether
-- the engine actually scrolls is not: that lives in four reserved component names and
-- three reserved callbacks in derpy_gg_list.twui.xml, and tools/gen_guilds_ui.py
-- check_scroll_parts() checks those against CA's own file instead.
;(function()
    local A, B, C = "cr_l_a", "cr_l_b", "cr_l_c"
    for _, f in ipairs({A, B, C}) do
        GG.CULTURE_OF[f] = GG.CHD_CULTURE
    end
    -- An OTHER-culture faction, which must never appear: this list exists because the
    -- request was "only same culture, not 127 factions".
    local X = "cr_l_x"
    GG.CULTURE_OF[X] = "wh_main_grn_greenskins"
    GG.CULTURES[GG.CHD_CULTURE] = true
    GG.CULTURES["wh_main_grn_greenskins"] = true
    GG.roster_cache = {[GG.CHD_CULTURE] = {A, B, C},
                       ["wh_main_grn_greenskins"] = {X}}

    local prev_state = GG.state
    GG.state = {[A] = {brass = {rep = 500, fav = 0}},
                [B] = {brass = {rep = 900, fav = 0}}}

    -- ---- WHICH GUILD THE LIST IS ABOUT ----------------------------------------------
    GGUI.STAND_GUILD = 2
    local g, i = GGUI.stand_guild()
    assert(g == GG.GUILDS[2] and i == 2, "the list follows the selected row")

    -- CLAMPED, NOT TRUSTED. The index is set from a component name at click time, and an
    -- out-of-range one would index nil and take the whole draw down with it.
    GGUI.STAND_GUILD = 99
    assert(GGUI.stand_guild() == GG.GUILDS[1], "an impossible index falls back to the first")
    GGUI.STAND_GUILD = 0
    assert(GGUI.stand_guild() == GG.GUILDS[1], "and so does a zero")
    GGUI.STAND_GUILD = nil
    assert(GGUI.stand_guild() == GG.GUILDS[1], "and so does nothing at all")
    GGUI.STAND_GUILD = 1

    -- ---- WHO IS IN IT ---------------------------------------------------------------
    local rows = GG.contenders("brass", GG.CHD_CULTURE)
    local names = {}
    for k = 1, #rows do names[rows[k].faction] = true end
    assert(names[A] and names[B] and names[C],
           "every present faction of the culture is a contender, earner or not")
    assert(not names[X],
           "a faction of another culture must NOT be listed - this list exists because "
           .. "the whole world's 127 factions is not a league table")
    assert(rows[1].faction == B and rows[1].rep == 900,
           "the list is ordered, highest first")
    assert(rows[1].pos == 1 and rows[2].pos == 2, "and carries its own positions")

    -- ---- WHAT ONE ROW SAYS ----------------------------------------------------------
    GG.FLAG_OF[B] = "ui/flags/cr_test_flag"
    local line = GGUI.frow_text(rows[1], A)
    assert(string.find(line, "cr_test_flag/mon_24%.png"),
           "the row draws the faction's own crest: " .. line)
    assert(string.find(line, "%[%[img:"), "the crest is INLINE markup, not a child - a "
           .. "child is placed by absolute MoveTo and would be left behind the moment "
           .. "the list scrolled")
    assert(string.find(line, "900"), "and the reputation")

    -- A FACTION WITH NO READABLE FLAG STILL GETS A CREST. flag_path() is read once in a
    -- scan that pcalls per faction, so one unreadable interface means one missing path -
    -- and a path that resolves to nothing draws nothing and says nothing about it.
    GG.FLAG_OF[C] = nil
    local crow
    for k = 1, #rows do if rows[k].faction == C then crow = rows[k] end end
    assert(crow, "C must be in the list")
    assert(string.find(GGUI.frow_text(crow, A), "chd_chaos_dwarfs/mon_24%.png"),
           "no flag on record must fall back rather than draw a gap")

    -- YOUR OWN ROW IS MARKED. Six names with one of them being you is the list a player
    -- reads three times without finding themselves.
    local mine
    for k = 1, #rows do if rows[k].faction == A then mine = rows[k] end end
    assert(string.find(GGUI.frow_text(mine, A), "col:yellow"),
           "your own row must be marked")
    assert(not string.find(GGUI.frow_text(rows[1], A), "col:yellow"),
           "and a rival's row must not be")

    -- THE COLOUR TAGS MUST NOT WRAP THE IMAGE. Overlapping markup is a guess about the
    -- renderer, and an unknown colour name is consumed silently rather than erroring, so
    -- a nesting mistake here would be invisible on screen.
    local m = GGUI.frow_text(mine, A)
    assert(string.find(m, "^%[%[img:"), "the image opens the line, outside any colour tag")

    -- ---- WHAT THE DRAW WOULD LIST ---------------------------------------------------
    -- Through GGUI.list_rows, which is the draw's own first call - not GG.contenders
    -- directly. The culture argument is the whole request ("only same culture, not 127
    -- factions") and it lives in the UI file, so testing the model's function instead
    -- would pass with the panel listing the entire world.
    GGUI.STAND_GUILD = 1
    local lrows, lguild = GGUI.list_rows(A)
    assert(lguild == "brass", "the list follows the selected row, got " .. tostring(lguild))
    local lseen = {}
    for k = 1, #lrows do lseen[lrows[k].faction] = true end
    assert(lseen[A] and lseen[B] and lseen[C], "every present faction of the culture")
    assert(not lseen[X], "and NOT a faction of another culture - the draw must pass the "
           .. "culture through, not just the model")

    -- ---- AND THE STANDINGS DRAW REACHES IT ------------------------------------------
    -- Every comp() lookup is nil here, so a draw that ran and found no panel and a draw
    -- that was never called look identical from outside. GGUI.LIST_LAST is written before
    -- the first lookup precisely so they do not.
    GGUI.LIST_LAST = -1
    GGUI.draw_faction_list(A)
    assert(GGUI.LIST_LAST == #lrows,
           "draw_faction_list must build the rows before it looks for components")
    GGUI.LIST_LAST = -1
    GGUI.draw_standings(A)
    assert(GGUI.LIST_LAST == #lrows,
           "draw_standings must reach the faction list - without that call the tab draws "
           .. "its six rows and the list under them stays empty forever")

    GG.state = prev_state
    GG.roster_cache = nil
    for _, f in ipairs({A, B, C, X}) do
        GG.CULTURE_OF[f] = nil
        GG.FLAG_OF[f] = nil
    end
end)()

-- ---------------------------------------------------------------------------
-- A LOAD MUST RESTORE THE WHOLE LEAGUE, NOT ONE FACTION AT A TIME.
--
-- GG.state is session-only and was refilled lazily: GG.load runs at a faction's OWN
-- FactionTurnStart, and GGAI.run_turn loads the AI once a round. Neither has happened
-- when a save is loaded mid-turn - which is every save a player makes - so GG.state is
-- empty for the rest of that turn. GG.standings reads GG.state, so every guild showed
-- an empty table and GG.leader_of named nobody: "the rankings reset and no guild has a
-- leader", reported from a live campaign on 2026-09-16.
--
-- Every OTHER record already had a restore path outside the turn handler - bounties,
-- the demand, the patron, research and the world record are all re-read when the panel
-- opens. The standings, the one record the mod is about, were the only ones that were
-- not.
do
    local A, B = "cr_reload_a", "cr_reload_b"
    local CHD = GG.CHD_CULTURE
    GG.CULTURE_OF[A], GG.CULTURE_OF[B] = CHD, CHD
    GG.state[A], GG.state[B] = nil, nil
    GG.grant(A, "brass", 400)
    GG.grant(B, "brass", 200)
    GG.save(A)
    GG.save(B)

    -- THE LOAD. Everything the script keeps in memory goes; the saved values stay,
    -- which is exactly what a save load leaves behind.
    GG.state = {}
    GG.leaders_now = {}
    GG.roster_cache = nil
    GG.player_cultures_cache = nil
    cm.model = function()
        return {turn_number = function() return TURN end,
                world = function()
                    return {faction_list = function()
                        local items = {}
                        for i, e in ipairs({THE_PLAYER, A, B}) do
                            items[i] = {
                                is_null_interface = function() return false end,
                                is_human = function() return e == THE_PLAYER end,
                                is_dead = function() return false end,
                                name = function() return e end,
                                culture = function() return CHD end,
                                flag_path = function() return "ui/flags/" .. e end,
                                has_home_region = function() return true end}
                        end
                        return LIST(items)
                    end}
                end}
    end

    -- THROUGH THE FIRST TICK, not by calling the recovery directly. A function that
    -- restores the league and is wired to nothing is the bug, unchanged.
    for i = 1, MODEL_TICKS do FIRST_TICKS[i]() end

    local back = GG.standings("brass", CHD)
    assert(#back == 2,
           "a save load must restore every faction's standing before anything else "
           .. "runs, got " .. #back .. " rows - GG.state is empty until each faction's "
           .. "own turn start, so the panel reads zero for the rest of the turn")
    assert(GG.leader_of("brass", CHD) == A,
           "and the guild must still have its leader, got "
           .. tostring(GG.leader_of("brass", CHD)))
    assert(select(1, GG.get(A, "brass")) == 400,
           "with the reputation it was saved on, got " .. select(1, GG.get(A, "brass")))

    GG.state[A], GG.state[B] = nil, nil
    GG.CULTURE_OF[A], GG.CULTURE_OF[B] = nil, nil
    GG.roster_cache = nil
    GG.player_cultures_cache = nil
    cm.model = function() return {turn_number = function() return TURN end} end
end

-- ---------------------------------------------------------------------------
-- A PAYLOAD THAT RAISES AN EVENT MUST NOT UNDO ITS OWN PAYMENT.
--
-- Two of the eighteen services fire a call the mod itself listens for:
-- bound_blueprint raises ResearchCompleted through cm:instantly_research_technology, and
-- raise_ziggurat raises BuildingCompleted through
-- cm:region_slot_instantly_upgrade_building. Both handlers open with `GG.load(name)`,
-- which overwrites GG.state AND GG.cooldowns from the saved value - and GG.buy fired the
-- payload while the purchase was still only in memory, because the save lived in the
-- CALLER (the panel's click handler, and GGAI's two).
--
-- So if the engine raises the event inside the call, the favour comes straight back and
-- the cooldown never starts. Reported from a live campaign on 2026-09-16 as "the instant
-- research being reverted" - the technology does complete, it is the payment that is
-- rolled back.
--
-- Whether the engine raises it synchronously is not knowable offline, which is the point:
-- the shipped code was relying on an ordering nobody has ever checked. Saving before the
-- payload is correct under BOTH orderings.
;(function()
    local F = "cr_reentry"
    local REWARD = GG.setting("rate_daemonsmiths") or 60
    -- A HUMAN BUYER. Bound Blueprint is human-only (GGAI.EXCLUDED), and since 2026-09-23
    -- ResearchCompleted pays humans only - the AI is paid off its technology count - so a
    -- fixture that is not a human would test a purchase nobody can make.
    local prev_humans = cm.get_human_factions
    cm.get_human_factions = function() return {F} end
    GG.humans, GG.player_cultures_cache = nil, nil
    GG.CULTURE_OF[F] = GG.CHD_CULTURE
    GG.state[F], GG.cooldowns[F] = nil, nil
    GG.grant(F, "daemonsmiths", 400)
    GG.save(F)
    GG.set_research(F, "tech_reentry")
    local fav_before = select(2, GG.get(F, "daemonsmiths"))
    local cost = GG.service_cost(F, "bound_blueprint")

    -- THE ENGINE, RAISING THE EVENT INSIDE THE CALL.
    local real_research = cm.instantly_research_technology
    cm.instantly_research_technology = function(s, f, t, n)
        real_research(s, f, t, n)
        handlers["gg_tech"]({
            faction = function()
                return {name = function() return f end,
                        is_null_interface = function() return false end}
            end,
            technology = function() return t end})
    end
    local bought = GG.buy(F, "bound_blueprint", GG.research_target(F))
    cm.instantly_research_technology = real_research

    assert(bought, "bound_blueprint must be buyable at rank 4 with 400 favour")
    assert(GG.cooldown_left(F, "bound_blueprint") > 0,
           "the cooldown was rolled back to zero - the payload's own ResearchCompleted "
           .. "handler reloaded GG.cooldowns from a save written before the purchase, so "
           .. "the service can be bought again on the same turn, forever")
    local fav_after = select(2, GG.get(F, "daemonsmiths"))
    assert(fav_after == fav_before - cost + REWARD,
           "the favour was refunded by the mod's own listener: expected "
           .. (fav_before - cost + REWARD) .. ", got " .. fav_after
           .. " - GG.buy must write the purchase to the save BEFORE firing a payload "
           .. "that raises an event, because every handler opens with GG.load")

    GG.clear_research(F)
    GG.state[F], GG.cooldowns[F] = nil, nil
    GG.CULTURE_OF[F] = nil
    cm.get_human_factions = prev_humans
    GG.humans, GG.player_cultures_cache = nil, nil
end)()

-- ---------------------------------------------------------------------------
-- WHO IS SELECTED ON THE CAMPAIGN MAP.
--
-- THE STUB IS CA'S OWN OBJECT, MEMBER FOR MEMBER, and that is the whole point of this
-- block. There was no stub at all: cm.get_campaign_ui_manager was nil, GGUI's pcall ate
-- the error and the function answered nil, so every check written against it passed with
-- the call spelled any way at all.
--
-- It was spelled `get_char_selected()`, which campaign_ui_manager does not have. CA's
-- lib_campaign_ui.lua declares exactly one get_char member and it is
-- `get_char_selected_cqi()` - so the panel has never known what was selected, and THREE
-- things were dead from the day they shipped: Appoint Patron (the button is gated on
-- `sel ~= nil` and so was permanently greyed), Hire the Immortals (kind "unit" reads this
-- for its target) and The Khan's Price (the hostile service reads it through
-- GGUI.selected_enemy_faction). Reported from a live campaign on 2026-09-16 as "cannot
-- assign lord as guild leader".
--
-- A stub that answers whatever it is asked cannot tell a real member from an invented
-- one. This one answers only what CA declares.
do
    local SELECTED = nil
    local prev_uim = cm.get_campaign_ui_manager
    cm.get_campaign_ui_manager = function()
        return {
            get_char_selected_cqi        = function() return SELECTED end,
            get_mf_selected_cqi          = function() return false end,
            get_mf_selected_type         = function() return false end,
            get_selected_settlement      = function() return "" end,
            get_selected_settlement_region = function() return nil end,
            get_open_panel               = function() return "" end,
        }
    end

    SELECTED = 4242
    assert(GGUI.selected_force_cqi() == 4242,
           "the panel cannot read the map selection, got "
           .. tostring(GGUI.selected_force_cqi())
           .. " - campaign_ui_manager has no get_char_selected, only "
           .. "get_char_selected_cqi, and the pcall around it turns the typo into a "
           .. "permanent nil")

    -- AND THE SERVICE THAT SPENDS IT. GG.buy refuses a targeted service with no target,
    -- so this is the difference between Hire the Immortals working and refunding nothing.
    assert(GGUI.pick_target(GG.service("hire_immortals"), "cr_sel") == 4242,
           "Hire the Immortals must target the selected army")

    -- NIL BEFORE ANYTHING HAS EVER BEEN SELECTED, and -1 AFTER A DESELECT. CA sets the
    -- field to -1 rather than clearing it, so a plain nil test lets a deselected map
    -- through as character -1.
    SELECTED = nil
    assert(GGUI.selected_force_cqi() == nil, "nothing selected is not a character")
    SELECTED = -1
    assert(GGUI.selected_force_cqi() == nil,
           "CharacterDeselected sets the cqi to -1, not to nil - a bare nil test hands "
           .. "the payload character -1, which is an unvalidated key that fails forever "
           .. "in silence")

    cm.get_campaign_ui_manager = prev_uim
end

-- ============================================================== THE LOG TAB ======
-- The panel had a Log tab once. It was replaced by Bounties because it "was a tab the
-- panel switched to and then drew nothing into" - there was never a record behind it.
-- This is the record: per human faction, newest first, capped, KEYS AND NUMBERS ONLY,
-- because every writer below runs from a turn handler and a loc call there is a CTD.
;(function()
    local H, AI = "cr_log_human", "cr_log_ai"
    CULTURE[H], CULTURE[AI] = GG.CHD_CULTURE, GG.CHD_CULTURE
    GG.CULTURE_OF[H], GG.CULTURE_OF[AI] = GG.CHD_CULTURE, GG.CHD_CULTURE
    local prev_humans = cm.get_human_factions
    cm.get_human_factions = function() return {H} end
    GG.humans, GG.player_cultures_cache = nil, nil
    local LOG = "derpy_gg_log_" .. H
    saved[LOG] = nil
    TURN = 30

    -- A RANK GAINED, with both ranks, so the line can say "rose to" and name it.
    GG.state[H] = nil
    GG.grant(H, "brass", 120)
    local e = GG.log_entries(H)
    assert(#e == 1, "a promotion must write exactly one log entry, got " .. #e)
    assert(e[1].kind == "rank" and e[1].guild == "brass"
           and tonumber(e[1].a) == 1 and tonumber(e[1].b) == 2 and e[1].turn == 30,
           "the entry must carry the turn, the guild and both ranks")

    -- A RANK LOST. Nothing announces a fall - GG.announce_rank returns on a demotion -
    -- so this line is the only place a player learns why a bonus went away.
    GG.penalise(H, "brass", 50)
    e = GG.log_entries(H)
    assert(e[1].kind == "rank" and tonumber(e[1].a) == 2 and tonumber(e[1].b) == 1,
           "a demotion must be recorded, newest first")

    -- AN AI'S OWN RANKS ARE NOBODY'S LOG. ~190 factions would each fill a saved value.
    GG.state[AI] = nil
    GG.grant(AI, "brass", 120)
    assert(saved["derpy_gg_log_" .. AI] == nil, "an AI faction was given a log")

    -- THE PLAYER'S PURCHASE, with what it cost.
    GG.state[H], GG.cooldowns[H] = nil, nil
    GG.grant(H, "brass", 400)
    local cost = GG.service_cost(H, "caravan_levy")
    assert(GG.buy(H, "caravan_levy"), "setup: the levy must be buyable at 400")
    e = GG.log_entries(H)
    assert(e[1].kind == "buy" and e[1].guild == "brass" and e[1].a == "caravan_levy"
           and tonumber(e[1].b) == cost,
           "the purchase must be logged with its key and price, got "
           .. tostring(e[1].kind) .. " " .. tostring(e[1].a) .. " " .. tostring(e[1].b))

    -- A RIVAL'S PURCHASE reaches the human of its culture, naming the buyer. The
    -- "Rivals last turn" line only ever counted these; nothing said WHO.
    GG.state[AI], GG.cooldowns[AI] = nil, nil
    GGAI.bought_this_turn[AI] = nil
    GG.grant(AI, "brass", 400)
    local prev_choose = GGAI.choose
    GGAI.choose = function() return "caravan_levy" end
    local bought = GGAI.step(AI)
    GGAI.choose = prev_choose
    assert(bought, "setup: the AI must be able to buy the levy")
    e = GG.log_entries(H)
    assert(e[1].kind == "ai_buy" and e[1].a == "caravan_levy" and e[1].b == AI,
           "an AI purchase must reach the player's log with the buyer's key")

    -- A HOSTILE SERVICE ON THE PLAYER IS A HIT, NOT A PURCHASE - one line, not two
    -- saying the same thing.
    local before = #GG.log_entries(H)
    GGAI.log_purchase(AI, GG.service("khans_price"), H)
    e = GG.log_entries(H)
    assert(#e == before + 1, "a hit must be one entry, got " .. (#e - before))
    assert(e[1].kind == "hit" and e[1].a == "khans_price" and e[1].b == AI,
           "a service used on the player must be logged as a hit, naming who did it")

    -- THE LEAD, both ways, naming the other party.
    GG.announce_lead("khanate", H, AI)
    e = GG.log_entries(H)
    assert(e[1].kind == "lead_won" and e[1].guild == "khanate" and e[1].a == AI,
           "taking a guild's lead must be logged with who it was taken from")
    GG.announce_lead("khanate", AI, H)
    e = GG.log_entries(H)
    assert(e[1].kind == "lead_lost" and e[1].a == AI,
           "losing a guild's lead must be logged with who took it")

    -- THE CAP. Newest first, and never more than GG.LOG_MAX - a saved value that grows
    -- for a whole campaign is a save file that grows for a whole campaign.
    saved[LOG] = nil
    for i = 1, GG.LOG_MAX + 5 do
        TURN = i
        GG.log_add(H, "rank", "brass", 1, 2)
    end
    e = GG.log_entries(H)
    assert(#e == GG.LOG_MAX, "the log must cap at " .. GG.LOG_MAX .. ", got " .. #e)
    assert(e[1].turn == GG.LOG_MAX + 5 and e[#e].turn == 6,
           "the cap must drop the OLDEST entries, got turns " .. e[1].turn .. ".."
           .. e[#e].turn)

    -- THE PANEL'S LINES. One entry, at least one line, and every line carries its turn -
    -- a log with no dates is a list of things that happened at some point.
    saved[LOG] = nil
    TURN = 41
    GG.log_add(H, "buy", "brass", "caravan_levy", 50)
    local lines = GGUI.log_lines(H, nil)
    assert(#lines >= 1, "one entry must draw at least one line")
    assert(string.find(lines[1], "41"), "the line must carry its turn: " .. lines[1])
    -- AN EMPTY LOG SAYS SO rather than drawing a blank tab - which is exactly what the
    -- old Log tab did, and why it was removed.
    saved[LOG] = nil
    lines = GGUI.log_lines(H, nil)
    assert(#lines == 1 and lines[1] ~= "", "an empty log must draw one line saying so")

    saved[LOG] = nil
    GG.state[H], GG.state[AI] = nil, nil
    GG.cooldowns[H], GG.cooldowns[AI] = nil, nil
    GG.CULTURE_OF[H], GG.CULTURE_OF[AI] = nil, nil
    cm.get_human_factions = prev_humans
    GG.humans, GG.player_cultures_cache = nil, nil
end)()

print("harness ok")
