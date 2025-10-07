extends Node

## Update / Launch Manager
## Основные задачи:
## 1. Определить локальную версию (если есть) и разрешить запуск игры.
## 2. (Когда включено) Загрузить manifest.json, сравнить версии и скачать обновление (полный ZIP или патч).
## 3. Предоставить путь к .exe для запуска.
##
## Текущая реализация использует HTTPRequest (Godot 4.5). Прогресс скачивания
## через streaming недоступен (нет сигнала request_progress в используемой сборке),
## поэтому progress обновляется только при завершении скачивания (0% -> 100%).
## Для детализированного прогресса потребуется ручной HTTPClient и мелкоблочное чтение.

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
const MANIFEST_URL := "https://example.com/gigabah/manifest.json" # TODO: replace
const DEBUG_LOG := true # установить false чтобы отключить отладочные print

# Offline / no-update mode toggle. If true, лаунчер не будет делать сетевые запросы,
# просто попытается обнаружить уже лежащую игру в папке game/ и разрешит запуск.
const ENABLE_UPDATES := false # По умолчанию включаем обновления; установить false для оффлайн режима

# Retry/timeout configuration
const MAX_RETRIES := 3
const RETRY_DELAY_SEC := 2.0
const REQUEST_TIMEOUT_SEC := 40.0

# Differential patch support (scaffold):
# Manifest may contain section:
#   "patches": {
#       "0.1.0": { "url": ".../patch_0.1.0_to_0.1.1.zip", "sha256": "...", "size": 12345 }
#   }
# If local_version in patches -> download patch first, apply (overlay) then mark updated.

enum DownloadMode { MANIFEST, FULL_PACKAGE, PATCH }
var _current_mode: DownloadMode = DownloadMode.MANIFEST
var _active_url: String = ""
var _retry_count: int = 0
var _request_start_time: float = 0.0

# Track file size for progress (if provided by manifest or Content-Length)
var _expected_size: int = 0
var _received_bytes: int = 0

# Buffer for streaming download (manual accumulation to show progressive progress)
var _stream_buffer: PackedByteArray = PackedByteArray()

var manifest: Dictionary
var local_version: String = "0.0.0"
var remote_version: String = "?"
var is_update_available: bool = false

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
var _download_started_time: float = 0.0
var _download_label: String = ""

func _ready() -> void:
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
	_emit_status("Загрузка манифеста...")
	_current_mode = DownloadMode.MANIFEST
	_active_url = MANIFEST_URL
	_start_request(MANIFEST_URL)

func download_and_apply_update() -> void:
	if not is_update_available:
		_emit_status("Обновление не требуется")
		return
	if manifest.is_empty():
		_emit_status("Манифест пуст")
		return
	var pkg: Dictionary = manifest.get("package", {})
	var url: String = pkg.get("url", "")
	if url.is_empty():
		_emit_status("URL пакета отсутствует")
		return
	_emit_status("Скачивание пакета...")
	_current_mode = DownloadMode.FULL_PACKAGE
	_active_url = url
	_start_request(url, true, int(pkg.get("size", 0)))

func _try_download_patch_if_available() -> bool:
	if not manifest.has("patches"):
		return false
	var patches: Dictionary = manifest["patches"]
	if not patches.has(local_version):
		return false
	var p: Dictionary = patches[local_version]
	var p_url: String = p.get("url", "")
	if p_url.is_empty():
		return false
	_emit_status("Скачивание патча с версии %s..." % local_version)
	_current_mode = DownloadMode.PATCH
	_active_url = p_url
	_start_request(p_url, true, int(p.get("size", 0)))
	return true

func _start_request(url: String, _binary: bool=false, expected_size: int=0) -> void: # _binary не используется
	_expected_size = expected_size
	_received_bytes = 0
	_stream_buffer.clear()
	_retry_count = 0
	_downloading = true
	_download_started_time = Time.get_unix_time_from_system()
	_download_label = url
	_issue_request(url)

func _issue_request(url: String) -> void:
	_request_start_time = Time.get_unix_time_from_system()
	var err = http.request(url)
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

	# 1. Попытка: указанный в манифесте относительный путь внутри res://game
	if manifest.has("executable"):
		var rel = manifest["executable"]
		var candidate_res = "res://" + GAME_DIR + "/" + rel
		if FileAccess.file_exists(candidate_res):
			_cached_exe_path = ProjectSettings.globalize_path(candidate_res)
			_debug("Нашёл через manifest.executable: %s" % _cached_exe_path)
			return _cached_exe_path

	# 2. Поиск в стандартной папке res://game
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
		# For large files we rely on streaming progress; final body holds all data.
		_save_download(body)
		await get_tree().process_frame
		if _current_mode == DownloadMode.PATCH:
			if not _apply_patch_zip("res://" + DOWNLOAD_FILE):
				_emit_status("Ошибка применения патча, скачиваем полный пакет...")
				# Fall back to full package
				download_and_apply_update()
				return
			_write_local_version(remote_version)
			_emit_status("Патч установлен")
			emit_signal("update_finished", true, "Патч установлен")
		else:
			_verify_and_install()
	else:
		var text = body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			_emit_status("Некорректный JSON манифеста")
			return
		manifest = data
		remote_version = manifest.get("game_version", "?")
		emit_signal("versions_known", local_version, remote_version)
		emit_signal("changelog_received", manifest.get("changelog_bbcode", "[i]Нет изменений[/i]"))
		if _version_is_newer(remote_version, local_version):
			is_update_available = true
			emit_signal("update_available", remote_version)
			# Try differential patch first
			if _try_download_patch_if_available():
				return
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
	_emit_status("Проверка пакета...")
	var pkg: Dictionary = manifest.get("package", {})
	var expected_hash: String = pkg.get("sha256", "")
	if expected_hash != "":
		var real_hash = _sha256_file("res://" + DOWNLOAD_FILE)
		if real_hash.to_lower() != expected_hash.to_lower():
			_emit_status("Хэш не совпадает")
			emit_signal("update_finished", false, "Ошибка проверки хэша")
			return
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

func _sha256_file(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var ctx = HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(f.get_buffer(f.get_length()))
		var res = ctx.finish()
		return res.hex_encode()
	return ""

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

# Apply differential patch ZIP: overlay files into game directory.
func _apply_patch_zip(zip_path: String) -> bool:
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

func _get_header_value(headers: PackedStringArray, key: String) -> String:
	var key_l = key.to_lower()
	for h in headers:
		var parts = h.split(':', false, 2)
		if parts.size() == 2 and parts[0].strip_edges().to_lower() == key_l:
			return parts[1].strip_edges()
	return ""

func _emit_status(t: String) -> void:
	emit_signal("status_changed", t)
