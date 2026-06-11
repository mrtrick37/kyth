import os
import subprocess
import time

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    DataWorker, _DEFAULT_FIRST_RUN_APPS, _IS_LIVE, _branch_display_name, _command_stdout, _current_branch, _detect_nvidia, _find_ntfs_drives, _first_run_app_setup_state, _has_rollback_deployment, _has_staged_update, _release_worker_when_finished,
)
from .qt import (  # noqa: E501
    QFrame, QGridLayout, QHBoxLayout, QLabel, QProgressBar, QPushButton, QSize, QSizePolicy, QTimer, QVBoxLayout, Qt,
)
from .widgets import (  # noqa: E501
    Page, StatTile, _make_card, _theme_icon,
)

# ── First-week follow-up ──────────────────────────────────────────────────────
# Anchored to markers that only exist once per install (first-boot flatpak setup
# and the welcome wizard), so installs older than the window never see the card.
_FIRST_WEEK_DISMISS = os.path.expanduser("~/.config/kyth-first-week-done")
_FIRST_BOOT_MARKERS = (
    "/var/lib/kyth/default-flatpaks-v5-done",
    os.path.expanduser("~/.config/kyth-welcome-done"),
)
_FIRST_WEEK_MIN_DAYS = 2   # let the first-boot banner have the spotlight first
_FIRST_WEEK_MAX_DAYS = 30


def _first_week_days() -> int | None:
    """Days since first boot, or None when unknown or already dismissed."""
    if os.path.exists(_FIRST_WEEK_DISMISS):
        return None
    stamps = []
    for marker in _FIRST_BOOT_MARKERS:
        try:
            stamps.append(os.stat(marker).st_mtime)
        except OSError:
            continue
    if not stamps:
        return None
    return int((time.time() - min(stamps)) / 86400)


