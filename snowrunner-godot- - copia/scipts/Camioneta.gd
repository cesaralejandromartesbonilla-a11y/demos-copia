extends VehicleBody3D

# --- SEÑALES ---
signal traccion_cambiada(estado_4x4)
signal motor_estado_cambiado(prendido)
signal dif_cambiado(bloqueado)
signal datos_actualizados(combustible)

#==================================
var modo_seleccion_winche: bool = false
@onready var camara_actual = get_viewport().get_camera_3d() # Referencia a la cámara
#==================================

# --- CONFIGURACIÓN ---
@export_group("Motor y Tracción")
@export var max_torque: float = 400.0 # Ajustado a valores de Godot (Newton-metros)
@export var max_rpm: float = 3000.0
@export var steering_max: float = 0.5 # Radianes (aprox 30 grados)
@export var steering_speed: float = 2.0

@export_group("Combustible")
@export var combustible_max: float = 100.0
var combustible_actual: float = 20.0

@export_group("Remolque")
var remolque_acoplado: Node3D = null
var joint_acople: Joint3D = null
# Nodo hijo de la camioneta donde se conecta el remolque (Marker3D)
@onready var punto_quinta_rueda: Marker3D = $QuintaRueda

# --- ESTADOS INTERNOS ---
var motor_encendido: bool = false
var es_4x4: bool = false
var dif_bloqueado: bool = false

@export_group("Motor Avanzado")
@export var torque_curva: Curve # Crea una curva en el inspector
@export var transmision_ratio: float = 0.2 # Cuanto más bajo, más lenta y pesada
@export var velocidad_maxima: float = 25.0 # m/s (unos 90 km/h)

# --- VARIABLES DEL WINCHE PRO ---
@export_group("Winche Avanzado")
var hook_pos = Vector3()
var hook_active = false
var rope_length = 0.0
@export var winch_speed = 5.0      # Velocidad al recoger cable
@export var rope_stiffness = 20.0  # Rigidez del cable
@export var rope_damping = 4.0     # Amortiguación (para que no rebote como un chicle)
@onready var hook_ctrl = $HookController

# Para el dibujo del cable (puedes usar un ImmediateMesh)
@onready var winch_origin = $MarkerFrontal # Asegúrate de tener este nodo

# --- VARIABLES DE BARRO ---
var en_barro: bool = false
var lodo_viscosidad: float = 0.0
var lodo_friccion: float = 5.0
var lodo_profundidad: float = 0.0

# Referencia a la malla visual para el hundimiento
@onready var chasis_visual = $"." # El nodo que contiene el modelo 3D

# --- VARIABLES DE AJUSTE ---
@export var altura_suspension_normal: float = 0.3
@export var altura_suspension_barro: float = 0.3 # Casi sin recorrido para que se sienta enterrado

func entrar_en_barro(v, f, p):
	en_barro = true
	lodo_viscosidad = v
	lodo_friccion = f
	lodo_profundidad = p
	
	# Ajustamos las ruedas para que "bajen"
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			# Reducimos el muelle para que el peso del camión lo hunda
			wheel.suspension_travel = altura_suspension_barro
			wheel.suspension_stiffness = 10.0 # Más blando

func salir_del_barro():
	en_barro = false
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			wheel.suspension_travel = altura_suspension_normal
			wheel.suspension_stiffness = 40.0 # Rigidez normal

func _calcular_fuerza_motor(throttle: float) -> float:
	if not motor_encendido or combustible_actual <= 0: return 0.0
	
	# Calculamos qué tan rápido vamos respecto al máximo
	var velocidad_actual = linear_velocity.length()
	var ratio_velocidad = clamp(velocidad_actual / velocidad_maxima, 0.0, 1.0)
	
	# Usamos la curva para que tenga mucha fuerza al salir y poca al final
	# Si no creas la curva en el inspector, esto fallará. 
	# (Puedes usar un cálculo matemático simple si prefieres no usar Curve)
	var factor_potencia = 1.0 - ratio_velocidad 
	
	return throttle * max_torque * factor_potencia * transmision_ratio

func _process(_delta):
	# Opcional: Cambiar el cursor si estamos sobre algo válido
	var camera = get_viewport().get_camera_3d()
	if camera and not hook_ctrl:
		# (Lógica similar al raycast del mouse mencionada arriba)
		# Si el rayo toca algo -> cursor_shape = CURSOR_CROSS
		# Si no -> cursor_shape = CURSOR_ARROW
		pass

