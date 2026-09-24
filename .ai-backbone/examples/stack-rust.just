# stack-rust.just — Rust and Cargo; the database group is sqlx and PostgreSQL, delete it on another database
#
# `just stack <lang>` copies this to the repo root as `stack.just`; the Justfile imports it.
#
#     just stack rust
#     just --list          # the new recipes appear alongside the core ones
#
# Everything below is a starting point, not a standard. Expect to edit it.
# Two projects on the same stack already disagree about half of these choices:
# the first project on this backbone runs SurrealDB with its workspace at the
# root, and rewrote this header to say so.

# Where the Cargo workspace lives. A Cargo.toml in the root means the root;
# otherwise `server`. Set it by hand when neither is right. just looks beside
# the Justfile, so the answer is the same from any folder of the project.
server_dir := if path_exists("Cargo.toml") == "true" { "." } else { "server" }

# Uncomment ONLY if you commit a .sqlx offline query cache.
# With it, `cargo check` works with no database running.
# Without it, every check and test needs a live PostgreSQL.
# export SQLX_OFFLINE := "true"

# ─────────────────────────── build ───────────────────────────
# check, test, test-fast, lint and build start cargo through
# `env $(just _build-wait)`. When another build is already running on this
# machine, in this project or another, it says so and waits for it to finish;
# after BUILD_WAIT_MINUTES (20) it goes on with half the cores, by handing `env`
# a CARGO_BUILD_JOBS. Otherwise it prints nothing and cargo runs as always.
# Two builds that share a folder wait on one lock anyway, and two at once on a
# machine with little memory can run it out at link time. BUILD_WAIT_MINUTES=0
# switches it off. Put a recipe of your own that compiles through it too.

# Run the backend locally
[group('rust')]
dev:
    cd {{server_dir}} && cargo run

# Fast type check. No tests, no codegen.
[group('rust')]
check:
    cd {{server_dir}} && env $(just _build-wait) cargo check --workspace --all-targets

# Unit tests only. Database tests are separate, see test-db.
[group('rust')]
test:
    cd {{server_dir}} && env $(just _build-wait) cargo test --workspace

# Formatter and linter. Both must pass before a commit. The last line reports
# docs that name a path no longer here; the leading - keeps it from failing lint.
[group('rust')]
lint:
    cd {{server_dir}} && env $(just _build-wait) cargo clippy --workspace --all-targets -- -D warnings
    cd {{server_dir}} && cargo fmt --check
    -@just stale

# `just lint` prints a diff and does not say how to apply it, and
# `cargo fmt -p <crate>` prints cargo-fmt's help instead of formatting; a
# contributor lost an hour to that.

# Apply the formatting that `just lint` only checks
[group('rust')]
fmt:
    cd {{server_dir}} && cargo fmt --all

# Doctests compile every ``` block in the tree: in the first project they were
# 28 of the suite's 37 seconds, and this is the 9 that are left. Lint catches
# what clippy catches, not a rule that stopped being true; a red test reached
# three commits in one day there while the hook ran lint alone. A project that
# wants this before every commit adds a hook with `entry: just test-fast` to its
# own .pre-commit-config.yaml, as that one did.

# The tests without the doctests: quick enough to run before a commit
[group('rust')]
test-fast:
    cd {{server_dir}} && env $(just _build-wait) cargo test --workspace --lib --bins --tests

# Release build
[group('rust')]
build:
    cd {{server_dir}} && env $(just _build-wait) cargo build --release

# ──────────────────────── build output ───────────────────────
# Where cargo writes, for `just doctor` and the wait above (spec 015). A Rust
# build folder grows with every build and nothing clears it: one that several
# projects shared had reached 335 GB. doctor says when this one is over
# BUILD_OUTPUT_WARN_GB (50) and when it is shared with other projects.

