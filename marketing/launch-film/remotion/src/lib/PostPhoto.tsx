import React from 'react';
import {Monitor, Selfie} from './Monitor';
import screens from '../screens.json';

const B = screens.boxes as Record<string, Record<string, number[]>>;

/** The posted dual photo drawn into the Main feed card's photo slot (screen space, source px). */
export const PostPhoto: React.FC<{which?: 'photo' | 'photo2'}> = ({which = 'photo'}) => {
  const [px, py, pw, ph] = B.Main[which];
  const rows: [string, string][] | undefined = which === 'photo2'
    ? [['time', '47:28.8'], ['metres', '12000'], ['/500m', '1:58.7'], ['s/m', '19']] : undefined;
  return (
    <div style={{position: 'absolute', left: px, top: py, width: pw, height: ph, borderRadius: 66, overflow: 'hidden',
      background: 'radial-gradient(90% 70% at 40% 45%, #23262d, #0c0d10)'}}>
      <div style={{position: 'absolute', left: 150, top: (ph - 518) / 2 + 20}}><Monitor w={480} rows={rows} /></div>
      <Selfie w={250} h={333} radius={45} style={{position: 'absolute', left: pw - 250 - 30, top: 30, border: '6px solid #1b1c21', boxSizing: 'border-box'}} />
    </div>
  );
};
