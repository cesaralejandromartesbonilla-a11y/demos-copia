extends Control

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var hunger_bar: ProgressBar = $VBoxContainer/HungerBar
@onready var thirst_bar: ProgressBar = $VBoxContainer/ThirstBar
@onready var energy_bar: ProgressBar = $VBoxContainer/EnergyBar
@onready var growth_bar: ProgressBar = $VBoxContainer/GrowthBar
@onready var slot1 = $VBoxContainer/AbilitySlot
@onready var slot2 = $VBoxContainer/AbilitySlot2
@onready var slot3 = $VBoxContainer/AbilitySlot3

func _ready() -> void:
	# Esperamos un frame para darle tiempo al World de hacer add_child(creature)
	await get_tree().process_frame
	
	# Buscamos a la criatura en la escena (asegúrate de que esté en el grupo "player")
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var survival = player.get_node_or_null("SurvivalManager")
		if survival:
			# Conectamos la señal unificada del SurvivalManager
			survival.stats_changed.connect(_on_stats_changed)
			
			# Ajustamos los valores máximos basándonos en el SurvivalManager
			health_bar.max_value = survival.max_health
			hunger_bar.max_value = survival.max_hunger
			thirst_bar.max_value = survival.max_thirst
			energy_bar.max_value = survival.max_energy
			growth_bar.max_value = 100.0 # Porcentaje
			
			# Refrescamos la UI de inmediato para que no empiece vacía
			_on_stats_changed(survival.current_health, survival.current_hunger, survival.current_thirst, survival.current_energy, survival.growth_percent, "")
		else:
			print("HUD Error: La criatura no tiene un nodo SurvivalManager.")
	else:
		print("HUD Error: No se encontró ninguna criatura en el grupo 'player'.")
	await get_tree().process_frame
	if player:
		var am = player.get_node("AbilityManager")
		slot1.setup(0, am)
		slot2.setup(1, am)
		slot3.setup(2, am)

# Esta función recibe exactamente los parámetros que envía la señal stats_changed
func _on_stats_changed(health: float, hunger: float, thirst: float, energy: float, growth: float, _time: String) -> void:
	health_bar.value = health
	hunger_bar.value = hunger
	thirst_bar.value = thirst
	energy_bar.value = energy
	growth_bar.value = growth * 100
