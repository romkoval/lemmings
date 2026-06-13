#!/usr/bin/env python3
"""Slice the AI-generated reference art into normalised per-state frames.

The reference poses (assets/characters/lemming/ref/) are inconsistent in scale,
position and framing, and several share a sheet cell with neighbours / floating
text / embers. This tool:
  1. crops the chosen region for each game state,
  2. optionally colour-keys an opaque background (the brick wall behind climb),
  3. keeps only large connected alpha components (drops text, embers, neighbour
     fragments),
  4. normalises every pose to a common scale by body height and drops it onto a
     shared canvas with the FEET on a fixed baseline (the LemmingSprite anchor),
  5. writes assets/characters/lemming/frames/<state>_<i>.png.

Pure PIL (no numpy). Deterministic. Re-run after editing the STATES table.
"""
from PIL import Image
from collections import deque
import os

REF = "assets/characters/lemming/ref"
OUT = "assets/characters/lemming/frames"
os.makedirs(OUT, exist_ok=True)

# Common output canvas (logical px) and supersample. The runtime adapter draws
# the texture at scale 1/SS with offset = -FEET, so FEET lands on the node origin.
CANVAS_W, CANVAS_H = 56, 84
FEET = (28, 80)            # where the soles sit inside the canvas (logical px)
SS = 4                     # supersample for crisp downscaling on hi-dpi
TARGET_BODY = 30           # default figure height in logical px (feet→top of art)

CW, CH = 170, 204          # sheet cell size (all sheets are 1024x1024, 6x5)

def cell_box(n):
    c, r = n % 6, n // 6
    return (c * CW, r * CH, c * CW + CW, r * CH + CH)

# state -> list of frames; each frame is a dict describing how to extract it.
#   src:    file in REF
#   box:    (x0,y0,x1,y1) crop, or None for whole image
#   target: figure height in logical px (override TARGET_BODY for props/arms-up)
#   flip:   mirror horizontally so the pose faces RIGHT (our canonical dir=1)
#   wall:   (r,g,b,tol) colour-key to drop an opaque background before component pick
#   keep_frac: keep alpha components whose area >= keep_frac * largest (drops text)
STATES = {
    "walk":  [{"src": "sheet.png", "box": cell_box(0)},
              {"src": "sheet.png", "box": cell_box(1)}],
    "dig":   [{"src": "sheet.png", "box": cell_box(10)}],
    "bash":  [{"src": "sheet.png", "box": cell_box(18)}],
    "mine":  [{"src": "sheet.png", "box": cell_box(16)}],
    "build": [{"src": "sheet.png", "box": cell_box(2)}],
    "block": [{"src": "pose_block.png", "box": None, "target": 30}],
    "float": [{"src": "pose_float.png", "box": None, "target": 64}],  # man+canopy tall
    "cheer": [{"src": "sheet_extra1.png", "box": cell_box(0),  "target": 38}],
    "panic": [{"src": "sheet_extra2.png", "box": cell_box(0),  "target": 38, "keep_frac": 0.40}],
    "fall":  [{"src": "sheet_extra2.png", "box": cell_box(1),  "target": 36}],
    "climb": [{"src": "sheet_extra2.png", "box": (12, 432, 158, 602),
               "wall": [(150, 110, 70, 85), (188, 168, 142, 46), (120, 92, 64, 70)],
               "target": 34, "keep_frac": 0.5, "flip": True}],
    "splat": [{"src": "sheet_extra1.png", "box": cell_box(29), "target": 24, "keep_frac": 0.25}],
}


def load(src):
    return Image.open(os.path.join(REF, src)).convert("RGBA")


def colour_key(im, keys):
    """Make pixels within tol of any (r,g,b,tol) key transparent (brick wall)."""
    px = im.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            for r0, g0, b0, tol in keys:
                if abs(r - r0) < tol and abs(g - g0) < tol and abs(b - b0) < tol:
                    px[x, y] = (0, 0, 0, 0)
                    break
    return im


def largest_components(im, keep_frac):
    """Keep alpha blobs with area >= keep_frac * largest; clear the rest."""
    W, H = im.size
    px = im.load()
    seen = bytearray(W * H)
    comps = []
    for sy in range(H):
        for sx in range(W):
            i = sy * W + sx
            if seen[i] or px[sx, sy][3] <= 40:
                continue
            q = deque([(sx, sy)]); seen[i] = 1; pix = []
            while q:
                x, y = q.popleft(); pix.append((x, y))
                for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                    if 0 <= nx < W and 0 <= ny < H:
                        j = ny * W + nx
                        if not seen[j] and px[nx, ny][3] > 40:
                            seen[j] = 1; q.append((nx, ny))
            comps.append(pix)
    if not comps:
        return im
    biggest = max(len(c) for c in comps)
    thr = biggest * keep_frac
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    op = out.load()
    for c in comps:
        if len(c) >= thr:
            for x, y in c:
                op[x, y] = px[x, y]
    return out


def extract(spec):
    im = load(spec["src"])
    if spec.get("box"):
        im = im.crop(spec["box"])
    if spec.get("wall"):
        im = colour_key(im, spec["wall"])
    im = largest_components(im, spec.get("keep_frac", 0.15))
    bb = im.split()[3].getbbox()
    if bb is None:
        raise SystemExit("empty extraction for %s" % spec)
    im = im.crop(bb)
    if spec.get("flip"):
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


def place(im, target_h):
    """Scale so the art is target_h logical px tall, drop on the shared canvas
    with feet centred on FEET. Returns an RGBA image (CANVAS*SS)."""
    cw, ch = CANVAS_W * SS, CANVAS_H * SS
    scale = (target_h * SS) / im.height
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    im = im.resize((w, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    fx, fy = FEET[0] * SS, FEET[1] * SS
    canvas.alpha_composite(im, (int(fx - w / 2), int(fy - h)))
    return canvas


def build(only=None):
    manifest = {}
    for state, frames in STATES.items():
        if only and state not in only:
            continue
        paths = []
        for i, spec in enumerate(frames):
            art = extract(spec)
            canvas = place(art, spec.get("target", TARGET_BODY))
            p = os.path.join(OUT, "%s_%d.png" % (state, i))
            canvas.save(p)
            paths.append(p)
        manifest[state] = paths
        print("%-7s -> %s" % (state, ", ".join(os.path.basename(p) for p in paths)))
    return manifest


if __name__ == "__main__":
    import sys
    only = set(sys.argv[1:]) or None
    build(only)
