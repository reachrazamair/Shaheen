class_name Bomb
extends Node2D
## A free-fall bomb after release: keeps the aircraft's speed, falls under
## gravity with a little air drag, noses over along its path, and goes off
## when it reaches the ground (`impacted`). The same fall model predicts the
## impact point for the aiming marker (predict_impact_x).
## Physics in metres (x along the route, y = height); drawn at 4 px/m.
## Guided bombs (guide_x set) steer their forward speed, within guide_accel,
## so their predicted impact point moves onto guide_x.

signal impacted(x_m: float)

const PREDICT_STEP_S := 1.0 / 30.0
const PREDICT_MAX_S := 30.0

var pos_m := Vector2.ZERO
var vel_m := Vector2.ZERO
var drag := 0.0002
## The weapon's art, drawn centred, nose along the flight path, at draw_scale
## (world px per texture px).
var texture: Texture2D
var draw_scale := 0.25
## Guided: ground x (m) to steer onto; NAN = unguided.
var guide_x := NAN
var guide_accel := 15.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sync()


func _physics_process(delta: float) -> void:
	if not is_nan(guide_x):
		var hit := predict_impact(pos_m, vel_m, drag)
		var need := (guide_x - hit.x) / maxf(hit.y, 0.3)   # extra forward speed needed
		vel_m.x += clampf(need, -guide_accel * delta, guide_accel * delta)
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
	if texture:
		var sz := texture.get_size() * draw_scale
		draw_texture_rect(texture, Rect2(-sz * 0.5, sz), false)


## Velocity after one step of the fall model.
static func step(v: Vector2, k: float, dt: float) -> Vector2:
	return v + (Vector2(0.0, -WorldScale.GRAVITY) - v * v.length() * k) * dt


## Where (x, metres) a bomb released at pos with velocity vel would hit the ground.
static func predict_impact_x(pos: Vector2, vel: Vector2, k: float) -> float:
	return predict_impact(pos, vel, k).x


## Impact x (m) and seconds until impact, for a bomb at pos with velocity vel.
static func predict_impact(pos: Vector2, vel: Vector2, k: float) -> Vector2:
	var p := pos
	var v := vel
	var t := 0.0
	while p.y > 0.0 and t < PREDICT_MAX_S:
		var prev := p
		v = step(v, k, PREDICT_STEP_S)
		p += v * PREDICT_STEP_S
		t += PREDICT_STEP_S
		if p.y <= 0.0:
			var f := prev.y / maxf(prev.y - p.y, 0.0001)
			return Vector2(lerpf(prev.x, p.x, f), t - PREDICT_STEP_S * (1.0 - f))
	return Vector2(p.x, t)
