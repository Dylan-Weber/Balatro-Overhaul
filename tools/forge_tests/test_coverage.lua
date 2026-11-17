package.path = "assets/?.lua;" .. package.path
mod_loc = function(s) return s end
G = {}
local Cat = require("functions/forge/forge_catalog")
local R = require("functions/forge/forge_rules")

local fails, total = 0, 0
local function check(name, ok, got)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (got ~= nil and (" got: " .. tostring(got)) or "")) end
end

local function W(when, only, give, alt) return {when = when, only = only or {}, give = give, alt = alt} end
local function g(id, n, v) return {id = id, n = n, v = v} end
local function o(id, v, op, n) return {id = id, v = v, op = op, n = n} end
local function hand(v) return {id = "hand", v = v, mode = "contains"} end
local function chance(n) return {id = "chance", n = n} end
local function var(op, n) return {id = "var", var = 1, op = op, n = n} end
local function vadd(n) return {id = "var_add", var = 1, n = n} end
local function per(id, p, n, m) return {id = id, per = p, n = n, m = m} end
local function pas(...) return {W("passive", nil, {...})} end
local function V(name, start) return {{name = name, start = start}} end

local J = {
  {"Joker", {W("hand_played", nil, {g("mult", 4)})}, want = {"main", "High Card", "mult_mod", 4}},
  {"Greedy Joker", {W("card_scored", {o("suit", "Diamonds")}, {g("mult", 3)})}, want = {"scored", "D_5", "mult", 3}},
  {"Lusty Joker", {W("card_scored", {o("suit", "Hearts")}, {g("mult", 3)})}, want = {"scored", "H_5", "mult", 3}},
  {"Wrathful Joker", {W("card_scored", {o("suit", "Spades")}, {g("mult", 3)})}, want = {"scored", "S_5", "mult", 3}},
  {"Gluttonous Joker", {W("card_scored", {o("suit", "Clubs")}, {g("mult", 3)})}, want = {"scored", "C_5", "mult", 3}},
  {"Jolly Joker", {W("hand_played", {hand("Pair")}, {g("mult", 8)})}, want = {"main", "Pair", "mult_mod", 8}},
  {"Zany Joker", {W("hand_played", {hand("Three of a Kind")}, {g("mult", 12)})}, want = {"main", "Three of a Kind", "mult_mod", 12}},
  {"Mad Joker", {W("hand_played", {hand("Two Pair")}, {g("mult", 10)})}, want = {"main", "Two Pair", "mult_mod", 10}},
  {"Crazy Joker", {W("hand_played", {hand("Straight")}, {g("mult", 12)})}, want = {"main", "Straight", "mult_mod", 12}},
  {"Droll Joker", {W("hand_played", {hand("Flush")}, {g("mult", 10)})}, want = {"main", "Flush", "mult_mod", 10}},
  {"Sly Joker", {W("hand_played", {hand("Pair")}, {g("chips", 50)})}, want = {"main", "Pair", "chip_mod", 50}},
  {"Wily Joker", {W("hand_played", {hand("Three of a Kind")}, {g("chips", 100)})}, want = {"main", "Three of a Kind", "chip_mod", 100}},
  {"Clever Joker", {W("hand_played", {hand("Two Pair")}, {g("chips", 80)})}, want = {"main", "Two Pair", "chip_mod", 80}},
  {"Devious Joker", {W("hand_played", {hand("Straight")}, {g("chips", 100)})}, want = {"main", "Straight", "chip_mod", 100}},
  {"Crafty Joker", {W("hand_played", {hand("Flush")}, {g("chips", 80)})}, want = {"main", "Flush", "chip_mod", 80}},
  {"Half Joker", {W("hand_played", {o("cards_played", nil, "at_most", 3)}, {g("mult", 20)})}, want = {"main", "Pair", "mult_mod", 20}},
  {"Joker Stencil", {W("hand_played", nil, {per("xmult_per", "empty_slots", 1)})}},
  {"Four Fingers", pas(g("p_rule", nil, "four_fingers"))},
  {"Mime", {W("card_held", nil, {g("retrigger", 1)})}},
  {"Credit Card", pas(g("p_debt", 20))},
  {"Ceremonial Dagger", {W("blind_selected", nil, {g("dagger", 2, "right")})}},
  {"Banner", {W("hand_played", nil, {per("chips_per", "discards_left", 30)})}},
  {"Mystic Summit", {W("hand_played", {o("discards_left", nil, "exactly", 0)}, {g("mult", 15)})}},
  {"Marble Joker", {W("blind_selected", nil, {g("add_card", nil, "m_stone")})}},
  {"Loyalty Card", {W("hand_played", {var("at_least", 5)}, {g("xmult", 4), {id = "var_set", var = 1, n = 0}}, {vadd(1)})}, V("Hands", 0)},
  {"8 Ball", {W("card_scored", {o("rank", 8), chance(4)}, {g("create", nil, "Tarot")})}},
  {"Misprint", {W("hand_played", nil, {g("rand_mult", 23)})}},
  {"Dusk", {W("card_scored", {o("last_hand")}, {g("retrigger", 1)})}},
  {"Raised Fist", {W("card_held", {o("lowest_held")}, {g("rank_mult", 2)})}},
  {"Chaos the Clown", pas(g("p_free_rerolls", 1))},
  {"Fibonacci", {W("card_scored", {o("rank", 14)}, {g("mult", 8)}), W("card_scored", {o("rank", 2)}, {g("mult", 8)}), W("card_scored", {o("rank", 3)}, {g("mult", 8)}), W("card_scored", {o("rank", 5)}, {g("mult", 8)}), W("card_scored", {o("rank", 8)}, {g("mult", 8)})}, want = {"scored", "S_8", "mult", 8}},
  {"Steel Joker", {W("hand_played", nil, {per("xmult_per", "deck_match", 0.2, "m_steel")})}},
  {"Scary Face", {W("card_scored", {o("rank", "face")}, {g("chips", 30)})}, want = {"scored", "S_K", "chips", 30}},
  {"Abstract Joker", {W("hand_played", nil, {per("mult_per", "jokers", 3)})}},
  {"Delayed Gratification", {W("round_end", {o("no_discard")}, {per("money_per", "discards_left", 2)})}},
  {"Hack", {W("card_scored", {o("rank", 2)}, {g("retrigger", 1)}), W("card_scored", {o("rank", 3)}, {g("retrigger", 1)}), W("card_scored", {o("rank", 4)}, {g("retrigger", 1)}), W("card_scored", {o("rank", 5)}, {g("retrigger", 1)})}},
  {"Pareidolia", pas(g("p_rule", nil, "pareidolia"))},
  {"Gros Michel", {W("hand_played", nil, {g("mult", 15)}), W("round_end", {chance(6)}, {g("destroy_self")})}},
  {"Even Steven", {W("card_scored", {o("rank", "even")}, {g("mult", 4)})}, want = {"scored", "H_8", "mult", 4}},
  {"Odd Todd", {W("card_scored", {o("rank", "odd")}, {g("chips", 31)})}, want = {"scored", "H_9", "chips", 31}},
  {"Scholar", {W("card_scored", {o("rank", 14)}, {g("chips", 20), g("mult", 4)})}, want = {"scored", "H_A", "chips", 20}},
  {"Business Card", {W("card_scored", {o("rank", "face"), chance(2)}, {g("money", 2)})}},
  {"Supernova", {W("hand_played", nil, {per("mult_per", "times_played", 1)})}},
  {"Ride the Bus", {W("before", {{id = "played_rank", v = "face", neg = true}}, {vadd(1)}), W("before", {o("played_rank", "face")}, {{id = "var_set", var = 1, n = 0}}), W("hand_played", nil, {{id = "var_mult", var = 1, n = 1}})}, V("Streak", 0)},
  {"Space Joker", {W("hand_played", {chance(4)}, {g("level_up")})}},
  {"Egg", {W("round_end", nil, {g("sell_value", 3)})}},
  {"Burglar", {W("blind_selected", nil, {g("hand", 3), g("lose_discards")})}},
  {"Blackboard", {W("hand_played", {o("held_all", "black")}, {g("xmult", 3)})}},
  {"Runner", {W("before", {hand("Straight")}, {g("gain_chips", 15)})}},
  {"Ice Cream", {W("hand_played", nil, {{id = "var_chips", var = 1, n = 5}}), W("after", nil, {vadd(-1)}), W("after", {var("at_most", 0)}, {g("destroy_self")})}, V("Left", 20)},
  {"DNA", {W("card_scored", {o("first_hand"), o("cards_played", nil, "exactly", 1)}, {g("copy_card", nil, "hand")})}},
  {"Splash", pas(g("p_rule", nil, "splash"))},
  {"Blue Joker", {W("hand_played", nil, {per("chips_per", "deck_left", 2)})}},
  {"Sixth Sense", {W("card_scored", {o("first_hand"), o("cards_played", nil, "exactly", 1), o("rank", 6)}, {g("destroy_card"), g("create", nil, "Spectral")})}},
  {"Constellation", {W("consumable_used", {o("used_kind", "Planet")}, {g("gain_xmult", 0.1)})}},
  {"Hiker", {W("card_scored", nil, {g("perma_chips", 5)})}},
  {"Faceless Joker", {W("discard", {o("once_per_discard"), o("discarded", "face", "at_least", 3)}, {g("money", 5)})}},
  {"Green Joker", {W("before", nil, {vadd(1)}), W("discard", {o("once_per_discard"), var("at_least", 1)}, {vadd(-1)}), W("hand_played", nil, {{id = "var_mult", var = 1, n = 1}})}, V("Mult", 0)},
  {"Superposition", {W("hand_played", {o("played_rank", 14), hand("Straight")}, {g("create", nil, "Tarot")})}},
  {"To Do List", {W("hand_played", {o("round_hand")}, {g("money", 4)})}},
  {"Cavendish", {W("hand_played", nil, {g("xmult", 3)}), W("round_end", {chance(1000)}, {g("destroy_self")})}},
  {"Card Sharp", {W("hand_played", {o("played_this_round")}, {g("xmult", 3)})}},
  {"Red Card", {W("pack_skipped", nil, {g("gain_mult", 3)})}},
  {"Madness", {W("blind_selected", {{id = "boss", neg = true}}, {g("gain_xmult", 0.5), g("destroy_joker")})}},
  {"Square Joker", {W("before", {o("cards_played", nil, "exactly", 4)}, {g("gain_chips", 4)})}},
  {"Seance", {W("hand_played", {hand("Straight Flush")}, {g("create", nil, "Spectral")})}},
  {"Riff-raff", {W("blind_selected", nil, {g("create_rarity", 2, "Common")})}},
  {"Vampire", {W("before", nil, {g("strip_enh", 0.1)})}},
  {"Shortcut", pas(g("p_rule", nil, "shortcut"))},
  {"Hologram", {W("card_added", nil, {g("gain_xmult", 0.25)})}},
  {"Vagabond", {W("hand_played", {o("money", nil, "at_most", 4)}, {g("create", nil, "Tarot")})}},
  {"Baron", {W("card_held", {o("rank", 13)}, {g("xmult", 1.5)})}, want = {"held", "S_K", "x_mult", 1.5}},
  {"Cloud 9", {W("round_end", nil, {per("money_per", "deck_match", 1, 9)})}},
  {"Rocket", {W("round_end", nil, {{id = "var_money", var = 1, n = 1}}), W("round_end", {o("boss")}, {vadd(2)})}, V("Payout", 1)},
  {"Obelisk", {W("hand_played", {{id = "most_played", neg = true}}, {g("gain_xmult", 0.2)}), W("hand_played", {o("most_played")}, {g("reset_gains")})}},
  {"Midas Mask", {W("card_scored", {o("rank", "face")}, {{id = "change", what = "enhancement", v = "m_gold"}})}},
  {"Luchador", {W("self_sold", nil, {g("disable_boss")})}},
  {"Photograph", {W("card_scored", {o("rank", "face"), o("first_scored")}, {g("xmult", 2)})}},
  {"Gift Card", {W("round_end", nil, {g("sell_all", 1)})}},
  {"Turtle Bean", {W("passive", nil, {{id = "p_hand_size_var", var = 1, n = 1}}), W("round_end", nil, {vadd(-1)}), W("round_end", {var("at_most", 0)}, {g("destroy_self")})}, V("Size", 5)},
  {"Erosion", {W("hand_played", nil, {per("mult_per", "below_deck", 4)})}},
  {"Reserved Parking", {W("card_held", {o("rank", "face"), chance(2)}, {g("money", 1)})}},
  {"Mail-In Rebate", {W("discard", {o("round_rank")}, {g("money", 5)})}},
  {"To the Moon", pas(g("p_interest", 1))},
  {"Hallucination", {W("pack_opened", {chance(2)}, {g("create", nil, "Tarot")})}},
  {"Fortune Teller", {W("hand_played", nil, {per("mult_per", "tarots_used", 1)})}},
  {"Juggler", pas(g("p_hand_size", 1))},
  {"Drunkard", pas(g("p_discards", 1))},
  {"Stone Joker", {W("hand_played", nil, {per("chips_per", "deck_match", 25, "m_stone")})}},
  {"Golden Joker", {W("round_end", nil, {g("money", 4)})}},
  {"Lucky Cat", {W("card_scored", {o("lucky_hit")}, {g("gain_xmult", 0.25)})}},
  {"Baseball Card", {W("other_joker", {o("other_rarity", "Uncommon")}, {g("xmult", 1.5)})}},
  {"Bull", {W("hand_played", nil, {per("chips_per", "money", 2)})}},
  {"Diet Cola", {W("self_sold", nil, {g("tag", nil, "tag_double")})}},
  {"Trading Card", {W("discard", {o("first_discard"), o("discarded", "any", "exactly", 1)}, {g("destroy_card"), g("money", 3)})}},
  {"Flash Card", {W("reroll", nil, {g("gain_mult", 2)})}},
  {"Popcorn", {W("hand_played", nil, {{id = "var_mult", var = 1, n = 4}}), W("round_end", nil, {vadd(-1)}), W("round_end", {var("at_most", 0)}, {g("destroy_self")})}, V("Left", 5)},
  {"Spare Trousers", {W("before", {hand("Two Pair")}, {g("gain_mult", 2)})}},
  {"Ancient Joker", {W("card_scored", {o("round_suit")}, {g("xmult", 1.5)})}},
  {"Ramen", {W("hand_played", nil, {{id = "var_xmult", var = 1, n = 0.01}}), W("discard", nil, {vadd(-1)}), W("discard", {var("at_most", 0)}, {g("destroy_self")})}, V("Left", 100)},
  {"Walkie Talkie", {W("card_scored", {o("rank", 10)}, {g("chips", 10), g("mult", 4)}), W("card_scored", {o("rank", 4)}, {g("chips", 10), g("mult", 4)})}},
  {"Seltzer", {W("card_scored", {var("at_least", 1)}, {g("retrigger", 1)}), W("after", nil, {vadd(-1)}), W("after", {var("at_most", 0)}, {g("destroy_self")})}, V("Left", 10)},
  {"Castle", {W("discard", {o("round_suit")}, {g("gain_chips", 3)})}},
  {"Smiley Face", {W("card_scored", {o("rank", "face")}, {g("mult", 5)})}, want = {"scored", "H_Q", "mult", 5}},
  {"Campfire", {W("card_sold", nil, {g("gain_xmult", 0.25)}), W("round_end", {o("boss")}, {g("reset_gains")})}},
  {"Golden Ticket", {W("card_scored", {o("enhancement", "m_gold")}, {g("money", 4)})}},
  {"Mr. Bones", {W("would_lose", {o("blind_percent", nil, "at_least", 25)}, {g("save_run"), g("destroy_self")})}},
  {"Acrobat", {W("hand_played", {o("last_hand")}, {g("xmult", 3)})}},
  {"Sock and Buskin", {W("card_scored", {o("rank", "face")}, {g("retrigger", 1)})}},
  {"Swashbuckler", {W("hand_played", nil, {per("mult_per", "sell_others", 1)})}},
  {"Troubadour", pas(g("p_hand_size", 2), g("p_hands", -1))},
  {"Certificate", {W("first_hand", nil, {g("add_to_hand", nil, "random")})}},
  {"Smeared Joker", pas(g("p_rule", nil, "smeared"))},
  {"Throwback", {W("blind_skipped", nil, {g("gain_xmult", 0.25)})}},
  {"Hanging Chad", {W("card_scored", {o("first_scored")}, {g("retrigger", 2)})}},
  {"Rough Gem", {W("card_scored", {o("suit", "Diamonds")}, {g("money", 1)})}},
  {"Bloodstone", {W("card_scored", {o("suit", "Hearts"), chance(2)}, {g("xmult", 1.5)})}},
  {"Arrowhead", {W("card_scored", {o("suit", "Spades")}, {g("chips", 50)})}, want = {"scored", "S_2", "chips", 50}},
  {"Onyx Agate", {W("card_scored", {o("suit", "Clubs")}, {g("mult", 7)})}, want = {"scored", "C_2", "mult", 7}},
  {"Glass Joker", {W("cards_destroyed", nil, {per("gain_xmult_per", "destroyed_match", 0.75, "m_glass")})}},
  {"Showman", pas(g("p_rule", nil, "showman"))},
  {"Flower Pot", {W("hand_played", {o("all_suits")}, {g("xmult", 3)})}},
  {"Blueprint", pas(g("copy_ability", nil, "right"))},
  {"Wee Joker", {W("card_scored", {o("rank", 2)}, {g("gain_chips", 8)})}},
  {"Merry Andy", pas(g("p_discards", 3), g("p_hand_size", -1))},
  {"Oops! All 6s", pas(g("p_chances", 2))},
  {"The Idol", {W("card_scored", {o("round_card")}, {g("xmult", 2)})}},
  {"Seeing Double", {W("hand_played", {o("suit_and_other", "Clubs")}, {g("xmult", 2)})}},
  {"Matador", {W("hand_played", {o("boss_triggered")}, {g("money", 8)}), W("hand_debuffed", {o("boss_triggered")}, {g("money", 8)})}},
  {"Hit the Road", {W("discard", {o("rank", 11)}, {g("gain_xmult", 0.5)}), W("round_end", nil, {g("reset_gains")})}},
  {"The Duo", {W("hand_played", {hand("Pair")}, {g("xmult", 2)})}, want = {"main", "Pair", "Xmult_mod", 2}},
  {"The Trio", {W("hand_played", {hand("Three of a Kind")}, {g("xmult", 3)})}, want = {"main", "Three of a Kind", "Xmult_mod", 3}},
  {"The Family", {W("hand_played", {hand("Four of a Kind")}, {g("xmult", 4)})}, want = {"main", "Four of a Kind", "Xmult_mod", 4}},
  {"The Order", {W("hand_played", {hand("Straight")}, {g("xmult", 3)})}, want = {"main", "Straight", "Xmult_mod", 3}},
  {"The Tribe", {W("hand_played", {hand("Flush")}, {g("xmult", 2)})}, want = {"main", "Flush", "Xmult_mod", 2}},
  {"Stuntman", {W("hand_played", nil, {g("chips", 250)}), W("passive", nil, {g("p_hand_size", -2)})}},
  {"Invisible Joker", {W("round_end", nil, {vadd(1)}), W("self_sold", {var("at_least", 2)}, {g("dup_joker")})}, V("Rounds", 0)},
  {"Brainstorm", pas(g("copy_ability", nil, "leftmost"))},
  {"Satellite", {W("round_end", nil, {per("money_per", "planets_used", 1)})}},
  {"Shoot the Moon", {W("card_held", {o("rank", 12)}, {g("mult", 13)})}},
  {"Driver's License", {W("hand_played", {o("deck_count", "enhanced", "at_least", 16)}, {g("xmult", 3)})}},
  {"Cartomancer", {W("blind_selected", nil, {g("create", nil, "Tarot")})}},
  {"Astronomer", pas(g("p_rule", nil, "free_planets"))},
  {"Burnt Joker", {W("discard", {o("first_discard"), o("once_per_discard")}, {g("level_up")})}},
  {"Bootstraps", {W("hand_played", nil, {per("mult_per", "money_5", 2)})}},
  {"Canio", {W("cards_destroyed", nil, {per("gain_xmult_per", "destroyed_match", 1, "face")})}},
  {"Triboulet", {W("card_scored", {o("rank", 13)}, {g("xmult", 2)}), W("card_scored", {o("rank", 12)}, {g("xmult", 2)})}},
  {"Yorick", {W("discard", {var("at_least", 22)}, {g("gain_xmult", 1), {id = "var_set", var = 1, n = 0}}, {vadd(1)})}, V("Discarded", 0)},
  {"Chicot", {W("blind_selected", {o("boss")}, {g("disable_boss")})}},
  {"Perkeo", {W("shop_end", nil, {g("copy_consumable", nil, "negative")})}},
}

