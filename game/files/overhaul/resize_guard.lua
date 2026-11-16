local Hooks = require("overhaul.hooks")

Hooks.wrap("love", "resize", function(orig) return function(w, h, ...)
    w, h = tonumber(w) or 0, tonumber(h) or 0
    if w < 1 or h < 1 then
        local ok, gw, gh = pcall(love.graphics.getDimensions)
        w = math.max(1, math.floor(w >= 1 and w or (ok and gw or 1)))
        h = math.max(1, math.floor(h >= 1 and h or (ok and gh or 1)))
    end
    return orig(w, h, ...)
end end, {id = "overhaul.resize_guard"})
