--!strict
--[[
	BigNumber.lua

	A mantissa/exponent based big-number library for incremental games.
	Represents a value as: mantissa * 10^exponent, where 1 <= |mantissa| < 10.

	Why this approach instead of exact arbitrary-precision math:
	- Fast: every operation is a handful of float ops, not digit-array loops.
	- Scales as high as a Lua double's exponent allows (~10^(1.8e308) — you will
	  never realistically hit this ceiling in a game).
	- Precision loss beyond ~15-17 significant digits is invisible to players
	  since displayed numbers are always truncated anyway.

	Design choices (per project decisions):
	- Explicit function calls, no metatable/operator overloading. This means a
	  BigNumber is just a plain table {mantissa = number, exponent = number} —
	  it can be written straight into DataStore data with zero conversion.
	- Two display modes: "scientific" and "abbreviation" (word suffixes).
	  Abbreviation mode automatically falls back to scientific once the value
	  passes the last standardized word name (Centillion, 10^303) since there's
	  no common name for anything larger.

	Location: ReplicatedStorage/Modules/BigNumber.lua
	Usage:    local BigNumber = require(game:GetService("ReplicatedStorage").Modules.BigNumber)
]]

export type BigNum = {
	mantissa: number,
	exponent: number,
}

local BigNumber = {}

-- ============================================================
-- Internal helpers
-- ============================================================

-- Brings mantissa back into [1, 10) (or [-10, -1]) and adjusts exponent to match.
local function normalize(mantissa: number, exponent: number): BigNum
	if mantissa == 0 then
		return { mantissa = 0, exponent = 0 }
	end

	local sign = mantissa < 0 and -1 or 1
	local absM = math.abs(mantissa)

	-- Fast initial shift using log10, then correct any float rounding error.
	local shift = math.floor(math.log(absM, 10) + 1e-10)
	absM = absM / (10 ^ shift)
	exponent = exponent + shift

	while absM >= 10 do
		absM = absM / 10
		exponent = exponent + 1
	end
	while absM > 0 and absM < 1 do
		absM = absM * 10
		exponent = exponent - 1
	end

	return { mantissa = absM * sign, exponent = exponent }
end

-- ============================================================
-- Construction
-- ============================================================

function BigNumber.new(mantissa: number, exponent: number?): BigNum
	return normalize(mantissa, exponent or 0)
end

function BigNumber.Clone(a: BigNum): BigNum
	return { mantissa = a.mantissa, exponent = a.exponent }
end

function BigNumber.FromNumber(n: number): BigNum
	if n == 0 then
		return { mantissa = 0, exponent = 0 }
	end
	local sign = n < 0 and -1 or 1
	local absN = math.abs(n)
	local exponent = math.floor(math.log(absN, 10) + 1e-10)
	local mantissa = absN / (10 ^ exponent)
	return normalize(mantissa * sign, exponent)
end

-- Parses "1.5e15" style strings, or plain numeric strings like "1500".
function BigNumber.FromString(str: string): BigNum
	local mantissaStr, exponentStr = string.match(str, "^(-?%d+%.?%d*)[eE](%-?%d+)$")
	if mantissaStr and exponentStr then
		return normalize(tonumber(mantissaStr) :: number, tonumber(exponentStr) :: number)
	end

	local n = tonumber(str)
	if n then
		return BigNumber.FromNumber(n)
	end

	error("BigNumber.FromString: invalid format '" .. tostring(str) .. "'")
end

-- Converts back to a plain Lua number. Lossy/saturating for very large values —
-- use this for gameplay math well within double range, not for display.
function BigNumber.ToNumber(a: BigNum): number
	-- Guard before the multiply, not after: mantissa can be up to ~9.999,
	-- so exponent 308 can still overflow a double (max ~1.7976931348623157e308).
	if a.exponent >= 308 then
		return a.mantissa > 0 and math.huge or -math.huge
	end
	return a.mantissa * (10 ^ a.exponent)
end

-- ============================================================
-- Save / load (plain data already — these exist for clarity at call sites)
-- ============================================================

function BigNumber.Serialize(a: BigNum): { m: number, e: number }
	return { m = a.mantissa, e = a.exponent }
end

function BigNumber.Deserialize(data: { m: number?, e: number? }?): BigNum
	if not data then
		return { mantissa = 0, exponent = 0 }
	end
	return normalize(data.m or 0, data.e or 0)
end

-- ============================================================
-- Arithmetic
-- ============================================================

