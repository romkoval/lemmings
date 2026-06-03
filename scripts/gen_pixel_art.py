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
# Lava-cavern background (matches the original's molten-rock walls)
CAVE_DK = (0x0a, 0x06, 0x08, 255)
CAVE_MD = (0x16, 0x0a, 0x0a, 255)
ROCK_DD = (0x3a, 0x16, 0x0c, 255)
ROCK_D  = (0x6e, 0x28, 0x12, 255)
ROCK    = (0xa8, 0x42, 0x18, 255)
ROCK_L  = (0xd8, 0x6a, 0x22, 255)
ROCK_LL = (0xf2, 0x9a, 0x3a, 255)
EMBER   = (0xff, 0xcc, 0x55, 255)
# Skill-icon accents
ICON_OUT= (0x10, 0x0c, 0x14, 255)   # near-black outline for contrast
PICK_H  = (0x8a, 0x5a, 0x2a, 255)   # pick / tool handle (wood)
PICK_HD = (0x5a, 0x38, 0x18, 255)
METAL   = (0xc8, 0xcc, 0xd2, 255)
METAL_D = (0x7a, 0x80, 0x88, 255)

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
    """Rocky, cratered earth. Warmer tone, diagonal cracks and embedded boulders
    so a stack of these reads as a rough rock face, not flat brown squares."""
    p = im.load()

    def s(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            p[x0 + x, y] = c

    for y in range(16):
        for x in range(16):
            n = (x * 7 + y * 13 + seed * 17) & 0xff
            n2 = (x * 11 + y * 5 + seed * 3) & 0xff
            if n < 50:
                base = DIRT_D
            elif n < 120:
                base = DIRT
            elif n < 175:
                base = DIRT_L
            else:
                base = DIRT_LL
            if n2 < 26:
                base = DIRT_DD
            s(x, y, base)

    # Irregular diagonal fissures — the single biggest cue against a grid look.
    cracks = {
        "A": [(2, 1), (3, 2), (3, 3), (4, 4), (11, 3), (12, 4), (12, 5), (13, 6)],
        "B": [(5, 0), (5, 1), (6, 2), (6, 3), (7, 4), (1, 9), (2, 10), (3, 11)],
        "C": [(9, 1), (9, 2), (10, 3), (10, 4), (4, 10), (5, 11), (6, 12), (13, 9)],
    }.get(variant, [])
    for (cx, cy) in cracks:
        s(cx, cy, DIRT_DD)
        s(cx, cy + 1, ROOT_DK)

    # Embedded boulders (round clusters with lit top / shadowed underside).
    rocks = {
        "A": [(11, 11, 2), (4, 13, 1)],
        "B": [(4, 6, 2), (12, 12, 1)],
        "C": [(7, 8, 3), (12, 4, 1)],
    }.get(variant, [])
    for (rx, ry, rr) in rocks:
        for dy in range(-rr, rr + 1):
            for dx in range(-rr, rr + 1):
                if dx * dx + dy * dy <= rr * rr:
                    s(rx + dx, ry + dy, STONE)
        s(rx, ry - rr, STONE_L)
        s(rx - 1, ry - rr + 1 if rr > 1 else ry, STONE_L)
        for dx in range(-rr, rr + 1):
            s(rx + dx, ry + rr, STONE_D)


def _draw_grass_top(im, x0, *, variant="A"):
    """Rolling grass surface over rocky subsoil. The grass cap height varies per
    column (rows 0..4) so the walked-on edge is ragged and organic instead of a
    ruler-straight line — collision stays full-tile, this is purely the silhouette."""
    p = im.load()
    seed = {"A": 11, "B": 23}.get(variant, 11)

    def s(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            p[x0 + x, y] = c

    # Rocky subsoil rows 5..15 (same texture family as the dirt body).
    for y in range(5, 16):
        for x in range(16):
            n = (x * 7 + y * 13 + seed) & 0xff
            if n < 50:
                base = DIRT_D
            elif n < 180:
                base = DIRT
            else:
                base = DIRT_L
            s(x, y, base)
    for x in range(16):           # packed-soil seam where grass meets earth
        if x % 3:
            s(x, 5, DIRT_DD)

    # Ragged grass cap: per-column top offset 0..3 (0 = tallest, pokes to row 0).
    for x in range(16):
        off = (x * 5 + seed * 3 + (x * x) % 7) % 4
        top = off
        for y in range(top, 5):
            if y == top:
                c = GRASS_LL if (x * 3 + seed) % 5 == 0 else GRASS_L
            elif y >= 4:
                c = GRASS_D
            elif y == 3:
                c = GRASS
            else:
                c = GRASS_L if (x + seed) % 4 == 0 else GRASS
            s(x, y, c)
        # a few blades droop one extra pixel for an overhang feel
        if (x + seed) % 6 == 0 and top > 0:
            s(x, top - 1, GRASS)

    # Roots tangling down into the soil.
    for x in (1, 5, 9, 12, 14):
        s(x, 5, GRASS_DD)

    if variant == "B":
        # Wildflowers nestled in the taller blades.
        for (fx, fc) in [(4, FLOWER_R), (10, FLOWER_W), (13, FLOWER_Y)]:
            off = (fx * 5 + seed * 3 + (fx * fx) % 7) % 4
            ty = max(0, off - 1)
            s(fx, ty, fc)
            s(fx, ty + 1, FLOWER_Y if fc != FLOWER_Y else GRASS)
    else:
        s(5, 1, WHITE)            # dewdrop sparkle
        s(12, 0, (0xcc, 0xff, 0xcc, 255))


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


def _clamp8(v):
    return 0 if v < 0 else (255 if v > 255 else int(v))


def make_bg_sky():
    """720×1280 lava-cavern backdrop (filename kept for compatibility). A dark
    play-area in the centre so terrain and lemmings pop, framed by a glowing
    molten-rock wall that thickens toward the edges, with stalactites up top and
    a few embers. Echoes the original game's cave tilesets."""
    W, H = 720, 1280
    im = img(W, H)
    p = im.load()

    def rock_shade(t, n):
        # t: 0 (open cavern) .. 1 (bright rock rim). n: -16..15 texture noise.
        if t <= 0.0:
            base = CAVE_DK
        elif t < 0.18:
            base = CAVE_MD
        elif t < 0.36:
            base = ROCK_DD
        elif t < 0.58:
            base = ROCK_D
        elif t < 0.80:
            base = ROCK
        else:
            base = ROCK_L
        k = n * 2.2
        return (_clamp8(base[0] + k), _clamp8(base[1] + k * 0.55),
                _clamp8(base[2] + k * 0.25), 255)

    # Rock frames all four edges around a large dark play area. `e` is the
    # normalised distance to the nearest frame edge (0 at the border, 1 dead
    # centre); rock lives where e is small, the cavern opens up in the middle.
    BAND = 0.46
    for y in range(H):
        ey = min(y, H - 1 - y) / (H * 0.5)
        for x in range(W):
            ex = min(x, W - 1 - x) / (W * 0.5)
            e = ex if ex < ey else ey
            # Craggy boundary: two-octave wobble so the wall isn't a clean frame.
            wob = (0.085 * math.sin(x / 70.0 + y / 110.0)
                   + 0.05 * math.sin(y / 41.0 - x / 57.0)
                   + 0.03 * math.sin((x + y) / 23.0))
            t = (BAND + wob - e) / BAND          # >0 inside the rock band
            t = 0.0 if t < 0 else (1.0 if t > 1 else t)
            n = (((x * 13 + y * 7) ^ (x * 5 + y * 11)) & 0x1f) - 16
            # Mottle the rock with a second coarse band of darker veining.
            if t > 0 and ((x // 7 + y // 5) ^ (x // 11)) & 3 == 0:
                n -= 10
            p[x, y] = rock_shade(t, n)

    # Bright molten veins glowing in the thick rock near the frame edges.
    for (vx, vy, vlen, ph) in [(60, 200, 160, 0.0), (660, 300, 200, 1.1),
                               (90, 980, 220, 2.0), (640, 1040, 180, 0.6),
                               (360, 60, 140, 1.7), (360, 1230, 150, 2.6)]:
        for i in range(vlen):
            ang = ph + i * 0.05
            x = int(vx + math.sin(ang * 1.7) * 18 + (i if vx < W / 2 else -i) * 0.0)
            y = int(vy + i - vlen // 2)
            x += int(8 * math.sin(i / 9.0 + ph))
            if 0 <= x < W and 0 <= y < H:
                cur = p[x, y]
                # only light up where it's already rock (don't bleed into cave)
                if cur[0] > 0x40 or cur[1] > 0x20:
                    p[x, y] = ROCK_LL
                    if x + 1 < W: p[x + 1, y] = EMBER
                    if y + 1 < H: p[x, y + 1] = ROCK_L

    # Stalactites hanging from the cavern ceiling into the dark.
    for (sx, base_len) in [(120, 70), (210, 40), (300, 90), (430, 55),
                           (520, 75), (610, 45), (680, 60), (60, 50)]:
        for j in range(base_len):
            half = max(0, (base_len - j) * 4 // base_len)
            for dx in range(-half, half + 1):
                x = sx + dx
                if 0 <= x < W and j < H:
                    shade = ROCK_D if abs(dx) >= half else (ROCK if dx <= 0 else ROCK_DD)
                    p[x, j] = shade
        p[sx, base_len] = ROCK_L  # wet tip glint

    # Drifting embers / motes in the open cave for a touch of life.
    for (ex, ey) in [(240, 380), (300, 520), (180, 640), (470, 440),
                     (520, 600), (360, 700), (410, 320), (270, 760)]:
        if 0 <= ex < W and 0 <= ey < H:
            p[ex, ey] = EMBER
            if ex + 1 < W: p[ex + 1, ey] = (0xff, 0x99, 0x33, 180)

    return im


# ── Skill button icons (32×32, transparent, auto-outlined) ──────────────

def _disc(im, cx, cy, r, c):
    p = im.load()
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if 0 <= x < im.width and 0 <= y < im.height and (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                p[x, y] = c


def _tri(im, cx, cy, dirn, half, c):
    """Solid triangle, tip at (cx,cy)."""
    for k in range(half + 1):
        if dirn == "up":
            for x in range(cx - k, cx + k + 1): putpx(im, x, cy + k, c)
        elif dirn == "down":
            for x in range(cx - k, cx + k + 1): putpx(im, x, cy - k, c)
        elif dirn == "right":
            for y in range(cy - k, cy + k + 1): putpx(im, cx - k, y, c)
        elif dirn == "left":
            for y in range(cy - k, cy + k + 1): putpx(im, cx + k, y, c)


def _arrow(im, cx, cy, dirn, length, half, c):
    """Arrowhead (tip at cx,cy) plus a shaft extending the opposite way."""
    _tri(im, cx, cy, dirn, half, c)
    s = max(1, half // 2)
    if dirn == "up":
        fill(im, cx - s, cy + half, cx + s, cy + half + length, c)
    elif dirn == "down":
        fill(im, cx - s, cy - half - length, cx + s, cy - half, c)
    elif dirn == "right":
        fill(im, cx - half - length, cy - s, cx - half, cy + s, c)
    elif dirn == "left":
        fill(im, cx + half, cy - s, cx + half + length, cy + s, c)


def _outline(im, c=ICON_OUT):
    """Wrap every opaque shape in a 1px dark border for contrast on any panel."""
    p = im.load()
    W, Hh = im.size
    edge = []
    for y in range(Hh):
        for x in range(W):
            if p[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                           (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < Hh and p[nx, ny][3] == 255 and p[nx, ny] != c:
                    edge.append((x, y))
                    break
    for (x, y) in edge:
        p[x, y] = c


def _mini_lem(im, ox, oy):
    """Tiny 8×13 lemming (green hair, skin face, blue robe) for icons that read
    best with a little worker in them."""
    g, k, r, rd = HAIR, SKIN, ROBE, ROBE_D
    rows = [
        (2, 5, g), (1, 6, g), (5, 6, g),
        (2, 5, k),  # face row handled below
    ]
    # head
    fill(im, ox + 2, oy, ox + 5, oy, g)
    fill(im, ox + 1, oy + 1, ox + 6, oy + 1, g)
    fill(im, ox + 2, oy + 2, ox + 5, oy + 3, k)
    # body
    fill(im, ox + 1, oy + 4, ox + 6, oy + 9, r)
    fill(im, ox + 1, oy + 8, ox + 6, oy + 9, rd)
    # legs
    fill(im, ox + 1, oy + 10, ox + 2, oy + 12, rd)
    fill(im, ox + 5, oy + 10, ox + 6, oy + 12, rd)


def make_icon_climber():
    im = img(32, 32)
    fill(im, 22, 2, 27, 30, DIRT)                    # wall
    for y in range(3, 30, 3): fill(im, 22, y, 27, y, DIRT_D)
    _mini_lem(im, 13, 9)                             # lemming hugging it
    fill(im, 20, 13, 22, 14, SKIN); fill(im, 20, 17, 22, 18, SKIN)  # arms on wall
    _arrow(im, 7, 5, "up", 16, 4, GRASS_L)           # upward motion
    _outline(im); return im


def make_icon_floater():
    im = img(32, 32)
    for j, yy in enumerate(range(5, 12)):            # umbrella dome
        w = 3 + j * 2
        fill(im, 16 - w, yy, 16 + w, yy, ROBE_L if j % 2 == 0 else ROBE)
    fill(im, 16 - 14, 11, 16 + 14, 11, ROBE_D)       # rim
    for rx in (16 - 10, 16, 16 + 10):                # ribs
        for yy in range(5, 12): putpx(im, rx, yy, ROBE_D)
    fill(im, 15, 12, 16, 19, GREY_D)                 # pole
    _mini_lem(im, 12, 18)                            # hanging worker
    _outline(im); return im


def make_icon_bomber():
    im = img(32, 32); p = im.load()
    bomb = (0x24, 0x22, 0x2c, 255)
    _disc(im, 15, 21, 8, bomb)
    _disc(im, 12, 18, 2, GREY)                       # specular
    for (fx, fy) in [(20, 12), (21, 10), (22, 9), (23, 8), (24, 8)]:
        putpx(im, fx, fy, PICK_H)                    # fuse
    p[25, 7] = EMBER; p[24, 6] = YELLOW; p[26, 8] = ORANGE; p[25, 5] = RED
    _outline(im); return im


def make_icon_blocker():
    im = img(32, 32)
    fill(im, 2, 7, 6, 25, RED); fill(im, 25, 7, 29, 25, RED)     # stop bars
    fill(im, 3, 9, 5, 11, WHITE); fill(im, 26, 9, 28, 11, WHITE)  # bar glints
    _mini_lem(im, 12, 9)
    fill(im, 9, 13, 13, 14, SKIN); fill(im, 19, 13, 23, 14, SKIN)  # arms out
    _outline(im); return im


def make_icon_builder():
    im = img(32, 32)
    for (bx, by) in [(2, 25), (9, 21), (16, 17), (23, 13)]:       # staircase
        fill(im, bx, by, bx + 7, by + 5, BRICK)
        fill(im, bx, by, bx + 7, by, DOOR_LL)                    # lit top edge
        fill(im, bx, by + 5, bx + 7, by + 5, BRICK_D)
        putpx(im, bx + 3, by + 2, BRICK_D)                       # mortar
    _mini_lem(im, 22, 1)
    _outline(im); return im


def make_icon_basher():
    im = img(32, 32)
    for (rx, ry) in [(23, 13), (26, 11), (24, 17), (28, 15), (25, 21), (22, 19)]:
        fill(im, rx, ry, rx + 2, ry + 2, DIRT)                   # rubble wall
    _arrow(im, 21, 16, "right", 12, 5, WHITE)                    # smashing right
    fill(im, 6, 19, 12, 20, PICK_H)                              # pick handle
    _outline(im); return im


def make_icon_miner():
    im = img(32, 32); p = im.load()
    for (rx, ry) in [(20, 20), (23, 22), (25, 25), (22, 26), (27, 24)]:
        fill(im, rx, ry, rx + 2, ry + 2, DIRT)                   # rubble lower-right
    for i in range(11):                                          # diagonal arrow
        for w in range(-2, 3):
            putpx(im, 6 + i + w, 6 + i, WHITE)
    _tri(im, 20, 20, "down", 5, WHITE)
    fill(im, 18, 14, 19, 18, WHITE)
    _outline(im); return im


def make_icon_digger():
    im = img(32, 32)
    fill(im, 8, 23, 24, 30, DIRT)                                # ground
    fill(im, 12, 23, 20, 30, CAVE_DK)                            # the hole
    _arrow(im, 16, 22, "down", 13, 5, WHITE)                    # digging down
    fill(im, 11, 4, 21, 6, PICK_H)                              # spade grip
    _outline(im); return im


SKILL_ICONS = {
    "climber": make_icon_climber, "floater": make_icon_floater,
    "bomber": make_icon_bomber,   "blocker": make_icon_blocker,
    "builder": make_icon_builder, "basher": make_icon_basher,
    "miner": make_icon_miner,     "digger": make_icon_digger,
}


# ── Main ───────────────────────────────────────────────────────────────

def main():
    for skill, fn in SKILL_ICONS.items():
        out = SPR / f"skill_{skill}.png"
        fn().save(out)
        print(f"wrote {out}  (32x32)")
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
