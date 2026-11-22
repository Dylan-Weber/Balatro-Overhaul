local Q = QOL
local M = Q.feature("instant_draw", {})

-- Drawing a hand queues a short pause, then one event per card that holds the queue for
-- 0.1s after the card lands, and with Steamodded one more event that holds it for 0.4s
-- after telling jokers what was drawn. Instant draw keeps every one of those events, in the
-- same order, and only drops the waits. Nothing is moved by a timer: each card still goes
-- into the hand from its own event, and anything queued after the draw still runs after it.
M.SHORTENED_TRIGGERS = {after = true, before = true}

M.draw_depth = 0
M.wrapped_draw_functions = {}

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
    if type(event) ~= "table" or not M.SHORTENED_TRIGGERS[event.trigger] then return end
    local event_delay = tonumber(event.delay)
    if event_delay and event_delay > 0 then event.delay = 0 end
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
end

strings()

return M
