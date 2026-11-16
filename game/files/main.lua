local path = "balatro/main.lua"
local src = assert(love.filesystem.read(path))
local engine = package.loaded["modloader.lovely"]
local chunk, err
if type(engine) == "table" and engine.installed and engine.needs_patching("main.lua") then
	engine.run_load_now_modules("main.lua")
	chunk, err = engine.compile_patched("main.lua", src, "@main.lua")
else
	chunk, err = loadstring(src, "@main.lua")
end
if not chunk then error(err, 0) end
chunk(...)
