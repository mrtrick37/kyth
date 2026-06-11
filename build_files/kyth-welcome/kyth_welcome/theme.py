
# __KYTH_GENERATED_IMPORTS__


QSS = """
* {
    font-family: "Noto Sans", "Segoe UI", sans-serif;
    font-size: 13px;
    color: #d8dee9;
}

QMainWindow {
    background: #111418;
}

QWidget {
    background: transparent;
}

QLabel {
    background: transparent;
}

/* ── Sidebar ─────────────────────────────────────────────────────────────── */
QWidget#sidebar {
    background: #151922;
    border-right: 1px solid #252b36;
}

QWidget#sidebar-header {
    background: #151922;
    border-bottom: 1px solid #252b36;
}

QLabel#sidebar-logo {
    font-size: 22px;
    font-weight: 800;
    color: #f8fafc;
    letter-spacing: 0;
    padding: 0;
}

QLabel#sidebar-ver {
    font-size: 11px;
    color: #8ea0b8;
    font-weight: 600;
    padding: 0;
}

QLabel#nav-section {
    font-size: 10px;
    font-weight: 700;
    color: #6f7f95;
    letter-spacing: 1px;
    padding: 0 0 2px 0;
}

QPushButton#nav-item {
    background: transparent;
    color: #b8c3d4;
    border: 1px solid transparent;
    border-radius: 8px;
    padding: 9px 12px;
    text-align: left;
    font-size: 13px;
    font-weight: 500;
}

QPushButton#nav-item:hover {
    background: #202838;
    color: #f8fafc;
    border: 1px solid #2d384d;
}

QPushButton#nav-item-active {
    background: #223246;
    color: #ffffff;
    border: 1px solid #3f8cff;
    border-radius: 8px;
    padding: 9px 12px;
    text-align: left;
    font-size: 13px;
    font-weight: 700;
}

/* ── Content area ────────────────────────────────────────────────────────── */
QWidget#content-area {
    background: #111418;
}

QScrollArea {
    background: transparent;
    border: none;
}

/* ── Page header band ────────────────────────────────────────────────────── */
QWidget#page-header {
    background: #111418;
    border-bottom: 1px solid #252b36;
}

/* ── Headings ────────────────────────────────────────────────────────────── */
QLabel#eyebrow {
    background: transparent;
    color: #58d7c4;
    border: none;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 1.8px;
    padding: 0;
}

QLabel#heading {
    font-size: 28px;
    font-weight: 700;
    color: #f8fafc;
    letter-spacing: 0;
}

QLabel#subheading {
    font-size: 13px;
    color: #97a6ba;
    line-height: 1.5;
}

/* ── Status labels ───────────────────────────────────────────────────────── */
QLabel#status-ok {
    color: #4fc1ff;
    font-weight: 600;
}

QLabel#status-warn {
    color: #d4a843;
    font-weight: 600;
}

QLabel#status-err {
    color: #f48771;
    font-weight: 600;
}

QLabel#status-dim {
    color: #858585;
}

/* ── Buttons ─────────────────────────────────────────────────────────────── */
QPushButton {
    background: #202838;
    color: #d8dee9;
    border: 1px solid #303a4d;
    border-radius: 8px;
    padding: 9px 20px;
    font-size: 13px;
    font-weight: 500;
}

QPushButton:hover {
    background: #283447;
    color: #ffffff;
    border-color: #3f8cff;
}

QPushButton:pressed {
    background: #192131;
    color: #d8dee9;
}

QPushButton:disabled {
    background: #171d29;
    color: #657386;
    border-color: #252b36;
}

QPushButton#primary {
    background: #2f6fed;
    color: #ffffff;
    border: 1px solid #4f8dff;
    font-weight: 700;
}

QPushButton#primary:hover {
    background: #3d7cff;
    border-color: #8cb6ff;
}

QPushButton#primary:pressed {
    background: #2d242d;
}

QPushButton#primary:disabled {
    background: #252526;
    color: #6f6f6f;
    border: none;
}

QPushButton#danger {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                stop:0 #c0392b, stop:1 #96281b);
    color: #ffffff;
    font-weight: 700;
    border: none;
    border-radius: 3px;
    padding: 9px 20px;
}

QPushButton#danger:hover {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                stop:0 #e74c3c, stop:1 #c0392b);
}

QPushButton#danger:pressed {
    background: #7a1f14;
}

QPushButton#danger:disabled {
    background: #2a1a1a;
    color: #5a3a3a;
}

QPushButton#branch-active {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                stop:0 #4d4d4d, stop:1 #3a3a3a);
    color: #ffffff;
    font-weight: 700;
    border: none;
    border-radius: 3px;
    padding: 10px 24px;
}

QPushButton#branch-inactive {
    background: #2d2d30;
    color: #a6a6a6;
    border: 1px solid #3c3c3c;
    border-radius: 3px;
    padding: 10px 24px;
}

QPushButton#branch-inactive:hover {
    background: #3a3d41;
    color: #cccccc;
    border-color: #505050;
}

/* ── Cards ───────────────────────────────────────────────────────────────── */
QFrame#card {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QLabel#card-title {
    font-size: 15px;
    font-weight: 700;
    color: #f8fafc;
}

QLabel#section-heading {
    font-size: 15px;
    font-weight: 700;
    color: #d8dee9;
    letter-spacing: 0.1px;
}

QLabel#card-summary {
    color: #d8dee9;
    font-weight: 600;
}

QLabel#card-action {
    color: #58d7c4;
}

QLabel#card-copy {
    color: #97a6ba;
    line-height: 1.6;
}

QFrame#card-accent-ok {
    background: #132235;
    border: 1px solid #275d85;
    border-radius: 8px;
}

QFrame#card-accent-warn {
    background: #181508;
    border: 1px solid #4c4010;
    border-radius: 4px;
}

QFrame#card-accent-err {
    background: #221010;
    border: 1px solid #4a1a1a;
    border-radius: 4px;
}

QFrame#home-action-card {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QFrame#home-action-card:hover {
    background: #1d2636;
    border-color: #3f8cff;
}

QLabel#home-action-icon {
    font-size: 13px;
    font-weight: 700;
    color: #58d7c4;
}

QLabel#home-action-title {
    font-size: 16px;
    font-weight: 700;
    color: #f3f3f3;
}

QLabel#home-action-copy {
    color: #a6a6a6;
    line-height: 1.45;
}

QLabel#home-next-title {
    font-size: 18px;
    font-weight: 800;
    color: #ffffff;
}

QLabel#home-next-copy {
    color: #b8c7d9;
    line-height: 1.5;
}

QFrame#starter-pack {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QPushButton#starter-pack-header {
    background: transparent;
    border: none;
    color: #f3f3f3;
    text-align: left;
    font-size: 14px;
    font-weight: 700;
    padding: 0;
}

QPushButton#starter-pack-header:hover {
    color: #ffffff;
}

QLabel#starter-pack-meta {
    color: #4fc1ff;
    font-size: 11px;
    font-weight: 700;
}

QWidget#starter-pack-details {
    background: transparent;
}

QFrame#store-hero {
    background: #132235;
    border: 1px solid #275d85;
    border-radius: 8px;
}

QLabel#store-hero-title {
    font-size: 22px;
    font-weight: 800;
    color: #ffffff;
}

QLabel#store-kicker {
    color: #58d7c4;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1px;
}

QFrame#store-app-card {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QFrame#store-app-card:hover {
    background: #1d2636;
    border-color: #3f8cff;
}

QFrame#store-category-card {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QFrame#store-category-card:hover {
    border-color: #58d7c4;
}

QFrame#drop-card {
    background: #151c29;
    border: 1px dashed #3d4a60;
    border-radius: 8px;
}

QFrame#drop-card-active {
    background: #172a3a;
    border: 2px dashed #58d7c4;
    border-radius: 8px;
}

QLabel#drop-glyph {
    background: #223246;
    color: #58d7c4;
    border: 1px solid #35506f;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 800;
}

QLabel#drop-title {
    font-size: 20px;
    font-weight: 800;
    color: #f8fafc;
}

/* ── Software page tab bar ───────────────────────────────────────────────── */
QWidget#sw-tab-bar {
    background: #1e1e1e;
}

QPushButton#sw-tab {
    background: transparent;
    color: #a6a6a6;
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    padding: 10px 22px;
    font-size: 13px;
    font-weight: 500;
    min-width: 110px;
}

QPushButton#sw-tab:hover {
    background: #1b2230;
    color: #d8dee9;
}

QPushButton#sw-tab-active {
    background: transparent;
    color: #ffffff;
    border: none;
    border-bottom: 2px solid #58d7c4;
    border-radius: 0;
    padding: 10px 22px;
    font-size: 13px;
    font-weight: 700;
    min-width: 110px;
}

/* ── Stat tiles ──────────────────────────────────────────────────────────── */
QFrame#stat-tile {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QFrame#stat-tile:hover {
    border-color: #3f8cff;
    background: #1d2636;
}

QLabel#stat-label {
    font-size: 10px;
    font-weight: 700;
    color: #6f7f95;
    letter-spacing: 1px;
}

QLabel#stat-value {
    font-size: 14px;
    font-weight: 700;
    color: #d8dee9;
}

QLabel#stat-value-ok {
    font-size: 14px;
    font-weight: 700;
    color: #58d7c4;
}

QLabel#stat-value-warn {
    font-size: 14px;
    font-weight: 700;
    color: #d4a843;
}

/* ── Divider ─────────────────────────────────────────────────────────────── */
QFrame#divider {
    background: #252b36;
    max-height: 1px;
    border: none;
}

/* ── Text log ────────────────────────────────────────────────────────────── */
QTextEdit {
    background: #0f131b;
    color: #d4d4d4;
    border: 1px solid #2a3446;
    border-radius: 8px;
    font-family: "Cascadia Code", "Noto Mono", "Consolas", monospace;
    font-size: 12px;
    padding: 12px 14px;
    selection-background-color: #264f78;
}

/* ── Progress bar ────────────────────────────────────────────────────────── */
QProgressBar {
    background: #0f131b;
    border: none;
    border-radius: 4px;
    max-height: 6px;
    text-align: center;
    color: transparent;
}

QProgressBar::chunk {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                stop:0 #2f6fed, stop:1 #58d7c4);
    border-radius: 4px;
}

/* ── Scroll bars ─────────────────────────────────────────────────────────── */
QScrollBar:vertical {
    background: transparent;
    width: 8px;
    margin: 0;
    border: none;
}

QScrollBar::handle:vertical {
    background: #3b4658;
    border-radius: 4px;
    min-height: 28px;
}

QScrollBar::handle:vertical:hover {
    background: #526174;
}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
    height: 0px;
    background: transparent;
}

QScrollBar:horizontal {
    background: transparent;
    height: 8px;
    margin: 0;
    border: none;
}

QScrollBar::handle:horizontal {
    background: #3b4658;
    border-radius: 4px;
    min-width: 28px;
}

QScrollBar::handle:horizontal:hover {
    background: #526174;
}

QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
    width: 0px;
    background: transparent;
}

/* ── Line edit ───────────────────────────────────────────────────────────── */
QLineEdit {
    background: #0f131b;
    border: 1px solid #2a3446;
    border-radius: 8px;
    padding: 9px 12px;
    color: #d8dee9;
    selection-background-color: #275d85;
}

QLineEdit:focus {
    border-color: #3f8cff;
    background: #121824;
}

/* ── Checkbox ────────────────────────────────────────────────────────────── */
QCheckBox {
    color: #d8dee9;
    spacing: 9px;
}

QCheckBox::indicator {
    width: 16px;
    height: 16px;
    background: #0f131b;
    border: 1px solid #566275;
    border-radius: 4px;
}

QCheckBox::indicator:checked {
    background: #2f6fed;
    border-color: #8cb6ff;
}

QCheckBox::indicator:hover {
    border-color: #58d7c4;
}

/* ── ComboBox ────────────────────────────────────────────────────────────── */
QComboBox {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
    padding: 8px 12px;
    color: #d8dee9;
    min-width: 80px;
}

QComboBox:hover {
    border-color: #3f8cff;
    background: #1d2636;
}

QComboBox::drop-down {
    border: none;
    width: 22px;
}

QComboBox QAbstractItemView {
    background: #171d29;
    border: 1px solid #2a3446;
    color: #d8dee9;
    selection-background-color: #223246;
    outline: none;
}

/* ── Getting-started step items ──────────────────────────────────────────── */
QFrame#step-item {
    background: #171d29;
    border: 1px solid #2a3446;
    border-radius: 8px;
}

QFrame#step-item:hover {
    background: #1d2636;
    border-color: #3f8cff;
}

QLabel#step-number {
    background: #3a3d41;
    color: #ffffff;
    border: none;
    border-radius: 14px;
    font-size: 12px;
    font-weight: 700;
}

QLabel#step-title {
    font-size: 13px;
    font-weight: 600;
    color: #cccccc;
}

QLabel#step-desc {
    color: #858585;
    font-size: 12px;
    line-height: 1.5;
}

QPushButton#step-action {
    background: #2d2d30;
    color: #cccccc;
    border: 1px solid #3c3c3c;
    border-radius: 3px;
    padding: 7px 16px;
    font-weight: 500;
    font-size: 12px;
}

QPushButton#step-action:hover {
    background: #3a3d41;
    color: #ffffff;
    border-color: #505050;
}

/* ── Update alert card ───────────────────────────────────────────────────── */
QFrame#card-update {
    background: #2a2518;
    border: 1px solid #5f4f24;
    border-radius: 4px;
}

QLabel#card-title-update {
    font-size: 14px;
    font-weight: 700;
    color: #dcdcaa;
}

/* ── Wizard header ───────────────────────────────────────────────────────── */
QWidget#wizard-header {
    background: #181818;
    border-bottom: 1px solid #2b2b2b;
}

QLabel#wizard-step-label {
    font-size: 10px;
    font-weight: 700;
    color: #c586c0;
    letter-spacing: 1.4px;
}

QLabel#step-dot-active {
    background: #c586c0;
    border-radius: 5px;
}

QLabel#step-dot-done {
    background: #4fc1ff;
    border-radius: 5px;
}

QLabel#step-dot-inactive {
    background: #505050;
    border-radius: 5px;
}

/* ── Wizard progress track ────────────────────────────────────────────────── */
QLabel#wizard-progress-step {
    font-size: 11px;
    font-weight: 600;
    color: #858585;
}

QLabel#wizard-progress-step-active {
    font-size: 11px;
    font-weight: 700;
    color: #ffffff;
}

QLabel#wizard-progress-step-done {
    font-size: 11px;
    font-weight: 600;
    color: #4fc1ff;
}

/* ── Wizard footer ───────────────────────────────────────────────────────── */
QWidget#wizard-footer {
    background: #181818;
    border-top: 1px solid #2b2b2b;
}

/* ── Wizard welcome hero ─────────────────────────────────────────────────── */
QWidget#wizard-hero {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                                stop:0 #252526, stop:0.5 #1e1e1e, stop:1 #181818);
}

QLabel#wizard-logo {
    font-size: 54px;
    font-weight: 800;
    color: #ffffff;
    letter-spacing: -1px;
}

QLabel#wizard-tagline {
    font-size: 17px;
    color: #c586c0;
    font-weight: 600;
    letter-spacing: 0.3px;
}

QLabel#wizard-desc {
    font-size: 13px;
    color: #a6a6a6;
    line-height: 1.6;
}

/* ── Wizard finish screen ────────────────────────────────────────────────── */
QLabel#finish-title {
    font-size: 28px;
    font-weight: 800;
    color: #ffffff;
}

QLabel#finish-subtitle {
    font-size: 14px;
    color: #a6a6a6;
    line-height: 1.6;
}

/* ── Hardware card ────────────────────────────────────────────────────────── */
QFrame#hw-card-ok {
    background: #121e2d;
    border: 1px solid #1c3d60;
    border-left: 3px solid #4fc1ff;
    border-radius: 4px;
}

QFrame#hw-card-warn {
    background: #181508;
    border: 1px solid #4c4010;
    border-left: 3px solid #d4a843;
    border-radius: 4px;
}

QFrame#hw-card-err {
    background: #221010;
    border: 1px solid #4a1a1a;
    border-left: 3px solid #f48771;
    border-radius: 4px;
}

QFrame#hw-card-dim {
    background: #252526;
    border: 1px solid #3c3c3c;
    border-left: 3px solid #505050;
    border-radius: 4px;
}

/* ── Live session banner ─────────────────────────────────────────────────── */
QWidget#live-banner {
    background: #141000;
    border-bottom: 1px solid #403800;
}

QLabel#live-banner-badge {
    background: #1e1a06;
    color: #d4a843;
    border: 1px solid #5a4c0c;
    border-radius: 10px;
    padding: 3px 8px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.5px;
}

QLabel#live-banner-text {
    color: #a09060;
    font-size: 11px;
}

/* ── 2026 System Hub refresh ─────────────────────────────────────────────── */
QMainWindow {
    background: #0b0f17;
}

QWidget#content-area {
    background: #0b0f17;
}

QWidget#sidebar {
    background: #0f141f;
    border-right: 1px solid #243044;
}

QWidget#sidebar-header {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                                stop:0 #1d2638, stop:0.45 #111827, stop:1 #181429);
    border-bottom: 1px solid #2e405b;
}

QLabel#sidebar-logo {
    color: #ffffff;
    font-size: 22px;
    font-weight: 900;
}

QLabel#sidebar-ver {
    color: #8ddcff;
    font-size: 11px;
    font-weight: 700;
}

QPushButton#nav-item {
    color: #c8d3e2;
    border-left: 3px solid transparent;
    padding: 10px 16px 10px 13px;
}

QPushButton#nav-item:hover {
    background: #172033;
    color: #ffffff;
    border-left: 3px solid #47c7ff;
}

QPushButton#nav-item-active {
    background: #1b263a;
    color: #ffffff;
    border-left: 3px solid #ff5fd2;
    padding: 10px 16px 10px 13px;
}

QWidget#page-header {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                stop:0 #121a28, stop:0.55 #101722, stop:1 #17132a);
    border-bottom: 1px solid #28364e;
}

QLabel#eyebrow {
    color: #66ddff;
}

QLabel#heading {
    color: #f7fbff;
    font-weight: 800;
}

QLabel#subheading {
    color: #aebbd0;
}

QPushButton {
    background: #172033;
    color: #d7e1ef;
    border: 1px solid #2d3b53;
    border-radius: 7px;
    padding: 9px 18px;
}

QPushButton:hover {
    background: #202c42;
    border-color: #4f6689;
    color: #ffffff;
}

QPushButton#primary {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                stop:0 #1b8cff, stop:1 #b74dff);
    color: #ffffff;
    border: 1px solid #60cfff;
    border-radius: 7px;
}

QPushButton#primary:hover {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                stop:0 #33a2ff, stop:1 #ce63ff);
    border-color: #aeeeff;
}

QFrame#card,
QFrame#home-action-card,
QFrame#stat-tile {
    background: #111827;
    border: 1px solid #29364c;
    border-radius: 8px;
}

QFrame#card:hover,
QFrame#home-action-card:hover,
QFrame#stat-tile:hover {
    background: #151f31;
    border-color: #3e5274;
}

QFrame#card-accent-ok {
    background: #0e2230;
    border: 1px solid #1e6d8f;
    border-radius: 8px;
}

QFrame#card-accent-warn {
    background: #241d0d;
    border: 1px solid #755b18;
    border-radius: 8px;
}

QFrame#card-accent-err {
    background: #2a1118;
    border: 1px solid #7b2c3f;
    border-radius: 8px;
}

QLabel#card-title,
QLabel#home-action-title,
QLabel#home-next-title {
    color: #f6f9ff;
}

QLabel#card-copy,
QLabel#home-action-copy,
QLabel#home-next-copy {
    color: #aebbd0;
}

QFrame#home-hero {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                                stop:0 #122b3f, stop:0.48 #111827, stop:1 #28163a);
    border: 1px solid #38516f;
    border-radius: 8px;
}

QLabel#home-hero-kicker {
    color: #77e4ff;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1.3px;
}

QLabel#home-hero-title {
    color: #ffffff;
    font-size: 28px;
    font-weight: 900;
}

QLabel#home-hero-copy {
    color: #c7d5e8;
    font-size: 13px;
    line-height: 1.55;
}

QLabel#home-hero-badge {
    background: #0b1320;
    color: #93ecff;
    border: 1px solid #285e78;
    border-radius: 12px;
    padding: 5px 10px;
    font-size: 11px;
    font-weight: 800;
}

QFrame#ready-panel {
    background: #111827;
    border: 1px solid #31425e;
    border-radius: 8px;
}

QLabel#ready-score {
    color: #69f0ae;
    font-size: 30px;
    font-weight: 900;
}

QLabel#ready-score-warn {
    color: #ffd166;
    font-size: 30px;
    font-weight: 900;
}

QLabel#ready-score-err {
    color: #ff7b8a;
    font-size: 30px;
    font-weight: 900;
}

QLabel#ready-row-ok,
QLabel#ready-row-warn,
QLabel#ready-row-err,
QLabel#ready-row-dim {
    border-radius: 8px;
    padding: 8px 10px;
    font-weight: 700;
}

QLabel#ready-row-ok {
    background: #10281f;
    color: #8ff0bd;
    border: 1px solid #245d43;
}

QLabel#ready-row-warn {
    background: #2a220f;
    color: #ffd166;
    border: 1px solid #6d571b;
}

QLabel#ready-row-err {
    background: #2a1118;
    color: #ff8fa1;
    border: 1px solid #743044;
}

QLabel#ready-row-dim {
    background: #151e2e;
    color: #9aa9bd;
    border: 1px solid #2a3850;
}

/* ── Command Center polish ───────────────────────────────────────────────── */
* {
    font-family: "Noto Sans", "Segoe UI", sans-serif;
    font-size: 13px;
    color: #d9e2ef;
}

QMainWindow,
QWidget#content-area {
    background: #0f1218;
}

QWidget#sidebar {
    background: #111722;
    border-right: 1px solid #263244;
}

QWidget#sidebar-header {
    background: #131c2a;
    border-bottom: 1px solid #2a3a52;
}

QLabel#sidebar-logo {
    color: #f7fbff;
    font-size: 22px;
    font-weight: 900;
}

QLabel#sidebar-ver {
    color: #91d9ff;
    font-size: 11px;
    font-weight: 700;
}

QLabel#nav-section {
    color: #78879b;
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 1.2px;
}

QPushButton#nav-item {
    background: transparent;
    color: #b9c5d4;
    border: none;
    border-left: 3px solid transparent;
    border-radius: 0;
    padding: 9px 16px 9px 13px;
    text-align: left;
    font-size: 13px;
    font-weight: 600;
}

QPushButton#nav-item:hover {
    background: #192331;
    color: #ffffff;
    border-left: 3px solid #5fc7ff;
}

QPushButton#nav-item-active {
    background: #1d2a3c;
    color: #ffffff;
    border: none;
    border-left: 3px solid #5fc7ff;
    border-radius: 0;
    padding: 9px 16px 9px 13px;
    text-align: left;
    font-size: 13px;
    font-weight: 800;
}

QWidget#page-header {
    background: #111722;
    border-bottom: 1px solid #263244;
}

QLabel#eyebrow {
    color: #91d9ff;
    font-size: 10px;
    font-weight: 800;
    letter-spacing: 1.6px;
}

QLabel#heading {
    color: #f7fbff;
    font-size: 26px;
    font-weight: 800;
}

QLabel#subheading {
    color: #9fadc0;
}

QPushButton {
    background: #1a2330;
    color: #d9e2ef;
    border: 1px solid #334256;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: 600;
}

QPushButton:hover {
    background: #223044;
    color: #ffffff;
    border-color: #4e6683;
}

QPushButton:pressed {
    background: #151d29;
}

QPushButton:disabled {
    background: #151a22;
    color: #657386;
    border-color: #263142;
}

QPushButton#primary {
    background: #2b6fb1;
    color: #ffffff;
    border: 1px solid #58a6d8;
    border-radius: 6px;
    font-weight: 800;
}

QPushButton#primary:hover {
    background: #347fc6;
    border-color: #84cfff;
}

QPushButton#danger {
    background: #7f2634;
    color: #ffffff;
    border: 1px solid #b5485b;
    border-radius: 6px;
}

QFrame#card,
QFrame#home-action-card,
QFrame#stat-tile,
QFrame#starter-pack,
QFrame#ready-panel {
    background: #151b24;
    border: 1px solid #2b394b;
    border-radius: 8px;
}

QFrame#card:hover,
QFrame#home-action-card:hover,
QFrame#stat-tile:hover {
    background: #182232;
    border-color: #3c506a;
}

QFrame#card-accent-ok {
    background: #122432;
    border: 1px solid #2d6680;
    border-radius: 8px;
}

QFrame#card-accent-warn {
    background: #241f12;
    border: 1px solid #77622a;
    border-radius: 8px;
}

QFrame#card-accent-err {
    background: #2a151a;
    border: 1px solid #7f3545;
    border-radius: 8px;
}

QFrame#home-hero {
    background: #132033;
    border: 1px solid #355475;
    border-radius: 8px;
}

QLabel#home-hero-kicker,
QLabel#starter-pack-meta {
    color: #91d9ff;
}

QLabel#home-hero-title {
    color: #ffffff;
    font-size: 27px;
    font-weight: 900;
}

QLabel#home-hero-copy,
QLabel#card-copy,
QLabel#home-action-copy,
QLabel#home-next-copy {
    color: #aebbd0;
}

QLabel#home-hero-badge {
    background: #0f1724;
    color: #b7eaff;
    border: 1px solid #365a76;
    border-radius: 10px;
    padding: 4px 9px;
    font-size: 11px;
    font-weight: 800;
}

QLabel#card-title,
QLabel#home-action-title,
QLabel#home-next-title,
QLabel#section-heading {
    color: #f7fbff;
}

QLabel#home-action-icon {
    color: #91d9ff;
}

QLabel#status-ok,
QLabel#stat-value-ok,
QLabel#ready-score {
    color: #7bdba9;
}

QLabel#status-warn,
QLabel#stat-value-warn,
QLabel#ready-score-warn {
    color: #f1c96b;
}

QLabel#status-err,
QLabel#ready-score-err {
    color: #ff8fa1;
}

QLabel#status-dim,
QLabel#stat-label {
    color: #8391a4;
}

QFrame#hw-card-ok,
QLabel#ready-row-ok {
    background: #11251e;
    color: #9be7bd;
    border: 1px solid #2f6b4d;
    border-left: 3px solid #7bdba9;
    border-radius: 8px;
}

QFrame#hw-card-warn,
QLabel#ready-row-warn {
    background: #24200f;
    color: #f1c96b;
    border: 1px solid #736026;
    border-left: 3px solid #f1c96b;
    border-radius: 8px;
}

QFrame#hw-card-err,
QLabel#ready-row-err {
    background: #2a151a;
    color: #ff9aad;
    border: 1px solid #7f3545;
    border-left: 3px solid #ff8fa1;
    border-radius: 8px;
}

QFrame#hw-card-dim,
QLabel#ready-row-dim {
    background: #151b24;
    color: #aebbd0;
    border: 1px solid #2b394b;
    border-left: 3px solid #56667c;
    border-radius: 8px;
}

QTextEdit,
QLineEdit,
QComboBox {
    background: #111722;
    color: #d9e2ef;
    border: 1px solid #2d3b4f;
    border-radius: 6px;
}

QLineEdit:focus,
QComboBox:hover {
    border-color: #5fc7ff;
}

QWidget#sw-tab-bar {
    background: #111722;
}

QPushButton#sw-tab,
QPushButton#sw-tab-active {
    border-radius: 0;
    min-width: 92px;
}

QPushButton#sw-tab-active {
    color: #ffffff;
    border-bottom: 2px solid #5fc7ff;
}
"""
