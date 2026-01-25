# Ralph (Copilot CLI runner)

> Let AI implement your features while you sleep.

Ralph runs **GitHub Copilot CLI** in a loop, implementing one feature at a time until your PRD is complete.

[Quick Start](#quick-start) · [How It Works](#how-it-works) · [Configuration](#configuration) · [Command Reference](#command-reference) · [Demo](#demo)


---

## Quick Start

```bash
# Clone and enter the repo
git clone https://github.com/soderlind/ralph
cd ralph

# Add your work items to plans/prd.json

# Test with a single iteration
./ralph.py --allow-profile safe --max-iterations 1

# Run multiple iterations (iterative mode - RECOMMENDED)
./ralph.py --allow-profile safe --allow-dirty --max-iterations 10
```

Check `progress.txt` for a log of what was done.

---

## How It Works

Ralph implements the ["Ralph Wiggum" technique](https://www.humanlayer.dev/blog/brief-history-of-ralph):

1. **Read** — Copilot reads your PRD (if attached) and progress file
2. **Pick** — It chooses the highest-priority incomplete item
3. **Implement** — It writes code for that one feature
4. **Verify** — It runs your tests (`pnpm typecheck`, `pnpm test`)
5. **Update** — It marks the item complete and logs progress
6. **Commit** — It commits the changes
7. **Repeat** — Until all items pass or it signals completion

### Learn More

- [Matt Pocock's thread](https://x.com/mattpocockuk/status/2007924876548637089)
- [Ship working code while you sleep (video)](https://www.youtube.com/watch?v=_IK18goX4X8)
- [11 Tips For AI Coding With Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum)
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Ralph Loop Implementation (Python reference)](https://gist.github.com/soderlind/ca83ba5417e3d9e25b68c7bdc644832c) — Detailed example of state management, test orchestration, and PRD-driven iteration

---

## Configuration

### Choose a Model

Set the `MODEL` environment variable (default: `gpt-5.2`):

```bash
MODEL=claude-opus-4.5 ./ralph.py --allow-profile safe --max-iterations 10
```

### Define Your Work Items

Create `plans/prd.json` with your requirements:

```json
[
  {
    "category": "functional",
    "description": "User can send a message and see it in the conversation",
    "steps": ["Open chat", "Type message", "Click Send", "Verify it appears"],
    "passes": false
  }
]
```

| Field         | Description                                |
|---------------|--------------------------------------------|
| `category`    | `"functional"`, `"ui"`, or custom          |
| `description` | One-line summary                           |
| `steps`       | How to verify it works                     |
| `passes`      | `false` → `true` when complete             |

See the [`plans/`](plans/) folder for more context.

### Use Custom Prompts

Prompts can be customized via `--prompt-prefix`:

```bash
./ralph.py --prompt-prefix prompts/my-prompt.txt --allow-profile safe --max-iterations 10
```

> **Note:** Custom tools require `--allow-profile` or `--allow-tools`.

---

## Command Reference

### `ralph.py` — Looped Runner

Runs Copilot up to N iterations. Stops early on `<promise>COMPLETE</promise>`.

```bash
./ralph.py [options]
```

**Examples:**

```bash
./ralph.py --allow-profile safe --max-iterations 10
./ralph.py --allow-profile safe --allow-dirty --max-iterations 10
./ralph.py --once --allow-profile safe
./ralph.py --prompt-prefix prompts/custom.txt --allow-profile safe --max-iterations 10
MODEL=claude-opus-4.5 ./ralph.py --allow-profile safe --max-iterations 10
```

### Options

| Option                   | Description                          | Default               |
|--------------------------|--------------------------------------|-----------------------|
| `--once`                 | Single iteration mode                | Loop mode             |
| `--allow-dirty`          | Allow uncommitted changes (iterative)| Clean repo enforced   |
| `--prompt-prefix <file>` | Load custom prompt prefix            | Built-in prompt       |
| `--prd <file>`           | Path to PRD JSON file                | `plans/prd.json`      |
| `--max-iterations <n>`   | Maximum iterations (loop mode)       | 10                    |
| `--allow-profile <name>` | Permission profile (see below)       | —                     |
| `--allow-tools <spec>`   | Allow specific tool (repeatable)     | —                     |
| `--deny-tools <spec>`    | Deny specific tool (repeatable)      | —                     |
| `-h, --help`             | Show help                            | —                     |

**Environment:**

| Variable | Description        | Default   |
|----------|--------------------|-----------|
| `MODEL`  | Model to use       | `gpt-5.2` |

### Permission Profiles

| Profile  | Allows                                 | Use Case                     |
|----------|----------------------------------------|------------------------------|
| `locked` | `write` only                           | File edits, no shell         |
| `safe`   | `write`, `shell(pnpm:*)`, `shell(git:*)` | Normal dev workflow        |
| `dev`    | All tools                              | Broad shell access           |

**Always denied:** `shell(rm)`, `shell(git push)`

**Custom tools:** If you pass `--allow-tools`, it replaces the profile defaults:

```bash
./ralph.py --allow-tools write --allow-tools 'shell(composer:*)' --allow-profile safe --max-iterations 10
```

---

## Demo

Try Ralph in a safe sandbox:

```bash
# Setup
git clone https://github.com/soderlind/ralph && cd ralph
git worktree add ../ralph-demo -b ralph-demo
cd ../ralph-demo

# Run
./ralph.py --allow-profile safe --max-iterations 1
./ralph.py --allow-profile safe --allow-dirty --max-iterations 10

# Inspect
git log --oneline -20
cat progress.txt

# Cleanup
cd .. && git worktree remove ralph-demo && git branch -D ralph-demo
```

---

## Project Structure

```
.
├── plans/prd.json        # Your work items
├── prompts/default.txt   # Example prompt
├── progress.txt          # Running log
├── ralph.py              # Main runner (Python)
├── .ralph/state.json     # Iteration state
└── test/                 # Test harness
```

---

## Install Copilot CLI

```bash
# Check version
copilot --version

# Homebrew
brew update && brew upgrade copilot

# npm
npm i -g @github/copilot

# Windows
winget upgrade GitHub.Copilot
```

---

## Testing Prompts

Run all prompts in isolated worktrees:

```bash
./test/run-prompts.sh
```

Logs: `test/log/`

---

## PRD-Driven State Management

Ralph uses a **PRD-first architecture** inspired by the [Ralph Loop reference implementation](https://gist.github.com/soderlind/ca83ba5417e3d9e25b68c7bdc644832c):

### State Persistence

Three files track the workflow:

| File | Purpose |
|------|---------|
| `plans/prd.json` | **Source of truth** — your requirements, marked `passes: true/false` |
| `progress.txt` | **Append-only log** — what was built, why, and what failed |
| `.ralph/state.json` | **Resume metadata** — iteration count, last run, PRD hash |

### Feature Lifecycle

Each iteration:

1. **Read** — Load PRD, check which features are incomplete (`passes: false`)
2. **Pick** — Select highest-priority incomplete feature by ID and priority
3. **Implement** — Copilot builds the feature based on `description`, `details`, and `steps`
4. **Test** — Run commands from `prd.json` feature's `tests` array (if provided)
5. **Update** — Mark feature `passes: true`, append notes to progress.txt
6. **Commit** — Auto-commit with feature ID in message (e.g., `[arch-001] Setup TypeScript`)
7. **Repeat** — Loop until `passes: true` for all features or max-iterations reached

### Example: Test Inheritance

Features with `dependsOn` ensure previous work stays validated:

```json
{
  "id": "auth-001",
  "steps": [
    "Create login page",
    "Build /api/auth/login",
    "Ensure: pnpm test passes (runs arch-001 + data-001 + auth-001 tests)"
  ],
  "dependsOn": ["arch-001", "data-001"]
}
```

When Ralph implements `auth-001`, it runs **all** tests — ensuring architecture and data models still work.

### Why This Matters

- **No lost context** — progress.txt keeps human-readable transcript
- **Resume-safe** — state.json lets you pause and continue later
- **Test integrity** — old tests keep passing as new features layer on
- **Clear git history** — commits reference PRD feature IDs

---

## Copilot CLI Notes

Ralph is a Python-based wrapper around the Copilot CLI. The important flags it relies on are:

### Context attachment

Ralph passes context to Copilot via inline prompts. Ralph builds context per iteration that typically contains:

- `progress.txt` (always)
- PRD JSON (only if you pass `--prd <file>`)
- Custom prompt prefix (if `--prompt-prefix <file>` is provided)

This keeps the agent's input structured and clean.

### Tool permissions (`--allow-*` / `--deny-*`)

Ralph controls what Copilot is allowed to do by passing tool permission flags:

- `--allow-profile <safe|dev|locked>`: convenience presets implemented by Ralph.
- `--allow-tools <spec>`: allow a specific tool spec (repeatable). When you use this, it replaces the profile defaults.
- `--deny-tools <spec>`: deny a specific tool spec (repeatable).

For shell tools, prefer the pattern form `shell(cmd:*)` (for example `shell(git:*)`).

Ralph always denies a small set of dangerous commands (currently `shell(rm)` and `shell(git push)`).




## License

MIT — see [LICENSE](LICENSE).
