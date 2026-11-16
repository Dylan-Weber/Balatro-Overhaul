assert(loadstring(love.filesystem.read("balatro/conf.lua"), "@conf.lua"))()

pcall(require, "functions.win_dpi")
pcall(require, "functions.pure_math")

local modloader_ok, modloader = pcall(require, "modloader.boot")
if modloader_ok and type(modloader) == "table" then
	modloader.start_main = "balatro/main.lua"
	pcall(modloader.hook)
end

local balatro_conf = love.conf
love.conf = function(t)
	balatro_conf(t)
	t.window.fullscreen = true
end
