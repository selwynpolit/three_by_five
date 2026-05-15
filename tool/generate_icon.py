#!/usr/bin/env python3
"""
Generates the 3by5 app icon — a landscape index card on a green background.
Writes PNGs directly to macos/Runner/Assets.xcassets/AppIcon.appiconset/.
Requires only Python stdlib (no PIL/numpy).
"""

import struct, zlib, math, os

# ── Colours (RGBA tuples) ────────────────────────────────────────────────────

BG      = (44,  94,  62,  255)   # deep green background
CARD    = (255, 253, 245, 255)   # warm cream card
STRIPE  = (29,  68,  44,  255)   # dark-green top stripe
LINE    = (172, 208, 220, 255)   # blue ruled lines
SHADOW  = (0,   0,   0         )  # shadow (no alpha; blended separately)

# ── PNG helpers ───────────────────────────────────────────────────────────────

def _png_chunk(tag: bytes, data: bytes) -> bytes:
    buf  = tag + data
    crc  = zlib.crc32(buf) & 0xFFFF_FFFF
    return struct.pack('>I', len(data)) + buf + struct.pack('>I', crc)

def write_png(path: str, width: int, height: int, pixels: bytearray) -> None:
    """pixels: flat RGBA bytearray, row-major."""
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)                          # filter: None
        raw += pixels[y * stride:(y + 1) * stride]

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png  = (b'\x89PNG\r\n\x1a\n'
            + _png_chunk(b'IHDR', ihdr)
            + _png_chunk(b'IDAT', zlib.compress(bytes(raw), 9))
            + _png_chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)
    print(f'  wrote {path}  ({width}×{height})')

# ── Pixel helpers ─────────────────────────────────────────────────────────────

