# Project Shaheen (working title)

A 2D, side-view, pixel-art flight game centred on the **Pakistan Air Force (PAF)**. The player flies real PAF aircraft between named PAF bases: start the engine, take off, fly, and land at the destination. A career mode starts you in trainers; successful missions earn pay, which unlocks faster jets up to fighters like the JF-17 and F-16.

Inspiration:
- **TU-95** (browser game): a simple, charming, deliberately lo-fi "fly a big plane from A to B" game. We keep its indie, pixelated feel but make the controls **much less clunky** and add a lot more depth and options.
- **Air Offense Command** (Android): the plane is shown from the side and flies to the right across a scrolling landscape. We like its look and side-scrolling layout. Its ground-attack gameplay is a **later** feature, not part of the early builds.

Read these before doing any work:
- `docs/GAME_DESIGN.md`: the full vision (what the game becomes eventually)
- `docs/ROADMAP.md`: the phased plan, broken into small chunks
- `docs/PROTOTYPE_SPEC.md`: detailed spec for the **current** milestone (the prototype)
- `docs/DEPLOYMENT.md`: how builds are exported and shared

## Current focus: prototype only

Right now we are **only** building the basic prototype: a couple of planes that can take off, fly and land between two bases, playable in a browser. Career, money, unlocks, mission planner, weapons, weather, mobile, back end and per-aircraft cockpits are all **out of scope** until the owner says otherwise. `GAME_DESIGN.md` describes the long-term vision so early code doesn't paint us into a corner. It is **not** a to-do list.

## How we work (important)

- **Small chunks.** We build one roadmap chunk at a time. Do only the current chunk. Don't build features from later phases "while you're at it". Leave a short TODO note in the roadmap instead.
- At the end of each chunk: summarise what changed, say how to test it (which keys to press, what should happen), and stop so the owner can play it.
- Keep the game **runnable at every step**. A chunk isn't done if the project doesn't open and run in Godot.
- **Feel matters more than realism.** The flight model is arcade-style. If a choice is between "realistic" and "fun and readable", choose fun and readable.
- **Data-driven.** Aircraft stats and base definitions live in data resources (`.tres`), not hard-coded in scripts, so new aircraft and bases are added without code changes.
- **Every tunable number is exposed** (`@export` vars or resource fields) so the owner can tweak feel in the editor.
- Use git; one commit (or a few) per chunk with clear messages.
- Update `docs/ROADMAP.md` checkboxes when a chunk is finished.

## Tech stack

- **Engine:** Godot 4 (latest stable 4.x release).
- **Language:** GDScript only. Godot 4 can't export C# projects to the web, and the web build is how we share the game.
- **Renderer:** Compatibility (OpenGL / WebGL 2). Required for reliable web export and older phones.
- **Platforms:** Web (HTML5) first. Windows desktop as a secondary export. Android later.
- **Back end:** none for now. Saves are local (Godot `user://`, which maps to browser storage on web). Cloud saves and leaderboards come much later (likely Supabase or Firebase).
- **Hosting:** Vercel, as a static site serving the Godot web export (see `docs/DEPLOYMENT.md`). No other hosts for now.

## Visual style rules

- Pixel art, low internal resolution: **640×360** base viewport (leaves room for the cockpit panel at the top), scaled up with integer scaling (2× = 1280×720, 3× = 1920×1080) and nearest-neighbour filtering (no blur).
  - Project Settings → Display → Window: viewport 640×360, stretch mode `viewport`, aspect `keep`, scale mode `integer`.
  - Rendering → Textures → Default texture filter: `Nearest`.
- Side view. The plane flies **left to right**. The camera follows the plane horizontally and vertically, with a little look-ahead in the direction of travel.
- Parallax background layers (sky gradient, distant mountains, mid hills, near trees and buildings) give a sense of speed and place.
- Each base has its own look (e.g. green Peshawar valley, Salt Range hills near Mianwali and Sargodha, coastal Karachi), but it's **stylised**: runway, hangars, control tower, landmarks. Never trace real base layouts or use satellite imagery.
- Until real art exists, use **simple placeholder shapes** (Polygon2D / ColorRect / tiny generated PNGs) at the correct final pixel size, so real sprites can be dropped in later without code changes.
- Pixel font for the HUD and menus.

## Screen layout (reference: `docs/reference/tu95_layout_reference.png`)

The reference screenshot is from TU-95. We want a **similar layout, not a copy**: our own art, aircraft and PAF setting.

