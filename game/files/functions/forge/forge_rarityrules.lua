local X = {}

X.VANILLA = {"Common", "Uncommon", "Rare", "Legendary"}
X.NUM = {Common = 1, Uncommon = 2, Rare = 3, Legendary = 4}

local function Ra() return require("functions/forge/forge_rarities") end
local function Rules() return package.loaded["functions/forge/forge_rules"] end

function X.fields(c)
  local f = type(c) == "table" and type(c.fields) == "table" and c.fields or {}
  local function num(k, hi)
    local v = tonumber(f[k])
    if not v or v ~= v then return 0 end
    return math.max(0, math.min(hi, v))
  end
  local lo, hi = num("price_lo", 1e9), num("price_hi", 1e9)
  if lo > 0 and hi > 0 and lo > hi then lo, hi = hi, lo end
  return {price_lo = lo, price_hi = hi, sell = num("sell", 1e9), shop = f.shop ~= false, packs = f.packs ~= false}
end

function X.rarity_of(card)
  local cen = type(card) == "table" and card.config and card.config.center
  if not cen or cen.set ~= "Joker" then return nil end
  local r = cen.rarity
  if type(r) == "string" then return Ra().by_key[r] end
  return nil
end

function X.is_value(v)
  if X.NUM[v] then return true end
  local R = Rules()
  return R and R.own_id("rarity", v) ~= nil or false
end

function X.label(v, lang)
  if X.NUM[v] then
    local key = ({"k_common", "k_uncommon", "k_rare", "k_legendary"})[X.NUM[v]]
    local d = G and G.localization and G.localization.misc and G.localization.misc.dictionary
    return d and d[key] or v
  end
  return Ra().label(v)
end

function X.matches(card, v)
  local cen = card and card.config and card.config.center
  if not cen then return false end
  if X.NUM[v] then return cen.rarity == X.NUM[v] end
  return cen.rarity == v
end

function X.count(v)
  local n = 0
  for _, j in ipairs(G.jokers and G.jokers.cards or {}) do
    if X.matches(j, v) then n = n + 1 end
  end
  return n
end

