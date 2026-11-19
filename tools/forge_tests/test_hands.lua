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
G.handlist = {"Flush Five", "Flush House", "Five of a Kind", "Straight Flush", "Four of a Kind", "Full House", "Flush", "Straight", "Three of a Kind", "Two Pair", "Pair", "High Card"}

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local H = require("functions/forge/forge_hands")

local function card(suit, id, opts)
  opts = opts or {}
  return {base = {suit = suit, id = id}, ability = {effect = opts.stone and "Stone Card" or nil, name = opts.wild and "Wild Card" or ""},
    get_id = function(self) return self.base.id end,
    is_face = function(self) return self.base.id >= 11 and self.base.id <= 13 end,
    is_suit = function(self, s) if self.ability.effect == "Stone Card" then return false end if self.ability.name == "Wild Card" then return true end return self.base.suit == s end}
end
local function hand_of(p, n) return {id = "h" .. p, kind = "hand", name = p, enabled = true, fields = {pattern = p, count = n or 4}} end

check("kind: poker hand is a Forge kind", Cat.BY_ID.hand ~= nil)
local f = Cat.clean_fields("hand", {pattern = "same_rank", count = 3, beats = "Straight", chips = 50, mult = 5, l_chips = 25, l_mult = 3, hidden = true})
check("fields: kept", f.pattern == "same_rank" and f.count == 3 and f.beats == "Straight" and f.chips == 50 and f.mult == 5 and f.l_chips == 25 and f.l_mult == 3 and f.hidden == true)
local bad = Cat.clean_fields("hand", {pattern = "nope", count = 9, beats = "Royal"})
check("fields: bad pattern falls back", bad.pattern == "each_suit")
check("fields: count above 5 is kept", bad.count == 9, bad.count)
check("fields: bad beats falls back", bad.beats == "Flush")
check("labels: pattern has a name", Cat.value_label("pattern", "each_suit") == "Different suits", Cat.value_label("pattern", "each_suit"))

