extends Node
class_name EvolutionManager

@onready var model_holder = $"../ModelHolder"
@onready var ability_manager = $"../AbilityManager"
@onready var effect_manager = $"../effect_manager"
@onready var level_manager = $"../LevelManager"

var current_stage_index: int = -1
var available_stages: Array[EvolutionStage] = []

func _ready():
	# Nos conectamos al sistema de niveles para revisar evoluciones cada vez que subimos
	if level_manager:
		level_manager.leveled_up.connect(check_evolutions)

func setup_stages(stages: Array[EvolutionStage], starting_level: int = 1):
	available_stages = stages
	# Forzamos la primera etapa (Bebé)
	if available_stages.size() > 0:
		evolve_to(0)
	sync_stage_to_level(starting_level)
	
func check_evolutions(current_level: int):
	# Revisamos si la siguiente etapa cumple los requisitos
	var next_index = current_stage_index + 1
	if next_index >= available_stages.size():
		return # Ya está en la etapa máxima
		
	var next_stage = available_stages[next_index]
	
	# Verificación de nivel
	if current_level >= next_stage.required_level:
		# Aquí podrías añadir comprobaciones para el "special_requirement_tag" (ej. "venerado")
		evolve_to(next_index)

func evolve_to(index: int):
	current_stage_index = index
	var new_stage = available_stages[index]
	
	print("Evolucionando a etapa: ", new_stage.stage_name)
	
	# 1. Cambiar el Modelo 3D y Animaciones
	for child in model_holder.get_children():
		child.queue_free() # Borramos el modelo viejo (ej. Bebé)
		
	if new_stage.model_scene:
		var new_model = new_stage.model_scene.instantiate()
		model_holder.add_child(new_model)
	
	# 2. Desbloquear Habilidades de esta etapa
	if ability_manager:
		for ability in new_stage.granted_abilities:
			if not ability in ability_manager.equipped_abilities:
				ability_manager.equipped_abilities.append(ability)
				print("Nueva habilidad desbloqueada!")
	
	# 3. Añadir Inmunidades de esta etapa (ej. El dragón adulto es inmune al fuego)
	if effect_manager:
		for immunity in new_stage.stage_immunities:
			if not immunity in effect_manager.immunities:
				effect_manager.immunities.append(immunity)
				
	# 4. Actualizar capacidades en el controlador (Volar/Nadar)
	var controller = get_parent()
	if "can_fly" in controller:
		controller.can_fly = new_stage.can_fly
	if "can_swim" in controller:
		controller.can_swim = new_stage.can_swim



func sync_stage_to_level(current_level: int) -> void:
	if available_stages.is_empty(): return
	
	var correct_stage_index = 0
	
	# Buscamos la etapa más alta que corresponda a nuestro nivel actual
	for i in range(available_stages.size()):
		if current_level >= available_stages[i].required_level:
			correct_stage_index = i
			
	# Forzamos la evolución a la etapa correcta (esto cargará el modelo y habilidades correctas)
	evolve_to(correct_stage_index)
	print("Evolución sincronizada al nivel: ", current_level, ". Etapa: ", available_stages[current_stage_index].stage_name)
