extends Area3D

@export var grow_time: float = 10.0 
@export var drop_amount: int = 3 
@export var plot_mesh: MeshInstance3D 
@export var health: float = 100.0
@export var item_base_scene: PackedScene

enum State { EMPTY, GROWING, READY, DIRTY }
var current_state: State = State.EMPTY
var planted_seed_data: ItemData = null

var is_submerged: bool = false
var current_compost: float = 0.0 # Memoria de cuánto ha comido el hongo

@onready var timer = Timer.new()
var custom_material: StandardMaterial3D

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_crop_ready)
	
	if plot_mesh:
		custom_material = StandardMaterial3D.new()
		plot_mesh.material_override = custom_material
		_update_visuals()
		
	# Verificación de Agua
	await get_tree().process_frame
	for area in get_overlapping_areas():
		if area.is_in_group("water"):
			is_submerged = true
			break

func interact(player: Node3D) -> void:
	var hands = player.get_node_or_null("HandsInventory")
	
	match current_state:
		State.EMPTY:
			if hands:
				var seed_item = hands.get_seed_in_hands()
				if seed_item:
					_plant_seed(seed_item, hands)
				else:
					print("Se requiere tener una semilla en las manos.")
			else:
				print("La criatura no tiene manos para plantar.")
				
		State.GROWING:
			# Si es un hongo, intentamos alimentarlo en lugar de esperar
			if planted_seed_data and planted_seed_data.crop_type == ItemData.CropType.FUNGUS:
				_try_feed_fungus(hands)
			else:
				print("Aún está creciendo... Faltan ", int(timer.time_left), " segundos.")
				
		State.READY:
			_harvest(player)
			
		State.DIRTY:
			print("Limpiando parcela...")
			current_state = State.EMPTY
			_update_visuals()

# Lógica exclusiva de los hongos
func _try_feed_fungus(hands: HandsInventory) -> void:
	if hands == null: return
	
	# Buscar algo orgánico en las manos (asumimos que si tiene nutrition_value > 0 es orgánico)
	var food_to_feed: PickableItem = null
	if hands.item_in_right and hands.item_in_right.data.nutrition_value > 0:
		food_to_feed = hands.item_in_right
	elif hands.item_in_left and hands.item_in_left.data.nutrition_value > 0:
		food_to_feed = hands.item_in_left
		
	if food_to_feed:
		var nutrition = food_to_feed.data.nutrition_value
		hands.consume_item(food_to_feed)
		current_compost += nutrition
		print("Hongo alimentado con ", nutrition, " de materia orgánica. Progreso: ", current_compost, "/", planted_seed_data.compost_needed)
		
		# Si comió suficiente, crece inmediatamente
		if current_compost >= planted_seed_data.compost_needed:
			_on_crop_ready()
	else:
		print("El hongo necesita materia orgánica (comida, carne podrida, etc.) para crecer. Progreso: ", current_compost, "/", planted_seed_data.compost_needed)

func _plant_seed(seed_node: PickableItem, hands: HandsInventory) -> void:
	planted_seed_data = seed_node.data
	hands.consume_item(seed_node)
	current_compost = 0.0 # Reiniciamos el "estómago" del hongo
	
	if planted_seed_data.requires_submerged and not is_submerged:
		print("Semilla plantada, pero necesita estar bajo el agua para crecer.")
		current_state = State.GROWING
		_update_visuals()
		return 
		
	current_state = State.GROWING
	
	# Si NO es hongo, usa el temporizador normal
	if planted_seed_data.crop_type != ItemData.CropType.FUNGUS:
		timer.start(grow_time)
		
	print("Semilla de " + planted_seed_data.item_name + " plantada.")
	_update_visuals()

func _on_crop_ready() -> void:
	current_state = State.READY
	print("¡Cosecha lista!")
	_update_visuals()

func _harvest(_player: Node3D) -> void:
	print("Cosechando...")
	
	if planted_seed_data and planted_seed_data.result_item_data:
		# Comprobamos que no se nos haya olvidado poner la escena base en el inspector
		if item_base_scene: 
			for i in range(drop_amount):
				var drop = item_base_scene.instantiate()
				
				# ¡LA MAGIA OCURRE AQUÍ! Le inyectamos los datos al objeto recién nacido
				drop.data = planted_seed_data.result_item_data 
				
				get_tree().current_scene.add_child(drop)
				drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5))
		else:
			printerr("ERROR: Olvidaste arrastrar la escena 'item_base.tscn' al inspector de la Parcela.")
	
	# El hongo y los árboles frutales son ambos permanentes
	if planted_seed_data.crop_type == ItemData.CropType.PERMANENT or planted_seed_data.crop_type == ItemData.CropType.FUNGUS:
		current_state = State.GROWING
		current_compost = 0.0 # Se vacía para la siguiente cosecha de hongos
		
		if planted_seed_data.requires_submerged and not is_submerged:
			print("El cultivo permanente necesita agua para dar otra cosecha.")
		elif planted_seed_data.crop_type != ItemData.CropType.FUNGUS:
			timer.start(grow_time) # Los árboles reinician su tiempo
			print("Cosechado. Volverá a dar frutos pronto.")
		else:
			print("Cosechado. El hongo vuelve a estar hambriento.")
	else:
		current_state = State.DIRTY
		planted_seed_data = null
		print("Parcela sucia. Usa interactuar ('F') para limpiarla.")
		
	_update_visuals()

func _update_visuals() -> void:
	if custom_material == null: return
	
	match current_state:
		State.EMPTY:
			custom_material.albedo_color = Color(0.4, 0.2, 0.1) 
		State.GROWING:
			if planted_seed_data and planted_seed_data.requires_submerged and not is_submerged:
				custom_material.albedo_color = Color(0.3, 0.3, 0.3) 
			elif planted_seed_data and planted_seed_data.crop_type == ItemData.CropType.FUNGUS:
				custom_material.albedo_color = Color(0.5, 0.2, 0.5) # Le damos un color Morado para distinguirlo visualmente
			else:
				custom_material.albedo_color = Color(0.2, 0.8, 0.2) 
		State.READY:
			custom_material.albedo_color = Color(0.9, 0.8, 0.1) 
		State.DIRTY:
			custom_material.albedo_color = Color(0.15, 0.1, 0.05)

func disassemble_with_tool() -> void:
	print("Desarmando parcela...")
	# Aquí puedes poner código para soltar semillas o tierra si quieres
	queue_free()

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		disassemble_with_tool()

# --- PREPARACIÓN PARA GUARDADO ---
func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : str(get_parent().get_path()) if get_parent() else "",
		"pos_x" : global_position.x,
		"pos_y" : global_position.y,
		"pos_z" : global_position.z,
		"rot_x" : global_rotation.x,
		"rot_y" : global_rotation.y,
		"rot_z" : global_rotation.z,
		
		# Variables exclusivas de la parcela
		"current_state" : current_state,
		"current_compost" : current_compost,
		"health" : health,
		"timer_left" : timer.time_left if timer != null and timer.time_left > 0 else 0.0,
		"planted_seed_path" : ""
	}
	
	# Si hay algo plantado, guardamos la ruta del recurso de la semilla
	if planted_seed_data != null:
		save_dict["planted_seed_path"] = planted_seed_data.resource_path
		
	return save_dict
