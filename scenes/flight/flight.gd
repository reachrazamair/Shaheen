extends Node2D
## One flight: departure base -> destination base, aircraft, camera, scenery, HUD.
## Bases and the route distance are data; the scenery theme blends from the
## departure base's look to the destination's as the plane flies.

@export var departure: BaseData
@export var destination: BaseData
## Distance between the two runway thresholds. Compressed so a trainer flight
## takes a few minutes (real Risalpur-Peshawar is ~45 km).
@export var route_distance_m := 9000.0
## Where the aircraft starts, in metres from the departure runway threshold.
@export var spawn_x_m := 60.0

@onready var aircraft: Aircraft = $Aircraft
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var ground: Node2D = $Ground
@onready var departure_base: Node2D = $DepartureBase
@onready var destination_base: Node2D = $DestinationBase
@onready var sky: CanvasItem = $Sky/Gradient
@onready var mountains: Node2D = $Mountains
@onready var hills: Node2D = $Hills
@onready var trees: Node2D = $Trees


func _ready() -> void:
	departure_base.data = departure
	destination_base.data = destination
	destination_base.position.x = route_distance_m * WorldScale.PX_PER_M
	ground.end_m = route_distance_m + destination.runway_length_m + 3000.0
	aircraft.place_at(spawn_x_m)
	camera.snap()
	hud.setup(aircraft, departure, destination, route_distance_m)
	_update_theme()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	_update_theme()


func _update_theme() -> void:
	var t := smoothstep(0.15, 0.85, aircraft.pos_m.x / route_distance_m)
	sky.modulate = departure.sky_tint.lerp(destination.sky_tint, t)
	mountains.color = departure.mountain_color.lerp(destination.mountain_color, t)
	mountains.height_scale = lerpf(departure.mountain_height, destination.mountain_height, t)
	hills.color = departure.hill_color.lerp(destination.hill_color, t)
	trees.color = departure.tree_color.lerp(destination.tree_color, t)
