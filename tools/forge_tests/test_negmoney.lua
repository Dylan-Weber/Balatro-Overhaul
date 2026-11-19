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
local Bal = require("functions/forge/forge_balance")
local Run = require("functions/forge/forge_run")
local T = require("functions/forge/forge_text")
localize = function(x) if x == "$" then return "$" end return type(x) == "string" and x or "?" end
G.C.RED, G.C.MONEY = {1, 0, 0, 1}, {1, 1, 0, 1}
local said
card_eval_status_text = function(_, _, _, _, _, o) said = o end
ease_dollars = function(n) G.GAME.dollars = G.GAME.dollars + n end

check("num: money goes below 0", R.num("money", -2) == -2 and R.num("money_per", -3) == -3, R.num("money", -2))
local j = Store.clean({id = "leech", name = "Leech", rules = {{when = "hand_played", only = {}, give = {{id = "money", n = -1}}}}})
check("clean: Money -1 kept", j.rules[1].give[1].n == -1, j.rules[1].give[1].n)
check("share: negative money needs 16", R.need_v(j.rules) == 16, R.need_v(j.rules))
check("share: positive money stays old", R.need_v({{when = "hand_played", only = {}, give = {{id = "money", n = 2}}}}) < 16)

G.GAME.dollars, G.GAME.bankrupt_at = 1, 0
check("debt: $1 left, -2 takes 2 like Rental", R.money_cut(-2) == -2, R.money_cut(-2))
G.GAME.dollars = 0
check("debt: $0, still takes 2", R.money_cut(-2) == -2)
check("debt: gains pass", R.money_cut(4) == 4)
G.GAME.dollars, G.GAME.bankrupt_at = 10, 0
local src = {T = {}}
check("pay: -$2", R.pay(-2, src) == -2 and G.GAME.dollars == 8 and said and said.message == "-$2" and said.colour == G.C.RED, said and said.message)
check("pay: +$3 in money colour", R.pay(3, src) == 3 and said.message == "$3" and said.colour == G.C.MONEY)

G.GAME.dollars = 1
local function text(c, lang)
  local ok, l = pcall(D.lines, c, lang)
  if ok and #l > 0 then return table.concat(l, " ") end
  local out = {}
  for _, r in ipairs(c.rules or {}) do out[#out + 1] = T.sentence(r, lang, c.vars) end
  return table.concat(out, " ")
end
check("text en: -$1 in red", text(j, "en"):find("{C:red}-$1{}", 1, true) ~= nil, text(j, "en"))
check("text fr: -1 $ in red", text(j, "fr"):find("{C:red}-1 ${}", 1, true) ~= nil, text(j, "fr"))
check("text es: -$1 in red", text(j, "es"):find("{C:red}-$1{}", 1, true) ~= nil, text(j, "es"))
local tax = Store.clean({id = "tax", name = "Tax Man", rules = {{when = "hand_played", only = {}, give = {{id = "money_per", n = -1, per = "jokers"}}}}})
check("money for each: -1 kept", tax.rules[1].give[1].n == -1)
check("money for each text: red", text(tax, "en"):find("{C:red}-$1{}", 1, true) ~= nil, text(tax, "en"))
check("money for each needs 16", R.need_v(tax.rules) == 16)

local deck = Store.clean_item({id = "poor", kind = "voucher", name = "Poor Voucher", effects = {{id = "money", n = -5}}})
check("run effect: Money now -5 kept", deck.effects[1] and deck.effects[1].n == -5, deck.effects[1] and deck.effects[1].n)
check("run effect: no new share format (negative was already allowed)", Cat.need_v(deck) < 16, Cat.need_v(deck))
check("run effect text: -$5 in red", text(deck, "en"):find("{C:red}-$5{}", 1, true) ~= nil, text(deck, "en"))
local tag = Store.clean_item({id = "fee", kind = "tag", name = "Fee Tag", effects = {{id = "money", n = -3}}})
check("tag text: -$3 in red", text(tag, "en"):find("{C:red}-$3{}", 1, true) ~= nil, text(tag, "en"))
G.GAME.dollars = 3
Run.apply({id = "money", n = -5})
check("run effect: goes into debt like Rental", G.GAME.dollars == -2, G.GAME.dollars)

local toll = Store.clean_item({id = "toll", kind = "sticker", name = "Toll", fields = {look = "Red"}, effects = {{id = "round_money", n = -2}}})
check("sticker Money each round -2 text in red", text(toll, "en"):find("{C:red}-$2{}", 1, true) ~= nil, text(toll, "en"))
local St = require("functions/forge/forge_stickers")
Store.put_item(toll)
St.refresh_list()
local tj = {ability = {set = "Joker"}, set_cost = function() end}
St.apply(tj, "toll")
G.GAME.dollars, G.GAME.bankrupt_at, G.GAME.round = 1, 0, 7
local paid_now
card_eval_status_text = function(_, kind, n) if kind == "dollars" then paid_now = n end end
St.round_end(tj)
check("sticker Money each round goes into debt", G.GAME.dollars == -1 and paid_now == -2, tostring(G.GAME.dollars) .. " " .. tostring(paid_now))

local plain = Store.clean({id = "p", name = "P", rules = {{when = "hand_played", only = {}, give = {{id = "mult", n = 4}}}}})
local costly = Store.clean({id = "c", name = "C", rules = {{when = "hand_played", only = {}, give = {{id = "mult", n = 4}, {id = "money", n = -1}}}}})
local paid = Store.clean({id = "d", name = "D", rules = {{when = "hand_played", only = {}, give = {{id = "mult", n = 4}, {id = "money", n = 1}}}}})
local sp, sc, sd = Bal.of(plain).score, Bal.of(costly).score, Bal.of(paid).score
check("balance: -$1 a hand is a cost", sc < sp and sp < sd, sp .. " " .. sc .. " " .. sd)

print(string.format("negmoney: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
