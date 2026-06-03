#!/usr/bin/env python3
"""Generate pixel-art sprites, tileset, and background for the Lemmings clone.

Atlas layout (128x16, 8 tiles wide):
    cols 0..4 — terrain variants (grass-A, dirt-A, grass-B, dirt-B, dirt-C-rock)
    cols 5..7 — steel variants  (plate, rivet, warning-stripe)
The two TileSet sources map source-0 to cols 0..4 and source-1 (margin x=80) to cols 5..7.

All output goes under assets/. Sprite sheets stack frames horizontally so the
offset of frame N is (N*16, 0).
"""

from PIL import Image
from pathlib import Path
import math

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
# Earth tones — warmer, more saturated for vintage Amiga feel
DIRT_LL= (0xd6, 0xa3, 0x4a, 255)
DIRT_L = (0xb0, 0x7a, 0x2a, 255)
DIRT   = (0x82, 0x55, 0x16, 255)
DIRT_D = (0x55, 0x36, 0x0a, 255)
DIRT_DD= (0x2c, 0x1c, 0x06, 255)
ROOT_DK= (0x3c, 0x22, 0x08, 255)
GRASS  = (0x32, 0xb8, 0x32, 255)
GRASS_D= (0x10, 0x70, 0x18, 255)
GRASS_DD=(0x06, 0x40, 0x10, 255)
GRASS_L= (0x66, 0xea, 0x55, 255)
GRASS_LL=(0xb0, 0xff, 0x7a, 255)
FLOWER_R=(0xff, 0xa8, 0xc0, 255)
FLOWER_Y=(0xff, 0xee, 0x66, 255)
FLOWER_W=(0xff, 0xff, 0xff, 255)
STONE_L= (0xc0, 0xb8, 0xa8, 255)
STONE  = (0x88, 0x80, 0x70, 255)
STONE_D= (0x4a, 0x44, 0x3a, 255)
STEEL  = (0x95, 0x9a, 0xa2, 255)
STEEL_L= (0xd6, 0xda, 0xe0, 255)
STEEL_LL=(0xf0, 0xf2, 0xf6, 255)
STEEL_D= (0x4a, 0x4f, 0x57, 255)
STEEL_DD=(0x2a, 0x2d, 0x32, 255)
RUST   = (0xa8, 0x55, 0x22, 255)
WARN_Y = (0xff, 0xcc, 0x33, 255)
WARN_K = (0x22, 0x22, 0x22, 255)
DOOR   = (0x66, 0x33, 0x11, 255)
DOOR_L = (0xaa, 0x77, 0x33, 255)
DOOR_LL= (0xd0, 0x99, 0x44, 255)
EXIT_GRN=(0x44, 0xee, 0x44, 255)
EXIT_GRN_D=(0x18, 0x88, 0x22, 255)
MARBLE_L=(0xee, 0xea, 0xe0, 255)
MARBLE  =(0xc4, 0xbc, 0xa8, 255)
MARBLE_D=(0x90, 0x86, 0x70, 255)
SKY_TOP= (0x18, 0x12, 0x4a, 255)
SKY_HI = (0x35, 0x2a, 0x88, 255)
SKY_MID= (0x0e, 0x0c, 0x36, 255)
SKY_BOT= (0x04, 0x03, 0x14, 255)
HILL_D = (0x14, 0x16, 0x42, 255)
HILL_DD= (0x0a, 0x0c, 0x2e, 255)
MOON   = (0xfa, 0xf0, 0xc4, 255)
MOON_D = (0xc0, 0xa8, 0x70, 255)
LAMP_GLOW=(0xff, 0xe6, 0x88, 255)
LAMP_DK= (0x66, 0x44, 0x18, 255)

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


