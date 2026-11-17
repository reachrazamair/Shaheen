# Roadmap

Work proceeds in small chunks. Only work on the current chunk. Tick boxes when done. Later phases are rough and will be detailed into chunks when we get there.

## Phase 1: Prototype (current)
Detailed in `PROTOTYPE_SPEC.md`.
- [x] 1.1 Project setup (settings, folders, input map, git)
- [x] 1.2 Plane on a runway (throttle, brakes, rolling, camera, debug text)
- [x] 1.3 Takeoff and flight (lift, pitch, stall, drag)
- [ ] 1.4 Flaps, gear, engine, fuel
  - TODO: E starts/stops the engine (until then thrust works without it). B also acts as an air brake in flight.
- [ ] 1.5 Cockpit HUD layout (gauge panel, phase box, instructor message box)
- [ ] 1.6 Two bases and parallax scenery
- [ ] 1.7 Landing detection, grading, result screen
- [ ] 1.8 Second aircraft (F-16) and aircraft-select screen
- [ ] 1.9 Tuning pass and web deploy to Vercel for friends

### Open questions (owner to decide after playtesting)
- **Camera:** keep the moving look-ahead camera? Should it zoom out as speed increases?
- **Throttle:** keep "hold ↑/↓ to move the lever" (lever stays where you leave it), or switch to a different scheme (e.g. fixed steps)?
- Throttle response was sped up in 1.3 (lever idle→full in ~0.6 s, stronger static prop thrust). Re-check feel.
- Above ~30 m altitude the ground leaves the screen and the sky is plain until clouds/parallax arrive in 1.6.

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
