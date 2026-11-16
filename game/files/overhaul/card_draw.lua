local Hooks = require("overhaul.hooks")

local function after(fn)
    return function(orig) return function(self, ...)
        local r = Hooks.pack(orig(self, ...))
        fn(self)
        return Hooks.unpack(r)
    end end
end

Hooks.wrap("SMODS.DrawSteps.back", "func", after(function(self)
    if bom_ranked then bom_ranked.draw_back(self) end
    if TavernApply then TavernApply.draw_back(self) end
end), {id = "overhaul.card_draw.back"})

Hooks.wrap("SMODS.DrawSteps.greyed", "func", after(function(self)
    if bom_ranked then bom_ranked.draw_frame(self) end
end), {id = "overhaul.card_draw.frame"})
