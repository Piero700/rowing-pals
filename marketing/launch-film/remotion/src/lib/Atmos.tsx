import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {C, INTER} from './theme';

/** Deep base with two very soft brand-coloured light pools and a vignette. */
export const Backdrop: React.FC<{blue?: number; lilac?: number; drift?: number}> = ({blue = 0.1, lilac = 0.06, drift = 0}) => (
  <AbsoluteFill style={{background: C.black}}>
    <AbsoluteFill style={{background: `radial-gradient(900px 700px at ${30 + drift * 6}% 30%, rgba(145,184,255,${blue}), transparent 70%)`}} />
    <AbsoluteFill style={{background: `radial-gradient(800px 600px at ${75 - drift * 5}% 75%, rgba(198,173,255,${lilac}), transparent 70%)`}} />
  </AbsoluteFill>
);

/** Fine film grain (deterministic: the seed follows the frame) plus vignette, laid over everything. */
export const Grain: React.FC<{amount?: number}> = ({amount = 0.07}) => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{pointerEvents: 'none'}}>
      <svg width="1920" height="1080" style={{position: 'absolute', inset: 0, opacity: amount, mixBlendMode: 'overlay'}}>
        <filter id={`g${f % 8}`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed={f % 8} stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="1920" height="1080" filter={`url(#g${f % 8})`} />
      </svg>
      <AbsoluteFill style={{background: 'radial-gradient(130% 120% at 50% 50%, transparent 55%, rgba(0,0,0,.55) 100%)'}} />
    </AbsoluteFill>
  );
};

/** Section label used on the feature scenes: title + one line, left aligned. */
export const Label: React.FC<{title: string; line: string; opacity: number; y?: number; shift?: number}> = ({title, line, opacity, y = 430, shift = 0}) => (
  <div style={{position: 'absolute', left: 150, top: y, width: 620, opacity, transform: `translateY(${shift}px)`, fontFamily: INTER}}>
    <div style={{fontSize: 64, fontWeight: 600, color: C.ink, letterSpacing: '-0.01em', lineHeight: 1.1}}>{title}</div>
    <div style={{fontSize: 34, fontWeight: 400, color: C.ink2, marginTop: 20, lineHeight: 1.35}}>{line}</div>
  </div>
);

/** Small honest footnote shown whenever app screens are on screen. */
export const SampleNote: React.FC<{opacity: number}> = ({opacity}) => (
  <div style={{position: 'absolute', left: 56, top: 34, fontFamily: INTER, fontSize: 22, color: C.ink3, opacity: opacity * 0.8,
    letterSpacing: '0.01em'}}>
    App screens shown with sample data from a fictional club.
  </div>
);
