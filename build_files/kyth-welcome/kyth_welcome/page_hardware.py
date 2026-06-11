import shutil
import subprocess
import time

# __KYTH_GENERATED_IMPORTS__
from .core import (  # noqa: E501
    HardwareProbe, HardwareProbeWorker, _command_stdout, _detect_nvidia, _finish_worker, _restyle,
)
from .qt import (  # noqa: E501
    QDesktopServices, QFrame, QHBoxLayout, QLabel, QProgressBar, QPushButton, QTimer, QUrl, QVBoxLayout, QWidget, Signal,
)
from .widgets import (  # noqa: E501
    HardwareCard, Page, _make_card,
)

# ── Page: Hardware ────────────────────────────────────────────────────────────
class HardwarePage(Page):
    action_requested = Signal(str)

    def __init__(self, wizard_mode: bool = False, navigate=None):
        super().__init__()
        self._worker = None
        self._wizard_mode = wizard_mode
        self._navigate = navigate or (lambda key: self.action_requested.emit(key))
        self._cards: list[HardwareCard] = []
        self._last_probes: list[HardwareProbe] = []

        self._page_header(
            "System",
            "Hardware",
            "Graphics, firmware, connectivity, audio, storage, and platform checks.",
        )

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)
        self._refresh_btn = QPushButton("Refresh")
        self._refresh_btn.setObjectName("primary")
        self._refresh_btn.clicked.connect(self.refresh)
        btn_row.addWidget(self._refresh_btn)
        btn_row.addStretch()

        self._status_lbl = QLabel("Running hardware probes…")
        self._status_lbl.setObjectName("subheading")
        btn_row.addWidget(self._status_lbl)
        self._add_layout(btn_row)

        self._progress = QProgressBar()
        self._progress.setRange(0, 0)
        self._add(self._progress)

        driver_card, driver_layout = _make_card("card-accent-ok")
        driver_title = QLabel("Driver Manager")
        driver_title.setObjectName("card-title")
        driver_layout.addWidget(driver_title)
        driver_body = QLabel(
            "Start here when graphics, Wi-Fi, Bluetooth, controllers, audio, printers, or firmware feel wrong. "
            "The checks below turn hardware details into recommended actions; advanced tools stay one click away."
        )
        driver_body.setObjectName("card-copy")
        driver_body.setWordWrap(True)
        driver_layout.addWidget(driver_body)
        driver_btns = QHBoxLayout()
        driver_btns.setSpacing(8)
        for label, key in (
            ("Kernel Choice", "Kernel"),
            ("System Repair", "Repair"),
            ("Controllers", "Controllers"),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, k=key: self._navigate(k))
            driver_btns.addWidget(btn)
        if _detect_nvidia():
            nvidia_btn = QPushButton("NVIDIA Drivers")
            nvidia_btn.setObjectName("primary")
            nvidia_btn.clicked.connect(lambda _=False: self._navigate("NVIDIA"))
            driver_btns.addWidget(nvidia_btn)
        driver_btns.addStretch()
        driver_layout.addLayout(driver_btns)
        self._add(driver_card)

        self._add(self._make_personality_card())
        self._add(self._make_bt_audio_card())
        self._add(self._make_display_card())

        # Card container inside the page's scroll area
        self._card_container = QWidget()
        self._card_container.setObjectName("content-area")
        self._card_col = QVBoxLayout(self._card_container)
        self._card_col.setContentsMargins(0, 0, 0, 0)
        self._card_col.setSpacing(12)
        self._add(self._card_container)

        self._stretch()
        self.refresh()

    def _make_display_card(self) -> QFrame:
        card, layout = _make_card()
        title = QLabel("Display — HDR & Variable Refresh Rate")
        title.setObjectName("card-title")
        layout.addWidget(title)

        # Read current display state via kscreen-doctor
        raw = _command_stdout(["kscreen-doctor", "-o"], timeout=6)
        hdr_outputs: list[tuple[str, str]] = []   # (name, hdr_state)
        vrr_outputs: list[tuple[str, str]] = []   # (name, vrr_state)
        if raw:
            cur_name = ""
            for line in raw.splitlines():
                stripped = line.strip()
                if stripped.startswith("Output:") or (stripped and not line.startswith(" ")):
                    parts = stripped.split()
                    if len(parts) >= 2:
                        cur_name = parts[-1].rstrip(":")
                elif stripped.lower().startswith("hdr:") and cur_name:
                    hdr_outputs.append((cur_name, stripped.split(":", 1)[1].strip()))
                elif stripped.lower().startswith("vrr:") and cur_name:
                    vrr_outputs.append((cur_name, stripped.split(":", 1)[1].strip()))

        if hdr_outputs or vrr_outputs:
            lines = []
            seen = set()
            for name, hdr in hdr_outputs:
                seen.add(name)
                vrr = next((v for n, v in vrr_outputs if n == name), "unknown")
                hdr_str = "HDR on" if hdr == "enabled" else "HDR off"
                vrr_str = f"VRR {vrr}" if vrr not in ("unknown", "") else "VRR unknown"
                lines.append(f"{name}: {hdr_str}  ·  {vrr_str}")
            for name, vrr in vrr_outputs:
                if name not in seen:
                    lines.append(f"{name}: VRR {vrr}")
            status_lbl = QLabel("\n".join(lines))
        else:
            status_lbl = QLabel("Display info unavailable — kscreen not running or no outputs detected.")
        status_lbl.setObjectName("card-copy")
        status_lbl.setWordWrap(True)
        layout.addWidget(status_lbl)

        body = QLabel(
            "HDR and Variable Refresh Rate (FreeSync/G-Sync) are configured per monitor in "
            "KDE Display Settings. Enable HDR for your primary display, then set per-game "
            "HDR via Steam → game properties → General → HDR."
        )
        body.setObjectName("card-copy")
        body.setWordWrap(True)
        layout.addWidget(body)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        display_btn = QPushButton("Display Settings")
        display_btn.setObjectName("primary")
        display_btn.setToolTip("Open KDE Display Settings — HDR, VRR, refresh rate, and multi-monitor layout.")
        display_btn.clicked.connect(
            lambda _=False: subprocess.Popen(["kcmshell6", "kcm_kscreen"])
            if shutil.which("kcmshell6") else QDesktopServices.openUrl(QUrl("settings://display"))
        )
        btns.addWidget(display_btn)
        color_btn = QPushButton("Color & Night Light")
        color_btn.setToolTip("Color profiles and Night Light blue-light filter settings.")
        color_btn.clicked.connect(
            lambda _=False: subprocess.Popen(["kcmshell6", "kcm_nightcolor"])
            if shutil.which("kcmshell6") else None
        )
        btns.addWidget(color_btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    def _make_personality_card(self) -> QFrame:
        pci = _command_stdout(["lspci"], timeout=5).lower()
        cpu = _command_stdout(["lscpu"], timeout=5).lower()
        if "nvidia" in pci and ("amd" in cpu or "ryzen" in cpu):
            title = "NVIDIA gaming desktop"
            note = "Best first checks: proprietary module active, Vulkan summary, display refresh rate, and Game Night Mode."
        elif "nvidia" in pci:
            title = "NVIDIA gaming machine"
            note = "Best first checks: driver build status, Secure Boot state, Vulkan, and external display behavior."
        elif "amd" in pci or "radeon" in pci:
            title = "AMD/Radeon gaming machine"
            note = "Best first checks: Mesa/Vulkan, VRR/high refresh, MangoHud, and firmware updates."
        elif "intel" in pci:
            title = "Intel laptop or iGPU desktop"
            note = "Best first checks: Wi-Fi, Bluetooth, suspend/resume, fractional scaling, and battery profile."
        else:
            title = "KythOS desktop"
            note = "Best first checks: graphics, audio, network, firmware, and rollback confidence."

        card, layout = _make_card("card-accent-ok")
        card_title = QLabel(f"Hardware Personality: {title}")
        card_title.setObjectName("card-title")
        layout.addWidget(card_title)
        body = QLabel(note)
        body.setObjectName("card-copy")
        body.setWordWrap(True)
        layout.addWidget(body)
        btns = QHBoxLayout()
        for label, key in (("Gaming", "Gaming"), ("Controllers", "Controllers"), ("Repair", "Repair")):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, k=key: self._navigate(k))
            btns.addWidget(btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    def _make_bt_audio_card(self) -> QFrame:
        card, layout = _make_card()
        title = QLabel("Bluetooth Audio")
        title.setObjectName("card-title")
        layout.addWidget(title)

        desc = QLabel(
            "KythOS prefers LDAC (990 kbps HQ) over SBC when your headset supports it. "
            "If your Bluetooth headset sounds worse than on Windows, use the controls below "
            "to check the active codec, switch audio to your headset, or reconnect to renegotiate the codec."
        )
        desc.setObjectName("card-copy")
        desc.setWordWrap(True)
        layout.addWidget(desc)

        self._bt_status_lbl = QLabel("Click Refresh Devices to scan.")
        self._bt_status_lbl.setObjectName("card-copy")
        self._bt_status_lbl.setWordWrap(True)
        layout.addWidget(self._bt_status_lbl)

        btns = QHBoxLayout()
        btns.setSpacing(8)
        refresh_btn = QPushButton("Refresh Devices")
        refresh_btn.clicked.connect(self._refresh_bt_audio)
        btns.addWidget(refresh_btn)
        switch_btn = QPushButton("Switch to BT Output")
        switch_btn.setToolTip("Set the connected Bluetooth audio device as the default audio output.")
        switch_btn.clicked.connect(self._switch_to_bt_audio)
        btns.addWidget(switch_btn)
        ldac_btn = QPushButton("Force LDAC Reconnect")
        ldac_btn.setToolTip(
            "Disconnect and reconnect the active Bluetooth device to renegotiate codec. "
            "Use this if your headset falls back to SBC instead of LDAC."
        )
        ldac_btn.clicked.connect(self._force_ldac_reconnect)
        btns.addWidget(ldac_btn)
        bt_settings_btn = QPushButton("Bluetooth Settings")
        bt_settings_btn.clicked.connect(
            lambda: subprocess.Popen(["kcmshell6", "kcm_bluetooth"])
            if shutil.which("kcmshell6") else QDesktopServices.openUrl(QUrl("settings://bluetooth"))
        )
        btns.addWidget(bt_settings_btn)
        btns.addStretch()
        layout.addLayout(btns)
        return card

    def _refresh_bt_audio(self):
        paired = _command_stdout(["bluetoothctl", "devices", "Paired"], timeout=5)
        connected = _command_stdout(["bluetoothctl", "devices", "Connected"], timeout=5)
        connected_addrs = {
            line.split()[1] for line in connected.splitlines()
            if len(line.split()) >= 2
        }
        sinks_raw = _command_stdout(
            ["bash", "-c", "wpctl status 2>/dev/null | grep -E 'bluez_output' | head -8"],
            timeout=5,
        )
        lines: list[str] = []
        for line in paired.splitlines():
            parts = line.split(" ", 2)
            if len(parts) < 3:
                continue
            addr, name = parts[1], parts[2]
            state = "Connected" if addr in connected_addrs else "Paired (not connected)"
            lines.append(f"{name}  [{addr}]  —  {state}")
        if sinks_raw.strip():
            lines.append(f"\nWirePlumber BT sinks:\n{sinks_raw.strip()}")
        self._bt_status_lbl.setText(
            "\n".join(lines) if lines
            else "No paired Bluetooth devices found. Pair a headset via Bluetooth Settings."
        )

    def _switch_to_bt_audio(self):
        result = subprocess.run(
            ["bash", "-c",
             "wpctl status 2>/dev/null | grep -E '\\bbluez_output' | head -1"
             " | awk '{print $1}' | tr -d '.*'"],
            capture_output=True, text=True, timeout=5,
        )
        sink_id = result.stdout.strip()
        if sink_id:
            subprocess.run(["wpctl", "set-default", sink_id], timeout=5, check=False)
            self._bt_status_lbl.setText(
                f"Audio output switched to Bluetooth device (WirePlumber ID: {sink_id}). "
                "If the change doesn't take effect, log out and back in."
            )
        else:
            self._bt_status_lbl.setText(
                "No Bluetooth audio output found. Make sure your headset is connected, then refresh."
            )

    def _force_ldac_reconnect(self):
        connected = _command_stdout(["bluetoothctl", "devices", "Connected"], timeout=5)
        for line in connected.splitlines():
            parts = line.split(" ", 2)
            if len(parts) < 2:
                continue
            addr = parts[1]
            self._bt_status_lbl.setText(f"Reconnecting {addr} to renegotiate codec…")
            subprocess.run(["bluetoothctl", "disconnect", addr], timeout=6, check=False)
            time.sleep(1.5)
            subprocess.run(["bluetoothctl", "connect", addr], timeout=12, check=False)
            self._bt_status_lbl.setText(
                f"Reconnected {addr}. LDAC should now be active if your device supports it. "
                "Refresh Devices to confirm the WirePlumber sink is present."
            )
            return
        self._bt_status_lbl.setText("No connected Bluetooth device found. Connect your headset first.")

    def refresh(self):
        self._refresh_btn.setEnabled(False)
        self._status_lbl.setText("Running hardware probes…")
        self._status_lbl.setObjectName("subheading")
        _restyle(self._status_lbl)
        self._progress.show()

        self._worker = HardwareProbeWorker()
        self._worker.done.connect(self._on_done)
        self._worker.failed.connect(self._on_failed)
        self._worker.start()

    def _replace_cards(self, probes: list[HardwareProbe]):
        while self._card_col.count():
            item = self._card_col.takeAt(0)
            if w := item.widget():
                w.deleteLater()
        self._cards = []
        for probe in probes:
            card = HardwareCard(probe)
            self._cards.append(card)
            self._card_col.addWidget(card)

    def _on_done(self, probes: list[HardwareProbe]):
        self._progress.hide()
        self._refresh_btn.setEnabled(True)
        _finish_worker(self)
        self._replace_cards(probes)
        self._last_probes = probes

        levels = {p.status for p in probes}
        if "err" in levels:
            self._status_lbl.setText("One or more issues need attention.")
            self._status_lbl.setObjectName("status-err")
        elif "warn" in levels:
            self._status_lbl.setText("Mostly healthy — a few items worth checking.")
            self._status_lbl.setObjectName("status-warn")
        else:
            self._status_lbl.setText("All checks passed.")
            self._status_lbl.setObjectName("status-ok")
        _restyle(self._status_lbl)

        if self._wizard_mode:
            self._wire_wizard_action_buttons(probes)

    def _wire_wizard_action_buttons(self, probes: list[HardwareProbe]):
        for card, probe in zip(self._cards, probes):
            if probe.action_page_key:
                key = probe.action_page_key
                card.set_action_fn(
                    probe.action or f"Open {key}",
                    lambda k=key: self.action_requested.emit(k),
                )
            elif probe.action_cmd:
                cmd = probe.action_cmd
                card.set_action_fn(
                    probe.action or "Fix",
                    lambda c=cmd: self._run_inline_cmd(c),
                )

    def _run_inline_cmd(self, cmd: list[str]):
        try:
            subprocess.Popen(cmd)
        except OSError:
            pass
        QTimer.singleShot(1500, self.refresh)

    def _on_failed(self, message: str):
        self._progress.hide()
        self._refresh_btn.setEnabled(True)
        _finish_worker(self)
        self._status_lbl.setText(f"Probe failed: {message}")
        self._status_lbl.setObjectName("status-err")
        _restyle(self._status_lbl)
