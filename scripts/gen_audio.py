#!/usr/bin/env python3
"""Generate procedural placeholder audio for the Lemmings clone.

Pure standard library (wave + math) — no numpy. Writes 22.05 kHz mono 16-bit
WAVs: a handful of SFX and a short looping chiptune theme. These are prototype
stand-ins, meant to be replaced by real assets later.

Run:  python3 scripts/gen_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
SOUNDS = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
MUSIC = os.path.join(os.path.dirname(__file__), "..", "assets", "music")


def write_wav(path, samples):
    # samples: list of floats in [-1, 1]
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))
    print("wrote", os.path.relpath(path))


def env(i, n, attack=0.01, release=0.3):
    """Simple attack/exponential-release amplitude envelope."""
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = math.exp(-(max(0.0, t - (dur - release)) / release) * 3.0) if release > 0 else 1.0
    return a * r


def square(freq, i):
    return 1.0 if math.sin(2 * math.pi * freq * i / RATE) >= 0 else -1.0


def tone(freq, dur, kind="sine", vol=0.5, attack=0.005, release=0.05):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        if kind == "square":
            s = square(freq, i)
        elif kind == "saw":
            ph = (freq * i / RATE) % 1.0
            s = 2.0 * ph - 1.0
        else:
            s = math.sin(2 * math.pi * freq * i / RATE)
        out.append(s * vol * env(i, n, attack, release))
    return out


def sequence(notes, kind="square", vol=0.5):
    out = []
    for freq, dur in notes:
        out += tone(freq, dur, kind=kind, vol=vol, attack=0.004, release=min(0.06, dur * 0.5))
    return out


# Note frequencies (equal temperament).
def nf(semitones_from_a4):
    return 440.0 * (2 ** (semitones_from_a4 / 12.0))


C4, D4, E4, F4, G4, A4, B4 = (nf(x) for x in (-9, -7, -5, -4, -2, 0, 2))
C5, E5, G5 = nf(3), nf(7), nf(10)


def gen_skill_assign():
    write_wav(os.path.join(SOUNDS, "skill_assign.wav"),
              tone(880, 0.06, "square", vol=0.4, attack=0.002, release=0.04))


def gen_yippee():
    # Bright rising arpeggio — a saved lemming.
    write_wav(os.path.join(SOUNDS, "yippee.wav"),
              sequence([(C5, 0.07), (E5, 0.07), (G5, 0.07), (nf(15), 0.16)], vol=0.4))


def gen_oh_no():
    # Two falling notes — a lost lemming.
    write_wav(os.path.join(SOUNDS, "oh_no.wav"),
              sequence([(G4, 0.14), (nf(-6), 0.22)], kind="saw", vol=0.4))


def gen_explosion():
    rng = random.Random(1234)
    n = int(0.45 * RATE)
    out = []
    for i in range(n):
        e = math.exp(-(i / RATE) * 9.0)
        noise = (rng.random() * 2 - 1)
        rumble = math.sin(2 * math.pi * 70 * i / RATE)
        out.append((noise * 0.7 + rumble * 0.3) * 0.6 * e)
    write_wav(os.path.join(SOUNDS, "explosion.wav"), out)


def gen_music():
    # A calm looping chiptune: arpeggios over I–V–vi–IV, with a soft bass.
    chords = [
        [C4, E4, G4], [G4, B4, nf(2)],
        [A4, C5, E5], [F4, A4, C5],
    ]
    beat = 0.16
    melody = []
    for _rep in range(2):
        for ch in chords:
            pattern = [ch[0], ch[1], ch[2], ch[1]] * 2  # 8 sixteenths per chord
            for f in pattern:
                melody += tone(f, beat, "square", vol=0.22, attack=0.004, release=beat * 0.4)
    # Bass: root of each chord, one long note per chord.
    bass = []
    for _rep in range(2):
        for ch in chords:
            bass += tone(ch[0] / 2.0, beat * 8, "saw", vol=0.16, attack=0.01, release=0.2)
    n = min(len(melody), len(bass))
    mix = [melody[i] + bass[i] for i in range(n)]
    write_wav(os.path.join(MUSIC, "theme.wav"), mix)


def main():
    os.makedirs(SOUNDS, exist_ok=True)
    os.makedirs(MUSIC, exist_ok=True)
    gen_skill_assign()
    gen_yippee()
    gen_oh_no()
    gen_explosion()
    gen_music()


if __name__ == "__main__":
    main()
