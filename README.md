# Lemmings Clone

Прототип клона классики 1991 года на Godot Engine 4.3 (GDScript).
Целевые платформы: iOS + Android (primary), Linux/Mac/Windows (dev/testing).

## Быстрый старт

```bash
# Запуск проекта
./godot

# Headless-прогон тестов (как в CI)
./godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Структура

См. [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) и
[docs/ТЗ.md](docs/ТЗ.md).

```
autoload/   — singleton менеджеры (GameManager, LevelManager, SaveManager, AudioManager)
entities/   — Lemming (CharacterBody2D + FSM), Entrance, Exit
skills/     — BaseSkill + 8 навыков (Strategy pattern)
managers/   — SkillManager, LemmingManager
scenes/     — game.tscn, level.tscn, menu/*
ui/         — HUD, skill panel, result screen
levels/fun/ — 5 уровней Fun (level_NN.json + level_NN.tscn)
tests/      — GUT-тесты (FSM, скиллы, парсер, solvability)
addons/gut/ — Godot Unit Test framework
```

## Навыки

| # | Навык | Эффект |
|---|-------|--------|
| 1 | Climber | Карабкается по вертикальным стенам |
| 2 | Floater | Парашют — безопасное падение с любой высоты |
| 3 | Bomber | Взрыв через 5 секунд, уничтожает ландшафт |
| 4 | Blocker | Стоит, разворачивает встречных |
| 5 | Builder | Строит 12 ступенек по диагонали вверх |
| 6 | Basher | Горизонтальный туннель (steel не пробивает) |
| 7 | Miner | Диагональный туннель вниз |
| 8 | Digger | Вертикальный туннель вниз |

## CI

GitHub Actions запускает GUT-тесты и собирает Linux-билд на каждый PR и push в `main`.
Конфиг: [.github/workflows/ci.yml](.github/workflows/ci.yml).
