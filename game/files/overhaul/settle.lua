local Hooks = require("overhaul.hooks")

local S = {pending = false}

Hooks.wrap("Moveable", "init", function(orig) return function(self, ...)
    S.pending = true
    return orig(self, ...)
end end, {id = "overhaul.settle.init"})

function S.run()
    if not S.pending then return end
    S.pending = false
    if not (G and G.MOVEABLES and G.FRAMES and G.exp_times and G.exp_times.max_vel) then return end
    local dt = math.max(1/240, math.min(1/20, G.real_dt or 1/60))
    for _, m in pairs(G.MOVEABLES) do
        if m and m.FRAME and m.FRAME.MOVE < G.FRAMES.MOVE then m:move(dt) end
    end
end

Hooks.wrap("Game", "draw", function(orig) return function(self, ...)
    pcall(S.run)
    return orig(self, ...)
end end, {id = "overhaul.settle.draw"})

return S
