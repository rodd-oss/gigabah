extends Node

## Update / Launch Manager (GitHub Releases): получает latest release, скачивает первый ZIP asset и распаковывает.

signal status_changed(text: String)
signal progress_changed(percent: float)
signal versions_known(local_version: String, remote_version: String)
signal update_available(new_version: String)
signal update_finished(success: bool, message: String)
signal changelog_received(text_bbcode: String)

const GAME_DIR := "game"
const VERSION_FILE := GAME_DIR + "/version.json"
const TEMP_DIR := "launcher_tmp"
const DOWNLOAD_FILE := TEMP_DIR + "/package.zip"
## желательно использовать формат SemVer с префиксом v (например v0.1.0) или без.
const GITHUB_OWNER := "rodd-oss"
const GITHUB_REPO := "gigabah"
# Нельзя формировать const через % (не константное выражение) — используем шаблон и собираем позже
const GITHUB_RELEASE_LATEST_API_TEMPLATE := "https://api.github.com/repos/%s/%s/releases/latest"
var GITHUB_RELEASE_LATEST_API: String = "" # инициализируется в _ready
const DEBUG_LOG := true # установить false чтобы отключить отладочные print

# Offline / no-update mode toggle.
const ENABLE_UPDATES := true

# Retry/timeout configuration
const MAX_RETRIES := 3
const RETRY_DELAY_SEC := 2.0

enum DownloadMode { RELEASE_INFO, FULL_PACKAGE }
var _current_mode: DownloadMode = DownloadMode.RELEASE_INFO
var _active_url: String = ""
var _retry_count: int = 0
var _request_start_time: float = 0.0

# Track file size for progress (if provided by manifest or Content-Length)
var _expected_size: int = 0

var manifest: Dictionary # Больше не является ручным manifest.json — это raw JSON ответа GitHub release
var local_version: String = "0.0.0"
var remote_version: String = "?"
var is_update_available: bool = false

# Данные выбранного ассета релиза (ZIP сборка)
var _release_asset_url: String = ""
var _release_asset_size: int = 0
const PLATFORM_PRIORITY: Array[String] = [
	"win64", "windows", "win", "x64", "64", "" # последний пустой = любой ZIP fallback
]

# Кеш выбранного исполняемого файла, чтобы не искать каждый раз
var _cached_exe_path: String = ""

# Список предпочтительных имен exe (если в папке несколько). Первое найденное в этом порядке берётся.
const PREFERRED_EXE_NAMES: Array[String] = [
	"gigabah.exe",
	"godessa.exe",
	"game.exe",
	"client.exe"
]

var http: HTTPRequest
var _downloading: bool = false

func _ready() -> void:
	# Собираем конечный URL releases/latest
	GITHUB_RELEASE_LATEST_API = GITHUB_RELEASE_LATEST_API_TEMPLATE % [GITHUB_OWNER, GITHUB_REPO]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + TEMP_DIR))
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	# В данной сборке движка сигнал request_progress отсутствует → прогресс не стримится.

func start_check() -> void:
	_emit_status("Проверка локальной версии...")
	local_version = _load_local_version()
	# Ранний поиск локального exe: если он найден, мы можем разрешить запуск сразу (пока идёт проверка обновлений)
	var early_exe = get_game_executable_path()
	if early_exe != "":
		# Сообщаем UI локальную версию (даже если 0.0.0) и что запуск возможен
		emit_signal("versions_known", local_version, local_version)
		# Не посылаем update_finished здесь, чтобы не скрыть статус обновления, но даём понять что версия известна
		_emit_status("Локальная игра обнаружена. Проверка обновлений...")
	if not ENABLE_UPDATES:
		# В оффлайн режиме мы не ходим в сеть: если есть версия > 0.0.0 — разрешаем запуск.
		if local_version != "0.0.0":
			emit_signal("versions_known", local_version, local_version)
			emit_signal("update_finished", true, "Оффлайн режим: игра готова")
		else:
			emit_signal("versions_known", local_version, local_version)
			_emit_status("Оффлайн режим: положите сборку в папку game/")
		return
	_emit_status("Запрос последних Releases...")
	_current_mode = DownloadMode.RELEASE_INFO
	_active_url = GITHUB_RELEASE_LATEST_API
	_start_request(GITHUB_RELEASE_LATEST_API)

