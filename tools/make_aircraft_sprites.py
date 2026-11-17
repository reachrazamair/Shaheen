"""Builds aircraft sprites from the owner's art (plane on a white background).

    python tools/make_aircraft_sprites.py            # all aircraft
    python tools/make_aircraft_sprites.py f16        # one aircraft
(needs Pillow: pip install pillow)

For each aircraft in CONFIGS it removes the white background and writes
aligned layers to assets/sprites/<name>_<layer>.png:
  body - the aircraft (minus gear/prop if those are split out)
  gear - landing gear cut from the art (slides up to retract), optional
  prop - propeller blades (shown while the engine runs), optional
  elevator - the tailplane cut out of the body (drawn rotating with the
             stick), optional; the hole left in the body is filled with a
             dark fuselage grey where it overlaps the fuselage
Textures are stored at TEXTURE_SCALE x the on-screen size and drawn scaled
down with mipmaps, so they look like the art rather than blocky.
It prints texture-space positions to copy into data/aircraft/<name>.tres.
"""
import sys
from collections import deque
from PIL import Image, ImageDraw

TEXTURE_SCALE = 4   # texture px per world px

CONFIGS = {
    "super_mushshak": {
        "src": "docs/reference/super_mushshak_sprite_source.png",
        "display_width": 70,   # world px (owner: "original size")
        # Gear = pixels below a cut line inside each x range: (x0, x1, cut y at x0, cut y at x1).
        "gear_regions": [(440, 585, 231, 231), (600, 735, 233, 210)],
        "gear_cut_y": 231,
        # Propeller blades: right of min_x, outside the spinner band.
        "prop": {"min_x": 724, "spinner_y": (148, 198)},
        "points": {"flap_hinge": (368, 126), "prop_center": (742, 173)},
    },
    "f16": {
        "src": "docs/reference/f16_sprite_source.png",
        "display_width": 115,  # world px; the F-16 is ~2x the Mushshak's length
        "gear_regions": [],    # the art shows the gear retracted: gear is drawn in code
        "prop": None,
        # Points for code-drawn parts (source px): engine nozzle, gear attach points
        # on the fuselage underside, and where the wheels must reach (below the tank).
        "points": {"nozzle": (56, 190), "main_gear_top": (340, 262), "nose_gear_top": (476, 241),
                   "wheel_bottom": (0, 296), "elevator_hinge": (125, 199)},
        # All-moving tailplane, in OUTPUT texture px: outline polygon, hole fill
        # colour, and the hole is only filled right of fill_min_x (left of it
        # there is no fuselage behind the tailplane, just sky).
        "elevator": {"poly": [(3, 111), (79, 110), (79, 119), (42, 126), (10, 127), (3, 125)],
                     "fill": (66, 70, 76, 255), "fill_min_x": 13},
    },
}


def is_bg(p):
    return min(p[:3]) >= 232


def remove_background(im):
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    # Soften the light halo left from anti-aliasing against white.
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


def build(name, cfg):
    im = Image.open(cfg["src"]).convert("RGBA")
    remove_background(im)
    w, h = im.size
    px = im.load()
    layers = {"body": im.copy()}
    if cfg["gear_regions"]:
        layers["gear"] = Image.new("RGBA", im.size, (0, 0, 0, 0))
    if cfg["prop"]:
        layers["prop"] = Image.new("RGBA", im.size, (0, 0, 0, 0))
    bp = layers["body"].load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if "gear" in layers and any(x0 <= x <= x1 and y >= y0 + (y1 - y0) * (x - x0) / (x1 - x0)
                                        for x0, x1, y0, y1 in cfg["gear_regions"]):
                layers["gear"].putpixel((x, y), px[x, y]); bp[x, y] = (0, 0, 0, 0)
            elif "prop" in layers and x >= cfg["prop"]["min_x"] and not (
                    cfg["prop"]["spinner_y"][0] <= y <= cfg["prop"]["spinner_y"][1]):
                layers["prop"].putpixel((x, y), px[x, y]); bp[x, y] = (0, 0, 0, 0)

    box = im.getbbox()
    out_w = cfg["display_width"] * TEXTURE_SCALE
    k = out_w / (box[2] - box[0])
    out_h = round((box[3] - box[1]) * k)
    out = {layer: img.crop(box).resize((out_w, out_h), Image.LANCZOS) for layer, img in layers.items()}
    if cfg.get("elevator"):
        e = cfg["elevator"]
        mask = Image.new("L", (out_w, out_h), 0)
        ImageDraw.Draw(mask).polygon(e["poly"], fill=255)
        elev = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
        elev.paste(out["body"], (0, 0), mask)
        body = out["body"]
        bpx, mpx = body.load(), mask.load()
        for y in range(out_h):
            for x in range(out_w):
                if mpx[x, y]:
                    bpx[x, y] = e["fill"] if x >= e["fill_min_x"] and bpx[x, y][3] > 0 else (0, 0, 0, 0)
        out["elevator"] = elev
    for layer, img in out.items():
        img.save("assets/sprites/%s_%s.png" % (name, layer))

    def t(x, y):
        return round((x - box[0]) * k, 1), round((y - box[1]) * k, 1)

    print("== %s: texture %dx%d, sprite_scale %s" % (name, out_w, out_h, 1 / TEXTURE_SCALE))
    if cfg["gear_regions"]:
        print("  sprite_wheel_bottom_y =", out_h)
        print("  sprite_gear_travel =", round(out_h - t(0, cfg["gear_cut_y"])[1], 1))
    for key, pt in cfg["points"].items():
        print("  %s -> %s" % (key, t(*pt)))


if __name__ == "__main__":
    names = sys.argv[1:] or list(CONFIGS)
    for n in names:
        build(n, CONFIGS[n])
