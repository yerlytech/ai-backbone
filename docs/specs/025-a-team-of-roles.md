---
status: draft
date: 2026-10-01
---

# 025 — A team of roles

## What

A project built on the backbone gets a team: named roles an agent takes on,
each with what it reads, what it writes and where, and when it hands over. A
role is a skill, written once in `.agents/skills/`. Codex and Gemini CLI read
that folder, Claude Code reads the copies `just sync-rules` already makes, and
an agent with no skill support at all reads the roster and the role's file.

One new skill, `team`, holds the roster and the rules of handing over. Half
the team exists already under other names; three roles are new:

| Role | Skill | Takes on | Writes |
|---|---|---|---|
| Team lead | the person, with the main session; `team` | who does what; approval at the gates | the journal |
| Product manager | `spec` (exists) | a feature or change bigger than a fix | `docs/specs/` |
| Architect | `spec`, `just adr` (exist) | a choice that is hard to undo | `docs/adr/` |
| Engineer | the main session | building an approved spec | code, tests, `docs/` |
| Reviewer | `audit` (exists) | the end of a phase, a release | verified findings |
| Researcher | `research` (new) | a question the web or the field must answer | `brain/02-research/` |
| Marketer | `marketing` (new) | who a product is for, its promise, site copy, search, ads, launch | `brain/06-marketing/` |
| Data analyst | `data` (new) | a question the product's own numbers must answer | `brain/02-research/` |

Every role file has the same parts: when, inputs, steps, output and its path,
a done check, the handover, and what the role never does. Heavy material
(search, ads, copywriting, launch for the marketer) sits in the skill's
`references/` and is read only when the task needs it, so the roster costs a
few lines of context, not a few pages.

## Why

A person with ideas and no team asks one agent to be everyone, and the work
turns to soup: nobody can say who decided what, which file is current, or what
was handed to whom. The frameworks that give an agent roles (role-based Python
frameworks, hosted builders) bring their own runtime, their own API keys, or a
closed service; the ones that are plain markdown cover building and stop
before selling. The backbone already has the parts for building (spec, adr,
audit). What is missing is the side that turns a built product into a sold
one: research, marketing, numbers.

The rules that keep it from turning back into soup, borrowed from the
frameworks that work:

- Roles hand over through files, never through a chat. A role reads named
  files and writes one named file.
- Every document has one owner role. Another role proposes a change; the owner
  makes it.
- A small job is done directly. A big one goes through the chain
  (research → spec → build → review → marketing), and the person approves at
  each step that commits money, a promise to users, or something public.
- One session plays one role at a time and says which.

## Growth

Small first, built to grow into a full team:

- A project adds a role of its own as a skill in `.agents/skills/<name>/` and
  a row under "Team" in its own `AGENTS.md`. The backbone never touches it.
- A role grows by adding `references/`, not by adding skills.
- A role the backbone does not have (sales, support, legal, design) is added
  to the backbone when two projects have written one, not before.

## Not doing

- No agent framework, no runtime, no API key, no dependency. Markdown only.
- No subagent definitions (`.claude/agents/`, `.codex/agents/`,
  `.gemini/agents/`): the three formats differ and a skill does the job in all
  of them. A later spec may generate thin wrappers for the roles that gain
  from a separate context (researcher, data analyst).
- No copying of third-party skill collections. The role files are written
  here; a reference may link to further reading.
- No project-specific content: a product's audience, voice and keywords live
  in that project's `brain/06-marketing/context.md`, never in the backbone.
- No change to what the person types.

## Questions

- Where does a role write what is meant for the person (research, marketing
  plans, numbers)? Answer I would give: `brain/`, in `brain_lang`, because the
  person reads it and it may hold money and strategy; what code needs stays in
  `docs/` in English; final page and store copy goes into the product's own
  source. Cost: a cloud agent cannot see `brain/`.

## Acceptance

- [ ] `.agents/skills/team/SKILL.md` lists the eight roles with their skill,
      inputs, output path and handover, and the four rules above.
- [ ] `research`, `marketing` and `data` exist, each with the same parts, and
      `marketing/references/` holds search, ads, copy and launch.
- [ ] The manifest lists the four skills; `just template-update` brings them
      into a project and `just sync-rules` copies them to `.claude/skills/`.
- [ ] The brain template lists `06-marketing/`.
- [ ] `just new-project` writes an empty "Team" section into `AGENTS.md` for
      the project's own roles.
- [ ] The self-test checks that every skill in the manifest has `name` and
      `description` and that each role file has the seven parts.
- [ ] `docs/` names the team in one place; the README's table of skills lists
      the new ones.

## Tasks

- [ ] `team` skill and the role template it describes.
- [ ] `research` skill.
- [ ] `data` skill.
- [ ] `marketing` skill and its four references.
- [ ] Manifest, brain template, `new-project`'s AGENTS.md.
- [ ] Self-test checks.
- [ ] Docs, README, CHANGELOG, version.
