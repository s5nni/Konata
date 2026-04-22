--[[
    Seeded URL-Safe Encoder / Decoder
    ----------------------------------
    Features:
    - Converts any string into a 50+ character URL-safe string
    - Uses a numeric seed
    - Fully reversible
    - URL-safe output (A-Z a-z 0-9 - _)
    - Deterministic: same input + same seed = same result
]]

local UrlCodec = {}

-- URL-safe alphabet
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local BASE = #ALPHABET

-- Build lookup table
local Lookup = {}
for i = 1, BASE do
    Lookup[ALPHABET:sub(i, i)] = i - 1
end

-- Simple seeded pseudo-random generator
local function CreateRNG(seed)
    local state = tonumber(seed) or 1

    return function()
        state = (1103515245 * state + 12345) % 2147483648
        return state
    end
end

-- Convert number to URL-safe base
local function EncodeNumber(num)
    if num == 0 then
        return ALPHABET:sub(1,1)
    end

    local result = ""

    while num > 0 do
        local remainder = (num % BASE) + 1
        result = ALPHABET:sub(remainder, remainder) .. result
        num = math.floor(num / BASE)
    end

    return result
end

-- Convert URL-safe base back to number
local function DecodeNumber(str)
    local num = 0

    for i = 1, #str do
        local char = str:sub(i, i)
        local value = Lookup[char]

        num = (num * BASE) + value
    end

    return num
end

-- Encode string
function UrlCodec.Encode(input, seed)
    local rng = CreateRNG(seed)

    local chunks = {}

    for i = 1, #input do
        local byte = string.byte(input, i)

        -- seeded XOR-style scramble
        local rand = rng() % 256
        local mixed = bit32.bxor(byte, rand)

        table.insert(chunks, EncodeNumber(mixed))
    end

    local joined = table.concat(chunks, ".")

    -- Padding to ensure 50+ chars
    while #joined < 50 do
        local rand = rng() % BASE
        joined = joined .. ALPHABET:sub(rand + 1, rand + 1)
    end

    return joined
end

-- Decode string
function UrlCodec.Decode(encoded, seed, originalLength)
    if type(encoded) ~= "string" then
        return nil, "Invalid encoded input"
    end
    local rng = CreateRNG(seed)
    local parts = {}
    for part in string.gmatch(encoded, "[^%.]+") do
        table.insert(parts, part)
    end
    -- Use provided length or fall back to number of parts
    local limit = originalLength or #parts
    if limit <= 0 then
        return nil, "No data to decode"
    end
    local output = {}
    for i = 1, limit do
        local encodedPart = parts[i]
        if not encodedPart then break end
        local mixed = DecodeNumber(encodedPart)
        local rand = rng() % 256
        local byte = bit32.bxor(mixed, rand)
        output[i] = string.char(byte)
    end
    return table.concat(output)
end

return UrlCodec
