import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {C, FPS, HAND, INTER, LCD, easeInOut, easeOut, ip, sceneFade} from '../lib/theme';
import {Monitor} from '../lib/Monitor';

const fmt = (sec: number) => {
  const m = Math.floor(sec / 60);
  const s = sec - m * 60;
  return `${m}:${s.toFixed(1).padStart(4, '0')}`;
};

/** The erg's fan, drawn: 16 curved blades in a vented housing. Speed surges on each drive (every 2.4 s). */
const Flywheel: React.FC<{t: number; size: number}> = ({t, size}) => {
  const cycle = 2.4;
  const n = Math.floor(t / cycle);
  const ph = Math.min(1, (t % cycle) / 0.9);
  const surge = n + ph * ph * (3 - 2 * ph);
  const angle = 90 * t + 140 * surge;
  const blades = Array.from({length: 16}, (_, i) => i * 22.5);
  return (
    <svg width={size} height={size} viewBox="-100 -100 200 200">
      <defs>
        <radialGradient id="hub" cx="40%" cy="35%" r="70%">
          <stop offset="0" stopColor="#3b4049" />
          <stop offset="1" stopColor="#0e1013" />
        </radialGradient>
        <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#9fb6dd" stopOpacity=".55" />
          <stop offset=".35" stopColor="#2a2e35" />
          <stop offset="1" stopColor="#0b0c0f" />
        </linearGradient>
        <linearGradient id="blade" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#4a505b" />
          <stop offset="1" stopColor="#1a1d22" />
        </linearGradient>
      </defs>
      <circle r="96" fill="#0b0c0f" stroke="url(#rim)" strokeWidth="3" />
      {/* housing vents */}
      {Array.from({length: 48}, (_, i) => (
        <rect key={i} x="-1.2" y="-93" width="2.4" height="9" rx="1.2" fill="#1c1f25" transform={`rotate(${i * 7.5})`} />
      ))}
      <g transform={`rotate(${angle})`}>
        {/* motion trail: two faint copies behind the blades */}
        {[10, 5].map((lag, j) => (
          <g key={j} opacity={0.12 + j * 0.08} transform={`rotate(${-lag})`}>
            {blades.map((a) => (
              <path key={a} d="M0 -22 C 14 -40, 10 -62, 4 -80 L -4 -80 C 0 -60, 2 -42, -6 -24 Z" fill="#2a2e36" transform={`rotate(${a})`} />
            ))}
          </g>
        ))}
        {blades.map((a) => (
          <path key={a} d="M0 -22 C 14 -40, 10 -62, 4 -80 L -4 -80 C 0 -60, 2 -42, -6 -24 Z" fill="url(#blade)"
            stroke="#5d6573" strokeOpacity=".35" strokeWidth=".6" transform={`rotate(${a})`} />
        ))}
      </g>
      <circle r="24" fill="url(#hub)" stroke="#4b515c" strokeWidth="1" />
      <circle r="6" fill="#0a0b0d" />
      {/* key light from top-left */}
      <circle r="96" fill="url(#rim)" opacity=".06" />
    </svg>
  );
};

export const OpenScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t > 7.2) return null;
  const op = sceneFade(t, 0.4, 6.6, 1.6, 0.55);
  const push = ip(t, [0, 7], [1, 1.14], easeInOut);
  const wheelBlur = ip(t, [0, 2.5], [5, 2]) + ip(t, [3.3, 4.6], [0, 9]);
  const monOp = ip(t, [3.2, 4.4], [0, 1]);
  const monBlur = ip(t, [3.2, 4.6], [14, 0], easeOut);
  return (
    <AbsoluteFill style={{opacity: op}}>
      <AbsoluteFill style={{transform: `scale(${push})`}}>
        <div style={{position: 'absolute', left: 300, top: 40, filter: `blur(${wheelBlur}px)`, opacity: 0.95}}>
          <Flywheel t={t} size={1000} />
        </div>
        <div style={{position: 'absolute', left: 1180, top: 230, opacity: monOp, filter: `blur(${monBlur}px)`,
          transform: `translateY(${ip(t, [3.2, 4.6], [30, 0], easeOut)}px)`}}>
          <Monitor w={500} rows={[['time', '4:12.0'], ['metres', '1000'], ['/500m', '1:40.7'], ['s/m', '30']]} glow={0.8} />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const NumberScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 6.2 || t > 14.4) return null;
  const op = sceneFade(t, 6.55, 14.2, 0.5, 0.6);
  const split = ip(t, [6.9, 8.9], [104.2, 100.7], easeOut);
  const two = ip(t, [10.3, 12.3], [411.0, 402.9], easeOut);
  const lift = ip(t, [9.6, 10.4], [0, 1], easeInOut);
  const twoOp = ip(t, [10.0, 10.6], [0, 1]);
  const push = ip(t, [6.3, 14.2], [1, 1.05], easeInOut);
  return (
    <AbsoluteFill style={{opacity: op, fontFamily: INTER, color: C.ink, transform: `scale(${push})`}}>
      {/* the split */}
      <div style={{position: 'absolute', left: 0, right: 0, top: 300 - lift * 170, textAlign: 'center',
        transform: `scale(${1 - lift * 0.55})`, opacity: 1 - lift * 0.55}}>
        <div style={{fontSize: 280, fontWeight: 300, letterSpacing: '-0.02em', fontVariantNumeric: 'tabular-nums', lineHeight: 1}}>
          {fmt(split)}
        </div>
        <div style={{fontSize: 44, color: C.ink2, marginTop: 20, letterSpacing: '0.02em'}}>/500m split</div>
      </div>
      {/* the 2k */}
      <div style={{position: 'absolute', left: 0, right: 0, top: 470, textAlign: 'center', opacity: twoOp,
        transform: `translateY(${(1 - twoOp) * 30}px)`}}>
        <div style={{fontSize: 280, fontWeight: 300, letterSpacing: '-0.02em', fontVariantNumeric: 'tabular-nums', lineHeight: 1}}>
          {fmt(two)}
        </div>
        <div style={{fontSize: 44, color: C.ink2, marginTop: 20, letterSpacing: '0.02em'}}>2k</div>
      </div>
    </AbsoluteFill>
  );
};

