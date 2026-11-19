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
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end
local log
local rnd = 0.5
local function reset_game()
  log = {dollars = 0, hands = 0, discards = 0, levels = 0, created = {}, status = {}, hand_added = {}}
  G = {
    play = {name = "play"},
    hand = {name = "hand", cards = {}, sort = function() end},
    jokers = {cards = {}, config = {card_limit = 5}, emplace = function(self, c) self.cards[#self.cards + 1] = c end},
    consumeables = {cards = {}, config = {card_limit = 2}, emplace = function(self, c) self.cards[#self.cards + 1] = c end},
    GAME = {dollars = 10, probabilities = {normal = 1}, current_round = {hands_left = 3, discards_left = 2, hands_played = 0, discards_used = 0}, round_resets = {ante = 2}, blind = {boss = false, debuff_card = function() end}, joker_buffer = 0, consumeable_buffer = 0,
      hands = {Pair = {played = 3, played_this_round = 1, visible = true, level = 1}, Flush = {played = 1, played_this_round = 0, visible = true, level = 1}, ["High Card"] = {played = 2, played_this_round = 0, visible = true, level = 1}}},
    C = {MONEY = {}, MULT = {}, CHIPS = {}, BLUE = {}, RED = {}, FILTER = {}, SECONDARY_SET = {Planet = {}, Tarot = {}, Spectral = {}, Enhanced = {}}},
    E_MANAGER = {add_event = function(_, e) e.func() end},
    P_CENTERS = {c_base = {key = "c_base"}, m_gold = {key = "m_gold"}, m_glass = {key = "m_glass"}, m_steel = {key = "m_steel"}},
    P_CARDS = {H_K = {suit = "Hearts", value = "King"}},
    FUNCS = {get_poker_hand_info = function(cards) return #cards >= 2 and "Pair" or "High Card", nil, {} end},
  }
  G.playing_cards = {}
end
Event = function(t) return t end
localize = function(a)
  if type(a) == "table" then return a.key .. ":" .. table.concat(a.vars or {}, ",") end
  return a
end
card_eval_status_text = function(card, kind, amt, pct, dir, extra) log.status[#log.status + 1] = extra and extra.message end
ease_dollars = function(n) log.dollars = log.dollars + n end
ease_hands_played = function(n) log.hands = log.hands + n end
ease_discard = function(n) log.discards = log.discards + n end
level_up_hand = function(card, hand) log.levels = log.levels + 1; log.level_hand = hand end
play_sound = function() end
pseudorandom = function(seed, lo, hi) if lo then log.rand = {lo, hi} return hi end return rnd end
pseudoseed = function(s) return s end
pseudorandom_element = function(t) return next(t) and t[next(t)] end
create_card = function(kind, area, legendary, rarity)
  log.created[#log.created + 1] = {kind = kind, legendary = legendary, rarity = rarity}
  return {add_to_deck = function() end, start_materialize = function() end}
end

local NOMINAL = {[14] = 11, [13] = 10, [12] = 10, [11] = 10}
local function pcard(suit, id, o)
  o = o or {}
  local c = {base = {suit = suit, id = id, nominal = NOMINAL[id] or id}, config = {center = G.P_CENTERS[o.enh or "c_base"] or {key = o.enh}}, seal = o.seal, debuff = o.debuff, ability = {name = o.enh == "m_wild" and "Wild Card" or "Default Base", effect = o.enh == "m_stone" and "Stone Card" or ""}}
  function c:get_id() return self.base.id end
  function c:is_face() return self.base.id >= 11 and self.base.id <= 13 end
  function c:is_suit(s) return self.ability.name == "Wild Card" or self.base.suit == s end
  function c:set_seal(s) self.seal = s end
  function c:juice_up() end
  return c
end
create_playing_card = function(t, area)
  local c = pcard("Hearts", 13)
  log.hand_added[#log.hand_added + 1] = c
  return c
end
playing_card_joker_effects = function() end

local function joker(id)
  local j = {ability = {extra = {chips = 0, mult = 0, xmult = 1}}, config = {center = {forge_id = id or "t1", key = "j_forge_t1"}}, T = {}, children = {center = {pinch = {}}}, states = {drag = {}}}
  function j:juice_up() end
  function j:remove() self.removed = true end
  j.area = {remove_card = function() end}
  return j
end

local function main(hand, extra)
  local c = {cardarea = G.jokers, joker_main = true, full_hand = hand, scoring_hand = hand, scoring_name = "Pair", poker_hands = {Pair = {{}}}}
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local T = require("functions/forge/forge_text")
local Mods = require("functions/forge/forge_mods")
json = require("bot.sim.json")

reset_game()
R.status = function() end

local TWINS = {lose_money_per = "money_per", minus_chips_per = "chips_per", minus_mult_per = "mult_per", var_lose_money = "var_money", var_minus_chips = "var_chips", var_minus_mult = "var_mult"}
local vars = {{name = "Tax", start = 2}}
for id, pos in pairs(TWINS) do
  local var = R.VAR_GIVE[id]
  check("listed: " .. id, R.member(R.GIVE, id))
  check("label: " .. id, R.LABEL_GIVE[id] ~= nil)
  check("var flag matches twin: " .. id, (R.VAR_GIVE[id] and true or false) == (R.VAR_GIVE[pos] and true or false))
  check("per flag matches twin: " .. id, (R.PER_GIVE[id] and true or false) == (R.PER_GIVE[pos] and true or false))
  local g = var and {id = id, n = 3, var = 1} or {id = id, n = 3, per = "jokers"}
  for _, lang in ipairs({"en", "fr", "es"}) do
    local s = T.give_text(g, lang, vars, "hand_played")
    check("text " .. lang .. ": " .. id, type(s) == "string" and s:find("3", 1, true) ~= nil and not s:find("%%") and (var and s:find("Tax", 1, true) ~= nil or not var and s:lower():find("joker", 1, true) ~= nil))
  end
  check("version 16: " .. id, R.need_v({{when = "hand_played", only = {}, give = {g}}}, vars) == 16)
  check("hand trigger: " .. id, R.allowed_give("hand_played", id, "joker"))
  for _, host in ipairs({"card", "run"}) do
    check(host .. " host like twin: " .. id, R.allowed_give("hand_played", id, host) == R.allowed_give("hand_played", pos, host))
  end
end
check("lose money text en", T.give_text({id = "lose_money_per", n = 2, per = "discards_left"}, "en", {}, "round_end"):find("lose", 1, true) ~= nil)
check("tarot count text", T.give_text({id = "lose_money_per", n = 1, per = "tarots_used"}, "en", {}, "round_end"):find("Tarot", 1, true) ~= nil)
check("default per", R.default_give("lose_money_per").per ~= nil)
check("no held -Chips for each", not R.allowed_give("card_held", "minus_chips_per", "joker"))
check("held -Mult for each", R.allowed_give("card_held", "minus_mult_per", "joker"))
check("lose money for each on round end", R.allowed_give("round_end", "lose_money_per", "joker") and R.allowed_give("round_end", "var_lose_money", "joker"))

local alt = R.clean_rules({{when = "round_end", only = {{id = "boss"}}, give = {{id = "money_per", n = 1, per = "jokers"}}, alt = {{id = "lose_money_per", n = 2, per = "jokers"}}}})
check("otherwise lose money for each: kept", alt[1].alt and alt[1].alt[1].id == "lose_money_per" and alt[1].alt[1].per == "jokers" and alt[1].alt[1].n == 2)
local va = R.clean_rules({{when = "round_end", only = {{id = "boss"}}, give = {{id = "var_money", n = 1, var = 1}}, alt = {{id = "var_lose_money", n = 1, var = 1}}}}, vars)
check("otherwise lose money for each point: kept", va[1].alt and va[1].alt[1].id == "var_lose_money" and va[1].alt[1].var == 1)

G.jokers.cards = {joker("a"), joker("b"), joker("c")}
G.GAME.dollars = 20
G.GAME.blind.boss = false
log.dollars = 0
R.calculate(joker(), {end_of_round = true, cardarea = G.jokers}, alt)
check("otherwise: lose $2 for each of 3 Jokers", log.dollars == -6)
G.GAME.blind.boss = true
log.dollars = 0
R.calculate(joker(), {end_of_round = true, cardarea = G.jokers}, alt)
check("boss: gain $1 for each of 3 Jokers", log.dollars == 3)
G.GAME.blind.boss = false
G.GAME.dollars = 4
log.dollars = 0
R.calculate(joker(), {end_of_round = true, cardarea = G.jokers}, alt)
check("lose goes into debt like Rental", log.dollars == -6)

local vj = joker()
vj.ability.extra.vars = {5}
G.GAME.dollars = 20
log.dollars = 0
R.calculate(vj, {end_of_round = true, cardarea = G.jokers}, va, vars)
check("otherwise: lose $1 for each of 5 points", log.dollars == -5)

hand_chips, mult = 100, 10
local mc = R.calculate(joker(), main({}), R.clean_rules({{when = "hand_played", give = {{id = "minus_chips_per", n = 4, per = "jokers"}, {id = "minus_mult_per", n = 2, per = "jokers"}}}}))
check("-4 Chips and -2 Mult for each of 3 Jokers", mc and mc.chip_mod == -12 and mc.mult_mod == -6)
local vj2 = joker()
vj2.ability.extra.vars = {5}
local vm = R.calculate(vj2, main({}), R.clean_rules({{when = "hand_played", give = {{id = "var_minus_chips", n = 30, var = 1}, {id = "var_minus_mult", n = 3, var = 1}}}}, vars), vars)
check("-Chips for each point stops at current chips, -Mult for each point", vm and vm.chip_mod == -100 and vm.mult_mod == -10)
hand_chips, mult = nil, nil

Store.put({id = "twinj", name = "Tax Man", rarity = 1, cost = 4, enabled = true, mode = "advanced", vars = vars, rules = alt})
local raw, out = Mods.pack({name = "Twin pack"}, {"twinj"})
check("share: file version 16", out and out.v == 16)
local mod = raw and Mods.parse(raw)
local j = mod and mod.jokers and mod.jokers[1]
check("share: otherwise travels", j and j.rules[1].alt and j.rules[1].alt[1].id == "lose_money_per" and j.rules[1].alt[1].per == "jokers")
local saved = Store.get and Store.get("twinj")
check("save: kept after store", saved == nil or (saved.rules[1].alt and saved.rules[1].alt[1].id == "lose_money_per"))

print(string.format("forge twins: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
