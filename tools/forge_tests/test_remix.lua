package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name) end
end

local files, dirs = {}, {}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end if dirs[p] then return {type = "directory"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function(p) dirs[p] = true return true end,
  remove = function(p) files[p] = nil return true end,
  getSaveDirectory = function() return "/save" end,
  getDirectoryItems = function(dir)
    local out = {}
    for p in pairs(files) do
      local name = p:match("^" .. dir:gsub("%p", "%%%0") .. "/([^/]+)$")
      if name then out[#out + 1] = name end
    end
    return out
  end,
}}
package.loaded["functions/fast_fs"] = {write = function(p, d) files[p] = tostring(d) return true end}
mod_loc = function(s) return s end

local json = require("bot.sim.json")
local Store = require("functions/forge/forge_store")
local M = require("functions/forge/forge_mods")
local Remix = require("functions/forge/forge_remix")

local function png(tag)
  local function u32(n) return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256) end
  return "\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(71) .. u32(95) .. "\8\6\0\0\0" .. tag .. string.rep("\0\255\1", 30)
end

local function reset()
  files, dirs = {}, {}
  Store.list, Store.items_list, Store.settings = nil, nil, nil
  M.index, M.list, M.jokers, M.items = nil, {}, {}, {}
end

check("clean one credit", Remix.clean({id = "orig01", name = "Old Pack", author = "Ana"})[1].author == "Ana")
check("clean drops bad ids and repeats", #Remix.clean({{id = "orig01"}, {id = "orig01"}, {id = "BAD"}, {id = "x"}, 5}) == 1)
check("clean empty is nil", Remix.clean({}) == nil and Remix.clean("x") == nil)
check("clean caps at 4", #Remix.clean({{id = "aaaa1"}, {id = "aaaa2"}, {id = "aaaa3"}, {id = "aaaa4"}, {id = "aaaa5"}}) == 4)
check("clean cuts long names", #Remix.clean({id = "orig01", name = string.rep("n", 60)})[1].name == 24)
check("clean default name", Remix.clean({id = "orig01", name = "  "})[1].name == "Forge mod")
local merged = Remix.merge({id = "new001", name = "New"}, {{id = "orig01", name = "Old"}, {id = "new001"}})
check("merge keeps order without repeats", #merged == 2 and merged[1].id == "new001" and merged[2].id == "orig01")
check("credit text", Remix.credit_text({{id = "orig01", name = "Old Pack", author = "Ana"}}) == "Remix of Old Pack by Ana")
check("credit text no author", Remix.credit_text({id = "orig01", name = "Old Pack"}) == "Remix of Old Pack")
check("credit text more", Remix.credit_text({{id = "orig01", name = "A", author = "B"}, {id = "orig02", name = "C"}}) == "Remix of A by B and 1 more")
check("credit text none", Remix.credit_text(nil) == nil)

reset()
local c = Store.put({id = "aaa111", name = "Thief", remix = {{id = "orig01", name = "Old Pack", author = "Ana"}}})
check("store keeps a joker credit", c and c.remix and c.remix[1].id == "orig01")
c = Store.put({id = "aaa111", name = "Thief 2"})
check("store keeps the credit when the Builder saves without it", c and c.remix and c.remix[1].author == "Ana" and Store.get("aaa111").name == "Thief 2")
local it = Store.put_item({id = "ttt111", kind = "tarot", name = "Coin", fields = {}, effects = {}, remix = {id = "orig01", name = "Old Pack", author = "Ana"}})
check("store keeps an item credit", it and it.remix and it.remix[1].name == "Old Pack")
it = Store.put_item({id = "ttt111", kind = "tarot", name = "Coin 2", fields = {}, effects = {}})
check("store keeps an item credit on resave", it and it.remix and it.remix[1].id == "orig01")
local d = Store.duplicate("aaa111", "copy")
check("duplicate keeps the credit", d and d.remix and d.remix[1].id == "orig01")
local plain = Store.put({id = "bbb222", name = "Plain"})
check("plain creation has no credit", plain and plain.remix == nil)

local raw, out = M.pack({id = "pack01", name = "Remix Pack", author = "Bo"}, {"aaa111", "ttt111", "bbb222"})
check("pack carries the credit", raw and out.remix and #out.remix == 1 and out.remix[1].id == "orig01" and out.remix[1].author == "Ana")
local raw2, out2 = M.pack({id = "orig01", name = "Self"}, {"aaa111"})
check("pack drops a credit to itself", raw2 and out2.remix == nil)
local _, out3 = M.pack({name = "No credit"}, {"bbb222"})
check("pack without remix has no field", out3 and out3.remix == nil)
local parsed = M.parse(raw)
check("parse keeps the pack credit", parsed and parsed.remix and parsed.remix[1].name == "Old Pack")
check("parse keeps the creation credit", parsed and parsed.jokers[1].remix and parsed.jokers[1].remix[1].id == "orig01")

reset()
files["forge/art/hthief.png"] = png("H")
local other = json.encode({
  format = "forgemod", v = 16, id = "orig01", name = "Old Pack", author = "Ana", about = {"Hearts"}, version = 3, made = 1,
  jokers = {{id = "hthief", name = "Heart Thief", rarity = 2, cost = 5, art = {file = "forge/art/hthief.png"},
    rules = {{when = "card_scored", give = {{id = "change", what = "enhancement", v = "m_forge_enh777"}}}}}},
  creations = {{id = "enh777", kind = "enhancement", name = "Tangerine", fields = {}, effects = {}}},
  files = {hthief = M.b64_encode(png("H"))},
})
files["forge/art/hthief.png"] = nil
local inst = M.install(other)
check("install the other player's mod", inst and inst.id == "orig01" and not inst.mine)
check("installed joker art exists", files["forge/art/fm_orig01_hthief.png"] ~= nil)
check("nothing own yet", #Store.all() == 0 and #Store.items() == 0)
check("remix of own mod refused", select(2, Remix.copy("nope00")) == "gone")
local ids = Remix.copy("orig01")
check("remix copies every creation", ids and #ids == 2)
local j, e
for _, x in ipairs(Store.all()) do j = x end
for _, x in ipairs(Store.items()) do e = x end
check("remixed joker is own with a new id", j and j.id ~= "orig01hthief" and j.mod_id == nil and j.name == "Heart Thief")
check("remixed joker credits the original", j and j.remix and j.remix[1].id == "orig01" and j.remix[1].author == "Ana")
check("remixed item credits the original", e and e.remix and e.remix[1].name == "Old Pack")
check("remixed joker has its own art file", j and j.art and j.art.file == Store.art_path(j.id) and files[j.art.file] == files["forge/art/fm_orig01_hthief.png"])
local g = j and j.rules and j.rules[1] and j.rules[1].give and j.rules[1].give[1]
check("remixed rule points at the remixed enhancement", g and e and g.v == "m_forge_" .. e.id)
local rraw, rout = M.pack({name = "Old Pack Remix", author = "Bo"}, ids)
check("remix pack credits the original", rraw and rout.remix and rout.remix[1].id == "orig01" and rout.remix[1].name == "Old Pack")
local ok_json, t = pcall(json.decode, rraw)
check("remix pack json has the credit", ok_json and t.remix and t.remix[1].author == "Ana")
M.delete("orig01")
check("deleting the original keeps the remix art", j and files[j.art.file] ~= nil)
inst = M.install(other)
local twice = Remix.copy("orig01")
local seen, dup = {}, false
for _, x in ipairs(Store.all()) do if seen[x.id] then dup = true end seen[x.id] = true end
check("second remix gets fresh ids", twice and #twice == 2 and not dup and #Store.all() == 2)

print(string.format("%d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
