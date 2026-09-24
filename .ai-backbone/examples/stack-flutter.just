# stack-flutter.just — Flutter and Dart: one app, or a pub workspace of apps and packages
#
# `just stack <lang>` copies this to the repo root as `stack.just`; the Justfile imports it.
#
#     just stack flutter
#     just --list          # the new recipes appear alongside the core ones
#
# Everything below is a starting point, not a standard. It was lifted from the
# first Flutter project on this backbone after that project had rewritten its
# own copy under load: two apps and four packages in one pub workspace, linted
# on every save and tested before every push (Flutter 3.47.5, Dart 3.13.4,
# September 2026). Expect to edit it.
#
# Where the code lives. The recipes tell the three shapes apart on their own;
# only the recipes about one app need telling which app, in a workspace:
#
#   one app            `flutter create --project-name my_app src` (code lives
#                      in src/ on this backbone). src/pubspec.yaml is the app,
#                      and `app` below stays empty.
#   a pub workspace    src/pubspec.yaml holds no code: the Flutter pin and a
#                      `workspace:` list of members. Each app and package is a
#                      folder beside it, src/<name>/, with `resolution:
#                      workspace` in its own pubspec.yaml; there is one lock
#                      file, at the root. `get`, `lint` and `test` cover every
#                      member from the root. The recipes about one app (run,
#                      the builds, clean) use `app`: set it below, and
#                      `just app=<name> run` picks another for one command.
#   at the root        pubspec.yaml beside the Justfile. `ws_dir` is then "."
#                      and `_root-allow` names what Flutter keeps there.
#   one app in         `flutter create src/mobile`, one part among others
#     src/<name>       (src/web, src/server). Set `app := "mobile"` below and
#                      the app's folder is the workspace. Left unset, every
#                      recipe stops and says so: a lint that answered "nothing
#                      to lint yet" over an app it could not find passed every
#                      save unread (spec 015 review).
#
# Pin the Flutter SDK exactly, once: `flutter: 3.47.5` (your version) under
# `environment:` in the workspace root's pubspec.yaml, and in no member. pub
# then refuses any other SDK for every member: after a `flutter upgrade`, every
# recipe here, and the lint hook with it, stops with "requires Flutter SDK
# version 3.47.5, version solving failed". That is the pin working. Moving to a
# new SDK is one save: that line, then `just lint` and `just test`. The checks
# on GitHub read the same line (`just ci-init flutter`), and they can only read
# an exact version, never a range.
#
# Not here yet, each until the event that will measure it:
#
#   release signing       the first store build a project on this backbone signs
#                         for real
#   store upload          the first upload to TestFlight or a Play testing track
#   a build-number bump   the second upload, when a store refuses a build number
#                         it has already seen
#   flavors               the first project that needs two builds of one app (the
#                         first one here chose two apps in one workspace instead)
#   device integration    integration_test/ on a simulator, an emulator or a
#     tests               phone: run by hand on one machine so far, here once a
#                         second machine has run them
#   golden tests          a picture drawn on one operating system fails on
#                         another (the fonts differ): here once one set passes
#                         on two
#   the Dart SDK's own    it runs the app and changes files, so what it may do
#     MCP server          is the maintainer's decision first
#   a toolchain line in   the Flutter on the machine against the pin: it changes
#     doctor              a command the person types, so it waits for their yes
#   the build-output      which folder a Flutter build fills and which programs
#     checks (spec 015)   are its compiler, so doctor can say how big it is and
#                         a heavy recipe can wait for another build: the first
#                         time a Flutter build's size is measured on a machine
#                         building two projects at once

# The app that run, the builds and clean use: a folder under ws_dir, or, in the
# one-app-in-src/<name> shape, src/<name> itself. Empty means the workspace root
# is itself the app.
app := ""

# The members that must never depend on Flutter, by name: `pure := "core rules"`.
# Each always runs under `dart test`, and lint and test stop if its
# pubspec.yaml names the Flutter SDK. Without this list purity is read from the
# pubspec.yaml itself, and the one edit that breaks it — adding Flutter to a
# pure package — would also quietly move its tests to `flutter test`, so the
# gate would switch itself off (spec 015 review). The project this was lifted
# from named its pure packages for exactly that reason.
pure := ""

