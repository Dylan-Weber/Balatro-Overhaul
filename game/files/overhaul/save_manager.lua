local Hooks = require("overhaul.hooks")

Hooks.wrap("love.thread", "newThread", function(orig) return function(src, ...)
    if src == 'engine/save_manager.lua' then src = 'overhaul/save_thread.lua' end
    return orig(src, ...)
end end, {id = "overhaul.save_manager.thread"})
