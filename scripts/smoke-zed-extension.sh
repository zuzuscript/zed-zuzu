#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timeout_seconds="${ZED_ZUZU_SMOKE_TIMEOUT:-25}"
tmpdir="$(mktemp -d /tmp/zed-zuzu-smoke.XXXXXX)"
workspace="$tmpdir/workspace"
log="$tmpdir/logs/Zed.log"

cleanup() {
	if [[ "${KEEP_ZED_ZUZU_SMOKE:-0}" != 1 ]]; then
		rm -rf "$tmpdir"
	else
		printf 'Kept smoke profile: %s\n' "$tmpdir"
	fi
}
trap cleanup EXIT

fail() {
	printf 'fail: %s\n' "$1" >&2
	if [[ -f "$log" ]]; then
		printf 'Interesting Zed log lines:\n' >&2
		grep -E 'zuzu|ZuzuScript|language server|worktree|extension wasm|Failed to load extension|failed to compile wasm' "$log" >&2 || true
	fi
	exit 1
}

if ! command -v zed >/dev/null 2>&1; then
	fail "zed is not on PATH"
fi

if [[ ! -f "$root/extension.wasm" ]]; then
	fail "extension.wasm is missing; run scripts/build-extension-wasm.sh first"
fi

mkdir -p "$tmpdir/extensions/installed" "$tmpdir/config" \
	"$workspace/modules/demo" "$workspace/scripts"
ln -sfn "$root" "$tmpdir/extensions/installed/zuzu"

cat >"$tmpdir/config/settings.json" <<'JSON'
{
  "session": {
    "trust_all_worktrees": true
  },
  "languages": {
    "ZuzuScript": {
      "semantic_tokens": "combined"
    }
  }
}
JSON

printf 'class Thing;\n' >"$workspace/modules/demo/tools.zzm"
printf 'from demo/tools import Thing;\nfunction __main__() {\n\tlet item := Thing;\n}\n' >"$workspace/scripts/main.zzs"

timeout "$timeout_seconds"s zed \
	--foreground \
	--user-data-dir "$tmpdir" \
	"$workspace/scripts/main.zzs" \
	>"$tmpdir/stdout.log" \
	2>"$tmpdir/stderr.log" || true

if [[ ! -f "$log" ]]; then
	fail "Zed did not write a log file"
fi

if grep -Eq 'Failed to load extension: zuzu|failed to compile wasm|opening wasm file' "$log"; then
	fail "Zed failed to load the Zuzu extension wasm"
fi

if grep -Eq 'Waiting for worktree ".+" to be trusted, before starting language server zuzu-lsp' "$log"; then
	fail "Zed did not apply trust_all_worktrees in the isolated smoke profile"
fi

if ! grep -Eq 'starting language server process\. binary path: ".*/zuzu-lsp", working directory: ".+", args: \["--stdio"\]' "$log"; then
	fail "Zed did not start zuzu-lsp through the extension"
fi

printf 'ok: Zed loaded the extension and started zuzu-lsp\n'
