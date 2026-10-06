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
printf "  %-14s %-9s %-8s %-7s %-11s %-9s %s\n" project backbone unsaved github "last save" upstream note
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
  # What the project's own weekly check last found newer than its pins, read
  # from the cache it left (spec 026): no network, nothing asked. "-" for a
  # project with no watch list or no check yet.
  up="-"; behind=""
  cache=$(git -C "$d" rev-parse --git-path upstream-cache.json 2>/dev/null || true)
  case "$cache" in ""|/*) ;; *) cache="$d/$cache" ;; esac
  if [ -f "$d/docs/upstream.toml" ] && [ -n "$cache" ] && [ -f "$cache" ]; then
    behind=$(python3 -c 'import json, sys; print(" ".join(json.load(open(sys.argv[1])).get("behind", [])))' "$cache" 2>/dev/null || true)
    if [ -n "$behind" ]; then up="$(wc -w <<< "$behind" | tr -d ' ') newer"; else up="current"; fi
  fi
  note=""
  [ "$v" != "$mine" ] && note="${note:+$note; }behind, $mine here -> just template-update"
  [ "$unsaved" != 0 ] && [ "$unsaved" != "-" ] && note="${note:+$note; }unsaved work"
  [ "$remote" = none ] && note="${note:+$note; }only on this machine"
  [ -n "$behind" ] && note="${note:+$note; }newer upstream: ${behind// /, }"
  printf "  %-14s %-9s %-8s %-7s %-11s %-9s %s\n" "$name" "$v" "$unsaved" "$remote" "$last" "$up" "$note"
done
echo
if [ "$found" -eq 0 ]; then echo "No projects found next to the backbone."; else echo "$found project(s). Backbone here: $mine."; fi
