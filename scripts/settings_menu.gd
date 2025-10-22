extends Control
"""
Settings Menu: позволяет игроку переназначать управляющие клавиши.
Функционал:
 - Просмотр текущих биндов действий move_left/right/forward/backward, ui_accept
 - Переназначение клавиши (одна клавиша per action) по нажатию на кнопку
 - Сброс к дефолту
 - Сохранение/загрузка в user://controls.cfg (ConfigFile)
 - Возврат назад в главное меню

Ограничения текущей версии:
 - Поддерживаются только клавиши клавиатуры (InputEventKey)
 - Без проверки на конфликты (дубликаты возможны)
 - Без геймпада/мыши

Расширения в будущем:
 - Множественные клавиши на действие
 - Поддержка мыши/геймпада
 - Проверка конфликтов, всплывающие подтверждения
 - Локализация названий действий
"""

const ACTIONS: Array[Dictionary] = [
	{"name":"move_left", "label":"Влево"},
	{"name":"move_right", "label":"Вправо"},
	{"name":"move_forward", "label":"Вперёд"},
	{"name":"move_backward", "label":"Назад"},
	{"name":"ui_accept", "label":"Прыжок"}
]

# Дефолтные бинды (keycodes)
const DEFAULT_BINDS: Dictionary = {
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_forward": [KEY_W],
	"move_backward": [KEY_S],
	"ui_accept": [KEY_SPACE]
}

@onready var actions_container: VBoxContainer = $VBox/ScrollContainer/ActionsVBox
@onready var save_button: Button = $VBox/Buttons/SaveButton
@onready var reset_button: Button = $VBox/Buttons/ResetButton
@onready var back_button: Button = $VBox/Buttons/BackButton

var _capture_action: String = ""
var _capture_button: Button = null

func _ready() -> void:
	# Bind existing buttons added via scene.
	for action_data: Dictionary in ACTIONS:
		var action_name: String = action_data.name
		var row: HBoxContainer = actions_container.get_node_or_null(action_name) as HBoxContainer
		if not row:
			push_warning("Row node missing for action: %s" % action_name)
			continue
		# Expect button child named same as action
		var btn: Button = row.get_node_or_null("Button") as Button
		if not btn:
			push_warning("Button missing in row: %s" % action_name)
			continue
		btn.name = action_name # ensure name matches for later lookups
		btn.text = _get_action_events_text(action_name)
		btn.pressed.connect(func() -> void: _on_rebind_pressed(action_name, btn))
	_load_custom_or_apply_defaults()
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _get_action_events_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "(нет действия)"
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "—"
	var parts: Array[String] = []
	for e: InputEvent in events:
		if e is InputEventKey:
			parts.append(OS.get_keycode_string((e as InputEventKey).keycode))
	return ", ".join(parts)

func _on_rebind_pressed(action_name: String, button: Button) -> void:
	if _capture_action == action_name:
		_cancel_capture()
		return
	_enter_capture(action_name, button)

func _enter_capture(action_name: String, button: Button) -> void:
	_cancel_capture()
	_capture_action = action_name
	_capture_button = button
	button.text = "Нажмите клавишу... (Esc отмена)"
	button.button_pressed = true

func _cancel_capture() -> void:
	if _capture_button:
		_capture_button.button_pressed = false
		if _capture_action != "":
			_capture_button.text = _get_action_events_text(_capture_action)
	_capture_action = ""
	_capture_button = null

func _unhandled_input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_capture()
			return
		if not InputMap.has_action(_capture_action):
			push_warning("Действие исчезло: %s" % _capture_action)
			_cancel_capture()
			return
		InputMap.action_erase_events(_capture_action)
		var new_event: InputEventKey = InputEventKey.new()
		new_event.keycode = event.keycode
		new_event.shift_pressed = event.shift_pressed
		new_event.alt_pressed = event.alt_pressed
		new_event.ctrl_pressed = event.ctrl_pressed
		new_event.meta_pressed = event.meta_pressed
		InputMap.action_add_event(_capture_action, new_event)
		if _capture_button:
			_capture_button.text = _get_action_events_text(_capture_action)
		_capture_button.button_pressed = false
		_capture_action = ""
		_capture_button = null
		accept_event()

func _on_reset_pressed() -> void:
	for action_name: String in DEFAULT_BINDS.keys():
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		for kc: int in DEFAULT_BINDS[action_name]:
			var ev: InputEventKey = InputEventKey.new()
			ev.keycode = (kc as Key)
			InputMap.action_add_event(action_name, ev)
	# Обновить подписи
	for child: Node in actions_container.get_children():
		for sub: Node in child.get_children():
			if sub is Button:
				sub.text = _get_action_events_text(sub.name)

func _on_save_pressed() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "version", 1)
	for action_data: Dictionary in ACTIONS:
		var action_name: String = action_data.name
		var arr: Array[Dictionary] = []
		if InputMap.has_action(action_name):
			for e: InputEvent in InputMap.action_get_events(action_name):
				if e is InputEventKey:
					var key_event: InputEventKey = e
					arr.append({
						"type": "key",
						"keycode": key_event.keycode,
						"shift": key_event.shift_pressed,
						"alt": key_event.alt_pressed,
						"ctrl": key_event.ctrl_pressed,
						"meta": key_event.meta_pressed
					})
		cfg.set_value("controls", action_name, arr)
	var err: int = cfg.save("user://controls.cfg")
	if err != OK:
		push_warning("Не удалось сохранить controls.cfg (%s)" % err)

func _load_custom_or_apply_defaults() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load("user://controls.cfg")
	if err != OK:
		_on_reset_pressed()
		return
	if cfg.get_value("controls", "version", 0) != 1:
		_on_reset_pressed()
		return
	for action_data: Dictionary in ACTIONS:
		var action_name: String = action_data.name
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		var stored: Variant = cfg.get_value("controls", action_name, [])
		if stored is Array and not (stored as Array).is_empty():
			for d: Variant in stored:
				if typeof(d) != TYPE_DICTIONARY:
					continue
				var dict_d: Dictionary = d
				if dict_d.get("type","") != "key":
					continue
				var ev: InputEventKey = InputEventKey.new()
				ev.keycode = (int(dict_d.get("keycode", 0)) as Key)
				ev.shift_pressed = bool(dict_d.get("shift", false))
				ev.alt_pressed = bool(dict_d.get("alt", false))
				ev.ctrl_pressed = bool(dict_d.get("ctrl", false))
				ev.meta_pressed = bool(dict_d.get("meta", false))
				InputMap.action_add_event(action_name, ev)
	# Обновить подписи
	for child: Node in actions_container.get_children():
		for sub: Node in child.get_children():
			if sub is Button:
				sub.text = _get_action_events_text(sub.name)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
