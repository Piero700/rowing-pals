"""Builds the three Rowing Pals short-form video pages for the marketing-skill renderer.

Run: python3 build.py   (writes ../A-receipts.html, ../B-sunday-board.html, ../C-pb-line.html)
Render: node <plugin>/scripts/video/render.js <page> <out.mp4> --variants a,b,c

Every person, club and number on screen is fictional (Wexmoor UBC). The app screens are renders
of the v4 design artboards with that fictional data swapped in (see README.md).
"""
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE.parent
BASE = (HERE / 'base.css').read_text()

RP_CSS = """
  :root { --bg:#101114; --card:#1b1c21; --line:#464a56; --text:#f7f8fc; --muted:#bbc0ce;
          --accent:#91b8ff; --rec:#c6adff; --gold:#efc37c; --ok:#78d7ac; }
  .g1 { background:#1a3466; } .g2 { background:#35265a; }
  /* captions band: inside the safe area, above the phone */
  .capband { position:absolute; left:90px; right:150px; top:330px; height:220px; display:grid; align-items:end; justify-items:center; }
  .capband > * { grid-area:1/1; }
  .cap.brand > span { background:var(--accent); color:#09090b; }
  .cap.rec > span { background:var(--rec); color:#09090b; }
  .cap.gold > span { background:var(--gold); color:#09090b; }
  .cap { font-size:58px; }
  /* phone showing an app screen; .ui is the screen at its native 1179px width, scaled by --k */
  .phone { position:absolute; left:var(--x,130px); top:var(--y,570px); width:var(--w,820px); height:var(--h,810px);
           border-radius:58px; overflow:hidden; border:3px solid #2e313b; background:#101114;
           box-shadow:0 40px 120px rgba(0,0,0,.65), 0 0 0 10px rgba(255,255,255,.03);
           animation: phoneIn .5s cubic-bezier(.2,.8,.2,1) var(--in) both, fadeOut .3s ease-in var(--out,999s) forwards; }
  @keyframes phoneIn { from { opacity:0; transform:translateY(90px) scale(.96); } to { opacity:1; transform:none; } }
  .ui { position:absolute; left:0; top:0; width:1179px; transform-origin:0 0;
        animation: pan var(--pd,.8s) cubic-bezier(.5,0,.2,1) var(--pin,999s) both; }
  .ui2 { position:absolute; inset:0; animation: pan2 var(--pd2,.8s) cubic-bezier(.5,0,.2,1) var(--pin2,999s) both; }
  @keyframes pan  { from { transform:scale(var(--k)) translateY(var(--y0)); } to { transform:scale(var(--k)) translateY(var(--y1)); } }
  @keyframes pan2 { from { transform:translateY(0); } to { transform:translateY(var(--d2,0px)); } }
  .ui img.screen { display:block; width:1179px; }
  .ui .o { position:absolute; }
  /* highlight ring on part of the screen (native px) */
  .hl { position:absolute; border:9px solid var(--c,var(--accent)); border-radius:var(--r,44px);
        box-shadow:0 0 0 9999px rgba(8,9,12,.45), 0 0 60px var(--c,var(--accent));
        animation: hlIn .35s cubic-bezier(.2,.9,.3,1.2) var(--in) both, fadeOut .3s ease-in var(--out,999s) forwards; }
  @keyframes hlIn { from { opacity:0; transform:scale(1.15); } to { opacity:1; transform:none; } }
  /* a finger tap */
  .tap { position:absolute; width:150px; height:150px; margin:-75px 0 0 -75px; border-radius:50%;
         background:rgba(255,255,255,.55); border:6px solid #fff;
         animation: tapIn .55s ease-out var(--in) both; opacity:0; }
  @keyframes tapIn { 0% { opacity:0; transform:scale(1.6); } 35% { opacity:1; transform:scale(.8); } 100% { opacity:0; transform:scale(1.25); } }
  /* illustrated erg monitor (a drawing, not a photo) */
  .mon { position:absolute; background:linear-gradient(160deg,#3a3d45,#24262c); border-radius:36px; padding:34px;
         box-shadow:inset 0 3px 0 rgba(255,255,255,.12), 0 20px 50px rgba(0,0,0,.5); }
  .lcd { background:linear-gradient(170deg,#c7d1b6,#aebb9c); border-radius:18px; height:100%; padding:26px 34px;
         display:flex; flex-direction:column; justify-content:space-between; color:#1d231a;
         font-family:"Share Tech Mono","DejaVu Sans Mono",monospace; box-shadow:inset 0 4px 14px rgba(0,0,0,.25); }
  .lcd .row { display:flex; justify-content:space-between; align-items:baseline; }
  .lcd b { font-weight:400; font-size:var(--d,96px); letter-spacing:2px; line-height:1; }
  .lcd small { font-size:var(--l,36px); opacity:.75; }
  .face { position:absolute; display:grid; place-items:center; background:#1c1e25; border-radius:40px; font-size:150px; }
  .shine { position:absolute; inset:0; background:#fff; animation: flash .5s ease-out var(--in) both; pointer-events:none; }
  .floater { position:absolute; font-size:110px; animation: floatUp 1.6s ease-out var(--in) both; }
  @keyframes floatUp { 0% { opacity:0; transform:translateY(40px) scale(.5); } 20% { opacity:1; transform:translateY(0) scale(1.1); }
                       100% { opacity:0; transform:translateY(-420px) scale(1); } }
  .demo { position:absolute; left:90px; right:150px; top:1402px; text-align:center; font-size:28px; font-weight:600;
          color:#a3abba; letter-spacing:.5px; animation: fadeIn .3s ease-out var(--in) both, fadeOut .3s ease-in var(--out,999s) forwards; }
  .demo.now { animation: fadeOut .3s ease-in var(--out,999s) forwards; }
  /* hook */
  .hook { font-size:112px; font-weight:800; line-height:1.04; letter-spacing:-3px; text-wrap:balance; }
  .hook em { font-style:normal; color:var(--accent); }
  .hook .rec { color:var(--rec); } .hook .gold { color:var(--gold); }
  /* end card */
  .end img { width:300px; height:300px; border-radius:68px; box-shadow:0 30px 80px rgba(0,0,0,.6);
             animation: popIn .55s cubic-bezier(.2,.9,.3,1.25) var(--in) both; }
  .pill { display:inline-block; margin-top:34px; padding:22px 44px; border-radius:999px; background:var(--accent); color:#09090b;
          font-size:46px; font-weight:800; }
  .chat-head .av { background:linear-gradient(135deg,#91b8ff,#35265a); }
"""

