if getgenv().__RemoteMapper then
    return getgenv().Dehash
end
getgenv().__RemoteMapper = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteMap = {}
local Remotes = {}
local BlockedRemotes = {}
local ForcedRemotes = {}
local fullSearchEnabled = false

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

local function scanReplicatedStorage()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            register(obj, RemoteMap[obj] or obj.Name)
        end
    end
    ReplicatedStorage.DescendantAdded:Connect(function(obj)
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
end

local function scanEverything()
    for _, service in ipairs(game:GetChildren()) do
        pcall(function()
            for _, obj in ipairs(service:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    register(obj, RemoteMap[obj] or obj.Name)
                end
            end
        end)
    end
    for _, obj in ipairs(getnilinstances()) do
        pcall(function()
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                register(obj, RemoteMap[obj] or obj.Name)
            end
        end)
    end
    scanGC()
end

local function watchFolder(folder)
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local realName = RemoteMap[obj]
            if realName then register(obj, realName) end
        end
    end
    folder.ChildAdded:Connect(function(child)
        if not (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) then return end
        task.spawn(function()
            local timeout = tick() + 5
            while child.Parent and tick() < timeout do
                local realName = RemoteMap[child]
                if realName then
                    register(child, realName)
                    return
                end
                task.wait(0.1)
            end
        end)
    end)
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

task.spawn(function()
    task.wait(2)
    scanGC()
    scanReplicatedStorage()
end)

task.spawn(function()
    while true do
        task.wait(5)
        scanGC()
    end
end)

local Dehash = {}

function Dehash:GetRemote(name)
    return Remotes[name] or nil
end

function Dehash:GetName(remote)
    return RemoteMap[remote] or nil
end

function Dehash:GetRemotes()
    local copy = {}
    for name, remote in pairs(Remotes) do
        copy[name] = remote
    end
    return copy
end

function Dehash:HasRemote(name)
    return Remotes[name] ~= nil
end

function Dehash:WaitForRemote(name, timeout)
    timeout = timeout or 10
    local elapsed = 0
    while not Remotes[name] and elapsed < timeout do
        task.wait(0.1)
        elapsed += 0.1
    end
    return Remotes[name] or nil
end

function Dehash:PrintAll()
    print("=== Dehash Remote Map ===")
    local count = 0
    for name, remote in pairs(Remotes) do
        print("  Name:", name, "| Path:", remote:GetFullName(), "| Type:", remote.ClassName)
        count += 1
    end
    print("  Total:", count, "remotes found")
end

function Dehash:FireRemote(name, ...)
    local remote = Remotes[name]
    if not remote then
        warn("Dehash: remote not found ->", name)
        return
    end
    if BlockedRemotes[name] then
        print("Dehash:", name, "is blocked, not firing")
        return
    end
    local args = {...}
    if ForcedRemotes[name] then
        local forceData = ForcedRemotes[name]
        args = forceData.args
        if not forceData.keepForcing then
            ForcedRemotes[name] = nil
        end
    end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(table.unpack(args))
    elseif remote:IsA("RemoteFunction") then
        return remote:InvokeServer(table.unpack(args))
    end
end

function Dehash:OnClientEvent(name, callback)
    local remote = Remotes[name]
    if not remote then
        warn("Dehash: remote not found ->", name)
        return
    end
    if remote:IsA("RemoteEvent") then
        return remote.OnClientEvent:Connect(callback)
    end
end

function Dehash:BlockRemote(name, enabled)
    BlockedRemotes[name] = enabled
    print("Dehash:", name, enabled and "blocked" or "unblocked")
end

function Dehash:GetBlockedRemotes()
    local copy = {}
    for name, state in pairs(BlockedRemotes) do
        if state then table.insert(copy, name) end
    end
    return copy
end

function Dehash:ForceRemote(name, args, keepForcing)
    if not Remotes[name] then
        warn("Dehash: remote not found ->", name)
        return
    end
    ForcedRemotes[name] = {
        args = args,
        keepForcing = keepForcing
    }
    print("Dehash:", name, "arguments are now forced")
end

function Dehash:UnforceRemote(name)
    ForcedRemotes[name] = nil
    print("Dehash:", name, "force removed")
end

function Dehash:GetForcedRemotes()
    local copy = {}
    for name, data in pairs(ForcedRemotes) do
        copy[name] = data
    end
    return copy
end

function Dehash:SpyRemote(name, callback)
    local remote = Remotes[name]
    if not remote then
        warn("Dehash: remote not found ->", name)
        return
    end
    local originalNamecall
    originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if self == remote and (method == "FireServer" or method == "InvokeServer") then
            local args = {...}
            callback(name, args)
            if BlockedRemotes[name] then return end
            if ForcedRemotes[name] then
                local forceData = ForcedRemotes[name]
                if not forceData.keepForcing then ForcedRemotes[name] = nil end
                return originalNamecall(self, table.unpack(forceData.args))
            end
        end
        return originalNamecall(self, ...)
    end))
end

function Dehash:SpyAll()
    local originalNamecall
    originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local realName = RemoteMap[self] or self.Name
            local args = {...}
            if BlockedRemotes[realName] then
                print("Dehash [BLOCKED]:", realName)
                return
            end
            if ForcedRemotes[realName] then
                local forceData = ForcedRemotes[realName]
                print("Dehash [FORCED]:", realName, "->", table.unpack(forceData.args))
                if not forceData.keepForcing then ForcedRemotes[realName] = nil end
                return originalNamecall(self, table.unpack(forceData.args))
            end
            print("Dehash [FIRED]:", realName, "| Args:", table.unpack(args))
        end
        return originalNamecall(self, ...)
    end))
    print("Dehash: spying on all remotes")
end

function Dehash:AllowFullSearch(enabled)
    fullSearchEnabled = enabled
    print("Dehash: full search", enabled and "enabled" or "disabled")
    self:Rescan()
end

function Dehash:Rescan()
    scanGC()
    if fullSearchEnabled then
        scanEverything()
    else
        scanReplicatedStorage()
    end
    local count = 0
    for _ in pairs(Remotes) do count += 1 end
    print("Dehash: rescan complete, found", count, "remotes")
end

getgenv().Dehash = Dehash
return Dehash
