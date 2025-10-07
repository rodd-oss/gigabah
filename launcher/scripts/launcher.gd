extends Control

@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var local_version_label: Label = $Margin/VBox/Header/TitleBox/LocalVersionLabel
@onready var remote_version_label: Label = $Margin/VBox/Header/TitleBox/RemoteVersionLabel
@onready var update_button: Button = $Margin/VBox/Buttons/UpdateButton
@onready var launch_button: Button = $Margin/VBox/Buttons/LaunchButton
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressBar
@onready var changelog: RichTextLabel = $Margin/VBox/Changelog

var update_manager: Node

func _ready() -> void:
	update_manager = load("res://scripts/update_manager.gd").new()
	add_child(update_manager)
	update_manager.connect("status_changed", _on_status_changed)
	update_manager.connect("progress_changed", _on_progress_changed)
	update_manager.connect("versions_known", _on_versions_known)
	update_manager.connect("update_available", _on_update_available)
	update_manager.connect("update_finished", _on_update_finished)
	update_manager.connect("changelog_received", _on_changelog_received)
	update_manager.start_check()
	update_button.pressed.connect(_on_update_pressed)
	launch_button.pressed.connect(_on_launch_pressed)

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_progress_changed(pct: float) -> void:
	progress_bar.value = pct

func _on_versions_known(local_v: String, remote_v: String) -> void:
	local_version_label.text = "Local Version: %s" % local_v
	remote_version_label.text = "Remote Version: %s" % remote_v
	# enable launch if versions same
	if local_v == remote_v:
		launch_button.disabled = false

func _on_update_available(new_version: String) -> void:
	update_button.disabled = false
	launch_button.disabled = true
	status_label.text = "Доступно обновление: %s" % new_version

func _on_update_finished(success: bool, message: String) -> void:
	status_label.text = message
	update_button.disabled = true
	launch_button.disabled = not success

func _on_changelog_received(text_bbcode: String) -> void:
	changelog.clear()
	changelog.append_bbcode(text_bbcode)

func _on_update_pressed() -> void:
	update_button.disabled = true
	update_manager.download_and_apply_update()

func _on_launch_pressed() -> void:
	var exe_path: String = update_manager.get_game_executable_path()
	if exe_path.is_empty():
		status_label.text = "Исполняемый файл не найден"
		return
	status_label.text = "Запуск игры..."
	# ВАЖНО: OS.create_process возвращает PID (целое число процесса), а не Error.
	# Раньше мы трактовали PID как код ошибки (поэтому появлялись числа типа 1824),
	# что создавало ложное сообщение об ошибке.
	var pid = OS.create_process(exe_path, [])
	if pid <= 0:
		status_label.text = "Ошибка запуска: не удалось создать процесс"
	else:
		status_label.text = "Игра запущена (PID %d)" % pid
		# Авто-закрытие лаунчера после успешного запуска (можно отключить при отладке)
		get_tree().quit()
