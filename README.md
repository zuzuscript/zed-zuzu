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
rev = "8593148756686092d0ac547ae868fca5d1b604a3"
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

The language server advertises editor features including hover, completions,
signature help, document symbols, workspace symbols, go to definition,
references, document highlights, rename, document links, diagnostics, code
actions, code lenses, folding ranges, selection ranges, inlay hints,
call/type hierarchy, and semantic tokens.

Zed requests semantic tokens only when enabled in settings. To combine
tree-sitter highlighting with Zuzu LSP semantic tokens, use:

```json
{
  "languages": {
    "ZuzuScript": {
      "semantic_tokens": "combined"
    }
  }
}
```

For local testing, check Zed's inherited PATH if the log says `zuzu-lsp` was
not found. Desktop-launched Zed may not inherit the same shell PATH as a
terminal. A local symlink is often enough:

```sh
ln -sfn /home/tai/src/zuzuscript/zuzu-lsp/target/debug/zuzu-lsp ~/.local/bin/zuzu-lsp
```

After changing `extension.toml`, restart Zed or reinstall the dev extension if
`~/.local/share/zed/extensions/index.json` still shows stale metadata.
If Zed reports older error text after source changes, rebuild the generated
`extension.wasm` component and reload Zed:

```sh
scripts/build-extension-wasm.sh
```

The build script requires `wasm-tools` on PATH:

```sh
cargo install wasm-tools --locked
```

It fetches the WASI preview1 component adapter crate automatically when the
adapter is not already present in the local Cargo registry.

This helper checks the common local failure modes:

```sh
scripts/doctor-dev-extension.sh
```

It verifies the dev-extension symlink, generated Zed caches, local grammar
cache, local `zuzu-lsp` startup, advertised LSP capabilities, and a real
go-to-definition request across a temporary workspace module.
With `--rebuild-wasm`, it rebuilds a missing or stale `extension.wasm`.
With `--repair-grammar`, it updates the generated grammar checkout to the
pinned revision. With `--repair-cache`, it repairs generated index metadata,
rebuilds a missing or stale `extension.wasm`, and updates a stale generated
grammar checkout.

Zed will not start language servers in an untrusted worktree. If the log says
`Waiting for worktree ... before starting language server zuzu-lsp`, trust the
worktree from Zed's Restricted Mode prompt or set `session.trust_all_worktrees`
only in a disposable test profile.

To smoke test the extension through Zed itself, including the compiled wasm and
the LSP launch path, run:

```sh
scripts/smoke-zed-extension.sh
```

The smoke test creates an isolated Zed profile, enables `trust_all_worktrees`
inside that temporary profile, opens a small ZuzuScript fixture, and checks
Zed's log for `zuzu-lsp --stdio` startup.

If it reports stale Zuzu snippet metadata in Zed's generated extension index,
clear that cache entry with:

```sh
scripts/doctor-dev-extension.sh --repair-index
```

To clear both known generated caches in one step, run:

```sh
scripts/doctor-dev-extension.sh --repair-cache
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
