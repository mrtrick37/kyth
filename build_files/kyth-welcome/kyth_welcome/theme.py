
# __KYTH_GENERATED_IMPORTS__


# KythOS theme: graphite surfaces, teal focus, restrained status colors.
# Palette:
#   window      #202020      sidebar          #1b1b1c
#   card        #2b2b2b      card hover       #313131
#   border      #3a3a3a      strong border    #4a4a4a
#   input       #2d2d2d      log/console      #1a1a1a
#   text        #ffffff      secondary text   #a6a6a6
#   accent      #2f9b8f      accent (light)   #7dd3c7
#   ok #6ccb5f   warn #d9b54a   error #ff99a4   danger button #c42b1c
QSS = """
* {
    font-family: "Noto Sans", "Segoe UI", sans-serif;
    font-size: 13px;
    color: #e8e8e8;
}

QMainWindow,
QWidget#content-area {
    background: #202020;
}

QWidget {
    background: transparent;
}

QLabel {
    background: transparent;
}

QScrollArea {
    background: transparent;
    border: none;
}

QToolTip {
    background: #2b2b2b;
    color: #e8e8e8;
    border: 1px solid #4a4a4a;
    padding: 4px 8px;
}

/* ── Top command bar ─────────────────────────────────────────────────────── */
QWidget#topbar {
    background: #1b1b1c;
    border-bottom: 1px solid #2e2e2e;
}

QPushButton#topbar-nav {
    background: transparent;
    color: #e8e8e8;
    border: none;
    border-radius: 5px;
    padding: 4px 0;
    font-size: 15px;
    font-weight: 400;
}

QPushButton#topbar-nav:hover {
    background: #2d2d2d;
}

QPushButton#topbar-nav:pressed {
    background: #272727;
}

QPushButton#topbar-nav:disabled {
    color: #5c5c5c;
    background: transparent;
}

QPushButton#breadcrumb-link {
    background: transparent;
    color: #e8e8e8;
    border: none;
    border-radius: 5px;
    padding: 4px 8px;
    font-size: 13px;
    font-weight: 600;
    text-align: left;
}

QPushButton#breadcrumb-link:hover {
    background: #2d2d2d;
    color: #ffffff;
}

QLabel#breadcrumb {
    color: #a6a6a6;
    font-size: 13px;
}

QLineEdit#search-box {
    background: #2d2d2d;
    color: #e8e8e8;
    border: 1px solid #3a3a3a;
    border-bottom: 1px solid #5c5c5c;
    border-radius: 5px;
    padding: 6px 12px;
}

QLineEdit#search-box:focus {
    background: #1f1f1f;
    border-bottom: 2px solid #7dd3c7;
}

QFrame#search-results-panel {
    background: #1b1b1c;
    border-bottom: 1px solid #2e2e2e;
}

QLabel#search-results-title {
    color: #ffffff;
    font-size: 12px;
    font-weight: 700;
}

QLabel#search-results-hint {
    color: #8a8a8a;
    font-size: 11px;
}

QPushButton#search-result {
    background: #242424;
    color: #dcdcdc;
    border: 1px solid #343434;
    border-radius: 6px;
    padding: 8px 12px;
    text-align: left;
    font-size: 12px;
    line-height: 1.35;
}

QPushButton#search-result:hover {
    background: #2d2d2d;
    color: #ffffff;
    border-color: #4a4a4a;
}

QPushButton#search-result:pressed {
    background: #202020;
}

/* ── Sidebar ─────────────────────────────────────────────────────────────── */
QWidget#sidebar {
    background: #191b1d;
    border-right: 1px solid #2e2e2e;
    border-left: 4px solid #2f9b8f;
}

QWidget#sidebar-header {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #1e2426, stop:1 #1b1b1c);
    border-bottom: 1px solid #2e2e2e;
}

QLabel#sidebar-logo {
    font-size: 20px;
    font-weight: 700;
    color: #ffffff;
    padding: 0;
}

QLabel#sidebar-ver {
    font-size: 11px;
    color: #a6a6a6;
    font-weight: 500;
    padding: 0;
}

QLabel#nav-section {
    font-size: 11px;
    font-weight: 600;
    color: #8a8a8a;
    padding: 0 0 2px 0;
}

QPushButton#nav-item,
QPushButton#nav-item-active {
    background: transparent;
    border: none;
    border-radius: 6px;
    margin: 1px 8px;
    padding: 8px 10px;
    text-align: left;
    font-size: 13px;
}

QPushButton#nav-item {
    color: #d6d6d6;
    font-weight: 400;
}

QPushButton#nav-item:hover {
    background: #2d2d2d;
    color: #ffffff;
}

QPushButton#nav-item:pressed {
    background: #272727;
}

QPushButton#nav-item-active {
    background: #2d2d2d;
    color: #ffffff;
    border-left: 3px solid #7dd3c7;
    padding: 8px 10px 8px 7px;
    font-weight: 600;
}

/* ── Page header band ────────────────────────────────────────────────────── */
QWidget#page-header {
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #272727, stop:1 #202020);
    border-bottom: 1px solid #2e2e2e;
}

QLabel#eyebrow {
    color: #8be3d7;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 2px;
    padding: 0;
}

QLabel#heading {
    font-size: 30px;
    font-weight: 700;
    color: #ffffff;
}

QLabel#subheading {
    font-size: 13px;
    color: #a6a6a6;
    line-height: 1.5;
}

QLabel#section-heading {
    font-size: 16px;
    font-weight: 600;
    color: #ffffff;
}

/* ── Status labels ───────────────────────────────────────────────────────── */
QLabel#status-ok {
    color: #6ccb5f;
    font-weight: 600;
}

QLabel#status-warn {
    color: #d9b54a;
    font-weight: 600;
}

QLabel#status-err {
    color: #ff99a4;
    font-weight: 600;
}

QLabel#status-dim {
    color: #8a8a8a;
}

QLabel#task-status-idle,
QLabel#task-status-running,
QLabel#task-status-ok,
QLabel#task-status-warn,
QLabel#task-status-err {
    border-radius: 5px;
    padding: 8px 10px;
    font-weight: 600;
}

QLabel#task-status-idle {
    background: #242424;
    color: #a6a6a6;
    border: 1px solid #343434;
}

QLabel#task-status-running {
    background: #203331;
    color: #a6f0e5;
    border: 1px solid #345d58;
}

QLabel#task-status-ok {
    background: #283028;
    color: #9fd99a;
    border: 1px solid #3e573c;
}

QLabel#task-status-warn {
    background: #322d20;
    color: #d9b54a;
    border: 1px solid #5c5126;
}

QLabel#task-status-err {
    background: #332527;
    color: #ff99a4;
    border: 1px solid #5e3338;
}

QFrame#action-row {
    background: transparent;
    border: none;
}

QFrame#command-result-panel {
    background: transparent;
    border: none;
}

QFrame#empty-state {
    background: #242424;
    border: 1px dashed #4a4a4a;
    border-radius: 6px;
}

QLabel#empty-state-title {
    color: #ffffff;
    font-size: 14px;
    font-weight: 700;
}

QLabel#empty-state-copy {
    color: #a6a6a6;
    line-height: 1.5;
}

QFrame#flow-step {
    background: #242424;
    border: 1px solid #343434;
    border-radius: 6px;
}

QLabel#flow-step-num {
    background: #223634;
    color: #a6f0e5;
    border: 1px solid #345d58;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 700;
}

QLabel#flow-step-title {
    color: #ffffff;
    font-size: 13px;
    font-weight: 700;
}

QLabel#flow-step-copy {
    color: #a6a6a6;
    line-height: 1.45;
}

/* ── Buttons ─────────────────────────────────────────────────────────────── */
QPushButton {
    background: #2d2d2d;
    color: #e8e8e8;
    border: 1px solid #3a3a3a;
    border-radius: 5px;
    padding: 7px 16px;
    font-size: 13px;
    font-weight: 400;
}

QPushButton:hover {
    background: #323232;
    color: #ffffff;
    border-color: #454545;
}

QPushButton:pressed {
    background: #272727;
    color: #cfcfcf;
}

QPushButton:disabled {
    background: #262626;
    color: #6b6b6b;
    border-color: #303030;
}

QPushButton#primary,
QPushButton#btn-secondary {
    background: #2f9b8f;
    color: #ffffff;
    border: 1px solid #3ab6a9;
    font-weight: 600;
    padding: 8px 20px;
    letter-spacing: 0.3px;
}

QPushButton#primary:hover,
QPushButton#btn-secondary:hover {
    background: #3ab6a9;
    border-color: #7dd3c7;
}

QPushButton#primary:pressed,
QPushButton#btn-secondary:pressed {
    background: #237a71;
}

QPushButton#primary:disabled,
QPushButton#btn-secondary:disabled {
    background: #2d2d2d;
    color: #6b6b6b;
    border-color: #303030;
}

QPushButton#danger {
    background: #c42b1c;
    color: #ffffff;
    border: 1px solid #d13438;
    font-weight: 600;
}

QPushButton#danger:hover {
    background: #d13438;
    border-color: #ff6b6b;
}

QPushButton#danger:pressed {
    background: #a72015;
}

QPushButton#danger:disabled {
    background: #2d1d1c;
    color: #6b5252;
    border-color: #3a2a29;
}

QPushButton#branch-active {
    background: #2f9b8f;
    color: #ffffff;
    font-weight: 600;
    border: 1px solid #3ab6a9;
    border-radius: 5px;
    padding: 9px 22px;
}

QPushButton#branch-inactive {
    background: #2d2d2d;
    color: #a6a6a6;
    border: 1px solid #3a3a3a;
    border-radius: 5px;
    padding: 9px 22px;
}

QPushButton#branch-inactive:hover {
    background: #323232;
    color: #e8e8e8;
    border-color: #454545;
}

/* ── Control Panel home: category grid ───────────────────────────────────── */
QFrame#cp-category {
    background: #2b2b2b;
    border: 1px solid #3a3a3a;
    border-radius: 10px;
}

QFrame#cp-category:hover {
    background: #313131;
    border-color: #4a4a4a;
}

QPushButton#cp-category-title {
    background: transparent;
    color: #ffffff;
    border: none;
    padding: 0;
    font-size: 15px;
    font-weight: 600;
    text-align: left;
}

QPushButton#cp-category-title:hover {
    color: #7dd3c7;
}

QPushButton#task-link {
    background: transparent;
    color: #7dd3c7;
    border: none;
    border-radius: 4px;
    padding: 3px 6px;
    font-size: 12px;
    font-weight: 400;
    text-align: left;
}

QPushButton#task-link:hover {
    background: #383838;
    color: #a6f0e5;
}

QPushButton#task-link:pressed {
    color: #4fc6b8;
}

/* ── Gaming section switcher ─────────────────────────────────────────────── */
QFrame#gaming-section-switcher {
    background: transparent;
    border: none;
}

QWidget#gaming-section-row {
    background: transparent;
}

QPushButton#gaming-section,
QPushButton#gaming-section-active {
    border-radius: 5px;
    padding: 7px 14px;
    font-weight: 600;
}

QPushButton#gaming-section {
    background: #242424;
    color: #a6a6a6;
    border: 1px solid #343434;
}

QPushButton#gaming-section:hover {
    background: #2d2d2d;
    color: #ffffff;
    border-color: #4a4a4a;
}

QPushButton#gaming-section-active {
    background: #223634;
    color: #ffffff;
    border: 1px solid #7dd3c7;
}

/* ── Cards ───────────────────────────────────────────────────────────────── */
QFrame#card,
QFrame#home-recommend-card,
QFrame#home-action-card,
QFrame#stat-tile,
QFrame#starter-pack,
QFrame#ready-panel,
QFrame#store-app-card,
QFrame#store-category-card {
    background: #2b2b2b;
    border: 1px solid #3a3a3a;
    border-radius: 10px;
}

QFrame#card:hover,
QFrame#home-recommend-card:hover,
QFrame#home-action-card:hover,
QFrame#stat-tile:hover,
QFrame#store-app-card:hover,
QFrame#store-category-card:hover {
    background: #313131;
    border-color: #4a4a4a;
}

QLabel#card-title {
    font-size: 14px;
    font-weight: 600;
    color: #ffffff;
}

QLabel#card-subtitle {
    font-size: 13px;
    font-weight: 600;
    color: #ffffff;
}

QLabel#card-summary {
    color: #e8e8e8;
    font-weight: 600;
}

QLabel#card-action {
    color: #7dd3c7;
}

QLabel#card-copy {
    color: #a6a6a6;
    line-height: 1.6;
}

QFrame#home-recommend-card {
    background: #203331;
    border: 1px solid #345d58;
    border-left: 4px solid #7dd3c7;
    border-radius: 10px;
}

QLabel#home-kicker {
    color: #7dd3c7;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1px;
}

QFrame#home-section {
    background: transparent;
    border: none;
}

QLabel#home-section-title {
    color: #ffffff;
    font-size: 15px;
    font-weight: 700;
}

QLabel#home-section-copy {
    color: #8a8a8a;
    font-size: 12px;
    line-height: 1.4;
}

QFrame#card-accent-ok {
    background: #283028;
    border: 1px solid #3e573c;
    border-radius: 10px;
}

QFrame#card-accent-warn {
    background: #322d20;
    border: 1px solid #5c5126;
    border-radius: 10px;
}

QFrame#card-accent-err {
    background: #332527;
    border: 1px solid #5e3338;
    border-radius: 10px;
}

QLabel#home-action-icon {
    font-size: 13px;
    font-weight: 600;
    color: #7dd3c7;
}

QLabel#home-action-title {
    font-size: 15px;
    font-weight: 600;
    color: #ffffff;
}

QLabel#home-action-copy {
    color: #a6a6a6;
    line-height: 1.45;
}

QLabel#home-next-title {
    font-size: 16px;
    font-weight: 600;
    color: #ffffff;
}

QLabel#home-next-copy {
    color: #c5c5c5;
    line-height: 1.5;
}

QLabel#home-next-meta {
    color: #a6f0e5;
    line-height: 1.45;
}

QPushButton#starter-pack-header {
    background: transparent;
    border: none;
    color: #ffffff;
    text-align: left;
    font-size: 14px;
    font-weight: 600;
    padding: 0;
}

QPushButton#starter-pack-header:hover {
    color: #7dd3c7;
}

QLabel#starter-pack-meta {
    color: #7dd3c7;
    font-size: 11px;
    font-weight: 600;
}

QWidget#starter-pack-details {
    background: transparent;
}

QFrame#store-hero {
    background: #2b2b2b;
    border: 1px solid #3a3a3a;
    border-radius: 6px;
}

QLabel#store-hero-title {
    font-size: 20px;
    font-weight: 600;
    color: #ffffff;
}

QLabel#store-kicker {
    color: #7dd3c7;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 1px;
}

QFrame#drop-card {
    background: #262626;
    border: 1px dashed #4a4a4a;
    border-radius: 10px;
}

QFrame#drop-card-active {
    background: #213634;
    border: 2px dashed #7dd3c7;
    border-radius: 10px;
}

QLabel#drop-glyph {
    background: #2d2d2d;
    color: #7dd3c7;
    border: 1px solid #3a3a3a;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 600;
}

QLabel#drop-title {
    font-size: 18px;
    font-weight: 600;
    color: #ffffff;
}

/* ── Software page tab bar ───────────────────────────────────────────────── */
QWidget#sw-tab-bar {
    background: #1b1b1c;
}

QPushButton#sw-tab,
QPushButton#sw-tab-active {
    background: transparent;
    border: none;
    border-radius: 0;
    padding: 10px 22px;
    font-size: 13px;
    min-width: 92px;
}

QPushButton#sw-tab {
    color: #a6a6a6;
    border-bottom: 2px solid transparent;
    font-weight: 400;
}

QPushButton#sw-tab:hover {
    background: #242424;
    color: #e8e8e8;
}

QPushButton#sw-tab-active {
    color: #ffffff;
    border-bottom: 2px solid #7dd3c7;
    font-weight: 600;
}

/* ── Stat tiles ──────────────────────────────────────────────────────────── */
QLabel#stat-label {
    font-size: 11px;
    font-weight: 600;
    color: #8a8a8a;
}

QLabel#stat-value {
    font-size: 16px;
    font-weight: 600;
    color: #e8e8e8;
}

QLabel#stat-value-ok {
    font-size: 16px;
    font-weight: 600;
    color: #6ccb5f;
}

QLabel#stat-value-warn {
    font-size: 16px;
    font-weight: 600;
    color: #d9b54a;
}

/* ── Gaming readiness panel ──────────────────────────────────────────────── */
QLabel#ready-score {
    color: #6ccb5f;
    font-size: 28px;
    font-weight: 700;
}

QLabel#ready-score-warn {
    color: #d9b54a;
    font-size: 28px;
    font-weight: 700;
}

QLabel#ready-score-err {
    color: #ff99a4;
    font-size: 28px;
    font-weight: 700;
}

QLabel#ready-row-ok,
QLabel#ready-row-warn,
QLabel#ready-row-err,
QLabel#ready-row-dim {
    border-radius: 5px;
    padding: 8px 10px;
    font-weight: 600;
}

QLabel#ready-row-ok {
    background: #283028;
    color: #9fd99a;
    border: 1px solid #3e573c;
}

QLabel#ready-row-warn {
    background: #322d20;
    color: #d9b54a;
    border: 1px solid #5c5126;
}

QLabel#ready-row-err {
    background: #332527;
    color: #ff99a4;
    border: 1px solid #5e3338;
}

QLabel#ready-row-dim {
    background: #2b2b2b;
    color: #a6a6a6;
    border: 1px solid #3a3a3a;
}

/* ── Hardware cards ──────────────────────────────────────────────────────── */
QFrame#hw-card-ok {
    background: #283028;
    border: 1px solid #3e573c;
    border-left: 4px solid #6ccb5f;
    border-radius: 8px;
}

QFrame#hw-card-warn {
    background: #322d20;
    border: 1px solid #5c5126;
    border-left: 4px solid #d9b54a;
    border-radius: 8px;
}

QFrame#hw-card-err {
    background: #332527;
    border: 1px solid #5e3338;
    border-left: 4px solid #ff99a4;
    border-radius: 8px;
}

QFrame#hw-card-dim {
    background: #2b2b2b;
    border: 1px solid #3a3a3a;
    border-left: 4px solid #5c5c5c;
    border-radius: 8px;
}

/* ── Divider ─────────────────────────────────────────────────────────────── */
QFrame#divider {
    background: #2e2e2e;
    max-height: 1px;
    border: none;
}

/* ── Text log ────────────────────────────────────────────────────────────── */
QTextEdit {
    background: #1a1a1a;
    color: #d4d4d4;
    border: 1px solid #3a3a3a;
    border-radius: 5px;
    font-family: "Cascadia Code", "Noto Mono", "Consolas", monospace;
    font-size: 12px;
    padding: 12px 14px;
    selection-background-color: #245a55;
}

/* ── Progress bar ────────────────────────────────────────────────────────── */
QProgressBar {
    background: #2d2d2d;
    border: none;
    border-radius: 3px;
    max-height: 5px;
    text-align: center;
    color: transparent;
}

QProgressBar::chunk {
    background: #2f9b8f;
    border-radius: 3px;
}

/* ── Scroll bars ─────────────────────────────────────────────────────────── */
QScrollBar:vertical {
    background: transparent;
    width: 8px;
    margin: 0;
    border: none;
}

QScrollBar::handle:vertical {
    background: #4a4a4a;
    border-radius: 4px;
    min-height: 28px;
}

QScrollBar::handle:vertical:hover {
    background: #5c5c5c;
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
    background: #4a4a4a;
    border-radius: 4px;
    min-width: 28px;
}

QScrollBar::handle:horizontal:hover {
    background: #5c5c5c;
}

QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
    width: 0px;
    background: transparent;
}

/* ── Inputs ──────────────────────────────────────────────────────────────── */
QLineEdit {
    background: #2d2d2d;
    border: 1px solid #3a3a3a;
    border-bottom: 1px solid #5c5c5c;
    border-radius: 5px;
    padding: 7px 11px;
    color: #e8e8e8;
    selection-background-color: #245a55;
}

QLineEdit:focus {
    background: #1f1f1f;
    border-bottom: 2px solid #7dd3c7;
}

QCheckBox {
    color: #e8e8e8;
    spacing: 9px;
}

QCheckBox::indicator {
    width: 16px;
    height: 16px;
    background: #2d2d2d;
    border: 1px solid #5c5c5c;
    border-radius: 4px;
}

QCheckBox::indicator:checked {
    background: #2f9b8f;
    border-color: #2f9b8f;
}

QCheckBox::indicator:hover {
    border-color: #7dd3c7;
}

QComboBox {
    background: #2d2d2d;
    border: 1px solid #3a3a3a;
    border-radius: 5px;
    padding: 7px 11px;
    color: #e8e8e8;
    min-width: 80px;
}

QComboBox:hover {
    border-color: #4a4a4a;
    background: #323232;
}

QComboBox::drop-down {
    border: none;
    width: 22px;
}

QComboBox QAbstractItemView {
    background: #2b2b2b;
    border: 1px solid #3a3a3a;
    color: #e8e8e8;
    selection-background-color: #2d2d2d;
    outline: none;
}

/* ── Live session banner ─────────────────────────────────────────────────── */
QWidget#live-banner {
    background: #322d20;
    border-bottom: 1px solid #5c5126;
}

QLabel#live-banner-badge {
    background: #2b2b2b;
    color: #d9b54a;
    border: 1px solid #5c5126;
    border-radius: 10px;
    padding: 3px 8px;
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.5px;
}

QLabel#live-banner-text {
    color: #c0ab6f;
    font-size: 11px;
}

/* ── Wizard ──────────────────────────────────────────────────────────────── */
QWidget#wizard-header {
    background: #1b1b1c;
    border-bottom: 1px solid #2e2e2e;
}

QWidget#wizard-footer {
    background: #1b1b1c;
    border-top: 1px solid #2e2e2e;
}

QLabel#wizard-footer-hint {
    color: #a6a6a6;
    font-size: 12px;
}

QLabel#step-dot-active {
    background: #7dd3c7;
    border-radius: 5px;
}

QLabel#step-dot-done {
    background: #2f9b8f;
    border-radius: 5px;
}

QLabel#step-dot-inactive {
    background: #4a4a4a;
    border-radius: 5px;
}

QLabel#wizard-progress-step {
    font-size: 11px;
    font-weight: 400;
    color: #8a8a8a;
}

QLabel#wizard-progress-step-active {
    font-size: 11px;
    font-weight: 600;
    color: #ffffff;
}

QLabel#wizard-progress-step-done {
    font-size: 11px;
    font-weight: 400;
    color: #7dd3c7;
}

QWidget#wizard-hero {
    background: #1b1b1c;
}

QLabel#wizard-logo {
    font-size: 48px;
    font-weight: 700;
    color: #ffffff;
    letter-spacing: -1px;
}

QLabel#wizard-tagline {
    font-size: 16px;
    color: #7dd3c7;
    font-weight: 600;
}

QLabel#wizard-desc {
    font-size: 13px;
    color: #a6a6a6;
    line-height: 1.6;
}

QLabel#finish-title {
    font-size: 26px;
    font-weight: 700;
    color: #ffffff;
}

QLabel#finish-subtitle {
    font-size: 14px;
    color: #a6a6a6;
    line-height: 1.6;
}
"""
