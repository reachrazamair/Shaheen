# Roadmap

Work proceeds in small chunks. Only work on the current chunk. Tick boxes when done. Later phases are rough and will be detailed into chunks when we get there.

## Phase 1: Prototype (current)
Detailed in `PROTOTYPE_SPEC.md`.
- [x] 1.1 Project setup (settings, folders, input map, git)
- [x] 1.2 Plane on a runway (throttle, brakes, rolling, camera, debug text)
- [x] 1.3 Takeoff and flight (lift, pitch, stall, drag)
- [x] 1.4 Flaps, gear, engine, fuel (E engine with spool-up, F flaps UP/TO/LDG, G gear for retractable aircraft, B air brake in flight, fuel burn and flame-out)
- [x] 1.5 Cockpit HUD layout (gauge panel, phase box, instructor message box)
- [x] 1.6 Two bases and parallax scenery
  - Route: **Risalpur (start, PAF Academy Asghar Khan) → Peshawar**, 9 km between thresholds (compressed). Buildings, windsock, name boards, approach lights, parallax mountains/hills/trees/clouds, scenery blending from Risalpur's green plains to Peshawar's big mountains, distance bar, APPROACH phase and landing calls.
  - Also done alongside 1.6 at the owner's request: pixel-art Super Mushshak sprite (sharper, ~2x true scale), animated retractable gear on the Mushshak, instructor redrawn in helmet + green flight suit (talks and blinks), camera keeps the ground in view when low.
- [x] 1.7 Landing detection, grading, result screen
  - Grades PERFECT/GOOD/FIRM/HARD from touchdown sink rate (limits in AircraftData), CRASH for: off-runway touchdown, gear up, nose-first, too hard, running off a runway end; WRONG BASE for landing back at Risalpur; overrun at low speed = one grade lower. Crash effect (fireball, debris, smoke). Result screen with Retry / Menu.
  - Also: route shortened to **5 km** (owner: 9 km felt too long); start screen with **name entry**, shown as **"AVN CDT <NAME>"** (Aviation Cadet) bottom-left in flight, on the result screen and in the instructor's calls.
- [x] 1.8 Second aircraft (F-16) and aircraft-select screen
  - F-16 built from the owner's art (`docs/reference/f16_sprite_source.png`), gear drawn in code (art shows it retracted). Afterburner above 85% throttle (flame, A/B light, 3x fuel). Harder than the Mushshak: stall 125 kt, rotate 145 kt, approach ~145 kt, 4 s engine spool, twitchier pitch, weaker brakes, stricter landing limits.
  - Also: stalls no longer drop the nose (owner: "fall in the same position"); crashes break the fuselage into 2 or 3 tumbling pieces depending on impact severity.
  - Follow-up (owner feedback): smoother on-screen motion (render interpolation + camera locked to the plane; a softer F-16 handling model was tried and reverted, owner prefers the original crisp handling), much bigger afterburner flame, nose gear moved under the intake. Centre attitude indicator and route bar replaced by a **positional radar** (side-view map of the route with both bases and the plane blip, phase + km to go + progress segments). **Per-aircraft cockpit:** `cockpit_style` Analog (Mushshak, round dials) / Glass (F-16, green speed/altitude tapes, Mach, G, VS bar, three gear lights).
  - Ninth follow-up: big performance fix for the browser (static scenery no longer redrawn every frame; parallax bands batched into one draw call each: ~10x faster); start screen gets a golden-hour airfield backdrop with a formation flypast; start-screen cards ordered Mushshak, Mirage, F-16; subtitle and route line removed.
  - Eighth follow-up: Mirage V rebuilt from the owner's gear-down art (real retracting gear layer); night aircraft lights come on with the engine; parked front-view aircraft at both bases (12 K-8s at Risalpur, 12 JF-17s at Masroor), some in hardened shelters; Masroor squadron boards (No. 2 "Minhasians", No. 8 "Haider") and a "Welcome to Masroor, the Home of Warriors" board at the far end of the runway.
  - Seventh follow-up: aircraft flies itself off once the nose wheel is up at rotate speed; nose wheel comes down by itself on the landing roll when slow; fighter brakes much stronger; brighter aircraft and afterburner at night; landmarks bigger and Mazar-e-Quaid redrawn. Web export preset + `deploy.bat` added (chunk 1.9 prep).
  - Sixth follow-up (owner requests): **Mirage V** added as a third aircraft (dark analog cockpit, stall 140 kt); takeoff pitch limit until 500 ft; destination is now **PAF Base Masroor, Karachi** with a sandy coastal look and background Karachi landmarks (sea and port, Teen Talwar, Bahria Icon Tower, Mazar-e-Quaid, Masjid-e-Tooba, skyline); aircraft cards show only name and role.
  - Fifth follow-up: aggressive instructor with Urdu phrases; rank per aircraft (AVN CDT in the Mushshak, SQN LDR in the F-16); name plate moved under the instructor box (it hid the plane); DAY/NIGHT choice on the start screen with a full night mode (stars, runway/approach lights, lit tower, aircraft nav/strobe/landing lights).
  - Fourth follow-up: the aircraft pivots on its main wheels on the ground (only the nose wheel lifts); pitch limits removed (loops/inverted possible, lift model covers any angle incl. negative stalls); tail-strike and upside-down touchdowns crash.
  - Third follow-up: instructor box and instrument panel swapped (instructor top-left, panel top-right) so the plane isn't hidden when climbing; bottom-left name plate now shows the PAF pilot wings badge above "AVN CDT" and the name.
  - Second follow-up: crashes shatter the airframe into many small irregular shards that slide to a stop (no bounce); big crashes explode (fireball, debris, ground fire), small ones scrape along with dust and thin smoke; nose lifts gradually on the takeoff roll from 70% of rotate speed; F-16 moving tailplane (elevator) follows the pitch keys; F-16 blackout (high positive G) and redout (strong negative G) screen effects above 250 kt.
