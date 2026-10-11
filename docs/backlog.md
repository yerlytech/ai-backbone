# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-11, n-9d7b12: just new-project refuses a target folder that exists and is empty, the common case when the person made the folder and opened it in the editor first; it could accept an empty folder, since just adopt there leaves the README, the language rows and the first save undone
- [ ] 2026-10-11, n-343ebd: just ref-add refuses a git bundle file (*.bundle), yet an old repo's only copy is often a bundle; git clone reads one, so just ref-add could clone it into .references/ as it does a repository
- [ ] 2026-10-11, n-ae6ffe: just stack rust leaves target/ out of .gitignore (it only prints the hint section), so the first just save after a cargo build stages gigabytes of target/ and the size check refuses it; two adopted Rust projects added target/ and *.rs.bk by hand. The layer could append its ignore lines the way adopt appends brain/.
