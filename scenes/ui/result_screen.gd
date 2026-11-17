extends CanvasLayer
## End-of-flight result: grade, why, touchdown rate, flight time, fuel used.
## Buttons: RETRY (same flight) and MENU (start screen; aircraft select in 1.8).

signal retry_pressed
signal menu_pressed

const GRADE_COLORS := {
	"PERFECT": Color(0.35, 1.0, 0.45),
	"GOOD": Color(0.6, 0.95, 0.4),
	"FIRM": Color(1.0, 0.85, 0.3),
	"HARD": Color(1.0, 0.55, 0.2),
	"CRASH": Color(1.0, 0.25, 0.2),
	"WRONG BASE": Color(0.6, 0.8, 1.0),
}

var _panel: PanelContainer


func _ready() -> void:
	layer = 20
	visible = false


## result: {grade, title, reasons (Array[String]), touchdown_fpm, time_s, fuel_used_kg, fuel_capacity_kg}
func show_result(result: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.12, 0.95)
	style.border_color = Color(0.55, 0.57, 0.6)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(170, 92)
	_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)

	var grade: String = result.get("grade", "CRASH")
	box.add_child(_label(GameState.cadet_title(), 8, Color(0.75, 0.78, 0.72)))
	box.add_child(_label(result.get("title", grade), 16, GRADE_COLORS.get(grade, Color.WHITE)))
	for r in result.get("reasons", []):
		box.add_child(_label(r, 8, Color(0.9, 0.9, 0.85)))

	var sep := HSeparator.new()
	box.add_child(sep)
	var time_s: float = result.get("time_s", 0.0)
	var stats := [
		"TOUCHDOWN   %d FT/MIN" % roundi(result.get("touchdown_fpm", 0.0)) if result.has("touchdown_fpm") else "TOUCHDOWN   -",
		"FLIGHT TIME %d:%02d" % [int(time_s) / 60, int(time_s) % 60],
		"FUEL USED   %.0f KG (%d%%)" % [result.get("fuel_used_kg", 0.0),
				roundi(100.0 * result.get("fuel_used_kg", 0.0) / maxf(result.get("fuel_capacity_kg", 1.0), 1.0))],
	]
	for s in stats:
		var l := _label(s, 8, Color(0.85, 0.88, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(l)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var retry := _button("RETRY (R)")
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	var menu := _button("MENU")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(retry)
	row.add_child(menu)
	box.add_child(row)

	visible = true
	retry.grab_focus()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 22)
	b.add_theme_font_size_override("font_size", 8)
	return b