def putpx(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.load()[x, y] = c


# ── Lemming sprite (unchanged design) ──────────────────────────────────

def draw_lemming_base(im, *, ox=0, oy=0, leg_pose="together", arms="down"):
    p = im.load()
    def s(x, y, c):
        xx, yy = ox + x, oy + y
        if 0 <= xx < im.width and 0 <= yy < im.height:
            p[xx, yy] = c

    for x in (7, 8): s(x, 0, HAIR_L)
    for x in range(6, 10): s(x, 1, HAIR_L)
    for x in range(5, 11): s(x, 2, HAIR)
    for x in range(5, 11): s(x, 3, HAIR_D)
    s(4, 3, HAIR_D); s(11, 3, HAIR_D)

    for x in range(5, 11): s(x, 4, SKIN)
    s(6, 4, EYE_W)
    s(9, 4, EYE_W)
    for x in range(6, 10): s(x, 5, SKIN_D)

    for x in range(5, 11): s(x, 6, ROBE_L)
    for x in range(4, 12): s(x, 7, ROBE)
    for x in range(4, 12): s(x, 8, ROBE)
    for x in range(4, 12): s(x, 9, ROBE)
    for x in range(3, 13): s(x, 10, ROBE_D)
    for x in range(3, 13): s(x, 11, ROBE_D)
    for x in range(3, 13): s(x, 12, ROBE_D)
    s(2, 12, ROBE_D); s(13, 12, ROBE_D)

    if arms == "down":
        s(3, 8, SKIN); s(12, 8, SKIN)
        s(3, 9, SKIN_D); s(12, 9, SKIN_D)
    elif arms == "side":
        for x in (1, 2, 3): s(x, 8, SKIN)
        for x in (12, 13, 14): s(x, 8, SKIN)
        s(0, 8, SKIN_D); s(15, 8, SKIN_D)
    elif arms == "up":
        s(3, 5, SKIN); s(12, 5, SKIN)
        s(3, 6, SKIN); s(12, 6, SKIN)
        s(3, 7, SKIN_D); s(12, 7, SKIN_D)
    elif arms == "fwd_swing":
        for x in (12, 13, 14, 15): s(x, 8, SKIN)
        for x in (12, 13, 14, 15): s(x, 9, SKIN_D)
    elif arms == "fwd_pick":
        s(12, 8, SKIN); s(13, 8, SKIN)
        s(12, 9, SKIN_D); s(13, 9, SKIN_D)

    if leg_pose == "together":
        for x in (6, 7, 8, 9): s(x, 13, ROBE_D)
        s(6, 14, SKIN_D); s(7, 14, SKIN_D)
        s(8, 14, SKIN_D); s(9, 14, SKIN_D)
        s(5, 15, PUPIL); s(6, 15, PUPIL)
        s(9, 15, PUPIL); s(10, 15, PUPIL)
    elif leg_pose == "split":
        s(4, 13, ROBE_D); s(5, 13, SKIN_D); s(4, 14, SKIN_D)
        s(3, 15, PUPIL); s(4, 15, PUPIL)
        s(11, 13, ROBE_D); s(10, 13, SKIN_D); s(11, 14, SKIN_D)
        s(11, 15, PUPIL); s(12, 15, PUPIL)
    elif leg_pose == "mid":
        s(5, 13, ROBE_D); s(5, 14, SKIN_D)
        s(4, 15, PUPIL); s(5, 15, PUPIL)
        s(10, 13, ROBE_D); s(10, 14, SKIN_D)
        s(10, 15, PUPIL); s(11, 15, PUPIL)


def make_walk():
    sheet = img(64, 16)
    poses = [("together", "down"), ("mid", "down"),
             ("split", "down"), ("mid", "down")]
    for i, (legs, arms) in enumerate(poses):
        draw_lemming_base(sheet, ox=i * 16, oy=0, leg_pose=legs, arms=arms)
    return sheet


def make_fall():
    sheet = img(16, 16)
    draw_lemming_base(sheet, leg_pose="split", arms="up")
    return sheet


def make_float():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="up")
        p = sheet.load()
        cx = i * 16 + 8
        for x in range(cx - 5, cx + 5):
            p[x, 0] = ROBE_L
        for x in range(cx - 4, cx + 4):
            p[x, 1] = ROBE
        p[cx - 3, 2] = WHITE; p[cx + 2, 2] = WHITE
    return sheet


