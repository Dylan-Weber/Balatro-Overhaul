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
  getDirectoryItems = function(dir)
    local out = {}
    for p in pairs(files) do
      local name = p:match("^" .. dir:gsub("%p", "%%%0") .. "/([^/]+)$")
      if name then out[#out + 1] = name end
    end
    return out
  end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end

local events = {}
Event = function(t) return t end
G = {
  P_CENTERS = {
    j_joker = {key = "j_joker", set = "Joker", name = "Joker", discovered = true, config = {}},
    j_baron = {key = "j_baron", set = "Joker", name = "Baron", discovered = true, config = {}},
    j_blueprint = {key = "j_blueprint", set = "Joker", name = "Blueprint", discovered = false, config = {}},
    j_cry_mod = {key = "j_cry_mod", set = "Joker", name = "Mod Joker", discovered = true, config = {}},
    c_fool = {key = "c_fool", set = "Tarot", name = "The Fool", config = {}},
  },
  P_CENTER_POOLS = {Joker = {}},
  C = {FILTER = {1, 1, 1, 1}, GREEN = {0, 1, 0, 1}, SECONDARY_SET = {Spectral = {0, 0, 1, 1}}},
  SETTINGS = {language = "en-us"},
  GAME = {probabilities = {normal = 1}, round_resets = {ante = 1}},
  E_MANAGER = {add_event = function(_, e) events[#events + 1] = e end},
  ASSET_ATLAS = {Joker = {name = "Joker", px = 71, py = 95}, forge_g1 = {name = "forge_g1", px = 71, py = 95}},
  CARD_W = 2, CARD_H = 3,
}
for _, k in ipairs({"j_joker", "j_baron", "j_blueprint", "j_cry_mod"}) do G.P_CENTER_POOLS.Joker[#G.P_CENTER_POOLS.Joker + 1] = G.P_CENTERS[k] end
local statuses = {}
card_eval_status_text = function(card, kind, a, b, c, t) statuses[#statuses + 1] = t and t.message end
localize = function(x) return type(x) == "string" and x or "?" end
local rolls = 0
pseudoseed = function(s) return s end
pseudorandom = function() rolls = rolls + 1 return 0.5 end
local pool_args
get_current_pool = function(t, rarity, legendary, append)
  pool_args = {t = t, rarity = rarity, legendary = legendary, append = append}
  if legendary then return {"UNAVAILABLE", "j_cry_mod"}, "Joker4" end
  if rarity and rarity > 0.95 then return {"j_baron", "UNAVAILABLE", "j_blueprint"}, "Joker3" end
  return {"j_joker"}, "Joker1"
end
discover_card = function(c) c.discovered = true end
play_sound = function() end

local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local T = require("functions/forge/forge_text")
local Mods = require("functions/forge/forge_mods")
local FJ = require("functions/forge/forge_joker")
local Room = require("functions/forge/forge_room")
local Grow = require("functions/forge/forge_grow")
local json = require("bot.sim.json")

check("ids listed", R.member(R.GIVE, "become") and R.member(R.GIVE, "next_look"))
check("joker only", R.allowed_give("round_end", "become", "joker") and not R.allowed_give("round_end", "become", "card") and not R.allowed_give("round_end", "next_look", "run"))
check("triggers: rounds, hands, Flush after", R.allowed_give("hand_played", "become") and R.allowed_give("after", "become") and R.allowed_give("blind_selected", "next_look") and R.allowed_give("discard", "become"))
check("triggers: not per card or passive", not R.allowed_give("card_scored", "become") and not R.allowed_give("card_held", "next_look") and not R.allowed_give("passive", "become") and not R.allowed_give("self_sold", "become"))
check("default become is Rare", R.default_give("become").v == "Rare" and R.default_give("next_look").id == "next_look")
check("simple lists them", R.SIMPLE_GIVE.become and R.SIMPLE_GIVE.next_look)

local function clean1(g, when) return R.clean_rules({{when = when or "round_end", give = {g}}})[1] end
check("clean: rarity kept", clean1({id = "become", v = "Legendary", n = 4}).give[1].v == "Legendary" and clean1({id = "become", v = "Legendary", n = 4}).give[1].n == nil)
check("clean: vanilla key kept", clean1({id = "become", v = "j_baron"}).give[1].v == "j_baron")
check("clean: own key kept", clean1({id = "become", v = "j_forge_abc"}).give[1].v == "j_forge_abc")
check("clean: mod key kept", clean1({id = "become", v = "j_cry_mod"}).give[1].v == "j_cry_mod")
check("clean: junk to Rare", clean1({id = "become", v = "c_fool"}).give[1].v == "Rare" and clean1({id = "become", v = "bad key!"}).give[1].v == "Rare")
check("clean: next look drops values", clean1({id = "next_look", v = "x", n = 3}).give[1].v == nil)
check("clean: dropped on card_scored", #clean1({id = "become", v = "Rare"}, "card_scored").give == 0)

check("text en random", T.give_text({id = "become", v = "Rare"}, "en") == "this Joker becomes a random {C:red}Rare{} Joker")
check("text fr random", T.give_text({id = "become", v = "Legendary"}, "fr") == "ce Joker devient un Joker {C:legendary}Légendaire{} au hasard")
check("text es random", T.give_text({id = "become", v = "Uncommon"}, "es") == "este Joker se convierte en un Joker {C:green}Poco común{} al azar")
check("text en chosen", T.give_text({id = "become", v = "j_baron"}, "en") == "this Joker becomes {C:attention}j_baron{}" or T.give_text({id = "become", v = "j_baron"}, "en"):find("becomes {C:attention}", 1, true) ~= nil)
check("text next look", T.give_text({id = "next_look"}, "en") == "this Joker gets its next look" and T.give_text({id = "next_look"}, "fr"):find("look suivant", 1, true) ~= nil and T.give_text({id = "next_look"}, "es"):find("aspecto", 1, true) ~= nil)
local egg_rules = {{when = "round_end", only = {{id = "every", v = "event", n = 3}}, give = {{id = "become", v = "Rare"}}}}
local sentence = T.sentence(R.clean_rules(egg_rules)[1], "en")
check("egg sentence", sentence:find("every {C:attention}3{} times", 1, true) ~= nil and sentence:find("random {C:red}Rare{} Joker", 1, true) ~= nil, sentence)
for _, l in ipairs({"en", "fr", "es"}) do
  local s = T.sentence({when = "hand_played", only = {{id = "hand", v = "Flush"}, {id = "every", v = "event", n = 10}}, give = {{id = "become", v = "j_baron"}}}, l)
  check("flush sentence " .. l, type(s) == "string" and not s:find("%%") and not s:find("nil"), s)
end

check("need: become is 16", R.need_v(R.clean_rules(egg_rules)) == 16)
check("need: next look is 16", R.need_v(R.clean_rules({{when = "round_end", only = {{id = "boss"}}, give = {{id = "next_look"}}}})) == 16)
check("need: plain stays old", R.need_v(R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4}}}})) < 16)
check("need: looks alone are 16", Mods.needs_v({{id = "a", rules = {}, looks = {{atlas = "Joker", x = 1, y = 0}}}}, {}) == 16)
check("need: plain joker old", Mods.needs_v({{id = "a", rules = {}}}, {}) < 16)
check("format 16", Mods.V >= 16 and Room.V >= 16 and Grow.V == 16)

local sc = Store.clean({id = "grow1", name = "Grower", art = {file = "forge/art/grow1.png"},
  looks = {{file = "forge/art/grow1_l2.png"}, {atlas = "Joker", x = 4, y = 2}, {file = "../evil.png"}, "junk", {atlas = "Joker", x = 500, y = -3}}, look_var = "v2"})
check("store: looks kept in order", sc.looks and #sc.looks == 3 and sc.looks[1].file == "forge/art/grow1_l2.png" and sc.looks[2].x == 4 and sc.looks[3].x == 99 and sc.looks[3].y == 0)
check("store: look var kept", sc.look_var == "v2")
check("store: look var only with looks", Store.clean({id = "x1", name = "A", look_var = "v1"}).look_var == nil)
check("store: bad look var dropped", Store.clean({id = "x2", name = "A", looks = {{atlas = "Joker"}}, look_var = "v9"}).look_var == nil)
local many = {}
for i = 1, 12 do many[i] = {atlas = "Joker", x = i, y = 0} end
check("store: at most 5 more looks", #Store.clean({id = "x3", name = "A", looks = many}).looks == Grow.MAX_LOOKS - 1)
check("store: old joker has no looks", Store.clean({id = "x4", name = "Old"}).looks == nil)

local function png(tag)
  local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
  return "\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(71) .. u32(95) .. "\8\6\0\0\0" .. tag .. string.rep("\0\255\1", 30)
end
Store.list, Store.items_list = {}, {}
files["forge/art/gg1.png"] = png("A")
files["forge/art/gg1_l2.png"] = png("B")
files["forge/art/gg1_l3.png"] = png("C")
Store.put({id = "gg1", name = "Egg Boss", rarity = 1, cost = 4, art = {file = "forge/art/gg1.png"}, looks = {{file = "forge/art/gg1_l2.png"}, {atlas = "Joker", x = 2, y = 1}, {file = "forge/art/gg1_l3.png"}},
  rules = {{when = "round_end", only = {{id = "boss"}}, give = {{id = "next_look"}}}, {when = "hand_played", give = {{id = "become", v = "j_forge_gg2"}}}}})
Store.put({id = "gg2", name = "Chick", rarity = 3, cost = 8})
local raw, out = Mods.pack({name = "Growing"}, {"gg1"})
check("mods: pack ok", type(raw) == "string" and out.v == 16, out)
check("mods: pack has the look files and the target", out and out.files and out.files.gg1_l2 and out.files.gg1_l3 and #out.jokers == 2)
local mod = Mods.parse(raw)
local mj = mod and mod.jokers[1]
check("mods: looks remapped", mj and mj.looks and #mj.looks == 3 and mj.looks[1].file == Mods.art_path(mod.id, "gg1_l2") and mj.looks[2].x == 2 and mj.looks[3].file == Mods.art_path(mod.id, "gg1_l3"), mj and mj.looks and mj.looks[1].file)
check("mods: become target renamed", mj and mj.rules[2].give[1].v == "j_forge_" .. mod.jokers[2].id, mj and mj.rules[2].give[1].v)
files["forge/art/gg1_l3.png"] = string.rep("x", 10)
local raw2, out2 = Mods.pack({name = "Growing"}, {"gg1"})
local m2 = raw2 and Mods.parse(raw2)
check("mods: bad look file keeps its place", out2 and out2.files.gg1_l3 == nil and m2 and #m2.jokers[1].looks == 3 and m2.jokers[1].looks[3].atlas == "Joker")
files["forge/art/gg1_l3.png"] = png("C")
local old = json.decode(raw)
old.v = 18
check("mods: newer refused", select(2, Mods.parse(json.encode(old))) == "newer")
check("mods: format 15 still loads", Mods.parse(json.encode({format = "forgemod", v = 15, id = "old15", name = "Old", jokers = {{id = "o1", name = "Old", rules = {{when = "hand_played", give = {{id = "mult", n = 4}}}}}}})) ~= nil)
local oldc = json.decode(Mods.for_old_server(raw))
check("mods: old server copy asks for 16", oldc.v == 1 and oldc.need == 16)

local rraw, rinfo = Room.pack()
check("room: pack ok", rraw and rinfo.art == 3, rinfo and rinfo.art)
local rt = rraw and json.decode(rraw)
check("room: format 16", rt and rt.room == 16)
check("room: enter", Room.enter(rraw) == true)
local rj = Store.get("mproom01")
check("room: looks arrive", rj and rj.looks and #rj.looks == 3 and rj.looks[1].file == "forge/art/fm_mproom_r01L2.png" and files["forge/art/fm_mproom_r01L2.png"] == files["forge/art/gg1_l2.png"] and rj.looks[2].x == 2, rj and rj.looks and rj.looks[1].file)
check("room: become renamed", rj and rj.rules[2].give[1].v == "j_forge_mproom02", rj and rj.rules[2].give[1].v)
Room.leave()
rt.room = 18
check("room: newer refused", select(2, Room.enter(json.encode(rt))) == "newer")

local dup = Store.duplicate("gg1")
check("store: copy has its own look files", dup and dup.looks[1].file ~= "forge/art/gg1_l2.png" and files[dup.looks[1].file] == files["forge/art/gg1_l2.png"] and dup.looks[2].atlas == "Joker")
local dupfile = dup and dup.looks[1].file
Store.delete(dup.id)
check("store: delete removes look files", dupfile and files[dupfile] == nil and files["forge/art/gg1_l2.png"] ~= nil)

FJ.atlas_from_data = function(name) G.ASSET_ATLAS[name] = {name = name, px = 71, py = 95} return G.ASSET_ATLAS[name] end
love.image = {newImageData = function(p) if not files[p] then error("no file") end return {getWidth = function() return 71 end, getHeight = function() return 95 end, getDimensions = function() return 71, 95 end} end}
local cen = FJ.center_for(Store.get("gg1"), 1)
check("center: three more stages", cen.forge_stages and #cen.forge_stages == 3 and cen.forge_stages[1].atlas == "forge_gg1_l2" and cen.forge_stages[2].atlas == "Joker" and cen.forge_stages[2].pos.x == 2)
check("center: no var", cen.forge_look_var == nil)
local plain_cen = FJ.center_for(Store.get("gg2"), 2)
check("center: plain joker has no stages", plain_cen.forge_stages == nil)

local function sprite(atlas)
  local s = {atlas = G.ASSET_ATLAS[atlas], scale = {x = 10, y = 5}, sprite_pos = {x = 0, y = 0}}
  function s:set_sprite_pos(p) self.sprite_pos = {x = p.x, y = p.y} end
  function s:remove() self.removed = true end
  return s
end
local function jcard(center, extra)
  local c = {config = {center = center}, ability = {extra = extra or {}, eternal = true, perishable = true, perish_tally = 3, rental = true, name = center.name},
    edition = {holo = true, type = "holo"}, children = {center = sprite(center.atlas or "Joker")}, T = {w = 1, h = 1}, added_to_deck = true, calls = {}}
  function c:remove_from_deck() self.calls[#self.calls + 1] = "remove"; self.added_to_deck = false end
  function c:add_to_deck() self.calls[#self.calls + 1] = "add"; self.added_to_deck = true end
  function c:set_ability(ce) self.calls[#self.calls + 1] = "set"; self.config.center = ce; self.ability = {name = ce.name, extra = {}} end
  function c:set_cost() self.calls[#self.calls + 1] = "cost" end
  function c:juice_up() end
  return c
end

local cj = jcard(cen, {look = 1})
check("stage: starts at 1", Grow.stage_of(cj) == 1)
Grow.show(cj)
check("show: first look untouched", cj.children.center.forge_stage == nil)
local x = cj.ability.extra
R.DOS.next_look({id = "next_look"}, cj, cj, {})
check("next look: 2", x.look == 2 and Grow.stage_of(cj) == 2)
Grow.show(cj)
check("show: second look atlas", cj.children.center.atlas == G.ASSET_ATLAS.forge_gg1_l2 and cj.children.center.forge_stage == 2)
R.DOS.next_look({id = "next_look"}, cj, cj, {})
Grow.show(cj)
check("show: third look is game art", cj.children.center.atlas == G.ASSET_ATLAS.Joker and cj.children.center.sprite_pos.x == 2 and cj.children.center.sprite_pos.y == 1)
R.DOS.next_look({id = "next_look"}, cj, cj, {})
R.DOS.next_look({id = "next_look"}, cj, cj, {})
check("next look stops at the last", x.look == 4)
R.DOS.next_look({id = "next_look"}, cj, cj, {blueprint = true})
check("next look: blueprint does nothing", x.look == 4)
x.look = 1
Grow.show(cj)
check("show: back to the first look", cj.children.center.forge_stage == nil and cj.children.center.atlas == G.ASSET_ATLAS[cen.atlas or "Joker"])
cen.forge_look_var = 2
x.vars = {5, 1}
check("var: follows variable 2", Grow.stage_of(cj) == 2)
x.vars[2] = 99
check("var: capped at the last", Grow.stage_of(cj) == 4)
x.vars[2] = -3
check("var: never below the first", Grow.stage_of(cj) == 1)
cen.forge_look_var = nil

G.jokers = {cards = {}}
local egg = jcard(G.P_CENTERS.j_joker)
egg.area = G.jokers
events = {}
R.DOS.become({id = "become", v = "Rare"}, egg, egg, {})
check("random: Rare roll asked", pool_args and pool_args.t == "Joker" and pool_args.rarity == 0.99 and not pool_args.legendary)
check("random: queued", #events == 1 and (egg.forge_becoming == "j_baron" or egg.forge_becoming == "j_blueprint"), egg.forge_becoming)
R.DOS.become({id = "become", v = "Rare"}, egg, egg, {})
check("random: one change at a time", #events == 1)
local target = egg.forge_becoming
events[1].func()
check("become: new joker", egg.config.center.key == target and egg.forge_becoming == nil)
check("become: keeps edition", egg.edition and egg.edition.holo)
check("become: keeps stickers", egg.ability.eternal == true and egg.ability.perishable == true and egg.ability.perish_tally == 3 and egg.ability.rental == true)
check("become: leaves and rejoins the deck", table.concat(egg.calls, ",") == "remove,set,add,cost", table.concat(egg.calls, ","))
check("become: discovers the target", G.P_CENTERS[target].discovered == true)
check("become: card size reset", egg.T.w == G.CARD_W and egg.T.h == G.CARD_H)
check("become: status shown", statuses[#statuses] == "Grew up!")

events = {}
local bp = jcard(G.P_CENTERS.j_joker)
bp.area = G.jokers
R.DOS.become({id = "become", v = "j_baron"}, bp, bp, {blueprint = true})
check("blueprint copies do not change", #events == 0)
local away = jcard(G.P_CENTERS.j_joker)
R.DOS.become({id = "become", v = "j_baron"}, away, away, {})
check("only owned jokers change", #events == 0)
local legend = jcard(G.P_CENTERS.j_joker)
legend.area = G.jokers
legend.children.floating_sprite = sprite("Joker")
local fl = legend.children.floating_sprite
R.DOS.become({id = "become", v = "Legendary"}, legend, legend, {})
check("legendary: asks the legendary pool", pool_args.legendary == true and legend.forge_becoming == "j_cry_mod")
events[1].func()
check("legendary: old soul sprite removed", fl.removed and legend.children.floating_sprite == nil)
events = {}
local same = jcard(G.P_CENTERS.j_baron)
same.area = G.jokers
R.DOS.become({id = "become", v = "j_baron"}, same, same, {})
check("never becomes itself", #events == 0)
R.DOS.become({id = "become", v = "c_fool"}, same, same, {})
check("only Jokers", #events == 0)
R.DOS.become({id = "become", v = "j_forge_gg2"}, same, same, {})
check("own creation target", #events == 1 and same.forge_becoming == "j_forge_gg2")
events = {}
local off = jcard(G.P_CENTERS.j_joker)
off.area = G.jokers
G.P_CENTERS.j_forge_gg2.forge_on = false
R.DOS.become({id = "become", v = "j_forge_gg2"}, off, off, {})
check("switched off creation is skipped", #events == 0)
G.P_CENTERS.j_forge_gg2.forge_on = true

events = {}
local eggc = jcard(G.P_CENTERS.j_joker)
eggc.area = G.jokers
local rules = R.clean_rules(egg_rules)
for i = 1, 2 do R.calculate(eggc, {end_of_round = true}, rules) end
check("egg: not after 2 rounds", #events == 0)
R.calculate(eggc, {end_of_round = true}, rules)
check("egg: hatches after 3 rounds", #events == 1)

events = {}
local flush = jcard(G.P_CENTERS.j_joker)
flush.area = G.jokers
local frules = R.clean_rules({{when = "hand_played", only = {{id = "hand", v = "Flush"}, {id = "every", v = "event", n = 10}}, give = {{id = "become", v = "j_cry_mod"}}}})
local function play(name)
  local ph = {[name] = {{1}}}
  return R.calculate(flush, {cardarea = G.jokers, joker_main = true, full_hand = {}, scoring_hand = {}, scoring_name = name, poker_hands = ph}, frules)
end
for _ = 1, 9 do play("Flush") end
for _ = 1, 5 do play("Pair") end
check("flush: 9 Flushes and some Pairs do nothing", #events == 0)
play("Flush")
check("flush: the 10th Flush changes it", #events == 1 and flush.forge_becoming == "j_cry_mod")

print(string.format("forge grow: %d checks, %d failed", total, fails))
