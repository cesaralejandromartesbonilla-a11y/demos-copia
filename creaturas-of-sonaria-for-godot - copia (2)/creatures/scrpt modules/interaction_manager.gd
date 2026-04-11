extends Area3D
class_name InteractionManager

@onready var survival = get_parent().get_node("SurvivalManager")
@onready var controller = get_parent()

func try_interact_continuous(delta: float) -> void:
	if controller.current_creature_data == null: return
	
	var current_diet = controller.current_creature_data.diet
	var areas = get_overlapping_areas()
	var interacted = false
	
	for area in areas:
		# --- LÓGICA DE HERBÍVOROS ---
		if area.is_in_group("planta"):
			if current_diet == CreatureData.DietType.HERBIVORE or current_diet == CreatureData.DietType.OMNIVORE:
				_process_consumption(area, 20.0 * delta, "hunger", false, true) # true = se agota
				interacted = true
				
		# --- LÓGICA DE CARNÍVOROS ---
		elif area.is_in_group("carne") or area.is_in_group("podrido"):
			if current_diet == CreatureData.DietType.CARNIVORE or current_diet == CreatureData.DietType.OMNIVORE:
				var is_toxic = area.is_in_group("podrido")
				_process_consumption(area, 30.0 * delta, "hunger", is_toxic, true) # true = se agota
				interacted = true
				
		# --- LÓGICA DE AGUA ---
		elif area.is_in_group("agua"):
			_process_consumption(area, 25.0 * delta, "thirst", false, false) # false = infinito
			interacted = true
		elif area.is_in_group("agua_contaminada"):
			_process_consumption(area, 15.0 * delta, "thirst", true, false) # false = infinito
			interacted = true
			
		if interacted: 
			controller.velocity = Vector3.ZERO
			break

func _process_consumption(area: Area3D, requested_amount: float, stat_type: String, is_toxic: bool, is_depletable: bool):
	var amount_received = requested_amount
	
	# --- LÓGICA DE ENCOGIMIENTO Y DESGASTE ---
	if is_depletable:
		# Si es la primera vez que lo muerden, le creamos su "vida" (capacidad) usando metadatos
		if not area.has_meta("current_capacity"):
			area.set_meta("current_capacity", 100.0) # Cuánta comida tiene en total
			area.set_meta("max_capacity", 100.0)
		
		var current_cap = area.get_meta("current_capacity")
		if current_cap <= 0: return # Ya no le queda comida
		
		# Nos aseguramos de no comer más de lo que queda
		amount_received = min(requested_amount, current_cap)
		current_cap -= amount_received
		area.set_meta("current_capacity", current_cap) # Guardamos el nuevo valor
		
		# Encogemos el modelo visualmente (Escalamos el Area3D)
		var max_cap = area.get_meta("max_capacity")
		var scale_factor = max(0.1, current_cap / max_cap) # Usamos max(0.1) para que no se haga invisible antes de borrarse
		area.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		# Si se acabó, destruimos el nodo de la comida
		if current_cap <= 0:
			area.queue_free()
			
	# --- APLICAR ESTADÍSTICAS A LA CRIATURA ---
	if stat_type == "hunger":
		survival.current_hunger = clamp(survival.current_hunger + amount_received, 0, survival.max_hunger)
		if is_toxic: survival.take_damage(5.0 * get_process_delta_time()) 
		
	elif stat_type == "thirst":
		survival.current_thirst = clamp(survival.current_thirst + amount_received, 0, survival.max_thirst)
		if is_toxic: survival.take_damage(10.0 * get_process_delta_time())
