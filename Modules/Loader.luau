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
	Mitulib.Database = DatabaseLib:New({
		Url    = "https://mitu-gg-default-rtdb.firebaseio.com",
		Secret = "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX",
	})
end

--> Shared helpers
local function getApps()
	if Mitulib.Database:Exists("Apps") == false then return nil end
	return Mitulib.Database:Get("Apps")
end

local function getSettings()
	if Mitulib.Database:Exists("Settings") == false then return nil end
	return Mitulib.Database:Get("Settings")
end

local function findPlaceData(Apps)
	-- Search main places
	for ID, Data in next, Apps do
		if game.PlaceId == tonumber(ID) then
			return Data, "main"
		end
	end
	-- Search subplaces
	for ID, Data in next, Apps do
		if Data.Settings.AllowSubPlaces == true and Data.SubPlaces then
			for SubID in next, Data.SubPlaces do
				if game.PlaceId == tonumber(SubID) then
					return Data, "sub"
				end
			end
		end
	end
	return nil, nil
end

local function resolveScriptType(placeData, placeType)
	if placeType == "sub" then
		for SubID, SubType in next, placeData.SubPlaces do
			if game.PlaceId == tonumber(SubID) then
				return SubType
			end
		end
	end
	return placeData.Place.Type
end

local function launch(placeData, placeType, Settings)
	local ok, Encoded = pcall(Mitulib.Encode.Encode, placeData.Settings.Key, placeData.Settings.Seed)
	if not ok then
		Mitulib.Reason = "Encoding failed, try again. ("..tostring(Encoded)..")"
		Mitulib.__MituRunning = false
		return false
	end
	Mitulib._PassKey = Encoded
	local scriptType = resolveScriptType(placeData, placeType)
	local scriptUrl  = Settings.AppsPath..scriptType..".luau"
	loadstring(game:HttpGet(scriptUrl, false))(Encoded)
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
				loadstring(game:HttpGet(Settings.AppsPath..scriptType..".luau", false))(Varargs)
				return
			end
		end
	end
	-- Invalid vararg — fall through to normal flow silently
end

--> Settings check
local Settings = getSettings()
if Settings == nil then
	Mitulib.Reason = "Service unavailable, try again later."
	return
end
if Settings.AllowLaunching == false then
	Mitulib.Reason = "Launching is currently disabled."
	return
end

--> Apps check
local Apps = getApps()
if Apps == nil then
	Mitulib.Reason = "Apps registry is unavailable, try again later."
	return
end

--> Place lookup
local placeData, placeType = findPlaceData(Apps)
if placeData == nil then
	Mitulib.Reason = "This game is not supported."
	return
end

--> Execution check
if placeData.Settings.AllowExecution == false then
	Mitulib.Reason = "Execution is not allowed for this game."
	return
end

--> SubPlace check
if placeType == "sub" and placeData.Settings.AllowSubPlaces == false then
	Mitulib.Reason = "SubPlace access is not allowed for this game."
	return
end

--> Version check
if placeData.Settings.RejectVersionCheck == false then
	if placeData.Place.Version ~= game.PlaceVersion then
		Mitulib.Reason = "Script is outdated, wait for an update. (Game: "..game.PlaceVersion.." | Script: "..placeData.Place.Version..")"
		return
	end
end

--> Users check
if Mitulib.Database:Exists("Users") == false then
	Mitulib.Reason = "User registry is unavailable, try again later."
	return
end

--> Authentication
local canAccess  = false
local accessState = "w"

Authentication = Mitulib.Source:AddAuthentication({
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
		if input == "tokentest" then
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
launch(placeData, placeType, Settings)
