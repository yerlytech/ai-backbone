# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-06, n-0db9ff: _build-wait in core.just polls for any cargo or rustc process and waits up to BUILD_WAIT_MINUTES; with several projects on one machine saving often, the waits stack to the limit and then every waiter goes at once (measured: three saves each waited about 20 minutes, then compiled together). A per-machine FIFO lock (flock on a file under the user's cache) would serve builds in order and never release them together.
- [ ] 2026-10-06, n-5332d9: .gitignore: Claude Code's agent worktrees in .claude/worktrees/ are not ignored, so just save (git add -A) would commit them as embedded repositories; add .claude/worktrees/ to the template's .gitignore
