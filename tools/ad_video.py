#!/usr/bin/env python3
"""Cuts the recorded gameplay into a 9:16 motion-graphics video ad.

1. Render the cast:   tools/godot/ad_portraits.tscn   -> <work>/portraits/*.png
2. Record gameplay:   tools/godot/ad_capture.tscn     -> <work>/capture.avi + shots.json
3. Compose:           python3 tools/ad_video.py <work> <out.mp4>

Needs Pillow, numpy and an ffmpeg with libx264 (`pip install imageio-ffmpeg`
provides one). See docs/marketing/README.md for the full commands.
"""
from __future__ import annotations

import json
import math
import random
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT_BOLD = str(ROOT / "assets/fonts/Fredoka-SemiBold.ttf")
FONT_BODY = str(ROOT / "assets/fonts/Fredoka-Medium.ttf")
AUDIO = ROOT / "assets/audio"

W, H, FPS = 1080, 1920, 30
RATE = 44100

INK = (74, 53, 48)
INK_SOFT = (107, 80, 72)
CREAM = (255, 246, 236)
PEACH = (250, 215, 192)
PEACH_LIGHT = (253, 230, 216)
TOMATO = (201, 79, 69)
STRAWBERRY = (244, 143, 160)
MINT = (158, 217, 184)
MINT_LIGHT = (228, 245, 236)
BUTTER = (255, 214, 107)
LAVENDER = (198, 180, 232)
SKY = (156, 203, 235)
WHITE = (255, 255, 255)


# -- easing -------------------------------------------------------------------------

def clamp(x: float, a: float = 0.0, b: float = 1.0) -> float:
    return max(a, min(b, x))


def ease_out_back(t: float, s: float = 1.9) -> float:
    t = clamp(t) - 1.0
    return 1.0 + t * t * ((s + 1.0) * t + s)


def ease_out_cubic(t: float) -> float:
    return 1.0 - (1.0 - clamp(t)) ** 3


def ease_in_out(t: float) -> float:
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def pop(t: float, start: float, dur: float = 0.45) -> float:
    """0 before `start`, then an overshooting 0 -> 1."""
    return 0.0 if t < start else ease_out_back((t - start) / dur)


# -- drawing helpers ----------------------------------------------------------------

_fonts: dict = {}


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    key = (size, bold)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(FONT_BOLD if bold else FONT_BODY, size)
    return _fonts[key]


