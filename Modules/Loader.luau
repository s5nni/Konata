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

-- Checks and fire Settings Data
local SettingsExists = getgenv().__Mitulib.Database:Exists("Settings")
if SettingsExists == false then return end

local Settings = getgenv().__Mitulib.Database:Get("Settings")
if Settings.AllowLaunching == false then return end

-- Checks and collect Apps Data
local AppsExists = getgenv().__Mitulib.Database:Exists("Apps")
if AppsExists == false then return end

local Apps = getgenv().__Mitulib.Database:Get("Apps")
local placeData = nil

-- Search for matching place ID
for ID, Data in next, Apps do
	local newID = tonumber(ID)
	if game.PlaceId == newID then
		placeData = Data
		break
	end
end

-- Check if Data was found
if placeData == nil then getgenv().__Mitulib.Reason = "Not provided." return end

-- Check and collect Users data
local UserExists = getgenv().__Mitulib.Database:Exists("Users")
if UserExists == false then getgenv().__Mitulib.Reason = "Not provided." return end

local canAcess = false
Authentication = getgenv().__Mitulib.Source:AddAuthentication({
	Key = placeData.Settings.Key,
	Method = "Key",
	Icon = "80203530127401"
})

-- Authentication
Authentication:OnSubmit(function()
	local method = Authentication:GetActiveMethod()
	local authenticated = Authentication:IsAuthenticated()
	local input = Authentication:GetInput()

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

repeat task.wait(1) until canAcess == true

local Encoded = getgenv().__Mitulib.Encode.Encode(placeData.Settings.Key, placeData.Place.Seed)

-- Load the game script and pass the encoded data
local scriptUrl = Settings.AppsPath..placeData.Place.Type..".luau"
loadstring(game:HttpGet(scriptUrl, false))(Encoded)
