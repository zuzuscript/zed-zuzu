#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grammar="${TREE_SITTER_ZUZU_DIR:-"$root/../tree-sitter-zuzu"}"
parser="$grammar/node_modules/.bin/tree-sitter"
sample="$grammar/examples/smoke.zzs"

require_line() {
	local file="$1"
	local pattern="$2"

	if ! grep -Eq "$pattern" "$file"; then
		printf 'Missing expected pattern in %s: %s\n' "$file" "$pattern" >&2
		exit 1
	fi
}

require_line "$root/extension.toml" '^id = "zuzu"$'
require_line "$root/extension.toml" '^schema_version = 1$'
require_line "$root/extension.toml" '^languages = \["languages/zuzu"\]$'
require_line "$root/extension.toml" '^\[lib\]$'
require_line "$root/extension.toml" '^kind = "Rust"$'
require_line "$root/extension.toml" '^version = "0\.7\.0"$'
require_line "$root/extension.toml" '^\[grammars\.zuzu\]$'
require_line "$root/extension.toml" '^repository = "https://github\.com/zuzuscript/tree-sitter-zuzu"$'
require_line "$root/extension.toml" '^rev = "[0-9a-f]{40}"$'
require_line "$root/extension.toml" '^\[language_servers\.zuzu-lsp\]$'
require_line "$root/extension.toml" '^name = "Zuzu LSP"$'
require_line "$root/extension.toml" '^languages = \["ZuzuScript"\]$'
require_line "$root/extension.toml" '^\[language_servers\.zuzu-lsp\.language_ids\]$'
require_line "$root/extension.toml" '^ZuzuScript = "zuzu"$'

pinned_rev="$(sed -n 's/^rev = "\([0-9a-f]\{40\}\)"$/\1/p' "$root/extension.toml")"
grammar_head="$(git -C "$grammar" rev-parse HEAD)"

if [[ "$pinned_rev" != "$grammar_head" ]]; then
	printf 'Pinned grammar rev does not match %s HEAD:\n' "$grammar" >&2
	printf '  extension.toml: %s\n' "$pinned_rev" >&2
	printf '  grammar HEAD:   %s\n' "$grammar_head" >&2
	exit 1
fi

require_line "$root/languages/zuzu/config.toml" '^name = "ZuzuScript"$'
require_line "$root/languages/zuzu/config.toml" '^grammar = "zuzu"$'
require_line "$root/languages/zuzu/config.toml" '^path_suffixes = \["zzs", "zzm"\]$'
require_line "$root/languages/zuzu/config.toml" '^block_comment = \{ start = "/\*", prefix = " ", end = " \*/", tab_size = 0 \}$'
require_line "$root/languages/zuzu/config.toml" '^first_line_pattern = "\^#!\.\*\\\\bzuzu\\\\b"$'
require_line "$root/languages/zuzu/config.toml" '^brackets = \[$'
require_line "$root/languages/zuzu/runnables.scm" 'tag zuzu-script'
require_line "$root/languages/zuzu/runnables.scm" 'tag zuzu-entrypoint'
require_line "$root/languages/zuzu/runnables.scm" 'tag zuzu-test'

node -e '
const snippets = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
for (const key of ["zscript", "zmodule", "zfn", "zclass", "zcclass", "ztrait", "ztest", "zimport", "ztryimport", "zpod"]) {
	if (typeof snippets[key] !== "string") {
		throw new Error(`missing string snippet: ${key}`);
	}
}
' "$root/snippets/zuzuscript.json"

for query in "$root"/languages/zuzu/*.scm; do
	printf 'Checking %s\n' "${query#$root/}"
	(cd "$grammar" && "$parser" query "$query" "$sample" >/tmp/zed-zuzu-query-check.out)
done

cmp -s "$root/languages/zuzu/highlights.scm" "$grammar/queries/highlights.scm"
cmp -s "$root/languages/zuzu/indents.scm" "$grammar/queries/indents.scm"
cmp -s "$root/languages/zuzu/injections.scm" "$grammar/queries/injections.scm"

printf 'Zed extension checks passed\n'