local function lossless(rules, kind, vars)
  local c = R.clean_rules(rules, kind)
  if #c ~= #rules then return false, "rules " .. #c .. "/" .. #rules end
  for i, r in ipairs(rules) do
    if #c[i].only ~= #(r.only or {}) then return false, "rule " .. i .. " conditions" end
    if #c[i].give ~= #(r.give or {}) then return false, "rule " .. i .. " gives" end
    if #(c[i].alt or {}) ~= #(r.alt or {}) then return false, "rule " .. i .. " otherwise" end
    for k, x in ipairs(r.give or {}) do
      if x.v ~= nil and c[i].give[k].v ~= x.v then return false, "rule " .. i .. " value " .. tostring(x.v) end
      if x.per ~= nil and c[i].give[k].per ~= x.per then return false, "rule " .. i .. " count " .. tostring(x.per) end
      if x.n ~= nil and tonumber(c[i].give[k].n) ~= tonumber(x.n) then return false, "rule " .. i .. " " .. x.id .. " number " .. tostring(x.n) .. " became " .. tostring(c[i].give[k].n) end
    end
    for k, x in ipairs(r.alt or {}) do
      if x.n ~= nil and tonumber(c[i].alt[k].n) ~= tonumber(x.n) then return false, "rule " .. i .. " otherwise " .. x.id .. " number " .. tostring(x.n) .. " became " .. tostring(c[i].alt[k].n) end
    end
    for k, x in ipairs(r.only or {}) do
      if x.v ~= nil and c[i].only[k].v ~= x.v then return false, "rule " .. i .. " condition value " .. tostring(x.v) end
      if x.n ~= nil and tonumber(c[i].only[k].n) ~= tonumber(x.n) then return false, "rule " .. i .. " condition " .. x.id .. " number " .. tostring(x.n) .. " became " .. tostring(c[i].only[k].n) end
    end
  end
  if R.need_v(rules, vars) > 8 then return false, "version" end
  return true
