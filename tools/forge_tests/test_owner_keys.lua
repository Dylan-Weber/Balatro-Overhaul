package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, got)
  total = total + 1
  if not ok then fails = fails + 1; print("FAIL " .. name .. (got ~= nil and (" got: " .. tostring(got)) or "")) end
end

local files, dirs = {}, {}
love = {filesystem = {
  getInfo = function(p) if files[p] then return {type = "file"} end if dirs[p] then return {type = "directory"} end return nil end,
  read = function(p) if files[p] then return files[p], #files[p] end return nil, "missing" end,
  write = function(p, d) files[p] = d return true end,
  createDirectory = function(p) dirs[p] = true return true end,
  remove = function(p) files[p] = nil return true end,
}}
mod_loc = function(s) return s end
rawset(_G, "get_table_from_string", function(s)
  local f = loadstring(s)
  if not f then return nil end
  local ok, t = pcall(f)
  return ok and t or nil
end)
G = {FUNCS = {}, C = {RED = {}, GREEN = {}, UI = {TEXT_LIGHT = {}}}, E_MANAGER = {add_event = function() end}}
Event = function(t) return t end

local installed, got = {}, {}
local local_mods = {}
package.loaded["functions/forge/forge_mods"] = {
  get = function(id) return local_mods[id] end,
  install = function(raw, opts)
    installed[#installed + 1] = {raw = raw, mine = opts and opts.mine}
    local m = {id = raw, name = "Forged", version = 1, mine = opts and opts.mine or false}
    local_mods[raw] = m
    return m
  end,
}
local edits = {}
rawset(_G, "ForgeModsUI", {open_export = function(id, from, opts) edits[#edits + 1] = {id = id, from = from, version = opts and opts.version, publish = opts and opts.publish} end})

local sent = {}
local KEY_NOW = string.rep("N", 24)
bom_core = {
  player_key = function() return KEY_NOW end,
  send = function(m) sent[#sent + 1] = m return true end,
  is_connected = function() return true end,
}

local O = require("functions/forge/forge_online")
O.with_connection = function(go) return go() end

local A, B, C = string.rep("A", 24), string.rep("B", 24), string.rep("C", 24)

local m = O.merge_keys(A, {A, B, "short", B, 7}, {C, "bad key with spaces!!!!"})
check("merge keeps other valid keys once", #m == 2 and m[1] == B and m[2] == C, table.concat(m, ","))
local many = {}
for i = 1, 12 do many[i] = string.rep(string.char(64 + i), 24) end
check("merge caps the list", #O.merge_keys(nil, many) == O.MAX_KEYS)
check("valid key", O.valid_key(A) and not O.valid_key("A") and not O.valid_key(nil) and not O.valid_key(string.rep("-", 24)))

check("no keys at first", #O.alt_keys(KEY_NOW) == 0)
O.remember(A)
O.remember(B)
O.remember(A)
local ok_keys = O.owner_keys()
check("remembered keys, newest first, once", #ok_keys == 2 and ok_keys[1] == B and ok_keys[2] == A, table.concat(ok_keys, ","))
check("owners file in the forge folder", files["forge/owners.json"] ~= nil)
O.remember("nope")
check("bad key not remembered", #O.owner_keys() == 2)

files["settings.jkr"] = "return {mp_player_key = '" .. C .. "'}"
files["modded_settings.jkr"] = "return {mp_player_key = '" .. KEY_NOW .. "'}"
local sk = O.settings_keys()
check("keys read from plain and modded settings", #sk == 2 and sk[1] == C and sk[2] == KEY_NOW)
files["modded_settings.jkr"] = "not a table"
check("broken settings file skipped", #O.settings_keys() == 1)

local alts = O.alt_keys(KEY_NOW)
check("alt keys join both sources without the current one", #alts == 3 and alts[1] == B and alts[2] == A and alts[3] == C, table.concat(alts, ","))

O.send({type = "forge_browse", page = 1, mine = true})
local last = sent[#sent]
check("send carries the current key", last.pkey == KEY_NOW)
check("send carries the old keys", type(last.keys) == "table" and #last.keys == 3)
local kept = O.owner_keys()
check("current key remembered for later", kept[1] == KEY_NOW)
check("keys found in settings remembered too", #kept == 4 and kept[4] == C, table.concat(kept, ","))
files["settings.jkr"] = nil
check("old key still known once the settings file is gone", #O.alt_keys(KEY_NOW) == 3)
O.remember(KEY_NOW)
check("remember twice writes nothing new", #O.owner_keys() == 4)

files = {}
O.send({type = "forge_browse", page = 1})
check("no keys field when there is nothing else", sent[#sent].keys == nil)

O.update("ecjsm3", 1)
check("update without a local copy gets it first", sent[#sent].type == "forge_get" and sent[#sent].id == "ecjsm3")
check("update waits to edit", O.state.want.ecjsm3 and O.state.want.ecjsm3.mine == true and O.state.want.ecjsm3.edit == 1)
O.on_mod({ok = true, id = "ecjsm3", mod = "ecjsm3"})
check("old server answer still installs it as mine", installed[#installed].mine == true)
check("then opens the edit to publish", #edits == 1 and edits[1].id == "ecjsm3" and edits[1].from == "online" and edits[1].publish == true and edits[1].version == 1)
check("want cleared", O.state.want.ecjsm3 == nil)

O.on_mod({ok = true, id = "zz11", mod = "zz11", mine = true})
check("new server mine flag installs as mine", installed[#installed].mine == true)
O.on_mod({ok = true, id = "yy22", mod = "yy22"})
check("other players' mods stay not mine", not installed[#installed].mine)

local before = #sent
O.update("ecjsm3", 3)
check("update with a local copy edits at once", #sent == before and #edits == 2 and edits[2].version == 3)

local MU_saved = rawget(_G, "ForgeModsUI")
rawset(_G, "ForgeModsUI", nil)
O.update("nolocal", 2)
O.on_mod({ok = true, id = "nolocal", mod = "nolocal"})
check("no crash without the mods UI", local_mods.nolocal ~= nil)
rawset(_G, "ForgeModsUI", MU_saved)

print(string.format("%d checks, %d failed", total, fails))
os.exit(fails == 0 and 0 or 1)
