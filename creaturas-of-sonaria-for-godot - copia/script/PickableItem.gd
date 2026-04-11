extends Area3D
class_name PickableItem

@export var data: ItemData
@export var grupo: String = "planta"

func _ready() -> void:
	if data == null: return
	
	# Si es comestible, lo preparamos para que el InteractionManager lo reconozca
	if data.is_edible:
		add_to_group(grupo) 
		set_meta("current_capacity", data.nutrition_value)
		set_meta("max_capacity", data.nutrition_value)
