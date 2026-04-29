assert(typeof(Drawing) == "table" and typeof(Drawing.new) == "function", "[DrawingLib] Drawing.new is not available in this environment.")

local _registry = {}
local _counter  = 0  

local DEFAULTS = {
	Line = {
		Visible      = true,
		ZIndex       = 1,
		Transparency = 1,
		Color        = Color3.new(1, 1, 1),
		From         = Vector2.new(0, 0),
		To           = Vector2.new(0, 0),
		Thickness    = 1,
	},
	Text = {
		Visible       = true,
		ZIndex        = 1,
		Transparency  = 1,
		Color         = Color3.new(1, 1, 1),
		Text          = "",
		Size          = 18,
		Center        = false,
		Outline       = false,
		OutlineColor  = Color3.new(0, 0, 0),
		Position      = Vector2.new(0, 0),
		Font          = Drawing.Fonts and Drawing.Fonts.UI or 0,
	},
	Image = {
		Visible      = true,
		ZIndex       = 1,
		Transparency = 1,
		Color        = Color3.new(1, 1, 1),
		Data         = "",
		Size         = Vector2.new(0, 0),
		Position     = Vector2.new(0, 0),
		Rounding     = 0,
	},
	Circle = {
		Visible      = true,
		ZIndex       = 1,
		Transparency = 1,
		Color        = Color3.new(1, 1, 1),
		Position     = Vector2.new(0, 0),
		Radius       = 0,
		Thickness    = 1,
		Filled       = false,
		NumSides     = 250,
	},
	Square = {
		Visible      = true,
		ZIndex       = 1,
		Transparency = 1,
		Color        = Color3.new(1, 1, 1),
		Position     = Vector2.new(0, 0),
		Size         = Vector2.new(0, 0),
		Thickness    = 1,
		Filled       = false,
	},
	Triangle = {
		Visible      = true,
		ZIndex       = 1,
		Transparency = 1,
		Color        = Color3.new(1, 1, 1),
		PointA       = Vector2.new(0, 0),
		PointB       = Vector2.new(0, 0),
		PointC       = Vector2.new(0, 0),
		Thickness    = 1,
		Filled       = false,
	},
	Quad = {
		Visible      = true,
		ZIndex       = 1,
		Transparency = 1,
		Color        = Color3.new(1, 1, 1),
		PointA       = Vector2.new(0, 0),
		PointB       = Vector2.new(0, 0),
		PointC       = Vector2.new(0, 0),
		PointD       = Vector2.new(0, 0),
		Thickness    = 1,
		Filled       = false,
	},
	Font = {
		Data = "",
	},
}

local WRAPPER_KEYS = { _raw = true, _type = true, _name = true }

local function makeWrapper(raw, objType, name)
	local wrapper = {
		_raw  = raw,
		_type = objType,
		_name = name,
	}
	local mt = {}
	mt.__index = function(t, k)
		if WRAPPER_KEYS[k] then
			return rawget(t, k)
		end
		if k == "Name" then
			return rawget(t, "_name")
		end
		local ok, val = pcall(function()
			return rawget(t, "_raw")[k]
		end)
		if ok then
			return val
		end
		return nil
	end
	mt.__newindex = function(t, k, v)
		if WRAPPER_KEYS[k] then
			rawset(t, k, v)
			return
		end
		if k == "Name" then
			local oldName = rawget(t, "_name")
			if _registry[oldName] == t then
				_registry[oldName] = nil
			end
			rawset(t, "_name", v)
			_registry[v] = t
			return
		end
		local ok, err = pcall(function()
			rawget(t, "_raw")[k] = v
		end)
		if not ok then
			warn(("[DrawingLib] Could not set '%s' on '%s': %s")
				:format(tostring(k), rawget(t, "_name"), tostring(err)))
		end
	end
	mt.__tostring = function(t)
		return ("[DrawingLib.%s] \"%s\""):format(rawget(t, "_type"), rawget(t, "_name"))
	end
	return setmetatable(wrapper, mt)
end

local DrawingLib = {}
DrawingLib.__index = DrawingLib

function DrawingLib:New(objType)
	assert(type(objType) == "string", "[DrawingLib] New: objType must be a string.")
	assert(DEFAULTS[objType], ("[DrawingLib] New: Unknown type '%s'. Valid types: Line, Text, Image, Circle, Square, Triangle, Quad, Font."):format(objType))
	local raw = Drawing.new(objType)
	for k, v in pairs(DEFAULTS[objType]) do
		pcall(function() raw[k] = v end)
	end
	_counter += 1
	local defaultName = objType .. "_" .. _counter
	local wrapper = makeWrapper(raw, objType, defaultName)
	_registry[defaultName] = wrapper
	return wrapper
end

function DrawingLib:Remove(name)
	assert(type(name) == "string", "[DrawingLib] Remove: name must be a string.")
	local obj = _registry[name]
	if not obj then
		warn(("[DrawingLib] Remove: Object '%s' does not exist."):format(name))
		return
	end
	pcall(function() obj._raw:Destroy() end)
	_registry[name] = nil
end

function DrawingLib:Set(name, props)
	assert(type(name)  == "string", "[DrawingLib] Set: name must be a string.")
	assert(type(props) == "table",  "[DrawingLib] Set: props must be a table.")
	local obj = _registry[name]
	if not obj then
		warn(("[DrawingLib] Set: Object '%s' does not exist."):format(name))
		return
	end
	for k, v in pairs(props) do
		obj[k] = v  
	end
end

function DrawingLib:Get(name, props)
	assert(type(name)  == "string", "[DrawingLib] Get: name must be a string.")
	assert(type(props) == "table" and #props >= 1, "[DrawingLib] Get: props must be a non-empty array of property names.")
	local obj = _registry[name]
	if not obj then
		warn(("[DrawingLib] Get: Object '%s' does not exist."):format(name))
		return nil
	end
	if #props == 1 then
		return obj[props[1] ]
	end
	local result = {}
	for _, k in ipairs(props) do
		result[k] = obj[k]
	end
	return result
end

function DrawingLib:Exists(name)
	assert(type(name) == "string", "[DrawingLib] Exists: name must be a string.")
	return _registry[name] ~= nil
end

function DrawingLib:Clear()
	for name, obj in pairs(_registry) do
		pcall(function() obj._raw:Destroy() end)
		_registry[name] = nil
	end
end

function DrawingLib:IsOnScreen(position)
	local camera = workspace.CurrentCamera
	if not camera then return false end
	if typeof(position) == "Vector3" then
		local screenPos, onScreen = camera:WorldToViewportPoint(position)
		return onScreen and screenPos.Z > 0
	elseif typeof(position) == "Vector2" then
		local vp = camera.ViewportSize
		return position.X >= 0 and position.X <= vp.X
			and position.Y >= 0 and position.Y <= vp.Y
	else
		warn("[DrawingLib] IsOnScreen: expected Vector3 or Vector2, got " .. typeof(position))
		return false
	end
end

function DrawingLib:GetAll()
	local copy = {}
	for k, v in pairs(_registry) do
		copy[k] = v
	end
	return copy
end

return DrawingLib