end

local function effects_ok(kind, effects)
  for _, e in ipairs(effects or {}) do
    local spec = Cat.effect(kind, e.id)
    if not spec then return false, "effect " .. e.id end
    if spec.v and e.v ~= nil then
      local ok = false
      for _, v in ipairs(Cat.values(spec.v) or {}) do if v == e.v then ok = true end end
      if not ok then return false, e.id .. " value " .. tostring(e.v) end
    end
  end
  local c = Cat.clean_effects(kind, effects or {})
  for i, e in ipairs(effects or {}) do
    if not c[i] or c[i].id ~= e.id then return false, "effect " .. e.id .. " dropped" end
    if e.n ~= nil and tonumber(c[i].n) ~= tonumber(e.n) then return false, e.id .. " number " .. tostring(e.n) .. " became " .. tostring(c[i].n) end
  end
  return true
end

local function fields_ok(kind, fields)
  local k = Cat.kind(kind)
  for id in pairs(fields or {}) do
    local found = false
    for _, list in ipairs({k.fields or {}, k.adv_fields or {}}) do
      for _, f in ipairs(list) do if f.id == id then found = true end end
    end
    if not found then return false, "field " .. id end
  end
  local c = Cat.clean_fields(kind, fields or {})
  for id, v in pairs(fields or {}) do
    if c[id] ~= v then return false, "field " .. id .. " " .. tostring(v) .. " became " .. tostring(c[id]) end
  end
  return true
