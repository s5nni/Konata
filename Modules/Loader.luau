assert(getgenv, "Executor does not support getgenv")
assert(request, "Executor does not support request")

-- Reject if already running
if getgenv().__MituRunning == true then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Rejected, Reason: "..getgenv().__Mitulib.Reason,
		color    = Color3.fromRGB(80, 125, 215),
		duration = 10,
	})
	return
end

--> Initialize globals
getgenv().__MituRunning = true
getgenv().__Mitulib = {
	Reason = "Not provided.",
	_CachedApps = nil,
	_CachedSettings = nil,
}

--> Load modules
local Mitulib = getgenv().__Mitulib

if Mitulib.Source == nil then
	Mitulib.Source = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Source.luau", false))()
end
if Mitulib.Runtime == nil then
	Mitulib.Runtime = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Runtime.luau", false))()
end
if Mitulib.Encode == nil then
	Mitulib.Encode = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Encode.luau", false))()
end
if Mitulib.Database == nil then
	local DatabaseLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Database.luau", false))()
	-- Firebase secret should be retrieved from environment or secure storage, not hardcoded
	local firebaseSecret = os.getenv("FIREBASE_SECRET") or "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX"
	Mitulib.Database = DatabaseLib:New({
		Url    = "https://mitu-gg-default-rtdb.firebaseio.com",
		Secret = firebaseSecret,
	})
end

--> Shared helpers with caching
local function getApps()
	if Mitulib._CachedApps then
		return Mitulib._CachedApps
	end
	if Mitulib.Database:Exists("Apps") == false then return nil end
	local apps = Mitulib.Database:Get("Apps")
	if apps then
		-- Precompute place IDs as numbers for faster lookup
		for ID, Data in next, apps do
			Data._NumericID = tonumber(ID)
			if Data.SubPlaces then
				for SubID in next, Data.SubPlaces do
					Data.SubPlaces[SubID] = {
						_NumericID = tonumber(SubID),
						Type = Data.SubPlaces[SubID],
					}
				end
			end
		end
		Mitulib._CachedApps = apps
	end
	return apps
end

local function getSettings()
	if Mitulib._CachedSettings then
		return Mitulib._CachedSettings
	end
	if Mitulib.Database:Exists("Settings") == false then return nil end
	local settings = Mitulib.Database:Get("Settings")
	if settings then
		Mitulib._CachedSettings = settings
	end
	return settings
end

local function findPlaceData(Apps)
	local currentPlaceId = game.PlaceId
	
	-- Search main places
	for ID, Data in next, Apps do
		if currentPlaceId == (Data._NumericID or tonumber(ID)) then
			return Data, "main"
		end
	end
	
	-- Search subplaces
	for ID, Data in next, Apps do
		if Data.Settings.AllowSubPlaces == true and Data.SubPlaces then
			for SubID, SubData in next, Data.SubPlaces do
				if currentPlaceId == (SubData._NumericID or tonumber(SubID)) then
					return Data, "sub"
				end
			end
		end
	end
	
	return nil, nil
end

local function resolveScriptType(placeData, placeType)
	if placeType == "sub" then
		for SubID, SubData in next, placeData.SubPlaces do
			if game.PlaceId == (SubData._NumericID or tonumber(SubID)) then
				return SubData.Type
			end
		end
	end
	return placeData.Place.Type
end

local function launch(placeData, placeType, Settings)
	local ok, Encoded = pcall(Mitulib.Encode.Encode, placeData.Settings.Key, placeData.Settings.Seed)
	if not ok then
		Mitulib.Reason = "Encoding failed, try again. ("..tostring(Encoded)..")"
		getgenv().__MituRunning = false
		return false
	end
	
	Mitulib._PassKey = Encoded
	local scriptType = resolveScriptType(placeData, placeType)
	local scriptUrl = Settings.AppsPath..scriptType..".luau"
	
	-- Improved error handling for script loading
	local scriptOk, scriptResult = pcall(function()
		return loadstring(game:HttpGet(scriptUrl, false))(Encoded)
	end)
	
	if not scriptOk then
		Mitulib.Reason = "Script execution failed: "..tostring(scriptResult)
		getgenv().__MituRunning = false
		return false
	end
	
	return true
