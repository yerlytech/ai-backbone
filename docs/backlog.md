# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-06, n-d3573c: A project cannot opt out of the vault copy: _vault-copy sends brain/ and every ignored secret file to the one global ai-backbone.vault-copy folder for every project. Read a per-repo git config (e.g. ai-backbone.vault-copy = off) before the global value, and have doctor say when it is off.
- [ ] 2026-10-06, n-0ed67e: There is no local-only mode: publish still offers to create a GitHub repo, and doctor and stack still suggest ci-init. A per-repo setting (e.g. git config ai-backbone.local-only true) could make publish, publish-on-save and ci-init refuse, add a pre-push hook that refuses every push, and quiet those hints.
