---
status: done
date: 2026-09-19
---

# 011 — level and remembered

## What

The maintainer no longer opens the backbone on their machine: the projects
leave notes, and a scheduled agent in a fresh checkout does the work. So
GitHub becomes the only place the backbone's working memory lives. The local
clone stays, as the bridge the projects' notes cross and as a backup, and it
keeps itself level with GitHub without anyone opening it. The scheduled agent
gets a memory that survives its sandbox (one line per run in
`docs/routine-log.md`), a brief written for the machine it really runs on, and
limits it cannot edit. What is still alive in the backbone's own `brain/` moves
to where that agent can read it.

Closes these backlog lines, all dated 2026-09-19 and from ai-backbone:
"backbone-note never refreshes the clone before it appends", "the backbone's
own session-start prints 'GitHub: up to date.' in three different states",
"backbone-note can say 'sent to GitHub' when nothing was sent", "routine.md
still assumes a machine a person works on", and "routine.md step 6 skips a
backlog line that an approved, unfinished spec says it closes".

## Why

Measured on 2026-09-19 (scratch clones, a bare stand-in remote, git 2.55.0):

- A note written from a project while GitHub has moved is refused, the message
  says "GitHub not reachable", and the clone is left ahead and behind. From then
  on `_backbone-refresh` (`pull --ff-only`) can never bring it level and says
  nothing, every project is compared against a stale tree, and `just publish`
  is refused. The scheduled agent pushes every day, so this is the normal case,
  not the rare one. It happened once for real that morning.
- The backbone's `session-start` prints "GitHub: up to date." after a rebase
  that failed, and leaves the repository in the middle of it.
- The scheduled run writes its report into a `brain/` that vanishes with the
  sandbox: every run starts with "no journal entries yet".
- The stored prompt paraphrases `routine.md` and ends the item search one step
  early, so two truths already disagree.
- Whatever the scheduled agent pushes is pulled to the maintainer's machine at
  the next project session, copied into seven projects by `template-update`,
  and run there outside any sandbox. No hook looks at `routine.md`,
  `.gitignore`, `.pre-commit-config.yaml` or `.claude/settings.json`, and a
  brief that is a file in the repo is a brief the agent can rewrite.

## Not doing

- A second scheduled agent, a local timer, a private repository for `brain/`,
  a GitHub fallback for `template-check` (the clone stays, so it has one).
- The scheduled agent building what changes what a person types, even after
  the maintainer's yes: it marks the line `blocked: decided yes ...` and an
  agent somebody is watching builds it. A line in a file that any project can
  append to must not be able to switch off a limit.
- `merge=union` anywhere but `docs/backlog.md`. Measured: it loses lines in
  entries of more than one line and brings removed lines back.
- Deleting anything in `brain/`, or moving the journals. History stays where
  it is, in the maintainer's language.
- Moving every idea found in `brain/`. About thirty were found; the ones rated
  worth doing move, scrubbed; the rest stay with one line saying why. Nothing
  that names a person, an account, a private project's weakness, a bill or a
  path on the maintainer's machine goes into a tracked file.
- A setup script for the cloud environment: it can only be pasted by hand.
- Anything about reading the outside world. That is spec 012.

## Questions

None open. The maintainer approved the direction on 2026-09-19. Nothing they
type changes; at most one yes/no question a week reaches them (spec 012).

## Acceptance

- [x] A note written while GitHub has moved ends with "sent", and both lines
      are on GitHub. A note that cannot be sent says which of the two it was:
      GitHub moved and the work does not fit, or GitHub was not reachable.
- [x] A clone that is ahead and behind is level again after the next project
      session, with no conflict markers in `docs/backlog.md`.
- [x] A note whose commit a hook refuses says "not saved", never "sent". A note
      from a clone that is not on `main` says so. A note with a newline in it
      writes one line.
- [x] The backbone's `session-start` never prints "up to date" after a failure,
      never leaves `.git/rebase-merge` behind, says "ahead" when it is, and
      tells no person to type a git command.
- [x] When what was pulled touched the scheduled agent's own guard rails, the
      project session that pulled it says which files.
- [x] `routine.md` tells a fresh checkout nothing it cannot do: no journal, no
      brew. It says what to do with a refused push, a line repeated by a
      merge, a line that waits for something (`blocked:`), a line that is the
      maintainer's to decide (`- [?]`, never more than three), and a claim by
      a spec nobody is working on.
- [x] Every run ends with one line appended to `docs/routine-log.md`, and the
      backbone's `session-start` prints the last two.
- [x] The stored prompt points at `routine.md` and carries, itself, the limits
      the agent must not be able to edit. `docs/01-getting-started.md` quotes
      it, so the routine can be made again. One attended run after the change
      was read line by line.
- [x] `just self-test` covers the first four lines above on a bare remote, and
      fails when the backbone stops ignoring `brain/` or loses its `no-brain`
      hook. The self-test hook also fires for `routine.md`, `.gitignore` and
      `.pre-commit-config.yaml`.
- [x] The ideas worth keeping from `brain/` are open lines in `docs/backlog.md`;
      three lessons that lived only in the journal are in the skills and the
      docs; the dead notes in `brain/` say `status: abandoned` and why; the
      newest journal entry says where the living notes went.

Walked line by line on 2026-09-19. Lines 1 to 5, 7 and 9 hold in `just self-test`
(eighteen checks on a bare stand-in remote, the first twelve seen failing on the
old recipes); the "does not fit" half of line 1 was measured by hand on a stand
without the union rule: the message is said, no rebase and no lock are left,
the notes stay saved. 125 forced overlaps of two sessions: none broken. Line 8:
the routine's run of 13:03 UTC was read through its log from the first event to
the report. It read the brief, unshallowed before measuring a claim, skipped the
lines these specs hold and the two that wait for a measurement, did one item
(3.21.1), wrote its log line, pushed to `main` by name, said that its tag was
refused, and touched no guard rail. The maintainer's machine then brought itself
level and tagged v3.21.1 with the new helper. Line 10: the record of what moved
and what stayed, and why, is in the maintainer's vault.

## Tasks

- [x] One helper that brings the clone level (on `main` and clean only; fetch;
      rebase and abort on failure; push what is ahead; say why when it cannot),
      used by `_backbone-refresh`, `backbone-note` and the backbone's
      `session-start`. The guard-rail notice. `.gitattributes`.
- [x] `backbone-note`: refresh, flatten, append, commit, push only what was
      committed, true words.
- [x] Self-test checks on a bare remote; the `brain/` guard check; the hook's
      wider `files:`.
- [x] `routine.md`, `docs/routine-log.md`, the two lines in `session-start`.
- [x] Docs that the change makes untrue: session and backbone-dev skills,
      `docs/01-getting-started.md`, `docs/README.md`. CHANGELOG, version.
- [x] What the review of the change found (three lenses, each finding
      reproduced by a second agent): one at a time in the clone; the tag comes
      from `origin/main`; a note never sends the saved work under it; a
      checkout with no branch; the brief's revert, the yes that looped, the
      lapse in a shallow checkout.
- [x] The stored prompt, then one attended run read through its log.
- [x] The vault, in one attended local session, from a level clone.
- [x] Spec 009 says `done` (every box was ticked and it shipped in 3.7.0); the two
      backlog lines about graphify and Dart agree.
