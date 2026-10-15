---
status: draft
date: 2026-10-15
---

# 031 — Hardening, after an independent review

Proposals from an independent review of this repository (2026-10-15), each
checked against the code, and from what the same day's work showed. They are
the maintainer's to choose; none is built before that. Written by one agent
without subagents, on the maintainer's word, to spare the week's limit; the
building waits for the next week. Ordered by what each protects.

## What

### 1. Code nobody watched waits for a yes

Checked: the scheduled run works every third day with nobody watching; it may
approve its own spec, write code and push to `cloud` (`.ai-backbone/routine.md`
steps 6, 7 and 12). The gate carries any commit that is green on the three
machines to `main` (`gate.sh carry`), and every project runs it, outside a
sandbox, at its next update.

Already in place, which the review did not credit: an unattended run may not
change `.github/workflows`, `gate.sh`, `.claude/settings.json` or
`.gitignore`, and the gate refuses to carry a changed workflow or `gate.sh`;
`radar-save` commits nothing but markers and the log line; `idea:` lines are
capped (three a run, five open) and checked again through `just radar` before
anything is built on them; one item a run.

The gap is the one the review names: text a stranger wrote in a changelog can
shape an `idea:` line, and a later run can turn it into code that is green and
reaches every project without anyone having looked.

Proposal: widen the existing rule. The gate carries on its own only a push that
changes no code: docs, specs, the backlog, the log. A push that changes code
waits on `cloud`, tested and green, until an attended session carries it: the
agent says in plain words what changed and why, and on the maintainer's yes
runs `main`'s own copy of the carry on this machine. No commit is trusted for
what it says about its author: every code change waits, and an attended
session carries its own right after the green run. Cost: one word per release;
a scheduled run's code waits until the next attended session.

Decided by the maintainer on 2026-10-15: yes, one word per release.

### 2. Throwing work away asks first; the list says what it is

Checked: `.claude/settings.json` allows `Bash(just:*)` and
`Bash(git checkout -- .)`. `just undo` asks y/n itself, but an agent can
answer it; `git checkout -- .` throws away every unsaved change with no
question at all. The deny entry `Bash(rm -rf:*)` names one spelling;
`rm -r -f` and `rm -fr` are others (how Claude Code matches them is measured
before anything rests on it).

Proposal: `git checkout -- .` leaves the allow list, `just undo` asks the
person through Claude Code's own prompt, the other `rm` spellings join the deny
list, and `docs/how-it-works.md` says plainly that the list guards habits and
is not a security boundary. Checked first: whether an unattended run still
works with the change.

### 3. The README names no version

Checked: `README.md` says "this is 3.27.2"; the version is 3.39.0. Proposal:
the sentence points at `CHANGELOG.md` without a number, and the suite fails
when the README names a version other than line 1 of `core.just`.

### 4. Projects move on a stable version, not on every version

Checked: 107 versions since 12 September; 30 since 3.27.2 on 24 September (12
minor, 18 patch), about one and a half a day this month. Every project hears
"behind" after each.

Proposal: `main` keeps moving and the gate keeps testing every push, but a
project's session says "behind" only past the last version marked stable,
the way 3.39.0 goes out today. A version is marked stable by an attended
session on the maintainer's word; a security fix is marked the same day.

### 5. A smaller core, measured first

Checked: `core.just` is 4,825 lines, 1,504 of them comments (31%);
`upstream.py` 1,479; the suite 2,970.

Proposal: first count which recipes the projects on this machine have run in
the last month, from their agents' local session records (nothing leaves the
machine), and list the ones nobody ran. A later spec decides, from that list,
what moves to a language layer and what goes.

### 6. Comments: short in code, the story in the spec

Proposal: for code that is new or touched, never as a rewrite: a comment says
what the code guards and which spec or version taught it, in one or two lines;
the story goes to the spec or the CHANGELOG. The measured lessons stay. The
share of comment lines in `core.just` is said by `just doctor` in the backbone,
falling by attrition.

### 7. Windows sooner and faster

Checked: today's Windows run took 26m43s (Linux 3m43s, macOS 9m23s), and the
day's one bug, a `pathlib.Path` printed with a backslash, showed only there.

Proposal: time the suite by section on Windows and cut the slowest process
spawning; and a rule in the backbone-dev skill: a path printed for a person or
compared as text is text (`as_posix()`), never a `Path`.

### 8. A mode is not a yes to a number

Checked: "max and ultracode on" was read as consent to about fifty subagents;
the maintainer found it too many and stopped it.

Proposal: the agent-cap refusal and the audit skill say that a mode the person
turned on is not a yes to a count: the count and its share of the week are
said, and a yes to that number is waited for.

## Why

The review was right that code reaches the projects without a person, and
that the size and the pace cost attention. The day added two lessons of its
own: a Windows-only bug that the slowest machine found last, and a mode read
as a blank cheque.

## Not doing

- A 24-hour wait with nobody looking (the review's fallback): it adds time,
  not eyes.
- Signed commits to tell attended from unattended: a key the maintainer would
  have to keep.
- Rewriting the comments in one go: the measured lessons are what stops a
  regression.
- The open backlog lines: a spec of their own after this one (032).

## Questions

Asked one per turn, each with the answer recommended.

- Proposal 4: who marks a version stable. Recommended: an attended session, on
  the maintainer's word or the managing session's.
- Proposals 2, 3, 5, 6, 7 and 8 change nothing the maintainer does.
  Recommended: build them.

## Acceptance

- [ ] Written when the questions are answered.

## Tasks

- [ ] Written when the questions are answered.
