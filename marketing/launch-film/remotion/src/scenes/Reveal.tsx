import React from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame} from 'remotion';
import {C, FPS, INTER, easeInOut, easeOut, ip, sceneFade} from '../lib/theme';
import {Phone} from '../lib/Phone';
import {PostPhoto} from '../lib/PostPhoto';

/** Light blooms out of the dark, the otter mark settles, the wordmark resolves; then the app arrives in three phones. */
export const RevealScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 26.8 || t > 37.2) return null;
  const op = sceneFade(t, 27.0, 36.55, 0.3, 0.55);
  const bloom = ip(t, [27.2, 29.4], [0, 1], easeOut);
  const iconIn = ip(t, [28.1, 29.5], [0, 1], easeOut);
  const wordIn = ip(t, [29.0, 30.4], [0, 1], easeOut);
  const lockupOut = ip(t, [31.7, 32.5], [0, 1], easeInOut);
  return (
    <AbsoluteFill style={{opacity: op, fontFamily: INTER}}>
      {/* bloom */}
      <AbsoluteFill style={{background: `radial-gradient(${300 + bloom * 700}px ${220 + bloom * 420}px at 50% 46%, rgba(145,184,255,${0.22 * bloom * (1 - lockupOut * 0.6)}), transparent 70%)`}} />
      <div style={{position: 'absolute', left: 0, right: 0, top: 497, height: 2, opacity: bloom * (1 - lockupOut),
        background: 'linear-gradient(90deg, transparent, rgba(190,215,255,.35) 50%, transparent)', filter: 'blur(1px)',
        transform: `scaleX(${0.3 + bloom * 0.7})`}} />
      {/* lockup */}
      <AbsoluteFill style={{opacity: 1 - lockupOut, transform: `translateY(${-lockupOut * 40}px) scale(${1 - lockupOut * 0.06})`}}>
        <Img src={staticFile('icon.png')} style={{position: 'absolute', left: 960 - 120, top: 270, width: 240, height: 240, borderRadius: 54,
          opacity: iconIn, filter: `blur(${(1 - iconIn) * 16}px)`, transform: `scale(${0.93 + iconIn * 0.07})`,
          boxShadow: `0 30px 90px rgba(0,0,0,.6), 0 0 ${80 * iconIn}px rgba(145,184,255,.18)`}} />
        <div style={{position: 'absolute', left: 0, right: 0, top: 570, textAlign: 'center', fontSize: 96, fontWeight: 600, color: C.ink,
          letterSpacing: `${0.3 - wordIn * 0.31}em`, opacity: wordIn, filter: `blur(${(1 - wordIn) * 6}px)`}}>
          Rowing Pals
        </div>
      </AbsoluteFill>
      {/* the app, in three phones */}
      <ThreePhones t={t} />
    </AbsoluteFill>
  );
};

const ThreePhones: React.FC<{t: number}> = ({t}) => {
  const items = [
    {screen: 'Main', x: -560, ry: 20, a: 32.5, nav: true},
    {screen: 'VolBefore', x: 0, ry: 0, a: 32.25, nav: true},
    {screen: 'Profile', x: 560, ry: -20, a: 32.75, nav: true},
  ];
  const orbit = ip(t, [32.4, 36.9], [-5, 5], (v) => v);
  return (
    <AbsoluteFill style={{perspective: 2600, perspectiveOrigin: '50% 45%'}}>
      <div style={{position: 'absolute', left: 960, top: 560, transformStyle: 'preserve-3d', transform: `rotateY(${orbit}deg)`}}>
        {items.map((p) => {
          const k = ip(t, [p.a, p.a + 1.3], [0, 1], easeOut);
          return (
            <div key={p.screen} style={{position: 'absolute', left: p.x - 210, top: -455 + (1 - k) * 260, opacity: k,
              transform: `translateZ(${p.x === 0 ? 90 : 0}px) rotateY(${p.ry}deg)`}}>
              <Phone screen={p.screen} width={420} nav={p.nav} navH={p.screen === 'Profile' ? 290 : 300}>
                {p.screen === 'Main' ? <><PostPhoto /><PostPhoto which="photo2" /></> : null}
              </Phone>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
