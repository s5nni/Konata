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

local main_Dehash = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Dehash.luau"))()
local __ScreenGui = getgenv().__Mitulib.Source:GetScreenGui()
__ScreenGui.DisplayOrder = -10
__ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local Window = getgenv().__Mitulib.Source:AddWindow({
	title   = { "Mitu", "Konata (Main)" },
	theme   = { Accent = Color3.fromRGB(80, 125, 215) },
	key     = Enum.KeyCode.E,
	default = false,
})

local Config = {
	LocalPlayer = {
		Character = {
			WalkSpeed = {
				Enabled = false,
				Value = 16,
			},
			JumpPower = {
				Enabled = false,
				Value = 50,
			},
			No_Jump_Delay = {
				Enabled = false,
			},
		},
	},
}

getgenv().__Mitulib.Runtime.RunLoops:BindToHeartbeat("Konata_Heartbeat", function()
	if Config.LocalPlayer.Character.WalkSpeed.Enabled then
		local LocalPlayer = getgenv().__Mitulib.Runtime.LocalPlayer
		if getgenv().__Mitulib.Runtime.IsAlive then
			local Direction = getgenv().__Mitulib.Runtime.Humanoid.MoveDirection * Config.LocalPlayer.Character.WalkSpeed.Value
			getgenv().__Mitulib.Runtime.HumanoidRootPart.Velocity = Vector3.new(Direction.X, getgenv().__Mitulib.Runtime.HumanoidRootPart.Velocity.Y, Direction.Z)
		end
	end
end)

local Tabs = {}
Tabs.LocalPlayer = Window:AddTab("LocalPlayer", {default = true})
Tabs.Miscellaneous = Window:AddTab("Miscellaneous", {default = false})
Tabs.Visuals = Window:AddTab("Visuals", {default = false})
Tabs.Settings = Window:AddTab("Settings", {default = false})
-----------------------------------------

local Character = Tabs.LocalPlayer:AddSection("Character", {default = false})
Character:AddSlider("WalkSpeed", 0, 50, 16, {flag = "WalkSpeedSlider", rounded = false, cap = true, dual = false, toggleable = true, default = false, fireondrag = true}, function(Value, Enabled)
	Config.LocalPlayer.Character.WalkSpeed.Enabled = Enabled
	Config.LocalPlayer.Character.WalkSpeed.Value = Value
end)
Character:AddSlider("JumpPower", 0, 200, 50, {flag = "JumpPowerSlider", rounded = false, cap = true, dual = false, toggleable = true, default = false, fireondrag = true})
Character:AddToggle("No Jump Delay", {flag = "NoJumpDelayToggle", default = false})

-----------------------------------------
Window.Frame.Topbar.Konata.Visible = true
Window:Toggle(true)
