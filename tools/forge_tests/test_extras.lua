package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, extra)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "")) end
end

local files, dirs = {}, {forge = true, ["forge/art"] = true}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end if dirs[p] then return {type = "directory"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function(p) dirs[p] = true return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function(dir)
    local out = {}
    for p in pairs(files) do
      local name = p:match("^" .. dir:gsub("%p", "%%%0") .. "/([^/]+)$")
      if name then out[#out + 1] = name end
    end
    return out
  end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end

local events = {}
Event = function(t) return t end
G = {
  P_CENTERS = {
    j_joker = {key = "j_joker", set = "Joker", name = "Joker", discovered = true, config = {}},
    j_baron = {key = "j_baron", set = "Joker", name = "Baron", discovered = true, config = {}},
    j_blueprint = {key = "j_blueprint", set = "Joker", name = "Blueprint", discovered = false, config = {}},
    j_cry_mod = {key = "j_cry_mod", set = "Joker", name = "Mod Joker", discovered = true, config = {}},
    c_fool = {key = "c_fool", set = "Tarot", name = "The Fool", config = {}},
  },
  P_CENTER_POOLS = {Joker = {}},
  C = {FILTER = {1, 1, 1, 1}, GREEN = {0, 1, 0, 1}, SECONDARY_SET = {Spectral = {0, 0, 1, 1}}},
  SETTINGS = {language = "en-us"},
  GAME = {probabilities = {normal = 1}, round_resets = {ante = 1}},
  E_MANAGER = {add_event = function(_, e) events[#events + 1] = e end},
  ASSET_ATLAS = {Joker = {name = "Joker", px = 71, py = 95}, forge_g1 = {name = "forge_g1", px = 71, py = 95}},
  CARD_W = 2, CARD_H = 3,
}
for _, k in ipairs({"j_joker", "j_baron", "j_blueprint", "j_cry_mod"}) do G.P_CENTER_POOLS.Joker[#G.P_CENTER_POOLS.Joker + 1] = G.P_CENTERS[k] end
local statuses = {}
card_eval_status_text = function(card, kind, a, b, c, t) statuses[#statuses + 1] = t and t.message end
localize = function(x) return type(x) == "string" and x or "?" end
local rolls = 0
pseudoseed = function(s) return s end
pseudorandom = function() rolls = rolls + 1 return 0.5 end
local pool_args
get_current_pool = function(t, rarity, legendary, append)
  pool_args = {t = t, rarity = rarity, legendary = legendary, append = append}
  if legendary then return {"UNAVAILABLE", "j_cry_mod"}, "Joker4" end
  if rarity and rarity > 0.95 then return {"j_baron", "UNAVAILABLE", "j_blueprint"}, "Joker3" end
  return {"j_joker"}, "Joker1"
end
discover_card = function(c) c.discovered = true end
play_sound = function() end

local Store = require("functions/forge/forge_store")
local Mods = require("functions/forge/forge_mods")
local FJ = require("functions/forge/forge_joker")
local Room = require("functions/forge/forge_room")
local Grow = require("functions/forge/forge_grow")
local X = require("functions/forge/forge_extras")
local json = require("bot.sim.json")

local function png(tag)
  local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
  return "\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(71) .. u32(95) .. "\8\6\0\0\0" .. tag .. string.rep("\0\255\1", 30)
end
local function ogg(tag) return "OggS" .. string.rep("\0", 24) .. tag .. string.rep("\1", 200) end
local function wav(tag) return "RIFF\36\0\0\0WAVEfmt " .. tag .. string.rep("\0", 100) end

check("format 17", X.V == 17 and Mods.V == 17 and Room.V == 17)
check("clean soul", X.clean_soul({file = "forge/art/a1_soul.png"}).file == "forge/art/a1_soul.png" and X.clean_soul({file = "../x.png"}) == nil and X.clean_soul("x") == nil)
check("clean anim", X.clean_anim(6) == 6 and X.clean_anim(0) == nil and X.clean_anim(13) == nil and X.clean_anim("4") == 4 and X.clean_anim(2.7) == 2)
check("clean sound key", X.clean_sound({key = "gong"}).key == "gong" and X.clean_sound({key = "music1"}) == nil and X.clean_sound({key = "../x"}) == nil)
check("clean sound file", X.clean_sound({file = "forge/sound/a1.ogg"}).file == "forge/sound/a1.ogg" and X.clean_sound({file = "forge/sound/a1.exe"}) == nil and X.clean_sound({file = "forge/art/a1.ogg"}) == nil)
check("magic", X.magic(ogg("a")) == "ogg" and X.magic(wav("a")) == "wav" and X.magic("ID3" .. string.rep("\0", 20)) == "mp3" and X.magic(png("a")) == nil and X.magic("") == nil)
check("sound size limit", X.check_sound(ogg("a")) == "ogg" and select(2, X.check_sound("OggS" .. string.rep("x", X.MAX_SOUND))) == "big" and select(2, X.check_sound(png("x"))) == "bad")
check("sound label", X.sound_label(nil) == "No sound" and X.sound_label({key = "gong"}) == "Gong" and X.sound_label({file = "forge/sound/a.ogg"}) == "Your sound")

local sc = Store.clean({id = "ex1", name = "Extra", soul = {file = "forge/art/ex1_soul.png"}, anim = 8, sound = {key = "chips1"}})
check("store keeps extras", sc.soul and sc.soul.file == "forge/art/ex1_soul.png" and sc.anim == 8 and sc.sound.key == "chips1")
local old = Store.clean({id = "ex0", name = "Old"})
check("old joker has no extras", old.soul == nil and old.anim == nil and old.sound == nil)

check("need: plain joker stays old", Mods.needs_v({{id = "a", rules = {}}}, {}) < 17)
check("need: looks alone stay 16", Mods.needs_v({{id = "a", rules = {}, looks = {{atlas = "Joker", x = 1, y = 0}}}}, {}) == 16)
check("need: soul is 17", Mods.needs_v({{id = "a", rules = {}, soul = {file = "forge/art/a_soul.png"}}}, {}) == 17)
check("need: animation is 17", Mods.needs_v({{id = "a", rules = {}, anim = 4}}, {}) == 17)
check("need: sound is 17", Mods.needs_v({{id = "a", rules = {}, sound = {key = "gong"}}}, {}) == 17)

Store.list, Store.items_list = {}, {}
files["forge/art/ex1.png"] = png("A")
files["forge/art/ex1_l2.png"] = png("B")
files["forge/art/ex1_soul.png"] = png("S")
files["forge/sound/ex1.ogg"] = ogg("Z")
Store.put({id = "ex1", name = "Dancer", rarity = 2, cost = 5, art = {file = "forge/art/ex1.png"}, looks = {{file = "forge/art/ex1_l2.png"}}, anim = 6,
  soul = {file = "forge/art/ex1_soul.png"}, sound = {file = "forge/sound/ex1.ogg"}, rules = {{when = "hand_played", give = {{id = "mult", n = 4}}}}})
Store.put({id = "ex2", name = "Gonger", rarity = 1, cost = 4, sound = {key = "gong"}, rules = {{when = "hand_played", give = {{id = "chips", n = 10}}}}})
local raw, out = Mods.pack({name = "Extras"}, {"ex1", "ex2"})
check("mods: pack is 17", type(raw) == "string" and out.v == 17, out)
check("mods: soul file packed", out and out.files and out.files.ex1_soul ~= nil and out.files.ex1_l2 ~= nil)
check("mods: sound packed apart from pictures", out and out.sounds and out.sounds.ex1 ~= nil and (out.files or {}).ex1 ~= nil and out.files.ex1 ~= out.sounds.ex1)
local mod = Mods.parse(raw)
local mj, mg
for _, j in ipairs(mod and mod.jokers or {}) do if j.src == "ex1" then mj = j elseif j.src == "ex2" then mg = j end end
check("mods: soul remapped", mj and mj.soul and mj.soul.file == Mods.art_path(mod.id, "ex1_soul"), mj and mj.soul and mj.soul.file)
check("mods: sound remapped", mj and mj.sound and mj.sound.file == X.mod_sound_path(mod.id, "ex1", "ogg"), mj and mj.sound and mj.sound.file)
check("mods: animation kept", mj and mj.anim == 6 and mj.looks and #mj.looks == 1)
check("mods: game sound kept", mg and mg.sound and mg.sound.key == "gong")
local m = Mods.install(raw)
check("mods: install writes the sound", m and files[X.mod_sound_path(m.id, "ex1", "ogg")] == files["forge/sound/ex1.ogg"])
check("mods: install writes the soul", m and files[Mods.art_path(m.id, "ex1_soul")] == files["forge/art/ex1_soul.png"])
local t = json.decode(raw)
t.sounds.ex1 = Mods.b64_encode(png("P"))
local bad = Mods.parse(json.encode(t))
local bj
for _, j in ipairs(bad and bad.jokers or {}) do if j.src == "ex1" then bj = j end end
check("mods: a picture is not a sound", bj and bj.sound == nil and bj.soul ~= nil)
t = json.decode(raw)
t.v = 18
check("mods: newer refused", select(2, Mods.parse(json.encode(t))) == "newer")
check("mods: format 16 still loads", Mods.parse(json.encode({format = "forgemod", v = 16, id = "old16", name = "Old", jokers = {{id = "o1", name = "Old", rules = {{when = "hand_played", give = {{id = "mult", n = 4}}}}}}})) ~= nil)
files["forge/sound/ex1.ogg"] = "junk junk junk"
local raw3, out3 = Mods.pack({name = "Extras"}, {"ex1"})
check("mods: broken sound left out", raw3 and out3.sounds == nil and out3.jokers[1].sound == nil)
files["forge/sound/ex1.ogg"] = ogg("Z")

Mods.list = {}
local rraw, rinfo = Room.pack()
local rt = rraw and json.decode(rraw)
check("room: pack is 17", rt and rt.room == 17 and rt.v == 17, rt and rt.room)
check("room: soul and sound travel", rt and rt.files and rt.files.r01S ~= nil and rt.sounds and rt.sounds.r01snd ~= nil)
check("room: enter", Room.enter(rraw) == true)
local rj = Store.get("mproom01")
check("room: soul arrives", rj and rj.soul and rj.soul.file == "forge/art/fm_mproom_r01S.png" and files["forge/art/fm_mproom_r01S.png"] == files["forge/art/ex1_soul.png"], rj and rj.soul and rj.soul.file)
check("room: sound arrives", rj and rj.sound and rj.sound.file == "forge/sound/fm_mproom_r01snd.ogg" and files["forge/sound/fm_mproom_r01snd.ogg"] == files["forge/sound/ex1.ogg"], rj and rj.sound and rj.sound.file)
check("room: game sound arrives", Store.get("mproom02") and Store.get("mproom02").sound.key == "gong")
Room.leave()
check("room: leave cleans sounds", files["forge/sound/fm_mproom_r01snd.ogg"] == nil)
local tiny = Room.pack(400 + #Mods.b64_encode(files["forge/art/ex1.png"]) * 3)
local tt = tiny and json.decode(tiny)
check("room: sound dropped when the room is full", tt == nil or tt.sounds == nil)

local dup = Store.duplicate("ex1")
check("store: copy has its own soul and sound", dup and dup.soul and dup.soul.file ~= "forge/art/ex1_soul.png" and files[dup.soul.file] == files["forge/art/ex1_soul.png"] and dup.sound.file == "forge/sound/" .. dup.id .. ".ogg" and files[dup.sound.file] ~= nil)
local ds, dsn = dup.soul.file, dup.sound.file
Store.delete(dup.id)
check("store: delete removes soul and sound", files[ds] == nil and files[dsn] == nil and files["forge/art/ex1_soul.png"] ~= nil)

FJ.atlas_from_data = function(name) G.ASSET_ATLAS[name] = {name = name, px = 71, py = 95} return G.ASSET_ATLAS[name] end
love.image = {newImageData = function(p) if not files[p] then error("no file") end return {getWidth = function() return 71 end, getHeight = function() return 95 end, getDimensions = function() return 71, 95 end} end}
local cen = FJ.center_for(Store.get("ex1"), 1)
check("center: soul layer", cen.soul_pos and cen.soul_pos.x == 0 and cen.forge_soul_atlas == "forge_ex1_soul" and G.ASSET_ATLAS.forge_ex1_soul ~= nil)
check("center: animation and sound", cen.forge_anim == 6 and cen.forge_stages and #cen.forge_stages == 1 and cen.forge_sound.file == "forge/sound/ex1.ogg")
local plain = FJ.center_for(Store.get("ex2"), 2)
check("center: plain has no soul or animation", plain.soul_pos == nil and plain.forge_anim == nil and plain.forge_sound.key == "gong")
local c1 = Store.copy(Store.get("ex1"))
c1.soul, c1.anim = nil, nil
Store.put(c1)
local cen2 = FJ.center_for(Store.get("ex1"), 1)
check("center: soul removed again", cen2.soul_pos == nil and cen2.forge_soul_atlas == nil and cen2.forge_anim == nil)
c1.anim = 4
Store.put(c1)
FJ.center_for(Store.get("ex1"), 1)

package.loaded["overhaul.hooks"] = {wrap = function(owner, key, make) local t = type(owner) == "string" and rawget(_G, owner) or owner if type(t) == "table" then t[key] = make(t[key] or function() end) end end}
local CardT = {set_sprites = function() end, calculate_joker = function(_, ctx) return ctx.r end}
rawset(_G, "Card", CardT)
X.hooked = nil
X.install()
G.TIMERS = {REAL = 0}
local card = {config = {center = G.P_CENTERS["j_forge_ex1"]}, ability = {extra = {}}}
local seen = {}
for i = 0, 7 do G.TIMERS.REAL = i * 0.25 + 0.01 seen[#seen + 1] = Grow.stage_of(card) end
check("animation steps through the looks", table.concat(seen, ",") == "1,2,1,2,1,2,1,2", table.concat(seen, ","))
local fl = {set_sprite_pos = function(self, p) self.pos = p end}
local sc2 = {config = {center = {forge_soul_atlas = "forge_ex1_soul"}}, children = {floating_sprite = fl}}
X.fix_soul(sc2)
check("soul sprite uses the soul atlas", fl.atlas == G.ASSET_ATLAS.forge_ex1_soul and fl.pos.x == 0)

X.played = {}
local gc = {config = {center = {forge = true, forge_sound = {key = "gong"}}}}
local before = #events
CardT.calculate_joker(gc, {r = {mult_mod = 4}})
CardT.calculate_joker(gc, {r = nil})
check("sound queued once when the Joker triggers", #events == before + 1)
if events[#events] and events[#events].func then events[#events].func() end
check("sound played", X.played[1] == "gong", X.played[1])
love.timer = {getTime = function() return 100 end}
gc.forge_sound_t = 99.95
CardT.calculate_joker(gc, {r = {mult_mod = 4}})
check("sound not spammed", #events == before + 1)
gc.forge_preview = true
gc.forge_sound_t = nil
CardT.calculate_joker(gc, {r = {mult_mod = 4}})
check("builder preview stays quiet", #events == before + 1)


local it = Store.clean_item({id = "it1", kind = "tarot", name = "Bell", soul = {file = "forge/art/it1_soul.png"}, sound = {key = "gong"}})
check("items: tarot keeps soul and sound", it and it.soul and it.soul.file == "forge/art/it1_soul.png" and it.sound.key == "gong")
local is = Store.clean_item({id = "it2", kind = "seal", name = "Moon", soul = {file = "forge/art/it2_soul.png"}, sound = {key = "coin3"}, effects = {{id = "scored_money", n = 3}}})
check("items: seal has a sound but no soul", is and is.soul == nil and is.sound and is.sound.key == "coin3")
local ih = Store.clean_item({id = "it3", kind = "hand", name = "Big", sound = {key = "gong"}})
check("items: kinds without a card keep neither", ih == nil or (ih.sound == nil and ih.soul == nil))
check("need: creation with sound is 17", Mods.needs_v({}, {it}) == 17)
Store.put_item({id = "it2", kind = "seal", name = "Moon", sound = {key = "coin3"}, effects = {{id = "scored_money", n = 3}}})
Store.put_item({id = "it4", kind = "tag", name = "Ring", sound = {key = "gong"}, effects = {{id = "money", n = 2}}})
check("sound found from a seal, tag and blind key", X.sound_of_key("Forge_it2").key == "coin3" and X.sound_of_key("tag_forge_it4").key == "gong" and X.sound_of_key("bl_forge_none") == nil and X.sound_of_key("c_base") == nil)
check("ink names are safe", X.ink_safe("ace-fire 2.png") == "ace_fire_2" and X.ink_safe("../x.PNG") == "___x")
dirs["forge/inkjoker"] = true
files["forge/inkjoker/b_one.png"] = png("I")
files["forge/inkjoker/a_two.png"] = png("J")
files["forge/inkjoker/notes.txt"] = "x"
local il = X.ink_list()
check("ink list sorted pictures only", #il == 2 and il[1].file == "forge/inkjoker/a_two.png" and il[2].ink == true)

print(string.format("forge extras: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
