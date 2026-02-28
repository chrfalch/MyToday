#!/usr/bin/env python3
"""Generate app icon for MyToday - a macOS menu bar meetings/calendar app.

Design: Cartoony-but-real calendar with rings, red header, big date number,
        and a small schedule preview with colored meeting bars.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ICON_DIR = "MyToday/Assets.xcassets/AppIcon.appiconset"

SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

FONT_PATHS = [
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
]

FONT_PATHS_REG = [
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
]


def get_font(size, bold=True):
    paths = FONT_PATHS if bold else FONT_PATHS_REG
    for path in paths:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


def rounded_rect_path(x0, y0, x1, y1, r):
    """Return list of points for a rounded rectangle (for polygon drawing)."""
    # We'll use the draw primitives approach instead
    pass


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = [int(v) for v in xy]
    r = min(int(radius), (x1 - x0) // 2, max((y1 - y0) // 2, 0))
    if r < 0:
        r = 0
    if fill:
        if x0 + r <= x1 - r:
            draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
        if y0 + r <= y1 - r:
            draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
        draw.ellipse([x0, y0, x0 + 2*r, y0 + 2*r], fill=fill)
        draw.ellipse([x1 - 2*r, y0, x1, y0 + 2*r], fill=fill)
        draw.ellipse([x0, y1 - 2*r, x0 + 2*r, y1], fill=fill)
        draw.ellipse([x1 - 2*r, y1 - 2*r, x1, y1], fill=fill)
    if outline:
        if x0 + r <= x1 - r:
            draw.rectangle([x0 + r, y0, x1 - r, y0 + width], fill=outline)
            draw.rectangle([x0 + r, y1 - width, x1 - r, y1], fill=outline)
        if y0 + r <= y1 - r:
            draw.rectangle([x0, y0 + r, x0 + width, y1 - r], fill=outline)
            draw.rectangle([x1 - width, y0 + r, x1, y1 - r], fill=outline)
        draw.ellipse([x0, y0, x0 + 2*r, y0 + 2*r], outline=outline, width=width)
        draw.ellipse([x1 - 2*r, y0, x1, y0 + 2*r], outline=outline, width=width)
        draw.ellipse([x0, y1 - 2*r, x0 + 2*r, y1], outline=outline, width=width)
        draw.ellipse([x1 - 2*r, y1 - 2*r, x1, y1], outline=outline, width=width)


def create_icon(size):
    """Create the icon at the given pixel size."""
    # Work at 2x for better quality on small sizes, then downscale
    render_size = max(size, 256)
    scale = render_size / size

    s = render_size

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Background: soft sky-blue gradient ──────────────────────────────────
    bg_color_top = (99, 172, 255)
    bg_color_bot = (40, 110, 230)
    bg_r = s * 0.175

    # Gradient background using horizontal strips
    for y in range(s):
        t = y / s
        r = int(bg_color_top[0] * (1-t) + bg_color_bot[0] * t)
        g = int(bg_color_top[1] * (1-t) + bg_color_bot[1] * t)
        b = int(bg_color_top[2] * (1-t) + bg_color_bot[2] * t)
        draw.line([(0, y), (s, y)], fill=(r, g, b, 255))

    # Mask to rounded square
    mask = Image.new("L", (s, s), 0)
    mdraw = ImageDraw.Draw(mask)
    draw_rounded_rect(mdraw, (0, 0, s, s), int(bg_r), fill=255)
    img.putalpha(mask)
    draw = ImageDraw.Draw(img)

    # ── Calendar body ────────────────────────────────────────────────────────
    # Positioned with some margin; slightly taller than wide
    m = s * 0.10           # outer margin
    cal_x0 = m
    cal_y0 = m + s * 0.05  # push down a bit to leave room for rings above
    cal_x1 = s - m
    cal_y1 = s - m
    cal_r = s * 0.07
    cal_w = cal_x1 - cal_x0
    cal_h = cal_y1 - cal_y0

    # Drop shadow
    shadow_offset = s * 0.025
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    draw_rounded_rect(
        sdraw,
        (cal_x0 + shadow_offset, cal_y0 + shadow_offset,
         cal_x1 + shadow_offset, cal_y1 + shadow_offset),
        cal_r,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=s * 0.025))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # White calendar body
    draw_rounded_rect(
        draw,
        (cal_x0, cal_y0, cal_x1, cal_y1),
        cal_r,
        fill=(255, 255, 255, 255),
    )

    # ── Red header ───────────────────────────────────────────────────────────
    header_h = cal_h * 0.28
    header_color = (234, 56, 44)   # Apple Calendar red
    header_color2 = (200, 30, 20)  # darker shade at bottom

    # Gradient header
    header_overlay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for y in range(int(header_h + cal_r)):
        t = min(y / header_h, 1.0)
        r = int(header_color[0] * (1-t) + header_color2[0] * t)
        g = int(header_color[1] * (1-t) + header_color2[1] * t)
        b = int(header_color[2] * (1-t) + header_color2[2] * t)
        header_overlay.paste(
            (r, g, b, 255),
            [int(cal_x0), int(cal_y0) + y, int(cal_x1), int(cal_y0) + y + 1],
        )

    # Clip header to rounded-top, flat-bottom shape using mask
    header_mask = Image.new("L", (s, s), 0)
    hmdraw = ImageDraw.Draw(header_mask)
    draw_rounded_rect(
        hmdraw,
        (cal_x0, cal_y0, cal_x1, cal_y0 + header_h + cal_r),
        cal_r,
        fill=255,
    )
    # Cut off the bottom-rounded part
    hmdraw.rectangle(
        [int(cal_x0), int(cal_y0 + header_h), int(cal_x1), int(cal_y0 + header_h + cal_r)],
        fill=255,
    )
    header_overlay.putalpha(header_mask)
    img = Image.alpha_composite(img, header_overlay)
    draw = ImageDraw.Draw(img)

    # Thin separator line between header and body
    sep_y = int(cal_y0 + header_h)
    draw.rectangle(
        [int(cal_x0), sep_y, int(cal_x1), sep_y + max(1, int(s * 0.004))],
        fill=(200, 30, 20, 180),
    )

    # ── Ring binders ─────────────────────────────────────────────────────────
    ring_r_outer = s * 0.055
    ring_r_inner = s * 0.032
    ring_y = cal_y0
    ring_positions = [
        cal_x0 + cal_w * 0.28,
        cal_x0 + cal_w * 0.72,
    ]

    for rx in ring_positions:
        # Ring shadow
        draw.ellipse(
            [rx - ring_r_outer + s*0.008, ring_y - ring_r_outer + s*0.008,
             rx + ring_r_outer + s*0.008, ring_y + ring_r_outer + s*0.008],
            fill=(0, 0, 0, 40),
        )
        # Outer ring (metallic grey)
        draw.ellipse(
            [rx - ring_r_outer, ring_y - ring_r_outer,
             rx + ring_r_outer, ring_y + ring_r_outer],
            fill=(180, 185, 195),
        )
        # Inner ring highlight
        draw.ellipse(
            [rx - ring_r_inner, ring_y - ring_r_inner,
             rx + ring_r_inner, ring_y + ring_r_inner],
            fill=(220, 225, 235),
        )
        # Center hole (background color)
        hole_r = ring_r_inner * 0.55
        draw.ellipse(
            [rx - hole_r, ring_y - hole_r, rx + hole_r, ring_y + hole_r],
            fill=(99, 160, 240, 200),
        )

    # ── Header text: day abbreviation ────────────────────────────────────────
    header_center_y = cal_y0 + header_h * 0.45

    # ── Schedule preview bars ────────────────────────────────────────────────
    body_top = cal_y0 + header_h
    body_h = cal_y1 - body_top

    bars_top = body_top + body_h * 0.07
    bars_bottom = cal_y1 - body_h * 0.07
    bars_left = cal_x0 + cal_w * 0.07
    bars_right = cal_x1 - cal_w * 0.07

    bars = [
        {"color": (255, 149,   0), "width_frac": 0.85},  # orange
        {"color": (52, 199,  89), "width_frac": 0.70},   # green
        {"color": (175,  82, 222), "width_frac": 0.90},  # purple
        {"color": (255,  59,  48), "width_frac": 0.60},  # red
    ]

    n = len(bars)
    bar_h = (bars_bottom - bars_top) / n * 0.68
    bar_gap = (bars_bottom - bars_top - n * bar_h) / (n + 1)
    bar_r = bar_h * 0.5

    for i, bar in enumerate(bars):
        by = bars_top + bar_gap * (i + 1) + bar_h * i
        bx1 = bars_left + (bars_right - bars_left) * bar["width_frac"]

        c = bar["color"]
        # Faint background track
        draw_rounded_rect(
            draw,
            (bars_left, by, bars_right, by + bar_h),
            bar_r,
            fill=(c[0], c[1], c[2], 40),
        )
        # Colored bar
        draw_rounded_rect(
            draw,
            (bars_left, by, bx1, by + bar_h),
            bar_r,
            fill=(c[0], c[1], c[2], 230),
        )
        # Highlight gleam
        gleam_h = bar_h * 0.35
        gleam_overlay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(gleam_overlay)
        draw_rounded_rect(
            gdraw,
            (bars_left, by, bx1, by + gleam_h),
            bar_r,
            fill=(255, 255, 255, 70),
        )
        img = Image.alpha_composite(img, gleam_overlay)
        draw = ImageDraw.Draw(img)

    # ── Downscale to requested size ──────────────────────────────────────────
    if render_size != size:
        img = img.resize((size, size), Image.LANCZOS)

    return img


os.makedirs(ICON_DIR, exist_ok=True)

for filename, size in SIZES:
    icon = create_icon(size)
    path = os.path.join(ICON_DIR, filename)
    icon.save(path, "PNG")
    print(f"Generated {path} ({size}x{size})")

print("\nAll icons generated successfully!")
