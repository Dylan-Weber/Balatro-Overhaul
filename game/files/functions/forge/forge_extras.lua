local X = {}

X.V = 17
X.FPS = {1, 2, 3, 4, 6, 8, 10, 12}
X.FPS_DEF = 6
X.MAX_SOUND = 64 * 1024
X.MAX_SECONDS = 3
X.SOUND_DIR = "forge/sound"
X.DRAFT_SOUL = "forge/art/draft_soul.png"
X.DRAFT_SOUND = "forge/sound/draft"
X.IMPORT_DIR = "forge/import"
X.INK_DIR = "forge/inkjoker"
X.INK_MAX = 240
X.EXTS = {ogg = true, wav = true, mp3 = true}
X.played = {}
X.SOUL_KINDS = {joker = true, tarot = true, planet = true, spectral = true, voucher = true, booster = true, enhancement = true}
X.SOUND_KINDS = {joker = true, tarot = true, planet = true, spectral = true, voucher = true, booster = true, enhancement = true, seal = true, edition = true, tag = true, deck = true, blind = true}
X.KEY_PREFIXES = {"c_forge_", "v_forge_", "b_forge_", "m_forge_", "e_forge_", "p_forge_", "tag_forge_", "bl_forge_", "Forge_"}

X.SOUNDS = {
  {k = "chips1", en = "Chips", fr = "Jetons", es = "Fichas"},
  {k = "multhit1", en = "Mult", fr = "Multi", es = "Mult"},
  {k = "multhit2", en = "Big Mult", fr = "Gros Multi", es = "Gran Mult"},
  {k = "coin3", en = "Coin", fr = "Pièce", es = "Moneda"},
  {k = "gong", en = "Gong", fr = "Gong", es = "Gong"},
  {k = "glass1", en = "Glass", fr = "Verre", es = "Cristal"},
  {k = "holo1", en = "Holo", fr = "Holo", es = "Holo"},
  {k = "polychrome1", en = "Polychrome", fr = "Polychrome", es = "Policromo"},
  {k = "foil1", en = "Foil", fr = "Brillant", es = "Laminado"},
  {k = "negative", en = "Negative", fr = "Négatif", es = "Negativo"},
  {k = "tarot1", en = "Tarot", fr = "Tarot", es = "Tarot"},
  {k = "gold_seal", en = "Gold Seal", fr = "Sceau doré", es = "Sello dorado"},
  {k = "explosion_release1", en = "Explosion", fr = "Explosion", es = "Explosión"},
  {k = "whoosh1", en = "Whoosh", fr = "Souffle", es = "Zumbido"},
  {k = "slice1", en = "Slice", fr = "Coupe", es = "Corte"},
  {k = "crumple1", en = "Crumple", fr = "Froissé", es = "Arrugado"},
  {k = "timpani", en = "Timpani", fr = "Timbales", es = "Timbales"},
  {k = "voice1", en = "Voice", fr = "Voix", es = "Voz"},
  {k = "magic_crumple", en = "Magic", fr = "Magie", es = "Magia"},
  {k = "generic1", en = "Pop", fr = "Pop", es = "Pop"},
}
X.SOUND_BY = {}
for _, s in ipairs(X.SOUNDS) do X.SOUND_BY[s.k] = s end

X.LOC = {
  fr = {["Sound: %s"] = "Son : %s",
    ["Soul: on"] = "L'âme : oui", ["Add a soul"] = "Ajouter une âme", ["SOUL AND SOUND"] = "L'AME ET LE SON",
    ["Floating soul"] = "L'âme flottante", ["Remove"] = "Retirer", ["Sound"] = "Son", ["Listen"] = "Tester",
    ["WHICH SOUND?"] = "QUEL SON ?", ["No sound"] = "Aucun son", ["Pick a file"] = "Choisir un fichier", ["Your sound"] = "Votre son",
    ["The soul floats above the card like on Legendary Jokers. The sound plays when the Joker triggers."] =
      "L'âme flotte au-dessus de la carte comme sur les Jokers légendaires. Le son se joue quand le Joker se déclenche.",
    ["Your own sounds: .ogg, .wav or .mp3, 3 seconds and 64 KB at most, in forge/import."] =
      "Vos propres sons : .ogg, .wav ou .mp3, 3 secondes et 64 Ko au plus, dans forge/import.",
    ["%s is too long (3 seconds at most)."] = "%s est trop long (3 secondes au plus).", ["%s is too big (64 KB at most)."] = "%s est trop gros (64 Ko au plus).",
    ["%s is not a sound the game can play."] = "%s n'est pas un son que le jeu peut lire.",
    ["Animation"] = "Animation", ["Speed"] = "Vitesse", ["%d per second"] = "%d par seconde",
    ["The looks play one after another, like a flipbook."] = "Les looks s'enchaînent, comme un folioscope.",
    ["An animation needs a second look: add one in Looks"] = "Une animation demande un deuxième look : ajoutez-en un dans Looks",
    ["InkJoker art"] = "Dessin InkJoker", ["PICK INKJOKER ART"] = "CHOISISSEZ UN DESSIN INKJOKER", ["No InkJoker art found"] = "Aucun dessin InkJoker trouvé"},
  es = {["Sound: %s"] = "Sonido: %s",
    ["Soul: on"] = "Alma: sí", ["Add a soul"] = "Añadir alma", ["SOUL AND SOUND"] = "ALMA Y SONIDO",
    ["Floating soul"] = "Alma flotante", ["Remove"] = "Quitar", ["Sound"] = "Sonido", ["Listen"] = "Escuchar",
    ["WHICH SOUND?"] = "¿QUÉ SONIDO?", ["No sound"] = "Sin sonido", ["Pick a file"] = "Elegir un archivo", ["Your sound"] = "Tu sonido",
    ["The soul floats above the card like on Legendary Jokers. The sound plays when the Joker triggers."] =
      "El alma flota sobre la carta como en los Jokers legendarios. El sonido suena cuando el Joker se activa.",
    ["Your own sounds: .ogg, .wav or .mp3, 3 seconds and 64 KB at most, in forge/import."] =
      "Tus propios sonidos: .ogg, .wav o .mp3, 3 segundos y 64 KB como máximo, en forge/import.",
    ["%s is too long (3 seconds at most)."] = "%s es demasiado largo (3 segundos como máximo).", ["%s is too big (64 KB at most)."] = "%s es demasiado grande (64 KB como máximo).",
    ["%s is not a sound the game can play."] = "%s no es un sonido que el juego pueda reproducir.",
    ["Animation"] = "Animación", ["Speed"] = "Velocidad", ["%d per second"] = "%d por segundo",
    ["The looks play one after another, like a flipbook."] = "Los aspectos se suceden, como un folioscopio.",
    ["An animation needs a second look: add one in Looks"] = "Una animación necesita un segundo aspecto: añade uno en Aspectos",
    ["InkJoker art"] = "Arte InkJoker", ["PICK INKJOKER ART"] = "ELIGE UN ARTE INKJOKER", ["No InkJoker art found"] = "No se encontró arte InkJoker"},
}

