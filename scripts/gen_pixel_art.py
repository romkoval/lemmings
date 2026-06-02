#!/usr/bin/env python3
"""Generate pixel-art sprites and tileset for the Lemmings clone.

All output goes under assets/. Sprites are 16x16 frames. Sheets stack
frames horizontally so the offset of frame N is (N*16, 0).
"""

from PIL import Image
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"
TIL = ROOT / "assets" / "tilesets"
SPR.mkdir(parents=True, exist_ok=True)
TIL.mkdir(parents=True, exist_ok=True)

# ── Palette ────────────────────────────────────────────────────────────
T = (0, 0, 0, 0)
HAIR_D = (0x00, 0x88, 0x22, 255)
HAIR   = (0x10, 0xdd, 0x44, 255)
HAIR_L = (0x44, 0xff, 0x66, 255)
ROBE_D = (0x10, 0x1c, 0x66, 255)
ROBE   = (0x20, 0x3c, 0xcc, 255)
ROBE_L = (0x55, 0x77, 0xff, 255)
SKIN   = (0xff, 0xd0, 0xa0, 255)
SKIN_D = (0xe6, 0xa0, 0x70, 255)
EYE_W  = (0xff, 0xff, 0xff, 255)
PUPIL  = (0x00, 0x00, 0x00, 255)
RED    = (0xff, 0x33, 0x33, 255)
ORANGE = (0xff, 0x88, 0x22, 255)
YELLOW = (0xff, 0xee, 0x44, 255)
WHITE  = (0xff, 0xff, 0xff, 255)
BRICK  = (0xdd, 0x77, 0x33, 255)
BRICK_D= (0x88, 0x44, 0x22, 255)
GREY_L = (0xcc, 0xcc, 0xcc, 255)
GREY   = (0x99, 0x99, 0x99, 255)
GREY_D = (0x55, 0x55, 0x55, 255)
DIRT_L = (0xb8, 0x8a, 0x3a, 255)
DIRT   = (0x8c, 0x66, 0x22, 255)
DIRT_D = (0x5c, 0x40, 0x14, 255)
DIRT_DD= (0x3a, 0x28, 0x0a, 255)
GRASS  = (0x32, 0xb8, 0x32, 255)
GRASS_D= (0x10, 0x70, 0x18, 255)
GRASS_L= (0x66, 0xea, 0x55, 255)
STEEL  = (0x95, 0x9a, 0xa2, 255)
STEEL_L= (0xd0, 0xd4, 0xd9, 255)
STEEL_D= (0x4a, 0x4f, 0x57, 255)
DOOR   = (0x66, 0x33, 0x11, 255)
DOOR_L = (0xaa, 0x77, 0x33, 255)
EXIT_GRN=(0x44, 0xee, 0x44, 255)
SKY_TOP= (0x1a, 0x1f, 0x4e, 255)
SKY_MID= (0x0c, 0x10, 0x2e, 255)
SKY_BOT= (0x02, 0x02, 0x10, 255)

# ── Helpers ────────────────────────────────────────────────────────────

def img(w, h):
    return Image.new("RGBA", (w, h), T)


def fill(im, x0, y0, x1, y1, color):
    """Inclusive rect fill."""
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < im.width and 0 <= y < im.height:
                px[x, y] = color


def putrow(im, y, xs, color):
    px = im.load()
    for x in xs:
        if 0 <= x < im.width and 0 <= y < im.height:
            px[x, y] = color


def stamp(sheet, frame_img, idx):
    sheet.paste(frame_img, (idx * 16, 0), frame_img)


