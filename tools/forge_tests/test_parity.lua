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

G = {P_JOKER_RARITY_POOLS = {{}, {}, {}, {}},
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
local Bal = require("functions/forge/forge_balance")
local SP = require("functions/forge/forge_startpack")
local Run = require("functions/forge/forge_run")
local Bal = require("functions/forge/forge_balance")
local P = require("functions/forge/forge_parity")
local Mods = require("functions/forge/forge_mods")

check("share format is 17", Mods.V == 17 and P.V == 17)
for _, id in ipairs({"chance", "last_used", "suit_random_all", "rank_random_all", "copy_joker", "destroy_others", "joker_edition"}) do
  check("tarot offers " .. id, Cat.effect("tarot", id) ~= nil)
  check("spectral offers " .. id, Cat.effect("spectral", id) ~= nil)
end
for _, k in ipairs({"deck", "challenge", "stake"}) do check(k .. " offers Balance", Cat.effect(k, "balance") ~= nil) end
check("deck offers Random ranks and suits", Cat.effect("deck", "erratic") ~= nil)
check("Boss Blinds do not get Balance", Cat.effect("blind", "balance") == nil)
check("Tags keep the plain edition list", Cat.effect("tag", "joker_edition").v == "shader")
check("random edition offered first", Cat.values("jedition")[1] == "random" and Cat.values("jedition")[2] ~= nil)
check("random edition label", Cat.value_label("jedition", "random") == "Foil, Holographic or Polychrome")
check("plain edition label kept", Cat.value_label("jedition", "polychrome") == Cat.value_label("shader", "polychrome"))

local function item(x) return Store.clean_item(x) end
local fool = item({id = "fool", kind = "tarot", name = "Fool", fields = {cost = 3, select = 0}, effects = {{id = "last_used"}}})
local wheel = item({id = "wheel", kind = "tarot", name = "Wheel", fields = {cost = 3, select = 0}, effects = {{id = "chance", n = 4}, {id = "joker_edition", v = "random"}}})
local hex = item({id = "hex", kind = "spectral", name = "Hex", fields = {cost = 4, select = 0}, effects = {{id = "joker_edition", v = "polychrome"}, {id = "destroy_others"}}})
local ankh = item({id = "ankh", kind = "spectral", name = "Ankh", fields = {cost = 4, select = 0}, effects = {{id = "copy_joker"}, {id = "destroy_others"}}})
local sigil = item({id = "sigil", kind = "spectral", name = "Sigil", fields = {cost = 4, select = 0}, effects = {{id = "suit_random_all"}}})
local ouija = item({id = "ouija", kind = "spectral", name = "Ouija", fields = {cost = 4, select = 0}, effects = {{id = "rank_random_all"}, {id = "hand_size_minus"}}})
local plasma = item({id = "plasma", kind = "deck", name = "Plasma", effects = {{id = "balance"}, {id = "blind_size", n = 2}}})
local erratic = item({id = "erratic", kind = "deck", name = "Erratic", effects = {{id = "erratic"}}})
local small = item({id = "smallb", kind = "blind", name = "Small", fields = {shows_as = "small", size = 1, reward = 3}, effects = {}})
local big = item({id = "bigb", kind = "blind", name = "Big", fields = {shows_as = "big", size = 1.5, reward = 4}, effects = {}})
local boss = item({id = "bossb", kind = "blind", name = "Wall", fields = {size = 4, reward = 5}, effects = {}})

check("Fool kept", fool.effects[1] and fool.effects[1].id == "last_used")
check("Wheel kept", wheel.effects[1].id == "chance" and wheel.effects[1].n == 4 and wheel.effects[2].v == "random", wheel.effects[2] and wheel.effects[2].v)
check("Hex kept", hex.effects[1].v == "polychrome" and hex.effects[2].id == "destroy_others")
check("Ankh kept", ankh.effects[1].id == "copy_joker" and ankh.effects[2].id == "destroy_others")
check("Ouija kept", ouija.effects[1].id == "rank_random_all" and ouija.effects[2].id == "hand_size_minus")
check("Plasma kept", plasma.effects[1].id == "balance" and plasma.effects[2].id == "blind_size" and plasma.effects[2].n == 2, plasma.effects[2] and plasma.effects[2].n)
check("Small Blind slot kept", small.fields.shows_as == "small" and tonumber(small.fields.size) == 1 and tonumber(small.fields.reward) == 3)
check("Big Blind slot kept", big.fields.shows_as == "big" and tonumber(big.fields.size) == 1.5)
check("bad slot falls back", item({id = "bb", kind = "blind", name = "B", fields = {shows_as = "huge"}, effects = {}}).fields.shows_as ~= "huge")

for _, c in ipairs({fool, wheel, hex, ankh, sigil, ouija, plasma, erratic, small, big}) do check(c.name .. " needs format 17", Cat.need_v(c) == 17, Cat.need_v(c)) end
check("boss blind stays older", Cat.need_v(boss) < 17, Cat.need_v(boss))
local aura = item({id = "aura", kind = "spectral", name = "Aura", fields = {select = 0}, effects = {{id = "joker_edition", v = "foil"}}})
check("older spectral edition stays older", Cat.need_v(aura) < 17, Cat.need_v(aura))
check("mods export needs 17", Mods.needs_v({}, {wheel}) == 17)

local function txt(c) return table.concat(D.lines(c, "en"), " ") end
check("Wheel text", txt(wheel):find("1 in 4", 1, true) and txt(wheel):find("Foil, Holographic or Polychrome", 1, true), txt(wheel))
check("Fool text", txt(fool):find("last", 1, true) ~= nil, txt(fool))
check("Plasma text", txt(plasma):find("Balances", 1, true) ~= nil, txt(plasma))

for _, c in ipairs({fool, wheel, hex, ankh, sigil, ouija, plasma, erratic, small, big}) do
  local s = Bal.of(c)
  check(c.name .. " rated", s and s.level ~= nil, s and s.level)
end
local sure = item({id = "sure", kind = "tarot", name = "Sure", fields = {select = 0}, effects = {{id = "joker_edition", v = "random"}}})
check("chance lowers the rating", Bal.of(wheel).score < Bal.of(sure).score, Bal.of(wheel).score .. " " .. Bal.of(sure).score)
check("Plasma rated above nothing", Bal.of(item({id = "pl2", kind = "deck", name = "P", effects = {{id = "balance"}}})).score > Bal.of(item({id = "pl3", kind = "deck", name = "N", effects = {}})).score)

G.STATES = {SELECTING_HAND = 1, SHOP = 2, TAROT_PACK = 3, SPECTRAL_PACK = 4, PLANET_PACK = 5, STANDARD_PACK = 6, BUFFOON_PACK = 7}
G.STATE = 2
local function J(ed) return {ability = {set = "Joker"}, edition = ed} end
G.jokers = {cards = {}, config = {card_limit = 5}}
G.consumeables = {cards = {}, config = {card_limit = 2}}
G.hand = {cards = {}}
G.GAME.last_tarot_planet = nil
check("Wheel needs a Joker without edition", P.can_use(wheel) == false)
G.jokers.cards = {J({foil = true})}
check("Wheel blocked when every Joker has an edition", P.can_use(wheel) == false)
G.jokers.cards[2] = J(nil)
check("Wheel usable", P.can_use(wheel) == true)
check("Hex usable", P.can_use(hex) == true)
check("Ankh usable with room", P.can_use(ankh) == true and P.no_space(ankh) == false)
for i = 3, 5 do G.jokers.cards[i] = J(nil) end
check("Ankh with full slots is usable and says No space like vanilla", P.can_use(ankh) == true and P.no_space(ankh) == true)
G.jokers.cards[5] = nil
check("Ankh with a free slot has space", P.no_space(ankh) == false)
G.jokers.cards[5] = J(nil)
G.jokers.cards = {}
check("Ankh needs a Joker", P.can_use(ankh) == false)
check("Fool needs a last card", P.can_use(fool) == false)
G.P_CENTERS.c_star = {key = "c_star", set = "Tarot"}
G.P_CENTERS.c_fool = {key = "c_fool", set = "Tarot"}
G.GAME.last_tarot_planet = "c_star"
check("Fool usable after a Tarot", P.can_use(fool) == true and P.last_key() == "c_star")
G.GAME.last_tarot_planet = "c_fool"
check("Fool never makes The Fool", P.can_use(fool) == false)
Store.put_item(fool)
G.P_CENTERS.c_forge_fool = {key = "c_forge_fool", set = "Tarot", forge_kind = "tarot", forge_id = fool.id}
G.GAME.last_tarot_planet = "c_forge_fool"
check("Fool never makes another Fool", P.can_use(fool) == false)
G.GAME.last_tarot_planet = "c_star"
G.consumeables.cards = {{}, {}}
check("Fool needs a free consumable slot", P.can_use(fool) == false)
check("Fool in the consumable area frees its own slot", P.can_use(fool, {area = G.consumeables}) == true)
G.hand.cards = {{}, {}}
check("Sigil only during a hand", P.can_use(sigil) == false)
G.STATE = 1
check("Sigil usable with 2 cards in hand", P.can_use(sigil) == true)
G.hand.cards = {{}}
check("Ouija needs 2 cards", P.can_use(ouija) == false)
local mixed = item({id = "mix", kind = "spectral", name = "Mix", fields = {select = 0}, effects = {{id = "joker_edition", v = "foil"}, {id = "money", n = 3}}})
check("other effects keep the card usable", P.can_use(mixed) == true)

local bs, bm = {name = "Small Blind", forge_vanilla_slot = "small"}, {name = "Forge Blind smallb", forge_slot = "small"}
local bb = {name = "Big Blind", forge_vanilla_slot = "big"}
local mt = {__eq = P.eq}
setmetatable(bs, mt); setmetatable(bm, mt); setmetatable(bb, mt)
check("own Small Blind counts as the Small Blind", bm == bs and bs == bm)
check("own Small Blind is not the Big Blind", bm ~= bb)
local bm2 = setmetatable({forge_slot = "small"}, mt)
check("two own Small Blinds stay different", bm ~= bm2)
check("slot of blind", P.slot_of(small) == "small" and P.slot_of(big) == "big" and P.slot_of(boss) == nil)
local p = {}
P.mark_blind(p, small)
check("own Small Blind leaves the boss pool", p.boss == nil and p.forge_slot == "small")

local wall2 = item({id = "w2", kind = "blind", name = "W2", fields = {size = 2, reward = 5}, effects = {}})
check("plain Small Blind copy rates like a plain Boss Blind", Bal.of(small).level == Bal.of(wall2).level and Bal.of(big).level == Bal.of(wall2).level, Bal.of(small).level .. " " .. Bal.of(big).level .. " " .. Bal.of(wall2).level)
check("Plasma copy rates fair", Bal.of(plasma).level == "fair", Bal.of(plasma).level .. " " .. tostring(Bal.of(plasma).score))
check("slot labels", Cat.value_label("blindslot", "boss") == "Boss Blind")
check("Final boss field kept for Boss Blinds only", P.slot_of(boss) == nil and P.slot_of(small) == "small")
print("forge parity: " .. total .. " checks, " .. fails .. " failed")
