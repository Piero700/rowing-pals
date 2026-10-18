"""Mixes narration, score and SFX for the launch film.

Inputs:  voice/timeline.json (narration lines and where each lands), audio/score.wav,
         remotion/src/timeline.json (SFX cues), remotion/public/sfx/*.mp3
Outputs: remotion/public/audio/mix.wav          voice + score + SFX, -14 LUFS integrated, -1.5 dBTP
         remotion/public/audio/mix-nomusic.wav  voice + SFX at exactly the same gain (for your own music)
The score is ducked by 9 dB under every narration line (0.25 s attack, 0.6 s release).
"""
import json
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SR = 48000
DUR = 90.0
N = int(SR * DUR)


def read_any(path, channels):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le", "-ac", str(channels),
                          "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, "<i2").astype(np.float64).reshape(-1, channels).T / 32768


def place(buf, sig, t, gain_db=0.0):
    i = int(round(t * SR))
    sig = sig[:, : max(0, N - i)]
    buf[:, i:i + sig.shape[1]] += sig * 10 ** (gain_db / 20)


voice_tl = json.loads((ROOT / "voice/timeline.json").read_text())
cues = json.loads((ROOT / "remotion/src/timeline.json").read_text())["cues"]

voice = np.zeros((2, N))
active = np.zeros(N)
for line in voice_tl["lines"]:
    clip = read_any(ROOT / line["clip"], 1)
    clip = np.vstack([clip[0], clip[0]])
    start = line["at"] - line["startPad"]
    place(voice, clip, start)
    a, b = int(line["at"] * SR), int((start + line["clipDur"]) * SR)
    active[a:b] = 1

# ducking envelope: smooth the voice-activity gate
duck_db = -9.0
env = np.zeros(N)
att, rel = 1 / (0.25 * SR), 1 / (0.6 * SR)
level = 0.0
for i in range(0, N, 48):  # control rate: 1 ms
    target = active[i]
    level += (target - level) * (att * 48 if target > level else rel * 48)
    env[i:i + 48] = level
music_gain = 10 ** (duck_db * env / 20)

score = read_any(ROOT / "audio/score.wav", 2)[:, :N]
music = score * music_gain

sfx = np.zeros((2, N))
for c in cues:
    s = read_any(ROOT / f"remotion/public/sfx/{c['sfx']}.mp3", 2)
    place(sfx, s, c["t"], c["db"])

full = voice + music + sfx
nomusic = voice + sfx


def lufs(x):
    tmp = ROOT / "audio/_tmp.wav"
    write(tmp, x)
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(tmp), "-af", "ebur128=peak=true",
                          "-f", "null", "-"], capture_output=True, text=True).stderr
    tmp.unlink()
    summary = out[out.rfind("Summary:"):]
    i = float(summary.split("I:")[1].split("LUFS")[0])
    peak = float(summary.split("Peak:")[1].split("dBFS")[0])
    return i, peak


def write(path, x):
    pcm = (np.clip(x.T, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


out_dir = ROOT / "remotion/public/audio"
out_dir.mkdir(parents=True, exist_ok=True)
raw_full, raw_nomusic = ROOT / "audio/_full.wav", ROOT / "audio/_nomusic.wav"
write(raw_full, full)
write(raw_nomusic, nomusic)


def master(src, dst, gain_db):
    """Gentle bus compression, gain, then a true-peak limiter at -1.5 dBTP."""
    chain = (f"acompressor=threshold=-20dB:ratio=2.5:attack=8:release=150,volume={gain_db}dB,"
             "alimiter=limit=0.84:attack=3:release=60:level=disabled")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-af", chain, "-ar", str(SR), str(dst)], check=True)


def measure(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true",
                          "-f", "null", "-"], capture_output=True, text=True).stderr
    summary = out[out.rfind("Summary:"):]
    return float(summary.split("I:")[1].split("LUFS")[0]), float(summary.split("Peak:")[1].split("dBFS")[0])


g = 8.0
for _ in range(4):  # converge on -14 LUFS
    master(raw_full, out_dir / "mix.wav", g)
    i, peak = measure(out_dir / "mix.wav")
    if abs(i + 14) < 0.3:
        break
    g += -14 - i
master(raw_nomusic, out_dir / "mix-nomusic.wav", g)
raw_full.unlink()
raw_nomusic.unlink()
print("gain", round(g, 2), "dB | full:", measure(out_dir / "mix.wav"), "| no-music:", measure(out_dir / "mix-nomusic.wav"))
