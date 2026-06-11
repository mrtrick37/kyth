from dataclasses import dataclass

# __KYTH_GENERATED_IMPORTS__
from .qt import (  # noqa: E501
    QDesktopServices, QFrame, QHBoxLayout, QLabel, QPushButton, QUrl, QVBoxLayout, QWidget, Qt,
)
from .widgets import (  # noqa: E501
    Page, _make_card,
)

@dataclass(frozen=True)
class CompatGame:
    name: str
    anticheat: str
    status: str
    note: str
    checked: str
    source: str
    source_url: str


# ── Game compatibility data ────────────────────────────────────────────────────
# Status values: "native" | "proton" | "tweaks" | "blocked"
# Anti-cheat values used as display tags. Every entry carries a date/source so
# stale anti-cheat claims are easy to audit during release validation.
_COMPAT_GAMES: list[CompatGame] = [
    # ── Native Linux builds ──────────────────────────────────────────────────
    CompatGame("Counter-Strike 2", "VAC", "native", "Native Linux client; full competitive matchmaking.", "2026-05-18", "Steam store / KythOS validation target", "https://store.steampowered.com/app/730/CounterStrike_2/"),
    CompatGame("Dota 2", "VAC", "native", "Native Linux client.", "2026-05-18", "Steam store", "https://store.steampowered.com/app/570/Dota_2/"),
    CompatGame("Team Fortress 2", "VAC", "native", "Native Linux client.", "2026-05-18", "Steam store", "https://store.steampowered.com/app/440/Team_Fortress_2/"),
    CompatGame("Baldur's Gate 3", "None", "native", "Native Linux client. Proton is also worth testing for regressions.", "2026-05-18", "Steam store / validation matrix", "https://store.steampowered.com/app/1086940/Baldurs_Gate_3/"),
    CompatGame("The Witcher 3", "None", "native", "Native Linux client included.", "2026-05-18", "Steam store", "https://store.steampowered.com/app/292030/The_Witcher_3_Wild_Hunt/"),
    CompatGame("Hollow Knight", "None", "native", "Native Linux client.", "2026-05-18", "Steam store", "https://store.steampowered.com/app/367520/Hollow_Knight/"),
    CompatGame("Stardew Valley", "None", "native", "Native Linux client.", "2026-05-18", "Steam store", "https://store.steampowered.com/app/413150/Stardew_Valley/"),
    CompatGame("Terraria", "None", "native", "Native Linux client.", "2026-05-18", "Steam store", "https://store.steampowered.com/app/105600/Terraria/"),
    # ── Works via Proton (no AC or AC with Linux support) ────────────────────
    CompatGame("Elden Ring", "None", "proton", "Platinum-rated community reports; online path is part of KythOS validation.", "2026-05-18", "ProtonDB / KythOS validation target", "https://www.protondb.com/app/1245620"),
    CompatGame("Cyberpunk 2077", "None", "proton", "Excellent Proton support. Test HDR, FSR, and frame pacing on each release.", "2026-05-18", "ProtonDB / KythOS validation target", "https://www.protondb.com/app/1091500"),
    CompatGame("Red Dead Redemption 2", "Rockstar", "proton", "Gold community reports; Rockstar Launcher remains the risk surface.", "2026-05-18", "ProtonDB / KythOS validation target", "https://www.protondb.com/app/1174180"),
    CompatGame("GTA V", "Rockstar", "proton", "Story mode and launcher path need periodic revalidation.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/271590"),
    CompatGame("God of War", "None", "proton", "Platinum-rated community reports.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/1593500"),
    CompatGame("Hogwarts Legacy", "None", "proton", "Gold-rated community reports.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/990080"),
    CompatGame("Spider-Man Remastered", "None", "proton", "Gold/Platinum community reports.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/1817070"),
    CompatGame("Resident Evil 4 (2023)", "None", "proton", "Works via Proton.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/2050650"),
    CompatGame("Sekiro", "None", "proton", "Platinum community reports.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/814380"),
    CompatGame("Dark Souls III", "VAC", "proton", "Works via Proton; VAC does not restrict Linux for this title.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/374320"),
    CompatGame("Monster Hunter: World", "None", "proton", "Gold community reports.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/582010"),
    CompatGame("Hades", "None", "proton", "Platinum community reports.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/1145360"),
    CompatGame("Deep Rock Galactic", "EAC", "proton", "EAC Linux support is enabled; retest after major anti-cheat updates.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/548430"),
    CompatGame("Dead by Daylight", "EAC", "proton", "EAC Linux support is enabled; retest after major game updates.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/381210"),
    CompatGame("The Finals", "EAC", "proton", "EAC Linux path has community support; validate matchmaking on release images.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/2073850"),
    CompatGame("Halo Infinite", "EAC", "proton", "EAC Linux support is enabled.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/1240440"),
    CompatGame("Overwatch 2", "Warden", "proton", "Runs via Proton + Battle.net through Lutris/umu. Launcher flow is the main risk.", "2026-05-18", "ProtonDB / KythOS validation target", "https://www.protondb.com/app/2357570"),
    CompatGame("Paladins", "EAC", "proton", "EAC Linux support is enabled by the publisher.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/444090"),
    # ── Works with tweaks ────────────────────────────────────────────────────
    CompatGame("Rainbow Six Siege", "BattlEye", "tweaks", "Mostly works; occasional BattlEye launch failures. Try PROTON_NO_ESYNC=1 if it fails to start.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/359550"),
    CompatGame("Hunt: Showdown", "BattlEye", "tweaks", "BattlEye enabled but reports are mixed. Check ProtonDB before promising support.", "2026-05-18", "ProtonDB", "https://www.protondb.com/app/594650"),
    CompatGame("Warframe", "EAC", "tweaks", "EAC Linux support enabled; occasionally needs a specific Proton version.", "2026-05-18", "ProtonDB / KythOS validation target", "https://www.protondb.com/app/230410"),
    # ── Blocked ──────────────────────────────────────────────────────────────
    CompatGame("Apex Legends", "EAC", "blocked", "EA removed Steam Deck/Linux support in 2024. Retest only if EA announces a policy reversal.", "2026-05-18", "EA / ProtonDB", "https://www.protondb.com/app/1172470"),
    CompatGame("Destiny 2", "BattlEye", "blocked", "Bungie states SteamOS/Proton is unsupported and warns against bypass attempts.", "2026-05-18", "Bungie Help", "https://help.bungie.net/hc/en-us/articles/360049517431-Destiny-Account-Restrictions-and-Banning-Policies"),
    CompatGame("Rust", "EAC", "blocked", "Facepunch has publicly said there are no current Proton/Linux support plans.", "2026-05-18", "Facepunch statement coverage", "https://www.pcgamer.com/games/survival-crafting/rust-developer-has-no-plans-for-linux-or-proton-support-says-games-that-support-them-are-not-serious-about-anti-cheat/"),
    CompatGame("PUBG", "BattlEye", "blocked", "Treat as blocked until KythOS validation confirms current official Proton support.", "2026-05-18", "KythOS conservative policy", "https://areweanticheatyet.com"),
    CompatGame("Valorant", "Vanguard", "blocked", "Riot Vanguard requires ring-0 kernel access: Windows-only driver. No Linux support from Riot.", "2026-05-18", "Riot Vanguard architecture", "https://support-valorant.riotgames.com/hc/en-us/articles/360046160933-VALORANT-anti-cheat-FAQ"),
    CompatGame("Fortnite", "EAC", "blocked", "Epic has not enabled Linux support for Fortnite, despite EAC supporting Linux for other games.", "2026-05-18", "Are We Anti-Cheat Yet", "https://areweanticheatyet.com"),
    CompatGame("Call of Duty (MP/WZ)", "RICOCHET", "blocked", "RICOCHET anti-cheat runs at kernel level on Windows and has no Linux support.", "2026-05-18", "Are We Anti-Cheat Yet", "https://areweanticheatyet.com"),
    CompatGame("Roblox", "Hyperion", "blocked", "Roblox's Byfron/Hyperion anti-cheat blocks Wine/Proton paths.", "2026-05-18", "Are We Anti-Cheat Yet", "https://areweanticheatyet.com"),
    CompatGame("League of Legends", "Vanguard", "blocked", "Riot migrated LoL to Vanguard in 2024. Same Linux blocker as Valorant.", "2026-05-18", "Riot Vanguard architecture", "https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/"),
    CompatGame("Escape from Tarkov", "BattlEye", "blocked", "BattlEye can support Linux, but this title has not enabled a supported Proton path.", "2026-05-18", "Are We Anti-Cheat Yet", "https://areweanticheatyet.com"),
    CompatGame("Lost Ark", "GameGuard", "blocked", "nProtect GameGuard is kernel-level and blocks Linux.", "2026-05-18", "Are We Anti-Cheat Yet", "https://areweanticheatyet.com"),
]

