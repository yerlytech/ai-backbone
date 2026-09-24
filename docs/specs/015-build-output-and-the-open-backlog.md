---
status: done
date: 2026-09-23
---

# 015 — build output, and the open backlog

## What

Two things, and the second is the maintainer's own ask.

**A machine that builds several projects at once.** A person with two or three
IDE windows open, each on its own project, should not find one build silently
waiting on another, a machine running out of memory because three linkers
started together, or a build folder that has grown to hundreds of gigabytes
with nothing ever saying so. The backbone learns, in its language-neutral core,
to say how big a project's build output is and whether it is shared with other
projects, and to wait politely when another build is already running. The
language layer says where its build output lives, what its compiler is called,
and how to clean it. Rust is the first layer that fills those in.

**Nothing left waiting.** Every open line in `docs/backlog.md` ends this spec
done, closed with its reason, or open with `blocked:` and the one event that
would unblock it, re-checked today. It claims every line open on 2026-09-23 at
12:00 UTC except the two `- [?]` lines, which are the maintainer's to answer
and are brought to them, not built.

The maintainer approved the proposals behind the first part on 2026-09-23 in
the Yerly XL session ("önerdiğin tüm önerileri kabul ediyorum"), with one
condition that governs everything below: **the backbone is developed for any
person, on any project, in any IDE, on any operating system.** Nothing here may
assume a Mac.

## Why

Measured on the maintainer's machine on 2026-09-23 (Apple M5 Pro, 15 cores,
24 GB): two IDE windows on two Rust projects shared one `CARGO_TARGET_DIR`, so
each waited on the other's build lock without saying so; that folder had grown
to 335 GB (322 GB of it debug output, 129 GB of it incremental caches, 26
copies of one database engine, the oldest file from June), with 280 GB of disk
left; and on 2026-09-19 two heavy jobs at once ended in a Force Quit dialog.
Nothing in the backbone saw any of it.

And the backlog had seventeen open lines, several of them blocked on an event
that has since happened.

## Not doing

- **Moving build folders on the person's behalf.** The notes that started this
  (lines of 2026-09-23) proposed building into `<shared>/<project>` from the
  recipes. Two of their premises were wrong when measured: the Desktop they
  came from is not synced by any cloud drive (`FXICloudDriveDesktop` is 0, no
  other drive is mounted), and sccache's 0 hits out of 412 were counted while
  everything was already built — after a clean the same day, 1348 of 1934
  compile requests hit, so it does share. And a folder chosen inside `just` alone would
  split the IDE's own build (rust-analyzer reads the environment the IDE was
  started with) from the recipes' — every crate built twice. The honest fix is
  one line in the person's own shell setup, which is theirs to change, so
  `doctor` says what the shared folder costs and which line ends it.
- **Deleting build output.** The recipe that cleans exists; running it is the
  person's decision, every time.
- **A native Windows shell.** The backbone's recipes run in a POSIX shell
  (macOS, Linux, Windows through WSL). Everything added here stays inside what
  that shell and POSIX `ps` offer, and where a machine cannot answer a question
  — `ps` that cannot list processes, a folder that cannot be measured — the
  check says nothing and does not wait. It never blocks a person on a machine
  it cannot read. A native Windows shell would be its own spec.
- **Lines blocked on an event that has not happened:** the Swift CI starter
  and the lost-runner case of `just ci` (both need a real GitHub Actions run,
  and Actions is off), one Rust binary for the Python helpers (graphify is
  still Python), readers for Codex and Gemini transcripts (no project on this
  backbone uses either). Each is re-checked today and says so on its line.
- **The two `- [?]` lines** (a public template repository; GitHub Actions on
  this repository). The maintainer's, with the answer this backbone would give.

## Questions

None open. The maintainer approved the proposals on 2026-09-23.

The Flutter layer's lines were blocked on "the first real Flutter project's
first spec passes its acceptance list". Read on 2026-09-23: that project's spec
001 has five of six acceptance lines ticked — lint and test green, the Flutter
import guard, the desktop demo, iOS simulator and Android debug builds, adding a
game in its own folder — and the open one is the owner's verdict after playing
three matches, which says nothing about the tooling; its specs 003, 004 and 005
are done. The event the block was waiting for, a real project that has rewritten
its own `stack.just` under load, has happened. Lifted here.

## Acceptance

Every line is checked by `just self-test`, in a throwaway project, with the
tools it needs faked where the real ones would build something.

**Build output (backlog 2026-09-23 × 2)**

- [x] Core has a language-neutral helper that, before a heavy recipe, looks for
      a build already running (the names come from the language layer) and, if
      there is one, prints one line and waits for it to end, up to a limit
      (default 20 minutes, `BUILD_WAIT_MINUTES`). At the limit it goes ahead with
      half the machine's cores and says so. With no build running it returns at
      once and prints nothing. Where `ps` cannot list processes it returns at
      once and prints nothing. Measured in the self-test with a fake `ps`.
