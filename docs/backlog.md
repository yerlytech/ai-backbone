# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-13, n-3c54ee: spec skill, Night specs: say what a night does when it finishes its spec before five hours and the maintainer approved several night specs at once as a series (start the next approved one), and when the next spec's dependency is unmet (skip it, say so in the morning)
- [ ] 2026-10-14, n-ffb8cc: .ai-backbone/examples/stack-rust.just: its clean-own recipe runs cargo clean -p, which cleans only the dev profile; it should also run cargo clean --release -p for each own crate, or a release build made in a git worktree sharing the target dir stays counted fresh and links old code.
