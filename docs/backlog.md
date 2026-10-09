# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-06, n-0db9ff: _build-wait in core.just polls for any cargo or rustc process and waits up to BUILD_WAIT_MINUTES; with several projects on one machine saving often, the waits stack to the limit and then every waiter goes at once (measured: three saves each waited about 20 minutes, then compiled together). A per-machine FIFO lock (flock on a file under the user's cache) would serve builds in order and never release them together.
- [ ] 2026-10-06, n-5332d9: .gitignore: Claude Code's agent worktrees in .claude/worktrees/ are not ignored, so just save (git add -A) would commit them as embedded repositories; add .claude/worktrees/ to the template's .gitignore; checked 2026-10-07: no .gitignore here names worktrees, so the line stands; blocked: needs an attended session
- [ ] 2026-10-08, n-9f9be8: upstream.py: add a hf:owner/name source that reads a Hugging Face repo's commits, so a model a project pins by its revision can be watched in docs/upstream.toml like a crate, instead of a comment beside the list
- [ ] 2026-10-08, n-303cba: session skill: nothing says what an agent does when its context nears the model's limit; a rule (measure after each task, at a set mark write the handover into the day's journal, save, tell the maintainer the session is ready for a new chat, stop; never compact) would replace telling every session by hand
- [ ] 2026-10-08, n-bf44a6: just save (.ai-backbone/core.just): a commit went through while its tree failed just test-fast, measured right after; the first save was refused by lint, the second passed silently; prek.log keeps only the last run, so which hooks ran is unknown. just save should print each hook's passed or skipped line, or keep the last runs' results
- [ ] 2026-10-09, n-2cd44d: core.just: nothing trims cargo target dirs; on one Mac several Rust workspaces grew past 200 GB each (old incremental crate dirs, cross-target profiles from weeks ago) and filled the disk to 2.7 GB free. Idea: a 'just clean-builds' that removes incremental crate dirs untouched for a day and cross-target or release dirs untouched for a week, safe while a build runs, and a session-start warning when free disk falls under 10%.
