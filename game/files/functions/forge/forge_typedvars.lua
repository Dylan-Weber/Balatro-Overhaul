return function(R)
  R.TYPED_V = 10
  R.VAR_TYPES = {"number", "suit", "rank", "hand", "edition", "enhancement", "seal"}
  R.VAR_FOR_ONLY = {suit = "suit", rank = "rank", hand = "hand", edition = "edition", enhancement = "enhancement", seal = "seal"}
  R.VAR_RANKS = {14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2}
  R.VAR_GIVE.var_pick = true
  R.GIVE[#R.GIVE + 1] = "var_pick"

  local function text() return package.loaded["functions/forge/forge_text"] end

  function R.var_values(ty)
    if ty == "suit" then return {"Hearts", "Diamonds", "Spades", "Clubs"} end
    if ty == "rank" then return R.VAR_RANKS end
    if ty == "hand" then return R.HANDS end
    if ty == "edition" then return R.editions() end
    if ty == "enhancement" then return R.enhancements() end
    if ty == "seal" then return R.seals() end
    return {}
  end

  function R.var_ok(ty, v)
    if v == nil then return false end
    for _, x in ipairs(R.var_values(ty)) do
      if x == v or (ty == "rank" and tonumber(v) == x) then return true end
    end
    return false
  end

  function R.var_ref(v)
    if type(v) ~= "string" then return nil end
    local n = tonumber(v:match("^var:(%d)$"))
    if n and n >= 1 and n <= R.MAX_VARS then return n end
    return nil
  end

  function R.var_random(ty, cur)
    local list = {}
    for _, v in ipairs(R.var_values(ty)) do
      local seen = ty ~= "hand" or not (G.GAME and G.GAME.hands and G.GAME.hands[v]) or G.GAME.hands[v].visible
      if seen and v ~= cur then list[#list + 1] = v end
    end
    if #list == 0 then return cur end
    if G.GAME and G.GAME.pseudorandom and pseudoseed then
      return pseudorandom_element(list, pseudoseed("forge_var_" .. ty))
    end
    return list[math.random(#list)]
  end

  function R.var_show(ty, v, lang)
    local T = text()
    if not T then return tostring(v) end
    lang = lang or (G and G.SETTINGS and G.SETTINGS.language == "fr" and "fr") or (G and G.SETTINGS and tostring(G.SETTINGS.language):sub(1, 2) == "es" and "es") or "en"
    if v == nil or v == "random" then return T.random_word(lang) end
    if ty == "suit" then return T.suit_name(v, lang == "es") end
    if ty == "rank" then return T.rank_name(v, lang) end
    if ty == "hand" then return T.hand_name(v) end
    if ty == "edition" then return T.edition_name(v) end
    if ty == "enhancement" then return T.enh_name(v) end
    if ty == "seal" then return T.seal_name(v) end
    return tostring(v)
  end

  function R.clean_typed(v, out)
    local ty = v.type
    if ty == nil or ty == "number" then return false end
    local ok = false
    for _, t in ipairs(R.VAR_TYPES) do if t == ty then ok = true end end
    if not ok then return false end
    out.type = ty
    local s = v.start
    if ty == "rank" then s = tonumber(s) or s end
    out.start = R.var_ok(ty, s) and s or "random"
    return true
  end

  function R.typed_state(x, defs)
    x.var_types = {}
    for i, d in ipairs(type(defs) == "table" and defs or {}) do
      local ty = d.type
      if ty and ty ~= "number" then
        x.var_types[i] = ty
        if not R.var_ok(ty, x.vars[i]) then
          x.vars[i] = (d.start == "random" or not R.var_ok(ty, d.start)) and R.var_random(ty) or d.start
        end
      else
        x.var_types[i] = nil
      end
    end
  end

  local has_refs = setmetatable({}, {__mode = "k"})
  local function rule_refs(rules)
    if type(rules) ~= "table" then return false end
    local c = has_refs[rules]
    if c ~= nil then return c end
    c = false
    for _, r in ipairs(rules) do
      if type(r) == "table" then
        for _, o in ipairs(type(r.only) == "table" and r.only or {}) do if R.var_ref(o.v) or R.num_ref(o) then c = true end end
        for _, l in ipairs({r.give, r.alt}) do
          for _, g in ipairs(type(l) == "table" and l or {}) do if R.var_ref(g.v) or R.num_ref(g) then c = true end end
        end
      end
    end
    has_refs[rules] = c
    return c
  end
  R.rule_refs = rule_refs

  local function cur_vars(card)
    local x = R.cur_state or card and card.ability and card.ability.extra
    return type(x) == "table" and type(x.vars) == "table" and x.vars or {}
  end

  local function swap(list, vars, cond)
    if type(list) ~= "table" then return list end
    local out = {}
    for i, e in ipairs(list) do
      local n = type(e) == "table" and R.var_ref(e.v)
      local nv = type(e) == "table" and R.num_ref(e)
      if n or nv then
        local c = {}
        for k, v in pairs(e) do c[k] = v end
        if n then
          c.v = vars[n]
          if c.v == nil then c.v = "forge_unset" end
        end
        if nv then c.n = R.live_num(e, vars[nv], cond) end
        out[i] = c
      else
        out[i] = e
      end
    end
    return out
  end

  function R.resolve_refs(rules, card)
    if not rule_refs(rules) then return rules end
    local vars = cur_vars(card)
    local out = {}
    for i, r in ipairs(rules) do
      if type(r) == "table" then
        local c = {}
        for k, v in pairs(r) do c[k] = v end
        c.only, c.give, c.alt = swap(r.only, vars, true), swap(r.give, vars), swap(r.alt, vars)
        out[i] = c
      else
        out[i] = r
      end
    end
    return out
  end

  R.DOS.var_pick = function(g, card, src, context)
    if context.blueprint then return end
    local x = R.state(card)
    if type(x.vars) ~= "table" then x.vars = {} end
    local i = g.var or 1
    local ty = type(x.var_types) == "table" and x.var_types[i]
    if not ty then return end
    local v = g.v
    if v == "random" or not R.var_ok(ty, v) then v = R.var_random(ty, x.vars[i]) end
    x.vars[i] = v
    R.status(src, R.var_show(ty, v), G.C.FILTER)
  end

  R.DEFAULT_GIVE.var_pick = function() return {id = "var_pick", var = 1, v = "random"} end
  R.CLEAN_GIVE.var_pick = function(e)
    if e.v ~= "random" and type(e.v) ~= "string" and type(e.v) ~= "number" then e.v = "random" end
    e.n = nil
  end

  local base_allowed = R.allowed_give
  function R.allowed_give(when, give, host)
    if give == "var_pick" then give = "var_set" end
    return base_allowed(when, give, host)
  end


  R.ONLY[#R.ONLY + 1] = "every"
  R.NUM.every = {def = 5, lo = 2, hi = 1000, step = 1, big = 10}
  R.ONLY_WHEN.every = {}
  for _, w in ipairs(R.WHEN) do if w ~= "passive" then R.ONLY_WHEN.every[w] = true end end
  R.LABEL_ONLY = R.LABEL_ONLY or {}
  R.LABEL_ONLY.every = "Every N times"
  R.EVERY_TEXT = {
    en = {event = "every {C:attention}%d{} times", var = "each time {C:attention}%s{} reaches {C:attention}%d{}"},
    fr = {event = "toutes les {C:attention}%d{} fois", var = "chaque fois que {C:attention}%s{} atteint {C:attention}%d{}"},
    es = {event = "cada {C:attention}%d{} veces", var = "cada vez que {C:attention}%s{} llega a {C:attention}%d{}"},
  }
  R.TEXT_ONLY.every = function(o, s, lang, vars)
    local t = R.EVERY_TEXT[lang] or R.EVERY_TEXT.en
    local n = math.floor(tonumber(o.n) or 5)
    if o.v == "var" then
      local d = type(vars) == "table" and vars[o.var or 1]
      return string.format(t.var, d and d.name or "?", n)
    end
    return string.format(t.event, n)
  end
  R.DEFAULT_ONLY.every = function() return {id = "every", v = "event", n = R.NUM.every.def} end
  R.SIMPLE_ONLY = R.SIMPLE_ONLY or {}
  R.SIMPLE_ONLY.every = true
  R.CLEAN_ONLY.every = function(c)
    if c.v ~= "var" then c.v, c.var = "event", nil end
    c.op, c.neg = nil, nil
  end

  local function rule_i(seed)
    return tonumber(type(seed) == "string" and seed:match("_(%d+)$")) or 1
  end

  function R.every_left(o, x, i)
    local n = math.max(1, math.floor(tonumber(o.n) or 5))
    if o.v == "var" then
      local vars = type(x) == "table" and type(x.vars) == "table" and x.vars or {}
      return math.max(0, n - (tonumber(vars[o.var or 1]) or 0))
    end
    local cs = type(x) == "table" and type(x.counters) == "table" and x.counters or {}
    return math.max(1, n - (tonumber(cs["r" .. i]) or 0))
  end

  function R.every_hit(o, context, card, seed)
    local n = math.max(1, math.floor(tonumber(o.n) or 5))
    local x = R.state(card)
    local still = R.dry or context.blueprint
    if o.v == "var" then
      local i = o.var or 1
      if type(x.vars) ~= "table" then x.vars = {} end
      local v = tonumber(x.vars[i]) or 0
      if v < n then return false end
      if not still then x.vars[i] = v - n end
      return true
    end
    if type(x.counters) ~= "table" then x.counters = {} end
    local k = "r" .. rule_i(seed)
    local c = (tonumber(x.counters[k]) or 0) + 1
    if still then return c >= n end
    if c >= n then
      x.counters[k] = 0
      return true
    end
    x.counters[k] = c
    return false
  end

  local base_need = R.need_v
  function R.need_v(rules, vars)
    local need = base_need(rules, vars)
    for _, v in ipairs(type(vars) == "table" and vars or {}) do
      if type(v) == "table" and v.type and v.type ~= "number" then need = math.max(need, R.TYPED_V) end
    end
    if rule_refs(rules) then need = math.max(need, R.TYPED_V) end
    if R.nv_used(rules) then need = math.max(need, R.NV_V) end
    for _, r in ipairs(type(rules) == "table" and rules or {}) do
      for _, o in ipairs(type(r) == "table" and type(r.only) == "table" and r.only or {}) do
        if type(o) == "table" and o.id == "every" then need = math.max(need, R.TYPED_V) end
      end
    end
    for _, r in ipairs(type(rules) == "table" and rules or {}) do
      for _, l in ipairs(type(r) == "table" and {r.give, r.alt} or {}) do
        for _, g in ipairs(type(l) == "table" and l or {}) do
          if type(g) == "table" and (g.id == "var_pick" or (g.id == "copy_ability" and g.v == "random") or (R.XCHIPS_IDS and R.XCHIPS_IDS[g.id])) then need = math.max(need, R.TYPED_V) end
        end
      end
    end
    return need
  end
end
