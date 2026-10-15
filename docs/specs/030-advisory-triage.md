---
status: draft
date: 2026-10-15
---

# 030 — An advisory looked at, written down

Asked for on 2026-10-15 by the managing session on the owner's word, as the
next backbone work; the technical decisions are that session's. Closes the
backlog line n-bcfbed.

## What

A Rust project writes down, in `docs/advisories.toml`, each RustSec advisory
it has looked at and ships anyway: the advisory's id, the crate, the reason in
one line, the fixed versions as they stood that day, and a last day at most 90
days ahead. `just session-start` and `just doctor` stop repeating an advisory
with a valid row, and say it again when its day has passed, when RustSec's
fixed versions are no longer what the row recorded, or when the row cannot be
used. A second advisory of the same crate has no row, so it is said like any
new one. `upstream.py --advisories gate --triaged <file> <Cargo.lock>...`
judges the files it is given, one line per advisory, and exits non-zero when
any advisory is not covered: what a project's `just ship` calls.

## Why

Since 3.38.0 every Rust project hears about a published vulnerability in its
Cargo.lock (spec 029). Some cannot be updated: a crate only tests build, a fix
behind a dependency's exact pin (SurrealDB), a key that is public and only
verifies. session-start then says `cargo update -p <name>` every session for
something nobody can update, and a new advisory drowns among the old ones on
the page an agent reads first. And a ship has nothing to stop on: it should
refuse a vulnerability nobody has looked at, and pass one somebody has, for a
stated reason and for a while.

## The file

```toml
# RustSec advisories this project has looked at and ships anyway.
[[triaged]]
id = "RUSTSEC-2023-0071"
crate = "rsa"
why = "the key is public and only verifies signatures"
fixed = "none"        # what doctor prints after "fixed in", or none
until = 2026-12-31    # at most 90 days ahead; holds through that day
```

Its own file, not a section of `docs/upstream.toml`, because:

- not every Rust project has a watch list, and one made only to hold a triage
  would have `just upstream` say it watches nothing;
- `docs/upstream.toml` is edited by code: `just tools-update` rewrites `pin`
  lines in place, and `_tool-pins` reads it with awk that knows only
  `[[watch]]` blocks, so a row of another kind would be read into the block
  above it;
- the rows expire and are reviewed on a rhythm of their own, and the gate gets
  one small file whose history is triage and nothing else;
- it is the project's file, made with its first row: no template, nothing in
  the manifest, and a new project's file count does not move.

A row silences nothing, and is said with its fault, when it has no `why` or no
`fixed`, names a crate other than the advisory's, or has an `until` that is
not a date or is more than 90 days ahead. A row covers every Cargo.lock of the
project. doctor prints a triaged advisory as `info` with its reason and day,
so the list stays in sight, and a row that matches nothing in any lock as
`info ... -> remove the row`. session-start prints nothing for it.

## The gate

`upstream.py --advisories gate [--triaged <file>] <Cargo.lock>...`

- Reads only the paths it is given, never the `docs/` of the folder it runs
  in: a clean copy of the commit, or `git show` output in a temporary folder,
  is what is judged.
- One line per advisory and lock, its first word the state: `triaged`,
  `untriaged`, `expired`, `changed` (the fixed versions moved), `invalid` (the
  row cannot be used); then the lock as given, the crate, its version, the id
  and the fixed versions. No title, no reason text, nothing from the
  environment. Triaged ones are printed too, so the ship's output records what
  was shipped knowingly.
- A last line: `database <date>`, or `stale` (below).
- Exit 0 when every advisory is `triaged`, or there is none. 1 when any other
  state is printed: the gate refuses exactly what session-start would say
  again. 2 when the check could not run: no Python with tomllib, a lock or the
  triage file unreadable or not TOML, or no copy of the database at all. A
  `--triaged` path that does not exist is read as an empty list and said on a
  line: that can only make the gate stricter, and the caller need not check
  whether the project has a file yet.
- Notices (`unmaintained`, `unsound`, `notice`) do not count, as in doctor.

**An old database.** As the managing session leans: when the copy was last fetched more
than 7 days ago and cannot be fetched now, the gate prints `stale <date>,
fetched N days ago` and still decides by what it read. The copy knows every
advisory up to its date, and a release that a GitHub outage can block teaches
people to switch the gate off; the line is in the ship output a person reads.
No copy at all is another case: nothing was read, so 2, never 0. The fetch
rule stays (at most once a day), so a ship reads the copy session-start read
that day.

## Only tests build it

Cargo.lock does not mark a dev-dependency. Asking cargo (`cargo tree -e
normal`) resolves the workspace, may reach the network and costs seconds, and
session-start must not. So a row by hand: `why = "only tests build it"`.

A better way, offered and not built here: read the members' Cargo.toml files
beside Cargo.lock and walk Cargo.lock's own `dependencies` lists from what the
members name under `[dependencies]` and `[build-dependencies]`; what that never
reaches is built only for tests. No cargo, about a millisecond. It must follow
renames (`package =`), `workspace = true` and `[target.*]` tables, and an edge
misread would call a shipped crate test-only; so it would only label a
finding "(only tests, by Cargo.toml)" to speed the triage, never silence it.
A backlog line if wanted.

## Not doing

- A command that writes rows: the reason is the point, and an agent writes it.
- A row per Cargo.lock.
- cargo-audit's or cargo-deny's ignore lists: neither is installed here (029).
- A fresh fetch forced at ship time.

## Questions

- **`fixed`, a fifth field, required.** "Said again when a fix becomes
  reachable (the version line changed)" is read as RustSec's fixed-versions
  line for that advisory, compared with what the row recorded: the check
  cannot know the Cargo.toml requirement or the dependency that pins it, but
  it can see the line move. Without the field that cannot be seen. A new
  version of the crate in Cargo.lock does not reopen a row: if it is still
  affected, the reason usually still holds, and the day bounds it.
  Recommendation: yes, required.

## Acceptance

- [ ] With a valid row, session-start says nothing of that advisory, and
      doctor prints it as `info` with its reason and day.
- [ ] Both say it again, each with why, when `until` has passed, when
      RustSec's fixed versions differ from the row's `fixed`, and when the row
      is invalid (no `why`, no `fixed`, another crate, `until` not a date or
      more than 90 days ahead).
- [ ] A second advisory of a triaged crate is said as new.
- [ ] doctor names a row that matches nothing.
- [ ] `--advisories gate`: 0 with everything triaged or nothing found; 1 with
      one untriaged, expired, changed or invalid; 2 with no database, an
      unreadable lock or an unreadable triage file; a missing `--triaged`
      file is an empty list. One line per advisory and the database line;
      nothing from the current folder's `docs/` is read.
- [ ] A copy fetched more than 7 days ago that cannot be fetched again: a
      `stale` line, the exit decided by the findings.
- [ ] session-start's hint names `docs/advisories.toml`; the session skill
      says when and how to write a row.
- [ ] Green on the three machines, released as 3.39.0.

## Tasks

- [ ] Rows read and checked; session-start and doctor silence and say again;
      the hint line and the session skill; self-test cases.
- [ ] The gate mode, its exit codes and the stale line; self-test cases.
- [ ] Through the gate on three machines, tagged; the managing session told the version.