def draw_lemming_base(im, *, ox=0, oy=0, leg_pose="together", arms="down"):
    """Draw a 16x16 lemming silhouette into im at (ox,oy).

    Layout — head+hair rows 0-4 (5px), robe rows 5-12 (8px), legs 13-15 (3px).
    leg_pose: 'together' | 'split' | 'mid'
    arms: 'down' | 'side' | 'up' | 'fwd_swing' | 'fwd_pick'
    """
    p = im.load()
    def s(x, y, c):
        xx, yy = ox + x, oy + y
        if 0 <= xx < im.width and 0 <= yy < im.height:
            p[xx, yy] = c

    # ── Hair (rows 0-3) — bright green mohawk-style cap, 5 rows tall
    for x in (7, 8): s(x, 0, HAIR_L)               # crown spike
    for x in range(6, 10): s(x, 1, HAIR_L)         # top of cap
    for x in range(5, 11): s(x, 2, HAIR)           # main hair band
    for x in range(5, 11): s(x, 3, HAIR_D)         # underside of hair
    s(4, 3, HAIR_D); s(11, 3, HAIR_D)              # side wisps

    # ── Face (row 4) — skin band with two white eyes
    for x in range(5, 11): s(x, 4, SKIN)
    s(6, 4, EYE_W)                                  # left eye
    s(9, 4, EYE_W)                                  # right eye
    # ── Chin/cheek (row 5) — narrow
    for x in range(6, 10): s(x, 5, SKIN_D)

    # ── Robe collar (row 6) — narrow shoulders
    for x in range(5, 11): s(x, 6, ROBE_L)
    # ── Robe body — bell widens downward
    for x in range(4, 12): s(x, 7, ROBE)
    for x in range(4, 12): s(x, 8, ROBE)
    for x in range(4, 12): s(x, 9, ROBE)
    for x in range(3, 13): s(x, 10, ROBE_D)
    for x in range(3, 13): s(x, 11, ROBE_D)
    # ── Hem (row 12) — widest, darker
    for x in range(3, 13): s(x, 12, ROBE_D)
    s(2, 12, ROBE_D); s(13, 12, ROBE_D)

    # ── Arms (overwrite robe shoulders/sides)
    if arms == "down":
        s(3, 8, SKIN); s(12, 8, SKIN)
        s(3, 9, SKIN_D); s(12, 9, SKIN_D)
    elif arms == "side":  # blocker — arms stretched horizontally
        for x in (1, 2, 3): s(x, 8, SKIN)
        for x in (12, 13, 14): s(x, 8, SKIN)
        s(0, 8, SKIN_D); s(15, 8, SKIN_D)
    elif arms == "up":  # climber/cheer — arms raised
        s(3, 5, SKIN); s(12, 5, SKIN)
        s(3, 6, SKIN); s(12, 6, SKIN)
        s(3, 7, SKIN_D); s(12, 7, SKIN_D)
    elif arms == "fwd_swing":  # basher arms forward
        for x in (12, 13, 14, 15): s(x, 8, SKIN)
        for x in (12, 13, 14, 15): s(x, 9, SKIN_D)
    elif arms == "fwd_pick":  # digger holding pick downward
        s(12, 8, SKIN); s(13, 8, SKIN)
        s(12, 9, SKIN_D); s(13, 9, SKIN_D)

    # ── Legs/feet (rows 13-15)
    if leg_pose == "together":
        for x in (6, 7): s(x, 13, ROBE_D)
        for x in (8, 9): s(x, 13, ROBE_D)
        s(6, 14, SKIN_D); s(7, 14, SKIN_D)
        s(8, 14, SKIN_D); s(9, 14, SKIN_D)
        # feet
        s(5, 15, PUPIL); s(6, 15, PUPIL)
        s(9, 15, PUPIL); s(10, 15, PUPIL)
    elif leg_pose == "split":  # walking peak — legs spread
        s(4, 13, ROBE_D); s(5, 13, SKIN_D); s(4, 14, SKIN_D)
        s(3, 15, PUPIL); s(4, 15, PUPIL)
        s(11, 13, ROBE_D); s(10, 13, SKIN_D); s(11, 14, SKIN_D)
        s(11, 15, PUPIL); s(12, 15, PUPIL)
    elif leg_pose == "mid":  # mid-step — one leg forward, one back
        # back leg
        s(5, 13, ROBE_D); s(5, 14, SKIN_D)
        s(4, 15, PUPIL); s(5, 15, PUPIL)
        # forward leg
        s(10, 13, ROBE_D); s(10, 14, SKIN_D)
        s(10, 15, PUPIL); s(11, 15, PUPIL)


# ── 1. Walking (4 frames) ──────────────────────────────────────────────

def make_walk():
    sheet = img(64, 16)
    poses = [
        ("together", "down"),
        ("mid", "down"),
        ("split", "down"),
        ("mid", "down"),
    ]
    for i, (legs, arms) in enumerate(poses):
        draw_lemming_base(sheet, ox=i * 16, oy=0, leg_pose=legs, arms=arms)
    return sheet


# ── 2. Falling (1 frame) ───────────────────────────────────────────────

def make_fall():
    sheet = img(16, 16)
    draw_lemming_base(sheet, leg_pose="split", arms="up")
    return sheet


# ── 3. Float (2 frames — open parachute over head) ─────────────────────

