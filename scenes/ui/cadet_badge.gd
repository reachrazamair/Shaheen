extends PanelContainer
## Compact name plate under the instructor box (top-left): PAF pilot wings
## badge, a thin gold divider, then the rank (gold, like the wreath: "AVN CDT"
## in the trainer, "SQN LDR" in the F-16) over the player's name (white), on a
## dark plate with a thin gold border. Call show_cadet() once the name is known.

@export var badge_texture: Texture2D = preload("res://assets/sprites/paf_pilot_wings.png")
## On-screen badge width (layout px); height follows the picture.
@export var badge_width := 52.0
@export var plate_color := Color(0.06, 0.08, 0.1, 0.78)
@export var border_color := Color(0.72, 0.55, 0.28)
@export var rank_color := Color(0.85, 0.66, 0.34)
@export var name_color := Color(0.96, 0.96, 0.92)

var _rank: Label
var _name: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = plate_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var badge := TextureRect.new()
	badge.texture = badge_texture
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ratio := badge_texture.get_height() / float(badge_texture.get_width())
	badge.custom_minimum_size = Vector2(badge_width, roundf(badge_width * ratio))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)

	# Thin gold divider between the badge and the text.
	var rule := ColorRect.new()
	rule.color = Color(border_color, 0.6)
	rule.custom_minimum_size = Vector2(1, 0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)

	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_rank = _label(rank_color)
	_name = _label(name_color)
	text.add_child(_rank)
	text.add_child(_name)


func show_cadet() -> void:
	_rank.text = GameState.aircraft_data().pilot_rank
	var n := GameState.pilot_name.strip_edges().to_upper()
	_name.text = n if n != "" else "CADET"


func _label(col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
