import os
import re
import subprocess
from datetime import datetime

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    DataWorker, HardwareProbe, HardwareProbeWorker, _diagnostics_report, _finish_worker, _health_command_report, _health_recommendations, _restyle,
)
from .qt import (  # noqa: E501
    QApplication, QFileDialog, QHBoxLayout, QLabel, QProgressBar, QPushButton, QTextEdit, QVBoxLayout, QWidget,
)
from .widgets import (  # noqa: E501
    HardwareCard, Page, _make_card,
)

# ── Page: Diagnostics ─────────────────────────────────────────────────────────
class DiagnosticsPage(Page):
    def __init__(self):
        super().__init__()
        self._worker = None
        self._health_worker = None
        self._last_probes: list[HardwareProbe] = []
        self._base_report = ""
        self._health_report = ""
        self._probe_cards: dict[str, HardwareCard] = {}

        self._page_header(
            "System",
            "Health Report",
            "A quick look at how your hardware and system stack are doing.",
        )

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)
        self._refresh_btn = QPushButton("Run Health Report")
        self._refresh_btn.setObjectName("primary")
        self._refresh_btn.clicked.connect(self.refresh)
        btn_row.addWidget(self._refresh_btn)

        self._copy_btn = QPushButton("Copy Report")
        self._copy_btn.setEnabled(False)
        self._copy_btn.clicked.connect(self._copy_report)
        btn_row.addWidget(self._copy_btn)

        self._save_btn = QPushButton("Save Report…")
        self._save_btn.setEnabled(False)
        self._save_btn.clicked.connect(self._save_report)
        btn_row.addWidget(self._save_btn)

        self._issue_btn = QPushButton("Report Issue")
        self._issue_btn.setEnabled(False)
        self._issue_btn.clicked.connect(self._report_issue)
        btn_row.addWidget(self._issue_btn)
        btn_row.addStretch()

        self._status_lbl = QLabel()
        self._status_lbl.setObjectName("subheading")
        btn_row.addWidget(self._status_lbl)
        self._add_layout(btn_row)

        self._progress = QProgressBar()
        self._progress.setRange(0, 0)
        self._add(self._progress)

        # Summary banner
        self._banner_card, self._banner_layout = _make_card()
        self._banner_title = QLabel()
        self._banner_title.setObjectName("card-title")
        self._banner_layout.addWidget(self._banner_title)
        self._banner_body = QLabel()
        self._banner_body.setObjectName("card-copy")
        self._banner_body.setWordWrap(True)
        self._banner_layout.addWidget(self._banner_body)
        self._banner_card.hide()
        self._add(self._banner_card)

        # Per-probe cards
        self._cards_widget = QWidget()
        self._cards_layout = QVBoxLayout(self._cards_widget)
        self._cards_layout.setContentsMargins(0, 0, 0, 0)
        self._cards_layout.setSpacing(8)
        self._add(self._cards_widget)

        # Raw report (hidden; surfaced via toggle for support use)
        self._raw_toggle = QPushButton("Show technical details")
        self._raw_toggle.setCheckable(True)
        self._raw_toggle.setChecked(False)
        self._raw_toggle.toggled.connect(self._toggle_raw)
        self._raw_toggle.hide()
        self._add(self._raw_toggle)

        self._report = QTextEdit()
        self._report.setReadOnly(True)
        self._report.setMinimumHeight(220)
        self._report.hide()
        self._add(self._report)

        self._stretch()
        self.refresh()

    def _clear_cards(self):
        while self._cards_layout.count():
            item = self._cards_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self._probe_cards = {}

    def _build_summary_banner(self, probes: list[HardwareProbe]) -> None:
        errs  = [p for p in probes if p.status == "err"]
        warns = [p for p in probes if p.status == "warn"]
        oks   = [p for p in probes if p.status == "ok"]
        if errs:
            self._banner_card.setObjectName("card-accent-err")
            self._banner_title.setText(
                f"{len(errs)} issue{'s' if len(errs) != 1 else ''} found"
            )
            self._banner_body.setText(
                "Some hardware or system checks need attention. "
                "Review the items below and follow the suggested fixes."
            )
        elif warns:
            self._banner_card.setObjectName("card-accent-warn")
            self._banner_title.setText(
                f"{len(warns)} warning{'s' if len(warns) != 1 else ''}"
            )
            self._banner_body.setText(
                "Everything is mostly working but some things could be improved. "
                "Check the items below for details."
            )
        else:
            self._banner_card.setObjectName("card-accent-ok")
            self._banner_title.setText(f"All {len(oks)} checks passed")
            self._banner_body.setText("Your hardware and system stack look healthy.")
        _restyle(self._banner_card)
        self._banner_card.show()

    def refresh(self):
        self._refresh_btn.setEnabled(False)
        self._copy_btn.setEnabled(False)
        self._save_btn.setEnabled(False)
        self._issue_btn.setEnabled(False)
        self._status_lbl.setText("Gathering system information…")
        self._status_lbl.setObjectName("subheading")
        _restyle(self._status_lbl)
        self._progress.show()
        self._base_report = ""
        self._health_report = ""
        self._banner_card.hide()
        self._raw_toggle.hide()
        self._report.hide()
        self._report.setPlainText("")
        self._clear_cards()

        self._worker = HardwareProbeWorker()
        self._worker.done.connect(self._on_done)
        self._worker.failed.connect(self._on_failed)
        self._worker.start()

    def _on_done(self, probes: list[HardwareProbe]):
        self._progress.hide()
        self._refresh_btn.setEnabled(True)
        _finish_worker(self)
        self._last_probes = probes
        self._base_report = _diagnostics_report(probes)

        self._build_summary_banner(probes)
        self._clear_cards()
        for probe in probes:
            card = HardwareCard(probe)
            self._probe_cards[probe.title] = card
            self._cards_layout.addWidget(card)

        levels = {p.status for p in probes}
        if "err" in levels:
            self._status_lbl.setText("Issues found — running extended checks…")
            self._status_lbl.setObjectName("status-err")
        elif "warn" in levels:
            self._status_lbl.setText("Warnings found — running extended checks…")
            self._status_lbl.setObjectName("status-warn")
        else:
            self._status_lbl.setText("Hardware checks passed — running extended checks…")
            self._status_lbl.setObjectName("status-ok")
        _restyle(self._status_lbl)

        self._health_worker = DataWorker("health", _health_command_report)
        self._health_worker.result.connect(self._on_health_done)
        self._health_worker.failed.connect(self._on_health_failed)
        self._health_worker.start()

    def _on_health_done(self, _key: str, report: str):
        _finish_worker(self, "_health_worker")
        self._health_report = str(report)
        recs = _health_recommendations(self._base_report + self._health_report)
        self._report.setPlainText(self._base_report + recs + self._health_report)
        self._copy_btn.setEnabled(True)
        self._save_btn.setEnabled(True)
        self._issue_btn.setEnabled(True)
        self._raw_toggle.show()

        has_failures = (
            re.search(r"^FAIL\s+", self._health_report, re.MULTILINE)
            or re.search(r"^FAIL:\s*[1-9]", self._health_report, re.MULTILINE)
            or "Result: not daily-driver ready" in self._health_report
        )
        has_warnings = (
            re.search(r"^WARN\s+", self._health_report, re.MULTILINE)
            or re.search(r"^WARN:\s*[1-9]", self._health_report, re.MULTILINE)
            or "Result: controller readiness has warnings" in self._health_report
            or "Result: resume readiness has warnings" in self._health_report
        )
        if has_failures:
            self._status_lbl.setText("Issues found — check the details above.")
            self._status_lbl.setObjectName("status-err")
        elif has_warnings:
            self._status_lbl.setText("Warnings found — review the items above.")
            self._status_lbl.setObjectName("status-warn")
        else:
            self._status_lbl.setText("All checks completed successfully.")
            self._status_lbl.setObjectName("status-ok")
        _restyle(self._status_lbl)

    def _on_health_failed(self, _key: str, message: str):
        _finish_worker(self, "_health_worker")
        self._health_report = f"\nKythOS Health Command Output\n==========================\n\nfailed: {message}\n"
        self._report.setPlainText(self._base_report + self._health_report)
        self._copy_btn.setEnabled(True)
        self._save_btn.setEnabled(True)
        self._issue_btn.setEnabled(True)
        self._raw_toggle.show()
        self._status_lbl.setText(f"Extended checks failed: {message}")
        self._status_lbl.setObjectName("status-err")
        _restyle(self._status_lbl)

    def _on_failed(self, message: str):
        self._progress.hide()
        self._refresh_btn.setEnabled(True)
        _finish_worker(self)
        self._status_lbl.setText(f"Failed: {message}")
        self._status_lbl.setObjectName("status-err")
        _restyle(self._status_lbl)

    def _toggle_raw(self, checked: bool):
        self._raw_toggle.setText(
            "Hide technical details" if checked else "Show technical details"
        )
        self._report.setVisible(checked)

    def _copy_report(self):
        QApplication.clipboard().setText(self._report.toPlainText())
        self._status_lbl.setText("Report copied to clipboard.")
        self._status_lbl.setObjectName("status-ok")
        _restyle(self._status_lbl)

    def _save_report(self):
        default = os.path.expanduser(f"~/Documents/kyth-health-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.txt")
        path, _ = QFileDialog.getSaveFileName(self, "Save Health Report", default, "Text Files (*.txt);;All Files (*)")
        if not path:
            return
        try:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(self._report.toPlainText())
            self._status_lbl.setText(f"Saved to {path}.")
            self._status_lbl.setObjectName("status-ok")
        except OSError as exc:
            self._status_lbl.setText(f"Could not save: {exc}")
            self._status_lbl.setObjectName("status-err")
        _restyle(self._status_lbl)

    def _report_issue(self):
        report = self._report.toPlainText().strip()
        if not report:
            self._status_lbl.setText("Run a health report first.")
            self._status_lbl.setObjectName("status-warn")
            _restyle(self._status_lbl)
            return
        report_dir = os.path.expanduser("~/.local/state/kyth")
        body_path = os.path.join(report_dir, f"health-report-issue-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
        body = (
            "## What happened\n\n"
            "Describe what you were doing and what went wrong.\n\n"
            "## KythOS health report\n\n"
            "```text\n"
            f"{report}\n"
            "```\n"
        )
        try:
            os.makedirs(report_dir, exist_ok=True)
            with open(body_path, "w", encoding="utf-8") as fh:
                fh.write(body)
            subprocess.Popen([
                "/usr/bin/kyth-report-issue",
                "--title", "KythOS health report issue",
                "--body-file", body_path,
                "--label", "bug",
            ])
            self._status_lbl.setText("Opening a prefilled GitHub issue.")
            self._status_lbl.setObjectName("status-ok")
        except OSError as exc:
            self._status_lbl.setText(f"Could not prepare issue: {exc}")
            self._status_lbl.setObjectName("status-err")
        _restyle(self._status_lbl)