def make_float():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="up")
        # Parachute as crown above hair
        p = sheet.load()
        cx = i * 16 + 8
        # Half-circle umbrella in row 0-1
        for x in range(cx - 5, cx + 5):
            p[x, 0] = ROBE_L
        for x in range(cx - 4, cx + 4):
            p[x, 1] = ROBE
        # Strings
        p[cx - 3, 2] = WHITE; p[cx + 2, 2] = WHITE
    return sheet


# ── 4. Climb (2 frames — arms raised hugging wall) ─────────────────────

def make_climb():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="up")
        # Hand position alternates
        p = sheet.load()
        ox = i * 16
        if i == 0:
            p[ox + 12, 4] = SKIN; p[ox + 13, 4] = SKIN
        else:
            p[ox + 13, 3] = SKIN; p[ox + 13, 4] = SKIN
    return sheet


# ── 5. Blocker (1 frame — arms out) ────────────────────────────────────

def make_block():
    sheet = img(16, 16)
    draw_lemming_base(sheet, leg_pose="together", arms="side")
    # Stern mouth
    p = sheet.load()
    p[7, 5] = PUPIL; p[8, 5] = PUPIL  # both eyes serious
    return sheet


# ── 6. Builder (3 frames placing brick) ────────────────────────────────

def make_build():
    sheet = img(48, 16)
    for i in range(3):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="down")
        p = sheet.load()
        ox = i * 16
        # Brick stack growing in front (right side)
        levels = [(11, 14), (12, 13), (13, 12)][:i + 1]
        for bx, by in levels:
            for dx in range(3):
                p[ox + bx + dx, by] = BRICK
                if by + 1 < 16:
                    p[ox + bx + dx, by + 1] = BRICK_D
        # Arms forward holding next brick on top frame
        if i == 2:
            p[ox + 12, 7] = SKIN; p[ox + 13, 7] = SKIN
    return sheet


# ── 7. Basher (2 frames — pickaxe sweeping forward) ────────────────────

def make_bash():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="fwd_swing")
        p = sheet.load()
        ox = i * 16
        if i == 0:
            # Pickaxe horizontal
            for x in range(13, 16): p[ox + x, 7] = GREY
            p[ox + 15, 6] = GREY_L
        else:
            # Pickaxe striking down
            for y in range(7, 10): p[ox + 14, y] = GREY
            p[ox + 15, 8] = GREY_L
    return sheet


# ── 8. Miner (2 frames — diagonal pick downward) ───────────────────────

def make_mine():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="fwd_pick")
        p = sheet.load()
        ox = i * 16
        # Diagonal pickaxe
        if i == 0:
            for d in range(3):
                p[ox + 12 + d, 9 + d] = GREY
            p[ox + 14, 11] = GREY_L
        else:
            for d in range(3):
                p[ox + 12 + d, 10 + d] = GREY
            p[ox + 14, 12] = GREY_L
    return sheet


# ── 9. Digger (2 frames — pickaxe straight down) ───────────────────────

def make_dig():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="fwd_pick")
        p = sheet.load()
        ox = i * 16
        # Vertical pickaxe head below
        if i == 0:
            for y in range(11, 14): p[ox + 8, y] = GREY
            p[ox + 7, 14] = GREY_L; p[ox + 9, 14] = GREY_L
        else:
            for y in range(12, 15): p[ox + 8, y] = GREY
            p[ox + 7, 15] = GREY_L; p[ox + 9, 15] = GREY_L
    return sheet


# ── 10. Bomb (2 frames — flashing red/yellow) ──────────────────────────

def make_bomb():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="down")
        p = sheet.load()
        ox = i * 16
        glow = RED if i == 0 else YELLOW
        # Overlay tint on robe rows
        for y in range(6, 11):
            for x in range(3, 13):
                cur = p[ox + x, y]
                if cur[3] == 255 and cur != SKIN and cur != SKIN_D:
                    p[ox + x, y] = glow
        # Fuse spark above hair
        p[ox + 8, 0] = glow
    return sheet


# ── 11. Splat (1 frame) ────────────────────────────────────────────────

def make_die():
    sheet = img(16, 16)
    p = sheet.load()
    # Red splat — irregular blob in lower half
    splat = [
        (3, 12), (4, 12), (5, 11), (6, 11), (7, 11), (8, 11), (9, 11),
        (10, 11), (11, 12), (12, 12),
        (2, 13), (3, 13), (4, 13), (5, 13), (6, 13), (7, 13), (8, 13),
        (9, 13), (10, 13), (11, 13), (12, 13), (13, 13),
        (3, 14), (4, 14), (5, 14), (8, 14), (10, 14), (11, 14),
        (5, 15), (9, 15),
    ]
    for (x, y) in splat:
        p[x, y] = RED
    # Highlights
    for (x, y) in [(4, 12), (10, 12), (6, 14)]:
        p[x, y] = ORANGE
    # Small tufts of green hair scattered
    p[4, 11] = HAIR; p[11, 11] = HAIR
    return sheet


