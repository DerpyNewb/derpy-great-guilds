-- The Great Guilds - panel.
--
-- Creates its own components from the mod's own .twui.xml files. It overrides no
-- CA file, so it collides with nothing.
--
-- Rules that are silent when broken, every one of them learned the hard way:
--   * dockpoint is IGNORED on a runtime component. MoveTo is the only thing that
--     positions one, and a layout group beats MoveTo.
--   * Never cache a UIComponent handle. is_uicomponent() is a type test and a
--     destroyed component still passes it. Re-find every time.
--   * SetStateText is per state. A label written to one state vanishes on hover.
--   * A missing imagepath draws a blank square, silently.
--   * Loc resolves HERE, at draw time, never in a turn handler. A loc call from a
--     turn handler is a CTD at turn 1 and pcall does not catch it.

GGUI = GGUI or {}

GGUI.PANEL = "derpy_gg_panel"
GGUI.CARD  = "derpy_gg_card"
GGUI.ROW   = "derpy_gg_row"

GGUI.PATH_PANEL = "ui/campaign ui/derpy_gg_panel"
GGUI.PATH_CARD  = "ui/campaign ui/derpy_gg_card"
GGUI.PATH_ROW   = "ui/campaign ui/derpy_gg_row"
GGUI.PATH_OPENER = "ui/campaign ui/derpy_gg_opener"

-- 1 guilds, 2 standings, 3 bounties, 4 court, 5 help, 6 log. NUMBERED BY AGE, not by
-- position: the Log sits left of Help on screen but took the next free number, so no
-- existing TAB test had to move.
GGUI.TAB  = 1
GGUI.PAGE = 1     -- which guild, 1..6

GGUI.GUILD_ORDER = {"brass", "immortals", "daemonsmiths", "khanate",
                    "overseers", "slavers"}

-- Card slot geometry, mirroring PANEL_LAYOUT in tools/gen_guilds_ui.py.
GGUI.CARD_XY = {{20, 170}, {20, 300}, {20, 430}}

-- NO STATE LIST LIVES HERE ANY MORE. There was one - {"default", "hover",
-- "selected", "active"} - fed to SetStateText as if the second argument named a
-- state. It does not: CA's reference calls it "source of text in format of a
-- stringtable key", and SetStateText always writes the CURRENT state. These
-- components have states named "standard" and "hover", never "default", so the
-- Buy caption existed on one state and vanished on mouseover. Use SetText.

-- ---------------------------------------------------------------- helpers ---

local function root()
    return core:get_ui_root()
end

-- Never cached. A destroyed component still passes is_uicomponent(), so a stored
-- handle is a crash waiting for a panel close.
local function comp(name, parent)
    local ok, c = pcall(function()
        return find_uicomponent(parent or root(), name)
    end)
    if ok and c and is_uicomponent(c) then return c end
    return nil
end

-- SetText writes ALL states; SetStateText writes only the current one and takes a
-- STRINGTABLE KEY as its second argument, not a state name. Getting that backwards
-- is what made the Buy caption disappear on mouseover.
local function set_text(c, text)
    if not c then return end
    pcall(function() c:SetText(text, "") end)
end

