extends SceneTree
## Generates assets/sprites/super_mushshak.png from the owner's reference art
## (docs/reference/super_mushshak_livery_reference.png).
##
## Every shape below is traced in the REFERENCE image's pixel coordinates
## (807x356 image, plane nose to the right) and scaled down by SCALE into the
## sprite, then rasterised at pixel centres and given a 1 px dark outline.
## To adjust the look, compare a point with the reference image and nudge it.
##
## Landing gear (legs + wheels) and the propeller are NOT in the sprite: the
## Aircraft script draws and animates them at positions in AircraftData.
##
## Run from the project root:
##   godot_console --headless --path . -s tools/make_mushshak_sprite.gd [-- preview.png]

const OUT := "res://assets/sprites/super_mushshak.png"
## Reference pixels per sprite pixel.
const SCALE := 6.0
## Reference-image point that maps to sprite pixel (1, 1) (leaves room for the outline).
const ORIGIN := Vector2(40, 35)
const W := 127
const H := 40
const PREVIEW_SCALE := 6

const OUTLINE := Color(0.1, 0.11, 0.14)
const WHITE := Color(0.97, 0.97, 0.97)
const SHADE := Color(0.8, 0.82, 0.86)
const SHADE_DARK := Color(0.66, 0.68, 0.73)
const RED := Color(0.86, 0.13, 0.13)
const RED_DARK := Color(0.62, 0.08, 0.1)
const BLUE := Color(0.24, 0.42, 0.85)
const GLASS := Color(0.62, 0.84, 0.95)
const GLASS_HI := Color(0.88, 0.97, 1.0)
const GLASS_DARK := Color(0.4, 0.62, 0.78)
const WINDOW := Color(0.22, 0.32, 0.48)
const FLAG_GREEN := Color(0.0, 0.4, 0.2)
const SUIT := Color(0.3, 0.4, 0.24)
const HELMET := Color(0.38, 0.46, 0.3)
const GREY := Color(0.55, 0.57, 0.6)
const BLACK := Color(0.08, 0.08, 0.09)
const NAV_GREEN := Color(0.2, 0.9, 0.3)

var img: Image


func _init() -> void:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Fuselage + fin + tailplane as one silhouette.
	var body := _ref([[48, 42], [150, 50], [153, 62], [215, 140], [300, 138], [385, 133],
			[505, 132], [640, 150], [700, 160], [745, 170], [765, 180], [760, 196],
			[720, 222], [640, 236], [540, 246], [470, 250], [400, 245], [300, 229],
			[200, 216], [130, 209], [100, 205]])
	_fill(body, WHITE)
	# Belly shading: bottom two rows of the body.
	for y in H:
		for x in W:
			if _in(body, x, y) and not _in(body, x, y + 1):
				_px(x, y, SHADE_DARK)
			elif _in(body, x, y) and not _in(body, x, y + 2):
				_px(x, y, SHADE)

	# Tailplane on top of the fin: red top, darker red below.
	_fill(_ref([[48, 42], [150, 50], [152, 57], [52, 54]]), RED, body)
	_fill(_ref([[52, 54], [152, 57], [153, 62], [60, 64]]), RED_DARK, body)

	# Rudder bands: red down the trailing edge, then blue, sweeping into the cheat lines.
	_fill(_ref([[52, 64], [78, 66], [96, 140], [72, 146]]), RED, body)
	_fill(_ref([[72, 146], [96, 140], [112, 182], [86, 190]]), BLUE, body)

	# Cheat lines: red over blue from the rudder to the nose.
	_polyline_in(body, [[86, 168], [200, 196], [350, 206], [520, 210], [725, 213]], RED)
	_polyline_in(body, [[92, 180], [200, 203], [350, 213], [520, 217], [720, 220]], BLUE)

	# Pakistan flag on the fin: white hoist, green field, crescent and star.
	_rect_ref(Rect2(116, 103, 8, 34), WHITE)
	_rect_ref(Rect2(124, 103, 38, 34), FLAG_GREEN)
	for p in [Vector2i(17, 13), Vector2i(17, 14), Vector2i(18, 15), Vector2i(19, 13)]:
		_px(p.x, p.y, WHITE)

	# "385" in big black digits.
	_digits(Vector2i(50, 21), "385")

	# Rear cabin window.
	_rect_ref(Rect2(440, 158, 42, 30), WINDOW)
	var wp := _t(Vector2(442, 160))
	_px(int(wp.x), int(wp.y), GLASS)

	# High wing, seen slightly from below: red top surface, white underside.
	var wing := _ref([[372, 138], [468, 112], [518, 116], [510, 144], [392, 158]])
	_fill(wing, RED)
	_fill(_ref([[392, 150], [512, 136], [512, 146], [392, 160]]), WHITE, wing)
	_frame(wing)
	var nav := _t(Vector2(500, 126))
	_px(int(nav.x), int(nav.y), NAV_GREEN)
	# Wing strut down to the fuselage, by the main gear.
	_line(_t(Vector2(490, 150)), _t(Vector2(478, 246)), GREY)

	# Bubble canopy with the pilot (green helmet and flight suit).
	var canopy := _ref([[506, 136], [522, 112], [560, 104], [600, 108], [632, 130],
			[646, 152], [520, 152]])
	_fill(canopy, GLASS)
	_fill(_ref([[528, 134], [578, 134], [580, 152], [526, 152]]), SUIT, canopy)
	_fill(_ref([[540, 116], [566, 116], [568, 136], [538, 136]]), HELMET, canopy)
	_fill(_ref([[600, 112], [628, 132], [640, 150], [612, 150]]), GLASS_DARK, canopy)
	for p in [Vector2(530, 118), Vector2(578, 108)]:
		var q := _t(p)
		_px(int(q.x), int(q.y), GLASS_HI)
	_frame(canopy)

	# Nose: small blue "PAC" mark and a cowling panel line; white spinner.
	_rect_ref(Rect2(638, 160, 22, 5), BLUE)
	_line(_t(Vector2(690, 162)), _t(Vector2(684, 226)), SHADE)
	_fill(_ref([[745, 168], [770, 175], [784, 185], [770, 195], [745, 201]]), WHITE)
	var tip := _t(Vector2(782, 185))
	_px(int(tip.x), int(tip.y), GREY)
	var ex := _t(Vector2(700, 236))
	_px(int(ex.x), int(ex.y), OUTLINE)   # exhaust

	_outline()
	var err := img.save_png(OUT)
	print("saved ", OUT, " ", img.get_size(), " err=", err)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var big := img.duplicate()
		big.resize(W * PREVIEW_SCALE, H * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
		big.save_png(args[0])
	quit()


# --- Helpers: reference coords -> sprite pixels ---

func _t(p: Vector2) -> Vector2:
	return (p - ORIGIN) / SCALE + Vector2(1, 1)


func _ref(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_t(Vector2(p[0], p[1])))
	return out


func _in(poly: PackedVector2Array, x: int, y: int) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly)


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


