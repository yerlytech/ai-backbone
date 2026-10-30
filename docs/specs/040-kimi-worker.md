---
status: approved
date: 2026-10-30
approved: the agent, 2026-10-30 (company desk: the maintainer will not renew Grok and moves to the official Kimi subscription with Kimi Code CLI; this branch does not publish)
---

# 040 — kimi worker

## What

`WORKER=kimi` is a fourth worker for `just delegate`, beside `grok`, `claude`
and `opencode`. It runs `kimi -p` with `--output-format stream-json` in the
project folder. `DELEGATE_MODEL`, when set, is passed as `-m`. The deny list
is the same fence grok and opencode get, written as Kimi permission rules.
The stream-json log stays outside the repo. The report is the last 15 lines
of the assistant text in that log.

## Why

On 2026-10-30 the maintainer decided not to renew Grok and to move to the
official Kimi subscription, used through Kimi Code CLI. A delegated job has
to be able to run on that CLI the same way it runs on the other three.

Facts read from the Kimi Code CLI 2.4.0 docs
(`https://moonshotai.github.io/kimi-code/llms-full.txt`) and from the
installed 2.4.0 bundle on this machine, the same day. Nothing else was
assumed:

- Headless is `kimi -p "<prompt>" [--output-format text|stream-json] [-m <alias>]`.
  `-p` cannot be combined with `--yolo`, `--auto` or `--plan`. In `-p` there
  are no approval prompts. Tool calls use the auto policy. Static deny rules
  still apply.
- There is no `--config` flag and no general env override for rules.
  `KIMI_CODE_HOME` relocates the whole data directory, credentials included,
  so it is not pointed at a per-run folder. Project `local.toml` does not
  hold permission rules. The deny list is a marked block in the user
  `config.toml`, rewritten each run.
- `[[permission.rules]]` is `decision` plus `pattern`. First match wins.
  The bundled picomatch treats `*` as not crossing `/`, and `**` as crossing
  it. A glued `sh*` matches a longer name. Each denied command is therefore
  an exact `Bash(<command>)` and a `Bash(<command> **)`.
- `[permission] dangerous_command_guard` defaults to true. The env
  `KIMI_CODE_DANGEROUS_COMMAND_GUARD` is on only for the exact string `true`.
  The run sets that. The guard's own asks do not prompt in `-p`, so the
  secret paths are explicit deny rules.
- `[workspace] require_trust` defaults to true. The docs say a headless `-p`
  cannot show the trust prompt. They do not say it hangs. The run exports
  `KIMI_CODE_TRUST_WORKSPACE=1` for that process only, which the bundle
  treats as trusting the folder without writing a trust record.
- `kimi login` is a device-code flow that polls until it finishes. The docs
  name no status command. A run that is not logged in must stop with
  `kimi is not logged in: run kimi login` before it creates a branch.
- stream-json writes one JSON object per line. Assistant text is
  `role=assistant` and `content`. Tool results are `role=tool`. There is no
  cost field.

## Not doing

- A model ladder. Opencode climbs `WORKER_LADDER`. Kimi does not, and it
  does not read `WORKER_MODEL`.
- A cost line. The stream has no cost event.
- Pointing `KIMI_CODE_HOME` at the per-run cache.
- Setting `require_trust = false` in the user config. That would trust every
  folder permanently.
- A blanket deny of every path outside the project. Opencode has
  `external_directory: deny`. Kimi's rules deny the secret paths by pattern.
- Closing the grok backlog lines about an unmeasured shell wrapper and an
  unmeasured Read deny. Those are about grok.
- Calling `kimi -p` or `kimi login` from the tests or from this change.
- A version bump. That belongs to a publish, and this branch does not publish.

## Questions

(none; the desk named the worker, and the docs named the mechanism)

## Acceptance

- [x] `WORKER=kimi just delegate "<task>"` runs `kimi -p <prompt> --output-format stream-json` on a `delegate/` branch, with the same preamble the other workers get. `DELEGATE_MODEL` adds `-m`.
- [x] The known-worker lists (the recipe, the allow-rule gate, the skills, the docs, `AGENTS.md`, and session-start's worker line) name kimi.
- [x] The binary is `WORKER_BIN`, else `kimi` on `PATH`, else `~/.kimi-code/bin/kimi`, else `/opt/homebrew/bin/kimi`, else `/usr/local/bin/kimi`.
- [x] The generated rules deny the grok and opencode commands (push, merge, rebase, checkout, switch, reset, branch deletion, tag, publish, ship, deploy, release, undo, gh, curl, ssh, rm, and the wrappers sh, bash, zsh, eval, xargs, env), plus `just carry`, web search, URL fetch, and reads or writes of `~/.aws`, `~/.appstoreconnect`, `brain/03-stack` and `.env`. A user's own rule stays. The block is not duplicated on a second run, and it is the first match.
- [x] A machine with no credentials file and no api key is refused with `kimi is not logged in: run kimi login`, the fake is not run, no branch is created, and no config is written.
- [x] The log outside the repo holds the stream-json. The printed report is the last 15 lines of assistant content, not tool output.
- [x] Idle, timeout and breach behave as they do for the other workers, because the run goes through the same recipe after the adapter returns.

## Tasks

- [x] `delegate_kimi` in `core.just`, the login check, the marked block, the report.
- [x] Self-test with a fake `kimi` on `PATH`: a run, a denied command in the generated rules, not logged in, the report.
- [x] The skill, the docs, `AGENTS.md`, the watch row, the CHANGELOG entry under `[Unreleased]`.