-- NOTHING IN THIS ENGINE WRAPS TEXT. Measured for the Zharr Exchange: a component
-- resized to 880x60 still reported its string as one 1333px line, and there is no
-- texthbehaviour value that changes it. So a paragraph becomes a LIST OF LINES and
-- each line gets its own component. Widths come from TextDimensionsForText, never
-- from a character budget - the guess is what shipped "Shaken: Gemsto..." once.
function GGUI.wrap(c, text, max_lines)
    if not c or not text or text == "" then return {} end
    local ok_w, w = pcall(function() return c:Dimensions() end)
    if not ok_w or not w or w <= 0 then return {text} end
    local lines, cur = {}, nil
    for word in string.gmatch(text, "%S+") do
        local try = cur and (cur .. " " .. word) or word
        local ok, need = pcall(function() return c:TextDimensionsForText(try) end)
        if ok and need and need > w and cur then
            lines[#lines + 1] = cur
            if max_lines and #lines >= max_lines then
                -- Out of room: mark the cut rather than ending mid-sentence as if
                -- that were the whole thought.
                lines[#lines] = cur .. " ..."
                return lines
            end
            cur = word
        else
            cur = try
        end
    end
    if cur then lines[#lines + 1] = cur end
    return lines
end

local function set_named_text(name, text)
    set_text(comp(name), text)
end

-- SetTooltipText APPENDS to whatever the component already carries rather than
-- replacing it, so a tooltip rewritten every refresh would grow without bound.
-- Passing an empty string first clears it. The second argument takes a literal
-- string here, not a stringtable key, which is why "||" splits correctly: the
-- text is already resolved by GGUI.loc before it arrives.
--
-- Never read a tooltip back. GetTooltipText hard-crashes on a HUD button.
local function set_tooltip(c, text)
    if not c or not text or text == "" then return end
    pcall(function() c:SetTooltipText("", true) end)
    pcall(function() c:SetTooltipText(text, true) end)
end

-- ------------------------------------------------------------------- loc ---
-- Every call below reads localisation and therefore may ONLY be reached from a
-- draw path. Nothing in zzz_derpy_guilds.lua calls into this file.

function GGUI.loc(key)
    local ok, s = pcall(function()
        return common.get_localised_string("derpy_gg_" .. key)
    end)
    if ok and s and s ~= "" then return s end
    return key
end

function GGUI.loc_guild(g)   return GGUI.loc("guild_name_" .. g) end
function GGUI.loc_service(k) return GGUI.loc("service_name_" .. k) end
function GGUI.loc_rank(r)    return GGUI.loc("rank_name_" .. r) end
function GGUI.loc_service_desc(k) return GGUI.loc("service_desc_" .. k) end
function GGUI.loc_guild_desc(g)   return GGUI.loc("guild_desc_" .. g) end

-- ----------------------------------------------------------------- panel ---

function GGUI.current_guild()
    return GGUI.GUILD_ORDER[GGUI.PAGE] or GGUI.GUILD_ORDER[1]
end

-- WHOSE HALL THE PANEL IS STANDING IN. The Guilds tab pages one guild at a time and the
-- Standings tab has a selected row, so "the guild on screen" is two different variables
-- depending on the tab; everything else follows the pager.
function GGUI.ground_guild()
    if GGUI.TAB == 2 then return (GGUI.stand_guild()) end
    return GGUI.current_guild()
end

-- Repaint the panel's ground for a guild. Called on every refresh rather than memoised:
-- GGUI.close DESTROYS the panel, so any memo of what was last painted is wrong the next
-- time it opens, and the way that fault presents is a panel stuck on CA's default ground
-- with nothing in the log. GetImagePath would answer the question directly and is BANNED
-- - it hard-crashes the game, as GetTooltipText does. Refresh runs on clicks and events,
-- not on a timer, so this is a handful of calls per panel visit.
function GGUI.paint_ground(guild)
    local path = GGUI.PANEL_BG[guild]
    -- NO FALLBACK TO "". An unknown guild leaves the ground alone; SetImagePath with an
    -- empty path draws nothing at all, so guessing here would trade a wrong picture for
    -- no picture.
    if not path then return end
    local panel = comp(GGUI.PANEL)
    if not panel then return end
    pcall(function() panel:SetImagePath(path, GGUI.BG_INDEX) end)
end

function GGUI.services_of(guild)
    local out = {}
    for i = 1, #GG.SERVICES do
        if GG.SERVICES[i].guild == guild then out[#out + 1] = GG.SERVICES[i] end
    end
    return out
end

-- ---------------------------------------------------------------- layout ---
-- THE tx/ty OFFSETS IN THE .twui.xml POSITION NOTHING. Measured live through the
-- wh3 bridge on 2026-09-10, with the panel open:
--
--   panel        @565,190 790x700
--   gg_title     @565,190 400x28
--   gg_rank_line @565,190 750x26
--   gg_footer    @565,190 750x30
--   card_1       @585,360 750x120
--     card_name  @585,360 520x26
--     card_cost  @585,360 130x26
--
-- EVERY child sits at exactly its parent's origin. That is why the title and the
-- rank line drew on top of each other and every card's label sat in the card's top
-- left corner outside the plate.
--
-- uicomponent:MoveTo with ABSOLUTE screen coordinates is the only thing that moves a
-- runtime component - the same rule the Zharr Exchange states above EX.layout, which
-- positions every one of its components explicitly for exactly this reason.
--
-- These tables MIRROR PANEL_LAYOUT / CARD_LAYOUT / ROW_LAYOUT in tools/gen_guilds_ui.py.
-- gen_guilds_ui.check() parses this file and refuses if the two disagree, because a
-- drift here is silent misplacement rather than an error.
GGUI.PANEL_XY = {
    gg_crest      = {16, 9},
    gg_title      = {54, 14},
    gg_close      = {748, 12},
    gg_divider    = {20, 44},
    gg_tab_guilds = {20, 56},
    gg_tab_stand  = {145, 56},
    gg_tab_bounty = {270, 56},
    gg_tab_court  = {395, 56},
    gg_tab_log    = {520, 56},
    gg_tab_help   = {645, 56},
    gg_rank_line  = {20, 104},
    gg_bar_track  = {20, 138},
    gg_rep_bar    = {20, 138},
    gg_card_1     = {20, 170},
    gg_card_2     = {20, 300},
    gg_card_3     = {20, 430},
    gg_prev       = {20, 596},
    gg_next       = {732, 596},
    gg_footer     = {20, 640},
    gg_help_01   = {20, 168},
    gg_help_02   = {20, 188},
    gg_help_03   = {20, 208},
    gg_help_04   = {20, 228},
    gg_help_05   = {20, 248},
    gg_help_06   = {20, 268},
    gg_help_07   = {20, 288},
    gg_help_08   = {20, 308},
    gg_help_09   = {20, 328},
    gg_help_10   = {20, 348},
    gg_help_11   = {20, 368},
    gg_help_12   = {20, 388},
    gg_help_13   = {20, 408},
    gg_help_14   = {20, 428},
    gg_help_15   = {20, 448},
    gg_help_16   = {20, 468},
    gg_help_17   = {20, 488},
    gg_help_18   = {20, 508},
    gg_help_19   = {20, 528},
    gg_help_20   = {20, 548},
    gg_help_21   = {20, 568},
}

-- Mirrors HELP_SLOTS in tools/gen_guilds_ui.py; check() refuses if the two differ.
GGUI.HELP_SLOTS = 21
GGUI.CARD_CHILD_XY = {
    card_icon = {14, 26},
    card_name = {92, 12},
    card_desc_1 = {92, 44},
    card_desc_2 = {92, 64},
    card_cost = {596, 12},
    card_buy  = {596, 60},
}

-- The card is ONE template used by all six guilds, so its icon cannot be baked into
-- the .twui.xml - the file ships a placeholder and this swaps it per draw. A path the
-- game does not have draws a blank square and says nothing about it, so
-- gen_guilds_ui.check() parses this table and asserts every path exists in a ui pack.
GGUI.GUILD_ICON = {
    -- OUR OWN RECOLOURED COPIES of CA's 74x74 building icons - written by
    -- tools/make_guild_icons.py, sources in Modding Files/source/guild_icons.
    -- CA's originals are flat dark silhouettes at 80% opacity, tinted at draw time
    -- on CA's own panels; drawn raw on a near-black card they were barely legible.
    -- They cannot be tinted brighter in the .twui.xml because a layer colour
    -- MULTIPLIES. 74x74 into a 44px box is still a downscale, so they stay sharp.
    brass        = "ui/campaign ui/derpy_gg_icons/brass.png",
    immortals    = "ui/campaign ui/derpy_gg_icons/immortals.png",
    daemonsmiths = "ui/campaign ui/derpy_gg_icons/daemonsmiths.png",
    khanate      = "ui/campaign ui/derpy_gg_icons/khanate.png",
    overseers    = "ui/campaign ui/derpy_gg_icons/overseers.png",
    slavers      = "ui/campaign ui/derpy_gg_icons/slavers.png",
}

-- THE PANEL GROUND, ONE PICTURE PER GUILD. The panel component carries FOUR images in
-- this order - the plain tile, the art, the scrim over it, the frame around it - and
-- SetImagePath replaces one of them by INDEX. Index 1 is the art: index 0 would replace
-- the tile UNDERNEATH it, which is hidden and would change nothing anyone can see, and
-- index 2 would replace the scrim that makes the Help tab's unplated text readable.
-- gen_guilds_ui.check() pins this number against the order of PANEL_LAYERS, because the
-- day a layer is inserted above the art this constant is wrong with no symptom but a
-- background that stops changing.
GGUI.BG_INDEX = 1

-- Baked by tools/make_guild_backgrounds.py out of the Chaos Dwarf reference art. Each
-- one is multiplied down until it measures what CA's tier_01 ground measures under this
-- panel's scrim, so the text over it keeps exactly the contrast it was tuned for; the
-- generator re-measures the shipped files rather than trusting that it was done.
GGUI.PANEL_BG = {
    brass        = "ui/campaign ui/derpy_gg_bg/brass.png",
    immortals    = "ui/campaign ui/derpy_gg_bg/immortals.png",
    daemonsmiths = "ui/campaign ui/derpy_gg_bg/daemonsmiths.png",
    khanate      = "ui/campaign ui/derpy_gg_bg/khanate.png",
    overseers    = "ui/campaign ui/derpy_gg_bg/overseers.png",
    slavers      = "ui/campaign ui/derpy_gg_bg/slavers.png",
}
-- The reputation bar's FULL width, matching PANEL_LAYOUT["gg_rep_bar"] in
-- tools/gen_guilds_ui.py, which check() pins. The bar is drawn at full width in the
-- .twui.xml and narrowed here to the fraction earned - it read as a full gold bar at
-- 0 / 100 reputation until this existed, which says the opposite of the truth.
-- Mirrors GG.BOUNTY_OFFER_LIFE in zzz_derpy_guilds.lua. The panel counts down from
-- it, so a drift here draws a countdown that disagrees with when the offer actually
-- goes away. gen_guilds_ui.check() pins the two together.
GGUI.BOUNTY_LIFE = 6

GGUI.REP_BAR_W = 750
GGUI.REP_BAR_H = 12

-- Mirrors ROW_LAYOUT in tools/gen_guilds_ui.py; check() compares the two. The leader
-- column was widened to 324px because it now carries the round's movement as well as
-- the holder.
GGUI.ROW_CHILD_XY = {
    row_guild  = {14, 8},
    row_rank   = {212, 8},
    row_leader = {416, 8},
}

-- ------------------------------------------- the standings faction list ---
-- WHO ELSE IS IN THE RACE. The Standings tab named the leader of each guild and where
-- you sat in it ("4/9") and nothing in between - so a player could see they were fourth
-- and never learn who the three above them were. The full table was a HOVER, five names
-- deep, which is not a thing you can read while comparing two guilds.
--
-- SCROLLING IS NOT A WIDGET IN THIS ENGINE. It is four components with reserved names -
-- list_clip, list_box, vslider, handle - carrying reserved callbacks - List, VSlider,
-- VSliderHandle - which the engine binds to each other BY NAME. They live in
-- derpy_gg_list.twui.xml; tools/gen_guilds_ui.py check_scroll_parts() keeps that spelling
-- honest, including against CA's own file it was read from.
-- NAMED `listview`, and the component carries callback_id="Listview". That callback
-- is what binds list_clip, list_box and vslider to each other; the first build of
-- this list had the inner three and no container callback, and it drew, stacked and
-- clipped its rows perfectly while refusing to scroll a single line.
GGUI.LIST = "listview"
GGUI.FROW = "derpy_gg_frow"
GGUI.PATH_LIST = "ui/campaign ui/derpy_gg_list"
GGUI.PATH_FROW = "ui/campaign ui/derpy_gg_frow"

GGUI.LIST_XY = {20, 440}
GGUI.LIST_W  = 750
GGUI.LIST_H  = 150

-- list_box is deliberately absent. It is inside list_clip and the engine's List layout
-- owns where it sits; moving it is how you scroll a list to somewhere it is not. Same for
-- the slider's handle, which VSlider owns.
GGUI.LIST_CHILD_XY = {
    list_clip = {0, 0},
    vslider   = {734, 0},
}

-- WHICH GUILD THE LIST IS SHOWING: an index into GG.GUILDS, because GGUI.leaders() builds
-- the six rows in exactly that order. Clicking a standings row sets it.
GGUI.STAND_GUILD = 1

-- A faction whose flag_path() was unreadable still gets a crest rather than a gap. A path
-- that resolves to nothing draws nothing and says nothing about it.
GGUI.FLAG_FALLBACK = "ui/flags/wh3_dlc23_chd_chaos_dwarfs/mon_24.png"

-- Re-run on every open and every refresh. Cheap, and it heals a panel laid out
-- before the screen settled instead of leaving a bad position permanent.
function GGUI.layout()
    local panel = comp(GGUI.PANEL)
    if not panel then return end
    local px, py = panel:Position()
    for name, xy in pairs(GGUI.PANEL_XY) do
        local c = comp(name, panel)
        if c then c:MoveTo(px + xy[1], py + xy[2]) end
    end
    for i = 1, #GGUI.CARD_XY do
        local card = comp(GGUI.CARD .. "_" .. i, panel)
        if card then
            card:MoveTo(px + GGUI.CARD_XY[i][1], py + GGUI.CARD_XY[i][2])
            -- Read the card's position back rather than reusing the asked-for
            -- numbers: the children must follow where the card ACTUALLY went.
            local cx, cy = card:Position()
            for name, xy in pairs(GGUI.CARD_CHILD_XY) do
                local c = comp(name, card)
                if c then c:MoveTo(cx + xy[1], cy + xy[2]) end
            end
        end
    end
    -- THE LIST FRAME, but not what is inside the box. The clip window and the slider are
    -- placed here because nothing else places them; the rows inside are placed by the
    -- engine's list layout, which is the whole point of using one.
    local list = comp(GGUI.LIST, panel)
    if list then
        list:MoveTo(px + GGUI.LIST_XY[1], py + GGUI.LIST_XY[2])
        local lx, ly = list:Position()
        for name, xy in pairs(GGUI.LIST_CHILD_XY) do
            local c = comp(name, list)
            if c then c:MoveTo(lx + xy[1], ly + xy[2]) end
        end
    end
    for i = 1, #GG.GUILDS do
        local row = comp(GGUI.ROW .. "_" .. i, panel)
        if row then
            row:MoveTo(px + 20, py + 170 + (i - 1) * 44)
            local rx, ry = row:Position()
            for name, xy in pairs(GGUI.ROW_CHILD_XY) do
                local c = comp(name, row)
                if c then c:MoveTo(rx + xy[1], ry + xy[2]) end
            end
        end
    end
end

function GGUI.open()
    if comp(GGUI.PANEL) then GGUI.refresh(); return end
    local ok = pcall(function()
        local r = root()
        r:CreateComponent(GGUI.PANEL, GGUI.PATH_PANEL)
        local panel = comp(GGUI.PANEL)
        if not panel then return end
        -- MoveTo, not dockpoint. Bounds() includes children; the screen size is
        -- Dimensions(), so centring reads the root's Dimensions.
        local sw, sh = r:Dimensions()
        local pw, ph = panel:Dimensions()
        panel:MoveTo(math.floor((sw - pw) / 2), math.floor((sh - ph) / 2))
        panel:PropagatePriority(60)

        -- AND IT EATS THE MOUSE WHILE IT IS UP. Without this the panel is scenery:
        -- the cursor reaches the campaign map straight through 790x700 of
        -- background, so hovering it raises the region and army tooltips of
        -- whatever is behind it, and a click lands on the map as well as on us.
        -- CA's words for the flag: "Interactivity determines if a component can
        -- handle mouse interactions like clicks and mouseovers" - a component that
        -- cannot handle them does not consume them either. An interactive CONTAINER
        -- is CA's norm and no risk to its children; the rituals panel ships
        -- agent_list, bottom and action all interactive with working children.
        --
        -- A LITERAL true IS SAFE HERE ONLY BECAUSE GGUI.close DESTROYS THE PANEL.
        -- The Zharr Exchange hides its panel instead, so it must write this flag
        -- from the same variable as its visibility - interactive-while-hidden is a
        -- dead zone in the middle of the map that nothing on screen explains, and
        -- that is the worse bug. gen_guilds_ui.check() refuses this literal the
        -- moment close() stops destroying.
        panel:SetInteractive(true)

        -- MoveTo TAKES ABSOLUTE SCREEN COORDINATES, even for a child. Being a child
        -- of the panel does NOT make MoveTo relative to it: the cards were moved to
        -- (20,170), (20,300), (20,430) and landed in the top-left corner of the
        -- SCREEN, outside their own parent, over the campaign map. Every offset in
        -- GGUI.CARD_XY and every row below is panel-relative by design, so the
        -- panel's own origin has to be added back on.
        for i = 1, #GGUI.CARD_XY do
            panel:CreateComponent(GGUI.CARD .. "_" .. i, GGUI.PATH_CARD)
        end
        -- One standings row per guild, stacked under the header. Created once and
        -- hidden with el.hidden-style visibility on the tabs that do not use them.
        for i = 1, #GG.GUILDS do
            panel:CreateComponent(GGUI.ROW .. "_" .. i, GGUI.PATH_ROW)
        end
        -- The faction list frame. Its rows are not created here: they depend on who is
        -- alive and which guild is selected, so GGUI.draw_faction_list builds them.
        panel:CreateComponent(GGUI.LIST, GGUI.PATH_LIST)
        -- Creation only above. GGUI.layout() places every component, including the
        -- panel's own children, which the .twui.xml offsets do not.
        GGUI.layout()
    end)
    if ok then GGUI.refresh() end
end

function GGUI.close()
    local p = comp(GGUI.PANEL)
    if p then pcall(function() p:DestroyChildren(); p:Destroy() end) end
end

function GGUI.card(i)
    return comp(GGUI.CARD .. "_" .. i, comp(GGUI.PANEL))
end

function GGUI.draw_card(faction, i, s)
    local card = GGUI.card(i)
    if not card then return end
    if not s then
        set_text(comp("card_name", card), "")
        set_text(comp("card_desc_1", card), "")
        set_text(comp("card_desc_2", card), "")
        set_text(comp("card_cost", card), "")
        set_text(comp("card_buy", card), "")
        local eb = comp("card_buy", card)
        if eb then pcall(function() eb:SetVisible(false) end) end
        -- An empty card keeps its plate but drops the glyph, so a short guild's
        -- third slot reads as empty rather than as a mislabelled service.
        local ic = comp("card_icon", card)
        if ic then pcall(function() ic:SetVisible(false) end) end
        return
    end
    local ok, why = GG.can_buy(faction, s.key)
    -- A TARGETED service needs something selected on the map. can_buy cannot see the
    -- selection, so the card checks it here - otherwise the button reads as live and
    -- refuses when pressed, which is the fault this whole pass keeps finding.
    --
    -- GG.needs_target, not s.hostile: four more services read a target and did nothing
    -- without one, and this card showed all four as buyable.
    if ok and GG.needs_target(s) and not GGUI.pick_target(s, faction) then
        ok, why = false, "target"
    end
    local label = GGUI.loc_service(s.key)
    local rep_now = GG.get(faction, s.guild)
    local need_rep = GG.RANKS[s.rank] or 0
    if not ok and why == "rank" then
        -- [[col:]] markup works in SetStateText. A typo'd colour name silently
        -- drops the colour rather than erroring, so this uses a known one.
        -- "Needs Indebted" rather than "Indebted": the bare rank name reads as a
        -- property of the service, not as the thing standing in your way.
        label = label .. "  [[col:red]]" .. GGUI.loc("needs") .. " "
                .. GGUI.loc_rank(s.rank) .. "[[/col]]"
    elseif not ok and why == "lead" then
        -- The monopoly. Red, like the rank gate, because it is the same kind of thing:
        -- something standing between the player and a service they can otherwise afford.
        label = label .. "  [[col:red]]" .. GGUI.loc("needs_lead") .. "[[/col]]"
    elseif not ok and why == "cooldown" then
        label = label .. "  " .. GG.cooldown_left(faction, s.key) .. "t"
    elseif not ok and why == "target" then
        label = label .. "  [[col:red]]" .. GGUI.loc("needs_target_short") .. "[[/col]]"
    end
    set_text(comp("card_name", card), label)

    -- THE LIVE PRICE, from the same call GG.buy charges through. A guild that knows
    -- you charges less; one whose rival you have been courting charges more, so the
    -- number on this card is not the number in the data and must never be read from
    -- there.
    local cost_now, cost_mod = GG.service_cost(faction, s.key)
    local cost_text = tostring(cost_now)
    if cost_mod < 0 then
        cost_text = "[[col:green]]" .. cost_text .. "[[/col]]"
    elseif cost_mod > 0 then
        cost_text = "[[col:yellow]]" .. cost_text .. "[[/col]]"
    end
    if not ok and why == "favour" then
        cost_text = "[[col:red]]" .. tostring(cost_now) .. "[[/col]]"
    end
    set_text(comp("card_cost", card), cost_text)

    local ic = comp("card_icon", card)
    if ic then
        pcall(function()
            ic:SetVisible(true)
            ic:SetImagePath(GGUI.GUILD_ICON[GGUI.current_guild()] or "", 0)
        end)
    end

    -- The card shows a name and a number. Everything a player needs to decide -
    -- what it does, what the number is, how long it lasts, why it is greyed -
    -- lives in the tooltip, so it is built here rather than left implicit.
    local tip = GGUI.loc_service_desc(s.key)
    local body = tip:match("^(.-)||") or tip
    local d1 = comp("card_desc_1", card)
    local lines = GGUI.wrap(d1, body, 2)
    set_text(d1, lines[1] or "")
    set_text(comp("card_desc_2", card), lines[2] or "")
    if not ok and why == "rank" then
        -- The exact shortfall, because "keep earning reputation" does not tell a
        -- player whether they are ten short or a thousand.
        tip = tip .. "||" .. GGUI.loc("locked_hint")
              .. " You have " .. rep_now .. " reputation with them and need "
              .. need_rep .. " for " .. GGUI.loc_rank(s.rank) .. " - "
              .. math.max(0, need_rep - rep_now) .. " more."
    elseif not ok and why == "lead" then
        local who = GG.leader_of(s.guild, GG.culture_of(faction))
        tip = tip .. "||" .. GGUI.loc("lead_hint")
        if who then
            tip = tip .. "  " .. GGUI.loc("lead_by") .. " " .. GGUI.faction_name(who)
                  .. "."
        end
    elseif not ok and why == "cooldown" then
        tip = tip .. "||On cooldown for another "
              .. GG.cooldown_left(faction, s.key) .. " turns."
    elseif not ok and why == "favour" then
        tip = tip .. "||You do not have " .. cost_now .. " favour with this guild yet."
    elseif not ok and why == "target" then
        tip = tip .. "||" .. GGUI.loc(GGUI.target_hint(s))
    elseif not ok and why == "no_unit" then
        -- Every culture in the campaign runs guilds; only the flavoured ones have a
        -- regiment mapped. Said in words rather than left as a dead button.
        tip = tip .. "||" .. GGUI.loc("no_unit")
    end
    set_tooltip(card, tip)
    -- The price AND the reason for it. A number that moves with no explanation is
    -- read as a bug, which is the whole lesson of the bounty board's difficulty band.
    local cost_tip = GGUI.loc("cost_label") .. ": " .. cost_now
    if cost_mod ~= 0 then
        cost_tip = cost_tip .. "  (" .. GGUI.loc("cost_base") .. " " .. s.cost .. ")||"
                   .. (cost_mod < 0 and GGUI.loc("cost_loyal") or GGUI.loc("cost_rival"))
                   .. "  " .. string.format("%+d", cost_mod) .. "%"
    end
    set_tooltip(comp("card_cost", card), cost_tip)
    local btn = comp("card_buy", card)
    if btn then
        local cap = GGUI.loc("buy")
        if not ok then cap = "[[col:red]]" .. cap .. "[[/col]]" end
        set_text(btn, cap)
        -- SHOWN AGAIN. The bounty board and the Court both hide this button on a slot
        -- with no action, and nothing else would ever bring it back.
        pcall(function()
            btn:SetVisible(true)
            btn:SetDisabled(not ok)
        end)
    end
end

-- A mission's title and description live under keys the RUNTIME derives from the
-- mission key - missions_localised_title_<key> - not under this mod's derpy_gg_
-- prefix, so they cannot go through GGUI.loc.
function GGUI.loc_raw(key)
    local ok, s = pcall(function() return common.get_localised_string(key) end)
    if ok and s and s ~= "" then return s end
    return ""
end

function GGUI.bounty_title(o)
    local t = GGUI.loc_raw("missions_localised_title_" .. GG.bounty_mission_key(o.guild))
    if t ~= "" then return t end
    return GGUI.loc_guild(o.guild)
end

-- Resolved HERE, at draw time, and never stored on the offer: a loc call from a turn
-- handler CTDs at turn 1 and pcall does not catch it, which is why the offer carries
-- only keys.
-- WHO HOLDS IT NOW, not who held it when the offer was posted. The stored owner is a
-- snapshot, and a settlement that changes hands makes it a lie on the card.
function GGUI.bounty_owner_now(o)
    local k = GG.BOUNTY_KINDS[o.kind]
    if k and k.target == "region" then
        local ok, name = pcall(function()
            local r = cm:get_region(o.target)
            if not r or r:is_null_interface() then return nil end
            local f = r:owning_faction()
            if not f or f:is_null_interface() then return nil end
            return f:name()
        end)
        if ok and name then return name end
    end
    return o.owner or ""
end

function GGUI.bounty_target_label(o)
    local owner = GGUI.faction_name(GGUI.bounty_owner_now(o))
    local k = GG.BOUNTY_KINDS[o.kind]
    if k and k.target == "region" then
        -- regions_onscreen_<region_key>, read out of CA's own regions__.loc.
        local nm = GGUI.loc_raw("regions_onscreen_" .. tostring(o.target))
        if nm == "" then nm = tostring(o.target) end
        return nm .. "  (" .. owner .. ")"
    end
    return GGUI.loc("bounty_lord") .. "  (" .. owner .. ")"
end

-- THE DIFFICULTY BANDS, read off the stored score rather than recomputed. The model
-- prices from o.diff and the panel names it from o.diff, so the word and the number are
-- the same fact told twice and cannot drift.
--
-- Thresholds against GG.BOUNTY_DIFF_MAX (200): under a quarter is routine, under
-- two-thirds is hard, the rest is grim.
GGUI.BOUNTY_BANDS = {
    {50,  "bounty_routine"},
    {130, "bounty_hard"},
    {nil, "bounty_grim"},
}

function GGUI.bounty_band(o)
    local d = (o and o.diff) or 0
    for i = 1, #GGUI.BOUNTY_BANDS do
        local at, key = GGUI.BOUNTY_BANDS[i][1], GGUI.BOUNTY_BANDS[i][2]
        if at == nil or d < at then return GGUI.loc(key) end
    end
    return ""
end

function GGUI.draw_bounties(faction)
    -- A reload mid-turn leaves GG.bounties empty until the next turn start, so the
    -- board reads the save the first time it is drawn. This is a saved-value read,
    -- not a loc call, so it is safe from anywhere.
    if not GG.bounties[faction] then
        pcall(function() GG.load_bounties(faction) end)
    end
    -- POSTED ON DEMAND, ONCE PER TURN. post_bounties otherwise runs only at
    -- FactionTurnStart, so the board is empty for a whole turn after the mod is
    -- installed mid-campaign, and empty again on any save loaded after its turn had
    -- already started. Both read as "the feature does not work".
    --
    -- The turn stamp is what keeps this cheap: with no war to draw targets from the
    -- walk finds nothing, and without the stamp it would run again on every redraw.
    local turn = GG.turn_now()
    GGUI.posted = GGUI.posted or {}
    if #(GG.bounties[faction] or {}) == 0 and GGUI.posted[faction] ~= turn then
        GGUI.posted[faction] = turn
        pcall(function()
            GG.post_bounties(faction)
            GG.save_bounties(faction)
        end)
    end
    -- Purged on every draw, not only at turn start: an offer can stop being true in the
    -- middle of your own turn - you take the settlement it names - and the panel is
    -- where that would otherwise be visible for a full turn.
    pcall(function()
        if GG.purge_bounties(faction) > 0 then GG.save_bounties(faction) end
    end)
    local list = GG.bounties[faction] or {}
    for i = 1, #GGUI.CARD_XY do
        local card = GGUI.card(i)
        local o = list[i]
        if card and not o then
            -- An empty slot says so, rather than leaving the previous tab's service
            -- text sitting on a card that no longer means it.
            GGUI.draw_card(faction, i, nil)
            set_text(comp("card_desc_1", card), GGUI.loc("bounty_none"))
            set_tooltip(card, GGUI.loc("bounty_help"))
            -- No offer, no button. draw_card blanks the caption but leaves the plate,
            -- which reads as a button that does nothing rather than as an empty slot.
            local eb = comp("card_buy", card)
            if eb then pcall(function() eb:SetVisible(false) end) end
        elseif card then
            set_text(comp("card_name", card), GGUI.bounty_title(o))
            set_text(comp("card_desc_1", card), GGUI.bounty_target_label(o))

            -- The band leads, because it is the reason the two numbers after it are
            -- what they are. Without it three offers at three prices read as a bug.
            local pay = GGUI.bounty_band(o) .. "   "
                        .. GGUI.loc("bounty_pays") .. " " .. (o.gold or 0) .. "g   "
                        .. (o.rep or 0) .. " " .. GGUI.loc("reputation")
            if o.taken then
                pay = "[[col:yellow]]" .. GGUI.loc("bounty_taken") .. "[[/col]]   "
                      .. pay
            else
                local left = GGUI.BOUNTY_LIFE - (turn - (o.posted or 0))
                if left < 0 then left = 0 end
                pay = pay .. "   " .. left .. " " .. GGUI.loc("bounty_turns")
            end
            set_text(comp("card_desc_2", card), pay)
            set_text(comp("card_cost", card), tostring(o.gold or 0))
            set_tooltip(comp("card_cost", card), GGUI.loc("bounty_pays") .. " "
                        .. (o.gold or 0))

            local ic = comp("card_icon", card)
            if ic then
                pcall(function()
                    ic:SetVisible(true)
                    ic:SetImagePath(GGUI.GUILD_ICON[o.guild] or "", 0)
                end)
            end

            set_tooltip(card, GGUI.loc_guild(o.guild) .. "  -  "
                        .. GGUI.loc_raw("missions_localised_description_"
                                        .. GG.bounty_mission_key(o.guild))
                        .. "||" .. GGUI.loc("bounty_help"))

            local btn = comp("card_buy", card)
            if btn then
                -- A TAKEN OFFER HAS NO BUTTON AT ALL. These buttons ship `standard` and
                -- `hover` only, so SetDisabled has no inactive state to show and a taken
                -- offer still looked exactly like a live one - reported from play as
                -- "it still lets me take it". The row keeps saying Taken beside the pay.
                pcall(function() btn:SetVisible(not o.taken) end)
                if not o.taken then
                    set_text(btn, GGUI.loc("take"))
                    pcall(function() btn:SetDisabled(false) end)
                end
            end
        end
    end
end

-- A THIRD CARD SHAPE. The services write these six children from a service and the
-- bounty board writes them from an offer; the Court has three things that are neither,
-- so it writes them directly rather than pretending to be one of the other two.
--
-- An empty caption HIDES the button. These plates ship `standard` and `hover` only, so
-- SetDisabled has nothing to draw - a card with no action must lose the plate entirely
-- or it reads as a button that does nothing, which is exactly what the bounty board's
-- taken offers did.
function GGUI.write_card(i, icon, name, l1, l2, right, button, enabled, tip)
    local card = GGUI.card(i)
    if not card then return end
    set_text(comp("card_name", card), name or "")
    set_text(comp("card_desc_1", card), l1 or "")
    set_text(comp("card_desc_2", card), l2 or "")
    set_text(comp("card_cost", card), right or "")
    local ic = comp("card_icon", card)
    if ic then
        pcall(function()
            local has = icon ~= nil and icon ~= ""
            ic:SetVisible(has)
            if has then ic:SetImagePath(icon, 0) end
        end)
    end
    local btn = comp("card_buy", card)
    if btn then
        local cap = button or ""
        local show = cap ~= ""
        if show and not enabled then cap = "[[col:red]]" .. cap .. "[[/col]]" end
        set_text(btn, cap)
        pcall(function()
            btn:SetVisible(show)
            btn:SetDisabled(not enabled)
        end)
    end
    set_tooltip(card, tip or "")
end

-- A character cqi to a display name. get_forename returns a loc KEY, not a name, so it
-- has to go through the stringtable - and that is a draw-time call only, which is where
-- this is. An unreadable one falls back to the post rather than printing a number.
function GGUI.patron_name(cqi)
    local ok, name = pcall(function()
        local c = cm:get_character_by_cqi(cqi)
        if not c or c:is_null_interface() then return nil end
        local fore = common.get_localised_string(c:get_forename() or "") or ""
        local sur = common.get_localised_string(c:get_surname() or "") or ""
        local full = fore
        if sur ~= "" then
            full = (fore ~= "" and (fore .. " ") or "") .. sur
        end
        if full == "" then return nil end
        return full
    end)
    if ok and name then return name end
    return GGUI.loc("patron_of")
end

-- THE COURT. Three cards: what a guild is asking of you, which lord speaks for the
-- guild on this page, and who leads it.
--
-- Cards 2 and 3 are per-guild, which is why the pager stays live on this tab - the
-- patron is appointed TO a guild, so the panel has to be showing one.
function GGUI.draw_court(faction)
    local guild = GGUI.current_guild()
    local turn = GG.turn_now()

    -- Same read-the-save-on-first-draw rule the bounty board uses: a reload mid-turn
    -- leaves these tables empty until the next turn start, and an empty table here
    -- would read as "there is no demand" rather than "nothing has been loaded".
    if GGUI.court_read ~= faction then
        GGUI.court_read = faction
        pcall(function()
            GG.load_demand(faction)
            GG.load_patron(faction)
        end)
    end

    -- ------------------------------------------------------------ the demand ---
    local d = GG.demands[faction]
    if d then
        local ok = GG.demand_payable(faction)
        local unit = (d.kind == "tribute") and GGUI.loc("demand_gold")
                     or GGUI.loc("demand_favour")
        local left = (d.due or 0) - turn
        if left < 0 then left = 0 end
        local l1 = GGUI.loc("demand_owed") .. " " .. (d.amount or 0) .. " " .. unit
        if d.kind == "renounce" and GG.RIVALS[d.guild] then
            l1 = l1 .. "  (" .. GGUI.loc_guild(GG.RIVALS[d.guild]) .. ")"
        end
        -- The deadline goes red in its last two turns. It is the only number on this
        -- panel with a point of no return behind it.
        local l2 = left .. " " .. GGUI.loc("demand_due")
        if left <= 2 then l2 = "[[col:red]]" .. l2 .. "[[/col]]" end
        local tip = GGUI.loc_guild(d.guild) .. "  -  "
                    .. GGUI.loc("demand_desc_" .. d.kind)
        if not ok then tip = tip .. "||" .. GGUI.loc("demand_short") end
        tip = tip .. "||" .. GGUI.loc("court_help")
        GGUI.write_card(1, GGUI.GUILD_ICON[d.guild],
                        GGUI.loc_guild(d.guild) .. "   "
                        .. GGUI.loc("demand_name_" .. d.kind),
                        l1, l2, tostring(d.amount or 0),
                        GGUI.loc("demand_pay"), ok == true, tip)
    else
        GGUI.write_card(1, nil, GGUI.loc("demand_none"), "", "", "", "", false,
                        GGUI.loc("court_help"))
    end

    -- ------------------------------------------------------------ the patron ---
    local p = GG.patrons[faction]
    local holds_this = p ~= nil and p.guild == guild
    if holds_this then
        GGUI.write_card(2, GGUI.GUILD_ICON[guild],
                        GGUI.loc("patron_of") .. ": " .. GGUI.loc_guild(guild),
                        GGUI.patron_name(p.cqi),
                        "+" .. (GG.setting("rate_patron") or 0) .. "% "
                        .. GGUI.loc("reputation") .. "   -"
                        .. GG.FAVOUR_PATRON .. "% " .. GGUI.loc("cost_label"),
                        "", GGUI.loc("patron_dismiss"), true,
                        GGUI.loc("court_help"))
    else
        local sel = GGUI.selected_force_cqi()
        local l2 = GGUI.loc("patron_needs_char")
        if p then l2 = GGUI.loc("patron_elsewhere") end
        GGUI.write_card(2, nil,
                        GGUI.loc("patron_of") .. ": " .. GGUI.loc_guild(guild),
                        GGUI.loc("patron_none"), l2, "",
                        GGUI.loc("patron_appoint"), sel ~= nil,
                        GGUI.loc("court_help"))
    end

    -- ---------------------------------------------------------- who leads it ---
    local who, who_rep = GG.leader_of(guild, GG.culture_of(faction))
    local line
    if who == faction then
        line = "[[col:yellow]]" .. GGUI.loc("lead_you") .. "[[/col]]"
    elseif who then
        line = GGUI.loc("lead_by") .. " " .. GGUI.faction_name(who)
    else
        line = GGUI.loc("nobody")
    end
    local mine = select(1, GG.get(faction, guild))
    GGUI.write_card(3, GGUI.GUILD_ICON[guild],
                    GGUI.loc_guild(guild) .. "   " .. GGUI.loc("lead_title"),
                    line,
                    GGUI.loc("you") .. ": " .. mine .. "   "
                    .. GGUI.loc("leader") .. ": " .. (who_rep or 0),
                    tostring(who_rep or 0), "", false,
                    GGUI.table_lines(guild, faction) .. "||"
                    .. GGUI.loc("lead_hint") .. "||" .. GGUI.loc("court_help"))
end

function GGUI.refresh()
    -- Forced local-faction read. An unforced get_local_faction_name THROWS in
    -- multiplayer, and a local-faction call at script root CTDs uncatchably.
    local ok, faction = pcall(function() return cm:get_local_faction_name(true) end)
    if not ok or not faction then return end
    if not comp(GGUI.PANEL) then return end

    -- WHAT THE RIVALS DID. GGAI writes this into the same Lua state the panel runs in,
    -- so in a live session it is already here; the read matters after a save and
    -- reload, when GG.world is back to its zeroed declaration and the Standings tab
    -- would otherwise say the world had never moved. Same idiom as the bounties, the
    -- demand and the patron, all of which the panel re-reads here.
    pcall(function() GG.load_world() end)

    GGUI.layout()
    -- The ground follows whichever guild the panel is showing, so paging the Guilds tab
    -- or picking a row on Standings changes the hall behind the text.
    GGUI.paint_ground(GGUI.ground_guild())
    set_named_text("gg_title", GGUI.loc("panel_title"))

    -- THE TAB ROW, THE PAGER AND THE BUY BUTTONS ARE BUTTONS WITH NO TEXT OF THEIR
    -- OWN. Nothing wrote a label onto any of them, so with art they would be blank
    -- plates and without art - which is how they shipped - they were invisible
    -- click targets. The active tab is marked so the row says which view is up.
    -- Indexed by GGUI.TAB, which is why the Log is last here and fifth on screen.
    local tabs = {"gg_tab_guilds", "gg_tab_stand", "gg_tab_bounty", "gg_tab_court",
                  "gg_tab_help", "gg_tab_log"}
    for i = 1, #tabs do
        local label = GGUI.loc(string.sub(tabs[i], 4))
        if i == GGUI.TAB then
            label = "[[col:yellow]]" .. label .. "[[/col]]"
        end
        set_named_text(tabs[i], label)
    end
    set_named_text("gg_prev", GGUI.loc("prev"))
    set_named_text("gg_next", GGUI.loc("next"))
    set_tooltip(comp("gg_title"), GGUI.loc("standing_help"))

    local guild = GGUI.current_guild()
    local rep, fav = GG.get(faction, guild)
    local rank = GG.rank_of(rep)
    local next_at = GG.RANKS[math.min(rank + 1, #GG.RANKS)]

    -- ONLY THE GUILDS TAB SHOWS ONE GUILD AT A TIME, so only the Guilds tab has
    -- anything for the pager to page. Standings lists all six, the bounty board pools
    -- its three offers from every guild, and Help is prose - on those three the arrows
    -- moved one word in the header and nothing else, which reads as a dead button.
    -- THE COURT PAGES TOO. Two of its three cards are about one guild - the patron is
    -- appointed to a named guild and leadership is held of a named guild - so the arrows
    -- do exactly what they do on the Guilds tab. Standings lists all six, the board
    -- pools from all six and Help is prose; on those three the arrows moved one word.
    -- THE LOG PAGES TOO, newest first, a slot-page at a time.
    local paged = (GGUI.TAB == 1 or GGUI.TAB == 4 or GGUI.TAB == 5 or GGUI.TAB == 6)
    for _, n in ipairs({"gg_prev", "gg_next"}) do
        local b = comp(n)
        if b then pcall(function() b:SetVisible(paged) end) end
    end

    if paged and GGUI.TAB == 1 then
        -- The bare "340 / 700" said nothing about WHICH number it was. Naming it is
        -- the difference between two numbers on screen and a mechanic a player can read.
        -- EVERYTHING THAT TAKES REPUTATION AWAY IS NAMED HERE, in red, because a number
        -- that falls with no visible reason is a bug report. There are two of them: the
        -- rival, and the upkeep.
        local line = GGUI.loc_guild(guild) .. "   " .. GGUI.loc_rank(rank) .. "   "
                     .. GGUI.loc("reputation") .. " " .. rep .. " / " .. next_at
        -- THE UPKEEP, and only once it is actually running. Medieval 2's whole flaw was
        -- that it charged a hidden point a turn and showed the player nothing, ever - the
        -- video's one complaint about an otherwise good mechanic. Before the grace period
        -- ends nothing is added, so the opening line is exactly what it was.
        --
        -- SHORT ON PURPOSE: this line has 750px and already carries three numbers, and a
        -- longer string on a shared line is how the Standings header clipped its rivals
        -- counter on 2026-09-12. The sentence explaining it goes in the tooltip, which
        -- wraps and has no ceiling.
        local upkeep = 0
        if rep > 0 and GG.decay_due(GG.turn_now()) then
            upkeep = GG.decay_amount(rank)
        end
        if upkeep > 0 then
            line = line .. "   [[col:red]]-" .. upkeep .. GGUI.loc("per_turn")
                   .. "[[/col]]"
        end
        local rival = GG.RIVALS[guild]
        local share = GG.setting("rate_rivalry") or 0
        if rival and share > 0 then
            line = line .. "   [[col:red]]" .. GGUI.loc("rival") .. " "
                   .. GGUI.loc_guild(rival) .. "[[/col]]"
        end
        set_named_text("gg_rank_line", line)
        -- THE GUILD'S OWN DESCRIPTION, then what the upkeep is and when it starts. Said
        -- even before it bites, so a player reads the rule in the first twenty turns
        -- rather than discovering it as a rank quietly going backwards on turn 26.
        local tip = GGUI.loc_guild_desc(guild)
        local drate = GG.setting("rate_decay") or 0
        local dfrom = GG.setting("decay_from") or 0
        if drate > 0 and dfrom > 0 then
            if upkeep > 0 then
                tip = tip .. "||" .. GGUI.loc("upkeep_on") .. " " .. upkeep .. "."
            else
                tip = tip .. "||" .. GGUI.loc("upkeep_soon") .. " " .. dfrom .. "."
            end
            tip = tip .. " " .. GGUI.loc("upkeep_help")
        end
        set_tooltip(comp("gg_rank_line"), tip)
    elseif GGUI.TAB == 5 then
        -- The Help tab's header is its table of contents: which chapter, and how many
        -- there are, so the arrows read as pages rather than as something that might
        -- change the subject.
        set_named_text("gg_rank_line",
                       GGUI.loc("hdr_help") .. "   [[col:yellow]]"
                       .. GGUI.loc("help_t" .. GGUI.HELP_PAGE) .. "[[/col]]   "
                       .. GGUI.HELP_PAGE .. " " .. GGUI.loc("help_of") .. " "
                       .. GGUI.HELP_PAGES)
        set_tooltip(comp("gg_rank_line"), GGUI.loc("standing_help"))
    elseif GGUI.TAB == 6 then
        set_named_text("gg_rank_line", GGUI.loc("hdr_log") .. "   " .. GGUI.LOG_PAGE
                       .. " " .. GGUI.loc("help_of") .. " " .. GGUI.log_pages(faction))
        set_tooltip(comp("gg_rank_line"), GGUI.loc("log_help"))
    elseif GGUI.TAB == 4 then
        -- The Court pages, but its header names the view AND the guild the arrows are
        -- pointing at, because two of its three cards are about that guild.
        set_named_text("gg_rank_line", GGUI.loc("hdr_court") .. "   "
                       .. GGUI.loc_guild(guild) .. "   " .. GGUI.loc_rank(rank)
                       .. "   " .. GGUI.loc("reputation") .. " " .. rep)
        set_tooltip(comp("gg_rank_line"), GGUI.loc("court_help"))
    else
        -- A header that names the view, not a guild the view does not show. The
        -- bounty count is live because it is the one number a player wants before
        -- reading three cards.
        local head = GGUI.loc("hdr_help")
        if GGUI.TAB == 4 then
            head = GGUI.loc("hdr_court")
        elseif GGUI.TAB == 2 then
            -- THE LEAGUE TABLE'S HEADER IS THE SCOREBOARD'S CLOCK. "The Standings" on
            -- its own said nothing about whether anybody else was playing; this line
            -- is the one place in the mod that says out loud that they are.
            head = GGUI.loc("hdr_stand") .. "   " .. GGUI.rivals_line()
        elseif GGUI.TAB == 3 then
            local list, taken = GG.bounties[faction] or {}, 0
            for i = 1, #list do
                if list[i].taken then taken = taken + 1 end
            end
            head = GGUI.loc("hdr_bounty") .. "   " .. taken .. " / "
                   .. #GGUI.CARD_XY .. " " .. GGUI.loc("bounty_taken")
        end
        set_named_text("gg_rank_line", head)
        -- The Standings header carries the rivals' line, so its hover explains that
        -- rather than repeating the general standing rules a hover away on the title.
        set_tooltip(comp("gg_rank_line"),
                    GGUI.loc(GGUI.TAB == 2 and "rivals_help" or "standing_help"))
    end
    set_named_text("gg_footer", GGUI.loc("favour") .. ": " .. fav)
    set_tooltip(comp("gg_footer"), GGUI.loc("standing_help"))

    -- The bar is the rank line's picture, so it must agree with it. SetCanResizeWidth
    -- has to be set before Resize or the call is ignored; this is the same idiom the
    -- Exchange's sparkline bars use. Resize AFTER GGUI.layout above, which MoveTo's it.
    -- THE BAR FOLLOWS THE RANK LINE, not the pager. The Court pages but draws its own
    -- header, so a bar under it would be measuring a line that is not there.
    local barred = (GGUI.TAB == 1)
    local track = comp("gg_bar_track")
    if track then pcall(function() track:SetVisible(barred) end) end
    local bar = comp("gg_rep_bar")
    if bar then
        local frac = 0
        if next_at and next_at > 0 then frac = rep / next_at end
        if frac > 1 then frac = 1 end
        if frac < 0 then frac = 0 end
        local w = math.floor(GGUI.REP_BAR_W * frac)
        pcall(function()
            -- A zero-width component is not reliably drawn as "empty", so an empty
            -- bar is hidden outright rather than resized to nothing.
            bar:SetVisible(barred and w > 0)
            if w > 0 then
                bar:SetCanResizeWidth(true)
                bar:Resize(w, GGUI.REP_BAR_H)
            end
        end)
        set_tooltip(bar, GGUI.loc_guild(guild) .. "  " .. rep .. " / " .. next_at)
    end

    -- Only one tab's widgets are visible at a time. Visibility is toggled, not
    -- destroyed: destroying and recreating on every tab click is how you end up
    -- holding a stale handle.
    -- THE BOUNTY BOARD REUSES THE THREE SERVICE CARDS. A bounty has exactly the
    -- shape a card already draws - a glyph, a name, two lines, a number and a button -
    -- and the board holds three offers because there are three cards. A fourth
    -- template would have been a second copy of the same layout to keep in step.
    local show_cards = (GGUI.TAB == 1 or GGUI.TAB == 3 or GGUI.TAB == 4)
    for i = 1, #GGUI.CARD_XY do
        local card = GGUI.card(i)
        if card then pcall(function() card:SetVisible(show_cards) end) end
    end
    for i = 1, #GG.GUILDS do
        local row = comp(GGUI.ROW .. "_" .. i, comp(GGUI.PANEL))
        if row then pcall(function() row:SetVisible(GGUI.TAB == 2) end) end
    end
    local list = comp(GGUI.LIST, comp(GGUI.PANEL))
    if list then pcall(function() list:SetVisible(GGUI.TAB == 2) end) end
    -- THE LOG DRAWS INTO THE HELP TAB'S 21 SLOTS. Both are pages of single lines, and
    -- one set of slots is one set of components to keep placed.
    for i = 1, GGUI.HELP_SLOTS do
        local h = comp(string.format("gg_help_%02d", i))
        if h then pcall(function() h:SetVisible(GGUI.TAB == 5 or GGUI.TAB == 6) end) end
    end

    if GGUI.TAB == 1 then
        local mine = GGUI.services_of(guild)
        for i = 1, #GGUI.CARD_XY do
            GGUI.draw_card(faction, i, mine[i])
        end
    elseif GGUI.TAB == 3 then
        GGUI.draw_bounties(faction)
    elseif GGUI.TAB == 2 then
        GGUI.draw_standings(faction)
    elseif GGUI.TAB == 4 then
        GGUI.draw_court(faction)
    elseif GGUI.TAB == 5 then
        GGUI.draw_help()
    elseif GGUI.TAB == 6 then
        GGUI.draw_log(faction)
    end

    -- The count changes the moment favour is spent, and the panel is open when that
    -- happens - so the badge must not wait for the next turn to catch up.
    pcall(function()
        local me = cm:get_local_faction_name(true)
        if me then GGUI.badge(me) end
    end)
end

-- The Help tab. Four pages of its own loc, "||"-separated - which is a TOOLTIP
-- convention, so on a panel each paragraph has to be wrapped into single-line
-- components, because nothing here wraps by itself.
--
-- IT NO LONGER READS derpy_gg_standing_help. It used to, and that coupling made the
-- tooltip and the tab the same words: the tooltip could not be shortened without
-- thinning the tab, which is why it was still five paragraphs on hover in the
-- 2026-09-12 build. The tab owns help_p1..4 and the tooltip owns its two sentences.
-- FOUR PAGES, NOT TWO WALLS OF PROSE. This tab used to wrap two tooltip paragraphs
-- blind into 21 single-line slots: 21 lines of unbroken text with no heading, no list
-- and nothing to navigate by - and it filled every slot, so anything added to it was
-- dropped in silence past the last one.
--
-- The loc now carries one key per page, lines joined by "||", and each line's FIRST
-- CHARACTER says what it is:
--
--   "#..."   a heading    yellow, with a blank line before it unless it opens the page
--   "-..."   a bullet     indented, with a hanging indent on its wrapped continuations
--   ""       a blank
--   other    body text    wrapped plainly
--
-- tools/gen_great_guilds.py owns the text and check_help_pages() proves every page fits
-- in HELP_SLOTS and that GGUI.HELP_PAGES below matches the number of pages it writes.
GGUI.HELP_PAGES  = 5
GGUI.HELP_PAGE   = 1
GGUI.HELP_BULLET = "  -  "
GGUI.HELP_HANG   = "     "

function GGUI.help_lines(ruler)
    local out = {}
    local function push(text)
        if #out < GGUI.HELP_SLOTS then out[#out + 1] = text end
    end

    local key = "help_p" .. GGUI.HELP_PAGE
    local text = GGUI.loc(key)
    -- GGUI.loc FALLS BACK TO THE KEY, so a missing page would draw the literal string
    -- "help_p1" as the whole tab. Say something true instead.
    if text == key or text == "" then
        push(GGUI.loc("hdr_help"))
        return out
    end

    for seg in string.gmatch(text .. "||", "(.-)||") do
        local lead = string.sub(seg, 1, 1)
        if seg == "" then
            push("")
        elseif lead == "#" then
            -- A blank line above every heading but the first: that is the whole
            -- difference between a page of blocks and a column of text.
            if #out > 0 then push("") end
            -- [[col:]] markup works in SetStateText. "yellow" is one of CA's 42 real
            -- names; a typo'd one drops the colour silently rather than erroring.
            push("[[col:yellow]]" .. string.sub(seg, 2) .. "[[/col]]")
        elseif lead == "-" then
            local wrapped = GGUI.wrap(ruler, string.sub(seg, 2), GGUI.HELP_SLOTS)
            for i = 1, #wrapped do
                push((i == 1 and GGUI.HELP_BULLET or GGUI.HELP_HANG) .. wrapped[i])
            end
        else
            local wrapped = GGUI.wrap(ruler, seg, GGUI.HELP_SLOTS)
            for i = 1, #wrapped do push(wrapped[i]) end
        end
    end
    return out
end

function GGUI.draw_help()
    local first = comp("gg_help_01")
    local lines = GGUI.help_lines(first)
    for i = 1, GGUI.HELP_SLOTS do
        set_text(comp(string.format("gg_help_%02d", i)), lines[i] or "")
    end
end

-- ------------------------------------------------------------------ the log --
-- The Log tab. GG.log_entries holds keys and numbers, written from turn handlers; this is
-- the only place they become words. Newest first, a page of the Help tab's slots at a time.
GGUI.LOG_PAGE = 1

-- One entry as plain text, and whether it is bad news. nil for a kind this build does not
-- know, so an entry written by a later version is skipped rather than drawn as keys.
function GGUI.log_text(e)
    local k, body, bad = e.kind, nil, false
    if k == "rank" then
        local was, now = tonumber(e.a) or 0, tonumber(e.b) or 0
        bad = now < was
        body = GGUI.loc(bad and "log_fell" or "log_rose") .. " " .. GGUI.loc_rank(now)
    elseif k == "buy" then
        body = GGUI.loc("log_bought") .. " " .. GGUI.loc_service(e.a) .. " (" .. e.b
               .. " " .. GGUI.loc("favour") .. ")"
    elseif k == "ai_buy" then
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_ai_bought") .. " "
               .. GGUI.loc_service(e.a)
    elseif k == "hit" then
        bad = true
        body = GGUI.loc_service(e.a) .. " " .. GGUI.loc("log_hit") .. " "
               .. GGUI.faction_name(e.b)
    elseif k == "lead_won" then
        body = GGUI.loc("log_lead_won")
        if e.a ~= "" then
            body = body .. " " .. GGUI.loc("log_from") .. " " .. GGUI.faction_name(e.a)
        end
    elseif k == "lead_lost" then
        bad = true
        body = GGUI.loc("log_lead_lost") .. " " .. GGUI.faction_name(e.a)
    else
        return nil
    end
    return GGUI.loc("log_turn") .. " " .. e.turn .. "   " .. GGUI.loc_guild(e.guild)
           .. ":  " .. body .. ".", bad
end

-- Every line the log would draw, wrapped against `ruler`. THE COLOUR GOES ON AFTER THE
-- WRAP, one pair of tags per line: GGUI.wrap splits on spaces, so a [[col:]] opened on
-- one line and closed on the next would be a guess about the renderer.
function GGUI.log_lines(me, ruler)
    local out = {}
    local entries = GG.log_entries(me)
    for i = 1, #entries do
        local text, bad = GGUI.log_text(entries[i])
        if text then
            local wrapped = GGUI.wrap(ruler, text, 3)
            if #wrapped == 0 then wrapped = {text} end
            for j = 1, #wrapped do
                local line = (j == 1 and "" or GGUI.HELP_HANG) .. wrapped[j]
                if bad then line = "[[col:red]]" .. line .. "[[/col]]" end
                out[#out + 1] = line
            end
        end
    end
    -- AN EMPTY LOG SAYS WHAT WILL APPEAR IN IT. The first Log tab drew nothing at all,
    -- which is why it was removed.
    if #out == 0 then out[1] = GGUI.loc("log_empty") end
    return out
end

function GGUI.log_pages(me)
    local n = #GGUI.log_lines(me, comp("gg_help_01"))
    return math.max(1, math.ceil(n / GGUI.HELP_SLOTS))
end

function GGUI.draw_log(me)
    local lines = GGUI.log_lines(me, comp("gg_help_01"))
    local pages = math.max(1, math.ceil(#lines / GGUI.HELP_SLOTS))
    if GGUI.LOG_PAGE > pages then GGUI.LOG_PAGE = pages end
    local from = (GGUI.LOG_PAGE - 1) * GGUI.HELP_SLOTS
    for i = 1, GGUI.HELP_SLOTS do
        set_text(comp(string.format("gg_help_%02d", i)), lines[from + i] or "")
    end
end

-- The Standings league table. Returns KEYS, not display names - the row resolves
-- a key to a name at draw time, never in a handler.
function GGUI.leaders(me)
    local rows = {}
    for gi = 1, #GG.GUILDS do
        -- The rule lives in GG.leader_of: reputation above zero to be named at all, and
        -- a stable tie-break. This used to start from -1 and crown whichever faction
        -- pairs() yielded first, which in a young campaign is the only one in
        -- GG.state - so the player led all six guilds at 0 reputation.
        local guild = GG.GUILDS[gi]
        local best, best_rep = GG.leader_of(guild, GG.culture_of(me))
        rows[#rows + 1] = {guild = guild, faction_key = best,
                           rank = GG.rank_of(best_rep or 0), rep = best_rep or 0}
    end
    return rows
end

-- WHAT THE RIVALS DID LAST ROUND, in one line. GG.world is written once a round by
-- GGAI.run_turn from the calls that actually did the work, so these are counts of real
-- actions and not an estimate made by a second scan that could drift from them.
--
-- Three numbers and no more: the line shares gg_rank_line's 750px with the tab's own
-- header, and a fourth would push it past what fits.
function GGUI.rivals_line()
    local w = GG.world
    if not w or (w.turn or 0) == 0 then return GGUI.loc("rivals_idle") end
    return GGUI.loc("rivals") .. " " .. (w.bought or 0) .. " "
           .. GGUI.loc("rivals_bought") .. ", " .. (w.demands or 0) .. " "
           .. GGUI.loc("rivals_demands") .. ", " .. (w.patrons or 0) .. " "
           .. GGUI.loc("rivals_patrons")
end

-- THE LEAGUE TABLE FOR ONE GUILD, as tooltip lines. Five names and no more: a tooltip
-- that runs past the screen is worse than a short one, and five is enough to see whether
-- you are in the race or watching it.
--
-- THE PLAYER'S OWN ROW IS ALWAYS PRESENT, appended when it falls outside the top five -
-- otherwise the one reader of this table is the one faction it can fail to mention.
GGUI.TABLE_ROWS = 5

function GGUI.table_lines(guild, me)
    -- CONTENDERS, not standings: the rivals are in the campaign long before any of them
    -- banks a reputation point, and a hover that lists only earners is blank for the
    -- first stretch of every campaign. Leadership still reads GG.standings.
    local rows = GG.contenders(guild, GG.culture_of(me))
    if #rows == 0 then return GGUI.loc("nobody") end
    local out = GGUI.loc("table_head")
    local shown = 0
    local saw_me = false
    for i = 1, #rows do
        if shown >= GGUI.TABLE_ROWS then break end
        local r = rows[i]
        local who = (r.faction == me) and GGUI.loc("you") or GGUI.faction_name(r.faction)
        local line = r.pos .. ". " .. who .. "  " .. r.rep .. " ("
                     .. GGUI.loc_rank(GG.rank_of(r.rep)) .. ")"
        -- YELLOW ON YOUR OWN ROW. Six lines of faction names with one of them being you
        -- is exactly the list a player reads three times without finding themselves.
        if r.faction == me then
            line = "[[col:yellow]]" .. line .. "[[/col]]"
            saw_me = true
        end
        out = out .. "||" .. line
        shown = shown + 1
    end
    if #rows > shown then
        out = out .. "||+" .. (#rows - shown) .. " " .. GGUI.loc("more")
    end
    if not saw_me then
        local pos, total = GG.position_of(me, guild)
        if pos then
            out = out .. "||[[col:yellow]]" .. pos .. ". " .. GGUI.loc("you")
                  .. "  " .. select(1, GG.get(me, guild)) .. "  (" .. pos .. "/"
                  .. total .. ")[[/col]]"
        else
            out = out .. "||[[col:yellow]]" .. GGUI.loc("you") .. ": "
                  .. GGUI.loc("unranked") .. "[[/col]]"
        end
    end
    return out
end

-- WHERE YOU SIT, in the four characters a 204px column has room for. "4/9" answers the
-- question the Standings tab was built to answer and never did: the leader's name says
-- who is winning and nothing at all about whether you are second or last.
function GGUI.position_tag(faction, guild)
    local pos, total = GG.position_of(faction, guild)
    if not pos then return "" end
    return "  " .. pos .. "/" .. total
end

-- ONE FACTION, ONE LINE, and the crest is INSIDE the line rather than beside it.
--
-- [[img:<full path>]][[/img]] draws a picture inside a string - measured across CA's own
-- loc (156 distinct full paths) and built from Lua in CA's own wh3_dlc26_ogre_camps.lua,
-- so this is not a loc-only feature. It is used here because a row in a SCROLLING list
-- cannot have children: every child in this panel is placed by absolute MoveTo, the
-- engine moves a scrolled row without raising anything, and the child would be left
-- hanging in the middle of the panel while its row travelled on.
--
-- The colour tags wrap only the text. Nesting them around the [[img:]] pair would be a
-- guess about how the renderer handles overlapping markup, and an unknown colour name is
-- consumed silently rather than erroring - so a nesting mistake would be invisible.
function GGUI.frow_text(r, me)
    local flag = GG.FLAG_OF[r.faction]
    local img = (type(flag) == "string" and flag ~= "")
                and (flag .. "/mon_24.png") or GGUI.FLAG_FALLBACK
    local who = (r.faction == me) and GGUI.loc("you") or GGUI.faction_name(r.faction)
    local body = r.pos .. ".  " .. who .. "   " .. r.rep .. "   "
                 .. GGUI.loc_rank(GG.rank_of(r.rep))
    if r.faction == me then
        body = "[[col:yellow]]" .. body .. "[[/col]]"
    end
    return "[[img:" .. img .. "]][[/img]]  " .. body
end

-- WHICH GUILD THE LIST IS SHOWING. Clamped rather than trusted: GGUI.STAND_GUILD is set
-- from a component name at click time, and a guild list that shrank under a saved index
-- would otherwise index nil and take the whole draw down with it.
function GGUI.stand_guild()
    local i = GGUI.STAND_GUILD
    if type(i) ~= "number" or i < 1 or i > #GG.GUILDS then i = 1 end
    return GG.GUILDS[i], i
end

-- WHO GOES IN THE LIST, split out from the drawing so it can be tested at all. With no
-- panel on screen every comp() lookup is nil and the draw below returns before it reaches
-- anything worth asserting on - so a version of this that listed the whole world instead
-- of one culture would have passed every test.
--
-- THE CULTURE IS THE POINT. "Only same culture, not 127 factions" is the request this
-- list was built from; GG.contenders filters on it, and passing nil here is the one edit
-- that turns a league table into a phone book.
function GGUI.list_rows(faction)
    local guild = GGUI.stand_guild()
    return GG.contenders(guild, GG.culture_of(faction)), guild
end

-- HOW MANY ROWS THE LAST DRAW BUILT. Written before the first component lookup, so a
-- harness with no panel can still tell "the draw ran and found nothing" apart from "the
-- draw was never reached" - which is the difference between a working list and one whose
-- call was quietly dropped out of draw_standings.
GGUI.LIST_LAST = 0

-- THE LIST ITSELF. Rebuilt from nothing on every draw rather than hidden and reused: a
-- hidden child still occupies a slot in some layout engines, which would leave gaps
-- wherever a faction died, and this panel already re-finds every component every time
-- rather than caching handles.
function GGUI.draw_faction_list(faction)
    local rows, guild = GGUI.list_rows(faction)
    GGUI.LIST_LAST = #rows

    local list = comp(GGUI.LIST, comp(GGUI.PANEL))
    if not list then return end
    local box = comp("list_box", list)
    if not box then return end
    pcall(function() box:DestroyChildren() end)

    for i = 1, #rows do
        local name = GGUI.FROW .. "_" .. i
        local ok = pcall(function() box:CreateComponent(name, GGUI.PATH_FROW) end)
        local fr = ok and comp(name, box) or nil
        if fr then
            set_text(fr, GGUI.frow_text(rows[i], faction))
            set_tooltip(fr, GGUI.loc_guild(guild) .. "  "
                        .. GGUI.faction_name(rows[i].faction))
        end
    end
    -- Force the list layout to run now. Without it the rows created above are stacked at
    -- the box's origin until something else happens to trigger a relayout.
    pcall(function() box:Layout() end)
end

function GGUI.draw_standings(faction)
    local leaders = GGUI.leaders(faction)
    local w = GG.world or {}
    for i = 1, #leaders do
        local L = leaders[i]
        local row = comp(GGUI.ROW .. "_" .. i, comp(GGUI.PANEL))
        if row then
            local rep = select(1, GG.get(faction, L.guild))
            -- THE SELECTED ROW IS THE ONE THE LIST BELOW IS ABOUT. Without a mark the
            -- list changes when a row is clicked and nothing on screen says which row
            -- did it.
            local _sel_guild, sel_i = GGUI.stand_guild()
            local label = GGUI.loc_guild(L.guild)
            if i == sel_i then
                label = "[[col:yellow]]" .. label .. "[[/col]]"
            end
            set_text(comp("row_guild", row), label)
            -- LABELLED, because the row had three naked fragments in it: the guild,
            -- a rank with a number after it, and a second rank belonging to somebody
            -- else. Nothing said which of the two ranks was yours.
            set_text(comp("row_rank", row),
                     GGUI.loc("you") .. ": " .. GGUI.loc_rank(GG.rank_of(rep))
                     .. " (" .. rep .. ")" .. GGUI.position_tag(faction, L.guild))
            local who = L.faction_key
            if who == faction then
                -- "Leader: You" and nothing else: the rank is already in the column
                -- to the left, and printing it twice was half the confusion.
                who = GGUI.loc("you")
            elseif who then
                who = GGUI.faction_name(who) .. " (" .. GGUI.loc_rank(L.rank) .. ")"
            else
                -- Nobody has any standing with this guild yet, so nobody leads it.
                who = GGUI.loc("nobody")
            end
            -- YELLOW WHEN THE GUILD CHANGED HANDS ON THE ROUND JUST PAST. A name that
            -- is merely different from the last time you opened the panel says nothing
            -- about when it changed; the mark is the difference between a scoreboard
            -- and a scoreboard you can watch. [[col:]] works in SetStateText and
            -- "yellow" is one of CA's 42 real colour names.
            local slot = GG.lead_slot(L.guild, GG.culture_of(faction))
            if w.moved and w.moved[slot] then
                who = "[[col:yellow]]" .. who .. "[[/col]]"
            end
            -- AND WHAT THE LEADER GAINED ON IT. This is the race's speed: a rival
            -- pulling away shows a number every round whether or not the name above it
            -- ever changes. Usually positive, because earning only adds - but a
            -- rivalry drain, a penalty or an expired demand can take it back, so the
            -- sign is read rather than assumed. Zero prints nothing rather than "+0",
            -- which is clutter on six rows.
            local gain = (w.gain or {})[slot] or 0
            if gain ~= 0 then
                who = who .. (gain > 0 and "   [[col:green]]+" or "   [[col:red]]")
                      .. gain .. "[[/col]]"
            end
            set_text(comp("row_leader", row), GGUI.loc("leader") .. ": " .. who)
            -- The league table is where a player decides which guild to chase, so
            -- each row carries what that guild is and what its ladder pays - and, when
            -- there is movement to explain, what the marks on it mean.
            -- THE TABLE FIRST, then what the guild is. The row already says who
            -- leads and where you sit; the hover is the only place with room for the
            -- names between you, which is the whole of what a scoreboard is for.
            local tip = GGUI.table_lines(L.guild, faction) .. "||"
                        .. GGUI.loc_guild_desc(L.guild)
            if w.moved and w.moved[slot] then
                tip = tip .. "||" .. GGUI.loc_guild(L.guild) .. " "
                      .. GGUI.loc("took")
            end
            if gain ~= 0 then
                tip = tip .. "||" .. GGUI.loc("leader") .. " "
                      .. GGUI.loc("gained") .. " " .. gain .. " "
                      .. GGUI.loc("reputation")
            end
            set_tooltip(row, tip)
        end
    end
    GGUI.draw_faction_list(faction)
end

-- A faction KEY to a display name. Loc, so draw time only.
function GGUI.faction_name(key)
    local ok, s = pcall(function()
        return common.get_localised_string("factions_screen_name_" .. key)
    end)
    if ok and s and s ~= "" then return s end
    return key
end

-- WHICH COUNTER THE ARROWS WRITE TO. The Help tab pages CHAPTERS and the Guilds and
-- Court tabs page GUILDS. One shared counter would mean reading the help moved the guild
-- you had been looking at, and a help page numbered 6 with four chapters in it.
function GGUI.page_now()
    if GGUI.TAB == 5 then return GGUI.HELP_PAGE end
    if GGUI.TAB == 6 then return GGUI.LOG_PAGE end
    return GGUI.PAGE
end

function GGUI.page_max()
    if GGUI.TAB == 5 then return GGUI.HELP_PAGES end
    if GGUI.TAB == 6 then
        local ok, me = pcall(function() return cm:get_local_faction_name(true) end)
        return GGUI.log_pages(ok and me or nil)
    end
    return #GGUI.GUILD_ORDER
end

function GGUI.set_page(n)
    if n < 1 then n = 1 end
    if n > GGUI.page_max() then n = GGUI.page_max() end
    if GGUI.TAB == 5 then
        GGUI.HELP_PAGE = n
    elseif GGUI.TAB == 6 then
        GGUI.LOG_PAGE = n
    else
        GGUI.PAGE = n
    end
    GGUI.refresh()
end

function GGUI.set_tab(n)
    GGUI.TAB = n
    GGUI.refresh()
end

-- EVERY TARGETED SERVICE TAKES WHATEVER THE PLAYER HAS SELECTED, and the campaign map
-- is the picker. The panel builds no picker of its own: the map already has a good one,
-- CA's own targeted abilities work this way, and a nil target is a refusal the card
-- states in words rather than a payload fired blind.
--
-- ALL FIVE ARE COVERED NOW. Research and building were the last two without a source,
-- and both had one - it was in a place neither the signature nor the obvious member list
-- pointed at. See GG.research_target and GGUI.selected_building_upgrade.
-- WHICH SELECTION THIS SERVICE WANTS. One string used to answer for all of them, and
-- it said "select an enemy character on the campaign map" - which is right for The
-- Khan's Price and wrong for the other four. Hire the Immortals wants one of YOUR
-- armies, and a player told to select an enemy and then refused for doing exactly that
-- has been sent to debug the mod.
function GGUI.target_hint(s)
    if not s then return "needs_target" end
    if s.hostile then return "needs_target" end
    if s.kind == "unit" then return "needs_army" end
    if s.kind == "shroud" then return "needs_region_any" end
    if s.kind == "building" then return "needs_region_own" end
    if s.kind == "research" then return "needs_research" end
    return "needs_target"
end

function GGUI.pick_target(s, faction)
    if not s then return nil end
    if s.hostile then return GGUI.selected_enemy_faction() end
    if s.kind == "unit" then return GGUI.selected_force_cqi() end
    -- WHATEVER SETTLEMENT IS SELECTED. cm:get_campaign_ui_manager() documents
    -- get_selected_settlement_region(), so the shroud service has a real target source
    -- and the map's own selection is the picker - the same idiom the two above use.
    if s.kind == "shroud" then return GGUI.selected_region() end
    -- WHAT THE FACTION IS ALREADY RESEARCHING. No member of the faction interface names
    -- the subject, but ResearchStarted's context carries the key and the model records
    -- it - so the player picks the technology the ordinary way, in the tech tree, and
    -- this service finishes it.
    if s.kind == "research" then return GG.research_target(faction) end
    if s.kind == "building" then return GGUI.selected_building_upgrade(faction) end
    return nil
end

-- THE FIRST LEGAL UPGRADE IN THE SELECTED REGION, as the {slot, building} pair the
-- payload wants. cm:region_slot_instantly_upgrade_building needs a slot interface AND a
-- building key that is a legal upgrade for the chain standing in that slot, and the
-- legality lives in building_upgrades_junction, which no script interface exposes - so
-- this looked like it needed a copy of that table baked into the pack.
--
-- IT DOES NOT. cm:get_building_level_upgrades(key) returns "a lua table containing a
-- list of building keys that are upgrades from a supplied building key", empty when
-- there are none. CA's own prologue achievement script walks settlements with exactly
-- this call, which is where the idiom below comes from -
-- region:settlement():primary_slot():building():name().
--
-- THE PRIMARY SLOT IS TRIED FIRST, because the settlement chain is what raising a
-- ziggurat means and it is the tier gate every other slot in the region is capped by.
-- The rest of the settlement's slots are the fallback, so a region already at its
-- maximum tier still has something to sell.
function GGUI.selected_building_upgrade(faction)
    local key = GGUI.selected_region()
    if not key or not faction then return nil end
    local ok, out = pcall(function()
        -- cm:get_region returns FALSE, not nil, for a region key it does not know.
        local r = cm:get_region(key)
        if not r or r:is_null_interface() then return nil end
        -- YOUR OWN REGION ONLY. Upgrading a building for the faction that owns it is a
        -- gift to whoever holds the settlement, and the map's selection happily lands
        -- on someone else's city.
        if r:owning_faction():name() ~= faction then return nil end
        local st = r:settlement()
        if not st or st:is_null_interface() then return nil end
        local ordered = {st:primary_slot()}
        local slots = st:slot_list()
        for i = 0, slots:num_items() - 1 do
            ordered[#ordered + 1] = slots:item_at(i)
        end
        for i = 1, #ordered do
            local sl = ordered[i]
            if sl and not sl:is_null_interface() and sl:has_building() then
                local b = sl:building()
                if b and not b:is_null_interface() then
                    local ups = cm:get_building_level_upgrades(b:name())
                    -- AN EMPTY TABLE IS THE DOCUMENTED "no upgrades" ANSWER, and a key
                    -- that names no building returns nothing at all - so the type is
                    -- checked before the index.
                    if type(ups) == "table" and type(ups[1]) == "string" then
                        return {slot = sl, building = ups[1]}
                    end
                end
            end
        end
        return nil
    end)
    if ok then return out end
    return nil
end

function GGUI.selected_region()
    local ok, key = pcall(function()
        -- A PLAIN STRING, AND A REGION KEY - despite CA's doc calling it "the string
        -- name of the region". Read out of their own lib_campaign_ui: the value is set
        -- from gr:region():name() on SettlementSelected, and region:name() is the key
        -- that make_region_visible_in_shroud asks for. Blank when nothing is selected.
        -- Checked in the source because "name" has meant "key" twice in this workspace
        -- already, and the wrong guess here is a service that silently does nothing.
        local r = cm:get_campaign_ui_manager():get_selected_settlement_region()
        if type(r) ~= "string" or r == "" then return nil end
        return r
    end)
    if ok then return key end
    return nil
end

-- WHO IS SELECTED ON THE CAMPAIGN MAP, as a character cqi.
--
-- THE MEMBER IS get_char_selected_cqi. It was get_char_selected, which
-- campaign_ui_manager does not have - CA's lib_campaign_ui.lua declares exactly one
-- get_char member and check_lua_api.py could not see this one because the receiver is a
-- call expression (`cm:get_campaign_ui_manager()`) and not `cm` itself. The pcall turned
-- the missing method into a permanent nil, and three things were dead from the day they
-- shipped: Appoint Patron (its button is gated on this being non-nil, so it was greyed
-- forever), Hire the Immortals, and The Khan's Price through GGUI.selected_enemy_faction.
--
-- THREE STATES, NOT TWO. CA's field starts nil and CharacterDeselected sets it to -1
-- rather than clearing it, so a bare nil test hands the payload character -1 - an
-- unvalidated key that fails forever in silence.
--
-- cm:get_campaign_ui_manager() itself can return FALSE: campaign_ui_manager:new()
-- refuses to build one after the UI is up. CA creates it during startup so this should
-- not happen, and a guard is cheaper than finding out that it did.
function GGUI.selected_force_cqi()
    local ok, cqi = pcall(function()
        local uim = cm:get_campaign_ui_manager()
        if not uim then return nil end
        local c = uim:get_char_selected_cqi()
        if type(c) ~= "number" or c <= 0 then return nil end
        return c
    end)
    if ok then return cqi end
    return nil
end

-- WHOEVER IS SELECTED ON THE CAMPAIGN MAP, as long as it is not you. The panel has no
-- faction picker and building one is a larger job than this one service is worth - the
-- map already has a perfectly good one, and CA's own targeted abilities work this way.
--
-- Returning nil is a refusal, not a fallback: GG.buy now declines a hostile service with
-- no target rather than putting the malus on the buyer.
function GGUI.selected_enemy_faction()
    local ok, key = pcall(function()
        local cqi = GGUI.selected_force_cqi()
        if not cqi then return nil end
        local c = cm:get_character_by_cqi(cqi)
        if not c or c:is_null_interface() then return nil end
        local f = c:faction()
        if not f or f:is_null_interface() then return nil end
        return f:name()
    end)
    if not ok or not key then return nil end
    local me = nil
    pcall(function() me = cm:get_local_faction_name(true) end)
    if me and key == me then return nil end
    return key
end

-- ----------------------------------------------------------- interaction ---

core:add_listener("gg_clicks", "ComponentLClickUp", true, function(context)
    local id = context.string
    if not id then return end

    if id == "gg_close" then
        GGUI.close()
    elseif id == "gg_next" then
        GGUI.set_page(GGUI.page_now() + 1)
    elseif id == "gg_prev" then
        GGUI.set_page(GGUI.page_now() - 1)
    elseif id == "gg_tab_guilds" then
        GGUI.set_tab(1)
    elseif id == "gg_tab_stand" then
        GGUI.set_tab(2)
    elseif id == "gg_tab_bounty" then
        GGUI.set_tab(3)
    elseif id == "gg_tab_court" then
        GGUI.set_tab(4)
    elseif id == "gg_tab_help" then
        GGUI.set_tab(5)
    elseif id == "gg_tab_log" then
        -- Newest first, so opening the tab always lands on what just happened.
        GGUI.LOG_PAGE = 1
        GGUI.set_tab(6)
    elseif string.match(id, "^derpy_gg_row_%d+$") then
        -- Which guild the faction list below is about. The row index IS the guild index:
        -- GGUI.leaders() builds its six rows in GG.GUILDS order.
        local n = tonumber(string.match(id, "(%d+)$"))
        if n then
            GGUI.STAND_GUILD = n
            GGUI.refresh()
        end
    elseif id == "card_buy" then
        GGUI.on_buy_click(context)
    elseif id == "gg_opener" then
        if comp(GGUI.PANEL) then GGUI.close() else GGUI.open() end
    end
end, true)

function GGUI.on_buy_click(context)
    local ok, faction = pcall(function() return cm:get_local_faction_name(true) end)
    if not ok or not faction then return end
    -- One button, two meanings, because one card template serves both tabs.
    local is_bounty = (GGUI.TAB == 3)
    local is_court = (GGUI.TAB == 4)
    -- Which card was clicked: walk up to the card, read its index off its name.
    local slot = nil
    local okp, parent_name = pcall(function()
        -- UIComponent TWICE, and that is not a typo. :Parent() hands back a component
        -- ADDRESS, not a uicomponent, so calling :Id() straight off it throws - and
        -- inside this pcall that threw silently, leaving slot nil and every Buy and
        -- Take in the panel dead while the click itself registered fine. The Zharr
        -- Exchange writes the same two-step walk for the same reason.
        return UIComponent(UIComponent(context.component):Parent()):Id()
    end)
    if okp and parent_name then
        slot = tonumber(string.match(parent_name, "_(%d+)$"))
    end
    if not slot then return end
    if is_bounty then
        if GG.take_bounty(faction, slot) then
            GG.save_bounties(faction)
        end
        GGUI.refresh()
        return
    end
    if is_court then
        -- Slot 1 pays the demand, slot 2 appoints or dismisses the patron, slot 3 is
        -- the leadership card and has no button at all.
        if slot == 1 then
            if GG.pay_demand(faction) then
                GG.save_demand(faction)
                GG.save(faction)
            end
        elseif slot == 2 then
            local guild = GGUI.current_guild()
            local p = GG.patrons[faction]
            if p and p.guild == guild then
                GG.clear_patron(faction)
            else
                GG.set_patron(faction, guild, GGUI.selected_force_cqi())
            end
            GG.save_patron(faction)
        end
        GGUI.refresh()
        return
    end
    local mine = GGUI.services_of(GGUI.current_guild())
    local s = mine[slot]
    if not s then return end
    GG.buy(faction, s.key, GGUI.pick_target(s, faction))
    GG.save(faction)
    GGUI.refresh()
end

-- ---------------------------------------------------------------- opener ---
-- WHERE THE BUTTON GOES, and why it is not parented to anything on the HUD.
--
-- The first version did `find_uicomponent(root, "button_rituals"):CreateComponent(...)`
-- and never called MoveTo. It drew nothing. Both halves were wrong, and the Zharr
-- Exchange had already paid for both lessons - see the block above EX.place_button
-- in zzz_derpy_chd_exchange.lua:
--
--   1. button_rituals is one member of a RadialList (starting_angle 3.64773798,
--      radius 95) declared in ui3.pack/ui/campaign ui/hud_campaign.twui.xml. A
--      LAYOUT GROUP OWNS ITS CHILDREN'S POSITIONS. MoveTo does not lose a fight
--      with a layout engine, it never gets to have one - the child becomes an
--      extra slot on the Chaos Dwarf ring and CA re-lays it out every pass.
--   2. Nothing positioned it at all, and dockpoint is ignored on a runtime
--      component, so even off a plain parent it sat at the parent's origin.
--
-- So: created on the UI ROOT, which holds no LayoutEngine and is always present.
-- The strip is a RULER, read for coordinates only, never a parent.
-- THE LOG CHANNEL. This file used to emit nothing at all, and that is exactly why
-- the opener bug cost a round trip: "there is no button" could not be told apart
-- from never-created, created-off-screen, or created-and-then-moved-by-a-parent.
-- One line per placement, the same shape the Zharr Exchange prints.
GGUI.TAG = "GREAT GUILDS: "

function GGUI.say(msg)
    pcall(function() out(GGUI.TAG .. msg) end)
end

GGUI.BTN      = "gg_opener"
GGUI.BTN_SIZE = 44          -- must match OPENER_W/H in tools/gen_guilds_ui.py

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

GGUI.BTN_GAP  = 4
GGUI.BTN_TRIES = 12
GGUI.btn_at = nil           -- set once placed; stops the retry chain for good

-- Dimensions(), NOT Bounds(). Bounds() is the extent INCLUDING children, so while
-- the HUD is still settling the root's bounds balloon past the real display and an
-- on-screen guard asking that question passes a position that is off the screen.
-- CA's own core:get_screen_resolution() is literally ui_root:Dimensions().
local function screen()
    return core:get_screen_resolution()
end

-- UNDER the resource strip's left end.
--
-- OFF ITS LEFT END WAS WRONG, and being on-screen was not enough. Measured from the
-- Zharr Exchange's own log line on this machine - "opener button at 1396,2
-- (resources_bar)", which is bx+bw+4 - the strip ends at x=1392, so its left edge is
-- near x=373 and a button parked at 325,4 lands UNDERNEATH CA's top-left button
-- cluster, which occupies roughly x 0..460 of the top row and draws over us. The
-- button was placed, on-screen, and invisible.
--
-- The Exchange gets away with the RIGHT end because that side is clear. Rather than
-- take the mirror of a spot that only works on one side, this drops one row DOWN,
-- which is open on every layout and is independent of screen width - so it cannot
-- collide with the Exchange's button either, whichever mods are installed.
--
-- resources_bar is THE ART; resources_bar_holder is a box that neither contains nor
-- aligns with it (measured 1920x1080: holder 564,0 792x67 against bar 431,-4
-- 1019x60 - the art overhangs its parent on both sides). Anchor to the art.
-- WHERE THE OPENER SITS, and why it depends on another mod being installed.
--
-- Asked for from play: to the LEFT of the Zharr Exchange's button when that mod is
-- present,
-- and IN ITS PLACE when it is not. Both positions are derived from resources_bar
-- using the Exchange's own arithmetic - they are NOT read off its live button.
--
-- That is deliberate. The Exchange's own notes record its button teleporting 133px
-- because a fallback resolved to different geometry while the real anchor was still
-- loading, and its rule from that is: never let "not ready yet" produce a different
-- place. Its button retries across several seconds, so a live read of it is exactly
-- that hazard. Two formulas over the same anchor cannot disagree; a read of a
-- component that is still moving can.
--
-- EX is a global in this same Lua state from the moment the Exchange's script loads,
-- long before any HUD placement, so it is a stable install test with no race -
-- unlike asking whether its button component exists yet, which is false for the
-- first few seconds of every campaign whether or not the mod is installed.
function GGUI.btn_anchor()
    local bar = find_uicomponent(core:get_ui_root(), "resources_bar")
    if not is_uicomponent(bar) then return nil end
    local bx, by = bar:Position()
    -- Dimensions(), NOT Bounds(): Bounds() includes children and this strip is full
    -- of them.
    local bw, bh = bar:Dimensions()
    -- REFUSE AN UNSETTLED STRIP. resources_bar is ANIMATED: it slides in at campaign
    -- load and leaves the top of the screen for cutscenes and end-turn, reporting a
    -- far-negative y while it is away. Read mid-slide on this machine it answered
    -- by = -64 with bh = 60, and the button was placed at 489,0 - on-screen, so every
    -- guard downstream passed it, and sitting on top of the resource strip. Settled
    -- it sits at by = -4. An off-screen READ is not the same as an off-screen RESULT,
    -- which is why the clamp downstream could not catch this; here is the only place
    -- it can be caught.
    if by < -GGUI.BTN_SIZE then return nil, nil, "unsettled" end

    -- The Exchange parks off the RIGHT end of the strip, vertically centred on it.
    -- Its two constants are read from EX when it is loaded so a change there cannot
    -- silently drift this; the literals are only the uninstalled case, and
    -- gen_guilds_ui.check() pins them against the Exchange's shipped script.
    -- ex_size IS UNREAD, AND IT STAYS. gen_guilds_ui.check() pins these two fallback
    -- literals with a regex anchored on the line that follows this one, so deleting it
    -- disarms that check silently instead of breaking it loudly.
    local ex_size = (EX and EX.BUTTON_SIZE) or 48
    local ex_gap = (EX and EX.BUTTON_GAP) or 4
    local slot_x = bx + bw + ex_gap
    -- Our own vertical centring on the strip, NOT the Exchange's: its button is
    -- 48px and ours is 44, so centring on its box would leave the pair 2px out of
    -- line. Both are centred on the same strip instead, which is what makes them
    -- read as one row.
    local row_y = by + math.floor((bh - GGUI.BTN_SIZE) / 2)

    if EX and EX.BUTTON then
        -- Immediately to its LEFT, along the same row. Left means our right edge
        -- stops one gap short of the Exchange's left edge, so the offset is our own
        -- width - not the Exchange's, which is the easy way to overlap it.
        return slot_x - GGUI.BTN_SIZE - ex_gap, row_y,
               string.format("left of the exchange button, bar %d,%d %dx%d",
                             bx, by, bw, bh)
    end
    -- No Exchange installed: take the slot it would have used.
    return slot_x, row_y,
           string.format("in the exchange slot, bar %d,%d %dx%d", bx, by, bw, bh)
end

function GGUI.place_opener(attempt)
    attempt = attempt or 1
    local root = core:get_ui_root()
    local sw, sh = screen()

    -- Every "not ready" branch routes through here so the chain cannot be given up
    -- on in one place and kept alive in another. Stops on the first success.
    local function retry()
        if GGUI.btn_at or attempt >= GGUI.BTN_TRIES then return false end
        cm:callback(function() GGUI.place_opener(attempt + 1) end, 2.0,
                    "gg_place_opener_" .. attempt)
        return true
    end

    -- CREATION retries too. The HUD is not built when the first callback runs, so a
    -- one-shot create silently does nothing forever.
    local b = comp(GGUI.BTN)
    if not is_uicomponent(b) then
        pcall(function() root:CreateComponent(GGUI.BTN, GGUI.PATH_OPENER) end)
        b = comp(GGUI.BTN)
    end
    if not is_uicomponent(b) then retry() return end

    -- Recomputed every call, never cached: a wrong early read then heals itself
    -- instead of being made permanent.
    local x, y, how = GGUI.btn_anchor()
    if not x then
        if not retry() and not GGUI.btn_at then
            GGUI.say("GAVE UP - no usable resources_bar reading (" ..
                     tostring(how or "absent") .. ")")
        end
        return
    end

    -- CLAMP A SMALL OVERSHOOT, REFUSE A WILD ONE. resources_bar is ANIMATED - it
    -- slides off the top for the intro, cutscenes and end-turn, reporting y far
    -- negative while away. But a flat "y < 0" refusal is also wrong: some cultures
    -- sit a few pixels higher and settle at y = -5, and refusing those leaves the
    -- mod with no way in at all. Within one button of the screen is a real anchor
    -- merely poking out.
    local tol = GGUI.BTN_SIZE
    if x < -tol or y < -tol or x + GGUI.BTN_SIZE > sw + tol
       or y + GGUI.BTN_SIZE > sh + tol then
        if not retry() and not GGUI.btn_at then
            GGUI.say("GAVE UP - resources_bar put the button at " .. x .. "," .. y
                     .. " on a " .. sw .. "x" .. sh .. " screen, too far out to clamp")
        end
        return
    end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x + GGUI.BTN_SIZE > sw then x = sw - GGUI.BTN_SIZE end
    if y + GGUI.BTN_SIZE > sh then y = sh - GGUI.BTN_SIZE end

    b:MoveTo(x, y)
    b:SetVisible(true)
    -- The button is created on the UI root, which does NOT put it in front of the
    -- HUD - hud_campaign draws over it. Being on-screen is not the same as being
    -- visible, and that difference is what the first attempt lost a round trip to.
    pcall(function() b:RegisterTopMost() end)
    set_tooltip(b, GGUI.loc("panel_title") .. "||" .. GGUI.loc("standing_help"))

    -- READ IT BACK. This is the check that catches a layout engine on day one
    -- instead of costing a screenshot and a wrong fix: if the position we asked for
    -- is not the position we got, something else is laying this component out and no
    -- amount of MoveTo will win. Nothing else in the engine reports that - the
    -- button simply appears somewhere else, or nowhere.
    local ax, ay = b:Position()
    if ax == x and ay == y then
        -- Logged once, on the transition, so a re-run from FactionTurnStart does not
        -- write a line every turn.
        -- Logged on the transition AND whenever the position changes, so a
        -- correction at turn start is visible instead of silent.
        local now = x .. "," .. y
        if GGUI.btn_at ~= now then
            GGUI.say("opener button at " .. now .. " on a " .. sw .. "x" .. sh
                     .. " screen, " .. tostring(how))
        end
        GGUI.btn_at = now
    else
        -- Do not mark it placed: leave the chain free to try again.
        GGUI.say("MoveTo OVERRIDDEN - asked " .. x .. "," .. y .. " got "
                 .. ax .. "," .. ay .. ", the parent is laying this component out")
    end
end

-- Placement starts at first tick and is re-run at turn start. Both are one-shots
-- into the same chain; place_opener stops itself once GGUI.btn_at is set.
cm:add_first_tick_callback(function() GGUI.place_opener(1) end)

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