function X.values()
  local out = {}
  for _, v in ipairs(X.VANILLA) do out[#out + 1] = v end
  local R = Rules()
  for _, v in ipairs(R and R.own_values("rarity") or {}) do out[#out + 1] = v end
  return out
end

function X.allowed(r, append)
  local f = X.fields(r and r.c)
  if append == "sho" and not f.shop then return false end
  if append == "buf" and not f.packs then return false end
  return true
end

function X.extra_rules(joker)
  local key = type(joker) == "table" and joker.own_rarity
  local r = key and Ra().by_key[key]
  local c = r and r.c
  if not (c and type(c.rules) == "table" and #c.rules > 0) then return nil end
  return c.rules
end

X.AS = {
  en = "{C:inactive}As a{} {C:attention}%s{} {C:inactive}Joker:{}",
  fr = "{C:inactive}En tant que joker{} {C:attention}%s{} {C:inactive}:{}",
  es = "{C:inactive}Como comodín{} {C:attention}%s{C:inactive}:{}",
}

function X.with_lines(c, lines, lang)
  local extra = X.extra_rules(c)
  if not extra then return lines end
  local T = require("functions/forge/forge_text")
  local R = Rules()
  local rules = R and R.clean_rules and R.clean_rules(extra) or extra
  local add = {}
  local prev = T.cur_kind
  T.cur_kind = "rarity"
  for _, rule in ipairs(rules) do
    local ok, sen = pcall(T.sentence, rule, lang, nil)
    if ok and sen then
      local first = sen:match("^({[^}]*})") or ""
      local rest = sen:sub(#first + 1)
      for _, l in ipairs(T.wrap(first .. rest:sub(1, 1):upper() .. rest:sub(2))) do add[#add + 1] = l end
    end
  end
  T.cur_kind = prev
  if #add == 0 then return lines end
  local out = {}
  for _, l in ipairs(lines or {}) do out[#out + 1] = l end
  out[#out + 1] = string.format(X.AS[lang] or X.AS.en, Ra().label(c.own_rarity))
  for _, l in ipairs(add) do out[#out + 1] = l end
  return out
end

function X.doc_lines(fields, add)
  local f = X.fields({fields = fields})
  if f.price_lo > 0 and f.price_hi > 0 then add(string.format(mod_loc("Its Jokers cost {C:money}$%d{} to {C:money}$%d{}"), f.price_lo, f.price_hi))
  elseif f.price_lo > 0 then add(string.format(mod_loc("Its Jokers cost at least {C:money}$%d{}"), f.price_lo))
  elseif f.price_hi > 0 then add(string.format(mod_loc("Its Jokers cost at most {C:money}$%d{}"), f.price_hi)) end
  if f.sell > 0 then add(string.format(mod_loc("Its Jokers sell for {C:money}$%d{} more"), f.sell)) end
  if not f.shop then add(mod_loc("Never in the shop")) end
  if not f.packs then add(mod_loc("Never in Buffoon packs")) end
end

X.HAVE = {
  en = "you have %s {C:attention}%d{} %s Jokers", fr = "vous avez %s {C:attention}%d{} jokers %s", es = "tienes %s {C:attention}%d{} comodines %s",
}
X.ONE = {en = "{C:attention}%s{} Joker", fr = "joker {C:attention}%s{}", es = "comodín {C:attention}%s{}"}
X.PER = {en = "%s you have", fr = "%s que vous avez", es = "%s que tienes"}

function X.rules(R)
  R.HOST_OF.rarity = "rarity"
  R.HOST_WHEN.rarity = R.JOKER_WHEN
  local base_give = R.allowed_give
  R.allowed_give = function(when, give, host, ...)
    if host == "rarity" then host = "joker" end
    return base_give(when, give, host, ...)
  end
  local base_only = R.allowed_only
  R.allowed_only = function(when, only, host, ...)
    if host == "rarity" then host = "joker" end
    return base_only(when, only, host, ...)
  end
  R.ONLY[#R.ONLY + 1] = "jokers_of"
  R.FILTER_ONLY.jokers_of = true
  R.NUM.jokers_of = {def = 1, lo = 0, hi = 100, step = 1, big = 5}
  R.DEFAULT_ONLY.jokers_of = function() return {id = "jokers_of", v = "Rare", op = "at_least", n = 1} end
  R.CLEAN_ONLY.jokers_of = function(c)
    if not X.is_value(c.v) then c.v = "Rare" end
    c.op = c.op or "at_least"
  end
  R.CHECKS.jokers_of = function(o) return R.compare(o.op, X.count(o.v), o.n) end
  R.TEXT_ONLY.jokers_of = function(o, s, lang)
    local op = (s and (s[o.op or "at_least"] or s.at_least)) or ""
    return string.format(X.HAVE[lang] or X.HAVE.en, op, tonumber(o.n) or 0, X.label(o.v, lang))
  end
  R.LABEL_ONLY.jokers_of = "Jokers of a rarity"
  local base_filter = R.filter_values
  R.filter_values = function(id)
    if id == "jokers_of" then return X.values() end
    return base_filter(id)
  end
  R.FILTER_LABEL = function(id, v)
    if (id == "jokers_of" or id == "jokers_rarity") and X.is_value(v) then return X.label(v) end
    return nil
  end
  local base_mlabel = R.match_label
  R.match_label = function(v, lang, plural)
    if X.is_value(v) then return X.label(v, lang) end
    return base_mlabel(v, lang, plural)
  end
  if not R.member(R.COUNTS, "jokers_rarity") then R.COUNTS[#R.COUNTS + 1] = "jokers_rarity" end
  R.COUNT_MATCH.jokers_rarity = true
  R.COUNT.jokers_rarity = function(g) return X.count(g.m) end
  if R.LABEL_COUNT then R.LABEL_COUNT.jokers_rarity = "Joker of a rarity you have" end
  for lang, t in pairs(R.PER_TEXT or {}) do
    if type(t) == "table" and type(t.counts) == "table" then t.counts.jokers_rarity = X.PER[lang] or X.PER.en end
  end
  local base_matches = R.count_matches
  R.count_matches = function(per)
    if per == "jokers_rarity" then return X.values() end
    return base_matches(per)
  end
  local base_one = R.one_label
  R.one_label = function(v, lang)
    if X.is_value(v) then return string.format(X.ONE[lang] or X.ONE.en, X.label(v, lang)) end
    return base_one(v, lang)
  end
  local base_m = R.count_m_label
  if base_m then
    R.count_m_label = function(per, m, lang)
      if X.is_value(m) then return R.one_label(m, lang) end
      return base_m(per, m, lang)
    end
  end
  for _, id in ipairs({"chips_per", "mult_per", "xmult_per", "money_per", "gain_mult_per", "gain_xmult_per"}) do
    local fn = R.CLEAN_GIVE[id]
    if type(fn) == "function" then
      R.CLEAN_GIVE[id] = function(e, ...)
        local m, per = type(e) == "table" and e.m, type(e) == "table" and e.per
        local r = fn(e, ...)
        if per == "jokers_rarity" and X.is_value(m) then e.per, e.m = per, m end
        return r
      end
    end
  end
  local base_need = R.need_v
  R.need_v = function(rules, vars)
    local need = base_need(rules, vars)
    for _, r in ipairs(type(rules) == "table" and rules or {}) do
      for _, k in ipairs({"give", "alt", "only"}) do
        for _, g in ipairs(type(r) == "table" and type(r[k]) == "table" and r[k] or {}) do
          if type(g) == "table" and (g.per == "jokers_rarity" or g.id == "jokers_of") then need = math.max(need, 16) end
        end
      end
    end
    return need
  end
end

function X.install()
  if X.hooked then return end
  local okh, Hooks = pcall(require, "overhaul.hooks")
  if not (okh and Hooks) then return end
  X.hooked = true
  Hooks.wrap("Card", "set_cost", function(orig) return function(self, ...)
    local r = orig(self, ...)
    local ra = X.rarity_of(self)
    if ra then
      local f = X.fields(ra.c)
      local cost = self.cost
      if f.price_lo > 0 and cost < f.price_lo then cost = f.price_lo end
      if f.price_hi > 0 and cost > f.price_hi then cost = f.price_hi end
      if cost ~= self.cost then
        self.cost = cost
        self.sell_cost = math.max(1, math.floor(cost / 2)) + (self.ability and self.ability.extra_value or 0)
      end
      if f.sell > 0 then self.sell_cost = self.sell_cost + f.sell end
      self.sell_cost_label = self.facing == "back" and "?" or self.sell_cost
    end
    return r
  end end, {id = "forge_rarityrules.set_cost"})
end

local function register_strings()
  if not mod_loc_register then return end
  mod_loc_register{
    fr = {
      ["Lowest price"] = "Prix minimum", ["Highest price"] = "Prix maximum", ["In the shop"] = "Dans la boutique", ["In Buffoon packs"] = "Dans les paquets Bouffon",
      ["Its Jokers cost {C:money}$%d{} to {C:money}$%d{}"] = "Ses jokers coûtent de {C:money}%d ${} à {C:money}%d ${}", ["Its Jokers cost at least {C:money}$%d{}"] = "Ses jokers coûtent au moins {C:money}%d ${}",
      ["Its Jokers cost at most {C:money}$%d{}"] = "Ses jokers coûtent au plus {C:money}%d ${}", ["Its Jokers sell for {C:money}$%d{} more"] = "Ses jokers se revendent {C:money}%d ${} de plus",
      ["Never in the shop"] = "Jamais dans la boutique", ["Never in Buffoon packs"] = "Jamais dans les paquets Bouffon",
      ["Jokers of a rarity"] = "Jokers d'une rareté", ["Joker of a rarity you have"] = "Joker d'une rareté que vous avez", ["WHICH RARITY?"] = "QUELLE RARETÉ ?",
    },
    es = {
      ["Lowest price"] = "Precio mínimo", ["Highest price"] = "Precio máximo", ["In the shop"] = "En la tienda", ["In Buffoon packs"] = "En sobres de bufón",
      ["Its Jokers cost {C:money}$%d{} to {C:money}$%d{}"] = "Sus comodines cuestan de {C:money}$%d{} a {C:money}$%d{}", ["Its Jokers cost at least {C:money}$%d{}"] = "Sus comodines cuestan al menos {C:money}$%d{}",
      ["Its Jokers cost at most {C:money}$%d{}"] = "Sus comodines cuestan como mucho {C:money}$%d{}", ["Its Jokers sell for {C:money}$%d{} more"] = "Sus comodines se venden por {C:money}$%d{} más",
      ["Never in the shop"] = "Nunca en la tienda", ["Never in Buffoon packs"] = "Nunca en sobres de bufón",
      ["Jokers of a rarity"] = "Comodines de una rareza", ["Joker of a rarity you have"] = "Comodín de una rareza que tienes", ["WHICH RARITY?"] = "¿QUÉ RAREZA?",
    },
  }
end

register_strings()

return X
