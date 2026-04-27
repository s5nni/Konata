local UrlCodec = {}

local URL_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local ALLOWED_PATTERN = "^[A-Za-z0-9_-]+$"
local CLEAN_PATTERN = "[^A-Za-z0-9_-]"

local function HashSeed(seed)
    local str = tostring(seed)
    local hash = 2166136261

    for i = 1, #str do
        hash = bit32.bxor(hash, string.byte(str, i))
        hash = (hash * 16777619) % 4294967296
    end

    return hash
end

local function CreateRNG(seed)
    local state = HashSeed(seed)

    return function()
        state = (1664525 * state + 1013904223) % 4294967296
        return state
    end
end

local function GenerateAlphabet(seed)
    local rng = CreateRNG(seed)
    local chars = {}

    for i = 1, #URL_ALPHABET do
        chars[i] = URL_ALPHABET:sub(i, i)
    end

    for i = #chars, 2, -1 do
        local j = (rng() % i) + 1
        chars[i], chars[j] = chars[j], chars[i]
    end

    return table.concat(chars)
end

local function ValidateInput(text)
    if type(text) ~= "string" then
        error("Encode input must be string")
    end

    if not text:match(ALLOWED_PATTERN) then
        error("Only A-Z a-z 0-9 _ - are allowed")
    end
end

local function BytesToSafe(bytes, alphabet)
    local out = {}

    for _, byte in ipairs(bytes) do
        local high = math.floor(byte / 64)
        local low = byte % 64

        out[#out + 1] = alphabet:sub(high + 1, high + 1)
        out[#out + 1] = alphabet:sub(low + 1, low + 1)
    end

    return table.concat(out)
end

local function SafeToBytes(str, alphabet)
    local reverse = {}

    for i = 1, #alphabet do
        reverse[alphabet:sub(i, i)] = i - 1
    end

    local bytes = {}

    for i = 1, #str, 2 do
        local a = reverse[str:sub(i, i)]
        local b = reverse[str:sub(i + 1, i + 1)]

        if a == nil or b == nil then
            error("Invalid encoded string")
        end

        bytes[#bytes + 1] = (a * 64) + b
    end

    return bytes
end

local function CleanDecoded(text)
    return text:gsub(CLEAN_PATTERN, "")
end

function UrlCodec.Encode(input, seed)
    ValidateInput(input)

    local rng = CreateRNG(seed)
    local alphabet = GenerateAlphabet(seed)

    local bytes = {}

    for i = 1, #input do
        local byte = string.byte(input, i)
        local key = rng() % 256

        bytes[#bytes + 1] = bit32.bxor(byte, key)
    end

    return BytesToSafe(bytes, alphabet)
end

function UrlCodec.Decode(encoded, seed)
    if type(encoded) ~= "string" then
        error("Decode input must be string")
    end

    local rng = CreateRNG(seed)
    local alphabet = GenerateAlphabet(seed)

    local bytes = SafeToBytes(encoded, alphabet)

    local chars = {}

    for i, byte in ipairs(bytes) do
        local key = rng() % 256
        local decoded = bit32.bxor(byte, key) % 256

        chars[i] = string.char(decoded)
    end

    local result = table.concat(chars)

    return CleanDecoded(result)
end

return UrlCodec
