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
  localization = {misc = {suits_plural = {}, suits_singular = {}, dictionary = {}}, descriptions = {}},
}
for _, s in ipairs({{"H", "Hearts"}, {"D", "Diamonds"}, {"S", "Spades"}, {"C", "Clubs"}}) do
  for i, r in ipairs({{"2", "2"}, {"3", "3"}, {"4", "4"}, {"5", "5"}, {"6", "6"}, {"7", "7"}, {"8", "8"}, {"9", "9"}, {"T", "10"}, {"J", "Jack"}, {"Q", "Queen"}, {"K", "King"}, {"A", "Ace"}}) do
    G.P_CARDS[s[1] .. "_" .. r[1]] = {name = r[2] .. " of " .. s[2], value = r[2], suit = s[2], pos = {x = i - 1, y = 0}}
  end
end

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local S = require("functions/forge/forge_suits")

check("kind: suit is a Forge kind", Cat.BY_ID.suit ~= nil and Cat.BY_ID.suit.shape == "playing")
local f = Cat.clean_fields("suit", {colour = "GOLD", deck = false, weight = 50})
check("fields: colour kept", f.colour == "GOLD")
check("fields: deck off kept", f.deck == false)
check("fields: weight kept", f.weight == 50)
local bad = Cat.clean_fields("suit", {colour = "NOPE", weight = -5})
check("fields: unknown colour falls back", bad.colour == "PURPLE")
check("fields: deck on by default", bad.deck == true)
check("fields: weight never below 0", bad.weight >= 0)
check("colours: every catalog colour has a hex", (function()
  for _, id in ipairs(Cat.SUIT_COLOURS) do if not S.COLOUR_HEX[id] then return false end end
  return true
end)())

local stars = Store.clean_item({id = "stars1", kind = "suit", name = "Stars", fields = {colour = "GOLD"}, art = {file = "forge/art/stars1.png"}})
check("store: suit item survives cleaning", stars and stars.kind == "suit" and stars.art and stars.art.file == "forge/art/stars1.png")