# What the backbone's core asks of this layer, one line per answer. The folder
# is CARGO_TARGET_DIR when that is set (read from server_dir, where cargo runs,
# when it is relative), else target/ in the workspace. A target-dir set in a
# .cargo/config.toml is not read here: add it as the dir line if you use one.
_build-info:
    #!/usr/bin/env bash
    # Cargo's own answer first. `cargo metadata` finds the build folder the way
    # every cargo command does — CARGO_TARGET_DIR, CARGO_BUILD_TARGET_DIR, a
    # `[build] target-dir` in any .cargo/config.toml from here up — and builds
    # nothing. Reading only the variables named a folder cargo was not using
    # whenever a config file chose it, and clean-build measured one folder and
    # cleared another (spec 015 review).
    d=""; meta=""
    if command -v cargo >/dev/null 2>&1; then
      meta=$(cd {{server_dir}} 2>/dev/null && cargo metadata --no-deps --format-version 1 2>/dev/null)
      d=$(printf '%s' "$meta" | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p' | head -n 1)
    fi
    # On Windows cargo answers C:\\x in its JSON and the variables hold C:\x or
    # C:/x; the checks below read paths the way Git Bash writes them (spec 020).
    posix() { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$(printf '%s' "$1" | sed 's/\\\\/\\/g')"; else printf '%s' "$1"; fi; }
    [ -z "$d" ] || d=$(posix "$d")
    by=""
    if [ -n "${CARGO_TARGET_DIR:-}" ]; then by=CARGO_TARGET_DIR
    elif [ -n "${CARGO_BUILD_TARGET_DIR:-}" ]; then by=CARGO_BUILD_TARGET_DIR; fi
    if [ -z "$d" ]; then
      # No cargo, or a manifest it cannot read: the variables, as cargo reads them.
      d="${CARGO_TARGET_DIR:-${CARGO_BUILD_TARGET_DIR:-}}"
      if [ -z "$d" ]; then d="{{server_dir}}/target"; else d=$(posix "$d"); case "$d" in /*) ;; *) d="{{server_dir}}/$d" ;; esac; fi
    fi
    echo "dir   $d"
    [ -z "$by" ] || echo "set   $by"
    # Chosen by a config file rather than a variable: say which kind of line to
    # change, since removing a variable nobody set would end nothing.
    if [ -z "$by" ] && [ -n "$meta" ] && [ "$d" != "$(cd {{server_dir}} 2>/dev/null && pwd -P)/target" ]; then
      echo "from  the [build] target-dir line in a .cargo/config.toml (this folder, one above it, or CARGO_HOME)"
    fi
    echo "names cargo rustc"
    echo "jobs  CARGO_BUILD_JOBS"
    echo "clean clean-build"

# Clearing it is the person's decision, every time: this asks, the way `just
# undo` asks, and an agent passes on the person's own yes and nothing else
# (printf 'y\n' | just clean-build). A folder other projects build into too is
# refused: cargo clean there clears every project's builds.

# Clear this project's build output, after saying how big it is (asks first)
[group('rust')]
clean-build:
    #!/usr/bin/env bash
    set -uo pipefail
    dir=""; by=""
    while read -r k v; do
      case "$k" in dir) dir="$v" ;; set) by="$v" ;; esac
    done <<< "$(just _build-info)"
    if [ ! -d "$dir" ]; then echo "Nothing to clear: no build output at $dir yet."; exit 0; fi
    echo "Measuring $dir ..."
    read -r kb size <<< "$(just _build-size "$dir" 120)"
    echo "Build output: ${size:-more than two minutes to measure, so very large}, in $dir"
    if [ -n "$(just _build-shared "$dir")" ]; then
      echo "Not cleared. This folder is outside the project${by:+ ($by)}, where other projects can build"
      echo "too: if they do, cargo clean would clear their builds as well, and each would build again from nothing."
      if [ -n "$by" ]; then
        echo "Instead, give each project a folder of its own: remove the line that sets $by from your"
        echo "shell setup (.zshrc, .bashrc, .profile, config.fish, an .envrc: wherever it is set), open"
        echo "a new terminal and restart the IDE. This project then builds into its own target/, which"
        echo "this recipe can clear."
      else
        echo "Instead, point the build folder back inside this project; this recipe can clear that."
      fi
      echo "Clearing the shared folder for every project at once is a decision for whoever owns them"
      echo "all, taken by hand when nothing is building: cargo clean, in any one of them."
      exit 1
    fi
    printf '%s' "$(just _msg clean-build-confirm)"
    read -r a || { a=""; echo; }
    case "$a" in
      # The folder that was measured and named, and no other: cargo is told it
      # rather than left to work it out a second time.
      y|Y|e|E) cd {{server_dir}} && cargo clean --target-dir "$dir" && echo "Cleared." ;;
      *)       echo "Nothing deleted." ;;
    esac

# What doctor says about this project, printed as it is, in doctor's columns.
# The debug-info lesson ci-check carries for CI, said for this machine: a dev
# build that keeps the full map for a debugger writes what nobody reads on most
# days. Measured against debug = 1 (a machine-wide ~/.cargo/config.toml had set
# it), it was about a tenth of a build; against the default, full debug info,
# it is more and was not measured. What fills a disk is builds that are never
# cleared, which doctor says separately. Any debug level the project sets for dev is its decision and
# ends the question, `debug = true` too. Cargo.toml is never written here.
_stack-advice:
    #!/usr/bin/env bash
    toml="{{server_dir}}/Cargo.toml"; toml="${toml#./}"
    [ -f "$toml" ] || exit 0
    [ -z "${CARGO_PROFILE_DEV_DEBUG:-}" ] || exit 0
    sets_debug() {
      awk '
        { line = $0; sub(/#.*/, "", line) }
        line ~ /^[ \t]*\[/ { sect = line; gsub(/[ \t]/, "", sect); next }
        sect == "[profile.dev]" && line ~ /^[ \t]*debug[ \t]*=/ { found = 1 }
        sect == "[profile]" && line ~ /^[ \t]*dev\.debug[ \t]*=/ { found = 1 }
        sect == "" && line ~ /^[ \t]*profile\.dev\.debug[ \t]*=/ { found = 1 }
        END { exit !found }' "$1" 2>/dev/null
    }
    [ -f "$toml" ] && sets_debug "$toml" && exit 0
    # Cargo reads a .cargo/config.toml (or the older .cargo/config) in the
    # project's folder and in every folder above it, then CARGO_HOME's. A level
    # set in any of them is the project's decision.
    d=$(cd {{server_dir}} 2>/dev/null && pwd -P) || d=""
    while [ -n "$d" ]; do
      for f in "$d/.cargo/config.toml" "$d/.cargo/config"; do [ -f "$f" ] && sets_debug "$f" && exit 0; done
      [ "$d" = / ] && break
      d=$(dirname "$d")
    done
    for f in "${CARGO_HOME:-$HOME/.cargo}/config.toml" "${CARGO_HOME:-$HOME/.cargo}/config"; do
      [ -f "$f" ] && sets_debug "$f" && exit 0
    done
    echo "  info  dev builds keep full debug info: $toml sets no debug level for [profile.dev]"
    echo "        Debug info is a map for a debugger, and most days nobody attaches one. Keeping"
    echo "        only the line numbers a panic prints made one workspace's full test build a"
    echo "        tenth smaller than debug = 1 did (9.8 GB to 8.6 GB, measured 2026-09-23), and"
    echo "        full debug info, cargo's default, is larger than that. Free, in $toml:"
    echo "          [profile.dev]"
    echo "          debug = \"line-tables-only\""
    echo "        Want the full map? Write debug = true there, and this stops asking."