func download_and_apply_update() -> void:
	if not is_update_available:
		_emit_status("Обновление не требуется")
		return
	if _release_asset_url.is_empty():
		_emit_status("Asset ZIP не выбран")
		return
	_emit_status("Скачивание пакета версии %s..." % remote_version)
	_current_mode = DownloadMode.FULL_PACKAGE
	_active_url = _release_asset_url
	_start_request(_release_asset_url, true, _release_asset_size)

func _try_download_patch_if_available() -> bool:
	return false

func _start_request(url: String, _binary: bool=false, expected_size: int=0) -> void:
	_expected_size = expected_size
	_retry_count = 0
	_downloading = true
	_issue_request(url)

func _issue_request(url: String) -> void:
	_request_start_time = Time.get_unix_time_from_system()
	var headers: PackedStringArray = [
		"User-Agent: GigabahLauncher",
		"Accept: application/vnd.github+json"
	]
	var err = http.request(url, headers)
	if err != OK:
		_emit_status("Ошибка запроса: %s" % err)
		_schedule_retry()

func _schedule_retry() -> void:
	if _retry_count < MAX_RETRIES:
		_retry_count += 1
		_emit_status("Повтор #%d через %.1fс" % [_retry_count, RETRY_DELAY_SEC])
		await get_tree().create_timer(RETRY_DELAY_SEC).timeout
		_issue_request(_active_url)
	else:
		# После исчерпания попыток: если есть локальный exe — разрешаем оффлайн запуск.
		var local_exe = get_game_executable_path()
		if local_exe != "":
			_emit_status("Сеть недоступна, оффлайн запуск")
			emit_signal("update_finished", true, "Оффлайн (без проверки обновлений)")
		else:
			emit_signal("update_finished", false, "Сеть: исчерпаны повторы")

# NOTE: Сигнала прогресса здесь нет; если потребуется настоящий прогресс — перейти на ручной HTTPClient.

func get_game_executable_path() -> String:
	# Если уже определяли ранее — возвращаем кеш
	if _cached_exe_path != "" and FileAccess.file_exists(_cached_exe_path):
		return _cached_exe_path

	_debug("Начинаю поиск exe...")

	# Поиск в стандартной папке res://game
	var found := _find_exe_in_folder("res://" + GAME_DIR)
	if found != "":
		_cached_exe_path = ProjectSettings.globalize_path(found)
		_debug("Нашёл в res://game: %s" % _cached_exe_path)
		return _cached_exe_path

	# 3. Поиск рядом с лаунчером (если пользователь положил игру не в game/, а рядом)
	#    Получаем абсолютный путь лаунчера и ищем .exe в той же директории
	var launcher_dir_abs = OS.get_executable_path().get_base_dir()
	var found_side = _find_exe_in_absolute_folder(launcher_dir_abs)
	if found_side != "":
		_cached_exe_path = found_side
		_debug("Нашёл рядом с лаунчером: %s" % _cached_exe_path)
		return _cached_exe_path

	# 4. Поиск в подкаталоге game относительно директории бинарника
	var abs_game = launcher_dir_abs.path_join(GAME_DIR)
	var found_in_abs_game = _find_exe_in_absolute_folder(abs_game)
	if found_in_abs_game != "":
		_cached_exe_path = found_in_abs_game
		_debug("Нашёл в подпапке game у бинарника лаунчера: %s" % _cached_exe_path)
		return _cached_exe_path

	# 5. Попытка: на один уровень выше (сценарий: launcher/ и game/ соседние в корне)
	var parent = launcher_dir_abs.get_base_dir()
	var sibling_game = parent.path_join(GAME_DIR)
	var found_sibling = _find_exe_in_absolute_folder(sibling_game)
	if found_sibling != "":
		_cached_exe_path = found_sibling
		_debug("Нашёл в соседней папке game: %s" % _cached_exe_path)
		return _cached_exe_path

	return ""

func _debug(msg: String) -> void:
	if DEBUG_LOG:
		print("[LauncherDebug] ", msg)

