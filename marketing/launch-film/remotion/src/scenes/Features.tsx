import React from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame} from 'remotion';
import {APPFONT, C, FPS, INTER, easeInOut, easeOut, ip, sceneFade} from '../lib/theme';
import {Phone, phoneGeom} from '../lib/Phone';
import {PostPhoto} from '../lib/PostPhoto';
import {Label} from '../lib/Atmos';
import screens from '../screens.json';

const B = screens.boxes as Record<string, Record<string, number[]>>;
const PW = 500;
const PG = phoneGeom(PW);
const PLEFT = 1120;
const PTOP = (1080 - PG.height) / 2;

const Ring: React.FC<{box: number[]; color: string; o: number; r?: number; pad?: number}> = ({box, color, o, r = 66, pad = 10}) => (
  <div style={{position: 'absolute', left: box[0] - pad, top: box[1] - pad, width: box[2] + pad * 2, height: box[3] + pad * 2,
    borderRadius: r + pad, border: `9px solid ${color}`, opacity: o, boxShadow: `0 0 50px ${color}66`}} />
);

/** A push-in: from [in0,in1] the camera moves to `z` around a point of the phone (phone-local px), and back out by [out0,out1]. */
type Push = {in: [number, number]; out?: [number, number]; z: number; y: number};
const pushZ = (t: number, p?: Push) => (p ? 1 + (p.z - 1) * Math.min(ip(t, p.in, [0, 1], easeInOut), p.out ? ip(t, p.out, [1, 0], easeInOut) : 1) : 1);
/** Phone-local y of a screen-space point, for a given viewTop. */
const localY = (srcY: number, viewTop: number) => PG.bezel + (srcY - viewTop) * PG.k;

const PhoneSlot: React.FC<{t: number; a: number; b: number; children: React.ReactNode; zoom?: number; push?: Push}> = ({t, a, b, children, zoom = 1, push}) => {
  const k = ip(t, [a, a + 1.0], [0, 1], easeOut);
  const out = ip(t, [b - 0.5, b], [0, 1], easeInOut);
  const z = zoom * pushZ(t, push);
  return (
    <div style={{position: 'absolute', left: PLEFT, top: PTOP, opacity: k * (1 - out),
      transform: `translateY(${(1 - k) * 70 - out * 30}px) scale(${z})`, transformOrigin: `50% ${push ? push.y : PG.height * 0.4}px`}}>
      {children}
    </div>
  );
};

