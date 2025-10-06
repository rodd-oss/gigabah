extends Control
## Скрипт главного меню.
## Назначение:
##  - Показать идентификатор сервера (пока заглушка)
##  - Отображать статус соединения (offline/connecting/online) переданный извне
##  - Показывать пинг через сигнал `ping_updated` из NetworkManager (если присутствует)
##  - Обработать только кнопку выхода.
## НЕ делает:
##  - Инициацию сетевого подключения
##  - Смену сцен или создание NetworkManager
##  - Любые таймауты/ретраи
## Кнопка Connect (если есть в UI) должна быть визуальной и не связана с этим скриптом.

@onready var exit_button: Button = $Center/VBox/ExitButton
@onready var server_id_label: Label = $Center/VBox/ServerInfo/ServerIdLabel
@onready var server_status_label: Label = $Center/VBox/ServerInfo/ServerStatusLabel
@onready var ping_label: Label = $Center/VBox/ServerInfo/PingLabel
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var connect_button: Button = $Center/VBox/ConnectButton

const SERVER_ID: String = "#0001" # Заглушка до интеграции реального списка серверов
var _last_ping_ms: int = -1 # Последний пинг полученный извне (через сигнал NetworkManager)
var _preconnect_ping_ms: int = -1 # Оценка до подключения через системный ping
const SERVER_ADDRESS: String = "gigabuh.d.roddtech.ru"
var _ping_in_progress: bool = false

func _ready() -> void:
	server_id_label.text = "Server: %s" % SERVER_ID
	server_status_label.text = "Status: offline"
	ping_label.text = "Ping: -- ms"
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	# Автозагрузка доступна как узел /root/NetworkManager (а не Engine singleton).
	var nm: Node = get_tree().root.get_node_or_null("NetworkManager")
	if nm:
		# Пробуем типизированный каст (если нужно будет расширять API)
		if nm.has_signal("ping_updated"):
			nm.connect("ping_updated", Callable(self, "_on_ping_updated"))
		if nm.has_signal("connectivity_phase_changed"):
			nm.connect("connectivity_phase_changed", Callable(self, "_on_phase_changed"))
		# Немедленная синхронизация статуса
		if nm.has_method("get_current_phase"):
			_on_phase_changed(nm.get_current_phase())
		if nm.has_method("get_last_ping_ms"):
			var lp: int = nm.get_last_ping_ms()
			if lp >= 0:
				_on_ping_updated(lp)
	else:
		print_debug("[MainMenu] NetworkManager not found in /root at _ready()")

	# Запускаем одноразовый pre-connect ping (не игровой RTT)
	_perform_preconnect_ping()

## Удалён устаревший фрагмент автоподключения и смены сцены.

func _process(_delta: float) -> void:
	# Нет активной логики в процессе кадра.
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _push_temp_warning(msg: String) -> void:
	print_debug("[MainMenu] WARNING: %s" % msg)

## Пришёл новый пинг от внешнего менеджера.
func _on_ping_updated(ms: int) -> void:
	_last_ping_ms = ms
	ping_label.text = "Ping: %d ms" % ms

func _show_preconnect_ping() -> void:
	if _last_ping_ms >= 0:
		return # Уже есть игровой пинг — не перезаписываем.
	if _preconnect_ping_ms >= 0:
		ping_label.text = "Ping(est): %d ms" % _preconnect_ping_ms
	else:
		ping_label.text = "Ping: -- ms"

func _perform_preconnect_ping() -> void:
	if _ping_in_progress:
		return
	_ping_in_progress = true
	ping_label.text = "Ping: probing..."
	# Windows / Linux / macOS различаются по ключам. Попробуем универсально определить.
	var is_windows: bool = OS.get_name().to_lower().find("windows") != -1
	var args: PackedStringArray
	if is_windows:
		# -n 1 (один пакет), -w 1000 (таймаут мс). Вывод локализован, парсим 'Average' медленно.
		args = ["ping", "-n", "1", "-w", "1000", SERVER_ADDRESS]
	else:
		# Unix: -c 1 (один пакет), -W 1 (таймаут сек)
		args = ["ping", "-c", "1", "-W", "1", SERVER_ADDRESS]

	# Используем OS.execute в отдельном потоке? В Godot 4 нет прямого async, поэтому делаем call_deferred.
	call_deferred("_run_ping_command", args)

