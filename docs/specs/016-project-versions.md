---
status: done
date: 2026-09-23
---

# 016 — project versions

## What

Every project on the backbone has a version of its own, not only the
backbone's. It follows https://semver.org, is written in the project's own
`CHANGELOG.md` after https://keepachangelog.com, and is a git tag `vX.Y.Z` that
reaches GitHub with the backup, the way the backbone's own versions do.

A version is cut **at a meaningful point**: when a spec is done, and when a fix
goes out on its own between specs. The agent cuts it with `just release`; the
person types nothing. The kind of step is read from the commits since the last
version, which already say their kind (conventional commits, enforced by the
commit hook): a `feat` makes the next minor version, fixes alone the next patch.
While a project is below 1.0.0 a breaking change is a minor step too, and
**1.0.0 is cut only on the maintainer's word** (`just release major`).

## Why

The session skill has said since 3.23.0 that a project follows semver and keeps
a CHANGELOG.md, and nothing did it. On 2026-09-23 the maintainer's four projects
on the backbone had no tag and no CHANGELOG between them; the only number each
carried was the backbone's own (3.25.2), which says nothing about the project,
and xlarge's Cargo.toml had said 0.1.0 since its first day. The maintainer asked
for every project's version to follow semver, tagged and backed up like the
backbone's, and chose when it moves: at meaningful points.

## Not doing

- **A version on every save or every push.** Asked and decided: a version marks
  something (a spec done, a fix shipped), not the passage of time.
- **1.0.0 without the maintainer's word.** Nothing computes its way past 0.x.
- **App store versions.** A Flutter or Swift app's `version: 1.2.3+45` is what a
  store counts and has its own recipes (`versions`, `check-versions`); a
  repository's release and a store build are different things.
- **Tags on the backbone's own repository.** They stay as they are, cut by hand
  at each backbone release; this is for projects. (Since spec 017 the gate on
  GitHub cuts them, at the moment it carries a green push to `main`.)
- **Retroactive versions in projects.** A project's history before this is not
  re-tagged by a recipe; its first `just release` starts the line.

## Questions

None open. The maintainer chose "at meaningful points" on 2026-09-23 over "on
every backup" and "only when I say".

## Acceptance

Checked by `just self-test` in throwaway projects, with a bare repository
standing in for GitHub.

- [x] `just release` in a project with no version tag cuts v0.1.0, whatever the
      commits say.
- [x] After that, a `feat` since the last version makes the next minor; only
      fixes (and anything else that is not a feat), the next patch; a breaking
      change (`!` after the kind, or `BREAKING CHANGE:` in the body) the next
      minor below 1.0.0 and the next major from 1.0.0 on.
- [x] `just release major` below 1.0.0 cuts 1.0.0; `just release patch|minor`
      forces that step. Nothing else ever crosses into 1.0.0.
- [x] No commit since the last version: it says so and changes nothing.
- [x] Uncommitted work: it refuses and says why, and changes nothing.
- [x] CHANGELOG.md: created with its header when missing; an `## [Unreleased]`
      section's text becomes the version's entry and an empty one is left
      behind; with none, the entry is drafted from the commit subjects since the
      last version, grouped as Added (feat), Fixed (fix), Changed (perf,
      refactor, revert),
      each subject cut at its first " — " so a long narrative subject gives one
      line. Chores, docs, tests, style, build and ci commits are left out of a
      draft: a changelog is for whoever uses the thing.
- [x] The release is one commit (`chore(release): vX.Y.Z`) through the same
      checks as any save, and an annotated tag `vX.Y.Z` on it.
- [x] A save that reaches GitHub (publish-on-save) and `just publish` carry the
      tags along; with publish-on-save off, nothing leaves the machine.
- [x] A language layer may set the version in its own manifest: the Rust layer
      writes it into the Cargo.toml the workspace reads (`[workspace.package]`
      or `[package]`), and nothing breaks where a layer has no such recipe.
- [x] `doctor` says the project's version and how many commits have come since;
      with no version yet, that the first release will be 0.1.0.
- [x] The spec skill says to run `just release` when a spec is done, and the
      session skill's public-standards paragraph says how versions are cut.

## Tasks

- [x] Save and publish this spec before building.
- [x] `release` in core, `_set-version` in the Rust layer, the tag-carrying
      push in save, the doctor line, the two skills, the docs.
- [x] Self-test checks for every acceptance line, each proven red with its
      thing taken out.
- [x] CHANGELOG entry, version 3.26.0, publish, the maintainer's copy level.
      *Published 2026-09-23, tag `v3.26.0`.*
- [x] The projects: xlarge updated; yerly and yerly-tech updated only (they are
      on hold by the maintainer's choice); games is the maintainer's session.
      *All three on 3.26.0 with `_set-version` in their stack.just; none has a
      version yet — each gets 0.1.0 at its next spec done.*