local items = {
  {id = "zzz", kind = "suit", name = "Moons", enabled = true},
  {id = "stars1", kind = "suit", name = "Stars", enabled = true},
  {id = "off", kind = "suit", name = "Off", enabled = false},
  {id = "joker1", kind = "tarot", name = "T", enabled = true},
}
local list = S.assign(items)
check("assign: only enabled suits", #list == 2)
check("assign: sorted by id", list[1].id == "stars1" and list[2].id == "zzz")
check("assign: codes differ", list[1].code ~= list[2].code)
check("assign: codes are one lowercase letter", list[1].code:match("^%l$") ~= nil and list[2].code:match("^%l$") ~= nil)
check("assign: suit key starts with its code", list[1].key:sub(1, 1) == list[1].code)
local again = S.assign({items[2]})
check("assign: code stable without the other suit", again[1].code == list[1].code)
local many = {}
for i = 1, 9 do many[#many + 1] = {id = "s" .. i, kind = "suit", name = "S" .. i} end
check("assign: at most S.MAX own suits", #S.assign(many) == S.MAX)
local clash = S.assign({{id = "a", kind = "suit"}, {id = "a", kind = "suit"}})
check("assign: same preferred code still gives two codes", #clash == 2 and clash[1].code ~= clash[2].code)

S.set_list(list)
local st = list[1]
local ace = S.p_card(st, 13)
check("card: ace of stars", ace.value == "Ace" and ace.suit == st.key and ace.pos.x == 12 and ace.atlas == S.atlas_key(st))
check("card: key format for the start deck", S.card_key(st, "A"):match("^%l_A$") ~= nil)
check("card: key splits like vanilla", S.card_key(st, "T"):sub(1, 1) == st.code and S.card_key(st, "T"):sub(3, 3) == "T")
check("rank code: 10 is T", S.rank_code("10") == "T" and S.rank_code("Ace") == "A" and S.rank_code("nope") == nil)
check("is_own: stars yes, Spades no", S.is_own(st.key) and not S.is_own("Spades"))
local all = S.all_suits()
check("all suits: 4 vanilla then own", #all == 6 and all[1] == "Spades" and all[5] == st.key)

check("pips: 2 has two", #S.pips("2") == 2)
check("pips: 10 has ten", #S.pips("T") == 10)
check("pips: bottom pips are upside down", S.pips("2")[2].flip and not S.pips("2")[1].flip)
check("pips: middle pip of 5 is upright", not S.pips("5")[5].flip)
for r, n in pairs({["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9}) do
  check("pips: " .. r .. " count", #S.pips(r) == n)
end
check("pips: inside the card", (function()
  for _, r in ipairs({"2", "3", "4", "5", "6", "7", "8", "9", "T"}) do
    for _, p in ipairs(S.pips(r)) do if p.x < 0 or p.y < 0 or p.x + p.w > 71 or p.y + p.h > 95 then return false end end
  end
  return true
end)())

local function card(suit, opts)
  opts = opts or {}
  return {base = {suit = suit}, ability = {effect = opts.stone and "Stone Card" or nil, name = opts.wild and "Wild Card" or ""}, debuff = opts.debuff,
    is_suit = function(self, s, _, flush_calc)
      if self.ability.effect == "Stone Card" then return false end
      if self.ability.name == "Wild Card" and not (flush_calc and self.debuff) then return true end
      return self.base.suit == s
    end}
end
local hand = {card(st.key), card(st.key), card(st.key), card(st.key), card(st.key)}
local t = S.flush_in(hand, 5)
check("flush: five Stars", t and #t == 5)
hand[5] = card("Spades")
check("flush: four Stars and a Spade is not", S.flush_in(hand, 5) == nil)
check("flush: four Stars with Four Fingers is", S.flush_in(hand, 4) ~= nil and #S.flush_in(hand, 4) == 4)
hand[5] = card("Spades", {wild = true})
check("flush: a Wild card counts as Stars", S.flush_in(hand, 5) ~= nil)
hand[5] = card(st.key, {stone = true})
check("flush: a Stone card does not count", S.flush_in(hand, 5) == nil)
check("flush: six cards never", S.flush_in({card(st.key), card(st.key), card(st.key), card(st.key), card(st.key), card(st.key)}, 5) == nil)

local pool = {a = {suit = "Spades"}, b = {suit = "Hearts"}, c = {suit = st.key, forge_suit = st.id}, d = {suit = list[2].key, forge_suit = list[2].id}}
list[1].c.fields = {weight = 0}
list[2].c.fields = {weight = 100}
check("weight: 0% never picked", (function()
  for i = 0, 99 do local v = S.weighted_pick(pool, i / 100) if v == pool.c then return false end end
  return true
end)())
local seen = {}
for i = 0, 98 do local _, k = S.weighted_pick(pool, (i + 0.5) / 99) seen[k] = (seen[k] or 0) + 1 end
check("weight: 100% like a vanilla card", seen.a == seen.b and seen.b == seen.d)
list[2].c.fields = {weight = 200}
seen = {}
for i = 0, 99 do local _, k = S.weighted_pick(pool, (i + 0.5) / 100) seen[k] = (seen[k] or 0) + 1 end
check("weight: 200% twice as often", seen.d == 2 * seen.a)
check("weight: vanilla cards weigh 1", S.weight_of(G.P_CARDS.S_A) == 1)
check("weight: unknown own suit weighs 0", S.weight_of({forge_suit = "gone"}) == 0)

S.set_list({})
local live_before = Store.live_items
Store.live_items = function() return {stars} end
S.register()
local n = 0
for k, v in pairs(G.P_CARDS) do if v.forge_suit == "stars1" then n = n + 1 end end
check("register: 13 Stars cards", n == 13, n)
local skey = S.list[1] and S.list[1].key
check("register: colour set", skey and G.C.SUITS[skey] ~= nil)
check("register: name in the suit names", skey and G.localization.misc.suits_plural[skey] == "Stars")
local held = G.P_CARDS[S.card_key(S.list[1], "A")]
S.register()
check("register: again keeps the same card tables", G.P_CARDS[S.card_key(S.list[1], "A")] == held)
Store.live_items = function() return {} end
S.register()
n = 0
for k, v in pairs(G.P_CARDS) do if v.forge_suit then n = n + 1 end end
check("register: removed suit leaves no cards", n == 0)
check("register: vanilla cards untouched", G.P_CARDS.S_A and G.P_CARDS.H_2 and G.P_CARDS.D_T and G.P_CARDS.C_K)
local R = require("functions/forge/forge_rules")
stars.enabled = true
Store.put_item(stars)
Store.live_items = function() return {stars} end
S.register()
local own = "suit_forge_stars1"
check("own value: id read back", R.own_id("suit", own) == "stars1")
check("own value: resolves to the live suit key", R.suit_key(own) == S.list[1].key)
check("own value: vanilla suits pass through", R.suit_key("Spades") == "Spades")
check("own value: in the suit choices", (function() for _, v in ipairs(Cat.values("suit")) do if v == own then return true end end return false end)())
check("own value: not in the base list", (function() for _, v in ipairs(Cat.values("suit", true)) do if v == own then return false end end return true end)())
check("own value: shown by name", Cat.value_label("suit", own) == "Stars", Cat.value_label("suit", own))
local eff = Cat.clean_effects("tarot", {{id = "suit", v = own}})
check("tarot: turns cards into Stars survives cleaning", eff[1] and eff[1].v == own, eff[1] and eff[1].v)
check("rules: change suit offers Stars", (function() for _, v in ipairs(R.change_values("suit")) do if v == own then return true end end return false end)())
local rules = R.clean_rules({{when = "card_scored", only = {{id = "suit", v = own}}, give = {{id = "mult", n = 4}}}})
check("rules: IF suit Stars survives cleaning", rules[1] and rules[1].only[1].v == own)
check("own value: usable while live", R.usable("suit", own))
Store.live_items = function() return {} end
S.register()
check("own value: gone suit resolves to nothing", R.suit_key(own) == nil and not R.usable("suit", own))
Store.live_items = live_before

local Mods = require("functions/forge/forge_mods")
local Room = require("functions/forge/forge_room")
local json = require("bot.sim.json")
local function png(w, h, tag)
  local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
  return "\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(w) .. u32(h) .. "\8\6\0\0\0" .. tag .. string.rep("\0\255\1", 30)
end
check("share: 11x10 symbol accepted", Mods.art_size_ok(11, 10) and Mods.art_size_ok(71, 95) and not Mods.art_size_ok(12, 10))
Store.list, Store.items_list = {}, {}
files["forge/art/shst.png"] = png(11, 10, "S")
Store.put_item({id = "shst", kind = "suit", name = "Stars", fields = {colour = "GOLD"}, art = {file = "forge/art/shst.png"}})
Store.put_item({id = "shtar", kind = "tarot", name = "Starfall", fields = {select = 3}, effects = {{id = "suit", v = "suit_forge_shst"}}})
check("share: suit needs format 16", Mods.needs_v({}, {Store.get_item("shst")}) == 16)
check("share: tarot into an own suit needs 16", Mods.needs_v({}, {Store.get_item("shtar")}) == 16)
check("share: rule on an own suit needs 16", R.need_v(R.clean_rules({{when = "card_scored", only = {{id = "suit", v = "suit_forge_shst"}}, give = {{id = "mult", n = 4}}}})) >= 16)
check("share: vanilla tarot stays old", Mods.needs_v({}, {Store.clean_item({id = "van", kind = "tarot", effects = {{id = "suit", v = "Hearts"}}})}) < 16)
local raw, out = Mods.pack({name = "Star Pack"}, {"shst", "shtar"})
check("mods: pack ok at 16", type(raw) == "string" and out.v == 16, out)
check("mods: symbol packed", out and out.files and out.files.shst ~= nil)
local mod = raw and Mods.parse(raw)
local msuit, mtar
for _, c in ipairs(mod and mod.creations or {}) do
  if c.kind == "suit" then msuit = c end
  if c.kind == "tarot" then mtar = c end
end
check("mods: suit arrives with its symbol", msuit and msuit.art and msuit.art.file == Mods.art_path(mod.id, "shst"), msuit and msuit.art and msuit.art.file)
check("mods: tarot points at the shared suit", msuit and mtar and mtar.effects[1].v == "suit_forge_" .. msuit.id, mtar and mtar.effects[1].v)
local rraw, rinfo = Room.pack()
check("room: pack ok with the symbol", rraw and rinfo and rinfo.art >= 1, rinfo and rinfo.art)
check("room: enter", rraw and Room.enter(rraw) == true)
local rsuit, rtar
for _, c in ipairs(Store.live_items()) do
  if c.kind == "suit" then rsuit = c end
  if c.kind == "tarot" then rtar = c end
end
check("room: suit arrives with its symbol", rsuit and rsuit.art and rsuit.art.file and files[rsuit.art.file] == files["forge/art/shst.png"], rsuit and rsuit.art and rsuit.art.file)
check("room: tarot points at the room suit", rsuit and rtar and rtar.effects[1].v == "suit_forge_" .. rsuit.id, rtar and rtar.effects[1].v)
Room.leave()

print(string.format("forge suits: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
