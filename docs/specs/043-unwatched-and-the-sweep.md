---
status: approved
date: 2026-11-11
---

# 043 — Flag what is not watched, and sweep every project

Closes n-058e8b.

## What

A package declared in `package.json` (`dependencies` and `devDependencies`), in a `Cargo.toml` `[workspace.dependencies]` table, or in `pyproject.toml` with no `[[watch]]` row is a line `not watched: <name>`. `just upstream` prints those lines, and so does the FRESHNESS block at session start. A row `[[unwatched]]` with `name` and `why` is the allow-list: that package is left out on purpose and is not flagged. A watch covers a name when the row's `name` is that name, or its source is `npm:`, `crates:`, `pypi:`, `pub:` or `brew:` of that name.

`just freshness-sweep` reads every project listed for this machine, the way `just projects` does, and writes one file of `Behind:` and `not watched:` lines per project. `just freshness-sweep-install` installs a launchd job that runs that sweep every day at 08:15, the way a daily pull is installed: the script launchd runs is a copy outside the project, and this checkout is marked the desk (`git config --local ai-backbone.desk true`). The desk's `just session-start` prints the file. It says when the file is missing or older than 24 hours.

## Why

Watch rows are written by hand. A dependency with no row is never checked, and a `Behind:` line in one project's session start is read by nobody else. One major sat that way for months.

## Not doing

- No row is generated. The line says what is missing; a person or an agent adds the `[[watch]]` or the allow row.
- No upgrade. The sweep reports.
- The sweep does not write into another project's git directory.
- launchd still cannot read Desktop, Documents or Downloads. The installer says so. A session runs `just freshness-sweep` in that case.

## Tasks

- [x] `not watched:` in `just upstream` and in FRESHNESS, with the allow-list.
- [x] `just freshness-sweep` writes the file; the installer loads the daily job; the desk's session start prints the list.
- [x] The self-test covers a watched crate, an allowed package, an unwatched one, a behind line from the cache, the plist, and the desk line.
