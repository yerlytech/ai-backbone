#!/usr/bin/env sh
# Run this repository's routine with whichever agent this machine has.
#
# The scheduler calls this; this calls an agent. Which agent is not the
# backbone's business, so the command lives in one table below and can be
# replaced entirely with AI_AGENT_CMD. Nothing here knows what the routine says:
# that is `.ai-backbone/routine.md` in the backbone, `.ai-backbone/routine-project.md`
# in a project.
#
#   sh .ai-backbone/routine.sh            run the routine now
#   sh .ai-backbone/routine.sh --which    say which agent would be used, run nothing
#   sh .ai-backbone/routine.sh --brief    say which brief would be read, run nothing
#
# AI_AGENT_CMD is a command line with {prompt} where the prompt goes:
#   AI_AGENT_CMD='mytool run --quiet {prompt}'
set -u

# launchd gives a process almost no PATH, so the usual places are named here.
PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root" || exit 1

# The backbone carries its own brief; a project gets the template, which is
# its brief until somebody edits it — and editing it is the point.
brief=""
for candidate in .ai-backbone/routine.md .ai-backbone/routine-project.md \
                 .ai-backbone/templates/routine-project.md; do
  if [ -f "$candidate" ]; then brief="$candidate"; break; fi
done
if [ -z "$brief" ]; then
  echo "No routine brief in .ai-backbone/. Nothing to run." >&2
  exit 1
fi

# The scheduler recipe asks here rather than looking again, so there is one
# answer to "which brief" and it cannot drift between the two.
if [ "${1:-}" = "--brief" ]; then
  echo "$brief"
  exit 0
fi

# Every agent that can take a prompt and work on its own. Verified entries run
# as written; the rest are a best guess and are checked before a schedule is
# installed, so a wrong line is found on the day it is set up rather than in
# six weeks of silence. Correct one with AI_AGENT_CMD.
agent_command() {
  case "$1" in
    # Verified.
    claude) echo 'claude -p {prompt} --permission-mode acceptEdits' ;;
    opencode) echo 'opencode run {prompt}' ;;
    # Believed. If one of these is wrong on your machine, `just routine-install`
    # will say so rather than installing a schedule that does nothing.
    gemini) echo 'gemini -p {prompt}' ;;
    codex) echo 'codex exec {prompt}' ;;
    crush) echo 'crush run {prompt}' ;;
    cursor-agent) echo 'cursor-agent -p {prompt}' ;;
    amp) echo 'amp -x {prompt}' ;;
    *) echo "" ;;
  esac
}

# The first one installed wins, unless AI_AGENT_CMD says otherwise.
chosen=""
template="${AI_AGENT_CMD:-}"
if [ -z "$template" ]; then
  for candidate in claude opencode gemini codex crush cursor-agent amp; do
    if command -v "$candidate" >/dev/null 2>&1; then
      chosen="$candidate"
      template=$(agent_command "$candidate")
      break
    fi
  done
fi

# --which is a question, not an attempt, so it answers on a machine with no
# agent instead of failing: "which would you use" has a true answer there, and
# it is "none". Whoever acts on the answer decides what to do about it.
if [ "${1:-}" = "--which" ]; then
  if [ -z "$template" ]; then
    echo "none: no agent on this machine (looked for claude, opencode, gemini, codex, crush, cursor-agent, amp)."
    echo "      Install one, or say which to use: AI_AGENT_CMD='mytool run {prompt}'"
  else
    echo "${chosen:-AI_AGENT_CMD}: $template"
  fi
  exit 0
fi

if [ -z "$template" ]; then
  echo "No agent found on this machine (looked for claude, opencode, gemini, codex, crush, cursor-agent, amp)." >&2
  echo "Install one, or say which to use: AI_AGENT_CMD='mytool run {prompt}'" >&2
  exit 1
fi

# One run at a time. `mkdir` is the atomic test-and-set every shell has, and a
# lock inside .git is never committed and never in the way.
#
# The lock names the run that holds it. A run that dies outright (the power
# goes, the battery runs flat, kill -9) never gets to remove it, and a lock
# nobody holds would turn every later week into "already going" and nothing.
lock="$root/.git/ai-routine.lock"
holder_alive() {
  pid=$(cat "$lock/pid" 2>/dev/null) || return 1
  [ -n "$pid" ] || return 1
  # Git Bash has a ps that knows no -o: there it fails for a run that is alive,
  # and the lock was cleared under it (spec 020). A ps that cannot answer is
  # asked no further, and kill -0 decides, as on a machine with no ps.
  if out=$(ps -p "$pid" -o command= 2>/dev/null); then
    printf '%s\n' "$out" | grep -q routine
  else
    kill -0 "$pid" 2>/dev/null
  fi
}
if ! mkdir "$lock" 2>/dev/null; then
  # A run that has just made the lock may not have written its number yet.
  [ -s "$lock/pid" ] || sleep 1
  if holder_alive; then
    echo "== $(date '+%Y-%m-%d %H:%M') a run is already going here (process $pid); doing nothing"
    exit 0
  fi
  echo "== $(date '+%Y-%m-%d %H:%M') the last run stopped without clearing its lock; clearing it"
  rm -f "$lock/pid"
  rmdir "$lock" 2>/dev/null
  if ! mkdir "$lock" 2>/dev/null; then
    echo "== $(date '+%Y-%m-%d %H:%M') another run started at the same moment; doing nothing"
    exit 0
  fi
fi
echo "$$" > "$lock/pid"
trap 'rm -f "$lock/pid"; rmdir "$lock" 2>/dev/null' EXIT INT TERM

prompt=$(cat "$brief")
echo "== $(date '+%Y-%m-%d %H:%M') routine in $root with ${chosen:-AI_AGENT_CMD}"

# The prompt is passed as one argument, never interpolated into a shell string:
# a brief is a document and may hold quotes, backticks and dollars.
before="${template%%\{prompt\}*}"
after="${template#*\{prompt\}}"
# shellcheck disable=SC2086
set -- $before "$prompt" $after
"$@"
status=$?

echo "== $(date '+%Y-%m-%d %H:%M') routine finished, exit $status"
exit $status
