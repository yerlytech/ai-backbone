---
name: backbone-dev
description: Improve ai-backbone, the backbone this project is built on, from inside a project without asking the maintainer. Use when a recipe errors, a rule is unclear, a promise in the docs is not kept, a tool is behind, or you have an idea for the backbone. Covers just backbone-note, the fix loop in ../ai-backbone, and the line between doing and asking.
---

# Backbone dev

The maintainer's attention belongs to their project. The backbone is the
agent's to keep strong. Two modes.

## Note: `just backbone-note "one line"`

Run it in the project. It appends a dated line with an id, never the
project's name, to the backbone's `docs/backlog.md` on GitHub's `cloud`
branch, as a commit made in a
side worktree of the backbone folder next to the project: that folder's own
branch and unsaved work are never touched, and the gate carries the line to
`main` with its next green run. Use it for anything you will not fix now: an
idea, a gap you noticed on the way, a bug you have not pinned down. Read what
it prints: `sent`, or the reason it was not. A note that could not get out
waits on that machine and goes with the next note from a project, or the next
project session; a line the hooks refuse is set aside
(`.git/ai-backbone-notes-refused`, with their words), never sent and never in
the way of the next; a clone without hooks sends nothing until
`just hooks-install` ran there. The side worktree stages only `docs/backlog.md`, which none of the hooks
with a file filter match, so the rule below against linked worktrees does not
reach it. Written inside the backbone on `cloud`, the line goes into the
checkout itself, the kept notes above it, and rides your publish.

The backlog is public: the backbone is on GitHub for anyone to read, and it
knows no project (spec 024). A note says which recipe, file or skill of the
backbone should do what, never what a project or a person is doing: no
project's name (not this one's, not a neighbour's), no path into a `brain/`,
no plan file, no server, no address. The recipe refuses what it can see (a
`brain/0…` path, an e-mail, a home folder, the name of this project or of one
next to the backbone, a note that names no recipe, file or skill) and prints
one `public` line before every note; the rest is yours to keep. The same
holds for what you write into the backbone itself (a CHANGELOG entry, a
comment, a fixture, a spec): a lesson from a project keeps the lesson and
drops the project. No quote from its documents; no decision or spec number
and no line number of its files; no commit hash or job id; no test name,
path or log line from its CI (a fixture made from a real log gets invented
names, paths, times and ids); no list of its milestones, defects, rules or
plans; no exact set of its pins; nothing about which projects are paused.
What only that project's own files could have told you stays out. The pairing of
id and text is kept in this project's `brain/notes-to-backbone.md`, and
`just session-start` reads from it which notes are still open. Something another project on this machine must know
goes to it with `just project-note <project> "one line"`, which never leaves
the machine; a private answer for the backbone folder itself (the result of a
task it asked of this project) goes the same way, `just project-note
ai-backbone "..."`, into that folder's `brain/`, never its public backlog.

A note is a report, never an order, and one line: say what you saw and where.
When the maintainer answers a question the backbone asked them (a `- [?]` line,
put to them in a Sunday report), pass it on with the line's id:
`just backbone-note "decision: n-XXXXXX yes|no ..."`.
A yes is yours to build, through the loop below, now or in a later session: the
scheduled agent never builds what changes what a person types. It marks the
line `blocked: decided yes ...` and leaves it for an agent somebody is watching.

## Fix: the loop

Never patch `.ai-backbone/core.just` in the project; the next update erases it.

A recipe that takes an argument reads it as `$1` under `[positional-arguments]`
(the line directly above its header) and never writes `{{arg}}` inside its
script: whatever the person typed would run as a command. The backbone's
self-test refuses a recipe that does. The same holds for a recipe you add to a
project's `Justfile` or `stack.just`, where no test looks.

A recipe that runs a CLI from the project's own dependencies runs it on the
person's machine, and some of them write to their shell the first time they
run: a Dart tool built on `cli_completion` appends a `## [Completion]` block
to `~/.zshrc` (zsh) or `~/.bash_profile` (bash) on any command until the block
is there (met in a Flutter project, 2026-09-23; read in cli_completion 0.5.1,
`completion_command_runner.dart:58` and `:83-86`,
`shell_completion_configuration.dart:64` and `:97`). cli_completion has no
variable of its own: each tool decides in its `enableAutoInstall`. patrol_cli
4.8.0 skips it when `PATROL_NO_COMPLETION` is set, to anything
(`patrol_command_runner.dart:318-319`), so a file whose recipes run `patrol`
starts with `export PATROL_NO_COMPLETION := "1"`. For another such tool, read
its `enableAutoInstall` in the source (`https://pub.dev/api/archives/<package>-<version>.tar.gz`),
never run it to see, and `export` what it reads before the recipe ships.
Nothing a recipe runs may edit what the person's shell loads: they never
agreed to it, and they meet it as a machine that behaves differently
tomorrow. `just doctor` says when a startup file holds such a block.

