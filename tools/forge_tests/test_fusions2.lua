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

local function center(key, set, rarity) local c = {key = key, set = set, rarity = rarity} if set == "Tarot" or set == "Planet" or set == "Spectral" then c.consumeable = {} end G.P_CENTERS[key] = c return c end
center("j_joker", "Joker", 1) center("j_jolly", "Joker", 1) center("j_zany", "Joker", 1) center("j_cavendish", "Joker", 1) center("j_gros_michel", "Joker", 1)
center("j_dna", "Joker", 3) center("j_blueprint", "Joker", 3) center("c_death", "Tarot") center("c_hanged_man", "Tarot") center("c_cryptid", "Spectral") center("c_pluto", "Planet")
local function card(key, extra)
  local c = {config = {center = G.P_CENTERS[key]}, ability = {}}
  for k, v in pairs(extra or {}) do c.ability[k] = v end
  return c
end

local f = Cat.clean_fields("fusion", {a = "j_joker", b = "j_jolly", c = "j_zany", out = "j_cavendish", on = "Jokers", auto = true, between = true, sacrifice = true, keep = true})
check("fields: third ingredient and switches kept", f.c == "j_zany" and f.auto == true and f.between == true and f.sacrifice == true and f.keep == true)
check("fields: default third is nothing", Cat.clean_fields("fusion", {}).c == "j_none")
check("fields: consumables", Cat.clean_fields("fusion", {on = "Consumables", a = "c_death", b = "c_hanged_man", out = "c_cryptid"}).a == "c_death")
local ff = Fu.fields({fields = {a = "j_joker", b = "j_jolly", c = "j_none", out = "j_any"}})
check("fields: nothing is no third, any is no result", ff.c == nil and ff.out == nil)

check("fits: exact", Fu.fits(card("j_joker"), "j_joker") and not Fu.fits(card("j_joker"), "j_jolly"))
check("fits: any Joker", Fu.fits(card("j_dna"), "j_any") and not Fu.fits(card("c_death"), "j_any"))
check("fits: any Rare Joker", Fu.fits(card("j_dna"), "j_any_rare") and not Fu.fits(card("j_joker"), "j_any_rare"))
center("j_forge_epicone", "Joker", "rarity_forge_epic")
check("fits: own rarity", Fu.fits(card("j_forge_epicone"), "j_any_r_epic") and not Fu.fits(card("j_dna"), "j_any_r_epic"))
check("fits: any Tarot", Fu.fits(card("c_death"), "c_any_tarot") and not Fu.fits(card("c_pluto"), "c_any_tarot") and Fu.fits(card("c_pluto"), "c_any"))

local trio = {parts = {"j_joker", "j_jolly", "j_zany"}}
local a, b, c, x = card("j_joker"), card("j_jolly"), card("j_zany"), card("j_dna")
local picked = Fu.assign(trio, b, {a, b, x, c})
check("assign: three ingredients found", picked and picked[1] == a and picked[2] == b and picked[3] == c)
check("assign: missing one fails", Fu.assign(trio, b, {a, b, x}) == nil)
local rare = {parts = {"j_gros_michel", "j_any_rare"}}
local gm = card("j_gros_michel")
local p2 = Fu.assign(rare, gm, {gm, a, x})
check("assign: Gros Michel + any Rare Joker", p2 and p2[2] == x)
check("assign: no double use", Fu.assign({parts = {"j_any", "j_any"}}, a, {a}) == nil)

Store.put_item(Store.clean_item({id = "trio", kind = "fusion", name = "Trio", fields = {a = "j_joker", b = "j_jolly", c = "j_zany", out = "j_cavendish", cost = 0, auto = true}}))
Store.put_item(Store.clean_item({id = "rite", kind = "fusion", name = "Rite", fields = {on = "Consumables", a = "c_death", b = "c_hanged_man", out = "c_cryptid", cost = 2}}))
local rs = Fu.recipes()
check("recipes: both", #rs == 2 and rs[1].on == "Consumables" and rs[2].third == "j_zany", #rs)
G.jokers = {cards = {a, b, c}}
G.consumeables = {cards = {card("c_death"), card("c_hanged_man")}}
local r1 = Fu.match(b)
check("match: Trio from the second Joker", r1 and r1.id == "trio")
local r2 = Fu.match(G.consumeables.cards[1])
check("match: Rite from Death", r2 and r2.id == "rite")
check("share: format 16", Cat.need_v(Store.clean_item({id = "t2", kind = "fusion", fields = {a = "j_joker", b = "j_jolly", out = "j_cavendish"}})) == 16)

G.shop_jokers = {cards = {}}
G.jokers = {cards = {a, b}}
local shop = card("j_zany")
shop.area = G.shop_jokers
local h = Fu.hint(shop)
check("hint: Zany in the shop completes Trio", h and h.id == "trio")
local text = table.concat(Fu.hint_text(h), "|")
check("hint: text names the result", text:find("Fuses into", 1, true) ~= nil, text)
local plain = card("j_dna")
plain.area = G.shop_jokers
check("hint: unrelated Joker has none", Fu.hint(plain) == nil)

check("label: specials", R.card_label("j_any_rare") == "Any Rare Joker" and R.card_label("j_none") == "Nothing" and R.card_label("c_any_tarot") == "Any Tarot")
local opts = Fu.ingredient_options("Jokers")
check("options: specials first", opts[1].value == "j_any" and opts[4].value == "j_any_rare")
local copts = Fu.ingredient_options("Consumables")
check("options: consumables", copts[1].value == "c_any" and copts[2].value == "c_any_tarot")

local lines = table.concat(D.lines(Store.clean_item({id = "t3", kind = "fusion", name = "T", fields = {a = "j_joker", b = "j_jolly", c = "j_zany", out = "j_cavendish", auto = true, sacrifice = true, keep = true, between = true}}), "en"), "|")
check("text: third ingredient", lines:find("+ {C:attention}", 1, true) ~= nil, lines)
check("text: switches", lines:find("Fuses by itself", 1, true) and lines:find("random Joker", 1, true) and lines:find("Keeps stickers", 1, true) and lines:find("between rounds", 1, true), lines)

local made = {ability = {extra_value = 0}, set_cost = function() end}
St = require("functions/forge/forge_stickers")
Fu.keep(made, {card("j_joker", {extra_value = 3}), card("j_jolly", {extra_value = 2, forge_stk = "nope"})})
check("keep: sell value adds up", made.ability.extra_value == 5)

print(string.format("forge fusions2: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
