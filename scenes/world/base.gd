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
## Child layer for the animated bits (see _process).
var _anim: Node2D
## Shelter positions (px) for the current data.
var _shelters: Array = []

@export_group("Apron")
## Hardened aircraft shelter size (metres) and parked aircraft size scale.
@export var shelter_width_m := 17.0
@export var shelter_height_m := 8.0
@export var shelter_color := Color(0.66, 0.64, 0.58)
@export var shelter_inside := Color(0.16, 0.16, 0.18)
## Parked aircraft keep this far (metres) from a squadron board or trophy.
@export var apron_clear_m := 14.0

@export_group("Trophies and trees")
## Trophy displays are drawn this much larger than true size (owner: clearly
## visible, but not overpowering).
@export var trophy_scale := 1.5
@export var banyan_height_m := 17.0
@export var banyan_width_m := 34.0


func _ready() -> void:
	_font = ThemeDB.fallback_font if not ProjectSettings.get_setting("gui/theme/custom_font") \
			else load(ProjectSettings.get_setting("gui/theme/custom_font"))
	_anim = Node2D.new()
	add_child(_anim)
	_anim.draw.connect(_draw_anim)
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
	# Squadron boards and trophy plinths keep a clear gap in the line of aircraft.
	var keep_clear: Array = []
	for bx in data.squadron_board_x_m:
		keep_clear.append(bx)
	for tx in data.trophy_x_m:
		keep_clear.append(tx)
	var x := data.apron_from_m
	var slot := 0
	while x < data.apron_to_m and (data.parked_max <= 0 or slot < data.parked_max):
		var in_shelter := data.shelter_every > 0 and slot % data.shelter_every == 0
		var step := data.parked_spacing_m
		if in_shelter:
			step = shelter_width_m + 3.0
		var blocked := false
		for cx_m in keep_clear:
			if x + step > cx_m - apron_clear_m and x < cx_m + apron_clear_m:
				blocked = true
		if blocked:
			x += 3.0
			continue
		var tex: Texture2D = data.parked_aircraft[slot % data.parked_aircraft.size()]
		var size := tex.get_size() * 0.25
		if in_shelter:
			_shelters.append(m(x + step * 0.5))
		var cx := m(x + step * 0.5)
		items.append([tex, Rect2(cx - size.x * 0.5, -size.y, size.x, size.y),
				Color(0.72, 0.72, 0.74) if in_shelter else Color.WHITE])
		x += step
		slot += 1
	_parked.set_items(items)


## Only the small moving parts (windsock, tower beacon) are redrawn each
## frame, on their own child layer; the rest of the base is drawn once.
func _process(delta: float) -> void:
	_time += delta
	if _anim:
		_anim.queue_redraw()


func _draw_anim() -> void:
	if data == null:
		return
	_draw_windsock(m(windsock_x_m))
	if _night() and fmod(_time, 1.5) < 0.9:
		var cab_y := -s(data.tower_height_m) - s(5.0)
		var bp := Vector2(m(tower_x_m), cab_y - 19)
		_anim.draw_circle(bp, 6, _lamp(Color(1, 0.15, 0.1, 0.15)))
		_anim.draw_circle(bp, 2.5, _lamp(Color(1, 0.2, 0.15)))


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
	for i in data.banyan_x_m.size():
		_draw_banyan(m(data.banyan_x_m[i]), i)
	_draw_sign(m(sign_x_m))
	_draw_tower(m(tower_x_m))
	var x := m(admin_x_m)
	_draw_admin(x)
	x += s(data.admin_block_length_m) + m(20.0)
	for i in data.hangar_count:
		_draw_hangar(x, i + 1)
		x += s(hangar_width_m) + m(hangar_gap_m)
	for sx in _shelters:
		_draw_shelter(sx)
	for i in data.squadron_boards.size():
		if i < data.squadron_board_x_m.size():
			_draw_squadron_board(m(data.squadron_board_x_m[i]), data.squadron_boards[i])
	for i in data.trophies.size():
		if i < data.trophy_x_m.size():
			_draw_trophy(m(data.trophy_x_m[i]), data.trophies[i])
	if not data.welcome_sign.is_empty():
		for wx in data.welcome_sign_x_m:
			if data.welcome_sign_style == 1:
				_draw_welcome_monument(m(wx))
			else:
				_draw_welcome(m(wx))


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


## Squadron board: coloured face (BaseData: blue at Masroor, red at Mushaf) with a gold frame, squadron on the first line,
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
	draw_rect(r, data.squadron_board_trim)
	draw_rect(r.grow(-2), data.squadron_board_color)
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