- **Top-left: cockpit instrument panel.** A grey metal panel with chunky pixel-art **analog round gauges** (airspeed, altimeter, vertical speed, engine/throttle). Above or beside them: throttle lever, flap and gear indicators, warning lights. It overlays the sky.
- **Top-centre: flight phase panel.** A small dark box showing the current phase (`TAKE OFF`, `CLIMB`, `CRUISE`, `DESCENT`, `APPROACH`, `LANDED`) with a tiny diagram of the plane's attitude or the phase.
- **Top-right: radio/instructor message box.** A pixel portrait (placeholder: a PAF instructor or ATC officer) plus short pixel-font messages, e.g. "Throttle up to begin your takeoff roll", "Gear up!", "Cleared to land, Peshawar". A row of small lights underneath is optional decoration.
- **Bottom ~60%: the world.** A wide, fairly **zoomed-out** side view: the plane is **small** relative to big base buildings (hangars, a long terminal/admin block, control tower), with green hills, clouds and a pale sky behind. Ground and runway along the bottom.
- The panels are part of the UI layer (`CanvasLayer`) and stay fixed. The world scrolls underneath.
- Prototype: **one shared panel design** for both aircraft, with gauge ranges taken from the aircraft data. Different cockpit panels per aircraft come later.

## Suggested project structure

```
res://
  project.godot
  scenes/
    main.tscn              # entry point
    flight/flight.tscn     # one flight: world + aircraft + HUD
    aircraft/aircraft.tscn
    world/runway.tscn, base.tscn, parallax_bg.tscn
    ui/hud.tscn, result_screen.tscn, main_menu.tscn
  scripts/                 # or keep scripts next to their scenes
  data/
    aircraft/*.tres        # AircraftData resources
    bases/*.tres           # BaseData resources
  assets/
    sprites/ fonts/ audio/
docs/
```

## Content and sensitivity notes

- Bases and aircraft use real PAF names. Scenery is stylised and invented. No real layouts, no sensitive detail.
- Official PAF insignia and emblems: use a stylised placeholder roundel for now. Using the real emblem in a public or paid release may need permission (ISPR/PAF). The owner will decide later.

## Working notes (keep this section up to date)

Decisions and facts future sessions need. Update it whenever something here changes.

- **Godot 4.7.2** installed via winget. Executables: `C:\Users\rohai\AppData\Local\Microsoft\WinGet\Links\godot.exe` (editor) and `godot_console.exe` (headless/CLI). Both are on the user PATH as `godot` / `godot_console` (VS Code must be restarted to see it).
  - Open the editor: `godot -e` from the project root. Run the game: F5.
  - Headless checks: `godot_console --headless --path . --import` then `godot_console --headless --path . --quit-after 120`. Throwaway test scripts (`extends SceneTree`) go in the scratchpad, run with `-s <script>`.
- **Git:** this folder is its own repo (branch `main`). Small commits per step. **Always ask the owner before pushing.** The owner will create the GitHub repo ("Shaheen") and share the link; no remote yet.
- **Controls** (owner's layout, source of truth is the Input Map in `project.godot`): ↑/↓ throttle (hold), ← pitch nose up, → pitch nose down, E engine, F flaps, G gear, B brake (ground and air), Esc pause, R restart.
- **Aircraft order:** Super Mushshak first, then F-16. Both will eventually wear PAF colour schemes with the Pakistan flag; placeholders until the art phase. Mushshak livery reference: `docs/reference/super_mushshak_livery_reference.png`.
- **Feel:** the owner wants motion that follows a believable flight path (too slow → stall, more speed → more lift → climb, drag and friction always act). Arcade-simple controls, believable physics.
- **Flight model (chunk 1.3, `scenes/aircraft/aircraft.gd`):** custom forces, no RigidBody. Lift = weight × (speed / stall_speed)² × cl(aoa); cl rises linearly to 1.0 at `stall_aoa_deg`, then collapses to `post_stall_lift`. So each aircraft's stall speed is a direct data value, and more speed at the same pitch means a climb. Drag = k·v²·(1 + induced·cl²). Propeller thrust fades with speed (`thrust_zero_speed_kt`; 0 for jets). A stall lasts at least `min_stall_time_s` and forces the nose down. On the ground: normal force, rolling friction, brakes; nose can't rise below `rotate_speed_kt`. Mushshak tested: lift-off ~64 kt after ~180 m, climb ~1,400 fpm at ~95 kt, cruise ~115-130 kt, stall ~52 kt.
- **Units:** physics in SI; drawing at 4 px/m (`scripts/world_scale.gd`). Aircraft node origin = wheel contact point, nose points +x. Altitude A m is drawn at y = -A × 4.
- **Layout conventions:** scene scripts live next to their `.tscn`; shared/global scripts in `scripts/`; Resource classes (`AircraftData`, later `BaseData`) in `scripts/data/`; `.tres` data in `data/`. `docs/` has a `.gdignore` so Godot doesn't import it.
- **Scene tree (as of chunk 1.2):** `main.tscn` (Node) → instance of `flight/flight.tscn` (sky CanvasLayer, Ground, Runway, Aircraft, Camera, DebugUI). `main` becomes the start screen in chunk 1.8.