end

local log
local function reset()
  log = {dollars = 0}
  G = {
    play = {name = "play"}, hand = {name = "hand", cards = {}}, jokers = {cards = {}, config = {card_limit = 5}}, consumeables = {cards = {}, config = {card_limit = 2}},
    GAME = {dollars = 10, probabilities = {normal = 1}, current_round = {hands_left = 3, discards_left = 2, hands_played = 0, discards_used = 0}, round_resets = {ante = 1}, blind = {boss = false},
      hands = {Pair = {played = 1, played_this_round = 1, visible = true, level = 1}}},
    C = {MONEY = {}, MULT = {}, CHIPS = {}, BLUE = {}, RED = {}, FILTER = {}, SECONDARY_SET = {}},
    E_MANAGER = {add_event = function(_, e) e.func() end},
    P_CENTERS = {c_base = {key = "c_base"}},
  }
end
Event = function(t) return t end
localize = function(a) return type(a) == "table" and a.key or a end
card_eval_status_text = function() end
ease_dollars = function(n) log.dollars = log.dollars + n end

local RANK = {A = 14, K = 13, Q = 12, J = 11, T = 10}
local SUIT = {H = "Hearts", D = "Diamonds", S = "Spades", C = "Clubs"}
local function pcard(key)
  local s, r = key:match("^(%a)_(%w+)$")
  local id = RANK[r] or tonumber(r)
  local c = {base = {suit = SUIT[s], id = id, nominal = math.min(id, 10)}, ability = {}, config = {center = G.P_CENTERS.c_base}}
  function c:get_id() return self.base.id end
  function c:is_face() return self.base.id >= 11 and self.base.id <= 13 end
  function c:is_suit(x) return self.base.suit == x end
  return c
