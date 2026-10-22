---
name: delegate
description: How a session hands one task to a worker with just delegate, then accepts, fixes or drops the branch. Use when WORKER is grok, claude or opencode and the session manages instead of writing the product code.
---

# Delegate

`WORKER` is the machine's choice. Unset or `off` means no delegation, which is
the default on a new machine. The same when the named worker is not installed.
Do the work yourself, as before.

With `WORKER` set to `grok`, `claude` or `opencode`, this session is the manager.

1. Write no product code. One task at a time.
2. `just delegate "<task>"`. The worker runs on `delegate/<date>-<slug>`, in
   this folder, and commits with `just save`. The recipe prints the worker's
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

`just delegate-status` says whether a job of this project is running, and shows
the last report, the model and cost of the last opencode run when the log has
one, and the open `delegate/*` branches. `DELEGATE_TIMEOUT` is
minutes for one job (180 if unset). `DELEGATE_BASE` is a long-lived branch to
start from instead of the default. The branch records it, accept
fast-forwards onto it, and drop returns to it. `WORKER_MODEL` pins one model.
For `claude` it is passed through. For `opencode` it is used on every round
instead of the ladder. `WORKER_LADDER` is that ladder, comma-separated
`opencode-go/<id>`. Unset, it is
`opencode-go/deepseek-v4.1-flash,opencode-go/glm-5.3,opencode-go/kimi-k3`.
The first try of a branch uses the first model; each fix round uses the next.
`WORKER_BIN` is the binary, when set. Otherwise the name
on `PATH` is used, and otherwise `~/.grok/bin/grok`, Claude's
`~/.claude/local/claude` then `~/.local/bin/claude`, or
`~/.opencode/bin/opencode`. `grok` is called as
`<bin> -p … --output-format plain`, in auto mode, and its deny list names the
shell wrappers `sh`, `bash`, `zsh`, `eval`, `xargs` and `env` too: that line is
added and not measured on grok yet. `opencode` is called as
`opencode run --standalone --auto --format json -m <model>`, with
`OPENCODE_CONFIG` pointing at a file outside the project. That file turns
autoupdate off and gives the worker only shell, read, edit and write. It
denies push, merge, rebase, checkout, switch, reset, branch deletion, tag,
publish, ship, deploy, release, undo, gh, curl, ssh and rm, the wrappers
`sh`, `bash`, `zsh`, `eval`, `xargs` and `env`, web fetch, and paths outside
the project.

A run that pushed, moved the default branch (or the base, when one is set), or
changed the branch list prints `BREACH:` first and exits non-zero. A fetch
that moves a remote ref, or someone else pushing a commit this branch does
not contain, is not a breach. A branch another worktree of the same
repository has checked out is not this run's change: a parallel lane that
creates or drops its own branch during the run is not a breach. A branch the
worker creates and leaves unchecked still is. Do not accept a branch that
breached.

The harness this session runs in may stop a command after two hours (Claude
Code's limit for a background command, measured on claude-code 2.1.296), and
the job goes with it. A job that may run longer is started on its own:
`nohup just delegate "<task>" > <file outside the repo> 2>&1 &`. Then
`just delegate-status` says when it is done and shows the report.
