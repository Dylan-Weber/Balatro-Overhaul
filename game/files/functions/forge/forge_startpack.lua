local SP = {}

SP.V = 16
SP.ID = "free_pack"
SP.OLD = "give_pack"
SP.KINDS = {"deck", "challenge", "stake", "voucher"}
SP.USE = {"use", "spectral"}
SP.wait = 0

function SP.cat(Cat)
  local e = {id = SP.ID, label = "Free pack", v = "pack", line = "Opens a free {C:attention}%s Pack{}", own_line = "Opens a free {C:attention}%s{}", run = true, new = true, need = SP.V}
  local function add(list, x)
    if not list then return end
    for _, y in ipairs(list) do if y.id == x.id then return end end
    local c = {}
    for k, v in pairs(x) do c[k] = v end
    list[#list + 1] = c
  end
  for _, k in ipairs(SP.KINDS) do add(Cat.EFFECTS[k], e) end
  local plain = {}
  for k, v in pairs(e) do plain[k] = v end
  plain.run = nil
  for _, k in ipairs(SP.USE) do add(Cat.EFFECTS[k], plain) end
end

function SP.queue(v)
  if not (G and G.GAME) then return end
  G.GAME.forge_packs = type(G.GAME.forge_packs) == "table" and G.GAME.forge_packs or {}
  G.GAME.forge_packs[#G.GAME.forge_packs + 1] = v
end

function SP.ready()
  if not (G and G.GAME and G.STATES) then return false end
  local q = G.GAME.forge_packs
  if type(q) ~= "table" or #q == 0 then return false end
  if G.CONTROLLER and G.CONTROLLER.locked then return false end
  if G.OVERLAY_MENU or G.GAME.PACK_INTERRUPT or (G.pack_cards and not G.pack_cards.REMOVED) then return false end
  if G.STATE == G.STATES.BLIND_SELECT then return G.blind_select ~= nil and G.blind_select_opts ~= nil end
  if G.STATE == G.STATES.SHOP then return G.shop ~= nil and G.shop_jokers ~= nil end
  return false
end

function SP.tick(dt)
  if not SP.ready() then
    SP.wait = 0
    return
  end
  SP.wait = SP.wait + (tonumber(dt) or 0)
  if SP.wait < 0.6 then return end
  SP.wait = 0
  local v = table.remove(G.GAME.forge_packs, 1)
  local M = require("functions/forge/forge_kinds_more")
  local key = M.pack_key and M.pack_key(v)
  if key and M.open_pack then M.open_pack(key) end
end

function SP.install()
  if SP.hooked then return end
  local okh, Hooks = pcall(require, "overhaul.hooks")
  if not (okh and Hooks) then return end
  SP.hooked = true
  Hooks.wrap("Game", "update", function(orig) return function(self, dt, ...)
    local r = {orig(self, dt, ...)}
    local ok, err = pcall(SP.tick, dt)
    if not ok and not SP.failed then
      SP.failed = true
      print("[FORGE] free pack failed: " .. tostring(err))
    end
    return unpack(r)
  end end, {id = "forge_startpack.update"})
end

return SP
