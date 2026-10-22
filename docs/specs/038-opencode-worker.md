---
status: approved
date: 2026-10-22
approved: the maintainer, 2026-10-22 (the direction: an opencode worker that starts cheap and
  climbs a model ladder; the details below were written by the session from that word and from
  what was measured the same night)
---

# 038 — opencode worker

## What

`WORKER=opencode` is a third worker for `just delegate`, beside `grok` and
`claude`. It runs `opencode run --standalone --auto --format json` in the
project folder, with a deny list the run cannot step around, autoupdate off,
and only the tools a worker needs. The model is a ladder: the first try of a
job runs the first model of `WORKER_LADDER`, and each fix round on the same
branch runs the next one, so a job starts on a cheap model and climbs only when
it fails. The report the recipe prints ends with what the run cost, read from
the run's own events, not from what the worker says.

## Why

On 2026-10-22 the maintainer took an opencode subscription that serves many
models behind one sign-in (DeepSeek, GLM, Kimi, Grok and others), and wants
the workers to be independent of one vendor. Measured that night on one task
in a Bevy game, the same job cost about 30 times less on DeepSeek V4.1 Flash
than on GLM-5.3 or Kimi K3, while the subscription's monthly allowance holds
roughly 75 dollars of list-price use: a strong model on every job would spend
it in about 13 hours of work. Starting cheap and climbing on failure keeps the
strong models for the jobs that need them.

Three facts were measured on opencode 2.1.2 the same night, and the adapter is
built on them:

- `opencode run` without `--standalone` talks to a shared background service
  that does not read the project's config. A deny list there is not applied:
  a denied `rm` and `git push --dry-run` both ran. With `--standalone` the
  same rules refused both, and allowed commands still ran.
- A model is named `opencode-go/<id>` to draw on the subscription;
  `opencode/<id>` bills a separate pay-as-you-go balance.
- `--format json` gives one event per step with its cost and tokens.

A public write-up of the same pattern (a planner and coders of rising cost)
found that unused tool definitions made every call carry about 80 thousand
tokens of start-up context, and that trimming them per agent cut it to 12 to
19 thousand. A worker here gets only shell, read, edit and write.

## Not doing

- A planner agent inside opencode. The session is the manager; a second
  planner would make two.
- Choosing the ladder for a project. The default is a machine setting; a
  project or a job may set its own `WORKER_LADDER`.
- Free models in the default ladder. Their tool calls were reported to break
  silently under load, and a night job cannot skip a step unseen.
- Any MCP server, web fetch or path outside the project for the worker.
- Reading the subscription's remaining allowance. The maintainer sees it on
  the provider's page; the report says what this run spent.

## Questions

(none; the maintainer gave the direction, the session wrote the rest)

## Acceptance

- [x] `WORKER=opencode just delegate "<task>"` runs `opencode run --standalone --auto
      --format json -m <first model of the ladder>` in the project folder on a
      `delegate/` branch, with the same preamble the other workers get.
- [x] The deny list is the same list `grok` gets (push, merge, rebase,
      checkout, switch, reset, branch deletion, tag, publish, ship, deploy,
      release, undo, gh, curl, ssh, rm), the shell wrappers above, plus web
      fetch and paths outside the project. A test with a fake opencode proves the config the run is given;
      a test note in `docs/` records the live check (a denied `rm` leaves the
      file, an allowed `git status` runs).
- [x] The config is given to the run through `OPENCODE_CONFIG`, a file outside the
      project tree (measured: read with `--standalone`). autoupdate is off in it.
- [x] `WORKER_LADDER` (comma-separated `opencode-go/<id>`) defaults to
      `opencode-go/deepseek-v4.1-flash,opencode-go/glm-5.3,opencode-go/kimi-k3`.
      The first `just delegate` of a branch uses the first; each fix round on
      the same branch the next; past the last it refuses and says two failed
      tries go to the maintainer. `WORKER_MODEL` still pins one model.
- [x] The report ends with `cost: $<sum> on <model>, <n> steps`, summed from the
      run's `--format json` events; the raw events stay in the log outside the
      repo.
- [x] `just delegate-status` shows the model and the cost of the last run.
- [x] An unknown `WORKER` still refuses, now listing claude, grok, opencode.
- [x] The freshness block watches opencode as it watches grok.
- [x] The delegate skill, docs/01-getting-started.md and the CHANGELOG say all
      of this; the self-test covers the ladder, the cost line and the refusal.

## Tasks

- [x] Measure first, on this Mac (opencode 2.1.2, 2026-10-22, DeepSeek V4.1 Flash on a
      scratch repository): `OPENCODE_CONFIG=<file outside the tree> opencode run --standalone`
      reads the file, and its deny rules hold: `rm probe.tmp` and
      `git status --short && rm probe.tmp` were refused and the file stayed. But
      `sh -c 'rm probe.tmp'` ran and removed it: a pattern list matches the command's
      start, so a shell wrapper steps around it. The list therefore also denies
      `sh *`, `bash *`, `zsh *`, `eval *`, `xargs *` and `env *`, and the spec's
      guard stays what it is for every worker: the breach check after the run
      (a push, a moved default branch or base, a changed branch list). The deny
      list is a fence, not the guard.
- [x] `delegate_opencode` in `core.just`, the config, the ladder, the cost line;
      self-test with a fake opencode.
- [x] `delegate-status`, the freshness watch, the skill, the getting-started
      page, the CHANGELOG.
