local Hooks = require("overhaul.hooks")

local function line_count(lines)
    local n = #lines
    while n > 0 and lines[n] == '' do n = n - 1 end
    return n
end

local function unchanged(e, lines, n)
    local p = e.config.ov_debuff_prev
    if not p or p.n ~= n or p.children ~= #e.children or p.lines ~= lines then return false end
    for i = 1, n do if p[i] ~= lines[i] then return false end end
    return p.vars == lines.vars and p.scale == lines.scale and p.col == lines.text_colour
end

local function remember(e, lines, n)
    local p = e.config.ov_debuff_prev or {}
    for i = n + 1, (p.n or 0) do p[i] = nil end
    for i = 1, n do p[i] = lines[i] end
    p.n, p.children, p.lines = n, #e.children, lines
    p.vars, p.scale, p.col = lines.vars, lines.scale, lines.text_colour
    e.config.ov_debuff_prev = p
end

Hooks.wrap("G.FUNCS", "HUD_blind_debuff", function(orig) return function(e, ...)
    local blind = rawget(_G, "SMODS") and G.GAME and G.GAME.blind
    local lines = blind and blind.loc_debuff_lines
    if not (type(lines) == "table" and e and e.config and e.children and e.UIBox) then return orig(e, ...) end
    local n = line_count(lines)
    if not blind.update_loc_debuff_lines and unchanged(e, lines, n) then return end
    local r = Hooks.pack(orig(e, ...))
    remember(e, lines, n)
    return Hooks.unpack(r)
end end, {id = "overhaul.smods_hud"})