const NOTES = [
  ['Mon', '16k UT2', '2:01.4'],
  ['Wed', '3 × 2k', '1:42 avg'],
  ['Sat', '2k test', '6:51.0'],
];

export const AloneScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 13.6 || t > 27.4) return null;
  const op = sceneFade(t, 13.8, 27.0, 0.8, 0.9);
  // beat 1: a lone light crossing a dark horizon
  const b1 = sceneFade(t, 13.8, 17.6, 0.8, 0.6);
  const x = ip(t, [13.8, 17.6], [520, 980], (v) => v);
  // beat 2: early start
  const b2 = sceneFade(t, 17.3, 19.5, 0.4, 0.4);
  // beat 3: long piece
  const b3 = sceneFade(t, 19.3, 21.8, 0.4, 0.5);
  const prog = ip(t, [19.3, 21.8], [0.08, 0.36], (v) => v);
  // beat 4: the notebook, then forgotten
  const b4 = sceneFade(t, 21.5, 27.0, 0.5, 0.8);
  const forget = ip(t, [25.0, 26.4], [0, 1], easeInOut);
  return (
    <AbsoluteFill style={{opacity: op, fontFamily: INTER}}>
      <AbsoluteFill style={{opacity: b1}}>
        {/* pre-dawn sky and still water, barely lit */}
        <div style={{position: 'absolute', left: 0, right: 0, top: 0, height: 600,
          background: 'linear-gradient(180deg, rgba(10,12,16,0) 0%, rgba(38,48,66,.45) 82%, rgba(70,86,112,.55) 100%)'}} />
        <div style={{position: 'absolute', left: 0, right: 0, top: 600, bottom: 0,
          background: 'linear-gradient(180deg, rgba(52,64,84,.42) 0%, rgba(14,16,20,0) 45%)'}} />
        <div style={{position: 'absolute', left: 0, right: 0, top: 599, height: 2, background: 'linear-gradient(90deg,transparent,rgba(190,205,230,.45),transparent)'}} />
        {/* a lone sculler: a small light and the long wake behind it */}
        <div style={{position: 'absolute', left: x - 420, top: 607, width: 420, height: 2, background: 'linear-gradient(90deg,transparent,rgba(200,215,240,.35))'}} />
        <div style={{position: 'absolute', left: x - 6, top: 591, width: 12, height: 12, borderRadius: 6, background: '#e8eefb',
          boxShadow: '0 0 30px 8px rgba(170,198,245,.45)'}} />
        <div style={{position: 'absolute', left: x - 3, top: 612, width: 6, height: 70, background: 'linear-gradient(180deg, rgba(200,215,240,.35), transparent)',
          filter: 'blur(2px)'}} />
      </AbsoluteFill>
      <AbsoluteFill style={{opacity: b2, justifyContent: 'center', alignItems: 'center'}}>
        <div style={{fontFamily: LCD, fontSize: 200, color: '#8b93a5', letterSpacing: '0.04em'}}>
          05{Math.floor(t * 2) % 2 ? ':' : ' '}42
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{opacity: b3}}>
        <div style={{position: 'absolute', left: 360, right: 360, top: 560, height: 4, borderRadius: 2, background: '#1f232a'}}>
          <div style={{width: `${prog * 100}%`, height: '100%', borderRadius: 2, background: '#9aa3b6', boxShadow: '0 0 18px rgba(154,163,182,.4)'}} />
        </div>
        <div style={{position: 'absolute', left: 360, right: 360, top: 600, display: 'flex', justifyContent: 'space-between',
          fontFamily: LCD, fontSize: 40, color: '#7f889b', fontVariantNumeric: 'tabular-nums'}}>
          <span>{Math.round(prog * 12000).toLocaleString('en-GB')}m</span>
          <span>12,000m</span>
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{opacity: b4 * (1 - forget * 0.35), justifyContent: 'center', alignItems: 'center'}}>
        <div style={{width: 1000, height: 560, borderRadius: 18, transform: `rotate(-1.5deg) scale(${ip(t, [21.5, 27], [1, 1.04])})`,
          background: 'linear-gradient(170deg,#1d1f24,#15171b)', boxShadow: '0 40px 100px rgba(0,0,0,.6)', position: 'relative', overflow: 'hidden'}}>
          {Array.from({length: 9}, (_, i) => (
            <div key={i} style={{position: 'absolute', left: 60, right: 60, top: 92 + i * 52, height: 1, background: 'rgba(140,150,170,.12)'}} />
          ))}
          {NOTES.map(([d, w, r], i) => {
            const a = 21.9 + i * 0.85;
            const reveal = ip(t, [a, a + 0.7], [0, 100], (v) => v);
            const gone = ip(t, [25.0 + i * 0.25, 26.1 + i * 0.25], [0, 1], easeInOut);
            return (
              <div key={d} style={{position: 'absolute', left: 90, top: 128 + i * 104, fontFamily: HAND, fontSize: 64, color: '#c9cdd6',
                clipPath: `inset(0 ${100 - reveal}% 0 0)`, opacity: 0.85 * (1 - gone), filter: `blur(${gone * 8}px)`,
                display: 'flex', gap: 60}}>
                <span style={{width: 120}}>{d}</span><span style={{width: 330}}>{w}</span><span>{r}</span>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
