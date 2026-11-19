local Bal = {}

Bal.LEVELS = {"weak", "fair", "strong", "op", "broken"}
Bal.RANK = {weak = 1, fair = 2, strong = 3, op = 4, broken = 5}
Bal.NAME = {weak = "Weak", fair = "Fair", strong = "Strong", op = "Overpowered", broken = "Broken"}
Bal.M0, Bal.C0, Bal.HANDS = 12, 100, 4
Bal.WINDOW, Bal.SHORT = 32, 12
Bal.WEAK_R, Bal.STRONG_R, Bal.OP_R = 0.15, 2, 4
Bal.OP_AT, Bal.BROKEN_AT = 3.6, 5
Bal.HARM_FAIR, Bal.HARM_STRONG = 0.4, 1.2
Bal.REF = {
  joker = {0.55, 0.75, 1.2, 1.5},
  voucher = {0.5, 0.8},
  tarot = 0.55, planet = 0.3, spectral = 0.9, tag = 0.6,
  enhancement = 0.45, seal = 0.35, edition = 0.6, booster = 0.35, deck = 0.8,
}
Bal.TIER_P = {0.55, 0.8, 1.3, 2.2}
Bal.HARM = {stake = true, blind = true}
Bal.ONCE = {tarot = true, planet = true, spectral = true, tag = true}
Bal.CARD_HOST = {enhancement = true, seal = true, edition = true}
Bal.TIER = {joker = {"common", "uncommon", "rare", "legendary"}}

local LN2 = 0.6931471805599453
local BIG = 1e300

local function num(x, def)
  x = tonumber(x)
  if not x or x ~= x then return def or 0 end
  if x > BIG then return BIG end
  if x < -BIG then return -BIG end
  return x
end

local function lg(x)
  x = num(x)
  if x <= 0 then return 0 end
  local e = 0
  while x >= 2 do x = x * 0.5; e = e + 1 end
  while x < 1 do x = x * 2; e = e - 1 end
  local t = (x - 1) / (x + 1)
  local t2 = t * t
  local s = t * (1 + t2 * (1 / 3 + t2 * (1 / 5 + t2 * (1 / 7 + t2 * (1 / 9 + t2 * (1 / 11 + t2 / 13))))))
  return e + 2 * s / LN2
end
Bal.lg = lg

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function round2(x) return math.floor(x * 100 + 0.5) / 100 end
Bal.round2 = round2

local function curve(n, per, knee, tail, floor)
  if n <= 0 then return math.max(floor or -3, per * n) end
  if n <= knee then return per * n end
  return per * knee + tail * lg(1 + n - knee)
end

local function money_pp(m)
  if m < 0 then return math.max(-2, 0.11 * m) end
  if m <= 20 then return 0.11 * m end
  return 2.2 + 1.5 * lg(m / 20)
end

local function once_money_pp(m)
  if m < 0 then return math.max(-1, 0.03 * m) end
  if m <= 50 then return 0.03 * m end
  return 1.5 + 1.6 * lg(m / 50)
end

local W = {
  card_scored = {h = 3.5, card = true}, card_held = {h = 3, card = true, held = true},
  hand_played = {h = 1}, before = {h = 1}, after = {h = 1}, hand_debuffed = {h = 0.1}, other_joker = {h = 4},
  discard = {r = 7, card = true, discard = true},
  first_hand = {r = 1}, blind_selected = {r = 1}, round_end = {r = 1}, blind_skipped = {r = 0.3}, reroll = {r = 1},
  shop_end = {r = 1}, card_sold = {r = 0.5}, pack_opened = {r = 0.7}, consumable_used = {r = 1.5}, card_bought = {r = 1.5},
  pack_skipped = {r = 0.3}, cards_destroyed = {r = 0.2}, card_added = {r = 0.5}, shop_enter = {r = 1}, ante_up = {r = 1 / 3},
  money_earned = {r = 3}, money_spent = {r = 2}, card_drawn = {r = 12, card = true}, joker_sold = {r = 0.3}, joker_added = {r = 0.5}, tag_added = {r = 0.4}, boss_beaten = {r = 1 / 3},
  shop_opened = {r = 1}, hand_leveled = {r = 0.7}, consumable_added = {r = 1.5}, before_discard = {r = 2},
  self_sold = {once = true}, would_lose = {once = true}, now = {once = true}, used = {once = true}, passive = {perm = true},
}
local CARD_W = {card_scored = {h = 1, card = true}, card_held = {h = 1, card = true, held = true}, discard = {r = 0.5, card = true, discard = true}, round_end = {r = 1}}

local HAND_P = {["High Card"] = 0.9, Pair = 0.6, ["Two Pair"] = 0.35, ["Three of a Kind"] = 0.35, Straight = 0.3, Flush = 0.35, ["Full House"] = 0.2,
  ["Four of a Kind"] = 0.2, ["Straight Flush"] = 0.05, ["Five of a Kind"] = 0.05, ["Flush House"] = 0.03, ["Flush Five"] = 0.03}
local RANK_P = {face = 3 / 13, number = 9 / 13, even = 5 / 13, odd = 5 / 13}
local PLAYED_P = {[1] = 0.3, [2] = 0.2, [3] = 0.15, [4] = 0.15, [5] = 0.4}
local COUNT = {jokers = 4, empty_slots = 1, consumables = 1, deck_left = 30, held_match = 1.5, scoring_match = 1.5, destroyed_match = 0.5,
  discards_left = 2, hands_left = 2, money = 20, money_5 = 4, sell_others = 8, times_played = 5, planets_used = 5, hands_run = 20,
  discards_unused = 5, below_deck = 5, tarots_used = 5, jokers_match = 1}
local IV = {Tarot = 0.5, Planet = 0.4, Spectral = 0.9, Joker = 0.6, Playing = 0.1}
local RV = {Common = 0.35, Uncommon = 0.8, Rare = 1.3, Legendary = 2.5, [1] = 0.5, [2] = 0.8, [3] = 1.3, [4] = 2.5}
local EV = {m_glass = 0.25, m_steel = 0.22, m_gold = 0.15, m_lucky = 0.15, m_mult = 0.12, m_bonus = 0.1, m_wild = 0.1, m_stone = 0.1}
local ED_C = {foil = 0.2, holo = 0.25, polychrome = 0.35, negative = 0.5}
local ED_J = {foil = 0.3, holo = 0.45, polychrome = 0.6, negative = 0.9}
local PACKV = {Arcana = 0.35, Celestial = 0.3, Spectral = 0.7, Standard = 0.15, Buffoon = 0.5, Forge = 0.5}
local BOSS_HARM = {debuff_suit = 0.3, debuff_face = 0.3, debuff_hand = 0.3, only_hand = 0.6, must_play = 0.2, no_discards = 0.4, face_down_first = 0.1,
  one_hand = 0.8, halve_base = 0.4, debuff_rank = 0.2, debuff_enh = 0.1, debuff_seal = 0.1, debuff_edition = 0.1, most_played_zero = 0.3,
  face_down_chance = 0.2, face_down_faces = 0.1, face_down_after = 0.1, level_down = 0.2, no_repeat = 0.3, one_type = 0.3, draw_three = 0.2,
  debuff_played_ante = 0.3, shuffle_jokers = 0.1, debuff_until_sell = 0.3, disable_joker = 0.3, force_select = 0.2}

local function card_value(key)
  if type(key) ~= "string" then return 0.4 end
  if key:match("^j_") then return 0.7 end
  if key:match("^c_") then return 0.35 end
  if key:match("^v_") then return 0.6 end
  return 0.4
end

local function ed_key(v)
  if type(v) ~= "string" then return nil end
  return (v:gsub("^e_", ""))
end

local function new_acc()
  return {mult = 0, chips = 0, xlog = 0, exp = 0, money = 0, hands = 0, discards = 0, hsize = 0, jslots = 0, cslots = 0, retr = 0,
    make = 0, levels = 0, util = 0, once = 0, once_money = 0, life = 1, top = nil, top_pp = 0}
end

local function note(A, pp, key, amt, freq)
  if pp > A.top_pp then A.top_pp, A.top = pp, {key = key, n = amt, freq = freq} end
end

local function freq_of(o)
  if o.perm then return nil end
  if o.once then return "once" end
  if o.card then return o.p >= 0.9 and (o.held and "held" or "scored") or "some" end
  if o.r and not o.hand then return o.p >= 0.9 and "round" or "some" end
  if o.p >= 0.9 then return "hand" end
  if o.p >= 0.3 then return "often" end
  return "some"
end

local function add_score(A, kind, amt, o)
  local h = o.h or 0
  if h <= 0 then return end
  local f = freq_of(o)
  if kind == "mult" or kind == "chips" then
    local base = kind == "mult" and Bal.M0 or Bal.C0
    A[kind] = A[kind] + amt * h
    if amt > 0 then note(A, lg(1 + amt * h / base), kind, amt, f) end
  elseif kind == "xmult" or kind == "xchips" then
    if amt <= 0 then return end
    local l = lg(amt) * h
    A.xlog = A.xlog + l
    note(A, l, kind, amt, f)
  elseif kind == "emult" or kind == "echips" then
    local l = (amt - 1) * 5 * h
    A.exp = A.exp + l
    note(A, l, kind, amt, f)
  end
end

local function per_round(o, ctx)
  if o.once or o.perm then return 0 end
  if o.r then return o.r end
  return (o.h or 0) * ctx.hands
end

local function add_money(A, amt, o, ctx)
  if o.once then
    A.once_money = A.once_money + amt
    if amt > 0 then note(A, once_money_pp(amt) * ctx.once_w, "money_once", amt, "once") end
    return
  end
  local m = o.perm and amt or amt * per_round(o, ctx)
  A.money = A.money + m
  if m > 0 then note(A, money_pp(m), "money", round2(m), "round") end
end

local function add_make(A, value, o, ctx)
  if o.once or o.perm then
    A.once = A.once + value
    note(A, value * ctx.once_w, "make", nil, "once")
    return
  end
  local v = value * per_round(o, ctx)
  A.make = A.make + v
  note(A, v, "make", nil, freq_of(o))
end

