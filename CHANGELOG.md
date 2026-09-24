# Changelog

What each backbone version changed, and why. Newest first.
`just template-check` tells a project which version it has and which is available.

Versions follow [SemVer](https://semver.org): `MAJOR.MINOR.PATCH`. Patch: a fix,
nothing to do. Minor: new recipes or files, nothing breaks. Major: something
moved or a rule needs a manual step, and the entry says which. The git history
was squashed into one commit twice, at 3.0.0 and again at 3.27.2 on 2026-09-24,
when the repository went public: a newcomer reads a repository, not a diary.
The entries below are the record of every version; the tags before 3.27.2 are
gone with the history.

## 3.27.3 — 2026-09-24

**Windows, the first step** (spec 020). Text checks out with LF on every
machine (`* text=auto eol=lf` in `.gitattributes`): Git for Windows wrote CRLF,
and a size check on the gate failed by exactly one byte a line. Every Python a
recipe runs is in UTF-8 mode (`PYTHONUTF8=1`): on Windows it wrote in cp1252 and
stopped at the first Turkish letter, so the session line said python3 was
missing. When `new-project` fails in the suite, its output is shown, since
everything after it builds on that project.

## 3.27.2 — 2026-09-24

**A clean start for the public repository** (spec 018). The README is written
for somebody who lands on the page: what this is, who it is for, what it does,
what it is built on and why, what it costs in tokens, how to start. The
maintainer's private vault left this repository's machine and its second copy,
and the history is one commit. Nothing in the recipes changed.

## 3.27.1 — 2026-09-24

**The repository is public.** The gate's first run never started: GitHub
refused the account's private-repository minutes ("recent account payments
have failed or your spending limit needs to be increased", as on 2026-09-19).
On a public repository the standard runners are free, and the maintainer
chose that over a card. Before the switch, the whole history was scanned
(gitleaks: no leaks; no personal e-mail, no machine path in any commit) and
two things that named the maintainer's projects were changed: a note's
commit is `docs: backlog note` now, without the project's name (the note's
own line keeps it, so a project still finds its notes), and the suite reads
the private names it must not find in a lifted layer from
`brain/private-names.txt` on the maintainer's machine instead of listing them
here. The old names stay in the history; the audit the maintainer planned
for the public repository is the next spec.

## 3.27.0 — 2026-09-24

The backbone is developed away from the maintainer's machine, and what reaches
`main` has passed on a clean Linux and a clean Mac.

**The cloud branch and the three-machine gate** (spec 017). Every unattended
run and every cloud session pushes to the branch `cloud`, never to `main`.
`checks.yml` runs on every push there: a first job asks `gate.sh look` whether
anything but the routine's own files (its log, the backlog, the radar's
markers, a spec) differs from `main`, and only then runs the suite on
`ubuntu-latest`, `macos-latest` and `windows-latest` — Linux and macOS decide,
Windows only reports until a spec of its own makes it green. `promote.yml`
runs when that finishes, from `main`'s own copy of itself and of
`.ai-backbone/gate.sh`, so a push can change what is tested and never how it
is judged: `gate.sh carry` moves `main` forward to the tested commit (never a
merge on a runner), tags the version on line 1 of `core.just` in the same
atomic push, and when it cannot carry — red, `main` moved, a changed workflow
or `gate.sh`, a suite that was due and did not run — writes one `gate:` line
at the end of `docs/routine-log.md` on `cloud`, which the next run reads
first. The routine's brief starts each run from `cloud` with `main` merged in,
treats a red gate as its first item (fix it, or revert the run's own commits
and reopen the line as blocked), never tags and never pushes `main`; its
stored prompt is unchanged. The maintainer decided the same day that Actions
is on for this repository, and that if the gate's minutes run past the free
2,000 a month the repository becomes public, as its own spec after a clean-up
and an audit.

**The recipes know the branch.** `_backbone-level` levels a clone on `cloud` by
a merge and never pushes from it, calls a run's no-branch checkout up to date
when it holds both branches, names a sibling left on `cloud` from a project,
and says in every session, projects included, when `cloud` has been ahead of
`main` for two days — the one way a gate that stopped reaches a person's
agent. `template-update` copies nothing from a sibling that is not on `main`.
`backbone-note` from a run's checkout saves the note and lets it ride the
run's push (the `HEAD:main` it once pushed would now carry untested work).
`publish`, and `save` with publish-on-save, refuse to push `main` from inside
the backbone and say what to type instead. `radar-save` counts as strays only
what is on neither branch, or a spec that reached `main` would refuse every
Sunday save. `_backbone-tag` stays as the backstop and agrees with the gate by
construction. `docs/routine-log.md` merges as union. Two dozen new checks in
the suite, the gate's against a bare repository with a stand-in `gh`.

Measured on git 2.55.0 and /bin/bash 3.2.57 on the maintainer's Mac, and on
GitHub's runner images as read on 2026-09-24: ubuntu-latest = Ubuntu 24.04,
macos-latest = macOS 26 arm64, windows-latest = Windows Server 2025, with
`actions/checkout@v5`. The minutes of the first runs are in the spec.

## 3.26.1 — 2026-09-24

**A recipe never edits the person's shell** (backbone-dev skill). A project
reported a dev-dependency CLI that appended a `## [Completion]` block to
`~/.zshrc` the first time a recipe ran it — a Dart tool built on
`cli_completion`, which auto-installs completion unless its opt-out variable
is set. The rule now sits beside the `$1` rule an agent already reads before
it writes a recipe: find the tool's opt-out in its own documentation and
`export` it at the top of the file, because a recipe that changes what the
person's shell loads is a manual step they never agreed to.

## 3.26.0 — 2026-09-23

One new recipe, and the person types none of it: `just release`, which the
agent runs.

**A project has a version of its own** (spec 016). Until now the only number in
a project was the backbone's own (3.25.2 in every one of them), and the session
skill's promise of semver and a CHANGELOG.md had nothing behind it: four
projects, no tag and no changelog between them. Now a project's version follows
semver.org, is written in its own CHANGELOG.md after keepachangelog.com, and is
a tag `vX.Y.Z` that goes to GitHub with the backup, the way the backbone's do.
It is cut **at a meaningful point** — the maintainer's choice — when a spec is
done, and when a fix goes out on its own between specs. `just release` reads the
step from the kinds of the commits since the last version: a feat makes the
next minor, anything else the next patch, a breaking change the next major from
1.0.0 on and the next minor below it. The first version is 0.1.0, and 1.0.0 is
cut only on the maintainer's word (`just release major`). The entry is what an
`## [Unreleased]` section already says, or a draft from the commits (added,
fixed, changed; a long subject cut at its first " — "). The release commit
passes the same checks as a save, and a refused one leaves nothing behind. A
save that reaches GitHub, and `just publish`, carry the tags along. `doctor`
says the project's version and how many saves have come since.

**For a project that already exists:** in a Rust project, copy the recipe
`_set-version` from `$(just _backbone)/.ai-backbone/examples/stack-rust.just`
into `stack.just`, so that `just release` writes the version into Cargo.toml as
well. Nothing else is needed; the first `just release` starts the line.

## 3.25.2 — 2026-09-23

Nothing a person types changes.

**A measurement said what it was measured against.** 3.25.0's entry, and the
Rust layer's advice in doctor, said a workspace's full test build went from 9.8
GB "with full debug info" to 8.6 GB with `debug = "line-tables-only"`. The 9.8
GB was not full debug info: the machine it was measured on sets `debug = 1` for
every project in `~/.cargo/config.toml`, and that setting was not seen until the
advice stayed quiet in another project and the reason was read. So the tenth is
the step from `debug = 1` to line tables only; from cargo's default, full debug
info, the saving is larger, and it was not measured. The advice now says so,
and 3.25.0's entry above is left as it was published, with this one beside it.

## 3.25.1 — 2026-09-23

Nothing a person types changes.

