class_name WorldScale
extends RefCounted
## Shared units for the whole game.
## Physics runs in SI units (metres, m/s, kg, N). Drawing converts metres to
## pixels with PX_PER_M. World y is "up = altitude" in physics, but Godot's
## y axis points down, so altitude A metres is drawn at y = -A * PX_PER_M.

## 4 px per metre: a Super Mushshak (~7 m long) is ~28 px, an F-16 (~15 m) ~60 px.
const PX_PER_M := 4.0
const GRAVITY := 9.81
const MS_TO_KT := 1.94384
const M_TO_FT := 3.28084


static func m_to_px(m: float) -> float:
	return m * PX_PER_M