HEAD = """<!doctype html>
<!-- Rowing Pals short-form video, built by build/build.py. Fictional club and data throughout. -->
<html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800&family=Share+Tech+Mono&family=TikTok+Sans:wght@500..900&family=Noto+Color+Emoji&display=block">
<style>
""" + BASE + RP_CSS + "\n</style></head>\n"

MUSIC = 'data-music="house" data-bpm="124" data-key="A" data-mode="minor" data-energy="4" data-motif="1 3 5 3 | 6 5 3 1"'


def monitor(left, top, w, h, time, dist, split, rate, d=96, l=36, pad=34):
    return (f'<div class="o mon" style="left:{left}px;top:{top}px;width:{w}px;height:{h}px;padding:{pad}px">'
            f'<div class="lcd" style="--d:{d}px;--l:{l}px">'
            f'<div class="row"><small>time</small><b>{time}</b></div>'
            f'<div class="row"><small>meters</small><b>{dist}</b></div>'
            f'<div class="row"><small>/500m</small><b>{split}</b></div>'
            f'<div class="row"><small>s/m</small><b>{rate}</b></div></div></div>')


def endcard(t, line, sub):
    return f'''
  <div class="scene center end" style="--out:999s">
    <img class="now" src="assets/icon.png" alt="" style="--in:{t}s;animation:popIn .55s cubic-bezier(.2,.9,.3,1.25) {t}s both" data-sfx="chime">
    <div class="big rise" style="--in:{t+.25}s;margin-top:40px">Rowing Pals</div>
    <div class="mid rise" style="--in:{t+.5}s;margin-top:14px;color:var(--muted);font-size:54px">{line}</div>
    <div class="rise" style="--in:{t+.8}s"><span class="pill">{sub}</span></div>
  </div>'''


