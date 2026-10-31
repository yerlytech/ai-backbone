# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. A line built
is ticked and names the commit that built it, and that version's CHANGELOG
entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-16, n-ae82d7: stack-flutter.just writes the launchd agent (`just emulator-plist`: KeepAlive false, ProcessType Interactive, ANDROID_HOME, JAVA_HOME, PATH) and does not start the emulator as a child. bootstrap itself is not run from here. blocked: needs a Mac to run launchctl bootstrap gui/UID and to watch whether a busy machine still loses the device after install.
- [ ] 2026-10-22, n-fc65ca: delegate grok's deny list names the shell wrappers sh, bash, zsh, eval, xargs and env. blocked: whether grok's --deny is stepped around by those wrappers was not measured on grok. Needs a measurement on a live worker.
- [ ] 2026-10-22, n-5b9b58: delegate: deny reads of secret paths on grok (~/.aws, ~/.appstoreconnect, brain/03-stack, .env) and limit outbound network beyond the curl, ssh and gh deny. blocked: grok's Read-deny syntax, and a network limit that is not command text, are unmeasured. The strip, the process-group kill and opencode's outside-path deny are in, with the checklist. Secret-path half claimed by spec 041 (draft); the network half stays. Needs a measurement on a live worker.
