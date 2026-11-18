class_name BombSight
extends Control
## Guided-bomb sight (F-16s), shown in the radar's place (top centre) during
## the target run; the HUD swaps the radar back once the landing base appears.
## In side view a bomb's impact point is usually far off screen (it keeps the
## jet's speed while it falls), so this screen shows a zoomed stretch of
## ground centred on where a bomb released NOW would land: the cross is the
## impact point, the bracket around it is how far a guided bomb can steer,
## targets slide in from the right as the jet flies on, white bars show where
## falling bombs will hit. Target inside the bracket = IN RANGE: press Space.
## Missile (F-16D, AGM-88 HARM): the screen shows the ground ahead of the jet
## instead (jet symbol on the left), the bracket is the missile's range band,
## and IN RANGE - FIRE! when a target is inside it.

var strike: StrikeMission

## Metres of ground shown each side of the impact point.
@export var range_m := 900.0
@export var glass_color := Color(0.03, 0.07, 0.04)
@export var frame_color := Color(0.22, 0.24, 0.23)
@export var frame_light := Color(0.4, 0.43, 0.41)
@export var ink_color := Color(0.45, 1.0, 0.45)
@export var target_color := Color(1.0, 0.45, 0.3)
@export var in_range_color := Color(1.0, 0.85, 0.3)

var _font: Font
var _time := 0.0


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shown while airborne on the target run with bombs left (or still falling).
func wanted() -> bool:
	if strike == null or strike.aircraft == null or strike.is_revealed:
		return false
	var a := strike.aircraft
	return a.data.bomb_guided and not a.crashed and not a.on_ground \
			and (a.bombs_left > 0 or strike.bombs_in_air > 0)


func _process(delta: float) -> void:
	_time += delta
	visible = wanted()
	if visible:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, frame_color)
	draw_rect(r.grow(-1), frame_light)
	draw_rect(r.grow(-2), frame_color)
	var sr := r.grow(-5)
	draw_rect(sr, glass_color)
	var a := strike.aircraft
	var d := a.data
	var missile := d.weapon_is_missile
	# Bombs: centred on the impact point. Missile: from just behind the jet to past max range.
	var centre_x := a.pos_m.x + d.missile_range_max_m * 0.5 if missile else strike.impact_x
	var span := d.missile_range_max_m * 0.5 + 500.0 if missile else range_m
	var ground_y := sr.end.y - 7.0
	var half_w := sr.size.x * 0.5 - 3.0
	var mid := sr.position.x + sr.size.x * 0.5
	var to_x := func(m: float) -> float: return mid + (m - centre_x) / span * half_w
	draw_rect(Rect2(sr.position.x + 2, ground_y, sr.size.x - 4, 1), Color(ink_color, 0.6))
	# Tick every 100 m (longer every 500 m) so the ground's speed is visible.
	var tick := 500.0 if missile else 100.0
	var m := ceilf((centre_x - span) / tick) * tick
	while m <= centre_x + span:
		var tx: float = to_x.call(m)
		draw_rect(Rect2(roundf(tx), ground_y + 1, 1, 4 if int(m) % int(tick * 5.0) == 0 else 2), Color(ink_color, 0.45))
		m += tick

	var have := a.bombs_left > 0
	var in_range := have and (strike.missile_target() if missile else strike.guided_target_near(centre_x)) != null
	# Bracket: where a guided bomb can steer to (around the impact point), or
	# the missile's range band ahead of the jet.
	if have:
		var col := in_range_color if in_range else Color(ink_color, 0.7)
		var edges: Array = [to_x.call(a.pos_m.x + d.missile_range_min_m), to_x.call(a.pos_m.x + d.missile_range_max_m)] if missile \
				else [mid - d.bomb_guidance_reach_m / span * half_w, mid + d.bomb_guidance_reach_m / span * half_w]
		for k in 2:
			var bx := roundf(edges[k])
			draw_rect(Rect2(bx, ground_y - 9, 1, 8), col)
			draw_rect(Rect2(bx - (2 if k == 1 else 0), ground_y - 9, 3, 1), col)

	# Targets (arrows at the edges when out of range).
	for t in strike.targets:
		var tx: float = to_x.call(t.x_m)
		var lo := sr.position.x + 4
		var hi := sr.end.x - 4
		if t.destroyed:
			if tx > lo and tx < hi:
				draw_line(Vector2(tx - 2, ground_y - 4), Vector2(tx + 2, ground_y - 1), Color(ink_color, 0.35), 1.0)
				draw_line(Vector2(tx - 2, ground_y - 1), Vector2(tx + 2, ground_y - 4), Color(ink_color, 0.35), 1.0)
			continue
		if tx < lo:
			draw_colored_polygon(PackedVector2Array([Vector2(lo - 1, ground_y - 3), Vector2(lo + 3, ground_y - 6), Vector2(lo + 3, ground_y)]), target_color)
		elif tx > hi:
			draw_colored_polygon(PackedVector2Array([Vector2(hi + 1, ground_y - 3), Vector2(hi - 3, ground_y - 6), Vector2(hi - 3, ground_y)]), target_color)
		else:
			var half := maxf(t.half_width_m / span * half_w, 1.5)
			draw_rect(Rect2(roundf(tx - half), ground_y - 5, roundf(half * 2.0), 5), target_color)

	# Bombs already falling: where they will hit.
	for x in strike.falling_impacts():
		var bx: float = to_x.call(x)
		if bx > sr.position.x + 2 and bx < sr.end.x - 2:
			draw_rect(Rect2(bx - 1, ground_y - 13, 2, 8), Color(1, 1, 1, 0.85))

	# Jet symbol (missile view), or the impact cross (bombs).
	if missile:
		var jx := roundf(to_x.call(a.pos_m.x))
		draw_rect(Rect2(jx - 4, sr.position.y + 26, 9, 1), ink_color)
		draw_rect(Rect2(jx - 4, sr.position.y + 24, 1, 2), ink_color)
		draw_rect(Rect2(jx - 1, sr.position.y + 27, 3, 1), ink_color)
	elif have:
		var col := in_range_color if in_range else ink_color
		var cx := roundf(mid)
		draw_rect(Rect2(cx, sr.position.y + 22, 1, ground_y - sr.position.y - 22), Color(col, 0.4))
		draw_rect(Rect2(cx - 4, ground_y - 3, 9, 1), col)
		draw_rect(Rect2(cx - 1, ground_y - 5, 3, 5), col)

	# Text: title / status, distance to the next target, bombs left.
	var blink := fmod(_time, 0.5) < 0.32
	var title := d.weapon_name if d.weapon_name != "" else "BOMB SIGHT"
	var title_col := Color(ink_color, 0.85)
	if in_range:
		title = ("IN RANGE - FIRE!" if missile else "IN RANGE - DROP!") if blink else ""
		title_col = in_range_color
	elif not have:
		title = "MISSILE AWAY" if missile else "BOMBS FALLING"
	_text(Vector2(sr.position.x + 3, sr.position.y + 9), title, title_col)
	var dist := strike.distance_to_next_target()
	var line2 := "TGT %.1f KM" % (dist / 1000.0) if dist < INF else "NO TARGETS"
	_text(Vector2(sr.position.x + 3, sr.position.y + 19), line2, Color(ink_color, 0.7))
	var bombs := "%d LEFT" % a.bombs_left
	var w := _font.get_string_size(bombs, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_text(Vector2(sr.end.x - 3 - w, sr.position.y + 19), bombs, Color(ink_color, 0.7))


func _text(p: Vector2, s: String, col: Color) -> void:
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
