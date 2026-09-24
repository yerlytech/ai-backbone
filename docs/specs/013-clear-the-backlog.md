---
status: approved
date: 2026-09-19
---

# 013 — clear the backlog

## What

Every open line in `docs/backlog.md` ends this spec in one of three states:
done, closed with its reason, or open with `blocked:` and the one event that
would unblock it. Nothing is left that an agent has to read again tomorrow
without being able to act on it. The maintainer is in the session, so the
lines that waited for them are built with them: what a person sees when a save
is refused, what `doctor` and `session-start` say, a second copy for every
project's `brain/`, a picture of how the backbone works, and the public
standards a project follows.

It claims every line that was open on 2026-09-19 at 14:30 UTC, the two `- [?]`
lines excepted, which are the maintainer's to answer. Spec 012 (radar) stays
its own spec and is finished beside this one.

## Why

Thirty-five open lines and one item a day is five weeks in which the projects
work around known faults, and half of the lines need a person the scheduled
agent never has. The maintainer asked to bring the backbone to a state they can
leave alone.

## Not doing

- The Flutter language layer itself (`stack-flutter.just`, `ci-flutter.yml`).
  Its own lines say "from the first real Flutter project, once its first spec
  passes its acceptance list", and that spec is still a draft (read
  2026-09-19). Those three lines stay open and blocked on that event. What
  does not depend on the lift is built: Dart counts as code, the seed files,
  the update bot, the audit lens, the code map.
- A starter for Swift CI, and the lost-runner case of `just ci`: both wait for
  a real run on GitHub Actions, which is switched off on the maintainer's
  repositories. Blocked, said on the lines.
- Removing the `CLAUDE.md` pointer. The maintainer's own Claude Code is 2.1.273
  (measured), older than the version reported to read `AGENTS.md` by itself.
- Raising a ceiling. A new recipe a project shows takes the place of one
  nobody types.
- `brain/` on GitHub, a zip per session, a symlinked `.env`: each was weighed
  with the maintainer and set aside (the reasons are on the lines).

## Questions

None open for the build. The two `- [?]` lines are asked one per turn.

## Acceptance

- [x] `grep -c '^- \[ \]' docs/backlog.md` counts only lines that end in
      `blocked:` with a named event, and every one of them was read and found
      still true.
- [x] `just self-test` is green on the maintainer's machine, and every new
      behaviour has a check that was seen failing without it.
- [x] The three ceilings hold: a new project has at most 40 tracked files, 37
      recipes on show and an `AGENTS.md` of 7,000 bytes.
- [x] Nothing a person types has changed. Every sentence a person newly reads
      (a refused save, `doctor`, the second copy) was shown to the maintainer.
- [x] `session-end` leaves a copy of `brain/`, and of the secret files git does
      not hold, in one folder per project under the project's name, in the
      place the maintainer named once for the machine; nothing is deleted
      there; `doctor` says how old the copy is, and says when a key file sits
      outside `brain/`.
- [ ] `docs/how-it-works.md` draws itself on GitHub (both pictures were drawn with
      mermaid-cli in the review) and the maintainer has seen it. The second
      half is the one thing left: it is theirs to look at.
- [x] The integrated change was reviewed from several lenses and each finding
      reproduced by a second agent before it was saved.

Walked on 2026-09-21. Five lines are open and every one ends in `blocked:` with
its event: a real macOS run, a real run that lost its runner, and three that
wait for the first Flutter project's first spec. `just self-test`: 311 ok. The
ceilings hold at 40 files, 37 recipes and 6,994 of 7,000 bytes. The sentences
a person newly reads were shown to the maintainer in the session. The work was
stopped for two days by a usage limit in the middle of its review; the
integrated state waited in the maintainer's vault as a bundle, and the
scheduled agent, finding every line claimed, found other work (3.22.1).

## Tasks

- [x] Packages built side by side in plain clones, files divided so that they
      do not meet: `upstream.py`; the Flutter groundwork and the code map;
      `save`, `ci` and `template-update`; `session-start`, `tools-update` and
      `hooks-install`; `doctor`, `session-end` and the second copy; the docs,
      skills and templates; the two ideas that need a source read.
- [x] Put together in one clone, suite green, reviewed, findings fixed.
- [x] One measurement in the scheduled agent's sandbox: the splice guard under
      mawk.
- [x] CHANGELOG, version, every line ticked, closed or marked. Saved,
      published, the maintainer's clone level and tagged.