func _find_exe_in_folder(res_path: String) -> String:
	var dir := DirAccess.open(res_path)
	if dir:
		dir.list_dir_begin()
		var preferred: String = ""
		var f = dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.to_lower().ends_with(".exe"):
				var lower = f.to_lower()
				if PREFERRED_EXE_NAMES.has(lower):
					_debug("Предпочтительный exe в %s: %s" % [res_path, lower])
					return res_path + "/" + f
				if preferred == "":
					preferred = res_path + "/" + f
			f = dir.get_next()
		if preferred != "":
			_debug("Выбран первый найденный exe (нет предпочитаемых): %s" % preferred)
			return preferred
	return ""

func _find_exe_in_absolute_folder(abs_path: String) -> String:
	if abs_path == "":
		return ""
	var dir := DirAccess.open(abs_path)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		var self_exe_name = OS.get_executable_path().get_file().to_lower()
		var self_exe_full = OS.get_executable_path().to_lower()
		var preferred: String = ""
		while f != "":
			if not dir.current_is_dir() and f.to_lower().ends_with(".exe"):
				var fname = f.to_lower()
				var full_candidate = abs_path.path_join(f)
				var full_candidate_lower = full_candidate.to_lower()
				# Пропускаем только если это ТОЧНО тот же бинарник лаунчера (полный путь совпадает)
				if full_candidate_lower == self_exe_full:
					_debug("Skip exact launcher exe path: %s" % full_candidate_lower)
					f = dir.get_next()
					continue
				# Если имя содержит 'launcher' — предполагаем что это тоже лаунчер
				if fname.contains("launcher"):
					_debug("Skip launcher-like by name: %s" % fname)
					f = dir.get_next()
					continue
				# Если имя совпадает с именем лаунчера, но путь другой — разрешаем (редкий кейс: копия движка как игра)
				if fname == self_exe_name:
					_debug("Allow same filename as launcher in different folder: %s" % full_candidate_lower)
				if PREFERRED_EXE_NAMES.has(fname):
					_debug("Предпочтительный exe в %s: %s" % [abs_path, fname])
					return full_candidate
				if preferred == "":
					preferred = full_candidate
				_debug("Кандидат exe (abs) в %s: %s" % [abs_path, fname])
			f = dir.get_next()
		if preferred != "":
			_debug("Выбран первый найденный exe (abs, нет предпочитаемых): %s" % preferred)
			return preferred
	return ""

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_status("Ошибка сети: %s" % result)
		_schedule_retry()
		return
	if response_code != 200:
		_emit_status("HTTP %s" % response_code)
		_schedule_retry()
		return
	var content_type = _get_header_value(headers, "content-type")
	if content_type.contains("application/zip"):
		_save_download(body)
		await get_tree().process_frame
		_verify_and_install()
	else:
		var text = body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			_emit_status("Некорректный JSON ответа")
			return
		manifest = data
		# GitHub release fields: tag_name, body, assets[]
		var tag_name: String = str(manifest.get("tag_name", "?"))
		# Убираем возможный префикс 'v'
		if tag_name.begins_with("v") and tag_name.length() > 1:
			remote_version = tag_name.substr(1, tag_name.length() - 1)
		else:
			remote_version = tag_name
		# Преобразуем markdown body в простой BBCode (минимально)
		var body_md: String = str(manifest.get("body", ""))
		var bbcode = _markdown_to_basic_bbcode(body_md, remote_version)
		emit_signal("versions_known", local_version, remote_version)
		emit_signal("changelog_received", bbcode)
		# Выбор ZIP ассета с приоритетом по платформе
		_release_asset_url = ""
		_release_asset_size = 0
		var chosen_score := 9999
		var assets = manifest.get("assets", [])
		if typeof(assets) == TYPE_ARRAY:
			for a in assets:
				if typeof(a) != TYPE_DICTIONARY:
					continue
				var asset_name: String = str(a.get("name", ""))
				var lower = asset_name.to_lower()
				if not lower.ends_with(".zip"):
					continue
				var score = _score_platform_asset(lower)
				if score < chosen_score:
					chosen_score = score
					_release_asset_url = str(a.get("browser_download_url", ""))
					_release_asset_size = int(a.get("size", 0))
		if _release_asset_url == "":
			_emit_status("Не найден ZIP asset в релизе")
			return
		if _version_is_newer(remote_version, local_version):
			is_update_available = true
			emit_signal("update_available", remote_version)
			_emit_status("Обновление доступно")
		else:
			_emit_status("Актуальная версия")
			emit_signal("update_finished", true, "Актуальная версия")