def make_climb():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="up")
        p = sheet.load()
        ox = i * 16
        if i == 0:
            p[ox + 12, 4] = SKIN; p[ox + 13, 4] = SKIN
        else:
            p[ox + 13, 3] = SKIN; p[ox + 13, 4] = SKIN
    return sheet


def make_block():
    sheet = img(16, 16)
    draw_lemming_base(sheet, leg_pose="together", arms="side")
    p = sheet.load()
    p[7, 5] = PUPIL; p[8, 5] = PUPIL
    return sheet


def make_build():
    sheet = img(48, 16)
    for i in range(3):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="down")
        p = sheet.load()
        ox = i * 16
        levels = [(11, 14), (12, 13), (13, 12)][:i + 1]
        for bx, by in levels:
            for dx in range(3):
                p[ox + bx + dx, by] = BRICK
                if by + 1 < 16:
                    p[ox + bx + dx, by + 1] = BRICK_D
        if i == 2:
            p[ox + 12, 7] = SKIN; p[ox + 13, 7] = SKIN
    return sheet


def make_bash():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="fwd_swing")
        p = sheet.load()
        ox = i * 16
        if i == 0:
            for x in range(13, 16): p[ox + x, 7] = GREY
            p[ox + 15, 6] = GREY_L
        else:
            for y in range(7, 10): p[ox + 14, y] = GREY
            p[ox + 15, 8] = GREY_L
    return sheet


def make_mine():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="fwd_pick")
        p = sheet.load()
        ox = i * 16
        if i == 0:
            for d in range(3): p[ox + 12 + d, 9 + d] = GREY
            p[ox + 14, 11] = GREY_L
        else:
            for d in range(3): p[ox + 12 + d, 10 + d] = GREY
            p[ox + 14, 12] = GREY_L
    return sheet


def make_dig():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="fwd_pick")
        p = sheet.load()
        ox = i * 16
        if i == 0:
            for y in range(11, 14): p[ox + 8, y] = GREY
            p[ox + 7, 14] = GREY_L; p[ox + 9, 14] = GREY_L
        else:
            for y in range(12, 15): p[ox + 8, y] = GREY
            p[ox + 7, 15] = GREY_L; p[ox + 9, 15] = GREY_L
    return sheet


def make_bomb():
    sheet = img(32, 16)
    for i in range(2):
        draw_lemming_base(sheet, ox=i * 16, leg_pose="together", arms="down")
        p = sheet.load()
        ox = i * 16
        glow = RED if i == 0 else YELLOW
        for y in range(6, 11):
            for x in range(3, 13):
                cur = p[ox + x, y]
                if cur[3] == 255 and cur != SKIN and cur != SKIN_D:
                    p[ox + x, y] = glow
        p[ox + 8, 0] = glow
    return sheet


def make_die():
    sheet = img(16, 16)
    p = sheet.load()
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
    for (x, y) in [(4, 12), (10, 12), (6, 14)]:
        p[x, y] = ORANGE
    p[4, 11] = HAIR; p[11, 11] = HAIR
    return sheet


def make_exit_anim():
    sheet = img(16, 16)
    draw_lemming_base(sheet, leg_pose="together", arms="up")
    return sheet


# ── World objects ──────────────────────────────────────────────────────

