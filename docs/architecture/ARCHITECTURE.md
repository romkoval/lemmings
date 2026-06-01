# Lemmings Clone — Архитектурная схема

> Диаграмма компонентов и потоков данных. Создана: 2026-06-01.
> Движок: Godot 4.x, язык: GDScript

---

## Компонентная диаграмма (C4 — Container)

```
┌──────────────────────────────────────────────────────────────────┐
│                       Mobile Device (iOS / Android)               │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │                   Godot Engine Runtime                    │     │
│  │                                                           │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │     │
│  │  │GameManager│  │LevelMgr  │  │SaveMgr   │  (Autoloads) │     │
│  │  │ state     │  │ load     │  │ slots    │               │     │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘               │     │
│  │       │             │             │                       │     │
│  │       ▼             ▼             ▼                       │     │
│  │  ┌──────────────────────────────────────┐                │     │
│  │  │            Game Scene                 │                │     │
│  │  │                                       │                │     │
│  │  │  ┌─────────┐  ┌──────────┐           │                │     │
│  │  │  │TileMap  │  │LemmingMgr│           │                │     │
│  │  │  │(terrain)│  │  (pool)  │           │                │     │
│  │  │  └────┬────┘  └────┬─────┘           │                │     │
│  │  │       │            │                  │                │     │
│  │  │       │     ┌──────▼──────┐           │                │     │
│  │  │       │     │Lemming Node │ × N       │                │     │
│  │  │       │     │ FSM + sprite│           │                │     │
│  │  │       │     └──────┬──────┘           │                │     │
│  │  │       │            │                  │                │     │
│  │  │       │     ┌──────▼──────┐           │                │     │
│  │  │       │     │SkillHandler │ × 8       │                │     │
│  │  │       │     │(Climber,    │           │                │     │
│  │  │       │     │ Builder...) │           │                │     │
│  │  │       │     └─────────────┘           │                │     │
│  │  │       │                               │                │     │
│  │  │  ┌────▼──────────────────────────┐    │                │     │
│  │  │  │           HUD                  │    │                │     │
│  │  │  │  Skill Panel │ Counters │Timer │    │                │     │
│  │  │  └───────────────────────────────┘    │                │     │
│  │  └──────────────────────────────────────┘                │     │
│  └─────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

---

## Поток игры (Sequence)

```
User                HUD              GameManager      LevelManager      LemmingManager    Lemming
 │                   │                    │                │                  │              │
 │  Tap "Play"       │                    │                │                  │              │
 │──────────────────►│                    │                │                  │              │
 │                   │  start_game()      │                │                  │              │
 │                   │───────────────────►│                │                  │              │
 │                   │                    │  load_level(1) │                  │              │
 │                   │                    │───────────────►│                  │              │
 │                   │                    │                │  spawn_entrance  │              │
 │                   │                    │                │─────────────────►│              │
 │                   │                    │                │                  │  spawn()     │
 │                   │                    │                │                  │─────────────►│
 │                   │                    │                │                  │              │
 │  Tap skill icon   │                    │                │                  │              │
 │──────────────────►│                    │                │                  │              │
 │                   │  select_skill(5)   │                │                  │              │
 │                   │───────────────────►│                │                  │              │
 │                   │                    │                │                  │              │
 │  Tap lemming      │                    │                │                  │              │
 │───────────────────│────────────────────│────────────────│──────────────────│─────────────►│
 │                   │                    │                │                  │  assign()    │
 │                   │                    │                │                  │              │
 │                   │                    │                │                  │◄─────────────│
 │                   │                    │                │  update_counters │              │
 │                   │◄───────────────────│◄───────────────│◄─────────────────│              │
 │                   │                    │                │                  │              │
 │  (loop until      │                    │                │                  │              │
 │   quota met or    │                    │                │                  │              │
 │   timer expires)  │                    │                │                  │              │
 │                   │                    │                │                  │              │
 │                   │                    │  level_complete │                 │              │
 │                   │◄───────────────────│◄───────────────│                  │              │
 │                   │                    │                │                  │              │
 │  Show result      │                    │                │                  │              │
 │◄──────────────────│                    │                │                  │              │
