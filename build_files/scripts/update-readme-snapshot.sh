#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
readme_path="$repo_root/README.md"
start_marker="<!-- AUTO-README-START -->"
end_marker="<!-- AUTO-README-END -->"

if [[ ! -f "$readme_path" ]]; then
    echo "README.md not found at $readme_path" >&2
    exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
head_short="$(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
last_subject="$(git log -1 --pretty=%s 2>/dev/null || echo 'No commits yet')"
last_when="$(git log -1 --date=iso-strict --pretty=%cd 2>/dev/null || echo n/a)"
now_utc="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
workflow_count="$(find "$repo_root/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ')"
script_count="$(find "$repo_root/build_files/scripts" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"

block_file="$(mktemp)"
tmp_file="$(mktemp)"
trap 'rm -f "$block_file" "$tmp_file"' EXIT

cat > "$block_file" <<EOF
## Auto Project Snapshot

- Last refreshed (UTC): $now_utc
- Current branch: $branch
- HEAD commit: $head_short
- Last commit title: $last_subject
- Last commit date: $last_when
- CI workflow files: $workflow_count
- Build script files: $script_count

EOF

if grep -q "$start_marker" "$readme_path" && grep -q "$end_marker" "$readme_path"; then
    awk -v start="$start_marker" -v end="$end_marker" -v repl="$block_file" '
        BEGIN { in_block = 0 }
        $0 == start {
            print
            while ((getline line < repl) > 0) {
                print line
            }
            close(repl)
            in_block = 1
            next
        }
        $0 == end {
            in_block = 0
            print
            next
        }
        !in_block {
            print
        }
    ' "$readme_path" > "$tmp_file"
else
    cat "$readme_path" > "$tmp_file"
    {
        echo
        echo "$start_marker"
        cat "$block_file"
        echo "$end_marker"
    } >> "$tmp_file"
fi

if ! cmp -s "$readme_path" "$tmp_file"; then
    cp "$tmp_file" "$readme_path"
    echo "README snapshot updated"
fi
