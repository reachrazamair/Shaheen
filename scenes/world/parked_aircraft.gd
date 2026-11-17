extends Node2D
## Parked front-view aircraft on a base's apron (scenery). The base fills
## `items` with [texture, Rect2 (px), tint]; drawn smooth like the flying
## aircraft (linear + mipmaps) in its own node so the base's pixel text stays crisp.

var items: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func set_items(list: Array) -> void:
	items = list
	queue_redraw()


func _draw() -> void:
	for it in items:
		var r: Rect2 = it[1]
		# Soft shadow on the apron under the aircraft.
		draw_rect(Rect2(r.position.x + r.size.x * 0.15, -1, r.size.x * 0.7, 1), Color(0, 0, 0, 0.25))
		draw_texture_rect(it[0], r, false, it[2])
