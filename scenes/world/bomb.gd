class_name Bomb
extends Node2D
## A free-fall bomb after release: keeps the aircraft's speed, falls under
## gravity with a little air drag, noses over along its path, and goes off
## when it reaches the ground (`impacted`). The same fall model predicts the
## impact point for the aiming marker (predict_impact_x).
## Physics in metres (x along the route, y = height); drawn at 4 px/m.

signal impacted(x_m: float)

const PREDICT_STEP_S := 1.0 / 30.0
const PREDICT_MAX_S := 30.0

var pos_m := Vector2.ZERO
var vel_m := Vector2.ZERO
var drag := 0.0002
## Drawn size in world px (texture px x the aircraft's sprite_scale).
var length_px := 16.0
var diameter_px := 3.0


func _ready() -> void:
	_sync()


func _physics_process(delta: float) -> void:
	vel_m = step(vel_m, drag, delta)
	pos_m += vel_m * delta
	if pos_m.y <= 0.0:
		impacted.emit(pos_m.x)
		queue_free()
		return
	_sync()


func _sync() -> void:
	position = Vector2(pos_m.x, -pos_m.y) * WorldScale.PX_PER_M
	rotation = -atan2(vel_m.y, vel_m.x)


func _draw() -> void:
	draw_shape(self, Vector2.ZERO, length_px, diameter_px)


## Velocity after one step of the fall model.
static func step(v: Vector2, k: float, dt: float) -> Vector2:
	return v + (Vector2(0.0, -WorldScale.GRAVITY) - v * v.length() * k) * dt


## Where (x, metres) a bomb released at pos with velocity vel would hit the ground.
static func predict_impact_x(pos: Vector2, vel: Vector2, k: float) -> float:
	var p := pos
	var v := vel
	var t := 0.0
	while p.y > 0.0 and t < PREDICT_MAX_S:
		var prev := p
		v = step(v, k, PREDICT_STEP_S)
		p += v * PREDICT_STEP_S
		t += PREDICT_STEP_S
		if p.y <= 0.0:
			return lerpf(prev.x, p.x, prev.y / maxf(prev.y - p.y, 0.0001))
	return p.x


## Olive-drab low-drag bomb, nose pointing +x, centred on `c`: ogive nose with
## a yellow band (live bomb), body, tail cone and fins. Used for bombs on the
## pylons (aircraft.gd, texture px) and falling ones (world px).
static func draw_shape(ci: CanvasItem, c: Vector2, length: float, dia: float) -> void:
	var body := Color(0.34, 0.37, 0.25)
	var dark := Color(0.16, 0.17, 0.12)
	var l := length
	var r := dia * 0.5
	var outline := PackedVector2Array([
		c + Vector2(0.5 * l, 0), c + Vector2(0.38 * l, -r * 0.75), c + Vector2(0.26 * l, -r),
		c + Vector2(-0.3 * l, -r), c + Vector2(-0.4 * l, -r * 0.55),
		c + Vector2(-0.4 * l, r * 0.55), c + Vector2(-0.3 * l, r),
		c + Vector2(0.26 * l, r), c + Vector2(0.38 * l, r * 0.75),
	])
	# Fins (behind the body).
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34 * l, 0), c + Vector2(-0.5 * l, -r * 1.7),
			c + Vector2(-0.5 * l, r * 1.7)]), dark)
	ci.draw_colored_polygon(outline, body)
	ci.draw_polyline(outline + PackedVector2Array([outline[0]]), dark, maxf(dia * 0.12, 0.5))
	# Yellow band behind the nose, and a light top edge.
	ci.draw_rect(Rect2(c + Vector2(0.2 * l, -r * 0.95), Vector2(0.05 * l, dia * 0.95)), Color(0.85, 0.7, 0.2))
	ci.draw_line(c + Vector2(-0.28 * l, -r * 0.55), c + Vector2(0.24 * l, -r * 0.55), Color(0.5, 0.53, 0.38), maxf(dia * 0.12, 0.5))
