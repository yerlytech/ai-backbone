---
status: done
date: 2026-09-16
---

# 009 — lint before save

## What

Every project on the backbone gets one more git hook: whatever `just lint`
runs in that project, it runs before the commit. The hook is quiet in a
project that has no `lint` recipe yet, and it skips commits that touch only
Markdown or `docs/`. Nobody types anything new: `just new-project`,
`just adopt` and `just stack <lang>` put the hook in, and `just stack <lang>`
adds it to a project that already has a language layer.

## Why

A project that ran `just stack rust` has `just lint` (clippy and
`cargo fmt --check`) but no hook that runs it. `just save` therefore commits
code that `just lint` rejects, and the failure surfaces later, in CI or in
the next agent's session. Yerly XL committed a clippy failure this way on
2026-09-15 and filed the backlog line this spec closes. The stack example
only mentioned the hook in a comment block the person was expected to copy
by hand, which is exactly the manual step the backbone promises not to ask
for.

## Not doing

- Putting `cargo clippy` in the hook config. The hook calls `just lint`, so
  the language layer stays the one place that knows the commands.
- Touching `just save`, `just doctor` or their messages.
- A new hook for `just test`. Tests can be slow and can need a database; a
  commit must stay cheap.
- Reaching into existing projects. They pick the hook up the next time an
  agent runs `just stack <lang>` there.

## Questions

None open. The backlog line is the request; nothing here changes what the
maintainer types.

## Acceptance

- [x] In a fresh project, `.pre-commit-config.yaml` carries a `lint` hook and
      `just save` still works with no `stack.just` present.
- [x] With a `lint` recipe that fails, `just save` refuses the commit and
      shows why; with one that passes, the commit goes through.
- [x] A commit that touches only Markdown does not run lint.
- [x] `just stack rust` in a project that already has `stack.just` adds the
      missing hook instead of only printing an error.
- [x] The hook is added at most once, and a broken append is rolled back.
- [x] CHANGELOG entry, version 3.7.0, self-test green.

## Tasks

- [x] `_lint-if-any` and `_hook-lint` in `.ai-backbone/core.just`.
- [x] Call `_hook-lint` from `new-project`, `adopt` and `stack`.
- [x] `stack` self-heals when `stack.just` already exists.
- [x] Drop the copy-this-by-hand comment from `stack-rust.just`.
- [x] Self-test checks, docs, CHANGELOG, backlog tick.
