"""Builds the Super Mushshak sprites from the owner's art.

Source: docs/reference/super_mushshak_sprite_source.png (plane on white).
Output (all the same canvas size, so they line up):
  assets/sprites/super_mushshak_body.png  - plane without gear blades
  assets/sprites/super_mushshak_gear.png  - landing gear (slides up to retract)
  assets/sprites/super_mushshak_prop.png  - propeller blades (shown when running)

Textures are stored at TEXTURE_SCALE x the on-screen size and drawn scaled
down (with mipmaps) so the plane looks smooth, like the art, not blocky.
Prints the numbers to put into data/aircraft/super_mushshak.tres.

Run from the project root (needs Pillow: pip install pillow):
    python tools/make_mushshak_from_art.py
"""
from collections import deque
from PIL import Image

SRC = "docs/reference/super_mushshak_sprite_source.png"
OUT = "assets/sprites/super_mushshak_%s.png"

# On-screen length of the whole plane (world px; the world is 4 px per metre).
DISPLAY_WIDTH = 70
# Texture pixels per world pixel.
TEXTURE_SCALE = 4

# Regions in SOURCE image pixels.
# Landing gear = pixels below a cut line inside each x range. Each entry:
# (x0, x1, cut y at x0, cut y at x1); the cut follows the fuselage underside.
GEAR_REGIONS = [(440, 585, 231, 231),   # main gear (twin wheels)
                (600, 735, 233, 210)]   # nose gear (leg slants up to the cowling)
GEAR_CUT_Y = 231                        # main-gear cut, used for the retract travel
PROP_MIN_X = 724                        # propeller blades: right of this...
PROP_SPINNER_Y = (148, 198)             # ...but not the spinner/nose band in the middle
FLAP_HINGE_SRC = (368, 126)           # wing trailing edge (for the code-drawn flap)


def is_bg(p):
    r, g, b = p[:3]
    return min(r, g, b) >= 232


def main():
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    px = im.load()

    # 1. Flood-fill the white background from the borders -> transparent.
    seen = [[False] * h for _ in range(w)]
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[x][y]:
            continue
        seen[x][y] = True
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    # 2. Soften the light halo left from anti-aliasing against white.
    for _ in range(2):
        clear = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0 or min(r, g, b) < 215 or max(r, g, b) - min(r, g, b) > 25:
                    continue
                if any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    clear.append((x, y))
        for x, y in clear:
            px[x, y] = (0, 0, 0, 0)

    # 3. Split into layers.
    body = im.copy()
    gear = Image.new("RGBA", im.size, (0, 0, 0, 0))
    prop = Image.new("RGBA", im.size, (0, 0, 0, 0))
    bp, gp, pp = body.load(), gear.load(), prop.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if any(x0 <= x <= x1 and y >= y0 + (y1 - y0) * (x - x0) / (x1 - x0)
                   for x0, x1, y0, y1 in GEAR_REGIONS):
                gp[x, y] = px[x, y]; bp[x, y] = (0, 0, 0, 0)
            elif x >= PROP_MIN_X and not (PROP_SPINNER_Y[0] <= y <= PROP_SPINNER_Y[1]):
                pp[x, y] = px[x, y]; bp[x, y] = (0, 0, 0, 0)

    # 4. Crop all layers to the plane's bounding box and scale down together.
    box = im.getbbox()
    out_w = DISPLAY_WIDTH * TEXTURE_SCALE
    k = out_w / (box[2] - box[0])
    out_h = round((box[3] - box[1]) * k)
    for name, layer in (("body", body), ("gear", gear), ("prop", prop)):
        layer.crop(box).resize((out_w, out_h), Image.LANCZOS).save(OUT % name)

    def t(x, y):  # source px -> texture px
        return round((x - box[0]) * k, 1), round((y - box[1]) * k, 1)

    gear_top = t(0, GEAR_CUT_Y)[1]
    spinner = t(w - 1, (PROP_SPINNER_Y[0] + PROP_SPINNER_Y[1]) / 2)
    print("texture size:", out_w, "x", out_h, " scale:", 1 / TEXTURE_SCALE)
    print("sprite_wheel_bottom_y =", out_h)
    print("sprite_gear_travel =", round(out_h - gear_top, 1))
    print("sprite_prop_center =", spinner)
    print("sprite_flap_hinge =", t(*FLAP_HINGE_SRC))


if __name__ == "__main__":
    main()
