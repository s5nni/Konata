local Database = {}
Database.__index = Database

local HttpService = game:GetService("HttpService")

-- Default configuration
local DEFAULT_CONFIG = {
	Url = "",
	Secret = "",
	Timeout = 30,
	Retries = 3,
	RetryDelay = 0.5,
}

if not request then
	warn("[Database] 'request' function not found, ensure you're using a compatible executor")
end

--  Constructor
--- Creates a new Database instance
--- @param options table? Optional configuration table { Url, Secret, Timeout, Retries, RetryDelay }
--- @return table A new Database instance
function Database:New(options)
	local instance = setmetatable({}, Database)
	instance.Configuration = {
		Url = "",
		Secret = "",
		Timeout = DEFAULT_CONFIG.Timeout,
		Retries = DEFAULT_CONFIG.Retries,
		RetryDelay = DEFAULT_CONFIG.RetryDelay,
	}
	if options then
		instance:SetConfiguration(options)
	end
	return instance
end

--  Configuration
--- Sets configuration options for the database
--- @param options table Configuration table with any of: { Url, Secret, Timeout, Retries, RetryDelay }
--- @return boolean Success
function Database:SetConfiguration(options)
	assert(type(options) == "table", "[Database] SetConfiguration: options must be a table")
	
	if options.Url ~= nil then
		assert(type(options.Url) == "string", "[Database] SetConfiguration: Url must be a string")
		self.Configuration.Url = options.Url
	end
	
	if options.Secret ~= nil then
		assert(type(options.Secret) == "string", "[Database] SetConfiguration: Secret must be a string")
		self.Configuration.Secret = options.Secret
	end
	
	if options.Timeout ~= nil then
		assert(type(options.Timeout) == "number", "[Database] SetConfiguration: Timeout must be a number")
		assert(options.Timeout > 0, "[Database] SetConfiguration: Timeout must be greater than 0")
		self.Configuration.Timeout = options.Timeout
	end
	
	if options.Retries ~= nil then
		assert(type(options.Retries) == "number", "[Database] SetConfiguration: Retries must be a number")
		assert(options.Retries >= 0, "[Database] SetConfiguration: Retries must be non-negative")
		self.Configuration.Retries = options.Retries
	end
	
	if options.RetryDelay ~= nil then
		assert(type(options.RetryDelay) == "number", "[Database] SetConfiguration: RetryDelay must be a number")
		assert(options.RetryDelay > 0, "[Database] SetConfiguration: RetryDelay must be greater than 0")
		self.Configuration.RetryDelay = options.RetryDelay
	end
	
	return true
end

--- Returns the current configuration
--- @return table Current configuration
function Database:GetConfiguration()
	return {
		Url = self.Configuration.Url,
		Secret = self.Configuration.Secret,
		Timeout = self.Configuration.Timeout,
		Retries = self.Configuration.Retries,
		RetryDelay = self.Configuration.RetryDelay,
	}
end

--  Internal Helpers
--- Validates that minimal configuration is set
--- @return boolean Is configuration valid
function Database:_validateConfig()
	local c = self.Configuration
	if c.Url == "" then
		warn("[Database] Configuration incomplete: Url must be set. Call :SetConfiguration({ Url = ... })")
		return false
	end
	-- Secret is now optional
	return true
end

--- Validates a path string
--- @param path string The path to validate
--- @return boolean Is path valid
function Database:_validatePath(path)
	assert(type(path) == "string", "[Database] Path must be a string")
	assert(path ~= "", "[Database] Path cannot be empty")
	assert(not path:match("%.%."), "[Database] Path cannot contain '..'")
	return true
end

--- Normalises path and builds complete URL with auth and extra params
--- @param path string The database path
--- @param extraParams string? Additional query parameters
--- @return string The complete URL
function Database:_buildUrl(path, extraParams)
	local c = self.Configuration
	if path:sub(1, 1) ~= "/" then 
		path = "/" .. path 
	end
	local url = c.Url .. path .. ".json"
	
	-- Only append auth if secret is configured
	if c.Secret and c.Secret ~= "" then
		url = url .. "?auth=" .. c.Secret
		if extraParams then 
			url = url .. "&" .. extraParams 
		end
	elseif extraParams then
		url = url .. "?" .. extraParams
	end
	
	return url
end

--- Safely decodes JSON string
--- @param raw string? The JSON string to decode
--- @return any The decoded value, or nil if decode fails
function Database:_decode(raw)
	if raw == nil or raw == "" or raw == "null" then 
		return nil 
	end
	
	local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		warn("[Database] Failed to decode JSON: " .. tostring(result))
		return nil
	end
	return result
