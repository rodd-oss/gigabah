# Godessa

A multiplayer 3D game built with Godot 4.5 featuring networked gameplay with synchronized player positions, health, and projectiles.

## Features

- Real-time multiplayer networking
- Player movement with WASD/Arrow keys and gamepad support
- Network-synchronized components (HP, position, projectiles)
- Jolt Physics engine integration
- Dedicated server support
- Configurable day/night lighting cycle (addon)

## Tech Stack

- **Engine**: Godot 4.5
- **Physics**: Jolt Physics
- **Networking**: Godot Multiplayer API
- **Container**: Docker support included

## Development Setup

### Running Multiple Instances for Testing

To test multiplayer locally with multiple game instances:

1. Go to **Debug** → **Customize Run Instances**
2. Enable **Multiple Instances**
3. Set instance count to **3**
4. On the last instance, add `dedicated_server` to **Feature Flags**

This configuration will launch 2 client instances and 1 dedicated server instance for local multiplayer testing.

## Controls

- **WASD** / **Arrow Keys** - Movement
- **Gamepad** - Left stick for movement

## Project Structure

```
components/     - Network synchronization components
scripts/        - Core game logic and network manager
scenes/         - Game scenes (player, projectiles, index)
materials/      - Visual materials
addons/day_night_cycle/ - Day/Night cycle addon (data-driven phases)
```

## Day / Night Cycle Addon

The addon `DayNightCycle` provides a data-driven sequence of lighting phases.

### Default Phases
By default (when the array is empty) four phases are auto-created:
`MORNING -> DAY -> EVENING -> NIGHT`

### Adding or Reordering Phases
1. Select the `DayNightCycle` node in your scene.
2. In the Inspector, expand `phase_configs`.
3. Add a new element and choose `New DayPhaseConfig`.
4. Set fields:
   - `name` (e.g. AFTERNOON)
   - `duration` (seconds)
   - `dir_energy` (directional light energy)
   - `point_energy` (point/omni lights energy)
   - `ambient_color` (ambient / canvas modulate color)
5. Drag the new resource to the desired position (list order = cycle order).

Example: To insert `AFTERNOON` between `DAY` and `EVENING`, place the new config after `DAY` in the array.

### Forcing a Phase in Code
```
var cycle = $DayNightCycle
var idx = cycle.find_phase_index("AFTERNOON")
if idx != -1:
	cycle.force_phase(idx)
```

### Saving / Restoring State
Use `serialize_state()` and `restore_state(dictionary)` if you need to persist current phase and day across sessions.

### Fail-Fast Behavior
If invalid indices or empty phase sets appear at runtime, the component logs a fatal error and quits the game to surface configuration mistakes early.

