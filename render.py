"""Render the standalone welcome and portal preview."""

import json
import os
import re
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SPEC = json.loads((ROOT / 'portal.json').read_text(encoding='utf-8'))
WIDTH, HEIGHT, FPS = 1600, 1016, 30
PIXELS = WIDTH / SPEC['width']
CENTER = np.array(SPEC['center'])
MOTION = np.array(SPEC['motion'])

# The endpoints join directly, including the light upstroke into the J.
WRITING = [
    (.13, 'M 69,123'),
    (.79, """
        C 70,118 77,114 78,121 C 79,125 74,136 79,136
        C 84,136 88,125 88,119 C 89,127 87,136 93,135
        C 98,133 101,124 100,118 C 98,124 103,130 111,128
    """),
    (1.19, """
        C 119,127 122,120 118,117 C 114,114 109,121 111,129
        C 113,139 124,137 131,126
    """),
    (1.58, """
        C 137,117 142,102 136,101 C 130,99 124,119 127,129
        C 130,140 140,138 146,125
    """),
    (1.99, """
        C 150,117 155,116 158,119 C 152,114 146,121 145,129
        C 145,139 158,138 163,126
    """),
    (2.43, """
        C 168,113 180,116 178,127 C 176,137 167,141 163,133
        C 160,128 166,118 171,118 C 176,118 179,127 185,126
        C 189,125 191,122 193,118
    """),
    (2.90, """
        C 192,125 190,131 190,135 C 193,123 197,116 202,117
        C 207,118 205,128 203,134 C 206,125 210,116 215,118
        C 222,120 210,135 218,135
    """),
    (3.26, """
        C 227,134 235,123 230,118 C 226,114 221,124 222,130
        C 223,138 233,137 238,132
    """),
    (3.41, 'C 242,127 239,115 247,112'),
    (4.06, """
        C 253,107 271,100 271,111 C 271,121 264,133 255,140
        C 247,147 240,144 245,138 C 250,132 259,138 268,133
        C 272,131 275,126 278,123
    """),
    (4.50, """
        C 283,117 293,118 289,124 C 285,131 277,135 273,133
        C 268,130 278,118 284,119 C 288,118 289,120 291,120
        C 289,126 281,136 288,136 C 292,135 296,130 298,127
    """),
    (4.98, """
        C 302,120 305,118 303,123 C 300,129 295,135 300,136
        C 305,137 312,126 316,121 C 311,131 304,150 296,153
        C 287,157 288,148 295,144 C 302,140 310,139 318,132
    """),
]

SLIDE = 190
PORTAL_PATH = SPEC['outline']
TAIL = 'C 333,124 343,147 355,139 C 362,134 364,126 365,120'
INK_COLORS = [
    '#ff608b', '#ff8b70', '#ffc368', '#dfe777', '#87df9e', '#70d9e9',
    '#84b5ff', '#bb91f7', '#f782c4', '#ff89a5', '#ffc775',
]
INK_X = [69, 101, 135, 158, 190, 226, 251, 275, 312, 344, 365]
CLOUD_COLORS = ['#ffca6d', '#bfe69a', '#73dbe3', '#b692f7', '#d19af9',
                '#7ddde9', '#bce59e', '#ffca6d', '#ffca6d']


def rgb(hex_color):
    return tuple(bytes.fromhex(hex_color.removeprefix('#')))


def bezier(start, data):
    coords = np.array(re.findall(r'-?[\d.]+', data), dtype=float).reshape(-1, 2)
    if start is None:
        start, coords = coords[0], coords[1:]
    points = [np.asarray(start, dtype=float)]
    for a, b, end in coords.reshape(-1, 3, 2):
        p = points[-1]
        t = np.linspace(0, 1, 65)[1:, None]
        u = 1-t
        points.extend(u**3*p + 3*u*u*t*a + 3*u*t*t*b + t**3*end)
    return np.array(points)


def arc_lengths(points):
    return np.r_[0, np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1))]


def gradient(position, stops, colors):
    palette = np.array([rgb(color) for color in colors])
    return np.column_stack([np.interp(position, stops, channel) for channel in palette.T])


