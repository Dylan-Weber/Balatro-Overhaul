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
local D = require("functions/forge/forge_doc")
local function card(suit, id, opts)
  opts = opts or {}
  return {base = {suit = suit, id = id}, ability = {effect = opts.stone and "Stone Card" or nil, name = opts.wild and "Wild Card" or ""},
    get_id = function(self) return self.base.id end,
    is_face = function(self) return self.base.id >= 11 and self.base.id <= 13 end,
    is_suit = function(self, s) if self.ability.effect == "Stone Card" then return false end if self.ability.name == "Wild Card" then return true end return self.base.suit == s end}
end
local function hand(id, fields, rules) return {id = id, kind = "hand", name = id, enabled = true, fields = fields, rules = rules} end

local f = Cat.clean_fields("hand", {pattern = "kinds", count = 4, group2 = 2, low = "10", high = "Ace", sum = 50, also = "every_suit", contains = "Straight", auto_level = 3})
check("fields: kinds pattern", f.pattern == "kinds")
check("fields: second group", f.group2 == 2)
check("fields: rank range", f.low == "10" and f.high == "Ace")
check("fields: rank sum", f.sum == 50)
check("fields: and also", f.also == "every_suit")
check("fields: must contain", f.contains == "Straight")
check("fields: auto level", f.auto_level == 3)
local bad = Cat.clean_fields("hand", {also = "kinds", contains = "Royal", low = "Eleven"})
check("fields: group patterns are not a second condition", bad.also == "none")
check("fields: unknown hand falls back", bad.contains == "none")
check("fields: unknown rank falls back", bad.low == "2")
check("labels: new patterns", Cat.value_label("pattern", "kinds") == "Two rank groups" and Cat.value_label("pattern", "any") == "Any cards")