def make_entrance_obj():
    """Trapdoor hatch — 32x16. Iron-banded wooden door under a tile roof,
    with two warning lamps and a chevron pointing down. Reads as a Lemmings
    'spawn hatch' even at this tiny size."""
    im = img(32, 16)
    p = im.load()

    # Roof beam — slate-style two-tone overhang, full width
    fill(im, 0, 0, 31, 0, STEEL_DD)
    fill(im, 1, 1, 30, 1, STEEL_D)
    fill(im, 2, 2, 29, 2, STEEL)
    # Roof highlight pixels (rivets along the eave)
    for x in (3, 9, 16, 22, 28):
        p[x, 1] = STEEL_LL

    # Side posts (iron struts)
    fill(im, 3, 3, 4, 14, STEEL_D)
    fill(im, 27, 3, 28, 14, STEEL_D)
    p[3, 3] = STEEL; p[28, 3] = STEEL
    p[3, 14] = STEEL_DD; p[28, 14] = STEEL_DD
    # Foot plates
    fill(im, 2, 15, 5, 15, STEEL_DD)
    fill(im, 26, 15, 29, 15, STEEL_DD)

    # Door panel — dark wood with grain
    fill(im, 5, 3, 26, 14, DOOR)
    # Wood grain — vertical streaks
    for x in (7, 11, 15, 19, 23):
        for y in range(3, 14):
            if (x + y) % 3 == 0:
                p[x, y] = DOOR_L
            elif (x + y) % 5 == 0:
                p[x, y] = (0x40, 0x1c, 0x06, 255)
    # Iron banding — top and bottom bands across the door
    fill(im, 5, 3, 26, 3, STEEL_D)
    fill(im, 5, 13, 26, 13, STEEL_D)
    # Rivets on the bands
    for x in (6, 10, 15, 20, 25):
        p[x, 3] = STEEL_LL
        p[x, 13] = STEEL_LL

    # Two warning lamps glowing on either side of the chevron
    p[7, 6] = LAMP_GLOW; p[7, 7] = LAMP_DK
    p[24, 6] = LAMP_GLOW; p[24, 7] = LAMP_DK
    # Soft halo
    p[6, 6] = (0xff, 0xc8, 0x44, 255); p[8, 6] = (0xff, 0xc8, 0x44, 255)
    p[23, 6] = (0xff, 0xc8, 0x44, 255); p[25, 6] = (0xff, 0xc8, 0x44, 255)

    # Down-chevron (arrow) — big, centered
    for d in range(4):
        p[12 + d, 6 + d] = WHITE
        p[19 - d, 6 + d] = WHITE
    # Inner outline shadow for contrast
    for d in range(4):
        p[12 + d, 7 + d] = STEEL_D
        p[19 - d, 7 + d] = STEEL_D

    return im


def make_exit_obj():
    """Classical pillared exit door — 32x32. Two marble columns flanking a
    glowing green panel with an up-arrow, capped with a wooden lintel and
    a brass nameplate. Steel base step."""
    im = img(32, 32)
    p = im.load()

    # Sky-tone backdrop tinted slightly so the door reads against any bg
    # (kept fully transparent in the corners — only the door body is opaque)

    # Roof lintel — wooden beam with brass nameplate centered
    fill(im, 0, 0, 31, 2, DOOR_L)
    fill(im, 0, 0, 31, 0, DOOR_LL)
    fill(im, 0, 2, 31, 2, DOOR)
    # Brass nameplate
    fill(im, 11, 1, 20, 1, WARN_Y)
    p[12, 1] = WARN_K; p[15, 1] = WARN_K; p[18, 1] = WARN_K  # rivets

    # Triangular pediment hint above the lintel (rooflet)
    for d in range(5):
        for x in range(15 - d, 17 + d):
            putpx(im, x, 0 - d if 0 - d >= 0 else 0, T)  # noop guard
    # (No upward growth — kept within 32×32 bounds.)

    # Marble columns left + right
    for col_x in (3, 4, 26, 27):
        fill(im, col_x, 3, col_x, 26, MARBLE)
    # Column flutes
    for y in range(4, 26):
        p[3, y] = MARBLE_L if y % 3 == 0 else MARBLE
        p[4, y] = MARBLE_D if y % 3 == 0 else MARBLE
        p[26, y] = MARBLE_L if y % 3 == 0 else MARBLE
        p[27, y] = MARBLE_D if y % 3 == 0 else MARBLE
    # Capitals + bases
    fill(im, 2, 3, 5, 4, MARBLE_L)
    fill(im, 25, 3, 28, 4, MARBLE_L)
    fill(im, 2, 25, 5, 26, MARBLE_D)
    fill(im, 25, 25, 28, 26, MARBLE_D)

    # Door panel — green with darker frame
    fill(im, 6, 4, 25, 26, EXIT_GRN_D)
    fill(im, 7, 5, 24, 25, EXIT_GRN)
    # Border highlight
    for x in range(7, 25):
        p[x, 5] = (0x88, 0xff, 0x88, 255)
    for y in range(5, 25):
        p[7, y] = (0x88, 0xff, 0x88, 255)
    # Shadow border
    for x in range(7, 25):
        p[x, 25] = EXIT_GRN_D
    for y in range(5, 25):
        p[24, y] = EXIT_GRN_D

    # Big up-arrow inside
    for d in range(8):
        p[15, 9 + d] = WHITE; p[16, 9 + d] = WHITE
    for d in range(6):
        p[10 + d, 14 - d] = WHITE
        p[21 - d, 14 - d] = WHITE
    # Arrow shadow
    for d in range(8):
        p[17, 9 + d] = EXIT_GRN_D

    # Steel step / base
    fill(im, 1, 27, 30, 30, STEEL_D)
    fill(im, 1, 27, 30, 27, STEEL_L)
    fill(im, 1, 30, 30, 30, STEEL_DD)
    fill(im, 1, 31, 30, 31, STEEL_DD)
    # Rivets in the step
    for x in (4, 11, 20, 27):
        p[x, 28] = STEEL_LL
        p[x, 29] = STEEL_DD

    return im


