# stack-swift.just — Swift, SwiftUI and xcodegen
#
# `just stack <lang>` copies this to the repo root as `stack.just`; the Justfile imports it.
#
#     just stack swift
#     just --list          # the new recipes appear alongside the core ones
#
# Everything below is a starting point, not a standard. It came out of a repo
# with three small iOS apps; expect to edit it.
#
# Where the app folders live, relative to the repo root. "." if they sit at the
# root, "apps" if they are grouped under a folder. The searches skip
# dot-directories so read-only clones under .references/ are never picked up.
games_dir := "."

# Two layers per game, and they are tested differently:
#   the engine is a plain Swift package  -> `swift test`, fast, no simulator
#   the app is an Xcode project          -> xcodebuild, needs a simulator

# ────────────────────────── projects ──────────────────────────

# Xcode projects are generated, never committed. Run this after adding a file.
[group('swift')]
gen:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v xcodegen >/dev/null 2>&1; then
      echo "xcodegen missing -> brew install xcodegen"; exit 1
    fi
    found=0
    while IFS= read -r y; do
      d="$(dirname "$y")"; echo "-- $d"; ( cd "$d" && xcodegen generate ); found=1
    done < <(find {{games_dir}} -name project.yml -not -path "*/.*" -not -path "*/build*/*" 2>/dev/null)
    if [ "$found" -eq 0 ]; then echo "No project.yml found."; fi

# ──────────────────────────── test ────────────────────────────

# The engines are pure Swift packages. No UI, no simulator, no Xcode.

# Run every engine package's tests
[group('swift')]
test:
    #!/usr/bin/env bash
    set -euo pipefail
    found=0
    while IFS= read -r p; do
      d="$(dirname "$p")"; echo "== $d"; ( cd "$d" && swift test ); found=1
    done < <(find {{games_dir}} -name Package.swift -not -path '*/.*' -not -path '*/build*/*' 2>/dev/null)
    if [ "$found" -eq 0 ]; then echo "No Swift package found."; fi

# ──────────────────────────── lint ────────────────────────────
#
# The pre-commit hook runs `just lint`, so this recipe is what stands between a
# commit and CI. `swift format` ships with the toolchain from Swift 6; older
# toolchains have the separate `swift-format` binary. SwiftLint is not part of
# any toolchain, so it runs only where the project has already chosen it, which
# a `.swiftlint.yml` says.

