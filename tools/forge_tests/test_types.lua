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
  getDirectoryItems = function() return {} end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end
localize = function(x) return type(x) == "string" and x or "?" end

G = {
  P_CARDS = {}, P_CENTERS = {c_base = {key = "c_base"}}, P_CENTER_POOLS = {},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}}, SETTINGS = {language = "en-us"}, GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, poker_hands = {}, poker_hand_descriptions = {}, dictionary = {}}, descriptions = {}},
}
G.C.SET, G.C.SECONDARY_SET, G.C.UI = {}, {}, {TEXT_LIGHT = {1, 1, 1, 1}}
number_format = function(v) return tostring(v) end

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local D = require("functions/forge/forge_doc")
local Ty = require("functions/forge/forge_types")

check("kind: card type is a Forge kind", Cat.BY_ID.ctype ~= nil)
local f = Cat.clean_fields("ctype", {colour = "BLACK", shop = 0})
check("fields: kept", f.colour == "BLACK" and f.shop == 0)
local bad = Cat.clean_fields("ctype", {colour = "NOPE", shop = -5})
check("fields: bad colour falls back", bad.colour == "PURPLE")
check("fields: shop weight not below 0", bad.shop == 0, bad.shop)
check("labels: Normal for no type", Cat.value_label("ctype", "none") == "Normal")
check("tarot: Card type field", (function() for _, x in ipairs(Cat.BY_ID.tarot.fields) do if x.id == "ctype" then return true end end return false end)())
check("spectral: Card type field", (function() for _, x in ipairs(Cat.BY_ID.spectral.fields) do if x.id == "ctype" then return true end end return false end)())
check("tarot: default is Normal", Cat.default_fields("tarot").ctype == "none")
check("tarot: own type kept before it exists", Cat.clean_fields("tarot", {ctype = "type_forge_runes"}).ctype == "type_forge_runes")
check("tarot: junk type dropped", Cat.clean_fields("tarot", {ctype = "type_forge_a b"}).ctype == "none")
check("booster: own type kept", Cat.clean_fields("booster", {pack = "type_forge_runes"}).pack == "type_forge_runes")
check("booster: Arcana still fine", Cat.clean_fields("booster", {pack = "Arcana"}).pack == "Arcana")
check("effects: next Blind on Tarots", Cat.effect("tarot", "next_blind") ~= nil and Cat.effect("tarot", "next_boss_off") ~= nil)
check("effects: next Blind on Spectrals", Cat.effect("spectral", "next_blind") ~= nil)
check("effects: next Blind in Simple", Cat.effect("tarot", "next_blind").simple == true)