func _fill(poly: PackedVector2Array, c: Color, clip := PackedVector2Array()) -> void:
	for y in H:
		for x in W:
			if _in(poly, x, y) and (clip.is_empty() or _in(clip, x, y)):
				_px(x, y, c)


func _rect_ref(r: Rect2, c: Color) -> void:
	var a := _t(r.position)
	var b := _t(r.end)
	for y in range(roundi(a.y), maxi(roundi(b.y), roundi(a.y) + 1)):
		for x in range(roundi(a.x), maxi(roundi(b.x), roundi(a.x) + 1)):
			_px(x, y, c)


func _line(a: Vector2, b: Vector2, c: Color, clip := PackedVector2Array()) -> void:
	var n := int(ceilf(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		var x := int(floorf(p.x))
		var y := int(floorf(p.y))
		if clip.is_empty() or _in(clip, x, y):
			_px(x, y, c)


func _polyline_in(clip: PackedVector2Array, pts: Array, c: Color) -> void:
	for i in pts.size() - 1:
		_line(_t(Vector2(pts[i][0], pts[i][1])), _t(Vector2(pts[i + 1][0], pts[i + 1][1])), c, clip)


## Dark frame on the inside edge of a shape (separates wing/canopy from the body).
func _frame(poly: PackedVector2Array) -> void:
	var edge := []
	for y in H:
		for x in W:
			if not _in(poly, x, y):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _in(poly, x + d.x, y + d.y):
					edge.append(Vector2i(x, y))
					break
	for e in edge:
		_px(e.x, e.y, OUTLINE)


## 3x5 pixel digits.
func _digits(at: Vector2i, s: String) -> void:
	var font := {
		"3": ["111", "001", "111", "001", "111"],
		"8": ["111", "101", "111", "101", "111"],
		"5": ["111", "100", "111", "001", "111"],
	}
	var x := at.x
	for ch in s:
		var rows: Array = font[ch]
		for r in rows.size():
			for c in 3:
				if rows[r][c] == "1":
					_px(x + c, at.y + r, BLACK)
		x += 4


## 1 px dark outline around the silhouette.
func _outline() -> void:
	var edge := []
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and img.get_pixel(q.x, q.y).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixel(p.x, p.y, OUTLINE)