# ── Tileset atlas (128×16) ──────────────────────────────────────────────
# Tile layout (8 cols × 1 row):
#   0: grass-top A     1: dirt body A
#   2: grass-top B     3: dirt body B
#   4: dirt-with-rock  5: steel plate   6: steel rivet   7: steel warning

def _draw_dirt_body(im, x0, *, seed=0, variant="A"):
    """Fill a 16x16 region starting at column x0 with dirt earth pattern."""
    p = im.load()
    for y in range(16):
        for x in range(16):
            ax = x0 + x
            base = DIRT_D
            n = (x * 7 + y * 13 + seed) & 0xff
            n2 = (x * 11 + y * 5 + seed * 3) & 0xff
            if n < 80:
                base = DIRT
            elif n < 110:
                base = DIRT_L
            if n2 < 40:
                base = DIRT_DD
            elif n2 > 230:
                base = DIRT_LL
            p[ax, y] = base
    # Pack-soil seams every few rows (horizontal striations)
    seams = {"A": (4, 9, 13), "B": (3, 8, 12), "C": (5, 10, 14)}.get(variant, (4, 9, 13))
    for y in seams:
        for x in range(16):
            if (x + y + seed) % 3 != 0:
                p[x0 + x, y] = DIRT_DD
    # Variant-specific embellishments
    if variant == "B":
        # Tangled roots
        roots = [(2, 6), (3, 7), (4, 8), (5, 9), (6, 10),
                 (10, 4), (11, 5), (12, 6), (13, 7),
                 (1, 11), (2, 12), (3, 13)]
        for (rx, ry) in roots:
            p[x0 + rx, ry] = ROOT_DK
    elif variant == "C":
        # Embedded stone
        stone_cluster = [
            (5, 6), (6, 6), (7, 6), (8, 6),
            (4, 7), (5, 7), (6, 7), (7, 7), (8, 7), (9, 7),
            (4, 8), (5, 8), (6, 8), (7, 8), (8, 8), (9, 8), (10, 8),
            (5, 9), (6, 9), (7, 9), (8, 9), (9, 9),
            (6, 10), (7, 10), (8, 10),
        ]
        for (sx, sy) in stone_cluster:
            p[x0 + sx, sy] = STONE
        # Stone highlights
        for (sx, sy) in [(5, 6), (6, 6), (5, 7)]:
            p[x0 + sx, sy] = STONE_L
        # Stone shadow
        for (sx, sy) in [(9, 8), (10, 8), (8, 10), (9, 9)]:
            p[x0 + sx, sy] = STONE_D
    else:  # "A" — small pebbles
        pebbles = [(2, 5), (11, 7), (4, 11), (13, 13)]
        for (px_, py_) in pebbles:
            p[x0 + px_, py_] = STONE
            if px_ + 1 < 16:
                p[x0 + px_ + 1, py_] = STONE_D


