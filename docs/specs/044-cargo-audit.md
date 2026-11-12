# cargo-audit reads the lock

status: approved
date: 2026-11-11
closes: n-2ed2cf

`just doctor` used to read RustSec's database itself. RustSec publishes
`cargo-audit` for that. The owner chose 0.23.0 on 2026-11-11. cargo-deny was
rejected: it is not RustSec's, and its last release was July 2026.

## What changes

- `--advisories` runs `cargo-audit --json --file <lock> --db <db> --no-fetch`
  when the binary is on `PATH`, or when `AI_BACKBONE_CARGO_AUDIT` names one.
  The pin is the `cargo-audit` row in `docs/upstream.toml`. On Windows a
  real `cargo-audit.exe` is started as itself. A `.cmd` stand-in goes
  through `cmd /c`, because CreateProcess will not start one (spec 020).
- A `[[triaged]]` row that has a reason is the same fact as one
  `[[advisories.ignore]]` entry: `id` and `reason`. The scan does not pass
  those entries in. An ignore would hide the finding, and the gate still says
  when the day has passed or the fixed versions have moved (spec 030).
- `sh .ai-backbone/setup.sh`, `just tools-update` and the two suite workflows
  install that pin when they can. A machine with no `cargo` is told the
  command by `just doctor`. Without the binary, the database copy is still
  read, so a session that has not installed it yet still speaks.
- OSV's GHSA ids stay as they are (n-87f6a0).

## Tasks

- [x] `cargo-audit` is the reader, and a reasoned row renders as an ignore entry.
- [x] The pin, the install and the suite's stand-in are in.

## Acceptance

- [x] `just self-test` is green, including the cargo-audit section.
