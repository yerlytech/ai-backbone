---
status: approved
date: 2026-09-19
---

# 012 — radar

## What

Once a week the scheduled agent that maintains the backbone looks outward
instead of at the backlog: on Sunday its one item is to read what the things
the backbone stands beside have published (Claude Code, OpenSpec, Spec Kit, the
AGENTS.md and Agent Skills standards, Gemini CLI) and to leave what matters as
`idea:` lines in `docs/backlog.md`, written with `just backbone-note`. The
ordinary runs then reach those lines in their turn, oldest first, behind the
projects' own notes. Same agent, same schedule, same brief; no new file a
person has to know about. Builds on spec 011.

## Why

The backbone borrowed from OpenSpec and Spec Kit on the day they were cloned
and has not looked since: the brief reaches the references only when the
backlog is empty, and the stored prompt stopped one step before that. The
sandbox cannot read other repositories' releases either: its GitHub proxy
answers only for the repository attached to the session, and everything else
gets a 403 by design (code.claude.com/docs/en/cloud-environments, read
2026-09-19). Files on raw.githubusercontent.com are on the default allowlist;
whether a read from inside the sandbox works is not measured yet. Meanwhile the
tools move weekly. Claude Code 2.1.277 is reported to read `AGENTS.md` when
there is no `CLAUDE.md`, and Junie's docs are reported to call
`.junie/guidelines.md` the legacy format: two files the backbone generates may
have become removable, and nothing would ever have said so.

## What the sandbox can reach

Measured on 2026-09-19 with a one-off run in the routine's own environment that
changed nothing (48 seconds; every body thrown away, only codes kept):

| From inside the sandbox | Answer |
|---|---|
| `api.github.com` for a repository not attached to the session | 403, as the docs say; 200 for this repository |
| a ranged read (`curl -r 0-999`) of a file on `raw.githubusercontent.com` | 206 for all eleven: the CHANGELOGs of just, prek, graphify (branch `master`), Claude Code, OpenSpec and Spec Kit, the Agent Skills specification, the AGENTS.md README, Gemini CLI's `latest.md`, Copilot's reusable, superpowers' release notes |
| `git ls-remote --tags` of a public repository not attached | works, for all four of the backbone's own tools |
| `git clone --depth 1` of a public repository not attached | works, so `just ref-fetch` would |
| PyPI, pub.dev, crates.io, npm, code.claude.com | 200 |
| `cursor.com`, `junie.jetbrains.com`, `go.dev` | refused by the egress proxy |
| on the machine | git, curl, python3, uv, go; no `gh`, and no `just` or `prek` until `setup.sh` runs |

So the radar reads raw files, and `just upstream` can see all four tools
through their tags: a fallback inside the GitHub source ("the API refused: list
the tags with git"), no new source kind. gitleaks has no changelog file at all
(404 on both branches, measured from the maintainer's machine), which is why
tags and not raw files are the way for the four.

## Not doing

- A second scheduled agent, a `docs/ideas.md`, a new source kind in
  `upstream.py`, a rotating source list, a day of the week for building ideas.
  Four skeptics took each of these out on 2026-09-19; the reasons are in the
  maintainer's vault.
- Reading skills, prompts or command templates unattended. Changelogs, release
  notes and the hash of a specification file only: text written to instruct an
  agent is the riskiest thing an agent with a push right can read.
- A network wider than the default. Cursor's, Junie's and Codex's own pages are
  out of reach in the sandbox; an idea that rests on them is marked
  `needs a local session`.
- Building what changes what the person types. Such a line becomes `- [?]`
  (spec 011) and Sunday's report asks the oldest one as a yes/no question.

## Questions

None open. The maintainer approved the direction on 2026-09-19.

## Acceptance

- [x] A one-off run in the sandbox has printed what can be read there: a ranged
      read of a raw changelog, `git ls-remote --tags` of a public repository,
      a shallow clone of one, and the expected 403 from the API as the control.
      The spec is amended with what it found before anything is built on it.
- [ ] On Sunday the run writes at most three `idea:` lines, each naming the
      backbone file it touches and the address it came from, in the agent's
      own words. It writes none when it cannot name the file, the term is
      already in the backlog, a spec or the CHANGELOG, the idea needs a
      dependency, a duty for the person or something they must learn, or five
      `idea:` lines are already open.
- [ ] A source that did not answer is "not read" in the log line, never
      "nothing new"; its marker does not move.
- [ ] The markers are saved through a recipe that refuses to commit anything
      else, looking at the working tree and at what is ahead of `origin/main`.
- [ ] What the agent reads from a source passes through a filter and a length
      cut in the command itself, so the whole file never enters its context.
- [ ] `just self-test` holds a new project to today's size (tracked files,
      visible recipes, the length of `AGENTS.md`), and the stored prompt says
      those numbers are never raised unattended. Growing means removing first.
- [ ] `just upstream` can see the backbone's own four tools from the sandbox,
      in whatever shape the first line allows, or says "not read" for the ones
      it cannot.
- [ ] The first Sunday run was read through its log by an agent, including a
      changelog fixture that tries to give orders. Nothing instruction-shaped
      reached the backlog and no file outside the allowed ones changed.

## Tasks

- [x] The probe. Amend this spec.
- [x] The radar rows (address, bytes to read, filter, marker, last answered,
      file it touches) in `docs/radar.toml`, a file of their own so that the
      save can be fenced to it, and the Sunday section of the brief. The
      reading is done by `.ai-backbone/radar.py`, not by the agent with `curl`:
      the cut is in the code.
- [x] `just radar`, `just radar-mark` and `just radar-save` in the backbone's
      own `Justfile`; no project receives them.
- [x] The size ceilings (3.21.3: tracked files 40, recipes 37, `AGENTS.md` 7,000
      bytes, as a new project measured on 2026-09-19); the line in the stored
      prompt went in with spec 011.
- [x] `just upstream` in the sandbox (3.21.2: the tags are asked of git when the
      API refuses). Whether the four are read there shows in the next run's
      log line, which has said "not read" for all four so far.
- [ ] Docs, CHANGELOG, version. The first Sunday run, read.
