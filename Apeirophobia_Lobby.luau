local Attempts = 0
repeat Attempts = Attempts + 1; wait(1); until getgenv().__Mitulib.Authorized == true
getgenv().__Mitulib.Authorized = nil

local main_Dehash = loadstring(game:HttpGet("https://raw.githubusercontent.com/s5nni/Konata/refs/heads/main/Dehash.luau"))()
local __ScreenGui = getgenv().__Mitulib.Source:GetScreenGui()
__ScreenGui.DisplayOrder = -10
__ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local LocalPlayer = game:GetService("Players").LocalPlayer
local RoomControl = game:GetService("ReplicatedStorage")
	:WaitForChild("Assets")
	:WaitForChild("Events")
	:WaitForChild("RoomControl")

-- ── Levels ───────────────────────────────────────────────────────────────────

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

-- ── Window ───────────────────────────────────────────────────────────────────

local Window = getgenv().__Mitulib.Source:AddWindow({
	title   = { "Mitu", "Konata" },
	theme   = { Accent = Color3.fromRGB(80, 125, 215) },
	key     = Enum.KeyCode.E,
	default = false,
})

-- ── Config ───────────────────────────────────────────────────────────────────

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

-- ── Tabs / Sections ──────────────────────────────────────────────────────────

local Tabs = {
	Room     = Window:AddTab("Room",     { default = true }),
	Settings = Window:AddTab("Settings", { default = false }),
}

local Sections = {
	Setup   = Tabs.Room:AddSection("Setup",   { default = true }),
	Control = Tabs.Room:AddSection("Control", { default = true }),
}

local SubSections = {
	Options = Sections.Setup:AddSubSection("Options",  { default = true }),
	Actions = Sections.Control:AddSubSection("Actions", { default = true }),
}

-- ── Setup ────────────────────────────────────────────────────────────────────

local ch1Names = getLevelNames(1)
Config.Room.Level = Levels.Chapters[1][ch1Names[1]]

-- Chapter
SubSections.Options:AddDropdown("Chapter", { "Chapter 1", "Chapter 2" }, { multi = false, default = "Chapter 1" }, function(val)
	Config.Room.Chapter = val == "Chapter 1" and 1 or 2
	local names = getLevelNames(Config.Room.Chapter)
	Config.Room.Level = Levels.Chapters[Config.Room.Chapter][names[1]]
	if Config.State.LevelDrop then
		Config.State.LevelDrop:SetList(names)
		Config.State.LevelDrop:Select(names[1])
	end
end)

-- Level
Config.State.LevelDrop = SubSections.Options:AddDropdown("Level", ch1Names, { multi = false, default = ch1Names[1] }, function(val)
	local levelNum = Levels.Chapters[Config.Room.Chapter][val]
	if levelNum ~= nil then
		Config.Room.Level = levelNum
	end
end)

-- GameMode
SubSections.Options:AddDropdown("GameMode", { "Easy", "Normal", "Hard", "Nightmare" }, { multi = false, default = "Easy" }, function(val)
	Config.Room.GameMode = ({ Easy = 1, Normal = 2, Hard = 3, Nightmare = 4 })[val]
end)

-- Max Players
SubSections.Options:AddDropdown("Max Players", { "1", "2", "3", "4" }, { multi = false, default = "1" }, function(val)
	Config.Room.MaxSize = tonumber(val)
end)

-- Toggles
SubSections.Options:AddToggle("Friends Only",        { default = false }, function(val) Config.Room.Locked       = val end)
SubSections.Options:AddToggle("IsTestPlace",         { default = false }, function(val) Config.Room.IsTestPlace  = val end)
SubSections.Options:AddToggle("IsPre-PublishPlace",  { default = false }, function(val) Config.Room.IsPrePublish = val end)

-- ── Actions ──────────────────────────────────────────────────────────────────

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

--[[
    Add this after the existing Tabs/Sections setup in Apeirophobia_Lobby.luau
    Example location: after line 47 where Tabs.Settings is defined.
--]]

-- 1. Create the Account section within the Settings tab
local AccountSection = Tabs.Settings:AddSection("Account")

-- 2. Fetch the latest agent data from Firebase
--    (agentData is already available from the launcher's global scope)
local currentAgentData = agentData or {}

-- 3. Helper function to safely get nested table values
local function getNestedValue(tbl, ...)
    local current = tbl
    for _, key in ipairs({...}) do
        if type(current) ~= "table" then return nil end
        current = current[key]
    end
    return current
end

-- 4. Display Premium Status
local premiumStatus = getNestedValue(currentAgentData, "Account", "Premium")
local premiumText = "None"
if premiumStatus and premiumStatus.Activated and (premiumStatus.Duration or 0) > 0 then
    local pType = premiumStatus.Type or "Unknown"
    local pDur = premiumStatus.Duration or 0
    premiumText = pType == "Lifetime" and "Lifetime" or string.format("%dh %dm remaining", math.floor(pDur/3600), math.floor((pDur%3600)/60))
end
AccountSection:AddLabel("Premium: " .. premiumText)

-- 5. Display Ban Status
local isBanned = getNestedValue(currentAgentData, "Account", "Settings", "IsBanned") or false
AccountSection:AddLabel("Banned: " .. (isBanned and "Yes" or "No"))

-- 6. Display Linked Discord (if any)
local discordTag = getNestedValue(currentAgentData, "Account", "Settings", "Discord")
if discordTag then
    AccountSection:AddLabel("Discord: " .. discordTag)
else
    AccountSection:AddLabel("Discord: Not linked")
end

-- 7. Display Number of Authorized Sessions
local authCount = 0
if currentAgentData.Authorizations then
    for _ in pairs(currentAgentData.Authorizations) do authCount = authCount + 1 end
end
AccountSection:AddLabel("Active Sessions: " .. tostring(authCount))

-- 8. Clipboard button to copy HWID
AccountSection:AddClipboardLabel("Copy HWID", function()
    local hwid = gethwid()
    setclipboard(hwid)
    getgenv().__Mitulib.Source:Notify({
        title   = "Account",
        text    = "HWID copied to clipboard!",
        color   = Color3.fromRGB(80, 125, 215),
        duration = 3,
    })
end)

Window.Frame.Topbar.Konata.Visible = true
Window:Toggle(true)
