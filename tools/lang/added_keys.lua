local Loc = {}
function Loc.merge(dst, src)
  for k, v in pairs(src) do
    local leaf = type(v) ~= "table" or v[1] ~= nil or next(v) == nil
    if leaf or type(dst[k]) ~= "table" or dst[k][1] ~= nil or next(dst[k]) == nil then dst[k] = v else Loc.merge(dst[k], v) end
  end
end
local function load(lang)
  local t = assert(loadfile("assets/localization/" .. lang .. ".lua"))()
  local o = loadfile("assets/overhaul/localization/" .. lang .. ".lua")
  if o then Loc.merge(t, o()) end
  return t
end
local en = load("en-us")
local base = load(arg[1] or "de")
local n = 0
local function walk(e, b, path)
  for k, v in pairs(e) do
    local p = path == "" and tostring(k) or (path .. "." .. tostring(k))
    if b == nil or b[k] == nil then
      n = n + 1
      print(p)
    elseif type(v) == "table" and type(b[k]) == "table" then
      walk(v, b[k], p)
    end
  end
end
walk(en, base, "")
io.stderr:write(n .. "\n")
