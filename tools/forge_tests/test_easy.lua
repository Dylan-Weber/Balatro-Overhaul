package.path = "assets/?.lua;" .. package.path
local E = require("functions/forge/forge_easy")

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

check("norm lowers and strips accents", E.norm("Défausse Équipée") == "defausse equipee")
check("norm keeps signs", E.norm("+Mult") == "+mult" and E.norm("XMult") == "xmult")
check("matches every word", E.matches("Gains XMult for each", "xmult each") and not E.matches("Gains XMult", "chips"))
check("empty query matches", E.matches("Anything", "  "))
check("accent query matches", E.matches("Défausses restantes", "defausses"))

local opts = {{label = "+Chips", value = "chips"}, {label = "+Mult", value = "mult"}, {label = "Gains Mult", value = "gain_mult"},
  {label = "Money", value = "money"}, {label = "Shop thing", value = "run:shop_x"}}
local all = E.filter(opts, "", nil, "give")
check("no query no group shows all", #all == 5)
local grow = E.filter(opts, "", "grow", "give")
check("group grow", #grow == 1 and opts[grow[1]].value == "gain_mult")
local q = E.filter(opts, "mult", "money", "give")
check("query ignores group", #q == 2 and q[1] == 2 and q[2] == 3)
check("run values group as run", E.group_for("give", "run:shop_x") == "run")
check("unknown ids are other", E.group_for("give", "brand_new") == "other")
local groups = E.groups_in(opts, "give")
check("groups in order", table.concat(groups, ",") == "score,grow,money,run")

local R = require("functions/forge/forge_rules")
for _, list in ipairs({"give", "only"}) do
  local src = list == "give" and R.GIVE or R.ONLY
  local miss = {}
  for _, id in ipairs(src) do if E.group_for(list, id) == "other" then miss[#miss + 1] = id end end
  check(list .. " ids all grouped (" .. table.concat(miss, " ") .. ")", #miss == 0)
end
for _, id in ipairs(R.whens("joker")) do check("when grouped " .. id, E.group_for("when", id) ~= "other") end

check("below lo says so", E.range_note({lo = 1, hi = 100}, 0) == "It can't go below 1. Type 1 or more.")
check("above hi says so", E.range_note({lo = 1, hi = 100}, 101) == "It can't go above 100. Type 100 or less.")
check("in range is fine", E.range_note({lo = 1, hi = 100}, 1) == nil and E.range_note({lo = 1.1, hi = 5}, 1.1) == nil)
check("decimal lo", E.range_note({lo = 1.1, hi = 5}, 1) ~= nil)

local l, s, r = E.split_num("{C:mult}+98765431{} Mult", 98765431)
check("split +n Mult", l == "{C:mult}" and s == "+" and r == "{} Mult")
l, s, r = E.split_num(" X98765431  Mult", 98765431)
check("split Xn", l == "" and s == "X" and r == "Mult")
l, s, r = E.split_num("you have at least $98765431", 98765431)
check("split money cond", l == "you have at least" and s == "$" and r == "")
l, s, r = E.split_num("with a 1 in 98765431 chance", 98765431)
check("split chance", l == "with a 1 in" and s == "" and r == "chance")
local _, s2, r2, suf = E.split_num("gagnez 98765431$", 98765431)
check("split money suffix", s2 == "" and r2 == "" and suf == "$")
check("split missing mark", E.split_num("retrigger the card", 98765431) == nil)
check("starts signed", E.starts_signed("+4 Mult") and E.starts_signed(" X2 Mult") and not E.starts_signed("earn $3"))


local function sample(label)
  for _, sm in ipairs(E.SAMPLES) do if (sm.label or sm.hand) == label then return sm end end
end
local heart = {{when = "card_scored", only = {{id = "suit", v = "Hearts"}}, give = {{id = "mult", n = 4}}}}
local r1 = E.simulate(heart, {}, sample("Flush of Hearts"))
check("flush of hearts chips", r1.chips == 35 + 2 + 5 + 8 + 10 + 11)
check("flush of hearts mult", r1.mult == 4 + 20 and r1.add_mult == 20)
check("flush of hearts events", #r1.events == 1 and r1.events[1].id == "mult" and r1.events[1].n == 4 and r1.events[1].count == 5)
check("flush of hearts score", r1.score == 71 * 24 and r1.plain_score == 71 * 4)
local rp = E.simulate(heart, {}, sample("Pair of Kings"))
check("pair of kings one heart", rp.add_mult == 4 and rp.mult == 6 and rp.chips == 30)
local r3 = E.simulate({{when = "hand_played", only = {{id = "hand", v = "Pair", mode = "contains"}}, give = {{id = "xmult", n = 2}, {id = "money", n = 3}}}}, {}, sample("Full House"))
check("full house contains pair", r3.xmult == 2 and r3.money == 3 and r3.mult == 8)
local r4 = E.simulate({{when = "hand_played", only = {{id = "hand", v = "Flush", mode = "is"}}, give = {{id = "chips", n = 50}}}}, {}, sample("Pair of Kings"))
check("hand is flush fails on pair", r4.add_chips == 0 and r4.score == 60)
local r5 = E.simulate({{when = "card_scored", only = {{id = "rank", v = 14}}, give = {{id = "retrigger", n = 1}}}}, {}, sample("Three Aces"))
check("retrigger aces adds their chips", r5.chips == 30 + 33 + 33 and r5.add_chips == 33)
local r6 = E.simulate({{when = "hand_played", only = {{id = "chance", n = 4}}, give = {{id = "mult", n = 10}}, alt = {{id = "chips", n = 5}}}}, {}, sample("Pair of Kings"))
check("chance counts as hit", r6.lucky and r6.add_mult == 10 and r6.add_chips == 0)
local r7 = E.simulate({{when = "hand_played", only = {{id = "last_hand"}}, give = {{id = "mult", n = 10}}, alt = {{id = "chips", n = 5}}}}, {}, sample("Pair of Kings"))
check("otherwise used", r7.add_chips == 5 and r7.add_mult == 0)
local r8 = E.simulate({{when = "hand_played", give = {{id = "gain_mult", n = 2}, {id = "create", v = "Tarot"}}}}, {}, sample("Pair of Kings"))
check("gain counts and create skipped", r8.add_mult == 2 and #r8.grows == 1 and r8.skipped[1] == "create")
local r9 = E.simulate({{when = "card_held", only = {{id = "rank", v = 12}}, give = {{id = "xmult", n = 1.5}}}}, {}, sample("Pair of Kings"))
check("held queen x1.5", r9.xmult == 1.5 and r9.mult == 3)
local r10 = E.simulate({{when = "hand_played", give = {{id = "mult", n = 1, nv = 1}}}}, {{name = "c", start = 7}}, sample("Pair of Kings"))
check("number from variable", r10.add_mult == 7)
local r11 = E.simulate({{when = "hand_played", only = {{id = "jokers_with", v = "x"}}, give = {{id = "mult", n = 1}}}}, {}, sample("Pair of Kings"))
check("unknown condition reported", r11.unchecked[1] == "jokers_with" and r11.add_mult == 0)
local r12 = E.simulate({{when = "card_scored", only = {{id = "suit", v = "Hearts", neg = true}}, give = {{id = "chips", n = 10}}}}, {}, sample("Pair of Kings"))
check("not hearts", r12.add_chips == 10)

local wopts = {}
for _, id in ipairs({"card_scored", "hand_played", "before", "after", "card_held", "discard", "reroll", "passive", "card_sold", "boss_beaten", "round_end", "first_hand"}) do
  wopts[#wopts + 1] = {label = id, value = id}
end
local common = E.common(wopts, "when")
check("common keeps order and drops rare", common and common[1].value == "card_scored" and common[2].value == "hand_played" and #common == 7)
check("common nil when nothing to hide", E.common({{label = "a", value = "card_scored"}}, "when") == nil)
for _, list in ipairs({"when", "only", "give"}) do check("common size " .. list, #E.COMMON[list] <= 10) end

print(string.format("test_easy: %d/%d passed, %d failed", total - fails, total, fails))
os.exit(fails == 0 and 0 or 1)
