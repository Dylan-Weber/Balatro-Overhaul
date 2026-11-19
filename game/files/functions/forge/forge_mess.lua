return function(R)
  local M = {}
  R.MESS = M
  M.V = 16
  M.ORDER = {"blind_x", "blind_set", "ante_move", "level_down", "level_random", "level_most", "free_reroll"}
  M.IDS = {}
  for _, id in ipairs(M.ORDER) do M.IDS[id] = true end

  R.NUM.blind_x = {def = 0.75, lo = 0.05, hi = 100, step = 0.05, big = 0.5}
  R.NUM.blind_set = {def = 300, lo = 1, hi = R.BIG, step = 50, big = 1000}
  R.NUM.ante_move = {def = -1, lo = -10, hi = 10, step = 1, big = 5}
  R.NUM.level_down = {def = 1, lo = 1, hi = 100, step = 1, big = 10}
  R.NUM.level_random = {def = 1, lo = 1, hi = 100, step = 1, big = 10}
  R.NUM.level_most = {def = 1, lo = 1, hi = 100, step = 1, big = 10}
  R.NUM.free_reroll = {def = 1, lo = 1, hi = 100, step = 1, big = 10}
  R.MULT_NUM.blind_x = true

  local function set(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
  end
  local BLIND = set({"blind_selected", "hand_played", "before", "after", "card_scored", "card_held", "discard", "first_hand"})
  local LEVEL = set({"before", "hand_played", "after"})
  local ANY = set({"blind_selected", "hand_played", "before", "after", "discard", "round_end", "card_scored", "card_held", "blind_skipped", "shop_end", "self_sold"})
  M.WHEN = {
    blind_x = BLIND, blind_set = BLIND,
    ante_move = set({"blind_selected", "round_end", "blind_skipped", "shop_end", "self_sold"}),
    level_down = LEVEL, level_random = ANY, level_most = ANY,
    free_reroll = set({"round_end", "blind_selected", "blind_skipped", "reroll", "self_sold"}),
  }

  for _, id in ipairs(M.ORDER) do
    if not R.member(R.GIVE, id) then R.GIVE[#R.GIVE + 1] = id end
    R.HOST_GIVE[id] = {joker = true, card = true}
    R.GIVE_WHEN[id] = M.WHEN[id]
    R.SIMPLE_GIVE[id] = true
    R.DEFAULT_GIVE[id] = function() return {id = id, n = R.NUM[id].def} end
  end

  local function whole(n, lo)
    n = math.floor((tonumber(n) or 1) + 0.5)
    return math.max(lo or 1, n)
  end

  function M.blind_chips(cur, id, n)
    n = tonumber(n)
    if not n or n ~= n then return cur end
    if id == "blind_set" then return math.max(1, math.floor(n)) end
    if type(cur) ~= "number" then
      local ok, r = pcall(function() return cur * n end)
      return ok and r or cur
    end
    return math.max(1, math.floor(cur * math.max(0.01, n)))
  end

  function M.ante_step(ante, n)
    ante = math.floor(tonumber(ante) or 1)
    n = tonumber(n) or 0
    n = n >= 0 and math.floor(n + 0.5) or -math.floor(-n + 0.5)
    return math.max(n, 1 - ante)
  end

  function M.most_played(hands, order)
    local best, top = nil, -1
    for _, name in ipairs(order or {}) do
      local h = hands and hands[name]
      if type(h) == "table" and (h.visible ~= false) and (tonumber(h.played) or 0) > top then
        best, top = name, tonumber(h.played) or 0
      end
    end
    return best
  end

  function M.down_amount(level, n)
    level = math.floor(tonumber(level) or 1)
    return math.max(0, math.min(whole(n), level - 1))
  end

  local function hand_order()
    local out = {}
    for _, name in ipairs(G.handlist or {}) do out[#out + 1] = name end
    for name in pairs(G.GAME and G.GAME.hands or {}) do
      if not R.member(out, name) then out[#out + 1] = name end
    end
    return out
  end

  local function visible_hands()
    local out = {}
    for _, name in ipairs(hand_order()) do
      local h = G.GAME.hands[name]
      if type(h) == "table" and h.visible ~= false then out[#out + 1] = name end
    end
    return out
  end

  local function status(src, text, colour)
    if src and card_eval_status_text then card_eval_status_text(src, "extra", nil, nil, nil, {message = text, colour = colour}) end
  end

  local function update_blind()
    local b = G.GAME and G.GAME.blind
    if not b then return end
    b.chip_text = number_format(b.chips)
    if G.HUD_blind then
      local t = G.HUD_blind:get_UIE_by_ID("HUD_blind_count")
      if t and t.UIBox then t.UIBox:recalculate() end
    end
  end

  local function blind_do(g, card, src)
    local b = G.GAME and G.GAME.blind
    if not (b and b.chips) then return end
    b.chips = M.blind_chips(b.chips, g.id, g.n)
    update_blind()
    status(src, g.id == "blind_set" and number_format(b.chips) or ("X" .. tostring(g.n)), G.C.FILTER)
  end
  R.DOS.blind_x = blind_do
  R.DOS.blind_set = blind_do

  R.DOS.ante_move = function(g, card, src)
    local rr = G.GAME and G.GAME.round_resets
    if not rr then return end
    local d = M.ante_step(rr.ante, g.n)
    if d == 0 then return end
    ease_ante(d)
    rr.blind_ante = (rr.blind_ante or rr.ante) + d
    status(src, (d > 0 and "+" or "") .. d, G.C.FILTER)
  end

  R.DOS.level_down = function(g, card, src, context)
    local name = context and context.scoring_name
    local h = name and G.GAME.hands[name]
    if not h then return end
    local d = M.down_amount(h.level, g.n)
    if d <= 0 then return end
    status(src, "-" .. d, G.C.RED)
    level_up_hand(src, name, nil, -d)
  end

  R.DOS.level_random = function(g, card, src)
    local list = visible_hands()
    if #list == 0 then return end
    local name = pseudorandom_element(list, pseudoseed("forge_lvl_rand"))
    if not name then return end
    status(src, localize("k_level_up_ex"), G.C.SECONDARY_SET and G.C.SECONDARY_SET.Planet)
    level_up_hand(src, name, nil, whole(g.n))
  end

  R.DOS.level_most = function(g, card, src)
    local name = M.most_played(G.GAME.hands, hand_order())
    if not name then return end
    status(src, localize("k_level_up_ex"), G.C.SECONDARY_SET and G.C.SECONDARY_SET.Planet)
    level_up_hand(src, name, nil, whole(g.n))
  end

  R.DOS.free_reroll = function(g, card, src)
    local cr = G.GAME and G.GAME.current_round
    if not cr then return end
    if G.STATE ~= G.STATES.SHOP then
      G.GAME.forge_rr_next = (tonumber(G.GAME.forge_rr_next) or 0) + whole(g.n)
    else
      cr.free_rerolls = math.max(0, (cr.free_rerolls or 0) + whole(g.n))
      if calculate_reroll_cost then calculate_reroll_cost(true) end
    end
    status(src, localize("k_reroll"), G.C.GREEN)
  end

  local base_need = R.need_v
  function R.need_v(rules, vars)
    local need = base_need(rules, vars)
    for _, r in ipairs(type(rules) == "table" and rules or {}) do
      for _, l in ipairs(type(r) == "table" and {r.give, r.alt} or {}) do
        for _, g in ipairs(type(l) == "table" and l or {}) do
          if type(g) == "table" and M.IDS[g.id] then need = math.max(need, M.V) end
        end
      end
    end
    return need
  end

  local L = {
    en = {blind_x = "the Blind score becomes {C:attention}X%s{}", blind_set = "the Blind score becomes {C:attention}%s{}", ante_move = "Ante {C:attention}%s{}", level_down = "the hand loses {C:attention}%d{} level", level_random = "a random poker hand gains {C:attention}%d{} level", level_most = "your most played hand gains {C:attention}%d{} level", free_reroll = "{C:green}%d{} free reroll"},
    fr = {blind_x = "le score de la Blinde devient {C:attention}X%s{}", blind_set = "le score de la Blinde devient {C:attention}%s{}", ante_move = "Mise {C:attention}%s{}", level_down = "la main perd {C:attention}%d{} niveau", level_random = "une main de poker au hasard gagne {C:attention}%d{} niveau", level_most = "votre main la plus jouée gagne {C:attention}%d{} niveau", free_reroll = "{C:green}%d{} relance gratuite"},
    es = {blind_x = "el puntaje de la ciega pasa a {C:attention}X%s{}", blind_set = "el puntaje de la ciega pasa a {C:attention}%s{}", ante_move = "Apuesta {C:attention}%s{}", level_down = "la mano pierde {C:attention}%d{} nivel", level_random = "una mano de póker al azar gana {C:attention}%d{} nivel", level_most = "tu mano más jugada gana {C:attention}%d{} nivel", free_reroll = "{C:green}%d{} renovación gratis"},
  }
  local function lt(lang) return L[lang] or L.en end
  local function T() return package.loaded["functions/forge/forge_text"] end
  local function fmt(n)
    local t = T()
    return t and t.fmt_n and t.fmt_n(n) or tostring(n)
  end
  function M.text(g, lang)
    local s = lt(lang)[g.id]
    if not s then return "" end
    if g.id == "ante_move" then
      local n = math.floor((tonumber(g.n) or 0) + 0.5)
      return string.format(s, (n > 0 and "+" or "") .. n)
    end
    if g.id == "blind_x" then return string.format(s, fmt(g.n)) end
    if g.id == "blind_set" then return string.format(s, number_format and number_format(tonumber(g.n) or 0) or fmt(g.n)) end
    return string.format(s, whole(g.n))
  end
  for _, id in ipairs(M.ORDER) do
    R.TEXT_GIVE[id] = function(g, s, lang) return M.text(g, lang) end
  end

  local LG = R.LABEL_GIVE
  LG.blind_x, LG.blind_set, LG.ante_move = "Blind score x", "Set the Blind score", "Change the ante"
  LG.level_down, LG.level_random, LG.level_most, LG.free_reroll = "Level down the hand", "Level up a random hand", "Level up the most played hand", "Free rerolls"

  if mod_loc_register then
    mod_loc_register{
      fr = {["Blind score x"] = "Score de la Blinde x", ["Set the Blind score"] = "Fixer le score de la Blinde", ["Change the ante"] = "Changer la mise", ["Level down the hand"] = "Baisser le niveau de la main", ["Level up a random hand"] = "Monter une main au hasard", ["Level up the most played hand"] = "Monter la main la plus jouée", ["Free rerolls"] = "Relances gratuites"},
      es = {["Blind score x"] = "Puntaje de la ciega x", ["Set the Blind score"] = "Fijar el puntaje de la ciega", ["Change the ante"] = "Cambiar la apuesta", ["Level down the hand"] = "Bajar de nivel la mano", ["Level up a random hand"] = "Subir una mano al azar", ["Level up the most played hand"] = "Subir la mano más jugada", ["Free rerolls"] = "Renovaciones gratis"},
    }
  end

  M.SHOP = {"p_shop_slots", "p_reroll_off", "p_free_item"}
  M.SHOP_KEY = {p_shop_slots = "shop_slots", p_reroll_off = "reroll_off", p_free_item = "free_item"}
  local P = require("functions/forge/forge_power3")
  P.APPLY = P.APPLY or {}
  R.NUM.p_shop_slots = {def = 1, lo = 1, hi = 5, step = 1, big = 1}
  R.NUM.p_reroll_off = {def = 1, lo = 1, hi = 100, step = 1, big = 5}
  R.NUM.p_free_item = {def = 1, lo = 1, hi = 5, step = 1, big = 1}
  for _, id in ipairs(M.SHOP) do
    M.IDS[id] = true
    if not R.member(R.GIVE, id) then R.GIVE[#R.GIVE + 1] = id end
    if not R.member(P.PASSIVE, id) then P.PASSIVE[#P.PASSIVE + 1] = id end
    P.KEY[id] = M.SHOP_KEY[id]
    if P.PASS then P.PASS[id] = true end
    R.HOST_GIVE[id] = {joker = true}
    R.SIMPLE_GIVE[id] = true
    R.DEFAULT_GIVE[id] = function() return {id = id, n = R.NUM[id].def} end
  end

  P.APPLY.shop_slots = function(d)
    if change_shop_size and G.GAME.shop then change_shop_size(d) end
  end
  P.APPLY.reroll_off = function(d)
    G.GAME.forge_reroll_off = math.max(0, (tonumber(G.GAME.forge_reroll_off) or 0) + d)
    M.install()
    if calculate_reroll_cost and G.GAME.current_round then calculate_reroll_cost(true) end
  end
  P.APPLY.free_item = function(d)
    G.GAME.forge_free_items = math.max(0, (tonumber(G.GAME.forge_free_items) or 0) + d)
  end

  function M.reroll_cost(cost, off)
    off = tonumber(off) or 0
    if type(cost) ~= "number" or off <= 0 then return cost end
    return math.max(0, cost - off)
  end

  function M.free_shop_items(cards, n)
    local done = 0
    for i = 1, math.min(tonumber(n) or 0, #(cards or {})) do
      local c = cards[i]
      if c and c.ability and not c.ability.couponed then
        c.ability.couponed = true
        if c.set_cost then c:set_cost() end
        done = done + 1
      end
    end
    return done
  end

  function M.install()
    if not calculate_reroll_cost or calculate_reroll_cost == M.wrapped then return end
    local base = calculate_reroll_cost
    M.wrapped = function(...)
      local r = base(...)
      local cr = G.GAME and G.GAME.current_round
      if cr and (tonumber(G.GAME.forge_reroll_off) or 0) > 0 then cr.reroll_cost = M.reroll_cost(cr.reroll_cost, G.GAME.forge_reroll_off) end
      return r
    end
    calculate_reroll_cost = M.wrapped
  end

  function M.shop_opened()
    M.install()
    if (tonumber(G.GAME and G.GAME.forge_reroll_off) or 0) > 0 and G.GAME.current_round then calculate_reroll_cost(true) end
    local n = tonumber(G.GAME and G.GAME.forge_free_items) or 0
    if n <= 0 then return end
    local tries = 0
    G.E_MANAGER:add_event(Event({blocking = false, func = function()
      tries = tries + 1
      if not (G.shop_jokers and G.shop_jokers.cards and #G.shop_jokers.cards > 0) then return tries > 600 end
      M.free_shop_items(G.shop_jokers.cards, n)
      return true
    end}))
  end

  local SL = {
    en = {p_shop_slots = "{C:attention}+%d{} card slot in the shop", p_reroll_off = "Rerolls cost {C:money}$%d{} less", p_free_item = "The first {C:attention}%d{} card in every shop is free"},
    fr = {p_shop_slots = "{C:attention}+%d{} emplacement de carte en boutique", p_reroll_off = "Les relances coûtent {C:money}%d ${} de moins", p_free_item = "La première {C:attention}%d{} carte de chaque boutique est gratuite"},
    es = {p_shop_slots = "{C:attention}+%d{} espacio de carta en la tienda", p_reroll_off = "Las renovaciones cuestan {C:money}$%d{} menos", p_free_item = "La primera {C:attention}%d{} carta de cada tienda es gratis"},
  }
  for _, id in ipairs(M.SHOP) do
    R.TEXT_GIVE[id] = function(g, s, lang) return string.format((SL[lang] or SL.en)[id], whole(g.n)) end
  end
  LG.p_shop_slots, LG.p_reroll_off, LG.p_free_item = "Shop card slots", "Cheaper rerolls", "Free card each shop"
  if mod_loc_register then
    mod_loc_register{
      fr = {["Shop card slots"] = "Emplacements en boutique", ["Cheaper rerolls"] = "Relances moins chères", ["Free card each shop"] = "Carte gratuite par boutique"},
      es = {["Shop card slots"] = "Espacios en la tienda", ["Cheaper rerolls"] = "Renovaciones más baratas", ["Free card each shop"] = "Carta gratis por tienda"},
    }
  end

  M.DEBUFF = {"debuff_card", "undebuff_hand"}
  R.NUM.debuff_card = {def = 1, lo = 1, hi = 10, step = 1, big = 5}
  R.NUM.undebuff_hand = {def = 8, lo = 1, hi = 20, step = 1, big = 5}
  M.WHEN.debuff_card = set({"card_scored", "card_held", "discard"})
  M.WHEN.undebuff_hand = set({"blind_selected", "before", "hand_played", "after", "discard"})
  for _, id in ipairs(M.DEBUFF) do
    M.IDS[id] = true
    if not R.member(R.GIVE, id) then R.GIVE[#R.GIVE + 1] = id end
    R.HOST_GIVE[id] = {joker = true}
    R.GIVE_WHEN[id] = M.WHEN[id]
    R.SIMPLE_GIVE[id] = true
    R.DEFAULT_GIVE[id] = function() return {id = id, n = R.NUM[id].def} end
    R.TEXT_GIVE[id] = function(g, s, lang) return M.text(g, lang) end
  end
  L.en.debuff_card, L.en.undebuff_hand = "the card is debuffed for {C:attention}%d{} round", "up to {C:attention}%d{} debuffed cards in hand work again"
  L.fr.debuff_card, L.fr.undebuff_hand = "la carte est affaiblie pendant {C:attention}%d{} manche", "jusqu'à {C:attention}%d{} cartes affaiblies en main remarchent"
  L.es.debuff_card, L.es.undebuff_hand = "la carta queda debilitada {C:attention}%d{} ronda", "hasta {C:attention}%d{} cartas debilitadas en mano vuelven a funcionar"
  LG.debuff_card, LG.undebuff_hand = "Debuff the card", "Un-debuff cards in hand"
  if mod_loc_register then
    mod_loc_register{
      fr = {["Debuff the card"] = "Affaiblir la carte", ["Un-debuff cards in hand"] = "Réparer les cartes en main"},
      es = {["Debuff the card"] = "Debilitar la carta", ["Un-debuff cards in hand"] = "Reparar las cartas en mano"},
    }
  end

  function M.debuff_of(ab, round)
    if type(ab) ~= "table" then return nil end
    round = tonumber(round) or 0
    if tonumber(ab.forge_undebuff) and ab.forge_undebuff >= round then return false end
    if tonumber(ab.forge_debuff) and ab.forge_debuff >= round then return true end
    return nil
  end

  function M.install_debuff()
    if not (Blind and Blind.debuff_card) or Blind.debuff_card == M.debuff_wrapped then return end
    local orig = Blind.debuff_card
    M.debuff_wrapped = function(self, card, from_blind)
      local r = orig(self, card, from_blind)
      if card and card.area ~= G.jokers then
        local st = M.debuff_of(card.ability, G.GAME and G.GAME.round)
        if st ~= nil then card:set_debuff(st) end
      end
      return r
    end
    Blind.debuff_card = M.debuff_wrapped
  end

  R.DOS.debuff_card = function(g, card, src, context, other)
    if not (other and other.ability and G.GAME) then return end
    M.install_debuff()
    other.ability.forge_undebuff = nil
    other.ability.forge_debuff = (tonumber(G.GAME.round) or 0) + whole(g.n) - 1
    other:set_debuff(true)
    status(src, localize("k_debuffed"), G.C.RED)
  end

  R.DOS.undebuff_hand = function(g, card, src)
    if not (G.hand and G.GAME) then return end
    M.install_debuff()
    local left = whole(g.n)
    for _, c in ipairs(G.hand.cards) do
      if left <= 0 then break end
      if c.debuff and c.ability then
        c.ability.forge_debuff = nil
        c.ability.forge_undebuff = tonumber(G.GAME.round) or 0
        c:set_debuff(false)
        left = left - 1
      end
    end
    status(src, localize("k_active_ex"), G.C.GREEN)
  end

  return M
end
