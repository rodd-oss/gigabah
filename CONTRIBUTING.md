# Contributing to Gigabah

Thank you for your interest in contributing to Gigabah! This document provides guidelines for contributing to our multiplayer 3D game built with Godot 4.5.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Branch Naming Convention](#branch-naming-convention)
- [Pull Request Process](#pull-request-process)
- [Code Style Guidelines](#code-style-guidelines)
- [Getting Help](#getting-help)

## Getting Started

### Prerequisites

- Godot 4.5 or later
- Git
- Basic knowledge of GDScript and Godot development
- Understanding of multiplayer game development concepts

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/gigabah.git
   cd gigabah
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/rodd-oss/gigabah.git
   ```
4. **Open the project** in Godot 4.5
5. **Set up multiple instances** for local multiplayer testing:
   - Go to **Debug** → **Customize Run Instances**
   - Enable **Multiple Instances**
   - Set instance count to **3**
   - On the last instance, add `dedicated_server` to **Feature Flags**

## How to Contribute

### 1. Finding Tasks

- Check the [Issues](https://github.com/rodd-oss/gigabah/issues) page for available tasks
- Look for issues labeled with:
  - `good first issue` - Suitable for newcomers
  - `help wanted` - Community contributions welcome
  - `bug` - Bug fixes needed
  - `enhancement` - New features or improvements
- Comment on an issue to claim it and avoid duplicate work

### 2. Accepting Tasks

1. **Comment on the issue** you want to work on
2. **Wait for confirmation** from maintainers
3. **Create a new branch** following our naming convention
4. **Start working** on your changes

## Branch Naming Convention

Use descriptive branch names with the following format:

```
<type>/<description>
```

### Types:
- `feature/` - New features or enhancements
- `bugfix/` - Bug fixes
- `hotfix/` - Critical bug fixes for production
- `refactor/` - Code refactoring without changing functionality
- `docs/` - Documentation updates
- `test/` - Adding or updating tests
- `chore/` - Maintenance tasks, dependency updates

### Examples:
- `feature/new-enemy-ai`
- `bugfix/menu-crash`
- `feature/health-bar-improvements`
- `bugfix/network-sync-issues`
- `refactor/player-movement-system`
- `docs/api-documentation`
- `hotfix/critical-memory-leak`

## Pull Request Process

### Before Submitting

1. **Ensure your branch is up to date**:
   ```bash
   git checkout dev
   git pull upstream dev
   git checkout your-branch-name
   git rebase dev
   ```

2. **Test your changes**:
   - Run the game locally with multiple instances
   - Test multiplayer functionality
   - Verify no regressions in existing features

3. **Follow code style guidelines** (see below)

### Creating a Pull Request

1. **Push your branch** to your fork:
   ```bash
   git push origin your-branch-name
   ```

2. **Create a Pull Request** on GitHub with:
   - **Clear title** describing the change
   - **Detailed description** including:
     - What changes were made
     - Why the changes were necessary
     - How to test the changes
     - Screenshots/videos if applicable
   - **Link to related issues** using "Fixes #123" or "Closes #123"

3. **Fill out the PR template** (if available)

### PR Review Process

- Maintainers will review your code
- Address any requested changes
- Respond to feedback promptly
- Keep your PR up to date with the dev branch

## Code Style Guidelines

### GDScript Standards

- **Use strict typing** for better error detection:
  ```gdscript
  var health: int = 100
  var player_name: String = "Player"
  ```

- **Implement lifecycle functions** with explicit super() calls:
  ```gdscript
  func _ready() -> void:
      super._ready()
      # Your initialization code
  ```

- **Use @onready annotations** instead of direct node references:
  ```gdscript
  @onready var health_bar: ProgressBar = $HealthBar
  ```

- **Follow naming conventions**:
  - Files: `snake_case.gd` (e.g., `player_character.gd`)
  - Classes: `PascalCase` with `class_name` (e.g., `PlayerCharacter`)
  - Variables: `snake_case` (e.g., `health_points`)
  - Constants: `ALL_CAPS_SNAKE_CASE` (e.g., `MAX_HEALTH`)
  - Functions: `snake_case` (e.g., `move_player()`)
  - Signals: `snake_case` in past tense (e.g., `health_depleted`)

### Code Organization

- **Keep methods focused** and under 30 lines when possible
- **Use meaningful names** for variables and functions
- **Group related properties** and methods together
- **Document complex functions** with docstrings
- **Use signals for loose coupling** between nodes

### Performance Considerations

- **Use node groups judiciously** for managing collections
- **Implement object pooling** for frequently spawned objects
- **Use physics layers** to optimize collision detection
- **Prefer packed arrays** (PackedVector2Array, etc.) over regular arrays

## Project Structure

Understanding the codebase organization:

```
components/     - Network synchronization components
├── hp.gd                    - Health point synchronization
├── network_position.gd      - Position synchronization
└── network_projectile.gd    - Projectile synchronization

features/       - Feature-specific implementations
└── health-bar/ - Health bar UI components

scripts/        - Core game logic
├── network_manager.gd       - Multiplayer networking
├── multiplayer_spawner.gd   - Player spawning logic
└── player.gd               - Player controller

scenes/         - Game scenes
├── index.tscn              - Main game scene
├── player.tscn             - Player scene
├── bullet.tscn             - Projectile scene
└── aoe.tscn                - Area of effect scene
```

## Getting Help

### Who to Contact

- **General questions**: Open a [Discussion](https://github.com/rodd-oss/gigabah/discussions) or join [Telegram chat](https://t.me/milanroddchat)
- **Bug reports**: Create an [Issue](https://github.com/rodd-oss/gigabah/issues)
- **Feature requests**: Create an [Issue](https://github.com/rodd-oss/gigabah/issues) with the `enhancement` label
- **Code questions**: Ask in your Pull Request comments
- **Urgent issues**: [milanrodd@mail.ru](mailto:milanrodd@mail.ru) <!-- Add contact information -->

### Resources

- [Godot 4.5 Documentation](https://docs.godotengine.org/en/stable/)
- [Godot Multiplayer Tutorial](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

### Video Tutorials
- [Brackeys: How to make a 3D game in Godot](https://youtu.be/ke5KpqcoiIU?si=LtXnQr40wO5eXbyh)
- [Brackeys: How to make a Video Game - Godot Beginner Tutorial](https://youtu.be/LOhfqjmasi0?si=ydLoBKtK1uEAxaxi)
- [Brackeys: How to program in Godot - GDScript Tutorial](https://youtu.be/e1zJS31tr88?si=N6Rhp-vpll7wF_Lz)





## License

By contributing to Gigabah, you agree that your contributions will be licensed under the same license as the project. See [LICENSE](LICENSE) for details.

---

Thank you for contributing to Gigabah! Your efforts help make this multiplayer game better for everyone. 🎮
