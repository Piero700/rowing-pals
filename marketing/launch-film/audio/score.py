"""Original score for the Rowing Pals launch film (no samples, nothing to license).

90 s in D major / B minor. Builds in four stages that follow the picture:
  0–27 s   opening + problem: a low B-minor pad, sparse piano, and a soft "stroke" swell every 2.4 s
           (filtered noise shaped like an erg drive), thinning to almost nothing at 14–27 s.
  27–29 s  reveal: a swell into D major on the downbeat at 29.0 s.
  29–83 s  demonstration: the progression D – A – Bm – G (4 s per chord), plucked arpeggios from
           37 s, a soft pulse from 52 s, a high shimmer layer from 68 s.
  83–90 s  close: one sustained D major, a final piano note, decay to silence.

Writes audio/score.wav (48 kHz stereo, peak-normalised to -6 dBFS; ducking and loudness happen in mix.py).
Deterministic: fixed RNG seed.
"""
import wave
from pathlib import Path

import numpy as np

SR = 48000
DUR = 90.0
N = int(SR * DUR)
rng = np.random.default_rng(7)
OUT = Path(__file__).parent / "score.wav"


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a, d, s, r, sustain_len):
    """Linear-ish ADSR envelope in samples; total length = a + d + sustain_len + r."""
    A = np.linspace(0, 1, max(1, int(a * SR)), endpoint=False)
    D = np.linspace(1, s, max(1, int(d * SR)), endpoint=False)
    S = np.full(max(0, int(sustain_len * SR)), s)
    R = np.linspace(s, 0, max(1, int(r * SR)))
    e = np.concatenate([A, D, S, R])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def lp_fast(x, cutoff):
    """Fixed-cutoff low-pass via FFT (brick-wall with a soft knee)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def add(buf, sig, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N:
        return
    sig = sig[: N - i]
    l = np.cos((pan + 1) * np.pi / 4) * gain
    r = np.sin((pan + 1) * np.pi / 4) * gain
    buf[0, i:i + len(sig)] += sig * l
    buf[1, i:i + len(sig)] += sig * r


def pad_voice(freq, dur, attack=2.5, release=3.0, bright=1800.0):
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for det in (-0.07, 0.0, 0.06):  # detuned saws, in semitones
        f = freq * 2 ** (det / 12)
        ph = (t * f + rng.random()) % 1.0
        s += 2 * ph - 1
    s = lp_fast(s / 3, bright)
    s += 0.35 * np.sin(2 * np.pi * freq * t)  # body
    return s * env_adsr(n, attack, 0.5, 0.85, release, dur - attack - 0.5)


def piano(freq, dur=4.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for k, amp in enumerate((1.0, 0.45, 0.22, 0.12, 0.06), start=1):
        fk = freq * k * (1 + 0.0004 * k * k)  # slight inharmonicity
        s += amp * np.sin(2 * np.pi * fk * t) * np.exp(-t * (1.1 + 0.9 * k))
    att = np.minimum(1, t / 0.004)
    return s * att * 0.6


_PLUCKS = {}


def pluck(freq, dur=1.2):
    """Karplus-Strong pluck, soft (cached per pitch so the same note sounds the same)."""
    key = round(freq, 3)
    if key in _PLUCKS:
        return _PLUCKS[key]
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p)
    buf = lp_fast(np.tile(buf, 4), 3000)[:p]
    out = np.empty(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % p
        buf[idx] = 0.996 * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    _PLUCKS[key] = lp_fast(out, 2600) * np.exp(-np.arange(n) / SR * 1.8)
    return _PLUCKS[key]


def soft_kick(dur=0.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 46 + 70 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7.5)


def stroke_swell(dur=2.4):
    """An erg 'drive': filtered noise swelling up and easing off, like air through the fan."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    drive = np.clip(t / 0.9, 0, 1) ** 1.6 * np.exp(-np.clip(t - 0.9, 0, None) * 2.2)
    return lp_fast(lp_fast(noise, 500), 500) * drive


music = np.zeros((2, N))

# --- chords --------------------------------------------------------------------------------
B_MIN = [47, 54, 59, 62]          # B2 F#3 B3 D4
D_MAJ = [50, 57, 62, 66]          # D3 A3 D4 F#4
A_MAJ = [45, 52, 61, 64]          # A2 E3 C#4 E4
G_MAJ = [43, 50, 59, 62]          # G2 D3 B3 D4
PROG = [D_MAJ, A_MAJ, B_MIN, G_MAJ]

