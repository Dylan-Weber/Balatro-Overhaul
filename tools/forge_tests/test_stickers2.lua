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
local X = require("functions/forge/forge_stickerrules")
local H = require("functions/forge/forge_hostrules")

local f = Cat.clean_fields("sticker", {on = "Playing cards", life = 3})
check("fields: goes on and lasts kept", f.on == "Playing cards" and f.life == 3, tostring(f.on) .. " " .. tostring(f.life))
check("fields: bad goes on falls back", X.fields({fields = {on = "Nope"}}).on == "Jokers")
check("fields: life clamped", X.fields({fields = {life = -4}}).life == 0)

check("rules: stickers host joker rules plus used", R.host_of("sticker") == "sticker" and #R.whens("sticker") == #R.JOKER_WHEN + 1)
check("rules: used is a sticker WHEN", R.when_ok("sticker", "used", "sticker"))
check("rules: joker gives allowed", R.allowed_give("hand_played", "gain_mult", "sticker"))

local cursed = Store.clean_item({id = "cursed", kind = "sticker", name = "Cursed", fields = {look = "Black", colour = "BLACK", chance = 0},
  rules = {{when = "hand_played", only = {}, give = {{id = "xmult", n = 2}}}, {when = "round_end", only = {}, give = {{id = "money", n = -2}}}}})
check("store: rules kept", cursed.rules and #cursed.rules == 2 and cursed.rules[1].give[1].id == "xmult")
check("share: format 16", Cat.need_v(cursed) == 16)
local gold = Store.clean_item({id = "gold", kind = "sticker", name = "Golden Touch", fields = {look = "Gold", on = "Playing cards", chance = 20, life = 0},
  effects = {{id = "mult", n = 4}}, rules = {{when = "card_scored", only = {}, give = {{id = "money", n = 1}}}}})
check("store: playing card sticker kept", gold.fields.on == "Playing cards" and gold.effects[1].id == "mult")
local fresh = Store.clean_item({id = "fresh", kind = "sticker", name = "Fresh", fields = {look = "Green", on = "Any card", life = 3}, effects = {{id = "xmult", n = 1.5}}})
Store.put_item(cursed)
Store.put_item(gold)
Store.put_item(fresh)
St.refresh_list()
check("list: three stickers", #St.list == 3 and St.by_id.gold ~= nil)

local joker = {ability = {set = "Joker"}, config = {center = {set = "Joker"}}}
local card = {ability = {set = "Default"}, config = {center = {}}, base = {}}
local tarot = {ability = {set = "Tarot", consumeable = {}}, config = {center = {}}}
check("fits: Jokers sticker on a Joker", X.fits(cursed, joker) and not X.fits(cursed, card))
check("fits: playing card sticker", X.fits(gold, card) and not X.fits(gold, tarot))
check("fits: any card", X.fits(fresh, joker) and X.fits(fresh, card) and X.fits(fresh, tarot))

check("apply: Golden Touch on a card", St.apply(card, "gold") and card.ability.forge_stk == "gold")
check("apply: no life for good", card.ability.forge_stk_life == nil)
local it = X.card_item(card)
check("card rules: fixed +Mult and own rule", it and #it.c.rules == 2 and it.c.rules[1].give[1].id == "mult" and it.c.rules[2].give[1].id == "money", it and #it.c.rules)
H.forge_stk_wrapped = nil
local items_before = #H.items_on(card)
check("card rules: not on hosts before install", items_before == 0)
check("apply: Fresh lasts 3 rounds", St.apply(tarot, "fresh") and tarot.ability.forge_stk_life == 3)
check("tick: 2 left", not X.tick(tarot) and tarot.ability.forge_stk_life == 2)
X.tick(tarot)
card_eval_status_text = function() end
check("tick: peels off", X.tick(tarot) and tarot.ability.forge_stk == nil)

local own = "sticker_forge_gold"
check("values: any, vanilla and own", X.values()[1] == "any" and X.is_value("eternal") and X.is_value(own) and not X.is_value("nope"))
check("has: own sticker", X.has(card, own) and not X.has(card, "sticker_forge_cursed"))
check("has: any", X.has(card, "any") and not X.has({ability = {}}, "any"))
check("has: eternal", X.has({ability = {eternal = true}}, "eternal"))

local r1 = R.clean_rules({{when = "card_scored", only = {{id = "card_sticker", v = own}}, give = {{id = "mult", n = 3}}}})
check("IF: card has a sticker survives", r1[1] and r1[1].only[1] and r1[1].only[1].v == own)
check("IF: needs 16", R.need_v(r1) == 16)
check("IF: card check", R.CHECKS.card_sticker({v = own}, {}, joker, card))
check("IF: card check fails on a plain card", not R.CHECKS.card_sticker({v = own}, {}, joker, {ability = {}}))
check("IF: text", R.TEXT_ONLY.card_sticker({v = own}, {}, "en"):find("Golden Touch", 1, true) ~= nil)
local j2 = {ability = {set = "Joker", forge_stk = "cursed"}}
G.jokers = {cards = {j2, {ability = {set = "Joker", eternal = true}}, joker}}
G.playing_cards = {card}
check("IF: Jokers with a sticker (2 with any)", R.CHECKS.jokers_sticker({v = "any", op = "at_least", n = 2}))
check("IF: Jokers with Cursed exactly 1", R.CHECKS.jokers_sticker({v = "sticker_forge_cursed", op = "exactly", n = 1}))
local x = R.clean_rules({{when = "hand_played", only = {}, give = {{id = "mult_per", n = 4, per = "stickered", m = "any"}}}})
check("count: for each card with a sticker survives", x[1] and x[1].give[1].per == "stickered" and x[1].give[1].m == "any")
check("count: 3 cards with a sticker", R.COUNT.stickered({m = "any"}) == 3, R.COUNT.stickered({m = "any"}))
check("count: +4 Mult each gives 12", R.AMOUNT.mult_per(x[1].give[1], nil, {}) == 12, R.AMOUNT.mult_per(x[1].give[1], nil, {}))
check("count: label", R.count_label({per = "stickered", m = own}, "en"):find("Golden Touch", 1, true) ~= nil, R.count_label({per = "stickered", m = own}, "en"))

local g = R.clean_rules({{when = "card_scored", only = {{id = "rank", v = 14}}, give = {{id = "stick_card", v = own}}}})
check("DO: put a sticker on the card survives", g[1] and g[1].give[1].id == "stick_card" and g[1].give[1].v == own)
check("DO: only on card WHENs", R.allowed_give("card_scored", "stick_card", "joker") and not R.allowed_give("hand_played", "stick_card", "joker"))
check("DO: text", R.TEXT_GIVE.stick_card(g[1].give[1], {}, "en"):find("Golden Touch", 1, true) ~= nil)
check("DO: needs 16", R.need_v(g) == 16)
G.E_MANAGER = {add_event = function() end}
Event = function(t) return t end
local plain = {ability = {set = "Default"}}
R.DOS.stick_card({v = own}, joker, joker, {}, plain)
check("DO: sticks the scored card", plain.ability.forge_stk == "gold")

local spec = Cat.effect("deck", "stick_deck")
check("deck: sticker on random deck cards", spec ~= nil and spec.v == "sticker")
check("stake: sticker on shop cards", Cat.effect("stake", "stick_shop") ~= nil)
check("challenge: sticker effects", Cat.effect("challenge", "stick_joker") ~= nil and Cat.effect("challenge", "ch_joker_sticker") ~= nil)
check("tarot: sticker on cards in hand", Cat.effect("tarot", "stick_hand") ~= nil or Cat.effect("use", "stick_hand") ~= nil)
check("line: deck text", Cat.fill(spec.line, {v = own, n = 5}, spec):find("Golden Touch", 1, true) ~= nil, Cat.fill(spec.line, {v = own, n = 5}, spec))
G.GAME = {probabilities = {normal = 1}}
check("shop: bonus applied", X.apply({id = "stick_shop", v = own, n = 30}) and X.shop_bonus("gold") == 30)
pseudoseed = function(s) return s end
pseudorandom_element = function(t) return t[1], 1 end
local deck = {{ability = {set = "Default"}}, {ability = {set = "Default"}}, {ability = {set = "Default"}}}
G.playing_cards = deck
X.apply({id = "stick_deck", v = own, n = 2})
check("deck: 2 cards stuck", deck[1].ability.forge_stk == "gold" and deck[2].ability.forge_stk == "gold" and deck[3].ability.forge_stk == nil)

local m = X.merge(joker, {mult_mod = 4, message = "+4"}, {Xmult_mod = 2, message = "X2"})
check("merge: both effects kept", m.mult_mod == 4 and m.Xmult_mod == 2)
check("merge: one side nil", X.merge(joker, nil, {mult_mod = 1}).mult_mod == 1 and X.merge(joker, {chip_mod = 2}, nil).chip_mod == 2)
check("merge: repetitions add", X.merge(joker, {repetitions = 1}, {repetitions = 2}).repetitions == 3)

local text = table.concat(D.lines(gold, "en"), "|")
check("text: goes on", text:find("Goes on", 1, true) ~= nil, text)
check("text: for your cards", text:find("A sticker for your cards", 1, true) ~= nil, text)
local text2 = table.concat(D.lines(fresh, "en"), "|")
check("text: peels off", text2:find("Peels off after {C:attention}3{} rounds", 1, true) ~= nil, text2)
local text3 = table.concat(D.lines(cursed, "en"), "|")
check("text: rules shown", text3:find("X", 1, true) ~= nil, text3)

local T = require("functions/forge/forge_text")
X.text()
check("WHEN text: card scores on a sticker", T.when_text("card_scored", "en", "sticker") == "When a card scores (on a card: this card)", T.when_text("card_scored", "en", "sticker"))
check("WHEN text: used", T.when_text("used", "en", "sticker") == "When this card is used")

print(string.format("forge stickers2: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
