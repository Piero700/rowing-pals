import React from 'react';
import {Img, staticFile} from 'remotion';
import screens from '../screens.json';

export const SRC_W = 1179; // app screens are 393 pt at 3x
export const SRC_H = 2556; // one iPhone screen (852 pt) at 3x

type Props = {
  screen: string;          // file in public/screens (no extension)
  width: number;           // phone body width in px
  viewTop?: number;        // which part of the (tall) screen render is visible, in source px
  nav?: boolean;           // pin the render's floating tab bar to the bottom of the screen
  navH?: number;           // height of that tab bar strip in source px
  children?: React.ReactNode; // overlays, positioned in source px (same space as screens.json boxes)
  style?: React.CSSProperties;
  dim?: number;            // 0..1 darkening of the screen
  next?: {screen: string; viewTop?: number; p: number; children?: React.ReactNode}; // an iOS-style push to a second screen
};

/** A generic modern phone (no brand marks) showing a rendered app screen, with overlays in screen space. */
export const Phone: React.FC<Props> = ({screen, width, viewTop = 0, nav = false, navH = 300, children, style, dim = 0, next}) => {
  const bezel = width * 0.034;
  const screenW = width - bezel * 2;
  const k = screenW / SRC_W;
  const screenH = SRC_H * k;
  const height = screenH + bezel * 2;
  const r = width * 0.155;
  const size = (screens.sizes as Record<string, number[]>)[screen];
  const fullH = size ? size[1] : SRC_H;
  return (
    <div style={{position: 'relative', width, height, ...style}}>
      {/* soft contact shadow */}
      <div style={{position: 'absolute', left: '8%', right: '8%', bottom: -height * 0.05, height: height * 0.08,
        background: 'radial-gradient(closest-side, rgba(0,0,0,.55), transparent)', filter: 'blur(14px)'}} />
      {/* body: brushed edge + black bezel */}
      <div style={{position: 'absolute', inset: 0, borderRadius: r,
        background: 'linear-gradient(135deg,#5b606b 0%,#2a2d33 22%,#16181c 50%,#2c3036 78%,#6a707b 100%)',
        boxShadow: '0 50px 120px rgba(0,0,0,.65), 0 10px 30px rgba(0,0,0,.5)'}} />
      <div style={{position: 'absolute', inset: width * 0.006, borderRadius: r - width * 0.006, background: '#040405'}} />
      {/* side buttons */}
      <div style={{position: 'absolute', left: -width * 0.008, top: height * 0.2, width: width * 0.01, height: height * 0.05, borderRadius: 4, background: '#3a3e45'}} />
      <div style={{position: 'absolute', left: -width * 0.008, top: height * 0.28, width: width * 0.01, height: height * 0.09, borderRadius: 4, background: '#3a3e45'}} />
      <div style={{position: 'absolute', right: -width * 0.008, top: height * 0.25, width: width * 0.01, height: height * 0.12, borderRadius: 4, background: '#3a3e45'}} />
      {/* screen */}
      <div style={{position: 'absolute', left: bezel, top: bezel, width: screenW, height: screenH, borderRadius: r - bezel,
        overflow: 'hidden', background: '#101114'}}>
        <div style={{position: 'absolute', left: 0, top: 0, width: SRC_W, height: fullH,
          transform: `translateX(${next ? -next.p * screenW * 0.3 : 0}px) scale(${k}) translateY(${-viewTop}px)`, transformOrigin: '0 0'}}>
          <Img src={staticFile(`screens/${screen}.png`)} style={{position: 'absolute', left: 0, top: 0, width: SRC_W}} />
          {children}
        </div>
        {next && next.p > 0 ? (
          <div style={{position: 'absolute', inset: 0, background: `rgba(0,0,0,${next.p * 0.35})`}} />
        ) : null}
        {next && next.p > 0 ? (
          <div style={{position: 'absolute', left: 0, top: 0, width: SRC_W, transformOrigin: '0 0',
            transform: `translateX(${(1 - next.p) * screenW}px) scale(${k}) translateY(${-(next.viewTop ?? 0)}px)`,
            boxShadow: '-30px 0 60px rgba(0,0,0,.4)'}}>
            <Img src={staticFile(`screens/${next.screen}.png`)} style={{position: 'absolute', left: 0, top: 0, width: SRC_W}} />
            {next.children}
          </div>
        ) : null}
        {nav && size && !(next && next.p > 0.5) ? (
          <div style={{position: 'absolute', left: 0, bottom: 0, width: screenW, height: navH * k, overflow: 'hidden'}}>
            <Img src={staticFile(`screens/${screen}.png`)}
              style={{position: 'absolute', left: 0, top: -(fullH - navH) * k, width: screenW}} />
          </div>
        ) : null}
        {/* scroll-edge fade under the status bar, as iOS does when content scrolls beneath it */}
        {viewTop > 0 ? (
          <div style={{position: 'absolute', left: 0, right: 0, top: 0, height: 150 * k,
            background: 'linear-gradient(#101114 45%, rgba(16,17,20,0))'}} />
        ) : null}
        {/* fixed status-bar island so scrolled content passes beneath it */}
        <div style={{position: 'absolute', left: '50%', top: 10 * 3 * k, width: 106 * 3 * k, height: 27 * 3 * k,
          transform: 'translateX(-50%)', borderRadius: 99, background: '#030408'}} />
        {dim > 0 ? <div style={{position: 'absolute', inset: 0, background: `rgba(5,6,8,${dim})`}} /> : null}
        {/* glass reflection */}
        <div style={{position: 'absolute', inset: 0, pointerEvents: 'none',
          background: 'linear-gradient(115deg, rgba(255,255,255,.07) 0%, rgba(255,255,255,0) 32%, rgba(255,255,255,0) 70%, rgba(255,255,255,.03) 100%)'}} />
      </div>
    </div>
  );
};

/** Maps a point in a phone's screen space (source px) to the phone's own box (for layout maths). */
export const phoneGeom = (width: number) => {
  const bezel = width * 0.034;
  const k = (width - bezel * 2) / SRC_W;
  return {bezel, k, height: SRC_H * k + bezel * 2};
};
