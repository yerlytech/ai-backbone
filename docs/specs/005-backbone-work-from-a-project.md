---
status: done
date: 2026-09-14
---

# 005 — backbone work from a project

## What

An agent working inside a project can improve the backbone without leaving
the rules behind. Two modes:

1. **Note.** `just backbone-note "one line"` in any project appends a dated
   line, with the project's name, to `docs/backlog.md` in the backbone. The
   backbone's `just session-start` prints the open lines. The backbone's
   `session-end` reminds the agent to tick what was done.
2. **Fix.** A `backbone-dev` skill, shipped to every project, says how to go
   from a project to the backbone and back: switch to `../ai-backbone`, run
   `just session-start` there, spec it if it is bigger than a fix, change it,
   let the self-test hook run on save, `just publish`, then come back and run
   `just template-update` in the project. The skill also draws the line: which
   fixes the agent makes on its own, and which wait for approval.

AGENTS.md §3 gains two rules. A backbone bug or gap found in a project is
never patched in the project: `just backbone-note`, or the backbone-dev skill,
and the fix is made without asking. When the weekly tool check says a tool is
behind, the agent runs `just tools-update` and saves, without asking.
`just tools-update` also upgrades `just`, `gh` and `uv` through Homebrew when
it is there.

## Why

The maintainer will spend most of their time in the six projects, not in the
backbone, and wants the backbone to get stronger from what those projects
teach. Today a project agent that hits a backbone gap has three bad options:
patch `core.just` locally (erased at the next update), tell the maintainer in
chat (lost), or stop. Notes give the observation a home; the skill gives the
fix a safe path.

## Not doing

- GitHub issues. A file in the repo works offline and travels with the backbone.
- Auto-updating the other projects after a backbone change. `just projects`
  already shows who is behind; the maintainer decides when.
- Any change to the four human commands.

## Questions

None open. The maintainer answered on 2026-09-14: the agent fixes and improves
the backbone without asking; the person's attention belongs to their project.
The agent still asks before anything that changes what the person types or
must do by hand (the four commands, a manual migration step), and before
deleting or installing globally (§7).

## Acceptance

- [x] In a project, `just backbone-note "x"` adds a line to the backbone's
      `docs/backlog.md` with the date and the project's name; running it with
      no backbone nearby says so and changes nothing.
- [x] In the backbone, `just session-start` prints the open backlog lines.
- [x] `.agents/skills/backbone-dev/SKILL.md` exists, is in the manifest's
      `[project]` section, and `just sync-rules` links it for Claude.
- [x] AGENTS.md §3 carries both rules.
- [x] `just self-test` covers the note from a throwaway project.
- [x] The weekly tool table tells the agent to update, not the person to decide.

## Tasks

- [x] `backbone-note` recipe; `docs/backlog.md` with a two-line header.
- [x] `session-start`: open backlog lines when this repo is the backbone.
- [x] `backbone-dev` skill; manifest; sync-rules.
- [x] AGENTS.md §3 line; getting-started page; CHANGELOG 2.2.0; self-test.
