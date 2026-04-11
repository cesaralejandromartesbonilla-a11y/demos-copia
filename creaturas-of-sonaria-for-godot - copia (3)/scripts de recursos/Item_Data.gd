extends Resource
class_name ItemData

@export var item_name: String = "Objeto"
@export var model_scene: PackedScene # El modelo 3D que cae al suelo (ej. una manzana)
@export var slot_cost: int = 1 # 1 para una mano, 2 para usar ambas manos
@export var weight_kg: float = 1.0 # Para calcular el límite de peso del Titan vs Humano

@export_group("Consumo")
@export var is_edible: bool = false
@export var nutrition_value: float = 20.0 # Cuánto llena al comerlo

@export_group("Agricultura")
@export var is_seed: bool = false
@export var result_crop: Resource # Qué planta crece de esta semilla (lo usaremos luego para los 4 tipos)
