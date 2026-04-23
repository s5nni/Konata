-- Protection layer from direct execution.
local __Key, __Length = ... or "Not provided.", nil

local __Data = getgenv().__Mitulib.Database:Get("Apps")
if type(__Data) ~= "table" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failure.\n"..__Key,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	return
end
local placeId = tostring(game.PlaceId)
local placeData = __Data[placeId]
if type(placeData) ~= "table" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failure.\n"..__Key,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	return
end
local settings = placeData.Settings
if type(settings) ~= "table" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failure.\n"..__Key,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	return
end
local seed = settings.Seed
if type(seed) ~= "string" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failure.\n"..__Key,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	return
end
if type(__Key) ~= "string" then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failure.\n"..__Key,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	return
end
local __DecodedKey = getgenv().__Mitulib.Encode.Decode(__Key, seed, __Length)
if __DecodedKey ~= placeData.Key then
	getgenv().__Mitulib.Source:Notify({
		title    = "Konata",
		text     = "Failure.\n"..__Key,
		color    = Color3.fromRGB(215, 80, 80),
		duration = 5,
	})
	return
end

local Window = getgenv().__Mitulib.Source:AddWindow({
	title   = { "Mitu", "Konata" },
	theme   = { Accent = Color3.fromRGB(80, 125, 215) },
	key     = Enum.KeyCode.E,
	default = false,
})

local Config = {
	Settings = {
		Account = {
			Label = nil,
			Sync_Cloud = {Enabled = false},
			Test1 = {Enabled = false},
			Test2 = {Enabled = false, Value = 0},
		},
	},
}

local Tabs = {}
Tabs.Settings = Window:AddTab("Settings", {default = false})

local Sections = {}
Sections.Account = Tabs.Settings:AddSection("Account", {default = false})
---------------------------------------------

local canUpdate = false
getgenv().__Mitulib.Runtime.RunLoops:BindToHeartbeat("Sync", function()
	if canUpdate == true then return end
	if not canUpdate then
		canUpdate = true
		wait(5)
		local appsData = getgenv().__Mitulib.Database:Get("Apps/"..game.PlaceId)
		local userData = getgenv().__Mitulib.Database:Get("Users/"..gethwid())
		if appsData and userData then
			if userData.Connections[getgenv().__Mitulib.Runtime.LocalPlayer.UserId].Cloud[appsData.Type] then
				Config.Settings.Account.Label.Label2.Text = "Yes"
			end
		else
			warn("No apps/user found")
			return
		end
		local hwid = gethwid()
		local userId = tostring(getgenv().__Mitulib.Runtime.LocalPlayer.UserId)
		local placeId = game.PlaceId
		local connPath = "Users/" .. hwid .. "/Connections/" .. userId .. "/Cloud/" .. appsData.Type
		getgenv().__Mitulib.Database:Patch(connPath, Config)
		canUpdate = false
	end
end)

---------------------------------------------
Config.Settings.Account.Sync_Cloud = Sections.Account:AddDualLabel({"Sync:", "No"})
Sections.Account:AddToggle("Sync Cloud", {flag = "Toggle_Flag", default = false}, function(bool)
	Config.Settings.Account.Sync_Cloud.Enabled = bool
end)

Sections.Account:AddToggle("Test", {flag = "Toggle_Flag", default = false}, function(bool)
	Config.Settings.Account.Test1.Enabled = bool
end)
Sections.Account:AddSlider("Test", 1, 100, 50, {toggleable = true, default = false, flag = "Slider_Flag", fireontoggle = true, fireondrag = true, rounded = true}, function(val, bool)
	Config.Settings.Account.Test2.Enabled = bool
	Config.Settings.Account.Test2.Value = val
end)


Window.Frame.Topbar.Konata.Visible = true
Window:Toggle(true)