// ---------------------------------------------------------------------------------------------
export const FeedScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 51.2 || t > 59.8) return null;
  const a = 51.6, b = 59.5;
  const [rx, ry, rw, rh] = B.Main.react;
  const pop = ip(t, [54.9, 55.05], [0, 1]) * ip(t, [55.05, 55.4], [1, 0]);
  const count = t >= 54.95 ? 13 : 12;
  const push = ip(t, [56.0, 56.7], [0, 1], easeInOut);
  return (
    <AbsoluteFill style={{fontFamily: INTER}}>
      <Label title="Club feed" line="Your crew reacts, comments and celebrates every new personal best." opacity={sceneFade(t, a + 0.3, b, 0.8, 0.5)} />
      <PhoneSlot t={t} a={a} b={b} push={{in: [53.8, 54.8], out: [55.9, 56.6], z: 1.5, y: localY(2192, 650)}}>
        <Phone screen="Main" width={PW} viewTop={ip(t, [52.0, 56.0], [420, 700], easeInOut)} nav navH={300}
          next={{screen: 'PostDetail', viewTop: ip(t, [56.0, 59.5], [1818, 1700], easeInOut), p: push}}>
          <PostPhoto /><PostPhoto which="photo2" />
          {/* a reaction lands: 12 → 13 */}
          <div style={{position: 'absolute', left: rx, top: ry, width: rw, height: rh, borderRadius: 60, background: '#24262d',
            border: '3px solid rgba(255,255,255,.16)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12,
            fontFamily: APPFONT, fontSize: 40, fontWeight: 600, color: C.ink, transform: `scale(${1 + pop * 0.14})`,
            opacity: t >= 54.85 ? 1 : 0}}>
            <span>🎉</span><span style={{fontVariantNumeric: 'tabular-nums'}}>{count}</span>
          </div>
          <div style={{position: 'absolute', left: rx + 30, top: ry - 40 - ip(t, [54.95, 56.0], [0, 260], easeOut), fontSize: 90,
            opacity: ip(t, [54.95, 55.1], [0, 1]) * ip(t, [55.5, 56.0], [1, 0])}}>🎉</div>
          <Ring box={B.Main.comments} color={C.brand} o={ip(t, [55.3, 55.5], [0, 1]) * ip(t, [55.9, 56.2], [1, 0])} r={60} />
        </Phone>
      </PhoneSlot>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------------------------------------
const PTS: [number, number][] = [[64, 38.5], [145.4, 70.1], [245.6, 98.5], [342, 117.2]];

const PBLine: React.FC<{p: number}> = ({p}) => {
  const [x, y, w, h] = B.PBHistoryLine.chart;
  const segs = PTS.slice(1).map((q, i) => Math.hypot(q[0] - PTS[i][0], q[1] - PTS[i][1]));
  const total = segs.reduce((s, v) => s + v, 0);
  const d = PTS.map((q, i) => `${i ? 'L' : 'M'}${q[0]} ${q[1]}`).join(' ');
  const reach = p * total;
  let acc = 0;
  const shown = PTS.map((_, i) => {
    if (i === 0) return true;
    acc += segs[i - 1];
    return reach >= acc - 0.5;
  });
  const fillX = 64 + (342 - 64) * p;
  return (
    <svg viewBox="0 0 360 252" style={{position: 'absolute', left: x, top: y, width: w, height: h, overflow: 'visible'}}>
      <clipPath id="pbclip"><rect x="0" y="0" width={fillX} height="252" /></clipPath>
      <path d={`${d} L342 212 L64 212 Z`} fill="rgba(145,184,255,.14)" clipPath="url(#pbclip)" />
      <path d={d} fill="none" stroke={C.brand} strokeWidth="3" strokeDasharray={total} strokeDashoffset={total - reach} strokeLinecap="round" />
      {PTS.map((q, i) => (shown[i] ? (
        <circle key={i} cx={q[0]} cy={q[1]} r={i === 3 ? 6 : 4} fill={i === 3 ? C.brand : C.card} stroke={C.brand} strokeWidth="2" />
      ) : null))}
    </svg>
  );
};

export const PBScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 58.9 || t > 68.9) return null;
  const a = 59.3, b = 68.6;
  const push = ip(t, [65.3, 66.0], [0, 1], easeInOut);
  return (
    <AbsoluteFill style={{fontFamily: INTER}}>
      <Label title="Personal bests" line="Every test, dated and kept. Plus a prediction for today from your recent training." opacity={sceneFade(t, a + 0.3, b, 0.8, 0.5)} />
      <PhoneSlot t={t} a={a} b={b} push={{in: [61.6, 62.6], out: [64.9, 65.4], z: 1.4, y: localY(2050, 950)}}>
        <Phone screen="PBHistoryLine" width={PW} viewTop={ip(t, [59.6, 65.3], [860, 980], easeInOut)}
          next={{screen: 'Profile', viewTop: 1640, p: push,
            children: <Ring box={B.Profile.pred2k} color={C.records} o={ip(t, [66.3, 66.6], [0, 1]) * ip(t, [68.0, 68.5], [1, 0])} r={66} />}}>
          <PBLine p={ip(t, [62.6, 64.6], [0, 1], easeInOut)} />
          <Ring box={B.PBHistoryLine.faster} color={C.records} o={ip(t, [64.7, 64.9], [0, 1]) * ip(t, [65.25, 65.5], [1, 0])} r={46} />
        </Phone>
      </PhoneSlot>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------------------------------------
const Strip: React.FC<{src: string; box: number[]; toY: number}> = ({src, box, toY}) => (
  <div style={{position: 'absolute', left: box[0], top: toY, width: box[2], height: box[3], overflow: 'hidden'}}>
    <Img src={staticFile(`screens/${src}.png`)} style={{position: 'absolute', left: -box[0], top: -box[1], width: 1179}} />
  </div>
);

export const RankingsScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 68.0 || t > 76.1) return null;
  const a = 68.4, b = 75.8;
  const up = 73.8;
  const after = t >= up;
  const m = ip(t, [up + 0.15, up + 0.85], [0, 1], easeInOut);
  const r1 = B.VolBefore.row1;
  const r2 = B.VolBefore.row2;
  const zoom = ip(t, [69.0, 73.0], [1, 1.06], easeInOut);
  return (
    <AbsoluteFill style={{fontFamily: INTER}}>
      <Label title="Rankings" line="Weekly volume and test results, within your own group in your club." opacity={sceneFade(t, a + 0.3, b, 0.8, 0.5)} />
      <PhoneSlot t={t} a={a} b={b} zoom={zoom} push={{in: [70.6, 71.8], z: 1.45, y: localY(1150, 330)}}>
        <Phone screen={after ? 'VolAfter' : 'VolBefore'} width={PW} viewTop={330}>
          <Ring box={B.VolBefore.gap} color={C.records} o={ip(t, [72.4, 72.7], [0, 1]) * ip(t, [73.6, 73.9], [1, 0])} r={84} />
          {after ? (
            <>
              <div style={{position: 'absolute', left: r1[0], top: r1[1], width: r1[2], height: r1[3] * 2, background: C.card}} />
              <Strip src="VolAfter" box={[r2[0], r2[1], r2[2], r2[3]]} toY={r1[1] + (r2[1] - r1[1]) * m} />
              <Strip src="VolAfter" box={r1} toY={r2[1] + (r1[1] - r2[1]) * m} />
            </>
          ) : null}
        </Phone>
      </PhoneSlot>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------------------------------------
export const ClubScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 75.2 || t > 83.0) return null;
  const items = [
    {screen: 'YourCrew', x: 560, ry: 12, a: 75.8, cap: 'Your crew'},
    {screen: 'ClubTestBoard', x: 960, ry: 0, a: 77.3, cap: 'Club tests'},
    {screen: 'CoachRowers', x: 1360, ry: -12, a: 79.0, cap: 'Coaching'},
  ];
  const out = ip(t, [82.2, 82.8], [0, 1], easeInOut);
  const dolly = ip(t, [75.6, 82.8], [1, 1.04], (v) => v);
  const w = 400;
  const g = phoneGeom(w);
  return (
    <AbsoluteFill style={{fontFamily: INTER, opacity: 1 - out, perspective: 2600, transform: `scale(${dolly})`}}>
      {items.map((p) => {
        const k = ip(t, [p.a, p.a + 1.0], [0, 1], easeOut);
        return (
          <React.Fragment key={p.screen}>
            <div style={{position: 'absolute', left: p.x - w / 2, top: 70 + (1 - k) * 80, opacity: k, transform: `rotateY(${p.ry}deg)`}}>
              <Phone screen={p.screen} width={w} viewTop={0} />
            </div>
            <div style={{position: 'absolute', left: p.x - 200, width: 400, top: 70 + g.height + 36, textAlign: 'center',
              fontSize: 36, fontWeight: 500, color: C.ink2, opacity: ip(t, [p.a + 0.4, p.a + 1.0], [0, 1])}}>{p.cap}</div>
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};
