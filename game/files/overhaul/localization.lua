local Hooks = require("overhaul.hooks")

local Loc = {merged = setmetatable({}, {__mode = "k"})}

local function is_leaf(v)
    return type(v) ~= "table" or v[1] ~= nil or next(v) == nil
end

function Loc.merge(dst, src)
    for k, v in pairs(src) do
        if is_leaf(v) or type(dst[k]) ~= "table" or is_leaf(dst[k]) then
            dst[k] = v
        else
            Loc.merge(dst[k], v)
        end
    end
    return dst
end

function Loc.language()
    local lang = G.SETTINGS and G.SETTINGS.language or "en-us"
    if G.F_ENGLISH_ONLY or not love.filesystem.getInfo("localization/" .. lang .. ".lua") then lang = "en-us" end
    if not love.filesystem.getInfo("overhaul/localization/" .. lang .. ".lua") then lang = "en-us" end
    return lang
end

function Loc.apply(t)
    if type(t) ~= "table" or Loc.merged[t] then return end
    Loc.merged[t] = true
    local chunk = love.filesystem.load("overhaul/localization/" .. Loc.language() .. ".lua")
    local ok, ours = pcall(chunk)
    if ok and type(ours) == "table" then Loc.merge(t, ours) end
end

Hooks.wrap(_G, "init_localization", function(orig) return function(...)
    Loc.apply(G.localization)
    return orig(...)
end end, {id = "overhaul.localization"})

return Loc