# ── 12. Exit cheer (1 frame — arms up "yippee") ────────────────────────

def make_exit_anim():
    sheet = img(16, 16)
    draw_lemming_base(sheet, leg_pose="together", arms="up")
    return sheet


# ── 13. Entrance/Exit world objects (32×32) ────────────────────────────

def make_entrance_obj():
    """Trap-door / hatch above ground. 32×16."""
    im = img(32, 16)
    p = im.load()
    # Door frame
    fill(im, 4, 0, 27, 2, DOOR)
    fill(im, 4, 3, 5, 14, DOOR)
    fill(im, 26, 3, 27, 14, DOOR)
    # Inner darkness
    fill(im, 6, 3, 25, 14, (0x18, 0x18, 0x28, 255))
    # Lintel highlight
    fill(im, 4, 0, 27, 0, DOOR_L)
    # "IN" arrow chevron
    for d in range(3):
        p[14 + d, 4 + d] = WHITE
        p[18 - d, 4 + d] = WHITE
    for x in range(13, 20):
        p[x, 8] = WHITE
    return im


def make_exit_obj():
    """Exit pillar — green door with arrow. 32×32."""
    im = img(32, 32)
    p = im.load()
    # Pillar base (steel)
    fill(im, 2, 28, 29, 31, STEEL_D)
    fill(im, 2, 28, 29, 28, STEEL_L)
    # Green door body
    fill(im, 4, 4, 27, 27, EXIT_GRN)
    # Border
    fill(im, 4, 4, 27, 4, WHITE)
    fill(im, 4, 27, 27, 27, GRASS_D)
    fill(im, 4, 4, 4, 27, WHITE)
    fill(im, 27, 4, 27, 27, GRASS_D)
    # Up-arrow inside
    for d in range(6):
        p[15, 8 + d] = WHITE; p[16, 8 + d] = WHITE
    for d in range(5):
        p[11 + d, 12 - d] = WHITE
        p[20 - d, 12 - d] = WHITE
    # Roof beam
    fill(im, 0, 0, 31, 3, DOOR)
    fill(im, 0, 0, 31, 0, DOOR_L)
    return im


# ── 14. Tileset atlas: 32×16 (dirt+grass tile, steel tile) ─────────────

def make_tileset():
    # 48x16 — three tiles side by side:
    #   (0..15)  grass-topped dirt (used on every platform's top row)
    #   (16..31) plain dirt (used for rows beneath the surface, also for built bricks)
    #   (32..47) steel
    im = img(48, 16)
    p = im.load()

    # Tile 0: dirt with crisp grass band on top (cols 0-15)
    # Grass: 4-row band — dark base, two greens, light highlight
    for x in range(16):
        p[x, 0] = GRASS_L
    for x in range(16):
        p[x, 1] = GRASS
    for x in range(16):
        p[x, 2] = GRASS
    for x in range(16):
        p[x, 3] = GRASS_D
    # Scattered light-green blades poking up
    for x in (1, 4, 8, 11, 14):
        p[x, 0] = GRASS
    for x in (3, 7, 12):
        p[x, 0] = WHITE  # dew/highlight sparkle (single px)
    # Dirt body (rows 4-15) — base + lighter speckles + dark pockets
    for y in range(4, 16):
        for x in range(16):
            p[x, y] = DIRT
            if (x + y * 2) % 5 == 0:
                p[x, y] = DIRT_L
            if (x * 3 + y * 7) % 13 == 0:
                p[x, y] = DIRT_D
            if (x * 5 + y * 11) % 29 == 0:
                p[x, y] = DIRT_DD
    # A few small stones embedded
    for (sx, sy) in [(2, 9), (10, 12), (6, 14)]:
        p[sx, sy] = STEEL_D
        if sx + 1 < 16:
            p[sx + 1, sy] = GREY_D

    # Tile 1: pure dirt (cols 16-31) — for subsurface and built bricks
    for y in range(16):
        for x in range(16, 32):
            p[x, y] = DIRT_D
            lx = x - 16
            if (lx + y * 2) % 5 == 0:
                p[x, y] = DIRT
            if (lx * 3 + y * 7) % 11 == 0:
                p[x, y] = DIRT_DD
            if (lx * 5 + y * 11) % 19 == 0:
                p[x, y] = DIRT_L
    # Subtle horizontal seams every 4 rows to give "packed earth" texture
    for y in (3, 7, 11):
        for x in range(16, 32):
            if (x + y) % 4 == 0:
                p[x, y] = DIRT_DD

    # Tile 2: steel (cols 32-47) — silver with horizontal striped pattern
    for y in range(16):
        for x in range(32, 48):
            band = y // 2
            if band % 2 == 0:
                p[x, y] = STEEL
            else:
                p[x, y] = STEEL_D
    # Bevels
    for x in range(32, 48):
        p[x, 0] = STEEL_L
    for y in range(16):
        p[32, y] = STEEL_L
    for x in range(32, 48):
        p[x, 15] = STEEL_D
    for y in range(16):
        p[47, y] = STEEL_D
    # Rivets at corners — light dome highlight
    for (rx, ry) in [(34, 2), (45, 2), (34, 13), (45, 13)]:
        p[rx, ry] = STEEL_D
        p[rx + 1, ry] = STEEL_D
        p[rx, ry + 1] = STEEL_D
        p[rx + 1, ry + 1] = STEEL_D
        p[rx, ry] = STEEL_L
    # Specular shine across middle band
    for x in range(36, 44):
        p[x, 7] = STEEL_L

    return im