# The workspace root: the folder whose pubspec.yaml holds the pin. The root of
# the repository when a pubspec.yaml is there, then src/, then src/<app> when
# the one app lives there. Set it by hand when none is right. just looks beside
# the Justfile, so the answer is the same from any folder of the project.
ws_dir := if path_exists("pubspec.yaml") == "true" { "." } else if path_exists("src/pubspec.yaml") == "true" { "src" } else if app == "" { "src" } else if path_exists("src/" + app + "/pubspec.yaml") == "true" { "src/" + app } else { "src" }
app_dir := if app == "" { ws_dir } else if ws_dir == "src/" + app { ws_dir } else { ws_dir / app }

# ─────────────────────────── build ───────────────────────────

# A project that generates code on every fetch (`flutter gen-l10n`,
# build_runner) adds that line here, after the fetch.

# Fetch the packages every member asks for: one lock file, at the workspace root
[group('flutter')]
get:
    #!/usr/bin/env bash
    set -euo pipefail
    ws={{quote(ws_dir)}}
    case "$(just _ws-state "$ws")" in
      ready) ;;
      none) echo "There is no pubspec.yaml in $ws/ yet, so there is nothing to fetch."
            echo "Make the app first: flutter create --project-name <name> $ws"
            exit 1 ;;
      *) exit 1 ;;
    esac
    just _need-flutter 2>/dev/null || exit 1
    cd "$ws" && flutter pub get

# With no device named, Flutter asks which one. `just devices` lists them.

# Run the app on a simulator, an emulator, a phone, this computer or a browser
[group('flutter')]
[positional-arguments]
run device="":
    #!/usr/bin/env bash
    set -euo pipefail
    d=$(just _app {{quote(app_dir)}} {{quote(ws_dir)}}); if [ -z "$d" ]; then exit 1; fi
    just _need-flutter 2>/dev/null || exit 1
    cd "$d"
    if [ -n "${1:-}" ]; then flutter run -d "$1"; else flutter run; fi

# What `just run` can run on
[group('flutter')]
devices:
    @just _need-flutter 2>/dev/null && flutter devices

# ──────────────────────────── test ────────────────────────────
#
# `flutter test` runs Dart in the computer's own VM: no simulator, no phone. It
# took one to four seconds a package where this was measured, so there is no
# test-fast here: the whole suite is already quick enough for every push.
#
# A package whose pubspec.yaml does not depend on Flutter is tested with `dart
# test`, never `flutter test`: a Flutter import that slips into it then fails
# the run instead of passing in silence, which is how a package stays pure (a
# server can compile it without Flutter). Everything else runs `flutter test`,
# once per app and per Flutter package. A package that holds both kinds of test
# splits them itself (`dart test test/pure_test.dart` beside `flutter test
# test/widget_test.dart`) and gets a line of its own here.
#
# Every member runs even after one fails, and the end names the ones that
# failed: stopping at the first tells you about one defect a run.

# The unit and widget tests of every member
[group('flutter')]
test:
    #!/usr/bin/env bash
    set -uo pipefail
    ws={{quote(ws_dir)}}
    case "$(just _ws-state "$ws")" in
      ready) ;;
      none) echo "No pubspec.yaml in $ws/ yet: no tests to run."; exit 0 ;;
      *) exit 1 ;;
    esac
    just _need-flutter 2>/dev/null || exit 1
    members=$(just _members "$ws") || exit 1
    just _pure-check "$ws" {{quote(pure)}} || exit 1
    pure=" "{{quote(pure)}}" "
    cd "$ws" || exit 1
    ran=0; failed=""
    while IFS= read -r m; do
      if [ -z "$m" ] || [ ! -d "$m/test" ]; then continue; fi
      ran=1
      name="$ws/$m"; if [ "$m" = . ]; then name="$ws"; fi
      # A test run that reads its input would eat the rest of this list. A
      # member named in `pure` runs dart test whatever its pubspec.yaml says:
      # _pure-check above has already stopped the run if it names Flutter.
      if [ "${pure#* $m }" = "$pure" ] && grep -qE "^[^#]*sdk:[[:space:]]*[\"']?flutter" "$m/pubspec.yaml"; then
        echo "== $name (flutter test)"; ( cd "$m" && flutter test ) </dev/null || failed="$failed $name"
      else
        echo "== $name (dart test)"; ( cd "$m" && dart test ) </dev/null || failed="$failed $name"
      fi
    done <<< "$members"
    if [ "$ran" -eq 0 ]; then echo "No member has a test/ folder yet."; exit 0; fi
    if [ -n "$failed" ]; then echo; echo "Failed:$failed"; exit 1; fi

