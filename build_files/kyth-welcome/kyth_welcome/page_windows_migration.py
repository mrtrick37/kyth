import glob
import html
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    DataWorker, Worker, _command_stdout, _finish_worker, _human_bytes, _install_flatpak_inline, _release_worker_when_finished, _restyle, _run_command,
)
from .page_feedback import (  # noqa: E501
    _probe_windows_partitions,
)
from .qt import (  # noqa: E501
    QCheckBox, QComboBox, QDesktopServices, QFrame, QHBoxLayout, QLabel, QProgressBar, QPushButton, QThread, QTimer, QUrl, QVBoxLayout, Signal,
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


# ── Copy My Files ─────────────────────────────────────────────────────────────
# Windows stores profile folders under their English names on disk regardless
# of display language, so these source names are locale-safe. Destinations go
# through xdg-user-dir so localized Linux home folders are honoured.
_XDG_FOLDER_KEYS = {
    "Desktop": "DESKTOP",
    "Documents": "DOCUMENTS",
    "Downloads": "DOWNLOAD",
    "Pictures": "PICTURES",
    "Music": "MUSIC",
    "Videos": "VIDEOS",
}


def _windows_folder_dest(folder: str) -> str:
    home = os.path.expanduser("~")
    if folder == "Saved Games":
        return os.path.join(_windows_folder_dest("Documents"), "Saved Games")
    key = _XDG_FOLDER_KEYS.get(folder)
    if key:
        path = _command_stdout(["xdg-user-dir", key], timeout=5)
        # xdg-user-dir answers $HOME itself for unset entries; don't copy there.
        if path and os.path.abspath(path) != home:
            return path
    return os.path.join(home, folder)


def _folder_sizes_calc(paths: dict[str, str]):
    def _calc() -> dict[str, int]:
        sizes: dict[str, int] = {}
        for name, path in paths.items():
            try:
                out = subprocess.check_output(
                    ["du", "-sb", path], text=True, timeout=600,
                    stderr=subprocess.DEVNULL,
                )
                sizes[name] = int(out.split()[0])
            except Exception:
                sizes[name] = -1
        return sizes
    return _calc


class UserFilesCopyWorker(QThread):
    """Copies selected Windows profile folders into the home directory via rsync."""
    status = Signal(str)
    overall = Signal(int)          # 0–100 across all folders
    done = Signal(int, int, bool)  # (ok, failed, cancelled)

    def __init__(self, jobs: list[tuple[str, str, str]]):
        super().__init__()
        self._jobs = jobs  # (folder name, src, dst)
        self._proc: subprocess.Popen | None = None
        self._stop = False

    def stop(self):
        self._stop = True
        proc = self._proc
        if proc and proc.poll() is None:
            proc.terminate()

    def run(self):
        ok = failed = 0
        total = len(self._jobs) or 1
        for idx, (name, src, dst) in enumerate(self._jobs):
            if self._stop:
                break
            self.status.emit(f"Copying {name}…")
            code = self._copy_one(idx, total, name, src, dst)
            if self._stop:
                break
            # 24 = source files vanished mid-copy; harmless for a one-way import.
            if code in (0, 24):
                ok += 1
            else:
                failed += 1
            self.overall.emit(int((idx + 1) * 100 / total))
        self.done.emit(ok, failed, self._stop)

    def _copy_one(self, idx: int, total: int, name: str, src: str, dst: str) -> int:
        try:
            os.makedirs(dst, exist_ok=True)
        except OSError:
            return 1
        # -rt without -p/-o/-g: NTFS carries no useful Unix permissions, so new
        # files get normal home-folder modes. --update never overwrites a file
        # that is already newer on the KythOS side.
        cmd = [
            "rsync", "-rt", "--update", "--info=progress2", "--no-inc-recursive",
            src.rstrip("/") + "/", dst.rstrip("/") + "/",
        ]
        try:
            self._proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except OSError:
            return 1
        # progress2 updates end with \r, not \n, so read raw chunks, not lines.
        fd = self._proc.stdout.fileno()
        tail = b""
        last_pct = -1
        while True:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            tail = (tail + chunk)[-256:]
            pcts = re.findall(rb"(\d+)%", tail)
            if pcts:
                pct = min(100, int(pcts[-1]))
                if pct != last_pct:
                    last_pct = pct
                    self.overall.emit(int((idx * 100 + pct) / total))
                    self.status.emit(f"Copying {name} — {pct}%")
        self._proc.wait()
        return self._proc.returncode


# ── Hardware sanity check ─────────────────────────────────────────────────────
# "Did everything come along?" — the things Windows configured silently.
# Every probe degrades to skipping its row when the tool is missing.

def _strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def _hw_display_row() -> tuple[str, str, str] | None:
    out = _strip_ansi(_command_stdout(["kscreen-doctor", "-o"], timeout=10))
    if not out:
        return None
    hdr = [v.lower() for v in re.findall(r"HDR:\s*([A-Za-z]+)", out)]
    vrr = [v.lower() for v in re.findall(r"VRR:\s*([A-Za-z]+)", out)]
    bits: list[str] = []
    status = "ok"
    if "enabled" in hdr:
        bits.append("HDR is on")
    elif "disabled" in hdr:
        bits.append("your display supports HDR but it's off — enable it in System Settings → Display & Monitor")
        status = "warn"
    elif hdr:
        bits.append("no HDR support advertised by the display")
    if any(v in ("automatic", "always") for v in vrr):
        bits.append("variable refresh rate (FreeSync/G-Sync) is active")
    elif "never" in vrr:
        bits.append("the display supports VRR but it's set to Never — switch it to Automatic for smoother gaming")
        status = "warn"
    elif vrr:
        bits.append("no variable refresh rate support")
    if not bits:
        return None
    joined = "; ".join(bits)
    text = joined[0].upper() + joined[1:] + "."
    if status == "ok" and not any(v == "enabled" for v in hdr) and not any(v in ("automatic", "always") for v in vrr):
        status = "dim"
    return (status, "Display", text)


def _collect_hw_sanity() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []

    state = _command_stdout(["nmcli", "-t", "-f", "STATE", "general"], timeout=5)
    if state:
        if state.startswith("connected"):
            rows.append(("ok", "Network", "Connected to the internet."))
        else:
            rows.append(("warn", "Network", "Not connected — click the network icon in the system tray to join your Wi-Fi."))

    display = _hw_display_row()
    if display:
        rows.append(display)

    lp = _run_command(["lpstat", "-p"], timeout=8)
    if lp is not None:
        printers = [ln for ln in lp.stdout.splitlines() if ln.startswith("printer")]
        if printers:
            rows.append(("ok", "Printer", f"{len(printers)} printer{'s' if len(printers) != 1 else ''} configured and ready."))
        else:
            rows.append(("warn", "Printer", "No printers set up yet. Plug one in (or have a network printer on), then run Set Up Printer."))

    rf = _command_stdout(["rfkill", "list", "bluetooth"], timeout=5)
    if rf.strip():
        if "soft blocked: yes" in rf.lower() or "hard blocked: yes" in rf.lower():
            rows.append(("warn", "Bluetooth", "Bluetooth is turned off (blocked). Enable it from the system tray or System Settings."))
        else:
            rows.append(("ok", "Bluetooth", "Bluetooth adapter is on. Pair devices from the system tray."))

    if glob.glob("/sys/class/power_supply/BAT*"):
        prof = _command_stdout(["powerprofilesctl", "get"], timeout=5)
        if prof:
            rows.append(("ok", "Power", f"Laptop power profile: {prof}. Switch profiles from the battery icon in the tray."))

    return rows


# ── Browser bookmark import ───────────────────────────────────────────────────
_CHROMIUM_BOOKMARK_STORES = (
    ("Chrome", "AppData/Local/Google/Chrome/User Data"),
    ("Edge", "AppData/Local/Microsoft/Edge/User Data"),
    ("Brave", "AppData/Local/BraveSoftware/Brave-Browser/User Data"),
    ("Vivaldi", "AppData/Local/Vivaldi/User Data"),
)
# Opera keeps its Bookmarks file directly in the profile dir, no "User Data" level.
_OPERA_BOOKMARK_DIR = "AppData/Roaming/Opera Software/Opera Stable"


def _read_chromium_bookmarks(path: str) -> list[tuple[str, str]]:
    """(title, url) pairs from a Chromium-format Bookmarks JSON file."""
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    out: list[tuple[str, str]] = []
    seen: set[str] = set()

    def _walk(node):
        if not isinstance(node, dict):
            return
        if node.get("type") == "url":
            url = node.get("url", "")
            if url.startswith(("http://", "https://")) and url not in seen:
                seen.add(url)
                out.append((node.get("name", "") or url, url))
        for child in node.get("children") or []:
            _walk(child)

    for root in (data.get("roots") or {}).values():
        _walk(root)
    return out


def _read_firefox_bookmarks(places_path: str) -> list[tuple[str, str]]:
    """(title, url) pairs from a Firefox places.sqlite (read via a temp copy)."""
    tmp = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
    tmp.close()
    try:
        shutil.copyfile(places_path, tmp.name)
        con = sqlite3.connect(tmp.name)
        try:
            rows = con.execute(
                "SELECT b.title, p.url FROM moz_bookmarks b"
                " JOIN moz_places p ON b.fk = p.id WHERE b.type = 1"
            ).fetchall()
        finally:
            con.close()
    finally:
        os.unlink(tmp.name)
    out: list[tuple[str, str]] = []
    seen: set[str] = set()
    for title, url in rows:
        if url and url.startswith(("http://", "https://")) and url not in seen:
            seen.add(url)
            out.append((title or url, url))
    return out


def _scan_windows_bookmarks(profiles: list[dict]) -> list[dict]:
    """Find bookmark stores in Windows user profiles. Runs on a worker thread."""
    sources: list[dict] = []
    for prof in profiles:
        base, user = prof.get("path", ""), prof.get("name", "")
        candidates: list[tuple[str, str]] = []
        for browser, rel in _CHROMIUM_BOOKMARK_STORES:
            for found in glob.glob(os.path.join(base, rel, "*", "Bookmarks")):
                candidates.append((browser, found))
        opera = os.path.join(base, _OPERA_BOOKMARK_DIR, "Bookmarks")
        if os.path.isfile(opera):
            candidates.append(("Opera", opera))
        for browser, path in candidates:
            try:
                entries = _read_chromium_bookmarks(path)
            except Exception:
                continue
            if not entries:
                continue
            prof_dir = os.path.basename(os.path.dirname(path))
            label = browser if prof_dir in ("Default", "Opera Stable") else f"{browser} ({prof_dir})"
            sources.append({"browser": label, "user": user, "entries": entries})
        for places in glob.glob(os.path.join(base, "AppData/Roaming/Mozilla/Firefox/Profiles", "*", "places.sqlite")):
            try:
                entries = _read_firefox_bookmarks(places)
            except Exception:
                continue
            if entries:
                sources.append({"browser": "Firefox", "user": user, "entries": entries})
    return sources


def _write_bookmarks_html(sources: list[dict], dest: str) -> int:
    """Write a Netscape bookmarks HTML file that every browser's importer accepts."""
    parts = [
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n",
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n',
        "<TITLE>Bookmarks</TITLE>\n",
        "<H1>Bookmarks from Windows</H1>\n",
        "<DL><p>\n",
    ]
    total = 0
    for src in sources:
        parts.append(f"  <DT><H3>{html.escape(src['browser'])} — {html.escape(src['user'])}</H3>\n  <DL><p>\n")
        for title, url in src["entries"]:
            parts.append(f'    <DT><A HREF="{html.escape(url, quote=True)}">{html.escape(title)}</A>\n')
            total += 1
        parts.append("  </DL><p>\n")
    parts.append("</DL><p>\n")
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write("".join(parts))
    return total


# ── Page: Move From Windows ──────────────────────────────────────────────────
class WindowsMigrationPage(Page):
    def __init__(self, navigate=None):
        super().__init__()
        self._navigate = navigate or (lambda _: None)
        self._worker: WindowsLibraryWorker | None = None
        self._files_profiles: list[tuple[dict, dict]] = []
        self._files_checks: list[tuple[QCheckBox, str, str, str]] = []
        self._files_sizes_key = ""
        self._folder_sizes_cache: dict[str, dict] = {}
        self._files_sizes_workers: dict[str, DataWorker] = {}
        self._files_copy_worker: UserFilesCopyWorker | None = None
        self._bm_worker: DataWorker | None = None
        self._bm_sources: list[dict] = []
        self._bm_dest = ""
        self._hw_worker: DataWorker | None = None

        self._page_header(
            "Apps",
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
            ("warn", "Files", "Use Copy My Files below: scan your Windows drive, then copy Documents, Pictures, Music, and Videos into your home folder."),
            ("warn", "Bookmarks", "Export Chrome, Edge, or Firefox bookmarks below; passwords come across via browser sync."),
            ("warn", "Saves", "Install Ludusavi before moving large libraries or experimenting with mods."),
            ("dim", "Updates", "KythOS updates stage a new OS image. Reboot when ready; rollbacks stay available."),
        ):
            checklist_layout.addWidget(self._make_migration_row(status, title, text))
        self._add(checklist)

        # Hardware sanity — the things Windows configured silently
        hw_card, hw_layout = _make_card()
        hw_top = QHBoxLayout()
        hw_title = QLabel("Did everything come along? Quick hardware check")
        hw_title.setObjectName("card-title")
        hw_top.addWidget(hw_title)
        hw_top.addStretch()
        hw_again_btn = QPushButton("Check Again")
        hw_again_btn.clicked.connect(self._run_hw_sanity)
        hw_top.addWidget(hw_again_btn)
        hw_layout.addLayout(hw_top)
        hw_body = QLabel(
            "Network, display (HDR and variable refresh), printers, Bluetooth, and power — "
            "the things Windows set up silently, checked here so you don't have to hunt for drivers."
        )
        hw_body.setObjectName("card-copy")
        hw_body.setWordWrap(True)
        hw_layout.addWidget(hw_body)
        self._hw_status = QLabel("Checking…")
        self._hw_status.setObjectName("card-copy")
        hw_layout.addWidget(self._hw_status)
        self._hw_rows = QVBoxLayout()
        self._hw_rows.setSpacing(6)
        hw_layout.addLayout(self._hw_rows)
        hw_btns = QHBoxLayout()
        hw_btns.setSpacing(8)
        self._hw_printer_btn = QPushButton("Set Up Printer")
        self._hw_printer_btn.setToolTip("Runs: ujust setup-printer")
        self._hw_printer_btn.hide()
        self._hw_printer_btn.clicked.connect(
            lambda _=False: self._run_ujust("setup-printer", self._hw_printer_btn))
        hw_btns.addWidget(self._hw_printer_btn)
        hw_open_btn = QPushButton("Open Hardware")
        hw_open_btn.clicked.connect(lambda _=False: self._navigate("Hardware"))
        hw_btns.addWidget(hw_open_btn)
        hw_btns.addStretch()
        hw_layout.addLayout(hw_btns)
        self._add(hw_card)
        # Pages are built eagerly at startup; defer the subprocess probes.
        QTimer.singleShot(900, self._run_hw_sanity)

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

        # Windows keyboard muscle memory
        shortcuts_card, shortcuts_layout = _make_card()
        shortcuts_title = QLabel("Keep your Windows keyboard shortcuts")
        shortcuts_title.setObjectName("card-title")
        shortcuts_layout.addWidget(shortcuts_title)
        shortcuts_body = QLabel(
            "Most Windows shortcuts already work on KythOS: Win+L locks, Win+D shows the desktop, "
            "Alt+Tab switches windows, Win+. opens the emoji picker. This adds the rest:"
        )
        shortcuts_body.setObjectName("card-copy")
        shortcuts_body.setWordWrap(True)
        shortcuts_layout.addWidget(shortcuts_body)
        for keys, what in (
            ("Win+E", "Open the file manager (Dolphin)"),
            ("Win+Shift+S", "Snip a region of the screen (Spectacle)"),
            ("Win+V", "Show clipboard history at the cursor"),
        ):
            row = QHBoxLayout()
            row.setSpacing(10)
            keys_lbl = QLabel(keys)
            keys_lbl.setStyleSheet(
                "font-family: monospace; font-size:12px; font-weight:600; color:#cccccc; "
                "background:#252526; border:1px solid #3c3c3c; border-radius:3px; padding:2px 8px;"
            )
            keys_lbl.setMinimumWidth(110)
            row.addWidget(keys_lbl)
            what_lbl = QLabel(what)
            what_lbl.setObjectName("card-copy")
            row.addWidget(what_lbl, 1)
            shortcuts_layout.addLayout(row)
        self._shortcuts_status = QLabel("")
        self._shortcuts_status.setObjectName("card-copy")
        self._shortcuts_status.setWordWrap(True)
        shortcuts_layout.addWidget(self._shortcuts_status)
        shortcuts_btns = QHBoxLayout()
        shortcuts_btns.setSpacing(8)
        shortcuts_apply_btn = QPushButton("Apply Windows Shortcuts")
        shortcuts_apply_btn.setObjectName("primary")
        shortcuts_apply_btn.clicked.connect(self._apply_windows_shortcuts)
        shortcuts_btns.addWidget(shortcuts_apply_btn)
        shortcuts_revert_btn = QPushButton("Restore KDE Defaults")
        shortcuts_revert_btn.clicked.connect(self._revert_windows_shortcuts)
        shortcuts_btns.addWidget(shortcuts_revert_btn)
        shortcuts_btns.addStretch()
        shortcuts_layout.addLayout(shortcuts_btns)
        self._add(shortcuts_card)

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

        # Phone Link replacement
        phone_card, phone_layout = _make_card()
        phone_title = QLabel("Phone Link → KDE Connect")
        phone_title.setObjectName("card-title")
        phone_layout.addWidget(phone_title)
        phone_body = QLabel(
            "On Windows you had Phone Link; KythOS has KDE Connect built in. Pair your phone "
            "over Wi-Fi to see and answer notifications on the desktop, send files both ways, "
            "share the clipboard, control media, and ring a lost phone. Install the app on "
            "your phone, open KDE Connect here, and tap Pair — both devices must be on the "
            "same network."
        )
        phone_body.setObjectName("card-copy")
        phone_body.setWordWrap(True)
        phone_layout.addWidget(phone_body)
        self._phone_status = QLabel("")
        self._phone_status.setObjectName("card-copy")
        self._phone_status.setWordWrap(True)
        phone_layout.addWidget(self._phone_status)
        phone_btns = QHBoxLayout()
        phone_btns.setSpacing(8)
        phone_open_btn = QPushButton("Open KDE Connect")
        phone_open_btn.setObjectName("primary")
        phone_open_btn.clicked.connect(self._open_kde_connect)
        phone_btns.addWidget(phone_open_btn)
        phone_android_btn = QPushButton("Android App")
        phone_android_btn.clicked.connect(lambda _=False: QDesktopServices.openUrl(
            QUrl("https://play.google.com/store/apps/details?id=org.kde.kdeconnect_tp")))
        phone_btns.addWidget(phone_android_btn)
        phone_ios_btn = QPushButton("iPhone App")
        phone_ios_btn.clicked.connect(lambda _=False: QDesktopServices.openUrl(
            QUrl("https://apps.apple.com/app/kde-connect/id1580245991")))
        phone_btns.addWidget(phone_ios_btn)
        phone_btns.addStretch()
        phone_layout.addLayout(phone_btns)
        self._add(phone_card)

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
        ntfs_warn = QLabel(
            "⚠  Browse and copy files from Windows drives freely — but don't add one as a Steam "
            "library or launch games from it. Proton needs a Linux-formatted disk; games run "
            "straight off NTFS break in confusing ways. Use Copy Games to KythOS instead."
        )
        ntfs_warn.setObjectName("card-copy")
        ntfs_warn.setWordWrap(True)
        ntfs_warn.setStyleSheet("color: #d4a843;")
        drives_layout.addWidget(ntfs_warn)
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

        # ── Copy My Files ─────────────────────────────────────────────────────
        files_card, files_layout = _make_card()
        files_title = QLabel("Copy your files from Windows")
        files_title.setObjectName("card-title")
        files_layout.addWidget(files_title)
        self._files_intro = QLabel(
            "Click Scan Drives above — your Windows user folders show up here, and one click "
            "copies Documents, Pictures, Music, Videos, and more into your KythOS home folder. "
            "The Windows side is never modified."
        )
        self._files_intro.setObjectName("card-copy")
        self._files_intro.setWordWrap(True)
        files_layout.addWidget(self._files_intro)
        self._files_profile_combo = QComboBox()
        self._files_profile_combo.hide()
        self._files_profile_combo.currentIndexChanged.connect(self._on_files_profile_changed)
        files_layout.addWidget(self._files_profile_combo)
        self._files_rows = QVBoxLayout()
        self._files_rows.setSpacing(4)
        files_layout.addLayout(self._files_rows)
        self._files_space_lbl = QLabel("")
        self._files_space_lbl.setObjectName("card-copy")
        files_layout.addWidget(self._files_space_lbl)
        self._files_status = QLabel("")
        self._files_status.setObjectName("card-copy")
        self._files_status.setWordWrap(True)
        files_layout.addWidget(self._files_status)
        self._files_progress = QProgressBar()
        self._files_progress.setRange(0, 100)
        self._files_progress.hide()
        files_layout.addWidget(self._files_progress)
        files_btns = QHBoxLayout()
        files_btns.setSpacing(8)
        self._files_copy_btn = QPushButton("Copy Selected Folders")
        self._files_copy_btn.setObjectName("primary")
        self._files_copy_btn.hide()
        self._files_copy_btn.clicked.connect(self._start_files_copy)
        files_btns.addWidget(self._files_copy_btn)
        self._files_cancel_btn = QPushButton("Cancel")
        self._files_cancel_btn.hide()
        self._files_cancel_btn.clicked.connect(self._cancel_files_copy)
        files_btns.addWidget(self._files_cancel_btn)
        files_btns.addStretch()
        files_layout.addLayout(files_btns)
        self._add(files_card)

        # ── Browser bookmarks ─────────────────────────────────────────────────
        bm_card, bm_layout = _make_card()
        bm_title = QLabel("Bring your browser bookmarks")
        bm_title.setObjectName("card-title")
        bm_layout.addWidget(bm_title)
        bm_body = QLabel(
            "Bookmarks are read straight off the Windows drive — Chrome, Edge, Brave, Vivaldi, "
            "Opera, and Firefox — and saved as one standard bookmarks file that any browser can "
            "import. Passwords can't be copied (Windows encrypts them per-machine); sign into "
            "Firefox Sync or your Google account to bring those across."
        )
        bm_body.setObjectName("card-copy")
        bm_body.setWordWrap(True)
        bm_layout.addWidget(bm_body)
        self._bm_status = QLabel("Scan drives above — bookmarks are found automatically.")
        self._bm_status.setObjectName("card-copy")
        self._bm_status.setWordWrap(True)
        bm_layout.addWidget(self._bm_status)
        self._bm_rows = QVBoxLayout()
        self._bm_rows.setSpacing(6)
        bm_layout.addLayout(self._bm_rows)
        bm_btns = QHBoxLayout()
        bm_btns.setSpacing(8)
        self._bm_export_btn = QPushButton("Save Bookmarks File")
        self._bm_export_btn.setObjectName("primary")
        self._bm_export_btn.hide()
        self._bm_export_btn.clicked.connect(self._export_bookmarks)
        bm_btns.addWidget(self._bm_export_btn)
        self._bm_show_btn = QPushButton("Show File")
        self._bm_show_btn.hide()
        self._bm_show_btn.clicked.connect(lambda _=False: QDesktopServices.openUrl(
            QUrl.fromLocalFile(os.path.dirname(self._bm_dest))) if self._bm_dest else None)
        bm_btns.addWidget(self._bm_show_btn)
        bm_btns.addStretch()
        bm_layout.addLayout(bm_btns)
        self._add(bm_card)

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
        bottles_btn.clicked.connect(lambda _=False, b=bottles_btn: _install_flatpak_inline(
            self, b, "com.usebottles.bottles", "Bottles"))
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

    # kglobalshortcutsrc writes: (group path, key, value). Non-service entries
    # use the "active,default,description" triple format.
    _WINDOWS_SHORTCUT_KEYS = (
        (("services", "org.kde.dolphin.desktop"), "_launch", "Meta+E"),
        (("org.kde.spectacle.desktop",), "RectangularRegionScreenShot",
         "Meta+Shift+S,Meta+Shift+S,Capture Rectangular Region"),
        (("klipper",), "show-on-mouse-pos",
         "Meta+V,Meta+V,Show Clipboard Items at Mouse Position"),
    )

    def _run_shortcut_change(self, delete: bool) -> bool:
        if not shutil.which("kwriteconfig6"):
            self._shortcuts_status.setText("kwriteconfig6 not found — is this a KDE session?")
            return False
        ok = True
        for groups, key, value in self._WINDOWS_SHORTCUT_KEYS:
            cmd = ["kwriteconfig6", "--file", "kglobalshortcutsrc"]
            for group in groups:
                cmd += ["--group", group]
            cmd += ["--key", key]
            cmd += ["--delete"] if delete else [value]
            try:
                ok = subprocess.run(cmd, capture_output=True, timeout=10).returncode == 0 and ok
            except Exception:
                ok = False
        # kglobalaccel only rereads the file on restart.
        subprocess.run(
            ["systemctl", "--user", "restart", "plasma-kglobalaccel.service"],
            capture_output=True, timeout=10,
        )
        return ok

    def _apply_windows_shortcuts(self):
        if self._run_shortcut_change(delete=False):
            self._shortcuts_status.setText(
                "✓ Windows shortcuts applied — try Win+E. If a shortcut doesn't respond, sign out and back in."
            )

    def _revert_windows_shortcuts(self):
        if self._run_shortcut_change(delete=True):
            self._shortcuts_status.setText("✓ KDE default shortcuts restored.")

    def _open_kde_connect(self):
        for cmd in (["kdeconnect-app"], ["kcmshell6", "kcm_kdeconnect"], ["systemsettings", "kcm_kdeconnect"]):
            if shutil.which(cmd[0]):
                subprocess.Popen(cmd)
                self._phone_status.setText("")
                return
        self._phone_status.setText(
            "KDE Connect isn't available in this session — install it from the App Store, "
            "or check System Settings → Connected Devices."
        )

    # ── Hardware sanity ───────────────────────────────────────────────────────

    def _run_hw_sanity(self):
        if self._hw_worker is not None and self._hw_worker.isRunning():
            return
        self._hw_status.setText("Checking…")
        self._hw_status.show()
        worker = DataWorker("hw-sanity", _collect_hw_sanity)
        worker.result.connect(self._on_hw_sanity)
        self._hw_worker = worker
        _release_worker_when_finished(self, "_hw_worker", worker)
        worker.start()

    def _on_hw_sanity(self, _key: str, rows: list):
        self._clear_layout(self._hw_rows)
        if not rows:
            self._hw_status.setText("Could not run the hardware checks in this session.")
            return
        self._hw_status.hide()
        printer_missing = False
        for status, title, text in rows:
            if title == "Printer" and status == "warn":
                printer_missing = True
            self._hw_rows.addWidget(self._make_migration_row(status, title, text))
        self._hw_printer_btn.setVisible(printer_missing)

    # ── Copy My Files ─────────────────────────────────────────────────────────

    def _set_files_status(self, text: str, obj: str = "card-copy"):
        self._files_status.setText(text)
        self._files_status.setObjectName(obj)
        _restyle(self._files_status)

    def _populate_files_card(self, partitions: list):
        if self._files_copy_worker is not None and self._files_copy_worker.isRunning():
            return  # don't yank the folder list out from under a running copy
        self._files_profiles = [
            (part, prof)
            for part in partitions
            for prof in (part.get("user_profiles") or [])
        ]
        self._files_profile_combo.blockSignals(True)
        self._files_profile_combo.clear()
        for part, prof in self._files_profiles:
            where = part.get("label") or part.get("device") or "Windows drive"
            self._files_profile_combo.addItem(f"{prof['name']} — {where}")
        self._files_profile_combo.blockSignals(False)
        if not self._files_profiles:
            self._files_intro.setText(
                "No Windows user folders found. If the drive is hibernated, boot Windows once, "
                "choose a full Shut Down, then rescan."
            )
            self._files_profile_combo.hide()
            self._files_copy_btn.hide()
            self._files_space_lbl.setText("")
            self._clear_layout(self._files_rows)
            self._files_checks = []
            return
        self._files_intro.setText(
            "Pick the Windows user to copy from, tick the folders you want, then start the copy. "
            "The Windows side is never modified, and newer files already in your home folder are kept."
        )
        self._files_profile_combo.show()
        self._files_copy_btn.show()
        self._set_files_status("")
        self._files_profile_combo.setCurrentIndex(0)
        self._on_files_profile_changed(0)

    def _on_files_profile_changed(self, idx: int):
        self._clear_layout(self._files_rows)
        self._files_checks = []
        if not (0 <= idx < len(self._files_profiles)):
            return
        _part, prof = self._files_profiles[idx]
        home = os.path.expanduser("~")
        for folder in prof.get("folders") or []:
            src = os.path.join(prof["path"], folder)
            dst = _windows_folder_dest(folder)
            cb = QCheckBox(f"{folder} — calculating size… → {dst.replace(home, '~', 1)}")
            # Downloads is mostly installer debris; everything else defaults on.
            cb.setChecked(folder != "Downloads")
            self._files_checks.append((cb, folder, src, dst))
            self._files_rows.addWidget(cb)
        free = shutil.disk_usage(home).free
        self._files_space_lbl.setText(f"Free space in your home folder: {_human_bytes(free)}.")
        key = prof["path"]
        self._files_sizes_key = key
        cached = self._folder_sizes_cache.get(key)
        if cached is not None:
            self._apply_folder_sizes(cached)
            return
        if key in self._files_sizes_workers and self._files_sizes_workers[key].isRunning():
            return
        paths = {folder: src for _, folder, src, _ in self._files_checks}
        worker = DataWorker(key, _folder_sizes_calc(paths))
        worker.result.connect(self._on_folder_sizes)
        self._files_sizes_workers[key] = worker
        worker.finished.connect(lambda w=worker, k=key: (self._files_sizes_workers.pop(k, None), w.deleteLater()))
        worker.start()

    def _on_folder_sizes(self, key: str, sizes: dict):
        self._folder_sizes_cache[key] = sizes
        if key == self._files_sizes_key:
            self._apply_folder_sizes(sizes)

    def _apply_folder_sizes(self, sizes: dict):
        home = os.path.expanduser("~")
        for cb, folder, _src, dst in self._files_checks:
            size = sizes.get(folder, -1)
            size_txt = _human_bytes(size) if size >= 0 else "size unknown"
            cb.setText(f"{folder} — {size_txt} → {dst.replace(home, '~', 1)}")

    def _start_files_copy(self):
        if self._files_copy_worker is not None and self._files_copy_worker.isRunning():
            return
        jobs = [(folder, src, dst) for cb, folder, src, dst in self._files_checks if cb.isChecked()]
        if not jobs:
            self._set_files_status("Tick at least one folder to copy.", "status-warn")
            return
        sizes = self._folder_sizes_cache.get(self._files_sizes_key) or {}
        needed = sum(s for s in (sizes.get(folder, -1) for folder, _, _ in jobs) if s > 0)
        free = shutil.disk_usage(os.path.expanduser("~")).free
        if needed > free:
            self._set_files_status(
                f"Not enough free space: the selected folders hold {_human_bytes(needed)} "
                f"but only {_human_bytes(free)} is free in your home folder.", "status-err")
            return
        for cb, *_ in self._files_checks:
            cb.setEnabled(False)
        self._files_profile_combo.setEnabled(False)
        self._files_copy_btn.setEnabled(False)
        self._files_cancel_btn.show()
        self._files_progress.setValue(0)
        self._files_progress.show()
        self._set_files_status("Starting copy…")
        worker = UserFilesCopyWorker(jobs)
        worker.status.connect(self._files_status.setText)
        worker.overall.connect(self._files_progress.setValue)
        worker.done.connect(self._on_files_copy_done)
        self._files_copy_worker = worker
        _release_worker_when_finished(self, "_files_copy_worker", worker)
        worker.start()

    def _cancel_files_copy(self):
        worker = self._files_copy_worker
        if worker is not None and worker.isRunning():
            self._files_cancel_btn.setEnabled(False)
            self._set_files_status("Cancelling…", "status-warn")
            worker.stop()

    def _on_files_copy_done(self, ok: int, failed: int, cancelled: bool):
        self._files_progress.hide()
        self._files_cancel_btn.hide()
        self._files_cancel_btn.setEnabled(True)
        self._files_copy_btn.setEnabled(True)
        self._files_profile_combo.setEnabled(True)
        for cb, *_ in self._files_checks:
            cb.setEnabled(True)
        if cancelled:
            self._set_files_status(
                "Copy cancelled. Files copied so far are kept; run it again to resume.", "status-warn")
        elif failed:
            self._set_files_status(
                f"Copied {ok} folder(s); {failed} had errors. If Windows wasn't shut down fully, "
                "boot it once, choose Shut Down, and try again.", "status-err")
        else:
            self._set_files_status(f"✓ Copied {ok} folder(s) into your home folder.", "status-ok")

    # ── Browser bookmarks ─────────────────────────────────────────────────────

    def _start_bookmark_scan(self, partitions: list):
        profiles = [prof for part in partitions for prof in (part.get("user_profiles") or [])]
        self._clear_layout(self._bm_rows)
        self._bm_export_btn.hide()
        self._bm_show_btn.hide()
        if not profiles:
            self._bm_status.setText("No Windows user profiles found — nothing to read bookmarks from.")
            return
        if self._bm_worker is not None and self._bm_worker.isRunning():
            return
        self._bm_status.setText("Looking for browser bookmarks…")
        worker = DataWorker("bookmarks", lambda: _scan_windows_bookmarks(profiles))
        worker.result.connect(self._on_bookmarks_found)
        self._bm_worker = worker
        _release_worker_when_finished(self, "_bm_worker", worker)
        worker.start()

    def _on_bookmarks_found(self, _key: str, sources: list):
        self._bm_sources = sources
        self._clear_layout(self._bm_rows)
        if not sources:
            self._bm_status.setText("No browser bookmarks found on the scanned drives.")
            return
        total = sum(len(src["entries"]) for src in sources)
        self._bm_status.setText(
            f"Found {total} bookmark{'s' if total != 1 else ''} in "
            f"{len(sources)} browser profile{'s' if len(sources) != 1 else ''}:"
        )
        for src in sources:
            self._bm_rows.addWidget(self._make_migration_row(
                "ok", src["browser"],
                f"{len(src['entries'])} bookmarks — Windows user {src['user']}",
            ))
        self._bm_export_btn.show()

    def _export_bookmarks(self):
        if not self._bm_sources:
            return
        dest = os.path.join(_windows_folder_dest("Documents"), "Windows Bookmarks.html")
        try:
            total = _write_bookmarks_html(self._bm_sources, dest)
        except OSError as exc:
            self._bm_status.setText(f"Could not write the bookmarks file: {exc}")
            return
        self._bm_dest = dest
        home = os.path.expanduser("~")
        self._bm_status.setText(
            f"✓ Saved {total} bookmarks to {dest.replace(home, '~', 1)}. In your browser, open "
            "the bookmark manager (Ctrl+Shift+O) and choose Import bookmarks from HTML."
        )
        self._bm_show_btn.show()

    @staticmethod
    def _clear_layout(layout):
        while layout.count():
            item = layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

    def _clear_drive_rows(self):
        self._clear_layout(self._drive_rows)

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
            self._populate_files_card([])
            self._start_bookmark_scan([])
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
        self._populate_files_card(partitions)
        self._start_bookmark_scan(partitions)

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
            steam_btn.setToolTip(
                "Read-only browsing is fine. Don't add this folder as a Steam library on "
                "KythOS — copy the games to your Linux disk instead."
            )
            steam_btn.clicked.connect(
                lambda _=False, path=steam_paths[0]: QDesktopServices.openUrl(QUrl.fromLocalFile(path))
            )
            layout.addWidget(steam_btn)
        gaming_btn = QPushButton("Copy Games to KythOS")
        gaming_btn.setToolTip("Opens Gaming → Steam Library migration: scans this drive and copies games to your Linux disk.")
        gaming_btn.clicked.connect(lambda _=False: self._navigate("Gaming"))
        layout.addWidget(gaming_btn)
        return row
