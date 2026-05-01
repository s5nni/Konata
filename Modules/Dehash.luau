if getgenv().__RemoteMapper then
    return getgenv().Dehash
end
getgenv().__RemoteMapper = true

local RemoteMap = {}
local Remotes = {}
local BlockedRemotes = {}
local ForcedRemotes = {}
local SearchStorage = {game:GetService("ReplicatedStorage")}

local function register(remote, realName)
    if not (remote and remote.Parent) then return end
    if typeof(remote) ~= "Instance" then return end
    if type(realName) ~= "string" or realName == "" then return end
    RemoteMap[remote] = realName
    Remotes[realName] = remote
end

local function scanGC()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            local remote = rawget(v, "Remote")
            local name = rawget(v, "Name")
            if typeof(remote) == "Instance" and type(name) == "string" and name ~= "" then
                register(remote, name)
            end
        end
    end
end

local function scanStorage()
    for _, storage in ipairs(SearchStorage) do
        pcall(function()
            for _, obj in ipairs(storage:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    register(obj, RemoteMap[obj] or obj.Name)
                end
            end
            storage.DescendantAdded:Connect(function(obj)
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    task.spawn(function()
                        local timeout = tick() + 5
                        while obj.Parent and tick() < timeout do
                            local realName = RemoteMap[obj]
                            if realName then
                                register(obj, realName)
                                return
                            end
                            task.wait(0.1)
                        end
                        if obj and obj.Parent then
                            register(obj, obj.Name)
                        end
                    end)
                end
            end)
        end)
    end
end

do
    local mt = getrawmetatable(game)
    local oldNewIndex = mt.__newindex
    setreadonly(mt, false)
    mt.__newindex = newcclosure(function(t, k, v)
        if k == "Remote" and typeof(v) == "Instance" then
            local realName = rawget(t, "Name")
            if type(realName) == "string" and realName ~= "" then
                task.defer(register, v, realName)
            end
        end
        return oldNewIndex(t, k, v)
    end)
    setreadonly(mt, true)
end

local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local realName = RemoteMap[self] or self.Name

        if BlockedRemotes[realName] then
            return
        end

        local args = {...}

        if ForcedRemotes[realName] then
            local forceData = ForcedRemotes[realName]
            for index, value in pairs(forceData.args) do
                args[index] = value
            end
            return originalNamecall(self, table.unpack(args))
        end
    end
    return originalNamecall(self, ...)
end))

task.spawn(function()
    task.wait(2)
    scanGC()
    scanStorage()
end)

task.spawn(function()
    while true do
        task.wait(5)
        scanGC()
    end
end)

local Dehash = {}

function Dehash:GetRemotes()
    local copy = {}
    for name, remote in pairs(Remotes) do
        copy[name] = remote
    end
    return copy
end

function Dehash:GetRemote(name)
    return Remotes[name] or nil
end

function Dehash:GetName(remote)
    return RemoteMap[remote] or nil
end

function Dehash:HasRemote(name)
    return Remotes[name] ~= nil
end

function Dehash:WaitForRemote(name, duration)
    duration = duration or 10
    local elapsed = 0
    while not Remotes[name] and elapsed < duration do
        task.wait(0.1)
        elapsed += 0.1
    end
    return Remotes[name] or nil
end

function Dehash:FireRemote(name, argsTable)
    local remote = Remotes[name]
    if not remote then
        warn("Dehash: remote not found ->", name)
        return
    end
    if BlockedRemotes[name] then
        warn("Dehash:", name, "is blocked")
        return
    end
    local args = {}
    for index, value in pairs(argsTable) do
        args[index] = value
    end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(table.unpack(args))
    elseif remote:IsA("RemoteFunction") then
        return remote:InvokeServer(table.unpack(args))
    end
end

function Dehash:BlockRemote(name, enabled)
    BlockedRemotes[name] = enabled
end

function Dehash:GetBlockedRemotes()
    local copy = {}
    for name, state in pairs(BlockedRemotes) do
        if state then table.insert(copy, name) end
    end
    return copy
end

function Dehash:ForceRemote(name, enabled, argsTable)
    if not Remotes[name] then
        warn("Dehash: remote not found ->", name)
        return
    end
    if not enabled then
        ForcedRemotes[name] = nil
        return
    end
    ForcedRemotes[name] = {
        args = argsTable or {},
        keepForcing = enabled
    }
end

function Dehash:GetForcedRemotes()
    local copy = {}
    for name, data in pairs(ForcedRemotes) do
        copy[name] = data
    end
    return copy
end

function Dehash:SpyRemote(name, callback)
    if not Remotes[name] then
        warn("Dehash: remote not found ->", name)
        return
    end
    local remote = Remotes[name]
    local active = true

    local spyNamecall
    spyNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if active and self == remote and (method == "FireServer" or method == "InvokeServer") then
            local args = {...}
            if BlockedRemotes[name] then return end
            callback(#args > 0 and args or nil)
            if ForcedRemotes[name] then
                local forceData = ForcedRemotes[name]
                for index, value in pairs(forceData.args) do
                    args[index] = value
                end
                return spyNamecall(self, table.unpack(args))
            end
        end
        return spyNamecall(self, ...)
    end))

    return {
        Cancel = function()
            active = false
            restorefunction(spyNamecall)
        end,
        IsActive = function()
            return active
        end
    }
end

function Dehash:OnClientEvent(name, callback)
    local remote = Remotes[name]
    if not remote then
        warn("Dehash: remote not found ->", name)
        return
    end
    if not remote:IsA("RemoteEvent") then
        warn("Dehash:", name, "is not a RemoteEvent")
        return
    end
    remote.OnClientEvent:Connect(function(...)
        if BlockedRemotes[name] then return end
        callback(...)
    end)
end

function Dehash:SetSearchStorage(storageTable)
    SearchStorage = storageTable
    scanStorage()
end

getgenv().Dehash = Dehash
return Dehash
