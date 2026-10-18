"""Writes POSTING.md: per-video, per-platform captions with character counts."""
from pathlib import Path
V = [
 ("A-receipts", "Receipts", {
   "yt_title": "When your mate’s 2k is a 6:27 “trust me” 🙄 #Shorts",
   "yt_desc": "Rowing Pals posts an erg session as two photos taken in one tap: the monitor and you. The numbers are read straight off the photo. Coming soon to iPhone. Follow for launch.\n\nDemo club, fictional rowers and data.\n\n#Shorts #rowing #erg #2ktest",
   "ig": "Tag the mate whose 2k always happens off camera 🧾\nRowing Pals: monitor + face, one tap, posted to your club. Coming soon to iPhone, follow for launch.\n(Demo club, fictional rowers and data.)",
   "tt": "pics or it didn’t happen 🧾 tag the mate whose 2k always happens off camera. Rowing Pals, coming soon to iPhone. (demo club, fictional data)",
   "tags": "#rowing #erg #2ktest #indoorrowing #ukrowing"}),
 ("B-sunday-board", "Sunday night board", {
   "yt_title": "3,501m from #1 on the club board. It’s Sunday night. #Shorts",
   "yt_desc": "Weekly erg volume boards for your own club, split by gender and novice/senior. Rowing Pals, coming soon to iPhone. Follow for launch.\n\nDemo club, fictional rowers and data.\n\n#Shorts #rowing #erg #indoorrowing",
   "ig": "Tag your Kit. They’ve got 7 days 😈\nRowing Pals keeps a weekly volume board for your club, not the whole world. Coming soon to iPhone, follow for launch.\n(Demo club, fictional rowers and data.)",
   "tt": "tag your kit. they’ve got 7 days 😈 weekly erg boards for your club on Rowing Pals, coming soon to iPhone. (demo club, fictional data)",
   "tags": "#rowing #erg #indoorrowing #rowingclub #ukrowing"}),
 ("C-pb-line", "The PB line", {
   "yt_title": "Every 2k PB on one line. What was your first? #Shorts",
   "yt_desc": "Rowing Pals keeps every test PB, dated, on one progression line, plus the best in your group to chase next. Coming soon to iPhone. Follow for launch.\n\nDemo rower, fictional data.\n\n#Shorts #rowing #2ktest #erg",
   "ig": "What was your first 2k? Drop it below 👇\nRowing Pals keeps every PB, dated, on one line, and shows who to chase next in your club. Coming soon to iPhone, follow for launch.\n(Demo rower, fictional data.)",
   "tt": "what was your first 2k? 👇 every PB on one line with Rowing Pals, coming soon to iPhone. (demo rower, fictional data)",
   "tags": "#rowing #2ktest #erg #indoorrowing #novicerowing"}),
]
out = ["# Posting copy\n",
 "Character counts are shown for every limited field (YouTube title ≤100, description ≤5,000; Instagram and TikTok captions ≤2,200). Hashtags: 3–5 per platform. Every caption keeps the \"fictional\" note: the videos use a demo club.\n",
 "**Posting windows (general benchmark guidance, not your analytics).** YouTube Shorts: Tue–Thu, 11:00–16:00. Reels: 06:00–09:00 or 19:00–23:00. TikTok: evening, when your audience is online. For UK student rowers, try 19:00–22:00 UK time, after evening outings. Stagger platforms by an hour or two rather than posting all three at once. Once each account has history, its own analytics override this.\n",
 "**Sound.** Each MP4 carries an original house track (124 BPM, A minor) generated locally, with no licence needed. To use a trending sound instead, add it in the app at posting time, at low volume under the original, or replace the original. This copy can't see what is trending this week.\n"]
for f, name, c in V:
    out.append(f"\n## {name} (`{f}-a/b/c.mp4`)\n")
    t = c['yt_title']; out.append(f"### YouTube Shorts\n- **Title** ({len(t)}/100): {t}\n- **Description** ({len(c['yt_desc'])}/5,000):\n\n```\n{c['yt_desc']}\n```\n")
    ig = c['ig'] + "\n" + c['tags']; out.append(f"### Instagram Reels\n- **Caption** ({len(ig)}/2,200). The first line is the hook shown before \"more\":\n\n```\n{ig}\n```\n")
    tt = c['tt'] + " " + c['tags']; out.append(f"### TikTok\n- **Caption** ({len(tt)}/2,200):\n\n```\n{tt}\n```\n")
    out.append(f"- **Cover:** frame 0 (the hook), `out/{f}-<variant>-cover.png`. Pick it in each app's cover picker.\n")
Path(__file__).parent.parent.joinpath("POSTING.md").write_text("\n".join(out))