# 0–27: low B-minor pad, fading in; thins (top voices drop) during the problem section
for i, n_ in enumerate(B_MIN):
    dur = 27.5 if i < 2 else 12.0
    add(music, pad_voice(midi(n_), dur, attack=4.0, release=3.0, bright=900), 0.6, 0.08, pan=(-0.3 + 0.2 * i))

# sparse piano in the opening
for t, n_ in ((4.0, 66), (6.8, 69), (9.6, 74), (14.3, 66), (21.0, 62)):
    add(music, piano(midi(n_), 5.0), t, 0.16, pan=0.15)

# erg 'stroke' swells: present in the opening, sparse in the problem section, gone at the reveal
for k, t in enumerate(np.arange(0.3, 26.5, 2.4)):
    g = 0.13 if t < 14 else 0.07
    add(music, stroke_swell(), t, g, pan=(-0.15 if k % 2 else 0.15))

# 27–29: reveal swell (noise riser + rising pad) into the downbeat at 29.0
n = int(2.2 * SR)
tt = np.arange(n) / SR
riser = lp_fast(rng.uniform(-1, 1, n), 2400) * (tt / 2.2) ** 2.5
add(music, riser, 26.8, 0.18)
for n_ in D_MAJ:
    add(music, pad_voice(midi(n_ + 12), 2.2, attack=2.0, release=0.4, bright=2400), 26.8, 0.05)

# 29–83: progression, 4 s per chord
T0 = 29.0
for c in range(14):
    t = T0 + 4 * c
    chord = PROG[c % 4]
    for i, n_ in enumerate(chord):
        add(music, pad_voice(midi(n_), 4.0, attack=0.6 if c else 0.05, release=1.6, bright=1500 + 60 * c),
            t, 0.06 + 0.035 * c / 13, pan=(-0.35 + 0.23 * i))
    add(music, pad_voice(midi(chord[0] - 12), 4.0, attack=0.3, release=1.0, bright=300), t, 0.10)  # bass
    if t >= 37:  # plucked arpeggio, eighth notes at 120 bpm
        arp = [chord[1] + 12, chord[2] + 12, chord[3] + 12, chord[2] + 12]
        for k in range(16):
            g = 0.05 + 0.02 * min(1, (t - 37) / 20)
            add(music, pluck(midi(arp[k % 4])), t + 0.25 * k, g, pan=(0.35 if k % 2 else -0.35))
    if t >= 52:  # soft pulse on the half-note
        for k in range(4):
            add(music, soft_kick(), t + k * 1.0, 0.16)
    if t >= 68:  # high shimmer
        for n_ in chord[1:]:
            add(music, pad_voice(midi(n_ + 24), 4.0, attack=1.5, release=2.0, bright=5000), t, 0.018, pan=0.4)

# piano accents on scene changes
for t, n_ in ((29.0, 74), (37.0, 69), (52.0, 74), (59.6, 78), (68.8, 76), (76.0, 74)):
    add(music, piano(midi(n_), 4.0), t, 0.12, pan=-0.1)

# 83–90: resolve on D major, final piano
for i, n_ in enumerate(D_MAJ + [74]):
    add(music, pad_voice(midi(n_), 3.4, attack=0.4, release=3.4, bright=1600), 83.0, 0.08, pan=(-0.3 + 0.15 * i))
add(music, piano(midi(62), 6.5), 83.0, 0.18)
add(music, piano(midi(74), 6.5), 87.0, 0.10)

# --- simple stereo reverb (decaying noise impulse) -------------------------------------------
ir_len = int(2.6 * SR)
ti = np.arange(ir_len) / SR
ir = rng.normal(0, 1, (2, ir_len)) * np.exp(-ti * 2.4)
ir[:, : int(0.012 * SR)] = 0
for ch in range(2):
    wet = np.fft.irfft(np.fft.rfft(music[ch], N + ir_len) * np.fft.rfft(ir[ch], N + ir_len))[:N]
    music[ch] = music[ch] + 0.012 * wet

# fade the very end to silence
fade = np.ones(N)
fade[int(88.6 * SR):] = np.linspace(1, 0, N - int(88.6 * SR)) ** 2
music *= fade

music /= np.max(np.abs(music)) / 0.5  # peak -6 dBFS
pcm = (np.clip(music.T, -1, 1) * 32767).astype("<i2")
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", OUT)