def text_image(text: str, size: int, fill=INK, stroke: int = 0, stroke_fill=WHITE, bold: bool = True) -> Image.Image:
    f = font(size, bold)
    box = f.getbbox(text, stroke_width=stroke)
    img = Image.new("RGBA", (box[2] - box[0] + 8, box[3] - box[1] + 8), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((4 - box[0], 4 - box[1]), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
    return img


def shadowed(img: Image.Image, radius: int = 14, offset=(0, 10), alpha: int = 70) -> Image.Image:
    pad = radius * 2 + max(abs(offset[0]), abs(offset[1]))
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    sh = Image.new("RGBA", out.size, (0, 0, 0, 0))
    a = img.getchannel("A").point(lambda v: v * alpha // 255)
    tint = Image.new("RGBA", img.size, INK + (0,))
    tint.putalpha(a)
    sh.paste(tint, (pad + offset[0], pad + offset[1]))
    sh = sh.filter(ImageFilter.GaussianBlur(radius))
    out.alpha_composite(sh)
    out.alpha_composite(img, (pad, pad))
    return out


def pill(text: str, size: int = 78, fg=INK, bg=WHITE, pad_x: int = 54, pad_y: int = 26, accent=None) -> Image.Image:
    t = text_image(text, size, fg)
    w, h = t.width + pad_x * 2, t.height + pad_y * 2
    img = Image.new("RGBA", (w, h + 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if accent:
        d.rounded_rectangle((0, 12, w - 1, h + 11), radius=h // 2, fill=accent)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2, fill=bg)
    img.alpha_composite(t, (pad_x, pad_y))
    return shadowed(img)


def place(canvas: Image.Image, img: Image.Image, center, scale: float = 1.0, alpha: float = 1.0, angle: float = 0.0) -> None:
    """Pastes `img` centred at `center`, scaled, faded and rotated."""
    if scale <= 0.01 or alpha <= 0.01:
        return
    if abs(scale - 1.0) > 0.002:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.BILINEAR)
    if abs(angle) > 0.05:
        img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
    if alpha < 0.999:
        img = img.copy()
        img.putalpha(img.getchannel("A").point(lambda v: int(v * alpha)))
    x, y = round(center[0] - img.width / 2), round(center[1] - img.height / 2)
    canvas.alpha_composite(img, (x, y)) if x >= 0 and y >= 0 and x + img.width <= W and y + img.height <= H else _paste_clipped(canvas, img, x, y)


def _paste_clipped(canvas: Image.Image, img: Image.Image, x: int, y: int) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(img, (x, y), img)
    canvas.alpha_composite(layer)


def gradient(top, bottom) -> Image.Image:
    a = np.linspace(0.0, 1.0, H)[:, None, None]
    arr = (np.array(top)[None, None, :] * (1 - a) + np.array(bottom)[None, None, :] * a)
    arr = np.repeat(arr, W, axis=1).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def dots_layer(t: float, colors, seed: int) -> Image.Image:
    """Soft drifting circles for the graphic scenes."""
    rnd = random.Random(seed)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(14):
        r = rnd.uniform(40, 150)
        x = rnd.uniform(-50, W + 50) + math.sin(t * 0.8 + i) * 30
        y = (rnd.uniform(0, H) - t * rnd.uniform(30, 80)) % (H + 300) - 150
        c = rnd.choice(colors)
        d.ellipse((x - r, y - r, x + r, y + r), fill=c + (120,))
    return layer


# -- the ad --------------------------------------------------------------------------

class Ad:
    def __init__(self, work: Path):
        self.work = work
        meta = json.loads((work / "shots.json").read_text())
        self.shots = meta["shots"]
        self.frames_dir = work / "frames"
        self.portraits = {p.stem: Image.open(p).convert("RGBA") for p in (work / "portraits").glob("*.png")}
        icon = Image.open(ROOT / "assets/icons/icon_1024.png").convert("RGBA")
        self.icon = shadowed(icon.resize((420, 420), Image.LANCZOS), radius=24, offset=(0, 16))
        self.sfx: list[tuple[float, str, float]] = []
        self._cache: dict = {}
        # scene list: (name, start, end)
        self.timeline = [
            ("intro", 0.0, 2.6),
            ("busy", 2.6, 7.6),
            ("chef", 7.6, 10.8),
            ("regulars", 10.8, 14.0),
            ("styles", 14.0, 17.9),
            ("outfits", 17.9, 21.0),
            ("helpers", 21.0, 23.2),
            ("end", 23.2, 27.0),
        ]
        self.duration = self.timeline[-1][2]
        self._plan_sfx()

    # -- footage ---------------------------------------------------------------------

    def extract_frames(self) -> None:
        if self.frames_dir.exists():
            return
        self.frames_dir.mkdir(parents=True)
        subprocess.run([ffmpeg(), "-v", "error", "-i", str(self.work / "capture.avi"), "-q:v", "2",
                        str(self.frames_dir / "f%05d.jpg")], check=True)

    def footage(self, shot: str, t: float, offset: float = 0.0) -> Image.Image:
        start, end = self.shots[shot]
        idx = min(end - 1, start + int(round((t + offset) * FPS)))
        key = (shot, idx)
        if key not in self._cache:
            self._cache.clear()
            # Movie Maker frame N is the (N+1)th image in the file.
            path = self.frames_dir / ("f%05d.jpg" % (idx + 1))
            self._cache[key] = Image.open(path).convert("RGBA").resize((W, H), Image.BILINEAR)
        return self._cache[key]

    def zoomed(self, img: Image.Image, z: float, cx: float = 0.5, cy: float = 0.5) -> Image.Image:
        if z <= 1.001:
            return img.copy()
        cw, ch = W / z, H / z
        x0 = clamp(cx * W - cw / 2, 0, W - cw)
        y0 = clamp(cy * H - ch / 2, 0, H - ch)
        return img.resize((W, H), Image.BILINEAR, box=(x0, y0, x0 + cw, y0 + ch))

    # -- scenes -----------------------------------------------------------------------

    def frame(self, t: float) -> Image.Image:
        for i, (name, a, b) in enumerate(self.timeline):
            if t < b or i == len(self.timeline) - 1:
                img = getattr(self, "scene_" + name)(t - a, b - a)
                break
        return self.transition(img, t)

    def caption(self, canvas, t, text, y, start=0.12, size=80, accent=STRAWBERRY, fg=INK, bg=WHITE):
        key = ("pill", text, size, accent, fg, bg)
        if key not in self._statics():
            self._statics()[key] = pill(text, size, fg=fg, bg=bg, accent=accent)
        s = pop(t, start, 0.5)
        wob = math.sin((t - start) * 5.0) * 2.0 * math.exp(-max(0.0, t - start) * 2.0)
        place(canvas, self._statics()[key], (W / 2, y), scale=s, angle=wob)

    def _statics(self) -> dict:
        if not hasattr(self, "_static_cache"):
            self._static_cache = {}
        return self._static_cache

    def static(self, key, make):
        cache = self._statics()
        if key not in cache:
            cache[key] = make()
        return cache[key]

    def portrait(self, name: str, size: int) -> Image.Image:
        return self.static(("portrait", name, size), lambda: shadowed(
            self.portraits[name].resize((size, size), Image.LANCZOS), radius=16, offset=(0, 12), alpha=55))

    def scene_intro(self, t: float, dur: float) -> Image.Image:
        bg = self.static("bg_intro", lambda: gradient(PEACH_LIGHT, (249, 196, 176)))
        img = bg.copy()
        img.alpha_composite(dots_layer(t, [CREAM, STRAWBERRY, BUTTER], 1))
        # Chef Mochi pops in and bobs.
        s = pop(t, 0.05, 0.55)
        bob = math.sin(t * 4.0) * 10
        place(img, self.portrait("chef", 760), (W / 2, 1010 + bob), scale=s)
        # Dishes pop in around the chef.
        dishes = ["latte", "cake", "pancakes", "soup", "sundae"]
        for i, d in enumerate(dishes):
            a = math.radians(165 - i * 37.5)  # an arc under the chef
            x, y = W / 2 + math.cos(a) * 410, 1400 + math.sin(a) * 260
            ds = pop(t, 0.55 + i * 0.12, 0.45)
            place(img, self.portrait(d, 230), (x, y + math.sin(t * 5 + i) * 8), scale=ds, angle=math.sin(t * 3 + i) * 6)
        place(img, self.static("t_run", lambda: shadowed(text_image("Run your own", 92, INK, 10, WHITE))), (W / 2, 330), scale=pop(t, 0.35))
        place(img, self.static("t_cafe", lambda: shadowed(text_image("tiny café!", 150, TOMATO, 14, WHITE))), (W / 2, 480), scale=pop(t, 0.6), angle=math.sin(t * 3) * 2)
        return img

    def scene_busy(self, t: float, dur: float) -> Image.Image:
        img = self.zoomed(self.footage("busy", t, 0.4), 1.0 + 0.07 * ease_in_out(t / dur), 0.5, 0.42)
        half = dur * 0.5
        if t < half:
            self.caption(img, t, "Cook yummy treats", 380)
            for i, d in enumerate(["latte", "cake", "pancakes", "sundae"]):
                x = W / 2 + (i - 1.5) * 200
                place(img, self.portrait(d, 190), (x, 560 + math.sin(t * 6 + i) * 8), scale=pop(t, 0.35 + i * 0.1) * (1 - ease_in_out((t - half + 0.25) / 0.25)))
        else:
            self.caption(img, t - half, "Serve cute guests", 380, accent=MINT)
        return img

    def scene_chef(self, t: float, dur: float) -> Image.Image:
        img = self.zoomed(self.footage("chef", t, 0.6), 1.0 + 0.05 * ease_in_out(t / dur))
        self.caption(img, t, "Collect big tips!", 300, accent=BUTTER)
        rnd = random.Random(7)
        for i in range(18):
            st = 0.35 + rnd.uniform(0, 1.6)
            k = t - st
            if k < 0 or k > 1.2:
                continue
            x0 = rnd.uniform(140, W - 140)
            x = x0 + math.sin(k * 6 + i) * 30
            y = H + 80 - k * rnd.uniform(1100, 1500) + 900 * k * k
            place(img, self.portrait("coin", 150), (x, y), scale=0.7 + 0.3 * math.sin(k * 3), angle=k * 160 * (1 if i % 2 else -1))
        return img

    def scene_regulars(self, t: float, dur: float) -> Image.Image:
        bg = self.static("bg_regulars", lambda: gradient(MINT_LIGHT, (206, 236, 220)))
        img = bg.copy()
        img.alpha_composite(dots_layer(t, [WHITE, MINT, BUTTER], 3))
        place(img, self.static("t_meet", lambda: shadowed(text_image("Meet the", 96, INK, 10, WHITE))), (W / 2, 260), scale=pop(t, 0.05))
        place(img, self.static("t_reg", lambda: shadowed(text_image("cutest regulars", 116, TOMATO, 12, WHITE))), (W / 2, 390), scale=pop(t, 0.2), angle=math.sin(t * 3) * 1.5)
        cast = [("bunny", "Pip"), ("bear", "Bruno"), ("frog", "Lily"), ("chick", "Sunny"), ("panda", "Bao")]
        spots = [(250, 800), (540, 760), (830, 800), (380, 1300), (700, 1300)]
        for i, ((who, name), (x, y)) in enumerate(zip(cast, spots)):
            s = pop(t, 0.35 + i * 0.14, 0.5)
            bob = math.sin(t * 5 + i * 1.3) * 10
            place(img, self.portrait(who, 400), (x, y + bob), scale=s)
            tag = self.static(("tag", name), lambda name=name: pill(name, 46, pad_x=30, pad_y=12, accent=STRAWBERRY))
            place(img, tag, (x, y + 215), scale=s)
            # hearts drift up
            for j in range(2):
                k = (t - 0.8 - i * 0.14 - j * 0.6) % 1.4
                if t < 0.8 + i * 0.14 + j * 0.6:
                    continue
                place(img, self.portrait("heart", 90), (x + 110 + j * 20, y - 120 - k * 220), scale=0.6 + k * 0.3, alpha=1.0 - k / 1.4)
        place(img, self.static("t_hearts", lambda: pill("Make friends, earn hearts", 60, accent=LAVENDER)), (W / 2, 1700), scale=pop(t, 1.2))
        return img

    def scene_styles(self, t: float, dur: float) -> Image.Image:
        img = self.zoomed(self.footage("styles", t, 0.35), 1.03)
        self.caption(img, t, "Decorate your way", 280, accent=LAVENDER)
        return img

    def scene_outfits(self, t: float, dur: float) -> Image.Image:
        img = self.zoomed(self.footage("outfits", t, 0.2), 1.3 + 0.06 * ease_in_out(t / dur), 0.5, 0.47)
        self.caption(img, t, "Dress up Chef Mochi", 280, accent=STRAWBERRY)
        return img

    def scene_helpers(self, t: float, dur: float) -> Image.Image:
        img = self.zoomed(self.footage("helpers", t, 0.4), 1.0 + 0.05 * ease_in_out(t / dur))
        self.caption(img, t, "Hire helpers & grow", 280, accent=SKY)
        place(img, self.portrait("penguin", 300), (190, 1650 + math.sin(t * 5) * 8), scale=pop(t, 0.4), angle=-6)
        place(img, self.portrait("hamster", 300), (W - 190, 1650 + math.sin(t * 5 + 1) * 8), scale=pop(t, 0.55), angle=6)
        return img

    def scene_end(self, t: float, dur: float) -> Image.Image:
        bg = self.static("bg_end", lambda: gradient(PEACH_LIGHT, (249, 196, 176)))
        img = bg.copy()
        img.alpha_composite(dots_layer(t, [CREAM, STRAWBERRY, MINT, BUTTER], 5))
        place(img, self.icon, (W / 2, 420 + math.sin(t * 3) * 8), scale=pop(t, 0.05, 0.6))
        place(img, self.static("t_cozy", lambda: shadowed(text_image("Cozy Mini", 132, INK, 12, WHITE))), (W / 2, 760), scale=pop(t, 0.3))
        place(img, self.static("t_rest", lambda: shadowed(text_image("Restaurant", 132, TOMATO, 12, WHITE))), (W / 2, 905), scale=pop(t, 0.42))
        place(img, self.static("t_tag", lambda: text_image("Cook · Serve · Decorate", 58, INK_SOFT, 0, bold=False)), (W / 2, 1035), scale=pop(t, 0.6), alpha=clamp((t - 0.6) / 0.3))
        # call to action: a pulsing button
        btn = self.static("cta", lambda: pill("Play free now", 88, fg=WHITE, bg=TOMATO, pad_x=80, pad_y=34, accent=(168, 63, 55)))
        pulse = 1.0 + 0.045 * math.sin(max(0.0, t - 1.0) * 7.0)
        place(img, btn, (W / 2, 1220), scale=pop(t, 0.8, 0.5) * pulse)
        # the cast lines up at the bottom
        cast = ["bunny", "bear", "chef", "frog", "panda"]
        for i, who in enumerate(cast):
            x = W / 2 + (i - 2) * 205
            size = 330 if who == "chef" else 270
            place(img, self.portrait(who, size), (x, 1640 + (0 if who == "chef" else 30) + math.sin(t * 5 + i) * 7), scale=pop(t, 1.0 + abs(i - 2) * 0.1, 0.5))
        place(img, self.static("t_free", lambda: text_image("Free to play on Android", 40, INK_SOFT, 0, bold=False)), (W / 2, 1865), alpha=clamp((t - 1.4) / 0.4))
        return img

    # -- transitions ------------------------------------------------------------------

    def transition(self, img: Image.Image, t: float) -> Image.Image:
        """A colour bubble that swells over each cut and opens onto the next scene."""
        half = 0.2
        colors = [STRAWBERRY, MINT, BUTTER, LAVENDER, SKY, STRAWBERRY, MINT]
        R = math.hypot(W, H) / 2 + 20
        for i, (_, start, _) in enumerate(self.timeline[1:]):
            d = t - start
            if -half <= d < half:
                c = colors[i % len(colors)] + (255,)
                layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                dr = ImageDraw.Draw(layer)
                cx, cy = W / 2, H / 2
                if d < 0:
                    r = R * ease_out_cubic((d + half) / half)
                    dr.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)
                else:
                    layer.paste(c, (0, 0, W, H))
                    r = R * ease_out_cubic(d / half)
                    dr.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(0, 0, 0, 0))
                img.alpha_composite(layer)
        return img

    # -- sound ------------------------------------------------------------------------

    def _plan_sfx(self) -> None:
        s = self.sfx
        for _, start, _ in self.timeline[1:]:
            s.append((start - 0.2, "whoosh", 0.5))
        s += [(0.05, "tap", 0.8), (0.35, "tap", 0.7), (0.6, "sparkle", 0.6)]
        s += [(0.55 + i * 0.12, "pickup", 0.45) for i in range(5)]
        busy = self.start("busy")
        s += [(busy + 0.12, "tap", 0.7), (busy + 2.62, "tap", 0.7), (busy + 1.0, "ready", 0.35), (busy + 3.2, "serve", 0.4)]
        chef = self.start("chef")
        s += [(chef + 0.12, "tap", 0.7)] + [(chef + 0.4 + i * 0.22, "coin", 0.35) for i in range(7)]
        reg = self.start("regulars")
        s += [(reg + 0.05, "tap", 0.7)] + [(reg + 0.35 + i * 0.14, "pickup", 0.5) for i in range(5)] + [(reg + 1.2, "sparkle", 0.5)]
        sty = self.start("styles")
        s += [(sty + 0.12, "tap", 0.7)] + [(sty + 0.4 + i * 0.75, "sparkle", 0.45) for i in range(5)]
        out = self.start("outfits")
        s += [(out + 0.12, "tap", 0.7)] + [(out + 0.42 + i * 0.62, "sparkle", 0.35) for i in range(5)]
        hel = self.start("helpers")
        s += [(hel + 0.12, "tap", 0.7), (hel + 0.4, "pickup", 0.5), (hel + 0.55, "pickup", 0.5)]
        end = self.start("end")
        s += [(end + 0.05, "sparkle", 0.6), (end + 0.3, "tap", 0.6), (end + 0.42, "tap", 0.6), (end + 0.8, "buy", 0.6)]

    def start(self, name: str) -> float:
        return next(a for n, a, _ in self.timeline if n == name)

    def mix_audio(self, path: Path) -> None:
        n = int(self.duration * RATE)
        music = load_wav(AUDIO / "music.wav")
        bed = np.zeros(n)
        pos = 0
        while pos < n:  # loop the music with a short crossfade
            seg = music[: n - pos]
            fade = min(len(seg), int(0.05 * RATE))
            seg = seg.copy()
            seg[:fade] *= np.linspace(0, 1, fade)
            bed[pos:pos + len(seg)] += seg
            pos += len(music) - fade
        bed *= 0.55
        out = int(1.2 * RATE)
        bed[-out:] *= np.linspace(1, 0, out)
        fx = np.zeros(n)
        for at, name, gain in self.sfx:
            clip = whoosh() if name == "whoosh" else load_wav(AUDIO / (name + ".wav"))
            i = int(at * RATE)
            if i < 0 or i >= n:
                continue
            clip = clip[: n - i]
            fx[i:i + len(clip)] += clip * gain
        mix = bed + fx
        peak = np.max(np.abs(mix))
        if peak > 0.95:
            mix *= 0.95 / peak
        data = (mix * 32767).astype("<i2")
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())

    # -- output ------------------------------------------------------------------------

    def render(self, out: Path) -> None:
        self.extract_frames()
        audio = self.work / "ad_audio.wav"
        self.mix_audio(audio)
        total = int(round(self.duration * FPS))
        cmd = [ffmpeg(), "-y", "-v", "error",
               "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
               "-i", str(audio),
               "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p",
               "-profile:v", "high", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart",
               "-shortest", str(out)]
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        for i in range(total):
            t = i / FPS
            frame = self.frame(t).convert("RGB")
            proc.stdin.write(frame.tobytes())
            if i % 60 == 0:
                print(f"  {i}/{total} frames", flush=True)
            if i == int(round((self.start("end") + 2.4) * FPS)):
                frame.save(out.with_name(out.stem + "_poster.png"))
        proc.stdin.close()
        proc.wait()
        if proc.returncode:
            raise SystemExit("ffmpeg failed")


# -- audio helpers ------------------------------------------------------------------

def load_wav(path: Path) -> np.ndarray:
    with wave.open(str(path)) as w:
        rate, ch = w.getframerate(), w.getnchannels()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    if rate != RATE:
        x = np.arange(int(len(data) * RATE / rate)) * rate / RATE
        data = np.interp(x, np.arange(len(data)), data)
    return data


def whoosh() -> np.ndarray:
    """A soft airy swish: band-limited noise with a rise and fall."""
    n = int(0.42 * RATE)
    rng = np.random.default_rng(3)
    noise = rng.standard_normal(n)
    # crude low-pass that opens up towards the middle
    out = np.zeros(n)
    acc = 0.0
    for i in range(n):
        k = 0.04 + 0.25 * math.sin(math.pi * i / n)
        acc += k * (noise[i] - acc)
        out[i] = acc
    env = np.sin(np.linspace(0, math.pi, n)) ** 2
    return out * env * 0.5


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg  # type: ignore
    return imageio_ffmpeg.get_ffmpeg_exe()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    work, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    Ad(work).render(out)
    print("wrote", out)
