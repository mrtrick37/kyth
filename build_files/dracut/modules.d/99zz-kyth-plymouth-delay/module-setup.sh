#!/usr/bin/bash

check() {
    return 0
}

depends() {
    echo kyth-plymouth
    return 0
}

install() {
    mkdir -p \
        "${initdir}/etc/plymouth" \
        "${initdir}/usr/share/plymouth"
    cat > "${initdir}/etc/plymouth/plymouthd.conf" <<'PLYMOUTHCONF'
[Daemon]
Theme=kyth
ShowDelay=1
PLYMOUTHCONF
    cat > "${initdir}/usr/share/plymouth/plymouthd.defaults" <<'PLYMOUTHDEFAULTS'
[Daemon]
Theme=kyth
ShowDelay=1
PLYMOUTHDEFAULTS
}
