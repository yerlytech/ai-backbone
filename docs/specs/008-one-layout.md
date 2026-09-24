---
status: done
date: 2026-09-14
---

# 008 — one layout

## What

Every project built on the backbone looks the same from the root: nine
things. All code under `src/`, split by part when there are several. Public
brand material in `docs/brand/`. Private files in `brain/05-files/`.
`just doctor` names anything that strays. The six existing projects are moved
onto it, builds verified, history kept with `git mv`.

## Why

Six projects had four layouts and one root with thirty entries. An agent
opening a project spent its first minutes guessing where the code was, and the
maintainer saw clutter. The maintainer asked for one standard on 2026-09-14.

## Not doing

- A `just tidy` that moves files by itself. Every project's build is different;
  an agent moves with the build in front of it.
- Touching the language layers' conventions inside `src/<part>/`.

## Questions

None open. Approved on 2026-09-14 ("tüm önerilerini uygula").

## Acceptance

- [x] In a fresh project, `just doctor` says "ok root holds only what belongs
      there"; with a stray file it names it.
- [x] Each of the six projects: root is within the allowed list, `just doctor`
      clean, the project's own check or build passes (or the report says which
      one could not be run and why).
- [x] `git log --follow` still reaches a moved file's history.
- [x] Docs describe the layout; CHANGELOG 3.4.0; self-test passes.

## Tasks

- [x] Backbone: `_root-strays`, doctor line, brain `05-files/`, docs, self-test.
- [x] yerly, yerly-tech, xlarge, duybu, randoms, solball: move, fix paths, verify, save.
