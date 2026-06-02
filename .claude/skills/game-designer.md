# Game Designer — Lemmings Clone Visual & UX Spec

When asked to improve visuals, animations, or gameplay feel, follow this spec.

## Original Lemmings Look (1991, Amiga)

### Lemming Sprite
- 16×16 pixel sprite (expanded to look like 16×20 with hair)
- **Green hair** (#00ff00) — spiky, 4-5 pixels tall
- **Blue robe** (#0000aa to #4444ff) — body from neck to feet, bell-shaped
- **Skin** (#ffcc99) — small face visible under hair
- **White eyes** — 2 pixels when visible
- Walking animation: 4 frames (legs alternate, robe sways slightly)
- Direction: face points in walking direction

### Skills visual effects
- **Climber**: arms raised, grabbing wall
- **Floater**: blue/white umbrella (parachute) opens above head — 8×8 pixels
- **Bomber**: lemming flashes red/yellow, countdown numbers "5-4-3-2-1" above head, then explosion particles
- **Blocker**: arms stretched sideways, stern expression
- **Builder**: carries brick, places it, steps up — 12 bricks total
- **Basher**: arms swinging pickaxe horizontally
- **Miner**: diagonal pickaxe swing downward
- **Digger**: vertical digging with pickaxe

### Terrain
- **Dirt/earth**: brown (#8B4513, #654321) with darker pixels for depth
- **Grass top**: green (#228B22, #006400) — 2-4 pixel grass layer on top of dirt
- **Steel**: silver/grey (#888888) with metallic shine lines
- **Background**: dark/night sky (#000011) fading to darker at bottom
- **Traps**: lava (red/orange animated), water (blue animated with sparkle)

### Sound (iconic)
- "Let's go!" — high-pitched voice on level start
- "Oh no!" — when lemming dies
- "Yippee!" — when lemming exits
- Pop — bomber explosion
- Ting — builder placing brick

## Modern Pixel Art Guidelines

- Scale: 16×16 base sprites, rendered at 2x or 3x for modern displays (720×1280 mobile)
- Color palette: match original feel but richer (32 colors per sprite instead of 4-8)
- Animation: 4-8 frames per action, smooth but retains pixel-art charm
- Background: subtle parallax, maybe distant mountains or stars
- UI: pixel-art icons for each skill in the HUD panel
- Particles: simple pixel particles for explosions, digging, building

## Current State (what needs fixing)

- Lemmings are colored rectangles (ColorRect) — need proper sprites
- No animations — need walking, skill, death, exit animations
- Terrain tiles are placeholder — need actual dirt/grass/steel textures
- Background is black — need sky/underground theme
- HUD skill buttons have text only — need pixel-art icons
- No particles or visual feedback

## Color Palette

```
Hair (green):       #00cc44, #00ff55, #009933
Robe (blue):        #2244cc, #4466ff, #112288
Skin:               #ffcc99, #ffbb77
Eyes:               #ffffff, #000000 (pupil)
Dirt:               #8B6914, #6B4914, #A08030
Grass:              #228B22, #006400, #44cc44
Steel:              #888888, #aaaaaa, #666666
Sky BG:             #1a1a3e, #0d0d2b
```

## Implementation in Godot

Use **AnimatedSprite2D** (not ColorRect) with sprite sheets. Create sprite sheet textures as PNG files in `assets/sprites/`. Each sprite frame = 16×16 pixels. Use AnimationPlayer for state-based animations.

### Sprite sheet layout
```
lemming_walk.png     — 16×64  (4 frames × 16px wide)
lemming_climb.png    — 16×32  (2 frames)
lemming_float.png    — 16×32  (2 frames, parachute above)
lemming_build.png    — 16×48  (3 frames)
lemming_bash.png     — 16×32  (2 frames)
lemming_mine.png     — 16×32  (2 frames)
lemming_dig.png      — 16×32  (2 frames)
lemming_block.png    — 16×16  (1 frame)
lemming_bomb.png     — 16×32  (2 frames, flashing)
lemming_die.png      — 16×16  (1 frame, splat)
```

Generate these as actual PNG files using code (PIL/Pillow or native GDScript). Even simple geometric shapes in the right colors will look better than rectangles.
