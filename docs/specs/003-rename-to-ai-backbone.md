---
status: done
date: 2026-09-14
---

# 003 — rename to ai-backbone

## What

The backbone is called `ai-backbone`: the GitHub repo, the folder on the
Desktop, the hidden folder in every project (`.ai-backbone/`), the environment
variable (`AI_BACKBONE`), and every sentence that named the old one. The six
projects built on it move over with the same guarantees as the 1.0 move: zip
copy first, `git mv`, nothing of the project's touched, archives byte-identical.

## Why

The docs have said "the backbone" since day one; the repo was called
`ai-first-repo`. Two names for one thing confuse every new agent. The
maintainer chose `ai-backbone` on 2026-09-14: the word they like, plus what it
is for, and no collision with Backbone.js.

## Not doing

- Publishing the six projects. They stay on this machine for now.
- Rewriting history or old CHANGELOG entries. The old name stays where it is
  history.

## Questions

None open.

## Acceptance

- [x] `github.com/yerlytech/ai-backbone` exists; the old address redirects.
- [x] The Desktop folder is `ai-backbone`; `just projects` runs from it.
- [x] No tracked file outside `CHANGELOG.md`, `docs/specs/` and `.archive/`
      mentions `ai-first-repo`, `.ai-first` or `AI_FIRST_REPO`, except the
      migration code and the skill line that handle old projects.
- [x] `just self-test` passes, including a 1.4.0 project moved to `.ai-backbone/`.
- [x] Six projects on 2.0.0: `.ai-backbone/` present, `.ai-first/` gone, archives
      byte-identical before and after, working trees clean.

## Tasks

- [x] Rename inside the backbone; `.ai-first/` -> `.ai-backbone/` with `git mv`.
- [x] Migration block for 1.x projects in `template-update`; self-test fixture.
- [x] CHANGELOG 2.0.0, tag, GitHub rename, push.
- [x] Migrate the six projects with archive fingerprints.
- [x] Rename the Desktop folder; move the agent's memory folder along.
