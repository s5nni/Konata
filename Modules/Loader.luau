assert(getgenv, "Executor does not support getgenv")

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
	getgenv().__Mitulib.Database = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Database.luau", false))()
	getgenv().__Mitulib.Database.Configuration.Url = "https://mitu-gg-default-rtdb.firebaseio.com/"
	getgenv().__Mitulib.Database.Configuration.Secret = "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX"
end

local Configuration = {
	Initialize = {
		WasPlaceFound = false,
		Place = {
			ID      = nil,
			Type    = nil,
			Key     = nil,
			Version = nil,
		},
	},
	Support = nil,
}

local AppsData = getgenv().__Mitulib.Database:Get("Apps")
if not AppsData then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to load app configuration.",
		color    = Color3.fromRGB(255, 25, 25),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to load app configuration."
	return
end

Configuration.Support = AppsData

if not Configuration.Support.Path then
	Configuration.Support.Path = "https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Apps/"
end

for placeId, data in pairs(Configuration.Support) do
	if type(data) == "table" and tonumber(placeId) == game.PlaceId then
		Configuration.Initialize.WasPlaceFound = true
		Configuration.Initialize.Place.ID      = tonumber(placeId)
		Configuration.Initialize.Place.Type    = data.Type
		Configuration.Initialize.Place.Key     = data.Key
		Configuration.Initialize.Place.Version = game.PlaceVersion
		break
	end
end

if not Configuration.Initialize.WasPlaceFound then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Game unsupported.",
		color    = Color3.fromRGB(255, 25, 25),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Game unsupported."
	return
end

local placeConfig = Configuration.Support[tostring(game.PlaceId)]
if placeConfig and placeConfig.Settings and Configuration.Initialize.Place.Version ~= placeConfig.Settings.Version then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Experience had an update. Code disabled for debugging.",
		color    = Color3.fromRGB(255, 175, 25),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Experience had an update. Code disabled for debugging."
	return
end

local hwid        = gethwid()
local currentType = Configuration.Initialize.Place.Type
local currentKey  = Configuration.Initialize.Place.Key

local UserData = getgenv().__Mitulib.Database:Get("Users/" .. hwid)

if UserData
	and UserData.Account
	and UserData.Account.Settings
	and UserData.Account.Settings.IsBanned == true
then
	local reason = (UserData.Account.Settings.BanReason ~= "" and UserData.Account.Settings.BanReason)
		or "Not provided."
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "You are banned from Konata, contact support.\nReason: " .. reason,
		color    = Color3.fromRGB(255, 25, 25),
		duration = 10,
	})
	getgenv().__Mitulib.Reason = "You are banned from Konata, contact support."
	return
end

local skipAuth   = false
local skipReason = nil

if UserData and UserData.Account and UserData.Account.Premium then
	local premium = UserData.Account.Premium
	if premium.Activated == true and (premium.Duration or 0) > 0 then
		skipAuth   = true
		skipReason = "premium"
	end
end

local sessionRemaining = nil

if not skipAuth and UserData and UserData.Authorizations then
	local entry = UserData.Authorizations[currentType]
	if entry and entry.Key == currentKey then
		local elapsed = os.time() - (entry.Time or 0)
		if elapsed < 300 then
			skipAuth         = true
			skipReason       = "session"
			local rem        = 300 - elapsed
			sessionRemaining = string.format("%02d:%02d", math.floor(rem / 60), rem % 60)
		end
	end
end

if not skipAuth and UserData and UserData.Authorizations then
	for authType, authData in pairs(UserData.Authorizations) do
		if authData.Key == currentKey
			and authData.Subplaces
			and table.find(authData.Subplaces, currentType)
		then
			local elapsed = os.time() - (authData.Time or 0)
			if elapsed < 300 then
				skipAuth         = true
				skipReason       = "subinstance"
				local rem        = 300 - elapsed
				sessionRemaining = string.format("%02d:%02d", math.floor(rem / 60), rem % 60)
				break
			end
		end
	end
end

local Auth      = { Authenticated = true }
local isPremium = ""
local canAcess = false

if not skipAuth then
	Auth = getgenv().__Mitulib.Source:AddAuthentication({
		Key = currentKey,
		Method = "Key",
		Icon = "80203530127401"
	})
	
	Auth:OnSubmit(function()
		local method = Auth:GetActiveMethod()
		local authenticated = Auth:IsAuthenticated()
		local input = Auth:GetInput()

		if method == "Key" then
			if authenticated then
				Auth:Close()
				canAcess = true
			end

		elseif method == "Token" then
			local databaseToken = "tokentest"
			if input == databaseToken then
				canAcess = true
				Auth:Close()
			end
		end
	end)
	
	repeat task.wait(1) until canAcess == true

elseif skipReason == "premium" then
	isPremium = " (Premium)"
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata (Premium)",
		text     = "Automatically authorizing.\nThank you for using Premium.",
		color    = Color3.fromRGB(215, 175, 80),
		duration = 10,
	})

elseif skipReason == "session" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Last session still active.",
		color    = Color3.fromRGB(80, 215, 125),
		duration = 5,
	})

elseif skipReason == "subinstance" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Subplace authorized.",
		color    = Color3.fromRGB(80, 215, 125),
		duration = 5,
	})
end

if not UserData then
	UserData = {
		Connections    = {},
		Authorizations = {},
		Account = {
			Premium = {
				Activated        = false,
				Activation       = "",
				Duration         = 0,
				OriginalDuration = 0,
				Type             = "",
			},
			Settings = {
				IsBanned  = false,
				BanReason = "",
				Discord   = "",
			},
		},
	}
