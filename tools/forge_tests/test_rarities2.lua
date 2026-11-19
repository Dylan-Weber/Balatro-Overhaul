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

G = {
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

local Ra = require("functions/forge/forge_rarities")
local X = require("functions/forge/forge_rarityrules")

local f = Cat.clean_fields("rarity", {sell = 3, price_lo = 6, price_hi = 9, shop = false, packs = false})
check("fields: sell", f.sell == 3)
check("fields: price range", f.price_lo == 6 and f.price_hi == 9)
check("fields: not in shop or packs", f.shop == false and f.packs == false)
local d = Cat.clean_fields("rarity", {})
check("fields: defaults change nothing", d.sell == 0 and d.price_lo == 0 and d.price_hi == 0 and d.shop == true and d.packs == true)
check("fields: swapped prices are fixed", X.fields({fields = {price_lo = 9, price_hi = 4}}).price_lo == 4)

check("rules: rarities host joker rules", R.host_of("rarity") == "rarity" and #R.whens("rarity") == #R.JOKER_WHEN)
local epic = Store.clean_item({id = "epic", kind = "rarity", name = "Epic", fields = {colour = "PINK", chance = 5, sell = 2},
  rules = {{when = "hand_played", only = {}, give = {{id = "chips", n = 10}}}}})
check("store: rules kept", epic.rules and epic.rules[1].give[1].id == "chips")
check("rules: joker gives allowed", R.allowed_give("hand_played", "gain_mult", "rarity"))
check("share: format 16", Cat.need_v(epic) == 16)
Store.put_item(epic)
Ra.refresh_list()
local own = "rarity_forge_epic"
check("rarity: Epic live", Ra.by_key[own] ~= nil)
check("joker: Epic Joker gets the rarity rules", X.extra_rules({own_rarity = own}) ~= nil and #X.extra_rules({own_rarity = own}) == 1)
check("joker: Common Joker gets none", X.extra_rules({rarity = 1}) == nil)

local j = R.clean_rules({{when = "hand_played", only = {{id = "jokers_of", v = own, op = "at_least", n = 2}}, give = {{id = "mult", n = 4}}}})
check("IF: Jokers of a rarity survives", j[1] and j[1].only[1] and j[1].only[1].v == own)
check("IF: needs 16", R.need_v(j) == 16)
G.jokers = {cards = {{config = {center = {set = "Joker", rarity = own}}}, {config = {center = {set = "Joker", rarity = own}}}, {config = {center = {set = "Joker", rarity = 3}}}}}
check("IF: 2 Epic Jokers", R.CHECKS.jokers_of({v = own, op = "at_least", n = 2}))
check("IF: not 3 Epic Jokers", not R.CHECKS.jokers_of({v = own, op = "at_least", n = 3}))
check("IF: 1 Rare Joker", R.CHECKS.jokers_of({v = "Rare", op = "at_least", n = 1}))
check("IF: text", R.TEXT_ONLY.jokers_of({v = own, op = "at_least", n = 2}, {at_least = "at least"}, "en"):find("Epic", 1, true) ~= nil)
local x = R.clean_rules({{when = "hand_played", only = {}, give = {{id = "xmult_per", n = 0.5, per = "jokers_rarity", m = own}}}})
check("count: for each Epic Joker survives", x[1] and x[1].give[1].per == "jokers_rarity" and x[1].give[1].m == own)
check("count: 2 Epic Jokers", R.COUNT.jokers_rarity({m = own}) == 2)
check("count: X0.5 for each gives X2", R.AMOUNT.xmult_per(x[1].give[1], nil, {}) == 2, R.AMOUNT.xmult_per(x[1].give[1], nil, {}))
local vals = R.count_matches("jokers_rarity")
check("count: picker offers vanilla and own rarities", vals[1] == "Common" and vals[#vals] == own)
check("count: label", R.count_label({per = "jokers_rarity", m = own}, "en"):find("Epic", 1, true) ~= nil, R.count_label({per = "jokers_rarity", m = own}, "en"))
check("filter: labels", R.FILTER_LABEL("jokers_of", own) == "Epic")

check("shop filter: allowed by default", X.allowed(Ra.by_key[own], "sho"))
Store.put_item(Store.clean_item({id = "hidden", kind = "rarity", name = "Hidden", fields = {shop = false}}))
Ra.refresh_list()
check("shop filter: Hidden not in the shop", not X.allowed(Ra.by_key["rarity_forge_hidden"], "sho"))
check("shop filter: Hidden still in packs", X.allowed(Ra.by_key["rarity_forge_hidden"], "buf"))

local text = table.concat(D.lines(Store.clean_item({id = "t", kind = "rarity", name = "T", fields = {price_lo = 6, price_hi = 9, sell = 2, packs = false}}), "en"), "|")
check("text: price range", text:find("cost {C:money}$6{} to {C:money}$9{}", 1, true) ~= nil, text)
check("text: sell", text:find("sell for", 1, true) ~= nil)
check("text: packs", text:find("Never in Buffoon packs", 1, true) ~= nil)

local wl = X.with_lines({own_rarity = own, rules = {}}, {"own line"}, "en")
check("card text: own lines first", wl[1] == "own line")
check("card text: rarity header", wl[2] and wl[2]:find("As a", 1, true) ~= nil and wl[2]:find("Epic", 1, true) ~= nil, wl[2])
check("card text: rarity rule line", wl[3] and wl[3]:find("10", 1, true) ~= nil, wl[3])
check("card text: fr header", X.with_lines({own_rarity = own}, {}, "fr")[1]:find("En tant que joker", 1, true) ~= nil)
check("card text: es header", X.with_lines({own_rarity = own}, {}, "es")[1]:find("Como comodín", 1, true) ~= nil)
local plain = {"a"}
check("card text: Common Joker unchanged", X.with_lines({rarity = 1}, plain, "en") == plain)

check("smods: shop key", Ra.poll_append("rarity1sho") == "sho")
check("smods: pool key", Ra.poll_append("rarity_Joker3buf") == "buf")
check("smods: no append", Ra.poll_append("rarity2") == nil and Ra.poll_append(nil) == nil)
local relic = Store.clean_item({id = "relic", kind = "rarity", name = "Relic", fields = {colour = "PINK", chance = 5, shop = false}})
Store.put_item(relic)
Ra.refresh_list()
local rk = {key = "rarity_forge_relic"}
Ra.polling = "sho"
check("smods: shop off gives 0 in the shop", Ra.smods_weight(rk, 0.05) == 0)
Ra.polling = "buf"
check("smods: shop off still in Buffoon packs", Ra.smods_weight(rk, 0.05) == 0.05)
Ra.polling = nil
check("smods: other polls unchanged", Ra.smods_weight(rk, 0.05) == 0.05)
local calls = {}
local SM = {poll_rarity = function(pool, key) calls[#calls + 1] = Ra.polling return "x" end}
Ra.hook_poll(SM)
check("smods: hook passes the result", SM.poll_rarity("Joker", "rarity1sho") == "x")
check("smods: hook sets the append while polling", calls[1] == "sho" and Ra.polling == nil)

print(string.format("forge rarities2: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
