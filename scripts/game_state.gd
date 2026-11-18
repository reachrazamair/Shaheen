extends Node
## Autoload "GameState": small bits of state that live across scenes
## (the flight scene is reloaded on retry). Only the options (volumes) are
## saved to disk (user://settings.cfg: browser storage on the web).

const MAX_NAME_LENGTH := 16
const SETTINGS_PATH := "user://settings.cfg"
## Audio buses with a volume slider (default_bus_layout.tres), in slider order.
const VOLUME_BUSES := ["Master", "Engine", "Effects"]

## Aircraft the player can choose on the start screen (in unlock order).
const AIRCRAFT := [
	"res://data/aircraft/super_mushshak.tres",
	"res://data/aircraft/mirage5.tres",
	"res://data/aircraft/f16a.tres",
	"res://data/aircraft/f16.tres",
]

## Destinations from Risalpur (always the start for now), in route order:
## each one is a longer flight (BaseData.route_distance_m).
const DESTINATIONS := [
	"res://data/bases/masroor.tres",
	"res://data/bases/mushaf.tres",
]

## Night: the world canvas is multiplied by this colour (CanvasModulate).
const NIGHT_TINT := Color(0.2, 0.24, 0.4)

var pilot_name := ""
## Path of the chosen AircraftData.
var aircraft_path: String = AIRCRAFT[0]
## Path of the chosen destination BaseData.
var destination_path: String = DESTINATIONS[0]
## Time of day chosen on the start screen.
var night := false
## Slider volume per bus, 0..1 (0 = muted).
var volumes := {"Master": 1.0, "Engine": 1.0, "Effects": 1.0}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for bus in VOLUME_BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	for bus in VOLUME_BUSES:
		_apply_volume(bus)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in VOLUME_BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.save(SETTINGS_PATH)


## Sets a bus volume (0..1) right away; call save_settings() to keep it.
func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	_apply_volume(bus)


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v: float = volumes[bus]
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


## The chosen aircraft's data (rank, etc.).
func aircraft_data() -> AircraftData:
	return load(aircraft_path)


## Rank shown with the name: Aviation Cadet in the trainer, Squadron Leader
## in the F-16 (AircraftData.pilot_rank), e.g. "AVN CDT ALI" / "SQN LDR ALI".
func pilot_title() -> String:
	var n := pilot_name.strip_edges().to_upper()
	return aircraft_data().pilot_rank + (" " + n if n != "" else "")


## Short form for radio calls, e.g. "Avn Cdt Ali" / "Sqn Ldr Ali".
func pilot_call() -> String:
	var n := pilot_name.strip_edges()
	return aircraft_data().pilot_rank_call + (" " + n.capitalize() if n != "" else "")


## A light's colour boosted so it still shines at full brightness under the
## night tint (lights are drawn in the world canvas, which is darkened).
func glow(c: Color) -> Color:
	if not night:
		return c
	return Color(c.r / NIGHT_TINT.r, c.g / NIGHT_TINT.g, c.b / NIGHT_TINT.b, c.a)
