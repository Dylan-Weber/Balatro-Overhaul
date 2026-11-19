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
local M = require("functions/forge/forge_mods")
local Gates = require("functions/forge/forge_gates")

check("parse: gone", select(1, Gates.parse("gone:j_gros_michel")) == "gone" and select(2, Gates.parse("gone:j_gros_michel")) == "j_gros_michel")
check("parse: voucher is not a gate", Gates.parse("v_overstock_norm") == nil)
check("parse: unknown kind", Gates.parse("eat:j_joker") == nil)
check("ok: hand with spaces", Gates.ok("played:Five of a Kind"))
check("ok: refuses junk", not Gates.ok("own:j_x;os.exit()") and not Gates.ok("none") and not Gates.ok(42))
check("make: builds", Gates.make("own", "j_cartomancer") == "own:j_cartomancer" and Gates.make("zzz", "j") == nil)

local g = {hands = {Flush = {played = 0}, Pair = {played = 3}}, pool_flags = {}}
check("met: plain voucher value passes", Gates.met("v_overstock_norm", g, {}))
check("met: gone false at start", not Gates.met("gone:j_gros_michel", g, {}))
g.pool_flags.gros_michel_extinct = true
check("met: Gros Michel extinct flag counts", Gates.met("gone:j_gros_michel", g, {}))
check("met: other Joker not gone", not Gates.met("gone:j_egg", g, {}))
local egg = {config = {center = {key = "j_egg"}}, ability = {set = "Joker"}}
check("record: destroyed Joker", Gates.record_gone(egg, g) and Gates.met("gone:j_egg", g, {}))
local sold = {config = {center = {key = "j_ice_cream"}}, ability = {set = "Joker"}, forge_selling = true}
check("record: sold Joker is not destroyed", not Gates.record_gone(sold, g) and not Gates.met("gone:j_ice_cream", g, {}))
local card = {config = {center = {key = "j_cartomancer"}}}
check("met: own", Gates.met("own:j_cartomancer", g, {card}) and not Gates.met("own:j_cartomancer", g, {egg}))
card.getting_sliced = true
check("met: own ignores a Joker being destroyed", not Gates.met("own:j_cartomancer", g, {card}))
check("met: played", Gates.met("played:Pair", g, {}) and not Gates.met("played:Flush", g, {}) and not Gates.met("played:Rainbow", g, {}))

local tf = Cat.clean_fields("planet", {hand = "Flush", requires = "played:Flush"})
check("clean: planet keeps the gate", tf.requires == "played:Flush", tf.requires)
local bad = Cat.clean_fields("planet", {hand = "Flush", requires = "played:Flush;x()"})
check("clean: planet drops a bad gate", bad.requires ~= "played:Flush;x()")
check("need_v: gated planet is 16", Cat.need_v({kind = "planet", fields = tf}) == 16)
check("need_v: voucher-gated planet stays below 16", Cat.need_v({kind = "planet", fields = Cat.clean_fields("planet", {hand = "Flush", requires = "v_overstock_norm"})}) < 16)

local j = Store.clean({id = "cav2", name = "Cavendish Two", rarity = 1, cost = 4, rules = {}, requires = "gone:j_gros_michel"})
check("store: Joker keeps the gate", j and j.requires == "gone:j_gros_michel")
local j2 = Store.clean({id = "bad", name = "Bad", rarity = 1, cost = 4, rules = {}, requires = "gone:j_a b;c()"})
check("store: drops a bad gate", j2 and j2.requires == nil)
check("store: voucher value still kept", Store.clean({id = "v", name = "V", rules = {}, requires = "v_overstock_norm"}).requires == "v_overstock_norm")
check("mods: gated Joker needs 16", M.needs_v({{rules = {}, requires = "own:j_cartomancer"}}, {}) == 16)
check("mods: plain Joker needs less", M.needs_v({{rules = {}}}, {}) < 16)

check("text: gate label", Gates.text("own:j_cartomancer") ~= nil and Gates.text("v_overstock_norm") == nil)
check("doc: gate line", Gates.doc("played:Flush") ~= nil and Gates.doc("played:Flush"):find("Shows up after") ~= nil)

print(string.format("test_gates: %d/%d passed", total - fails, total))
if fails > 0 then os.exit(1) end
