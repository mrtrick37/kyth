"""kyth-welcome — KythOS System Hub and first-run wizard.

Shows once on first login (via /etc/skel autostart) and is always
accessible from the application menu as "KythOS System Hub".

Package layout:
    qt.py        Qt binding shim (PySide6 preferred, PyQt6 fallback)
    theme.py     application-wide QSS stylesheet
    core.py      system helpers (bootc, flatpak, probes) and worker threads
    widgets.py   shared UI building blocks (Page base, cards, tiles)
    page_*.py    one module per hub page
    windows.py   MainWindow (hub) and WizardWindow (first run)
    app.py       entry point
"""
