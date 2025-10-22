extends Control
"""
Settings Menu (Dynamic): динамическое построение списка действий из InputMap
и поддержка двух клавиш (dual-slot) на одно действие.

Реализованные возможности:
 - Автоматическое перечисление всех действий InputMap (фильтрация по EXCLUDED_ACTION_PREFIXES / EXCLUDED_ACTIONS)
 - Для каждого действия до 2 слотов клавиш (кроме SINGLE_SLOT_ACTIONS с одним слотом)
 - Поддержка клавиатуры (InputEventKey) и мыши (InputEventMouseButton)
 - Переназначение по нажатию на кнопку слота (Esc = отмена)
 - Кнопка Clear (X) для удаления бинда из слота (unbind)
 - Проверка конфликтов: подсветка красным кнопок где один и тот же бинд используется в разных действиях
 - Сохранение/загрузка в user://controls.cfg (ConfigFile)
 - Миграция конфигурации с версии 1 -> 2
 - Сброс к дефолту (DEFAULT_BINDS)
 - Обратный сигнал back_pressed для оверлей режима

Ограничения:
 - Нет проверки конфликтов внутри одного действия (два одинаковых бинда в разных слотах одного действия)
 - Конфликты только подсвечиваются, не блокируют назначение (пользователь сам решает)
 - Нет геймпада/джойстика
 - Модификаторы (Shift/Ctrl/Alt/Meta) сохраняются, но не учитываются в проверке конфликтов

Потенциальные расширения:
 - Блокировка назначения при конфликте с подтверждением
 - Очистка всех биндов действия одной кнопкой
 - Поддержка джойстика/геймпада + отображение иконок
 - Локализация отображаемых названий
"""

signal back_pressed

# Префиксы, которые мы исключаем из динамического списка (например системные ui_* кроме ui_accept)
const EXCLUDED_ACTION_PREFIXES: Array[String] = ["ui_"]
# Системные действия которые не показываем в UI (управление radial menu мышью и т.п.)
const EXCLUDED_ACTIONS: Array[String] = ["radial_menu_click"]

# Действия, для которых разрешён только 1 слот (например кнопка открытия radial menu)
const SINGLE_SLOT_ACTIONS: Array[String] = ["show_radial_menu"]

# Явные человеко-читаемые ярлыки для некоторых action имен (fallback = само имя)
const ACTION_LABELS: Dictionary = {
	"move_left": "Влево",
	"move_right": "Вправо",
	"move_forward": "Вперёд",
	"move_backward": "Назад",
	"ui_accept": "Прыжок",
	"show_radial_menu": "Открыть радиальное меню"
}

# Дефолтные бинды (каждая запись: массив InputEvent dict для сериализации)
# Поддерживаем клавиатуру, мышь и геймпад (joy_button)
const DEFAULT_BINDS: Dictionary = {
	"move_left": [
		{"type": "key", "keycode": KEY_A},
		{"type": "joy_button", "button_index": 14} # DPad Left
	],
	"move_right": [
		{"type": "key", "keycode": KEY_D},
		{"type": "joy_button", "button_index": 15} # DPad Right
	],
	"move_forward": [
		{"type": "key", "keycode": KEY_W},
		{"type": "joy_button", "button_index": 12} # DPad Up
	],
	"move_backward": [
		{"type": "key", "keycode": KEY_S},
		{"type": "joy_button", "button_index": 13} # DPad Down
	],
	"ui_accept": [
		{"type": "key", "keycode": KEY_SPACE},
		{"type": "joy_button", "button_index": 0} # A
	],
	"show_radial_menu": [
		{"type": "key", "keycode": KEY_Q},
		{"type": "joy_button", "button_index": 4} # LB
	]
}

const CONFIG_VERSION: int = 2
const MAX_SLOTS: int = 2

# Цвета для подсветки конфликтов
const COLOR_CONFLICT: Color = Color(1.0, 0.3, 0.3, 1.0)  # Красноватый
const COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)

@onready var tab_container: TabContainer = $VBox/TabContainer
@onready var km_actions_container: VBoxContainer = $VBox/TabContainer/KeyboardMouse/ScrollContainer/ActionsVBox
@onready var gp_actions_container: VBoxContainer = $VBox/TabContainer/Gamepad/ScrollContainer/ActionsVBox
@onready var gp_status_label: Label = $VBox/TabContainer/Gamepad/GamepadStatus
@onready var save_button: Button = $VBox/Buttons/SaveButton
@onready var reset_button: Button = $VBox/Buttons/ResetButton
@onready var back_button: Button = $VBox/Buttons/BackButton

