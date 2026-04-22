-- Protection layer from direct execution.
local __Key, __Length = ...

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

local __ScreenGui = getgenv().__Mitulib.Source:GetScreenGui()
__ScreenGui.DisplayOrder = -10
__ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local LocalPlayer = game:GetService("Players").LocalPlayer
local RoomControl = game:GetService("ReplicatedStorage")
	:WaitForChild("Assets")
	:WaitForChild("Events")
	:WaitForChild("RoomControl")

local Levels = {
	Chapters = {
		[1] = {
			["The Lobby"]                       = 0,
			["The Poolrooms"]                   = 1,
			["The Windows"]                     = 2,
			["Abandoned Office"]                = 3,
			["Sublimity"]                       = 4,
			["Cave"]                            = 5,
			["Run"]                             = 6,
			["The End?"]                        = 7,
			["Septic"]                          = 8,
			["Boiling Point"]                   = 9,
			["Parking Garage"]                  = 10,
			["Warehouse"]                       = 11,
			["Creative Minds"]                  = 12,
			["The Funrooms"]                    = 13,
			["Electrical Station"]              = 14,
			["The Ocean of the Final Frontier"] = 15,
			["Crumbling Memory"]                = 16,
		},
		[2] = {
			["Left Scarred"]  = 17,
			["Mall"]          = 18,
			["Store"]         = 19,
			["Neighborhood"]  = 20,
			["Graveyard"]     = 21,
			["Party Mall"]    = 22,
			["Hospital"]      = 23,
			["Train Station"] = 24,
		},
	}
}

local function getLevelNames(chapter)
	local names = {}
	for name in pairs(Levels.Chapters[chapter]) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		return Levels.Chapters[chapter][a] < Levels.Chapters[chapter][b]
	end)
	return names
end

local Window = getgenv().__Mitulib.Source:AddWindow({
	title   = { "Mitu", "Konata" },
	theme   = { Accent = Color3.fromRGB(80, 125, 215) },
	key     = Enum.KeyCode.E,
	default = false,
})

local Config = {
	Room = {
		Chapter      = 1,
		GameMode     = 1,
		MaxSize      = 1,
		Level        = 0,
		Locked       = false,
		IsTestPlace  = false,
		IsPrePublish = false,
	},
	State = {
		StatusDual = nil,
		LevelDrop  = nil,
	},
}

local function buildArgs(type)
	return {
		Chapter           = Config.Room.Chapter,
		Type              = type,
		IsTestPlace       = Config.Room.IsTestPlace,
		GameMode          = Config.Room.GameMode,
		Locked            = Config.Room.Locked,
		MaxSize           = Config.Room.MaxSize,
		IsPrePublishPlace = Config.Room.IsPrePublish,
		Level             = Config.Room.Level,
		PlayerKicked      = type == "removePlayer" and LocalPlayer or nil,
	}
end

local function setStatus(text, color)
	Config.State.StatusDual:SetRightText(text)
	Config.State.StatusDual.Label2.TextColor3 = color or Color3.fromRGB(255, 255, 255)
end

local function checkRoom()
	local ok, result = pcall(function()
		return RoomControl:InvokeServer(buildArgs("updateRoom"))
	end)
	if not ok then return false end
	if type(result) == "table" then
		for i, v in next, result do
			if i == 1 and v == false then return false end
		end
	end
	return true
end

local Tabs = {
	Room     = Window:AddTab("Room",     { default = true }),
	Settings = Window:AddTab("Settings", { default = false }),
}

local Sections = {
	Setup   = Tabs.Room:AddSection("Setup",   { default = false }),
	Control = Tabs.Room:AddSection("Control", { default = false }),
	Account = Tabs.Settings:AddSection("Account", { default = false }),
}

local SubSections = {
	Options = Sections.Setup:AddSubSection("Options",  { default = false }),
	Actions = Sections.Control:AddSubSection("Actions", { default = false }),
}

local ch1Names = getLevelNames(1)
Config.Room.Level = Levels.Chapters[1][ch1Names[1]]

SubSections.Options:AddDropdown("Chapter", { "Chapter 1", "Chapter 2" }, { multi = false, default = "Chapter 1" }, function(val)
	Config.Room.Chapter = val == "Chapter 1" and 1 or 2
	local names = getLevelNames(Config.Room.Chapter)
	Config.Room.Level = Levels.Chapters[Config.Room.Chapter][names[1]]
	if Config.State.LevelDrop then
		Config.State.LevelDrop:SetList(names)
		Config.State.LevelDrop:Select(names[1])
	end
end)

Config.State.LevelDrop = SubSections.Options:AddDropdown("Level", ch1Names, { multi = false, default = ch1Names[1] }, function(val)
	local levelNum = Levels.Chapters[Config.Room.Chapter][val]
	if levelNum ~= nil then
		Config.Room.Level = levelNum
	end
end)

SubSections.Options:AddDropdown("GameMode", { "Easy", "Normal", "Hard", "Nightmare" }, { multi = false, default = "Easy" }, function(val)
	Config.Room.GameMode = ({ Easy = 1, Normal = 2, Hard = 3, Nightmare = 4 })[val]
end)

SubSections.Options:AddDropdown("Max Players (5-10 Gamepass)", { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}, { multi = false, default = "1" }, function(val)
	Config.Room.MaxSize = tonumber(val)
end)

SubSections.Options:AddToggle("Friends Only",        { default = false }, function(val) Config.Room.Locked       = val end)
SubSections.Options:AddToggle("IsTestPlace",         { default = false }, function(val) Config.Room.IsTestPlace  = val end)
SubSections.Options:AddToggle("IsPre-PublishPlace",  { default = false }, function(val) Config.Room.IsPrePublish = val end)

Config.State.StatusDual = SubSections.Actions:AddDualLabel({ "Status:", "Idle." })

SubSections.Actions:AddButton("Create Room", function()
	local ok, err = pcall(function() RoomControl:InvokeServer(buildArgs("createRoom")) end)
	setStatus(ok and "Room Created." or "Failed.", ok and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
	if not ok then warn("[Mitu] CreateRoom:", err) end
end)

SubSections.Actions:AddButton("Update Room", function()
	local ok, err = pcall(function() RoomControl:InvokeServer(buildArgs("updateRoom")) end)
	setStatus(ok and "Room Updated." or "Failed.", ok and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
	if not ok then warn("[Mitu] UpdateRoom:", err) end
end)

SubSections.Actions:AddButton("Check Room", function()
	local exists = checkRoom()
	setStatus(exists and "Room Exists." or "No Room.", exists and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 165, 0))
end)

SubSections.Actions:AddButton("Exit Room", function()
	local ok, err = pcall(function() RoomControl:InvokeServer(buildArgs("removePlayer")) end)
	setStatus(ok and "Exited Room." or "Failed.", ok and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(255, 0, 0))
	if not ok then warn("[Mitu] ExitRoom:", err) end
end)

SubSections.Actions:AddButton("Start Room", function()
	local ok, err = pcall(function()
		RoomControl:InvokeServer({ Type = "play" })
	end)
	setStatus(ok and "Game Started." or "Failed.", ok and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
	if not ok then warn("[Mitu] StartGame:", err) end
end)

Window.Frame.Topbar.Konata.Visible = true
Window:Toggle(true)
