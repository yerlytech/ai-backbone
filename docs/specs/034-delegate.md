---
status: approved
date: 2026-10-20
---

# 034 — delegate: Claude manages, a worker builds

## What

A project session in Claude becomes the project's manager. It does not write the
work itself. It picks the next job, writes it as a short task and hands it to a
worker agent with `just delegate "<task>"`. The worker today is Grok, run headless
from its own CLI. Later it may be GLM, Kimi or Gemini. The worker does the job on
its own branch, runs the tests, commits locally and ends with a report of at most
15 lines. The manager reads only that report and the branch's summary. Then it
either takes the work with `just delegate-accept`, sends a fix with another
`just delegate` on that same branch, or drops the branch with
`just delegate-drop`. Publishing, shipping and talking to the maintainer stay
with the manager.

## Why

The maintainer runs many projects at once in Zed, each with a Claude thread and a
Grok thread. Claude's tokens are the scarce resource, and a manager that only
reads reports spends a fraction of what building does. A trial on 2026-10-20 in
one game project showed this. Grok updated the backbone and walked one spec's
acceptance list. It refused to close the spec on a line that really does not
hold. The manager spent a few thousand tokens on the task and the review. Without
a shared recipe, every project would hand-roll the call, and the rules would
drift. The rules are: no push, no ship, the report's shape, where the log goes.
Unmanaged cloud agents showed the cost of drift on 2026-10-19 in three projects:
the same work done twice, work on a stale copy, and a merge on GitHub the Mac
never pulled.

## Not doing

- No worktrees. The worker uses the project's own folder on a branch, one job at
  a time per project. A worktree breaks the `../ai-backbone` path and starts a
  Rust build from nothing, 100 GB and more. Projects still run in parallel.
- No unattended loop or timer. A job starts because a manager ran it. The manager
  hears when it ends because its shell call returns, not by polling.
- No writing into the Zed Grok thread. The headless run is a separate session,
  kept in the worker's own history.
- No worker other than Grok and Claude until its headless call is tested here.
  An unknown `WORKER` refuses with the list it knows.
- Delegation is never required. With `WORKER` unset or `off`, the session works
  as before and does the work itself; that is the default on a new machine.
- No change to how publish and ship work, or who may run them.

## Questions

None open. Approved by the maintainer on 2026-10-20 with these choices: one job
per project at a time; a 3-hour limit per job by default, longer for one job
with `DELEGATE_TIMEOUT` (Rust builds and full test runs can pass an hour); the
log outside the repo; the manager may also delegate docs and spec drafts, but
shows a spec to the maintainer itself; after two failed tries at one job, the
manager stops and tells the maintainer instead of doing it itself; delegation
is optional, so a machine with only Claude works the old way or uses Claude as
its own worker.

## Acceptance

- [x] `just delegate "<task>"` refuses on a dirty tree, on a branch other than
      the default (or `DELEGATE_BASE`, when that branch exists) and other than
      an open `delegate/*` branch, while another job of this project runs, when
      `DELEGATE_BASE` names a branch that does not exist, or when the worker
      is not installed. Each refusal says why in one line.
- [x] On the default branch, or on `DELEGATE_BASE` when that is set, it creates
      `delegate/<date>-<slug>` from that branch and records the base as
      `branch.<name>.delegateBase`. On a `delegate/*` branch with a clean tree
      it runs there again and makes no new branch, so a fix keeps the first
      round's commits. The worker gets a fixed preamble: read AGENTS.md, stay
      on this branch, commit with `just save`, the forbidden list, the report's
      shape. The manager's text follows the preamble. The worker sees nothing
      else.
- [x] Forbidden to the worker, said in the preamble and checked afterwards:
      `just publish`, `git push`, `just ship`, `just deploy`, any server or
      GitHub call, merge, rebase, branch deletion. After the run the recipe
      checks three things. A remote ref is a breach when it points at a
      commit the job's branch can reach and no ref could reach before the
      run: the job's own new commits reached a remote. That ref may be a
      remote-tracking ref, or a ref of a remote whose URL is a local path.
      A fetch that moves origin, or a third party pushing an unrelated
      commit, is not a breach. Moving the default branch (the base, when
      `DELEGATE_BASE` is set or the branch records one), or changing the
      branch list, still is. Any breach prints `BREACH: …` first and exits
      non-zero.