```

---

## Конечный автомат лемминга (FSM)

```
                        ┌─────────────────────────────┐
                        │          SPAWNED             │
                        │  (выход из люка, анимация)    │
                        └─────────────┬───────────────┘
                                      │
                                      ▼
                        ┌─────────────────────────────┐
             ┌─────────│          WALKING             │◄────────────────┐
             │         │  (move_and_slide, проверка    │                 │
             │         │   коллизий, смена направления) │                 │
             │         └──┬───────┬───────┬──────┬───┘                 │
             │            │       │       │      │                      │
             │   ┌────────▼──┐ ┌──▼───┐ ┌─▼──┐ ┌─▼──────────┐        │
             │   │  FALLING  │ │WALL  │ │EDGE│ │SKILL GIVEN │        │
             │   │  (gravity)│ │HIT   │ │    │ │(user tap)  │        │
             │   └────┬──────┘ └──┬───┘ └──┬─┘ └─────┬──────┘        │
             │        │           │        │         │                │
             │   ┌────▼────┐ ┌───▼───┐     │  ┌──────▼──────────┐    │
             │   │HIGH FALL│ │TURN   │     │  │  SKILL_ACTIVE    │    │
             │   │> 64px   │ │AROUND │     │  │  (build/bash/    │    │
             │   └────┬────┘ └───┬───┘     │  │   mine/dig/      │    │
             │        │          │         │  │   block/float/    │    │
             │   ┌────▼────┐     │         │  │   climb/bomb)     │    │
             │   │  SPLAT  │     │         │  └──────┬───────────┘    │
             │   │  (dead) │     │         │         │                │
             │   └─────────┘     │         │         │                │
             │                   │         │         │                │
             │                   └─────────┴─────────┘                │
             │                        │                               │
             │                        └───────────────────────────────┘
             │
             │         ┌─────────────────────────────┐
             │         │          EXITED              │
             │         │  (достиг выхода, спасён)      │
             │         └─────────────────────────────┘
             │
             │         ┌─────────────────────────────┐
             └────────►│           DEAD               │
                       │  (сплат/лава/вода/бомба/     │
                       │   край экрана)               │
                       └─────────────────────────────┘
```

---

## Структура данных уровня

```
LevelData
├── metadata
│   ├── name: String
│   ├── difficulty: enum {FUN, TRICKY, TAXING, MAYHEM}
│   └── number: int
├── goals
│   ├── save_percentage: int (0-100)
│   ├── time_limit_sec: int
│   ├── lemming_count: int
│   └── release_rate: int (1-99)
├── skills_available: Dictionary[SkillType, int]
│   ├── CLIMBER: 0..99
│   ├── FLOATER: 0..99
│   ├── BOMBER: 0..99
│   ├── BLOCKER: 0..99
│   ├── BUILDER: 0..99
│   ├── BASHER: 0..99
│   ├── MINER: 0..99
│   └── DIGGER: 0..99
├── entrances: Array[Vector2i]  (координаты люков)
├── exit: Vector2i              (координаты выхода)
├── traps: Array[{type, pos}]   (ловушки)
└── tilemap_ref: String         (путь к .tscn или данным тайлов)
```

---

## Система навыков (Strategy Pattern)

```
                    ┌──────────────┐
                    │  BaseSkill   │  (абстрактный)
                    │  +execute()  │
                    │  +interrupt()│
                    └──────┬───────┘
           ┌───────┬───────┼───────┬───────┬───────┬───────┬───────┐
           │       │       │       │       │       │       │       │
    ┌──────▼──┐┌───▼───┐┌──▼──┐┌───▼──┐┌───▼──┐┌───▼──┐┌───▼──┐┌──▼───┐
    │Climber  ││Floater││Bomber││Blocker││Builder││Basher││Miner ││Digger│
    │wall     ││chute  ││5sec  ││stand ││stairs ││horiz ││diag  ││vert  │
    │climb    ││fall   ││boom  ││block ││12steps││tunnel││tunnel││tunnel│
    └─────────┘└───────┘└──────┘└──────┘└───────┘└──────┘└──────┘└──────┘
```

---

## Модель Touch-управления

```
Состояния UI:
  IDLE         — нет выбранного навыка, тап по леммингу ничего не делает
  SKILL_ACTIVE — выбран навык на панели, тап по леммингу назначает его
  PAUSED       — игра на паузе, панель скрыта, видна кнопка Play

Жесты:
  Tap (lemming)        — назначить активный навык
  Tap (skill icon)     — выбрать навык / отменить выбор
  Double-tap (empty)   — Nuke (подтверждение)
  Long-press (lemming) — показать информацию о лемминге
  Pinch                — Zoom in/out
  Two-finger pan       — Скролл карты уровня
```

---

## Система событий (Signal bus)

```gdscript
# GameManager signals
signal level_started(level_data: LevelData)
signal level_completed(saved: int, total: int, percentage: float)
signal level_failed(reason: String)
signal game_paused()
signal game_resumed()

# LevelManager signals
signal lemming_spawned(lemming: Lemming)
signal lemming_exited(lemming: Lemming)
signal lemming_died(lemming: Lemming, cause: String)
signal skill_assigned(lemming: Lemming, skill: SkillType)
signal skill_exhausted(skill: SkillType)

# Lemming signals
signal state_changed(old: State, new: State)
signal direction_changed(new_dir: Vector2)
signal terrain_modified(cell: Vector2i, new_tile: int)
```
