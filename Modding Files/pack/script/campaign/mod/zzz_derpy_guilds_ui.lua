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
GGUI.PAGE = 1     -- which guild, 1..#GGUI.GUILD_ORDER

GGUI.GUILD_ORDER = {"brass", "immortals", "daemonsmiths", "khanate",
                    "overseers", "slavers", "temple"}

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
    -- The box is GGUI.S times its design width and so is the text drawn in it, so the
    -- lines break where they break at 1x. The budget is put in whatever units the
    -- measurement below comes back in; see GGUI.text_ratio.
    local r = GGUI.text_ratio()
    w = w * r / GGUI.S
    -- AN [[img:]] IS ONE WORD, AS WIDE AS ITS PICTURE (2026-10-05). CA's effect icons
    -- live under "ui/campaign ui/", so its spaces are held as \1 while the words are
    -- split, and the markup is charged GGUI.FLAG_W rather than measured as its path.
    text = string.gsub(text, "%[%[img:.-%]%]", function(m) return (string.gsub(m, " ", "\1")) end)
    local function measure(s)
        local bare, n = string.gsub(s, "%[%[img:.-%]%]%[%[/img%]%]", "")
        local ok, need = pcall(function() return c:TextDimensionsForText(bare) end)
        if not ok or type(need) ~= "number" then return nil end
        return need + n * GGUI.FLAG_W * r
    end
    local function restore(out)
        for i, l in ipairs(out) do out[i] = (string.gsub(l, "\1", " ")) end
        return out
    end
    local lines, cur = {}, nil
    for word in string.gmatch(text, "%S+") do
        local try = cur and (cur .. " " .. word) or word
        local need = measure(try)
        if need and need > w and cur then
            lines[#lines + 1] = cur
            if max_lines and #lines >= max_lines then
                -- Out of room: mark the cut rather than ending mid-sentence as if
                -- that were the whole thought.
                lines[#lines] = cur .. " ..."
                return restore(lines)
            end
            cur = word
        else
            cur = try
        end
    end
    if cur then lines[#lines + 1] = cur end
    return restore(lines)
end

local function set_named_text(name, text)
    set_text(comp(name), text)
end

-- THE HEADER STRIP: a heading at header_18 on the left (gg_rank_line) and the figures in body
-- text on the right (gg_rank_stats). One body line carried both until 2026-10-04, so the
-- guild's name read as one more number. Both cells carry the hover, since either is under
-- the cursor.
local set_tooltip
local function set_header(head, stats, tip)
    set_named_text("gg_rank_line", head)
    set_named_text("gg_rank_stats", stats)
    set_tooltip(comp("gg_rank_line"), tip)
    set_tooltip(comp("gg_rank_stats"), tip)
end

-- SetTooltipText APPENDS to whatever the component already carries rather than
-- replacing it, so a tooltip rewritten every refresh would grow without bound.
-- Passing an empty string first clears it. The second argument takes a literal
-- string here, not a stringtable key, which is why "||" splits correctly: the
-- text is already resolved by GGUI.loc before it arrives.
--
-- Never read a tooltip back. GetTooltipText hard-crashes on a HUD button.
--
-- AND A TOOLTIP ONLY SHOWS ON AN INTERACTIVE COMPONENT. 1,670 of CA's 1,747 component
-- tooltips sit on one (docs/CUSTOM_UI.md), and a tooltip on a plain text cell is set,
-- correct and never seen. Every card, the rank line, the cost and the footer carried one
-- and none of them was interactive, so the whole panel's hover text was unreachable.
-- Interactive is not clickable: nothing here listens for a click on a text cell.
function set_tooltip(c, text)
    if not c or not text or text == "" then return end
    pcall(function() c:SetTooltipText("", true) end)
    pcall(function() c:SetTooltipText(text, true) end)
    pcall(function() c:SetInteractive(true) end)
end

-- ------------------------------------------------------------------- loc ---
-- Every call below reads localisation and therefore may ONLY be reached from a
-- draw path. Nothing in zzz_derpy_guilds.lua calls into this file.

-- THE HEADER'S INSETS, per race, in design px: where the guild's name starts (the frame's
-- rank_tx) plus how far short of the right end the figures stop (RANK_STATS_PAD). Mirrored
-- from tools/gen_guilds_ui.py, whose check_header_inset compares the two.
GGUI.HEADER_INSET = {[""] = 98, _brt = 148, _cth = 202, _def = 122, _dwf = 98, _emp = 134,
                     _hef = 158, _ksl = 152, _skv = 104}
GGUI.HEADER_GAP = 24

-- WHETHER THE GUILD'S NAME AND THESE FIGURES FIT SIDE BY SIDE, measured in the game's own
-- font (2026-10-05). It replaced a per-race list chosen from the preview, whose font runs
-- about a quarter narrower than the game's: "The Warpstone Traders" was drawn over the
-- start of its figures in game. nil when the engine will not measure.
function GGUI.header_fits(head, stats, tag)
    local hc, sc = comp("gg_rank_line"), comp("gg_rank_stats")
    if not hc or not sc then return nil end
    local ok1, hw = pcall(function() return hc:TextDimensionsForText(head) end)
    local ok2, sw = pcall(function() return sc:TextDimensionsForText(stats) end)
    local ok3, bw = pcall(function() return sc:Dimensions() end)
    if not (ok1 and ok2 and ok3) or type(hw) ~= "number" or type(sw) ~= "number"
       or type(bw) ~= "number" or bw <= 0 then
        return nil
    end
    -- Design px, then the units the measurement comes back in (see GGUI.wrap). The insets
    -- are TEXT insets, which a Small file keeps at Medium's size (gen_guilds_ui.sized: they
    -- clear 9-slice ends drawn at native size), so below 1 they are charged at full size.
    local inset = (GGUI.HEADER_INSET[tag] or 202) * math.max(1, 1 / GGUI.F)
    local room = (bw / GGUI.S - inset - GGUI.HEADER_GAP) * GGUI.text_ratio()
    return hw + sw <= room
end

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
    local path = GGUI.art(GGUI.PANEL_BG[guild])
    -- NO FALLBACK TO "". An unknown guild leaves the ground alone; SetImagePath with an
    -- empty path draws nothing at all, so guessing here would trade a wrong picture for
    -- no picture.
    if not path then return end
    local panel = comp(GGUI.PANEL)
    if not panel then return end
    pcall(function() panel:SetImagePath(path, GGUI.BG_INDEX) end)
end

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

-- THE FACTION'S THREE CARDS for this guild (spec 2026-09-29 pools §4), never the whole
-- catalogue: a guild now holds more services than it has cards.
function GGUI.services_of(guild, faction)
    return GG.guild_cards(faction or GGUI.me(), guild)
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
    gg_title      = {55, 0},
    gg_close      = {748, 12},
    gg_divider    = {20, 44},
    gg_tab_guilds = {20, 56},
    gg_tab_stand  = {145, 56},
    gg_tab_bounty = {270, 56},
    gg_tab_court  = {395, 56},
    gg_tab_log    = {520, 56},
    gg_tab_help   = {645, 56},
    gg_rank_line  = {20, 92},
    gg_rank_stats = {20, 92},
    gg_rank_mark  = {18, 89},
    -- The dark field under the Help and Log lines, and under the faction list.
    gg_back_text  = {20, 164},
    gg_back_list  = {20, 436},
    gg_bar_track  = {20, 140},
    gg_rep_bar    = {38, 148},
    gg_card_1     = {20, 170},
    gg_card_2     = {20, 300},
    gg_card_3     = {20, 430},
    gg_prev       = {20, 596},
    gg_next       = {732, 596},
    -- The seven guild buttons between the arrows, and the bar that marks the page.
    gg_gtab_1     = {232, 596},
    gg_gtab_2     = {280, 596},
    gg_gtab_3     = {328, 596},
    gg_gtab_4     = {376, 596},
    gg_gtab_5     = {424, 596},
    gg_gtab_6     = {472, 596},
    gg_gtab_7     = {520, 596},
    gg_gsel       = {232, 590},
    gg_gbar       = {152, 595},
    -- The Log's filters, in the band the reputation bar uses on the Guilds tab.
    gg_lf_all     = {20, 138},
    gg_lf_mine    = {140, 138},
    gg_lf_rivals  = {260, 138},
    gg_lf_ranks   = {380, 138},
    gg_earned     = {20, 562},
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
    gg_helph_01  = {20, 168},
    gg_helph_02  = {20, 188},
    gg_helph_03  = {20, 208},
    gg_helph_04  = {20, 228},
    gg_helph_05  = {20, 248},
    gg_helph_06  = {20, 268},
    gg_helph_07  = {20, 288},
    gg_helph_08  = {20, 308},
    gg_helph_09  = {20, 328},
    gg_helph_10  = {20, 348},
    gg_helph_11  = {20, 368},
    gg_helph_12  = {20, 388},
    gg_helph_13  = {20, 408},
    gg_helph_14  = {20, 428},
    gg_helph_15  = {20, 448},
    gg_helph_16  = {20, 468},
    gg_helph_17  = {20, 488},
    gg_helph_18  = {20, 508},
    gg_helph_19  = {20, 528},
    gg_helph_20  = {20, 548},
    gg_helph_21  = {20, 568},
}

-- Mirrors HELP_SLOTS in tools/gen_guilds_ui.py; check() refuses if the two differ.
GGUI.HELP_SLOTS = 21
GGUI.CARD_CHILD_XY = {
    card_icon = {8, 7},
    card_name = {114, 12},
    card_need = {114, 12},
    card_desc_1 = {114, 44},
    card_desc_2 = {114, 64},
    card_cost = {596, 10},
    card_buy  = {596, 60},
}

-- The card is ONE template used by every guild, so its icon cannot be baked into
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
    temple       = "ui/campaign ui/derpy_gg_icons/temple.png",
}

-- WHICH IMAGE IS THE GLYPH. The card icon and the header's icon are CA's round bronze
-- holder with the glyph over it, so image 0 is the holder and 1 the glyph; painting 0
-- would put the guild's mark where the holder was and leave the placeholder inside it.
-- gen_guilds_ui.check() pins both against the layer order.
GGUI.CARD_ICON_INDEX = 1
GGUI.RANK_ICON_INDEX = 1

-- A RUNNING SERVICE LIGHTS ITS CARD: CA's heat glow behind the icon (image 2 of the card,
-- index CARD_HEAT_INDEX) and the Tower of Zharr's glowing rim around it (CARD_RIM_INDEX).
-- Off is CLEAR, our own fully transparent 128px file, which is also what the .twui.xml
-- ships (NOT CA's 24px icon_blank: the rim's 40px 9-slice margin read past its edge into
-- the texture atlas and drew streaks over every card, seen in game 2026-09-26). So a
-- card nobody lit - the pick card, a bounty - stays dark. Mirrors CARD_LAYERS in
-- tools/gen_guilds_ui.py, which check() pins.
GGUI.CARD_HEAT_INDEX = 1
GGUI.CARD_RIM_INDEX = 2
GGUI.CARD_OFF = "ui/campaign ui/derpy_gg_icons/clear.png"

-- EVERY RACE IN ITS OWN FRAME (2026-09-29). The panel and the card are created from the
-- reader's race's copy of the .twui.xml - derpy_gg_panel_emp for an Empire player - and
-- what this file repaints at runtime comes from the same race here: the lit card's two
-- glows, and the tab plates by state. A tab state is a LIST, one path per image layer:
-- Kislev's and Bretonnia's tabs are two layers, so their hover layers start at image 2.
-- Mirrors FRAMES in tools/gen_guilds_ui.py, which check() pins entry by entry.
GGUI.FRAME = {
    [""] = {
        heat = "ui/skins/default/dlc23_chd_hell_forge/heat_glow.png",
        rim = "ui/skins/default/dlc23_tower_of_zharr/district_complete_glow_02.png",
        active = {"ui/skins/default/dlc23_chd_hell_forge/button_square_extra_large_active.png"},
        hover = {"ui/skins/default/dlc23_chd_hell_forge/button_square_extra_large_hover.png"},
        selected = {"ui/skins/default/dlc23_chd_hell_forge/button_square_extra_large_selected.png"},
        selected_hover = {"ui/skins/default/dlc23_chd_hell_forge/button_square_extra_large_selected_hover.png"},
    },
    _brt = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/tutglow_square.png",
        active = {"ui/skins/wh_main_brt_bretonnia/legacy/panel_back_tile.png", "ui/skins/default/chivalry_bar_frame.png"},
        hover = {"ui/skins/wh_main_brt_bretonnia/legacy/panel_back_tile.png", "ui/skins/default/chivalry_bar_frame.png"},
        selected = {"ui/skins/wh_main_brt_bretonnia/legacy/panel_back_tile.png", "ui/skins/default/building_frame_selected.png"},
        selected_hover = {"ui/skins/wh_main_brt_bretonnia/legacy/panel_back_tile.png", "ui/skins/default/building_frame_selected.png"},
    },
    _cth = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/tutglow_square.png",
        active = {"ui/skins/default/cp1_cth_tiger_court/position_flag_3.png", "ui/campaign ui/derpy_gg_icons/clear.png"},
        hover = {"ui/skins/default/cp1_cth_tiger_court/position_flag_3.png", "ui/campaign ui/derpy_gg_icons/clear.png"},
        selected = {"ui/skins/default/cp1_cth_tiger_court/position_flag_3.png", "ui/skins/default/tutglow_square.png"},
        selected_hover = {"ui/skins/default/cp1_cth_tiger_court/position_flag_3.png", "ui/skins/default/tutglow_square.png"},
    },
    _def = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/tutglow_square.png",
        active = {"ui/skins/warhammer2/malus_parchment_button_square_active.png"},
        hover = {"ui/skins/warhammer2/malus_parchment_button_square_hover.png"},
        selected = {"ui/skins/warhammer2/malus_parchment_button_square_pressed.png"},
        selected_hover = {"ui/skins/warhammer2/malus_parchment_button_square_pressed.png"},
    },
    _skv = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/tutglow_square.png",
        active = {"ui/skins/warhammer2/ikit_button_active.png", "ui/campaign ui/derpy_gg_icons/clear.png", "ui/skins/default/1x1_blank_white.png"},
        hover = {"ui/skins/warhammer2/ikit_button_hover.png", "ui/campaign ui/derpy_gg_icons/clear.png", "ui/skins/default/1x1_blank_white.png"},
        selected = {"ui/skins/warhammer2/ikit_button_down.png", "ui/skins/default/tutglow_square.png", "ui/skins/default/1x1_blank_white.png"},
        selected_hover = {"ui/skins/warhammer2/ikit_button_down.png", "ui/skins/default/tutglow_square.png", "ui/skins/default/1x1_blank_white.png"},
    },
    _dwf = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/dlc25_malakais_adventures/tab_hover_glow.png",
        active = {"ui/skins/default/dlc25_book_of_grudges/tab_button_confederation_selected.png"},
        hover = {"ui/skins/default/dlc25_book_of_grudges/tab_button_confederation_selected.png"},
        selected = {"ui/skins/default/dlc25_book_of_grudges/tab_button_unit_pack_selected.png"},
        selected_hover = {"ui/skins/default/dlc25_book_of_grudges/tab_button_unit_pack_selected.png"},
    },
    _emp = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/dlc25_gunnery_school/frame_unit_card_selected.png",
        active = {"ui/skins/default/dlc25_gardens_of_morr/don_square_button_default.png"},
        hover = {"ui/skins/default/dlc25_gardens_of_morr/don_square_button_hover.png"},
        selected = {"ui/skins/default/dlc25_gardens_of_morr/don_square_button_selected.png"},
        selected_hover = {"ui/skins/default/dlc25_gardens_of_morr/don_square_button_selected_hover.png"},
    },
    _hef = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/tutglow_square.png",
        active = {"ui/skins/default/dlc27_hef_dragonships/wh3_hef_dragonships_header_tooltip.png", "ui/campaign ui/derpy_gg_icons/clear.png"},
        hover = {"ui/skins/default/dlc27_hef_dragonships/wh3_hef_dragonships_header_tooltip.png", "ui/campaign ui/derpy_gg_icons/clear.png"},
        selected = {"ui/skins/default/dlc27_hef_dragonships/wh3_hef_dragonships_header_tooltip.png", "ui/skins/default/white_frame.png"},
        selected_hover = {"ui/skins/default/dlc27_hef_dragonships/wh3_hef_dragonships_header_tooltip.png", "ui/skins/default/white_frame.png"},
    },
    _ksl = {
        heat = "ui/skins/default/dlc29_great_temple_of_ulric/fx_radial_blur.png",
        rim = "ui/skins/default/wh3_main_court_orthodoxy/court_completed_btn_ornaments.png",
        active = {"ui/skins/default/wh3_main_court_orthodoxy/court_progress_bar.png", "ui/skins/default/wh3_main_court_orthodoxy/kislev_support_frame.png"},
        hover = {"ui/skins/default/wh3_main_court_orthodoxy/court_progress_bar.png", "ui/skins/default/wh3_main_court_orthodoxy/kislev_support_frame.png"},
        selected = {"ui/skins/warhammer3/kislev_devotion_base.png", "ui/skins/warhammer3/kislev_devotion_frame.png"},
        selected_hover = {"ui/skins/warhammer3/kislev_devotion_base.png", "ui/skins/warhammer3/kislev_devotion_frame.png"},
    },
}

function GGUI.frame()
    return GGUI.FRAME[GGUI.tag()] or GGUI.FRAME[""]
end

-- THE FILE A PANEL OR CARD IS CREATED FROM: the reader's race's copy, and the original
-- for a race with no frame of its own. CreateComponent on a path that does not exist
-- draws nothing and says nothing, so an unknown tag must never be appended.
function GGUI.frame_path(base)
    local tag = GGUI.tag()
    if tag ~= "" and GGUI.FRAME[tag] then return base .. tag .. GGUI.SUFFIX end
    return base .. GGUI.SUFFIX
end

function GGUI.light_card(card, lit)
    if not card then return end
    local f = GGUI.frame()
    pcall(function()
        card:SetImagePath(lit and f.heat or GGUI.CARD_OFF, GGUI.CARD_HEAT_INDEX)
        card:SetImagePath(lit and f.rim or GGUI.CARD_OFF, GGUI.CARD_RIM_INDEX)
    end)
