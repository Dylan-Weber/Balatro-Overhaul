-- Portrait run layout while a menu is zoomed in.
-- Builds a real HUD UIBox with the game's own engine and runs the real portrait.lua layout on it.
-- Bug this guards: leaving the app mid-blind opens the pause menu, which zooms the room in and
-- moves it up. Android then resizes the window, the run layout measured the OFFLINE/MODDED
-- labels against the zoomed room, and pushed the HUD, jokers, hand and later the shop about 3
-- units down for the rest of the run.
local fails, passes = 0, 0
local function ok(condition, message)
  if condition then passes = passes + 1 else fails = fails + 1; print("FAIL " .. message) end
end
local function near(first_value, second_value) return math.abs(first_value - second_value) < 0.01 end

-- Sizes read from the debug app on a Pixel 10 Pro XL emulator in portrait, mid-blind.
local unzoomed_tile_scale, menu_zoom = 1.931, 1.4
local unzoomed_room_top, zoomed_room_top = 0.4, -3.1
love = {graphics = {getDimensions = function() return 448, 997 end}, timer = {getTime = function() return 0 end}}
G = {
  TILESIZE = 20, TILESCALE = unzoomed_tile_scale, MENU_ZOOM = 1, TILE_W = 10.8, TILE_H = 24.6,
  ID = 1, I = {UIBOX = {}, NODE = {}, MOVEABLE = {}, POPUP = {}, CARD = {}, SPRITE = {}, UIBOX_ROOT = {}},
  SETTINGS = {paused = false},
  TIMERS = {REAL = 0, TOTAL = 0}, FRAMES = {MOVE = 0, DRAW = 0}, exp_times = {xy = 0, scale = 0, r = 0},
  STAGES = {MAIN_MENU = 1, RUN = 2}, STAGE = 2, STAGE_OBJECTS = {{}, {}}, MOVEABLES = {},
  UIT = {T = 1, B = 2, C = 3, R = 4, O = 5, ROOT = 7, S = 8, I = 9, padding = 0},
  C = setmetatable({}, {__index = function() return {0, 0, 0, 1} end}),
  FUNCS = {}, UIDEF = {},
  CONTROLLER = {clicked = {}, focused = {}, dragging = {}, hovering = {}, released_on = {}, cursor_down = {}, cursor_up = {}, cursor_hover = {}},
}
function EMPTY(table_to_clear)
  for key in pairs(table_to_clear or {}) do table_to_clear[key] = nil end
  return table_to_clear or {}
end
G.ROOM = {T = {x = 0.4, y = unzoomed_room_top, w = 10.8, h = 24.6}}
G.ROOM_UNZOOMED = {x = 0.4, y = unzoomed_room_top}
G.ROOM_ATTACH = {T = {x = 0, y = 0, w = 10.8, h = 24.6}, VT = {x = 0, y = 0, w = 10.8, h = 24.6}}

for _, engine_file in ipairs({"object", "node", "moveable", "ui"}) do dofile("assets/engine/" .. engine_file .. ".lua") end
G.ROOM_ATTACH = Moveable{T = {0, 0, 10.8, 24.6}}
package.preload["overhaul.hooks"] = function() return {wrap = function() end} end
dofile("assets/functions/portrait.lua")
local P = PORTRAIT
P.active = true

-- The OFFLINE badge in the top left corner, in screen pixels like bom_ui draws it.
CORNER_LABELS = {status_box = {x = 18, y = 18, w = 80, h = 25}, MODE_GAP = 4}

-- A portrait HUD: the blind row sits at the top, like create_UIBox_HUD in portrait.
G.HUD = UIBox{definition = {n = G.UIT.ROOT, config = {align = "cm", portrait_hud = true}, nodes = {
  {n = G.UIT.R, config = {id = "row_blind", align = "cm", minw = 10, minh = 2.5}, nodes = {}},
  {n = G.UIT.R, config = {align = "cm", minw = 10, minh = 3.5}, nodes = {}},
}}, config = {align = "tmi", offset = {x = 0, y = P.HUD_Y}, major = G.ROOM_ATTACH}}

local function zoom_in_for_menu()
  G.OVERLAY_MENU = {}
  G.MENU_ZOOM = menu_zoom
  G.TILESCALE = unzoomed_tile_scale * menu_zoom
  G.ROOM.T.y = zoomed_room_top
end
local function zoom_out_after_menu()
  G.OVERLAY_MENU = nil
  G.MENU_ZOOM = 1
  G.TILESCALE = unzoomed_tile_scale
  G.ROOM.T.y = unzoomed_room_top
end

P.layout_hud()
local playing_push = P.hud_push or 0
local playing_band_bottom = P.band_bottom()
local playing_clear = P.badge_clear_y()
ok(playing_clear ~= nil, "the badge is measured during play")
ok(playing_push > 0, "the HUD clears the OFFLINE badge during play, push " .. playing_push)
ok(G.HUD:get_UIE_by_ID("row_blind").T.y >= playing_clear - 0.01, "the blind row starts below the badge")

-- the app goes to the background: the pause menu opens, then the window is resized
zoom_in_for_menu()
ok(near(P.badge_clear_y(), playing_clear), "the badge measures the same with the menu zoomed in: " .. P.badge_clear_y() .. " vs " .. playing_clear)
P.layout_hud()
ok(near(P.hud_push or 0, playing_push), "a layout with the menu open keeps the HUD push: " .. tostring(P.hud_push) .. " vs " .. playing_push)
ok(near(P.band_bottom(), playing_band_bottom), "the jokers stay where they were with the menu open: " .. P.band_bottom() .. " vs " .. playing_band_bottom)

-- back in the game with the menu closed, before any other resize
zoom_out_after_menu()
ok(near(P.band_bottom(), playing_band_bottom), "the jokers are back at their playing height after the menu closes")
P.layout_hud()
ok(near(P.hud_push or 0, playing_push), "a layout after the menu closes still gives the same push")

-- several trips to the background in one blind
for _ = 1, 4 do
  zoom_in_for_menu()
  P.layout_hud()
  zoom_out_after_menu()
end
ok(near(P.band_bottom(), playing_band_bottom), "four trips to the background leave the run layout where it was")

-- without ROOM_UNZOOMED (before the first resize) it still measures against the room
G.ROOM_UNZOOMED = nil
ok(near(P.badge_clear_y(), playing_clear), "with no unzoomed room recorded the badge is measured against the room")

print(string.format("portrait_hud_menu_zoom: %d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
