--!strict
--[[
	RuneConfig.luau

	Tuning constants for the rune loop. Per-rune numbers live in
	Schema/<RuneId>; this is the machinery around them.

	Location: ReplicatedStorage/Modules/Runes/RuneConfig.luau
]]

local RuneConfig = {}

-- Base stats before any upgrade or rune boost. Bulk 1 and Speed 1 means
-- one roll per second producing one rune: 1 RPS, as intended.
RuneConfig.BaseBulk = 1
RuneConfig.BaseSpeed = 1  -- rolls per second
RuneConfig.BaseLuck = 1

-- ============================================================
-- THE 0.1s FLOOR
--
-- Speed is rolls per second, so the interval between rolls is 1/Speed.
-- Past Speed 10 that interval drops under 0.1s, and running a timer at
-- 1000Hz to "roll" 1000 times a second is pure waste — the player can't
-- perceive it and the server certainly can't afford it per player.
--
-- So the loop ticks at a FIXED 0.1s and rolls however many rolls that
-- 0.1s earned: Speed 10 is one roll per tick, Speed 1e12 is 1e11 rolls
-- per tick. Speed keeps mattering forever because it multiplies the
-- batch size rather than the tick rate. Below Speed 10 the fractional
-- carry accumulates until it's worth a whole roll, so slow speeds are
-- exact too rather than rounding to zero every tick.
-- ============================================================
RuneConfig.TickInterval = 0.1

-- Below this many total runes, roll them individually with math.random
-- so early game is genuinely random. Above it, RuneMath uses expected
-- counts — see the note there. 500 is comfortably below the point where
-- looping costs a frame.
RuneConfig.ExactRollLimit = 500

-- A rune type whose chance falls below this is treated as unobtainable
-- and its share redistributed. This is what makes commons disappear at
-- extreme luck: they aren't removed by a rule, they're squeezed out by
-- normalisation until they cross this line.
RuneConfig.UnobtainableChance = 1e-15

-- How long a gain label lingers in the corner after it stops increasing.
RuneConfig.GainFadeSeconds = 5
RuneConfig.GainFadeTime = 0.6

-- How close the player must be for a rune's panels to appear.
RuneConfig.PanelDistance = 40

return RuneConfig
