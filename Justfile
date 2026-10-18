# This project's commands.
#
# The backbone's recipes live in `.ai-backbone/core.just`. Never edit that file;
# `just template-update` overwrites it. Language recipes live in `stack.just`
# (`just stack rust`). Anything you add below is yours and is never touched.

import? '.ai-backbone/core.just'   # optional, so a missing core gives a message, not a crash
import? 'stack.just'

# Plain `just` shows the four commands a person types. `just --list` shows all.
default:
    @just help

# Rename these to whatever you say in your own language.
alias yedekle := save
alias yayinla := publish
alias geri-al := undo

# ─────────────────────── this project ────────────────────────
# This repo is the backbone itself. Projects get .ai-backbone/seed/Justfile instead.

# Test the backbone: throwaway projects, a 0.3.1 -> current migration, what a person sees
self-test:
    @bash .ai-backbone/self-test.sh

# Every project built on this backbone, at a glance: version, unsaved work, GitHub, last save
projects:
    @bash .ai-backbone/projects.sh

# Mark a version stable: projects hear "behind" only below it (spec 031) · just stable 3.41.0
[positional-arguments]
stable version:
    #!/usr/bin/env bash
    set -uo pipefail
    # The rule, from spec 031: green on the three machines, then one day of
    # clean use in the pilot project; a security fix the same day. Only an
    # attended session runs this; the routine brief forbids it. The mark is a
    # file with a history, never a tag, and taking it back is one more run.
    v="$1"
    [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Say a version: just stable 3.41.0"; exit 1; }
    git fetch -q origin +refs/heads/main:refs/remotes/origin/main --tags 2>/dev/null || { echo "GitHub could not be reached; nothing marked."; exit 1; }
    c=$(git rev-parse -q --verify "refs/tags/v$v^{commit}" 2>/dev/null) || { echo "No tag v$v: only a version that reached main is marked."; exit 1; }
    git merge-base --is-ancestor "$c" origin/main || { echo "v$v is not on main; nothing marked."; exit 1; }
    printf '%s %s\n' "$v" "$c" > STABLE
    echo "STABLE now says $v ($c). Save it, publish to cloud, and carry it (just carry): the gate never takes this file on its own."

# The backbone's root holds its stable mark too
_root-allow:
    @echo STABLE

# What code waits on cloud for a yes · just carry <commit> takes it to main
[positional-arguments]
carry commit="":
    #!/usr/bin/env bash
    set -uo pipefail
    # Spec 031: the gate carries only docs on its own; code waits until the
    # person said yes to it. This lists, and with a commit carries through
    # main's own copy of gate.sh, so nothing on cloud changes how it is judged.
    # The routine brief forbids a scheduled run to call it.
    if ! git fetch -q origin +refs/heads/main:refs/remotes/origin/main +refs/heads/cloud:refs/remotes/origin/cloud 2>/dev/null; then
      echo "GitHub could not be reached; nothing was looked at."; exit 1
    fi
    if [ -n "${1:-}" ]; then
      gate=$(mktemp); trap 'rm -f "$gate"' EXIT
      MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' git show origin/main:.ai-backbone/gate.sh > "$gate" 2>/dev/null || { echo "main has no gate.sh to carry with."; exit 1; }
      bash "$gate" attend "$1"; exit
    fi
    if [ -z "$(git rev-list -n1 origin/main..origin/cloud 2>/dev/null)" ]; then echo "Nothing waits: cloud has nothing main does not."; exit 0; fi
    if [ "$(bash .ai-backbone/gate.sh look origin/cloud 2>/dev/null | tail -1)" != suite ]; then echo "Nothing waits for a yes: what cloud has over main is docs only, and the gate carries that on its own."; exit 0; fi
    echo "Code on cloud that main does not have, waiting for the maintainer's yes:"
    git --no-pager log --no-merges --format='  %h %s' origin/main..origin/cloud | grep -v ' docs: gate — ' | head -15
    echo "Files: $(git diff --name-only origin/main origin/cloud | wc -l | tr -d ' ') changed; .github/workflows or gate.sh among them: $(git diff --quiet origin/main origin/cloud -- .github/workflows .ai-backbone/gate.sh && echo no || echo YES)"
    # The commit to carry is the newest one a checks run tested: the gate's own
    # log lines on top of it start no run.
    found=""
    if command -v gh >/dev/null 2>&1; then
      for c in $(git rev-list --no-merges -n 20 origin/main..origin/cloud); do
        r=$(GH_PAGER=cat gh run list --workflow checks.yml --commit "$c" --limit 1 --json status,conclusion -q '.[0] | select(. != null) | "\(.status) \(.conclusion)"' 2>/dev/null || true)
        [ -n "$r" ] || continue
        found="${c:0:7}"
        case "$r" in
          "completed success") echo "Checks: ${found} is green. Say in plain words what changed and why; on the person's yes -> just carry ${found}" ;;
          completed*) echo "Checks: ${found} ended ${r#completed }; it cannot be carried (just ci)" ;;
          *) echo "Checks: ${found} is still being tested (just ci); carry it once it is green" ;;
        esac
        break
      done
    fi
    [ -n "$found" ] || echo "Checks: no run found for these commits (gh missing or not signed in?) -> just ci"

