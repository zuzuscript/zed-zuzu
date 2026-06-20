use std::path::Path;

use zed_extension_api::{self as zed, LanguageServerId, Result, Worktree};

const LANGUAGE_SERVER_ID: &str = "zuzu-lsp";

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
        ensure_zuzu_lsp(language_server_id)?;

        let settings = zed::settings::LspSettings::for_worktree(LANGUAGE_SERVER_ID, worktree)?;
        let command = configured_binary_path(&settings)
            .or_else(|| worktree.which(LANGUAGE_SERVER_ID))
            .or_else(|| development_server_path(worktree));

        let Some(command) = command else {
            return Err(format!(
                "{LANGUAGE_SERVER_ID} was not found. Configure `lsp.{LANGUAGE_SERVER_ID}.binary.path`, install it on PATH, or build ../zuzu-lsp/target/debug/{LANGUAGE_SERVER_ID} for local development."
            ));
        };

        Ok(zed::Command {
            command,
            args: command_arguments(&settings),
            env: command_environment(&settings, worktree),
        })
    }

    fn language_server_initialization_options(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<Option<zed::serde_json::Value>> {
        ensure_zuzu_lsp(language_server_id)?;
        let settings = zed::settings::LspSettings::for_worktree(LANGUAGE_SERVER_ID, worktree)?;
        Ok(settings.initialization_options)
    }

    fn language_server_workspace_configuration(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<Option<zed::serde_json::Value>> {
        ensure_zuzu_lsp(language_server_id)?;
        let settings = zed::settings::LspSettings::for_worktree(LANGUAGE_SERVER_ID, worktree)?;
        Ok(settings.settings)
    }
}

fn ensure_zuzu_lsp(language_server_id: &LanguageServerId) -> Result<()> {
    if language_server_id.as_ref() == LANGUAGE_SERVER_ID {
        return Ok(());
    }
    Err(format!(
        "unsupported ZuzuScript language server: {language_server_id}"
    ))
}

fn configured_binary_path(settings: &zed::settings::LspSettings) -> Option<String> {
    settings
        .binary
        .as_ref()
        .and_then(|binary| binary.path.as_ref())
        .filter(|path| !path.trim().is_empty())
        .cloned()
}

fn command_arguments(settings: &zed::settings::LspSettings) -> Vec<String> {
    let mut args = settings
        .binary
        .as_ref()
        .and_then(|binary| binary.arguments.clone())
        .unwrap_or_default();
    if !args.iter().any(|arg| arg == "--stdio") {
        args.push("--stdio".to_string());
    }
    args
}

fn command_environment(settings: &zed::settings::LspSettings, worktree: &Worktree) -> zed::EnvVars {
    let shell_env = worktree.shell_env();
    let mut env = Vec::new();

    for key in ["PATH", "HOME", "USERPROFILE", "ZUZULIB", "ZUZU_STDLIB"] {
        if let Some((_, value)) = shell_env.iter().find(|(name, _)| name == key) {
            env.push((key.to_string(), value.clone()));
        }
    }

    if let Some(binary) = &settings.binary {
        if let Some(extra_env) = &binary.env {
            for (key, value) in extra_env {
                upsert_env(&mut env, key, value);
            }
        }
    }

    env
}

fn upsert_env(env: &mut zed::EnvVars, key: &str, value: &str) {
    if let Some((_, existing)) = env.iter_mut().find(|(name, _)| name == key) {
        *existing = value.to_string();
    } else {
        env.push((key.to_string(), value.to_string()));
    }
}

fn development_server_path(worktree: &Worktree) -> Option<String> {
    let root_path = worktree.root_path();
    let worktree_root = Path::new(&root_path);
    let candidate = worktree_root
        .parent()?
        .join(LANGUAGE_SERVER_ID)
        .join("target")
        .join("debug")
        .join(LANGUAGE_SERVER_ID);

    candidate.is_file().then(|| candidate.display().to_string())
}

zed::register_extension!(ZuzuExtension);
