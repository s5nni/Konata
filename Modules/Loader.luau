--[[
	Konata Loader v2
	Secure script loader with authentication, versioning, and caching
	Repository: https://github.com/s5nni/Konata
]]

assert(getgenv, "Executor does not support getgenv")
assert(request, "Executor does not support request")

-- ============================================================================
-- CONSTANTS & CONFIGURATION
-- ============================================================================

local CONFIG = {
	NAME = "Konata",
	UI_COLOR = Color3.fromRGB(80, 125, 215),
	ERROR_COLOR = Color3.fromRGB(215, 80, 80),
	NOTIFICATION_DURATION = 10,
	FIREBASE_URL = "https://mitu-gg-default-rtdb.firebaseio.com",
	MODULES = {
		Source = "https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Source.luau",
		Runtime = "https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Runtime.luau",
		Encode = "https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Encode.luau",
		Database = "https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Database.luau",
	},
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function notify(title, text, color, duration)
	color = color or CONFIG.UI_COLOR
	duration = duration or CONFIG.NOTIFICATION_DURATION
	getgenv().__Mitulib.Source:Notify({
		title = title,
		text = text,
		color = color,
		duration = duration,
	})
end

local function fail(reason)
	getgenv().__Mitulib.Reason = reason
	getgenv().__MituRunning = false
	return false
end

local function safeExecute(fn, errorContext)
	local success, result = pcall(fn)
	if not success then
		warn(("Konata: %s failed - %s"):format(errorContext or "Operation", tostring(result)))
		return false, result
	end
	return true, result
end

-- ============================================================================
-- EARLY TERMINATION CHECK
-- ============================================================================

if getgenv().__MituRunning == true then
	notify(CONFIG.NAME, "Rejected, Reason: " .. getgenv().__Mitulib.Reason, CONFIG.UI_COLOR)
	return
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

getgenv().__MituRunning = true
getgenv().__Mitulib = {
	Reason = "Not provided.",
	_CachedApps = nil,
	_CachedSettings = nil,
	_PlaceIdLookup = nil,
}

local Mitulib = getgenv().__Mitulib

-- ============================================================================
-- MODULE LOADING
-- ============================================================================

local function loadModule(name, url)
	if Mitulib[name] then
		return
	end
	
	local success, result = safeExecute(function()
		return loadstring(game:HttpGet(url, false))()
	end, ("Loading module: %s"):format(name))
	
	if success then
		Mitulib[name] = result
	else
		error(("Failed to load module: %s"):format(name))
	end
end

-- Load all required modules
loadModule("Source", CONFIG.MODULES.Source)
loadModule("Runtime", CONFIG.MODULES.Runtime)
loadModule("Encode", CONFIG.MODULES.Encode)

-- Initialize Database with secure secret handling
if Mitulib.Database == nil then
	local DatabaseLib = loadstring(game:HttpGet(CONFIG.MODULES.Database, false))()
	local firebaseSecret = os.getenv("FIREBASE_SECRET") or "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX"
	Mitulib.Database = DatabaseLib:New({
		Url = CONFIG.FIREBASE_URL,
		Secret = firebaseSecret,
	})
end

-- ============================================================================
-- DATABASE HELPERS WITH CACHING
-- ============================================================================

local function getApps()
	if Mitulib._CachedApps then
		return Mitulib._CachedApps
	end
	
	if not Mitulib.Database:Exists("Apps") then
		return nil
	end
	
	local apps = Mitulib.Database:Get("Apps")
	if apps then
		-- Pre-compute numeric place IDs for faster lookups
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
	
	if not Mitulib.Database:Exists("Settings") then
		return nil
	end
	
	local settings = Mitulib.Database:Get("Settings")
	if settings then
		Mitulib._CachedSettings = settings
	end
	
	return settings
end

local function getUsers()
	if not Mitulib.Database:Exists("Users") then
		return {}
	end
	return Mitulib.Database:Get("Users") or {}
end

-- ============================================================================
-- PLACE RESOLUTION
-- ============================================================================

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
		if Data.Settings and Data.Settings.AllowSubPlaces and Data.SubPlaces then
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

-- ============================================================================
-- SCRIPT LAUNCHING
-- ============================================================================

local function launch(placeData, placeType, Settings)
	-- Encode the script data
	local success, Encoded = safeExecute(function()
		return select(2, assert(pcall(Mitulib.Encode.Encode, placeData.Settings.Key, placeData.Settings.Seed)))
	end, "Encoding")
	
	if not success then
		return fail("Encoding failed, try again. (" .. tostring(Encoded) .. ")")
	end
	
	Mitulib._PassKey = Encoded
	
	-- Resolve and load the script
	local scriptType = resolveScriptType(placeData, placeType)
	local scriptUrl = Settings.AppsPath .. scriptType .. ".luau"
	
	local scriptSuccess, scriptError = safeExecute(function()
		return loadstring(game:HttpGet(scriptUrl, false))(Encoded)
	end, "Script execution")
	
	if not scriptSuccess then
		return fail("Script execution failed: " .. tostring(scriptError))
	end
	
	return true
end

-- ============================================================================
-- VARARG SHORTCUT (Pre-encoded key bypass)
-- ============================================================================

local function handleVarargBypass(encodedKey)
	local Apps = getApps()
	local Settings = getSettings()
	
	if not (Apps and Settings) then
		return false
	end
	
	local placeData, placeType = findPlaceData(Apps)
	if not (placeData and placeData.Settings.AllowExecution) then
		return false
	end
	
	local success, decoded = safeExecute(function()
		return select(2, assert(pcall(Mitulib.Encode.Decode, encodedKey, placeData.Settings.Seed)))
	end, "Decoding vararg")
	
	if success and decoded == placeData.Settings.Key then
		Mitulib._PassKey = encodedKey
		local scriptType = resolveScriptType(placeData, placeType)
		safeExecute(function()
			return loadstring(game:HttpGet(Settings.AppsPath .. scriptType .. ".luau", false))(encodedKey)
		end, "Vararg script execution")
		return true
	end
	
	return false
end

local Varargs = ...
if Varargs and type(Varargs) == "string" and Varargs ~= "" then
	if handleVarargBypass(Varargs) then
		return
	end
end

-- ============================================================================
-- VALIDATION PHASE
-- ============================================================================

local function validateAndInitialize()
	-- Settings availability
	local Settings = getSettings()
	if not Settings then
		return nil, nil, nil, "Service unavailable, try again later."
	end
	
	if not Settings.AllowLaunching then
		return nil, nil, nil, "Launching is currently disabled."
	end
	
	-- Apps registry availability
	local Apps = getApps()
	if not Apps then
		return nil, nil, nil, "Apps registry is unavailable, try again later."
	end
	
	-- Place lookup
	local placeData, placeType = findPlaceData(Apps)
	if not placeData then
		return nil, nil, nil, "This game is not supported."
	end
	
	-- Execution permission
	if not placeData.Settings.AllowExecution then
		return nil, nil, nil, "Execution is not allowed for this game."
	end
	
	-- Subplace check
	if placeType == "sub" and not placeData.Settings.AllowSubPlaces then
		return nil, nil, nil, "SubPlace access is not allowed for this game."
	end
	
	-- Version check
	if not placeData.Settings.RejectVersionCheck then
		if placeData.Place.Version ~= game.PlaceVersion then
			return nil, nil, nil, 
				("Script is outdated, wait for an update. (Game: %d | Script: %d)"):format(
					game.PlaceVersion, 
					placeData.Place.Version
				)
		end
	end
	
	-- Users registry availability
	if not Mitulib.Database:Exists("Users") then
		return nil, nil, nil, "User registry is unavailable, try again later."
	end
	
	return placeData, placeType, Settings, nil
end

local placeData, placeType, Settings, validationError = validateAndInitialize()
if validationError then
	fail(validationError)
	return
end

-- ============================================================================
-- AUTHENTICATION PHASE
-- ============================================================================

local canAccess = false
local accessState = "waiting"

local Authentication = Mitulib.Source:AddAuthentication({
	Key = placeData.Settings.Key,
	Method = "Key",
	Icon = "80203530127401",
})

Authentication:OnSubmit(function()
	local method = Authentication:GetActiveMethod()
	local authenticated = Authentication:IsAuthenticated()
	local input = Authentication:GetInput()
	
	if method == "Key" then
		if authenticated then
			canAccess = true
			Authentication:Close()
		end
	elseif method == "Token" then
		local Users = getUsers()
		if Users[input] then
			canAccess = true
			Authentication:Close()
		end
	end
end)

Authentication:OnClose(function()
	Mitulib.Reason = "Authentication cancelled, please rejoin."
	accessState = "cancelled"
	Authentication:Close()
end)

-- Wait for authentication
repeat task.wait(1)
	if accessState == "cancelled" then
		getgenv().__MituRunning = false
		return
	end
until canAccess == true

-- ============================================================================
-- LAUNCH PHASE
-- ============================================================================

local launchSuccess = launch(placeData, placeType, Settings)

if not launchSuccess then
	notify(
		CONFIG.NAME,
		"Launch failed: " .. Mitulib.Reason,
		CONFIG.ERROR_COLOR,
		CONFIG.NOTIFICATION_DURATION
	)
	getgenv().__MituRunning = false
end
