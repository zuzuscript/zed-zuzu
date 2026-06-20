# ZuzuScript for Zed

This is the Zed language extension for ZuzuScript.

Current scope:

- registers `tree-sitter-zuzu` as the ZuzuScript grammar;
- recognises `.zzs`, `.zzm`, and extensionless files with a `zuzu` shebang;
- provides highlighting, indentation, POD injections, bracket matching,
  folding, outline entries, text objects, comment/string overrides, literal
  redactions, and basic runnable markers;
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

`snippets/zuzuscript.json` is kept as a candidate snippet set, but it is not
registered in `extension.toml` until the extension-host snippet schema is
settled. Snippet registration errors should not block language or LSP loading.

## Language Server

The extension starts `zuzu-lsp --stdio` for ZuzuScript buffers. It resolves the
server in this order:

1. `lsp.zuzu-lsp.binary.path` from Zed settings.
2. `zuzu-lsp` on Zed's PATH.
3. `target/debug/zuzu-lsp` or `zuzu-lsp/target/debug/zuzu-lsp` under the open
   worktree or one of its ancestors for local umbrella-checkout development.
4. `zuzu-lsp/target/debug/zuzu-lsp` under `$HOME/src/zuzuscript`, `$HOME/src`,
   or `$HOME` for local dev-extension checkouts.

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

For local testing, check Zed's inherited PATH if the log says `zuzu-lsp` was
not found. Desktop-launched Zed may not inherit the same shell PATH as a
terminal. A local symlink is often enough:

```sh
ln -sfn /home/tai/src/zuzuscript/zuzu-lsp/target/debug/zuzu-lsp ~/.local/bin/zuzu-lsp
```

After changing `extension.toml`, restart Zed or reinstall the dev extension if
`~/.local/share/zed/extensions/index.json` still shows stale metadata.

This helper checks the common local failure modes:

```sh
scripts/doctor-dev-extension.sh
```

## Runnable Tasks

The extension marks three Tree-sitter runnable tags:

- `zuzu-script` for files with a Zuzu shebang;
- `zuzu-entrypoint` for `function __main__()`;
- `zuzu-test` for ztest files with a top-level `plan(...)` call.

Bind those tags in `.zed/tasks.json` or your global Zed tasks:

```json
[
  {
    "label": "Run Zuzu script",
    "command": "zuzu",
    "args": ["$ZED_FILE"],
    "tags": ["zuzu-script", "zuzu-entrypoint"]
  },
  {
    "label": "Run Zuzu test",
    "command": "zuzuprove",
    "args": ["$ZED_FILE"],
    "tags": ["zuzu-test"]
  }
]
```
