#!/usr/bin/env python3
"""Procedural chiptune soundtrack generator for the Lemmings clone.

Synthesizes the game's music pack from scratch — original compositions in the
spirit of the DOS-era soundtrack (square/triangle leads, oom-pah basses, noise
drums), NOT covers: every melody below is hand-written for this project.
Deterministic: the same script always renders bit-identical tracks.

Usage (needs numpy + soundfile):
    python3 -m venv /tmp/musicenv && /tmp/musicenv/bin/pip install numpy soundfile
    /tmp/musicenv/bin/python scripts/make_music.py [out_dir]

Renders remake_01..remake_17.ogg (one per original DOS tune slot, similar
duration and mood) and theme.ogg (title screen) into assets/music/.
"""

import math
import os
import random
import sys

import numpy as np
import soundfile as sf

SR = 44100

# ── Oscillators ───────────────────────────────────────────────────────────────

def _phase(freq, n, vib_hz=0.0, vib_amt=0.0):
    t = np.arange(n) / SR
    f = freq * (1.0 + vib_amt * np.sin(2 * math.pi * vib_hz * t))
    return np.cumsum(f) / SR


def osc(freq, n, wave_name, vib_hz=0.0, vib_amt=0.0):
    p = _phase(freq, n, vib_hz, vib_amt) % 1.0
    if wave_name == "pulse50":
        return np.where(p < 0.5, 1.0, -1.0)
    if wave_name == "pulse25":
        return np.where(p < 0.25, 1.0, -1.0)
    if wave_name == "pulse12":
        return np.where(p < 0.125, 1.0, -1.0)
    if wave_name == "tri":
        return 2.0 * np.abs(2.0 * p - 1.0) - 1.0
    if wave_name == "saw":
        return 2.0 * p - 1.0
    raise ValueError(wave_name)


def envelope(n, attack, decay, sustain, release):
    """Linear ADSR over n samples; release eats the tail of the note."""
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    env = np.full(n, sustain)
    a = min(a, n)
    env[:a] = np.linspace(0.0, 1.0, a)
    d_end = min(a + d, n)
    if d_end > a:
        env[a:d_end] = np.linspace(1.0, sustain, d_end - a)
    if r < n:
        env[n - r:] *= np.linspace(1.0, 0.0, r)
    else:
        env *= np.linspace(1.0, 0.0, n)
    return env


def midi_freq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# ── Music theory helpers ─────────────────────────────────────────────────────

