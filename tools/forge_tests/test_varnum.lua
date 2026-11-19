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
local rnd = 0.01
pseudorandom = function() return rnd end
localize = function(a) if type(a) == "table" then return a.key end return a end
card_eval_status_text = function() end

local log
local function reset_game()
  log = {dollars = 0, hands = 0, discards = 0, created = {}, applied = {}, removed = 0}
  G = {
    GAME = {joker_buffer = 0, consumeable_buffer = 0, dollars = 10, probabilities = {normal = 1}, current_round = {hands_left = 3, discards_left = 2, hands_played = 0}, round_resets = {ante = 1}, blind = {boss = false}},
    play = {name = "play"}, hand = {name = "hand", highlighted = {}},
    jokers = {cards = {}, config = {card_limit = 5}}, consumeables = {cards = {}, config = {card_limit = 2}, emplace = function(self, c) self.cards[#self.cards + 1] = c end},
    E_MANAGER = {add_event = function(_, e) e.func() end},
    C = {FILTER = {}, GREEN = {}, MONEY = {}, MULT = {}, CHIPS = {}, BLUE = {}, RED = {}, SECONDARY_SET = {Planet = {}, Tarot = {}, Spectral = {}}},
    P_CENTERS = {m_gold = {key = "m_gold", set = "Enhanced"}},
    P_CENTER_POOLS = {Joker = {}, Tarot = {}, Planet = {}, Spectral = {}},
  }
end
reset_game()
ease_dollars = function(n) log.dollars = log.dollars + n; G.GAME.dollars = G.GAME.dollars + n end
ease_hands_played = function(n) log.hands = log.hands + n end
ease_discard = function(n) log.discards = log.discards + n end
create_card = function(kind)
  log.created[#log.created + 1] = kind
  return {add_to_deck = function() end, start_materialize = function() end}
end

local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local Cat = require("functions/forge/forge_catalog")
local T = require("functions/forge/forge_text")
local D = require("functions/forge/forge_doc")
local H = require("functions/forge/forge_hostrules")
local Mods = require("functions/forge/forge_mods")
json = require("bot.sim.json")
package.loaded["functions/forge/forge_run"] = {
  apply = function(e) log.applied[#log.applied + 1] = e.id .. ":" .. tostring(e.n) end,
  sources = function() return log.sources or {} end,
  previewing = function() return false end,
}

local function pcard(suit, id, o)
  o = o or {}
  local c = {ability = {set = o.set or "Enhanced"}, config = {center = o.center or {key = "c_base"}}, seal = o.seal, edition = o.edition, base = {suit = suit, id = id}}
  function c:get_id() return self.base.id end
  function c:is_suit(s) return self.base.suit == s end
  function c:is_face() return self.base.id >= 11 and self.base.id <= 13 end
  function c:start_dissolve() log.removed = log.removed + 1; self.removed = true end
  return c
end

local function put(kind, id, rules, vars, extra)
  local c = {id = id, kind = kind, name = id, fields = {}, effects = {}, rules = rules, vars = vars}
  for k, v in pairs(extra or {}) do c[k] = v end
  return Store.put_item(c) or Store.get_item(id)
end

local function enh_card(id, suit, rank)
  return pcard(suit or "Hearts", rank or 7, {center = {key = "m_forge_" .. id, forge_kind = "enhancement", forge_id = id}})
end

local function score(card)
  local ret = {}
  H.eval_card(card, {cardarea = G.play, full_hand = {card}, scoring_hand = {card}, poker_hand = "High Card"}, ret)
  return ret
end

local P3 = require("functions/forge/forge_power3")
local Room = require("functions/forge/forge_room")
local VARS = {{name = "c", start = 3}, {name = "d", start = 10}, {name = "s", type = "suit", start = "Hearts"}}

local c1 = R.clean_rules({{when = "hand_played", only = {{id = "money", op = "at_least", n = 10, nv = 2}}, give = {{id = "mult", n = 4, nv = 1}, {id = "chips", n = 30}}, alt = {{id = "xmult", n = 2, nv = 1}}}})[1]
check("clean: give keeps nv", c1.give[1].nv == 1 and c1.give[1].n == 4)
check("clean: cond keeps nv", c1.only[1].nv == 2 and c1.only[1].n == 10)
check("clean: alt keeps nv", c1.alt and c1.alt[1].nv == 1)
check("clean: plain number has no nv", c1.give[2].nv == nil)
for _, bad in ipairs({0, 5, -1, 1.5, "x", true}) do
  local g = R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4, nv = bad}}}})[1].give[1]
  check("clean: bad nv dropped " .. tostring(bad), g.nv == nil and g.n == 4)
