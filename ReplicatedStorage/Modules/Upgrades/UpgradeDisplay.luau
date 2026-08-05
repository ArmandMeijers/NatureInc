--!strict
--[[
	UpgradeDisplay.luau

	Turns an upgrade + a level into the strings a board shows. Pure — no
	Instances, no signals — so how an upgrade READS lives in one place
	and any future surface (a shop preview, a quest reward blurb) says
	the same thing the board does.

	LEVEL TEXT is level+1 / MaxLevel+1. Levels are stored as "purchases
	made", which starts at 0, but a player reading "0/40" reasonably
	concludes the upgrade is broken. Both numbers shift so an unbought
	upgrade reads 1/40 and a maxed one reads 40/40 — the schema's
	MaxLevels are set one below a round number to suit.

	VALUE TEXT follows the entry's Display.Mode:
	    Flat        +10 -> +11         (Base shifts it to an absolute)
	    Multiplier  x10 -> x23
	    Seconds     3s -> 2.3s
	    Studs       5 studs -> 6 studs
	    Percent     15% -> 16%

	Seconds reads the boost value directly rather than adding it to a
	base, because SpeedInterval entries resolve TO an interval instead of
	contributing toward one.

	Location: ReplicatedStorage/Modules/Upgrades/UpgradeDisplay.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNumber = require(ReplicatedStorage.Modules.BigNumber)
local UpgradeSchema = require(ReplicatedStorage.Modules.Upgrades.UpgradeSchema)

local UpgradeDisplay = {}

UpgradeDisplay.LevelOffset = 1 -- set to 0 to show raw purchase counts

local function trim(value: number, decimals: number): string
	local text = string.format("%." .. decimals .. "f", value)
	if decimals > 0 then
		text = (text:gsub("%.?0+$", ""))
	end
	return text
end

-- Plain formatting up to a point, then BigNumber's. A multiplier at
-- level 49 of a compounding curve is only ~3000, but nothing stops a
-- schema entry from producing something enormous, and "1e21" beats
-- "1000000000000000000000".
local function formatNumber(value: number, decimals: number, notation: string?): string
	if math.abs(value) >= 1e6 then
		return BigNumber.Format(BigNumber.FromNumber(value), notation)
	end
	return trim(value, decimals)
end

function UpgradeDisplay.LevelText(upgradeId: string, level: number): string
	local entry = UpgradeSchema.Get(upgradeId)
	if not entry then
		return "-"
	end
	local offset = UpgradeDisplay.LevelOffset
	return `{level + offset}/{entry.MaxLevel + offset}`
end

function UpgradeDisplay.IsMaxed(upgradeId: string, level: number): boolean
	local entry = UpgradeSchema.Get(upgradeId)
	return entry ~= nil and level >= entry.MaxLevel
end

-- The value this upgrade shows AT that level, already formatted.
function UpgradeDisplay.ValueText(upgradeId: string, level: number, notation: string?): string
	local entry = UpgradeSchema.Get(upgradeId)
	if not entry then
		return "-"
	end

	local display = entry.Display or { Mode = "Flat" }
	local decimals = display.Decimals or 2
	local value = UpgradeSchema.GetBoostValue(upgradeId, level)

	if display.Mode == "Seconds" then
		return trim(value, decimals) .. "s"
	elseif display.Mode == "Studs" then
		return trim((display.Base or 0) + value, decimals) .. " studs"
	elseif display.Mode == "Percent" then
		return trim(value * 100, decimals) .. "%"
	elseif display.Mode == "Multiplier" then
		return "x" .. formatNumber(value, decimals, notation)
	end

	-- Flat. With a Base it's an absolute total; without one it's a delta,
	-- so it wears a + to say so.
	if display.Base then
		return formatNumber(display.Base + value, decimals, notation)
	end
	return "+" .. formatNumber(value, decimals, notation)
end

-- Current value and what it becomes after one more level. Next is nil at
-- max level, which the board renders as the current value alone.
function UpgradeDisplay.Transition(upgradeId: string, level: number, notation: string?): (string, string?)
	local current = UpgradeDisplay.ValueText(upgradeId, level, notation)
	if UpgradeDisplay.IsMaxed(upgradeId, level) then
		return current, nil
	end
	return current, UpgradeDisplay.ValueText(upgradeId, level + 1, notation)
end

-- Cost split into amount and currency, so the board can style them
-- separately: white number, gradient currency name.
function UpgradeDisplay.CostParts(upgradeId: string, level: number, notation: string?): (string?, string?)
	local entry = UpgradeSchema.Get(upgradeId)
	if not entry then
		return nil, nil
	end
	local cost = UpgradeSchema.GetCost(upgradeId, level)
	if not cost then
		return nil, nil -- maxed
	end
	return BigNumber.Format(cost, notation), entry.Currency
end

return UpgradeDisplay
