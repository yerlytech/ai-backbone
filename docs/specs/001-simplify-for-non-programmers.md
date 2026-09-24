---
status: done
date: 2026-09-13
---

# 001 — simplify for non-programmers

## What

A fresh project made with `just new-project` is something a person who has
never seen a terminal can open in Finder, understand in one glance, and run
by talking to their agent. Everything the backbone owns moves into one hidden
folder, `.ai-first/`. The visible tree of a new project becomes:

```
AGENTS.md   Justfile   README.md   LICENSE   docs/   src/   brain/
```

plus the three-line pointers `CLAUDE.md` and `GEMINI.md`. Typing `just` shows
the four commands a human might ever type. Everything else still exists for
the agent under `just --list`.

## Why

Tested on 2026-09-13 by creating `../todo` from the backbone and building a
one-file to-do app with it. What the backbone does well: one-command project
creation, real secrets blocked at save time, clear `doctor` output, safe
`undo`, `publish` that prints the exact command when there is no remote.

What a non-programmer hits on day one:

1. **A red error after doing exactly what they were told.** `session-end` says
   "write the entry, then `just save`". The journal is private and never
   committed, so `save` prints `nothing to commit` and `error: recipe save
   failed`. Every session that ends with only a journal hits this.
2. **47 files in a brand-new empty project**, 12 in `docs/` alone: the
   backbone's own ADRs, Rust and Swift examples, Dependabot files, the
   backbone's CHANGELOG, a LICENSE naming `yerly.tech` as copyright holder.
   None of it is theirs.
3. **18 commands** in `just`, with words like "stack.just", "derived rule
   files", "code map", "language layer". A human needs four.
4. **Six installs before the first command.** `just new-project` needs `just`,
   which needs Homebrew; then `uv`, `prek`, `graphify`, `gh`. The README leads
   with a command the reader cannot run yet.
5. **Eleven lines of hook chatter** on every save and on project creation.
   The one line that matters, `Saved.`, is at the bottom.
6. **Section 0 asks six questions** (stack, source_dir, code_lang...). A human
   can answer two: the project name and the language they think in.
7. Small things: `just spec "yapılacaklar listesi"` creates a file with a
   space in its name; `doctor` warns "no code map" forever on a project
   graphify cannot parse; nothing stops a Turkish commit message; `src/README`
   asks the human to decide on a folder layout they have no opinion about.

Ideas borrowed, and where we stop: OpenSpec's propose → apply → archive is our
`status: draft → approved → done`, one file instead of a folder of four.
Spec Kit's constitution is `AGENTS.md`; its *clarify* step becomes a
`## Questions` section in the spec template, asked one per turn. Nothing else
from either is taken; both add tooling where one file is enough.

## Layout (approved 2026-09-13)

Visible in a project: `README.md AGENTS.md Justfile LICENSE docs/ src/ brain/`
plus the pointers `CLAUDE.md` and `GEMINI.md`. Hidden: `.ai-first/` (core.just,
manifest.txt, setup.sh, CHANGELOG.md, brain-template/, templates/), `.agents/skills/`,
`.claude/`, `.github/`, `.junie/`, `.pre-commit-config.yaml`, `.editorconfig`,
`.gitignore`, `.env.example`, `.vscode/settings.json` (folds the rest away in VS Code).
Not created until needed: `.archive/`, `.references/`, `graphify-out/`, `.graphifyignore`,
`docs/specs/`, `docs/adr/`. Never copied: the backbone's ADRs and getting-started
page, language examples (`just stack <lang>` fetches them), Dependabot files.
Manifest sections: `[project]` kept current, `[seed]` copied once, `[backbone]` stays.

## Not doing

- No GUI, no installer app, no web dashboard. The human's interface is the
  agent and Finder.
- No change to what `brain/`, `docs/`, `src/` mean.
- No new dependencies. `just`, `prek`, `graphify`, `gh`, `uv` stay.
- No touching derived projects. They pick this up with `just template-update`
  when they choose to.

## Acceptance

Patch, `0.3.1`, ships first and alone:

- [x] `just save` with nothing to commit prints one calm line and exits 0.
      `session-end` says "your journal is private and is not part of a save".
- [x] `just save`, `new-project` and `session-end` show hook output only when a
      hook fails. A clean save prints the changed files and `Saved.`
- [x] `just spec "Yapılacaklar Listesi"` creates `002-yapilacaklar-listesi.md`.
- [x] `doctor` and `session-start` say "no code to map yet" instead of a
      warning when nothing parseable exists.
- [x] `new-project` stamps the git user's name and the current year into LICENSE.

Major, `1.0.0`, after approval of this page:

