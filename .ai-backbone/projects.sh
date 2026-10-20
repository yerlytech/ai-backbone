#!/usr/bin/env bash
# Every project built on this backbone, at a glance. Run: just projects
# Looks one and two folders up from the backbone for repos that carry
# .ai-backbone/core.just, and any folder named in brain/project-roots.txt
# (one path a line, never committed). Read-only, always: a project is updated
# from inside, by the agent working in it, when `just session-start` there
# says it is behind.
# Until 3.20.0 this also had an `update` mode that did it from out here; the
# Justfile says why it went.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
mine=$(grep -m1 -oE 'version [0-9.]+' "$root/.ai-backbone/core.just" | awk '{print $2}')
printf "  %-14s %-9s %-8s %-7s %-11s %-9s %s\n" project backbone unsaved github "last save" upstream note
found=0
seen=" "
missing=0

one() {
  local d="$1"
  [ -d "$d" ] || return 0
  [ -f "$d/.ai-backbone/core.just" ] || return 0
  d=$(cd "$d" && pwd -P)
  [ "$d" = "$root" ] && return 0
  case " $seen " in *" $d "*) return 0 ;; esac
  seen="$seen$d "
  local v name unsaved remote last up behind note cache read_up
  v=$(grep -m1 -oE 'version [0-9.]+' "$d/.ai-backbone/core.just" | awk '{print $2}')
  found=$((found + 1))
  name=$(basename "$d")
  if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    unsaved=$(git -C "$d" status --short 2>/dev/null | wc -l | tr -d ' ')
    remote=$(git -C "$d" remote get-url origin >/dev/null 2>&1 && echo yes || echo none)
    last=$(git -C "$d" log -1 --format=%cs 2>/dev/null); last="${last:--}"
  else
    unsaved="-"; remote="-"; last="no git"
  fi
  # What the project's own daily check last found newer than its pins, read
  # from the cache it left (spec 026): no network, nothing asked. "-" for a
  # project with no watch list or no check yet.
  # "-" too when python3 cannot read it (a stand-in python3 on Windows).
  up="-"; behind=""
  cache=$(git -C "$d" rev-parse --git-path upstream-cache.json 2>/dev/null || true)
  case "$cache" in ""|/*) ;; *) cache="$d/$cache" ;; esac
  if [ -f "$d/docs/upstream.toml" ] && [ -n "$cache" ] && [ -f "$cache" ]; then
    read_up=$(python3 -c 'import json, sys; b = json.load(open(sys.argv[1])).get("behind", []); print(str(len(b)) + "\t" + ", ".join(b))' "$cache" 2>/dev/null || true)
    case "$read_up" in
      0*) up="current" ;;
      [1-9]*) up="${read_up%%$'\t'*} newer"; behind="${read_up#*$'\t'}" ;;
    esac
  fi
  note=""
  [ "$v" != "$mine" ] && note="${note:+$note; }behind, $mine here -> just template-update"
  [ "$unsaved" != 0 ] && [ "$unsaved" != "-" ] && note="${note:+$note; }unsaved work"
  [ "$remote" = none ] && note="${note:+$note; }only on this machine"
  [ -n "$behind" ] && note="${note:+$note; }newer upstream: $behind"
  printf "  %-14s %-9s %-8s %-7s %-11s %-9s %s\n" "$name" "$v" "$unsaved" "$remote" "$last" "$up" "$note"
}

for d in "$root"/../*/ "$root"/../*/*/; do
  one "$d"
done

# Machine-local roots (spec 033). A missing path is said; a path that is the
# same folder as one already listed is not listed twice. The list is private.
roots="$root/brain/project-roots.txt"
if [ -n "${AI_BACKBONE_PROJECT_ROOTS:-}" ]; then roots="$AI_BACKBONE_PROJECT_ROOTS"; fi
if [ -f "$roots" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ""|\#*) continue ;; esac
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    if [ ! -d "$line" ]; then echo "  missing root: $line"; missing=$((missing + 1)); continue; fi
    line=$(cd "$line" && pwd -P)
    one "$line"
    for d in "$line"/*/ "$line"/*/*/; do one "$d"; done
  done < "$roots"
fi

echo
if [ "$found" -eq 0 ]; then echo "No projects found next to the backbone."; else echo "$found project(s). Backbone here: $mine."; fi
if [ "$missing" -gt 0 ]; then echo "$missing root(s) named in the local list are not there."; fi