**doctor says when git does not ignore the build folder.** Until today every
Rust build on the maintainer's machine went to one folder outside the projects,
so whether a project's .gitignore covered its build output never came up. The
day that setting was removed (3.25.0's advice), builds landed in the projects
— and one whose .gitignore said only `/target` had its server's
`src/server/target/` unignored: the next save would have staged gigabytes. When
the language layer's build folder is inside the project and git does not ignore
it, doctor now says so and names the line to add. It asks git with a trailing
slash, because git cannot match a folder pattern against a folder that has not
been built yet.

## 3.25.0 — 2026-09-23

Nothing a person already types changes, with one exception: `just ci-init` with
no language named, in a project that has two (Flutter apps with a Rust server
beside them), asks which instead of picking the first one it found.

**A machine that builds several projects at once** (spec 015). Two IDE windows
on two Rust projects shared one build folder through a `CARGO_TARGET_DIR` set in
the shell, so each waited on the other's build lock and said nothing; the
folder had grown to 335 GB, 322 GB of it debug output, with builds from June
nobody had cleared; and two heavy jobs at once had already ended in a Force Quit
dialog. The core now asks the language layer three things in a private
`_build-info` recipe — where its build output lives, what its compiler is
called, and which recipe clears it — and uses the answers:

- `_build-wait`: before a heavy recipe, a build already running (this person's
  own, not one stopped with Ctrl-Z) is waited for, with one line when the wait
  starts and one when it ends, up to `BUILD_WAIT_MINUTES` (20); at the limit the
  build goes on with half the cores. Where `ps` cannot list processes it says
  nothing and does not wait. `BUILD_WAIT_MINUTES=0` switches it off. `just
  save` waits where the person can see it, before the checks.
- `doctor` says when the build output is over `BUILD_OUTPUT_WARN_GB` (50), or
  too big to measure in `BUILD_MEASURE_SECONDS` (60), and when the folder lies
  outside the project: what that costs, and the line that ends it. The
  backbone never moves a build folder: one chosen inside `just` alone would
  split the IDE's own build from the recipes', and every crate would be built
  twice.
- The Rust layer names its folder through `cargo metadata` (so a `[build]
  target-dir` in any .cargo/config.toml counts), waits in check, test,
  test-fast, lint and build, gains `clean-build` (says the size, asks, clears
  exactly the folder it measured, refuses one outside the project), and
  `doctor` suggests `debug = "line-tables-only"` for dev builds when nothing
  sets a level. Measured on one workspace's full test build: 9.8 GB with full
  debug info, 8.6 GB without, a tenth. What fills a disk is builds nobody
  clears, and that is what the size line is for.

**A Flutter language layer and CI starter**, lifted from the first Flutter
project on this backbone: `examples/stack-flutter.just` (one app, one app in
src/<name>, a pub workspace, or the root; members read from `workspace:` in
every spelling pub accepts; pure packages named in `pure` always run `dart
test` and stop lint and test the day they take Flutter in; build folders git
would save stop lint before a save commits them; the JDK lesson; a not-yet list
with each item's event) and `examples/ci-flutter.yml` (Ubuntu, pinned by
commit, ten minutes). `just ci-init flutter` exits 0 and points the workflow and
the update bot at the pubspec.yaml that pins the SDK.

**Four ideas from the projects.** `just stale` reports backticked paths the
docs name that git once held and no longer does, and old names in
`docs/renames.toml`, as file:line; every layer's `lint` runs it and never fails
on it. `just adr <name> --amends NNNN` writes the new decision and points the
old one's Status line at it. `just ref-add <folder>` lists an old repo of your
own that has no address anywhere else; `path` keeps meaning where a reference
lives. The seed `.pre-commit-config.yaml` carries a commented pre-push hook
that runs the tests, for a project whose checks do not run on GitHub, and
`hooks-install` installs that stage whenever the config has one.

**For a project that already exists.** `stack.just` is the project's own, and
no update reaches it. After `just template-update`, the agent makes these edits
by hand, reading the new examples in the backbone
(`$(just _backbone)/.ai-backbone/examples/`):

- *Rust:* in each recipe that compiles (check, test, test-fast, the clippy line
  of lint, build, and any of the project's own that runs cargo build, test or
  clippy), put `env $(just _build-wait)` directly before `cargo`. Copy the
  recipes `_build-info`, `clean-build` and `_stack-advice` from
  `stack-rust.just`; they read `server_dir`, so a stack.just without that
  variable adds `server_dir := "."` or names its workspace folder there. Add
  `-@just stale` as the last line of `lint`.
- *Swift:* add `just stale || true` as the last line of `lint`.
- *Flutter with its own stack.just:* compare it with `stack-flutter.just` and
  take what is missing; nothing is required.
- *Optional, where the checks do not run on GitHub:* the pre-push block from the
  seed `.pre-commit-config.yaml`, uncommented, then `just hooks-install`.
- *Optional:* the "A folder with no address" section of
  `.ai-backbone/templates/references-README.md` in `.references/README.md`.

## 3.24.1 — 2026-09-23

Nothing a person types changes.

**An adopted project is no longer called ai-backbone.** `AGENTS.md` is a seed
file, and its section 0 says `| project | ai-backbone |` because that is the
backbone talking about itself. `just new-project` rewrites that row with the
name it was given; `just adopt` never did, so every repo brought onto the
backbone carried rules that named the wrong project, and an agent had to notice
and edit the row by hand (measured while adopting a repo on 2026-09-22).
`adopt` now writes the folder's own name there — the name `_vault-dest` already
falls back to — and says so in one line, adding that section 0 still asks for
`brain_lang` and `chat_lang`. Those two are the maintainer's answer, not a
folder's, so they stay as they are. A project that kept its own `AGENTS.md` is
untouched, as before. A project adopted before this version fixes the row by
hand, once; `_vault-dest` keeps its fallback for exactly those.

## 3.24.0 — 2026-09-22

Nothing a person types changes. **For a project that already exists:** after
the update that brings this in, run `just hooks-install` once; it puts the
subagent-cap hook into `.claude/settings.json`, merged beside what is there.
(`just template-update` runs the recipe it found, not the one it just copied,
so this first update cannot do it; every later one does.)

**What the week can take, said first, and a cap that holds.** A multi-agent
audit spent about a fifth of a week's limit in one day and crashed the machine
(12 lenses, 74 findings, three skeptics each: 235 agents, the skill's own
arithmetic), and nothing anywhere bounded fan-out. An agent cannot ask Claude
what is left, `/usage` is for a person; but Claude Code keeps the last answer it
got in `~/.claude.json` (a percentage for the seven-day and the five-hour
window, when each resets, when it was read), and every transcript under
`~/.claude/projects/` carries each message's tokens and model. So
`.ai-backbone/budget.py` reads the meter and sums the transcripts (once per
message id; a subagent's calls live only in its own file; about a gigabyte in a
second the first time and 0.03 s after), and the first line of every
`just session-start` says about what percent of the week is used and how old
that reading is, the five-hour percent, the days to the reset counted the way
the person works (`ai-backbone.weekend`, once per machine), the subagents that
ran today, and how many a session may start without asking. Never a decimal,
never an absolute number: Anthropic publishes none, and the meter includes what
this machine cannot see (one week's 100% was 5.0 billion local tokens, the next
week's 46% was 1.5 billion). Without Python or a meter it is one quiet line.

The cap is not a sentence: `.ai-backbone/agent-cap.sh` is a PreToolUse hook on
the Agent and Workflow tools that counts a session's subagents in a folder
keyed by its id and refuses past the cap (8 by default, `ai-backbone.agent-cap`
for the machine) with a reason the agent reads; measured, the model then asked
the person instead of retrying. A workflow starts its agents past the hook, so
its launch is gated by the same yes. The yes is `just _agent-cap <cap> <folder>`
for that session only; about 20 ms a call, bash 3.2 and BSD tools, no Python.
Several agents started in one breath are counted one at a time, under a lock:
without it, twelve at once all read "none started" and all passed (found in
review). The day's number the line says is written where the hook reads it,
so what the person reads is what holds, never above their own setting. The
audit skill stops multiplying agents by findings: each reviewer verifies its
own findings (measured on 2026-09-21: the same thirteen, at half the cost), and
the count is said and approved before the first agent starts. The session skill
carries the rule for every tool that reads it.

Two files reach a new project, so its tracked files rise from 40 to 42: the
maintainer's decision of 2026-09-22, in an attended session, for this feature.
Python was weighed and kept: it arrives through `uv`, as `just` and `prek` do,
and the code map is Python; the hook and the session line stay plain bash.
Spec 014.

## 3.23.3 — 2026-09-22

Nothing a person types changes. For a project there is nothing to do; the next
session in it simply starts with its eyes open.

**Agents were starting every session half blind, and nothing said so.** Claude
Code hands a SessionStart hook's output to the model whole only up to 10,000
characters; past that it keeps the text in a file and shows the first 2,000
(measured on 2.1.273). `just session-start` printed 12,891 here and 23,497 in
one project, the journal alone 17,000, and it printed the journal first: so
for weeks every agent began with the head of a diary and never saw the open
specs, the backlog, the GitHub line or what the tools had released — the very
things it is there to say. Now what is short and acted on comes first (the
working tree, the open specs, the GitHub and backbone lines, the waiting
decisions, the backlog's newest ten lines cut to 150 characters), the commits
and the journal come last and bounded (the newest entry's first 2,000
characters, and where the rest is), and whatever the whole grows to, it is cut
at 9,500 and says so. Measured after: 4,652 characters in the backbone. Three
checks: a huge journal, a hundred open specs, the order.

## 3.23.2 — 2026-09-22

**For a project that already exists:** `.gitignore` is the project's own and no
update carries a line into it. Add `__pycache__/` and `*.pyc` to it; your agent
does this the next time it opens a session there.

`.gitignore` did not ignore `__pycache__/`. Every project carries `upstream.py`
and `radar.py`, so every project grows one the moment `just upstream` runs, and
a save takes every file git does not ignore: the scheduled run of 2026-09-22
staged `.ai-backbone/__pycache__/upstream.cpython-311.pyc` and kept it out by
hand. A tracked `.pyc` is worse than clutter — it holds the source's mtime, so
a fresh checkout recompiles it, `git status` is never empty again, and step 0
of the routine's brief stops every later run before it starts. The scheduled
agent may not edit `.gitignore`, which is why it left the line open for an
attended session. One check holds it.

## 3.23.1 — 2026-09-22

**An audit's reviewers never build.** "Reviewers may run commands but must
never edit a file" reads a build as a read, and a build is not one: a
reviewer's trial Gradle build installed Android SDK Platform 34, 126 MB, into
the machine's own SDK without asking, which §7 forbids. Every toolchain that
fetches what it is missing does this, Flutter, Xcode and `cargo` with it. The
`audit` skill now says so in its rules, and step 2 has the ground rules name
the commands the reviewers may run, a build not among them. Whether the app
builds stays the rehearsal's question, step 7, where a person is watching.

## 3.23.0 — 2026-09-21

Nothing a person types changes. **For a project that already exists**, what no
update carries is named below where it applies (the seed `.gitignore` and
`.editorconfig` lines, two sentences of `AGENTS.md`); `just template-update`
now ends by listing the seed rules a project's `AGENTS.md` lacks.

**The backlog, cleared.** Thirty-five lines were open and half of them waited
for a person the scheduled agent never has; the maintainer sat in, seven agents
built the packages side by side in plain clones, and every line ended done,
closed with its reason, or open with `blocked:` and the one event that would
unblock it (spec 013). Put together, the change was read from three lenses
before it was saved, each finding reproduced by measurement: a clone or a
Finder duplicate with the same project name wrote an empty journal over the
real project's second copy (it is refused now, and told which folder the copy
belongs to); one unreadable file in `brain/` stopped the secrets from being
copied; a link pointing out of `brain/` was copied as a link without a word;
one radar filter that is not a pattern killed the whole Sunday run; a version
glued to its word (`n7.1`, `go1.24.0`) lost its major and read as current;
dated tags of 2023 read as newer than `0.15.1` on the path without the API;
`radar-save` called somebody else's push the run's own doing; `session-start`
took a README that shows a spec header for an open spec. 311 checks.

**`brain/` has a second copy.** It is ignored by git on purpose, so in every project it existed on one disk only. `just session-end` now mirrors it, after the journal step, into `<place>/<project>/brain/` with `rsync -a` and without `--delete`: one folder per project, named after the project row of AGENTS.md section 0, never a growing pile, and a file lost here by accident is still there. A mirror and not a zip, because of what was measured on the maintainer's machine: eight vaults from under 1 MB to about 90 MB, most of it large files that never change, and a journal that changes every session, so a zip would have been rewritten and uploaded whole each time. The flags were measured on openrsync (protocol 29, macOS 27) and on rsync 3.4.1. The secret files git ignores are copied beside it under `secrets/`, each at its own path: `.env`, `.env.*` (never `.env.example`), `.envrc` and the key and certificate endings, outside `brain/`, `.references/` and build and dependency folders; an `.env` is copied and never moved, because its tool reads it where it is. The place is asked for once per machine and lives in git's own settings for the person (`git config --global ai-backbone.vault-copy`): an agent sets it after asking, no recipe does, and the person types nothing. Not set, not there, not writable, no rsync: one plain line and the session still ends. A place inside a folder git saves is refused, because the secrets would go into that project's next save. A `.git` inside `brain/` is left out and said (no vault here holds one). The copy is written on this machine; whether a drive has uploaded it is the drive's business, so the word is "copied" and nothing is claimed about a cloud. `just doctor` says in its Repo half whether there is a second copy and how old it is, read off `about-this-copy.txt`, which the mirror writes into the copy and which says how to put things back; it warns, and never fails, when a key or certificate sits outside `brain/`, where AGENTS.md section 7 says they live. `just brain-init` says when a copy under the project's name is waiting. The copy is taken when `session-end` runs, which is before the entry is written, so it asks to be run once more afterwards.

**`just doctor` asks the language layer what it needs, and ends three ways.** A Mac with no Flutter on it read "Everything needed is installed", and every save that touched code then failed in the lint hook with "dart: command not found". `stack.just` names its tools in a private `_stack-doctor` recipe, one line per tool (the command, then where to get it), the way `_root-allow` names root files; doctor lists them under "Language" and counts them apart from its own five, so a project that lacks only its SDK is never sent to `setup.sh`, which has never installed a language. The endings and the new rows a person acts on speak `chat_lang` (a private `_doctor-msg`, shaped like `_msg`); the English of the two old endings is unchanged. "rust | swift" was written out by hand; doctor's hint and `just stack` now read the `stack-*.just` file names, and `just stack` alone lists the ready layers.

**`just ci-init` writes the update bot with or without a workflow.** It copied `dependabot-<lang>.yml` only after it had found `ci-<lang>.yml`, so `dependabot-swift.yml` could never be reached and a Flutter project got no bot at all. The bot comes first now, a `pubspec.yaml` means flutter, and `dependabot-flutter.yml` carries `pub` and `github-actions` (GitHub's options reference lists `pub` and says of `enable-beta-ecosystems` "Not currently in use", read 2026-09-19). In a private repository it says once what a run costs: the account's free minutes, of which a project here used 2,000 in two days. Silent only where GitHub itself answers that the repository is public.

Twenty-five new checks, each seen failing on the old recipes; the two that assert an absence (nothing deleted in the copy, nothing said in a public repository) were seen failing on a planted fault instead.

Nothing a person types changes. One thing a person reads does: a save that a file over the size limit stops. For a project there is nothing to do.

**A save stopped by a big file says which file, and whose job it is.** "Not saved. Fix what the check above says" gave somebody who is no programmer no way out of the 5,000 KB `check-added-large-files` hook, and because a save stages everything, one big asset stopped every save after it. The refusal now names each file with its size and the limit, read from the hook's own line (prek 0.5.3 measured, pre-commit's read in its source), says that nothing is lost and that this is the agent's job, and tells the agent the ways out in order: ignore what does not belong, move a private file into `brain/`, shrink what belongs, and only then raise `--maxkb` in the project's own `.pre-commit-config.yaml` with the reason on that line; never skip the checks. The limit itself was not raised: nobody has measured a real asset. The named files are also taken back out of what is staged, one path at a time. git goes on tracking a staged file after it is ignored, so the agent that ignored the file was refused again for it (measured), and a reset of the whole index would also end a merge in progress (measured on git 2.55.0). Turkish and English. Five checks.

**`just save`, `just ci` and `just template-update` work in a linked git worktree.** `.git` is a file there and the recipes asked `[ -d .git ]`, so an agent working in one read "No git repo yet. Run: git init". A hidden helper, `_is-repo`, asks git, and asks for the top of a work tree (`git rev-parse --show-cdup` prints nothing there) rather than for `--git-dir`: that succeeds in a plain folder inside somebody else's repository too, and from there the `git add -A` of a save stages the whole of it (measured). Four checks, one of them a guard that is red against the shorter fix. [Integrator: add doctor, session-start and adopt here once the needs_elsewhere edits are in.]

**`just ci` says when the checks are switched off on GitHub.** In a repository whose Actions are turned off it said "The checks have never run here. They start on the next push", about checks that never will; where old runs were still listed it called a commit that was on GitHub unsent. Measured on 2026-09-19 with gh 2.101.0 against the maintainer's repositories: the run list answers `[]` on one and two old runs on another, and `actions/permissions` answers `enabled: false` on both. When a commit has no run, ci asks that one question first, says that the checks are switched off and prints the page where they are switched back on. Somebody else's repository answers 403 and reads as before; a green or red build costs no extra call. `just publish` ended with "The checks start now" in the same repositories; it asks the same question and says nothing there. Five checks, with a stand-in for gh first on the PATH.

**`just template-update` reads the version from the last save, and lists the rules a project's `AGENTS.md` lacks.** It read the old version from the working copy, so an update that was copied and never saved hid its span: four projects had 3.7.0 committed and 3.17.1 on disk, and what ten versions had to say about `AGENTS.md` was never shown. The version now comes from HEAD, and from the file only where git has no answer. And because `AGENTS.md` is a seed no update carries, template-update ends, up to date or not, by listing the rules of the backbone's Session protocol, Safety and Do not sections that the project's file has no line for. Two lines are the same rule when their first six words are, read without case and punctuation; a rule reworded or left out on purpose is listed too, and the words say so. It changes nothing and adds no recipe. Dry-run on real projects, read-only: xlarge lacks four rules. Five checks.

**The suite runs from a folder of any name.** The check "ref-add adds the guide and the list" looked for the literal word ai-backbone, and ref-add names the clone after the folder it came from, so a second clone under another name went red, and green again by accident wherever the word stood anywhere in the path. It looks for this checkout's own name now. The whole suite is green from a clone called Baska-Isim.

**A session starts with what is open, and with what is missing.** `just session-start` prints one line for every draft or approved spec, in every project. The line gives the name, the status, how many of the boxes under "## Tasks" are ticked, and the first line of the next open task. Only `[x]` counts as ticked. Until now a session began with the journal, the commits and the backlog, and nothing said that a spec was half built (borrowed from the Next line of OpenSpec's status command). A draft says that no code comes before approval. A spec whose tasks are all ticked says to walk the acceptance list and close it. A project with no GitHub address has one copy of its code, on one disk. `just publish` said so only to somebody who typed it, and `just projects` only to somebody who opened the backbone. session-start now says it in one line at every session for as long as it is true, offline too, and tells the agent to ask the person first, because publishing creates a repository under their account.

**A weekly check that learned nothing no longer uses up the week.** session-start stamped `.git/ai-backbone.last-upstream` whatever `just upstream` had read, so a dead network or a proxy that refuses every source cost seven days of silence. The stamp is now written only when the run went through and did not end in "Nothing could be read". A run that could not run at all is asked again at the next session too, and still says so.

**`just tools-update` moves the pin of a tool it has upgraded.** A tool that lives as a binary and in no file has its pin in `docs/upstream.toml` and nowhere else. graphify was upgraded to 0.9.64 while its row still said 0.9.62, and `just upstream` went on reporting as new what was already installed. tools-update now ends by moving the pins of just, prek, graphify, gh and uv to the installed version, in the same run, and says so in one line. It moves only a row that names no `pinned_in`: where a file holds the version, that file is the truth and MOVED says the drift. It moves a pin only upwards, so a machine whose upgrade did not go through does not pull the pin back. It rewrites only that one line of the file.

**`just hooks-install` fetches the Go that prek could not.** Every scheduled run in a sandbox began with about ninety red checks. prek builds the secret scanner with Go and downloads the Go it wants from go.dev, which is closed there, so every commit failed until the agent applied a quirk from the brief by hand. hooks-install now prepares what the hooks run (`prek prepare-hooks`), which takes a hundredth of a second where it is already there. When that fails, prek's own log names the Go it went to go.dev for, and a go is on the PATH, that go fetches the toolchain through the module proxy (`GOTOOLCHAIN`). It is put first on the PATH for one more try, and one line says so. When that does not work either, prek's own words are shown and the hooks still count as installed, so the first save tries again. Nothing is prepared in offline mode. Measured on prek 0.5.3 with go 1.23.0 on the PATH, go.dev closed by a proxy and an empty prek cache. The scanner was built, and a later save went through with go.dev still closed. The quirk leaves the brief.

Thirteen new checks. Nine were seen failing on the old recipes. The four that guard a silence were seen failing with their guard taken out.

**The code map is the project's code, and Dart counts.** A Flutter game's first map had 76 nodes: 52 came from `.ai-backbone/` (upstream.py, setup.sh, routine.sh) and 6 from the game. Its second, made with `graphify update .`, had 217, of which 141 were `.md` files, and the changelog was its most connected node. `templates/graphifyignore` now names `.ai-backbone/` and `*.md`, and `just update-map` adds the lines an older `.graphifyignore` lacks, at the end, the way the lint hook reaches an older hook config: nothing is taken out or moved, and a line somebody commented out counts as answered, which is how a project says no to one. Every run is now `graphify extract . --code-only`. Measured on graphify 0.9.64 in a scratch project holding the game's Dart files: it is incremental (a second run re-read only the two JSON settings files and wrote the same graph byte for byte); an edit, a renamed class, a new file and a deleted one each came out right with no `--force`; a map built the old way went from 217 nodes to 12 on the first run with the new lines; and a project folder that had really moved needed nothing, because the root marker is an absolute path but the paths in the graph are relative, and the marker is rewritten. The two things seen on 0.9.58 (nodes of deleted files stay until the update is forced, a moved folder needs a fresh extract) do not hold on 0.9.64, so `update-map` forces nothing. `_has-code` counts `*.dart` and nothing else new: graphify's own list has 102 extensions with `.json` and `.sh` among them, which every project has on the day it is made. Its comment and `update-map`'s sentence were wrong about SQL: `.sql` is on graphify's list, but its parser is an extra the default install does not bring, and a tree of SQL alone ends in "graph is empty". For a project there is nothing to do: the next `just update-map` adds the two lines and the map, with its saved report, gets smaller.

**`just uses <word>`.** AGENTS.md section 4 sends an agent to `graphify affected` before a change, and graphify 0.9.64 draws next to no calls in Dart: it reads Dart with regular expressions and the only calls that reader knows are a BLoC's events and states (12 edges among the game's Dart nodes, none a call, where the backbone's own Python has 33). `just uses SwapSmashGame` prints every line that names the word, whole words only and exactly as typed, in saved and in brand-new files, leaving out `.ai-backbone/`, `brain/`, `graphify-out/`, `.references/` and `.archive/`, and ends with a count. It is `git grep`: no new tool. A new project shows 37 recipes and 37 is the ceiling, so `backbone-news` gave up its place: only `session-start` ran it, once a week, and it is `_backbone-news` now (it still runs by hand under that name). AGENTS.md section 4 names the new recipe; AGENTS.md is a seed, so in an existing project the agent adds that line by hand.

**The seed files against a Flutter app.** `.editorconfig` gives `*.dart` 2 spaces, which is what `dart format` writes (measured on Dart 3.13.4; the editor was told 4); it is a backbone file, so `template-update` brings it. The seed `.gitignore` ignores `*.keystore` and `*.mobileprovision` beside `*.pem *.key *.p8 *.p12 *.pfx *.jks`: key and certificate files are secrets and live in `brain/`, and `save` stages every file git does not ignore, so an Android keystore next to the app was one save away from GitHub. Its stack examples gain a Flutter line: `.kotlin/` (a Kotlin 2 build writes it and what `flutter create` 3.47.5 writes does not cover it), keep the `.gitignore` files `flutter create` puts inside the app, never `*.xcodeproj`. The seed hook config no longer runs check-json over `.vscode/*.json`: VS Code writes comments into those files (its own extensions.json starts with two), and a save was refused for a file the editor had made (reproduced on prek 0.5.3 with the template a VS Code build carries). Seeds are copied once, so in an existing project an agent adds by hand: `*.keystore` and `*.mobileprovision` under Secrets in `.gitignore` (and `.kotlin/` in a Flutter project), and in `.pre-commit-config.yaml` check-json's exclude becomes `'(^|/)(tsconfig[^/]*\.json|\.vscode/[^/]+\.json)$'`.

**The second-day lens asks about any toolchain.** `templates/audit-lenses.md` asked about a Docker image and rust-version, and a Flutter app's mismatch lives elsewhere. The lens now asks whether whatever builds the app away from the development machine (CI, the image, the store build) installs at least what the app and every dependency declare, with two examples: Rust 1.94 against a Dockerfile's 1.90, and in a Flutter app `environment:` in `pubspec.yaml` against the Flutter CI installs, the iOS deployment target against a plugin, and Android's minSdk, Gradle, its plugin, Kotlin and the JDK. A project that already has `docs/audit-lenses.md` keeps its copy; its agent replaces that paragraph at the next audit.

Thirteen new checks, each seen failing first: twelve against the untouched code, the thirteenth after it was found passing there for the wrong reason and rewritten, and the ignore-file, extract and `uses` checks again one at a time under eight planted faults (update put back, the refusal rule dropped, the newline guard dropped, the folder list dropped, whole-word dropped, new files dropped, Dart dropped, the old template).

Suggested lead: Nothing a person types changes. For a project there is nothing to do, with one exception its agent handles: a Flutter project changes the SDK row of `docs/upstream.toml` to `source = "flutter:stable"`. Until it does, the row says UNKNOWN and why, where it used to say "current".

**`just upstream` no longer calls a pin current that its source does not list.** flutter/flutter's release pages on GitHub stop at 3.19.0-0.1.pre, so Swap Smash's pin of 3.44.0 read "current, nothing newer" while 3.47.2 to 3.47.5 existed: nothing listed was newer, so nothing was. "Current" is now said only of a pin the source itself lists. A list that holds neither the pin nor anything newer makes the row UNKNOWN, and the reason stands under the table: the newest version the source does list, or, when the pin is written another way than the source writes its versions, what they look like. The three sentences of the report that said "nothing came back" and "could not read" are reworded, because such a source was read and did send something back. Measured against the real sources on 2026-09-19: `github:flutter/flutter` with a pin of 3.44.0 says unknown, "the newest it lists is 3.19.0-0.1.pre"; none of the twenty rows in the three real watch lists on the maintainer's machine changes, that one excepted.

**Flutter's own release list is a source: `flutter:stable`, `flutter:beta`.** It reads `storage.googleapis.com/flutter_infra_release/releases/releases_<os>.json`, the file the archive page on flutter.dev is drawn from. A Mac's file holds an x64 and an arm64 row per version, and a version built again has a pair per build (3.13.3: three, over five days), so a version is one row, dated by the first day it existed. On the beta channel a beta is the release, so the row needs no `prereleases = true`; a channel that is not there is said together with the ones that are. The same pin of 3.44.0 now reads "15 newer", newest 3.47.5. `just upstream <name>` also lists the SDK's own checkout when the command on the PATH runs from a clone of the watched repository, with its tag against the pin and its CHANGELOG.md: on this Mac `/opt/homebrew/share/flutter`, holding 3.47.5 under a pin of 3.44.0. The clone's address is what decides, because walking up from any Homebrew command ends in `/opt/homebrew`, which is a git repository too. The checks run offline against a fixture cut from the real list; only the network is replaced, the whole script runs.

**Three shapes of tag were read wrongly, and one change reads them all.** Measured on google/A2UI, the MCP specification and openai/codex: `python/x/v1.0` read as newer than a pin of `v0.9` of another package; `2026-07-28-RC` read as newer than `2026-07-28`; `rust-v0.155.1` yielded no numbers at all, so the row compared words. A tag is now the label before its version plus the version, and only a tag under the pin's own label is its next version. A pin is therefore written the way the source tags it when the source tags more than one thing (`rust-v0.155.0`); written bare, the row used to be a silent "current" and now says UNKNOWN and how to write it. On the way: `1.0` equals `1.0.0`, `rc10` sorts after `rc9` without the dot, the git fallback of 3.21.2 keeps every tag instead of the fifty highest (sorted together, codex's newest `rust-v` release stood at place 49 of 1,358 and the pin fell off the end) and knows `-rc1` for a release candidate, where only `-rc.1` was known.

**MOVED is said for a pin that is only the start of a longer one.** `pin_is_real` asked whether the pin's text was anywhere in the file, so a lockfile that had moved on to 1.38.20 still "held" 1.38.2. The pin now has to stand there as a version of its own; `v3.2.4-alpine` still holds 3.2.4, and a pin written with its label is held by a file that says `0.155.0`. The watch-list template names the lockfile per registry (`pubspec.lock` for pub) and why the file beside it will not do: it holds a range, and goes on saying so after the lockfile has moved.

Seventeen checks, each seen failing first: fourteen on the untouched file, the Homebrew guard against a first form of the finder that did not match the address, and the many-tags check twice, once with the cap of fifty put back and once with the old prerelease pattern.

**For a project that already exists: two lines your agent adds to `AGENTS.md` by hand.** `AGENTS.md` is the project's own and no update carries it. In section 4, "Reading the codebase", replace the bullet about `graphify affected` with: "- `graphify affected "Symbol"` before you change it. Where the map draws no calls (Dart) it finds nobody: `just uses <word>` lists every line naming it." At the end of section 7, "Safety", add: "- Never send the maintainer's name or e-mail to a third-party service, a `User-Agent` header included. Stay anonymous, or ask first." The first because graphify 0.9.64 draws no call edges in Dart and `affected` found none of two real callers in a Flutter game; the second because a research agent put the owner's e-mail into the User-Agent of three crates.io calls, since that service asks for a contact. A new project's `AGENTS.md` measures 6,890 bytes of its 7,000.

**The public standards a project follows, said once.** Only the backbone had been told, about itself. The session skill, which an update carries to every project, now names three with their addresses: https://semver.org for version numbers (a project's first version is 0.1.0, and 1.0.0 is the first one other people rely on), https://keepachangelog.com for a `CHANGELOG.md` in the project's root from its first version on, and https://www.conventionalcommits.org for commit messages, with the eleven kinds `just save` and the commit hook accept. A check reads those kinds out of the save recipe, so a kind added there and not in the skill is red. `just doctor` no longer calls a project's root `CHANGELOG.md` a stray. [this last sentence only if the _root-strays change is taken]

**A picture of how it works.** `docs/how-it-works.md`, for a person who does not read code: two flowcharts GitHub draws by itself from text in the page, so there is no image to keep current. The first is the loop: a project's note, the backbone folder, GitHub, the scheduled agent with one item a day and the radar on Sunday, the new version, and back into the projects; beside it the `- [?]` question to the maintainer with the answer coming back as a note, and `brain/` with its second copy, which never go to GitHub. The second is the life of one idea. Twelve and six boxes, labels of two to four plain words. Both were parsed and drawn with mermaid-cli 11.17.0 before they were saved, and the self-test holds what it can without a browser: two blocks, plain flowcharts, every label quoted, nothing GitHub refuses, and ceilings of 14 and 8 boxes.

**The project brief learned what the backbone's own learned in 3.21.0.** `templates/routine-project.md` said "paste it as the prompt" and pushed with `git push origin HEAD`, which a checkout with no branch refuses (measured on git 2.55.0: "not a full refname"). It now gives a scheduler elsewhere three sentences that point at the file `routine.sh --brief` names; keeps `git push origin HEAD` where there is a branch, which is a person's own machine and the one push `.claude/settings.json` allows there; pushes to the default branch by name where there is none; and says what to do when GitHub refuses a push because it moved. The walkthrough told people to change the routine by editing the template, which the next `just template-update` overwrites: it now says to copy it to `.ai-backbone/routine-project.md`, which `routine.sh` has always read first.

**Smaller.** A question put to the maintainer carries the answer the agent would give and one sentence on why it matters, so that "yes" is an answer (spec skill step 3 and the spec template; the idea is Spec Kit's clarify step, whose command template was not read). The ADR template's Measured-on line allows "Nothing" only for a decision that says nothing about what a tool or a version does, and "from memory" is never the reason. `setup.sh`'s header and the walkthrough say that `just` on Linux is `rust-just` from PyPI, a third party's repackaging (github.com/gnpaone/rust-just, read on PyPI 2026-09-19 at 1.58.0, level with the author's), and that a watch row for it would need a `pypi:` source kind `upstream.py` does not have; not built. Two limits accepted on purpose are written where the checks live, so that a close reading stops reporting them: the commit-message check tests for a letter outside ASCII, so Turkish typed in plain ASCII passes and an English word with a diaeresis is refused; gitleaks lets Amazon's documented EXAMPLE key through by its own allowlist and refused a random key of the real shape (both measured 2026-09-19). The comment in the hook config carries no version number, because `upstream.py` looks for the pin anywhere in that file and a number in a comment would hide a pin that has moved; a check holds that. The walkthrough and `docs/README.md` now say what the scheduled agent does on a Sunday, which 3.22.0 built and did not write down. Sixteen new checks: fifteen were seen failing on the old files first, the sixteenth on the first draft of the comment it guards.

## 3.22.1 — 2026-09-21

**`just snapshot` really does leave the heavy folders out.** Every one of its
`-x` patterns began with `*/`, and zip matches a pattern against the whole
stored name, so `*/target/*` saw a `target/` one level down and never the one
at the root — which is where a Rust project's build folder always is, and a
Node project's `node_modules/`. The zip a person made "just in case" carried
the artifacts whole, sometimes gigabytes of them, into `.snapshots/`. Each
heavy folder is now named at both depths. Nothing a person types changes; a
project picks the fix up with `just template-update`.

## 3.22.0 — 2026-09-19

Nothing a person types changes. For a project there is nothing to do: the
radar is the backbone's own and no project receives it.

**The radar: once a week the scheduled agent looks outward.** The backbone
borrowed from OpenSpec and Spec Kit on the day they were cloned and had not
looked since; the brief reached its references only when the backlog was empty,
and the stored prompt stopped one step before that. On a Sunday the run's one
item is now to read what Claude Code, OpenSpec, Spec Kit and Gemini CLI have
published and whether the AGENTS.md README, the Agent Skills specification and
Copilot's page on AGENTS.md have changed, and to leave what matters as `idea:`
lines in `docs/backlog.md`, in its own words, at most three a run and never
more than five open. The ordinary runs reach them in their turn, oldest first,
behind the projects' own notes.

What it reads was written by strangers and it can push to `main`, from where
the maintainer's machine pulls it, so the reading is done by code and not by
the agent with `curl` (`.ai-backbone/radar.py`, `just radar`): the top of a
file, down to the heading seen last time, headings and the lines a narrow
filter lets through, each cut at 200 characters, 40 lines a source, plain
ASCII. A file with no versions is never shown: only that it changed. Only
files on raw.githubusercontent.com, which a sandbox can read while every other
repository's API answers it 403 (measured). Changelogs and specifications,
never a skill, a prompt or a command template. `just radar-mark` moves one
marker in `docs/radar.toml`; `just radar-save` commits the markers and the
run's log line and refuses anything else, looking at the folder and at what is
committed and not yet on GitHub, because a check an agent runs on itself
missed a change committed first (measured). A run that builds an idea checks
the fact it rests on through the same window: `just radar <source> "<heading>"`.
No code can tell what a line means, so a line that gives orders is shown like
any other; the fixture that holds one is there for the rehearsal, where the
pass mark is that it is reported and not obeyed.

**The scheduled agent can leave notes again.** 3.21.0 refused a note from any
checkout with no branch, because a note committed in the middle of a rebase
had been lost that way. A scheduled run's own checkout has no branch either,
is exactly what GitHub has, and is pushed to `main` by name: that one is let
through, and the maintainer's clone on no branch is still refused. Found before
any run needed it, because the radar writes its ideas as notes.

The splice guard was measured under mawk 1.3.4, which is `awk` in the sandbox:
nothing on the real recipes, every planted offence named. Sixteen new checks.
Spec 012.

## 3.21.3 — 2026-09-19

Nothing a person types changes. For a project there is nothing to do.

**A brake on growth that an agent respects.** A scheduled agent works on this
backbone every day, and from spec 012 on it will also build ideas it read about
elsewhere. Each one is small and sensible; a hundred of them are not the
radically simple thing a non-programmer was promised, and nobody reads the
repository to notice. So the self-test holds a new project to what it measured
today: 40 tracked files (a ceiling since 3.12.0), 37 recipes on show, an
`AGENTS.md` of at most 7,000 bytes (6,644 today). At the ceiling, adding means
taking something out first. Raising a number is a person's decision, made in an
attended session; the scheduled agent's stored prompt forbids it, and that
prompt is the one text the agent cannot edit.

## 3.21.2 — 2026-09-19

Nothing a person types changes. For a project there is nothing to do.

**`just upstream` can see from inside a cloud sandbox.** A sandbox's GitHub
proxy answers the API only for the repository attached to the session and
gives every other one a 403, by design, so the scheduled run has written "not
read: just, prek, gitleaks, graphify" in every report since it began. A one-off
run measured what is open there instead (spec 012): `git ls-remote --tags` of a
public repository works. So when the API refuses, with `gh` or without it, the
GitHub source asks git for the tags: names only, newest first, a release
candidate not counted as a release, and no days, which is enough to say
"newer". When git cannot list them either the source is unreachable and says
both reasons, never "current". Two checks, with the API pointed at a port
nothing listens on and git pointed at a folder; both fail on the old file.

## 3.21.1 — 2026-09-19

Nothing a person types changes. For a project there is nothing to do.

**`sh .ai-backbone/setup.sh` now ends with one meaning.** It exited 0 when
`just` could not be installed at all and 1 when the `just` it found was merely
too old, so a caller reading the code was told the worse of the two cases was
the good one. The header now says what the code means — 0 when git, just, uv,
prek and graphify are all on the PATH as the script ends, 1 when any of them is
not — and the last lines of the script name what is still missing. `gh` is left
out of the count on purpose: only `just publish` needs it. The repo's own state
(no vault, no hooks) stays `just doctor`'s to report, which is why this repo's
CI keeps naming the tool it wants instead of leaning on the code alone. Two
self-test checks hold both ends.

## 3.21.0 — 2026-09-19

Nothing a person types changes. For a project there is nothing to do.

**The backbone next to your projects keeps itself level with GitHub.**
The maintainer stopped opening the backbone: the projects leave notes and a
scheduled agent does the work. Measured on scratch clones against a bare
stand-in remote: a note written from a project while GitHub had moved, which is
every day now, was refused, the message said "GitHub not reachable", and the
clone was left ahead and behind. From then on `_backbone-refresh` (`pull
--ff-only`) could never bring it level and said nothing, every project was
compared against a stale tree, later notes piled up unsent, and `just publish`
was refused. The backbone's own `session-start` printed "GitHub: up to date."
on top of a rebase it had left half done, after which the next note committed
the conflict markers. `backbone-note` printed "sent" when a hook had refused
its commit, and sent a note to whatever branch the clone happened to be on.
There were three pulls and each failed its own way, so now there is one:
`_backbone-level`. On `main` and clean only; fetch; rebase, and abort when it
does not fit; send the note commits that never went out, and nothing else,
because a push of saved work stays the act of whoever saved it. It says why
when it cannot, in the project's session, to the agent there: unsaved work,
another branch, a rebase somebody left, work that does not fit together.
`backbone-note` brings the clone level first, writes one line whatever the text
holds (a newline used to forge a second line with any date and author), pushes
only what it committed, and tells "GitHub moved" from "not reachable" by
whether a fetch answers. `docs/backlog.md` merges as a union, here only: both
sides add lines to it. Measured too: union loses lines in entries longer than
one line and brings removed lines back, so it is on that one file, and the
brief says what a repeated line is.

**The scheduled agent gets a memory, a brief for the machine it runs on, and
limits it cannot edit.** Its sandbox keeps nothing, and its brief had it write
the run's report into a `brain/` that vanished: every run began with "no
journal entries yet". It now ends with one line in `docs/routine-log.md`, and
the backbone's `session-start` prints the last two. `routine.md` lost the
journal, the brew report and the borrowing step nobody could reach (the stored
prompt paraphrased the brief and stopped one step early; it is a pointer now),
and gained what to do with a refused push, a line that waits for something
(`blocked:`), a line that is the maintainer's to decide (`- [?]`, never more
than three, asked one at a time in Sunday's report, answered through
`just backbone-note "decision: ..."`), and a claim by a spec nobody has touched
for 14 days. What the agent pushes is pulled to the maintainer's machine and
run there, and a brief in the repository is a brief the agent can rewrite, so
the limits live in the stored prompt, quoted in `docs/01-getting-started.md`;
the self-test hook now also fires for `routine.md`, `.gitignore`,
`.gitattributes` and `.pre-commit-config.yaml`; the suite fails when the
backbone stops ignoring `brain/`; and the machine that pulls says which guard
rails a pull changed. What the sandbox can reach was measured with a one-off
run and is written in the brief: other repositories' API is closed by design,
their raw files, tags and clones are open.

**What a review of this change found before it was saved**, each reproduced
by a second agent on a bare stand-in remote. Two sessions starting together,
which several agents of one workflow do, rebased the same clone at once: in 4
of 120 forced overlaps the newest note was left as a staged deletion, and the
next note then removed a line on GitHub and said "sent"; a note written while
another session was mid-rebase was committed on a detached HEAD and lost. So
one at a time: a lock folder in the clone's git directory, shared by
`_backbone-level` and `backbone-note`, cleared after ten minutes if its run
died; 125 forced overlaps afterwards, none broken. `_backbone-tag` read the
version from the folder's files and tagged HEAD, so a version bumped in unsaved
work was tagged on the commit before it, and a saved, unpublished one was
uploaded under its tag; both now come from `origin/main`, because a tag on
GitHub is not something the person can take back. `backbone-note` pushed
whatever sat under the note, including somebody's saved, unpublished work; it
sends itself and the notes before it, or says why not. A scheduled run's
checkout has no branch and was told every morning that it was "not brought up
to date"; when it is what GitHub has, it is told so. In the brief, the revert
after a failed save reverted nothing (`save` has staged the work by then), a
maintainer's yes looped back into a question, and the 14-day lapse could not be
measured in a shallow checkout.

`_backbone-tag` said "GitHub would not take the tag" when GitHub had not
answered at all; it says nothing then and tries at the next session.
`backbone-note` ended without a word in a folder whose `AGENTS.md` has no
project row. Eighteen new checks; the first twelve were run against the old
recipes first, where nine of them fail. Spec 011.

## 3.20.0 — 2026-09-19

**For a project that already exists: two things your agent adds by hand.**
`AGENTS.md` and `docs/audit-lenses.md` are the project's own and no update
carries them. Add this bullet to `AGENTS.md` section 8, "Do not":
"- Do not use a feature of a pinned version from memory. Your training ended on
a day and the pin may be past it: read its notes (`just upstream <name>`) or its
source on this machine, or measure it. In an ADR that rests on it, write
`measured on <name> <version>`." And under the first lens of
`docs/audit-lenses.md`, add the paragraph that asks which version a claim was
measured on, from `.ai-backbone/templates/audit-lenses.md`. The recipe that
brings you this version is your old one and does not say so; from the next
update on, `just template-update` does.

**What you type is what runs.** `just save`, `just backbone-note`, `just spec`,
`just adr`, `just new-project` and every other recipe that takes a word from you
pasted that word into the script that runs it. A dollar sign followed by a word
stopped the save with "unbound variable"; a dollar-paren or a backtick ran as a
command and its output became the commit message; double quotes vanished on the
way; and a project's name went into `AGENTS.md` through perl, where it was code.
Now every recipe reads its argument the way a shell script does, as `$1`, under
`[positional-arguments]`, and the text arrives exactly as typed. Nothing you
type changes. The self-test refuses any recipe that goes back to pasting — in
`core.just`, the backbone's own `Justfile` and the stack examples, a quiet
`@name arg:` and a default in single quotes included. A `stack.just` copied from
the Swift example before this version keeps its old `build-app` line, because
that file is the project's own and no update touches it. Found by Yerly XL on
2026-09-18.

**The floor, said out loud.** That attribute needs just 1.29 (June 2024); the
recipes already needed 1.27 for their groups, and nothing had ever said so.
Ubuntu 24.04's package is 1.21, and it stops at "unknown attribute" with no hint.
A check inside `just doctor` cannot help, because doctor lives in the file that
fails to parse. So `setup.sh` — the one script that runs before just reads a
recipe — compares the version, moves an older just itself (`brew upgrade just`
on a Mac, `uv tool install rust-just` elsewhere, asked for twice like every
other install) and only then, if it is still old, says what it found and where.
`just tools-update` now also moves a just that came through uv, which on Linux
it never did. Found by reading the tools' own changelogs; no project paid for
it. (`set minimum-version` was looked at and left alone: on every just before
1.55 the setting is itself the first error.)

**A refusal, tried once more, and shown.** `setup.sh` asked uv once for each
tool it installs, and when a sandbox dropped that one request it ended with
"just could not be installed" and told the reader to type the command that had
just failed. Now a tool uv refuses is asked for a second time, both attempts on
the screen, so uv's own words — a proxy, a directory not on the PATH — are the
reason, and the ending points at them and says to run the script again; it only
adds what is missing. The branch that said "just is installed but not on the
PATH yet" is gone: it was never true for anything this script installs. The
self-test now runs `setup.sh` with every tool faked, under dash where there is
one and with a system folder of its own: on a Mac `sh` is bash, so a bash-only
line stayed green here and went red on CI, and a packaged just in `/usr/bin`
shadowed the check that meant "no just". Seen by the backbone's own routine in
a Linux sandbox on 2026-09-18.

**An agent's knowledge has an end date.** An agent is trained up to a day, and a
version released after it is one the agent cannot know — and it will not say
so; it remembers the version before and answers as if it were this one. Yerly
XL had made the opposite its habit: "measured, on SurrealDB 3.2.4", then a
table of what worked and what was accepted as syntax and silently did nothing.
The maintainer asked for the habit to be the rule. So the `session` skill says
it: nothing this project pins is used from memory — read what it released since
the pin, or the pinned version's own source, already on the machine, or measure
it, and write `measured on <name> <version>` into the decision. An agent that
cannot say when its training ended treats every pin as newer than itself. The
ADR template gains a **Measured on** line next to the **Relates to** line 3.9.0
added, the first audit lens asks it, and `AGENTS.md` §8 gained the rule quoted
at the top of this entry.

The tools follow. `just upstream` shows each pin's own release date beside it —
the day that version came out, not the newest one. `just session-start` prints,
every session and offline, what the project is built on and which pins came
out in the last twelve months, with one sentence: an agent whose training ended
before one of those dates does not know that version. And `just upstream <name>`
lists where the pinned version itself can be read on this machine: the cargo
registry folder, the `node_modules` folder next to the file that pins it, the
pub cache, the uv tool folder, the tool on PATH with its own `--version`, a
`CHANGELOG` inside any of those, and an optional `docs = "url"` from the watch
list. Paths, not prose. `pub:name` is a fourth source kind, for Dart and
Flutter. Nothing is upgraded, as before.

**Versions as they are really written.** 3.19.1 counted the source that cannot
be reached, the night this was being built. The same report had more to get
right. `AI_BACKBONE_OFFLINE` now makes every source count as unreachable, so the
self-test proves it with no network at all. A monorepo's sub-package tag
(`python/a2ui-core/v0.1.1`) read as "2 newer" every week because the 2 in a2ui
counted as a version. A number inside a suffix was read as text, so rc.10 sorted
before rc.9 and the tenth release candidate would never have been seen — and
Yerly XL pins a release candidate. `+build` was called a prerelease, so such a
row said "current" for ever. GitHub dates a release by the day its page was
written; SurrealDB writes its pages in batches, so 3.2.4 — out on 3 August — was
dated the 17th, and a column whose whole point is the date took the earlier of
the two days. A pin without quotes and a list with one bracket were tracebacks
and are now said in words; a long version ran into the next column; a project
that tags without releasing read as "stop watching it" on a machine without gh;
`just upstream <name>` ended in "recipe failed" when its source was silent,
though what is on this machine was the answer; and a network that accepts and
never answers cost one wait per row — five minutes of silence at the start of a
session, measured on a list of thirteen — so three sources in a row that do not
answer end the asking. A fresh list's own example row was MOVED on day one; it
now watches the secret scanner at the version the hook config really holds. And
the script runs on the Python uv already keeps: a Mac's own python3 is 3.9, has
no `tomllib`, and the weekly report had been dying there in silence.

**One way to update a project, not two.** Every `just session-start` in a
project already refreshes the backbone from GitHub and says when the project is
behind, and the agent working there updates it at a moment it knows is safe.
`just projects-update` and its daily schedule did the same from outside, while
somebody might be working inside: its save is a `git add -A`, a moment's bad
timing from taking an agent's half-finished work with it, and on 2026-09-18 it
left Yerly XL at "update FAILED". Both
are gone; `just projects`, the table, stays. The maintainer asked for fewer
moving parts, and this was the one that could do harm.

**A seed rule reaches nobody, and the update that would say so died on the way.**
`just template-update` now says it out loud when an entry in the span it prints
names `AGENTS.md`, the file no update carries. And that span no longer kills
the recipe: printing it through `head` under pipefail was a SIGPIPE, certain
once the jump is about ten versions, and it died with exit 141 after copying
the files. The span is captured first and cut afterwards, and the self-test
updates a project from 3.5.0 to prove it. The pages no longer promise "a zip
copy first": no zip has been made since 3.0.0, and git is the way back.

**The plan goes to GitHub first, and the routine skips what it claims.** 3.19.1
and this release fixed the same backlog line on the same night, because this
release's spec sat on one machine for hours where the scheduled agent could not
see it. Work that gets a spec now publishes it before it builds, the spec names
the backlog lines it closes, and the routine skips a line an approved,
unfinished spec has taken.

**The suite wrote into the real repository, once.** git hands a hook its own
`GIT_DIR`. A commit from a linked worktree ran the suite with it, and every
`git init` and `git remote` the throwaway projects ran landed in the real
repository: it went bare and lost its GitHub address. Repaired by hand, nothing
lost. The suite now starts by dropping whatever git exported, and re-enacting
the accident on a throwaway repository shows the old suite doing the same
damage and the new one none.

**`just ci` says why a job never started.** A failed job with no steps and no
log did not run, and GitHub writes the reason in the job's annotations and
nowhere else. `just ci` now asks for them in that one case and prints the first
sentence — "The job was not started because recent account payments have
failed…" — instead of "GitHub keeps no log for that job". Twelve of Yerly XL's
pushes were red for a day on 2026-09-18 for a billing hold found by hand.

**`just routine-remove` ends with a hint that is true.** Its last line used
four variables the recipe never set: three "unbound variable" errors and
`just routine-install " "`. It reads the schedule from the plist before deleting
it. Seen while removing the backbone's own local routine, which the daily cloud
routine had made redundant.

**The Rust example, as the first project rewrote it.** `server_dir` is the root
when a `Cargo.toml` sits there and `server` otherwise, so `just check` works on
the first run in both layouts; the header names the database group as sqlx and
PostgreSQL and deletable; `fmt` applies what `lint` only complains about; and
`test-fast` is the suite without doctests, for a project that wants it before a
commit. All three were written by hand in Yerly XL.

## 3.19.1 — 2026-09-19

**A weekly report that said everything was fine after reading nothing.**
`just upstream` puts a source it could not reach in the `newest` column and the
error text in the column next to it — but the summary at the bottom built its
blind list from that second column, so an unreachable source was never counted
blind and the report still ended with "Everything watched is current." Seen with
all four watched tools answering 403 behind a proxy.

The reason now travels beside the table instead of inside it, so the summary
reads the column it meant to: a source that could not be read is named under
UNKNOWN with what came back, and when nothing at all could be read the last line
says so rather than claiming the pins are current. The self-test carries a watch
list whose source cannot be reached, offline, so the claim is checked.

## 3.19.0 — 2026-09-18

**A waiver the size of a whole file.** `just ci-check` refuses a workflow that
runs `cargo test` without `--no-fail-fast`, and a project that means it says so
in the file: `# ci-check: skip no-fail-fast`. That waiver was read per file. A
workflow that tests the whole workspace and, beside it, one crate with a single
test binary — which has nothing to fail fast past — had to switch the rule off
for both lines to excuse the second one. The real line then stopped being
watched, silently, and a later edit that dropped the flag from it would pass.

Now the waiver can be as small as the line it is about. Written on a
`cargo test` command, or on the line directly above one, it speaks for that
command alone and every other `cargo test` in the file stays watched. Written
anywhere else it still waives the file, so nothing already in a project changes
meaning. The refusal names the line number it is on, and offers the narrower
form.

Found by a project that hit it on 2026-09-16 and got away with it.

## 3.18.0 — 2026-09-17

**A protection installed once, and never checked again.** `just stack` puts the
lint hook into `.pre-commit-config.yaml`, so a project that picked its language
that way cannot commit code the language layer rejects. A project whose
`stack.just` was written by hand — which is what every project does once it
outgrows the example — has the `lint` recipe and no hook, and nothing anywhere
said so. Neither did a project that lost the hook when somebody edited that file.

What it costs is the thing the hook exists to prevent, one step further along:
the work is saved, `publish-on-save` sends it to GitHub, the checks there go
red, and the first person to hear about it is the maintainer, by e-mail. That is
exactly the attention this backbone is written to protect.

So `just doctor` now looks: a project with a `lint` recipe and nothing running
it is a warning with the repair on the same line. And `just hooks-install` — the
public recipe for "make my hooks right" — adds the lint hook as well as
installing them, so the repair is a command somebody already knows rather than a
private recipe they have to be told the name of.

Found in a real project. The maintainer had asked why CI was e-mailing him about
failures; the answer was that nothing local was stopping them.

## 3.17.1 — 2026-09-17

**A test that passed because it crashed.** Thirty-odd checks were written as
`cmd | grep -q x`. `grep -q` leaves the moment it matches, the command is still
writing, and the SIGPIPE that kills it is what `set -o pipefail` hands back as
the pipeline's result. A check reading `! cmd | grep -q x` therefore passed
whenever the text *was* found — the loudest possible failure, reported as ok.
The suite now has a `says` helper that captures the output first and looks at it
afterwards, no pipe left to race, and a check of its own that fails if a pipe
into grep comes back.

Two things were hiding behind it. `just doctor`'s repo check was reading the
machine half too, so a computer without `gh` on it counted as a project with
something missing. And `_has-code` counted `.ai-backbone/upstream.py` — the
backbone's own plumbing — as the project's code, so every brand-new project was
told on day one to map code it had not written yet.

## 3.17.0 — 2026-09-17

**The root check named eight things, and all eight belonged there.** In a real
Rust project `just doctor` reported `Cargo.lock Cargo.toml deploy files
history.txt rust-toolchain.toml scripts CONTRIBUTING.md`. Two of those git was
already ignoring, five are where Cargo requires them, and the last is where an
arriving contributor looks first. A check that names what belongs is a check
people stop reading, and then it can no longer tell them about the thing that
does not.

`_root-strays` now passes over three kinds of entry:

- the files a repository open to the world keeps in its root —
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`;
- whatever `.gitignore` covers, which is not in the repository at all and so
  cannot be in the wrong place in it;
- whatever the project's own `stack.just` names in a `_root-allow` recipe. The
  backbone cannot know it is looking at a Rust project, but the project can say
  so in one line, and both shipped stack layers now say it for you.

The warning names that third way out, because the person reading it is the
person who knows the answer.

Four self-tests, each mutation-checked: dropping any one of the three ways out
fails exactly the check that covers it, and widening the allowance to everything
fails the fourth — a real stray, still named with all three in place.

## 3.16.2 — 2026-09-16

**Three things the backbone said about Linux that were not true there**, all
found by its own checks on their first run — which is the whole argument for
3.16.0, made by the thing itself within an hour of shipping.

- `sh .ai-backbone/routine.sh --which` failed on a machine with no agent
  installed, printing to stderr and exiting 1. "Which agent would you use" has a
  true answer on such a machine, and it is "none"; it now says so and exits 0.
  `just routine-install` makes the decision instead, which is where a decision
  belongs.
- `just routine-status` and `just routine-remove` answer correctly on Linux —
  the weekly schedule is macOS launchd, and on Linux the recipe hands you the
  cron line — but the self-test only recognised the macOS sentence, so the two
  recipes read as broken on any machine that is not a Mac.
- `just routine-remove` did not say how to get the schedule back. It now prints
  the exact `just routine-install` line, with the day and time it just removed.
  Written after removing a live schedule on the author's own machine while
  checking something else.

## 3.16.1 — 2026-09-16

**`just ci` printed one unfinished run's columns one place to the left.** jq
writes an empty field as nothing between two tabs, and `read` with a tab
separator folds a run of tabs into one, so a run with no conclusion yet — every
run, for the minute it is going — lost a column and printed its event where its
time belonged. Empty fields now travel as `-` and are read back as empty. Found
by pointing the new recipe at the backbone's own first push, which is the only
state that shows it.

Also: `just ci` no longer says a commit has not reached GitHub when GitHub has
taken the push but not yet indexed the run. It looks at what the fallback found
before it says anything about where the commit is.

## 3.16.0 — 2026-09-16

**The checks GitHub runs on every push, and a way to ask how they went.**

A project on this backbone could be sent to GitHub and have nothing waiting for
it there, and if something was waiting, the only way to hear about it was an
email. Three recipes:

- `just ci-init` writes `.github/workflows/checks.yml` and `.github/dependabot.yml`.
  It guesses the language from the files that are there, never adds a second
  workflow beside one the project already has, and for a project it cannot place
  writes the part that is true in any language.
- `just ci` says how the last push went: every job of every run for the commit
  you are on, and for a job that failed, the last lines before GitHub's own
  error marker. One real failed job's log is 2667 lines, of which 19 say what
  happened; the rest is the runner starting up and tidying away. It is quiet and
  useful when there is nothing to show — no checks yet, nothing pushed yet, no
  address, still running — and it never exits non-zero, because a red build is
  an answer and not an error.
- `just ci-check` asks whether the checks still carry the lessons they were
  built on, and runs before every commit that touches them.

That third one is the point. Four of the five lessons in the starter are
*settings*, and a setting cannot fail on a runner: it silently stops being there
the first time somebody edits the file. `examples/README.md` has said since
3.0.0 that a mistake which has already cost you something belongs in a recipe
that fails rather than in a sentence, and this is that. A lesson you mean to
drop is waived in the workflow itself, in writing, and `just ci-check` prints
the line to write.

**The five lessons**, all of them measured on Yerly XL on 2026-09-16, where
between them they cost a day of red builds and three runs that tested nothing:

1. A GitHub runner arrives with 14 GB free on a 72 GB disk. Deleting the .NET,
   Android, Haskell and Boost toolchains it ships gave 30 GB. Below that, the
   linker ran out of disk and died with `Bus error`, which names no cause and
   reads like a compiler bug.
2. Debug info in CI is a map for a debugger nobody can attach.
   `line-tables-only` keeps the line a panic names and drops the gigabytes.
3. `cargo test` stops at the first test binary that fails. Six of twenty never
   ran, and the failures in them were found a day later. `--no-fail-fast`.
4. A concurrency group keyed on the branch cancels superseded pull-request runs,
   which is right, and also cancels pushes to the default branch, which throws
   away the history you read later to find where something broke. Key it on the
   commit when the event is not a pull request.
5. Do not prove which crates are inside a binary with `strings`. A stripped Rust
   binary carries no crate names at all — a small experiment found the crate
   name zero times and the panic source path once — so the check reports every
   crate as absent and passes whatever is in there. Ask cargo's own
   `--message-format=json` record, and prove the record is not empty first. This
   one ships as a commented job, because what must not be in a binary is always
   the project's own claim.

`ci-check` asserts only the first four, and all but the concurrency one only for
cargo. The disk lesson is one Linux runner with seventeen Rust test binaries on
it; firing it at a Go or Gradle build would be asserting something nobody here
has measured, and blocking somebody's commit over it.

**There is no `ci-swift.yml`.** Those lessons are about a Linux runner; a Mac
runner is a different machine and nobody here has measured one. `just ci-init
swift` says so and offers the generic starter. Writing a guess down as a starter
is how a guess becomes a fact nobody rechecks.

Also: `just doctor` says whether a project has checks and whether they have
drifted; `just session-start` says in one line when the last push did not pass,
once per commit rather than once per session; `just publish` names `just ci`
when there is something to watch; `just stack <lang>` points at `just ci-init`
instead of asking for a hand-typed `cp`; both Dependabot examples now watch the
workflow's own actions, which go out of date the same way crates do; and `just
stack` no longer dies without a word when it cannot find a layer — a `grep` that
matched nothing was killing the recipe before the sentence that says what to do.

And the backbone now uses what it ships: `just ci-init generic` put
`.github/workflows/checks.yml` here, and every push runs `sh .ai-backbone/setup.sh
-y` on a clean Ubuntu machine and then `just self-test` on what it installed. So
the documented install is now run by somebody other than the person who wrote it,
every time — which is the gap that let a documented Docker install stay broken in
three places in the first project built on this.

## 3.15.1 — 2026-09-16

**`just publish-on-save on` said "Every  now sends to GitHub".** The recipe
quoted `just save` in backticks inside a double-quoted shell string, so the
shell ran it as a command and put its empty output in the sentence. Plain quotes
now.

## 3.15.0 — 2026-09-16

**Work that exists on one disk only.** `just save` commits here and `just
publish` sends; the split is deliberate, so that nothing leaves the machine
unasked. It also means a project can quietly accumulate weeks of work that a
failed disk would take with it — the first project on this backbone had 76
commits, all of phase 1, in exactly that state.

`just publish-on-save on` makes every save go to GitHub as well, once, per
repository, recorded in that repository's git config. Off by default and off
until somebody says otherwise, because the promise about the machine is worth
more than the convenience. When a push fails the save still stands and says so:
the work is committed either way, and "not sent" is a sentence rather than a
silence.

## 3.14.0 — 2026-09-16

**The weekly routine could not be installed in a project at all.** Four readers
went over everything the last six versions added, and this was the worst of what
they found: `just routine-install` looked for the brief in two places, and the
one a project actually has — the template — was neither. The headline feature of
3.12.0 and 3.13.0 worked only in the backbone's own folder, and said "No routine
brief" everywhere else. `routine.sh` knew the third path; the recipe had its own
copy of the lookup and they had drifted. There is one lookup now:
`routine.sh --brief` answers, and the recipe asks.

Four more from the same reading:

- On Linux the recipe printed a cron line for **Sunday 08:47 whatever time was
  asked for**. The day and the time are now read first, before anything else, so
  the line printed is the line requested — and the self-test check that claims to
  prove a bad time is refused finally reaches the code it names.
- `routine-status` and `routine-remove` answered as though nothing were
  installed on a machine that schedules with cron, which is where the recipe
  itself sends a Linux user. They now say what they can and cannot see.
- `routine-now` wrote to the terminal and not to the log, so `routine-status`
  reported "It has not run yet" after three runs by hand.
- `just upstream` reported a source it **could not read** as "current", and the
  closing line "Everything watched is current" covered it. A source that answers
  nothing now reads `unknown`, with its own line saying a watch that cannot read
  its source is not a watch. The commit hook also runs the self-test when
  `routine.sh` or `upstream.py` changes; it did not before, so both shipped
  untested.

`docs/01-getting-started.md` is current again on both features: it had still been
telling people to set the schedule up by hand.

## 3.13.1 — 2026-09-16

**A routine that died mid-run would never run again.** Its lock is removed when
the run ends, but a run that ends outright — power lost, a flat battery, kill -9 —
never gets there, and every week after that said "a run is already going here"
and did nothing. The lock now holds the run's process number; a lock whose
process is gone is cleared, said in the log, and the run goes ahead.

## 3.13.0 — 2026-09-16

**The weekly routine was installed, rehearsed once, and found to do nothing.**
It ran, and every shell command it tried was refused: the agent had never been
opened in that folder by hand, so the repository's own permission list was
ignored, and the print mode it runs in cannot ask. It changed nothing, wrote the
refusals in the journal and stopped — which is the behaviour the brief asks for,
and the reason to rehearse rather than to wait for Sunday.

Two changes. `just routine-install` now **runs a real command through the
agent** and reads the output, instead of asking it to say "ready": an agent that
answers politely and cannot use the tools is a schedule that does nothing every
week, which is worse than no schedule because it looks like it is working. When
the refusal is the one this recipe can fix — the folder was never trusted — it
trusts it, says so, and tries again; anything else stops the install with what
the agent actually said.

A second rehearsal, with the permissions fixed, found two more — both of them
things that only appear when an unattended agent runs in a folder a person also
uses, which is exactly where this one runs. It refused to save work it found
half-finished, and it noticed that step 2 of its own brief would have renamed
the maintainer in their own repository. Both are now rails rather than good
manners: **step 0 stops on a dirty tree**, and an identity is set **only where
there is none**. `routine.sh` also takes a lock, so two runs cannot overlap.

And `.claude/settings.json` now says what an unattended run may do here: `just`,
`prek`, `graphify`, the setup script, `brew update` and `brew outdated`, and the
handful of git verbs the brief uses — with `git push --force`, `git reset
--hard`, `rm -rf`, `sudo` and a blanket `brew upgrade` denied outright. A rail
in a file beats a rule in a paragraph.

## 3.12.1 — 2026-09-16

**`just routine-status` said the time wrong.** It read every number near the
schedule, including the ones in the log file's own path, so a Sunday at 08:47
was reported as "0 8 47 795 05". It now reads the three fields it means and says
"every sunday at 08:47".

## 3.12.0 — 2026-09-16

**A repository can work on itself once a week, with nobody watching.** The brief
for an unattended agent has been in `.ai-backbone/routine.md` since 3.0.0, and
nothing called it: it needed a scheduler, and setting one up by hand is exactly
the kind of step this backbone promises never to ask for.

`just routine-install "sunday 08:47"` installs a macOS user agent that runs
`.ai-backbone/routine.sh` weekly; `just routine-status` says whether it is
loaded and shows the last run; `just routine-remove` takes it off in one
command; `just routine-now` runs it in the terminal exactly as the schedule
would. The log lands in `brain/`, so a week's work is waiting in the vault
rather than in a terminal nobody had open. On Linux the recipe prints the cron
line for the same script instead of pretending.

**Which agent runs it is not the backbone's business.** `routine.sh` looks for
claude, opencode, gemini, codex, crush, cursor-agent and amp, in that order, and
`AI_AGENT_CMD='mytool run {prompt}'` overrides all of it — the same reasoning
that gives every editor its own rule file. Two of those invocations are verified
and the rest are a best guess, so `routine-install` **tries the agent once
before installing anything**: a wrong flag is found on the day it is set up
rather than after six weeks of silence.

**The routine now reports the machine without touching it.** `brew update` and
`brew outdated`, plus `just upstream` where there is a watch list, go into the
weekly journal entry. It does not run a blanket `brew upgrade`: that is how a
working machine breaks on a Tuesday with nobody able to say which package did
it. The tools the backbone owns are the exception, and `just tools-update`
already handles those. And when it does upgrade something, it writes the guard
test first, as 3.11.0 says.

## 3.11.0 — 2026-09-16

**Pin what would break in silence, then upgrade.** A compiler catches a renamed
function. It does not catch a library that still compiles and computes something
else, and that is the upgrade that costs a weekend. The project that found this
was raising six crates at once, including the one that hashes passwords: a
changed hash format locks every existing person out of their own workspace, and
the only symptom is that the right password stops working. It wrote two guard
tests first — a real stored hash from the old version, and a digest checked
against an independent implementation — watched them pass on the versions in
use, and only then moved. Both still passed, which is what made the upgrade
something other than a hope.

The `session` skill now says to do that, with the three kinds worth the ten
minutes every time: what is already stored, what was computed and written down,
and what somebody else is holding. It also says what makes such a test worthless
— asking the library what it computes and then asserting that.

**And the README says what this is for.** Not what it contains, which it already
said, but why a person who does not write code ends up with a professionally run
project: the setup a careful engineer would do is done once, here, so the two
decisions left are the ones that are actually theirs — what the product should
be, and what it is built on — and the second comes with a weekly briefing rather
than a search.

## 3.10.0 — 2026-09-16

**What this project is built on, and what changed in it.** A maintainer was
opening GitHub by hand, one repository at a time, to see whether the language,
the database, the protocol or the test runner had moved — and a version number
was never the thing he was looking for. What he needed was what changed, and
what following it would cost.

`docs/upstream.toml` is the list: what this project is built on, the version it
is pinned at, the file that holds that pin, why it is used, and what to check
before following it upstream. `just upstream` says what each one has released
since the pin, and marks a pin the file no longer holds — a watch list that has
drifted from the code is worse than none. `just upstream <name>` prints that
project's own release notes, which is the half that matters. Sources are
`github:owner/repo`, `crates:name` and `npm:name`; a project that tags rather
than releases falls back to tags. Start one with `just upstream-init`.

Nothing here upgrades anything, ever. `just session-start` prints the summary on
the same weekly rhythm as the tool check, and the `session` skill says what an
agent does with it: read the notes, say in one paragraph what changed and what
it would cost, and put an upgrade in a spec like any other work. A project with
no list stays quiet.

## 3.9.0 — 2026-09-16

**Rules that argue with each other.** Nothing in the backbone ever read two rules
together and asked whether they agree. `just sync-rules` keeps the copies of one
rule file identical, and `just self-test` checks what a project looks like, but a
decision written in March and a decision written in September could contradict each
other for ever without anybody noticing — and the newer one usually loses in silence,
because the code still obeys the old one. The project that asked for this had it
happen the same afternoon: an ADR gained a rule saying no model ever touches the data,
three lines under a rule saying a model may be shown the data, and only a re-read
caught it.

Two changes, both small on purpose, because a contradiction is a question of meaning
and a script that tried to find one would mostly find noise. `docs/audit-lenses.md`
gains a fifth always-there lens, **the rules against each other**: read the rule file,
the ADRs and the specs as one document, find the pairs that cannot both be followed,
and say which one the code actually obeys. And the ADR template gains a
**Relates to** line, so a decision that amends an earlier one says so where the next
reader will look. Ask for the lens with `just audit-lenses` in a project that has no
lens file yet; a project that already has one adds the section by hand or from this
template.

## 3.8.0 — 2026-09-16

**An audit ends by running the thing.** The first project to finish a full audit
fixed everything twelve lenses found, then ran the product for real and found
six more defects in an afternoon: two servers against one database raced on a
session that was created per connection, every closed listener left a live query
behind, a manager could invite an owner, and the image's Rust was older than a
dependency needed, so the documented install would have failed at its first
crate. No lens saw any of them, because each lives between two processes or in
the second minute rather than the first.

The `audit` skill now ends at a rehearsal instead of at a fix, and names four
that have each found something real: two servers on one database under load,
fifty long-lived things opened and closed with the count checked before and
after, the documented install on a clean machine, and a restore that is then
used. Each is written as `just rehearse <name>`, because the rehearsal that
finds a defect gets run twenty times while it is fixed. Each ends by counting
something; a rehearsal with no number is a rehearsal that passes. The second-day
lens in `docs/audit-lenses.md` also asks whether the image's toolchain is at
least what every dependency declares.

**Swift projects lint again.** The hook added in 3.7.0 calls `just lint`, and
`stack-swift.just` had no such recipe, so it stayed quiet in exactly the
projects that got it. The Swift layer now has one: `swift format lint --strict`
over `Sources` and `Tests` (the toolchain's own formatter since Swift 6, the
separate `swift-format` binary before that), plus SwiftLint where the project
has asked for it with a `.swiftlint.yml`. A Swift project picks it up by
running `just stack swift` again.

## 3.7.0 — 2026-09-16

**A save can no longer commit code the language layer rejects.** A project that
ran `just stack rust` had `just lint` — clippy and `cargo fmt --check` — but
nothing that ran it, so `just save` committed code that failed lint and CI
found out later. The Rust layer mentioned a hook in a comment block the person
was meant to copy into `.pre-commit-config.yaml` by hand, which is the kind of
manual step this backbone promises never to ask for.

`just new-project`, `just adopt` and `just stack <lang>` now put one hook in
`.pre-commit-config.yaml`: it calls `just lint`, so the language layer stays
the only place that knows the commands. The hook is quiet in a project with no
`lint` recipe, and it skips a commit that touches only Markdown or `docs/`. A
project that chose its language before today gets the hook by running
`just stack <lang>` again: instead of only refusing, that command now adds
what is missing. Nothing changed in `just save`, `undo`, `publish` or `doctor`.
Spec: `docs/specs/009-lint-before-save.md`.

## 3.6.0 — 2026-09-15

**An audit that argues with itself before it argues with you.** A review by one
agent produces a list of plausible things, most of them wrong, and the
maintainer spends the afternoon finding that out. The first project to do this
properly measured it: 112 claims, 100 refuted, 11 real. The difference between
those two numbers is the whole feature.

`just audit-lenses` creates `docs/audit-lenses.md`, the questions an audit asks
about that project. Four are given and are the same everywhere: documents
against code, tests that prove nothing, what leaks, and the second day (upgrade
and restore). The rest come from what the project has decided, because a
decision in `docs/adr/` is a claim, and a claim can be violated.

The `audit` skill is the shape: one agent per lens reading real code, then three
skeptics per finding from different angles — one reads the code it names, one
tries to reproduce it, one looks for the guard that already prevents it — each
told to default to refuted when the evidence is not clear. Two refutals and the
finding is gone. A last agent asks what the lenses missed. Reviewers may run
anything and may edit nothing.

It says plainly what it is not. An audit reads code, and the defects that cost
the most are the ones only running the thing finds: a database function that
does not exist, a driver that cannot take a backup over the protocol in use, a
stream that goes quiet the moment the request that opened it returns. All three
of those were found by rehearsing, not by reading. So the rule is both, at the
end of a phase, as two separate acts.

New projects get the rule in `AGENTS.md` section 3. Projects that already exist
get the skill and the recipe from `just template-update`; add the rule to their
own `AGENTS.md` when it suits them, since that file is theirs.

## 3.5.0 — 2026-09-15

**A project now sees its own backbone notes.** `just backbone-note` has always
written to the backbone's backlog, committed it and pushed it, so a scheduled
agent picks the note up and answers it. Nobody told the person who left the
note. A maintainer who stops opening the backbone folder, which is the point of
the backbone, had no way of knowing a note was taken or answered.

`just session-start` in a project now prints that project's own open notes and
the last two that were answered, with the reminder that one line is all it takes
to leave another. The backbone's own session-start is unchanged: there it still
shows the whole backlog, because there the job is to work through it.

## 3.4.1 — 2026-09-15

**`just session-start` no longer ends in a raw error.** When GitHub refuses the
version tag, the step that tags it said so as `error: recipe '_backbone-tag'
failed with exit code 1` — an internal name and an exit code, at a person who
did nothing wrong. It now says it in plain words and hands the session back
clean. It also stopped giving up for good: a tag that exists only on this
machine used to be treated as done, so a tag refused once was never pushed
again. It now checks GitHub, not the local copy, and tries again next time.

## 3.4.0 — 2026-09-14

**One layout for every project** (spec 008). The root holds nine things:
`README.md`, `AGENTS.md`, `Justfile`, `LICENSE`, `stack.just`, `docs/`,
`src/`, `brain/`, plus the two pointer files. Code lives in `src/` (one part
straight inside, several as `src/web`, `src/server`, `src/ios`...), public
brand material in `docs/brand/`, private files in `brain/05-files/`.

- **`just doctor` names what strays** in the root and says where it goes.
  A rule in a document is forgotten; a check is not.
- `just brain-init` creates `brain/05-files/`; the vault README explains it.
- Why: six projects, four layouts. The maintainer wants one, with no clutter.

## 3.3.0 — 2026-09-14

- **A routine brief for projects**: `.ai-backbone/templates/routine-project.md`.
  A scheduled agent takes the oldest approved spec, does one task, runs the
  checks, saves, pushes, reports in five lines. Never from a draft. Why: the
  maintainer wants projects to move at night too, without giving up the say
  on what gets built.
- **`just projects-update`** (backbone only): every sibling project that is
  behind and clean gets `template-update`, `sync-rules` and a save. Why: the
  maintainer will not open the projects they are not working on; those must
  not fall behind either.

## 3.2.0 — 2026-09-14

**Nobody has to open the backbone any more.**

- **Projects refresh the backbone.** `just template-check` (and so every
  `just session-start` in a project) and `just template-update` first pull the
  local backbone from GitHub when its tree is clean, and tag the version in
  `core.just` if it has no tag. Why: the maintainer works in the projects; what
  a scheduled agent pushed reached this machine only when the backbone was
  opened by hand.
- **The routine borrows ideas.** When the backlog is empty, tools are current
  and nothing is broken, the brief sends the agent to the reference repos
  (`just ref-fetch`: Spec Kit, OpenSpec, ...) for one idea that keeps the
  backbone simple, written up as a spec first, source named.
- `AI_BACKBONE_OFFLINE=1` keeps the self-test from pulling into or tagging the
  real backbone.

## 3.1.2 — 2026-09-14

Learned from the routine's first run in a locked-down cloud sandbox.

- **`setup.sh` installs `just` through `uv` on Linux** (`rust-just`), so it no
  longer depends on `just.systems` being reachable. Its last line is honest
  now: "installed but not on the PATH" only when a binary exists, otherwise
  "could not be installed" with the one command to run by hand (backlog note).
- **Tags heal themselves.** A scheduled agent could push its commit but not its
  tag (403). The backbone's `just session-start` now tags the version in
  `core.just` when no such tag exists, and pushes it.
- **`routine.md`** gained `just brain-init` in the setup step, a fallback for a
  refused tag push, and a list of sandbox quirks with their workarounds (the
  Go toolchain for gitleaks, the `just` installer).

## 3.1.1 — 2026-09-14

- **`sh .ai-backbone/setup.sh` works on Debian and Ubuntu.** The script asked for
  `pipefail`, a bash-only option, so any machine whose `/bin/sh` is dash stopped
  at line 8 with "Illegal option -o pipefail" and installed nothing. It is plain
  POSIX sh now. Why it matters: this is the first command in the getting-started
  page, and nothing depended on `pipefail` — no pipeline's exit status is read.

## 3.1.0 — 2026-09-14

**The backbone can work on its own** (spec 007).

- **`just backbone-note` saves and sends.** The note is committed in the
  backbone on the spot (only `docs/backlog.md`) and pushed when GitHub is
  reachable. Why: a scheduled agent in the cloud can only see what is on GitHub.
- **`just session-start` pulls in the backbone** when the tree is clean and
  GitHub answers, and lists what came in. Why: what a scheduled agent pushed
  has to reach this machine before the projects can pick it up.
- **`.ai-backbone/routine.md`**: the complete brief for a scheduled agent, one
  item per run, self-test on save, push, five-line report. Scheduler-neutral:
  a Claude Code routine, a Cursor cloud agent or a GitHub Action can run it.
  The getting-started page lists what each needs.

## 3.0.1 — 2026-09-14

- **`tsconfig*.json` is exempt from the JSON check.** TypeScript allows comments
  and trailing commas there, and the checker does not. Found when a project's
  first commit under 3.0.0 checked every file at once. Seed and backbone config;
  a project that already has the file adds the two lines itself, or leaves the
  check alone if it has no TypeScript.

## 3.0.0 — 2026-09-14

**A clean start.** The git history of the backbone and of every project built
on it was squashed into a single commit, under the maintainer's new identity.
The old history is kept as a git bundle in each repo's private `brain/`, never
committed. Major because the migration paths are gone: a project on 0.x or 1.x
can no longer move up on its own (there is none left; all six are on 3.0.0).

- Removed: the 0.x and 1.x blocks of `template-update` and `template-check`,
  the old-layout detection in `just projects`, the `AI_FIRST_REPO` fallback,
  the two migration sections of the self-test and the skill text for them.
  `core.just` is 70 lines shorter; the self-test is 32 checks.
- The old template drafts left `.archive/`; they live in the backbone's `brain/`.
- Nothing a project sees changes. `just template-update` picks 3.0.0 up as usual.

## 2.2.0 — 2026-09-14

**The backbone improves itself while the person works on their project** (spec 005).

- **`just backbone-note "one line"`** in any project appends a dated line with
  the project's name to the backbone's `docs/backlog.md`. The backbone's
  `just session-start` prints the open lines. Why: a gap noticed in a project
  had nowhere to go but chat.
- **backbone-dev skill**, shipped to every project: the loop from a project to
  the backbone and back (spec if bigger than a fix, change, self-test on save,
  publish, tick the backlog, update the project), and the line between doing
  and asking. The maintainer's decision: agents fix and improve the backbone
  without asking; they ask only when a change alters what the person types or
  must do by hand, deletes files, or installs globally.
- **Tools update without a question.** The weekly release table now tells the
  agent to run `just tools-update`, and AGENTS.md §3 says so. `tools-update`
  also upgrades `just`, `gh` and `uv` through Homebrew when it is there.
- **AGENTS.md §3 gained two rules** (backbone notes, tool updates). Projects
  on 2.1.0 add them by hand; the backbone-update skill says so.
- The session skill's end step includes the notes.

## 2.1.0 — 2026-09-14

Seven gaps closed after a full read of the backbone (spec 004). Nothing moves.

- **`just adopt ../my-repo`** brings an existing repo onto the backbone from the
  backbone's side: owned files in, missing seeds added, every file the repo
  already has kept, `brain/` made ignorable, hooks installed, nothing saved
  until you say so. Replaces "copy the folder by hand" in the getting-started page.
- **`.pre-commit-config.yaml` is a seed now**: copied once, then the project's.
  A formatter you add there survives `just template-update`. Why: the file said
  "add your linter elsewhere" and there was no elsewhere. `just tools-update`
  still bumps the gitleaks version. Projects on 2.0.0 keep their copy as is.
- **`just adr <name>`** creates `docs/adr/NNNN-<slug>.md` from a template. The
  spec skill has pointed at `docs/adr/` since 0.3; now there is a command.
- **`just archive <path>`** moves a file or folder into `.archive/` with git and
  writes the folder's guide the first time. **`just ref-add`** writes
  `.references/README.md` the first time too. Both guides live in
  `.ai-backbone/templates/`. Why: the rules promised the guides and nothing created them.
- **`just session-start` prints the newest journal entry in full**, the one
  before as a head. A 39-line entry had lost its second half to `head -25`.
- **Turkish aliases only for Turkish projects.** `new-project` keeps
  `yedekle`, `yayinla`, `geri-al` when the language is `tr` and otherwise leaves
  a one-line hint in the seed `Justfile`.
- **Self-test before the core is saved.** `AGENTS.md` §3 says so, and the
  backbone's own hook config runs `just self-test` whenever a commit touches
  `core.just`, the manifest, a seed or a template. 57 checks.

## 2.0.0 — 2026-09-14

**The backbone is called `ai-backbone`.** The GitHub repo, the Desktop folder,
the hidden folder in every project (`.ai-backbone/`), the variable (`AI_BACKBONE`;
the old `AI_FIRST_REPO` still works) and every sentence that named `ai-first-repo`.
Major because the hidden folder moves; the move is automatic and keeps history.

- **A 1.x project** copies the core in by hand once
  (`cp ../ai-backbone/.ai-backbone/core.just .ai-first/core.just`), then
  `just template-update` makes a zip copy, runs `git mv .ai-first .ai-backbone`,
  and renames the path in `Justfile`, `.vscode/settings.json`, `AGENTS.md` and
  `README.md`. Nothing else of the project is touched. Running it again changes
  nothing. A 0.x project still moves in one go, now straight into `.ai-backbone/`.
- Why: the docs said "the backbone" from day one while the repo said
  `ai-first-repo`; two names for one thing. The maintainer picked `ai-backbone`.
- Old CHANGELOG entries and specs keep the old name; they are history.

## 1.4.0 — 2026-09-14

- **Acceptance check before done.** The spec skill now walks the Acceptance list
  against what was built and shows holds / not yet; anything unmet becomes a
  Task. Borrowed from Spec Kit's converge step, kept to one paragraph.
- **`just projects`** (backbone only) lists every project next to the backbone:
  backbone version, unsaved work, GitHub address, last save, and a note when one
  is behind or lives only on this machine. Why: six projects, one glance.

## 1.3.0 — 2026-09-13

- **Bridge files removed.** `ai-first.just` and `template-manifest.txt` leave the
  backbone root; every project built on it has moved to the `.ai-first/` layout.
  A project still on 0.x copies the core in by hand (`cp ../ai-first-repo/.ai-first/core.just ai-first.just`,
  then `just template-update`); the backbone-update skill says so. The self-test
  does the same instead of relying on the bridge.
- Migration verified on six real projects (three games, yerly, yerly-tech, xlarge):
  archives byte-identical before and after, checked by git blob ids and checksums.

## 1.2.1 — 2026-09-13

- **Migration keeps the guide of a non-empty archive.** `.archive/README.md` and
  `.references/README.md` were the backbone's and were removed on the move to 1.0.
  Now they stay when the folder holds anything of the project's: archived bundles,
  or listed references. Archived content itself was never on the list and was never
  touched. Why: three game projects carry their old repos as bundles in `.archive/legacy/`;
  the README there says how to open them. The self-test covers it.

## 1.2.0 — 2026-09-13

Polish after the first review of 1.0, all in the backbone; other projects pick
it up with `just template-update` whenever they choose.

- **Seven visible things in a project.** `CLAUDE.md`, `GEMINI.md` and the two
  bridge files fold away in VS Code like the rest of the plumbing. `.env.example`
  is no longer seeded; it is created together with the first secret. `CLAUDE.md`
  is the single line `@AGENTS.md`: its three Claude lines were already rules.
- **`just self-test`** (backbone only) builds a project from the current backbone
  and migrates a project made from the `v0.3.1` tag, in a temp folder, and checks
  what a person would see. The seed `Justfile` now lives in `.ai-first/seed/` so
  the backbone's own `Justfile` can carry recipes projects never get.
- **The journal arrives by itself.** `.claude/settings.json` gained a `SessionStart`
  hook that runs `just session-start`; its output lands in the agent's context.
- **The four human commands speak `chat_lang`.** `help`, `save`, `undo` and
  `publish` read `chat_lang` from AGENTS.md section 0 and print Turkish when it
  is `tr`, English otherwise (`_msg`). Everything the agent reads stays English.
- **`just publish` creates the repo.** With no remote and a logged-in `gh` it asks,
  creates a private repo under your account, then pushes with tags.
- **`just undo` resets staged changes too** (a failed save leaves files staged)
  and says so when there is nothing to undo. **`just save` prints one line while
  the checks run**; the first save ever downloads the secret scanner.
- `tools` in this repo is `claude`; new projects inherit section 0 and can set `all`.

## 1.1.0 — 2026-09-13

- **`just ref-add <url> "why"`** keeps a read-only, shallow clone of another repo
  in `.references/` and lists it in `references.toml`. **`just ref-fetch`** brings
  every listed clone back on a new machine; the clones themselves are never
  committed. Why: the backbone borrowed ideas from OpenSpec and Spec Kit and had
  no place to keep the source of an idea. Agents read `.references/`, never write
  there; graphify and the hooks skip it.
- The bridge files for 0.x projects stay for now.

## 1.0.0 — 2026-09-13

**Everything the backbone owns now lives in one hidden folder, `.ai-first/`.**
What a person sees in a project is theirs: `README.md`, `AGENTS.md`, `Justfile`,
`LICENSE`, `docs/`, `src/`, `brain/`. Major because files move; the move is
automatic and keeps history.

- **Moved.** `ai-first.just` -> `.ai-first/core.just`, `template-manifest.txt`
  -> `.ai-first/manifest.txt`, `brain-template/` -> `.ai-first/brain-template/`,
  `docs/specs/_template.md` -> `.ai-first/templates/spec.md`, `docs/examples/`
  -> `.ai-first/examples/`. In a project, `CHANGELOG.md` -> `.ai-first/CHANGELOG.md`.
- **No longer copied into projects:** the backbone's own ADRs and getting-started
  page, the language examples, the Dependabot files, `graphify-out/README.md`,
  `.archive/` and `.references/` READMEs, `docs/specs/README.md`. A fresh project
  has about 30 tracked files instead of 47, and `docs/` holds one README.
- **Migration is automatic.** A 0.x project runs `just template-update` twice:
  the first swaps in the 1.0 core, the second makes a zip copy in `.snapshots/`,
  moves the backbone's files with `git mv`, removes only what the old manifest
  listed as the backbone's, rewrites the stock `import?` line in `Justfile` and
  runs a second time without changing anything. Project files are never opened.
- **Manifest with three sections.** `[project]` is kept current, `[seed]` is
  copied once and then the project's, `[backbone]` never leaves the backbone.
  A line may read `path -> path-in-the-project`.
- **`just` prints the four commands a person types** (`help`): save, undo,
  publish, doctor. `just --list` is unchanged for agents.
- **`just new-project <name> [lang]`** sets `brain_lang` and `chat_lang` too.
  **`just stack rust|swift`** copies a ready language layer from the backbone.
- **`.ai-first/setup.sh`** installs every missing tool on a fresh machine, asks
  first. `doctor` points at it.
- **`tools` row in AGENTS.md section 0.** Rule copies for Copilot and Junie and
  the Claude skill links are generated only for the tools listed; `all` by default.
- **`.vscode/settings.json`** folds the plumbing away from VS Code's sidebar.
  Nothing is deleted. It is a seed: yours after the first copy.
- **Commit messages are checked.** A `commit-msg` hook wants `feat:`, `fix:`,
  `docs:`, `chore:`... and English letters on the first line. `just save` adds
  `chore: ` when the kind is missing. Why: a Turkish message in an English repo
  is a bug per AGENTS.md, and nothing enforced it. `just hooks-install` now
  installs both hook types; `template-update` re-installs them.
- **Spec template gained `## Questions`.** The spec skill asks them one per turn
  and waits for approval until the section is empty. Borrowed from Spec Kit's
  clarify step; nothing else from it.
- **README rewritten for the person who does not code.** Three steps, four
  commands, what each visible folder is. The five-line project README says how
  to start.
- **`template-update` prints the CHANGELOG entries** between the old and the new
  version, so the agent can explain the update without opening files.
- Bridge files `ai-first.just` and `template-manifest.txt` stay in the backbone
  root so 0.x projects can reach 1.0. They go in 1.1 once every project has moved.

## 0.3.1 — 2026-09-13

Fixes from the first end-to-end test with a non-programmer in mind: a to-do
app built from a fresh `just new-project`. Nothing moves, nothing to do.

- **`just save` on a clean tree says so and exits 0.** It used to print
  `nothing to commit` and a red error, every time a session ended with only a
  journal entry, because `brain/` is private and never committed. `session-end`
  now says that too.
- **Hook output only on failure.** A clean save prints the changed files and
  `Saved.`; `new-project` no longer opens with eleven lines of `Passed`. A hook
  that fixes files (final newline, trailing spaces) is retried once before the
  save is called failed.
- **File-safe names.** `just spec "Yapılacaklar Listesi"` creates
  `002-yapilacaklar-listesi.md`; `just new-project "Yapılacaklar Listesi"`
  creates `../yapilacaklar-listesi` and keeps the typed name as the project
  name. Spaces in a folder name broke the `gh repo create` line `publish` prints.
- **"Nothing to map yet"** instead of a warning in `doctor` and `session-start`
  when the repo holds no file graphify can parse, such as a one-file HTML app.
- **LICENSE names the maker.** `new-project` stamps the git user name and the
  current year; it used to carry the backbone author's name into every project.

## 0.3.0 — 2026-09-13

- **Hooks are built into prek.** The `pre-commit/pre-commit-hooks` clone is gone;
  the same checks run from `repo: builtin`. No network, no version to fall behind.
  gitleaks moved to v8.30.1. Why: pinned hook versions were a year old and nobody
  had noticed, which is exactly the kind of rot this backbone exists to prevent.
- **`just tools-update`** upgrades prek, graphify and the hook versions in one go.
  **`just backbone-news`** shows installed versus latest for every tool.
- **`just outdated`** in each language example, and Dependabot examples for Rust
  and Swift. `just doctor` points at `outdated` when it exists. Why: a maintainer
  who does not read Cargo.toml still needs to see "5 dependencies behind".
- **Specs before code.** `just spec <name>` creates a one-page spec in
  `docs/specs/` with a `status:` line. AGENTS.md gained two rules: spec first,
  docs follow code. Why: the idea is borrowed from OpenSpec; the tooling is not,
  because one file is enough.
- **Skills.** Three reusable skills in `.agents/skills/` (session, spec,
  backbone-update) in the SKILL.md open standard. Codex and Gemini CLI read that
  folder; Claude Code reads the links `just sync-rules` writes to `.claude/skills/`.
- **Version-aware update check.** `template-check` reports `0.2 -> 0.3`, not just
  a file count, and points here.
- **README rewritten** around what each folder is for: brain is your Obsidian
  vault, docs is what agents keep current, graphify-out is why they read less.
- **Weekly tool check.** `session-start` runs `backbone-news` once every seven
  days per machine, so a new prek or graphify release is seen within a week.
  Nothing updates on its own; the maintainer says "update", the agent runs
  `tools-update`. Why: weekly is what Dependabot and Renovate default to, and
  silent automatic upgrades are how a tool changes behaviour with nobody knowing.
- **SemVer.** Versions are `MAJOR.MINOR.PATCH` and git tags from now on.
- Backbone decisions are recorded here from now on, not as new ADRs. Projects
  own ADR numbers 0003 and up.

## 0.2.0 — 2026-09-13

- `just new-project <name>` creates a sibling project from the backbone.
- `doctor` checks for `uv`.
- Journal template takes its language from `brain_lang` in AGENTS.md.
- `update-map` matches graphify's real parser list and says so when nothing matches.

## 0.1.0 — 2026-09-12

- First version: AGENTS.md, Justfile with `ai-first.just` core, private `brain/`,
  public `docs/`, graphify map, prek hooks, `template-update` with a manifest.