def _draw_grass_top(im, x0, *, variant="A"):
    """Fill 16x16 starting at x0 with grass surface (top ~6 rows) over dirt (rows 6-15)."""
    p = im.load()
    # Dirt subsoil under the grass band
    seed = {"A": 11, "B": 23}.get(variant, 11)
    for y in range(6, 16):
        for x in range(16):
            base = DIRT
            n = (x * 7 + y * 13 + seed) & 0xff
            if n < 60:
                base = DIRT_D
            elif n > 200:
                base = DIRT_L
            p[x0 + x, y] = base
    # Horizontal "packed soil" line where grass meets dirt
    for x in range(16):
        if x % 3 != 0:
            p[x0 + x, 6] = DIRT_DD

    # Grass band — 5 rows tall, with chunky organic blades
    fill(im, x0, 0, x0 + 15, 0, T)  # leave top row transparent for irregularity
    # Row 1 — tallest blades
    for x in range(16):
        p[x0 + x, 1] = T
    # Row 2-5 — grass body
    fill(im, x0, 2, x0 + 15, 2, GRASS_LL)
    fill(im, x0, 3, x0 + 15, 3, GRASS_L)
    fill(im, x0, 4, x0 + 15, 4, GRASS)
    fill(im, x0, 5, x0 + 15, 5, GRASS_D)

    if variant == "A":
        # Tall scattered blades poking into rows 0-1
        blade_xs = [(1, 4), (3, 3), (7, 4), (10, 3), (12, 4), (14, 3)]
        for (bx, bh) in blade_xs:
            top_y = 5 - bh
            for y in range(top_y, 2):
                p[x0 + bx, y] = GRASS
            p[x0 + bx, top_y] = GRASS_L
        # Single dewdrop sparkle
        p[x0 + 5, 2] = WHITE
        p[x0 + 13, 2] = (0xcc, 0xff, 0xcc, 255)
    else:  # variant B with flowers
        blade_xs = [(2, 3), (5, 4), (9, 3), (11, 4), (14, 3)]
        for (bx, bh) in blade_xs:
            top_y = 5 - bh
            for y in range(top_y, 2):
                p[x0 + bx, y] = GRASS
            p[x0 + bx, top_y] = GRASS_L
        # Flowers — small 1px caps with stem
        # Pink flower at x=7
        p[x0 + 7, 1] = FLOWER_R
        p[x0 + 6, 2] = FLOWER_R; p[x0 + 8, 2] = FLOWER_R
        p[x0 + 7, 2] = FLOWER_Y  # yellow center
        p[x0 + 7, 3] = GRASS_D  # stem
        # White daisy at x=13
        p[x0 + 13, 1] = FLOWER_W
        p[x0 + 12, 2] = FLOWER_W; p[x0 + 14, 2] = FLOWER_W
        p[x0 + 13, 2] = FLOWER_Y
        p[x0 + 13, 3] = GRASS_D

    # Underside of grass (root tangle into dirt) — micro detail row 6
    for x in (1, 5, 9, 12, 14):
        p[x0 + x, 6] = GRASS_DD


