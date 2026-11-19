package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, extra)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "")) end
end

local queue = {}
Event = function(t) return t end
local function drain()
  local q = queue
  queue = {}
  for _, e in ipairs(q) do e.func() end
end

Controller = {}
function Controller:L_cursor_press() self.cursor_down = {time = 1} end
function Controller:L_cursor_release() self.cursor_up = {time = 2} end
Game = {}
function Game:delete_run() if G.on_delete then G.on_delete() end end
function Game:set_globals() self.ANIMATION_ATLAS = {} end
function Game:start_run() end
CardArea = {}
function CardArea:parse_highlighted() G.parsed = (G.parsed or 0) + 1 end

local seeds = {}
function pseudoseed(s) seeds[#seeds + 1] = s; return 0.5 end
function pseudorandom_element(t, seed) return t[1], seed end

G = {
  SETTINGS = {profile = "p"}, PROFILES = {p = {}},
  UIDEF = {}, FUNCS = {}, I = {CARDAREA = {}},
  TIMERS = {UPTIME = 42},
  P_CENTERS = {j_joker = {}},
  GAME = {},
  E_MANAGER = {add_event = function(_, e) queue[#queue + 1] = e end},
  CHALLENGES = {},
}
G.hand = {cards = {}}
G.play = {cards = {}}
G.deck = {cards = {}}
G.discard = {cards = {}}

G.FUNCS.can_buy_and_use = function(e) e.UIBox.states.visible = false; return true end
G.FUNCS.can_buy = function(e) return e.UIBox ~= nil end

local Hooks = require("overhaul.hooks")
local MG = require("overhaul.mod_guards")
MG.install(Hooks)

check("212 fake element gets a UIBox", G.FUNCS.can_buy_and_use({config = {ref_table = {}}}) == true)
check("212 can_buy sees a UIBox", G.FUNCS.can_buy({config = {ref_table = {}}}) == true)

G.parsed = 0
G.on_delete = function() CardArea.parse_highlighted(G.hand) end
Game.delete_run(G)
check("213 no hand parse during delete_run", G.parsed == 0, G.parsed)
CardArea.parse_highlighted(G.hand)
check("213 parse works after delete_run", G.parsed == 1, G.parsed)
check("213 flag cleared", MG.deleting_run == nil)

Game.set_globals(G)
check("207 STATE_ATLAS aliases ANIMATION_ATLAS", G.STATE_ATLAS == G.ANIMATION_ATLAS and G.STATE_ATLAS ~= nil)
Game.set_globals(G)
check("207 alias follows a rebuilt ANIMATION_ATLAS", G.STATE_ATLAS == G.ANIMATION_ATLAS)
local own = {x = 1}
local g2 = {ANIMATION_ATLAS = {}, STATE_ATLAS = own}
check("207 a real STATE_ATLAS is kept", MG.state_atlas(g2) == false and g2.STATE_ATLAS == own)

local ctl = setmetatable({}, {__index = Controller})
Controller.L_cursor_press(ctl)
check("266 press sets cursor_down.uptime", ctl.cursor_down.uptime == 42)
Controller.L_cursor_release(ctl)
check("266 release sets cursor_up.uptime", ctl.cursor_up.uptime == 42)

local v, s = pseudorandom_element({"a"}, "false_to_do_smods")
check("234 string seed becomes a number", v == "a" and s == 0.5 and seeds[1] == "false_to_do_smods")
v, s = pseudorandom_element({"a"}, 0.25)
check("234 number seed untouched", s == 0.25 and #seeds == 1)

math.clamp = function(n, lo, hi) assert(lo <= hi); return math.min(math.max(n, lo), hi) end
Hooks.reapply()
check("260 clamp with min above max", math.clamp(1, 2, 1) == 1)
check("260 clamp normal", math.clamp(5, 1, 3) == 3 and math.clamp(0, 1, 3) == 1)
math.clamp = nil

PB_UTIL = {}
local shade_card = {is_suit_shade = function(_, shade) return shade == "light" end}
Card = {is_suit_shade = shade_card.is_suit_shade}
local castle
function reset_castle_card() castle = PB_UTIL.is_suit(shade_card, "light") end
Hooks.reapply()
reset_castle_card()
check("253 PB_UTIL.is_suit shim", castle == true)

SMODS = {}
function SMODS.create_poll_pool() return {{key = "UNAVAILABLE"}, {key = "j_joker"}} end
local blue_ret = {chips = 5}
function SMODS.blueprint_effect() return blue_ret end
Hooks.reapply()
local pool = SMODS.create_poll_pool({"Joker"}, {append = "misprintta"})
check("203 misprint pool keeps known centers", #pool == 1 and pool[1].key == "j_joker", #pool)
pool = SMODS.create_poll_pool({"Joker"}, {append = "other"})
check("203 other pools untouched", #pool == 2)
local r = SMODS.blueprint_effect({config = {center = {key = "j_roff_getchips"}}}, {}, {})
check("274 chip_mod filled for Just Get Chips", r.chip_mod == 0 and r.chips == 5)
blue_ret = {chips = 1}
r = SMODS.blueprint_effect({config = {center = {key = "j_other"}}}, {}, {})
check("274 other jokers untouched", r.chip_mod == nil)

All_in_Jest = {create_astral_pin = function(c) return #G.GAME.Astral_pins[c.ability.consumeable.hand] end}
G.P_CENTERS.e_aij_misprint = {on_remove = function(c) return _front end}
TexturePacks = {}
local set_defaults_ran = false
Malverk = {set_defaults = function() set_defaults_ran = true; return TexturePacks.default.textures end}
Hooks.reapply()
check("262 astral pins list created", All_in_Jest.create_astral_pin({ability = {consumeable = {hand = "aij_Royal Flush"}}}) == 0)
local front = {suit = "Hearts"}
check("267 misprint on_remove sees the card front", G.P_CENTERS.e_aij_misprint.on_remove({config = {card = front}}) == front)
check("267 _front cleared", rawget(_G, "_front") == nil)
Malverk.set_defaults()
check("209 malverk without texture packs skips", set_defaults_ran == false)
TexturePacks.default = {textures = {}}
Malverk.set_defaults()
check("209 malverk with packs runs", set_defaults_ran == true)

SMODS.Challenges = {}
local Ch = require("overhaul.challenges")
check("279 our challenges listed", #G.CHALLENGES > 0)
local id = G.CHALLENGES[1].id
Game.start_run(G)
local c = SMODS.Challenges[id]
check("279 SMODS.Challenges finds our challenge", c ~= nil and c.id == id and c.jokers == G.CHALLENGES[1].jokers)
check("279 proxy has a calculate", c and type(c.calculate) == "function" and c:calculate({}) == nil)
check("279 same proxy each lookup", SMODS.Challenges[id] == c)
check("279 pairs does not list ours", next(SMODS.Challenges) == nil)
check("279 unknown ids still nil", SMODS.Challenges.c_none == nil)
check("279 index installed once", Ch.smods_index() == false)

love = love or {}
local E = require("modloader.lovely")
E.patches, E.targets, E.warnings, E.misses = {}, {}, {}, {}
E.late_misses = E.late_misses or {}
local q = string.rep("'", 3)
local toml = table.concat({
  "[manifest]", 'version = "1.0.0"', "priority = 0", "",
  "[[patches]]", "[patches.regex]", 'target = "big.lua"',
  "pattern = " .. q .. "(?<all>(?:ab\\n?)+)" .. q, 'position = "at"', "payload = " .. q .. "x" .. q, "",
  "[[patches]]", "[patches.regex]", 'target = "big.lua"',
  "pattern = " .. q .. "^tail$" .. q, 'position = "at"', "payload = " .. q .. "done" .. q, "",
}, "\n")
E.load_patch_file("mods/deep/lovely.toml", nil, toml)
local big = string.rep("ab", 20000) .. "\ntail\n"
local ok, out = pcall(E.apply_patches, "big.lua", big)
check("269 deep regex does not crash the patcher", ok, out)
check("269 next patch still applies", ok and out:find("\ndone\n", 1, true) ~= nil)
local warned = false
for _, w in ipairs(E.warnings) do if w:find("could not be matched", 1, true) then warned = true end end
check("269 deep regex is reported as a warning", warned)

print(string.format("crashes_1118: %d/%d passed, %d failed", total - fails, total, fails))
os.exit(fails == 0 and 0 or 1)
