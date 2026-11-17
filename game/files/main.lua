local path = "balatro/main.lua"
local src = assert(love.filesystem.read(path))
local engine = package.loaded["modloader.lovely"]
local chunk, err
if type(engine) == "table" and engine.installed and not LOADING_SCREEN then
	pcall(function() require("overhaul.first_start").run(engine) end)
end
if type(engine) == "table" and engine.installed and engine.needs_patching("main.lua") then
	engine.run_load_now_modules("main.lua")
	chunk, err = engine.compile_patched("main.lua", src, "@main.lua")
else
	chunk, err = loadstring(src, "@main.lua")
end
if not chunk then error(err, 0) end
local guard_ok, StartError = pcall(require, "overhaul.start_error")
local ran, ran_err = xpcall(chunk, function(e)
	if guard_ok then StartError.failed = {msg = e, trace = debug.traceback("", 2)} end
	return e
end, ...)
if guard_ok then pcall(StartError.guard) end
if not ran then error(ran_err, 0) end