local function add_gain(A, kind, amt, o, ctx)
  local h = o.h or 0
  if o.r then h = o.r / ctx.hands end
  if o.once or o.perm or h <= 0 then return end
  local acc = amt * h * ctx.window / 2
  if kind == "xmult" then
    local l = lg(1 + acc)
    A.xlog = A.xlog + l
    note(A, l, "gain_xmult", amt, freq_of(o))
  else
    A[kind] = A[kind] + acc
    note(A, lg(1 + acc / (kind == "mult" and Bal.M0 or Bal.C0)), "gain_" .. kind, amt, freq_of(o))
  end
end

local function add_res(A, key, n)
  A[key] = A[key] + n
end

local function add_levels(A, n, o, ctx)
  if o.once or o.perm then
    A.once = A.once + 0.12 * n
    note(A, 0.12 * n * ctx.once_w, "levels", n, "once")
    return
  end
  local h = o.r and o.r / ctx.hands or (o.h or 0)
  local l = n * h * ctx.window / 2
  A.levels = A.levels + l
  note(A, 0.12 * l, "levels", round2(l), nil)
end

local function add_util(A, v, key, o, ctx)
  if o and (o.once) and not o.perm then
    A.once = A.once + v
    if v > 0 then note(A, v * ctx.once_w, key, nil, "once") end
    return
  end
  A.util = A.util + v
  if v > 0 then note(A, v, key, nil, nil) end
end

local function var_value(ctx, i)
  local v = ctx.vars[i]
  if not v then return 0 end
  local span = v.reset and Bal.SHORT or Bal.WINDOW
  local e = v.start + (v.up - v.down) * span
  if e < 0 then e = 0 end
  local val = (math.max(0, v.start) + e) / 2
  if v.set_max > 0 then val = math.max(val, v.set_max / 2) end
  return val
end

local function amount(g, ctx, def)
  local i = tonumber(g.nv)
  if i and g.n ~= nil and ctx.vars[i] then return var_value(ctx, i) end
  return num(g.n, def)
end

local DO = {}

local function scorer(kind, sign)
  return function(g, o, A, ctx) add_score(A, kind, sign * amount(g, ctx, 0), o) end
end
DO.chips, DO.mult, DO.xmult, DO.xchips = scorer("chips", 1), scorer("mult", 1), scorer("xmult", 1), scorer("xchips", 1)
DO.emult, DO.echips = scorer("emult", 1), scorer("echips", 1)
DO.minus_chips, DO.minus_mult = scorer("chips", -1), scorer("mult", -1)
DO.div_mult = function(g, o, A, ctx)
  local n = amount(g, ctx, 1)
  if n > 0 then add_score(A, "xmult", 1 / n, o) end
end
DO.rand_mult = function(g, o, A, ctx) add_score(A, "mult", amount(g, ctx, 0) / 2, o) end
DO.rank_mult = function(g, o, A, ctx) add_score(A, "mult", amount(g, ctx, 0) * 4, o) end
local function var_scorer(kind)
  return function(g, o, A, ctx)
    local v = var_value(ctx, tonumber(g.var) or 1)
    local n = num(g.n, 1)
    if kind == "xmult" or kind == "xchips" then add_score(A, kind, 1 + n * v, o) else add_score(A, kind, n * v, o) end
  end
end
DO.var_chips, DO.var_mult, DO.var_xmult, DO.var_xchips = var_scorer("chips"), var_scorer("mult"), var_scorer("xmult"), var_scorer("xchips")
local function count_of(g)
  local c = COUNT[g.per]
  if c then return c end
  if g.per == "deck_match" then
    local m = g.m
    if type(m) == "string" and m:match("^m_") then return 2 end
    if tonumber(m) then return 4 end
    if m == "face" then return 12 end
    return 5
  end
  return 3
end
local function per_scorer(kind)
  return function(g, o, A, ctx)
    local n, c = amount(g, ctx, 0), count_of(g)
    if kind == "xmult" then add_score(A, "xmult", 1 + n * c, o) else add_score(A, kind, n * c, o) end
  end
end
DO.chips_per, DO.mult_per, DO.xmult_per = per_scorer("chips"), per_scorer("mult"), per_scorer("xmult")
DO.money_per = function(g, o, A, ctx) add_money(A, amount(g, ctx, 0) * count_of(g), o, ctx) end
DO.gain_mult_per = function(g, o, A, ctx) add_gain(A, "mult", amount(g, ctx, 0) * count_of(g), o, ctx) end
DO.gain_xmult_per = function(g, o, A, ctx) add_gain(A, "xmult", amount(g, ctx, 0) * count_of(g), o, ctx) end
DO.gain_chips = function(g, o, A, ctx) add_gain(A, "chips", amount(g, ctx, 0), o, ctx) end
DO.gain_mult = function(g, o, A, ctx) add_gain(A, "mult", amount(g, ctx, 0), o, ctx) end
DO.gain_xmult = function(g, o, A, ctx) add_gain(A, "xmult", amount(g, ctx, 0), o, ctx) end
DO.gain_xchips = DO.gain_xmult
DO.boost_mult = DO.gain_mult
DO.boost_chips = DO.gain_chips
DO.boost_xmult = DO.gain_xmult
DO.dagger = function(g, o, A, ctx) add_gain(A, "mult", 6, o, ctx); add_util(A, -0.2, "destroy", nil, ctx) end
DO.strip_enh = function(g, o, A, ctx) add_gain(A, "xmult", amount(g, ctx, 0.1) * 0.7, o, ctx) end
DO.perma_chips = function(g, o, A, ctx)
  if o.once then return add_util(A, 0.3 * lg(1 + amount(g, ctx, 0) / 30) * ctx.select, "perma", o, ctx) end
  add_gain(A, "chips", amount(g, ctx, 0) * 0.15, o, ctx)
end
DO.money = function(g, o, A, ctx) add_money(A, amount(g, ctx, 0), o, ctx) end
DO.lose_money = function(g, o, A, ctx) add_money(A, -amount(g, ctx, 0), o, ctx) end
DO.var_money = function(g, o, A, ctx) add_money(A, num(g.n, 1) * var_value(ctx, tonumber(g.var) or 1), o, ctx) end
DO.sell_value = function(g, o, A, ctx) add_money(A, amount(g, ctx, 0) * 0.5, o, ctx) end
DO.sell_all = function(g, o, A, ctx) add_money(A, amount(g, ctx, 1) * 2.5, o, ctx) end
local function round_res(key, sign)
  return function(g, o, A, ctx)
    local n = sign * amount(g, ctx, 1)
    if o.perm then return add_res(A, key, n) end
    local r = o.once and 1 or per_round(o, ctx)
    if not o.once and r > 1 and sign > 0 then r = 1 + (r - 1) * 0.5 end
    add_res(A, key, n * r)
    if n > 0 then note(A, (key == "hands" and 0.7 or 0.35) * n * r, key, n, freq_of(o)) end
  end