- [x] The run stops after `DELEGATE_TIMEOUT` (default 180 min, any value for one job). The full output
      goes to `~/.cache/ai-backbone/delegate/<project>/<id>.log`, never the
      repo. The recipe prints only the worker's report, the branch's commits
      with `--stat`, whether the tree is clean, and the exit status.
- [x] `just delegate-status` says whether a job runs and on which branch, and
      shows the last report and the open `delegate/*` branches.
      `just delegate-accept [branch]` fast-forwards the default branch onto it,
      or the recorded base when the job started from `DELEGATE_BASE`, and
      deletes it. It refuses when that is not a fast-forward.
      `just delegate-drop [branch]` asks once, then deletes the branch and
      returns to that same base. `--yes` or `DELEGATE_YES=1` deletes without
      asking, so a manager with no terminal can drop. Without that, it still
      asks once.
- [x] `WORKER` (machine-local; unset or `off` means no delegation) chooses the
      adapter. Each adapter is one function: how to call the CLI headless in a
      folder with a prompt. The binary is `WORKER_BIN` when that is executable,
      otherwise the name on `PATH`, otherwise a known place: `~/.grok/bin/grok`,
      or `~/.claude/local/claude` then `~/.local/bin/claude`. The adapter calls
      that path. `grok` uses `<bin> -p … --output-format plain`; `claude` uses
      `<bin> -p …` with a cheaper model (`WORKER_MODEL`). With `off`,
      `just delegate` says so and the manager rules do not apply.
- [x] The core rules give the manager role: no product code by the manager; one
      task, one report, review, then accept, fix or drop; the publish and ship
      gates unchanged; two failures go to the maintainer. They also say what to
      do when no worker is installed: the session works as before.
- [x] Tests with a fake worker (a script) cover each refusal, a clean run, a
      timeout, a worker that pushes or moves the default branch (BREACH), and
      accept and drop. They pass on macOS and Linux.
      macOS green (delegate section, full suite, 2026-10-20). Linux green on
      f64c84d (2026-10-20 routine log; it contains f978d71) and again on
      477af32 (2026-10-30, green on Linux and macOS). Checks: "a dirty tree is
      refused in one line, before any branch", "a clean run makes
      delegate/<date>-<slug>, commits, and prints the report", "the run stops
      when DELEGATE_TIMEOUT passes and says timeout", "a worker that pushes is
      a breach, said first", "a worker that moves the default branch is a
      breach, said first", "accept fast-forwards the default branch and
      deletes the delegate branch", "drop asks once: no keeps the branch, yes
      deletes it".
- [x] A real run in a fixture project with Grok finishes with a report and an
      accepted branch. Missing Grok leaves this line pending, not failed.
      2026-10-20, grok 1.0.62 off PATH (~/.grok/bin): a throwaway repo, one
      file committed on its delegate branch, report printed, tree clean, exit
      0, `delegate-status` then `delegate-accept` onto main.

## Tasks

- [x] The recipes `delegate`, `delegate-status`, `delegate-accept` and
      `delegate-drop`, the grok adapter, the preamble, and the fake-worker tests.
- [x] The BREACH check and the timeout, with their tests.
- [x] The manager rules in the core instructions, the skill text (team or a new
      `delegate` skill), `docs/`, and the changelog.
- [x] A real Grok run in a fixture. 2026-10-20, grok 1.0.62, recorded in
      df9708d: a throwaway repo, exit 0 (the acceptance line above).
- [x] Released with 035 as 3.45.0 (e766feb). Later CalVer through 26.10.1
      (e7c3348).
- [ ] Each project's `just template-update`. Not done from this repository.
