local R = RunMods

local function L(s) return mod_loc and mod_loc(s) or s end
local function fmt(s, ...) local ok, r = pcall(string.format, L(s), ...) return ok and r or s end

function R.lobby_on(v)
    return not R.empty(R.normalize(v))
end

function R.lobby_info(s)
    local p = R.normalize(type(s) == "table" and s.run_mods or nil)
    if R.empty(p) then return L("Off: plain decks and stakes") end
    local parts = {}
    local decks = #R.deck_keys(p)
    if decks > 0 then parts[#parts + 1] = fmt("Decks mixed in: %d", decks) end
    if #p.off > 0 then parts[#parts + 1] = fmt("Stake effects off: %d", #p.off) end
    return table.concat(parts, ", ")
end

local function lobby()
    local M = rawget(_G, "bom_lobby_settings")
    local bm = rawget(_G, "bom_match")
    return M, bm
end

function R.open_lobby()
    local M, bm = lobby()
    local s = bm and bm.get_settings and bm.get_settings()
    if type(s) ~= "table" then return end
    local edit = M and M.can_edit and M.can_edit() or false
    local deck = s.deck
    if deck == "random" or (type(deck) == "string" and deck:lower():find("random")) then deck = nil end
    local ok, stake = pcall(function() return bm.match_stake and bm.match_stake(s) or tonumber(s.stake) or 1 end)
    R._lobby_ctx = {
        picks = R.normalize(s.run_mods),
        readonly = not edit,
        deck = R.deck_key_of(deck),
        stake = ok and tonumber(stake) or 1,
        lobby = true,
        back_func = 'run_mods_lobby_back',
        commit = function(p)
            local room = rawget(_G, "bom_room")
            if edit and room and room.update_setting then room.update_setting("run_mods", R.normalize(p)) end
        end,
    }
    R._lobby_ctx.reopen = function() R.open(R._lobby_ctx) end
    R.ui.view, R.ui.page = nil, 1
    R.open(R._lobby_ctx)
end

function R.lobby_follow()
    local ctx = R._lobby_ctx
    if not (ctx and ctx.readonly and G.OVERLAY_MENU and UIK and UIK._win) then return end
    local id = UIK._win.id
    if id ~= 'run_mods' and id ~= 'run_mods_stakes' then return end
    local _, bm = lobby()
    local s = bm and bm.get_settings and bm.get_settings()
    if type(s) ~= "table" then return end
    local p = R.normalize(s.run_mods)
    ctx.picks.decks, ctx.picks.off = p.decks, p.off
    UIK.refresh()
end

local function hook_follow()
    local M = lobby()
    if R._follow_hooked or not (M and M.on_settings_changed) then return end
    R._follow_hooked = true
    local orig = M.on_settings_changed
    M.on_settings_changed = function(...)
        local r = orig(...)
        pcall(R.lobby_follow)
        return r
    end
end

G.FUNCS.run_mods_lobby = function()
    pcall(hook_follow)
    R.open_lobby()
end

G.FUNCS.run_mods_lobby_back = function()
    local M = lobby()
    R._lobby_ctx = nil
    if M and M.show then M.show("match") else G.FUNCS.exit_overlay_menu() end
end

if mod_loc_register then mod_loc_register{
    fr = {
        ["Off: plain decks and stakes"] = "Coupé : jeux et mises normaux",
        ["Decks mixed in: %d"] = "Jeux mélangés : %d",
        ["Stake effects off: %d"] = "Effets de mise coupés : %d",
    },
    es = {
        ["Off: plain decks and stakes"] = "Apagado: barajas y pozos normales",
        ["Decks mixed in: %d"] = "Barajas mezcladas: %d",
        ["Stake effects off: %d"] = "Efectos del pozo apagados: %d",
    },
} end

return R