def _draw_steel(im, x0, *, variant="plate"):
    """Fill 16x16 starting at x0 with steel pattern."""
    p = im.load()
    # Base — horizontal banded steel
    for y in range(16):
        for x in range(16):
            band = y // 2
            base = STEEL if band % 2 == 0 else STEEL_D
            p[x0 + x, y] = base
    # Outer bevels
    for x in range(16):
        p[x0 + x, 0] = STEEL_LL
        p[x0 + x, 15] = STEEL_DD
    for y in range(16):
        p[x0 + 0, y] = STEEL_LL
        p[x0 + 15, y] = STEEL_DD
    # Inner bevel one pixel in (gives raised-plate look)
    for x in range(1, 15):
        p[x0 + x, 1] = STEEL_L
        p[x0 + x, 14] = STEEL_D
    for y in range(1, 15):
        p[x0 + 1, y] = STEEL_L
        p[x0 + 14, y] = STEEL_D

    if variant == "plate":
        # Diagonal specular shine
        for d in range(6):
            p[x0 + 4 + d, 5 + d] = STEEL_LL
        # Center spot
        p[x0 + 8, 7] = STEEL_LL
    elif variant == "rivet":
        # Four big rivets — domed
        for (rx, ry) in [(4, 4), (11, 4), (4, 11), (11, 11)]:
            # Dark base ring
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                p[x0 + rx + dx, ry + dy] = STEEL_DD
            # Rivet body
            p[x0 + rx, ry] = STEEL_L
            p[x0 + rx + 1, ry] = STEEL_LL  # highlight
            p[x0 + rx, ry + 1] = STEEL_D
            p[x0 + rx + 1, ry + 1] = STEEL_D
        # Rust streaks below rivets
        for (rx, ry) in [(4, 4), (11, 4)]:
            for d in range(1, 4):
                p[x0 + rx, ry + 1 + d] = RUST if d == 1 else STEEL_D
    elif variant == "warning":
        # Black + yellow hazard stripes diagonally
        for y in range(2, 14):
            for x in range(2, 14):
                # Diagonal stripe equation
                d = (x + y) % 6
                if d < 3:
                    p[x0 + x, y] = WARN_Y
                else:
                    p[x0 + x, y] = WARN_K
        # Frame around the stripes
        for x in range(2, 14):
            p[x0 + x, 2] = STEEL_L
            p[x0 + x, 13] = STEEL_D
        for y in range(2, 14):
            p[x0 + 2, y] = STEEL_L
            p[x0 + 13, y] = STEEL_D


def make_tileset():
    """128×16 atlas — 8 tile columns. See module docstring for layout."""
    im = img(128, 16)
    # Terrain variants (cols 0..4)
    _draw_grass_top(im, 0, variant="A")
    _draw_dirt_body(im, 16, seed=1, variant="A")
    _draw_grass_top(im, 32, variant="B")
    _draw_dirt_body(im, 48, seed=2, variant="B")
    _draw_dirt_body(im, 64, seed=3, variant="C")
    # Steel variants (cols 5..7)
    _draw_steel(im, 80, variant="plate")
    _draw_steel(im, 96, variant="rivet")
    _draw_steel(im, 112, variant="warning")
    return im


# ── Background — full-viewport sky with horizon + mountains + moon ─────

def _hsv_lerp(c0, c1, t):
    return (int(c0[0] * (1 - t) + c1[0] * t),
            int(c0[1] * (1 - t) + c1[1] * t),
            int(c0[2] * (1 - t) + c1[2] * t),
            255)


