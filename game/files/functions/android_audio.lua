-- On Android, OpenAL Soft (1.21) picks its Oboe backend. When Android has already closed
-- the Oboe stream (headphones or Bluetooth disconnecting, the audio server restarting),
-- stopping it throws "Failed to stop stream: ErrorClosed". LOVE pauses the audio device
-- every time the app goes to the background, nothing catches that exception, and the game
-- dies, so the player comes back to a cold start. The OpenSL ES backend reports the same
-- failure without throwing. OpenAL reads ALSOFT_DRIVERS when LOVE opens the audio device,
-- which happens after conf.lua, so conf.lua sets it here. Oboe stays as the fallback.
local android_audio = {}

android_audio.driver_variable = "ALSOFT_DRIVERS"
android_audio.driver_list = "opensl,oboe"

function android_audio.driver_list_to_set(operating_system, existing_driver_list)
    if operating_system ~= "Android" then return nil end
    if existing_driver_list and existing_driver_list ~= "" then return nil end
    return android_audio.driver_list
end

function android_audio.apply(operating_system)
    local driver_list = android_audio.driver_list_to_set(operating_system, os.getenv(android_audio.driver_variable))
    if not driver_list then return false end
    local ffi_loaded, ffi = pcall(require, "ffi")
    if not ffi_loaded then return false end
    pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
    local call_ok, setenv_result = pcall(function()
        return ffi.C.setenv(android_audio.driver_variable, driver_list, 1)
    end)
    return call_ok and setenv_result == 0
end

return android_audio
