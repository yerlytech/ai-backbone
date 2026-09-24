# Examples

Copy-paste starting points. Nothing in this folder runs and nothing is imported.

## Language layers

The root `Justfile` ends with `import? 'stack.just'`. The question mark means
the file is optional, so the backbone works on its own. When you add a language,
you fill that slot.

| File | For |
|---|---|
| `stack-rust.just` | Rust and Cargo; a sqlx/PostgreSQL group you can delete; `server_dir` finds a root workspace; heavy recipes wait for a build already running; `clean-build` |
| `stack-swift.just` | Swift, SwiftUI, xcodegen, iOS |
| `stack-flutter.just` | Flutter and Dart: one app, or a pub workspace of apps and packages |
| `ci-rust.yml` | the checks GitHub runs on every push, for a Rust workspace on Linux |
| `ci-flutter.yml` | the same, for a Flutter workspace on Linux; it calls `just lint` and `just test` |
| `ci-generic.yml` | the part of that which is true in any language |
| `dependabot-rust.yml` | GitHub opens a pull request when a crate is behind |
| `dependabot-swift.yml` | same, for Swift packages |
| `dependabot-flutter.yml` | same, for pub.dev packages (Dart and Flutter) |

Each language layer has an `outdated` recipe. `just doctor` points at it when it
exists. `just ci-init` writes the Dependabot file for the language it finds,
and the workflow when one is ready for it: Swift gets the update bot today and
no workflow. Nothing in this folder is ever copied by hand.

The file names are the list. `just stack` alone prints the layers that are
here, `just doctor` offers the same ones, and `just ci-init` looks for
`ci-<language>.yml` and `dependabot-<language>.yml` under the name it found.
A new layer is a new file and no recipe changes. The one thing a name cannot
say is how to recognise the language in a folder (`Cargo.toml`,
`Package.swift`, `pubspec.yaml`); that is written in `ci-init`.

To use one:

```bash
just stack rust
just --list          # the new recipes appear next to the core ones
just ci-init rust    # and the same checks on every push
just ci              # how the last push went
```

Then edit `stack.just` until it fits. A recipe that takes an argument carries
`[positional-arguments]` and reads `$1`, never `{{arg}}` in its script —
`build-app` in `stack-swift.just` is the example.

## Two things only the language layer can tell `just doctor`

The backbone cannot know what a language keeps in the root or what it needs
installed, so `stack.just` says both, in two private recipes that print a line:

```just
# Root files the build needs there, so doctor does not call them strays.
_root-allow:
    @echo "pubspec.yaml pubspec.lock analysis_options.yaml"

# What must be on this machine: one line per tool, the command first, then
# where to get it. doctor lists them under "Language".
_stack-doctor:
    @echo "flutter  https://docs.flutter.dev/install"
    @echo "dart     comes with flutter"
```

Without `_stack-doctor`, a Mac with no Flutter on it read "Everything needed is
installed", and every save that touched code then failed in the lint hook with
"dart: command not found". With it, the missing SDK is a `MISS` line, and
doctor's ending sends nobody to `setup.sh` for it: `setup.sh` installs the
backbone's own tools and no language.

## A machine that builds several projects at once

Two IDE windows, an agent in a terminal: one machine often builds more than one
project. Two builds that share a folder wait on one lock without a word, two at
once can run a machine out of memory when they link, and a build folder grows
to hundreds of gigabytes with nothing saying so. The core handles all three for
any language whose layer says where its build goes, in one more private recipe,
one line per answer:

```just
_build-info:
    @echo "dir   target"              # the build folder, from the project root or absolute
    @echo "names cargo rustc"         # the programs a build runs, as the process list names them
    @echo "jobs  CARGO_BUILD_JOBS"    # the variable that caps a build's parallel jobs
    @echo "clean clean-build"         # the recipe that clears the folder
    @echo "set   CARGO_TARGET_DIR"    # the setting that put the folder elsewhere, if one did
```

- **Waiting.** A heavy recipe starts its build through the core's wait:
  `env $(just _build-wait) cargo test`. With a build already running on the
  machine it says so and waits (up to `BUILD_WAIT_MINUTES`, 20), then goes on
  with half the cores. With none, or where `ps` cannot list processes, it says
  nothing. `BUILD_WAIT_MINUTES=0` switches it off.
