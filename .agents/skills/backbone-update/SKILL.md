---
name: backbone-update
description: Pull updates from ai-backbone, the backbone this repo is built on, without losing project-owned files. Use when just session-start or just doctor reports the backbone is behind, or when the maintainer asks to update the template.
---

# Backbone update

The backbone owns only the files listed in the `[project]` section of
`.ai-backbone/manifest.txt`. Everything else is the project's and is never touched.

## Steps

1. Finish and save unrelated work first. Never update in the middle of something.
2. `just template-check` says whether there is anything to pull and which
   version is available. Since 3.41.0 that is the version marked stable in
   the backbone (its `STABLE` file), not every version: a project says
   "behind" only below it, and "ahead" when it is past it, which is fine.
   `just template-update newest` goes past the mark; do it only when the
   maintainer or a backbone fix this project needs asks for it.
3. `just template-update` copies the owned files. It looks for the backbone in
   `AI_BACKBONE`, then in a sibling `ai-backbone` folder up to three levels
   up, then clones it from GitHub. At the end it prints the CHANGELOG entries
   between the old and the new version, and says when one of them names
   `AGENTS.md`. It never moves a project down to an older version.
4. Explain to the maintainer in one paragraph, in their language, what changed
   and why. Plain words.
5. `just sync-rules` regenerates the rule copies and skill copies.
6. If the changelog says `AGENTS.md` gained a rule, add it to this project's
   `AGENTS.md` by hand. That file is project-owned and is never overwritten.
7. `git status`, then `just save "chore: backbone <version>"`.

## Rules

- Never edit `.ai-backbone/core.just` in a project. The next update overwrites it.
  Change it in the backbone and update everywhere.
- Never delete a file the maintainer wrote to make an update apply. If two
  files clash, keep theirs and ask.
