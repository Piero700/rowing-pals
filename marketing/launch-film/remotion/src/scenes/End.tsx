import React from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame} from 'remotion';
import {C, FPS, INTER, easeInOut, easeOut, ip} from '../lib/theme';

/** Lockup: mark + wordmark, "Train together.", then the call to action; a long hold, then black. */
export const EndScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 82.4) return null;
  const mark = ip(t, [82.7, 83.9], [0, 1], easeOut);
  const word = ip(t, [83.0, 84.2], [0, 1], easeOut);
  const line = ip(t, [84.8, 85.6], [0, 1], easeOut);
  const cta = ip(t, [87.0, 87.7], [0, 1], easeOut);
  const out = ip(t, [89.2, 90.0], [0, 1], easeInOut);
  const glow = ip(t, [82.6, 84.5], [0, 1], easeOut);
  return (
    <AbsoluteFill style={{fontFamily: INTER, opacity: 1 - out}}>
      <AbsoluteFill style={{background: `radial-gradient(700px 420px at 50% 42%, rgba(145,184,255,${0.12 * glow}), transparent 70%)`}} />
      <Img src={staticFile('icon.png')} style={{position: 'absolute', left: 960 - 95, top: 250, width: 190, height: 190, borderRadius: 43,
        opacity: mark, transform: `scale(${0.94 + 0.06 * mark})`, filter: `blur(${(1 - mark) * 10}px)`,
        boxShadow: '0 30px 80px rgba(0,0,0,.55)'}} />
      <div style={{position: 'absolute', left: 0, right: 0, top: 478, textAlign: 'center', fontSize: 92, fontWeight: 600, color: C.ink,
        letterSpacing: `${0.12 - word * 0.13}em`, opacity: word, filter: `blur(${(1 - word) * 5}px)`}}>
        Rowing Pals
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: 612, textAlign: 'center', fontSize: 48, fontWeight: 400, color: C.ink2,
        opacity: line, transform: `translateY(${(1 - line) * 14}px)`}}>
        Train together.
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: 760, textAlign: 'center', opacity: cta, transform: `translateY(${(1 - cta) * 14}px)`}}>
        <span style={{display: 'inline-block', padding: '20px 44px', borderRadius: 999, fontSize: 38, fontWeight: 600, color: '#09090b',
          background: `linear-gradient(180deg, #a9c6ff, ${C.brand})`, boxShadow: '0 12px 40px rgba(145,184,255,.28)'}}>
          Coming soon to iPhone
        </span>
      </div>
    </AbsoluteFill>
  );
};
