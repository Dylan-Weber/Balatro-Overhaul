-- Mod shaders on phones (OpenGL ES) are compiled at high float precision.
-- Patches Steamodded's real src/game_object.lua with the real Overhaul late patches through
-- the real lovely engine, runs the real SMODS.Shader inject with a recording newShader, and,
-- when glslangValidator is installed, compiles the shaders as GLSL ES 1.00 behind a header
-- shaped like LOVE's (effect() declared at the default precision before the mod's code).
-- Bug this guards: LOVE compiles pixel shaders at medium precision on OpenGL ES, Cryptid's
-- Astral and Glitched shaders overflowed it, and those cards drew solid black on a Pixel.
-- It also guards Astral's star field on high-density screens: it mixed screen_coords (pixels)
-- with mouse_screen_pos and screen_scale (screen units) and blew out to white on the phone.
-- A plain "precision highp float;" on top does not compile there (Steamodded then swaps in an
-- empty shader and the effect disappears), so this also checks the raised shaders compile.
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
local refuse_raised_shaders = false
local stub_shader = {stub = true}
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
    -- like Steamodded's GLSL ES wrapper: a shader that does not compile becomes its stub
    newShader = function(source)
      compiled_sources[#compiled_sources + 1] = source
      if refuse_raised_shaders and source:find("precision highp float", 1, true) then return stub_shader end
      return {source = source}
    end,
  },
}

local Engine = require("modloader.lovely")
Engine.load("mods", {enabled = {}, late = {"assets/overhaul/late/mod_shader_precision.toml"}})
love.graphics.getDPIScale = function() return 2.4381 end
local game_object_source = read_disk_file("assets/smods/src/game_object.lua")
local patched_game_object = Engine.apply_patches('=[SMODS _ "src/game_object.lua"]', game_object_source)
ok(patched_game_object:find('require("functions/mod_shader_precision").compile(file)', 1, true) ~= nil,
  "Steamodded compiles mod shaders through mod_shader_precision")

-- pull SMODS.Shader's inject function out of the patched file and run it on its own
local shader_section = patched_game_object:find("SMODS.Shader = SMODS.GameObject:extend", 1, true)
local inject_start = patched_game_object:find("inject = function(self)", shader_section, true)
local inject_end = patched_game_object:find("process_loc_text", inject_start, true)
local inject_source = patched_game_object:sub(inject_start, inject_end - 1):gsub(",%s*$", "")
local mod_shader_files = {}
local inject = assert(loadstring("local " .. inject_source .. "\nreturn inject", "@smods/src/game_object.lua"))()
NFS = {
  getNormalizedPath = function(path) return path end,
  read = function(path) return mod_shader_files[path] end,
}
SMODS = {path = "smods/", shader_stub = stub_shader}
G = {SHADERS = {}}
function sendWarnMessage() end

-- A mod shader shaped like Cryptid's: a helper declared before effect() and defined after it,
-- math in effect(), and a vertex position() function.
local mod_shader_source = [[
extern MY_HIGHP_OR_MEDIUMP vec2 astral;
vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv);
float scaled_noise(vec2 point) { return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453); }
vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec4 tex = Texel(texture, texture_coords);
    // a comment with a brace } in it
    float big = scaled_noise(texture_coords * 4096. + astral);
    if (big > 2.) { tex.r = 0.; }
    return dissolve_mask(tex * colour, texture_coords, texture_coords);
}
vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) { return tex; }
#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position ) { return transform_projection * vertex_position; }
#endif
]]
mod_shader_files["Mods/Example/assets/shaders/astral.fs"] = mod_shader_source
local mod_shader = {key = "example_astral", path = "astral.fs", mod = {id = "Example", path = "Mods/Example/", gles_alerted = true}}

local mod_shader_precision = dofile("assets/functions/mod_shader_precision.lua")
local raised_source = mod_shader_precision.raise(mod_shader_source)

