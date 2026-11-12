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
delegate job per project folder (spec 034). A script that chains these jobs
must print the failure word its watcher matches. A line that says FAILED is
missed by a watcher that looks for DESK FAIL.

`just delegate-status` says whether a job of this project is running, and shows
the last report, the model and cost of the last opencode run when the log has
one, and the open `delegate/*` branches. `DELEGATE_TIMEOUT` is minutes
for one job (180 if unset). `DELEGATE_BASE` is a long-lived branch to
start from instead of the default. The branch records it, accept
fast-forwards onto it, and drop returns to it. On a `delegate/*` branch, leave
it unset, or set it to that same branch, for a fix round. Set to another
branch, `just delegate` refuses before a worker starts, in one line that names
both branches and the fix: unset `DELEGATE_BASE` to keep fixing this branch,
or check out the named branch to start from it. Accept fast-forwards the base
where it is checked out, and does not switch a worktree that is on main onto
the lane. When the base is already checked out, the worktree that still has
the delegate branch is detached there, and then the branch is deleted.
`just delegate-accept` refuses with `refuses: a job is running` while the
job's lock pid is alive, before it changes anything. A running job's
`reference-transaction` hook stays in place and is not skipped. Empty hooks
are used only after that check finds no running job, so a dead job's leftover
`core.hooksPath` does not block a multi-commit fast-forward. A failed
fast-forward is put back to the starting commit. If the tree is dirty after
a fast-forward that landed, accept prints what is dirty and stops. It does
not reset that dirt away.
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
shell wrappers `sh`, `bash`, `zsh`, `eval`, `xargs` and `env`, and
`just delegate-accept` and `just delegate-drop`, too: that line is
added and not measured on grok yet. `opencode` is called as
`opencode run --standalone --auto --format json -m <model>`. Every opencode
command passes `--standalone`, including `opencode stats`. Without that flag,
opencode starts `serve --service` and resumes sessions a restart interrupted.
`opencode service status` does not accept the flag. `just delegate-status`
warns when that status is not `stopped`. The run is called with
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

The job does not share the machine's sccache (n-301ae6). The worker is
started with `RUSTC_WRAPPER` unset, `SCCACHE_SERVER_UDS` unset, and its own
`SCCACHE_SERVER_PORT`. The server on that port is stopped when the job ends,
including when the job is killed. A server first started inside the sandbox
keeps the sandbox's file rights and then fails later builds on the machine.

## Crates

A grok worker's sandbox cannot download crates. Never vendor a crate, and
never patch crates-io with a path. If a download is refused, stop and say
which crate. `just delegate` runs `cargo fetch` outside the sandbox before
the worker starts, when the project has Rust (n-c4e0f1).

## One MCP server

`DELEGATE_MCP` is one name and one http(s) url for one run, for example
`context7 https://mcp.example.com/mcp`. The name is letters, digits, `_` and
`-`. `just delegate` writes that server into `./.grok/config.toml` for the
job and removes it when the job ends, whatever way the job ends. Grok reads
a project server only in a trusted folder. The grok worker is trusted for that run only
(`--trust` on that command). Trust is not saved: the recipe does not run
`grok --trust`, and it does not write `~/.grok/trusted_folders` (n-a5924b).
`.grok/` is in the template `.gitignore`.

## Pin bumps

The worker has no network. Before a task that bumps a pin, the desk installs
the package in the lane and writes the release notes into `target/`. The
worker reads that file. It does not run npm, gh or `just upstream`.

## What a worker cannot do

The deny list is command text and can be reworded. These hold another way:

- A merge, a rebase or a reset does not move the branch. The ref update is
  refused unless the new tip's first parent is the old tip.
- `DELEGATE_TIMEOUT` (minutes) and `DELEGATE_IDLE` (minutes) kill the worker's process group.
  The idle end fires only when the worktree has also been clean for that
  whole window. A quiet log with uncommitted changes keeps the job.
- opencode cannot read a path outside the project. kimi denies reads and
  writes of `~/.aws`, `~/.appstoreconnect`, `brain/03-stack` and `.env` by
  pattern. It has no blanket deny of every path outside the project.
- curl, ssh and gh are denied. A firewall for every outbound call is not this list.
- The task text has no zero-width character, bidi mark or HTML comment.

Grok's delegate run denies `Read` of the secret paths and the keystore
commands, `ssh-add`, and the agent socket, and denies `Write` and `Edit` of
`.grok/sandbox.toml`. It also denies `just delegate-accept` and
`just delegate-drop`, as do opencode and kimi. It writes a sandbox profile
`ai-backbone-delegate` (or `ai-backbone-delegate-job` when
`~/.grok/sandbox.toml` already has the first name) whose `deny` lists the
same paths. The profile is written to the project's `.grok/sandbox.toml`,
and only when the spliced content differs. The shared
`~/.grok/sandbox.toml` is not written: Grok's guide names both files, and
writing the shared one closes every session already running (seen
2026-11-07 23:28). `grok --help` (1.0.62) gives `--sandbox` a profile name,
not a file. A per-run profile file would not be read, so this is the file
the run uses (n-a6542a). The guide says a
non-empty `deny` is kernel-enforced; that enforcement is not measured yet
(n-fc65ca). When the job ends, the recipe compares that file's hash with the
hash from before the worker started, and says
`sandbox profile changed: .grok/sandbox.toml` if the worker changed it.
The same profile grants write access to `~/.docker/buildx`, as
that directory's full path, because `read_write` does not expand `~`
(n-9e0540). `docker buildx` stores its state there. Without the grant the
command fails and the worker never reaches `just save`. The worker still
cannot read `~/.ssh`. A worker never signs. When `commit.gpgsign` is on,
the job turns signing off in this worktree and marks the branch
`delegateUnsigned`. The worktree's own settings come back when the job ends.
Accept signs after the desk has read the work, with `rebase -S -f`: a plain
`rebase -S` on a branch already ahead of its base never calls the signer.
There is no `key::` signing key from the agent socket (n-afbc90). A failed
`rebase -S -f` is aborted: the mark and the branch stay, the base stays
where it was, and accept says `refuses: could not sign`. Every commit that
would move onto the base has to carry a signature first. The mark is
cleared only after the base has moved. opencode denies the
same commands after the shell allow, and
denies the same paths in its `read` object; the per-path `read` schema was
not in the checkout on 2026-10-31 (pin 2.1.2). Claude's denies are merged
into `.claude/settings.json` when `WORKER` is set. The command list is still
not a security boundary. opencode's rule above covers a path outside the project.

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
