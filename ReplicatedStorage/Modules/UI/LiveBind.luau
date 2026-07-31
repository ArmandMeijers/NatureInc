--!strict
--[[
	LiveBind.luau

	Generic reactive glue: point it at an Instance property, a getter
	function, and one or more Signals, and it keeps that property up to
	date -- setting it immediately, then again every time any of those
	signals fire. Any script can reuse this instead of hand-rolling its
	own refresh() + a pile of :Connect(refresh) calls whenever a value
	depends on more than one thing changing (e.g. a cost label that needs
	to update on BOTH a currency change AND a settings change like
	NumberNotation).

	Example:
		LiveBind.Bind(costLabel, "Text", function()
			return BigNumber.Format(cost, SettingsState.Get("General.NumberNotation"))
		end, { TreeTierState.BalanceChanged.Event, SettingsState.Changed })

	Call :Disconnect() on the returned handle when the UI that owns the
	bound Instance is destroyed (e.g. a board unmounting), so this stops
	holding onto it and doesn't keep recomputing for nothing.

	Location: ReplicatedStorage/Modules/UI/LiveBind.luau
]]

local LiveBind = {}

export type Connection = { Disconnect: (self: Connection) -> () }

type AnySignal = { Connect: (self: any, fn: (...any) -> ()) -> any }

local function makeHandle(connections: { any }): Connection
	local handle = {}
	function handle.Disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	return (handle :: any) :: Connection
end

-- Binds instance[property] to getter(), refreshed immediately and again
-- every time any signal in `signals` fires.
function LiveBind.Bind(instance: Instance, property: string, getter: () -> any, signals: { AnySignal }): Connection
	local connections = {}

	local function update()
		(instance :: any)[property] = getter()
	end

	update()

	for _, signal in signals do
		table.insert(connections, signal:Connect(update))
	end

	return makeHandle(connections)
end

-- Same idea but for values that aren't a direct Instance property -- e.g.
-- driving several things off one recompute, or feeding a value into some
-- other system. Calls onUpdate(value) immediately and again on every
-- signal fire.
function LiveBind.Watch(getter: () -> any, signals: { AnySignal }, onUpdate: (any) -> ()): Connection
	local connections = {}

	local function update()
		onUpdate(getter())
	end

	update()

	for _, signal in signals do
		table.insert(connections, signal:Connect(update))
	end

	return makeHandle(connections)
end

return LiveBind