end

local function behaves(rules, vars, want)
  reset()
  local card = {ability = {set = "Joker", extra = {}}, config = {center = {forge_id = "cov"}}}
  local kind, a, key, n = want[1], want[2], want[3], want[4]
  local ctx
  if kind == "main" then
    local cards = a == "High Card" and {pcard("S_K")} or {pcard("S_K"), pcard("H_K")}
    ctx = {cardarea = G.jokers, joker_main = true, scoring_name = a, poker_hands = {[a] = {{}}}, full_hand = cards, scoring_hand = cards}
  else
    local c = pcard(a)
    ctx = {cardarea = kind == "held" and G.hand or G.play, individual = true, other_card = c, full_hand = {c}, scoring_hand = {c}, scoring_name = "High Card", poker_hands = {["High Card"] = {{}}}}
  end
  local r = R.calculate(card, ctx, R.clean_rules(rules), R.clean_vars(vars))
  return r ~= nil and r[key] == n, r and r[key]
end

local count = {}
local close = {}
local scripted = 0
local function tally(cat, ok, note)
  count[cat] = (count[cat] or 0) + (ok and 1 or 0)
  if ok and note then close[#close + 1] = note end
end

for _, e in ipairs(J) do
  local ok, why = lossless(e[2], "joker", e[3])
  check("Joker " .. e[1] .. " rebuilt", ok, why)
  if ok and e.want then
    local b, got = behaves(e[2], e[3], e.want)
    scripted = scripted + 1
    check("Joker " .. e[1] .. " scores like vanilla", b, got)
    ok = ok and b
  end
  tally("Jokers", ok, e.close and (e[1] .. ": " .. e.close))
end

local GREEN
for _, e in ipairs(J) do if e[1] == "Green Joker" then GREEN = e end end
do
  reset()
  local rules, vars = R.clean_rules(GREEN[2]), R.clean_vars(GREEN[3])
  local card = {ability = {set = "Joker", extra = {}}, config = {center = {forge_id = "cov"}}}
  local function play()
    local cards = {pcard("S_K")}
    local base = {cardarea = G.jokers, scoring_name = "High Card", poker_hands = {["High Card"] = {{}}}, full_hand = cards, scoring_hand = cards}
    local b = {before = true}
    for k, v in pairs(base) do b[k] = v end
    R.calculate(card, b, rules, vars)
    base.joker_main = true
    local r = R.calculate(card, base, rules, vars)
    return r and r.mult_mod or 0
  end
  local function discard(n)
    local cards = {}
    for i = 1, n do cards[i] = pcard("H_" .. (i + 1)) end
    for _, c in ipairs(cards) do R.calculate(card, {discard = true, other_card = c, full_hand = cards}, rules, vars) end
  end
  local function now() return tonumber(R.vars_state(card, vars)[1]) end
  check("Green Joker exact: first hand gives +1 Mult", play() == 1)
  check("Green Joker exact: second hand gives +2 Mult", play() == 2)
  discard(3)
  check("Green Joker exact: a discard of 3 cards loses 1 Mult once", now() == 1, now())
  discard(1)
  discard(2)
  check("Green Joker exact: never below 0", now() == 0, now())
  check("Green Joker exact: next hand gives +1 Mult again", play() == 1)
  local raw = R.clean_rules({W("discard", nil, {g("gain_mult", -1)})})[1].give[1].n
  check("gain_mult still cleans to at least 1, so lose recipes use a variable", raw == 1, raw)
end

local ENH = {
  {"Bonus", {chips = 30}}, {"Mult", {chips = 0, mult = 4}}, {"Wild", {chips = 0, any_suit = true}}, {"Glass", {chips = 0, xmult = 2, breaks = 4}},
  {"Steel", {chips = 0, held_xmult = 1.5}}, {"Stone", {chips = 50, no_rank = true, always = true}}, {"Gold", {chips = 0, held_money = 3}},
  {"Lucky", {chips = 0}, {W("card_scored", {chance(5)}, {g("mult", 20)}), W("card_scored", {chance(15)}, {g("money", 20)})}},
}
for _, e in ipairs(ENH) do
  local ok, why = fields_ok("enhancement", e[2])
  if ok and e[3] then ok, why = lossless(e[3], "enhancement") end
  local item = {kind = "enhancement", fields = e[2], rules = e[3]}
  if ok and Cat.need_v(item) > 8 then ok, why = false, "version" end
  check("Enhancement " .. e[1] .. " rebuilt", ok, why)
  tally("Enhancements", ok)
end

local SEALS = {
  {"Red", nil, {W("card_scored", nil, {g("retrigger", 1)}), W("card_held", nil, {g("retrigger", 1)})}},
  {"Blue", {{id = "held_planet"}}}, {"Gold", {{id = "scored_money", n = 3}}}, {"Purple", {{id = "discard_tarot"}}},
}
for _, e in ipairs(SEALS) do
  local ok, why = effects_ok("seal", e[2])
  if ok and e[3] then ok, why = lossless(e[3], "seal") end
  check("Seal " .. e[1] .. " rebuilt", ok, why)
  tally("Seals", ok)
end

local EDS = {
  {"Foil", {shader = "foil", chips = 50}}, {"Holographic", {shader = "holo", chips = 0, mult = 10}},
  {"Polychrome", {shader = "polychrome", chips = 0, xmult = 1.5}}, {"Negative", {shader = "negative", chips = 0, slot = true}},
}
for _, e in ipairs(EDS) do
  local ok, why = fields_ok("edition", e[2])
  check("Edition " .. e[1] .. " rebuilt", ok, why)
  tally("Editions", ok)
end

local function fx(id, n, v) return {id = id, n = n, v = v} end
local VOUCHERS = {
  {"Overstock", {fx("shop_slots", 1)}}, {"Overstock Plus", {fx("shop_slots", 1)}}, {"Clearance Sale", {fx("discount", 25)}}, {"Liquidation", {fx("discount", 50)}},
  {"Hone", {fx("edition_rate", 2)}}, {"Glow Up", {fx("edition_rate", 4)}}, {"Reroll Surplus", {fx("reroll_cost", -2)}}, {"Reroll Glut", {fx("reroll_cost", -2)}},
  {"Crystal Ball", {fx("consumable_slots", 1)}}, {"Omen Globe", {fx("omen")}}, {"Telescope", {fx("telescope")}}, {"Observatory", {fx("observatory", 1.5)}},
  {"Grabber", {fx("hands", 1)}}, {"Nacho Tong", {fx("hands", 1)}}, {"Wasteful", {fx("discards", 1)}}, {"Recyclomancy", {fx("discards", 1)}},
  {"Tarot Merchant", {fx("shop_rate", 5.6, "Tarot")}}, {"Tarot Tycoon", {fx("shop_rate", 22.4, "Tarot")}},
  {"Planet Merchant", {fx("shop_rate", 5.6, "Planet")}}, {"Planet Tycoon", {fx("shop_rate", 22.4, "Planet")}},
  {"Seed Money", {fx("interest_cap", 25)}}, {"Money Tree", {fx("interest_cap", 50)}}, {"Blank", {}}, {"Antimatter", {fx("joker_slots", 1)}},
  {"Magic Trick", {fx("shop_rate", 4, "Playing")}}, {"Illusion", {fx("illusion")}}, {"Hieroglyph", {fx("ante_now", -1), fx("hands", -1)}}, {"Petroglyph", {fx("ante_now", -1), fx("discards", -1)}},
  {"Director's Cut", {fx("boss_reroll")}}, {"Retcon", {fx("boss_reroll_any")}}, {"Paint Brush", {fx("hand_size", 1)}}, {"Palette", {fx("hand_size", 1)}},
}
for _, e in ipairs(VOUCHERS) do
  local ok, why = effects_ok("voucher", e[2])
  if ok and Cat.need_v({kind = "voucher", effects = e[2]}) > 8 then ok, why = false, "version" end
  check("Voucher " .. e[1] .. " rebuilt", ok, why)
  tally("Vouchers", ok, e.close and (e[1] .. ": " .. e.close))
end

local TAGS = {
  {"Uncommon Tag", {fx("free_joker", nil, 2)}}, {"Rare Tag", {fx("free_joker", nil, 3)}}, {"Negative Tag", {fx("next_edition", nil, "negative")}}, {"Foil Tag", {fx("next_edition", nil, "foil")}},
  {"Holographic Tag", {fx("next_edition", nil, "holo")}}, {"Polychrome Tag", {fx("next_edition", nil, "polychrome")}}, {"Investment Tag", {fx("boss_money", 25)}}, {"Voucher Tag", {fx("shop_voucher")}},
  {"Boss Tag", {fx("reroll_boss")}}, {"Standard Tag", {fx("free_pack", nil, "Standard")}}, {"Charm Tag", {fx("free_pack", nil, "Arcana")}}, {"Meteor Tag", {fx("free_pack", nil, "Celestial")}},
  {"Buffoon Tag", {fx("free_pack", nil, "Buffoon")}}, {"Handy Tag", {}, {W("used", nil, {per("money_per", "hands_run", 1)})}}, {"Garbage Tag", {}, {W("used", nil, {per("money_per", "discards_unused", 1)})}},
  {"Ethereal Tag", {fx("free_pack", nil, "Spectral")}}, {"Coupon Tag", {fx("coupon")}}, {"Double Tag", {fx("double")}}, {"Juggle Tag", {fx("hand_size", 3)}}, {"D6 Tag", {fx("free_shop_reroll")}},
  {"Top-up Tag", {}, {W("used", nil, {g("create_rarity", 2, "Common")})}}, {"Speed Tag", {fx("money_per_skip", 5)}}, {"Orbital Tag", {fx("level_up", 3, "Pair")}}, {"Economy Tag", {fx("double_money", 40)}},
}
for _, e in ipairs(TAGS) do
  local ok, why = effects_ok("tag", e[2])
  if ok and e[3] then ok, why = lossless(e[3], "tag") end
  if ok and Cat.need_v({kind = "tag", effects = e[2], rules = e[3]}) > 8 then ok, why = false, "version" end
  check(e[1] .. " rebuilt", ok, why)
  tally("Tags", ok)
end

local BOSSES = {
  {"The Hook", {fx("discard_held", 2)}}, {"The Ox", {fx("most_played_zero")}}, {"The House", {fx("face_down_first")}}, {"The Wall", {}, {size = 4}},
  {"The Wheel", {fx("face_down_chance", 7)}}, {"The Arm", {fx("level_down")}}, {"The Club", {fx("debuff_suit", nil, "Clubs")}}, {"The Fish", {fx("face_down_after")}},
  {"The Psychic", {fx("must_play", 5)}}, {"The Goad", {fx("debuff_suit", nil, "Spades")}}, {"The Water", {fx("no_discards")}}, {"The Window", {fx("debuff_suit", nil, "Diamonds")}},
  {"The Manacle", {fx("hand_size_minus", 1)}}, {"The Eye", {fx("no_repeat")}}, {"The Mouth", {fx("one_type")}}, {"The Plant", {fx("debuff_face")}},
  {"The Serpent", {fx("draw_three")}}, {"The Pillar", {fx("debuff_played_ante")}}, {"The Needle", {fx("one_hand")}, {size = 1}}, {"The Head", {fx("debuff_suit", nil, "Hearts")}},
  {"The Tooth", {fx("money_per_card", 1)}}, {"The Flint", {fx("halve_base")}}, {"The Mark", {fx("face_down_faces")}}, {"Amber Acorn", {fx("shuffle_jokers")}},
  {"Verdant Leaf", {fx("debuff_until_sell")}}, {"Violet Vessel", {}, {size = 6}}, {"Crimson Heart", {fx("disable_joker")}}, {"Cerulean Bell", {fx("force_select")}},
}
for _, e in ipairs(BOSSES) do
  local ok, why = effects_ok("blind", e[2])
  if ok and e[3] then ok, why = fields_ok("blind", e[3]) end
  if ok and Cat.need_v({kind = "blind", effects = e[2], fields = e[3]}) > 8 then ok, why = false, "version" end
  check(e[1] .. " rebuilt", ok, why)
  tally("Boss blinds", ok)
end

local function dna_run(rules, n_cards, played)
  reset()
  local where = {}
  G.deck = {config = {card_limit = 52}, emplace = function(_, c) where[#where + 1] = "deck"; c.area = "deck" end}
  G.hand.emplace = function(self, c) where[#where + 1] = "hand"; self.cards[#self.cards + 1] = c end
  G.playing_cards = {}
  G.GAME.current_round.hands_played = played or 0
  copy_card = function(c) local x = {src = c, states = {visible = true}} function x:add_to_deck() end function x:start_materialize() self.states.visible = true end return x end
  local card = {ability = {set = "Joker", extra = {}}, config = {center = {forge_id = "cov"}}}
  local cards = {}
  for i = 1, n_cards do cards[i] = pcard("S_" .. (i + 1)) end
  R.calculate(card, {cardarea = G.play, individual = true, other_card = cards[1], full_hand = cards, scoring_hand = cards, scoring_name = "High Card", poker_hands = {["High Card"] = {{}}}}, R.clean_rules(rules))
  return where, G.hand.cards[1], G.deck.config.card_limit, #G.playing_cards
end
local DNA
for _, e in ipairs(J) do if e[1] == "DNA" then DNA = e[2] end end
local w1, made, lim, pc = dna_run(DNA, 1)
check("DNA exact: the copy is drawn to hand like vanilla", #w1 == 1 and w1[1] == "hand" and made and made.src and made.src.base.id == 2, w1[1])
check("DNA exact: the copy joins the deck for good", lim == 53 and pc == 1)
check("DNA exact: the copy materializes visible", made and made.states.visible == true)
check("DNA exact: nothing with two cards", #dna_run(DNA, 2) == 0)
check("DNA exact: nothing after the first hand", #dna_run(DNA, 1, 1) == 0)
local w2 = dna_run({W("card_scored", nil, {g("copy_card")})}, 1)
check("copy card without hand still goes to the deck", #w2 == 1 and w2[1] == "deck")
check("copy to hand is version 8, plain copy stays old", R.need_v(DNA) == 8 and R.need_v({W("card_scored", nil, {g("copy_card")})}) < 8)
check("copy card cleaning keeps only hand", R.clean_rules({W("card_scored", nil, {g("copy_card", nil, "deck")})})[1].give[1].v == nil)
local T = require("functions/forge/forge_text")
check("copy to hand text en fr es", T.give_text({id = "copy_card", v = "hand"}, "en"):find("hand", 1, true) and T.give_text({id = "copy_card", v = "hand"}, "fr"):find("main", 1, true) and T.give_text({id = "copy_card", v = "hand"}, "es"):find("mano", 1, true))

local EXPECT = {Jokers = 150, Enhancements = 8, Seals = 4, Editions = 4, Vouchers = 32, Tags = 24, ["Boss blinds"] = 28}
local sum, want_sum = 0, 0
for _, cat in ipairs({"Jokers", "Enhancements", "Seals", "Editions", "Vouchers", "Tags", "Boss blinds"}) do
  print(string.format("coverage %s: %d / %d", cat, count[cat] or 0, EXPECT[cat]))
  check("coverage count " .. cat, (count[cat] or 0) == EXPECT[cat], count[cat])
  sum, want_sum = sum + (count[cat] or 0), want_sum + EXPECT[cat]
end
print(string.format("coverage all: %d / %d (%d close: %s), %d scored in scripted hands here", sum, want_sum, #close, table.concat(close, "; "), scripted))
print(string.format("forge coverage: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
