---
status: done
date: 2026-09-22
---

# 014 — budget

## What

An agent working in any project built on this knows, at the start of every
session, roughly how much of the person's weekly limit is used, how many days
are left before it resets, and how many subagents it may start today without
asking. It cannot start more than that on its own: a hook on the tool that
spawns subagents counts them per session and refuses past the cap with a
sentence that tells the agent to ask the person. The person answers in plain
words, once per machine for the work pattern ("I rest at weekends"), once per
session for a raise ("yes, go on"). The audit skill, the one place the backbone
told an agent to spawn many, stops multiplying agents by findings.

## Why

A multi-agent audit spent about a fifth of a week's limit in one day and
crashed the machine (12 lenses, 74 findings, 222 skeptics: 235 agents, the
skill's own arithmetic, `lenses + 3 × findings + 1`). The person on a top plan
found 40% of the week gone by Wednesday. Nothing bounded fan-out anywhere, and
an agent cannot ask Claude what is left: `/usage` is interactive only. What it
can do, measured on Claude Code 2.1.273: read the meter Claude Code itself
caches in `~/.claude.json` (a percentage for the seven-day and the five-hour
window, when each resets, when it was read), and sum what this machine spent
since from the transcripts under `~/.claude/projects/` (every assistant message
carries its token usage and model; a message counts once per id; a subagent's
calls live only in its own file). The meter is the truth and includes what the
machine never sees (the cloud routine, claude.ai); the transcripts fill the
minutes since it was read. Local tokens alone would mislead: one week's 100%
was 5.0 billion raw tokens, the next week's 46% was 1.5 billion. A hook that
counts and refuses was measured working, 25 ms a call, and the model then asked
the person instead of retrying.

## Not doing

- Claiming an absolute number of tokens for the limit, a per-model weight, or a
  decimal percentage. Anthropic publishes none of these. Every line says
  "about" and points at `/usage`.
- A Rust rewrite of the helpers. Python already arrives through `uv`, as
  `just` and `prek` do, and the code map (`graphify`) is Python: it cannot
  leave before that does. The hook and the session line stay plain bash. An
  `idea:` line records the thought for the day graphify leaves.
- Readers for Codex and Gemini transcripts (each records usage in its own
  place; Codex even its remaining percent). One line each, blocked on a project
  that uses them. Cursor keeps no usage locally: the person is asked.
- Raising the cap on the agent's own judgement. Only a person's words do, for
  one session (`just _agent-cap`) or for the machine (git config).
- Counting the agents a workflow script starts: they never pass the hook. The
  launch of a workflow is gated instead, by the same yes.

## Questions

None open. The maintainer approved the design and the default cap of 8 on
2026-09-22, and the Python question was settled by measurement (see Not doing).

## Acceptance

- [x] The first line of `just session-start` in every project says, in
      `chat_lang`, the week's percent from the meter and its age, the five-hour
      percent, the days to the reset, and the subagents it may start today;
      "about", never a decimal; `/usage` named. Without a meter or Python it
      says one quiet line and the session goes on.
- [x] `.ai-backbone/budget.py` sums the week and the day from the transcripts,
      counts each message once, runs in under a second once its cache is warm
      (0.04 s measured; the first run over a gigabyte took 1.2 to 3.1 s), keeps
      its cache outside `~/.claude`, and never writes there.
- [x] The ninth subagent of a session is refused with the count, the cap and
      the ask; a workflow launch is refused until the person's yes; the person's
      yes lifts it for that session with one recipe; a raise for the machine is
      one git config. Measured under bash 3.2 and BSD tools.
- [x] `just hooks-install` adds the hook to a project's `.claude/settings.json`
      without touching its permissions or its other hooks, never twice; a new
      project has it from the seed.
- [x] The audit skill says how many agents it will start before it starts,
      waits for a yes, and has each reviewer verify its own findings (measured:
      the same findings at half the cost); the session skill carries the rule
      for every tool.
- [x] `just self-test` covers each line above with a fixture transcript tree, a
      fixture meter and a fixture stdin for the hook; the three ceilings hold.
- [x] The person has seen the line and its four forms (no meter yet, reset just
      happened, over 80%, the refusal): shown in the session of 2026-09-22 with
      the machine's own numbers.

Walked on 2026-09-22. Two readers reviewed the built change and reproduced ten
defects, all fixed before it was saved: the worst were a meter read before the
reset passing as this week's, twelve agents started in one breath all passing
the hook, and the line's number not being the one the hook held to. 345 checks.
A live `claude -p` run in a fresh project refused the second subagent and the
model asked the person, in Turkish, unprompted.

## Tasks

- [x] `budget.py` from the measured prototype; `_budget` in core.just; the line
      first in `session-start`.
- [x] `agent-cap.sh`, `agent_cap_hook.py`, `_agent-cap`; `hooks-install` runs
      the merge; the seed; the manifest; the hook's `files:` pattern.
- [x] The audit and session skills.
- [x] Checks, docs, CHANGELOG, version 3.24.0, the three backlog lines.
- [x] Review by two readers that reproduce their own findings; publish; the
      maintainer's clone level.