## Gate-style welcome monument (PAF Base Mushaf): a dark-blue stone slab on a
## low plinth, gold border with key-pattern corners, a round crest at the top,
## a gold calligraphy line (stands in for the Urdu motto) and gold lettering.
func _draw_welcome_monument(cx: float) -> void:
	var l1 := data.welcome_sign[0]
	var l2 := data.welcome_sign[1] if data.welcome_sign.size() > 1 else ""
	var w1 := _font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var w2 := _font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := maxf(w1, w2) + 28.0
	var night := _night()
	var gold := _lamp(Color(0.95, 0.8, 0.45)) if night else Color(0.93, 0.78, 0.42)
	var navy := Color(0.1, 0.16, 0.3)
	var stone := Color(0.45, 0.44, 0.42)
	# Plinth (wider, stepped), then the slab, slightly narrower at the top.
	draw_rect(Rect2(cx - w * 0.5 - 6, -6, w + 12, 6), stone)
	draw_rect(Rect2(cx - w * 0.5 - 6, -6, w + 12, 1), stone.lightened(0.2))
	var top := -60.0
	var bottom := -6.0
	var slab := PackedVector2Array([Vector2(cx - w * 0.5, bottom), Vector2(cx + w * 0.5, bottom),
			Vector2(cx + w * 0.5 - 3, top), Vector2(cx - w * 0.5 + 3, top)])
	draw_colored_polygon(slab, outline_color)
	var face := PackedVector2Array([Vector2(cx - w * 0.5 + 1, bottom), Vector2(cx + w * 0.5 - 1, bottom),
			Vector2(cx + w * 0.5 - 4, top + 1), Vector2(cx - w * 0.5 + 4, top + 1)])
	draw_colored_polygon(face, navy)
	draw_rect(Rect2(cx - w * 0.5 + 4, top + 1, w - 8, 2), navy.lightened(0.12))   # top edge catches the light
	# Gold frame with key-pattern corners.
	var fr := Rect2(cx - w * 0.5 + 7, top + 6, w - 14, bottom - top - 10)
	draw_rect(fr, gold, false, 1.0)
	for c in [[fr.position, 1, 1], [Vector2(fr.end.x, fr.position.y), -1, 1],
			[Vector2(fr.position.x, fr.end.y), 1, -1], [fr.end, -1, -1]]:
		_key_corner(c[0], c[1], c[2], gold)
	# Crest on the top edge: blue disc, gold ring, white centre, star above.
	var crest := Vector2(cx, top + 4)
	draw_circle(crest, 8.0, gold)
	draw_circle(crest, 6.5, Color(0.12, 0.3, 0.62))
	draw_circle(crest, 3.5, _lamp(Color(0.92, 0.94, 0.95)) if night else Color(0.92, 0.94, 0.95))
	draw_circle(crest, 1.5, Color(0.1, 0.4, 0.22))
	_star(crest + Vector2(0, -11), 3.0, gold)
	# Calligraphy line: short gold strokes and dots of varying height.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lx := cx - w1 * 0.4
	while lx < cx + w1 * 0.4:
		var sw := rng.randi_range(2, 6)
		draw_rect(Rect2(lx, top + 17, sw, 1), gold)
		if rng.randf() < 0.5:
			draw_rect(Rect2(lx + rng.randi_range(0, sw), top + 14 - rng.randi_range(0, 2), 1, 3), gold)
		if rng.randf() < 0.3:
			draw_rect(Rect2(lx + 1, top + 19, 1, 1), gold)
		lx += sw + rng.randi_range(1, 3)
	draw_string(_font, Vector2(cx - w1 * 0.5, top + 36), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
	draw_string(_font, Vector2(cx - w2 * 0.5, top + 47), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gold)
	if night:
		# Ground floodlights in front of the monument.
		for fx in [cx - w * 0.3, cx + w * 0.3]:
			draw_rect(Rect2(fx - 2, -3, 4, 3), Color(0.2, 0.2, 0.2))
			draw_circle(Vector2(fx, -4), 1.5, _lamp(Color(1.0, 0.9, 0.6)))


## One key-pattern (meander) corner of the gold frame; sx/sy point inward.
func _key_corner(p: Vector2, sx: int, sy: int, col: Color) -> void:
	var pts := [Vector2(0, 0), Vector2(8, 0), Vector2(8, 6), Vector2(3, 6), Vector2(3, 3), Vector2(6, 3)]
	for i in pts.size() - 1:
		var a: Vector2 = p + Vector2(pts[i].x * sx, pts[i].y * sy)
		var b: Vector2 = p + Vector2(pts[i + 1].x * sx, pts[i + 1].y * sy)
		draw_line(a, b, col, 1.0)
	for i in pts.size() - 1:
		var a: Vector2 = p + Vector2(pts[i].y * sx, pts[i].x * sy)
		var b: Vector2 = p + Vector2(pts[i + 1].y * sx, pts[i + 1].x * sy)
		draw_line(a, b, col, 1.0)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## Captured-aircraft display: the tail section of an Indian Air Force jet on a
## black stone plinth with its name in gold (like the MiG-21 at Mushaf).
## The tail faces left (fin leading edge forward), as in the real display.
func _draw_trophy(cx: float, kind: String) -> void:
	var label := "IAF MIG-21 BISON" if kind == "mig21" else "IAF SU-30MKI"
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := tw + 14.0
	var night := _night()
	# Plinth: a black slab whose top slopes up toward the back.
	var plinth := PackedVector2Array([Vector2(cx - w * 0.5, 0), Vector2(cx + w * 0.5, 0),
			Vector2(cx + w * 0.5, -17), Vector2(cx - w * 0.5, -13)])
	draw_colored_polygon(plinth, Color(0.1, 0.1, 0.11))
	draw_line(Vector2(cx - w * 0.5, -13), Vector2(cx + w * 0.5, -17), Color(0.32, 0.32, 0.34), 1.0)
	var gold := _lamp(Color(0.95, 0.8, 0.45)) if night else Color(0.92, 0.78, 0.42)
	draw_string(_font, Vector2(cx - tw * 0.5, -3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gold)
	# Airframe on two short posts, drawn trophy_scale times true size.
	var sc := trophy_scale
	var base := Vector2(cx, -16)
	draw_rect(Rect2(cx - 10 * sc, base.y - 3 * sc, 2, 3 * sc), outline_color)
	draw_rect(Rect2(cx + 8 * sc, base.y - 3 * sc, 2, 3 * sc), outline_color)
	draw_set_transform(base + Vector2(0, -3 * sc), 0.0, Vector2(sc, sc))
	if kind == "mig21":
		_mig21_tail()
	else:
		_su30_tail()
	draw_set_transform(Vector2.ZERO)
	if night:
		draw_circle(Vector2(cx - w * 0.5 + 3, -1), 1.5, _lamp(Color(1.0, 0.9, 0.6)))


## MiG-21 tail section (true-size px, y = 0 at the bottom of the fuselage):
## fuselage cylinder, swept fin with a green tip and the Indian fin flash.
func _mig21_tail() -> void:
	var skin := _flood(Color(0.66, 0.68, 0.7))
	var shade := _flood(Color(0.5, 0.52, 0.55))
	var dark := _flood(Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(-22, -8, 42, 8), shade)
	draw_rect(Rect2(-22, -8, 42, 5), skin)
	draw_rect(Rect2(-22, -8, 42, 1), skin.lightened(0.15))
	draw_rect(Rect2(20, -7, 3, 7), dark)                     # nozzle ring
	draw_rect(Rect2(-22, -8, 1, 8), dark)                    # cut edge
	var fin := PackedVector2Array([Vector2(-14, -8), Vector2(6, -31), Vector2(13, -31),
			Vector2(17, -8)])
	draw_colored_polygon(fin, skin)
	draw_polyline(PackedVector2Array([Vector2(-14, -8), Vector2(6, -31), Vector2(13, -31), Vector2(17, -8)]), dark, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(5, -30), Vector2(6, -31), Vector2(13, -31), Vector2(13.3, -28),
			Vector2(7.7, -28)]), _flood(Color(0.45, 0.6, 0.35)))       # green fin tip
	draw_line(Vector2(9, -27), Vector2(15, -10), shade, 1.0)  # rudder hinge line
	_fin_flash(Vector2(-1, -22), Vector2(9, 6))


