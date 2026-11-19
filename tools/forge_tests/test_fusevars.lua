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
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local Fu = require("functions/forge/forge_fusion")

local function joker(id, vars) Store.put({id = id, name = id, rarity = 1, cost = 4, rules = {}, vars = vars}) end
joker("piggy", {{name = "Savings", start = 0}, {name = "Power", start = 1}})
joker("hoarder", {{name = "  savings ", start = 0}})
joker("vault", {{name = "Savings", start = 0}, {name = "Power", start = 1}, {name = "Other", start = 3}})
joker("plain", {})
joker("timer", {{name = "Timer", start = 5}})
joker("bomb", {{name = "Timer", start = 5}})
check("store: vars kept", Store.get("piggy") and #Store.get("piggy").vars == 2 and Store.get("hoarder").vars[1].name == "savings", Store.get("hoarder") and Store.get("hoarder").vars[1].name)

local function card(id, vals)
  return {config = {center = {key = "j_forge_" .. id, forge = true, forge_id = id}}, ability = {extra = {vars = vals}}}
end
local function fresh(id) return {config = {center = {key = "j_forge_" .. id, forge = true, forge_id = id}}, ability = {}} end

local made = fresh("vault")
Fu.keep(made, {card("piggy", {6, 1.5}), card("hoarder", {4})})
local v = made.ability.extra and made.ability.extra.vars or {}
check("Savings: 6 + 4 grown", v[1] == 10, v[1])
check("Power: start 1, grew 0.5", v[2] == 1.5, v[2])
check("Other: no ingredient has it, stays at start", v[3] == 3, v[3])

made = fresh("vault")
Fu.keep(made, {card("plain", {}), {config = {center = {key = "j_joker"}}, ability = {}}})
check("no matching vars: nothing set", made.ability.extra == nil or made.ability.extra.vars == nil or made.ability.extra.vars[1] == nil)

made = fresh("bomb")
Fu.keep(made, {card("timer", {3})})
check("countdown carries: 5 went to 3, fused starts at 3", made.ability.extra.vars[1] == 3, made.ability.extra.vars[1])

made = fresh("vault")
Fu.keep(made, {card("piggy", {nil, nil})})
local nv = made.ability.extra and made.ability.extra.vars or {}
check("ingredient never played: fused stays at its starts", (nv[1] == nil or nv[1] == 0) and (nv[2] == nil or nv[2] == 1), nv[1])

joker("typed", {{name = "Savings", type = "rank", v = 14}})
made = fresh("vault")
local okt = pcall(Fu.keep, made, {card("typed", {{rank = 14}})})
check("typed variable is left out", okt and (made.ability.extra == nil or made.ability.extra.vars == nil or made.ability.extra.vars[1] == nil))

local vanilla = {config = {center = {key = "j_joker"}}, ability = {}}
Fu.keep(vanilla, {card("piggy", {6, 1.5})})
check("fused vanilla Joker: untouched", vanilla.ability.extra == nil)

made = fresh("vault")
R.cur_state = {vars = {99}}
Fu.keep(made, {card("piggy", {2, 1})})
check("does not write into a running rule state", made.ability.extra.vars[1] == 2 and R.cur_state.vars[1] == 99)
R.cur_state = nil

print(string.format("fusevars: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
