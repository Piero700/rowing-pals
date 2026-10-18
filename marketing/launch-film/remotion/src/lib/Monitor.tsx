import React from 'react';
import {LCD} from './theme';

/** An illustrated, unbranded erg monitor: a drawing, never presented as a photo. */
export const Monitor: React.FC<{
  w: number;
  rows?: [string, string][];
  glow?: number; // 0..1 backlight
  style?: React.CSSProperties;
}> = ({w, rows = [['time', '6:42.9'], ['metres', '2000'], ['/500m', '1:40.7'], ['s/m', '30']], glow = 0.6, style}) => {
  const h = w * 1.08;
  const pad = w * 0.07;
  return (
    <div style={{position: 'relative', width: w, height: h, borderRadius: w * 0.07,
      background: 'linear-gradient(160deg,#3a3d45,#1d1f24 55%,#15171b)',
      boxShadow: `inset 0 ${w * 0.006}px 0 rgba(255,255,255,.14), 0 ${w * 0.05}px ${w * 0.12}px rgba(0,0,0,.55)`, ...style}}>
      <div style={{position: 'absolute', left: pad, right: pad, top: pad, bottom: pad * 2.2, borderRadius: w * 0.035,
        background: `linear-gradient(170deg, rgba(205,216,190,${0.75 + glow * 0.25}), rgba(170,184,156,${0.75 + glow * 0.25}))`,
        boxShadow: `inset 0 ${w * 0.01}px ${w * 0.03}px rgba(0,0,0,.35), 0 0 ${w * 0.15 * glow}px rgba(190,220,170,${0.18 * glow})`,
        padding: `${w * 0.045}px ${w * 0.06}px`, display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
        color: '#1a2016', fontFamily: LCD}}>
        {rows.map(([label, value]) => (
          <div key={label} style={{display: 'flex', justifyContent: 'space-between', alignItems: 'baseline'}}>
            <span style={{fontSize: w * 0.055, opacity: 0.7}}>{label}</span>
            <span style={{fontSize: w * 0.15, letterSpacing: w * 0.004, lineHeight: 1}}>{value}</span>
          </div>
        ))}
      </div>
      {/* buttons along the bottom edge */}
      <div style={{position: 'absolute', left: pad, right: pad, bottom: pad * 0.75, height: pad * 0.8, display: 'flex', gap: pad * 0.5}}>
        {[0, 1, 2, 3, 4].map((i) => (
          <div key={i} style={{flex: 1, borderRadius: pad * 0.3, background: 'linear-gradient(#2c2f36,#202227)',
            boxShadow: 'inset 0 1px 0 rgba(255,255,255,.08)'}} />
        ))}
      </div>
    </div>
  );
};

/** An illustrated stand-in for the front-camera photo: a simple silhouette, clearly not a real person. */
export const Selfie: React.FC<{w: number; h: number; radius?: number; style?: React.CSSProperties}> = ({w, h, radius = 0, style}) => (
  <div style={{position: 'relative', width: w, height: h, borderRadius: radius, overflow: 'hidden',
    background: 'radial-gradient(120% 90% at 50% 20%, #2b2f3a, #121318)', ...style}}>
    <svg viewBox="0 0 100 130" width={w} height={h} preserveAspectRatio="xMidYMax slice" style={{position: 'absolute', inset: 0}}>
      <defs>
        <linearGradient id="sil" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#c6adff" stopOpacity=".55" />
          <stop offset="1" stopColor="#6c5a99" stopOpacity=".35" />
        </linearGradient>
      </defs>
      <circle cx="50" cy="52" r="19" fill="url(#sil)" />
      <path d="M12 130c2-28 18-44 38-44s36 16 38 44z" fill="url(#sil)" />
    </svg>
  </div>
);
