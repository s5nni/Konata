local Library = {}
local HttpService = game:GetService("HttpService")

if not request then
	warn("[Library] 'request' function not found — ensure you're using a compatible executor")
end

Library.Configuration = {
	Url = "",
	Secret = "",
}

function Library:decodeJson(raw)
	local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and result or nil
end

function Library:_request(method, path, data)
	local config = self.Configuration or {}
	if config.Url == "" or config.Secret == "" then
		if Configuration and Configuration.Initialize and Configuration.Initialize.FireBase then
			config = Configuration.Initialize.FireBase
		else
			warn("[Library] Firebase configuration missing, set Library.Configuration.Url and .Secret")
			return nil
		end
	end

	local url = config.Url .. path .. ".json?auth=" .. config.Secret

	local body = nil
	if data then
		local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
		if not ok then
			warn("[Library] Failed to encode JSON: " .. tostring(encoded))
			return nil
		end
		body = encoded
	end

	local success, response = pcall(request, {
		Url     = url,
		Method  = method,
		Headers = { ["Content-Type"] = "application/json" },
		Body    = body,
	})

	if not success then
		warn("[Library] Request error: " .. tostring(response))
		return nil
	end

	if response and response.StatusCode == 200 then
		if method == "GET" and response.Body then
			return Library:decodeJson(response.Body)
		end
		return true
	end

	warn(string.format("[Library] Firebase %s failed, HTTP %d", method, response and response.StatusCode or 0))
	return nil
end

function Library:Get(path)
	assert(type(path) == "string", "path must be a string")
	return Library:_request("GET", path)
end

function Library:Set(path, data)
	assert(type(path) == "string", "path must be a string")
	return Library:_request("PUT", path, data)
end

function Library:Patch(path, data)
	assert(type(path) == "string", "path must be a string")
	return Library:_request("PATCH", path, data)
end

function Library:Push(path, data)
	assert(type(path) == "string", "path must be a string")
	return Library:_request("POST", path, data)
end

return Library
