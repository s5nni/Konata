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

local oldConfig = nil
local canUpdate = false
getgenv().__Mitulib.Runtime.RunLoops:BindToHeartbeat("Sync", function()
	if canUpdate == true then return end
	if not canUpdate then
		canUpdate = true
		oldConfig = Config
		wait(5)
		-- Deep‑compare oldConfig and Config, ignoring Sync_Cloud.Enabled
		local function deepEqual(a, b, ignorePath)
			-- ignorePath is a list of keys like {"Settings","Account","Sync_Cloud","Enabled"}
			-- For simplicity, we nil that exact leaf before comparing.
			local function stripPath(tbl, path)
				for i = 1, #path - 1 do
					if type(tbl) ~= "table" then return end
					tbl = tbl[path[i]]
				end
				if type(tbl) == "table" then
					tbl[path[#path]] = nil
				end
			end

			local copyA = getgenv().__Mitulib.Runtime.DeepCopy and getgenv().__Mitulib.Runtime.DeepCopy(oldConfig) or oldConfig -- assume minimal shallow copy if not available? Better to implement.
			local copyB = getgenv().__Mitulib.Runtime.DeepCopy and getgenv().__Mitulib.Runtime.DeepCopy(Config) or Config

			-- Fallback deep copy (since we can't assume library functions exist)
			if not copyA then
				local function _deepCopy(orig)
					if type(orig) ~= "table" then return orig end
					local copy = {}
					for k, v in pairs(orig) do
						copy[k] = _deepCopy(v)
					end
					return copy
				end
				copyA = _deepCopy(oldConfig)
				copyB = _deepCopy(Config)
			end

			stripPath(copyA, {"Settings", "Account", "Sync_Cloud", "Enabled"})
			stripPath(copyB, {"Settings", "Account", "Sync_Cloud", "Enabled"})
			
			local function _equal(a, b)
				if type(a) ~= type(b) then return false end
				if type(a) ~= "table" then return a == b end
				for k, v in pairs(a) do
					if not _equal(v, b[k]) then return false end
				end
				for k, _ in pairs(b) do
					if a[k] == nil then return false end
				end
				return true
			end

			if not _equal(copyA, copyB) then
				warn("found")
			end
		end

		deepEqual(oldConfig, Config)
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
