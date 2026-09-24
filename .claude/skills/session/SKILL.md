---
name: session
description: How to start and end a work session in a repo built on ai-backbone. Use at the beginning of every session, before the first edit, and again before the last save. Covers just session-start, the journal in brain/, just session-end, what to do when something the project is built on has moved or is newer than what you know, and the public standards a project follows for versions, its changelog and commit messages.
---

# Session

## Start

1. Run `just session-start`. It prints the last two journal entries, recent
   commits, the working tree, what the project is built on, and whether the
   backbone has updates.
2. Read the journal before touching code. A note marked `status: abandoned`
   is history, not a plan.
3. If the working tree is dirty, ask what it is before building on it.

## Before a long build

One machine often builds several projects at once: an IDE window each, and
you in a terminal. Before a command that compiles a lot (the tests, a release
build, lint over a workspace), look for a build already running and wait for it
to end rather than starting a second one beside it. Two builds that share a
folder wait on one lock anyway, and two at once can run the machine out of
memory when they link. `just _build-wait` looks for the compilers the language
layer names and waits; the Rust layer's heavy recipes already call it, and
`BUILD_WAIT_MINUTES=0` switches it off.

## What you know ends on a date

An agent is trained up to a day. A version released after it is one the agent
cannot know, and it will not say so: it remembers the version before and
answers as if it were this one. So nothing this project pins — the watch list
in `docs/upstream.toml` first, but a lockfile pin too — is used from memory.

With a watch list, every `just session-start` prints what the project is built
on and which of those pins came out in the last twelve months, with dates, from
the weekly check's cache. With none it prints nothing about pins, which means
nobody is watching, not that nothing is new: `just upstream-init` starts the
list. A version released after your training ended is one you do not know. The
list stops at twelve months: if your training ended before that, or you cannot
say when it ended, treat every pin as newer than you. A pin it calls
`not known yet` has no date on this machine, which is not the same as old:
treat it as newer than you until `just upstream` has reached its source. Three
ways to know, cheapest first:

1. `just upstream <name>`: what it released between the pin and today, and
   where the pinned version itself can be read on this machine — the source
   folder, its changelog, the docs (a watch may carry `docs = "url"`).
2. That source. A signature, a default, a behaviour you are about to rely on:
   find it there first. When it is not there, the memory was of another version.
3. A test, run against the pinned version and kept.

The decision that rests on it says so in the ADR —
`measured on <name> <version>`, with the date; the template has the line. A
claim without it is a memory, and a memory is older than the pin.

## When something upstream has moved

Once a week `just session-start` prints what the things this project is built on
have released since it pinned them — the language, the database, the framework,
the protocol — from `docs/upstream.toml`. Start that list with
`just upstream-init` in a project that has none.

A version number is the least useful half of the answer, so do not report one.

1. `just upstream <name>` prints that project's own release notes. Read them.
   It also lists where the pinned version itself lives on this machine: the
   source folder, its changelog, the docs.
2. Say, in one short paragraph per thing that moved: what changed, whether it
   touches anything this project does, and what following it would cost. The
   `check` line in the watch list says what to look at.
3. Nothing is upgraded because it is newer. An upgrade is work like any other:
   it gets a spec, or a task in the open one, and a test that proves the thing
   it changed still holds.
4. A pin marked `MOVED` means the file no longer holds that version — the watch
   list has drifted from the code. Fix the list first; it is lying.
5. A release that matters and cannot be taken yet is written down where it will
   be seen again: a line in the journal, or a task in the spec. Not in chat.

### Before following one upstream, pin what would break in silence

A compiler catches a renamed function. It does not catch a library that still
compiles and now computes something else, and that is the upgrade that costs a
weekend. So before changing the version, write the test that would fail if the
behaviour changed, and watch it pass on the version you already have.

Three kinds are worth the ten minutes, every time:

- **What is already stored.** A password hash, a signature, a saved document, a
  cached shape: put a real one, produced by the version in use today, into the
  test verbatim, and assert the new version still reads it. This is the failure
  that locks people out of their own data, and its only symptom is that the
  right password stops working.
- **What was computed and written down.** A digest, a checksum, an identifier, a
  rounded total. Assert the exact value, checked against something that is not
  the library being upgraded — another implementation, a published test vector,
  a number worked out by hand. A test that asks the library what it computes and
  then asserts that is a test that agrees with any answer.
