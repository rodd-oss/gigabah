# Gigabah

A multiplayer 3D game built with Godot 4.5 featuring networked gameplay with synchronized player positions, health, and projectiles.

## Features

- Real-time multiplayer networking
- Player movement with WASD/Arrow keys and gamepad support
- Network-synchronized components (HP, position, projectiles)
- Jolt Physics engine integration
- Dedicated server support

## Tech Stack

- **Engine**: Godot 4.5
- **Physics**: Jolt Physics
- **Networking**: Godot Multiplayer API
- **Container**: Docker support included
- **Scripting language**: GDScript with types

## Development Setup

### Running Multiple Instances for Development

To run multiplayer locally with multiple game instances:

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
models/         - Blender file 3d models
```
