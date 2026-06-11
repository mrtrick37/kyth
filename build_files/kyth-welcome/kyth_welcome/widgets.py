import re

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    HardwareProbe, _restyle,
)
from .qt import (  # noqa: E501
    QFrame, QHBoxLayout, QLabel, QPushButton, QScrollArea, QSizePolicy, QTextEdit, QVBoxLayout, QWidget, Qt,
)

def _divider() -> QFrame:
    f = QFrame()
    f.setObjectName("divider")
    f.setFrameShape(QFrame.Shape.HLine)
    f.setFixedHeight(1)
    return f


def _make_card(name: str = "card") -> tuple[QFrame, QVBoxLayout]:
    card = QFrame()
    card.setObjectName(name)
    layout = QVBoxLayout(card)
    layout.setContentsMargins(22, 20, 22, 20)
    layout.setSpacing(14)
    return card, layout


class AppImageDropCard(QFrame):
    _IMAGE_RE = re.compile(r"\.(png|svg|svgz|jpg|jpeg|webp|ico|xpm)$", re.I)

    def __init__(self, on_appimage_drop, on_icon_drop=None):
        super().__init__()
        self._on_appimage_drop = on_appimage_drop
        self._on_icon_drop = on_icon_drop
        self.setObjectName("drop-card")
        self.setAcceptDrops(True)

    @classmethod
    def _is_icon_path(cls, path: str) -> bool:
        return bool(path and cls._IMAGE_RE.search(path))

    def _dropped_path(self, event) -> tuple[str, str]:
        mime = event.mimeData()
        if not mime.hasUrls():
            return "", ""
        for url in mime.urls():
            path = url.toLocalFile()
            if path and re.search(r"\.[Aa]pp[Ii]mage$", path):
                return "appimage", path
            if self._on_icon_drop and self._is_icon_path(path):
                return "icon", path
        return "", ""

    def dragEnterEvent(self, event):  # noqa: N802
        kind, _ = self._dropped_path(event)
        if kind:
            self.setObjectName("drop-card-active")
            _restyle(self)
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragMoveEvent(self, event):  # noqa: N802
        kind, _ = self._dropped_path(event)
        if kind:
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragLeaveEvent(self, event):  # noqa: N802
        self.setObjectName("drop-card")
        _restyle(self)
        event.accept()

    def dropEvent(self, event):  # noqa: N802
        self.setObjectName("drop-card")
        _restyle(self)
        kind, path = self._dropped_path(event)
        if not kind or not path:
            event.ignore()
            return
        event.acceptProposedAction()
        if kind == "icon":
            self._on_icon_drop(path)
        else:
            self._on_appimage_drop(path)

def _set_log_panel(toggle: QPushButton, log: QTextEdit, expanded: bool):
    toggle.blockSignals(True)
    toggle.setChecked(expanded)
    toggle.blockSignals(False)
    toggle.setText("Hide details" if expanded else "Show details")
    log.setVisible(expanded)


# ── Hardware card widget ───────────────────────────────────────────────────────
class HardwareCard(QFrame):
    _CARD_NAME = {
        "ok":   "hw-card-ok",
        "warn": "hw-card-warn",
        "err":  "hw-card-err",
        "dim":  "hw-card-dim",
    }
    _BADGE_STYLE = {
        "ok":   ("background: #121e2d; color: #4fc1ff; border: 1px solid #1c3d60;",  "OK"),
        "warn": ("background: #1e1a06; color: #d4a843; border: 1px solid #5c4e14;",  "Warning"),
        "err":  ("background: #3a1010; color: #f48771; border: 1px solid #5a1a1a;",  "Issue"),
        "dim":  ("background: #252526; color: #858585; border: 1px solid #3c3c3c;",  "Info"),
    }

    def __init__(self, probe: HardwareProbe):
        super().__init__()
        self.setObjectName("hw-card-dim")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(18, 14, 18, 14)
        layout.setSpacing(8)

        top = QHBoxLayout()
        top.setSpacing(10)
        self._title = QLabel()
        self._title.setObjectName("card-title")
        top.addWidget(self._title)
        top.addStretch()
        self._badge = QLabel()
        self._badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._badge.setStyleSheet("border-radius: 3px; padding: 3px 9px; font-size: 11px; font-weight: 700;")
        top.addWidget(self._badge)
        layout.addLayout(top)

        self._summary = QLabel()
        self._summary.setWordWrap(True)
        self._summary.setObjectName("card-summary")
        layout.addWidget(self._summary)

        self._details = QLabel()
        self._details.setObjectName("card-copy")
        self._details.setWordWrap(True)
        self._details.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        layout.addWidget(self._details)

        self._action = QLabel()
        self._action.setWordWrap(True)
        self._action.setObjectName("card-action")
        layout.addWidget(self._action)

        self._action_btn = QPushButton()
        self._action_btn.setObjectName("primary")
        self._action_btn.hide()
        layout.addWidget(self._action_btn)

        self.update_probe(probe)

    def update_probe(self, probe: HardwareProbe):
        self._title.setText(probe.title)
        self._summary.setText(probe.summary)
        self._details.setText(probe.details)

        style, badge_text = self._BADGE_STYLE.get(
            probe.status, self._BADGE_STYLE["dim"]
        )
        self._badge.setText(f"  {badge_text}  ")
        self._badge.setStyleSheet(
            style + " border-radius: 3px; padding: 3px 9px; font-size: 11px; font-weight: 700;"
        )

        card_name = self._CARD_NAME.get(probe.status, "hw-card-dim")
        self.setObjectName(card_name)
        _restyle(self)

        if probe.action:
            self._action.setText(probe.action)
            self._action.show()
        else:
            self._action.hide()

    def set_action_fn(self, label: str, fn) -> None:
        self._action.hide()
        self._action_btn.setText(label)
        try:
            self._action_btn.clicked.disconnect()
        except (RuntimeError, TypeError):
            pass
        self._action_btn.clicked.connect(fn)
        self._action_btn.show()


