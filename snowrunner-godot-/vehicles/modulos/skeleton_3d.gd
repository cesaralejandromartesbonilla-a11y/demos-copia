extends Node3D

@export_group("Conexiones Principales")
@export var chasis: VehicleBody3D
@export var esqueleto: Skeleton3D
@export var rueda_trasera_izq: VehicleWheel3D
@export var rueda_trasera_der: VehicleWheel3D

@export_group("Configuración de Huesos")
# IMPORTANTE: El orden DEBE ser: [Frente, Medio, Medio, Atrás]
@export var nombres_huesos: Array[String] = ["Bone.001", "Bone.002", "Bone.003", "Bone.004"]

# En huesos que vienen de Blender, la torsión (retorcer el trapo) es CASI SIEMPRE el eje Y.
@export_enum("X", "Y", "Z") var eje_torsion: int = 1 
@export var invertir_giro: bool = false # Activa esto si el chasis gira al revés que el eje

@export_group("Físicas del Metal")
@export var multiplicador_torsion: float = 1.0
@export var suavizado_metal: float = 8.0
@export var limite_grados: float = 25.0

var indices_huesos: Array[int] = []
var torsion_actual_rad: float = 0.0

func _ready() -> void:
	if esqueleto:
		for nombre in nombres_huesos:
			var id = esqueleto.find_bone(nombre)
			if id != -1:
				indices_huesos.append(id)

func _physics_process(delta: float) -> void:
	if not chasis or not esqueleto or indices_huesos.is_empty(): return
	
	var angulo_objetivo = 0.0
	
	# 1. Medir el ángulo de las ruedas traseras
	if rueda_trasera_izq.is_in_contact() or rueda_trasera_der.is_in_contact():
		var contacto_izq = rueda_trasera_izq.get_contact_point()
		var contacto_der = rueda_trasera_der.get_contact_point()
		
		var local_izq = chasis.to_local(contacto_izq)
		var local_der = chasis.to_local(contacto_der)
		
		var diferencia_altura = local_izq.y - local_der.y
		var ancho_eje = abs(rueda_trasera_izq.position.x - rueda_trasera_der.position.x)
		
		if ancho_eje > 0.01:
			var angulo_puro = atan2(diferencia_altura, ancho_eje)
			
			# Si el camión (+Z) invierte la matemática, lo volteamos fácil aquí
			if invertir_giro:
				angulo_puro = -angulo_puro
				
			angulo_objetivo = angulo_puro * multiplicador_torsion
			
			var limite_rad = deg_to_rad(limite_grados)
			angulo_objetivo = clamp(angulo_objetivo, -limite_rad, limite_rad)
	
	# 2. Suavizado
	torsion_actual_rad = lerp(torsion_actual_rad, angulo_objetivo, suavizado_metal * delta)
	
	# 3. DISTRIBUCIÓN EN CADENA (La corrección matemática)
	var cantidad_huesos = indices_huesos.size()
	
	# Dividimos la torsión entre las articulaciones flexibles.
	# Si hay 4 huesos, hay 3 divisiones que se pueden doblar.
	var torsion_por_segmento = torsion_actual_rad / float(cantidad_huesos - 1)
	
	for i in range(cantidad_huesos):
		var rotacion_local = 0.0
		
		# El hueso 0 (el de la cabina) no debe rotar, debe quedarse firme al frente
		# Solo del hueso 1 en adelante se retuercen
		if i > 0:
			rotacion_local = torsion_por_segmento
		
		var vector_rotacion = Vector3.ZERO
		if eje_torsion == 0: vector_rotacion.x = rotacion_local
		elif eje_torsion == 1: vector_rotacion.y = rotacion_local # Y es el rey en Blender
		else: vector_rotacion.z = rotacion_local
			
		var nueva_rotacion = Quaternion.from_euler(vector_rotacion)
		esqueleto.set_bone_pose_rotation(indices_huesos[i], nueva_rotacion)
