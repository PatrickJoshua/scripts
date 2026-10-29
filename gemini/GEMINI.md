# Global Preferences & Notes

## Git Operations in Non-Interactive Subprocesses
- **Authentication & Terminal Prompts**: Shell commands in CLI subagents run with terminal prompts disabled and CLI-injected environment overrides (`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=`).
- **Handling**: Stored credentials in `~/.git-credentials` can be used for HTTPS network operations (`push`/`pull`) by passing `-c credential.helper=store` (e.g. `git -c credential.helper=store push`). If credentials are not stored or interactive 2FA input is required, notify the user to execute directly in their terminal.
