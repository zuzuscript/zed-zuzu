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
	if grep -A60 '"zuzu": {' "$index" | grep -q '"snippets":'; then
		warn "Zed extension index still has Zuzu snippet metadata; reload or reinstall the dev extension"
	else
		check "Zed extension index has no Zuzu snippet metadata"
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
