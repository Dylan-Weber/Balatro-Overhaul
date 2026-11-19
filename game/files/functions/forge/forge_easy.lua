local E = {}

local function loc(s) return mod_loc and mod_loc(s) or s end

E.GROUP_LABEL = {
  all = "All", score = "Score", grow = "Grows", money = "Money", cards = "Cards", jokers = "Jokers", round = "Hands and round", run = "Run and shop",
  vars = "Variables", lose = "Downsides", other = "Other",
  card = "The card", hand = "The hand", state = "The run", deck = "Hand and deck", discard = "Discards", luck = "Luck",
  during = "During a hand", rounds = "Rounds and blinds", shop = "Shop and packs", always = "Always",
}

E.ORDER = {
  give = {"score", "grow", "money", "cards", "jokers", "round", "run", "vars", "lose", "other"},
  only = {"card", "hand", "deck", "discard", "state", "jokers", "luck", "vars", "other"},
  when = {"during", "discard", "rounds", "shop", "cards", "always", "other"},
}

local function set(group, ids, map)
  for id in ids:gmatch("%S+") do map[id] = group end
end

E.GROUP = {give = {}, only = {}, when = {}}
do
  local g = E.GROUP.give
  set("score", "chips mult xmult xchips echips emult retrigger rand_mult rank_mult chips_per mult_per xmult_per", g)
  set("grow", "gain_chips gain_mult gain_xmult gain_xchips gain_mult_per gain_xmult_per reset_gains sell_value perma_chips", g)
  set("money", "money money_per var_money p_interest p_debt", g)
  set("cards", "create change destroy_card add_card copy_card make_card create_rarity add_to_hand", g)
  set("cards", "strip_enh draw debuff_card undebuff_hand stick_card unstick_card discard_drawn cancel_discard copy_consumable", g)
  set("jokers", "destroy_self destroy_joker copy_ability dagger sell_all dup_joker make_ed_joker ed_joker become", g)
  set("jokers", "next_look boost_retrigger boost_double boost_mult boost_chips boost_xmult stick_self unstick_self p_joker_slots p_consumable_slots", g)
  set("round", "level_up hand discard level_random level_most p_hand_size p_hand_size_var p_hands p_discards p_select select_plus select_round", g)
  set("run", "tag disable_boss blind_x blind_set ante_move free_reroll p_shop_slots p_reroll_off p_free_item p_free_rerolls p_chances p_rule save_run", g)
  set("vars", "var_add var_set var_pick var_chips var_mult var_xmult var_xchips", g)
  set("lose", "minus_chips minus_mult div_mult lose_money lose_hands lose_discard lose_discards lose_hand_size", g)
  set("lose", "lose_money_per minus_chips_per minus_mult_per var_lose_money var_minus_chips var_minus_mult level_down blind_mult", g)
  local o = E.GROUP.only
  set("card", "suit rank enhancement seal edition enhanced card_sticker first_scored lucky_hit", o)
  set("hand", "hand cards_played first_hand last_hand hand_level played_rank played_suit all_suits suit_and_other most_played played_this_round select_limit", o)
  set("deck", "held_cards held_all lowest_held deck_cards deck_count", o)
  set("discard", "discards_left first_discard once_per_discard discarded discard_all discard_any no_discard", o)
  set("state", "money hands_left ante round boss blind boss_triggered blind_percent consumables used_kind round_suit round_rank round_card round_hand round_hand_suit amount", o)
  set("jokers", "jokers other_rarity jokers_with jokers_of jokers_sticker", o)
  set("luck", "chance every", o)
  set("vars", "var", o)
  local w = E.GROUP.when
  set("during", "card_scored card_held hand_played before after first_hand card_drawn hand_debuffed would_lose other_joker hand_leveled", w)
  set("discard", "discard before_discard", w)
  set("rounds", "blind_selected round_end blind_skipped boss_beaten ante_up", w)
  set("shop", "reroll shop_end shop_opened card_bought card_sold self_sold pack_opened pack_skipped joker_sold", w)
  set("cards", "cards_destroyed card_added joker_added tag_added consumable_used consumable_added money_earned money_spent", w)
  set("always", "passive", w)
end

function E.group_for(list, value)
  local map = E.GROUP[list]
  if not map then return nil end
  value = tostring(value or "")
  if value:sub(1, 4) == "run:" then return list == "give" and "run" or "other" end
  return map[value] or "other"
end

