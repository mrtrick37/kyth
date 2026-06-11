import os
import sys
import shutil
import subprocess

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    Worker, _finish_worker, _open_terminal_with_cmd, _restyle,
)
from .page_feedback import (  # noqa: E501
    _probe_windows_partitions,
)
from .qt import (  # noqa: E501
    QDesktopServices, QFrame, QHBoxLayout, QLabel, QProgressBar, QPushButton, QThread, QUrl, QVBoxLayout, Signal,
)
from .widgets import (  # noqa: E501
    Page, _make_card,
)

class WindowsLibraryWorker(QThread):
    result = Signal(list)

    def run(self) -> None:
        try:
            partitions = _probe_windows_partitions()
        except Exception as exc:
            print(f"Windows library probe failed: {exc}", file=sys.stderr)
            partitions = []
        self.result.emit(partitions)


# ── Page: Move From Windows ──────────────────────────────────────────────────
class WindowsMigrationPage(Page):
    def __init__(self, navigate=None):
        super().__init__()
        self._navigate = navigate or (lambda _: None)
        self._worker: WindowsLibraryWorker | None = None

        self._page_header(
            "System",
            "Move From Windows",
            "Bring your files, games, and familiar habits over without touching the Windows install.",
        )

        intro, intro_layout = _make_card("card-accent-ok")
        intro_title = QLabel("Start here if this is your first week on KythOS")
        intro_title.setObjectName("card-title")
        intro_layout.addWidget(intro_title)
        intro_body = QLabel(
            "KythOS can read Windows drives, copy personal files, import Steam libraries, "
            "and point you toward the right app path for Windows installers. Windows drives "
            "are treated carefully: migration tools read from them and copy into your home folder."
        )
        intro_body.setObjectName("card-copy")
        intro_body.setWordWrap(True)
        intro_layout.addWidget(intro_body)
        intro_btns = QHBoxLayout()
        intro_btns.setSpacing(8)
        for label, page in (
            ("Install Familiar Apps", "App Store"),
            ("Move Steam Games", "Gaming"),
            ("Back Up Saves", "Gaming"),
            ("Open File Manager", None),
        ):
            btn = QPushButton(label)
            if page:
                btn.clicked.connect(lambda _=False, key=page: self._navigate(key))
            else:
                btn.clicked.connect(lambda _=False: subprocess.Popen(["dolphin", os.path.expanduser("~")]) if shutil.which("dolphin") else QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.expanduser("~"))))
            intro_btns.addWidget(btn)
        intro_btns.addStretch()
        intro_layout.addLayout(intro_btns)
        self._add(intro)

        checklist, checklist_layout = _make_card()
        checklist_title = QLabel("Windows switch checklist")
        checklist_title.setObjectName("card-title")
        checklist_layout.addWidget(checklist_title)
        for status, title, text in (
            ("ok", "Apps", "Use App Store for trending Flatpaks, starter packs, AppImages, and installed apps."),
            ("ok", "Games", "Use Steam, Heroic, Lutris, or Bottles instead of running random Windows installers directly."),
            ("warn", "Files", "Copy Documents, Downloads, Pictures, Music, and Videos into your KythOS home folder."),
            ("warn", "Saves", "Install Ludusavi before moving large libraries or experimenting with mods."),
            ("dim", "Updates", "KythOS updates stage a new OS image. Reboot when ready; rollbacks stay available."),
        ):
            checklist_layout.addWidget(self._make_migration_row(status, title, text))
        self._add(checklist)

        # Dual-boot clock fix card
        clock_card, clock_layout = _make_card("card-accent-warn")
        clock_title = QLabel("Dual-booting with Windows? Fix the clock.")
        clock_title.setObjectName("card-title")
        clock_layout.addWidget(clock_title)
        clock_body = QLabel(
            "After booting KythOS, Windows often shows the wrong time — sometimes off by several hours. "
            "This happens because Windows and Linux disagree about whether the hardware clock stores "
            "local time or UTC. One command fixes it permanently with no reboot needed."
        )
        clock_body.setObjectName("card-copy")
        clock_body.setWordWrap(True)
        clock_layout.addWidget(clock_body)
        clock_btns = QHBoxLayout()
        clock_btns.setSpacing(8)
        clock_fix_btn = QPushButton("Fix Dual-Boot Clock")
        clock_fix_btn.setObjectName("primary")
        clock_fix_btn.setToolTip("Runs: sudo timedatectl set-local-rtc 1 --adjust-system-clock")
        clock_fix_btn.clicked.connect(lambda _=False: self._run_ujust("fix-dualboot-clock", clock_fix_btn))
        clock_btns.addWidget(clock_fix_btn)
        clock_btns.addStretch()
        clock_layout.addLayout(clock_btns)
        self._add(clock_card)

        # OneDrive / cloud sync card
        onedrive_card, onedrive_layout = _make_card()
        onedrive_title = QLabel("OneDrive & Google Drive sync")
        onedrive_title.setObjectName("card-title")
        onedrive_layout.addWidget(onedrive_title)
        onedrive_body = QLabel(
            "KythOS includes a built-in Cloud Storage wizard that connects OneDrive and Google Drive "
            "via rclone — free, open-source, and background-sync capable. Files stay in a folder "
            "in your home directory and sync automatically. No paid client needed."
        )
        onedrive_body.setObjectName("card-copy")
        onedrive_body.setWordWrap(True)
        onedrive_layout.addWidget(onedrive_body)
        onedrive_btns = QHBoxLayout()
        onedrive_btns.setSpacing(8)
        onedrive_open_btn = QPushButton("Set Up Cloud Storage")
        onedrive_open_btn.setObjectName("primary")
        onedrive_open_btn.clicked.connect(lambda _=False: self._navigate("Cloud Storage"))
        onedrive_btns.addWidget(onedrive_open_btn)
        onedrive_btns.addStretch()
        onedrive_layout.addLayout(onedrive_btns)
        self._add(onedrive_card)

        score_card, score_layout = _make_card("card-accent-ok")
        score_title = QLabel("Switch Readiness")
        score_title.setObjectName("card-title")
        score_layout.addWidget(score_title)
        self._migration_score_lbl = QLabel(
            "Scan drives to estimate migration readiness. KythOS looks at launchers, save tools, Windows drives, and safe copy paths."
        )
        self._migration_score_lbl.setObjectName("card-copy")
        self._migration_score_lbl.setWordWrap(True)
        score_layout.addWidget(self._migration_score_lbl)
        score_btns = QHBoxLayout()
        for label, page in (("Install Launchers", "Gaming"), ("Back Up Saves", "Gaming"), ("Cloud Storage", "Cloud Storage")):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, key=page: self._navigate(key))
            score_btns.addWidget(btn)
        score_btns.addStretch()
        score_layout.addLayout(score_btns)
        self._add(score_card)

        drives, drives_layout = _make_card()
        drives_top = QHBoxLayout()
        drives_title = QLabel("Windows drives")
        drives_title.setObjectName("card-title")
        drives_top.addWidget(drives_title)
        drives_top.addStretch()
        refresh_btn = QPushButton("Scan Drives")
        refresh_btn.setObjectName("primary")
        refresh_btn.clicked.connect(self._scan_windows_drives)
        drives_top.addWidget(refresh_btn)
        drives_layout.addLayout(drives_top)
        drives_desc = QLabel(
            "Looks for NTFS partitions, hibernation/dirty flags, Windows user folders, mount points, and Steam folders. "
            "If a drive is hibernated, boot Windows once and choose full Shut Down before copying from it."
        )
        drives_desc.setObjectName("card-copy")
        drives_desc.setWordWrap(True)
        drives_layout.addWidget(drives_desc)
        self._drive_status = QLabel("Click Scan Drives to look for Windows partitions.")
        self._drive_status.setObjectName("card-copy")
        self._drive_status.setWordWrap(True)
        drives_layout.addWidget(self._drive_status)
        self._drive_progress = QProgressBar()
        self._drive_progress.setRange(0, 0)
        self._drive_progress.hide()
        drives_layout.addWidget(self._drive_progress)
        self._drive_rows = QVBoxLayout()
        self._drive_rows.setSpacing(8)
        drives_layout.addLayout(self._drive_rows)
        self._add(drives)

        exe_card, exe_layout = _make_card()
        exe_title = QLabel("What about .exe installers?")
        exe_title.setObjectName("card-title")
        exe_layout.addWidget(exe_title)
        exe_body = QLabel(
            "For games, start with Steam, Heroic, or Lutris. For standalone Windows apps, "
            "use Bottles so each app gets its own isolated Windows-like environment. "
            "If a native Linux or Flatpak version exists, prefer that first."
        )
        exe_body.setObjectName("card-copy")
        exe_body.setWordWrap(True)
        exe_layout.addWidget(exe_body)
        exe_btns = QHBoxLayout()
        exe_btns.setSpacing(8)
        bottles_btn = QPushButton("Install Bottles")
        bottles_btn.clicked.connect(lambda _=False: _open_terminal_with_cmd(["ujust", "install-bottles"], "Install Bottles"))
        exe_btns.addWidget(bottles_btn)
        software_btn = QPushButton("Open App Store")
        software_btn.clicked.connect(lambda _=False: self._navigate("App Store"))
        exe_btns.addWidget(software_btn)
        exe_btns.addStretch()
        exe_layout.addLayout(exe_btns)
        self._add(exe_card)

        self._stretch()

    def _make_migration_row(self, status: str, title: str, summary: str) -> QFrame:
        row = QFrame()
        row.setObjectName({
            "ok": "hw-card-ok",
            "warn": "hw-card-warn",
            "err": "hw-card-err",
            "dim": "hw-card-dim",
        }.get(status, "hw-card-dim"))
        layout = QHBoxLayout(row)
        layout.setContentsMargins(14, 9, 14, 9)
        layout.setSpacing(10)
        title_lbl = QLabel(title)
        title_lbl.setObjectName("card-summary")
        title_lbl.setMinimumWidth(110)
        layout.addWidget(title_lbl)
        summary_lbl = QLabel(summary)
        summary_lbl.setObjectName("card-copy")
        summary_lbl.setWordWrap(True)
        layout.addWidget(summary_lbl, 1)
        return row

    def _clear_drive_rows(self):
        while self._drive_rows.count():
            item = self._drive_rows.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

    def _scan_windows_drives(self):
        if self._worker and self._worker.isRunning():
            return
        self._clear_drive_rows()
        self._drive_progress.show()
        self._drive_status.setText("Scanning NTFS partitions…")
        self._drive_status.setObjectName("subheading")
        _restyle(self._drive_status)
        self._worker = WindowsLibraryWorker()
        self._worker.result.connect(self._on_windows_drives)
        self._worker.start()

    def _on_windows_drives(self, partitions: list):
        self._drive_progress.hide()
        _finish_worker(self)
        if not partitions:
            self._drive_status.setText("No Windows/NTFS partitions found.")
            self._drive_status.setObjectName("status-warn")
            self._migration_score_lbl.setText("Switch readiness: 2/5. Install your launchers and Ludusavi, then connect your Windows drive or cloud backup when ready.")
            _restyle(self._drive_status)
            return
        self._drive_status.setText(f"Found {len(partitions)} Windows-style partition{'s' if len(partitions) != 1 else ''}.")
        self._drive_status.setObjectName("status-ok")
        _restyle(self._drive_status)
        clean = sum(1 for p in partitions if not p.get("is_dirty") and not p.get("is_hibernated"))
        steam = sum(len(p.get("steam_paths") or []) for p in partitions)
        profiles = sum(len(p.get("user_profiles") or []) for p in partitions)
        score = 2 + (1 if clean else 0) + (1 if steam else 0) + (1 if profiles else 0)
        self._migration_score_lbl.setText(
            f"Switch readiness: {score}/5. Found {clean} safely readable drive(s), "
            f"{steam} Steam folder(s), and {profiles} Windows user profile(s). "
            "Back up saves with Ludusavi before copying large libraries."
        )
        for part in partitions:
            self._drive_rows.addWidget(self._make_drive_row(part))

    def _run_ujust(self, recipe: str, btn: QPushButton):
        btn.setEnabled(False)
        orig = btn.text()
        btn.setText("Running…")
        worker = Worker(["bash", "-c", f"ujust {recipe}"])
        def _done(code: int, b=btn, o=orig):
            b.setEnabled(True)
            b.setText("✓ Done" if code == 0 else o)
        worker.done.connect(_done)
        worker.start()
        self._worker = worker

    def _make_drive_row(self, part: dict) -> QFrame:
        status = "warn" if part.get("is_dirty") or part.get("is_hibernated") else "ok"
        label = part.get("label") or part.get("device") or "Windows drive"
        mount = part.get("mountpoint") or "not mounted"
        steam_count = len(part.get("steam_paths") or [])
        profile_count = len(part.get("user_profiles") or [])
        summary = (
            f"{part.get('device', '')} · {part.get('size', '')} · {mount} · "
            f"{profile_count} user profile{'s' if profile_count != 1 else ''} · "
            f"{steam_count} Steam folder{'s' if steam_count != 1 else ''}"
        )
        if part.get("is_hibernated"):
            summary += " · hibernated"
        elif part.get("is_dirty"):
            summary += " · needs Windows shutdown"
        row = self._make_migration_row(status, label, summary)
        layout = row.layout()
        if part.get("mountpoint"):
            open_btn = QPushButton("Open Drive")
            open_btn.clicked.connect(
                lambda _=False, path=part["mountpoint"]: QDesktopServices.openUrl(QUrl.fromLocalFile(path))
            )
            layout.addWidget(open_btn)
        profiles = part.get("user_profiles") or []
        if profiles:
            profile = profiles[0]
            files_btn = QPushButton("Open Windows Files")
            files_btn.clicked.connect(
                lambda _=False, path=profile["path"]: QDesktopServices.openUrl(QUrl.fromLocalFile(path))
            )
            files_btn.setToolTip(", ".join(profile.get("folders") or []))
            layout.addWidget(files_btn)
        steam_paths = part.get("steam_paths") or []
        if steam_paths:
            steam_btn = QPushButton("Open Steam Library")
            steam_btn.clicked.connect(
                lambda _=False, path=steam_paths[0]: QDesktopServices.openUrl(QUrl.fromLocalFile(path))
            )
            layout.addWidget(steam_btn)
        gaming_btn = QPushButton("Move Steam")
        gaming_btn.clicked.connect(lambda _=False: self._navigate("Gaming"))
        layout.addWidget(gaming_btn)
        return row