end

--- Safely encodes data to JSON string
--- @param data any The data to encode
--- @return string? The encoded JSON, or nil if encode fails
function Database:_encode(data)
	local ok, result = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok then
		warn("[Database] Failed to encode JSON: " .. tostring(result))
		return nil
	end
	return result
end

--- Core HTTP dispatcher with retry logic and timeout support
--- @param method string HTTP method (GET, POST, PUT, PATCH, DELETE)
--- @param path string Database path
--- @param data any? Data to send (for POST/PUT/PATCH)
--- @param extraParams string? Additional query parameters
--- @param timeout number? Custom timeout for this request
--- @return table? The response object, or nil if all retries failed
function Database:_request(method, path, data, extraParams, timeout)
	if not self:_validateConfig() then 
		return nil 
	end
	
	self:_validatePath(path)
	
	local url = self:_buildUrl(path, extraParams)
	local body = nil
	local retries = self.Configuration.Retries
	local retryDelay = self.Configuration.RetryDelay
	local requestTimeout = timeout or self.Configuration.Timeout
	
	if data ~= nil then
		body = self:_encode(data)
		if body == nil then 
			return nil 
		end
	end
	
	local lastError = nil
	
	for attempt = 0, retries do
		if attempt > 0 then
			task.wait(retryDelay)
		end
		
		local ok, response = pcall(function()
			return request({
				Url = url,
				Method = method,
				Headers = { ["Content-Type"] = "application/json" },
				Body = body,
				Timeout = requestTimeout,
			})
		end)
		
		if not ok then
			lastError = response
			if attempt < retries then
				warn(string.format("[Database] Request attempt %d/%d failed: %s, retrying...", attempt + 1, retries + 1, tostring(response)))
			else
				warn(string.format("[Database] Request failed after %d attempts: %s", retries + 1, tostring(response)))
			end
			continue
		end
		
		local status = response and response.StatusCode or 0
		
		-- Firebase DELETE returns 200 with body "null", treat as success
		if status == 200 then
			return response
		end
		
		lastError = string.format("HTTP %d", status)
		
		-- Retry on server errors (5xx) but not client errors (4xx)
		if status >= 500 and attempt < retries then
			warn(string.format("[Database] %s /%s returned HTTP %d, retrying...", method, path, status))
		else
			warn(string.format("[Database] %s /%s returned HTTP %d", method, path, status))
			return nil
		end
	end
	
	return nil
end

--  Read Methods

--- Gets a decoded value from the database
--- @param path string The database path
--- @param timeout number? Custom timeout for this request
--- @return any The decoded value, or nil if not found or request failed
function Database:Get(path, timeout)
	assert(type(path) == "string", "[Database] Get: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Get: timeout must be a number")
	end
	
	local response = self:_request("GET", path, nil, nil, timeout)
	if not response then 
		return nil 
	end
	
	return self:_decode(response.Body)
end

--- Gets a raw string value from the database
--- @param path string The database path
--- @param timeout number? Custom timeout for this request
--- @return string? The raw response body, or nil if request failed
function Database:GetRaw(path, timeout)
	assert(type(path) == "string", "[Database] GetRaw: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] GetRaw: timeout must be a number")
	end
	
	local response = self:_request("GET", path, nil, nil, timeout)
	if not response then 
		return nil 
	end
	
	return response.Body
end

--- Gets all keys at a path (shallow query)
--- @param path string The database path
--- @param timeout number? Custom timeout for this request
--- @return table Array of key strings
function Database:Keys(path, timeout)
	assert(type(path) == "string", "[Database] Keys: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Keys: timeout must be a number")
	end
	
	local response = self:_request("GET", path, nil, "shallow=true", timeout)
	if not response then 
		return {} 
	end
	
	local data = self:_decode(response.Body)
	if type(data) ~= "table" then 
		return {} 
	end
	
	local keys = {}
	for k in pairs(data) do
		table.insert(keys, k)
	end
	
	return keys
end

--- Checks if a path exists in the database
--- @param path string The database path
--- @param timeout number? Custom timeout for this request
--- @return boolean Does the path exist
function Database:Exists(path, timeout)
	assert(type(path) == "string", "[Database] Exists: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Exists: timeout must be a number")
	end
	
	return self:Get(path, timeout) ~= nil
end

--  Write Methods

