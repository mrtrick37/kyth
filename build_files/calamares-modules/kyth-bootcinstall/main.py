#!/usr/bin/env python3
# kyth-bootcinstall — Calamares Python job module
#
# Installs Kyth using podman + 'bootc install to-disk'.
# Running bootc from within the clean container image means no live-session
# contamination — the installed system is exactly the OCI image, with no
# live-only config to undo.
#
# Flow:
#   1.  Read target disk from globalStorage.
#   2.  Unmount stale mounts on the disk; wipe partition signatures.
#   3.  Activate zram swap.
#   4.  Set mq-deadline I/O scheduler.
#   5.  Run: podman run --privileged --pid=host -v /dev:/dev <image>
#             bootc install to-disk --target-imgref <ref> [--skip-fetch-check] <disk>
#       Uses bundled OCI dir (offline) or registry pull (online).
#   6.  Mount the installed root partition (bootc layout: EFI=p1, root=p2).
#   7.  Find the ostree deployment directory.
#   8.  Bind-mount /proc /sys /dev /var for Calamares locale/users jobs.
#   9.  Update globalStorage rootMountPoint for handoff.

import glob as _glob
import math
import os
import re
import subprocess
import tempfile
import threading
import time

import libcalamares

# ── Source image ──────────────────────────────────────────────────────────────
_BUNDLED_OCI_DIR    = "/usr/share/kyth/image"
_SOURCE_IMGREF_FILE = "/usr/share/kyth/source-imgref"

if os.path.isdir(_BUNDLED_OCI_DIR):
    _OFFLINE   = True
    _IMAGE_REF = f"oci:{_BUNDLED_OCI_DIR}"
else:
    _OFFLINE   = False
    _default   = "ghcr.io/mrtrick37/kyth:latest"
    try:
        raw = open(_SOURCE_IMGREF_FILE).read().strip()
        if raw:
            # Strip legacy docker:// transport prefix — podman run uses plain refs
            _default = raw.removeprefix("docker://")
    except OSError:
        pass
    _IMAGE_REF = os.environ.get("KYTH_SOURCE_IMGREF", _default)

# The bootc tracking ref the installed system uses for future upgrades.
_default_target = (
    _IMAGE_REF if not _IMAGE_REF.startswith("oci:")
    else "ghcr.io/mrtrick37/kyth:latest"
)
TARGET_IMGREF = os.environ.get("KYTH_TARGET_IMGREF", _default_target)

# Where we mount the target root to hand off to Calamares locale/users jobs.
TARGET_ROOT = "/mnt/kyth-install"

_DISK_RE = re.compile(
    r"^(/dev/(?:sd[a-z]+|vd[a-z]+|hd[a-z]+|nvme\d+n\d+))(?:p?\d+)?$"
)


def pretty_name():
    return "Installing Kyth"


def _log(msg):
    libcalamares.utils.debug(f"kyth-bootcinstall: {msg}")


def _run(cmd):
    _log(" ".join(str(c) for c in cmd))
    subprocess.run(cmd, check=True)


