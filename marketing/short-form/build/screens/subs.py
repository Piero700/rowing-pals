# Builds fictional-club versions of the v4 artboards (dark theme). Every name, club and number is replaced.
import json, re, sys, os
V4=str(__import__('pathlib').Path(__file__).resolve().parents[4]/'docs/design/v4')+'/'; OUT=sys.argv[1]; os.makedirs(OUT, exist_ok=True)
CLUB=[('UEA Boat Club','Wexmoor UBC')]
PEOPLE=[('Piero Ciobanu','Rory Ellison'),('>PC<','>RE<'),('Tom Ashworth','Kit Mallory'),('>TA<','>KM<'),
        ('Ollie Hart','Sam Adeyemi'),('>OH<','>SA<'),('Dan Okafor','Josh Penrose'),('>DO<','>JP<'),
        ('Ben Carter','Theo Lindqvist'),('>BC<','>TL<'),('Alice Whitfield','Kit Mallory'),('>AW<','>KM<')]
def first(a,b): return (a,b,1)
V = {
 'Main': ('Main', [
   ('Sub-7 at last. New 2k PB.','Told you. Sub-6:30. New 2k PB.'),
   ('6:58.7','6:27.6'),('1:44.6','1:36.9'),('🎉 19','🎉 11'),('🔥 6</button>','🔥 4</button>'),('4 comments','7 comments'),
   ('rear camera photo',''),('front<br>camera','')]),
 'LogWorkout': ('LogWorkout', [('REAR CAMERA',''),('>FRONT<','><')]),
 'ReviewSession': ('ReviewSession', [
   ('16,000','2,000'),('1:04:50 · 2:01.6 /500m · 19 spm','6:27.6 · 1:36.9 /500m · 32 spm'),
   ('value="12000"','value="2000"'),('value="47:28.8"','value="6:27.6"'),('value="1:58.7"','value="1:36.9"'),('value="19 spm"','value="32 spm"')]),
 'VolBefore': ('RankingsVolume', [
   ('13,150m to move into #1','3,501m to move into #1'),
   ('71,400','64,900'),('58,250','61,400'),('55,900','55,200'),('47,300','48,600'),('39,800','41,300')]),
 'VolAfter': ('RankingsVolume', [
   ('You · #2','You · #1'),('13,150m to move into #1','You lead this group'),
   ('Group leader · Tom Ashworth · 71,400m','Group leader · You · 66,400m'),
   ('58,250','66,400',1),            # hero number
   ('Tom Ashworth','@@ROW1@@'),('>TA<','>RE<'),('71,400','66,400'),
   ('Piero Ciobanu','Kit Mallory'),('>PC<','>KM<'),('58,250','64,900'),
   ('var(--line);background:var(--brandSoft);"','var(--line);"'),('@@ROW1@@','Rory Ellison'),
   ('55,900','55,200'),('47,300','48,600'),('39,800','41,300')]),
 'PBHistory': ('PBHistory', [
   ('6:18.9','6:42.9'),('6:30.7','6:54.7'),('6:48.6','7:12.6'),('7:08.6','7:32.6'),
   ('>8:19<','>7:43<'),('>7:19<','>7:13<'),('>6:19<','>6:43<'),('>5:19<','>6:13<'),('>4:19<','>5:43<'),
   ('14 Aug 2026','22 Aug 2026'),('2 Jun 2026','6 Jun 2026'),('21 Mar 2026','18 Mar 2026'),('9 Jan 2026','12 Jan 2026')]),
 'Tests': ('RankingsTests', [
   ('6:12.4','6:31.2'),('You’re 6.5s behind','You’re 11.7s behind'),('17:12.4','17:48.3'),('6:18.9','6:42.9'),
   ('1:28.4','1:33.1'),('3:02.6','3:14.0'),('35:48.0','37:02.5'),('1,214m','1,148m'),('8,410m','7,960m'),('16,220m','15,410m'),('2:21.9','2:31.4')]),
}
for out,(src,subs) in V.items():
    h=open(V4+src+'.dc.html').read()
    dark=json.loads(re.search(r'const DARK = (\{.*?\});',h).group(1))
    h=re.sub(r'\{\{ t\.(\w+) \}\}',lambda m:dark[m.group(1)],h)
    h=re.sub(r'<script[\s\S]*?</script>','',h); h=re.sub(r'</?(x-dc|helmet)>','',h)
    for s in subs:
        a,b=s[0],s[1]; n=s[2] if len(s)>2 else -1
        if a not in h: print('MISSING',out,a)
        h=h.replace(a,b,n)
    if out=='PBHistory':
        pts=[(64,38.5),(145.4,70.1),(245.6,98.5),(342,117.2)]
        line=' '.join(('M' if i==0 else 'L')+f'{x} {y}' for i,(x,y) in enumerate(pts))
        h=re.sub(r'd="M64 41.6[^"]*Z"', f'd="{line} L342 212 L64 212 Z"', h)
        h=re.sub(r'd="M64 41.6[^"]*"', f'd="{line}"', h)
        h=re.sub(r'<circle cx="(?!342)[^>]*></circle>','',h)
        h=re.sub(r'(<circle cx="342" cy=")116.4', r'\g<1>117.2', h)
        h=h.replace('<line x1="342"','@@').replace('@@','<line x1="342"')
        circ=''.join(f'<circle cx="{x}" cy="{y}" r="4" fill="var(--card)" stroke="var(--brand)" stroke-width="2"></circle>' for x,y in pts[:-1])
        h=h.replace('<circle cx="342"', circ+'<circle cx="342"',1)
    for a,b in CLUB+PEOPLE: h=h.replace(a,b)
    h=h.replace('<head>','<head><style>body{background:#101114}</style>')
    open(f'{OUT}/{out}.html','w').write(h)