local mansion = hand("mansion", {pattern = "kinds", count = 4, group2 = 2, beats = "Five of a Kind"})
local m = H.match({card("Spades", 9), card("Hearts", 9), card("Clubs", 9), card("Diamonds", 9), card("Spades", 4), card("Hearts", 4)}, mansion)
check("Full Mansion: four 9s and two 4s", m ~= nil and #m == 6)
check("Full Mansion: picks out of 8 cards", H.match({card("Spades", 2), card("Spades", 9), card("Hearts", 9), card("Clubs", 9), card("Diamonds", 9), card("Spades", 4), card("Hearts", 4), card("Hearts", 13)}, mansion) ~= nil)
check("Full Mansion: four of a kind alone is not", H.match({card("Spades", 9), card("Hearts", 9), card("Clubs", 9), card("Diamonds", 9), card("Spades", 4), card("Hearts", 5)}, mansion) == nil)
check("Full Mansion: six of a kind is not two groups", H.match({card("Spades", 9), card("Hearts", 9), card("Clubs", 9), card("Diamonds", 9), card("Spades", 9), card("Hearts", 9)}, mansion) == nil)
check("Full Mansion: Stone cards do not count", H.match({card("Spades", 9), card("Hearts", 9), card("Clubs", 9), card("Diamonds", 9, {stone = true}), card("Spades", 4), card("Hearts", 4)}, mansion) == nil)
local tr = hand("tr", {pattern = "kinds", count = 3, group2 = 0})
check("kinds: second group 0 is N of a kind", H.match({card("Spades", 7), card("Hearts", 7), card("Clubs", 7)}, tr) ~= nil)

local twin = hand("twin", {pattern = "suit_groups", count = 3, group2 = 3})
check("Twin Flush: 3 Hearts and 3 Spades", H.match({card("Hearts", 2), card("Hearts", 5), card("Hearts", 9), card("Spades", 3), card("Spades", 8), card("Spades", 12)}, twin) ~= nil)
check("Twin Flush: 4 Hearts and 2 Spades is not", H.match({card("Hearts", 2), card("Hearts", 5), card("Hearts", 9), card("Hearts", 3), card("Spades", 8), card("Spades", 12)}, twin) == nil)
check("Twin Flush: a Wild fills a group", H.match({card("Hearts", 2), card("Hearts", 5), card("Hearts", 9), card("Spades", 3), card("Spades", 8), card("Clubs", 12, {wild = true})}, twin) ~= nil)

local royal = hand("royal", {pattern = "in_a_row", count = 5, low = "10", high = "Ace", also = "every_suit"})
check("Royal Rainbow: 10 to Ace with every suit", H.match({card("Spades", 10), card("Hearts", 11), card("Clubs", 12), card("Diamonds", 13), card("Spades", 14)}, royal) ~= nil)
check("Royal Rainbow: same suit is not", H.match({card("Spades", 10), card("Spades", 11), card("Spades", 12), card("Spades", 13), card("Spades", 14)}, royal) == nil)
check("Royal Rainbow: 9 to King is not", H.match({card("Spades", 9), card("Hearts", 10), card("Clubs", 11), card("Diamonds", 12), card("Spades", 13)}, royal) == nil)

local big = hand("big", {pattern = "any", count = 6, sum = 50})
check("Big Sum: 6 cards adding to 50", H.match({card("Spades", 14), card("Hearts", 13), card("Clubs", 2), card("Diamonds", 3), card("Spades", 10), card("Hearts", 8)}, big) ~= nil)
check("Big Sum: 6 low cards is not", H.match({card("Spades", 2), card("Hearts", 3), card("Clubs", 4), card("Diamonds", 5), card("Spades", 6), card("Hearts", 7)}, big) == nil)
check("Big Sum: rank sum", H.rank_sum({card("Spades", 14), card("Hearts", 11)}) == 25)
check("Big Sum: fewer than 6 cards is not", H.match({card("Spades", 14), card("Hearts", 13), card("Clubs", 12), card("Diamonds", 11), card("Spades", 10)}, big) == nil)

local faces = hand("faces", {pattern = "same_suit", count = 3, low = "Jack", high = "King"})
check("only ranks: three face Hearts", H.match({card("Hearts", 11), card("Hearts", 12), card("Hearts", 13)}, faces) ~= nil)
check("only ranks: an Ace breaks it", H.match({card("Hearts", 11), card("Hearts", 12), card("Hearts", 14)}, faces) == nil)

evaluate_poker_hand = function(cards)
  local n = {}
  for _, c in ipairs(cards) do n[c.base.id] = (n[c.base.id] or 0) + 1 end
  local pair = false
  for _, v in pairs(n) do if v >= 2 then pair = true end end
  return {Pair = pair and {cards} or {}}
end
local cp = hand("cp", {pattern = "same_suit", count = 4, contains = "Pair"})
check("must contain: four Hearts with a Pair", H.match({card("Hearts", 5), card("Hearts", 5), card("Hearts", 9), card("Hearts", 2)}, cp) ~= nil)
check("must contain: four Hearts without a Pair", H.match({card("Hearts", 5), card("Hearts", 6), card("Hearts", 9), card("Hearts", 2)}, cp) == nil)

local ex = H.example(mansion)
check("example: Full Mansion shows 6 cards", #ex == 6, #ex)
check("example: four of one rank", ex[1][1]:sub(3) == ex[4][1]:sub(3) and ex[5][1]:sub(3) ~= ex[1][1]:sub(3), ex[1][1] .. ex[5][1])
local rex = H.example(royal)
check("example: Royal Rainbow starts at Ace", rex[1][1]:sub(3) == "A" and rex[5][1]:sub(3) == "T", rex[1][1] .. " " .. rex[5][1])
local text = table.concat(D.lines(Store.clean_item(royal), "en"), "|")
check("text: rank range line", text:find("Only ranks", 1, true) ~= nil, text)
check("text: and also line", text:find("And also", 1, true) ~= nil)
check("text: mansion line", table.concat(D.lines(Store.clean_item(mansion), "en"), "|"):find("4 of a kind plus 2 of a kind", 1, true) ~= nil)
check("text: big sum line", table.concat(D.lines(Store.clean_item(big), "en"), "|"):find("add up to {C:attention}50{}", 1, true) ~= nil)

check("rules: poker hands host run rules", R.host_of("hand") == "run")
local whens = R.whens("hand")
check("rules: played and scored WHENs", #whens == 2 and whens[1] == "hand_played" and whens[2] == "card_scored")
local lucky = Store.clean_item(hand("lucky", {pattern = "same_rank", count = 2}, {{when = "hand_played", only = {}, give = {{id = "money", n = 2}}}}))
check("rules: kept by the store", lucky.rules and lucky.rules[1] and lucky.rules[1].give[1].id == "money")
check("share: format 16", Cat.need_v(lucky) == 16)
local Mods = require("functions/forge/forge_mods")
Store.put_item(lucky)
Store.put_item(Store.clean_item(mansion))
local raw, out = Mods.pack({name = "Hands"}, {"lucky", "mansion"})
check("mods: pack at 16", type(raw) == "string" and out.v == 16, out and out.v)
local mod = raw and Mods.parse(raw)
local ml, mm
for _, c in ipairs(mod and mod.creations or {}) do if c.name == "lucky" then ml = c end if c.name == "mansion" then mm = c end end
check("mods: rules arrive", ml and ml.rules and ml.rules[1].give[1].id == "money")
check("mods: new fields arrive", mm and mm.fields.pattern == "kinds" and mm.fields.group2 == 2)

print(string.format("forge hands2: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
