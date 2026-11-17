extends Node2D
## Placeholder crash effect: a quick orange fireball, flying debris specks,
## then a column of dark smoke that keeps rising. Drawn in code.

@export var fireball_time_s := 0.6
@export var smoke_puffs := 14

var _t := 0.0
var _debris: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in 10:
		_debris.append([Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-90, -30)), _rng.randf_range(1, 2)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Fireball.
	if _t < fireball_time_s:
		var f := _t / fireball_time_s
		draw_circle(Vector2(0, -6), 8 + 18 * f, Color(1.0, 0.55, 0.1, 1.0 - f))
		draw_circle(Vector2(0, -6), 4 + 10 * f, Color(1.0, 0.9, 0.4, 1.0 - f))
	# Debris arcs.
	for d in _debris:
		var v: Vector2 = d[0]
		var p := v * _t + Vector2(0, 0.5 * 160.0 * _t * _t)
		if p.y < 0.0:
			draw_rect(Rect2(p, Vector2(d[1], d[1])), Color(0.15, 0.15, 0.15))
	# Rising smoke column (puffs drift up and right, grow and fade, then repeat).
	for i in smoke_puffs:
		var age := fmod(_t * 0.6 + float(i) / smoke_puffs, 1.0)
		if _t < 0.2:
			continue
		var pos := Vector2(4 + age * 26 + sin(i * 1.7) * 4, -6 - age * 90)
		var col := Color(0.18, 0.18, 0.2, 0.7 * (1.0 - age))
		draw_circle(pos.round(), 4 + age * 10, col)
