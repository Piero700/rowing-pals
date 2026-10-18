"""Writes out/<video>-<variant>.srt: the on-screen text as captions (for YouTube / accessibility)."""
from pathlib import Path
HOOKS = {
 'A-receipts': {'a': 'pov: your mate says he pulled a 6:27 2k', 'b': '“trust me, it was a 6:27” 🙄', 'c': '2k score, or it didn’t happen?'},
 'B-sunday-board': {'a': 'pov: it’s sunday, 9:47pm and you’re #2', 'b': '3,501m between you and #1. it’s sunday night.', 'c': 'rowers who check the club board before bed:'},
 'C-pb-line': {'a': '7:32.6 → 6:42.9, one 2k at a time', 'b': 'can you remember your first 2k time?', 'c': 'every 2k PB you’ve pulled. one line.'},
}
BODY = {
 'A-receipts': [(2.9, 3.9, 'Kit: just pulled 6:27.6 on the 2k 😤'), (3.9, 5.3, 'you: pics or it didn’t happen'), (5.3, 6.4, 'Kit: phone died 🫠'),
                (6.45, 8.7, 'next session, he logs it on Rowing Pals'), (8.8, 10.5, 'monitor + face. one tap.'),
                (10.65, 12.7, 'the numbers get read off the photo'), (12.8, 14.5, 'he just confirms the stroke rate'),
                (14.65, 18.9, 'receipts. posted to the club 🧾'), (19.0, 22.5, 'Rowing Pals: post the monitor, not the story. Coming soon to iPhone.')],
 'B-sunday-board': [(2.65, 4.9, 'kit’s held the crown all week 👑'), (5.0, 6.9, 'the gap: 3,501m'), (7.05, 10.9, 'one “easy” 5k later…'),
                    (11.05, 14.0, 'crown stolen. 66,400m 👑'), (14.1, 16.3, 'kit has 7 days to reply 😈'),
                    (16.4, 20.0, 'Rowing Pals: weekly erg boards for your club. Coming soon to iPhone.')],
 'C-pb-line': [(2.65, 4.45, 'january: 7:32.6'), (4.55, 6.25, 'august: 6:42.9'), (6.35, 8.5, '49.7 seconds faster 💜'),
               (8.65, 12.5, 'every PB, dated and kept'), (12.65, 14.5, 'and the next target?'), (14.6, 16.3, '11.7s to catch kit 👀'),
               (16.4, 20.0, 'Rowing Pals: watch your 2k come down. Coming soon to iPhone.')],
}
def ts(t): h, r = divmod(t, 3600); m, s = divmod(r, 60); return f"{int(h):02}:{int(m):02}:{int(s):02},{int(round((s % 1) * 1000)):03}"
out = Path(__file__).parent.parent / 'out'; out.mkdir(exist_ok=True)
for v, hooks in HOOKS.items():
    for k, hook in hooks.items():
        cues = [(0.0, 2.55, hook)] + BODY[v]
        (out / f'{v}-{k}.srt').write_text(''.join(f"{i}\n{ts(a)} --> {ts(b)}\n{t}\n\n" for i, (a, b, t) in enumerate(cues, 1)))
print('ok')
