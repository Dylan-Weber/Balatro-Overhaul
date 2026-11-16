local Hooks = require("overhaul.hooks")

local function phone_landscape()
    local PT = rawget(_G, "PHONE_TEXT")
    local PR = rawget(_G, "PORTRAIT")
    return PT and PT.on and PT.on() and not (PR and PR.on and PR.on()) or false
end

local function has_badge(node, d)
    if type(node) ~= "table" or d > 12 then return false end
    if node.config and node.config.id == "smods_mod_badge_text" then return true end
    for _, c in ipairs(node.nodes or {}) do if has_badge(c, d + 1) then return true end end
    return false
end

local function drop_badges(box)
    local list = box and box.nodes and box.nodes[1] and box.nodes[1].nodes and box.nodes[1].nodes[2] and box.nodes[1].nodes[2].nodes
    if type(list) ~= "table" then return end
    local dropped = false
    for i = #list, 1, -1 do
        if has_badge(list[i], 0) then table.remove(list, i); dropped = true end
    end
    local desc = box.nodes[1].nodes[3]
    if dropped and desc and desc.config then desc.config.padding = 0.05 end
end

Hooks.wrap("_G", "create_UIBox_blind_choice", function(orig) return function(kind, run_info, ...)
    local r = Hooks.pack(orig(kind, run_info, ...))
    if rawget(_G, "SMODS") and not run_info and phone_landscape() then pcall(drop_badges, r[1]) end
    return Hooks.unpack(r)
end end, {id = "overhaul.blind_badge"})
