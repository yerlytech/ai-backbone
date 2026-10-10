---
name: audit
description: Audit a finished phase or a release candidate with many agents, where every finding is verified before it reaches the maintainer and the agent count is said and approved before it starts. Use at the end of a phase, before publishing for the first time, and before a release. Covers the lenses, the verification, the completeness pass, the cost, and what to do with what survives.
---

# Audit

A review by one agent produces a list of plausible things. Most of them are
wrong, and the maintainer spends their afternoon finding that out. This is the
shape that does not do that: many lenses, and every finding argued against
before anybody is asked to read it.

The numbers from the audit this came from: 112 claims, 100 refuted, 11 real.
Without the middle step, that is 112 things to read. With it, 11.

And the number this was rewritten from: 12 lenses, 74 findings, three skeptics
each, 235 agents in one night, about a fifth of the week's limit, and a machine
that fell over. The verifying is kept; the multiplying is not.

## When

- At the end of a phase, with the maintainer's approval. It is expensive.
- Before publishing a repository for the first time.
- Before a release.

Never on a commit, never on a schedule. An audit is a deliberate act.

## What it is not

**An audit is not a rehearsal.** It reads code. The defects that cost the most
are the ones only running the thing finds: a database function that does not
exist, a driver that cannot do what the code asks over the protocol in use, a
stream that goes quiet when the request that opened it returns. Run the product
for real as well, on a real machine, with a real database. Two separate acts,
both at the end of a phase; the rehearsal is step 7 below.

## Steps

1. **Read the lenses.** `docs/audit-lenses.md` lists them. If the file is not
   there, run `just audit-lenses` and fill it in: five are given, the rest come
   from this project's own seams. A lens is a question about this codebase, not
   a category like "security".
2. **Write the ground rules once** and give the same block to every agent: what
   the project is, where its parts live, the rules it holds itself to, that
   reviewers may run commands but must never edit a file, and the commands they
   may run. A build is not among them (the rule below).
3. **Say the count, and wait.** Before the first agent starts: how many lenses,
   that each lens is one agent, plus one for step 5, and what that is against
   the week (`just session-start` printed the line). "This audit is 9 agents,
   about a day's share; go?" A yes raises this session's cap for exactly that
   many (`just _agent-cap`); without one, nothing starts. A lens more than about
   eight is a lens too many: merge two.
4. **Run the lenses in parallel, and each lens verifies its own findings.** One
   agent each, reading real code. Cap the findings per lens at about six and
   demand a concrete failure scenario, inputs or state and then the wrong
   outcome, and then demand that the same agent tries to make it happen before
   it reports: run it, or read the guard that would stop it, and give the
   finding a verdict (below). Measured on 2026-09-21 against the older shape,
   three skeptics per finding: the same thirteen real findings, at half the
   cost.
5. **Ask what was missed.** One more agent, given the surviving list and the
   lens names, whose only job is to find what nobody looked at: two subsystems
   interacting, the second day rather than the first, an upgrade, a restore.
   Not a second round of lenses: the count was said in step 3, and it holds.
6. **Fix what was confirmed, each with a test that catches it.** A fix without a
   test is a fix that comes back. What needs validation waits for its check.
7. **Rehearse.** Run the product against the real services it ships with, not
   the in-memory ones the tests use, and put load on it. Then tell the
   maintainer, in this order: what was confirmed and its severity, what needs
   validation and the check for each, the hardening notes, how many were
   refuted, and what you changed.

## Verdicts

Every finding a lens hands back carries one of three verdicts.

- **Confirmed.** The whole path is in the code, and the outcome was made to
  happen: the test ran red, the bad request was accepted, the row was read.
- **Needs validation.** The code path is real, but a fact that decides it is
  not in the repository or cannot be seen from this machine: a deployment
  setting, a proxy in front, the provider, the browser, a secret. Name that
  fact, and write the safe check that settles it, one the maintainer can look
  at or one an agent can run here. It gets no severity. It is not where a guess
  goes to wait: when the code contradicts the claim, the verdict is refuted.
- **Refuted.** Counted, never deleted, and the count goes to the maintainer.

## Severity

Only a confirmed finding gets one, and each level has an anchor:

| Severity | Anchor |
|---|---|
| critical | someone who is not signed in runs code, reaches the whole data store, or takes over any account they choose |
| high | an explicit security control is bypassed completely, with a real consequence: signing in without credentials, reading or writing another tenant's data, a stored script that runs for other users, a signed-in user running code, a shared service taken down remotely by someone not signed in |
| medium | a real boundary is crossed, but the reach is narrow or the preconditions are rare |
| low | internal information that is not a secret leaks, or much effort buys little |
| informational | minimal effect, most often a precondition of a bigger finding |

Two rules sit beside the table:

- **The severity never exceeds the impact shown.** What a finding could lead
  to if three other things were true is not what it showed.
- **High or medium is one question:** does the outcome shown bypass an explicit
  control completely, on an action with a real consequence, or only weaken it?
  When nobody can say what concrete harm follows, the severity is lower than
  it feels.

