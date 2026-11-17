local A = {}

A.V = 13
A.KINDS = {tarot = true, planet = true, spectral = true, enhancement = true}
A.BASE = {"foil", "holo", "polychrome", "negative"}
A.PLAYING = {"foil", "holo", "polychrome"}
A.LABEL = "Always comes with"
A.LINE = "Always {C:dark_edition}%s{}"
A.TITLE = "Shop and edition"

local LOC = {
  fr = {["Always comes with"] = "Vient toujours avec", ["No edition"] = "Sans édition", ["Always {C:dark_edition}%s{}"] = "Toujours {C:dark_edition}%s{}",
    ["Shop and edition"] = "Boutique et édition"},
  es = {["Always comes with"] = "Siempre viene con", ["No edition"] = "Sin edición", ["Always {C:dark_edition}%s{}"] = "Siempre {C:dark_edition}%s{}", ["Shop and edition"] = "Tienda y edición"},
}

local function rules() return package.loaded["functions/forge/forge_rules"] or require("functions/forge/forge_rules") end
local function ml(s)
  local f = rawget(_G, "mod_loc")
  return f and f(s) or s
end
local function member(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

function A.field(kind)
  local options = kind == "enhancement" and A.PLAYING or A.BASE
  return {id = "always_ed", label = A.LABEL, type = "choice", options = options, def = "none", none = true, own = "edition", new = true, top = kind == "joker" or nil}
end

function A.syntax_ok(v)
  if type(v) ~= "string" or v == "none" then return false end
  return member(A.BASE, v) or rules().own_id("edition", v) ~= nil
end

function A.raw(c)
  if type(c) ~= "table" then return nil end
  if c.kind == nil or c.kind == "joker" then return c.always_ed end
  if not A.KINDS[c.kind] then return nil end
  return type(c.fields) == "table" and c.fields.always_ed or nil
end

function A.value(c)
  if type(c) ~= "table" then return nil end
  local joker = c.kind == nil or c.kind == "joker"
  if not joker and c.mode ~= "advanced" then return nil end
  local v = A.raw(c)
  if not A.syntax_ok(v) then return nil end
  if c.kind == "enhancement" and member(A.BASE, v) and not member(A.PLAYING, v) then return nil end
  return v
end

function A.line(c)
  local v = A.value(c)
  if not v then return nil end
  return string.format(ml(A.LINE), rules().ed_name(v))
end

function A.with_line(c, lines, lang)
  if type(c) == "table" and type(c.text) == "table" and type(c.text[lang]) == "table" and #c.text[lang] > 0 then return lines end
  local l = A.line(c)
  if not l then return lines end
  local out = {}
  for _, x in ipairs(lines or {}) do out[#out + 1] = x end
  out[#out + 1] = l
  return out
end

function A.cat(Cat)
  for kind in pairs(A.KINDS) do
    local k = Cat.kind(kind)
    if k and k.id == kind then
      k.adv_fields = k.adv_fields or {}
      local have = false
      for _, f in ipairs(k.adv_fields) do if f.id == "always_ed" then have = true end end
      if not have then k.adv_fields[#k.adv_fields + 1] = A.field(kind) end
    end
  end
  A.JOKER_FIELD = A.field("joker")

  local base_what = Cat.field_what
  Cat.field_what = function(f)
    if type(f) == "table" and f.id == "always_ed" then return "always_edition" end
    return base_what(f)
  end
  local base_label = Cat.value_label
  Cat.value_label = function(what, v)
    if what == "always_edition" then
      if v == nil or v == "none" then return ml("No edition") end
      return base_label("pack_edition", v)
    end
    return base_label(what, v)
  end

  local base_clean = Cat.clean_fields
  Cat.clean_fields = function(kind_id, t)
    local out = base_clean(kind_id, t)
    local k = Cat.kind(kind_id)
    if type(t) ~= "table" or not k or k.id ~= kind_id then return out end
    for _, f in ipairs(k.adv_fields or {}) do
      local v = t[f.id]
      if f.own == "edition" and out[f.id] ~= v and rules().own_id("edition", v) then out[f.id] = v end
    end
    return out
  end

  local base_need = Cat.need_v
  Cat.need_v = function(c)
    local need = base_need(c)
    if type(c) == "table" and A.KINDS[c.kind] and A.syntax_ok(A.raw(c)) then need = math.max(need, A.V) end
    return need
  end

  local reg = rawget(_G, "mod_loc_register")
  if reg then reg(LOC) end
end

function A.label() return ml(A.LABEL) end
function A.title() return ml(A.TITLE) end

function A.per_row()
  local ui = rawget(_G, "UIK")
  return ui and ui.portrait and ui.portrait() and 1 or 2
end

function A.joker_need(x)
  return type(x) == "table" and A.syntax_ok(x.always_ed) and A.V or 1
end

function A.apply(card)
  if not (card and card.config and card.config.center and card.set_edition) or card.added_to_deck then return end
  local v = card.config.center.forge_start_ed
  if not v then return end
  local R = rules()
  local arg = R.edition_arg(v)
  if not arg or R.has_edition(card, v) then return end
  local ok = pcall(card.set_edition, card, arg, true, true)
  if ok and card.set_cost then pcall(card.set_cost, card) end
end

function A.install()
  local CardC, Area = rawget(_G, "Card"), rawget(_G, "CardArea")
  if A.hooked or not CardC then return end
  A.hooked = true
  local orig_init = CardC.init
  CardC.init = function(self, ...)
    local r = {orig_init(self, ...)}
    local cen = self.config and self.config.center
    if cen and cen.forge_start_ed then
      self.forge_always_new = true
      A.apply(self)
    end
    return unpack(r, 1, table.maxn(r))
  end
  if type(create_card) == "function" then
    local orig = create_card
    create_card = function(...)
      local card = orig(...)
      if type(card) == "table" and card.forge_always_new then A.apply(card) end
      return card
    end
  end
  if Area and Area.emplace then
    local orig = Area.emplace
    Area.emplace = function(self, card, ...)
      local r = {orig(self, card, ...)}
      local g = rawget(_G, "G")
      if type(card) == "table" and card.forge_always_new and g and (self == g.pack_cards or self == g.shop_jokers) then A.apply(card) end
      return unpack(r, 1, table.maxn(r))
    end
  end
end

return A
