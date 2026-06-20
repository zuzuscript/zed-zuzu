#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cargo_home="${CARGO_HOME:-"$HOME/.cargo"}"
adapter_version="45.0.2"
adapter_name="wasi_snapshot_preview1.reactor.wasm"

find_adapter() {
	if [[ -n "${WASI_PREVIEW1_ADAPTER:-}" && -f "$WASI_PREVIEW1_ADAPTER" ]]; then
		printf '%s\n' "$WASI_PREVIEW1_ADAPTER"
		return
	fi

	if [[ ! -d "$cargo_home/registry/src" ]]; then
		return
	fi

	find "$cargo_home/registry/src" \
		-path "*/wasi-preview1-component-adapter-provider-*/artefacts/$adapter_name" \
		-print 2>/dev/null |
		sort -V |
		tail -n 1
}

adapter="$(find_adapter)"
if [[ -z "$adapter" ]]; then
	tmpdir="$(mktemp -d /tmp/zed-zuzu-adapter.XXXXXX)"
	trap 'rm -rf "$tmpdir"' EXIT
	cat >"$tmpdir/Cargo.toml" <<TOML
[package]
name = "zed-zuzu-adapter-fetch"
version = "0.0.0"
edition = "2021"
publish = false

[dependencies]
wasi-preview1-component-adapter-provider = "$adapter_version"
TOML
	cargo fetch --manifest-path "$tmpdir/Cargo.toml" >/dev/null
	adapter="$(find_adapter)"
fi

if [[ -z "$adapter" ]]; then
	printf 'Unable to find %s. Set WASI_PREVIEW1_ADAPTER to its path.\n' "$adapter_name" >&2
	exit 1
fi

if ! command -v wasm-tools >/dev/null 2>&1; then
	printf 'Missing wasm-tools. Install it with: cargo install wasm-tools --locked\n' >&2
	exit 1
fi

cd "$root"
cargo build --target wasm32-wasip1
wasm-tools component new \
	target/wasm32-wasip1/debug/zed_zuzu.wasm \
	--adapt "wasi_snapshot_preview1=$adapter" \
	-o extension.wasm
wasm-tools validate extension.wasm
printf 'Wrote %s\n' "$root/extension.wasm"
