# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-16, n-ae82d7: stack-flutter.just writes the launchd agent (`just emulator-plist`: KeepAlive false, ProcessType Interactive, ANDROID_HOME, JAVA_HOME, PATH) and does not start the emulator as a child. bootstrap itself is not run from here. blocked: needs a Mac to run launchctl bootstrap gui/UID and to watch whether a busy machine still loses the device after install.
- [ ] 2026-10-20, n-cdb28d: spec 034 follow-up: projects that turn delegation on need Claude Code allow rules Bash(just delegate:*), Bash(just delegate-status:*), Bash(just delegate-accept:*) in a backbone-managed block of .claude/settings.json, opt-in per project (the code goes to the worker's vendor); today the auto-mode classifier blocks just delegate as data exfiltration and an agent may not write its own settings. blocked: needs the maintainer's explicit yes; an agent does not write a project's allow rules.
- [ ] 2026-10-22, n-fc65ca: delegate grok's deny list names the shell wrappers sh, bash, zsh, eval, xargs and env. blocked: whether grok's --deny is stepped around by those wrappers was not measured on grok.
- [ ] 2026-10-22, n-5b9b58: delegate: deny reads of secret paths on grok (~/.aws, ~/.appstoreconnect, brain/03-stack, .env) and limit outbound network beyond the curl, ssh and gh deny. blocked: grok's Read-deny syntax, and a network limit that is not command text, are unmeasured. The strip, the process-group kill and opencode's outside-path deny are in, with the checklist.
- [ ] 2026-10-27, n-67104d: just delegate: a project whose default branch is on an old backbone has no delegate recipe; worked around with just --justfile <other project>/.ai-backbone/core.just --working-directory <project> delegate. blocked: an old project's recipes arrive only with template-update; the backbone does not write into a checkout it does not own.
