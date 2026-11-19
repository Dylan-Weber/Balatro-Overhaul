local Store = require("functions/forge/forge_store")

local H = {}

H.PREFIX = "hand_forge_"
H.MAX = 6
H.PATTERNS = {"each_suit", "same_suit", "same_rank", "diff_rank", "in_a_row", "all_face", "all_even", "all_odd", "every_suit", "kinds", "suit_groups", "any"}
H.GROUPS = {kinds = true, suit_groups = true}
H.RANK_ID = {["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["10"] = 10, Jack = 11, Queen = 12, King = 13, Ace = 14}
H.VANILLA = {"Flush Five", "Flush House", "Five of a Kind", "Straight Flush", "Four of a Kind", "Full House", "Flush", "Straight", "Three of a Kind", "Two Pair", "Pair", "High Card"}
H.VANILLA_ORDER = {}
for i, h in ipairs(H.VANILLA) do H.VANILLA_ORDER[h] = i end

local function smods() return type(rawget(_G, "SMODS")) == "table" end

local function member(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

function H.key(c) return H.PREFIX .. tostring(c.id) end

function H.id_of(key)
  if type(key) ~= "string" or key:sub(1, #H.PREFIX) ~= H.PREFIX then return nil end
  local id = key:sub(#H.PREFIX + 1)
  if id == "" or #id > 16 or id:find("[^%w]") then return nil end
  return id
end

local function num(v, lo, hi, def)
  v = tonumber(v)
  if not v or v ~= v then return def end
  return math.max(lo, math.min(hi, v))
end

H.MAX_COUNT = 1000
H.EXAMPLE_MAX = 13

function H.fields(c)
  local f = type(c) == "table" and type(c.fields) == "table" and c.fields or {}
  return {
    count = math.floor(num(f.count, 1, H.MAX_COUNT, 4)),
    pattern = member(H.PATTERNS, f.pattern) and f.pattern or "each_suit",
    chips = num(f.chips, 0, 1e15, 40),
    mult = num(f.mult, 1, 1e15, 4),
    l_chips = num(f.l_chips, 0, 1e15, 20),
    l_mult = num(f.l_mult, 0, 1e15, 2),
    beats = (H.VANILLA_ORDER[f.beats] or (type(f.beats) == "string" and f.beats ~= H.key(c) and f.beats:sub(1, #H.PREFIX) == H.PREFIX)) and f.beats or "Flush",
    hidden = f.hidden == true,
    group2 = math.floor(num(f.group2, 0, H.MAX_COUNT, 2)),
    low = H.RANK_ID[tostring(f.low)] and tostring(f.low) or "2",
    high = H.RANK_ID[tostring(f.high)] and tostring(f.high) or "Ace",
    sum = math.floor(num(f.sum, 0, 1e6, 0)),
    also = (member(H.PATTERNS, f.also) and not H.GROUPS[f.also] and f.also ~= "any") and f.also or nil,
    contains = type(f.contains) == "string" and f.contains ~= "none" and f.contains ~= H.key(c) and f.contains or nil,
    auto_level = math.floor(num(f.auto_level, 0, 1e6, 0)),
  }
end

function H.total(f)
  if H.GROUPS[f.pattern] then return f.count + f.group2 end
  return f.count
end

function H.live(items)
  local list = {}
  for _, c in ipairs(items or {}) do
    if type(c) == "table" and c.kind == "hand" and type(c.id) == "string" and c.enabled ~= false and not c.unset then list[#list + 1] = c end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  local out = {}
  for i = 1, math.min(#list, H.MAX) do out[i] = list[i] end
  return out
end

H.list = {}
H.by_key = {}

function H.set_list(list)
  H.list, H.by_key = list, {}
  for _, c in ipairs(list) do H.by_key[H.key(c)] = c end
end

function H.is_own(key) return H.by_key[key] ~= nil end

local function stone(card) return card.ability and (card.ability.effect == "Stone Card" or card.ability.name == "Stone Card") end

local function id_of(card) return card.get_id and card:get_id() or (card.base and card.base.id) or 0 end

local function suits()
  local ok, Suits = pcall(require, "functions/forge/forge_suits")
  if ok and Suits.all_suits then return Suits.all_suits() end
  return {"Spades", "Hearts", "Clubs", "Diamonds"}
end

local function distinct_suits(cards)
  local list = suits()
  local used = {}
  local function place(i)
    if i > #cards then return true end
    local card = cards[i]
    if stone(card) then return false end
    for _, s in ipairs(list) do
      if not used[s] and card:is_suit(s, nil, true) then
        used[s] = true
        if place(i + 1) then return true end
        used[s] = nil
      end
    end
    return false
  end
  return place(1)
end

local function cover_suits(cards)
  local list = suits()
  local used = {}
  local function place(i)
    if i > #list then return true end
    for j, card in ipairs(cards) do
      if not used[j] and not stone(card) and card:is_suit(list[i], nil, true) then
        used[j] = true
        if place(i + 1) then return true end
        used[j] = nil
      end
    end
    return false
  end
  if not place(1) then return nil end
  return used
end
H.cover_suits = cover_suits

local function rank_groups(cards)
  local groups, order = {}, {}
  for _, c in ipairs(cards) do
    if not stone(c) then
      local id = id_of(c)
      if not groups[id] then groups[id] = {} order[#order + 1] = id end
      local g = groups[id]
      g[#g + 1] = c
    end
  end
  table.sort(order, function(a, b) return #groups[a] > #groups[b] or (#groups[a] == #groups[b] and a > b) end)
  return groups, order
end

local function kinds_pick(cards, n, m)
  local groups, order = rank_groups(cards)
  for _, a in ipairs(order) do
    if #groups[a] >= n then
      if m == 0 then
        local out = {}
        for i = 1, n do out[i] = groups[a][i] end
        return out
      end
      for _, b in ipairs(order) do
        if b ~= a and #groups[b] >= m then
          local out = {}
          for i = 1, n do out[#out + 1] = groups[a][i] end
          for i = 1, m do out[#out + 1] = groups[b][i] end
          return out
        end
      end
    end
  end
  return nil
end

local function suit_groups_ok(cards, n, m)
  local list = suits()
  for _, s in ipairs(list) do
    for _, t in ipairs(list) do
      if s ~= t then
        local a, b, w, ok = 0, 0, 0, true
        for _, c in ipairs(cards) do
          if stone(c) then ok = false break end
          local is_s, is_t = c:is_suit(s, nil, true), c:is_suit(t, nil, true)
          if is_s and is_t then w = w + 1 elseif is_s then a = a + 1 elseif is_t then b = b + 1 else ok = false break end
        end
        if ok and math.max(0, n - a) + math.max(0, m - b) <= w and a <= n + w and b <= m + w and a + b + w == n + m then return true end
      end
    end
  end
  return false
end

H.CHECK = {
  any = function() return true end,
  kinds = function(cards, f)
    f = f or {count = #cards, group2 = 0}
    return #cards == f.count + f.group2 and kinds_pick(cards, f.count, f.group2) ~= nil
  end,
  suit_groups = function(cards, f)
    f = f or {count = #cards, group2 = 0}
    return #cards == f.count + f.group2 and suit_groups_ok(cards, f.count, f.group2)
  end,
  every_suit = function(cards) return cover_suits(cards) ~= nil end,
  each_suit = distinct_suits,
  same_suit = function(cards)
    for _, s in ipairs(suits()) do
      local all = true
      for _, c in ipairs(cards) do if stone(c) or not c:is_suit(s, nil, true) then all = false break end end
      if all then return true end
    end
    return false
  end,
  same_rank = function(cards)
    local first = nil
    for _, c in ipairs(cards) do
      if stone(c) then return false end
      local id = id_of(c)
      if first == nil then first = id elseif id ~= first then return false end
    end
    return true
  end,
  diff_rank = function(cards)
    local seen = {}
    for _, c in ipairs(cards) do
      if stone(c) then return false end
      local id = id_of(c)
      if seen[id] then return false end
      seen[id] = true
    end
    return true
  end,
  in_a_row = function(cards)
    local ids = {}
    for _, c in ipairs(cards) do
      if stone(c) then return false end
      ids[#ids + 1] = id_of(c)
    end
    table.sort(ids)
    local function run(list)
      for i = 2, #list do if list[i] ~= list[i - 1] + 1 then return false end end
      return true
    end
    if run(ids) then return true end
    if ids[#ids] == 14 then
      local low = {1}
      for i = 1, #ids - 1 do low[#low + 1] = ids[i] end
      table.sort(low)
      return run(low)
    end
    return false
  end,
  all_face = function(cards)
    for _, c in ipairs(cards) do if stone(c) or not (c.is_face and c:is_face()) then return false end end
    return true
  end,
  all_even = function(cards)
    for _, c in ipairs(cards) do
      local id = id_of(c)
      if stone(c) or not (id <= 10 and id % 2 == 0) then return false end
    end
    return true
  end,
  all_odd = function(cards)
    for _, c in ipairs(cards) do
      local id = id_of(c)
      if stone(c) or not ((id <= 10 and id % 2 == 1) or id == 14) then return false end
    end
    return true
  end,
}

local function combos(n, k, fn)
  local idx = {}
  local function step(start, depth)
    if depth > k then return fn(idx) end
    for i = start, n - (k - depth) do
      idx[depth] = i
      if step(i + 1, depth + 1) then return true end
    end
    return false
  end
  return step(1, 1)
end

local function first_k(list, k)
  if #list < k then return nil end
  local out = {}
  for i = 1, k do out[i] = list[i] end
  return out
end

local function each_alone(pattern)
  return function(cards, k)
    local ok = {}
    for _, c in ipairs(cards) do if H.CHECK[pattern]({c}) then ok[#ok + 1] = c end end
    return first_k(ok, k)
  end
end

H.FAST = {
  any = function(cards, k) return first_k(cards, k) end,
  kinds = function(cards, k, f) return kinds_pick(cards, f.count, f.group2) end,
  all_face = each_alone("all_face"),
  all_even = each_alone("all_even"),
  all_odd = each_alone("all_odd"),
  same_suit = function(cards, k)
    for _, s in ipairs(suits()) do
      local ok = {}
      for _, c in ipairs(cards) do if not stone(c) and c:is_suit(s, nil, true) then ok[#ok + 1] = c end end
      if #ok >= k then return first_k(ok, k) end
    end
    return nil
  end,
  same_rank = function(cards, k)
    local groups, order = {}, {}
    for _, c in ipairs(cards) do
      if not stone(c) then
        local id = id_of(c)
        if not groups[id] then groups[id] = {} order[#order + 1] = id end
        local g = groups[id]
        g[#g + 1] = c
      end
    end
    for _, id in ipairs(order) do
      if #groups[id] >= k then return first_k(groups[id], k) end
    end
    return nil
  end,
  diff_rank = function(cards, k)
    local seen, ok = {}, {}
    for _, c in ipairs(cards) do
      if not stone(c) then
        local id = id_of(c)
        if not seen[id] then seen[id] = true ok[#ok + 1] = c end
      end
    end
    return first_k(ok, k)
  end,
  in_a_row = function(cards, k)
    if k > 13 then return nil end
    local at = {}
    for _, c in ipairs(cards) do
      if not stone(c) then
        local id = id_of(c)
        if not at[id] then at[id] = c end
      end
    end
    if at[14] and not at[1] then at[1] = at[14] end
    for lo = 1, 15 - k do
      local pick = {}
      for v = lo, lo + k - 1 do
        if not at[v] then pick = nil break end
        pick[#pick + 1] = at[v]
      end
      if pick then return pick end
    end
    return nil
  end,
  each_suit = function(cards, k)
    if k > #suits() then return nil end
    return false
  end,
  every_suit = function(cards, k)
    if k < #suits() then return nil end
    local used = cover_suits(cards)
    if not used then return nil end
    local pick = {}
    for j, card in ipairs(cards) do if used[j] then pick[#pick + 1] = card end end
    for j, card in ipairs(cards) do
      if #pick >= k then break end
      if not used[j] then pick[#pick + 1] = card end
    end
    if #pick < k then return nil end
    return pick
  end,
}

H.COMBO_LIMIT = 20000

local function n_choose_k(n, k)
  local r = 1
  for i = 1, k do
    r = r * (n - k + i) / i
    if r > H.COMBO_LIMIT then return r end
  end
  return r
end

function H.rank_sum(cards)
  local n = 0
  for _, c in ipairs(cards) do if not stone(c) then n = n + id_of(c) end end
  return n
end

local function in_range(cards, f)
  local lo, hi = H.RANK_ID[f.low], H.RANK_ID[f.high]
  if lo > hi then lo, hi = hi, lo end
  if lo == 2 and hi == 14 then return true end
  for _, c in ipairs(cards) do
    if stone(c) then return false end
    local id = id_of(c)
    if id < lo or id > hi then return false end
  end
  return true
end

H.depth = 0

function H.contains(cards, hand)
  if H.depth > 1 or type(evaluate_poker_hand) ~= "function" then return false end
  H.depth = H.depth + 1
  local ok, res = pcall(evaluate_poker_hand, cards)
  H.depth = H.depth - 1
  if not ok or type(res) ~= "table" then return false end
  local found = res[hand]
  return type(found) == "table" and found[1] ~= nil
end

function H.conditions(f)
  local out = {}
  local lo, hi = H.RANK_ID[f.low], H.RANK_ID[f.high]
  if not ((lo == 2 and hi == 14) or (hi == 2 and lo == 14)) then out[#out + 1] = function(pick) return in_range(pick, f) end end
  if f.sum > 0 then out[#out + 1] = function(pick) return H.rank_sum(pick) >= f.sum end end
  if f.also and H.CHECK[f.also] then out[#out + 1] = function(pick) return H.CHECK[f.also](pick, f) end end
  if f.contains then out[#out + 1] = function(pick) return H.contains(pick, f.contains) end end
  return out
end

function H.match(cards, c)
  local f = H.fields(c)
  local check = H.CHECK[f.pattern]
  local k = H.total(f)
  if not check or #cards < k or k < 1 then return nil end
  local extra = H.conditions(f)
  local fast = H.FAST[f.pattern]
  if fast and #extra == 0 then
    local pick = fast(cards, k, f)
    if pick ~= false then return pick end
  end
  if n_choose_k(#cards, k) > H.COMBO_LIMIT then return nil end
  local found = nil
  combos(#cards, k, function(idx)
    local pick = {}
    for i, j in ipairs(idx) do pick[i] = cards[j] end
    if not check(pick, f) then return false end
    for _, ok in ipairs(extra) do if not ok(pick) then return false end end
    found = pick
    return true
  end)
  return found
end

function H.root(c)
  local seen = {}
  local depth = 0
  local beats = H.fields(c).beats
  while not H.VANILLA_ORDER[beats] do
    local o = H.by_key[beats]
    if not o or seen[beats] or depth > 20 then return "Flush", depth end
    seen[beats] = true
    depth = depth + 1
    beats = H.fields(o.c or o).beats
  end
  return beats, depth
end

function H.order_list(base)
  local out = {}
  for _, h in ipairs(base or H.VANILLA) do
    if not H.by_key[h] then out[#out + 1] = h end
  end
  local left = {}
  for i = #H.list, 1, -1 do left[#left + 1] = H.list[i] end
  local function place(c, beats)
    local at = #out + 1
    for j, h in ipairs(out) do if h == beats then at = j break end end
    table.insert(out, at, H.key(c))
  end
  local moved = true
  while #left > 0 and moved do
    moved = false
    local rest = {}
    for _, c in ipairs(left) do
      local beats = H.fields(c).beats
      local ready = H.VANILLA_ORDER[beats] ~= nil
      if not ready then for _, h in ipairs(out) do if h == beats then ready = true break end end end
      if ready then place(c, beats); moved = true else rest[#rest + 1] = c end
    end
    left = rest
  end
  for _, c in ipairs(left) do place(c, (H.root(c))) end
  return out
end

function H.rank_of(key, list)
  for i, h in ipairs(list or G.handlist or H.VANILLA) do if h == key then return i end end
  return 1e9
end

function H.example(c)
  local f = H.fields(c)
  local ex = {}
  local suit_codes = {"S", "H", "C", "D"}
  local codes = {[14] = "A", [13] = "K", [12] = "Q", [11] = "J", [10] = "T"}
  local lo, hi = H.RANK_ID[f.low], H.RANK_ID[f.high]
  if lo > hi then lo, hi = hi, lo end
  local ranks = {}
  for id = hi, lo, -1 do ranks[#ranks + 1] = codes[id] or tostring(id) end
  local runs = {
    same_rank = {ranks[math.min(3, #ranks)]},
    all_face = {"K", "Q", "J"},
    all_even = {"T", "8", "6", "4", "2"},
    all_odd = {"A", "9", "7", "5", "3"},
  }
  local row = (f.count <= 5 and lo == 2 and hi == 14) and {"9", "8", "7", "6", "5"} or ranks
  local total = H.total(f)
  local n = math.min(total, H.EXAMPLE_MAX)
  for i = 1, n do
    local s, r = suit_codes[(i - 1) % 4 + 1], ranks[(i - 1) % #ranks + 1]
    if f.pattern == "same_suit" then s = "H" end
    if f.pattern == "in_a_row" then r = row[(i - 1) % #row + 1] end
    local list = runs[f.pattern]
    if list then r = list[(i - 1) % #list + 1] end
    if f.pattern == "kinds" then r = i <= f.count and ranks[1] or ranks[math.min(#ranks, 2)] end
    if f.pattern == "suit_groups" then s = i <= f.count and "H" or "S" end
    ex[#ex + 1] = {s .. "_" .. r, true}
  end
  return ex
end

function H.game_entry(c)
  local f = H.fields(c)
  local root, depth = H.root(c)
  return {visible = not f.hidden, order = H.VANILLA_ORDER[root] - 0.5 - depth * 0.01, mult = f.mult, chips = f.chips, s_mult = f.mult, s_chips = f.chips, level = 1,
    l_mult = f.l_mult, l_chips = f.l_chips, played = 0, played_this_round = 0, played_this_ante = 0, example = H.example(c), forge_hand = c.id}
end

function H.ensure_game_hands()
  local g = G and G.GAME
  if not (g and g.hands) then return end
  for _, c in ipairs(H.list) do
    local key = H.key(c)
    if not g.hands[key] then g.hands[key] = H.game_entry(c) end
  end
end

local function L(s) return mod_loc and mod_loc(s) or s end

function H.rank_label(v)
  local ok, Cat = pcall(require, "functions/forge/forge_catalog")
  if ok and Cat.value_label then return Cat.value_label("rankvalue", v) end
  return tostring(v)
end

function H.hand_label(v)
  local T = package.loaded["functions/forge/forge_text"]
  if H.by_key[v] then return H.by_key[v].name end
  return T and T.hand_name and T.hand_name(v) or tostring(v)
end

function H.doc_lines(f)
  local out = {}
  if H.GROUPS[f.pattern] then
    out[1] = string.format(L(H.PATTERN_TEXT[f.pattern]), f.count, f.group2)
  else
    out[1] = string.format(L(H.PATTERN_TEXT[f.pattern] or ""), f.count)
  end
  local lo, hi = H.RANK_ID[f.low], H.RANK_ID[f.high]
  if not ((lo == 2 and hi == 14) or (hi == 2 and lo == 14)) then
    local a, b = f.low, f.high
    if lo > hi then a, b = b, a end
    out[#out + 1] = string.format(L("Only ranks {C:attention}%s{} to {C:attention}%s{}"), H.rank_label(a), H.rank_label(b))
  end
  if f.sum > 0 then out[#out + 1] = string.format(L("Ranks add up to {C:attention}%d{} or more"), f.sum) end
  if f.also then out[#out + 1] = string.format(L("And also: %s"), L(H.PATTERN_LABEL[f.also] or f.also)) end
  if f.contains then out[#out + 1] = string.format(L("Must contain a {C:attention}%s{}"), H.hand_label(f.contains)) end
  if f.auto_level > 0 then out[#out + 1] = string.format(L("Levels up by itself every {C:attention}%d{} plays"), f.auto_level) end
  return out
end

function H.desc_lines(c)
  return H.doc_lines(H.fields(c))
end

H.PATTERN_LABEL = {
  each_suit = "Different suits", same_suit = "Same suit", same_rank = "Same rank", diff_rank = "Different ranks",
  in_a_row = "In a row", all_face = "Face cards", all_even = "Even ranks", all_odd = "Odd ranks", every_suit = "Every suit",
  kinds = "Two rank groups", suit_groups = "Two suit groups", any = "Any cards",
}
H.PATTERN_TEXT = {
  each_suit = "%d cards, each of a different suit", same_suit = "%d cards of the same suit", same_rank = "%d cards of the same rank", diff_rank = "%d cards, all different ranks",
  in_a_row = "%d cards with ranks in a row", all_face = "%d face cards", all_even = "%d cards of even rank", all_odd = "%d cards of odd rank", every_suit = "%d cards with every suit",
  kinds = "%d of a kind plus %d of a kind", suit_groups = "%d of one suit plus %d of another", any = "Any %d cards",
}

local function loc(c)
  local misc = G.localization and G.localization.misc
  if not misc then return end
  misc.poker_hands = misc.poker_hands or {}
  misc.poker_hand_descriptions = misc.poker_hand_descriptions or {}
  misc.poker_hands[H.key(c)] = c.name
  misc.poker_hand_descriptions[H.key(c)] = H.desc_lines(c)
end

function H.inject_loc()
  for _, c in ipairs(H.list) do loc(c) end
end

function H.smods_object(c)
  local f = H.fields(c)
  local SM = rawget(_G, "SMODS")
  local obj = {key = H.key(c), mult = f.mult, chips = f.chips, s_mult = f.mult, s_chips = f.chips, l_mult = f.l_mult, l_chips = f.l_chips, example = H.example(c),
    visible = not f.hidden, played = 0, played_this_round = 0, played_this_ante = 0, level = 1, set = "PokerHand", forge_hand = c.id, original_key = H.key(c), above_hand = (H.root(c))}
  obj.evaluate = function(_, hand)
    local m = H.match(hand, c)
    return m and {m} or {}
  end
  if SM and SM.PokerHand then setmetatable(obj, {__index = SM.PokerHand}) end
  return obj
end

function H.register()
  if not G then return end
  H.set_list(H.live(Store.live_items()))
  local SM = smods() and rawget(_G, "SMODS") or nil
  if SM and SM.PokerHands then
    for key, o in pairs(SM.PokerHands) do
      if type(o) == "table" and o.forge_hand and not H.by_key[key] then SM.PokerHands[key] = nil end
    end
    for _, c in ipairs(H.list) do SM.PokerHands[H.key(c)] = H.smods_object(c) end
  end
  if type(G.handlist) == "table" then
    local base = {}
    for _, h in ipairs(G.handlist) do if not H.id_of(h) then base[#base + 1] = h end end
    local list = H.order_list(base)
    for i = #G.handlist, 1, -1 do G.handlist[i] = nil end
    for i, h in ipairs(list) do G.handlist[i] = h end
    if SM and SM.PokerHands then
      for i, h in ipairs(G.handlist) do if SM.PokerHands[h] then SM.PokerHands[h].order = i end end
    end
  end
  H.inject_loc()
  H.ensure_game_hands()
end

function H.best(poker_hands, text)
  local list = G.handlist or H.order_list()
  local top = H.rank_of(text, list)
  local best, at = nil, top
  for _, c in ipairs(H.list) do
    local key = H.key(c)
    local r = H.rank_of(key, list)
    local found = poker_hands[key]
    if r < at and type(found) == "table" and found[1] then best, at = key, r end
  end
  return best
end

function H.auto_level()
  local key = G.GAME and G.GAME.last_hand_played
  local c = key and H.by_key[key]
  if not c then return end
  local f = H.fields(c)
  local h = G.GAME.hands[key]
  if f.auto_level <= 0 or not h then return end
  if (tonumber(h.played) or 0) > 0 and h.played % f.auto_level == 0 then level_up_hand(nil, key) end
end

function H.install_hooks()
  if H.hooked then return end
  local ok, Hooks = pcall(require, "overhaul.hooks")
  if not (ok and Hooks) then return end
  H.hooked = true
  Hooks.wrap(_G, "evaluate_poker_hand", function(orig) return function(hand, ...)
    local res = orig(hand, ...)
    if smods() or #H.list == 0 or type(res) ~= "table" then return res end
    for _, c in ipairs(H.list) do
      local m = H.match(hand, c)
      res[H.key(c)] = m and {m} or {}
    end
    return res
  end end, {id = "forge_hands.evaluate_poker_hand"})
  Hooks.wrap("G.FUNCS", "get_poker_hand_info", function(orig) return function(cards, ...)
    local text, loc_text, poker_hands, scoring, disp = orig(cards, ...)
    if smods() or #H.list == 0 or type(poker_hands) ~= "table" then return text, loc_text, poker_hands, scoring, disp end
    local key = H.best(poker_hands, text)
    if not key then return text, loc_text, poker_hands, scoring, disp end
    return key, localize(key, "poker_hands"), poker_hands, poker_hands[key][1], key
  end end, {id = "forge_hands.get_poker_hand_info"})
  Hooks.wrap(_G, "create_UIBox_current_hands", function(orig) return function(simple, ...)
    local t = orig(simple, ...)
    if smods() or #H.list == 0 or not (t and t.nodes and t.nodes[1] and t.nodes[1].nodes) then return t end
    local rows = {}
    for _, key in ipairs(G.handlist or H.order_list()) do
      if G.GAME.hands[key] then rows[#rows + 1] = create_UIBox_current_hand_row(key, simple) end
    end
    t.nodes[1].nodes = rows
    return t
  end end, {id = "forge_hands.current_hands"})
  Hooks.wrap("Game", "start_run", function(orig) return function(self, args, ...)
    local r = orig(self, args, ...)
    pcall(H.ensure_game_hands)
    return r
  end end, {id = "forge_hands.start_run"})
  Hooks.wrap("G.FUNCS", "evaluate_play", function(orig) return function(...)
    local r = orig(...)
    pcall(H.auto_level)
    return r
  end end, {id = "forge_hands.evaluate_play"})
end

local function register_strings()
  if not mod_loc_register then return end
  mod_loc_register{
    fr = {
      ["Poker hand"] = "Main de poker", ["Poker hands"] = "Mains de poker", ["Cards"] = "Cartes", ["Pattern"] = "Motif", ["Base chips"] = "Jetons de base", ["Base mult"] = "Multi de base",
      ["Chips per level"] = "Jetons par niveau", ["Mult per level"] = "Multi par niveau", ["Better than"] = "Meilleure que", ["Hidden until played"] = "Cachée avant d'être jouée",
      ["Different suits"] = "Couleurs différentes", ["Same suit"] = "Même couleur", ["Same rank"] = "Même valeur", ["Different ranks"] = "Valeurs différentes",
      ["In a row"] = "Qui se suivent", ["Face cards"] = "Figures", ["Even ranks"] = "Valeurs paires", ["Odd ranks"] = "Valeurs impaires",
      ["%d cards, each of a different suit"] = "%d cartes, chacune d'une couleur différente", ["%d cards of the same suit"] = "%d cartes de la même couleur", ["%d cards of the same rank"] = "%d cartes de la même valeur",
      ["%d cards, all different ranks"] = "%d cartes de valeurs toutes différentes", ["%d cards with ranks in a row"] = "%d cartes de valeurs qui se suivent", ["%d face cards"] = "%d figures",
      ["%d cards of even rank"] = "%d cartes de valeur paire", ["%d cards of odd rank"] = "%d cartes de valeur impaire",
      ["Every suit"] = "Toutes les couleurs", ["%d cards with every suit"] = "%d cartes avec toutes les couleurs",
      ["{C:chips}%s{} Chips, {C:mult}%s{} Mult, ranks above {C:attention}%s{}"] = "{C:chips}%s{} jetons, {C:mult}%s{} Multi, au-dessus de {C:attention}%s{}",
      ["Two rank groups"] = "Deux groupes de valeurs", ["Two suit groups"] = "Deux groupes de couleurs", ["Any cards"] = "N'importe quelles cartes",
      ["%d of a kind plus %d of a kind"] = "%d cartes de même valeur plus %d d'une autre valeur", ["%d of one suit plus %d of another"] = "%d cartes d'une couleur plus %d d'une autre", ["Any %d cards"] = "%d cartes au choix",
      ["When this hand is played"] = "Quand cette main est jouée", ["When one of its cards scores"] = "Quand une de ses cartes marque",
      ["Second group"] = "Second groupe", ["Rank sum at least"] = "Somme des valeurs au moins", ["And also"] = "Et aussi", ["Must contain"] = "Doit contenir", ["Levels up every N plays"] = "Monte de niveau toutes les N parties",
      ["Only ranks {C:attention}%s{} to {C:attention}%s{}"] = "Seulement de {C:attention}%s{} à {C:attention}%s{}", ["Ranks add up to {C:attention}%d{} or more"] = "Somme des valeurs d'au moins {C:attention}%d{}",
      ["And also: %s"] = "Et aussi : %s", ["Must contain a {C:attention}%s{}"] = "Doit contenir {C:attention}%s{}", ["Levels up by itself every {C:attention}%d{} plays"] = "Monte de niveau toute seule toutes les {C:attention}%d{} fois",
    },
    es = {
      ["Poker hand"] = "Mano de póker", ["Poker hands"] = "Manos de póker", ["Cards"] = "Cartas", ["Pattern"] = "Patrón", ["Base chips"] = "Fichas base", ["Base mult"] = "Multi base",
      ["Chips per level"] = "Fichas por nivel", ["Mult per level"] = "Multi por nivel", ["Better than"] = "Mejor que", ["Hidden until played"] = "Oculta hasta jugarla",
      ["Different suits"] = "Palos distintos", ["Same suit"] = "Mismo palo", ["Same rank"] = "Mismo valor", ["Different ranks"] = "Valores distintos",
      ["In a row"] = "Seguidas", ["Face cards"] = "Figuras", ["Even ranks"] = "Valores pares", ["Odd ranks"] = "Valores impares",
      ["%d cards, each of a different suit"] = "%d cartas, cada una de un palo distinto", ["%d cards of the same suit"] = "%d cartas del mismo palo", ["%d cards of the same rank"] = "%d cartas del mismo valor",
      ["%d cards, all different ranks"] = "%d cartas de valores distintos", ["%d cards with ranks in a row"] = "%d cartas de valores seguidos", ["%d face cards"] = "%d figuras",
      ["%d cards of even rank"] = "%d cartas de valor par", ["%d cards of odd rank"] = "%d cartas de valor impar",
      ["Every suit"] = "Todos los palos", ["%d cards with every suit"] = "%d cartas con todos los palos",
      ["{C:chips}%s{} Chips, {C:mult}%s{} Mult, ranks above {C:attention}%s{}"] = "{C:chips}%s{} fichas, {C:mult}%s{} multi, por encima de {C:attention}%s{}",
      ["Two rank groups"] = "Dos grupos de valores", ["Two suit groups"] = "Dos grupos de palos", ["Any cards"] = "Cualquier carta",
      ["%d of a kind plus %d of a kind"] = "%d cartas de un valor más %d de otro", ["%d of one suit plus %d of another"] = "%d cartas de un palo más %d de otro", ["Any %d cards"] = "%d cartas cualesquiera",
      ["When this hand is played"] = "Cuando se juega esta mano", ["When one of its cards scores"] = "Cuando anota una de sus cartas",
      ["Second group"] = "Segundo grupo", ["Rank sum at least"] = "Suma de valores mínima", ["And also"] = "Y además", ["Must contain"] = "Debe contener", ["Levels up every N plays"] = "Sube de nivel cada N jugadas",
      ["Only ranks {C:attention}%s{} to {C:attention}%s{}"] = "Solo del {C:attention}%s{} al {C:attention}%s{}", ["Ranks add up to {C:attention}%d{} or more"] = "Los valores suman {C:attention}%d{} o más",
      ["And also: %s"] = "Y además: %s", ["Must contain a {C:attention}%s{}"] = "Debe contener {C:attention}%s{}", ["Levels up by itself every {C:attention}%d{} plays"] = "Sube de nivel sola cada {C:attention}%d{} jugadas",
    },
  }
end

register_strings()

return H