# The version in the Cargo.toml the workspace reads, so that the program says
# what the tag says (spec 016): `just release` calls this. [workspace.package]
# when the workspace has a version there, else the root [package]; members that
# write `version.workspace = true` follow. Cargo.lock names the workspace's own
# versions too, and is brought along offline; where that cannot be done here,
# the next build does it.
[positional-arguments]
_set-version version:
    #!/usr/bin/env bash
    set -euo pipefail
    toml="{{server_dir}}/Cargo.toml"; toml="${toml#./}"
    [ -f "$toml" ] || exit 0
    t=$(mktemp)
    V="$1" awk '
      NR == FNR { if ($0 ~ /^[ \t]*\[/) { s = $0; gsub(/[ \t]/, "", s) }
                  if (s == "[workspace.package]" && $0 ~ /^[ \t]*version[ \t]*=/) ws = 1
                  next }
      /^[ \t]*\[/ { s = $0; gsub(/[ \t]/, "", s) }
      !done && ((ws && s == "[workspace.package]") || (!ws && s == "[package]")) && /^[ \t]*version[ \t]*=/ {
        sub(/"[^"]*"/, "\"" ENVIRON["V"] "\""); done = 1 }
      { print }' "$toml" "$toml" > "$t"
    cat "$t" > "$toml"; rm -f "$t"
    if command -v cargo >/dev/null 2>&1 && [ -f "{{server_dir}}/Cargo.lock" ]; then
      ( cd {{server_dir}} && cargo update --workspace --offline --quiet ) >/dev/null 2>&1 \
        || echo "Cargo.lock takes the new version at the next build."
    fi

# ───────────────────────── database ──────────────────────────
# sqlx and PostgreSQL. On another database, delete this group.

# Run integration tests against a throwaway PostgreSQL
[group('db')]
test-db:
    # Needs DATABASE_URL and a role with CREATEDB permission.
    cd {{server_dir}} && cargo test --features db-tests --test db_integration

# Apply pending migrations to the dev database
[group('db')]
migrate:
    cd {{server_dir}} && sqlx migrate run

# Rebuild the .sqlx offline cache after a schema change
[group('db')]
sqlx-prepare:
    # Commit the result, or CI fails for everyone else.
    cd {{server_dir}} && cargo sqlx prepare --workspace

# ────────────────────────── contract ─────────────────────────

# Generate TypeScript types from the Rust DTOs (ts-rs)
[group('rust')]
gen-types:
    # Adjust the crate name and the test filter to match your project.
    cd {{server_dir}} && cargo test -p core --tests export_bindings_

# ─────────────────────────────────────────────────────────────
# Also add these to the repo root, outside this file:
#
#   .gitignore          target/
#                       *.rs.bk
#
#   .graphifyignore     **/target/
#                       **/.sqlx/          (thousands of generated json files)
#                       **/bindings/
#
#   rust-toolchain.toml
#     [toolchain]
#     channel = "stable"
#
# The git hooks already run `just lint` before every commit: `just stack rust`
# put that hook in .pre-commit-config.yaml. Nothing to copy by hand. Change what
# lint runs by editing the recipe above; the hook follows.

# ──────────────────────── freshness ──────────────────────────

# Which crates are behind. Needs cargo-outdated once: cargo install cargo-outdated
[group('rust')]
outdated:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! cargo outdated --version >/dev/null 2>&1; then
      echo "cargo-outdated missing -> cargo install cargo-outdated"; exit 1
    fi
    cd {{server_dir}} && cargo outdated --root-deps-only
    echo "To have GitHub open the update PRs for you: just ci-init rust"

# The root files Cargo needs there, so `just doctor` does not call them strays.
# Only matters when the workspace is at the root rather than in `server_dir`;
# naming a file that is not there costs nothing.
_root-allow:
    @echo "Cargo.toml Cargo.lock rust-toolchain.toml deny.toml clippy.toml rustfmt.toml"

# What this layer needs on the machine, so `just doctor` can say when it is not
# there: one line per tool, the command first, then where to get it.
_stack-doctor:
    @echo "cargo  https://rustup.rs"
