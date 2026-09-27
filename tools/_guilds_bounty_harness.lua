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

-- A REGION. t: owner, x, y, adj = {keys}, buildings = {level=true}, worth = {n, cap, army}
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
                    display_position_y = function() return t.y or 0 end}
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
        character_type = function(_, k) return (k == "general") == (t.general == true) end,
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
                    unit_list = function() return {num_items = function() return n end} end}
        end,
    }
end

TURN = 1
RANDOM = function(n) return 1 end   -- tests replace this to steer a roll

cm = {
    set_saved_value = function(_, k, v) saved[k] = v end,
    get_saved_value = function(_, k) return saved[k] end,
    add_first_tick_callback = function() end,
    apply_effect_bundle = function() end,
    remove_effect_bundle = function() end,
    model = function() return {turn_number = function() return TURN end} end,
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
    treasury_mod = function() end,
}
core = {add_listener = function(_, name, _e, _c, fn) HANDLERS[name] = fn end}
out = function() end

dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua")
if io.open("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua") then
    dofile("Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_bounty_data.lua")
end
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
    GG.MP_OPS.bounty("me", "1")
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
    GG.BOUNTY_TECHS[""] = {{"tech_a", 5}, {"tech_b", 6}}
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
    -- build: a level the player has nowhere; one they have is skipped.
    W.reset()
    GG.BOUNTY_BUILDINGS[""] = GG.BOUNTY_BUILDINGS[""] or {}
    GG.BOUNTY_BUILDINGS[""].brass = {{"lvl_have", 3}, {"lvl_want", 4}}
    F.me.regions = {"home"}
    W.region("home", {owner = "me", buildings = {lvl_have = true}})
    local o = GG.make_offer("me", "brass", "job_build", 1, {})
    assert(o and o.target == "lvl_want", "build must skip a building you own")
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

print("bounty harness ok")
