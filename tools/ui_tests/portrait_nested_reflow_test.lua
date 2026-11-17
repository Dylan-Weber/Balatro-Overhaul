-- Portrait reflow of a menu whose wide part sits in a nested UIBox (the profile screen's tabs).
-- Builds real UIBoxes with the game's own engine and runs the real portrait.lua on them.
-- Bug this guards: pressing "Unlock All" on the profile screen swaps the info tip, the reflow is
-- undone and redone, and the tab contents came back in their landscape width, off the right edge.
local fails, passes = 0, 0
local function ok(cond, msg)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. msg) end
end
local function near(a, b) return math.abs(a - b) < 0.01 end

-- Sizes read from the debug app on a Pixel 9 emulator in portrait.
love = {graphics = {getDimensions = function() return 411, 923 end}, timer = {getTime = function() return 0 end}}
G = {
  TILESIZE = 20, TILESCALE = 2.303, MENU_ZOOM = 1.3, TILE_W = 10.8, TILE_H = 24.85,
  ID = 1, I = {UIBOX = {}, NODE = {}, MOVEABLE = {}, POPUP = {}, CARD = {}, SPRITE = {}, UIBOX_ROOT = {}},
  SETTINGS = {paused = false},
  TIMERS = {REAL = 0, TOTAL = 0}, FRAMES = {MOVE = 0, DRAW = 0}, exp_times = {xy = 0, scale = 0, r = 0},
  STAGES = {MAIN_MENU = 1, RUN = 2}, STAGE = 1, STAGE_OBJECTS = {{}, {}}, MOVEABLES = {},
  UIT = {T = 1, B = 2, C = 3, R = 4, O = 5, ROOT = 7, S = 8, I = 9, padding = 0},
  C = setmetatable({}, {__index = function() return {0, 0, 0, 1} end}),
  FUNCS = {}, UIDEF = {},
  CONTROLLER = {clicked = {}, focused = {}, dragging = {}, hovering = {}, released_on = {}, cursor_down = {}, cursor_up = {}, cursor_hover = {}},
}
function EMPTY(table_to_clear)
  for key in pairs(table_to_clear or {}) do table_to_clear[key] = nil end
  return table_to_clear or {}
end
G.ROOM = {T = {x = 0, y = 0, w = 10.8, h = 24.25}}
G.ROOM_ATTACH = {T = {x = 0, y = 0, w = 10.8, h = 24.25}, VT = {x = 0, y = 0, w = 10.8, h = 24.25}}

for _, engine_file in ipairs({"object", "node", "moveable", "ui"}) do dofile("assets/engine/" .. engine_file .. ".lua") end
G.ROOM_ATTACH = Moveable{T = {0, 0, 10.8, 24.25}}
package.preload["overhaul.hooks"] = function() return {wrap = function() end} end
dofile("assets/functions/portrait.lua")
local P = PORTRAIT
P.active = true

-- The profile tab: a 6 wide progress column beside the button column, 11.1 in all, a little
-- wider than portrait allows, like G.UIDEF.profile_option in landscape.
local function profile_tab_definition()
  return {n = G.UIT.ROOT, config = {align = "cm", colour = G.C.CLEAR}, nodes = {
    {n = G.UIT.R, config = {align = "cm", padding = 0.1}, nodes = {
      {n = G.UIT.C, config = {align = "cm", minw = 6, minh = 4}, nodes = {}},
      {n = G.UIT.C, config = {align = "cm", minw = 4.8, minh = 4}, nodes = {}},
    }},
  }}
end

local function info_tip_box(width)
  return UIBox{definition = {n = G.UIT.ROOT, config = {align = "cm"}, nodes = {
    {n = G.UIT.R, config = {minw = width, minh = 1}, nodes = {
      -- stands in for the warning text, so the menu's content changes like it does in game
      {n = G.UIT.O, config = {object = Moveable{T = {0, 0, 1, 0.5}}}},
    }}}}, config = {offset = {x = 0, y = 0}, align = "bm"}}
end

local tab_box = UIBox{definition = profile_tab_definition(), config = {offset = {x = 0, y = 0}, align = "cm"}}
local overlay = UIBox{definition = {n = G.UIT.ROOT, config = {align = "cm", padding = 0.1}, nodes = {
  {n = G.UIT.C, config = {align = "cm", padding = 0.2}, nodes = {
    {n = G.UIT.R, config = {align = "cm", padding = 0.15}, nodes = {
      {n = G.UIT.O, config = {id = "tab_contents", object = tab_box}},
    }},
    -- the profile tabs, name box, wins and Back button: the menu is about 13 tall in game
    {n = G.UIT.R, config = {align = "cm", minw = 4, minh = 6.5}, nodes = {}},
    {n = G.UIT.R, config = {align = "cm"}, nodes = {
      {n = G.UIT.O, config = {id = "overlay_menu_infotip", object = Moveable()}},
    }},
  }},
}}, config = {align = "cm", offset = {x = 0, y = 0}, major = G.ROOM_ATTACH}}
G.OVERLAY_MENU = overlay

local outer_column = overlay.UIRoot.children[1]
local tab_node = overlay:get_UIE_by_ID("tab_contents")
local target_width = P.reflow_width()
ok(outer_column.T.w > target_width, "the landscape tab is wider than portrait before the reflow")

P.read_check(overlay)
ok(overlay.portrait_flips ~= nil, "the reflow stacks the two tab columns")
ok(outer_column.T.w <= target_width, "the menu fits portrait after the first reflow, got " .. outer_column.T.w)
ok(near(tab_node.T.w, tab_box.T.w), "the tab node is as wide as the tab box after the first reflow")

-- What G.FUNCS.unlock_all does on its first press: swap in the warning info tip.
local info_tip_node = overlay:get_UIE_by_ID("overlay_menu_infotip")
info_tip_node.config.object:remove()
info_tip_node.config.object = info_tip_box(7.8)
P.read_check(overlay)
ok(overlay.portrait_flips ~= nil, "the tab columns are stacked again after the info tip appears")
ok(outer_column.T.w <= target_width, "the menu still fits portrait after the info tip appears, got " .. outer_column.T.w)
ok(near(tab_node.T.w, tab_box.T.w), "the tab node matches the tab box after the info tip appears, node "
  .. tab_node.T.w .. " box " .. tab_box.T.w)
ok(tab_box.T.w <= target_width, "the tab box itself fits portrait after the info tip appears, got " .. tab_box.T.w)

-- Leaving portrait undoes the reflow, and the nested tab box must get its landscape width back.
P.active = false
P.read_check(overlay)
ok(overlay.portrait_flips == nil, "landscape undoes the stacked columns")
ok(near(tab_box.T.w, tab_node.T.w) and tab_box.T.w > target_width,
  "landscape gives the tab its full width back, node " .. tab_node.T.w .. " box " .. tab_box.T.w)

print(string.format("portrait_nested_reflow_test: %d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
