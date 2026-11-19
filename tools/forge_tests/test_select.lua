package.path = "assets/?.lua;" .. package.path
local files, dirs = {}, {}
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
local R = require("functions/forge/forge_rules")
local Cat = require("functions/forge/forge_catalog")
local T = require("functions/forge/forge_text")
local S = R.SELECT

local fails, total = 0, 0
local function check(name, ok, ...)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name, ...) end
end

local function hand_area()
  local h = {config = {highlighted_limit = 5}, highlighted = {}}
  function h:remove_from_highlighted(c)
    for i, v in ipairs(self.highlighted) do if v == c then table.remove(self.highlighted, i) return end end
  end
  return h
end
local function reset()
  G = {hand = hand_area(), GAME = {starting_params = {}, blind = {in_blind = false}}, C = {FILTER = {}, UI = {BACKGROUND_INACTIVE = "grey"}, BLUE = "blue", RED = "red"}}
  SMODS = nil
end
reset()
localize = function(k) return k == "b_limit" and "Limit: " or k end

check("module loaded", S ~= nil and S.V == 16)
for _, id in ipairs({"p_select", "select_plus", "select_round"}) do
  check(id .. " in the DO list", R.member(R.GIVE, id))
  check(id .. " has a label", R.LABEL_GIVE[id] ~= nil and R.SIMPLE_GIVE[id])
  for _, lang in ipairs({"en", "fr", "es"}) do
    local t = R.TEXT_GIVE[id]({id = id, n = 2}, {}, lang)
    check(id .. " text " .. lang, t:find("+2", 1, true) ~= nil and not t:find("%%"), t)
  end
  check(id .. " needs format 16", R.need_v({{when = id == "p_select" and "passive" or "round_end", give = {{id = id, n = 1}}}}) >= 16)
end
check("negative text", R.TEXT_GIVE.p_select({id = "p_select", n = -1}, {}, "en"):find("-1", 1, true) ~= nil)
check("p_select only while owned", R.allowed_give("passive", "p_select", "joker") and not R.allowed_give("round_end", "p_select", "joker"))
check("select_plus on a Joker rule", R.allowed_give("round_end", "select_plus", "joker") and R.allowed_give("blind_selected", "select_round", "joker"))
check("select_plus not passive", not R.allowed_give("passive", "select_plus", "joker"))
local P = require("functions/forge/forge_power3")
check("p_select is a passive", R.member(P.PASSIVE, "p_select") and P.KEY.p_select == "select" and P.APPLY.select ~= nil)

local function has(kind, id)
  for _, e in ipairs(Cat.EFFECTS[kind] or {}) do if e.id == id then return e end end
  return nil
end
for _, k in ipairs({"voucher", "deck", "stake", "challenge", "use", "spectral", "tag"}) do
  check(k .. " offers select_plus", has(k, "select_plus") ~= nil)
  check(k .. " offers select_round", has(k, "select_round") ~= nil)
end
check("voucher select_plus is a run effect", has("voucher", "select_plus").run == true and has("voucher", "select_plus").need == 16)
check("tarot select_plus is not a run effect", has("use", "select_plus").run == nil)
check("deck sets the limit", has("deck", "select_set") and has("deck", "select_set").num.def == 7)
check("challenge sets the limit", has("challenge", "select_set") ~= nil)
check("boss caps the limit", has("boss", "select_cap") and has("boss", "select_cap").num.def == 3)
check("boss has no select_plus", has("boss", "select_plus") == nil)
check("boss select_round", has("boss", "select_round") ~= nil)
check("planet has none", has("planet", "select_plus") == nil)
check("simple voucher", has("voucher", "select_plus").simple == true)
local line = Cat.fill(has("voucher", "select_plus").line, {id = "select_plus", n = 1}, has("voucher", "select_plus"))
check("voucher line", tostring(line):find("+1", 1, true) ~= nil, line)
local dl = Cat.fill(has("deck", "select_set").line, {id = "select_set", n = 7}, has("deck", "select_set"))
check("deck line", tostring(dl):find("7", 1, true) ~= nil, dl)
check("fr deck line", S.LOC.fr["You can select {C:attention}%d{} cards"] ~= nil and S.LOC.es["You can only select {C:attention}%d{} cards"] ~= nil)

