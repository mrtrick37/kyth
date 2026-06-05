#!/usr/bin/env bash
# Remove distro artwork from Plymouth fallback themes. This is intentionally
# runnable more than once because package upgrades can restore upstream assets.

set -euo pipefail

source_svg="${1:-}"
asset_dir=/usr/share/kyth/branding
transparent_svg="${asset_dir}/transparent-watermark.svg"
transparent_png="${asset_dir}/transparent-watermark.png"

mkdir -p "${asset_dir}"
if [[ -n "${source_svg}" && -r "${source_svg}" ]]; then
	install -m 0644 "${source_svg}" "${transparent_svg}"
elif [[ ! -r "${transparent_svg}" ]]; then
	cat >"${transparent_svg}" <<'SVEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" viewBox="0 0 1 1">
  <rect width="1" height="1" fill="none"/>
</svg>
SVEOF
fi

if command -v rsvg-convert >/dev/null 2>&1; then
	rsvg-convert "${transparent_svg}" -o "${transparent_png}"
elif [[ ! -r "${transparent_png}" ]]; then
	printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=' |
		base64 -d >"${transparent_png}"
fi

for theme_dir in \
	/usr/share/plymouth/themes/spinner \
	/usr/share/plymouth/themes/bgrt \
	/usr/share/plymouth/themes/bgrt-fedora; do
	[[ -d "${theme_dir}" ]] || continue

	for asset in watermark.png watermark@2x.png logo.png; do
		install -m 0644 "${transparent_png}" "${theme_dir}/${asset}"
	done
	for asset in watermark.svg logo.svg; do
		install -m 0644 "${transparent_svg}" "${theme_dir}/${asset}"
	done

	for branded_asset in "${theme_dir}"/*fedora* "${theme_dir}"/*Fedora* "${theme_dir}"/*FEDORA*; do
		[[ -e "${branded_asset}" ]] || continue
		case "${branded_asset}" in
		*.svg | *.svgz)
			install -m 0644 "${transparent_svg}" "${branded_asset}"
			;;
		*.png)
			install -m 0644 "${transparent_png}" "${branded_asset}"
			;;
		*)
			rm -f "${branded_asset}"
			;;
		esac
	done
done

# Remove both Fedora-branded and plain bgrt themes from the system filesystem.
# The bgrt theme (not just bgrt-fedora) can fall back to rendering the UEFI
# BGRT ACPI table image — which may contain the Fedora logo written by the
# original bootloader/shim.  Removing the directory makes the fallback
# impossible; Plymouth can only use kyth, details, or text.
rm -rf /usr/share/plymouth/themes/bgrt-fedora
rm -rf /usr/share/plymouth/themes/bgrt
plymouth-set-default-theme kyth

# Write plymouthd.conf and plymouthd.defaults to the host filesystem so that
# dracut's 45plymouth module (plymouth-populate-initrd) installs a non-empty
# file, and the first-boot initramfs rebuild service finds the correct config.
mkdir -p /etc/plymouth /usr/share/plymouth
printf '[Daemon]\nTheme=kyth\nShowDelay=1\nUseFirmwareBackground=false\n' \
	>/etc/plymouth/plymouthd.conf
install -m 0644 /etc/plymouth/plymouthd.conf /usr/share/plymouth/plymouthd.defaults

rm -rf /usr/lib/dracut/modules.d/46kyth-plymouth
kyth_plymouth_dracut_dir=/usr/lib/dracut/modules.d/99kyth-plymouth
mkdir -p "${kyth_plymouth_dracut_dir}"
cat >"${kyth_plymouth_dracut_dir}/module-setup.sh" <<'KYTHPLYMOUTHEOF'
#!/usr/bin/bash

check() {
    return 0
}

depends() {
    echo plymouth
    return 0
}

install() {
    mkdir -p \
        "${initdir}/etc/plymouth" \
        "${initdir}/usr/share/plymouth/themes"
    printf '[Daemon]\nTheme=kyth\nShowDelay=1\nUseFirmwareBackground=false\n' \
        > "${initdir}/etc/plymouth/plymouthd.conf"
    printf '[Daemon]\nTheme=kyth\nShowDelay=1\nUseFirmwareBackground=false\n' \
        > "${initdir}/usr/share/plymouth/plymouthd.defaults"
    echo "=== kyth-plymouth: plymouthd.conf ($(wc -c < "${initdir}/etc/plymouth/plymouthd.conf" 2>/dev/null || echo MISSING) bytes) ===" >&2
    cat "${initdir}/etc/plymouth/plymouthd.conf" >&2 || true
    echo "=== kyth-plymouth: plymouthd.defaults ($(wc -c < "${initdir}/usr/share/plymouth/plymouthd.defaults" 2>/dev/null || echo MISSING) bytes) ===" >&2
    cat "${initdir}/usr/share/plymouth/plymouthd.defaults" >&2 || true
    ln -sfn kyth/kyth.plymouth \
        "${initdir}/usr/share/plymouth/themes/default.plymouth"
    rm -rf \
        "${initdir}/usr/share/plymouth/themes/bgrt-fedora" \
        "${initdir}/usr/share/plymouth/themes/bgrt"
    inst_libdir_file "plymouth/script.so"
    inst_multiple \
        /usr/share/plymouth/themes/kyth/kyth.plymouth \
        /usr/share/plymouth/themes/kyth/kyth.script \
        /usr/share/plymouth/themes/kyth/kyth-logo.png
    inst_multiple -o \
        /etc/os-release \
        /usr/lib/os-release
}
KYTHPLYMOUTHEOF
chmod 0755 "${kyth_plymouth_dracut_dir}/module-setup.sh"

mkdir -p /etc/dracut.conf.d
if [[ -f /etc/dracut.conf.d/99-kyth.conf ]]; then
	if ! grep -q 'kyth-plymouth' /etc/dracut.conf.d/99-kyth.conf; then
		sed -i 's/add_dracutmodules+="\([^"]*\)"/add_dracutmodules+="\1 kyth-plymouth"/' \
			/etc/dracut.conf.d/99-kyth.conf
		grep -q 'kyth-plymouth' /etc/dracut.conf.d/99-kyth.conf ||
			printf '\nadd_dracutmodules+=" kyth-plymouth "\n' >>/etc/dracut.conf.d/99-kyth.conf
	fi
else
	cat >/etc/dracut.conf.d/99-kyth.conf <<'DRACUTEOF'
add_dracutmodules+=" ostree drm plymouth kyth-plymouth "
DRACUTEOF
fi