# ──────────────────────────── lint ────────────────────────────
#
# `flutter analyze`, never `dart analyze`: flutter analyze fails on infos and
# warnings as well as errors (measured on Flutter 3.47.5), so a lint the
# analyzer only mentions still stops a commit, while dart analyze exits 0 on an
# info. One run at the workspace root covers every member (1.2 s for two apps
# and three packages where it was measured).
#
# The format check names every member's Dart folders rather than `.`: `dart
# format .` walks into build/ and ios/Flutter/ephemeral/ (Dart 3.13.4).
#
# With no pubspec.yaml yet it says so and passes. The lint hook runs it before
# every save, and a save between `just stack flutter` and `flutter create` must
# not stop over an app that does not exist yet.

# Formatter and analyzer over every member. Both must pass before a commit.
[group('flutter')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    ws={{quote(ws_dir)}}
    case "$(just _ws-state "$ws")" in
      ready) ;;
      none) echo "No pubspec.yaml in $ws/ yet: nothing to lint."; exit 0 ;;
      *) exit 1 ;;
    esac
    just _loose-builds "$ws" || exit 1
    just _pure-check "$ws" {{quote(pure)}} || exit 1
    just _need-flutter 2>/dev/null || exit 1
    found=$(just _dart-dirs "$ws") || exit 1
    dirs=()
    while IFS= read -r d; do if [ -n "$d" ]; then dirs+=("$d"); fi; done <<< "$found"
    cd "$ws"
    if [ ${#dirs[@]} -gt 0 ]; then dart format --output=none --set-exit-if-changed "${dirs[@]}"; fi
    flutter analyze
    cd - >/dev/null
    # Docs that name a path no longer here: a report, never a reason for lint
    # to fail, and only where the backbone's core provides it.
    if just --summary 2>/dev/null | tr ' ' '\n' | grep -qx stale; then just stale || true; fi

# Apply the formatting that `just lint` only checks
[group('flutter')]
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    ws={{quote(ws_dir)}}
    case "$(just _ws-state "$ws")" in
      ready) ;;
      none) echo "No pubspec.yaml in $ws/ yet: nothing to format."; exit 0 ;;
      *) exit 1 ;;
    esac
    just _need-flutter 2>/dev/null || exit 1
    found=$(just _dart-dirs "$ws") || exit 1
    dirs=()
    while IFS= read -r d; do if [ -n "$d" ]; then dirs+=("$d"); fi; done <<< "$found"
    cd "$ws"
    if [ ${#dirs[@]} -gt 0 ]; then dart format "${dirs[@]}"; fi

# ──────────────────────────── builds ───────────────────────────
#
# The tests and the analyzer run in the Dart VM and never touch Xcode or
# Gradle. These two do, and catch what they cannot: a plugin's native code, an
# Info.plist or AndroidManifest key, a Gradle or CocoaPods version clash. Debug
# builds, unsigned: nothing here needs a certificate. A Gradle build installs
# the Android SDK parts it is missing into the SDK folder outside this
# repository without asking (126 MB once, in another project here), so it is
# run by a person who is watching, never by an agent to see what happens.
#
# Measured on 2026-09-19 (Flutter 3.47.5, Android Gradle Plugin 9.1.0, Gradle
# 9.3.1): with only a JDK 26 on the machine, `flutter doctor` said "No issues
# found!" and the first APK build died in jlink. Flutter's own hint blamed an
# Android Gradle Plugin older than 8.2.1, which that project did not have. A JDK
# 21, handed to Flutter with `flutter config --jdk-dir`, fixed it. The recipe
# says so when it sees the same death, so nobody chases the wrong hint.

# Build the Android app (debug APK)
[group('flutter')]
build-android:
    #!/usr/bin/env bash
    set -uo pipefail
    d=$(just _app {{quote(app_dir)}} {{quote(ws_dir)}}); if [ -z "$d" ]; then exit 1; fi
    just _need-flutter 2>/dev/null || exit 1
    cd "$d" || exit 1
    log=$(mktemp); trap 'rm -f "$log"' EXIT
    flutter build apk --debug 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    if [ "$status" -ne 0 ] && grep -q jlink "$log"; then
      echo
      echo "The build died in jlink: the JDK Flutter uses is newer than Android's tools accept."
      echo "Ignore the Android Gradle Plugin hint above. Point Flutter at a JDK 21:"
      echo "  flutter config --jdk-dir=\"<JDK 21 home>\"   (flutter doctor -v shows which JDK it uses now)"
    fi
    exit "$status"

# Build the iOS app for the simulator. Only a Mac with Xcode can.
[group('flutter')]
build-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname -s)" != Darwin ]; then
      echo "An iOS build needs macOS with Xcode, and this machine runs $(uname -s)."
      echo "The Android build works here: just build-android"
      exit 1
    fi
    d=$(just _app {{quote(app_dir)}} {{quote(ws_dir)}}); if [ -z "$d" ]; then exit 1; fi
    just _need-flutter 2>/dev/null || exit 1
    cd "$d" && flutter build ios --simulator --debug

# Delete this app's build output. The next flutter command fetches what it needs.
[group('flutter')]
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    d=$(just _app {{quote(app_dir)}} {{quote(ws_dir)}}); if [ -z "$d" ]; then exit 1; fi
    just _need-flutter 2>/dev/null || exit 1
    cd "$d" && flutter clean

# ───────────────────────── release ─────────────────────────
#
# There is no one-command release recipe, on purpose. A store build signs with a
# real certificate or keystore and uploads; it should be typed deliberately, not
# triggered by a typo.
#
# An app's version lives in one place: `version: 1.2.3+45` in its pubspec.yaml,
# where 1.2.3 is what people see and 45 is the build number the stores count.
# iOS reads it through $(FLUTTER_BUILD_NAME) and $(FLUTTER_BUILD_NUMBER) in
# Info.plist, Android through flutter.versionName and flutter.versionCode in
# build.gradle(.kts). A number typed into either file by hand wins over
# pubspec.yaml in silence, and a Swift project on this backbone shipped the
# wrong build number twice that way. check-versions fails on it. Both recipes
# look at every app in the workspace: a folder with an ios/ or android/ in it.

# Show the version and build number of every app, from its pubspec.yaml
[group('release')]
versions:
    #!/usr/bin/env bash
    set -uo pipefail
    ws={{quote(ws_dir)}}
    found=0
    while IFS= read -r p; do
      if [ -z "$p" ]; then continue; fi
      if [ "$found" -eq 0 ]; then printf '%-28s %-10s %s\n' APP VERSION BUILD; fi
      found=1
      # comments never count as settings
      v=$(sed -n 's/^version:[[:space:]]*//p' "$p/pubspec.yaml" | sed 's/[[:space:]]#.*//' | tr -d "\"' \r")
      if [ -z "$v" ]; then printf '%-28s %s\n' "$p" "pubspec.yaml has no version line"; continue; fi
      b='? (no +N)'; if [ "$v" != "${v#*+}" ]; then b="${v#*+}"; fi
      printf '%-28s %-10s %s\n' "$p" "${v%%+*}" "$b"
    done < <(just _apps "$ws")
    if [ "$found" -eq 0 ]; then echo "No app with an ios/ or android/ folder in $ws/ yet."; fi

# Fail if iOS or Android could ship a version other than pubspec.yaml's
[group('release')]
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    ws={{quote(ws_dir)}}
    bad=0; checked=""
    while IFS= read -r app; do
      if [ -z "$app" ]; then continue; fi
      plist="$app/ios/Runner/Info.plist"
      if [ -f "$plist" ]; then
        checked="$checked $app:iOS"
        for k in 'CFBundleShortVersionString:FLUTTER_BUILD_NAME' 'CFBundleVersion:FLUTTER_BUILD_NUMBER'; do
          key=${k%%:*}; var=${k#*:}
          # The value is the <string> on the line after its <key>.
          val=$(grep -A1 "<key>$key</key>" "$plist" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1 || true)
          if [ "$val" != "\$($var)" ]; then echo "HAND-SET  $key = '${val:-missing}' in $plist (want \$($var))"; bad=1; fi
        done
      fi
      gradle=""
      for g in "$app/android/app/build.gradle.kts" "$app/android/app/build.gradle"; do
        if [ -f "$g" ]; then gradle="$g"; break; fi
      done
      if [ -n "$gradle" ]; then
        checked="$checked $app:Android"
        # Every assignment counts, not the first: a flavor block can set its own.
        # flutterVersionCode is the template of Flutter 3.22 and earlier; it reads
        # pubspec.yaml too.
        for kk in 'versionCode:flutterVersionCode' 'versionName:flutterVersionName'; do
          k=${kk%%:*}; old=${kk#*:}
          # comments never count as settings
          lines=$(sed 's://.*$::' "$gradle" | grep -E "(^|[{;[:space:]])$k[[:space:]]*(=|[[:space:]])" || true)
          if [ -z "$lines" ]; then echo "MISSING   $k in $gradle (want flutter.$k)"; bad=1; continue; fi
          while IFS= read -r line; do
            case "$line" in
              *flutter.$k*|*"$old"*) ;;
              *) echo "HAND-SET  $k in $gradle: '$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')' (want flutter.$k)"; bad=1 ;;
            esac
          done <<<"$lines"
        done
      fi
    done < <(just _apps "$ws")
    if [ -z "$checked" ]; then
      echo "nothing checked: no ios/Runner/Info.plist and no android/app/build.gradle(.kts) in any app under $ws/"
      exit 0
    fi
    if [ "$bad" -ne 0 ]; then exit 1; fi
    echo "ok  every app takes its version from its pubspec.yaml:$checked"

# ──────────────────────── freshness ──────────────────────────
#
# `flutter pub outdated --no-transitive` lists the packages this project names
# itself, which are the ones it can act on. Alone it printed an all-clear that
# was not true (measured on 2026-09-19): it leaves out every package that came
# in through another one, and the lock file can hold those below what the
# pubspec.yaml files already allow, where a plain `flutter pub upgrade` would
# move them. So one more question is asked, of pub itself: what would `flutter
# pub upgrade` change. `--dry-run` writes no lock file, though Flutter's own
# wrapper still runs its post-processing after it (gen-l10n among it, read in
# flutter_tools' packages command). The all-clear is printed only
# when pub says nothing would change; anything else it says is shown as it
# said it.

# Which packages are behind, across the workspace. Flutter has this built in; nothing to install.
[group('flutter')]
outdated:
    #!/usr/bin/env bash
    set -uo pipefail
    ws={{quote(ws_dir)}}
    case "$(just _ws-state "$ws")" in
      ready) ;;
      none) echo "No pubspec.yaml in $ws/ yet. No packages, nothing to be behind."; exit 0 ;;
      *) exit 1 ;;
    esac
    just _need-flutter 2>/dev/null || exit 1
    bot=0; if [ -f .github/dependabot.yml ]; then bot=1; fi
    cd "$ws" || exit 1
    flutter pub outdated --no-transitive
    echo
    if ! out=$(flutter pub upgrade --dry-run 2>&1); then
      echo "Could not ask pub what an upgrade would move. It said:"
      printf '%s\n' "$out" | tail -5
      exit 1
    fi
    moved=$(grep -E '^[<>] ' <<<"$out" || true)
    if grep -q 'No dependencies would change' <<<"$out"; then
      echo "Nothing is locked below what the pubspec.yaml files allow: flutter pub upgrade would move nothing."
    elif [ -n "$moved" ]; then
      echo "Locked below what the pubspec.yaml files already allow, indirect ones included."
      echo "A plain flutter pub upgrade moves them, with no edit to any pubspec.yaml:"
      printf '%s\n' "$moved" | sed 's/^/  /'
    else
      echo "What flutter pub upgrade would do, in pub's words:"
      printf '%s\n' "$out" | tail -5
    fi
    if [ "$bot" -eq 0 ]; then echo "To have GitHub open the update PRs for you: just ci-init flutter"; fi

