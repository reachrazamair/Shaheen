extends Node2D
## One background parallax layer (mountains, hills, trees or clouds), drawn as
## seamless repeating placeholder pixel art. Local y = 0 is the ground line.
## factor: 0 = fixed to the screen (infinitely far), 1 = moves with the world.
## Vertically the layer is anchored so that at the starting camera height its
## y = 0 lines up with the real ground; when the plane climbs, far layers sink
## slowly (like a distant horizon) while near layers drop away quickly.
## Colours are set each frame by the flight scene (theme blend between bases).

enum Kind { MOUNTAINS, HILLS, TREES, CLOUDS }

@export var kind: Kind = Kind.HILLS
@export var camera: Camera2D
@export var factor := Vector2(0.2, 0.2)
@export var repeat_px := 1280.0
@export var random_seed := 1
## Peak height in px for MOUNTAINS/HILLS (scaled by height_scale).
@export var amplitude_px := 60.0
@export var color := Color.WHITE
@export var height_scale := 1.0
## CLOUDS: how many per tile, and the height band they float in (px above ground).
@export var cloud_count := 32
@export var cloud_min_px := 120.0
@export var cloud_max_px := 2400.0

var _shapes: Array = []      # Array of [PackedVector2Array, shade] for one tile
var _ref_cam_y := 0.0


func _ready() -> void:
	_build_tile()
	await get_tree().process_frame
	if camera:
		_ref_cam_y = camera.get_screen_center_position().y


func _process(_delta: float) -> void:
	if camera == null:
		return
	var c := camera.get_screen_center_position()
	position = Vector2(c.x * (1.0 - factor.x), (c.y - _ref_cam_y) * (1.0 - factor.y))
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var c := camera.get_screen_center_position()
	var view_w := get_viewport_rect().size.x
	var left := c.x - view_w * 0.5 - position.x
	var first := floori(left / repeat_px)
	var tiles := ceili(view_w / repeat_px) + 1
	for k in range(first, first + tiles + 1):
		draw_set_transform(Vector2(k * repeat_px, 0), 0.0, Vector2(1.0, height_scale if kind != Kind.CLOUDS else 1.0))
		for s in _shapes:
			draw_colored_polygon(s[0], _shade(s[1]))
	draw_set_transform(Vector2.ZERO)


func _shade(amount: float) -> Color:
	if kind == Kind.CLOUDS:
		return Color(1, 1, 1).darkened(amount)
	return color.darkened(amount) if amount >= 0.0 else color.lightened(-amount)


func _build_tile() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	_shapes.clear()
	match kind:
		Kind.MOUNTAINS, Kind.HILLS:
			_build_ridge(rng, 0.0)
			if kind == Kind.MOUNTAINS:
				_build_ridge(rng, -0.12, 0.6)   # lighter, lower range in front for depth
		Kind.TREES:
			_build_trees(rng)
		Kind.CLOUDS:
			_build_clouds(rng)


## A seamless ridge: sum of sines whose periods divide the tile width.
func _build_ridge(rng: RandomNumberGenerator, shade: float, scale := 1.0) -> void:
	var waves := []
	for i in 4:
		waves.append([rng.randi_range(1 + i * 2, 3 + i * 3), rng.randf() * TAU, 1.0 / (i + 1)])
	var pts := PackedVector2Array()
	var step := 8.0
	var x := 0.0
	while x <= repeat_px + 0.1:
		var h := 0.0
		for wv in waves:
			h += sin(x / repeat_px * TAU * wv[0] + wv[1]) * wv[2]
		h = (h * 0.5 + 1.0) * 0.5 * amplitude_px * scale
		pts.append(Vector2(x, -roundf(maxf(h, 2.0))))
		x += step
	pts.append(Vector2(repeat_px, 2000))
	pts.append(Vector2(0, 2000))
	_shapes.append([pts, shade])


func _build_trees(rng: RandomNumberGenerator) -> void:
	_shapes.append([PackedVector2Array([Vector2(0, -3), Vector2(repeat_px, -3),
			Vector2(repeat_px, 2000), Vector2(0, 2000)]), 0.1])
	var x := 0.0
	while x < repeat_px - 12:
		var r := rng.randf_range(4.0, 9.0)
		var cy := -3.0 - r * rng.randf_range(0.6, 1.0)
		_shapes.append([_circle(Vector2(x + r, cy), r), rng.randf_range(-0.05, 0.15)])
		x += r * rng.randf_range(1.0, 2.2)


func _build_clouds(rng: RandomNumberGenerator) -> void:
	for i in cloud_count:
		var base := Vector2(rng.randf_range(0, repeat_px - 80), -rng.randf_range(cloud_min_px, cloud_max_px))
		var puffs := rng.randi_range(3, 5)
		var w := 0.0
		for j in puffs:
			var r := rng.randf_range(7.0, 15.0)
			_shapes.append([_circle(base + Vector2(w, -r * 0.6), r), 0.0])
			w += r * 1.2
		# Flat, slightly shaded underside.
		_shapes.append([PackedVector2Array([base + Vector2(-6, -4), base + Vector2(w + 4, -4),
				base + Vector2(w, 2), base + Vector2(-2, 2)]), 0.08])


func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(8, int(r * 1.5))
	for i in n:
		var a := TAU * i / n
		pts.append((c + Vector2(cos(a), sin(a)) * r).round())
	return pts
