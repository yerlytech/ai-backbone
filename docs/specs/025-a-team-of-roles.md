---
status: done
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

- A project adds a role of its own as a skill in `.agents/skills/<name>/`
  whose description starts "The <name> role." The backbone never touches it,
  and the `team` skill says that every role skill it does not list is the
  project's own, so no second list can drift from the folder.
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

None open. Answered by the maintainer, 2026-10-01: start small, on a path that
grows into a full team; a role writes what is meant for the person into
`brain/`, in `brain_lang` (it may hold money and strategy, and the person reads
it); what code needs stays in `docs/`; final page and store copy goes into the
product's own source. The cost, accepted: a cloud agent cannot see `brain/`.

## Acceptance

- [x] `.agents/skills/team/SKILL.md` lists the eight roles with their skill,
      inputs, output path and handover, and the four rules above.
- [x] `research`, `marketing` and `data` exist, each with the same parts, and
      `marketing/references/` holds search, ads, copy and launch.
- [x] The manifest lists the four skills; `just template-update` brings them
      into a project and `just sync-rules` copies them to `.claude/skills/`.
- [x] The brain template lists `06-marketing/`.
- [x] The seed `AGENTS.md` names the team in section 3, so `just
      template-update` lists the rule to a project that lacks it, and stays
      under the size a session loads (7100 bytes with `CLAUDE.md`).
- [x] The self-test checks that each role skill has the seven parts, a
      description that starts "The <name> role." and a row in the roster, and
      that a new project carries the team with its copies for Claude Code.
- [x] A new project's ceiling of tracked files moves from 43 to 59 (the
      maintainer's word, 2026-10-01: the references stay separate files).
- [x] `docs/01-getting-started.md` names the team where it lists the skills.

## Tasks

- [x] `team` skill and the role template it describes.
- [x] `research` skill.
- [x] `data` skill.
- [x] `marketing` skill and its four references.
- [x] Manifest, brain template, the seed `AGENTS.md`.
- [x] Self-test checks.
- [x] Docs, README, CHANGELOG, version.
