local root = ROOT or 'assets/'
local shown = false
love = {keyboard = {setTextInput = function(on) shown = on end}, update = function() end}
G = {FUNCS = {}, CONTROLLER = {}, SETTINGS = {ingame_keyboard = false}, F_MOBILE = true}
G.FUNCS.text_input = function(e) end
G.FUNCS.select_text_input = function(e) G.CONTROLLER.text_input_hook = e end
package.loaded['overhaul.hooks'] = assert(loadfile(root .. 'overhaul/hooks.lua'))()
assert(loadfile(root .. 'overhaul/ingame_keyboard.lua'))()
local fails = 0
local function check(name, cond) if not cond then fails = fails + 1 print('FAIL ' .. name) end end

local function frame(...)
  for _, e in ipairs({...}) do G.FUNCS.text_input(e) end
  love.update(0)
end

local function focus(e)
  G.FUNCS.select_text_input(e)
  frame(e)
end

local function fresh()
  G.CONTROLLER.text_input_hook = nil
  G.SETTINGS.ingame_keyboard = false
  IngameKeyboard.sys = nil
  shown = false
  local e = {}
  focus(e)
  return e
end

local a = fresh()
check('opens on focus', shown)

a = fresh()
shown = false
frame(a)
check('stays hidden after Back until tapped', not shown)
G.FUNCS.select_text_input(a)
check('tap brings it back after Back', shown)

a = fresh()
G.CONTROLLER.text_input_hook = nil
a.REMOVED = true
love.update(0)
check('closes with the menu', not shown)

a = fresh()
a.REMOVED = true
love.update(0)
check('removed field still focused closes it', not shown)

a = fresh()
local b = {}
G.CONTROLLER.text_input_hook = b
love.update(0)
check('stays open moving to another field', shown)
frame(b)
check('new field keeps it', shown)

a = fresh()
G.SETTINGS.ingame_keyboard = true
love.update(0)
check('turning the setting on closes it', not shown)

fresh()
G.SETTINGS.ingame_keyboard = true
G.CONTROLLER.text_input_hook = nil
love.update(0)
shown = false
focus({})
check('setting on never opens it', not shown)

print(fails == 0 and 'all system keyboard checks pass' or (fails .. ' failed'))
