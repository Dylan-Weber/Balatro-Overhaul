-- "Instant draw": cards reach the hand at once, without changing the order things happen in.
-- Runs the real functions/qol/instant_draw.lua with the game's real Event and EventManager
-- (engine/event.lua) and the game's own draw functions, cut out of their files unchanged:
-- draw_card and delay (functions/common_events.lua), G.FUNCS.draw_from_deck_to_hand
-- (functions/state_events.lua) and SMODS.draw_cards (smods/src/utils.lua).
-- Timing this guards: Fast packs once let pack cards arrive before their pack box existed,
-- so packs opened empty. Instant draw must not let anything queued after a draw (the hand
-- becoming playable, jokers hearing what was drawn) run before every card is in the hand.
local fails, passes = 0, 0
local function ok(condition, message)
  if condition then passes = passes + 1 else fails = fails + 1; print("FAIL " .. message) end
end

local function read_file(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end

-- Loads one top-level function from a game file, from its first line to the "end" that closes it.
local function load_game_function(path, first_line)
  local source = read_file(path)
  local start_position = assert(source:find(first_line, 1, true), first_line .. " not found in " .. path)
  local end_position = assert(source:find("\nend\n", start_position, true), "no end for " .. first_line)
  assert(loadstring(source:sub(start_position, end_position + 4), "=" .. path))()
end

local FRAME_TIME = 1 / 60
local HAND_SIZE = 8

G = {
  SETTINGS = {paused = false, qol_instant_draw = true},
  TIMERS = {REAL = 0, TOTAL = 0},
  STATES = {SELECTING_HAND = 1, DRAW_TO_HAND = 2, GAME_OVER = 3, TAROT_PACK = 4, SPECTRAL_PACK = 5, SMODS_BOOSTER_OPENED = 6},
  FUNCS = {},
  ARGS = {},
  VIBRATION = 0,
}
G.STATE = G.STATES.DRAW_TO_HAND

assert(loadfile("assets/engine/object.lua"))()
assert(loadfile("assets/engine/event.lua"))()
load_game_function("assets/functions/common_events.lua", "function delay(")
load_game_function("assets/functions/common_events.lua", "function draw_card(")
load_game_function("assets/functions/state_events.lua", "G.FUNCS.draw_from_deck_to_hand = function(e)")
local base_draw_from_deck_to_hand = G.FUNCS.draw_from_deck_to_hand

SMODS = {drawn_cards = {}, heard_contexts = {}}
function SMODS.calculate_context(context)
  SMODS.heard_contexts[#SMODS.heard_contexts + 1] = {context = context, cards_in_hand = #G.hand.cards}
  return {}
end
load_game_function("assets/smods/src/utils.lua", "function SMODS.draw_cards(hand_space)")

local played_sounds = 0
function play_sound() played_sounds = played_sounds + 1 end

-- A card area with the parts of CardArea the draw functions use.
local function new_card_area(card_limit)
  local card_area = {cards = {}, config = {card_limit = card_limit}, sort_count = 0}
  function card_area:remove_card()
    return table.remove(self.cards)
  end
  function card_area:emplace(card)
    self.cards[#self.cards + 1] = card
    card.arrived_at = G.TIMERS.TOTAL
    if SMODS and card.playing_card then SMODS.drawn_cards[#SMODS.drawn_cards + 1] = card end
  end
  function card_area:draw_card_from(from_area)
    local card = from_area:remove_card()
    if card then self:emplace(card) return true end
  end
  function card_area:sort() self.sort_count = self.sort_count + 1 end
  return card_area
end

local function new_round()
  G.deck = new_card_area(52)
  for card_number = 1, 20 do G.deck.cards[card_number] = {id = card_number, playing_card = true} end
  G.hand = new_card_area(HAND_SIZE)
  G.GAME = {blind = {name = "Small Blind", stay_flipped = function() return false end}, modifiers = {},
    current_round = {hands_played = 0, discards_used = 0}, facing_blind = true}
  G.E_MANAGER = EventManager()
  G.STATE = G.STATES.DRAW_TO_HAND
  SMODS.drawn_cards, SMODS.heard_contexts = {}, {}
  played_sounds = 0
end

local function run_frames(frame_count)
  for _ = 1, frame_count do
    G.TIMERS.REAL = G.TIMERS.REAL + FRAME_TIME
    G.TIMERS.TOTAL = G.TIMERS.TOTAL + FRAME_TIME
    G.E_MANAGER:update(FRAME_TIME)
  end
end

local function run_until(condition, frame_limit)
  local started_at = G.TIMERS.TOTAL
  for _ = 1, frame_limit or 600 do
    if condition() then return G.TIMERS.TOTAL - started_at end
    run_frames(1)
  end
  return nil
end

-- What the round start does: draw a hand, then let the player pick cards.
local function draw_hand_then_select(draw_function)
  local state_changed_with_cards
  G.E_MANAGER:add_event(Event({func = function()
    draw_function()
    G.E_MANAGER:add_event(Event({func = function()
      G.STATE = G.STATES.SELECTING_HAND
      state_changed_with_cards = #G.hand.cards
      return true
    end}))
    return true
  end}))
  local seconds_taken = run_until(function() return G.STATE == G.STATES.SELECTING_HAND end)
  return seconds_taken, state_changed_with_cards
end

local function hand_ids()
  local ids = {}
  for _, card in ipairs(G.hand.cards) do ids[#ids + 1] = card.id end
  return table.concat(ids, ",")
end

QOL = {
  modules = {},
  feature = function(key, module) QOL.modules[key] = module return module end,
  default = function() end,
  on = function(key) return G.SETTINGS[key] == true end,
  solo = function() return not G.GAME.multiplayer end,
  row = function() end,
  save = function() end,
}

local instant_draw = assert(loadfile("assets/functions/qol/instant_draw.lua"))()
instant_draw.init()
instant_draw.init()
ok(G.FUNCS.draw_from_deck_to_hand ~= base_draw_from_deck_to_hand, "instant draw wraps the hand draw")
ok(instant_draw.wrap_draw(G.FUNCS.draw_from_deck_to_hand) == G.FUNCS.draw_from_deck_to_hand, "a wrapped draw is not wrapped twice")

-- the game's own timing, with instant draw off
G.SETTINGS.qol_instant_draw = false
new_round()
local normal_seconds, normal_cards_at_select = draw_hand_then_select(G.FUNCS.draw_from_deck_to_hand)
local normal_order = hand_ids()
ok(normal_seconds and normal_seconds >= 1.0, "with instant draw off a hand still takes the game's 1.1s, took " .. tostring(normal_seconds))
ok(normal_cards_at_select == HAND_SIZE, "with instant draw off the hand is full when it becomes playable")

-- instant draw on: the same cards, in the same order, in a handful of frames
G.SETTINGS.qol_instant_draw = true
new_round()
local instant_seconds, instant_cards_at_select = draw_hand_then_select(G.FUNCS.draw_from_deck_to_hand)
ok(instant_seconds and instant_seconds <= (HAND_SIZE + 4) * FRAME_TIME, "with instant draw on the hand is drawn in a few frames, took " .. tostring(instant_seconds))
ok(instant_cards_at_select == HAND_SIZE, "the hand only becomes playable once all " .. HAND_SIZE .. " cards are in it, it had " .. tostring(instant_cards_at_select))
ok(hand_ids() == normal_order, "instant draw draws the same cards in the same order: " .. hand_ids() .. " vs " .. normal_order)
ok(#G.deck.cards == 20 - HAND_SIZE, "the drawn cards left the deck")
ok(played_sounds == HAND_SIZE and G.hand.sort_count == HAND_SIZE, "every card still plays its sound and sorts the hand")
ok(instant_draw.draw_depth == 0, "instant draw is off again once the draw has been queued")

-- events queued after the draw keep their own waits
new_round()
local later_event_ran_at
G.E_MANAGER:add_event(Event({func = function()
  G.FUNCS.draw_from_deck_to_hand()
  return true
end}))
G.E_MANAGER:add_event(Event({trigger = "after", delay = 0.5, func = function() later_event_ran_at = G.TIMERS.TOTAL return true end}))
local queued_at = G.TIMERS.TOTAL
run_until(function() return later_event_ran_at ~= nil end)
ok(later_event_ran_at and later_event_ran_at - queued_at >= 0.5, "an event queued after the draw keeps its 0.5s wait")

-- Steamodded's draw: jokers hear about the drawn cards only once they are all in the hand
new_round()
local smods_seconds, smods_cards_at_select = draw_hand_then_select(function() SMODS.draw_cards(HAND_SIZE) end)
local heard_drawn
for _, heard in ipairs(SMODS.heard_contexts) do
  if heard.context.hand_drawn then heard_drawn = heard end
end
ok(smods_seconds and smods_seconds <= (HAND_SIZE + 5) * FRAME_TIME, "Steamodded draws are instant too, took " .. tostring(smods_seconds))
ok(smods_cards_at_select == HAND_SIZE, "with Steamodded the hand is full when it becomes playable")
ok(heard_drawn and #heard_drawn.context.hand_drawn == HAND_SIZE and heard_drawn.cards_in_hand == HAND_SIZE,
  "jokers hear about all " .. HAND_SIZE .. " drawn cards after they are in the hand")

-- multiplayer, replays and speedruns keep the game's timing
new_round()
G.GAME.multiplayer = true
local multiplayer_seconds = draw_hand_then_select(G.FUNCS.draw_from_deck_to_hand)
ok(multiplayer_seconds and multiplayer_seconds >= 1.0, "multiplayer draws keep the game's timing, took " .. tostring(multiplayer_seconds))

new_round()
bom_playback = {active = function() return true end}
local replay_seconds = draw_hand_then_select(G.FUNCS.draw_from_deck_to_hand)
bom_playback = nil
ok(replay_seconds and replay_seconds >= 1.0, "replays keep the game's timing, took " .. tostring(replay_seconds))

new_round()
FairLock = {blocks = function(key) return key == "instant_draw" and "Off in Speedrun" or nil end}
local speedrun_seconds = draw_hand_then_select(G.FUNCS.draw_from_deck_to_hand)
FairLock = nil
ok(speedrun_seconds and speedrun_seconds >= 1.0, "speedruns keep the game's timing, took " .. tostring(speedrun_seconds))

-- the game's results and errors come back through the wrapper
new_round()
G.hand.config.card_limit = 0
ok(G.FUNCS.draw_from_deck_to_hand() == true, "a draw with no hand space still ends the run")
ok(G.STATE == G.STATES.GAME_OVER, "and the game is over")

local failing_draw = instant_draw.wrap_draw(function() error("draw failed") end)
new_round()
local failed = not pcall(failing_draw)
ok(failed and instant_draw.draw_depth == 0, "a draw that fails turns instant draw back off")

print(string.format("instant_draw: %d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
