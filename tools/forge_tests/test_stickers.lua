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
local St = require("functions/forge/forge_stickers")

check("kind: sticker is a Forge kind", Cat.BY_ID.sticker ~= nil)
local f = Cat.clean_fields("sticker", {look = "Black", colour = "RED", chance = 25})
check("fields: kept", f.look == "Black" and f.colour == "RED" and f.chance == 25)
local bad = Cat.clean_fields("sticker", {look = "Nope", colour = "NOPE", chance = 400})
check("fields: bad look falls back", bad.look == "Purple")
check("fields: chance capped", bad.chance == 100, bad.chance)
check("share: sticker needs format 16", Cat.need_v({kind = "sticker", fields = {look = "Black"}}) == 16)
check("effects: sticker list", #Cat.effects_for("sticker") >= 8)
check("effects: Simple has the Cursed parts", Cat.effect("sticker", "times").simple and Cat.effect("sticker", "round_money").simple)
local fx = Cat.clean_effects("sticker", {{id = "times", n = 2}, {id = "round_money", n = -2}, {id = "bogus"}})
check("effects: cleaned", #fx == 2 and fx[1].n == 2 and fx[2].n == -2, #fx)

local cursed = {id = "cursed", kind = "sticker", name = "Cursed", fields = {look = "Black", colour = "BLACK", chance = 20}, effects = {{id = "times", n = 2}, {id = "round_money", n = -2}}}
local lucky = {id = "lucky", kind = "sticker", name = "Lucky", mode = "advanced", fields = {look = "Gold", colour = "GOLD", chance = 0}, effects = {{id = "mult", n = 4}, {id = "no_sell"}, {id = "rounds_left", n = 2}, {id = "sell_gain", n = 3}}}
Store.put_item(cursed)
Store.put_item(lucky)
local live_before = Store.live_items
Store.live_items = function() return Store.items() end
G.BADGE_COL = {eternal = {1, 1, 1, 1}}
St.register()
check("register: two stickers", #St.list == 2)
check("register: badge colour kept and added", G.BADGE_COL.eternal ~= nil and G.BADGE_COL.forge_stk_cursed ~= nil)
check("register: badge name", G.localization.misc.labels.forge_stk_cursed == "Cursed")
check("register: tooltip text", G.localization.descriptions.Other.forge_stk_cursed ~= nil)
local e = St.effects(Store.get_item("cursed"))
check("effects: Cursed sums", e.times == 2 and e.round_money == -2)
check("values: own stickers offered", Cat.values("sticker")[1] == "sticker_forge_cursed")
check("label: own name", Cat.value_label("sticker", "sticker_forge_cursed") == "Cursed")
local tar = {kind = "tarot", fields = {cost = 3, select = 0}, effects = {{id = "put_sticker", v = "sticker_forge_cursed"}}}
check("tarot: put a sticker needs format 16", Cat.need_v(tar) == 16)
local cl = Cat.clean_effects("tarot", tar.effects)
check("tarot: own sticker kept", cl[1] and cl[1].v == "sticker_forge_cursed", cl[1] and cl[1].v)

local card = {ability = {set = "Joker"}, set_cost = function(self) self.cost_set = true end}
check("apply: unknown sticker refused", St.apply(card, "nope") == false)
check("apply: Cursed", St.apply(card, "cursed") and card.ability.forge_stk == "cursed" and card.cost_set)
local r = St.score(card, {mult_mod = 4, message = "+4"})
check("score: Cursed doubles Mult", r.mult_mod == 8, r.mult_mod)
r = St.score(card, {Xmult_mod = 3, chip_mod = 10, message = "x"})
check("score: Cursed doubles XMult and Chips", r.Xmult_mod == 6 and r.chip_mod == 20)
check("score: nothing to double stays nothing", St.score(card, nil) == nil)
local c2 = {ability = {set = "Joker"}}
St.apply(c2, "lucky")
r = St.score(c2, nil)
check("score: Lucky adds its own", r and r.mult_mod == 4 and r.card == c2)
check("score: chips and XMult add up", (function()
  local t = St.score({ability = {forge_stk = "x"}}, nil) == nil
  St.by_id.tmp = {id = "tmp", c = {effects = {{id = "chips", n = 10}, {id = "xmult", n = 1.5}}}}
  local o = St.score({ability = {forge_stk = "tmp"}}, nil)
  St.by_id.tmp = nil
  return t and o.chip_mod == 10 and o.Xmult_mod == 1.5
end)())
check("score: Lucky adds to the Joker's", St.score(c2, {mult_mod = 2}).mult_mod == 6)
check("apply: rounds left set", c2.ability.forge_stk_left == 2)

local money = 0
G.GAME.dollars = 100
ease_dollars = function(n) money = money + n end
card_eval_status_text = function() end
Event = function(t) return t end
G.E_MANAGER = {add_event = function(_, ev) ev.func() end}
G.GAME.round = 1
St.round_end(card)
check("round: Cursed costs $2", money == -2, money)
St.round_end(card)
check("round: once per round", money == -2, money)
G.GAME.round = 2
St.round_end(card)
check("round: next round costs again", money == -4, money)
c2.set_cost = function() end
c2.start_dissolve = function(self) self.gone = true end
G.GAME.round = 1
St.round_end(c2)
check("round: sell value grows", c2.ability.extra_value == 3 and c2.ability.forge_stk_left == 1)
G.GAME.round = 2
St.round_end(c2)
check("round: destroyed when rounds run out", c2.gone == true)

pseudorandom = function() return 0.1 end
pseudoseed = function(s) return s end
local shop = {ability = {set = "Joker"}}
check("shop: 20% Cursed lands on a low roll", St.roll_shop(shop) == "cursed" and shop.ability.forge_stk == "cursed")
pseudorandom = function() return 0.5 end
local shop2 = {ability = {set = "Joker"}}
check("shop: high roll no sticker", St.roll_shop(shop2) == nil and shop2.ability.forge_stk == nil)
check("shop: Tarots never get one", St.roll_shop({ability = {set = "Tarot"}}) == nil)

Card = {can_sell_card = function() return true end, calculate_joker = function(self, ctx) return {mult_mod = 3, message = "+3"} end}
St.install_hooks()
local sell = setmetatable({ability = {set = "Joker", forge_stk = "lucky"}}, {__index = Card})
check("sell: Lucky can't be sold", sell:can_sell_card() == false)
local plain = setmetatable({ability = {set = "Joker"}}, {__index = Card})
check("sell: plain Joker still sells", plain:can_sell_card() == true)
local cj = setmetatable({ability = {set = "Joker", forge_stk = "cursed"}}, {__index = Card})
check("hook: joker_main doubled", cj:calculate_joker({joker_main = true}).mult_mod == 6)
check("hook: Blueprint copy not doubled", cj:calculate_joker({joker_main = true, blueprint = true}).mult_mod == 3)

Store.live_items = function() return {} end
St.register()
check("register: removed stickers leave", #St.list == 0 and St.of_card(card) == nil)
check("score: removed sticker does nothing", St.score(card, {mult_mod = 4}).mult_mod == 4)
Store.live_items = live_before

print(string.format("forge stickers: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
