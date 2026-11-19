package.path = "assets/?.lua;" .. package.path
mod_loc = function(s) return s end
mod_loc_register = function() end

local fails, total = 0, 0
local function check(name, ok, got)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (got ~= nil and (" got: " .. tostring(got)) or "")) end
end

local NAMES = {j_joker = "Joker", j_cavendish = "Cavendish", j_hiker = "Hiker"}
G = {
  SETTINGS = {language = "en-us", tally_joker = true, tally_advanced = true},
  GAME = {probabilities = {normal = 1}, dollars = 10, hands = {}, current_round = {}, round_resets = {ante = 1}},
  C = {MULT = {1, 0.3, 0.3, 1}, CHIPS = {0, 0.6, 1, 1}, MONEY = {1, 0.8, 0, 1}, FILTER = {1, 0.6, 0, 1}, GREEN = {0.3, 0.7, 0.5, 1}, RED = {1, 0.3, 0.3, 1},
    BLUE = {0, 0.6, 1, 1}, WHITE = {1, 1, 1, 1}, CLEAR = {0, 0, 0, 0}, DARK_EDITION = {0.4, 0.4, 0.8, 1}, GOLD = {1, 0.8, 0, 1}, SECONDARY_SET = {},
    UI = {TEXT_INACTIVE = {0.5, 0.5, 0.5, 1}, TEXT_LIGHT = {1, 1, 1, 1}, TEXT_DARK = {0.2, 0.2, 0.2, 1}}},
  jokers = {cards = {}, config = {card_limit = 5}},
  UIT = {T = 1, B = 2, C = 3, R = 4, O = 5, ROOT = 6},
  STAGE = 1, STAGES = {RUN = 1}, CARD_W = 2, TILESIZE = 20, I = {}, FUNCS = {},
}
localize = function(a, b)
  if type(a) == "table" then
    if a.type == "name_text" then return NAMES[a.key] or a.key end
    return a.key .. ":" .. table.concat(a.vars or {}, ",")
  end
  return a
end
Game = {update = function() end}
Card = {}
Card.__index = Card

local items = {}
package.loaded["functions/forge/forge_store"] = {get = function(id) local c = items[id]; return c and c.kind == "joker" and c or nil end, get_item = function(id) return items[id] end,
  cut = function(str, n) return str:sub(1, n or #str) end}
require("functions/forge/forge_rules")
require("functions/forge/forge_text")
local P = require("functions/forge/forge_power3")
local BO = require("functions/forge/forge_boost")
require("functions/forge/forge_grow")
TALLY = nil
dofile("assets/functions/tally_joker.lua")
local T = TALLY
G.CARD_W = 2
local card = {T = {x = 8.6, y = 7.4, w = 2, h = 2.75}}
local box = {T = {x = 9.0, y = 10.05, w = 1.2, h = 0.43}, alignment = {offset = {x = 0, y = -0.1}}, config = {offset = {x = 0, y = -0.1}}}
G.deck = {T = {x = 8.3, y = 10.57, w = 2.25, h = 2.9}, cards = {{T = {y = 10.5}, VT = {y = 10.5}}}}
G.consumeables = {T = {x = 0.5, y = 10.3, w = 7.5, h = 2.5}, cards = {}}
check("area top: deck uses its top card", T.area_top(G.deck) == 10.5)
check("area top: empty consumable area is ignored", T.area_top(G.consumeables) == nil)
T.lift(card, box)
local bottom = card.T.y + card.T.h + box.alignment.offset.y + box.T.h
check("lift: pill moves up above the deck", box.alignment.offset.y < -0.1 and bottom <= 10.5 - T.LIFT_GAP + 1e-6, box.alignment.offset.y)
check("lift: never more than the cap", box.alignment.offset.y >= -0.1 - T.LIFT_MAX * card.T.h - 1e-6)
local far = {T = {x = 1, y = 7.4, w = 2, h = 2.75}}
local fbox = {T = {x = 1.4, y = 10.05, w = 1.2, h = 0.43}, alignment = {offset = {x = 0, y = -0.1}}, config = {offset = {x = 0, y = -0.1}}}
T.lift(far, fbox)
check("lift: a Joker not over the deck keeps its place", fbox.alignment.offset.y == -0.1)
G.deck.T.x = 20
T.lift(card, box)
check("lift: back down when the deck moves away", math.abs(box.alignment.offset.y + 0.1) < 1e-6, box.alignment.offset.y)
G.consumeables.cards = {{T = {y = 10.3}, VT = {y = 10.3}}}
check("area top: consumable area with cards counts", T.area_top(G.consumeables) == 10.3)

print(string.format("tally_lift: %d/%d passed", total - fails, total))
os.exit(fails == 0 and 0 or 1)