local rainbow = {id = "rainbow", kind = "hand", name = "Rainbow", enabled = true, fields = {pattern = "each_suit", count = 4, beats = "Flush"}}
check("rainbow: 4 suits", H.match({card("Spades", 2), card("Hearts", 9), card("Clubs", 5), card("Diamonds", 13)}, rainbow) ~= nil)
check("rainbow: 3 suits is not", H.match({card("Spades", 2), card("Hearts", 9), card("Clubs", 5), card("Clubs", 13)}, rainbow) == nil)
check("rainbow: a fifth card does not matter", H.match({card("Spades", 2), card("Hearts", 9), card("Clubs", 5), card("Diamonds", 13), card("Diamonds", 3)}, rainbow) ~= nil)
check("rainbow: scoring cards are the 4", #H.match({card("Spades", 2), card("Hearts", 9), card("Clubs", 5), card("Diamonds", 13), card("Diamonds", 3)}, rainbow) == 4)
check("rainbow: a Wild fills a missing suit", H.match({card("Spades", 2), card("Hearts", 9), card("Clubs", 5), card("Clubs", 13, {wild = true})}, rainbow) ~= nil)
check("rainbow: a Stone card is no suit", H.match({card("Spades", 2), card("Hearts", 9), card("Clubs", 5), card("Diamonds", 13, {stone = true})}, rainbow) == nil)
check("rainbow: too few cards", H.match({card("Spades", 2), card("Hearts", 9)}, rainbow) == nil)
check("same suit", H.match({card("Hearts", 2), card("Hearts", 9), card("Hearts", 5), card("Hearts", 13)}, hand_of("same_suit")) ~= nil)
check("same suit: mixed is not", H.match({card("Hearts", 2), card("Spades", 9), card("Hearts", 5), card("Hearts", 13)}, hand_of("same_suit")) == nil)
check("same rank: 3 Queens", H.match({card("Hearts", 12), card("Spades", 12), card("Clubs", 12), card("Hearts", 2)}, hand_of("same_rank", 3)) ~= nil)
check("different ranks", H.match({card("Hearts", 2), card("Hearts", 3), card("Hearts", 9), card("Hearts", 13)}, hand_of("diff_rank")) ~= nil)
check("different ranks: a pair is not", H.match({card("Hearts", 2), card("Hearts", 2), card("Hearts", 9), card("Hearts", 13)}, hand_of("diff_rank")) == nil)
check("in a row", H.match({card("Hearts", 5), card("Spades", 6), card("Clubs", 7), card("Hearts", 8)}, hand_of("in_a_row")) ~= nil)
check("in a row: Ace low", H.match({card("Hearts", 14), card("Spades", 2), card("Clubs", 3)}, hand_of("in_a_row", 3)) ~= nil)
check("in a row: gap is not", H.match({card("Hearts", 5), card("Spades", 6), card("Clubs", 8), card("Hearts", 9)}, hand_of("in_a_row")) == nil)
check("faces", H.match({card("Hearts", 11), card("Spades", 12), card("Clubs", 13)}, hand_of("all_face", 3)) ~= nil)
check("faces: an Ace is not", H.match({card("Hearts", 11), card("Spades", 12), card("Clubs", 14)}, hand_of("all_face", 3)) == nil)
local seven = {}
for i = 1, 7 do seven[i] = card(({"Hearts", "Spades", "Clubs", "Diamonds"})[(i - 1) % 4 + 1], 9) end
seven[8] = card("Hearts", 2)
check("big hand: 7 of a kind in 8 cards", H.match(seven, hand_of("same_rank", 7)) ~= nil and #H.match(seven, hand_of("same_rank", 7)) == 7)
check("big hand: 8 of a kind is not", H.match(seven, hand_of("same_rank", 8)) == nil)
local run6 = {card("Hearts", 14), card("Spades", 2), card("Clubs", 3), card("Hearts", 4), card("Spades", 5), card("Clubs", 6), card("Clubs", 6)}
check("big hand: 6 in a row from Ace low", H.match(run6, hand_of("in_a_row", 6)) ~= nil and #H.match(run6, hand_of("in_a_row", 6)) == 6)
check("big hand: 7 in a row is not", H.match(run6, hand_of("in_a_row", 7)) == nil)
local broad = {}
for i = 2, 14 do broad[#broad + 1] = card("Spades", i) end
check("big hand: 13 in a row", H.match(broad, hand_of("in_a_row", 13)) ~= nil)
check("big hand: 14 in a row never", H.match(broad, hand_of("in_a_row", 14)) == nil)
local many = {}
for i = 1, 40 do many[i] = card(i % 2 == 0 and "Hearts" or "Spades", (i % 13) + 2) end
local t0 = os.clock()
local m20 = H.match(many, hand_of("same_suit", 20))
check("big hand: 20 Hearts out of 40 cards", m20 ~= nil and #m20 == 20)
check("big hand: 21 Hearts out of 40 is not", H.match(many, hand_of("same_suit", 21)) == nil)
check("big hand: 6 different suits never with 4 suits", H.match(many, hand_of("each_suit", 6)) == nil)
check("big hand: 10 different ranks", H.match(many, hand_of("diff_rank", 10)) ~= nil)
check("big hand: fast", os.clock() - t0 < 0.5, os.clock() - t0)
local big_f = Cat.clean_fields("hand", {pattern = "same_rank", count = 1000})
check("big hand: count 1000 kept", big_f.count == 1000, big_f.count)
check("big hand: count above max is clamped", Cat.clean_fields("hand", {pattern = "same_rank", count = 5000}).count == 1000)
local ex9 = H.example(hand_of("same_suit", 9))
check("big hand: example has 9 cards", #ex9 == 9)
local ex_ok = true
for _, e in ipairs(H.example(hand_of("in_a_row", 40))) do if not e[1]:match("^[SHCD]_[AKQJT2-9]$") then ex_ok = false end end
check("big hand: long examples use real cards", ex_ok and #H.example(hand_of("in_a_row", 40)) == H.EXAMPLE_MAX)
check("even", H.match({card("Hearts", 2), card("Spades", 4), card("Clubs", 10)}, hand_of("all_even", 3)) ~= nil)
check("odd with an Ace", H.match({card("Hearts", 3), card("Spades", 9), card("Clubs", 14)}, hand_of("all_odd", 3)) ~= nil)
check("odd: a face is not", H.match({card("Hearts", 3), card("Spades", 9), card("Clubs", 13)}, hand_of("all_odd", 3)) == nil)

H.set_list({rainbow})
local order = H.order_list()
check("order: Rainbow sits right above Flush", order[7] == "hand_forge_rainbow" and order[8] == "Flush", order[7])
check("order: 13 hands", #order == 13)
local ph = {["hand_forge_rainbow"] = {{1}}, Flush = {{1}}, Pair = {{1}}}
G.handlist = order
check("best: Rainbow beats a Pair", H.best(ph, "Pair") == "hand_forge_rainbow")
check("best: Rainbow does not beat a Full House", H.best(ph, "Full House") == nil)
check("best: nothing when Rainbow is not there", H.best({Pair = {{1}}}, "Pair") == nil)

local entry = H.game_entry(rainbow)
check("game hand: level table", entry.chips == 40 and entry.mult == 4 and entry.l_chips == 20 and entry.l_mult == 2 and entry.level == 1 and entry.visible == true)
check("game hand: 4 example cards", #entry.example == 4 and entry.example[1][1] == "S_A")
G.GAME.hands = {Flush = {level = 3}}
H.ensure_game_hands()
check("game hand: added to the run", G.GAME.hands["hand_forge_rainbow"] ~= nil)
G.GAME.hands["hand_forge_rainbow"].level = 4
H.ensure_game_hands()
check("game hand: levels kept", G.GAME.hands["hand_forge_rainbow"].level == 4)

Store.list, Store.items_list = {}, {}
Store.put_item(rainbow)
Store.put_item({id = "prism", kind = "planet", name = "Prism", fields = {hand = "hand_forge_rainbow", levels = 1}})
local live_before = Store.live_items
Store.live_items = function() return Store.items() end
H.register()
check("register: Rainbow is live", H.is_own("hand_forge_rainbow"))
check("register: name for the game", G.localization.misc.poker_hands["hand_forge_rainbow"] == "Rainbow")
check("register: handlist has it above Flush", H.rank_of("hand_forge_rainbow") == H.rank_of("Flush") - 1)
local planet = Store.get_item("prism")
check("planet: own hand kept", planet and planet.fields.hand == "hand_forge_rainbow", planet and planet.fields.hand)
check("planet: own hand offered", (function() for _, v in ipairs(Cat.field_values(Cat.BY_ID.planet.fields[1])) do if v == "hand_forge_rainbow" then return true end end return false end)())
check("planet: label", Cat.value_label("hand", "hand_forge_rainbow") == "Rainbow")
check("rules: IF hand offers Rainbow", (function() for _, v in ipairs(Cat.values("hand")) do if v == "hand_forge_rainbow" then return true end end return false end)())

local Mods = require("functions/forge/forge_mods")
check("share: hand needs 16", Mods.needs_v({}, {Store.get_item("rainbow")}) == 16)
check("share: planet of an own hand needs 16", Mods.needs_v({}, {planet}) == 16)
check("share: rule on an own hand needs 16", R.need_v(R.clean_rules({{when = "hand_played", only = {{id = "hand", v = "hand_forge_rainbow"}}, give = {{id = "mult", n = 4}}}})) >= 16)
local raw, out = Mods.pack({name = "Rainbow Pack"}, {"rainbow", "prism"})
local mod = raw and Mods.parse(raw)
local mh, mp
for _, c in ipairs(mod and mod.creations or {}) do
  if c.kind == "hand" then mh = c end
  if c.kind == "planet" then mp = c end
end
check("mods: Rainbow and Prism travel together", mh and mp and mp.fields.hand == "hand_forge_" .. mh.id, mp and mp.fields.hand)

Store.live_items = function() return {} end
H.register()
check("register: removed hand leaves the list", H.rank_of("hand_forge_rainbow") > 100 and #G.handlist == 12)
Store.live_items = live_before

print(string.format("forge hands: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
