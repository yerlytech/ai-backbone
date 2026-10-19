---
status: approved
date: 2026-10-15
---

# 031 — Hardening, after an independent review

Proposals from an independent review of this repository (2026-10-15), each
checked against the code, and from what the same day's work showed. They are
the maintainer's to choose; none is built before that. Written by one agent
without subagents, on the maintainer's word, to spare the week's limit.
Approved by the maintainer on 2026-10-15, all eight proposals; the building
waited until the weekly limit reset (2026-10-19). On 2026-10-18 the
maintainer lifted that wait (the weekly limit no longer applies; the project
is built with several models) and building began. Ordered by what each
protects.

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

Decided on 2026-10-15, as the managing session proposed and the maintainer
approved: the managing session marks a version stable without asking the
maintainer, and tells them. Its rule: green on the three machines, then one
day of clean use in its pilot project (session-start, save, publish and its
own tests clean, no note coming back); a security fix the same day, without
the pilot. The maintainer can always take the mark back. No mark by a rule
alone ("no red run for a day"): a run that is not red does not show the
version was used.

The mark is a one-line file on `main`, never a tag (a tag can be moved, and a
moved tag reaches nobody without force; a file has a history, and taking it
back is one commit). It lives outside `.ai-backbone/`, at the top of the
backbone: a new core file would pass the new-project file ceiling. A
project's `template-check` and `session-start` read it from `origin/main` and
say "behind" only below it; `template-update` goes to it, and to the newest
only when asked. The mark may go back: a project past it is told it is ahead,
never that it is broken. The gate never carries a change to the file on its
own and the scheduled run never touches it: only an attended session changes
it, on the managing session's or the maintainer's word.

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

None open. Settled on 2026-10-15: proposal 1 yes, one word per release;
proposal 4 as decided above; proposals 2, 3, 5, 6, 7 and 8 built as written.

## Acceptance

- [x] A push to `cloud` that changes code is not carried by the gate on its
      own: the gate's line says it waits for an attended carry, and
      `just session-start` in the backbone names what waits.
- [x] A push that changes only docs, specs, the backlog or the log is still
      carried on its own.
- [x] An attended carry takes a waiting commit to `main` with `main`'s own copy
      of the carry, only when all three machines were green for that commit,
      and tags it; it refuses anything else and says why.
- [~] `.claude/settings.json` no longer allows `git checkout -- .`, `just undo`
      goes through Claude Code's own prompt, and `rm -r -f` and `rm -fr` are
      denied, each rule measured on the pinned Claude Code; a scheduled run
      still finishes; `docs/how-it-works.md` says what the list is and is not.
      Holds without measurement: `git checkout -- .` is absent from allow;
      `rm -rf` / `rm -fr` / `rm -r -f` / `rm -f -r` are denied; how-it-works
      states the boundary. Open: `just undo` behind an `ask` rule (allow still
      has `Bash(just:*)`), and measurement on the pinned Claude Code (not
      installed on the machine that built and verified this, 2026-10-19).
- [x] `README.md` names no version, and the suite fails when it names one other
      than line 1 of `core.just`.
- [x] The stable mark: a project's `session-start` and `template-check` say
      "behind" only below it and "ahead" above it; `template-update` goes to
      it unless asked for the newest; the gate never carries a change to it on
      its own, and the routine brief forbids touching it.
- [~] A count of the recipes this machine's projects ran in the last month,
      from local session records only, written into a follow-up spec; no
      recipe is removed in this one. Measured 2026-10-18: no month of records
      (Claude transcripts 0, Zed 5 threads that day). Count deferred; no recipe
      removed. Follow-up stays outside this acceptance until records exist.
- [x] The comment rule is in the backbone-dev skill, and `just doctor` in the
      backbone says the share of comment lines in `core.just`.
- [~] The suite says how long each section took; the slowest sections on
      Windows are named and the worst is cut, measured before and after; the
      backbone-dev skill says a printed path is text, never a `Path`.
      Holds: section timings print; path-as-text is in backbone-dev; Windows
      run 39091792611 named slowest "the budget" 203s (1497s total). Open: cut
      that section and re-measure (033 defers structural simplification).
- [x] The agent-cap refusal and the audit skill say that a mode the person
      turned on is not a yes to a count.
- [x] Green on the three machines, released, and the managing session told.
      3.41.0 (`d28b98b`) and 3.41.2 (`0da7504`) carried to `main` with tags
      after green checks; the managing session told via `just project-note` on
      2026-10-19.

## Tasks

- [x] The gate waits for an attended carry when a push changes code; the
      attended carry; the routine brief and `docs/` with it (3.41.0;
      `gate.sh attend`, `just carry`, checked against a bare repository in
      the suite; the first real carry is the first push of this version).
- [x] The stable mark and the three recipes that read it; "ahead" when it goes
      back; the routine brief forbids it. (3.41.0: `STABLE` holds the
      version and its commit, so a moved tag cannot move the mark; offline
      it is not read, as `template-update` compares nothing with GitHub
      there.)
- [~] The permission list, after measuring how Claude Code matches each rule.
      Done in 3.41.0, from Claude Code's permissions page (read 2026-10-18,
      not measured: Claude Code is not installed on the machine this was
      built on): `git checkout -- .` left the allow list; `rm -fr`,
      `rm -r -f` and `rm -f -r` joined the deny list; `docs/how-it-works.md`
      says what the list is and is not. Open: `just undo` behind an `ask`
      rule, which waits for a measurement of what the scheduled run's
      permission mode does with an ask rule (its revert path runs
      `just undo`), and the measurement of all of it on the pinned Claude
      Code.
- [x] The README without a version, and its check.
- [x] A mode is not a yes to a count: agent-cap.sh's refusal and the audit
      skill.
- [~] Section timings in the suite; the slowest Windows section cut; the
      path-as-text rule. (Timings and the rule in 3.41.0. First Windows run
      that prints them, 39091792611 on 2026-10-18: 1497s in all, 771 checks;
      slowest "the budget" 203s (a section of 120 checks that runs on to
      the next heading), "the backbone's clone keeps itself level" 139s,
      "build output" and "the backlog of 2026-10-06" 128s each, "checks on
      every push" 124s. Linux 4m45s, macOS 12m. The cut is still to do.)
- [x] The comment rule and doctor's line.
- [~] The recipe count from local session records, into a follow-up spec.
      Measured 2026-10-18 on the maintainer's machine: there is no month of
      records to count. Claude Code keeps no transcripts there (0 files under
      its projects folder), Zed's thread store holds 5 threads, all of that
      day, and Gemini's temp folder one session. A count from that would be
      a guess, so it waits: either a month of records, or a follow-up spec
      for a local count the backbone keeps itself. Acceptance marked the same.
- [x] Through the gate on the three machines; the managing session told.
      Attended carries of 3.41.0 and 3.41.2; project-note to the managing
      session 2026-10-19.
