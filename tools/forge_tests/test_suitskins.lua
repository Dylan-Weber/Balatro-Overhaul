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
  P_CARDS = {},
  P_CENTERS = {c_base = {key = "c_base"}},
  P_CENTER_POOLS = {},
  C = {SUITS = {}, SO_1 = {}, SO_2 = {}},
  SETTINGS = {language = "en-us"},
  GAME = {probabilities = {normal = 1}},
  localization = {misc = {suits_plural = {}, suits_singular = {}, dictionary = {}}, descriptions = {Other = {}}},
}
local Store = require("functions/forge/forge_store")
local S = require("functions/forge/forge_suits")
local SK = require("functions/forge/forge_suitskins")
G.FUNCS = G.FUNCS or {}
local M = require("functions/forge/forge_kinds_more")
G.COLLABS = {pos = {Jack = {x = 0, y = 0}, Queen = {x = 1, y = 0}, King = {x = 2, y = 0}}, options = {Spades = {"default", "collab_TW"}, Hearts = {"default"}}}
G.SETTINGS.CUSTOM_DECK = {Collabs = {Spades = "default"}}
G.localization.misc.collabs = {Spades = {["1"] = "Default", ["2"] = "The Witcher"}}
G.ASSET_ATLAS = {}
SK.hooked = true

Store.put_item({id = "stars", kind = "suit", name = "Stars", enabled = true, fields = {}})
Store.put_item({id = "moons", kind = "suit", name = "Moons", enabled = true, fields = {}})
S.set_list(S.assign(Store.live_items()))
local stars = S.of_id("stars")
check("two own suits", #S.list == 2 and stars ~= nil)

local regs = 0
M.register_collabs = function() regs = regs + 1 end
SK.sync()
check("options: own suit gets a list", type(G.COLLABS.options[stars.key]) == "table")
check("options: Default first", G.COLLABS.options[stars.key][1] == "default", G.COLLABS.options[stars.key][1])
check("names: Default", G.localization.misc.collabs[stars.key]["1"] == "Default")
check("collabs registered again after suits", regs == 1)
check("vanilla lists untouched", #G.COLLABS.options.Spades == 2 and G.COLLABS.options.Spades[1] == "default")
G.COLLABS.options[stars.key][2] = "collab_forge_sc"
G.SETTINGS.CUSTOM_DECK.Collabs[stars.key] = "collab_forge_sc"
SK.sync()
check("sync keeps an existing choice and list", G.COLLABS.options[stars.key][1] == "default" and #G.COLLABS.options[stars.key] == 2)
check("no duplicate Default", (function() local n = 0 for _, v in ipairs(G.COLLABS.options[stars.key]) do if v == "default" then n = n + 1 end end return n == 1 end)())

table.remove(G.COLLABS.options[stars.key], 2)
SK.fix_choices()
check("choice of a gone collab falls back to Default", G.SETTINGS.CUSTOM_DECK.Collabs[stars.key] == "default", G.SETTINGS.CUSTOM_DECK.Collabs[stars.key])

local mk = stars.key
Store.delete_item("moons")
local moonskey = S.of_id("moons").key
S.set_list(S.assign(Store.live_items()))
SK.sync()
check("deleted suit leaves Customize Deck", G.COLLABS.options[moonskey] == nil and G.COLLABS.options[mk] ~= nil)

local Cat = require("functions/forge/forge_catalog")
local cf = Cat.clean_fields("collab", {suit = "suit_forge_stars"})
check("collab field keeps an own suit", cf.suit == "suit_forge_stars", cf.suit)
check("collab own suit maps to the game suit", M.collab_suit({kind = "collab", fields = {suit = "suit_forge_stars"}}) == mk, M.collab_suit({kind = "collab", fields = {suit = "suit_forge_stars"}}))
check("collab vanilla suit unchanged", M.collab_suit({kind = "collab", fields = {suit = "Spades"}}) == "Spades")
check("collab on an own suit needs 16", Cat.need_v({id = "x", kind = "collab", name = "X", fields = {suit = "suit_forge_stars"}}) == 16)

SMODS = {DeckSkins = {}, DeckSkin = {obj_buffer = {"default_Spades"}}}
SMODS.DeckSkins.default_Spades = {key = "default_Spades", suit = "Spades"}
localize = function(x) if x == "b_deckskins_lc" then return "Low" end if x == "b_deckskins_hc" then return "High" end return type(x) == "string" and x or "?" end
G.COLLABS.options.Spades[3] = "collab_forge_jc"
Store.put_item({id = "jc", kind = "collab", name = "Jimbo Court", enabled = true, fields = {suit = "Spades"}})
SK.sync()
local def = SMODS.DeckSkins["default_" .. mk]
check("smods: own suit default skin", def and def.forge_skin and def.suit == mk and def.palettes[1].atlas == S.atlas_key(stars) and def.palettes[1].pos_style == "deck")
check("smods: own suit options start with its default skin", G.COLLABS.options[mk][1] == "default_" .. mk, G.COLLABS.options[mk][1])
local jc = SMODS.DeckSkins.collab_forge_jc
check("smods: Forge collab is a deck skin", jc and jc.suit == "Spades" and jc.palettes[1].atlas == "collab_forge_jc_1" and jc.palettes[2].atlas == "collab_forge_jc_2" and jc.palette_map.hc ~= nil)
check("smods: palettes listed", G.COLLABS.colour_palettes and G.COLLABS.colour_palettes.collab_forge_jc[2] == "hc")
check("smods: names", G.localization.misc.collabs.Spades.collab_forge_jc == "Jimbo Court" and G.localization.misc.collab_palettes.collab_forge_jc[1] == "Low" and G.localization.misc.collab_palettes.collab_forge_jc["2"] == "High")
check("smods: vanilla skins untouched", SMODS.DeckSkins.default_Spades and not SMODS.DeckSkins.default_Spades.forge_skin)
check("smods: own suit choice set to its default", G.SETTINGS.CUSTOM_DECK.Collabs[mk] == "default_" .. mk, G.SETTINGS.CUSTOM_DECK.Collabs[mk])
local nbuf = #SMODS.DeckSkin.obj_buffer
G.COLLABS.options.Spades[3] = nil
SK.sync()
check("smods: removed collab skin gone", SMODS.DeckSkins.collab_forge_jc == nil and #SMODS.DeckSkin.obj_buffer == nbuf - 1, #SMODS.DeckSkin.obj_buffer)
SMODS = nil

print(string.format("suitskins: %d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