# ── Stat tile widget ───────────────────────────────────────────────────────────
class StatTile(QFrame):
    def __init__(self, label: str, value: str, value_style: str = "stat-value"):
        super().__init__()
        self.setObjectName("stat-tile")
        self.setMinimumHeight(76)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.setCursor(Qt.CursorShape.ArrowCursor)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 14, 16, 14)
        layout.setSpacing(5)

        self._label = QLabel(label.upper())
        self._label.setObjectName("stat-label")
        layout.addWidget(self._label)

        self._value = QLabel(value)
        self._value.setObjectName(value_style)
        self._value.setWordWrap(True)
        layout.addWidget(self._value)

    def set_value(self, value: str, style: str = "stat-value"):
        self._value.setText(value)
        self._value.setObjectName(style)
        _restyle(self._value)


# ── Page base ─────────────────────────────────────────────────────────────────
class _NoAutoScrollArea(QScrollArea):
    """QScrollArea that does not jump to newly visible/focused child widgets."""
    def ensureWidgetVisible(self, widget, xmargin=50, ymargin=50):
        pass  # suppress automatic scroll-to-child on show/focus


class Page(QWidget):
    """Base page — provides a scrollable content area with consistent padding.

    Subclasses can call _page_header(eyebrow, title, subtitle) to render a
    distinct header band before the scroll area, matching the wizard style.
    """
    def __init__(self):
        super().__init__()
        self.setObjectName("content-area")

        self._outer = QVBoxLayout(self)
        self._outer.setContentsMargins(0, 0, 0, 0)
        self._outer.setSpacing(0)

        scroll = _NoAutoScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._outer.addWidget(scroll)

        container = QWidget()
        container.setObjectName("content-area")
        scroll.setWidget(container)

        self._layout = QVBoxLayout(container)
        # Right padding accounts for the 8 px vertical scrollbar overlap
        self._layout.setContentsMargins(56, 44, 64, 48)
        self._layout.setSpacing(24)

    def _page_header(self, eyebrow: str, title: str, subtitle: str = "") -> None:
        """Insert a styled header band at the top of the page (above scroll)."""
        hdr = QWidget()
        hdr.setObjectName("page-header")
        hdr_layout = QVBoxLayout(hdr)
        hdr_layout.setContentsMargins(56, 24, 56, 20)
        hdr_layout.setSpacing(5)

        ew = QLabel(eyebrow.upper())
        ew.setObjectName("eyebrow")
        hdr_layout.addWidget(ew)

        ttl = QLabel(title)
        ttl.setObjectName("heading")
        hdr_layout.addWidget(ttl)

        if subtitle:
            sub = QLabel(subtitle)
            sub.setObjectName("subheading")
            sub.setWordWrap(True)
            hdr_layout.addWidget(sub)

        # Insert header before the scroll area
        self._outer.insertWidget(0, hdr)
        self._outer.insertWidget(1, _divider())

    def _add(self, widget: QWidget) -> QWidget:
        self._layout.addWidget(widget)
        return widget

    def _add_layout(self, layout) -> None:
        self._layout.addLayout(layout)

    def _stretch(self):
        self._layout.addStretch()

    def _heading(self, text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setObjectName("heading")
        self._add(lbl)
        return lbl

    def _subheading(self, text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setObjectName("subheading")
        lbl.setWordWrap(True)
        self._add(lbl)
        return lbl

    def _divider(self):
        self._add(_divider())
