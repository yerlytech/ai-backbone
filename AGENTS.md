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

You answer `project`, `brain_lang` and `chat_lang`. The agent fills `stack` and
`source_dir` when the time comes. `tools`: the AI tools you use (`claude`, `gemini`,
`copilot`, `junie`, `codex`, `cursor`), comma-separated. `all` generates copies for
every tool.

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

Never mix the two. A Turkish commit message in an English repo is a bug.

## 3. Session protocol

- **Start:** run `just session-start`. Read the last journal entries before touching code.
- **End:** run `just session-end`. Record what changed and why.
- Never leave a session with uncommitted work.
- Before saving a change to `.ai-backbone/core.just`, run `just self-test`. It builds
  throwaway projects and shows what a person would see. Red means not saved.
- **The backbone is yours to improve.** A bug, gap or idea about the backbone found
  while working in a project is never patched in the project. Write it down with
  `just backbone-note "one line"`, or fix it in the backbone right away (the
  backbone-dev skill says how). Do not ask the maintainer; their attention belongs to
  their project. Ask only when the fix changes what they type or must do by hand.
- When `just session-start` says a tool is behind, run `just tools-update`, then
  `just save`. Do not ask.
- **Spec first.** Anything bigger than a small fix starts as a one-page spec in
  `docs/specs/` (`just spec <name>`). No code until the maintainer says approved.
- **Docs follow code.** If a change alters something `docs/` describes, update
  `docs/` in the same session. Stale documentation is a bug.
- **Audit at the end of a phase**, with the maintainer's approval, and again
  before publishing or releasing. Many lenses, and every finding argued against
  by three skeptics before the maintainer reads it (the `audit` skill). Never on
  a commit: it is expensive and deliberate. An audit reads code, so it is not a
  substitute for running the thing on a real machine. Do both.

## 4. Reading the codebase

Do not read the whole codebase. Use the map.

- `graphify query "question"` to find where something lives.
- `graphify explain "Symbol"` to understand one thing.
- `graphify affected "Symbol"` and `just uses Symbol` before you change it: the map draws no calls in some languages (Dart), the word search reads them all. Where the map draws no
  calls (Dart) it finds nobody: `just uses <word>` lists every line naming it.
- Never open `graphify-out/graph.json`. It is machine output, not a document.
- Refresh the map with `just update-map`.

## 5. Folders

| Folder | Rule |
|---|---|
| `src/` | product code. Rename or restructure it to fit the project, then update §0. |
| `docs/` | public documentation, in `code_lang`. Agents keep it current. |
| `docs/specs/` | one page per idea, written before the code. `just spec <name>`. |
| `.agents/skills/` | reusable agent skills (SKILL.md standard). `.claude/skills/` holds generated copies of them. |
| `brain/` | private vault, in `brain_lang`, never committed |
| `.ai-backbone/` | **owned by the backbone.** Its recipes, manifest, templates and setup script. `just template-update` writes here and to nothing of yours. Never edit. |
| `.references/` | **READ ONLY.** Other people's repos and old versions of yours. Never write there. Created when first needed. `just ref-add <url> "why"` adds one. |
| `.archive/` | retired but kept. Do not read unless asked. Created when first needed. |
| `.github/copilot-instructions.md` | **generated from this file** for the tools in §0. Never edit it. |
| `.junie/guidelines.md` | **generated from this file** for the tools in §0. Never edit it. |
| `.vscode/settings.json` | folds the hidden plumbing away from VS Code's sidebar. Nothing is deleted. |
| `.ai-backbone/CHANGELOG.md` | what each backbone version changed and why. In the backbone itself it sits in the root. |

Rules change in one place: this file. Then run `just sync-rules`.
The derived copies exist because some editors look for their own filename and stop
at the first one they find. A short pointer would leave them with three lines instead
of the whole ruleset, so they get a full copy instead.

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

If you need a new repeatable command, add a recipe. Do not leave it in chat history.

## 7. Safety

- Ask first before: deleting files, force pushing, rewriting history, installing anything globally.
- Never commit secrets. `.env` is ignored. `.env.example` is its template, created
  together with the first secret, not before.
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
- Do not use a feature of a pinned version from memory. Your training ended on a day
  and the pin may be past it: read its notes (`just upstream <name>`) or its source on
  this machine, or measure it. In an ADR that rests on it, write
  `measured on <name> <version>`.
