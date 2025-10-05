extends CanvasLayer

# HUD только визуализирует поступающие значения. Игровая логика не реализуется.
# Ожидается, что внешняя логика будет вызывать set_hp / set_armor / set_energy или set_stats.

@onready var _hp_bar: TextureProgressBar = $MarginContainer/VBoxContainer/HPRow/HPBar
@onready var _armor_bar: TextureProgressBar = $MarginContainer/VBoxContainer/ArmorRow/ArmorBar
@onready var _energy_bar: TextureProgressBar = $MarginContainer/VBoxContainer/EnergyRow/EnergyBar

var _hp_max: float = 100.0
var _armor_max: float = 100.0
var _energy_max: float = 100.0

var ui_base_width: int = 1280 # Базовая ширина для расчёта относительного масштаба
var ui_min_scale: float = 0.75
var ui_max_scale: float = 1.75

# Быстрые слоты инвентаря (7 штук). Заполняются иконками/данными извне.
signal quick_slot_selected(index: int)

var quick_slot_count: int = 7
var _quick_slots: Array[TextureRect] = []
var _selected_slot: int = 0 # 0..quick_slot_count-1

# Настройка клавиш — по умолчанию цифры 1..7 сверху клавиатуры.
# Можно переопределить через ProjectSettings (custom/quick_slots/keys) или методом set_quick_slot_keys.
var _quick_slot_keys: Array[Key] = []

const PROJECT_SETTING_KEYS_PATH: String = "custom/quick_slots/keys"
const DEFAULT_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]

func _ready() -> void:
	# Надёжный поиск нод, если структура изменилась в сцене вручную
	if not is_instance_valid(_hp_bar):
		_hp_bar = _safe_find_bar(["MarginContainer/VBoxContainer/HPBar", "MarginContainer/VBoxContainer/HPRow/HPBar"])
	if not is_instance_valid(_armor_bar):
		_armor_bar = _safe_find_bar(["MarginContainer/VBoxContainer/ArmorBar", "MarginContainer/VBoxContainer/ArmorRow/ArmorBar"])
	if not is_instance_valid(_energy_bar):
		_energy_bar = _safe_find_bar(["MarginContainer/VBoxContainer/EnergyBar", "MarginContainer/VBoxContainer/EnergyRow/EnergyBar"])
	# Если что-то не найдено — выводим предупреждение
	if not _hp_bar or not _armor_bar or not _energy_bar:
		push_warning("HUD: one or more bars not found. Check node paths in hud.tscn.")
	else:
		set_max_values(_hp_max, _armor_max, _energy_max)
	# Подключаемся к изменению размера окна
	var vp: Viewport = get_viewport()
	if vp:
		if not vp.is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
			vp.connect("size_changed", Callable(self, "_on_viewport_size_changed"))
	# Первичное масштабирование
	apply_scale(true)

	_init_quick_slots()
	_load_or_init_keymap()
	_highlight_selected_slot()

func _safe_find_bar(paths: Array[String]) -> TextureProgressBar:
	for p: String in paths:
		var node: Node = get_node_or_null(p)
		if node and node is TextureProgressBar:
			return node
	return null

func set_max_values(hp_max: float = -1.0, armor_max: float = -1.0, energy_max: float = -1.0) -> void:
	if hp_max > 0: _hp_max = hp_max
	if armor_max > 0: _armor_max = armor_max
	if energy_max > 0: _energy_max = energy_max
	_hp_bar.max_value = _hp_max
	_armor_bar.max_value = _armor_max
	_energy_bar.max_value = _energy_max

func set_hp(value: float) -> void:
	_hp_bar.value = clamp(value, 0.0, _hp_max)

func set_armor(value: float) -> void:
	_armor_bar.value = clamp(value, 0.0, _armor_max)

func set_energy(value: float) -> void:
	_energy_bar.value = clamp(value, 0.0, _energy_max)

func set_stats(hp: float, armor: float, energy: float) -> void:
	# Удобный пакетный метод.
	set_hp(hp)
	set_armor(armor)
	set_energy(energy)

func reset() -> void:
	# Сбрасывает визуальные значения в ноль.
	set_hp(0)
	set_armor(0)
	set_energy(0)

