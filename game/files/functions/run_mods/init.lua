RunMods = RunMods or {}

for _, name in ipairs({"engine", "ui", "lobby"}) do
    local ok, err = pcall(require, "functions/run_mods/" .. name)
    if not ok then print("[RunMods] load " .. name .. ": " .. tostring(err)) end
end

if RunMods.install then
    local ok, err = pcall(RunMods.install)
    if not ok then print("[RunMods] install: " .. tostring(err)) end
end
if RunMods.hook_run_info then pcall(RunMods.hook_run_info) end

return RunMods