function BigNumber.Add(a: BigNum, b: BigNum): BigNum
	if a.mantissa == 0 then
		return BigNumber.Clone(b)
	end
	if b.mantissa == 0 then
		return BigNumber.Clone(a)
	end

	local diff = a.exponent - b.exponent

	-- Beyond ~17 orders of magnitude apart, the smaller number is negligible
	-- at double precision anyway — skip the wasted math.
	if diff > 17 then
		return BigNumber.Clone(a)
	elseif diff < -17 then
		return BigNumber.Clone(b)
	end

	if diff >= 0 then
		local combined = a.mantissa + (b.mantissa / (10 ^ diff))
		return normalize(combined, a.exponent)
	else
		local combined = b.mantissa + (a.mantissa / (10 ^ (-diff)))
		return normalize(combined, b.exponent)
	end
end

function BigNumber.Negate(a: BigNum): BigNum
	return { mantissa = -a.mantissa, exponent = a.exponent }
end

function BigNumber.Sub(a: BigNum, b: BigNum): BigNum
	return BigNumber.Add(a, BigNumber.Negate(b))
end

function BigNumber.Mul(a: BigNum, b: BigNum): BigNum
	if a.mantissa == 0 or b.mantissa == 0 then
		return { mantissa = 0, exponent = 0 }
	end
	return normalize(a.mantissa * b.mantissa, a.exponent + b.exponent)
end

function BigNumber.Div(a: BigNum, b: BigNum): BigNum
	if b.mantissa == 0 then
		error("BigNumber.Div: division by zero")
	end
	if a.mantissa == 0 then
		return { mantissa = 0, exponent = 0 }
	end
	return normalize(a.mantissa / b.mantissa, a.exponent - b.exponent)
end

-- Raises a BigNumber to a plain-number power (e.g. cost curves like base^level).
-- Works via log10 so fractional powers (sqrt, etc.) are handled correctly.
function BigNumber.Pow(a: BigNum, power: number): BigNum
	if a.mantissa <= 0 then
		if power == 0 then
			return BigNumber.new(1, 0)
		end
		error("BigNumber.Pow: base must be positive")
	end

	local log10Value = a.exponent + math.log(a.mantissa, 10)
	local newLog = log10Value * power
	local newExponent = math.floor(newLog)
	local newMantissa = 10 ^ (newLog - newExponent)
	return normalize(newMantissa, newExponent)
end

function BigNumber.Sqrt(a: BigNum): BigNum
	return BigNumber.Pow(a, 0.5)
end

-- Base-10 logarithm, returned as a plain number (useful for cost-curve math,
-- e.g. "how many levels can this currency afford").
-- Zero is a valid BigNumber state (see IsZero), so it returns -math.huge
-- instead of erroring — callers doing cost-curve math on a 0 balance would
-- otherwise crash instead of correctly affording nothing.
function BigNumber.Log10(a: BigNum): number
	if a.mantissa == 0 then
		return -math.huge
	end
	if a.mantissa < 0 then
		error("BigNumber.Log10: value must be positive")
	end
	return a.exponent + math.log(a.mantissa, 10)
end

function BigNumber.Abs(a: BigNum): BigNum
	return { mantissa = math.abs(a.mantissa), exponent = a.exponent }
end

function BigNumber.IsZero(a: BigNum): boolean
	return a.mantissa == 0
end

-- ============================================================
-- Comparison
-- ============================================================

-- Returns -1, 0, or 1. Sign is embedded in mantissa, so this handles
-- negative numbers correctly across differing exponents.
function BigNumber.Compare(a: BigNum, b: BigNum): number
	local signA = a.mantissa < 0 and -1 or (a.mantissa > 0 and 1 or 0)
	local signB = b.mantissa < 0 and -1 or (b.mantissa > 0 and 1 or 0)

	if signA ~= signB then
		return signA < signB and -1 or 1
	end
	if signA == 0 then
		return 0
	end

	if a.exponent ~= b.exponent then
		local result = (a.exponent < b.exponent) and -1 or 1
		return result * signA
	end

	if a.mantissa == b.mantissa then
		return 0
	end
	return (a.mantissa < b.mantissa) and -1 or 1
end

function BigNumber.LessThan(a: BigNum, b: BigNum): boolean
	return BigNumber.Compare(a, b) < 0
end

function BigNumber.LessThanOrEqual(a: BigNum, b: BigNum): boolean
	return BigNumber.Compare(a, b) <= 0
end

function BigNumber.GreaterThan(a: BigNum, b: BigNum): boolean
	return BigNumber.Compare(a, b) > 0
end

function BigNumber.GreaterThanOrEqual(a: BigNum, b: BigNum): boolean
	return BigNumber.Compare(a, b) >= 0
end

function BigNumber.Equals(a: BigNum, b: BigNum): boolean
	return BigNumber.Compare(a, b) == 0
end

function BigNumber.Min(a: BigNum, b: BigNum): BigNum
	return BigNumber.LessThanOrEqual(a, b) and BigNumber.Clone(a) or BigNumber.Clone(b)
end

function BigNumber.Max(a: BigNum, b: BigNum): BigNum
	return BigNumber.GreaterThanOrEqual(a, b) and BigNumber.Clone(a) or BigNumber.Clone(b)
