extends MultiplayerSynchronizer
class_name NetworkHP

## Health component that can be attached to any object
## Manages health synchronization across network and displays UI health bar

# Health properties
@export var max_health: int = 100:
	set(value):
		max_health = max(1, value)
		if current_health > max_health:
			current_health = max_health
		if is_inside_tree():
			health_changed.emit(current_health, max_health)

@export var current_health: int = 100:
	set(value):
		var old_health: int = current_health
		current_health = clampi(value, 0, max_health)
		if old_health != current_health and is_inside_tree():
			health_changed.emit(current_health, max_health)
			if current_health <= 0:
				health_depleted.emit()

# Health bar display options
@export_group("Health Bar")
@export var health_bar: Node = null

# Signals
signal health_changed(new_health: int, max_health: int)
signal health_depleted()
signal damage_taken(amount: int, new_health: int)
signal healed(amount: int, new_health: int)

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _ready() -> void:
	# Initialize health
	if current_health > max_health:
		current_health = max_health

	# Defer health bar setup to ensure all nodes are ready
	call_deferred("_setup_health_bar")

func _exit_tree() -> void:
	# Disconnect from health bar (don't free it, it's part of the scene)
	if health_changed.is_connected(_on_health_changed):
		health_changed.disconnect(_on_health_changed)

## Apply damage to this object
func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	var old_health: int = current_health
	current_health -= amount

	if old_health != current_health:
		damage_taken.emit(amount, current_health)

## Heal this object
func heal(amount: int) -> void:
	if amount <= 0:
		return

	var old_health: int = current_health
	current_health += amount

	if old_health != current_health:
		healed.emit(amount, current_health)

## Set health to a specific value
func set_health(value: int) -> void:
	current_health = value

## Check if object is alive
func is_alive() -> bool:
	return current_health > 0

## Get health as a percentage (0.0 to 1.0)
func get_health_percentage() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

## Reset health to maximum
func reset_health() -> void:
	current_health = max_health

## Setup and configure health bar UI
func _setup_health_bar() -> void:
	# Check if health bar is set
	if not is_instance_valid(health_bar):
		return

	# Connect signals first
	if not health_changed.is_connected(_on_health_changed):
		health_changed.connect(_on_health_changed)

	# Initialize health bar with current values
	if health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	else:
		push_warning("NetworkHP: Health bar doesn't have update_health method!")

	# Emit initial health state to trigger update via signal
	health_changed.emit(current_health, max_health)

## Update health bar when health changes
func _on_health_changed(new_health: int, new_max_health: int) -> void:
	if is_instance_valid(health_bar) and health_bar.has_method("update_health"):
		health_bar.update_health(new_health, new_max_health)