def make_bg_sky():
    """720×1280 — matches mobile portrait viewport. Gradient sky, scattered
    stars, a soft moon glow upper-right, and two layered mountain silhouettes
    near the horizon zone where most levels place their terrain."""
    W, H = 720, 1280
    im = img(W, H)
    p = im.load()

    horizon_y = 540  # roughly where terrain platforms sit in level scenes

    # Vertical gradient — three-stop (top → upper-mid → horizon hue)
    for y in range(H):
        if y < horizon_y:
            t = y / float(horizon_y)
            if t < 0.55:
                k = t / 0.55
                c = _hsv_lerp(SKY_TOP, SKY_HI, k)
            else:
                k = (t - 0.55) / 0.45
                c = _hsv_lerp(SKY_HI, SKY_MID, k)
        else:
            t = (y - horizon_y) / float(H - horizon_y)
            c = _hsv_lerp(SKY_MID, SKY_BOT, min(1.0, t * 1.5))
        for x in range(W):
            p[x, y] = c

    # Scattered stars in the upper half only
    star_seed = [
        (45, 60), (120, 30), (200, 80), (280, 45), (360, 110), (440, 75),
        (520, 30), (590, 95), (660, 50),
        (30, 160), (95, 220), (175, 180), (260, 245), (340, 200), (415, 270),
        (490, 215), (565, 165), (635, 235), (700, 190),
        (60, 310), (140, 360), (215, 330), (295, 395), (380, 350),
        (460, 405), (540, 340), (615, 380), (685, 315),
        (50, 450), (155, 480), (235, 420), (330, 470), (410, 440),
        (495, 490), (580, 430), (650, 475),
    ]
    for (sx, sy) in star_seed:
        if 0 <= sx < W and 0 <= sy < H:
            p[sx, sy] = WHITE
            # ~half get a halo
            if (sx + sy) % 3 == 0:
                if sx - 1 >= 0: p[sx - 1, sy] = (200, 200, 220, 255)
                if sx + 1 < W: p[sx + 1, sy] = (200, 200, 220, 255)
                if sy - 1 >= 0: p[sx, sy - 1] = (200, 200, 220, 255)
                if sy + 1 < H: p[sx, sy + 1] = (200, 200, 220, 255)
    # A few extra-bright stars with cross-shaped sparkle
    bright_stars = [(120, 30), (440, 75), (340, 200), (615, 380)]
    for (sx, sy) in bright_stars:
        for dx in range(-2, 3):
            if 0 <= sx + dx < W: p[sx + dx, sy] = WHITE
        for dy in range(-2, 3):
            if 0 <= sy + dy < H: p[sx, sy + dy] = WHITE

    # Moon — soft glowing disc, parked top-centre between the typical
    # entrance (x≈80) and exit (x≈560) world positions so it doesn't
    # bleed a halo behind those sprites.
    mx, my, mr = 360, 140, 32
    for y in range(my - mr - 6, my + mr + 6):
        for x in range(mx - mr - 6, mx + mr + 6):
            if not (0 <= x < W and 0 <= y < H):
                continue
            d = math.hypot(x - mx, y - my)
            if d <= mr - 2:
                p[x, y] = MOON
            elif d <= mr:
                p[x, y] = MOON_D
            elif d <= mr + 5:
                # Halo blend
                halo_t = (d - mr) / 5.0
                cur = p[x, y]
                target = MOON_D
                p[x, y] = (
                    int(cur[0] * halo_t + target[0] * (1 - halo_t)),
                    int(cur[1] * halo_t + target[1] * (1 - halo_t)),
                    int(cur[2] * halo_t + target[2] * (1 - halo_t)),
                    255)
    # Moon craters (a couple of darker spots)
    for (cx, cy, cr) in [(mx - 9, my - 4, 3), (mx + 7, my + 10, 3), (mx - 3, my + 12, 2)]:
        for y in range(cy - cr, cy + cr + 1):
            for x in range(cx - cr, cx + cr + 1):
                if 0 <= x < W and 0 <= y < H and math.hypot(x - cx, y - cy) <= cr:
                    p[x, y] = MOON_D

    # Distant mountain silhouettes — two layers near the horizon zone
    def _mountain(amp, base_y, color, period, phase):
        for x in range(W):
            h = int(amp * (0.5 + 0.5 * math.sin(x / period + phase)
                          + 0.25 * math.sin(x / (period * 0.37) + phase * 2.1)))
            top = base_y - h
            for y in range(top, base_y + 1):
                if 0 <= y < H:
                    p[x, y] = color

    _mountain(amp=80, base_y=horizon_y - 4, color=HILL_DD, period=110, phase=0.7)
    _mountain(amp=46, base_y=horizon_y, color=HILL_D, period=70, phase=2.1)

    # Faint ground haze just above the horizon (blue glow)
    for y in range(horizon_y - 14, horizon_y):
        for x in range(W):
            cur = p[x, y]
            # Tint warmer / blueish along this band only where pixel isn't a mountain or star
            if cur == HILL_D or cur == HILL_DD or cur == WHITE:
                continue
            blend = (y - (horizon_y - 14)) / 14.0
            tgt = (0x22, 0x30, 0x6e, 255)
            p[x, y] = (
                int(cur[0] * (1 - blend * 0.4) + tgt[0] * blend * 0.4),
                int(cur[1] * (1 - blend * 0.4) + tgt[1] * blend * 0.4),
                int(cur[2] * (1 - blend * 0.4) + tgt[2] * blend * 0.4),
                255)

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
