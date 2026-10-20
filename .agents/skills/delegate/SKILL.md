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
   fix, or `just delegate-drop`.
4. `just publish` and `just ship` stay here. They are not the worker's.
5. Two failed tries at one job: stop and tell the maintainer. Do not do the
   job yourself instead.
6. A spec still goes to the maintainer for a yes. A draft of one may be delegated.

`just delegate-status` says whether a job of this project is running, and shows
the last report and the open `delegate/*` branches. `DELEGATE_TIMEOUT` is
minutes for one job (180 if unset). `WORKER_MODEL` is the model passed to
`claude`, when set. `grok` is called as `grok -p … --output-format plain`.

A run that pushed, moved the default branch, or changed the branch list prints
`BREACH:` first and exits non-zero. Do not accept that branch.
