local assets_root = ROOT or 'assets/'
local keyboard_shown = false
love = {keyboard = {setTextInput = function(enabled) keyboard_shown = enabled end}, update = function() end}
G = {FUNCS = {}, CONTROLLER = {}, SETTINGS = {ingame_keyboard = false}, F_MOBILE = true}
G.FUNCS.text_input = function(field) end
G.FUNCS.select_text_input = function(field) G.CONTROLLER.text_input_hook = field end
package.loaded['overhaul.hooks'] = assert(loadfile(assets_root .. 'overhaul/hooks.lua'))()
assert(loadfile(assets_root .. 'overhaul/ingame_keyboard.lua'))()
local failures = 0
local function check(name, passed) if not passed then failures = failures + 1 print('FAIL ' .. name) end end

local function run_frame(...)
  for _, field in ipairs({...}) do G.FUNCS.text_input(field) end
  love.update(0)
end

local function focus(field)
  G.FUNCS.select_text_input(field)
  run_frame(field)
end

local function focus_new_field()
  G.CONTROLLER.text_input_hook = nil
  G.SETTINGS.ingame_keyboard = false
  IngameKeyboard.sys = nil
  keyboard_shown = false
  local field = {}
  focus(field)
  return field
end

local field = focus_new_field()
check('opens on focus', keyboard_shown)

field = focus_new_field()
keyboard_shown = false
run_frame(field)
check('stays hidden after Back until tapped', not keyboard_shown)
G.FUNCS.select_text_input(field)
check('tap brings it back after Back', keyboard_shown)

field = focus_new_field()
G.CONTROLLER.text_input_hook = nil
love.update(0)
check('closes with the menu', not keyboard_shown)

field = focus_new_field()
local other_field = {}
G.CONTROLLER.text_input_hook = other_field
love.update(0)
check('stays open moving to another field', keyboard_shown)
run_frame(other_field)
check('new field keeps it', keyboard_shown)

field = focus_new_field()
G.SETTINGS.ingame_keyboard = true
love.update(0)
check('turning the setting on closes it', not keyboard_shown)

focus_new_field()
G.SETTINGS.ingame_keyboard = true
G.CONTROLLER.text_input_hook = nil
love.update(0)
keyboard_shown = false
focus({})
check('setting on never opens it', not keyboard_shown)

print(failures == 0 and 'all system keyboard checks pass' or (failures .. ' failed'))
os.exit(failures == 0 and 0 or 1)