## Su-30MKI tail section: longer fuselage with two nozzles, twin fins (the far
## one darker, set a little forward) and a tailplane stub; grey-blue camouflage.
func _su30_tail() -> void:
	var skin := _flood(Color(0.56, 0.62, 0.68))
	var patch := _flood(Color(0.44, 0.5, 0.58))
	var shade := _flood(Color(0.4, 0.45, 0.5))
	var dark := _flood(Color(0.18, 0.19, 0.22))
	var far_fin := PackedVector2Array([Vector2(-16, -9), Vector2(-1, -35), Vector2(5, -35), Vector2(9, -9)])
	draw_colored_polygon(far_fin, shade)
	draw_polyline(far_fin, dark, 1.0)
	draw_rect(Rect2(-26, -9, 50, 9), shade)
	draw_rect(Rect2(-26, -9, 50, 6), skin)
	draw_rect(Rect2(-10, -8, 14, 4), patch)
	draw_rect(Rect2(-26, -9, 1, 9), dark)
	draw_rect(Rect2(24, -8, 4, 4), dark)                      # nozzles
	draw_rect(Rect2(24, -4, 4, 4), dark.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(12, -5), Vector2(30, -3), Vector2(30, -1), Vector2(12, -2)]), shade)
	var fin := PackedVector2Array([Vector2(-10, -9), Vector2(6, -37), Vector2(12, -37), Vector2(17, -9)])
	draw_colored_polygon(fin, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -20), Vector2(6, -32), Vector2(10, -24), Vector2(4, -16)]), patch)
	draw_polyline(PackedVector2Array([Vector2(-10, -9), Vector2(6, -37), Vector2(12, -37), Vector2(17, -9)]), dark, 1.0)
	draw_rect(Rect2(7, -40, 1, 3), dark)                      # fin-tip antenna
	_fin_flash(Vector2(4, -27), Vector2(8, 5))


