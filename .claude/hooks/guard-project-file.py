#!/usr/bin/env python3
"""PreToolUse hook: refuse edits to the Xcode project file.

CLAUDE.md forbids hand-editing project.pbxproj. This turns that from a rule the
model is asked to follow into one it cannot break. Source files belong in the
synchronised folder, where Xcode picks them up automatically.
"""
import json
import sys

BLOCKED_FRAGMENTS = ("project.pbxproj", ".xcodeproj/", ".xcworkspace/")

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # unparseable input: stay out of the way

tool_input = payload.get("tool_input") or {}
path = str(
    tool_input.get("file_path")
    or tool_input.get("path")
    or tool_input.get("notebook_path")
    or ""
)

if any(fragment in path for fragment in BLOCKED_FRAGMENTS):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                "Blocked by project policy: never hand-edit the Xcode project file. "
                "Source files go in the synchronised folder and Xcode picks them up "
                "automatically. If a file is not being compiled, say so and stop — "
                "do not edit project structure to fix it."
            ),
        }
    }))

sys.exit(0)
