@tool
extends Node2D
## Side view of a runway: an asphalt strip at ground level with centreline
## dashes, threshold blocks and edge-light posts. Node origin = runway start.
## At night (GameState.night) the lights glow: white/yellow edge lights, green
## threshold, red runway end, and sequenced flashing approach lights.

@export var length_m := 1800.0:
	set(v): length_m = v; queue_redraw()
@export var thickness_px := 4
@export var asphalt_color := Color(0.32, 0.32, 0.35)
@export var marking_color := Color(0.92, 0.92, 0.88)
@export var light_post_color := Color(0.2, 0.2, 0.2)
@export var light_color := Color(1.0, 0.85, 0.3)
@export var dash_spacing_m := 50.0
@export var dash_length_m := 20.0
@export var light_spacing_m := 60.0
## Approach light poles before the threshold, to line up from further out.
@export var approach_lights_m := 150.0
@export var approach_light_spacing_m := 25.0
@export var approach_light_color := Color(1.0, 0.3, 0.25)
@export_group("Night")
@export var edge_glow_color := Color(1.0, 0.92, 0.65)
@export var threshold_color := Color(0.2, 1.0, 0.35)
@export var end_color := Color(1.0, 0.15, 0.1)
@export var approach_glow_color := Color(1.0, 0.95, 0.85)
## One sweep of the flashing approach lights toward the runway (s).
@export var rabbit_period_s := 1.0

var _time := 0.0
var _redraw_timer := 0.0


func _night() -> bool:
	var gs := get_node_or_null("/root/GameState")
	return gs != null and gs.night


func _process(delta: float) -> void:
	if _night():
		_time += delta
		# The flashing approach lights only need ~15 updates a second.
		_redraw_timer -= delta
		if _redraw_timer <= 0.0:
			_redraw_timer = 1.0 / 15.0
			queue_redraw()


func _draw() -> void:
	var px := WorldScale.PX_PER_M
	var l := length_m * px
	draw_rect(Rect2(0, 0, l, thickness_px), asphalt_color)

	var x := dash_spacing_m
	while x < length_m - dash_spacing_m:
		draw_rect(Rect2(x * px, 1, dash_length_m * px, 1), marking_color)
		x += dash_spacing_m

	# Threshold blocks at both ends.
	for tx in [0.0, length_m - 30.0]:
		draw_rect(Rect2(tx * px, 0, 30.0 * px, 1), marking_color)

	# Approach lights: taller poles getting shorter toward the threshold.
	var ax := -approach_lights_m
	while ax < -1.0:
		var hgt := roundi(3 + 6 * (-ax / approach_lights_m))
		draw_rect(Rect2(ax * px, -hgt, 1, hgt), light_post_color)
		draw_rect(Rect2(ax * px - 1, -hgt - 2, 3, 2), approach_light_color)
		ax += approach_light_spacing_m

	x = 0.0
	while x <= length_m:
		draw_rect(Rect2(x * px, -3, 1, 3), light_post_color)
		draw_rect(Rect2(x * px, -4, 1, 1), light_color)
		x += light_spacing_m

	if _night():
		_draw_night_lights()


func _draw_night_lights() -> void:
	var px := WorldScale.PX_PER_M
	var gs := get_node("/root/GameState")
	# Edge lights.
	var x := 0.0
	while x <= length_m:
		_glow(Vector2(x * px + 0.5, -3.5), edge_glow_color, 1.0, gs)
		x += light_spacing_m
	# Threshold (green) and runway end (red) bars.
	for k in 5:
		_glow(Vector2(k * 2.0, -1.0), threshold_color, 0.9, gs)
		_glow(Vector2(length_m * px - k * 2.0, -1.0), end_color, 0.9, gs)
	# Approach lights: steady red, plus a bright flash running toward the runway.
	var poles: Array = []
	var ax := -approach_lights_m
	while ax < -1.0:
		poles.append(ax)
		ax += approach_light_spacing_m
	var lit := int(fmod(_time / rabbit_period_s, 1.0) * poles.size())
	for i in poles.size():
		var a: float = poles[i]
		var hgt := roundi(3 + 6 * (-a / approach_lights_m))
		var p := Vector2(a * px, -hgt - 1)
		_glow(p, approach_light_color, 0.9, gs)
		if i == lit:
			_glow(p, approach_glow_color, 2.2, gs)


func _glow(p: Vector2, col: Color, r: float, gs: Node) -> void:
	draw_circle(p, r * 4.0, gs.glow(Color(col, 0.12)))
	draw_circle(p, r * 2.0, gs.glow(Color(col, 0.3)))
	draw_circle(p, r, gs.glow(col))