inject(mod_shader)
ok(compiled_sources[#compiled_sources] == raised_source, "on OpenGL ES the shader is compiled at high precision")
ok(G.SHADERS.example_astral and G.SHADERS.example_astral.source == raised_source, "and that shader is the one stored")
ok(raised_source:sub(1, #mod_shader_precision.high_precision) == mod_shader_precision.high_precision, "high precision comes first")
local effect_position = raised_source:find("vec4 effect(", 1, true)
local default_position = raised_source:find(mod_shader_precision.default_precision, 1, true)
ok(default_position and default_position < effect_position, "effect()'s parameters keep LOVE's default precision")
local body_open = raised_source:find("{", effect_position, true)
ok(raised_source:find(mod_shader_precision.high_precision, body_open, true) == body_open + 2, "effect()'s body switches to high precision")
local mask_definition = raised_source:find("vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) {", 1, true)
local last_high = select(1, raised_source:find(mod_shader_precision.high_precision, body_open + 10, true))
ok(last_high and mask_definition and last_high < mask_definition, "functions after effect() are back at high precision")
local stripped = raised_source:gsub(mod_shader_precision.high_precision:gsub("%p", "%%%0"), ""):gsub(mod_shader_precision.default_precision:gsub("%p", "%%%0"), ""):gsub("\n", "")
ok(stripped == mod_shader_source:gsub("\n", ""), "the mod's own code is unchanged apart from the precision lines")

-- if the raised shader does not compile on the phone, the mod's shader is used as written
refuse_raised_shaders = true
G.SHADERS = {}
inject(mod_shader)
ok(G.SHADERS.example_astral and G.SHADERS.example_astral.source == mod_shader_source, "a raised shader that fails falls back to the original")
refuse_raised_shaders = false

-- desktop is untouched
renderer_name = "OpenGL"
G.SHADERS = {}
inject(mod_shader)
ok(compiled_sources[#compiled_sources] == mod_shader_source, "on desktop OpenGL the shader is compiled exactly as the mod wrote it")
renderer_name = "OpenGL ES"

-- shaders that already pick a precision, or have no effect(), are left alone
ok(mod_shader_precision.raise("precision highp float;\n" .. mod_shader_source) == "precision highp float;\n" .. mod_shader_source, "a shader with its own precision is left alone")
ok(mod_shader_precision.raise("#pragma language glsl3\n" .. mod_shader_source) == "#pragma language glsl3\n" .. mod_shader_source, "a GLSL 3 shader is left alone")
ok(mod_shader_precision.raise("vec4 position(mat4 a, vec4 b) { return a * b; }") == "vec4 position(mat4 a, vec4 b) { return a * b; }", "a shader without effect() is left alone")

-- Cryptid's Astral: screen_coords goes into screen units before it meets mouse_screen_pos
local astral_excerpt = table.concat({
  "extern MY_HIGHP_OR_MEDIUMP vec2 mouse_screen_pos;",
  "extern MY_HIGHP_OR_MEDIUMP float hovering;",
  "extern MY_HIGHP_OR_MEDIUMP float screen_scale;",
  "vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )",
  "{",
  "    vec2 mouse_offset = (screen_coords.xy - mouse_screen_pos.xy)/screen_scale;",
  "    return colour * length(mouse_offset);",
  "}",
  ""}, "\n")
local patched_astral = Engine.apply_patches('=[SMODS Cryptid "astral.fs"]', astral_excerpt)
ok(patched_astral:find("extern MY_HIGHP_OR_MEDIUMP float overhaul_pixel_density;", 1, true) ~= nil, "Astral declares overhaul_pixel_density")
ok(patched_astral:find("(screen_coords.xy / overhaul_pixel_density - mouse_screen_pos.xy)/screen_scale", 1, true) ~= nil, "Astral divides screen_coords by the pixel density")
ok(Engine.apply_patches('=[SMODS Cryptid "glitched_b.fs"]', astral_excerpt) == astral_excerpt, "other Cryptid shaders are not given the pixel density")

mod_shader_files["Mods/Cryptid/assets/shaders/astral.fs"] = patched_astral
local astral_shader = {key = "cry_astral", path = "astral.fs", mod = {id = "Cryptid", path = "Mods/Cryptid/", gles_alerted = true},
  send_vars = function() return {astral_twinkle = 3} end}
inject(astral_shader)
local astral_variables = astral_shader.send_vars()
ok(astral_variables.overhaul_pixel_density == 2.4381, "Astral is sent the screen's pixels per unit")
ok(astral_variables.astral_twinkle == 3, "the mod's own shader variables are still sent")
local plain_shader = {key = "example_plain", path = "astral.fs", mod = mod_shader.mod}
inject(plain_shader)
ok(plain_shader.send_vars == nil, "a shader without the uniform gets nothing extra")

-- compile as GLSL ES 1.00 the way a phone does, when the validator is available
local validator_found = os.execute("command -v glslangValidator >/dev/null 2>&1")
if validator_found == 0 or validator_found == true then
  local love_like_header = table.concat({
    "#version 100", "#define PIXEL", "precision mediump float;",
    "#define number float", "#define Image sampler2D", "#define extern uniform", "#define Texel texture2D",
    "#define MY_HIGHP_OR_MEDIUMP highp",
    "vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 pixcoord);", ""}, "\n")
  local love_like_footer = "\nuniform sampler2D MainTex;\nvarying vec2 VaryingTexCoord;\nvoid main() { gl_FragColor = effect(vec4(1.0), MainTex, VaryingTexCoord, gl_FragCoord.xy); }\n"
  local function compiles(shader_source)
    local path = os.tmpname() .. ".frag"
    local handle = io.open(path, "wb")
    handle:write(love_like_header .. shader_source .. love_like_footer)
    handle:close()
    local result = os.execute("glslangValidator " .. path .. " >/dev/null 2>&1")
    os.remove(path)
    return result == 0 or result == true
  end
  ok(compiles(mod_shader_source), "the mod's shader compiles as GLSL ES as written")
  ok(not compiles(mod_shader_precision.high_precision .. mod_shader_source), "a plain high precision line on top does not compile (the old fix)")
  ok(compiles(raised_source), "the raised shader compiles as GLSL ES")
  ok(compiles(mod_shader_precision.raise(patched_astral)), "the patched Astral excerpt compiles as GLSL ES at high precision")
else
  print("skipping the GLSL ES compile checks (no glslangValidator)")
end

print(string.format("mod_shader_precision: %d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
