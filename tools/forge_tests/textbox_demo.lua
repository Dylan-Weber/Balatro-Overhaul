FTB = FTB or {}
local B = ForgeBuilder

function FTB.open()
  B.new_draft({kind = "joker", name = "Ink Test"})
  JokerForge.ui.open("builder")
end

function FTB.text()
  G.FUNCS.forge_b_text()
end

function FTB.type()
  local st = B.state.text
  HLOG("ftb_focus", tostring(B.text_focused()), "hook", tostring(G.CONTROLLER.text_input_hook == B.TEXT_HOOK))
  for _ = 1, 400 do G.FUNCS.text_input_key({key = "backspace"}) end
  G.FUNCS.forge_b_brush({config = {ref_table = {c = "mult"}}})
  G.FUNCS.text_input_char("+4 Mult")
  G.FUNCS.forge_b_brush({config = {ref_table = {c = "plain"}}})
  G.FUNCS.text_input_char(" when played")
  G.FUNCS.text_input_key({key = "return"})
  G.FUNCS.forge_b_brush({config = {ref_table = {c = "custom"}}})
  st.rgb.r, st.rgb.g, st.rgb.b = 30, 200, 120
  B.text_rgb()
end

function FTB.custom()
  G.FUNCS.forge_b_rgb_use()
  G.FUNCS.text_input_char("Été vert")
  G.FUNCS.text_input_key({key = "left"})
  G.FUNCS.text_input_key({key = "left"})
  G.FUNCS.text_input_key({key = "backspace"})
  local st = B.state.text
  local lines = DE_LINES and DE_LINES(st) or require("functions/forge/forge_desc").from_chars(st.chars)
  HLOG("ftb_lines", table.concat(lines, " / "))
end

function FTB.done()
  G.FUNCS.forge_b_text_done()
  local d = B.state.draft
  local t = d and d.text and d.text[JokerForge.doc and JokerForge.doc.lang and JokerForge.doc.lang() or "en-us"]
  local out = {}
  for k, v in pairs(d and d.text or {}) do out[#out + 1] = k .. "=" .. table.concat(v, " / ") end
  HLOG("ftb_saved", table.concat(out, " ; "), "hook_left", tostring(G.CONTROLLER.text_input_hook ~= nil))
end

function FTB.pause()
  G.FUNCS.options()
end

function FTB.back_click()
  local e = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("forge_try_back_button")
  HLOG("ftb_back_button", tostring(e ~= nil))
  if e then e:click() end
end

function FTB.back_check()
  local d = ForgeBuilder.state.draft
  HLOG("ftb_back", "state", tostring(G.STATE == G.STATES.MENU), "overlay", tostring(G.OVERLAY_MENU ~= nil), "draft", tostring(d and d.id), tostring(d and d.name))
end
