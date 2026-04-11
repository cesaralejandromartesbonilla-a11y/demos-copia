extends Node

const WORLD_SAVE_PATH = "user://saves/world_data.json"

# --- CONFIGURACIÓN DEL AUTOGUARDADO (SISTEMA MIXTO) ---
var auto_save_enabled: bool = false # Empieza apagado para que tú tengas el control inicial
var auto_save_interval: float = 300.0 # 300 segundos = 5 minutos
var _timer: Timer

func _ready() -> void:
	# Creamos el temporizador invisible para el autoguardado
	_timer = Timer.new()
	_timer.wait_time = auto_save_interval
	_timer.autostart = false
	_timer.timeout.connect(save_world)
	add_child(_timer)

func toggle_autosave(enabled: bool) -> void:
	auto_save_enabled = enabled
	if auto_save_enabled:
		_timer.start()
		print("Autoguardado Activado cada ", auto_save_interval, " segundos.")
	else:
		_timer.stop()
		print("Autoguardado Desactivado.")

# --- GUARDADO MANUAL / AUTOMÁTICO ---
func save_world() -> void:
	print("Guardando el estado del mundo...")
	var save_nodes = get_tree().get_nodes_in_group("persist")
	var world_data = []
	
	for node in save_nodes:
		# Comprobamos el contrato: ¿Este nodo tiene la función de guardar?
		if node.has_method("save_data"):
			world_data.append(node.save_data())
	
	# Abrimos el archivo y escribimos el diccionario completo en formato JSON
	var file = FileAccess.open(WORLD_SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(world_data, "\t") # El "\t" lo hace legible para humanos
		file.store_string(json_string)
		file.close()
		print("¡Mundo guardado exitosamente con ", world_data.size(), " objetos!")
	else:
		printerr("Error fatal: No se pudo abrir el archivo para guardar el mundo.")

# --- CARGA DEL MUNDO ---
func load_world() -> void:
	if not FileAccess.file_exists(WORLD_SAVE_PATH):
		print("No hay partida guardada del mundo anterior. Empezando de cero.")
		return
		
	print("Cargando el mundo...")
	var file = FileAccess.open(WORLD_SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		printerr("Error al leer el archivo JSON de guardado.")
		return
		
	var world_data = json.data
	
	# 1. LIMPIEZA: Destruimos los objetos para no duplicarlos (EXCEPTO LOS PRINCIPALES)
	var current_nodes = get_tree().get_nodes_in_group("persist")
	for node in current_nodes:
		# Pon aquí el nombre exacto de los nodos que NO quieres que se destruyan
		if node.name == "CharacterBody3D":
			print("Salvando a ", node.name, " de la limpieza.")
			continue # Salta a la siguiente iteración, no lo borra
			
		print("LIMPIEZA: Borrando ", node.name)
		node.queue_free()
		
	# Esperamos un micro-instante para que Godot termine de borrarlos de la memoria
	await get_tree().process_frame
	print("empezando con la RECONSTRUCCIÓN")
# 2. RECONSTRUCCIÓN: Leemos la lista y creamos los objetos de nuevo
	for node_data in world_data:
		var new_object_scene = load(node_data["filename"]) as PackedScene
		if new_object_scene:
			# 1. INSTANCIAR (El objeto existe en la memoria, pero aún no en el mundo)
			var new_object = new_object_scene.instantiate()
			
			# 2. ASIGNAR DATOS EN EL LIMBO
			if node_data.has("data_path") and node_data["data_path"] != "":
				new_object.data = load(node_data["data_path"])
			
			if node_data.has("current_capacity"):
				new_object.set_meta("current_capacity", node_data["current_capacity"])
				
			# 3. APLICAR TU IDEA: CONGELAR ANTES DE NACER
			var is_rigidbody = new_object is RigidBody3D
			if is_rigidbody:
				new_object.freeze = true 
				
			# 4. NACIMIENTO SECRETO (Ahora lo metemos al mundo, pero entra totalmente dormido)
			var parent_node = get_node_or_null(node_data["parent"])
			if parent_node:
				parent_node.add_child(new_object)
			else:
				get_tree().current_scene.add_child(new_object)
				
			# 5. MOVER A SU SITIO (Como está congelado, moverlo no dispara cálculos de colisión)
			# Nota: Godot exige que el objeto ya tenga padre (add_child) para poder usar 'global_position'
			new_object.global_position = Vector3(node_data["pos_x"], node_data["pos_y"], node_data["pos_z"])
			new_object.global_rotation = Vector3(node_data["rot_x"], node_data["rot_y"], node_data["rot_z"])

	print("¡Mundo cargado correctamente sin explotar las físicas!")
