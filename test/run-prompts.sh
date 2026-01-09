#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  ./test/run-prompts.sh

What it does:
  - Finds all *.txt prompts in ./prompts
  - Creates a git worktree per prompt
  - Runs ./ralph-once.sh with that prompt inside the worktree
  - Logs stdout/stderr to ./test/log/<timestamp>/
  - Removes the worktree and its temp branch

Environment variables:
  MAIN_BRANCH   Base branch for worktrees (default: main)
  MODEL         Copilot model (default: gpt-5.2)
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: must run inside a git repository" >&2
  exit 1
}

MAIN_BRANCH="${MAIN_BRANCH:-main}"
MODEL="${MODEL:-gpt-5.2}"

# Prefer logging into the main-branch worktree if it exists; otherwise use current worktree.
LOG_ROOT="$ROOT"
if git -C "$ROOT" worktree list --porcelain | awk -v b="refs/heads/$MAIN_BRANCH" '
    $1=="worktree"{path=$2}
    $1=="branch" && $2==b{print path; exit}
  ' >/tmp/ralph-main-worktree-path.$$ 2>/dev/null; then
  MAIN_WT_PATH="$(cat /tmp/ralph-main-worktree-path.$$ || true)"
  rm -f /tmp/ralph-main-worktree-path.$$ || true
  if [[ -n "$MAIN_WT_PATH" ]]; then
    LOG_ROOT="$MAIN_WT_PATH"
  fi
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG_DIR="$LOG_ROOT/test/log/$TS"
mkdir -p "$RUN_LOG_DIR"

PROMPTS_DIR="$ROOT/prompts"
if [[ ! -d "$PROMPTS_DIR" ]]; then
  echo "Error: prompts folder not found at: $PROMPTS_DIR" >&2
  exit 1
fi

mapfile -t PROMPT_FILES < <(find "$PROMPTS_DIR" -maxdepth 1 -type f -name "*.txt" | sort)
if [[ ${#PROMPT_FILES[@]} -eq 0 ]]; then
  echo "Error: no prompt files found in $PROMPTS_DIR" >&2
  exit 1
fi

echo "Logging to: $RUN_LOG_DIR"

echo "prompt\tstatus\tworktree" >"$RUN_LOG_DIR/summary.tsv"

run_one_prompt() {
  local prompt_path="$1"
  local prompt_file
  local prompt_name
  local wt_dir
  local branch
  local log_file

  prompt_file="$(basename "$prompt_path")"
  prompt_name="${prompt_file%.txt}"

  wt_dir="$ROOT/test/worktrees/${TS}-${prompt_name}"
  branch="ralph-test/${TS}-${prompt_name}"
  log_file="$RUN_LOG_DIR/${prompt_name}.log"

  mkdir -p "$(dirname "$wt_dir")"

  # Ensure cleanup even if the copilot run fails.
  cleanup() {
    set +e
    git -C "$ROOT" worktree remove --force "$wt_dir" >/dev/null 2>&1 || true
    git -C "$ROOT" branch -D "$branch" >/dev/null 2>&1 || true
    git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
  }
  trap cleanup RETURN

  echo "==> [$prompt_name] creating worktree: $wt_dir" | tee -a "$log_file"
  git -C "$ROOT" worktree add -b "$branch" "$wt_dir" "$MAIN_BRANCH" >>"$log_file" 2>&1

  pushd "$wt_dir" >/dev/null

  # Prompt-specific tool policy (kept in the runner, not in prompt files).
  # Feel free to tweak these mappings as you add more prompts.
  declare -a args
  args=("--prompt" "prompts/$prompt_file")

  case "$prompt_file" in
    wordpress-plugin-agent.txt)
      args+=("--allow-profile" "safe")
      args+=("--allow-tools" "shell(npx)")
      args+=("--allow-tools" "shell(composer)")
      args+=("--allow-tools" "shell(npm)")
      ;;
    safe-write-only.txt)
      args+=("--allow-profile" "locked")
      ;;
    *)
      # Default prompt expects pnpm + git checks; safe profile already allows those.
      args+=("--allow-profile" "safe")
      ;;
  esac

  echo "==> [$prompt_name] running ralph-once.sh ${args[*]}" | tee -a "$log_file"

  set +e
  MODEL="$MODEL" ./ralph-once.sh "${args[@]}" >>"$log_file" 2>&1
  local status=$?
  set -e

  popd >/dev/null

  if [[ $status -eq 0 ]]; then
    echo -e "${prompt_file}\tPASS\t$wt_dir" >>"$RUN_LOG_DIR/summary.tsv"
  else
    echo -e "${prompt_file}\tFAIL($status)\t$wt_dir" >>"$RUN_LOG_DIR/summary.tsv"
  fi

  return 0
}

for p in "${PROMPT_FILES[@]}"; do
  run_one_prompt "$p" || true
done

echo "Done. Summary: $RUN_LOG_DIR/summary.tsv"