# Текущее состояние захвата
var _capture_action: String = ""
var _capture_slot: int = -1
var _capture_button: Button = null
var _capture_input_type: String = "" # "km" | "gp"

# Кеш строк (Keyboard/Mouse): action_name -> {"row":HBoxContainer, "label":Label, "buttons": [Button, ...], "clear_buttons": [Button, ...]}
var _rows: Dictionary = {}
# Кеш строк (Gamepad)
var _rows_gamepad: Dictionary = {}

# Кеш конфликтов: {action_name: {slot: [conflicting_action_names]}}
var _conflicts: Dictionary = {}


func _ready() -> void:
	_build_dynamic_rows()
	_load_custom_or_apply_defaults()
	_refresh_all_rows()
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _build_dynamic_rows() -> void:
	_build_km_rows()
	_build_gamepad_rows()

func _build_km_rows() -> void:
	for child: Node in km_actions_container.get_children():
		child.queue_free()
	_rows.clear()
	var actions: Array[StringName] = InputMap.get_actions()
	actions.sort()
	for action_name_sn: StringName in actions:
		var action_name: String = String(action_name_sn)
		if _is_action_excluded(action_name):
			continue
		var max_slots: int = _get_max_slots_for_action(action_name)
		var row: HBoxContainer = HBoxContainer.new()
		row.name = action_name
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		km_actions_container.add_child(row)
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(180, 0)
		label.text = ACTION_LABELS.get(action_name, action_name)
		row.add_child(label)
		var buttons: Array[Button] = []
		var clear_buttons: Array[Button] = []
		for slot in range(max_slots):
			var btn: Button = Button.new()
			btn.toggle_mode = true
			btn.name = "%s_km_slot%d" % [action_name, slot]
			btn.text = "—"
			btn.custom_minimum_size = Vector2(120, 0)
			var slot_index := slot
			btn.pressed.connect(func() -> void:
				_on_slot_rebind_pressed(action_name, slot_index, btn, "km")
			)
			row.add_child(btn)
			buttons.append(btn)
			var clear_btn: Button = Button.new()
			clear_btn.name = "%s_km_clear%d" % [action_name, slot]
			clear_btn.text = "X"
			clear_btn.custom_minimum_size = Vector2(30, 0)
			clear_btn.pressed.connect(func() -> void:
				_on_clear_slot_pressed(action_name, slot_index, "km")
			)
			row.add_child(clear_btn)
			clear_buttons.append(clear_btn)
		_rows[action_name] = {"row": row, "label": label, "buttons": buttons, "clear_buttons": clear_buttons}

func _build_gamepad_rows() -> void:
	for child: Node in gp_actions_container.get_children():
		child.queue_free()
	_rows_gamepad.clear()
	var pads := Input.get_connected_joypads()
	gp_status_label.visible = pads.is_empty()
	if pads.is_empty():
		return
	var actions: Array[StringName] = InputMap.get_actions()
	actions.sort()
	for action_name_sn: StringName in actions:
		var action_name: String = String(action_name_sn)
		if _is_action_excluded(action_name):
			continue
		var max_slots: int = _get_max_slots_for_action(action_name)
		var row: HBoxContainer = HBoxContainer.new()
		row.name = action_name + "_gp"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gp_actions_container.add_child(row)
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(180, 0)
		label.text = ACTION_LABELS.get(action_name, action_name)
		row.add_child(label)
		var buttons: Array[Button] = []
		var clear_buttons: Array[Button] = []
		for slot in range(max_slots):
			var btn: Button = Button.new()
			btn.toggle_mode = true
			btn.name = "%s_gp_slot%d" % [action_name, slot]
			btn.text = "—"
			btn.custom_minimum_size = Vector2(120, 0)
			var slot_index := slot
			btn.pressed.connect(func() -> void:
				_on_slot_rebind_pressed(action_name, slot_index, btn, "gp")
			)
			row.add_child(btn)
			buttons.append(btn)
			var clear_btn: Button = Button.new()
			clear_btn.name = "%s_gp_clear%d" % [action_name, slot]
			clear_btn.text = "X"
			clear_btn.custom_minimum_size = Vector2(30, 0)
			clear_btn.pressed.connect(func() -> void:
				_on_clear_slot_pressed(action_name, slot_index, "gp")
			)
			row.add_child(clear_btn)
			clear_buttons.append(clear_btn)
		_rows_gamepad[action_name] = {"row": row, "label": label, "buttons": buttons, "clear_buttons": clear_buttons}

