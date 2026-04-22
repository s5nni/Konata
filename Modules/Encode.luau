local Codec = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local BASE = #ALPHABET

local Lookup = {}
for i = 1, BASE do
    Lookup[ALPHABET:sub(i,i)] = i - 1
end

local function RNG(seed)
    local state = seed
    return function()
        state = (1103515245 * state + 12345) % 2147483648
        return state
    end
end

local function encodeByte(n)
    return ALPHABET:sub((n % BASE) + 1, (n % BASE) + 1)
end

local function decodeByte(c)
    return Lookup[c]
end

-- encode string (self-contained)
function Codec.Encode(str, seed)
    local rng = RNG(seed)

    local len = #str
    local out = {}

    -- store length first (3 chars fixed)
    for i = 1, 3 do
        local shift = rng() % 256
        local b = math.floor(len / (256 ^ (i - 1))) % 256
        b = bit32.bxor(b, shift)
        table.insert(out, encodeByte(b))
    end

    for i = 1, len do
        local b = string.byte(str, i)
        local r = rng() % 256
        local mixed = bit32.bxor(b, r)
        table.insert(out, encodeByte(mixed))
    end

    -- padding (optional, purely cosmetic)
    while #table.concat(out) < 50 do
        local r = rng() % BASE
        table.insert(out, ALPHABET:sub(r+1, r+1))
    end

    return table.concat(out)
end

function Codec.Decode(encoded, seed)
    local rng = RNG(seed)

    local bytes = {}

    for c in encoded:gmatch(".") do
        table.insert(bytes, decodeByte(c) or 0)
    end

    -- read length (first 3 bytes)
    local len = 0
    for i = 1, 3 do
        local shift = rng() % 256
        len = len + bit32.bxor(bytes[i], shift) * (256 ^ (i - 1))
    end

    local out = {}

    local idx = 4
    for i = 1, len do
        local r = rng() % 256
        local b = bit32.bxor(bytes[idx], r)
        out[i] = string.char(b)
        idx += 1
    end

    return table.concat(out)
end

return Codec
