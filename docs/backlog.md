# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-06, n-0db9ff: _build-wait in core.just polls for any cargo or rustc process and waits up to BUILD_WAIT_MINUTES; with several projects on one machine saving often, the waits stack to the limit and then every waiter goes at once (measured: three saves each waited about 20 minutes, then compiled together). A per-machine FIFO lock (flock on a file under the user's cache) would serve builds in order and never release them together.
- [ ] 2026-10-08, n-bf44a6: just save (.ai-backbone/core.just): a commit went through while its tree failed just test-fast, measured right after; the first save was refused by lint, the second passed silently; prek.log keeps only the last run, so which hooks ran is unknown. just save should print each hook's passed or skipped line, or keep the last runs' results
- [ ] 2026-10-09, n-2cd44d: core.just: nothing trims cargo target dirs; on one Mac several Rust workspaces grew past 200 GB each (old incremental crate dirs, cross-target profiles from weeks ago) and filled the disk to 2.7 GB free. Idea: a 'just clean-builds' that removes incremental crate dirs untouched for a day and cross-target or release dirs untouched for a week, safe while a build runs, and a session-start warning when free disk falls under 10%.
- [ ] 2026-10-10, n-98c69c: just save (.ai-backbone/core.just): run the cheap pre-commit hooks (language, secrets, whitespace) before just test-fast, not after; on 2026-10-10 a Turkish name in a test file was found only after the ten-minute suite, twice in a row
- [ ] 2026-10-10, n-7b8c9b: core.just, extends n-2cd44d: trimming by age alone does not keep up (on one Mac the Rust projects wrote about 130 GB of cargo output in a day). _build-wait, which every Rust build passes, could trim the project's own target first: a soft cap per project (60 GB worked here), entries written longest ago removed until 75% of it, never an entry written in the last 6 h, a top-level binary or a profile folder whose cargo lock is held, the cap halved under 15% free disk; it never fails or holds a build, it only logs
