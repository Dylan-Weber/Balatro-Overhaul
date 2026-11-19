local Store = require("functions/forge/forge_store")

local Ra = {}

Ra.MAX = 8
Ra.PREFIX = "rarity_forge_"
Ra.COLOURS = {"PURPLE", "GOLD", "GREEN", "TEAL", "ORANGE", "PINK", "BLUE", "RED", "BLACK"}
Ra.HEX = {PURPLE = "8a5cd1", GOLD = "d99a1e", GREEN = "2f9a55", TEAL = "1d9399", ORANGE = "e0702a", PINK = "d8508f", BLUE = "3466d0", RED = "d8473f", BLACK = "3a3346"}
Ra.list = {}
Ra.by_key = {}
Ra.by_id = {}

local function smods() return type(rawget(_G, "SMODS")) == "table" and type(SMODS.Rarities) == "table" end

function Ra.fields(c)
  local f = type(c) == "table" and type(c.fields) == "table" and c.fields or {}
  local w = tonumber(f.chance)
  return {colour = Ra.HEX[f.colour] and f.colour or "PURPLE", chance = w and math.max(0, math.min(100, w)) or 2}
end

function Ra.key(id) return Ra.PREFIX .. tostring(id) end

function Ra.loc_key(key) return "k_" .. string.lower(tostring(key)) end

function Ra.rgb(c)
  local hex = Ra.HEX[Ra.fields(c).colour]
  local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  return {r / 255, g / 255, b / 255, 1}
end

