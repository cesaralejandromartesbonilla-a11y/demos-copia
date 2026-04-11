extends VehicleBody3D


# --- SEÑALES PARA LA UI ---
signal datos_actualizados(combustible: float, velocidad: float, rpm: float)
signal traccion_cambiada(es_4x4: bool)
signal motor_estado_cambiado(encendido: bool)
signal dif_cambiado(bloqueado: bool)

# --- CONFIGURACIÓN DESDE EL INSPECTOR ---
@export_group("Motor y Transmisión")
@export var max_torque: float = 800.0
@export var max_rpm: float = 3000.0
@export var consumo_base: float = 0.5
@export var curvas_torque: Curve
@export var steering_max: float = 0.6
@export var steering_speed: float = 2.5

@export_group("Combustible")
@export var combustible_max: float = 100.0

@export_group("Remolque")
@export var nodo_quinta_rueda: Marker3D

@export_group("suspencion")
@onready var rueda_fisica_di = $VehicleWheel3D2
@onready var raycast_di = $SENSORES_RAYCAST/RayCast_DI

# Contenedor que sube y baja (La Suspensión)
@onready var contenedor_suspension = $SUSPENSION_VISUAL/Eje_Delantero_Contenedor
# Ballesta que se aplasta (Hija del contenedor)
@onready var malla_ballesta = $SUSPENSION_VISUAL/Eje_Delantero_Contenedor/Eje_Metal_Malla
# Pivote que gira a los lados (Hijo del contenedor)
@onready var pivote_direccion = $SUSPENSION_VISUAL/Eje_Delantero_Contenedor/Pivote_Direccion_DI
# Llanta que rueda (Hija del pivote)
@onready var malla_llanta = $SUSPENSION_VISUAL/Eje_Delantero_Contenedor/Pivote_Direccion_DI/Llanta_Visual_DI

# --- REFERENCIAS TRASERAS ---
@onready var rueda_fisica_ti = $Trasera
@onready var rueda_fisica_td = $Trasera2
@onready var ray_ti = $SENSORES_RAYCAST/RayCast_TI
@onready var ray_td = $SENSORES_RAYCAST/RayCast_TD
@onready var contenedor_eje = $EJE_RIGIDO_TRASERO
@onready var malla_llanta_ti = $EJE_RIGIDO_TRASERO/Pivote_L/Malla_Llanta_TI
@onready var malla_llanta_td = $EJE_RIGIDO_TRASERO/Pivote_R/Malla_Llanta_TD
@export var ancho_eje: float = 2.0

# --- 2. VARIABLES DE CONFIGURACIÓN ---
@export var radio_rueda: float = 0.5
@export var extension_maxima: float = 0.6
@export var escala_ballesta_reposo: float = 1.0

# --- CONFIGURACIÓN DE BARRO (GRUPOS) ---
var tipos_de_barro: Dictionary = {
	"barro_ligero": 2.0,
	"barro_estandar": 4.5,
	"barro_profundo": 9.0,
	"barro_extremo": 18.0
}

# --- VARIABLES INTERNAS ---
var combustible_actual: float = 0.0
var motor_encendido: bool = false
var es_4x4: bool = false
var dif_bloqueado: bool = false

var remolque_acoplado: Node3D = null
var joint_acople: Joint3D = null
var tiene_carga: bool = false

# Diccionario para rastrear el hundimiento progresivo de cada rueda
var inmersiones_ruedas: Dictionary = {}

func _ready() -> void:
	combustible_actual = combustible_max
	
	if not curvas_torque:
		curvas_torque = Curve.new()
		curvas_torque.add_point(Vector2(0, 1))
		curvas_torque.add_point(Vector2(1, 0.2))
		
	# Inicializar el nivel de hundimiento de cada rueda en 0.0 (limpias)
	for child in get_children():
		if child is VehicleWheel3D:
			inmersiones_ruedas[child] = 0.0

func _physics_process(delta: float) -> void:
	_gestionar_inputs()
	_procesar_ruedas_y_fisicas(delta)
	_actualizar_ui()
	_procesar_esquina_delantera_derecha(delta)
	_actualizar_eje_rigido(delta)

func _gestionar_inputs() -> void:
	# E: Encendido
	if Input.is_action_just_pressed("press_e") and combustible_actual > 0:
		motor_encendido = !motor_encendido
		motor_estado_cambiado.emit(motor_encendido)

	# T: Tracción 4x4
	if Input.is_action_just_pressed("press_t"):
		es_4x4 = !es_4x4
		traccion_cambiada.emit(es_4x4)

	# Z: Bloqueo de Diferencial
	if Input.is_action_just_pressed("press_z"):
		dif_bloqueado = !dif_bloqueado
		dif_cambiado.emit(dif_bloqueado)
	
	# F: Remolque
	if Input.is_action_just_pressed("press_f"):
		if remolque_acoplado: _desacoplar()
		else: _acoplar()

