# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-14, n-f79b86: stack-flutter.just (to be written): a recipe that finds an Android emulator picks it by its own AVD name (adb -s <serial> emu avd name) or a fixed -port, never the first line of adb devices; several projects run emulators on one machine, and adb lists them in no set order
- [ ] 2026-10-14, n-445708: _build-wait waits for cargo and rustc only; stack-flutter.just (to be written) should give a device test run (flutter test -d <device>) a silence watchdog: a run that writes nothing for N minutes is stopped and counted as failed, because an emulator run can hang after the APK install with no output and block every run queued after it
- [ ] 2026-10-15, n-86a7c9: buildtrim.py and just doctor: build caps are per project, but the disk is shared. With nine Rust workspaces on one machine, each capped at 150 GB (git config ai-backbone.build-cap), the caps add up to more than the 1 TB disk. Every folder stayed under its cap while the disk fell 60 GB an hour, so nothing was trimmed. Proposal: just doctor checks a machine-wide budget, the sum of the caps at most about half the disk, and below it buildtrim.py takes idle workspaces first, least recently built first.
- [ ] 2026-10-15, n-26ead0: audit skill, ground rules: reviewers who copy the repo to mutate code must each use a private CARGO_TARGET_DIR (cp -c -R target/release into their own scratch). A shared one mixes their builds: cargo names workspace members' artifacts by relative path and checks freshness by mtime, so a copy in another folder took a mutated copy's build as up to date and one reviewer ran another's test binary (measured in a phase audit, 2026-10-15).
