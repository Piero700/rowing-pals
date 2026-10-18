# App screens for the launch film

Source: the design canvas https://claude.ai/artifact/42YP5UcaQKWnfQdERRgLcc (`project/*.dc.html`).

1. Read the artboards into a folder (Artifact tool, `read` with `paths`).
2. `python3 prep.py <that folder>/project src`: resolves the dark-theme tokens and strips the scripts.
3. `node screens.js src clean`: for each screen, removes what the shipped app doesn't have (Calendar tab,
   Trained with, attendance, @username, coach tab bar, prediction advice, the old pieces block), swaps in the
   fictional Wexmoor UBC data, renders the full-length screen at 3x, and writes `<name>.boxes.json`
   (positions the film's overlays use).
4. Copy `clean/*.png` to `remotion/public/screens/` and rebuild `remotion/src/screens.json` (boxes + sizes).

`screens.js` loads Playwright from the marketing-skill plugin's install
(`~/.claude/plugins/marketplaces/marketing-skill/scripts/video/node_modules`); point it at any Playwright.
