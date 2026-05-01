if getgenv().__DehashLoaded then
	return print(string.rep("\nDehasher: Already loaded\n", 100))
end
getgenv().__DehashLoaded = true

------------------------------------------------------------------------
-- CORE TABLES
------------------------------------------------------------------------
local Dehash = {}
Dehash.StoredRemotes  = {}
Dehash.ForcedRemotes  = {}
Dehash.BlockedRemotes = {}
Dehash.SpiedRemotes   = {}
Dehash.OnCallRemotes  = {}

------------------------------------------------------------------------
-- INTERNAL HELPERS
------------------------------------------------------------------------
local function isValidRemote(obj)
	return typeof(obj) == "Instance"
		and obj.Parent ~= nil
		and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
end

local function getEntry(name)
	return Dehash.StoredRemotes[name]
end

local function makeEntry(remote)
	return {
		Remote = remote,
		Path   = remote:GetFullName(),
		Class  = remote.ClassName,
	}
end

local function attachCleanup(name, remote)
	remote.Destroying:Connect(function()
		Dehash.StoredRemotes[name]  = nil
		Dehash.BlockedRemotes[name] = nil
		Dehash.ForcedRemotes[name]  = nil
		Dehash.SpiedRemotes[name]   = nil
		Dehash.OnCallRemotes[name]  = nil
	end)
end

------------------------------------------------------------------------
-- CENTRALIZED NAMECALL HOOK
-- Single hook handles: blocking, forcing, spying, onCall dispatch
------------------------------------------------------------------------
local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	local method = getnamecallmethod()

	if method == "FireServer" or method == "InvokeServer" then
		-- find matching entry by remote instance
		local matchedName
		for name, entry in pairs(Dehash.StoredRemotes) do
			if entry.Remote == self then
				matchedName = name
				break
			end
		end

		if matchedName then
			-- blocking
			if Dehash.BlockedRemotes[matchedName] then
				return
			end

			local args = { ... }

			-- spy dispatch (non blocking, runs in separate thread)
			local spyEntry = Dehash.SpiedRemotes[matchedName]
			if spyEntry and spyEntry.active then
				task.spawn(spyEntry.callback, #args > 0 and args or nil)
			end

			-- onCall dispatch
			local callEntry = Dehash.OnCallRemotes[matchedName]
			if callEntry and callEntry.active then
				task.spawn(callEntry.callback)
			end

			-- forcing (merges only specified indexes)
			local forceEntry = Dehash.ForcedRemotes[matchedName]
			if forceEntry and forceEntry.active then
				for index, value in pairs(forceEntry.args) do
					args[index] = value
				end
				return originalNamecall(self, table.unpack(args))
			end
		end
	end

	return originalNamecall(self, ...)
end))

------------------------------------------------------------------------
-- ScanPath
-- manually scans a target instance and registers all remotes inside it
------------------------------------------------------------------------
function Dehash:ScanPath(target)
	assert(typeof(target) == "Instance", "Dehash:ScanPath - expected Instance, got " .. typeof(target))

	local found = 0
	local function scanDescendants(obj)
		for _, child in ipairs(obj:GetDescendants()) do
			if isValidRemote(child) then
				local name = child.Name
				-- avoid duplicate overwrite, append path suffix if name collides
				if self.StoredRemotes[name] and self.StoredRemotes[name].Remote ~= child then
					name = child:GetFullName()
				end
				if not self.StoredRemotes[name] then
					self.StoredRemotes[name] = makeEntry(child)
					attachCleanup(name, child)
					found += 1
				end
			end
		end
	end

	pcall(scanDescendants, target)

	-- watch for new remotes added after scan
	target.DescendantAdded:Connect(function(child)
		if isValidRemote(child) then
			local name = child.Name
			if self.StoredRemotes[name] and self.StoredRemotes[name].Remote ~= child then
				name = child:GetFullName()
			end
			if not self.StoredRemotes[name] then
				self.StoredRemotes[name] = makeEntry(child)
				attachCleanup(name, child)
			end
		end
	end)

	print("Dehash:ScanPath - found " .. found .. " remotes in " .. target:GetFullName())
end

------------------------------------------------------------------------
-- ClearCache
-- clears specified cache tables
-- usage: Dehash:ClearCache({"Stored", "Blocked"})
------------------------------------------------------------------------
function Dehash:ClearCache(options)
	local map = {
		Stored  = "StoredRemotes",
		Forced  = "ForcedRemotes",
		Blocked = "BlockedRemotes",
		Spied   = "SpiedRemotes",
		OnCall  = "OnCallRemotes",
	}
	for _, key in ipairs(options) do
		local field = map[key]
		if field then
			table.clear(self[field])
			print("Dehash:ClearCache - cleared " .. key)
		else
			warn("Dehash:ClearCache - unknown option: " .. tostring(key))
		end
	end
end

------------------------------------------------------------------------
-- FireRemote
-- fires a remote by name using indexed args table
-- args are not required
------------------------------------------------------------------------
function Dehash:FireRemote(name, args)
	local entry = getEntry(name)
	if not entry or not isValidRemote(entry.Remote) then
		warn("Dehash:FireRemote - remote not found: " .. tostring(name))
		return
	end
	if self.BlockedRemotes[name] then
		warn("Dehash:FireRemote - remote is blocked: " .. name)
		return
	end

	local packed = {}
	if args then
		for index, value in pairs(args) do
			packed[index] = value
		end
	end

	if entry.Remote:IsA("RemoteEvent") then
		entry.Remote:FireServer(table.unpack(packed))
	elseif entry.Remote:IsA("RemoteFunction") then
		return entry.Remote:InvokeServer(table.unpack(packed))
	end
