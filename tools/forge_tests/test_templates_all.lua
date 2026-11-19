package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, got)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (got ~= nil and (" got: " .. tostring(got)) or "")) end
end

local files = {}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function() return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function() return {} end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end
G = {P_CENTERS = {}, P_TAGS = {}, P_BLINDS = {}, P_STAKES = {}, localization = {descriptions = {}}, C = {}}

local Cat = require("functions/forge/forge_catalog")
local D = require("functions/forge/forge_doc")

local function list(s) local t = {} for w in s:gmatch("%S+") do t[#t + 1] = w end return t end

local ALL = {
  tarot = list("c_fool c_magician c_high_priestess c_empress c_emperor c_heirophant c_lovers c_chariot c_justice c_strength c_hermit " ..
    "c_wheel_of_fortune c_hanged_man c_death c_temperance c_devil c_tower c_star c_moon c_sun c_judgement c_world"),
  planet = list("c_mercury c_venus c_earth c_mars c_jupiter c_saturn c_uranus c_neptune c_pluto c_planet_x c_ceres c_eris"),
  spectral = list("c_familiar c_grim c_incantation c_talisman c_aura c_wraith c_sigil c_ouija c_ectoplasm c_immolate c_ankh c_deja_vu c_hex c_trance c_medium c_cryptid c_soul c_black_hole"),
  voucher = list("v_overstock_norm v_overstock_plus v_clearance_sale v_liquidation v_hone v_glow_up v_reroll_surplus v_reroll_glut v_crystal_ball v_omen_globe v_telescope v_observatory " ..
    "v_grabber v_nacho_tong v_wasteful v_recyclomancy v_tarot_merchant v_tarot_tycoon v_planet_merchant v_planet_tycoon v_seed_money v_money_tree v_blank v_antimatter " ..
    "v_magic_trick v_illusion v_hieroglyph v_petroglyph v_directors_cut v_retcon v_paint_brush v_palette"),
  deck = list("b_red b_blue b_yellow b_green b_black b_magic b_nebula b_ghost b_abandoned b_checkered b_zodiac b_painted b_anaglyph b_plasma b_erratic"),
  booster = list("p_arcana_normal_1 p_arcana_jumbo_1 p_arcana_mega_1 p_celestial_normal_1 p_celestial_jumbo_1 p_celestial_mega_1 p_spectral_normal_1 p_spectral_jumbo_1 p_spectral_mega_1 " ..
    "p_standard_normal_1 p_standard_jumbo_1 p_standard_mega_1 p_buffoon_normal_1 p_buffoon_jumbo_1 p_buffoon_mega_1"),
  enhancement = list("m_bonus m_mult m_wild m_glass m_steel m_stone m_gold m_lucky"),
  seal = list("Red Blue Gold Purple"),
  tag = list("tag_uncommon tag_rare tag_negative tag_foil tag_holo tag_polychrome tag_investment tag_voucher tag_boss tag_standard tag_charm tag_meteor tag_buffoon tag_handy tag_garbage " ..
    "tag_ethereal tag_coupon tag_double tag_juggle tag_d_six tag_top_up tag_skip tag_orbital tag_economy"),
  blind = list("bl_small bl_big bl_ox bl_hook bl_mouth bl_fish bl_club bl_manacle bl_tooth bl_wall bl_house bl_mark bl_wheel bl_arm bl_psychic bl_goad bl_water bl_eye bl_plant bl_needle bl_head bl_window " ..
    "bl_serpent bl_pillar bl_flint bl_final_acorn bl_final_leaf bl_final_vessel bl_final_heart bl_final_bell"),
  stake = list("stake_white stake_red stake_green stake_black stake_blue stake_purple stake_orange stake_gold"),
}

local COUNT = {tarot = 22, planet = 12, spectral = 18, voucher = 32, deck = 15, booster = 15, enhancement = 8, seal = 4, tag = 24, blind = 30, stake = 8}

local function in_range(spec, v)
  return type(v) == "number" and v >= spec.lo - 1e-9 and v <= spec.hi + 1e-9
end

local function field_spec(kind, id)
  local k = Cat.kind(kind)
  for _, l in ipairs({k.fields or {}, k.adv_fields or {}}) do
    for _, f in ipairs(l) do if f.id == id then return f end end
  end
  return nil
end

local function same_effects(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i].id ~= b[i].id then return false end
    if a[i].n ~= nil and tonumber(a[i].n) ~= tonumber(b[i].n) then return false end
    if a[i].v ~= nil and tostring(a[i].v) ~= tostring(b[i].v) then return false end
  end
  return true
end

for kind, keys in pairs(ALL) do
  local tpl = D.templates(kind)
  local seen, dup = {}, {}
  for _, t in ipairs(tpl) do
    if seen[t.key] then dup[#dup + 1] = t.key end
    seen[t.key] = true
  end
  check(kind .. " no duplicates", #dup == 0, table.concat(dup, ","))
  local missing = {}
  for _, key in ipairs(keys) do if not seen[key] then missing[#missing + 1] = key end end
  check(kind .. " nothing missing", #missing == 0, table.concat(missing, ","))
  local hard = {}
  for _, key in ipairs(keys) do hard[key] = true end
  local extra = {}
  for _, t in ipairs(tpl) do if not hard[t.key] then extra[#extra + 1] = t.key end end
  check(kind .. " count", #keys == COUNT[kind], #keys)
  check(kind .. " only known keys", #extra == 0 or (kind == "planet" and #extra == 1 and extra[1] == "c_black_hole"), table.concat(extra, ","))

  for _, t in ipairs(tpl) do
    local name = kind .. ":" .. t.key
    for fid, v in pairs(t.fields or {}) do
      local f = field_spec(kind, fid)
      if f == nil then
        check(name .. " field " .. fid .. " exists", kind == "enhancement")
      elseif f.type == "num" then
        check(name .. " field " .. fid .. " range", in_range(f.num, v), v)
      elseif f.type == "choice" then
        local ok = false
        for _, o in ipairs(Cat.field_values(f)) do if o == v then ok = true end end
        check(name .. " field " .. fid .. " choice", ok, v)
      end
    end
    for _, e in ipairs(t.effects or {}) do
      local spec = Cat.effect(kind, e.id)
      check(name .. " effect " .. e.id .. " exists", spec ~= nil)
      if spec and spec.num and e.n ~= nil then check(name .. " effect " .. e.id .. " n range", in_range(spec.num, e.n), e.n) end
    end
    local cleaned = Cat.clean_effects(kind, D.copy(t.effects or {}))
    check(name .. " survives clean", same_effects(t.effects or {}, cleaned), #cleaned .. " of " .. #(t.effects or {}))
    local ok, d = pcall(D.from_template, kind, t)
    check(name .. " from_template", ok and type(d) == "table", d)
    if ok and type(d) == "table" then
      check(name .. " from key", d.from == t.key)
      check(name .. " effects kept", same_effects(t.effects or {}, d.effects or {}))
      for fid, v in pairs(t.fields or {}) do
        local f = field_spec(kind, fid)
        if f then check(name .. " field kept " .. fid, d.fields and d.fields[fid] == v, d.fields and d.fields[fid]) end
      end
    end
    check(name .. " approx flag type", t.approx == nil or t.approx == true)
  end
end

print(string.format("templates_all: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
