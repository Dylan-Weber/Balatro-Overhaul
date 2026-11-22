-- Opening a second booster pack with "Fast packs" on.
-- Runs the real functions/qol/fast_packs.lua against a small event queue that keeps the
-- game's rules (blocking events hold back blockable ones, non-blockable ones run on their
-- own timer) and the two events Card.open queues for a pack: build the cards, then put them
-- in G.pack_cards once it exists and is on screen. The pack box (the new G.pack_cards) is
-- built later, behind the blocking events of opening a pack.
-- Bug this guards: G.pack_cards still pointed at the last pack's removed area, which sits on
-- screen in portrait. Fast packs cut the wait to a tenth, so the cards went into that
-- removed area and every pack after the first opened empty until the run was reloaded.
local fails, passes = 0, 0
local function ok(condition, message)
  if condition then passes = passes + 1 else fails = fails + 1; print("FAIL " .. message) end
end

local room_height = 24.6
local event_clock = 0

EventManager = {}
EventManager.__index = EventManager
function EventManager.new() return setmetatable({queue = {}}, EventManager) end
function EventManager:add_event(event)
  event.created_at = event_clock
  event.delay = event.delay or 0
  if event.blocking == nil then event.blocking = true end
  if event.blockable == nil then event.blockable = true end
  self.queue[#self.queue + 1] = event
end
function EventManager:run_until(stop_time)
  while event_clock < stop_time do
    event_clock = event_clock + 0.01
    local blocked = false
    local index = 1
    while index <= #self.queue do
      local event = self.queue[index]
      local finished = false
      if not (blocked and event.blockable) and event_clock >= event.created_at + event.delay then
        finished = event.func() == true
      end
      if finished then
        table.remove(self.queue, index)
      else
        if event.blocking then blocked = true end
        index = index + 1
      end
    end
  end
end

local function new_pack_area()
  return {cards = {}, emplaced_count = 0, VT = {y = 17.3}, emplace = function(self, card)
    self.cards[#self.cards + 1] = card
    self.emplaced_count = self.emplaced_count + 1
  end}
end

-- Card.open as the game has it, cut down to the parts that decide where the cards go.
Card = {}
function Card.open(pack)
  local pack_cards = {}
  G.E_MANAGER:add_event({trigger = "after", delay = 0.4, func = function()
    G.E_MANAGER:add_event({trigger = "after", delay = 1.3, blockable = false, blocking = false, func = function()
      for index = 1, pack.ability.extra do pack_cards[index] = {id = index} end
      return true
    end})
    G.E_MANAGER:add_event({trigger = "after", delay = 1.3, blockable = false, blocking = false, func = function()
      if G.pack_cards and G.pack_cards.VT.y < room_height then
        for _, card in ipairs(pack_cards) do G.pack_cards:emplace(card) end
        return true
      end
    end})
    return true
  end})
  -- jokers reacting to the pack and the price easing in hold the queue up for a while
  local held_until = event_clock + 0.6
  G.E_MANAGER:add_event({trigger = "immediate", func = function() return event_clock >= held_until end})
  -- SMODS update_pack builds the pack box, and with it a new G.pack_cards
  G.E_MANAGER:add_event({trigger = "immediate", func = function()
    G.pack_cards = new_pack_area()
    return true
  end})
end

G = {SETTINGS = {qol_fast_packs = true}, TIMERS = {REAL = 0}, E_MANAGER = EventManager.new()}
QOL = {
  feature = function(_, module) return module end,
  default = function() end,
  on = function(key) return G.SETTINGS[key] == true end,
  solo = function() return true end,
  row = function() end,
  toggle = function() end,
}

local fast_packs = assert(loadfile("assets/functions/qol/fast_packs.lua"))()
fast_packs.init()

local function open_pack()
  local pack = {ability = {set = "Booster", extra = 3}}
  Card.open(pack)
  G.E_MANAGER:run_until(event_clock + 8)
  return G.pack_cards
end

local function close_pack()
  -- skipping or picking removes the pack box with its card area and cards; the global stays
  G.pack_cards.REMOVED = true
  G.pack_cards.cards = {}
end

-- the first pack of the run, with no earlier pack area around
local first_area = open_pack()
ok(first_area and #first_area.cards == 3, "the first pack shows its 3 cards")
close_pack()

-- the next pack, with the removed area of the first one still in G.pack_cards
local second_area = open_pack()
ok(second_area ~= first_area, "the second pack gets its own card area")
ok(#second_area.cards == 3, "the second pack shows its 3 cards, got " .. #second_area.cards)
ok(first_area.emplaced_count == 3, "no cards went into the first pack's removed area, it got " .. first_area.emplaced_count)
close_pack()

-- a pack area that is still open is left alone
local forget_closed_pack_area = fast_packs.forget_closed_pack_area or function() end
ok(fast_packs.forget_closed_pack_area ~= nil, "fast packs can forget a closed pack area")
local open_area = new_pack_area()
G.pack_cards = open_area
forget_closed_pack_area()
ok(G.pack_cards == open_area, "an open pack area is kept")
G.pack_cards = nil
forget_closed_pack_area()
ok(G.pack_cards == nil, "no pack area stays no pack area")

-- with fast packs off the game's own wait is long enough, and the guard changes nothing
G.SETTINGS.qol_fast_packs = false
G.pack_cards = second_area
local slow_area = open_pack()
ok(#slow_area.cards == 3, "with fast packs off a later pack shows its 3 cards")

-- the race itself: without forgetting the removed area, a fast pack opens empty
G.SETTINGS.qol_fast_packs = true
close_pack()
fast_packs.forget_closed_pack_area = function() end
local stale_area = G.pack_cards
local raced_area = open_pack()
fast_packs.forget_closed_pack_area = forget_closed_pack_area
ok(#raced_area.cards == 0 and stale_area.emplaced_count == 6, "without the guard the cards land in the removed area (the bug this test guards): new " .. #raced_area.cards .. ", removed " .. stale_area.emplaced_count)

print(string.format("fast_packs_reopen: %d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
