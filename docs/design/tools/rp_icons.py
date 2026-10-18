"""Generates Rowing Pals/DesignSystem/RPIcon.swift from the canvas's icons (decision 80).

Every icon in the app is drawn as the design canvas draws it: an outline on a 24 x 24 grid, stroked
with round caps and joins. The SVG markup below is copied from the canvas boards; the ones marked
"drawn to match" have no canvas original and are drawn in the same style. To add or change an icon,
edit ICONS and run:

    python3 -I docs/design/tools/rp_icons.py

Supports <path d>, <circle> and <rect rx>; path commands M L H V C S Q A Z, absolute and relative.
"""

import math
import pathlib
import re

# name: (what it's for, SVG inner markup). Order = the order in RPIcon.
ICONS = {
    # Navigation
    "chevronRight": ("Rows that open something", '<path d="m9 18 6-6-6-6"/>'),
    "chevronLeft": ("Back", '<path d="m15 18-6-6 6-6"/>'),
    "chevronDown": ("A menu or a fold that opens", '<path d="m6 9 6 6 6-6"/>'),
    "chevronUpDown": ("A picker", '<path d="m8 9 4-4 4 4M8 15l4 4 4-4"/>'),
    "close": ("Close, cancel, remove", '<path d="M18 6 6 18M6 6l12 12"/>'),
    "more": ("More options", '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>'),
    "external": ("Opens outside the app", '<path d="M7 17 17 7M8 7h9v9"/>'),
    # Tabs
    "home": ("Feed tab", '<path d="m3 11 9-7 9 7v9h-6v-6H9v6H3z"/>'),
    "rankings": ("Rankings tab", '<path d="M5 20v-7h4v7M10 20V7h4v13M15 20v-10h4v10"/>'),
    "calendar": ("Calendar tab, a practice", '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/>'),
    "profile": ("Profile tab, a person", '<path d="M4.5 21a7.5 7.5 0 0 1 15 0"/><circle cx="12" cy="8" r="4"/>'),
    "people": ("Rowers tab, squads, set by", '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>'),
    "stopwatch": ("Workouts tab, a land session", '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5M9.5 2.5h5"/>'),
    "boat": ("Boats tab", '<path d="M12 2c2 3 2.6 6 2.6 10S14 19 12 22c-2-3-2.6-6-2.6-10S10 5 12 2z"/><path d="M9.6 8 4 6.5M14.4 11 20 9.5M9.6 14 4 12.5M14.4 17 20 15.5"/>'),
    # Actions
    "plus": ("Add, Log", '<path d="M12 5v14M5 12h14"/>'),
    "plusCircle": ("Add a boat", '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>'),
    "check": ("Done, chosen, available", '<path d="M5 12.5 10 17l9-10"/>'),
    "search": ("Search", '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>'),
    "filter": ("Filters and sort", '<path d="M4 6h16M7 12h10M10 18h4"/>'),
    "sort": ("Order", '<path d="M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4"/>'),
    "trash": ("Delete", '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>'),
    "share": ("Share", '<path d="M12 16V3M7 8l5-5 5 5M5 13v7h14v-7"/>'),
    "comment": ("Comments", '<path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z"/>'),
    "send": ("Send a comment", '<path d="M12 19V5M5 12l7-7 7 7"/>'),
    "switchMode": ("Switch between rowing and coaching", '<path d="M17 2l4 4-4 4"/><path d="M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4"/><path d="M21 13v2a3 3 0 0 1-3 3H3"/>'),
    "flipCamera": ("Flip the camera", '<path d="M7 7h11l-3-3M17 17H6l3 3"/>'),
    "photo": ("Choose from library", '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m3 16 5-5 4 4 3-3 6 6"/>'),
    "settings": ("Settings", '<path d="m9 3-.6 2.3-2 .9-2.1-.6-2 3.4 1.6 1.7v2.6l-1.6 1.7 2 3.4 2.1-.6 2 .9L9 21h4l.6-2.3 2-.9 2.1.6 2-3.4-1.6-1.7v-2.6L19.7 9l-2-3.4-2.1.6-2-.9L13 3z"/><circle cx="11" cy="12" r="3"/>'),
    # Things
    "water": ("Water: the chip, a water session", '<path d="M2 15c2.5 0 2.5-2 5-2s2.5 2 5 2 2.5-2 5-2 2.5 2 5 2M2 20c2.5 0 2.5-2 5-2s2.5 2 5 2 2.5-2 5-2 2.5 2 5 2M2 10c2.5 0 2.5-2 5-2s2.5 2 5 2 2.5-2 5-2 2.5 2 5 2"/>'),
    "flag": ("A race, report", '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'),
    "megaphone": ("An announcement", '<path d="M3 10v4a1 1 0 0 0 1 1h3l6 4V5L7 9H4a1 1 0 0 0-1 1z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>'),
    "peopleCheck": ("Who's available", '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="m16 11 2 2 4-4"/>'),
    "clock": ("A time, another event", '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
    "pin": ("A place", '<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>'),
    "warning": ("A flag on a rower", '<path d="M12 3 2 20h20z"/><path d="M12 10v4M12 17h.01"/>'),
    "eye": ("Who can see it", '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>'),
    "clipboard": ("A coach's account", '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 10h6M9 14h6M9 18h3"/>'),
    # Drawn to match (no canvas original)
    "lock": ("A private account (drawn to match)", '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>'),
    "info": ("How we got this (drawn to match)", '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.5h.01"/>'),
    "star": ("Shown first (drawn to match)", '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.9z"/>'),
    "pencil": ("Edit (drawn to match)", '<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>'),
    "camera": ("Change photo (drawn to match)", '<path d="M4 8.5A2.5 2.5 0 0 1 6.5 6H8l1.5-2h5L16 6h1.5A2.5 2.5 0 0 1 20 8.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 17.5z"/><circle cx="12" cy="13" r="3.5"/>'),
    "scan": ("Read a monitor photo (drawn to match)", '<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M8 10h8M8 14h5"/>'),
    "block": ("Block (drawn to match)", '<circle cx="12" cy="12" r="9"/><path d="m5.6 5.6 12.8 12.8"/>'),
    "tag": ("A note on a rower (drawn to match)", '<path d="M3 12V4h8l10 10-8 8z"/><path d="M7.5 8.5h.01"/>'),
    "list": ("The plan (drawn to match)", '<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>'),
    "checkCircle": ("Checked in (drawn to match)", '<circle cx="12" cy="12" r="9"/><path d="m8 12.5 3 3 5-6"/>'),
    "clear": ("Clear a field (drawn to match)", '<circle cx="12" cy="12" r="9"/><path d="m9 9 6 6M15 9l-6 6"/>'),
    "checkbox": ("A tick box, empty (drawn to match)", '<rect x="4" y="4" width="16" height="16" rx="4"/>'),
    "checkboxOn": ("A tick box, ticked (drawn to match)", '<rect x="4" y="4" width="16" height="16" rx="4"/><path d="m8 12.5 3 3 5-6"/>'),
}


def fmt(v):
    v = round(v, 3)
    if v == int(v):
        return str(int(v))
    return f"{v}".rstrip("0").rstrip(".")


def pt(x, y):
    return f".init(x: {fmt(x)}, y: {fmt(y)})"


def arc_to_cubics(x1, y1, rx, ry, phi, large, sweep, x2, y2):
    """SVG elliptical arc -> cubic Béziers (the W3C endpoint-to-centre conversion)."""
    if rx == 0 or ry == 0:
        return [("L", x2, y2)]
    rx, ry = abs(rx), abs(ry)
    cp, sp = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    lam = (x1p ** 2) / (rx ** 2) + (y1p ** 2) / (ry ** 2)
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    co = math.sqrt(max(0, num / den)) if den else 0
    if large == sweep:
        co = -co
    cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)

    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    segs = max(1, math.ceil(abs(dt) / (math.pi / 2)))
    d = dt / segs
    out = []
    for i in range(segs):
        a1, a2 = t1 + i * d, t1 + (i + 1) * d
        k = 4 / 3 * math.tan((a2 - a1) / 4)

        def p(a):
            x, y = rx * math.cos(a), ry * math.sin(a)
            return cp * x - sp * y + cx, sp * x + cp * y + cy

        def dp(a):
            x, y = -rx * math.sin(a), ry * math.cos(a)
            return cp * x - sp * y, sp * x + cp * y

        s, e = p(a1), p(a2)
        d1, d2 = dp(a1), dp(a2)
        out.append(("C", s[0] + k * d1[0], s[1] + k * d1[1], e[0] - k * d2[0], e[1] - k * d2[1], e[0], e[1]))
    return out


