#!/usr/bin/env python3
"""Headless driver for KythOS System Hub (kyth-welcome). See SKILL.md.

Usage:
  python3 driver.py list-pages
  python3 driver.py shoot <page-key> <out.png> [--timeout SECONDS]

Bypasses kyth_welcome.app:main() entirely so it never touches the
single-instance lock file at ~/.cache/kyth/kyth-welcome.lock, and never
calls _wait_for_display_setup()/_prefer_xwayland_if_wayland_plugin_missing()
(both no-ops under the offscreen platform anyway).
"""
import argparse
import os
import sys
import time
from pathlib import Path

# The driver adds the packaged kyth-welcome source tree to sys.path at runtime.
# pylint: disable=wrong-import-position,import-error

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

# .claude/skills/run-system-hub/driver.py -> kyth-welcome/ (the unit root,
# which holds the kyth_welcome/ package)
_UNIT_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(_UNIT_ROOT))

from kyth_welcome.qt import QApplication  # noqa: E402
from kyth_welcome.theme import QSS  # noqa: E402
from kyth_welcome.windows import MainWindow  # noqa: E402


def _build_app() -> QApplication:
    app = QApplication(sys.argv[:1])
    app.setStyleSheet(QSS)
    return app


def cmd_list_pages(_args: argparse.Namespace) -> None:
    """Print every available System Hub page key."""
    _build_app()
    win = MainWindow()
    page_index = getattr(win, "_page_index_by_key")
    for key in sorted(page_index):
        print(key)


def cmd_shoot(args: argparse.Namespace) -> None:
    """Capture a screenshot for the requested System Hub page."""
    app = _build_app()
    win = MainWindow()
    win.resize(1920, 1150)
    navigate_to = getattr(win, "_navigate_to")
    navigate_to(args.page)
    win.show()

    # Pages like Hardware kick off a HardwareProbeWorker QThread (lspci /
    # lsusb / lsmod / vainfo etc.) that renders "Running hardware probes..."
    # until it finishes. Poll instead of a fixed sleep so static pages
    # (no _worker attribute) return almost instantly.
    deadline = time.time() + args.timeout
    while time.time() < deadline:
        app.processEvents()
        page_stack = getattr(win, "_stack")
        page = page_stack.currentWidget()
        worker = getattr(page, "_worker", None)
        if worker is None or not worker.isRunning():
            for _ in range(5):  # let the UI repaint with final probe results
                app.processEvents()
                time.sleep(0.05)
            break
        time.sleep(0.05)

    pix = win.grab()
    pix.save(args.out)
    print(f"saved {args.out}")


def main() -> None:
    """Run the selected headless System Hub driver command."""
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list-pages", help="print every valid --page/shoot key")
    p_list.set_defaults(func=cmd_list_pages)

    p_shoot = sub.add_parser("shoot", help="navigate to a page and save a screenshot")
    p_shoot.add_argument(
        "page",
        help='page key, e.g. "Welcome" (Home) or "Hardware" - see list-pages',
    )
    p_shoot.add_argument("out", help="output PNG path")
    p_shoot.add_argument(
        "--timeout",
        type=float,
        default=25.0,
        help="max seconds to wait for async probes",
    )
    p_shoot.set_defaults(func=cmd_shoot)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
