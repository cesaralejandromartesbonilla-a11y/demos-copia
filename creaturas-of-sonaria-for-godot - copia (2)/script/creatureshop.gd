extends CanvasLayer

@export var data_creature_1: CreatureData
@export var data_creature_2: CreatureData

@onready var btn_1: Button = $CenterContainer/VBoxContainer2/BtnCreature1
@onready var btn_2: Button = $CenterContainer/VBoxContainer2/BtnCreature2
@onready var btn_back: Button = $CenterContainer/VBoxContainer2/BtnBack
@onready var coin_label: Label = $CenterContainer/VBoxContainer2/CoinLabel

func _ready() -> void:
	_disconnect_buttons()
	update_ui()

func update_ui() -> void:
	if coin_label:
		coin_label.text = "Monedas: " + str(InventoryManager.player_data.coins)
	
	setup_button(btn_1, data_creature_1)
	setup_button(btn_2, data_creature_2)
	
	if not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)

func setup_button(button: Button, data: CreatureData) -> void:
	if not data:
		button.text = "Ranura Vacía"
		button.disabled = true
		return

	button.disabled = false
	
	# Caso 1: No está desbloqueada (Tienda)
	if not InventoryManager.is_unlocked(data):
		button.text = "COMPRAR %s (%d coins)" % [data.creature_name, data.price]
		button.pressed.connect(_on_buy_pressed.bind(data))
		
	# Caso 2: Ya es tuya y tiene partida guardada (Continuar)
	elif InventoryManager.has_save_file(data):
		button.text = "CONTINUAR: " + data.creature_name
		button.pressed.connect(_on_play_pressed.bind(data, true))
		
	# Caso 3: Es tuya pero es nueva (Empezar de cero)
	else:
		button.text = "NUEVA PARTIDA: " + data.creature_name
		button.pressed.connect(_on_play_pressed.bind(data, false))

func _on_buy_pressed(data: CreatureData) -> void:
	if InventoryManager.buy_creature(data):
		print("¡Compra exitosa!")
		_disconnect_buttons()
		update_ui()
	else:
		print("Monedas insuficientes.")

func _on_play_pressed(data: CreatureData, is_continue: bool) -> void:
	if is_continue:
		InventoryManager.load_creature_save(data)
	else:
		InventoryManager.set_selected_creature(data)
	
	get_tree().change_scene_to_file("res://ecenas/world.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ecenas/main_menu.tscn")

func _disconnect_buttons() -> void:
	# Función auxiliar para limpiar señales y evitar que se acumulen
	for b in [btn_1, btn_2]:
		for sig in b.pressed.get_connections():
			b.pressed.disconnect(sig.callable)