def _run_best_effort(cmd):
    try:
        subprocess.run(cmd, check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        _log(f"  (ignored: {e})")


def _find_disk(gs):
    disk = (gs.value("installationDevice") or
            gs.value("bootLoaderInstallPath") or "").strip()
    if disk:
        m = _DISK_RE.match(disk)
        return m.group(1) if m else disk
    for part in (gs.value("partitions") or []):
        device = part.get("device", "") if isinstance(part, dict) else ""
        m = _DISK_RE.match(device)
        if m:
            return m.group(1)
    return ""


def _part(disk, n):
    """Return the nth partition path (e.g. /dev/nvme0n1p2, /dev/vda2)."""
    if re.search(r"(nvme\d+n\d+|loop\d+)$", disk):
        return f"{disk}p{n}"
    return f"{disk}{n}"


def _setup_zram_swap():
    try:
        subprocess.run(["modprobe", "zram"], check=True, capture_output=True)
        mem_kb = 0
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    mem_kb = int(line.split()[1])
                    break
        zram_bytes = min(mem_kb * 1024, 4 * 1024 ** 3)
        with open("/sys/block/zram0/comp_algorithm", "w") as f:
            f.write("zstd\n")
        with open("/sys/block/zram0/disksize", "w") as f:
            f.write(f"{zram_bytes}\n")
        subprocess.run(["mkswap", "/dev/zram0"], check=True, capture_output=True)
        subprocess.run(["swapon", "-p", "100", "/dev/zram0"], check=True, capture_output=True)
        _log(f"zram swap active: {zram_bytes // (1024 ** 2)} MiB")
    except Exception as e:
        _log(f"warning: zram swap setup failed: {e}")


def _set_scheduler(dev_name):
    sched_path = f"/sys/block/{dev_name}/queue/scheduler"
    if not os.path.exists(sched_path):
        return
    try:
        with open(sched_path) as f:
            available = f.read()
        for sched in ["mq-deadline", "deadline", "none"]:
            if sched in available:
                with open(sched_path, "w") as f:
                    f.write(sched + "\n")
                _log(f"I/O scheduler: {sched} on {dev_name}")
                return
    except OSError as e:
        _log(f"warning: scheduler on {dev_name}: {e}")


def _find_deployment(mount_root):
    deploy_base = os.path.join(mount_root, "ostree", "deploy")
    if not os.path.isdir(deploy_base):
        return None, None
    stateroots = [e for e in os.listdir(deploy_base)
                  if os.path.isdir(os.path.join(deploy_base, e))]
    if not stateroots:
        return None, None
    stateroot  = stateroots[0]
    var_dir    = os.path.join(deploy_base, stateroot, "var")
    deploy_sub = os.path.join(deploy_base, stateroot, "deploy")
    if not os.path.isdir(deploy_sub):
        return None, None
    deploys = [d for d in os.listdir(deploy_sub)
               if not d.endswith(".origin")
               and os.path.isdir(os.path.join(deploy_sub, d))]
    if not deploys:
        return None, None
    deploy_dir = os.path.join(deploy_sub, deploys[0])
    if not os.path.isdir(os.path.join(deploy_dir, "usr")):
        return None, None
    return deploy_dir, var_dir


def run():
    gs = libcalamares.globalstorage

    # ── 1. Resolve target disk ───────────────────────────────────────────────
    disk = _find_disk(gs)
    if not disk:
        return (
            "Installation error",
            "Could not determine the target disk.\n"
            "Please go back and select a disk, then try again.",
        )
    _log(f"target disk: {disk}  image: {_IMAGE_REF}  target-imgref: {TARGET_IMGREF}")

    # ── 2. Unmount stale mounts + wipe signatures ────────────────────────────
    # Release any mounts the Calamares partition show module left behind,
    # and any partitions auto-mounted by udisks2 from a prior install attempt.
    libcalamares.job.setprogress(0.01)
    old_root = (gs.value("rootMountPoint") or "/tmp/calamares-root").rstrip("/")
    _run_best_effort(["umount", "-R", old_root])
    try:
        lsblk = subprocess.run(
            ["lsblk", "-n", "-o", "MOUNTPOINT", disk],
            capture_output=True, text=True, check=True,
        )
        for mp in lsblk.stdout.splitlines():
            mp = mp.strip()
            if mp and mp != "[SWAP]":
                _run_best_effort(["umount", "-R", mp])
    except subprocess.CalledProcessError:
        pass
    _run_best_effort(["swapoff", "--all"])
    _run_best_effort(["vgchange", "-an"])
    _run_best_effort(["wipefs", "--all", "--force", disk])
    _run_best_effort(["partprobe", disk])
    _run_best_effort(["udevadm", "settle"])

    # ── 3. Zram swap ────────────────────────────────────────────────────────
    libcalamares.job.setprogress(0.02)
    _setup_zram_swap()

    # ── 4. I/O schedulers ───────────────────────────────────────────────────
    _set_scheduler(os.path.basename(disk))
    for p in _glob.glob("/sys/block/loop*/queue/scheduler"):
        _set_scheduler(os.path.basename(os.path.dirname(os.path.dirname(p))))
    for p in _glob.glob("/sys/block/nvme*/queue/scheduler"):
        _set_scheduler(os.path.basename(os.path.dirname(os.path.dirname(p))))

    # Tune VM memory management for large OCI layer extraction.
    for path, val in [
        ("/proc/sys/vm/swappiness",             "200"),
        ("/proc/sys/vm/vfs_cache_pressure",     "500"),
        ("/proc/sys/vm/dirty_ratio",            "5"),
        ("/proc/sys/vm/dirty_background_ratio", "2"),
    ]:
        try:
            with open(path, "w") as f:
                f.write(val + "\n")
        except OSError:
            pass

    libcalamares.job.setprogress(0.04)

    # ── 5. Build podman + bootc command ──────────────────────────────────────
    # Running 'bootc install to-disk' from within the container installs that
    # container's own image — no live-session contamination possible.
    podman_cmd = [
        "nice", "-n", "10",
        "podman", "run", "--rm",
        "--privileged",
        "--pid=host",
        "--security-opt", "label=disable",
        "-v", "/dev:/dev",
        _IMAGE_REF,
        "bootc", "install", "to-disk",
        "--target-imgref", TARGET_IMGREF,
    ]
    if _OFFLINE:
        podman_cmd.append("--skip-fetch-check")
    podman_cmd.append(disk)

    # ── 6. Progress thread ───────────────────────────────────────────────────
    _stop_event = threading.Event()

    PHASE_LABELS = (
        [
            (0.00, "Installing OS — this takes a few minutes…"),
            (0.10, "Extracting OS image…"),
            (0.55, "Writing filesystem layers…"),
            (0.82, "Committing ostree deployment…"),
            (0.93, "Installing bootloader…"),
            (0.97, "Finalizing…"),
        ] if _OFFLINE else [
            (0.00, "Connecting to registry…"),
            (0.05, "Downloading OS image — this may take 10-20 minutes…"),
            (0.60, "Writing filesystem layers…"),
            (0.82, "Committing ostree deployment…"),
            (0.93, "Installing bootloader…"),
            (0.97, "Finalizing…"),
        ]
    )
    HALF_TIME = 300 if _OFFLINE else 360

    def _progress_thread():
        TARGET_VAL = 0.88
        start      = time.monotonic()
        last_label = ""
        while not _stop_event.is_set():
            elapsed  = time.monotonic() - start
            k        = math.log(2) / HALF_TIME
            value    = min(TARGET_VAL * (1.0 - math.exp(-k * elapsed)), TARGET_VAL)
            libcalamares.job.setprogress(value)
            fraction = value / TARGET_VAL
            label    = PHASE_LABELS[0][1]
            for threshold, lbl in PHASE_LABELS:
                if fraction >= threshold:
                    label = lbl
            if label != last_label:
                _log(f"status: {label}")
                last_label = label
            time.sleep(1.5)

    t = threading.Thread(target=_progress_thread, daemon=True)
    t.start()

    # ── 7. Run bootc install via podman ──────────────────────────────────────
    log_fd, log_path = tempfile.mkstemp(prefix="bootc-install.", suffix=".log")
    os.close(log_fd)
    _log(f"bootc output log: {log_path}")
    _log(" ".join(str(c) for c in podman_cmd))

    try:
        with open(log_path, "w") as log_fh:
            with subprocess.Popen(
                podman_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            ) as proc:
                for line in proc.stdout:
                    log_fh.write(line)
                    log_fh.flush()
                    _log(f"bootc: {line.rstrip()}")
                proc.wait()
            if proc.returncode != 0:
                raise subprocess.CalledProcessError(proc.returncode, podman_cmd)
    except subprocess.CalledProcessError as e:
        _stop_event.set()
        try:
            with open(log_path) as lf:
                detail = lf.read().strip()
        except OSError:
            detail = ""
        _log(f"podman/bootc exit {e.returncode}: {detail!r}")
        return (
            "Installation failed",
            f"bootc install to-disk failed (exit {e.returncode}).\n\n"
            + (detail or f"No output captured. Check {log_path} and journalctl."),
        )
    finally:
        _stop_event.set()

    libcalamares.job.setprogress(0.90)

    # ── 8. Mount installed root ──────────────────────────────────────────────
    # bootc to-disk layout: partition 1 = EFI, partition 2 = root.
    root_part = _part(disk, 2)
    _log(f"mounting installed root: {root_part} → {TARGET_ROOT}")
    os.makedirs(TARGET_ROOT, exist_ok=True)
    try:
        _run(["mount", root_part, TARGET_ROOT])
    except subprocess.CalledProcessError:
        return ("Installation error", f"Could not mount {root_part} at {TARGET_ROOT}.")

    # ── 9. Find ostree deployment ────────────────────────────────────────────
    deploy_dir, var_dir = _find_deployment(TARGET_ROOT)
    if not deploy_dir:
        subprocess.run(["umount", "-R", TARGET_ROOT], capture_output=True)
        return (
            "Post-install error",
            f"Could not locate the ostree deployment under {TARGET_ROOT}.\n"
            "The OS was installed but user configuration was not applied.",
        )

    _log(f"deployment: {deploy_dir}")
    _log(f"var dir:    {var_dir}")

    # ── 10. Bind-mount pseudo-filesystems for Calamares locale/users jobs ─────
    libcalamares.job.setprogress(0.95)
    for sub, src in [("proc", "/proc"), ("sys", "/sys"), ("dev", "/dev")]:
        _run(["mount", "--bind", src, os.path.join(deploy_dir, sub)])
    if var_dir and os.path.isdir(var_dir):
        _run(["mount", "--bind", var_dir, os.path.join(deploy_dir, "var")])

    # ── 11. Hand off to Calamares locale/users jobs ───────────────────────────
    gs.insert("rootMountPoint",   deploy_dir)
    gs.insert("kyth_outer_mount", TARGET_ROOT)

    _log(f"rootMountPoint   → {deploy_dir}")
    _log(f"kyth_outer_mount → {TARGET_ROOT}")

    libcalamares.job.setprogress(1.0)
    return None
