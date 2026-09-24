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

# No `projects-update` and no schedule for one since 3.20.0: `just session-start` in a project says when it is behind,
# and the agent working there updates it when that is safe. The daily job wrote into projects from outside, mid-work.

# ─────────────────────────── the radar ───────────────────────────
# Once a week the scheduled agent looks outward (routine.md, the Sunday
# section; spec 012). What it reads was written by strangers and it can push to
# main, so the reading is done by code and the saving is fenced.

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
