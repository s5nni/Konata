if getgenv().__MituRemoteMapper then
	return getgenv().Dehash
end
if game.PlaceId ~= 10277635599 then
	return
end
getgenv().__MituRemoteMapper = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteMap = {}
local Remotes   = {}

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
			local name   = rawget(v, "Name")
			if typeof(remote) == "Instance" and type(name) == "string" and name ~= "" then
				register(remote, name)
			end
		end
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

task.spawn(function()
	task.wait(2)
	scanGC()
end)

task.spawn(function()
	local Communication = ReplicatedStorage:WaitForChild("Communication")
	watchFolder(Communication:WaitForChild("Events"))
	watchFolder(Communication:WaitForChild("Functions"))
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

function Dehash:FireRemote(name, ...)
	local remote = Remotes[name]
	if not remote then
		return
	end
	if remote:IsA("RemoteEvent") then
		remote:FireServer(...)
	elseif remote:IsA("RemoteFunction") then
		return remote:InvokeServer(...)
	end
end

function Dehash:GetRemotes()
	local copy = {}
	for name, remote in pairs(Remotes) do
		copy[name] = remote
	end
	return copy
end

getgenv().Dehash = Dehash
return Dehash
