import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {APPFONT, C, FPS, INTER, LCD, easeInOut, easeOut, ip, sceneFade} from '../lib/theme';
import {Phone, phoneGeom} from '../lib/Phone';
import {Monitor, Selfie} from '../lib/Monitor';
import {Label} from '../lib/Atmos';
import screens from '../screens.json';

const B = screens.boxes as Record<string, Record<string, number[]>>;
const ROWS: [string, string][] = [['time', '6:42.9'], ['metres', '2000'], ['/500m', '1:40.7'], ['s/m', '30']];

/** The viewfinder content drawn into the Log workout screen's rear-camera area (screen space, source px). */
const Viewfinder: React.FC = () => {
  const [rx, ry, rw, rh] = B.LogWorkout.rear;
  const [fx, fy, fw, fh] = B.LogWorkout.front;
  return (
    <>
      <div style={{position: 'absolute', left: rx, top: ry, width: rw, height: rh, borderRadius: 66, overflow: 'hidden',
        background: 'radial-gradient(90% 70% at 40% 45%, #23262d, #0c0d10)'}}>
        <div style={{position: 'absolute', left: 130, top: 420}}><Monitor w={640} rows={ROWS} glow={0.7} /></div>
      </div>
      <Selfie w={fw} h={fh} radius={51} style={{position: 'absolute', left: fx, top: fy, border: '6px solid #1b1c21', boxSizing: 'border-box'}} />
    </>
  );
};

/** The dual photo as it is posted: monitor photo with the front-camera inset in its corner. */
export const DualPhoto: React.FC<{w: number; insetK: number; split: number}> = ({w, insetK, split}) => {
  const h = w * 4 / 3;
  const iw = w * 0.27;
  const ih = iw * 4 / 3;
  // split = 0: inset docked top-right; split = 1: the selfie stands beside the monitor photo at full size
  const sw = iw + (w * 0.62 - iw) * split;
  const sh = sw * 4 / 3;
  const sx = (w - iw - w * 0.03) + (w + w * 0.1 - (w - iw - w * 0.03)) * split;
  const sy = w * 0.03 + (h / 2 - sh / 2 - w * 0.03) * split;
  return (
    <div style={{position: 'relative', width: w, height: h}}>
      <div style={{position: 'absolute', inset: 0, borderRadius: w * 0.06, overflow: 'hidden',
        background: 'radial-gradient(90% 70% at 40% 45%, #23262d, #0c0d10)', boxShadow: '0 40px 100px rgba(0,0,0,.6)'}}>
        <div style={{position: 'absolute', left: w * 0.1, top: h * 0.2}}><Monitor w={w * 0.8} rows={ROWS} glow={0.7} /></div>
      </div>
      <Selfie w={sw} h={sh} radius={w * 0.045 * (1 + split)} style={{position: 'absolute', left: sx, top: sy,
        border: `${Math.max(3, w * 0.008)}px solid #1b1c21`, boxSizing: 'border-box', boxShadow: '0 20px 60px rgba(0,0,0,.5)',
        opacity: insetK}} />
    </div>
  );
};

