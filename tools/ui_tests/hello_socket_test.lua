package.path = "assets/?.lua;" .. package.path

local fails, total = 0, 0
local function check(name, ok, extra)
    total = total + 1
    if not ok then fails = fails + 1; print("FAIL " .. name .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "")) end
end

love = {timer = {getTime = function() return 100 end}}
local noop = function() end
mp_log = {info = noop, warn = noop, error = noop, debug = noop, enabled = function() return false end}
G = {SETTINGS = {profile = 1, mp_player_key = string.rep("a", 24)}, PROFILES = {{name = "Alice"}}}
bom_room = {game_version = function() return "73" end}

local sent = {}
local ws = {connected = false, opens = 0}
AndroidWS = {
    isConnected = function() return ws.connected end,
    receive = function() return nil end,
    send = function(text) sent[#sent + 1] = text return true end,
    close = function() ws.connected = false end,
    connect = noop,
    lastError = function() return nil end,
    lastStatus = function() return nil end,
    isWaiting = function() return false end,
    openCount = function() return ws.opens end,
}

local function open() ws.opens = ws.opens + 1; ws.connected = true end
local function hellos()
    local n = 0
    for _, s in ipairs(sent) do if s:find('"client_hello"', 1, true) then n = n + 1 end end
    return n
end

local core = dofile("assets/multiplayer/bom_core.lua")

core.update(0.016)
check("no hello while offline", hellos() == 0)

open()
core.update(0.016)
check("hello on the first open", hellos() == 1, hellos())
check("hello carries the build", sent[1] and sent[1]:find('"version":"73"', 1, true) ~= nil, sent[1])
check("hello carries the name", sent[1] and sent[1]:find('"name":"Alice"', 1, true) ~= nil, sent[1])

for _ = 1, 20 do core.update(0.016) end
check("never twice for the same socket", hellos() == 1, hellos())

ws.connected = false
open()
core.update(0.016)
check("socket closed and reopened between two updates still says hello", hellos() == 2, hellos())
core.update(0.016)
check("still one hello for that socket", hellos() == 2, hellos())

ws.connected = false
core.update(0.016)
open()
core.update(0.016)
check("reopen seen over two frames says hello once", hellos() == 3, hellos())

core.disconnect()
open()
core.update(0.016)
core.update(0.016)
check("disconnect then reconnect says hello once", hellos() == 4, hellos())

AndroidWS.openCount = nil
ws.connected = false
core.update(0.016)
ws.connected = true
core.update(0.016)
core.update(0.016)
check("bridge without an open counter keeps the edge rule", hellos() == 5, hellos())

print(string.format("%d/%d passed", total - fails, total))
if fails > 0 then os.exit(1) end
