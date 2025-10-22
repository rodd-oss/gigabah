extends Node
"""
InputConfigLoader: автоматическая загрузка пользовательских биндов при старте игры.
Этот autoload гарантирует что настройки управления применяются до загрузки основной сцены.
"""

const CONFIG_PATH: String = "user://controls.cfg"
const CONFIG_VERSION: int = 2


func _ready() -> void:
	_load_custom_binds()


func _load_custom_binds() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		# Конфиг не существует, используем дефолты из project.godot
		return

	var version: int = cfg.get_value("controls", "version", 0)
	if version not in [1, CONFIG_VERSION]:
		push_warning("Unsupported controls config version: %d" % version)
		return

	# Получить все сохранённые действия
	var actions: Array = cfg.get_section_keys("controls")
	for action_key: String in actions:
		if action_key == "version":
			continue

		var action_name: String = action_key
		if not InputMap.has_action(action_name):
			continue

		var stored: Variant = cfg.get_value("controls", action_name, [])
		if stored is Array and not (stored as Array).is_empty():
			# Очистить существующие бинды
			InputMap.action_erase_events(action_name)

			# Загрузить сохранённые
			for d: Variant in stored:
				if typeof(d) != TYPE_DICTIONARY:
					continue
				var ev: InputEvent = _dict_to_event(d)
				if ev:
					InputMap.action_add_event(action_name, ev)


func _dict_to_event(d: Dictionary) -> InputEvent:
	"""Преобразует словарь с описанием события в InputEvent."""
	var event_type: String = d.get("type", "")
	if event_type == "key":
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = (int(d.get("keycode", 0)) as Key)
		ev.shift_pressed = bool(d.get("shift", false))
		ev.alt_pressed = bool(d.get("alt", false))
		ev.ctrl_pressed = bool(d.get("ctrl", false))
		ev.meta_pressed = bool(d.get("meta", false))
		return ev
	elif event_type == "mouse":
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = (int(d.get("button_index", 0)) as MouseButton)
		return ev
	return null
