extends Resource
class_name ItemData

@export var item_name: String = "Objeto"
@export var slot_cost: int = 1 
@export var weight_kg: float = 1.0 
@export_enum("ninguno", "planta", "carne") var food_type: String = "ninguno"
@export var item_mesh: Mesh

@export_group("Consumo")
@export var is_edible: bool = false
@export var nutrition_value: float = 20.0 

@export_group("Herramientas")
@export var is_tool: bool = false
@export var can_till_soil: bool = false 

@export_group("Agricultura (Semillas)")
@export var is_seed: bool = false

enum CropType { NONE, SINGLE_HARVEST, PERMANENT, FUNGUS }
@export var crop_type: CropType = CropType.NONE

@export var result_item_data: Resource 
@export var requires_submerged: bool = false 
@export var result_model_scene: PackedScene 
@export var compost_needed: float = 50.0