end
check("clean: string index taken", R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4, nv = "2"}}}})[1].give[1].nv == 2)
check("clean: no number, no nv", R.clean_rules({{when = "hand_played", give = {{id = "level_up", nv = 1}}}})[1].give[1].nv == nil)
check("clean: var_pick has no number", R.clean_rules({{when = "hand_played", give = {{id = "var_pick", var = 3, v = "random", nv = 1}}}})[1].give[1].nv == nil)
local cvr = R.clean_rules({{when = "blind_selected", give = {{id = "hand_size", n = 2, nv = 1}}}}, "voucher")[1].give[1]
check("clean: run give keeps nv", cvr.run and cvr.nv == 1 and cvr.n == 2)

check("need: nv rules need 14", R.need_v({c1}) == 14 and R.NV_V == 14)
check("need: plain rules unchanged", R.need_v(R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4}}}})) == 1)
check("need: alt nv counts", R.need_v({{when = "hand_played", only = {{id = "first_hand"}}, give = {{id = "mult", n = 1}}, alt = {{id = "mult", n = 1, nv = 1}}}}) == 14)
check("need: mods count jokers", Mods.needs_v({{id = "j", rules = {c1}, vars = VARS}}, {}) == 14)
check("need: host kinds count", Cat.need_v({kind = "enhancement", fields = {}, effects = {}, rules = {{when = "card_scored", give = {{id = "mult", n = 2, nv = 1}}}}, vars = {{name = "c"}}}) == 14)
check("format: mods and rooms read 16", Mods.V >= 16 and Room.V >= 16)

local function jcard(vals)
  return {ability = {extra = {chips = 0, mult = 0, xmult = 1, vars = vals}}, config = {center = {key = "j_forge_v"}}, T = {}, juice_up = function() end}
end
local hp = {cardarea = G.jokers, joker_main = true, full_hand = {}, scoring_hand = {}, scoring_name = "Pair", poker_hands = {}}
local rules = R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4, nv = 1}}}})
local r = R.calculate(jcard({3, 10}), hp, rules, R.clean_vars(VARS))
check("fire: +Mult reads the variable", r and r.mult_mod == 3)
local jc = jcard({7, 10})
r = R.calculate(jc, hp, rules, R.clean_vars(VARS))
check("fire: value read when it fires", r and r.mult_mod == 7)
jc.ability.extra.vars[1] = 0
r = R.calculate(jc, hp, rules, R.clean_vars(VARS))
check("fire: zero gives nothing", r == nil or r.mult_mod == nil)
check("fire: rules table untouched", rules[1].give[1].n == 4 and rules[1].give[1].nv == 1)
local fresh = {ability = {}, config = {center = {key = "j_forge_v"}}, T = {}, juice_up = function() end}
r = R.calculate(fresh, hp, rules, R.clean_vars(VARS))
check("fire: unset variable uses its start", r and r.mult_mod == 3)

G.GAME.dollars = 5
local cr = R.clean_rules({{when = "hand_played", only = {{id = "money", op = "at_least", n = 1, nv = 2}}, give = {{id = "chips", n = 20}}}})
check("cond: money at least [d] blocks", R.calculate(jcard({3, 10}), hp, cr, R.clean_vars(VARS)) == nil)
r = R.calculate(jcard({3, 4}), hp, cr, R.clean_vars(VARS))
check("cond: money at least [d] passes", r and r.chip_mod == 20)
G.GAME.dollars = 10

