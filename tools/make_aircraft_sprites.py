"""Builds aircraft sprites from the owner's art (plane on a white background).

    python tools/make_aircraft_sprites.py            # all aircraft
    python tools/make_aircraft_sprites.py f16        # one aircraft
(needs Pillow: pip install pillow)

For each aircraft in CONFIGS it removes the white background and writes
aligned layers to assets/sprites/<name>_<layer>.png:
  body - the aircraft (minus gear/prop if those are split out)
  gear - landing gear cut from the art (slides up to retract), optional
  prop - propeller blades (shown while the engine runs), optional
Front-view configs (k8_front, jf17_front, f16_front) make parked-aircraft scenery.
  elevator - the tailplane cut out of the art (drawn rotating with the
             stick), optional. The body under it comes from the owner's
             no-tailplane picture (F-16A), or for art without one (F-16D)
             from that body plus this aircraft's own nozzle, mirrored
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
        # Owner's F-16D art (No. 11 Sqn "Falcons", 10805), drawn with the gear
        # DOWN: the gear is cut to its own layer and slides up into the body.
        # (Old retracted-gear art: docs/reference/f16d_old_sprite_source.png.)
        "src": "docs/reference/f16_sprite_source.png",
        "display_width": 115,  # world px; the F-16 is ~2x the Mushshak's length
        # Main gear below the fuselage; nose gear = strut column + wheel below the tank.
        "gear_regions": [(274, 326, 249, 249), (473, 482, 255, 255), (462, 492, 270, 270)],
        # Travel = wheel bottom up to y 245, so the main wheel hides fully in the body.
        "gear_cut_y": 245,
        "prop": None,
        "points": {"nozzle": (50, 184), "main_wheel": (295, 0), "elevator_hinge": (128, 202),
                   "light_landing": (477, 262)},
        # All-moving tailplane, in OUTPUT texture px (see the f16a config).
        "elevator": {"poly": [(0, 131), (14, 108), (78, 106), (79, 111), (52, 117), (32, 123), (13, 131)],
                     # No picture of the D without its tailplane: what it hides is taken from
                     # the F-16A body (built from the owner's no-tailplane art; build f16a
                     # first if that art changes), the D's own nozzle mirrored about its axis
                     # (= sprite_nozzle.y) up to nozzle_x_max.
                     "under_donor": "assets/sprites/f16a_body.png", "donor_offset": (0, 1),
                     "nozzle_axis_y": 101, "nozzle_x_max": 30},
    },
    "f16a": {
        # Owner's F-16A art (No. 9 Sqn "Griffins", 84717). Same pose and size as
        # the F-16D, gear retracted: gear drawn in code, tailplane cut to its own layer.
        # Owner's pair (2026-11-18): the art with the tailplane, and the same art
        # WITHOUT it (full nozzle and the fixed shelf under the tailplane). The
        # no-tailplane picture is the body; the tailplane layer is the difference.
        # (Same art as the older f16a_sprite_source.png, shifted by (15, 4) px.)
        "src": "docs/reference/f16a_with_tailplane_source.png",
        "display_width": 115,
        "gear_regions": [],
        "prop": None,
        # Gear tops sit hidden behind the stores/fuselage; the wheels reach the same
        # height below the fuselage as on the F-16D (fin top to wheel = 275 src px).
        "points": {"nozzle": (71, 185), "main_gear_top": (363, 254), "nose_gear_top": (498, 252),
                   "wheel_bottom": (0, 307), "elevator_hinge": (143, 203)},
        # under_offset: where the no-tailplane picture sits on the with-tailplane one.
        # poly: the tailplane outline in OUTPUT texture px (cut from the with-tailplane art).
        "elevator": {"under_src": "docs/reference/f16a_no_tailplane_source.png", "under_offset": (5, -12),
                     "poly": [(0, 131), (14, 110), (79, 108), (80, 112), (50, 118), (30, 123), (12, 131)]},
    },
    "mirage5": {
        "src": "docs/reference/mirage5_sprite_source.png",   # owner's art with the gear down
        "display_width": 118,  # world px; 15.5 m, about the F-16's length
        "gear_regions": [(285, 336, 266, 266), (548, 596, 219, 219)],   # main wheel, nose gear
        "gear_cut_y": 219,
        "prop": None,
        "points": {"nozzle": (55, 182), "main_wheel": (312, 0), "light_nav_near": (160, 208),
                   "light_nav_far": (185, 203), "light_tail": (55, 140), "light_beacon": (38, 38),
                   "light_landing": (575, 252)},
    },
    # Front views for parked aircraft (base scenery, not flyable). "erase" blanks
    # the phone share/copy/download buttons in the top-right of the screenshots.
    "k8_front": {
        "src": "docs/reference/k8_front_source.png",
        "display_width": 40,   # K-8 span 9.6 m
        "erase": [(680, 0, 853, 50)],
        "gear_regions": [], "prop": None, "points": {},
    },
    "jf17_front": {
        "src": "docs/reference/jf17_front_source.png",
        "display_width": 40,   # JF-17 span 9.45 m incl. wingtip missiles
        "erase": [(680, 0, 846, 50)],
        "gear_regions": [], "prop": None, "points": {},
    },
    "f16_front": {
        "src": "docs/reference/f16_front_source.png",
        "display_width": 42,   # F-16 span 9.96 m incl. wingtip missiles
        "erase": [(680, 0, 852, 50)],
        "gear_regions": [], "prop": None, "points": {},
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


def _fill_under_tailplane(body, cut, donor, donor_offset, axis_y, nozzle_x_max):
    """Paints what the tailplane hides, for art that has no picture without it
    (the F-16D): the same area of a donor body that does (the F-16A, built from
    the owner's no-tailplane art, same pose and size), and over that the lower
    half of this aircraft's own nozzle, mirrored from its visible top half
    (the nozzle is a cylinder; the D's is tan, the A's dark)."""
    bpx, dpx = body.load(), donor.load()
    w, h = body.size
    dw, dh = donor.size
    dx, dy = donor_offset
    for x in range(w):
        bottom = -1
        if x < nozzle_x_max and bpx[x, axis_y][3] > 0:
            top = axis_y
            while top - 1 >= 0 and bpx[x, top - 1][3] > 0:
                top -= 1
            bottom = 2 * axis_y - top
        for y in range(h):
            if x < nozzle_x_max and y > max(bottom, axis_y) and y < axis_y + 35:
                # Under this nozzle there is only sky (the donor's nozzle is bigger,
                # and specks of the tailplane outline can sit outside the cut).
                bpx[x, y] = (0, 0, 0, 0)
                continue
            if not cut[x, y]:
                continue
            if axis_y < y <= bottom:
                bpx[x, y] = bpx[x, 2 * axis_y - y]
            else:
                sx, sy = x - dx, y - dy
                bpx[x, y] = dpx[sx, sy] if 0 <= sx < dw and 0 <= sy < dh else (0, 0, 0, 0)


def build(name, cfg):
    im = Image.open(cfg["src"]).convert("RGBA")
    for box in cfg.get("erase", []):
        im.paste((255, 255, 255, 255), box)
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
    if cfg.get("elevator") and cfg["elevator"].get("under_src"):
        # The owner's art also exists WITHOUT the tailplane: that picture is the
        # body, and the tailplane layer is what differs between the two.
        e = cfg["elevator"]
        under = Image.new("RGBA", im.size, (255, 255, 255, 255))
        under.paste(Image.open(e["under_src"]).convert("RGBA"), e["under_offset"])
        remove_background(under)
        under = under.crop(box).resize((out_w, out_h), Image.LANCZOS)
        mask = Image.new("L", (out_w, out_h), 0)
        ImageDraw.Draw(mask).polygon(e["poly"], fill=255)
        elev = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
        elev.paste(out["body"], (0, 0), mask)
        out["elevator"] = elev
        out["body"] = under
    elif cfg.get("elevator"):
        e = cfg["elevator"]
        mask = Image.new("L", (out_w, out_h), 0)
        ImageDraw.Draw(mask).polygon(e["poly"], fill=255)
        elev = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
        elev.paste(out["body"], (0, 0), mask)
        donor = Image.open(e["under_donor"]).convert("RGBA")
        _fill_under_tailplane(out["body"], mask.load(), donor, e["donor_offset"],
                              e["nozzle_axis_y"], e["nozzle_x_max"])
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
