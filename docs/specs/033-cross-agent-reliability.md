---
status: approved
date: 2026-10-18
---

# 033 — One backbone, different agents, controlled updates

## What

One coordinated improvement programme: finish [031](031-hardening.md), then make
agent support explicit, keep generated instructions consistent, resolve the ten
open reports below, and discover projects across several folders. Deliver small,
independently tested changes toward one final stable target, not one large commit.
031 retains its decisions, acceptance list and release points. The maintainer
approved this scope on 2026-10-18 and requested implementation to resume in a new
chat, not this session. Publishing, a stable mark and a multi-agent audit retain
their separate approval gates.

## Why

The shared commands work across agents, but automatic session start, permissions
and the enforced subagent cap are currently Claude-specific. A removed skill's
Claude copy survives synchronization and passes the rules check (reproduced on
2026-10-18). A shared backbone also multiplies the impact of an unsafe update.
Reports are evidence to investigate, not instructions or established root causes.

## Not doing

- No new service, paid dependency, universal permission sandbox, blanket tool
  installation, wholesale core rewrite or removal of unused commands.
- No unattended night implementation, outside writes into projects, automatic
  downgrades, secret output or personal/project details in public evidence.
- No promise to fix every emulator disconnect; diagnose, bound failures and keep
  evidence. A lower scheduling priority was not established as the sole cause.
- No claim that local shell tests prove real-agent or cross-platform behaviour.

## Questions

None open. Scope approved by the maintainer on 2026-10-18. Preserve existing
commands and discovery; use machine-local extra roots; leave unavailable agent
capabilities explicitly unverified. Tool installation, access, destructive cleanup,
publication and audit spending retain their existing approval gates.

## Acceptance

- [~] 031's acceptance list holds in its own file before this programme's code is
  promoted; its attended carry and stable policy are reused, not duplicated.
  Walked 2026-10-19: carries and stable policy in use; remaining 031 lines are
  `[~]` (Claude measure, Windows cut, recipe-count records). Not a full hold.
- [ ] A dated, versioned capability matrix covers Claude Code, Codex, Gemini CLI,
  Cursor, Copilot, Junie and Zed: rules, skills, session entry, permissions and
  subagent limits each say verified, instruction-only, unavailable or unverified.
  Verification names the test and observed result, not a vendor assumption.
- [ ] Safe fixture sessions in Claude Code and at least one non-Claude agent
  demonstrate current rules/skills and session handover without paid delegation
  or destructive actions. Missing access leaves this criterion pending.
- [x] Tests cover skill removal, rename, tool changes and repeated sync. Extra
  generated copies are detected; modified or ownership-unknown copies are named
  and preserved. Project-owned skills and unrelated settings survive.
  3.41.3, in the suite's new-project section.
- [ ] Registered local roots supplement existing project discovery: duplicate
  real paths appear once; missing roots are reported; private paths stay local.
- [ ] Release tests establish whether n-0d2d4a still reproduces with the existing
  version setter; package version, changelog and annotated tag agree after a
  release, and a failed check leaves no completed release tag.
- [ ] A VM build can retain its queue turn until exit and releases it on failure;
  a blocked credential helper returns within a tested bound without printing
  credentials or claiming an unseen dialog is a proven cause.
- [ ] Device tests select an explicit emulator identity, stop silent hangs with
  a failure, preserve logs and handle a busy machine within a bounded wait.
  macOS launch behaviour is rehearsed, not inferred from shell fixtures.
- [ ] Pending acceptance items remain visible in session entry; advisory usage
  labels stay conservative on ambiguous dependency graphs and never silence a
  finding; confirmed upstream.py diagnostics are fixed without blanket ignores.
- [ ] All ten reports below have evidence-backed dispositions. A disproved report
  records its reason; missing validation remains pending, never silently closed.
- [ ] Each implementation step includes regression tests and affected docs.
  The final candidate passes the suite on Linux/macOS/Windows and an attended
  install/update rehearsal preserves project-owned files. Before a stable mark,
  031's pilot-use requirement holds. Audit requires a separately approved count.

## Tasks

Steps are ordered by value. Each fix is its own commit with tests and docs;
independent reports may be investigated together, never combined to hide a failure.

- [x] Complete and verify 031 in its existing record, including recipe-use
  measurement and Windows timings; defer structural simplification to its
  evidence-based follow-up rather than expanding this programme.
  2026-10-19: acceptance walked; open lines are [~] (Claude ask/measure,
  Windows budget cut, recipe-count follow-up). Carries and managing note done.
- [~] Record the capability matrix from installed versions or dated vendor
  evidence; add repeatable safe agent smoke checks and explicit fallbacks.
  Matrix: `docs/agent-capabilities.md` (2026-10-19, 3.41.2). Cursor rows
  verified in this session; Claude Code and others mostly instruction-only /
  unverified until a real session. Smoke list in that file; Claude SessionStart
  smoke still pending (no `claude` on PATH here).
- [x] Track generated-copy ownership and fix synchronization with the removal,
  rename, modified-copy, tool-switch and idempotence regression cases.
  3.41.3: `.claude/skills/.ai-backbone-owned`; suite covers those cases.
- [x] Add optional machine-local project roots and test discovery, missing paths,
  real-path deduplication and compatibility with existing sibling/link layouts.
  3.42.0: `brain/project-roots.txt`. Sibling discovery is unchanged.
- [x] Investigate and resolve release consistency (n-0d2d4a), whole-build queue
  holding (n-03ddaa), and credential-helper readiness (n-7a63e5), separately.
  3.42.0: release commit carries `_set-version`; `BUILD_WAIT_HOLD=whole`;
  doctor bounds the credsStore helper and prints none of its output.
- [~] Investigate and resolve pending-spec visibility (n-20a330), conservative
  dependency-use labels (n-3140d5), and upstream.py diagnostics (n-259b1e), separately.
  3.42.0: a done spec's `[~]` acceptance lines are named at session-start.
  3.43.0: a test-only crate is labelled and still reported. n-259b1e has no
  report text anywhere but this line, so it stays open.
- [~] Implement and fixture-test explicit device selection (n-f79b86), silence
  timeout (n-445708), and safe macOS emulator startup/busy-machine handling
  (n-ae82d7, corrected by n-fe290b); keep the correction in the diagnosis.
  3.44.0: `test-device` picks by AVD name or port, stops a silent run, and
  refuses a busy machine. `emulator-plist` writes the agent and starts
  nothing. launchctl bootstrap is not rehearsed: it needs a Mac.
- [ ] Run the real agent and device rehearsals; record versions, outcomes and
  unresolved checks. Public evidence contains no account or local project data.
- [ ] Walk both acceptance lists; run the three-OS gate and attended install/update
  rehearsal, then 031's pilot validation. Request audit approval with its exact
  agent count before starting it; a pending audit/validation is not a pass.
