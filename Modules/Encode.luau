local UrlCodec = {}
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local BASE = #ALPHABET
local Lookup = {}
for i = 1, BASE do
	Lookup[ALPHABET:sub(i, i)] = i - 1
end
local function CreateRNG(seed)
	local state = tonumber(seed) or 1
	return function()
		state = (1103515245 * state + 12345) % 2147483648
		return state
	end
end
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
local function DecodeNumber(str)
	local num = 0
	for i = 1, #str do
		local char = str:sub(i, i)
		local value = Lookup[char]
		num = (num * BASE) + value
	end
	return num
end
function UrlCodec.Encode(input, seed)
	local rng = CreateRNG(seed)
	local chunks = {}
	for i = 1, #input do
		local byte = string.byte(input, i)
		local rand = rng() % 256
		local mixed = bit32.bxor(byte, rand)
		table.insert(chunks, EncodeNumber(mixed))
	end
	local joined = table.concat(chunks, ".")
	while #joined < 50 do
		local rand = rng() % BASE
		joined = joined .. ALPHABET:sub(rand + 1, rand + 1)
	end
	return joined
end
function UrlCodec.Decode(encoded, seed, originalLength)
	local rng = CreateRNG(seed)
	local parts = {}
	for part in string.gmatch(encoded, "[^%.]+") do
		table.insert(parts, part)
	end
	local output = {}
	for i = 1, originalLength do
		local encodedPart = parts[i]
		local mixed = DecodeNumber(encodedPart)
		local rand = rng() % 256
		local byte = bit32.bxor(mixed, rand)
		output[i] = string.char(byte)
	end
	return table.concat(output)
end
return UrlCodec