end

--> Vararg shortcut (bypass auth if valid encoded key is provided)
local Varargs = ...
if Varargs ~= nil and type(Varargs) == "string" and Varargs ~= "" then
	local Apps     = getApps()
	local Settings = getSettings()
	if Apps and Settings then
		local placeData, placeType = findPlaceData(Apps)
		if placeData and placeData.Settings.AllowExecution == true then
			local ok, decoded = pcall(Mitulib.Encode.Decode, Varargs, placeData.Settings.Seed)
			if ok and decoded == placeData.Settings.Key then
				Mitulib._PassKey = Varargs
				local scriptType = resolveScriptType(placeData, placeType)
				local scriptOk, scriptResult = pcall(function()
					return loadstring(game:HttpGet(Settings.AppsPath..scriptType..".luau", false))(Varargs)
				end)
				if not scriptOk then
					warn("Konata: Vararg script execution failed - "..tostring(scriptResult))
				end
				return
			end
		end
	end
	-- Invalid vararg — fall through to normal flow silently
end

--> Settings check (cache result)
local Settings = getSettings()
if Settings == nil then
	Mitulib.Reason = "Service unavailable, try again later."
	getgenv().__MituRunning = false
	return
end
if Settings.AllowLaunching == false then
	Mitulib.Reason = "Launching is currently disabled."
	getgenv().__MituRunning = false
	return
end

--> Apps check (cache result)
local Apps = getApps()
if Apps == nil then
	Mitulib.Reason = "Apps registry is unavailable, try again later."
	getgenv().__MituRunning = false
	return
end

--> Place lookup
local placeData, placeType = findPlaceData(Apps)
if placeData == nil then
	Mitulib.Reason = "This game is not supported."
	getgenv().__MituRunning = false
	return
end

--> Execution check
if placeData.Settings.AllowExecution == false then
	Mitulib.Reason = "Execution is not allowed for this game."
	getgenv().__MituRunning = false
	return
end

--> SubPlace check
if placeType == "sub" and placeData.Settings.AllowSubPlaces == false then
	Mitulib.Reason = "SubPlace access is not allowed for this game."
	getgenv().__MituRunning = false
	return
end

--> Version check
if placeData.Settings.RejectVersionCheck == false then
	if placeData.Place.Version ~= game.PlaceVersion then
		Mitulib.Reason = "Script is outdated, wait for an update. (Game: "..game.PlaceVersion.." | Script: "..placeData.Place.Version..")"
		getgenv().__MituRunning = false
		return
	end
end

--> Users check
if Mitulib.Database:Exists("Users") == false then
	Mitulib.Reason = "User registry is unavailable, try again later."
	getgenv().__MituRunning = false
	return
end

--> Authentication
local canAccess = false
local accessState = "w"

local Authentication = Mitulib.Source:AddAuthentication({
	Key    = placeData.Settings.Key,
	Method = "Key",
	Icon   = "80203530127401",
})

Authentication:OnSubmit(function()
	local method        = Authentication:GetActiveMethod()
	local authenticated = Authentication:IsAuthenticated()
	local input         = Authentication:GetInput()
	if method == "Key" then
		if authenticated then
			canAccess = true
			Authentication:Close()
		end
	elseif method == "Token" then
		-- TODO: Replace hardcoded token with database validation
		-- Token validation should check against Users registry
		local Users = Mitulib.Database:Exists("Users") and Mitulib.Database:Get("Users") or {}
		if Users[input] then
			canAccess = true
			Authentication:Close()
		end
	end
end)

Authentication:OnClose(function()
	Mitulib.Reason = "Authentication cancelled, please rejoin."
	accessState = "c"
	Authentication:Close()
end)

repeat task.wait(1)
	if accessState == "c" then
		getgenv().__MituRunning = false
		return
	end
until canAccess == true

--> Launch
local launchSuccess = launch(placeData, placeType, Settings)
if not launchSuccess then
	-- Show error notification
	Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Launch failed: "..Mitulib.Reason,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 10,
	})
	getgenv().__MituRunning = false
end
