"""Renders the Party Games logo with Pillow (4x supersampled) into PNG files."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 2            # supersample factor
W = 1024 * S     # canvas size at supersample


def P(x, y):
    return (x * S, y * S)


def cubic(p0, p1, p2, p3, n=40):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def path(cmds):
    """cmds: ('M',x,y) ('L',x,y) ('C',x1,y1,x2,y2,x,y) in 1024 units -> list of supersampled points."""
    pts, cur = [], None
    for c in cmds:
        if c[0] in 'ML':
            cur = (c[1], c[2]); pts.append(cur)
        else:
            _, x1, y1, x2, y2, x, y = c
            pts += cubic(cur, (x1, y1), (x2, y2), (x, y)); cur = (x, y)
    return [P(x, y) for x, y in pts]


def mask_poly(pts):
    m = Image.new('L', (W, W), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def rgba(hexs, a=255):
    h = hexs.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def solid(color):
    return Image.new('RGBA', (W, W), rgba(color) if isinstance(color, str) else color)


def lin_grad(stops, angle_deg):
    """stops: [(t, '#hex')], angle: 0 = left->right, 90 = top->bottom, 45 = TL->BR."""
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32) / W
    a = math.radians(angle_deg)
    t = xx * math.cos(a) + yy * math.sin(a)
    t = (t - t.min()) / (t.max() - t.min())
    out = np.zeros((W, W, 4), np.float32)
    ts = [s[0] for s in stops]; cs = [np.array(rgba(s[1]), np.float32) for s in stops]
    for ch in range(4):
        out[..., ch] = np.interp(t, ts, [c[ch] for c in cs])
    return Image.fromarray(out.astype(np.uint8), 'RGBA')


def grad_box(stops, box, vertical=True):
    """Vertical gradient defined over a y-range (box=(y0,y1) in 1024 units)."""
    y0, y1 = box[0] * S, box[1] * S
    yy = np.mgrid[0:W, 0:1][0].astype(np.float32)
    t = np.clip((yy - y0) / (y1 - y0), 0, 1)
    col = np.zeros((W, 1, 4), np.float32)
    ts = [s[0] for s in stops]; cs = [np.array(rgba(s[1]), np.float32) for s in stops]
    for ch in range(4):
        col[..., ch] = np.interp(t, ts, [c[ch] for c in cs])
    return Image.fromarray(np.repeat(col, W, axis=1).astype(np.uint8), 'RGBA')


def radial(cx, cy, r, color, alpha):
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    d = np.sqrt((xx - cx * S) ** 2 + (yy - cy * S) ** 2) / (r * S)
    a = np.clip(1 - d, 0, 1) ** 1.6 * alpha
    c = rgba(color)
    img = np.zeros((W, W, 4), np.float32)
    img[..., 0], img[..., 1], img[..., 2] = c[0], c[1], c[2]
    img[..., 3] = a * 255
    return Image.fromarray(img.astype(np.uint8), 'RGBA')


def paint(base, fill, mask):
    """Composite fill (RGBA image) onto base through mask (L)."""
    layer = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    layer.paste(fill, (0, 0), mask)
    # respect fill's own alpha too
    if fill.mode == 'RGBA':
        fa = fill.getchannel('A')
        m = Image.fromarray((np.asarray(mask, np.float32) * np.asarray(fa, np.float32) / 255).astype(np.uint8))
        layer = Image.new('RGBA', (W, W), (0, 0, 0, 0)); layer.paste(fill.convert('RGB'), (0, 0), m)
        layer.putalpha(m)
    base.alpha_composite(layer)


def dilate(mask, px):
    """Fast approximate dilation: blur, then threshold low."""
    r = max(1, px * S)
    b = mask.filter(ImageFilter.GaussianBlur(r / 2))
    a = np.asarray(b, np.float32)
    out = np.clip((a - 8) * 6, 0, 255)
    return Image.fromarray(np.maximum(out, np.asarray(mask, np.float32)).astype(np.uint8))


def AND(a, b):
    return Image.fromarray(np.minimum(np.asarray(a), np.asarray(b)))


def shift(mask, dx, dy):
    out = Image.new('L', (W, W), 0); out.paste(mask, (dx * S, dy * S)); return out


INK = '#120C3A'


def art(base, scale=1.0):
    """Draw confetti, controller, bolt, sparkle onto base. scale shrinks around the centre."""
    def T(pts):
        c = W / 2
        return [((x - c) * scale + c, (y - c) * scale + c) for x, y in pts]

    def poly(pts):
        return mask_poly(T(pts))

    # confetti
    conf = [
        ('rect', 236, 286, 34, 16, -28, '#FFC93C'), ('rect', 792, 270, 30, 15, 24, '#FF5C8A'),
        ('circ', 872, 420, 13, 0, 0, '#2ECC71'), ('circ', 150, 420, 11, 0, 0, '#FFFFFF'),
        ('rect', 376, 214, 26, 13, 40, '#2E8BFF'), ('rect', 660, 210, 24, 12, -36, '#B07CFF'),
        ('circ', 512, 208, 9, 0, 0, '#FFC93C'), ('rect', 150, 740, 28, 14, 30, '#FF8A1F'),
        ('rect', 868, 746, 28, 14, -30, '#2E8BFF'),
    ]
    for kind, x, y, w, h, rot, col in conf:
        if kind == 'circ':
            pts = [P(x + w * math.cos(t), y + w * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 48)]
        else:
            a = math.radians(rot)
            corners = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
            pts = [P(x + cx * math.cos(a) - cy * math.sin(a), y + cx * math.sin(a) + cy * math.cos(a)) for cx, cy in corners]
        paint(base, solid(col), poly(pts))

    # controller body
    body_cmds = [
        ('M', 330, 430), ('L', 694, 430),
        ('C', 790, 430, 842, 474, 864, 562), ('L', 902, 716),
        ('C', 918, 790, 858, 834, 802, 802), ('C', 758, 778, 730, 724, 690, 694),
        ('L', 334, 694),
        ('C', 294, 724, 266, 778, 222, 802), ('C', 166, 834, 106, 790, 122, 716),
        ('L', 160, 562), ('C', 182, 474, 234, 430, 330, 430),
    ]
    body = poly(path(body_cmds))
    # drop shadow
    sh = shift(body, 0, 26).filter(ImageFilter.GaussianBlur(14 * S))
    paint(base, solid((5, 4, 25, 150)), sh)
    # outline
    paint(base, solid(INK), dilate(body, int(20 * scale) or 1))
    # halves
    left_m = mask_poly(T([P(0, 0), P(512, 0), P(512, 1024), P(0, 1024)]))
    right_m = mask_poly(T([P(512, 0), P(1024, 0), P(1024, 1024), P(512, 1024)]))
    blue = grad_box([(0, '#6CB4FF'), (0.45, '#2E8BFF'), (1, '#1659C9')], (512 - (512 - 430) * scale, 512 + (834 - 512) * scale))
    orng = grad_box([(0, '#FFB866'), (0.45, '#FF8A1F'), (1, '#D9600A')], (512 - (512 - 430) * scale, 512 + (834 - 512) * scale))
    paint(base, blue, AND(body, left_m))
    paint(base, orng, AND(body, right_m))
    # top highlight band
    hl = poly(path([('M', 300, 452), ('L', 724, 452), ('C', 790, 452, 826, 480, 840, 530), ('L', 184, 530), ('C', 198, 480, 234, 452, 300, 452)]))
    paint(base, solid((255, 255, 255, 34)), AND(hl, body))

    # d-pad (left)
    def plus(cx, cy, arm, w):
        return [P(cx - w, cy - arm), P(cx + w, cy - arm), P(cx + w, cy - w), P(cx + arm, cy - w), P(cx + arm, cy + w), P(cx + w, cy + w),
                P(cx + w, cy + arm), P(cx - w, cy + arm), P(cx - w, cy + w), P(cx - arm, cy + w), P(cx - arm, cy - w), P(cx - w, cy - w)]
    paint(base, solid('#0E3C8A'), poly(plus(330, 570, 66, 24)))
    paint(base, solid('#FFFFFF'), poly(plus(330, 562, 66, 24)))

    # buttons (right) as the four player shapes
    def circle(cx, cy, r):
        return [P(cx + r * math.cos(t), cy + r * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 64)]
    shapes = [
        circle(694, 500, 23),
        [P(756, 562 - 28), P(756 + 28, 562), P(756, 562 + 28), P(756 - 28, 562)],
        [P(694, 598), P(694 + 27, 642), P(694 - 27, 642)],
        [P(611, 541), P(653, 541), P(653, 583), P(611, 583)],
    ]
    for pts in shapes:
        paint(base, solid('#9A4100'), poly([(x, y + 8 * S) for x, y in pts]))
        paint(base, solid('#FFFFFF'), poly(pts))

    # lightning bolt over the seam
    bolt_pts = [P(520, 360), P(596, 360), P(540, 526), P(604, 526), P(474, 806), P(506, 596), P(436, 596)]
    bolt = poly(bolt_pts)
    paint(base, solid(INK), dilate(bolt, int(16 * scale) or 1))
    paint(base, grad_box([(0, '#FFE58A'), (0.5, '#FFC93C'), (1, '#F0A500')], (512 - 152 * scale, 512 + 294 * scale)), bolt)
    paint(base, solid((255, 246, 200, 170)), poly([P(530, 376), P(566, 376), P(520, 512), P(504, 512)]))

    # sparkle
    def star4(cx, cy, r, ri):
        pts = []
        for i in range(8):
            ang = -math.pi / 2 + i * math.pi / 4
            rr = r if i % 2 == 0 else ri
            pts.append(P(cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
        return pts
    paint(base, solid('#FFF4C2'), poly(star4(842, 330, 40, 9)))
    paint(base, solid('#FFFFFF'), poly(star4(196, 610, 22, 5)))


def background(base, mask):
    bg = lin_grad([(0, '#4A35C2'), (0.45, '#241A7A'), (1, '#0B0E2E')], 50)
    paint(base, bg, mask)
    for g in [radial(512, 560, 470, '#FF4FA3', 0.30), radial(110, 980, 520, '#2E8BFF', 0.35), radial(960, 40, 420, '#FFC93C', 0.20)]:
        paint(base, g, mask)
    # sunburst
    c = (512, 560)
    for i in range(16):
        a0 = i * 2 * math.pi / 16; a1 = a0 + math.pi / 16
        ray = mask_poly([P(*c), P(c[0] + 900 * math.cos(a0), c[1] + 900 * math.sin(a0)), P(c[0] + 900 * math.cos(a1), c[1] + 900 * math.sin(a1))])
        paint(base, solid((255, 255, 255, 12)), AND(ray, mask))


def rounded_mask(r=225):
    m = Image.new('L', (W, W), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, W - 1], radius=r * S, fill=255)
    return m


def make(rounded=True, scale=1.0, transparent_bg=False):
    base = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    tile = rounded_mask() if rounded else Image.new('L', (W, W), 255)
    if not transparent_bg:
        background(base, tile)
    art(base, scale)
    if rounded:
        # clip everything to the tile and add a soft inner edge
        a = np.minimum(np.asarray(base.getchannel('A')), np.asarray(tile))
        base.putalpha(Image.fromarray(a))
        edge = Image.fromarray(np.clip(np.asarray(tile, np.int16) - np.asarray(tile.filter(ImageFilter.MinFilter(13)), np.int16), 0, 255).astype(np.uint8))
        paint(base, solid((255, 255, 255, 40)), edge)
    return base.resize((1024, 1024), Image.LANCZOS)


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    icon = make(rounded=True)
    icon.save(f'{out}/icon_1024.png')
    full = make(rounded=False)
    full.save(f'{out}/playstore_512_src.png')
    full.resize((512, 512), Image.LANCZOS).save(f'{out}/playstore_512.png')
    fg = make(rounded=False, scale=0.70)
    fg.save(f'{out}/foreground_1024.png')
    print('done')