_COMPAT_AC_EXPLAINERS: list[tuple[str, str, str]] = [
    # (ac_name, status, explanation)
    ("Valve Anti-Cheat (VAC)",
     "ok",
     "Runs in user-space inside the game process. Works on Linux without restriction."),
    ("Easy Anti-Cheat (EAC)",
     "ok",
     "Supports Linux natively — but only when the game developer flips the switch to enable it. "
     "EAC can run in kernel mode on Windows; those games are blocked. Check per-game status below."),
    ("BattlEye",
     "ok",
     "Same story as EAC: full Linux support exists, but each developer must opt in. "
     "Most major BattlEye titles have enabled it. A few have not."),
    ("Vanguard / RICOCHET / Hyperion",
     "err",
     "These anti-cheats load a Windows kernel driver at boot. There is no Linux equivalent "
     "and the vendors have not announced plans to change this. These games are currently unplayable on Linux."),
]


# ── Page: Compatibility ───────────────────────────────────────────────────────
class CompatibilityPage(Page):

    _STATUS_STYLE: dict[str, tuple[str, str, str]] = {
        # status → (badge_text, badge_css, row_left_border_color)
        "native":  ("Native",       "background:#121e2d; color:#4fc1ff; border:1px solid #1c3d60;",  "#4fc1ff"),
        "proton":  ("Works",        "background:#121e2d; color:#4fc1ff; border:1px solid #1c3d60;",  "#4fc1ff"),
        "tweaks":  ("Tweaks",       "background:#1e1a06; color:#d4a843; border:1px solid #5c4e14;",  "#d4a843"),
        "blocked": ("Blocked",      "background:#3a1010; color:#f48771; border:1px solid #5a1a1a;",  "#f48771"),
    }
    _AC_BADGE_CSS = (
        "font-size:10px; font-weight:600; border-radius:3px; padding:1px 6px; "
        "background:#252526; color:#a6a6a6; border:1px solid #3c3c3c;"
    )

    def __init__(self):
        super().__init__()
        self._page_header(
            "Gaming",
            "Game Compatibility",
            "Most of your library works. Here's the full picture before you switch.",
        )

        # ── Summary bar ───────────────────────────────────────────────────────
        works   = sum(1 for game in _COMPAT_GAMES if game.status in ("native", "proton", "tweaks"))
        blocked = sum(1 for game in _COMPAT_GAMES if game.status == "blocked")
        total   = len(_COMPAT_GAMES)
        oldest_check = min((game.checked for game in _COMPAT_GAMES), default="unknown")

        sum_card, sum_layout = _make_card("card-accent-ok")
        sum_layout.setSpacing(4)
        sum_title = QLabel(
            f"{works} of the {total} listed games work on KythOS — "
            f"including most of the Steam top 100."
        )
        sum_title.setObjectName("card-title")
        sum_title.setWordWrap(True)
        sum_layout.addWidget(sum_title)
        sum_copy = QLabel(
            f"The {blocked} blocked titles are tracked conservatively: if a publisher blocks "
            "or refuses SteamOS/Proton, KythOS marks it blocked until release validation proves "
            f"otherwise. Oldest source check in this list: {oldest_check}."
        )
        sum_copy.setObjectName("card-copy")
        sum_copy.setWordWrap(True)
        sum_layout.addWidget(sum_copy)
        self._add(sum_card)

        # ── Anti-cheat explainers ─────────────────────────────────────────────
        self._divider()
        ac_head = QLabel("How anti-cheat works on Linux")
        ac_head.setObjectName("heading")
        ac_head.setStyleSheet("font-size:17px; font-weight:700; color:#ffffff;")
        self._add(ac_head)

        for ac_name, ac_status, ac_text in _COMPAT_AC_EXPLAINERS:
            card_name = "hw-card-ok" if ac_status == "ok" else "hw-card-err"
            card = QFrame()
            card.setObjectName(card_name)
            cl = QHBoxLayout(card)
            cl.setContentsMargins(16, 12, 16, 12)
            cl.setSpacing(14)
            dot = QLabel("✓" if ac_status == "ok" else "✗")
            dot.setStyleSheet(
                f"font-size:18px; font-weight:700; color:{'#4fc1ff' if ac_status == 'ok' else '#f48771'};"
                " background:transparent; border:none;"
            )
            dot.setFixedWidth(20)
            dot.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignHCenter)
            cl.addWidget(dot)
            text_col = QVBoxLayout()
            text_col.setSpacing(3)
            name_lbl = QLabel(ac_name)
            name_lbl.setObjectName("card-title")
            name_lbl.setStyleSheet("font-size:13px;")
            desc_lbl = QLabel(ac_text)
            desc_lbl.setObjectName("card-copy")
            desc_lbl.setWordWrap(True)
            text_col.addWidget(name_lbl)
            text_col.addWidget(desc_lbl)
            cl.addLayout(text_col, 1)
            self._add(card)

        # ── Game list ─────────────────────────────────────────────────────────
        self._divider()
        games_head = QLabel("Notable games")
        games_head.setObjectName("heading")
        games_head.setStyleSheet("font-size:17px; font-weight:700; color:#ffffff;")
        self._add(games_head)

        filter_row = QHBoxLayout()
        filter_row.setSpacing(8)
        self._filter_all  = self._make_filter_btn("All",     None,        True)
        self._filter_works = self._make_filter_btn("Works",  ("native", "proton"), False)
        self._filter_tweaks = self._make_filter_btn("Tweaks", ("tweaks",), False)
        self._filter_blocked = self._make_filter_btn("Blocked", ("blocked",), False)
        for btn in (self._filter_all, self._filter_works, self._filter_tweaks, self._filter_blocked):
            filter_row.addWidget(btn)
        filter_row.addStretch()
        self._add_layout(filter_row)

        self._game_rows: list[tuple[QFrame, str]] = []  # (widget, status)
        for game in _COMPAT_GAMES:
            row = self._make_game_row(game)
            self._game_rows.append((row, game.status))
            self._add(row)

        # ── Windows apps via Bottles / Lutris ─────────────────────────────────
        self._divider()
        winapps_head = QLabel("Known-working Windows apps")
        winapps_head.setObjectName("heading")
        winapps_head.setStyleSheet("font-size:17px; font-weight:700; color:#ffffff;")
        self._add(winapps_head)

        winapps_intro = QLabel(
            "These apps run on KythOS via Bottles or Lutris. "
            "Use the Gaming page → Launcher setup to install launchers. "
            "For standalone .exe or .msi installers, open Bottles and create a new bottle."
        )
        winapps_intro.setObjectName("card-copy")
        winapps_intro.setWordWrap(True)
        self._add(winapps_intro)

        _WINAPPS: list[tuple[str, str, str, str]] = [
            # (name, status, tool, note)
            ("EA App",            "proton",  "Lutris",   "Use the Gaming page → Install EA App button. Installs via Lutris script."),
            ("Battle.net",        "proton",  "Lutris",   "Use the Gaming page → Install Battle.net. Installs Overwatch, Diablo, etc."),
            ("Ubisoft Connect",   "proton",  "Lutris",   "Use the Gaming page → Install Ubisoft Connect for Ubisoft game library."),
            ("Rockstar Launcher", "tweaks",  "Bottles",  "Create a Gaming bottle in Bottles and run the RGSC installer .exe."),
            ("Vortex (Nexus)",    "tweaks",  "Bottles",  "Create a Gaming bottle, install Vortex .exe. Works for most Bethesda mods."),
            ("GOG Galaxy",        "proton",  "Heroic",   "Heroic handles your GOG library natively — no GOG Galaxy needed."),
            ("Epic Games Store",  "proton",  "Heroic",   "Heroic replaces the Epic Games Launcher for your Epic library."),
            ("Xbox App",          "blocked", "—",        "No Linux client. Use Xbox Cloud Gaming (above) for Game Pass streaming."),
        ]
        for name, status, tool, note in _WINAPPS:
            badge_text, badge_css, border_color = CompatibilityPage._STATUS_STYLE.get(
                status, CompatibilityPage._STATUS_STYLE["tweaks"]
            )
            wa_row = QFrame()
            wa_row.setObjectName("hw-card-dim")
            wa_row.setStyleSheet(
                f"QFrame#hw-card-dim {{ border-left: 3px solid {border_color}; border-radius:4px; }}"
            )
            wa_rl = QHBoxLayout(wa_row)
            wa_rl.setContentsMargins(14, 8, 14, 8)
            wa_rl.setSpacing(10)
            wa_name = QLabel(name)
            wa_name.setObjectName("card-summary")
            wa_name.setStyleSheet("font-size:13px; font-weight:600;")
            wa_rl.addWidget(wa_name, 1)
            wa_tool_lbl = QLabel(f"  {tool}  ")
            wa_tool_lbl.setStyleSheet(
                "font-size:10px; font-weight:600; border-radius:3px; padding:1px 6px; "
                "background:#252526; color:#cccccc; border:1px solid #3c3c3c;"
            )
            wa_rl.addWidget(wa_tool_lbl)
            wa_badge = QLabel(f"  {badge_text}  ")
            wa_badge.setStyleSheet(badge_css + " border-radius:3px; padding:2px 8px; font-size:11px; font-weight:700;")
            wa_badge.setToolTip(note)
            wa_rl.addWidget(wa_badge)
            note_lbl = QLabel(note)
            note_lbl.setObjectName("card-copy")
            note_lbl.setWordWrap(True)
            wa_vl = QVBoxLayout()
            wa_vl.setSpacing(0)
            wa_vl.addWidget(wa_row)
            note_lbl.setContentsMargins(17, 2, 0, 0)
            wa_vl.addWidget(note_lbl)
            container = QWidget()
            container.setLayout(wa_vl)
            self._add(container)

        # ── ProtonDB CTA ──────────────────────────────────────────────────────
        self._divider()
        pdb_card, pdb_layout = _make_card()
        pdb_title = QLabel("Check any game — ProtonDB")
        pdb_title.setObjectName("card-title")
        pdb_layout.addWidget(pdb_title)
        pdb_copy = QLabel(
            "ProtonDB has compatibility reports from thousands of Linux gamers for "
            "nearly every title on Steam. If a game isn't listed above, look it up there."
        )
        pdb_copy.setObjectName("card-copy")
        pdb_copy.setWordWrap(True)
        pdb_layout.addWidget(pdb_copy)
        pdb_btn = QPushButton("Open ProtonDB  →")
        pdb_btn.setObjectName("primary")
        pdb_btn.clicked.connect(
            lambda: QDesktopServices.openUrl(QUrl("https://www.protondb.com"))
        )
        pdb_layout.addWidget(pdb_btn)
        self._add(pdb_card)

        # ── Cloud Gaming — Xbox Game Pass workaround ──────────────────────────
        self._divider()
        cloud_head = QLabel("Cloud gaming (Xbox Game Pass workaround)")
        cloud_head.setObjectName("heading")
        cloud_head.setStyleSheet("font-size:17px; font-weight:700; color:#ffffff;")
        self._add(cloud_head)

        cloud_card, cloud_layout = _make_card("card-accent-warn")
        cloud_title = QLabel("Xbox Game Pass — cloud streaming works today")
        cloud_title.setObjectName("card-title")
        cloud_layout.addWidget(cloud_title)
        cloud_body = QLabel(
            "The native Xbox app is Windows-only and there is no Linux client. "
            "However, Xbox Cloud Gaming (xCloud) streams your Game Pass library to any "
            "browser — no install required. Performance depends on your connection, "
            "and a controller is strongly recommended. For competitive or latency-sensitive games, "
            "keep a Windows dual-boot until a native solution ships."
        )
        cloud_body.setObjectName("card-copy")
        cloud_body.setWordWrap(True)
        cloud_layout.addWidget(cloud_body)
        cloud_btns = QHBoxLayout()
        cloud_btns.setSpacing(8)
        xbox_btn = QPushButton("Open Xbox Cloud Gaming")
        xbox_btn.setObjectName("primary")
        xbox_btn.clicked.connect(
            lambda: QDesktopServices.openUrl(QUrl("https://www.xbox.com/play"))
        )
        cloud_btns.addWidget(xbox_btn)
        cloud_btns.addStretch()
        cloud_layout.addLayout(cloud_btns)
        self._add(cloud_card)

        alt_card, alt_layout = _make_card()
        alt_title = QLabel("Other cloud gaming services — fully supported on Linux")
        alt_title.setObjectName("card-title")
        alt_layout.addWidget(alt_title)
        alt_body = QLabel(
            "These services work in Firefox or Chrome on KythOS with no configuration needed. "
            "GeForce NOW is the best option for library games you already own on Steam."
        )
        alt_body.setObjectName("card-copy")
        alt_body.setWordWrap(True)
        alt_layout.addWidget(alt_body)
        alt_btns = QHBoxLayout()
        alt_btns.setSpacing(8)
        for label, url in (
            ("GeForce NOW", "https://www.geforcenow.com"),
            ("Amazon Luna",  "https://luna.amazon.com"),
            ("Boosteroid",   "https://boosteroid.com"),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, u=url: QDesktopServices.openUrl(QUrl(u)))
            alt_btns.addWidget(btn)
        alt_btns.addStretch()
        alt_layout.addLayout(alt_btns)
        self._add(alt_card)

        self._stretch()

    # ── helpers ───────────────────────────────────────────────────────────────

    def _make_filter_btn(self, label: str, statuses: tuple | None, active: bool) -> QPushButton:
        btn = QPushButton(label)
        btn.setCheckable(True)
        btn.setChecked(active)
        btn.setFixedHeight(28)
        btn.setStyleSheet(
            "QPushButton { border-radius:4px; padding:2px 14px; font-size:12px; "
            "background:#252526; color:#cccccc; border:1px solid #3c3c3c; }"
            "QPushButton:checked { background:#3a2d3a; color:#4fc1ff; border-color:#4fc1ff; }"
        )
        btn.clicked.connect(lambda _=False, s=statuses: self._apply_filter(s))
        return btn

    def _apply_filter(self, statuses: tuple | None):
        for btn in (self._filter_all, self._filter_works, self._filter_tweaks, self._filter_blocked):
            btn.setChecked(False)
        if statuses is None:
            self._filter_all.setChecked(True)
        elif "blocked" in statuses:
            self._filter_blocked.setChecked(True)
        elif "tweaks" in statuses:
            self._filter_tweaks.setChecked(True)
        else:
            self._filter_works.setChecked(True)

        for row, status in self._game_rows:
            row.setVisible(statuses is None or status in statuses)

    def _make_game_row(self, game: CompatGame) -> QFrame:
        badge_text, badge_css, border_color = self._STATUS_STYLE.get(
            game.status, self._STATUS_STYLE["tweaks"]
        )
        row = QFrame()
        row.setObjectName("hw-card-dim")
        row.setStyleSheet(
            f"QFrame#hw-card-dim {{ border-left: 3px solid {border_color}; border-radius:4px; }}"
        )
        rl = QHBoxLayout(row)
        rl.setContentsMargins(14, 8, 14, 8)
        rl.setSpacing(10)

        name_lbl = QLabel(game.name)
        name_lbl.setObjectName("card-summary")
        name_lbl.setStyleSheet("font-size:13px; font-weight:600;")
        rl.addWidget(name_lbl, 1)

        tooltip = (
            f"{game.note}\n\n"
            f"Checked: {game.checked}\n"
            f"Source: {game.source}\n{game.source_url}"
        )
        name_lbl.setToolTip(tooltip)
        row.setToolTip(tooltip)

        ac_lbl = QLabel(game.anticheat)
        ac_lbl.setStyleSheet(self._AC_BADGE_CSS)
        ac_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        ac_lbl.setFixedHeight(20)
        rl.addWidget(ac_lbl)

        checked_lbl = QLabel(game.checked)
        checked_lbl.setStyleSheet("font-size:10px; color:#858585;")
        checked_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        rl.addWidget(checked_lbl)

        badge = QLabel(f"  {badge_text}  ")
        badge.setStyleSheet(
            badge_css + " border-radius:3px; padding:2px 8px; font-size:11px; font-weight:700;"
        )
        badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        rl.addWidget(badge)

        return row
