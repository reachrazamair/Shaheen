@tool
extends Node2D
## Flat ground strip at y = 0 with scattered grass tufts as motion cues.
## (Parallax hills, trees and base buildings come in chunk 1.6.)

@export var start_m := -2000.0:
	set(v): start_m = v; queue_redraw()
@export var end_m := 30000.0:
	set(v): end_m = v; queue_redraw()
@export var depth_px := 400.0
@export var grass_color := Color(0.42, 0.62, 0.3)
@export var tuft_color := Color(0.33, 0.52, 0.24)
@export var soil_color := Color(0.5, 0.42, 0.3)
## Average spacing between grass tufts, in metres.
@export var tuft_spacing_m := 12.0
@export var random_seed := 1947


func _draw() -> void:
	var px := WorldScale.PX_PER_M
	var x0 := start_m * px
	var w := (end_m - start_m) * px
	draw_rect(Rect2(x0, 0, w, depth_px), grass_color)
	draw_rect(Rect2(x0, 14, w, depth_px), soil_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var x := start_m
	while x < end_m:
		x += tuft_spacing_m * rng.randf_range(0.5, 1.5)
		var y := rng.randi_range(1, 11)
		draw_rect(Rect2(x * px, y, rng.randi_range(2, 5), 1), tuft_color)
