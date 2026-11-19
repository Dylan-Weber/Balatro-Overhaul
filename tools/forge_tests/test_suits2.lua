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
  P_CARDS = {},
  P_CENTERS = {c_base = {key = "c_base"}},
  P_CENTER_POOLS = {},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}},
  SETTINGS = {language = "en-us"},
  GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, dictionary = {}}, descriptions = {Other = {}}},
}

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local S = require("functions/forge/forge_suits")
local X = require("functions/forge/forge_suitrules")
local D = require("functions/forge/forge_doc")

check("host: suits get card rules", R.host_of("suit") == "card")
check("whens: scored, held, discarded, round end", R.when_ok and true or #R.whens("suit") == 4)
local whens = R.whens("suit")
check("whens: card list", #whens == 4 and whens[1] == "card_scored", #whens)

local f = Cat.clean_fields("suit", {chips = 30, mult = 5, as1 = "Hearts", as2 = "suit_forge_moons", xmult = 1.5, money = 2, held_xmult = 1.25, held_money = 1, low = "Jack", high = "King", copies = 2, never_debuff = true, boss = "bl_head"})
check("fields: chips", f.chips == 30)
check("fields: mult", f.mult == 5)
check("fields: counts as Hearts", f.as1 == "Hearts")
check("fields: counts as an own suit", f.as2 == "suit_forge_moons")
check("fields: xmult", f.xmult == 1.5)
check("fields: money", f.money == 2)
check("fields: held xmult", f.held_xmult == 1.25)
check("fields: held money", f.held_money == 1)
check("fields: rank range", f.low == "Jack" and f.high == "King")
check("fields: copies", f.copies == 2)
check("fields: never debuffed", f.never_debuff == true)
check("fields: boss", f.boss == "bl_head")
local bad = Cat.clean_fields("suit", {chips = 9999, as1 = "Nope", low = "Eleven", copies = 1500, boss = "bl_wall"})
check("fields: chips have no small cap", bad.chips == 9999)
check("fields: unknown suit falls back", bad.as1 == "none")
check("fields: unknown rank falls back", bad.low == "2")
check("fields: copies capped at 1000", bad.copies == 1000)
check("fields: 50 copies kept", Cat.clean_fields("suit", {copies = 50}).copies == 50)
check("fields: unknown boss falls back", bad.boss == "none")
local def = Cat.clean_fields("suit", {})
check("fields: defaults are a plain suit", def.chips == 0 and def.mult == 0 and def.as1 == "none" and def.low == "2" and def.high == "Ace" and def.copies == 1 and def.never_debuff == false and def.boss == "none")

local royal = {fields = {low = "Jack", high = "King"}}
check("ranks: royal has J Q K", table.concat(X.ranks_in(royal), ",") == "Jack,Queen,King")
check("ranks: royal refuses 10", not X.rank_ok(royal, "10"))
check("ranks: royal refuses Ace", not X.rank_ok(royal, "Ace"))
check("ranks: swapped range still works", #X.ranks_in({fields = {low = "5", high = "2"}}) == 4)
check("ranks: full range takes all 13", #X.ranks_in({fields = {}}) == 13)

local items = {
  {id = "stars", kind = "suit", name = "Stars", enabled = true, fields = {as1 = "Hearts", as2 = "Spades", mult = 5, chips = 10, xmult = 2, money = 1, held_xmult = 1.5, held_money = 1, never_debuff = true, boss = "bl_club"},
    rules = {{when = "card_scored", only = {}, give = {{id = "mult", n = 5}}}}},
  {id = "moons", kind = "suit", name = "Moons", enabled = true, fields = {low = "Jack", high = "King", copies = 2, boss = "any_boss"},
    rules = {{when = "round_end", only = {}, give = {{id = "money", n = 1}}}}},
}
for _, c in ipairs(items) do Store.put_item(c) end
local list = S.assign(Store.live_items())
S.set_list(list)
local stars, moons = S.of_id("stars"), S.of_id("moons")
check("list: both suits live", stars and moons)

local saved = Store.get_item("stars")
check("store: suit keeps its rules", saved and saved.rules and #saved.rules == 1 and saved.rules[1].give[1].id == "mult")
check("store: suit keeps new fields", saved and saved.fields.as1 == "Hearts" and saved.fields.never_debuff == true)
check("share: suit with rules is format 16", Cat.need_v(saved) == 16, Cat.need_v(saved))

local function card(suit, opts)
  opts = opts or {}
  return {base = {suit = suit}, ability = {effect = opts.stone and "Stone Card" or nil, name = ""}, debuff = opts.debuff}
end
check("counts as: Stars count as Hearts", X.counts_as(card(stars.key), "Hearts"))
check("counts as: Stars count as Spades", X.counts_as(card(stars.key), "Spades"))
check("counts as: Stars are not Clubs", not X.counts_as(card(stars.key), "Clubs"))
check("counts as: Moons count as nothing else", not X.counts_as(card(moons.key), "Hearts"))
check("counts as: a Stone Star is no suit", not X.counts_as(card(stars.key, {stone = true}), "Hearts"))
check("counts as: debuffed Star fails outside flushes", not X.counts_as(card(stars.key, {debuff = true}), "Hearts"))
check("counts as: debuffed Star still helps a Flush", X.counts_as(card(stars.key, {debuff = true}), "Hearts", nil, true))
check("counts as: vanilla cards untouched", not X.counts_as(card("Hearts"), "Spades"))

check("bonus: chips", X.bonus(card(stars.key), "chips") == 10)
check("bonus: mult", X.bonus(card(stars.key), "mult") == 5)
check("bonus: xmult", X.bonus(card(stars.key), "xmult") == 2)
check("bonus: money", X.bonus(card(stars.key), "money") == 1)
check("bonus: held xmult", X.bonus(card(stars.key), "held_xmult") == 1.5)
check("bonus: held money", X.bonus(card(stars.key), "held_money") == 1)
check("bonus: none for Moons", X.bonus(card(moons.key), "chips") == nil)
check("bonus: none when debuffed", X.bonus(card(stars.key, {debuff = true}), "mult") == nil)
check("bonus: none on Stone", X.bonus(card(stars.key, {stone = true}), "mult") == nil)

local club = {config = {blind = {key = "bl_club"}}, boss = true}
local wall = {config = {blind = {key = "bl_wall"}}, boss = true}
local small = {config = {blind = {key = "bl_small"}}}
check("boss: The Club hits Stars", X.boss_hits(club, card(stars.key)))
check("boss: The Wall does not hit Stars", not X.boss_hits(wall, card(stars.key)))
check("boss: every Boss hits Moons", X.boss_hits(wall, card(moons.key)))
check("boss: Small Blind never hits Moons", not X.boss_hits(small, card(moons.key)))
check("boss: disabled Boss hits nothing", not X.boss_hits({config = {blind = {key = "bl_club"}}, boss = true, disabled = true}, card(stars.key)))
check("never: Stars can never be debuffed", X.never(card(stars.key)))
check("never: Moons can", not X.never(card(moons.key)))

local own = "suit_forge_stars"
local m = R.matches()
local found = false
for _, v in ipairs(m) do if v == own then found = true end end
check("counts: own suit offered as a card filter", found)
check("counts: own suit label", R.match_label(own, "en") == "Stars" and R.one_label(own, "en"):find("Stars", 1, true) ~= nil, R.one_label(own, "en"))
local per = R.clean_rules({{when = "hand_played", only = {}, give = {{id = "mult_per", n = 4, per = "deck_match", m = own}}}})
check("counts: for each Stars card in the deck survives cleaning", per[1] and per[1].give[1].m == own, per[1] and per[1].give[1].m)
local dc = R.clean_rules({{when = "hand_played", only = {{id = "deck_count", v = own, op = "at_least", n = 5}}, give = {{id = "mult", n = 4}}}})
check("ifs: deck count of Stars survives", dc[1] and dc[1].only[1] and dc[1].only[1].v == own)
local ps = R.clean_rules({{when = "hand_played", only = {{id = "played_suit", v = own}}, give = {{id = "mult", n = 4}}}})
check("ifs: played suit Stars survives", ps[1] and ps[1].only[1] and ps[1].only[1].v == own)
local ha = R.clean_rules({{when = "hand_played", only = {{id = "held_all", v = own}}, give = {{id = "mult", n = 4}}}})
check("ifs: every held card is Stars survives", ha[1] and ha[1].only[1] and ha[1].only[1].v == own)

local srules = R.clean_rules(saved.rules, "suit")
check("rules: card WHEN kept for suits", srules[1] and srules[1].when == "card_scored")

local lines = D.lines(saved, "en")
local text = table.concat(lines, "|")
check("text: counts as line", text:find("Also counts as", 1, true) ~= nil, text)
check("text: chips line", text:find("Chips when scored", 1, true) ~= nil)
check("text: never debuffed line", text:find("Can never be debuffed", 1, true) ~= nil)
check("text: rule line", #lines >= 6, #lines)
local mtext = table.concat(D.lines(Store.get_item("moons"), "en"), "|")
check("text: Moons count 6 cards", mtext:find("{C:attention}6{} cards", 1, true) ~= nil, mtext)
check("text: Moons two of each", mtext:find("{C:attention}2{} of each rank", 1, true) ~= nil)
local cl = X.card_lines(saved, "en")
check("card text: no deck lines on the card", table.concat(cl, "|"):find("starting deck", 1, true) == nil and #cl > 0)

local Ch = require("functions/forge/forge_challenges")
local ch = Ch.build(Store.clean_item({id = "nostar", kind = "challenge", name = "No Stars", effects = {{id = "ch_no_suit", v = own}}}))
check("challenge: Remove a suit takes an own suit", ch.deck.forge_no_suits and ch.deck.forge_no_suits[1] == own)
local opts = Cat.values("suit", (Cat.effect("challenge", "ch_no_suit") or {}).base)
local has = false
for _, v in ipairs(opts) do if v == own then has = true end end
check("challenge: Remove a suit offers own suits", has)

local Mods = require("functions/forge/forge_mods")
local raw, out = Mods.pack({name = "Star Pack"}, {"stars", "moons"})
check("mods: pack at 16", type(raw) == "string" and out.v == 16, out and out.v)
local mod = raw and Mods.parse(raw)
local ms
for _, c in ipairs(mod and mod.creations or {}) do if c.kind == "suit" and c.name == "Stars" then ms = c end end
check("mods: suit arrives with rules and fields", ms and ms.rules and #ms.rules == 1 and ms.fields.as1 == "Hearts" and ms.fields.boss == "bl_club")

print(string.format("forge suits2: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
