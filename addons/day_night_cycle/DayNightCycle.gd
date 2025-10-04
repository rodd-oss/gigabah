@tool
class_name DayNightCycle
extends Node

## DayNightCycle (data-driven)
## Как добавить / изменить фазы:
##   1. В инспекторе у узла выбери массив phase_configs.
##   2. Добавь новый ресурс DayPhaseConfig (Right Click -> New -> DayPhaseConfig).
##   3. Задай name (например AFTERNOON), duration, dir_energy, point_energy, ambient_color.
##   4. Перетащи ресурс в нужное место массива (порядок = порядок проигрывания).
##   5. (Опционально) Удали legacy поля, если не нужны — они используются только для автогенерации 4 дефолтов при пустом списке.
## Пример добавления AFTERNOON между DAY и EVENING: вставь новый ресурс на индекс 2.
## Fail-fast стратегия: некорректный индекс или пустой список в рантайме — фатальное завершение.

signal phase_changed(phase: StringName, state_index: int, day_index: int)
signal new_day_started(day_index: int)

@export var phase_configs: Array[DayPhaseConfig] = [] ## Data-driven phases; if empty defaults will be built.

var current_phase_index: int = 0 : set = _set_current_phase_index
var current_day: int = 1

@export var morning_duration: float = 20.0
@export var day_duration: float = 30.0
@export var evening_duration: float = 20.0
@export var night_duration: float = 30.0

@export var directional_light: NodePath ## Can be left empty; resolved at runtime.
@export var directional_lights: Array[NodePath] = [] ## Optional multiple directional lights (processed in addition to single directional_light for backward compatibility).
@export var point_lights: Array[NodePath] = [] ## Optional additional lights.
@export var canvas_modulate: CanvasModulate = null
@export var world_environment: WorldEnvironment = null

@export var dir_energy_morning: float = 0.25
@export var dir_energy_day: float = 1.0
@export var dir_energy_evening: float = 0.5
@export var dir_energy_night: float = 0.1

@export var point_energy_morning: float = 0.0
@export var point_energy_day: float = 0.0
@export var point_energy_evening: float = 0.4
@export var point_energy_night: float = 0.8

@export var ambient_color_morning: Color = Color(0.9,0.85,0.75)
@export var ambient_color_day: Color = Color(1,1,1)
@export var ambient_color_evening: Color = Color(0.8,0.6,0.5)
@export var ambient_color_night: Color = Color(0.3,0.35,0.5)

@export var transition_time: float = 5.0
@export var autostart: bool = true
@export var debug_log: bool = false ## Enable verbose runtime logging.

var _phase_timer: float = 0.0
var _phase_target_duration: float = 0.0
var _active: bool = false
var _tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint():
		_ensure_defaults_if_empty()
		return
	_ensure_defaults_if_empty()
	if autostart:
		start_cycle()

func _enter_tree() -> void:
	pass

func start_cycle(reset: bool = true) -> void:
	if _active:
		if debug_log:
			print("[DayNightCycle] start_cycle ignored (already active)")
		return
	if reset:
		current_phase_index = 0
		current_day = 1
	if phase_configs.is_empty():
		_fatal("No phases configured")
	_active = true
	set_process(true)
	_enter_phase(current_phase_index, true)

func stop_cycle() -> void:
	_active = false
	set_process(false)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _active:
		return
	_phase_timer += delta
	if _phase_timer >= _phase_target_duration:
		_advance_phase()

func _advance_phase() -> void:
	if phase_configs.is_empty():
		return
	var next_index := current_phase_index + 1
	if next_index >= phase_configs.size():
		current_day += 1
		emit_signal("new_day_started", current_day)
		next_index = 0
	current_phase_index = next_index
	_enter_phase(current_phase_index)

func _enter_phase(index: int, first: bool = false) -> void:
	if index < 0 or index >= phase_configs.size():
		_fatal("Phase index %d out of range" % index)
	current_phase_index = index
	var cfg := phase_configs[index]
	_phase_timer = 0.0
	_phase_target_duration = cfg.duration
	_apply_phase_transition(cfg, first)
	emit_signal("phase_changed", cfg.name, index, current_day)
	if debug_log:
		var peer := 0
		if Engine.has_singleton("ENetMultiplayerPeer") and get_tree().get_multiplayer():
			peer = get_tree().get_multiplayer().get_unique_id()
		print("[DayNightCycle] Enter phase %s (index=%d day=%d duration=%.2f peer=%d)" % [cfg.name, index, current_day, cfg.duration, peer])

func _set_current_phase_index(value: int) -> void:
	if value < 0 or value >= phase_configs.size():
		_fatal("Phase index %d out of range (set)" % value)
	current_phase_index = value

func _get_phase_duration(index: int) -> float:
	if index < 0 or index >= phase_configs.size():
		_fatal("Phase index %d out of range in duration" % index)
	return phase_configs[index].duration

func _phase_name(index: int) -> StringName:
	if index < 0 or index >= phase_configs.size():
		return &"UNKNOWN"
	return phase_configs[index].name

