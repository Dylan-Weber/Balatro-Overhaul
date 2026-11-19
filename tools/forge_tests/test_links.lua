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
Event = function(t) return t end

G = {P_JOKER_RARITY_POOLS = {{}, {}, {}, {}},
  P_CARDS = {}, P_CENTERS = {c_base = {key = "c_base"}}, P_CENTER_POOLS = {},
  P_BLINDS = {bl_small = {key = "bl_small", order = 1}, bl_big = {key = "bl_big", order = 2}, bl_wall = {key = "bl_wall", boss = {min = 2}, order = 3}, bl_hook = {key = "bl_hook", boss = {min = 1}, order = 4}},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}, FILTER = {1, 1, 1, 1}}, SETTINGS = {language = "en-us"}, GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, poker_hands = {}, poker_hand_descriptions = {}, dictionary = {}}, descriptions = {}},
}
G.C.SET, G.C.SECONDARY_SET, G.C.UI = {}, {}, {TEXT_LIGHT = {1, 1, 1, 1}}
number_format = function(v) return tostring(v) end

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
require("functions/forge/forge_grow")
require("functions/forge/forge_power3")

local OWN = {
  {kind = "suit", what = "suit", fields = {colour = "GREEN"}},
  {kind = "hand", what = "hand", fields = {pattern = "same_suit"}},
  {kind = "ctype", what = "ctype", fields = {colour = "GOLD"}},
  {kind = "rarity", what = "rarity", fields = {colour = "PINK"}},
  {kind = "sticker", what = "sticker", fields = {look = "Gold"}},
  {kind = "blind", what = "boss", fields = {}},
  {kind = "stake", what = "stake", fields = {}},
  {kind = "enhancement", what = "enhancement", fields = {}},
  {kind = "seal", what = "seal", fields = {}},
  {kind = "edition", what = "edition", fields = {}},
  {kind = "tag", what = "tag", fields = {}},
  {kind = "voucher", what = "voucher", fields = {}},
  {kind = "booster", what = "pack", fields = {}},
  {kind = "deck", what = "deck", fields = {}},
  {kind = "challenge", what = "challenge", fields = {}},
}
local own_of = {}
for _, o in ipairs(OWN) do
  local id = "lk" .. o.kind
  Store.put_item({id = id, kind = o.kind, name = "Mine " .. o.kind, mode = "advanced", fields = o.fields, effects = {}, rules = {}, art = {}})
  own_of[o.what] = R.OWN_PREFIX[o.what] .. id
end
Store.live_items = function() return Store.items() end

for _, o in ipairs(OWN) do
  local v = own_of[o.what]
  check("own " .. o.kind .. " is listed", R.own_values(o.what)[1] == v, R.own_values(o.what)[1])
  check("own " .. o.kind .. " has its name", R.own_label(o.what, v) == "Mine " .. o.kind, R.own_label(o.what, v))
end

local NO_OWN = {
  rankvalue = "ranks are fixed", blindtype = "Small, Big or Boss", looktarget = "a look, not a creation",
  card = "own cards come from the game pools (test_cards)", joker = "own cards come from the game pools (test_cards)", consumable = "own cards come from the game pools (test_cards)",
}
local FIELD_NO_OWN = {
  ["joker.rarity"] = "own rarities have their own Builder row",
  ["edition.shader"] = "the shine of an edition, not a pick", ["edition.tint"] = "a colour",
}

local function has(list, v)
  for _, x in ipairs(list or {}) do if x == v or tostring(x) == tostring(v) then return true end end
  return false
end

local seen_kinds = {}
for kind_id, list in pairs(Cat.EFFECTS) do
  local k = Cat.BY_ID[kind_id]
  for _, spec in ipairs(list) do
    local w = spec.v
    if w and not spec.base and not NO_OWN[w] then
      seen_kinds[w] = true
      local own_what = Cat.OWN_WHAT[w]
      check("value kind " .. w .. " (" .. kind_id .. "." .. spec.id .. ") has an own counterpart", own_what ~= nil)
      local v = own_what and own_of[own_what]
      if v then
        check(kind_id .. "." .. spec.id .. " picker offers own " .. own_what, has(Cat.values(w), v))
        if k then
          local e = Cat.clean_effects(kind_id, {{id = spec.id, v = v, n = spec.num and spec.num.def or nil}})[1]
          check(kind_id .. "." .. spec.id .. " keeps own " .. own_what .. " on save", e and e.v == v, e and e.v)
          local need = Cat.need_v({kind = kind_id, fields = {}, effects = {{id = spec.id, v = v, n = spec.num and spec.num.def or nil}}})
          check(kind_id .. "." .. spec.id .. " own value needs a newer format", need >= 6, need)
          if Cat.NEW_OWN[w] or spec.need == 16 then check(kind_id .. "." .. spec.id .. " own value needs format 16", need >= 16, need) end
        end
        check(kind_id .. "." .. spec.id .. " names own " .. own_what, Cat.value_label(w, v) == "Mine " .. (({boss = "blind", pack = "booster"})[own_what] or own_what), Cat.value_label(w, v))
      end
    end
  end
