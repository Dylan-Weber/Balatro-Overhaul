package.path = "assets/?.lua;" .. package.path
local R = require("functions/forge/forge_rules")
local T = require("functions/forge/forge_text")

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

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

local function run(rules, ctx, j, vars)
  return R.calculate(j or joker(), ctx, R.clean_rules(rules), vars)
end

reset_game()

check("new ids are in the lists", R.member(R.ONLY, "first_scored") and R.member(R.GIVE, "var_xmult") and R.member(R.GIVE, "create_rarity"))
check("version 8 for new condition", R.need_v({{when = "hand_played", only = {{id = "most_played"}}, give = {{id = "mult", n = 4}}}}) == 8)
check("version 8 for new give", R.need_v({{when = "blind_selected", give = {{id = "lose_discards"}}}}) == 8)
check("version 8 for disable_boss on sell", R.need_v({{when = "self_sold", give = {{id = "disable_boss"}}}}) == 8)
check("old disable_boss stays v3", R.need_v({{when = "blind_selected", give = {{id = "disable_boss"}}}}) == 3)
check("level_up on discard is v8", R.need_v({{when = "discard", give = {{id = "level_up"}}}}) == 8)
check("first_scored only on card_scored", not R.allowed_only("hand_played", "first_scored") and R.allowed_only("card_scored", "first_scored"))
check("lowest_held only on card_held", R.allowed_only("card_held", "lowest_held") and not R.allowed_only("card_scored", "lowest_held"))
check("used_kind only on consumable_used", R.allowed_only("consumable_used", "used_kind") and not R.allowed_only("discard", "used_kind"))
check("rank_mult not on hand_played", not R.allowed_give("hand_played", "rank_mult") and R.allowed_give("card_held", "rank_mult"))
check("disable_boss allowed on self_sold", R.allowed_give("self_sold", "disable_boss") and R.allowed_give("card_sold", "disable_boss"))
check("level_up allowed on discard", R.allowed_give("discard", "level_up"))
check("bad rank value is cleaned", R.clean_rule({when = "hand_played", only = {{id = "played_rank", v = 99}}, give = {{id = "mult", n = 1}}}).only[1].v == 14)
check("bad filter value is cleaned", R.clean_rule({when = "discard", only = {{id = "discarded", v = "zzz", n = 3}}, give = {{id = "money", n = 1}}}).only[1].v == "any")
check("bad rarity is cleaned", R.clean_rule({when = "blind_selected", give = {{id = "create_rarity", v = "Mythic", n = 2}}}).give[1].v == "Common")
check("bad seal is cleaned", R.clean_rule({when = "first_hand", give = {{id = "add_to_hand", v = "Pink"}}}).give[1].v == "random")
check("own seal kept", R.clean_rule({when = "first_hand", give = {{id = "add_to_hand", v = "Forge_abc"}}}).give[1].v == "Forge_abc")
local mapped = {{when = "first_hand", give = {{id = "add_to_hand", v = "Forge_abc"}}}}
R.map_refs(mapped, function(id) return id .. "x" end)
check("own seal ref is renamed", mapped[1].give[1].v == "Forge_abcx")

for _, lang in ipairs({"en", "fr", "es"}) do
  for _, id in ipairs(R.ONLY) do
    if R.TEXT_ONLY[id] then
      local o = R.default_only(id)
      local txt = T.only_text(o, lang, {{name = "A"}})
      check("text " .. lang .. " " .. id, type(txt) == "string" and txt ~= "" and not txt:find("%%"))
    end
  end
  for _, id in ipairs(R.GIVE) do
    if R.TEXT_GIVE[id] then
      local g = R.default_give(id)
      local txt = T.give_text(g, lang, {{name = "A"}})
      check("text " .. lang .. " " .. id, type(txt) == "string" and txt ~= "" and not txt:find("%%"))
    end
  end
  check("level up discard text " .. lang, T.sentence({when = "discard", only = {}, give = {{id = "level_up"}}}, lang) ~= T.sentence({when = "before", only = {}, give = {{id = "level_up"}}}, lang))
end
check("misprint text", T.give_text({id = "rand_mult", n = 23}, "en") == "{C:mult}+0{} to {C:mult}+23{} Mult")
check("riff-raff text", T.give_text({id = "create_rarity", v = "Common", n = 2}, "en") == "create {C:attention}2{} {C:blue}Common{} Jokers")
check("filter text", T.only_text({id = "discarded", v = "face", op = "at_least", n = 3}, "en") == "the discard has at least {C:attention}3{} face cards")

