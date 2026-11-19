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
local R = require("functions/forge/forge_rules")
local T = require("functions/forge/forge_text")
local M = require("functions/forge/forge_moments")
local Bal = require("functions/forge/forge_balance")

local NEW = {"money_earned", "money_spent", "card_drawn", "joker_sold", "joker_added", "tag_added", "boss_beaten", "ante_up", "shop_opened", "hand_leveled", "consumable_added"}
for _, w in ipairs(NEW) do
  check("joker when: " .. w, R.when_ok("joker", w))
  check("text en: " .. w, T.when_text(w, "en") ~= "")
  check("text fr: " .. w, T.when_text(w, "fr") ~= "" and T.when_text(w, "fr") ~= T.when_text(w, "en"))
  check("text es: " .. w, T.when_text(w, "es") ~= "" and T.when_text(w, "es") ~= T.when_text(w, "en"))
end
for _, w in ipairs(M.RUN) do check("run when: " .. w, R.when_ok("run", w, "deck")) end
check("text: joker sold on a deck", T.when_text("joker_sold", "en", "deck") == "When a Joker is sold")

local piggy = R.clean_rules({{when = "money_earned", only = {}, give = {{id = "gain_mult", n = 1}}}})
check("clean: Piggy Bank kept", piggy[1] and piggy[1].when == "money_earned" and piggy[1].give[1].id == "gain_mult")
check("share: format 16", R.need_v(piggy) == 16)
check("share: old rules unchanged", R.need_v(R.clean_rules({{when = "round_end", only = {}, give = {{id = "money", n = 1}}}})) < 16)
local draw = R.clean_rules({{when = "card_drawn", only = {{id = "suit", v = "Hearts"}}, give = {{id = "gain_chips", n = 5}}}})
check("clean: card drawn keeps a card IF", draw[1] and draw[1].only[1] and draw[1].only[1].id == "suit")
local tagger = R.clean_rules({{when = "tag_added", only = {}, give = {{id = "money", n = 3}}}})
check("clean: Tag Collector money", tagger[1] and tagger[1].give[1].n == 3)

check("trigger: forge_when maps", R.trigger_of({forge_when = "card_drawn"}) == "card_drawn")

G.STAGES = {RUN = 1}
G.STAGE = 1
local fired = {}
local function joker(name)
  return {name = name, ability = {set = "Joker"}, calculate_joker = function(self, ctx) fired[#fired + 1] = self.name .. ":" .. tostring(ctx.forge_when) end}
end
local a, b = joker("a"), joker("b")
G.jokers = {cards = {a, b}}
M.fire("joker_sold", {}, a)
check("fire: skips the sold Joker", #fired == 1 and fired[1] == "b:joker_sold", table.concat(fired, ","))
fired = {}
M.busy = {money_earned = true}
M.fire("money_earned", {})
check("fire: no loop while firing", #fired == 0)
M.fire("tag_added", {})
check("fire: other moments still fire inside one", #fired == 2)
fired = {}
M.busy = {}
M.fire("money_earned", {forge_amount = 2})
check("fire: every Joker hears it", #fired == 2)
G.STAGE = 2
fired = {}
M.fire("money_spent", {})
check("fire: only in a run", #fired == 0)

local big = R.clean_rules({{when = "money_spent", only = {{id = "amount", op = "at_least", n = 6}}, give = {{id = "gain_mult", n = 2}}}})
check("amount IF: kept on money moments", big[1] and big[1].only[1] and big[1].only[1].id == "amount" and big[1].only[1].n == 6)
check("amount IF: share format 16", R.need_v(big) == 16)
check("amount IF: only on money moments", R.allowed_only("money_earned", "amount", "joker") and not R.allowed_only("hand_played", "amount", "joker"))
check("amount IF: passes at 6", R.CHECKS.amount({op = "at_least", n = 6}, {forge_amount = 6}) and not R.CHECKS.amount({op = "at_least", n = 6}, {forge_amount = 5}))
check("amount IF: text fr", R.TEXT_ONLY.amount({op = "at_least", n = 6}, {at_least = "au moins"}, "fr"):find("montant", 1, true) ~= nil)
check("card drawn: card IFs for run rules too", R.allowed_only("card_drawn", "suit", "run") and R.allowed_only("card_drawn", "rank", "joker"))
check("hand leveled: poker hand IF", R.allowed_only("hand_leveled", "hand", "joker"))
local astro = R.clean_rules({{when = "hand_leveled", only = {{id = "hand", v = "Flush", mode = "is"}}, give = {{id = "gain_mult", n = 1}}}})
check("clean: Astronomer kept", astro[1] and astro[1].only[1] and astro[1].only[1].v == "Flush")
check("consumable added: it is a Tarot IF", R.allowed_only("consumable_added", "used_kind", "joker"))
check("shop opened: Jokers only", R.when_ok("joker", "shop_opened") and not R.when_ok("run", "shop_opened", "deck"))

G.STAGE = 1
G.GAME.forge_tally = nil
M.busy = {}
M.fire("money_spent", {forge_amount = 5})
M.fire("money_spent", {forge_amount = 2})
M.fire("joker_sold", {})
M.busy = {tag_added = true}
M.fire("tag_added", {})
M.busy = {}
check("tally: $ spent this run", R.count_of({per = "t_spent"}) == 7, R.count_of({per = "t_spent"}))
check("tally: Joker sold this run", R.count_of({per = "t_jsold"}) == 1)
check("tally: counted even inside the same moment", R.count_of({per = "t_tags"}) == 1)
check("tally: nothing drawn yet", R.count_of({per = "t_drawn"}) == 0)
local wallet = R.clean_rules({{when = "hand_played", only = {}, give = {{id = "mult_per", n = 1, per = "t_spent"}}}})
check("count: Big Wallet kept", wallet[1] and wallet[1].give[1].per == "t_spent")
check("count: share format 16", R.need_v(wallet) == 16)
for _, id in ipairs(M.COUNTS) do
  check("count text fr: " .. id, R.PER_TEXT.fr.counts[id] ~= nil and R.PER_TEXT.fr.counts[id] ~= R.PER_TEXT.en.counts[id])
  check("count label: " .. id, R.LABEL_COUNT[id] ~= nil)
end

local ok = pcall(function() return Bal.score_rules and Bal.score_rules(piggy) end)
check("balance: rates known", ok)

print(string.format("test_moments: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