The anchors speak of security. A finding from another lens, a lost row, a wrong
total, a restore that fails, is placed by the same two rules.

## A flag is not a finding

A missing header, a cookie flag, a rate limit, a best practice: none is a
finding on its own. A finding names who or what is affected and shows a bad
request that was accepted. When one layer already stops the attack, the missing
second layer is a hardening note. Hardening notes go to the maintainer as a
list of their own, after the findings, never mixed into them.

## Checklists for a security lens

Optional. When the project has a security lens, that lens may read the
checklists of Cloudflare's security-audit-skill, one per kind of boundary, at
the pinned commit, never the moving head:

`https://github.com/cloudflare/security-audit-skill/blob/c1c8a8c/skills/security-audit/<FILE>.md`

`<FILE>` is one of `WEB-PROTOCOL-AND-AUTH`, `CLIENT-SIDE`,
`PROTOCOLS-RPC-AND-MESSAGING`, `DATA-ISOLATION-AND-LIFECYCLE`,
`CLOUD-AND-DEPLOYMENT`, `SUPPLY-CHAIN-AND-RELEASE`, `AI-AND-LLM`,
`DESKTOP-MOBILE-AND-LOCAL-IPC`, `MEMORY-SAFETY-AND-BINARY` and
`RESOURCE-EXHAUSTION-AND-AVAILABILITY`. Pick a file only when the project
really owns that boundary; each one opens with "When to use this file", which
says when. They are something to read, not to install: never `npx skills add`.

The verdicts, the severity anchors and "a flag is not a finding" are adapted,
in our own words, from that skill (MIT, commit c1c8a8c, 2026-09-14). Left out
on purpose: its six phases, coverage ledger and critic waves (a run is 20 to 30
agents); a fresh verifier per candidate, since the measurement in step 4 found
the same real findings at half the cost with each lens verifying its own; and
its sandbox requirement, file-moving procedure and Node validators.

## The rehearsal

The step the audit cannot replace. Every lens reads one path at a time; these
defects live between two processes, or in the second minute rather than the
first.

Write each rehearsal as a recipe, `just rehearse <name>`, not as commands in a
chat. A rehearsal that cannot be run again proves nothing about tomorrow, and
the one that finds a defect will be run twenty times while it is fixed.

Four that have each found something real:

- **Two servers, one database.** Start the product twice against one real
  database and send both the same kind of work at once, a hundred writes each.
  Anything the code does per connection — a session, a cached handle, a lock —
  fails here and nowhere else.
- **Open and close, many times.** Open every long-lived thing the product has,
  live queries, streams, subscriptions, watchers, fifty at a time, then close
  them. Count what the service holds before, during and after. The number after
  must be the number before.
- **The documented install, on a clean machine.** Follow the guide's own
  commands, in order, in a container or a fresh VM, with nothing from the
  development machine. This is how you find that the image's toolchain is too
  old, that a file the guide names was never committed, or that the first sign-in
  cannot be completed.
- **The restore.** Back up, restore into a new name, then use the restored copy
  for real: sign in, open a screen, save a row.

Count something at the end of each one rather than reading the log and calling
it fine: entries in the chain, rows written, queries still open, the exit code.
A rehearsal with no number is a rehearsal that passes.

## Running it with a workflow tool

When the agent has one (Claude Code's Workflow tool), one call runs the lenses
side by side; the workflow's launch is gated by the same yes as step 3, and the
agents it starts are exactly the lenses, no more.

```js
const reviewed = await parallel(LENSES.map((lens) => () =>
  agent(`${GROUND}\n\n${lens.prompt}\n\nRun it, or read the guard that stops it, then give each finding a verdict: confirmed, needs validation (the missing fact and the check), or refuted. A flag is a hardening note, not a finding.`,
        { schema: FINDINGS })))
```

Without one, do the same thing sequentially with subagents. It is slower and it
is the same discipline: no finding reaches the maintainer without a verdict, and
no agent starts that was not counted.

## Rules

- **Reviewers never edit, and never build.** They read, they may run tests and
  queries, and they report. The fixes are a separate act, by you, afterwards.
  A build is not a read: a reviewer's trial Gradle build installed Android SDK
  Platform 34, 126 MB, into the machine's own SDK without asking (measured
  2026-09-21), which §7 of `AGENTS.md` forbids. Every toolchain that fetches
  what it is missing does this, Flutter, Xcode and `cargo` with it. Whether the
  app builds is the rehearsal's question, step 7, where a person is watching.
- **Refuted findings are not deleted, they are counted.** Tell the maintainer
  how many were refuted. That number is the reason to keep verifying.
- **The count said in step 3 is the count.** An agent that wants one more
  agent asks again. An audit is expensive on purpose, and only once.
- **A confirmed finding with no test is not finished.**
- **A phase with no rehearsal is not audited.** Say which rehearsals ran and
  what each one counted.
- Findings about the backbone itself go to `just backbone-note`, not into the
  project.