local xr = R.clean_rules({{when = "hand_played", give = {{id = "xmult", n = 2, nv = 1}}}})
r = R.calculate(jcard({0, 0}), hp, xr, R.clean_vars(VARS))
check("fire: X[c] at 0 is X1, not X0", r == nil or r.Xmult_mod == nil)
r = R.calculate(jcard({2.5, 0}), hp, xr, R.clean_vars(VARS))
check("fire: X[c] uses decimals", r and r.Xmult_mod == 2.5)

rnd = 0.9
local ch = R.clean_rules({{when = "hand_played", only = {{id = "chance", n = 4, nv = 1}}, give = {{id = "chips", n = 5}}}})
r = R.calculate(jcard({0, 0}), hp, ch, R.clean_vars(VARS))
check("cond: 1 in [c] at 0 is 1 in 1", r and r.chip_mod == 5)
r = R.calculate(jcard({4, 0}), hp, ch, R.clean_vars(VARS))
check("cond: 1 in [c] at 4 misses on 0.9", r == nil)
rnd = 0.01

local rt = R.clean_rules({{when = "card_scored", give = {{id = "retrigger", n = 1, nv = 1}}}})
local ace = pcard("Hearts", 14)
r = R.calculate(jcard({3, 0}), {cardarea = G.play, repetition = true, other_card = ace, full_hand = {ace}, scoring_hand = {ace}, scoring_name = "High Card", poker_hands = {}}, rt, R.clean_vars(VARS))
check("fire: retrigger [c] times", r and r.repetitions == 3)
local cs = R.clean_rules({{when = "card_scored", give = {{id = "chips", n = 5, nv = 1}}}})
r = R.calculate(jcard({12, 0}), {cardarea = G.play, individual = true, other_card = ace, full_hand = {ace}, scoring_hand = {ace}, scoring_name = "High Card", poker_hands = {}}, cs, R.clean_vars(VARS))
check("fire: card scored +[c] chips", r and r.chips == 12)

local before = log.dollars
r = R.calculate(jcard({6, 0}), {setting_blind = true, blind = {}}, R.clean_rules({{when = "blind_selected", give = {{id = "money", n = 1, nv = 1}}}}), R.clean_vars(VARS))
check("fire: money [c]", log.dollars - before == 6)

local va = R.clean_rules({{when = "hand_played", give = {{id = "var_add", var = 1, n = 1, nv = 2}}}})
local jv = jcard({1, 5})
R.calculate(jv, hp, va, R.clean_vars(VARS))
check("fire: add [d] to c", jv.ability.extra.vars[1] == 6)
local vc = R.clean_rules({{when = "hand_played", give = {{id = "var_mult", var = 1, n = 1, nv = 2}}}})
r = R.calculate(jcard({3, 2}), hp, vc, R.clean_vars(VARS))
check("fire: [d] mult for each c", r and r.mult_mod == 6)
local vv = R.clean_rules({{when = "hand_played", only = {{id = "var", var = 1, op = "at_least", n = 99, nv = 2}}, give = {{id = "mult", n = 1}}}})
check("cond: c at least [d] passes", R.calculate(jcard({5, 5}), hp, vv, R.clean_vars(VARS)) ~= nil)
check("cond: c at least [d] blocks", R.calculate(jcard({4, 5}), hp, vv, R.clean_vars(VARS)) == nil)

local ev = R.clean_rules({{when = "hand_played", only = {{id = "every", v = "event", n = 5, nv = 1}}, give = {{id = "mult", n = 1}}}})
local je = jcard({2, 0})
check("every [c]: first miss", R.calculate(je, hp, ev, R.clean_vars(VARS)) == nil)
check("every [c]: second hit", R.calculate(je, hp, ev, R.clean_vars(VARS)) ~= nil)
check("every [c]: left uses the variable", T.vars(je, R.clean_vars(VARS), nil, ev)[13] == "2")

local typed = R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4, nv = 3}}}})
r = R.calculate(jcard({1, 1, "Hearts"}), hp, typed, R.clean_vars(VARS))
check("fire: typed variable falls back to the box number", r and r.mult_mod == 4)

