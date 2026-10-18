import {Easing, continueRender, delayRender, interpolate, staticFile} from 'remotion';

// The app's own tokens (CLAUDE.md palette, dark). Each accent keeps its job from the app:
// brand = interactive / CTA, records = personal bests, rank = the #1 row only.
export const C = {
  black: '#050608',
  base: '#101114',
  card: '#1b1c21',
  raised: '#292c34',
  line: '#464a56',
  ink: '#f7f8fc',
  ink2: '#bbc0ce',
  ink3: '#a3abba',
  brand: '#91b8ff',
  records: '#c6adff',
  rank: '#efc37c',
};

// Fonts ship with the project (public/fonts, all SIL Open Font Licence) so renders need no network.
const FONTS: [string, string, string][] = [
  ['Inter', 'fonts/Inter-var.woff2', '300 600'],
  ['Caveat', 'fonts/Caveat-500.woff2', '500'],
  ['Share Tech Mono', 'fonts/ShareTechMono-400.woff2', '400'],
];
if (typeof document !== 'undefined') {
  const handle = delayRender('fonts');
  Promise.all(FONTS.map(([family, file, weight]) => {
    const face = new FontFace(family, `url(${staticFile(file)}) format('woff2')`, {weight});
    document.fonts.add(face);
    return face.load();
  })).then(() => continueRender(handle)).catch((e) => { console.error(e); continueRender(handle); });
}
export const INTER = "'Inter', 'Liberation Sans', sans-serif";
export const HAND = "'Caveat', cursive";
export const LCD = "'Share Tech Mono', 'DejaVu Sans Mono', monospace";
// The app screens were rendered with this fallback for SF Pro, so overlays drawn on top of them match.
export const APPFONT = "'Liberation Sans', Arial, sans-serif";

export const FPS = 30;

/** Clamped interpolate on absolute seconds. */
export const ip = (t: number, inR: [number, number], outR: [number, number], ease = Easing.bezier(0.45, 0, 0.2, 1)) =>
  interpolate(t, inR, outR, {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: ease});

export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);

/** Opacity for a scene that fades in at a and out at b. */
export const sceneFade = (t: number, a: number, b: number, fin = 0.5, fout = 0.5) =>
  Math.min(ip(t, [a, a + fin], [0, 1]), ip(t, [b - fout, b], [1, 0]));
