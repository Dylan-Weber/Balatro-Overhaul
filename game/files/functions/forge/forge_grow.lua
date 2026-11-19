local Grow = {}

Grow.V = 16
Grow.MAX_LOOKS = 6
Grow.RARITIES = {"Common", "Uncommon", "Rare", "Legendary"}
Grow.ROLL = {Common = 0, Uncommon = 0.8, Rare = 0.99}
Grow.COL = {Common = "blue", Uncommon = "green", Rare = "red", Legendary = "legendary"}
Grow.STICKERS = {"eternal", "perishable", "perish_tally", "rental"}
Grow.IDS = {become = true, next_look = true}
Grow.SKIP_WHEN = {card_scored = true, card_held = true, passive = true, other_joker = true, would_lose = true, self_sold = true, hand_debuffed = true}
Grow.DRAFT_PREFIX = "forge/art/draft_g"

local RARITY_NAME = {
  en = {Common = "Common", Uncommon = "Uncommon", Rare = "Rare", Legendary = "Legendary"},
  fr = {Common = "Commun", Uncommon = "Peu commun", Rare = "Rare", Legendary = "Légendaire"},
  es = {Common = "Común", Uncommon = "Poco común", Rare = "Raro", Legendary = "Legendario"},
}
local TEXT = {
  en = {pick = "this Joker becomes {C:attention}%s{}", random = "this Joker becomes a random {C:%s}%s{} Joker", next_look = "this Joker gets its next look"},
  fr = {pick = "ce Joker devient {C:attention}%s{}", random = "ce Joker devient un Joker {C:%s}%s{} au hasard", next_look = "ce Joker passe à son look suivant"},
  es = {pick = "este Joker se convierte en {C:attention}%s{}", random = "este Joker se convierte en un Joker {C:%s}%s{} al azar", next_look = "este Joker pasa a su siguiente aspecto"},
}
local RANDOM = {en = "Random %s Joker", fr = "Joker %s au hasard", es = "Joker %s al azar"}

Grow.LOC = {
  fr = {["Becomes another Joker"] = "Devient un autre Joker", ["Next look"] = "Look suivant", ["Grew up!"] = "A grandi !", ["New look!"] = "Nouveau look !",
    ["WHAT DOES IT BECOME?"] = "EN QUOI SE TRANSFORME-T-IL ?", ["WHICH JOKER?"] = "QUEL JOKER ?", ["A chosen Joker"] = "Un Joker choisi",
    ["Looks"] = "Looks", ["ITS LOOKS"] = "SES LOOKS", ["WHEN DOES IT CHANGE?"] = "QUAND CHANGE-T-IL ?", ["+ Add a look"] = "+ Ajouter un look", ["Remove this look"] = "Retirer ce look",
    ["Game art and Draw it change the look you picked."] = "Image et Dessiner changent le look choisi.",
    ["Look follows"] = "Le look suit", ["The Next look effect"] = "L'effet Look suivant", ["Variable: %s"] = "Variable : %s",
    ["A rule with the Next look effect moves it to its next look."] = "Une règle avec l'effet Look suivant le fait passer au look suivant.",
    ["The look follows the variable: 0 is the first look, 1 the second..."] = "Le look suit la variable : 0 est le premier look, 1 le deuxième...",
    ["Next look needs a second look: add one in Looks"] = "Look suivant demande un deuxième look : ajoutez-en un dans Looks"},
  es = {["Becomes another Joker"] = "Se convierte en otro Joker", ["Next look"] = "Siguiente aspecto", ["Grew up!"] = "¡Creció!", ["New look!"] = "¡Nuevo aspecto!",
    ["WHAT DOES IT BECOME?"] = "¿EN QUÉ SE CONVIERTE?", ["WHICH JOKER?"] = "¿QUÉ JOKER?", ["A chosen Joker"] = "Un Joker elegido",
    ["Looks"] = "Aspectos", ["ITS LOOKS"] = "SUS ASPECTOS", ["WHEN DOES IT CHANGE?"] = "¿CUÁNDO CAMBIA?", ["+ Add a look"] = "+ Añadir aspecto", ["Remove this look"] = "Quitar este aspecto",
    ["Game art and Draw it change the look you picked."] = "Imagen y Dibujar cambian el aspecto elegido.",
    ["Look follows"] = "El aspecto sigue", ["The Next look effect"] = "El efecto Siguiente aspecto", ["Variable: %s"] = "Variable: %s",
    ["A rule with the Next look effect moves it to its next look."] = "Una regla con el efecto Siguiente aspecto lo pasa a su siguiente aspecto.",
    ["The look follows the variable: 0 is the first look, 1 the second..."] = "El aspecto sigue la variable: 0 es el primer aspecto, 1 el segundo...",
    ["Next look needs a second look: add one in Looks"] = "Siguiente aspecto necesita un segundo aspecto: añade uno en Aspectos"},
}

