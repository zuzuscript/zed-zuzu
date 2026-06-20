# ZuzuScript for Zed

This is the Zed language extension for ZuzuScript.

Current scope:

- registers `tree-sitter-zuzu` as the ZuzuScript grammar;
- recognises `.zzs`, `.zzm`, and extensionless files with a `zuzu` shebang;
- provides highlighting, indentation, POD injections, bracket matching, outline
  entries, text objects, comment/string overrides, and basic runnable markers;
- provides practical snippets for scripts, modules, declarations, imports,
  tests, and POD;
- launches `zuzu-lsp --stdio` when the language server is available.

## Local Development

The extension pins the published grammar repository:

```toml
[grammars.zuzu]
repository = "https://github.com/zuzuscript/tree-sitter-zuzu"
rev = "0ad04a355bd94954830d01f23bfa69822995e23c"
```

For local grammar development, set `TREE_SITTER_ZUZU_DIR` when running the
extension checks or query sync script. The manifest should keep pointing at the
published grammar repository so a dev extension checkout is not tied to one
machine's filesystem layout.

Shared query files are copied from `tree-sitter-zuzu`:

```sh
scripts/sync-tree-sitter-queries.sh
```

Zed-specific query files live in `languages/zuzu/` and should remain small.

Snippets are registered from `./snippets/zuzuscript.json`; the filename matches
Zed's lowercase language-name convention for `ZuzuScript`.

## Language Server

The extension starts `zuzu-lsp --stdio` for ZuzuScript buffers. It resolves the
server in this order:

1. `lsp.zuzu-lsp.binary.path` from Zed settings.
2. `zuzu-lsp` on Zed's PATH.
3. `../zuzu-lsp/target/debug/zuzu-lsp` relative to the `zed-zuzu` worktree for
   local umbrella-checkout development.

Example Zed settings:

```json
{
  "lsp": {
    "zuzu-lsp": {
      "binary": {
        "path": "/home/tai/src/zuzuscript/zuzu-lsp/target/debug/zuzu-lsp",
        "arguments": ["--stdio"],
        "env": {
          "ZUZU_STDLIB": "/custom/zuzu/stdlib"
        }
      },
      "initialization_options": {
        "zuzu": {
          "moduleRoots": ["vendor/modules"],
          "runtimeParserDiagnostics": true
        }
      },
      "settings": {
        "zuzu": {
          "moduleRoots": ["vendor/modules"],
          "runtimeParserDiagnostics": true
        }
      }
    }
  }
}
```

If custom binary arguments omit `--stdio`, the extension appends it so Zed still
starts the server over the LSP stdio transport.

The extension maps Zed's `ZuzuScript` language to the LSP language id `zuzu`.
That keeps untitled ZuzuScript buffers and extensionless shebang scripts on the
same document-classification path as `.zzs` and `.zzm` files.
