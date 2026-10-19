# Agent capability matrix

Dated **2026-10-19**, for backbone **3.41.2**. What each agent can rely on from
this repo, by evidence — not by vendor marketing. Values:

| Value | Meaning |
|---|---|
| **verified** | Named test or observed session on this machine / CI, with the result |
| **instruction-only** | File or hook exists; behaviour not measured on that agent |
| **unavailable** | Agent has no place for this kind of control |
| **unverified** | Not tried here |

Rows: rules (AGENTS.md and generated copies), skills (SKILL.md and copies),
session entry (`just session-start` at start), permissions (deny/allow before a
command), subagent limits (cap before spawning).

| Agent | Rules | Skills | Session entry | Permissions | Subagent limits |
|---|---|---|---|---|---|
| Claude Code | instruction-only | instruction-only | instruction-only | instruction-only | instruction-only |
| Cursor | verified | verified | verified | unavailable | unverified |
| Codex | instruction-only | instruction-only | unverified | unavailable | unverified |
| Gemini CLI | instruction-only | instruction-only | unverified | unavailable | unverified |
| Copilot | instruction-only | unverified | unverified | unavailable | unverified |
| Junie | instruction-only | unverified | unverified | unavailable | unverified |
| Zed | instruction-only | unverified | unverified | unavailable | unverified |

## Evidence

### Shared (all agents that read the tree)

- **Rules:** `AGENTS.md` is the source. `just sync-rules` writes whole copies for
  the tools named in §0 (`tools` row): today `claude` only, so
  `.github/copilot-instructions.md` and `.junie/guidelines.md` are not generated
  until those tools are listed. Pointers: `CLAUDE.md`, `GEMINI.md`.
- **Skills:** `.agents/skills/*/SKILL.md`. Claude copies under `.claude/skills/`
  from `sync-rules`. A copy is removed when its source is gone only if this
  recipe wrote it and nobody has edited it since (`.claude/skills/.ai-backbone-owned`).
  An edited copy, or one the recipe never recorded, is named and left.
  Other agents must find `.agents/skills/` themselves unless a later sync
  target is added.
- **Session:** `just session-start` / `just session-end` work from any shell that
  has `just`. Automatic run at session open is Claude Code's SessionStart hook
  only (`.claude/settings.json`).

### Claude Code

- SessionStart runs `just session-start`. PreToolUse runs `agent-cap.sh` for
  `Agent|Workflow`. Allow/deny lists in `.claude/settings.json`.
- **Not verified on this machine (2026-10-19):** `claude` is not on PATH; no
  measured match of allow/deny or ask rules against the pinned Claude Code.
  Spec 031 keeps that measurement open. Docs state the list is not a security
  boundary (`docs/how-it-works.md`).

### Cursor (this session, 2026-10-19)

- **Rules verified:** agent followed `AGENTS.md` / session protocol (`just
  session-start`, `just save`, `just publish`, `just carry`) in the attended
  carry of 3.41.0 and 3.41.2.
- **Skills verified:** `session`, `spec`, `backbone-dev` read from
  `.claude/skills/` / `.agents/skills/` and applied.
- **Session entry verified:** started with `just session-start` by hand; no
  Cursor-native SessionStart hook in this repo.
- **Permissions unavailable:** Cursor does not read `.claude/settings.json`
  (`docs/how-it-works.md`). Approvals are the product's own.
- **Subagent limits unverified:** no Cursor-native equivalent of `agent-cap.sh`
  measured; Cursor Task/subagents were not capped by this repo's hook.

### Codex, Gemini CLI, Copilot, Junie, Zed

- **Rules instruction-only:** would read `AGENTS.md` (and Copilot/Junie copies
  when `tools` lists them). No session observed here on 2026-10-19.
- **Permissions unavailable:** they do not use `.claude/settings.json`.
- **Skills / session / subagent limits:** unverified unless noted above.
- Zed is installed on this machine (`/usr/local/bin/zed`); no agent session was
  run against this repo for this matrix.

## Smoke checks (safe)

Repeatable, no paid delegation, no destructive git:

1. `just session-start` — prints backlog / journal / working tree; exit 0.
2. `just --list` — shows `save`, `publish`, `carry` (backbone) / project recipes.
3. Open `AGENTS.md` and one skill under `.agents/skills/session/SKILL.md`;
   confirm the agent cites them before editing.
4. Claude Code only, when installed: open a session and confirm SessionStart
   output appears without typing `just session-start`.

Record new verifications in this file with date and backbone version.
