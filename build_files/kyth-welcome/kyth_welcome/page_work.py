import os
import shutil
import subprocess

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    Worker, _install_flatpak_inline, _is_flatpak_installed,
)
from .qt import (  # noqa: E501
    QHBoxLayout, QLabel, QPushButton,
)
from .widgets import (  # noqa: E501
    Page, _make_card,
)

# Work-bundle apps offered on this page (and pre-selected by the first-run
# wizard when the user picks the Work or Both profile).
_WORK_APPS = [
    ("org.libreoffice.LibreOffice", "LibreOffice",
     "Writer, Calc, and Impress — opens and saves Word, Excel, and PowerPoint files."),
    ("org.mozilla.Thunderbird", "Thunderbird",
     "Desktop email, calendar, and contacts — connects to Microsoft 365, Gmail, and IMAP accounts."),
]

_M365_APPS = [
    ("Outlook",    "https://outlook.office.com/mail/",               "Email and calendar"),
    ("Word",       "https://office.live.com/start/Word.aspx",       "Documents"),
    ("Excel",      "https://office.live.com/start/Excel.aspx",      "Spreadsheets"),
    ("PowerPoint", "https://office.live.com/start/PowerPoint.aspx", "Presentations"),
    ("OneNote",    "https://www.onenote.com/notebooks",              "Notes"),
    ("Teams",      "https://teams.microsoft.com/",                   "Chat and meetings"),
]

_MS_FONTS_DIR = os.path.expanduser("~/.local/share/fonts/msttcorefonts")


def _ms_fonts_installed() -> bool:
    try:
        return any(entry.lower().endswith(".ttf") for entry in os.listdir(_MS_FONTS_DIR))
    except OSError:
        return False


def _m365_desktop_entry(name: str, url: str, comment: str) -> str:
    wm_class = f"Microsoft365-{name}"
    return (
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={name} (Microsoft 365)\n"
        f"Comment={comment}\n"
        f"Exec=chromium-browser --app={url} --class={wm_class} --name={wm_class}\n"
        "Icon=internet-web-browser\n"
        "Categories=Office;Network;\n"
        f"StartupWMClass={wm_class}\n"
    )


def _create_m365_shortcuts() -> int:
    """Write launcher .desktop entries for the Microsoft 365 web apps.

    Returns the number of shortcuts written."""
    apps_dir = os.path.expanduser("~/.local/share/applications")
    written = 0
    try:
        os.makedirs(apps_dir, exist_ok=True)
    except OSError:
        return 0
    for name, url, comment in _M365_APPS:
        path = os.path.join(apps_dir, f"kyth-m365-{name.lower()}.desktop")
        try:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(_m365_desktop_entry(name, url, comment))
            written += 1
        except OSError:
            pass
    return written


def _m365_shortcuts_present() -> bool:
    apps_dir = os.path.expanduser("~/.local/share/applications")
    return all(
        os.path.exists(os.path.join(apps_dir, f"kyth-m365-{name.lower()}.desktop"))
        for name, _, _ in _M365_APPS
    )


