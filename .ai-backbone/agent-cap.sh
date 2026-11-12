#!/usr/bin/env bash
# PreToolUse hook on the Agent and Workflow tools: how many subagents one session
# may start on its own (spec 014). Claude Code feeds one line of JSON on stdin
# and reads the JSON this prints (measured on 2.1.273). The count lives in a temp
# folder keyed by session_id, so every session starts at zero and two sessions
# never share it. The cap comes from, in this order: the session's own cap file
# (what the person's "yes" writes, through `just _agent-cap`), the environment
# (AI_BACKBONE_AGENT_CAP), `git config --global ai-backbone.agent-cap`, and 8 when
# none is set. A call past the cap is refused with a reason the agent reads, and
# the model then asks the person (measured: it did, and did not retry). A refused
# call is not counted, so a lifted cap counts right. A workflow starts its agents
# itself, past this hook, so its launch is gated by the same yes. bash 3.2 and BSD
# tools only, no Python: this runs on every Agent call, in about 25 ms.
set -u
in=$(cat 2>/dev/null || true)
field() { printf '%s' "$in" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }
sid=$(field session_id)
case "$sid" in ""|.|..|*[!A-Za-z0-9._-]*) exit 0 ;; esac    # no usable id: neither count nor block
tmp="${TMPDIR:-/tmp}"; dir="${tmp%/}/ai-backbone-agents/$sid"
mkdir -p "$dir" 2>/dev/null || exit 0
# The cap is resolved before the lock. git config is the slow call, and holding
# the lock across it made the waiters give up (ubuntu-latest, 2026-11-11).
cap=$( [ -f "$dir/cap" ] && tr -d ' \n\r' < "$dir/cap" )
[ -n "$cap" ] || cap="${AI_BACKBONE_AGENT_CAP:-}"
# The day's number, as the session's first line said it (budget.py writes it):
# what the person reads is what holds, and it is never above their own setting.
[ -n "$cap" ] || { [ -f "${tmp%/}/ai-backbone-agents/today-cap" ] && cap=$(tr -d ' \n\r' < "${tmp%/}/ai-backbone-agents/today-cap"); }
[ -n "$cap" ] || cap=$(git config --global --get ai-backbone.agent-cap 2>/dev/null || true)
case "$cap" in ""|*[!0-9]*|???????*) cap=8 ;; esac
tool=$(field tool_name)
id=$(field tool_use_id)
# One assistant turn can start several agents at once, and the hook runs once
# per call, concurrently: twelve at a time all read "0 started" and all passed
# (measured in review). The count is taken under a lock. A dead holder's lock
# is taken; a live one is waited for. A call that never gets the lock is
# refused and not counted. Giving the lock up after two seconds, and removing
# it on the way out, let a slow runner admit more than eight.
owned=0
release_lock() {
  [ "${owned:-0}" = 1 ] || return 0
  [ -n "${dir:-}" ] || return 0
  pid=$(tr -d ' \n\r' < "$dir/lock/pid" 2>/dev/null || true)
  [ "$pid" = "$$" ] || return 0
  rm -rf "$dir/lock" 2>/dev/null || true
}
trap release_lock EXIT
empty_for=0
waited=0
while [ "$owned" -eq 0 ]; do
  if mkdir "$dir/lock" 2>/dev/null; then
    if printf '%s\n' "$$" > "$dir/lock/pid"; then owned=1; break; fi
    rm -rf "$dir/lock" 2>/dev/null || true
  fi
  holder=$(tr -d ' \n\r' < "$dir/lock/pid" 2>/dev/null || true)
  case "$holder" in
    ""|*[!0-9]*)
      empty_for=$((empty_for + 1))
      if [ "$empty_for" -gt 100 ]; then
        rm -rf "$dir/lock" 2>/dev/null || true
        empty_for=0
      fi
      ;;
    *)
      empty_for=0
      if ! kill -0 "$holder" 2>/dev/null; then
        now=$(tr -d ' \n\r' < "$dir/lock/pid" 2>/dev/null || true)
        if [ "$now" = "$holder" ]; then rm -rf "$dir/lock" 2>/dev/null || true; fi
      fi
      ;;
  esac
  waited=$((waited + 1))
  if [ "$waited" -gt 1000 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AGENT CAP: could not take the lock for this session (cap %s). Stop and try the agent again."}}\n' "$cap"
    exit 0
  fi
  sleep 0.02
done
n=0; [ -f "$dir/started" ] && n=$(wc -l < "$dir/started" | tr -d ' ')
if [ "$tool" = "Workflow" ]; then
  [ -f "$dir/cap" ] && exit 0
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AGENT CAP: a workflow starts many subagents on its own (%s started this session, cap %s). Stop and ask the person, saying roughly how many agents it would run; a mode they turned on is not a yes to a count. Only if they say yes to that number, run: just _agent-cap <cap> %s and launch it again."}}\n' "$n" "$cap" "$dir"
  exit 0
fi
if [ "$n" -ge "$cap" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AGENT CAP: %s subagents already started this session and the cap is %s. Stop and ask the person, saying how many more and why; a mode they turned on is not a yes to a count. Only if they say yes to that number, run: just _agent-cap <cap> %s (for every session on this machine: git config --global ai-backbone.agent-cap <cap>)."}}\n' "$n" "$cap" "$dir"
  exit 0
fi
grep -qxF "$id" "$dir/started" 2>/dev/null || printf '%s\n' "$id" >> "$dir/started"
exit 0