reset_game()
local held = {pcard("Spades", 9), pcard("Hearts", 4), pcard("Clubs", 4), pcard("Diamonds", 7, {enh = "m_stone"})}
G.hand.cards = held
local fist = {{when = "card_held", only = {{id = "lowest_held"}}, give = {{id = "rank_mult", n = 2}}}}
local r1 = run(fist, {cardarea = G.hand, individual = true, other_card = held[3]})
check("raised fist: lowest card (last of ties) gives 2x rank", r1 and r1.h_mult == 8)
check("raised fist: other cards give nothing", run(fist, {cardarea = G.hand, individual = true, other_card = held[2]}) == nil)
check("raised fist: stone card is skipped", run(fist, {cardarea = G.hand, individual = true, other_card = held[4]}) == nil)

reset_game()
local mis = run({{when = "hand_played", give = {{id = "rand_mult", n = 23}}}}, main({pcard("Hearts", 2)}))
check("misprint: random 0 to 23", mis and mis.mult_mod == 23 and log.rand[1] == 0 and log.rand[2] == 23)

reset_game()
local pot = {{when = "hand_played", only = {{id = "all_suits"}}, give = {{id = "xmult", n = 3}}}}
check("flower pot: four suits", (run(pot, main({pcard("Hearts", 2), pcard("Diamonds", 3), pcard("Spades", 4), pcard("Clubs", 5)})) or {}).Xmult_mod == 3)
check("flower pot: wild fills the gap", (run(pot, main({pcard("Hearts", 2), pcard("Diamonds", 3), pcard("Spades", 4), pcard("Spades", 5, {enh = "m_wild"})})) or {}).Xmult_mod == 3)
check("flower pot: three suits fail", run(pot, main({pcard("Hearts", 2), pcard("Diamonds", 3), pcard("Spades", 4), pcard("Spades", 5)})) == nil)

local sd = {{when = "hand_played", only = {{id = "suit_and_other", v = "Clubs"}}, give = {{id = "xmult", n = 2}}}}
check("seeing double: club and heart", (run(sd, main({pcard("Clubs", 2), pcard("Hearts", 2)})) or {}).Xmult_mod == 2)
check("seeing double: only clubs fail", run(sd, main({pcard("Clubs", 2), pcard("Clubs", 3)})) == nil)
check("seeing double: wild becomes club", (run(sd, main({pcard("Hearts", 2), pcard("Hearts", 3, {enh = "m_wild"})})) or {}).Xmult_mod == 2)