# ── Page: Work Setup ──────────────────────────────────────────────────────────
class WorkSetupPage(Page):
    """Guided checklist that makes a fresh install Monday-morning ready:
    office apps, Microsoft 365 shortcuts, document fonts, VPN, shares,
    cloud sync, and printing — threading the existing Hub pages together."""

    def __init__(self, navigate=None):
        super().__init__()
        self._navigate = navigate or (lambda _: None)
        self._ms_fonts_worker: Worker | None = None

        self._page_header(
            "Apps",
            "Work Setup",
            "Everything a work machine needs before Monday morning: office apps, email, "
            "Microsoft 365, document fonts, VPN, network shares, cloud sync, and printing. "
            "Each step is optional — set up only what your workplace uses.",
        )

        self._add(self._make_work_apps_card())
        self._add(self._make_m365_card())
        self._add(self._make_fonts_card())
        self._add(self._make_connect_card())
        self._stretch()

    # ── Office & email apps ────────────────────────────────────────────────
    def _make_work_apps_card(self):
        card, layout = _make_card()
        title = QLabel("1. Office and email apps")
        title.setObjectName("card-title")
        layout.addWidget(title)
        copy = QLabel(
            "LibreOffice covers Word, Excel, and PowerPoint files. Thunderbird handles "
            "work email and calendars. Both install from Flathub in one click."
        )
        copy.setObjectName("card-copy")
        copy.setWordWrap(True)
        layout.addWidget(copy)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        for app_id, name, desc in _WORK_APPS:
            btn = QPushButton(f"Install {name}")
            btn.setToolTip(desc)
            if _is_flatpak_installed(app_id):
                btn.setText(f"✓ {name} installed")
                btn.setEnabled(False)
            else:
                btn.setObjectName("primary")
                btn.clicked.connect(
                    lambda _=False, b=btn, a=app_id, n=name: _install_flatpak_inline(self, b, a, n)
                )
            btns.addWidget(btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    # ── Microsoft 365 web apps ─────────────────────────────────────────────
    def _make_m365_card(self):
        card, layout = _make_card()
        title = QLabel("2. Microsoft 365 — web app shortcuts")
        title.setObjectName("card-title")
        layout.addWidget(title)
        copy = QLabel(
            "If your workplace uses Microsoft 365, the full suite runs in the browser. "
            "Add launcher shortcuts so Outlook, Teams, Word, and the rest open in their "
            "own windows from the app menu — pinnable to the taskbar like native apps."
        )
        copy.setObjectName("card-copy")
        copy.setWordWrap(True)
        layout.addWidget(copy)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        self._m365_btn = QPushButton("Add Microsoft 365 to App Launcher")
        if _m365_shortcuts_present():
            self._m365_btn.setText("✓ Shortcuts added — find them in the app menu")
            self._m365_btn.setEnabled(False)
        else:
            self._m365_btn.setObjectName("primary")
        self._m365_btn.clicked.connect(self._on_add_m365)
        btns.addWidget(self._m365_btn)

        for name, url, tip in _M365_APPS[:2]:
            open_btn = QPushButton(f"Open {name}")
            open_btn.setToolTip(f"{tip} — opens in a dedicated window")
            open_btn.clicked.connect(
                lambda _=False, u=url, n=name: subprocess.Popen([
                    "chromium-browser", f"--app={u}",
                    f"--class=Microsoft365-{n}", f"--name=Microsoft365-{n}",
                ])
            )
            btns.addWidget(open_btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    def _on_add_m365(self):
        written = _create_m365_shortcuts()
        if written == len(_M365_APPS):
            self._m365_btn.setText("✓ Shortcuts added — find them in the app menu")
            self._m365_btn.setEnabled(False)
        else:
            self._m365_btn.setText(f"Added {written} of {len(_M365_APPS)} — try again")

    # ── Microsoft fonts ────────────────────────────────────────────────────
    def _make_fonts_card(self):
        card, layout = _make_card()
        title = QLabel("3. Microsoft fonts — keep document formatting intact")
        title.setObjectName("card-title")
        layout.addWidget(title)
        copy = QLabel(
            "Documents from Windows colleagues use fonts like Times New Roman and Arial. "
            "Installing them keeps layouts pixel-identical instead of substituted."
        )
        copy.setObjectName("card-copy")
        copy.setWordWrap(True)
        layout.addWidget(copy)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        self._fonts_btn = QPushButton("Install Microsoft Fonts")
        if _ms_fonts_installed():
            self._fonts_btn.setText("✓ Microsoft fonts installed")
            self._fonts_btn.setEnabled(False)
        else:
            self._fonts_btn.setObjectName("primary")
        self._fonts_btn.clicked.connect(self._on_install_fonts)
        btns.addWidget(self._fonts_btn)
        btns.addStretch()
        layout.addLayout(btns)

        self._fonts_status = QLabel("")
        self._fonts_status.setObjectName("card-copy")
        self._fonts_status.setWordWrap(True)
        self._fonts_status.hide()
        layout.addWidget(self._fonts_status)
        return card

    def _on_install_fonts(self):
        if self._ms_fonts_worker is not None and self._ms_fonts_worker.isRunning():
            return
        self._fonts_btn.setEnabled(False)
        self._fonts_btn.setText("Installing…")
        self._fonts_status.setText("Downloading Microsoft core fonts…")
        self._fonts_status.show()
        self._ms_fonts_worker = Worker(["bash", "-c", "ujust install-ms-fonts"])
        self._ms_fonts_worker.done.connect(self._on_fonts_done)
        self._ms_fonts_worker.start()

    def _on_fonts_done(self, code: int):
        if code == 0:
            self._fonts_btn.setText("✓ Microsoft fonts installed")
            self._fonts_status.setText("✓ Done. Restart LibreOffice to pick up the new fonts.")
        else:
            self._fonts_btn.setEnabled(True)
            self._fonts_btn.setText("Install Microsoft Fonts")
            self._fonts_status.setText("✗ Installation failed. Check your network connection and try again.")

    # ── Workplace connections ──────────────────────────────────────────────
    def _make_connect_card(self):
        card, layout = _make_card()
        title = QLabel("4. Connect to your workplace")
        title.setObjectName("card-title")
        layout.addWidget(title)
        copy = QLabel(
            "Each of these opens the matching setup page. Have your IT details handy: "
            "VPN gateway address, share paths (\\\\server\\share), and printer name."
        )
        copy.setObjectName("card-copy")
        copy.setWordWrap(True)
        layout.addWidget(copy)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        for label, page_key in (
            ("Set up VPN", "VPN"),
            ("Mount Network Shares", "Network Shares"),
            ("Sync Cloud Storage", "Cloud Storage"),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, k=page_key: self._navigate(k))
            btns.addWidget(btn)

        printer_btn = QPushButton("Add a Printer")
        printer_btn.setToolTip("Opens KDE printer settings. Network printers are usually detected automatically.")
        printer_btn.clicked.connect(self._open_printer_settings)
        btns.addWidget(printer_btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    @staticmethod
    def _open_printer_settings():
        if shutil.which("kcmshell6"):
            subprocess.Popen(["kcmshell6", "kcm_printer_manager"])
        else:
            subprocess.Popen(["systemsettings", "kcm_printer_manager"])
