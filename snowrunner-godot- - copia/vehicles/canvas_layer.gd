extends CanvasLayer

@onready var consola = $Consola
@onready var vel_label = $PanelInstrumentos/Velocimetro
@onready var fuel_bar = $PanelInstrumentos/CombustibleBar
@onready var traccion_label = $PanelInstrumentos/Indicador4x4

var timer_mensaje: SceneTreeTimer = null

func _ready():
	# Inicializar valores
	consola.text = "SISTEMAS LISTOS"
	_limpiar_consola_despues(3.0)

# Función que ya usaba la gasolinera
func mostrar_mensaje(texto: String):
	consola.text = texto
	_limpiar_consola_despues(4.0)

func _limpiar_consola_despues(segundos: float):
	if timer_mensaje: return # Evitar múltiples timers
	await get_tree().create_timer(segundos).timeout
	consola.text = ""

# --- NUEVAS FUNCIONES DE ACTUALIZACIÓN ---

func actualizar_velocidad(valor: float):
	# valor viene en metros/segundo habitualmente
	var kmh = abs(valor * 3.6)
	vel_label.text = "%d KM/H" % kmh

func actualizar_combustible(actual: float, maximo: float):
	fuel_bar.max_value = maximo
	fuel_bar.value = actual

func actualizar_traccion(es_4x4: bool, dif_bloqueado: bool):
	var texto = "[ 4x4 ]" if es_4x4 else "[ 2x4 ]"
	if dif_bloqueado:
		texto += " [ DIF. LOCK ]"
	traccion_label.text = texto