local hr = R.clean_rules({{when = "card_scored", give = {{id = "mult", n = 2, nv = 1}}}}, "enhancement")
check("host: card rules keep nv", hr[1].give[1].nv == 1)
put("enhancement", "venh", {{when = "card_scored", give = {{id = "mult", n = 2, nv = 1}}}}, {{name = "c", start = 9}})
local ret = score(enh_card("venh"))
check("host: enhancement +[c] Mult from its start", ret.mult == 9)
put("tarot", "vtar", {{when = "used", give = {{id = "money", n = 1, nv = 1}}}}, {{name = "c", start = 4}})
before = log.dollars
H.use(Store.get_item("vtar"))
check("host: tarot money [c]", log.dollars - before == 4)
put("voucher", "vvou", {{when = "now", give = {{id = "hand_size", n = 1, nv = 1}}}}, {{name = "c", start = 2}})
log.applied = {}
H.now(Store.get_item("vvou"), "vvou")
check("host: voucher run effect reads [c]", log.applied[1] == "hand_size:2", log.applied[1])
check("host: run spec found", R.run_num("hand_size") ~= nil)

local pr = {id = "pv", rules = {{when = "passive", give = {{id = "p_hand_size", n = 1, nv = 1}}}}, vars = {{name = "c", start = 3}}}
local info = P3.passive_of(pr)
check("passive: nv marks it live", info.var == true)
check("passive: hand size [c]", P3.want(jcard({3}), info).hand_size == 3)

