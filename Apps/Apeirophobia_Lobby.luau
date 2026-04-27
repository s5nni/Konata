-- Protection layer from direct execution.
local keyVararg, lenVararg = ...
if keyVararg == nil or lenVararg == nil then error("Failure: 4") return end

print(keyVararg, lenVararg)

-- Checks and collect Apps Data
local AppsExists = getgenv().__Mitulib.Database:Exists("Apps")
if AppsExists == false then error("Failure: 1") return end

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
if placeData == nil then error("Failure: 2") return end

-- Decode Key
local newKey = getgenv().__Mitulib.Encode.Decode(keyVararg, placeData.Settings.Seed, lenVararg)
if newKey ~= placeData.Settings.Key then print(newKey, placeData.Settings.Key)  error("Failure: 3") return end
---------------------------------------------------

---------------------------------------------------
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
	extrakey = Enum.KeyCode.Q,
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

local List = {}
local Actions = {}

local Terminal = SubSections.Actions:AddTerminal("Logs", {extend = 150})

Actions["Create"] = function()
	local ok, err = pcall(function()
		RoomControl:InvokeServer(buildArgs("createRoom"))
	end)
	Terminal:Add(ok and "Room Created." or "Failed.", {type = ok and "Success" or "Error"})
	if not ok then Terminal:Add("Faliure: "..err, {type = "Error"}) end
	return ok
end

Actions["Update"] = function()
	local ok, err = pcall(function()
		RoomControl:InvokeServer(buildArgs("updateRoom"))
	end)
	Terminal:Add(ok and "Room Updated." or "Failed.", {type = ok and "Success" or "Error"})
	if not ok then Terminal:Add("Faliure: "..err, {type = "Error"}) end
	return ok
end

Actions["Check"] = function()
	local exists = checkRoom()
	Terminal:Add(exists and "Room Exists." or "No Room.", {type = "feed"})
	return exists
end

Actions["Leave"] = function()
	local ok, err = pcall(function()
		RoomControl:InvokeServer(buildArgs("removePlayer"))
	end)
	Terminal:Add(ok and "Exited Room." or "Failed.", {type = ok and "Success" or "Error"})
	if not ok then Terminal:Add("Faliure: "..err, {type = "Error"}) end
	return ok
end

Actions["Start"] = function()
	local ok, err = pcall(function()
		RoomControl:InvokeServer({ Type = "play" })
	end)
	Terminal:Add(ok and "Game Started." or "Failed.", {type = ok and "Success" or "Error"})
	if not ok then Terminal:Add("Faliure: "..err, {type = "Error"}) end
	return ok
end

SubSections.Actions:AddPriority("Choose Sequence", {"Create", "Update", "Start", "Leave"}, {exclude = true}, function(va)
	List = va
end)

SubSections.Actions:AddButton("Launch", function()
	if #List == 0 then
		Terminal:Add("No sequence selected.", {type = "Error"})
		return
	end

	for i, actionName in ipairs(List) do
		local action = Actions[actionName]
		if action then
			print(string.format("[Mitu] Step %d/%d: %s", i, #List, actionName))
			local success = action()
			if not success then
				warn(string.format("[Mitu] Sequence halted at '%s' (step %d)", actionName, i))
				break
			end
		else
			warn(string.format("[Mitu] Unknown action in sequence: %s", tostring(actionName)))
		end
	end
end)

SubSections.Actions:AddButton("Clear Logs", function()
	Terminal:Reset()
end)

Window.Frame.Topbar.Konata.Visible = true
Window:Toggle(true)