function Ra.assign(items)
  local list = {}
  for _, c in ipairs(type(items) == "table" and items or {}) do
    if type(c) == "table" and c.kind == "rarity" and c.enabled ~= false and type(c.id) == "string" then list[#list + 1] = c end
  end
  table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
  local out = {}
  for i = 1, math.min(Ra.MAX, #list) do
    local c = list[i]
    out[#out + 1] = {id = c.id, c = c, key = Ra.key(c.id), index = i}
  end
  return out
end

function Ra.set_list(list)
  Ra.list, Ra.by_key, Ra.by_id = list, {}, {}
  for _, r in ipairs(list) do
    Ra.by_key[r.key] = r
    Ra.by_id[r.id] = r
  end
end

function Ra.refresh_list()
  local ok, items = pcall(Store.live_items)
  Ra.set_list(Ra.assign(ok and items or {}))
  return Ra.list
end

function Ra.own_ok(v)
  return type(v) == "string" and v:sub(1, #Ra.PREFIX) == Ra.PREFIX and #v <= #Ra.PREFIX + 16 and not v:sub(#Ra.PREFIX + 1):find("[^%w]") and #v > #Ra.PREFIX
end

function Ra.of_joker(c)
  local v = type(c) == "table" and c.own_rarity
  if not Ra.own_ok(v) then return nil end
  return Ra.by_key[v] and v or nil
end

function Ra.name(r)
  local c = r and r.c
  if c and c.name and c.name ~= "" then return c.name end
  return mod_loc and mod_loc("Rarity") or "Rarity"
end

function Ra.label(v)
  local r = Ra.by_key[v]
  if r then return Ra.name(r) end
  local R = package.loaded["functions/forge/forge_rules"]
  return R and R.own_label and R.own_label("rarity", v) or tostring(v)
end

function Ra.live_jokers(key)
  local out = {}
  for _, v in ipairs(G and G.P_JOKER_RARITY_POOLS and G.P_JOKER_RARITY_POOLS[key] or {}) do
    if v.forge_on ~= false and not v.forge_lost then out[#out + 1] = v end
  end
  return out
end

local function allowed(r, append)
  local X = package.loaded["functions/forge/forge_rarityrules"]
  return not X or X.allowed(r, append)
end

function Ra.chance(r)
  local b = G and G.GAME and G.GAME.forge_bonus
  local add = b and tonumber(b[r.key]) or 0
  return math.max(0, Ra.fields(r.c).chance + add)
end

function Ra.total(append)
  local total = 0
  for _, r in ipairs(Ra.list) do
    if #Ra.live_jokers(r.key) > 0 and allowed(r, append) then total = total + Ra.chance(r) end
  end
  return total
end

function Ra.pick(roll, append)
  local total = Ra.total(append)
  if total <= 0 then return nil end
  local at = roll * (100 + total)
  if at >= total then return nil end
  for _, r in ipairs(Ra.list) do
    if #Ra.live_jokers(r.key) > 0 and allowed(r, append) then
      local w = Ra.chance(r)
      if w > 0 and at < w then return r end
      at = at - w
    end
  end
  return nil
end

local function loc(r)
  local L = G and G.localization
  if not (L and L.misc) then return end
  L.misc.dictionary = L.misc.dictionary or {}
  L.misc.labels = L.misc.labels or {}
  L.misc.dictionary[Ra.loc_key(r.key)] = Ra.name(r)
  L.misc.labels[Ra.loc_key(r.key)] = Ra.name(r)
end

function Ra.inject_loc()
  for _, r in ipairs(Ra.list) do pcall(loc, r) end
end

function Ra.poll_append(key)
  if type(key) ~= "string" then return nil end
  return key:match("^rarity_?%a*%d+(%a+)$")
end

function Ra.smods_weight(self, weight)
  local r = Ra.by_key[self.key]
  local ap = Ra.polling
  if r and ap and not allowed(r, ap) then return 0 end
  return weight
end

function Ra.hook_poll(SM)
  if Ra.poll_hooked or type(SM.poll_rarity) ~= "function" then return end
  Ra.poll_hooked = true
  local orig = SM.poll_rarity
  SM.poll_rarity = function(pool_key, rand_key, ...)
    local before = Ra.polling
    Ra.polling = Ra.poll_append(rand_key)
    local r = {pcall(orig, pool_key, rand_key, ...)}
    Ra.polling = before
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, table.maxn(r))
  end
end

function Ra.register_smods(list)
  local SM = rawget(_G, "SMODS")
  Ra.hook_poll(SM)
  local RB = SM.Rarity and SM.Rarity.obj_buffer
  local jt = SM.ObjectTypes and SM.ObjectTypes.Joker
  for key, o in pairs(SM.Rarities) do if type(o) == "table" and o.forge_rarity then SM.Rarities[key] = nil end end
  if RB then
    for i = #RB, 1, -1 do if type(RB[i]) == "string" and RB[i]:sub(1, #Ra.PREFIX) == Ra.PREFIX then table.remove(RB, i) end end
  end
  if jt and jt.rarities then
    for i = #jt.rarities, 1, -1 do
      local k = jt.rarities[i] and jt.rarities[i].key
      if type(k) == "string" and k:sub(1, #Ra.PREFIX) == Ra.PREFIX then table.remove(jt.rarities, i) end
    end
  end
  for _, r in ipairs(list) do
    local w = Ra.fields(r.c).chance / 100
    local obj = {key = r.key, original_key = r.key, badge_colour = Ra.rgb(r.c), default_weight = w, pools = {Joker = {weight = w}},
      disable_if_empty = true, forge_rarity = r.id, set = "Rarity", loc_txt = {}, get_weight = Ra.smods_weight}
    if SM.Rarity then setmetatable(obj, {__index = SM.Rarity}) end
    SM.Rarities[r.key] = obj
    if RB then RB[#RB + 1] = r.key end
    if jt and jt.rarities then
      jt.rarities[#jt.rarities + 1] = {key = r.key, weight = w}
      if jt.rarity_pools then jt.rarity_pools[r.key] = jt.rarity_pools[r.key] or {} end
    end
  end
end

function Ra.register()
  if not (G and G.P_JOKER_RARITY_POOLS) then return end
  local list = Ra.refresh_list()
  G.C = G.C or {}
  G.C.RARITY = G.C.RARITY or {}
  for _, r in ipairs(list) do
    G.P_JOKER_RARITY_POOLS[r.key] = G.P_JOKER_RARITY_POOLS[r.key] or {}
    local col = Ra.rgb(r.c)
    local old = G.C.RARITY[r.key]
    if type(old) == "table" then
      for i = 1, 4 do old[i] = col[i] end
    else
      G.C.RARITY[r.key] = col
    end
    pcall(loc, r)
  end
  if smods() then
    local ok, err = pcall(Ra.register_smods, list)
    if not ok then require("functions/forge/forge_joker").log_once("rarity_smods", "rarity register failed: " .. tostring(err)) end
  end
end

function Ra.own_pool(key, fn, ...)
  local FJ = package.loaded["functions/forge/forge_joker"]
  if FJ and FJ.sync_pools then pcall(FJ.sync_pools) end
  local pools = G.P_JOKER_RARITY_POOLS
  local keep = pools[1]
  pools[1] = pools[key] or {}
  Ra.swapping = true
  local r = {pcall(fn, ...)}
  Ra.swapping = false
  pools[1] = keep
  if not r[1] then error(r[2], 0) end
  return unpack(r, 2, table.maxn(r))
end

function Ra.install_hooks()
  if Ra.hooked then return end
  Ra.hooked = true
  pcall(require("functions/forge/forge_rarityrules").install)
  if type(get_current_pool) == "function" then
    local orig = get_current_pool
    get_current_pool = function(_type, _rarity, _legendary, _append, ...)
      if _type ~= "Joker" or _legendary or smods() or not (G and G.GAME and G.P_JOKER_RARITY_POOLS) then return orig(_type, _rarity, _legendary, _append, ...) end
      if type(_rarity) == "string" and Ra.own_ok(_rarity) then
        return Ra.own_pool(_rarity, orig, _type, 0, nil, "fr" .. string.lower(_rarity:sub(#Ra.PREFIX + 1)) .. (_append or ""), ...)
      end
      if _rarity == nil and #Ra.list > 0 then
        local ante = G.GAME.round_resets and G.GAME.round_resets.ante or 1
        local ok, r = pcall(Ra.pick, pseudorandom("forge_rarity" .. ante .. (_append or "")), _append)
        if ok and r then
          return Ra.own_pool(r.key, orig, _type, 0, nil, "fr" .. string.lower(r.id) .. (_append or ""), ...)
        end
      end
      return orig(_type, _rarity, _legendary, _append, ...)
    end
  end
end

local function register_strings()
  if not mod_loc_register then return end
  mod_loc_register{
    fr = {
      ["Rarity"] = "Rareté", ["Rarities"] = "Raretés", ["Shop odds"] = "Chance en boutique",
      ["A new rarity for your Jokers"] = "Une nouvelle rareté pour vos Jokers", ["Shop odds {C:attention}%s{}"] = "Chance en boutique {C:attention}%s{}",
      ["Never in the shop, only made by effects"] = "Jamais en boutique, seulement créée par des effets",
    },
    es = {
      ["Rarity"] = "Rareza", ["Rarities"] = "Rarezas", ["Shop odds"] = "Probabilidad en tienda",
      ["A new rarity for your Jokers"] = "Una nueva rareza para tus comodines", ["Shop odds {C:attention}%s{}"] = "Probabilidad en tienda {C:attention}%s{}",
      ["Never in the shop, only made by effects"] = "Nunca en la tienda, solo creada por efectos",
    },
  }
end

register_strings()

return Ra
