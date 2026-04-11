extends Area3D
class_name InteractionManager

@export_group("Habilidades de cultivo")
@export var enable_farming_override: bool = false # Actívalo en el inspector para saltarte la regla de evolución

@onready var survival = get_parent().get_node("SurvivalManager")
@onready var controller = get_parent()

# --- LÓGICA CONTINUA (Mantener pulsado para comer/beber) ---
func try_interact_continuous(delta: float) -> void:
	if controller.current_creature_data == null: return
	
	var current_diet = controller.current_creature_data.diet
	var areas = get_overlapping_areas()
	var interacted = false
	
	for area in areas:
		# --- LÓGICA DE HERBÍVOROS ---
		if area.is_in_group("planta"):
			if current_diet == CreatureData.DietType.HERBIVORE or current_diet == CreatureData.DietType.OMNIVORE:
				_process_consumption(area, 20.0 * delta, "hunger", false, true) 
				interacted = true
				
		# --- LÓGICA DE CARNÍVOROS ---
		elif area.is_in_group("carne") or area.is_in_group("podrido"):
			if current_diet == CreatureData.DietType.CARNIVORE or current_diet == CreatureData.DietType.OMNIVORE:
				var is_toxic = area.is_in_group("podrido")
				_process_consumption(area, 30.0 * delta, "hunger", is_toxic, true) 
				interacted = true
				
		# --- LÓGICA DE AGUA ---
		elif area.is_in_group("agua"):
			_process_consumption(area, 25.0 * delta, "thirst", false, false) 
			interacted = true
		elif area.is_in_group("agua_contaminada"):
			_process_consumption(area, 15.0 * delta, "thirst", true, false) 
			interacted = true
			
		if interacted: 
			controller.velocity = Vector3.ZERO
			break

# --- NUEVA LÓGICA DE ACCIÓN ÚNICA (Pulsar una vez para plantar/cosechar) ---
func try_interact_action() -> void:
	if controller.current_creature_data == null: return
	
	# 1. Verificar si tiene permiso para cultivar
	var can_farm = enable_farming_override
	
	# Usamos get() por seguridad, asumiendo que tu controller guarda la etapa actual en una variable "current_stage"
	if controller.get("current_stage") != null and "can_farm" in controller.get("current_stage"):
		if controller.get("current_stage").can_farm:
			can_farm = true
			
	var areas = get_overlapping_areas()
	for area in areas:
		if area.is_in_group("crop_plot"):
			if can_farm:
				if area.has_method("interact"):
					area.interact(controller)
					break # Solo plantamos/cosechamos una parcela a la vez
			else:
				print("Tu criatura actual no tiene la capacidad de cultivar.")

func _process_consumption(area: Area3D, requested_amount: float, stat_type: String, is_toxic: bool, is_depletable: bool):
	var amount_received = requested_amount
	
	# --- LÓGICA DE ENCOGIMIENTO Y DESGASTE ---
	if is_depletable:
		if not area.has_meta("current_capacity"):
			area.set_meta("current_capacity", 100.0) 
			area.set_meta("max_capacity", 100.0)
		
		var current_cap = area.get_meta("current_capacity")
		if current_cap <= 0: return 
		
		amount_received = min(requested_amount, current_cap)
		current_cap -= amount_received
		area.set_meta("current_capacity", current_cap) 
		
		var max_cap = area.get_meta("max_capacity")
		var scale_factor = max(0.1, current_cap / max_cap) 
		area.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		if current_cap <= 0:
			area.queue_free()
			
	# --- APLICAR ESTADÍSTICAS A LA CRIATURA ---
	if stat_type == "hunger":
		survival.current_hunger = clamp(survival.current_hunger + amount_received, 0, survival.max_hunger)
		if is_toxic: survival.take_damage(5.0 * get_process_delta_time()) 
		
	elif stat_type == "thirst":
		survival.current_thirst = clamp(survival.current_thirst + amount_received, 0, survival.max_thirst)
		if is_toxic: survival.take_damage(10.0 * get_process_delta_time())
