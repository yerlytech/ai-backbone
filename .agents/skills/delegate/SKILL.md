---
name: delegate
description: How a session hands one task to a worker with just delegate, then accepts, fixes or drops the branch. Use when WORKER is grok or claude and the session manages instead of writing the product code.
---

# Delegate

`WORKER` is the machine's choice. Unset or `off` means no delegation, which is
the default on a new machine. The same when the named worker is not installed.
Do the work yourself, as before.

With `WORKER` set to `grok` or `claude`, this session is the manager.

1. Write no product code. One task at a time.
2. `just delegate "<task>"`. The worker runs on `delegate/<date>-<slug>`, in
   this folder, and commits with `just save`. The recipe prints the worker's
   report (at most 15 lines), the commits, whether the tree is clean, and the
   exit. The log stays outside the repo.
3. Read that. Then `just delegate-accept`, another `just delegate` with the
   fix, or `just delegate-drop`. The fix runs on the same branch. A new branch
   would drop the first round's commits. `just delegate-drop --yes`, or
   `DELEGATE_YES=1`, drops with no terminal. Without that, it asks once.
4. `just publish` and `just ship` stay here. They are not the worker's.
5. Two failed tries at one job: stop and tell the maintainer. Do not do the
   job yourself instead.
6. A spec still goes to the maintainer for a yes. A draft of one may be delegated.

`just delegate-status` says whether a job of this project is running, and shows
the last report and the open `delegate/*` branches. `DELEGATE_TIMEOUT` is
minutes for one job (180 if unset). `DELEGATE_BASE` is a long-lived branch to
start from instead of the default. The branch records it, accept
fast-forwards onto it, and drop returns to it. `WORKER_MODEL` is the model passed to
`claude`, when set. `WORKER_BIN` is the binary, when set. Otherwise the name
on `PATH` is used, and otherwise `~/.grok/bin/grok`, or Claude's
`~/.claude/local/claude` then `~/.local/bin/claude`. `grok` is called as
`<bin> -p … --output-format plain`.

A run that pushed, moved the default branch (or the base, when one is set), or
changed the branch list prints `BREACH:` first and exits non-zero. Do not
accept that branch.
