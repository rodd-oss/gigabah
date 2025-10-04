# DayNightCycle (Godot 4.5)

Расширяемый, data‑driven цикл День / Ночь для 2D и 3D сцен. Подходит как для одиночной игры, так и для мультиплеера (логика детерминирована и может быть запущена только на authority / host при необходимости).

## Основные возможности
* Data-driven фазы: массив ресурсов `DayPhaseConfig` (неограниченное число фаз). По умолчанию генерируется 4: MORNING → DAY → EVENING → NIGHT, если список пуст.
* Плавные переходы (Tween) освещения между фазами.
* Управление:
  * Одним основным `directional_light` (NodePath) + массивом `directional_lights` (доп. солнца / луны / вспомогательные источники)
  * Массив точечных / Omni / Spot источников `point_lights`
  * Ambient: через `CanvasModulate` (2D) или `WorldEnvironment` (3D)
* Пер-фаза: длительность, энергия направленного света, энергия точечных, цвет ambient, настраиваемая `ambient_energy`, опциональный `dir_color` (оттенок солнца / луны).
* Сигналы: `phase_changed`, `new_day_started`
* Сохранение/восстановление: `serialize_state()`, `restore_state(dict)`
* Прогресс текущей фазы: `phase_progress()` (0..1)
* Принудительное переключение: `force_phase(index|name)` / `force_phase_by_name()`
* Debug вывод (флаг `debug_log`)

## Структура ресурсов (DayPhaseConfig)
Поля ресурса:
| Поле | Тип | Назначение |
|------|-----|-----------|
| `name` | StringName | Имя фазы (уникально в пределах массива) |
| `duration` | float | Длительность фазы (сек) |
| `dir_energy` | float | Энергия направленного света |
| `point_energy` | float | Унифицированная энергия для всех точечных / omni / spot |
| `ambient_color` | Color | Цвет ambient света / CanvasModulate |
| `ambient_energy` | float | Явное значение мощности ambient (>=0 — переопределяет авто) |
| `dir_color` | Color | Тинт направленного света (если не WHITE) |

Если `ambient_energy < 0`, берётся автоматическое (средняя яркость цвета).

## Установка плагина
1. Скопируйте папку `addons/day_night_cycle` в проект (если не через git).
2. Project → Project Settings → Plugins → включите `DayNightCycle`.
3. Добавьте в сцену узел `DayNightCycle`.

## Быстрый старт (3D пример)
1. Добавьте `DirectionalLight3D` (или используйте существующий) → перетащите в `directional_light`.
2. (Опц.) Перетащите второй / лунный свет в массив `directional_lights`.
3. Добавьте один или несколько `OmniLight3D` → массив `point_lights`.
4. Добавьте `WorldEnvironment` и назначьте узлу.
5. Оставьте `phase_configs` пустым — сгенерируются 4 дефолтных фазы, либо создайте свои ресурсы `DayPhaseConfig` и заполните массив.
6. Нажмите Play — фазы будут переключаться автоматически.

## Пример подписки на события
```gdscript
func _ready():
    var cycle = $DayNightCycle
    cycle.phase_changed.connect(_on_phase_changed)
    cycle.new_day_started.connect(_on_new_day)

func _on_phase_changed(phase: StringName, idx: int, day: int) -> void:
    print("Phase:", phase, "index=", idx, "day=", day, "progress=", $DayNightCycle.phase_progress())

func _on_new_day(day: int) -> void:
    print("New day:", day)
```

## Добавление новой фазы (пример AFTERNOON)
1. Выделите узел `DayNightCycle`.
2. В инспекторе у `phase_configs` нажмите `Add Element` → `New DayPhaseConfig`.
3. Установите поля: `name = AFTERNOON`, `duration`, `dir_energy`, `point_energy`, `ambient_color`, при необходимости `ambient_energy`, `dir_color`.
4. Перетащите ресурс мышкой в список между `DAY` и `EVENING`.
5. Запустите сцену — цикл теперь MORNING → DAY → AFTERNOON → EVENING → NIGHT.

## Принудительное переключение
```gdscript
$DayNightCycle.force_phase_by_name(&"NIGHT")
# или индексом
$DayNightCycle.force_phase(0) # MORNING
```
Если хотите сохранить текущий таймер (не сбрасывать прогресс), можно расширить API (или добавить флаг preserve_timer) — базовый метод сбрасывает таймер.

## Экспортируемые параметры узла (основные)
| Параметр | Назначение |
|----------|-----------|
| `phase_configs` | Массив фаз (если пуст — генерируются дефолты) |
| `transition_time` | Время плавного перехода между значениями |
| `autostart` | Автозапуск при _ready (рантайм) |
| `directional_light` | Основной направленный свет |
| `directional_lights` | Доп. список направленных источников |
| `point_lights` | Массив точечных / omni / spot |
| `canvas_modulate` | Узел для 2D глобального цвета |
| `world_environment` | Узел для 3D окружения |
| `debug_log` | Включить подробный лог фаз |

Исторические поля вроде `morning_duration`, `dir_energy_morning` и т.п. остаются только как генератор дефолтов. Их можно удалить из инспектора, если полностью используете `phase_configs`.

## Диагностика и отладка
| Симптом | Причина | Решение |
|---------|---------|---------|
| "Фазы не меняются" | `_process` не активен / узел не автозапущен | Проверь `autostart`, вызови `start_cycle()` вручную |
| Видно несколько одинаковых логов | Несколько узлов / повторный запуск | Оставьте один экземпляр / смотрите peer id |
| Нет эффекта ночью | Слишком высокие `ambient_energy` или `dir_energy` | Понизьте NIGHT `ambient_energy` до 0.05–0.1, dir до 0.05–0.1 |
| Omni не меняются | Не добавлены в `point_lights` | Перетащите узлы в массив |
| Цвет не меняется | `dir_color` = WHITE | Задайте тёплый вечерний / холодный ночной оттенок |

## Рекомендации по визуалу
* Ночь: низкий ambient, компенсируйте локальными точечными источниками.
* Рассвет / закат: изменяйте `dir_color` (оранжево‑золотой, затем более холодный). 
* Можно вращать солнце: анимируйте `rotation_degrees` у DirectionalLight в `_apply_phase_transition` (не включено по умолчанию для простоты).

## Сохранение и восстановление
```gdscript
var data = $DayNightCycle.serialize_state()
FileAccess.open("user://cycle.save", FileAccess.WRITE).store_var(data)

# Позже
var loaded = FileAccess.open("user://cycle.save", FileAccess.READ).get_var()
$DayNightCycle.restore_state(loaded)
```

## Использование в мультиплеере
* Запускайте цикл только на authoritative стороне (сервер / хост) и реплицируйте нужные эффекты (например, через RPC или синхронизацию параметров освещения).
* Текущее решение не делает внутренних RPC — вы сами решаете где крутить время.

## Расширение
Идеи для будущего:
* Вращение солнца / луны + высота над горизонтом.
* Управление туманом (`fog_density`, `fog_light_color`).
* Переход между разными Sky ресурсами / HDRI.
* Группы освещения: вместо явного массива можно подсасывать все ноды в группе `day_cycle_point` и т.п.

## Минимальный пример кода получения текущей фазы
```gdscript
var idx = $DayNightCycle.current_phase_index
var progress = $DayNightCycle.phase_progress()
print("Phase:", idx, "Progress:", progress)
```

## Лицензия
Смотрите LICENSE в корне репозитория.

---
Если чего-то не хватает в документации — дополняйте или создавайте issue.