-- all credit goes to mitixius production team.

if getgenv().__Mitulib ~= nil then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Already injected.",
		color    = Color3.fromRGB(80, 125, 215),
		duration = 5,
	})
	return
end

getgenv().__Mitulib          = {}
getgenv().__Mitulib.Source   = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Source.luau",   false))()
getgenv().__Mitulib.Runtime  = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/UI-Library/refs/heads/main/Runtime.luau",  false))()
getgenv().__Mitulib.Database = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Modules/Database.luau",     false))()

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
	return
end

Configuration.Support = AppsData

if not Configuration.Support.Path then
	Configuration.Support.Path = "https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/"
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

UserData.Connections[tostring(getgenv().__Mitulib.Runtime.LocalPlayer.UserId)] = getgenv().__Mitulib.Runtime.LocalPlayer.Name

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
	return
end

getgenv().__Mitulib.Source:Notify({
	title    = "Konata" .. isPremium,
	text     = "Please wait " .. getgenv().__Mitulib.Runtime.LocalPlayer.Name .. ", We're getting things ready.",
	color    = Color3.fromRGB(255, 85, 25),
	duration = 5,
})

getgenv().__Mitulib.Authorized = true

loadstring(game:HttpGet(
	Configuration.Support.Path .. Configuration.Initialize.Place.Type .. ".luau",
	false
	))()

getgenv().__Mitulib.Source:Notify({
	title    = "Konata" .. isPremium,
	text     = "Welcome back, " .. getgenv().__Mitulib.Runtime.LocalPlayer.Name .. ".",
	color    = Color3.fromRGB(80, 125, 215),
	duration = 10,
})

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
