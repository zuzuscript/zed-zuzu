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
wasm="$root/extension.wasm"
wasm_builder="$root/scripts/build-extension-wasm.sh"
repair_index=false
clear_wasm=false
failed=false

for arg in "$@"; do
	case "$arg" in
		--repair-index)
			repair_index=true
			;;
		--clear-wasm)
			clear_wasm=true
			;;
		--rebuild-wasm)
			clear_wasm=true
			;;
		--repair-cache)
			repair_index=true
			clear_wasm=true
			;;
		-h|--help)
			printf 'Usage: %s [--repair-index] [--rebuild-wasm] [--clear-wasm] [--repair-cache]\n' "$0"
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
	failed=true
	printf 'fail: %s\n' "$1"
}

build_wasm() {
	if [[ ! -x "$wasm_builder" ]]; then
		fail "extension wasm builder is missing or not executable: $wasm_builder"
		return
	fi
	if output="$("$wasm_builder" 2>&1)"; then
		check "rebuilt extension wasm"
		printf '%s\n' "$output"
	else
		fail "failed to rebuild extension wasm: $output"
	fi
}

check_lsp_capabilities() {
	python3 - "$lsp" "$root" <<'PY'
import json
import pathlib
import select
import subprocess
import sys
import tempfile
import time

lsp, root = sys.argv[1], sys.argv[2]


def send(process, message):
    body = json.dumps(message).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    process.stdin.write(header + body)
    process.stdin.flush()


def read_message(process):
    deadline = time.monotonic() + 5
    header = b""
    while b"\r\n\r\n" not in header:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("timed out waiting for LSP response headers")
        ready, _, _ = select.select([process.stdout], [], [], remaining)
        if not ready:
            raise TimeoutError("timed out waiting for LSP response headers")
        chunk = process.stdout.read(1)
        if not chunk:
            stderr = process.stderr.read().decode("utf-8", "replace")
            raise RuntimeError(f"LSP exited before responding: {stderr}")
        header += chunk

    headers = header.decode("ascii", "replace").split("\r\n")
    length = None
    for line in headers:
        if line.lower().startswith("content-length:"):
            length = int(line.split(":", 1)[1].strip())
            break
    if length is None:
        raise RuntimeError("LSP response omitted Content-Length")

    body = process.stdout.read(length)
    if len(body) != length:
        raise RuntimeError("LSP response body was truncated")
    return json.loads(body)


def read_response(process, expected_id):
    while True:
        message = read_message(process)
        if message.get("id") == expected_id:
            return message


process = subprocess.Popen(
    [lsp, "--stdio"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    cwd=root,
    bufsize=0,
)

workspace = None
try:
    workspace = tempfile.TemporaryDirectory(prefix="zed-zuzu-lsp-smoke-")
    workspace_path = pathlib.Path(workspace.name)
    workspace_uri = workspace_path.as_uri()
    module_path = workspace_path / "modules" / "demo" / "tools.zzm"
    script_path = workspace_path / "scripts" / "main.zzs"
    module_text = "class Thing;\n"
    script_text = (
        "from demo/tools import Thing;\n"
        "function __main__() {\n"
        "\tlet item := Thing;\n"
        "}\n"
    )
    module_path.parent.mkdir(parents=True)
    script_path.parent.mkdir(parents=True)
    module_path.write_text(module_text, encoding="utf-8")
    script_path.write_text(script_text, encoding="utf-8")
    send(
        process,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "processId": None,
                "rootUri": workspace_uri,
                "capabilities": {},
            },
        },
    )
    response = read_response(process, 1)
    capabilities = response.get("result", {}).get("capabilities", {})
    required = {
        "callHierarchyProvider": lambda value: value is True,
        "codeActionProvider": lambda value: isinstance(value, dict) or value is True,
        "codeLensProvider": lambda value: isinstance(value, dict),
        "completionProvider": lambda value: isinstance(value, dict),
        "definitionProvider": lambda value: value is True,
        "diagnosticProvider": lambda value: isinstance(value, dict),
        "documentFormattingProvider": lambda value: value is True,
        "documentHighlightProvider": lambda value: value is True,
        "documentLinkProvider": lambda value: isinstance(value, dict),
        "documentSymbolProvider": lambda value: value is True,
        "executeCommandProvider": lambda value: isinstance(value, dict),
        "foldingRangeProvider": lambda value: value is True or isinstance(value, dict),
        "hoverProvider": lambda value: value is True,
        "inlayHintProvider": lambda value: isinstance(value, dict),
        "referencesProvider": lambda value: value is True,
        "renameProvider": lambda value: isinstance(value, dict) or value is True,
        "semanticTokensProvider": lambda value: isinstance(value, dict),
        "selectionRangeProvider": lambda value: value is True,
        "signatureHelpProvider": lambda value: isinstance(value, dict),
        "typeHierarchyProvider": lambda value: value is True,
        "workspaceSymbolProvider": lambda value: value is True,
    }
    missing = [
        name
        for name, predicate in required.items()
        if not predicate(capabilities.get(name))
    ]
    workspace_capabilities = capabilities.get("workspace", {})
    workspace_folders = workspace_capabilities.get("workspaceFolders", {})
    if workspace_folders.get("supported") is not True:
        missing.append("workspace.workspaceFolders.supported")
    if missing:
        print("missing LSP capabilities: " + ", ".join(missing))
        sys.exit(1)
    send(process, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
    for version, path, text in (
        (1, module_path, module_text),
        (1, script_path, script_text),
    ):
        send(
            process,
            {
                "jsonrpc": "2.0",
                "method": "textDocument/didOpen",
                "params": {
                    "textDocument": {
                        "uri": path.as_uri(),
                        "languageId": "zuzu",
                        "version": version,
                        "text": text,
                    }
                },
            },
        )
    send(
        process,
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "textDocument/definition",
            "params": {
                "textDocument": {"uri": script_path.as_uri()},
                "position": {"line": 2, "character": 14},
            },
        },
    )
    definition = read_response(process, 2)
    target = definition.get("result", {}).get("uri", "")
    if not target.endswith("/modules/demo/tools.zzm"):
        print(f"go to definition returned unexpected target: {target!r}")
        sys.exit(1)
    print(", ".join(sorted(required.keys())) + ", workspace folders, go to definition")
