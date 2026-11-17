local Hooks = require("overhaul.hooks")

local Fallbacks = {ran = {}}

local function note(group)
    Fallbacks.ran[#Fallbacks.ran + 1] = group
    print("[overhaul] late patch " .. group .. " missed, runtime fallback installed")
end

local function mod_session()
    local boot = package.loaded["modloader.boot"]
    return type(boot) == "table" and boot.active and true or false
end

function Fallbacks.main_menu_guard()
    Hooks.wrap("Game", "main_menu", function(orig) return function(game, ...)
        if G and G.LOAD_HANDLER and G.LOAD_HANDLER.loading and G.wait_for_async then
            G:wait_for_async()
            return
        end
        return orig(game, ...)
    end end, {id = "fallback.main_menu_guard"})
end

Hooks.on_late_miss("boot.start_up", function()
    note("boot.start_up")
    local game_class = rawget(_G, "Game")
    if mod_session() and type(game_class) == "table" and not game_class.mod_main_menu then Fallbacks.main_menu_guard() end
    local fetch = rawget(_G, "fetch_achievements")
    if type(fetch) == "function" then pcall(fetch) end
    local boot_profile = mod_session() and G.PROFILES and G.PROFILES[G.SETTINGS.profile or 1]
    if boot_profile and G.load_profile then
        local key = G.SETTINGS.profile
        G:load_profile(G.SETTINGS.profile or 1)
        local index = rawget(_G, "modded_profile_index")
        if type(index) == "function" and not index(G.SETTINGS.profile) then G.SETTINGS.profile = key end
        if not (G.LOAD_HANDLER and G.LOAD_HANDLER.loading) and G.FUNCS.apply_custom_colors then pcall(G.FUNCS.apply_custom_colors) end
    end
end)

local function blocked()
    if G.GAME and G.GAME.modded_run then return true end
    local progress = rawget(_G, "Progress")
    return type(progress) == "table" and type(progress.allowed) == "function" and not progress.allowed()
end

Hooks.on_late_miss("guard.unlock_card", function()
    note("guard.unlock_card")
    Hooks.wrap(_G, "unlock_card", function(orig) return function(card, ...)
        if type(card) == "table" and card.unlocked == false and blocked() then return end
        return orig(card, ...)
    end end, {id = "fallback.unlock_card"})
end)

Hooks.on_late_miss("guard.discover_card", function()
    note("guard.discover_card")
    Hooks.wrap(_G, "discover_card", function(orig) return function(card, ...)
        if blocked() then return end
        return orig(card, ...)
    end end, {id = "fallback.discover_card"})
end)

function Fallbacks.run()
    local engine = package.loaded["modloader.lovely"]
    if type(engine) == "table" and engine.late_misses and #engine.late_misses > 0 then
        return Hooks.run_fallbacks(engine.late_misses)
    end
    return 0
end

Hooks.wrap("Game", "splash_screen", function(orig) return function(...)
    pcall(Fallbacks.run)
    return orig(...)
end end, {id = "fallbacks.splash"})

return Fallbacks
