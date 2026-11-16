CP = {}
local Store = require("functions/forge/forge_store")
local function pool(t)
  local S = rawget(_G, "SMODS")
  local list = S and S.collection_pool and S.collection_pool(t) or {}
  local n = 0
  for _, v in ipairs(list) do if v.forge_kind then n = n + 1 end end
  return n, #list
end
function CP.count(tag)
  local ft, at = pool(G.P_TAGS)
  local fb, ab = pool(G.P_BLINDS)
  print("COLLPROBE", tag, "smods=" .. tostring(rawget(_G, "SMODS") ~= nil), "forge_tags=" .. ft, "all_tags=" .. at, "forge_blinds=" .. fb, "all_blinds=" .. ab)
end
function CP.off()
  Store.get_item("kt2").enabled = false
  Store.get_item("kbl").enabled = false
end
function CP.open(which)
  local ok, err = pcall(function()
    local def = which == "tags" and create_UIBox_your_collection_tags() or create_UIBox_your_collection_blinds()
    G.FUNCS.overlay_menu{definition = def}
  end)
  print("COLLPROBE open", which, ok, tostring(err))
end
