class_name InventoryState
extends RefCounted

signal changed(item_id: String, amount: int)

var items: Dictionary = {}

func add_item(item_id: String, amount := 1) -> void:
	items[item_id] = int(items.get(item_id, 0)) + maxi(amount, 0)
	changed.emit(item_id, count(item_id))

func remove_item(item_id: String, amount := 1) -> bool:
	var current := int(items.get(item_id, 0))
	if amount < 0 or current < amount:
		return false
	var remaining := current - amount
	if remaining == 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining
	changed.emit(item_id, remaining)
	return true

func has_item(item_id: String, amount := 1) -> bool:
	return int(items.get(item_id, 0)) >= amount

func count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func snapshot() -> Dictionary:
	return items.duplicate(true)

func restore(snapshot_data: Dictionary) -> void:
	items = snapshot_data.duplicate(true)
	for item_id in items.keys():
		changed.emit(str(item_id), count(str(item_id)))

func clear() -> void:
	var previous_items := items.duplicate(true)
	items.clear()
	for item_id in previous_items.keys():
		changed.emit(str(item_id), 0)
