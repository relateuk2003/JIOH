# scripts/data/trade_roster.gd — JIOH-21: the ten trades in authored order.
# Iteration order is this array's order, never the filesystem's.
class_name TradeRoster
extends Resource

const PATH := "res://resources/trades/roster.tres"

@export var trades: Array[TradespersonData] = []


static func shipped() -> TradeRoster:
	return load(PATH) as TradeRoster


func get_trade(trade_id: StringName) -> TradespersonData:
	for t in trades:
		if t.trade_id == trade_id:
			return t
	return null


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in trades:
		out.append(t.trade_id)
	return out
