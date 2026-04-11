extends VehicleBody3D

# Referencia a las patas de apoyo (si quieres animarlas luego)
# @onready var patas = $PatasApoyo 


func set_acoplado(estado: bool):
	if estado:
		print("Remolque: Conectado al sistema eléctrico del camión.")
		# Aquí podrías subir las patas de apoyo
		# $PatasApoyo.visible = false
		
		# Aumentar un poco el frenado de las ruedas para simular frenos de aire conectados?
		brake = 0.0 
	else:
		print("Remolque: Desconectado.")
		# Bajar patas
		# $PatasApoyo.visible = true
		
		# Aplicar freno de estacionamiento automático
		brake = 1.0 

var en_barro: bool = false

func entrar_en_barro(_v, _f, _p):
	en_barro = true
	# El remolque solo sufre el peso, no el cálculo de tracción
	mass *= 1.5 # Simula el peso del lodo pegado
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			wheel.suspension_travel = 0.05 

func salir_del_barro():
	en_barro = false
	mass /= 1.5
	for wheel in get_children():
		if wheel is VehicleWheel3D:
			wheel.suspension_travel = 0.2
