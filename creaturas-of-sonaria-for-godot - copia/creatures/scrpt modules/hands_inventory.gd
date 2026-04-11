extends Node
class_name HandsInventory

signal inventory_changed(left_text: String, right_text: String)

@export var max_weight_capacity: float = 50.0
@export var left_hand_marker: Marker3D
@export var right_hand_marker: Marker3D

var item_in_left: PickableItem = null
var item_in_right: PickableItem = null

func _ready() -> void:
	_update_ui()

func try_pick_up(item: PickableItem) -> bool:
	var data = item.data
	if data == null: return false
	
	var current_weight = _get_current_weight()
	if current_weight + data.weight_kg > max_weight_capacity:
		print("Es muy pesado.")
		return false
	
	if data.slot_cost == 2:
		if item_in_left == null and item_in_right == null:
			_attach_to_hand(item, left_hand_marker, "both")
			return true
	else:
		if item_in_right == null:
			_attach_to_hand(item, right_hand_marker, "right")
			return true
		elif item_in_left == null:
			_attach_to_hand(item, left_hand_marker, "left")
			return true
			
	return false

func _attach_to_hand(item: PickableItem, marker: Marker3D, hand: String) -> void:
	item.get_parent().remove_child(item)
	marker.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	
	for child in item.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
			
	if hand == "right": item_in_right = item
	elif hand == "left": item_in_left = item
	elif hand == "both":
		item_in_left = item
		item_in_right = item
		
	_update_ui()

# --- NUEVO: FUNCIONES PARA SOLTAR ---
func drop_items() -> void:
	# Soltamos primero la derecha, luego la izquierda
	if item_in_right != null:
		_drop_specific_item(item_in_right)
	elif item_in_left != null:
		_drop_specific_item(item_in_left)

func _drop_specific_item(item: PickableItem) -> void:
	if item == null: return
	
	# Lo quitamos de la mano y lo devolvemos al mundo
	item.get_parent().remove_child(item)
	get_tree().current_scene.add_child(item)
	
	# Lo ponemos frente al jugador para que no caiga dentro de su cuerpo
	item.global_position = get_parent().global_position + (get_parent().global_basis.z * 1.5) + Vector3(0, 1, 0)
	
	# Reactivamos su colisión
	for child in item.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", false)
			
	# Limpiamos las variables
	if item_in_right == item: item_in_right = null
	if item_in_left == item: item_in_left = null
	
	_update_ui()
	print("Objeto soltado.")

# --- NUEVO: FUNCIONES PARA EL CULTIVO ---
func get_seed_in_hands() -> PickableItem:
	if item_in_right != null and item_in_right.data.is_seed: return item_in_right
	if item_in_left != null and item_in_left.data.is_seed: return item_in_left
	return null

func consume_item(item: PickableItem) -> void:
	if item_in_right == item: item_in_right = null
	if item_in_left == item: item_in_left = null
	item.queue_free() # Destruimos el objeto visual de la mano
	_update_ui()

func _get_current_weight() -> float:
	var total = 0.0
	if item_in_right and item_in_right.data: total += item_in_right.data.weight_kg
	if item_in_left and item_in_left != item_in_right and item_in_left.data: 
		total += item_in_left.data.weight_kg
	return total

func _update_ui() -> void:
	var left_txt = "Vacío"
	var right_txt = "Vacío"
	if item_in_left: left_txt = item_in_left.data.item_name
	if item_in_right: right_txt = item_in_right.data.item_name
	
	# Si es un objeto de dos manos, que diga lo mismo en ambas
	if item_in_left != null and item_in_left == item_in_right:
		left_txt = item_in_left.data.item_name + " (2 Manos)"
		right_txt = item_in_right.data.item_name + " (2 Manos)"
		
	inventory_changed.emit(left_txt, right_txt)