local sup = {{when = "hand_played", only = {{id = "played_rank", v = 14}, {id = "hand", v = "Straight", mode = "contains"}}, give = {{id = "create", v = "Tarot"}}}}
reset_game()
run(sup, main({pcard("Hearts", 14), pcard("Spades", 13)}, {poker_hands = {Straight = {{}}}}))
check("superposition: ace in straight makes a Tarot", log.created[1] and log.created[1].kind == "Tarot")
reset_game()
run(sup, main({pcard("Hearts", 10), pcard("Spades", 13)}, {poker_hands = {Straight = {{}}}}))
check("superposition: no ace no Tarot", #log.created == 0)

reset_game()
G.hand.cards = {pcard("Spades", 2), pcard("Clubs", 3)}
local bb = {{when = "hand_played", only = {{id = "held_all", v = "black"}}, give = {{id = "xmult", n = 3}}}}
check("blackboard: all black", (run(bb, main({pcard("Hearts", 2)})) or {}).Xmult_mod == 3)
G.hand.cards[3] = pcard("Hearts", 5)
check("blackboard: a heart fails", run(bb, main({pcard("Hearts", 2)})) == nil)
G.hand.cards = {}
check("blackboard: empty hand passes", (run(bb, main({pcard("Hearts", 2)})) or {}).Xmult_mod == 3)

reset_game()
local cs = {{when = "hand_played", only = {{id = "played_this_round"}}, give = {{id = "xmult", n = 3}}}}
check("card sharp: first time this round fails", run(cs, main({pcard("Hearts", 2)})) == nil)
G.GAME.hands.Pair.played_this_round = 2
check("card sharp: second time passes", (run(cs, main({pcard("Hearts", 2)})) or {}).Xmult_mod == 3)

reset_game()
local ob = {
  {when = "before", only = {{id = "most_played", neg = true}}, give = {{id = "gain_xmult", n = 0.2}}, alt = {{id = "reset_gains"}}},
}
local obj = joker("ob")
run(ob, {cardarea = G.jokers, before = true, scoring_name = "Flush", full_hand = {}, scoring_hand = {}}, obj)
run(ob, {cardarea = G.jokers, before = true, scoring_name = "Flush", full_hand = {}, scoring_hand = {}}, obj)
check("obelisk: gains on a hand that is not most played", math.abs(obj.ability.extra.xmult - 1.4) < 1e-9)
run(ob, {cardarea = G.jokers, before = true, scoring_name = "Pair", full_hand = {}, scoring_hand = {}}, obj)
check("obelisk: resets on most played", obj.ability.extra.xmult == 1)
G.GAME.hands.Flush.played = 3
check("most played needs strictly most", not R.check({id = "most_played"}, {scoring_name = "Pair"}))

reset_game()
local ramen = {
  {when = "discard", give = {{id = "var_add", var = 1, n = -1}}},
  {when = "discard", only = {{id = "var", var = 1, op = "at_most", n = 0}}, give = {{id = "destroy_self"}}},
  {when = "hand_played", give = {{id = "var_xmult", var = 1, n = 0.01}}},
}
local rv = {{name = "Ramen", start = 100}}
local rj = joker("ramen")
local hp = run(ramen, main({pcard("Hearts", 2)}), rj, rv)
check("ramen: starts at X2", hp and hp.Xmult_mod == 2)
local hand5 = {pcard("Hearts", 2), pcard("Hearts", 3), pcard("Hearts", 4), pcard("Hearts", 5), pcard("Hearts", 6)}
for _, c in ipairs(hand5) do run(ramen, {discard = true, other_card = c, full_hand = hand5}, rj, rv) end
hp = run(ramen, main({pcard("Hearts", 2)}), rj, rv)
check("ramen: X1.95 after 5 discarded", hp and math.abs(hp.Xmult_mod - 1.95) < 1e-9)

reset_game()
local green = {
  {when = "before", give = {{id = "var_add", var = 1, n = 1}}},
  {when = "discard", only = {{id = "once_per_discard"}}, give = {{id = "var_add", var = 1, n = -1}}},
  {when = "hand_played", give = {{id = "var_mult", var = 1, n = 1}}},
}
local gv = {{name = "Mult", start = 0}}
local gj = joker("green")
run(green, {cardarea = G.jokers, before = true, scoring_name = "Pair", full_hand = {}, scoring_hand = {}}, gj, gv)
run(green, {cardarea = G.jokers, before = true, scoring_name = "Pair", full_hand = {}, scoring_hand = {}}, gj, gv)
for _, c in ipairs(hand5) do run(green, {discard = true, other_card = c, full_hand = hand5}, gj, gv) end
hp = run(green, main({pcard("Hearts", 2)}), gj, gv)
check("green joker: +2 hands -1 discard = +1 Mult", hp and hp.mult_mod == 1)

reset_game()
local road = {
  {when = "discard", only = {{id = "rank", v = 11}}, give = {{id = "gain_xmult", n = 0.5}}},
  {when = "round_end", give = {{id = "reset_gains"}}},
}
local rdj = joker("road")
local jacks = {pcard("Hearts", 11), pcard("Spades", 11), pcard("Spades", 5)}
for _, c in ipairs(jacks) do run(road, {discard = true, other_card = c, full_hand = jacks}, rdj) end
hp = run(road, main({pcard("Hearts", 2)}), rdj)
check("hit the road: X2 after two Jacks", hp and hp.Xmult_mod == 2)
run(road, {end_of_round = true}, rdj)
check("hit the road: reset at round end", run(road, main({pcard("Hearts", 2)}), rdj) == nil)

reset_game()
local rocket = {
  {when = "round_end", only = {{id = "boss"}}, give = {{id = "var_add", var = 1, n = 2}}},
  {when = "round_end", give = {{id = "var_money", var = 1, n = 1}}},
}
local rkv = {{name = "Payout", start = 1}}
local rk = joker("rocket")
run(rocket, {end_of_round = true}, rk, rkv)
check("rocket: $1 on a normal round", log.dollars == 1)
G.GAME.blind.boss = true
run(rocket, {end_of_round = true}, rk, rkv)
check("rocket: $3 after the boss", log.dollars == 4)

reset_game()
G.GAME.current_round.discards_left = 3
run({{when = "blind_selected", give = {{id = "hand", n = 3}, {id = "lose_discards"}}}}, {setting_blind = true})
check("burglar: +3 hands, lose all discards", log.hands == 3 and log.discards == -3)

reset_game()
local faceless = {{when = "discard", only = {{id = "once_per_discard"}, {id = "discarded", v = "face", op = "at_least", n = 3}}, give = {{id = "money", n = 5}}}}
local faces = {pcard("Hearts", 11), pcard("Spades", 12), pcard("Spades", 13), pcard("Clubs", 2)}
for _, c in ipairs(faces) do run(faceless, {discard = true, other_card = c, full_hand = faces}, joker("fl")) end
check("faceless: $5 once for 3 faces", log.dollars == 5)
reset_game()
local two = {pcard("Hearts", 11), pcard("Spades", 12)}
for _, c in ipairs(two) do run(faceless, {discard = true, other_card = c, full_hand = two}, joker("fl")) end
check("faceless: nothing for 2 faces", log.dollars == 0)

reset_game()
local trading = {{when = "discard", only = {{id = "first_discard"}, {id = "cards_played", op = "exactly", n = 1}}, give = {{id = "destroy_card"}, {id = "money", n = 3}}}}
local one = {pcard("Hearts", 5)}
local tr = run(trading, {discard = true, other_card = one[1], full_hand = one}, joker("tc"))
check("trading card: destroy and $3", tr and tr.remove and log.dollars == 3)
G.GAME.current_round.discards_used = 1
check("trading card: not on second discard", run(trading, {discard = true, other_card = one[1], full_hand = one}, joker("tc")) == nil)

reset_game()
local chad = {{when = "card_scored", only = {{id = "first_scored"}}, give = {{id = "retrigger", n = 2}}}}
local sh = {pcard("Hearts", 5), pcard("Hearts", 6)}
local rep = R.calculate(joker("hc"), {cardarea = G.play, repetition = true, other_card = sh[1], scoring_hand = sh, full_hand = sh}, R.clean_rules(chad))
check("hanging chad: first card retriggers twice", rep and rep.repetitions == 2)
check("hanging chad: second card does not", R.calculate(joker("hc"), {cardarea = G.play, repetition = true, other_card = sh[2], scoring_hand = sh, full_hand = sh}, R.clean_rules(chad)) == nil)

local photo = {{when = "card_scored", only = {{id = "rank", v = "face"}, {id = "first_scored"}}, give = {{id = "xmult", n = 2}}}}
local ph = {pcard("Hearts", 5), pcard("Hearts", 12), pcard("Hearts", 13)}
local function scored(c) return R.calculate(joker("ph"), {cardarea = G.play, individual = true, other_card = c, scoring_hand = ph, full_hand = ph}, R.clean_rules(photo)) end
check("photograph: first face gives X2", (scored(ph[2]) or {}).x_mult == 2)
check("photograph: second face gives nothing", scored(ph[3]) == nil)
check("photograph: number card gives nothing", scored(ph[1]) == nil)

reset_game()
local const = {{when = "consumable_used", only = {{id = "used_kind", v = "Planet"}}, give = {{id = "gain_xmult", n = 0.1}}}}
local cj = joker("con")
run(const, {using_consumeable = true, consumeable = {ability = {set = "Planet"}}}, cj)
run(const, {using_consumeable = true, consumeable = {ability = {set = "Tarot"}}}, cj)
check("constellation: only Planets count", math.abs(cj.ability.extra.xmult - 1.1) < 1e-9)

reset_game()
for i = 1, 16 do G.playing_cards[i] = pcard("Hearts", 5, {enh = "m_gold"}) end
for i = 17, 30 do G.playing_cards[i] = pcard("Hearts", 5) end
local dl = {{when = "hand_played", only = {{id = "deck_count", v = "enhanced", op = "at_least", n = 16}}, give = {{id = "xmult", n = 3}}}}
check("driver's license: 16 enhanced", (run(dl, main({pcard("Hearts", 2)})) or {}).Xmult_mod == 3)
G.playing_cards[1] = pcard("Hearts", 5)
check("driver's license: 15 enhanced fails", run(dl, main({pcard("Hearts", 2)})) == nil)

reset_game()
run({{when = "blind_selected", give = {{id = "create_rarity", v = "Common", n = 2}}}}, {setting_blind = true})
check("riff-raff: two Common Jokers", #log.created == 2 and log.created[1].rarity == 0 and log.created[1].kind == "Joker")
reset_game()
G.jokers.cards = {{}, {}, {}, {}}
run({{when = "blind_selected", give = {{id = "create_rarity", v = "Rare", n = 2}}}}, {setting_blind = true})
check("create by rarity respects room", #log.created == 1 and log.created[1].rarity == 1)
reset_game()
run({{when = "blind_selected", give = {{id = "create_rarity", v = "Legendary", n = 1}}}}, {setting_blind = true})
check("legendary flag", log.created[1] and log.created[1].legendary == true)

reset_game()
rnd = 0.9
run({{when = "first_hand", give = {{id = "add_to_hand", v = "random"}}}}, {first_hand_drawn = true})
check("certificate: card with a random seal", #log.hand_added == 1 and log.hand_added[1].seal == "Red")
rnd = 0.5

reset_game()
local boss_off = false
G.GAME.blind = {boss = true, disabled = false, disable = function() boss_off = true end}
run({{when = "self_sold", give = {{id = "disable_boss"}}}}, {selling_self = true})
check("luchador: selling disables the boss", boss_off)

reset_game()
local burnt = {{when = "discard", only = {{id = "first_discard"}, {id = "once_per_discard"}}, give = {{id = "level_up"}}}}
for _, c in ipairs(two) do run(burnt, {discard = true, other_card = c, full_hand = two}, joker("bj")) end
check("burnt joker: levels the discarded hand once", log.levels == 1 and log.level_hand == "Pair")

reset_game()
local fortune = {{when = "consumable_used", only = {{id = "used_kind", v = "Tarot"}}, give = {{id = "gain_mult", n = 1}}}}
local fj = joker("ft")
run(fortune, {using_consumeable = true, consumeable = {ability = {set = "Tarot"}}}, fj)
check("fortune teller: +1 Mult per Tarot", fj.ability.extra.mult == 1)

reset_game()
local nd = {{when = "round_end", only = {{id = "no_discard"}}, give = {{id = "money", n = 2}}}}
run(nd, {end_of_round = true})
check("no discard used passes", log.dollars == 2)
G.GAME.current_round.discards_used = 1
run(nd, {end_of_round = true})
check("discard used fails", log.dollars == 2)

reset_game()
check("per gives are v8", R.need_v({{when = "hand_played", give = {{id = "mult_per", n = 3, per = "jokers"}}}}) == 8)
check("bad count is cleaned", R.clean_rule({when = "hand_played", give = {{id = "mult_per", n = 3, per = "nope"}}}).give[1].per == "jokers")
check("count not allowed for trigger is cleaned", R.clean_rule({when = "round_end", give = {{id = "money_per", n = 1, per = "scoring_match", m = "face"}}}).give[1].per == "jokers")
check("filter kept for match counts", R.clean_rule({when = "hand_played", give = {{id = "xmult_per", n = 0.2, per = "deck_match", m = "m_steel"}}}).give[1].m == "m_steel")
check("filter dropped for other counts", R.clean_rule({when = "hand_played", give = {{id = "mult_per", n = 3, per = "jokers", m = "m_steel"}}}).give[1].m == nil)
check("per field not kept on plain gives", R.clean_rule({when = "hand_played", give = {{id = "mult", n = 3, per = "jokers"}}}).give[1].per == nil)
check("steel text", T.give_text({id = "xmult_per", n = 0.2, per = "deck_match", m = "m_steel"}, "en") == "{X:mult,C:white} X0.2 {} Mult for each {C:attention}m_steel{} in your {C:attention}full deck{}" or T.give_text({id = "xmult_per", n = 0.2, per = "deck_match", m = "m_steel"}, "en"):find("full deck", 1, true) ~= nil)
for _, lang in ipairs({"en", "fr", "es"}) do
  for _, per in ipairs(R.COUNTS) do
    for id in pairs(R.PER_GIVE) do
      local txt = T.give_text({id = id, n = 2, per = per, m = "face"}, lang)
      check("per text " .. lang .. " " .. id .. " " .. per, type(txt) == "string" and txt ~= "" and not txt:find("%%"))
    end
  end
end

local function score(rules, hand, extra, j)
  return run(rules, main(hand or {pcard("Hearts", 2)}, extra), j) or {}
end

reset_game()
G.jokers.cards = {joker("a"), joker("b")}
check("joker stencil: X4 with 3 empty slots", score({{when = "hand_played", give = {{id = "xmult_per", n = 1, per = "empty_slots"}}}}).Xmult_mod == 4)
check("abstract joker: +6 Mult with 2 Jokers", score({{when = "hand_played", give = {{id = "mult_per", n = 3, per = "jokers"}}}}).mult_mod == 6)
G.GAME.current_round.discards_left = 3
check("banner: +90 Chips with 3 discards", score({{when = "hand_played", give = {{id = "chips_per", n = 30, per = "discards_left"}}}}).chip_mod == 90)
G.deck = {cards = {1, 2, 3, 4, 5}}
check("blue joker: +10 Chips with 5 cards left", score({{when = "hand_played", give = {{id = "chips_per", n = 2, per = "deck_left"}}}}).chip_mod == 10)
for i = 1, 4 do G.playing_cards[i] = pcard("Hearts", 9, {enh = "m_steel"}) end
G.playing_cards[5] = pcard("Spades", 9)
G.playing_cards[6] = pcard("Spades", 5, {enh = "m_stone"})
G.P_CENTERS.m_stone = {key = "m_stone"}
G.playing_cards[6].config.center = G.P_CENTERS.m_stone
check("steel joker: X1.8 with 4 Steel", math.abs((score({{when = "hand_played", give = {{id = "xmult_per", n = 0.2, per = "deck_match", m = "m_steel"}}}}).Xmult_mod or 0) - 1.8) < 1e-9)
check("stone joker: +25 per Stone", score({{when = "hand_played", give = {{id = "chips_per", n = 25, per = "deck_match", m = "m_stone"}}}}).chip_mod == 25)
run({{when = "round_end", give = {{id = "money_per", n = 1, per = "deck_match", m = 9}}}}, {end_of_round = true})
check("cloud 9: $5 for five 9s", log.dollars == 5)
G.GAME.starting_deck_size = 10
check("erosion: +4 per card below start", score({{when = "hand_played", give = {{id = "mult_per", n = 4, per = "below_deck"}}}}).mult_mod == 16)
G.GAME.dollars = 23
check("bull: +2 Chips per $1", score({{when = "hand_played", give = {{id = "chips_per", n = 2, per = "money"}}}}).chip_mod == 46)
check("bootstraps: +2 Mult per $5", score({{when = "hand_played", give = {{id = "mult_per", n = 2, per = "money_5"}}}}).mult_mod == 8)
G.GAME.dollars = -5
check("bull: nothing in debt", score({{when = "hand_played", give = {{id = "chips_per", n = 2, per = "money"}}}}).chip_mod == nil)
local me = joker("sw")
G.jokers.cards = {me, joker("x"), joker("y")}
G.jokers.cards[2].sell_cost, G.jokers.cards[3].sell_cost, me.sell_cost = 3, 4, 9
check("swashbuckler: Mult = other Jokers' sell value", score({{when = "hand_played", give = {{id = "mult_per", n = 1, per = "sell_others"}}}}, nil, nil, me).mult_mod == 7)
G.GAME.hands.Pair.played = 6
check("supernova: Mult = times played", score({{when = "hand_played", give = {{id = "mult_per", n = 1, per = "times_played"}}}}).mult_mod == 6)
G.GAME.consumeable_usage = {c_mars = {set = "Planet", count = 3}, c_venus = {set = "Planet", count = 1}, c_fool = {set = "Tarot", count = 2}}
reset_game()
G.GAME.consumeable_usage = {c_mars = {set = "Planet", count = 3}, c_venus = {set = "Planet", count = 1}, c_fool = {set = "Tarot", count = 2}}
run({{when = "round_end", give = {{id = "money_per", n = 1, per = "planets_used"}}}}, {end_of_round = true})
check("satellite: $2 for two Planets", log.dollars == 2)
reset_game()
G.GAME.current_round.discards_left = 3
run({{when = "round_end", only = {{id = "no_discard"}}, give = {{id = "money_per", n = 2, per = "discards_left"}}}}, {end_of_round = true})
check("delayed gratification: $6 with 3 discards unused", log.dollars == 6)

reset_game()
G.P_CENTERS.m_glass = {key = "m_glass"}
local gj2 = joker("glass")
local glass = {{when = "cards_destroyed", give = {{id = "gain_xmult_per", n = 0.75, per = "destroyed_match", m = "m_glass"}}}}
run(glass, {remove_playing_cards = true, removed = {pcard("Hearts", 5, {enh = "m_glass"}), pcard("Hearts", 6, {enh = "m_glass"}), pcard("Hearts", 7)}}, gj2)
check("glass joker: X2.5 after two Glass break", math.abs(gj2.ability.extra.xmult - 2.5) < 1e-9)
local cj2 = joker("canio")
run({{when = "cards_destroyed", give = {{id = "gain_xmult_per", n = 1, per = "destroyed_match", m = "face"}}}}, {remove_playing_cards = true, removed = {pcard("Hearts", 12), pcard("Hearts", 6)}}, cj2)
check("canio: X2 after a face card is destroyed", cj2.ability.extra.xmult == 2)

reset_game()
local vj = joker("vamp")
local vh = {pcard("Hearts", 5, {enh = "m_gold"}), pcard("Hearts", 6, {enh = "m_steel"}), pcard("Hearts", 7), pcard("Hearts", 8, {enh = "m_gold", debuff = true})}
for _, c in ipairs(vh) do c.set_ability = function(self, center) self.config.center = center end end
local vamp = {{when = "before", give = {{id = "gain_xmult_per", n = 0.1, per = "scoring_match", m = "enhanced"}, {id = "strip_enh"}}}}
run(vamp, {cardarea = G.jokers, before = true, scoring_hand = vh, full_hand = vh, scoring_name = "Pair"}, vj)
check("vampire: X1.2 from two enhanced cards", math.abs(vj.ability.extra.xmult - 1.2) < 1e-9)
check("vampire: enhancements removed, debuffed kept", vh[1].config.center.key == "c_base" and vh[2].config.center.key == "c_base" and vh[4].config.center.key == "m_gold")

reset_game()
G.STAGES = {RUN = 1}
G.STAGE = 1
G.GAME.round = 3
G.GAME.hands.Pair.visible, G.GAME.hands.Flush.visible = true, true
G.playing_cards = {pcard("Diamonds", 7), pcard("Clubs", 12)}
local t1 = R.round_target()
check("target: suit picked", R.member(R.FOUR_SUITS, t1.suit))
check("target: rank from the deck", t1.rank == 7 and t1.card.rank == 7 and t1.card.suit == "Diamonds")
check("target: same within the round", R.round_target() == t1)
G.GAME.round = 4
local t2 = R.round_target()
check("target: suit changes next round", t2 ~= t1 and t2.suit ~= t1.suit)
check("target: hand changes next round", t2.hand ~= t1.hand)
local tv = T.vars(nil, {})
check("target vars 9 to 12", tv[9] ~= nil and tv[10] ~= nil and tv[11] ~= nil and tv[12] ~= nil)
check("target text uses var", T.only_text({id = "round_suit"}, "en"):find("#9#", 1, true) ~= nil)
local lines = T.lines({rules = R.clean_rules({{when = "card_scored", only = {{id = "round_suit"}}, give = {{id = "xmult", n = 1.5}}}})}, "en")
check("target text says it changes", lines[#lines] == "{C:inactive}(Changes every round){}")
for _, lang in ipairs({"en", "fr", "es"}) do
  for _, id in ipairs({"round_suit", "round_rank", "round_card", "round_hand"}) do check("target text " .. lang .. " " .. id, T.only_text({id = id}, lang) ~= "") end
end
check("round targets are v8", R.need_v({{when = "card_scored", only = {{id = "round_card"}}, give = {{id = "xmult", n = 2}}}}) == 8)
check("round_hand not on discard", not R.allowed_only("discard", "round_hand"))

local t = R.round_target()
local function sc(rules, c, j) return R.calculate(j or joker("tg"), {cardarea = G.play, individual = true, other_card = c, scoring_hand = {c}, full_hand = {c}}, R.clean_rules(rules)) end
local ancient = {{when = "card_scored", only = {{id = "round_suit"}}, give = {{id = "xmult", n = 1.5}}}}
check("ancient joker: X1.5 on this round's suit", (sc(ancient, pcard(t.suit, 5)) or {}).x_mult == 1.5)
local other_suit = t.suit == "Hearts" and "Spades" or "Hearts"
check("ancient joker: nothing on other suits", sc(ancient, pcard(other_suit, 5)) == nil)
local idol = {{when = "card_scored", only = {{id = "round_card"}}, give = {{id = "xmult", n = 2}}}}
check("the idol: X2 on this round's card", (sc(idol, pcard(t.card.suit, t.card.rank)) or {}).x_mult == 2)
check("the idol: nothing on same rank other suit", sc(idol, pcard(t.card.suit == "Hearts" and "Spades" or "Hearts", t.card.rank)) == nil)
log.dollars = 0
local mail = {{when = "discard", only = {{id = "round_rank"}}, give = {{id = "money", n = 5}}}}
local md = {pcard("Hearts", t.rank), pcard("Spades", t.rank), pcard("Spades", 2)}
for _, c in ipairs(md) do run(mail, {discard = true, other_card = c, full_hand = md}, joker("mail")) end
check("mail-in rebate: $5 per card of this round's rank", log.dollars == 10)
local castle = {{when = "discard", only = {{id = "round_suit"}}, give = {{id = "gain_chips", n = 3}}}}
local cjj = joker("castle")
local cd = {pcard(t.suit, 3), pcard(t.suit, 4), pcard(other_suit, 5)}
for _, c in ipairs(cd) do run(castle, {discard = true, other_card = c, full_hand = cd}, cjj) end
check("castle: +6 Chips after two cards of the suit", (run(castle, main({pcard("Hearts", 2)}), cjj) or {}).chip_mod == 6)
log.dollars = 0
local todo = {{when = "before", only = {{id = "round_hand"}}, give = {{id = "money", n = 4}}}}
run(todo, {cardarea = G.jokers, before = true, scoring_name = t.hand, full_hand = {}, scoring_hand = {}})
check("to do list: $4 on this round's hand", log.dollars == 4)
run(todo, {cardarea = G.jokers, before = true, scoring_name = t.hand == "Pair" and "Flush" or "Pair", full_hand = {}, scoring_hand = {}})
check("to do list: nothing on other hands", log.dollars == 4)
G.STAGE = 0
G.GAME.round = 9
check("no target stored outside a run", R.round_target().round == 9 and G.GAME.forge_target.round == 4)

local function kept(kind, when, give)
  local c = R.clean_rule({when = when, give = {give}}, kind)
  return c ~= nil and #c.give == 1
end
check("host: random Mult on an enhancement", kept("enhancement", "card_scored", {id = "rand_mult", n = 5}))
check("host: Mult per Joker on a voucher", kept("voucher", "hand_played", {id = "mult_per", n = 2, per = "jokers"}))
check("host: money per hand played on a tag", kept("tag", "now", {id = "money_per", n = 1, per = "hands_run"}) or kept("tag", "used", {id = "money_per", n = 1, per = "hands_run"}))
check("host: remove enhancements not on a seal", not kept("seal", "before", {id = "strip_enh"}))
check("host: rank Mult not on a voucher", not kept("voucher", "card_scored", {id = "rank_mult", n = 2}))

reset_game()
local lc = joker("lucky")
local lucky = {{when = "card_scored", only = {{id = "lucky_hit"}}, give = {{id = "gain_xmult", n = 0.25}}}}
local lcard = pcard("Hearts", 5, {enh = "m_lucky"})
R.calculate(lc, {cardarea = G.play, individual = true, other_card = lcard, scoring_hand = {lcard}, full_hand = {lcard}}, R.clean_rules(lucky))
check("lucky cat: nothing when the Lucky roll fails", lc.ability.extra.xmult == 1)
lcard.lucky_trigger = true
R.calculate(lc, {cardarea = G.play, individual = true, other_card = lcard, scoring_hand = {lcard}, full_hand = {lcard}}, R.clean_rules(lucky))
check("lucky cat: X0.25 when it triggers", lc.ability.extra.xmult == 1.25)
local mat = {{when = "hand_played", only = {{id = "boss_triggered"}}, give = {{id = "money", n = 8}}}}
run(mat, main({pcard("Hearts", 2)}))
check("matador: nothing without a boss trigger", log.dollars == 0)
G.GAME.blind = {boss = true, triggered = true}
run(mat, main({pcard("Hearts", 2)}))
check("matador: $8 when the boss ability triggers", log.dollars == 8)
for _, lang in ipairs({"en", "fr", "es"}) do check("lucky text " .. lang, T.only_text({id = "lucky_hit"}, lang) ~= "" and T.only_text({id = "boss_triggered"}, lang) ~= "") end

print(string.format("forge blocks: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
