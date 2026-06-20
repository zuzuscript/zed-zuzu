#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extension_id="zuzu"
zed_data="${XDG_DATA_HOME:-"$HOME/.local/share"}/zed"
installed="$zed_data/extensions/installed/$extension_id"
index="$zed_data/extensions/index.json"
log="$zed_data/logs/Zed.log"
lsp="$root/../zuzu-lsp/target/debug/zuzu-lsp"
grammar="$root/grammars/zuzu"
repair_index=false

for arg in "$@"; do
	case "$arg" in
		--repair-index)
			repair_index=true
			;;
		-h|--help)
			printf 'Usage: %s [--repair-index]\n' "$0"
			exit 0
			;;
		*)
			printf 'Unknown argument: %s\n' "$arg" >&2
			exit 2
			;;
	esac
done

check() {
	printf 'ok: %s\n' "$1"
}

warn() {
	printf 'warn: %s\n' "$1"
}

fail() {
	printf 'fail: %s\n' "$1"
}

printf 'Zed Zuzu dev-extension doctor\n'
printf 'repo: %s\n' "$root"

if [[ -L "$installed" ]]; then
	target="$(readlink "$installed")"
	if [[ "$target" == "$root" ]]; then
		check "installed dev extension points at this checkout"
	else
		warn "installed dev extension points at $target"
	fi
elif [[ -e "$installed" ]]; then
	warn "installed extension exists but is not a symlink: $installed"
else
	fail "dev extension is not installed at $installed"
fi

if [[ -f "$index" ]]; then
	snippets_value="$(
		python3 - "$index" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)

manifest = data.get("extensions", {}).get("zuzu", {}).get("manifest", {})
value = manifest.get("snippets")
if value is None:
    print("null")
else:
    print(value)
PY
	)"
	if [[ "$snippets_value" == "null" ]]; then
		check "Zed extension index has no active Zuzu snippet metadata"
	else
		warn "Zed extension index still has Zuzu snippet metadata: $snippets_value"
		if $repair_index && ! grep -Eq '^snippets =' "$root/extension.toml"; then
			cp "$index" "$index.zuzu-doctor.bak"
			python3 - "$index" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

data["extensions"]["zuzu"]["manifest"]["snippets"] = None

with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
			check "repaired Zed extension index; backup written to $index.zuzu-doctor.bak"
		elif $repair_index; then
			warn "not repairing index because extension.toml still registers snippets"
		else
			warn "run $0 --repair-index, then reload Zed, to clear this generated cache entry"
		fi
	fi
else
	warn "Zed extension index not found: $index"
fi

if [[ -x "$lsp" ]]; then
	check "local zuzu-lsp exists: $lsp"
else
	fail "local zuzu-lsp is missing; run cargo build in ../zuzu-lsp"
fi

if command -v zuzu-lsp >/dev/null 2>&1; then
	check "zuzu-lsp is on this shell PATH: $(command -v zuzu-lsp)"
else
	warn "zuzu-lsp is not on this shell PATH"
fi

while IFS= read -r pid; do
	[[ -r "/proc/$pid/environ" ]] || continue
	path="$(
		tr '\0' '\n' <"/proc/$pid/environ" |
			sed -n 's/^PATH=//p' |
			head -n 1
	)"
	printf 'Zed PID %s PATH: %s\n' "$pid" "$path"
	if [[ ":$path:" == *":$HOME/.local/bin:"* ]]; then
		check "Zed PATH includes ~/.local/bin"
	else
		warn "Zed PATH does not include ~/.local/bin"
	fi
done < <(pgrep -f 'zed-editor' || true)

if [[ -d "$grammar/.git" ]]; then
	remote="$(git -C "$grammar" remote get-url origin 2>/dev/null || true)"
	rev="$(git -C "$grammar" rev-parse HEAD 2>/dev/null || true)"
	pinned="$(sed -n 's/^rev = "\([0-9a-f]\{40\}\)"$/\1/p' "$root/extension.toml")"
	if [[ "$remote" == "https://github.com/zuzuscript/tree-sitter-zuzu" ]]; then
		check "grammar cache origin is $remote"
	else
		warn "grammar cache origin is $remote"
	fi
	if [[ "$rev" == "$pinned" ]]; then
		check "grammar cache matches pinned rev"
	else
		warn "grammar cache rev $rev does not match pinned rev $pinned"
	fi
elif [[ -e "$grammar" ]]; then
	warn "grammar cache exists but is not a git clone: $grammar"
else
	check "grammar cache is absent; Zed will clone it on reload"
fi

if [[ -f "$log" ]]; then
	printf 'Recent Zed Zuzu-related log lines:\n'
	grep -E 'zuzu|ZuzuScript|invalid type|language not found' "$log" | tail -20 || true
else
	warn "Zed log not found: $log"
fi
