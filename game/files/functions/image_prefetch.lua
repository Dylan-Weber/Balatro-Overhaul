local IP = {}
IP.__index = IP

local DECODER = [[
    require("love.image")
    local jobs, results = ...
    while true do
        local job = jobs:demand()
        if type(job) ~= "table" then break end
        local ok, data = pcall(love.image.newImageData, job[2])
        job[2]:release()
        results:push({job[1], ok and data or false})
    end
]]

function IP.new(max_workers)
    if not (love.thread and love.thread.newThread and love.image) then return nil end
    local cores = love.system and love.system.getProcessorCount and love.system.getProcessorCount() or 2
    local workers = math.max(1, math.min(max_workers or 8, cores - 1))
    local self = setmetatable({jobs = love.thread.newChannel(), results = love.thread.newChannel(), want = {}, ready = {}, threads = {}}, IP)
    for _ = 1, workers do
        local ok, t = pcall(love.thread.newThread, DECODER)
        if ok and t and pcall(t.start, t, self.jobs, self.results) then self.threads[#self.threads + 1] = t end
    end
    if #self.threads == 0 then return nil end
    return self
end

function IP:queue(path, file_data)
    if self.want[path] then
        self.want[path] = self.want[path] + 1
        file_data:release()
        return
    end
    self.want[path] = 1
    self.jobs:push({path, file_data})
end

function IP:close_queue()
    for _ = 1, #self.threads do self.jobs:push(false) end
end

function IP:has(path)
    return self.want[path] ~= nil
end

function IP:take(path)
    local left = self.want[path]
    if not left then return nil end
    if LOADING_SCREEN then LOADING_SCREEN.draw() end
    while self.ready[path] == nil do
        local r = self.results:demand(1 / 60)
        if r then self.ready[r[1]] = r[2] end
        if LOADING_SCREEN then LOADING_SCREEN.draw() end
    end
    local data = self.ready[path]
    if left > 1 then
        self.want[path] = left - 1
        if data then data = data:clone() end
    else
        self.want[path], self.ready[path] = nil, nil
    end
    return data or nil
end

function IP:stop()
    self.jobs:clear()
    self:close_queue()
    for _, data in pairs(self.ready) do if data then data:release() end end
    self.ready, self.want = {}, {}
    repeat
        local r = self.results:pop()
        if r and r[2] then r[2]:release() end
    until not r
end

function IP:take_kept(path)
    if not self.want[path] then return nil end
    if LOADING_SCREEN then LOADING_SCREEN.draw() end
    while self.ready[path] == nil do
        local r = self.results:demand(1 / 60)
        if r then self.ready[r[1]] = r[2] end
        if LOADING_SCREEN then LOADING_SCREEN.draw() end
    end
    return self.ready[path] or nil
end

local boot = nil

function IP.boot_start(dirs)
    if boot then return end
    local P = IP.new(4)
    local raw_image, raw_shader = love.graphics.newImage, love.graphics.newShader
    boot = {prefetch = P, raw_image = raw_image, raw_shader = raw_shader}
    if P then
        for _, dir in ipairs(dirs) do
            for _, item in ipairs(love.filesystem.getDirectoryItems(dir)) do
                local path = dir .. "/" .. item
                if item:sub(-4):lower() == ".png" then
                    local ok, fd = pcall(love.filesystem.newFileData, path)
                    if ok and fd then P:queue(path, fd) end
                end
            end
        end
        P:close_queue()
    end
    boot.image = function(src, ...)
        if not boot then return raw_image(src, ...) end
        if LOADING_SCREEN then LOADING_SCREEN.draw() end
        local data = type(src) == "string" and boot.prefetch and boot.prefetch:take_kept(src)
        return raw_image(data or src, ...)
    end
    boot.shader = function(...)
        if boot and LOADING_SCREEN then LOADING_SCREEN.draw() end
        return raw_shader(...)
    end
    love.graphics.newImage, love.graphics.newShader = boot.image, boot.shader
end

function IP.boot_stop()
    if not boot then return end
    local b = boot
    boot = nil
    if love.graphics.newImage == b.image then love.graphics.newImage = b.raw_image end
    if love.graphics.newShader == b.shader then love.graphics.newShader = b.raw_shader end
    if b.prefetch then
        b.prefetch.jobs:clear()
        b.prefetch:close_queue()
        b.prefetch.ready, b.prefetch.want = {}, {}
        repeat until not b.prefetch.results:pop()
    end
end

return IP