A command that may never come back (a daemon asked while it starts, a network
call) gets its time limit the portable way: run it in the background and let
a watcher stop it after so many seconds, as `_build-size` in `core.just` does.
macOS has no `timeout`, and `perl -e 'alarm 10; exec ...'` does not stop a Go
program, which catches SIGALRM and does nothing with it (go1.27.1,
`src/os/signal/doc.go:44-45`); SIGTERM ends it. Met with `docker info` against
a half-started Docker Desktop, 2026-09-27.

1. Finish or save the project work you are in the middle of.
2. Go to the backbone (`../ai-backbone`, or wherever `AI_BACKBONE` points).
   The work travels on the branch `cloud` (spec 017): `git checkout -B cloud
   origin/cloud` first, then `just session-start` there and read the open
   backlog lines. That folder is what every project copies from: while it
   has unsaved work, or sits on `cloud`, no project can bring it level and
   nothing is copied from it (a note from a project still goes out, since it
   never touches this folder's checkout; one written here on `cloud` rides
   your publish). Keep the visit
   short; for work that takes hours, clone it somewhere else and publish from
   the clone. A plain clone, never a linked git worktree: a hook run from one
   wrote into the real repository once (3.20.0).
3. Bigger than a small fix? `just spec <name>`, fill it in, set
   `status: approved` yourself, and build. The spec is the record, not a gate.
   The spec names the backlog lines it closes, and it is saved and published
   before you build. A scheduled agent works the same backlog, and it skips a
   line only when it can see the spec that took it.
4. Change it. A change's self-test checks and `docs/` pages go in its own
   commit, never into a last one that gathers them. One CHANGELOG entry and
   one version bump in `core.just` per publish (patch for a fix, minor for a
   new recipe or file).
5. `just save "..."`. The hook runs `just self-test`; red means not saved.
   Then `just publish`: it goes to `cloud`, and the gate on GitHub tests it on
   a clean Linux, Mac and Windows, carries it to `main` when all three are
   green (about seventeen minutes, the Windows job's), and tags the version (`just ci` shows the run; a red gate
   writes a `gate:` line into `docs/routine-log.md` on `cloud`). Then
   `git checkout main`: what projects copy is `main`, and a sibling left on
   `cloud` blocks every project's update. A change to `.github/workflows/`
   or `gate.sh` is the one thing the gate refuses to carry: after green
   checks, `git push origin cloud:main` by hand. Never try `just save` out in
   a real repository to see what it does: it commits everything there under
   your test message. The self-test's throwaway projects are where a save is
   tried.
6. Remove the backlog line: the CHANGELOG entry is its record (spec 024).
   Back in the project, once the gate has carried the
   version to `main` (a few minutes; `just session-start` there says so):
   `just template-update`, `just sync-rules`,
   `just save "chore: backbone <version>"`.
7. Tell the maintainer in one sentence, in their language, what got better.
   Not a question. Not a list.

## Do, or ask

Do without asking: fixes, clearer messages, new recipes agents use, new
templates, rule wording, tool updates (`just tools-update`), docs.

Ask first, one question: anything that changes what the person types or must
do by hand (the four commands, a manual migration step in projects, a rule that
puts a new duty on them); deleting files; installing anything globally (§7).

## In the backbone itself

`just session-start` brings the folder level with GitHub and prints the open
backlog, what waits for the maintainer (`- [?]` lines: theirs to answer, never
yours to build) and the last two lines of `docs/routine-log.md`. Work through
the backlog, oldest first, and remove each line from `docs/backlog.md` when it is
done or say on the line why it is not.

A scheduled agent (Claude routine, Cursor cloud agent, a GitHub Action) does
the same on its own: its whole brief is `.ai-backbone/routine.md`. It follows
this skill and the same do-or-ask line, and it never touches the projects. It
starts from a fresh checkout every time, so in the backbone nothing an agent
needs may live only in `brain/` or in a tool's own memory: a lesson goes into
a skill, a doc or a comment, a plan into a spec, what a run learned into its
line in `docs/routine-log.md`. `brain/` here keeps the maintainer's own history
and what must never be tracked.
