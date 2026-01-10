# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-01-10

### Added
- `CHANGELOG.md`.
- `RALPH_VERSION="1.0.0"` in the runner scripts.
- `prompts/pest-coverage.txt`.
- Harness support for running `pest-coverage.txt` without a PRD.

### Changed
- `ralph.sh` / `ralph-once.sh`: `--prompt` is required (no implicit default prompt).
- `ralph.sh` / `ralph-once.sh`: `--prd` is optional and only attached when explicitly provided.
- Normalized shell tool allow/deny specs to the pattern form `shell(cmd:*)`.
- Prevented emitting empty tool spec arguments (avoids `--allow-tool ''` / `--deny-tool ''`).
- `test/run-prompts.sh`: runs prompts in isolated git worktrees and captures Copilot output via pseudo-TTY transcript.

### Documentation
- Updated README usage/examples to reflect `--prompt` required and `--prd` optional.
- Added per-prompt examples in `prompts/README.md`.
