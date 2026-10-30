# Backlog

What the backbone should do next: bugs, gaps and ideas, one line each, from
`just backbone-note` in any project and from the scheduled runs. Open lines
only: a line built is removed by the version that built it, and that version's
CHANGELOG entry is the record. A line carries a date and an id, never a
project's name: the backbone is public and knows no project (spec 024). A
`- [?]` line waits on the maintainer.
- [ ] 2026-10-16, n-ae82d7: stack-flutter.just writes the launchd agent (`just emulator-plist`: KeepAlive false, ProcessType Interactive, ANDROID_HOME, JAVA_HOME, PATH) and does not start the emulator as a child. bootstrap itself is not run from here. blocked: needs a Mac to run launchctl bootstrap gui/UID and to watch whether a busy machine still loses the device after install.
- [ ] 2026-10-22, n-fc65ca: delegate grok's deny list names the shell wrappers sh, bash, zsh, eval, xargs and env. blocked: whether grok's --deny is stepped around by those wrappers was not measured on grok.
- [ ] 2026-10-22, n-5b9b58: delegate: deny reads of secret paths on grok (~/.aws, ~/.appstoreconnect, brain/03-stack, .env) and limit outbound network beyond the curl, ssh and gh deny. blocked: grok's Read-deny syntax, and a network limit that is not command text, are unmeasured. The strip, the process-group kill and opencode's outside-path deny are in, with the checklist.
- [ ] 2026-10-27, n-67104d: just delegate: a project whose default branch is on an old backbone has no delegate recipe; worked around with just --justfile <other project>/.ai-backbone/core.just --working-directory <project> delegate. blocked: an old project's recipes arrive only with template-update; the backbone does not write into a checkout it does not own.
- [ ] 2026-10-28, n-73d3f2: session-start FRESHNESS: nginx's upstream.toml row says 'stable line only (an even minor)' but the check calls release-1.31.8 (mainline) the next version and missed 1.30.6; let a row name a version line (e.g. track = "1.30.") so 'behind' follows it
- [ ] 2026-10-29, n-fabf4b: graphify: the pin in docs/upstream.toml is 0.9.93 while PyPI graphifyy is 0.9.97 (2026-10-27), yet session-start FRESHNESS says Behind nothing, so the pypi check misses it; and graphify-out maps are weeks old in projects. Make FRESHNESS see the pypi pin, and refresh a map at session-start or save when it is older than HEAD by many commits.