func _save_download(bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + TEMP_DIR))
	var file = FileAccess.open("res://" + DOWNLOAD_FILE, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file.close()
		emit_signal("progress_changed", 100.0)
		_emit_status("Пакет скачан")
	else:
		_emit_status("Не удалось сохранить пакет")

func _verify_and_install() -> void:
	# Для GitHub Releases пока нет встроенной проверки SHA-256 (можно добавить, если опубликовать *.sha256)
	_emit_status("Распаковка...")
	var ok = _unpack_zip_to_game("res://" + DOWNLOAD_FILE)
	if not ok:
		emit_signal("update_finished", false, "Ошибка распаковки")
		return
	_write_local_version(remote_version)
	_emit_status("Обновление завершено")
	emit_signal("update_finished", true, "Обновление завершено")

func _load_local_version() -> String:
	if FileAccess.file_exists(VERSION_FILE):
		var f = FileAccess.open(VERSION_FILE, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY and data.has("game_version"):
				return str(data["game_version"])
	return "0.0.0"

func _write_local_version(ver: String) -> void:
	var f = FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	if f:
		var d = {"game_version": ver, "updated_at": Time.get_datetime_string_from_system()}
		f.store_string(JSON.stringify(d))
		f.close()

func _version_is_newer(remote: String, local: String) -> bool:
	var r_parts = remote.split('.')
	var l_parts = local.split('.')
	for i in range(max(r_parts.size(), l_parts.size())):
		var r = int(r_parts[i]) if i < r_parts.size() else 0
		var l = int(l_parts[i]) if i < l_parts.size() else 0
		if r > l:
			return true
		if r < l:
			return false
	return false

func _markdown_to_basic_bbcode(md: String, version: String) -> String:
	if md.is_empty():
		return "[b]%s[/b]\nНет описания изменений." % version
	var lines = md.split('\n')
	var out: Array[String] = []
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.begins_with("### "):
			out.append("[b]%s[/b]" % trimmed.substr(4, trimmed.length()))
		elif trimmed.begins_with("## "):
			out.append("[b]%s[/b]" % trimmed.substr(3, trimmed.length()))
		elif trimmed.begins_with("# "):
			out.append("[center][b]%s[/b][/center]" % trimmed.substr(2, trimmed.length()))
		elif trimmed.begins_with("-") or trimmed.begins_with("*"):
			out.append("• " + trimmed.lstrip("-* "))
		else:
			out.append(trimmed)
	return "\n".join(out)

func _score_platform_asset(name: String) -> int:
	# Чем меньше score — тем выше приоритет
	for i in range(PLATFORM_PRIORITY.size()):
		var key = PLATFORM_PRIORITY[i]
		if key == "":
			# Пустая строка = универсальный fallback (возьмётся если ничего лучше не найдено)
			return i + 50 # сдвиг чтобы любой явный матч был лучше
		if name.contains(key):
			return i
	return 1000

func is_downloading() -> bool:
	return _downloading

func _unpack_zip_to_game(zip_path: String) -> bool:
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + GAME_DIR))
	for file_path in reader.get_files():
		if file_path.ends_with('/'):
			continue
		var data: PackedByteArray = reader.read_file(file_path)
		var target_rel = GAME_DIR + "/" + file_path
		var target_dir_rel = target_rel.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + target_dir_rel))
		var out_f = FileAccess.open(target_rel, FileAccess.WRITE)
		if not out_f:
			return false
		out_f.store_buffer(data)
		out_f.close()
	reader.close()
	return true

##

func _get_header_value(headers: PackedStringArray, key: String) -> String:
	var key_l = key.to_lower()
	for h in headers:
		var parts = h.split(':', false, 2)
		if parts.size() == 2 and parts[0].strip_edges().to_lower() == key_l:
			return parts[1].strip_edges()
	return ""

func _emit_status(t: String) -> void:
	emit_signal("status_changed", t)
