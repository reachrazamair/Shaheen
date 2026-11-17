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

@export_group("Landmarks")
## Background landmarks seen while flying in (scenes/world/landmarks.gd LAYOUT),
## e.g. Karachi: sea, port_cranes, teen_talwar, bahria_icon, mazar_e_quaid,
## masjid_e_tooba, skyline. Scenery only.
@export var landmarks := PackedStringArray()