end

------------------------------------------------------------------------
-- BlockRemote
-- blocks or unblocks a remote from firing
-- returns a cancellable object
------------------------------------------------------------------------
function Dehash:BlockRemote(name, boolean)
	local entry = getEntry(name)
	if not entry then
		warn("Dehash:BlockRemote - remote not found: " .. tostring(name))
		return
	end

	self.BlockedRemotes[name] = boolean and entry or nil

	return {
		Cancel = function()
			Dehash.BlockedRemotes[name] = nil
		end
	}
end

------------------------------------------------------------------------
-- ForceRemote
-- forces specific arg indexes on a remote
-- returns a cancellable object
-- call :ForceRemote(name, args):Cancel() to stop
------------------------------------------------------------------------
function Dehash:ForceRemote(name, args)
	local entry = getEntry(name)
	if not entry then
		warn("Dehash:ForceRemote - remote not found: " .. tostring(name))
		return
	end

	self.ForcedRemotes[name] = {
		Remote = entry.Remote,
		Path   = entry.Path,
		Class  = entry.Class,
		args   = args or {},
		active = true,
	}

	return {
		Cancel = function()
			if Dehash.ForcedRemotes[name] then
				Dehash.ForcedRemotes[name].active = false
				Dehash.ForcedRemotes[name] = nil
			end
		end
	}
end

------------------------------------------------------------------------
-- GetRemote
-- returns the remote instance by name, nil if not found or dead
------------------------------------------------------------------------
function Dehash:GetRemote(name)
	local entry = getEntry(name)
	if entry and isValidRemote(entry.Remote) then
		return entry.Remote
	end
	return nil
end

------------------------------------------------------------------------
-- SpyRemote
-- spies on a remote, callback receives args table or nil
-- returns a cancellable object
------------------------------------------------------------------------
function Dehash:SpyRemote(name, callback)
	local entry = getEntry(name)
	if not entry then
		warn("Dehash:SpyRemote - remote not found: " .. tostring(name))
		return
	end

	self.SpiedRemotes[name] = {
		Remote   = entry.Remote,
		Path     = entry.Path,
		Class    = entry.Class,
		callback = callback,
		active   = true,
	}

	return {
		Cancel = function()
			if Dehash.SpiedRemotes[name] then
				Dehash.SpiedRemotes[name].active = false
				Dehash.SpiedRemotes[name] = nil
			end
		end,
		IsActive = function()
			return Dehash.SpiedRemotes[name] ~= nil
				and Dehash.SpiedRemotes[name].active == true
		end
	}
end

------------------------------------------------------------------------
-- OnRemoteCall
-- fires callback whenever the game fires this remote
-- callback receives no args, use SpyRemote if you need args
-- returns a cancellable object
------------------------------------------------------------------------
function Dehash:OnRemoteCall(name, callback)
	local entry = getEntry(name)
	if not entry then
		warn("Dehash:OnRemoteCall - remote not found: " .. tostring(name))
		return
	end

	self.OnCallRemotes[name] = {
		Remote   = entry.Remote,
		Path     = entry.Path,
		Class    = entry.Class,
		callback = callback,
		active   = true,
	}

	return {
		Cancel = function()
			if Dehash.OnCallRemotes[name] then
				Dehash.OnCallRemotes[name].active = false
				Dehash.OnCallRemotes[name] = nil
			end
		end,
		IsActive = function()
			return Dehash.OnCallRemotes[name] ~= nil
				and Dehash.OnCallRemotes[name].active == true
		end
	}
end

------------------------------------------------------------------------
-- STATE CHECKS
------------------------------------------------------------------------
function Dehash:IsBlocked(name)
	return self.BlockedRemotes[name] ~= nil
end

function Dehash:IsForced(name)
	return self.ForcedRemotes[name] ~= nil
		and self.ForcedRemotes[name].active == true
end

function Dehash:IsSpied(name)
	return self.SpiedRemotes[name] ~= nil
		and self.SpiedRemotes[name].active == true
end

------------------------------------------------------------------------
-- INFO
------------------------------------------------------------------------
function Dehash:GetRemotePath(name)
	local entry = getEntry(name)
	return entry and entry.Path or nil
end

function Dehash:GetRemoteClass(name)
	local entry = getEntry(name)
	return entry and entry.Class or nil
end

function Dehash:Destroy()
	-- disconnect the namecall hook by restoring the original
	pcall(function()
		restorefunction(originalNamecall)
	end)

	-- cancel all active spies
	for name, entry in pairs(self.SpiedRemotes) do
		if entry.active then
			entry.active = false
		end
	end

	-- cancel all active onCall listeners
	for name, entry in pairs(self.OnCallRemotes) do
		if entry.active then
			entry.active = false
		end
	end

	-- cancel all active forces
	for name, entry in pairs(self.ForcedRemotes) do
		if entry.active then
			entry.active = false
		end
	end

	-- clear all caches
	table.clear(self.StoredRemotes)
	table.clear(self.ForcedRemotes)
	table.clear(self.BlockedRemotes)
	table.clear(self.SpiedRemotes)
	table.clear(self.OnCallRemotes)

	-- remove from genv so it can't be reused
	getgenv().__DehashLoaded = nil
	getgenv().Dehash = nil

	print("Dehash: destroyed successfully")
end

print("Operating for:", game.PlaceId, "At:"..os.time())

getgenv().Dehash = Dehash
return Dehash
