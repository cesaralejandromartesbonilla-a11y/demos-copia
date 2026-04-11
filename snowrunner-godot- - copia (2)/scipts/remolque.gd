extends VehicleBody3D

# En lugar de @onready, usamos una variable normal para comprobar si existe
var patas_visuales: Node3D = null

func _ready() -> void:
	# Intentamos buscar el nodo por si existe
	if has_node("PatasApoyo"):
		patas_visuales = get_node("PatasApoyo")
	else:
		print("AVISO: No se encontró el nodo 'PatasApoyo' en el remolque. Se omitirá la animación de patas.")

	# Frenar al inicio
	_frenar(true)

func set_conectado(conectado: bool) -> void:
	if conectado:
		print("Remolque conectado -> Frenos LIBERADOS")
		_frenar(false)
		if patas_visuales: patas_visuales.visible = false
	else:
		print("Remolque desconectado -> Frenos ACTIVADOS")
		_frenar(true)
		if patas_visuales: patas_visuales.visible = true

func _frenar(activo: bool) -> void:
	for w in get_children():
		if w is VehicleWheel3D:
			w.brake = 100.0 if activo else 0.0
			w.engine_force = 0.0
