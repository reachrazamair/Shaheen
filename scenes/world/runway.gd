@tool
extends Node2D
## Side view of a runway: an asphalt strip at ground level with centreline
## dashes, threshold blocks and edge-light posts. Node origin = runway start.
## (Will be driven by BaseData in chunk 1.6.)

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

	x = 0.0
	while x <= length_m:
		draw_rect(Rect2(x * px, -3, 1, 3), light_post_color)
		draw_rect(Rect2(x * px, -4, 1, 1), light_color)
		x += light_spacing_m