local runes = {id = "runes", kind = "ctype", name = "Runes", enabled = true, fields = {colour = "TEAL", shop = 3}}
local curses = {id = "curses", kind = "ctype", name = "Curses", enabled = true, fields = {colour = "BLACK", shop = 0}}
local list = Ty.assign({runes, curses, {id = "x", kind = "tarot"}})
check("assign: only card types, sorted", #list == 2 and list[1].id == "curses" and list[2].id == "runes")
local many = {}
for i = 1, 6 do many[i] = {id = "t" .. i, kind = "ctype", enabled = true} end
check("assign: at most 4", #Ty.assign(many) == Ty.MAX)
check("assign: disabled ones left out", #Ty.assign({{id = "a", kind = "ctype", enabled = false}}) == 0)
check("set key", Ty.set_key("runes") == "FType_runes" and Ty.rate_key("FType_runes") == "ftype_runes_rate")
check("colour: teal", math.abs(Ty.rgb(runes)[1] - 0x1d / 255) < 1e-6)

Store.list, Store.items_list = {}, {}
Store.put_item(runes)
Store.put_item(curses)
Store.put_item({id = "rhaga", kind = "tarot", name = "Hagalaz", fields = {ctype = "type_forge_runes", select = 0}, effects = {{id = "next_blind", n = 0.75}}})
Store.put_item({id = "curse1", kind = "spectral", name = "Hex Mark", fields = {ctype = "type_forge_curses"}, effects = {{id = "next_boss_off"}}})
Store.put_item({id = "rpack", kind = "booster", name = "Rune Pack", fields = {pack = "type_forge_runes", size = "Normal", cost = 4}})
local live_before = Store.live_items
Store.live_items = function() return Store.items() end
Ty.register()
check("register: two types", #Ty.list == 2)
check("register: pools", G.P_CENTER_POOLS.FType_runes ~= nil and G.P_CENTER_POOLS.FType_curses ~= nil)
check("register: colours", G.C.SECONDARY_SET.FType_runes ~= nil and G.C.SET.FType_curses ~= nil)
check("register: badge name", G.localization.misc.dictionary.k_ftype_runes == "Runes")
check("register: collection name", G.localization.misc.dictionary.b_ftype_curses_cards == "Curses")
check("set_of: Hagalaz is a Rune", Ty.set_of(Store.get_item("rhaga")) == "FType_runes")
check("set_of: plain Tarot has none", Ty.set_of({kind = "tarot", fields = {ctype = "none"}}) == nil)
check("set_of: missing type has none", Ty.set_of({kind = "tarot", fields = {ctype = "type_forge_gone"}}) == nil)
check("label: own type", Cat.value_label("ctype", "type_forge_runes") == "Runes")
check("values: types offered", (function() for _, v in ipairs(Cat.field_values(Cat.BY_ID.booster.fields[1])) do if v == "type_forge_curses" then return true end end return false end)())
check("doc: shop line", (function() for _, l in ipairs(D.lines(runes, "en")) do if l:find("weight") then return true end end return false end)())
check("doc: own packs only line", (function() for _, l in ipairs(D.lines(curses, "en")) do if l:find("own packs") then return true end end return false end)())
check("doc: Rune pack line", (function() for _, l in ipairs(D.lines(Store.get_item("rpack"), "en")) do if l:find("Runes") then return true end end return false end)())

G.P_CENTER_POOLS.FType_runes = {{key = "c_forge_rhaga", forge_kind = "tarot"}}
G.P_CENTER_POOLS.FType_curses = {{key = "c_forge_curse1", forge_kind = "spectral"}}
G.GAME = {probabilities = {normal = 1}}
Ty.ensure_rates()
check("rates: Runes 3", G.GAME.ftype_runes_rate == 3)
check("rates: Curses 0 (own packs only)", G.GAME.ftype_curses_rate == 0)
check("pick: always Runes", Ty.pick(0) == Ty.by_id.runes and Ty.pick(0.99) == Ty.by_id.runes)
local _, weight = Ty.pick(0.5)
check("pick: weight 3", weight == 3)
G.P_CENTER_POOLS.FType_runes = {}
Ty.ensure_rates()
check("rates: no cards means 0", G.GAME.ftype_runes_rate == 0)
check("pick: nothing without cards", Ty.pick(0.5) == nil)

G.GAME.joker_rate, G.GAME.tarot_rate, G.GAME.planet_rate, G.GAME.playing_card_rate, G.GAME.spectral_rate = 20, 4, 4, 0, 0
G.GAME.ftype_tdx_rate = 99
check("base rate: vanilla weights only", Ty.base_rate() == 28, Ty.base_rate())
G.GAME.ftype_runes_rate = 3
local seen
Ty.without_rates(function() seen = G.GAME.ftype_runes_rate end)
check("roll without own weights", seen == 0 and G.GAME.ftype_runes_rate == 3, seen)

local events = {}
G.E_MANAGER = {add_event = function(_, e) events[#events + 1] = e end}
Event = function(t) return t end
G.GAME.forge_next_blind = 0.75
local blind = {chips = 300, boss = false}
Ty.next_blind(blind, false)
check("next blind: 300 becomes 225", blind.chips == 225 and blind.chip_text == "225")
check("next blind: used once", G.GAME.forge_next_blind == nil)
Ty.next_blind(blind, false)
check("next blind: second blind untouched", blind.chips == 225)
G.GAME.forge_next_blind = 0.5
Ty.next_blind(blind, true)
check("next blind: loading a save does not use it", blind.chips == 225 and G.GAME.forge_next_blind == 0.5)
G.GAME.forge_next_blind = nil
G.GAME.forge_next_boss_off = true
Ty.next_blind({chips = 100, boss = false}, false)
check("boss off: waits for a boss", G.GAME.forge_next_boss_off == true and #events == 0)
Ty.next_blind({chips = 100, boss = true}, false)
check("boss off: disables the boss", G.GAME.forge_next_boss_off == nil and #events == 1)

local Mods = require("functions/forge/forge_mods")
check("share: card type needs 16", Mods.needs_v({}, {runes}) == 16)
check("share: a Rune needs 16", Mods.needs_v({}, {Store.get_item("rhaga")}) == 16)
check("share: Rune pack needs 16", Mods.needs_v({}, {Store.get_item("rpack")}) == 16)
check("share: a plain Tarot stays low", Mods.needs_v({}, {{id = "pt", kind = "tarot", name = "P", fields = {cost = 3}, effects = {{id = "money", n = 5}}}}) < 16)
local raw = Mods.pack({name = "Runes"}, {"runes", "rhaga", "rpack"})
local mod = raw and Mods.parse(raw)
local mt, mr, mb
for _, c in ipairs(mod and mod.creations or {}) do
  if c.kind == "ctype" then mt = c end
  if c.kind == "tarot" then mr = c end
  if c.kind == "booster" then mb = c end
end
check("mods: type, Rune and pack travel together", mt and mr and mb and mr.fields.ctype == "type_forge_" .. mt.id and mb.fields.pack == "type_forge_" .. mt.id, mr and mr.fields.ctype)
check("mods: Rune keeps its effect", mr and mr.effects[1] and mr.effects[1].id == "next_blind" and mr.effects[1].n == 0.75)

Store.live_items = function() return {} end
Ty.register()
check("register: removed types leave the list", #Ty.list == 0 and Ty.set_of(Store.get_item("rhaga")) == nil)
Store.live_items = live_before

print(string.format("forge types: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
