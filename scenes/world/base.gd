extends Node2D
## A PAF base, built from BaseData: runway (child node), name board, windsock,
## control tower, long admin block, hangars, and an apron of parked front-view
## aircraft (some in hardened shelters) with squadron boards, plus an optional
## welcome board before the threshold. All standing on the ground line behind
## the runway (scenery only). Node origin = runway start (threshold) on the ground.
## Placeholder pixel art drawn in code at final size (4 px per metre).

@export var data: BaseData:
	set(v):
		data = v
		if is_node_ready():
			_apply()

@export_group("Layout (metres from runway start)")
@export var sign_x_m := -70.0
@export var windsock_x_m := 25.0
@export var tower_x_m := 110.0
@export var admin_x_m := 150.0
@export var hangar_gap_m := 8.0
@export var hangar_width_m := 36.0
@export var hangar_height_m := 12.0

## Draw buildings this many times their true size (aircraft sprites are ~2-4x scale).
@export var building_scale := 1.0

@export_group("Colours")
@export var window_color := Color(0.24, 0.3, 0.38)
@export var window_lit_color := Color(0.95, 0.88, 0.55)
@export var glass_color := Color(0.42, 0.72, 0.78)
@export var outline_color := Color(0.18, 0.18, 0.2)

@onready var runway: Node2D = $Runway

var _time := 0.0
var _font: Font
var _parked: Node2D
## Shelter positions (px) for the current data.
var _shelters: Array = []

@export_group("Apron")
## Hardened aircraft shelter size (metres) and parked aircraft size scale.
@export var shelter_width_m := 17.0
@export var shelter_height_m := 8.0
@export var shelter_color := Color(0.66, 0.64, 0.58)
@export var shelter_inside := Color(0.16, 0.16, 0.18)


func _ready() -> void:
	_font = ThemeDB.fallback_font if not ProjectSettings.get_setting("gui/theme/custom_font") \
			else load(ProjectSettings.get_setting("gui/theme/custom_font"))
	_apply()


func _apply() -> void:
	if data:
		runway.length_m = data.runway_length_m
		_layout_apron()
	queue_redraw()


## Places parked aircraft along the apron: one per slot, every shelter_every-th
## slot in a hardened shelter, leaving room around the squadron boards.
func _layout_apron() -> void:
	if _parked == null:
		_parked = preload("res://scenes/world/parked_aircraft.gd").new()
		add_child(_parked)
	_shelters.clear()
	var items: Array = []
	if data.parked_aircraft.is_empty():
		_parked.set_items(items)
		return
	var x := data.apron_from_m
	var slot := 0
	while x < data.apron_to_m and (data.parked_max <= 0 or slot < data.parked_max):
		var blocked := false
		for bx in data.squadron_board_x_m:
			if absf(x - bx) < 20.0:
				blocked = true
		if blocked:
			x += 6.0
			continue
		var tex: Texture2D = data.parked_aircraft[slot % data.parked_aircraft.size()]
		var size := tex.get_size() * 0.25
		var in_shelter := data.shelter_every > 0 and slot % data.shelter_every == 0
		var step := data.parked_spacing_m
		if in_shelter:
			step = shelter_width_m + 3.0
			_shelters.append(m(x + step * 0.5))
		var cx := m(x + step * 0.5)
		items.append([tex, Rect2(cx - size.x * 0.5, -size.y, size.x, size.y),
				Color(0.72, 0.72, 0.74) if in_shelter else Color.WHITE])
		x += step
		slot += 1
	_parked.set_items(items)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()   # windsock flutter


## Night: lit windows and lights glow (GameState.glow beats the night tint).
func _night() -> bool:
	var gs := get_node_or_null("/root/GameState")
	return gs != null and gs.night


func _lamp(c: Color) -> Color:
	var gs := get_node_or_null("/root/GameState")
	return gs.glow(c) if gs != null else c


func m(x: float) -> float:
	return x * WorldScale.PX_PER_M


## Building sizes: metres scaled by building_scale (buildings are drawn larger
## than true scale to match the ~2x aircraft sprites).
func s(x: float) -> float:
	return x * WorldScale.PX_PER_M * building_scale


func _draw() -> void:
	if data == null:
		return
	_draw_sign(m(sign_x_m))
	_draw_tower(m(tower_x_m))
	var x := m(admin_x_m)
	_draw_admin(x)
	x += s(data.admin_block_length_m) + m(20.0)
	for i in data.hangar_count:
		_draw_hangar(x, i + 1)
		x += s(hangar_width_m) + m(hangar_gap_m)
	_draw_windsock(m(windsock_x_m))
	for sx in _shelters:
		_draw_shelter(sx)
	for i in data.squadron_boards.size():
		if i < data.squadron_board_x_m.size():
			_draw_squadron_board(m(data.squadron_board_x_m[i]), data.squadron_boards[i])
	if not data.welcome_sign.is_empty():
		_draw_welcome(m(data.welcome_sign_x_m))