end
for _, w in ipairs({"levelhand", "shopset", "rarity3", "bossblind", "jsticker", "anysticker", "hand", "suit", "seal", "edition"}) do
  check("value kind " .. w .. " is used somewhere", seen_kinds[w] == true)
end

for _, k in ipairs(Cat.KINDS) do
  for _, list in ipairs({k.fields or {}, k.adv_fields or {}}) do
    for _, f in ipairs(list) do
      local w = f.type == "choice" and not f.dynamic and Cat.field_what(f)
      local own_what = f.own or (w and Cat.OWN_WHAT[w])
      local name = k.id .. "." .. f.id
      if own_what and not FIELD_NO_OWN[name] then
        check(name .. " is marked own", f.own ~= nil, own_what)
        local v = own_of[f.own or own_what]
        if f.own and v then
          check(name .. " offers own " .. f.own, has(Cat.field_values(f), v))
          local kept = Cat.clean_fields(k.id, {[f.id] = v})
          check(name .. " keeps own " .. f.own .. " on save", kept[f.id] == v, kept[f.id])
          if f.own == "boss" or f.own == "stake" or f.own == "hand" then
            check(name .. " own value needs format 16", Cat.need_v({kind = k.id, fields = {[f.id] = v}, effects = {}}) >= 16)
          end
        end
      end
    end
  end
end

check("run IF: own hand kept", (Cat.clean_only("hand_played", {{id = "hand", v = own_of.hand}})[1] or {}).v == own_of.hand)
check("run IF: own suit kept", (Cat.clean_only("card_scored", {{id = "suit", v = own_of.suit}})[1] or {}).v == own_of.suit)
check("run IF: Boss Blind kept", (Cat.clean_only("now", {{id = "blind", v = "bl_wall"}})[1] or {}).v == "bl_wall")
check("run IF: own Boss Blind kept", (Cat.clean_only("now", {{id = "blind", v = own_of.boss}})[1] or {}).v == own_of.boss)
check("run IF: junk still dropped", (Cat.clean_only("hand_played", {{id = "hand", v = "hand_forge_"}})[1] or {}).v == "Pair")
check("run IF: own hand needs 16", Cat.need_v({kind = "voucher", fields = {}, effects = {{id = "money", n = 2, when = "hand_played", only = {{id = "hand", v = own_of.hand}}}}}) >= 16)
check("bossblind lists vanilla bosses", has(Cat.values("bossblind"), "bl_wall") and not has(Cat.values("bossblind"), "bl_small"))
check("boss list stays vanilla", not has(Cat.values("boss"), own_of.boss))
check("ch_ban_blind offers own Boss", has(Cat.values(Cat.effect("challenge", "ch_ban_blind").v), own_of.boss))
check("ch_ban_pack offers own card type", has(Cat.values("packset"), own_of.ctype))
check("ch_ban_pack keeps own card type", Cat.clean_effects("challenge", {{id = "ch_ban_pack", v = own_of.ctype}})[1].v == own_of.ctype)
check("ch_ban_pack names own card type", Cat.value_label("packset", own_of.ctype) == "Mine ctype")
check("ch_deck vanilla decks", has(Cat.values("chback", true), "b_red") and not has(Cat.values("chback", true), "b_challenge"))
for _, id in ipairs({"ch_enhance", "ch_edition", "ch_seal", "ch_joker_edition", "ch_enh_n", "ch_seal_n", "ch_ed_n"}) do
  local spec = Cat.effect("challenge", id)
  local v = own_of[Cat.OWN_WHAT[spec.v]]
  check(id .. " offers own", spec.base == nil and has(Cat.values(spec.v), v))
  check(id .. " keeps own", Cat.clean_effects("challenge", {{id = id, v = v, n = spec.num and spec.num.def}})[1].v == v)
end

