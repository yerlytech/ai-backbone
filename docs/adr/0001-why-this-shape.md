# 0001 — Why this repo is shaped this way

**Status:** accepted

## Context

A repo that an AI agent works in has a different failure mode than one only
humans touch. The agent reads what it is pointed at. If the rules live in
eight files, it reads a stale copy. If private notes sit next to public code,
they get committed. If it has to read the whole tree to answer one question,
it burns context and still misses things.

## Decision

Four concerns, four places.

1. **Rules.** `AGENTS.md` is the only rule file. `CLAUDE.md` and `GEMINI.md`
   are one-line pointers, because those tools look for their own filenames.
   One source, no drift.
2. **Memory.** `brain/` is private and in your language. `docs/` is public and
   in English. The split is enforced by `.gitignore`, a git hook, and a rule,
   so a single mistake cannot leak the vault.
3. **Commands.** Every repeatable action is a `just` recipe. The agent does not
   guess a shell incantation, and the maintainer does not memorise one.
4. **Map.** `graphify` builds a structural map. Agents query it instead of
   reading every file.

## Consequences

- A new agent is productive after reading one file.
- The core stays language-independent. A language layer arrives as `stack.just`.
- Private notes cannot reach GitHub by accident.
- The map needs refreshing. `just update-map` does it, with no API key.
