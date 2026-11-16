local Hooks = require("overhaul.hooks")

local function shop_area(a)
    return a ~= nil and (a == G.shop_jokers or a == G.shop_booster or a == G.shop_vouchers)
end

Hooks.wrap(Card, "set_cost", function(orig) return function(self, ...)
    local game = G.GAME
    if not game then return orig(self, ...) end
    game.discount_percent = game.discount_percent or 0
    game.modifiers = game.modifiers or {}
    local tax = game.multiplayer and shop_area(self.area) and (game.mp_shop_tax or 0) or 0
    if tax == 0 then return orig(self, ...) end
    local inflation = game.inflation
    game.inflation = (inflation or 0) + tax
    local r = Hooks.pack(pcall(orig, self, ...))
    game.inflation = inflation
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end end, {id = "overhaul.card.mp_shop_tax"})
