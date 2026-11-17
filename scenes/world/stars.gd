extends Control
## Night sky: a fixed field of small stars that gently twinkle, brighter and
## denser toward the top of the screen. Lives in the Sky CanvasLayer (not
## darkened by the night tint), added by the flight scene at night only.

@export var count := 170
@export var random_seed := 7

var _stars: Array = []   # [position (0..1), size, phase]
var _time := 0.0
var _redraw_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in count:
		# Bias toward the top: fewer stars near the horizon glow.
		var y := pow(rng.randf(), 1.6) * 0.8
		_stars.append([Vector2(rng.randf(), y), 1.0 if rng.randf() < 0.85 else 2.0, rng.randf() * TAU])


func _process(delta: float) -> void:
	_time += delta
	# Twinkling doesn't need every frame.
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.1
		queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	for s in _stars:
		var p: Vector2 = s[0] * view
		var tw := 0.65 + 0.35 * sin(_time * 1.7 + s[2])
		var fade := 1.0 - clampf((s[0].y - 0.5) / 0.3, 0.0, 1.0) * 0.6
		var col := Color(1.0, 0.97, 0.9, tw * fade)
		var sz: float = s[1]
		draw_rect(Rect2(p.round(), Vector2(sz, sz)), col)
		if sz > 1.0:
			draw_circle(p + Vector2(1, 1), 2.5, Color(0.8, 0.85, 1.0, 0.12 * tw))