- **Size.** `just doctor` says when the folder is over `BUILD_OUTPUT_WARN_GB`
  (50), with the recipe that clears it. Measured in doctor only, bounded at a
  minute: a huge folder takes `du` minutes.
- **Shared.** `just doctor` says when the folder lies outside the project, what
  that costs and which line ends it. The backbone never moves a build folder:
  the IDE reads the same setting as the recipes, and moving it from `just`
  alone would build everything twice.

A layer with no `_build-info` is never measured and never waits. A
`_stack-advice` recipe prints doctor lines of the layer's own, as they are: the
Rust layer's says when dev builds keep full debug info. The Rust layer fills in
all of it, with a `clean-build` that asks before it deletes and refuses a
shared folder.

## Why these are examples and not a template

There is no universal setup for a language. Two projects here, same company,
same Rust stack, already disagree:

| | project A | project B |
|---|---|---|
| sqlx offline cache | none | 1490 files |
| `check` | plain `cargo check` | needs `SQLX_OFFLINE=true` |
| `test` | also runs the frontend tests | backend only |
| recipes | 16 | 9 |

A shared language template would have been wrong for one of them on day one.
An example you adapt is honest about that. A template pretending to be a
standard is not.

The Flutter example was not written ahead of a project either: the first
Flutter project here wrote its own layer, rewrote it when it became a workspace
of two apps and four packages, and only then was it lifted, with that project's
names taken out. What it carries from there: `dart test` for
a package that does not depend on Flutter, so a Flutter import in it fails the
run; `flutter analyze` rather than `dart analyze`, which exits 0 on an info; an
`outdated` that asks pub what an upgrade would move, because the list alone
printed an all-clear that was not true; a sentence where Flutter would have
printed a missing file; and no `test-fast`, because the whole suite took
seconds. Its header lists what it does not do yet, and the event that will
measure each one.

The Swift example carries a rule that is not general but is worth reading anyway:
version and build number live in `project.yml`, and when `GENERATE_INFOPLIST_FILE`
is off they must also appear in the `info: properties:` block or xcodegen writes
its own 1.0 / 1. That shipped the wrong build number twice before anyone noticed,
so the example includes a `check-versions` recipe that fails on it. The general
lesson: when a mistake has already cost you something, encode it as a recipe that
fails, not as a sentence in a document.

## The checks, and what a starter may assert

`ci-rust.yml` carries five things that cost a real project a day of red builds
in one afternoon. Four of them are *settings* — a concurrency group, a disk
step, two `CARGO_PROFILE` lines, one cargo flag — and a setting cannot fail on a
runner. It stops being there the moment somebody edits the file, and nothing
says so until the day it matters. That is why `just ci-check` exists and why
`just ci-init` puts it in front of every commit that touches the workflow: the
paragraph you are reading would otherwise be the only thing keeping them.

It asserts only what has been measured here, which is why every rule but the
concurrency one asks about cargo first. The disk lesson is a Linux runner with
seventeen Rust test binaries on it. Nobody here has run a Go build, a Gradle
build or a macOS runner, so `ci-check` says nothing about them — and there is no
`ci-swift.yml`, because writing a guess down as a starter is how a guess becomes
a fact nobody rechecks.

Flutter was checked against the same rules on 2026-09-23. Only the concurrency
rule applies to `ci-flutter.yml`, and it holds; the others ask about cargo and
say nothing. No Flutter rule was added: the one Flutter project here keeps
Actions off, so its workflow has not run on a runner yet, and what it carries
(one Linux job, a ten-minute cap, the Flutter pin read from the workspace
root, docs-only pushes skipped, the three actions pinned by commit) is written
in its comments rather than asserted. Its first run, read with `just ci`, is
the measurement. `ci-generic.yml` is what is left when only the measured
and the universal survive: when, what the job may touch, and which runs
supersede which. Its one step fails on purpose until you write the build, because
a starter that passed while checking nothing would mean "nobody has filled this
in yet" and read as green.

In a private repository a run is paid for out of the account's free minutes,
and nothing on GitHub says so until they are gone: one project here used
2,000 in two days. `just ci-init` says it once, in one sentence, unless GitHub
itself answers that the repository is public.

A lesson you mean to drop is waived in the workflow itself, in writing:

```yaml
# ci-check: skip no-fail-fast - one test binary here
```

`just ci-check` prints that line when it refuses. A rule you can get past is a
rule people keep; one they cannot is a rule they delete.