local function ml(s)
  local f = rawget(_G, "mod_loc")
  return f and f(s) or s
end
local function fs() return rawget(_G, "love") and love.filesystem or nil end
local function store() return package.loaded["functions/forge/forge_store"] end
local function lang()
  local Cat = package.loaded["functions/forge/forge_catalog"]
  return Cat and Cat.lang and Cat.lang() or "en"
end
local function sfx(...)
  local f = rawget(_G, "play_sound")
  if f then pcall(f, ...) end
end
local function reopen()
  local JF = rawget(_G, "JokerForge")
  if JF and JF.ui then JF.ui.reopen("builder") end
end
local function ensure(dir)
  local f = fs()
  if f and not f.getInfo(dir) then f.createDirectory(dir) end
end

function X.art_ok(p) return type(p) == "string" and p:match("^forge/art/[%w_]+%.png$") ~= nil end

function X.sound_path_ok(p)
  if type(p) ~= "string" then return false end
  local b, e = p:match("^forge/sound/([%w_]+)%.(%a+)$")
  return b ~= nil and X.EXTS[e] == true
end

function X.clean_soul(s)
  if type(s) == "table" and X.art_ok(s.file) then return {file = s.file} end
  return nil
end

function X.clean_anim(n)
  n = math.floor(tonumber(n) or 0)
  if n >= 1 and n <= 12 then return n end
  return nil
end

function X.clean_sound(s)
  if type(s) ~= "table" then return nil end
  if type(s.key) == "string" and X.SOUND_BY[s.key] then return {key = s.key} end
  if X.sound_path_ok(s.file) then return {file = s.file} end
  return nil
end

function X.uses(c)
  if type(c) ~= "table" then return false end
  return X.clean_soul(c.soul) ~= nil or X.clean_anim(c.anim) ~= nil or X.clean_sound(c.sound) ~= nil
end

function X.kind_of(c) return type(c) == "table" and c.kind or "joker" end

function X.magic(data)
  if type(data) ~= "string" or #data < 12 then return nil end
  if data:sub(1, 4) == "OggS" then return "ogg" end
  if data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WAVE" then return "wav" end
  if data:sub(1, 3) == "ID3" then return "mp3" end
  local a, b = data:byte(1, 2)
  if a == 0xFF and b and b >= 0xE0 then return "mp3" end
  return nil
end

function X.check_sound(data)
  if type(data) ~= "string" then return nil, "bad" end
  if #data > X.MAX_SOUND then return nil, "big" end
  local ext = X.magic(data)
  if not ext then return nil, "bad" end
  local L = rawget(_G, "love")
  if L and L.sound and L.filesystem and L.filesystem.newFileData then
    local ok, sd = pcall(function() return L.sound.newSoundData(L.filesystem.newFileData(data, "x." .. ext)) end)
    if not ok or not sd then return nil, "bad" end
    if sd:getDuration() > X.MAX_SECONDS + 0.05 then return nil, "long" end
  end
  return ext
end

function X.sound_label(s)
  s = X.clean_sound(s)
  if not s then return ml("No sound") end
  if s.key then
    local e = X.SOUND_BY[s.key]
    return e[lang()] or e.en
  end
  return ml("Your sound")
end

local cache = {}

function X.forget(path) cache[path] = nil end

local function source(path)
  local f = fs()
  local info = f and f.getInfo(path)
  if not info then return nil end
  local stamp = tostring(info.size) .. ":" .. tostring(info.modtime)
  local c = cache[path]
  if c and c.stamp == stamp then return c.src end
  local ok, src = pcall(function() return love.audio.newSource(love.sound.newSoundData(path), "static") end)
  if not ok or not src then return nil end
  cache[path] = {src = src, stamp = stamp}
  return src
end

function X.volume()
  local S = G and G.SETTINGS and G.SETTINGS.SOUND or {}
  return ((tonumber(S.volume) or 50) / 100) * ((tonumber(S.game_sounds_volume) or 50) / 100)
end

