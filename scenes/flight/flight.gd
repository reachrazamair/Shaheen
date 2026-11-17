extends Node2D
## One flight: world + aircraft + camera + (for now) debug readout.

## Where the aircraft starts, in metres from the runway start.
@export var spawn_x_m := 60.0

@onready var aircraft: Aircraft = $Aircraft
@onready var camera: Camera2D = $Camera
@onready var debug_label: Label = $DebugUI/DebugLabel


func _ready() -> void:
	aircraft.place_at(spawn_x_m)
	camera.snap()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	# Temporary debug readout; replaced by the cockpit HUD in chunk 1.5.
	debug_label.text = "%s\nSPD %3d kt   THR %3d%%   %s\nDIST %d m\nW/S throttle   B brake   R restart" % [
		aircraft.data.display_name,
		roundi(aircraft.speed_kt),
		roundi(aircraft.throttle * 100.0),
		"BRAKE" if aircraft.braking else "",
		roundi(aircraft.pos_m.x),
	]
