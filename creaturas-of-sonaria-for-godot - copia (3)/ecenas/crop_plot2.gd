extends Area3D

@export var grow_time: float = 10.0 
@export var drop_item_data: ItemData # Lo que va a soltar (ej. ManzanaData.tres)
@export var drop_amount: int = 3 # Cuántas manzanas suelta

enum State { EMPTY, GROWING, READY }
var current_state: State = State.EMPTY
var planted_seed: ItemData = null

@onready var timer = Timer.new()

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_crop_ready)

func interact(player: Node3D) -> void:
	match current_state:
		State.EMPTY:
			# Aquí luego conectaremos el inventario de las manos. 
			# Por ahora simulamos que el jugador tiene una semilla.
			print("Se requiere una semilla para plantar.")
			# _plant_seed(semilla_del_jugador) 
		State.GROWING:
			print("Aún está creciendo... Faltan ", int(timer.time_left), " segundos.")
		State.READY:
			_harvest(player)

func _plant_seed(seed_item: ItemData) -> void:
	if not seed_item.is_seed: 
		print("Esto no es una semilla.")
		return
		
	planted_seed = seed_item
	current_state = State.GROWING
	timer.start(grow_time)
	print("Semilla plantada. Esperando a que crezca...")

func _on_crop_ready() -> void:
	current_state = State.READY
	print("¡Cosecha lista!")

func _harvest(_player: Node3D) -> void:
	print("Cosechando...")
	
	# En lugar de dar monedas, instanciamos los objetos en el mundo
	for i in range(drop_amount):
		if drop_item_data and drop_item_data.model_scene:
			var drop = drop_item_data.model_scene.instantiate()
			# Los esparcimos un poco alrededor de la parcela
			drop.global_position = global_position + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))
			get_tree().current_scene.add_child(drop)
			
	current_state = State.EMPTY
	planted_seed = null
	print("Parcela vacía de nuevo.")
