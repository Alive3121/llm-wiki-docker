#!/usr/bin/env python3
"""Generate wiki/assets/home-cooking-flavor-radar.svg (五味雷达图, small multiples).

Scores mirror the table in wiki/home-cooking-flavor-comparison.md and the atom
home-cooking/flavor-scores-twenty-dishes. Change them there first, then here, then rerun:
    python scripts/gen-flavor-radar.py
"""
import math
import os

AXES = ["辣", "酸", "甜", "油", "咸"]

# (group label, [(dish, [辣, 酸, 甜, 油, 咸]), ...])
GROUPS = [
    ("清淡基准", [("白切鸡", [1, 1, 1, 2, 2]), ("清蒸鲈鱼", [1, 1, 1, 2, 2]),
              ("鲫鱼豆腐汤", [1, 1, 1, 1, 1]), ("青椒肉丝", [2, 1, 1, 3, 3])]),
    ("酸为主", [("西红柿炒鸡蛋", [1, 4, 3, 2, 2]), ("酸汤肥牛", [3, 5, 2, 2, 3]),
             ("酸辣土豆丝", [3, 4, 1, 2, 2]), ("酸菜鱼", [4, 4, 1, 3, 3])]),
    ("甜为主", [("糖醋排骨", [1, 4, 5, 3, 3]), ("糖醋里脊", [1, 5, 5, 5, 2]),
             ("可乐鸡翅", [1, 1, 5, 2, 3]), ("京酱肉丝", [1, 1, 4, 3, 5])]),
    ("油咸与复合", [("红烧肉", [1, 1, 4, 4, 4]), ("梅菜扣肉", [1, 1, 3, 5, 5]),
               ("地三鲜", [1, 1, 2, 5, 4]), ("鱼香肉丝", [3, 3, 3, 3, 4])]),
    ("辣为主", [("口水鸡", [4, 3, 3, 4, 3]), ("麻婆豆腐", [5, 1, 1, 4, 5]),
             ("辣子鸡", [5, 1, 2, 5, 4]), ("水煮肉片", [5, 1, 1, 5, 4])]),
]

CELL_W, CELL_H = 190, 206
LEFT, TOP = 96, 64
R = 58          # radius for score 5
COLS = 4

W = LEFT + CELL_W * COLS + 16
H = TOP + CELL_H * len(GROUPS) + 24


def pt(cx, cy, i, v):
    a = -math.pi / 2 + i * 2 * math.pi / len(AXES)
    r = R * v / 5
    return cx + r * math.cos(a), cy + r * math.sin(a)


def poly(cx, cy, vals):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in (pt(cx, cy, i, v) for i, v in enumerate(vals)))


out = []
out.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
           f'role="img" aria-label="20 道家常菜五味雷达图：辣、酸、甜、油、咸，各 1 到 5 分">')
out.append("""<style>
  :root { --surface:#fcfcfb; --ink:#0b0b0b; --ink2:#52514e; --muted:#898781; --grid:#e1e0d9; --axis:#c3c2b7; --s1:#2a78d6; }
  @media (prefers-color-scheme: dark) {
    :root { --surface:#1a1a19; --ink:#f0efec; --ink2:#c3c2b7; --muted:#898781; --grid:#2c2c2a; --axis:#383835; --s1:#3987e5; }
  }
  text { font-family: "PingFang SC","Microsoft YaHei","Noto Sans CJK SC",sans-serif; }
  .bg { fill: var(--surface); }
  .title { fill: var(--ink); font-size: 18px; font-weight: 600; }
  .sub { fill: var(--ink2); font-size: 12px; }
  .grp { fill: var(--ink2); font-size: 13px; font-weight: 600; }
  .name { fill: var(--ink); font-size: 14px; font-weight: 600; }
  .ax { fill: var(--muted); font-size: 11px; }
  .ring { fill: none; stroke: var(--grid); stroke-width: 1; }
  .spoke { stroke: var(--axis); stroke-width: 1; }
  .shape { fill: var(--s1); fill-opacity: .22; stroke: var(--s1); stroke-width: 2; stroke-linejoin: round; }
  .dot { fill: var(--s1); stroke: var(--surface); stroke-width: 2; }
</style>""")
out.append(f'<rect class="bg" width="{W}" height="{H}"/>')
out.append(f'<text class="title" x="16" y="28">家常菜五味雷达图</text>')
out.append(f'<text class="sub" x="16" y="48">辣 · 酸 · 甜 · 油 · 咸，每项 1–5 分；外圈 = 5 分。依据 raw/recipe_corpus_full.json 统计 + 判断</text>')

for gi, (glabel, dishes) in enumerate(GROUPS):
    gy = TOP + gi * CELL_H
    out.append(f'<text class="grp" x="16" y="{gy + CELL_H / 2 + 4:.0f}">{glabel}</text>')
    for di, (name, vals) in enumerate(dishes):
        cx = LEFT + di * CELL_W + CELL_W / 2
        cy = gy + 36 + R + 14
        out.append(f'<g><title>{name}：' + "，".join(f"{a}{v}" for a, v in zip(AXES, vals)) + '</title>')
        out.append(f'<text class="name" x="{cx:.0f}" y="{gy + 22}" text-anchor="middle">{name}</text>')
        for lv in range(1, 6):
            out.append(f'<polygon class="ring" points="{poly(cx, cy, [lv] * 5)}"/>')
        for i, a in enumerate(AXES):
            x, y = pt(cx, cy, i, 5)
            out.append(f'<line class="spoke" x1="{cx:.1f}" y1="{cy:.1f}" x2="{x:.1f}" y2="{y:.1f}"/>')
            lx, ly = pt(cx, cy, i, 6.1)
            out.append(f'<text class="ax" x="{lx:.1f}" y="{ly + 4:.1f}" text-anchor="middle">{a}</text>')
        out.append(f'<polygon class="shape" points="{poly(cx, cy, vals)}"/>')
        for i, v in enumerate(vals):
            x, y = pt(cx, cy, i, v)
            out.append(f'<circle class="dot" cx="{x:.1f}" cy="{y:.1f}" r="4"/>')
        out.append('</g>')
out.append('</svg>')

dst = os.path.join(os.path.dirname(__file__), "..", "wiki", "assets", "home-cooking-flavor-radar.svg")
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("wrote", os.path.normpath(dst))
