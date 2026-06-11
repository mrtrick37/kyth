import subprocess

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    _IS_LIVE, _branch_display_name, _command_stdout, _current_branch, _detect_nvidia, _find_ntfs_drives, _has_rollback_deployment, _has_staged_update,
)
from .qt import (  # noqa: E501
    QFrame, QGridLayout, QHBoxLayout, QLabel, QPushButton, QSize, QSizePolicy, QVBoxLayout, Qt,
)
from .widgets import (  # noqa: E501
    Page, StatTile, _make_card, _theme_icon,
)

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

        self._add(self._make_recommended_card(staged, rollback, windows_found))

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
