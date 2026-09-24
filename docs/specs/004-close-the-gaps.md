---
status: done
date: 2026-09-14
---

# 004 — close the gaps

## What

Seven small holes found in a full read of the backbone after 2.0.0, closed in
one minor version (2.1.0). Nothing moves; every project picks it up with
`just template-update` whenever it chooses.

1. `just session-start` prints the latest journal entry in full and only the
   head of the one before. A 39-line entry lost its second half to `head -25`.
2. `.pre-commit-config.yaml` becomes a seed: copied once, then the project's.
   A project can add its formatter there without the next update erasing it.
   The backbone's own copy carries an extra hook: `just self-test` runs
   whenever `core.just` is in a commit.
3. `just ref-add` writes `.references/README.md` when it is missing.
   `just archive <path>` moves a file or folder into `.archive/` with git and
   writes `.archive/README.md` when it is missing. The two guides live in
   `.ai-backbone/templates/`.
4. `just adopt <path>` brings an existing repo onto the backbone from the
   backbone's side: owned files copied, missing seeds added, the project's own
   files never overwritten, `brain/` made ignorable, hooks installed. The
   getting-started page points at it instead of "copy the folder".
5. `just adr <name>` creates `docs/adr/NNNN-<slug>.md` from a template, so the
   spec skill's "design details go in docs/adr/" has a command behind it.
6. `AGENTS.md` §3 says: before saving a change to `core.just`, run `just self-test`.
7. The three Turkish aliases in the seed `Justfile` stay only when the project's
   language is `tr`; otherwise `new-project` removes them and leaves the hint.

## Why

The maintainer asked for an analysis of the backbone and approved every
finding. Each item is a promise the docs or rules already make that the code
did not keep.

## Not doing

- Backups and the dead GitHub remote. Decided later.
- Updating the six projects to 2.1.0. Their choice, `just template-update`.
- Touching the README "Start" steps; they work again once the repo is published.

## Questions

None open. Approved by the maintainer on 2026-09-14.

## Acceptance

- [x] `just session-start` shows every line of the newest journal file.
- [x] `manifest.txt` lists `.pre-commit-config.yaml` under `[seed]`; `just
      template-update` in a project leaves a locally edited copy alone.
- [x] In a fresh project, `just ref-add` creates `.references/README.md` and
      `just archive src/x.txt` creates `.archive/README.md` and `.archive/x.txt`,
      both tracked.
- [x] `just adopt ../repo` on a repo with its own README and `.gitignore`: the
      README is byte-identical afterwards, `.gitignore` ignores `brain/`,
      `.ai-backbone/core.just` and `AGENTS.md` exist, `just doctor` finds nothing
      missing.
- [x] `just adr 'Why sqlite'` in a project creates `docs/adr/0001-why-sqlite.md`.
- [x] A project made with `lang=tr` keeps `alias yedekle`; one made without
      has no Turkish alias.
- [x] `just self-test` passes with the new checks; docs and CHANGELOG say 2.1.0.

## Tasks

- [x] session-start: full latest entry.
- [x] pre-commit config to seed; backbone copy gains the self-test hook.
- [x] templates for the two guides; `ref-add` and `archive`.
- [x] `adopt` recipe; getting-started page.
- [x] `adr` recipe and template.
- [x] AGENTS.md §3 line; alias handling in `new-project`.
- [x] self-test checks, docs, CHANGELOG 2.1.0, version bump, tag.