- [ ] 1.9 Tuning pass and web deploy to Vercel for friends
  - Web deploy done: https://shaheen-green.vercel.app (2026-11-17). Tuning pass from friends' feedback still to do.
  - Tuning so far: instructor English-only (censored curses), black helmet with visor down; firm-but-legal landings make a small realistic hop (one per landing), smooth landings don't, too hard still crashes.
  - TODO (owner asked, not started): landing readability (sink-rate cue, short-final callouts, fairer nose-down rule); audio (Phase 2).

### Open questions (owner to decide after playtesting)
- **Camera:** keep the moving look-ahead camera? Should it zoom out as speed increases?
- **Throttle:** keep "hold ↑/↓ to move the lever" (lever stays where you leave it), or switch to a different scheme (e.g. fixed steps)?
- Throttle response was sped up in 1.3 and again in 1.4 (thrust and drag both ×1.75: same top speed, much punchier speed changes; brakes 0.4 g → 0.6 g), then before 1.5 via `speed_response` = 2 (speed changes 2× faster again, same top speed/climb) and brakes 0.9 g. Re-check feel.
- **Stall behaviour (decided):** owner chose NO auto nose-drop: the aircraft keeps its attitude and falls until the player pushes the nose down (`stall_nose_drop_deg_s` = 0 for both aircraft). An options toggle for auto-recovery could still come in Phase 2.
- **Gear on the Super Mushshak:** the real aircraft has fixed gear; the owner asked for working gear up/down, so `retractable_gear = true` in `super_mushshak.tres` (one flag to flip back).

**Everything below Phase 1 is on hold.** Don't start any of it until the owner says so. It's listed only so the prototype code stays easy to extend.

## Phase 2: Feedback and polish
- Gather friends' feedback. Tune controls and flight feel.
- Real pixel art for the two aircraft and the two bases (replace placeholders).
  - TODO (owner): aircraft must wear PAF colour schemes with the Pakistan flag and markings (Super Mushshak first, then F-16). Mushshak reference: `docs/reference/super_mushshak_livery_reference.png`.
- Sound: engine per aircraft type, touchdown, warnings (stall horn, gear).
- Pause menu, simple options (volume, show key list).
- Gamepad support.

## Phase 3: Career mode
- Main menu, career save (local, `user://`).
- Money and pay per mission based on landing grade, time and fuel.
- Mission select: list of routes between unlocked bases with pay offered.
- Hangar: buy or unlock aircraft.
- Add aircraft: K-8P Karakoram, F-7PG, Mirage, JF-17 (art plus data each).
- Add bases: Mianwali, Sargodha, Kamra, Rawalpindi and more, each with its own scenery theme.

## Phase 4: Mission planner
- Pre-flight screen to choose fuel load. Weight affects takeoff roll, climb and stall speed.
- Fuel management matters: diversions if low.
- Prepare a data structure for stores and weapons (not used yet).

## Phase 5: Conditions and challenge
- Time of day (dawn, day, dusk, night) with runway lights.
- Weather: wind/turbulence, rain, fog, dust haze.
- Emergencies: engine failure, gear failure, low-fuel diversion.
- Rank and reputation, more mission types (formation, ferry flights).

## Phase 6: Ground attack (Air Offense Command inspired)
- Weapons via the mission planner (bombs, rockets).
- Ground targets, anti-air threats, mission objectives.
- Separate mission type alongside normal flights.

## Phase 7: Mobile
- On-screen touch controls (throttle slider, pitch, flaps, gear, brake buttons).
- Android export, Google Play listing.

## Phase 8: Online and release
- Back end (Supabase or Firebase): cloud saves, leaderboards per route.
- Decide on PAF insignia permission (ISPR/PAF) before any paid or major public release.
- Public release (hosting and stores to be decided then; the prototype stays on Vercel).
- Per-aircraft cockpit panels (each aircraft gets its own instrument layout).

## Parking lot (ideas not yet scheduled)
- Aerial refueling, air show mode, transport and AEW aircraft (C-130, Erieye)
- Replays, photo mode
- Key rebinding UI