func _physics_process(delta: float) -> void:
	if modo_seleccion_winche:
		_actualizar_raycast_visual()
	
	# 1. CONTROLES DE SISTEMA (Motor, Acople, Tracción)
	_procesar_inputs_sistema()
	
	# 2. CONSUMO Y MOVIMIENTO
	var aceleracion = 0.0
	
	if motor_encendido and combustible_actual > 0:
		aceleracion = Input.get_axis("press_s", "press_w") # S / W
		# Consumo simple
		if aceleracion != 0:
			combustible_actual -= 0.5 * delta
		else:
			combustible_actual -= 0.1 * delta # Ralentí
			
		datos_actualizados.emit(combustible_actual)
	else:
		aceleracion = 0.0 # Si no hay combustible o motor apagado
	
	# 3. APLICAR FUERZAS A LAS RUEDAS
	# Asumimos que las ruedas traseras tienen "Trasera" en su nombre de nodo
	# Ejemplo: RuedaTraseraIzquierda, RuedaDelanteraDerecha
	var fuerza_final = _calcular_fuerza_motor(aceleracion)
	
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			var es_rueda_motriz = "Trasera" in wheel.name or es_4x4
			if es_rueda_motriz:
				wheel.engine_force = fuerza_final
				
			else:
				wheel.engine_force = 0.0
				
			# Tracción (Fricción) dinámica según diferencial
			# Si el dif está bloqueado, aumentamos la fricción para que no patine una sola rueda
			wheel.wheel_friction_slip = 10.0 if dif_bloqueado else 5.0
			
	
	# 4. DIRECCIÓN
	var steer_target = Input.get_axis("press_d", "press_a") * steering_max
	steering = move_toward(steering, steer_target, steering_speed * delta)
	
	# ACTUALIZAR HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		# 1. Velocidad (Usamos linear_velocity que es propia de RigidBody/VehicleBody)
		hud.actualizar_velocidad(linear_velocity.length())
		
		# 2. Combustible
		hud.actualizar_combustible(combustible_actual, combustible_max)
		
		# 3. Tracción y Diferencial
		hud.actualizar_traccion(es_4x4, dif_bloqueado)
	
	if en_barro:
		# 1. Aplicamos una fuerza de frenado constante (Resistencia)
		var resistencia = -linear_velocity * lodo_viscosidad * mass * delta
		apply_central_force(resistencia)
		
		# 2. Efecto visual de hundimiento
		# Si vamos lento, el coche se "hunde" más
		var factor_hundimiento = clamp(1.0 - (linear_velocity.length() / 5.0), 0.5, 1.0)
		chasis_visual.position.y = lerp(chasis_visual.position.y, -lodo_profundidad * factor_hundimiento, delta * 2.0)
		
		# 3. Hacer que las ruedas patinen
		for wheel in get_children():
			if wheel is VehicleWheel3D:
				# Reducimos la fricción para que la rueda gire pero no avance
				wheel.wheel_friction_slip = lodo_friccion
	else:
		# Fricción normal en asfalto/tierra seca
		for wheel in get_children():
			if wheel is VehicleWheel3D:
				wheel.wheel_friction_slip = 10.0 # Valor estándar
	_manejar_input_winche(delta)

func _manejar_input_winche(_delta):
	# Verificación de seguridad: ¿Existe el nodo y tiene la variable?
	if not hook_ctrl: 
		return

	# 1. Alternar modo de selección (TAB)
	if Input.is_action_just_pressed("ui_focus_next"):
		_alternar_modo_mouse()
	
	# 2. Intentar enganchar con Click
	if modo_seleccion_winche and Input.is_action_just_pressed("click_izquierdo"):
		_intentar_enganchar_con_mouse()
		
	# 3. Soltar el gancho (V) - Usamos "get" por seguridad si sigue dando error
	var esta_enganchado = hook_ctrl.get("is_hooked")
	
	if Input.is_action_just_pressed("press_v") and esta_enganchado:
		hook_ctrl.release_hook()

	# 4. Control de tracción (Q / Z)
	if esta_enganchado:
		if Input.is_key_pressed(KEY_Q):
			hook_ctrl.pull_speed = 15.0
		elif Input.is_key_pressed(KEY_Z):
			hook_ctrl.pull_speed = -15.0
		else:
			hook_ctrl.pull_speed = 0.0



