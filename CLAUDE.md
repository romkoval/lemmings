# Lemmings Clone — Godot 4.x Project

## Project Identity
- **Name:** Lemmings Clone
- **Engine:** Godot 4.3+ (GDScript)
- **Platforms:** iOS + Android (primary), Linux/Mac/Windows (dev/testing)
- **Language:** GDScript (code), Russian (UI strings)

## Architecture
- **Pattern:** Autoloads (Singleton managers) + Scene composition
- **Managers:** GameManager, LevelManager, SaveManager, AudioManager — all Autoload
- **Lemming FSM:** Finite State Machine per lemming (WALKING, FALLING, SKILL_ACTIVE, etc.)
- **Skills:** Strategy pattern — each skill is a separate class extending BaseSkill
- **Landscape:** per-pixel terrain (`PixelTerrain`), like the original game. Tile layers are only the AUTHORING format: at level load they are rasterized into a 1px solidity mask + material map (dirt/wood/steel), then hidden. Skills carve/fill pixels (`Level.carve_rect_px` / `fill_rect_px`); the visible terrain is drawn by `assets/shaders/pixel_terrain.gdshader` straight from the same mask, so physics and visuals can never disagree
- **UI:** HUD scene with skill panel, counters, timer. Touch-first design.

## Key Conventions
- All game objects use `snake_case` for methods and variables
- Classes use `PascalCase`
- Constants use `UPPER_SNAKE_CASE`
- Signals use `snake_case` (past tense for events: `lemming_died`, `skill_assigned`)
- File names match class names: `game_manager.gd` → `GameManager`
- Assets under `res://assets/`, organized by type
- Levels stored as Godot `.tscn` scenes with metadata in companion `.json` files
- TileMap cell size: 16×16 pixels — authoring/procgen granularity only; runtime collision is per-pixel

## Test Framework
- **GUT (Godot Unit Test):** `res://addons/gut/`
- Test files in `res://tests/`, mirroring source structure
- Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Test naming: `test_<feature>.gd` with methods `test_<scenario>()`

## Project Structure
```
res://
├── main.tscn
├── scenes/          # Full scenes (menu, game, level)
├── entities/        # Game entities (lemming, entrance, exit, traps)
├── skills/          # Skill classes (builder, climber, etc.)
├── managers/        # Autoload managers
├── levels/          # Level .tscn + .json files
├── data/            # Data classes & parsers
├── ui/              # UI components
├── autoload/        # Autoload singletons
├── assets/          # sprites/, tilesets/, sounds/, music/, fonts/
└── tests/           # GUT test files
```

## Lemming Physics
- Movement is classic pixel physics (no move_and_slide/raycasts against terrain;
  the body probes the pixel mask at its centre column)
- Walk speed: 1 pixel per frame at 60fps = 60 px/sec
- Step-up ≤ 8px in stride (builder planks are 8px); taller = wall → turn/climb
- Step-down ≤ 8px in stride; deeper = FALLING
- Fall speed: 2 px/frame (120 px/sec); falls > 64px = splat
- Climb speed: 30 px/sec

## Git Workflow
- Branch: `main` for stable, feature branches for new work
- Commit format: `type: description` (feat:, fix:, test:, docs:, refactor:)
- Always commit after each completed task
