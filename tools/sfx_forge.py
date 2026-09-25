#!/usr/bin/env python3
"""Synthesise every sound effect and the music loop for Cozy Mini Restaurant.

    python3 tools/sfx_forge.py

Writes 16-bit mono WAV files to assets/audio/. Standard library only.
"""

import math
import os
import random
import struct
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "audio"))
SR = 44100


def note(name):
    """'A4' -> Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semis -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12.0)


def buf(seconds, sr=SR):
    return [0.0] * int(seconds * sr)


def add_tone(b, start, dur, freq, amp=0.5, decay=6.0, attack=0.004, partials=((1, 1.0),), sr=SR, glide=0.0, vibrato=0.0):
    n0 = int(start * sr)
    n = int(dur * sr)
    phase = [0.0] * len(partials)
    for i in range(n):
        k = n0 + i
        if k >= len(b):
            k -= len(b)  # wrap tails (used by the seamless music loop)
        t = i / sr
        env = min(1.0, t / attack) * math.exp(-decay * t)
        f = freq * (1 + glide * t / max(dur, 1e-6)) * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        s = 0.0
        for j, (mult, pamp) in enumerate(partials):
            phase[j] += 2 * math.pi * f * mult / sr
            s += pamp * math.sin(phase[j]) * (math.exp(-decay * (mult - 1) * 0.35 * t) if mult > 1 else 1.0)
        b[k] += amp * env * s


def add_noise(b, start, dur, amp=0.3, decay=30.0, lowpass=0.2, seed=1, sr=SR):
    rnd = random.Random(seed)
    n0 = int(start * sr)
    y = 0.0
    for i in range(int(dur * sr)):
        t = i / sr
        y += lowpass * (rnd.uniform(-1, 1) - y)
        if n0 + i < len(b):
            b[n0 + i] += amp * y * math.exp(-decay * t)


def write(name, b, sr=SR, peak=0.85):
    m = max(1e-9, max(abs(x) for x in b))
    g = peak / m
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * g)) * 32767)) for x in b))
    print("%-10s %5.2fs" % (name, len(b) / sr))


BELL = ((1, 1.0), (2.76, 0.35), (5.4, 0.12))
MARIMBA = ((1, 1.0), (4.0, 0.25), (9.8, 0.05))
BOX = ((1, 1.0), (2, 0.3), (3, 0.08))


def sfx():
    b = buf(0.12)
    add_tone(b, 0, 0.12, 620, 0.8, decay=38, glide=0.6)
    write("tap", b)

    b = buf(0.35)
    add_noise(b, 0, 0.3, 0.5, decay=14, lowpass=0.08)
    add_tone(b, 0.02, 0.2, 330, 0.4, decay=14, glide=0.8)
    write("cook", b)

    b = buf(1.1)
    add_tone(b, 0, 1.1, note("E6"), 0.6, decay=4.5, partials=BELL)
    add_tone(b, 0.09, 1.0, note("B6"), 0.35, decay=5.0, partials=BELL)
    write("ready", b)

    b = buf(0.16)
    add_tone(b, 0, 0.16, 440, 0.7, decay=22, glide=0.5, partials=MARIMBA)
    write("pickup", b)

    b = buf(0.8)
    for i, n in enumerate(("C6", "E6", "G6")):
        add_tone(b, i * 0.075, 0.6, note(n), 0.5, decay=6, partials=MARIMBA)
    write("serve", b)

    b = buf(0.5)
    add_tone(b, 0, 0.08, note("B5"), 0.45, decay=4, partials=((1, 1.0), (3, 0.3), (5, 0.12)))
    add_tone(b, 0.07, 0.42, note("E6"), 0.45, decay=7, partials=((1, 1.0), (3, 0.3), (5, 0.12)))
    write("coin", b)

    b = buf(0.45)
    add_tone(b, 0, 0.42, 150, 0.6, decay=5, partials=((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)), glide=-0.25, vibrato=0.04)
    write("grumble", b)

    b = buf(1.2)
    add_tone(b, 0, 1.2, note("G6"), 0.5, decay=4, partials=BELL)
    add_tone(b, 0.14, 1.05, note("C7"), 0.4, decay=4, partials=BELL)
    write("door", b)

    b = buf(0.9)
    add_noise(b, 0, 0.05, 0.6, decay=60, lowpass=0.5, seed=4)
    add_tone(b, 0.05, 0.8, note("A6"), 0.45, decay=5, partials=BELL)
    add_tone(b, 0.12, 0.75, note("E7"), 0.3, decay=6, partials=BELL)
    write("buy", b)

    b = buf(0.35)
    add_tone(b, 0, 0.14, note("E4"), 0.5, decay=16, partials=MARIMBA)
    add_tone(b, 0.13, 0.2, note("C4"), 0.5, decay=14, partials=MARIMBA)
    write("nope", b)

    b = buf(1.6)
    for i, n in enumerate(("C5", "E5", "G5", "C6")):
        add_tone(b, i * 0.11, 1.2, note(n), 0.45, decay=3.5, partials=MARIMBA)
    add_tone(b, 0.44, 1.1, note("E6"), 0.25, decay=3, partials=BELL)
    write("open", b)

    b = buf(2.2)
    for i, n in enumerate(("G5", "E5", "C5", "D5", "C5")):
        add_tone(b, i * 0.16 + (0.1 if i == 4 else 0), 1.4, note(n), 0.45, decay=3, partials=MARIMBA)
    add_tone(b, 0.74, 1.4, note("C4"), 0.3, decay=2.5, partials=BOX)
    write("close", b)

    b = buf(0.5)
    add_tone(b, 0, 0.45, note("C6"), 0.4, decay=7, partials=BELL)
    add_tone(b, 0.06, 0.4, note("G6"), 0.3, decay=8, partials=BELL)
    write("sparkle", b)


def music():
    sr = 22050
    bpm = 88.0
    beat = 60.0 / bpm
    bars = 8
    b = buf(bars * 4 * beat, sr)
    chords = [("C3", "E4", "G4", "C5"), ("A2", "E4", "A4", "C5"), ("F2", "F4", "A4", "C5"), ("G2", "D4", "G4", "B4"),
              ("C3", "E4", "G4", "C5"), ("A2", "E4", "A4", "C5"), ("F2", "F4", "A4", "D5"), ("G2", "D4", "G4", "B4")]
    melody = [
        "E5 - G5 - A5 G5 E5 -", "C5 - E5 - D5 - C5 -", "A4 - C5 - D5 C5 A4 -", "G4 - A4 - B4 - D5 -",
        "E5 - G5 - C6 - A5 G5", "E5 - - - D5 E5 G5 -", "A5 G5 E5 - D5 - C5 -", "D5 - - - - - - -",
    ]
    eighth = beat / 2
    for bar, (bass, *tones) in enumerate(chords):
        t0 = bar * 4 * beat
        add_tone(b, t0, 4 * beat, note(bass), 0.28, decay=0.9, attack=0.02, partials=((1, 1.0), (2, 0.25)), sr=sr)
        add_tone(b, t0 + 2 * beat, 2 * beat, note(bass), 0.18, decay=1.4, attack=0.02, partials=((1, 1.0), (2, 0.25)), sr=sr)
        arp = [tones[0], tones[1], tones[2], tones[1]] * 2
        for i, n in enumerate(arp):
            add_tone(b, t0 + i * eighth, eighth * 3, note(n), 0.07, decay=5.5, partials=MARIMBA, sr=sr)
        for i, n in enumerate(melody[bar].split()):
            if n != "-":
                add_tone(b, t0 + i * eighth, beat * 3, note(n), 0.2, decay=2.2, partials=BOX, sr=sr)
    write("music", b, sr=sr, peak=0.7)


if __name__ == "__main__":
    sfx()
    music()