func _is_action_excluded(action_name: String) -> bool:
	if action_name in EXCLUDED_ACTIONS:
		return true
	for prefix: String in EXCLUDED_ACTION_PREFIXES:
		if action_name.begins_with(prefix) and action_name != "ui_accept":
			return true
	return false

func _get_max_slots_for_action(action_name: String) -> int:
	if action_name in SINGLE_SLOT_ACTIONS:
		return 1
	return MAX_SLOTS

func _get_action_events(action_name: String) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not InputMap.has_action(action_name):
		return result
	for e: InputEvent in InputMap.action_get_events(action_name):
		if e is InputEventKey or e is InputEventMouseButton:
			result.append(e)
	return result

func _get_action_events_gamepad(action_name: String) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not InputMap.has_action(action_name):
		return result
	for e: InputEvent in InputMap.action_get_events(action_name):
		if e is InputEventJoypadButton:
			result.append(e)
	return result

func _format_event(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).keycode)
	elif ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
			_: return "Mouse %d" % mb.button_index
	return "—"

func _format_event_gamepad(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		return "Btn %d" % jb.button_index
	return "—"

func _refresh_action_row(action_name: String) -> void:
	if not _rows.has(action_name):
		return
	var info: Dictionary = _rows[action_name]
	var buttons: Array = info["buttons"]
	var events: Array[InputEvent] = _get_action_events(action_name)
	var max_slots: int = _get_max_slots_for_action(action_name)
	for i in range(max_slots):
		var btn: Button = buttons[i]
		if i < events.size():
			btn.text = _format_event(events[i])
		else:
			btn.text = "—"
		btn.button_pressed = (_capture_action == action_name and _capture_slot == i and _capture_input_type == "km")
		if _conflicts.has(action_name) and _conflicts[action_name].has(i):
			btn.modulate = COLOR_CONFLICT
		else:
			btn.modulate = COLOR_NORMAL

func _refresh_action_row_gamepad(action_name: String) -> void:
	if not _rows_gamepad.has(action_name):
		return
	var info: Dictionary = _rows_gamepad[action_name]
	var buttons: Array = info["buttons"]
	var events: Array[InputEvent] = _get_action_events_gamepad(action_name)
	var max_slots: int = _get_max_slots_for_action(action_name)
	for i in range(max_slots):
		var btn: Button = buttons[i]
		if i < events.size():
			btn.text = _format_event_gamepad(events[i])
		else:
			btn.text = "—"
		btn.button_pressed = (_capture_action == action_name and _capture_slot == i and _capture_input_type == "gp")
		# пока без проверки конфликтов для геймпада
		btn.modulate = COLOR_NORMAL

func _refresh_all_rows() -> void:
	_check_conflicts()
	for action_name: String in _rows.keys():
		_refresh_action_row(action_name)
	for action_name: String in _rows_gamepad.keys():
		_refresh_action_row_gamepad(action_name)

func _check_conflicts() -> void:
	"""
	Проверяет конфликты биндов: одна и та же клавиша/кнопка мыши назначена
	на несколько разных действий. Заполняет _conflicts словарь.
	"""
	_conflicts.clear()
	# Построить карту: event_signature -> [(action_name, slot), ...]
	var event_map: Dictionary = {}
	for action_name: String in _rows.keys():
		if not InputMap.has_action(action_name):
			continue
		var events: Array[InputEvent] = _get_action_events(action_name)
		for slot in range(events.size()):
			var ev: InputEvent = events[slot]
			var sig: String = _event_signature(ev)
			if sig == "":
				continue
			if not event_map.has(sig):
				event_map[sig] = []
			event_map[sig].append({"action": action_name, "slot": slot})
	# Найти дубликаты
	for sig: String in event_map.keys():
		var bindings: Array = event_map[sig]
		if bindings.size() > 1:
			# Конфликт!
			for binding: Dictionary in bindings:
				var action: String = binding["action"]
				var slot: int = binding["slot"]
				if not _conflicts.has(action):
					_conflicts[action] = {}
				if not _conflicts[action].has(slot):
					_conflicts[action][slot] = []
				# Добавить все конфликтующие действия (кроме себя)
				for other: Dictionary in bindings:
					if other["action"] != action or other["slot"] != slot:
						_conflicts[action][slot].append(other["action"])

func _event_signature(ev: InputEvent) -> String:
	"""
	Создаёт уникальную строку-подпись события для сравнения.
	Игнорируем модификаторы (shift/alt/ctrl/meta) для упрощения.
	"""
	if ev is InputEventKey:
		var key: InputEventKey = ev as InputEventKey
		return "key:%d" % key.keycode
	elif ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		return "mouse:%d" % mb.button_index
	return ""

func _on_clear_slot_pressed(action_name: String, slot: int, input_type: String) -> void:
	if not InputMap.has_action(action_name):
		return
	var km_events := _get_action_events(action_name)
	var gp_events := _get_action_events_gamepad(action_name)
	if input_type == "km":
		if slot < km_events.size():
			km_events.remove_at(slot)
	elif input_type == "gp":
		if slot < gp_events.size():
			gp_events.remove_at(slot)
	# Перезаписываем все события (сохраняем порядок: KM затем GP)
	InputMap.action_erase_events(action_name)
	for e in km_events:
		InputMap.action_add_event(action_name, e)
	for e in gp_events:
		InputMap.action_add_event(action_name, e)
	_refresh_all_rows()

func _on_slot_rebind_pressed(action_name: String, slot: int, button: Button, input_type: String) -> void:
	if _capture_action == action_name and _capture_slot == slot and _capture_input_type == input_type:
		_cancel_capture()
		return
	_enter_capture(action_name, slot, button, input_type)

func _enter_capture(action_name: String, slot: int, button: Button, input_type: String) -> void:
	_cancel_capture()
	_capture_action = action_name
	_capture_slot = slot
	_capture_button = button
	_capture_input_type = input_type
	var prompt: String = ""
	if input_type == "gp":
		prompt = "Нажмите кнопку геймпада... (Esc отмена)"
	else:
		prompt = "Нажмите клавишу... (Esc отмена)"
	button.text = prompt
	button.button_pressed = true

func _cancel_capture() -> void:
	if _capture_button:
		_capture_button.button_pressed = false
	if _capture_action != "":
		if _capture_input_type == "gp":
			_refresh_action_row_gamepad(_capture_action)
		else:
			_refresh_action_row(_capture_action)
	_capture_action = ""
	_capture_slot = -1
	_capture_button = null
	_capture_input_type = ""

func _unhandled_input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_capture()
			return
		if _capture_input_type == "km":
			_assign_event_to_slot(event)
			accept_event()
		return
	if event is InputEventMouseButton and event.pressed and _capture_input_type == "km":
		_assign_event_to_slot(event)
		accept_event()
		return
	if event is InputEventJoypadButton and event.pressed and _capture_input_type == "gp":
		_assign_event_to_slot(event)
		accept_event()
		return

func _assign_event_to_slot(event: InputEvent) -> void:
	if not InputMap.has_action(_capture_action):
		push_warning("Действие исчезло: %s" % _capture_action)
		_cancel_capture()
		return
	var km_events := _get_action_events(_capture_action)
	var gp_events := _get_action_events_gamepad(_capture_action)
	var new_event: InputEvent = null
	if _capture_input_type == "km":
		if event is InputEventKey:
			var key_ev := event as InputEventKey
			var new_key := InputEventKey.new()
			new_key.keycode = key_ev.keycode
			new_key.shift_pressed = key_ev.shift_pressed
			new_key.alt_pressed = key_ev.alt_pressed
			new_key.ctrl_pressed = key_ev.ctrl_pressed
			new_key.meta_pressed = key_ev.meta_pressed
			new_event = new_key
		elif event is InputEventMouseButton:
			var mb_ev := event as InputEventMouseButton
			var new_mb := InputEventMouseButton.new()
			new_mb.button_index = mb_ev.button_index
			new_event = new_mb
	elif _capture_input_type == "gp" and event is InputEventJoypadButton:
		var jb_ev := event as InputEventJoypadButton
		var new_jb := InputEventJoypadButton.new()
		new_jb.button_index = jb_ev.button_index
		new_event = new_jb
	if new_event == null:
		_cancel_capture()
		return
	if _capture_input_type == "km":
		if _capture_slot < km_events.size():
			km_events[_capture_slot] = new_event
		else:
			while km_events.size() < _capture_slot:
				km_events.append(new_event)
			km_events.append(new_event)
	else:
		if _capture_slot < gp_events.size():
			gp_events[_capture_slot] = new_event
		else:
			while gp_events.size() < _capture_slot:
				gp_events.append(new_event)
			gp_events.append(new_event)
	InputMap.action_erase_events(_capture_action)
	for e in km_events:
		InputMap.action_add_event(_capture_action, e)
	for e in gp_events:
		InputMap.action_add_event(_capture_action, e)
	_cancel_capture()

func _on_reset_pressed() -> void:
	for action_name: String in _rows.keys():
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		if DEFAULT_BINDS.has(action_name):
			for event_dict: Variant in DEFAULT_BINDS[action_name]:
				if typeof(event_dict) != TYPE_DICTIONARY:
					continue
				var d: Dictionary = event_dict
				var ev: InputEvent = _dict_to_event(d)
				if ev:
					InputMap.action_add_event(action_name, ev)
	_refresh_all_rows()

func _dict_to_event(d: Dictionary) -> InputEvent:
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
		var evm: InputEventMouseButton = InputEventMouseButton.new()
		evm.button_index = (int(d.get("button_index", 0)) as MouseButton)
		return evm
	elif event_type == "joy_button":
		var evj: InputEventJoypadButton = InputEventJoypadButton.new()
		evj.button_index = int(d.get("button_index", 0)) as JoyButton
		return evj
	return null

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var key_event := ev as InputEventKey
		return {
			"type": "key",
			"keycode": key_event.keycode,
			"shift": key_event.shift_pressed,
			"alt": key_event.alt_pressed,
			"ctrl": key_event.ctrl_pressed,
			"meta": key_event.meta_pressed
		}
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return {
			"type": "mouse",
			"button_index": mb.button_index
		}
	elif ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		return {
			"type": "joy_button",
			"button_index": jb.button_index
		}
	return {}

func _on_save_pressed() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "version", CONFIG_VERSION)
	var actions: Array[StringName] = InputMap.get_actions()
	for action_name_sn in actions:
		var action_name: String = String(action_name_sn)
		if _is_action_excluded(action_name):
			continue
		var arr: Array[Dictionary] = []
		if InputMap.has_action(action_name):
			var km_events := _get_action_events(action_name)
			var gp_events := _get_action_events_gamepad(action_name)
			for e in km_events:
				var d := _event_to_dict(e)
				if not d.is_empty():
					arr.append(d)
			for e in gp_events:
				var d2 := _event_to_dict(e)
				if not d2.is_empty():
					arr.append(d2)
		cfg.set_value("controls", action_name, arr)
	var err := cfg.save("user://controls.cfg")
	if err != OK:
		push_warning("Не удалось сохранить controls.cfg (%s)" % err)

