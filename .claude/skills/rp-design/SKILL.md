---
name: rp-design
description: Capture a Claude Design handoff bundle into the repository so it survives past this session. Use immediately after a Send to Claude Code handoff, or when the user types /rp-design.
argument-hint: "[screen name, e.g. feed]"
---

# Capture the design handoff

A handoff bundle lives only in this session's context. Once the session ends it is gone, and a
future session rebuilding this screen has nothing to work from. Write it down now.

## Procedure

1. **Summarise what you received.** List every component in the hierarchy, every design token,
   every layout relationship, and every referenced asset. If you did **not** receive a handoff
   bundle in this session, say so plainly and stop — do not invent a summary from the design
   brief, and do not proceed as though a bundle arrived.

2. **Write it to the repo** at `docs/design/$ARGUMENTS-spec.md`, structured as:

   ```
   # <Screen name> — design handoff
   Captured: <date>

   ## Component hierarchy
   ## Tokens used
   ## Layout and spacing
   ## Assets
   ## Interaction notes
   ```

   Record real values — actual spacing, actual token names, actual sizes. A spec that says
   "generous padding" is worthless to the session that reads it next.

3. **Save the assets** into `docs/design/assets/` and reference them by path from the spec.

4. **Confirm** the file was written and report its path.

5. **Then say** whether the screen is ready to build, and which numbered task in
   `.claude/skills/rp-task/tasks.md` covers it.

## Note for the user

Ask them to also export the artboard as a PNG to `docs/design/$ARGUMENTS.png`. That image is
what `/rp-verify` compares screenshots against later.
