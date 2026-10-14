# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-13, n-3c54ee: spec skill, Night specs: say what a night does when it finishes its spec before five hours and the maintainer approved several night specs at once as a series (start the next approved one), and when the next spec's dependency is unmet (skip it, say so in the morning)
- [ ] 2026-10-14, n-ffb8cc: .ai-backbone/examples/stack-rust.just: its clean-own recipe runs cargo clean -p, which cleans only the dev profile; it should also run cargo clean --release -p for each own crate, or a release build made in a git worktree sharing the target dir stays counted fresh and links old code.
- [ ] 2026-10-14, n-f7e10e: buildtrim.py (spec 027) removes the oldest pieces first, and the oldest are the dependencies a project still builds against: they are compiled once and never written again. With sccache at its default 10 GiB shared by several Rust projects (Rust hit rate 6%), one trim past the cap cost a 40+ minute rebuild of every dependency. Remove first the pieces whose crate has a newer piece under another hash; and have doctor say when sccache's max size is below the sum of the caps, since the cap assumes the cache can bring the dependencies back.
- [ ] 2026-10-14, n-cdec6e: Correction to n-f7e10e (buildtrim order): the 40-minute rebuild cited there was mostly a stable toolchain change the same hour (1.98.1 to 1.99.0), which rebuilds every dependency and misses sccache anyway. The point stands on its own (the oldest pieces are the dependencies still in use), but without that number as its cost; measure one trim on an unchanged toolchain before acting.
