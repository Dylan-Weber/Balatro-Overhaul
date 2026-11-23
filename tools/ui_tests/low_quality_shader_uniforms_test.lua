-- The low-quality card drawing path (Shader Quality below High, and maximum performance mode).
-- Patches the real engine/sprite.lua with the real Overhaul late patches through the real
-- lovely engine, then draws a card with a recording stand-in for each shader.
-- Bug this guards: that path never sent screen_scale or mouse_screen_pos. Cryptid's Astral
-- shader divides by screen_scale, so with it left at 0 every Astral card drew solid black.
package.path = "assets/?.lua;" .. package.path

local fails, passes = 0, 0
local function ok(condition, message)
  if condition then passes = passes + 1 else fails = fails + 1; print("FAIL " .. message) end
end

local function read_disk_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local contents = handle:read("*a")
  handle:close()
  return contents
end

love = {
  filesystem = {
    read = function(path)
      local contents = read_disk_file(path)
      if contents then return contents, #contents end
      return nil, "missing"
    end,
    getInfo = function(path) return read_disk_file(path) and {type = "file"} or nil end,
    getDirectoryItems = function() return {} end,
    getSaveDirectory = function() return "/save" end,
    createDirectory = function() return true end,
    write = function() return true end,
    remove = function() return true end,
  },
  graphics = {setShader = function() end, getDPIScale = function() return 2.4 end},
}

local Engine = require("modloader.lovely")
Engine.load("mods", {enabled = {}, late = {"assets/overhaul/late/sprite.toml", "assets/overhaul/late/sprite_auto.toml"}})
local patched_sprite = Engine.apply_patches("engine/sprite.lua", read_disk_file("assets/engine/sprite.lua"))
local function_start = patched_sprite:find("function Sprite:draw_shader", 1, true)
local function_end = patched_sprite:find("\nend\n", function_start, true)
ok(function_start and function_end, "the patched sprite.lua has Sprite:draw_shader")

Sprite = {}
assert(loadstring(patched_sprite:sub(function_start, function_end + 4), "@engine/sprite.lua"))()

local function recording_shader()
  return {sent = {}, send = function(self, name, value) self.sent[name] = value end}
end

local tile_scale, tile_size, canvas_scale = 1.93, 20, 1
G = {
  SETTINGS = {GRAPHICS = {perf_shader_quality = 1}},
  SHADERS = {cry_astral = recording_shader(), dissolve = recording_shader()},
  TILESCALE = tile_scale, TILESIZE = tile_size, CANV_SCALE = canvas_scale,
  CONTROLLER = {cursor_position = {x = 120, y = 640}},
  C = {CLEAR = {0, 0, 0, 0}},
  TIMERS = {REAL = 0},
}

local function new_card_sprite()
  local card = {ID = 7, dissolve = 0, tilt_var = {mx = 300, my = 900}}
  return {
    role = {draw_major = card}, ARGS = {}, VT = {x = 0, y = 0, scale = 1},
    get_pos_pixel = function() return {0, 0, 71, 95} end,
    get_image_dims = function() return {710, 950} end,
    draw_self = function() end,
  }
end

for _, quality in ipairs({1, 2}) do
  G.SETTINGS.GRAPHICS.perf_shader_quality = quality
  G.SHADERS.cry_astral = recording_shader()
  local card_sprite = new_card_sprite()
  card_sprite.draw_shader = Sprite.draw_shader
  card_sprite:draw_shader("cry_astral", nil, {0.5, 3})
  local sent = G.SHADERS.cry_astral.sent
  ok(sent.screen_scale ~= nil and sent.screen_scale > 0, "quality " .. quality .. " sends a screen_scale above 0, got " .. tostring(sent.screen_scale))
  ok(sent.screen_scale == tile_scale * tile_size * canvas_scale, "quality " .. quality .. " sends the same screen_scale as full quality")
  ok(type(sent.mouse_screen_pos) == "table" and sent.mouse_screen_pos[1] == 300 and sent.mouse_screen_pos[2] == 900,
    "quality " .. quality .. " sends the card's tilt point as mouse_screen_pos")
  ok(sent.hovering == 0, "quality " .. quality .. " still draws without tilt")

  -- a card with no tilt point uses the cursor, like full quality
  G.SHADERS.cry_astral = recording_shader()
  local plain_sprite = new_card_sprite()
  plain_sprite.role.draw_major.tilt_var = nil
  plain_sprite.draw_shader = Sprite.draw_shader
  plain_sprite:draw_shader("cry_astral", nil, {0.5, 3})
  local cursor = G.SHADERS.cry_astral.sent.mouse_screen_pos
  ok(cursor and cursor[1] == 120 and cursor[2] == 640, "quality " .. quality .. " falls back to the cursor position")

  -- drawing the same card again reuses its table instead of making a new one each frame
  local first_table = plain_sprite.ARGS.low_quality_cursor
  plain_sprite:draw_shader("cry_astral", nil, {0.5, 3})
  ok(first_table ~= nil and plain_sprite.ARGS.low_quality_cursor == first_table, "quality " .. quality .. " reuses the cursor table")
end

-- full quality is unchanged and still sends both
G.SETTINGS.GRAPHICS.perf_shader_quality = 3
G.SHADERS.cry_astral = recording_shader()
local full_sprite = new_card_sprite()
full_sprite.draw_shader = Sprite.draw_shader
full_sprite:draw_shader("cry_astral", nil, {0.5, 3})
ok(G.SHADERS.cry_astral.sent.screen_scale == tile_scale * tile_size * canvas_scale, "full quality sends screen_scale")
ok(full_sprite.ARGS.low_quality_cursor == nil, "full quality does not use the low-quality cursor table")

print(string.format("low_quality_shader_uniforms: %d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