function X.play(s)
  s = X.clean_sound(s)
  if not s then return false end
  if s.key then
    sfx(s.key, 1, 0.7)
    X.played[#X.played + 1] = s.key
    print("[FORGE] sound played: " .. s.key)
    return true
  end
  local src = source(s.file)
  if not src then return false end
  pcall(function()
    src:stop()
    src:setVolume(math.max(0, math.min(1, X.volume())))
    src:play()
  end)
  X.played[#X.played + 1] = s.file
  print("[FORGE] sound played: " .. s.file)
  return true
end

function X.triggered(r)
  return type(r) == "table" and next(r) ~= nil
end

function X.on_calc(card, r)
  local cen = card and card.config and card.config.center
  local s = cen and cen.forge_sound
  if not (s and X.triggered(r)) or card.forge_preview then return end
  X.queue(card, s)
end

X.last = {}

function X.sound_of_key(key)
  if type(key) ~= "string" then return nil end
  local S = store()
  for _, p in ipairs(X.KEY_PREFIXES) do
    if key:sub(1, #p) == p then
      local c = S and S.get_item and S.get_item(key:sub(#p + 1))
      return c and X.SOUND_KINDS[c.kind] and X.clean_sound(c.sound) or nil
    end
  end
  return nil
end

function X.queue(card, s)
  s = X.clean_sound(s)
  if not s or (card and card.forge_preview) then return end
  local L = rawget(_G, "love")
  local now = L and L.timer and L.timer.getTime() or os.clock()
  local holder = card or X.last
  local tag = card and "forge_sound_t" or (s.key or s.file)
  if holder[tag] and now - holder[tag] < 0.2 then return end
  holder[tag] = now
  local E, Ev = G and G.E_MANAGER, rawget(_G, "Event")
  if E and Ev then
    E:add_event(Ev({trigger = "immediate", func = function() X.play(s) return true end}))
  else
    X.play(s)
  end
end

function X.fix_soul(card)
  local cen = card and card.config and card.config.center
  local name = cen and cen.forge_soul_atlas
  local fl = card and card.children and card.children.floating_sprite
  local atlas = name and G.ASSET_ATLAS and G.ASSET_ATLAS[name]
  if not (atlas and fl and fl.set_sprite_pos) then return end
  fl.atlas = atlas
  fl:set_sprite_pos({x = 0, y = 0})
end

function X.soul_atlas(name, file)
  local f = fs()
  local FJ = package.loaded["functions/forge/forge_joker"]
  if not (f and FJ and X.art_ok(file) and f.getInfo(file)) then return nil end
  local ok, data = pcall(love.image.newImageData, file)
  if ok and data and data:getWidth() == 71 and data:getHeight() == 95 and FJ.atlas_from_data(name, data) then return name end
  return nil
end

function X.apply(center, c, name)
  center.forge_soul_atlas, center.forge_sound, center.forge_anim = nil, nil, nil
  if center.forge_soul_set then center.soul_pos, center.forge_soul_set = nil, nil end
  local soul = X.clean_soul(c.soul)
  local atlas = soul and X.soul_atlas(name, soul.file)
  if atlas then
    center.soul_pos = {x = 0, y = 0}
    center.forge_soul_set = true
    center.forge_soul_atlas = atlas
  end
  center.forge_sound = X.clean_sound(c.sound)
  center.forge_anim = X.clean_anim(c.anim)
  return center
end

function X.joker(FJ)
  local base_center = FJ.center_for
  FJ.center_for = function(c, index)
    local center = base_center(c, index)
    X.apply(center, c, "forge_" .. c.id .. "_soul")
    if not center.forge_stages then center.forge_anim = nil end
    return center
  end
  local base_install = FJ.install_hooks
  FJ.install_hooks = function(...)
    local r = base_install(...)
    pcall(X.install)
    return r
  end
end

function X.install()
  if X.hooked then return end
  local ok, Hooks = pcall(require, "overhaul.hooks")
  if not (ok and Hooks and rawget(_G, "Card")) then return end
  X.hooked = true
  Hooks.wrap("Card", "set_sprites", function(orig) return function(self, ...)
    local r = orig(self, ...)
    pcall(X.fix_soul, self)
    return r
  end end, {id = "forge.extras_soul"})
  Hooks.wrap("Card", "calculate_joker", function(orig) return function(self, ...)
    local r = orig(self, ...)
    local cen = self.config and self.config.center
    if cen and cen.forge and cen.forge_sound then pcall(X.on_calc, self, r) end
    return r
  end end, {id = "forge.extras_sound"})
  Hooks.wrap("Card", "open", function(orig) return function(self, ...)
    local cen = self.config and self.config.center
    if cen and cen.forge_kind == "booster" then pcall(X.queue, self, cen.forge_sound) end
    return orig(self, ...)
  end end, {id = "forge.extras_open"})
  Hooks.wrap(_G, "eval_card", function(orig) return function(card, context, ...)
    local a, b, c = orig(card, context, ...)
    pcall(X.on_scored, card, context)
    return a, b, c
  end end, {id = "forge.extras_eval", allow_missing = true})
  local Grow = require("functions/forge/forge_grow")
  if not X.grow_hooked then
    X.grow_hooked = true
    local base_stage = Grow.stage_of
    Grow.stage_of = function(card, cen)
      cen = cen or (card and card.config and card.config.center)
      local fps = cen and cen.forge_anim
      if fps then
        local n = Grow.stage_count(cen)
        if n > 1 then
          local t = G and G.TIMERS and G.TIMERS.REAL or 0
          return math.floor(t * fps) % n + 1
        end
      end
      return base_stage(card, cen)
    end
  end
end

function X.on_scored(card, context)
  if not (card and context and G and context.cardarea == G.play) or context.repetition_only or context.repetition or context.post_trigger then return end
  if not card.playing_card then return end
  local cen = card.config and card.config.center
  local s = cen and cen.forge_kind == "enhancement" and cen.forge_sound or nil
  s = s or X.sound_of_key(card.seal) or X.sound_of_key(card.edition and card.edition.key)
  if s then X.queue(card, s) end
end

function X.kinds(K)
  local base_center = K.center_for
  K.center_for = function(c, index)
    local center = base_center(c, index)
    if center and X.SOUND_KINDS[c.kind] then
      X.apply(center, X.SOUL_KINDS[c.kind] and c or {sound = c.sound}, "forge_" .. c.id .. "_soul")
    end
    return center
  end
  local More = K.more
  if More and More.tag_apply then
    local base_tag = More.tag_apply
    More.tag_apply = function(tag, ...)
      local r = base_tag(tag, ...)
      pcall(X.queue, nil, X.sound_of_key(tag and tag.key))
      return r
    end
  end
  if More and More.blind_set then
    local base_blind = More.blind_set
    More.blind_set = function(blind, ...)
      local r = base_blind(blind, ...)
      pcall(function() X.queue(nil, X.sound_of_key(blind and blind.config and blind.config.blind and blind.config.blind.key)) end)
      return r
    end
  end
  local base_use = K.use
  K.use = function(card, ...)
    local r = base_use(card, ...)
    local cen = card and card.config and card.config.center
    if cen and cen.forge_sound then pcall(X.queue, card, cen.forge_sound) end
    return r
  end
  local base_voucher = K.apply_voucher
  K.apply_voucher = function(center, ...)
    local r = base_voucher(center, ...)
    if center and center.forge_sound then pcall(X.queue, nil, center.forge_sound) end
    return r
  end
  local base_deck = K.apply_deck
  K.apply_deck = function(back, ...)
    local r = base_deck(back, ...)
    local cen = back and back.effect and back.effect.center
    if cen and cen.forge_sound then pcall(X.queue, nil, cen.forge_sound) end
    return r
  end
end

function X.store(S)
  local base_clean = S.clean
  S.clean = function(c)
    local out = base_clean(c)
    if out and type(c) == "table" then
      out.soul = X.clean_soul(c.soul)
      out.anim = X.clean_anim(c.anim)
      out.sound = X.clean_sound(c.sound)
    end
    return out
  end
  local base_item = S.clean_item
  S.clean_item = function(c)
    local out = base_item(c)
    if out and type(c) == "table" then
      out.soul = X.SOUL_KINDS[out.kind] and X.clean_soul(c.soul) or nil
      out.sound = X.SOUND_KINDS[out.kind] and X.clean_sound(c.sound) or nil
    end
    return out
  end
  local base_del_item = S.delete_item
  S.delete_item = function(id)
    local c = S.get_item and S.get_item(id)
    local files = {}
    if c and c.soul then files[#files + 1] = c.soul.file end
    if c and c.sound and c.sound.file then files[#files + 1] = c.sound.file end
    local ok = base_del_item(id)
    local f = fs()
    if ok and f then
      for _, p in ipairs(files) do if f.getInfo(p) then pcall(f.remove, p) end end
    end
    return ok
  end
  local base_dup = S.duplicate
  S.duplicate = function(id, ...)
    local d = base_dup(id, ...)
    if not (d and (d.soul or (d.sound and d.sound.file))) then return d end
    local f = fs()
    if f and d.soul and f.getInfo(d.soul.file) then
      local to = S.art_path(d.id .. "_soul")
      local raw = f.read(d.soul.file)
      d.soul = (raw and f.write(to, raw)) and {file = to} or nil
    end
    if f and d.sound and d.sound.file and f.getInfo(d.sound.file) then
      ensure(X.SOUND_DIR)
      local ext = d.sound.file:match("%.(%a+)$")
      local to = X.SOUND_DIR .. "/" .. d.id .. "." .. ext
      local raw = f.read(d.sound.file)
      d.sound = (raw and f.write(to, raw)) and {file = to} or nil
    end
    S.save()
    return d
  end
  local base_delete = S.delete
  S.delete = function(id)
    local c = S.get and S.get(id)
    local files = {}
    if c and c.soul then files[#files + 1] = c.soul.file end
    if c and c.sound and c.sound.file then files[#files + 1] = c.sound.file end
    local ok = base_delete(id)
    local f = fs()
    if ok and f then
      for _, p in ipairs(files) do if f.getInfo(p) then pcall(f.remove, p) end end
    end
    return ok
  end
end

function X.mods(M)
  local base_needs = M.needs_v
  M.needs_v = function(jokers, creations)
    local v = base_needs(jokers, creations)
    for _, x in ipairs(jokers or {}) do if X.uses(x) then v = math.max(v, X.V) end end
    for _, x in ipairs(creations or {}) do if X.uses(x) then v = math.max(v, X.V) end end
    return v
  end
end

function X.files(c, out)
  local s = type(c) == "table" and X.clean_soul(c.soul)
  if s then out[#out + 1] = s.file end
  return out
end

function X.strip(x, packed)
  if type(x.soul) == "table" and not packed[x.soul.file] then x.soul = nil end
end

function X.remap(c, art)
  if type(c.soul) == "table" and c.soul.file then
    local p = art(c.soul.file)
    c.soul = p and {file = p} or nil
  end
end

local function sound_base(p)
  return type(p) == "string" and p:match("^forge/sound/([%w_]+)%.%a+$") or nil
end

function X.pack_sounds(M, out)
  local f = fs()
  local sounds = {}
  local list = {}
  for _, x in ipairs(out.jokers or {}) do list[#list + 1] = x end
  for _, x in ipairs(out.creations or {}) do list[#list + 1] = x end
  for _, x in ipairs(list) do
    local s = X.clean_sound(x.sound)
    if s and s.file then
      local b = sound_base(s.file)
      local data = f and f.getInfo(s.file) and f.read(s.file)
      if b and type(data) == "string" and X.check_sound(data) then
        sounds[b] = sounds[b] or M.b64_encode(data)
      else
        x.sound = nil
      end
    end
  end
  if next(sounds) then out.sounds = sounds end
end

function X.parse_sounds(M, t, mod)
  mod.sounds = {}
  if type(t.sounds) ~= "table" then return end
  local n = 0
  for k, v in pairs(t.sounds) do
    if type(k) == "string" and k:match("^[%w_]+$") and #k <= 40 and type(v) == "string" and n < M.MAX_FILES then
      local data = M.b64_decode(v)
      local ext = data and X.check_sound(data)
      if ext then
        mod.sounds[k] = {data = data, ext = ext}
        n = n + 1
      end
    end
  end
end

function X.mod_sound_path(mod_id, b, ext) return X.SOUND_DIR .. "/fm_" .. mod_id .. "_" .. b .. "." .. ext end

function X.remap_sound(c, mod)
  if type(c.sound) ~= "table" or not c.sound.file then return end
  local b = sound_base(c.sound.file)
  local s = b and mod.sounds and mod.sounds[b]
  c.sound = s and {file = X.mod_sound_path(mod.id, b, s.ext)} or nil
end

function X.extract(mod, force)
  local f = fs()
  if not (f and mod.sounds and next(mod.sounds)) then return end
  ensure("forge")
  ensure(X.SOUND_DIR)
  for b, s in pairs(mod.sounds) do
    local p = X.mod_sound_path(mod.id, b, s.ext)
    if force or not f.getInfo(p) then f.write(p, s.data) end
  end
end

function X.remove_sounds(mod_id)
  local f = fs()
  if not (f and f.getInfo(X.SOUND_DIR)) then return end
  local prefix = "fm_" .. mod_id .. "_"
  for _, name in ipairs(f.getDirectoryItems(X.SOUND_DIR)) do
    if name:sub(1, #prefix) == prefix then
      X.forget(X.SOUND_DIR .. "/" .. name)
      pcall(f.remove, X.SOUND_DIR .. "/" .. name)
    end
  end
end

function X.room_files(c, out)
  local s = type(c) == "table" and X.clean_soul(c.soul)
  if s then out[#out + 1] = {"S", s.file} end
  return out
end

function X.room_strip(x)
  x.soul = nil
  if type(x.sound) == "table" and x.sound.file then x.sound = nil end
end

function X.room_put(x, slot, p)
  if slot ~= "S" then return false end
  x.soul = {file = p}
  return true
end

function X.room_sounds(M, out, pairs_list, size, max_bytes)
  local f = fs()
  local sounds = {}
  for _, it in ipairs(pairs_list) do
    local s = X.clean_sound(it.c.sound)
    if s and s.file then
      local data = f and f.getInfo(s.file) and f.read(s.file)
      local ext = data and X.check_sound(data)
      if ext then
        local key = "r" .. it.x.id .. "snd"
        local b = M.b64_encode(data)
        local more = #b + #key + 8 + 40
        if size + more <= max_bytes then
          sounds[key] = b
          size = size + more
          it.x.sound = {file = X.SOUND_DIR .. "/" .. key .. "." .. ext}
        end
      end
    end
  end
  if next(sounds) then out.sounds = sounds end
  return size
end

function X.ink_roots()
  local env = os.getenv("INKJOKER_LIBRARY")
  if env and env ~= "" then return {env} end
  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if not home or home == "" then return {} end
  return {home .. "/InkJoker/library/saved/joker", home .. "/InkJoker/generated/cards"}
end

local function list_dir(dir)
  local L = rawget(_G, "love")
  local osn = L and L.system and L.system.getOS() or "Linux"
  if osn == "Android" or osn == "iOS" or not io.popen then return {} end
  local cmd = osn == "Windows" and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>NUL') or ('ls -1 "' .. dir:gsub('"', "") .. '" 2>/dev/null')
  local ok, h = pcall(io.popen, cmd)
  if not ok or not h then return {} end
  local out = {}
  for line in h:lines() do
    if line:lower():match("%.png$") and #out < X.INK_MAX then out[#out + 1] = line end
  end
  h:close()
  return out
end

function X.ink_safe(name)
  local stem = tostring(name):gsub("%.[Pp][Nn][Gg]$", ""):gsub("[^%w]", "_"):sub(1, 40)
  return stem ~= "" and stem or nil
end

function X.ink_sync()
  local f = fs()
  if not f then return 0 end
  local n = 0
  for _, root in ipairs(X.ink_roots()) do
    for _, name in ipairs(list_dir(root)) do
      local stem = X.ink_safe(name)
      local to = stem and (X.INK_DIR .. "/" .. stem .. ".png")
      if to and not f.getInfo(to) then
        local h = io.open(root .. "/" .. name, "rb")
        local data = h and h:read("*a")
        if h then h:close() end
        local M = package.loaded["functions/forge/forge_mods"]
        local w, hh
        if M then w, hh = M.png_size(data) end
        if type(data) == "string" and #data <= 64 * 1024 and w == 71 and hh == 95 then
          ensure("forge")
          ensure(X.INK_DIR)
          if f.write(to, data) then n = n + 1 end
        end
      end
    end
  end
  return n
end

function X.ink_list()
  local f = fs()
  if not (f and f.getInfo(X.INK_DIR)) then return {} end
  local names = {}
  for _, name in ipairs(f.getDirectoryItems(X.INK_DIR)) do
    if name:match("^[%w_]+%.png$") then names[#names + 1] = name end
  end
  table.sort(names)
  local out = {}
  for _, name in ipairs(names) do out[#out + 1] = {file = X.INK_DIR .. "/" .. name, ink = true} end
  return out
end

function X.ink_available()
  if X.ink_seen ~= nil then return X.ink_seen end
  local f = fs()
  local any = false
  if f and f.getInfo(X.INK_DIR) then
    for _, name in ipairs(f.getDirectoryItems(X.INK_DIR)) do if name:match("%.png$") then any = true break end end
  end
  if not any then
    for _, root in ipairs(X.ink_roots()) do if #list_dir(root) > 0 then any = true break end end
  end
  X.ink_seen = any
  return any
end

function X.ink_atlas(it, i)
  local f = fs()
  local FJ = package.loaded["functions/forge/forge_joker"]
  local name = "forge_ink_" .. i
  if it.loaded == name and G.ASSET_ATLAS[name] then return name end
  if not (f and FJ and f.getInfo(it.file)) then return nil end
  local ok, data = pcall(love.image.newImageData, it.file)
  if ok and data and data:getWidth() == 71 and data:getHeight() == 95 and FJ.atlas_from_data(name, data) then
    it.loaded = name
    return name
  end
  return nil
end

function X.import_sounds()
  local f = fs()
  local out = {}
  if not (f and f.getInfo(X.IMPORT_DIR)) then return out end
  for _, name in ipairs(f.getDirectoryItems(X.IMPORT_DIR)) do
    local e = (name:match("%.(%a+)$") or ""):lower()
    if X.EXTS[e] then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

function X.take_sound(name)
  local f = fs()
  local data = f and f.read(X.IMPORT_DIR .. "/" .. name)
  local ext, why = X.check_sound(data)
  if not ext then
    local msg = why == "big" and "%s is too big (64 KB at most)." or why == "long" and "%s is too long (3 seconds at most)." or "%s is not a sound the game can play."
    return nil, string.format(ml(msg), name)
  end
  ensure("forge")
  ensure(X.SOUND_DIR)
  for e in pairs(X.EXTS) do
    local p = X.DRAFT_SOUND .. "." .. e
    if f.getInfo(p) then pcall(f.remove, p) end
    X.forget(p)
  end
  local to = X.DRAFT_SOUND .. "." .. ext
  if not f.write(to, data) then return nil, string.format(ml("%s is not a sound the game can play."), name) end
  return {file = to}
end

function X.keep(d, id)
  local f = fs()
  local S = store()
  local soul = X.clean_soul(d.soul)
  if soul and f and S and soul.file == X.DRAFT_SOUL and f.getInfo(soul.file) then
    local to = S.art_path(id .. "_soul")
    local raw = f.read(soul.file)
    soul = (raw and f.write(to, raw)) and {file = to} or nil
  end
  if not soul and f and S and f.getInfo(S.art_path(id .. "_soul")) then pcall(f.remove, S.art_path(id .. "_soul")) end
  local snd = X.clean_sound(d.sound)
  if snd and snd.file and f and snd.file:sub(1, #X.DRAFT_SOUND + 1) == X.DRAFT_SOUND .. "." and f.getInfo(snd.file) then
    local ext = snd.file:match("%.(%a+)$")
    local to = X.SOUND_DIR .. "/" .. id .. "." .. ext
    local raw = f.read(snd.file)
    snd = (raw and f.write(to, raw)) and {file = to} or nil
    X.forget(to)
  end
  if f then
    for e in pairs(X.EXTS) do
      local p = X.SOUND_DIR .. "/" .. id .. "." .. e
      if not (snd and snd.file == p) and f.getInfo(p) then pcall(f.remove, p) end
    end
  end
  return soul, snd
end

function X.clear_drafts()
  local f = fs()
  if not f then return end
  for _, p in ipairs({X.DRAFT_SOUL, "forge/art/draft_soul_2x.png"}) do if f.getInfo(p) then pcall(f.remove, p) end end
  for e in pairs(X.EXTS) do
    local p = X.DRAFT_SOUND .. "." .. e
    if f.getInfo(p) then pcall(f.remove, p) end
    X.forget(p)
  end
end

function X.register_loc()
  local reg = rawget(_G, "mod_loc_register")
  if reg then reg(X.LOC) end
end

function X.builder(B)
  local K = B.kit
  local D = require("functions/forge/forge_doc")
  local Grow = require("functions/forge/forge_grow")
  local Store = store()
  local FJ = require("functions/forge/forge_joker")
  X.register_loc()

  local base_new = D.new
  D.new = function(kind, o)
    local d = base_new(kind, o)
    if X.SOUND_KINDS[d.kind] and type(o) == "table" then
      d.soul = X.SOUL_KINDS[d.kind] and X.clean_soul(o.soul) or nil
      d.sound = X.clean_sound(o.sound)
    end
    if d.kind == "joker" and type(o) == "table" then
      local fps = X.clean_anim(o.anim)
      if fps and d.looks then
        d.look_var = "anim"
        d.anim_fps = fps
      end
    end
    return d
  end

  local function frames(d)
    return d.look_all and #d.look_all or (1 + #(d.looks or {}))
  end

  local base_problems = D.problems
  D.problems = function(d)
    local out = base_problems(d)
    if d and d.kind == "joker" and d.look_var == "anim" and frames(d) <= 1 then out[#out + 1] = ml("An animation needs a second look: add one in Looks") end
    return out
  end

  local base_draft = B.new_draft
  B.new_draft = function(o)
    X.clear_drafts()
    return base_draft(o)
  end

  local base_save = B.save
  B.save = function(...)
    local d = B.state.draft
    local joker = d and d.kind == "joker"
    local anim = joker and d.look_var == "anim" and (X.clean_anim(d.anim_fps) or X.FPS_DEF) or nil
    if anim and frames(d) <= 1 then return nil end
    if anim then d.look_var = nil end
    local c = base_save(...)
    if anim and not c then d.look_var = "anim" end
    if c and d and not joker and X.SOUND_KINDS[d.kind] then
      local soul, snd = X.keep(d, c.id)
      local full = Store.copy(c)
      full.soul, full.sound = soul, snd
      local c2 = Store.put_item(full)
      if c2 then
        c = c2
        local KF = rawget(_G, "ForgeKinds")
        if KF and KF.register_all then pcall(KF.register_all) end
      end
      X.clear_drafts()
      d.soul, d.sound = c.soul, c.sound
    end
    if c and joker then
      local soul, snd = X.keep(d, c.id)
      local full = Store.copy(c)
      full.soul, full.sound = soul, snd
      full.anim = full.looks and anim or nil
      local c2 = Store.put(full)
      if c2 then
        c = c2
        FJ.register_all()
      end
      X.clear_drafts()
      d.soul, d.sound = c.soul, c.sound
      if c.anim then d.look_var, d.anim_fps = "anim", c.anim end
    end
    return c
  end

  local base_changed = B.art_changed
  B.art_changed = function(path, info)
    local r = base_changed(path, info)
    local d = B.state.draft
    if d and X.SOUL_KINDS[d.kind] and type(info) == "table" and info.kind == (B.PX_KIND and B.PX_KIND[d.kind] or "joker") then
      d.soul = info.soul and {file = X.DRAFT_SOUL} or nil
      B.dirty = true
    end
    return r
  end

  local base_preview = B.preview_center
  B.preview_center = function(...)
    local c = base_preview(...)
    local d = B.state.draft
    if not (c and d) then return c end
    X.apply(c, {soul = d.soul}, "forge_draft_soul")
    c.forge_stages = nil
    if d.look_var == "anim" then
      local all = {}
      for i, a in ipairs(Grow.all(d)) do all[i] = a end
      all[B.state.look_i or 1] = d.art or all[B.state.look_i or 1]
      if #all > 1 then
        local a1, p1 = Grow.atlas_for("forge_draft_l1", all[1])
        c.atlas, c.pos = a1 or "Joker", p1 or {x = 0, y = 0}
        local st = {}
        for i = 2, #all do
          local a, p = Grow.atlas_for("forge_draft_l" .. i, all[i])
          st[#st + 1] = {atlas = a or "Joker", pos = p or {x = 0, y = 0}}
        end
        c.forge_stages = st
        c.forge_anim = X.clean_anim(d.anim_fps) or X.FPS_DEF
      end
    end
    return c
  end

  local base_dc = B.draft_center
  if base_dc then
    B.draft_center = function(d, k)
      local c = base_dc(d, k)
      if c and d and d.kind ~= "joker" and X.SOUL_KINDS[d.kind] then
        X.apply(c, {soul = d.soul}, "forge_draft_soul")
        c.forge_sound, c.forge_anim = nil, nil
      end
      return c
    end
  end

  local function sync_soul(d)
    local f = fs()
    if not f then return end
    local s = X.clean_soul(d.soul)
    if s and s.file ~= X.DRAFT_SOUL and f.getInfo(s.file) then
      local raw = f.read(s.file)
      if raw then f.write(X.DRAFT_SOUL, raw) end
    elseif not s and f.getInfo(X.DRAFT_SOUL) then
      pcall(f.remove, X.DRAFT_SOUL)
    end
  end

  local base_art = G.FUNCS.forge_b_art
  G.FUNCS.forge_b_art = function(...)
    local d = B.state.draft
    if d and X.SOUL_KINDS[d.kind] then sync_soul(d) end
    return base_art(...)
  end

  G.FUNCS.forge_x_soul_draw = function()
    local d = B.state.draft
    if not (d and X.SOUL_KINDS[d.kind]) then return end
    G.FUNCS.forge_b_art()
    local PX = rawget(_G, "ForgePixelUI")
    local P = require("functions/forge/forge_pixel")
    local doc = PX and PX.doc
    if not doc then return end
    if P.count_role(doc, "soul") == 0 then
      P.add_layer(doc, "soul")
    else
      for i, l in ipairs(doc.layers) do if l.role == "soul" then doc.active = i end end
      P.relink(doc)
    end
    PX.sync_image()
    if PX.mode and PX.mode() ~= "advanced" then G.FUNCS.forge_px_mode({config = {ref_table = {mode = "advanced"}}}) end
    PX.state.panel = "layers"
    local JF = rawget(_G, "JokerForge")
    if JF and JF.ui then JF.ui.reopen("pixel") end
  end

  G.FUNCS.forge_x_soul_del = function()
    local d = B.state.draft
    if not d then return end
    d.soul = nil
    local f = fs()
    if f and f.getInfo(X.DRAFT_SOUL) then pcall(f.remove, X.DRAFT_SOUL) end
    B.dirty = true
    sfx("crumple1", 1, 0.4)
    reopen()
  end

  G.FUNCS.forge_x_sound_play = function()
    local d = B.state.draft
    if d then X.play(d.sound) end
  end

  local function file_picker()
    local ok, FP = pcall(require, "functions/file_picker")
    return ok and type(FP) == "table" and FP or nil
  end

  function X.ask_sound(note)
    local d = B.state.draft
    if not d then return end
    local function done()
      B.state.pick = nil
      B.dirty = true
      reopen()
    end
    local function take(name)
      local s, err = X.take_sound(name)
      if not s then return X.ask_sound(err) end
      d.sound = s
      X.play(s)
      done()
    end
    local opts = {{label = ml("No sound"), value = "none", colour = G.C.RED}}
    for _, name in ipairs(X.import_sounds()) do opts[#opts + 1] = {label = name, value = "f:" .. name, colour = G.C.GREEN} end
    local FP = file_picker()
    if FP and FP.browse_available() then opts[#opts + 1] = {label = ml("Pick a file"), value = "pick", colour = G.C.FILTER} end
    for _, s in ipairs(X.SOUNDS) do opts[#opts + 1] = {label = s[lang()] or s.en, value = "k:" .. s.k} end
    local notes = {ml("Your own sounds: .ogg, .wav or .mp3, 3 seconds and 64 KB at most, in forge/import.")}
    B.pick{title = ml("WHICH SOUND?"), note = note or notes[1], options = opts, choose = function(v)
      if v == "none" then
        d.sound = nil
        return done()
      end
      if v:sub(1, 2) == "k:" then
        d.sound = {key = v:sub(3)}
        X.play(d.sound)
        return done()
      end
      if v:sub(1, 2) == "f:" then return take(v:sub(3)) end
      if v == "pick" then
        ensure("forge")
        ensure(X.IMPORT_DIR)
        local dir = love.filesystem.getSaveDirectory() .. "/" .. X.IMPORT_DIR
        local started = FP.browse("audio", dir, X.MAX_SOUND, function(res)
          local name = res.added[1] or res.same[1]
          if name then return take(name) end
          if res.big[1] then return X.ask_sound(string.format(ml("%s is too big (64 KB at most)."), res.big[1])) end
          if res.wrong[1] then return X.ask_sound(string.format(ml("%s is not a sound the game can play."), res.wrong[1])) end
        end, ml("Sound"))
        if not started then return X.ask_sound(ml(FP.missing_text())) end
      end
    end}
  end

  G.FUNCS.forge_x_sound = function() X.ask_sound() end

  G.FUNCS.forge_x_ink = function()
    local d = B.state.draft
    if not d then return end
    pcall(X.ink_sync)
    B.state.art = {page = 1, ink = true}
    reopen()
  end

  function X.ink_use(it)
    local d = B.state.draft
    local f = fs()
    local raw = f and it and f.read(it.file)
    if not (d and raw) then return end
    Store.ensure_dirs()
    if f.write(B.DRAFT_ART, raw) then
      B.state.art_base = nil
      B.art_changed(B.DRAFT_ART)
    end
    B.state.art = nil
    B.dirty = true
    sfx("card1", 1.1, 0.5)
    reopen()
  end

  function X.item_buttons(d, bw, h)
    if not (d and d.kind ~= "joker" and X.SOUND_KINDS[d.kind]) then return nil end
    local UIK = rawget(_G, "UIK")
    local sc = UIK.touch() and 0.4 or 0.34
    local snd = string.format(ml("Sound: %s"), X.sound_label(d.sound))
    if not X.SOUL_KINDS[d.kind] then
      local l, s2 = B.wrap_label(snd, bw, sc)
      return UIK.button{label = l, button = "forge_x_sound", colour = UIK.C.accent, w = bw, h = h, scale = s2, col = true, id = "forge_x_sound"}
    end
    local hw = (bw - 0.1) / 2
    local l1, s1 = B.wrap_label(ml(X.clean_soul(d.soul) and "Soul: on" or "Add a soul"), hw, sc)
    local l2, s2 = B.wrap_label(snd, hw, sc)
    return K.hrow({
      UIK.button{label = l1, button = "forge_x_soul_draw", colour = UIK.C.purple, w = hw, h = h, scale = s1, col = true, id = "forge_x_soul_draw"},
      UIK.button{label = l2, button = "forge_x_sound", colour = UIK.C.accent, w = hw, h = h, scale = s2, col = true, id = "forge_x_sound"},
    }, bw, 0.1)
  end

  local base_body = B.looks_body
  B.looks_body = function(w)
    local nodes = base_body(w)
    local UIK = rawget(_G, "UIK")
    local d = B.state.draft
    if not (UIK and d) then return nodes end
    local touch = UIK.touch()
    nodes[#nodes + 1] = K.step_title(3, ml("SOUL AND SOUND"), w)
    local h = touch and 0.7 or 0.56
    local two = w >= (touch and 11 or 9.6)
    local fw = two and math.min((w - 0.3) / 2, touch and 6.4 or 5.6) or math.min(w, touch and 6.4 or 5.6)
    local bw = (math.min(fw - 0.1, touch and 4.4 or 4) - 0.1) / 2
    local sc = touch and 0.4 or 0.36
    local has = X.clean_soul(d.soul) ~= nil
    local l1, s1 = B.wrap_label(ml("Draw it"), bw, sc)
    local l2, s2 = B.wrap_label(ml("Remove"), bw, sc)
    local soul = K.hrow({
      UIK.button{label = l1, button = "forge_x_soul_draw", colour = UIK.C.purple, w = bw, h = h, scale = s1, col = true, id = "forge_x_soul_draw"},
      UIK.button{label = l2, button = "forge_x_soul_del", colour = G.C.RED, w = bw, h = h, scale = s2, col = true, id = "forge_x_soul_del", disabled = not has},
    }, bw * 2 + 0.1, 0.1)
    local name = X.sound_label(d.sound)
    local nw = bw * 2 + 0.1 - bw * 0.8 - 0.1
    local l3, s3 = B.wrap_label(name, nw, sc)
    local l4, s4 = B.wrap_label(ml("Listen"), bw * 0.8, sc)
    local snd = K.hrow({
      UIK.button{label = l3, button = "forge_x_sound", colour = UIK.C.accent, w = nw, h = h, scale = s3, col = true, id = "forge_x_sound"},
      UIK.button{label = l4, button = "forge_x_sound_play", colour = UIK.C.ok, w = bw * 0.8, h = h, scale = s4, col = true, id = "forge_x_sound_play", disabled = d.sound == nil},
    }, bw * 2 + 0.1, 0.1)
    local c1 = B.cell(ml("Floating soul"), soul, fw)
    local c2 = B.cell(ml("Sound"), snd, fw)
    if two then
      nodes[#nodes + 1] = K.hrow({c1, c2}, w, 0.2)
    else
      nodes[#nodes + 1] = K.hrow({c1}, w, 0.2)
      nodes[#nodes + 1] = K.hrow({c2}, w, 0.2)
    end
    nodes[#nodes + 1] = UIK.note({ml("The soul floats above the card like on Legendary Jokers. The sound plays when the Joker triggers.")}, {w = w - 0.2, scale = touch and 0.38 or 0.32})
    return nodes
  end
end

return X