# ─────────────────────────────────────────────────────────────
# Also add these to the repo root, outside this file:
#
#   .gitignore   src/.dart_tool/     the workspace root's own: flutter create
#                src/build/          writes a .gitignore inside each app it
#                                    makes and none at the workspace root
#                src/*/.dart_tool/   a member made by hand, not by flutter
#                src/*/build/        create, has no .gitignore of its own
#                .kotlin/            Android's Kotlin cache, which flutter
#                                    create's .gitignore misses
#                With pubspec.yaml at the root: .dart_tool/ and build/ instead
#                of the four src/ lines. Without them the first save commits
#                them: a save stages everything git does not ignore.
#
# The git hooks already run `just lint` before every commit: `just stack
# flutter` put that hook in .pre-commit-config.yaml. Nothing to copy by hand.
# Change what lint runs by editing the recipe above; the hook follows.

# ────────────────────────── helpers ──────────────────────────

# The root files Flutter keeps there when pubspec.yaml is at the root, so `just
# doctor` does not call them strays. With the code in src/ nothing of Flutter's
# is in the root, and nothing is named. build/ is left off on purpose: once the
# .gitignore lines above are in, git ignores it and doctor never sees it, and
# until they are, doctor naming it is the only warning before a save commits it.
_root-allow:
    #!/usr/bin/env bash
    if [ -f pubspec.yaml ]; then
      echo "pubspec.yaml pubspec.lock analysis_options.yaml l10n.yaml lib test integration_test test_driver bin tool assets android ios macos linux windows web"
    fi

