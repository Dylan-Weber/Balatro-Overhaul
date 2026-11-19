CLASSIC_LAYOUT = CLASSIC_LAYOUT or {}
local C = CLASSIC_LAYOUT

C.KEY = 'classic_layout'

function C.setting()
  local GR = G and G.SETTINGS and G.SETTINGS.GRAPHICS
  return GR and GR[C.KEY] == true or false
end

function C.on()
  if not C.setting() then return false end
  if not (UIK and UIK.touch and UIK.touch()) then return false end
  if PORTRAIT and PORTRAIT.on and PORTRAIT.on() then return false end
  return true
end

function C.plain_zoom(o)
  local c = o and o.definition and o.definition.config
  return c ~= nil and c.classic_plain == true and C.on()
end

function C.install()
  if C.installed then return end
  local ok, Hooks = pcall(require, "overhaul.hooks")
  if not (ok and Hooks) then return end
  C.installed = true
  Hooks.wrap("G.UIDEF", "run_info", function(orig) return function(...)
    local def = orig(...)
    if type(def) == 'table' and def.config and C.on() then def.config.classic_plain = true end
    return def
  end end, {id = "classic_layout.run_info", allow_missing = true})
end

if mod_loc_register then
  mod_loc_register{
    fr = {["Classic Layout"] = "Disposition classique", ["Original compact Run Info and Blind choice"] = "Infos de partie et choix de Blinde compacts d'origine"},
    es = {["Classic Layout"] = "Diseño clásico", ["Original compact Run Info and Blind choice"] = "Info de partida y elección de ciega compactas originales"},
  }
end

C.install()
