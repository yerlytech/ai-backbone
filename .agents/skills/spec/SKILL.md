---
name: spec
description: Turn an idea into a one-page spec in docs/specs before writing code. Use whenever the maintainer asks for a feature, a change larger than a small fix, or says "I want to build X". Covers just spec, filling the template, asking questions one per turn, getting approval, checking the acceptance list before done, and closing the spec.
---

# Spec

Anything bigger than a small fix gets a spec first. One file, one page, English.

## Steps

1. Run `just spec <short-name>`. It creates `docs/specs/NNN-<short-name>.md`
   from the template with the next free number.
2. Fill it in with the maintainer, in their language, then write it in English:
   - **What**: one paragraph, plain words.
   - **Why**: the problem it solves. If you cannot say it, stop.
   - **Not doing**: what is deliberately left out.
   - **Questions**: everything still unclear, as a list.
   - **Acceptance**: how we will know it works. Concrete, testable.
   - **Tasks**: the steps, in order. Small enough to finish one per commit.
     The tests and docs a task calls for go in with it, never into a last
     task that gathers them. A step that waits on something later (a run to
     read, the maintainer's look) is a box of its own. The CHANGELOG and the
     version are not tasks: `just release` writes them once.
3. Set `status: draft` and show the maintainer. Then work through
   **Questions** one per turn: ask one, wait, write the answer into the spec,
   remove the question. Never send a list of questions. A question carries
   the answer you would give and one plain sentence on why it matters to them,
   so that "yes" is an answer. A bare question hands a product owner the
   engineer's homework.
4. When **Questions** is empty, ask for approval. Do not write code before the
   maintainer says it is approved.
5. On approval set `status: approved`, then work through the tasks, ticking
   them off in the file as you go.
6. Before `done`, walk the **Acceptance** list line by line against what was
   built and show the maintainer a short table: holds / not yet. Anything not
   yet met becomes a new **Task**. Tick each line (`- [x]`) as it is checked,
   so the file itself says the list was walked; `just session-start` names a
   done spec with a box still open. A line that cannot hold yet is marked
   `- [~]` and says why on the line. Never call it done on memory.
7. When every line holds, set `status: done` and save. Then `just release`:
   a spec done is the moment the project gets its next version, read from the
   commits since the last one (a spec's work is a `feat`, so the next minor
   while the project is below 1.0.0). 1.0.0 is cut only on the maintainer's
   word, with `just release major`. If the idea is dropped, set
   `status: abandoned` and say why in one line. Never delete a spec.

## Night specs

A night spec is a spec the maintainer approves once, to be built while they
sleep, with no questions on the way. It is a mode beside the handover, and
the maintainer's to choose: you may say a spec would suit a night, but never
mark one on your own.

- **Marking.** `night: yes` in the front matter, under `status:`, and a first
  paragraph saying it is a night spec, with the maintainer's approval in
  their words. `just session-start` names it `(approved, night spec)`.
- **Before the night.** Questions are asked as for any spec, until the
  section is empty; whatever would come up during the night is settled now
  or left to your recommendation, and the spec says which. Order the tasks
  by value, so whatever is left at the end is the least of it.
- **The length.** Five to seven hours, without a break. Look at the clock
  (`date`) when you start and after each task; after five hours, end at the
  first point that suits the work (a task finished and saved), and at seven
  at the latest. Run out of tasks before five and you end there, unless the
  maintainer approved several night specs at once as a series: then start
  the next approved one of it, in their order, and keep to the same clock.
  One whose dependency is not met (a spec it builds on not done, a
  measurement or an answer it needs not there) is skipped, never half
  begun, and named in the morning summary with what it waits for.
- **No questions.** Every choice you would have asked about, you make by your
  own recommendation, and write it down with its reason, in the spec or the
  journal. A choice that belongs to the maintainer is never made this way:
  money, legal text, deleting their files or data, anything a user would
  meet. It goes into the morning summary as a question, and the night goes
  on with the next task.
- **This machine only.** Nothing leaves it but commits to the project's own
  GitHub: no ship, no deploy, no store, no server, and no `just publish`
  where publishing deploys (`just save` then). Builds run at low priority:
  `nice -n 15` and at most 6 jobs (`CARGO_BUILD_JOBS=6`, `make -j6`), unless
  the project's AGENTS.md says otherwise. An audit or a release happens only
  when the night spec names it.
- **The context.** A full context is no reason to stop: "When the context
  fills up" (session skill) does not hold during a night. Where it would
  stop, tick the spec, `just save`, and go on while the tool summarises the
  conversation. After a summary, read the night spec and today's journal
  before the next task.
- **The morning.** Stop at a saved commit, never mid-step. Write the handover
  once, at the end of the night: today's journal, opened with a morning
  summary in the maintainer's language (what was built, what you decided for
  them and why, what waits for their word, the next step), then `just save`
  and `just session-end`, and the same summary, short, as your last message.
  Before a risky step, write the handover first.
- **Never in the backbone itself.** What the backbone publishes reaches every
  project the next morning: a night there runs unattended in all of them.

## Rules

- A spec is public documentation. No secrets, no customer names.
- The spec describes the outcome, not the code. Design details go in
  `docs/adr/` when they are decisions worth remembering.
- A claim about what a pinned thing does names the version it was measured on
  (session skill, "What you know ends on a date"). Never from memory.
- A spec that closes backlog lines names them, so whoever reads the backlog
  next, a person or a scheduled agent, sees they are taken.
