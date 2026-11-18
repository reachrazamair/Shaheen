extends Node2D
## One background parallax layer (mountains, hills, trees or clouds), drawn as
## seamless repeating placeholder pixel art. Local y = 0 is the ground line.
## factor: 0 = fixed to the screen (infinitely far), 1 = moves with the world.
## Vertically the layer is anchored so that at the starting camera height its
## y = 0 lines up with the real ground; when the plane climbs, far layers sink
## slowly (like a distant horizon) while near layers drop away quickly.
## Colours are set each frame by the flight scene (theme blend between bases).
## Camera zoom (air-to-ground attack run): the layer gets its own zoom
## k = lerp(1, camera zoom, factor.x), so far layers barely change while near
## ones shrink with the world, and it is scaled/placed so that on screen
## x = centre + p.x * k - camera.x * zoom * factor.x and its ground line keeps
## its height (at zoom 1 this is exactly the old parallax).

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
## The same shapes cut into triangles once: [triangle vertices (3 per triangle), shade].
## The whole band is then sent as ONE triangle array per redraw (one draw call)
## instead of one call per cloud puff / tree.
var _tris: Array = []
## What the current drawing was made for. The band is only redrawn when one of
## these changes (moving it for parallax is free); redrawing every frame was
## the main cause of low frame rates, especially in the browser.
var _drawn_first := -999999
var _drawn_color := Color(-1, -1, -1)
var _drawn_height := -1.0
var _ref_cam_y := 0.0
var _drawn_tiles := -1


func _ready() -> void:
	_build_tile()
	await get_tree().process_frame
	if camera:
		_ref_cam_y = camera.get_screen_center_position().y


func _process(_delta: float) -> void:
	if camera == null:
		return
	var c := camera.get_screen_center_position()
	var z := camera.zoom.x
	var k := _band_zoom()
	var cam_y := _ref_cam_y + (c.y * z - _ref_cam_y) * factor.y
	position = Vector2(c.x * (1.0 - factor.x), c.y - cam_y / z)
	scale = Vector2(k / z, k / z)
	var first := _first_tile(c)
	if first != _drawn_first or _tile_count() != _drawn_tiles or absf(height_scale - _drawn_height) > 0.005 or absf(color.r - _drawn_color.r) + absf(color.g - _drawn_color.g) + absf(color.b - _drawn_color.b) > 0.012:
		queue_redraw()


## This layer's own zoom: 1 for far layers, the camera's for factor 1.
func _band_zoom() -> float:
	return lerpf(1.0, camera.zoom.x, factor.x) if camera else 1.0


## First tile in view (layer-local), and how many tiles cover the screen.
func _first_tile(c: Vector2) -> int:
	var left := (c.x * camera.zoom.x * factor.x - get_viewport_rect().size.x * 0.5) / _band_zoom()
	return floori(left / repeat_px)


func _tile_count() -> int:
	return ceili(get_viewport_rect().size.x / _band_zoom() / repeat_px) + 1


func _draw() -> void:
	if camera == null:
		return
	var c := camera.get_screen_center_position()
	var first := _first_tile(c)
	var tiles := _tile_count()
	_drawn_first = first
	_drawn_tiles = tiles
	_drawn_color = color
	_drawn_height = height_scale
	var sy := height_scale if kind != Kind.CLOUDS else 1.0
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for k in range(first, first + tiles + 1):
		var ox := k * repeat_px
		for tr in _tris:
			var col := _shade(tr[1])
			for v in tr[0]:
				points.append(Vector2(v.x + ox, v.y * sy))
				colors.append(col)
	var indices := PackedInt32Array()
	indices.resize(points.size())
	for i in points.size():
		indices[i] = i
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)


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
	_tris.clear()
	for s in _shapes:
		var poly: PackedVector2Array = s[0]
		var idx := Geometry2D.triangulate_polygon(poly)
		var verts := PackedVector2Array()
		for i in idx:
			verts.append(poly[i])
		_tris.append([verts, s[1]])


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