def _set(pixels: bytearray, width: int, x: int, y: int, c) -> None:
    if 0 <= x < width and 0 <= y < (len(pixels) // (width * 4)):
        o = (y * width + x) * 4
        pixels[o], pixels[o+1], pixels[o+2], pixels[o+3] = c[0], c[1], c[2], c[3]

def _blend_shadow(pixels: bytearray, width: int, x: int, y: int, alpha: float) -> None:
    """Darken the existing pixel by alpha."""
    height = len(pixels) // (width * 4)
    if 0 <= x < width and 0 <= y < height:
        o = (y * width + x) * 4
        for i in range(3):
            pixels[o+i] = int(pixels[o+i] * (1 - alpha))

def _fill_rect(pixels: bytearray, width: int,
               rx: int, ry: int, rw: int, rh: int, c) -> None:
    height = len(pixels) // (width * 4)
    for y in range(max(0, ry), min(height, ry + rh)):
        o = (y * width + max(0, rx)) * 4
        xe = min(width, rx + rw)
        for x in range(max(0, rx), xe):
            pixels[o], pixels[o+1], pixels[o+2], pixels[o+3] = c[0], c[1], c[2], c[3]
            o += 4

def _fill_rrect(pixels: bytearray, width: int,
                rx: int, ry: int, rw: int, rh: int, r: int, c,
                clip_top: int = None, clip_bottom: int = None) -> None:
    """Fill rounded rectangle. Optional clip_top / clip_bottom in absolute y."""
    height = len(pixels) // (width * 4)
    y0 = max(0, ry) if clip_top is None else max(0, ry, clip_top)
    y1 = min(height, ry + rh) if clip_bottom is None else min(height, ry + rh, clip_bottom)
    for y in range(y0, y1):
        dy_top    = (ry + r) - y
        dy_bottom = y - (ry + rh - r - 1)
        if dy_top > 0:                          # inside top-corner band
            dx = int(math.sqrt(max(0, r*r - dy_top*dy_top)))
            x_left  = rx + r - dx
            x_right = rx + rw - r + dx
        elif dy_bottom > 0:                     # inside bottom-corner band
            dx = int(math.sqrt(max(0, r*r - dy_bottom*dy_bottom)))
            x_left  = rx + r - dx
            x_right = rx + rw - r + dx
        else:
            x_left  = rx
            x_right = rx + rw
        xs = max(0, x_left)
        xe = min(width, x_right)
        o  = (y * width + xs) * 4
        for x in range(xs, xe):
            pixels[o], pixels[o+1], pixels[o+2], pixels[o+3] = c[0], c[1], c[2], c[3]
            o += 4

def _shadow_rrect(pixels: bytearray, width: int,
                  rx: int, ry: int, rw: int, rh: int, r: int, alpha: float) -> None:
    height = len(pixels) // (width * 4)
    for y in range(max(0, ry), min(height, ry + rh)):
        dy_top    = (ry + r) - y
        dy_bottom = y - (ry + rh - r - 1)
        if dy_top > 0:
            dx = int(math.sqrt(max(0, r*r - dy_top*dy_top)))
            x_left  = rx + r - dx
            x_right = rx + rw - r + dx
        elif dy_bottom > 0:
            dx = int(math.sqrt(max(0, r*r - dy_bottom*dy_bottom)))
            x_left  = rx + r - dx
            x_right = rx + rw - r + dx
        else:
            x_left  = rx
            x_right = rx + rw
        xs = max(0, x_left)
        xe = min(width, x_right)
        o  = (y * width + xs) * 4
        for x in range(xs, xe):
            for i in range(3):
                pixels[o+i] = int(pixels[o+i] * (1 - alpha))
            o += 4

# ── Icon renderer ─────────────────────────────────────────────────────────────

def render_icon(size: int) -> bytearray:
    """
    Renders the icon at [size]×[size].
    Design: green rounded-square BG, landscape index card (5:3 aspect),
    dark-green top stripe, 4 blue ruled lines.
    """
    s = size / 512.0
    pixels = bytearray(size * size * 4)  # all transparent

    # ── Background rounded square ────────────────────────────────────────────
    bg_r = max(2, int(60 * s))
    _fill_rrect(pixels, size, 0, 0, size, size, bg_r, BG)

    # ── Shadow card (slightly offset behind main card) ────────────────────────
    cw = int(360 * s)
    ch = int(216 * s)           # 5:3 landscape ratio
    cx = (size - cw) // 2
    cy = (size - ch) // 2
    cr = max(2, int(14 * s))    # card corner radius
    sh = max(1, int(7 * s))     # shadow offset

    _shadow_rrect(pixels, size, cx + sh, cy + sh, cw, ch, cr, 0.35)

    # ── Card body ────────────────────────────────────────────────────────────
    _fill_rrect(pixels, size, cx, cy, cw, ch, cr, CARD)

    # ── Top stripe ────────────────────────────────────────────────────────────
    stripe_h = max(2, int(30 * s))
    # Clipped to card top (rounded top corners handled by drawing CARD first
    # then overwriting the stripe zone which is away from round corners at
    # all realistic sizes)
    _fill_rect(pixels, size, cx + cr, cy, cw - 2 * cr, stripe_h, STRIPE)
    # Fill the non-corner parts of the very top rows properly
    _fill_rrect(pixels, size, cx, cy, cw, ch, cr, STRIPE,
                clip_bottom=cy + stripe_h)

    # ── Ruled lines ───────────────────────────────────────────────────────────
    line_h   = max(1, int(1.5 * s))
    line_gap = max(4, int(28 * s))
    y_start  = cy + stripe_h + line_gap
    line_margin = max(1, int(16 * s))
    y = y_start
    while y + line_h < cy + ch - max(4, int(10 * s)):
        _fill_rect(pixels, size,
                   cx + line_margin, y,
                   cw - 2 * line_margin, line_h,
                   LINE)
        y += line_gap + line_h

    return pixels


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    out_dir = os.path.join(
        os.path.dirname(__file__),
        '..', 'macos', 'Runner', 'Assets.xcassets',
        'AppIcon.appiconset'
    )
    out_dir = os.path.normpath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    names = {
        16:   'app_icon_16.png',
        32:   'app_icon_32.png',
        64:   'app_icon_64.png',
        128:  'app_icon_128.png',
        256:  'app_icon_256.png',
        512:  'app_icon_512.png',
        1024: 'app_icon_1024.png',
    }

    print('Generating 3by5 app icons…')
    for size in sizes:
        pixels = render_icon(size)
        write_png(os.path.join(out_dir, names[size]), size, size, pixels)

    print('Done.')

if __name__ == '__main__':
    main()
