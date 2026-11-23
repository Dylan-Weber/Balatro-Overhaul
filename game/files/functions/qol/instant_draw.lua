local Q = QOL
local M = Q.feature("instant_draw", {})

-- Drawing a hand queues a short pause, then one event per card that holds the queue for
-- 0.1s after the card lands, and with Steamodded one more event that holds it for 0.4s
-- after telling jokers what was drawn. Instant draw keeps every one of those events, in the
-- same order, and drops the waits. It also stops them holding the queue for a frame each,
-- so a 52 card hand lands in one frame instead of 52. They still wait behind anything
-- queued before them, and anything queued after the draw still runs after every card is in.
-- Steamodded also queues an immediate event beside each card that takes up hand space,
-- and those get the same treatment.
M.INSTANT_TRIGGERS = {after = true, before = true, immediate = true}

-- A whole hand landing at once would play every card's draw sound together.
M.DRAW_SOUNDS_PER_FRAME = 3

M.draw_depth = 0
M.wrapped_draw_functions = {}
M.landing_depth = 0
M.sound_frame_time = nil
M.sounds_this_frame = 0

Q.default("qol_instant_draw", false)

function M.allowed()
    if not (Q.on("qol_instant_draw") and Q.solo()) then return false end
    if bom_playback and bom_playback.active and bom_playback.active() then return false end
    local fair_lock = rawget(_G, "FairLock")
    if fair_lock and fair_lock.blocks then
        local checked, blocked_reason = pcall(fair_lock.blocks, "instant_draw")
        if not checked or blocked_reason then return false end
    end
    return true
end

function M.shorten(event)
    if type(event) ~= "table" or not M.INSTANT_TRIGGERS[event.trigger] then return end
    local event_delay = tonumber(event.delay)
    if event_delay and event_delay > 0 then event.delay = 0 end
    if event.blocking == false or type(event.func) ~= "function" then return end
    -- The event no longer holds the queue when it finishes in one go. If it reports that it
    -- is not done, it holds the queue at once (EventManager:update reads the blocking flag of
    -- G.ARGS.event_manager_update after the event runs) and from then on, as it did before.
    local event_function = event.func
    event.blocking = false
    event.func = function(...)
        M.landing_depth = M.landing_depth + 1
        local event_results = {pcall(event_function, ...)}
        M.landing_depth = M.landing_depth - 1
        if not event_results[1] then error(event_results[2], 0) end
        if not event_results[2] then
            event.blocking = true
            local queue_results = G and G.ARGS and G.ARGS.event_manager_update
            if type(queue_results) == "table" then queue_results.blocking = true end
        end
        return unpack(event_results, 2, table.maxn(event_results))
    end
end

function M.sound_allowed(sound_code)
    if M.landing_depth == 0 or sound_code ~= 'card1' then return true end
    local frame_time = G and G.TIMERS and G.TIMERS.REAL
    if frame_time ~= M.sound_frame_time then
        M.sound_frame_time = frame_time
        M.sounds_this_frame = 0
    end
    M.sounds_this_frame = M.sounds_this_frame + 1
    return M.sounds_this_frame <= M.DRAW_SOUNDS_PER_FRAME
end

-- Runs a draw function with instant draw on for the events it queues. The flag only lasts
-- while the function runs, so events queued later by other code keep their own timing.
function M.wrap_draw(draw_function)
    if M.wrapped_draw_functions[draw_function] then return draw_function end
    local wrapped_draw_function = function(...)
        local allowed_checked, allowed = pcall(M.allowed)
        if not (allowed_checked and allowed) then return draw_function(...) end
        M.draw_depth = M.draw_depth + 1
        local draw_results = {pcall(draw_function, ...)}
        M.draw_depth = M.draw_depth - 1
        if not draw_results[1] then error(draw_results[2], 0) end
        return unpack(draw_results, 2, table.maxn(draw_results))
    end
    M.wrapped_draw_functions[wrapped_draw_function] = true
    return wrapped_draw_function
end

Q.row("Speed", function()
    return UIK.toggle{id = 'set_qol_instant_draw', label = mod_loc("Instant draw"), info = mod_loc("Cards reach your hand at once in solo runs"),
        ref_table = G.SETTINGS, ref_value = 'qol_instant_draw', lock = 'instant_draw', callback = Q.save}
end)

local function strings()
    if not mod_loc_register then return end
    mod_loc_register{
        fr = {["Instant draw"] = "Pioche instantanée", ["Cards reach your hand at once in solo runs"] = "Les cartes arrivent d'un coup dans votre main en solo"},
        es = {["Instant draw"] = "Robo instantáneo", ["Cards reach your hand at once in solo runs"] = "Las cartas llegan a tu mano al instante en solitario"},
    }
end

function M.init()
    strings()
    if M.initialized or not (G and G.FUNCS and G.FUNCS.draw_from_deck_to_hand and EventManager and EventManager.add_event) then return end
    M.initialized = true
    G.FUNCS.draw_from_deck_to_hand = M.wrap_draw(G.FUNCS.draw_from_deck_to_hand)
    local steamodded = rawget(_G, "SMODS")
    if type(steamodded) == "table" and type(steamodded.draw_cards) == "function" then
        steamodded.draw_cards = M.wrap_draw(steamodded.draw_cards)
    end
    local add_event = EventManager.add_event
    EventManager.add_event = function(self, event, ...)
        if M.draw_depth > 0 then pcall(M.shorten, event) end
        return add_event(self, event, ...)
    end
    if type(play_sound) == "function" then
        local base_play_sound = play_sound
        play_sound = function(sound_code, ...)
            if not M.sound_allowed(sound_code) then return end
            return base_play_sound(sound_code, ...)
        end
    end
end

strings()

return M