--- Sets a value at a path (overwrites entirely)
--- @param path string The database path
--- @param data any The data to set
--- @param timeout number? Custom timeout for this request
--- @return boolean Success
function Database:Set(path, data, timeout)
	assert(type(path) == "string", "[Database] Set: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Set: timeout must be a number")
	end
	
	return self:_request("PUT", path, data, nil, timeout) ~= nil
end

--- Patches (merges) data at a path
--- @param path string The database path
--- @param data table The data to merge
--- @param timeout number? Custom timeout for this request
--- @return boolean Success
function Database:Patch(path, data, timeout)
	assert(type(path) == "string", "[Database] Patch: path must be a string")
	assert(type(data) == "table", "[Database] Patch: data must be a table")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Patch: timeout must be a number")
	end
	
	return self:_request("PATCH", path, data, nil, timeout) ~= nil
end

--- Pushes data to a path (creates new child with auto-generated key)
--- @param path string The database path
--- @param data any The data to push
--- @param timeout number? Custom timeout for this request
--- @return string? The auto-generated key, or nil if request failed
function Database:Push(path, data, timeout)
	assert(type(path) == "string", "[Database] Push: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Push: timeout must be a number")
	end
	
	local response = self:_request("POST", path, data, nil, timeout)
	if not response then 
		return nil 
	end
	
	local result = self:_decode(response.Body)
	-- Firebase returns { name = "-autoGeneratedKey" }
	return result and result.name or nil
end

--- Deletes a value at a path
--- @param path string The database path
--- @param timeout number? Custom timeout for this request
--- @return boolean Success
function Database:Delete(path, timeout)
	assert(type(path) == "string", "[Database] Delete: path must be a string")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Delete: timeout must be a number")
	end
	
	return self:_request("DELETE", path, nil, nil, timeout) ~= nil
end

--  Utility Methods

--- Atomically increments a number at a path
--- @param path string The database path
--- @param amount number? The amount to increment by (default: 1)
--- @param timeout number? Custom timeout for this request
--- @return boolean Success
function Database:Increment(path, amount, timeout)
	assert(type(path) == "string", "[Database] Increment: path must be a string")
	
	if amount == nil then
		amount = 1
	else
		assert(type(amount) == "number", "[Database] Increment: amount must be a number")
	end
	
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Increment: timeout must be a number")
	end
	
	-- Use transaction for atomic increment
	return self:Transaction(path, function(current)
		local base = type(current) == "number" and current or 0
		return base + amount
	end, timeout)
end

--- Executes an atomic transaction at a path
--- @param path string The database path
--- @param callback function Function called with current value, should return new value or nil to abort
--- @param timeout number? Custom timeout for this request
--- @return boolean Success
function Database:Transaction(path, callback, timeout)
	assert(type(path) == "string", "[Database] Transaction: path must be a string")
	assert(type(callback) == "function", "[Database] Transaction: callback must be a function")
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Transaction: timeout must be a number")
	end
	
	local current = self:Get(path, timeout)
	local newValue = callback(current)
	
	if newValue == nil then
		return false  -- caller chose to abort
	end
	
	return self:Set(path, newValue, timeout)
end

--- Listens to changes at a path and calls callback when value changes
--- @param path string The database path
--- @param callback function Called with (newValue, oldValue) when value changes
--- @param interval number? Polling interval in seconds (default: 3, minimum: 1)
--- @param timeout number? Custom timeout for requests
--- @return table A handle with :Stop() method to stop listening
function Database:Listen(path, callback, interval, timeout)
	assert(type(path) == "string", "[Database] Listen: path must be a string")
	assert(type(callback) == "function", "[Database] Listen: callback must be a function")
	
	interval = math.max(interval or 3, 1)
	
	if timeout ~= nil then
		assert(type(timeout) == "number", "[Database] Listen: timeout must be a number")
	end
	
	local self_ref = self
	local running = true
	local lastJson = nil
	
	local handle = {}
	
	--- Stops listening for changes
	function handle:Stop()
		running = false
	end
	
	task.spawn(function()
		while running do
			local value = self_ref:Get(path, timeout)
			
			-- Serialise to JSON for a simple deep-equality check
			local currentJson
			if value ~= nil then
				local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
				currentJson = ok and encoded or nil
			end
			
			-- Only call callback if value actually changed
			if currentJson ~= lastJson then
				local oldDecoded
				if lastJson ~= nil then
					oldDecoded = self_ref:_decode(lastJson)
				end
				
				local ok, err = pcall(callback, value, oldDecoded)
				if not ok then
					warn(string.format("[Database] Listen callback error: %s", tostring(err)))
				end
				
				lastJson = currentJson
			end
			
			task.wait(interval)
		end
	end)
	
	return handle
end

return Database