end
DO.hand, DO.discard = round_res("hands", 1), round_res("discards", 1)
DO.hands_round, DO.discards_round = round_res("hands", 1), round_res("discards", 1)
DO.lose_hands, DO.lose_discard = round_res("hands", -1), round_res("discards", -1)
DO.cancel_discard = round_res("discards", 1)
DO.lose_discards = function(g, o, A, ctx) add_res(A, "discards", -3 * math.min(1, o.once and 1 or per_round(o, ctx))) end
DO.lose_hand_size = function(g, o, A, ctx) add_res(A, "hsize", -amount(g, ctx, 1)) end
DO.p_hand_size = function(g, o, A, ctx) add_res(A, "hsize", amount(g, ctx, 1)) end
DO.p_select = function(g, o, A, ctx) add_res(A, "hsize", amount(g, ctx, 1)) end
DO.select_plus = function(g, o, A, ctx) add_res(A, "hsize", amount(g, ctx, 1)) end
DO.p_hand_size_var = function(g, o, A, ctx) add_res(A, "hsize", num(g.n, 1) * var_value(ctx, tonumber(g.var) or 1)) end
DO.p_hands = function(g, o, A, ctx) add_res(A, "hands", amount(g, ctx, 1)) end
DO.p_discards = function(g, o, A, ctx) add_res(A, "discards", amount(g, ctx, 1)) end
DO.p_joker_slots = function(g, o, A, ctx) add_res(A, "jslots", amount(g, ctx, 1)) end
DO.p_consumable_slots = function(g, o, A, ctx) add_res(A, "cslots", amount(g, ctx, 1)) end
DO.p_interest = function(g, o, A, ctx) A.money = A.money + 4 * amount(g, ctx, 1); note(A, money_pp(4 * amount(g, ctx, 1)), "money", 4 * amount(g, ctx, 1), "round") end
DO.p_free_rerolls = function(g, o, A, ctx) add_util(A, curve(amount(g, ctx, 1), 0.4, 3, 0.6), "rerolls", o, ctx) end
DO.p_chances = function(g, o, A, ctx) add_util(A, 0.7 * lg(math.max(1, amount(g, ctx, 1))), "chances", o, ctx) end
DO.p_debt = function(g, o, A, ctx) add_util(A, 0.01 * math.min(100, amount(g, ctx, 1)) + 0.1, "money", o, ctx) end
DO.p_rule = function(g, o, A, ctx) add_util(A, 0.6, "rule", o, ctx) end
DO.copy_ability = function(g, o, A, ctx) add_util(A, 1.2, "copy", o, ctx) end
DO.create = function(g, o, A, ctx) add_make(A, (IV[g.v] or 0.35) * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.create_rarity = function(g, o, A, ctx) add_make(A, (RV[g.v] or 0.5) * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.make_card = function(g, o, A, ctx) add_make(A, card_value(g.v) * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.tag = function(g, o, A, ctx) add_make(A, 0.4 * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.make_ed_joker = function(g, o, A, ctx) add_make(A, 0.7 * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.ed_joker = function(g, o, A, ctx) add_make(A, 0.5, o, ctx) end
DO.copy_consumable = function(g, o, A, ctx) add_make(A, g.v == "negative" and 1.2 or 0.5, o, ctx) end
DO.dup_joker = function(g, o, A, ctx) add_make(A, 1, o, ctx) end
local function small_make(v)
  return function(g, o, A, ctx) add_make(A, v * math.max(1, amount(g, ctx, 1)), o, ctx) end
end
DO.add_card, DO.add_to_hand, DO.copy_card, DO.draw = small_make(0.1), small_make(0.1), small_make(0.3), small_make(0.03)
DO.destroy_card = small_make(0.05)
DO.change = function(g, o, A, ctx) add_make(A, g.what == "enhancement" and 0.15 or g.what == "edition" and 0.3 or 0.05, o, ctx) end
DO.level_up = function(g, o, A, ctx) add_levels(A, math.max(1, num(g.n, 1)), o, ctx) end
DO.disable_boss = function(g, o, A, ctx)
  if o.once then return add_util(A, 0.5, "boss", o, ctx) end
  add_util(A, 1.5 * math.min(1, 3 * per_round(o, ctx)), "boss", o, ctx)
end
DO.destroy_joker = function(g, o, A, ctx) A.util = A.util - 0.4 * math.min(1, o.once and 1 or per_round(o, ctx)) end
DO.destroy_self = function(g, o, A, ctx)
  if o.once or o.perm then return end
  local r = per_round(o, ctx)
  if r <= 0 then return end
  local life = math.min(1, 1 / (r * 8))
  if life < A.life then A.life = life end
end
DO.save_run = function(g, o, A, ctx) add_util(A, 0.8, "save", nil, ctx) end
DO.blind_mult = function(g, o, A, ctx) A.util = A.util - 0.8 * lg(math.max(1, amount(g, ctx, 1))) * math.min(1, o.once and 1 or per_round(o, ctx)) end
DO.retrigger = function(g, o, A, ctx)
  local n = amount(g, ctx, 1) * (o.h or 0) * (o.held and 0.4 or 1)
  if o.r then n = amount(g, ctx, 1) * 0.2 end
  A.retr = A.retr + n
  note(A, curve(n, 0.3, 4, 1.5), "retrigger", amount(g, ctx, 1), freq_of(o))
end
DO.boost_retrigger = function(g, o, A, ctx) add_util(A, curve(amount(g, ctx, 1), 0.9, 2, 1.2), "boost", o, ctx) end
DO.boost_double = function(g, o, A, ctx)
  local l = 0.8 * lg(math.max(1, amount(g, ctx, 2)))
  A.xlog = A.xlog + l
  note(A, l, "boost", nil, nil)
end
local function rate_of(o, ctx, cap)
  if o.once or o.perm then return 1 end
  return math.min(cap, per_round(o, ctx))
end
Bal.STICKER_V = {eternal = -0.05, perishable = -0.2, rental = -0.2}
function Bal.sticker_v(v)
  if Bal.STICKER_V[v] then return Bal.STICKER_V[v] end
  if v == "any" then return -0.1 end
  return 0.15
end
local function sticker_do(sign, cards)
  return function(g, o, A, ctx)
    local n = cards and math.max(1, amount(g, ctx, 1)) or 1
    add_util(A, sign * Bal.sticker_v(g.v) * n * (rate_of(o, ctx, 2)), "stickers", o.once and o or nil, ctx)
  end
end
DO.stick_card, DO.stick_self = sticker_do(1, true), sticker_do(1, false)
DO.unstick_card, DO.unstick_self = sticker_do(-1, true), sticker_do(-1, false)
DO.lose_money_per = function(g, o, A, ctx) add_money(A, -amount(g, ctx, 0) * count_of(g), o, ctx) end
DO.minus_chips_per = function(g, o, A, ctx) add_score(A, "chips", -amount(g, ctx, 0) * count_of(g), o) end
DO.minus_mult_per = function(g, o, A, ctx) add_score(A, "mult", -amount(g, ctx, 0) * count_of(g), o) end
DO.var_lose_money = function(g, o, A, ctx) add_money(A, -num(g.n, 1) * var_value(ctx, tonumber(g.var) or 1), o, ctx) end
DO.var_minus_chips = function(g, o, A, ctx) add_score(A, "chips", -num(g.n, 1) * var_value(ctx, tonumber(g.var) or 1), o) end
DO.var_minus_mult = function(g, o, A, ctx) add_score(A, "mult", -num(g.n, 1) * var_value(ctx, tonumber(g.var) or 1), o) end
DO.blind_x = function(g, o, A, ctx)
  local x = math.max(1e-6, amount(g, ctx, 1))
  add_util(A, 1.5 * lg(1 / x) * rate_of(o, ctx, 1), "blind_size", o.once and o or nil, ctx)
end
DO.blind_set = function(g, o, A, ctx)
  local n = math.max(1, amount(g, ctx, 300))
  add_util(A, clamp(1.5 * lg(3000 / n), -3, 1e6) * rate_of(o, ctx, 1), "blind_size", o.once and o or nil, ctx)
end
DO.ante_move = function(g, o, A, ctx)
  local n = amount(g, ctx, 0)
  add_util(A, curve(-n, 1.2, 2, 1.5) * rate_of(o, ctx, 3), "ante", o.once and o or nil, ctx)
end
DO.level_down = function(g, o, A, ctx) add_levels(A, -math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.level_random = function(g, o, A, ctx) add_levels(A, 0.25 * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.level_most = function(g, o, A, ctx) add_levels(A, math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.level_all = function(g, o, A, ctx) add_levels(A, 10 * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.free_reroll = function(g, o, A, ctx) add_money(A, 2.5 * math.max(1, amount(g, ctx, 1)), o, ctx) end
DO.p_shop_slots = function(g, o, A, ctx) add_util(A, curve(amount(g, ctx, 1), 0.4, 3, 0.4), "shop", o, ctx) end
DO.p_reroll_off = function(g, o, A, ctx) add_util(A, 0.15 * math.min(20, amount(g, ctx, 1)), "rerolls", o, ctx) end
DO.p_free_item = function(g, o, A, ctx) add_make(A, 0.5 * math.max(1, amount(g, ctx, 1)), {perm = true}, ctx) end
DO.debuff_card = function(g, o, A, ctx) A.util = A.util - 0.1 * rate_of(o, ctx, 1) end
DO.undebuff_hand = function(g, o, A, ctx) add_util(A, 0.4 * rate_of(o, ctx, 1), "boss", o.once and o or nil, ctx) end
DO.select_round = function(g, o, A, ctx) add_util(A, 0.08 * math.max(1, amount(g, ctx, 1)), "hsize", o, ctx) end
DO.discard_drawn = small_make(0.02)
DO.next_blind = function(g, o, A, ctx) add_util(A, 1.5 * lg(1 / math.max(1e-6, amount(g, ctx, 1))) * 0.5, "blind_size", o, ctx) end
DO.next_boss_off = function(g, o, A, ctx) add_util(A, 0.5, "boss", o, ctx) end
DO.put_sticker = function(g, o, A, ctx) add_util(A, Bal.sticker_v(g.v), "stickers", o, ctx) end
Bal.NEUTRAL = {var_add = true, var_set = true, reset_gains = true, var_pick = true, next_look = true, pack_card = true}
DO.become = function(g, o, A, ctx)
  local r = ({Common = 1, Uncommon = 2, Rare = 3, Legendary = 4})[g.v] or 3
  add_util(A, 0.5 * Bal.REF.joker[r], "become", nil, ctx)
end

local USE = {
  free_pack = function(e, o, A, ctx) add_make(A, PACKV[e.v] or 0.5, o, ctx) end,
  give_pack = function(e, o, A, ctx) add_make(A, PACKV[e.v] or 0.5, o, ctx) end,
  enhance = function(e, o, A, ctx) add_util(A, (EV[e.v] or 0.2) * ctx.select, "enhance", o, ctx) end,
  seal = function(e, o, A, ctx) add_util(A, 0.2 * ctx.select, "seal", o, ctx) end,
  suit = function(e, o, A, ctx) add_util(A, 0.06 * ctx.select, "cards", o, ctx) end,
  rank_up = function(e, o, A, ctx) add_util(A, 0.05 * math.min(12, math.abs(num(e.n, 1))) * ctx.select, "cards", o, ctx) end,
  edition = function(e, o, A, ctx) add_util(A, (ED_C[ed_key(e.v)] or 0.3) * ctx.select, "edition", o, ctx) end,
  destroy = function(e, o, A, ctx) add_util(A, 0.2 * ctx.select, "cards", o, ctx) end,
  copy = function(e, o, A, ctx) add_util(A, 0.3, "cards", o, ctx) end,
  double_money = function(e, o, A, ctx) add_money(A, num(e.n, 20) * 0.75, o, ctx) end,
  level_all = function(e, o, A, ctx) add_util(A, 1.2 * math.max(1, num(e.n, 1)), "levels", o, ctx) end,
  level_random = function(e, o, A, ctx) add_util(A, 0.1 * math.max(1, num(e.n, 1)), "levels", o, ctx) end,
  destroy_random = function(e, o, A, ctx) A.once = A.once - 0.1 * num(e.n, 1) end,
  money_zero = function(e, o, A, ctx) A.once = A.once - 0.4 end,
  hand_size_minus = function(e, o, A, ctx) add_res(A, "hsize", -1) end,
  add_cards = function(e, o, A, ctx) add_util(A, 0.12 * num(e.n, 1), "cards", o, ctx) end,
  joker_edition = function(e, o, A, ctx) add_util(A, ED_J[ed_key(e.v)] or 0.6, "edition", o, ctx) end,
  rare_joker = function(e, o, A, ctx) add_make(A, RV[e.v] or RV[tonumber(e.v) or 0] or 1.3, o, ctx) end,
  hand_size_plus = function(e, o, A, ctx) add_res(A, "hsize", num(e.n, 1)) end,
  select_plus = function(e, o, A, ctx) add_res(A, "hsize", num(e.n, 1)) end,
  select_round = function(e, o, A, ctx) add_util(A, 0.08 * num(e.n, 1), "hsize", o, ctx) end,
  joker_slots_plus = function(e, o, A, ctx) add_res(A, "jslots", num(e.n, 1)) end,
  edition_joker = function(e, o, A, ctx) add_util(A, 0.6 * math.max(1, num(e.n, 1)), "edition", o, ctx) end,
  draw_cards = function(e, o, A, ctx) add_util(A, 0.02 * num(e.n, 1), "cards", o, ctx) end,
}

local TAG = {
  money_per_skip = function(e, o, A, ctx) add_money(A, num(e.n, 5) * 3, o, ctx) end,
  free_joker = function(e, o, A, ctx) add_make(A, (RV[e.v] or RV[tonumber(e.v) or 0] or 0.8) * 0.8, o, ctx) end,
  free_pack = function(e, o, A, ctx) add_make(A, PACKV[e.v] or 0.5, o, ctx) end,
  double = function(e, o, A, ctx) add_util(A, 0.4, "tags", o, ctx) end,
  hand_size = function(e, o, A, ctx) add_util(A, 0.08 * num(e.n, 1), "hsize", o, ctx) end,
  select_plus = function(e, o, A, ctx) add_res(A, "hsize", num(e.n, 1)) end,
  select_round = function(e, o, A, ctx) add_util(A, 0.08 * num(e.n, 1), "hsize", o, ctx) end,
  free_rerolls = function(e, o, A, ctx) add_util(A, 0.1 * num(e.n, 1), "rerolls", o, ctx) end,
  level_all = function(e, o, A, ctx) add_levels(A, 10 * math.max(1, num(e.n, 1)), o, ctx) end,
  coupon = function(e, o, A, ctx) add_util(A, 0.6, "shop", o, ctx) end,
  level_up = function(e, o, A, ctx) add_levels(A, num(e.n, 1), o, ctx) end,
  hands_next = function(e, o, A, ctx) add_util(A, 0.25 * num(e.n, 1), "hands", o, ctx) end,
  give_voucher = function(e, o, A, ctx) add_make(A, 0.7, o, ctx) end,
  next_edition = function(e, o, A, ctx) add_util(A, ED_J[ed_key(e.v)] or 0.6, "edition", o, ctx) end,
  boss_money = function(e, o, A, ctx) add_money(A, num(e.n, 25), o, ctx) end,
  shop_voucher = function(e, o, A, ctx) add_make(A, 0.6, o, ctx) end,
  reroll_boss = function(e, o, A, ctx) add_util(A, 0.3, "boss", o, ctx) end,
  double_money = function(e, o, A, ctx) add_money(A, num(e.n, 40) * 0.6, o, ctx) end,
  free_shop_reroll = function(e, o, A, ctx) add_util(A, 0.2, "rerolls", o, ctx) end,
}

local RUN = {
  free_pack = function(e, o, A, ctx) add_make(A, PACKV[e.v] or 0.5, o, ctx) end,
  give_pack = function(e, o, A, ctx) add_make(A, PACKV[e.v] or 0.5, o, ctx) end,
  hand_size = function(e, o, A, ctx) add_res(A, "hsize", num(e.n, 1)) end,
  select_plus = function(e, o, A, ctx) add_res(A, "hsize", num(e.n, 1)) end,
  select_set = function(e, o, A, ctx) add_res(A, "hsize", num(e.n, 5) - 5) end,
  joker_slots = function(e, o, A, ctx) add_res(A, "jslots", num(e.n, 1)) end,
  consumable_slots = function(e, o, A, ctx) add_res(A, "cslots", num(e.n, 1)) end,
  hands = function(e, o, A, ctx) add_res(A, "hands", num(e.n, 1)) end,
  discards = function(e, o, A, ctx) add_res(A, "discards", num(e.n, 1)) end,
  interest_cap = function(e, o, A, ctx) add_money(A, num(e.n, 10) / 10, o, ctx) end,
  reroll_cost = function(e, o, A, ctx) add_util(A, -0.15 * num(e.n, 0), "shop", o, ctx) end,
  discount = function(e, o, A, ctx) add_util(A, 0.016 * clamp(num(e.n, 0), -100, 100) + (num(e.n, 0) >= 100 and 3 or 0), "shop", o, ctx) end,
  shop_slots = function(e, o, A, ctx) add_util(A, curve(num(e.n, 1), 0.4, 3, 0.4), "shop", o, ctx) end,
  interest_amount = function(e, o, A, ctx) add_money(A, 4 * num(e.n, 1), o, ctx) end,
  money_per_hand = function(e, o, A, ctx) add_money(A, 1.5 * num(e.n, 1), o, ctx) end,
  money_per_discard = function(e, o, A, ctx) add_money(A, 1.5 * num(e.n, 1), o, ctx) end,
  blind_size = function(e, o, A, ctx) add_util(A, 1.5 * lg(1 / math.max(1e-6, num(e.n, 1))), "blind_size", o, ctx) end,
  probability = function(e, o, A, ctx) add_util(A, 0.7 * lg(math.max(1e-6, num(e.n, 1))), "chances", o, ctx) end,
  shop_rate = function(e, o, A, ctx) add_util(A, num(e.n, 0) > 0 and 0.25 or -0.1, "shop", o, ctx) end,
  edition_rate = function(e, o, A, ctx) add_util(A, 0.4 * lg(math.max(1e-6, num(e.n, 1))), "shop", o, ctx) end,
  rarity_weight = function(e, o, A, ctx) add_util(A, clamp(0.005 * num(e.n, 0) * (RV[e.v] or RV[tonumber(e.v) or 0] or 0.5), -1, 3), "shop", o, ctx) end,
  pack_slots = function(e, o, A, ctx) add_util(A, 0.35 * num(e.n, 1), "shop", o, ctx) end,
  voucher_slots = function(e, o, A, ctx) add_util(A, 0.4 * num(e.n, 1), "shop", o, ctx) end,
  free_rerolls = function(e, o, A, ctx) add_util(A, curve(num(e.n, 1), 0.4, 3, 0.6), "rerolls", o, ctx) end,
  ante_now = function(e, o, A, ctx) add_util(A, curve(-num(e.n, 0), 1.2, 2, 1.5), "ante", o.once and {perm = true} or o, ctx) end,
  win_ante = function(e, o, A, ctx) add_util(A, curve(8 - num(e.n, 8), 1.2, 2, 1.5, -2), "ante", {perm = true}, ctx) end,
  enhance_random = function(e, o, A, ctx) add_make(A, 0.08 * num(e.n, 1), o, ctx) end,
  add_cards = function(e, o, A, ctx) add_make(A, 0.08 * num(e.n, 1), o, ctx) end,
  joker_edition = function(e, o, A, ctx) add_make(A, ED_J[ed_key(e.v)] or 0.6, o, ctx) end,
  edition_joker = function(e, o, A, ctx) add_make(A, 0.6 * math.max(1, num(e.n, 1)), o, ctx) end,
  draw_cards = function(e, o, A, ctx) add_make(A, 0.03 * num(e.n, 1), o, ctx) end,
  omen = function(e, o, A, ctx) add_util(A, 0.3, "shop", o, ctx) end,
  telescope = function(e, o, A, ctx) add_util(A, 0.3, "shop", o, ctx) end,
  observatory = function(e, o, A, ctx) add_util(A, 0.5 * lg(math.max(1, num(e.n, 1.5))) / lg(1.5), "xmult", o, ctx) end,
  illusion = function(e, o, A, ctx) add_util(A, 0.4, "shop", o, ctx) end,
  boss_reroll = function(e, o, A, ctx) add_util(A, 0.4, "boss", o, ctx) end,
  boss_reroll_any = function(e, o, A, ctx) add_util(A, 0.6, "boss", o, ctx) end,
  dollars = function(e, o, A, ctx) add_money(A, num(e.n, 0), {once = true}, ctx) end,
  no_faces = function(e, o, A, ctx) add_util(A, 0.2, "cards", nil, ctx) end,
  remove_suit = function(e, o, A, ctx) add_util(A, 0.2, "cards", nil, ctx) end,
  add_suit = function(e, o, A, ctx) add_util(A, 0.1 * math.max(1, num(e.n, 1)), "cards", nil, ctx) end,
  enhance_all = function(e, o, A, ctx) add_util(A, (EV[e.v] or 0.2) * 10, "enhance", nil, ctx) end,
  seal_all = function(e, o, A, ctx) add_util(A, 1.5, "enhance", nil, ctx) end,
  edition_all = function(e, o, A, ctx) add_util(A, 2, "enhance", nil, ctx) end,
  remove_rank = function(e, o, A, ctx) add_util(A, 0.1, "cards", nil, ctx) end,
  next_boss = function(e, o, A, ctx) add_util(A, 0.1, "shop", o, ctx) end,
  start_voucher = function(e, o, A, ctx) add_make(A, 0.6, {once = true}, ctx) end,
  start_consumable = function(e, o, A, ctx) add_make(A, (IV[e.v] or 0.35) * math.max(1, num(e.n, 1)), {once = true}, ctx) end,
  start_card = function(e, o, A, ctx) add_make(A, card_value(e.v) * math.max(1, num(e.n, 1)), {once = true}, ctx) end,
  look = function(e, o, A, ctx) add_util(A, 1.2 / math.max(1, num(e.n, 1)), "look", nil, ctx) end,
  blind_scaling = function(e, o, A, ctx) add_util(A, -1.5 * lg(math.max(0.01, 1 + num(e.n, 0) / 100)), "blind_size", nil, ctx) end,
  discards_minus = function(e, o, A, ctx) add_res(A, "discards", -num(e.n, 1)) end,
  hands_minus = function(e, o, A, ctx) add_res(A, "hands", -num(e.n, 1)) end,
  no_interest = function(e, o, A, ctx) A.money = A.money - 3 end,
  small_no_reward = function(e, o, A, ctx) A.money = A.money - 1 end,
  prices_plus = function(e, o, A, ctx) A.util = A.util - 0.1 * math.min(30, num(e.n, 1)) end,
  eternal = function(e, o, A, ctx) A.util = A.util - 0.15 end,
  perishable = function(e, o, A, ctx) A.util = A.util - 0.15 end,
  rental = function(e, o, A, ctx) A.util = A.util - 0.15 end,
  hand_size_minus = function(e, o, A, ctx) add_res(A, "hsize", -num(e.n, 1)) end,
  select_cap = function(e, o, A, ctx) add_res(A, "hsize", -math.max(0, 5 - num(e.n, 3))) end,
  money_per_card = function(e, o, A, ctx) A.money = A.money - 0.2 * math.min(50, num(e.n, 1)) * 12 / ctx.hands end,
  discard_held = function(e, o, A, ctx) A.util = A.util - 0.1 * math.min(10, num(e.n, 1)) end,
  pack_card = function() end,
  stick_joker = function(e, o, A, ctx) DO.stick_card(e, o, A, ctx) end,
  stick_deck = function(e, o, A, ctx) DO.stick_card(e, o, A, ctx) end,
  stick_hand = function(e, o, A, ctx) DO.stick_card(e, o, A, ctx) end,
  unstick_joker = function(e, o, A, ctx) DO.unstick_card(e, o, A, ctx) end,
  unstick_deck = function(e, o, A, ctx) DO.unstick_card(e, o, A, ctx) end,
  unstick_hand = function(e, o, A, ctx) DO.unstick_card(e, o, A, ctx) end,
  stick_shop = function(e, o, A, ctx) add_util(A, 0.5 * Bal.sticker_v(e.v), "stickers", o, ctx) end,
}

local SEAL = {
  scored_money = function(e, o, A, ctx) add_money(A, num(e.n, 3), {h = 1, card = true, p = 1}, ctx) end,
  scored_retrigger = function(e, o, A, ctx) DO.retrigger({n = e.n}, {h = 1, card = true, p = 1}, A, ctx) end,
  scored_mult = function(e, o, A, ctx) add_score(A, "mult", num(e.n, 5), {h = 1, card = true, p = 1}) end,
  scored_chips = function(e, o, A, ctx) add_score(A, "chips", num(e.n, 30), {h = 1, card = true, p = 1}) end,
  scored_xmult = function(e, o, A, ctx) add_score(A, "xmult", num(e.n, 1.5), {h = 1, card = true, p = 1}) end,
  held_planet = function(e, o, A, ctx) A.make = A.make + 0.3; note(A, 0.3, "make", nil, "round") end,
  held_money = function(e, o, A, ctx) add_money(A, num(e.n, 2), {r = 1, p = 1}, ctx) end,
  discard_tarot = function(e, o, A, ctx) A.make = A.make + 0.35 * 0.8; note(A, 0.28, "make", nil, "some") end,
  discard_money = function(e, o, A, ctx) add_money(A, num(e.n, 1), {r = 0.5, p = 0.5}, ctx) end,
  held_xmult = function(e, o, A, ctx) add_score(A, "xmult", num(e.n, 1.5), {h = 1, card = true, held = true, p = 1}) end,
  held_mult = function(e, o, A, ctx) add_score(A, "mult", num(e.n, 5), {h = 1, card = true, held = true, p = 1}) end,
}

local function var_info(c, list)
  local vars = {}
  for i, v in ipairs(type(c.vars) == "table" and c.vars or {}) do
    vars[i] = {start = num(type(v) == "table" and v.start, 0), up = 0, down = 0, reset = false, set_max = 0}
    if vars[i].start ~= vars[i].start then vars[i].start = 0 end
  end
  return vars
end

local function trig(when, ctx)
  local t = (ctx.card_host and CARD_W[when]) or W[when] or {r = 0.5}
  local o = {h = t.h, r = t.r, once = t.once, perm = t.perm, card = t.card, held = t.held, discard = t.discard, hand = t.h ~= nil}
  if ctx.once_kind and when ~= "passive" then o.once = true end
  if ctx.blind_share and o.h then o.h = o.h * ctx.blind_share end
  if ctx.blind_share and o.r then o.r = o.r * ctx.blind_share end
  if ctx.card_host and o.r then o.r = o.r end
  return o
end

local function cond_p(x, ctx)
  local id = x.id
  local p
  if id == "hand" then p = HAND_P[x.v] or 0.3
  elseif id == "suit" or id == "played_suit" or id == "round_suit" then p = (x.v == "red" or x.v == "black") and 0.55 or 0.3
  elseif id == "rank" or id == "played_rank" or id == "round_rank" then p = RANK_P[x.v] or 0.1
  elseif id == "enhancement" then p = 0.06
  elseif id == "enhanced" then p = 0.15
  elseif id == "seal" then p = 0.08
  elseif id == "edition" then p = 0.05
  elseif id == "chance" then p = 1 / math.max(1, num(x.n, 4))
  elseif id == "every" then
    local i = tonumber(x.v) or tonumber(x.var)
    if i and ctx.vars[i] then
      local v = ctx.vars[i]
      p = clamp(v.up / math.max(1, num(x.n, 2)), 0.02, 1)
    else
      p = 1 / math.max(1, num(x.n, 2))
    end
  elseif id == "first_hand" or id == "last_hand" then p = 0.25
  elseif id == "first_scored" then p = 1 / 3.5
  elseif id == "first_discard" then p = 0.5
  elseif id == "once_per_discard" then p = 1 / 3.5
  elseif id == "boss" or id == "blind" then p = 1 / 3
  elseif id == "cards_played" then
    local n, op = math.floor(num(x.n, 5)), x.op
    p = 0
    for k = 1, 5 do
      if (op == "at_most" and k <= n) or (op == "exactly" and k == n) or (op ~= "at_most" and op ~= "exactly" and k >= n) then p = p + PLAYED_P[k] end
    end
  elseif id == "var" then
    local v = ctx.vars[tonumber(x.var) or 1]
    local n = num(x.n, 0)
    if not v then p = 0.5
    elseif x.op == "at_most" then
      if v.start <= n then p = v.up > 0 and 0.5 or 1 else p = v.down > 0 and clamp(v.down / (v.start - n + v.down), 0.02, 1) or 0.02 end
    elseif x.op == "exactly" then
      p = (v.start == n and v.up == 0 and v.down == 0) and 1 or 0.3
    else
      if v.start >= n then p = 1
      elseif v.up > 0 then p = clamp(v.up / (n - v.start + v.up), 0.02, 1)
      else p = v.set_max >= n and 0.5 or 0.02 end
    end
  elseif id == "all_suits" then p = 0.15
  elseif id == "held_all" then p = 0.25
  elseif id == "lucky_hit" then p = 0.05
  elseif id == "round_card" then p = 0.08
  elseif id == "round_hand" then p = 0.2
  elseif id == "lowest_held" then p = 1 / 3
  elseif id == "no_discard" then p = 0.3
  elseif id == "used_kind" then p = 0.4
  elseif id == "other_rarity" then p = 0.3
  elseif id == "suit_and_other" then p = 0.3
  elseif id == "discarded" then p = 0.3
  elseif id == "boss_triggered" then p = 0.3
  elseif (x.op == "at_least" and num(x.n, 1) <= 0) then p = 1
  else p = 0.5 end
  if x.neg then p = 1 - p end
  return clamp(p, 0, 1)
end

local function rule_p(r, ctx, skip_var)
  local p = 1
  for _, x in ipairs(type(r.only) == "table" and r.only or {}) do
    if type(x) == "table" and not (skip_var and (x.id == "var" or x.id == "every")) then p = p * cond_p(x, ctx) end
  end
  return p
end

local function scan_round(rules, ctx)
  local tmp = {}
  for i, v in ipairs(ctx.vars) do tmp[i] = {up = 0, down = 0} end
  for _, r in ipairs(rules) do
    if type(r) == "table" then
      local o = trig(r.when, ctx)
      local per_hand = o.h or (o.r and o.r / ctx.hands) or 0
      if o.once or o.perm then per_hand = 0 end
      local p = rule_p(r, ctx, false)
      for li, list in ipairs({r.give, r.alt}) do
        local w = per_hand * (li == 1 and p or (1 - p))
        for _, g in ipairs(type(list) == "table" and list or {}) do
          local t = type(g) == "table" and g.id == "var_add" and tmp[tonumber(g.var) or 1]
          if t then
            local n = num(g.n, 1)
            if n > 0 then t.up = t.up + n * w else t.down = t.down - n * w end
          end
        end
      end
    end
  end
  for i, v in ipairs(ctx.vars) do v.up, v.down = tmp[i].up, tmp[i].down end
end

local function scan_vars(rules, ctx)
  for _, r in ipairs(rules) do
    if type(r) == "table" then
      local o = trig(r.when, ctx)
      local per_hand = o.h or (o.r and o.r / ctx.hands) or 0
      if o.once or o.perm then per_hand = 0 end
      local p = rule_p(r, ctx, true)
      for li, list in ipairs({r.give, r.alt}) do
        local w = per_hand * (li == 1 and p or (1 - p))
        for _, g in ipairs(type(list) == "table" and list or {}) do
          local v = type(g) == "table" and ctx.vars[tonumber(g.var) or 1]
          if v and g.id == "var_add" then
            local n = num(g.n, 1)
            if n > 0 then v.up = v.up + n * w else v.down = v.down - n * w end
          elseif v and g.id == "var_set" then
            local n = num(g.n, 0)
            if n < v.start or n == 0 then v.reset = true end
            if n > v.set_max then v.set_max = n end
          elseif v and g.id == "var_pick" then
            v.reset = true
          end
          if type(g) == "table" and g.id == "reset_gains" then ctx.window = Bal.SHORT end
        end
      end
    end
  end
end

local function eval_rules(rules, A, ctx)
  for _, r in ipairs(rules) do
    if type(r) == "table" then
      local base = trig(r.when, ctx)
      local p = rule_p(r, ctx, base.once and not ctx.once_kind)
      for li, list in ipairs({r.give, r.alt}) do
        local q = li == 1 and p or (1 - p)
        if type(list) == "table" and #list > 0 and q > 0 then
          local o = {h = base.h and base.h * q, r = base.r and base.r * q, once = base.once, perm = base.perm, card = base.card, held = base.held, hand = base.hand, p = q}
          if base.once and q < 1 and not base.perm then o.scale = q end
          for _, g in ipairs(list) do
            local f = type(g) == "table" and DO[g.id]
            if type(g) == "table" and (g.run or not f) and RUN[g.id] then f = RUN[g.id] end
            if f then
              if o.scale then
                local B = new_acc()
                f(g, o, B, ctx)
                for k, v in pairs(B) do if type(v) == "number" and k ~= "life" and k ~= "top_pp" then A[k] = A[k] + v * o.scale end end
                if B.top and B.top_pp * o.scale > A.top_pp then A.top, A.top_pp = B.top, B.top_pp * o.scale end
                if B.life < A.life then A.life = B.life end
              else
                f(g, o, A, ctx)
              end
            end
          end
        end
      end
    end
  end
end

local function eval_effects(effects, map, A, ctx)
  for _, e in ipairs(type(effects) == "table" and effects or {}) do
    if type(e) == "table" then
      local f = map[e.id] or RUN[e.id] or DO[e.id]
      local o
      if e.when and e.when ~= "now" then
        o = trig(e.when, ctx)
        o.p = 1
        local p = 1
        for _, x in ipairs(type(e.only) == "table" and e.only or {}) do if type(x) == "table" then p = p * cond_p(x, ctx) end end
        if o.h then o.h = o.h * p end
        if o.r then o.r = o.r * p end
        o.p = p
      else
        o = ctx.once_kind and {once = true, p = 1} or (e.when == "now" and {once = true, p = 1} or {perm = true, p = 1})
      end
      if ctx.kind == "blind" and BOSS_HARM[e.id] then
        local h = BOSS_HARM[e.id]
        if e.id == "hand_size_minus" then h = 0.3 * math.min(10, num(e.n, 1)) end
        A.util = A.util - h
      elseif f then
        f(e, o, A, ctx)
      elseif e.id == "money" then
        add_money(A, num(e.n, 0), o.perm and {once = true} or o, ctx)
      end
    end
  end
end

local function edition_fields(f, A, o)
  add_score(A, "chips", num(f.chips, 0), o)
  add_score(A, "mult", num(f.mult, 0), o)
  if num(f.xmult, 1) > 1 then add_score(A, "xmult", num(f.xmult, 1), o) end
end

local function always(c, A, ctx)
  local v = c.always_ed
  if type(v) == "table" then v = v.v or v.key or v.id end
  if type(v) ~= "string" then return end
  local k = ed_key(v)
  local o = {h = 1, p = 1}
  if k == "foil" then add_score(A, "chips", 50, o)
  elseif k == "holo" then add_score(A, "mult", 10, o)
  elseif k == "polychrome" then add_score(A, "xmult", 1.5, o)
  elseif k == "negative" then add_res(A, ctx.kind == "joker" and "jslots" or "cslots", 1)
  else add_util(A, 0.6, "edition", nil, ctx) end
end

local function planet(c, A, ctx)
  local f = type(c.fields) == "table" and c.fields or {}
  local lv = math.max(0, num(f.levels, 1)) * (math.max(0, num(f.chips, 15)) / 30 + math.max(0, num(f.mult, 1)) / 3)
  if f.hand == "all" or f.hand == "All" then lv = lv * 6 end
  local pp = lv <= 5 and 0.3 * lv or 1.5 + 0.8 * lg(lv / 5)
  A.once = A.once + pp
  note(A, pp, "planet", nil, "once")
end

local function booster(c, A, ctx)
  local f = type(c.fields) == "table" and c.fields or {}
  local size = f.size or "Normal"
  local choose = num(f.choose, size == "Mega" and 2 or 1)
  local cost = math.max(0.5, num(f.cost, 4))
  local iv = PACKV[f.pack] or 0.4
  local cards = {}
  for _, e in ipairs(type(c.effects) == "table" and c.effects or {}) do
    if type(e) == "table" and e.id == "pack_card" then cards[#cards + 1] = card_value(e.v) end
  end
  if #cards > 0 then
    local s = 0
    for _, v in ipairs(cards) do s = s + v end
    iv = s / #cards
  end
  local pp = choose * iv * math.min(2, 4 / cost)
  A.util = A.util + pp
  note(A, pp, "pack", nil, nil)
end

local function enhancement(c, A, ctx)
  local f = type(c.fields) == "table" and c.fields or {}
  local o = {h = 1, card = true, p = 1}
  edition_fields(f, A, o)
  if num(f.money, 0) ~= 0 then add_money(A, num(f.money, 0), {r = 1, p = 1}, ctx) end
  if num(f.held_xmult, 1) > 1 then add_score(A, "xmult", num(f.held_xmult, 1), {h = 1, card = true, held = true, p = 1}) end
  if num(f.held_money, 0) ~= 0 then add_money(A, num(f.held_money, 0), {r = 1, p = 1}, ctx) end
  if num(f.retrigger, 0) > 0 then DO.retrigger({n = f.retrigger}, o, A, ctx) end
  if f.always then A.util = A.util + 0.1 end
  if f.any_suit then A.util = A.util + 0.15 end
  if f.no_rank then A.util = A.util - 0.05 end
  local b = num(f.breaks, 0)
  if b >= 1 then A.life = math.min(A.life, b / 8) end
end

local function edition(c, A, ctx)
  local f = type(c.fields) == "table" and c.fields or {}
  edition_fields(f, A, {h = 1, p = 1})
  if f.slot then add_res(A, "jslots", 1) end
  if num(f.sell, 0) > 0 then add_money(A, num(f.sell, 0) * 0.3, {r = 1, p = 1}, ctx) end
end

local function blind(c, A, ctx)
  local f = type(c.fields) == "table" and c.fields or {}
  local size = math.max(0.0001, num(f.size, 2))
  A.util = A.util + 0.5 * lg(2 / size) * (size < 1 and 3 or 1)
  local reward = num(f.reward, 5)
  if reward ~= 5 then A.money = A.money + (reward - 5) / 3 end
  if reward > 5 then note(A, money_pp((reward - 5) / 3), "money", round2((reward - 5) / 3), "round") end
end

function Bal.score(c)
  local kind = type(c) == "table" and c.kind or "joker"
  if type(c) ~= "table" then return 0, nil, new_acc() end
  local A = new_acc()
  local ctx = {kind = kind, hands = Bal.HANDS, window = Bal.WINDOW, once_w = Bal.ONCE[kind] and 1 or 0.5,
    once_kind = Bal.ONCE[kind] or false, card_host = Bal.CARD_HOST[kind] or false, select = 1}
  local f = type(c.fields) == "table" and c.fields or {}
  if kind == "tarot" or kind == "spectral" then ctx.select = clamp(num(f.select, 1), 1, 100) end
  if kind == "blind" then ctx.blind_share = 1 / 3 end
  if kind == "seal" then ctx.hands = 1 end
  if Bal.CARD_HOST[kind] then ctx.hands = 1 end
  local rules = type(c.rules) == "table" and c.rules or {}
  ctx.vars = var_info(c)
  scan_vars(rules, ctx)
  if #ctx.vars > 0 then for _ = 1, 4 do scan_round(rules, ctx) end end
  if kind == "planet" then planet(c, A, ctx)
  elseif kind == "booster" then booster(c, A, ctx)
  elseif kind == "enhancement" then enhancement(c, A, ctx)
  elseif kind == "edition" then edition(c, A, ctx)
  elseif kind == "blind" then blind(c, A, ctx) end
  local map = RUN
  if kind == "tarot" or kind == "spectral" or kind == "planet" then map = USE
  elseif kind == "tag" then map = TAG
  elseif kind == "seal" then map = SEAL end
  if kind ~= "booster" then eval_effects(c.effects, map, A, ctx) end
  eval_rules(rules, A, ctx)
  always(c, A, ctx)
  local mult = math.max(-0.9 * Bal.M0, A.mult)
  local chips = math.max(-0.9 * Bal.C0, A.chips)
  local score = lg(1 + mult / Bal.M0) + lg(1 + chips / Bal.C0) + A.xlog + A.exp
  local rh, rd, rs, rj, rc = curve(A.hands, 0.7, 3, 1.2), curve(A.discards, 0.35, 3, 0.6), curve(A.hsize, 0.45, 4, 0.6), curve(A.jslots, 0.9, 3, 0.8), curve(A.cslots, 0.25, 3, 0.4)
  local res = rh + rd + rs + rj + rc
  note(A, rh, "hands", round2(A.hands), nil)
  note(A, rd, "discards", round2(A.discards), nil)
  note(A, rs, "hsize", round2(A.hsize), nil)
  note(A, rj, "jslots", round2(A.jslots), nil)
  note(A, rc, "cslots", round2(A.cslots), nil)
  local stream = curve(A.retr, 0.3, 4, 1.5) + curve(A.make, 1, 1.5, 0.8) + curve(A.levels, 0.12, 10, 0.8) + money_pp(A.money) + A.util
  local once = ctx.once_w * (curve(A.once, 1, 3, 0.6, -2) + once_money_pp(A.once_money))
  local pos = score + res + stream + once
  if A.life < 1 and pos > 0 then pos = pos * A.life end
  local P = round2(pos)
  if P ~= P then P = 0 end
  local flag = A.money >= 100 or A.once_money >= 500
  return P, flag, A
end

local function ref_of(c)
  local kind = c.kind or "joker"
  local r = Bal.REF[kind]
  if kind == "joker" then return r[clamp(math.floor(num(c.rarity, 1)), 1, 4)] end
  if kind == "voucher" then
    local f = type(c.fields) == "table" and c.fields or {}
    return (type(f.requires) == "string" and f.requires ~= "none") and r[2] or r[1]
  end
  return r
end
Bal.ref_of = ref_of

function Bal.level_of(c, P, flag)
  local kind = c.kind or "joker"
  if kind == "collab" or kind == "suit" or kind == "hand" or kind == "ctype" or kind == "challenge" or kind == "rarity" or kind == "sticker" or kind == "fusion" then return "fair" end
  if flag or P >= Bal.BROKEN_AT then return "broken" end
  if Bal.HARM[kind] then
    if P <= Bal.HARM_FAIR then return "fair" end
    if P <= Bal.HARM_STRONG then return "strong" end
    return "op"
  end
  local ref = ref_of(c) or 0.5
  if P >= Bal.OP_AT or P > ref * Bal.OP_R then return "op" end
  if P > ref * Bal.STRONG_R then return "strong" end
  if P < ref * Bal.WEAK_R then return "weak" end
  return "fair"
end

function Bal.tier_above(c, P)
  local kind = c.kind or "joker"
  if kind == "joker" then
    local best = nil
    for i, r in ipairs(Bal.TIER_P) do if P > r then best = i end end
    return "joker" .. (best or 1)
  end
  return kind
end

function Bal.compute(c)
  local P, flag, A = Bal.score(c)
  local level = Bal.level_of(c, P, flag)
  local own = (c.kind or "joker") == "joker" and ("joker" .. clamp(math.floor(num(c.rarity, 1)), 1, 4)) or (c.kind or "joker")
  return {level = level, score = P, top = A.top, own = own, above = Bal.tier_above(c, P), kind = c.kind or "joker"}
end

local function canon(v, out)
  local t = type(v)
  if t == "number" then
    if v ~= v then out[#out + 1] = "n:nan" else out[#out + 1] = string.format("n:%.17g", v) end
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
  elseif t == "table" then
    local keys = {}
    for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      local x = v[k]
      local tx = type(x)
      if tx == "number" or tx == "string" or tx == "boolean" or tx == "table" then
        canon(k, out)
        out[#out + 1] = "="
        canon(x, out)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  else out[#out + 1] = "_" end
end

Bal.CONTENT = {"kind", "rarity", "own_rarity", "rules", "vars", "fields", "effects", "always_ed"}

function Bal.content_key(c)
  local out = {}
  for _, k in ipairs(Bal.CONTENT) do
    out[#out + 1] = k
    canon(c[k], out)
    out[#out + 1] = ";"
  end
  return table.concat(out)
end

Bal.by_table = setmetatable({}, {__mode = "k"})
Bal.by_content = {}
Bal.content_n = 0
Bal.gen = 0

function Bal.rate_fresh(c)
  if type(c) ~= "table" then return nil end
  local key = Bal.content_key(c)
  local res = Bal.by_content[key]
  if not res then
    local ok, r = pcall(Bal.compute, c)
    res = ok and r or {level = "fair", score = 0, own = "joker1", above = "joker1", kind = c.kind or "joker"}
    if Bal.content_n >= 2048 then Bal.by_content, Bal.content_n = {}, 0 end
    Bal.by_content[key] = res
    Bal.content_n = Bal.content_n + 1
  end
  Bal.by_table[c] = res
  return res
end

function Bal.of(c)
  if type(c) ~= "table" then return nil end
  return Bal.by_table[c] or Bal.rate_fresh(c)
end

function Bal.is_broken(c)
  local r = Bal.of(c)
  return r ~= nil and r.level == "broken"
end

function Bal.store(S)
  local base_clean, base_item = S.clean, S.clean_item
  S.base_clean, S.base_clean_item = base_clean, base_item
  S.clean = function(c)
    local out = base_clean(c)
    if out then
      Bal.by_table[out] = nil
      Bal.rate_fresh(out)
      Bal.gen = Bal.gen + 1
    end
    return out
  end
  S.clean_item = function(c)
    local out = base_item(c)
    if out then
      Bal.by_table[out] = nil
      Bal.rate_fresh(out)
      Bal.gen = Bal.gen + 1
    end
    return out
  end
end


local function lang()
  local l = G and G.SETTINGS and G.SETTINGS.language or "en-us"
  if l == "fr" then return "fr" end
  if type(l) == "string" and l:sub(1, 2) == "es" then return "es" end
  return "en"
end
Bal.lang = lang

Bal.TEXT = {
  en = {
    weak = "Weak", fair = "Fair", strong = "Strong", op = "Overpowered", broken = "Broken",
    l_weak = "%s: below %s", l_fair = "%s: in line with %s", l_strong = "%s: %s is above %s", l_op = "%s: %s is far above %s", l_broken = "%s: %s, progress turns off",
    looks = "%s: looks only",
    joker1 = "Common Jokers", joker2 = "Uncommon Jokers", joker3 = "Rare Jokers", joker4 = "Legendary Jokers",
    tarot = "Tarot cards", planet = "Planet cards", spectral = "Spectral cards", voucher = "Vouchers", enhancement = "Enhancements", seal = "Seals",
    edition = "Editions", tag = "Tags", booster = "Booster packs", deck = "Decks", stake = "Stakes", blind = "Boss Blinds",
    mult = "+%s Mult", chips = "+%s Chips", xmult = "X%s Mult", xchips = "X%s Chips", emult = "^%s Mult", echips = "^%s Chips",
    gain_mult = "gaining +%s Mult", gain_chips = "gaining +%s Chips", gain_xmult = "gaining X%s Mult",
    money = "$%s a round", money_once = "$%s at once", retrigger = "retriggers", make = "making cards", levels = "hand levels",
    hands = "extra hands", discards = "extra discards", hsize = "hand size", jslots = "Joker slots", cslots = "consumable slots",
    boss = "beating Boss Blinds", stickers = "stickers", copy = "copying Jokers", rule = "its rule", chances = "better chances", rerolls = "free rerolls",
    shop = "shop perks", blind_size = "smaller blinds", ante = "ante changes", enhance = "enhancing cards", edition_fx = "editions",
    seal_fx = "seals", cards = "changing cards", perma = "permanent Chips", look = "card looks", boost = "boosting Jokers",
    become = "growing up", save = "saving the run", planet_fx = "hand levels", pack = "its pack contents", tags = "tags", effects = "its effects",
    f_hand = "every hand", f_often = "often", f_some = "sometimes", f_scored = "per scored card", f_held = "per held card", f_round = "each round",
    pack_up = "Balance: up to %s", pack_broken = "Broken: %s (progress off)",
    progress = "Broken Forge content",
  },
  fr = {
    weak = "Faible", fair = "Équilibré", strong = "Fort", op = "Surpuissant", broken = "Cassé",
    l_weak = "%s : en dessous des %s", l_fair = "%s : comme les %s", l_strong = "%s : %s dépasse les %s", l_op = "%s : %s dépasse de loin les %s", l_broken = "%s : %s, la progression se coupe",
    looks = "%s : apparence seulement",
    joker1 = "Jokers communs", joker2 = "Jokers peu communs", joker3 = "Jokers rares", joker4 = "Jokers légendaires",
    tarot = "cartes Tarot", planet = "cartes Planète", spectral = "cartes Spectrales", voucher = "Bons", enhancement = "Améliorations", seal = "Sceaux",
    edition = "Éditions", tag = "Badges", booster = "Paquets", deck = "Jeux", stake = "Mises", blind = "Blindes Boss",
    mult = "+%s Multi", chips = "+%s jetons", xmult = "X%s Multi", xchips = "X%s jetons", emult = "^%s Multi", echips = "^%s jetons",
    gain_mult = "gagner +%s Multi", gain_chips = "gagner +%s jetons", gain_xmult = "gagner X%s Multi",
    money = "%s $ par manche", money_once = "%s $ d'un coup", retrigger = "les relances", make = "créer des cartes", levels = "les niveaux de main",
    hands = "les mains en plus", discards = "les défausses en plus", hsize = "la taille de main", jslots = "les places de Joker", cslots = "les places de consommable",
    boss = "battre les Blindes Boss", stickers = "les autocollants", copy = "copier des Jokers", rule = "sa règle", chances = "les chances", rerolls = "les relances gratuites",
    shop = "les avantages en boutique", blind_size = "les blindes plus petites", ante = "changer la mise de départ", enhance = "améliorer des cartes", edition_fx = "les éditions",
    seal_fx = "les sceaux", cards = "changer des cartes", perma = "les jetons permanents", look = "l'apparence des cartes", boost = "renforcer des Jokers",
    become = "grandir", save = "sauver la partie", planet_fx = "les niveaux de main", pack = "le contenu du paquet", tags = "les badges", effects = "ses effets",
    f_hand = "à chaque main", f_often = "souvent", f_some = "parfois", f_scored = "par carte jouée", f_held = "par carte en main", f_round = "à chaque manche",
    pack_up = "Équilibre : jusqu'à %s", pack_broken = "Cassé : %s (pas de progression)",
    progress = "contenu de la Forge cassé",
  },
  es = {
    weak = "Débil", fair = "Justo", strong = "Fuerte", op = "Excesivo", broken = "Roto",
    l_weak = "%s: por debajo de los %s", l_fair = "%s: como los %s", l_strong = "%s: %s supera a los %s", l_op = "%s: %s supera con creces a los %s", l_broken = "%s: %s, el progreso se desactiva",
    looks = "%s: solo aspecto",
    joker1 = "Jokers comunes", joker2 = "Jokers poco comunes", joker3 = "Jokers raros", joker4 = "Jokers legendarios",
    tarot = "cartas de Tarot", planet = "cartas de Planeta", spectral = "cartas Espectrales", voucher = "Vales", enhancement = "Mejoras", seal = "Sellos",
    edition = "Ediciones", tag = "Etiquetas", booster = "Sobres", deck = "Barajas", stake = "Apuestas", blind = "Ciegas jefe",
    mult = "+%s multi", chips = "+%s fichas", xmult = "X%s multi", xchips = "X%s fichas", emult = "^%s multi", echips = "^%s fichas",
    gain_mult = "ganar +%s multi", gain_chips = "ganar +%s fichas", gain_xmult = "ganar X%s multi",
    money = "%s $ por ronda", money_once = "%s $ de golpe", retrigger = "las repeticiones", make = "crear cartas", levels = "los niveles de mano",
    hands = "las manos extra", discards = "los descartes extra", hsize = "el tamaño de mano", jslots = "los espacios de Joker", cslots = "los espacios de consumible",
    boss = "vencer Ciegas jefe", stickers = "las pegatinas", copy = "copiar Jokers", rule = "su regla", chances = "las probabilidades", rerolls = "las tiradas gratis",
    shop = "las ventajas de tienda", blind_size = "las ciegas más pequeñas", ante = "cambiar la apuesta inicial", enhance = "mejorar cartas", edition_fx = "las ediciones",
    seal_fx = "los sellos", cards = "cambiar cartas", perma = "las fichas permanentes", look = "el aspecto de las cartas", boost = "potenciar Jokers",
    become = "crecer", save = "salvar la partida", planet_fx = "los niveles de mano", pack = "el contenido del sobre", tags = "las etiquetas", effects = "sus efectos",
    f_hand = "en cada mano", f_often = "a menudo", f_some = "a veces", f_scored = "por carta jugada", f_held = "por carta en mano", f_round = "cada ronda",
    pack_up = "Equilibrio: hasta %s", pack_broken = "Roto: %s (sin progreso)",
    progress = "contenido de la Forja roto",
  },
}
Bal.FX_KEY = {edition = "edition_fx", seal = "seal_fx", planet = "planet_fx"}

function Bal.t(key, l)
  local T = Bal.TEXT[l or lang()] or Bal.TEXT.en
  return T[key] or Bal.TEXT.en[key] or key
end

function Bal.fmt_n(n)
  n = num(n, 0)
  local a = math.abs(n)
  if a >= 1e9 then return (string.format("%.3g", n):gsub("e%+0*", "e")) end
  if n == math.floor(n) then return string.format("%d", n) end
  local s = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
  return s
end

local AMOUNT = {mult = true, chips = true, xmult = true, xchips = true, emult = true, echips = true, gain_mult = true, gain_chips = true, gain_xmult = true, money = true, money_once = true}
local NO_FREQ = {money = true, money_once = true}

function Bal.cause(res, l)
  local top = res and res.top
  if not top then return Bal.t("effects", l) end
  local key = Bal.FX_KEY[top.key] or top.key
  local s = Bal.t(key, l)
  if AMOUNT[top.key] and top.n then s = string.format(s, Bal.fmt_n(top.n)) end
  if top.freq and not NO_FREQ[top.key] and Bal.TEXT.en["f_" .. top.freq] then s = s .. " " .. Bal.t("f_" .. top.freq, l) end
  return s
end

function Bal.line(res, l)
  if not res then return "" end
  l = l or lang()
  local name = Bal.t(res.level, l)
  if res.kind == "collab" then return string.format(Bal.t("looks", l), name) end
  local lv = res.level
  if lv == "weak" or lv == "fair" then return string.format(Bal.t("l_" .. lv, l), name, Bal.t(res.own, l)) end
  if lv == "broken" then return string.format(Bal.t("l_broken", l), name, Bal.cause(res, l)) end
  local tier = res.above
  if Bal.RANK[lv] and res.kind == "joker" and tier < res.own then tier = res.own end
  return string.format(Bal.t("l_" .. lv, l), name, Bal.cause(res, l), Bal.t(tier, l))
end

function Bal.colour(level)
  local C = G and G.C or {}
  if level == "weak" then return {0.42, 0.47, 0.53, 1} end
  if level == "fair" then return C.GREEN or {0.3, 0.7, 0.4, 1} end
  if level == "strong" then return C.FILTER or C.ORANGE or {1, 0.6, 0.1, 1} end
  if level == "op" then return C.RED or {0.9, 0.3, 0.3, 1} end
  return {0.56, 0.3, 0.82, 1}
end

function Bal.text_colour(level)
  if level == "weak" then return (G and G.C and G.C.UI and G.C.UI.TEXT_INACTIVE) or {0.7, 0.7, 0.7, 1} end
  if level == "broken" then return {0.78, 0.56, 1, 1} end
  return Bal.colour(level)
end

function Bal.draft_res(d)
  if type(d) ~= "table" then return nil end
  local S = package.loaded["functions/forge/forge_store"]
  if not S then return nil end
  local src = {}
  for k, v in pairs(d) do src[k] = v end
  if tostring(src.id or ""):gsub("[^%w]", "") == "" then src.id = "draft" end
  local ok, clean
  if (d.kind or "joker") == "joker" then ok, clean = pcall(S.base_clean or S.clean, src) else ok, clean = pcall(S.base_clean_item or S.clean_item, src) end
  if not (ok and clean) then return nil end
  if (d.kind or "joker") ~= "joker" then clean.kind = d.kind end
  return Bal.rate_fresh(clean)
end

local NONE = {}
Bal.slots = {}

local function source(i, S)
  if i == 1 then return S.list or NONE end
  if i == 2 then return S.items_list or NONE end
  local E = S.extra
  if i == 3 then return E and E.jokers or NONE end
  if i == 4 then return E and E.items or NONE end
  local R = S.room
  if i == 5 then return R and R.jokers or NONE end
  return R and R.items or NONE
end

function Bal.broken_set()
  local S = package.loaded["functions/forge/forge_store"]
  if not S then return NONE end
  if not S.list then pcall(S.all) end
  if not S.items_list then pcall(S.items) end
  local slots = Bal.slots
  local same = Bal.set ~= nil and slots.gen == Bal.gen
  for i = 1, 6 do
    local l = source(i, S)
    if slots[i] ~= l or slots[i + 6] ~= #l then same = false end
  end
  if same then return Bal.set end
  local set = {}
  for i = 1, 6 do
    local l = source(i, S)
    slots[i], slots[i + 6] = l, #l
    for _, c in ipairs(l) do
      if type(c) == "table" and c.id and set[c.id] == nil and Bal.is_broken(c) then
        set[c.id] = tostring(c.name or c.id)
      end
    end
  end
  slots.gen = Bal.gen
  Bal.set = set
  return set
end

function Bal.id_of_key(key)
  if type(key) ~= "string" then return nil end
  return key:match("_(%w+)$")
end

function Bal.key_broken(key)
  local id = Bal.id_of_key(key)
  if not id then return nil end
  return Bal.broken_set()[id]
end

function Bal.id_broken(id)
  if type(id) ~= "string" then return nil end
  return Bal.broken_set()[id]
end

Bal.POOL_SKIP = {deck = true, stake = true, collab = true, suit = true, hand = true, ctype = true, challenge = true, rarity = true, sticker = true, fusion = true}

function Bal.pool_broken()
  local S = package.loaded["functions/forge/forge_store"]
  if not S then return nil end
  for _, fn in ipairs({"live_jokers", "live_items"}) do
    local ok, list = pcall(S[fn])
    for _, c in ipairs(ok and type(list) == "table" and list or {}) do
      if type(c) == "table" and c.enabled ~= false and not Bal.POOL_SKIP[c.kind or "joker"] and Bal.is_broken(c) then
        return tostring(c.name or c.id)
      end
    end
  end
  return nil
end

function Bal.worst(list)
  local best, name = nil, nil
  for _, c in ipairs(type(list) == "table" and list or {}) do
    local r = Bal.of(c)
    if r and (not best or Bal.RANK[r.level] > Bal.RANK[best]) then best, name = r.level, c.name end
  end
  return best, name
end

function Bal.pack_line(list, l)
  local lv, name = Bal.worst(list)
  if not lv then return nil end
  if lv == "broken" then return string.format(Bal.t("pack_broken", l), tostring(name or "")), lv end
  return string.format(Bal.t("pack_up", l), Bal.t(lv, l)), lv
end

local function tw(text, scale)
  if UIK and UIK.text_w then return UIK.text_w(text, scale) end
  return #text * scale * 0.3
end

function Bal.pill(level, o)
  o = o or {}
  local label = Bal.t(level)
  local scale = o.scale or 0.32
  local w = math.max(o.minw or 0, tw(label, scale) + 0.24)
  if o.maxw and w > o.maxw then
    scale = scale * (o.maxw - 0.24) / math.max(0.01, tw(label, scale))
    w = o.maxw
  end
  return {n = G.UIT.C, config = {align = "cm", r = 0.08, colour = Bal.colour(level), minw = w, minh = o.h or (scale * 1.25 + 0.06), padding = 0.02, shadow = o.shadow}, nodes = {
    {n = G.UIT.T, config = {text = label, scale = scale, colour = G.C.WHITE, shadow = true}},
  }}
end

function Bal.wrap(text, scale, w, max)
  if UIK and UIK.wrap then
    local ok, lines = pcall(UIK.wrap, text, scale, w, max)
    if ok and type(lines) == "table" and #lines > 0 then return lines end
  end
  return {text}
end

function Bal.builder_node(d, w, o)
  o = o or {}
  if type(d) == "table" and (d.kind == "suit" or d.kind == "hand" or d.kind == "ctype" or d.kind == "challenge" or d.kind == "rarity" or d.kind == "sticker" or d.kind == "fusion") then return nil end
  local res = Bal.draft_res(d)
  if not res then return nil end
  local line = Bal.line(res)
  local scale = o.scale or 0.3
  local text = line:gsub("^[^:]*:%s*", "")
  local pill = Bal.pill(res.level, {scale = scale + 0.02})
  local lines = Bal.wrap(text, scale, w - 0.2, 2)
  if #lines > 2 then lines = {lines[1], lines[2]} end
  local rows = {{n = G.UIT.R, config = {align = "cm", padding = 0.02}, nodes = {pill}}}
  for _, s in ipairs(lines) do
    rows[#rows + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.005}, nodes = {
      {n = G.UIT.T, config = {text = s, scale = scale, colour = (UIK and UIK.C and UIK.C.muted) or G.C.UI.TEXT_LIGHT, shadow = true}},
    }}
  end
  local node = {n = G.UIT.R, config = {align = "cm", minw = w, maxw = w, padding = 0.03, id = "forge_balance"}, nodes = {
    {n = G.UIT.C, config = {align = "cm"}, nodes = rows},
  }}
  node.bal_h = (scale + 0.02) * 1.25 + 0.16 + #lines * (scale * 1.1 + 0.02)
  return node, res
end

function Bal.loc_register()
  local reg = rawget(_G, "mod_loc_register")
  if not reg or Bal.registered then return end
  Bal.registered = true
  reg{fr = {["Broken Forge content"] = Bal.TEXT.fr.progress}, es = {["Broken Forge content"] = Bal.TEXT.es.progress}}
end
Bal.loc_register()


Bal.MAPS = {USE = USE, TAG = TAG, RUN = RUN, SEAL = SEAL, DO = DO, BOSS = BOSS_HARM}

return Bal
