#!/usr/bin/env bash
# Second copies of brain/ for every sibling project on this machine (n-a931f8).
# `just vault-sweep` runs it. Claude Code's hooks run it as `--periodic`, at most
# once every 3 hours. A scheduled job cannot read the Desktop, so this file is
# what the hook runs, and nothing here starts launchd.
#
# One line per project: copied, off or failed, and the age of the copy before
# this run. A project that turned the copy off stays off. Projects with no
# brain/ are skipped. The suite points AI_BACKBONE_PROJECTS at a fixture and
# this does not read the machine.
set -uo pipefail

# A hook's PATH is short. The tools a session already has are here.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

mode="${1:-sweep}"
hint="${2:-}"
# The recipe says `periodic`. The installed hook says `--periodic` and then the
# backbone path, which is already $2.
case "$mode" in
  --periodic) mode=periodic ;;
esac
case "$mode" in
  sweep|periodic|warn-others) ;;
  *) echo "usage: vault-sweep.sh sweep|periodic|--periodic|warn-others [backbone]" >&2; exit 2 ;;
esac

mtime_of() {
  local s
  if s=$(stat -c %Y "$1" 2>/dev/null); then printf '%s' "$s"; return 0; fi
  if s=$(stat -f %m "$1" 2>/dev/null); then printf '%s' "$s"; return 0; fi
  return 1
}

# Seconds since the copy file was written, or nothing when it is not there.
age_seconds() {
  local s now
  [ -f "$1" ] || return 0
  s=$(mtime_of "$1" 2>/dev/null || true)
  case "$s" in ""|*[!0-9]*) return 0 ;; esac
  now=$(date +%s)
  if [ $(( now - s )) -lt 0 ]; then printf '0'; else printf '%s' $(( now - s )); fi
}

# Words for a sweep line: none, under an hour, N hours, N days.
age_phrase() {
  local s=$1 d
  if [ -z "$s" ]; then printf 'none'; return; fi
  if [ "$s" -lt 3600 ]; then printf 'under an hour'; return; fi
  if [ "$s" -lt 172800 ]; then printf '%s hours' $(( s / 3600 )); return; fi
  d=$(( s / 86400 ))
  if [ "$d" -eq 1 ]; then printf '1 day'; else printf '%s days' "$d"; fi
}

if [ "$mode" = periodic ]; then
  stamp="${AI_BACKBONE_VAULT_STAMP:-}"
  if [ -z "$stamp" ]; then
    stamp="$(cd "$(dirname "$0")" && pwd)/vault-sweep.last"
  fi
  # 3 hours. Touched first, so a long run is not started again beside itself.
  if [ -f "$stamp" ]; then
    s=$(mtime_of "$stamp" 2>/dev/null || true)
    now=$(date +%s)
    case "$s" in
      ""|*[!0-9]*) ;;
      *) [ $(( now - s )) -ge 10800 ] || exit 0 ;;
    esac
  fi
  mkdir -p "$(dirname "$stamp")" 2>/dev/null || true
  touch "$stamp" 2>/dev/null || true
  mode=sweep
fi

# Where the projects are. The same places as just projects and the freshness
# sweep: beside the backbone, one and two folders down, then brain/project-roots.txt.
bb=""
if [ -n "${AI_BACKBONE_PROJECTS:-}" ]; then
  base=$AI_BACKBONE_PROJECTS
else
  if [ -n "${AI_BACKBONE:-}" ] && [ -f "$AI_BACKBONE/.ai-backbone/projects.sh" ]; then
    bb=$(cd "$AI_BACKBONE" && pwd -P)
  elif [ -n "$hint" ] && [ -d "$hint" ]; then
    bb=$(cd "$hint" && pwd -P)
  else
    bb=$(pwd -P)
  fi
  base=$(dirname "$bb")
fi

list=$(mktemp)
trap 'rm -f "$list"' EXIT
seen=" "
add() {
  local d
  d="${1%/}"
  [ -d "$d" ] || return 0
  [ -f "$d/.ai-backbone/core.just" ] || return 0
  d=$(cd "$d" && pwd -P) || return 0
  # The backbone itself is not a sibling. routine.md is only in the backbone.
  [ -f "$d/.ai-backbone/manifest.txt" ] && [ -f "$d/.ai-backbone/routine.md" ] && return 0
  case " $seen " in *" $d "*) return 0 ;; esac
  seen="$seen$d "
  printf '%s\n' "$d" >> "$list"
}
if [ -d "$base" ]; then
  for d in "$base"/*/ "$base"/*/*/; do
    [ -d "$d" ] || continue
    add "$d"
  done
