// Usage: node scripts/stills.mjs out/stills 2,5,8.5 [bgm]
import {bundle} from '@remotion/bundler';
import {renderStill, selectComposition} from '@remotion/renderer';
import path from 'node:path';
import fs from 'node:fs';
const [outDir, times] = process.argv.slice(2);
fs.mkdirSync(outDir, {recursive: true});
const browserExecutable = process.env.REMOTION_BROWSER || undefined;
const serveUrl = await bundle({entryPoint: path.resolve('src/index.ts')});
const inputProps = {bgm: true};
const composition = await selectComposition({serveUrl, id: 'LaunchFilm', inputProps, browserExecutable});
for (const s of times.split(',').map(Number)) {
  const frame = Math.round(s * 30);
  await renderStill({serveUrl, composition, frame, output: path.join(outDir, `t${s.toFixed(1).padStart(5, '0')}.jpg`),
    imageFormat: 'jpeg', jpegQuality: 85, inputProps, browserExecutable});
}
console.log('done');
