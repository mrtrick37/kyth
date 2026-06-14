import sys
import traceback

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    _IS_LIVE, _is_first_run, _prefer_xwayland_if_wayland_plugin_missing, _remove_autostart, _wait_for_display_setup,
)
from .qt import (  # noqa: E501
    QApplication, QIcon,
)
from .theme import (  # noqa: E501
    QSS,
)
from .windows import (  # noqa: E501
    MainWindow, WizardWindow,
)

# ── Entry point ───────────────────────────────────────────────────────────────
def main():
    # Parse --page PAGEKEY before QApplication (which may strip unrecognised args)
    start_page = None
    raw_args = sys.argv[1:]
    for i, a in enumerate(raw_args):
        if a == "--page" and i + 1 < len(raw_args):
            start_page = raw_args[i + 1]

    _wait_for_display_setup()
    _prefer_xwayland_if_wayland_plugin_missing()

    # PyQt6 calls qFatal() (abort + core dump) on any uncaught Python exception
    # in a slot unless an excepthook is installed. Log and keep the app alive.
    def _log_uncaught(exc_type, exc_value, exc_tb):
        traceback.print_exception(exc_type, exc_value, exc_tb, file=sys.stderr)
    sys.excepthook = _log_uncaught

    app = QApplication(sys.argv)
    app.setApplicationName("kyth-welcome")
    app.setDesktopFileName("kyth-welcome")
    app.setWindowIcon(QIcon.fromTheme("kyth"))
    app.setStyleSheet(QSS)

    if _IS_LIVE:
        win = MainWindow()
    elif _is_first_run():
        win = WizardWindow()
    else:
        win = MainWindow()
    win.setWindowIcon(QIcon.fromTheme("kyth"))
    win.showMaximized()
    if start_page and isinstance(win, MainWindow):
        win._navigate_to(start_page)
    _remove_autostart()
    sys.exit(app.exec())