def path_ops(d):
    tokens = re.findall(r"[MmLlHhVvCcSsQqAaZz]|-?(?:\d+\.\d*|\.\d+|\d+)", d)
    ops, i = [], 0
    x = y = sx = sy = 0.0
    last_c = None
    cmd = None

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if re.match(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1
        rel = cmd.islower()
        c = cmd.upper()
        if c == "Z":
            ops.append(("Z",))
            x, y = sx, sy
            last_c = None
            continue
        if c == "M":
            nx, ny = num(), num()
            if rel:
                nx, ny = nx + x, ny + y
            ops.append(("M", nx, ny))
            x, y, sx, sy = nx, ny, nx, ny
            cmd = "l" if rel else "L"
            last_c = None
        elif c == "L":
            nx, ny = num(), num()
            if rel:
                nx, ny = nx + x, ny + y
            ops.append(("L", nx, ny))
            x, y = nx, ny
            last_c = None
        elif c == "H":
            nx = num()
            x = nx + x if rel else nx
            ops.append(("L", x, y))
            last_c = None
        elif c == "V":
            ny = num()
            y = ny + y if rel else ny
            ops.append(("L", x, y))
            last_c = None
        elif c in "CS":
            if c == "C":
                c1x, c1y = num(), num()
                if rel:
                    c1x, c1y = c1x + x, c1y + y
            else:
                c1x, c1y = (2 * x - last_c[0], 2 * y - last_c[1]) if last_c else (x, y)
            c2x, c2y, nx, ny = num(), num(), num(), num()
            if rel:
                c2x, c2y, nx, ny = c2x + x, c2y + y, nx + x, ny + y
            ops.append(("C", c1x, c1y, c2x, c2y, nx, ny))
            last_c = (c2x, c2y)
            x, y = nx, ny
        elif c == "Q":
            qx, qy, nx, ny = num(), num(), num(), num()
            if rel:
                qx, qy, nx, ny = qx + x, qy + y, nx + x, ny + y
            ops.append(("Q", qx, qy, nx, ny))
            x, y = nx, ny
            last_c = None
        elif c == "A":
            rx, ry, phi = num(), num(), num()
            large, sweep = int(num()), int(num())
            nx, ny = num(), num()
            if rel:
                nx, ny = nx + x, ny + y
            ops.extend(arc_to_cubics(x, y, rx, ry, phi, large, sweep, nx, ny))
            x, y = nx, ny
            last_c = None
    return ops


def swift_for(markup):
    lines = []
    for tag, attrs in re.findall(r"<(path|circle|rect)\s+([^>]*?)/?>", markup):
        a = dict(re.findall(r'([\w-]+)="([^"]*)"', attrs))
        if tag == "path":
            for op in path_ops(a["d"]):
                if op[0] == "M":
                    lines.append(f"p.move(to: {pt(op[1], op[2])})")
                elif op[0] == "L":
                    lines.append(f"p.addLine(to: {pt(op[1], op[2])})")
                elif op[0] == "C":
                    lines.append(f"p.addCurve(to: {pt(op[5], op[6])}, control1: {pt(op[1], op[2])}, control2: {pt(op[3], op[4])})")
                elif op[0] == "Q":
                    lines.append(f"p.addQuadCurve(to: {pt(op[3], op[4])}, control: {pt(op[1], op[2])})")
                elif op[0] == "Z":
                    lines.append("p.closeSubpath()")
        elif tag == "circle":
            cx, cy, r = float(a["cx"]), float(a["cy"]), float(a["r"])
            lines.append(f"p.addEllipse(in: CGRect(x: {fmt(cx - r)}, y: {fmt(cy - r)}, width: {fmt(2 * r)}, height: {fmt(2 * r)}))")
        elif tag == "rect":
            x, y, w, h = (float(a[k]) for k in ("x", "y", "width", "height"))
            rx = float(a.get("rx", 0))
            lines.append(f"p.addRoundedRect(in: CGRect(x: {fmt(x)}, y: {fmt(y)}, width: {fmt(w)}, height: {fmt(h)}), "
                         f"cornerSize: CGSize(width: {fmt(rx)}, height: {fmt(rx)}))")
    return lines


def main():
    root = pathlib.Path(__file__).resolve().parents[3]
    out = root / "Rowing Pals" / "DesignSystem" / "RPIcon.swift"
    cases = "\n".join(f"    /// {why}.\n    case {name}" for name, (why, _) in ICONS.items())
    switch = []
    for name, (_, markup) in ICONS.items():
        body = "\n".join("            " + line for line in swift_for(markup))
        switch.append(f"        case .{name}:\n{body}")
    text = f"""//
//  RPIcon.swift
//  Rowing Pals
//
//  Generated by docs/design/tools/rp_icons.py from the design canvas's icons — edit the script, not
//  this file.

import SwiftUI

/// Every icon in the app, drawn as the design canvas draws them (decision 80): an outline on a
/// 24 × 24 grid, stroked with round caps and joins. Drawn with `RPIconView`; never SF Symbols.
enum RPIcon: String, CaseIterable, Sendable {{
{cases}

    /// The outline in a 24 × 24 box.
    var outline: Path {{
        var p = Path()
        switch self {{
{chr(10).join(switch)}
        }}
        return p
    }}
}}
"""
    out.write_text(text, encoding="utf-8")
    print(f"Wrote {out} ({len(ICONS)} icons)")


if __name__ == "__main__":
    main()
