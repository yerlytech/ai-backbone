---
status: approved
date: 2026-09-25
---

# 021 — Current tools, and a radar every third day

## What

The backbone is tested on the newest release of everything it is built on and
carried to `main` when the gate is green on Linux, macOS and Windows. The
scheduled agent checks the tools at the start of every run and, when one has
moved, makes moving to it that run's item. It reads each tool where it is
installed from. The radar that reads the standards around the backbone
(OpenSpec, Spec Kit, AGENTS.md, Agent Skills, Claude Code, Gemini CLI, Copilot)
runs every third day instead of every Sunday. There is one scheduled agent:
the Claude Code routine in the maintainer's account, whose whole brief is
`.ai-backbone/routine.md`.

## Why

The maintainer asked for it on 2026-09-25, after reading what the routine
watched. Measured that day:

- `just upstream` read just, prek and gitleaks from GitHub, whose API answers
  403 in the routine's sandbox: their versions came through `git ls-remote`,
  their release dates never ("?" every night).
- graphify was reported "4 newer, v1.0.0": GitHub had the tag, PyPI, where uv
  installs it from, had 0.9.67 as its newest. Nobody could install what the
  report called new.
- Nothing watched uv, or `actions/checkout`, which the gate ran at v5 while v7
  was out.
- The routine's brief read the report and moved nothing: "a report, and it
  changes nothing".

## How it works

- `upstream.py` reads `pypi:<name>`: every release and the day of its first
  file, a yanked one left out, PEP 440's letters as a prerelease. just
  (`rust-just`), prek, graphify (`graphifyy`) and uv are read there.
- A row with `major = true` counts only a new major as newer: a workflow's
  `actions/checkout@v7` takes every v7.x by itself.
- `just tools-update` moves the pin of a row read from PyPI too.
- The brief: after the gate, a watched tool that moved is the run's item.
  just, prek, graphify and uv are already installed at their newest by
  `setup.sh`, so the run's suite is the test; `just tools-update` moves the
  pins and the hooks' `rev:` lines, and a moved gitleaks goes into the seed
  config, its watch row and the template's example row, which the suite
  checks agree. A workflow pin is noted for an attended session: the gate
  never carries a changed workflow.
- The radar: every third day of the year (`date -u +%j` divisible by 3). The
  weekly yes/no question stays on Sunday.

## Not doing

- Letting the unattended run change a workflow or the gate. It could then
  weaken what judges it.
- Watching the runner images: the gate runs on `-latest`, which GitHub moves.
- A second scheduler. `just routine-install` stays for projects; the backbone
  has the one in the cloud.

## Questions

## Acceptance

- [x] `just upstream` shows a release date for just, prek, graphify and uv in the cloud sandbox.
- [x] graphify is not reported newer while PyPI has nothing newer.
- [x] uv and `actions/checkout` are watched; v7.0.1 is not "newer" than a pin of v7.
- [x] The gate is green on three machines with `actions/checkout@v7` (run 36121318206); `promote.yml` with it carried eb5428c to main and tagged v3.28.0 (run 36122881278).
- [ ] A routine run that finds a moved tool moves it, and the gate carries it.

## Tasks

- [x] `pypi:` in upstream.py, `major`, tools-update, the watch list, their checks.
- [x] The brief: current tools after the gate, the radar every third day; the docs.
- [x] `actions/checkout@v7` and graphify's pin, carried to main by hand (a workflow): fb02c01.
