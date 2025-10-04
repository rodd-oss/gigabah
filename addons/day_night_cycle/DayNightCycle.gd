@tool
class_name DayNightCycle
extends Node

# ...existing code will be brought over below (kept identical except minor header adjusted)...
## Универсальный компонент цикла День/Ночь для Godot 4.5 (Addon Version)
## (См. README в папке плагина)

signal phase_changed(phase: StringName, state_index: int, day_index: int)
signal new_day_started(day_index: int)

@export_enum("MORNING", "DAY", "EVENING", "NIGHT") var _dummy_enum:int = 0

enum Phase {
    MORNING,
    DAY,
    EVENING,
    NIGHT,
}

var current_phase: Phase = Phase.MORNING : set = _set_current_phase
var current_day: int = 1

# Fallback duration used only if an unknown phase is encountered (should never happen).
const DEFAULT_PHASE_DURATION: float = 10.0

@export var morning_duration: float = 20.0
@export var day_duration: float = 30.0
@export var evening_duration: float = 20.0
@export var night_duration: float = 30.0

@export var directional_light: Node = null
@export var point_lights: Array[Node] = []
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

var _phase_timer: float = 0.0
var _phase_target_duration: float = 0.0
var _active: bool = false
var _tween: Tween

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if autostart:
        start_cycle()

func start_cycle(reset: bool = true) -> void:
    if reset:
        current_phase = Phase.MORNING
        current_day = 1
    _active = true
    _enter_phase(current_phase, true)

func stop_cycle() -> void:
    _active = false

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if not _active:
        return
    _phase_timer += delta
    if _phase_timer >= _phase_target_duration:
        _advance_phase()

func _advance_phase() -> void:
    var next_index := int(current_phase) + 1
    if next_index >= Phase.size():
        current_day += 1
        emit_signal("new_day_started", current_day)
        next_index = Phase.MORNING
    current_phase = next_index as Phase
    _enter_phase(current_phase)

func _enter_phase(phase: Phase, first: bool = false) -> void:
    _phase_timer = 0.0
    _phase_target_duration = _get_phase_duration(phase)
    _apply_phase_transition(phase, first)
    emit_signal("phase_changed", _phase_name(phase), int(phase), current_day)

func _set_current_phase(value: Phase) -> void:
    current_phase = value

func _get_phase_duration(phase: Phase) -> float:
    match phase:
        Phase.MORNING: return morning_duration
        Phase.DAY: return day_duration
        Phase.EVENING: return evening_duration
        Phase.NIGHT: return night_duration
    var msg := "FATAL: Unhandled phase in _get_phase_duration: %s" % [phase]
    push_error(msg)  
    get_tree().quit(1) 
    assert(false, msg)  # Also trip in debug builds.
    return 0.0  # Unreachable; added only to satisfy return expectation.

func _phase_name(phase: Phase) -> StringName:
    match phase:
        Phase.MORNING: return &"MORNING"
        Phase.DAY: return &"DAY"
        Phase.EVENING: return &"EVENING"
        Phase.NIGHT: return &"NIGHT"
    return &"UNKNOWN"

func _apply_phase_transition(phase: Phase, instant: bool) -> void:
    if _tween and _tween.is_running():
        _tween.kill()
    _tween = null

    var target_dir_energy := _energy_for_phase(phase)
    var target_point_energy := _point_energy_for_phase(phase)
    var target_ambient_color := _ambient_for_phase(phase)

    var has_transition := transition_time > 0.0 and not instant
    if has_transition:
        _tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    if directional_light and directional_light.has_method("set"):
        _tween_property_or_set(directional_light, "energy", target_dir_energy, has_transition)

    for pl in point_lights:
        if pl and pl.has_method("set"):
            _tween_property_or_set(pl, "energy", target_point_energy, has_transition)

    if canvas_modulate:
        _tween_property_or_set(canvas_modulate, "color", target_ambient_color, has_transition)

    if world_environment and world_environment.environment:
        var env := world_environment.environment
        _tween_property_or_set(env, "ambient_light_color", target_ambient_color, has_transition)
        var brightness := (target_ambient_color.r + target_ambient_color.g + target_ambient_color.b) / 3.0
        _tween_property_or_set(env, "ambient_light_energy", clamp(brightness, 0.05, 1.2), has_transition)

func _tween_property_or_set(obj: Object, prop: String, value, use_tween: bool) -> void:
    if use_tween and _tween:
        _tween.tween_property(obj, prop, value, transition_time)
    else:
        obj.set(prop, value)

func _energy_for_phase(phase: Phase) -> float:
    match phase:
        Phase.MORNING: return dir_energy_morning
        Phase.DAY: return dir_energy_day
        Phase.EVENING: return dir_energy_evening
        Phase.NIGHT: return dir_energy_night
    return 1.0

func _point_energy_for_phase(phase: Phase) -> float:
    match phase:
        Phase.MORNING: return point_energy_morning
        Phase.DAY: return point_energy_day
        Phase.EVENING: return point_energy_evening
        Phase.NIGHT: return point_energy_night
    return 0.0

func _ambient_for_phase(phase: Phase) -> Color:
    match phase:
        Phase.MORNING: return ambient_color_morning
        Phase.DAY: return ambient_color_day
        Phase.EVENING: return ambient_color_evening
        Phase.NIGHT: return ambient_color_night
    return Color.WHITE

func force_phase(phase: Phase, preserve_timer: bool = false) -> void:
    current_phase = phase
    if not preserve_timer:
        _enter_phase(phase)
    else:
        _apply_phase_transition(phase, false)
        emit_signal("phase_changed", _phase_name(phase), int(phase), current_day)

func phase_progress() -> float:
    if _phase_target_duration <= 0.0:
        return 1.0
    return clamp(_phase_timer / _phase_target_duration, 0.0, 1.0)

func serialize_state() -> Dictionary:
    return {
        "current_phase": int(current_phase),
        "current_day": current_day,
        "phase_timer": _phase_timer
    }

func restore_state(data: Dictionary) -> void:
    if data.has("current_phase"):
        current_phase = data["current_phase"]
    if data.has("current_day"):
        current_day = data["current_day"]
    if data.has("phase_timer"):
        _phase_timer = data["phase_timer"]
    _phase_target_duration = _get_phase_duration(current_phase)
    _apply_phase_transition(current_phase, true)
