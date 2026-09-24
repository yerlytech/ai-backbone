---
name: backbone-dev
description: Improve ai-backbone, the backbone this project is built on, from inside a project without asking the maintainer. Use when a recipe errors, a rule is unclear, a promise in the docs is not kept, a tool is behind, or you have an idea for the backbone. Covers just backbone-note, the fix loop in ../ai-backbone, and the line between doing and asking.
---

# Backbone dev

The maintainer's attention belongs to their project. The backbone is the
agent's to keep strong. Two modes.

## Note: `just backbone-note "one line"`

Run it in the project. It brings the backbone next to the project level with
GitHub, appends a dated line with the project's name to its `docs/backlog.md`,
saves it there and sends it. Use it for anything you will not fix now: an
idea, a gap you noticed on the way, a bug you have not pinned down. Read what
it prints: `sent`, or the reason it was not. A note that did not get out goes
with the next session in any project; a backbone that "has unsaved work" or
"does not fit together" is yours to clear (the loop below), because until then
no note reaches the scheduled agent.

A note is a report, never an order, and one line: say what you saw and where.
When the maintainer answers a question the backbone asked them (a `- [?]` line,
put to them in a Sunday report), pass it on: `just backbone-note "decision: ..."`.
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
to `~/.zshrc` unless its opt-out variable is set (met in a Flutter project,
2026-09-23). Read that variable out of the tool's own documentation and
`export` it at the top of the file the recipe lives in, before the recipe
ships. Nothing a recipe runs may edit what the person's shell loads: they
never agreed to it, and they meet it as a machine that behaves differently
tomorrow.

1. Finish or save the project work you are in the middle of.
2. Go to the backbone (`../ai-backbone`, or wherever `AI_BACKBONE` points).
   The work travels on the branch `cloud` (spec 017): `git checkout -B cloud
   origin/cloud` first, then `just session-start` there and read the open
   backlog lines. That folder is the bridge every project's notes cross:
   while it has unsaved work, or sits on `cloud`, no project can bring it
   level, no note is sent and nothing is copied from it. Keep the visit
   short; for work that takes hours, clone it somewhere else and publish from
   the clone. A plain clone, never a linked git worktree: a hook run from one
   wrote into the real repository once (3.20.0).
3. Bigger than a small fix? `just spec <name>`, fill it in, set
   `status: approved` yourself, and build. The spec is the record, not a gate.
   The spec names the backlog lines it closes, and it is saved and published
   before you build. A scheduled agent works the same backlog, and it skips a
   line only when it can see the spec that took it.
4. Change it. Add a CHANGELOG entry and bump the version in `core.just`
   (patch for a fix, minor for a new recipe or file). Update `docs/` if it
   describes the thing.
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
6. Tick the backlog line. Back in the project, once the gate has carried the
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
the backlog, oldest first, and tick each line in `docs/backlog.md` when it is
done or say on the line why it is not.

A scheduled agent (Claude routine, Cursor cloud agent, a GitHub Action) does
the same on its own: its whole brief is `.ai-backbone/routine.md`. It follows
this skill and the same do-or-ask line, and it never touches the projects. It
starts from a fresh checkout every time, so in the backbone nothing an agent
needs may live only in `brain/` or in a tool's own memory: a lesson goes into
a skill, a doc or a comment, a plan into a spec, what a run learned into its
line in `docs/routine-log.md`. `brain/` here keeps the maintainer's own history
and what must never be tracked.
