assert(getgenv, "Executor does not support getgenv")
assert(request, "Executor does not support request")
if getgenv().__MituRunning == true then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Rejected, Reason: "..getgenv().__Mitulib.Reason,
		color    = Color3.fromRGB(80, 125, 215),
		duration = 10,
	})
	return
end

getgenv().__MituRunning = true
getgenv().__Mitulib = {}
getgenv().__Mitulib.Reason = "Not provided."
if getgenv().__Mitulib.Source == nil then
	getgenv().__Mitulib.Source = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Source.luau", false))()
end
if getgenv().__Mitulib.Runtime == nil then
	getgenv().__Mitulib.Runtime = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Runtime.luau", false))()
end
if getgenv().__Mitulib.Encode == nil then
	getgenv().__Mitulib.Encode = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Encode.luau", false))()
end
if getgenv().__Mitulib.Database == nil then
	local DatabaseLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Database.luau", false))()
	getgenv().__Mitulib.Database = DatabaseLib:New({
		Url    = "https://mitu-gg-default-rtdb.firebaseio.com",
		Secret = "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX",
	})
end

local Varargs = ...
if Varargs ~= nil and type(Varargs) == "string" and Varargs ~= "" then
	-- Load required modules if not already loaded
	if getgenv().__Mitulib.Encode == nil then
		getgenv().__Mitulib.Encode = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Encode.luau", false))()
	end
	if getgenv().__Mitulib.Database == nil then
		local DatabaseLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Database.luau", false))()
		getgenv().__Mitulib.Database = DatabaseLib:New({
			Url    = "https://mitu-gg-default-rtdb.firebaseio.com",
			Secret = "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX",
		})
	end

	-- Collect Apps Data
	local AppsExists = getgenv().__Mitulib.Database:Exists("Apps")
	if AppsExists == false then return end
	local Apps = getgenv().__Mitulib.Database:Get("Apps")
	local Settings = getgenv().__Mitulib.Database:Get("Settings")

	-- Search for matching place ID
	local placeData = nil
	for ID, Data in next, Apps do
		if game.PlaceId == tonumber(ID) then
			placeData = Data
			break
		end
	end

	if placeData == nil then return end
	if placeData.Settings.AllowExecution == false then return end

	-- Decode the provided vararg and validate against the database key
	local ok, decoded = pcall(getgenv().__Mitulib.Encode.Decode, Varargs, placeData.Settings.Seed)
	if not ok then return end
	if decoded ~= placeData.Settings.Key then return end

	-- Valid — skip auth and launch directly
	getgenv().__MituRunning = true
	getgenv().__Mitulib._PassKey = Varargs
	local scriptUrl = Settings.AppsPath..placeData.Place.Type..".luau"
	loadstring(game:HttpGet(scriptUrl, false))(Varargs)
	return
end

-- Checks and fire Settings Data
local SettingsExists = getgenv().__Mitulib.Database:Exists("Settings")
if SettingsExists == false then
	getgenv().__Mitulib.Reason = "Service unavailable, try again later."
	return
end
local Settings = getgenv().__Mitulib.Database:Get("Settings")
if Settings.AllowLaunching == false then
	getgenv().__Mitulib.Reason = "Launching is currently disabled."
	return
end

-- Checks and collect Apps Data
local AppsExists = getgenv().__Mitulib.Database:Exists("Apps")
if AppsExists == false then
	getgenv().__Mitulib.Reason = "Apps registry is unavailable, try again later."
	return
end
local Apps = getgenv().__Mitulib.Database:Get("Apps")
local placeData = nil
local placeType = nil -- "main" or "sub"

-- Search for matching place ID (main place)
for ID, Data in next, Apps do
	if game.PlaceId == tonumber(ID) then
		placeData = Data
		placeType = "main"
		break
	end
end

-- Search for matching place ID (subplace)
if placeData == nil then
	for ID, Data in next, Apps do
		if Data.Settings.AllowSubPlaces == true and Data.SubPlaces then
			for SubID, SubType in next, Data.SubPlaces do
				if game.PlaceId == tonumber(SubID) then
					placeData = Data
					placeType = "sub"
					break
				end
			end
		end
		if placeData ~= nil then break end
	end
end

-- Check if Data was found
if placeData == nil then
	getgenv().__Mitulib.Reason = "This game is not supported."
	return
end

-- Execution check (applies to both main and subplaces)
if placeData.Settings.AllowExecution == false then
	getgenv().__Mitulib.Reason = "Execution is not allowed for this game."
	return
end

-- SubPlace access check
if placeType == "sub" and placeData.Settings.AllowSubPlaces == false then
	getgenv().__Mitulib.Reason = "SubPlace access is not allowed for this game."
	return
end

-- Version check (skipped if RejectVersionCheck is true)
if placeData.Settings.RejectVersionCheck == false then
	if placeData.Place.Version ~= game.PlaceVersion then
		getgenv().__Mitulib.Reason = "Script is outdated, wait for an update. (Game: "..game.PlaceVersion.." | Script: "..placeData.Place.Version..")"
		return
	end
end

-- Check and collect Users data
local UserExists = getgenv().__Mitulib.Database:Exists("Users")
if UserExists == false then
	getgenv().__Mitulib.Reason = "User registry is unavailable, try again later."
	return
end

local canAcess = false
local accessState = "w"
Authentication = getgenv().__Mitulib.Source:AddAuthentication({
	Key  = placeData.Settings.Key,
	Method = "Key",
	Icon = "80203530127401"
})

-- Authentication
Authentication:OnSubmit(function()
	local method        = Authentication:GetActiveMethod()
	local authenticated = Authentication:IsAuthenticated()
	local input         = Authentication:GetInput()
	if method == "Key" then
		if authenticated then
			canAcess = true
			Authentication:Close()
		end
	elseif method == "Token" then
		local databaseToken = "tokentest"
		if input == databaseToken then
			canAcess = true
			Authentication:Close()
		end
	end
end)
Authentication:OnClose(function()
	getgenv().__Mitulib.Reason = "Authentication cancelled, please rejoin."
	accessState = "c"
	Authentication:Close()
end)

repeat task.wait(1) if accessState == "c" then
		getgenv().__MituRunning = false
		return
	end until canAcess == true

local ok, Encoded = pcall(getgenv().__Mitulib.Encode.Encode, placeData.Settings.Key, placeData.Settings.Seed)
if not ok then
	getgenv().__Mitulib.Reason = "Encoding failed, try again. ("..tostring(Encoded)..")"
	getgenv().__MituRunning = false
	return
end

getgenv().__Mitulib._PassKey = Encoded

-- Resolve script type for subplaces
local scriptType = placeData.Place.Type
if placeType == "sub" then
	for SubID, SubType in next, placeData.SubPlaces do
		if game.PlaceId == tonumber(SubID) then
			scriptType = SubType
			break
		end
	end
end

-- Load the game script and pass the encoded data
local scriptUrl = Settings.AppsPath..scriptType..".luau"
loadstring(game:HttpGet(scriptUrl, false))(Encoded)
