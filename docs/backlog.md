# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-16, n-ae82d7: stack-flutter.just writes the launchd agent (`just emulator-plist`: KeepAlive false, ProcessType Interactive, ANDROID_HOME, JAVA_HOME, PATH) and does not start the emulator as a child. bootstrap itself is not run from here. blocked: needs a Mac to run launchctl bootstrap gui/UID and to watch whether a busy machine still loses the device after install.
- [ ] 2026-10-20, n-baecb7: when a project's GitHub repo is created, turn on auto-delete of merged branches (gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true)
- [ ] 2026-10-20, n-a052c5: delegate skill: an agent harness may cap a background shell call (Claude Code: 2 h); for a long job start just delegate detached (nohup) and read just delegate-status, or the run is cut while the worker still works
- [ ] 2026-10-20, n-a72029: 035 FRESHNESS: 'First job: ... Do it in this session' should say 'just delegate it' when WORKER is set (spec 034's manager rule)
- [ ] 2026-10-16, n-ae82d7: stack-flutter.just writes the launchd agent (`just emulator-plist`: KeepAlive false, ProcessType Interactive, ANDROID_HOME, JAVA_HOME, PATH) and does not start the emulator as a child. bootstrap itself is not run from here. blocked: needs a Mac to run launchctl bootstrap gui/UID and to watch whether a busy machine still loses the device after install.
- [ ] 2026-10-20, n-818193: delegate skill: write the queue rule down - related small jobs go as one task text (one report), independent jobs in one project go back to back (the manager hands the next on the report, the owner does not wait), parallelism only across projects (spec 034: one delegate job per project folder)
- [ ] 2026-10-20, n-cdb28d: spec 034 follow-up: projects that turn delegation on need Claude Code allow rules Bash(just delegate:*), Bash(just delegate-status:*), Bash(just delegate-accept:*) in a backbone-managed block of .claude/settings.json, opt-in per project (the code goes to the worker's vendor); today the auto-mode classifier blocks just delegate as data exfiltration and an agent may not write its own settings
