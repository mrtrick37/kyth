import os
import subprocess
import time

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    DataWorker, _IS_LIVE, _branch_display_name, _command_stdout, _current_branch, _detect_nvidia, _find_ntfs_drives, _has_rollback_deployment, _has_staged_update, _load_profile, _release_worker_when_finished, _restyle, _save_profile, _steam_libraries_on_ntfs,
)
from .qt import (  # noqa: E501
    QFrame, QGridLayout, QHBoxLayout, QLabel, QPushButton, QSize, QSizePolicy, QTimer, QVBoxLayout, Qt, Signal,
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


def _path_exists(path: str) -> bool:
    return os.path.exists(os.path.expanduser(path))


def _cmd_ok(cmd: list[str], timeout: int = 5) -> bool:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        return result.returncode == 0
    except Exception:
        return False


def _flatpak_installed(app_id: str) -> bool:
    return _cmd_ok(["flatpak", "info", app_id], timeout=5)


def _controller_seen() -> bool:
    for path in ("/dev/input/by-id", "/dev/input/by-path"):
        try:
            names = os.listdir(path)
        except OSError:
            continue
        if any(token in name.lower() for name in names for token in ("joystick", "gamepad", "controller")):
            return True
    return False


def _kdeconnect_configured() -> bool:
    if _path_exists("~/.config/kdeconnect"):
        return True
    try:
        result = subprocess.run(["kdeconnect-cli", "--list-devices"], capture_output=True, text=True, timeout=6, check=False)
        return result.returncode == 0 and bool(result.stdout.strip())
    except Exception:
        return False


def _cloud_storage_configured() -> bool:
    return _path_exists("~/.config/kyth-cloud-sync.json") or _path_exists("~/.config/rclone/rclone.conf")


def _printer_configured() -> bool:
    try:
        result = subprocess.run(["lpstat", "-v"], capture_output=True, text=True, timeout=5, check=False)
        return result.returncode == 0 and bool(result.stdout.strip())
    except Exception:
        return False


def _browser_integration_native_ready() -> bool:
    return (
        _cmd_ok(["rpm", "-q", "plasma-browser-integration"], timeout=5)
        or _path_exists("/usr/bin/plasma-browser-integration-host")
    )


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
    profile_changed = Signal(str)

    def __init__(self, navigate=None):
        super().__init__()
        self._navigate = navigate or (lambda _: None)
        self._profile = _load_profile()

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

        self._add(self._make_recommended_card(staged, rollback, windows_found))

        # ── NTFS Steam library warning ────────────────────────────────────────
        # Proton on a Windows-formatted drive fails in ways that read as
        # "Linux gaming is broken"; catch it here before the first bad evening.
        ntfs_libs = [] if _IS_LIVE else _steam_libraries_on_ntfs()
        if ntfs_libs:
            self._add(self._make_ntfs_library_card(ntfs_libs))

        # ── First-week tips: the things people discover too late ─────────────
        days = None if _IS_LIVE else _first_week_days()
        if days is not None and _FIRST_WEEK_MIN_DAYS <= days <= _FIRST_WEEK_MAX_DAYS:
            self._add(self._make_first_week_card(days))

        self._add(self._make_section_header("Tune the hub", "Choose what this PC is for; the rest of the hub follows that focus."))

        # ── Usage focus ───────────────────────────────────────────────────────
        # Same choice the first-boot wizard offers, so existing installs can
        # re-purpose a machine (e.g. a work PC that never games) after the fact.
        self._add(self._make_focus_card())

        self._add(self._make_section_header("Browse by task", "Search understands familiar names, but each card opens a KythOS workflow built for this desktop."))

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


        self._category_grid = QGridLayout()
        self._category_grid.setSpacing(12)
        self._category_cards: list[tuple[QFrame, bool]] = []
        for icon_names, glyph, title, tasks in categories:
            card = self._make_category_card(icon_names, glyph, title, tasks)
            self._category_cards.append((card, title == "Games"))
        self._relayout_categories(self._profile)
        self._category_grid.setColumnStretch(0, 1)
        self._category_grid.setColumnStretch(1, 1)
        self._add_layout(self._category_grid)

        self._stretch()

    def _make_ntfs_library_card(self, libs: list[str]) -> QFrame:
        card, layout = _make_card("card-accent-warn")
        title = QLabel("Your Steam library is on a Windows-formatted drive")
        title.setObjectName("card-title")
        layout.addWidget(title)
        home = os.path.expanduser("~")
        listed = ",  ".join(lib.replace(home, "~", 1) for lib in libs[:3])
        if len(libs) > 3:
            listed += f"  (+{len(libs) - 3} more)"
        body = QLabel(
            f"Steam is using a library on an NTFS/exFAT drive: {listed}.  Proton needs a "
            "Linux-formatted disk — games on Windows-formatted drives crash, hang at launch, "
            "or corrupt their save prefixes, and it won't look like a drive problem when they do. "
            "Copy the games onto your KythOS disk instead; your Windows drive stays untouched."
        )
        body.setObjectName("card-copy")
        body.setWordWrap(True)
        layout.addWidget(body)
        btns = QHBoxLayout()
        btns.setSpacing(8)
        copy_btn = QPushButton("Copy Games to KythOS")
        copy_btn.setObjectName("primary")
        copy_btn.clicked.connect(lambda _=False: self._navigate("Gaming"))
        btns.addWidget(copy_btn)
        learn_btn = QPushButton("Why This Breaks")
        learn_btn.clicked.connect(lambda _=False: self._navigate("Move From Windows"))
        btns.addWidget(learn_btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    def _make_first_week_card(self, days: int) -> QFrame:
        card, layout = _make_card("card-accent-ok")
        title = QLabel(f"Day {days} on KythOS — finish setting up this PC")
        title.setObjectName("card-title")
        layout.addWidget(title)

        body = QLabel("A quick pass over the everyday pieces that make this machine feel settled.")
        body.setObjectName("card-copy")
        body.setWordWrap(True)
        layout.addWidget(body)

        app_setup_done = os.path.exists("/var/lib/kyth/default-flatpaks-v5-done")
        checklist = [
            (
                app_setup_done,
                "Default apps",
                "Steam, launchers, Bottles, save backup, and everyday apps are installed.",
                "App Store",
            ),
            (
                _flatpak_installed("com.brave.Browser"),
                "Browser",
                "Brave is ready for sync, extensions, web apps, and media playback.",
                "App Store",
            ),
            (
                _browser_integration_native_ready(),
                "Browser integration",
                "The native Plasma connector is ready for media keys, download progress, and desktop controls.",
                "App Store",
            ),
            (
                _flatpak_installed("com.valvesoftware.Steam"),
                "Steam",
                "Steam is installed; add libraries, Proton tools, and save backup from Gaming.",
                "Gaming",
            ),
            (
                _controller_seen(),
                "Controller",
                "A controller has been detected at least once this session.",
                "Controllers",
            ),
            (
                _kdeconnect_configured(),
                "Phone pairing",
                "KDE Connect is ready for file sharing, notifications, and dynamic lock.",
                "Move From Windows",
            ),
            (
                _cloud_storage_configured(),
                "Cloud storage",
                "Cloud or rclone configuration exists for this account.",
                "Cloud Storage",
            ),
            (
                _printer_configured(),
                "Printer",
                "At least one local or network printer is configured.",
                "Hardware",
            ),
            (
                _has_rollback_deployment(),
                "Rollback",
                "Your previous system image is available if an update or change feels wrong.",
                "Update",
            ),
        ]

        for done, label, text, page_key in checklist:
            row = QHBoxLayout()
            row.setSpacing(10)
            badge = QLabel("Done" if done else "Set up")
            badge.setObjectName("task-status-ok" if done else "task-status-idle")
            row.addWidget(badge, 0, Qt.AlignmentFlag.AlignTop)

            text_col = QVBoxLayout()
            text_col.setSpacing(2)
            heading = QLabel(label)
            heading.setObjectName("card-subtitle")
            text_col.addWidget(heading)
            lbl = QLabel(text)
            lbl.setObjectName("card-copy")
            lbl.setWordWrap(True)
            text_col.addWidget(lbl)
            row.addLayout(text_col, 1)

            btn = QPushButton("Open" if done else "Set Up")
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

    # ── Usage focus ───────────────────────────────────────────────────────────

    def _make_section_header(self, title: str, subtitle: str) -> QFrame:
        frame = QFrame()
        frame.setObjectName("home-section")
        layout = QVBoxLayout(frame)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        title_lbl = QLabel(title)
        title_lbl.setObjectName("home-section-title")
        layout.addWidget(title_lbl)

        subtitle_lbl = QLabel(subtitle)
        subtitle_lbl.setObjectName("home-section-copy")
        subtitle_lbl.setWordWrap(True)
        layout.addWidget(subtitle_lbl)
        return frame

    def _make_focus_card(self) -> QFrame:
        card, layout = _make_card()
        title = QLabel("This PC's focus")
        title.setObjectName("card-title")
        layout.addWidget(title)
        body = QLabel(
            "Pick what you use this PC for, and KythOS tunes the hub, pins, and "
            "desktop defaults around that workflow. Nothing is uninstalled — switch back anytime."
        )
        body.setObjectName("card-copy")
        body.setWordWrap(True)
        layout.addWidget(body)

        self._focus_buttons: dict[str, QPushButton] = {}
        row = QHBoxLayout()
        row.setSpacing(10)
        for key, label, tip in (
            ("everyday", "Everyday", "Apps, browser, files, cloud storage, VPN, printers, and updates up front."),
            ("gaming", "Gaming", "Launchers, performance, compatibility, controllers, and gaming pins up front."),
        ):
            btn = QPushButton(label)
            btn.setCheckable(True)
            btn.setToolTip(tip)
            btn.setMinimumHeight(38)
            btn.clicked.connect(lambda _=False, k=key: self._on_focus_chosen(k))
            self._focus_buttons[key] = btn
            row.addWidget(btn)
        row.addStretch()
        layout.addLayout(row)
        self._focus_buttons[self._profile].setChecked(True)

        apply_row = QHBoxLayout()
        apply_row.setSpacing(8)
        apply_btn = QPushButton("Apply Preset")
        apply_btn.setObjectName("primary")
        apply_btn.clicked.connect(lambda _=False: self._apply_role_preset())
        apply_row.addWidget(apply_btn)
        self._preset_status = QLabel("Preset changes are safe to re-apply anytime.")
        self._preset_status.setObjectName("status-dim")
        self._preset_status.setWordWrap(True)
        apply_row.addWidget(self._preset_status, 1)
        layout.addLayout(apply_row)
        return card

    def _on_focus_chosen(self, profile: str):
        self._profile = profile
        for key, btn in self._focus_buttons.items():
            btn.setChecked(key == profile)
        _save_profile(profile)
        self._relayout_categories(profile)
        self.profile_changed.emit(profile)

    def _apply_role_preset(self):
        try:
            result = subprocess.run(
                ["/usr/bin/kyth-apply-role-preset", self._profile],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
            if result.returncode == 0:
                self._preset_status.setObjectName("status-ok")
                self._preset_status.setText(f"{self._profile.title()} preset applied.")
            else:
                detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
                self._preset_status.setObjectName("status-warn")
                self._preset_status.setText(f"Preset saved, but desktop pins could not be refreshed: {detail}")
        except Exception as exc:
            self._preset_status.setObjectName("status-warn")
            self._preset_status.setText(f"Preset saved, but desktop pins could not be refreshed: {exc}")
        _restyle(self._preset_status)

    def _relayout_categories(self, profile: str):
        """Re-pack the category grid so hiding the Games card leaves no hole."""
        show_games = profile == "gaming"
        visible: list[QFrame] = []
        for card, is_games in self._category_cards:
            self._category_grid.removeWidget(card)
            wanted = show_games or not is_games
            card.setVisible(wanted)
            if wanted:
                visible.append(card)
        for i, card in enumerate(visible):
            self._category_grid.addWidget(card, i // 2, i % 2)

    def _make_recommended_card(self, staged: bool, rollback: bool, windows_found: bool = False) -> QFrame:
        if _IS_LIVE:
            kicker = "Live session"
            title = "Try the desktop, then install when ready"
            copy = (
                "Start with hardware checks so you know graphics, networking, audio, "
                "and storage look right before installing."
            )
            buttons = [("Check Hardware", "Hardware", True), ("Install KythOS", None, False)]
        elif staged:
            kicker = "Needs attention"
            title = "Restart to finish your update"
            copy = (
                "A new KythOS image is staged. Restart when convenient; your previous "
                "system remains available as a rollback target."
            )
            buttons = [("Restart Now", "reboot", True), ("View Update", "Update", False)]
        elif rollback:
            kicker = "Recovery ready"
            title = "Your previous system is saved"
            copy = (
                "Rollback is available if a recent change does not feel right. "
                "Otherwise, you can keep setting up apps and games."
            )
            buttons = [("View Rollback", "Update", True), ("Set Up Games", "Gaming", False)]
        elif windows_found:
            kicker = "Recommended next"
            title = "Windows drive found — bring your games and files"
            copy = (
                "KythOS sees one or more Windows drives. Copy saves, inspect Steam "
                "libraries, and keep your Windows install untouched."
            )
            buttons = [("Move From Windows", "Move From Windows", True), ("Set Up Games", "Gaming", False)]
        else:
            kicker = "Recommended next"
            title = "Everything starts here"
            copy = (
                "Set up the essentials first, then use search or the task cards below "
                "whenever you know what you want to do."
            )
            buttons = [("Set Up Games", "Gaming", True), ("Install Apps", "App Store", False)]

        card, layout = _make_card("home-recommend-card")
        kicker_lbl = QLabel(kicker.upper())
        kicker_lbl.setObjectName("home-kicker")
        layout.addWidget(kicker_lbl)

        row = QHBoxLayout()
        row.setSpacing(20)

        text_col = QVBoxLayout()
        text_col.setSpacing(8)
        title_lbl = QLabel(title)
        title_lbl.setObjectName("home-next-title")
        title_lbl.setWordWrap(True)
        text_col.addWidget(title_lbl)

        body = QLabel(copy)
        body.setObjectName("home-next-copy")
        body.setWordWrap(True)
        text_col.addWidget(body)

        meta = QLabel("Search also understands common PC setting names, app tasks, and game setup phrases.")
        meta.setObjectName("home-next-meta")
        meta.setWordWrap(True)
        text_col.addWidget(meta)
        row.addLayout(text_col, 1)

        btns = QVBoxLayout()
        btns.setSpacing(8)
        for label, key, primary in buttons:
            btn = QPushButton(label)
            if primary:
                btn.setObjectName("primary")
            btn.setMinimumWidth(168)
            if key == "reboot":
                btn.clicked.connect(lambda _=False: subprocess.Popen(["systemctl", "reboot"]))
            elif key is None:
                btn.clicked.connect(lambda _=False: subprocess.Popen(["/usr/bin/kyth-launch-installer"]))
            else:
                btn.clicked.connect(lambda _=False, k=key: self._navigate(k))
            btns.addWidget(btn)
        btns.addStretch()
        row.addLayout(btns)
        layout.addLayout(row)
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
