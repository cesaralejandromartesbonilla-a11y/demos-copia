extends Area3D
class_name PickableItem

@export var data: ItemData

func _ready() -> void:
	if data == null: return
	
	# Si es comestible, lo preparamos para que el InteractionManager lo reconozca
	if data.is_edible:
		add_to_group("planta") # O "carne" dependiendo del item
		set_meta("current_capacity", data.nutrition_value)
		set_meta("max_capacity", data.nutrition_value)
