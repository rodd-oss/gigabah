# DayNightCycle (Godot 4.5 Addon)

Универсальный цикл День/Ночь для 2D и 3D.

## Возможности
- Фазы: Morning → Day → Evening → Night (расширяемо)
- Настраиваемые длительности и плавные переходы (Tween)
- Управление DirectionalLight(2D/3D) + массив точечных / Omni / Spot
- Ambient через CanvasModulate (2D) или WorldEnvironment (3D)
- Сигналы: `phase_changed`, `new_day_started`
- Сохранение/восстановление состояния
- Прогресс фазы 0..1 (`phase_progress()`)
- `force_phase()` для ручного переключения

## Установка
1. В Godot: Project → Project Settings → Plugins → включите `DayNightCycle`.
2. Добавьте узел `DayNightCycle` (он доступен по имени класса). 

## Быстрый старт
1. Перетащите DirectionalLight2D или DirectionalLight3D в поле `directional_light`.
2. (Опц.) Укажите список точечных источников в `point_lights`.
3. (2D) Добавьте `CanvasModulate` и назначьте.
4. (3D) Укажите `WorldEnvironment`.
5. Настройте длительности фаз и энергии.
6. Подпишитесь на сигналы:
```gdscript
$DayNightCycle.phase_changed.connect(func(phase, idx, day):
    print("Phase:", phase, "Day:", day))
$DayNightCycle.new_day_started.connect(func(day):
    print("New day:", day))
```

## API Кратко
| Метод | Описание |
|-------|----------|
| `start_cycle(reset:=true)` | Запуск цикла |
| `stop_cycle()` | Остановка |
| `force_phase(Phase.EVENING)` | Принудительная фаза |
| `phase_progress()` | Прогресс 0..1 |
| `serialize_state()` | Dict состояния |
| `restore_state(dict)` | Восстановление |

## Сигналы
- `phase_changed(phase: StringName, state_index: int, day_index: int)`
- `new_day_started(day_index: int)`