return function(R)
  local T = require("functions/forge/forge_text")

  R.NEG_V = 11
  R.NEG_IDS = {"lose_money", "minus_chips", "minus_mult", "div_mult", "lose_hands", "lose_discard", "lose_hand_size", "blind_mult"}
  R.NEG_GIVE = {minus_chips = true, minus_mult = true}

  for _, id in ipairs(R.NEG_IDS) do
    if not R.member(R.GIVE, id) then R.GIVE[#R.GIVE + 1] = id end
  end

  R.NUM.lose_money = {def = 3, lo = 1, hi = R.BIG, step = 1, big = 5}
  R.NUM.minus_chips = {def = 30, lo = 5, hi = R.BIG, step = 5, big = 50}
  R.NUM.minus_mult = {def = 4, lo = 1, hi = R.BIG, step = 1, big = 10}
  R.NUM.div_mult = {def = 2, lo = 1.5, hi = 1e6, step = 0.5, big = 1}
  R.NUM.lose_hands = {def = 1, lo = 1, hi = R.MANY, step = 1, big = 10}
  R.NUM.lose_discard = {def = 1, lo = 1, hi = R.MANY, step = 1, big = 10}
  R.NUM.lose_hand_size = {def = 1, lo = 1, hi = 10, step = 1, big = 5}
  R.NUM.blind_mult = {def = 2, lo = 1.5, hi = 1000, step = 0.5, big = 1}

  local SCORE = {card_scored = true, card_held = true, hand_played = true}
  local ALL3 = {joker = true, card = true, run = true}
  R.GIVE_WHEN.minus_chips = {card_scored = true, hand_played = true}
  R.GIVE_WHEN.minus_mult = {card_scored = true, hand_played = true}
  R.GIVE_WHEN.div_mult = SCORE
  R.GIVE_WHEN.lose_hands = R.ROUND_WHEN
  R.GIVE_WHEN.lose_discard = R.ROUND_WHEN
  R.GIVE_WHEN.blind_mult = R.ROUND_WHEN
  for _, id in ipairs({"lose_money", "minus_chips", "minus_mult", "div_mult"}) do R.HOST_GIVE[id] = ALL3 end
  for _, id in ipairs({"lose_hands", "lose_discard", "lose_hand_size", "blind_mult"}) do R.HOST_GIVE[id] = {joker = true} end

  local function big_num(x)
    local conv = rawget(_G, "to_number")
    if (type(x) == "table" or type(x) == "cdata") and type(conv) == "function" then
      local ok, v = pcall(conv, x)
      if ok then x = v end
    end
    return tonumber(x) or 0
  end

  R.SCORE_GIVE.minus_chips = "chips"
  R.AMOUNT.minus_chips = function(g)
    return -math.min(tonumber(g.n) or 0, math.max(0, big_num(rawget(_G, "hand_chips"))))
  end
  R.SCORE_GIVE.minus_mult = "mult"
  R.AMOUNT.minus_mult = function(g)
    return -math.min(tonumber(g.n) or 0, math.max(0, big_num(rawget(_G, "mult"))))
  end
  R.SCORE_GIVE.div_mult = "xmult"
  R.AMOUNT.div_mult = function(g)
    local n = tonumber(g.n) or 1
    if n <= 1 then return 1 end
    return 1 / n
  end

  function R.is_pvp_blind()
    local b = G.GAME and G.GAME.blind
    if b and b.pvp then return true end
    local bm = rawget(_G, "bom_match")
    local ok, r = pcall(function() return bm and bm.is_pvp_blind and bm.is_pvp_blind() end)
    return ok and r and true or false
  end

  function R.apply_next_hand_size()
    local p = math.floor(tonumber(G.GAME and G.GAME.forge_next_hsize) or 0)
    G.GAME.forge_next_hsize = nil
    if p <= 0 or not (G.hand and G.hand.config) then return end
    local take = math.min(p, math.max(0, (tonumber(G.hand.config.card_limit) or 1) - 1))
    if take <= 0 then return end
    G.hand:change_size(-take)
    G.GAME.round_resets.temp_handsize = (G.GAME.round_resets.temp_handsize or 0) - take
  end

  local function hook_new_round()
    local f = rawget(_G, "new_round")
    if type(f) ~= "function" or R.new_round_hooked == f then return end
    local hooked = function(...)
      if G.GAME and G.GAME.forge_next_hsize then pcall(R.apply_next_hand_size) end
      return f(...)
    end
    R.new_round_hooked = hooked
    rawset(_G, "new_round", hooked)
  end
  hook_new_round()

  local D = R.DOS
  D.lose_money = function(g, card, src)
    local have = big_num(G.GAME.dollars) - big_num(G.GAME.bankrupt_at or 0)
    local n = math.min(tonumber(g.n) or 0, math.max(0, have))
    if n <= 0 then return end
    ease_dollars(-n)
    R.status(src, "-" .. localize("$") .. T.fmt_n(n), G.C.RED)
  end
  D.lose_hands = function(g, card, src)
    local left = tonumber(R.round_info().hands_left) or 0
    local n = math.min(math.floor(tonumber(g.n) or 0), left - 1)
    if n <= 0 then return end
    ease_hands_played(-n)
  end
  D.lose_discard = function(g, card, src)
    local left = tonumber(R.round_info().discards_left) or 0
    local n = math.min(math.floor(tonumber(g.n) or 0), left)
    if n <= 0 then return end
    ease_discard(-n)
  end
  D.lose_hand_size = function(g, card, src)
    local n = math.floor(tonumber(g.n) or 0)
    if n <= 0 then return end
    G.GAME.forge_next_hsize = (tonumber(G.GAME.forge_next_hsize) or 0) + n
    hook_new_round()
    R.status(src, "-" .. T.fmt_n(n), G.C.FILTER)
  end
  D.blind_mult = function(g, card, src)
    local b = G.GAME and G.GAME.blind
    local n = tonumber(g.n) or 1
    if n <= 1 or not b or not b.chips or R.is_pvp_blind() then return end
    if G.STATE == G.STATES.BLIND_SELECT or G.STATE == G.STATES.SHOP then return end
    b.chips = b.chips * n
    b.chip_text = number_format(b.chips)
    if G.HUD_blind and G.HUD_blind.recalculate then pcall(G.HUD_blind.recalculate, G.HUD_blind) end
    R.status(src, "X" .. T.fmt_n(n), G.C.RED)
  end

  local L = {
    en = {
      lose_money = "lose {C:money}$%s{}", minus_chips = "{C:chips}-%s{} Chips", minus_mult = "{C:mult}-%s{} Mult",
      div_mult = "{X:mult,C:white} /%s {} Mult", lose_hands = "{C:blue}-%s{} hand this round", lose_discard = "{C:red}-%s{} discard this round",
      lose_hand_size = "{C:attention}-%s{} hand size next round", blind_mult = "the current {C:attention}Blind{} needs {X:red,C:white} X%s {} score",
    },
    fr = {
      lose_money = "perdez {C:money}%s ${}", minus_chips = "{C:chips}-%s{} jetons", minus_mult = "{C:mult}-%s{} Multi",
      div_mult = "{X:mult,C:white} /%s {} Multi", lose_hands = "{C:blue}-%s{} main pour cette manche", lose_discard = "{C:red}-%s{} défausse pour cette manche",
      lose_hand_size = "{C:attention}-%s{} carte en main à la prochaine manche", blind_mult = "la {C:attention}blinde{} en cours demande un score {X:red,C:white} X%s {}",
    },
    es = {
      lose_money = "pierdes {C:money}$%s{}", minus_chips = "{C:chips}-%s{} fichas", minus_mult = "{C:mult}-%s{} multi",
      div_mult = "{X:mult,C:white} /%s {} multi", lose_hands = "{C:blue}-%s{} mano en esta ronda", lose_discard = "{C:red}-%s{} descarte en esta ronda",
      lose_hand_size = "{C:attention}-%s{} carta en mano en la próxima ronda", blind_mult = "la {C:attention}ciega{} actual pide {X:red,C:white} X%s {} de puntuación",
    },
  }
  for _, id in ipairs(R.NEG_IDS) do
    R.TEXT_GIVE[id] = function(g, s, lang) return string.format((L[lang] or L.en)[id], T.fmt_n(g.n)) end
  end

  local LG = R.LABEL_GIVE
  LG.lose_money, LG.minus_chips, LG.minus_mult, LG.div_mult = "Lose money", "-Chips", "-Mult", "Divide Mult"
  LG.lose_hands, LG.lose_discard, LG.lose_hand_size, LG.blind_mult = "Lose hands", "Lose discards", "Smaller hand next round", "Blind needs more score"
  for _, id in ipairs({"lose_money", "minus_chips", "minus_mult", "div_mult"}) do R.SIMPLE_GIVE[id] = true end

  if mod_loc_register then
    mod_loc_register{
      fr = {
        ["Lose money"] = "Perd de l'argent", ["-Chips"] = "-Jetons", ["-Mult"] = "-Multi", ["Divide Mult"] = "Divise le Multi",
        ["Lose hands"] = "Perd des mains", ["Lose discards"] = "Perd des défausses",
        ["Smaller hand next round"] = "Main plus petite à la prochaine manche", ["Blind needs more score"] = "La blinde demande plus",
      },
      es = {
        ["Lose money"] = "Pierde dinero", ["-Chips"] = "-Fichas", ["-Mult"] = "-Multi", ["Divide Mult"] = "Divide el multi",
        ["Lose hands"] = "Pierde manos", ["Lose discards"] = "Pierde descartes", ["Smaller hand next round"] = "Mano más pequeña la próxima ronda", ["Blind needs more score"] = "La ciega pide más",
      },
    }
  end

  local base_need = R.need_v
  function R.need_v(rules, vars)
    local need = base_need(rules, vars)
    local neg = {}
    for _, id in ipairs(R.NEG_IDS) do neg[id] = true end
    for _, r in ipairs(type(rules) == "table" and rules or {}) do
      for _, l in ipairs(type(r) == "table" and {r.give, r.alt} or {}) do
        for _, g in ipairs(type(l) == "table" and l or {}) do
          if type(g) == "table" and neg[g.id] then need = math.max(need, R.NEG_V) end
        end
      end
    end
    return need
  end
end
