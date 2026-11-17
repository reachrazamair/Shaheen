extends Node2D
## Entry point. For chunk 1.1 it only proves the project runs and the
## input map works: it shows the last input action pressed.

const ACTIONS := [
	"pitch_up", "pitch_down", "throttle_up", "throttle_down",
	"engine_toggle", "flaps_cycle", "gear_toggle", "brake", "pause", "restart",
]

@onready var _action_label: Label = $UI/ActionLabel


func _unhandled_input(event: InputEvent) -> void:
	for action in ACTIONS:
		if event.is_action_pressed(action):
			_action_label.text = "Last action: " + action
			return
