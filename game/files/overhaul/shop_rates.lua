local Hooks = require("overhaul.hooks")

local function rules()
    local g = G.GAME
    g.spectral_rate = g.spectral_rate or 0
    local saved = {joker_rate = g.joker_rate, tarot_rate = g.tarot_rate, planet_rate = g.planet_rate, spectral_rate = g.spectral_rate, playing_card_rate = g.playing_card_rate}
    if g.shop_jokers_disabled then g.joker_rate = 0 end
    if g.shop_tarots_disabled then g.tarot_rate = 0 end
    if g.shop_planets_disabled then g.planet_rate = 0 end
    if g.shop_spectrals_disabled then g.spectral_rate = 0 end
    if g.joker_rate + g.tarot_rate + g.planet_rate + g.playing_card_rate + g.spectral_rate <= 0 then g.playing_card_rate = 1 end
    return function()
        for k, v in pairs(saved) do g[k] = v end
    end
end

Hooks.wrap("SMODS", "create_shop_card", function(orig) return function(...)
    if not G.GAME then return orig(...) end
    local restore = rules()
    local r = Hooks.pack(pcall(orig, ...))
    restore()
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end end, {id = "overhaul.shop_rates"})

return rules
