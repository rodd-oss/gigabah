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

const SERVER_ID: String = "#0001" # Заглушка до интеграции реального списка серверов
var _last_ping_ms: int = -1 # Последний пинг полученный извне (через сигнал NetworkManager)

func _ready() -> void:
	server_id_label.text = "Server: %s" % SERVER_ID
	server_status_label.text = "Status: offline"
	ping_label.text = "Ping: -- ms"
	exit_button.pressed.connect(_on_exit_pressed)
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

## Удалён устаревший фрагмент автоподключения и смены сцены.

func _process(_delta: float) -> void:
	# Нет активной логики в процессе кадра.
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

func _push_temp_warning(msg: String) -> void:
	print_debug("[MainMenu] WARNING: %s" % msg)

## Пришёл новый пинг от внешнего менеджера.
func _on_ping_updated(ms: int) -> void:
	_last_ping_ms = ms
	ping_label.text = "Ping: %d ms" % ms

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