finally:
    if workspace is not None:
        try:
            workspace.cleanup()
        except Exception:
            pass
    if process.stdin:
        try:
            send(process, {"jsonrpc": "2.0", "id": 3, "method": "shutdown"})
            read_response(process, 3)
            send(process, {"jsonrpc": "2.0", "method": "exit"})
        except Exception:
            pass
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.terminate()
PY
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

if $clear_wasm; then
	build_wasm
elif [[ -f "$wasm" ]]; then
	if [[ "$wasm" -ot "$root/src/lib.rs" || "$wasm" -ot "$root/extension.toml" || "$wasm" -ot "$root/Cargo.toml" ]]; then
		warn "compiled extension wasm is older than the source or manifest: $wasm"
		warn "run $0 --rebuild-wasm, then reload Zed, to rebuild it"
	elif strings "$wasm" | grep -q '../zuzu-lsp/target/debug'; then
		warn "compiled extension wasm still contains the old ../zuzu-lsp lookup message"
		warn "run $0 --rebuild-wasm, then reload Zed, to rebuild it"
	else
		check "compiled extension wasm is not older than the main source files"
	fi
else
	warn "compiled extension wasm is absent; Zed needs this file to load the Rust extension"
	warn "run $0 --rebuild-wasm, then reload Zed, to build it"
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
	if capabilities="$(check_lsp_capabilities 2>&1)"; then
		check "local zuzu-lsp handles editor features: $capabilities"
	else
		fail "local zuzu-lsp capability smoke test failed: $capabilities"
	fi
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
	if grep -q '../zuzu-lsp/target/debug' "$log"; then
		warn "Zed log contains the old ../zuzu-lsp error text from a stale extension build"
		warn "run $0 --rebuild-wasm, then reload Zed, if that error is still appearing"
	fi
else
	warn "Zed log not found: $log"
fi

if $failed; then
	exit 1
fi
