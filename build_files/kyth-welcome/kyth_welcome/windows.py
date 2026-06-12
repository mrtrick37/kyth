import shlex
import subprocess

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    Worker, _IS_LIVE, _cancel_worker, _command_stdout, _current_branch, _detect_nvidia, _find_ntfs_drives, _finish_worker, _ge_proton_version, _has_rollback_deployment, _is_flatpak_installed, _load_profile, _mark_wizard_done, _restyle, _save_profile,
)
from .page_branches import (  # noqa: E501
    BranchesPage,
)
from .page_cloud_storage import (  # noqa: E501
    CloudStoragePage,
)
from .page_compatibility import (  # noqa: E501
    CompatibilityPage, _COMPAT_GAMES,
)
from .page_controllers import (  # noqa: E501
    ControllerPage,
)
from .page_diagnostics import (  # noqa: E501
    DiagnosticsPage,
)
from .page_feedback import (  # noqa: E501
    FeedbackPage,
)
from .page_gaming import (  # noqa: E501
    GamingPage,
)
from .page_hardware import (  # noqa: E501
    HardwarePage,
)
from .page_kernel import (  # noqa: E501
    KernelPage,
)
from .page_network_shares import (  # noqa: E501
    NetworkSharesPage,
)
from .page_nvidia import (  # noqa: E501
    NvidiaPage,
)
from .page_performance import (  # noqa: E501
    PerformancePage,
)
from .page_repair import (  # noqa: E501
    RepairPage,
)
from .page_software import (  # noqa: E501
    SoftwarePage,
)
from .page_update import (  # noqa: E501
    UpdatePage,
)
from .page_vpn import (  # noqa: E501
    VpnPage,
)
from .page_welcome import (  # noqa: E501
    WelcomePage,
)
from .page_windows_migration import (  # noqa: E501
    WindowsMigrationPage,
)
from .page_work import (  # noqa: E501
    WorkSetupPage,
)
from .qt import (  # noqa: E501
    QCheckBox, QCompleter, QDesktopServices, QFrame, QHBoxLayout, QIcon, QLabel, QLineEdit, QMainWindow, QMessageBox, QProgressBar, QPushButton, QScrollArea, QSize, QSizePolicy, QStackedWidget, QTextEdit, QTimer, QUrl, QVBoxLayout, QWidget, Qt,
)
from .widgets import (  # noqa: E501
    _divider, _make_card, _set_log_panel, _theme_icon,
)

# ── Sidebar nav button ─────────────────────────────────────────────────────────
def _nav_section_label(text: str) -> QLabel:
    """Create a sidebar section header label (e.g. 'System', 'Apps')."""
    lbl = QLabel(text)
    lbl.setObjectName("nav-section")
    lbl.setContentsMargins(20, 14, 16, 4)
    return lbl


class NavButton(QPushButton):
    def __init__(self, icon_names: tuple[str, ...], glyph: str, label: str):
        icon = _theme_icon(*icon_names)
        if icon.isNull():
            # No matching theme icon installed — fall back to the text glyph.
            super().__init__(f"  {glyph}  {label}")
        else:
            super().__init__(f"  {label}")
            self.setIcon(icon)
            self.setIconSize(QSize(16, 16))
        self.setObjectName("nav-item")
        self.setCheckable(False)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        sp = self.sizePolicy()
        sp.setHorizontalPolicy(QSizePolicy.Policy.Expanding)
        self.setSizePolicy(sp)
        self.setMinimumHeight(36)

    def set_active(self, active: bool):
        self.setObjectName("nav-item-active" if active else "nav-item")
        _restyle(self)