reset()
S.change(2)
check("plain +2", G.GAME.starting_params.play_limit == 7 and G.GAME.starting_params.discard_limit == 7 and G.hand.config.highlighted_limit == 7)
S.change(-2)
check("plain back to 5", G.hand.config.highlighted_limit == 5)
S.change(-10)
check("at least 1", G.hand.config.highlighted_limit == 1 and select(1, S.limits()) == 1)
S.change(10)
check("raw count kept", G.GAME.starting_params.play_limit == 5)
S.set(7)
check("set to 7", G.GAME.starting_params.play_limit == 7 and G.hand.config.highlighted_limit == 7)
G.hand.highlighted = {1, 2, 3, 4, 5}
S.cap(3)
check("cap 3", select(1, S.limits()) == 3 and G.hand.config.highlighted_limit == 3 and #G.hand.highlighted == 3)
S.change(2)
check("cap holds with a bigger limit", select(1, S.limits()) == 3 and G.GAME.starting_params.play_limit == 9)
S.uncap()
check("uncap", select(1, S.limits()) == 9)
S.set(5)

reset()
S.round(2)
check("one round waits for the blind", G.GAME.forge_sel_next == 2 and G.hand.config.highlighted_limit == 5)
G.GAME.blind.in_blind = true
S.round_start()
check("one round starts", G.hand.config.highlighted_limit == 7 and G.GAME.forge_sel_round == 2)
S.round(1)
check("one round inside the blind", G.hand.config.highlighted_limit == 8)
S.round_end()
check("one round ends", G.hand.config.highlighted_limit == 5 and G.GAME.forge_sel_round == nil)
S.cap(3)
S.round_end()
check("round end lifts the cap", G.GAME.forge_sel_cap == nil and G.hand.config.highlighted_limit == 5)

reset()
check("apply select_plus", S.apply({id = "select_plus", n = 1}) and G.GAME.starting_params.play_limit == 6)
check("apply select_set", S.apply({id = "select_set", n = 3}) and G.GAME.starting_params.play_limit == 3)
check("apply other ids", S.apply({id = "money", n = 1}) == false)
P.APPLY.select(2)
check("passive add", G.GAME.starting_params.play_limit == 5)
R.DOS.select_plus({id = "select_plus", n = 2}, nil, nil)
check("DO select_plus", G.GAME.starting_params.play_limit == 7)

reset()
local calls = {}
SMODS = {hand_limit_strings = {play = "", discard = ""},
  change_play_limit = function(d) calls[#calls + 1] = "p" .. d; G.GAME.starting_params.play_limit = G.GAME.starting_params.play_limit + d end,
  change_discard_limit = function(d) calls[#calls + 1] = "d" .. d; G.GAME.starting_params.discard_limit = G.GAME.starting_params.discard_limit + d end,
  update_hand_limit_text = function() end}
S.change(2)
check("Steamodded limit functions", calls[1] == "p2" and calls[2] == "d2" and G.hand.config.highlighted_limit == 7)
S.change(-4)
check("Steamodded follows a lower limit", G.hand.config.highlighted_limit == 3)
S.cap(2)
check("Steamodded cap", G.hand.config.highlighted_limit == 2 and SMODS.hand_limit_strings.play == "Limit: 2")
SMODS = nil

local function card(rank, suit) return {rank = rank, suit = suit, get_id = function(self) return self.rank end, is_suit = function(self, s) return self.suit == s end, get_nominal = function(self) return self.rank end} end
local function cards(spec)
  local out = {}
  for tok in spec:gmatch("%S+") do
    local r, s = tok:match("^(%d+)(%a)$")
    local suits = {H = "Hearts", S = "Spades", C = "Clubs", D = "Diamonds"}
    out[#out + 1] = card(tonumber(r), suits[s])
  end
  return out
end
local function best(res)
  for _, k in ipairs({"Flush Five", "Flush House", "Five of a Kind", "Straight Flush", "Four of a Kind", "Full House", "Flush", "Straight", "Three of a Kind", "Two Pair", "Pair", "High Card"}) do
    if res[k] and res[k][1] then return k, #res[k][1] end
  end
end
local function ev(spec, o) return best(S.evaluate(cards(spec), o)) end
local k, n = ev("2H 5H 7H 9H 11H 13H")
check("6 card flush", k == "Flush" and n == 6, k, n)
k, n = ev("3S 4H 5C 6D 7S 8H 9C")
check("7 card straight", k == "Straight" and n == 7, k, n)
k, n = ev("2H 4H 6H 8H 10H 9S 11C 12D 13S")
check("flush beats a mixed straight", k == "Flush", k, n)
k, n = ev("2H 3H 4H 5H 6H 9S 9C")
check("straight flush with extras", k == "Straight Flush" and n == 5, k, n)
k, n = ev("13S 13H 13C 12D 12S 2H")
check("full house with an extra", k == "Full House" and n == 5, k, n)
k, n = ev("13S 13H 13C 12D 12S 12H")
check("two trips make a full house", k == "Full House" and n == 5, k, n)
k, n = ev("13S 13H 12C 12D 4S 4H")
check("three pairs make two pair", k == "Two Pair" and n == 4, k, n)
k, n = ev("13S 13H 13C 13D 13S 13H")
check("six of a kind is five of a kind", k == "Five of a Kind" and n == 6, k, n)
k, n = ev("13H 13H 13H 13H 13H 2H")
check("flush five", k == "Flush Five", k, n)
k, n = ev("13H 13H 13H 12H 12H 2S")
check("flush house", k == "Flush House" and n == 5, k, n)
k, n = ev("2H 4H 6H 8H 3S 5C")
check("four fingers flush", select(1, best(S.evaluate(cards("2H 4H 6H 8H 3S 5C"), {four_fingers = true}))) == "Flush")
check("no flush without four fingers", k ~= "Flush", k)
k, n = ev("2S 3H 4C 5D 7S 8H", {shortcut = true})
check("shortcut straight", k == "Straight", k, n)
local r = S.evaluate(cards("13S 13H 13C 13D 2S 3H"))
check("contains three and pair", r["Three of a Kind"][1] ~= nil and r["Pair"][1] ~= nil and r["Four of a Kind"][1] ~= nil)
check("wide only when plain and over 5", S.wide(cards("2H 3H 4H 5H 6H 7H")) and not S.wide(cards("2H 3H 4H 5H 6H")))

local Mods = require("functions/forge/forge_mods")
local Store = require("functions/forge/forge_store")
Store.list = {}
Store.put({id = "bh", name = "Big Hands", rarity = 2, cost = 6, enabled = true, art = {atlas = "Joker", x = 1, y = 1}, rules = {{when = "passive", give = {{id = "p_select", n = 2}}}}})
local raw, out = Mods.pack({name = "Select", author = "Tester", about = {"Cards to select."}}, {"bh"})
check("export is format 16", raw and type(out) == "table" and out.v == 16)
local mod, err = Mods.parse(raw)
local g = mod and mod.jokers and mod.jokers[1] and mod.jokers[1].rules[1].give[1]
check("import keeps p_select", g and g.id == "p_select" and g.n == 2, err)
local full = T.sentence(R.clean_rules({{when = "round_end", give = {{id = "select_plus", n = 1}}}})[1], "en")
check("rule sentence", tostring(full):find("select", 1, true) ~= nil, full)
local kept = R.clean_rules({{when = "passive", give = {{id = "p_select", n = 500}}}})
check("clean clamps", kept[1] and kept[1].give[1] and kept[1].give[1].n == 100, kept[1] and kept[1].give[1] and kept[1].give[1].n)

local H = require("functions/forge/forge_hands")
local rf = {id = "rf", kind = "hand", fields = {count = 7, pattern = "every_suit", beats = "Flush Five"}}
local m = H.match(cards("2S 4H 6C 8D 10S 12H 14C"), rf)
check("rainbow flood matches 7 with every suit", m ~= nil and #m == 7)
check("rainbow flood needs every suit", H.match(cards("2S 4H 6C 8S 10S 12H 14C"), rf) == nil)
check("rainbow flood needs 7 cards", H.match(cards("2S 4H 6C 8D 10S 12H"), rf) == nil)
check("rainbow flood from 9 cards", #(H.match(cards("2S 4H 6C 8D 10S 12H 14C 3S 5S"), rf) or {}) == 7)
check("every suit pattern listed", R.member(Cat.HAND_PATTERNS, "every_suit") and R.member(H.PATTERNS, "every_suit") and H.PATTERN_TEXT.every_suit ~= nil)

reset()
S.change(2)
check("IF select_limit at least 7", R.CHECKS.select_limit({id = "select_limit", op = "at_least", n = 7}))
check("IF select_limit at most 6 fails", not R.CHECKS.select_limit({id = "select_limit", op = "at_most", n = 6}))
check("IF in the list", R.member(R.ONLY, "select_limit") and R.member(Cat.RUN_ONLY, "select_limit") and Cat.OP_ONLY.select_limit)
local ci = R.clean_rules({{when = "hand_played", only = {{id = "select_limit", op = "at_least", n = 6}}, give = {{id = "mult", n = 4}}}})
check("IF survives cleaning", ci[1] and ci[1].only[1] and ci[1].only[1].id == "select_limit" and ci[1].only[1].n == 6 and ci[1].only[1].op == "at_least")
check("IF needs format 16", R.need_v(ci) >= 16)
for _, lang in ipairs({"en", "fr", "es"}) do
  local t = T.sentence(ci[1], lang)
  check("IF text " .. lang, tostring(t):find("6", 1, true) ~= nil and not tostring(t):find("select_limit", 1, true), t)
end
check("count source", R.member(R.COUNTS, "select_limit") and R.count_of({per = "select_limit"}) == 7)
local cp = R.clean_rules({{when = "hand_played", give = {{id = "mult_per", n = 4, per = "select_limit"}}}})
check("count survives cleaning", cp[1] and cp[1].give[1] and cp[1].give[1].per == "select_limit")
check("count needs format 16", R.need_v(cp) >= 16)
local ct = T.sentence(cp[1], "en")
check("count text", tostring(ct):find("card you can select", 1, true) ~= nil, ct)

print(total .. " checks, " .. fails .. " failed")
