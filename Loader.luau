if getgenv().__Mitulib ~= nil then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Already injected.",
		color    = Color3.fromRGB(80, 125, 215),
		duration = 5,
	})
	return
end

getgenv().__Mitulib         = {}
getgenv().__Mitulib.Source  = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Source.luau", false))()
getgenv().__Mitulib.Runtime = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Runtime.luau", false))()
getgenv().__Mitulib.Database = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Database.luau", false))()

getgenv().__Mitulib.Database.Configuration.Url    = "https://mitu-gg-default-rtdb.firebaseio.com/"
getgenv().__Mitulib.Database.Configuration.Secret = "yRMlT8NNgrOOl5WUIxANgIwzralo2n9hGUkFDuoX"

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

	Support = {
		Path = "https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/",
		[10277607801] = {
			Type = "Apeirophobia_Lobby",
			Key  = "ojvx3BBA9UKndy6LVCS_zQ",
			Settings = { Version = 1772 },
			Supinstances = {
				"Apeirophobia_Main"
			}
		},
		[10277635599] = {
			Type = "Apeirophobia_Main",
			Key  = "ojvx3BBA9UKndy6LVCS_zQ",
			Settings = { Version = 1715 },
			Supinstances = {
				"Apeirophobia_Lobby"
			}
		},
	},
}

for placeId, data in next, Configuration.Support do
	if game.PlaceId == placeId then
		Configuration.Initialize.WasPlaceFound = true
		Configuration.Initialize.Place.ID      = placeId
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
	return
end

if Configuration.Initialize.Place.Version ~= Configuration.Support[game.PlaceId].Settings.Version then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Experience had an update. Code disabled for debugging.",
		color    = Color3.fromRGB(255, 175, 25),
		duration = 5,
	})
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
	local reason = UserData.Account.Settings.BanReason and UserData.Account.Settings.BanReason or "Not provided."
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "You are banned from using Konata, Contact support.\nReason: " .. reason,
		color    = Color3.fromRGB(255, 25, 25),
		duration = 10,
	})
	return
end

local skipAuth   = false
local skipReason = nil

if UserData
	and UserData.Account
	and UserData.Account.Premium
then
	local premium = UserData.Account.Premium
	if premium.Activated == true and (premium.Duration or 0) > 0 then
		skipAuth   = true
		skipReason = "premium"
	end
end

local sessionRemaining = nil

-- 1) Check current type session
if not skipAuth
	and UserData
	and UserData.Authorizations
then
	local entry = UserData.Authorizations[currentType]
	if entry and entry.Key == currentKey then
		local elapsed = os.time() - (entry.Time or 0)
		if elapsed < 120 then
			skipAuth         = true
			skipReason       = "session"
			local rem        = 120 - elapsed
			sessionRemaining = string.format("%02d:%02d", math.floor(rem / 60), rem % 60)
		end
	end
end

-- 2) Check any authorization that lists current type as a subplace
if not skipAuth
	and UserData
	and UserData.Authorizations
then
	for authType, authData in pairs(UserData.Authorizations) do
		if authData.Key == currentKey
			and authData.Subplaces
			and table.find(authData.Subplaces, currentType) then

			local elapsed = os.time() - (authData.Time or 0)
			if elapsed < 120 then
				skipAuth         = true
				skipReason       = "supinstance"
				local rem        = 120 - elapsed
				sessionRemaining = string.format("%02d:%02d", math.floor(rem / 60), rem % 60)
				break
			end
		end
	end
end

local Auth = { Authenticated = true }
local isPremium = ""

if not skipAuth then
	Auth = getgenv().__Mitulib.Source:Auth({
		Key     = currentKey,
		Discord = "https://discord.gg/AVEQCfng",
		Icon    = "rbxassetid://101639538453544",
	})
	repeat task.wait(1) until Auth.Authenticated == true

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
elseif skipReason == "supinstance" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Subplace authorized.",
		color    = Color3.fromRGB(80, 215, 125),
		duration = 5,
	})
end

-- Initialize UserData if it doesn't exist
if not UserData then
	UserData = {
		Connections    = {},
		Authorizations = {},
		Account        = {
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

-- Ensure all required fields exist (handles both new and existing users)
UserData.Connections    = UserData.Connections          or {}
UserData.Authorizations = UserData.Authorizations       or {}
UserData.Account        = UserData.Account              or {}
UserData.Account.Premium = UserData.Account.Premium     or {
	Activated = false, Activation = "", Duration = 0,
	OriginalDuration = 0, Type = "",
}
UserData.Account.Settings = UserData.Account.Settings   or {
	IsBanned  = false,
	BanReason = "",
	Discord   = "",
}
-- Ensure BanReason exists even for existing Settings
UserData.Account.Settings.BanReason = UserData.Account.Settings.BanReason or "Not provided."

-- Update connections list
UserData.Connections[tostring(getgenv().__Mitulib.Runtime.LocalPlayer.UserId)] = getgenv().__Mitulib.Runtime.LocalPlayer.Name

-- Build Subplaces list for current place
local subplaces = Configuration.Support[game.PlaceId]
	and Configuration.Support[game.PlaceId].Supinstances
	or {}

-- Save current authorization (with Subplaces)
UserData.Authorizations[currentType] = {
	Key       = currentKey,
	Time      = os.time(),
	Subplaces = subplaces
}

-- === SAVE TO DATABASE ===
local success = getgenv().__Mitulib.Database:Set("Users/" .. hwid, UserData)
if success then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Session synced.",
		color    = Color3.fromRGB(80, 215, 125),
		duration = 3,
	})
else
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failed to sync with database.",
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
end

getgenv().__Mitulib.Source:Notify({
	title    = "Konata" .. isPremium,
	text     = "Please wait " .. getgenv().__Mitulib.Runtime.LocalPlayer.Name .. ", We're getting things ready.",
	color    = Color3.fromRGB(255, 85, 25),
	duration = 5,
})

getgenv().__Mitulib.Authorized = true
loadstring(game:HttpGet(Configuration.Support.Path .. Configuration.Initialize.Place.Type .. ".luau", false))()

getgenv().__Mitulib.Source:Notify({
	title    = "Konata" .. isPremium,
	text     = "Welcome back, " .. getgenv().__Mitulib.Runtime.LocalPlayer.Name .. ".",
	color    = Color3.fromRGB(80, 125, 215),
	duration = 10,
})

-- Background thread to monitor ban status
task.spawn(function()
	repeat
		UserData = getgenv().__Mitulib.Database:Get("Users/" .. hwid, UserData)
		wait(5)
	until UserData and UserData.Account and UserData.Account.Settings and UserData.Account.Settings.IsBanned == true

	local reason = UserData.Account.Settings.BanReason and UserData.Account.Settings.BanReason or "Not provided."
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "You've been banned, Contact support.\nReason: " .. reason,
		color    = Color3.fromRGB(255, 25, 25),
		duration = math.huge,
	})
end)