func apply_scale(auto: bool = true, explicit_scale: float = 1.0) -> void:
	"""Динамическое масштабирование HUD.
	Если auto=true: вычисляет коэффициент на основе текущей ширины окна относительно ui_base_width.
	Если auto=false: применяет explicit_scale.
	"""
	var scale_factor: float = explicit_scale
	if auto:
		var viewport_width: float = get_viewport().get_visible_rect().size.x
		scale_factor = clamp(viewport_width / float(ui_base_width), ui_min_scale, ui_max_scale)
	# Применяем масштаб к контейнеру баров
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer
	# Сбрасываем предыдущий масштаб, если был
	vbox.scale = Vector2.ONE * scale_factor

func _on_viewport_size_changed() -> void:
	apply_scale(true)

func _init_quick_slots() -> void:
	"""Находит TextureRect слоты быстрых ячеек и складывает в массив в порядке Slot1..Slot7."""
	_quick_slots.clear()
	var root: Node = get_node_or_null("FastInventory/Margin/Slots")
	if not root:
		push_warning("HUD: FastInventory slots root not found.")
		return
	for i: int in range(1, quick_slot_count + 1):
		var slot: TextureRect = root.get_node_or_null("Slot%d" % i)
		if slot and slot is TextureRect:
			_quick_slots.append(slot)
		else:
			push_warning("HUD: Slot%d missing" % i)
	# Страхуемся, если меньше фактически найдено
	quick_slot_count = _quick_slots.size()

func _load_or_init_keymap() -> void:
	"""Загружает массив Key из ProjectSettings или создаёт дефолт."""
	_quick_slot_keys.clear()
	if ProjectSettings.has_setting(PROJECT_SETTING_KEYS_PATH):
		var arr: Array = ProjectSettings.get_setting(PROJECT_SETTING_KEYS_PATH)
		if arr is Array:
			for i: int in arr:
				if typeof(i) == TYPE_INT:
					_quick_slot_keys.append(i)
	if _quick_slot_keys.is_empty():
		_quick_slot_keys = DEFAULT_KEYS.duplicate()
	# Гарантируем длину равную количеству слотов
	if _quick_slot_keys.size() < quick_slot_count:
		for i: int in range(_quick_slot_keys.size(), quick_slot_count):
			_quick_slot_keys.append(KEY_0) # Заполнитель

func set_quick_slot_keys(keys: Array[int]) -> void:
	"""Переопределяет привязку клавиш (ожидает массив Key длиной >= числу слотов)."""
	if keys.size() < quick_slot_count:
		push_warning("HUD: not enough keys provided for quick slots")
		return
	_quick_slot_keys = []
	for k: int in keys:
		if typeof(k) == TYPE_INT:
			_quick_slot_keys.append(k)
	_highlight_selected_slot()

func get_selected_slot() -> int:
	return _selected_slot

func select_slot(index: int, emit_signal_flag: bool = true) -> void:
	"""Выбирает слот (0-based)."""
	if index < 0 or index >= quick_slot_count:
		return
	_selected_slot = index
	_highlight_selected_slot()
	if emit_signal_flag:
		emit_signal("quick_slot_selected", _selected_slot)

func _highlight_selected_slot() -> void:
	"""Простая подсветка: выбранный — белый, остальные затемнены."""
	for i: int in range(_quick_slots.size()):
		var slot: TextureRect = _quick_slots[i]
		if not slot:
			continue
		if i == _selected_slot:
			slot.modulate = Color(1, 1, 1, 1)
		else:
			slot.modulate = Color(0.65, 0.65, 0.65, 0.85)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = (event as InputEventKey).keycode
		var max_i: int = min(quick_slot_count, _quick_slot_keys.size())
		for i: int in range(max_i):
			if _quick_slot_keys[i] == keycode:
				select_slot(i)
				# CanvasLayer не имеет accept_event(); помечаем событие обработанным через вьюпорт.
				if get_viewport():
					get_viewport().set_input_as_handled()
				return

# Пример использования (раскомментируй в _ready если нужно):
# func _ready():
# 	apply_scale(true)

# Опционально плавное обновление (закомментировано, если понадобится — раскомментируй)
# func tween_to(values: Dictionary, duration: float = 0.15):
# 	var tween = create_tween()
# 	if values.has("hp"):
# 		tween.tween_property(_hp_bar, "value", clamp(values.hp, 0.0, _hp_max), duration)
# 	if values.has("armor"):
# 		tween.tween_property(_armor_bar, "value", clamp(values.armor, 0.0, _armor_max), duration)
# 	if values.has("energy"):
# 		tween.tween_property(_energy_bar, "value", clamp(values.energy, 0.0, _energy_max), duration)
