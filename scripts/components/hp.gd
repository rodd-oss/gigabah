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