func _alternar_modo_mouse():
	modo_seleccion_winche = !modo_seleccion_winche
	
	# 1. Visibilidad del mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if modo_seleccion_winche else Input.MOUSE_MODE_CAPTURED
	
	# 2. ACTIVAR/DESACTIVAR EL NODO RAYCAST FÍSICO
	var ray_nodo = $"SpringArm3D/Camera3D/Hook Raycast" # Ajusta la ruta si es distinta
	if ray_nodo:
		ray_nodo.enabled = modo_seleccion_winche
		ray_nodo.visible = modo_seleccion_winche

func _procesar_inputs_sistema():
	# Encender Motor (Tecla E)
	if Input.is_action_just_pressed("press_e"):
		if combustible_actual > 0:
			motor_encendido = !motor_encendido
			motor_estado_cambiado.emit(motor_encendido)
			# Feedback rápido en consola para verificar
			print("ESTADO DEL MOTOR: ", motor_encendido) 
		else:
			print("SIN COMBUSTIBLE")

	# Tracción 4x4 (Tecla T)
	if Input.is_action_just_pressed("press_t"): # Asegura añadir 'press_t' al Input Map
		es_4x4 = !es_4x4
		traccion_cambiada.emit(es_4x4)
		print("4x4: ", es_4x4)

	# Bloqueo Diferencial (Tecla Z)
	if Input.is_action_just_pressed("press_z"):
		dif_bloqueado = !dif_bloqueado
		dif_cambiado.emit(dif_bloqueado)
		print("Dif Bloqueado: ", dif_bloqueado)

	# Acoplar Remolque (Tecla F)
	if Input.is_action_just_pressed("press_f"):
		if remolque_acoplado:
			desacoplar()
		else:
			intentar_acoplar()

# --- LÓGICA DE ACOPLE ---

func intentar_acoplar():
	# Buscamos nodos en el grupo "remolques"
	var remolques = get_tree().get_nodes_in_group("remolques")
	var candidato = null
	var distancia_minima = 3.0 # Metros
	
	for r in remolques:
		var punto_enganche = r.get_node("PuntoPerno") # El remolque DEBE tener este Marker3D
		if punto_enganche:
			var dist = punto_quinta_rueda.global_position.distance_to(punto_enganche.global_position)
			if dist < distancia_minima:
				candidato = r
				distancia_minima = dist
	
	if candidato:
		_realizar_conexion(candidato)

func desacoplar():
	if joint_acople:
		if remolque_acoplado:
			self.remove_collision_exception_with(remolque_acoplado)
			if remolque_acoplado.has_method("set_acoplado"):
				remolque_acoplado.set_acoplado(false)
		
		joint_acople.queue_free()
		joint_acople = null
		remolque_acoplado = null
		print("Remolque liberado.")

func repostar(cantidad: float):
	combustible_actual += cantidad
	# Clamp para no superar el máximo
	if combustible_actual > combustible_max:
		combustible_actual = combustible_max
	
	# Emitimos la señal para actualizar la UI inmediatamente
	datos_actualizados.emit(combustible_actual)


# --- MODIFICACIÓN EN LA CONEXIÓN DEL REMOLQUE ---

func _realizar_conexion(remolque):
	remolque_acoplado = remolque
	
	# 1. MOVER EL REMOLQUE A SU SITIO ANTES DEL JOINT (Evita el frenazo en seco)
	var perno_remolque = remolque.get_node("PuntoPerno")
	if perno_remolque:
		# Calculamos donde debería estar el remolque para que los puntos coincidan
		var global_fix_pos = punto_quinta_rueda.global_position
		var offset_local = remolque.global_position - perno_remolque.global_position
		remolque.global_position = global_fix_pos + offset_local
		# Opcional: Alineamos la rotación para que no haya un latigazo
		remolque.global_rotation.y = global_rotation.y

	# 2. CREAR EL JOINT
	joint_acople = ConeTwistJoint3D.new()
	add_child(joint_acople)
	
	joint_acople.global_position = punto_quinta_rueda.global_position
	
	# 3. CONFIGURAR NODOS
	joint_acople.node_a = self.get_path()
	joint_acople.node_b = remolque.get_path()
	
	# 4. PARÁMETROS DE SUAVE (Para que no parezca soldado)
	joint_acople.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(70.0))
	joint_acople.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(20.0))
	joint_acople.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 1.2) # Más de 1.0 para que sea elástico
	joint_acople.set_param(ConeTwistJoint3D.PARAM_BIAS, 0.3)
	
	# 5. EXCEPCIONES DE COLISIÓN
	self.add_collision_exception_with(remolque)
	# Si el remolque tiene un chasis hijo, asegúrate de ignorarlo también
	print("Remolque acoplado con suavizado.")

