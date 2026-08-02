--!strict
--[[
	CurrencyOrder.luau

	The declared order currencies should ever be displayed in, anywhere:
	Leafs, Compost, Nuts, then whatever gets added next.

	This can't just BE Template.Currency's own key order for two reasons:
	1. Template.luau lives in ServerScriptService, which client scripts
	   can never require() -- it doesn't replicate there at all.
	2. Even on the server, Lua/Luau table iteration order for string keys
	   isn't part of the language guarantee, so reading Template.Currency
	   with a `for key in` loop and hoping it comes out Leafs, Compost,
	   Nuts isn't something to build UI ordering on.

	So this is the one explicit, ordered list every currency-order-aware
	system reads from -- the tree tier board's boost rows, the stats
	menu, anything added later. When you add a new currency to
	Template.Currency, add its name here too, in whatever position you
	want it displayed. Nothing else needs to change.

	Location: ReplicatedStorage/Modules/CurrencyOrder.luau
]]

local CurrencyOrder: { string } = {
	"Leafs",
	"Compost",
	"Nuts",
}

return CurrencyOrder