- **What somebody else is holding.** A protocol version, an on-the-wire shape, a
  file format. If an older client or an earlier file must keep working, say so
  in a test before the upgrade, not after the complaint.

Then upgrade. A guard test that passes on both versions is the evidence the
upgrade was safe; one that fails has just paid for itself. Keep them: they are
the record of what this project promised to keep working.

## End

1. Run `just session-end`. It creates today's journal file from the template,
   and copies `brain/` and the secret files git ignores to this machine's place
   for second copies (`<place>/<project>/`, nothing is ever deleted there). When
   it says the machine has no place yet, ask the maintainer once for a folder (a
   folder in a cloud drive, a second disk), then
   `git config --global ai-backbone.vault-copy "<folder>"`. They type nothing.
2. Fill the journal in the maintainer's language (`brain_lang` in AGENTS.md):
   what changed, why this way, open questions, next steps.
3. If code changed something `docs/` describes, update `docs/` now.
   `just stale` lists every line of the docs that names a path no longer here.
   When you rename or move a file or folder, add it to `docs/renames.toml`
   (`[[rename]]` with `old`, `new` and `date`), and it finds the lines still
   using the old name too. Record a planned layout that changes before it was
   ever committed the same way: stale only knows a path was real if git once
   held it, and on the project this came from that was 1 of the 51 stale lines. A decision that changes an earlier one is written
   with `just adr <name> --amends NNNN`, which points the old one at it.
4. If the backbone got in the way this session (a recipe that erred, a rule
   that was unclear, something missing), `just backbone-note "one line"` for
   each, or fix it there now (backbone-dev skill). Do not ask.
5. Run `just save "<message in code_lang>"`. Never leave uncommitted work.
6. When step 1 said `brain/ copied`, run `just session-end` once more: the copy
   is taken when the command runs, and the entry was still empty then.

## Before many agents

Every subagent draws on the same weekly limit as the session, and nobody can
ask Claude how much is left from inside a session. So the first line of
`just session-start` says what this machine can know: about what percent of the
week is used (Claude Code's own meter, and how old it is), how many days to the
reset, and how many subagents this session may start on its own. That number is a cap a
hook enforces for the day, the person's own setting (8 unless they changed it)
or less when the week is ahead of its pace: the next one is refused, and the
refusal tells you to ask. Before you start more than a few, say how many and roughly what share of
the week it is, in the person's language, and wait. A yes lifts the cap for
this session (`just _agent-cap <cap> <folder>`, the folder is in the refusal);
"for every session on this machine" is `git config --global ai-backbone.agent-cap`.
The person's work pattern is one setting, asked once: `ai-backbone.weekend`,
`rest` (the default: the days left are weekdays) or `work`. Whatever your
effort setting or mode says, the cap and the ask hold. A reviewer that verifies
its own findings costs half of one skeptic per finding and finds the same
(measured); prefer it.

## Public standards

A project built on this follows three public standards, so that the next agent
and the next person find what they expect without being told. Version numbers
follow https://semver.org: the first version is 0.1.0, and 1.0.0 is the first
one other people rely on. From its first version on, the project keeps a
`CHANGELOG.md` in its root after https://keepachangelog.com: newest first,
written for whoever uses the thing. A version is the project's own, not the
backbone's, and it is cut at a meaningful point: `just release` when a spec is
done, and `just release patch` when a fix goes out on its own between specs.
It reads the step from the commits since the last version, writes the
CHANGELOG entry (from an `## [Unreleased]` section if one was written, else a
draft from the commits), tags `vX.Y.Z`, and the tag goes to GitHub with the
backup. The person types none of it. Only the maintainer's word crosses into
1.0.0 (`just release major`). Commit messages follow
https://www.conventionalcommits.org: the commit hook refuses a message without
its kind at the front (`feat`, `fix`, `docs`, `chore`, `test`, `refactor`,
`style`, `perf`, `build`, `ci`, `revert`), and `just save` writes `chore:` for
a message that names none.

## Rules

- The journal is the only memory that survives between sessions. Write it.
  (The backbone's own scheduled agent has no journal; the backbone-dev skill
  says where its memory is.)
- Commit messages are in `code_lang`. The journal is in `brain_lang`. Never mix.
