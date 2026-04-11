extends Area3D

@export var grow_time: float = 10.0 
@export var drop_item_data: ItemData 
@export var drop_amount: int = 3 

# NUEVO: Referencia al modelo 3D
@export var plot_mesh: MeshInstance3D 

enum State { EMPTY, GROWING, READY }
var current_state: State = State.EMPTY
var planted_seed_data: ItemData = null

@onready var timer = Timer.new()
var custom_material: StandardMaterial3D

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_crop_ready)
	
	# NUEVO: Creamos un material único para esta parcela y se lo aplicamos
	if plot_mesh:
		custom_material = StandardMaterial3D.new()
		plot_mesh.material_override = custom_material
		_update_visuals()

func interact(player: Node3D) -> void:
	match current_state:
		State.EMPTY:
			var hands = player.get_node_or_null("HandsInventory")
			if hands:
				var seed_item = hands.get_seed_in_hands()
				if seed_item:
					_plant_seed(seed_item, hands)
				else:
					print("Se requiere tener una semilla en las manos.")
			else:
				print("La criatura no tiene manos para plantar.")
				
		State.GROWING:
			print("Aún está creciendo... Faltan ", int(timer.time_left), " segundos.")
		State.READY:
			_harvest(player)

func _plant_seed(seed_node: PickableItem, hands: HandsInventory) -> void:
	planted_seed_data = seed_node.data
	current_state = State.GROWING
	timer.start(grow_time)
	print("Semilla de " + planted_seed_data.item_name + " plantada.")
	
	hands.consume_item(seed_node)
	_update_visuals() # Cambia a Verde

func _on_crop_ready() -> void:
	current_state = State.READY
	print("¡Cosecha lista!")
	_update_visuals() # Cambia a Amarillo

func _harvest(_player: Node3D) -> void:
	print("Cosechando...")
	
	for i in range(drop_amount):
		if drop_item_data and drop_item_data.model_scene:
			var drop = drop_item_data.model_scene.instantiate()
			drop.global_position = global_position + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))
			get_tree().current_scene.add_child(drop)
			
	current_state = State.EMPTY
	planted_seed_data = null
	print("Parcela vacía.")
	_update_visuals() # Vuelve a Marrón

# NUEVO: Función que controla los colores
func _update_visuals() -> void:
	if custom_material == null: return
	
	match current_state:
		State.EMPTY:
			custom_material.albedo_color = Color(0.4, 0.2, 0.1) # Marrón tierra
		State.GROWING:
			custom_material.albedo_color = Color(0.2, 0.8, 0.2) # Verde planta
		State.READY:
			custom_material.albedo_color = Color(0.9, 0.8, 0.1) # Amarillo trigo/cosecha
