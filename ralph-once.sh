#!/usr/bin/env bash
set -euo pipefail

usage() {
   cat <<USAGE
Usage:
   $0 [--prompt <file>] [--allow-profile <safe|dev|locked>] [--allow-tools <toolSpec> ...] [--deny-tools <toolSpec> ...]

Options:
   --prompt <file>           Load prompt text from file (otherwise use built-in default).
   --allow-profile <name>    Tool permission profile: safe | dev | locked.
   --allow-tools <toolSpec>  Allow a specific tool (repeatable). Example: --allow-tools write
                                          Use quotes if the spec includes spaces: --allow-tools 'shell(git push)'
   --deny-tools <toolSpec>   Deny a specific tool (repeatable). Example: --deny-tools 'shell(rm)'
   -h, --help                Show this help.

Notes:
   - If you use --prompt, you must also pass --allow-profile or at least one --allow-tools.
USAGE
}

prompt_file=""
allow_profile=""
declare -a allow_tools
declare -a deny_tools

while [[ $# -gt 0 ]]; do
   case "$1" in
      --prompt)
         shift
         if [[ $# -lt 1 || -z "${1:-}" ]]; then
            echo "Error: --prompt requires a file path" >&2
            usage
            exit 1
         fi
         prompt_file="$1"
         shift
         ;;
      --allow-profile)
         shift
         if [[ $# -lt 1 || -z "${1:-}" ]]; then
            echo "Error: --allow-profile requires a value" >&2
            usage
            exit 1
         fi
         allow_profile="$1"
         shift
         ;;
      --allow-tools)
         shift
         if [[ $# -lt 1 || -z "${1:-}" ]]; then
            echo "Error: --allow-tools requires a tool spec" >&2
            usage
            exit 1
         fi
         allow_tools+=("$1")
         shift
         ;;
      --deny-tools)
         shift
         if [[ $# -lt 1 || -z "${1:-}" ]]; then
            echo "Error: --deny-tools requires a tool spec" >&2
            usage
            exit 1
         fi
         deny_tools+=("$1")
         shift
         ;;
      -h|--help)
         usage
         exit 0
         ;;
      --)
         shift
         break
         ;;
      -*)
         echo "Error: unknown option: $1" >&2
         usage
         exit 1
         ;;
      *)
         break
         ;;
   esac
done

# Default model if not provided
MODEL="${MODEL:-gpt-5.2}"

PROMPT=$(
  cat <<'PROMPT'
Work in the current repo. Use these files as your source of truth:
- plans/prd.json
- progress.txt

1. Find the highest-priority feature to work on and work only on that feature.
   This should be the one YOU decide has the highest priority - not necessarily the first in the list.
2. Check that the types check via pnpm typecheck and that the tests pass via pnpm test.
3. Update the PRD with the work that was done (plans/prd.json).
4. Append your progress to progress.txt.
   Use this to leave a note for the next person working in the codebase.
5. Make a git commit of that feature.
ONLY WORK ON A SINGLE FEATURE.
If, while implementing the feature, you notice the PRD is complete, output <promise>COMPLETE</promise>.
PROMPT
)

if [[ -n "$prompt_file" ]]; then
   if [[ ! -r "$prompt_file" ]]; then
      echo "Error: prompt file not readable: $prompt_file" >&2
      exit 1
   fi
   PROMPT="$(cat "$prompt_file")"
fi

if [[ -n "$prompt_file" ]] && [[ -z "$allow_profile" ]] && [[ ${#allow_tools[@]} -eq 0 ]]; then
   echo "Error: when using --prompt, you must specify --allow-profile or at least one --allow-tools" >&2
   usage
   exit 1
fi

declare -a copilot_tool_args

# Always deny a small set of dangerous commands.
copilot_tool_args+=(--deny-tool 'shell(rm)')
copilot_tool_args+=(--deny-tool 'shell(git push)')

if [[ -n "$allow_profile" ]]; then
   case "$allow_profile" in
      dev)
         copilot_tool_args+=(--allow-all-tools)
         copilot_tool_args+=(--allow-tool 'write')
         copilot_tool_args+=(--allow-tool 'shell(pnpm)')
         copilot_tool_args+=(--allow-tool 'shell(git)')
         ;;
      safe)
         copilot_tool_args+=(--allow-tool 'write')
         copilot_tool_args+=(--allow-tool 'shell(pnpm)')
         copilot_tool_args+=(--allow-tool 'shell(git)')
         ;;
      locked)
         copilot_tool_args+=(--allow-tool 'write')
         ;;
      *)
         echo "Error: unknown --allow-profile: $allow_profile" >&2
         usage
         exit 1
         ;;
   esac
else
   # Preserve previous default behavior when not using a custom prompt.
   if [[ -z "$prompt_file" ]]; then
      copilot_tool_args+=(--allow-all-tools)
      copilot_tool_args+=(--allow-tool 'write')
      copilot_tool_args+=(--allow-tool 'shell(pnpm)')
      copilot_tool_args+=(--allow-tool 'shell(git)')
   fi
fi

for tool in "${allow_tools[@]:-}"; do
   copilot_tool_args+=(--allow-tool "$tool")
done

for tool in "${deny_tools[@]:-}"; do
   copilot_tool_args+=(--deny-tool "$tool")
done

copilot --model "$MODEL" \
  -p "@plans/prd.json @progress.txt $PROMPT" \
   "${copilot_tool_args[@]}"