## Hardened aircraft shelter seen from the front: a low concrete arch with a
## dark opening, earth berms on both sides, and a lamp over the door at night.
func _draw_shelter(cx: float) -> void:
	var w := m(shelter_width_m)
	var h := m(shelter_height_m)
	var berm := data.hill_color.darkened(0.1)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5 - 10, 0), Vector2(cx - w * 0.5, -h * 0.75), Vector2(cx - w * 0.5, 0)]), berm)
	draw_colored_polygon(PackedVector2Array([Vector2(cx + w * 0.5, 0), Vector2(cx + w * 0.5, -h * 0.75), Vector2(cx + w * 0.5 + 10, 0)]), berm)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		outer.append(Vector2(cx - cos(a) * w * 0.5, -sin(a) * h))
		inner.append(Vector2(cx - cos(a) * (w * 0.5 - 4), -sin(a) * (h - 4)))
	draw_colored_polygon(outer, shelter_color)
	draw_polyline(outer, outline_color, 1.0)
	draw_colored_polygon(inner, shelter_inside)
	if _night():
		draw_circle(Vector2(cx, -h + 2), 2.0, _lamp(Color(1.0, 0.85, 0.55)))


## Squadron board: deep blue with a gold frame, squadron on the first line,
## its name large in gold on the second. Text: "LINE 1|LINE 2". Mounted high on
## tall posts so a jet stopped in front of it doesn't hide it.
func _draw_squadron_board(cx: float, text: String) -> void:
	var lines := text.split("|")
	var l1 := lines[0]
	var l2 := lines[1] if lines.size() > 1 else ""
	var w1 := _font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w2 := _font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var w := maxf(w1, w2) + 12.0
	var r := Rect2(cx - w * 0.5, -80, w, 30)
	draw_rect(Rect2(r.position.x + 6, r.end.y, 3, -r.end.y), outline_color)
	draw_rect(Rect2(r.end.x - 9, r.end.y, 3, -r.end.y), outline_color)
	draw_rect(r, Color(0.85, 0.68, 0.25))
	draw_rect(r.grow(-2), Color(0.08, 0.16, 0.38))
	var gold := _lamp(Color(1.0, 0.82, 0.35)) if _night() else Color(1.0, 0.82, 0.35)
	var white := _lamp(Color.WHITE) if _night() else Color.WHITE
	draw_string(_font, Vector2(cx - w1 * 0.5, r.position.y + 11), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, white)
	draw_string(_font, Vector2(cx - w2 * 0.5, r.position.y + 26), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)


