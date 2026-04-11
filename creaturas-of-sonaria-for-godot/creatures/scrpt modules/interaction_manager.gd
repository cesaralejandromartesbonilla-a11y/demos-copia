extends Area3D
class_name InteractionManager

@export_group("Habilidades de cultivo")
@export var enable_farming_override: bool = false # Actívalo en el inspector para saltarte la regla de evolución

@onready var survival = get_parent().get_node("SurvivalManager")
@onready var hands = get_parent().get_node_or_null("HandsInventory")
@onready var controller = get_parent()

# --- LÓGICA CONTINUA (Mantener pulsado para comer/beber) ---
func try_interact_continuous(delta: float) -> void:
	if controller.current_creature_data == null: return
	var current_diet = controller.current_creature_data.diet
	
	# --- PRIORIDAD 1: COMER DE LAS MANOS ---
	if hands:
		var item_to_eat = null
		if hands.item_in_right and _is_edible(hands.item_in_right.data, current_diet):
			item_to_eat = hands.item_in_right
		elif hands.item_in_left and _is_edible(hands.item_in_left.data, current_diet):
			item_to_eat = hands.item_in_left
			
		if item_to_eat:
			_process_hand_consumption(item_to_eat, 40.0 * delta) # Comer de la mano es más rápido
			controller.velocity = Vector3.ZERO
			return # Bloqueamos otras interacciones si estamos comiendo de la mano
			
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

# --- NUEVA LÓGICA DE ACCIÓN ÚNICA (Pulsar una vez para plantar/cosechar/construir) ---
func try_interact_action() -> void:
	if controller.current_creature_data == null: return
	
	var areas = get_overlapping_areas()
	var bodies = get_overlapping_bodies()
	var recogio_algo = false
	
	# --- NUEVA PRIORIDAD 1: Recoger objetos del suelo primero ---
	for body in bodies:
		if "data" in body and body.data is ItemData:
			if hands and hands.try_pick_up(body):
				recogio_algo = true
				break # Rompemos el bucle porque ya recogimos uno

	# Si recogimos algo, cortamos la función aquí para no interactuar con la parcela sin querer
	if recogio_algo:
		return
	print("--- INTENTO DE INTERACTUAR ---")
	
	# 1. Prioridad: Construcción y Parcelas (Areas)
	for area in areas:
		if area.is_in_group("estructuras") or area.is_in_group("crop_plot"):
			if area.has_method("interact"):
				print("Interactuando con estructura: ", area.name)
				area.interact(controller)
				return 
				
	# 2. Prioridad: Recoger Manzanas y Semillas (RigidBodys)
	print("Cuerpos detectados: ", bodies.size())
	for body in bodies:
		print("- Detectado: ", body.name)
		
		# En lugar de "is PickableItem", verificamos si tiene la variable 'data' de ItemData
		if "data" in body and body.data is ItemData:
			print("¡Es un objeto recogible (Manzana/Semilla)! Intentando agarrar...")
			if hands and hands.try_pick_up(body):
				print("¡Objeto recogido con éxito!")
				return # Bloqueo: Si recogimos algo, salimos del click
			else:
				print("No hay espacio en las manos.")
		else:
			print("No es un objeto recogible.")
	
	# 1. Verificar si tiene permiso para cultivar (Usando el EvolutionManager correctamente)
	var can_farm = enable_farming_override
	var evo_manager = controller.get_node_or_null("EvolutionManager")
	if evo_manager:
		var stage = evo_manager._get_current_stage()
		if stage and stage.can_farm:
			can_farm = true
			
	for area in areas:
		
		# --- LÓGICA DE PARCELAS ---
		if area.is_in_group("crop_plot"):
			if can_farm:
				if area.has_method("interact"):
					area.interact(controller)
					break # Solo interactuamos con una cosa a la vez
			else:
				print("Tu criatura actual no tiene la capacidad de cultivar.")
				
		# --- LÓGICA DE CONSTRUCCIÓN (NUEVO) ---
		elif area.is_in_group("estructuras"):
			if area.has_method("interact"):
				# Llama a tu script de ConstructionSite pasándole el CharacterBody3D (controller)
				area.interact(controller)
				break 

	# --- LÓGICA DE RECOGER OBJETOS ---
	for area in areas:
		if area is PickableItem:
			if controller.get_node_or_null("HandsInventory"):
				if controller.get_node("HandsInventory").try_pick_up(area):
					break

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

func _is_edible(item_data: ItemData, diet: int) -> bool:
	if item_data == null or not item_data.is_edible: return false
	
	var is_plant = (item_data.food_type == "planta")
	var is_meat = (item_data.food_type == "carne")
	
	# Lógica de dieta
	if diet == CreatureData.DietType.OMNIVORE: return true
	if diet == CreatureData.DietType.HERBIVORE and is_plant: return true
	if diet == CreatureData.DietType.CARNIVORE and is_meat: return true
	
	return false

func _process_hand_consumption(item: PickableItem, amount: float):
	# Aplicamos el beneficio al Survival
	survival.current_hunger = clamp(survival.current_hunger + amount, 0, survival.max_hunger)
	
	# Desgastamos el ítem visualmente o por capacidad
	# Si el ítem se acaba, lo borramos de la mano
	if item.consume(amount): # Deberías crear esta función en PickableItem
		hands.consume_item(item)
