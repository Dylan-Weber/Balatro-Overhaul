package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, got)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (got ~= nil and (" got: " .. tostring(got)) or "")) end
end

local files = {}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function() return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function() return {} end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end
G = {P_CENTERS = {}, P_TAGS = {}, P_BLINDS = {}, P_STAKES = {}, localization = {descriptions = {}}, C = {}}

local Cat = require("functions/forge/forge_catalog")
local D = require("functions/forge/forge_doc")

local ART = {joker = true, tarot = true, planet = true, spectral = true, voucher = true, booster = true, deck = true, enhancement = true, seal = true, tag = true, blind = true, stake = true}
local UNSET = {planet = "hand", blind = "size", booster = "pack", collab = "suit", suit = "colour", hand = "pattern", ctype = "colour", rarity = "colour", sticker = "look", fusion = "out"}
local BASE = {planet = "Levels up", blind = "Size", booster = "Choose", collab = "Face cards", suit = "{C:attention}13{} cards", hand = "4 cards", ctype = "Its own family", rarity = "A new rarity", sticker = "A sticker", fusion = "{C:attention}"}
local SIZE = {tag = {34, 34}, blind = {34, 34}, stake = {29, 29}}

local function png_size(path)
  local f = io.open("assets/" .. path, "rb")
  if not f then return nil end
  local head = f:read(24)
  f:close()
  if not head or head:sub(2, 4) ~= "PNG" then return nil end
  local function u32(i) local a, b, c, d = head:byte(i, i + 3) return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(17), u32(21)
end

local seen = 0
for _, k in ipairs(Cat.KINDS) do
  local id = k.id
  seen = seen + 1
  local d = D.blank(id)
  check(id .. " kind", d.kind == id, d.kind)
  check(id .. " empty name", d.name == "", d.name)
  check(id .. " no rules", type(d.rules) ~= "table" or #d.rules == 0, d.rules and #d.rules)
  check(id .. " no vars", type(d.vars) ~= "table" or #d.vars == 0)
  check(id .. " no effects", type(d.effects) ~= "table" or #d.effects == 0, d.effects and #d.effects)
  check(id .. " no own text", d.text == nil)
  check(id .. " no art yet", d.art == nil)
  local lines = D.lines(d, "en")
  check(id .. " empty description", #lines == 0, lines[1])
  check(id .. " unset only where a setting has no blank value", (D.unset(d) == true) == (UNSET[id] ~= nil), tostring(d.unset))
  local probs = D.problems(d)
  if id == "booster" then
    check(id .. " asks for a name and its contents", #probs == 2 and probs[1] == "Give it a name" and probs[2] == "Pick what it contains", table.concat(probs, " / "))
  else
    check(id .. " only asks for a name", #probs == 1 and probs[1] == "Give it a name", table.concat(probs, " / "))
  end
  d.name = "Blank"
  if id == "booster" then
    check(id .. " still blocked without contents", #D.problems(d) == 1, table.concat(D.problems(d), " / "))
    D.choose(d, "pack")
  end
  check(id .. " saves once named", #D.problems(d) == 0, table.concat(D.problems(d), " / "))
  if UNSET[id] then
    local again = D.blank(id)
    D.choose(again, "cost")
    D.choose(again, "levels")
    check(id .. " other settings keep it unset", D.unset(again) == true and #D.lines(again, "en") == 0)
    D.choose(again, UNSET[id])
    local l2 = D.lines(again, "en")
    check(id .. " picking the setting brings its line", not D.unset(again) and #l2 >= 1 and l2[1]:find(BASE[id], 1, true) == 1, l2[1])
    local kept = D.new(id, {name = "K", unset = true, fields = {}, effects = {}})
    check(id .. " unset survives a reload", D.unset(kept) == true and #D.lines(kept, "en") == 0)
    local tp = D.from_template(id, (D.templates(id) or {})[1] or {key = "x", fields = {}})
    check(id .. " template keeps its values", not D.unset(tp) and #D.lines(tp, "en") >= 1, tp.unset)
  end
  local art = D.blank_art(id)
  if ART[id] then
    check(id .. " art key", art == "resources/textures/1x/forge_blank/" .. id .. ".png", art)
    local w, h = png_size(art or "")
    local want = SIZE[id] or {71, 95}
    check(id .. " art size", w == want[1] and h == want[2], tostring(w) .. "x" .. tostring(h))
  else
    check(id .. " keeps no art", art == nil, art)
  end
end
check("every kind covered", seen == #Cat.KINDS and seen >= 14, seen)

local j = D.blank("joker")
check("joker blank keeps rarity and cost", j.rarity == 1 and j.cost == 4)
local e = D.blank("enhancement")
check("enhancement scores nothing", e.fields.chips == 0 and e.fields.mult == 0 and e.fields.xmult == 1 and e.fields.money == 0)
local tpl = D.new("tarot", {name = "T"})
check("a plain new tarot still gets a starter effect", #tpl.effects == 1)
for _, id in ipairs({"tarot", "spectral", "voucher", "seal", "tag", "blind", "stake", "deck"}) do
  local back = D.new(id, {name = "B", effects = {}, fields = {}})
  check(id .. " saved without effects stays empty when edited", #back.effects == 0, #back.effects)
end
check("empty joker text is empty, not nil", #D.lines({kind = "joker", rules = {}, vars = {}}, "en") == 0)

local ok_store, Store = pcall(require, "functions/forge/forge_store")
if ok_store and Store.clean_item then
  local cl = Store.clean_item({id = "abc", kind = "planet", name = "P", fields = {hand = "Pair"}, unset = true})
  check("store keeps unset", cl and cl.unset == true, cl and cl.unset)
  local cl2 = Store.clean_item({id = "abd", kind = "planet", name = "P", fields = {hand = "Pair"}})
  check("store adds no unset", cl2 and cl2.unset == nil)
else
  check("store loads", false, Store)
end
check("unset ignored for kinds without such a setting", not D.unset({kind = "tarot", unset = true}))

print(string.format("blank: %d / %d", total - fails, total))
if fails > 0 then os.exit(1) end