## Indian fin flash: green, white, saffron vertical bands (as on the display).
func _fin_flash(p: Vector2, size: Vector2) -> void:
	var bw := size.x / 3.0
	draw_rect(Rect2(p.x, p.y, bw, size.y), _flood(Color(0.1, 0.5, 0.2)))
	draw_rect(Rect2(p.x + bw, p.y, bw, size.y), _flood(Color(0.95, 0.95, 0.93)))
	draw_rect(Rect2(p.x + bw * 2.0, p.y, bw, size.y), _flood(Color(0.95, 0.55, 0.15)))


## Trophy colours: floodlit at night (bright through the night tint, a bit warm).
func _flood(c: Color) -> Color:
	return _lamp(c * Color(0.75, 0.72, 0.65)) if _night() else c


## Banyan tree: a short, very thick trunk, many aerial prop-roots hanging from
## the branches to the ground, and a huge, wide, low dome of dark foliage.
func _draw_banyan(cx: float, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + index * 37
	var h := m(banyan_height_m) * rng.randf_range(0.85, 1.1)
	var w := m(banyan_width_m) * rng.randf_range(0.85, 1.15)
	var leaf := data.tree_color
	var bark := Color(0.4, 0.33, 0.26)
	var root := Color(0.48, 0.42, 0.35)
	var canopy_y := -h * 0.62
	# Prop-roots: thin, some down to the ground (thicker), some still hanging.
	for k in 14:
		var rx := cx + rng.randf_range(-w * 0.42, w * 0.42)
		if absf(rx - cx) < 8:
			continue
		var reach := 0.0 if rng.randf() < 0.6 else rng.randf_range(-h * 0.35, -h * 0.15)
		var thick := 2.0 if reach == 0.0 and rng.randf() < 0.5 else 1.0
		draw_rect(Rect2(rx, canopy_y + h * 0.12, thick, reach - canopy_y - h * 0.12), root)
	# Trunk with a flared, buttressed foot and two big limbs.
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 12, 0), Vector2(cx + 12, 0), Vector2(cx + 6, -10),
			Vector2(cx + 5, canopy_y + 8), Vector2(cx - 5, canopy_y + 8), Vector2(cx - 6, -10)]), bark)
	draw_line(Vector2(cx - 3, canopy_y + 14), Vector2(cx - w * 0.3, canopy_y + 4), bark, 3.0)
	draw_line(Vector2(cx + 3, canopy_y + 12), Vector2(cx + w * 0.32, canopy_y + 6), bark, 3.0)
	draw_line(Vector2(cx - 4, -2), Vector2(cx - 4, -14), bark.darkened(0.2), 1.0)
	# Canopy: dark underside, then overlapping blobs, lighter on top.
	_ellipse(Vector2(cx, canopy_y + 2), Vector2(w * 0.5, h * 0.16), leaf.darkened(0.3))
	for k in 11:
		var t := float(k) / 10.0
		var bx := cx + (t - 0.5) * w * 0.86
		var arch := sin(t * PI)
		var by := canopy_y - h * 0.12 * arch - rng.randf_range(0, 4)
		var r := Vector2(w * rng.randf_range(0.11, 0.15), h * rng.randf_range(0.14, 0.2) * (0.7 + 0.5 * arch))
		_ellipse(Vector2(bx, by), r, leaf.darkened(rng.randf_range(0.0, 0.15)))
	for k in 6:
		var bx := cx + rng.randf_range(-w * 0.3, w * 0.3)
		var by := canopy_y - h * 0.22 - rng.randf_range(0, h * 0.08)
		_ellipse(Vector2(bx, by), Vector2(w * 0.09, h * 0.08), leaf.lightened(rng.randf_range(0.06, 0.16)))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


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
	_anim.draw_rect(Rect2(x - 1, top.y, 2, -top.y), Color(0.5, 0.5, 0.52))
	# Sock streams to the left (wind from the right, i.e. a headwind for takeoff).
	var seg := 4
	for i in seg:
		var wobble := sin(_time * 6.0 + i) * (i * 0.7)
		var p := top + Vector2(-2 - i * 4, 1 + i * 0.6 + wobble)
		var col := Color(1.0, 0.45, 0.1) if i % 2 == 0 else Color.WHITE
		_anim.draw_rect(Rect2(p.x - 4, p.y, 4, 4 - i * 0.5), col)
