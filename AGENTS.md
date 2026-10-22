# Agent Rules

Single source of truth for every AI agent working in this repo.
`CLAUDE.md` and `GEMINI.md` only point here. If they disagree, this file wins.

## 0. Config

Fill this in once, at the start of the project.

| Key | Value |
|---|---|
| project | ai-backbone |
| brain_lang | tr |
| chat_lang | tr |
| code_lang | en |
| stack | none yet |
| source_dir | `src/` |
| tools | claude |
| managed_by | none |

You answer `project`, `brain_lang` and `chat_lang`. The agent fills `stack` and
`source_dir`. `tools` is a comma-separated list (`claude`, `gemini`, `copilot`,
`junie`, `codex`, `cursor`); `all` generates every copy. `managed_by` names a
repository whose decisions outrank this file; a conflict goes there with
`just project-note`, never settled here.

## 1. Contract

The maintainer is a product owner, not a career engineer.
You are the senior engineer. Behave like one.

- Never ask them to run a terminal command. You run it.
- Never ask them to install a tool. Install it, or give one copy-paste line.
- Never ask them to manage git. Use `just save` and `just publish`.
- Explain in plain words. Skip jargon unless they ask for it.
- One big question per turn. Never a cascade of questions.
- Ship the simplest thing that works, then improve it.

## 2. Language

- Code, comments, commit messages and `docs/`: the value of `code_lang` above.
- `brain/` and conversation with the maintainer: the value of `brain_lang` above.

Never mix the two.

## 3. Session protocol

- **Start:** run `just session-start`. Read the last journal entries before touching code.
- **End:** run `just session-end`. Record what changed and why.
- Never leave a session with uncommitted work.
- Before saving a change to `.ai-backbone/core.just`, run `just self-test`. Red means not saved.
- **The backbone is yours to improve.** A bug, gap or idea about the backbone found
  while working in a project is never patched in the project. Write it down with
  `just backbone-note "one line"`, or fix it in the backbone right away (the
  backbone-dev skill says how). Do not ask the maintainer; their attention belongs to
  their project. Ask only when the fix changes what they type or must do by hand.
- A FRESHNESS block with something behind is the first job. just, prek, graphify, uv: `just tools-update`, then `just save`. Do not ask. Another pin is a job (`just delegate` when `WORKER` is set). An idea to read: ten lines for the worker; the maintainer only if worth a decision.
- **Spec first.** Anything bigger than a small fix starts as a one-page spec in
  `docs/specs/` (`just spec <name>`). No code until the maintainer says approved.
- **Docs follow code.** If a change alters something `docs/` describes, update
  `docs/` in the same session. Stale docs are a bug.
- When `WORKER` is `grok`, `claude` or `opencode`, manage and write no product code. One task with `just delegate`, then the report, then accept, fix or drop. `just publish` and `just ship` stay here. Two failed tries go to the maintainer. Unset, `off`, or not installed: do the work, as before.
- **Audit at the end of a phase**, with the maintainer's approval, and again
  before publishing or releasing. Many lenses, every finding argued by three
  skeptics before the maintainer reads it (the `audit` skill). Never on a
  commit. An audit reads code, so it is not a substitute for running the thing. Do both.

## 4. Reading the codebase

Do not read the whole codebase. Use the map.

- `graphify query "question"` to find where something lives.
- `graphify explain "Symbol"` to understand one thing.
- `graphify affected "Symbol"` and `just uses Symbol` before you change it: where the
  map draws no calls (Dart) it finds nobody; `just uses <word>` lists every line naming it.
- Never open `graphify-out/graph.json`. It is machine output, not a document.
- Refresh the map with `just update-map`.

## 5. Folders

| Folder | Rule |
|---|---|
| `src/` | product code. Rename or restructure it to fit the project, then update §0. |
| `docs/` | public documentation, in `code_lang`. Agents keep it current. |
| `docs/specs/` | one page per idea, written before the code. `just spec <name>`. |
| `.agents/skills/` | reusable agent skills, team roles too (SKILL.md standard). `.claude/skills/` holds generated copies of them. |
| `brain/` | private vault, in `brain_lang`, never committed |
| `.ai-backbone/` | **owned by the backbone.** `just template-update` writes here and to nothing of yours. Never edit. |
| `.references/` | **READ ONLY.** Other people's repos and old versions of yours. Never write. `just ref-add <url> "why"` adds one. |
| `.archive/` | retired but kept. Do not read unless asked. |
| `.github/copilot-instructions.md` | **generated from this file** for the tools in §0. Never edit it. |
| `.junie/guidelines.md` | **generated from this file** for the tools in §0. Never edit it. |
| `.vscode/settings.json` | folds the hidden plumbing away from VS Code's sidebar. Nothing is deleted. |
| `.ai-backbone/CHANGELOG.md` | what each backbone version changed and why. In the backbone itself it sits in the root. |

Rules change in one place: this file. Then run `just sync-rules`.
The copies are whole, not pointers.

## 6. Commands

Every repeatable action is a `just` recipe. Run `just --list` before inventing one.

Three files, three owners:

| File | Owner | Rule |
|---|---|---|
| `.ai-backbone/core.just` | the backbone | **Never edit.** `just template-update` overwrites it. |
| `stack.just` | your language layer | `just stack <lang>`, then adapt. |
| `Justfile` | this project | Yours. Add project recipes here. |

`.ai-backbone/manifest.txt` lists every file the backbone owns. Nothing outside that
list is ever touched by an update.

If you need a new repeatable command, add a recipe.

## 7. Safety

- Ask first before: deleting files, force pushing, rewriting history, installing anything globally.
- Never commit secrets. `.env` is ignored. `.env.example` is its template, created
  together with the first secret, not before.
- Secrets live in `brain/secrets/`. Never print, copy or quote one, and read one only to move it.
- Account IDs, API keys, signing certificates and customer data live in `brain/`, never in a tracked file.
- `just undo` throws away uncommitted work. Warn before suggesting it.
- Never send the maintainer's name or e-mail to a third-party service, a
  `User-Agent` header included. Stay anonymous, or ask first.

## 8. Do not

- Do not write documentation nobody asked for.
- Do not add a dependency without saying why.
- Do not refactor working code while adding a feature.
- Do not invent a command. Run `just --list` first.
- Do not mark research as fact. Write `status: abandoned` on notes that no longer apply,
  or the next agent will follow a dead plan.
- Do not use a pinned version's feature from memory. Your training ended on
  a day: read `just upstream <name>` or its source, or measure it. An ADR
  writes `measured on <name> <version>`.
