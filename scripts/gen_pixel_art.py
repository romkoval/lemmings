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
HAIR_D = (0x00, 0x99, 0x33, 255)
HAIR   = (0x00, 0xcc, 0x44, 255)
HAIR_L = (0x00, 0xff, 0x55, 255)
ROBE_D = (0x11, 0x22, 0x88, 255)
ROBE   = (0x22, 0x44, 0xcc, 255)
ROBE_L = (0x44, 0x66, 0xff, 255)
SKIN   = (0xff, 0xcc, 0x99, 255)
SKIN_D = (0xff, 0xbb, 0x77, 255)
EYE_W  = (0xff, 0xff, 0xff, 255)
PUPIL  = (0x00, 0x00, 0x00, 255)
RED    = (0xff, 0x33, 0x33, 255)
ORANGE = (0xff, 0x88, 0x22, 255)
YELLOW = (0xff, 0xee, 0x44, 255)
WHITE  = (0xff, 0xff, 0xff, 255)
BRICK  = (0xcc, 0x66, 0x33, 255)
BRICK_D= (0x88, 0x44, 0x22, 255)
GREY_L = (0xcc, 0xcc, 0xcc, 255)
GREY   = (0x99, 0x99, 0x99, 255)
GREY_D = (0x55, 0x55, 0x55, 255)
DIRT_L = (0xa0, 0x80, 0x30, 255)
DIRT   = (0x8b, 0x69, 0x14, 255)
DIRT_D = (0x6b, 0x49, 0x14, 255)
GRASS  = (0x22, 0x8b, 0x22, 255)
GRASS_D= (0x00, 0x64, 0x00, 255)
GRASS_L= (0x44, 0xcc, 0x44, 255)
STEEL  = (0x88, 0x88, 0x88, 255)
STEEL_L= (0xbb, 0xbb, 0xbb, 255)
STEEL_D= (0x55, 0x55, 0x55, 255)
DOOR   = (0x66, 0x33, 0x11, 255)
DOOR_L = (0xaa, 0x77, 0x33, 255)
EXIT_GRN=(0x44, 0xee, 0x44, 255)

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

    leg_pose: 'together' | 'split' | 'mid'
    arms: 'down' | 'side' | 'up' | 'fwd_swing' | 'fwd_pick'
    """
    p = im.load()
    def set(x, y, c):
        xx, yy = ox + x, oy + y
        if 0 <= xx < im.width and 0 <= yy < im.height:
            p[xx, yy] = c

    # ── Hair (rows 1-3) — spiky green cap
    for x in (5, 7, 9): set(x, 1, HAIR_L)
    for x in range(4, 12): set(x, 2, HAIR)
    for x in range(4, 12): set(x, 3, HAIR_D)

    # ── Face (rows 4-5) — skin
    for x in range(5, 11): set(x, 4, SKIN)
    for x in range(5, 11): set(x, 5, SKIN)
    # Eyes (facing right): two white pixels on right side
    set(8, 5, EYE_W); set(9, 5, PUPIL)

    # ── Robe shoulders (row 6)
    for x in range(4, 12): set(x, 6, ROBE)
    # ── Robe body (rows 7-10) — bell shape
    for x in range(4, 12): set(x, 7, ROBE)
    for x in range(3, 13): set(x, 8, ROBE)
    for x in range(3, 13): set(x, 9, ROBE_D)
    for x in range(3, 13): set(x, 10, ROBE_D)

    # ── Arms
    if arms == "down":
        set(3, 7, SKIN); set(12, 7, SKIN)
        set(3, 8, SKIN); set(12, 8, SKIN)
    elif arms == "side":  # blocker — arms out
        set(2, 7, SKIN); set(13, 7, SKIN)
        set(1, 7, SKIN); set(14, 7, SKIN)
        set(2, 8, SKIN); set(13, 8, SKIN)
    elif arms == "up":  # climber/cheer — arms raised
        set(3, 5, SKIN); set(12, 5, SKIN)
        set(3, 6, SKIN); set(12, 6, SKIN)
    elif arms == "fwd_swing":  # basher arms out front
        for x in (12, 13, 14): set(x, 7, SKIN)
        for x in (12, 13, 14): set(x, 8, SKIN_D)
    elif arms == "fwd_pick":  # digger holding pick down
        set(12, 7, SKIN); set(12, 8, SKIN)
        set(11, 9, SKIN); set(11, 10, SKIN)

    # ── Legs/feet
    if leg_pose == "together":
        for x in (5, 6): set(x, 11, ROBE_D); set(x, 12, SKIN_D)
        for x in (9, 10): set(x, 11, ROBE_D); set(x, 12, SKIN_D)
        for x in (5, 6, 9, 10): set(x, 13, SKIN_D)
    elif leg_pose == "split":  # legs apart, walking peak
        set(4, 11, ROBE_D); set(4, 12, SKIN_D); set(3, 13, SKIN_D)
        set(11, 11, ROBE_D); set(11, 12, SKIN_D); set(12, 13, SKIN_D)
        # Inner pair tucked
        set(7, 11, ROBE_D); set(8, 11, ROBE_D)
    elif leg_pose == "mid":  # mid-step
        for x in (5, 6): set(x, 11, ROBE_D)
        set(6, 12, SKIN_D); set(5, 13, SKIN_D)
        for x in (9, 10): set(x, 11, ROBE_D)
        set(9, 12, SKIN_D); set(10, 13, SKIN_D)


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
    im = img(32, 16)
    p = im.load()

    # Tile 0: dirt with grass top (cols 0-15)
    # Grass row (top 3 rows)
    for x in range(16):
        p[x, 0] = GRASS_D
        p[x, 1] = GRASS
        p[x, 2] = GRASS_L if (x % 3) else GRASS
    # Dirt body
    for y in range(3, 16):
        for x in range(16):
            # Base dirt
            p[x, y] = DIRT
            # Lighten checker
            if (x + y) % 3 == 0:
                p[x, y] = DIRT_L
            # Dark speckles
            if (x * 7 + y * 13) % 11 == 0:
                p[x, y] = DIRT_D
    # Few grass blades hanging
    for x in (2, 7, 12):
        p[x, 3] = GRASS

    # Tile 1: steel (cols 16-31)
    for y in range(16):
        for x in range(16, 32):
            p[x, y] = STEEL
    # Bevel
    for x in range(16, 32):
        p[x, 0] = STEEL_L
    for y in range(16):
        p[16, y] = STEEL_L
        p[31, y] = STEEL_D
    for x in range(16, 32):
        p[x, 15] = STEEL_D
    # Rivets at corners
    for (rx, ry) in [(18, 2), (29, 2), (18, 13), (29, 13)]:
        p[rx, ry] = STEEL_D
        p[rx + 1, ry] = STEEL_D
        p[rx, ry + 1] = STEEL_D
        p[rx + 1, ry + 1] = STEEL_D
        p[rx, ry] = STEEL_L
    # Shine line
    for x in range(20, 28):
        p[x, 6] = STEEL_L

    return im


# ── 15. Background tile / parallax (optional sky gradient) ─────────────

def make_bg_sky():
    im = img(64, 64)
    p = im.load()
    for y in range(64):
        t = y / 63.0
        r = int(0x1a * (1 - t) + 0x0d * t)
        g = int(0x1a * (1 - t) + 0x0d * t)
        b = int(0x3e * (1 - t) + 0x2b * t)
        for x in range(64):
            p[x, y] = (r, g, b, 255)
    # Scattered stars
    star_positions = [(5, 8), (17, 4), (29, 11), (44, 6), (55, 14),
                       (9, 22), (37, 26), (58, 31), (12, 40), (49, 47)]
    for (x, y) in star_positions:
        p[x, y] = WHITE
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
