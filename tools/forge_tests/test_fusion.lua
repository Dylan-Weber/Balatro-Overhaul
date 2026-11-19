package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, extra)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "")) end
end

local files, dirs = {}, {forge = true, ["forge/art"] = true}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end if dirs[p] then return {type = "directory"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function(p) dirs[p] = true return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function() return {} end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end
localize = function(x) return type(x) == "string" and x or "?" end

G = {P_JOKER_RARITY_POOLS = {{}, {}, {}, {}},
  P_CARDS = {}, P_CENTERS = {c_base = {key = "c_base"}}, P_CENTER_POOLS = {},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}}, SETTINGS = {language = "en-us"}, GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, poker_hands = {}, poker_hand_descriptions = {}, dictionary = {}}, descriptions = {}},
}
G.C.SET, G.C.SECONDARY_SET, G.C.UI = {}, {}, {TEXT_LIGHT = {1, 1, 1, 1}}
number_format = function(v) return tostring(v) end

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local D = require("functions/forge/forge_doc")
local Fu = require("functions/forge/forge_fusion")
local M = require("functions/forge/forge_mods")

check("kind: fusion is a Forge kind", Cat.BY_ID.fusion ~= nil)
local f = Cat.clean_fields("fusion", {a = "j_gros_michel", b = "j_cavendish", out = "j_forge_split", cost = 6})
check("fields: kept", f.a == "j_gros_michel" and f.b == "j_cavendish" and f.out == "j_forge_split" and f.cost == 6)
local bad = Cat.clean_fields("fusion", {a = "x_fool", b = "j_a b", out = 5, cost = -3})
check("fields: junk falls back", bad.a == "j_gros_michel" and bad.b == "j_cavendish" and bad.out == "j_joker" and bad.cost == 0, bad.a, bad.cost)
check("share: fusion needs format 16", Cat.need_v({kind = "fusion", fields = f}) == 16)
check("doc: blank fusion has no text", #D.lines(D.blank("fusion"), "en") == 0)
local d = D.new("fusion", {fields = f})
d.unset = nil
local lines = D.lines(d, "en")
check("doc: recipe lines", #lines == 3 and lines[1]:find("j_gros_michel", 1, true) and lines[2]:find("$6", 1, true), lines[1], lines[2])

G.P_CENTERS.j_gros_michel = {key = "j_gros_michel", set = "Joker"}
G.P_CENTERS.j_cavendish = {key = "j_cavendish", set = "Joker"}
G.P_CENTERS.j_forge_split = {key = "j_forge_split", set = "Joker", forge_on = true}
Store.put_item({id = "banana", kind = "fusion", name = "Banana fusion", fields = f})
Store.put_item({id = "off", kind = "fusion", name = "Off", enabled = false, fields = {a = "j_joker", b = "j_joker", out = "j_forge_split"}})
local live_before = Store.live_items
Store.live_items = function() return Store.items() end
check("recipes: live ones only", #Fu.recipes() == 1 and Fu.recipes()[1].out == "j_forge_split", #Fu.recipes())

local function J(key, extra)
  local c = {config = {center = G.P_CENTERS[key] or {key = key, set = "Joker"}}, ability = {}}
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end
local gm, cav, other = J("j_gros_michel"), J("j_cavendish"), J("j_joker")
check("match: both owned", select(2, Fu.match(gm, {gm, cav, other})) == cav)
check("match: from either side", select(2, Fu.match(cav, {gm, cav})) == gm)
check("match: one alone does not fuse", Fu.match(gm, {gm, other}) == nil)
check("match: other Jokers do not", Fu.match(other, {gm, cav, other}) == nil)
G.P_CENTERS.j_forge_split.forge_on = false
check("match: switched off result does not fuse", Fu.match(gm, {gm, cav}) == nil)
G.P_CENTERS.j_forge_split.forge_on = true

check("edition: best stays", Fu.best_edition({edition = {foil = true}}, {edition = {polychrome = true}}) == "polychrome")
check("edition: one side", Fu.best_edition({edition = {holo = true}}, {}) == "holo")
check("edition: none", Fu.best_edition({}, {}) == nil)
check("edition: negative wins", Fu.best_edition({edition = {negative = true}}, {edition = {polychrome = true}}) == "negative")

G.jokers = {cards = {gm, cav}}
gm.area, cav.area = G.jokers, G.jokers
G.GAME.dollars = 10
G.CONTROLLER = {locked = false}
check("can: fuse with money", Fu.can(gm) == true)
G.GAME.dollars = 3
check("can: not enough money", Fu.can(gm) == false)
G.GAME.dollars = 10
cav.ability.eternal = true
check("can: Eternal Jokers do not fuse", Fu.can(gm) == false)
cav.ability.eternal = nil

local mod = M.parse('{"format":"forgemod","v":16,"id":"abcd","name":"T","jokers":[{"id":"split","name":"Banana Split"}],"creations":[{"id":"fz","kind":"fusion","name":"F","fields":{"a":"j_gros_michel","b":"j_cavendish","out":"j_forge_split","cost":5}}]}')
check("mods: imported recipe points at the imported Joker", mod and mod.creations[1] and mod.creations[1].fields.out == "j_forge_" .. mod.jokers[1].id, mod and mod.creations[1] and mod.creations[1].fields.out)
check("mods: recipe needs 16", M.needs_v({}, {Store.get_item("banana")}) == 16)
Store.live_items = live_before

print(string.format("forge fusion: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