func _apply_phase_transition(cfg: DayPhaseConfig, instant: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null

	var target_dir_energy := cfg.dir_energy
	var target_point_energy := cfg.point_energy
	var target_ambient_color := cfg.ambient_color
	var target_ambient_energy := cfg.ambient_energy

	var has_transition := transition_time > 0.0 and not instant

	var dir_node := _resolve_node(directional_light)
	if dir_node:
		_tween_light_energy(dir_node, target_dir_energy, has_transition)
		# Optional per-phase light color tint
		if cfg.dir_color != Color.WHITE and _has_property(dir_node, "light_color"):
			_tween_property_or_set(dir_node, "light_color", cfg.dir_color, has_transition)
	# Additional directional lights
	for dl_path in directional_lights:
		var dl_node := _resolve_node(dl_path)
		if dl_node and dl_node != dir_node: # avoid double-processing same node
			_tween_light_energy(dl_node, target_dir_energy, has_transition)
			if cfg.dir_color != Color.WHITE and _has_property(dl_node, "light_color"):
				_tween_property_or_set(dl_node, "light_color", cfg.dir_color, has_transition)

	for pl_path in point_lights:
		var pl_node := _resolve_node(pl_path)
		if pl_node:
			_tween_light_energy(pl_node, target_point_energy, has_transition)

	if canvas_modulate:
		_tween_property_or_set(canvas_modulate, "color", target_ambient_color, has_transition)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		_tween_property_or_set(env, "ambient_light_color", target_ambient_color, has_transition)
		var brightness := (target_ambient_color.r + target_ambient_color.g + target_ambient_color.b) / 3.0
		var computed := clamp(brightness, 0.02, 1.2)
		if target_ambient_energy >= 0.0:
			computed = target_ambient_energy
		_tween_property_or_set(env, "ambient_light_energy", computed, has_transition)

func _tween_property_or_set(obj: Object, prop: String, value, use_tween: bool) -> void:
	if obj == null:
		return
	if not obj.has_method("set"):
		return
	if not _has_property(obj, prop):
		return
	if use_tween:
		if not _tween:
			_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(obj, prop, value, transition_time)
	else:
		obj.set(prop, value)

func _tween_light_energy(light: Object, value: float, use_tween: bool) -> void:
	var prop := ""
	if _has_property(light, "light_energy"):
		prop = "light_energy"
	elif _has_property(light, "energy"):
		prop = "energy"
	if prop == "":
		return
	_tween_property_or_set(light, prop, value, use_tween)

func _has_property(obj: Object, prop: String) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and p.name == prop:
			return true
	return false

func _resolve_node(value) -> Node:
	if value is Node:
		return value
	if value is NodePath and value != NodePath(""):
		return get_node_or_null(value)
	return null



func force_phase(index: int, preserve_timer: bool = false) -> void:
	if index < 0 or index >= phase_configs.size():
		_fatal("Phase index %d out of range (force_phase)" % index)
	current_phase_index = index
	var cfg := phase_configs[index]
	if not preserve_timer:
		_enter_phase(index)
	else:
		_apply_phase_transition(cfg, false)
		emit_signal("phase_changed", cfg.name, index, current_day)

func phase_progress() -> float:
	if _phase_target_duration <= 0.0:
		return 1.0
	return clamp(_phase_timer / _phase_target_duration, 0.0, 1.0)

func serialize_state() -> Dictionary:
	return {
		"current_phase_index": current_phase_index,
		"current_day": current_day,
		"phase_timer": _phase_timer,
		"current_phase_name": phase_configs.size() > 0 and phase_configs[current_phase_index].name or StringName()
	}

func restore_state(data: Dictionary) -> void:
	_ensure_defaults_if_empty()
	if data.has("current_phase_index"):
		current_phase_index = int(data["current_phase_index"])
	if data.has("current_day"):
		current_day = int(data["current_day"])
	if data.has("phase_timer"):
		_phase_timer = float(data["phase_timer"])
	if current_phase_index < 0 or current_phase_index >= phase_configs.size():
		current_phase_index = 0
	var cfg := phase_configs[current_phase_index]
	_phase_target_duration = cfg.duration
	_apply_phase_transition(cfg, true)

func add_phase(cfg: DayPhaseConfig, index: int = -1) -> void:
	if index < 0 or index > phase_configs.size():
		index = phase_configs.size()
	phase_configs.insert(index, cfg)

func remove_phase(index: int) -> void:
	if index < 0 or index >= phase_configs.size():
		_fatal("Phase index %d out of range (remove_phase)" % index)
	phase_configs.remove_at(index)
	if phase_configs.is_empty():
		_fatal("All phases removed")
	if current_phase_index >= phase_configs.size():
		current_phase_index = phase_configs.size() - 1

func find_phase_index(name: StringName) -> int:
	for i in phase_configs.size():
		if phase_configs[i].name == name:
			return i
	return -1

func force_phase_by_name(name: StringName, preserve_timer: bool = false) -> void:
	var i := find_phase_index(name)
	if i == -1:
		_fatal("Phase '%s' not found" % [name])
	force_phase(i, preserve_timer)

func _fatal(msg: String) -> void:
	push_error("[DayNightCycle:FATAL] %s" % msg)
	if OS.is_debug_build():
		assert(false, msg)
	get_tree().quit(1)

func _ensure_defaults_if_empty() -> void:
	if phase_configs.is_empty():
		var morning := DayPhaseConfig.new(); morning.name = &"MORNING"; morning.duration = morning_duration; morning.dir_energy = dir_energy_morning; morning.point_energy = point_energy_morning; morning.ambient_color = ambient_color_morning
		var day := DayPhaseConfig.new(); day.name = &"DAY"; day.duration = day_duration; day.dir_energy = dir_energy_day; day.point_energy = point_energy_day; day.ambient_color = ambient_color_day
		var evening := DayPhaseConfig.new(); evening.name = &"EVENING"; evening.duration = evening_duration; evening.dir_energy = dir_energy_evening; evening.point_energy = point_energy_evening; evening.ambient_color = ambient_color_evening
		var night := DayPhaseConfig.new(); night.name = &"NIGHT"; night.duration = night_duration; night.dir_energy = dir_energy_night; night.point_energy = point_energy_night; night.ambient_color = ambient_color_night
		phase_configs.append_array([morning, day, evening, night])