function E.groups_in(options, list)
  local seen = {}
  for _, op in ipairs(options or {}) do seen[E.group_for(list, op.value) or "other"] = true end
  local out = {}
  for _, g in ipairs(E.ORDER[list] or {}) do if seen[g] then out[#out + 1] = g end end
  return out
end

local ACCENTS = {
  ["à"] = "a", ["â"] = "a", ["á"] = "a", ["ä"] = "a", ["ç"] = "c", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
  ["î"] = "i", ["ï"] = "i", ["í"] = "i", ["ô"] = "o", ["ó"] = "o", ["ö"] = "o", ["û"] = "u", ["ù"] = "u", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n", ["œ"] = "oe",
  ["À"] = "a", ["Â"] = "a", ["Á"] = "a", ["Ç"] = "c", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Î"] = "i", ["Í"] = "i", ["Ô"] = "o", ["Ó"] = "o", ["Û"] = "u", ["Ú"] = "u", ["Ñ"] = "n", ["Œ"] = "oe",
}

function E.norm(s)
  s = tostring(s or "")
  s = s:gsub("[\195\197][\128-\191]", function(c) return ACCENTS[c] or c end)
  s = s:lower():gsub("[^%w%+%$%^%s]", " "):gsub("%s+", " ")
  return (s:gsub("^ ", ""):gsub(" $", ""))
end

function E.matches(label, q)
  q = E.norm(q)
  if q == "" then return true end
  local hay = " " .. E.norm(label)
  for word in q:gmatch("%S+") do
    if not hay:find(word, 1, true) then return false end
  end
  return true
end

function E.filter(options, q, group, list)
  local out = {}
  local searching = E.norm(q) ~= ""
  for i, op in ipairs(options or {}) do
    local ok
    if searching then ok = E.matches(op.label, q) or (op.search and E.matches(op.search, q))
    else ok = not group or group == "all" or E.group_for(list, op.value) == group end
    if ok then out[#out + 1] = i end
  end
  return out
end

function E.range_note(spec, v, fmt)
  if type(spec) ~= "table" or type(v) ~= "number" then return nil end
  fmt = fmt or tostring
  if spec.lo and v < spec.lo then return string.format(loc("It can't go below %s. Type %s or more."), fmt(spec.lo), fmt(spec.lo)) end
  if spec.hi and v > spec.hi then return string.format(loc("It can't go above %s. Type %s or less."), fmt(spec.hi), fmt(spec.hi)) end
  return nil
end

function E.split_num(text, mark)
  text = tostring(text or "")
  local m = tostring(mark)
  local a, b = text:find(m, 1, true)
  if not a then return nil end
  local after = text:sub(b + 1):gsub("^%.0+", "")
  local suffix = after:match("^%$") or ""
  after = after:sub(#suffix + 1)
  local left = text:sub(1, a - 1)
  local sign = left:match("[%+%-]?[%$X%^]?$") or ""
  left = left:sub(1, #left - #sign)
  local trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  return trim(left), sign, trim(after), suffix
end

local SIGNED = {["+"] = true, ["X"] = true, ["^"] = true, ["$"] = true, ["-"] = true}

function E.starts_signed(text)
  local c = tostring(text or ""):match("^%s*(.)")
  return c ~= nil and SIGNED[c] == true
end

E.MORE = "\1more"

E.COMMON = {
  when = {"card_scored", "hand_played", "card_held", "discard", "first_hand", "blind_selected", "round_end", "shop_end", "self_sold", "passive"},
  only = {"suit", "rank", "hand", "cards_played", "enhancement", "first_hand", "last_hand", "money", "chance", "every"},
  give = {"chips", "mult", "xmult", "money", "retrigger", "gain_chips", "gain_mult", "gain_xmult", "create", "level_up"},
}

function E.common(options, list)
  local order = E.COMMON[list]
  if not order then return nil end
  local by = {}
  for _, op in ipairs(options or {}) do by[op.value] = op end
  local out = {}
  for _, id in ipairs(order) do if by[id] then out[#out + 1] = by[id] end end
  if #out == 0 or #out >= #(options or {}) then return nil end
  return out
end

E.HAND_BASE = {
  ["High Card"] = {5, 1}, ["Pair"] = {10, 2}, ["Two Pair"] = {20, 2}, ["Three of a Kind"] = {30, 3}, ["Straight"] = {30, 4}, ["Flush"] = {35, 4},
  ["Full House"] = {40, 4}, ["Four of a Kind"] = {60, 7}, ["Straight Flush"] = {100, 8},
}

E.CONTAINS = {
  ["High Card"] = {"High Card"}, ["Pair"] = {"Pair", "High Card"}, ["Two Pair"] = {"Two Pair", "Pair", "High Card"},
  ["Three of a Kind"] = {"Three of a Kind", "Pair", "High Card"}, ["Straight"] = {"Straight", "High Card"}, ["Flush"] = {"Flush", "High Card"},
  ["Full House"] = {"Full House", "Three of a Kind", "Two Pair", "Pair", "High Card"}, ["Four of a Kind"] = {"Four of a Kind", "Three of a Kind", "Pair", "High Card"},
  ["Straight Flush"] = {"Straight Flush", "Straight", "Flush", "High Card"},
}

E.HELD = {"S_Q", "D_9", "C_5"}

E.SAMPLES = {
  {label = "Pair of Kings", hand = "Pair", cards = {"H_K", "S_K"}},
  {label = "Flush of Hearts", hand = "Flush", cards = {"H_2", "H_5", "H_8", "H_J", "H_A"}},
  {label = "High Card: an Ace", hand = "High Card", cards = {"S_A"}},
  {hand = "Two Pair", cards = {"H_J", "C_J", "D_4", "S_4"}},
  {label = "Three Aces", hand = "Three of a Kind", cards = {"H_A", "D_A", "C_A"}},
  {hand = "Straight", cards = {"S_5", "H_6", "D_7", "C_8", "H_9"}},
  {hand = "Full House", cards = {"S_Q", "H_Q", "D_Q", "C_3", "H_3"}},
  {label = "Four Sevens", hand = "Four of a Kind", cards = {"S_7", "H_7", "D_7", "C_7"}},
}

E.STATE = {money = 4, hands_left = 3, discards_left = 3, ante = 1, round = 1, jokers = 1, consumables = 0, deck_cards = 44, hand_level = 1}

local SUIT_OF = {H = "Hearts", D = "Diamonds", S = "Spades", C = "Clubs"}
local RANK_OF = {T = 10, J = 11, Q = 12, K = 13, A = 14}

function E.fake_card(code)
  local suit = SUIT_OF[code:sub(1, 1)]
  local r = code:sub(3)
  local id = RANK_OF[r] or tonumber(r)
  local nominal = id == 14 and 11 or math.min(id, 10)
  return {code = code, nominal = nominal, base = {suit = suit, id = id, nominal = nominal}, config = {center = {key = "c_base"}},
    get_id = function() return id end, is_face = function() return id >= 11 and id <= 13 end, is_suit = function(_, s) return s == suit end}
end

local function cmp(op, a, b)
  a, b = tonumber(a) or 0, tonumber(b) or 0
  if op == "at_most" then return a <= b end
  if op == "exactly" then return a == b end
  return a >= b
end

local REAL_CHECK = {suit = true, rank = true, enhancement = true, seal = true, edition = true, hand = true, cards_played = true}

local SCORE_GIVE = {
  chips = true, mult = true, xmult = true, xchips = true, money = true, retrigger = true, minus_chips = true, minus_mult = true, div_mult = true,
  lose_money = true, emult = true, echips = true, gain_chips = true, gain_mult = true, gain_xmult = true, gain_xchips = true,
  var_add = true, var_set = true, var_chips = true, var_mult = true,
}

function E.simulate(rules, vars, sample)
  local R = require("functions/forge/forge_rules")
  local base = E.HAND_BASE[sample.hand] or {5, 1}
  local played, held = {}, {}
  for _, c in ipairs(sample.cards) do played[#played + 1] = E.fake_card(c) end
  for _, c in ipairs(sample.held or E.HELD) do held[#held + 1] = E.fake_card(c) end
  local ph = {}
  for _, h in ipairs(E.CONTAINS[sample.hand] or {sample.hand}) do ph[h] = {{}} end
  local ctx = {scoring_name = sample.hand, poker_hands = ph, full_hand = played, scoring_hand = played}
  local res = {hand = sample.hand, base_chips = base[1], base_mult = base[2], chips = base[1], mult = base[2], money = 0,
    add_chips = 0, add_mult = 0, xmult = 1, xchips = 1, lucky = false, grows = {}, skipped = {}, unchecked = {}}
  local vals = {}
  for i, v in ipairs(vars or {}) do vals[i] = (v.type == nil or v.type == "number") and (tonumber(v.start) or 0) or v.start end
  local state = {chips = 0, mult = 0, xmult = 1, xchips = 1}
  local function seen(list, id) for _, x in ipairs(list) do if x == id then return end end list[#list + 1] = id end
  local function num(e)
    if e.nv ~= nil then return tonumber(vals[e.nv]) or 0 end
    return tonumber(e.n) or 0
  end
  local function check(o, other)
    local id = o.id
    if id == "chance" or id == "every" then res.lucky = true return true end
    if id == "first_hand" then return true end
    if id == "last_hand" or id == "boss" then return false end
    if id == "blind" then return o.v == "Small" end
    if id == "var" then return cmp(o.op, vals[o.var], num(o)) end
    if id == "held_cards" then return cmp(o.op, #held, num(o)) end
    if E.STATE[id] ~= nil then return cmp(o.op, E.STATE[id], num(o)) end
    if REAL_CHECK[id] then
      local c = {}
      for k, v in pairs(o) do c[k] = v end
      if c.nv ~= nil then c.n, c.nv = num(o), nil end
      local ok, r = pcall(R.check, c, ctx, nil, other, "forge_sample", nil)
      return ok and r or false
    end
    seen(res.unchecked, id)
    return false
  end
  local function passes(rule, other)
    for _, o in ipairs(rule.only or {}) do
      local ok = check(o, other)
      if o.neg then ok = not ok end
      if not ok then return false end
    end
    return true
  end
  res.events = {}
  local function event(id, n)
    for _, ev in ipairs(res.events) do if ev.id == id and ev.n == n then ev.count = ev.count + 1 return end end
    res.events[#res.events + 1] = {id = id, n = n, count = 1}
  end
  local function apply(list, scope)
    local reps = 0
    for _, g in ipairs(list or {}) do
      local id, n = g.id, num(g)
      if SCORE_GIVE[id] and not R.VAR_GIVE[id] and not id:find("^gain_") and not (id == "retrigger" and scope ~= "card") then event(id, n) end
      if not SCORE_GIVE[id] then seen(res.skipped, id)
      elseif id == "chips" then res.chips = res.chips + n; res.add_chips = res.add_chips + n
      elseif id == "minus_chips" then res.chips = res.chips - n; res.add_chips = res.add_chips - n
      elseif id == "mult" then res.mult = res.mult + n; res.add_mult = res.add_mult + n
      elseif id == "minus_mult" then res.mult = res.mult - n; res.add_mult = res.add_mult - n
      elseif id == "xmult" then res.mult = res.mult * n; res.xmult = res.xmult * n
      elseif id == "div_mult" and n ~= 0 then res.mult = res.mult / n; res.xmult = res.xmult / n
      elseif id == "xchips" then res.chips = res.chips * n; res.xchips = res.xchips * n
      elseif id == "emult" then res.mult = res.mult ^ n; res.emult = n
      elseif id == "echips" then res.chips = res.chips ^ n; res.echips = n
      elseif id == "money" then res.money = res.money + n
      elseif id == "lose_money" then res.money = res.money - n
      elseif id == "retrigger" then if scope == "card" then reps = reps + math.max(0, math.floor(n)) end
      elseif id == "gain_chips" then state.chips = state.chips + n; seen(res.grows, id)
      elseif id == "gain_mult" then state.mult = state.mult + n; seen(res.grows, id)
      elseif id == "gain_xmult" then state.xmult = state.xmult + n; seen(res.grows, id)
      elseif id == "gain_xchips" then state.xchips = state.xchips + n; seen(res.grows, id)
      elseif id == "var_add" then vals[g.var or 1] = (tonumber(vals[g.var or 1]) or 0) + n
      elseif id == "var_set" then vals[g.var or 1] = n
      elseif id == "var_chips" then local a = n * (tonumber(vals[g.var or 1]) or 0); res.chips = res.chips + a; res.add_chips = res.add_chips + a; event("chips", a)
      elseif id == "var_mult" then local a = n * (tonumber(vals[g.var or 1]) or 0); res.mult = res.mult + a; res.add_mult = res.add_mult + a; event("mult", a)
      end
    end
    return reps
  end
  local function run(when, other, scope)
    local reps = 0
    for _, rule in ipairs(rules or {}) do
      if rule.when == when then
        if passes(rule, other) then reps = reps + apply(rule.give, scope)
        elseif rule.alt and #rule.alt > 0 then reps = reps + apply(rule.alt, scope) end
      end
    end
    return reps
  end
  local plain_chips = base[1]
  run("before", nil, "hand")
  for _, c in ipairs(played) do
    plain_chips = plain_chips + c.nominal
    res.chips = res.chips + c.nominal
    local reps = run("card_scored", c, "card")
    for _ = 1, reps do
      res.chips = res.chips + c.nominal
      res.add_chips = res.add_chips + c.nominal
      run("card_scored", c, "again")
    end
  end
  for _, c in ipairs(held) do
    local reps = run("card_held", c, "card")
    for _ = 1, reps do run("card_held", c, "again") end
  end
  run("hand_played", nil, "hand")
  if state.chips ~= 0 then res.chips = res.chips + state.chips; res.add_chips = res.add_chips + state.chips; event("chips", state.chips) end
  if state.mult ~= 0 then res.mult = res.mult + state.mult; res.add_mult = res.add_mult + state.mult; event("mult", state.mult) end
  if state.xmult ~= 1 then res.mult = res.mult * state.xmult; res.xmult = res.xmult * state.xmult; event("xmult", state.xmult) end
  if state.xchips ~= 1 then res.chips = res.chips * state.xchips; res.xchips = res.xchips * state.xchips; event("xchips", state.xchips) end
  run("after", nil, "hand")
  local r2 = function(x) return math.floor(x * 100 + 0.5) / 100 end
  res.chips, res.mult = r2(math.max(0, res.chips)), r2(math.max(0, res.mult))
  res.xmult, res.xchips = r2(res.xmult), r2(res.xchips)
  res.plain_chips, res.plain_mult = plain_chips, base[2]
  res.plain_score = plain_chips * base[2]
  res.score = math.floor(res.chips * res.mult + 0.5)
  return res
end

function E.builder(B)
  local K = B.easy_kit
  local T = require("functions/forge/forge_text")
  local R = require("functions/forge/forge_rules")
  local touch = function() return UIK.touch() end

  function B.sentence_on()
    local d = K.draft()
    if not (d and d.kind == "joker") then return false end
    if B.state.jview == nil then B.state.jview = require("functions/forge/forge_store").get_setting("joker_view", "simple") end
    return B.state.jview == "simple"
  end

  local function scale() return touch() and 0.44 or 0.4 end
  local function chip_h() return touch() and 0.74 or 0.6 end

  local function word(str)
    local s = scale() * 1.12
    local tw = UIK.text_w(str, s)
    local node = {n = G.UIT.C, config = {align = "cm", minh = chip_h(), padding = 0}, nodes = {UIK.text(str, {scale = s, colour = UIK.C.text, shadow = true})}}
    node.ez_w, node.ez_tight = tw, str:match("^[,.:;]") ~= nil
    node.ez_word = not node.ez_tight
    return node
  end

  local function chip(label, colour, func, ref_t, id, maxw)
    local s = scale()
    local bw = math.min(maxw, UIK.text_w(label, s) + 0.36)
    local lab, ls = B.wrap_label(label, bw, s)
    local node = UIK.button{label = lab, button = func, ref_table = ref_t, colour = colour, w = bw, h = chip_h(), scale = ls, col = true, id = id}
    node.ez_w = bw + 0.1
    return node
  end

  local function num_chip(t, spec, sign, suffix, colour, id, maxw)
    local ty = B.state.typing
    if ty and ty.t == t and ty.k == "n" then
      local cw = touch() and 1.5 or 1.3
      local node = K.type_row(nil, ty, cw, 0)
      node.ez_w = cw + 0.2 + B.type_w() + 0.12
      node.ez_break = true
      return node
    end
    local v = tonumber(t.n) or spec.lo
    local shown = sign .. T.fmt_n(v)
    if sign == "+" and v < 0 then shown = "-" .. T.fmt_n(-v) end
    shown = shown .. suffix
    return chip(shown, {colour[1] * 0.75, colour[2] * 0.75, colour[3] * 0.75, colour[4] or 1}, "forge_b_type", {t = t, k = "n", spec = spec}, id, maxw)
  end

  local function phrase(out, text, t, spec, colour, func, ref_t, id, maxw)
    if spec and t.n ~= nil and t.nv == nil then
      local c = {}
      for k, v in pairs(t) do c[k] = v end
      c.n = T.NV_MARK
      local left, sign, right, suffix = E.split_num(text(c), T.NV_MARK)
      if left then
        if left ~= "" then out[#out + 1] = chip(left, colour, func, ref_t, id .. "_a", maxw) end
        local nc = num_chip(t, spec, sign, suffix, colour, id .. "_n", maxw)
        nc.ez_glue = left ~= "" and not nc.ez_break
        out[#out + 1] = nc
        if right ~= "" then
          local rc = chip(right, colour, func, ref_t, id .. "_b", maxw)
          rc.ez_glue = not nc.ez_break
          out[#out + 1] = rc
        end
        return
      end
    end
    out[#out + 1] = chip(text(t), colour, func, ref_t, id, maxw)
  end

  function B.sentence_parts(r, w)
    local lang = K.lang()
    local vars = K.dvars()
    local kind = K.draft() and K.draft().kind
    local out = {}
    local maxw = w - 0.3
    local wt = K.plain(T.when_text(r.when, lang, kind))
    if wt == "" then wt = loc("Always") end
    out[#out + 1] = chip(wt, G.C.ORANGE, "forge_b_pick_when", nil, "forge_s_when", maxw)
    local conds, nots, extra = {}, {}, {}
    for i, o in ipairs(r.only) do
      local entry = {o = o, i = i}
      if o.id == "chance" or o.id == "every" then extra[#extra + 1] = entry
      elseif o.neg then nots[#nots + 1] = entry
      else conds[#conds + 1] = entry end
    end
    local function only_part(e)
      local o = e.o
      local spec = R.NUM[o.id == "money" and "money_cond" or o.id]
      local text = function(c) return K.plain(T.only_text(c, lang, vars)) end
      phrase(out, text, o, spec, G.C.BLUE, "forge_b_pick_only", {slot = e.i}, "forge_s_only_" .. e.i, maxw)
    end
    for j, e in ipairs(conds) do
      if j == 1 then out[#out + 1] = word(",") end
      out[#out + 1] = word(loc(j == 1 and "if" or "and"))
      only_part(e)
    end
    for j, e in ipairs(nots) do
      if j == 1 then out[#out + 1] = word(",") end
      out[#out + 1] = word(loc(j == 1 and "unless" or "and"))
      only_part(e)
    end
    for _, e in ipairs(extra) do
      out[#out + 1] = word(",")
      only_part(e)
    end
    local function give_part(g, i, func, prefix)
      local spec = K.give_num(g)
      local text = function(c) return K.plain(T.give_text(c, lang, vars, r.when)) end
      phrase(out, text, g, spec, G.C.RED, func, {slot = i}, prefix .. i, maxw)
    end
    if #r.give == 0 then
      out[#out + 1] = word(",")
      out[#out + 1] = chip(loc("+ Pick what it does"), G.C.RED, "forge_b_pick_give", {slot = 1}, "forge_s_give_1", maxw)
    else
      for i, g in ipairs(r.give) do
        out[#out + 1] = word(i == 1 and "," or loc("and"))
        if i == 1 and E.starts_signed(K.plain(T.give_text(g, lang, vars, r.when))) and g.nv == nil then out[#out + 1] = word(loc("give")) end
        give_part(g, i, "forge_b_pick_give", "forge_s_give_")
      end
    end
    for i, g in ipairs(r.alt or {}) do
      out[#out + 1] = word(i == 1 and "," or loc("and"))
      if i == 1 then out[#out + 1] = word(loc("otherwise")) end
      if i == 1 and E.starts_signed(K.plain(T.give_text(g, lang, vars, r.when))) and g.nv == nil then out[#out + 1] = word(loc("give")) end
      give_part(g, i, "forge_b_pick_alt", "forge_s_alt_")
    end
    out[#out + 1] = word(".")
    return out
  end

  local function flow(parts, w, balanced)
    local rows, cur, used = {}, {}, 0
    local limit = w
    if balanced then
      local total = 0
      for _, p in ipairs(parts) do total = total + (p.ez_w or 1) + 0.1 end
      if total > w then limit = math.min(w, total / math.ceil(total / w) + 0.6) end
    end
    local groups = {}
    for _, p in ipairs(parts) do
      local pw = (p.ez_w or 1) + (p.ez_tight and 0.02 or 0.1)
      local last = groups[#groups]
      local after_word = last and last.list[#last.list].ez_word
      if last and (p.ez_tight or p.ez_glue or after_word) and not p.ez_break then
        last.list[#last.list + 1] = p
        last.w = last.w + pw
      else
        groups[#groups + 1] = {list = {p}, w = pw, brk = p.ez_break}
      end
    end
    for _, g in ipairs(groups) do
      if #cur > 0 and (used + g.w > limit or g.brk) then
        rows[#rows + 1] = cur
        cur, used = {}, 0
      end
      for _, p in ipairs(g.list) do cur[#cur + 1] = p end
      used = used + g.w
    end
    if #cur > 0 then rows[#rows + 1] = cur end
    local out = {}
    for ri, row in ipairs(rows) do
      local nodes = {}
      for i, p in ipairs(row) do
        if p.n == G.UIT.R then p.n = G.UIT.C end
        if p.ez_tight and #nodes > 0 then
          local prev = nodes[#nodes]
          nodes[#nodes] = {n = G.UIT.C, config = {align = "cm", padding = 0}, nodes = {prev, p}}
        else
          if i > 1 then nodes[#nodes + 1] = {n = G.UIT.C, config = {minw = 0.1, padding = 0}, nodes = {}} end
          nodes[#nodes + 1] = p
        end
      end
      if ri > 1 then out[#out + 1] = {n = G.UIT.R, config = {minh = 0.08, padding = 0}, nodes = {}} end
      out[#out + 1] = {n = G.UIT.R, config = {align = "cm", minw = w, padding = 0}, nodes = nodes}
    end
    return out
  end

  function B.sentence_block(r, w)
    local inner = w - 0.28
    local nodes = flow(B.sentence_parts(r, inner), inner)
    nodes[#nodes + 1] = {n = G.UIT.R, config = {minh = 0.1}, nodes = {}}
    local adds = {}
    local maxw = inner - 0.3
    local has_chance = false
    for _, o in ipairs(r.only) do if o.id == "chance" then has_chance = true end end
    if r.when ~= "passive" and #r.only < 6 then
      adds[#adds + 1] = chip(loc("+ Only if"), UIK.C.accent, "forge_b_pick_only", {slot = #r.only + 1}, "forge_s_add_only", maxw)
      if not has_chance then adds[#adds + 1] = chip(loc("+ With a chance"), G.C.GREEN, "forge_b_add_chance", nil, "forge_s_add_chance", maxw) end
    end
    if #r.give > 0 and #r.give < 6 then adds[#adds + 1] = chip(loc("+ Give more"), G.C.RED, "forge_b_pick_give", {slot = #r.give + 1}, "forge_s_add_give", maxw) end
    if #r.only > 0 and #r.give > 0 and #(r.alt or {}) < 2 then adds[#adds + 1] = chip(loc("+ Otherwise"), UIK.C.inactive, "forge_b_pick_alt", {slot = #(r.alt or {}) + 1}, "forge_s_add_alt", maxw) end
    for _, row in ipairs(flow(adds, inner)) do nodes[#nodes + 1] = row end
    local hint = loc("Tap any coloured part of the sentence to change it.")
    local hint_t = UIK.text(hint, {scale = touch() and 0.34 or 0.3, colour = UIK.C.muted})
    nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm", minw = inner, padding = 0.04}, nodes = {{n = G.UIT.C, config = {align = "cm", maxw = inner}, nodes = {hint_t}}}}
    return {n = G.UIT.R, config = {align = "cm", padding = 0}, nodes = {
      {n = G.UIT.C, config = {align = "cm", minw = w, r = 0.15, padding = 0.1, colour = UIK.C.section}, nodes = nodes},
    }}
  end

  local function pick_rows(p)
    if UIK.portrait() then return p.tools and 10 or 12, 1 end
    if touch() then return p.tools and 4 or (#p.options <= 18 and 6 or 5), 3 end
    return p.tools and 5 or (#p.options <= 21 and 7 or 6), 3
  end

  function B.pick_tools_on(p) return p.list ~= nil and #p.options > 15 or (p.search == true and #p.options > 15) end

  local function group_row(p, w)
    local groups = E.groups_in(p.options, p.list)
    if #groups < 2 then return nil end
    local searching = E.norm(p.q) ~= ""
    local cur = searching and "all" or (p.group or "all")
    local h = touch() and 0.64 or 0.52
    local s = touch() and 0.38 or 0.34
    if UIK.portrait() then
      local all = {"all"}
      for _, g in ipairs(groups) do all[#all + 1] = g end
      local at = 1
      for i, g in ipairs(all) do if g == cur then at = i end end
      local gl = loc(E.GROUP_LABEL[all[at]])
      return {UIK.pager{prev = "forge_b_pick_group", next = "forge_b_pick_group", prev_ref = {d = -1}, next_ref = {d = 1}, text = gl, text_w = math.max(2.8, UIK.text_w(gl, 0.48) + 0.5), w = w}}
    end
    local tabs = {}
    local function tab(g)
      local label = loc(E.GROUP_LABEL[g] or g)
      local bw = UIK.text_w(label, s) + 0.3
      local colour = g == cur and G.C.RED or UIK.C.inactive
      local node = UIK.button{label = label, button = "forge_b_pick_group", ref_table = {g = g}, colour = colour, w = bw, h = h, scale = s, col = true, id = "forge_group_" .. g}
      node.ez_w = bw + 0.1
      return node
    end
    tabs[1] = tab("all")
    for _, g in ipairs(groups) do tabs[#tabs + 1] = tab(g) end
    return flow(tabs, w, true)
  end

  function B.pick_list_def(p)
    local per_row, rows
    rows, per_row = pick_rows(p)
    local per = per_row * rows
    local shown = E.filter(p.options, p.q, p.group, p.list)
    local pages = math.max(1, math.ceil(#shown / per))
    p.page = math.max(1, math.min(p.page or 1, pages))
    local bw = UIK.portrait() and 6.2 or (touch() and 4.3 or 4.5)
    local bh = touch() and 0.82 or 0.66
    local items = {}
    for j = (p.page - 1) * per + 1, math.min(#shown, p.page * per) do
      local i = shown[j]
      local op = p.options[i]
      items[#items + 1] = K.button(op.label, "forge_b_choose", {i = i}, op.colour or p.colour or UIK.C.accent, bw, bh, "forge_opt_" .. i)
    end
    local w = UIK.W - 0.4
    local nodes = {}
    if p.tools then
      local gw = math.min(w, per_row * (bw + 0.1) + 0.1)
      for _, row in ipairs(group_row(p, gw) or {}) do nodes[#nodes + 1] = row end
    end
    local grid_h = math.ceil(per / per_row) * (bh + 0.12)
    if #items == 0 then
      local none = UIK.text(loc("Nothing matches your search."), {scale = touch() and 0.4 or 0.36, colour = UIK.C.muted})
      nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm", minw = w, minh = grid_h}, nodes = {none}}
    else
      nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "tm", minw = w, minh = p.tools and grid_h or 0}, nodes = {UIK.grid(items, per_row, {w = w, padding = 0.05})}}
    end
    if pages > 1 then
      local text = string.format(loc("Page %d of %d"), p.page, pages)
      nodes[#nodes + 1] = UIK.pager{prev = "forge_b_pick_page", next = "forge_b_pick_page", prev_ref = {d = -1}, next_ref = {d = 1}, text = text, w = UIK.W}
    elseif p.tools then
      nodes[#nodes + 1] = {n = G.UIT.R, config = {minh = B.line_h("pager")}, nodes = {}}
    end
    return {n = G.UIT.ROOT, config = {align = "tm", colour = G.C.CLEAR, padding = 0}, nodes = {{n = G.UIT.C, config = {align = "tm", padding = 0}, nodes = nodes}}}
  end

  function B.pick_search_row(p)
    p.q = p.q or ""
    p.last_q = p.q
    local w = UIK.portrait() and 6.2 or math.min(7, UIK.W - 0.6)
    local input = _G.create_text_input({ref_table = p, ref_value = "q", max_length = 24, w = w, h = touch() and 0.66 or 0.52, text_scale = touch() and 0.42 or 0.38,
      prompt_text = loc("Search"), extended_corpus = true, keyboard_offset = touch() and 2.4 or 3})
    return {n = G.UIT.R, config = {align = "cm", padding = 0.04}, nodes = {{n = G.UIT.C, config = {align = "cm"}, nodes = {input}}}}
  end

  function B.pick_redraw()
    local p = B.state.pick
    if not p then return end
    if not K.soft_set("forge_pick_list", B.pick_list_def(p)) then K.refresh() end
  end

  G.FUNCS.forge_b_pick_watch = function()
    local p = B.state.pick
    if not (p and p.tools) then return end
    local q = tostring(p.q or "")
    if q == p.last_q then return end
    p.last_q = q
    p.page = 1
    B.pick_redraw()
  end

  G.FUNCS.forge_b_pick_group = function(e)
    local p = B.state.pick
    if not p then return end
    local r2 = e and e.config and e.config.ref_table or {}
    if r2.g then
      p.group = r2.g
    else
      local all = {"all"}
      for _, g in ipairs(E.groups_in(p.options, p.list)) do all[#all + 1] = g end
      local at = 1
      for i, g in ipairs(all) do if g == (p.group or "all") then at = i end end
      p.group = all[(at - 1 + (tonumber(r2.d) or 1)) % #all + 1]
    end
    p.q = ""
    p.last_q = ""
    p.page = 1
    play_sound("button", 1, 0.4)
    K.refresh()
  end

  function B.easy_simple_list(o)
    if not (o.list and not o.full and B.sentence_on()) then return o end
    local keep = E.common(o.options, o.list)
    if not keep then return o end
    o.all = o.options
    keep[#keep + 1] = {label = loc("More..."), value = E.MORE, colour = UIK.C.accent}
    o.options = keep
    return o
  end

  function B.easy_more(p, value)
    if value ~= E.MORE or not p.all then return false end
    p.options, p.all, p.full = p.all, nil, true
    p.tools = #p.options > 15
    p.page, p.group, p.q = 1, nil, ""
    play_sound("button", 1, 0.5)
    K.refresh()
    return true
  end

  B.state.sample = B.state.sample or 1

  local function cards_area(codes, s)
    local cw, ch = G.CARD_W * s, G.CARD_H * s
    local w = math.max(1, #codes) * cw * 1.08 + 0.1
    local area = _G.CardArea(G.ROOM.T.x, G.ROOM.T.y, w, ch, {card_limit = math.max(1, #codes), type = "title", highlight_limit = 0, collection = true, card_w = cw})
    for _, code in ipairs(codes) do
      local c = _G.Card(G.ROOM.T.x, G.ROOM.T.y, cw, ch, G.P_CARDS[code], G.P_CENTERS.c_base)
      c.states.hover.can, c.states.drag.can, c.states.click.can = false, false, false
      area:emplace(c)
    end
    return {n = G.UIT.C, config = {align = "cm", minw = w, minh = ch, padding = 0}, nodes = {{n = G.UIT.O, config = {object = area}}}}, w
  end

  local function txt(str, ts, colour)
    return {n = G.UIT.C, config = {align = "cm", padding = 0}, nodes = {UIK.text(str, {scale = ts, colour = colour or UIK.C.text, shadow = true})}}
  end

  local function pill(str, colour, ps, w)
    local t = UIK.text(str, {scale = ps, colour = G.C.UI.TEXT_LIGHT, shadow = true})
    return {n = G.UIT.C, config = {align = "cm", minw = w or 0, minh = ps * 1.9, r = 0.1, padding = 0.06, colour = colour}, nodes = {t}}
  end

  local function line(nodes, w, pad)
    local list = {}
    for i, n in ipairs(nodes) do
      if i > 1 then list[#list + 1] = {n = G.UIT.C, config = {minw = pad or 0.12}, nodes = {}} end
      list[#list + 1] = n
    end
    return {n = G.UIT.R, config = {align = "cm", minw = w, padding = 0.04}, nodes = list}
  end

  function B.sample_result()
    local d = K.draft()
    local sm = E.SAMPLES[B.state.sample] or E.SAMPLES[1]
    return E.simulate(d and d.rules or {}, R.clean_vars(d and d.vars), sm), sm
  end

  function B.sample_body(w)
    local res, sm = B.sample_result()
    local s = touch() and 0.4 or 0.36
    local nodes = {}
    nodes[#nodes + 1] = line({txt(loc("TRY IT ON A SAMPLE HAND"), touch() and 0.46 or 0.42, UIK.C.title)}, w)
    local lbl = sm.label and loc(sm.label) or T.hand_name(sm.hand)
    local ltw = math.max(2.8, UIK.text_w(lbl, 0.48) + 0.5)
    nodes[#nodes + 1] = UIK.pager{prev = "forge_b_sample", next = "forge_b_sample", prev_ref = {d = -1}, next_ref = {d = 1}, text = lbl, text_w = ltw, w = w}
    local played, pw = cards_area(sm.cards, UIK.portrait() and 0.42 or (touch() and 0.42 or 0.4))
    local heldn, hw = cards_area(E.HELD, UIK.portrait() and 0.32 or 0.3)
    local function boxed(node, label, bw)
      return {n = G.UIT.C, config = {align = "cm", padding = 0.04}, nodes = {
        {n = G.UIT.R, config = {minh = 0.14}, nodes = {}},
        {n = G.UIT.R, config = {align = "cm", minw = bw, padding = 0}, nodes = {node}},
        {n = G.UIT.R, config = {align = "cm", padding = 0.04}, nodes = {UIK.text(label, {scale = s * 0.85, colour = UIK.C.muted})}},
      }}
    end
    local pb, hb = boxed(played, loc("Played"), pw), boxed(heldn, loc("Held in hand"), hw)
    if pw + hw + 0.5 <= w then
      nodes[#nodes + 1] = line({pb, hb}, w, 0.4)
    else
      nodes[#nodes + 1] = line({pb}, w)
      nodes[#nodes + 1] = line({hb}, w)
    end
    local r = {}
    local function fmt(x) return T.fmt_n(x) end
    r[#r + 1] = line({txt(string.format(loc("Without it: %s Chips x %s Mult = %s"), fmt(res.plain_chips), fmt(res.plain_mult), fmt(res.plain_score)), s, UIK.C.muted)}, w - 0.3)
    local gives = {}
    local chips_w, mult_w = loc("Chips"), loc("Mult")
    local EV = {
      chips = {"+%s " .. chips_w, G.C.CHIPS}, minus_chips = {"-%s " .. chips_w, G.C.CHIPS}, xchips = {"X%s " .. chips_w, G.C.CHIPS}, echips = {"^%s " .. chips_w, G.C.CHIPS},
      mult = {"+%s " .. mult_w, G.C.MULT}, minus_mult = {"-%s " .. mult_w, G.C.MULT}, xmult = {"X%s " .. mult_w, G.C.MULT}, div_mult = {"/%s " .. mult_w, G.C.MULT},
      emult = {"^%s " .. mult_w, G.C.MULT}, money = {"$%s", G.C.MONEY}, lose_money = {"-$%s", G.C.MONEY}, retrigger = {loc("Retrigger") .. " %s", UIK.C.accent},
    }
    for _, ev in ipairs(res.events or {}) do
      local spec = EV[ev.id]
      if spec then
        local label = string.format(spec[1], fmt(ev.n))
        if ev.count > 1 then label = label .. " " .. string.format(loc("(%d times)"), ev.count) end
        gives[#gives + 1] = pill(label, spec[2], s)
      end
    end
    if #gives == 0 then
      r[#r + 1] = line({txt(loc("Your Joker gives nothing on this hand."), s, UIK.C.text)}, w - 0.3)
    else
      r[#r + 1] = line({txt(loc("Your Joker gives:"), s, UIK.C.text)}, w - 0.3)
      local cur, used = {}, 0
      for _, g in ipairs(gives) do
        local gw = UIK.text_w(g.nodes[1].config.text, s) + 0.3
        if #cur > 0 and used + gw > w - 0.5 then r[#r + 1] = line(cur, w - 0.3, 0.1); cur, used = {}, 0 end
        cur[#cur + 1] = g
        used = used + gw + 0.1
      end
      if #cur > 0 then r[#r + 1] = line(cur, w - 0.3, 0.1) end
    end
    local big = touch() and 0.5 or 0.46
    local bw = touch() and 1.6 or 1.4
    local total = {pill(fmt(res.chips), G.C.CHIPS, big, bw), txt("X", big, G.C.RED), pill(fmt(res.mult), G.C.MULT, big, bw), txt("=", big), txt(fmt(res.score), big * 1.1, UIK.C.title)}
    r[#r + 1] = line(total, w - 0.3, 0.14)
    local notes = {}
    if res.lucky then notes[#notes + 1] = loc("Chance and Every N parts count as if they hit.") end
    if #res.grows > 0 then notes[#notes + 1] = loc("What it gains counts from this hand on.") end
    local skip = {}
    for _, id in ipairs(res.skipped) do skip[#skip + 1] = K.give_name(id) end
    if #skip > 0 then notes[#notes + 1] = string.format(loc("Not shown here: %s."), table.concat(skip, ", ")) end
    local unk = {}
    for _, id in ipairs(res.unchecked) do unk[#unk + 1] = K.only_name(id) end
    if #unk > 0 then notes[#notes + 1] = string.format(loc("Counted as not met here: %s."), table.concat(unk, ", ")) end
    if #notes > 0 then r[#r + 1] = UIK.note(notes, {w = w - 0.4, scale = touch() and 0.32 or 0.3, colour = UIK.C.muted}) end
    nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0}, nodes = {
      {n = G.UIT.C, config = {align = "cm", minw = w, r = 0.15, padding = 0.1, colour = UIK.C.section}, nodes = r},
    }}
    return nodes
  end

  G.FUNCS.forge_b_sample = function(e)
    local r2 = e and e.config and e.config.ref_table or {}
    local n = #E.SAMPLES
    B.state.sample = ((B.state.sample or 1) - 1 + (tonumber(r2.d) or 1)) % n + 1
    play_sound("card1", 1, 0.4)
    K.refresh()
  end

  function B.start_grid_def()
    local items, pages, per, count = B.start_list_def()
    local w = UIK.W - 0.2
    local rows = math.ceil(#items / per)
    local cap_rows = UIK.portrait() and 3 or touch() and 1 or 2
    local nodes = {}
    if count == 0 then
      nodes[#nodes + 1] = {n = G.UIT.R, config = {align = "cm", minw = w, minh = 1.2}, nodes = {UIK.text(loc("Nothing matches your search."), {scale = touch() and 0.4 or 0.36, colour = UIK.C.muted})}}
    else
      nodes[#nodes + 1] = UIK.grid(items, per, {w = w, padding = 0.04})
    end
    if rows < cap_rows and count > 0 then nodes[#nodes + 1] = {n = G.UIT.R, config = {minh = 0.1}, nodes = {}} end
    if pages > 1 then
      local text = string.format(loc("Page %d of %d"), B.state.page, pages)
      nodes[#nodes + 1] = UIK.pager{prev = "forge_b_page", next = "forge_b_page", prev_ref = {d = -1}, next_ref = {d = 1}, text = text, w = UIK.W}
    end
    return {n = G.UIT.ROOT, config = {align = "tm", colour = G.C.CLEAR, padding = 0, minw = w}, nodes = {{n = G.UIT.C, config = {align = "tm", padding = 0, minw = w}, nodes = nodes}}}
  end

  function B.start_search_row()
    B.state.start_q = B.state.start_q or ""
    B.state.start_last_q = B.state.start_q
    local w = UIK.portrait() and (UIK.W - 0.8) or math.min(7, UIK.W - 0.6)
    local input = _G.create_text_input({ref_table = B.state, ref_value = "start_q", max_length = 24, w = w, h = touch() and 0.66 or 0.52, text_scale = touch() and 0.42 or 0.38,
      prompt_text = loc("Search"), extended_corpus = true, keyboard_offset = touch() and 2.4 or 3})
    return {n = G.UIT.R, config = {align = "cm", padding = 0.04}, nodes = {{n = G.UIT.C, config = {align = "cm"}, nodes = {input}}}}
  end

  function B.start_redraw()
    if not (B.state.start and not K.draft()) then return false end
    return K.soft_set("forge_start_list", B.start_grid_def())
  end

  G.FUNCS.forge_b_start_watch = function()
    local q = tostring(B.state.start_q or "")
    if q == B.state.start_last_q then return end
    B.state.start_last_q = q
    B.state.page = 1
    B.start_redraw()
  end

  function B.easy_range_note(ty)
    local v = tonumber((tostring(ty.text or ""):gsub(",", "."):gsub("[^%d%.%-eE+]", "")))
    if not v or v ~= v then return nil end
    return E.range_note(ty.spec, v, T.fmt_n)
  end

  if mod_loc_register then
    mod_loc_register{
      fr = {
        ["All"] = "Tout", ["Score"] = "Score", ["Grows"] = "Grandit", ["Money"] = "Argent",
        ["Cards"] = "Cartes", ["Jokers"] = "Jokers", ["Hands and round"] = "Mains et manche", ["Run and shop"] = "Partie et boutique",
        ["Variables"] = "Variables", ["Downsides"] = "Malus", ["Other"] = "Autre", ["The card"] = "La carte",
        ["The hand"] = "La main", ["Hand and deck"] = "Main et jeu", ["Discards"] = "Défausses", ["Luck"] = "Chance", ["The run"] = "La partie",
        ["During a hand"] = "Pendant une main", ["Rounds and blinds"] = "Manches et blindes", ["Shop and packs"] = "Boutique et paquets", ["Always"] = "Toujours",
        ["More..."] = "Plus...", ["(%d times)"] = "(%d fois)", ["Sample hand"] = "Main test",
        ["TRY IT ON A SAMPLE HAND"] = "ESSAYEZ-LE SUR UNE MAIN", ["Played"] = "Jouées", ["Held in hand"] = "En main",
        ["Without it: %s Chips x %s Mult = %s"] = "Sans lui : %s Jetons x %s Multi = %s", ["Your Joker gives nothing on this hand."] = "Votre joker ne donne rien sur cette main.",
        ["Your Joker gives:"] = "Votre joker donne :", ["Chance and Every N parts count as if they hit."] = "Les parties Chance et Toutes les N fois comptent comme réussies.",
        ["What it gains counts from this hand on."] = "Ce qu'il gagne compte dès cette main.",
        ["Not shown here: %s."] = "Pas montré ici : %s.", ["Counted as not met here: %s."] = "Compté comme non rempli ici : %s.",
        ["Pair of Kings"] = "Paire de Rois", ["Flush of Hearts"] = "Couleur à Cœur", ["High Card: an Ace"] = "Carte haute : un As", ["Three Aces"] = "Brelan d'As",
        ["Four Sevens"] = "Carré de 7",
        ["Search"] = "Rechercher", ["Nothing matches your search."] = "Rien ne correspond à votre recherche.",
        ["It can't go below %s. Type %s or more."] = "Ça ne peut pas descendre sous %s. Tapez %s ou plus.",
        ["It can't go above %s. Type %s or less."] = "Ça ne peut pas dépasser %s. Tapez %s ou moins.",
        ["if"] = "si", ["and"] = "et", ["unless"] = "sauf si", ["otherwise"] = "sinon", ["give"] = "donne",
        ["Tap any coloured part of the sentence to change it."] = "Touchez une partie colorée de la phrase pour la changer.",
      },
      es = {
        ["All"] = "Todo", ["Score"] = "Puntos", ["Grows"] = "Crece", ["Money"] = "Dinero",
        ["Cards"] = "Cartas", ["Jokers"] = "Jokers", ["Hands and round"] = "Manos y ronda", ["Run and shop"] = "Partida y tienda",
        ["Variables"] = "Variables", ["Downsides"] = "Contras", ["Other"] = "Otro", ["The card"] = "La carta",
        ["The hand"] = "La mano", ["Hand and deck"] = "Mano y baraja", ["Discards"] = "Descartes", ["Luck"] = "Suerte", ["The run"] = "La partida",
        ["During a hand"] = "Durante una mano", ["Rounds and blinds"] = "Rondas y ciegas", ["Shop and packs"] = "Tienda y paquetes", ["Always"] = "Siempre",
        ["More..."] = "Más...", ["(%d times)"] = "(%d veces)", ["Sample hand"] = "Mano de prueba",
        ["TRY IT ON A SAMPLE HAND"] = "PRUÉBALO EN UNA MANO", ["Played"] = "Jugadas", ["Held in hand"] = "En la mano",
        ["Without it: %s Chips x %s Mult = %s"] = "Sin él: %s fichas x %s multi = %s", ["Your Joker gives nothing on this hand."] = "Tu joker no da nada en esta mano.",
        ["Your Joker gives:"] = "Tu joker da:", ["Chance and Every N parts count as if they hit."] = "Las partes de probabilidad y Cada N veces cuentan como acertadas.",
        ["What it gains counts from this hand on."] = "Lo que gana cuenta desde esta mano.",
        ["Not shown here: %s."] = "No se muestra aquí: %s.", ["Counted as not met here: %s."] = "Cuenta como no cumplido aquí: %s.",
        ["Pair of Kings"] = "Pareja de reyes", ["Flush of Hearts"] = "Color de corazones", ["High Card: an Ace"] = "Carta alta: un as", ["Three Aces"] = "Trío de ases",
        ["Four Sevens"] = "Póker de sietes",
        ["Search"] = "Buscar", ["Nothing matches your search."] = "Nada coincide con tu búsqueda.",
        ["It can't go below %s. Type %s or more."] = "No puede bajar de %s. Escribe %s o más.", ["It can't go above %s. Type %s or less."] = "No puede pasar de %s. Escribe %s o menos.",
        ["if"] = "si", ["and"] = "y", ["unless"] = "salvo si", ["otherwise"] = "si no", ["give"] = "da",
        ["Tap any coloured part of the sentence to change it."] = "Toca una parte de color de la frase para cambiarla.",
      },
    }
  end
end

return E
