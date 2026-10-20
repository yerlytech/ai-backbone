---
status: approved
date: 2026-10-20
---

# 035 — Fresh every day: the watch list read at session start

## What

`just session-start` tells the agent, in its first screen, what the project is
behind on, and makes the update the session's first job. Releases are checked
online at most once a day per machine. The first session of the day checks, and
every later session that day reads the shared result. The watch list also holds
ideas: projects we take an idea from. When one of them releases, the agent sees
it, and the worker writes what is new and what it means for us in ten lines.
The agent tools this way of working rests on are watched too: the worker CLI,
Claude Code and the editor.

## Why

On 2026-10-20 the backbone's own watch list was four tools behind: just, prek,
graphify and uv. Two of its pins no longer matched the file they name. The Mac
had already installed newer graphify and just, so the pins were stale as well.
`just upstream` worked and said all of it, but only when someone ran it, and
nobody did. The "Built on" lines at session start never go online. A weekly
routine was considered and rejected by the maintainer as too slow. The maintainer
wants every new chat to start current. Ideas, such as agent orchestrators taken
as references for spec 034, had no place to be followed at all.

## Not doing

- No scheduled job and no weekly routine. The trigger is a session starting.
- No automatic upgrade. The check reports; the update is a job like any other,
  delegated (spec 034) when a worker is set, done by the session when not.
- No online check on every start: once a day per machine, shared by projects.
- No monthly scan. A scan for new ideas runs only when the maintainer asks
  ("yeni fikirlere bak"). It leaves a dated note in `brain/02-research/`.
- No dependency on an idea's code. An idea entry is read, never installed.

## Questions

None open. Approved by the maintainer on 2026-10-20: daily at session start,
first job the update, ideas watched in the same list, the scan on request.

## Acceptance

- [ ] `just session-start` shows a FRESHNESS block: when it was checked, what is
      behind (tool, pin → newest), pins that MOVED, the backbone's own version,
      ideas that released, and one suggested first job.
- [ ] The online check runs only when the machine's shared result is older than
      24 hours, or on `just upstream --refresh`. Its cache lives under
      `~/.cache/ai-backbone/upstream/`, keyed by source, so two projects that
      watch the same tool share one lookup.
- [ ] Offline, rate-limited or slow (over 10 s in total): session start still
      completes. It shows the last result with its age and says why it is old.
      It never fails the session and never hides a failure.
- [ ] `docs/upstream.toml` accepts `kind = "idea"` with `why` and `look_for`.
      An idea entry is listed apart from tools. Its newer release counts as
      "to read", never as "behind".
- [ ] The backbone's list watches the worker CLI (grok), Claude Code and Zed,
      and the two ideas taken for spec 034: OrchestratorInc/agent-orchestrator
      (a board of every running job) and claude-delegator (ask-only mode).
      The pins match what is installed or pinned on 2026-10-20.
- [ ] The core rules and the session skill say: a FRESHNESS block with something
      behind makes the update the first job; an idea to read goes to the
      worker for a ten-line note, and to the maintainer only when it is worth
      a decision.
- [ ] Tests cover the cache's age rule, a shared lookup across two fixture
      projects, offline and rate-limited runs, and an idea entry. They pass on
      macOS and Linux.

## Tasks

- [ ] Shared daily cache and `--refresh` in upstream.py, with its tests.
- [ ] FRESHNESS block in session-start, offline and slow paths, tests.
- [ ] `kind = "idea"`, its listing and tests; the backbone's list brought up to
      date (just, prek, graphify, uv, the two MOVED pins) and the new entries.
- [ ] Rules, session skill, docs and changelog. Release with 034's, or after it.

## Notes

2026-10-20, fix round. agent-orchestrator is pinned at v0.14.3, the newest
release read that day. A pin of 0 counted every earlier release as to read.
claude-delegator publishes no release, so `github:` read UNKNOWN. It is
watched with `ghcommit:owner/repo`: the commits on the repository's default
branch, the request naming no branch. Pinned at `8e2ea57c9b8e6f0790b1596d98e35632ca48a59c`,
the newest commit read that day (the commit itself is dated 2026-10-12). A
later commit is to read.
