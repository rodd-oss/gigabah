@tool
class_name DayPhaseConfig
extends Resource

## Phase configuration resource.
## Add new resources of this type to the DayNightCycle.phase_configs array
## to extend or reorder the cycle (e.g., add AFTERNOON).

@export var name: StringName = &"MORNING"
@export var duration: float = 20.0
@export var dir_energy: float = 1.0
@export var point_energy: float = 0.0
@export var ambient_color: Color = Color.WHITE
@export var ambient_energy: float = -1.0 ## If >=0 overrides automatic brightness-derived ambient energy.
@export var dir_color: Color = Color.WHITE ## Optional per-phase directional light color.