G.CHALLENGES = {}
G.P_CENTERS.b_blue = {key = "b_blue", set = "Back", name = "Blue Deck"}
Store.put_item({id = "lkpack2", kind = "booster", name = "Type pack", mode = "advanced", fields = {pack = own_of.ctype}, effects = {}, rules = {}, art = {}})
Store.put_item({id = "lksrc", kind = "challenge", name = "Source", mode = "advanced", fields = {}, effects = {{id = "ch_no_rank", v = "Ace"}, {id = "ch_no_suit", v = "Hearts"}}, rules = {}, art = {}})
local Ch = require("functions/forge/forge_challenges")
local me = {id = "lkme", kind = "challenge", name = "Me", fields = {}, effects = {
  {id = "ch_ban_blind", v = own_of.boss}, {id = "ch_ban_pack", v = own_of.pack}, {id = "ch_ban_pack", v = own_of.ctype},
  {id = "ch_no_shop", v = own_of.ctype}, {id = "ch_seal", v = own_of.seal}, {id = "ch_enhance", v = own_of.enhancement}, {id = "ch_edition", v = "foil"},
  {id = "ch_joker", v = "j_joker"}, {id = "ch_joker_edition", v = own_of.edition}, {id = "ch_deck", v = R.OWN_PREFIX.deck .. "lkdeck"}, {id = "ch_deck_of", v = R.OWN_PREFIX.challenge .. "lksrc"},
}}
G.P_CENTERS.j_joker = {key = "j_joker", set = "Joker"}
local built = Ch.build(me)
local function banned(list, id) for _, b in ipairs(list) do if b.id == id then return b end end return nil end
check("build bans own Boss", banned(built.restrictions.banned_other, own_of.boss) ~= nil)
check("build bans own pack", banned(built.restrictions.banned_cards, own_of.pack) ~= nil)
local tp = banned(built.restrictions.banned_cards, "p_forge_lkbooster") or {}
local tp2 = banned(built.restrictions.banned_cards, "p_forge_lkpack2")
check("build bans packs of own card type", tp2 ~= nil and has(tp2.ids, "p_forge_lkpack2") and not has(tp2.ids, "p_forge_lkbooster"), tp.id)
check("build no own card type in shop", built.forge_no_types and built.forge_no_types[1] == "lkctype")
check("build own deck", built.deck.type == "Forge lkdeck" and built.forge_back == "b_forge_lkdeck", built.deck.type)
check("build own seal not a plain key", built.deck.seal == nil and built.deck.cards and built.deck.cards[1].g == nil)
check("build vanilla edition kept", built.deck.cards and built.deck.cards[1].d == "foil")
check("build own challenge deck", built.deck.cards and #built.deck.cards == 36, built.deck.cards and #built.deck.cards)
check("build own Joker edition", built.jokers[1] and built.jokers[1].forge_ed == own_of.edition and built.jokers[1].edition == nil)
check("own challenge cannot copy itself", Ch.deck_cards(R.OWN_PREFIX.challenge .. "lkme", "lkme") == nil)
local vb = Ch.build({id = "lkv", kind = "challenge", name = "V", fields = {}, effects = {{id = "ch_deck", v = "b_blue"}, {id = "ch_seal", v = "Red"}}})
check("build vanilla deck", vb.deck.type == "Blue Deck" and vb.deck.seal == "Red", vb.deck.type)
check("Deck needs format 16", Cat.need_v({kind = "challenge", fields = {}, effects = {{id = "ch_deck", v = "b_blue"}}}) >= 16)
local DX = require("functions/forge/forge_chdeck")
check("own every-card seal runs at start", DX.own_all({id = "ch_seal", v = own_of.seal}) and not DX.own_all({id = "ch_seal", v = "Red"}))
local Ty = require("functions/forge/forge_types")
local t = {set = Ty.set_key("lkctype"), c = {fields = {shop = 3}}}
check("type weight from fields", Ty.weight(t) == 3)
Ty.set_weight("lkctype", 0)
check("type weight zeroed", Ty.weight(t) == 0)
Ty.set_weight("lkctype", 2, true)
check("type weight added", Ty.weight(t) == 2)
G.GAME.forge_type_rates = nil

local function rule(only, give)
  return R.clean_rules({{when = "hand_played", only = only or {}, give = give or {{id = "mult", n = 4}}}})[1] or {only = {}, give = {}}
end
local r1 = rule({{id = "blind", v = own_of.boss}})
check("Joker IF Blind is own Boss kept", (r1.only[1] or {}).v == own_of.boss, (r1.only[1] or {}).v)
check("Joker IF Blind is The Wall kept", (rule({{id = "blind", v = "bl_wall"}}).only[1] or {}).v == "bl_wall")
check("Joker IF Blind junk falls back", (rule({{id = "blind", v = "bl_nope"}}).only[1] or {}).v == "Small")
check("Joker IF Blind is own Boss needs 16", R.need_v({{when = "hand_played", only = {{id = "blind", v = own_of.boss}}, give = {{id = "mult", n = 4}}}}, {}) >= 16)
local r2 = rule({{id = "suit_and_other", v = own_of.suit}})
check("Joker IF suit_and_other own suit kept", (r2.only[1] or {}).v == own_of.suit, (r2.only[1] or {}).v)
check("Joker IF other_rarity own kept", (R.clean_rules({{when = "other_joker", only = {{id = "other_rarity", v = own_of.rarity}}, give = {{id = "mult", n = 4}}}})[1] or {only = {}}).only[1].v == own_of.rarity)
local vo = {}
for _, o in ipairs(R.VALUES_ONLY.other_rarity()) do vo[#vo + 1] = o.value end
check("Joker IF other_rarity offers own", has(vo, own_of.rarity))
local vb = {}
for _, o in ipairs(R.VALUES_GIVE.become()) do vb[#vb + 1] = o.value end
check("Joker DO become offers own rarity", has(vb, own_of.rarity))
check("Joker DO become keeps own rarity", (rule(nil, {{id = "become", v = own_of.rarity}}).give[1] or {}).v == own_of.rarity)
local vs = {}
for _, o in ipairs(R.VALUES_GIVE.stick_self()) do vs[#vs + 1] = o.value end
check("Joker DO stick_self offers Eternal and own", has(vs, "eternal") and has(vs, own_of.sticker))
check("Joker DO stick_self keeps Rental", (rule(nil, {{id = "stick_self", v = "rental"}}).give[1] or {}).v == "rental")
local vu = {}
for _, o in ipairs(R.VALUES_GIVE.unstick_card()) do vu[#vu + 1] = o.value end
check("Joker DO unstick_card offers any, vanilla and own", has(vu, "any") and has(vu, "perishable") and has(vu, own_of.sticker))
check("Joker DO unstick_self keeps own", (R.clean_rules({{when = "round_end", only = {}, give = {{id = "unstick_self", v = own_of.sticker}}}})[1] or {give = {}}).give[1].v == own_of.sticker)
check("Joker DO unstick needs 16", R.need_v({{when = "hand_played", only = {}, give = {{id = "unstick_card", v = "any"}}}}, {}) >= 16)
check("typed variable hand offers own", has(R.var_values("hand"), own_of.hand))
check("typed variable own hand needs 16", R.need_v({}, {{type = "hand", start = own_of.hand}}) >= 16)

check("deck seal_all listed", Cat.effect("deck", "seal_all") and Cat.effect("deck", "edition_all") and Cat.effect("deck", "remove_rank"))
check("deck remove_rank keeps Queen", Cat.clean_effects("deck", {{id = "remove_rank", v = "Queen"}})[1].v == "Queen")
check("deck seal_all needs 16", Cat.need_v({kind = "deck", fields = {}, effects = {{id = "seal_all", v = "Red"}}}) == 16)
check("next_boss on vouchers", Cat.effect("voucher", "next_boss") ~= nil and Cat.effect("use", "next_boss") == nil and Cat.effect("tarot", "next_boss") ~= nil)
check("next_boss not on Boss Blinds", Cat.effect("blind", "next_boss") == nil)
check("unstick_joker on decks and tarots", Cat.effect("deck", "unstick_joker") ~= nil and Cat.effect("tarot", "unstick_joker") ~= nil)
check("put_sticker offers Eternal", has(Cat.values("jsticker"), "eternal") and Cat.default_effect("tarot", "put_sticker").v == "eternal")
check("stick_deck stays own only", not has(Cat.values("sticker"), "eternal"))
check("old put_sticker save loads", Cat.clean_effects("tarot", {{id = "put_sticker", v = own_of.sticker}})[1].v == own_of.sticker)

local H = require("functions/forge/forge_hands")
local a = {id = "lka", kind = "hand", name = "A", fields = {pattern = "same_suit", beats = "hand_forge_lkb"}}
local b = {id = "lkb", kind = "hand", name = "B", fields = {pattern = "same_rank", beats = "Straight"}}
check("hand beats own hand kept", H.fields(a).beats == "hand_forge_lkb")
check("hand cannot beat itself", H.fields({id = "lka", kind = "hand", fields = {beats = "hand_forge_lka"}}).beats == "Flush")
local list_before = H.list
H.list = {a, b}
H.by_key = {hand_forge_lka = a, hand_forge_lkb = b}
local order = H.order_list()
local pa, pb, ps = 0, 0, 0
for i, h in ipairs(order) do
  if h == "hand_forge_lka" then pa = i elseif h == "hand_forge_lkb" then pb = i elseif h == "Straight" then ps = i end
end
check("hand order: A above B above Straight", pa > 0 and pa < pb and pb < ps, pa .. "," .. pb .. "," .. ps)
H.list = list_before

print(string.format("links: %d/%d passed", total - fails, total))
if fails > 0 then os.exit(1) end
