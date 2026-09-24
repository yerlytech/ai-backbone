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
   yet met becomes a new **Task**. Never call it done on memory.
7. When every line holds, set `status: done` and save. Then `just release`:
   a spec done is the moment the project gets its next version, read from the
   commits since the last one (a spec's work is a `feat`, so the next minor
   while the project is below 1.0.0). 1.0.0 is cut only on the maintainer's
   word, with `just release major`. If the idea is dropped, set
   `status: abandoned` and say why in one line. Never delete a spec.

## Rules

- A spec is public documentation. No secrets, no customer names.
- The spec describes the outcome, not the code. Design details go in
  `docs/adr/` when they are decisions worth remembering.
- A claim about what a pinned thing does names the version it was measured on
  (session skill, "What you know ends on a date"). Never from memory.
- A spec that closes backlog lines names them, so whoever reads the backlog
  next, a person or a scheduled agent, sees they are taken.
