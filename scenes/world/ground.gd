@tool
extends Node2D
## Flat ground strip at y = 0 with scattered tufts as motion cues. The top
## colour follows colour stops along the route (e.g. green Risalpur, sandy
## Karachi, green Sargodha), set by the flight scene from the bases' data:
## constant before the first stop and after the last, blended in between.
## With no stops it is grass_color everywhere.

@export var start_m := -2000.0:
	set(v): start_m = v; queue_redraw()
@export var end_m := 30000.0:
	set(v): end_m = v; queue_redraw()
@export var depth_px := 400.0
@export var grass_color := Color(0.42, 0.62, 0.3)
@export var tuft_color := Color(0.33, 0.52, 0.24)
@export var soil_color := Color(0.5, 0.42, 0.3)
## Colour stops (metres along the route) with the grass and tuft colour there.
@export var stop_m := PackedFloat32Array()
@export var stop_grass := PackedColorArray()
@export var stop_tuft := PackedColorArray()
## Colour bands per blend (more = smoother).
@export var blend_steps := 24
## Average spacing between grass tufts, in metres.
@export var tuft_spacing_m := 12.0
@export var random_seed := 1947


func set_stops(xs: PackedFloat32Array, grass: PackedColorArray, tufts: PackedColorArray) -> void:
	stop_m = xs
	stop_grass = grass
	stop_tuft = tufts
	queue_redraw()


func _at(x: float, cols: PackedColorArray, fallback: Color) -> Color:
	if stop_m.is_empty():
		return fallback
	if x <= stop_m[0]:
		return cols[0]
	for i in stop_m.size() - 1:
		if x <= stop_m[i + 1]:
			return cols[i].lerp(cols[i + 1], (x - stop_m[i]) / maxf(stop_m[i + 1] - stop_m[i], 1.0))
	return cols[cols.size() - 1]


func _draw() -> void:
	var px := WorldScale.PX_PER_M
	var x0 := start_m * px
	var w := (end_m - start_m) * px
	draw_rect(Rect2(x0, 0, w, depth_px), _at(start_m, stop_grass, grass_color))
	if not stop_m.is_empty():
		for i in stop_m.size() - 1:
			var band := (stop_m[i + 1] - stop_m[i]) / blend_steps
			for k in blend_steps:
				var f := (k + 0.5) / blend_steps
				draw_rect(Rect2((stop_m[i] + k * band) * px, 0, band * px + 1, depth_px), stop_grass[i].lerp(stop_grass[i + 1], f))
		var last := stop_m[stop_m.size() - 1]
		draw_rect(Rect2(last * px, 0, (end_m - last) * px, depth_px), stop_grass[stop_grass.size() - 1])
	draw_rect(Rect2(x0, 14, w, depth_px), soil_color)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var x := start_m
	while x < end_m:
		x += tuft_spacing_m * rng.randf_range(0.5, 1.5)
		var y := rng.randi_range(1, 11)
		draw_rect(Rect2(x * px, y, rng.randi_range(2, 5), 1), _at(x, stop_tuft, tuft_color))