## Big welcome board before the runway: PAF green with a white frame.
func _draw_welcome(cx: float) -> void:
	var l1 := data.welcome_sign[0]
	var l2 := data.welcome_sign[1] if data.welcome_sign.size() > 1 else ""
	var w1 := _font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var w2 := _font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := maxf(w1, w2) + 16.0
	var r := Rect2(cx - w * 0.5, -48, w, 32)
	for px in [r.position.x + 10, cx - 1.5, r.end.x - 13]:
		draw_rect(Rect2(px, r.end.y, 3, 16), outline_color)
	draw_rect(r, Color.WHITE)
	draw_rect(r.grow(-2), Color(0.02, 0.36, 0.2))
	var white := _lamp(Color.WHITE) if _night() else Color.WHITE
	var gold := _lamp(Color(1.0, 0.85, 0.4)) if _night() else Color(1.0, 0.85, 0.4)
	draw_string(_font, Vector2(cx - w1 * 0.5, r.position.y + 15), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
	draw_string(_font, Vector2(cx - w2 * 0.5, r.position.y + 27), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gold)


func _box(r: Rect2, fill: Color) -> void:
	draw_rect(r, outline_color)
	draw_rect(r.grow(-1), fill)


func _draw_admin(x: float) -> void:
	var floor_h := s(4.5)
	var w := s(data.admin_block_length_m)
	var h := floor_h * data.admin_block_floors + s(2.0)
	_box(Rect2(x, -h, w, h), data.building_color)
	draw_rect(Rect2(x, -h, w, 3), data.roof_color)
	# Window grid; a few windows are lit.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.short_name)
	for f in data.admin_block_floors:
		var wy := -h + s(2.0) + f * floor_h + 3
		var wx := x + 5.0
		while wx < x + w - 8:
			var lit := rng.randf() < (0.4 if _night() else 0.15)
			var lit_col := _lamp(window_lit_color * Color(0.9, 0.85, 0.7)) if _night() else window_lit_color
			draw_rect(Rect2(wx, wy, 5, 8), lit_col if lit else window_color)
			wx += 9.0
	# Entrance.
	draw_rect(Rect2(x + w * 0.5 - 8, -14, 16, 14), window_color)
	draw_rect(Rect2(x + w * 0.5 - 12, -16, 24, 2), data.roof_color)


func _draw_tower(x: float) -> void:
	var h := s(data.tower_height_m)
	var shaft_w := s(4.0)
	var cab_w := s(9.0)
	_box(Rect2(x - shaft_w * 0.5, -h, shaft_w, h), data.building_color)
	for y in range(int(-h + 30), -6, 14):
		draw_rect(Rect2(x - 2, y, 4, 6), window_color)
	# Cab: wider glass room on top, dark roof, antenna.
	var cab_y := -h - s(5.0)
	_box(Rect2(x - cab_w * 0.5, cab_y, cab_w, s(5.0)), data.building_color)
	var cab_glass := _lamp(Color(0.75, 0.9, 0.85)) if _night() else glass_color
	draw_rect(Rect2(x - cab_w * 0.5 + 2, cab_y + 4, cab_w - 4, s(5.0) - 9), cab_glass)
	for gx in range(int(x - cab_w * 0.5 + 8), int(x + cab_w * 0.5 - 2), 8):
		draw_rect(Rect2(gx, cab_y + 4, 1, s(5.0) - 9), outline_color)
	draw_rect(Rect2(x - cab_w * 0.5 - 3, cab_y - 3, cab_w + 6, 4), data.roof_color)
	draw_rect(Rect2(x - 1, cab_y - 18, 2, 15), outline_color)
	draw_rect(Rect2(x - 1, cab_y - 20, 2, 2), Color(1, 0.2, 0.2))
	if _night() and fmod(_time, 1.5) < 0.9:
		var bp := Vector2(x, cab_y - 19)
		draw_circle(bp, 6, _lamp(Color(1, 0.15, 0.1, 0.15)))
		draw_circle(bp, 2.5, _lamp(Color(1, 0.2, 0.15)))


func _draw_hangar(x: float, number: int) -> void:
	var w := s(hangar_width_m)
	var h := s(hangar_height_m)
	# Body plus a low arched roof.
	_box(Rect2(x, -h, w, h), data.hangar_color)
	var arch := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		arch.append(Vector2(x + t * w, -h - sin(t * PI) * 12.0))
	arch.append(Vector2(x + w, -h + 1))
	arch.append(Vector2(x, -h + 1))
	draw_colored_polygon(arch, data.roof_color)
	draw_polyline(arch.slice(0, 17), outline_color, 1.0)
	# Big sliding doors.
	var door := Rect2(x + 8, -h + 10, w - 16, h - 10)
	draw_rect(door, data.hangar_color.darkened(0.25))
	var dx := door.position.x + door.size.x / 6.0
	while dx < door.end.x - 1:
		draw_rect(Rect2(dx, door.position.y, 1, door.size.y), outline_color)
		dx += door.size.x / 6.0
	draw_string(_font, Vector2(x + w * 0.5 - 4, -h + 8), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, outline_color)


func _draw_sign(x: float) -> void:
	var text := data.display_name.to_upper()
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var r := Rect2(x - tw - 8, -26, tw + 8, 13)
	draw_rect(Rect2(r.position.x + 4, r.end.y, 2, 13), outline_color)
	draw_rect(Rect2(r.end.x - 6, r.end.y, 2, 13), outline_color)
	_box(r, Color(0.08, 0.35, 0.2))
	draw_string(_font, Vector2(r.position.x + 4, r.end.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_windsock(x: float) -> void:
	var top := Vector2(x, -s(7.0))
	draw_rect(Rect2(x - 1, top.y, 2, -top.y), Color(0.5, 0.5, 0.52))
	# Sock streams to the left (wind from the right, i.e. a headwind for takeoff).
	var seg := 4
	for i in seg:
		var wobble := sin(_time * 6.0 + i) * (i * 0.7)
		var p := top + Vector2(-2 - i * 4, 1 + i * 0.6 + wobble)
		var col := Color(1.0, 0.45, 0.1) if i % 2 == 0 else Color.WHITE
		draw_rect(Rect2(p.x - 4, p.y, 4, 4 - i * 0.5), col)
