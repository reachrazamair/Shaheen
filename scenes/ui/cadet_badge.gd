extends PanelContainer
## Bottom-left name plate: PAF pilot wings badge over "AVN CDT" (gold, like
## the wreath) and the player's name (white), on a dark plate with a thin
## gold border. Call show_cadet() once the name is known.

@export var badge_texture: Texture2D = preload("res://assets/sprites/paf_pilot_wings.png")
## On-screen badge width (layout px); height follows the picture.
@export var badge_width := 72.0
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
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var badge := TextureRect.new()
	badge.texture = badge_texture
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ratio := badge_texture.get_height() / float(badge_texture.get_width())
	badge.custom_minimum_size = Vector2(badge_width, roundf(badge_width * ratio))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)

	# Thin gold rule between the badge and the text.
	var rule := ColorRect.new()
	rule.color = Color(border_color, 0.6)
	rule.custom_minimum_size = Vector2(badge_width * 0.6, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)

	_rank = _label(rank_color)
	_name = _label(name_color)
	box.add_child(_rank)
	box.add_child(_name)


func show_cadet() -> void:
	_rank.text = GameState.RANK
	var n := GameState.pilot_name.strip_edges().to_upper()
	_name.text = n if n != "" else "CADET"


func _label(col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
