function Sprite:tilt_on_touch()
    self.touch_collide_tilt = true
    return self
end

local Hooks = require("overhaul.hooks")

Hooks.wrap("AnimatedSprite", "animate", function(orig) return function(self, ...)
    local g = G.SETTINGS.GRAPHICS
    if not (SMODS and self.float and g and g.perf_bg_anims == false) then return orig(self, ...) end
    local float = self.float
    self.float = nil
    local r = Hooks.pack(pcall(orig, self, ...))
    self.float = float
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end end, {id = "overhaul.sprite.still_float"})
