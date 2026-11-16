local Hooks = require("overhaul.hooks")

Hooks.wrap("SMODS", "stencil_for", function(orig) return function(canvas, ...)
    local r = Hooks.pack(orig(canvas, ...))
    local s = r[1]
    if not (canvas and canvas.getPixelWidth and s and s.getPixelWidth) then return Hooks.unpack(r) end
    local pw, ph = canvas:getPixelWidth(), canvas:getPixelHeight()
    if s:getPixelWidth() == pw and s:getPixelHeight() == ph then return Hooks.unpack(r) end
    s = love.graphics.newCanvas(pw, ph, {format = "stencil8", readable = false, dpiscale = 1})
    SMODS.stencil_canvas = s
    return s
end end, {id = "overhaul.stencil"})