end

-- THE PRICE AND ITS PLATE GO TOGETHER. The price sits on the Hell-Forge's small title
-- plate, and a plate with nothing on it is an empty dark bar - the Court's demand and
-- patron cards drew two of them, seen in game 2026-09-26. Every write to card_cost comes
-- through here, so the plate shows exactly when there is a number to put on it.
function GGUI.set_cost(card, text)
    local c = comp("card_cost", card)
    if not c then return end
    text = text or ""
    set_text(c, text)
    pcall(function() c:SetVisible(text ~= "") end)
end

-- WHETHER A SERVICE IS IN EFFECT ON THIS FACTION: its bundle is on the faction now. Only a
-- bundle service can be; a hostile one sits on its victim, not on the buyer.
-- A gold or research service that carries a bundle (the Guild Loan's drawback, The Great
-- Work) lights while that bundle runs too; it went on the faction unlit (2026-09-29).
function GGUI.service_running(faction, s)
    if not s or s.hostile then return false end
    if s.kind ~= "bundle" and not s.with_bundle then return false end
    local ok, on = pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then return false end
        return f:has_effect_bundle("derpy_gg_svc_" .. s.key .. GG.tag(faction))
    end)
    return ok and on == true
end

-- THE TAB PLATE, in the reader's race's frame. The open tab wears the selected pair, so
-- the strip says which view is up in the art as well as the colour. The file lists the
-- standard state's layers and then the hover state's, so with n layers per state the
-- hover ones are images n..2n-1.
function GGUI.paint_tab(t, sel)
    local f = GGUI.frame()
    local std = sel and f.selected or f.active
    local hov = sel and f.selected_hover or f.hover
    pcall(function()
        for k = 1, #std do t:SetImagePath(std[k], k - 1) end
        for k = 1, #hov do t:SetImagePath(hov[k], #std + k - 1) end
    end)
end

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
    temple       = "ui/campaign ui/derpy_gg_bg/temple.png",
}
-- The reputation bar's FULL width, matching PANEL_LAYOUT["gg_rep_bar"] in
-- tools/gen_guilds_ui.py, which check() pins. The bar is drawn at full width in the
-- .twui.xml and narrowed here to the fraction earned - it read as a full gold bar at
-- 0 / 100 reputation until this existed, which says the opposite of the truth.
-- Mirrors GG.BOUNTY_OFFER_LIFE in zzz_derpy_guilds.lua. The panel counts down from
-- it, so a drift here draws a countdown that disagrees with when the offer actually
-- goes away. gen_guilds_ui.check() pins the two together.
GGUI.BOUNTY_LIFE = 6

GGUI.REP_BAR_W = 714
GGUI.REP_BAR_H = 13

-- Mirrors ROW_LAYOUT in tools/gen_guilds_ui.py; check() compares the two. The leader
-- column was widened to 324px because it now carries the round's movement as well as
-- the holder.
GGUI.ROW_CHILD_XY = {
    row_icon   = {6, 2},
    row_guild  = {46, 5},
    row_rank   = {222, 5},
    row_leader = {416, 5},
}
-- One standings row per guild, 34 tall at a 38 step: seven end at y=432 (ROW_STEP in
-- tools/gen_guilds_ui.py).
GGUI.ROW_STEP = 38

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
    vslider   = {732, 24},
}

-- THE SLIDER IS CA'S EVENT-MESSAGE SLIDER (gen_guilds_ui.ca_vslider), as the Exchange's: its
-- track stops 24px short of each end of the list, and a frame cap and an arrow sit in that
-- gap. Docking is ignored on a runtime component, so each part is MoveTo'd: x from the
-- track's left, y from its top - or from its END for the two bottoms. gen_guilds_ui.CA_SLIDER
-- holds the same numbers, measured off CA's art.
GGUI.SLIDER_PARTS = {
    {"frame_top", -1, -24},
    {"frame_bottom", -1, 0},
    {"top", 1, -23},
    {"bottom", 1, -1},
}

-- WHICH GUILD THE LIST IS SHOWING: an index into GG.GUILDS, because GGUI.leaders() builds
-- the rows in exactly that order. Clicking a standings row sets it.
GGUI.STAND_GUILD = 1

-- A faction whose flag_path() was unreadable still gets a crest rather than a gap. A path
-- that resolves to nothing draws nothing and says nothing about it.
GGUI.FLAG_FALLBACK = "ui/flags/wh3_dlc23_chd_chaos_dwarfs/mon_24.png"

-- ------------------------------------------------------------------ scale ---
-- THE PANEL GROWS WITH THE SCREEN. A 4K player at UI Scale 100% got a 790x700 panel in a
-- quarter of the area it covers at 1080p, with text to match.
--
-- The screen this script is told about is ALREADY divided by the player's UI Scale.
-- CA's own scale slider tests RootComponent.Dimensions.y * DevUiScale >= 1440, and a
-- 1280x720 window reported a 1600x900 screen here. So the game's own setting already
-- scales this panel along with the rest of its UI, and the factor below only makes up the
-- gap between that screen and the 1920x1080 the panel was laid out for. A 4K player at
-- 200% reports 1920x1080 and gets 1: scaling again would make it four times.
--
-- Never below 1, since at 1600x900 the design still fits. Led by height, and capped by
-- width, so an ultrawide gets the panel a 16:9 screen of the same height would.
GGUI.DESIGN_W = 1920
GGUI.DESIGN_H = 1080
-- THE TOTAL FACTOR, design pixels to screen pixels: every MoveTo and offset goes through
-- GGUI.px with it. It is GGUI.F times GGUI.SA, and the two are applied differently:
--   F  - the MCT size. The parts ARE that size in their own .twui.xml files, with real
--        font categories, so nothing is stretched (GGUI.SIZES).
--   SA - the screen factor above. scale_tree resizes the parts and stretches their text.
GGUI.S = 1
GGUI.F = 1
GGUI.SA = 1
GGUI.SUFFIX = ""
GGUI.SIZE = "medium"

function GGUI.scale_for(sw, sh)
    if type(sw) ~= "number" or type(sh) ~= "number" or sw <= 0 or sh <= 0 then
        return 1
    end
    local s = math.min(sw / GGUI.DESIGN_W, sh / GGUI.DESIGN_H)
    if s <= 1 then return 1 end
    -- Hundredths: 2560x1440 is 1.333... and the tail buys nothing but float noise.
    return math.floor(s * 100 + 0.5) / 100
end

-- MCT "Panel size": Small / Medium / Large. A SLIDER WAS TRIED FIRST (2026-10-08) and drew
-- soft text at every size but 100%: font_scale stretches the glyphs it already drew, and
-- no call changes a font. So each size is its own set of files, every font category one
-- real step along CA's list - gen_guilds_ui.SIZES writes them, and check_sizes pins this
-- table against it. Medium is the original files, no suffix.
GGUI.SIZES = {
    small  = {f = 6 / 7, suffix = "_sm"},
    medium = {f = 1,     suffix = ""},
    large  = {f = 4 / 3, suffix = "_lg"},
}
-- The panel at Medium: what decides whether a size fits the screen. check_sizes pins it
-- against the generator's panel root.
GGUI.PANEL_W, GGUI.PANEL_H = 790, 700

-- Read live on every open, like log_accrual: display only, never frozen into the save, and
-- set_is_global keeps it each player's own in multiplayer.
function GGUI.want_size()
    local ok, v = pcall(function()
        local mct = get_mct and get_mct()
        local mod = mct and mct:get_mod_by_key("derpy_great_guilds")
        local opt = mod and mod:get_option_by_key("ui_size")
        return opt and opt:get_finalized_setting()
    end)
    if ok and GGUI.SIZES[v] then return v end
    return "medium"
end

