# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-14, n-f79b86: stack-flutter.just (to be written): a recipe that finds an Android emulator picks it by its own AVD name (adb -s <serial> emu avd name) or a fixed -port, never the first line of adb devices; several projects run emulators on one machine, and adb lists them in no set order
- [ ] 2026-10-14, n-445708: _build-wait waits for cargo and rustc only; stack-flutter.just (to be written) should give a device test run (flutter test -d <device>) a silence watchdog: a run that writes nothing for N minutes is stopped and counted as failed, because an emulator run can hang after the APK install with no output and block every run queued after it
