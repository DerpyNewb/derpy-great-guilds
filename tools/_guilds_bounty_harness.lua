-- The bounty board, version 2 (docs/superpowers/specs/2026-09-27-great-guilds-bounties-v2-design.md).
-- Run from the workspace root:
--   "/c/Program Files (x86)/Lua/5.1/lua.exe" tools/_guilds_bounty_harness.lua
--
-- ITS OWN FILE AND ITS OWN WORLD. _guilds_harness.lua is within a handful of Lua 5.1's
-- 200-locals ceiling, and its stubs model a world where every faction is an enemy with no
-- position. The rules here are about who is at peace, who is an ally, and how far away a
-- thing is, so the world is built to answer exactly those questions.
--
-- NEW TESTS GO IN A `do ... end` BLOCK, one rule per block.

local saved = {}
HANDLERS = {}
CALLS = {}          -- [cm member] = { {args...}, ... }
local function rec(name, ...)
    CALLS[name] = CALLS[name] or {}
    table.insert(CALLS[name], {...})
end

W = {}
local F, R, C = {}, {}, {}    -- factions, regions, characters by key / cqi string

local function LIST(items)
    return {num_items = function() return #items end,
            item_at = function(_, i) return items[i + 1] end,
            is_empty = function() return #items == 0 end}
end
local function NULL() return {is_null_interface = function() return true end} end

-- A FACTION. t: at_war = {key=true}, met = {keys}, allies/defensive/pact/vassal_of/
-- client = {key=true}, human, dead, bundles = {key=true}, regions = {keys},
-- lords = {cqis}, heroes = {cqis}, treasury, income, techs = {key=true}, culture.
function W.faction(key, t)
    t = t or {}
    t.at_war = t.at_war or {}
    F[key] = t
    return t
end

local function fi(key)
    local t = F[key]
    if not t then return nil end
    local self
    self = {
        is_null_interface = function() return false end,
        name = function() return key end,
        is_dead = function() return t.dead == true end,
        is_human = function() return t.human == true end,
        culture = function() return t.culture or "wh3_dlc23_chd_chaos_dwarfs" end,
        at_war_with = function(_, o) return t.at_war[o:name()] == true end,
        factions_at_war_with = function()
            local out = {}
            for k, v in pairs(t.at_war) do if v and F[k] then out[#out + 1] = fi(k) end end
            table.sort(out, function(a, b) return a:name() < b:name() end)
            return LIST(out)
        end,
        factions_met = function()
            local out = {}
            for _, k in ipairs(t.met or {}) do out[#out + 1] = fi(k) end
            return LIST(out)
        end,
        military_allies_with = function(_, o) return (t.allies or {})[o:name()] == true end,
        defensive_allies_with = function(_, o) return (t.defensive or {})[o:name()] == true end,
        non_aggression_pact_with = function(_, o) return (t.pact or {})[o:name()] == true end,
        is_vassal_of = function(_, o) return (t.vassal_of or {})[o:name()] == true end,
        is_ally_vassal_or_client_state_of = function(_, o)
            return (t.client or {})[o:name()] == true
        end,
        has_effect_bundle = function(_, b) return (t.bundles or {})[b] == true end,
        treasury = function() return t.treasury or 0 end,
        net_income = function() return t.income or 0 end,
        has_technology = function(_, k) return (t.techs or {})[k] == true end,
        -- t.resources = {key = value}; a key it lacks is CA's null interface.
        pooled_resource_manager = function()
            return {resource = function(_, k)
                local v = (t.resources or {})[k]
                if v == nil then return NULL() end
                return {is_null_interface = function() return false end,
                        key = function() return k end,
                        value = function() return v end}
            end}
        end,
        -- t.provinces = {{key = "p1", labour = true}, ...}: a faction-province's labour pool.
        provinces = function()
            local out = {}
            for _, p in ipairs(t.provinces or {}) do
                out[#out + 1] = {pooled_resource_manager = function()
                    return {resource = function(_, k)
                        if k ~= "wh3_dlc23_chd_labour" or not p.labour then return NULL() end
                        return {is_null_interface = function() return false end,
                                key = function() return k end, province = p.key}
                    end}
                end}
            end
            return LIST(out)
        end,
        region_list = function()
            local out = {}
            for _, k in ipairs(t.regions or {}) do out[#out + 1] = W.ri(k) end
            return LIST(out)
        end,
        military_force_list = function()
            local out = {}
            for _, cqi in ipairs(t.lords or {}) do
                local c = C[tostring(cqi)]
                if c and c.army ~= false then
                    out[#out + 1] = {
                        has_general = function() return true end,
                        is_armed_citizenry = function() return false end,
                        general_character = function() return W.ci(cqi) end,
                        unit_list = function() return LIST({}) end,
                    }
                end
            end
            return LIST(out)
        end,
        character_list = function()
            local out = {}
            for _, cqi in ipairs(t.lords or {}) do out[#out + 1] = W.ci(cqi) end
            for _, cqi in ipairs(t.heroes or {}) do out[#out + 1] = W.ci(cqi) end
            return LIST(out)
        end,
    }
    return self
end
W.fi = fi

-- A REGION. t: owner, x, y, adj = {keys}, buildings = {level=true}, worth = {n, cap, army},
-- level = the main settlement's level (default 5, so no older test is held back by it)
function W.region(key, t)
    R[key] = t
    return t
end

function W.ri(key)
    local t = R[key]
    if not t then return NULL() end
    local w = t.worth or {}
    return {
        is_null_interface = function() return false end,
        name = function() return key end,
        owning_faction = function() return fi(t.owner) or NULL() end,
        adjacent_region_list = function()
            local out = {}
            for _, k in ipairs(t.adj or {}) do out[#out + 1] = W.ri(k) end
            return LIST(out)
        end,
        settlement = function()
            return {logical_position_x = function() return t.x or 0 end,
                    logical_position_y = function() return t.y or 0 end,
                    display_position_x = function() return t.x or 0 end,
                    display_position_y = function() return t.y or 0 end,
                    primary_slot = function()
                        return {building = function()
                            return {building_level = function() return t.level or 5 end}
                        end}
                    end}
        end,
        building_exists = function(_, lvl) return (t.buildings or {})[lvl] == true end,
        num_buildings = function() return w[1] or 0 end,
        is_province_capital = function() return w[2] == true end,
        garrison_residence = function()
            return {is_null_interface = function() return false end,
                    has_army = function() return w[3] == true end,
                    region = function() return W.ri(key) end}
        end,
    }
end

-- A CHARACTER. t: faction, x, y, rank, general (bool), army (false = none), leader, units
function W.char(cqi, t)
    C[tostring(cqi)] = t
    return t
end

function W.ci(cqi)
    local t = C[tostring(cqi)]
    if not t then return NULL() end
    local fm = {is_null_interface = function() return false end,
                command_queue_index = function() return cqi end,
                character = function() return W.ci(cqi) end}
    return {
        is_null_interface = function() return false end,
        command_queue_index = function() return cqi end,
        family_member = function() return fm end,
        faction = function() return fi(t.faction) end,
        -- A lord is a general; anything else a hero unless t.type says (e.g. "colonel").
        character_type = function(_, k)
            return k == (t.general and "general" or t.type or "champion")
        end,
        has_region = function() return true end,
        has_military_force = function() return t.general == true and t.army ~= false end,
        logical_position_x = function() return t.x or 0 end,
        logical_position_y = function() return t.y or 0 end,
        display_position_x = function() return t.x or 0 end,
        display_position_y = function() return t.y or 0 end,
        rank = function() return t.rank or 1 end,
        is_faction_leader = function() return t.leader == true end,
        military_force = function()
            if t.army == false or not t.general then return NULL() end
            local n = t.units or 0
            return {is_null_interface = function() return false end,
                    command_queue_index = function() return t.force or 1000 + cqi end,
                    is_armed_citizenry = function() return false end,
                    unit_count_limit = function() return t.limit or 20 end,
                    has_effect_bundle = function(_, b) return (t.force_bundles or {})[b] == true end,
                    unit_list = function() return {num_items = function() return n end} end}
        end,
    }
end

TURN = 1
RANDOM = function(n) return 1 end   -- tests replace this to steer a roll

cm = {
    set_saved_value = function(_, k, v) saved[k] = v end,
    get_saved_value = function(_, k) return saved[k] end,
    add_first_tick_callback = function(_, fn)
        FIRST_TICK = FIRST_TICK or {}
        FIRST_TICK[#FIRST_TICK + 1] = fn
    end,
    apply_effect_bundle = function(_, k, f, turns) rec("bundle", k, f, turns) end,
    get_character_by_cqi = function(_, cqi)
        if not C[tostring(cqi)] then return NULL() end
        return W.ci(cqi)
    end,
    apply_effect_bundle_to_force = function(_, k, cqi, turns) rec("force_bundle", k, cqi, turns) end,
    apply_effect_bundle_to_region = function(_, k, r, turns) rec("region_bundle", k, r, turns) end,
    heal_military_force = function(_, mf) rec("heal", mf:command_queue_index()) end,
    add_agent_experience = function(_, lookup, n, ranks) rec("ranks", lookup, n, ranks) end,
    remove_effect_bundle = function() end,
    model = function()
        return {turn_number = function() return TURN end,
                -- Every faction of the world, for the rivals' sweep and its index.
                world = function()
                    return {
                        -- t.caravans = {{id = 1, cargo = 100, returning = false}, ...}
                        caravans_system = function()
                            return {faction_caravans = function(_, f)
                                local t = F[f:name()]
                                if not t or not t.caravans then return NULL() end
                                local list = {}
                                for _, c in ipairs(t.caravans) do
                                    list[#list + 1] = {id = c.id,
                                        cargo = function() return c.cargo end,
                                        is_returning = function() return c.returning == true end}
                                end
                                return {is_null_interface = function() return false end,
                                        active_caravans = function() return LIST(list) end}
                            end}
                        end,
                        faction_list = function()
                        local keys = {}
                        for k in pairs(F) do keys[#keys + 1] = k end
                        table.sort(keys)
                        local out = {}
                        for _, k in ipairs(keys) do out[#out + 1] = fi(k) end
                        return LIST(out)
                    end}
                end}
    end,
    random_number = function(_, n) return RANDOM(n) end,
    get_faction = function(_, k) return fi(k) or false end,
    get_region = function(_, k) return W.ri(k) end,
    get_family_member_by_cqi = function(_, cqi)
        if not C[tostring(cqi)] then return NULL() end
        return W.ci(cqi):family_member()
    end,
    get_human_factions = function() return {"me"} end,
    trigger_custom_mission_from_string = function(_, f, s) rec("trigger", f, s) end,
    cancel_custom_mission = function(_, f, k) rec("cancel", f, k) end,
    complete_scripted_mission_objective = function(_, f, k, sk, ok)
        rec("complete", f, k, sk, ok)
    end,
    set_scripted_mission_position = function(_, k, sk, x, y) rec("position", k, sk, x, y) end,
    treasury_mod = function(_, f, n) rec("treasury", f, n) end,
    show_message_event_located = function(_, f, t, p, s, x, y, persistent, idx)
        rec("located", f, t, p, s, x, y, persistent, idx)
    end,
    -- CA's campaign_manager builds "character_cqi:<n>" from a character or a cqi
    -- (lib_campaign_manager.lua:5558); the character calls below take that string.
    char_lookup_str = function(_, c)
        if type(c) == "table" then c = c:command_queue_index() end
        return "character_cqi:" .. tostring(c)
    end,
    grant_unit_to_character = function(_, lookup, unit) rec("grant", lookup, unit) end,
    show_message_event = function(_, f, t, p, s, persistent, idx)
        rec("message", f, t, p, s, persistent, idx)
    end,
    faction_add_pooled_resource = function(_, f, res, factor, n) rec("pooled", f, res, factor, n) end,
    pooled_resource_factor_transaction = function(_, res, factor, n)
        rec("transaction", res.province, res:key(), factor, n)
    end,
    trigger_incident = function(_, f, k, now) rec("incident", f, k, now) end,
    get_factions_bonus_value = function(_, f, k) return (BONUS or {})[f .. "|" .. k] or 0 end,
    trigger_dilemma = function(_, f, k) rec("dilemma", f, k); return not DILEMMA_REFUSED end,
    faction_has_campaign_feature = function(_, f, feat)
        return F[f] ~= nil and (F[f].features or {})[feat] == true
    end,
    set_next_winds_of_magic_compass_selection_cooldown = function(_, f, n)
        rec("compass", f:name(), n)
    end,
    set_caravan_cargo = function(_, c, n) rec("cargo", c.id, n) end,
    modify_character_personal_loyalty_factor = function(_, lookup, n) rec("loyalty", lookup, n) end,
    change_influence = function(_, f, n) rec("influence", f, n) end,
    remove_effect_bundle_from_force = function(_, k, cqi) rec("force_unbundle", k, cqi) end,
    is_new_game = function() return NEW_GAME == true end,
}
EVENTS = {}
core = {add_listener = function(_, name, e, _c, fn) HANDLERS[name] = fn; EVENTS[name] = e end}
out = function() end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua")
if io.open("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua") then
    dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua")
end
-- THE RIVALS' HALF (2026-09-29): their bounties live in the AI file.
dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua")
-- THE LISTENERS, which the game registers at first tick. Registered here so a test can
-- raise an event through the mod's real handler (HANDLERS[name]) rather than a copy.
GG.register()

-- A fresh world: the player "me" (Chaos Dwarf), a board wiped, settings back to default
-- with the bounty rate at 80 and the stake at its default.
function W.reset()
    F, R, C = {}, {}, {}
    CALLS = {}
    TURN = 1
    RANDOM = function(n) return 1 end
    GG.bounties = {}
    GG.state = {}
    GG.turn_gain = {}
    GG.dead = {}
    GG.CULTURE_OF = {}
    GG.cards = {}
    GG.self_grants = {}
    GG.earn_carry = {}
    GG.humans = nil
    -- The player's culture is cached on first read; a test that changes it must drop it.
    GG.player_cultures_cache = nil
    GGAI.bounty, GGAI.by_target, GGAI.indexed, GGAI.agent_seen = {}, {}, false, nil
    GG.TUNE = {}
    for k, v in pairs(GG.TUNE_DEFAULTS) do GG.TUNE[k] = v end
    GG.TUNE.rate_bounty = 80
    for k in pairs(saved) do saved[k] = nil end
    W.faction("me", {human = true, regions = {}, lords = {}, heroes = {}})
end

function ok(name) print("ok   " .. name) end

-- ------------------------------------------------------------ Task 1: the record --
do
    W.reset()
    GG.bounties.me = {{guild = "brass", kind = "region_take", target = "r1", owner = "foe",
                       gold = 3000, rep = 80, posted = 4, taken = true, diff = 12,
                       war = 1, stake = 20, amount = 7, done = 1, void = true}}
    GG.save_bounties("me")
    GG.bounties.me = nil
    GG.load_bounties("me")
    local o = GG.bounties.me[1]
    assert(o.war == 1, "war did not survive a save, got " .. tostring(o.war))
    assert(o.stake == 20, "stake did not survive a save, got " .. tostring(o.stake))
    assert(o.amount == 7, "amount did not survive a save, got " .. tostring(o.amount))
    assert(o.done == 1, "done did not survive a save, got " .. tostring(o.done))
    assert(o.void == true, "void did not survive a save")
    ok("the five new offer fields survive a save")
end

do
    -- REVIEW FOCUS 1: a save written by the previous build has nine fields.
    W.reset()
    cm:set_saved_value("derpy_gg_bounties_me", "brass,region_take,r1,foe,3000,80,4,1,12")
    GG.load_bounties("me")
    local o = GG.bounties.me[1]
    assert(o and o.taken, "an old-format taken offer must load")
    assert(o.war == 0 and o.stake == 0 and o.amount == 0 and o.done == 0
           and o.void == false, "an old-format offer must load its new fields as zero")
    ok("an old save's offer loads as a far enemy with no stake")
end

-- ------------------------------------------------------ Task 2: who is a target --
do
    W.reset()
    local me = F.me
    for _, k in ipairs({"foe", "ally", "defender", "pact", "master", "client", "human",
                        "dead", "realm", "friend"}) do
        W.faction(k, {})
    end
    me.at_war = {foe = true, ally = true, human = true, dead = true, realm = true}
    me.met = {"foe", "defender", "pact", "master", "client", "friend", "human"}
    me.allies = {ally = true}
    me.defensive = {defender = true}
    me.pact = {pact = true}
    me.vassal_of = {master = true}
    F.client.client = {me = true}
    F.human.human = true
    F.dead.dead = true
    F.realm.bundles = {wh3_main_bundle_realm_factions = true}
    for _, k in ipairs(me.met) do if not me.at_war[k] then F[k].at_war = {} end end

    local function names(list)
        local out = {}
        for i = 1, #list do out[#out + 1] = list[i]:name() end
        table.sort(out)
        return table.concat(out, ",")
    end
    assert(names(GG.bounty_pool("me", false)) == "foe",
           "the at-war pool must be only foe, got " .. names(GG.bounty_pool("me", false)))
    assert(names(GG.bounty_pool("me", true)) == "friend",
           "the peace pool must be only friend, got " .. names(GG.bounty_pool("me", true)))
    ok("allies, defensive allies, pacts, masters, clients, humans, the dead and realm "
       .. "factions are never targets")
end

-- ------------------------------------------------------- Task 3: the front line --
do
    W.reset()
    W.faction("foe", {})
    F.me.regions = {"home"}
    F.me.lords = {10}
    W.char(10, {faction = "me", general = true, x = 1000, y = 1000})
    W.region("home", {owner = "me", x = 0, y = 0, adj = {"border"}})
    W.region("border", {owner = "foe", x = 50, y = 0})
    W.region("far", {owner = "foe", x = 5000, y = 5000})
    assert(GG.region_on_front("me", "home"), "an owned region is on the front")
    assert(GG.region_on_front("me", "border"), "an adjacent region is on the front")
    assert(not GG.region_on_front("me", "far"), "a distant region is not on the front")

    W.char(20, {faction = "foe", general = true, x = 1100, y = 1000})  -- 100 from my army
    W.char(21, {faction = "foe", general = true, x = 150, y = 0})      -- 150 from home
    W.char(22, {faction = "foe", general = true, x = 3000, y = 3000})
    assert(GG.char_on_front("me", W.ci(20)), "a lord beside my army is on the front")
    assert(GG.char_on_front("me", W.ci(21)), "a lord beside my settlement is on the front")
    assert(not GG.char_on_front("me", W.ci(22)), "a distant lord is not on the front")
    ok("the front is owned and adjacent regions, and anything near a settlement or army")
end

-- ------------------------------------------------- Task 4: far enemy or new war --
local function world4()
    W.reset()
    W.faction("foe", {regions = {"foe_near", "foe_far"}, lords = {30, 31}})
    W.faction("friend", {regions = {"friend_town"}, lords = {40}})
    F.me.at_war = {foe = true}
    F.foe.at_war = {me = true}
    F.me.met = {"foe", "friend"}
    F.me.regions = {"home"}
    W.region("home", {owner = "me", x = 0, y = 0, adj = {"foe_near"}})
    W.region("foe_near", {owner = "foe", x = 60, y = 0})
    W.region("foe_far", {owner = "foe", x = 4000, y = 0})
    W.region("friend_town", {owner = "friend", x = 0, y = 4000})
    W.char(30, {faction = "foe", general = true, x = 100, y = 0, units = 10})
    W.char(31, {faction = "foe", general = true, x = 4000, y = 100, units = 10})
    W.char(40, {faction = "friend", general = true, x = 100, y = 4000, units = 10})
end

do
    world4()
    local t = GG.bounty_target("me", "region_take", {}, false)
    assert(t == "foe_far", "a far-enemy capture must skip the front, got " .. tostring(t))
    local l = GG.bounty_target("me", "lord_kill", {}, false)
    assert(l == "31", "a far-enemy lord must skip the front, got " .. tostring(l))
    local p = GG.bounty_target("me", "region_take", {}, true)
    assert(p == "friend_town", "a new-war capture names a faction at peace, got "
           .. tostring(p))
    ok("far enemy skips the front; new war names a faction at peace")
end

do
    world4()
    -- The mix: a roll of 3 asks for a new war, anything else a far enemy.
    RANDOM = function(n) if n == 3 then return 3 end return 1 end
    local o = GG.make_offer("me", "brass", "region_take", 1, {})
    assert(o and o.war == 1 and o.target == "friend_town",
           "a 3 must post a new war, got " .. tostring(o and o.target))
    RANDOM = function(n) return 1 end
    local far = GG.make_offer("me", "brass", "region_take", 1, {})
    assert(far.war == 0 and far.target == "foe_far", "a 1 must post a far enemy")
    -- New war doubles the gold and pays half again the reputation.
    local g0, r0 = GG.bounty_price("region_take", o.diff, 0)
    assert(o.gold == g0 * 2 and o.rep == math.floor(r0 * 3 / 2),
           "new war must pay x2 gold and x1.5 reputation, got " .. o.gold .. "/" .. o.rep)
    -- Fallback: nobody at peace, so a 3 still posts a far enemy.
    F.me.met = {"foe"}
    RANDOM = function(n) if n == 3 then return 3 end return 1 end
    local fb = GG.make_offer("me", "brass", "region_take", 1, {})
    assert(fb and fb.war == 0, "no peace pool must fall back to a far enemy")
    ok("the war roll, its price and its fallback")
end

do
    -- REVIEW FOCUS 3: turn 1, nobody at war, nobody met.
    world4()
    F.me.at_war = {}
    F.me.met = {}
    GG.post_bounties("me")
    -- Jobs and building requests may still post (Task 7); nothing military can.
    for _, o in ipairs(GG.bounties.me or {}) do
        assert(not GG.BOUNTY_KINDS[o.kind].military,
               "a player who has met nobody has no military work, got " .. o.kind)
    end
    ok("turn one with nobody met posts no military offer and does not error")
end

do
    -- Validity: a new-war offer survives the declaration; a far offer does not survive
    -- peace; an untaken far offer on the front is withdrawn, a taken one is kept.
    world4()
    local nw = {guild = "brass", kind = "region_take", target = "friend_town",
                owner = "friend", war = 1, posted = 1}
    F.me.at_war.friend = true
    assert(GG.bounty_still_valid("me", nw), "a new-war offer must survive the war")
    F.me.pact = {friend = true}
    assert(not GG.bounty_still_valid("me", nw), "a pact must withdraw even a new-war offer")
    F.me.pact = {}
    local far = {guild = "brass", kind = "region_take", target = "foe_far",
                 owner = "foe", war = 0, posted = 1}
    F.me.at_war.foe = nil
    assert(not GG.bounty_still_valid("me", far), "peace must withdraw a far offer")
    F.me.at_war.foe = true
    R.home.adj = {"foe_near", "foe_far"}
    assert(not GG.bounty_still_valid("me", far), "an untaken offer on the front is withdrawn")
    far.taken = true
    assert(GG.bounty_still_valid("me", far), "a taken offer on the front is kept")
    ok("validity for new-war and far offers")
end

do
    -- THE SAME RULES FOR A LORD (spec 3.5): the offer names whoever owns the lord, so
    -- peace or a pact with that faction withdraws it just as it does a town.
    world4()
    local lk = {guild = "immortals", kind = "lord_kill", target = "31", owner = "foe",
                war = 0, posted = 1}
    assert(GG.bounty_still_valid("me", lk), "a far lord of an enemy is a valid offer")
    F.me.at_war.foe = nil
    assert(not GG.bounty_still_valid("me", lk), "peace must withdraw a far lord offer")
    F.me.at_war.foe = true
    F.me.pact = {foe = true}
    assert(not GG.bounty_still_valid("me", lk), "a pact must withdraw a lord offer")
    F.me.pact = {}
    local nw = {guild = "immortals", kind = "lord_kill", target = "40", owner = "friend",
                war = 1, posted = 1}
    assert(GG.bounty_still_valid("me", nw), "a new-war lord offer stands at peace")
    ok("validity for lord offers follows their owner")
end

do
    -- Distance adds to the price: the same town, further away, pays more.
    world4()
    local near_d = GG.bounty_difficulty("region_take", "foe_near", nil, "me")
    local far_d = GG.bounty_difficulty("region_take", "foe_far", nil, "me")
    assert(far_d > near_d, "distance must raise the price: near " .. near_d .. " far " .. far_d)
    assert(far_d - near_d <= GG.BOUNTY_DIFF.distance_max,
           "the distance term is capped at " .. GG.BOUNTY_DIFF.distance_max)
    ok("distance raises the price, capped")
end

-- ------------------------------------------------------------- Task 5: the stake --
local function board5()
    world4()
    GG.bounties.me = {{guild = "brass", kind = "region_take", target = "foe_far",
                       owner = "foe", gold = 3000, rep = 80, posted = 1, taken = false,
                       diff = 0, war = 0, stake = 20, amount = 0, done = 0, void = false}}
    GG.state.me = nil
end

do
    board5()
    assert(GG.bounty_stake(80) == 20, "the stake is a quarter of the reputation")
    GG.TUNE.rate_bounty_stake = 0
    assert(GG.bounty_stake(80) == 0, "0 switches the stake off")
    GG.TUNE.rate_bounty_stake = 25
    -- Not enough favour: nothing is issued.
    assert(GG.take_bounty("me", 1) == false, "a take with no favour must be refused")
    assert(not CALLS.trigger, "a refused take must issue nothing")
    -- Enough favour: the stake is spent.
    GG.grant("me", "brass", 50, "test")
    local _, fav0 = GG.get("me", "brass")
    assert(GG.take_bounty("me", 1) == true, "a take with favour must succeed")
    local _, fav1 = GG.get("me", "brass")
    assert(fav0 - fav1 == 20, "taking must spend the stake, spent " .. (fav0 - fav1))
    -- Success refunds the stake as favour only.
    local rep1 = select(1, GG.get("me", "brass"))
    assert(GG.bounty_done("me", GG.offer_mission_key(GG.bounties.me[1], "me")))
    local rep2, fav2 = GG.get("me", "brass")
    assert(fav2 == fav1 + 20 + 80, "success must refund 20 and pay 80 favour, got "
           .. (fav2 - fav1))
    assert(rep2 - rep1 == 80, "the refund must not add reputation, got " .. (rep2 - rep1))
    ok("the stake is refused when short, spent on take and refunded on success")
end

do
    -- Hand-back loses the stake; a voided offer refunds it; failure loses it.
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.take_bounty("me", 1)
    local _, fav = GG.get("me", "brass")
    local key = GG.offer_mission_key(GG.bounties.me[1], "me")
    GG.bounty_cancelled("me", key)
    assert(select(2, GG.get("me", "brass")) == fav, "a hand-back must not refund")
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.take_bounty("me", 1)
    GG.bounties.me[1].void = true
    fav = select(2, GG.get("me", "brass"))
    GG.bounty_cancelled("me", key)
    assert(select(2, GG.get("me", "brass")) == fav + 20, "a voided offer must refund")
    ok("hand-back loses the stake, a void refunds it")
end

do
    -- A trigger that throws puts the stake back.
    board5()
    GG.grant("me", "brass", 50, "test")
    local _, fav = GG.get("me", "brass")
    local real = cm.trigger_custom_mission_from_string
    cm.trigger_custom_mission_from_string = function() error("boom") end
    assert(GG.take_bounty("me", 1) == false, "a throwing trigger must fail the take")
    cm.trigger_custom_mission_from_string = real
    assert(select(2, GG.get("me", "brass")) == fav, "a failed trigger must refund")
    assert(GG.bounties.me[1].taken == false, "a failed trigger must leave the offer untaken")
    ok("a trigger that throws refunds the stake")
end

do
    -- THE STAKE IS SAVED BEFORE THE TRIGGER. A mission event inside the call reaches a
    -- handler that runs GG.load; a spend held only in memory is thrown away by it, and
    -- the bounty was taken for free (final review, 2026-09-27).
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.save("me")
    local _, fav = GG.get("me", "brass")
    local real = cm.trigger_custom_mission_from_string
    cm.trigger_custom_mission_from_string = function(_, f) GG.load(f) end
    assert(GG.take_bounty("me", 1), "the take must succeed")
    cm.trigger_custom_mission_from_string = real
    assert(select(2, GG.get("me", "brass")) == fav - 20,
           "a reload inside the trigger must not undo the stake, favour is "
           .. select(2, GG.get("me", "brass")))
    ok("the stake survives a reload inside the trigger")
end

do
    -- REVIEW FOCUS 5: the multiplayer path saves the standings too.
    board5()
    GG.grant("me", "brass", 50, "test")
    GG.save("me")
    local before = cm:get_saved_value("derpy_gg_me")   -- GG.save writes "derpy_gg_" .. faction
    GG.MP_OPS.bounty("me", "brass")     -- by guild since the logic audit
    local after = cm:get_saved_value("derpy_gg_me")
    assert(before ~= after, "the take must save the favour it spent")
    ok("the multiplayer take saves the standings")
end

-- -------------------------------------------------------------- Task 7: the jobs --
do
    W.reset()
    F.me.income = 1200
    F.me.treasury = 3000
    F.me.regions = {"home"}
    F.me.lords = {50}
    W.char(50, {faction = "me", general = true, rank = 10})
    W.region("home", {owner = "me", buildings = {}})

    -- coffers: the ask is 5 turns of income, at least 5000, in steps of 500.
    local o = GG.make_offer("me", "brass", "job_coffers", 1, {})
    assert(o.amount == 6000, "coffers must ask 6000, got " .. tostring(o.amount))
    F.me.income = 300
    o = GG.make_offer("me", "brass", "job_coffers", 1, {})
    assert(o.amount == 5000, "coffers has a 5000 floor, got " .. tostring(o.amount))

    -- champion: highest rank + 4.
    o = GG.make_offer("me", "immortals", "job_champion", 1, {})
    assert(o.amount == 14, "champion must ask rank 14, got " .. tostring(o.amount))
    C["50"].rank = 37
    assert(GG.make_offer("me", "immortals", "job_champion", 1, {}) == nil,
           "a rank-37 lord leaves no champion job")
    C["50"].rank = 10

    -- captives: turn * 10 + 300, at most 1500.
    TURN = 20
    o = GG.make_offer("me", "slavers", "job_captives", 20, {})
    assert(o.amount == 500, "captives on turn 20 must ask 500, got " .. tostring(o.amount))
    TURN = 500
    o = GG.make_offer("me", "slavers", "job_captives", 500, {})
    assert(o.amount == 1500, "captives cap at 1500, got " .. tostring(o.amount))
    TURN = 1
    ok("coffers, champion and captives ask what the spec says")
end

do
    -- research: a tech the player lacks, from the generated list; none left means none.
    W.reset()
    -- The roll takes the FIRST open tech, so the deepest come first: any gating mistake
    -- lets one of them through. tech_e needs both b and c, tech_d either, tech_c b.
    GG.BOUNTY_TECHS[""] = {{"tech_e", 8, 2, {"tech_b", "tech_c"}},
                           {"tech_d", 7, 1, {"tech_b", "tech_c"}}, {"tech_c", 7, 1, {"tech_b"}},
                           {"tech_b", 6, 1, {"tech_a"}}, {"tech_a", 5, 0, {}}}
    local function asks(techs, want, why)
        F.me.techs = techs
        local o2 = GG.make_offer("me", "daemonsmiths", "job_research", 1, {})
        assert(o2 and o2.target == want, why .. ", got " .. tostring(o2 and o2.target))
    end
    asks({tech_a = true}, "tech_b", "only a tech whose parents are researched")
    asks({tech_a = true, tech_b = true}, "tech_d", "one of two parents opens tech_d")
    asks({tech_a = true, tech_b = true, tech_c = true}, "tech_e", "tech_e opens on both")
    asks({}, "tech_a", "a root needs nothing")
    GG.BOUNTY_TECHS[""] = {{"tech_a", 5, 0, {}}, {"tech_b", 6, 0, {}}}
    F.me.techs = {tech_a = true}
    local o = GG.make_offer("me", "daemonsmiths", "job_research", 1, {})
    assert(o and o.target == "tech_b", "research must name the tech you lack")
    assert(GG.bounty_still_valid("me", o), "an unresearched tech is a valid offer")
    F.me.techs.tech_b = true
    assert(not GG.bounty_still_valid("me", o), "a researched tech withdraws the offer")
    -- REVIEW FOCUS 4: every tech researched; the guild posts another kind.
    assert(GG.make_offer("me", "daemonsmiths", "job_research", 1, {}) == nil,
           "no tech left means no research job")
    ok("research names a missing tech and is withdrawn once researched")
end

do
    -- build: an upgrade the player can make now - they own a level that upgrades into it,
    -- and not the level itself. The roll takes the FIRST open level, so the ones that
    -- must be refused come first: lvl_far is two steps up, lvl_have is already built.
    W.reset()
    GG.BOUNTY_BUILDINGS[""] = GG.BOUNTY_BUILDINGS[""] or {}
    GG.BOUNTY_BUILDINGS[""].brass = {{"lvl_far", 5, {"lvl_want"}},
                                     {"lvl_have", 3, {"lvl_base"}},
                                     {"lvl_want", 4, {"lvl_have"}}}
    F.me.regions = {"home"}
    W.region("home", {owner = "me", buildings = {lvl_have = true}})
    local o = GG.make_offer("me", "brass", "job_build", 1, {})
    assert(o and o.target == "lvl_want",
           "build must ask for the next level of one you own, got "
           .. tostring(o and o.target))
    -- Either of two lower levels upgrades into it (Cathay's yin and yang).
    GG.BOUNTY_BUILDINGS[""].brass = {{"lvl_yang_3", 3, {"lvl_yang_2", "lvl_yin_2"}}}
    W.region("home", {owner = "me", buildings = {lvl_yin_2 = true}})
    local y = GG.make_offer("me", "brass", "job_build", 1, {})
    assert(y and y.target == "lvl_yang_3", "any level that upgrades into it will do")
    W.region("home", {owner = "me", buildings = {}})
    assert(GG.make_offer("me", "brass", "job_build", 1, {}) == nil,
           "nothing to upgrade from means no building job")
    -- THE SETTLEMENT MUST ALREADY BE BIG ENOUGH (the 4th field). lvl_want needs a level-4
    -- settlement: in a level-3 one there is no job, at 4 there is.
    GG.BOUNTY_BUILDINGS[""].brass = {{"lvl_far", 5, {"lvl_want"}, 3},
                                     {"lvl_have", 3, {"lvl_base"}, 3},
                                     {"lvl_want", 4, {"lvl_have"}, 4}}
    W.region("home", {owner = "me", level = 3, buildings = {lvl_have = true}})
    assert(GG.make_offer("me", "brass", "job_build", 1, {}) == nil,
           "a settlement too small for the upgrade means no building job")
    R.home.level = 4
    o = GG.make_offer("me", "brass", "job_build", 1, {})
    assert(o and o.target == "lvl_want", "a settlement big enough gets the job, got "
           .. tostring(o and o.target))
    -- The lower level is in a region the player then loses: the untaken offer goes.
    R.home.owner, F.me.regions = "foe", {}
    assert(not GG.bounty_still_valid("me", o), "losing the lower level withdraws the offer")
    R.home.owner, F.me.regions = "me", {"home"}
    assert(GG.bounty_still_valid("me", o), "and holding it again keeps the offer")
    R.home.buildings.lvl_want = true
    assert(not GG.bounty_still_valid("me", o), "building it withdraws the offer")
    GG.BOUNTY_BUILDINGS[""].khanate = nil
    assert(GG.make_offer("me", "khanate", "job_build", 1, {}) == nil,
           "a guild with no buildings has no building job")
    ok("building requests skip what you own and are withdrawn once built")
end

do
    -- The objective strings (spec 5 table).
    W.reset()
    local function str(o) return GG.bounty_string("me", o) end
    local s = str({guild = "brass", kind = "job_coffers", target = "job_coffers", amount = 9000,
                   gold = 1500})
    assert(s:find("type HAVE_AT_LEAST_X_MONEY;total 9000;", 1, true), s)
    s = str({guild = "immortals", kind = "job_champion", target = "job_champion", amount = 14,
             gold = 2000})
    assert(s:find("type ACHIEVE_CHARACTER_RANK;total 1;total2 14;include_generals;", 1, true), s)
    s = str({guild = "daemonsmiths", kind = "job_research", target = "tech_b", gold = 2000})
    assert(s:find("type RESEARCH_N_TECHS_INCLUDING;total 1;technology tech_b;", 1, true), s)
    s = str({guild = "brass", kind = "job_build", target = "lvl_want", gold = 2500})
    assert(s:find("type CONSTRUCT_N_OF_A_BUILDING;faction me;total 1;building_level lvl_want;",
                  1, true), s)
    s = str({guild = "slavers", kind = "job_captives", target = "job_captives", amount = 500,
             gold = 1500})
    assert(s:find("type CAPTURE_X_BATTLE_CAPTIVES;total 500;", 1, true), s)
    assert(s:find("key derpy_gg_job_slavers;", 1, true), "a job uses the job row: " .. s)
    ok("every job builds the objective string CA's own helpers build")
end

do
    -- Coffers is fixed at TAKE: treasury then + the ask.
    W.reset()
    F.me.treasury = 4000
    F.me.income = 0
    GG.TUNE.rate_bounty_stake = 0
    GG.bounties.me = {GG.make_offer("me", "brass", "job_coffers", 1, {})}
    F.me.treasury = 7000
    GG.take_bounty("me", 1)
    local s = CALLS.trigger[1][2]
    assert(s:find("total 12000;", 1, true), "coffers must ask treasury-at-take + ask: " .. s)
    ok("the coffers figure is set when the bounty is taken")
end

do
    -- Every guild can post a building request; the board mixes kinds.
    W.reset()
    for i = 1, #GG.GUILDS do
        local ks = GG.guild_kinds(GG.GUILDS[i])
        local has = false
        for j = 1, #ks do if ks[j] == "job_build" then has = true end end
        assert(has, GG.GUILDS[i] .. " cannot post a building request")
    end
    ok("all six guilds can ask for a building")
end

-- --------------------------------------------------------- Task 8: hero bounties --
local function world8()
    world4()
    GG.TUNE.rate_bounty_stake = 0
    GG.bounties.me = {
        {guild = "daemonsmiths", kind = "hero_sabotage", target = "foe_far", owner = "foe",
         gold = 1200, rep = 80, posted = 1, taken = true, diff = 0, war = 0, stake = 0,
         amount = 2, done = 0, void = false},
        {guild = "khanate", kind = "hero_strike", target = "31", owner = "foe",
         gold = 1200, rep = 80, posted = 1, taken = true, diff = 0, war = 0, stake = 0,
         amount = 1, done = 0, void = false},
    }
end
local DMG = "wh2_main_agent_action_champion_hinder_settlement_damage_building"
local SCOUT = "wh2_main_agent_action_champion_hinder_settlement_scout_settlement"
local WOUND = "wh2_main_agent_action_spy_hinder_agent_wound"
local CONVERT = "wh3_dlc29_agent_action_spy_hinder_agent_wound_convert_to_nur_lord"

do
    world8()
    assert(not GG.hero_progress("me", DMG, "foe_far", false), "a failure must not count")
    assert(not GG.hero_progress("me", SCOUT, "foe_far", true), "scouting must not count")
    assert(not GG.hero_progress("me", DMG, "foe_near", true), "another town must not count")
    assert(not GG.hero_progress("other", DMG, "foe_far", true),
           "another faction's hero must not count")
    assert(not GG.hero_progress("me", CONVERT, "31", true), "a Nurgle conversion must not count")
    -- The board as it stood at take, so a reload below has something older to go back to.
    GG.save_bounties("me")
    GG.hero_progress("me", DMG, "foe_far", true)
    assert(GG.bounties.me[1].done == 1 and not CALLS.complete, "one of two is progress only")
    -- SAVED AS IT IS COUNTED: a save and load, or any handler that reloads the board,
    -- between the first action and the second must not forget the first.
    GG.load_bounties("me")
    assert(GG.bounties.me[1].done == 1, "hero progress must be saved when it is counted")
    GG.hero_progress("me", DMG, "foe_far", true)
    assert(CALLS.complete and #CALLS.complete == 1, "two of two completes the objective")
    assert(CALLS.complete[1][3] == "derpy_gg_hero", "it completes the hero script key")
    GG.hero_progress("me", DMG, "foe_far", true)
    assert(#CALLS.complete == 1, "a third success must not complete it again")
    ok("only matching successes on the named target count, and completion happens once")
end

do
    -- REVIEW FOCUS 2: completion fires MissionSucceeded synchronously, and its handler
    -- reloads and pays. The offer must not come back, and must pay once.
    world8()
    GG.bounties.me[2].amount = 1
    local real_complete = cm.complete_scripted_mission_objective
    cm.complete_scripted_mission_objective = function(_, f, key)
        HANDLERS.gg_mission({faction = function() return W.fi(f) end,
                             mission = function()
                                 return {mission_record_key = function() return key end}
                             end})
    end
    local rep0 = select(1, GG.get("me", "khanate"))
    GG.hero_progress("me", WOUND, "31", true)
    local rep1 = select(1, GG.get("me", "khanate"))
    assert(rep1 - rep0 == 80, "the strike must pay once, paid " .. (rep1 - rep0))
    GG.load_bounties("me")
    assert(not GG.bounty_for_guild("me", "khanate"), "a paid strike must not come back")
    cm.complete_scripted_mission_objective = real_complete
    ok("a completion that re-enters the mission handler pays once and stays paid")
end

do
    -- The target is gone: sabotage voids and refunds; a dead strike target completes.
    world8()
    GG.bounties.me[1].stake = 20
    GG.save_bounties("me")
    R.foe_far.owner = "me"                        -- captured
    GG.void_stale_hero_bounties("me")
    assert(CALLS.cancel and CALLS.cancel[1][2] == "derpy_gg_hero_daemonsmiths",
           "a captured sabotage target must cancel the mission")
    GG.load_bounties("me")
    assert(GG.bounty_for_guild("me", "daemonsmiths").void == true,
           "the voided offer must be saved void before the cancel")
    CALLS = {}
    GG.drop_bounty_target(31)
    assert(CALLS.complete and CALLS.complete[1][2] == "derpy_gg_job_khanate",
           "a destroyed strike target completes the strike")
    ok("a vanished target voids sabotage and completes a strike")
end

do
    -- Hero bounties may name the front, and post for Dwarfs and Empire too.
    world4()
    local o = GG.make_offer("me", "daemonsmiths", "hero_sabotage", 1, {})
    assert(o and (o.target == "foe_near" or o.target == "foe_far"), "sabotage has a target")
    local near = GG.bounty_target("me", "hero_sabotage", {foe_far = true}, false)
    assert(near == "foe_near", "hero work may be done on the front")
    for _, c in ipairs({"wh_main_dwf_dwarfs", "wh_main_emp_empire"}) do
        world4()
        GG.CULTURE_OF.me = c
        local h = GG.make_offer("me", "immortals", "hero_harry", 1, {})
        assert(h, c .. " must get a hero bounty")
        local s = GG.bounty_string("me", h)
        assert(s:find("type SCRIPTED;script_key derpy_gg_hero;override_text "
                      .. "mission_text_text_derpy_gg_hero_harry" .. GG.tag("me") .. ";", 1, true), s)
    end
    ok("hero bounties allow the front and serve Dwarfs and Empire")
end

do
    -- AN UNTAKEN HARRY OFFER GOES WITH ITS TARGET'S ARMY (2026-09-29). A taken one was
    -- already voided on this test; an untaken one sat on the board.
    world4()
    local h = GG.make_offer("me", "immortals", "hero_harry", 1, {})
    assert(h and C[h.target], "harry needs a lord to name")
    assert(GG.bounty_still_valid("me", h), "a lord with an army is a harry target")
    C[h.target].army = false
    assert(not GG.bounty_still_valid("me", h), "a lord who lost his army is not")
    -- A KILL is not harrying: an armyless lord is still a kill target. The far lord, 31,
    -- because harry may name the one on the front, where a kill offer is never posted.
    C["31"].army = false
    local kill = {guild = "khanate", kind = "lord_kill", target = "31", owner = "foe",
                  war = 0}
    assert(GG.bounty_still_valid("me", kill), "an armyless lord can still be killed")
    ok("an untaken harry offer is withdrawn when its lord has no army")
end

-- ------------------------------------------------- AI bounties: one offer format --
do
    W.reset()
    local o = {guild = "brass", kind = "region_take", target = "r1", owner = "foe",
               gold = 3000, rep = 80, posted = 4, taken = true, diff = 12,
               war = 1, stake = 20, amount = 7, done = 1, void = true}
    local s = GG.pack_offer(o)
    assert(s == "brass,region_take,r1,foe,3000,80,4,1,12,1,20,7,1,1", "packed as " .. s)
    local back = GG.unpack_offer(s)
    for k, v in pairs(o) do
        assert(back[k] == v, k .. " did not round-trip: " .. tostring(back[k]))
    end
    assert(GG.unpack_offer("brass,no_such_kind,r1") == nil, "an unknown kind unpacks to nil")
    -- The player's board string is what it always was.
    GG.bounties.me = {o}
    GG.save_bounties("me")
    assert(cm:get_saved_value("derpy_gg_bounties_me") == s, "the board string changed")
    ok("one offer format, and the player's board string is unchanged")
end

-- ------------------------------------------ AI bounties: who a rival may name --
-- "rival" is a Chaos Dwarf AI faction, the player's own race: only those hold standing.
local function worldA()
    world4()
    F.me.lords = {10}
    W.char(10, {faction = "me", general = true, x = 0, y = 0})
    W.faction("rival", {regions = {"rival_home"}, lords = {60}})
    -- Its front: foe_near and my home touch it. foe_far and every lord are far from it.
    W.region("rival_home", {owner = "rival", x = 9000, y = 9000, adj = {"foe_near", "home"}})
    W.char(60, {faction = "rival", general = true, x = 9000, y = 9000, rank = 5})
    F.rival.met = {"me", "foe", "friend"}
    F.rival.at_war = {me = true, foe = true}
    F.me.at_war.rival, F.foe.at_war.rival = true, true
end

do
    worldA()
    F.rival.at_war = {me = true}
    local t, owner = GG.bounty_target("rival", "region_take", {}, false, "brass", true)
    assert(t == "home" and owner == "me",
           "a rival at war with a human may name the human's region, got " .. tostring(t))
    assert(GG.bounty_target("rival", "region_take", {}, false, "brass") == nil,
           "without the flag a human is never a target")
    -- THE FRONT IS ALLOWED: foe_near touches the rival's own home.
    F.rival.at_war = {foe = true}
    assert(GG.bounty_target("rival", "region_take", {foe_far = true}, false, "brass") == nil,
           "setup: without the flag the front is refused")
    local near = GG.bounty_target("rival", "region_take", {foe_far = true}, false, "brass", true)
    assert(near == "foe_near", "a rival may name the front, got " .. tostring(near))
    ok("a rival may name a human's holdings and its own front")
end

do
    -- FINAL REVIEW: ONLY its own front. A target across the map is one it never reaches.
    worldA()
    F.rival.at_war = {foe = true}
    local far = GG.bounty_target("rival", "region_take", {foe_near = true}, false, "brass", true)
    assert(far == nil, "a region far from the rival is never its target, got " .. tostring(far))
    local lord = GG.bounty_target("rival", "lord_kill", {}, false, "immortals", true)
    assert(lord == nil, "a lord far from the rival is never its target, got " .. tostring(lord))
    W.char(32, {faction = "foe", general = true, x = 9100, y = 9000})
    W.char(33, {faction = "foe", x = 5000, y = 5000})                    -- a far hero
    F.foe.lords, F.foe.heroes = {30, 31, 32}, {33}
    lord = GG.bounty_target("rival", "lord_kill", {}, false, "immortals", true)
    assert(lord == "32", "a lord beside the rival's town is, got " .. tostring(lord))
    local hero = GG.bounty_target("rival", "hero_strike", {["32"] = true}, false, "khanate", true)
    assert(hero == nil, "a hero far from the rival is never its target, got " .. tostring(hero))
    C["33"].x, C["33"].y = 9000, 9100
    hero = GG.bounty_target("rival", "hero_strike", {["32"] = true}, false, "khanate", true)
    assert(hero == "33", "a hero beside it is, got " .. tostring(hero))
    ok("a rival names only what stands on its own front")
end

do
    worldA()
    F.rival.at_war = {}
    RANDOM = function(n) if n == 3 then return 3 end return 1 end
    assert(GG.make_offer("rival", "brass", "region_take", 1, {}, true) == nil,
           "a rival at war with nobody names nothing, even on a new-war roll")
    F.rival.at_war = {foe = true}
    local o = GG.make_offer("rival", "brass", "region_take", 1, {}, true)
    assert(o and o.war == 0 and (o.target == "foe_near" or o.target == "foe_far"),
           "a rival's offer is a war it already fights, got " .. tostring(o and o.target))
    RANDOM = function(n) return 1 end
    ok("a rival's bounty is never a new war and never names a faction at peace")
end

-- ------------------------------------------------ AI bounties: taking one --
do
    worldA()
    F.rival.at_war = {foe = true}
    assert(GGAI.take_bounty("rival", 1) == nil, "no favour anywhere means no bounty")
    GG.grant("rival", "immortals", 400, "test")          -- the SECOND guild only
    local _, fav0 = GG.get("rival", "immortals")
    local o = GGAI.take_bounty("rival", 1)
    assert(o and o.guild == "immortals",
           "the first guild it can afford, got " .. tostring(o and o.guild))
    assert(o.taken and o.war == 0 and o.stake > 0, "taken, never a new war, with a stake")
    local _, fav1 = GG.get("rival", "immortals")
    assert(fav0 - fav1 == o.stake, "the stake is spent, spent " .. (fav0 - fav1))
    assert(GG.bounties.rival == nil, "a rival's bounty never touches the player's board")
    GGAI.bounty.rival = nil
    local back = GGAI.load_bounty("rival")
    assert(back and back.kind == o.kind and back.target == o.target, "it survives a save")
    ok("a rival takes from the first guild it can afford and spends the stake")
end

do
    worldA()
    F.rival.at_war = {}
    GG.grant("rival", "slavers", 400, "test")
    assert(GG.make_offer("rival", "slavers", "job_captives", 1, {}),
           "setup: the player's board would post Fill the Pens")
    assert(GGAI.offer("rival", "slavers", 1) == nil, "a rival never takes Fill the Pens")
    ok("a rival never takes Fill the Pens")
end

do
    -- FINAL REVIEW: two hits on one named target by heroes nobody aims is close to never.
    worldA()
    F.rival.at_war = {foe = true}
    W.char(32, {faction = "foe", general = true, x = 9100, y = 9000})
    F.foe.lords = {30, 31, 32}
    GG.grant("rival", "immortals", 400, "test")
    GG.grant("rival", "daemonsmiths", 400, "test")
    for _, guild in ipairs({"immortals", "daemonsmiths"}) do
        for start = 1, 4 do
            RANDOM = function(n) return math.min(start, n) end
            local o = GGAI.offer("rival", guild, 1)
            assert(not (o and (o.kind == "hero_harry" or o.kind == "hero_sabotage")),
                   guild .. " offered a rival " .. tostring(o and o.kind))
        end
    end
    RANDOM = function(n) return 1 end
    ok("a rival never takes hero work that needs two hits")
end

do
    -- FINAL REVIEW: a rival that cannot put up the least stake walks nothing. GGAI.step
    -- spends favour just before the sweep, so this is the common case.
    worldA()
    F.rival.at_war = {foe = true}
    for _, g in ipairs(GG.GUILDS) do GG.grant("rival", g, 1, "test") end
    assert(GG.bounty_stake(GG.bounty_pay()) > 1, "setup: one favour is short of every stake")
    local walks, real = 0, GG.bounty_target
    GG.bounty_target = function(...) walks = walks + 1 return real(...) end
    local o = GGAI.take_bounty("rival", 1)
    GG.bounty_target = real
    assert(o == nil, "a broke rival takes nothing")
    assert(walks == 0, "a broke rival walked the map " .. walks .. " times")
    ok("a rival short of every stake walks nothing")
end

do
    worldA()
    -- rival2 borders my town too, or its front alone would keep it off my town.
    W.faction("rival2", {met = {"me"}, regions = {"rival2_home"}})
    W.region("rival2_home", {owner = "rival2", x = 0, y = 9000, adj = {"home"}})
    F.rival.at_war, F.rival2.at_war = {me = true}, {me = true}
    GG.grant("rival", "brass", 400, "test")
    GG.grant("rival2", "brass", 400, "test")
    F.me.lords = {}
    local a = GGAI.take_bounty("rival", 1)
    local b = GGAI.take_bounty("rival2", 1)
    assert(a and a.target == "home", "setup: the first rival takes my only town")
    assert(b and b.target ~= "home",
           "two rivals never hold one target, got " .. tostring(b and b.target))
    ok("no two rivals hold one target")
end

do
    worldA()
    F.rival.at_war = {me = true}
    F.me.lords = {}
    GG.grant("rival", "brass", 400, "test")
    local o = GGAI.take_bounty("rival", 1)
    assert(o and o.target == "home" and o.owner == "me", "setup: a bounty on my town")
    local e = GG.log_entries("me")
    assert(e[1] and e[1].kind == "hunted" and e[1].guild == "brass" and e[1].a == "home"
           and e[1].b == "rival", "the hunted player's Log must say so")
    assert(CALLS.located and #CALLS.located == 1, "one located feed message")
    local c = CALLS.located[1]
    assert(c[1] == "me" and c[7] == false and c[8] == GG.FEED_INDEX_HUNTED,
           "to me, transient, at the hunted index: " .. tostring(c[7]) .. " " .. tostring(c[8]))
    assert(c[2] == "message_event_text_text_derpy_gg_hunted_title", c[2])
    -- NOT ON A HUMAN: nothing said, nothing called.
    worldA()
    F.rival.at_war = {foe = true}
    GG.grant("rival", "brass", 400, "test")
    GGAI.take_bounty("rival", 1)
    assert(not CALLS.located and #GG.log_entries("me") == 0, "a bounty on an AI is silent")
    ok("a bounty on a human is logged and announced where it stands")
end

-- --------------------------------------------- AI bounties: how one ends --
local function takenA(kind, target, extra)
    extra = extra or {}
    worldA()
    GG.grant("rival", "brass", 400, "test")
    local o = {guild = "brass", kind = kind, target = target, owner = extra.owner or "foe",
               gold = 1000, rep = 80, posted = 1, taken = true, diff = 0, war = 0,
               stake = 20, amount = extra.amount or 0, done = 0, void = false}
    GGAI.bounty.rival = o
    GGAI.save_bounty("rival")
    return o
end

do
    takenA("region_take", "foe_far")
    local rep0, fav0 = GG.get("rival", "brass")
    assert(GGAI.settle_bounty("rival", 2) == false, "not done yet: nothing happens")
    R.foe_far.owner = "rival"
    assert(GGAI.settle_bounty("rival", 3) == true, "the rival holds it: done")
    local rep1, fav1 = GG.get("rival", "brass")
    assert(rep1 - rep0 == 80, "done pays the Reputation, paid " .. (rep1 - rep0))
    assert(fav1 - fav0 == 100, "done returns the stake and pays favour, got " .. (fav1 - fav0))
    assert(CALLS.treasury and CALLS.treasury[1][1] == "rival" and CALLS.treasury[1][2] == 1000,
           "done pays the gold")
    assert(GGAI.bounty.rival == nil and cm:get_saved_value(GGAI.bounty_key("rival")) == "",
           "done clears the bounty and its save")
    assert(GGAI.settle_bounty("rival", 4) == false and #CALLS.treasury == 1, "paid once")
    ok("a finished bounty pays stake, Reputation and gold once")
end

do
    local o = takenA("region_take", "foe_far")
    local rep0 = GG.get("rival", "brass")
    assert(GGAI.settle_bounty("rival", GG.BOUNTY_TURN_LIMIT) == false,
           "one turn short of the limit is not a failure")
    assert(GGAI.settle_bounty("rival", 1 + GG.BOUNTY_TURN_LIMIT) == true, "the limit fails it")
    assert(rep0 - GG.get("rival", "brass") == GG.bounty_fail_cost(o),
           "a failure costs what the player's would")
    takenA("region_take", "foe_far")
    R.foe_far.owner = "rival"
    local r0 = GG.get("rival", "brass")
    GGAI.settle_bounty("rival", 1 + GG.BOUNTY_TURN_LIMIT)
    assert(GG.get("rival", "brass") - r0 == 80, "finished on its last turn is paid, not failed")
    ok("a rival's failure costs Reputation, and done beats the deadline")
end

do
    takenA("hero_sabotage", "foe_far", {amount = 2})
    local rep0, fav0 = GG.get("rival", "brass")
    R.foe_far.owner = "friend"            -- the rival is not at war with friend
    assert(GGAI.settle_bounty("rival", 2), "a sabotage target no enemy holds voids it")
    local rep1, fav1 = GG.get("rival", "brass")
    assert(fav1 - fav0 == 20 and rep1 == rep0, "a void refunds the stake with no penalty")
    ok("a void refunds the stake with no penalty")
end

do
    takenA("job_coffers", "job_coffers", {amount = 5000})
    F.rival.treasury = 4999
    assert(not GGAI.settle_bounty("rival", 2), "coffers one short")
    F.rival.treasury = 5000
    assert(GGAI.settle_bounty("rival", 2), "coffers met")
    takenA("job_champion", "job_champion", {amount = 9})
    C["60"].rank = 8
    assert(not GGAI.settle_bounty("rival", 2), "champion one rank short")
    C["60"].rank = 9
    assert(GGAI.settle_bounty("rival", 2), "champion met")
    takenA("job_research", "tech_x")
    assert(not GGAI.settle_bounty("rival", 2), "research not yet")
    F.rival.techs = {tech_x = true}
    assert(GGAI.settle_bounty("rival", 2), "research done")
    takenA("job_build", "lvl_x")
    assert(not GGAI.settle_bounty("rival", 2), "build not yet")
    R.rival_home.buildings = {lvl_x = true}
    assert(GGAI.settle_bounty("rival", 2), "build done")
    ok("each job is read off the rival itself")
end

do
    -- REVIEW FOCUS 5: a read that throws neither pays nor voids.
    takenA("region_take", "foe_far")
    local real = cm.get_region
    cm.get_region = function() error("unreadable") end
    assert(GGAI.settle_bounty("rival", 2) == false, "an unreadable region is not done")
    takenA("hero_sabotage", "foe_far", {amount = 2})
    cm.get_region = function() error("unreadable") end
    assert(GGAI.settle_bounty("rival", 2) == false, "an unreadable hero target is not void")
    cm.get_region = real
    ok("an unreadable model neither pays nor voids")
end

do
    -- REVIEW FOCUS 2: a bounty on my town reports its end to me even after I lost it.
    takenA("region_take", "home", {owner = "me"})
    R.home.owner = "rival"
    GGAI.settle_bounty("rival", 2)
    local e = GG.log_entries("me")
    assert(#e == 1 and e[1].kind == "hunt_done" and e[1].a == "home" and e[1].b == "rival",
           "the hunted player hears hunt_done and nothing else")
    takenA("region_take", "home", {owner = "me"})
    GGAI.settle_bounty("rival", 1 + GG.BOUNTY_TURN_LIMIT)
    assert(GG.log_entries("me")[1].kind == "hunt_failed", "a failed hunt is logged")
    takenA("hero_sabotage", "home", {owner = "me", amount = 2})
    R.home.owner = "friend"
    GGAI.settle_bounty("rival", 2)
    assert(GG.log_entries("me")[1].kind == "hunt_void", "a withdrawn hunt is logged")
    -- THE RACE: a same-race rival's finish on someone else.
    takenA("region_take", "foe_far")
    R.foe_far.owner = "rival"
    GGAI.settle_bounty("rival", 2)
    e = GG.log_entries("me")
    assert(e[1].kind == "ai_bounty" and e[1].b == "rival" and tonumber(e[1].a) == 80,
           "a rival of my race finishing a bounty is in my Log")
    takenA("region_take", "foe_far")
    -- Both: GG.covered caches the culture it read, and takenA may already have read it.
    F.rival.culture, GG.CULTURE_OF.rival = "wh_main_emp_empire", "wh_main_emp_empire"
    R.foe_far.owner = "rival"
    GGAI.settle_bounty("rival", 2)
    assert(#GG.log_entries("me") == 0, "another race's rival is not")
    ok("the hunted hear how it ended, and the race is in the Log")
end

-- ------------------------------------ AI bounties: what the listeners mark --
do
    takenA("region_sack", "foe_far")
    local function sack(who, region)
        HANDLERS.gg_sack_CharacterSackedSettlement({
            character = function() return W.ci(who) end,
            garrison_residence = function() return W.ri(region):garrison_residence() end})
    end
    sack(30, "foe_far")                     -- the foe itself: not the holder
    sack(60, "foe_near")                    -- the holder, the wrong town
    assert(GGAI.load_bounty("rival").done == 0, "only the holder's sack of the target counts")
    sack(60, "foe_far")
    assert(GGAI.load_bounty("rival").done == 1, "the holder's sack of the target counts")
    assert(GGAI.settle_bounty("rival", 2), "and finishes it")
    ok("a sack counts only by the holder, on the target")
end

do
    -- REVIEW FOCUS 3: a new session - nothing indexed - then the lord dies.
    takenA("lord_kill", "31")
    GGAI.indexed, GGAI.by_target, GGAI.bounty = false, {}, {}
    HANDLERS.gg_character_destroyed({family_member = function() return W.ci(31):family_member() end})
    assert(GGAI.load_bounty("rival").done == 1, "a lord destroyed by anyone finishes the kill")
    assert(GGAI.settle_bounty("rival", 2), "and it is paid")
    ok("a death counts even before the first sweep of a session")
end

do
    takenA("hero_sabotage", "foe_far", {amount = 2})
    GGAI.hero_progress("rival", DMG, "foe_far", false)
    assert(GGAI.load_bounty("rival").done == 0, "an opportune failure does not count")
    GGAI.hero_progress("rival", SCOUT, "foe_far", true)
    assert(GGAI.load_bounty("rival").done == 0, "scouting does not count")
    GGAI.hero_progress("rival", DMG, "foe_far", true)
    assert(not GGAI.settle_bounty("rival", 2), "one of two is not done")
    GGAI.hero_progress("rival", DMG, "foe_far", true)
    assert(GGAI.settle_bounty("rival", 2), "two of two is")
    assert(GG.bounties.rival == nil, "no AI path writes the player's board")
    ok("a rival's hero work counts to its number")
end

-- ------------------------------------------------ AI bounties: the sweep --
do
    worldA()
    GG.grant("rival", "brass", 400, "test")
    GGAI.bounty_sweep({"rival", "foe"}, 1)
    local o = GGAI.bounty.rival
    assert(o, "a rival with favour and no bounty takes one")
    assert(GGAI.bounty.foe == nil and cm:get_saved_value(GGAI.bounty_key("foe")) == nil,
           "a faction with no standing is not touched")
    local held = o.target
    GGAI.bounty_sweep({"rival"}, 2)
    assert(GGAI.bounty.rival.target == held, "a rival holding a bounty takes no second one")
    R[held].owner = "rival"
    assert(GGAI.bounty_sweep({"rival"}, 3) == 1, "the sweep settles it")
    assert(GGAI.bounty.rival == nil, "settled this round: no new take until the next")
    GGAI.bounty_sweep({"rival"}, 4)
    assert(GGAI.bounty.rival, "the next round takes again")
    ok("the sweep settles first, and takes only when a rival holds nothing")
end

do
    -- FINAL REVIEW: the soak's measure. Whether rivals come out ahead is a rate, and the
    -- script log is the only place a failed rival bounty is ever written down.
    worldA()
    GG.grant("rival", "brass", 400, "test")
    local lines, real = {}, out
    out = function(s) lines[#lines + 1] = s end
    GGAI.bounty_sweep({"rival"}, 1)
    GGAI.bounty_sweep({"rival"}, 2)                  -- held, not done: nothing to say
    R[GGAI.bounty.rival.target].owner = "rival"
    GGAI.bounty_sweep({"rival"}, 3)
    out = real
    local want = {"derpy_gg: rivals' bounties turn 1: 1 taken, 0 paid, 0 failed, 0 withdrawn",
                  "derpy_gg: rivals' bounties turn 3: 0 taken, 1 paid, 0 failed, 0 withdrawn"}
    local got = {}
    for _, s in ipairs(lines) do
        if s:find("rivals' bounties turn", 1, true) then got[#got + 1] = s end
    end
    assert(#got == 2, "one line per round that did something, got " .. #got)
    assert(got[1] == want[1] and got[2] == want[2], "the round's count: " .. tostring(got[1])
           .. " / " .. tostring(got[2]))
    ok("each round's rival bounties are counted in the script log")
end

do
    -- REVIEW FOCUS 4: off means no call and no write.
    for _, how in ipairs({"switch", "rate"}) do
        worldA()
        GG.grant("rival", "brass", 400, "test")
        if how == "switch" then GG.TUNE.ai_bounties = false else GG.TUNE.rate_bounty = 0 end
        GGAI.bounty_sweep({"rival"}, 1)
        assert(GGAI.bounty.rival == nil and cm:get_saved_value(GGAI.bounty_key("rival")) == nil,
               how .. " off: nothing taken, nothing written")
    end
    ok("ai_bounties off, or a bounty rate of 0, stops the rivals")
end

do
    -- THE ROUND ITSELF runs the sweep, and never for a human.
    worldA()
    GG.grant("rival", "brass", 400, "test")
    GG.save("rival")
    local cs, st, sw = GGAI.court_step, GGAI.step, GG.snapshot_world
    GGAI.court_step = function() return false end
    GGAI.step = function() return false end
    GG.snapshot_world = function() end
    GGAI.run_turn()
    GGAI.court_step, GGAI.step, GG.snapshot_world = cs, st, sw
    assert(GGAI.bounty.rival, "the round's sweep takes a rival's bounty")
    assert(cm:get_saved_value(GGAI.bounty_key("me")) == nil, "never a human's")
    ok("the AI round takes rivals' bounties")
end

-- ------------------------------------------------- SERVICE POOLS: Hire's grant --
do
    -- CA documents grant_unit_to_character's first argument as a character LOOKUP
    -- STRING and every CA call builds one with cm:char_lookup_str; a bare cqi is not one.
    W.reset()
    W.char(70, {faction = "me", general = true, x = 0, y = 0})
    F.me.lords = {70}
    GG.CULTURE_OF.me = GG.CHD_CULTURE
    GG.payload("me", GG.service("hire_immortals"), 70)
    assert(CALLS.grant and #CALLS.grant == 1, "one unit granted")
    assert(CALLS.grant[1][1] == "character_cqi:70",
           "the grant takes a lookup string, got " .. tostring(CALLS.grant[1][1]))
    ok("Hire grants its unit through a character lookup string")
end

-- ------------------------------------------------- SERVICE POOLS: the cards --
do
    -- REVIEW FOCUS 1 and 3: a faction with no cards holds today's 18, and reading them
    -- never rolls - the panel reads this, and a roll from UI code desyncs multiplayer.
    W.reset()
    local rolls = 0
    RANDOM = function(n) rolls = rolls + 1 return 1 end
    local keys = GG.cards_of("me")
    assert(#keys == 18, "18 cards, got " .. #keys)
    assert(keys[1] == "caravan_levy" and keys[4] == "oathbound_draft"
           and keys[18] == "great_coffle", "defaults are today's services in card order")
    local g = GG.guild_cards("me", "khanate")
    assert(#g == 3 and g[1].key == "hobgoblin_eyes" and g[3].key == "khans_price",
           "a guild's three cards, ranks 2-4")
    assert(GG.on_card("me", "forge_rite") and not GG.on_card("me", "no_such"),
           "on_card answers from the cards")
    assert(rolls == 0, "reading cards rolled " .. rolls .. " times")
    assert(cm:get_saved_value(GG.cards_key("me")) == nil, "reading cards wrote nothing")
    ok("no cards means today's 18, read without a roll")
end

do
    W.reset()
    -- EVERY SLOT HOLDS A NON-DEFAULT KEY, the last row of its pool: a load that answered
    -- the slot defaults would pass a check on a default key (final review, 2026-09-29).
    local drawn = {}
    for _, g in ipairs(GG.GUILDS) do
        for _, r in ipairs(GG.CARD_RANKS) do
            local last = nil
            for _, s in ipairs(GG.SERVICES) do
                if s.guild == g and s.rank == r then last = s.key end
            end
            assert(last ~= GG.default_card(g, r), "setup: " .. g .. " rank " .. r)
            drawn[#drawn + 1] = last
        end
    end
    GG.cards.me = {turn = 3, keys = {unpack(drawn)}}
    GG.save_cards("me")
    GG.cards.me = nil
    GG.load_cards("me")
    assert(GG.cards.me and GG.cards.me.turn == 3, "cards survive a save")
    for i = 1, #drawn do
        assert(GG.cards.me.keys[i] == drawn[i], "card " .. i .. " saved as " .. drawn[i]
               .. ", loaded as " .. tostring(GG.cards.me.keys[i]))
    end
    -- AND THROUGH GG.load, which every listener calls: a load that skipped the cards would
    -- show today's 18 until the next draw.
    GG.cards.me = nil
    GG.load("me")
    assert(GG.cards.me and GG.cards.me.keys[18] == drawn[18],
           "GG.load must restore the drawn cards, got " .. tostring(GG.cards.me and GG.cards.me.keys[18]))
    -- A KEY THIS BUILD DOES NOT SELL, or one in the wrong slot, reads as that slot's
    -- default rather than nil.
    cm:set_saved_value(GG.cards_key("me"), "4;gone_service" .. string.rep(",caravan_levy", 17))
    GG.load_cards("me")
    assert(GG.cards.me.keys[1] == "caravan_levy" and GG.cards.me.keys[4] == "oathbound_draft",
           "an unknown or misplaced key reads as that slot's default")
    cm:set_saved_value(GG.cards_key("me"), "garbage")
    GG.load_cards("me")
    assert(GG.cards.me == nil, "an unreadable value is no cards at all")
    ok("cards save and load, and a bad value falls back")
end

do
    -- THE GATE: not on a card, not for sale.
    W.reset()
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
    GG.cooldowns.me = {}
    GG.CULTURE_OF.me = GG.CHD_CULTURE
    assert(GG.can_buy("me", "forge_rite"), "setup: a default card sells")
    GG.cards.me = {turn = 1, keys = GG.cards_of("me")}
    GG.cards.me.keys[7] = "bound_blueprint"            -- the daemonsmiths rank-2 slot
    local okb, why = GG.can_buy("me", "forge_rite")
    assert(not okb and why == "card", "off the cards is refused as card, got " .. tostring(why))
    ok("a service not on the faction's cards is refused")
end

-- ------------------------------------------------- SERVICE POOLS: the draw --
local function with_pool_rows(fn)
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_brass2_a", guild = "brass", rank = 2, cost = 50, cd = 8,
                          kind = "bundle", turns = 5}
    GG.SERVICES[n + 2] = {key = "t_brass2_b", guild = "brass", rank = 2, cost = 50, cd = 8,
                          kind = "bundle", turns = 5}
    local okf, err = pcall(fn)
    GG.SERVICES[n + 2], GG.SERVICES[n + 1] = nil, nil
    if not okf then error(err, 0) end
end

do
    with_pool_rows(function()
        W.reset()
        local p = GG.pool("me", "brass", 2)
        assert(#p >= 3 and p[1].key == "caravan_levy",
               "a card's pool is its guild and rank, today's service first")
        -- NEVER THE SAME TWICE: the stub rolls 1, so without the rule every draw would
        -- land on the pool's first row.
        GG.draw_cards("me", 10)
        local first = GG.cards_of("me")[1]
        assert(first ~= "caravan_levy", "the first draw leaves today's service")
        GG.draw_cards("me", 20)
        assert(GG.cards_of("me")[1] ~= first, "and the next leaves that one")
        assert(cm:get_saved_value(GG.cards_key("me")) ~= nil, "a draw is saved")
        -- A POOL OF ONE keeps its one; an EMPTY pool keeps what the card held.
        local real = GG.pool
        GG.pool = function(f, g, r)
            if g == "immortals" and r == 2 then return {GG.service("oathbound_draft")} end
            if g == "immortals" and r == 3 then return {} end
            return real(f, g, r)
        end
        GG.cards.me.keys[5] = "hire_immortals"
        GG.draw_cards("me", 30)
        GG.pool = real
        assert(GG.cards_of("me")[4] == "oathbound_draft", "a pool of one keeps its row")
        assert(GG.cards_of("me")[5] == "hire_immortals", "an empty pool keeps the card")
    end)
    ok("a draw never repeats a card when the pool has another")
end

do
    with_pool_rows(function()
        W.reset()
        GG.TUNE.rotate_turns = 10
        -- A NEW CAMPAIGN draws on turn one. A save with no cards past turn one keeps the
        -- original 18 until its period ends (2026-09-29; was: every first call drew).
        assert(GG.rotate_cards("me", 1) == true, "no cards on turn one: a new campaign draws")
        GG.cards.me = nil
        assert(GG.rotate_cards("me", 3) == false, "no cards later: an old save keeps them")
        assert(GG.cards.me and GG.cards.me.turn == 3, "and records them for this period")
        assert(GG.rotate_cards("me", 9) == false, "same period: no redraw")
        assert(GG.rotate_cards("me", 10) == true, "turn 10 starts a new period")
        assert(GG.rotate_cards("me", 10) == false, "and draws once, whoever calls it again")
        assert(GG.rotate_cards("me", 37) == true, "a skipped period catches up once")
        assert(GG.rotate_cards("me", 39) == false, "not twice")
        GG.TUNE.rotate_turns = 0
        assert(GG.rotation_turns() == 10, "an unusable setting reads as 10")
    end)
    ok("the clock is the turn number, and each period draws once")
end

do
    -- REVIEW FOCUS 4: a service rotated off its card while a pick is open is refused.
    with_pool_rows(function()
        W.reset()
        GG.state.me = {}
        for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
        GG.cooldowns.me = {}
        GG.CULTURE_OF.me = GG.CHD_CULTURE
        assert(GG.can_buy("me", "caravan_levy"), "setup: today's card sells")
        GG.draw_cards("me", 10)                       -- caravan_levy leaves its card
        local okb, why = GG.buy("me", "caravan_levy", nil)
        assert(not okb and why == "card", "a rotated-off service is refused, got " .. tostring(why))
    end)
    ok("a purchase of a service that just rotated off is refused")
end

do
    -- REVIEW FOCUS 5: hostile services off - never drawn.
    W.reset()
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_khan4", guild = "khanate", rank = 4, cost = 400, cd = 16,
                          kind = "enemy_settlement", turns = 5, lead = true}
    GG.TUNE.hostile_services = false
    local off = GG.pool("me", "khanate", 4)
    GG.TUNE.hostile_services = true
    local on = GG.pool("me", "khanate", 4)
    GG.SERVICES[n + 1] = nil
    for _, s in ipairs(off) do
        assert(not s.hostile and s.kind ~= "enemy_settlement",
               s.key .. " is in a pool with hostile services off")
    end
    assert(#off < #on, "the switch takes something out of the pool")
    ok("hostile services off keeps them out of every pool")
end

do
    -- THE RIVALS' ROUND DRAWS TOO, so a rival whose own turn comes later in the round
    -- still buys from this period's cards. Never a human's: its own turn start does that.
    worldA()
    GG.TUNE.rotate_turns = 10
    TURN = 20
    local cs, st, sw = GGAI.court_step, GGAI.step, GG.snapshot_world
    GGAI.court_step = function() return false end
    GGAI.step = function() return false end
    GG.snapshot_world = function() end
    GGAI.run_turn()
    GGAI.court_step, GGAI.step, GG.snapshot_world = cs, st, sw
    assert(GG.cards.rival and GG.cards.rival.turn == 20, "the round drew the rival's cards")
    assert(GG.cards.me == nil, "and not the human's")
    ok("the rivals' round draws a rival's cards")
end

do
    -- Read on every preset, like the switches: it sits in the systems section, and a
    -- slider that only counts under Custom would look live and do nothing.
    local found = false
    for _, k in ipairs(GG.TUNE_ORDER) do if k == "rotate_turns" then found = true end end
    assert(found and GG.TUNE_DEFAULTS.rotate_turns == 10, "rotate_turns is a setting, default 10")
    assert(GG.EVERY_PRESET and GG.EVERY_PRESET.rotate_turns, "read on every preset")
    ok("rotate_turns is a setting read on every preset")
end

-- ------------------------------------------------- SERVICE POOLS: the notice --
do
    W.reset()
    GG.TUNE.rotate_turns = 10
    GG.rotate_cards("me", 1)                          -- first draw: silent
    assert(not CALLS.message and #GG.log_entries("me") == 0, "the first draw says nothing")
    GG.rotate_cards("me", 10)
    assert(CALLS.message and #CALLS.message == 1, "a rotation raises one message")
    local c = CALLS.message[1]
    assert(c[1] == "me" and c[2] == "message_event_text_text_derpy_gg_rotation_title"
           and c[5] == true and c[6] == GG.FEED_INDEX_ROTATION,
           "to me, persistent, at the rotation index")
    assert(GG.log_entries("me")[1].kind == "rotation", "and one Log line")
    -- Not for a rival, and not with notices off.
    W.faction("ai1", {})
    GG.rotate_cards("ai1", 1)
    GG.rotate_cards("ai1", 10)
    assert(#CALLS.message == 1, "a rival's rotation is silent")
    GG.TUNE.guild_notices = false
    GG.rotate_cards("me", 20)
    assert(#CALLS.message == 1, "notices off: no message")
    assert(#GG.log_entries("me") == 2, "but the Log still records it")
    ok("a rotation tells a human once, and never a rival")
end

-- ------------------------------------------- SERVICE POOLS: the new kinds --
local function kinds_world()
    worldA()                                   -- me at war with foe; 10 is my lord
    GG.CULTURE_OF.me = GG.CHD_CULTURE
    W.char(71, {faction = "me", general = true, x = 0, y = 0})
    W.char(72, {faction = "me", x = 0, y = 0})             -- a hero of mine
    F.me.lords, F.me.heroes = {10, 71}, {72}
end

do
    kinds_world()
    GG.payload("me", {key = "t_army", guild = "immortals", kind = "army", turns = 3,
                      heal = true}, 71)
    assert(CALLS.force_bundle[1][1] == "derpy_gg_svc_t_army"
           and CALLS.force_bundle[1][2] == 1071 and CALLS.force_bundle[1][3] == 3,
           "an army bundle lands on the general's FORCE cqi")
    assert(CALLS.heal and CALLS.heal[1][1] == 1071, "heal = true heals that force")
    GG.payload("me", {key = "t_set", guild = "overseers", kind = "settlement", turns = 8},
               "home")
    assert(CALLS.region_bundle[1][2] == "home" and CALLS.region_bundle[1][3] == 8,
           "a settlement bundle lands on the region")
    GG.payload("me", {key = "t_rk", guild = "khanate", kind = "ranks", value = 3}, 72)
    assert(CALLS.ranks[1][1] == "character_cqi:72" and CALLS.ranks[1][2] == 3
           and CALLS.ranks[1][3] == true, "ranks: lookup string, n, and true for ranks")
    GG.payload("me", {key = "t_loan", guild = "brass", kind = "gold", value = 6000,
                      turns = 10, with_bundle = true}, nil)
    assert(CALLS.treasury[#CALLS.treasury][2] == 6000, "the loan pays")
    local found = false
    for _, c in ipairs(CALLS.bundle or {}) do
        if c[1] == "derpy_gg_svc_t_loan" and c[2] == "me" and c[3] == 10 then found = true end
    end
    assert(found, "and applies its bundle to the buyer")
    ok("each new kind calls the game the way CA documents it")
end

do
    -- REVIEW FOCUS 2: a buff never lands on an enemy.
    kinds_world()
    local army = {key = "t_army", guild = "immortals", kind = "army", turns = 3}
    assert(GG.target_ok("me", army, 71), "my general's army is a target")
    assert(not GG.target_ok("me", army, 30), "an enemy general's army is not")
    assert(not GG.target_ok("me", army, 72), "a hero has no army")
    local rk = {key = "t_rk", guild = "khanate", kind = "ranks", value = 3}
    assert(GG.target_ok("me", rk, 72) and not GG.target_ok("me", rk, 30),
           "ranks go to my own characters only")
    local settle = {key = "t_set", guild = "overseers", kind = "settlement", turns = 8}
    assert(GG.target_ok("me", settle, "home") and not GG.target_ok("me", settle, "foe_near"),
           "a settlement service takes my own settlement only")
    local hostile = {key = "t_en", guild = "khanate", kind = "enemy_settlement", turns = 5}
    assert(GG.target_ok("me", hostile, "foe_near"), "an enemy settlement is a target")
    assert(not GG.target_ok("me", hostile, "home"), "my own is not")
    assert(not GG.target_ok("me", hostile, "friend_town"), "a faction I am not at war with is not")
    assert(not GG.target_ok("me", GG.service("hire_immortals"), 30),
           "Hire never gives an enemy general a regiment")
    assert(not GG.target_ok("me", army, nil), "nothing selected is no target")
    ok("a friendly service never targets an enemy, a hostile one only an enemy")
end

do
    kinds_world()
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
    GG.cooldowns.me = {}
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_army", guild = "immortals", rank = 2, cost = 50, cd = 8,
                          kind = "army", turns = 3}
    GG.cards.me = {turn = 1, keys = GG.cards_of("me")}
    GG.cards.me.keys[4] = "t_army"
    local okb, why = GG.buy("me", "t_army", 30)
    local okc = GG.buy("me", "t_army", 71)
    GG.SERVICES[n + 1] = nil
    assert(not okb and why == "target", "the till refuses a bad target, got " .. tostring(why))
    assert(okc, "and sells on a good one")
    -- The hostile switch covers enemy-settlement services at the till too.
    GG.TUNE.hostile_services = false
    GG.SERVICES[n + 1] = {key = "t_en", guild = "khanate", rank = 3, cost = 150, cd = 12,
                          kind = "enemy_settlement", turns = 5}
    GG.cards.me.keys[11] = "t_en"                    -- the khanate rank-3 slot
    local okh, whyh = GG.can_buy("me", "t_en")
    GG.SERVICES[n + 1] = nil
    GG.TUNE.hostile_services = true
    assert(not okh and whyh == "disabled",
           "hostile services off refuses an enemy-settlement service, got " .. tostring(whyh))
    ok("the till checks the target, and the hostile switch covers enemy settlements")
end

-- ------------------------------------------------ SERVICE POOLS: the catalogue --
do
    -- THREE PER CARD, and every new row a shape the payload knows.
    W.reset()
    local kinds = {bundle = 1, gold = 1, research = 1, unit = 1, shroud = 1, building = 1,
                   pooled = 1, army = 1, settlement = 1, enemy_settlement = 1, ranks = 1}
    for _, g in ipairs(GG.GUILDS) do
        for _, r in ipairs(GG.CARD_RANKS) do
            -- THE SHARED ROWS: a race's own services join the pool (stage 2).
            local p = {}
            for _, s in ipairs(GG.pool("me", g, r)) do
                if not s.race then p[#p + 1] = s end
            end
            assert(#p == 3, g .. " rank " .. r .. " has " .. #p .. " services, not 3")
        end
    end
    local shared = 0
    for _, s in ipairs(GG.SERVICES) do if not s.race then shared = shared + 1 end end
    assert(shared == 54, "54 shared services, got " .. shared)
    for i = 19, 54 do
        local s = GG.SERVICES[i]
        assert(kinds[s.kind], s.key .. " has kind " .. tostring(s.kind))
        assert((s.rank == 4) == (s.lead == true), s.key .. ": lead exactly on rank 4")
        assert(s.cost == ({50, 150, 400})[s.rank - 1] and s.cd == ({8, 12, 16})[s.rank - 1],
               s.key .. ": cost and cooldown follow its rank")
        assert(s.kind ~= "bundle" or (s.turns or 0) > 0, s.key .. ": a bundle needs turns")
    end
    ok("every card has three services, and every new one is a known shape")
end

-- ------------------------------------ SERVICE POOLS: final review (2026-09-29) --
do
    -- A RIVAL'S ENEMY-SETTLEMENT SERVICE ON A HUMAN IS A HIT. Its target is a region key,
    -- not a faction, so the victim is the region's owner - the MCT tooltip promises that
    -- a rival's service landing on you is always announced.
    worldA()
    local s = GG.service("sow_discord")
    GGAI.report("rival", s, "home")
    GGAI.log_purchase("rival", s, "home")
    local msg = nil
    for _, c in ipairs(CALLS.message or {}) do
        if c[1] == "me" then msg = c end
    end
    assert(msg and string.find(msg[2], "derpy_gg_hit", 1, true),
           "Sow Discord on the player's region raised no hit message")
    local hit = false
    for _, e in ipairs(GG.log_entries("me")) do
        if e.kind == "hit" and e.a == "sow_discord" and e.b == "rival" then hit = true end
    end
    assert(hit, "Sow Discord on the player's region wrote no hit line to their Log")

    -- On someone else's region it is not the player's business, and a friendly service
    -- on the player's own region is not a hit.
    worldA()
    GGAI.report("rival", s, "foe_near")
    GGAI.report("rival", GG.service("granaries"), "home")
    assert(#(CALLS.message or {}) == 0,
           "a hit message for a service that did not land on a human")
    ok("a rival's enemy-settlement service on a human's region is announced as a hit")
end

do
    -- AN OLD SAVE'S 18 COOLDOWNS LAND ON THE FIRST 18 ROWS (spec §11): saved by position,
    -- and the table only grows at the end.
    W.reset()
    local cds = {}
    for i = 1, 18 do cds[i] = tostring(i) end
    cm:set_saved_value("derpy_gg_me", string.rep("0,0|", 5) .. "0,0;" .. table.concat(cds, "|"))
    GG.load("me")
    assert(GG.cooldown_left("me", "caravan_levy") == 1
           and GG.cooldown_left("me", "great_coffle") == 18,
           "an 18-field save's cooldowns must stay on their services")
    assert(GG.cooldown_left("me", GG.SERVICES[19].key) == 0, "a new row starts ready")
    ok("an old save's cooldowns stay on their own services")
end

do
    -- A FACTION NO HUMAN SHARES A RACE WITH HOLDS NO CARDS: the rivals' round walks the
    -- whole world, and each card set is a saved value.
    W.reset()
    W.faction("orcs", {culture = "wh_main_grn_greenskins", regions = {}, lords = {}, heroes = {}})
    assert(not GG.covered("orcs"), "setup: an uncovered faction")
    assert(GG.rotate_cards("orcs", 10) == false, "an uncovered faction must not draw")
    assert(GG.cards.orcs == nil and cm:get_saved_value(GG.cards_key("orcs")) == nil,
           "an uncovered faction must save no cards")
    ok("only covered factions draw cards")
end

do
    -- THE RIVALS PICK WHAT THE TILL ACCEPTS, for every new kind: a picker aimed at the
    -- wrong kind of target is refused every time, so rivals never buy the service.
    worldA()
    for _, key in ipairs({"forced_march", "granaries", "sow_discord", "warlords_honour"}) do
        local s = GG.service(key)
        local t = GGAI.pick_target("me", s)
        assert(t ~= nil and GG.target_ok("me", s, t), key .. " (" .. s.kind
               .. "): the rivals' pick " .. tostring(t) .. " is one the till refuses")
    end
    ok("the rivals' pickers answer each new kind with a target the till accepts")
end

-- ------------------------------------------------------------ RACES: the twists --
-- A player of `culture`: the world reset, the human "me" of that race.
local function race(culture)
    W.reset()
    F.me.culture = culture
end

do
    -- EACH RACE'S RULE, read through GG.setting_for (spec §7), on the default settings:
    -- demand_every 12, demand_reward 120, demand_penalty 60, rate_bounty_fail 100,
    -- rate_rivalry 40, rate_decay 100.
    local want = {
        ["wh3_dlc23_chd_chaos_dwarfs"] = {demand_every = 8, demand_reward = 180},
        ["wh_main_dwf_dwarfs"]         = {rate_bounty_fail = 150, demand_penalty = 120},
        ["wh_main_emp_empire"]         = {rate_rivalry = 60},
        ["wh3_main_ksl_kislev"]        = {rate_decay = 50},
        ["wh_main_brt_bretonnia"]      = {demand_reward = 180, demand_penalty = 120},
        ["wh3_main_cth_cathay"]        = {rate_rivalry = 20},
        ["wh2_main_def_dark_elves"]    = {rate_rivalry = 60},
        ["wh2_main_hef_high_elves"]    = {},
    }
    for culture, bent in pairs(want) do
        race(culture)
        for _, key in ipairs({"demand_every", "demand_reward", "demand_penalty",
                              "rate_bounty_fail", "rate_rivalry", "rate_decay"}) do
            local expect = bent[key] or GG.TUNE_DEFAULTS[key]
            local got = GG.setting_for("me", key)
            assert(got == expect, culture .. " " .. key .. " reads " .. tostring(got)
                   .. ", want " .. expect)
        end
    end
    ok("each race bends its own rule and no other")
end

do
    -- 0 STAYS 0, A RULE ON NEVER ROUNDS TO OFF, AND OFF IS THE PLAIN RULE.
    race("wh3_main_cth_cathay")
    GG.TUNE.rate_rivalry = 0
    assert(GG.setting_for("me", "rate_rivalry") == 0, "a rivalry switched off stays off")
    GG.TUNE.rate_rivalry = 1
    assert(GG.setting_for("me", "rate_rivalry") == 1, "half of 1 is still on, not 0")
    GG.TUNE.rate_rivalry = 40
    assert(GG.setting_for(nil, "rate_rivalry") == 40, "no faction: the plain rule")
    GG.TUNE.race_differences = false
    assert(GG.setting_for("me", "rate_rivalry") == 40, "race differences off: the plain rule")
    ok("a twist keeps 0 at 0, never rounds a rule off, and stops with race differences")
end

do
    -- WHERE THE TWISTS BITE: rivalry, upkeep, a failed bounty, a paid demand, the favour
    -- cap and a hostile service's price, each read for the faction it applies to.
    race("wh3_main_cth_cathay")
    assert(GG.rival_loss(100, "me") == 20, "Cathay's rival takes half: "
           .. GG.rival_loss(100, "me"))
    assert(GG.rival_loss(100) == 40, "a loss with no faction is the plain rule")
    race("wh3_main_ksl_kislev")
    assert(GG.decay_amount(4, "me") == 2, "Kislev's upkeep at rank 4 is halved")
    race("wh_main_dwf_dwarfs")
    assert(GG.bounty_fail_cost({rep = 80}, "me") == 120, "a Dwarf's failed bounty is 150%")
    race("wh3_dlc23_chd_chaos_dwarfs")
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 100, fav = 0} end
    GG.demands.me = {guild = "brass", kind = "tribute", amount = 1, due = 99}
    F.me.treasury = 99999
    assert(GG.pay_demand("me"), "the demand is paid")
    assert(GG.get("me", "brass") == 280, "Hashut's tithe: a paid demand is 180, got "
           .. GG.get("me", "brass"))
    -- ...and they come every 8 turns, not 12: the clock reads the race.
    GG.demands.me, GG.demand_last.me = nil, 12
    assert(GG.demand_tick("me", 20) == "new", "Hashut's tithe: a demand after 8 turns")
    -- A Dwarf's expired demand costs 200%: the penalty reads the race too.
    race("wh_main_dwf_dwarfs")
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 500, fav = 0} end
    GG.demands.me = {guild = "brass", kind = "tribute", amount = 1, due = 5}
    assert(GG.demand_tick("me", 6) == "expired", "the demand expired")
    assert(GG.get("me", "brass") == 380, "a Dwarf's expired demand costs 120, got "
           .. GG.get("me", "brass"))
    GG.demands.me, GG.demand_last.me = nil, nil
    race("wh2_main_hef_high_elves")
    GG.state.me = {}
    -- Just under the cap: a gain stops at it (and never takes favour already above it).
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 100, fav = 290} end
    GG.grant("me", "brass", 50, "other")
    assert(select(2, GG.get("me", "brass")) == 300, "High Elves hold 3x the rank's "
           .. "threshold in favour, got " .. select(2, GG.get("me", "brass")))
    race("wh2_main_def_dark_elves")
    local price, mod = GG.service_cost("me", "sow_discord")
    assert(price == 112 and mod == -26, "a Dark Elf's hostile service costs 75%, got "
           .. price .. " at " .. mod .. "%")
    ok("the twists bite where each rule is applied")
end

-- ------------------------------------------------------- RACES: the catalogue --
-- Two fixture rows, appended and removed around each test: a Dwarf pool grant and a
-- Dwarf army service. Neither ships.
local function with_race_rows(fn)
    local n = #GG.SERVICES
    GG.SERVICES[n + 1] = {key = "t_dwf_pool", guild = "overseers", rank = 2, cost = 50, cd = 8,
                          kind = "resource", resource = "t_res", factor = "t_factor",
                          value = 7, race = "wh_main_dwf_dwarfs"}
    GG.SERVICES[n + 2] = {key = "t_dwf_army", guild = "immortals", rank = 3, cost = 150,
                          cd = 12, kind = "race_army", race = "wh_main_dwf_dwarfs"}
    local okf, err = pcall(fn)
    GG.SERVICES[n + 2], GG.SERVICES[n + 1] = nil, nil
    GG.RACE_FIRE.t_dwf_army, GG.RACE_TARGET_OK.t_dwf_army = nil, nil
    GG.RACE_NEEDS.t_dwf_pool = nil
    if not okf then error(err, 0) end
end

local function in_pool(key, guild, rank)
    for _, s in ipairs(GG.pool("me", guild, rank)) do
        if s.key == key then return true end
    end
    return false
end

local function in_pool_of(faction, key, guild, rank)
    for _, s in ipairs(GG.pool(faction, guild, rank)) do
        if s.key == key then return true end
    end
    return false
end

-- A service on me's card with every rank, ample favour and no cooldown, so only what the
-- test is about can refuse it.
local function stock(key)
    local s = GG.service(key)
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 99999, fav = 99999} end
    GG.cooldowns.me = {}
    GG.TUNE.lead_monopoly = false
    GG.cards.me = {turn = 1, keys = GG.cards_of("me")}
    for gi, g in ipairs(GG.GUILDS) do
        if g == s.guild then
            GG.cards.me.keys[(gi - 1) * #GG.CARD_RANKS + s.rank - 1] = key
        end
    end
    return s
end

do
    -- A RACE'S ROW IS IN ITS OWN RACE'S POOL and nobody else's (spec §3).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        assert(in_pool("t_dwf_pool", "overseers", 2), "a Dwarf draws the Dwarf row")
        race("wh_main_emp_empire")
        F.me.resources = {t_res = 0}
        assert(not in_pool("t_dwf_pool", "overseers", 2), "the Empire never draws it")
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        GG.TUNE.race_differences = false
        assert(not in_pool("t_dwf_pool", "overseers", 2), "race differences off: never")
    end)
    ok("a race service is drawn for its own race, and only with race differences on")
end

do
    -- A POOL GRANT NEEDS THE POOL. Without it the row is never drawn, and the till refuses
    -- it: a pool lost after the draw is the same case (Review Focus 1).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        assert(not in_pool("t_dwf_pool", "overseers", 2), "no pool, no draw")
        stock("t_dwf_pool")
        local okb, why = GG.can_buy("me", "t_dwf_pool")
        assert(not okb and why == "unavailable", "no pool, no sale: got " .. tostring(why))
        F.me.resources = {t_res = 0}
        assert(GG.can_buy("me", "t_dwf_pool"), "with the pool it sells")
        GG.RACE_NEEDS.t_dwf_pool = function() return false end
        local okn, whyn = GG.can_buy("me", "t_dwf_pool")
        assert(not okn and whyn == "unavailable", "a failed needs refuses at the till too")
    end)
    ok("a service whose hook is gone is neither drawn nor sold")
end

do
    -- THE PAYLOADS: a pool grant by faction KEY, recorded before it is made; a race call
    -- handed the faction, the row and the target.
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        GG.POOL_ROUTES.t_res = "grudges"                  -- a route that counts every factor
        GG.payload("me", GG.service("t_dwf_pool"), nil)
        GG.POOL_ROUTES.t_res = nil
        local c = CALLS.pooled and CALLS.pooled[1]
        assert(c and c[1] == "me" and c[2] == "t_res" and c[3] == "t_factor" and c[4] == 7,
               "a pool grant takes the faction key, the pool, the factor and the value")
        assert(GG.take_self("me", "t_res", 7) == 0, "and was recorded as the buyer's own")
        local got
        GG.RACE_FIRE.t_dwf_army = function(f, s, t) got = {f, s.key, t} end
        GG.payload("me", GG.service("t_dwf_army"), 10)
        assert(got and got[1] == "me" and got[2] == "t_dwf_army" and got[3] == 10,
               "a race call gets the faction, the row and the target")
    end)
    ok("a pool grant and a race call reach the game as documented")
end

do
    -- A RACE CALL THAT IS MISSING OR THROWS IS REFUNDED, never charged for nothing.
    with_race_rows(function()
        worldA()
        F.me.culture = "wh_main_dwf_dwarfs"
        stock("t_dwf_army")
        local fav0 = select(2, GG.get("me", "immortals"))
        local okb, why = GG.buy("me", "t_dwf_army", 10)
        assert(not okb and why == "failed", "no race call: refused, got " .. tostring(why))
        assert(select(2, GG.get("me", "immortals")) == fav0, "and the favour is back")
        GG.RACE_FIRE.t_dwf_army = function() rec("fired") end
        assert(GG.buy("me", "t_dwf_army", 10), "with its call it sells")
        assert(CALLS.fired, "and the call ran")
    end)
    ok("a race call that is missing is refunded")
end

do
    -- A RACE ARMY SERVICE is aimed at the buyer's own army. It may ask for room and may ask
    -- more of the army. The wire, the panel's pick and the rivals' pick all treat it as one.
    with_race_rows(function()
        worldA()
        F.me.culture = "wh_main_dwf_dwarfs"
        local s = GG.service("t_dwf_army")
        assert(GG.needs_target(s), "it needs a target")
        assert(GG.target_ok("me", s, 10), "my lord's army is a target")
        assert(not GG.target_ok("me", s, 30), "an enemy's is not")
        s.room = true
        C["10"].units = 20
        assert(not GG.target_ok("me", s, 10), "room asked: a full army is refused")
        C["10"].units = 19
        assert(GG.target_ok("me", s, 10), "and one with room taken")
        s.room = nil
        GG.RACE_TARGET_OK.t_dwf_army = function(_, c) return c:command_queue_index() ~= 10 end
        assert(not GG.target_ok("me", s, 10), "the race's own check on the army is honoured")
        GG.RACE_TARGET_OK.t_dwf_army = nil
        assert(GG.target_from_wire("me", s, "10") == 10, "the wire carries it as a cqi")
        local t = GGAI.pick_target("me", s)
        assert(t ~= nil and GG.target_ok("me", s, t), "the rivals pick an army the till takes")
    end)
    ok("a race army service is judged like an army, room and its own check included")
end

do
    -- A PURCHASE NEVER PAYS ITS OWN EARNING, and a record never outlives its turn (spec §7).
    W.reset()
    TURN = 5
    GG.note_self("me", "t_res", 200)
    assert(GG.take_self("me", "t_res", 200) == 0, "the purchase's own change pays nothing")
    assert(GG.take_self("me", "t_res", 30) == 30, "and the record is spent once")
    GG.note_self("me", "t_res", 200)
    TURN = 6
    assert(GG.take_self("me", "t_res", 30) == 30, "last turn's record eats nothing")
    ok("a recorded purchase is subtracted once, and only in its own turn")
end

-- ------------------------------------------------------- RACES: rule 2 of the draw --
local function race_on_show()
    local n = 0
    for _, k in ipairs(GG.cards_of("me")) do
        if GG.service(k).race then n = n + 1 end
    end
    return n
end

do
    -- EVERY ROLL OF 1 lands each card on its first pool row, which is shared - so rule 2
    -- must put one race service on show. With race differences off, none (spec §4).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        GG.draw_cards("me", 10, true)
        assert(race_on_show() == 1, "one race service on show, got " .. race_on_show())
        GG.TUNE.race_differences = false
        GG.draw_cards("me", 20, false)
        assert(race_on_show() == 0, "race differences off drew one")
    end)
    ok("a draw always shows a race service, and none with race differences off")
end

do
    -- THE CARD IS ROLLED among those whose pool holds one: roll 19 picks the second of
    -- two candidates, the overseers' rank-2 card (slot 13), not immortals rank 3 (slot 5).
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        local calls = 0
        RANDOM = function(n)
            calls = calls + 1
            if calls == 19 then return n end
            return 1
        end
        GG.draw_cards("me", 10, true)
        local keys = GG.cards_of("me")
        assert(keys[13] == "t_dwf_pool", "slot 13 was rolled, got " .. tostring(keys[13]))
        assert(keys[5] ~= "t_dwf_army", "and only that card changed")
        assert(calls == 19, "18 card rolls and one for the card, got " .. calls)
    end)
    ok("the card rule 2 changes is rolled among those that can hold a race service")
end

do
    -- A DRAW THAT ALREADY SHOWS ONE ROLLS NO MORE: every roll lands on the last row,
    -- which for these two cards is the race row.
    with_race_rows(function()
        race("wh_main_dwf_dwarfs")
        F.me.resources = {t_res = 0}
        local calls = 0
        RANDOM = function(n) calls = calls + 1 return n end
        GG.draw_cards("me", 10, true)
        assert(race_on_show() == 2, "both race rows drawn by the rolls themselves")
        assert(calls == 18, "and no extra roll, got " .. calls)
    end)
    ok("rule 2 does nothing when the draw already shows a race service")
end

-- ------------------------------------------------ RACES: Chaos Dwarfs and Dwarfs --
local CHD, DWF = "wh3_dlc23_chd_chaos_dwarfs", "wh_main_dwf_dwarfs"

do
    -- CONCLAVE FAVOUR, HIGH KING'S DECREE AND STRIKE LINES are pool grants on the pool CA
    -- itself grants through.
    race(CHD)
    F.me.resources = {wh3_dlc23_chd_conclave_influence = 0}
    stock("conclave_favour")
    assert(GG.buy("me", "conclave_favour"), "Conclave Favour sells")
    local c = CALLS.pooled[1]
    assert(c[2] == "wh3_dlc23_chd_conclave_influence"
           and c[3] == "wh3_dlc23_chd_conclave_influence_gained_events" and c[4] == 40,
           "Conclave Favour: 40 influence through the events factor")
    race(DWF)
    F.me.resources = {dwf_underdeeps = 0, wh3_dlc25_dwf_grudge_points = 0}
    stock("high_kings_decree")
    assert(GG.buy("me", "high_kings_decree"), "the Decree sells")
    stock("strike_lines")
    assert(GG.buy("me", "strike_lines"), "Strike Lines sells")
    assert(CALLS.pooled[1][2] == "dwf_underdeeps" and CALLS.pooled[1][4] == 1,
           "one High King Decree")
    assert(CALLS.pooled[2][2] == "wh3_dlc25_dwf_grudge_points"
           and CALLS.pooled[2][3] == "settled" and CALLS.pooled[2][4] == 200,
           "200 grudge points through settled")
    assert(GG.take_self("me", "wh3_dlc25_dwf_grudge_points", 200) == 0,
           "and the grudge points are recorded as the buyer's own")
    ok("the Chaos Dwarf and Dwarf pool grants reach CA's pools")
end

do
    -- HELL-FORGE ALLOTMENT: CA's own +1, never a ritual; the Tower's message, the
    -- blunderbusses' by its real key; nothing without CA's global.
    race(CHD)
    assert(not in_pool("hellforge_allotment", "daemonsmiths", 3), "no hellforge, no draw")
    local seen = {}
    hellforge = {unit_cap_modifiers_bundle_string = "wh3_dlc23_bundle_chd_unit_cap_rituals",
                 modify_unit_cap = function(_, rk, f, b) seen[#seen + 1] = {rk, f:name(), b} end}
    assert(in_pool("hellforge_allotment", "daemonsmiths", 3), "with it, drawn")
    RANDOM = function(n) return n end        -- the last cap: the blunderbusses
    stock("hellforge_allotment")
    assert(GG.buy("me", "hellforge_allotment"), "it sells")
    hellforge = nil
    assert(seen[1] and seen[1][1] == "wh3_dlc23_chd_ritual_unit_cap_chaos_dwarf_blunderbusses"
           and seen[1][2] == "me" and seen[1][3] == "wh3_dlc23_bundle_chd_unit_cap_rituals",
           "modify_unit_cap(ritual, faction interface, CA's cap bundle)")
    assert(CALLS.incident[1][2]
           == "wh3_dlc23_chd_toz_cap_wh3_dlc23_chd_ritual_unit_cap_dwarf_blunderbusses",
           "the blunderbusses' message by its real key")
    -- No ritual check here: cm has no perform_ritual stub, so a call to it would throw
    -- and the buy above would have been refunded.
    ok("Hell-Forge Allotment raises one cap through CA's own call")
end

do
    -- LABOUR GANGS: every province's own labour, skipping one without the pool.
    race(CHD)
    F.me.provinces = {{key = "p1", labour = true}, {key = "p2"}, {key = "p3", labour = true}}
    stock("labour_gangs")
    assert(GG.buy("me", "labour_gangs"), "Labour Gangs sells")
    assert(#CALLS.transaction == 2, "two provinces hold labour, got " .. #CALLS.transaction)
    for _, c in ipairs(CALLS.transaction) do
        assert(c[3] == "other" and c[4] == 200, "200 labour through other")
    end
    ok("Labour Gangs adds labour to every province that holds it")
end

do
    -- CALL THE RECKONING: only at the top level, for a human in a running cycle, and
    -- refused at the till once the cycle has dropped (Review Focus 1); never on a rival's
    -- card (Review Focus 5).
    race(DWF)
    local level = 5
    grudge_cycle = {faction_times = {me = 9},
                    get_current_grudge_level = function(_, fk) return level end}
    assert(in_pool("call_reckoning", "immortals", 4), "at the top level it is drawn")
    stock("call_reckoning")
    level = 3
    local okl, why = GG.can_buy("me", "call_reckoning")
    assert(not okl and why == "unavailable", "below the top level the till refuses: "
           .. tostring(why))
    level = 5
    BONUS = {["me|dwf_grudge_feature_off"] = 1}
    assert(select(2, GG.can_buy("me", "call_reckoning")) == "unavailable",
           "not with the grudge feature off")
    BONUS = nil
    assert(GG.buy("me", "call_reckoning"), "it sells")
    assert(grudge_cycle.faction_times.me == 0, "the cycle resolves at the next turn start")
    W.faction("rival_dwf", {culture = DWF, regions = {}, lords = {}, heroes = {}})
    -- A RUNNING CYCLE FOR THE RIVAL TOO, so the human rule is the only thing refusing.
    grudge_cycle.faction_times.rival_dwf = 9
    assert(not in_pool_of("rival_dwf", "call_reckoning", "immortals", 4),
           "a rival never holds it")
    grudge_cycle = nil
    assert(not in_pool("call_reckoning", "immortals", 4), "no global, never drawn")
    ok("Call the Reckoning only at the top level, for a human, while it still is")
end

-- ------------------------------------------------------------- RACES: the Empire --
local EMP = "wh_main_emp_empire"

do
    -- THE WARRANT ON MY OWN SETTLEMENT; THE MUSTER'S TWO REGIMENTS, one per grant, on an
    -- army with room; UNITY ON THE FACTION.
    worldA()
    F.me.culture = EMP
    stock("witch_hunters_warrant")
    assert(not GG.buy("me", "witch_hunters_warrant", "foe_near"), "never an enemy's town")
    assert(GG.buy("me", "witch_hunters_warrant", "home"), "my own town")
    assert(CALLS.region_bundle[1][1] == "derpy_gg_svc_witch_hunters_warrant_emp"
           and CALLS.region_bundle[1][3] == 8, "the Warrant's bundle, 8 turns")
    stock("electors_muster")
    C["10"].units = 20
    assert(not GG.buy("me", "electors_muster", 10), "a full army is refused")
    C["10"].units = 18
    assert(GG.buy("me", "electors_muster", 10), "an army with room")
    assert(#CALLS.grant == 2 and CALLS.grant[1][1] == "character_cqi:10"
           and CALLS.grant[1][2] == "wh_main_emp_inf_swordsmen"
           and CALLS.grant[2][2] == "wh_main_emp_inf_handgunners",
           "Swordsmen then Handgunners, through a lookup string")
    stock("unity_of_empire")
    assert(GG.buy("me", "unity_of_empire"), "Unity sells")
    local u = CALLS.bundle[#CALLS.bundle]
    assert(u[1] == "derpy_gg_svc_unity_of_empire_emp" and u[2] == "me" and u[3] == 15,
           "Unity's bundle on the faction for 15 turns")
    ok("the Empire's three race services land where their cards say")
end

do
    -- ELECTOR'S FAVOUR: the least loyal Elector, through CA's own globals, for a faction
    -- with the politics feature - asked of the buyer, which is on the map.
    race(EMP)
    F.me.features = {politics = true}
    local loyal = {averland = 7, talabecland = 3, stirland = 3}
    local order = {"averland", "talabecland", "stirland"}
    empire_find_electors_with_loyalty = function(f, lo, hi)
        assert(f:name() == "me", "asked with the buyer's faction interface")
        local out = {}
        for _, e in ipairs(order) do
            if loyal[e] >= lo and loyal[e] <= hi then out[#out + 1] = {elector = e} end
        end
        return out
    end
    local moved
    empire_modify_elector_loyalty = function(e, factor, n) moved = {e, factor, n} end
    stock("electors_favour")
    assert(GG.buy("me", "electors_favour"), "it sells")
    assert(moved[1] == "talabecland" and moved[2] == "events" and moved[3] == 1,
           "+1 Fealty through events to the least loyal, first in CA's order")
    -- The buy set a cooldown, which would refuse everything below on its own.
    GG.cooldowns.me = {}
    local function why() return select(2, GG.can_buy("me", "electors_favour")) end
    loyal = {averland = 10, talabecland = 10, stirland = 10}
    assert(why() == "unavailable", "every Elector at 10: nothing to buy")
    F.me.features = {}
    loyal.averland = 2
    assert(why() == "unavailable", "no politics feature: not offered")
    F.me.features = {politics = true}
    assert(why() == nil, "and with it back, offered again")
    empire_find_electors_with_loyalty, empire_modify_elector_loyalty = nil, nil
    assert(why() == "unavailable", "no politics script: not offered")
    ok("Elector's Favour raises the least loyal Elector, where politics runs")
end

do
    -- THE LORDS' POOLS, each only on the faction that holds it.
    race(EMP)
    F.me.resources = {wh3_dlc29_emp_fervour = 0}
    assert(in_pool("fervour", "immortals", 3), "Todbringer's faction draws Fervour")
    assert(not in_pool("gunnery_schematics", "daemonsmiths", 3), "and not Elspeth's")
    stock("fervour")
    assert(GG.buy("me", "fervour"), "Fervour sells")
    local c = CALLS.pooled[1]
    assert(c[2] == "wh3_dlc29_emp_fervour" and c[3] == "missions" and c[4] == 300,
           "300 Fervour through missions")
    ok("each lord's service follows the pool, not a faction name")
end

do
    -- THE SUPPLY TRAIN: CA's dilemma at CA's strength, for a human Wulfhart only, never a
    -- rival. "me" is a human Empire player throughout, so the Empire stays covered and
    -- the AI case is refused by the human check, not by the culture gate.
    local W_ = "wh2_dlc13_emp_the_huntmarshals_expedition"
    race(EMP)
    W.faction(W_, {culture = EMP, resources = {emp_progress = 45},
                   regions = {}, lords = {}, heroes = {}})
    assert(not in_pool_of(W_, "supply_train", "brass", 3), "an AI Wulfhart never draws it")
    F[W_].human = true
    GG.humans = nil
    cm.get_human_factions = function() return {"me", W_} end
    assert(in_pool_of(W_, "supply_train", "brass", 3), "a human Wulfhart draws it")
    assert(not in_pool("supply_train", "brass", 3), "and no other Empire faction does")
    GG.state[W_] = {}
    for _, g in ipairs(GG.GUILDS) do GG.state[W_][g] = {rep = 99999, fav = 99999} end
    GG.cards[W_] = {turn = 1, keys = GG.cards_of(W_)}
    GG.cards[W_].keys[2] = "supply_train"                      -- brass, rank 3
    assert(GG.buy(W_, "supply_train"), "it sells")
    cm.get_human_factions = function() return {"me"} end
    GG.humans = nil
    assert(CALLS.dilemma[1][1] == W_
           and CALLS.dilemma[1][2] == "wh2_dlc13_wulfhart_imperial_guards_st_2",
           "Acclaim 45 is CA's middle strength")
    -- REFUSED, REFUNDED (final review): cm:trigger_dilemma answers false when the director
    -- declines, and a multiplayer game triggers it directly, so a refusal must not keep
    -- the favour.
    cm.get_human_factions = function() return {"me", W_} end
    GG.humans = nil
    GG.cooldowns[W_] = {}
    local fav = select(2, GG.get(W_, "brass"))
    DILEMMA_REFUSED = true
    local sold, why = GG.buy(W_, "supply_train")
    DILEMMA_REFUSED = nil
    cm.get_human_factions = function() return {"me"} end
    GG.humans = nil
    assert(not sold and why == "failed", "a refused dilemma fails the sale, got " .. tostring(why))
    assert(select(2, GG.get(W_, "brass")) == fav, "and the favour is returned")
    ok("the Supply Train raises CA's dilemma for a human Wulfhart only")
end

-- ------------------------------------------------------ RACES: Kislev and Bretonnia --
local KSL, BRT = "wh3_main_ksl_kislev", "wh_main_brt_bretonnia"

do
    -- PRAYERS, THE LOWER COURT, AND THE BLESSING OF THE MOTHERLAND.
    race(KSL)
    F.me.resources = {wh3_main_ksl_devotion = 0, wh3_main_ksl_support_level_orthodoxy = 2,
                      wh3_main_ksl_support_level_ice_court = 1}
    stock("prayers_motherland")
    assert(GG.buy("me", "prayers_motherland"), "Prayers sells")
    stock("court_favour")
    assert(GG.buy("me", "court_favour"), "Court Favour sells")
    stock("blessing_motherland")
    assert(GG.buy("me", "blessing_motherland"), "the Blessing sells")
    local p = CALLS.pooled
    assert(p[1][2] == "wh3_main_ksl_devotion" and p[1][3] == "events" and p[1][4] == 75,
           "Prayers: 75 Devotion through events")
    assert(p[2][2] == "wh3_main_ksl_support_tracker_ice_court" and p[2][3] == "faction"
           and p[2][4] == 30, "the Ice Court is behind, so it gets the 30")
    assert(p[3][4] == 100 and p[4][4] == 20 and p[5][4] == 20
           and p[4][2] ~= p[5][2], "the Blessing: 100 Devotion and 20 to each court")
    F.me.resources.wh3_main_ksl_support_level_ice_court = 2
    assert(GG.lower_court("me") == "ice_court", "a tie goes to the Ice Court")
    F.me.resources.wh3_main_ksl_support_level_ice_court = 3
    assert(GG.lower_court("me") == "orthodoxy", "the Orthodoxy when it is behind")
    F.me.resources.wh3_main_ksl_devotion = nil
    assert(not in_pool("prayers_motherland", "daemonsmiths", 2)
           and not in_pool("blessing_motherland", "immortals", 4),
           "no Devotion, neither drawn")
    ok("Kislev's services reach Devotion and the court that is behind")
end

do
    -- THE LADY'S BLESSING on my army by CA's own call, refused on one already blessed;
    -- TALES OF VALOUR through CA's chivalry, or the plain grant without it.
    worldA()
    F.me.culture = BRT
    F.me.resources = {brt_chivalry = 0}
    local blessed, done = {}, {}
    Has_Blessing_Already = function(fcqi) return blessed[fcqi] == true end
    Blessing_Character_Won = function(c) done[#done + 1] = c:command_queue_index() end
    stock("ladys_blessing")
    blessed[1010] = true
    assert(not GG.buy("me", "ladys_blessing", 10), "an army already blessed is refused")
    blessed[1010] = nil
    C["10"].force_bundles = {wh_dlc07_blessing_of_the_lady = true}
    assert(not GG.buy("me", "ladys_blessing", 10), "and one carrying the bundle")
    C["10"].force_bundles = nil
    assert(GG.buy("me", "ladys_blessing", 10), "an army without it is blessed")
    assert(done[1] == 10, "through Blessing_Character_Won on its general")
    Has_Blessing_Already, Blessing_Character_Won = nil, nil
    assert(not in_pool("ladys_blessing", "immortals", 2), "no global, never drawn")
    local modified
    chivalry = {ModifyChivalry = function(self, f, factor, n) modified = {self, f, factor, n} end}
    stock("tales_of_valour")
    assert(GG.buy("me", "tales_of_valour"), "Tales sells")
    assert(modified[1] == chivalry and modified[2] == "me" and modified[3] == "missions"
           and modified[4] == 150, "chivalry:ModifyChivalry(me, missions, 150), with a colon")
    chivalry = nil
    stock("tales_of_valour")
    assert(GG.buy("me", "tales_of_valour"), "and without CA's chivalry")
    local c = CALLS.pooled[#CALLS.pooled]
    assert(c[2] == "brt_chivalry" and c[3] == "missions" and c[4] == 150,
           "the plain grant through missions")
    ok("Bretonnia's Blessing and Tales go through CA's own calls")
end

-- ------------------------------------------ RACES: Cathay, Dark Elves, High Elves --
local CTH, DEF, HEF = "wh3_main_cth_cathay", "wh2_main_def_dark_elves", "wh2_main_hef_high_elves"

do
    -- THE COMPASS BY FACTION INTERFACE, never for the Celestial Court; CARGO FOR EVERY
    -- CARAVAN STILL OUT, and not offered once they are all home (Review Focus 1).
    race(CTH)
    stock("realign_compass")
    assert(GG.buy("me", "realign_compass"), "the Compass sells")
    assert(CALLS.compass[1][1] == "me" and CALLS.compass[1][2] == 0, "cooldown 0 for me")
    W.faction("wh3_dlc24_cth_the_celestial_court", {culture = CTH, regions = {}, lords = {}})
    assert(not in_pool_of("wh3_dlc24_cth_the_celestial_court", "realign_compass",
                          "daemonsmiths", 2), "never for the Celestial Court")
    F.me.caravans = {{id = 1, cargo = 100}, {id = 2, cargo = 50, returning = true},
                     {id = 3, cargo = 0}}
    stock("ivory_cargo")
    assert(GG.buy("me", "ivory_cargo"), "Cargo sells")
    assert(#CALLS.cargo == 2 and CALLS.cargo[1][1] == 1 and CALLS.cargo[1][2] == 300
           and CALLS.cargo[2][1] == 3 and CALLS.cargo[2][2] == 200,
           "+200 on each caravan still on its way, none on the one coming home")
    F.me.caravans = {{id = 2, cargo = 50, returning = true}}
    GG.cooldowns.me = {}                         -- the buy's cooldown would refuse it anyway
    assert(select(2, GG.can_buy("me", "ivory_cargo")) == "unavailable",
           "all home: unavailable at the till")
    ok("Cathay's Compass and Cargo reach CA's own systems")
end

do
    -- SLAVES AS CA PAYS THEM; LOYALTY FOR A LORD WHO IS NOT THE LEADER.
    worldA()
    F.me.culture = DEF
    F.me.resources = {def_slaves = 100}
    stock("slave_coffles")
    assert(GG.buy("me", "slave_coffles"), "Coffles sells")
    local c = CALLS.pooled[1]
    assert(c[2] == "def_slaves" and c[3] == "missions" and c[4] == 500, "500 Slaves")
    stock("bought_loyalty")
    C["10"].leader = true
    assert(not GG.buy("me", "bought_loyalty", 10), "never the faction leader")
    C["10"].leader = nil
    assert(GG.buy("me", "bought_loyalty", 10), "another lord")
    assert(CALLS.loyalty[1][1] == "character_cqi:10" and CALLS.loyalty[1][2] == 3,
           "+3 through a lookup string")
    ok("the Dark Elves' Slaves and loyalty land as CA documents")
end

do
    -- INFLUENCE AND THE PHOENIX KING'S FAVOUR, the Grace carrying both.
    race(HEF)
    F.me.resources = {wh3_dlc27_hef_favour = 0}
    stock("whispers_at_court")
    assert(GG.buy("me", "whispers_at_court"), "Whispers sells")
    stock("asuryans_grace")
    assert(GG.buy("me", "asuryans_grace"), "the Grace sells")
    assert(CALLS.influence[1][1] == "me" and CALLS.influence[1][2] == 30, "30 Influence")
    local c = CALLS.pooled[#CALLS.pooled]
    assert(c[2] == "wh3_dlc27_hef_favour" and c[3] == "faction" and c[4] == 150,
           "150 Favour of the Phoenix King")
    assert(CALLS.influence[2][2] == 40, "and 40 Influence")
    ok("the High Elves' services reach Influence and the Phoenix King's favour")
end

-- ------------------------------------------------------- RACES: the Slave Tithe --
do
    -- KISLEV: Devotion through events where the faction holds it, gold where it does not.
    -- DARK ELVES: Slaves through missions (spec §6.2).
    race(KSL)
    F.me.resources = {wh3_main_ksl_devotion = 0}
    GG.payload("me", GG.service("slave_tithe"), nil)
    local c = CALLS.pooled and CALLS.pooled[1]
    assert(c and c[2] == "wh3_main_ksl_devotion" and c[3] == "events" and c[4] == 150,
           "Kislev's tithe is 150 Devotion")
    race(KSL)
    GG.payload("me", GG.service("slave_tithe"), nil)
    assert(CALLS.treasury and CALLS.treasury[1][2] == 3000 and not CALLS.pooled,
           "a Kislev faction without Devotion takes the gold")
    race(DEF)
    GG.payload("me", GG.service("slave_tithe"), nil)
    c = CALLS.pooled and CALLS.pooled[1]
    assert(c and c[2] == "def_slaves" and c[3] == "missions" and c[4] == 1000,
           "the Dark Elves' tithe is 1,000 Slaves")
    ok("the Slave Tithe pays Kislev in Devotion and the Dark Elves in Slaves")
end

-- ------------------------------------------------------- RACES: the earn routes --
-- A human of `culture` with standing saved, so a listener's GG.load finds it; no turn
-- limit on any guild unless a test sets one.
local function earner(culture)
    race(culture)
    GG.state.me = {}
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 0, fav = 0} end
    for _, g in ipairs(GG.GUILDS) do GG.TUNE["cap_" .. g] = 0 end
    GG.save("me")
end

local function prc(key, amount, factor)
    return {resource = function() return {key = function() return key end} end,
            has_faction = function() return true end,
            faction = function() return W.fi("me") end,
            amount = function() return amount end,
            factor = function()
                if not factor then return NULL() end
                return {is_null_interface = function() return false end,
                        key = function() return factor end}
            end}
end

local function rep(guild) return (GG.get("me", guild)) end

do
    -- A CARAVAN PAYS THE MERCHANTS for Chaos Dwarfs and Cathay alike, and writes one Log
    -- line of what the guild gained.
    for _, culture in ipairs({CHD, CTH}) do
        earner(culture)
        HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
        assert(rep("brass") == 60, culture .. ": a caravan pays 60, got " .. rep("brass"))
    end
    local e = GG.log_entries("me")[1]
    assert(e and e.kind == "earn" and e.guild == "brass" and e.a == "caravan" and e.b == "60",
           "one Log line: earn, brass, caravan, 60")
    earner(DWF)
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 0, "a Dwarf caravan pays nothing")
    ok("a completed caravan pays the Merchants for the two caravan races")
end

do
    -- THE TURN LIMIT BINDS, and the Log says what was actually paid - nothing when nothing.
    earner(CTH)
    GG.TUNE.cap_brass = 40
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 40, "the Merchants' limit of 40 binds")
    assert(GG.log_entries("me")[1].b == "40", "and the Log says 40")
    local function earns()
        local n = 0
        for _, e in ipairs(GG.log_entries("me")) do if e.kind == "earn" then n = n + 1 end end
        return n
    end
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 40 and earns() == 1,
           "a second caravan over the limit pays nothing and writes nothing")
    ok("an earning meets its guild's turn limit, and the Log reports what was paid")
end

do
    -- GRUDGES: every rise pays, but not the part a purchase granted (Review Focus 3).
    earner(DWF)
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 30, "settled"))
    assert(rep("immortals") == 6, "30 grudges settled pay 6 (one per 5)")
    GG.note_self("me", "wh3_dlc25_dwf_grudge_points", 200)
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 200, "settled"))
    assert(rep("immortals") == 6, "Strike Lines' own 200 pays nothing")
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", -50, "settled"))
    assert(rep("immortals") == 6, "a fall pays nothing")
    ok("settled grudges pay the Ironbreakers, never for the purchase itself")
end

do
    -- CHIVALRY one per 5, the remainder kept; never through missions. CAPTIVES one per 20,
    -- from raiding and battles only.
    earner(BRT)
    HANDLERS.gg_earn_pool(prc("brt_chivalry", 12, "battles"))
    HANDLERS.gg_earn_pool(prc("brt_chivalry", 8, "battles"))
    assert(rep("immortals") == 4, "12 then 8 chivalry is 4 Reputation, got " .. rep("immortals"))
    HANDLERS.gg_earn_pool(prc("brt_chivalry", 150, "missions"))
    assert(rep("immortals") == 4, "chivalry through missions pays nothing")
    earner(DEF)
    HANDLERS.gg_earn_pool(prc("def_slaves", 45, "raiding"))
    HANDLERS.gg_earn_pool(prc("def_slaves", 20, "battles"))
    HANDLERS.gg_earn_pool(prc("def_slaves", 500, "missions"))
    HANDLERS.gg_earn_pool(prc("def_slaves", 60, nil))
    assert(rep("slavers") == 3, "65 Slaves by raid and battle is 3, got " .. rep("slavers"))
    ok("Chivalry and captives pay per so many, from the right sources only")
end

do
    -- A PURCHASE THE ROUTE IGNORES LEAVES NO RECORD (final review): Slave Coffles grants
    -- through missions, which captives never count, so its record was never spent by its
    -- own change and ate the next raid instead.
    earner(DEF)
    F.me.resources = {def_slaves = 100}
    stock("slave_coffles")
    assert(GG.buy("me", "slave_coffles"), "Coffles sells")
    HANDLERS.gg_earn_pool(prc("def_slaves", 500, "missions"))
    for _, g in ipairs(GG.GUILDS) do GG.state.me[g] = {rep = 0, fav = 0} end
    for _, g in ipairs(GG.GUILDS) do GG.TUNE["cap_" .. g] = 0 end
    GG.save("me")
    HANDLERS.gg_earn_pool(prc("def_slaves", 400, "raiding"))
    assert(rep("slavers") == 20, "a raid after Coffles pays in full, got " .. rep("slavers"))
    ok("a purchase through a factor the route ignores never eats a real earning")
end

do
    -- LAND OF THE OLD EMPIRE TAKEN BACK, not handed over, traded or abandoned.
    earner(EMP)
    W.faction("vc", {culture = "wh_main_vmp_vampire_counts", regions = {}, lords = {}})
    W.faction("emp2", {culture = EMP, regions = {}, lords = {}})
    local function rfce(prev, why, in_lands)
        return {region = function()
                    return {owning_faction = function() return W.fi("me") end,
                            is_contained_in_region_group = function(_, g)
                                return in_lands and g == GG.IMPERIAL_LANDS[2] end}
                end,
                previous_faction = function() return prev and W.fi(prev) or NULL() end,
                reason = function() return why end}
    end
    HANDLERS.gg_earn_reclaimed(rfce("vc", "normal capture", true))
    assert(rep("immortals") == 50, "taken from the Vampire Counts: 50")
    HANDLERS.gg_earn_reclaimed(rfce("emp2", "normal capture", true))
    HANDLERS.gg_earn_reclaimed(rfce("vc", "diplomacy trade", true))
    HANDLERS.gg_earn_reclaimed(rfce("vc", "normal capture", false))
    assert(rep("immortals") == 50, "not from the Empire, not by trade, not outside the lands")
    HANDLERS.gg_earn_reclaimed(rfce(nil, "normal capture", true))
    assert(rep("immortals") == 100, "a ruin in the old lands counts")
    ok("the Empire earns for taking back its own lands, by conquest only")
end

do
    -- A MOTHERLAND RITUAL BEGUN; A COURT ACTION THAT SUCCEEDED.
    earner(KSL)
    HANDLERS.gg_earn_motherland({faction = function() return W.fi("me") end})
    assert(rep("daemonsmiths") == 40, "a Motherland ritual pays 40")
    earner(HEF)
    local function ritual(cat, won)
        return {ritual = function() return {ritual_category = function() return cat end} end,
                succeeded = function() return won end,
                performing_faction = function() return W.fi("me") end}
    end
    HANDLERS.gg_earn_court(ritual("HEF_COURT_ACTION_TAKE_PATRONAGE", true))
    assert(rep("khanate") == 40, "a court action pays 40")
    HANDLERS.gg_earn_court(ritual("HEF_COURT_ACTION_TRIBUTE", false))
    HANDLERS.gg_earn_court(ritual("TYRION_IMPERATIVE_HEIR", true))
    assert(rep("khanate") == 40, "not a failed one, not another category")
    ok("Kislev and the High Elves earn by their own rituals")
end

do
    -- RACE DIFFERENCES OFF: no earning at all (Review Focus 2).
    earner(CHD)
    GG.TUNE.race_differences = false
    HANDLERS.gg_earn_caravan({faction = function() return W.fi("me") end})
    assert(rep("brass") == 0, "race differences off: a caravan pays nothing")
    ok("no race earns with race differences off")
end


-- ------------------------------------------------------ LOGIC AUDIT (2026-09-29) --
-- A LOAD, as far as the harness can have one: every session table empty, every saved
-- value kept.
local function reload()
    GG.state, GG.cards, GG.cooldowns = {}, {}, {}
    GG.patrons, GG.patron_forces, GG.demands, GG.demand_last = {}, {}, {}, {}
    GG.researching, GG.bounties, GG.turn_gain, GG.earn_carry = {}, {}, {}, {}
    GG.leaders_now = {}
    GG.world = {turn = 0, bought = 0, demands = 0, patrons = 0,
                rep = {}, gain = {}, held = {}, moved = {}}
    GGAI.last_turn = 0
    GGAI.bought_this_turn = {}
end

local function standing(faction, rep, fav)
    GG.state[faction] = {}
    for _, g in ipairs(GG.GUILDS) do GG.state[faction][g] = {rep = rep, fav = fav} end
end

do
    -- C1, I2: THE FIRST TICK RESTORES EVERY RECORD, on every machine alike. The patron,
    -- the army wearing its bundle, the demand, the research subject and the world record
    -- came back only when one machine's panel opened - so a till reading them priced one
    -- multiplayer sale two ways, and a patron moved after a load left its bundle behind.
    W.reset()
    W.char(7, {faction = "me", general = true})
    F.me.lords = {7}
    standing("me", 500, 500)
    GG.save("me")
    assert(GG.set_patron("me", "brass", 7), "appointed")
    GG.save_patron("me")
    GG.demands.me = {guild = "khanate", kind = "tribute", amount = 100, due = 9}
    GG.save_demand("me")
    GG.set_research("me", "tech_x")
    GG.save_research("me")
    GG.world.turn = 5
    GG.save_world()
    reload()
    GG.load_all()
    assert(GG.patrons.me and GG.patrons.me.guild == "brass", "the patron is back")
    assert(GG.demands.me and GG.demands.me.amount == 100, "the demand is back")
    assert(GG.researching.me == "tech_x", "the research subject is back")
    assert(GG.world.turn == 5, "the world record is back, got " .. tostring(GG.world.turn))
    CALLS.force_unbundle = nil
    GG.clear_patron("me")
    assert(CALLS.force_unbundle and CALLS.force_unbundle[1][2] == 1007,
           "a patron dismissed after a load takes the bundle off the army that wears it")
    ok("the first tick restores the patron, its army, the demand, research and the world")
end

do
    -- I3: ONLY YOUR OWN LORD. The map's selection lands on anyone, and an enemy army
    -- was given the patron's bundle for good.
    W.reset()
    W.faction("foe", {regions = {}, lords = {8}, heroes = {}})
    W.char(8, {faction = "foe", general = true})
    local okp, why = GG.set_patron("me", "brass", 8)
    assert(not okp, "another faction's lord is refused")
    assert(not CALLS.force_bundle, "and their army gets nothing")
    ok("a patron is always one of the faction's own lords")
end

do
    -- I1: A NEW CAMPAIGN DRAWS AT ITS FIRST TICK. No FactionTurnStart fires on turn 1, so
    -- the first draw landed on turn 2 and took the branch for a save that never drew:
    -- the original cards, for the whole first period, with no race service.
    W.reset()
    NEW_GAME = true
    GG.first_cards()
    NEW_GAME = nil
    assert(GG.cards.me and GG.cards.me.turn == 1, "the player's cards are drawn on turn 1")
    assert(GG.rotate_cards("me", 2) == false, "and not drawn again on turn 2")
    assert(GG.cards.me.turn == 1, "nor reset to the defaults")
    ok("a new campaign draws its first cards at the first tick")
end

do
    -- I5: A HELD LEAD SURVIVES A LOAD. GG.leaders_now is session memory, so after a load
    -- the margin had no holder to protect and a rival one point ahead took the guild,
    -- silently. The holder is whoever wears the lead bundle - the game kept that.
    W.reset()
    TURN = 40
    W.faction("rival", {regions = {}, lords = {}, heroes = {}})
    GG.CULTURE_OF.me, GG.CULTURE_OF.rival = GG.CHD_CULTURE, GG.CHD_CULTURE
    standing("me", 300, 0)
    standing("rival", 300, 0)
    GG.state.rival.brass.rep = 301
    F.me.bundles = {[GG.lead_key("brass", GG.CHD_CULTURE)] = true}
    GG.leaders_now = {}
    assert(GG.leader_of("brass", GG.CHD_CULTURE) == "me",
           "the wearer keeps a guild a rival leads by one, got "
           .. tostring(GG.leader_of("brass", GG.CHD_CULTURE)))
    ok("a guild held within the margin is still held after a load")
end

do
    -- I6: EARNING NEVER COSTS FAVOUR. The cap was applied only when reputation rose, so a
    -- demotion left favour above the new cap and the next point earned cut it down.
    W.reset()
    standing("me", 0, 0)
    GG.state.me.brass = {rep = 800, fav = 1300}
    GG.penalise("me", "brass", 104)
    GG.grant("me", "brass", 1, "battles")
    assert(GG.state.me.brass.fav == 1300,
           "one point earned after a demotion keeps 1300 favour, got " .. GG.state.me.brass.fav)
    ok("earning reputation never lowers favour")
end

do
    -- I7: ONE RIVALS' ROUND PER ROUND, across a load. The guard was session memory, so a
    -- save made in a swept round was swept again: a second purchase for every rival.
    W.reset()
    local runs, real = 0, GGAI.run_turn
    GGAI.run_turn = function() runs = runs + 1 end
    TURN = 30
    HANDLERS.gg_ai_turn()
    reload()
    HANDLERS.gg_ai_turn()
    GGAI.run_turn = real
    assert(runs == 1, "a load mid-round does not sweep the round again, ran " .. runs)
    ok("the rivals' round runs once per round across a load")
end


do
    -- C1: A POST SAVED BEFORE THE ARMY WAS: "guild,cqi" and no third field. The lord's own
    -- army is the one the bundle went on.
    W.reset()
    W.char(7, {faction = "me", general = true})
    F.me.lords = {7}
    cm:set_saved_value("derpy_gg_patron_me", "brass,7")
    GG.patrons, GG.patron_forces = {}, {}
    GG.load_patron("me")
    assert(GG.patrons.me and GG.patrons.me.guild == "brass", "an older post still loads")
    assert(GG.patron_forces.me == 1007, "with its lord's army, got " .. tostring(GG.patron_forces.me))
    ok("a patron saved by an older build finds the army wearing its bundle")
end


do
    -- m1: A SAVE AND RELOAD DOES NOT REFILL A TURN'S LIMITS. The per-turn totals were
    -- session memory, so a player at the Immortals' 60 reloaded and earned 60 more.
    W.reset()
    standing("me", 0, 0)
    GG.TUNE.cap_immortals = 60
    for _ = 1, 6 do GG.capped_grant("me", "immortals", 10, "battles") end
    reload()
    standing("me", 60, 0)
    GG.capped_grant("me", "immortals", 10, "battles")
    assert(GG.state.me.immortals.rep == 60,
           "the limit reached before the load still binds, got " .. GG.state.me.immortals.rep)
    GG.reset_turn("me")
    GG.capped_grant("me", "immortals", 10, "battles")
    assert(GG.state.me.immortals.rep == 70, "and the next turn start frees it")
    ok("a turn's earning limits survive a save and reload")
end

do
    -- m2: A ROUTE'S REMAINDER SURVIVES A LOAD: 19 Slaves, a load, 19 more is one point.
    earner(DEF)
    HANDLERS.gg_earn_pool(prc("def_slaves", 19, "raiding"))
    GG.earn_carry = {}
    HANDLERS.gg_earn_pool(prc("def_slaves", 19, "raiding"))
    assert(rep("slavers") == 1, "38 Slaves across a load is 1 Reputation, got " .. rep("slavers"))
    ok("a points route keeps its remainder across a load")
end

do
    -- m5: ONE BATTLE, ONE AWARD PER FACTION. CharacterCompletedBattle is raised for every
    -- character in the battle, so a lord with two heroes won three times.
    W.reset()
    standing("me", 0, 0)
    GG.save("me")
    GG.TUNE.cap_immortals = 0
    local function side(cqi)
        return {is_null_interface = function() return false end,
                command_queue_index = function() return cqi end}
    end
    local function ctx(cqi, defender)
        local ch = {is_null_interface = function() return false end,
                    won_battle = function() return true end,
                    faction = function() return W.fi("me") end,
                    command_queue_index = function() return cqi end}
        local pb = {is_null_interface = function() return false end,
                    has_attacker = function() return true end,
                    attacker = function() return side(1) end,
                    defender = function() return side(defender) end,
                    secondary_attackers = function() return LIST({}) end,
                    attacker_is_stronger = function() return true end}
        return {character = function() return ch end, pending_battle = function() return pb end}
    end
    HANDLERS.gg_battle(ctx(1, 99))
    local one = GG.state.me.immortals.rep
    assert(one > 0, "a won battle pays")
    HANDLERS.gg_battle(ctx(2, 99))
    HANDLERS.gg_battle(ctx(3, 99))
    assert(GG.state.me.immortals.rep == one, "its heroes do not pay it again, got "
           .. GG.state.me.immortals.rep .. " for " .. one)
    HANDLERS.gg_battle(ctx(1, 98))
    assert(GG.state.me.immortals.rep == 2 * one, "the next battle pays")
    ok("a battle pays each winning faction once")
end

do
    -- m6: GRUDGES PAY BY THE POINT. CA splits one battle's grudges into one change per
    -- winning army, so a flat sum per change paid a two-army win twice.
    earner(DWF)
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 30, "settled"))
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 30, "settled"))
    local two = rep("immortals")
    earner(DWF)
    HANDLERS.gg_earn_pool(prc("wh3_dlc25_dwf_grudge_points", 60, "settled"))
    assert(rep("immortals") == two and two > 0,
           "60 grudges pay alike in one change or two, got " .. rep("immortals") .. " and " .. two)
    ok("settled grudges pay by the point, however many armies share the win")
end

do
    -- m7: A LEAD NOBODY TOOK. The player's last reputation drained away and the guild is
    -- led by no one: no "a rival out-earned you" popup, and a Log line that names nobody.
    W.reset()
    GG.announce_lead("brass", false, "me")
    assert(not CALLS.message, "no popup when no rival took it")
    local e = GG.log_entries("me")[1]
    assert(e and e.kind == "lead_lost" and e.a == "", "the Log records it, naming no one")
    ok("a lead that lapses to nobody is not announced as a rival's")
end

do
    -- m17: THE RECKONING IS NOT SOLD ON THE CYCLE'S LAST TURN, when it resolves anyway.
    W.reset()
    F.me.culture = DWF
    grudge_cycle = {faction_times = {me = 1},
                    get_current_grudge_level = function() return 5 end}
    assert(not GG.RACE_NEEDS.call_reckoning("me"), "a cycle ending next turn anyway")
    grudge_cycle.faction_times.me = 4
    assert(GG.RACE_NEEDS.call_reckoning("me"), "a cycle with turns to run")
    grudge_cycle = nil
    ok("Call the Reckoning is offered only while it brings the cycle forward")
end

do
    -- m18: LABOUR GANGS NEEDS A PROVINCE WITH LABOUR, or it sold nothing.
    W.reset()
    F.me.provinces = {}
    assert(not GG.RACE_NEEDS.labour_gangs("me"), "no province, no labour")
    F.me.provinces = {{key = "p1", labour = false}, {key = "p2", labour = true}}
    assert(GG.RACE_NEEDS.labour_gangs("me"), "one province holding labour is enough")
    ok("Labour Gangs is offered only where there is labour to raise")
end

do
    -- m3: A GUILD THAT CHANGED HANDS GAINED NOTHING "THIS ROUND". The gain was the new
    -- leader's reputation less the old leader's - two factions' numbers.
    W.reset()
    W.faction("rival", {regions = {}, lords = {}, heroes = {}})
    GG.CULTURE_OF.me, GG.CULTURE_OF.rival = GG.CHD_CULTURE, GG.CHD_CULTURE
    standing("me", 0, 0)
    standing("rival", 0, 0)
    GG.state.rival.brass.rep = 305
    local slot = GG.lead_slot("brass", GG.CHD_CULTURE)
    GG.world = {turn = 3, bought = 0, demands = 0, patrons = 0,
                rep = {[slot] = 300}, gain = {}, held = {[slot] = "me"}, moved = {}}
    GG.snapshot_world(4, 0, 0, 0)
    assert(GG.world.moved[slot] == true, "the guild changed hands")
    assert(GG.world.gain[slot] == 0, "and no gain is claimed across two factions, got "
           .. tostring(GG.world.gain[slot]))
    ok("a change of hands claims no gain")
end

do
    -- m4: WHO IS PRESENT IS READ EACH ROUND. A faction that appeared mid-campaign (an
    -- invasion, a rebellion) earned unseen until the next load.
    W.reset()
    GG.roster_cache = nil
    local real = GG.present
    local here = {me = true}
    GG.present = function(f) return here[f:name()] == true end
    W.faction("late", {regions = {}, lords = {}, heroes = {}})
    local function has(list, k)
        for _, v in ipairs(list) do if v == k then return true end end
        return false
    end
    assert(not has(GG.roster(GG.CHD_CULTURE), "late"), "not present yet")
    here.late = true
    TURN = TURN + 1
    local got = has(GG.roster(GG.CHD_CULTURE), "late")
    GG.present, GG.roster_cache = real, nil
    assert(got, "present from the next round on")
    ok("the roster is read again each round")
end


do
    -- m20: THE COURT IS FOR COVERED RIVALS ONLY. Rows left by an older build for another
    -- race were handed demands and a patron every round, and climbed forever.
    W.reset()
    local LZD = "wh2_main_lzd_lizardmen"
    W.char(31, {faction = "lzd", general = true})
    W.faction("lzd", {culture = LZD, regions = {}, lords = {31}, heroes = {}, treasury = 999999})
    standing("lzd", 150, 150)
    GG.demand_last.lzd = TURN - 99
    local paid = GGAI.court_step("lzd", TURN)
    assert(not paid and not GG.demands.lzd, "no demand for a race this mod does not cover")
    assert(not GG.patrons.lzd, "and no patron")
    ok("the rivals' Court leaves uncovered factions alone")
end

do
    -- m21: A RIVAL'S HOSTILE PICK IS A LIVING ENEMY, NOT "rebels", and a pick that needs a
    -- region takes an enemy that holds one. The raw war list includes both, and The
    -- Khan's Price was spent on them for nothing.
    W.reset()
    W.region("r_reb", {owner = "rebels"})
    W.region("r_dead", {owner = "deadfoe"})
    W.region("r_foe", {owner = "foe"})
    W.faction("rebels", {regions = {"r_reb"}})
    W.faction("deadfoe", {dead = true, regions = {"r_dead"}})
    W.faction("horde", {regions = {}})
    W.faction("foe", {regions = {"r_foe"}})
    F.me.at_war = {rebels = true, deadfoe = true, horde = true, foe = true}
    local enemies, regions = {}, {}
    for k = 1, 4 do
        RANDOM = function(n) return math.min(k, n) end
        local e = GGAI.pick_enemy("me")
        if e then enemies[e] = true end
        local r = GGAI.pick_enemy_region("me")
        if r then regions[r] = true end
    end
    RANDOM = function() return 1 end
    assert(not enemies.rebels and not enemies.deadfoe, "never rebels or the dead")
    assert(enemies.foe and enemies.horde, "any living enemy for a faction target")
    assert(regions.r_foe and not regions.r_reb and not regions.r_dead,
           "a region pick lands on a living enemy's region")
    ok("a rival aims hostile services at living enemies")
end

do
    -- m22: THE STANDINGS STILL MOVE WITH THE RIVALS SWITCHED OFF. The round's record is
    -- not an AI action, and "Off, rivals still earn" promised a leaderboard that means
    -- something.
    W.reset()
    GG.TUNE.ai_spending = false
    TURN = 10
    GG.world = {turn = 0, bought = 0, demands = 0, patrons = 0,
                rep = {}, gain = {}, held = {}, moved = {}}
    GGAI.run_turn()
    assert(GG.world.turn == 10, "the round is recorded, got " .. tostring(GG.world.turn))
    ok("the Standings record is written with the rivals switched off")
end


do
    -- m8: THE MCT'S "Write every reputation to the log" BUTTON HAS A LISTENER. It raised
    -- DerpyGGDumpStandings and nothing heard it.
    W.reset()
    standing("me", 120, 30)
    local lines, real = {}, GG.trace
    GG.trace = function(l) lines[#lines + 1] = l end
    assert(HANDLERS.gg_dump, "a listener is registered")
    HANDLERS.gg_dump()
    GG.trace = real
    local all = table.concat(lines, " / ")
    assert(string.find(all, "me", 1, true) and string.find(all, "brass=120/30", 1, true),
           "every faction's reputation and favour is written, got: " .. all)
    ok("the MCT's dump button writes every standing to the log")
end

do
    -- m10: APPOINT IS NOT A TOGGLE. The op dismissed whenever the post was held for that
    -- guild, so a second press before the first came back dismissed the patron.
    W.reset()
    W.char(7, {faction = "me", general = true})
    F.me.lords = {7}
    standing("me", 0, 0)
    GG.save("me")
    GG.MP_OPS.patron("me", "appoint|brass|7")
    GG.MP_OPS.patron("me", "appoint|brass|7")
    assert(GG.patrons.me and GG.patrons.me.guild == "brass", "a second appoint keeps the post")
    GG.MP_OPS.patron("me", "dismiss|brass")
    assert(not GG.patrons.me, "dismiss is its own word")
    ok("the patron op says appoint or dismiss")
end

do
    -- m11: TAKE NAMES THE GUILD, NOT A POSITION. The board is one offer per guild, and an
    -- index captured at the last draw pointed at another offer once the board shifted.
    board5()
    local brass = GG.bounties.me[1]
    local slavers = {}
    for k, v in pairs(brass) do slavers[k] = v end
    slavers.guild = "slavers"
    GG.bounties.me = {slavers, brass}
    GG.grant("me", "brass", 50, "test")
    GG.save("me")
    GG.save_bounties("me")
    GG.MP_OPS.bounty("me", "brass")
    assert(GG.bounties.me[2].taken and not GG.bounties.me[1].taken,
           "the Brass offer is the one taken")
    ok("a bounty is taken by its guild")
end

do
    -- C1: A HUMAN'S BOUNTY BOARD comes back at the first tick too.
    board5()
    GG.save_bounties("me")
    reload()
    GG.load_all()
    assert(GG.bounties.me and GG.bounties.me[1] and GG.bounties.me[1].guild == "brass",
           "the board is back after a load")
    ok("the first tick restores a human's bounty board")
end

do
    -- I1: THE FIRST TICK ITSELF DRAWS A NEW CAMPAIGN'S CARDS, and a loaded one's never.
    W.reset()
    GG.cards = {}
    NEW_GAME = nil
    GG.first_cards()
    assert(not GG.cards.me, "a loaded campaign draws nothing at the first tick")
    assert(FIRST_TICK and #FIRST_TICK > 0, "the mod registers a first tick")
    NEW_GAME = true
    for i = 1, #FIRST_TICK do FIRST_TICK[i]() end
    NEW_GAME = nil
    assert(GG.cards.me and GG.cards.me.turn == 1,
           "the first tick of a new campaign draws the player's cards")
    ok("the first tick draws a new campaign's cards, and only a new one's")
end

do
    -- I3, I2: A VACATED POST TAKES ITS BUNDLE OFF; A SAVED POST KEEPS ITS ARMY.
    W.reset()
    W.char(7, {faction = "me", general = true})
    F.me.lords = {7}
    standing("me", 500, 500)
    assert(GG.set_patron("me", "brass", 7), "appointed")
    C["7"].army = false
    CALLS.force_unbundle = nil
    GG.assert_patron("me")
    assert(not GG.patrons.me, "a lord who lost the army loses the post")
    assert(CALLS.force_unbundle and CALLS.force_unbundle[1][2] == 1007,
           "and the army keeps no bundle")
    -- The lord takes another army after the save: the bundle is still on the first one.
    C["7"].army = nil
    assert(GG.set_patron("me", "brass", 7), "appointed again")
    GG.save_patron("me")
    C["7"].force = 2007
    reload()
    GG.load_patron("me")
    assert(GG.patron_forces.me == 1007,
           "the saved army, not the lord's new one, got " .. tostring(GG.patron_forces.me))
    C["7"].force = nil
    ok("a vacated post cleans up, and a saved post remembers its army")
end

do
    -- m1: A TURN START FORGETS THE LAST TURN'S EARNINGS IN THE SAVE AS WELL.
    W.reset()
    standing("me", 0, 0)
    GG.reset_turn("me")
    GG.capped_grant("me", "brass", 10, "battles")
    GG.reset_turn("me")
    reload()
    assert(next(GG.load_gain("me")) == nil, "a turn start clears the saved earnings")
    ok("a turn start clears the saved earnings")
end

do
    -- m8: THE DUMP LISTENER HEARS THE EVENT THE MCT BUTTON RAISES.
    local f = io.open("Modding Files/pack/script/mct/settings/derpy_great_guilds.lua", "rb")
    local src = f:read("*a")
    f:close()
    local raised = string.match(src, 'trigger_custom_event%("([%w_]+)"')
    assert(raised, "the MCT button raises an event")
    assert(EVENTS.gg_dump == raised,
           "gg_dump hears " .. tostring(EVENTS.gg_dump) .. ", the button raises " .. raised)
    ok("the dump button is heard")
end

do
    -- m21: A SETTLEMENT SERVICE NEEDS AN ENEMY WITH A SETTLEMENT.
    W.reset()
    local prev = GGAI.TEST_WARS
    GGAI.TEST_WARS = nil
    W.faction("foe_bare", {regions = {}, lords = {}, heroes = {}})
    F.me.at_war = {foe_bare = true}
    assert(GGAI.pick_enemy("me", true) == nil, "an enemy with no settlement is no target")
    assert(GGAI.pick_enemy("me") == "foe_bare", "for an army service it is one")
    F.me.at_war = {}
    GGAI.TEST_WARS = prev
    ok("a settlement service needs an enemy with a settlement")
end

print("bounty harness ok")