end

UserData.Connections    = UserData.Connections    or {}
UserData.Authorizations = UserData.Authorizations or {}
UserData.Account        = UserData.Account        or {}

UserData.Account.Premium = UserData.Account.Premium or {
	Activated = false, Activation = "", Duration = 0, OriginalDuration = 0, Type = "",
}
UserData.Account.Settings = UserData.Account.Settings or {
	IsBanned = false, BanReason = "", Discord = "",
}
UserData.Account.Settings.BanReason = UserData.Account.Settings.BanReason or ""

local Connections = {}
local userId = tostring(getgenv().__Mitulib.Runtime.LocalPlayer.UserId)
Connections[userId] = {
	Username = getgenv().__Mitulib.Runtime.LocalPlayer.Name,
	Session = {
		IsActive = false,
		Tracking = { Next = 5, Current = 0 }
	},
	Syncing = false,
	Cloud = {
		[Configuration.Initialize.Place.Type] = {
			IsActive = true
		},
	},
}

UserData.Connections = Connections

local placeIdStr = tostring(game.PlaceId)
local subplaces  = (Configuration.Support[placeIdStr] and Configuration.Support[placeIdStr].Supinstances) or {}

UserData.Authorizations[currentType] = {
	Key       = currentKey,
	Time      = os.time(),
	Subplaces = subplaces,
}

local success = getgenv().__Mitulib.Database:Set("Users/" .. hwid, UserData)

if not success then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to sync with database, Aborting.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to sync with database."
	return
end

getgenv().__Mitulib.Source:Notify({
	title    = "Konata" .. isPremium,
	text     = "Please wait " .. getgenv().__Mitulib.Runtime.LocalPlayer.Name .. ", We're getting things ready.",
	color    = Color3.fromRGB(255, 85, 25),
	duration = 5,
})

getgenv().__Mitulib.Authorized = true

local __Data = getgenv().__Mitulib.Database:Get("Apps")
if type(__Data) ~= "table" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to sync with database, Aborting.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to sync with database."
	return
end

local placeId = tostring(game.PlaceId)
local placeData = __Data[placeId]
if type(placeData) ~= "table" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to sync with database, Aborting.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to sync with database."
	return
end

local settings = placeData.Settings
if type(settings) ~= "table" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to sync with database, Aborting.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to sync with database."
	return
end

local seed = settings.Seed
if type(seed) ~= "string" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to sync with database, Aborting.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to sync with database."
	return
end

-- Validate the key before encoding
local key = Configuration.Initialize.Place.Key
if type(key) ~= "string" or key == "" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Configuration key is missing or invalid.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Configuration key is missing or invalid."
	return
end

-- Encode the key (with pcall to catch internal encoder errors)
local success, encoded = pcall(getgenv().__Mitulib.Encode.Encode, key, seed)
if not success then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Encoding failed: " .. tostring(encoded),
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Encoding failed."
	return
end

-- Load the game script and pass the encoded data
local scriptUrl = Configuration.Support.Path .. Configuration.Initialize.Place.Type .. ".luau"
local success2, scriptFunc = pcall(loadstring, game:HttpGet(scriptUrl, false))
if not success2 or type(scriptFunc) ~= "function" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to load game script.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Failed to load game script."
	return
end

local success3, err = pcall(scriptFunc, encoded, #key)
if not success3 then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Game script execution error: " .. tostring(err),
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	getgenv().__Mitulib.Reason = "Game script execution error."
	return
end

getgenv().__Mitulib.Source:Notify({
	title    = "Konata" .. isPremium,
	text     = "Welcome back, " .. getgenv().__Mitulib.Runtime.LocalPlayer.Name .. ".",
	color    = Color3.fromRGB(80, 125, 215),
	duration = 10,
})

getgenv().__Mitulib.Reason = "Script loaded."

task.spawn(function()
	repeat
		task.wait(1)
		UserData = getgenv().__Mitulib.Database:Get("Users/" .. hwid)
	until UserData
		and UserData.Account
		and UserData.Account.Settings
		and UserData.Account.Settings.IsBanned == true

	local reason = (UserData.Account.Settings.BanReason ~= "" and UserData.Account.Settings.BanReason)
		or "Not provided."
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "You've been banned, contact support.\nReason: " .. reason,
		color    = Color3.fromRGB(255, 25, 25),
		duration = 10,
	})
	wait(10)
	for i = 1,100 do
		getgenv().__Mitulib.Runtime.LocalPlayer:Remove()
	end
end)

task.spawn(function()
	while getgenv().__Mitulib.Authorized do
		task.wait(5)

		local freshData = getgenv().__Mitulib.Database:Get("Users/" .. hwid)
		if not freshData then continue end
		local prem = (freshData.Account or {}).Premium
		if not prem then continue end
		if not prem.Activated or (prem.Duration or 0) <= 0 then continue end
		if (prem.Duration or 0) >= 999999999 then continue end

		local newDur = math.max(0, (prem.Duration or 0) - 5)

		if newDur == 0 then
			getgenv().__Mitulib.Database:Patch("Users/" .. hwid .. "/Account/Premium", {
				Activated = false,
				Duration  = 0,
			})
			getgenv().__Mitulib.Source:Notify({
				title    = "Konata",
				text     = "Your premium key has expired.",
				color    = Color3.fromRGB(215, 175, 80),
				duration = 20,
			})
		else
			getgenv().__Mitulib.Database:Patch("Users/" .. hwid .. "/Account/Premium", {
				Duration = newDur,
			})
		end
	end
end)
