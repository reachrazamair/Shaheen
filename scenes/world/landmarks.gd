extends Node2D
## Background landmarks near a base (scenery only, nothing to collide with):
## a parallax layer between the hills and the clouds, so the city slides past
## slower than the ground and reads as being in the distance.
##
## Each landmark is placed by `offset_m`: where the CAMERA is (metres from
## the base's runway threshold) when the landmark is centred on screen.
## Negative = passed on the way in (seen during the approach).
## Kinds come from BaseData.landmarks. Karachi (PAF Base Masroor):
##   sea, port_cranes, teen_talwar, bahria_icon, mazar_e_quaid, masjid_e_tooba, skyline.

@export var camera: Camera2D
@export var factor := Vector2(0.3, 0.35)
## Haze: landmark colours are blended this much toward the haze colour.
@export var haze := 0.25
@export var haze_color := Color(0.85, 0.88, 0.9)
## Landmarks sit this many px above the ground line so the tree layer in
## front doesn't hide their lower part (they're far away, near the horizon).
@export var base_lift_px := 18.0

## [kind, offset_m]
const LAYOUT := {
	"sea": [["sea", -1300.0]],
	"port_cranes": [["port_cranes", -1150.0]],
	"teen_talwar": [["teen_talwar", -800.0]],
	"bahria_icon": [["bahria_icon", -550.0]],
	"mazar_e_quaid": [["mazar_e_quaid", -150.0]],
	"masjid_e_tooba": [["masjid_e_tooba", 450.0]],
	"skyline": [["skyline", -950.0], ["skyline", -650.0], ["skyline", -350.0], ["skyline", 150.0], ["skyline", 750.0]],
}

var _items: Array = []   # [kind, local x px, seed]
var _ref_cam_y := 0.0
var _time := 0.0


## kinds: BaseData.landmarks; base_x_m: the base's runway threshold (route metres).
func setup(kinds: PackedStringArray, base_x_m: float) -> void:
	_items.clear()
	var i := 0
	for k in kinds:
		for entry in LAYOUT.get(k, []):
			var cam_px: float = (base_x_m + entry[1]) * WorldScale.PX_PER_M
			_items.append([entry[0], cam_px * factor.x, 31 + i * 17])
			i += 1
	queue_redraw()


func _ready() -> void:
	await get_tree().process_frame
	if camera:
		_ref_cam_y = camera.get_screen_center_position().y


func _process(delta: float) -> void:
	if camera == null or _items.is_empty():
		return
	_time += delta
	var c := camera.get_screen_center_position()
	position = Vector2(c.x * (1.0 - factor.x), (c.y - _ref_cam_y) * (1.0 - factor.y) - base_lift_px)
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var c := camera.get_screen_center_position()
	var view_w := get_viewport_rect().size.x
	var left := c.x - view_w * 0.5 - position.x - 200.0
	var right := left + view_w + 400.0
	# Sea first (it lies behind everything else).
	for it in _items:
		if it[0] == "sea" and it[1] > left - 600 and it[1] < right + 600:
			_sea(it[1])
	for it in _items:
		var x: float = it[1]
		if it[0] == "sea" or x < left or x > right:
			continue
		match it[0]:
			"port_cranes": _port(x)
			"teen_talwar": _teen_talwar(x)
			"bahria_icon": _bahria_icon(x)
			"mazar_e_quaid": _mazar(x)
			"masjid_e_tooba": _tooba(x)
			"skyline": _skyline(x, it[2])


# --- Helpers ---

func _night() -> bool:
	return GameState.night


func _c(col: Color) -> Color:
	return col.lerp(haze_color, haze)


func _lamp(col: Color) -> Color:
	return GameState.glow(col)


func _poly(points: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), col)


# --- Landmarks (drawn with the base on y = 0, growing up) ---

## Arabian Sea: a band of water at the horizon with a few ships.
func _sea(x: float) -> void:
	var w := 900.0
	draw_rect(Rect2(x - w * 0.5, -7, w, 7), _c(Color(0.32, 0.5, 0.62)))
	draw_rect(Rect2(x - w * 0.5, -7, w, 1), _c(Color(0.6, 0.75, 0.82)))
	for k in 3:
		var sx := x - 300 + k * 260
		draw_rect(Rect2(sx, -11, 26, 4), _c(Color(0.35, 0.32, 0.3)))
		draw_rect(Rect2(sx + 16, -15, 6, 4), _c(Color(0.85, 0.85, 0.82)))
		for b in 3:
			draw_rect(Rect2(sx + 2 + b * 4, -14, 3, 3), _c([Color(0.7, 0.25, 0.2), Color(0.25, 0.4, 0.6), Color(0.8, 0.6, 0.2)][b]))


## Karachi port: gantry cranes over stacked containers.
func _port(x: float) -> void:
	var cols := [Color(0.75, 0.3, 0.22), Color(0.25, 0.42, 0.62), Color(0.8, 0.62, 0.2), Color(0.35, 0.55, 0.35)]
	for row in 3:
		for k in 12:
			draw_rect(Rect2(x - 70 + k * 11, -4 - row * 4, 10, 3), _c(cols[(k + row * 3) % cols.size()]))
	for k in 3:
		var cx := x - 55 + k * 50
		var col := _c(Color(0.85, 0.35, 0.2) if k % 2 == 0 else Color(0.9, 0.85, 0.3))
		draw_rect(Rect2(cx - 10, -46, 2, 46), col)
		draw_rect(Rect2(cx + 8, -46, 2, 46), col)
		draw_rect(Rect2(cx - 16, -48, 40, 3), col)        # boom
		draw_rect(Rect2(cx - 3, -45, 6, 5), col)          # trolley
		if _night():
			draw_circle(Vector2(cx + 22, -49), 2, _lamp(Color(1, 0.2, 0.15)))


