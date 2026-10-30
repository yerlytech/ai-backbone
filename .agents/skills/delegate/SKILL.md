---
name: delegate
description: How a session hands one task to a worker with just delegate, then accepts, fixes or drops the branch. Use when WORKER is grok, claude, opencode or kimi and the session manages instead of writing the product code.
---

# Delegate

`WORKER` is the machine's choice. Unset or `off` means no delegation, which is
the default on a new machine. The same when the named worker is not installed.
Do the work yourself, as before.

With `WORKER` set to `grok`, `claude`, `opencode` or `kimi`, this session is the manager.

1. Write no product code. One task at a time.
2. `just delegate "<task>"`. The worker runs on `delegate/<date>-<slug>`, in
   this folder, and commits with `just save`. A line `Title: ...` in the task
   is the slug. The same slug on the same day becomes `…-2`, then `…-3`. The recipe prints the worker's
   report (at most 15 lines), the commits, whether the tree is clean, and the
   exit. The log stays outside the repo. An opencode report ends with
   `cost: $<sum> on <model>, <n> steps`, summed from that run's events.
3. Read that. Then `just delegate-accept`, another `just delegate` with the
   fix, or `just delegate-drop`. The fix runs on the same branch. A new branch
   would drop the first round's commits. `just delegate-drop --yes`, or
   `DELEGATE_YES=1`, drops with no terminal. Without that, it asks once.
4. `just publish` and `just ship` stay here. They are not the worker's.
5. Two failed tries at one job: stop and tell the maintainer. Do not do the
   job yourself instead. For opencode, that is past the last model of the ladder.
6. A spec still goes to the maintainer for a yes. A draft of one may be delegated.

`.claude/settings.json` is the project's own file after it is created. When
`WORKER` is `grok`, `claude`, `opencode` or `kimi`, a new project and
`just template-update` add allow rules for `just delegate`,
`just delegate-status`, `just delegate-accept` and `just delegate-drop`.
A rule the project wrote stays. Do not edit that file to add these. With
`WORKER` unset or `off`, nothing is added.

## Queue

Related small jobs are one task text: one round, one report. Independent jobs
in one project go back to back: hand the next one when the report comes, and
do not make the owner wait for it. Run jobs in parallel only across projects,
or in separate worktrees of one repository started with `DELEGATE_BASE`; one
delegate job per project folder (spec 034).

`just delegate-status` says whether a job of this project is running, and shows
the last report, the model and cost of the last opencode run when the log has
one, and the open `delegate/*` branches. `DELEGATE_TIMEOUT` is
minutes for one job (180 if unset). `DELEGATE_BASE` is a long-lived branch to
start from instead of the default. The branch records it, accept
fast-forwards onto it, and drop returns to it. Accept fast-forwards the base
where it is checked out, and does not switch a worktree that is on main onto
the lane. When the base is already checked out, the worktree that still has
the delegate branch is detached there, and then the branch is deleted.
`WORKER_MODEL` pins one model.
For `claude` it is passed through. For `opencode` it is used on every round
instead of the ladder. `WORKER_LADDER` is that ladder, comma-separated
`opencode-go/<id>`. Unset, it is
`opencode-go/deepseek-v4.1-flash,opencode-go/glm-5.3,opencode-go/kimi-k3`.
The first try of a branch uses the first model; each fix round uses the next.
`WORKER_BIN` is the binary, when set. Otherwise the name
on `PATH` is used, and otherwise `~/.grok/bin/grok`, Claude's
`~/.claude/local/claude` then `~/.local/bin/claude`,
`~/.opencode/bin/opencode`, or `~/.kimi-code/bin/kimi` then
`/opt/homebrew/bin/kimi` and `/usr/local/bin/kimi`. `grok` is called as
`<bin> -p … --output-format plain`, in auto mode, and its deny list names the
shell wrappers `sh`, `bash`, `zsh`, `eval`, `xargs` and `env` too: that line is
added and not measured on grok yet. `opencode` is called as
`opencode run --standalone --auto --format json -m <model>`, with
`OPENCODE_CONFIG` pointing at a file outside the project. That file turns
autoupdate off and gives the worker only shell, read, edit and write. It
denies push, merge, rebase, checkout, switch, reset, branch deletion, tag,
publish, ship, deploy, release, undo, gh, curl, ssh and rm, the wrappers
`sh`, `bash`, `zsh`, `eval`, `xargs` and `env`, web fetch, and paths outside
the project. `kimi` is called as `kimi -p … --output-format stream-json`,
and `-m` when `DELEGATE_MODEL` is set. It does not read `WORKER_MODEL` and
does not climb the ladder. kimi-code 2.4.0 has no per-run config file, and
`KIMI_CODE_HOME` would move the login, so the same deny list, plus `just carry`,
is a marked block in the user config, rewritten each run. A machine that is
not logged in stops with `kimi is not logged in: run kimi login` and leaves
no branch. The report is the last 15 lines of the assistant text in that
stream-json log.

## Pin bumps

The worker has no network. Before a task that bumps a pin, the desk installs
the package in the lane and writes the release notes into `target/`. The
worker reads that file. It does not run npm, gh or `just upstream`.

## What a worker cannot do

The deny list is command text and can be reworded. These hold another way:

- A merge, a rebase or a reset does not move the branch. The ref update is
  refused unless the new tip's first parent is the old tip.
- `DELEGATE_TIMEOUT` and `DELEGATE_IDLE` kill the worker's process group.
  The idle end fires only when the worktree has also been clean for that
  whole window. A quiet log with uncommitted changes keeps the job.
- opencode cannot read a path outside the project. kimi denies reads and
  writes of `~/.aws`, `~/.appstoreconnect`, `brain/03-stack` and `.env` by
  pattern. It has no blanket deny of every path outside the project.
- curl, ssh and gh are denied. A firewall for every outbound call is not this list.
- The task text has no zero-width character, bidi mark or HTML comment.

A grok rule that denies reads of `~/.aws`, `~/.appstoreconnect`, `brain/03-stack`
and `.env` is not here: that syntax was not measured. opencode's rule above
covers a path outside the project.

A run that pushed, moved the default branch (or the base, when one is set), or
changed the branch list prints `BREACH:` first and exits non-zero. A fetch
that moves a remote ref, or someone else pushing a commit this branch does
not contain, is not a breach. A branch another worktree of the same
repository has checked out is not this run's change: a parallel lane that
creates or drops its own branch during the run is not a breach. A `lane/`
name alone does not skip the branch. A branch the worker creates and leaves
unchecked still is. Do not accept a branch that breached.

The harness this session runs in may stop a command after two hours (Claude
Code's limit for a background command, measured on claude-code 2.1.296), and
the job goes with it. A job that may run longer is started on its own:
`nohup just delegate "<task>" > <file outside the repo> 2>&1 &`. Then
`just delegate-status` says when it is done and shows the report.