def page(name, duration, drop, body):
    html = HEAD + f'<body class="fyp" data-duration="{duration}" data-drop="{drop}" {MUSIC}>\n  <div class="glow g1"></div><div class="glow g2"></div>\n' + body + '\n</body></html>\n'
    (OUT / name).write_text(html)
    print('wrote', OUT / name)


# ---------------------------------------------------------------- A: receipts
A = '''
  <!-- 0–2.6s: hook, three variants -->
  <div class="scene center" style="--out:2.55s">
    <div class="hook now" data-variant="a">pov: your mate says he pulled a <em>6:27</em> 2k</div>
    <div class="hook now" data-variant="b">“trust me, it was a <em>6:27</em>” 🙄</div>
    <div class="hook now" data-variant="c">2k score, or it <em>didn’t happen?</em></div>
  </div>

  <!-- 2.6–6.4s: the group chat (fictional) -->
  <div class="scene" style="--out:6.35s" data-sfx="whoosh:out">
    <div class="chat rise" style="--in:2.6s">
      <div class="chat-head"><i class="av">🚣</i><div><b>Senior squad</b><small>Kit, Sam, Josh, you</small></div></div>
      <div class="chat-body">
        <div class="msg them"><div class="bub" style="--in:2.9s" data-sfx="ping">Kit: just pulled 6:27.6 on the 2k 😤</div></div>
        <div class="msg me"><div class="bub" style="--in:3.9s" data-sfx="ping">pics or it didn’t happen</div></div>
        <div class="msg them"><div class="typing" style="--in:4.5s;--out:5.3s"><i></i><i></i><i></i></div><div class="bub" style="--in:5.3s" data-sfx="rimshot">phone died 🫠</div></div>
      </div>
    </div>
  </div>

  <!-- 6.4–10.6s: Log workout, two photos in one tap -->
  <div class="capband" style="--out:10.55s">
    <div class="cap swap" style="--in:6.45s;--out:8.7s"><span>next session, he logs it on Rowing Pals</span></div>
    <div class="cap brand swap" style="--in:8.8s;--out:10.5s"><span>monitor + face. one tap.</span></div>
  </div>
  <div class="phone" style="--in:6.4s;--out:10.55s">
    <div class="ui" style="--k:.6955;--y0:-330px;--y1:-1560px;--pin:7.9s;--pd:.8s">
      <img class="screen" src="assets/LogWorkout.png" alt="">
      ''' + monitor(100, 700, 690, 640, '6:27.6', '2000', '1:36.9', '32') + '''
      <div class="face" style="left:822px;top:384px;width:272px;height:462px">😤</div>
      <div class="tap" style="left:590px;top:2396px;--in:8.75s" data-sfx="shutter"></div>
    </div>
    <div class="shine" style="--in:8.95s"></div>
  </div>

  <!-- 10.6–14.6s: Review, the numbers are read off the photo -->
  <div class="capband" style="--out:14.55s">
    <div class="cap swap" style="--in:10.65s;--out:12.7s"><span>the numbers get read off the photo</span></div>
    <div class="cap swap" style="--in:12.8s;--out:14.5s"><span>he just confirms the stroke rate</span></div>
  </div>
  <div class="phone" style="--in:10.6s;--out:14.55s">
    <div class="ui" style="--k:.6955;--y0:-250px;--y1:-250px">
      <img class="screen" src="assets/ReviewSession.png" alt="">
      <div class="hl" style="left:36px;top:895px;width:1110px;height:452px;--in:11.3s;--out:12.75s" data-sfx="pop"></div>
      <div class="hl" style="left:604px;top:1166px;width:542px;height:181px;--r:999px;--in:12.85s"></div>
      <div class="tap" style="left:992px;top:1255px;--in:13.5s" data-sfx="click"></div>
    </div>
  </div>

  <!-- 14.6–19s: the post on the club feed -->
  <div class="capband" style="--out:18.95s">
    <div class="cap brand swap" style="--in:14.65s;--out:18.9s"><span>receipts. posted to the club 🧾</span></div>
  </div>
  <div class="phone" style="--in:14.6s;--out:18.95s">
    <div class="ui" style="--k:.6955;--y0:-640px;--y1:-1150px;--pin:15.9s;--pd:1.1s">
      <img class="screen" src="assets/Main.png" alt="">
      ''' + monitor(150, 905, 600, 640, '6:27.6', '2000', '1:36.9', '32', d=74, l=28, pad=24) + '''
      <div class="face" style="left:787px;top:896px;width:256px;height:262px;font-size:130px">😤</div>
      <div class="hl" style="left:108px;top:2132px;width:550px;height:146px;--r:999px;--in:17.1s" data-sfx="pop"></div>
    </div>
    <div class="floater" style="left:120px;top:560px;--in:17.3s">🎉</div>
    <div class="floater" style="left:330px;top:600px;--in:17.6s">🔥</div>
    <div class="floater" style="left:520px;top:580px;--in:17.9s">🎉</div>
  </div>
  <div class="demo" style="--in:6.4s;--out:18.95s">Demo club · fictional rowers and data</div>
''' + endcard(19.0, 'post the monitor, not the story', 'Coming soon to iPhone')

