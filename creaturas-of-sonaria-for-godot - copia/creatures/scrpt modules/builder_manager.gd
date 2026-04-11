extends Node
class_name BuilderManager

@export var crop_plot_scene: PackedScene # Aquí arrastras tu crop_plot.tscn
@onready var ground_detector: RayCast3D = $"../GroundDetector" # Referencia al RayCast

func try_build_plot() -> void:
	if not ground_detector.is_colliding():
		print("No estás apuntando al suelo.")
		return
		
	var collider = ground_detector.get_collider()
	
	# Verificamos si el suelo que tocamos tiene el grupo correcto
	if collider.is_in_group("cosechable"):
		# Obtenemos el punto exacto del mapa donde el láser chocó con el suelo
		var hit_point = ground_detector.get_collision_point()
		
		# Instanciamos la parcela
		var new_plot = crop_plot_scene.instantiate()
		get_tree().current_scene.add_child(new_plot)
		
		# Colocamos la parcela en ese punto
		new_plot.global_position = hit_point
		
		print("¡Tierra arada! Nueva parcela creada.")
	else:
		print("No puedes cultivar en este tipo de superficie.")