local function has_name(str) return type(str) == "string" and str:find("[c]", 1, true) ~= nil and not str:find(tostring(T.NV_MARK), 1, true) end
local defs = R.clean_vars(VARS)
local gn, gbad = 0, {}
for _, id in ipairs(R.GIVE) do
  if R.NUM[id] then
    for _, when in ipairs({"hand_played", "card_scored", "passive", "blind_selected"}) do
      local cl2 = R.clean_rules({{when = when, give = {{id = id, n = R.NUM[id].def, nv = 1, var = 2, v = (R.DEFAULT_GIVE[id] and R.DEFAULT_GIVE[id]().v) or nil}}}})[1]
      local g = cl2 and cl2.give[1]
      if g and g.nv then
        gn = gn + 1
        if not has_name(T.give_text(g, "en", defs, when)) then gbad[#gbad + 1] = id .. "@" .. when .. ": " .. tostring(T.give_text(g, "en", defs, when)) end
        break
      end
    end
  end
end
check("text: every number give shows [c] (" .. gn .. ")", #gbad == 0 and gn > 30)
for _, b in ipairs(gbad) do print("  give text: " .. b) end
local on, obad = 0, {}
for _, id in ipairs(R.ONLY) do
  local key = id == "money" and "money_cond" or id
  if R.NUM[key] and R.default_only(id) and R.default_only(id).n ~= nil then
    local o = {id = id, n = R.NUM[key].def, nv = 1, op = "at_least", var = 2, v = (R.DEFAULT_ONLY[id] and R.DEFAULT_ONLY[id]().v) or nil}
    on = on + 1
    if not has_name(T.only_text(o, "en", defs)) then obad[#obad + 1] = id .. ": " .. tostring(T.only_text(o, "en", defs)) end
  end
end
check("text: every number condition shows [c] (" .. on .. ")", #obad == 0 and on > 15)
for _, b in ipairs(obad) do print("  only text: " .. b) end
local rn, rbad = 0, {}
for _, e in ipairs(H.extra_values("voucher")) do
  if e.num then
    rn = rn + 1
    local g = {id = e.id, run = true, n = e.num.def or e.num.lo, nv = 1, v = e.v and Cat.values(e.v, true)[1] or nil}
    local prev = T.cur_kind
    T.cur_kind = "voucher"
    local txt = T.give_text(g, "en", defs, "now")
    T.cur_kind = prev
    if not has_name(txt) then rbad[#rbad + 1] = e.id .. ": " .. tostring(txt) end
  end
end
check("text: every run effect number shows [c] (" .. rn .. ")", #rbad == 0 and rn > 5)
for _, b in ipairs(rbad) do print("  run text: " .. b) end
for _, l in ipairs({"fr", "es"}) do
  check("text: " .. l .. " shows [c]", has_name(T.give_text({id = "mult", n = 4, nv = 1}, l, defs)))
end
local lines = table.concat(T.lines({rules = R.clean_rules({{when = "hand_played", give = {{id = "mult", n = 4, nv = 1}}}}), vars = defs}, "en"), " ")
check("text: card shows the variable line", lines:find("+[c]", 1, true) ~= nil and lines:find("c:", 1, true) ~= nil, lines)

local raw0 = json.encode({format = "forgemod", v = 14, id = "vn0001", name = "Vars", jokers = {{id = "jv", name = "V", rarity = 1, cost = 4, mode = "advanced", vars = VARS, rules = {{when = "hand_played", only = {{id = "money", op = "at_least", n = 10, nv = 2}}, give = {{id = "mult", n = 4, nv = 1}}}}}},
  creations = {{id = "en1", kind = "enhancement", name = "E", mode = "advanced", fields = {}, effects = {}, vars = {{name = "c", start = 2}}, rules = {{when = "card_scored", give = {{id = "chips", n = 5, nv = 1}}}}}}})
local mod, err = Mods.parse(raw0)
check("share: v14 parses", mod ~= nil, err)
local mj = mod and mod.jokers[1]
check("share: joker keeps nv", mj and mj.rules[1].give[1].nv == 1 and mj.rules[1].only[1].nv == 2)
local me = mod and mod.creations[1]
check("share: host rule keeps nv", me and me.rules and me.rules[1].give[1].nv == 1)
local t15 = json.decode(raw0)
t15.v = 18
check("share: newer refused", select(2, Mods.parse(json.encode(t15))) == "newer")
local old = json.decode(Mods.for_old_server(raw0))
check("share: old server copy asks for 14", old.v == 1 and old.need == 14)
local t13 = json.decode(raw0)
t13.v = 13
local m13 = Mods.parse(json.encode(t13))
check("share: a game on 13 would refuse it", Mods.needs_v(m13 and m13.jokers or {}, m13 and m13.creations or {}) == 14)

local stored = Store.clean({id = "jx", name = "X", rarity = 1, cost = 4, vars = VARS, rules = {{when = "hand_played", give = {{id = "mult", n = 4, nv = 1}}}}})
check("store: joker keeps nv", stored.rules[1].give[1].nv == 1)

local pw = D.power({kind = "joker", vars = {{name = "c", start = 20}}, rules = {{when = "hand_played", give = {{id = "mult", n = 1, nv = 1}}}}})
check("balance: uses the variable start", math.abs(pw - 5) < 1e-9, pw)

Store.list, Store.items_list = {}, {}
Store.put({id = "rv1", name = "Room Var", rarity = 1, cost = 4, enabled = true, art = {atlas = "Joker", x = 1, y = 1}, mode = "advanced", vars = VARS, rules = {{when = "hand_played", give = {{id = "mult", n = 4, nv = 1}}}}})
local rraw = Room.pack()
local rt = rraw and json.decode(rraw)
check("room: pack asks for 14", rt and rt.room == 14 and rt.v == 14)
check("room: pack keeps nv", rt and rt.jokers[1] and rt.jokers[1].rules[1].give[1].nv == 1)
check("room: enter keeps nv", rraw and Room.enter(rraw) == true and Store.room and Store.room.jokers[1].rules[1].give[1].nv == 1)
Room.leave()
Store.list = {}
Store.put({id = "rv2", name = "Room Plain", rarity = 1, cost = 4, enabled = true, art = {atlas = "Joker", x = 1, y = 1}, rules = {{when = "hand_played", give = {{id = "mult", n = 4}}}}})
local praw = Room.pack()
check("room: plain rooms stay old", praw and json.decode(praw).room < 14)
local rt2 = rt and json.decode(rraw)
if rt2 then rt2.room = 18 end
check("room: newer room refused", rt2 and select(2, Room.enter(json.encode(rt2))) == "newer")

print(string.format("forge var numbers: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
