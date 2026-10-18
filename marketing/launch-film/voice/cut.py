"""Cuts each narration line out of the chosen take (voice/takeB.mp3) using voice/timeline.json.

For each line: src = [first word start, last word end] in the take (from ElevenLabs Scribe word timings),
at = where its first word lands in the film. Writes voice/lines/lineNN.wav and records clipDur / startPad.
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
tl = json.loads((ROOT / "voice/timeline.json").read_text())
lines = tl["lines"]
for i, line in enumerate(lines):
    s, e = line["src"]
    nxt = lines[i + 1]["src"][0] if i + 1 < len(lines) else 1e9
    a = max(0.0, s - 0.12 if line["id"] != 13 else s - 0.36)  # line 13 starts softly; give it more lead-in
    b = min(e + 0.35, nxt - 0.1)
    out = ROOT / "voice/lines" / f"line{line['id']:02d}.wav"
    out.parent.mkdir(exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(a), "-to", str(b), "-i", str(ROOT / tl["source"]),
                    "-af", "afade=t=in:d=0.02,areverse,afade=t=in:d=0.12,areverse", "-ar", "48000", "-ac", "1", str(out)], check=True)
    dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(out)]))
    line.update(clip=str(out.relative_to(ROOT)), clipDur=round(dur, 3), startPad=round(s - a, 3))
(ROOT / "voice/timeline.json").write_text(json.dumps(tl, indent=1))
print("cut", len(lines), "lines")
