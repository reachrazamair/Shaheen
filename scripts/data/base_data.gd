class_name BaseData
extends Resource
## One PAF base: its name, runway, buildings and scenery theme.
## Real names, stylised and invented scenery (never real layouts).
## A new base is just a new .tres in data/bases/.

@export var display_name := "PAF Base"
## Short name for the HUD and radio calls (e.g. "PESHAWAR").
@export var short_name := "BASE"
@export var runway_length_m := 1200.0

@export_group("Buildings")
@export var hangar_count := 3
@export var admin_block_length_m := 90.0
@export var admin_block_floors := 3
@export var tower_height_m := 24.0
@export var building_color := Color(0.86, 0.83, 0.75)
@export var hangar_color := Color(0.62, 0.64, 0.6)
@export var roof_color := Color(0.42, 0.44, 0.47)

@export_group("Scenery theme")
## The scenery blends from the departure theme to the destination theme along the route.
@export var sky_tint := Color(1, 1, 1)
@export var mountain_color := Color(0.6, 0.66, 0.74)
## 0 = no mountains on the horizon, 1 = normal, 1.5 = big ranges.
@export var mountain_height := 0.5
@export var hill_color := Color(0.42, 0.58, 0.36)
@export var tree_color := Color(0.25, 0.42, 0.22)
## Ground around the base (the strip blends between the two bases).
@export var ground_color := Color(0.42, 0.62, 0.3)
@export var ground_tuft_color := Color(0.33, 0.52, 0.24)

@export_group("Apron (parked aircraft, scenery)")
## Front-view aircraft parked behind the runway (cycled in order). Empty = none.
@export var parked_aircraft: Array[Texture2D] = []
## Apron from/to (metres from the runway start). Each slot holds one aircraft;
## every shelter_every-th slot is a hardened aircraft shelter, the rest are in the open.
@export var apron_from_m := 400.0
@export var apron_to_m := 700.0
@export var parked_spacing_m := 13.0
## 0 = no shelters.
@export var shelter_every := 3
## Squadron boards on the apron: text (two lines split by "|") and position.
@export var squadron_boards := PackedStringArray()
@export var squadron_board_x_m := PackedFloat32Array()
## Big welcome board (lines), placed welcome_sign_x_m from the runway start
## (negative = before the threshold, seen on final approach). Empty = none.
@export var welcome_sign := PackedStringArray()
@export var welcome_sign_x_m := -160.0

@export_group("Landmarks")
## Background landmarks seen while flying in (scenes/world/landmarks.gd LAYOUT),
## e.g. Karachi: sea, port_cranes, teen_talwar, bahria_icon, mazar_e_quaid,
## masjid_e_tooba, skyline. Scenery only.
@export var landmarks := PackedStringArray()
