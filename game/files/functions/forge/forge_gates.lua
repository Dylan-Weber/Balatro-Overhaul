local Gates = {}

Gates.KINDS = {gone = true, own = true, played = true}
Gates.ORDER = {"gone", "own", "played"}
Gates.ASK = {gone = "After a Joker is destroyed", own = "While you own a Joker", played = "After a poker hand is played"}

function Gates.parse(v)
  if type(v) ~= "string" then return nil end
  local kind, what = v:match("^(%a+):(.+)$")
  if kind and Gates.KINDS[kind] then return kind, what end
  return nil
end

function Gates.ok(v)
  local kind, what = Gates.parse(v)
  return kind ~= nil and #v <= 60 and what:match("^[%w_ %-']+$") ~= nil
end

function Gates.make(kind, what)
  if not (Gates.KINDS[kind] and type(what) == "string" and what ~= "") then return nil end
  return kind .. ":" .. what
end

local function key_of(card) return card and card.config and card.config.center and card.config.center.key end

function Gates.met(v, g, jokers)
  local kind, what = Gates.parse(v)
  if not kind then return true end
  g = g or {}
  if kind == "gone" then
    if what == "j_gros_michel" and g.pool_flags and g.pool_flags.gros_michel_extinct then return true end
    return (g.forge_gone or {})[what] and true or false
  end
  if kind == "own" then
    for _, card in ipairs(jokers or {}) do
      if key_of(card) == what and not card.getting_sliced then return true end
    end
    return false
  end
  if kind == "played" then
    local h = g.hands and g.hands[what]
    return (h and (tonumber(h.played) or 0) > 0) and true or false
  end
  return true
end

function Gates.now(v)
  local g = G and G.GAME
  return Gates.met(v, g, G and G.jokers and G.jokers.cards)
end

function Gates.record_gone(card, g)
  g = g or (G and G.GAME)
  local key = key_of(card)
  if not (g and key) or card.forge_selling then return false end
  if not (card.ability and card.ability.set == "Joker") then return false end
  g.forge_gone = g.forge_gone or {}
  g.forge_gone[key] = true
  return true
end

local function label_of(kind, what)
  if kind == "played" then
    local Cat = require("functions/forge/forge_catalog")
    return Cat.value_label("hand", what)
  end
  local R = require("functions/forge/forge_rules")
  return R.card_label(what)
end

function Gates.text(v)
  local kind, what = Gates.parse(v)
  if not kind then return nil end
  local name = label_of(kind, what)
  if kind == "gone" then return string.format(mod_loc("%s destroyed"), name) end
  if kind == "own" then return string.format(mod_loc("Own %s"), name) end
  return string.format(mod_loc("%s played"), name)
end

function Gates.doc(v)
  local kind, what = Gates.parse(v)
  if not kind then return nil end
  local name = label_of(kind, what)
  if kind == "gone" then return string.format(mod_loc("Shows up after {C:attention}%s{} is destroyed"), name) end
  if kind == "own" then return string.format(mod_loc("Shows up while you own {C:attention}%s{}"), name) end
  return string.format(mod_loc("Shows up after {C:attention}%s{} is played"), name)
end

function Gates.install_hooks()
  if Gates.hooked then return end
  Gates.hooked = true
  if Card and Card.sell_card then
    local orig = Card.sell_card
    Card.sell_card = function(self, ...)
      self.forge_selling = true
      return orig(self, ...)
    end
  end
  if CardArea and CardArea.remove_card then
    local orig = CardArea.remove_card
    CardArea.remove_card = function(self, card, ...)
      if card and G and self == G.jokers and G.STAGE == G.STAGES.RUN and not G.forge_tearing_down then
        pcall(Gates.record_gone, card)
      end
      return orig(self, card, ...)
    end
  end
  if G and G.delete_run then
    local orig = G.delete_run
    G.delete_run = function(...)
      G.forge_tearing_down = true
      local ok, r = pcall(orig, ...)
      G.forge_tearing_down = nil
      if not ok then error(r, 0) end
      return r
    end
  end
end

local function register_strings()
  if not mod_loc_register then return end
  mod_loc_register{
    fr = {
      ["After a Joker is destroyed"] = "Après la destruction d'un Joker", ["While you own a Joker"] = "Tant que vous avez un Joker", ["After a poker hand is played"] = "Après avoir joué une main",
      ["%s destroyed"] = "Joker détruit : %s", ["Own %s"] = "Joker possédé : %s", ["%s played"] = "Main jouée : %s",
      ["Shows up after {C:attention}%s{} is destroyed"] = "Apparaît après la destruction de {C:attention}%s{}", ["Shows up while you own {C:attention}%s{}"] = "Apparaît tant que vous avez {C:attention}%s{}",
      ["Shows up after {C:attention}%s{} is played"] = "Apparaît après avoir joué {C:attention}%s{}",
    },
    es = {
      ["After a Joker is destroyed"] = "Tras destruir un comodín", ["While you own a Joker"] = "Mientras tengas un comodín", ["After a poker hand is played"] = "Tras jugar una mano",
      ["%s destroyed"] = "Comodín destruido: %s", ["Own %s"] = "Si tienes %s", ["%s played"] = "Mano jugada: %s",
      ["Shows up after {C:attention}%s{} is destroyed"] = "Sale tras destruir {C:attention}%s{}", ["Shows up while you own {C:attention}%s{}"] = "Sale mientras tengas {C:attention}%s{}",
      ["Shows up after {C:attention}%s{} is played"] = "Sale tras jugar {C:attention}%s{}",
    },
  }
end

register_strings()

return Gates
