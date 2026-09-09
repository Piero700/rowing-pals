---
name: rp-task
description: Run one numbered Rowing Pals build task (01-19) end to end, including its verification step. Use when the user types /rp-task followed by a number, or asks to start or continue a numbered build task.
argument-hint: "[task number 01-19]"
---

# Rowing Pals build task runner

The user wants build task **$ARGUMENTS** carried out.

## Procedure

1. **Find the task.** Read `tasks.md` in this skill's directory and locate the task numbered
   `$ARGUMENTS`. If no number was given, list all nineteen task titles with their numbers and
   ask which one — do not guess.

2. **Read the binding spec.** Every task names sections of `docs/design-brief.md`. Read those
   sections before writing anything. The brief is binding, not advisory. If a task also names
   `docs/schema.sql`, read that too.

3. **Plan before code.** Present a short plan — files you will create, the approach, anything
   in the task you think is wrong — and wait for approval. Do not begin editing until the user
   approves.

4. **Branch.** `git checkout -b t<NN>-<short-slug>` before the first edit.

5. **Build only what the task asks for.** Each task is deliberately narrow. If you find
   yourself wanting to add a feature from a later task, stop and ask instead.

6. **Run the Verification block yourself** and report the real output — the actual build
   result, the actual screenshot, the actual query result. Never report a task complete on the
   basis that the code looks right. If verification requires a physical iPhone, say so
   explicitly and give the user the exact steps to run it, then wait for them to report back.

7. **Report differences.** For any UI task, state plainly what differs between your screenshot
   and the brief. "Matches the brief" is only acceptable if you have actually compared them.

## Always applies

- The hard rules in `CLAUDE.md` are absolute, including never editing the Xcode project file
  and never hardcoding a Supabase key.
- Use only the three accent tokens in their reserved roles.
- Every numeral a user reads gets `.monospacedDigit()`.
- Durations are `Int` milliseconds, distances `Int` metres, dates the user's local calendar day.
