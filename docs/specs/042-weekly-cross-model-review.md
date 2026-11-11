---
status: draft
date: 2026-11-11
---

# 042 — weekly cross-model review

## What

`just review-week` reviews the code merged to `main` since the last review with a model **other than the ones that wrote it**. It writes the findings as one report, and the desk turns verified findings into fix tasks.

A project lists the reviewers it has subscriptions for in `review.toml`. Security review can be pinned to one reviewer.

## Why

The owner asked for it on 2026-11-11, after a company desk started a weekly design review for a Rust project's parallel Grok and DeepSeek lanes.

Three reasons:

1. **Workers write most of the code now,** and the desk cannot read every line at their speed.
2. **A model reviewing its own output repeats its own blind spots.** A different model catches different mistakes.
3. **Security deserves a dedicated reviewer.** A project with a Kimi, GLM or ChatGPT subscription should be able to point security review at it.

## Not doing

- **Replacing the phase-end audit** (the audit skill). The weekly review is lighter and runs every week; the audit still runs before a release.
- **Fixing code.** The reviewer is read-only. Fixes go through `just delegate` like any other task.
- **Sending code to a provider the project has no account with,** or sending anything before the secret scan passes.

## Design

### `review.toml`

At the project root:

```toml
[review]
reviewers = ["claude", "kimi", "glm", "chatgpt"]  # those with a subscription, in order of preference
security  = "kimi"                                # optional: the reviewer for the security lens
cadence   = "weekly"                              # weekly | per-release
```

### Authors

Each delegate log already names its worker. Commits accepted by `just delegate-accept` are attributed to that worker; commits made in the desk session are attributed to the desk's model.

### Choosing the reviewer

The reviewer is the first name in `reviewers` that wrote none of the commits under review. If every listed reviewer is also an author, the recipe says so and stops: there is no self-review.

### Adapters

The worker adapters already exist: `claude`, `grok`, `opencode` and `kimi`. This spec adds two:
- `chatgpt`, through the Codex CLI;
- `glm`, through opencode with a GLM provider.

Each runs read-only, with no write tools.

### The range

From the commit recorded in `docs/reviews/.last-review` to `HEAD` on `main`. A huge range is split by module, so each call stays within a model's context.

### Lenses

Each lens is one call:
1. **design:** the design skill and the project's ADRs;
2. **security:**
   - authorization and tenant isolation;
   - injection, and secrets in code;
   - unsafe deserialization;
   - dependency advisories (`cargo audit` or `npm audit` output passed in);
3. **tests:** behaviour changed without a test, and assertions that prove nothing.

### Output

`docs/reviews/<YYYY>-W<ww>-<reviewer>.md`. Each finding gives:
- a file and line;
- the lens;
- a one-line claim;
- a failure scenario;
- a severity.

The desk verifies each finding before it becomes a task, as the audit skill already does. Unverified findings stay in the report marked as such.

### Before anything is sent

`just secrets-scan`, or the project's gitleaks hook, runs on the range first. A hit stops the review.

### Subscriptions

A reviewer missing from `reviewers` is never called. This keeps a rule like "no Kimi until the owner subscribes" in one place.

## Questions

Each has the answer this spec would use.

1. **Who triggers it?** The desk, once a week, through its session start. `just session-start` says "a weekly review is due" when `.last-review` is older than 7 days. Suggested.
2. **Does it cost a subscription?** Yes, the reviewer's own. The report records which model ran and how long it took.
3. **Private repositories:** is sending code to a listed provider acceptable? Suggested yes, because listing a reviewer in `review.toml` is the owner's consent for that project.

## Acceptance

- [ ] `just review-week` on a repository whose last week was written by `grok` picks a reviewer other than grok, and writes `docs/reviews/<week>-<reviewer>.md` with three lenses.
- [ ] With only grok in `reviewers` and only grok as an author, it refuses and names why.
- [ ] A secret in the range stops the review before any call (test with a fake key).
- [ ] `security = "kimi"` sends the security lens to kimi, and the other lenses to the next reviewer.
- [ ] `just session-start` warns when a review is due.
- [ ] The `chatgpt` and `glm` adapters run read-only (proved by a denied write in a test).

## Tasks

- [ ] `review.toml` and its parser; author attribution from the delegate logs.
- [ ] `just review-week`: range, split, three lenses, the report, `.last-review`.
- [ ] The `chatgpt` and `glm` read-only adapters.
- [ ] The secret-scan gate before sending.
- [ ] The session-start reminder; docs (`docs/how-it-works.md`, the delegate skill).