# ---------------------------------------------------------------- B: sunday board
B = '''
  <div class="scene center" style="--out:2.55s">
    <div class="hook now" data-variant="a">pov: it’s sunday, 9:47pm and you’re <span class="gold">#2</span></div>
    <div class="hook now" data-variant="b"><em>3,501m</em> between you and #1. it’s sunday night.</div>
    <div class="hook now" data-variant="c">rowers who check the club board before bed:</div>
  </div>

  <!-- 2.6–7s: the board before -->
  <div class="capband" style="--out:6.95s">
    <div class="cap gold swap" style="--in:2.65s;--out:4.9s"><span>kit’s held the crown all week 👑</span></div>
    <div class="cap swap" style="--in:5.0s;--out:6.9s"><span>the gap: 3,501m</span></div>
  </div>
  <div class="phone" style="--in:2.6s;--out:6.95s">
    <div class="ui" style="--k:.6955;--y0:-560px;--y1:-560px">
      <img class="screen" src="assets/VolBefore.png" alt="">
      <div class="hl" style="left:52px;top:1436px;width:1078px;height:216px;--r:12px;--c:var(--gold);--in:3.2s;--out:4.95s" data-sfx="pop"></div>
      <div class="hl" style="left:80px;top:1010px;width:640px;height:84px;--r:24px;--in:5.05s" data-sfx="pop"></div>
    </div>
  </div>

  <!-- 7–11s: one 'easy' 5k (illustrated monitor) -->
  <div class="capband" style="--out:10.95s">
    <div class="cap swap" style="--in:7.05s;--out:10.9s"><span>one “easy” 5k later…</span></div>
  </div>
  <div class="scene" style="--out:10.95s;top:600px">
    <div class="rise" style="--in:7.0s;position:relative;height:640px">
      <div class="mon" style="position:absolute;inset:0;padding:30px">
        <div class="lcd" style="--d:104px;--l:38px">
          <div class="row"><small>time</small><b>19:58.4</b></div>
          <div class="row"><small>meters</small><b><span class="count" style="--in:7.5s;--to:5000;--for:2.4s"></span></b></div>
          <div class="row"><small>/500m</small><b>1:59.8</b></div>
          <div class="row"><small>s/m</small><b>22</b></div>
        </div>
      </div>
    </div>
  </div>

  <!-- 11–16.4s: the board after -->
  <div class="capband" style="--out:16.35s">
    <div class="cap gold swap" style="--in:11.05s;--out:14.0s"><span>crown stolen. 66,400m 👑</span></div>
    <div class="cap swap" style="--in:14.1s;--out:16.3s"><span>kit has 7 days to reply 😈</span></div>
  </div>
  <div class="phone" style="--in:11.0s;--out:16.35s">
    <div class="ui" style="--k:.6955;--y0:-560px;--y1:-560px">
      <img class="screen" src="assets/VolAfter.png" alt="">
      <div class="hl" style="left:52px;top:1436px;width:1078px;height:216px;--r:12px;--c:var(--gold);--in:11.9s" data-sfx="boom"></div>
    </div>
  </div>
  <div class="demo" style="--in:2.6s;--out:16.35s">Demo club · fictional rowers and data</div>
''' + endcard(16.4, 'weekly erg boards for your club', 'Coming soon to iPhone')

