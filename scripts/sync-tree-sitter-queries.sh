#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grammar="${TREE_SITTER_ZUZU_DIR:-"$root/../tree-sitter-zuzu"}"
language_dir="$root/languages/zuzu"

for query in highlights indents injections; do
	cp "$grammar/queries/$query.scm" "$language_dir/$query.scm"
done