# ── 15. Background tile / parallax (optional sky gradient) ─────────────

def make_bg_sky():
    # Tall gradient — dark blue at the top fading to nearly black at the bottom.
    h = 240
    im = img(64, h)
    p = im.load()
    for y in range(h):
        t = y / float(h - 1)
        if t < 0.5:
            k = t / 0.5
            r = int(SKY_TOP[0] * (1 - k) + SKY_MID[0] * k)
            g = int(SKY_TOP[1] * (1 - k) + SKY_MID[1] * k)
            b = int(SKY_TOP[2] * (1 - k) + SKY_MID[2] * k)
        else:
            k = (t - 0.5) / 0.5
            r = int(SKY_MID[0] * (1 - k) + SKY_BOT[0] * k)
            g = int(SKY_MID[1] * (1 - k) + SKY_BOT[1] * k)
            b = int(SKY_MID[2] * (1 - k) + SKY_BOT[2] * k)
        for x in range(64):
            p[x, y] = (r, g, b, 255)
    # Scattered stars (only in the upper half where sky is visible)
    star_positions = [
        (5, 8), (17, 4), (29, 11), (44, 6), (55, 14),
        (9, 22), (37, 26), (58, 31), (12, 40), (49, 47),
        (22, 18), (50, 22), (3, 32), (40, 38), (15, 55),
        (33, 60), (60, 70), (8, 80), (45, 90), (25, 100),
    ]
    for (x, y) in star_positions:
        if 0 <= y < h:
            p[x, y] = WHITE
            # Soft halo around the brightest stars
            if (x * y) % 7 == 0 and 0 < x < 63 and 0 < y < h - 1:
                p[x - 1, y] = (180, 180, 200, 255)
                p[x + 1, y] = (180, 180, 200, 255)
    return im


# ── Main ───────────────────────────────────────────────────────────────

def main():
    targets = [
        (SPR / "lemming_walk.png",  make_walk()),
        (SPR / "lemming_fall.png",  make_fall()),
        (SPR / "lemming_float.png", make_float()),
        (SPR / "lemming_climb.png", make_climb()),
        (SPR / "lemming_block.png", make_block()),
        (SPR / "lemming_build.png", make_build()),
        (SPR / "lemming_bash.png",  make_bash()),
        (SPR / "lemming_mine.png",  make_mine()),
        (SPR / "lemming_dig.png",   make_dig()),
        (SPR / "lemming_bomb.png",  make_bomb()),
        (SPR / "lemming_die.png",   make_die()),
        (SPR / "lemming_exit.png",  make_exit_anim()),
        (SPR / "entrance.png",      make_entrance_obj()),
        (SPR / "exit_door.png",     make_exit_obj()),
        (SPR / "bg_sky.png",        make_bg_sky()),
        (TIL / "main_atlas.png",    make_tileset()),
    ]
    for path, im in targets:
        im.save(path)
        print(f"wrote {path}  ({im.size[0]}x{im.size[1]})")


if __name__ == "__main__":
    main()
