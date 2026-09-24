#!/usr/bin/env bash
# The gate (spec 017): what reaches main is what passed on a clean Linux and a
# clean Mac. Two verbs, run by the workflows in .github/ and by just self-test.
#
#   gate.sh look [commit]   in a checkout of the pushed commit: prints `suite`
#                           when the suite must run for it, `docs-only` when
#                           nothing but the routine's own files differ from main
#   gate.sh carry           in a checkout of main with the whole history, given
#                           the finished run in GATE_SHA, GATE_ENDED and
#                           GATE_RUN: carries the tested commit to main and tags
#                           its version, or writes why not where the next run
#                           reads (the last line of docs/routine-log.md on cloud)
#
# promote.yml runs from main's copy of itself and of this file, so a push to
# cloud can change what is tested, never how it is judged. Nothing here merges:
# main only ever moves forward to a commit the suite ran on, and joining main's
# notes into cloud is the routine's job, where a merge that stops can be aborted.
set -uo pipefail

# The routine's own files: a log line, a tick, a note, a Sunday's markers, a
# spec. Nothing under them is copied to a project or run by a recipe, so a push
# that changes only these is carried without the suite (a macOS minute counts
# ten). Everything else under docs/ runs it: the suite greps three of those
# pages, and upstream.toml is read by code.
own() {
  case "$1" in
    docs/routine-log.md|docs/backlog.md|docs/radar.toml|docs/specs/*) return 0 ;;
    *) return 1 ;;
  esac
}

# What differs between main's tip and a commit: a tree diff, which needs no
# history and so answers the same in a checkout of depth one (measured: a
# merge-base there is empty, and the diff against nothing called a push with
# code in it docs-only). Judged against main, never against the push before,
# so a commit whose run was cancelled cannot slip under a docs-only push.
look() {
  local at="${1:-HEAD}" changed f
  if ! git fetch -q origin +refs/heads/main:refs/remotes/origin/main 2>/dev/null; then
    echo "main could not be fetched, so the suite runs" >&2; echo suite; return 0
  fi
  if ! changed=$(git diff --name-only origin/main "$at" 2>/dev/null); then
    echo "the diff against main failed, so the suite runs" >&2; echo suite; return 0
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! own "$f"; then echo "$f differs from main" >&2; echo suite; return 0; fi
  done <<<"$changed"
  echo docs-only
}

# The run's jobs, one per line: id, name, conclusion. Through gh, which the
# promote job has and the routine's sandbox does not; a stand-in answers here
# in the self-test.
jobs_of() {
  [ -n "$1" ] && command -v gh >/dev/null 2>&1 || return 1
  gh run view "$1" --json jobs --jq '.jobs[] | "\(.databaseId)\t\(.name)\t\(.conclusion)"' 2>/dev/null
}

# Green on the machines that decide. The Windows job reports only.
suite_green() {
  local id name concl linux="" mac=""
  # By prefix: a matrix job's name carries the other matrix values as well
  # when the workflow gives it no name of its own (measured 2026-09-24).
  while IFS=$'\t' read -r id name concl; do
    case "$name" in
      "suite (ubuntu-latest"*) [ "$concl" = success ] && linux=1 ;;
      "suite (macos-latest"*)  [ "$concl" = success ] && mac=1 ;;
    esac
  done < <(jobs_of "$1")
  [ -n "$linux" ] && [ -n "$mac" ]
}

# What went red, by machine, with up to five FAIL names from its log. The
# Windows job is left out: report-only, and its dozens of lines would hide the
# one that matters.
red() {
  local run="$1" id name concl log mine names out=""
  [ -n "$run" ] || { echo "no run to read"; return 0; }
  while IFS=$'\t' read -r id name concl; do
    [ -n "$id" ] || continue
    case "$concl" in success|skipped|"") continue ;; esac
    case "$name" in *windows*) continue ;; esac
    # gh prefixes every log line with the job and the step, tab-separated
    # (fixtures/gh-log-failed.txt): only this job's lines are read, and all of
    # them when the prefix is not there.
    log=$(gh run view "$run" --job "$id" --log-failed 2>/dev/null)
    mine=$(printf '%s\n' "$log" | awk -F'\t' -v j="$name" '$1 == j')
    [ -n "$mine" ] || mine="$log"
    names=$(printf '%s\n' "$mine" | grep -oE 'FAIL  .*' | cut -c7-100 | head -5 | tr '\n' ';' | sed 's/;$//')
    out="$out $name $concl${names:+ FAIL: $names};"
  done < <(jobs_of "$run")
  if [ -n "$out" ]; then printf '%s' "${out# }"; else echo "no failed job could be read"; fi
}

carry() {
  # No apostrophe inside these braces: /bin/bash 3.2 reads one as a quote.
  : "${GATE_SHA:?the tested commit}" "${GATE_ENDED:?the conclusion of the run}"
  local sha="$GATE_SHA" run="${GATE_RUN:-}" why="" short="${GATE_SHA:0:7}"
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  if ! git fetch -q origin +refs/heads/main:refs/remotes/origin/main +refs/heads/cloud:refs/remotes/origin/cloud 2>/dev/null; then
    echo "gate: GitHub could not be fetched; nothing was judged"; return 1
  fi
  # By name: cloud may have moved past it, and a commit cloud no longer reaches
  # (it is never rewritten, but a fetch is cheap) is judged as gone.
  git fetch -q origin "$sha" 2>/dev/null || true
  # The machines that decide decide. A report-only job cut by its cap ends
  # the whole run as "cancelled" whatever continue-on-error says (measured
  # 2026-09-24: Linux and macOS green, Windows cancelled, run cancelled), and
  # a run nobody judges is a push that never reaches main.
  if [ "$GATE_ENDED" != success ] && suite_green "$run"; then
    echo "gate: the run ended $GATE_ENDED, and Linux and macOS were green: they decide"
    GATE_ENDED=success
  fi
  case "$GATE_ENDED" in
    cancelled|skipped) echo "gate: the run was $GATE_ENDED; the next push is judged instead"; return 0 ;;
  esac
  if ! git cat-file -e "$sha^{commit}" 2>/dev/null; then
    why="the tested commit $short is not on GitHub any more"
  elif git merge-base --is-ancestor "$sha" origin/main 2>/dev/null; then
    # A newer push was carried first, and carried this one with it.
    echo "gate: $short is on main already; nothing to carry"; return 0
  elif [ "$GATE_ENDED" != success ]; then
    why="the checks ended $GATE_ENDED: $(red "$run")"
  elif ! git merge-base --is-ancestor origin/main "$sha" 2>/dev/null; then
    why="main moved ($(git rev-list --count "$sha..origin/main" 2>/dev/null || echo '?') commit(s) cloud does not have); the next run merges origin/main into cloud and pushes"
  elif ! git diff --quiet origin/main "$sha" -- .github/workflows .ai-backbone/gate.sh 2>/dev/null; then
    why="the push changes .github/workflows or gate.sh, which only an attended session carries to main (git push origin <commit>:main after green checks); an unattended run puts main's copy back"
  elif [ "$(look "$sha" 2>/dev/null)" = suite ] && ! suite_green "$run"; then
    why="the suite was due for this push and the run has no green suite job for Linux and macOS"
  else
    git checkout -q -B main origin/main 2>/dev/null
    if git merge -q --ff-only "$sha" >/dev/null 2>&1; then
      # The version is line 1 of core.just at main's new head, read the way
      # _backbone-tag reads it. A tag that exists is left alone: two writers
      # agree by construction, and an atomic push with a tag GitHub already has
      # elsewhere refuses main as well (measured), so main goes alone then.
      local v refs=main tagged="" stood=""
      v=$(head -1 .ai-backbone/core.just 2>/dev/null | grep -oE 'version [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
      if [ -n "$v" ]; then
        if [ -z "$(git ls-remote --tags origin "refs/tags/v$v" 2>/dev/null)" ]; then
          git tag -f "v$v" >/dev/null 2>&1 && { refs="main v$v"; tagged="v$v"; }
        else stood="v$v"; fi
      fi
      # shellcheck disable=SC2086
      if git push -q --atomic origin $refs 2>/dev/null; then
        echo "gate: carried $short to main${tagged:+ and tagged $tagged}${stood:+; $stood was tagged before}"; return 0
      fi
      if [ -n "$tagged" ] && git push -q origin main 2>/dev/null; then
        echo "gate: carried $short to main; the tag $tagged was there already, or was refused"; return 0
      fi
      why="GitHub would not take main${tagged:+ and $tagged}; nothing was carried, the next green push tries again"
    else
      why="main could not fast-forward to $short"
    fi
  fi
  # Not carried. One line where the next run reads (just session-start prints
  # the last two), on cloud, on top of whatever landed there meanwhile. A push
  # by this token starts no workflow, so the line rides the next real push.
  local line try
  line="- $(date -u +%Y-%m-%d) gate: cloud not promoted — $(printf '%s' "$why" | tr '\n\r\t' '   ' | cut -c1-400)"
  for try in 1 2 3; do
    git fetch -q origin +refs/heads/cloud:refs/remotes/origin/cloud 2>/dev/null || break
    git checkout -q --detach origin/cloud 2>/dev/null || break
    mkdir -p docs
    [ ! -s docs/routine-log.md ] || [ -z "$(tail -c1 docs/routine-log.md)" ] || echo >> docs/routine-log.md
    printf '%s\n' "$line" >> docs/routine-log.md
    if git add docs/routine-log.md && git commit -q -m "docs: gate — cloud not promoted" >/dev/null 2>&1 \
       && git push -q origin HEAD:cloud 2>/dev/null; then
      echo "gate: not promoted: $why"; return 0
    fi
    git reset -q --hard origin/cloud 2>/dev/null || true
  done
  echo "gate: not promoted: $why (and the verdict could not be written on cloud: the next run sees cloud ahead of main with no line for it)"
  return 1
}

case "${1:-}" in
  look)  look "${2:-HEAD}" ;;
  carry) carry ;;
  *) echo "usage: gate.sh look [commit] | gate.sh carry" >&2; exit 2 ;;
esac
