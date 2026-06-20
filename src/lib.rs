use std::path::{Path, PathBuf};

use zed_extension_api::{
    self as zed,
    lsp::{Completion, CompletionKind, Symbol, SymbolKind},
    CodeLabel, CodeLabelSpan, LanguageServerId, Result, Worktree,
};

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
                "{LANGUAGE_SERVER_ID} was not found. Configure `lsp.{LANGUAGE_SERVER_ID}.binary.path`, install it on PATH, or build zuzu-lsp/target/debug/{LANGUAGE_SERVER_ID} in this workspace or an ancestor workspace for local development."
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

    fn label_for_completion(
        &self,
        language_server_id: &LanguageServerId,
        completion: Completion,
    ) -> Option<CodeLabel> {
        if ensure_zuzu_lsp(language_server_id).is_err() {
            return None;
        }

        let kind = completion.kind?;
        match kind {
            CompletionKind::Keyword => simple_code_label(&completion.label),
            CompletionKind::Function => declaration_label("function", &completion.label),
            CompletionKind::Method => declaration_label("method", &completion.label),
            CompletionKind::Constructor | CompletionKind::Class | CompletionKind::Struct => {
                class_label(&completion.label)
            }
            CompletionKind::Module => module_label(&completion.label),
            CompletionKind::Variable | CompletionKind::Field | CompletionKind::Property => {
                variable_label("let", &completion.label)
            }
            CompletionKind::Constant | CompletionKind::EnumMember => {
                variable_label("const", &completion.label)
            }
            CompletionKind::Operator => simple_code_label(&completion.label),
            _ => None,
        }
    }

    fn label_for_symbol(
        &self,
        language_server_id: &LanguageServerId,
        symbol: Symbol,
    ) -> Option<CodeLabel> {
        if ensure_zuzu_lsp(language_server_id).is_err() {
            return None;
        }

        match symbol.kind {
            SymbolKind::Function => declaration_label("function", &symbol.name),
            SymbolKind::Method | SymbolKind::Constructor => {
                declaration_label("method", &symbol.name)
            }
            SymbolKind::Class | SymbolKind::Struct | SymbolKind::Interface => {
                class_label(&symbol.name)
            }
            SymbolKind::Module | SymbolKind::Namespace | SymbolKind::Package => {
                module_label(&symbol.name)
            }
            SymbolKind::Variable | SymbolKind::Field | SymbolKind::Property => {
                variable_label("let", &symbol.name)
            }
            SymbolKind::Constant | SymbolKind::EnumMember => variable_label("const", &symbol.name),
            _ => simple_code_label(&symbol.name),
        }
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
    let mut current = Some(Path::new(&root_path));

    while let Some(root) = current {
        for candidate in development_server_candidates(root) {
            if candidate.is_file() {
                return Some(candidate.display().to_string());
            }
        }
        current = root.parent();
    }

    None
}

fn development_server_candidates(root: &Path) -> Vec<PathBuf> {
    let mut candidates = Vec::new();
    for executable in [LANGUAGE_SERVER_ID, "zuzu-lsp.exe"] {
        candidates.push(root.join("target").join("debug").join(executable));
        candidates.push(
            root.join(LANGUAGE_SERVER_ID)
                .join("target")
                .join("debug")
                .join(executable),
        );
    }
    candidates
}

fn simple_code_label(label: &str) -> Option<CodeLabel> {
    if label.is_empty() {
        return None;
    }

    Some(CodeLabel {
        code: label.to_string(),
        spans: vec![CodeLabelSpan::code_range(0..label.len())],
        filter_range: (0..label.len()).into(),
    })
}

fn declaration_label(keyword: &str, name: &str) -> Option<CodeLabel> {
    if !is_zuzu_word(name) {
        return None;
    }

    let code = format!("{keyword} {name} () {{}}");
    let display_end = keyword.len() + 1 + name.len();
    let name_start = keyword.len() + 1;
    Some(CodeLabel {
        code,
        spans: vec![CodeLabelSpan::code_range(0..display_end)],
        filter_range: (name_start..display_end).into(),
    })
}

fn class_label(name: &str) -> Option<CodeLabel> {
    if !is_zuzu_word(name) {
        return None;
    }

    let code = format!("class {name};");
    let display_end = "class ".len() + name.len();
    Some(CodeLabel {
        code,
        spans: vec![CodeLabelSpan::code_range(0..display_end)],
        filter_range: ("class ".len()..display_end).into(),
    })
}

fn variable_label(keyword: &str, name: &str) -> Option<CodeLabel> {
    if !is_zuzu_word(name) {
        return None;
    }

    let code = format!("{keyword} {name};");
    let display_end = keyword.len() + 1 + name.len();
    let name_start = keyword.len() + 1;
    Some(CodeLabel {
        code,
        spans: vec![CodeLabelSpan::code_range(0..display_end)],
        filter_range: (name_start..display_end).into(),
    })
}

fn module_label(module: &str) -> Option<CodeLabel> {
    if !is_zuzu_module_path(module) {
        return None;
    }

    let code = format!("from {module} import Symbol;");
    let start = "from ".len();
    let end = start + module.len();
    Some(CodeLabel {
        code,
        spans: vec![CodeLabelSpan::code_range(start..end)],
        filter_range: (start..end).into(),
    })
}

fn is_zuzu_module_path(module: &str) -> bool {
    !module.is_empty() && module.split('/').all(is_zuzu_word)
}

fn is_zuzu_word(word: &str) -> bool {
    let mut chars = word.chars();
    let Some(first) = chars.next() else {
        return false;
    };

    if first.is_ascii_digit() || !is_zuzu_word_char(first) {
        return false;
    }

    chars.all(is_zuzu_word_char)
}

fn is_zuzu_word_char(ch: char) -> bool {
    ch == '_' || ch.is_alphanumeric()
}

zed::register_extension!(ZuzuExtension);
