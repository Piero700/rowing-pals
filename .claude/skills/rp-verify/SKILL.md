---
name: rp-verify
description: Build Rowing Pals, run it in the simulator, screenshot it, and compare the result against the design brief. Use after any UI change, when the user types /rp-verify, or whenever you are about to claim a UI task is finished.
argument-hint: "[screen name, optional]"
---

# Verify against the design

Never report a UI task complete without running this.

## Procedure

1. **Build** for an iPhone simulator using XcodeBuildMCP. Report the **actual** build output —
   scheme, configuration, and the real success or failure. Do not summarise it as "build
   succeeded" without the output.

2. **Run it.** Boot the simulator, install, launch. If the build failed, stop here and report
   the first error; do not attempt to describe what the screen would have looked like.

3. **Navigate** to the screen named in `$ARGUMENTS`. If no screen was named, use the one just
   changed.

4. **Screenshot it.** Then screenshot again in the other appearance — if you captured dark,
   capture light too. Dark is the primary design; light must still be legible.

5. **Compare.** Against `docs/design/$ARGUMENTS.png` if that file exists, and against the
   relevant section of `docs/design-brief.md`. Report differences as a table:

   | Element | Brief says | Screenshot shows |
   |---|---|---|

6. **Check these every time**, because they are the ones that slip:
   - Only the three accent tokens appear, each in its reserved role. Gold **only** on personal
     bests and podium ranks 1–3; coral **only** on the live capture state.
   - Every numeral a user reads is monospaced.
   - Glass surfaces show a darkened outer edge and a specular rim, not flat translucency.
   - The tab bar floats detached and content scrolls under it.
   - UK English in UI copy — metres, not meters.

7. **State the verdict plainly.** Either "matches the brief" with the comparison shown, or a
   list of what differs. If you did not obtain a screenshot, say that instead of judging.
