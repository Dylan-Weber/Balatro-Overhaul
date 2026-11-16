XCD = {}
local Store = require("functions/forge/forge_store")
function XCD.make()
  Store.ensure_dirs()
  Store.items_list = {}
  Store.put_item({id = "xce", kind = "deck", name = "XC Hand", effects = {{id = "xchips", n = 2, when = "hand_played"}}})
  Store.put_item({id = "xcc", kind = "deck", name = "XC Card", effects = {{id = "xchips", n = 1.5, when = "card_scored"}}})
  Store.put_item({id = "xcr", kind = "deck", name = "XC Rule", mode = "advanced", effects = {}, rules = {{when = "hand_played", only = {}, give = {{id = "xchips", n = 2}}}}})
  Store.put_item({id = "xcs", kind = "deck", name = "XC Rule Card", mode = "advanced", effects = {}, rules = {{when = "card_scored", only = {}, give = {{id = "xchips", n = 1.5}}}}})
  Store.put_item({id = "xcp", kind = "deck", name = "Chips Rule Card", mode = "advanced", effects = {}, rules = {{when = "card_scored", only = {}, give = {{id = "chips", n = 10}}}}})
  Store.put_item({id = "xcn", kind = "deck", name = "Plain", effects = {}})
  ForgeKinds.register_all()
  HLOG("XCD made", tostring(G.P_CENTERS.b_forge_xce ~= nil), tostring(G.P_CENTERS.b_forge_xcr ~= nil))
end