# What this layer needs on the machine, so `just doctor` can say when it is not
# there: one line per tool, the command first, then where to get it.
_stack-doctor:
    @echo "flutter  https://docs.flutter.dev/install"
    @echo "dart     comes with flutter"

# One sentence instead of "flutter: command not found" (exit 127), which is how
# every save that touched code once ended on a machine with no Flutter on it.
# The sentence goes to stdout: callers send this recipe's stderr away, so that
# just's own "recipe failed" line does not follow it and the person reads one
# line, not three.
_need-flutter:
    #!/usr/bin/env bash
    if command -v flutter >/dev/null 2>&1; then exit 0; fi
    echo "Flutter is not on this machine, or not on its PATH. just doctor says where to get it."
    exit 1

# The members of the workspace whose root is $1, one folder per line, relative
# to it: the `workspace:` list of its pubspec.yaml (a line may be a glob such as
# packages/*), or `.` alone when it is a single package. Only a folder with a
# pubspec.yaml of its own counts. Nothing when there is no pubspec.yaml at all.
# Plain awk, no YAML parser: the list is one key of one file, and this has to
# run wherever just does.
[positional-arguments]
_members ws:
    #!/usr/bin/env bash
    set -uo pipefail
    cd "$1" 2>/dev/null || exit 0
    if [ ! -f pubspec.yaml ]; then exit 0; fi
    # Three spellings pub accepts, all read: items under the key (indented, or
    # at column 0 — both are valid YAML, and the second once read as an empty
    # list, which made the root one package and tests and formatting quietly
    # skip every member), and a flow list, on one line or over several.
    list=$(awk '
      function flow(t,   n, i, w) {
        gsub(/\[/, " ", t); gsub(/\]/, " ", t); gsub(/,/, " ", t); gsub(/["\047]/, "", t)
        n = split(t, w, " "); for (i = 1; i <= n; i++) print w[i]
      }
      # A checkout made on Windows ends each line in a carriage return.
      { sub(/\r$/, ""); sub(/^[ \t]*#.*$/, ""); sub(/[ \t]+#.*$/, "") }
      inflow { buf = buf " " $0; if ($0 ~ /\]/) { flow(buf); exit }; next }
      /^workspace:/ {
        print "@key"
        rest = $0; sub(/^workspace:[ \t]*/, "", rest)
        if (rest ~ /^\[/) { if (rest ~ /\]/) { flow(rest); exit }; buf = rest; inflow = 1; next }
        on = 1; next
      }
      on && /^[ \t]*-/ { v = $0; sub(/^[ \t]*-[ \t]*/, "", v); gsub(/["\047]/, "", v); sub(/[ \t]+$/, "", v); if (v != "") print v; next }
      on && /^[^ \t]/ { exit }
    ' pubspec.yaml)
    key=0; case "$list" in "@key"*) key=1; list=$(printf '%s\n' "$list" | sed '1d') ;; esac
    if [ -z "$list" ]; then
      if [ "$key" -eq 1 ]; then
        # A `workspace:` key whose members this could not read. Falling back to
        # "one package" would test and format nothing and call it a pass.
        echo "$1/pubspec.yaml has a workspace: key, but no member could be read from it. Write each member on its own line under it, as - <folder>." >&2
        exit 1
      fi
      echo .; exit 0
    fi
    for m in $list; do
      if [ -f "$m/pubspec.yaml" ]; then printf '%s\n' "${m%/}"; fi
    done

# Where the workspace stands, printed as one word. ready: $1/pubspec.yaml is
# there. none: there is no pubspec.yaml anywhere a project on this backbone keeps
# one, so nothing has been made yet and a recipe passes quietly — a save between
# `just stack flutter` and `flutter create` must not stop. elsewhere: there is
# one, just not where ws_dir looks, and a quiet pass there would be a lint that
# never read the code (spec 015 review); a sentence on stderr says which line to
# set, and the caller stops.
[positional-arguments]
_ws-state ws:
    #!/usr/bin/env bash
    if [ -f "$1/pubspec.yaml" ]; then echo ready; exit 0; fi
    shopt -s nullglob
    found=""
    # nullglob drops a pattern that matches nothing, never a plain name: each
    # is asked about.
    for p in pubspec.yaml src/pubspec.yaml src/*/pubspec.yaml; do
      if [ -f "$p" ]; then d=$(dirname "$p"); found="$found $d/"; fi
    done
    if [ -z "$found" ]; then echo none; exit 0; fi
    {
      echo "The Flutter code here is in$found but these recipes look in $1/."
      one=$(printf '%s\n' $found | sed -n 's#^src/\([^/]*\)/$#\1#p' | head -n 1)
      if [ -n "$one" ]; then
        echo "One app in src/$one/: set app := \"$one\" in stack.just. Anything else: set ws_dir there."
      else
        echo "Set ws_dir in stack.just to the folder whose pubspec.yaml holds the Flutter pin."
      fi
    } >&2
    echo elsewhere

# Build folders git would save. flutter create writes a .gitignore inside each
# app it makes and none at a workspace root made by hand, so src/.dart_tool/ —
# whose package_config.json holds paths into the person's own home folder — and
# src/build/ were staged by the next save and sent by publish-on-save. Checked
# here, before every save, because doctor never sees a dot folder and a save
# stages everything git does not ignore. Nothing is written: the sentence names
# the lines, and the .gitignore is the project's.
[positional-arguments]
_loose-builds ws:
    #!/usr/bin/env bash
    set -uo pipefail
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
    members=$(just _members "$1") || exit 0
    loose=""
    for m in . $members; do
      if [ "$m" = . ]; then base="$1"; else base="$1/$m"; fi
      for d in .dart_tool build; do
        p="$base/$d"; p="${p#./}"
        if [ -d "$p" ] && ! git check-ignore -q "$p" 2>/dev/null; then
          case " $loose " in *" $p/ "*) ;; *) loose="$loose $p/" ;; esac
        fi
      done
    done
    [ -z "$loose" ] && exit 0
    echo "Git does not ignore these build folders, so the next save would commit them:$loose"
    echo "Add them to the .gitignore at the root of the repository, one line each, and save again."
    exit 1

# The members named in `pure` ($2) that name the Flutter SDK in their
# pubspec.yaml: each is a package that promised to stay free of Flutter and no
# longer is. A sentence and a failure, before the tests run, so a pure package
# that took Flutter in is caught on the save that did it and not the day a
# server build fails.
[positional-arguments]
_pure-check ws pure:
    #!/usr/bin/env bash
    set -uo pipefail
    [ -n "${2:-}" ] || exit 0
    bad=""
    for m in $2; do
      f="$1/$m/pubspec.yaml"
      if [ ! -f "$f" ]; then echo "pure names $m, but there is no $f." >&2; exit 1; fi
      if grep -qE "^[^#]*sdk:[[:space:]]*[\"']?flutter" "$f"; then bad="$bad $m"; fi
    done
    [ -z "$bad" ] && exit 0
    echo "These are named in pure, and now depend on Flutter:$bad."
    echo "Take the Flutter dependency back out of their pubspec.yaml, or move the code that needs"
    echo "Flutter into an app or a Flutter package. A pure package is what a server can compile."
    exit 1

# The Dart folders of every member of the workspace at $1, relative to it: what
# the format check reads. flutter create's and dart create's own folders.
[positional-arguments]
_dart-dirs ws:
    #!/usr/bin/env bash
    set -uo pipefail
    members=$(just _members "$1") || exit 1
    while IFS= read -r m; do
      if [ -z "$m" ]; then continue; fi
      for d in lib test integration_test test_driver bin tool; do
        if [ "$m" = . ]; then p="$d"; else p="$m/$d"; fi
        if [ -d "$1/$p" ]; then printf '%s\n' "$p"; fi
      done
    done <<< "$members"

# Every app of the workspace at $1, as a path from the project's root: a member
# with an ios/ or android/ folder, which is what a store ships.
[positional-arguments]
_apps ws:
    #!/usr/bin/env bash
    set -uo pipefail
    while IFS= read -r m; do
      if [ -z "$m" ]; then continue; fi
      if [ "$m" = . ]; then p="$1"; else p="$1/$m"; fi
      if [ -d "$p/ios" ] || [ -d "$p/android" ]; then printf '%s\n' "$p"; fi
    done < <(just _members "$1")

# The folder the one-app recipes run in, printed; or, when there is no app there,
# nothing printed and a sentence on stderr saying why and what to type.
# Flutter's own error in a folder with no app names a missing file and not what
# to do next. It exits 0 either way, so that just adds no "recipe failed" line
# under the sentence: an empty answer is the failure, and the caller stops.
[positional-arguments]
_app dir ws:
    #!/usr/bin/env bash
    set -uo pipefail
    d="$1"; ws="$2"
    if [ -f "$d/pubspec.yaml" ] && [ -f "$d/lib/main.dart" ]; then printf '%s\n' "$d"; exit 0; fi
    members=$(just _members "$ws"); apps=""
    while IFS= read -r m; do
      if [ -n "$m" ] && [ "$m" != . ] && [ -f "$ws/$m/lib/main.dart" ]; then apps="$apps $m"; fi
    done <<< "$members"
    {
      if [ ! -d "$d" ]; then echo "There is no folder $d/, so there is no app to run there."
      elif [ ! -f "$d/pubspec.yaml" ]; then echo "$d/ has no pubspec.yaml, so there is no Flutter app in it yet."
      elif [ "$d" = "$ws" ] && [ -n "$members" ] && [ "$members" != . ]; then echo "$d/ is the workspace root: its pubspec.yaml lists the members and is no app itself."
      else echo "$d/ has no lib/main.dart, so it is a package and not an app."; fi
      if [ -n "$apps" ]; then
        echo "The apps here:$apps. Name one for this command, just app=<name> <recipe>, or set app := \"<name>\" in stack.just."
      else
        echo "Make one: flutter create --project-name <name> $d"
      fi
    } >&2
