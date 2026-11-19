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
G.P_CENTERS.j_hanging_chad = {key = "j_hanging_chad", set = "Joker"}
G.P_CENTERS.j_joker = {key = "j_joker", set = "Joker"}
G.P_CENTERS.c_fool = {key = "c_fool", set = "Tarot"}
G.P_CENTERS.v_grabber = {key = "v_grabber", set = "Voucher"}
G.P_CENTERS.p_arcana_normal_1 = {key = "p_arcana_normal_1", set = "Booster"}
G.P_CENTERS.p_arcana_jumbo_1 = {key = "p_arcana_jumbo_1", set = "Booster"}
G.P_CENTERS.m_glass = {key = "m_glass", set = "Enhanced"}
G.P_CENTER_POOLS.Joker = {G.P_CENTERS.j_joker, G.P_CENTERS.j_hanging_chad}
G.P_CENTER_POOLS.Tarot = {G.P_CENTERS.c_fool}
G.P_CENTER_POOLS.Voucher = {G.P_CENTERS.v_grabber}
G.P_TAGS = {tag_double = {key = "tag_double"}}
G.P_BLINDS = {bl_wall = {key = "bl_wall", boss = {min = 1}, order = 2}, bl_small = {key = "bl_small"}}
G.CHALLENGES = {
  {name = "Omelette", id = "c_omelette_1", rules = {custom = {{id = "no_reward"}, {id = "no_extra_hand_money"}}, modifiers = {{id = "dollars", value = 0}}},
    jokers = {{id = "j_joker", eternal = true, edition = "negative", pinned = true}}, consumeables = {}, vouchers = {{id = "v_grabber"}},
    deck = {type = "Challenge Deck", cards = {{s = "H", r = "A"}, {s = "S", r = "K"}, {s = "D", r = "2"}}},
    restrictions = {banned_cards = {{id = "p_arcana_normal_1", ids = {"p_arcana_normal_1", "p_arcana_jumbo_1"}}, {id = "v_grabber"}, {id = "j_joker"}}, banned_tags = {{id = "tag_double"}}, banned_other = {{id = "bl_wall", type = "blind"}}}},
}
G.CHALLENGES[2] = {name = "Mod", id = "c_mod_x", rules = {custom = {{id = "mod_only_rule"}}, modifiers = {}}, jokers = {}, deck = {type = "Challenge Deck"}, restrictions = {}}
G.localization.misc.challenge_names = {c_omelette_1 = "Omelette"}

local Cat = require("functions/forge/forge_catalog")
local Store = require("functions/forge/forge_store")
local R = require("functions/forge/forge_rules")
local D = require("functions/forge/forge_doc")
local Ch = require("functions/forge/forge_challenges")
local Mods = require("functions/forge/forge_mods")

check("kind: challenge is a Forge kind", Cat.BY_ID.challenge ~= nil and Cat.BY_ID.challenge.effects == "challenge")
check("kind: run rules host", R.host_of("challenge") == "run")
check("effects: run rules merged", Cat.effect("challenge", "blind_size") ~= nil and Cat.effect("challenge", "make_card") ~= nil)
check("effects: Simple has the Glass Cannon blocks", Cat.effect("challenge", "ch_enhance").simple and Cat.effect("challenge", "ch_joker").simple and Cat.effect("challenge", "ch_no_shop").simple)

local X = require("functions/forge/forge_chdeck")
Store.live_items = function() return Store.items() end

for _, id in ipairs({"ch_copies", "ch_add_rank", "ch_add_suit", "ch_enh_n", "ch_seal_n", "ch_ed_n", "ch_joker_rental", "ch_joker_perishable", "start_card", "start_consumable", "hand_size", "joker_slots", "interest_cap", "draw_cards"}) do
  check("catalog: challenge offers " .. id, Cat.effect("challenge", id) ~= nil)
end
check("catalog: deck editor in Simple mode", Cat.effect("challenge", "ch_copies").simple == true and Cat.effect("challenge", "ch_add_rank").simple == true)
local fx = Cat.clean_effects("challenge", {{id = "ch_copies", n = 2}, {id = "ch_add_rank", v = "Ace", n = 8}, {id = "ch_add_suit", v = "Hearts", n = 13}, {id = "ch_enh_n", v = "m_glass", n = 5}, {id = "ch_joker", v = "j_joker"}, {id = "ch_joker_rental"}})
check("clean: deck editor kept", #fx == 6 and fx[1].n == 2 and fx[2].v == "Ace" and fx[2].n == 8 and fx[3].v == "Hearts", #fx)
local c = {id = "party", kind = "challenge", name = "Ace Party", fields = {}, effects = fx}
check("share: format 16", Cat.need_v(c) == 16)
Store.put_item(c)
local ch = Ch.build(Store.get_item("party"))
check("build: rules screen lines for the editor", #ch.forge_lines >= 5, #ch.forge_lines)
local text = table.concat(ch.forge_lines, "|")
check("line: copies", text:find("there {C:attention}2{} times", 1, true) ~= nil, text)
check("line: extra Aces", text:find("+8", 1, true) ~= nil and text:find("Ace", 1, true) ~= nil, text)
check("line: rental", text:find("Rental", 1, true) ~= nil, text)
check("build: starting Joker", ch.jokers[1] and ch.jokers[1].id == "j_joker")

G.P_CARDS = {S_A = {suit = "Spades", value = "Ace"}, H_K = {suit = "Hearts", value = "King"}}
check("front: Ace of Spades", X.front("Spades", "Ace") == G.P_CARDS.S_A and X.front("Clubs", "Ace") == nil)
G.jokers = {cards = {{id = 1}, {id = 2}}}
check("last joker: the one from the effects", X.last_joker({effects = {{id = "ch_joker"}, {id = "ch_copies"}}}) == G.jokers.cards[1])

print(string.format("forge challenges2: %d checks, %d failed", total, fails))
if fails > 0 then os.exit(1) end
