#!/usr/bin/env bash
# Every project built on this backbone, at a glance. Run: just projects
# Looks one and two folders up from the backbone for repos that carry
# .ai-backbone/core.just. Read-only, always: a project is updated from inside,
# by the agent working in it, when `just session-start` there says it is behind.
# Until 3.20.0 this also had an `update` mode that did it from out here; the
# Justfile says why it went.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
mine=$(grep -m1 -oE 'version [0-9.]+' "$root/.ai-backbone/core.just" | awk '{print $2}')
printf "  %-14s %-9s %-8s %-7s %-11s %s\n" project backbone unsaved github "last save" note
found=0
for d in "$root"/../*/ "$root"/../*/*/; do
  d="${d%/}"
  [ -d "$d" ] || continue
  [ "$(cd "$d" && pwd -P)" = "$root" ] && continue
  if [ -f "$d/.ai-backbone/core.just" ]; then
    v=$(grep -m1 -oE 'version [0-9.]+' "$d/.ai-backbone/core.just" | awk '{print $2}')
  else
    continue
  fi
  found=$((found+1))
  name=$(basename "$d")
  if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    unsaved=$(git -C "$d" status --short 2>/dev/null | wc -l | tr -d ' ')
    remote=$(git -C "$d" remote get-url origin >/dev/null 2>&1 && echo yes || echo none)
    last=$(git -C "$d" log -1 --format=%cs 2>/dev/null); last="${last:--}"
  else
    unsaved="-"; remote="-"; last="no git"
  fi
  note=""
  [ "$v" != "$mine" ] && note="${note:+$note; }behind, $mine here -> just template-update"
  [ "$unsaved" != 0 ] && [ "$unsaved" != "-" ] && note="${note:+$note; }unsaved work"
  [ "$remote" = none ] && note="${note:+$note; }only on this machine"
  printf "  %-14s %-9s %-8s %-7s %-11s %s\n" "$name" "$v" "$unsaved" "$remote" "$last" "$note"
done
echo
if [ "$found" -eq 0 ]; then echo "No projects found next to the backbone."; else echo "$found project(s). Backbone here: $mine."; fi