# Formatter and linter. Both must pass before a commit.
[group('swift')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    if swift format --version >/dev/null 2>&1; then
      fmt=(swift format)
    elif command -v swift-format >/dev/null 2>&1; then
      fmt=(swift-format)
    else
      echo "no formatter: Swift 6 ships one as \`swift format\`; before that, brew install swift-format"; exit 1
    fi
    found=0
    while IFS= read -r d; do
      echo "== $d"; "${fmt[@]}" lint --recursive --strict "$d"; found=1
    done < <(find {{games_dir}} \( -name Sources -o -name Tests \) -type d -not -path '*/.*' -not -path '*/build*/*' 2>/dev/null)
    if [ "$found" -eq 0 ]; then echo "No Sources or Tests folder found."; fi
    # A project that keeps a .swiftlint.yml has asked for SwiftLint as well.
    if [ -f .swiftlint.yml ]; then
      if ! command -v swiftlint >/dev/null 2>&1; then
        echo ".swiftlint.yml is here but swiftlint is not -> brew install swiftlint"; exit 1
      fi
      swiftlint lint --quiet --strict
    fi
    # Docs that name a path no longer here: a report, never a reason for lint to fail.
    just stale || true

# Build one app for the simulator. Catches what `swift test` cannot: the SwiftUI
# layer, asset catalogs, Info.plist keys.
#
# Usage: just build-app solball/Solball Solball

# Build one app scheme for the simulator
[group('swift')]
[positional-arguments]
build-app dir scheme:
    cd "$1" && xcodebuild -scheme "$2" \
      -destination 'platform=iOS Simulator,name=iPhone 16' \
      -quiet build

# ───────────────────────── release ─────────────────────────
#
# There is no one-command release recipe, on purpose. Archiving signs with a
# real certificate and uploads to App Store Connect; it should be typed
# deliberately, not triggered by a typo. The steps are in docs/02-release.md.
#
# One rule that has cost two shipped builds: version and build number live in
# project.yml, and when GENERATE_INFOPLIST_FILE is off they must appear in the
# `info: properties:` block as well. Otherwise xcodegen writes its own 1.0 / 1.

# Show the version and build number of every app
[group('release')]
versions:
    #!/usr/bin/env bash
    set -euo pipefail
    printf "%-30s %-10s %-7s %s\n" PROJECT VERSION BUILD PLIST
    while IFS= read -r y; do
      awk -v proj="$(dirname "$y")" '
        # comments never count as settings
        { line = $0; sub(/#.*/, "", line) }
        line ~ /MARKETING_VERSION:/        && v == "" { v = val(line) }
        line ~ /CURRENT_PROJECT_VERSION:/  && b == "" { b = val(line) }
        line ~ /GENERATE_INFOPLIST_FILE:/  && g == "" { g = val(line) }
        line ~ /CFBundleShortVersionString:/ { cfs = 1 }
        line ~ /CFBundleVersion:/            { cfv = 1 }
        function val(l,   t) { t = l; sub(/^[^:]*:[[:space:]]*/, "", t); gsub(/"/, "", t); gsub(/[[:space:]]+$/, "", t); return t }
        END {
          gen = (toupper(g) == "YES" || toupper(g) == "TRUE")
          state = gen ? "generated" : ((cfs && cfv) ? "explicit" : "MISSING")
          printf "%-30s %-10s %-7s %s\n", proj, (v == "" ? "?" : v), (b == "" ? "?" : b), state
        }
      ' "$y"
    done < <(find {{games_dir}} -name project.yml -not -path "*/.*" -not -path "*/build*/*" 2>/dev/null | sort)

# When GENERATE_INFOPLIST_FILE is off, MARKETING_VERSION alone does not reach the
# plist and xcodegen silently writes 1.0 / 1. This has shipped twice.

# Fail if a project.yml could ship the wrong build number
[group('release')]
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    bad=0
    while IFS= read -r y; do
      # grep finds nothing when the setting is absent; that is an answer, not an error
      gen=$(sed 's/#.*//' "$y" | grep -E 'GENERATE_INFOPLIST_FILE:' | head -1 | tr -d '" ' | cut -d: -f2 || true)
      case "$(printf '%s' "$gen" | tr '[:lower:]' '[:upper:]')" in
        YES|TRUE) continue ;;
      esac
      for k in CFBundleShortVersionString CFBundleVersion; do
        if ! sed 's/#.*//' "$y" | grep -q "$k"; then
          echo "MISSING  $k -> $y"; bad=1
        fi
      done
    done < <(find {{games_dir}} -name project.yml -not -path "*/.*" -not -path "*/build*/*" 2>/dev/null | sort)
    if [ "$bad" -eq 0 ]; then
      echo "ok  every project.yml either generates its plist or carries the version keys"
    else
      exit 1
    fi

# ──────────────────────── freshness ──────────────────────────

# Pinned package versions. SwiftPM has no "outdated" command; Dependabot fills that gap.
[group('swift')]
outdated:
    #!/usr/bin/env bash
    set -uo pipefail
    found=0
    while IFS= read -r r; do
      echo "-- $r"; found=1
      python3 - "$r" <<'PY'
    import json, sys
    d = json.load(open(sys.argv[1]))
    pins = d.get("pins") or d.get("object", {}).get("pins", [])
    for p in pins:
        st = p.get("state") or {}
        print("   %-32s %s" % (p.get("identity") or p.get("package"), st.get("version") or st.get("revision", "")[:7]))
    PY
    done < <(find {{games_dir}} -name Package.resolved -not -path "*/.*" -not -path "*/build*/*" 2>/dev/null)
    if [ "$found" -eq 0 ]; then echo "No Package.resolved found. No packages, nothing to be behind."; fi
    echo "SwiftPM cannot say what is newer. Dependabot can: just ci-init swift"

# The root files a Swift build needs there, so `just doctor` does not call them
# strays. Naming a file that is not there costs nothing.
_root-allow:
    @echo "Package.swift Package.resolved project.yml .swiftformat .swiftlint.yml"

# What this layer needs on the machine, so `just doctor` can say when it is not
# there: one line per tool, the command first, then where to get it.
_stack-doctor:
    @echo "swift     xcode-select --install, or Xcode from the App Store"
    @echo "xcodegen  brew install xcodegen"
