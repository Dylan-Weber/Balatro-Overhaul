local ok, ffi = pcall(require, "ffi")
if not ok or ffi.os ~= "Linux" then return false end
local appdir = os.getenv("APPDIR")
if not appdir or appdir == "" then return false end
pcall(ffi.cdef, [[
int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
]])
local function strip(name, own)
    local v = os.getenv(name)
    if not v then return end
    local keep = {}
    for part in (v .. ":"):gmatch("([^:]*):") do
        local p = part:gsub("/+$", "")
        if p ~= "" and p ~= own then keep[#keep + 1] = part end
    end
    pcall(function()
        if #keep == 0 then ffi.C.unsetenv(name) else ffi.C.setenv(name, table.concat(keep, ":"), 1) end
    end)
end
local base = appdir:gsub("/+$", "")
strip("LD_LIBRARY_PATH", base .. "/lib")
strip("XDG_DATA_DIRS", base .. "/share")
return true