export const CaptureScene: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t < 36.2 || t > 52.0) return null;
  const op = sceneFade(t, 36.5, 51.8, 0.5, 0.5);

  // phase A: Log workout, shutter
  const aOut = ip(t, [40.0, 40.6], [0, 1], easeInOut);
  const aIn = ip(t, [36.55, 37.5], [0, 1], easeOut);
  const logW = 470;
  const lg = phoneGeom(logW);
  const [shx, shy, shw, shh] = B.LogWorkout.shutter;
  const flash = ip(t, [39.55, 39.62], [0, 1]) * ip(t, [39.62, 40.0], [1, 0]);
  const tap = ip(t, [39.4, 39.8], [0, 1]);

  // phase B: the two photos separate, then dock into one post photo
  const bIn = ip(t, [40.6, 41.4], [0, 1], easeOut);
  const split = ip(t, [40.6, 41.6], [0, 1], easeInOut) * (1 - ip(t, [44.5, 45.5], [0, 1], easeInOut));
  const capA = ip(t, [41.0, 41.6], [0, 1]) * (1 - ip(t, [44.3, 44.8], [0, 1]));
  const capB = ip(t, [43.3, 43.9], [0, 1]) * (1 - ip(t, [44.3, 44.8], [0, 1]));
  const toLeft = ip(t, [45.4, 46.4], [0, 1], easeInOut);
  const photoW = 450 - toLeft * 60;
  const photoCx = 780 - toLeft * 280 - split * 130;
  const photoCy = 520;

  // phase C: Review screen, numbers fly from the monitor into the form
  const rW = 500;
  const rg = phoneGeom(rW);
  const rLeft = 1180;
  const rTop = (1080 - rg.height) / 2;
  const viewTop = 300;
  const rIn = ip(t, [45.6, 46.6], [0, 1], easeOut);
  const toFrame = (sx: number, sy: number) => [rLeft + rg.bezel + sx * rg.k, rTop + rg.bezel + (sy - viewTop) * rg.k];
  const fields: {key: string; val: string; at: number; row: number}[] = [
    {key: 'dist', val: '2000', at: 47.0, row: 1},
    {key: 'time', val: '6:42.9', at: 47.45, row: 0},
    {key: 'avg', val: '1:40.7', at: 47.9, row: 2},
    {key: 'rate', val: '30 spm', at: 48.35, row: 3},
  ];
  const photoH = photoW * 4 / 3;
  const monW = photoW * 0.8;
  const monLeft = photoCx - photoW / 2 + photoW * 0.1;
  const monTop = photoCy - photoH / 2 + photoH * 0.2;
  const lcdPad = monW * 0.07;
  const lcdTop = monTop + lcdPad;
  const lcdH = monW * 1.08 - lcdPad * 3.2;
  const confirmT = 49.6;
  const [cx, cy, cw, ch] = B.ReviewSession.confirm;
  const [rfx, rfy, rfw, rfh] = B.ReviewSession.rate;

  return (
    <AbsoluteFill style={{opacity: op, fontFamily: INTER}}>
      <Label title="Log a session" line="Two photos, one tap. The numbers are read off the monitor for you." opacity={aIn * (1 - aOut)} y={420} />

      {/* phase A */}
      <div style={{position: 'absolute', left: 1080, top: (1080 - lg.height) / 2, opacity: aIn * (1 - aOut),
        transform: `translateY(${(1 - aIn) * 60}px) scale(${1 + ip(t, [36.6, 40.2], [0, 0.04])})`}}>
        <Phone screen="LogWorkout" width={logW} viewTop={0}>
          <Viewfinder />
          <div style={{position: 'absolute', left: shx + shw / 2 - 150, top: shy + shh / 2 - 150, width: 300, height: 300, borderRadius: 150,
            border: '8px solid rgba(255,255,255,.9)', opacity: tap * (1 - tap), transform: `scale(${0.6 + tap * 0.6})`}} />
          <div style={{position: 'absolute', left: 0, top: 0, width: 1179, height: 2556, background: '#fff', opacity: flash * 0.6}} />
        </Phone>
      </div>

      {/* phase B → C: the photos */}
      <div style={{position: 'absolute', left: photoCx - photoW / 2, top: photoCy - photoH / 2, opacity: bIn,
        transform: `scale(${0.8 + bIn * 0.2 + ip(t, [41.4, 46.4], [0, 0.03], (v) => v)})`}}>
        <DualPhoto w={photoW} insetK={1} split={split} />
      </div>
      <div style={{position: 'absolute', left: photoCx - photoW / 2, top: photoCy + photoH / 2 + 34, width: photoW, textAlign: 'center',
        fontSize: 34, color: C.ink2, opacity: capA}}>Rear camera · the monitor</div>
      <div style={{position: 'absolute', left: photoCx + photoW / 2 + photoW * 0.1, top: photoCy + photoH / 2 + 34, width: photoW * 0.62 + 120,
        marginLeft: -60, textAlign: 'center', fontSize: 34, color: C.ink2, opacity: capB}}>Front camera · you</div>

      {/* phase C: Review session */}
      <div style={{position: 'absolute', left: rLeft, top: rTop, opacity: rIn, transform: `translateX(${(1 - rIn) * 80}px)`}}>
        <Phone screen="ReviewSession" width={rW} viewTop={viewTop}>
          {fields.map((f) => {
            const [x, y, w, h] = B.ReviewSession[f.key];
            const landed = t >= f.at + 0.55;
            const wMask = f.key === 'rate' ? cx - x - 12 : w - 12;
            return landed ? null : (
              <div key={f.key} style={{position: 'absolute', left: x + 6, top: y + 6, width: wMask, height: h - 12,
                borderRadius: f.key === 'rate' ? '66px 0 0 66px' : 66, background: '#1b1c21'}} />
            );
          })}
          {/* confirm tap + the rate field acknowledged */}
          <div style={{position: 'absolute', left: cx + cw / 2 - 110, top: cy + ch / 2 - 110, width: 220, height: 220, borderRadius: 110,
            background: 'rgba(145,184,255,.35)', opacity: ip(t, [confirmT, confirmT + 0.15], [0, 1]) * ip(t, [confirmT + 0.15, confirmT + 0.6], [1, 0]),
            transform: `scale(${ip(t, [confirmT, confirmT + 0.6], [0.4, 1.3])})`}} />
          <div style={{position: 'absolute', left: rfx - 6, top: rfy - 6, width: rfw + 12, height: rfh + 12, borderRadius: 78,
            border: `9px solid ${C.brand}`, opacity: ip(t, [confirmT + 0.1, confirmT + 0.4], [0, 1]) * ip(t, [51.0, 51.6], [1, 0]),
            boxShadow: `0 0 40px rgba(145,184,255,.45)`}} />
        </Phone>
      </div>

      {/* numbers in flight: LCD digits leave the monitor and settle into the form fields */}
      {fields.map((f) => {
        const p = ip(t, [f.at, f.at + 0.55], [0, 1], easeInOut);
        if (t < f.at || t > f.at + 0.6) return null;
        const [x, y, , h] = B.ReviewSession[f.key];
        const [tx, ty] = toFrame(x + 42, y + h / 2);
        const sx = monLeft + monW * 0.5;
        const sy = lcdTop + (f.row + 0.5) * (lcdH / 4);
        const px = sx + (tx - sx) * p;
        const py = sy + (ty - sy) * p - Math.sin(p * Math.PI) * 90;
        const fs = monW * 0.15 + (51 * rg.k - monW * 0.15) * p;
        return (
          <div key={f.key} style={{position: 'absolute', left: px, top: py, transform: 'translateY(-50%)', whiteSpace: 'nowrap',
            fontSize: fs, color: p < 0.5 ? '#e9f0dc' : C.ink, textShadow: `0 0 ${18 * (1 - p)}px rgba(200,230,180,.6)`,
            fontFamily: p < 0.5 ? LCD : APPFONT}}>
            {f.val}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
