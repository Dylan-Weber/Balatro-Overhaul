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
local T = require("functions/forge/forge_text")
local Mods = require("functions/forge/forge_mods")
json = require("bot.sim.json")

local IDS = {"lose_money", "minus_chips", "minus_mult", "div_mult", "lose_hands", "lose_discard", "lose_hand_size", "blind_mult"}
for _, id in ipairs(IDS) do
  check("give listed: " .. id, R.member(R.GIVE, id))
  check("label: " .. id, R.LABEL_GIVE[id] ~= nil)
  local d = R.default_give(id)
  check("default amount: " .. id, d.id == id and d.n == R.NUM[id].def)
  for _, lang in ipairs({"en", "fr", "es"}) do
    local s = T.give_text({id = id, n = 3}, lang, {}, "hand_played")
    check("text " .. lang .. ": " .. id, type(s) == "string" and s:find("3", 1, true) ~= nil and not s:find("%%"))
  end
  check("version 11: " .. id, R.need_v({{when = "hand_played", only = {}, give = {{id = id, n = 3}}}}) == 11)
  check("joker host and hand trigger: " .. id, R.allowed_give("hand_played", id, "joker"))
end
check("no held -Chips", not R.allowed_give("card_held", "minus_chips", "joker"))
check("divide while held", R.allowed_give("card_held", "div_mult", "joker"))
check("lose hands not in the shop", not R.allowed_give("shop_end", "lose_hands", "joker"))
check("enhancement may take -Mult", R.allowed_give("card_scored", "minus_mult", "card"))
check("enhancement may not change the blind", not R.allowed_give("card_scored", "blind_mult", "card"))

local r = R.clean_rule({when = "hand_played", only = {}, give = {{id = "div_mult", n = 0.2}, {id = "lose_hand_size", n = 99}, {id = "minus_chips", n = -40}}}, "joker")
check("clean: divide at least /1.5", r.give[1].n == 1.5)
check("clean: hand size at most 10", r.give[2].n == 10)
check("clean: -Chips amount stays positive", r.give[3].n == 5)

check("amount: /2 is x0.5", R.AMOUNT.div_mult({n = 2}) == 0.5)
hand_chips, mult = 16, 3
check("amount: -30 Chips from 16 stops at 0", R.AMOUNT.minus_chips({n = 30}) == -16)
check("amount: -2 Mult from 3", R.AMOUNT.minus_mult({n = 2}) == -2)
hand_chips, mult = nil, nil

G.GAME.dollars = 10
G.GAME.bankrupt_at = 0
R.status = function() end
R.DOS.lose_money({n = 3})
check("lose $3", G.GAME.dollars == 7)
G.GAME.dollars = 2
R.DOS.lose_money({n = 3})
check("lose $3 from $2 stops at 0", G.GAME.dollars == 0)
G.GAME.current_round.hands_left = 3
R.DOS.lose_hands({n = 5})
check("lose hands leaves 1", log.hands == -2)
R.DOS.lose_discard({n = 5})
check("lose discards stops at 0", log.discards == -2)
R.DOS.lose_hand_size({n = 2}, nil, nil)
check("hand size waits for next round", G.GAME.forge_next_hsize == 2)
G.GAME.blind = {chips = 300, pvp = true}
number_format = function(n) return tostring(n) end
R.DOS.blind_mult({n = 2})
check("PvP blind untouched", G.GAME.blind.chips == 300)
G.GAME.blind.pvp = nil
G.STATE, G.STATES = 1, {BLIND_SELECT = 2, SHOP = 3}
R.DOS.blind_mult({n = 2})
check("blind x2", G.GAME.blind.chips == 600 and G.GAME.blind.chip_text == "600")

Store.put({id = "negj", name = "Tax Man", rarity = 1, cost = 4, enabled = true, mode = "advanced", rules = {{when = "hand_played", only = {}, give = {{id = "lose_money", n = 2}, {id = "div_mult", n = 3}}}}})
local raw, out = Mods.pack({name = "Neg pack"}, {"negj"})
check("share: file version 11", out and out.v == 11)
local mod = raw and Mods.parse(raw)
local j = mod and mod.jokers and mod.jokers[1]
check("share: gives travel", j and j.rules[1].give[1].id == "lose_money" and j.rules[1].give[2].n == 3)

print(string.format("forge negative: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