end

-- ============================================================
-- Suffix table
-- ============================================================
--[[
	Every suffix lives in ONE ordered array, index = tier, built once when
	the module loads. Display and anything else that needs a suffix just
	computes a tier from the exponent and indexes straight into it — no
	string-building at runtime, no lookup logic scattered around.

	Tier n covers exponents [3n, 3n+2], e.g.:
		tier 1  -> K   (e3  to e5)   Thousand
		tier 2  -> M   (e6  to e8)   Million
		tier 3  -> B   (e9  to e11)  Billion
		tier 4  -> T   (e12 to e14)  Trillion
	(worth flagging since you weren't sure of the exact boundary — Billion
	is e9-e11, Trillion starts at e12, not e9-e12)

	Tiers 1-10 are the familiar base suffixes. From tier 11 (Decillion)
	onward there's no more full word — suffixes combine a "ones" prefix
	with a "tens" suffix (e.g. Undecillion -> "UDe", Duodecillion -> "DDe"),
	same convention used by Untitled Button Simulator and most incremental
	games. This block generates all of those combinations instead of
	hand-typing 90+ strings.

	Table caps out at tier 101 (Centillion, 10^303) — the last suffix with
	any real recognizability. Anything beyond that has no table entry, so
	Format() automatically falls back to scientific notation regardless of
	the player's setting.
]]

local SUFFIXES: { string } = {
	"K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No",
}

-- "Ones" digit prefix, reusing the base letters above where one already
-- exists (Qd/Qn/Sx/Sp/Oc/No) so e.g. "QnDe" reads consistently with "Qn".
local ONES_PREFIX = { "", "U", "D", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No" }
-- "Tens" suffix — each one is its own family of 10 (De -> UDe -> DDe -> ...).
local TENS_SUFFIX = { "", "De", "Vt", "Tg", "Qg", "Qq", "Sg", "St", "Og", "Ng" }
-- "Hundreds" suffix — only Ce (Centillion) is actually reached at the cap below.
local HUNDREDS_SUFFIX = { "", "Ce", "DCe", "TCe", "QdCe", "QnCe", "SxCe", "SpCe", "OcCe", "NoCe" }

local MAX_ILLION = 100 -- 100 = Centillion (10^303)

for illion = 10, MAX_ILLION do
	local h = math.floor(illion / 100)
	local remainder = illion % 100
	local t = math.floor(remainder / 10)
	local o = remainder % 10
	table.insert(SUFFIXES, ONES_PREFIX[o + 1] .. TENS_SUFFIX[t + 1] .. HUNDREDS_SUFFIX[h + 1])
end

-- Public, read-only reference — e.g. for a settings menu that previews suffixes.
BigNumber.Suffixes = table.freeze(SUFFIXES)

-- Returns the suffix for a given exponent, or nil if past the table
-- (caller should fall back to scientific). Also returns the tier's starting
-- exponent so the caller knows how much to scale the mantissa by.
function BigNumber.GetSuffix(exponent: number): (string?, number?)
	local tier = math.floor(exponent / 3)
	if tier < 1 or tier > #SUFFIXES then
		return nil, nil
	end
	return SUFFIXES[tier], tier * 3
end

-- ============================================================
-- Display formatting
-- ============================================================

local function formatSmallNumber(value: number): string
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return string.format("%.2f", value)
end

-- Main display function.
-- notationType: "scientific" or "abbreviation" — pass in whatever the
-- player's settings value currently is.
function BigNumber.Format(a: BigNum, notationType: string?): string
	local mode = notationType or "scientific"
	local sign = a.mantissa < 0 and "-" or ""
	local mantissa = math.abs(a.mantissa)
	local exponent = a.exponent

	-- Below 1000, just show the plain number regardless of mode.
	if exponent < 3 then
		local value = mantissa * (10 ^ exponent)
		return sign .. formatSmallNumber(value)
	end

	if mode == "abbreviation" then
		local suffix, tierExponent = BigNumber.GetSuffix(exponent)
		if suffix and tierExponent then
			local scaledMantissa = mantissa * (10 ^ (exponent - tierExponent))

			-- Guard against rounding up into the next tier at display time,
			-- e.g. 999.999K should read "1.00M", not "1000.00K".
			if scaledMantissa >= 999.995 then
				local nextSuffix, nextTierExponent = BigNumber.GetSuffix(exponent + 3)
				if nextSuffix and nextTierExponent then
					suffix = nextSuffix
					scaledMantissa = mantissa * (10 ^ (exponent - nextTierExponent))
				end
			end

			return sign .. string.format("%.2f%s", scaledMantissa, suffix)
		end
		-- Past Centillion (10^303) — table has no entry, fall back regardless
		-- of the player's chosen setting.
	end

	return sign .. string.format("%.2fe%d", mantissa, exponent)
end

return BigNumber