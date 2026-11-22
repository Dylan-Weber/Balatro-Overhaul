-- Mod shaders on phones (OpenGL ES) get high float precision.
-- Patches Steamodded's real src/game_object.lua with the real Overhaul late patches through
-- the real lovely engine, then runs the real SMODS.Shader inject with a recording newShader.
-- Bug this guards: LOVE compiles pixel shaders at medium precision on OpenGL ES, Cryptid's
-- Astral and Glitched shaders overflowed it, and those cards drew solid black on a Pixel.
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

local renderer_name = "OpenGL ES"
local compiled_sources = {}
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
  graphics = {
    getRendererInfo = function() return renderer_name end,
    validateShader = function() return true end,
    newShader = function(source)
      compiled_sources[#compiled_sources + 1] = source
      return {source = source}
    end,
  },
}

local Engine = require("modloader.lovely")
Engine.load("mods", {enabled = {}, late = {"assets/overhaul/late/mod_shader_precision.toml"}})
local game_object_source = read_disk_file("assets/smods/src/game_object.lua")
local patched_game_object = Engine.apply_patches('=[SMODS _ "src/game_object.lua"]', game_object_source)
ok(patched_game_object ~= game_object_source, "the late patch applies to Steamodded's game_object.lua")

-- pull SMODS.Shader's inject function out of the patched file and run it on its own
local shader_section = patched_game_object:find("SMODS.Shader = SMODS.GameObject:extend", 1, true)
local inject_start = patched_game_object:find("inject = function(self)", shader_section, true)
local inject_end = patched_game_object:find("process_loc_text", inject_start, true)
ok(shader_section and inject_start and inject_end, "SMODS.Shader.inject is in the patched file")
local inject_source = patched_game_object:sub(inject_start, inject_end - 1):gsub(",%s*$", "")
local mod_shader_files = {}
local inject = assert(loadstring("local " .. inject_source .. "\nreturn inject", "@smods/src/game_object.lua"))()
NFS = {
  getNormalizedPath = function(path) return path end,
  read = function(path) return mod_shader_files[path] end,
}
SMODS = {path = "smods/"}
G = {SHADERS = {}}
function sendWarnMessage() end

local astral_source = "extern number screen_scale;\nvec4 effect(vec4 colour, Image texture, vec2 uv, vec2 screen) { return colour; }\n"
mod_shader_files["Mods/Cryptid/assets/shaders/astral.fs"] = astral_source
local astral_shader = {key = "cry_astral", path = "astral.fs", mod = {id = "Cryptid", path = "Mods/Cryptid/", gles_alerted = true}}

inject(astral_shader)
local phone_source = compiled_sources[#compiled_sources]
ok(G.SHADERS.cry_astral ~= nil, "the shader is compiled and stored on a phone")
local high_precision_request = "#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#endif\n"
ok(phone_source:sub(1, #high_precision_request) == high_precision_request,
  "on OpenGL ES the shader starts by asking for high precision when the GPU has it")
ok(phone_source == high_precision_request .. astral_source, "the mod's own shader code follows unchanged")

renderer_name = "OpenGL"
inject(astral_shader)
ok(compiled_sources[#compiled_sources] == astral_source, "on desktop OpenGL the shader is compiled exactly as the mod wrote it")

print(string.format("mod_shader_precision: %d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