def smooth(u):
    value = np.clip(u, 0, 1)
    return value * value * (3-2*value)


def sample_path(points, spacing=.65):
    lengths = arc_lengths(points)
    steps = np.r_[np.arange(0, lengths[-1], spacing), lengths[-1]]
    xy = np.column_stack([np.interp(steps, lengths, axis) for axis in points.T])
    return xy, lengths, steps


chunks = []
ends = []
tip = None
for time, command in WRITING:
    curve = bezier(tip, command)
    chunks.append(curve if tip is None else curve[1:])
    ends.append(sum(map(len, chunks))-1)
    tip = curve[-1]
lettering = np.concatenate(chunks)
outline = bezier(None, PORTAL_PATH)
shape = outline + CENTER
tail = bezier(lettering[-1], TAIL)
assert np.allclose(tail[-1], shape[0] + [SLIDE, 0])
path = np.concatenate((lettering, tail[1:], shape[1:] + [SLIDE, 0]))
track, distances, steps = sample_path(path)
word_end = distances[len(lettering)-1]
tail_end = distances[len(lettering)+len(tail)-2]
speed_times = [0] + [time for time, _ in WRITING] + [5.80, 6.55, SPEC['duration']]
speed_distances = [0] + list(distances[ends]) + [tail_end, distances[-1], distances[-1]]
gap_start, gap_end = distances[ends[7]], distances[ends[8]]
colors = gradient(track[:, 0], INK_X, INK_COLORS)
cloud_track, cloud_lengths, cloud_steps = sample_path(outline)
cloud_stops = cloud_lengths[np.arange(0, len(outline), 64)]
cloud_palette = gradient(cloud_steps, cloud_stops, CLOUD_COLORS)
cloud_segment = steps >= tail_end
colors[cloud_segment] = gradient(steps[cloud_segment]-tail_end, cloud_stops, CLOUD_COLORS)


def make_background():
    x, y = np.meshgrid(np.linspace(0, 1, WIDTH), np.linspace(0, 1, HEIGHT))
    base = np.array(rgb(SPEC['background']))
    violet = np.exp(-((x-.19)**2/.09 + (y-.48)**2/.37))
    blue = np.exp(-((x-.81)**2/.09 + (y-.66)**2/.13))
    shade = np.exp(-((x-.53)**2/.34 + (y-.85)**2/.52))
    image = base + violet[..., None]*[4, 1, 5] + blue[..., None]*[0, 3, 6] - shade[..., None]*[2, 2, 3]
    dither = np.random.default_rng(18).normal(0, .75, (HEIGHT, WIDTH, 1))
    return Image.fromarray(np.uint8(np.clip(image+dither+.5, 0, 255))).convert('RGBA')


BACKGROUND = make_background()


def stroke(draw, xy, palette, weights, opacity, thickness):
    for index, (a, b) in enumerate(zip(xy, xy[1:])):
        alpha = opacity[index]
        if alpha < .01:
            continue
        radius = thickness * weights[index]/2
        if (max(a[0], b[0])+radius < 0 or min(a[0], b[0])-radius >= WIDTH
                or max(a[1], b[1])+radius < 0 or min(a[1], b[1])-radius >= HEIGHT):
            continue
        color = (*map(int, palette[index]), round(255*alpha))
        draw.line([tuple(a), tuple(b)], fill=color, width=max(1, round(radius*2)))
        draw.ellipse((a[0]-radius, a[1]-radius, a[0]+radius, a[1]+radius), fill=color)
        if index == len(xy)-2:
            draw.ellipse((b[0]-radius, b[1]-radius, b[0]+radius, b[1]+radius), fill=color)


def prompt(draw, time):
    opacity = 1-smooth((time-7.16)/.24)
    if time <= 6.56 or opacity <= 0:
        return
    # The neutral terminal strokes are secondary to the continuous rainbow trace.
    glyphs = [
        (6.56, 6.79, [(-11, -8), (-6, 0), (-11, 8)]),
        (6.79, 6.94, [(3, 8), (14, 8)]),
    ]
    for start, finish, glyph in glyphs:
        if time <= start:
            continue
        points = np.array(glyph)
        lengths = arc_lengths(points)
        shown = np.linspace(0, lengths[-1]*min(1, (time-start)/(finish-start)), 46)
        xy = np.column_stack([np.interp(shown, lengths, axis) for axis in points.T])
        fill = (242, 245, 250, round(245*opacity))
        draw.line([tuple(p) for p in (xy+CENTER)*PIXELS], fill=fill, width=round(2.35*PIXELS), joint='curve')
        for x, y in (xy[[0, -1]]+CENTER)*PIXELS:
            r = 1.14*PIXELS
            draw.ellipse((x-r, y-r, x+r, y+r), fill=fill)