func _load_custom_or_apply_defaults() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://controls.cfg")
	if err != OK:
		_on_reset_pressed()
		return
	var version: int = cfg.get_value("controls", "version", 0)
	if version not in [1, CONFIG_VERSION]:
		_on_reset_pressed()
		return
	var actions: Array[StringName] = InputMap.get_actions()
	for action_name_sn in actions:
		var action_name: String = String(action_name_sn)
		if _is_action_excluded(action_name):
			continue
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		var stored: Variant = cfg.get_value("controls", action_name, [])
		if stored is Array and not (stored as Array).is_empty():
			var max_slots: int = _get_max_slots_for_action(action_name)
			var km_added := 0
			var gp_added := 0
			for d: Variant in stored:
				if typeof(d) != TYPE_DICTIONARY:
					continue
				var ev: InputEvent = _dict_to_event(d)
				if ev == null:
					continue
				if ev is InputEventJoypadButton:
					if gp_added >= max_slots:
						continue
					InputMap.action_add_event(action_name, ev)
					gp_added += 1
				elif ev is InputEventKey or ev is InputEventMouseButton:
					if km_added >= max_slots:
						continue
					InputMap.action_add_event(action_name, ev)
					km_added += 1
	_refresh_all_rows()

func _on_back_pressed() -> void:
	# Emit signal for in-game menu, or change scene if opened from main menu
	if has_signal("back_pressed") and back_pressed.get_connections().size() > 0:
		back_pressed.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
