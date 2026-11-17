package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

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
Event = function(t) return t end
pseudoseed = function(s) return s end
pseudorandom_element = function(list) return list[1], 1 end

local made = {}
create_card = function(set, area, _, _, _, _, key)
  local c = {set = set, key = key, area = area, config = {center = {key = key}}}
  function c.add_to_deck() end
  function c.start_materialize() end
  function c.juice_up() end
  made[#made + 1] = c
  return c
end

local function area(limit)
  return {cards = {}, config = {card_limit = limit}, emplace = function(self, c) self.cards[#self.cards + 1] = c end}
end

local function reset_game()
  made = {}
  G = {
    GAME = {joker_buffer = 0, consumeable_buffer = 0},
    jokers = area(2), consumeables = area(2),
    E_MANAGER = {add_event = function(_, e) e.func() end},
    C = {FILTER = {}, GREEN = {}},
    P_CENTERS = {
      j_joker = {key = "j_joker", set = "Joker"}, c_fool = {key = "c_fool", set = "Tarot"}, c_pluto = {key = "c_pluto", set = "Planet"},
      m_gold = {key = "m_gold", set = "Enhanced"},
    },
    P_CENTER_POOLS = {Joker = {}, Tarot = {}, Planet = {}, Spectral = {}},
    localization = {descriptions = {Joker = {j_joker = {name = "Joker"}}, Tarot = {c_fool = {name = "The Fool"}}}},
  }
  G.P_CENTER_POOLS.Joker[1] = G.P_CENTERS.j_joker
  G.P_CENTER_POOLS.Tarot[1] = G.P_CENTERS.c_fool
  G.P_CENTER_POOLS.Planet[1] = G.P_CENTERS.c_pluto
end
reset_game()

local json = require("bot.sim.json")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local Cat = require("functions/forge/forge_catalog")
local D = require("functions/forge/forge_doc")
local Mods = require("functions/forge/forge_mods")
local Room = require("functions/forge/forge_room")

local function fresh_store()
  files, dirs = {}, {}
  Store.list, Store.items_list, Store.settings = nil, nil, nil
  Mods.index, Mods.list, Mods.jokers, Mods.items = nil, {}, {}, {}
end

check("version 15 for mods", Mods.V == 15)
check("rooms follow the creation version", Room.V == Mods.V)

for _, kind in ipairs({"tarot", "spectral", "planet", "tag", "voucher", "stake", "blind", "deck"}) do
  local spec = Cat.effect(kind, "make_card")
  check("make_card offered on " .. kind, spec and spec.v == "card" and spec.need == 7)
end
check("deck start_card", Cat.effect("deck", "start_card") and Cat.effect("deck", "start_card").need == 7)
for _, id in ipairs({"debuff_enh", "debuff_seal", "debuff_edition"}) do
  check("boss " .. id, Cat.effect("blind", id) and Cat.effect("blind", id).need == 7)
end
check("booster pack_card", Cat.effect("booster", "pack_card") and Cat.effect("booster", "pack_card").v == "card")
check("joker give make_card", R.allowed_give("hand_played", "make_card") and R.default_give("make_card").v == R.CARD_DEFAULT)

check("card_ok base", R.card_ok("j_joker") and R.card_ok("c_fool"))
check("card_ok own", R.card_ok("j_forge_abc123") and R.card_ok("c_forge_t1"))
check("card_ok junk", not R.card_ok("m_gold") and not R.card_ok("bad key") and not R.card_ok(5) and not R.card_ok(string.rep("j", 50)))
check("own_id card", R.own_id("card", "j_forge_abc") == "abc" and R.own_id("card", "c_forge_x1") == "x1" and R.own_id("card", "j_joker") == nil)

local cleaned = Cat.clean_effects("tarot", {{id = "make_card", v = "c_forge_t1", n = 2}, {id = "make_card", v = "nope nope"}})
check("clean keeps own card key", cleaned[1] and cleaned[1].v == "c_forge_t1" and cleaned[1].n == 2)
check("clean resets junk to default", cleaned[2] and cleaned[2].v == R.CARD_DEFAULT)
local rules = R.clean_rules({{when = "hand_played", give = {{id = "make_card", v = "j_forge_j1"}, {id = "make_card", v = 12}}}})
check("rule keeps make_card key", rules[1].give[1].v == "j_forge_j1")
check("rule resets bad make_card", rules[1].give[2].v == R.CARD_DEFAULT)

check("need_v tarot make_card", Cat.need_v({kind = "tarot", fields = {}, effects = {{id = "make_card", v = "c_fool", n = 1}}}) == 7)
check("need_v max over effects", Cat.need_v({kind = "tag", fields = {}, effects = {{id = "give_voucher", v = "v_hone"}, {id = "make_card", v = "c_fool", n = 1}}}) == 7)
check("need_v field then effect", Cat.need_v({kind = "tarot", fields = {requires = "v_hone"}, effects = {{id = "make_card", v = "c_fool", n = 1}}}) == 7)
check("need_v deck start_card", Cat.need_v({kind = "deck", fields = {}, effects = {{id = "start_card", v = "c_fool", n = 2}}}) == 7)
check("need_v chosen pack", Cat.need_v({kind = "booster", fields = {pack = "Chosen"}, effects = {}}) == 7)
check("need_v plain pack stays low", Cat.need_v({kind = "booster", fields = {pack = "Arcana"}, effects = {}}) < 6)
check("need_v boss debuff", Cat.need_v({kind = "blind", fields = {}, effects = {{id = "debuff_seal", v = "Red"}}}) == 7)
check("need_v joker rule", R.need_v({{when = "hand_played", give = {{id = "make_card", v = "c_fool"}}}}) == 7)
check("needs_v mixes", Mods.needs_v({{rules = {{when = "hand_played", give = {{id = "make_card", v = "c_fool"}}}}}}, {}) == 7)

local t = {effects = {{id = "make_card", v = "j_forge_old1"}, {id = "pack_card", v = "c_forge_old2"}, {id = "pack_card", v = "j_joker"}}, rules = {{give = {{id = "make_card", v = "c_forge_old2"}}}}}
R.map_refs(t, function(old) return ({old1 = "new1", old2 = "new2"})[old] end)
check("map_refs joker key", t.effects[1].v == "j_forge_new1")
check("map_refs consumable key", t.effects[2].v == "c_forge_new2" and t.rules[1].give[1].v == "c_forge_new2")
check("map_refs leaves base keys", t.effects[3].v == "j_joker")

local pack = {kind = "booster", fields = {pack = "Chosen"}, effects = {{id = "pack_card", v = "j_joker"}, {id = "pack_card", v = "c_forge_t1"}, {id = "pack_card", v = "bad"}}}
local pc = Cat.pack_cards(pack)
check("pack_cards lists valid keys", #pc == 2 and pc[1] == "j_joker" and pc[2] == "c_forge_t1")
check("pack_cards off unless Chosen", #Cat.pack_cards({kind = "booster", fields = {pack = "Arcana"}, effects = pack.effects}) == 0)
check("max_for hides list unless Chosen", Cat.max_for({kind = "booster", fields = {pack = "Arcana"}}, true) == 0 and Cat.max_for(pack, true) == Cat.PACK_MAX)
check("new booster has no default entry", #D.new("booster").effects == 0)
local probs = D.problems({kind = "booster", name = "P", fields = {pack = "Chosen"}, effects = {}})
local has = false
for _, p in ipairs(probs) do if p == "Add at least one card to the pack" then has = true end end
check("empty chosen pack is a problem", has)
local probs2 = D.problems({kind = "booster", name = "P", fields = {pack = "Arcana"}, effects = {}})
check("plain pack needs no entries", #probs2 == 0)

fresh_store()
Store.put({id = "jk1", name = "Kindling", rarity = 1, cost = 4, rules = {}})
Store.put_item({id = "tt1", kind = "tarot", name = "Spark", fields = {}, effects = {}})
Store.put_item({id = "tt2", kind = "tarot", name = "Off", enabled = false, fields = {}, effects = {}})
G.P_CENTERS.j_forge_jk1 = {key = "j_forge_jk1", set = "Joker", forge = true, forge_on = true}
G.P_CENTERS.c_forge_tt1 = {key = "c_forge_tt1", set = "Tarot", forge_kind = "tarot", forge_on = true}
G.P_CENTERS.c_forge_tt2 = {key = "c_forge_tt2", set = "Tarot", forge_kind = "tarot", forge_on = false}
G.P_CENTER_POOLS.Tarot[2] = G.P_CENTERS.c_forge_tt1

check("label own joker", R.card_label("j_forge_jk1") == "Kindling")
check("label own tarot", Cat.value_label("card", "c_forge_tt1") == "Spark")
check("label base", R.card_label("c_fool") == "The Fool")
check("label deleted", R.card_label("c_forge_gone9") == "Lost card")
local tv = R.card_values("Tarot")
check("picker lists own first then base", tv[1] == "c_forge_tt1" and tv[2] == "c_fool" and #tv == 2)
check("picker skips unticked", not table.concat(tv, ","):find("tt2"))
check("picker jokers", R.card_values("Joker")[1] == "j_forge_jk1")

check("usable own", R.usable("card", "c_forge_tt1") and R.card_usable("j_forge_jk1"))
check("unticked not usable", not R.card_usable("c_forge_tt2"))
check("deleted not usable", not R.card_usable("c_forge_gone9"))
check("non card not usable", not R.card_usable("m_gold"))

reset_game()
G.P_CENTERS.j_forge_jk1 = {key = "j_forge_jk1", set = "Joker", forge = true, forge_on = true}
G.P_CENTERS.c_forge_tt1 = {key = "c_forge_tt1", set = "Tarot", forge_kind = "tarot", forge_on = true}
G.P_CENTERS.c_forge_tt2 = {key = "c_forge_tt2", set = "Tarot", forge_kind = "tarot", forge_on = false}
check("make own tarot", R.make_card("c_forge_tt1") and G.consumeables.cards[1] and G.consumeables.cards[1].key == "c_forge_tt1")
check("make own joker", R.make_card("j_forge_jk1") and G.jokers.cards[1].key == "j_forge_jk1")
check("make base joker", R.make_card("j_joker") and G.jokers.cards[2].key == "j_joker")
check("joker slots respected", not R.make_card("j_joker") and #G.jokers.cards == 2)
check("unticked makes nothing", not R.make_card("c_forge_tt2") and #G.consumeables.cards == 1)
check("deleted makes nothing", not R.make_card("c_forge_zz9") and #made == 3)
check("buffers back to 0", G.GAME.joker_buffer == 0 and G.GAME.consumeable_buffer == 0)

local T = require("functions/forge/forge_text")
local lines = T.lines({rules = R.clean_rules({{when = "hand_played", give = {{id = "make_card", v = "c_forge_tt1"}}}}), vars = {}}, "en")
local all = table.concat(lines, " ")
check("joker text names the card", all:find("Spark") ~= nil and all:find("Must have room") ~= nil)
check("tarot line one copy", Cat.effect_line("tarot", {id = "make_card", v = "c_forge_tt1", n = 1}) == "Makes {C:attention}Spark{}")
check("tarot line copies", Cat.effect_line("tarot", {id = "make_card", v = "c_fool", n = 3}) == "Makes {C:attention}3{} copies of {C:attention}The Fool{}")
check("deck line", Cat.effect_line("deck", {id = "start_card", v = "j_forge_jk1", n = 1}) == "Start with {C:attention}Kindling{}")
check("boss enh line", Cat.effect_line("blind", {id = "debuff_enh", v = "m_gold"}):find("debuffed") ~= nil)
local bl = D.lines({kind = "booster", mode = "simple", fields = {pack = "Chosen", size = "Normal"}, effects = {{id = "pack_card", v = "c_forge_tt1"}, {id = "pack_card", v = "j_forge_jk1"}}}, "en")
check("pack text lists the cards", table.concat(bl, " "):find("{C:attention}Spark{}, {C:attention}Kindling{}", 1, true) ~= nil)

fresh_store()
Store.put({id = "jk1", name = "Kindling", rarity = 1, cost = 4, rules = {}})
Store.put_item({id = "tt1", kind = "tarot", name = "Spark", fields = {}, effects = {{id = "make_card", v = "j_forge_jk1", n = 1}}})
Store.put_item({id = "pk1", kind = "booster", name = "Picks", fields = {pack = "Chosen"}, effects = {{id = "pack_card", v = "c_forge_tt1"}, {id = "pack_card", v = "j_joker"}}})
Store.put_item({id = "dk1", kind = "deck", name = "Starter", fields = {}, effects = {{id = "start_card", v = "c_forge_tt1", n = 2}}})
Store.put({id = "jk2", name = "Maker", rarity = 1, cost = 4, rules = {{when = "hand_played", give = {{id = "make_card", v = "c_forge_tt1"}}}}})
local raw, out = Mods.pack({name = "Cards"}, {"pk1", "dk1", "jk2"})
local got = {}
for _, c in ipairs(out and out.creations or {}) do got[c.id] = true end
for _, c in ipairs(out and out.jokers or {}) do got[c.id] = true end
check("export pulls the tarot and its joker", got.tt1 and got.jk1 and got.pk1 and got.dk1 and got.jk2)
check("export is version 7", out and out.v == 7)
local mod = raw and Mods.parse(raw)
local by = {}
for _, c in ipairs(mod and mod.creations or {}) do by[c.kind] = c end
local jk1, jk2
for _, c in ipairs(mod and mod.jokers or {}) do if c.name == "Kindling" then jk1 = c else jk2 = c end end
check("install renames ids", by.tarot and by.tarot.id ~= "tt1" and jk1 and jk1.id ~= "jk1")
check("install: pack names the installed tarot", by.booster and by.booster.effects[1].v == "c_forge_" .. by.tarot.id and by.booster.effects[2].v == "j_joker")
check("install: tarot names the installed joker", by.tarot and by.tarot.effects[1].v == "j_forge_" .. jk1.id)
check("install: deck names the installed tarot", by.deck and by.deck.effects[1].v == "c_forge_" .. by.tarot.id)
check("install: joker rule names the installed tarot", jk2 and jk2.rules[1].give[1].v == "c_forge_" .. by.tarot.id)
local t8 = json.decode(raw)
t8.v = 16
local m8, err8 = Mods.parse(json.encode(t8))
check("older game refuses v16 as newer", m8 == nil and err8 == "newer")

G.FUNCS = G.FUNCS or {}
local okM, KM = pcall(require, "functions/forge/forge_kinds_more")
if not okM then print(KM) end
check("kinds_more loads", okM)
if okM then
  fresh_store()
  reset_game()
  Store.put_item({id = "bb1", kind = "blind", name = "Gilded", fields = {}, effects = {{id = "debuff_enh", v = "m_gold"}, {id = "debuff_seal", v = "Forge_se1"}, {id = "debuff_edition", v = "forge_ed1"}}})
  Store.put_item({id = "se1", kind = "seal", name = "Moon", fields = {}, effects = {}})
  Store.put_item({id = "ed1", kind = "edition", name = "Glow", fields = {}, effects = {}})
  G.P_SEALS, G.shared_seals = {Forge_se1 = {}}, {Forge_se1 = {}}
  G.P_CENTERS.e_forge_ed1 = {key = "e_forge_ed1"}
  local blind = {config = {blind = {forge_kind = "blind", forge_id = "bb1"}}}
  local function card(o) o.config = o.config or {center = {key = "c_base"}} return o end
  check("boss debuffs the enhancement", KM.blind_debuffs(blind, card({config = {center = {key = "m_gold"}}})))
  check("boss debuffs the own seal", KM.blind_debuffs(blind, card({seal = "Forge_se1"})))
  check("boss debuffs the own edition", KM.blind_debuffs(blind, card({edition = {forge = "ed1", foil = true}})))
  check("boss leaves other cards", not KM.blind_debuffs(blind, card({seal = "Red", edition = {foil = true}})))
  Store.delete_item("se1")
  check("deleted seal debuffs nothing", not KM.blind_debuffs(blind, card({seal = "Forge_se1"})))
  G.pack_cards = {cards = {{config = {center = {key = "j_joker"}}}}}
  check("pack pick skips cards already shown", KM.pick_key({"j_joker", "c_fool", "c_forge_none"}) == "c_fool")
  check("pack pick repeats when the list is used up", KM.pick_key({"j_joker"}) == "j_joker")
  check("pack pick with only deleted cards gives nothing", KM.pick_key({"c_forge_none", "j_forge_none"}) == nil)
  check("pack look", KM.pick_look({"j_joker"}) == "Buffoon" and KM.pick_look({"c_pluto"}) == "Celestial" and KM.pick_look({"j_joker", "c_fool"}) == "Arcana")
  G.pack_cards = nil
  check("other blinds untouched", not KM.blind_debuffs({config = {blind = {key = "bl_wall"}}}, card({config = {center = {key = "m_gold"}}})))
  Store.put_item({id = "bb2", kind = "blind", name = "Counter", fields = {}, effects = {{id = "debuff_enh", v = "m_gold"}}, rules = {{when = "hand_played", only = {}, give = {{id = "var_add", var = 1, n = 1}}}}, vars = {{name = "Hands", start = 0}}})
  local bt = table.concat(KM.blind_text(Store.get_item("bb2")), " ")
  check("blind text shows its rules and the live variable", bt:find("hand is played", 1, true) ~= nil and bt:find("Hands:", 1, true) ~= nil and bt:find("#5#", 1, true) ~= nil)
  check("blind without rules keeps its old text", #KM.blind_text(Store.get_item("bb1")) <= 2)
end

print(string.format("forge cards: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