# ── Main window ───────────────────────────────────────────────────────────────
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("KythOS")
        self.setMinimumSize(980, 660)
        self.resize(1180, 760)

        # Outer wrapper: live banner (if running from live ISO) + main content
        central = QWidget()
        central.setObjectName("content-area")
        central_layout = QVBoxLayout(central)
        central_layout.setContentsMargins(0, 0, 0, 0)
        central_layout.setSpacing(0)
        self.setCentralWidget(central)

        if _IS_LIVE:
            banner = QWidget()
            banner.setObjectName("live-banner")
            banner_layout = QHBoxLayout(banner)
            banner_layout.setContentsMargins(16, 9, 16, 9)
            banner_layout.setSpacing(0)

            badge = QLabel("  LIVE SESSION  ")
            badge.setObjectName("live-banner-badge")
            banner_layout.addWidget(badge)
            banner_layout.addSpacing(12)

            notice = QLabel(
                "Connect to Wi-Fi or Ethernet first, then install KythOS or open System Hub for hardware checks."
            )
            notice.setObjectName("live-banner-text")
            banner_layout.addWidget(notice, 1)
            banner_layout.addSpacing(16)

            install_btn = QPushButton("Install KythOS")
            install_btn.setObjectName("primary")
            install_btn.setFixedWidth(148)
            install_btn.clicked.connect(
                lambda: subprocess.Popen(["/usr/bin/kyth-launch-installer"])
            )
            banner_layout.addWidget(install_btn)
            central_layout.addWidget(banner)

        # ── Top command bar: back/forward, breadcrumb, search ────────────────
        topbar = QWidget()
        topbar.setObjectName("topbar")
        topbar.setFixedHeight(46)
        topbar_layout = QHBoxLayout(topbar)
        topbar_layout.setContentsMargins(8, 6, 14, 6)
        topbar_layout.setSpacing(4)

        self._back_btn = QPushButton("←")
        self._back_btn.setObjectName("topbar-nav")
        self._back_btn.setFixedSize(36, 30)
        self._back_btn.setToolTip("Back")
        self._back_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self._back_btn.clicked.connect(self._go_back)
        topbar_layout.addWidget(self._back_btn)

        self._fwd_btn = QPushButton("→")
        self._fwd_btn.setObjectName("topbar-nav")
        self._fwd_btn.setFixedSize(36, 30)
        self._fwd_btn.setToolTip("Forward")
        self._fwd_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self._fwd_btn.clicked.connect(self._go_forward)
        topbar_layout.addWidget(self._fwd_btn)

        topbar_layout.addSpacing(8)

        home_crumb = QPushButton("System Hub")
        home_crumb.setObjectName("breadcrumb-link")
        home_crumb.setCursor(Qt.CursorShape.PointingHandCursor)
        home_crumb.clicked.connect(lambda: self._navigate_to("Welcome"))
        topbar_layout.addWidget(home_crumb)

        self._crumb_lbl = QLabel("")
        self._crumb_lbl.setObjectName("breadcrumb")
        topbar_layout.addWidget(self._crumb_lbl)
        topbar_layout.addStretch()

        self._search_box = QLineEdit()
        self._search_box.setObjectName("search-box")
        self._search_box.setPlaceholderText("Find a setting")
        self._search_box.setFixedWidth(280)
        self._search_box.setClearButtonEnabled(True)
        topbar_layout.addWidget(self._search_box)

        central_layout.addWidget(topbar)

        root = QWidget()
        root.setObjectName("content-area")
        root_layout = QHBoxLayout(root)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)
        central_layout.addWidget(root, 1)

        # ── Sidebar ──────────────────────────────────────────────────────────
        sidebar = QWidget()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(244)
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)
        sidebar_layout.setSpacing(0)

        # Header / branding
        logo_area = QWidget()
        logo_area.setObjectName("sidebar-header")
        logo_layout = QVBoxLayout(logo_area)
        logo_layout.setContentsMargins(20, 22, 20, 18)
        logo_layout.setSpacing(3)

        logo_lbl = QLabel("KythOS")
        logo_lbl.setObjectName("sidebar-logo")
        logo_layout.addWidget(logo_lbl)

        _branch = _current_branch()
        _branch_text = {"latest": "Stable Channel", "testing": "Testing Channel"}.get(
            _branch or "", "System Hub"
        )
        ver_lbl = QLabel(_branch_text)
        ver_lbl.setObjectName("sidebar-ver")
        logo_layout.addWidget(ver_lbl)
        sidebar_layout.addWidget(logo_area)
        sidebar_layout.addWidget(_divider())

        # Nav groups: (section_label, [(icon_names, glyph, label, key, factory), ...])
        # section_label=None omits the header row (used for Home).
        page_specs: list[tuple[str, object]] = []

        NavItem = tuple[tuple[str, ...], str, str, str, object]
        nav_groups: list[tuple[str | None, list[NavItem]]] = [
            (None, [
                (("go-home",), "⌂", "Home", "Welcome", lambda: WelcomePage(navigate=self._navigate_to)),
            ]),
            ("Gaming", [
                (("applications-games", "input-gaming"), "◉", "Gaming", "Gaming", GamingPage),
                (("speedometer", "utilities-system-monitor"), "⚡", "Performance", "Performance", PerformancePage),
                (("dialog-ok-apply", "checkmark"), "◎", "Compatibility", "Compatibility", CompatibilityPage),
                (("input-gamepad", "input-gaming"), "⎮", "Controllers", "Controllers", ControllerPage),
            ]),
            ("Apps", [
                (("plasmadiscover", "applications-all"), "⬡", "Discover Apps", "App Store", lambda: SoftwarePage(initial_tab=4, store_landing=True)),
                (("x-office-document", "applications-office"), "▤", "Work Setup", "Work Setup", lambda: WorkSetupPage(navigate=self._navigate_to)),
                (("document-import", "drive-harddisk"), "⇄", "Windows Migration", "Move From Windows", lambda: WindowsMigrationPage(navigate=self._navigate_to)),
            ]),
            ("System", [
                (("system-software-update", "update-none"), "↻", "Updates", "Update", UpdatePage),
                (("computer", "computer-laptop"), "◈", "Hardware", "Hardware", lambda: HardwarePage(navigate=self._navigate_to)),
                (("view-statistics", "office-chart-bar"), "◌", "Health Report", "Diagnostics", DiagnosticsPage),
                (("tools-wizard", "configure"), "⚠", "Repair", "Repair", lambda: RepairPage(navigate=self._navigate_to)),
            ]),
            ("Network & Internet", [
                (("network-vpn", "security-high"), "⬡", "VPN", "VPN", VpnPage),
                (("folder-network", "network-workgroup"), "◫", "Network Shares", "Network Shares", NetworkSharesPage),
                (("folder-cloud", "weather-clouds"), "☁", "Cloud Storage", "Cloud Storage", CloudStoragePage),
            ]),
        ]

        advanced_items: list[NavItem] = []
        if _detect_nvidia():
            advanced_items.append((("video-display", "preferences-desktop-display"), "▣", "NVIDIA Drivers", "NVIDIA", NvidiaPage))
        advanced_items.append((("cpu", "applications-system"), "◌", "Kernel", "Kernel", KernelPage))
        advanced_items.append((("vcs-branch", "system-switch-user"), "⎇", "Channels", "Channels", BranchesPage))
        advanced_items.append((("mail-send", "mail-message"), "✉", "Feedback", "Feedback", FeedbackPage))
        nav_groups.append(("Advanced", advanced_items))

        self._nav_buttons: list[NavButton] = []
        self._page_crumbs: list[tuple[str | None, str]] = []
        global_idx = 0
        for section_title, items in nav_groups:
            sidebar_layout.addSpacing(4)
            if section_title is not None:
                sidebar_layout.addWidget(_nav_section_label(section_title))
            for icon_names, glyph, label, key, factory in items:
                page_specs.append((key, factory))
                self._page_crumbs.append((section_title, label))
                btn = NavButton(icon_names, glyph, label)
                btn.clicked.connect(self._make_nav_handler(global_idx))
                sidebar_layout.addWidget(btn)
                self._nav_buttons.append(btn)
                global_idx += 1
            sidebar_layout.addSpacing(2)

        self._page_index_by_key = {
            key: idx for idx, (key, _) in enumerate(page_specs)
        }

        sidebar_layout.addStretch()

        # Bottom version hint
        sidebar_layout.addWidget(_divider())
        ver_hint = QLabel("KythOS System Hub")
        ver_hint.setObjectName("nav-section")
        ver_hint.setContentsMargins(20, 10, 16, 12)
        sidebar_layout.addWidget(ver_hint)

        root_layout.addWidget(sidebar)

        # ── Page stack ───────────────────────────────────────────────────────
        self._stack = QStackedWidget()
        self._stack.setObjectName("content-area")
        self._pages = [factory() for _, factory in page_specs]
        for page in self._pages:
            self._stack.addWidget(page)
        root_layout.addWidget(self._stack)

        self._history: list[int] = []
        self._history_pos: int = -1
        self._setup_search()
        self._switch_page(0)

    # ── Search ("Find a setting") ─────────────────────────────────────────────

    # Windows-familiar phrasings mapped to page keys, so converts can search
    # for what they knew the task as on Windows.
    _SEARCH_ALIASES: dict[str, list[str]] = {
        "Welcome": ["Home", "Control Panel"],
        "Gaming": ["Gaming", "Game launchers", "Steam", "Epic Games", "GOG", "Game Pass", "Xbox app", "Battle.net"],
        "Performance": ["Performance", "Task Manager"],
        "Compatibility": ["Game compatibility", "Will my games work", "ProtonDB"],
        "Controllers": ["Controllers", "Game controllers", "Xbox controller", "PlayStation controller"],
        "App Store": ["Add or remove programs", "Apps & features", "Install apps", "App store", "Uninstall a program", "dnf install", "rpm", "exe installer", "downloaded installer", "Flathub"],
        "Move From Windows": ["Move from Windows", "Transfer my files", "Windows migration", "Copy game saves", "Keyboard shortcuts", "Snipping Tool", "Windows shortcuts", "Copy my files", "Import bookmarks", "Bookmarks", "Phone Link", "KDE Connect"],
        "Update": ["Check for updates", "Windows Update", "Updates"],
        "Hardware": ["Hardware", "Device Manager", "Display", "Sound", "Bluetooth"],
        "Diagnostics": ["Health report", "System information", "Diagnostics"],
        "Repair": ["Repair", "Troubleshoot", "Recovery", "Reset this PC", "Rollback", "terminal", "command prompt", "PowerShell"],
        "VPN": ["VPN", "VPN settings"],
        "Network Shares": ["Network shares", "Map network drive", "Shared folders"],
        "Cloud Storage": ["Cloud storage", "OneDrive", "Google Drive", "Dropbox"],
        "NVIDIA": ["NVIDIA drivers", "Graphics drivers", "GeForce"],
        "Kernel": ["Kernel", "Advanced system settings"],
        "Channels": ["Update channel", "Channels", "Insider program"],
        "Feedback": ["Feedback", "Send feedback", "Feedback Hub"],
    }

    def _setup_search(self):
        self._search_key_by_entry: dict[str, str] = {}
        for key, aliases in self._SEARCH_ALIASES.items():
            if key not in self._page_index_by_key:
                continue
            for alias in aliases:
                self._search_key_by_entry.setdefault(alias, key)

        entries = sorted(self._search_key_by_entry)
        completer = QCompleter(entries, self._search_box)
        completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
        completer.setFilterMode(Qt.MatchFlag.MatchContains)
        completer.activated.connect(self._on_search_pick)
        self._search_box.setCompleter(completer)
        self._search_box.returnPressed.connect(self._on_search_return)

    def _on_search_pick(self, entry: str):
        key = self._search_key_by_entry.get(entry)
        if key is not None:
            self._navigate_to(key)
        self._search_box.clear()

    def _on_search_return(self):
        text = self._search_box.text().strip().lower()
        if not text:
            return
        for entry, key in sorted(self._search_key_by_entry.items()):
            if text in entry.lower():
                self._navigate_to(key)
                self._search_box.clear()
                return

    # ── Navigation ────────────────────────────────────────────────────────────

    def _make_nav_handler(self, index: int):
        return lambda: self._switch_page(index)

    def _navigate_to(self, destination: int | str):
        if isinstance(destination, str):
            index = self._page_index_by_key.get(destination)
            if index is None:
                return
            self._switch_page(index)
            return
        self._switch_page(destination)

    def _go_back(self):
        if self._history_pos > 0:
            self._history_pos -= 1
            self._switch_page(self._history[self._history_pos], record=False)

    def _go_forward(self):
        if self._history_pos < len(self._history) - 1:
            self._history_pos += 1
            self._switch_page(self._history[self._history_pos], record=False)

    def _switch_page(self, index: int, record: bool = True):
        for i, btn in enumerate(self._nav_buttons):
            btn.set_active(i == index)
        self._stack.setCurrentIndex(index)
        if record:
            del self._history[self._history_pos + 1:]
            if not self._history or self._history[-1] != index:
                self._history.append(index)
            self._history_pos = len(self._history) - 1
        self._update_topbar(index)

    def _update_topbar(self, index: int):
        self._back_btn.setEnabled(self._history_pos > 0)
        self._fwd_btn.setEnabled(self._history_pos < len(self._history) - 1)
        section, label = self._page_crumbs[index]
        if index == 0:
            self._crumb_lbl.setText("")
        elif section and section != label:
            self._crumb_lbl.setText(f"›  {section}  ›  {label}")
        else:
            self._crumb_lbl.setText(f"›  {label}")

    def closeEvent(self, event):
        active = [
            child for child in self.findChildren(QWidget)
            if (w := getattr(child, "_worker", None)) is not None and w.isRunning()
        ]
        if active:
            QMessageBox.warning(
                self,
                "KythOS Is Busy",
                "A task is still running. Please wait for it to finish before closing.",
            )
            event.ignore()
            self.raise_()
            self.activateWindow()
            return
        super().closeEvent(event)


