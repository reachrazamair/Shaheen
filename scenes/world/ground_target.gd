class_name GroundTarget
extends Node2D
## A ground target for the air-to-ground mission: a stylised, unmarked
## military object standing on the ground line (no flags or national markings).
## Drawn once in code; redrawn only when destroyed (blackened wreck).
## Node origin = middle of the target on the ground.

## Kinds the mission picks from (see _draw_* below).
const KINDS := ["bunker", "radar", "sam", "fuel", "tank"]
## Width per kind, metres (drawn ~2x true size, like the aircraft).
const WIDTH_M := {"bunker": 16.0, "radar": 14.0, "sam": 14.0, "fuel": 18.0, "tank": 12.0}

var kind := "bunker"
var x_m := 0.0
var destroyed := false
## Small red marker above a live target so it can be spotted from the air.
var show_marker := true

var _sand := Color(0.66, 0.6, 0.45)
var _olive := Color(0.38, 0.4, 0.28)
var _olive_dark := Color(0.25, 0.27, 0.18)
var _concrete := Color(0.62, 0.61, 0.57)
var _ink := Color(0.15, 0.15, 0.13)


var half_width_m: float:
	get: return WIDTH_M.get(kind, 14.0) * 0.5


func _ready() -> void:
	position = Vector2(x_m * WorldScale.PX_PER_M, 0.0)
	queue_redraw()


func destroy() -> void:
	if destroyed:
		return
	destroyed = true
	queue_redraw()


func _draw() -> void:
	var w: float = WIDTH_M.get(kind, 14.0) * WorldScale.PX_PER_M
	if destroyed:
		_draw_wreck(w)
		return
	match kind:
		"bunker": _draw_bunker(w)
		"radar": _draw_radar(w)
		"sam": _draw_sam(w)
		"fuel": _draw_fuel(w)
		_: _draw_tank(w)
	if show_marker:
		var top := -_height_px(w) - 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(-5, top - 7), Vector2(5, top - 7), Vector2(0, top)]),
				GameState.glow(Color(0.95, 0.2, 0.15)))


func _height_px(w: float) -> float:
	match kind:
		"radar": return w * 0.85
		"sam": return w * 0.6
		"fuel": return w * 0.4
		"bunker": return w * 0.35
	return w * 0.35


## Low concrete bunker with a dark firing slit and sandbags.
func _draw_bunker(w: float) -> void:
	var h := w * 0.35
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(Vector2(cos(a) * w * 0.5, sin(a) * h))
	draw_colored_polygon(pts, _concrete)
	draw_polyline(pts, _ink, 1.0)
	draw_rect(Rect2(-w * 0.18, -h * 0.62, w * 0.36, h * 0.16), _ink)
	for i in 6:
		var x := -w * 0.62 + i * w * 0.05
		draw_rect(Rect2(x, -4, w * 0.05, 4), _sand.darkened(0.1 * (i % 2)))
		draw_rect(Rect2(-x - w * 0.05, -4, w * 0.05, 4), _sand.darkened(0.1 * (i % 2)))


## Radar trailer with a mast and a dish.
func _draw_radar(w: float) -> void:
	draw_rect(Rect2(-w * 0.45, -w * 0.22, w * 0.9, w * 0.16), _olive)
	draw_rect(Rect2(-w * 0.45, -w * 0.22, w * 0.9, w * 0.16), _ink, false, 1.0)
	for x in [-w * 0.3, w * 0.3]:
		draw_circle(Vector2(x, -w * 0.05), w * 0.06, _ink)
	draw_rect(Rect2(-2, -w * 0.62, 4, w * 0.4), _olive_dark)
	var dish := PackedVector2Array([Vector2(-w * 0.3, -w * 0.85), Vector2(w * 0.05, -w * 0.62),
			Vector2(w * 0.25, -w * 0.6), Vector2(-w * 0.1, -w * 0.84)])
	draw_colored_polygon(dish, _concrete.lightened(0.15))
	draw_polyline(dish + PackedVector2Array([dish[0]]), _ink, 1.0)


## Missile launcher vehicle with three missiles angled up.
func _draw_sam(w: float) -> void:
	draw_rect(Rect2(-w * 0.5, -w * 0.18, w, w * 0.13), _olive)
	draw_rect(Rect2(-w * 0.5, -w * 0.18, w, w * 0.13), _ink, false, 1.0)
	draw_rect(Rect2(w * 0.25, -w * 0.3, w * 0.22, w * 0.13), _olive_dark)
	for i in 4:
		draw_circle(Vector2(-w * 0.4 + i * w * 0.25, -w * 0.05), w * 0.05, _ink)
	for i in 3:
		var base := Vector2(-w * 0.25 + i * w * 0.08, -w * 0.2 - i * 3.0)
		var tip := base + Vector2(w * 0.3, -w * 0.32)
		draw_line(base, tip, Color(0.85, 0.85, 0.8), 3.0)
		draw_line(tip, tip + (tip - base).normalized() * 3.0, Color(0.8, 0.25, 0.2), 3.0)


## Two round fuel tanks with a pipe.
func _draw_fuel(w: float) -> void:
	for cx in [-w * 0.24, w * 0.24]:
		var r := Rect2(cx - w * 0.2, -w * 0.4, w * 0.4, w * 0.4)
		draw_rect(r, Color(0.78, 0.76, 0.68))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0.6, 0.58, 0.52))
		draw_rect(r, _ink, false, 1.0)
	draw_rect(Rect2(-w * 0.04, -w * 0.1, w * 0.08, 2), _ink)


## Armoured vehicle: hull, turret and gun.
func _draw_tank(w: float) -> void:
	var hull := PackedVector2Array([Vector2(-w * 0.5, -w * 0.08), Vector2(-w * 0.42, -w * 0.25),
			Vector2(w * 0.45, -w * 0.25), Vector2(w * 0.5, -w * 0.08), Vector2(w * 0.4, 0), Vector2(-w * 0.4, 0)])
	draw_colored_polygon(hull, _olive)
	draw_polyline(hull + PackedVector2Array([hull[0]]), _ink, 1.0)
	draw_rect(Rect2(-w * 0.2, -w * 0.38, w * 0.36, w * 0.13), _olive_dark)
	draw_line(Vector2(w * 0.16, -w * 0.32), Vector2(w * 0.62, -w * 0.34), _olive_dark, 2.0)
	for i in 5:
		draw_circle(Vector2(-w * 0.32 + i * w * 0.16, -w * 0.05), w * 0.045, _ink)


## Blackened rubble and twisted bits.
func _draw_wreck(w: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x_m)
	var pts := PackedVector2Array([Vector2(-w * 0.55, 0)])
	for i in 7:
		pts.append(Vector2(-w * 0.45 + i * w * 0.15, -rng.randf_range(2.0, w * 0.18)))
	pts.append(Vector2(w * 0.55, 0))
	draw_colored_polygon(pts, Color(0.12, 0.11, 0.1))
	for i in 4:
		var a := Vector2(rng.randf_range(-w * 0.4, w * 0.4), -rng.randf_range(2.0, w * 0.12))
		draw_line(a, a + Vector2(rng.randf_range(-8, 8), -rng.randf_range(3, 9)), Color(0.3, 0.28, 0.25), 2.0)
	draw_rect(Rect2(-w * 0.7, -1, w * 1.4, 2), Color(0.2, 0.18, 0.15))
