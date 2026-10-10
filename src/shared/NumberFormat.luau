--[[
	NumberFormat.luau
	Simulator-style number abbreviations: 950 -> "950", 1234 -> "1.23K", 15e9 -> "15B".
]]

local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text: string): string
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function NumberFormat.Abbreviate(value: number): string
	if value ~= value then
		return "0"
	end
	if value == math.huge then
		return "∞"
	end

	local sign = if value < 0 then "-" else ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(math.floor(value))
	end

	local function formatTier(tier: number): string
		local scaled = value / 10 ^ (tier * 3)
		local decimals = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
		return string.format("%." .. decimals .. "f", scaled)
	end

	local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
	local text = formatTier(tier)

	-- 999,999 rounds to "1000K"; bump into the next tier ("1M") instead.
	if (tonumber(text) or 0) >= 1000 and tier < #SUFFIXES - 1 then
		tier += 1
		text = formatTier(tier)
	end

	return sign .. trimZeros(text) .. SUFFIXES[tier + 1]
end

function NumberFormat.Commas(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return (if value < 0 then "-" else "") .. formatted
end

function NumberFormat.Multiplier(value: number): string
	if value >= 1000 then
		return "x" .. NumberFormat.Abbreviate(value)
	end
	return "x" .. trimZeros(string.format("%.2f", value))
end

function NumberFormat.Percent(value: number): string
	return trimZeros(string.format("%.1f", value * 100)) .. "%"
end

return NumberFormat
