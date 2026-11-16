local out = assert(os.getenv("IOS_BOOT_OUT"))
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
	local f = io.open(out .. "/boot.log", "a")
	f:write(table.concat(t, " ") .. "\n")
	f:close()
end

if os.getenv("IOS_BOOT_AS_IOS") == "1" then
	love.system.getOS = function() return "iOS" end
end

local install = require("overhaul_install")
local importer = require("ios_import").attach(install)
local runtime = require("ios_runtime")

local plan = install.plan()
log("start", "have", plan.have and plan.have.version or "-", "need", plan.need)
if not (plan.have and not plan.need) then
	local t0 = love.timer.getTime()
	assert(importer.copy_in(assert(os.getenv("IOS_BOOT_PICK"))))
	local ok, code, detail = importer.import_now(function() end)
	log("import", ok, code, detail, string.format("%.1fs", love.timer.getTime() - t0))
	local left = io.open(importer.save_path(importer.PICKED), "rb")
	if left then left:close() end
	log("picked_copy_left", left ~= nil, "official_copy_left", love.filesystem.getInfo(install.COPY) ~= nil)
	log("installed_name", install.installed_name())
	if not ok then
		love.event.quit(1)
		return
	end
end

local frames = 0
local t_menu, done, dismiss_at, dismiss_seen

local function find_tab(node, label)
	if type(node) ~= "table" then return nil end
	local c = node.config
	if c and c.button == "change_tab" and type(c.ref_table) == "table" and c.ref_table.label == label then return node end
	for _, child in pairs(node.children or {}) do
		local hit = find_tab(child, label)
		if hit then return hit end
	end
end

local steps, step_at = {}, nil

local function shot(name)
	return function(g, next_step)
		love.graphics.captureScreenshot(function(img)
			img:encode("png", name .. ".png")
			log("shot", love.filesystem.getSaveDirectory() .. "/" .. name .. ".png")
			next_step()
		end)
		return true
	end
end

local function act(fn)
	return function(g, next_step)
		local ok, err = pcall(fn, g)
		if not ok then log("step_error", err) end
		next_step()
		return true
	end
end

local busy = false
local function run_steps(g)
	if busy or not step_at or love.timer.getTime() < step_at then return end
	local fn = table.remove(steps, 1)
	if not fn then
		step_at = nil
		love.event.quit(0)
		return
	end
	busy = true
	fn(g, function()
		busy = false
		step_at = love.timer.getTime() + 2
	end)
end

local function probe()
	local g = rawget(_G, "G")
	if step_at then return run_steps(g) end
	if done or type(g) ~= "table" or not g.STATES or g.STATE ~= g.STATES.MENU then return end
	if not g.MAIN_MENU_UI then
		if g.OVERLAY_MENU and love.timer.getTime() >= (dismiss_at or 0) then
			dismiss_at = love.timer.getTime() + 3
			if dismiss_seen then
				log("dismiss_popup")
				pcall(g.FUNCS.exit_overlay_menu)
			end
			dismiss_seen = true
		end
		return
	end
	t_menu = t_menu or love.timer.getTime()
	if love.timer.getTime() - t_menu < 4 then return end
	done = true
	local smods = rawget(_G, "SMODS")
	local mods = 0
	if type(smods) == "table" and type(smods.Mods) == "table" then
		for k, m in pairs(smods.Mods) do
			if type(m) == "table" and m.can_load and k ~= "Steamodded" and k ~= "Lovely" and k ~= "Balatro" then mods = mods + 1 end
		end
	end
	log("menu", "os", love.system.getOS(), "version", rawget(_G, "VERSION"), "name", rawget(_G, "OVERHAUL_NAME"),
		"F_MOBILE", g.F_MOBILE, "F_VIDEO_SETTINGS", g.F_VIDEO_SETTINGS, "F_QUIT_BUTTON", g.F_QUIT_BUTTON, "desktop", rawget(_G, "_IS_DESKTOP"),
		"smods", type(smods) == "table", "mods_loaded", mods, "ios_frames", frames, "runtime", runtime.installed)
	steps[#steps + 1] = shot("ios_boot_menu")
	if os.getenv("IOS_BOOT_SCREENS") == "1" then
		steps[#steps + 1] = act(function(g) g.FUNCS.exit_overlay_menu() end)
		steps[#steps + 1] = shot("ios_boot_main")
		steps[#steps + 1] = act(function(g) g.FUNCS.settings() end)
		steps[#steps + 1] = shot("ios_boot_settings")
		steps[#steps + 1] = act(function(g) g.FUNCS.exit_overlay_menu() end)
		steps[#steps + 1] = act(function(g) g.FUNCS.overlay_menu({definition = g.UIDEF.credits()}) end)
		steps[#steps + 1] = act(function(g)
			local tab = g.OVERLAY_MENU and find_tab(g.OVERLAY_MENU.UIRoot, "Overhaul")
			log("credits_tab", tab ~= nil)
			if tab then g.FUNCS.change_tab(tab) end
		end)
		steps[#steps + 1] = shot("ios_boot_credits")
	end
	step_at = love.timer.getTime()
end

require("main_real")

if type(runtime.frame) == "function" then
	local frame = runtime.frame
	local next_status = love.timer.getTime() + 30
	runtime.frame = function(...)
		frames = frames + 1
		if love.timer.getTime() >= next_status then
			next_status = love.timer.getTime() + 30
			local g = rawget(_G, "G")
			local st = type(g) == "table" and g.STATE
			local name = "?"
			if type(g) == "table" and type(g.STATES) == "table" then
				for k, v in pairs(g.STATES) do if v == st then name = k end end
			end
			log("status", string.format("%.0fs", love.timer.getTime()), "frames", frames, "state", name,
				"menu_ui", type(g) == "table" and g.MAIN_MENU_UI ~= nil, "overlay", type(g) == "table" and g.OVERLAY_MENU ~= nil)
			love.graphics.captureScreenshot("ios_boot_wait.png")
		end
		return frame(...)
	end
end
local Game = rawget(_G, "Game")
if type(Game) == "table" and type(Game.update) == "function" then
	local update = Game.update
	Game.update = function(self, ...)
		pcall(probe)
		return update(self, ...)
	end
end
log("launched", "Game", type(Game) == "table", "ios_frame_hook", type(runtime.frame) == "function")