- [x] Backbone-owned files live under `.ai-first/`: the core recipes, the
      manifest, `brain-template/`, the examples, the backbone's ADRs and
      CHANGELOG. `Justfile` imports `.ai-first/core.just`. The manifest lists
      the new paths; `template-update` moves the old ones once and says so.
- [x] `git ls-files` in a fresh project shows 30 files (was 47). Visible in
      Finder: `AGENTS.md CLAUDE.md GEMINI.md Justfile README.md LICENSE docs/
      src/ brain/`.
- [x] `docs/` in a fresh project holds one `README.md`; `specs/` and `adr/`
      appear with the first spec and the first decision. Examples and the
      backbone's own ADRs stay in the backbone; the agent copies a stack file
      from there when a language is chosen.
- [x] Typing `just` prints four lines: `save`, `undo`, `publish`, `doctor`,
      and one sentence: "Everything else your agent runs; `just --list` shows
      it." `just --list` is unchanged for agents.
- [x] `just new-project todo tr` sets `project` and `brain_lang`/`chat_lang`.
      Section 0 keeps only what the human can answer; `stack` and
      `source_dir` are filled by the agent when the stack is chosen.
- [x] `.ai-first/setup.sh` installs every missing tool on a fresh Mac in one
      run, so the first thing a human says to the agent is enough even when
      `just` is not installed. `doctor` points at it.
- [x] README of the backbone is under 60 lines and written for the human:
      what this is, three steps to start (download, open in your AI tool, say
      one sentence), the four commands, where the rest lives. README of a new
      project is five lines.
- [ ] (partly) Every message a human might read in `core.just` is checked against
      one rule: no word the getting-started glossary does not define.
- [x] Spec template gains `## Questions`. The spec skill says: ask them one per
      turn, remove each when answered, approval only when the section is empty.
- [x] A `commit-msg` hook rejects a message that does not start with
      `feat|fix|docs|chore|test|refactor|style`. Turkish messages cannot slip
      through by accident.
- [x] `src/README.md` no longer asks the human to pick a layout. It says
      "your code goes here" and nothing else.
Migration, part of `1.0.0`. A project built on `0.3.x` runs `just template-update`
and loses nothing:

- [x] Before a major update the recipe runs `just snapshot` and prints the zip
      path, so there is always a copy to go back to.
- [x] Old backbone paths (`ai-first.just`, `template-manifest.txt`,
      `brain-template/`, `docs/examples/`, `docs/adr/0001-0002`, `CHANGELOG.md`)
      are moved with `git mv`, never deleted. History follows the file. The
      old path is removed only after the new one exists.
- [x] Files the project owns are never opened: `AGENTS.md`, `README.md`,
      `Justfile`, `src/`, `brain/`, `docs/specs/NNN-*`, `docs/adr/0003+`,
      `stack.just`, `.gitignore`, `.env.example`, `LICENSE`.
- [x] The `Justfile` import line is rewritten only when it is exactly the stock
      line. Otherwise the recipe prints the one line to change and stops short
      of editing.
- [x] Running the update twice changes nothing the second time.
- [x] `just template-check` says that a move is next, before anything moves before anything moves.
- [x] Verified on `../todo` (2026-09-13): after the update `git status` shows only renames
      and backbone files; `just doctor` is clean; the to-do app still opens.
- [x] Built a fresh project from `1.0.0` (deneme-projesi): 30 files, 9 visible, hooks on.

## Questions

None open. 0.3.1 shipped first, 1.0.0 the same day on the maintainer's go-ahead.
`CLAUDE.md` and `GEMINI.md` stay in the root as three-line pointers; those tools
look for their own filename there.

## Tasks

- [x] 0.3.1: fix `save` on a clean tree; quiet hooks on success; slugify spec
      names; soften the code-map warning; stamp LICENSE. Tag, CHANGELOG.
- [x] 1.0.0: move owned files into `.ai-first/`; update manifest, Justfile
      import, `template-update` migration, `new-project` copy list.
- [x] 1.0.0: `just` default prints the human list; the recipes agents use are
      grouped `agent`.
- [x] 1.0.0: `new-project <name> [lang]`; section 0 down to what a human answers.
- [x] 1.0.0: `setup.sh`; `doctor` points at it.
- [x] 1.0.0: README rewrite for the human; `docs/start-here.md`; five-line
      project README.
- [x] 1.0.0: spec template `## Questions`; spec skill; `commit-msg` hook.
- [x] 1.0.0: message audit against the glossary. Tag, CHANGELOG, journal.
- [x] 1.0.0: migration in `template-update` (snapshot, `git mv`, idempotent, dry run in `template-check`).
- [x] Update `../todo` from 0.3.1 to 1.0.0 in place and walk the migration list.
- [x] Fresh project from `1.0.0` walked the acceptance list.
