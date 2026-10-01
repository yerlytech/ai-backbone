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
# One assistant turn can start several agents at once, and the hook runs once
# per call, concurrently: twelve at a time all read "0 started" and all passed
# (measured in review). So the count is taken under a lock, one call at a time;
# a lock left by a call that died is waited out for two seconds and then taken.
i=0; until mkdir "$dir/lock" 2>/dev/null; do i=$((i+1)); [ "$i" -gt 100 ] && break; sleep 0.02; done
trap 'rmdir "$dir/lock" 2>/dev/null' EXIT
cap=$( [ -f "$dir/cap" ] && tr -d ' \n\r' < "$dir/cap" )
[ -n "$cap" ] || cap="${AI_BACKBONE_AGENT_CAP:-}"
# The day's number, as the session's first line said it (budget.py writes it):
# what the person reads is what holds, and it is never above their own setting.
[ -n "$cap" ] || { [ -f "${tmp%/}/ai-backbone-agents/today-cap" ] && cap=$(tr -d ' \n\r' < "${tmp%/}/ai-backbone-agents/today-cap"); }
[ -n "$cap" ] || cap=$(git config --global --get ai-backbone.agent-cap 2>/dev/null || true)
case "$cap" in ""|*[!0-9]*|???????*) cap=8 ;; esac
n=0; [ -f "$dir/started" ] && n=$(wc -l < "$dir/started" | tr -d ' ')
if [ "$(field tool_name)" = "Workflow" ]; then
  [ -f "$dir/cap" ] && exit 0
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AGENT CAP: a workflow starts many subagents on its own (%s started this session, cap %s). Stop and ask the person, saying roughly how many agents it would run; only if they say yes, run: just _agent-cap <cap> %s and launch it again."}}\n' "$n" "$cap" "$dir"
  exit 0
fi
if [ "$n" -ge "$cap" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AGENT CAP: %s subagents already started this session and the cap is %s. Stop and ask the person before starting more; only if they say yes, run: just _agent-cap <cap> %s (for every session on this machine: git config --global ai-backbone.agent-cap <cap>)."}}\n' "$n" "$cap" "$dir"
  exit 0
fi
id=$(field tool_use_id); grep -qxF "$id" "$dir/started" 2>/dev/null || printf '%s\n' "$id" >> "$dir/started"
exit 0