func _run_ping_command(args: PackedStringArray) -> void:
	var output: Array = []
	var exit_code: int = OS.execute(args[0], args.slice(1, args.size()), output, true)
	_ping_in_progress = false
	if exit_code != 0:
		_preconnect_ping_ms = -1
		_show_preconnect_ping()
		return
	var text: String = "".join(output)
	_preconnect_ping_ms = _parse_ping_ms(text)
	_show_preconnect_ping()

func _parse_ping_ms(text: String) -> int:
	# Локализация выводов ping бывает разной. Ищем первое правдоподобное числовое значение рядом с 'ms'.
	# Стратегия:
	# 1. Приводим текст к нижнему регистру.
	# 2. Разбиваем по любым неалфанум символам, но при этом отдельно ищем последовательности цифр.
	# 3. Фильтруем числа по диапазону (0 < n < 100000) — отсекаем абсурдные / timestamp.
	# 4. Предпочитаем число, находящееся в подстроке, где есть 'ms' или 'time' или 'avg'.
	var lower: String = text.to_lower()
	var best: int = -1
	var tokens: PackedStringArray = lower.split("\n")
	for line: String in tokens:
		var candidate: int = _extract_line_ms(line)
		if candidate >= 0:
			best = candidate
			break
	return best

func _extract_line_ms(line: String) -> int:
	# Возвращает первое "разумное" значение мс из строки или -1.
	# Допускаем форматы: 'time=23ms', 'time=23.4 ms', 'avg = 45ms', 'Average = 50ms' (локали: ищем 'avg' / 'time').
	var has_hint: bool = line.find("time") != -1 or line.find("avg") != -1 or line.find("ms") != -1
	if not has_hint:
		return -1
	# Удаляем лишние символы, кроме цифр, точки и пробела, заменяя разделители на пробел.
	var cleaned: String = ""
	for c: String in line:
		if ((c >= '0' and c <= '9') or c == "."):
			cleaned += c
		elif c == " " or c == "\t":
			cleaned += " "
		else:
			cleaned += " "
	# Теперь у нас строка с числами, точками и пробелами. Берём первое число.
	var parts: PackedStringArray = cleaned.split(" ", false)
	for p: String in parts:
		if p == "":
			continue
		var n: float = 0.0
		var ok: bool = true
		# Проверяем валидность (только цифры и максимум одна точка)
		var dot_count: int = 0
		for ch: String in p:
			if ch == ".":
				dot_count += 1
				if dot_count > 1:
					ok = false
			elif not (ch >= '0' and ch <= '9'):
				ok = false
		if not ok:
			continue
		n = p.to_float()
		if n <= 0.0 or n > 100000.0:
			continue
		return int(round(n))
	return -1

## Обновление визуального статуса (ожидаем строки: offline/connecting/online).
func _on_phase_changed(phase: String) -> void:
	_set_status_visual(phase)

func _set_status_visual(phase: String) -> void:
	var text: String
	var color: Color
	match phase:
		"connecting":
			text = "Status: connecting"
			color = Color(1,0.85,0.2)
		"online":
			text = "Status: online"
			color = Color(0.3,1,0.3)
		_: # offline or unknown
			text = "Status: offline"
			color = Color(1,0.4,0.4)
	server_status_label.text = text
	server_status_label.add_theme_color_override("font_color", color)

func _on_connect_pressed() -> void:
	var nm: Node = get_tree().root.get_node_or_null("NetworkManager")
	if not nm:
		print_debug("[MainMenu] NetworkManager not found on connect press")
		return
	if nm.has_method("request_client_connect"):
		# Смена сцены на игровую и после кадра запуск подключения
		get_tree().change_scene_to_file("res://scenes/index.tscn")
		call_deferred("_deferred_connect", nm)
	else:
		print_debug("[MainMenu] request_client_connect not available")

func _deferred_connect(nm: Node) -> void:
	if nm and nm.has_method("request_client_connect"):
		nm.call("request_client_connect")
