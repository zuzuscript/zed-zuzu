# ZuzuScript for Zed

This is the Zed language extension for ZuzuScript.

Current scope:

- registers `tree-sitter-zuzu` as the ZuzuScript grammar;
- recognises `.zzs`, `.zzm`, and extensionless files with a `zuzu` shebang;
- provides highlighting, indentation, POD injections, bracket matching, outline
  entries, text objects, and basic runnable markers;
- launches `zuzu-lsp --stdio` when the language server is available.

## Local Development

The extension currently pins the local grammar repository:

```toml
[grammars.zuzu]
repository = "file:///home/tai/src/zuzuscript/tree-sitter-zuzu"
rev = "79b72445e99c05f53bee808b46a60d7062b7b6c4"
```

For publishing, change `repository` to
`https://github.com/zuzulang/tree-sitter-zuzu` and pin `rev` to a published
commit SHA or tag.

Shared query files are copied from `tree-sitter-zuzu`:

```sh
scripts/sync-tree-sitter-queries.sh
```

Zed-specific query files live in `languages/zuzu/` and should remain small.

## Language Server

The extension first looks for `zuzu-lsp` on Zed's PATH. For local development in
the umbrella checkout, it also falls back to
`../zuzu-lsp/target/debug/zuzu-lsp` relative to the `zed-zuzu` worktree.