- [x] `doctor` reports a project's build output when it is larger than a limit
      (default 50 GB, `BUILD_OUTPUT_WARN_GB`): the size, and the one recipe that
      cleans it. Under the limit it says nothing. A layer that names no build
      folder is never measured.
- [x] `doctor` says when the build folder is shared with other projects, what
      that costs (one project's clean clears the others; two builds wait on one
      lock) and the line that ends it — and says it once, not on every
      recipe.
- [x] The Rust layer names its folder (`CARGO_TARGET_DIR`, or `target/`), its
      compiler (`cargo`, `rustc`), calls the wait helper from its heavy recipes
      (check, test, test-fast, lint, build), and has `clean-build`: it prints the
      size, cleans a folder that is this project's own, and refuses a shared
      one with the reason.
- [x] `doctor` suggests `debug = "line-tables-only"` for the dev profile when
      the project's `Cargo.toml` sets no debug level, the way the CI check
      already does for CI. It never writes the project's `Cargo.toml`.
- [x] The session skill says: before a long command, an agent checks for a
      build already running and waits for it rather than starting a second.
- [x] Nothing added here names a Mac, a Mac-only tool or a Mac-only path.

**The Flutter layer (backlog 2026-09-19 × 4, 2026-09-22 × 2)**

- [x] `examples/stack-flutter.just`, lifted from the first real Flutter
      project: pub workspaces (a workspace root with app folders apart from it;
      `get` and `analyze` at the root; `dart test` for the pure packages,
      `flutter test` per app); an app folder that is missing stops with a
      sentence, not a raw Flutter error, and `lint` stays quiet when there is
      no `pubspec.yaml` yet; `outdated` is `flutter pub outdated
      --no-transitive` plus a line for locked-but-movable packages; no
      `test-fast`; `flutter analyze`; the JDK lesson; a not-yet list in its
      header, each item tied to the event that will measure it.
- [x] `examples/ci-flutter.yml`: Ubuntu, `flutter-action` pinned by commit,
      `flutter-version-file` at the workspace root, `setup-just`, docs-only
      changes skipped, a ten-minute cap, the backbone's concurrency lines.
- [x] `just ci-init flutter` writes it and exits 0. It exits 1 today after
      writing dependabot, which breaks a script that chains it.
- [x] `examples/README.md` and the ci-check comment say Flutter was checked.

**The other ideas (backlog 2026-09-22 × 3, 2026-09-23 × 1)**

- [x] A reference may be a local folder with no remote: `ref-add` takes a path,
      `ref-fetch` skips it and says so, and the references README says a
      local-only entry is allowed.
- [x] `just stale`: every backticked repository path in `docs/`, `README*.md`,
      `AGENTS.md` and `src/*/README.md` that no longer exists, and every old
      name listed in `docs/renames.toml`, printed as `file:line`. A file whose
      Status line says it is amended is skipped. `lint` runs it and reports, and
      does not fail on it: a project updated today would otherwise find its
      lint red for lines it wrote months ago.
- [x] `just adr <name> --amends NNNN` writes the new ADR and adds the pointer
      line to the old one.
- [x] The seed pre-commit config carries a commented pre-push `just test` hook,
      and `hooks-install` installs the pre-push stage when the config has one.

**The backlog**

- [x] Every line open on 2026-09-23 is ticked with what was done, closed with
      its reason, or open with `blocked:` and a sentence saying what was
      re-checked on 2026-09-23. The two `- [?]` lines are untouched.
- [x] CHANGELOG entry, version 3.25.0, and the docs that describe any of this.

## Tasks

- [x] Save and publish this spec before building.
- [x] Build the three parts in three plain clones, each with `just self-test`
      green. Never a linked worktree (3.20.0).
      *Three agents, one clone each, then one reviewer each: 31 findings, two
      must-fix (clean-build measured one folder and cleared another; one app in
      src/<name> passed every save unread), fifteen should-fix, the rest nits.
      Every must- and should-fix was checked against the code, fixed with a
      test, and each test proven red with its fix taken out. 482 checks on the
      merged tree.*
- [x] An adversarial review of each part: one reader per part, looking for
      anything that assumes one operating system, anything that can block a
      person where it cannot measure, anything that writes a project-owned
      file, and any `{{arg}}` spliced into a script.
- [x] Merge, fix what survived review, CHANGELOG, version, backlog lines, docs.
- [x] `just self-test`, save, publish; bring the maintainer's copy level.
      *Published as 3.25.0 (tag `v3.25.0`) on 2026-09-23; the maintainer's copy
      pulled level. The projects take it from their own session-start.*