## Teen Talwar (Clifton): three tall white swords on a round base.
func _teen_talwar(x: float) -> void:
	var white := _c(Color(0.93, 0.93, 0.9))
	var shade := _c(Color(0.75, 0.76, 0.75))
	draw_rect(Rect2(x - 14, -5, 28, 5), shade)
	for k in 3:
		var sx := x - 7 + k * 7
		var h := 42.0 + (4.0 if k == 1 else 0.0)
		_poly([Vector2(sx - 2, -5), Vector2(sx + 2, -5), Vector2(sx + 1.5, -h), Vector2(sx, -h - 4), Vector2(sx - 1.5, -h)], white)
		draw_rect(Rect2(sx - 3, -h * 0.25, 6, 1), shade)   # hilt guard


## Bahria Icon Tower: Karachi's tallest, a slim glass tower with a slanted top
## and its shorter twin beside it.
func _bahria_icon(x: float) -> void:
	var glass := _c(Color(0.42, 0.52, 0.62))
	var edge := _c(Color(0.62, 0.7, 0.78))
	_poly([Vector2(x - 9, 0), Vector2(x + 9, 0), Vector2(x + 9, -112), Vector2(x - 9, -122)], glass)
	draw_rect(Rect2(x - 9, -112, 1, 112), edge)
	draw_rect(Rect2(x + 1, -125, 1, 8), edge)                 # mast
	_poly([Vector2(x + 12, 0), Vector2(x + 24, 0), Vector2(x + 24, -62), Vector2(x + 12, -68)], _c(Color(0.5, 0.58, 0.66)))
	for fy in range(-108, -4, 6):
		var lit := _night() and (int(fy * 7 + x) % 5 != 0)
		draw_rect(Rect2(x - 7, fy, 14, 1), _lamp(Color(1.0, 0.85, 0.55)) if lit else edge)
	if _night() and fmod(_time, 1.4) < 0.8:
		draw_circle(Vector2(x + 1.5, -126), 2.5, _lamp(Color(1, 0.15, 0.1)))


## Mazar-e-Quaid: white marble cube with tall pointed arches and a big dome,
## on a terraced platform. Floodlit at night.
func _mazar(x: float) -> void:
	var marble := _c(Color(0.95, 0.95, 0.92))
	var shadow := _c(Color(0.78, 0.8, 0.8))
	var dark := _c(Color(0.45, 0.5, 0.52))
	if _night():
		marble = _lamp(Color(0.9, 0.9, 0.86))
		shadow = _lamp(Color(0.62, 0.65, 0.66))
	draw_rect(Rect2(x - 44, -4, 88, 4), shadow)           # platform
	draw_rect(Rect2(x - 36, -7, 72, 3), shadow)
	draw_rect(Rect2(x - 24, -37, 48, 30), marble)         # cube
	draw_rect(Rect2(x - 24, -37, 48, 2), shadow)
	# Tall pointed arch with its dark screen.
	_poly([Vector2(x - 10, -7), Vector2(x + 10, -7), Vector2(x + 10, -24), Vector2(x, -33), Vector2(x - 10, -24)], shadow)
	_poly([Vector2(x - 7, -7), Vector2(x + 7, -7), Vector2(x + 7, -23), Vector2(x, -29), Vector2(x - 7, -23)], dark)
	# Dome: a raised, slightly pointed dome on a short drum.
	draw_rect(Rect2(x - 15, -42, 30, 5), marble)
	var dome := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16.0
		dome.append(Vector2(x - cos(a) * 16.0, -42.0 - sin(a) * 18.0 - (3.0 * sin(a) * sin(a) if k == 8 else 0.0)))
	draw_colored_polygon(dome, marble)
	draw_rect(Rect2(x - 1, -66, 2, 6), shadow)            # finial


## Masjid-e-Tooba: one wide, low dome and a single tall minaret.
func _tooba(x: float) -> void:
	var white := _c(Color(0.92, 0.92, 0.9))
	var shade := _c(Color(0.75, 0.77, 0.77))
	draw_rect(Rect2(x - 34, -10, 68, 10), shade)
	var dome := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16.0
		dome.append(Vector2(x - cos(a) * 32.0, -10.0 - sin(a) * 16.0))
	draw_colored_polygon(dome, white)
	draw_rect(Rect2(x + 44, -64, 5, 64), white)
	draw_rect(Rect2(x + 43, -50, 7, 2), shade)
	_poly([Vector2(x + 43, -64), Vector2(x + 50, -64), Vector2(x + 46.5, -72)], shade)
	if _night():
		draw_circle(Vector2(x + 46.5, -73), 1.5, _lamp(Color(0.4, 1.0, 0.5)))


## Filler city blocks: a few mid-rise buildings of different heights.
func _skyline(x: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bx := x - 60.0
	for k in 6:
		var w := rng.randf_range(10, 20)
		var h := rng.randf_range(14, 48)
		var shade := rng.randf_range(0.7, 0.9)
		var col := _c(Color(shade, shade * 0.97, shade * 0.9))
		draw_rect(Rect2(bx, -h, w, h), col)
		for fy in range(int(-h + 4), -3, 5):
			for wx in range(int(bx + 2), int(bx + w - 2), 4):
				var lit := _night() and rng.randf() < 0.45
				draw_rect(Rect2(wx, fy, 2, 2), _lamp(Color(1.0, 0.85, 0.5)) if lit else col.darkened(0.25))
		bx += w + rng.randf_range(2, 8)
