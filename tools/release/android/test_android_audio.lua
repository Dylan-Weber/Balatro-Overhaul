-- luajit tools/release/android/test_android_audio.lua
-- The Android build must ask OpenAL for its OpenSL ES backend before LOVE opens the audio
-- device: the Oboe backend aborts the game when it pauses a stream Android already closed.
local repo = (arg and arg[0] or ""):match("^(.*)/tools/release/") or "."

local fails = 0
local function check(ok, message)
    if not ok then
        fails = fails + 1
        print("FAIL " .. message)
    end
end

local function read(path)
    local file = assert(io.open(repo .. "/" .. path, "rb"))
    local contents = file:read("*a")
    file:close()
    return contents
end

local android_audio = assert(loadstring(read("assets/functions/android_audio.lua"), "@android_audio.lua"))()

-- which driver list gets set
check(android_audio.driver_list_to_set("Android", nil) == "opensl,oboe", "Android with nothing set gets opensl first, oboe as fallback")
check(android_audio.driver_list_to_set("Android", "") == "opensl,oboe", "Android with an empty variable gets the driver list")
check(android_audio.driver_list_to_set("Android", "oboe") == nil, "a driver list someone already set is kept")
for _, other_system in ipairs({"Windows", "Linux", "OS X", "iOS"}) do
    check(android_audio.driver_list_to_set(other_system, nil) == nil, other_system .. " keeps OpenAL's own choice")
end

-- apply really sets the process environment that OpenAL reads
local ffi_loaded = pcall(require, "ffi")
if ffi_loaded and os.getenv(android_audio.driver_variable) == nil then
    check(android_audio.apply("Linux") == false, "apply does nothing off Android")
    check(os.getenv(android_audio.driver_variable) == nil, "the variable stays unset off Android")
    check(android_audio.apply("Android") == true, "apply reports success on Android")
    check(os.getenv(android_audio.driver_variable) == "opensl,oboe", "ALSOFT_DRIVERS is set in the environment: " .. tostring(os.getenv(android_audio.driver_variable)))
    check(android_audio.apply("Android") == false, "a second apply leaves the variable alone")
else
    print("skipping the environment checks (no ffi, or ALSOFT_DRIVERS already set)")
end

-- conf.lua runs it before LOVE loads its modules (LOVE opens the audio device after conf.lua)
local conf_source = read("assets/conf.lua")
local apply_position = conf_source:find('require("functions.android_audio").apply(love._os)', 1, true)
local conf_position = conf_source:find("love.conf = function", 1, true)
check(apply_position ~= nil, "conf.lua applies the Android audio driver list")
check(apply_position and conf_position and apply_position < conf_position, "conf.lua applies it at load time, not inside love.conf")

local recorded_conf_lua = {}
local sandbox = setmetatable({
    love = {_os = "Android", filesystem = {read = function() return "" end}},
    require = function(module_name)
        if module_name == "functions.android_audio" then
            return {apply = function(operating_system) recorded_conf_lua.operating_system = operating_system end}
        end
        error("not loaded in this test: " .. module_name)
    end,
}, {__index = _G})
local conf_chunk = assert(loadstring(conf_source, "@conf.lua"))
setfenv(conf_chunk, sandbox)
local conf_ok, conf_error = pcall(conf_chunk)
check(conf_ok, "conf.lua runs in the sandbox: " .. tostring(conf_error))
check(recorded_conf_lua.operating_system == "Android", "conf.lua passes love._os to apply: " .. tostring(recorded_conf_lua.operating_system))

if fails == 0 then
    print("android audio: OpenSL ES first on Android, all checks passed")
else
    os.exit(1)
end