MODES = {
    "major":      [0, 2, 4, 5, 7, 9, 11],
    "minor":      [0, 2, 3, 5, 7, 8, 10],
    "dorian":     [0, 2, 3, 5, 7, 9, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}


def scale_midi(key_root, mode, degree):
    """Diatonic degree (any int, octaves wrap) → MIDI note."""
    steps = MODES[mode]
    octave, idx = divmod(degree, 7)
    return key_root + 12 * octave + steps[idx]


def chord_degrees(root_degree):
    """Diatonic triad on a scale degree (degrees, not semitones)."""
    return [root_degree, root_degree + 2, root_degree + 4]


def snap_to_chord(degree, chord_root):
    """Snap a diatonic degree to the nearest chord tone of the triad."""
    tones = []
    for base in chord_degrees(chord_root):
        for octave in (-2, -1, 0, 1, 2):
            tones.append(base + 7 * octave)
    return min(tones, key=lambda t: (abs(t - degree), t < degree))


# ── Drums ────────────────────────────────────────────────────────────────────

def drum_kick(n):
    t = np.arange(n) / SR
    f = 110.0 * np.exp(-t * 28.0) + 38.0
    body = np.sin(2 * math.pi * np.cumsum(f) / SR)
    return body * np.exp(-t * 22.0)


def drum_snare(n, rng):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    tone = np.sin(2 * math.pi * 185.0 * t)
    return (0.7 * noise + 0.3 * tone) * np.exp(-t * 30.0)


def drum_hat(n, rng):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # crude high-pass: difference of the noise
    hp = np.diff(noise, prepend=0.0)
    return hp * np.exp(-t * 70.0) * 0.7


# ── Sequencer ────────────────────────────────────────────────────────────────

class Song:
    def __init__(self, spec):
        self.spec = spec
        self.beat_sec = 60.0 / spec["bpm"]
        self.bar_beats = spec.get("bar_beats", 4)
        self.events = {"lead": [], "arp": [], "bass": []}   # (beat, dur, midi)
        self.drum_events = []                                # (beat, kind)
        self.total_beats = 0.0

    # -- composition ----------------------------------------------------------

    def compose(self):
        spec = self.spec
        prog = spec["prog"]                      # one chord degree per bar
        motif = spec["motif"]                    # [(dur_beats, contour_degree|None)]
        bars_per_motif = max(1, round(sum(d for d, _ in motif) / self.bar_beats))
        rng = random.Random(spec["seed"])

        # Repeat the progression enough times to reach the target length, with
        # the lead an octave up + ornaments on later passes so it develops.
        sec_per_bar = self.beat_sec * self.bar_beats
        body_bars = len(prog)
        passes = max(1, round(spec["target_sec"] / (sec_per_bar * body_bars)))
        beat = 0.0
        for p in range(passes):
            beat = self._compose_pass(beat, p, prog, motif, bars_per_motif, rng)
        # Final chord: a held tonic so the loop point breathes.
        self._add_chord(beat, self.bar_beats, 0)
        self.events["lead"].append((beat, self.bar_beats, self._melody_midi(0, 0)))
        self.total_beats = beat + self.bar_beats

    def _compose_pass(self, beat, pass_idx, prog, motif, bars_per_motif, rng):
        spec = self.spec
        lead_oct = 12 if (pass_idx % 2 == 1) else 0
        for bar_idx in range(0, len(prog), bars_per_motif):
            chords = prog[bar_idx:bar_idx + bars_per_motif]
            chord = chords[0]
            cadence = bar_idx + bars_per_motif >= len(prog)
            # Lead: the motif, planted on the current chord.
            t = beat
            notes = list(motif)
            for ni, (dur, contour) in enumerate(notes):
                bar_off = int((t - beat) // self.bar_beats)
                chord = chords[min(bar_off, len(chords) - 1)]
                if contour is not None:
                    degree = chord + contour
                    on_strong = abs((t - beat) % self.bar_beats) < 1e-6
                    if on_strong:
                        degree = snap_to_chord(degree, chord)
                    if cadence and ni == len(notes) - 1:
                        degree = 0 if chord == 0 else snap_to_chord(0, chord)
                    midi = self._melody_midi(degree, lead_oct)
                    self.events["lead"].append((t, dur, midi))
                    # Sparse ornament on repeat passes: a quick upper neighbour.
                    if (pass_idx > 0 and dur >= 1.0 and rng.random() < 0.3
                            and not cadence):
                        self.events["lead"].append(
                            (t + dur * 0.5, 0.25, self._melody_midi(degree + 1, lead_oct)))
                t += dur
            # Bass + arpeggio + drums, bar by bar.
            for b, chord in enumerate(chords):
                self._add_bar_accomp(beat + b * self.bar_beats, chord, pass_idx)
            beat += self.bar_beats * len(chords)
        return beat

    def _melody_midi(self, degree, extra_oct):
        spec = self.spec
        return scale_midi(spec["key"] + 12, spec["mode"], degree) + extra_oct

    def _add_chord(self, beat, dur, chord):
        for d in chord_degrees(chord):
            self.events["arp"].append((beat, dur, scale_midi(self.spec["key"], self.spec["mode"], d)))
        self.events["bass"].append((beat, dur, scale_midi(self.spec["key"] - 12, self.spec["mode"], chord)))

    def _add_bar_accomp(self, beat, chord, pass_idx):
        spec = self.spec
        key, mode = spec["key"], spec["mode"]
        root = scale_midi(key - 12, mode, chord)
        fifth = scale_midi(key - 12, mode, chord + 4)
        bb = self.bar_beats
        # Bass.
        pattern = spec.get("bass", "oompah")
        if pattern == "oompah":
            for b in range(bb):
                self.events["bass"].append((beat + b, 0.9, root if b % 2 == 0 else fifth))
        elif pattern == "roots":
            self.events["bass"].append((beat, bb * 0.95, root))
        elif pattern == "pulse8":
            for h in range(bb * 2):
                self.events["bass"].append((beat + h * 0.5, 0.45, root if h % 4 != 3 else fifth))
        elif pattern == "walk":
            steps = [chord, chord + 2, chord + 4, chord + 5][:bb]
            for b, d in enumerate(steps):
                self.events["bass"].append((beat + b, 0.9, scale_midi(key - 12, mode, d)))
        # Arpeggio / pad.
        arp = spec.get("arp", "up8")
        tones = [scale_midi(key, mode, d) for d in chord_degrees(chord)]
        if arp == "up8":
            for h in range(bb * 2):
                self.events["arp"].append((beat + h * 0.5, 0.4, tones[h % 3]))
        elif arp == "updown16":
            order = [0, 1, 2, 1]
            for q in range(bb * 4):
                self.events["arp"].append((beat + q * 0.25, 0.2, tones[order[q % 4]]))
        elif arp == "pad":
            for tone in tones:
                self.events["arp"].append((beat, bb * 0.95, tone))
        # Drums.
        drums = spec.get("drums", "light")
        if drums == "none":
            return
        for b in range(bb):
            if drums == "full":
                self.drum_events.append((beat + b, "kick" if b % 2 == 0 else "snare"))
                self.drum_events.append((beat + b + 0.5, "hat"))
            else:  # light
                if b == 0:
                    self.drum_events.append((beat + b, "kick"))
                self.drum_events.append((beat + b + 0.5, "hat"))

    # -- rendering --------------------------------------------------------------

    CHANNELS = {
        #          wave        gain  pan    a      d     s     r     vib_amt
        "lead": ("pulse50", 0.27, 0.12, 0.004, 0.05, 0.75, 0.05, 0.004),
        "arp":  ("pulse12", 0.13, -0.22, 0.002, 0.03, 0.6, 0.03, 0.0),
        "bass": ("tri",     0.30, 0.0,  0.004, 0.02, 0.9, 0.04, 0.0),
    }

    def render(self):
        spec = self.spec
        n_total = int(self.total_beats * self.beat_sec * SR) + SR
        left = np.zeros(n_total)
        right = np.zeros(n_total)
        for ch_name, events in self.events.items():
            wave_name, gain, pan, a, d, s, r, vib = self.CHANNELS[ch_name]
            wave_name = spec.get(ch_name + "_wave", wave_name)
            buf = np.zeros(n_total)
            for beat, dur, midi in events:
                start = int(beat * self.beat_sec * SR)
                n = max(1, int(dur * self.beat_sec * SR))
                if start + n > n_total:
                    n = n_total - start
                if n <= 0:
                    continue
                tone = osc(midi_freq(midi), n, wave_name, vib_hz=5.5, vib_amt=vib)
                buf[start:start + n] += tone * envelope(n, a, d, s, r)
            if ch_name == "lead":
                buf = self._echo(buf)
            l_gain = gain * (1.0 - max(0.0, pan))
            r_gain = gain * (1.0 + min(0.0, pan))
            left += buf * l_gain
            right += buf * r_gain
        # Drums (center, fixed kit).
        rng = np.random.default_rng(spec["seed"])
        kit_gain = 0.16
        for beat, kind in self.drum_events:
            start = int(beat * self.beat_sec * SR)
            n = int(0.18 * SR)
            if start + n > n_total:
                continue
            if kind == "kick":
                hit = drum_kick(n)
            elif kind == "snare":
                hit = drum_snare(n, rng)
            else:
                hit = drum_hat(int(0.06 * SR), rng)
                n = hit.shape[0]
            left[start:start + n] += hit * kit_gain
            right[start:start + n] += hit * kit_gain
        # Master: soft clip + normalize, trim the silent tail.
        mix = np.stack([left, right])
        mix = np.tanh(mix * 1.4)
        peak = np.max(np.abs(mix)) or 1.0
        mix *= 0.88 / peak
        tail = np.max(np.abs(mix), axis=0)
        last = np.nonzero(tail > 1e-4)[0]
        end = (last[-1] + int(0.25 * SR)) if last.size else n_total
        return mix[:, :min(end, n_total)]

    def _echo(self, buf):
        delay = int(self.beat_sec * 0.75 * SR)
        out = buf.copy()
        if delay <= 0 or delay >= buf.shape[0]:
            return out
        out[delay:] += buf[:-delay] * 0.28
        out[2 * delay:] += buf[:-2 * delay] * 0.10
        return out


# ── The pack: 18 original compositions ───────────────────────────────────────
# Motif notation: (duration_in_beats, diatonic_contour_offset_or_None_for_rest),
# offsets are relative to the current chord's root degree.

Q, E, H, DQ = 1.0, 0.5, 2.0, 1.5

SONGS = [
    # 01 — «Зелёные холмы»: пасторальный канон-настрой, спокойная секвенция.
    dict(name="remake_01", seed=101, bpm=100, key=62, mode="major", target_sec=53,
         prog=[0, 4, 5, 2, 3, 0, 3, 4],
         motif=[(Q, 4), (E, 3), (E, 2), (Q, 0), (Q, 2),
                (Q, 3), (E, 2), (E, 1), (H, 0)],
         bass="roots", arp="up8", drums="light", lead_wave="pulse50"),
    # 02 — «Марш-бросок»: бодрая полька.
    dict(name="remake_02", seed=102, bpm=132, key=55, mode="major", target_sec=53,
         prog=[0, 0, 3, 4, 0, 3, 4, 0],
         motif=[(E, 0), (E, 2), (E, 4), (E, 2), (Q, 5), (Q, 4),
                (E, 4), (E, 3), (E, 2), (E, 3), (H, 2)],
         bass="oompah", arp="off", drums="full", lead_wave="pulse25"),
    # 03 — «Сырые пещеры»: настороженный минор.
    dict(name="remake_03", seed=103, bpm=96, key=57, mode="minor", target_sec=55,
         prog=[0, 5, 2, 6, 0, 5, 6, 0],
         motif=[(Q, 0), (Q, 2), (DQ, 4), (E, 3), (Q, 2), (Q, 1), (H, 0)],
         bass="roots", arp="updown16", drums="light", lead_wave="tri"),
    # 04 — «Долгий путь домой»: неторопливый вальс-шкатулка.
    dict(name="remake_04", seed=104, bpm=92, key=60, mode="major", target_sec=105,
         bar_beats=3,
         prog=[0, 3, 4, 0, 5, 3, 4, 0, 0, 4, 5, 2, 3, 4, 0, 0],
         motif=[(Q, 2), (Q, 4), (Q, 3), (Q, 2), (Q, 1), (Q, 2), (H, 0), (Q, None)],
         bass="oompah", arp="off", drums="none", lead_wave="pulse12"),
    # 05 — «Джига на верстаке»: 6/8-наигрыш.
    dict(name="remake_05", seed=105, bpm=126, key=64, mode="dorian", target_sec=63,
         bar_beats=3,
         prog=[0, 0, 6, 6, 0, 6, 0, 0],
         motif=[(E, 0), (E, 1), (E, 2), (E, 4), (E, 2), (E, 4),
                (E, 5), (E, 4), (E, 2), (Q, 0), (E, None)],
         bass="roots", arp="up8", drums="light", lead_wave="pulse50"),
    # 06 — «Парад спасателей»: уверенный марш.
    dict(name="remake_06", seed=106, bpm=116, key=53, mode="major", target_sec=79,
         prog=[0, 3, 0, 4, 0, 3, 4, 0],
         motif=[(Q, 0), (E, 0), (E, 1), (Q, 2), (Q, 4),
                (E, 5), (E, 4), (E, 3), (E, 2), (H, 2)],
         bass="oompah", arp="off", drums="full", lead_wave="pulse50"),
    # 07 — «Подземная река»: дорийский грув.
    dict(name="remake_07", seed=107, bpm=108, key=62, mode="dorian", target_sec=87,
         prog=[0, 3, 0, 3, 0, 3, 6, 0],
         motif=[(E, 0), (E, 2), (Q, 3), (E, 2), (E, 0), (Q, 2),
                (E, 4), (E, 3), (Q, 2), (H, 0)],
         bass="pulse8", arp="updown16", drums="light", lead_wave="pulse25"),
    # 08 — «Наперегонки»: короткий галоп.
    dict(name="remake_08", seed=108, bpm=152, key=58, mode="major", target_sec=45,
         prog=[0, 4, 0, 4, 3, 4, 0, 0],
         motif=[(E, 0), (E, 2), (E, 4), (E, 5), (Q, 4), (E, 2), (E, 3),
                (E, 4), (E, 2), (H, 0)],
         bass="oompah", arp="off", drums="full", lead_wave="pulse25"),
    # 09 — «Ярмарка»: народный мотив с притопом.
    dict(name="remake_09", seed=109, bpm=124, key=57, mode="major", target_sec=71,
         prog=[0, 0, 4, 0, 3, 0, 4, 0],
         motif=[(Q, 0), (E, 2), (E, 2), (Q, 4), (Q, 2),
                (E, 5), (E, 4), (E, 3), (E, 2), (Q, 1), (Q, 0)],
         bass="oompah", arp="off", drums="full", lead_wave="pulse50"),
    # 10 — «Кристальный грот»: медленная капель.
    dict(name="remake_10", seed=110, bpm=84, key=60, mode="minor", target_sec=68,
         prog=[0, 2, 5, 6, 0, 2, 6, 0],
         motif=[(Q, 4), (Q, 2), (DQ, 0), (E, 1), (Q, 2), (Q, 4), (H, 2)],
         bass="roots", arp="updown16", drums="none", lead_wave="tri"),
    # 11 — «Весёлая шахта»: миксолидийский разгул.
    dict(name="remake_11", seed=111, bpm=128, key=55, mode="mixolydian", target_sec=63,
         prog=[0, 6, 3, 0, 0, 6, 3, 0],
         motif=[(E, 0), (E, 1), (E, 2), (E, 3), (Q, 4), (E, 3), (E, 2),
                (E, 1), (E, 2), (H, 0)],
         bass="pulse8", arp="off", drums="full", lead_wave="pulse25"),
    # 12 — «Колыбельная цеха»: музыкальная шкатулка.
    dict(name="remake_12", seed=112, bpm=104, key=64, mode="major", target_sec=55,
         prog=[0, 5, 3, 4, 0, 5, 4, 0],
         motif=[(E, 4), (E, 5), (Q, 4), (Q, 2), (E, 1), (E, 2), (Q, 0), (Q, None)],
         bass="roots", arp="up8", drums="none", lead_wave="pulse12"),
    # 13 — «Время поджимает»: спринт под таймер.
    dict(name="remake_13", seed=113, bpm=160, key=62, mode="major", target_sec=47,
         prog=[0, 3, 4, 0, 5, 3, 4, 4],
         motif=[(E, 0), (E, 2), (E, 4), (E, 2), (E, 5), (E, 4), (E, 2), (E, 0),
                (Q, 1), (Q, 0)],
         bass="pulse8", arp="off", drums="full", lead_wave="pulse50"),
    # 14 — «Старая мельница»: минорный вальс.
    dict(name="remake_14", seed=114, bpm=100, key=54, mode="minor", target_sec=79,
         bar_beats=3,
         prog=[0, 0, 5, 5, 2, 6, 0, 0],
         motif=[(Q, 0), (Q, 2), (Q, 4), (Q, 5), (Q, 4), (Q, 2), (H, 1), (Q, 0)],
         bass="oompah", arp="off", drums="light", lead_wave="tri"),
    # 15 — «Большое восхождение»: широкая тема с подъёмом.
    dict(name="remake_15", seed=115, bpm=112, key=60, mode="major", target_sec=95,
         prog=[0, 4, 5, 3, 0, 4, 3, 4, 0, 2, 5, 3, 4, 4, 0, 0],
         motif=[(Q, 0), (Q, 2), (H, 4), (E, 5), (E, 4), (E, 3), (E, 2), (Q, 3), (Q, 2)],
         bass="walk", arp="up8", drums="light", lead_wave="pulse50"),
    # 16 — «Огненный зал»: тревожное танго.
    dict(name="remake_16", seed=116, bpm=112, key=59, mode="minor", target_sec=63,
         prog=[0, 0, 6, 0, 5, 6, 0, 0],
         motif=[(DQ, 0), (E, 1), (Q, 2), (Q, 4), (E, 5), (E, 4), (Q, 3), (H, 2)],
         bass="pulse8", arp="pad", drums="light", lead_wave="saw"),
    # 17 — «Закат над лугом»: мягкое прощание.
    dict(name="remake_17", seed=117, bpm=92, key=55, mode="major", target_sec=53,
         prog=[0, 5, 3, 4, 0, 5, 4, 0],
         motif=[(Q, 4), (Q, 3), (Q, 2), (E, 1), (E, 2), (H, 0),
                (Q, 2), (Q, 4), (H, 4)],
         bass="roots", arp="up8", drums="none", lead_wave="tri"),
    # Заглавная тема меню.
    dict(name="theme", seed=100, bpm=120, key=62, mode="major", target_sec=42,
         prog=[0, 3, 4, 0, 5, 3, 4, 0],
         motif=[(Q, 0), (E, 2), (E, 4), (Q, 5), (Q, 4),
                (E, 3), (E, 2), (Q, 3), (H, 2)],
         bass="oompah", arp="up8", drums="light", lead_wave="pulse50"),
]


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "assets/music"
    os.makedirs(out_dir, exist_ok=True)
    for spec in SONGS:
        ogg_path = os.path.join(out_dir, spec["name"] + ".ogg")
        # Already rendered (re-runs only fill the gaps; delete a file to redo it).
        if os.path.exists(ogg_path) and os.path.getsize(ogg_path) > 10240:
            print("%-12s kept" % spec["name"], flush=True)
            continue
        song = Song(spec)
        song.compose()
        mix = song.render()
        # Write via a temp name so a crash never leaves a half-written .ogg, and
        # in chunks: a single multi-million-frame write hangs libsndfile's
        # vorbis encoder in uninterruptible sleep (observed at > 2^22 frames).
        tmp_path = ogg_path + ".part"
        data = np.clip(mix.T, -1.0, 1.0)
        with sf.SoundFile(tmp_path, "w", SR, 2, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(data), 65536):
                f.write(data[i:i + 65536])
        os.replace(tmp_path, ogg_path)
        print("%-12s %5.1fs  bpm=%d key=%d %s" % (
            spec["name"], mix.shape[1] / SR, spec["bpm"], spec["key"], spec["mode"]),
            flush=True)


if __name__ == "__main__":
    main()