# ── Wizard window ─────────────────────────────────────────────────────────────
class WizardWindow(QMainWindow):
    """Linear first-run wizard. On close writes a sentinel so future launches
    open the hub (MainWindow) instead."""

    _STEP_LABELS = ["Welcome", "Update", "Hardware", "Pick Apps", "Gaming", "All Done"]

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Welcome to KythOS")
        self.setMinimumSize(840, 600)
        self.resize(980, 700)

        root = QWidget()
        root.setObjectName("content-area")
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)
        self.setCentralWidget(root)

        # ── Header: logo + step progress track ───────────────────────────────
        header = QWidget()
        header.setObjectName("wizard-header")
        header.setFixedHeight(60)
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(36, 0, 36, 0)
        header_layout.setSpacing(0)

        logo = QLabel("KythOS")
        logo.setObjectName("sidebar-logo")
        header_layout.addWidget(logo)
        header_layout.addStretch()

        # Step progress track (dot + connector + label per step)
        self._step_label_widgets: list[QLabel] = []
        progress_widget = QWidget()
        progress_layout = QHBoxLayout(progress_widget)
        progress_layout.setContentsMargins(0, 0, 0, 0)
        progress_layout.setSpacing(0)

        for i, label in enumerate(self._STEP_LABELS):
            if i > 0:
                connector = QFrame()
                connector.setFixedSize(28, 2)
                connector.setStyleSheet("background: #4a4a4a; border: none;")
                progress_layout.addWidget(connector)

            step_col = QWidget()
            step_col_layout = QVBoxLayout(step_col)
            step_col_layout.setContentsMargins(0, 0, 0, 0)
            step_col_layout.setSpacing(4)
            step_col_layout.setAlignment(Qt.AlignmentFlag.AlignHCenter)

            dot = QLabel()
            dot.setFixedSize(10, 10)
            dot.setObjectName("step-dot-inactive")
            dot.setAlignment(Qt.AlignmentFlag.AlignCenter)
            step_col_layout.addWidget(dot, 0, Qt.AlignmentFlag.AlignHCenter)

            lbl = QLabel(label)
            lbl.setObjectName("wizard-progress-step")
            lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            step_col_layout.addWidget(lbl, 0, Qt.AlignmentFlag.AlignHCenter)

            progress_layout.addWidget(step_col)
            self._step_label_widgets.append((dot, lbl))  # type: ignore[assignment]

        header_layout.addWidget(progress_widget)
        root_layout.addWidget(header)

        # Accent line
        accent = QFrame()
        accent.setFixedHeight(2)
        accent.setStyleSheet("background: #0078d4; border: none;")
        root_layout.addWidget(accent)

        # ── Content stack ─────────────────────────────────────────────────
        self._stack = QStackedWidget()
        self._stack.setObjectName("content-area")
        root_layout.addWidget(self._stack, 1)

        self._profile = _load_profile()
        self._handoff_win: QMainWindow | None = None
        self._update_page = UpdatePage()
        self._hw_page = HardwarePage(wizard_mode=True)
        self._hw_page.action_requested.connect(self._on_hw_action_requested)
        self._gaming_page = GamingPage(wizard_mode=True)
        self._first_run_apps_step = self._make_first_run_apps_step()

        self._steps = [
            self._make_welcome_step(),
            self._wrap_step(
                "Update Your System",
                "Start with the latest OS image and packages before getting started.",
                self._update_page,
            ),
            self._wrap_step(
                "Hardware Check",
                "Checking your GPU, CPU, display, controllers, audio, and peripherals.",
                self._hw_page,
            ),
            self._first_run_apps_step,
            self._make_gaming_step(),
            self._make_finish_step(),
        ]
        for step in self._steps:
            self._stack.addWidget(step)

        # ── Footer ────────────────────────────────────────────────────────
        footer = QWidget()
        footer.setObjectName("wizard-footer")
        footer.setFixedHeight(68)
        footer_layout = QHBoxLayout(footer)
        footer_layout.setContentsMargins(36, 0, 36, 0)
        footer_layout.setSpacing(10)

        self._back_btn = QPushButton("← Back")
        self._back_btn.setFixedWidth(100)
        self._back_btn.clicked.connect(self._go_back)
        footer_layout.addWidget(self._back_btn)
        footer_layout.addStretch()

        self._skip_btn = QPushButton("Skip for now")
        self._skip_btn.clicked.connect(self._go_next)
        footer_layout.addWidget(self._skip_btn)

        self._next_btn = QPushButton("Get Started  →")
        self._next_btn.setObjectName("primary")
        self._next_btn.setFixedWidth(160)
        self._next_btn.clicked.connect(self._go_next)
        footer_layout.addWidget(self._next_btn)
        root_layout.addWidget(footer)


        self._current = 0
        self._busy_timer = QTimer(self)
        self._busy_timer.setInterval(250)
        self._busy_timer.timeout.connect(self._update_nav)
        self._busy_timer.start()
        self._update_nav()

    # ── Step builders ─────────────────────────────────────────────────────────

    def _wrap_step(self, title: str, subtitle: str, page: QWidget) -> QWidget:
        container = QWidget()
        container.setObjectName("content-area")
        layout = QVBoxLayout(container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        intro = QWidget()
        intro.setObjectName("page-header")
        intro_layout = QVBoxLayout(intro)
        intro_layout.setContentsMargins(56, 22, 56, 20)
        intro_layout.setSpacing(5)
        title_lbl = QLabel(title)
        title_lbl.setObjectName("heading")
        subtitle_lbl = QLabel(subtitle)
        subtitle_lbl.setObjectName("subheading")
        intro_layout.addWidget(title_lbl)
        intro_layout.addWidget(subtitle_lbl)
        layout.addWidget(intro)

        layout.addWidget(_divider())
        layout.addWidget(page, 1)
        return container

    def _blocked_game_summary(self, limit: int = 5) -> str:
        blocked = [game for game in _COMPAT_GAMES if game.status == "blocked"]
        if not blocked:
            return ""
        names = [game.name for game in blocked[:limit]]
        summary = ", ".join(names)
        if len(blocked) > limit:
            summary += f", and {len(blocked) - limit} more"
        return summary

    def _make_switch_preflight_card(self) -> QFrame | None:
        rows: list[str] = []
        blocked_summary = self._blocked_game_summary()
        if blocked_summary:
            rows.append(
                "Known hard blockers: "
                f"{blocked_summary}. These are publisher anti-cheat decisions, not Proton settings."
            )
        if not _IS_LIVE and _find_ntfs_drives():
            rows.append(
                "Windows game drive detected. Copy Steam libraries to a Linux-formatted disk before using Proton."
            )
        if _detect_nvidia():
            rows.append(
                "NVIDIA GPU detected. The driver page will verify the proprietary module and reboot state."
            )
        if _has_rollback_deployment():
            rows.append(
                "Rollback is available. If an update makes games worse, return to the previous image first."
            )
        if not rows:
            return None

        card, layout = _make_card("card-accent-warn")
        title = QLabel("Check these before moving your library")
        title.setObjectName("card-title")
        layout.addWidget(title)
        for text in rows:
            row = QLabel("- " + text)
            row.setObjectName("card-copy")
            row.setWordWrap(True)
            layout.addWidget(row)
        return card

    def _make_welcome_step(self) -> QWidget:
        page = QWidget()
        page.setObjectName("content-area")
        outer = QVBoxLayout(page)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # Hero
        hero = QWidget()
        hero.setObjectName("wizard-hero")
        hero_layout = QVBoxLayout(hero)
        hero_layout.setContentsMargins(72, 60, 72, 54)
        hero_layout.setSpacing(16)

        logo = QLabel("KythOS")
        logo.setObjectName("wizard-logo")
        hero_layout.addWidget(logo)

        tagline = QLabel("Your Windows games, running on Linux.")
        tagline.setObjectName("wizard-tagline")
        hero_layout.addWidget(tagline)

        hero_layout.addSpacing(8)

        desc = QLabel(
            "KythOS runs many Steam, Epic, and GOG games through Proton, then checks "
            "the traps Windows players usually hit first: anti-cheat blockers, "
            "Windows-formatted game drives, drivers, and rollback. Xbox and "
            "PlayStation controllers connect automatically."
        )
        desc.setObjectName("wizard-desc")
        desc.setWordWrap(True)
        hero_layout.addWidget(desc)

        # ── Usage profile ──────────────────────────────────────────────────
        # Drives which apps the Pick Apps step pre-selects and whether the
        # finish step offers the Work Setup handoff.
        hero_layout.addSpacing(10)
        profile_lbl = QLabel("What will you use this PC for?")
        profile_lbl.setObjectName("card-title")
        hero_layout.addWidget(profile_lbl)

        self._profile_buttons: dict[str, QPushButton] = {}
        profile_row = QHBoxLayout()
        profile_row.setSpacing(10)
        for key, label, tip in (
            ("gaming", "🎮  Gaming", "Game-ready defaults — Steam, Discord, launchers."),
            ("work", "💼  Work", "Office apps, email, Microsoft 365, VPN, and printing."),
            ("both", "🖥  Both", "Gaming defaults plus the work essentials."),
        ):
            btn = QPushButton(label)
            btn.setCheckable(True)
            btn.setToolTip(tip)
            btn.setMinimumHeight(38)
            btn.clicked.connect(lambda _=False, k=key: self._on_profile_chosen(k))
            self._profile_buttons[key] = btn
            profile_row.addWidget(btn)
        profile_row.addStretch()
        hero_layout.addLayout(profile_row)
        self._profile_buttons[self._profile].setChecked(True)

        preflight_card = self._make_switch_preflight_card()
        if preflight_card is not None:
            hero_layout.addWidget(preflight_card)

        outer.addWidget(hero, 1)
        outer.addWidget(_divider())

        # Stats bar
        stats_bar = QWidget()
        stats_bar.setObjectName("content-area")
        stats_layout = QHBoxLayout(stats_bar)
        stats_layout.setContentsMargins(72, 20, 72, 20)
        stats_layout.setSpacing(0)

        kernel = _command_stdout(["uname", "-r"]) or "unknown"
        ge_ver = _ge_proton_version() or "included"

        scx_sched = "Fedora"
        try:
            with open("/etc/scx/scx_loader.conf") as _scx_fh:
                for _scx_line in _scx_fh:
                    if _scx_line.startswith("SCX_SCHEDULER="):
                        scx_sched = _scx_line.split("=", 1)[1].strip().replace("scx_", "").upper()
                        break
        except OSError:
            pass

        stat_items = [
            ("Kernel", kernel),
            ("GE-Proton", ge_ver),
            ("Scheduler", scx_sched),
        ]
        for i, (label, value) in enumerate(stat_items):
            if i > 0:
                sep = QFrame()
                sep.setFrameShape(QFrame.Shape.VLine)
                sep.setFixedWidth(1)
                sep.setStyleSheet("background: #3a3a3a; border: none; max-width: 1px;")
                stats_layout.addSpacing(28)
                stats_layout.addWidget(sep)
                stats_layout.addSpacing(28)
            col = QVBoxLayout()
            col.setSpacing(4)
            lbl = QLabel(label.upper())
            lbl.setObjectName("stat-label")
            val = QLabel(value)
            val.setObjectName("stat-value")
            col.addWidget(lbl)
            col.addWidget(val)
            stats_layout.addLayout(col)

        stats_layout.addStretch()
        outer.addWidget(stats_bar)
        return page

    def _make_first_run_apps_step(self) -> QWidget:
        page = QWidget()
        page.setObjectName("content-area")
        layout = QVBoxLayout(page)
        layout.setContentsMargins(56, 34, 56, 28)
        layout.setSpacing(16)

        title = QLabel("Choose Your Extras")
        title.setObjectName("heading")
        layout.addWidget(title)

        subtitle = QLabel(
            "Your core gaming setup is already handled. Pick anything else you want now; "
            "you can install or remove these later from the System Hub."
        )
        subtitle.setObjectName("subheading")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)

        core_card, core_layout = _make_card("card-accent-ok")
        core_title = QLabel("Game-ready defaults")
        core_title.setObjectName("card-title")
        core_layout.addWidget(core_title)
        core_copy = QLabel(
            "Heroic Games Launcher, Lutris, ProtonUp-Qt, and protontricks install automatically "
            "as soon as networking is available."
        )
        core_copy.setObjectName("card-copy")
        core_copy.setWordWrap(True)
        core_layout.addWidget(core_copy)
        layout.addWidget(core_card)

        prep_row = QHBoxLayout()
        prep_row.setSpacing(12)

        install_model, install_model_layout = _make_card("card-accent-ok")
        install_model_title = QLabel("Install apps the KythOS way")
        install_model_title.setObjectName("card-title")
        install_model_layout.addWidget(install_model_title)
        install_model_copy = QLabel(
            "Use App Store or Flathub first. Standalone Windows .exe and .msi installers "
            "belong in Bottles, while downloaded .rpm packages are system packages for "
            "mutable Fedora-style installs and are usually the wrong path on KythOS."
        )
        install_model_copy.setObjectName("card-copy")
        install_model_copy.setWordWrap(True)
        install_model_layout.addWidget(install_model_copy)
        install_model_btns = QHBoxLayout()
        install_model_btns.setSpacing(8)
        flathub_btn = QPushButton("Browse Flathub")
        flathub_btn.clicked.connect(
            lambda _=False: QDesktopServices.openUrl(QUrl("https://flathub.org"))
        )
        install_model_btns.addWidget(flathub_btn)
        install_model_btns.addStretch()
        install_model_layout.addLayout(install_model_btns)
        prep_row.addWidget(install_model, 1)

        gaps_card, gaps_layout = _make_card()
        gaps_title = QLabel("Check daily-driver gaps now")
        gaps_title.setObjectName("card-title")
        gaps_layout.addWidget(gaps_title)
        gaps_copy = QLabel(
            "Game Pass is browser/cloud-first here, Microsoft 365 and OneDrive use web "
            "or cloud helpers, Adobe apps need native alternatives, and iCUE, G HUB, "
            "Synapse, and SteelSeries GG become OpenRGB, Piper, or vendor-limited "
            "workflows depending on the device."
        )
        gaps_copy.setObjectName("card-copy")
        gaps_copy.setWordWrap(True)
        gaps_layout.addWidget(gaps_copy)
        prep_row.addWidget(gaps_card, 1)
        layout.addLayout(prep_row)

        self._wizard_extra_apps = [
            ("com.valvesoftware.Steam",      "Steam",         "Valve's game store and Proton launcher for your Steam library."),
            ("com.discordapp.Discord",       "Discord",       "Voice, text, and community chat — used by almost every gaming community."),
            ("com.brave.Browser",            "Brave Browser", "Fast, privacy-friendly browser with good media support."),
            ("com.obsproject.Studio",        "OBS Studio",    "Record and stream your gameplay."),
            ("org.videolan.VLC",             "VLC",           "Plays virtually every video and audio format without extra codecs."),
            ("org.libreoffice.LibreOffice",  "LibreOffice",   "Open Word, Excel, and PowerPoint files — full office suite."),
            ("org.mozilla.Thunderbird",      "Thunderbird",   "Work email, calendar, and contacts — connects to Microsoft 365, Gmail, and IMAP."),
            ("com.github.mtkennerly.ludusavi","Ludusavi",      "Back up and restore game saves before migration or modding."),
            ("org.freedesktop.Piper",         "Piper",         "Configure supported gaming mice for DPI, buttons, and LEDs."),
            ("com.moonlight_stream.Moonlight","Moonlight",     "Stream games from another PC or NVIDIA Shield on your network."),
        ]

        extras_card, extras_layout = _make_card()
        extras_title = QLabel("Optional apps")
        extras_title.setObjectName("card-title")
        extras_layout.addWidget(extras_title)

        apps_view = QScrollArea()
        apps_view.setWidgetResizable(True)
        apps_view.setMinimumHeight(230)
        apps_view.setFrameShape(QFrame.Shape.NoFrame)
        apps_view.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        apps_widget = QWidget()
        apps_layout = QVBoxLayout(apps_widget)
        apps_layout.setContentsMargins(0, 0, 8, 0)
        apps_layout.setSpacing(10)

        self._wizard_extra_checks = []
        for app_id, name, desc in self._wizard_extra_apps:
            row = QWidget()
            row.setMinimumHeight(48)
            row.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Minimum)
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(12)

            already_installed = _is_flatpak_installed(app_id)
            check = QCheckBox()
            check.setChecked(not already_installed and app_id in {"com.valvesoftware.Steam", "com.discordapp.Discord"})
            check.setEnabled(not already_installed)
            self._wizard_extra_checks.append((check, app_id, name))
            row_layout.addWidget(check, 0, Qt.AlignmentFlag.AlignTop)

            text_col = QVBoxLayout()
            text_col.setSpacing(2)
            name_lbl = QLabel(name)
            name_lbl.setObjectName("card-title")
            name_lbl.setStyleSheet("font-size: 13px;")
            desc_lbl = QLabel("Already installed." if already_installed else desc)
            desc_lbl.setObjectName("card-copy")
            desc_lbl.setWordWrap(True)
            text_col.addWidget(name_lbl)
            text_col.addWidget(desc_lbl)
            row_layout.addLayout(text_col, 1)
            apps_layout.addWidget(row)

        apps_layout.addStretch()
        apps_view.setWidget(apps_widget)
        extras_layout.addWidget(apps_view, 1)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)
        self._wizard_install_btn = QPushButton("Install Selected")
        self._wizard_install_btn.setObjectName("primary")
        self._wizard_install_btn.clicked.connect(self._install_selected_wizard_apps)
        btn_row.addWidget(self._wizard_install_btn)
        self._wizard_cancel_install_btn = QPushButton("Cancel Install")
        self._wizard_cancel_install_btn.clicked.connect(self._cancel_selected_wizard_apps)
        self._wizard_cancel_install_btn.hide()
        btn_row.addWidget(self._wizard_cancel_install_btn)
        select_none_btn = QPushButton("Clear")
        select_none_btn.clicked.connect(lambda: [check.setChecked(False) for check, _, _ in self._wizard_extra_checks])
        btn_row.addWidget(select_none_btn)
        btn_row.addStretch()
        extras_layout.addLayout(btn_row)

        self._wizard_install_status = QLabel("Select apps above, or continue if you only want the gaming defaults.")
        self._wizard_install_status.setObjectName("subheading")
        extras_layout.addWidget(self._wizard_install_status)

        self._wizard_install_progress = QProgressBar()
        self._wizard_install_progress.setRange(0, 100)
        self._wizard_install_progress.setValue(0)
        self._wizard_install_progress.hide()
        extras_layout.addWidget(self._wizard_install_progress)

        self._wizard_install_log_toggle = QPushButton("Show details")
        self._wizard_install_log_toggle.setCheckable(True)
        self._wizard_install_log_toggle.hide()
        extras_layout.addWidget(self._wizard_install_log_toggle)

        self._wizard_install_log = QTextEdit()
        self._wizard_install_log.setReadOnly(True)
        self._wizard_install_log.setMaximumHeight(120)
        self._wizard_install_log.hide()
        extras_layout.addWidget(self._wizard_install_log)
        self._wizard_install_log_toggle.clicked.connect(
            lambda checked: _set_log_panel(self._wizard_install_log_toggle, self._wizard_install_log, checked)
        )

        layout.addWidget(extras_card, 1)
        self._wizard_extra_worker = None
        return page

    def _install_selected_wizard_apps(self):
        if self._wizard_extra_worker and self._wizard_extra_worker.isRunning():
            return
        selected = [
            (app_id, name)
            for check, app_id, name in self._wizard_extra_checks
            if check.isChecked() and check.isEnabled()
        ]
        if not selected:
            self._wizard_install_status.setText("No optional apps selected.")
            self._wizard_install_status.setObjectName("status-dim")
            _restyle(self._wizard_install_status)
            return

        names = ", ".join(name for _, name in selected)
        self._wizard_install_btn.setEnabled(False)
        self._wizard_cancel_install_btn.setEnabled(True)
        self._wizard_cancel_install_btn.show()
        for check, _, _ in self._wizard_extra_checks:
            check.setEnabled(False)
        self._wizard_install_total = len(selected)
        self._wizard_install_done = 0
        self._wizard_install_status.setText(f"Preparing to install {names}...")
        self._wizard_install_status.setObjectName("subheading")
        _restyle(self._wizard_install_status)
        self._wizard_install_progress.setRange(0, len(selected))
        self._wizard_install_progress.setValue(0)
        self._wizard_install_progress.show()
        self._wizard_install_log.clear()
        self._wizard_install_log.append("-> flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo")
        for app_id, name in selected:
            self._wizard_install_log.append(f"-> flatpak install -y flathub {app_id}  # {name}")
        self._wizard_install_log.append("")
        self._wizard_install_log_toggle.show()
        _set_log_panel(self._wizard_install_log_toggle, self._wizard_install_log, False)

        script = [
            "set -e",
            "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo",
        ]
        for app_id, name in selected:
            script.append(f"echo __KYTH_APP_START__:{shlex.quote(app_id)}:{shlex.quote(name)}")
            script.append(f"flatpak install -y flathub {shlex.quote(app_id)}")
            script.append(f"echo __KYTH_APP_DONE__:{shlex.quote(app_id)}:{shlex.quote(name)}")
        cmd = ["bash", "-c", "\n".join(script)]
        self._wizard_extra_worker = Worker(cmd)
        self._wizard_extra_worker.line.connect(self._on_wizard_extra_install_line)
        self._wizard_extra_worker.done.connect(
            lambda code, installed=selected: self._on_wizard_extra_install_done(code, installed)
        )
        self._wizard_extra_worker.start()
        self._update_nav()

    def _cancel_selected_wizard_apps(self):
        reply = QMessageBox.question(
            self,
            "Cancel App Install?",
            "Stop installing the selected apps? Apps that already finished installing will remain available.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.Cancel,
            QMessageBox.StandardButton.Cancel,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        _cancel_worker(
            self,
            attr="_wizard_extra_worker",
            status_lbl=self._wizard_install_status,
            log=self._wizard_install_log,
            cancel_btn=self._wizard_cancel_install_btn,
            message="Cancelling optional app install…",
        )

    def _on_wizard_extra_install_line(self, line: str):
        if line.startswith("__KYTH_APP_START__:"):
            parts = line.split(":", 2)
            name = parts[2] if len(parts) > 2 else "selected app"
            current = getattr(self, "_wizard_install_done", 0) + 1
            total = max(1, getattr(self, "_wizard_install_total", 1))
            self._wizard_install_status.setText(f"Installing {name} ({current} of {total})...")
            self._wizard_install_status.setObjectName("subheading")
            _restyle(self._wizard_install_status)
            return
        if line.startswith("__KYTH_APP_DONE__:"):
            parts = line.split(":", 2)
            name = parts[2] if len(parts) > 2 else "app"
            self._wizard_install_done = getattr(self, "_wizard_install_done", 0) + 1
            total = max(1, getattr(self, "_wizard_install_total", 1))
            self._wizard_install_progress.setValue(self._wizard_install_done)
            self._wizard_install_status.setText(f"Installed {name} ({self._wizard_install_done} of {total}).")
            return
        self._wizard_install_log.append(line)
        self._wizard_install_log.ensureCursorVisible()

    def _on_wizard_extra_install_done(self, code: int, installed: list[tuple[str, str]]):
        _finish_worker(self, attr="_wizard_extra_worker")
        self._wizard_cancel_install_btn.hide()
        if code == Worker.CANCELLED:
            self._wizard_install_status.setText("Optional app install cancelled. Apps that finished installing are still available.")
            self._wizard_install_status.setObjectName("status-warn")
            self._wizard_install_log.append("\nCancelled.")
            for check, app_id, _ in self._wizard_extra_checks:
                check.setEnabled(not _is_flatpak_installed(app_id))
        elif code == 0:
            self._wizard_install_progress.setValue(max(1, getattr(self, "_wizard_install_total", 1)))
            self._wizard_install_status.setText("Optional apps installed.")
            self._wizard_install_status.setObjectName("status-ok")
            self._wizard_install_log.append("\nDone.")
            installed_ids = {app_id for app_id, _ in installed}
            for check, app_id, _ in self._wizard_extra_checks:
                check.setChecked(False)
                check.setEnabled(app_id not in installed_ids)
        else:
            self._wizard_install_status.setText(f"Optional app install failed (exit {code}).")
            self._wizard_install_status.setObjectName("status-err")
            for check, app_id, _ in self._wizard_extra_checks:
                check.setEnabled(not _is_flatpak_installed(app_id))
        self._wizard_install_btn.setEnabled(True)
        _restyle(self._wizard_install_status)
        self._update_nav()

    def _make_windows_game_drive_card(self, drives: list[dict]) -> QFrame:
        card, layout = _make_card("card-accent-warn")
        title = QLabel("Windows game drive found")
        title.setObjectName("card-title")
        layout.addWidget(title)
        names = []
        for drive in drives[:3]:
            label = drive.get("label") or drive.get("name") or drive.get("dev") or "Windows drive"
            size = drive.get("size") or ""
            names.append(f"{label} {size}".strip())
        listed = ", ".join(names)
        if len(drives) > 3:
            listed += f", and {len(drives) - 3} more"
        body = QLabel(
            f"Detected: {listed}. Do not point Steam at the NTFS library and start playing. "
            "Copy the library into Steam on a Linux-formatted disk first, then let Proton "
            "build clean prefixes there. The migration tool below mounts Windows read-only."
        )
        body.setObjectName("card-copy")
        body.setWordWrap(True)
        layout.addWidget(body)
        return card

    def _make_gaming_step(self) -> QWidget:
        container = QWidget()
        container.setObjectName("content-area")
        outer = QVBoxLayout(container)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        intro = QWidget()
        intro.setObjectName("page-header")
        intro_layout = QVBoxLayout(intro)
        intro_layout.setContentsMargins(56, 22, 56, 20)
        intro_layout.setSpacing(5)
        title_lbl = QLabel("Install Your Games")
        title_lbl.setObjectName("heading")
        subtitle_lbl = QLabel(
            "Install launchers for Steam, Epic, GOG, and Battle.net below. "
            "Then follow the Proton steps to unlock your full Windows library."
        )
        subtitle_lbl.setObjectName("subheading")
        subtitle_lbl.setWordWrap(True)
        intro_layout.addWidget(title_lbl)
        intro_layout.addWidget(subtitle_lbl)
        outer.addWidget(intro)
        outer.addWidget(_divider())

        # ── Proton setup card ─────────────────────────────────────────────────
        proton_section = QWidget()
        proton_section.setObjectName("content-area")
        ps_layout = QVBoxLayout(proton_section)
        ps_layout.setContentsMargins(56, 20, 56, 0)
        ps_layout.setSpacing(10)

        windows_drives = [] if _IS_LIVE else _find_ntfs_drives()
        if windows_drives:
            ps_layout.addWidget(self._make_windows_game_drive_card(windows_drives))

        proton_head = QLabel("Enable Proton — play your entire Windows library")
        proton_head.setObjectName("heading")
        proton_head.setStyleSheet("font-size: 17px; font-weight: 700; color: #ffffff;")
        ps_layout.addWidget(proton_head)

        proton_card, pc_layout = _make_card("card-accent-ok")
        intro_copy = QLabel("Do this once after Steam finishes installing:")
        intro_copy.setObjectName("card-copy")
        pc_layout.addWidget(intro_copy)

        for step in [
            "1.  Open Steam",
            "2.  Steam  →  Settings  →  Compatibility",
            "3.  Turn on  Enable Steam Play for all other titles",
            "4.  Select  GE-Proton  from the version dropdown",
            "5.  Restart Steam — your full Windows library now appears",
        ]:
            lbl = QLabel(step)
            lbl.setObjectName("card-copy")
            lbl.setStyleSheet("padding-left: 8px;")
            pc_layout.addWidget(lbl)

        tip = QLabel(
            "GE-Proton is already installed on this system and kept up to date automatically."
        )
        tip.setObjectName("card-copy")
        tip.setWordWrap(True)
        tip.setStyleSheet("color: #4cc2ff; margin-top: 6px;")
        pc_layout.addWidget(tip)
        ps_layout.addWidget(proton_card)
        outer.addWidget(proton_section)
        outer.addWidget(_divider())

        # ── Compatibility teaser ──────────────────────────────────────────────
        compat_section = QWidget()
        compat_section.setObjectName("content-area")
        cs_layout = QHBoxLayout(compat_section)
        cs_layout.setContentsMargins(56, 14, 56, 0)

        compat_card, cc_layout = _make_card()
        cc_layout.setSpacing(6)
        compat_lbl = QLabel("Check your must-play games now — before you commit an evening to one")
        compat_lbl.setObjectName("card-copy")
        compat_lbl.setStyleSheet("font-weight: 600; color: #ffffff;")
        cc_layout.addWidget(compat_lbl)
        # Front-load the hard wall: kernel-level anti-cheat is the #1 reason
        # Windows switchers give up, and no Proton setting will ever fix it.
        # Showing the blocked titles here beats discovering them the hard way.
        blocked = [game for game in _COMPAT_GAMES if game.status == "blocked"]
        if blocked:
            blocked_names = "  ·  ".join(
                f"{game.name} ({game.anticheat})" for game in blocked
            )
            blocked_lbl = QLabel(
                f"Will NOT run — blocked by kernel-level anti-cheat on every Linux system: {blocked_names}."
            )
            blocked_lbl.setObjectName("card-copy")
            blocked_lbl.setWordWrap(True)
            blocked_lbl.setStyleSheet("color: #f48771;")
            cc_layout.addWidget(blocked_lbl)
        compat_sub = QLabel(
            "The rest of the tracked list is marked native, works through Proton, or needs "
            "specific tweaks. The Compatibility page in the System Hub keeps the full list "
            "current, and ProtonDB has reports for nearly every Steam title."
        )
        compat_sub.setObjectName("card-copy")
        compat_sub.setWordWrap(True)
        compat_btn = QPushButton("Browse ProtonDB →")
        compat_btn.setObjectName("primary")
        compat_btn.setFixedWidth(200)
        compat_btn.clicked.connect(
            lambda: QDesktopServices.openUrl(QUrl("https://www.protondb.com"))
        )
        cc_layout.addWidget(compat_sub)
        cc_layout.addWidget(compat_btn)
        cs_layout.addWidget(compat_card, 1)

        outer.addWidget(compat_section)
        outer.addWidget(_divider())

        # ── Launcher grid (full GamingPage) ───────────────────────────────────
        outer.addWidget(self._gaming_page, 1)
        return container

    def _make_finish_step(self) -> QWidget:
        page = QWidget()
        page.setObjectName("content-area")
        layout = QVBoxLayout(page)
        layout.setContentsMargins(72, 0, 72, 0)
        layout.setSpacing(0)
        layout.addStretch()

        check = QLabel("✓")
        check.setStyleSheet(
            "font-size: 52px; color: #6ccb5f; font-weight: 300; background: transparent;"
        )
        layout.addWidget(check)
        layout.addSpacing(18)

        title = QLabel("You're all set.")
        title.setObjectName("finish-title")
        layout.addWidget(title)
        layout.addSpacing(10)

        subtitle = QLabel(
            "Open Steam, go to Settings → Compatibility, and enable Proton for all titles.\n"
            "Your full Windows library will appear and be ready to install.\n\n"
            "If an update makes games worse, open System Hub → Update and use Roll Back "
            "before reinstalling anything. The System Hub is always available from the app menu."
        )
        subtitle.setObjectName("finish-subtitle")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)
        layout.addSpacing(36)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)
        steam_btn = QPushButton("Open Steam")
        steam_btn.setObjectName("primary")
        steam_btn.clicked.connect(lambda: subprocess.Popen(["flatpak", "run", "com.valvesoftware.Steam"]))
        btn_row.addWidget(steam_btn)
        self._finish_work_btn = QPushButton("Open Work Setup")
        self._finish_work_btn.setToolTip(
            "Office apps, Microsoft 365 shortcuts, document fonts, VPN, shares, and printing."
        )
        self._finish_work_btn.clicked.connect(lambda: self._open_hub_at("Work Setup"))
        self._finish_work_btn.setVisible(self._profile in ("work", "both"))
        btn_row.addWidget(self._finish_work_btn)
        hub_btn = QPushButton("Open System Hub")
        hub_btn.clicked.connect(lambda: (self._next_btn.click() or None))
        btn_row.addWidget(hub_btn)
        btn_row.addStretch()
        layout.addLayout(btn_row)
        layout.addStretch()
        return page

    # ── Usage profile ──────────────────────────────────────────────────────────

    _PROFILE_DEFAULT_APPS = {
        "gaming": {"com.valvesoftware.Steam", "com.discordapp.Discord"},
        "work": {"org.libreoffice.LibreOffice", "org.mozilla.Thunderbird"},
        "both": {
            "com.valvesoftware.Steam", "com.discordapp.Discord",
            "org.libreoffice.LibreOffice", "org.mozilla.Thunderbird",
        },
    }

    def _on_profile_chosen(self, profile: str):
        self._profile = profile
        for key, btn in self._profile_buttons.items():
            btn.setChecked(key == profile)
        _save_profile(profile)
        # Re-seed the Pick Apps defaults to match the chosen profile. Only
        # enabled boxes are touched — already-installed apps stay locked.
        wanted = self._PROFILE_DEFAULT_APPS.get(profile, set())
        for check, app_id, _name in self._wizard_extra_checks:
            if check.isEnabled():
                check.setChecked(app_id in wanted)
        self._update_nav()

    def _open_hub_at(self, page_key: str):
        """Hand off from the wizard to the System Hub opened at a page."""
        _mark_wizard_done()
        main_win = MainWindow()
        main_win.setWindowIcon(QIcon.fromTheme("kyth"))
        main_win.showMaximized()
        main_win._navigate_to(page_key)
        self._handoff_win = main_win
        self.close()

    # ── Navigation ────────────────────────────────────────────────────────────

    def _has_running_operation(self) -> bool:
        workers = (
            self._wizard_extra_worker,
            self._update_page._worker,
            self._gaming_page._tool_worker,
        )
        return any(worker is not None and worker.isRunning() for worker in workers)

    def _update_nav(self):
        idx = self._current
        total = len(self._steps)
        operation_busy = self._has_running_operation()

        for i, (dot, lbl) in enumerate(self._step_label_widgets):
            if i < idx:
                dot.setObjectName("step-dot-done")
                lbl.setObjectName("wizard-progress-step-done")
            elif i == idx:
                dot.setObjectName("step-dot-active")
                lbl.setObjectName("wizard-progress-step-active")
            else:
                dot.setObjectName("step-dot-inactive")
                lbl.setObjectName("wizard-progress-step")
            _restyle(dot)
            _restyle(lbl)

        self._back_btn.setVisible(idx > 0)
        self._skip_btn.setVisible(0 < idx < total - 1)
        self._back_btn.setEnabled(not operation_busy)
        self._skip_btn.setEnabled(not operation_busy)
        self._next_btn.setEnabled(not operation_busy)
        if hasattr(self, "_finish_work_btn"):
            self._finish_work_btn.setVisible(self._profile in ("work", "both"))

        if idx == total - 1:
            self._next_btn.setText("Close")
        elif idx == 0:
            self._next_btn.setText("Get Started  →")
        else:
            self._next_btn.setText("Next  →")

    def _on_hw_action_requested(self, page_key: str):
        self._open_hub_at(page_key)

    def _go_back(self):
        if self._current > 0:
            self._current -= 1
            self._stack.setCurrentIndex(self._current)
            self._update_nav()

    def _go_next(self):
        if self._current == len(self._steps) - 1:
            _mark_wizard_done()
            self.close()
        else:
            self._current += 1
            self._stack.setCurrentIndex(self._current)
            self._update_nav()

    def closeEvent(self, event):
        if self._has_running_operation():
            QMessageBox.warning(
                self,
                "KythOS Is Busy",
                "A setup task is still running. Cancel it from the current page while cancellation is available, or wait for it to finish before closing.",
            )
            event.ignore()
            self.raise_()
            self.activateWindow()
            return
        _mark_wizard_done()
        super().closeEvent(event)