func _manejar_winche_mouse():
	# Si presionamos el botón principal del mouse (o el que prefieras)
	if Input.is_action_just_pressed("click_izquierdo"): # Configura esto en Input Map
		if not hook_ctrl.is_hooked:
			_intentar_enganchar_con_mouse()
		else:
			hook_ctrl.release_hook()

# En Camioneta.gd, dentro de la función del click del mouse

func _intentar_enganchar_con_mouse():
	var camara = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camara.project_ray_origin(mouse_pos)
	var ray_target = ray_origin + camara.project_ray_normal(mouse_pos) * 25.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Detectamos si es un RigidBody o StaticBody
		var objeto_tocado = result.collider
		
		# IMPORTANTE: Llamamos a la función con los datos del mouse
		hook_ctrl.launch_hook(result.position, objeto_tocado)
		
		# Cerramos el modo selección
		modo_seleccion_winche = false
	else:
		print("No se detectó nada")
	
	
	# Evitamos chocar con nosotros mismos
	query.exclude = [self.get_rid()] 
	
	if space_state.intersect_ray(query):
		# Ahora hook_position existe porque la añadimos en el Paso 1
		hook_ctrl.hook_position = result.position
		hook_ctrl.is_hooked = true
		hook_ctrl.hooked_object = result.collider
		
		print("¡Enganchado!")
		_alternar_modo_mouse() # Cerramos el modo selección
	else:
		print("No hay nada que enganchar en esa posición")
	
	# Excluir a la camioneta y sus hijos (ruedas, etc.) para no engancharse a uno mismo
	query.exclude = [self.get_rid()] 
	
	
	if result:
		# Asignar datos al controlador
		hook_ctrl.hook_position = result.position
		hook_ctrl.is_hooked = true
		print("Enganchado a: ", result.collider.name)
		_alternar_modo_mouse() # Volver a conducir automáticamente
	
	# Obtenemos la cámara actualizada
	camara_actual = get_viewport().get_camera_3d()
	if not camara_actual: return
	
	# IMPORTANTE: Nos excluimos a nosotros mismos (Camioneta y ruedas)
	# Excluimos el propio vehículo para no engancharnos al chasis
	query.exclude = [self.get_rid()] 
	
	if result:
		var distancia = global_position.distance_to(result.position)
		
		# Verificamos si está dentro del alcance real del winche (ej. 25 metros)
		# Puedes leer esta variable desde hook_ctrl si la tiene, o usar una local
		var alcance_maximo = 25.0 
		
		if distancia <= alcance_maximo:
			# --- AQUÍ OCURRE LA MAGIA ---
			# Inyectamos los datos directamente al HookController
			hook_ctrl.hook_position = result.position
			hook_ctrl.hooked_object = result.collider
			hook_ctrl.is_hooked = true
			
			# Ajustamos la longitud inicial de la cuerda
			# (Dependiendo de cómo sea tu script hook_rope, esto puede ser automático)
			
			print("¡ENGANCHADO A: ", result.collider.name, "!")
			
			# Opcional: Volver al modo conducción automáticamente tras enganchar
			_alternar_modo_mouse() 
		else:
			print("Objetivo demasiado lejos: ", snapped(distancia, 0.1), "m")
	else:
		print("No se encontró ningún objeto bajo el cursor.")

func _actualizar_raycast_visual():
	var camara = get_viewport().get_camera_3d()
	if not camara: return
	
	var mouse_pos = get_viewport().get_mouse_position()
	# Proyectamos el rayo desde la cámara
	var origen = camara.project_ray_origin(mouse_pos)
	var direccion = camara.project_ray_normal(mouse_pos)
	
	# Actualizamos el nodo Hook Raycast (si es un RayCast3D)
	var raycast_nodo = $"SpringArm3D/Camera3D/Hook Raycast" # Ajusta la ruta a tu nodo
	if raycast_nodo:
		# Movemos el origen del raycast a donde está la cámara
		raycast_nodo.global_position = origen
		# Hacemos que apunte hacia la dirección del mouse 25 metros
		raycast_nodo.target_position = raycast_nodo.to_local(origen + direccion * 25.0)
