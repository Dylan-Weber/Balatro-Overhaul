local Remix = {}

Remix.MAX = 4
Remix.MAX_NAME = 24

local function fs() return rawget(_G, "love") and love.filesystem end

local function cut(s, max)
  s = tostring(s or ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if #s <= max then return s end
  s = s:sub(1, max)
  while #s > 0 and s:byte(#s) >= 128 and s:byte(#s) < 192 do s = s:sub(1, -2) end
  if #s > 0 and s:byte(#s) >= 192 then s = s:sub(1, -2) end
  return s
end

local function id_ok(id)
  return type(id) == "string" and #id >= 4 and #id <= 8 and id:match("^[a-z0-9]+$") ~= nil
end

function Remix.clean(list)
  if type(list) ~= "table" then return nil end
  if list.id ~= nil then list = {list} end
  local out, seen = {}, {}
  for _, c in ipairs(list) do
    if type(c) == "table" and id_ok(c.id) and not seen[c.id] then
      seen[c.id] = true
      local name = cut(c.name, Remix.MAX_NAME)
      out[#out + 1] = {id = c.id, name = name ~= "" and name or "Forge mod", author = cut(c.author, Remix.MAX_NAME)}
      if #out >= Remix.MAX then break end
    end
  end
  return #out > 0 and out or nil
end

function Remix.merge(...)
  local all = {}
  for i = 1, select("#", ...) do
    local l = Remix.clean(select(i, ...))
    for _, c in ipairs(l or {}) do all[#all + 1] = c end
  end
  return Remix.clean(all)
end

function Remix.credit_text(list)
  local l = Remix.clean(list)
  local c = l and l[1]
  if not c then return nil end
  local text
  if c.author ~= "" then
    text = string.format(mod_loc("Remix of %s by %s"), c.name, c.author)
  else
    text = string.format(mod_loc("Remix of %s"), c.name)
  end
  if #l > 1 then text = text .. string.format(mod_loc(" and %d more"), #l - 1) end
  return text
end

function Remix.store(S)
  if S.remix_hooked then return end
  S.remix_hooked = true
  local function old_of(list, id)
    for _, c in ipairs(type(list) == "table" and list or {}) do if c.id == id then return c end end
  end
  local base_clean = S.clean
  S.clean = function(c)
    local out = base_clean(c)
    if out and type(c) == "table" then
      local old = c.remix == nil and old_of(rawget(S, "list"), out.id)
      out.remix = Remix.clean(c.remix) or (old and Remix.clean(old.remix)) or nil
    end
    return out
  end
  local base_item = S.clean_item
  S.clean_item = function(c)
    local out = base_item(c)
    if out and type(c) == "table" then
      local old = c.remix == nil and old_of(rawget(S, "items_list"), out.id)
      out.remix = Remix.clean(c.remix) or (old and Remix.clean(old.remix)) or nil
    end
    return out
  end
end

function Remix.of_pack(creations)
  local all = {}
  for _, c in ipairs(creations or {}) do
    for _, r in ipairs(Remix.clean(c.remix) or {}) do all[#all + 1] = r end
  end
  return Remix.clean(all)
end

local function copy_file(from, to)
  local f = fs()
  if not (f and type(from) == "string" and f.getInfo(from)) then return nil end
  local data = f.read(from)
  if type(data) ~= "string" or not f.write(to, data) then return nil end
  return to
end

function Remix.copy(mod_id)
  local Mods = require("functions/forge/forge_mods")
  local Store = require("functions/forge/forge_store")
  local Rules = require("functions/forge/forge_rules")
  local mod = Mods.get(mod_id)
  if not mod then return nil, "gone" end
  if mod.mine then return nil, "mine" end
  Store.ensure_dirs()
  local credit = {id = mod.id, name = mod.name, author = mod.author}
  local map, taken = {}, {}
  local list = {}
  for _, c in ipairs(mod.jokers or {}) do list[#list + 1] = {c = c, joker = true} end
  for _, c in ipairs(mod.creations or {}) do list[#list + 1] = {c = c, joker = false} end
  for _, e in ipairs(list) do
    local id
    for _ = 1, 20 do
      id = Store.new_id()
      if not taken[id] then break end
    end
    taken[id] = true
    map[e.c.id] = id
  end
  local ids = {}
  for _, e in ipairs(list) do
    local x = Store.copy(e.c)
    x.id = map[e.c.id]
    x.mod_id, x.src = nil, nil
    x.created = os.time()
    x.enabled = true
    x.remix = Remix.merge({credit}, e.c.remix)
    if type(x.art) == "table" and x.art.file then
      local p = copy_file(x.art.file, Store.art_path(x.id))
      x.art = p and {file = p} or (e.joker and {atlas = "Joker", x = 0, y = 0} or nil)
    end
    if type(x.faces) == "table" then
      local faces = {}
      for _, r in ipairs({"J", "Q", "K"}) do
        if x.faces[r] then faces[r] = copy_file(x.faces[r], Store.art_path(x.id .. "_" .. r)) end
      end
      x.faces = faces
    end
    if type(x.looks) == "table" then
      for i, a in ipairs(x.looks) do
        if type(a) == "table" and a.file then
          local p = copy_file(a.file, Store.art_path(x.id .. "_l" .. (i + 1)))
          x.looks[i] = p and {file = p} or {atlas = "Joker", x = 0, y = 0}
        end
      end
    end
    Rules.map_refs(x, function(old) return map[old] end)
    local saved
    if e.joker then saved = Store.put(x) else saved = Store.put_item(x) end
    if saved then ids[#ids + 1] = saved.id end
  end
  if #ids == 0 then return nil, "empty" end
  local FJ = package.loaded["functions/forge/forge_joker"]
  if FJ and FJ.register_all then pcall(FJ.register_all) end
  local K = rawget(_G, "ForgeKinds")
  if K and K.register_all then pcall(K.register_all) end
  return ids, mod
end

function Remix.start(mod_id)
  local ids, mod = Remix.copy(mod_id)
  local MU = rawget(_G, "ForgeModsUI")
  if not ids then
    if MU then MU.state.msg = {text = mod_loc("Could not remix it."), colour = G.C.RED} end
    return nil
  end
  if play_sound then play_sound("card1", 1.1, 0.6) end
  if MU and MU.open_export then
    local name = cut(mod.name .. " " .. mod_loc("Remix"), Remix.MAX_NAME)
    MU.open_export(nil, "mods", {pick = ids, name = name, remix = true})
  end
  return ids
end

local function remix_button(e)
  local id = e and e.config and e.config.ref_table and e.config.ref_table.id
  if id then Remix.start(id) end
end

local function register_strings()
  if rawget(_G, "G") and G.FUNCS then G.FUNCS.forge_mods_remix = remix_button end
  if not rawget(_G, "mod_loc_register") then return end
  mod_loc_register{
    fr = {
      ["Remix"] = "Remix", ["Remix of %s by %s"] = "Remix de %s par %s", ["Remix of %s"] = "Remix de %s", [" and %d more"] = " et %d de plus",
      ["Could not remix it."] = "Impossible de le remixer.",
      ["Its cards are now in your Forge. Change what you like, then export."] = "Ses cartes sont maintenant dans votre Forge. Changez ce que vous voulez, puis exportez.",
      ["The credit to the original stays with it."] = "Le crédit de l'original reste avec lui.",
    },
    es = {
      ["Remix"] = "Remix", ["Remix of %s by %s"] = "Remix de %s de %s", ["Remix of %s"] = "Remix de %s", [" and %d more"] = " y %d más",
      ["Could not remix it."] = "No se pudo remezclar.",
      ["Its cards are now in your Forge. Change what you like, then export."] = "Sus cartas ya están en tu Forja. Cambia lo que quieras y exporta.",
      ["The credit to the original stays with it."] = "El crédito al original se queda con él.",
    },
  }
end

Remix.register = register_strings
register_strings()

return Remix