# ── Page: Welcome (Control Panel-style home) ──────────────────────────────────
class WelcomePage(Page):
    def __init__(self, navigate=None):
        super().__init__()
        self._navigate = navigate or (lambda _: None)

        self._page_header(
            "System Hub",
            "Home",
            "Adjust your system's settings — gaming, apps, updates, and recovery in one place.",
        )

        branch = _branch_display_name(_current_branch())
        staged = _has_staged_update()
        rollback = _has_rollback_deployment()
        kernel = _command_stdout(["uname", "-r"], timeout=5) or "unknown"
        hostname = _command_stdout(["hostname"], timeout=5) or "This PC"
        windows_found = bool(_find_ntfs_drives())

        # Device summary row, like the device card at the top of Settings
        tiles_row = QHBoxLayout()
        tiles_row.setSpacing(10)

        self._device_tile = StatTile("Device", hostname)
        tiles_row.addWidget(self._device_tile, 1)

        self._branch_tile = StatTile("Channel", branch)
        tiles_row.addWidget(self._branch_tile, 1)

        staged_val = "Restart Pending" if staged else "Up to Date"
        staged_style = "stat-value-warn" if staged else "stat-value-ok"
        self._update_tile = StatTile("Updates", staged_val, staged_style)
        tiles_row.addWidget(self._update_tile, 1)

        rollback_val = "Available" if rollback else "None"
        rollback_style = "stat-value-ok" if rollback else "stat-value"
        self._rollback_tile = StatTile("Rollback", rollback_val, rollback_style)
        tiles_row.addWidget(self._rollback_tile, 1)

        self._kernel_tile = StatTile("Kernel", kernel)
        tiles_row.addWidget(self._kernel_tile, 1)

        self._add_layout(tiles_row)

        # ── First-boot app setup banner ───────────────────────────────────────
        # Steam and the other default apps download in the background on first
        # boot; without this banner the app menu just looks broken until they
        # land. Hidden once setup is complete.
        self._setup_card, setup_layout = _make_card("card-accent-warn")
        setup_title = QLabel("Setting up your apps")
        setup_title.setObjectName("card-title")
        setup_layout.addWidget(setup_title)
        self._setup_lbl = QLabel("Checking app setup progress…")
        self._setup_lbl.setObjectName("card-copy")
        self._setup_lbl.setWordWrap(True)
        setup_layout.addWidget(self._setup_lbl)
        self._setup_progress = QProgressBar()
        self._setup_progress.setRange(0, len(_DEFAULT_FIRST_RUN_APPS))
        self._setup_progress.setTextVisible(False)
        setup_layout.addWidget(self._setup_progress)
        self._setup_card.hide()
        self._add(self._setup_card)
        self._setup_worker: DataWorker | None = None
        self._setup_timer = QTimer(self)
        self._setup_timer.setInterval(15000)
        self._setup_timer.timeout.connect(self._poll_first_run_setup)
        if not _IS_LIVE and not os.path.exists("/var/lib/kyth/default-flatpaks-v5-done"):
            self._setup_timer.start()
            QTimer.singleShot(400, self._poll_first_run_setup)

        self._add(self._make_recommended_card(staged, rollback, windows_found))

        # ── First-week tips: the things people discover too late ─────────────
        days = None if _IS_LIVE else _first_week_days()
        if days is not None and _FIRST_WEEK_MIN_DAYS <= days <= _FIRST_WEEK_MAX_DAYS:
            self._add(self._make_first_week_card(days))

        # ── Category grid, like the Control Panel category view ──────────────
        categories: list[tuple[tuple[str, ...], str, str, list[tuple[str, str]]]] = [
            (
                ("applications-games", "input-gaming"), "◉", "Games",
                [
                    ("Set up game launchers", "Gaming"),
                    ("Tune performance", "Performance"),
                    ("Check if your games work", "Compatibility"),
                    ("Connect a controller", "Controllers"),
                ],
            ),
            (
                ("plasmadiscover", "applications-all"), "⬡", "Apps",
                [
                    ("Browse and install apps", "App Store"),
                    ("Move files and saves from Windows", "Move From Windows"),
                ],
            ),
            (
                ("computer", "computer-laptop"), "◈", "System & Security",
                [
                    ("Check for updates", "Update"),
                    ("View hardware and devices", "Hardware"),
                    ("Run a health report", "Diagnostics"),
                    ("Fix problems", "Repair"),
                ],
            ),
            (
                ("folder-network", "network-workgroup"), "◫", "Network & Internet",
                [
                    ("Connect to a VPN", "VPN"),
                    ("Map network shares", "Network Shares"),
                    ("Set up cloud storage", "Cloud Storage"),
                ],
            ),
        ]

        advanced_tasks: list[tuple[str, str]] = []
        if _detect_nvidia():
            advanced_tasks.append(("Manage NVIDIA drivers", "NVIDIA"))
        advanced_tasks.append(("Choose a kernel", "Kernel"))
        advanced_tasks.append(("Pick an update channel", "Channels"))
        categories.append((("cpu", "applications-system"), "◌", "Advanced", advanced_tasks))

        categories.append((
            ("help-contents", "mail-send"), "✉", "Help & Feedback",
            [
                ("Send feedback or report a problem", "Feedback"),
                ("Open repair and recovery tools", "Repair"),
            ],
        ))

        grid = QGridLayout()
        grid.setSpacing(12)
        for i, (icon_names, glyph, title, tasks) in enumerate(categories):
            grid.addWidget(
                self._make_category_card(icon_names, glyph, title, tasks),
                i // 2, i % 2,
            )
        grid.setColumnStretch(0, 1)
        grid.setColumnStretch(1, 1)
        self._add_layout(grid)

        note = QLabel("Reopen this window anytime from the application menu.")
        note.setObjectName("status-dim")
        note.setWordWrap(True)
        self._add(note)
        self._stretch()

    def _poll_first_run_setup(self):
        if self._setup_worker is not None and self._setup_worker.isRunning():
            return
        worker = DataWorker("first-run", _first_run_app_setup_state)
        worker.result.connect(self._on_first_run_state)
        self._setup_worker = worker
        _release_worker_when_finished(self, "_setup_worker", worker)
        worker.start()

    def _on_first_run_state(self, _key: str, state_tuple):
        state, message, missing = state_tuple
        if state in ("ready", "live"):
            self._setup_card.hide()
            self._setup_timer.stop()
            return
        total = len(_DEFAULT_FIRST_RUN_APPS)
        done = max(0, total - len(missing))
        self._setup_progress.setValue(done)
        self._setup_lbl.setText(
            f"{message}  {done} of {total} headline apps are ready — new apps appear "
            "in the launcher as they finish. No action needed."
        )
        self._setup_card.show()

    def _make_first_week_card(self, days: int) -> QFrame:
        card, layout = _make_card()
        title = QLabel(f"Day {days} on KythOS — a few things people find out late")
        title.setObjectName("card-title")
        layout.addWidget(title)
        for text, btn_label, page_key in (
            ("Every update keeps your previous system as a rollback, so trying the "
             "latest is risk-free — restart when it suits you.", "Updates", "Update"),
            ("Set up Ludusavi once and your game saves are backed up before any "
             "modding or library experiments.", "Gaming", "Gaming"),
            ("Something feels off after a change? Repair can roll the whole OS back "
             "to its previous state in one click.", "Repair", "Repair"),
            ("Power-user shortcut: open Konsole and type ujust — every KythOS tweak "
             "is one command away.", None, None),
        ):
            row = QHBoxLayout()
            row.setSpacing(10)
            lbl = QLabel("•  " + text)
            lbl.setObjectName("card-copy")
            lbl.setWordWrap(True)
            row.addWidget(lbl, 1)
            if page_key:
                btn = QPushButton(btn_label)
                btn.clicked.connect(lambda _=False, k=page_key: self._navigate(k))
                row.addWidget(btn, 0, Qt.AlignmentFlag.AlignTop)
            layout.addLayout(row)
        dismiss_row = QHBoxLayout()
        dismiss_btn = QPushButton("Got it — hide this")
        dismiss_btn.clicked.connect(lambda _=False, c=card: self._dismiss_first_week(c))
        dismiss_row.addWidget(dismiss_btn)
        dismiss_row.addStretch()
        layout.addLayout(dismiss_row)
        return card

    def _dismiss_first_week(self, card: QFrame):
        try:
            os.makedirs(os.path.dirname(_FIRST_WEEK_DISMISS), exist_ok=True)
            with open(_FIRST_WEEK_DISMISS, "w", encoding="utf-8") as fh:
                fh.write(str(int(time.time())))
        except OSError:
            pass
        card.hide()

    def _make_recommended_card(self, staged: bool, rollback: bool, windows_found: bool = False) -> QFrame:
        if _IS_LIVE:
            title = "Try the desktop, then install when ready"
            copy = (
                "Start with hardware checks so you know graphics, networking, audio, "
                "and storage look right before installing."
            )
            buttons = [("Check Hardware", "Hardware", True), ("Install KythOS", None, False)]
        elif staged:
            title = "Restart to finish your update"
            copy = (
                "A new KythOS image is staged. Restart when convenient; your previous "
                "system remains available as a rollback target."
            )
            buttons = [("Restart Now", "reboot", True), ("View Update", "Update", False)]
        elif rollback:
            title = "Your previous system is saved"
            copy = (
                "Rollback is available if a recent change does not feel right. "
                "Otherwise, you can keep setting up apps and games."
            )
            buttons = [("View Rollback", "Update", True), ("Set Up Games", "Gaming", False)]
        elif windows_found:
            title = "Windows drive found — bring your games and files"
            copy = (
                "KythOS sees one or more Windows drives. Copy saves, inspect Steam "
                "libraries, and keep your Windows install untouched."
            )
            buttons = [("Move From Windows", "Move From Windows", True), ("Set Up Games", "Gaming", False)]
        else:
            title = "Everything starts here"
            copy = (
                "Pick a category below, or use the search box at the top to find "
                "any setting — Windows names like \"Device Manager\" work too."
            )
            buttons = [("Set Up Games", "Gaming", True), ("Install Apps", "App Store", False)]

        card, layout = _make_card("card-accent-ok")
        title_lbl = QLabel(title)
        title_lbl.setObjectName("home-next-title")
        layout.addWidget(title_lbl)

        body = QLabel(copy)
        body.setObjectName("home-next-copy")
        body.setWordWrap(True)
        layout.addWidget(body)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        for label, key, primary in buttons:
            btn = QPushButton(label)
            if primary:
                btn.setObjectName("primary")
            if key == "reboot":
                btn.clicked.connect(lambda _=False: subprocess.Popen(["systemctl", "reboot"]))
            elif key is None:
                btn.clicked.connect(lambda _=False: subprocess.Popen(["/usr/bin/kyth-launch-installer"]))
            else:
                btn.clicked.connect(lambda _=False, k=key: self._navigate(k))
            btns.addWidget(btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    def _make_category_card(
        self,
        icon_names: tuple[str, ...],
        glyph: str,
        title: str,
        tasks: list[tuple[str, str]],
    ) -> QFrame:
        card = QFrame()
        card.setObjectName("cp-category")
        card.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Minimum)
        layout = QHBoxLayout(card)
        layout.setContentsMargins(18, 16, 18, 16)
        layout.setSpacing(14)

        icon = _theme_icon(*icon_names)
        icon_lbl = QLabel()
        if icon.isNull():
            icon_lbl.setText(glyph)
            icon_lbl.setObjectName("home-action-icon")
            icon_lbl.setStyleSheet("font-size: 24px;")
        else:
            icon_lbl.setPixmap(icon.pixmap(QSize(32, 32)))
        icon_lbl.setFixedWidth(36)
        layout.addWidget(icon_lbl, 0, Qt.AlignmentFlag.AlignTop)

        text_col = QVBoxLayout()
        text_col.setSpacing(4)

        first_key = tasks[0][1] if tasks else None
        # "&" is a mnemonic marker in QPushButton text; escape it for display
        title_btn = QPushButton(title.replace("&", "&&"))
        title_btn.setObjectName("cp-category-title")
        title_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        if first_key:
            title_btn.clicked.connect(lambda _=False, k=first_key: self._navigate(k))
        text_col.addWidget(title_btn, 0, Qt.AlignmentFlag.AlignLeft)

        for label, key in tasks:
            link = QPushButton(label)
            link.setObjectName("task-link")
            link.setCursor(Qt.CursorShape.PointingHandCursor)
            link.clicked.connect(lambda _=False, k=key: self._navigate(k))
            text_col.addWidget(link, 0, Qt.AlignmentFlag.AlignLeft)

        text_col.addStretch()
        layout.addLayout(text_col, 1)
        return card
