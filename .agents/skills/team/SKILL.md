---
name: team
description: The roles an agent takes on in this repo (product manager, architect, engineer, reviewer, researcher, data analyst, marketer, with the maintainer as team lead), what each reads and writes, and how work passes from one to the next. Use when a request is bigger than one task, when it is unclear which role a job belongs to, when work moves from building to selling, or when adding a role of the project's own.
---

# Team

One agent can be everyone, and that is how work turns to soup: nobody can say
who decided what, which file is current, or what was handed to whom. Here
every job has a role, every role writes one kind of file, and every handover
is a file the next role reads.

## The roster

| Role | Skill | Takes on | Reads | Writes |
|---|---|---|---|---|
| Team lead | the maintainer, with the main session | what is done next and by whom; approval at the gates | `AGENTS.md`, the journal | the journal |
| Product manager | `spec` | a feature or a change bigger than a fix | the idea, research notes | `docs/specs/NNN-*.md` |
| Architect | `spec`, `just adr` | a choice that is hard to undo | the spec | `docs/adr/` |
| Engineer | none: the session itself | building an approved spec | the spec, the code map | code, tests, `docs/` |
| Reviewer | `audit` | the end of a phase, a release | the code, `docs/audit-lenses.md` | verified findings |
| Researcher | `research` | a question the web, the market or the field must answer | the question | `brain/02-research/` |
| Data analyst | `data` | a question the product's own numbers must answer | the question, a named source | `brain/02-research/` |
| Marketer | `marketing` | who a product is for, its promise, copy, search, ads, launch | `brain/06-marketing/context.md` | `brain/06-marketing/`, copy in the product's source |

A role of the project's own is a skill in `.agents/skills/` that this table
does not list; its description starts "The <name> role."

What is meant for the maintainer (research, numbers, marketing plans) goes
into `brain/`, in `brain_lang`: they read it, and it may hold money and
strategy. What code needs goes into `docs/`, in `code_lang`. Copy that ships
goes into the product's own source.

## Four rules

1. **Hand over through files, never through a chat.** A role reads named
   files and writes one. What lives only in a conversation is gone when it
   ends, and the next role, or the next session, never saw it. The notes of
   one effort are found together by their name: a research or data note
   written for an open spec starts with that spec's number
   (`brain/02-research/2026-10-06-026-ghcr-prices.md`).
2. **One owner per document.** The spec is the product manager's, the
   marketing context the marketer's, a research note the researcher's. A role
   that wants another's document changed says so and switches to the owner's
   role to change it; it never edits it on the way past.
3. **Small jobs go direct; big ones go through the chain.** A typo, a fix, one
   headline: do it. A new product, feature or campaign: research, spec, build,
   review, marketing, each step a file. The maintainer approves every step
   that spends money, makes a promise to users, or puts something in public.
4. **One role at a time, said out loud.** When the work is not the engineer's,
   start with the role you are in ("As the researcher: …"). When it moves on,
   say which role takes it and which file it reads.

## The chain

```
idea
 → research      researcher       brain/02-research/   (when facts are needed)
 → spec          product manager  docs/specs/          approved by the maintainer
 → decision      architect        docs/adr/            (when a choice is hard to undo)
 → build         engineer         code, tests, docs/
 → audit         reviewer         findings             (end of a phase, a release)
 → launch        marketer         brain/06-marketing/  approved by the maintainer
 → numbers       data analyst     brain/02-research/
 → the next idea
```

A step with nothing to add is skipped, and the session says which and why.

## A role's file

Every role skill has the same seven parts, so an agent with no skill support
can still follow one by reading the file:

| Part | Says |
|---|---|
| `## When` | the requests it takes, and the ones it leaves to another role |
| `## Inputs` | the files it reads first |
| `## Steps` | what it does, in order |
| `## Output` | the file it writes, and where |
| `## Done` | the check before handing over |
| `## Handover` | which role takes it next, reading what |
| `## Never` | what this role does not do |

Heavy material sits in the skill's `references/` and is read only when the
task needs it, so the roster costs a few lines of context, not a few pages.

## Adding a role

- **A role this project needs:** a skill in `.agents/skills/<name>/SKILL.md`
  with the seven parts and a description that starts "The <name> role.", then
  `just sync-rules`. An update of the backbone never touches it.
- **A role the backbone should have** (sales, support, legal, design): `just
  backbone-note`. It joins the backbone once two projects have written one.
- **Grow a role with `references/`, not with more roles.** Ten roles nobody
  can name is the soup again.

## Roles and subagents

A role is not a subagent. Start a subagent only for a job that gains from its
own context, such as wide research or a pile of numbers, give it the role's
skill to follow, and say how many before starting them.
