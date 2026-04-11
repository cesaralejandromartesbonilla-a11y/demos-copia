extends Area3D

@export var velocidad_carga: float = 25.0 
var camioneta_en_zona = null
var hud_sistema = null # Referencia en caché para no buscarla a cada frame

func _ready():
	set_process(false)
	# Conectamos las señales desde código o desde el editor, aquí lo hago por código para asegurar
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Buscamos el HUD una sola vez al inicio
	hud_sistema = get_tree().get_first_node_in_group("hud")

func _on_body_entered(body):
	# Verificamos si es el vehículo (puedes usar grupos o chequear la clase)
	if body.is_in_group("jugador") or body.has_method("repostar"):
		camioneta_en_zona = body
		set_process(true)

func _on_body_exited(body):
	if body == camioneta_en_zona:
		if hud_sistema: hud_sistema.mostrar_mensaje("")
		camioneta_en_zona = null
		set_process(false)

func _process(delta):
	if not is_instance_valid(camioneta_en_zona):
		set_process(false)
		return

	# Lógica de repostaje
	if camioneta_en_zona.motor_encendido:
		if hud_sistema: 
			hud_sistema.mostrar_mensaje("¡APAGA EL MOTOR (E) PARA REPOSTAR!")
	else:
		if camioneta_en_zona.combustible_actual < camioneta_en_zona.combustible_max:
			camioneta_en_zona.repostar(velocidad_carga * delta)
			if hud_sistema: 
				var litros = int(camioneta_en_zona.combustible_actual)
				hud_sistema.mostrar_mensaje("REPOSTANDO... %d L" % litros)
		else:
			if hud_sistema: hud_sistema.mostrar_mensaje("TANQUE LLENO")