# No `projects-update` and no schedule for one since 3.20.0: `just session-start` in a project says when it is behind,
# and the agent working there updates it when that is safe. The daily job of that time wrote into projects from outside, mid-work.

# ─────────────────────────── the radar ───────────────────────────
# Every second run the scheduled agent looks outward (routine.md, the radar
# section; spec 012, spec 021). What it reads was written by strangers and it can push to
# main, so the reading is done by code and the saving is fenced.

# Is this run a radar run? Yes when the last radar was saved five days ago or more
# (or never). The routine runs every third day since 2026-10-07, at the
# maintainer's word: with five days, every second run looks outward, about every
# six days, and a run a few minutes early is still counted. A day of the year
# divisible by 3, the rule before, falls on every run or on none once the runs
# are three days apart.
radar-due:
    #!/usr/bin/env bash
    last=$(git log -1 --format=%ct --grep='^docs: radar ' HEAD 2>/dev/null || true)
    if [ -z "$last" ]; then echo "yes: no radar run in this history"; exit 0; fi
    days=$(( ( $(date +%s) - last ) / 86400 ))
    if [ $(( $(date +%s) - last )) -ge $(( 5 * 86400 )) ]; then echo "yes: the last radar was $days days ago"
    else echo "no: the last radar was $days day(s) ago; the next run after five days looks outward"; fi

# What the sources in docs/radar.toml have published since they were last read: just radar · just radar claude-code · just radar claude-code "## 2.1.277"
[positional-arguments]
radar name="" heading="":
    #!/usr/bin/env bash
    "$(just _py)" .ai-backbone/radar.py ${1:+"$1"} ${2:+"$2"}

# Write down how far one source was read: just radar-mark claude-code
[positional-arguments]
radar-mark name:
    #!/usr/bin/env bash
    "$(just _py)" .ai-backbone/radar.py --mark "$1"

# What is committed and not yet on GitHub is read from this run's own commits,
# not by comparing two trees: when main moved during the run, somebody else's
# file looked like the run's own and a clean run was refused (measured).
# It looks twice: at the folder, and at what is already committed and not yet
# on GitHub. A check the agent runs on itself before `just save` was shown to
# miss a change that had been committed first, and `save` stages everything
# there is (measured, spec 012).
# Save a radar run: the markers and the run's log line, and nothing else
radar-save:
    #!/usr/bin/env bash
    set -uo pipefail
    ok='^docs/(radar\.toml|routine-log\.md|backlog\.md)$'
    # This run's own commits are what is on HEAD and on neither branch (spec
    # 017): cloud carries the week's unpromoted work, main the notes and specs
    # that arrived since, and a base of one branch alone called the other's
    # files strays and refused every Sunday. Neither branch known: HEAD alone.
    git fetch -q origin +refs/heads/main:refs/remotes/origin/main +refs/heads/cloud:refs/remotes/origin/cloud 2>/dev/null || true
    nots=""; for r in origin/cloud origin/main; do git rev-parse -q --verify "$r" >/dev/null 2>&1 && nots="$nots ^$r"; done
    [ -n "$nots" ] || nots="^HEAD"
    # shellcheck disable=SC2086
    strays=$( { git status --porcelain --untracked-files=all | cut -c4- | sed 's/.* -> //'; git log --format= --name-only HEAD $nots; } | sort -u | grep -vE "$ok" || true )
    if [ -n "$strays" ]; then
      echo "Not saved. A radar run writes docs/radar.toml, its line in docs/routine-log.md and notes, and these are something else:"
      printf '  %s\n' $strays
      echo "Nothing was committed and nothing is pushed. Say so in the report and stop; the next run starts from a fresh checkout."
      exit 1
    fi
    if [ -z "$(git status --porcelain -- docs/radar.toml docs/routine-log.md docs/backlog.md)" ]; then echo "Nothing to save."; exit 0; fi
    # A note that could not be saved on its own (the folder was not clean when it
    # was written) is in docs/backlog.md still: it goes with this save, or the
    # run ends with a dirty folder (seen in the rehearsal of 2026-09-19).
    for f in docs/radar.toml docs/routine-log.md docs/backlog.md; do if [ -e "$f" ]; then git add -- "$f"; fi; done
    out=$(mktemp)
    if git commit -q -m "docs: radar $(date -u +%Y-%m-%d)" >"$out" 2>&1; then
      echo "Saved: the markers, the log line and any note that was waiting. Now step 12 of the brief."
    else
      echo "Not saved: the checks refused the commit. What they said:"; tail -15 "$out"; exit 1
    fi
