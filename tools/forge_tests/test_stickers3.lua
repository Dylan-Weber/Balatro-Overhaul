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
local St = require("functions/forge/forge_stickers")
local X = require("functions/forge/forge_stickerrules")
local Fu = require("functions/forge/forge_fusion")
card_eval_status_text = function() end
ease_dollars = function(n) G.GAME.dollars = (G.GAME.dollars or 0) + n end
G.E_MANAGER = {add_event = function(_, e) if e and e.func then e.func() end end}
Event = function(t) return t end
G.C.FILTER, G.C.MONEY = {}, {}

local function put(t) Store.put_item(Store.clean_item(t)) end
put({id = "cursed", kind = "sticker", name = "Cursed", fields = {look = "Black", colour = "BLACK", chance = 0}, effects = {{id = "mult", n = 4}}})
put({id = "lucky", kind = "sticker", name = "Lucky", fields = {look = "Gold", colour = "GOLD", chance = 0}, effects = {{id = "round_money", n = 1}, {id = "chips", n = 10}}})
put({id = "fresh", kind = "sticker", name = "Fresh", fields = {look = "Green", on = "Any card", life = 3}, effects = {{id = "xmult", n = 1.5}}})
put({id = "doomed", kind = "sticker", name = "Doomed", fields = {look = "Padlock"}, effects = {{id = "rounds_left", n = 5}}})
put({id = "glued", kind = "sticker", name = "Glued", fields = {look = "Red"}, effects = {{id = "no_sell"}}})
St.refresh_list()
check("list: five stickers", #St.list == 5, #St.list)

local function joker() return {ability = {set = "Joker"}, config = {center = {set = "Joker"}}, set_cost = function() end} end
local j = joker()
check("apply: Cursed", St.apply(j, "cursed") and j.ability.forge_stk == "cursed")
check("apply: Lucky adds, Cursed stays", St.apply(j, "lucky") and j.ability.forge_stk == "cursed" and St.has(j, "lucky"))
check("ids: both in order", table.concat(St.ids(j), ",") == "cursed,lucky", table.concat(St.ids(j), ","))
check("all_of: two stickers", #St.all_of(j) == 2)
check("apply: same sticker twice keeps one", St.apply(j, "lucky") and #St.ids(j) == 2)
check("put: own value already there refused", not X.put(j, "sticker_forge_lucky"))
check("put: Fresh as third", X.put(j, "sticker_forge_fresh") and #St.ids(j) == 3)
check("put: Doomed as fourth", X.put(j, "sticker_forge_doomed") and #St.ids(j) == 4)
check("no cap: fifth fits", St.apply(j, "glued") and #St.ids(j) == 5)
check("squeeze: 3 per side keep their gap, 5 squeeze into the same span", St.squeeze(3) == 1 and math.abs(St.squeeze(5) * 4 - 2) < 1e-9)
check("life: Fresh has 3 rounds", St.get(j, "fresh", "life") == 3)
check("left: Doomed has 5 rounds", St.get(j, "doomed", "left") == 5)

local fx = St.effects_on(j)
check("effects: Mult and Chips add up, xMult kept", fx.mult == 4 and fx.chips == 10 and fx.xmult == 1.5 and fx.round_money == 1)
local r = St.score(j, nil)
check("score: Cursed and Lucky and Fresh all count", r and r.mult_mod == 4 and r.chip_mod == 10 and r.Xmult_mod == 1.5, r and tostring(r.mult_mod) .. " " .. tostring(r.chip_mod))

G.GAME.round, G.GAME.dollars = 1, 0
St.round_end(j)
check("round end: Lucky gives $1", G.GAME.dollars == 1, G.GAME.dollars)
check("round end: Fresh 2 left, Doomed 4 left", St.get(j, "fresh", "life") == 2 and St.get(j, "doomed", "left") == 4)
St.round_end(j)
check("round end: once per round", G.GAME.dollars == 1 and St.get(j, "fresh", "life") == 2)
G.GAME.round = 2 St.round_end(j)
G.GAME.round = 3 St.round_end(j)
check("tick: Fresh peeled at round 3, others stay", not St.has(j, "fresh") and St.has(j, "cursed") and St.has(j, "lucky") and St.has(j, "doomed"), table.concat(St.ids(j), ","))
check("tick: Doomed counts on its own", St.get(j, "doomed", "left") == 2, St.get(j, "doomed", "left"))
local gone = false
j.start_dissolve = function() gone = true end
G.GAME.round = 4 St.round_end(j)
G.GAME.round = 5 St.round_end(j)
check("Doomed destroys the Joker after 5 rounds", gone)

local k = joker()
pseudoseed = pseudoseed or function(x) return 0.5 end
pseudorandom_element = pseudorandom_element or function(t) return t[1], 1 end
St.apply(k, "cursed") St.apply(k, "lucky") St.apply(k, "glued")
check("take: named removes only that one", X.take(k, "sticker_forge_lucky") and table.concat(St.ids(k), ",") == "cursed,glued")
check("take: first removed, next moves up", X.take(k, "sticker_forge_cursed") and k.ability.forge_stk == "glued" and k.ability.forge_stk_more == nil)
St.apply(k, "cursed")
check("take: any removes one", X.take(k, "any") and #St.ids(k) == 1)
k.ability.eternal = true
check("take: any can pick a vanilla one", #X.held(k) == 2 and X.take(k, "any") and #X.held(k) == 1)
check("take: any takes the last one", X.take(k, "any") and #X.held(k) == 0 and not St.any(k) and not k.ability.eternal)
check("take: any on a bare card does nothing", not X.take(k, "any"))

local legacy = {ability = {set = "Joker", forge_stk = "fresh", forge_stk_life = 2}}
check("legacy save: one sticker reads as before", table.concat(St.ids(legacy), ",") == "fresh" and St.get(legacy, "fresh", "life") == 2)
local saved = {ability = {set = "Joker", forge_stk = "cursed", forge_stk_more = {{id = "fresh", life = 1}, {id = "fresh"}, "junk", {id = "doomed", left = 3}}}}
check("save: junk and duplicates cleaned", table.concat(St.ids(saved), ",") == "cursed,fresh,doomed", table.concat(St.ids(saved), ","))
check("save: per sticker rounds kept", St.get(saved, "fresh", "life") == 1 and St.get(saved, "doomed", "left") == 3)
local cleared = {ability = {set = "Joker", forge_stk_more = {{id = "lucky"}}}}
check("primary cleared: next sticker moves up", St.ids(cleared)[1] == "lucky" and cleared.ability.forge_stk == "lucky")
check("has: any with extras only", X.has({ability = {forge_stk_more = {{id = "lucky"}}}}, "any"))
check("has: own on second slot", X.has(saved, "sticker_forge_doomed"))

local a, b = joker(), joker()
St.apply(a, "cursed") St.apply(b, "lucky") St.apply(b, "cursed")
local made = joker()
Fu.keep(made, {a, b})
check("fusion: keeps every sticker once", table.concat(St.ids(made), ",") == "cursed,lucky", table.concat(St.ids(made), ","))

G.jokers = {cards = {joker(), joker()}}
St.apply(G.jokers.cards[1], "cursed")
St.apply(G.jokers.cards[2], "cursed")
St.apply(G.jokers.cards[2], "lucky")
check("count: Jokers with Lucky", X.count("sticker_forge_lucky", true) == 1 and X.count("sticker_forge_cursed", true) == 2)

SMODS = {Stickers = {eternal = {key = "eternal"}}, Sticker = {obj_buffer = {"eternal"}}}
G.shared_stickers, G.BADGE_COL = {}, {}
G.localization.misc.labels = {}
G.localization.descriptions.Other = {}
St.register()
check("smods: every own sticker registered", SMODS.Stickers.sticker_forge_cursed ~= nil and SMODS.Stickers.sticker_forge_glued ~= nil and SMODS.Stickers.eternal ~= nil)
local n = 0
for _, key in ipairs(SMODS.Sticker.obj_buffer) do if key:find("sticker_forge_", 1, true) then n = n + 1 end end
check("smods: in obj_buffer once", n == 5, n)
St.register()
n = 0
for _, key in ipairs(SMODS.Sticker.obj_buffer) do if key:find("sticker_forge_", 1, true) then n = n + 1 end end
check("smods: register twice keeps one each", n == 5 and SMODS.Sticker.obj_buffer[1] == "eternal", n)
local o = SMODS.Stickers.sticker_forge_cursed
check("smods: no calculate, hidden badge, no auto roll", o.calculate == nil and o.hide_badge == true and o.rate == 0 and o:should_apply(joker(), {}, nil) == false)
check("smods: label shared", G.localization.misc.labels.sticker_forge_cursed == "Cursed")
local m = joker()
o:apply(m, true)
check("smods: add_sticker puts the Forge sticker", St.has(m, "cursed") and m.ability.sticker_forge_cursed == true)
St.apply(m, "lucky")
check("smods: mirror flag set by the Forge", m.ability.sticker_forge_lucky == true)
SMODS.Stickers.sticker_forge_lucky:apply(m, false)
check("smods: remove_sticker removes the Forge sticker", not St.has(m, "lucky") and m.ability.sticker_forge_lucky == nil and St.has(m, "cursed"))
check("smods: should_apply with bypass checks fit", o:should_apply(joker(), {}, nil, true) and not o:should_apply({ability = {set = "Default"}}, {}, nil, true))
SMODS = nil

print(string.format("stickers3: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
