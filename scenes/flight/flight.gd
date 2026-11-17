extends Node2D
## One flight: world + aircraft + camera + cockpit HUD.

## Where the aircraft starts, in metres from the runway start.
@export var spawn_x_m := 60.0

@onready var aircraft: Aircraft = $Aircraft
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	aircraft.place_at(spawn_x_m)
	camera.snap()
	hud.setup(aircraft)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