func _procesar_ruedas_y_fisicas(delta: float) -> void:
	var aceleracion = 0.0
	var direccion = Input.get_axis("press_d", "press_a")

	if motor_encendido and combustible_actual > 0:
		aceleracion = Input.get_axis("press_s", "press_w")
		_consumir_combustible(aceleracion, delta)
	else:
		motor_encendido = false

	var ratio_velocidad = clamp(linear_velocity.length() / 25.0, 0.0, 1.0)
	var torque_base = aceleracion * max_torque * curvas_torque.sample(ratio_velocidad)

	steering = move_toward(steering, direccion * steering_max, steering_speed * delta)

	for wheel in get_children():
		if wheel is VehicleWheel3D:
			
			# --- A. DETECTAR EL SUELO Y TIPO DE BARRO ---
			var viscosidad_objetivo = 0.0
			var rueda_toca_barro = false
			
			if wheel.is_in_contact():
				var collider = wheel.get_contact_body()
				if collider:
					for grupo in tipos_de_barro.keys():
						if collider.is_in_group(grupo):
							viscosidad_objetivo = tipos_de_barro[grupo]
							rueda_toca_barro = true
							break
			
			# --- B. TRANSICIÓN SUAVE (SOLO PARA EL FRENADO/HUNDIMIENTO) ---
			if rueda_toca_barro:
				var velocidad_hundimiento = viscosidad_objetivo / 10.0 
				inmersiones_ruedas[wheel] = move_toward(inmersiones_ruedas[wheel], viscosidad_objetivo, velocidad_hundimiento * delta)
			else:
				inmersiones_ruedas[wheel] = move_toward(inmersiones_ruedas[wheel], 0.0, 20.0 * delta)
				
			var viscosidad_hundimiento = inmersiones_ruedas[wheel]

			# --- C. CALCULAR FRICCIÓN (INSTANTÁNEA) ---
			var friccion_final = 2.0 
			if rueda_toca_barro:
				# Pasa a resbalar instantáneamente usando el valor objetivo del barro
				friccion_final = clamp(2.0 - (viscosidad_objetivo * 0.1), 0.4, 1.0)
			
			if dif_bloqueado:
				friccion_final *= 1.4 
				
			wheel.wheel_friction_slip = friccion_final

			# --- D. CALCULAR TORQUE Y TRACCIÓN (INSTANTÁNEO) ---
			var es_trasera = wheel.position.z > 0
			var es_motriz = es_trasera or es_4x4
			var torque_aplicado = torque_base
			
			if rueda_toca_barro:
				# Pierde empuje instantáneamente al tocar el lodo
				torque_aplicado *= 0.6 
				
			wheel.engine_force = torque_aplicado if es_motriz else 0.0
			
			# --- E. FRENADO ---
			if aceleracion == 0 and linear_velocity.length() < 1.0:
				wheel.brake = 5.0
			else:
				wheel.brake = 0.0

			# --- F. RESISTENCIA CUADRÁTICA PROGRESIVA (CON RETRASO) ---
			# Aquí seguimos usando el valor que sube en 2 segundos
			if viscosidad_hundimiento > 0.1 and linear_velocity.length() > 0.1:
				var vel_rueda = linear_velocity
				var rapidez = vel_rueda.length()
				var dir_opuesta = -vel_rueda.normalized()
				
				var magnitud_fuerza = (rapidez * rapidez) * viscosidad_hundimiento * (mass * 0.05)
				apply_force(dir_opuesta * magnitud_fuerza, wheel.global_position - global_position)

func _consumir_combustible(acel: float, delta: float) -> void:
	var consumo = consumo_base if acel != 0 else (consumo_base * 0.2)
	if es_4x4: consumo *= 1.2
	if dif_bloqueado: consumo *= 1.1
	
	combustible_actual -= consumo * delta
	if combustible_actual < 0: combustible_actual = 0

func _actualizar_ui() -> void:
	var vel = linear_velocity.length() * 3.6
	var rpm = rueda_fisica_di.get_rpm()
	if motor_encendido:
		rpm = clamp((linear_velocity.length() / 20.0) * max_rpm, 800.0, max_rpm)
	datos_actualizados.emit(combustible_actual, vel, rpm)

# --- FUNCIONES DE ESTADO ---
func repostar(cantidad: float) -> void:
	combustible_actual = clamp(combustible_actual + cantidad, 0.0, combustible_max)
	datos_actualizados.emit(combustible_actual, 0.0, 0.0)

func recibir_carga() -> void:
	tiene_carga = true

func entregar_carga() -> bool:
	if tiene_carga:
		tiene_carga = false
		return true
	return false

# --- SISTEMA DE REMOLQUE ---
func _acoplar():
	if not nodo_quinta_rueda: return
	var remolques = get_tree().get_nodes_in_group("remolques")
	for r in remolques:
		if r.has_node("PuntoPerno"):
			var dist = nodo_quinta_rueda.global_position.distance_to(r.get_node("PuntoPerno").global_position)
			if dist < 2.5:
				_crear_joint(r)
				return

