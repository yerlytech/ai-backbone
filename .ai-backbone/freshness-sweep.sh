#!/usr/bin/env bash
# The machine's behind and not-watched lines, one project at a time (n-058e8b,
# spec 043). The daily job runs a copy of this file from outside the project
# and passes the checkout and the output file. A session runs it through
# `just freshness-sweep`. It reads projects. It does not write into them.
set -uo pipefail

root="${1:-}"
out="${2:-}"
if [ -z "$root" ] || [ -z "$out" ]; then
  echo "usage: freshness-sweep.sh <checkout> <outfile>" >&2
  exit 1
fi
root=$(cd "$root" 2>/dev/null && pwd -P) || { echo "freshness-sweep: cannot read $1" >&2; exit 1; }
if [ ! -f "$root/.ai-backbone/upstream.py" ]; then
  echo "freshness-sweep: $root has no .ai-backbone/upstream.py" >&2
  exit 1
fi

# launchd's PATH is almost empty. The tools a session already has are here.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
py=""
if command -v uv >/dev/null 2>&1; then
  py=$(uv python find '>=3.11' --no-project --no-python-downloads 2>/dev/null || true)
  if [ -z "$py" ]; then
    py=$(UV_NO_CACHE=1 uv python find '>=3.11' --no-project --no-python-downloads 2>/dev/null || true)
  fi
fi
if [ -z "$py" ]; then py=$(command -v python3 || true); fi
if [ -z "$py" ]; then
  echo "freshness-sweep: python3 is missing" >&2
  exit 1
fi

# Where the projects are. The suite points AI_BACKBONE_PROJECTS at a fixture
# and does not read this machine. A real run looks beside the backbone, then
# at brain/project-roots.txt, the same places as just projects.
bb=""
if [ -n "${AI_BACKBONE_PROJECTS:-}" ]; then
  base=$AI_BACKBONE_PROJECTS
else
  if [ -n "${AI_BACKBONE:-}" ] && [ -f "$AI_BACKBONE/.ai-backbone/projects.sh" ]; then
    bb=$(cd "$AI_BACKBONE" && pwd -P)
  else
    bb=$root
  fi
  base=$(dirname "$bb")
fi

list=$(mktemp)
trap 'rm -f "$list"' EXIT
seen=" "
add() {
  d="${1%/}"
  [ -d "$d" ] || return 0
  [ -f "$d/.ai-backbone/core.just" ] || return 0
  d=$(cd "$d" && pwd -P) || return 0
  case " $seen " in *" $d "*) return 0 ;; esac
  seen="$seen$d "
  printf '%s\n' "$d" >> "$list"
}
if [ -z "${AI_BACKBONE_PROJECTS:-}" ] && [ -n "$bb" ]; then add "$bb"; fi
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

tmpout=$(mktemp)
printf '# freshness %s\n' "$(date '+%Y-%m-%d %H:%M')" > "$tmpout"
any=0
if [ -s "$list" ]; then
  sort -u "$list" -o "$list"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    name=$(basename "$d")
    if [ ! -r "$d" ]; then
      printf '== %s ==\ncould not read\n\n' "$name" >> "$tmpout"
      any=1
      continue
    fi
    said=$(cd "$d" && AI_BACKBONE_UPSTREAM_NO_WRITE=1 "$py" "$root/.ai-backbone/upstream.py" --freshness 2>&1) || said="${said:-could not read}"
    lines=$(printf '%s\n' "$said" | awk '/^Behind: / && $0 !~ /^Behind: nothing$/ { print } /^not watched: / { print }')
    if [ -n "$lines" ]; then
      printf '== %s ==\n%s\n\n' "$name" "$lines" >> "$tmpout"
      any=1
    fi
  done < "$list"
fi
if [ "$any" -eq 0 ]; then
  printf '%s\n' "nothing behind, nothing unwatched" >> "$tmpout"
fi
mkdir -p "$(dirname "$out")"
mv "$tmpout" "$out"
echo "Wrote $out"
