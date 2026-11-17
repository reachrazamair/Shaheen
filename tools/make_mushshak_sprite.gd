extends SceneTree
## Generates assets/sprites/super_mushshak.png: a side-view pixel-art Super
## Mushshak in PAF trainer colours (white, red and blue cheat lines, red wing
## top and fin band, Pakistan flag on the fin). Shapes are polygons on a
## 64x22 pixel grid, rasterised at pixel centres, then given a 1 px dark
## outline. Landing gear, propeller and flaps are NOT in the sprite: the
## Aircraft script draws and animates them (positions are in AircraftData).
##
## Run from the project root:
##   godot_console --headless --path . -s tools/make_mushshak_sprite.gd
## The PNG can later be hand-edited or replaced in a pixel-art editor.

const W := 64
const H := 22
const OUT := "res://assets/sprites/super_mushshak.png"
const PREVIEW_SCALE := 8

const OUTLINE := Color(0.11, 0.12, 0.15)
const WHITE := Color(0.97, 0.97, 0.97)
const SHADE := Color(0.78, 0.8, 0.84)
const RED := Color(0.85, 0.12, 0.12)
const BLUE := Color(0.2, 0.36, 0.78)
const GLASS := Color(0.5, 0.74, 0.9)
const GLASS_HI := Color(0.82, 0.93, 1.0)
const GREEN := Color(0.0, 0.4, 0.2)
const HELMET := Color(0.32, 0.4, 0.25)
const GREY := Color(0.55, 0.57, 0.6)

var grid := {}   # Vector2i -> Color


func _init() -> void:
	var fuselage := _poly([[3, 10], [19, 8.5], [23, 6], [33, 6], [47, 8], [55, 10], [60, 12], [62, 14],
			[60, 17], [52, 19], [32, 19], [22, 16], [3, 13]])
	var stab := _poly([[0, 10], [13, 10], [13, 12], [0, 12]])
	var fin := _poly([[1, 11], [2, 1], [7, 1], [18, 10]])
	var fin_band := _poly([[5, 1], [7.5, 1], [18.5, 10.5], [14, 10.5]])
	var wing := _poly([[21, 4], [37, 3], [41, 4], [39, 6], [21, 6]])
	var canopy := _poly([[30, 9], [34, 5], [44, 5], [50, 10]])
	var spinner := _poly([[60, 11.5], [64, 14], [60, 16.5]])

	_fill(fuselage, WHITE)
	# Shade the belly (pixels whose lower neighbour is outside the fuselage).
	for p in grid.keys():
		if not _inside(fuselage, p + Vector2i(0, 1)) or not _inside(fuselage, p + Vector2i(0, 2)):
			grid[p] = SHADE
	_line_in(fuselage, Vector2(4, 12), Vector2(60, 14), RED)
	_line_in(fuselage, Vector2(4, 13), Vector2(60, 15), BLUE)
	_fill(stab, SHADE)
	_fill(fin, WHITE)
	_fill(fin_band, RED, fin)
	# Pakistan flag on the fin: white hoist band, green field, white crescent and star.
	for y in range(3, 7):
		grid[Vector2i(3, y)] = WHITE
		for x in range(4, 8):
			grid[Vector2i(x, y)] = GREEN
	for p in [Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 4)]:
		grid[p] = WHITE
	_fill(canopy, GLASS)
	for p in [Vector2i(36, 6), Vector2i(35, 7), Vector2i(45, 6), Vector2i(46, 7)]:
		grid[p] = GLASS_HI
	for p in [Vector2i(37, 6), Vector2i(38, 6), Vector2i(37, 7), Vector2i(38, 7),
			Vector2i(42, 6), Vector2i(43, 6), Vector2i(42, 7), Vector2i(43, 7)]:
		grid[p] = HELMET            # instructor and student helmets
	for y in range(5, 10):
		grid[Vector2i(40, y)] = OUTLINE   # canopy frame
	_fill(wing, WHITE)
	for p in grid.keys():
		if _inside(wing, p) and p.y <= 4:
			grid[p] = RED                 # red wing top, as on the real trainer
	_fill(spinner, WHITE)
	grid[Vector2i(63, 14)] = GREY
	grid[Vector2i(55, 17)] = OUTLINE      # exhaust

	# 1 px outline around the whole silhouette, on a canvas with a 1 px margin.
	var img := Image.create(W + 2, H + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in grid:
		img.set_pixel(p.x + 1, p.y + 1, grid[p])
	var outline := []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() \
						and img.get_pixel(q.x, q.y).a > 0.0:
					outline.append(Vector2i(x, y))
					break
	for p in outline:
		img.set_pixel(p.x, p.y, OUTLINE)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites"))
	var err := img.save_png(OUT)
	print("saved ", OUT, " ", img.get_size(), " err=", err)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():   # optional enlarged preview: -- <path.png>
		var big := img.duplicate()
		big.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
		big.save_png(args[0])
	quit()


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


func _inside(poly: PackedVector2Array, p: Vector2i) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(p) + Vector2(0.5, 0.5), poly)


func _fill(poly: PackedVector2Array, col: Color, clip := PackedVector2Array()) -> void:
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			if _inside(poly, p) and (clip.is_empty() or _inside(clip, p)):
				grid[p] = col


func _line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		grid[Vector2i(roundi(p.x), roundi(p.y))] = col


func _line_in(clip: PackedVector2Array, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		var q := Vector2i(roundi(p.x), roundi(p.y))
		if _inside(clip, q):
			grid[q] = col
