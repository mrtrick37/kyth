#!/usr/bin/env python3
"""Regenerate docs/metrics/kythos-users.svg from kythos-users.csv."""

from __future__ import annotations

import csv
import html
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = REPO_ROOT / "docs/metrics/kythos-users.csv"
SVG_PATH = REPO_ROOT / "docs/metrics/kythos-users.svg"


def main() -> None:
    rows = []
    with CSV_PATH.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            rows.append({
                "date": row["date"],
                "users": int(row["users"]),
                "source": row.get("source", ""),
            })
    if not rows:
        raise SystemExit("kythos-users.csv has no data rows")

    max_users = max(1, max(row["users"] for row in rows))
    width, height = 760, 260
    left, top, plot_w, plot_h = 54, 82, 660, 120
    if len(rows) == 1:
        points = [(plot_w, plot_h - (rows[0]["users"] / max_users) * plot_h)]
    else:
        points = [
            (i * plot_w / (len(rows) - 1), plot_h - (row["users"] / max_users) * plot_h)
            for i, row in enumerate(rows)
        ]
    polyline = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    last = rows[-1]
    last_x, last_y = points[-1]
    first_date = html.escape(rows[0]["date"])
    last_date = html.escape(last["date"])
    source = html.escape(last["source"] or "CountMe aggregate")

    SVG_PATH.write_text(f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">
  <title id="title">KythOS reported user count</title>
  <desc id="desc">A line chart for aggregate DNF CountMe reported KythOS users.</desc>
  <rect width="{width}" height="{height}" fill="#0d1117"/>
  <text x="32" y="38" fill="#f0f6fc" font-family="Arial, sans-serif" font-size="22" font-weight="700">KythOS Reported Users</text>
  <text x="32" y="62" fill="#8b949e" font-family="Arial, sans-serif" font-size="13">Aggregate DNF CountMe trend</text>
  <g transform="translate({left} {top})">
    <line x1="0" y1="{plot_h}" x2="{plot_w}" y2="{plot_h}" stroke="#30363d" stroke-width="1"/>
    <line x1="0" y1="{plot_h * 2 / 3:.1f}" x2="{plot_w}" y2="{plot_h * 2 / 3:.1f}" stroke="#21262d" stroke-width="1"/>
    <line x1="0" y1="{plot_h / 3:.1f}" x2="{plot_w}" y2="{plot_h / 3:.1f}" stroke="#21262d" stroke-width="1"/>
    <line x1="0" y1="0" x2="{plot_w}" y2="0" stroke="#21262d" stroke-width="1"/>
    <line x1="0" y1="0" x2="0" y2="{plot_h}" stroke="#30363d" stroke-width="1"/>
    <polyline points="{polyline}" fill="none" stroke="#4fc1ff" stroke-width="4" stroke-linecap="round"/>
    <circle cx="{last_x:.1f}" cy="{last_y:.1f}" r="5" fill="#4fc1ff"/>
    <text x="-36" y="{plot_h + 4}" fill="#8b949e" font-family="Arial, sans-serif" font-size="12">0</text>
    <text x="-42" y="4" fill="#8b949e" font-family="Arial, sans-serif" font-size="12">{max_users}</text>
    <text x="0" y="{plot_h + 26}" fill="#8b949e" font-family="Arial, sans-serif" font-size="12">{first_date}</text>
    <text x="{plot_w - 84}" y="{plot_h + 26}" fill="#8b949e" font-family="Arial, sans-serif" font-size="12">{last_date}</text>
  </g>
  <text x="32" y="232" fill="#8b949e" font-family="Arial, sans-serif" font-size="12">Current reported users: {last["users"]}. Source: {source}.</text>
</svg>
""", encoding="utf-8")


if __name__ == "__main__":
    main()