def render(time, portal_preview=True):
    frame = BACKGROUND.copy()
    art = Image.new('RGBA', frame.size)
    draw = ImageDraw.Draw(art)
    if time < MOTION[0, 0]:
        head = np.interp(time, speed_times, speed_distances)
        count = np.searchsorted(steps, head)
        if count and head > 0:
            positions = steps[:count]
            head_xy = [np.interp(head, distances, axis) for axis in path.T]
            xy = np.vstack((track[:count], head_xy))
            xy[:, 0] -= SLIDE * smooth((time-5.01)/.91)
            # The tail erases behind the head as the stroke moves into the cloud.
            exit_at = np.interp(positions, [0, word_end, tail_end, distances[-1]],
                                [5.03, 5.62, 6.08, 12])
            opacity = 1-smooth((time-exit_at)/.38)
            is_outline = positions >= tail_end
            opacity[is_outline] = 1
            gap = (positions > gap_start) & (positions < gap_end)
            weights = np.ones(count)
            weights[gap] -= .74*np.sin(np.pi*(positions[gap]-gap_start)/(gap_end-gap_start))**.7
            opacity[gap] *= .7
            stroke(draw, xy*PIXELS, colors[:count], weights, opacity, 2.62*PIXELS)
        prompt(draw, time)
    else:
        ring, opening = [np.interp(time, MOTION[:, 0], col) for col in MOTION[:, 1:].T]
        echo = smooth((time-7.20)/.24) * (1-smooth((time-7.59)/.29))
        for factor, opacity in [(1.34, 48), (1.67, 35), (2.05, 20)]:
            xy = (outline*(ring*factor) + CENTER)*PIXELS
            draw.line([tuple(point) for point in xy], fill=(171, 170, 199, round(opacity*echo)),
                      width=max(1, round(1.35*PIXELS)), joint='curve')
        stroke(draw, (cloud_track*ring+CENTER)*PIXELS, cloud_palette, np.ones(len(cloud_track)),
               np.ones(len(cloud_track)), (2.62+.38*(ring-1))*PIXELS)
        prompt(draw, time)
        if portal_preview and opening > 0:
            # The live overlay cuts through to the real app at these same coordinates.
            xy = (outline*opening+CENTER)*PIXELS
            draw.polygon([tuple(point) for point in xy], fill=(249, 249, 251, 255))
    frame.alpha_composite(art)
    return frame.convert('RGB')


def video_writer(path):
    return imageio_ffmpeg.write_frames(
        str(path), (WIDTH, HEIGHT), fps=FPS, codec='libx264', quality=8, macro_block_size=1,
        output_params=['-movflags', '+faststart', '-vf', 'scale=out_color_matrix=bt709', '-color_primaries', 'bt709',
                       '-color_trc', 'bt709', '-colorspace', 'bt709'],
    )


if __name__ == '__main__':
    preview_file = ROOT / '.Welcome Jay.render.mp4'
    overlay_file = ROOT / '.Welcome Jay.overlay.render.mp4'
    preview = video_writer(preview_file)
    overlay = video_writer(overlay_file)
    preview.send(None)
    overlay.send(None)
    try:
        for frame in range(round(SPEC['duration']*FPS)):
            time = frame/FPS
            pixels = render(time).tobytes()
            preview.send(pixels)
            overlay.send(pixels if time < MOTION[0, 0] else render(time, portal_preview=False).tobytes())
    finally:
        preview.close()
        overlay.close()
    os.replace(preview_file, ROOT / 'Welcome Jay.mp4')
    os.replace(overlay_file, ROOT / '.Welcome Jay.overlay.mp4')
