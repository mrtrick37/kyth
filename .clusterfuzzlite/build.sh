#!/bin/bash -eu

for fuzzer in "$SRC"/kyth/fuzz/*_fuzzer.py; do
  fuzzer_basename="$(basename -s .py "$fuzzer")"
  fuzzer_package="${fuzzer_basename}.pkg"
  pyinstaller \
    --distpath "$OUT" \
    --paths "$SRC/kyth/build_files/kyth-welcome" \
    --hidden-import kyth_welcome.core \
    --hidden-import kyth_welcome.page_vpn \
    --onefile \
    --name "$fuzzer_package" \
    "$fuzzer"
  cat >"$OUT/$fuzzer_basename" <<EOF
#!/bin/sh
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname "\$0")
PYTHONUTF8=1 "\$this_dir/$fuzzer_package" "\$@"
EOF
  chmod +x "$OUT/$fuzzer_basename"
done