local function ml(s)
  local f = rawget(_G, "mod_loc")
  return f and f(s) or s
end
local function sound(...)
  local f = rawget(_G, "play_sound")
  if f then f(...) end
end
local function reopen()
  local JF = rawget(_G, "JokerForge")
  if JF and JF.ui then JF.ui.reopen("builder") end
end
local function member(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end
local function rules() return package.loaded["functions/forge/forge_rules"] end
local function store() return package.loaded["functions/forge/forge_store"] end
local function key_ok(v) return type(v) == "string" and #v > 0 and #v <= 40 and v:match("^[%w_]+$") ~= nil end
local function file_ok(v) return type(v) == "string" and v:match("^forge/art/[%w_]+%.png$") ~= nil end
local function fs() return rawget(_G, "love") and love.filesystem or nil end
local function plain(v)
  if type(v) == "number" then return v end
  local conv = rawget(_G, "to_number")
  if type(v) == "table" and type(conv) == "function" then
    local ok, n = pcall(conv, v)
    if ok and type(n) == "number" then return n end
  end
  return tonumber(v)
end

function Grow.lang()
  local Cat = package.loaded["functions/forge/forge_catalog"]
  return Cat and Cat.lang and Cat.lang() or "en"
end

function Grow.own_rarity(v)
  local R = rules()
  return R and R.own_id and R.own_id("rarity", v) ~= nil or false
end

function Grow.is_rarity(v) return member(Grow.RARITIES, v) or Grow.own_rarity(v) end

function Grow.pick_own(rarity, self_key)
  local ok, Ra = pcall(require, "functions/forge/forge_rarities")
  if not ok then return nil end
  local list = {}
  for _, cen in ipairs(Ra.live_jokers(rarity) or {}) do
    if cen.key and cen.key ~= self_key then list[#list + 1] = cen.key end
  end
  if #list == 0 then return nil end
  table.sort(list)
  local rnd, seed = rawget(_G, "pseudorandom"), rawget(_G, "pseudoseed")
  return list[math.floor(rnd(seed("forge_grow_own")) * #list) + 1] or list[1]
end

function Grow.target_ok(v)
  return Grow.is_rarity(v) or (type(v) == "string" and #v <= 40 and v:match("^j_[%w_]+$") ~= nil)
end

function Grow.rarity_name(v, lang)
  if Grow.own_rarity(v) then return rules().own_label("rarity", v) end
  return (RARITY_NAME[lang] or RARITY_NAME.en)[v] or v
end

function Grow.random_label(v, lang)
  lang = lang or Grow.lang()
  return string.format(RANDOM[lang] or RANDOM.en, Grow.rarity_name(v, lang))
end

function Grow.text(g, lang)
  local t = TEXT[lang] or TEXT.en
  if g.id == "next_look" then return t.next_look end
  if Grow.is_rarity(g.v) then return string.format(t.random, Grow.COL[g.v] or "attention", Grow.rarity_name(g.v, lang)) end
  local R = rules()
  return string.format(t.pick, R and R.card_label and R.card_label(g.v) or tostring(g.v))
end

function Grow.clean_art(a)
  if type(a) ~= "table" then return nil end
  if file_ok(a.file) then return {file = a.file} end
  if key_ok(a.atlas) then
    local function n(x) x = math.floor(tonumber(x) or 0) return math.max(0, math.min(99, x)) end
    return {atlas = a.atlas, x = n(a.x), y = n(a.y)}
  end
  return nil
end

function Grow.clean_looks(list)
  if type(list) ~= "table" then return nil end
  local out = {}
  for _, a in ipairs(list) do
    local c = Grow.clean_art(a)
    if c and #out < Grow.MAX_LOOKS - 1 then out[#out + 1] = c end
  end
  return #out > 0 and out or nil
end

function Grow.clean_var(v)
  if type(v) == "string" and v:match("^v[1-4]$") then return v end
  return nil
end

function Grow.uses(c)
  if type(c) ~= "table" then return false end
  if type(c.looks) == "table" and #c.looks > 0 then return true end
  for _, r in ipairs(type(c.rules) == "table" and c.rules or {}) do
    for _, l in ipairs({r.give, r.alt}) do
      for _, g in ipairs(type(l) == "table" and l or {}) do
        if type(g) == "table" and Grow.IDS[g.id] then return true end
      end
    end
  end
  return false
end

function Grow.usable(key)
  local R = rules()
  local c = G and G.P_CENTERS and G.P_CENTERS[key]
  return c ~= nil and c.set == "Joker" and R.card_usable(key)
end

function Grow.pick_random(rarity, self_key)
  local gp = rawget(_G, "get_current_pool")
  if type(gp) ~= "function" then return nil end
  local legendary = rarity == "Legendary"
  local ok, pool, pool_key = pcall(gp, "Joker", not legendary and (Grow.ROLL[rarity] or 0) or nil, legendary or nil, "forge_grow")
  if not ok then return nil end
  local list = {}
  for _, k in ipairs(type(pool) == "table" and pool or {}) do
    if k ~= "UNAVAILABLE" and k ~= self_key and G.P_CENTERS[k] then list[#list + 1] = k end
  end
  if #list == 0 then return nil end
  local rnd, seed = rawget(_G, "pseudorandom"), rawget(_G, "pseudoseed")
  return list[math.floor(rnd(seed(pool_key or "forge_grow")) * #list) + 1] or list[1]
end

function Grow.sticker_keys()
  local out = {}
  for _, k in ipairs(Grow.STICKERS) do out[#out + 1] = k end
  local S = rawget(_G, "SMODS")
  if type(S) == "table" and type(S.Stickers) == "table" then
    for k in pairs(S.Stickers) do if not member(out, k) then out[#out + 1] = k end end
  end
  return out
end

function Grow.become(card, key)
  card.forge_becoming = nil
  local center = G.P_CENTERS[key]
  if not (center and card.ability and not card.REMOVED) then return false end
  local a = card.ability
  local keep = {}
  for _, k in ipairs(Grow.sticker_keys()) do keep[k] = a[k] end
  local added = card.added_to_deck
  if added then card:remove_from_deck() end
  local fl = card.children and card.children.floating_sprite
  if fl then
    fl:remove()
    card.children.floating_sprite = nil
  end
  local sp = card.children and card.children.center
  if sp and sp.atlas and sp.scale then
    sp.scale.x, sp.scale.y = sp.atlas.px, sp.atlas.py
    sp.forge_stage = nil
  end
  card.T.w, card.T.h = G.CARD_W, G.CARD_H
  local disc = rawget(_G, "discover_card")
  if not center.discovered and disc then pcall(disc, center) end
  card:set_ability(center, nil, nil)
  for k, v in pairs(keep) do card.ability[k] = v end
  if added then card:add_to_deck() end
  if card.set_cost then card:set_cost() end
  if card.juice_up then card:juice_up(0.8, 0.5) end
  sound("polychrome1", 1.2, 0.5)
  return true
end

function Grow.stage_count(cen)
  return 1 + (cen and type(cen.forge_stages) == "table" and #cen.forge_stages or 0)
end

function Grow.stage_of(card, cen)
  cen = cen or (card and card.config and card.config.center)
  local n = Grow.stage_count(cen)
  if n <= 1 then return 1 end
  local x = card and card.ability and card.ability.extra
  if type(x) ~= "table" then return 1 end
  local i
  if cen.forge_look_var then
    local vars = type(x.vars) == "table" and x.vars or {}
    i = math.floor(plain(vars[cen.forge_look_var]) or 0) + 1
  else
    i = math.floor(plain(x.look) or 1)
  end
  if i ~= i then i = 1 end
  return math.max(1, math.min(n, i))
end

function Grow.show(card)
  local cen = card.config and card.config.center
  local st = cen and cen.forge_stages
  local sp = card.children and card.children.center
  if not (st and sp and sp.set_sprite_pos) then return end
  local i = Grow.stage_of(card, cen)
  local want = i > 1 and st[i - 1] or nil
  local atlas = want and G.ASSET_ATLAS[want.atlas]
  if not atlas then
    if sp.forge_stage then
      sp.forge_stage = nil
      sp.atlas = G.ASSET_ATLAS[cen.atlas or "Joker"] or sp.atlas
      sp:set_sprite_pos(cen.pos or {x = 0, y = 0})
    end
    return
  end
  local pos = sp.sprite_pos or {}
  if sp.forge_stage ~= i or sp.atlas ~= atlas or pos.x ~= want.pos.x or pos.y ~= want.pos.y then
    sp.forge_stage = i
    sp.atlas = atlas
    sp:set_sprite_pos(want.pos)
  end
end

function Grow.rules(R)
  for id in pairs(Grow.IDS) do
    if not R.member(R.GIVE, id) then R.GIVE[#R.GIVE + 1] = id end
    R.HOST_GIVE[id] = {joker = true}
    local w = {}
    for _, x in ipairs(R.WHEN) do if not Grow.SKIP_WHEN[x] then w[x] = true end end
    R.GIVE_WHEN[id] = w
    R.SIMPLE_GIVE[id] = true
  end
  local base_allowed = R.allowed_give
  function R.allowed_give(when, give, host)
    if Grow.IDS[give] then
      if (host or "joker") ~= "joker" or Grow.SKIP_WHEN[when] then return false end
      return R.member(R.WHEN, when)
    end
    return base_allowed(when, give, host)
  end
  R.DEFAULT_GIVE.become = function() return {id = "become", v = "Rare"} end
  R.DEFAULT_GIVE.next_look = function() return {id = "next_look"} end
  R.CLEAN_GIVE.become = function(e)
    if not Grow.target_ok(e.v) then e.v = "Rare" end
    e.n = nil
  end
  R.CLEAN_GIVE.next_look = function(e) e.v, e.n = nil, nil end
  R.TEXT_GIVE.become = function(g, s, lang) return Grow.text(g, lang) end
  R.TEXT_GIVE.next_look = function(g, s, lang) return Grow.text(g, lang) end
  R.LABEL_GIVE.become = "Becomes another Joker"
  R.LABEL_GIVE.next_look = "Next look"

  R.DOS.become = function(g, card, src, context)
    if context.blueprint or not card or card.forge_becoming or card.getting_sliced then return end
    if not (G.jokers and card.area == G.jokers) then return end
    local cen = card.config and card.config.center
    local self_key = cen and cen.key
    local key = g.v
    if Grow.own_rarity(key) then key = Grow.pick_own(key, self_key)
    elseif member(Grow.RARITIES, key) then key = Grow.pick_random(key, self_key) end
    if not (key and key ~= self_key and Grow.usable(key)) then return end
    card.forge_becoming = key
    G.E_MANAGER:add_event(rawget(_G, "Event")({trigger = "after", delay = 0.3, func = function()
      local ok, err = pcall(Grow.become, card, key)
      if not ok then
        card.forge_becoming = nil
        print("[FORGE] becomes failed: " .. tostring(err))
      end
      return true
    end}))
    R.status(src, ml("Grew up!"), G.C.SECONDARY_SET and G.C.SECONDARY_SET.Spectral or G.C.FILTER)
  end
  R.DOS.next_look = function(g, card, src, context)
    if context.blueprint or not card then return end
    local cen = card.config and card.config.center
    local n = Grow.stage_count(cen)
    local x = R.state(card)
    local cur = math.floor(plain(x.look) or 1)
    if cur >= n then return end
    x.look = cur + 1
    R.status(src, ml("New look!"), G.C.FILTER)
  end

  R.VALUES_GIVE = R.VALUES_GIVE or {}
  R.VALUES_GIVE.become = function()
    local out = {}
    for _, v in ipairs(Grow.RARITIES) do out[#out + 1] = {label = Grow.random_label(v), value = v} end
    for _, v in ipairs(R.own_values("rarity")) do out[#out + 1] = {label = Grow.random_label(v), value = v} end
    return out
  end
  R.ASK_GIVE = R.ASK_GIVE or {}
  R.ASK_GIVE.become = function(g) return Grow.ask_become(g) end

  local base_need = R.need_v
  R.need_v = function(list, vars)
    local need = base_need(list, vars)
    if Grow.uses({rules = list}) then need = math.max(need, Grow.V) end
    return need
  end
  local reg = rawget(_G, "mod_loc_register")
  if reg then reg(Grow.LOC) end
end

function Grow.store(S)
  local base_clean = S.clean
  S.clean = function(c)
    local out = base_clean(c)
    if out and type(c) == "table" then
      out.looks = Grow.clean_looks(c.looks)
      out.look_var = out.looks and Grow.clean_var(c.look_var) or nil
    end
    return out
  end
  local base_dup = S.duplicate
  S.duplicate = function(id, ...)
    local d = base_dup(id, ...)
    if not (d and d.looks) then return d end
    local f = fs()
    local any = false
    for i, a in ipairs(d.looks) do
      if a.file and f and f.getInfo(a.file) then
        local to = S.art_path(d.id .. "_l" .. (i + 1))
        local raw = f.read(a.file)
        if raw and f.write(to, raw) then a.file = to; any = true end
      end
    end
    if any then S.save() end
    return d
  end
  local base_delete = S.delete
  S.delete = function(id)
    local c = S.get and S.get(id)
    local files = {}
    for _, a in ipairs(c and c.looks or {}) do if a.file then files[#files + 1] = a.file end end
    local ok = base_delete(id)
    local f = fs()
    if ok and f then
      for _, p in ipairs(files) do if f.getInfo(p) then pcall(f.remove, p) end end
    end
    return ok
  end
end

function Grow.files(c, out)
  for _, a in ipairs(type(c) == "table" and type(c.looks) == "table" and c.looks or {}) do
    if type(a) == "table" and a.file then out[#out + 1] = a.file end
  end
  return out
end

function Grow.strip(x, packed)
  if type(x.looks) ~= "table" then return end
  local out = {}
  for _, a in ipairs(x.looks) do
    if a.file and not packed[a.file] then out[#out + 1] = {atlas = "Joker", x = 0, y = 0} else out[#out + 1] = a end
  end
  x.looks = #out > 0 and out or nil
end

function Grow.remap(c, art)
  if type(c.looks) ~= "table" then return end
  local out = {}
  for _, a in ipairs(c.looks) do
    if type(a) == "table" and a.file then
      local p = art(a.file)
      out[#out + 1] = p and {file = p} or {atlas = "Joker", x = 0, y = 0}
    else
      out[#out + 1] = a
    end
  end
  c.looks = out
end

function Grow.room_files(c, out)
  for i, a in ipairs(type(c) == "table" and type(c.looks) == "table" and c.looks or {}) do
    if type(a) == "table" and a.file then out[#out + 1] = {"L" .. (i + 1), a.file} end
  end
  return out
end

function Grow.room_strip(x)
  if type(x.looks) ~= "table" then return end
  for i, a in ipairs(x.looks) do
    if type(a) == "table" and a.file then x.looks[i] = {atlas = "Joker", x = 0, y = 0} end
  end
end

function Grow.room_put(x, slot, p)
  local i = type(slot) == "string" and tonumber(slot:match("^L(%d)$"))
  if not (i and type(x.looks) == "table" and x.looks[i - 1]) then return false end
  x.looks[i - 1] = {file = p}
  return true
end

function Grow.mods(M)
  local base_needs = M.needs_v
  M.needs_v = function(jokers, creations)
    local v = base_needs(jokers, creations)
    for _, x in ipairs(jokers or {}) do if Grow.uses(x) then v = math.max(v, Grow.V) end end
    return v
  end
end

function Grow.atlas_for(name, a)
  if type(a) ~= "table" then return nil end
  if a.file then
    local f = fs()
    local FJ = package.loaded["functions/forge/forge_joker"]
    if not (f and FJ and f.getInfo(a.file)) then return nil end
    local ok, data = pcall(love.image.newImageData, a.file)
    if ok and data and data:getWidth() == 71 and data:getHeight() == 95 and FJ.atlas_from_data(name, data) then return name, {x = 0, y = 0} end
    return nil
  end
  if a.atlas and G.ASSET_ATLAS and G.ASSET_ATLAS[a.atlas] then return a.atlas, {x = a.x or 0, y = a.y or 0} end
  return nil
end

function Grow.joker(FJ)
  local base_center = FJ.center_for
  FJ.center_for = function(c, index)
    local center = base_center(c, index)
    center.forge_stages, center.forge_look_var = nil, nil
    if type(c.looks) == "table" and #c.looks > 0 then
      local st = {}
      for i, a in ipairs(c.looks) do
        local atlas, pos = Grow.atlas_for("forge_" .. c.id .. "_l" .. (i + 1), a)
        st[#st + 1] = {atlas = atlas or "Joker", pos = pos or {x = 0, y = 0}}
      end
      center.forge_stages = st
      local v = Grow.clean_var(c.look_var)
      center.forge_look_var = v and tonumber(v:sub(2)) or nil
    end
    return center
  end
  local base_install = FJ.install_hooks
  FJ.install_hooks = function(...)
    local r = base_install(...)
    pcall(Grow.install)
    return r
  end
end

function Grow.install()
  if Grow.hooked then return end
  local ok, Hooks = pcall(require, "overhaul.hooks")
  if not (ok and Hooks and rawget(_G, "Card")) then return end
  Grow.hooked = true
  Hooks.wrap("Card", "draw", function(orig) return function(self, ...)
    local cen = self.config and self.config.center
    if cen and cen.forge_stages then
      local okp, err = pcall(Grow.show, self)
      if not okp and not Grow.warned then
        Grow.warned = true
        print("[FORGE] looks failed: " .. tostring(err))
      end
    end
    return orig(self, ...)
  end end, {id = "forge.grow_draw"})
end

function Grow.ask_become(g)
  local B = rawget(_G, "ForgeBuilder")
  local UIK = rawget(_G, "UIK")
  if not B then return end
  local R = rules()
  local function done()
    B.state.pick = nil
    B.dirty = true
    reopen()
  end
  local opts = {}
  local num = {Common = 1, Uncommon = 2, Rare = 3, Legendary = 4}
  for _, v in ipairs(Grow.RARITIES) do
    opts[#opts + 1] = {label = Grow.random_label(v), value = v, colour = G.C.RARITY and G.C.RARITY[num[v]] or nil}
  end
  for _, v in ipairs(R.own_values("rarity")) do opts[#opts + 1] = {label = Grow.random_label(v), value = v} end
  opts[#opts + 1] = {label = ml("A chosen Joker"), value = "pick", colour = G.C.FILTER}
  B.pick{title = ml("WHAT DOES IT BECOME?"), options = opts, colour = G.C.RED, choose = function(v)
    if v ~= "pick" then
      g.v = v
      return done()
    end
    local d = B.state.draft
    local me = d and d.id and (R.OWN_PREFIX.joker .. d.id)
    local list = {}
    for _, k in ipairs(R.card_values("Joker")) do
      if k ~= me then list[#list + 1] = {label = R.card_label(k), value = k, colour = R.own_id("card", k) and G.C.GREEN or nil} end
    end
    B.pick{title = ml("WHICH JOKER?"), note = ml("Your own creations come first, in green."), options = list, choose = function(k)
      g.v = k
      done()
    end}
  end}
end

function Grow.all(d)
  if not d.look_all then
    d.look_all = {d.art or {atlas = "Joker", x = 0, y = 0}}
    for _, a in ipairs(d.looks or {}) do d.look_all[#d.look_all + 1] = a end
  end
  return d.look_all
end

function Grow.stash(B, d)
  local all = Grow.all(d)
  local i = B.state.look_i or 1
  local a = d.art
  local f = fs()
  if a and a.file == B.DRAFT_ART and f and f.getInfo(B.DRAFT_ART) then
    B.state.look_seq = (B.state.look_seq or 0) + 1
    local to = Grow.DRAFT_PREFIX .. B.state.look_seq .. ".png"
    local raw = f.read(B.DRAFT_ART)
    if raw and f.write(to, raw) then
      a = {file = to}
      pcall(f.remove, B.DRAFT_ART)
    end
  end
  all[i] = a or all[i]
  d.art = all[i]
  return all
end

function Grow.select(B, d, k)
  local all = Grow.stash(B, d)
  k = math.max(1, math.min(#all, k))
  B.state.look_i = k
  d.art = all[k]
end

function Grow.clear_drafts()
  local f = fs()
  if not (f and f.getInfo("forge/art")) then return end
  for _, name in ipairs(f.getDirectoryItems("forge/art")) do
    if name:match("^draft_g%d+%.png$") then pcall(f.remove, "forge/art/" .. name) end
  end
end

function Grow.finish(B, d)
  if not d.look_all then return end
  local all = Grow.stash(B, d)
  local first = all[1]
  local f = fs()
  if first and first.file and first.file:sub(1, #Grow.DRAFT_PREFIX) == Grow.DRAFT_PREFIX and f then
    local raw = f.read(first.file)
    if raw and f.write(B.DRAFT_ART, raw) then first = {file = B.DRAFT_ART} end
  end
  d.art = first
  local looks = {}
  for i = 2, #all do looks[#looks + 1] = all[i] end
  d.looks = #looks > 0 and looks or nil
  d.look_all = nil
  B.state.look_i = 1
end

function Grow.keep_looks(d, id)
  local S = store()
  local f = fs()
  if type(d.looks) ~= "table" or not (S and f) then return d.looks end
  local used = {}
  for _, a in ipairs(d.looks) do if a.file then used[a.file] = true end end
  local out = {}
  for _, a in ipairs(d.looks) do
    local x = a
    if a.file and (a.file:sub(1, #Grow.DRAFT_PREFIX) == Grow.DRAFT_PREFIX or a.file == "forge/art/draft.png") and f.getInfo(a.file) then
      local k = 2
      while used[S.art_path(id .. "_l" .. k)] do k = k + 1 end
      local to = S.art_path(id .. "_l" .. k)
      local raw = f.read(a.file)
      if raw and f.write(to, raw) then
        x = {file = to}
        used[to] = true
      end
    end
    out[#out + 1] = x
  end
  return out
end

function Grow.drop_unused(id, looks)
  local S = store()
  local f = fs()
  if not (S and f) then return end
  local keep = {}
  for _, a in ipairs(looks or {}) do if a.file then keep[a.file] = true end end
  for k = 2, Grow.MAX_LOOKS * 2 + 2 do
    local p = S.art_path(id .. "_l" .. k)
    if not keep[p] and f.getInfo(p) then pcall(f.remove, p) end
  end
end

function Grow.builder(B)
  local K = B.kit
  local D = require("functions/forge/forge_doc")
  local Store = store()
  B.SEC_LABEL.looks = "Looks"

  local base_new = D.new
  D.new = function(kind, o)
    local d = base_new(kind, o)
    if d.kind == "joker" and type(o) == "table" then
      d.looks = type(o.looks) == "table" and #o.looks > 0 and o.looks or nil
      d.look_var = Grow.clean_var(o.look_var)
    end
    return d
  end

  local base_problems = D.problems
  D.problems = function(d)
    local out = base_problems(d)
    if d and d.kind == "joker" then
      local n = d.look_all and #d.look_all or (1 + #(d.looks or {}))
      if n <= 1 and Grow.uses({rules = d.rules}) then
        for _, r in ipairs(d.rules or {}) do
          local hit = false
          for _, l in ipairs({r.give or {}, r.alt or {}}) do for _, g in ipairs(l) do if g.id == "next_look" then hit = true end end end
          if hit then out[#out + 1] = ml("Next look needs a second look: add one in Looks") break end
        end
      end
    end
    return out
  end

  local base_draft = B.new_draft
  B.new_draft = function(o)
    Grow.clear_drafts()
    B.state.look_i, B.state.look_seq = 1, 0
    return base_draft(o)
  end

  local base_save = B.save
  B.save = function(...)
    local d = B.state.draft
    if d and d.kind == "joker" then Grow.finish(B, d) end
    local c = base_save(...)
    if c and d and d.kind == "joker" then
      local looks = Grow.keep_looks(d, c.id)
      local full = Store.copy(c)
      full.looks = looks
      full.look_var = looks and d.look_var or nil
      local c2 = Store.put(full)
      if c2 then
        c = c2
        Grow.drop_unused(c.id, c.looks)
        Grow.clear_drafts()
        local FJ = package.loaded["functions/forge/forge_joker"]
        if FJ then FJ.register_all() end
      end
      d.looks = c.looks
      d.look_var = c.look_var
    end
    return c
  end

  function B.looks_body(w)
    local UIK = rawget(_G, "UIK")
    local d = B.state.draft
    local touch = UIK.touch()
    local all = Grow.stash(B, d)
    local cur = math.max(1, math.min(#all, B.state.look_i or 1))
    B.state.look_i = cur
    d.art = all[cur]
    local nodes = {K.step_title(1, ml("ITS LOOKS"), w)}
    local s = UIK.portrait() and 0.36 or touch and 0.42 or 0.38
    local tiles = {}
    for i, a in ipairs(all) do
      local atlas, pos = Grow.atlas_for("forge_draft_l" .. i, a)
      local spr = K.still(rawget(_G, "Sprite")(0, 0, G.CARD_W * s, G.CARD_H * s, G.ASSET_ATLAS[atlas or "Joker"], pos or {x = 0, y = 0}))
      local cfg = {align = "cm", padding = 0.06, r = 0.1, colour = i == cur and G.C.RED or UIK.C.section, button = "forge_g_look", ref_table = {i = i}, hover = true, shadow = true}
      cfg.id = "forge_look_" .. i
      tiles[#tiles + 1] = {n = G.UIT.C, config = cfg, nodes = {
        {n = G.UIT.R, config = {align = "cm"}, nodes = {K.obj(spr)}},
        {n = G.UIT.R, config = {align = "cm", padding = 0.02}, nodes = {UIK.text(tostring(i), {scale = touch and 0.4 or 0.34})}},
      }}
    end
    nodes[#nodes + 1] = K.hrow(tiles, w, 0.1)
    local bw = math.min((w - 0.3) / 2, touch and 3.4 or 3)
    local h = touch and 0.7 or 0.56
    local lab1, s1 = B.wrap_label(ml("+ Add a look"), bw, touch and 0.42 or 0.38)
    local lab2, s2 = B.wrap_label(ml("Remove this look"), bw, touch and 0.42 or 0.38)
    nodes[#nodes + 1] = K.hrow({
      UIK.button{label = lab1, button = "forge_g_look_add", colour = UIK.C.ok, w = bw, h = h, scale = s1, col = true, id = "forge_look_add", disabled = #all >= Grow.MAX_LOOKS},
      UIK.button{label = lab2, button = "forge_g_look_del", colour = G.C.RED, w = bw, h = h, scale = s2, col = true, id = "forge_look_del", disabled = #all <= 1},
    }, w, 0.2)
    nodes[#nodes + 1] = UIK.note({ml("Game art and Draw it change the look you picked.")}, {w = w - 0.2, scale = touch and 0.38 or 0.32})
    nodes[#nodes + 1] = K.step_title(2, ml("WHEN DOES IT CHANGE?"), w)
    local opts = {}
    for _, i in ipairs(B.num_vars()) do opts[#opts + 1] = "v" .. i end
    if d.look_var and not member(opts, d.look_var) then d.look_var = nil end
    local f = {id = "look_var", top = true, none = true, options = opts}
    local label = ml("The Next look effect")
    if d.look_var then
      local v = (d.vars or {})[tonumber(d.look_var:sub(2))]
      label = string.format(ml("Variable: %s"), v and v.name or "?")
    end
    local fw = math.min(w, touch and 6.4 or 5.6)
    local _, ch, cw = B.cell_dims(fw)
    cw = math.min(fw - 0.1, math.max(cw, UIK.text_w(label, (touch and 0.4 or 0.36) * 1.15) + 2 * (touch and 0.6 or 0.5) + 0.5))
    nodes[#nodes + 1] = K.hrow({B.cell(ml("Look follows"), B.flat_cycle(f, label, cw, ch), fw)}, w, 0.2)
    local why = d.look_var and "The look follows the variable: 0 is the first look, 1 the second..." or "A rule with the Next look effect moves it to its next look."
    nodes[#nodes + 1] = UIK.note({ml(why)}, {w = w - 0.2, scale = touch and 0.38 or 0.32})
    return nodes
  end

  local refresh = reopen
  G.FUNCS.forge_g_look = function(e)
    local d = B.state.draft
    local i = e and e.config and e.config.ref_table and e.config.ref_table.i
    if not (d and i) then return end
    Grow.select(B, d, i)
    sound("card1", 1.1, 0.4)
    refresh()
  end
  G.FUNCS.forge_g_look_add = function()
    local d = B.state.draft
    if not d then return end
    local all = Grow.stash(B, d)
    if #all >= Grow.MAX_LOOKS then return end
    local a = all[B.state.look_i or 1] or {}
    local copy = {atlas = a.atlas, x = a.x, y = a.y}
    local f = fs()
    if a.file and f and f.getInfo(a.file) then
      B.state.look_seq = (B.state.look_seq or 0) + 1
      local to = Grow.DRAFT_PREFIX .. B.state.look_seq .. ".png"
      local raw = f.read(a.file)
      if raw and f.write(to, raw) then copy = {file = to} end
    end
    if not (copy.file or copy.atlas) then copy = {atlas = "Joker", x = 0, y = 0} end
    all[#all + 1] = copy
    Grow.select(B, d, #all)
    B.dirty = true
    sound("card1", 1.1, 0.5)
    refresh()
  end
  G.FUNCS.forge_g_look_del = function()
    local d = B.state.draft
    if not d then return end
    local all = Grow.stash(B, d)
    if #all <= 1 then return end
    local i = B.state.look_i or 1
    table.remove(all, i)
    B.state.look_i = math.min(i, #all)
    d.art = all[B.state.look_i]
    B.dirty = true
    sound("crumple1", 1, 0.4)
    refresh()
  end
end

return Grow
