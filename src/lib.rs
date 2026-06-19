use std::path::Path;

use zed_extension_api::{self as zed, LanguageServerId, Result, Worktree};

struct ZuzuExtension;

impl zed::Extension for ZuzuExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<zed::Command> {
        if language_server_id.as_ref() != "zuzu-lsp" {
            return Err(format!(
                "unsupported ZuzuScript language server: {language_server_id}"
            ));
        }

        let command = worktree
            .which("zuzu-lsp")
            .or_else(|| development_server_path(worktree));

        let Some(command) = command else {
            return Err(
				"zuzu-lsp was not found on PATH. Build or install zuzu-lsp and ensure it is visible to Zed."
					.to_string(),
			);
        };

        Ok(zed::Command {
            command,
            args: vec!["--stdio".to_string()],
            env: worktree.shell_env(),
        })
    }
}

fn development_server_path(worktree: &Worktree) -> Option<String> {
    let root_path = worktree.root_path();
    let worktree_root = Path::new(&root_path);
    let candidate = worktree_root
        .parent()?
        .join("zuzu-lsp")
        .join("target")
        .join("debug")
        .join("zuzu-lsp");

    candidate.is_file().then(|| candidate.display().to_string())
}

zed::register_extension!(ZuzuExtension);
