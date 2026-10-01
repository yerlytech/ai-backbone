# 0002 — One ruleset, several filenames

**Status:** accepted

## Context

Every coding agent looks for its own filename. There is no single file all of
them read, and the behaviour differs in ways that matter.

Verified against the vendors' own documentation:

**Zed** scans a fixed list and uses **the first file it finds**, ignoring the rest:

```
.rules · .cursorrules · .windsurfrules · .clinerules
.github/copilot-instructions.md · AGENT.md · AGENTS.md · CLAUDE.md · GEMINI.md
```

**GitHub Copilot** reads `.github/copilot-instructions.md`, path-scoped files under
`.github/instructions/`, and `AGENTS.md` anywhere in the tree, nearest first.
Precedence between them is not documented.

**JetBrains Junie** checks `.junie/AGENTS.md`, then root `AGENTS.md` together with
`.junie/playbook.md` and `.junie/rules/*.md`, then legacy `.junie/guidelines.md`.
That order is documented for the CLI. The IDE plugin's behaviour is not.

An earlier version of this template shipped eight hand-written rule files. Six were
copies of the same text. They had already drifted from each other before the template
was finished.

## Decision

`AGENTS.md` is the only file anyone edits.

- `CLAUDE.md` and `GEMINI.md` stay one-line pointers. Those two tools support a
  mechanical `@file` import, so a pointer delivers the full ruleset.
- `.github/copilot-instructions.md` and `.junie/guidelines.md` are **generated
  copies** of `AGENTS.md`, written by `just sync-rules`.
- A `prek` hook named `rules-in-sync` rejects any commit where a generated file
  no longer matches its source.
- Files that only cause harm are absent: `.cursorrules`, `.windsurfrules`,
  `.clinerules`, `.rules`. Cursor reads `AGENTS.md` natively, and leaving those
  names empty keeps Zed walking down its list until it reaches a file we maintain.

## Why copies and not pointers

Because of Zed. It stops at `.github/copilot-instructions.md`, which sits above
`AGENTS.md` in its list. If that file said "the rules are in AGENTS.md", Zed would
take those three lines as the entire ruleset and never open the real one.

A generated copy costs nothing, cannot drift, and means every tool gets the same
complete text no matter which filename it happens to find first.

## Why there is no llms.txt

An earlier draft of this template shipped `llms.txt` and `llms-full.txt`. Both are gone.

`llms.txt` is a **web** convention. It belongs at the root of a served site, next to
`robots.txt`, and it describes the URLs underneath it. Its reader is an agent pulling a
library's documentation over HTTP, which otherwise has to dig the content out of rendered
HTML. The specification does not cover source repositories at all.

An agent working inside this repo has the filesystem. It opens `AGENTS.md`. A curated
index of web pages solves a problem it does not have.

In the earlier draft both files were hand-maintained copies of the same ruleset, which is
exactly the drift this ADR exists to prevent.

If this project ever publishes a documentation site, `llms.txt` belongs at that site's
root, pointing at real pages. It still does not belong in the repository.

Source: <https://llmstxt.org/>

## Consequences

- Three files hold the same content. That is duplication, and it is deliberate.
  It is safe only because a machine writes it and a hook checks it.
- Changing a rule is still a one-file edit, followed by `just sync-rules`.
- If Junie's IDE plugin turns out to read `AGENTS.md`, delete one line from
  `sync-rules` and the file with it.
- New agent, new filename: add one line to `sync-rules`, one row to the README table.

## Sources

- <https://github.com/zed-industries/zed/blob/main/docs/src/ai/rules.md>
- <https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions>
- <https://junie.jetbrains.com/docs/guidelines-and-memory.html>