fi
roots_file=""
if [ -n "${AI_BACKBONE_PROJECT_ROOTS:-}" ]; then
  roots_file=$AI_BACKBONE_PROJECT_ROOTS
elif [ -z "${AI_BACKBONE_PROJECTS:-}" ] && [ -n "$bb" ]; then
  roots_file=$bb/brain/project-roots.txt
fi
if [ -n "$roots_file" ] && [ -f "$roots_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ""|\#*) continue ;; esac
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -d "$line" ] || continue
    line=$(cd "$line" && pwd -P) || continue
    add "$line"
    for d in "$line"/*/ "$line"/*/*/; do
      [ -d "$d" ] || continue
      add "$d"
    done
  done < "$roots_file"
fi
# The folder this was started in, when it is a project and not already listed.
# A hook's cwd is whichever project is open; the sweep still copies that one.
# A fixture (AI_BACKBONE_PROJECTS) is the whole list: the cwd is not added.
if [ "$mode" = sweep ] && [ -z "${AI_BACKBONE_PROJECTS:-}" ]; then
  add "$PWD"
fi

off_of() {
  local v
  v=$(git -C "$1" config --local --get ai-backbone.vault-copy 2>/dev/null || true)
  case $(printf '%s' "$v" | tr 'A-Z' 'a-z') in
    off|false|no|none) printf yes ;;
  esac
}

# The folder the copy would use, even when this project turned the copy off,
# so the age before is still said.
dest_of() {
  local d=$1 place project name
  place=$(git -C "$d" config --local --get ai-backbone.vault-copy 2>/dev/null || true)
  case $(printf '%s' "$place" | tr 'A-Z' 'a-z') in
    off|false|no|none|"") place="" ;;
    *) place=$(git -C "$d" config --local --get --path ai-backbone.vault-copy 2>/dev/null || true) ;;
  esac
  if [ -z "$place" ]; then
    place=$(git -C "$d" config --global --get --path ai-backbone.vault-copy 2>/dev/null || true)
  fi
  [ -n "$place" ] || return 0
  project=$(grep -E '^\| *project *\|' "$d/AGENTS.md" 2>/dev/null | head -1 | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
  if [ "$project" = ai-backbone ]; then project=""; fi
  if [ -z "$project" ]; then project=$(basename "$d"); fi
  name=$(cd "$d" && just _slug "$project" 2>/dev/null || true)
  [ -n "$name" ] || name=$(basename "$d")
  printf '%s/%s\n' "${place%/}" "$name"
}

here=$(pwd -P)
if [ -s "$list" ]; then
  LC_ALL=C sort -u "$list" -o "$list"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    label=$(basename "$d")
    dest=$(dest_of "$d")
    secs=""
    if [ -n "$dest" ] && [ -f "$dest/about-this-copy.txt" ]; then
      secs=$(age_seconds "$dest/about-this-copy.txt")
    fi
    phrase=$(age_phrase "$secs")
    if [ "$mode" = warn-others ]; then
      [ "$d" = "$here" ] && continue
      [ "$(off_of "$d")" = yes ] && continue
      [ -n "$secs" ] || continue
      [ "$secs" -gt 86400 ] || continue
      days=$(( secs / 86400 ))
      [ "$days" -ge 1 ] || days=1
      if [ "$days" -eq 1 ]; then word="1 day old"; else word="$days days old"; fi
      printf 'Vault copy: %s: the second copy is %s, in %s\n' "$label" "$word" "$dest"
      continue
    fi
    if [ "$(off_of "$d")" = yes ]; then
      printf '%s: off, was %s\n' "$label" "$phrase"
      continue
    fi
    if [ ! -d "$d/brain" ]; then
      continue
    fi
    out=$(cd "$d" && just _vault-copy quiet 2>&1) || true
    case "$out" in
      "brain/ copied to "*) printf '%s: copied, was %s\n' "$label" "$phrase" ;;
      *) printf '%s: failed, was %s\n' "$label" "$phrase" ;;
    esac
  done < "$list"
fi
exit 0
