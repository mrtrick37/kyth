import subprocess

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    _IS_LIVE, _branch_display_name, _command_stdout, _current_branch, _find_ntfs_drives, _has_rollback_deployment, _has_staged_update,
)
from .qt import (  # noqa: E501
    QFrame, QHBoxLayout, QLabel, QPushButton,
)
from .widgets import (  # noqa: E501
    Page, StatTile, _make_card,
)

# ── Page: Welcome ─────────────────────────────────────────────────────────────
class WelcomePage(Page):
    def __init__(self, navigate=None):
        super().__init__()
        self._navigate = navigate or (lambda _: None)

        self._page_header(
            "System Hub",
            "Command Center",
            "One place to play, update, install, check hardware, and recover.",
        )

        branch = _branch_display_name(_current_branch())
        staged = _has_staged_update()
        rollback = _has_rollback_deployment()
        kernel = _command_stdout(["uname", "-r"], timeout=5) or "unknown"
        windows_found = bool(_find_ntfs_drives())

        tiles_row = QHBoxLayout()
        tiles_row.setSpacing(10)

        self._branch_tile = StatTile("Channel", branch)
        tiles_row.addWidget(self._branch_tile, 1)

        staged_val = "Update Staged" if staged else "Up to Date"
        staged_style = "stat-value-warn" if staged else "stat-value-ok"
        self._update_tile = StatTile("System", staged_val, staged_style)
        tiles_row.addWidget(self._update_tile, 1)

        rollback_val = "Available" if rollback else "None"
        rollback_style = "stat-value-ok" if rollback else "stat-value"
        self._rollback_tile = StatTile("Rollback", rollback_val, rollback_style)
        tiles_row.addWidget(self._rollback_tile, 1)

        self._kernel_tile = StatTile("Kernel", kernel)
        tiles_row.addWidget(self._kernel_tile, 1)

        self._add_layout(tiles_row)

        self._add(self._make_recommended_card(staged, rollback, windows_found))

        section_lbl = QLabel("Sections")
        section_lbl.setObjectName("section-heading")
        self._add(section_lbl)

        lanes = QHBoxLayout()
        lanes.setSpacing(12)
        lanes.addWidget(self._make_task_card(
            "PLAY",
            "Gaming",
            "Launchers, Proton, performance profiles, saves, and game checks.",
            "Open",
            "Gaming",
        ), 1)
        lanes.addWidget(self._make_task_card(
            "MAINTAIN",
            "Updates & Hardware",
            "Stage updates, confirm rollback, inspect drivers, firmware, and devices.",
            "Open",
            "Update" if staged else "Hardware",
            primary=staged,
        ), 1)
        lanes.addWidget(self._make_task_card(
            "APPS",
            "App Store",
            "Trending apps, curated shelves, search, installs, and software management.",
            "Open",
            "App Store",
        ), 1)
        lanes.addWidget(self._make_task_card(
            "RECOVER",
            "Repair",
            "Health reports, quick fixes, rollback guidance, snapshots, and support paths.",
            "Open",
            "Repair",
        ), 1)
        self._add_layout(lanes)

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
            title = "Reboot to finish your update"
            copy = (
                "A new KythOS image is staged. Reboot when convenient; your previous "
                "system remains available as a rollback target."
            )
            buttons = [("Reboot Now", "reboot", True), ("View Update", "Update", False)]
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
                "Pick a section below. The hub keeps gaming, updates, apps, and "
                "recovery in one place."
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

    def _make_task_card(
        self,
        icon: str,
        title: str,
        desc: str,
        button_label: str,
        page_key: str,
        primary: bool = False,
    ) -> QFrame:
        card, layout = _make_card("home-action-card")
        layout.setSpacing(10)

        icon_lbl = QLabel(icon)
        icon_lbl.setObjectName("home-action-icon")
        layout.addWidget(icon_lbl)

        title_lbl = QLabel(title)
        title_lbl.setObjectName("home-action-title")
        layout.addWidget(title_lbl)

        desc_lbl = QLabel(desc)
        desc_lbl.setObjectName("home-action-copy")
        desc_lbl.setWordWrap(True)
        layout.addWidget(desc_lbl)

        btn_row = QHBoxLayout()
        btn_row.addStretch()
        btn = QPushButton(button_label)
        if primary:
            btn.setObjectName("primary")
        btn.clicked.connect(lambda _=False, key=page_key: self._navigate(key))
        btn_row.addWidget(btn)
        layout.addLayout(btn_row)
        return card
