@tool
extends Node2D
## Flat ground strip at y = 0 with scattered tufts as motion cues. The top
## colour blends from grass_color to end_grass_color between blend_from_m and
## blend_to_m (e.g. green Risalpur to sandy Karachi), set from the bases' data.

@export var start_m := -2000.0:
	set(v): start_m = v; queue_redraw()
@export var end_m := 30000.0:
	set(v): end_m = v; queue_redraw()
@export var depth_px := 400.0
@export var grass_color := Color(0.42, 0.62, 0.3)
@export var tuft_color := Color(0.33, 0.52, 0.24)
@export var soil_color := Color(0.5, 0.42, 0.3)
@export var end_grass_color := Color(0.42, 0.62, 0.3)
@export var end_tuft_color := Color(0.33, 0.52, 0.24)
@export var blend_from_m := 1000.0
@export var blend_to_m := 4000.0
## Colour bands used for the blend (more = smoother).
@export var blend_steps := 24
## Average spacing between grass tufts, in metres.
@export var tuft_spacing_m := 12.0
@export var random_seed := 1947


func _draw() -> void:
	var px := WorldScale.PX_PER_M
	var x0 := start_m * px
	var w := (end_m - start_m) * px
	draw_rect(Rect2(x0, 0, w, depth_px), grass_color)
	# Blend band, then the end colour to the far end.
	var band := (blend_to_m - blend_from_m) / blend_steps
	for k in blend_steps:
		var f := (k + 0.5) / blend_steps
		draw_rect(Rect2((blend_from_m + k * band) * px, 0, band * px + 1, depth_px), grass_color.lerp(end_grass_color, f))
	draw_rect(Rect2(blend_to_m * px, 0, (end_m - blend_to_m) * px, depth_px), end_grass_color)
	draw_rect(Rect2(x0, 14, w, depth_px), soil_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var x := start_m
	while x < end_m:
		x += tuft_spacing_m * rng.randf_range(0.5, 1.5)
		var y := rng.randi_range(1, 11)
		var f := clampf((x - blend_from_m) / maxf(blend_to_m - blend_from_m, 1.0), 0.0, 1.0)
		draw_rect(Rect2(x * px, y, rng.randi_range(2, 5), 1), tuft_color.lerp(end_tuft_color, f))
