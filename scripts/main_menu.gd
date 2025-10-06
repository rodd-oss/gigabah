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
const STATUS_UI: Dictionary = {
	"offline": {"text": "Status: offline", "color": Color(1,0.4,0.4)},
	"connecting": {"text": "Status: connecting", "color": Color(1,0.85,0.2)},
	"online": {"text": "Status: online", "color": Color(0.3,1,0.3)},
	"available": {"text": "Status: available", "color": Color(0.6,0.9,0.3)} # Только для probe
}
var _last_ping_ms: int = -1 # RTT игровой сессии (если появится)
var _probe_latency_ms: int = -1 # Предварительный пинг до подключения (через ServerStatusProbe)
var _server_online: bool = false

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
		if nm.has_signal("ping_updated"):
			nm.connect("ping_updated", Callable(self, "_on_ping_updated"))
		# New enum-based signal
		if nm.has_signal("connectivity_status_changed"):
			nm.connect("connectivity_status_changed", Callable(self, "_on_status_changed"))
		# Immediate sync (prefer enum helpers if exposed)
		if nm.has_method("get_status_string"):
			_on_status_string_changed(nm.call("get_status_string"))
		if nm.has_method("get_last_ping_ms"):
			var lp: int = nm.get_last_ping_ms()
			if lp >= 0:
				_on_ping_updated(lp)
	else:
		print_debug("[MainMenu] NetworkManager not found in /root at _ready()")

	# Подписка на внешний пробер (автолоад ServerStatusProbe)
	var probe: ServerStatusProbeAutoload = get_tree().root.get_node_or_null("ServerStatusProbe") as ServerStatusProbeAutoload
	if probe:
		if probe.has_signal("status_updated"):
			probe.connect("status_updated", Callable(self, "_on_probe_status"))
		# Запрос первого измерения
		probe.request_probe()
	else:
		print_debug("[MainMenu] ServerStatusProbe not found — no pre-connect status")

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

## Статус получен от ServerStatusProbe (до игрового подключения).
func _on_probe_status(online: bool, latency_ms: int) -> void:
	_server_online = online
	_probe_latency_ms = latency_ms
	if _last_ping_ms < 0: # Пока нет игрового RTT
		if online and latency_ms >= 0:
			ping_label.text = "Ping(est): %d ms" % latency_ms
		else:
			ping_label.text = "Ping: -- ms"
	# Если уже подключён NetworkManager и он будет менять статус сам – не вмешиваемся.
	var nm: Node = get_tree().root.get_node_or_null("NetworkManager")
	if nm and nm.has_method("get_status_string"):
		var current_status: String = nm.call("get_status_string")
		if current_status == "online":
			return
	# Обновляем предварительный статус сервера.
	if online:
		server_status_label.text = "Status: available"
		server_status_label.add_theme_color_override("font_color", Color(0.6,0.9,0.3))
	else:
		server_status_label.text = "Status: offline"
		server_status_label.add_theme_color_override("font_color", Color(1,0.4,0.4))

## Обновление визуального статуса (ожидаем строки: offline/connecting/online) уже внутри игровой сессии.
func _on_status_changed(status: int) -> void:
	var status_str: String = "offline"
	match status:
		0:
			status_str = "offline"
		1:
			status_str = "connecting"
		2:
			status_str = "online"
	_set_status_visual(status_str)

func _on_status_string_changed(status_str: String) -> void:
	_set_status_visual(status_str)

func _set_status_visual(key: String) -> void:
	var entry: Dictionary = STATUS_UI.get(key, STATUS_UI["offline"])
	server_status_label.text = entry["text"]
	server_status_label.add_theme_color_override("font_color", entry["color"])

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