# ---------------------------------------------------------------- C: PB line
C = '''
  <div class="scene center" style="--out:2.55s">
    <div class="hook now" data-variant="a"><span class="rec">7:32.6 → 6:42.9</span><br>one 2k at a time</div>
    <div class="hook now" data-variant="b">can you remember your <em>first</em> 2k time?</div>
    <div class="hook now" data-variant="c">every 2k PB you’ve pulled. <em>one line.</em></div>
  </div>
  <div class="demo now" style="--out:16.35s">Demo rower · fictional data</div>

  <!-- 2.6–8.6s: the PB chart, then the card -->
  <div class="capband" style="--out:8.55s">
    <div class="cap swap" style="--in:2.65s;--out:4.45s"><span>january: 7:32.6</span></div>
    <div class="cap swap" style="--in:4.55s;--out:6.25s"><span>august: 6:42.9</span></div>
    <div class="cap rec swap" style="--in:6.35s;--out:8.5s"><span>49.7 seconds faster 💜</span></div>
  </div>
  <div class="phone" style="--in:2.6s;--out:8.55s">
    <div class="ui" style="--k:.6955;--y0:-1590px;--y1:-900px;--pin:6.0s;--pd:.7s">
      <img class="screen" src="assets/PBHistory-tall.png" alt="">
      <div class="hl" style="left:212px;top:1926px;width:100px;height:100px;--r:999px;--in:3.0s;--out:4.5s" data-sfx="pop"></div>
      <div class="hl" style="left:993px;top:2145px;width:110px;height:110px;--r:999px;--in:4.9s;--out:6.0s" data-sfx="pop"></div>
      <div class="hl" style="left:790px;top:1098px;width:292px;height:116px;--r:999px;--c:var(--rec);--in:6.7s" data-sfx="ding"></div>
    </div>
  </div>

  <!-- 8.6–12.6s: the dated list -->
  <div class="capband" style="--out:12.55s">
    <div class="cap swap" style="--in:8.65s;--out:12.5s"><span>every PB, dated and kept</span></div>
  </div>
  <div class="phone" style="--in:8.6s;--out:12.55s">
    <div class="ui" style="--k:.6955;--y0:-2600px;--y1:-2900px;--pin:9.4s;--pd:1.4s">
      <img class="screen" src="assets/PBHistory-tall.png" alt="">
    </div>
  </div>

  <!-- 12.6–16.4s: best in your group -->
  <div class="capband" style="--out:16.35s">
    <div class="cap swap" style="--in:12.65s;--out:14.5s"><span>and the next target?</span></div>
    <div class="cap gold swap" style="--in:14.6s;--out:16.3s"><span>11.7s to catch kit 👀</span></div>
  </div>
  <div class="phone" style="--in:12.6s;--out:16.35s">
    <div class="ui" style="--k:.6955;--y0:-300px;--y1:-300px">
      <img class="screen" src="assets/Tests-tall.png" alt="">
      <div class="hl" style="left:44px;top:622px;width:540px;height:438px;--r:44px;--c:var(--gold);--in:14.6s" data-sfx="pop"></div>
    </div>
  </div>
''' + endcard(16.4, 'watch your 2k come down', 'Coming soon to iPhone')

page('A-receipts.html', 22.5, 2.6, A)
page('B-sunday-board.html', 20.0, 2.6, B)
page('C-pb-line.html', 20.0, 2.6, C)