func _crear_joint(remolque):
	remolque_acoplado = remolque
	var offset = remolque.global_position - remolque.get_node("PuntoPerno").global_position
	remolque.global_position = nodo_quinta_rueda.global_position + offset
	
	joint_acople = ConeTwistJoint3D.new()
	add_child(joint_acople)
	joint_acople.global_position = nodo_quinta_rueda.global_position
	joint_acople.node_a = self.get_path()
	joint_acople.node_b = remolque.get_path()
	joint_acople.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(60))
	joint_acople.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(20))
	
	add_collision_exception_with(remolque)
	if remolque.has_method("set_conectado"): remolque.set_conectado(true)

func _desacoplar():
	if joint_acople:
		joint_acople.queue_free()
		joint_acople = null
	if remolque_acoplado:
		remove_collision_exception_with(remolque_acoplado)
		if remolque_acoplado.has_method("set_conectado"): remolque_acoplado.set_conectado(false)
		remolque_acoplado = null

func _procesar_esquina_delantera_derecha(delta: float) -> void:
	# --- A. CÁLCULO DE ALTURA Y COMPRESIÓN (EJE Y) ---
	if raycast_di.is_colliding():
		var punto_choque = raycast_di.get_collision_point()
		var distancia = raycast_di.global_position.distance_to(punto_choque)
		
		# Movemos TODO el contenedor (y sus hijos con él)
		var target_y = -distancia + radio_rueda
		contenedor_suspension.position.y = lerp(contenedor_suspension.position.y, clamp(target_y, -extension_maxima, 0.0), 20.0 * delta)
		
		# Calculamos qué tan aplastada debe estar la ballesta (0.0 = extendida, 1.0 = tope)
		var compresion = clamp(1.0 - (distancia / extension_maxima), 0.0, 1.0)
		malla_ballesta.scale.y = lerp(escala_ballesta_reposo, escala_ballesta_reposo * 0.3, compresion)
	else:
		# Si la rueda está en el aire (ej. un salto)
		contenedor_suspension.position.y = lerp(contenedor_suspension.position.y, -extension_maxima, 5.0 * delta)
		malla_ballesta.scale.y = escala_ballesta_reposo

	# --- B. DIRECCIÓN (STEERING - GIRO LATERAL) ---
	# Solo rotamos el pivote de dirección, manteniendo limpio el eje Y.
	pivote_direccion.rotation.y = rueda_fisica_di.steering

	# --- C. RODAMIENTO (RPM REALES DEL MOTOR/PATINAJE) ---
	# get_rpm() nos da las Revoluciones Por Minuto de la rueda física de Godot.
	var rpm = rueda_fisica_di.get_rpm()
	
	# Para rotar en 3D necesitamos Radianes por Segundo, no RPM.
	# La fórmula matemática es: RPM * (PI / 30)
	var radianes_por_segundo = rpm * (PI / 30.0)
	
	# Aplicamos el rodamiento solo a la malla final
	# Nota: Si notas que la llanta gira hacia atrás cuando aceleras, cambia a "+ radianes_por_segundo"
	malla_llanta.rotate_x(+radianes_por_segundo * delta)

func _actualizar_eje_rigido(delta: float) -> void:
	# 1. Obtener distancias (usamos la extensión máxima si no hay colisión)
	var dist_i = extension_maxima + radio_rueda
	var dist_d = extension_maxima + radio_rueda
	
	if ray_ti.is_colliding():
		dist_i = ray_ti.global_position.distance_to(ray_ti.get_collision_point())
	
	if ray_td.is_colliding():
		dist_d = ray_td.global_position.distance_to(ray_td.get_collision_point())
	
	# 2. Posición Y (Centro del eje)
	var altura_i = -dist_i + radio_rueda
	var altura_d = -dist_d + radio_rueda
	var altura_centro = (altura_i + altura_d) / 30.0
	
	contenedor_eje.position.y = lerp(contenedor_eje.position.y, clamp(altura_centro, -extension_maxima, 0.0), 0.05 * delta)
	
	# 3. Inclinación Lateral (Eje Z)
	# Calculamos el ángulo basado en la diferencia de alturas
	var diferencia_altura = dist_i - dist_d
	var angulo_z = atan2(diferencia_altura, ancho_eje)
	contenedor_eje.rotation.z = lerp_angle(contenedor_eje.rotation.z, angulo_z, 15.0 * delta)

	# 4. Rodamiento Trasero (Cada rueda usa su propia RPM física)
	var rpm_i = rueda_fisica_ti.get_rpm()
	var rpm_d = rueda_fisica_td.get_rpm()
	
	malla_llanta_ti.rotate_x((rpm_i * (PI / 30.0)) * delta)
	malla_llanta_td.rotate_x((rpm_d * (PI / 30.0)) * delta)
