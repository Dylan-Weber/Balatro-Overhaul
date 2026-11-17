-- Play menu > Daily preview in portrait: the Twists and Boon details must read at the size Run Info's
-- Daily tab shows them. Bug this guards: the preview squeezed the rules box between the deck column
-- and the stat tiles (1.7 wide in portrait), and maxw shrank "No Interest" and its description to
-- a few pixels on a phone.
local root = (arg and arg[0] and arg[0]:match("^(.*)/tools/ui_tests/") or ".") .. "/assets/"
local fails = 0
local function check(name, cond, detail)
    if not cond then fails = fails + 1 print("FAIL " .. name .. " " .. tostring(detail)) else print("ok   " .. name) end
end

local function colour(r, g, b) return {r, g, b, 1} end
G = {UIT = {T = 1, B = 2, C = 3, R = 4, O = 5, ROOT = 7},
    C = {RED = colour(1, 0, 0), GREEN = colour(0, 1, 0), GOLD = colour(1, 1, 0), BLACK = colour(0, 0, 0), WHITE = colour(1, 1, 1), CLEAR = {0, 0, 0, 0},
        ORANGE = colour(1, 0.5, 0), L_BLACK = colour(0.2, 0.2, 0.2),
        UI = {TEXT_LIGHT = colour(1, 1, 1), TEXT_DARK = colour(0, 0, 0), TEXT_INACTIVE = colour(0.5, 0.5, 0.5), TRANSPARENT_DARK = colour(0, 0, 0)}},
    FUNCS = {}, UIDEF = {}, SETTINGS = {profile = 1}, PROFILES = {{}}, STAGES = {MAIN_MENU = 1, RUN = 2}, STAGE = 1,
    P_CENTERS = {b_plasma = {key = "b_plasma", name = "Plasma Deck", pos = {x = 0, y = 0}}},
    P_CENTER_POOLS = {Back = {}, Stake = {{key = "stake_white", name = "White Stake"}}}, P_BLINDS = {},
    CARD_W = 2.05, CARD_H = 2.75, ASSET_ATLAS = {centers = {}}}
Game = {start_run = function() end, update_game_over = function() end}
mod_loc = function(text) return text end
mod_loc_register = function() end
localize = function(args) if type(args) == "table" then return args.key or "ERROR" end return tostring(args) end
get_stake_sprite = function() return nil end
Sprite = function() return {states = {drag = {}}} end
UIK = {C = {muted = colour(0.6, 0.6, 0.6), ok = colour(0, 1, 0), money = colour(1, 1, 0)},
    portrait = function() return true end, touch = function() return true end,
    button = function(args) return {n = G.UIT.C, config = {button = args.button, id = args.id}, nodes = {}} end}

dofile(root .. "functions/daily_challenge.lua")
dofile(root .. "functions/play/play_menu.lua")
local DY, PM = BO_DAILY, PlayMenu

-- The rules on Dylan's screenshots for 2026-11-17, with no starting jokers so no CardArea is needed.
local daily_rules = {date = "2026-11-17", seed = "ABCDEFGH", deck = "b_plasma", stake = 1,
    twists = {"small_hand", "no_interest"}, boons = {"pocket"}, jokers = {}, vouchers = {}}
DY.build = function() return daily_rules end
DY.countdown = function() return "04:18:29" end

-- PM.sizes() as read from the debug app on a Pixel 10 Pro XL emulator in portrait and in landscape.
local portrait_sizes = {t = true, port = true, iw = 7.9, pw = 8.2, s = 0.36, small = 0.33, big = 0.46}
local landscape_sizes = {t = true, wide = true, iw = 13.68, pw = 13.98, s = 0.4, small = 0.34, big = 0.5}

local function deep_equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not deep_equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

-- Every text node with its scale and the smallest maxw of the nodes around it.
local function texts_with_limits(node, inherited_maxw, found)
    found = found or {}
    local config = node.config or {}
    local limit = inherited_maxw
    if config.maxw and (not limit or config.maxw < limit) then limit = config.maxw end
    if node.n == G.UIT.T then found[config.text] = {scale = config.scale, maxw = limit} end
    for _, child in ipairs(node.nodes or {}) do texts_with_limits(child, limit, found) end
    return found
end

local function panel_tree(panel) return {n = G.UIT.ROOT, config = {}, nodes = panel.rows} end

-- Run Info's Daily tab, the reference the preview should match.
G.GAME = {daily = true, daily_rules = daily_rules}
local run_info_texts = texts_with_limits(G.UIDEF.daily_run_info())
check("Run Info lists No Interest", run_info_texts["No Interest"] ~= nil)
local run_info_rule_row = G.UIDEF.daily_run_info().nodes[2]
check("DY.rule_panels builds the same Twists and Boon boxes as Run Info", deep_equal(DY.rule_panels(daily_rules), run_info_rule_row))
G.GAME = nil

local portrait_panel = PM.daily_panel(portrait_sizes)
local portrait_texts = texts_with_limits(panel_tree(portrait_panel))
local reused_rule_panels = false
for _, row in ipairs(portrait_panel.rows) do
    if deep_equal(row, DY.rule_panels(daily_rules)) then reused_rule_panels = true end
end
check("portrait preview shows Run Info's Twists and Boon boxes", reused_rule_panels)
for _, text in ipairs({"Small Hand", "-1 hand size", "No Interest", "Earn no interest at end of round", "Deep Pockets", "+1 consumable slot"}) do
    local preview, reference = portrait_texts[text], run_info_texts[text]
    check("portrait preview shows " .. text, preview ~= nil)
    if preview and reference then
        check(text .. " uses Run Info's text size in portrait", preview.scale == reference.scale, tostring(preview.scale) .. " vs " .. tostring(reference.scale))
        check(text .. " is not squeezed by a maxw in portrait", preview.maxw == nil, preview.maxw)
    end
end

-- Width of a row in the layout's own minw units, to check nothing is laid out wider than the panel.
local function row_width(row)
    local total = 0
    for _, child in ipairs(row.nodes or {}) do total = total + ((child.config or {}).minw or (child.config or {}).w or 0) end
    return total
end
for index, row in ipairs(portrait_panel.rows) do
    if row.n == G.UIT.R and row.nodes and #row.nodes > 1 then
        check("portrait row " .. index .. " fits the panel width", row_width(row) <= portrait_sizes.iw, row_width(row))
    end
end

-- Landscape keeps its one-row layout with the rules box between the deck and the tiles.
UIK.portrait = function() return false end
local landscape_panel = PM.daily_panel(landscape_sizes)
local landscape_rule_panels = false
for _, row in ipairs(landscape_panel.rows) do
    if deep_equal(row, DY.rule_panels(daily_rules)) then landscape_rule_panels = true end
end
check("landscape keeps the inline rules box", not landscape_rule_panels)
local landscape_texts = texts_with_limits(panel_tree(landscape_panel))
check("landscape still lists No Interest", landscape_texts["No Interest"] ~= nil)
check("landscape rules box is wide enough for No Interest's description",
    landscape_texts["Earn no interest at end of round"] and landscape_texts["Earn no interest at end of round"].maxw >= 6)

print(fails == 0 and "daily_preview_portrait_test: all passed" or ("daily_preview_portrait_test: " .. fails .. " failed"))
os.exit(fails == 0 and 0 or 1)