-- THE SIZE THAT IS DRAWN: the file set nearest the size asked for times the screen factor,
-- among those that fit. The screen factor is spent HERE, on a real font, and never on
-- font_scale: a 2560x1440 player reported soft text at all three sizes (2026-10-09),
-- because SA 1.33 stretched every glyph. So at 1440p Medium draws the Large files - the
-- 1080p look, sharp - and above Large's 4/3 the panel simply stays Large. Medium always
-- fits: the engine's screen is never below 1600x900. Large does not on that floor.
function GGUI.pick_size(want, sw, sh, sa)
    local z = GGUI.SIZES[want] and want or "medium"
    local target = GGUI.SIZES[z].f * (sa or 1)
    local fits = type(sw) ~= "number" or type(sh) ~= "number"
    -- NOT math.huge: the game's math library has no `huge`. It only worked while another
    -- mod (OvN's json shim: `math.huge = 2 ^ 1024`) defined it; alone, `d < gap` threw.
    local best, gap = "medium", 1e30
    for _, k in ipairs({"small", "medium", "large"}) do
        local s = GGUI.SIZES[k]
        local d = math.abs(s.f - target)
        if (fits or (GGUI.PANEL_W * s.f <= sw and GGUI.PANEL_H * s.f <= sh)) and d < gap then
            best, gap = k, d
        end
    end
    return best
end

function GGUI.px(v)
    return math.floor(v * GGUI.S + 0.5)
end

-- THE ZERO-LENGTH ANIMATION EVERY TEXT CELL CARRIES. It exists so its font_scale frame
-- can be rewritten: nothing else in the uicomponent API changes the size a label draws
-- at, and CA's own lib_topic_leader.lua shrinks its text the same way. Swapping the font
-- category would stop near 1.33x, because the body family ends at body_16.
-- gen_guilds_ui.py writes the animation and its check() pins this name against it.
GGUI.SCALE_ANIM = "derpy_gg_scale"

-- EVERY PART, RECURSIVELY, PARENT FIRST. Each part is resized from what it measures
-- now, so this runs once per component, straight after it is created: a second pass
-- would scale a part that is already scaled. Parent first because list_clip follows its
-- parent's resize by itself (isrelativeresize), and the size set after that is the one
-- that stands.
--
-- Resize(w, h, FALSE). The third argument defaults to true and rescales every child by
-- the parent's factor; this walk then scales each child again, so the default compounded
-- per level - the title at S^2, card text at S^3 - and ran the cards off the panel at
-- 150% (in game, 2026-10-08).
--
-- SetCanResize* before Resize, or the call is ignored (the rep bar's idiom). The
-- pictures follow their box: across CA's panels an image's canresizewidth is only ever
-- written "false", 7,585 times and never "true", so stretching is the default.
function GGUI.scale_tree(c)
    -- GGUI.SA, not GGUI.S: the file is already at the MCT size (GGUI.F).
    if GGUI.SA == 1 or not c then return end
    local w, h
    pcall(function()
        w, h = c:Dimensions()
        w, h = math.floor(w * GGUI.SA + 0.5), math.floor(h * GGUI.SA + 0.5)
        c:SetCanResizeWidth(true)
        c:SetCanResizeHeight(true)
        c:Resize(w, h, false)
    end)
    pcall(function()
        if c:AnimationExists(GGUI.SCALE_ANIM) then
            -- The frame carries a width and height, as CA writes every frame. The mask
            -- says font_scale only; the grown size goes in as well, so a frame that
            -- applied them anyway could not shrink the part back to its design size.
            if w and h then
                c:SetAnimationFrameProperty(GGUI.SCALE_ANIM, 0, "scale", w, h)
            end
            c:SetAnimationFrameProperty(GGUI.SCALE_ANIM, 0, "font_scale", GGUI.SA)
            c:TriggerAnimation(GGUI.SCALE_ANIM)
        end
    end)
    local ok, n = pcall(function() return c:ChildCount() end)
    if not ok or type(n) ~= "number" then return end
    for i = 0, n - 1 do
        local ok_k, kid = pcall(function() return UIComponent(c:Find(i)) end)
        if ok_k and kid then GGUI.scale_tree(kid) end
    end
end

-- WHETHER TextDimensionsForText MEASURES THE SCALED FONT is not in CA's reference, so it
-- is measured instead: one probe string on gg_help_01, before the scale in open() and
-- again here. 1 means the engine measures at the design size, GGUI.S at the drawn one.
-- GGUI.wrap needs to know which, or the Help tab breaks its lines in the wrong places.
-- Logged when it changes, which is the in-game answer to the question.
--
-- TIMES GGUI.F: a Small or Large file draws a real smaller or bigger font, so its probe is
-- already F times the design reading before any stretch. Every caller divides by GGUI.S
-- (= F x SA) or multiplies by GGUI.px, so the F cancels and lines break against the box
-- the text actually sits in, whatever the true width ratio of body_16 to body_12 is.
GGUI.PROBE = "The Great Guilds of Zharr-Naggrund"
GGUI.PROBE_W0 = nil
GGUI.RATIO_SEEN = nil

function GGUI.text_ratio()
    if type(GGUI.PROBE_W0) ~= "number" or GGUI.PROBE_W0 <= 0 then return GGUI.F end
    local c = comp("gg_help_01")
    -- THE PANEL IS SHUT during a pick, and the pick card still wraps. The last reading is
    -- still the truth about the font.
    if not c then return GGUI.RATIO_SEEN or GGUI.F end
    local ok, w = pcall(function() return c:TextDimensionsForText(GGUI.PROBE) end)
    if not ok or type(w) ~= "number" or w <= 0 then return GGUI.F end
    local r = GGUI.F * w / GGUI.PROBE_W0
    if r ~= GGUI.RATIO_SEEN then
        GGUI.RATIO_SEEN = r
        GGUI.info(string.format("text measures x%.2f at panel scale %.2f", r, GGUI.S))
    end
    return r
end

-- Re-run on every open and every refresh. Cheap, and it heals a panel laid out
-- before the screen settled instead of leaving a bad position permanent.
-- Every offset goes through GGUI.px: the parts are GGUI.S times their design size, so
-- their places have to be too, or a grown panel stacks them in its top-left corner.
-- A card and its six children. Shared by the panel's three cards and the pick card, which
-- is the same template created on the root.
function GGUI.place_card(card, x, y)
    card:MoveTo(x, y)
    -- Read the card's position back rather than reusing the asked-for numbers: the
    -- children must follow where the card ACTUALLY went.
    local cx, cy = card:Position()
    for name, xy in pairs(GGUI.CARD_CHILD_XY) do
        local c = comp(name, card)
        local x = xy[1]
        if name == "card_need" then x = GGUI.NEED_DX[GGUI.card_id(card)] or x end
        if c then c:MoveTo(cx + GGUI.px(x), cy + GGUI.px(xy[2])) end
    end
end

function GGUI.layout()
    local panel = comp(GGUI.PANEL)
    if not panel then return end
    local P = GGUI.px
    local px, py = panel:Position()
    for name, xy in pairs(GGUI.PANEL_XY) do
        local c = comp(name, panel)
        if c then c:MoveTo(px + P(xy[1]), py + P(xy[2])) end
    end
    for i = 1, #GGUI.CARD_XY do
        local card = comp(GGUI.CARD .. "_" .. i, panel)
        if card then
            GGUI.place_card(card, px + P(GGUI.CARD_XY[i][1]), py + P(GGUI.CARD_XY[i][2]))
        end
    end
    -- THE LIST FRAME, but not what is inside the box. The clip window and the slider are
    -- placed here because nothing else places them; the rows inside are placed by the
    -- engine's list layout, which is the whole point of using one.
    local list = comp(GGUI.LIST, panel)
    if list then
        list:MoveTo(px + P(GGUI.LIST_XY[1]), py + P(GGUI.LIST_XY[2]))
        local lx, ly = list:Position()
        for name, xy in pairs(GGUI.LIST_CHILD_XY) do
            local c = comp(name, list)
            if c then c:MoveTo(lx + P(xy[1]), ly + P(xy[2])) end
        end
        -- AFTER the slider: a parent's MoveTo carries its children with it.
        -- Guarded: a cap left unplaced is cosmetic, a throw here would leave the rows unplaced.
        local vs = comp("vslider", list)
        if vs then
            pcall(function()
                local sx, sy = vs:Position()
                local _, th = vs:Dimensions()
                for _, p in ipairs(GGUI.SLIDER_PARTS) do
                    local part = comp(p[1], vs)
                    local base = (p[1] == "frame_bottom" or p[1] == "bottom") and sy + th or sy
                    if part then part:MoveTo(sx + P(p[2]), base + P(p[3])) end
                end
            end)
        end
    end
    for i = 1, #GG.GUILDS do
        local row = comp(GGUI.ROW .. "_" .. i, panel)
        if row then
            row:MoveTo(px + P(20), py + P(170 + (i - 1) * GGUI.ROW_STEP))
            local rx, ry = row:Position()
            for name, xy in pairs(GGUI.ROW_CHILD_XY) do
                local c = comp(name, row)
                if c then c:MoveTo(rx + P(xy[1]), ry + P(xy[2])) end
            end
        end
    end
end

function GGUI.open()
    if comp(GGUI.PANEL) then GGUI.refresh(); return end
    local ok, err = pcall(function()
        local r = root()
        -- Dimensions(), not Bounds(): Bounds() includes children. Read on every open,
        -- so a player who changes UI Scale or the MCT size gets it the next time they
        -- look. BEFORE CreateComponent, because the size picks which files are created.
        local sw, sh = r:Dimensions()
        -- SA stays 1: pick_size spends the screen factor on a real font, so scale_tree
        -- and its font_scale stretch never run (soft text at 1440p, 2026-10-09).
        GGUI.SA = 1
        GGUI.SIZE = GGUI.pick_size(GGUI.want_size(), sw, sh, GGUI.scale_for(sw, sh))
        GGUI.F, GGUI.SUFFIX = GGUI.SIZES[GGUI.SIZE].f, GGUI.SIZES[GGUI.SIZE].suffix
        GGUI.S = GGUI.F * GGUI.SA
        r:CreateComponent(GGUI.PANEL, GGUI.frame_path(GGUI.PATH_PANEL))
        local panel = comp(GGUI.PANEL)
        if not panel then return end
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
            panel:CreateComponent(GGUI.CARD .. "_" .. i, GGUI.frame_path(GGUI.PATH_CARD))
        end
        -- One standings row per guild, stacked under the header. Created once and
        -- hidden with el.hidden-style visibility on the tabs that do not use them.
        for i = 1, #GG.GUILDS do
            panel:CreateComponent(GGUI.ROW .. "_" .. i, GGUI.PATH_ROW .. GGUI.SUFFIX)
        end
        -- The faction list frame. Its rows are not created here: they depend on who is
        -- alive and which guild is selected, so GGUI.draw_faction_list builds them.
        panel:CreateComponent(GGUI.LIST, GGUI.PATH_LIST .. GGUI.SUFFIX)

        -- GROW EVERYTHING, THEN PLACE IT. The probe is measured first because it has to
        -- be the design-size reading. The panel is centred after the scale, on the size
        -- it has now, with MoveTo, since dockpoint is ignored on a runtime component.
        GGUI.PROBE_W0, GGUI.RATIO_SEEN = nil, nil
        local help = comp("gg_help_01", panel)
        if help then
            pcall(function() GGUI.PROBE_W0 = help:TextDimensionsForText(GGUI.PROBE) end)
        end
        GGUI.scale_tree(panel)
        -- THE SLIDER'S TRAVEL IS A NUMBER, not a size, so Resize never reaches it. Left
        -- alone, a list twice as tall scrolls through half of its track.
        if GGUI.S ~= 1 then
            for name, prop in pairs({vslider = "maxValue", handle = "max_height"}) do
                local c = comp(name, panel)
                if c then
                    pcall(function()
                        local v = tonumber(c:GetProperty(prop))
                        if v then c:SetProperty(prop, GGUI.px(v)) end
                    end)
                end
            end
        end
        local pw, ph = panel:Dimensions()
        panel:MoveTo(math.floor((sw - pw) / 2), math.floor((sh - ph) / 2))
        GGUI.info(string.format("panel scale %.2f on a %dx%d screen, panel %dx%d, %s size",
                               GGUI.S, sw, sh, pw, ph, GGUI.SIZE))

        -- Creation and scale above. GGUI.layout() places every component, including
        -- the panel's own children, which the .twui.xml offsets do not.
        GGUI.layout()
    end)
    -- A FAILED OPEN SAYS WHY, always (antislop audit 2026-10-09): otherwise the opener
    -- just does nothing, and a player's log has no line to send.
    if not ok then GGUI.say("GAVE UP opening the panel: " .. tostring(err)) end
    -- ASKED OF THE PANEL, not of `ok`: the body above returns early without a panel and
    -- still reports success, and a key held for a panel that is not there swallows the
    -- player's next Escape for nothing.
    if ok and comp(GGUI.PANEL) then
        GGUI.hold_esc(GGUI.ESC, GGUI.close)
        GGUI.refresh()
    end
end

function GGUI.close()
    GGUI.drop_esc(GGUI.ESC)
    GGUI.CONFIRM = nil
    local p = comp(GGUI.PANEL)
    if p then pcall(function() p:DestroyChildren(); p:Destroy() end) end
end

-- ------------------------------------------------------------ escape key ---
-- ESCAPE CLOSES THE PANEL, the way it closes every CA panel. Without it Escape opened the
-- game menu over the top of this one.
--
-- TRACKED HERE, because CA's two calls are not symmetric (lib_campaign_manager.lua):
--   * stealing a name that is already held is a script_error;
--   * releasing a name that is NOT held finds nothing, and if no entry is left CA then
--     lets go of the key outright - including a plain steal_escape_key some other script
--     is relying on.
-- And a FIRED entry is removed by CA itself, so the callback clears its own mark before it
-- runs; the close() it calls then has nothing to release.
GGUI.ESC = "derpy_gg_panel_esc"
GGUI.ESC_HELD = GGUI.ESC_HELD or {}

function GGUI.hold_esc(name, fn)
    if GGUI.ESC_HELD[name] then return end
    GGUI.ESC_HELD[name] = true
    pcall(function()
        cm:steal_escape_key_with_callback(name, function()
            GGUI.ESC_HELD[name] = nil
            fn()
        end)
    end)
end

function GGUI.drop_esc(name)
    if not GGUI.ESC_HELD[name] then return end
    GGUI.ESC_HELD[name] = nil
    pcall(function() cm:release_escape_key_with_callback(name) end)
end

function GGUI.card(i)
    return comp(GGUI.CARD .. "_" .. i, comp(GGUI.PANEL))
end

function GGUI.draw_card(faction, i, s)
    local card = GGUI.card(i)
    if not card then return end
    GGUI.light_card(card, GGUI.service_running(faction, s))
    GGUI.show_need(card)
    if not s then
        set_text(comp("card_name", card), "")
        set_text(comp("card_desc_1", card), "")
        set_text(comp("card_desc_2", card), "")
        GGUI.set_cost(card, "")
        set_text(comp("card_buy", card), "")
        local eb = comp("card_buy", card)
        if eb then pcall(function() eb:SetVisible(false) end) end
        -- An empty card drops the glyph, so a short guild's third slot reads as empty
        -- rather than as a mislabelled service - and the whole card, so it is not a bare
        -- plate either (antislop audit 2026-10-09). The bounty board shows it again.
        local ic = comp("card_icon", card)
        if ic then pcall(function() ic:SetVisible(false) end) end
        pcall(function() card:SetVisible(false) end)
        return
    end
    local ok, why = GGUI.card_state(faction, s)
    -- NO TARGET, BUT ONE CAN BE PICKED: the button is live and steps the panel aside.
    local pick = not ok and why == "target" and GGUI.can_pick(s)
    local label = GGUI.loc_service(s.key)
    local need
    local rep_now = GG.get(faction, s.guild)
    local need_rep = GG.RANKS[s.rank] or 0
    if not ok and why == "rank" then
        -- [[col:]] markup works in SetStateText. A typo'd colour name silently
        -- drops the colour rather than erroring, so this uses a known one.
        -- "Needs Indebted" rather than "Indebted": the bare rank name reads as a
        -- property of the service, not as the thing standing in your way.
        need = GGUI.loc("needs") .. " " .. GGUI.loc_rank(s.rank)
    elseif not ok and why == "lead" then
        -- The monopoly. Red, like the rank gate, because it is the same kind of thing:
        -- something standing between the player and a service they can otherwise afford.
        need = GGUI.loc("needs_lead")
    elseif not ok and why == "cooldown" then
        label = label .. "  " .. GGUI.count(GG.cooldown_left(faction, s.key), "bounty_turns")
    elseif not ok and why == "target" then
        label = label .. "  [[col:yellow]]" .. GGUI.loc("needs_target_short") .. "[[/col]]"
    elseif not ok and why == "unavailable" then
        need = GGUI.loc("unavailable_short")
    end
    set_text(comp("card_name", card), label)
    if need then GGUI.show_need(card, label, GGUI.need_tag(need)) end

    -- THE LIVE PRICE, from the same call GG.buy charges through. A guild that knows
    -- you charges less; one whose rival you have been courting charges more, so the
    -- number on this card is not the number in the data and must never be read from
    -- there.
    local cost_now, cost_mod, hall_cut = GG.service_cost(faction, s.key)
    local cost_text = tostring(cost_now)
    if cost_mod < 0 then
        cost_text = "[[col:green]]" .. cost_text .. "[[/col]]"
    elseif cost_mod > 0 then
        cost_text = "[[col:yellow]]" .. cost_text .. "[[/col]]"
    end
    -- SHORT OF FAVOUR IS RED WHATEVER ELSE SHUTS IT (2026-10-05, asked in game): can_buy
    -- names the rank first, so a card both locked and unaffordable never went red.
    local _, fav_now = GG.get(faction, s.guild)
    if (fav_now or 0) < cost_now then
        cost_text = "[[col:red]]" .. tostring(cost_now) .. "[[/col]]"
    end
    GGUI.set_cost(card, cost_text)

    local ic = comp("card_icon", card)
    if ic then
        pcall(function()
            ic:SetVisible(true)
            ic:SetImagePath(GGUI.icon(GGUI.current_guild()) or "", GGUI.CARD_ICON_INDEX)
        end)
    end

    -- The card shows a name and a number. Everything a player needs to decide -
    -- what it does, what the number is, how long it lasts, why it is greyed -
    -- lives in the tooltip, so it is built here rather than left implicit.
    local tip = GGUI.loc_service_desc(s.key)
    local body = GGUI.card_body(s, tip)
    local d1 = comp("card_desc_1", card)
    local lines = GGUI.wrap(d1, body, 2)
    set_text(d1, lines[1] or "")
    set_text(comp("card_desc_2", card), lines[2] or "")
    if not ok and why == "rank" then
        -- The exact shortfall, because "keep earning reputation" does not tell a
        -- player whether they are ten short or a thousand.
        -- From loc, not English built here (antislop audit 2026-10-09). %n held, %m needed,
        -- %r the rank, %d the difference.
        local short = GGUI.fill(GGUI.loc("tip_short_rep"), rep_now)
        short = string.gsub(short, "%%m", tostring(need_rep))
        short = string.gsub(short, "%%r", (string.gsub(GGUI.loc_rank(s.rank), "%%", "%%%%")))
        short = string.gsub(short, "%%d", tostring(math.max(0, need_rep - rep_now)))
        tip = tip .. "||" .. GGUI.loc("locked_hint") .. " " .. short
    elseif not ok and why == "lead" then
        local who = GG.leader_of(s.guild, GG.culture_of(faction))
        tip = tip .. "||" .. GGUI.loc("lead_hint")
        if who then
            tip = tip .. "  " .. GGUI.loc("lead_by") .. " " .. GGUI.faction_name(who)
                  .. "."
        end
    elseif not ok and why == "cooldown" then
        local left = GG.cooldown_left(faction, s.key)
        tip = tip .. "||" .. GGUI.fill(GGUI.loc(left == 1 and "tip_cooldown_1" or "tip_cooldown"), left)
    elseif not ok and why == "favour" then
        tip = tip .. "||" .. GGUI.fill(GGUI.loc("tip_short_fav"), cost_now)
    elseif not ok and why == "target" then
        tip = tip .. "||" .. GGUI.loc(GGUI.target_hint(s))
        if pick then tip = tip .. "||" .. GGUI.loc("pick_help") end
    elseif not ok and why == "no_unit" then
        -- Every culture in the campaign runs guilds; only the flavoured ones have a
        -- regiment mapped. Said in words rather than left as a dead button.
        tip = tip .. "||" .. GGUI.loc("no_unit")
    elseif not ok and why == "unavailable" then
        tip = tip .. "||" .. GGUI.loc("unavailable")
    end
    local asking = ok and GGUI.CONFIRM == s.key
    if asking then tip = tip .. "||" .. GGUI.loc("confirm_tip") end
    set_tooltip(card, tip)
    -- The price AND the reason for it. A number that moves with no explanation is
    -- read as a bug, which is the whole lesson of the bounty board's difficulty band.
    local cost_tip = GGUI.loc("cost_label") .. ": " .. cost_now
    if cost_mod ~= 0 then
        cost_tip = cost_tip .. "  (" .. GGUI.loc("cost_base") .. " " .. s.cost .. ")||"
                   .. (cost_mod < 0 and GGUI.loc("cost_loyal") or GGUI.loc("cost_rival"))
                   .. "  " .. string.format("%+d", cost_mod) .. "%"
    end
    -- THE HALLS' SHARE OF THAT TOTAL, not a cut on top of it: what they actually took
    -- after the -30 floor, which GG.service_cost returns. Nothing when it took nothing.
    hall_cut = hall_cut or 0
    if hall_cut > 0 then
        cost_tip = cost_tip .. "||" .. GGUI.loc("price_halls") .. ": -" .. hall_cut .. "%"
    end
    set_tooltip(comp("card_cost", card), cost_tip)
    local btn = comp("card_buy", card)
    if btn then
        local cap = GGUI.loc("buy")
        if pick then
            cap = GGUI.loc("pick_button")
        elseif asking then
            cap = "[[col:yellow]]" .. GGUI.loc("confirm") .. "[[/col]]"
        end
        -- A SHUT BUY IS GREYED, NOT RECOLOURED (antislop audit 2026-10-09): red on the red
        -- plate measured 2.85:1. The price is red when favour is short and card_need says
        -- what else shuts it, so the caption only has to read as dead.
        set_text(btn, cap)
        -- SHOWN AGAIN. The bounty board and the Court both hide this button on a slot
        -- with no action, and nothing else would ever bring it back.
        pcall(function() btn:SetVisible(true) end)
        GGUI.set_live(btn, ok or pick)
    end
end

-- THE CARD'S VERDICT, shared by the draw and the click so the two cannot disagree.
-- A TARGETED service needs something selected on the map. can_buy cannot see the
-- selection, so the card checks it here - otherwise the button reads as live and refuses
-- when pressed, which is the fault this whole pass keeps finding.
--
-- GG.needs_target, not s.hostile: four more services read a target and did nothing
-- without one, and this card showed all four as buyable.
-- THE CARD'S TWO LINES: what the service does, the tooltip's first paragraph. A race's own
-- service says so first (spec §9), in yellow, so the one card no other race sees is found
-- at a glance.
function GGUI.card_body(s, tip)
    local body = tip:match("^(.-)||") or tip
    if s.race then
        body = "[[col:yellow]]" .. GGUI.loc("race_label") .. "[[/col]]  " .. body
    end
    return body
end

-- WHAT STANDS BETWEEN THE PLAYER AND A SERVICE: CA's padlock, then the reason in red, on
-- its own plate just past the name (card_need). Red on the bare bronze measured 2.2:1, so
-- from 2026-10-04 the reason went in the name's colour - and blended into the card, seen
-- in game 2026-10-05. The plate is the race's cost-box art, which red reads on.
-- LOCK_COL (db/ui_colours "orange", FFAD5B) marks the Court's deadline. A full path, as
-- the faction list's flags are written.
GGUI.LOCK_ICON = "ui/skins/default/icon_padlock.png"
GGUI.LOCK_COL = "orange"

-- A CARD BUTTON'S LIVE OR DEAD LOOK. These plates ship `standard` and `hover` only, so
-- SetDisabled stops the click and draws nothing; the look is the opener's greyscale
-- (GGUI.gate_opener), and the caption stays cream so it still reads.
function GGUI.set_live(btn, live)
    pcall(function()
        btn:SetDisabled(not live)
        btn:ShaderTechniqueSet(live and "normal_t0" or "set_greyscale_t0", true, true)
        if not live then btn:ShaderVarsSet(1, 0.6, 0, 0, true, true) end
    end)
end

function GGUI.need_tag(text)
    return "[[img:" .. GGUI.LOCK_ICON .. "]][[/img]] [[col:red]]" .. text .. "[[/col]]"
end

-- THE PLATE'S PLACE, in design px from the card: the name's start, LABEL_TX's 6px inset,
-- the name as the game measures it, then NEED_GAP. Never past NEED_RIGHT, the price box's
-- edge less its 6px; a name too long for both lets the plate cover its end instead.
-- NEED_PAD mirrors gen_guilds_ui.NEED_PAD, the text inset each side. NEED_DX remembers the
-- place per card, so a re-layout (place_card) does not drop the plate on the name.
GGUI.NEED_PAD, GGUI.NEED_GAP, GGUI.NEED_RIGHT = 10, 8, 590
GGUI.NEED_DX = {}

function GGUI.card_id(card)
    local ok, id = pcall(function() return card:Id() end)
    return ok and id or tostring(card)
end

-- Design px a string draws at in c's font: markup out, each [[img:]] as GGUI.FLAG_W.
function GGUI.text_w(c, s)
    local bare, n = string.gsub(s, "%[%[img:.-%]%]%[%[/img%]%]", "")
    bare = string.gsub(bare, "%[%[/?col[^%]]*%]%]", "")
    local ok, w = pcall(function() return c:TextDimensionsForText(bare) end)
    if not ok or type(w) ~= "number" then return nil end
    return w / GGUI.text_ratio() + n * GGUI.FLAG_W
end

-- text nil hides the plate, as every card that is not a shut service needs.
function GGUI.show_need(card, name, text)
    local c = comp("card_need", card)
    if not c then return end
    local id = GGUI.card_id(card)
    if not text then
        GGUI.NEED_DX[id] = nil
        set_text(c, "")
        pcall(function() c:SetVisible(false) end)
        return
    end
    -- The pad is the cell's TEXT inset, which a Small file keeps at Medium's size
    -- (gen_guilds_ui.sized), so below 1 it is charged at full size.
    local pad = GGUI.NEED_PAD * math.max(1, 1 / GGUI.F)
    local w = math.floor((GGUI.text_w(c, text) or 140) + 2 * pad + 0.5)
    local nw = GGUI.text_w(comp("card_name", card) or c, name)
    local dx = GGUI.NEED_RIGHT - w
    if nw then
        dx = math.min(math.floor(GGUI.CARD_CHILD_XY.card_name[1] + 6 + nw
                                 + GGUI.NEED_GAP + 0.5), dx)
    end
    GGUI.NEED_DX[id] = dx
    set_text(c, text)
    pcall(function()
        local _, h = c:Dimensions()
        c:SetCanResizeWidth(true)
        c:Resize(GGUI.px(w), h, false)
        c:SetVisible(true)
        local cx, cy = card:Position()
        c:MoveTo(cx + GGUI.px(dx), cy + GGUI.px(GGUI.CARD_CHILD_XY.card_need[2]))
    end)
end

function GGUI.card_state(faction, s)
    local ok, why = GG.can_buy(faction, s.key)
    if ok and GG.needs_target(s) and not GGUI.pick_target(s, faction) then
        ok, why = false, "target"
    end
    return ok, why
end

-- A PURCHASE THAT IS HARD TO TAKE BACK ASKS FIRST: one aimed at another faction, and one
-- that spends half or more of what the player holds with that guild. The first click turns
-- the button into Confirm; paging or changing tab forgets it.
GGUI.CONFIRM = nil

function GGUI.needs_confirm(faction, s)
    if not s then return false end
    if s.hostile then return true end
    if s.kind == "enemy_settlement" then return true end
    local cost = GG.service_cost(faction, s.key)
    local _, fav = GG.get(faction, s.guild)
    return (cost or 0) * 2 >= (fav or 0)
end

-- A mission's title and description live under keys the RUNTIME derives from the
-- mission key - missions_localised_title_<key> - not under this mod's derpy_gg_
-- prefix, so they cannot go through GGUI.loc.
function GGUI.loc_raw(key)
    local ok, s = pcall(function() return common.get_localised_string(key) end)
    if ok and s and s ~= "" then return s end
    return ""
end

-- %n in a loc line is the number the card fills in. One placeholder, one number: a
-- sentence with the number in the middle is easier to translate than one built in pieces.
function GGUI.fill(s, n)
    return (string.gsub(s, "%%n", tostring(n)))
end

-- The footer's countdown to the next services. One turn left has its own words: the
-- counted line read "New services in 1 turns".
function GGUI.countdown(n)
    if n == 1 then return GGUI.loc("next_services_1") end
    return GGUI.fill(GGUI.loc("next_services"), n)
end

function GGUI.bounty_title(o)
    local t = GGUI.loc_raw("missions_localised_title_" .. GG.offer_mission_key(o, GGUI.me()))
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

-- A NEW-WAR OFFER SAYS SO IN RED, because taking it declares the war. A hero bounty
-- leads with what the heroes are to do and, once taken, counts up (1/2).
function GGUI.bounty_target_label(o)
    local k = GG.BOUNTY_KINDS[o.kind]
    if not k then return "" end
    local owner = GGUI.faction_name(GGUI.bounty_owner_now(o))
    local progress = ""
    if k.shape and o.taken then
        progress = "  (" .. (o.done or 0) .. "/" .. (o.amount or 1) .. ")"
    end
    local lead = ""
    -- Every key spelled out whole, so check_loc_keys can see each one ships.
    if k.shape then
        lead = GGUI.loc(({sabotage = "bounty_obj_sabotage", harry = "bounty_obj_harry",
                          strike = "bounty_obj_strike"})[k.shape]) .. ": "
    end
    local who
    if k.target == "region" then
        -- regions_onscreen_<region_key>, read out of CA's own regions__.loc.
        who = GGUI.loc_raw("regions_onscreen_" .. tostring(o.target))
        if who == "" then who = tostring(o.target) end
    elseif k.target == "lord" then
        who = GGUI.loc("bounty_lord")
    elseif k.target == "character" then
        who = GGUI.loc("bounty_char")
    end
    if who then
        if o.war == 1 then
            return lead .. who .. "  [[col:red]]" .. GGUI.loc("bounty_war") .. " "
                   .. owner .. "[[/col]]"
        end
        return lead .. who .. "  (" .. owner .. ")" .. progress
    elseif k.pick == "coffers" and o.taken then
        return GGUI.fill(GGUI.loc("bounty_obj_coffers_taken"), o.amount or 0)
    elseif k.pick == "coffers" then
        return GGUI.fill(GGUI.loc("bounty_obj_coffers"), o.amount or 0)
    elseif k.pick == "champion" then
        return GGUI.fill(GGUI.loc("bounty_obj_champion"), o.amount or 0)
    elseif k.pick == "captives" then
        return GGUI.fill(GGUI.loc("bounty_obj_captives"), o.amount or 0)
    elseif k.pick == "research" then
        local nm = GGUI.loc_raw("technologies_onscreen_name_" .. tostring(o.target))
        return GGUI.loc("bounty_obj_research") .. ": " .. (nm ~= "" and nm or tostring(o.target))
    elseif k.pick == "build" then
        local lk = GG.BOUNTY_BUILDING_LOC and GG.BOUNTY_BUILDING_LOC[o.target]
        local nm = lk and GGUI.loc_raw(lk) or ""
        return GGUI.loc("bounty_obj_build") .. ": " .. (nm ~= "" and nm or tostring(o.target))
    end
    return ""
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

-- THE DRAW WRITES NOTHING. It used to post and purge the board, and a draw runs on one
-- machine - in multiplayer that is a board the others do not have. GG.first_boards posts
-- an empty board at the first tick, turn start withdraws what went stale, and the draw
-- only hides an offer that stopped being true mid-turn (GG.bounty_view).
--
-- GGUI.BOUNTY_AT[card] is the board index that card shows, which is what a click sends.
GGUI.BOUNTY_AT = {}
-- AND ITS GUILD, which is what Take sends: an index named another offer once the board
-- shifted under an open panel (logic audit, 2026-09-29).
GGUI.BOUNTY_GUILD = {}

function GGUI.draw_bounties(faction)
    local turn = GG.turn_now()
    local list = GG.bounties[faction] or {}
    local view = {}
    pcall(function() view = GG.bounty_view(faction) end)
    GGUI.BOUNTY_AT = view
    GGUI.BOUNTY_GUILD = {}
    for i = 1, #GGUI.CARD_XY do
        local card = GGUI.card(i)
        local o = view[i] and list[view[i]]
        GGUI.BOUNTY_GUILD[i] = o and o.guild
        if card and not o and (i > 1 or #view > 0) then
            -- AN EMPTY SLOT IS HIDDEN; an empty board keeps one card saying so, and the
            -- header says when offers come (antislop audit 2026-10-09).
            pcall(function() card:SetVisible(false) end)
        elseif card and not o then
            -- It says so, rather than leaving the previous tab's service text sitting on
            -- a card that no longer means it.
            GGUI.draw_card(faction, i, nil)
            pcall(function() card:SetVisible(true) end)
            set_text(comp("card_desc_1", card), GGUI.loc("bounty_none"))
            set_tooltip(card, GGUI.loc("bounty_help"))
            -- No offer, no button. draw_card blanks the caption but leaves the plate,
            -- which reads as a button that does nothing rather than as an empty slot.
            local eb = comp("card_buy", card)
            if eb then pcall(function() eb:SetVisible(false) end) end
        elseif card then
            GGUI.show_need(card)
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
                pay = pay .. "   " .. GGUI.count(left, "bounty_turns")
            end
            set_text(comp("card_desc_2", card), pay)
            -- THE PLATE IS THE STAKE, as a service card's plate is its favour price
            -- (ruling T10-R1). The gold is already on the pay line.
            local stake = o.stake or 0
            GGUI.set_cost(card, (stake > 0 and not o.taken) and tostring(stake) or "")
            set_tooltip(comp("card_cost", card), GGUI.loc("bounty_stake_tip"))

            local ic = comp("card_icon", card)
            if ic then
                pcall(function()
                    ic:SetVisible(true)
                    ic:SetImagePath(GGUI.icon(o.guild) or "", GGUI.CARD_ICON_INDEX)
                end)
            end

            -- THIS OFFER'S OWN FACTS, NOT THE RULES. The card tooltip used to append the
            -- whole of bounty_help, which is the Help tab's Bounties page again - six
            -- lines under every card, and reported from play as "tooltip too long". What
            -- the card cannot show is the price of failing, so that is the line it keeps,
            -- as a number: the rate moves with the preset and "what finishing it would
            -- have paid" was only true on one of them.
            local guild = GGUI.loc_guild(o.guild)
            local desc = GGUI.loc_raw("missions_localised_description_"
                                      .. GG.offer_mission_key(o, GGUI.me()))
            -- The job texts already open with the guild's name; saying it twice read as
            -- "The Daemonsmiths - The Daemonsmiths have paid...".
            local tip = desc
            if desc == "" then
                tip = guild
            elseif desc:sub(1, #guild) ~= guild then
                tip = guild .. "  -  " .. desc
            end
            local lose = GG.bounty_fail_cost(o, faction)
            if lose > 0 then
                tip = tip .. "||" .. GGUI.fill(GGUI.loc("bounty_fail_tip"), lose)
            end
            -- A CLICK ON THE CARD SHOWS THE TARGET ON THE MAP - said only where there is
            -- somewhere to show, since a dead lord has no position.
            if o.war == 1 then
                tip = tip .. "||" .. GGUI.loc("bounty_war_tip") .. " "
                      .. GGUI.faction_name(GGUI.bounty_owner_now(o)) .. "."
            end
            if GGUI.bounty_pos(o) then tip = tip .. "||" .. GGUI.loc("map_tip") end

            local btn = comp("card_buy", card)
            if btn then
                -- A TAKEN OFFER HAS NO BUTTON AT ALL. These buttons ship `standard` and
                -- `hover` only, so SetDisabled has no inactive state to show and a taken
                -- offer still looked exactly like a live one - reported from play as
                -- "it still lets me take it". The row keeps saying Taken beside the pay.
                pcall(function() btn:SetVisible(not o.taken) end)
                if not o.taken then
                    -- SHORT OF FAVOUR, the Take is greyed and dead, the way a service the
                    -- player cannot afford is, and the tooltip says by how much.
                    local _, fav = GG.get(faction, o.guild)
                    local short = not GG.stake_affordable(faction, o)
                    set_text(btn, GGUI.loc("take"))
                    GGUI.set_live(btn, not short)
                    if short then
                        tip = tip .. "||" .. string.gsub(GGUI.fill(
                            GGUI.loc("bounty_stake_short"), o.stake), "%%m", tostring(fav or 0))
                    end
                end
            end
            set_tooltip(card, tip)
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
    GGUI.fill_card(GGUI.card(i), icon, name, l1, l2, right, button, enabled, tip)
end

-- The same six children on any card, including the pick card on the root.
function GGUI.fill_card(card, icon, name, l1, l2, right, button, enabled, tip)
    if not card then return end
    GGUI.show_need(card)
    set_text(comp("card_name", card), name or "")
    set_text(comp("card_desc_1", card), l1 or "")
    set_text(comp("card_desc_2", card), l2 or "")
    GGUI.set_cost(card, right or "")
    local ic = comp("card_icon", card)
    if ic then
        pcall(function()
            local has = icon ~= nil and icon ~= ""
            ic:SetVisible(has)
            if has then ic:SetImagePath(icon, GGUI.CARD_ICON_INDEX) end
        end)
    end
    local btn = comp("card_buy", card)
    if btn then
        local cap = button or ""
        local show = cap ~= ""
        set_text(btn, cap)
        pcall(function() btn:SetVisible(show) end)
        GGUI.set_live(btn, enabled)
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
-- TURNS LEFT TO PAY, COUNTING THIS ONE: GG.demand_tick expires a demand only once the turn
-- passes its due turn, and "0 turns to pay" on the due turn read as already lost while Pay
-- still worked (logic audit, 2026-09-29).
function GGUI.demand_left(d, turn)
    local left = (d.due or 0) - turn + 1
    if left < 0 then left = 0 end
    return left
end

function GGUI.draw_court(faction)
    local guild = GGUI.current_guild()
    local turn = GG.turn_now()

    -- NO LOAD HERE. The panel draws on one machine, and a patron it read back from the
    -- save changed the till's price on that machine only - a multiplayer desync. The
    -- model restores every record at the first tick (GG.load_all).

    -- ------------------------------------------------------------ the demand ---
    local d = GG.demands[faction]
    if d then
        local ok = GG.demand_payable(faction)
        local unit = (d.kind == "tribute") and GGUI.loc("demand_gold")
                     or GGUI.loc("demand_favour")
        local left = GGUI.demand_left(d, turn)
        -- The amount is in the price box beside Pay; the line says what it is paid in
        -- (antislop audit 2026-10-09: the figure showed twice).
        local l1 = GGUI.loc("demand_owed") .. " " .. unit
        if d.kind == "renounce" and GG.RIVALS[d.guild] then
            l1 = l1 .. "  (" .. GGUI.loc_guild(GG.RIVALS[d.guild]) .. ")"
        end
        -- The deadline goes orange (LOCK_COL) in its last two turns. It is the only number
        -- on this panel with a point of no return behind it. 0 left is the turn it is due,
        -- not a lapsed one, and 1 is singular (antislop audit 2026-10-09).
        local l2 = left .. " " .. GGUI.loc("demand_due")
        if left <= 0 then
            l2 = GGUI.loc("demand_due_now")
        elseif left == 1 then
            l2 = "1 " .. GGUI.loc("demand_due_1")
        end
        if left <= 2 then l2 = "[[col:" .. GGUI.LOCK_COL .. "]]" .. l2 .. "[[/col]]" end
        local tip = GGUI.loc_guild(d.guild) .. "  -  "
                    .. GGUI.loc("demand_desc_" .. d.kind)
        if not ok then tip = tip .. "||" .. GGUI.loc("demand_short") end
        -- ITS OWN PART OF THE RULES, not all three: the whole Court text under every card
        -- was 17 lines of tooltip (2026-09-28). The Help tab's Court page has the rest.
        tip = tip .. "||" .. GGUI.loc("court_help_demand")
        GGUI.write_card(1, GGUI.icon(d.guild),
                        GGUI.loc_guild(d.guild) .. "   "
                        .. GGUI.loc("demand_name_" .. d.kind),
                        l1, l2, tostring(d.amount or 0),
                        GGUI.loc("demand_pay"), ok == true, tip)
    else
        GGUI.write_card(1, nil, GGUI.loc("demand_none"), "", "", "", "", false,
                        GGUI.loc("court_help_no_demand"))
    end

    -- ------------------------------------------------------------ the patron ---
    local p = GG.patrons[faction]
    local holds_this = p ~= nil and p.guild == guild
    if holds_this then
        GGUI.write_card(2, GGUI.icon(guild),
                        GGUI.loc("patron_of") .. ": " .. GGUI.loc_guild(guild),
                        GGUI.patron_name(p.cqi),
                        "+" .. (GG.setting("rate_patron") or 0) .. "% "
                        .. GGUI.loc("reputation") .. "   -"
                        .. GG.FAVOUR_PATRON .. "% " .. GGUI.loc("cost_label"),
                        "", GGUI.loc("patron_dismiss"), true,
                        GGUI.loc("court_help_patron"))
    else
        local sel = GGUI.patron_cqi(faction)
        -- ONE ACCOUNT OF ITSELF, AND THE GUILD'S GLYPH (antislop audit 2026-10-09): "No
        -- patron appointed" sat over "Your patron already serves another guild", and the
        -- card was the only one on the tab with an empty holder.
        local l1, l2 = GGUI.loc("patron_none"), GGUI.loc("patron_needs_char")
        if p then l1, l2 = GGUI.loc("patron_elsewhere"), "" end
        -- NOBODY SELECTED: the button picks a lord instead of sitting greyed out.
        GGUI.write_card(2, GGUI.icon(guild),
                        GGUI.loc("patron_of") .. ": " .. GGUI.loc_guild(guild),
                        l1, l2, "",
                        GGUI.loc(sel and "patron_appoint" or "pick_button"), true,
                        GGUI.loc("court_help_patron"))
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
    GGUI.write_card(3, GGUI.icon(guild),
                    GGUI.loc_guild(guild) .. "   " .. GGUI.loc("lead_title"),
                    line,
                    GGUI.loc("you") .. ": " .. mine .. "   "
                    .. GGUI.loc("leader") .. ": " .. (who_rep or 0),
                    "", "", false,
                    GGUI.table_lines(guild, faction) .. "||"
                    .. GGUI.loc("court_help_lead"))
end

-- THE UPKEEP LINE of the rank hover: the charge when there is one, the turn it begins
-- only while it has not (a guild at 0 reputation owes nothing, and that 0 said "begins on
-- turn 25" at turn 40 - logic audit, 2026-09-29), and the rule either way.
function GGUI.upkeep_tip(upkeep, turn)
    local drate = GG.setting("rate_decay") or 0
    local dfrom = GG.setting("decay_from") or 0
    if drate <= 0 or dfrom <= 0 then return "" end
    if upkeep > 0 then
        return "||" .. GGUI.loc("upkeep_on") .. " -" .. upkeep .. GGUI.loc("per_turn")
               .. ". " .. GGUI.loc("upkeep_help")
    elseif not GG.decay_due(turn) then
        return "||" .. GGUI.loc("upkeep_soon") .. " " .. dfrom .. ". "
               .. GGUI.loc("upkeep_help")
    end
    return "||" .. GGUI.loc("upkeep_help")
end

-- WHY THE TOP OF THE TABLE IS NOT THE LEADER: the holder keeps a guild until out-earned
-- by more than a turn's movement, and the table showed a rival first under a leader's
-- name with nothing to say why (logic audit, 2026-09-29). A loc key, or "".
function GGUI.lead_note(guild, faction)
    local culture = GG.culture_of(faction)
    local rows = GG.contenders(guild, culture) or {}
    local top = rows[1] and rows[1].faction
    local who = GG.leader_of(guild, culture)
    if top and who and top ~= who then return "lead_held" end
    return ""
end

function GGUI.refresh()
    -- Forced local-faction read. An unforced get_local_faction_name THROWS in
    -- multiplayer, and a local-faction call at script root CTDs uncatchably.
    local ok, faction = pcall(function() return cm:get_local_faction_name(true) end)
    if not ok or not faction then return end
    if not comp(GGUI.PANEL) then return end

    -- WHAT THE RIVALS DID is restored by the model at the first tick (GG.load_all), on
    -- every machine; the panel reads it and loads nothing (logic audit, 2026-09-29).

    GGUI.layout()
    -- The ground follows whichever guild the panel is showing, so paging the Guilds tab
    -- or picking a row on Standings changes the hall behind the text.
    GGUI.paint_ground(GGUI.ground_guild())
    GGUI.paint_crest()
    -- The header's round holder carries the glyph of the guild whose hall is behind it,
    -- and the panel's crest on Bounties, Help and Log, which are about no one guild
    -- (antislop audit 2026-10-09).
    local ri = comp("gg_rank_mark")
    if ri then
        local whole = GGUI.TAB == 3 or GGUI.TAB == 5 or GGUI.TAB == 6
        pcall(function()
            ri:SetImagePath(whole and GGUI.art(GGUI.CREST)
                            or GGUI.icon(GGUI.ground_guild()) or "", GGUI.RANK_ICON_INDEX)
        end)
    end
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
        local t = comp(tabs[i])
        if t then GGUI.paint_tab(t, i == GGUI.TAB) end
    end
    set_named_text("gg_prev", GGUI.loc("prev"))
    set_named_text("gg_next", GGUI.loc("next"))
    set_tooltip(comp("gg_title"), GGUI.loc("standing_help"))

    local guild = GGUI.current_guild()
    local rep, fav = GG.get(faction, guild)
    local rank = GG.rank_of(rep)
    local next_at = GG.RANKS[math.min(rank + 1, #GG.RANKS)]

    -- ONLY THE GUILDS TAB SHOWS ONE GUILD AT A TIME, so only the Guilds tab has
    -- anything for the pager to page. Standings lists every guild, the bounty board pools
    -- its three offers from every guild, and Help is prose - on those three the arrows
    -- moved one word in the header and nothing else, which reads as a dead button.
    -- THE COURT PAGES TOO. Two of its three cards are about one guild - the patron is
    -- appointed to a named guild and leadership is held of a named guild - so the arrows
    -- do exactly what they do on the Guilds tab. Standings lists every guild, the board
    -- pools from all of them and Help is prose; on those three the arrows moved one word.
    -- THE LOG PAGES TOO, newest first, a slot-page at a time.
    local paged = (GGUI.TAB == 1 or GGUI.TAB == 4 or GGUI.TAB == 5 or GGUI.TAB == 6)
    for _, n in ipairs({"gg_prev", "gg_next"}) do
        local b = comp(n)
        if b then pcall(function() b:SetVisible(paged) end) end
    end
    -- WHERE EACH ARROW GOES, so paging is not a guess. See GGUI.pager_tips.
    if paged then
        local back, fwd = GGUI.pager_tips(faction)
        set_tooltip(comp("gg_prev"), back)
        set_tooltip(comp("gg_next"), fwd)
    end
    GGUI.draw_guild_buttons(faction)
    GGUI.draw_log_filters()

    if paged and GGUI.TAB == 1 then
        -- The bare "340 / 700" said nothing about WHICH number it was. Naming it is
        -- the difference between two numbers on screen and a mechanic a player can read.
        -- EVERYTHING THAT TAKES REPUTATION AWAY IS NAMED HERE, in red, because a number
        -- that falls with no visible reason is a bug report. There are two of them: the
        -- rival, and the upkeep.
        local line = GGUI.loc_rank(rank) .. "   "
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
            upkeep = GG.decay_amount(rank, faction)
        end
        if upkeep > 0 then
            -- NOT COLOURED (2026-10-04): red, then CA's orange, measured under 4.5:1 on the
            -- Empire's lighter bar. The words carry it, and the hover says the rest.
            line = line .. "   -" .. upkeep .. GGUI.loc("per_turn")
        end
        local head, tag = GGUI.loc_guild(guild), GG.tag(faction)
        -- THE RIVAL GIVES WAY BEFORE IT OVERLAPS: its full name, then without the article,
        -- then into the hover. Unmeasurable keeps it on the bar, as it always was.
        local rival_tip = ""
        local rival = GG.RIVALS[guild]
        local share = GG.setting("rate_rivalry") or 0
        if rival and share > 0 then
            local name = GGUI.loc_guild(rival)
            local full = line .. "   " .. GGUI.loc("rival") .. " " .. name
            local short = line .. "   " .. GGUI.loc("rival") .. " "
                          .. (string.gsub(name, "^The ", ""))
            if GGUI.header_fits(head, full, tag) ~= false then
                line = full
            elseif GGUI.header_fits(head, short, tag) then
                line = short
            else
                rival_tip = "||" .. GGUI.loc("rival") .. " " .. name
            end
        end
        -- HALLS STANDING for this guild, once there is one (GG.count_halls, turn start).
        --
        -- IN THE HEADER ONLY WHERE IT FITS, measured (GGUI.header_fits); otherwise, and
        -- whenever the engine will not measure, in the hover.
        local hh = GG.halls[faction] and GG.halls[faction][guild]
        local halls_tip = ""
        if hh and hh.n > 0 and GG.setting("guild_halls") ~= false then
            local stat = string.format(GGUI.loc("halls_stat"), hh.n)
            local with = line .. "   " .. stat
            if GGUI.header_fits(head, with, tag) then
                line = with
            else
                halls_tip = "||" .. stat
            end
        end
        -- THE GUILD'S OWN DESCRIPTION, then what the upkeep is and when it starts. Said
        -- even before it bites, so a player reads the rule in the first twenty turns
        -- rather than discovering it as a rank quietly going backwards on turn 26.
        local tip = GGUI.loc_guild_desc(guild)
        tip = tip .. GGUI.upkeep_tip(upkeep, GG.turn_now()) .. rival_tip .. halls_tip
        set_header(head, line, tip)
        -- WHAT THIS GUILD PAID, AND FOR WHAT. See GGUI.earned_line.
        local now, last = GG.earned(faction)
        set_named_text("gg_earned", GGUI.earned_line(now, last, guild))
        set_tooltip(comp("gg_earned"), GGUI.earned_tip(now, last, guild, faction))
    elseif GGUI.TAB == 5 then
        -- The Help tab's header is its table of contents: which chapter, and how many
        -- there are, so the arrows read as pages rather than as something that might
        -- change the subject.
        set_header(GGUI.loc("help_t" .. GGUI.HELP_PAGE),
                   GGUI.loc("hdr_help") .. "   " .. GGUI.HELP_PAGE .. " "
                   .. GGUI.loc("help_of") .. " " .. GGUI.help_page_count(),
                   GGUI.loc("standing_help"))
    elseif GGUI.TAB == 6 then
        set_header(GGUI.loc("tab_log"),
                   GGUI.loc("hdr_log") .. "   " .. GGUI.LOG_PAGE .. " "
                   .. GGUI.loc("help_of") .. " " .. GGUI.log_pages(faction),
                   GGUI.loc("log_help"))
    elseif GGUI.TAB == 4 then
        -- The Court pages, but its header names the guild the arrows are pointing at,
        -- because two of its three cards are about that guild. NO TAGLINE in the figures:
        -- "The Daemonsmiths" beside it plus a four-digit reputation ran the two cells into
        -- each other in game (2026-10-04); the tab button names the view already.
        set_header(GGUI.loc_guild(guild),
                   GGUI.loc_rank(rank) .. "   " .. GGUI.loc("reputation") .. " " .. rep,
                   GGUI.loc("court_intro"))
    else
        -- A header that names the view, not a guild the view does not show. The
        -- bounty count is live because it is the one number a player wants before
        -- reading three cards.
        local head = GGUI.loc("hdr_help")
        if GGUI.TAB == 2 then
            -- THE LEAGUE TABLE'S HEADER IS THE SCOREBOARD'S CLOCK. "The Standings" on
            -- its own said nothing about whether anybody else was playing; this line
            -- is the one place in the mod that says out loud that they are.
            head = GGUI.rivals_line()
        elseif GGUI.TAB == 3 then
            local list, taken = GG.bounties[faction] or {}, 0
            for i = 1, #list do
                if list[i].taken then taken = taken + 1 end
            end
            head = GGUI.loc("hdr_bounty") .. "   " .. taken .. " / "
                   .. #GGUI.CARD_XY .. " " .. GGUI.loc("bounty_taken")
            local view = {}
            pcall(function() view = GG.bounty_view(faction) end)
            if #view == 0 then
                local ok, pay = pcall(GG.bounty_pay)
                head = GGUI.loc((ok and pay <= 0) and "bounty_off" or "bounty_next")
            end
        end
        -- The Standings header carries the rivals' line, so its hover explains that
        -- rather than repeating the general standing rules a hover away on the title.
        -- "Hover a row for the full table" leads that hover now: the figures took its room.
        local tab_key = GGUI.TAB == 2 and "tab_stand" or "tab_bounty"
        local tip = GGUI.loc(GGUI.TAB == 2 and "rivals_help" or "standing_help")
        if GGUI.TAB == 2 then tip = GGUI.loc("hdr_stand") .. "||" .. tip end
        set_header(GGUI.loc(tab_key), head, tip)
    end
    -- THE COUNTDOWN (spec §9), here because the footer carries one short number on a
    -- 750px line; the rank and earned lines are full.
    local every = GG.rotation_turns()
    -- THE GUILD ON SCREEN: the Leaderboard shows the selected row's (logic audit), and the
    -- figure names it. Bounties, Help and Log show no one guild, so no Favour figure
    -- (antislop audit 2026-10-09: it read 0 on Bounties and 150 on the Leaderboard).
    local foot = GGUI.countdown(every - GG.turn_now() % every)
    if not (GGUI.TAB == 3 or GGUI.TAB == 5 or GGUI.TAB == 6) then
        local g = GGUI.ground_guild()
        foot = GGUI.loc_guild(g) .. " " .. GGUI.loc("favour") .. ": "
               .. select(2, GG.get(faction, g)) .. "   " .. foot
    end
    set_named_text("gg_footer", foot)
    set_tooltip(comp("gg_footer"), GGUI.loc("standing_help"))

    -- The bar is the rank line's picture, so it must agree with it. SetCanResizeWidth
    -- has to be set before Resize or the call is ignored; this is the same idiom the
    -- Exchange's sparkline bars use. Resize AFTER GGUI.layout above, which MoveTo's it.
    -- THE BAR FOLLOWS THE RANK LINE, not the pager. The Court pages but draws its own
    -- header, so a bar under it would be measuring a line that is not there.
    local barred = (GGUI.TAB == 1)
    local track = comp("gg_bar_track")
    if track then pcall(function() track:SetVisible(barred) end) end
    local earned = comp("gg_earned")
    if earned then pcall(function() earned:SetVisible(GGUI.TAB == 1) end) end
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
                bar:Resize(GGUI.px(w), GGUI.px(GGUI.REP_BAR_H), false)
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
        -- UNLIT FIRST. The bounty board and the Court reuse these three cards, so a glow
        -- left from the Guilds tab would light a bounty. draw_card relights its own.
        GGUI.light_card(card, false)
    end
    for i = 1, #GG.GUILDS do
        local row = comp(GGUI.ROW .. "_" .. i, comp(GGUI.PANEL))
        if row then pcall(function() row:SetVisible(GGUI.TAB == 2) end) end
    end
    local list = comp(GGUI.LIST, comp(GGUI.PANEL))
    if list then pcall(function() list:SetVisible(GGUI.TAB == 2) end) end
    for name, on in pairs({gg_back_list = GGUI.TAB == 2,
                           gg_back_text = GGUI.TAB == 5 or GGUI.TAB == 6}) do
        local c = comp(name)
        if c then pcall(function() c:SetVisible(on) end) end
    end
    -- THE LOG DRAWS INTO THE HELP TAB'S 21 SLOTS. Both are pages of single lines, and
    -- one set of slots is one set of components to keep placed.
    for i = 1, GGUI.HELP_SLOTS do
        local h = comp(string.format("gg_help_%02d", i))
        if h then pcall(function() h:SetVisible(GGUI.TAB == 5 or GGUI.TAB == 6) end) end
        local hh = comp(string.format("gg_helph_%02d", i))
        if hh then pcall(function() hh:SetVisible(GGUI.TAB == 5) end) end
    end

    if GGUI.TAB == 1 then
        local mine = GGUI.services_of(guild, faction)
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
GGUI.HELP_PAGES  = 6
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
            -- \2 marks it for draw_help, which writes it to the header_14 cell.
            push("\2[[col:yellow]]" .. string.sub(seg, 2) .. "[[/col]]")
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
        local l = lines[i] or ""
        local head = string.sub(l, 1, 1) == "\2"
        set_text(comp(string.format("gg_help_%02d", i)), head and "" or l)
        set_text(comp(string.format("gg_helph_%02d", i)), head and string.sub(l, 2) or "")
    end
end

-- ------------------------------------------------------------------ the log --
-- The Log tab. GG.log_entries holds keys and numbers, written from turn handlers; this is
-- the only place they become words. Newest first, a page of the Help tab's slots at a time.
GGUI.LOG_PAGE = 1

-- WHAT A BOUNTY ON YOU NAMED, at draw time (2026-09-29). A number is a character, named
-- off its own name keys while it can still be read; anything else is a region.
function GGUI.hunt_target(a)
    if tonumber(a) then
        local name = ""
        pcall(function()
            local c = cm:get_family_member_by_cqi(tonumber(a)):character()
            if not c or c:is_null_interface() then return end
            name = GGUI.loc_raw(c:get_forename())
            local sn = GGUI.loc_raw(c:get_surname())
            if sn ~= "" then name = (name ~= "" and (name .. " ") or "") .. sn end
        end)
        if name ~= "" then return name end
        return GGUI.loc("log_your_char")
    end
    local r = GGUI.loc_raw("regions_onscreen_" .. tostring(a))
    if r ~= "" then return r end
    return tostring(a)
end

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
    elseif k == "refund" then
        -- GG.refund_purchase: the service could not be delivered and the favour went back.
        bad = true
        body = GGUI.loc_service(e.a) .. " " .. GGUI.loc("log_refunded") .. " (" .. e.b
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
        -- NOBODY TOOK IT: the reputation drained away (logic audit, 2026-09-29).
        if e.a == "" then
            body = GGUI.loc("log_lead_lapsed")
        else
            body = GGUI.loc("log_lead_lost") .. " " .. GGUI.faction_name(e.a)
        end
    -- RIVALS' BOUNTIES (2026-09-29). A price put on you, or collected, is bad news; one
    -- that failed or was withdrawn is not.
    elseif k == "hunted" then
        bad = true
        body = GGUI.loc("log_hunted") .. " " .. GGUI.hunt_target(e.a) .. ", "
               .. GGUI.loc("log_for") .. " " .. GGUI.faction_name(e.b)
    elseif k == "hunt_done" then
        bad = true
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_hunt_done") .. " "
               .. GGUI.hunt_target(e.a)
    elseif k == "hunt_failed" then
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_hunt_failed") .. " "
               .. GGUI.hunt_target(e.a) .. ", " .. GGUI.loc("log_hunt_lost")
    elseif k == "hunt_void" then
        body = GGUI.loc("log_hunt_void") .. " " .. GGUI.hunt_target(e.a)
    elseif k == "ai_bounty" then
        body = GGUI.faction_name(e.b) .. " " .. GGUI.loc("log_ai_bounty") .. " " .. e.a
               .. " " .. GGUI.loc("reputation")
    elseif k == "earn" then
        -- A RACE EARNING (stage 2): what the race did and what the guild gained for it.
        body = GGUI.loc("log_earn_" .. e.a) .. " (+" .. e.b .. " " .. GGUI.loc("reputation")
               .. ")"
    elseif k == "rotation" then
        -- NO GUILD: every guild's services changed at once, so no guild prefix.
        return GGUI.loc("log_turn") .. " " .. e.turn .. "   " .. GGUI.loc("log_rotation")
               .. ".", false
    else
        return nil
    end
    return GGUI.loc("log_turn") .. " " .. e.turn .. "   " .. GGUI.loc_guild(e.guild)
           .. ":  " .. body .. ".", bad
end

-- Every line the log would draw, wrapped against `ruler`. THE COLOUR GOES ON AFTER THE
-- WRAP, one pair of tags per line: GGUI.wrap splits on spaces, so a [[col:]] opened on
-- one line and closed on the next would be a guess about the renderer.
-- WHICH ENTRIES THE LOG SHOWS. A long campaign's log is mostly rivals buying things; a
-- player looking for when they lost a rank had to page through all of it.
GGUI.LOG_FILTER = "all"
GGUI.LOG_FILTER_BTN = "gg_lf_"
GGUI.LOG_FILTER_ORDER = {"all", "mine", "rivals", "ranks"}
GGUI.LOG_FILTERS = {
    mine   = {buy = true, refund = true, rank = true, lead_won = true, rotation = true, earn = true},
    rivals = {ai_buy = true, hit = true, lead_lost = true, hunted = true, hunt_done = true,
              hunt_failed = true, hunt_void = true, ai_bounty = true},
    ranks  = {rank = true, lead_won = true, lead_lost = true},
}

-- The four buttons above the Log. Literal keys, one per filter, so the generator's loc
-- check can see every one of them.
function GGUI.draw_log_filters()
    local label = {all = GGUI.loc("lf_all"), mine = GGUI.loc("lf_mine"),
                   rivals = GGUI.loc("lf_rivals"), ranks = GGUI.loc("lf_ranks")}
    for _, f in ipairs(GGUI.LOG_FILTER_ORDER) do
        local b = comp(GGUI.LOG_FILTER_BTN .. f)
        if b then
            pcall(function() b:SetVisible(GGUI.TAB == 6) end)
            local t = label[f]
            if f == GGUI.LOG_FILTER then t = "[[col:yellow]]" .. t .. "[[/col]]" end
            set_text(b, t)
        end
    end
end

function GGUI.log_lines(me, ruler)
    local out = {}
    local entries = GG.log_entries(me)
    local keep = GGUI.LOG_FILTERS[GGUI.LOG_FILTER]
    for i = 1, #entries do
        local text, bad
        if not keep or keep[entries[i].kind] then text, bad = GGUI.log_text(entries[i]) end
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
    -- which is why it was removed. An empty FILTER says that instead, or a player with a
    -- full log reads "nothing yet" and thinks it was lost.
    if #out == 0 then
        out[1] = GGUI.loc((keep and #entries > 0) and "log_empty_filter" or "log_empty")
    end
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
        -- GG.state - so the player led every guild at 0 reputation.
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
-- A COUNT AND ITS NOUN, the noun's _1 key for one (antislop audit 2026-10-09), as
-- next_services_1 already did.
function GGUI.count(n, key)
    n = n or 0
    local k = key
    if n == 1 then k = key .. "_1" end
    return n .. " " .. GGUI.loc(k)
end

function GGUI.rivals_line()
    local w = GG.world
    if not w or (w.turn or 0) == 0 then return GGUI.loc("rivals_idle") end
    return GGUI.loc("rivals") .. " " .. GGUI.count(w.bought, "rivals_bought") .. ", "
           .. GGUI.count(w.demands, "rivals_demands") .. ", "
           .. GGUI.count(w.patrons, "rivals_patrons")
end

-- WHAT THIS GUILD PAID YOU, AND FOR WHAT: the line under the Guilds tab's three cards,
-- read off GG.earned. A finished building pays in script, not through an effect, so this
-- is where a player sees the forge they built pay the smiths.
--
-- AT MOST THREE SOURCES ON THE LINE, biggest first: 750px is about a hundred characters
-- and one guild can be paid from seven places in a turn. The hover carries all of them.
-- "withheld" is what the per-turn limit kept back - reputation you do NOT have - so it
-- never goes into the total and is shown apart, in red.
GGUI.EARNED_SHOWN = 3

local function earned_parts(by)
    local parts, total = {}, 0
    for i = 1, #GG.LEDGER_SOURCES do
        local s = GG.LEDGER_SOURCES[i]
        local n = by and by[s]
        if n and n > 0 and s ~= "withheld" then
            parts[#parts + 1] = {s = s, n = n, i = i}
            total = total + n
        end
    end
    table.sort(parts, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.i < b.i
    end)
    return parts, total, (by and by.withheld) or 0
end

local function source_text(p) return GGUI.loc("src_" .. p.s) .. " " .. p.n end

function GGUI.earned_line(now, last, guild)
    local parts, total, held = earned_parts(now[guild])
    local line = GGUI.loc("earned_now") .. " "
    if total == 0 then
        line = line .. GGUI.loc("earned_none")
    else
        local shown = {}
        for i = 1, math.min(#parts, GGUI.EARNED_SHOWN) do
            shown[i] = source_text(parts[i])
        end
        if #parts > GGUI.EARNED_SHOWN then shown[#shown + 1] = GGUI.loc("earned_more") end
        line = line .. "+" .. total .. " (" .. table.concat(shown, ", ") .. ")"
    end
    if held > 0 then
        line = line .. "   [[col:red]]" .. held .. " " .. GGUI.loc("earned_held") .. "[[/col]]"
    end
    local _, ltotal = earned_parts(last[guild])
    return line .. "   " .. GGUI.loc("earned_last") .. " "
           .. (ltotal > 0 and ("+" .. ltotal) or GGUI.loc("earned_none"))
end

function GGUI.earned_tip(now, last, guild, faction)
    local function block(head, by)
        local parts, total, held = earned_parts(by)
        local out = head .. " " .. (total > 0 and ("+" .. total) or GGUI.loc("earned_none"))
        for i = 1, #parts do out = out .. "||   " .. source_text(parts[i]) end
        if held > 0 then
            out = out .. "||   [[col:red]]" .. GGUI.loc("src_withheld") .. " " .. held
                  .. "[[/col]]"
        end
        return out
    end
    local cap = GG.guild_cap(guild, faction)
    local limit = GGUI.loc("earned_no_limit")
    if cap > 0 then
        limit = GGUI.loc("earned_limit") .. " " .. cap .. ". " .. GGUI.loc("earned_help")
    end
    return block(GGUI.loc("earned_now"), now[guild]) .. "||"
           .. block(GGUI.loc("earned_last"), last[guild]) .. "||" .. limit
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
function GGUI.flag_img(faction)
    local flag = GG.FLAG_OF[faction]
    local img = (type(flag) == "string" and flag ~= "")
                and (flag .. "/mon_24.png") or GGUI.FLAG_FALLBACK
    return "[[img:" .. img .. "]][[/img]]"
end

function GGUI.frow_text(r, me)
    local who = (r.faction == me) and GGUI.loc("you") or GGUI.faction_name(r.faction)
    local body = r.pos .. ".  " .. who .. "   " .. r.rep .. "   "
                 .. GGUI.loc_rank(GG.rank_of(r.rep))
    if r.faction == me then
        body = "[[col:yellow]]" .. body .. "[[/col]]"
    end
    return GGUI.flag_img(r.faction) .. "  " .. body
end

-- WHO LEADS, in the Leaderboard's third column: "Leader:" and the leader's flag. A
-- rival's name and rank follow the flag; yours does not, because the flag is yours and
-- the column to the left already gives your rank. The yellow changed-hands mark and the
-- round's gain wrap only the text, never the flag, for the reason frow_text gives.
--
-- detail 2 is the name and rank, 1 the name alone, 0 the flag alone; see leader_fit.
function GGUI.leader_text(L, me, moved, gain, detail)
    detail = detail or 2
    local body = ""
    if not L.faction_key then
        body = GGUI.loc("nobody")
    elseif L.faction_key ~= me and detail > 0 then
        body = GGUI.faction_name(L.faction_key)
        if detail > 1 then body = body .. " (" .. GGUI.loc_rank(L.rank) .. ")" end
    end
    if moved and body ~= "" then body = "[[col:yellow]]" .. body .. "[[/col]]" end
    gain = gain or 0
    if gain ~= 0 then
        body = body .. (gain > 0 and "   [[col:green]]+" or "   [[col:red]]")
               .. gain .. "[[/col]]"
    end
    if not L.faction_key then return GGUI.loc("leader") .. ": " .. body end
    return GGUI.loc("leader") .. ": " .. GGUI.flag_img(L.faction_key) .. "  " .. body
end

-- A string with its [[img:]] and [[col:]] markup taken out, for measuring.
function GGUI.bare(s)
    return (s:gsub("%[%[img:.-%]%]%[%[/img%]%]", ""):gsub("%[%[/?col[^%]]*%]%]", ""))
end

-- THE FLAG'S WIDTH, charged by hand: whether TextDimensionsForText reads [[img:]] as a
-- picture or as fifty characters of path is not in CA's reference, so the markup is
-- stripped before measuring and the flag is paid for here, in design pixels.
GGUI.FLAG_W = 30

-- THE LONGEST LEADER LINE THAT FITS ITS CELL. Nothing in this engine wraps, and the
-- longest real rival line - "The Huntsmarshal's Expedition (Grand Master)   +120" with
-- the flag - is about 460px against a 324px column, so it would run out past the
-- panel's edge. The rank goes first, then the name: the flag still says who, and the
-- row's hover names everyone. Measured the way GGUI.wrap measures.
function GGUI.leader_fit(c, L, me, moved, gain)
    local ok_w, w = pcall(function() return c:Dimensions() end)
    if not ok_w or type(w) ~= "number" or w <= 0 then
        return GGUI.leader_text(L, me, moved, gain)
    end
    local r = GGUI.text_ratio()
    w = w * r / GGUI.S
    local s
    for detail = 2, 0, -1 do
        s = GGUI.leader_text(L, me, moved, gain, detail)
        local ok, need = pcall(function() return c:TextDimensionsForText(GGUI.bare(s)) end)
        if not ok or type(need) ~= "number" or need + GGUI.FLAG_W * r <= w then
            return s
        end
    end
    return s
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
-- WHICH FACTION EACH ROW IS, by row number, for the click. A row is one text component
-- with no data behind it, so the click reads the faction back from here.
GGUI.LIST_FACTIONS = {}

function GGUI.draw_faction_list(faction)
    local rows, guild = GGUI.list_rows(faction)
    GGUI.LIST_LAST = #rows
    GGUI.LIST_FACTIONS = {}
    for i = 1, #rows do GGUI.LIST_FACTIONS[i] = rows[i].faction end

    local list = comp(GGUI.LIST, comp(GGUI.PANEL))
    if not list then return end
    local box = comp("list_box", list)
    if not box then return end
    pcall(function() box:DestroyChildren() end)

    for i = 1, #rows do
        local name = GGUI.FROW .. "_" .. i
        local ok = pcall(function() box:CreateComponent(name, GGUI.PATH_FROW .. GGUI.SUFFIX) end)
        local fr = ok and comp(name, box) or nil
        if fr then
            -- Created after open() scaled the panel, so it is scaled here, once.
            GGUI.scale_tree(fr)
            set_text(fr, GGUI.frow_text(rows[i], faction))
            -- A click shows their capital, promised only for a faction that has one.
            local tip = GGUI.loc_guild(guild) .. "  " .. GGUI.faction_name(rows[i].faction)
            if GGUI.faction_pos(rows[i].faction) then
                tip = tip .. "||" .. GGUI.loc("frow_map")
            end
            set_tooltip(fr, tip)
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
            local ic = comp("row_icon", row)
            if ic then
                pcall(function() ic:SetImagePath(GGUI.icon(L.guild) or "", 0) end)
                -- The one part of the row that does something else: it opens the guild.
                set_tooltip(ic, GGUI.loc("open_guild"))
            end
            -- LABELLED, because the row had three naked fragments in it: the guild,
            -- a rank with a number after it, and a second rank belonging to somebody
            -- else. Nothing said which of the two ranks was yours.
            set_text(comp("row_rank", row),
                     GGUI.loc("you") .. ": " .. GGUI.loc_rank(GG.rank_of(rep))
                     .. " (" .. rep .. ")" .. GGUI.position_tag(faction, L.guild))
            -- YELLOW WHEN THE GUILD CHANGED HANDS ON THE ROUND JUST PAST. A name that
            -- is merely different from the last time you opened the panel says nothing
            -- about when it changed; the mark is the difference between a scoreboard
            -- and a scoreboard you can watch. [[col:]] works in SetStateText and
            -- "yellow" is one of CA's 42 real colour names.
            local slot = GG.lead_slot(L.guild, GG.culture_of(faction))
            -- AND WHAT THE LEADER GAINED ON IT. This is the race's speed: a rival
            -- pulling away shows a number every round whether or not the name above it
            -- ever changes. Usually positive, because earning only adds - but a
            -- rivalry drain, a penalty or an expired demand can take it back, so the
            -- sign is read rather than assumed. Zero prints nothing rather than "+0",
            -- which is clutter on every row.
            local gain = (w.gain or {})[slot] or 0
            local cell = comp("row_leader", row)
            set_text(cell, GGUI.leader_fit(cell, L, faction, w.moved and w.moved[slot], gain))
            -- The league table is where a player decides which guild to chase, so
            -- each row carries what that guild is and what its ladder pays - and, when
            -- there is movement to explain, what the marks on it mean.
            -- THE TABLE, and not what the guild is. The row already says who leads and
            -- where you sit; the hover is the only place with room for the names between
            -- you, which is the whole of what a scoreboard is for. The guild's own
            -- description followed it and made 14 lines (2026-09-28); it is one click
            -- away, on the Guilds tab's rank line.
            local tip = GGUI.table_lines(L.guild, faction)
            if L.faction_key and GG.has_seat(L.faction_key, L.guild) then
                tip = tip .. "||" .. GGUI.loc("holds_seat")
            end
            local note = GGUI.lead_note(L.guild, faction)
            if note ~= "" then tip = tip .. "||" .. GGUI.loc(note) end
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

-- GGUI.HELP_PAGES is the count every race has; a race with halls reads one chapter more.
function GGUI.help_page_count()
    local me = GGUI.me()
    if me and GG.halls_here(me) and GG.setting("guild_halls") ~= false then
        return GGUI.HELP_PAGES + 1
    end
    return GGUI.HELP_PAGES
end

function GGUI.page_max()
    if GGUI.TAB == 5 then return GGUI.help_page_count() end
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
    GGUI.CONFIRM = nil
    GGUI.refresh()
end

function GGUI.set_tab(n)
    GGUI.TAB = n
    GGUI.CONFIRM = nil
    GGUI.refresh()
end

-- HOW MANY OF A GUILD'S SERVICES CAN BE BOUGHT NOW, by the same gate as the badge.
function GGUI.ready_in(faction, guild)
    local n, mine = 0, GGUI.services_of(guild, faction)
    for i = 1, #mine do
        local ok, can = pcall(function() return GG.can_buy(faction, mine[i].key) end)
        if ok and can then n = n + 1 end
    end
    return n
end

-- A guild's name and, when there is any, what is ready in it. The arrows and the guild
-- buttons both say this, so they say it the same way.
function GGUI.guild_tip(faction, guild)
    local t = GGUI.loc_guild(guild)
    local n = GGUI.ready_in(faction, guild)
    if n > 0 then t = t .. "  -  " .. n .. " " .. GGUI.loc("ready") end
    return t
end

-- WHAT EACH ARROW DOES, as (left, right). The Guilds and Court tabs page guilds, so an
-- arrow names the guild it goes to; Help and the Log page pages. An arrow at the end of
-- the run says so, because set_page clamps and a click there does nothing.
function GGUI.pager_tips(faction)
    local n, max = GGUI.page_now(), GGUI.page_max()
    local function tip(to)
        if to < 1 or to > max then return GGUI.loc("pager_end") end
        if GGUI.TAB == 5 or GGUI.TAB == 6 then
            return GGUI.loc(to > n and "pager_page_next" or "pager_page_prev")
        end
        return GGUI.guild_tip(faction, GGUI.GUILD_ORDER[to])
    end
    return tip(n - 1), tip(n + 1)
end

-- ONE CLICK TO ANY GUILD. The arrows walk six pages one at a time; these jump. Each button
-- is the guild's own glyph with the badge's gold count in its corner, and a bar marks the
-- page on screen. Only where the pager pages guilds - Guilds and Court.
GGUI.GUILD_BTN = "gg_gtab_"
GGUI.GUILD_SEL = "gg_gsel"
-- WHICH OF THE BUTTON'S IMAGES IS THE GLYPH: 0 is the round plate under it, which gives
-- the gold count a dark rim to sit on. gen_guilds_ui.check() pins this against the layers.
GGUI.GUILD_BTN_ICON = 1

function GGUI.draw_guild_buttons(faction)
    local quick = (GGUI.TAB == 1 or GGUI.TAB == 4)
    for i = 1, #GGUI.GUILD_ORDER do
        local g = GGUI.GUILD_ORDER[i]
        local b = comp(GGUI.GUILD_BTN .. i)
        if b then
            pcall(function() b:SetVisible(quick) end)
            if quick then
                pcall(function() b:SetImagePath(GGUI.icon(g) or "", GGUI.GUILD_BTN_ICON) end)
                local n = GGUI.ready_in(faction, g)
                set_text(b, n > 0 and tostring(n) or "")
                set_tooltip(b, GGUI.guild_tip(faction, g))
            end
        end
    end
    -- The bronze bar the buttons sit on goes with them.
    local gbar = comp("gg_gbar")
    if gbar then pcall(function() gbar:SetVisible(quick) end) end
    local bar, panel = comp(GGUI.GUILD_SEL), comp(GGUI.PANEL)
    if not bar or not panel then return end
    pcall(function()
        bar:SetVisible(quick)
        -- Moved AFTER GGUI.layout put it at the first button: the page, not the file,
        -- decides where it sits.
        local at = GGUI.PANEL_XY[GGUI.GUILD_BTN .. GGUI.PAGE]
        if at then
            local px, py = panel:Position()
            bar:MoveTo(px + GGUI.px(at[1]), py + GGUI.px(GGUI.PANEL_XY[GGUI.GUILD_SEL][2]))
        end
    end)
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
    -- A full army is refused for a regiment (GG.target_ok), so the hint says so.
    if s.kind == "unit" then return "needs_army_room" end
    if s.kind == "army" then return "needs_army" end
    -- THEIR OWN RULE, SAID (logic audit): not the faction leader; an army not yet blessed.
    if s.key == "bought_loyalty" then return "needs_army_not_leader" end
    if s.key == "ladys_blessing" then return "needs_army_unblessed" end
    if s.kind == "race_army" then return s.room and "needs_army_room" or "needs_army" end
    if s.kind == "ranks" then return "needs_char" end
    if s.kind == "settlement" then return "needs_settlement_own" end
    if s.kind == "enemy_settlement" then return "needs_region_enemy" end
    if s.kind == "shroud" then return "needs_region_any" end
    if s.kind == "building" then return "needs_region_own" end
    if s.kind == "research" then return "needs_research" end
    return "needs_target"
end

-- THE TARGET AS IT TRAVELS. GG.target_from_wire rebuilds it on every machine: a
-- building as the selected region, research as nothing, the rest as the key or cqi.
-- WHAT IS LEFT TO PAY ON THE CURRENT RESEARCH, read where only the buyer's UI can read it,
-- and sent with the purchase so every machine grants the same points (GG.payload). nil
-- when unreadable, which falls back to the old instant-research call.
function GGUI.research_left(faction)
    local ok, left = pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then return nil end
        return tonumber(common.get_context_value("CcoCampaignFaction", f:command_queue_index(),
            "TechnologyManagerContext.CurrentResearchingTechnologyContext.ResearchPointsCost"))
    end)
    if ok and left and left > 0 then return math.floor(left) end
    return nil
end

function GGUI.wire_target(s, faction)
    if not s then return "" end
    if s.kind == "research" then return tostring(GGUI.research_left(faction) or "") end
    if s.kind == "building" and not s.hostile then return GGUI.selected_region() or "" end
    local t = GGUI.pick_target(s, faction)
    if t == nil then return "" end
    return tostring(t)
end

function GGUI.pick_target(s, faction)
    if not s then return nil end
    -- THROUGH THE TILL'S OWN TEST, so the pick card waits on an ally or a faction at peace
    -- rather than bringing the panel back to a refusal (2026-09-29).
    if s.hostile then
        local f = GGUI.selected_enemy_faction()
        if f and GG.target_ok(faction, s, f) then return f end
        return nil
    end
    -- A SELECTION THAT FAILS GG.target_ok IS NO SELECTION: the card keeps waiting, and a
    -- friendly service can never be pointed at an enemy army or town.
    if GG.CHAR_KINDS[s.kind] then
        local c = GGUI.selected_force_cqi()
        if c and GG.target_ok(faction, s, c) then return c end
        return nil
    end
    if s.kind == "settlement" or s.kind == "enemy_settlement" then
        local r = GGUI.selected_region()
        if r and GG.target_ok(faction, s, r) then return r end
        return nil
    end
    -- WHATEVER SETTLEMENT IS SELECTED. cm:get_campaign_ui_manager() documents
    -- get_selected_settlement_region(), so the shroud service has a real target source
    -- and the map's own selection is the picker - the same idiom the two above use.
    -- Not the buyer's own region, which it already sees (GG.target_ok).
    if s.kind == "shroud" then
        local r = GGUI.selected_region()
        if r and GG.target_ok(faction, s, r) then return r end
        return nil
    end
    -- WHAT THE FACTION IS ALREADY RESEARCHING. No member of the faction interface names
    -- the subject, but ResearchStarted's context carries the key and the model records
    -- it - so the player picks the technology the ordinary way, in the tech tree, and
    -- this service finishes it.
    if s.kind == "research" then return GG.research_target(faction) end
    if s.kind == "building" then return GGUI.selected_building_upgrade(faction) end
    return nil
end

-- THE FIRST LEGAL UPGRADE IN THE SELECTED REGION. GG.upgrade_target does the work, and
-- the AI and the multiplayer handler build the same target through it.
function GGUI.selected_building_upgrade(faction)
    return GG.upgrade_target(faction, GGUI.selected_region())
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

-- THE SELECTED LORD, IF THEY CAN BE A PATRON: one of `faction`'s own, with an army. The
-- selection lands on anyone, and Appoint once made an enemy army the patron's; a hero
-- ended the pick on a live button that did nothing (logic audit, 2026-09-29).
function GGUI.patron_cqi(faction)
    local cqi = GGUI.selected_force_cqi()
    if cqi and GG.force_cqi_of(cqi, faction) then return cqi end
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

-- OUT OF CORE'S QUEUE ALTOGETHER (player report 2026-10-09, Malakai: "click sound,
-- nothing opens", and again after the first fix). Since 9.0 lib_core calls listeners
-- unprotected, and core:event_callback tests EVERY listener's condition before it calls
-- any callback (lib_core.lua 1978-1990): one mod's condition that throws drops the whole
-- click, so index 1 of core.event_listeners was not first enough. GGUI.click_first lifts
-- gg_clicks into events.ComponentLClickUp, the engine's own list that core's dispatcher
-- is one entry of - CA's wh2_campaign_traits.lua writes to events.* the same way.
function GGUI.on_click(context)
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
        -- GGUI.leaders() builds its rows in GG.GUILDS order.
        local n = tonumber(string.match(id, "(%d+)$"))
        if n then
            GGUI.STAND_GUILD = n
            GGUI.refresh()
        end
    elseif id == "row_icon" then
        -- THE ROW PICKS THE LIST BELOW IT; ITS GLYPH GOES TO THE GUILD'S OWN SERVICES.
        local n = tonumber(string.match(GGUI.parent_name(context) or "", "_(%d+)$"))
        local g = n and GG.GUILDS[n]
        for i = 1, #GGUI.GUILD_ORDER do
            if g and GGUI.GUILD_ORDER[i] == g then
                GGUI.PAGE = i
                GGUI.set_tab(1)
            end
        end
    elseif string.match(id, "^" .. GGUI.GUILD_BTN .. "%d+$") then
        local n = tonumber(string.match(id, "(%d+)$"))
        if n and GGUI.GUILD_ORDER[n] then GGUI.set_page(n) end
    elseif string.match(id, "^" .. GGUI.LOG_FILTER_BTN) then
        local f = string.sub(id, #GGUI.LOG_FILTER_BTN + 1)
        if f == "all" or GGUI.LOG_FILTERS[f] then
            -- The newest page of the new view, the same rule as opening the tab.
            GGUI.LOG_FILTER, GGUI.LOG_PAGE = f, 1
            GGUI.refresh()
        end
    elseif string.match(id, "^" .. GGUI.CARD .. "_%d+$") then
        -- A BOUNTY CARD IS A MAP LINK. The same card on the other tabs is a service or a
        -- court matter, and has its button for that.
        if GGUI.TAB == 3 then
            local n = tonumber(string.match(id, "(%d+)$"))
            local me = GGUI.me()
            local list = me and GG.bounties[me]
            GGUI.show_on_map(GGUI.bounty_pos(list and list[GGUI.BOUNTY_AT[n] or 0]))
        end
    elseif string.match(id, "^" .. GGUI.FROW .. "_%d+$") then
        local f = GGUI.LIST_FACTIONS[tonumber(string.match(id, "(%d+)$"))]
        if f then GGUI.show_on_map(GGUI.faction_pos(f)) end
    elseif id == "card_buy" then
        GGUI.on_buy_click(context)
    elseif id == "gg_opener" then
        -- NOT DURING THE AI ROUND. The greyed look is the affordance, this is the guard:
        -- it holds even on a save loaded mid-round, before anything has greyed the button.
        if not GGUI.player_turn() then return end
        if GGUI.PICK then
            GGUI.end_pick(true)
        elseif comp(GGUI.PANEL) then
            GGUI.close()
        else
            GGUI.open()
        end
    end
end

-- Named, so the harness can make a failed click throw again instead of vanishing.
function GGUI.click_failed(id, err)
    GGUI.say("GAVE UP on a click on " .. tostring(id) .. ": " .. tostring(err))
end

core:add_listener("gg_clicks", "ComponentLClickUp", true, function(context)
    local ok, err = pcall(GGUI.on_click, context)
    if not ok then GGUI.click_failed(context.string, err) end
end, true)

-- Inserted into the engine's list BEFORE it leaves core's, so a missing events table
-- leaves the listener where core put it. The wrapper never throws into the engine.
function GGUI.click_first(name)
    pcall(function()
        local list = core.event_listeners.ComponentLClickUp
        for i = #list, 1, -1 do
            local l = list[i]
            if l.name == name then
                table.insert(events.ComponentLClickUp, 1, function(context)
                    pcall(function()
                        if l.condition == true or l.condition(context) then l.callback(context) end
                    end)
                end)
                table.remove(list, i)
                return
            end
        end
    end)
end

GGUI.click_first("gg_clicks")

-- The name of the component a clicked child sits in: card_buy's card, row_icon's row.
function GGUI.parent_name(context)
    local ok, name = pcall(function()
        -- UIComponent TWICE, and that is not a typo. :Parent() hands back a component
        -- ADDRESS, not a uicomponent, so calling :Id() straight off it throws - and
        -- inside a pcall that throws silently, which left every Buy and Take in the
        -- panel dead once while the click itself registered fine. The Zharr Exchange
        -- writes the same two-step walk for the same reason.
        return UIComponent(UIComponent(context.component):Parent()):Id()
    end)
    if ok then return name end
    return nil
end

function GGUI.on_buy_click(context)
    local ok, faction = pcall(function() return cm:get_local_faction_name(true) end)
    if not ok or not faction then return end
    local parent_name = GGUI.parent_name(context)
    -- THE PICK CARD'S ONE BUTTON IS CANCEL.
    if parent_name == GGUI.PICK_CARD then
        GGUI.end_pick(true)
        return
    end
    -- One button, two meanings, because one card template serves both tabs.
    local is_bounty = (GGUI.TAB == 3)
    local is_court = (GGUI.TAB == 4)
    -- Which card was clicked: read its index off its name.
    local slot = parent_name and tonumber(string.match(parent_name, "_(%d+)$"))
    if not slot then return end
    -- EVERY CHANGE BELOW GOES THROUGH GG.mp_send - applied at once in single player,
    -- broadcast in multiplayer and applied on every machine when it comes back. In
    -- multiplayer the refresh here shows the state before the change; GG.after_mp
    -- redraws when it lands.
    if is_bounty then
        local g = GGUI.BOUNTY_GUILD[slot]
        if g then GG.mp_send(faction, "bounty", g) end
        GGUI.refresh()
        return
    end
    if is_court then
        -- Slot 1 pays the demand, slot 2 appoints or dismisses the patron, slot 3 is
        -- the leadership card and has no button at all.
        if slot == 1 then
            GG.mp_send(faction, "demand")
        elseif slot == 2 then
            -- APPOINTING WITH NOBODY SELECTED picks a lord first. Dismissing needs no one.
            local p = GG.patrons[faction]
            local holds_this = p ~= nil and p.guild == GGUI.current_guild()
            if not holds_this and not GGUI.patron_cqi(faction) then
                GGUI.start_pick("patron")
                return
            end
            -- THE VERB IS SENT: a second press before the first comes back must not undo
            -- it (logic audit, 2026-09-29).
            if holds_this then
                GG.mp_send(faction, "patron", "dismiss|" .. GGUI.current_guild())
            else
                GG.mp_send(faction, "patron", "appoint|" .. GGUI.current_guild() .. "|"
                                              .. tostring(GGUI.patron_cqi(faction)))
            end
        end
        GGUI.refresh()
        return
    end
    local mine = GGUI.services_of(GGUI.current_guild(), faction)
    local s = mine[slot]
    if not s then return end
    local can, why = GGUI.card_state(faction, s)
    if not can then
        -- The only refusal with a live button: no target yet, and the map can give one.
        if why == "target" and GGUI.can_pick(s) then GGUI.start_pick(s.key) end
        return
    end
    if GGUI.needs_confirm(faction, s) and GGUI.CONFIRM ~= s.key then
        GGUI.CONFIRM = s.key
        GGUI.refresh()
        return
    end
    GGUI.CONFIRM = nil
    GG.mp_send(faction, "buy", s.key .. "|" .. GGUI.wire_target(s, faction))
    GGUI.refresh()
end

-- A CHANGE THAT CAME BACK OVER THE NETWORK: redraw if it was ours and the panel is up.
GG.after_mp = function(faction)
    if faction == GGUI.me() and comp(GGUI.PANEL) then GGUI.refresh() end
end

-- ----------------------------------------------------------------- the map ---
-- THE PANEL COVERS THE MAP IT TALKS ABOUT: 790x700 over the middle of the screen. Three
-- things below get it out of the way - a bounty's target, a rival's capital, and picking
-- a target for a service.

-- Seconds. Long enough to see where the camera went, short enough not to wait on it.
GGUI.PAN_TIME = 0.6

-- ONLY THE POINT THE CAMERA LOOKS AT MOVES. Its distance, bearing and height are read and
-- handed back, because a pan that also zooms is two things at once. `true` because CA's
-- doc says to "set to true if control is being released back to the player".
function GGUI.pan_to(x, y)
    pcall(function()
        local _cx, _cy, d, b, h = cm:get_camera_position()
        cm:scroll_camera_from_current(true, GGUI.PAN_TIME, {x, y, d, b, h})
    end)
end

-- The panel closes only when there is somewhere to go, so a dead link is a click that
-- does nothing rather than one that shuts the panel and shows nothing.
function GGUI.show_on_map(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    GGUI.close()
    GGUI.pan_to(x, y)
    return true
end

-- WHERE A BOUNTY'S TARGET STANDS: the settlement for a region, the lord or hero for a
-- lord or a character. A
-- family member outlives its character (CA's model_hierarchy), so a dead lord is a null
-- character here and has no position.
function GGUI.bounty_pos(o)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    -- A job has nowhere to show: a sum, a rank, a technology, a building anywhere.
    if not k or not (k.target == "region" or k.target == "lord"
                     or k.target == "character") then
        return nil
    end
    local ok, x, y = pcall(function()
        if k.target == "region" then
            local r = cm:get_region(o.target)
            if not r or r:is_null_interface() then return nil end
            local s = r:settlement()
            return s:display_position_x(), s:display_position_y()
        end
        local fm = cm:get_family_member_by_cqi(tonumber(o.target) or 0)
        if not fm or fm:is_null_interface() then return nil end
        local c = fm:character()
        if not c or c:is_null_interface() then return nil end
        return c:display_position_x(), c:display_position_y()
    end)
    if ok then return x, y end
    return nil
end

-- A FACTION'S CAPITAL, or nil for one with none - a horde, or a faction that lost it. The
-- Leaderboard only offers the click where this answers.
function GGUI.faction_pos(key)
    local ok, x, y = pcall(function()
        local f = cm:get_faction(key)
        if not f or f:is_null_interface() or not f:has_home_region() then return nil end
        local s = f:home_region():settlement()
        return s:display_position_x(), s:display_position_y()
    end)
    if ok then return x, y end
    return nil
end

-- ------------------------------------------------------- picking a target ---
-- A TARGETED SERVICE READS THE MAP'S SELECTION, and the panel sits over that map. So the
-- card's button steps the panel aside: a card at the top of the screen says what to
-- select, the map is free, and the first selection that is a target brings the panel back
-- where it was. It buys nothing - the player still presses Buy, with the target now on the
-- card. Escape, the card's Cancel and the HUD opener all end it the same way.
--
-- NOT RESEARCH: that target is picked in the tech tree, and its card already says so.
GGUI.PICK = nil
GGUI.PICK_CARD = "derpy_gg_pick"
GGUI.PICK_ESC = "derpy_gg_pick_esc"
-- Design pixels from the top of the screen: under CA's top bar, and clear of the unit
-- panel a selected army raises along the bottom.
GGUI.PICK_Y = 110

function GGUI.can_pick(s)
    return s ~= nil and GG.needs_target(s) and s.kind ~= "research"
end

-- `key` is a service key, or "patron" for the Court's Appoint.
function GGUI.start_pick(key)
    -- The tab and page are left as they are: nothing can change them while the panel
    -- is shut, so the panel reopens where it was.
    GGUI.PICK = {key = key}
    GGUI.close()
    local s = GG.service(key)
    local guild = s and s.guild or GGUI.current_guild()
    local name, hint
    if s then
        name, hint = GGUI.loc_service(key), GGUI.target_hint(s)
    else
        name, hint = GGUI.loc("patron_of") .. ": " .. GGUI.loc_guild(guild), "patron_needs_char"
    end
    pcall(function()
        local r = root()
        r:CreateComponent(GGUI.PICK_CARD, GGUI.frame_path(GGUI.PATH_CARD))
        local card = comp(GGUI.PICK_CARD)
        if not card then return end
        card:PropagatePriority(60)
        -- The panel's scale, read by the last open(). A pick only starts from the panel.
        GGUI.scale_tree(card)
        local sw = r:Dimensions()
        local cw = card:Dimensions()
        GGUI.place_card(card, math.floor((sw - cw) / 2), GGUI.px(GGUI.PICK_Y))
        -- WRAPPED ACROSS BOTH LINES. The longest instruction runs about 110 characters
        -- and a card line holds about 70; nothing here wraps by itself. The Escape note
        -- goes to the hover, and the Cancel button says the rest.
        local lines = GGUI.wrap(comp("card_desc_1", card), GGUI.loc(hint), 2)
        GGUI.fill_card(card, GGUI.icon(guild), name, lines[1] or "", lines[2] or "",
                       "", GGUI.loc("cancel"), true,
                       GGUI.loc(hint) .. "||" .. GGUI.loc("pick_cancel"))
    end)
    GGUI.hold_esc(GGUI.PICK_ESC, function() GGUI.end_pick(true) end)
end

function GGUI.end_pick(reopen)
    local p = GGUI.PICK
    GGUI.PICK = nil
    GGUI.drop_esc(GGUI.PICK_ESC)
    local c = comp(GGUI.PICK_CARD)
    if c then pcall(function() c:DestroyChildren(); c:Destroy() end) end
    if p and reopen then GGUI.open() end
end

-- WHETHER WHAT IS SELECTED NOW IS WHAT THE PICK WANTS, through the same reads the card
-- makes, so the panel never comes back to a card that still says "pick a target".
function GGUI.pick_ready()
    local p = GGUI.PICK
    if not p then return false end
    if p.key == "patron" then return GGUI.patron_cqi(GGUI.me()) ~= nil end
    local s = GG.service(p.key)
    return s ~= nil and GGUI.pick_target(s, GGUI.me()) ~= nil
end

function GGUI.pick_check()
    if GGUI.pick_ready() then GGUI.end_pick(true) end
end

-- A TENTH OF A SECOND LATE: CA's campaign_ui_manager records the selection in its own
-- listener for the same event, and nothing orders the two.
for name, event in pairs({gg_pick_char = "CharacterSelected",
                          gg_pick_settlement = "SettlementSelected"}) do
    core:add_listener(name, event, true, function()
        if GGUI.PICK then cm:callback(GGUI.pick_check, 0.1) end
    end, true)
end

-- AN OPEN PANEL REDRAWS ON A SELECTION CHANGE, and a pending Confirm is dropped (logic
-- audit, 2026-09-29). The click re-reads the selection, so a card drawn "Select" bought at
-- once when an army had been clicked in between, and a Confirm landed on whatever was
-- selected at the second click. A tenth of a second late, for the reason above. UI only.
for name, event in pairs({gg_sel_char = "CharacterSelected",
                          gg_sel_settlement = "SettlementSelected",
                          gg_desel_char = "CharacterDeselected",
                          gg_desel_settlement = "SettlementDeselected"}) do
    core:add_listener(name, event, true, function()
        if GGUI.PICK or not comp(GGUI.PANEL) then return end
        GGUI.CONFIRM = nil
        cm:callback(function() GGUI.refresh() end, 0.1)
    end, true)
end

-- THE BIG PANELS CLOSE THIS ONE. Two panels at once draw over each other in whichever
-- order they opened. Only full-screen and decision panels: a click on the map raises the
-- settlement and unit panels, and closing on those would shut this one on every stray
-- click. Every name is one CA's own scripts compare PanelOpenedCampaign's context.string
-- against; a wrong name would match nothing and cost nothing.
GGUI.CLOSE_FOR = {
    popup_pre_battle = true, popup_battle_results = true, settlement_captured = true,
    character_details_panel = true, objectives_screen = true, diplomacy_dropdown = true,
    building_browser = true, technology_panel = true, offices = true,
    appoint_new_general = true, finance_screen = true, esc_menu_campaign = true,
    tower_of_zharr = true, hellforge_panel_main = true, book_of_monster_hunts = true,
    daemonic_progression = true, beastmen_panel = true,
}

core:add_listener("gg_close_for", "PanelOpenedCampaign", true, function(context)
    if not GGUI.CLOSE_FOR[context.string] then return end
    if GGUI.PICK then GGUI.end_pick(false) end
    if comp(GGUI.PANEL) then GGUI.close() end
end, true)

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

-- INFORMATION, NOT WARNINGS: printed only with MCT's "Log every accrual" on. GGUI.say is
-- kept for the lines that explain a fault - GAVE UP, OVERRIDDEN - which must be in any
-- log a player sends unasked.
function GGUI.info(msg)
    if GG.logging and GG.logging() then GGUI.say(msg) end
end

GGUI.BTN      = "gg_opener"
GGUI.BTN_SIZE = 44          -- must match OPENER_W/H in tools/gen_guilds_ui.py

-- THE HUB (tools/sync_derpy_hub.py, spec 2026-10-01). With a second Derpy opener on the
-- HUD, one hub button takes the strip slot and shows this button in a row on hover. While
-- the hub manages it, the hub owns its place and visibility; this file still makes it,
-- paints it, greys it and writes its tooltip.
GGUI.HUB_KEY = "gg"

function GGUI.hubbed()
    return DERPY_HUB ~= nil and DERPY_HUB.manages ~= nil
        and DERPY_HUB.manages(GGUI.HUB_KEY) == true
end

-- IS IT THE PLAYER'S TURN? ASKED, NOT REMEMBERED: a flag set at turn end and cleared at
-- turn start is wrong after a load, which restores neither. Fails OPEN - a probe that
-- throws must never be what locks the player out of the panel. The Zharr Exchange's
-- EX.player_turn, the same call.
function GGUI.player_turn()
    local ok, mine = pcall(function()
        return cm:model():world():is_factions_turn_by_key(GGUI.me())
    end)
    if not ok then return true end
    return mine ~= false
end

-- GREYED WHILE IT IS NOT THE PLAYER'S TURN, like the Exchange's button beside it (asked
-- for from a screenshot, 2026-09-28). SetDisabled only stops the click - CA: disabled
-- components "still respond to the mouse cursor" - and the opener has no inactive state to
-- draw, so the look is CA's set_greyscale_t0 on every state and the count text, the
-- Exchange's EX.set_off. Not SetVisible: a button that vanishes and returns reads as a bug.
function GGUI.gate_opener(on)
    local b = comp(GGUI.BTN)
    if not b then return end
    GGUI.opener_live = on and true or false     -- what the hub's live() reads
    pcall(function()
        b:SetDisabled(not on)
        b:ShaderTechniqueSet(on and "normal_t0" or "set_greyscale_t0", true, true)
        if not on then b:ShaderVarsSet(1, 0.6, 0, 0, true, true) end
    end)
end

-- WHAT THE PLAYER COULD DO RIGHT NOW. Three things count, and they are the three the panel
-- has a button for: a service they can actually buy, a bounty offer sitting on the board,
-- and a demand they can pay.
--
-- NO LOC IN HERE. This is called from a turn handler.
--
-- can_buy is the gate rather than the price, deliberately. A count that included services
-- the rank does not reach would send the player to a panel of greyed buttons, which is a
-- worse signal than no badge at all.
--
-- A LIST, NOT A COUNT, so the opener's tooltip can name what the badge is counting - the
-- two are one call and cannot disagree. Keys and guilds only: still no loc in here.
-- A TAKEN offer is not on it. It has no button on the board, so it is not waiting on the
-- player; it was counted until 2026-09-25.
function GGUI.actionable_items(faction)
    local out = {}
    if not faction or not GG.state or not GG.state[faction] then return out end
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        local ok, can = pcall(function() return GG.can_buy(faction, s.key) end)
        if ok and can then out[#out + 1] = {kind = "service", key = s.key, guild = s.guild} end
    end
    -- ONLY WHAT THE BOARD SHOWS (logic audit, 2026-09-29): an offer that stopped being
    -- true mid-turn is hidden there by GG.bounty_view, and was still counted here.
    local offers = (GG.bounties and GG.bounties[faction]) or {}
    local view = {}
    pcall(function() view = GG.bounty_view(faction) end)
    for _, i in ipairs(view) do
        local o = offers[i]
        -- ONLY ONE THE PLAYER CAN TAKE: an offer short of favour has a dead Take button.
        if o and not o.taken and GG.stake_affordable(faction, o) then
            out[#out + 1] = {kind = "bounty", guild = o.guild}
        end
    end
    local d = GG.demands and GG.demands[faction]
    if d then
        local ok, payable = pcall(function() return GG.demand_payable(faction) end)
        if ok and payable then out[#out + 1] = {kind = "demand", guild = d.guild} end
    end
    return out
end

function GGUI.actionable(faction)
    return #GGUI.actionable_items(faction)
end

-- WHAT THE BADGE IS COUNTING, in words. Draw time only - it is written on hover.
function GGUI.opener_tip(faction)
    local parts, bounties, demand = {GGUI.loc("panel_title")}, 0, nil
    local items = GGUI.actionable_items(faction)
    local ready = {}
    for i = 1, #items do
        local it = items[i]
        if it.kind == "service" then
            ready[#ready + 1] = GGUI.HELP_BULLET .. GGUI.loc_service(it.key) .. "  ("
                                .. GGUI.loc_guild(it.guild) .. ")"
        elseif it.kind == "bounty" then
            bounties = bounties + 1
        elseif it.kind == "demand" then
            demand = it
        end
    end
    if #items == 0 then
        parts[#parts + 1] = GGUI.loc("opener_none")
    end
    if #ready > 0 then
        parts[#parts + 1] = GGUI.loc("opener_ready")
        for i = 1, #ready do parts[#parts + 1] = ready[i] end
    end
    if bounties > 0 then
        parts[#parts + 1] = GGUI.loc("opener_bounties") .. " " .. bounties
    end
    if demand then
        parts[#parts + 1] = GGUI.loc("opener_demand") .. " " .. GGUI.loc_guild(demand.guild)
    end
    -- GREYED MID-ROUND (GGUI.gate_opener), so "click" would be a lie the button refuses.
    parts[#parts + 1] = GGUI.loc(GGUI.player_turn() and "opener_click" or "opener_wait")
    return table.concat(parts, "||")
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
-- LONGER THAN ANY INTRO. It was 12 (24 seconds), and a 2026-09-27 Middenland load kept
-- resources_bar off-screen ~245s after first tick: the chain gave up "(unsettled)" and
-- the button first showed at turn 2. The Zharr Exchange measured the same race on
-- 2026-09-06 and settled on 150 (EX.PLACE_TRIES); the chain ends at the first placement,
-- so the count only matters if CA renames the anchor.
GGUI.BTN_TRIES = 150        -- x2.0s = 5 minutes
GGUI.btn_at = nil           -- set once placed; stops the retry chain for good
GGUI.btn_chain = false      -- a retry is queued; a turn start must not start another

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

-- Within one button of the screen is clamped onto it; further out is a bad or
-- mid-animation read and answers nil. Shared by placement and the follow poll, so the
-- two cannot disagree about what counts as a real reading.
function GGUI.fit_opener(x, y)
    local sw, sh = screen()
    local tol = GGUI.BTN_SIZE
    if x < -tol or y < -tol or x + GGUI.BTN_SIZE > sw + tol
       or y + GGUI.BTN_SIZE > sh + tol then
        return nil
    end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x + GGUI.BTN_SIZE > sw then x = sw - GGUI.BTN_SIZE end
    if y + GGUI.BTN_SIZE > sh then y = sh - GGUI.BTN_SIZE end
    return x, y
end

-- THE BUTTON FOLLOWS THE STRIP'S END. resources_bar is docked Top Center and sizes to its
-- content, so its right end moves whenever an effect icon or faction widget appears -
-- mid-turn, with no event for it. Placement alone ran at load and turn start, so the
-- button sat where the end used to be and jumped at the next turn (reported 2026-09-27).
-- This polls on the UI clock, a few times a second: one find and two reads, and a MoveTo
-- only when the answer changed. Does nothing until the button is placed, and nothing while
-- the strip is away (btn_anchor refuses an unsettled strip). Local and UI-only, so it
-- cannot desync multiplayer.
GGUI.FOLLOW_MS = 300

function GGUI.follow_bar()
    if not GGUI.btn_at then return end
    if GGUI.hubbed() then return end            -- the hub owns its place
    local b = comp(GGUI.BTN)
    if not b then return end
    local x, y = GGUI.btn_anchor()
    if not x then return end
    x, y = GGUI.fit_opener(x, y)
    if not x then return end
    local ax, ay = b:Position()
    if ax == x and ay == y then return end
    b:MoveTo(x, y)
    GGUI.btn_at = x .. "," .. y
end

function GGUI.start_follow()
    cm:repeat_real_callback(function() pcall(GGUI.follow_bar) end, GGUI.FOLLOW_MS,
                            "gg_follow_bar")
end

cm:add_first_tick_callback(function() GGUI.start_follow() end)

function GGUI.place_opener(attempt)
    attempt = attempt or 1
    local root = core:get_ui_root()
    local sw, sh = screen()

    -- Every "not ready" branch routes through here so the chain cannot be given up
    -- on in one place and kept alive in another. Stops on the first success.
    local function retry()
        if GGUI.btn_at or attempt >= GGUI.BTN_TRIES then
            GGUI.btn_chain = false
            return false
        end
        GGUI.btn_chain = true
        cm:callback(function() GGUI.place_opener(attempt + 1) end, 2.0,
                    "gg_place_opener_" .. attempt)
        return true
    end
    -- ONE CHAIN. FactionTurnStart fires ~190 times a round; while the button is not yet
    -- placed each would otherwise start its own 150-try chain. A queued retry is already
    -- going to look again, so a fresh start has nothing to add.
    if attempt == 1 and GGUI.btn_chain then return end
    GGUI.btn_chain = false

    -- NO GUILDS, NO BUTTON. A race this mod writes no guilds for gets no way in; GG.covered
    -- keeps it out of the race as well. An unreadable player is loading, not a verdict.
    local fl = GG.flavour_of(GGUI.me())
    if not fl then retry() return end
    if fl == GG.GENERIC then return end

    -- CREATION retries too. The HUD is not built when the first callback runs, so a
    -- one-shot create silently does nothing forever.
    local b = comp(GGUI.BTN)
    if not is_uicomponent(b) then
        pcall(function() root:CreateComponent(GGUI.BTN, GGUI.PATH_OPENER) end)
        b = comp(GGUI.BTN)
    end
    if not is_uicomponent(b) then retry() return end

    -- THE HUB PLACES IT while it manages this button. Still painted and greyed here, which
    -- the hub never does; not moved or shown, which only one owner may do.
    if GGUI.hubbed() then
        GGUI.paint_opener(b)
        GGUI.gate_opener(GGUI.player_turn())
        return
    end

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
    local fx, fy = GGUI.fit_opener(x, y)
    if not fx then
        if not retry() and not GGUI.btn_at then
            GGUI.say("GAVE UP - resources_bar put the button at " .. x .. "," .. y
                     .. " on a " .. sw .. "x" .. sh .. " screen, too far out to clamp")
        end
        return
    end
    x, y = fx, fy

    b:MoveTo(x, y)
    b:SetVisible(true)
    -- The button is created on the UI root, which does NOT put it in front of the
    -- HUD - hud_campaign draws over it. Being on-screen is not the same as being
    -- visible, and that difference is what the first attempt lost a round trip to.
    pcall(function() b:RegisterTopMost() end)
    GGUI.paint_opener(b)
    -- This runs at the first tick and at EVERY faction's turn start, so an AI's greys the
    -- button and the player's own brings it back - and a load asks rather than assumes.
    GGUI.gate_opener(GGUI.player_turn())

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
            GGUI.info("opener button at " .. now .. " on a " .. sw .. "x" .. sh
                     .. " screen, " .. tostring(how))
        end
        GGUI.btn_at = now
    else
        -- Do not mark it placed: leave the chain free to try again.
        GGUI.say("MoveTo OVERRIDDEN - asked " .. x .. "," .. y .. " got "
                 .. ax .. "," .. ay .. ", the parent is laying this component out")
    end
end

-- THE MCT PAGE IN THE PLAYER'S OWN WORDS. The settings file names the guilds by what
-- they do, because the frontend has no race to name them for. In a campaign the twelve
-- guild sliders take the local player's flavour at the first tick. MCT reads an option's
-- text when it builds the page, so this lands before anyone opens it.
--
-- LITERAL NAMES, NOT LOC. This runs from the first tick, and a loc call there is the
-- no-loc-in-turn-handlers trap. tools/gen_great_guilds.py --write rewrites the table
-- between the two markers from its FLAVOURS, and --check refuses a stale one.
-- BEGIN GENERATED: GGUI.MCT_NAMES
GGUI.MCT_NAMES = {
    [""] = {
        brass = "The Brass Tablets",
        immortals = "The Immortals",
        daemonsmiths = "The Daemonsmiths",
        khanate = "The Khanate",
        overseers = "The Overseers",
        slavers = "The Slavers",
        temple = "The Temple of Hashut",
    },
    ["_emp"] = {
        brass = "The Merchant Guilds",
        immortals = "The Greatswords",
        daemonsmiths = "The Engineers' School",
        khanate = "The Thieves' Guild",
        overseers = "The Masons' Guild",
        slavers = "The Free Companies",
        temple = "The Colleges of Magic",
    },
    ["_dwf"] = {
        brass = "The Merchant Clans",
        immortals = "The Hammerers",
        daemonsmiths = "The Engineers' Guild",
        khanate = "The Rangers",
        overseers = "The Miners' Guild",
        slavers = "The Grudge-Settlers",
        temple = "The Ancestor Temples",
    },
    ["_brt"] = {
        brass = "The Wine Merchants",
        immortals = "The Knights Errant",
        daemonsmiths = "The Grail Damsels",
        khanate = "The Forest Outlaws",
        overseers = "The Castle-Wrights",
        slavers = "The Crusaders",
        temple = "The Grail Pilgrims",
    },
    ["_cth"] = {
        brass = "The Caravan Masters",
        immortals = "The Dragon Guard",
        daemonsmiths = "The Imperial Academy",
        khanate = "The Crow Society",
        overseers = "The Bastion Builders",
        slavers = "The Punitive Host",
        temple = "The Celestial Temples",
    },
    ["_ksl"] = {
        brass = "The Erengrad Merchants",
        immortals = "The Tzar Guard",
        daemonsmiths = "The Ice Court",
        khanate = "The Oblast Smugglers",
        overseers = "The Stanitsa Builders",
        slavers = "The Ungol Raiders",
        temple = "The Great Orthodoxy",
    },
    ["_def"] = {
        brass = "The Karond Kar Traders",
        immortals = "The Black Guard",
        daemonsmiths = "The Convent of Ghrond",
        khanate = "The Khainite Assassins",
        overseers = "The Naggarond Builders",
        slavers = "The Black Ark Corsairs",
        temple = "The Brides of Khaine",
    },
    ["_hef"] = {
        brass = "The Lothern Merchants",
        immortals = "The Swordmasters",
        daemonsmiths = "The Loremasters",
        khanate = "The Shadow Warriors",
        overseers = "The Ulthuan Masons",
        slavers = "The Ellyrian Reavers",
        temple = "The Cult of Asuryan",
    },
    ["_skv"] = {
        brass = "The Warpstone Traders",
        immortals = "The Stormvermin",
        daemonsmiths = "The Skryre Warlocks",
        khanate = "The Eshin Assassins",
        overseers = "The Moulder Breeders",
        slavers = "The Slave-Masters",
        temple = "The Grey Seers",
    },
    ["_gen"] = {
        brass = "The Merchant Houses",
        immortals = "The Veterans' Company",
        daemonsmiths = "The Artisans' Guild",
        khanate = "The Shadow Guild",
        overseers = "The Builders' Guild",
        slavers = "The Raiders' Guild",
        temple = "The Faith Guild",
    },
}
-- END GENERATED: GGUI.MCT_NAMES

function GGUI.name_mct()
    local names = GGUI.MCT_NAMES and GGUI.MCT_NAMES[GGUI.tag()]
    if not names then return end
    pcall(function()
        local mct = get_mct and get_mct()
        local mod = mct and mct:get_mod_by_key("derpy_great_guilds")
        if not mod then return end
        for g, name in pairs(names) do
            local r = mod:get_option_by_key("rate_" .. g)
            if r then r:set_text(name) end
            local c = mod:get_option_by_key("cap_" .. g)
            if c then c:set_text(name .. " limit") end
        end
    end)
end

cm:add_first_tick_callback(function() GGUI.name_mct() end)

-- THE OPENER'S TOOLTIP, WRITTEN ON HOVER. place_opener runs from FactionTurnStart, and a
-- loc call from a turn handler can crash at turn 1 past pcall - so the tooltip is not
-- written there. A hover is a UI event, and the text is in place before the tooltip's
-- own delay runs out.
-- WHAT IS READY, not the rules: the rules are a hover away on the panel's own title, and
-- this is the one place a player can learn whether opening the panel is worth it.
core:add_listener("gg_opener_tip", "ComponentMouseOn", true, function(context)
    if context.string ~= GGUI.BTN then return end
    set_tooltip(comp(GGUI.BTN), GGUI.opener_tip(GGUI.me()))
end, true)

-- Placement starts at first tick and is re-run at turn start. Both are one-shots
-- into the same chain; place_opener stops itself once GGUI.btn_at is set.
cm:add_first_tick_callback(function() GGUI.place_opener(1) end)

core:add_listener("gg_opener_place", "FactionTurnStart", true, function()
    GGUI.place_opener(1)
    -- AND HERE, NOT ONLY IN place_opener: that returns early while the top bar is still
    -- sliding back in, which is exactly when the player's turn starts, and the button would
    -- stay grey for the whole turn.
    GGUI.gate_opener(GGUI.player_turn())
    -- SAME LISTENER, deliberately. This fires once per faction - about 190 times a round -
    -- and both calls are idempotent and cheap: place_opener stops itself once btn_at is
    -- set, and the badge is eighteen can_buy calls against a table already in memory.
    -- Splitting them into a second listener would double the registrations for nothing.
    pcall(function()
        local me = cm:get_local_faction_name(true)
        if me then GGUI.badge(me) end
    end)
end, true)

-- THE PLAYER ENDS THEIR TURN: the button greys and the panel goes. Here and not at the next
-- AI turn start, because the player's own turn end still answers "it is your turn". The
-- panel and a pending target pick are shut too - a greyed button is no way to close them,
-- and buying mid-round is what the grey is there to stop. UI only, nothing in the model.
core:add_listener("gg_opener_turn_end", "FactionTurnEnd",
    function(context) return context:faction():name() == GGUI.me() end,
    function()
        if GGUI.PICK then GGUI.end_pick(false) end
        if comp(GGUI.PANEL) then GGUI.close() end
        GGUI.gate_opener(false)
    end, true)

-- THE HUB'S REGISTRATION. A plain table, so load order against the hub copies does not
-- matter. The label is read on hover, a UI event, so the loc call is safe there.
DERPY_HUB_QUEUE = DERPY_HUB_QUEUE or {}
table.insert(DERPY_HUB_QUEUE, {
    key = GGUI.HUB_KEY, button = GGUI.BTN, order = 2,
    label = function() return GGUI.loc("panel_title") end,
    live = function() return GGUI.opener_live ~= false end,
})
