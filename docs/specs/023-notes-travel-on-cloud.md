---
status: done
date: 2026-09-29
---

# 023 — Notes travel on cloud, and say they are public

## What

`just backbone-note` sends a note to the backbone's `cloud` branch on GitHub,
never to `main`, and never through the local backbone folder's own checkout:
the note is a commit made on top of what `cloud` has, in a side worktree, so
the folder's branch, unsaved work or half-done rebase no longer matter. When
GitHub cannot be reached the note waits on this machine and goes out with the
next note from a project or the next project session; a line the hooks refuse
is set aside, never sent and never in the way. Every note is told, before it is
written, that
`docs/backlog.md` is on GitHub for anyone to read; a note that carries a path
into a project's `brain/`, an e-mail address or a home folder is refused and
pointed at `just project-note`, which never leaves the machine. The four
backlog lines of 2026-09-28 and 2026-09-29 that carried such text are trimmed
to what the backbone should do.

## Why

The maintainer asked on 2026-09-29: a project sometimes leaves a note for the
other projects through the backbone, and the backbone is public. Measured on
the backlog: no secret, but four lines named private plan files under a
project's `brain/`, the projects those plans were for, and what the maintainer
does with their mail. Nothing told the writer the file is public. And a note
pushed to `main` moves `main` outside the gate: on 2026-09-28 the gate stopped
one run for it ("main moved"), and the merge that followed, under
`merge=union`, put an unticked twin beside eight ticked lines (a tick of the
last lines and a note appended after them are one hunk, and union keeps both
sides; measured again on 2026-09-29 by redoing the merge).

## Not doing

- Rewriting GitHub's history to remove the old text: it has no secret, every
  tag would dangle, and every clone would have to be reset. The maintainer's
  call, asked once, in the report.
- Detecting a project's name or a person's business in a note: no list can.
  The public line and the skill say the rule; the hooks run on the note's
  commit as on any other, and a clone without them sends nothing.
- Changing how a scheduled run's own checkout notes: it still saves the line
  and rides the run's push to cloud (spec 017).

## Questions

## Acceptance

- [x] From a project, `just backbone-note` puts the line on GitHub's `cloud`,
      `main` does not move, and the backbone folder's own files and branch are
      untouched, whatever branch it is on.
- [x] With GitHub unreachable the note is kept on this machine and said so; it
      goes out with the next note, and with the next project session.
- [x] A line the hooks refuse is set aside with their words, never called
      sent, and stops no other line; a clone with no hooks sends nothing and
      names `just hooks-install`.
- [x] A line appended to the box during a send is not lost; a batch a killed
      run left returns to the box; a line `cloud` already has is not sent
      twice; a backbone that is a linked worktree sends the same way; a note
      commit an older backbone left on a clone's `main` is lifted and sent.
- [x] Every note prints one `public` line first.
- [x] A note naming a file under `brain/0…`, an e-mail or `/Users/…` is
      refused, names `just project-note`, and writes nothing anywhere; the
      folder names, a pin with an `@`, a sandbox path and `git@github.com`
      pass; the backlog itself passes the rule.
- [x] The four lines are trimmed; the routine's asks in them stay.
- [x] The skill, the getting-started page and how-it-works say the new route.

## Tasks

- [x] `_notes-send` and the new `backbone-note`; `_backbone-level` sends the
      kept notes and pushes nothing to main; the suite's notes block rewritten.
- [x] The refusal and the public line, with their checks.
- [x] Docs: the skill, getting-started, how-it-works, CHANGELOG 3.30.0; the
      four lines trimmed.
- [x] Reviewed by three independent readers (git flow; portability and privacy; tests and docs), each reproducing its findings; every finding fixed; eighteen checks broken once on purpose, each turning its check red.
- [x] Published; the gate green on three machines (run 36550410007); 3.30.0 on main at cbc54b9 and tagged v3.30.0 (2026-09-29).
