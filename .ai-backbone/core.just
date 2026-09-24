# .ai-backbone/core.just — the backbone's recipes, version 3.27.13
#
# THIS FILE IS OWNED BY THE BACKBONE. `just template-update` overwrites it.
# Put your own recipes in `Justfile` or in `stack.just` instead.
#
# A recipe that takes an argument reads it as `$1` under `[positional-arguments]`,
# the attribute on the line directly above its header. Never write `{{arg}}`
# inside a script: whatever the person typed would run as a command.
#
# Needs just 1.29.0 or newer (the [positional-arguments] attribute). setup.sh
# says so before an older just stops at "unknown attribute".
#
# Versions follow SemVer: MAJOR.MINOR.PATCH. Patch = fix, nothing to do.
# Minor = new recipe or file, nothing breaks. Major = something moved or a
# rule needs a manual step; the CHANGELOG entry says which.
#
# .ai-backbone/manifest.txt lists every file the backbone owns.

# Python on Windows writes to a pipe in the console's code page (cp1252) and
# stops at the first letter outside it, a Turkish ı among them (spec 020). UTF-8
# mode makes every Python a recipe runs read and write UTF-8, on any machine.
export PYTHONUTF8 := "1"

# ──────────────────────────── you ────────────────────────────

# The four commands you will ever type
[group('you')]
help:
    @echo
    @just _msg help-save
    @just _msg help-undo
    @just _msg help-publish
    @just _msg help-doctor
    @echo
    @just _msg help-rest

# ─────────────────────────── setup ───────────────────────────

# Do the checks still carry the lessons they were built on?
[group('setup')]
ci-check:
    #!/usr/bin/env bash
    set -uo pipefail
    shopt -s nullglob
    files=(.github/workflows/*.yml .github/workflows/*.yaml)
    if [ ${#files[@]} -eq 0 ]; then
      echo "No checks in this project yet. Add them: just ci-init"; exit 0
    fi
    # Four of the five lessons the starter carries are SETTINGS, and a setting
    # cannot fail on a runner: it silently stops being there the first time
    # somebody edits the file. So they are checked here instead, on the commit.
    # Only what this backbone has measured is asserted — which is why every rule
    # but the first asks about cargo, and why nothing here judges a language
    # nobody has run on a runner yet.
    # Flutter was checked against these rules on 2026-09-23, with
    # examples/ci-flutter.yml: the concurrency rule is the one that applies to
    # it, and it holds; the others ask about cargo and stay silent. No Flutter
    # rule was added, because no Flutter run on a runner has been measured yet.
    bad=0
    say() { bad=$((bad+1)); printf '  FAIL  %s\n' "$1"; shift; for l in "$@"; do printf '        %s\n' "$l"; done; }
    for f in "${files[@]}"; do
      # A file's own comments are its reasons, not its answers: a line that says
      # --no-fail-fast in a comment must not pass the check for it. Backslash
      # continuations are joined first, so a flag on the next line still counts.
      body=$(sed -E 's/^[[:space:]]*#.*$//' "$f" | sed -e :a -e '/\\$/N;s/\\\n//;ta')
      skip=" $(grep -oE '#[[:space:]]*ci-check:[[:space:]]*skip[[:space:]]+[a-z-]+' "$f" | awk '{print $NF}' | tr '\n' ' ') "
      had=$bad
      has()     { printf '%s' "$body" | grep -qE "$1"; }
      skipped() { case "$skip" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

      # Only a workflow a push or a pull request starts can have a run to
      # supersede. A release or a scheduled job has nothing to cancel.
      if ! skipped concurrency && has '(pull_request|push)'; then
        if ! has '^[[:space:]]*concurrency:'; then
          say "$f: no concurrency group" \
            'A branch under review pushed to three times in a minute runs three' \
            'times over, and the two answers nobody wants finish last. Above jobs:' \
            '  concurrency:' \
            '    group: ${{{{ github.workflow }}-${{{{ github.event_name == '"'"'pull_request'"'"' && github.ref || github.sha }}' \
            '    cancel-in-progress: ${{{{ github.event_name == '"'"'pull_request'"'"' }}'
        else
          if printf '%s' "$body" | grep -qiE 'cancel-in-progress:[[:space:]]*(true|yes)[[:space:]]*(#.*)?$'; then
            say "$f: cancel-in-progress is a plain true" \
              'Then a push to the default branch cancels the push before it, and' \
              'the commit that broke something never gets an answer. Ask instead:' \
              '  cancel-in-progress: ${{{{ github.event_name == '"'"'pull_request'"'"' }}'
          fi
          if printf '%s' "$body" | grep -A6 '^[[:space:]]*concurrency:' | grep -q 'group:' && \
           ! printf '%s' "$body" | grep -A6 '^[[:space:]]*concurrency:' | grep -q 'github.sha'; then
            say "$f: every push shares one concurrency group" \
              'On the default branch each commit needs a group of its own, or' \
              'pushes cancel or queue behind one another and the history you read' \
              'later to find where something broke is one answer for many' \
              'commits. Key it on the sha when the event is not a pull request:' \
              '  group: ${{{{ github.workflow }}-${{{{ github.event_name == '"'"'pull_request'"'"' && github.ref || github.sha }}'
          fi
        fi
      fi

      # From here on, cargo only. The disk and the debug-info lessons were
      # measured once, on one Rust workspace on a Linux runner. Firing them at a
      # Go or a Gradle build would be asserting something nobody here has ever
      # seen, and blocking somebody's commit over it.
      if ! skipped room && has 'runs-on:.*ubuntu' && has 'cargo (build|test)' \
         && ! has '(df -h|/usr/share/dotnet|uses:[[:space:]]*\./\.github/actions/)'; then
        say "$f: nothing frees the runner's disk" \
          'A GitHub runner arrives with about 14 GB free, and a .NET SDK, an' \
          'Android SDK, a Haskell toolchain and a copy of Boost you will never' \
          'use. Deleting them gave 30 GB on the project this was measured on. A' \
          'linker that runs out of disk dies of a bus error and names no cause.' \
          'One step, first in the job:' \
          '  sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /usr/local/share/boost'
      fi

      if ! skipped debug-info && has 'cargo (build|test)' \
         && ! has 'CARGO_PROFILE_(TEST|DEV)_DEBUG' \
         && ! grep -qs 'line-tables-only' Cargo.toml; then
        say "$f: full debug info in CI" \
          'Debug info is a map for a debugger, and nobody attaches one to a' \
          'runner. It is gigabytes, and it is how the disk above fills. Keep the' \
          'line numbers a panic needs and drop the rest, under env:' \
          '  CARGO_PROFILE_DEV_DEBUG: line-tables-only' \
          '  CARGO_PROFILE_TEST_DEBUG: line-tables-only'
      fi

      # This waiver is the one that has to be smaller than a file. A workflow
      # can hold one cargo test line that means it — a single test binary has
      # nothing to fail fast past — and another that is a plain oversight. So a
      # `ci-check: skip no-fail-fast` comment ON a cargo test line, or on the
      # line directly above it, waives that line and no other. Anywhere else in
      # the file it waives the file, the way every other waiver does. Which is
      # why the joining above is repeated here: line numbers survive it.
      numbered=""; n=0; start=0; buf=""
      while IFS= read -r raw || [ -n "$raw" ]; do
        n=$((n+1))
        [ -n "$buf" ] || start=$n
        buf="$buf$raw"
        case "$buf" in *\\) buf="${buf%\\}"; continue ;; esac
        numbered="$numbered$start $buf"$'\n'; buf=""
      done < <(sed -E 's/^[[:space:]]*#.*$//' "$f")
      [ -z "$buf" ] || numbered="$numbered$start $buf"$'\n'

      # Every cargo test the file actually runs, and which of them are bare.
      cargo_at=" "; offenders=" "
      while IFS= read -r numline; do
        num="${numline%% *}"; line="${numline#* }"
        printf '%s' "$line" | grep -qE '(^|[^a-z-])cargo test' || continue
        # An ordinary trailing comment is not part of the command.
        line="${line%%#*}"
        [ -n "$line" ] || continue
        # A sentence about cargo test is not a cargo test.
        case "$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//' | cut -d' ' -f1)" in echo|printf) continue ;; esac
        cargo_at="$cargo_at$num "
        case "$line" in *--no-run*|*--list*|*--no-fail-fast*) continue ;; esac
        offenders="$offenders$num "
      done <<< "$numbered"

      # A waiver touching a cargo test line speaks for that line alone: written
      # on the command it is that command's, written on a line of its own it
      # belongs to the command under it. Touching neither, it is the file's.
      at() { case "$cargo_at" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
      waived=" "; nff_whole_file=0
      while IFS= read -r w; do
        [ -n "$w" ] || continue
        if at "$w"; then waived="$waived$w "
        elif at "$((w+1))"; then waived="$waived$((w+1)) "
        else nff_whole_file=1; fi
      done < <(grep -nE '#[[:space:]]*ci-check:[[:space:]]*skip[[:space:]]+no-fail-fast' "$f" | cut -d: -f1)

      if [ "$nff_whole_file" -eq 0 ]; then
        for num in $offenders; do
          case "$waived" in *" $num "*) continue ;; esac
          say "$f line $num: cargo test without --no-fail-fast" \
            'Cargo stops at the first test BINARY that fails, so one red push' \
            'tells you about one defect and you find the next one tomorrow. Six' \
            'went unrun the first time a project here got this far. Write:' \
            '  cargo test --workspace --no-fail-fast' \
            'Deliberate on this one line? Say so on the line itself, and every' \
            'other cargo test in the file stays watched:' \
            '  cargo test -p one-binary   # ci-check: skip no-fail-fast - one binary'
          break
        done
      fi

      [ "$bad" -eq "$had" ] && printf '  ok    %s\n' "$f"
    done
    echo
    if [ "$bad" -eq 0 ]; then
      echo "Every lesson these checks were built on is still in force."
    else
      if [ "$bad" -eq 1 ]; then echo "One lesson is not in force. The lines above say what it costs."
      else echo "$bad lessons are not in force. The lines above say what each one costs."; fi
      echo "Meant on purpose? Say so in the workflow and this stops asking. One of:"
      echo "  # ci-check: skip concurrency | room | debug-info | no-fail-fast"
      echo "with the reason after it, on the same line. A no-fail-fast waiver"
      echo "written on a cargo test line, or the line above one, waives that"
      echo "line alone; anywhere else in the file it waives the whole file."
      exit 1
    fi

# Add the checks GitHub runs on every push: just ci-init | just ci-init rust
[group('setup')]
[positional-arguments]
ci-init lang="":
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    lang="$1"
    # Nobody should have to say what this project is written in twice.
    if [ -z "$lang" ]; then
      # nullglob drops a pattern that matches nothing, but a plain name with no
      # wildcard in it survives whether or not the file is there, so the two are
      # asked about differently. A project with no marker at all gets the part
      # that is true anywhere rather than a guess about its language. The marker
      # is the one thing a file name in examples/ cannot say, so it is written
      # here; the name it leads to is the one the example files carry.
      rust=(*/Cargo.toml src/*/Cargo.toml)
      swift=(*/Package.swift *.xcodeproj)
      flutter=(*/pubspec.yaml src/*/pubspec.yaml)
      found=()
      if [ -f Cargo.toml ]    || [ ${#rust[@]}  -gt 0 ];   then found+=(rust); fi
      if [ -f Package.swift ] || [ ${#swift[@]} -gt 0 ];   then found+=(swift); fi
      if [ -f pubspec.yaml ]  || [ ${#flutter[@]} -gt 0 ]; then found+=(flutter); fi
      # Two languages is a real shape — Flutter apps with a Rust server beside
      # them — and the first one this found used to win in silence, so such a
      # project got the Rust checks and none for its apps. Asked instead.
      if [ ${#found[@]} -gt 1 ]; then
        echo "This project has more than one language: ${found[*]}. Name the one to check on every push:"
        for l in "${found[@]}"; do echo "  just ci-init $l"; done
        exit 1
      fi
      lang="${found[0]:-generic}"
    fi
    # Where a Flutter project keeps the pubspec.yaml that pins its SDK: the
    # workspace root. The two files copied below name it, and each is pointed
    # at the real one. Only what this run copies is touched.
    fdir=""
    if [ "$lang" = flutter ]; then
      apps=(src/*/pubspec.yaml)
      if   [ -f pubspec.yaml ];     then fdir=.
      elif [ -f src/pubspec.yaml ]; then fdir=src
      elif [ ${#apps[@]} -eq 1 ];   then fdir="${apps[0]%/pubspec.yaml}"
      fi
    fi
    src=""
    if [ -n "$(just _is-backbone)" ]; then src="$PWD"; else src=$(just _backbone 2>/dev/null) || true; fi
    if [ -z "$src" ]; then
      echo "The backbone is not on this machine next to the project, so there is"
      echo "nothing to copy from. Put it beside this folder, or set AI_BACKBONE."
      exit 1
    fi
    # The update bot first, and whether or not a workflow is ready for this
    # language. The two were one step, so dependabot-swift.yml could never be
    # reached (there is no ci-swift.yml to get past) and a Flutter project got
    # no update bot at all. A pull request that says a package is behind needs
    # no workflow to be worth reading.
    if [ ! -f .github/dependabot.yml ] && [ -f "$src/.ai-backbone/examples/dependabot-$lang.yml" ]; then
      mkdir -p .github
      cp "$src/.ai-backbone/examples/dependabot-$lang.yml" .github/dependabot.yml
      echo "  added   .github/dependabot.yml (GitHub opens a pull request when something is behind)"
      # pub's entry names the folder of the pubspec.yaml, and "/" had none in
      # the src/ shapes: its job failed on every schedule and no pub pull
      # request ever opened (spec 015 review). The github-actions entry stays
      # at "/". How Dependabot treats a pub workspace has not been measured.
      if [ -n "$fdir" ] && [ "$fdir" != . ]; then
        t=$(mktemp)
        awk -v d="/$fdir" '
          /package-ecosystem: *"pub"/ { pub = 1 }
          pub && /^[ \t]*directory:/ { sub(/"[^"]*"/, "\"" d "\""); pub = 0 }
          { print }' .github/dependabot.yml > "$t"
        cat "$t" > .github/dependabot.yml; rm -f "$t"
        echo "          its pub entry pointed at /$fdir, where the pubspec.yaml is"
      fi
    fi
    f="$src/.ai-backbone/examples/ci-$lang.yml"
    if [ ! -f "$f" ]; then
      echo "No ready checks for '$lang'. Ready: $(just _examples "$src" ci)"
      if [ "$lang" = swift ]; then
        echo "The Rust one would not do: its largest step frees disk on a Linux"
        echo "runner, and Swift needs a Mac, where the room is taken by Xcode and"
        echo "cannot be deleted. Nobody here has measured a macOS runner, and a"
        echo "guess written down as a starter becomes a fact nobody rechecks."
      fi
      echo "Starting from the part that is true anywhere: just ci-init generic"
      exit 1
    fi
    mkdir -p .github/workflows
    copied=0
    mine=(.github/workflows/*.yml .github/workflows/*.yaml)
    if [ ${#mine[@]} -gt 0 ]; then
      # Never a second workflow beside somebody's own: both would run, and the
      # second one is silent about doubling the bill.
      echo "  kept    the checks this project already has:"
      printf '          %s\n' "${mine[@]}"
    else
      cp "$f" .github/workflows/checks.yml
      echo "  added   .github/workflows/checks.yml (from ci-$lang.yml)"
      copied=1
      # The Flutter one reads its version from the workspace root's pubspec.yaml
      # and names src/, where this backbone keeps code. With the pubspec at the
      # root instead, the first run would stop at a file that is not there, so
      # the copy is pointed at the root. Only this recipe's own copy is touched,
      # written a line above; cat keeps the file's permissions, where mv would
      # hand it mktemp's.
      if [ "$lang" = flutter ] && [ -n "$fdir" ] && [ "$fdir" != src ]; then
        if [ "$fdir" = . ]; then pin=pubspec.yaml; else pin="$fdir/pubspec.yaml"; fi
        t=$(mktemp)
        sed "s#flutter-version-file: src/pubspec.yaml#flutter-version-file: $pin#" .github/workflows/checks.yml > "$t"
        cat "$t" > .github/workflows/checks.yml; rm -f "$t"
        echo "          pointed at $pin, where this project keeps its Flutter pin"
      fi
    fi
    echo
    just ci-check || true
    echo
    # What a run costs, said once, here, because nothing on GitHub says it until
    # the month's minutes are gone: a project on this backbone used 2,000 of them
    # in two days (2026-09-16 and 17), and its checks were then switched off. Only a
    # private repository pays, and `just publish` creates private ones, so the
    # sentence is left out only where GitHub itself says the repository is public.
    private=""
    if [ -z "${AI_BACKBONE_OFFLINE:-}" ] && command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
      private=$(GH_PAGER=cat gh repo view --json isPrivate -q .isPrivate 2>/dev/null || true)
    fi
    case "$private" in
      false) : ;;
      true)  echo "This repository is private: every run of these checks uses up the GitHub account's free minutes, and a month of them can be gone in days (one project here used 2,000 in two days)."; echo ;;
      *)     echo "In a private repository (the kind just publish creates) every run of these checks uses up the GitHub account's free minutes, and a month of them can be gone in days (one project here used 2,000 in two days)."; echo ;;
    esac
    # The commit hook is only for a workflow this recipe wrote. Installing it
    # over somebody's own file would block their next commit with rules they
    # were never told about, which is not this recipe's to do.
    if [ "$copied" -eq 1 ]; then
      added=$(just _hook-ci || true)
      if [ -n "$added" ]; then echo "  $added"; just hooks-install >/dev/null 2>&1 || true; echo; fi
      echo "Next: edit .github/workflows/checks.yml — the names and the commands in"
      echo "it are not this project's yet. Then: just publish. A minute later: just ci"
    else
      echo "Those are this project's own checks and they stay as they are."
      echo "Next: just publish. A minute later: just ci"
    fi

# Check that every tool this repo needs is installed
[group('setup')]
doctor:
    #!/usr/bin/env bash
    missing=0
    check() {
      if command -v "$1" >/dev/null 2>&1; then
        printf "  ok    %-10s %s\n" "$1" "$("$1" --version 2>&1 </dev/null | head -1)"
      else
        printf "  MISS  %-10s -> %s\n" "$1" "$2"; return 1
      fi
    }
    echo "Tools:"
    check git      "xcode-select --install   (macOS)  |  apt install git"         || missing=1
    check gh       "brew install gh          |  see cli.github.com"               || missing=1
    check uv       "curl -LsSf https://astral.sh/uv/install.sh | sh"              || missing=1
    check graphify "uv tool install graphifyy"                                    || missing=1
    check prek     "uv tool install prek"                                         || missing=1
    echo
    echo "  note  prek downloads the secret scanner itself. Nothing else to install."
    echo
    # What the project's own language needs on this machine. The backbone cannot
    # know it, and until it asked, a Mac with no Flutter on it read "Everything
    # needed is installed" and then failed every save that touched code, in the
    # lint hook, with "dart: command not found". So the language layer says it, the
    # way it says `_root-allow`: a `_stack-doctor` recipe in stack.just, one line
    # per tool, the command first and where to get it after.
    #     _stack-doctor:
    #         @echo "flutter  https://docs.flutter.dev/install"
    # Counted apart from the tools above, because the ending is different: nobody
    # is sent to setup.sh for a language, which setup.sh has never installed.
    sdk=0
    needs=$(just _stack-doctor 2>/dev/null || true)
    if [ -n "$needs" ]; then
      echo "Language:"
      while read -r tool how; do
        [ -n "$tool" ] || continue
        check "$tool" "${how:-stack.just names it and does not say where to get it}" || sdk=1
      done <<< "$needs"
      echo
    fi
    echo "Repo:"
    if [ -d brain ]; then echo "  ok    brain/"; else echo "  MISS  brain/ -> just brain-init"; missing=1; fi
    # brain/ is ignored by git on purpose, so GitHub is no second copy of it. Is
    # there one, and how old is it: the age is read off the file `_vault-copy`
    # writes into the copy each time, because only that says when a copy was
    # really written. Whether a cloud drive has uploaded it since, nothing here
    # can know, so nothing here says.
    if [ -d brain ]; then
      dest=$(just _vault-dest 2>/dev/null || true)
      if [ -z "$dest" ]; then echo "  --    $(just _doctor-msg copy-none)"
      elif [ ! -d "$(dirname "$dest")" ]; then echo "  warn  $(just _doctor-msg copy-unreachable "$(dirname "$dest")")"
      elif [ ! -f "$dest/about-this-copy.txt" ]; then echo "  --    $(just _doctor-msg copy-never "$dest")"
      else
        days=$(( ( $(date +%s) - $(date -r "$dest/about-this-copy.txt" +%s 2>/dev/null || date +%s) ) / 86400 ))
        echo "  ok    $(just _doctor-msg copy-age "$days" "$dest")"
      fi
    fi
    if [ -n "$(just _is-repo)" ]; then echo "  ok    git repo"; else echo "  warn  no git repo -> git init"; fi
    hooks=$(git rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)
    if [ -f "$hooks/pre-commit" ] && [ -f "$hooks/commit-msg" ]; then echo "  ok    git hooks"; else echo "  warn  hooks missing -> just hooks-install"; fi
    if [ -n "$(just _push-stage)" ] && [ ! -f "$hooks/pre-push" ]; then echo "  warn  .pre-commit-config.yaml has a pre-push hook and git will not run it -> just hooks-install"; fi
    if [ -f graphify-out/GRAPH_REPORT.md ]; then echo "  ok    code map"
    elif [ -n "$(just _has-code 2>/dev/null)" ]; then echo "  warn  no code map -> just update-map"
    else echo "  ok    code map   (nothing to map yet)"; fi
    # The languages on offer are the stack-*.just files the backbone holds, read
    # from their names: "rust | swift" written out here would still say two on
    # the day a third file arrives. With no backbone nearby there is no list.
    if [ -f stack.just ]; then echo "  ok    language layer (stack.just)"; else
      src=""; if [ -n "$(just _is-backbone)" ]; then src="$PWD"; else src=$(just _backbone 2>/dev/null) || true; fi
      hint=""; for l in $(just _examples "$src" stack); do hint="$hint${hint:+  |  }just stack $l"; done
      echo "  --    no language yet. When you pick one: ${hint:-just stack}"
    fi
    # A project with a lint and no hook to run it. `just stack` installs the
    # hook, so a project that got its language layer that way has one — and a
    # project made before the hook existed, or one whose stack.just was written
    # by hand, does not, and nothing said so. What it costs is the thing this
    # whole file is for: work the language layer rejects is saved, pushed by
    # publish-on-save, and found by CI, which means found by an email to the
    # maintainer.
    if just --summary 2>/dev/null | tr ' ' '\n' | grep -qx lint; then
      if [ -f .pre-commit-config.yaml ] && grep -q '_lint-if-any' .pre-commit-config.yaml
      then echo "  ok    lint runs before a save"
      else echo "  warn  'just lint' exists and nothing runs it before a save -> just hooks-install"; fi
    fi
    if [ -d .github/workflows ]; then
      if just ci-check >/dev/null 2>&1; then echo "  ok    checks on every push (.github/workflows)"
      else echo "  warn  the checks have dropped a lesson -> just ci-check"; fi
    elif [ -n "$(just _is-repo)" ]; then echo "  --    no checks on push yet. When you want them: just ci-init"; fi
    if just --summary 2>/dev/null | tr ' ' '\n' | grep -qx outdated; then echo "  info  run 'just outdated' to see which dependencies are behind"; fi
    # The project's own version (spec 016), not the backbone's: the highest
    # vX.Y.Z tag, and how many saves have come since.
    if [ -z "$(just _is-backbone)" ] && git rev-parse -q --verify HEAD >/dev/null 2>&1; then
      pv=$(git tag --list 'v[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1.2,1n -k2,2n -k3,3n | tail -n 1 || true)
      if [ -n "$pv" ]; then
        since=$(git rev-list --count "$pv..HEAD" 2>/dev/null || echo 0)
        if [ "$since" -eq 0 ]; then echo "  ok    version $pv, at this save"
        else echo "  ok    version $pv, $since save(s) since. The next is cut when a spec is done: just release"; fi
      else
        echo "  --    no version of its own yet: the first just release makes it 0.1.0, when a spec is done"
      fi
    fi
    if just _rules-check >/dev/null 2>&1; then echo "  ok    rule copies match AGENTS.md"; else echo "  warn  rule copies out of date -> just sync-rules"; fi
    stray=$(just _root-strays); if [ -z "$stray" ]; then echo "  ok    root holds only what belongs there"; else echo "  warn  root has things that do not belong:$stray"; echo "        code -> src/   private files -> brain/05-files/   logos, screenshots -> docs/brand/"; echo "        a root file your language needs: name it in a _root-allow recipe in stack.just"; fi
    # AGENTS.md section 7 says where keys and certificates live, and until now
    # nothing looked. A warning and never a failure: the file may be exactly where
    # a build tool reads it, and moving it is a decision, not a repair. An .env is
    # not named here: it has to stay where its tool reads it.
    keys=""
    while IFS= read -r k; do
      case "$k" in ""|.env|*/.env|.env.*|*/.env.*|.envrc|*/.envrc) continue ;; esac
      keys="$keys $k"
    done < <(just _secret-files 2>/dev/null)
    if [ -n "$keys" ]; then
      echo "  warn  $(just _doctor-msg key-outside)$keys"
      echo "        $(just _doctor-msg key-where)"
    fi
    # The build folder, where the language layer names one in `_build-info`
    # (spec 015): how big it has grown, and whether other projects build into
    # it too. Measured here and never in session-start: du reads every file,
    # and a folder of hundreds of gigabytes takes it minutes, which a session's
    # first seconds cannot spend and doctor, asked on purpose, can spend up to a
    # minute of. A folder that cannot be measured in that time, or at all, is
    # not reported and never guessed at. Under BUILD_OUTPUT_WARN_GB (50) it is
    # not mentioned. The shared line is said here, once, and not on every build.
    bdir=""; bclean=""; bset=""; bfrom=""
    while read -r k v; do
      case "$k" in dir) bdir="$v" ;; clean) bclean="$v" ;; set) bset="$v" ;; from) bfrom="$v" ;; esac
    done <<< "$(just _build-info 2>/dev/null || true)"
    if [ -n "$bdir" ]; then
      bshared=$(just _build-shared "$bdir")
      warn_gb="${BUILD_OUTPUT_WARN_GB:-50}"; case "$warn_gb" in ""|*[!0-9]*) warn_gb=50 ;; esac
      kb=""; size=""
      secs="${BUILD_MEASURE_SECONDS:-60}"; case "$secs" in ""|*[!0-9]*) secs=60 ;; esac
      if [ -d "$bdir" ]; then read -r kb size <<< "$(just _build-size "$bdir" "$secs")"; fi
      if [ -n "$bshared" ]; then fix="outside this project, see below"; elif [ -n "$bclean" ]; then fix="just $bclean"; else fix="stack.just names no recipe that clears it"; fi
      if [ "$kb" = timeout ]; then
        # The case that started spec 015: a folder so big that a minute is not
        # enough to add it up. Said, not skipped.
        echo "  warn  build output is too big to measure in ${secs}s (BUILD_MEASURE_SECONDS): $bdir -> $fix"
      elif [ -n "$kb" ] && [ "$kb" -gt $((10#$warn_gb * 1048576)) ]; then
        echo "  warn  build output is $size, over $warn_gb GB (BUILD_OUTPUT_WARN_GB): $bdir -> $fix"
      fi
      # A build folder inside the project that git does not ignore is
      # gigabytes the next save stages. It was never a question while every
      # build went to one folder outside the project; the day that setting is
      # removed, builds land here, and a project whose .gitignore named only
      # /target missed its server's src/server/target/ (measured 2026-09-23).
      # Asked with a trailing slash: without one git cannot match a folder
      # pattern against a folder that has not been built yet.
      if [ -z "$bshared" ] && [ -n "$(just _is-repo)" ]; then
        here=$(pwd -P)
        bparent=$(cd "$(dirname "$bdir")" 2>/dev/null && pwd -P) || bparent=""
        if [ -n "$bparent" ]; then
          brel="$bparent/$(basename "$bdir")"; brel="${brel#"$here"/}"
          if ! git check-ignore -q "$brel/" 2>/dev/null; then
            echo "  warn  git does not ignore the build folder, so a save would commit it: $brel/"
            echo "        Add this line to .gitignore: $brel/"
          fi
        fi
      fi
      if [ -n "$bshared" ]; then
        echo "  warn  the build folder is outside this project: $bdir${bset:+ ($bset)}"
        echo "        Other projects can build into it too, and if they do, one project's clean clears"
        echo "        every project's builds, and two builds wait on one lock. The IDE reads the same"
        echo "        setting as these recipes, so they agree on where builds go, and that is why"
        echo "        the backbone never moves it."
        if [ -n "$bset" ]; then
          echo "        To end it: remove the line that sets $bset from your shell setup (.zshrc,"
          echo "        .bashrc, .profile, config.fish, an .envrc: wherever it is set), open a new"
          echo "        terminal and restart the IDE. Each project then builds into its own folder."
        elif [ -n "$bfrom" ]; then
          echo "        To end it: change $bfrom so the folder is inside this project."
        else
          echo "        To end it: point the build folder back inside this project."
        fi
      fi
    fi
    # What the language layer has to say about the project itself, printed as it
    # is: a `_stack-advice` recipe in stack.just, in doctor's own two columns.
    # The Rust layer says when dev builds carry full debug info.
    just _stack-advice 2>/dev/null || true
    echo
    printf "  "; just template-check 2>/dev/null || echo "Backbone: check skipped."
    echo
    # Three endings. Nothing is missing; one of the backbone's own tools is, and
    # setup.sh installs those; what the language needs is, and setup.sh has never
    # installed a language, so a project that lacks only its SDK is not sent there.
    if [ "$missing" -eq 0 ] && [ "$sdk" -eq 0 ]; then
      just _doctor-msg end-ok
    elif [ "$missing" -eq 0 ]; then
      just _doctor-msg end-language
    else
      just _doctor-msg end-missing
      if [ "$sdk" -ne 0 ]; then just _doctor-msg end-both; fi
    fi

# Create the private vault (never committed)
[group('setup')]
brain-init:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -d brain ]; then echo "brain/ already exists."; exit 0; fi
    mkdir -p brain/01-journal brain/02-research brain/03-stack brain/04-chat-archive brain/05-files brain/_templates
    if [ -d .ai-backbone/brain-template ]; then
      cp -R .ai-backbone/brain-template/. brain/
      just _stamp-brain-lang brain/_templates/journal.md
    fi
    echo "brain/ created. Write in your own language. It is never committed."
    # A project fetched again after a lost disk arrives without its vault, and
    # the empty one made above is the wrong one to go on with: the next
    # session-end would lay its blank README and journal template over the ones
    # in the copy. Said, not done: a copy is filed under the project's name, and
    # only whoever is here can say that a new project of the same name is not the
    # old one come back.
    dest=$(just _vault-dest 2>/dev/null || true)
    if [ -n "$dest" ] && [ -d "$dest/brain" ]; then
      echo "A second copy of a brain/ under this project's name is in $dest"
      echo "If it is this project's, put it back before the next just session-end; $dest/about-this-copy.txt says how."
    fi

# Add the command layer for a language: just stack <language>  (just stack alone lists the ready ones)
[group('setup')]
[positional-arguments]
stack lang="":
    #!/usr/bin/env bash
    set -euo pipefail
    lang="$1"
    src=""
    if [ -n "$(just _is-backbone)" ]; then src="$PWD"; else src=$(just _backbone 2>/dev/null) || true; fi
    # The languages on offer are read from the file names in examples/, here and
    # in doctor's hint. They were written out by hand in five places, and a list
    # kept by hand is a list that is one short the day a layer is added.
    known=$(just _examples "$src" stack)
    if [ -z "$lang" ]; then
      echo "Ready layers: ${known:-none found (is the backbone nearby?)}"
      echo "Pick one: just stack <language>. For any other language, write stack.just by hand; the Justfile imports it automatically."
      exit 0
    fi
    # A project that already has a layer still gets the lint hook if it predates
    # one, so the second run of this command is a repair, not an error.
    if [ -f stack.just ]; then
      echo "stack.just already exists. Edit it, or remove it first."
      added=$(just _hook-lint || true)
      if [ -n "$added" ]; then echo "$added"; just hooks-install >/dev/null 2>&1 || true; exit 0; fi
      exit 1
    fi
    f="${src:+$src/.ai-backbone/examples/stack-$lang.just}"
    if [ -z "$f" ] || [ ! -f "$f" ]; then
      echo "No ready layer for '$lang'. Known: ${known:-none found (is the backbone nearby?)}"
      echo "Write stack.just by hand; the Justfile imports it automatically."; exit 1
    fi
    cp "$f" stack.just
    echo "stack.just added from stack-$lang.just. Edit it to fit. 'just --list' shows the new recipes."
    # The layer brings a lint; the hook that runs it comes with it, so a save
    # can never commit code the layer rejects.
    added=$(just _hook-lint || true)
    if [ -n "$added" ]; then echo "$added"; just hooks-install >/dev/null 2>&1 || true; fi
    # The update bot needs no workflow, so the hint no longer waits for one.
    if [ -f "$src/.ai-backbone/examples/ci-$lang.yml" ]; then
      echo "GitHub can run these checks on every push, and open update PRs: just ci-init $lang"
    elif [ -f "$src/.ai-backbone/examples/dependabot-$lang.yml" ]; then
      echo "GitHub can open a pull request when a package is behind: just ci-init $lang"
    fi

# Regenerate the rule copies and skill copies from AGENTS.md (tools row of section 0)
[group('setup')]
sync-rules:
    #!/usr/bin/env bash
    set -euo pipefail
    tools=$(just _tools)
    has() { case ",$tools," in *,all,*|*,"$1",*) return 0 ;; *) return 1 ;; esac; }
    gen() {
      if has "$1"; then
        mkdir -p "$(dirname "$2")"
        {
          printf '<!-- GENERATED FILE - do not edit.\n'
          printf '     Source of truth is AGENTS.md in the repo root.\n'
          printf '     Regenerate with: just sync-rules -->\n\n'
          cat AGENTS.md
        } > "$2"
        echo "  wrote $2"
      elif [ -f "$2" ]; then
        rm -f "$2"; rmdir "$(dirname "$2")" 2>/dev/null || true
        echo "  removed $2 ($1 is not in tools)"
      fi
    }
    gen copilot .github/copilot-instructions.md
    gen junie   .junie/guidelines.md
    # Skills live in .agents/skills/ (Codex and Gemini CLI read that folder).
    # Claude Code reads .claude/skills/, so each skill gets a copy there. A copy,
    # not a link: Git for Windows checks a link out as a small text file naming
    # its target, and Claude Code saw no skills at all there (spec 020). The rm
    # comes first, so an older link is replaced and never copied through.
    if has claude && [ -d .agents/skills ]; then
      mkdir -p .claude/skills
      for d in .agents/skills/*/; do
        [ -d "$d" ] || continue
        n=$(basename "$d")
        rm -rf ".claude/skills/$n"
        cp -R ".agents/skills/$n" ".claude/skills/$n"
        echo "  copied .claude/skills/$n"
      done
    fi
    echo "Rule copies regenerated from AGENTS.md (tools: $tools)."

# Update the tools this repo relies on: prek, graphify, the hook versions, a just that uv installed, and their pins in docs/upstream.toml
[group('setup')]
tools-update:
    #!/usr/bin/env bash
    set -uo pipefail
    if command -v uv >/dev/null 2>&1; then
      uv tool upgrade prek 2>&1 | tail -1
      uv tool upgrade graphifyy 2>&1 | tail -1
      # On Linux just came through uv (setup.sh: rust-just) and brew is not there
      # to move it; a pinned install stays pinned, which is uv's rule.
      case "$(uv tool list 2>/dev/null)" in *rust-just*) uv tool upgrade rust-just 2>&1 | tail -1 ;; esac
    else
      echo "uv missing -> curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
    if command -v brew >/dev/null 2>&1; then
      for t in just gh uv; do brew list --versions "$t" >/dev/null 2>&1 && brew upgrade "$t" 2>&1 | grep -E 'Upgrad|already' | tail -1; done
    fi
    if command -v prek >/dev/null 2>&1 && [ -f .pre-commit-config.yaml ]; then
      prek update 2>&1 | tail -3
    fi
    # A tool that lives as a binary and in no file has its pin in docs/upstream.toml
    # and nowhere else, so nothing held the two together: graphify was upgraded to
    # 0.9.64 here while its row still said 0.9.62, and `just upstream` went on
    # reporting as new what was already installed (2026-09-19). The pin means "the
    # version in use", so it follows what is installed, in the same run. Only
    # upwards: a machine whose upgrade did not go through must not pull the pin
    # back. Only a row that names no `pinned_in`: where a file holds the version,
    # that file is the truth and MOVED is how drift is said. And only that one
    # line of the file is rewritten; the list is the project's own.
    moved=""
    if [ -f docs/upstream.toml ]; then
      for pair in just=casey/just prek=j178/prek graphify=graphify-labs/graphify gh=cli/cli uv=astral-sh/uv; do
        tool="${pair%%=*}"
        have=$("$tool" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)
        [ -n "$have" ] || continue
        # "line<TAB>pin<TAB>name" of the first row that watches this tool and says no file holds its pin.
        row=$(awk -v want="github:${pair#*=}" '
          function val(s) { sub(/^[^"]*"/, "", s); sub(/".*$/, "", s); return s }
          function flush() { if (!said && src == want && at && !infile) { print at "\t" pin "\t" (name == "" ? want : name); said = 1 } }
          /^\[\[watch\]\]/           { flush(); src = ""; name = ""; pin = ""; at = 0; infile = 0; next }
          /^[ \t]*source[ \t]*=/     { src = tolower(val($0)) }
          /^[ \t]*name[ \t]*=/       { name = val($0) }
          /^[ \t]*pinned_in[ \t]*=/  { infile = 1 }
          /^[ \t]*pin[ \t]*=[ \t]*"/ { pin = val($0); at = FNR }
          END { flush() }' docs/upstream.toml)
        [ -n "$row" ] || continue
        IFS=$'\t' read -r at pin name <<< "$row"
        old="${pin#v}"
        grep -qE '^[0-9]+(\.[0-9]+)*$' <<< "$old" || continue
        [ "$old" != "$have" ] && [ "$(printf '%s\n%s\n' "$old" "$have" | sort -V | tail -1)" = "$have" ] || continue
        AT="$at" OLD="$old" NEW="$have" perl -pi -e 's/^(\s*pin\s*=\s*"v?)\Q$ENV{OLD}\E(")/$1$ENV{NEW}$2/ if $. == $ENV{AT}' docs/upstream.toml
        echo "docs/upstream.toml: $name pin $pin -> ${pin%"$old"}$have, the version now installed here."
        moved=" and docs/upstream.toml"
      done
    fi
    echo "Done. Review .pre-commit-config.yaml$moved with 'git diff', then 'just save'."

# Install the git hooks that check every save (leaked secrets, message style), and every push when the config has a pre-push hook
[group('setup')]
hooks-install:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v prek >/dev/null 2>&1; then
      echo "prek missing -> uv tool install prek"; exit 1
    fi
    # The lint hook too, if this project has a lint and is missing it. A
    # project made before this existed, or one whose `stack.just` was written by
    # hand rather than by `just stack`, has the recipe and not the hook — and
    # nothing told it so. `_hook-lint` is quiet when there is nothing to add.
    added=$(just _hook-lint 2>/dev/null || true)
    # And the push stage, when the config has a hook for it: a project whose
    # checks do not run on GitHub (Actions off, or no CI yet) runs `just test`
    # before every push (Smash, 2026-09-23). The seed config carries that hook
    # commented out; git runs it only once its shim is in .git/hooks/.
    push=$(just _push-stage)
    if [ -n "$push" ]; then prek install -t pre-commit -t commit-msg -t pre-push
    else prek install -t pre-commit -t commit-msg; fi
    if [ -n "$added" ]; then echo "$added"; fi
    # Fetch now what the hooks run, rather than inside the first save. Where it is
    # already there this takes a hundredth of a second and says nothing (measured
    # on prek 0.5.3). It matters in a sandbox: prek builds the secret scanner with
    # Go and downloads the Go it wants from go.dev, which is closed there, so every
    # commit failed, and with it about ninety checks of the first `just self-test`
    # of every scheduled run, until the agent found the way round by hand
    # (2026-09-19). The way round, once: prek's own log names the Go it went for
    # ("Installing go version=1.27.1", then the go.dev address); a Go that is
    # already on the machine fetches that toolchain through the module proxy
    # instead (`GOTOOLCHAIN=go1.27.1 go env GOROOT` downloads it and prints where
    # it landed); with that first on the PATH prek finds a Go it accepts and
    # downloads none. Measured on prek 0.5.3 with go 1.23.0 on the PATH, go.dev
    # closed by a proxy and an empty prek cache: the scanner was built, and a
    # later save went through with go.dev still closed and only the old Go on the
    # PATH. The log is this call's own file: the shared ~/.cache/prek/prek.log is
    # rewritten by every prek that runs. Never a reason to fail: the hooks are in
    # place either way, and the first save tries again. Not in offline mode, which
    # promises that nothing is fetched.
    if [ -z "${AI_BACKBONE_OFFLINE:-}" ]; then
      log=$(mktemp)
      if ! said=$(prek prepare-hooks --log-file "$log" 2>&1); then
        want=$(grep -oE '(Installing go version=|go\.dev/dl/go)[0-9]+(\.[0-9]+)+' "$log" 2>/dev/null | head -1 | grep -oE '[0-9]+(\.[0-9]+)+$' || true)
        built=""
        if [ -n "$want" ] && command -v go >/dev/null 2>&1 \
           && goroot=$(GOTOOLCHAIN="go$want" go env GOROOT 2>/dev/null) \
           && { ! command -v cygpath >/dev/null 2>&1 || goroot=$(cygpath -u "$goroot"); } \
           && [ -x "$goroot/bin/go" ]; then
          # Under Git Bash, Go answers C:\...: its colon split the PATH below in two,
          # so it goes through cygpath first, which only Git Bash has (spec 020).
          # The second answer replaces the first: if this fails too, it is the one worth reading.
          if said=$(PATH="$goroot/bin:$PATH" prek prepare-hooks 2>&1); then built=yes; fi
        fi
        if [ -n "$built" ]; then
          echo "prek could not download Go $want from go.dev, so the Go on this machine fetched it (GOTOOLCHAIN), and the hooks are built with that."
        else
          echo "What the hooks run could not be fetched yet; the first save tries again. prek said:"
          printf '%s\n' "$said" | sed -n '1,12s/^/  /p'
        fi
      fi
      rm -f "$log"
    fi
    # The subagent-cap hook too (spec 014): one PreToolUse group in the project's
    # own .claude/settings.json, merged beside its permissions and its other hooks
    # and never added twice. A project made before it existed gets it here, on the
    # next `just hooks-install` or `just template-update`.
    if [ -f .ai-backbone/budget.py ] && { [ -d .claude ] || [ -f .claude/settings.json ]; }; then
      if said=$("$(just _py)" .ai-backbone/budget.py hook add 2>/dev/null); then
        case "$said" in added|updated) echo "Subagent cap: in .claude/settings.json, $said. A session starts at most 8 on its own (git config --global ai-backbone.agent-cap <n> changes it)." ;; esac
      else
        echo "warn  the subagent cap hook could not be merged into .claude/settings.json (a comment or a trailing comma in it?): copy the PreToolUse group from the backbone's .claude/settings.json by hand."
      fi
    fi
    if [ -n "$push" ]; then echo "Hooks installed. They run on every save, and the pre-push ones before every push."
    else echo "Hooks installed. They run on every save."; fi

# ────────────────────────── session ──────────────────────────

# Read this before you start working
[group('session')]
session-start:
    #!/usr/bin/env bash
    # What an agent is shown of this is not what this prints. Claude Code hands a
    # SessionStart hook's output to the model whole only up to 10,000 characters;
    # past that it keeps the text in a file and shows the first 2,000 (measured
    # on 2.1.273, and seen in every session here for weeks: the journal alone was
    # 17,000 in one project, so the agent began each session with the head of a
    # diary and nothing else — no open spec, no backlog, no GitHub line). So the
    # body puts what is short and acted on first, bounds every block, and this
    # cuts the whole at 9,500 whatever it grew to, saying so.
    out=$(just _session-start-body 2>&1 || true)
    if [ "${#out}" -gt 9500 ]; then
      printf '%s\n' "${out:0:9500}"
      echo; echo "(cut at 9,500 characters: an agent is shown at most 10,000 of this; what is missing is in the files named above)"
    else
      printf '%s\n' "$out"
    fi

_session-start-body:
    #!/usr/bin/env bash
    set -uo pipefail
    # First, because it is what an agent must know before it starts anything:
    # about how much of the week is used, and how many subagents it may start
    # without asking (spec 014). The script never fails; without Python or a
    # meter this is one quiet line and the cap still holds, in the hook.
    lang=$(grep -E '^\| *chat_lang *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | tr -d ' `'); lang="${lang:-en}"
    if [ -f .ai-backbone/budget.py ]; then
      "$(just _py)" .ai-backbone/budget.py --line "$lang" 2>/dev/null \
        || echo "Backbone note: usage not measured (python3 is missing); the subagent cap holds."
    fi
    echo
    echo "=== WORKING TREE ==="
    git status --short 2>/dev/null | head -15 || true
    echo
    # The specs that are open, one line each. The journal says what was done and
    # the commits say what was saved; neither says what somebody is in the middle
    # of, and an agent that does not know a spec is open starts a second plan
    # beside it. A draft waits for the maintainer's word, an approved one for its
    # next task. Only the boxes under "## Tasks" are counted (the acceptance list
    # is walked at the end, not ticked on the way), and only [x] is ticked: a box
    # somebody marked [~] or [-] is work that is not finished. The first line of
    # the next task is quoted as written, with "…" when the task runs on. Quiet
    # when no spec is open, and in a project that has none.
    if ls docs/specs/*.md >/dev/null 2>&1; then
      awk '
        function flush() {
          if (status != "draft" && status != "approved") return
          line = "Spec " name " (" status (status == "draft" ? ", no code until approved" : "") "): "
          if (total == 0)         line = line "no tasks written yet"
          else if (ticked == total) line = line "all " total " tasks ticked. Walk its acceptance list, then close it (spec skill)"
          else                    line = line ticked " of " total " tasks ticked. Next: " todo
          print line
        }
        FNR == 1 { flush(); name = FILENAME; sub(/.*\//, "", name); sub(/\.md$/, "", name)
                   status = ""; fence = 0; tasks = 0; total = 0; ticked = 0; todo = ""; todo_at = 0 }
        { sub(/\r$/, "") }
        /^---[ \t]*$/ { if (FNR == 1 || fence > 0) fence++; next }
        fence == 1 && /^status:/ { status = $2; next }
        /^## / { tasks = ($0 ~ /^## +Tasks/); next }
        tasks && /^- \[.\]/ {
          total++
          if ($0 ~ /^- \[[xX]\]/) ticked++
          else if (todo == "") { todo = substr($0, 7); todo_at = FNR }
          next
        }
        tasks && todo_at && FNR == todo_at + 1 && /^[ \t]+[^ \t]/ { todo = todo " …" }
        END { flush() }
      ' docs/specs/*.md
    fi
    if [ -f graphify-out/GRAPH_REPORT.md ]; then
      echo "Code map: $(date -r graphify-out/GRAPH_REPORT.md '+%Y-%m-%d %H:%M')"
    elif [ -n "$(just _has-code 2>/dev/null)" ]; then
      echo "Code map: none -> just update-map"
    else
      echo "Code map: nothing to map yet"
    fi
    just template-check 2>/dev/null || true
    # A project without a GitHub address has one copy of its code, on this disk.
    # `just publish` offers to create the address, but only to somebody who types
    # it, and `just projects` shows the gap only to somebody who opens the
    # backbone; after the first day nothing said so. Said here at every session
    # for as long as it is true, so that the agent brings it up with the person:
    # the agent does not run publish on its own, because that creates a repository
    # under the person's account. It asks git and nothing else, so it is said in
    # offline mode too.
    if git rev-parse --git-dir >/dev/null 2>&1 && ! git remote get-url origin >/dev/null 2>&1; then
      echo "GitHub: no address yet. This code has no second copy; it lives on this machine only. Ask the person, then -> just publish"
    fi
    # How the last push went, in one line and only when it is not good news.
    # Stamped on the commit rather than on a week, the way the two blocks at the
    # end of this recipe are: a red default branch is news today, and the answer
    # changes only when the commit does, so this is one question per push. Quiet
    # when it passed, offline, without gh, and without an address.
    cistamp=$(git rev-parse --git-path ai-backbone.last-ci 2>/dev/null || echo .git/ai-backbone.last-ci)
    if [ -n "$(just _is-repo)" ] && [ -d .github/workflows ] && [ -z "${AI_BACKBONE_OFFLINE:-}" ] \
       && command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
      at=$(git rev-parse HEAD 2>/dev/null || echo "")
      if [ -n "$at" ] && [ "$at" != "$(cat "$cistamp" 2>/dev/null || true)" ]; then
        r=$(GH_PAGER=cat gh run list --commit "$at" --limit 1 --json workflowName,status,conclusion \
              -q '.[] | [.workflowName, .status, .conclusion] | @tsv' 2>/dev/null || true)
        IFS=$'\t' read -r wf st cc <<< "$r"
        case "${st:-}" in
          completed) printf '%s' "$at" > "$cistamp"
                     [ "${cc:-}" = success ] || echo "Checks: ${wf:-the checks} ${cc:-did not pass} on this commit -> just ci" ;;
          "")        : ;;
          *)         echo "Checks: ${wf:-the checks} still going -> just ci" ;;
        esac
      fi
    fi
    # The backbone itself: bring in what a scheduled agent (or another machine) pushed.
    if [ -n "$(just _is-backbone)" ] && git remote get-url origin >/dev/null 2>&1; then
      just _backbone-level "$PWD" GitHub
      just _backbone-tag "$PWD"
    fi
    if [ -n "$(just _is-backbone)" ] && [ -f docs/backlog.md ]; then
      open=$(grep -c '^- \[ \]' docs/backlog.md || true)
      if [ "${open:-0}" -gt 0 ]; then
        echo; echo "=== BACKLOG ($open open, from the projects; the newest are shown, the file has them all, oldest first) ==="
        grep '^- \[ \]' docs/backlog.md | tail -10 | cut -c1-150 | sed 's/$/ …/'
      fi
      wait=$(grep -c '^- \[?\]' docs/backlog.md || true)
      if [ "${wait:-0}" -gt 0 ]; then
        echo; echo "=== WAITING FOR THE MAINTAINER ($wait; not yours to build, only theirs to answer) ==="
        grep '^- \[?\]' docs/backlog.md | cut -c1-300
      fi
    fi
    # What the scheduled agent left for whoever comes next. Its sandbox keeps
    # nothing, so this file is the only memory a run has of the one before it.
    if [ -n "$(just _is-backbone)" ] && [ -f docs/routine-log.md ]; then
      echo; echo "=== LAST ROUTINE RUNS (docs/routine-log.md) ==="
      grep '^- ' docs/routine-log.md | tail -2 | cut -c1-300
    fi
    # In a project, not the backbone: show what this project reported and what
    # came of it. A maintainer who never opens the backbone folder still needs
    # to know that a note was taken, and that somebody answered it.
    if [ -z "$(just _is-backbone)" ] && src=$(just _backbone 2>/dev/null) && [ -f "$src/docs/backlog.md" ]; then
      project=$(grep -E '^\| *project *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
      project="${project:-$(basename "$PWD")}"
      mine_open=$(grep -F ", $project:" "$src/docs/backlog.md" 2>/dev/null | grep '^- \[ \]' || true)
      mine_done=$(grep -F ", $project:" "$src/docs/backlog.md" 2>/dev/null | grep '^- \[x\]' | tail -2 || true)
      if [ -n "$mine_open" ] || [ -n "$mine_done" ]; then
        echo; echo "=== BACKBONE NOTES FROM THIS PROJECT ==="
        if [ -n "$mine_open" ]; then
          echo "still open:"; echo "$mine_open" | cut -c1-160 | sed 's/^/  /'
        fi
        if [ -n "$mine_done" ]; then
          echo "answered:"; echo "$mine_done" | cut -c1-160 | sed 's/^/  /'
        fi
        echo "  (leave one: just backbone-note \"what you noticed\")"
      fi
    fi
    echo; echo "=== LAST COMMITS ==="
    git log --oneline -8 2>/dev/null | cut -c1-120 || { [ -n "$(just _is-repo)" ] && echo "(nothing saved yet)" || echo "(no git repo)"; }
    # The journal last, and only its head: what was done is in the commits and the
    # specs above; a day with two sessions ran to 17,000 characters and pushed
    # everything else out of the agent's sight. The file is named for the rest.
    echo; echo "=== LAST JOURNAL (head) ==="
    if ls brain/01-journal/*.md >/dev/null 2>&1; then
      ls -1t brain/01-journal/*.md | head -2 | { read -r f; echo "-- $f"; head -c 2000 "$f"; echo
        [ "$(wc -c < "$f" | tr -d ' ')" -le 2000 ] || echo "(… the rest is in $f)"
        if read -r g; then echo "-- $g: $(grep -m1 '^# ' "$g" | cut -c1-100)"; fi; }
    else
      echo "(no journal entries yet)"
    fi
    # Once a week, say what the tools have released. The stamp lives in .git/
    # so it is per machine and never committed. Quiet when gh is missing, and in
    # offline mode, where neither weekly block runs or uses up its week.
    stamp=$(git rev-parse --git-path ai-backbone.last-check 2>/dev/null || echo .git/ai-backbone.last-check)
    if [ -n "$(just _is-repo)" ] && [ -z "${AI_BACKBONE_OFFLINE:-}" ] && command -v gh >/dev/null 2>&1 \
       && [ -z "$(find "$stamp" -mtime -7 2>/dev/null)" ]; then
      echo; echo "=== TOOL RELEASES (weekly check) ==="
      just _backbone-news 2>/dev/null || true
      touch "$stamp"
    fi
    # What this project is built on, on the same weekly rhythm. The list is the
    # project's own (docs/upstream.toml); quiet when there is none. A check that
    # could not run says so: behind `|| true` a python3 too old for it failed
    # every week and printed nothing. The week is used up only by a run that
    # learned something: one that could not run, or that ends in upstream.py's
    # "No source gave an answer" (a dead network, a proxy that refuses every
    # source), is asked again at the next session instead of in seven days.
    up=$(git rev-parse --git-path ai-backbone.last-upstream 2>/dev/null || echo .git/ai-backbone.last-upstream)
    if [ -n "$(just _is-repo)" ] && [ -f docs/upstream.toml ] && [ -z "${AI_BACKBONE_OFFLINE:-}" ] \
       && [ -z "$(find "$up" -mtime -7 2>/dev/null)" ]; then
      echo; echo "=== WHAT THIS PROJECT IS BUILT ON (weekly check) ==="
      if seen=$(just upstream 2>/dev/null); then
        printf '%s\n' "$seen"
        grep -q '^No source gave an answer' <<< "$seen" || touch "$up"
      else
        [ -z "$seen" ] || printf '%s\n' "$seen"
        echo "upstream: could not run -> just upstream"
      fi
    fi
    # Every session, and without the network: what the project is built on and
    # which of those pins came out in the last twelve months, from what the weekly
    # run above cached. An agent's training ends on a day; a version released
    # after it is one the agent has never seen, and nothing else here says so.
    if [ -f docs/upstream.toml ]; then echo; "$(just _py)" .ai-backbone/upstream.py --recent 2>/dev/null || true; fi

# Open today's journal entry, copy brain/ to its second place, then save
[group('session')]
session-end:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p brain/01-journal
    f="brain/01-journal/$(date +%Y-%m-%d).md"
    if [ ! -f "$f" ]; then
      if [ -f brain/_templates/journal.md ]; then cp brain/_templates/journal.md "$f"; else touch "$f"; fi
      just _stamp-brain-lang "$f"
      echo "Created $f"
    else
      echo "Exists  $f"
    fi
    echo 'Fill in the entry. It is private: git never holds it and it is never part of a save.'
    echo 'If code changed something docs/ describes, update docs/. Then: just save "..."'
    # The second copy, last, and never in the way: a session that cannot copy
    # still ends. `_vault-copy` says what it did in its own words.
    just _vault-copy || true

# Start a spec for an idea: docs/specs/NNN-<name>.md, written before the code
[group('session')]
[positional-arguments]
spec name:
    #!/usr/bin/env bash
    set -euo pipefail
    name="$1"
    mkdir -p docs/specs
    # File names are ASCII and dashed: "Yapılacaklar Listesi" -> 002-yapilacaklar-listesi.md
    slug=$(just _slug "$name")
    if [ -z "$slug" ]; then echo "Give the spec a name, e.g. just spec login-page"; exit 1; fi
    last=$(ls docs/specs 2>/dev/null | grep -oE '^[0-9]{3}' | sort -n | tail -1 || true)
    id=$(printf '%03d' $((10#${last:-0}+1)))
    f="docs/specs/$id-$slug.md"
    if [ -f "$f" ]; then echo "Exists  $f"; exit 0; fi
    title=$(printf '%s\n' "$name" | tr '_-' '  ' | sed 's/[&|\\]/\\&/g')
    today=$(date +%Y-%m-%d)
    tpl=.ai-backbone/templates/spec.md
    if [ -f "$tpl" ]; then
      sed -e "s|^date: YYYY-MM-DD|date: $today|" -e "s|^# NNN — Title|# $id — $title|" "$tpl" > "$f"
    else
      printf -- '---\nstatus: draft\ndate: %s\n---\n\n# %s — %s\n' "$today" "$id" "$title" > "$f"
    fi
    echo "Created $f"
    echo "Fill it in with the maintainer, one question per turn. No code until they say approved."

# The questions an audit asks about this project: docs/audit-lenses.md
[group('session')]
audit-lenses:
    #!/usr/bin/env bash
    set -euo pipefail
    f=docs/audit-lenses.md
    if [ -f "$f" ]; then
      echo "$f"
      echo
      grep -E '^###? ' "$f" | sed 's/^#* /  /'
      echo
      echo "Ask your agent to run the audit skill. It reads this file."
      exit 0
    fi
    mkdir -p docs
    tpl=.ai-backbone/templates/audit-lenses.md
    if [ -f "$tpl" ]; then cp "$tpl" "$f"; else
      printf '# Audit lenses\n\nOne question per lens, about this codebase.\n' > "$f"
    fi
    echo "Created $f"
    echo "Four lenses are in it already. Add this project's own from docs/adr and docs/specs."
    echo "Then ask your agent to run the audit skill, at the end of a phase."

# Record a design decision: docs/adr/NNNN-<name>.md. One that changes an earlier one: just adr <name> --amends NNNN "what changed"
[group('session')]
[positional-arguments]
adr name *amends:
    #!/usr/bin/env bash
    set -euo pipefail
    # just adr <name> --amends NNNN ["what changed, in one line"]. A decision
    # that changes an earlier one says so in the earlier one too: its Status line
    # gains "amended by", a link, the date and one line, so whoever lands on the
    # old decision is sent on to the new one. Smash did it by hand for ADR 0016,
    # which amends 0002 and 0007 (2026-09-22), and the rule that an amended ADR
    # gets one pointer line is easy to forget. The line is also what `just stale`
    # reads: an amended file keeps its old names on purpose and is left alone.
    # The words are read in any order, so `--amends 0002` may come first.
    name=""; amends=""; why=""; want=""
    for a in "$@"; do
      if [ -n "$want" ]; then amends="$a"; want=""; continue; fi
      case "$a" in
        --amends) want=yes ;;
        --amends=*) amends="${a#--amends=}" ;;
        *) if [ -z "$name" ]; then name="$a"; elif [ -z "$why" ]; then why="$a"
           else echo "Too many words. A name of several words goes in quotes: just adr \"why sqlite\""; exit 1; fi ;;
      esac
    done
    if [ -n "$want" ] || { [ -n "$why" ] && [ -z "$amends" ]; }; then
      if [ -n "$want" ]; then echo "Which decision does it amend? For example: just adr two-apps --amends 0002"
      else echo "A second word is read only after --amends. A name of several words goes in quotes: just adr \"$name $why\""; fi
      exit 1
    fi
    slug=$(just _slug "$name")
    if [ -z "$slug" ]; then echo "Give the decision a name, e.g. just adr why-sqlite"; exit 1; fi
    # The decision it amends is found before anything is written, so a wrong
    # number leaves no new file behind.
    old=""
    if [ -n "$amends" ]; then
      case "$amends" in ""|*[!0-9]*) echo "--amends takes the number of a decision, e.g. --amends 0002"; exit 1 ;; esac
      oid=$(printf '%04d' $((10#$amends)))
      for o in docs/adr/"$oid"-*.md; do if [ -f "$o" ]; then old="$o"; break; fi; done
      if [ -z "$old" ]; then echo "There is no decision $oid in docs/adr/. Nothing was written."; exit 1; fi
    fi
    mkdir -p docs/adr
    last=$(ls docs/adr 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1 || true)
    id=$(printf '%04d' $((10#${last:-0}+1)))
    f="docs/adr/$id-$slug.md"
    if [ -f "$f" ]; then echo "Exists  $f"; exit 0; fi
    title=$(printf '%s\n' "$name" | tr '_-' '  ' | sed 's/[&|\\]/\\&/g')
    today=$(date +%Y-%m-%d)
    tpl=.ai-backbone/templates/adr.md
    if [ -f "$tpl" ]; then
      sed -e "s|^\*\*Date:\*\* YYYY-MM-DD|**Date:** $today|" -e "s|^# NNNN — Title|# $id — $title|" "$tpl" > "$f"
    else
      printf -- '# %s — %s\n\n**Status:** accepted\n**Date:** %s\n\n## Context\n\n## Decision\n\n## Consequences\n' "$id" "$title" "$today" > "$f"
    fi
    echo "Created $f"
    if [ -n "$old" ]; then
      # Both files are rewritten through awk, which every system has in some
      # form (BSD awk on a Mac, mawk or gawk on Linux); `sed -i` takes its
      # argument differently on each. The typed words reach awk through the
      # environment, where a backslash or an & means nothing.
      why=$(printf '%s' "${why:-$(printf '%s' "$name" | tr '_-' '  ')}" | tr '\n\r\t' '   ')
      link="[$id]($(basename "$f"))"; oldlink="[$oid]($(basename "$old"))"
      t=$(mktemp)
      # The new one names the old one on its Relates line: the template's
      # three-line prompt is replaced, or the line goes under the Date.
      rel=""; if grep -q '^\*\*Relates to:\*\*' "$f"; then rel=yes; fi
      L="$oldlink" R="$rel" awk '
        !done && ENVIRON["R"] != "" && /^\*\*Relates to:\*\*/ { print "**Relates to:** amends " ENVIRON["L"] "."; done = 1; skip = 1; next }
        skip && (/^\*\*/ || /^[ \t]*$/ || /^#/) { skip = 0 }
        skip { next }
        { print }
        !done && ENVIRON["R"] == "" && /^\*\*Date:\*\*/ { print "**Relates to:** amends " ENVIRON["L"] "."; done = 1 }
      ' "$f" > "$t" && cat "$t" > "$f"
      # The old one: its first Status line gains the pointer; a second
      # amendment adds "and by". A YAML front matter at the top (`---` ...
      # `---`, the MADR style) is passed over: its `status:` key is data, and
      # the value written here holds ": ", which is not valid YAML there. The
      # Status line is looked for in the whole file, not only above the first
      # section, so a decision that keeps it under ## Context is not given a
      # second one (spec 015 review). With none at all, one goes under the title.
      L="$link" D="$today" W="$why" awk '
        function tail(s) { return s ~ /amended by/ ? "; and by " : "; amended by " }
        done { print; next }
        NR == 1 && /^---[ \t]*$/ { infm = 1; held[++h] = $0; next }
        infm { if ($0 ~ /^---[ \t]*$/) infm = 0; held[++h] = $0; next }
        /^(\*\*)?[Ss]tatus(:\*\*|\*\*:|:)/ {
          for (i = 1; i <= h; i++) print held[i]
          body = $0; ws = ""
          if (match(body, /[ \t]+$/)) { ws = substr(body, RSTART); body = substr(body, 1, RSTART - 1) }
          print body tail(body) ENVIRON["L"] " on " ENVIRON["D"] ": " ENVIRON["W"] ws
          done = 1; next }
        { held[++h] = $0 }
        END {
          if (done) exit 0
          # No Status line: under the first title, or at the top.
          put = 0
          for (i = 1; i <= h; i++) {
            print held[i]
            if (!put && held[i] ~ /^# /) { print ""; print "**Status:** accepted; amended by " ENVIRON["L"] " on " ENVIRON["D"] ": " ENVIRON["W"]; put = 1 }
          }
          if (!put) { print "**Status:** accepted; amended by " ENVIRON["L"] " on " ENVIRON["D"] ": " ENVIRON["W"] }
        }
      ' "$old" > "$t" && cat "$t" > "$old"
      rm -f "$t"
      echo "Pointed $old at it: $(grep -m1 -E '^(\*\*)?[Ss]tatus' "$old" || true)"
    fi
    echo "Context, decision, consequences. Short. It is public documentation."

# ─────────────────────────── safety ──────────────────────────

# Save your work on this machine (git commit)
[group('safety')]
[positional-arguments]
save msg:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "$(just _is-repo)" ]; then echo "No git repo yet. Run: git init"; exit 1; fi
    git add -A
    if git diff --cached --quiet; then just _msg nothing-new; exit 0; fi
    msg="$1"
    # Messages start with the kind of change. A plain message gets "chore: ".
    if ! printf '%s' "$msg" | grep -qE '^(feat|fix|docs|chore|test|refactor|style|perf|build|ci|revert)(\([^)]*\))?!?: '; then
      msg="chore: $msg"
    fi
    git status --short
    # The checks run inside the commit; the first one ever also downloads the
    # secret scanner, so say something while it works. Their output is shown
    # only when they fail. A check that fixes files (final newline, trailing
    # spaces) fails once on purpose, so stage its fixes and try a second time.
    just _msg checking
    # A build already running elsewhere is waited for here, where the person
    # can see the line that says so, and not inside the checks, whose output is
    # kept until they fail: a save that sat silent for twenty minutes looked
    # hung (spec 015 review). Once waited for, the checks do not wait again; if
    # the wait gave up at its limit, they build with the smaller share it chose.
    cap=$(just _build-wait || true)
    [ -z "$cap" ] || export "$cap"
    export BUILD_WAIT_MINUTES=0
    out=$(mktemp)
    if ! git commit -q -m "$msg" >"$out" 2>&1; then
      git add -A
      if ! git commit -q -m "$msg" >"$out" 2>&1; then
        grep -vE "(Passed|Skipped)$|error: recipe" "$out" || true
        # One refusal gets words of its own: a file over the size limit. "Fix what
        # the check above says" gives somebody who is no programmer no way out,
        # and because a save stages everything, that one file then stops every
        # save. The hook's own line is read: "  path (5200 KB) exceeds 5000 KB"
        # from prek 0.5.3 (measured), with a full stop from pre-commit. So the
        # limit named is the one this project's own .pre-commit-config.yaml sets.
        # The limit itself is not raised here: nobody has measured a real asset.
        big=$(sed -nE 's/^[[:space:]]*(.+ \([0-9]+ KB\)) exceeds [0-9]+ KB\.?[[:space:]]*$/\1/p' "$out")
        limit=$(sed -nE 's/^.+ \([0-9]+ KB\) exceeds ([0-9]+) KB\.?[[:space:]]*$/\1/p' "$out" | awk 'NR==1')
        rm -f "$out"; echo
        if [ -z "$big" ]; then just _msg not-saved; exit 1; fi
        # too-big is a printf format with one %s, the limit.
        printf "$(just _msg too-big)\n" "$limit"
        # Each file is also taken back out of what is staged. The refused save put
        # it there, and git goes on tracking a staged file after it is ignored: the
        # agent added it to .gitignore, saved again, and was refused again for the
        # same file (measured). The hook names only files this save would add. One
        # path at a time, never the whole index: `git reset` with no path also ends
        # a merge that is in progress (measured on git 2.55.0).
        while IFS= read -r line; do
          printf '  %s\n' "$line"
          git reset -q -- "${line% (*}" 2>/dev/null || true
        done <<<"$big"
        just _msg too-big-next
        exit 1
      fi
    fi
    rm -f "$out"
    just _msg saved
    # A repository can ask for every save to reach GitHub as well, so that no
    # work exists only on one disk. Off unless somebody turned it on, because
    # the promise elsewhere is that nothing leaves the machine unasked.
    if [ "$(git config --get ai-backbone.publish-on-save 2>/dev/null || echo false)" = "true" ] \
       && git remote get-url origin >/dev/null 2>&1; then
      # --follow-tags: a version's tag goes where its commit goes (spec 016).
      # Inside the backbone, main is the gate's to move (spec 017).
      if [ -n "$(just _is-backbone)" ] && [ "$(git symbolic-ref -q --short HEAD 2>/dev/null)" = main ]; then
        echo "  not sent to GitHub: the backbone's work travels on cloud (just publish says how)"
      elif git push -q origin HEAD --follow-tags 2>/dev/null; then
        echo "  -> GitHub"
      else
        echo "  not sent to GitHub — saved here. Try: just publish"
      fi
    fi

# Every save also goes to GitHub, or stops doing so: just publish-on-save off
[group('safety')]
[positional-arguments]
publish-on-save mode="on":
    #!/usr/bin/env bash
    set -euo pipefail
    case "$1" in
      on|true|yes)
        if ! git remote get-url origin >/dev/null 2>&1; then
          echo "No GitHub address yet. Run: just publish"; exit 1
        fi
        git config ai-backbone.publish-on-save true
        echo "On. Every 'just save' now sends to GitHub as well, so nothing lives on one disk only."
        echo "Off again: just publish-on-save off" ;;
      off|false|no)
        git config --unset ai-backbone.publish-on-save 2>/dev/null || true
        echo "Off. 'just save' keeps work on this machine; 'just publish' sends it." ;;
      *) echo "Say on or off: just publish-on-save on"; exit 1 ;;
    esac

# Send saved work to GitHub; offers to create the repo when there is no address yet
[group('safety')]
publish:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! git remote get-url origin >/dev/null 2>&1; then
      name=$(just _slug "$(basename "$PWD")")
      just _msg no-remote
      if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && [ -t 0 ]; then
        printf '%s' "$(just _msg create-repo)"; read -r a || a=""
        case "$a" in
          y|Y|e|E) gh repo create "$name" --private --source=. --remote=origin >/dev/null
                   echo "  created  github.com/$(gh api user -q .login)/$name (private)" ;;
          *)       just _msg nothing-sent; exit 0 ;;
        esac
      else
        echo "To create one:"
        echo "  gh repo create $name --private --source=. --push"
        exit 0
      fi
    fi
    # Inside the backbone, main is the gate's to move (spec 017): work travels
    # on cloud, and a push to main from here would skip the three machines.
    if [ -n "$(just _is-backbone)" ] && [ "$(git symbolic-ref -q --short HEAD 2>/dev/null)" = main ]; then
      echo "Not sent: the backbone's work travels on cloud, and the gate carries it to main (spec 017)."
      echo "  git checkout -B cloud origin/cloud && git merge main   # take what is saved on main here along"
      echo "  just publish                                           # to cloud; afterwards: git branch -f main origin/main"
      exit 1
    fi
    git push -q -u origin HEAD --follow-tags
    just _msg published
    # "The checks start now" is a promise, and where the checks are switched off
    # on GitHub it was untrue on every publish: three of the maintainer's four
    # repositories had them off on 2026-09-19 (measured). Nothing is said there
    # instead; `just ci` says why. Only a plain `false` silences the line:
    # no gh, no login, offline mode or no answer leave it as it was.
    if [ -d .github/workflows ]; then
      on=""
      if [ -z "${AI_BACKBONE_OFFLINE:-}" ] && command -v gh >/dev/null 2>&1; then
        on=$(GH_PAGER=cat gh api 'repos/{owner}/{repo}/actions/permissions' -q .enabled </dev/null 2>/dev/null || true)
      fi
      [ "$on" = false ] || echo "The checks start now. In a minute: just ci"
    fi

# Cut a version of this project: just release — or patch, minor, major (spec 016)
#
# A project has a version of its own, not only the backbone's: semver.org, in
# its CHANGELOG.md after keepachangelog.com, as a tag vX.Y.Z that goes to GitHub
# with the backup. It is cut at a meaningful point — when a spec is done, and
# when a fix goes out on its own between specs — by the agent; the person types
# nothing. The step is read from the commits since the last version, which say
# their kind already (the commit hook sees to that): a feat makes the next
# minor, anything else the next patch, a breaking change (`feat!:`, or
# BREAKING CHANGE: in the body) the next major from 1.0.0 on and the next minor
# below it. 1.0.0 is the first version other people rely on, and it is cut only
# on the maintainer's word: `just release major`. Nothing computes its way there.
[group('safety')]
[positional-arguments]
release step="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "$(just _is-repo)" ]; then echo "No git repo yet. Run: git init"; exit 1; fi
    if [ -n "$(just _is-backbone)" ]; then
      echo "The backbone's own versions are cut by hand: line 1 of core.just, CHANGELOG.md, a tag. This is for projects."; exit 1
    fi
    step="${1:-}"
    case "$step" in ""|patch|minor|major) ;; *) echo "just release takes patch, minor or major, or nothing, and then the commits say which."; exit 1 ;; esac
    # A version names a saved state, and nothing else.
    if [ -n "$(git status --porcelain)" ]; then
      echo "Not released: there is work not saved yet. A version is a saved state: just save, then just release."; exit 1
    fi
    if ! git rev-parse -q --verify HEAD >/dev/null; then echo "Nothing to release yet: there is no save."; exit 0; fi
    # The last version: the highest vX.Y.Z tag. A pre-release tag (v1.0.0-rc.1)
    # is not a version this recipe counts from.
    last=$(git tag --list 'v[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1.2,1n -k2,2n -k3,3n | tail -n 1 || true)
    if [ -n "$last" ]; then range="$last..HEAD"; else range=HEAD; fi
    # Every commit since, one record each: its subject, then its body.
    log=$(mktemp); trap 'rm -f "$log"' EXIT
    git log --no-merges --format='%s%x1f%b%x1e' $range > "$log"
    count=$(tr -cd '\036' < "$log" | wc -c | tr -d ' ')
    if [ -n "$last" ] && [ "$count" -eq 0 ]; then echo "Nothing to release: no save since $last."; exit 0; fi
    # What the commits say. `kind(scope)!: ` at the front; a `!` or a
    # BREAKING CHANGE line in the body is a breaking change.
    read -r feat breaking <<<"$(awk 'BEGIN { RS = "\036"; FS = "\037" }
      NF { s = $1; sub(/^[ \t\n]+/, "", s)
           if (s ~ /^feat(\([^)]*\))?!?: /) f++
           if (s ~ /^[a-z]+(\([^)]*\))?!: / || $2 ~ /(^|\n)BREAKING[ -]CHANGE: /) b++ }
      END { print f + 0, b + 0 }' "$log")"
    if [ -z "$last" ]; then
      # The first version. 0.1.0 whatever the commits say, unless the
      # maintainer has said this first one is the one people rely on.
      if [ "$step" = major ]; then next=1.0.0; else next=0.1.0; fi
    else
      IFS=. read -r X Y Z <<<"${last#v}"
      if [ -z "$step" ]; then
        if [ "$breaking" -gt 0 ]; then if [ "$X" -ge 1 ]; then step=major; else step=minor; fi
        elif [ "$feat" -gt 0 ]; then step=minor
        else step=patch; fi
      fi
      case "$step" in
        major) next="$((X + 1)).0.0" ;;
        minor) next="$X.$((Y + 1)).0" ;;
        patch) next="$X.$Y.$((Z + 1))" ;;
      esac
    fi
    tag="v$next"
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then echo "Not released: the tag $tag is there already."; exit 1; fi
    today=$(date +%Y-%m-%d)
    # The entry. What the Unreleased section already says, when somebody wrote
    # it; otherwise a draft from the commits, for whoever uses the thing: what
    # was added, fixed and changed, one line each, a subject cut at its first
    # " — " so that a long one is one line. Chores, docs, tests and the like are
    # not what a reader of a changelog came for, and are left out of a draft.
    new=0; [ -f CHANGELOG.md ] || new=1
    if [ "$new" -eq 1 ]; then
      printf '%s\n' '# Changelog' '' \
        'What each version of this project changed, newest first. The format follows' \
        '[Keep a Changelog](https://keepachangelog.com), and the versions follow' \
        '[Semantic Versioning](https://semver.org).' '' '## [Unreleased]' > CHANGELOG.md
    fi
    body=$(mktemp); cl=$(mktemp)
    awk '/^## \[Unreleased\]/ { on = 1; next } on && /^## / { exit } on' CHANGELOG.md | sed -e '/./,$!d' > "$body" || true
    if [ -z "$(tr -d ' \t\n' < "$body")" ]; then
      awk 'BEGIN { RS = "\036"; FS = "\037" }
        NF { s = $1; sub(/^[ \t\n]+/, "", s)
             if (match(s, /^[a-z]+(\([^)]*\))?!?: /)) { k = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1) } else k = ""
             i = index(s, " — "); if (i > 0) s = substr(s, 1, i - 1)
             if (length(s) > 300) s = substr(s, 1, 297) "..."
             if (k ~ /^feat/) a[++na] = s
             else if (k ~ /^fix/) f[++nf] = s
             else if (k ~ /^(perf|refactor|revert)/) c[++nc] = s }
        END {
          if (na) { print "### Added"; for (j = na; j >= 1; j--) print "- " a[j]; print "" }
          if (nf) { print "### Fixed"; for (j = nf; j >= 1; j--) print "- " f[j]; print "" }
          if (nc) { print "### Changed"; for (j = nc; j >= 1; j--) print "- " c[j]; print "" }
          if (!na && !nf && !nc) print "- Maintenance: nothing a user of this project would notice." }' "$log" > "$body"
    fi
    # The Unreleased section keeps its heading and loses its text, and the
    # version's own section goes under it. A changelog that never had an
    # Unreleased section gets one, above the first version.
    awk -v head="## [$next] - $today" -v bodyf="$body" '
      function entry(   l) { print "## [Unreleased]"; print ""; print head; print ""
                             while ((getline l < bodyf) > 0) print l; close(bodyf) }
      /^## \[Unreleased\]/ && !done { entry(); skip = 1; done = 1; next }
      skip && /^## / { skip = 0; print ""; }
      skip { next }
      /^## / && !done { entry(); print ""; done = 1 }
      { print }
      END { if (!done) { print ""; entry() } }' CHANGELOG.md | cat -s \
      | awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--; for (i = 1; i <= n; i++) print l[i] }' > "$cl"
    # Ending in exactly one newline: the end-of-file check refuses anything else.
    cat "$cl" > CHANGELOG.md; rm -f "$cl" "$body"
    # The language's own manifest, where the layer knows one: `xlarge
    # --version` should say what the tag says.
    if just --show _set-version >/dev/null 2>&1; then just _set-version "$next"; fi
    git add -A
    out=$(mktemp)
    # The same second try a save makes: a check that fixes a file (a trailing
    # space, a final newline) fails once on purpose, and its fix is staged.
    if ! git commit -q -m "chore(release): $tag" >"$out" 2>&1 \
       && ! { git add -A && git commit -q -m "chore(release): $tag" >"$out" 2>&1; }; then
      grep -vE "(Passed|Skipped)$" "$out" || true; rm -f "$out"
      # Back to the saved state this started from: nothing half-released.
      git reset -q; git checkout -q -- .
      if [ "$new" -eq 1 ]; then rm -f CHANGELOG.md; fi
      echo "Not released: the checks refused the release commit. Nothing changed."; exit 1
    fi
    rm -f "$out"
    git tag -a "$tag" -m "$tag"
    echo "Released $tag${last:+ (after $last)}. CHANGELOG.md says what is in it."
    # With publish-on-save on, the release goes to GitHub the way a save does,
    # and its tag with it. Off, it stays here until `just publish`.
    if [ "$(git config --get ai-backbone.publish-on-save 2>/dev/null || echo false)" = "true" ] \
       && git remote get-url origin >/dev/null 2>&1; then
      if git push -q origin HEAD --follow-tags 2>/dev/null; then echo "  -> GitHub, with $tag"
      else echo "  not sent to GitHub — released here. Try: just publish"; fi
    fi

# How the last push went: just ci · just ci 35093270742 for one older run
[group('safety')]
[positional-arguments]
ci run="":
    #!/usr/bin/env bash
    set -uo pipefail
    # This is a report. A sub-command that cannot answer must not kill it, and a
    # red build is an answer rather than an error, so every path here exits 0 —
    # the same promise `doctor` and `upstream` make.
    # gh pages its own output into `less` when it can see a terminal, and the
    # log of one failed job is thousands of lines.
    export GH_PAGER=cat
    if [ -z "$(just _is-repo)" ]; then echo "No git repo yet. Run: git init"; exit 0; fi
    if [ -z "$1" ] && ! compgen -G '.github/workflows/*.y*ml' >/dev/null; then
      echo "No checks in this project yet. Add them: just ci-init"; exit 0
    fi
    if ! git remote get-url origin >/dev/null 2>&1; then
      echo "No GitHub address yet, so nothing has run there. Send this project: just publish"; exit 0
    fi
    # Before anything reaches the network, so a machine on a train and the
    # self-test both stop here rather than halfway through.
    if [ -n "${AI_BACKBONE_OFFLINE:-}" ]; then
      echo "Offline mode is on (AI_BACKBONE_OFFLINE). GitHub was not asked."; exit 0
    fi
    if ! command -v gh >/dev/null 2>&1; then
      echo "gh missing -> brew install gh   (or see cli.github.com)"; exit 0
    fi
    if ! gh auth status >/dev/null 2>&1; then
      echo "Needs gh, logged in: gh auth login"; exit 0
    fi
    F=databaseId,workflowName,displayTitle,headSha,headBranch,status,conclusion,createdAt,event,url
    # Every empty field is sent as "-" and read back as empty. jq writes an
    # empty string between two tabs, and `read` with a tab IFS folds a run of
    # tabs into one separator, so one unfinished run silently shifts every
    # column after it — which is how the first in-progress run this was pointed
    # at printed its event where its time should have been.
    ROW='[(.databaseId|tostring),.workflowName,(.headSha[0:7]),.headBranch,.status,(.conclusion // "-"|if . == "" then "-" else . end),.createdAt,.event,.url,(.displayTitle[0:70]|if . == "" then "-" else . end)]|@tsv'
    runs=$(mktemp); jobs=$(mktemp); log=$(mktemp)
    trap 'rm -f "$runs" "$jobs" "$log"' EXIT
    older=""
    if [ -n "$1" ]; then
      out=$(gh run view "$1" --json "$F" -q "$ROW" 2>&1) || { printf '%s\n' "$out" | head -2; exit 0; }
    else
      # "The last push" means the runs for the commit you are on. A pull request
      # from a branch in this repo starts push and pull_request both, and a repo
      # can have more than one workflow, so there may be several; all are shown.
      head=$(git rev-parse HEAD 2>/dev/null || true)
      if [ -z "$head" ]; then
        echo "Nothing is committed here yet, so nothing has run. Save first: just save \"what you did\""; exit 0
      fi
      out=$(gh run list --commit "$head" --limit 5 --json "$F" -q ".[]|$ROW" 2>/dev/null)
      if [ -z "$out" ]; then
        # No run for this commit. Before that is read as "not sent yet" or "never
        # ran", ask whether the checks can run at all. A repository whose Actions
        # are switched off answers the run list like any other: with nothing, and
        # this said "They start on the next push" about checks that never will; or
        # with its old runs, and this called a commit that was on GitHub unsent
        # (measured 2026-09-19 on gh 2.101.0: `[]` and exit 0 on one repository,
        # two old runs on another, `{"enabled":false}` on both). Only a plain
        # `false` counts: somebody else's repository answers 403, and then the
        # report reads as it did. One more question, and only on this path, so an
        # ordinary green or red build costs nothing extra.
        if [ "$(gh api 'repos/{owner}/{repo}/actions/permissions' -q .enabled </dev/null 2>/dev/null)" = false ]; then
          where=$(gh repo view --json url -q .url </dev/null 2>/dev/null)
          if [ -n "$where" ]; then where="$where/settings/actions"; else where="the repository's page on GitHub, under Settings, Actions"; fi
          echo "The checks are switched off for this repository on GitHub (Actions is disabled), so a push starts nothing there."
          echo "They are switched back on where they were switched off: $where"
          exit 0
        fi
        # gh says nothing at all and exits 0 when its filter matches no run and
        # its output is captured rather than shown to a person. So silence here
        # is this commit never having reached GitHub, not a failure.
        older=yes
        out=$(gh run list --limit 3 --json "$F" -q ".[]|$ROW" 2>&1) || {
          case "$out" in
            *"HTTP 404"*) echo "GitHub will not answer about this repository. It may be gone, it may belong to somebody else now, or Actions may be off for it. Look: gh repo view --web" ;;
            *) echo "GitHub did not answer. It said:"; printf '%s\n' "$out" | head -3 | sed 's/^/  /' ;;
          esac
          exit 0; }
      fi
    fi
    if [ -z "$out" ]; then
      echo "The checks have never run here. They start on the next push: just publish"; exit 0
    fi
    printf '%s\n' "$out" > "$runs"
    # The filter above can come back empty for a run GitHub has accepted but not
    # yet indexed, so the fallback's answer is looked at before anything is said
    # about the commit not having arrived.
    if [ -n "$older" ] && ! printf '%s\n' "$out" | cut -f3 | grep -qF "$(git rev-parse --short=7 HEAD 2>/dev/null)"; then
      echo "The commit you are on has not reached GitHub yet (send it: just publish). The last runs it saw:"
    fi
    red=0; going=0
    while IFS=$'\t' read -r id wf short branch status concl created event url title; do
      [ -n "$id" ] || continue
      [ "$concl" = "-" ] && concl=""
      [ "$title" = "-" ] && title=""
      # GitHub answers in UTC and this says so, rather than doing date
      # arithmetic that BSD and GNU spell differently.
      when="$(printf '%s' "$created" | tr T ' ' | cut -c1-16) UTC"
      echo
      printf '%s  %s  %s  %s\n' "$wf" "$short" "$when" "$title"
      echo "  $url"
      # The job and step names come from the API, not from the log: gh sometimes
      # labels every line of a job's log UNKNOWN STEP, for reasons outside this
      # repository, and names the steps correctly here either way.
      if ! gh run view "$id" --json jobs </dev/null 2>/dev/null \
        -q '.jobs[] | [.name, .status, (.conclusion // "-"|if . == "" then "-" else . end), (.databaseId|tostring), ([.steps[]? | select(.conclusion == "failure") | .name] | join(", ")|if . == "" then "-" else . end)] | @tsv' > "$jobs"; then
        echo "  ...   GitHub did not answer about this run's jobs"; continue
      fi
      [ -s "$jobs" ] || echo "  ...   the run has not started its jobs yet"
      while IFS=$'\t' read -r jname jstatus jconcl jid failstep; do
        [ "$jconcl" = "-" ] && jconcl=""
        [ "$failstep" = "-" ] && failstep=""
        case "$jstatus:$jconcl" in
          # A job that is still going reports its conclusion as the empty
          # string, not as null, so it is asked about by name and never by // .
          completed:success) printf '  ok    %s\n' "$jname" ;;
          completed:failure) printf '  FAIL  %s -> %s\n' "$jname" "${failstep:-the job itself}" ;;
          completed:*)       printf '  --    %s (%s)\n' "$jname" "${jconcl:-not finished}" ;;
          *)                 printf '  ...   %s (still going)\n' "$jname"; going=1 ;;
        esac
      done < "$jobs"
      while IFS=$'\t' read -r jname jstatus jconcl jid failstep; do
        [ "$jconcl" = failure ] || continue
        [ "$failstep" = "-" ] && failstep=""
        red=$((red+1)); [ "$red" -gt 2 ] && continue
        echo
        echo "  The last lines before $jname stopped:"
        gh run view --job "$jid" --log-failed </dev/null 2>/dev/null | just _ci-lines > "$log"
        if [ ! -s "$log" ]; then
          # No log and no failed step: the job never ran. GitHub puts the reason
          # in the job's annotations — a billing hold, a runner never assigned —
          # and nowhere else. Twelve pushes of one project read as a red build for
          # a day while this said only that there was no log. Asked for in this one
          # case, so an ordinary red build costs no extra call.
          why=""
          [ -z "$failstep" ] && why=$(gh api "repos/{owner}/{repo}/check-runs/$jid/annotations" </dev/null 2>/dev/null | just _ci-why)
          if [ -n "$why" ]; then
            echo "    The job never started. GitHub's reason: $why"
          else
            echo "    GitHub keeps no log for that job any more. The link above is what is left."
          fi
        else
          sed 's/^/    /' "$log"
        fi
      done < "$jobs"
    done < "$runs"
    echo
    if [ "$red" -gt 2 ]; then
      n=$((red-2))
      if [ "$n" -eq 1 ]; then echo "One more job failed; open the link above for it."
      else echo "$n more jobs failed; open the link above for them."; fi
    fi
    if [ "$going" -eq 1 ]; then echo "Still going. Ask again in a minute: just ci"; fi

# Throw away every change since the last save (asks first)
[group('safety')]
undo:
    #!/usr/bin/env bash
    set -euo pipefail
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
      just _msg nothing-to-undo; exit 0
    fi
    printf '%s' "$(just _msg undo-confirm)"; read -r a || a=""
    case "$a" in
      y|Y|e|E) git reset -q --hard && git clean -fdq && just _msg undone ;;
      *)       just _msg undo-kept ;;
    esac

# The tar that reads and writes zip archives, when there is one: bsdtar. A
# Mac's tar is one; Git Bash's is GNU tar, and Windows' own bsdtar sits in
# System32, behind it on the PATH (measured on the gate, spec 020). Prints the
# command, or nothing and exit 1.
_bsdtar:
    #!/usr/bin/env bash
    for t in bsdtar tar "${SYSTEMROOT:+$(cygpath -u "$SYSTEMROOT" 2>/dev/null)/System32/tar}"; do
      [ -n "$t" ] || continue
      v=$("$t" --version 2>/dev/null || true)
      case "$v" in *bsdtar*) echo "$t"; exit 0 ;; esac
    done
    exit 1

# Zip the whole project into .snapshots/
[group('safety')]
snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p .snapshots
    out=".snapshots/$(date +%Y-%m-%d_%H-%M-%S).zip"
    # zip matches an -x pattern against the whole stored name, so '*/target/*'
    # never sees a target/ at the root — which is where a Rust project's always
    # is, and a Node project's node_modules/. Each heavy folder is named twice:
    # once at the root, once below it.
    if command -v zip >/dev/null 2>&1; then
      zip -rq "$out" . \
        -x '.snapshots/*' '.git/*' '.references/*' 'graphify-out/*' \
           'node_modules/*' '*/node_modules/*' 'target/*' '*/target/*' \
           'build/*' '*/build/*' 'dist/*' '*/dist/*' '.venv/*' '*/.venv/*'
    elif bt=$(just _bsdtar 2>/dev/null); then
      # Git Bash on Windows has no zip, and the tar every Windows has is
      # bsdtar, which writes zip archives (spec 020). Its --exclude matches
      # a name at any depth, so each heavy folder is named once.
      "$bt" --format zip -cf "$out" \
        --exclude .snapshots --exclude .git --exclude .references --exclude graphify-out \
        --exclude node_modules --exclude target --exclude build --exclude dist --exclude .venv .
    else
      echo "No zip and no bsdtar on this machine, so nothing to make the archive with."; exit 1
    fi
    echo "$out"

# Retire a file or folder into .archive/ (kept, committed, not read unless asked)
[group('safety')]
[positional-arguments]
archive path:
    #!/usr/bin/env bash
    set -euo pipefail
    src="$1"; src="${src%/}"
    if [ ! -e "$src" ]; then echo "No such file or folder: $src"; exit 1; fi
    case "$src" in .archive/*|.archive) echo "$src is already in .archive/."; exit 0 ;; esac
    mkdir -p .archive
    if [ ! -f .archive/README.md ] && [ -f .ai-backbone/templates/archive-README.md ]; then
      cp .ai-backbone/templates/archive-README.md .archive/README.md; echo "  added   .archive/README.md"
    fi
    dst=".archive/$(basename "$src")"
    if [ -e "$dst" ]; then echo "$dst already exists. Rename one of them first."; exit 1; fi
    if git ls-files --error-unmatch "$src" >/dev/null 2>&1; then git mv -k "$src" "$dst"; else mv "$src" "$dst"; fi
    echo "  moved   $src -> $dst"
    echo "Add a line at the top of it (or a note next to it) saying when and why. Then: just save"

# ──────────────────────────── map ────────────────────────────

# Refresh the code map the agents read
[group('map')]
update-map:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v graphify >/dev/null 2>&1; then
      echo "graphify missing -> uv tool install graphifyy"; exit 1
    fi
    if [ -z "$(just _has-code)" ]; then
      echo "No program code here yet. Nothing to map."
      echo "(The map is drawn from code. A site of HTML and CSS, or SQL files alone, never gets one.)"
      exit 0
    fi
    # Everything below was measured on graphify 0.9.64 (2026-09-19), in a scratch
    # project holding swap-smash's three Dart files. Measure again before
    # trusting it on a graphify much newer than that.
    #
    # The ignore list. With the list as it was, 52 of the first map's 76 nodes
    # came from .ai-backbone/ (upstream.py, setup.sh, routine.sh) and 6 from the
    # game; that folder is in every project, so it was so in every language. The
    # template now names it, and documents too (next paragraph). .graphifyignore
    # is the project's after the first run, and a project made before a line
    # existed never got it: the way `_hook-lint` treats the hook config, a line
    # the template has and the file lacks is added at the end, and nothing is
    # taken out or moved. A line somebody commented out counts as there, which
    # is how a project says no to one.
    t=.ai-backbone/templates/graphifyignore
    if [ -f "$t" ] && [ ! -f .graphifyignore ]; then
      cp "$t" .graphifyignore; echo "  added .graphifyignore"
    elif [ -f "$t" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|'#'*) continue ;; esac
        if ! grep -qxF -e "$line" -e "# $line" -e "#$line" .graphifyignore; then
          [ -z "$(tail -c1 .graphifyignore)" ] || echo >> .graphifyignore
          printf '%s\n' "$line" >> .graphifyignore; echo "  added to .graphifyignore: $line"
        fi
      done < "$t"
    fi
    export PYTHONHASHSEED=0
    # One command, every time. Until spec 013 a map that existed was refreshed
    # with `graphify update .`, which reads documents as well as code: 141 of the
    # second map's 217 nodes were .md files, and the changelog was its most
    # connected node. `extract . --code-only` reads code only and is incremental:
    # a second run re-read nothing but the two JSON settings files, which give
    # no nodes ("5 files cached/unchanged, 2 re-extracted"), and wrote a graph
    # the same byte for byte; an edit, a renamed class and a new file each came
    # out right.
    # Deleted files: their nodes go on the next run, with no --force ("Pruned 3
    # node(s) from 1 deleted or excluded source file(s)"; 7 of 14 when two of
    # three files went). The note that asked said 0.9.58 kept them until the
    # update was forced; 0.9.64 does not, in `extract` or in `update`. The same
    # pruning takes out what a new ignore line excludes: a map built the old way
    # went from 217 nodes to 12.
    # A project folder that moved: nothing to do. graphify-out/.graphify_root
    # holds an absolute path, but the paths in the graph are relative; the first
    # run in the new place rewrote the marker, re-read only what it always
    # re-reads, and an edit and a deletion made after the move came out right.
    graphify extract . --code-only
    graphify cluster-only . --no-label --no-viz || true
    echo "graphify-out/GRAPH_REPORT.md updated."

# Every line that names a word, in any language: just uses SwapSmashGame
[group('map')]
[positional-arguments]
uses word:
    #!/usr/bin/env bash
    set -uo pipefail
    # AGENTS.md section 4 sends an agent to `graphify affected` before a change,
    # and the map knows only the callers graphify can draw. In Dart that is next
    # to none: it reads Dart with regular expressions, and the only calls that
    # reader knows are a BLoC's events and states (extractors/dart.py, 0.9.64).
    # Measured on 0.9.64: the map of swap-smash's three Dart files has 12 lines
    # between its nodes and not one is a call, where the backbone's own Python
    # has 33; in the project itself "affected swap" named neither of swap's two
    # real callers. A word search knows no language and misses nothing spelled
    # the same, so it is asked as well as the map, never instead of it. A whole
    # word, exactly as typed: no pattern to get wrong.
    if [ -z "$1" ]; then echo "Which word? For example: just uses SwapSmashGame"; exit 1; fi
    # Saved files and brand-new ones are both read, what git ignores is not.
    # A folder git has never seen has no such list, so every file in it is read.
    if git rev-parse --git-dir >/dev/null 2>&1; then where=--untracked; else where=--no-index; fi
    # The five folders left out are not this project's code: the backbone's own
    # files, the private vault, the map itself, other people's repos, and what
    # was retired. -I leaves binary files out; a line is cut at 240 bytes so that
    # one minified file cannot bury the rest.
    out=$(git grep -n -w -I -F "$where" -e "$1" -- . \
      ':!.ai-backbone' ':!brain' ':!graphify-out' ':!.references' ':!.archive' 2>/dev/null | LC_ALL=C cut -c1-240 || true)
    if [ -z "$out" ]; then echo "No line in this project names \"$1\" as a whole word."; exit 0; fi
    printf '%s\n' "$out"
    lines=$(wc -l <<<"$out" | tr -d ' '); files=$(cut -d: -f1 <<<"$out" | sort -u | wc -l | tr -d ' ')
    echo "$lines line(s) in $files file(s) name \"$1\"."

# Lines in the docs that name a path no longer here, or an old name in docs/renames.toml: file:line
[group('map')]
stale:
    #!/usr/bin/env bash
    set -uo pipefail
    # Docs drift in silence: a folder is renamed, the code follows and the
    # sentences do not. Smash measured it on 2026-09-22: two folder renames and
    # one layout change left 51 stale lines in 18 files, found by a hand grep.
    # This reads docs/, README*.md, AGENTS.md and every README.md under src/, and
    # reports two things as file:line. It is a report, never a failure: `lint`
    # runs it, and a project updated today would otherwise find its lint red for
    # lines written months ago.
    #
    # 1. A path in backticks that is no longer here. Where the line is drawn,
    #    because a check that cries wolf is a check nobody reads: the text
    #    between two backticks, outside a fenced block, that is one word of path
    #    characters (letters, digits, . _ - /), after a `:42` line number or a
    #    `#heading` is dropped. No space (a command), no :// (an address), no * ?
    #    [ { (a glob), no < > $ ~ (a placeholder, a home folder, a variable), not
    #    starting with / or - (outside the project, a flag), and no NNN or YYYY
    #    (a template's placeholder). It needs a slash, or a file extension when it
    #    is a bare name. And it is reported only when it is gone: it, or a folder
    #    above it, was once in this repository's history and is not here now,
    #    read from the root and from the folder of the file that names it. So
    #    `owner/repo`, `and/or`, `Node.js`, a file a project will have one day and
    #    a file the backbone describes for a project never count; only drift does.
    #    A bare name is gone when no file of that name is anywhere in the tree.
    #    What git ignores (brain/, build output) is never reported, nor the two
    #    folders the backbone makes when first needed (.archive/, .references/):
    #    AGENTS.md names them as places with a rule, whether they exist or not.
    # 2. An old name from docs/renames.toml, anywhere in a line, fenced or not,
    #    unless the line names the new one too (it is saying what was renamed).
    #    The agent that renames a file or folder adds one entry; `new` is left out
    #    for something removed:
    #
    #      [[rename]]
    #      old  = "games/"
    #      new  = "src/games/"
    #      date = "2026-09-22"
    #
    # A file whose Status line says "amended by" (or "superseded by") is skipped:
    # an ADR changed later keeps its old names on purpose, and
    # `just adr <name> --amends NNNN` writes that line.
    # perl, because the backbone already needs it and it reads the same on every
    # system; awk's regular expressions differ between a Mac and Linux.
    w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
    : > "$w/gone"; : > "$w/here"
    files=()
    repo=$(just _is-repo)
    if [ -n "$repo" ]; then
      while IFS= read -r x; do files+=("$x"); done < <(git -c core.quotePath=false ls-files -co --exclude-standard -- 'docs/*.md' 'README*.md' 'AGENTS.md' 'src/*/README.md' 2>/dev/null)
      git -c core.quotePath=false ls-files -co --exclude-standard > "$w/here" 2>/dev/null || true
      if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
        git -c core.quotePath=false log --format= --name-only --diff-filter=D --no-renames HEAD > "$w/gone" 2>/dev/null || true
      fi
    else
      while IFS= read -r x; do files+=("$x"); done < <(find docs -type f -name '*.md' 2>/dev/null; ls -1 README*.md AGENTS.md 2>/dev/null; find src -mindepth 2 -type f -name README.md 2>/dev/null)
    fi
    ren=""; if [ -f docs/renames.toml ]; then ren=docs/renames.toml; fi
    if [ ${#files[@]} -eq 0 ]; then echo "No docs to read yet."; exit 0; fi
    # The program goes to a file first: a heredoc inside $( ) is misread by the
    # bash 3.2 every Mac ships whenever the text holds a lone quote.
    cat > "$w/stale.pl" <<'PERL'
    use strict; use warnings;
    my ($gone_f, $here_f, $ren_f, @files) = @ARGV;
    sub lines { my $f = shift; return () unless length $f && open(my $h, '<', $f); my @l = <$h>; chomp @l; return grep { length } @l }
    my (%gone, %gonebase, %herebase);
    for my $p (lines($gone_f)) {
      $gonebase{(split m{/}, $p)[-1]} = 1;
      my $q = $p; while (1) { $gone{$q} = 1; last unless $q =~ s{/[^/]*$}{} }
    }
    $herebase{(split m{/}, $_)[-1]} = 1 for lines($here_f);
    my (@ren, $cur);
    for (lines($ren_f)) {
      if (/^\s*\[\[\s*rename\s*\]\]/) { push @ren, $cur if $cur && length $cur->{old}; $cur = { old => '', new => '', date => '' }; next }
      next unless $cur;
      if (/^\s*(old|new|date)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|'([^']*)')/) {
        my ($k, $v, $lit) = ($1, defined $2 ? $2 : $3, defined $3);
        $v =~ s/\\(.)/$1/g unless $lit; $cur->{$k} = $v;
      }
    }
    push @ren, $cur if $cur && length $cur->{old};
    sub names { my ($l, $w) = @_; my $q = quotemeta $w; my $end = $w =~ m{/$} ? '' : '(?![A-Za-z0-9_-])'; return $l =~ /(?<![A-Za-z0-9_.\/-])$q$end/ }
    sub norm { my @o; for my $s (split m{/}, $_[0]) { next if $s eq '' || $s eq '.'; if ($s eq '..') { return undef unless @o; pop @o; next } push @o, $s } return join '/', @o }
    for my $f (@files) {
      open(my $h, '<', $f) or next; my @text = <$h>; close $h;
      my $amended = 0;
      for (@text) { last if /^## /; if (/^(?:\*\*)?status(?::\*\*|\*\*:|:)/i) { $amended = 1 if /(?:amended|superseded) by/i; last } }
      next if $amended;
      my $dir = $f =~ m{^(.*)/} ? $1 : '';
      my ($n, $fence) = (0, '');
      for my $l (@text) {
        $n++; chomp(my $t = $l);
        for my $r (@ren) {
          next unless names($t, $r->{old});
          next if length $r->{new} && names($t, $r->{new});
          my $what = length $r->{new} ? "is `$r->{new}` now" : "is gone";
          $what .= " (renamed $r->{date})" if length $r->{date} && length $r->{new};
          $what .= " (since $r->{date})" if length $r->{date} && !length $r->{new};
          print "\t$f:$n: `$r->{old}` $what\n";
        }
        if ($t =~ /^\s*(`{3,}|~{3,})/) { my $m = substr($1, 0, 1); if ($fence eq '') { $fence = $m } elsif ($fence eq $m) { $fence = '' } next }
        next if $fence ne '';
        while ($t =~ /`([^`]+)`/g) {
          my $w = $1; $w =~ s/^\s+|\s+$//g;
          my $p = $w; $p =~ s/#.*$//; $p =~ s/:\d+(?:[-:]\d+)*$//;
          next unless $p =~ m{^[A-Za-z0-9._/-]+$} && $p =~ /[A-Za-z]/;
          next if $p =~ m{^[-/]} || $p =~ m{//} || $p =~ /NNN|YYYY|XXX/;
          next if $p =~ m{^\.(?:archive|references)/?$};
          if ($p =~ m{/}) {
            my @c = grep { defined && length } (($p =~ m{^\.\./} ? () : norm($p)), (length $dir ? norm("$dir/$p") : ()));
            next if !@c || grep { -e $_ } @c;
            my $was;
            C: for my $c (@c) { my $q = $c; while (1) { if ($gone{$q} && !-e $q) { $was = $c; last C } last unless $q =~ s{/[^/]*$}{} } }
            next unless defined $was;
            print $was . ($p =~ m{/$} ? '/' : '') . "\t$f:$n: `$w` is no longer here\n";
          } elsif ($p =~ /[^.]\.[A-Za-z0-9]{1,10}$/ || $p =~ /^\.[A-Za-z]/) {
            next if -e $p || (length $dir && -e "$dir/$p") || $herebase{$p} || !$gonebase{$p};
            print "$p\t$f:$n: `$w` is no longer here\n";
          }
        }
      }
    }
    PERL
    # A machine that cannot answer says so and nothing more: without perl, or
    # with a perl that failed, an empty answer is not "nothing is stale", and
    # the all-clear it printed was false (spec 015 review).
    if ! command -v perl >/dev/null 2>&1; then echo "stale reads with perl, which is not on this machine: nothing was checked."; exit 0; fi
    if ! raw=$(perl "$w/stale.pl" "$w/gone" "$w/here" "$ren" "${files[@]}"); then
      echo "stale could not read the docs (perl stopped): nothing was checked."; exit 0
    fi
    if [ -z "$raw" ]; then echo "Nothing stale: every path the docs name is still here."; exit 0; fi
    # What git ignores is somebody's private folder or build output, named on purpose.
    ign=""
    if [ -n "$repo" ]; then ign=$(cut -f1 <<<"$raw" | sed '/^$/d' | sort -u | git check-ignore --stdin 2>/dev/null || true); fi
    out=$(IGN="$ign" perl -ne 'BEGIN { %i = map { $_ => 1 } split /\n/, $ENV{IGN} } my ($k, $m) = split /\t/, $_, 2; print $m unless length $k && $i{$k}' <<<"$raw")
    if [ -z "$out" ]; then echo "Nothing stale: every path the docs name is still here."; exit 0; fi
    printf '%s\n' "$out"
    lines=$(wc -l <<<"$out" | tr -d ' '); nf=$(cut -d: -f1 <<<"$out" | sort -u | wc -l | tr -d ' ')
    echo "$lines line(s) in $nf file(s) name something that has moved or gone. Fix them where they stand; this is a report, and lint does not fail on it."

# ─────────────────────────── template ────────────────────────

# Pull backbone updates from ai-backbone (only files it owns; yours are never touched)
[group('template')]
template-update:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "$(just _is-backbone)" ]; then echo "This repo IS the backbone. Nothing to pull."; exit 0; fi
    tmp=""
    if ! src=$(just _backbone 2>/dev/null); then
      tmp=$(mktemp -d)
      if ! git clone --depth 1 -q https://github.com/yerlytech/ai-backbone.git "$tmp/t" 2>/dev/null; then
        rm -rf "$tmp"
        echo "Cannot reach the backbone. Point AI_BACKBONE at a local copy:"
        echo "  AI_BACKBONE=../ai-backbone just template-update"
        exit 1
      fi
      src="$tmp/t"
    fi
    # What projects copy is what the gate carried to main (spec 017). A sibling
    # clone left on cloud by an attended session is untested and is not copied
    # from. Not in offline mode, which compares nothing with GitHub.
    if [ -z "$tmp" ] && [ -z "${AI_BACKBONE_OFFLINE:-}" ] && [ -d "$src/.git" ] && git -C "$src" remote get-url origin >/dev/null 2>&1; then
      br=$(git -C "$src" symbolic-ref -q --short HEAD 2>/dev/null || echo "no branch")
      if [ "$br" != main ]; then
        echo "Not updated: the backbone in $src is on '$br', not on main, and what projects copy is what the gate carried to main."
        echo "An agent there runs: git -C $src checkout main"; exit 1
      fi
    fi
    [ -z "$tmp" ] && just _backbone-refresh "$src"
    man="$src/.ai-backbone/manifest.txt"
    if [ ! -f "$man" ]; then echo "No .ai-backbone/manifest.txt in $src. Is that really the backbone?"; exit 1; fi
    ver() { grep -m1 -oE 'version [0-9]+\.[0-9]+(\.[0-9]+)?' "$1" 2>/dev/null | awk '{print $2}'; }
    theirs=$(ver "$src/.ai-backbone/core.just")
    # The version this project is ON is the one in its last save, not the one on
    # disk. An update that was copied and never saved left four projects with
    # 3.7.0 committed and 3.17.1 on disk; the next update read 3.17.1, and what
    # ten versions had to say about AGENTS.md was never shown. So git is asked
    # first, and the file only where git has no answer: no repository, no save
    # yet, a project adopted a minute ago. Captured and then read, because
    # `git show | grep -m1` is the SIGPIPE under pipefail the span below died of.
    saved=$(git show HEAD:.ai-backbone/core.just 2>/dev/null || true)
    mine=$(grep -m1 -oE 'version [0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$saved" | awk '{print $2}' || true)
    [ -n "$mine" ] || mine=$(ver .ai-backbone/core.just || true)
    # AGENTS.md is a seed: copied once, then the project's own, so a rule the
    # backbone gained reaches no project that was already there. Those four still
    # lacked the rules of ten versions. Nothing can be carried into a file that
    # is theirs, but it can be said: the rules of the three sections that grow
    # (the "- " lines of Session protocol, Safety and Do not) which this AGENTS.md
    # has no line for. Two lines are the same rule when their first six words
    # are, read without case and punctuation. That is all it knows: a rule the
    # project reworded or left out on purpose is listed too, and the words say so.
    # Read here, while a backbone cloned for this run is still on disk.
    lacks=""; seed="$src/AGENTS.md"
    [ -z "$tmp" ] || seed="https://github.com/yerlytech/ai-backbone/blob/main/AGENTS.md"
    if [ -s AGENTS.md ] && [ -f "$src/AGENTS.md" ]; then
      lacks=$(awk '
        function key(s,   n, w, i, k) {
          s = tolower(s); gsub(/[^a-z0-9]+/, " ", s); n = split(s, w, " "); k = ""
          for (i = 1; i <= n && i <= 6; i++) k = k " " w[i]
          return k
        }
        FNR == NR { if (/^- /) has[key($0)] = 1; next }
        /^## /    { on = /^## [0-9]+\. (Session protocol|Safety|Do not)[ \t]*$/ }
        on && /^- / && !(key($0) in has) { print "  " $0 }
      ' AGENTS.md "$src/AGENTS.md" || true)
    fi
    rules() {
      [ -n "$lacks" ] || return 0
      echo
      echo "AGENTS.md is this project's own, so no update carries a new rule into it. These rules"
      echo "of the backbone's AGENTS.md have no line here that starts the same way. The first six"
      echo "words are compared, so a rule this project reworded or left out on purpose is listed too:"
      printf '%s\n' "$lacks"
      echo "In full: $seed"
      echo "Add the ones that fit this project. Nothing was changed."
    }
    # Copy the backbone's files where they differ.
    changed=0; added=0
    while IFS=$'\t' read -r from to; do
      [ -f "$src/$from" ] || { echo "  missing upstream, skipped: $from"; continue; }
      if [ ! -f "$to" ]; then
        mkdir -p "$(dirname "$to")"; cp "$src/$from" "$to"; echo "  added   $to"; added=$((added+1))
      elif ! cmp -s "$src/$from" "$to"; then
        cp "$src/$from" "$to"; echo "  updated $to"; changed=$((changed+1))
      fi
    done < <(just _manifest "$man" project)
    [ -n "$tmp" ] && rm -rf "$tmp"
    if command -v prek >/dev/null 2>&1 && [ -n "$(just _is-repo)" ]; then
      if [ -n "$(just _push-stage)" ]; then prek install -t pre-commit -t commit-msg -t pre-push >/dev/null 2>&1 || true
      else prek install -t pre-commit -t commit-msg >/dev/null 2>&1 || true; fi
    fi
    echo
    # The subagent-cap hook (spec 014) reaches a project made before it existed
    # here, whether or not a file moved: merged into the project's own
    # .claude/settings.json beside its permissions, never twice, never a reason
    # to fail an update. The same step hooks-install takes.
    caphook() {
      if [ -f .ai-backbone/budget.py ] && { [ -d .claude ] || [ -f .claude/settings.json ]; }; then
        if said=$("$(just _py)" .ai-backbone/budget.py hook add 2>/dev/null); then
          case "$said" in added|updated) echo "Subagent cap: in .claude/settings.json, $said. A session starts at most 8 on its own (git config --global ai-backbone.agent-cap <n> changes it)." ;; esac
        else
          echo "warn  the subagent cap hook could not be merged into .claude/settings.json (a comment or a trailing comma in it?): copy the PreToolUse group from the backbone's .claude/settings.json by hand."
        fi
      fi
    }
    if [ "$changed" -eq 0 ] && [ "$added" -eq 0 ]; then
      echo "Already up to date."; caphook; rules; exit 0
    fi
    echo "$added added, $changed updated. Your own files were not touched."
    # What changed, in the backbone's own words: the entries newer than the old version.
    # The span is captured first and cut afterwards: a pipe into `head` here is a
    # SIGPIPE under pipefail once the span outgrows the pipe buffer — about 400
    # CHANGELOG lines, ten versions, today — and a project that skipped that many
    # died with exit 141 after copying the files, before the line that says what
    # to do next.
    if [ -f .ai-backbone/CHANGELOG.md ] && [ -n "$theirs" ] && [ "$mine" != "$theirs" ]; then
      slice=$(awk -v new="## $theirs" -v old="## ${mine:-}" '
        index($0,new)==1 {on=1; print; next}
        on && /^## / { if (old=="## " || old==new || index($0,old)==1) exit }
        on {print}' .ai-backbone/CHANGELOG.md)
      if [ -n "$slice" ]; then
        echo
        awk 'NR<=60' <<<"$slice"
        total=$(awk 'END{print NR}' <<<"$slice")
        if [ "$total" -gt 60 ]; then echo "… and $((total-60)) more lines in .ai-backbone/CHANGELOG.md"; fi
        # AGENTS.md is a seed: no update carries it, so a rule it gained reaches
        # an existing project only when somebody reads the entry. The whole span
        # is searched, not the sixty lines shown.
        if grep -q 'AGENTS\.md' <<<"$slice"; then
          echo
          echo "An entry in this span names AGENTS.md. That file is this project's own and is"
          echo "never updated: read the entry and add the rule by hand (backbone-update skill, step 6)."
        fi
      fi
    fi
    rules
    caphook
    echo "Next: just sync-rules, look at git status, then: just save \"chore: backbone $theirs\""

# Say whether the backbone has updates. Changes nothing.
[group('template')]
template-check:
    #!/usr/bin/env bash
    set -uo pipefail
    if [ -n "$(just _is-backbone)" ]; then echo "Backbone: this repo IS the backbone."; exit 0; fi
    if ! src=$(just _backbone 2>/dev/null); then
      echo "Backbone: not found nearby. Set AI_BACKBONE to check for updates."; exit 0
    fi
    just _backbone-refresh "$src"
    ver() { grep -m1 -oE 'version [0-9]+\.[0-9]+(\.[0-9]+)?' "$1" 2>/dev/null | awk '{print $2}'; }
    theirs=$(ver "$src/.ai-backbone/core.just")
    mine=$(ver .ai-backbone/core.just)
    behind=0
    while IFS=$'\t' read -r from to; do
      [ -f "$src/$from" ] || continue
      if [ ! -f "$to" ] || ! cmp -s "$src/$from" "$to"; then behind=$((behind+1)); fi
    done < <(just _manifest "$src/.ai-backbone/manifest.txt" project)
    if [ "$behind" -eq 0 ]; then
      echo "Backbone: up to date (${theirs:-?})."
    elif [ -n "$theirs" ] && [ "$mine" != "$theirs" ]; then
      echo "Backbone: ${mine:-?} -> $theirs, $behind file(s) behind -> just template-update"
    else
      echo "Backbone: $behind file(s) behind -> just template-update"
    fi

# Let this repo work on itself once a week, unattended: just routine-install
[group('template')]
[positional-arguments]
routine-install when="sunday 08:47":
    #!/usr/bin/env bash
    set -euo pipefail
    # The day and the time are read first, so that the cron line printed on
    # Linux is the one that was asked for rather than the example.
    when="$1"
    day=$(echo "$when" | awk '{print tolower($1)}'); clock=$(echo "$when" | awk '{print $2}')
    case "$day" in sunday) n=0;; monday) n=1;; tuesday) n=2;; wednesday) n=3;; thursday) n=4;; friday) n=5;; saturday) n=6;;
      *) echo "Say a day and a time: just routine-install \"sunday 08:47\""; exit 1;; esac
    hour=${clock%%:*}; minute=${clock##*:}
    if ! [ "$hour" -ge 0 ] 2>/dev/null || ! [ "$minute" -ge 0 ] 2>/dev/null; then
      echo "Say a day and a time: just routine-install \"sunday 08:47\""; exit 1
    fi
    # Which brief, asked of the script that will read it. One answer, one place.
    brief=$(sh .ai-backbone/routine.sh --brief) || { echo "$brief"; exit 1; }
    if [ "$(uname)" != "Darwin" ]; then
      echo "This installs a macOS schedule. On this machine, run the same script from cron:"
      echo "  $((10#$minute)) $((10#$hour)) * * $n  cd $PWD && sh .ai-backbone/routine.sh"
      echo "Everything else — the brief, the agent, the lock, the log — is the same."
      exit 1
    fi
    # Which agent, and does it actually answer? A schedule that calls a command
    # with the wrong flag is six weeks of silence, so it is tried once, here.
    # --which answers on any machine now, so the decision is made here.
    which=$(sh .ai-backbone/routine.sh --which) || { echo "$which"; exit 1; }
    case "$which" in none:*) printf '%s\n' "$which"; exit 1 ;; esac
    echo "Agent: $which"
    just _msg checking
    # The probe runs a real command through the agent, because "it answered" and
    # "it can work here" are different questions. An agent that replies politely
    # and is refused every shell command is a schedule that does nothing every
    # week, which is worse than no schedule: it looks like it is working.
    probe() {
      sh -c "$(echo "${which#*: }" | sed "s|{prompt}|'Run the shell command: just --version. Reply with its output and nothing else.'|")" 2>&1
    }
    said=$(probe || true)
    if ! printf '%s' "$said" | grep -qE 'just [0-9]+\.[0-9]+'; then
      # The commonest cause, and one this recipe can fix: the agent was never
      # opened here by hand, so it ignores this repo's own permission list.
      if printf '%s' "$said" | grep -qi "not been trusted"; then
        echo "  the agent had not been trusted in this folder; trusting it"
        python3 - "$PWD" <<'PYTRUST'
    import json, pathlib, sys
    config = pathlib.Path.home() / ".claude.json"
    data = json.loads(config.read_text()) if config.exists() else {}
    projects = data.setdefault("projects", {})
    here = projects.setdefault(sys.argv[1], {})
    here["hasTrustDialogAccepted"] = True
    config.write_text(json.dumps(data, indent=2))
    PYTRUST
        said=$(probe || true)
      fi
    fi
    if ! printf '%s' "$said" | grep -qE 'just [0-9]+\.[0-9]+'; then
      echo "That agent cannot run a command in this folder. What it said:"
      printf '%s\n' "$said" | tail -6 | sed 's/^/  /'
      echo
      echo "Nothing was scheduled. A weekly run that cannot use the tools would do nothing, quietly."
      echo "Fix its permissions for this folder, or name another: AI_AGENT_CMD='mytool run {prompt}' just routine-install"
      exit 1
    fi
    echo "  it ran a command here: $(printf '%s' "$said" | grep -oE 'just [0-9]+\.[0-9]+[^ ]*' | head -1)"
    root="$PWD"
    label="ai-backbone.routine.$(just _slug "$(basename "$root")")"
    plist="$HOME/Library/LaunchAgents/$label.plist"
    mkdir -p "$HOME/Library/LaunchAgents" brain/05-files
    sed -e "s|LABEL|$label|" -e "s|ROOT|$root|g" \
        -e "s|<integer>WEEKDAY</integer>|<integer>$n</integer>|" \
        -e "s|<integer>HOUR</integer>|<integer>$((10#$hour))</integer>|" \
        -e "s|<integer>MINUTE</integer>|<integer>$((10#$minute))</integer>|" \
        .ai-backbone/templates/routine.plist > "$plist"
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
    echo "Installed. $(basename "$root") works on itself every $day at $clock."
    echo "  what it does    $brief"
    echo "  what it wrote   brain/05-files/routine.log  (just routine-status)"
    echo "  stop it         just routine-remove"

# Is the routine installed, and what did it do last time?
[group('template')]
routine-status:
    #!/usr/bin/env bash
    set -uo pipefail
    label="ai-backbone.routine.$(just _slug "$(basename "$PWD")")"
    plist="$HOME/Library/LaunchAgents/$label.plist"
    if [ ! -f "$plist" ]; then
      if [ "$(uname)" != "Darwin" ]; then
        echo "No macOS schedule here. This machine schedules with cron; check it with: crontab -l"
      else
        echo "Not installed here. Start it with: just routine-install"
      fi
      exit 0
    fi
    day=$(grep -A4 StartCalendarInterval "$plist" | grep -A0 Weekday | grep -oE '<integer>[0-9]+' | grep -oE '[0-9]+')
    hour=$(grep -A4 StartCalendarInterval "$plist" | grep Hour | grep -oE '<integer>[0-9]+' | grep -oE '[0-9]+')
    minute=$(grep -A4 StartCalendarInterval "$plist" | grep Minute | grep -oE '<integer>[0-9]+' | grep -oE '[0-9]+')
    names="sunday monday tuesday wednesday thursday friday saturday"
    echo "Installed: $label — every $(echo $names | cut -d' ' -f$((day+1))) at $(printf '%02d:%02d' "$hour" "$minute")"
    if launchctl list 2>/dev/null | grep -q "$label"; then echo "Loaded: yes"; else echo "Loaded: no -> just routine-install"; fi
    echo "Agent:  $(sh .ai-backbone/routine.sh --which 2>&1)"
    if [ -f brain/05-files/routine.log ]; then
      echo; echo "Last run:"; tail -20 brain/05-files/routine.log | sed 's/^/  /'
    else
      echo "It has not run yet."
    fi

# Stop the weekly routine on this machine
[group('template')]
routine-remove:
    #!/usr/bin/env bash
    set -uo pipefail
    label="ai-backbone.routine.$(just _slug "$(basename "$PWD")")"
    plist="$HOME/Library/LaunchAgents/$label.plist"
    if [ ! -f "$plist" ]; then
      if [ "$(uname)" != "Darwin" ]; then
        echo "No macOS schedule here. If this machine runs it from cron, remove that line: crontab -e"
      else
        echo "Nothing installed here."
      fi
      exit 0
    fi
    # The schedule is read before the file goes, the way routine-status reads it,
    # so the last line can say how to put back exactly what was removed. Until
    # 3.20.0 that line used a day and a time this recipe never read, and the
    # removal ended in "unbound variable". A file that holds no schedule this
    # can read gets the hint without a time, never a wrong one.
    sched() { grep -A4 StartCalendarInterval "$plist" | grep "$1" | grep -oE '<integer>[0-9]+' | grep -oE '[0-9]+' | head -1; }
    day=$(sched Weekday); hour=$(sched Hour); minute=$(sched Minute)
    names="sunday monday tuesday wednesday thursday friday saturday"
    back="just routine-install"
    if [ -n "$day" ] && [ "$day" -le 6 ] && [ -n "$hour" ] && [ -n "$minute" ]; then
      back="$back \"$(echo $names | cut -d' ' -f$((day+1))) $(printf '%02d:%02d' "$((10#$hour))" "$((10#$minute))")\""
    fi
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    echo "Removed. The log stays at brain/05-files/routine.log."
    echo "Put it back whenever: $back"

# Run the routine now, in this terminal, exactly as the schedule would
[group('template')]
routine-now:
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p brain/05-files
    # The same log the schedule writes, so `routine-status` shows a run by hand
    # as well as a run at night.
    sh .ai-backbone/routine.sh 2>&1 | tee -a brain/05-files/routine.log

# What is new upstream: latest releases of the tools this repo relies on.
# Run by session-start once a week, and by nobody else: no skill, rule or
# recipe names it, and the one page that did listed it among commands an agent
# might type. A new project shows 37 recipes and 37 is the ceiling, so when
# `just uses` arrived (spec 013) this one gave up its place and took the
# underscore. It still runs by hand: just _backbone-news
_backbone-news:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
      echo "Needs gh, logged in: gh auth login"; exit 0
    fi
    latest() { gh api "repos/$1/releases/latest" -q '.tag_name' 2>/dev/null | sed 's/^v//' || echo "?"; }
    have() { command -v "$1" >/dev/null 2>&1 && "$1" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "-"; }
    printf "  %-10s %-10s %s\n" tool here latest
    printf "  %-10s %-10s %s\n" just     "$(have just)"     "$(latest casey/just)"
    printf "  %-10s %-10s %s\n" prek     "$(have prek)"     "$(latest j178/prek)"
    printf "  %-10s %-10s %s\n" graphify "$(have graphify)" "$(latest Graphify-Labs/graphify)"
    rev=$(grep -A1 'gitleaks/gitleaks' .pre-commit-config.yaml 2>/dev/null | grep -oE 'v[0-9.]+' | head -1 | sed 's/^v//')
    printf "  %-10s %-10s %s\n" gitleaks "${rev:--}" "$(latest gitleaks/gitleaks)"
    echo
    echo "Behind -> run: just tools-update, then just save. (An agent does this without asking.)"

# What the things this project is built on have released: just upstream · just upstream surrealdb
[group('template')]
[positional-arguments]
upstream name="":
    #!/usr/bin/env bash
    set -uo pipefail
    "$(just _py)" .ai-backbone/upstream.py ${1:+"$1"}

# Start the watch list: docs/upstream.toml, then edit it
[group('template')]
upstream-init:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f docs/upstream.toml ]; then echo "Exists  docs/upstream.toml"; exit 0; fi
    mkdir -p docs
    cp .ai-backbone/templates/upstream.toml docs/upstream.toml
    echo "Created docs/upstream.toml"
    echo "List what this project is built on, then: just upstream"

# Start a new project from the backbone: `just new-project my-app tr` creates ../my-app
[group('template')]
[positional-arguments]
new-project name lang="":
    #!/usr/bin/env bash
    set -euo pipefail
    name="$1"; lang="$2"
    case "$name" in */*) parent="$(dirname "$name")"; name="$(basename "$name")" ;; *) parent=".." ;; esac
    # The folder (and later the GitHub repo) gets a file-safe name; the project
    # keeps the name as typed: "Yapılacaklar Listesi" lives in ../yapilacaklar-listesi.
    slug=$(just _slug "$name")
    if [ -z "$slug" ]; then echo "Give the project a name, e.g. just new-project my-app"; exit 1; fi
    target="$parent/$slug"
    if [ -e "$target" ]; then echo "$target already exists. Pick another name."; exit 1; fi
    src=""
    if [ -n "$(just _is-backbone)" ]; then src="$PWD"; else src=$(just _backbone 2>/dev/null) || true; fi
    if [ -z "$src" ] || [ ! -f "$src/.ai-backbone/manifest.txt" ]; then
      echo "Cannot find the backbone. Set AI_BACKBONE to a local copy of ai-backbone."; exit 1
    fi
    src="$(cd "$src" && pwd -P)"
    mkdir -p "$target"; target="$(cd "$target" && pwd -P)"
    # Two kinds of file go in: the backbone's own (kept current by template-update)
    # and seeds (copied once, then the project's). Nothing else.
    for section in project seed; do
      while IFS=$'\t' read -r from to; do
        [ -f "$src/$from" ] || continue
        mkdir -p "$target/$(dirname "$to")"; cp "$src/$from" "$target/$to"
      done < <(just _manifest "$src/.ai-backbone/manifest.txt" "$section")
    done
    cd "$target"
    # The name and the language reach perl through the environment, not inside its
    # script: a name pasted into the substitution is perl code, and "P3 @{[system ...]}"
    # ran (3.20.0).
    BB_NAME="$name" perl -pi -e 's/^\| project \| .* \|/| project | $ENV{BB_NAME} |/' AGENTS.md
    if [ -n "$lang" ]; then
      BB_LANG="$lang" perl -pi -e 's/^\| brain_lang \| .* \|/| brain_lang | $ENV{BB_LANG} |/; s/^\| chat_lang \| .* \|/| chat_lang | $ENV{BB_LANG} |/' AGENTS.md
    fi
    # The seed Justfile carries three Turkish aliases as an example. They stay only
    # when the project is Turkish; otherwise the hint stays and the aliases go.
    if [ "$lang" != tr ] && [ -f Justfile ]; then
      perl -ni -e 'print unless /^alias (yedekle|yayinla|geri-al) :=/' Justfile
      perl -pi -e 's/^# Rename these to whatever you say in your own language\.$/# Aliases in your own language go here, e.g.  alias speichern := save/' Justfile
    fi
    {
      echo "# $name"; echo
      echo "Built on [ai-backbone](https://github.com/yerlytech/ai-backbone)."
      echo "Rules: \`AGENTS.md\`. Commands: type \`just\`. Your notes: \`brain/\`."
      echo
      echo "To start, tell your agent: **read AGENTS.md and set this project up for me.**"
    } > README.md
    # The licence names the person who made the project, not the backbone's author.
    holder=$(git config user.name 2>/dev/null || true); holder="${holder:-$name}"
    if [ -f LICENSE ]; then
      tmp=$(mktemp); sed -E "s/^Copyright \(c\) [0-9]{4} .*/Copyright (c) $(date +%Y) $holder/" LICENSE > "$tmp"; mv "$tmp" LICENSE
    fi
    git init -q -b main
    just brain-init >/dev/null
    just sync-rules >/dev/null
    just _hook-lint >/dev/null
    if command -v prek >/dev/null 2>&1; then just hooks-install >/dev/null; fi
    git add -A
    # The checks run inside the commit. Show their output only when they fail.
    msg="chore: start $slug from ai-backbone"; out=$(mktemp)
    if ! git commit -q -m "$msg" >"$out" 2>&1; then
      git add -A
      if ! git commit -q -m "$msg" >"$out" 2>&1; then
        cat "$out"; rm -f "$out"; echo "Project created, but the first save failed. See above."; exit 1
      fi
    fi
    rm -f "$out"
    echo "Created $target"
    echo
    echo "Next: open that folder in your AI tool and say:"
    echo "  read AGENTS.md and set this project up for me"

# Bring an existing repo onto the backbone: `just adopt ../my-repo`. Its own files are never overwritten.
[group('template')]
[positional-arguments]
adopt path:
    #!/usr/bin/env bash
    set -euo pipefail
    target="$1"
    if [ ! -d "$target" ]; then echo "No such folder: $target"; exit 1; fi
    src=""
    if [ -n "$(just _is-backbone)" ]; then src="$PWD"; else src=$(just _backbone 2>/dev/null) || true; fi
    if [ -z "$src" ] || [ ! -f "$src/.ai-backbone/manifest.txt" ]; then
      echo "Cannot find the backbone. Set AI_BACKBONE to a local copy of ai-backbone."; exit 1
    fi
    src="$(cd "$src" && pwd -P)"; target="$(cd "$target" && pwd -P)"
    if [ "$target" = "$src" ]; then echo "That is the backbone itself."; exit 1; fi
    if [ -f "$target/.ai-backbone/core.just" ]; then echo "$target is already on the backbone. Use: just template-update (there)."; exit 0; fi
    cd "$target"
    # The project has no recipes yet, so every `just` call below points at the core file itself.
    core() { just -f .ai-backbone/core.just -d . "$@"; }
    added=0; kept=0; agents_copied=""
    # Owned files: copied. Seeds: copied only when the project has no file of that name.
    for section in project seed; do
      while IFS=$'\t' read -r from to; do
        [ -f "$src/$from" ] || continue
        if [ -f "$to" ]; then kept=$((kept+1)); echo "  kept    $to (yours)"; continue; fi
        # The placeholder README is for an empty src/; a repo with code does not need it.
        if [ "$to" = src/README.md ] && [ -n "$(ls -A src 2>/dev/null)" ]; then continue; fi
        mkdir -p "$(dirname "$to")"; cp "$src/$from" "$to"; added=$((added+1))
        if [ "$to" = AGENTS.md ]; then agents_copied=1; fi
        if [ "$to" = LICENSE ]; then
          holder=$(git config user.name 2>/dev/null || true); holder="${holder:-$(basename "$target")}"
          tmp=$(mktemp); sed -E "s/^Copyright \(c\) [0-9]{4} .*/Copyright (c) $(date +%Y) $holder/" LICENSE > "$tmp"; mv "$tmp" LICENSE
        fi
      done < <(just -f "$src/.ai-backbone/core.just" -d "$src" _manifest "$src/.ai-backbone/manifest.txt" "$section")
    done
    # The seed AGENTS.md says `| project | ai-backbone |`, which is the backbone
    # talking about itself; in an adopted project it is simply wrong, and every
    # agent reads that file as the rules. The folder's own name is the only name
    # this recipe is given, and it is the one `_vault-dest` already falls back to.
    # The name reaches perl through the environment, never inside its script (3.20.0).
    if [ -n "$agents_copied" ]; then
      BB_NAME="$(basename "$target")" perl -pi -e 's/^\| project \| .* \|/| project | $ENV{BB_NAME} |/' AGENTS.md
      echo "  AGENTS.md: project row set to $(basename "$target"). Section 0 still asks for brain_lang and chat_lang."
    fi
    # A project's own .gitignore must still keep the vault out of git.
    if ! grep -qE '^brain/?$' .gitignore 2>/dev/null; then
      printf '\n# Private vault and local snapshots (ai-backbone). Never committed.\nbrain/\n.snapshots/\n' >> .gitignore
      echo "  .gitignore: added brain/ and .snapshots/"
    fi
    if [ -f Justfile ] && ! grep -q '\.ai-backbone/core\.just' Justfile; then
      echo "  Justfile is yours and was kept. Add this line near its top so the backbone's recipes load:"
      echo "      import? '.ai-backbone/core.just'"
    fi
    if [ -f AGENTS.md ] && ! grep -q '^| brain_lang |' AGENTS.md; then
      echo "  AGENTS.md is yours and was kept. Compare it with $src/AGENTS.md and add section 0 (project, brain_lang, chat_lang, tools)."
    fi
    if [ -z "$(core _is-repo)" ]; then git init -q -b main; echo "  git repo created"; fi
    core brain-init >/dev/null 2>&1 || true
    core sync-rules >/dev/null 2>&1 || true
    hook=$(core _hook-lint 2>/dev/null || true); if [ -n "$hook" ]; then echo "  $hook"; fi
    if command -v prek >/dev/null 2>&1; then core hooks-install >/dev/null 2>&1 || true; fi
    echo
    echo "$added file(s) added, $kept of yours kept. Nothing was overwritten and nothing is saved yet."
    echo "Next: look at git status, then: just save \"chore: adopt ai-backbone\""

# ──────────────────────── references ─────────────────────────

# Keep a read-only copy of another repo to learn from: just ref-add <git url or folder> "why it is here"
[group('references')]
[positional-arguments]
ref-add url note="":
    #!/usr/bin/env bash
    set -euo pipefail
    url="$1"; note="$2"
    name=$(basename "${url%.git}" | tr '[:upper:]' '[:lower:]')
    # A folder on this machine, too: an old repo of the person's own that has no
    # address anywhere else (Smash kept three earlier games that way, 1.4 GB,
    # moved into .references/ by hand on 2026-09-22, and nothing listed them).
    # With no address it is listed with url = "", which `ref-fetch` skips and
    # says so. It is never written: a folder already in .references/ is listed
    # where it stands, a git repository elsewhere is cloned in the way a URL is
    # (git reads it and writes nothing there), and anything else is refused,
    # because copying a loose folder could copy gigabytes of build output nobody
    # asked for, and moving it is the person's decision. Paths are read with
    # `cd` and `pwd -P`, which every POSIX shell has; `readlink -f` is not on
    # every Mac.
    how=url; abs=""; from=""; addr=""
    if [ -d "$url" ]; then
      here=$(pwd -P); abs=$(cd "$url" && pwd -P)
      refs=$(cd .references 2>/dev/null && pwd -P || true); refs=${refs:-$here/.references}
      case "$abs/" in
        "$refs/"?*) rel=${abs#"$refs"/}; name=${rel%%/*}; how=listed ;;
        "$here/"*) echo "$url is part of this project. A reference is another repo, or an old copy of yours kept apart; retired work of this one goes to .archive/ (just archive <path>)."; exit 1 ;;
        *) name=$(basename "$abs" | tr '[:upper:]' '[:lower:]'); how=cloned ;;
      esac
      if [ "$how" = cloned ] && [ ! -e "$abs/.git" ] && [ "$(git -C "$abs" rev-parse --is-bare-repository 2>/dev/null)" != true ]; then
        echo "$url is not a git repository, so there is nothing to clone, and ref-add copies no loose folder."
        echo "Move it into .references/ if it belongs there, then: just ref-add .references/$(basename "$abs") \"why\""; exit 1
      fi
      # A repository that has an address elsewhere keeps that address, so that
      # ref-fetch can bring it back on any machine; a path on this one is none.
      # Asked of a clone made here and of one already in .references/ alike: a
      # repository cloned by hand into .references/ used to be listed as local
      # only, and another machine skipped what it could have fetched (spec 015
      # review). The address loses any user and password written into it
      # (https://name:token@host/...), which the person never typed and which
      # would otherwise land in a tracked file and be pushed; an scp-style
      # git@host:path names a user and no secret, and stays.
      if [ -e "$abs/.git" ] || [ "$(git -C "$abs" rev-parse --is-bare-repository 2>/dev/null)" = true ]; then
        origin=$(git -C "$abs" config --get remote.origin.url 2>/dev/null || true)
        case "$origin" in file://*) ;; *://*|*@*:*) addr=$(printf '%s' "$origin" | sed -E 's#^([A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@#\1#') ;; esac
      fi
      # Otherwise the list says where a clone came from, for a person reading it
      # here, with the home folder written as ~ so that no user name reaches a
      # tracked file. `from`, not `path`: `path` already means where a
      # reference lives and is read in place, in lists written before this.
      if [ "$how" = cloned ]; then
        from="$abs"; home=$(cd "$HOME" 2>/dev/null && pwd -P || true)
        if [ -n "$home" ]; then case "$abs" in "$home"/*) from="~/${abs#"$home"/}" ;; esac; fi
      fi
    else
      case "$url" in
        /*|./*|../*|'~'*) echo "No folder at $url. A reference is a git address or a folder on this machine."; exit 1 ;;
      esac
    fi
    mkdir -p .references
    if [ ! -f .references/README.md ] && [ -f .ai-backbone/templates/references-README.md ]; then
      cp .ai-backbone/templates/references-README.md .references/README.md; echo "  added   .references/README.md"
    fi
    toml=.references/references.toml
    if [ ! -f "$toml" ]; then
      {
        echo '# Read-only references: other people'"'"'s repos, kept to learn from. Never edit them.'
        echo '# The clones are not committed. `just ref-fetch` brings them back on a new machine.'
        echo '# An entry with url = "" is a folder on this machine only: ref-fetch skips it.'
      } > "$toml"
    fi
    if [ "$how" = listed ]; then
      echo "  here    .references/$name (a folder on this machine, not committed)"
    elif [ -e ".references/$name" ]; then
      echo "  exists  .references/$name"
    elif [ "$how" = cloned ]; then
      git clone -q "$abs" ".references/$name"
      echo "  cloned  .references/$name from $abs (what was committed there; read-only, not committed)"
    else
      git clone --depth 1 -q "$url" ".references/$name"
      echo "  cloned  .references/$name (shallow, read-only, not committed)"
    fi
    if [ "$how" = url ] || [ -n "$addr" ]; then
      url=${addr:-$url}
      if grep -q "url *= *\"$url\"" "$toml" 2>/dev/null; then
        echo "  listed  already in $toml"
      else
        printf '\n[[ref]]\nname   = "%s"\nurl    = "%s"\nnote   = "%s"\nadded  = "%s"\nstatus = "frozen"\n' "$name" "$url" "$note" "$(date +%Y-%m-%d)" >> "$toml"
        echo "  listed  $toml${addr:+ (with its address, $addr)}"
      fi
    elif N="$name" awk -F'"' '/^name *=/ && $2 == ENVIRON["N"] {f=1} END {exit !f}' "$toml"; then
      echo "  listed  already in $toml"
    else
      esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
      { printf '\n[[ref]]\nname   = "%s"\nurl    = ""\n' "$(esc "$name")"
        if [ -n "$from" ]; then printf 'from   = "%s"\n' "$(esc "$from")"; fi
        printf 'note   = "%s"\nadded  = "%s"\nstatus = "frozen"\n' "$(esc "$note")" "$(date +%Y-%m-%d)"
      } >> "$toml"
      echo "  listed  $toml (local only: no other machine can fetch it)"
    fi
    echo "Read it, copy the idea out. Never write in .references/."

# Bring back every reference listed in .references/references.toml that is missing on this machine
[group('references')]
ref-fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    toml=.references/references.toml
    if [ ! -f "$toml" ]; then echo "No references listed ($toml)."; exit 0; fi
    n=0
    # One line per [[ref]]: name, url, path, from and restore, split on the
    # unit separator (\037). A tab is whitespace to `read`, so two tabs in a row
    # were one and an empty url slid the next field into its place.
    while IFS=$'\037' read -r name url path from restore; do
      [ -n "$name" ] || continue
      # A folder on this machine only: listed by hand with `path` (where it
      # lives, read in place, as lists have always said), or by ref-add
      # <folder> with url = "". There is no address to fetch it from, so it is
      # checked where it should be and said in one line, never skipped quietly
      # and never called missing when it is there.
      if [ -z "$url" ]; then
        where=".references/$name"
        if [ -n "$path" ]; then
          case "$path" in '~/'*) where="$HOME/${path#'~/'}" ;; *) where="$path" ;; esac
        fi
        if [ -d "$where" ]; then echo "  ok      ${path:-.references/$name} (local only, read where it stands)"
        else
          echo "  skipped $where: local only and not on this machine, and there is no address to fetch it from${from:+ (it came from $from)}"
          if [ -n "$restore" ]; then echo "          to bring it back: $restore"; fi
        fi
        continue
      fi
      if [ -d ".references/$name" ]; then
        echo "  ok      .references/$name"
      elif git clone --depth 1 -q "$url" ".references/$name"; then
        echo "  cloned  .references/$name"; n=$((n+1))
      else
        echo "  failed  .references/$name: git could not clone $url"
      fi
    done < <(awk -F'"' '
      function flush() { if (n != "") printf "%s\037%s\037%s\037%s\037%s\n", n, u, p, f, r; n = ""; u = ""; p = ""; f = ""; r = "" }
      /^\[/          { flush() }
      /^name *=/     { n = $2 }
      /^url *=/      { u = $2 }
      /^path *=/     { p = $2 }
      /^from *=/     { f = $2 }
      /^restore *=/  { r = $2 }
      END            { flush() }' "$toml")
    echo "$n fetched."

# Leave a note for the backbone (a bug, a gap, an idea): just backbone-note "one line"
[group('template')]
[positional-arguments]
backbone-note text:
    #!/usr/bin/env bash
    set -euo pipefail
    # One note is one line. A newline in the text would write a second backlog
    # line, with whatever date and project it liked, for an agent to work from.
    text=$(printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '\000-\037\177' | sed 's/  */ /g; s/^ //; s/ $//')
    if [ -z "$text" ]; then echo 'Say what you noticed: just backbone-note "save prints the wrong thing when ..."'; exit 1; fi
    inside=""
    if [ -n "$(just _is-backbone)" ]; then src="$PWD"; inside=1; elif ! src=$(just _backbone 2>/dev/null); then
      echo "The backbone is not on this machine (set AI_BACKBONE). Nothing written; keep the note in brain/ for now."; exit 1
    fi
    # Land the note on top of what GitHub has, so that sending it is a plain push.
    # A scheduled agent pushes every day; a note written on yesterday's tree was
    # refused, called "not reachable", and left the clone unable to pull again.
    # One at a time in that clone, with `_backbone-level` (its comment says what
    # two at once did). And never into a clone that would lose the line: a note
    # written in the middle of a rebase, or on no branch, was committed onto a
    # HEAD that the abort then threw away. One checkout with no branch is not
    # that: a scheduled run's own, which is what GitHub has; its note is saved
    # and rides the run's push to cloud (spec 017). 3.21.0 refused it too, so
    # the agent that works here every day could leave no note at all.
    if [ -d "$src/.git" ]; then
      gd=$(git -C "$src" rev-parse --git-dir 2>/dev/null); case "$gd" in /*|[A-Za-z]:*) ;; *) gd="$src/$gd" ;; esac   # C:/x is whole too, under Git Bash
      lock="$gd/backbone-level.lock"; n=0
      until mkdir "$lock" 2>/dev/null; do
        find "$lock" -maxdepth 0 -mmin +10 -exec rmdir {} \; 2>/dev/null || true
        n=$((n+1)); if [ "$n" -ge 60 ]; then echo "Nothing written: another session has been working in the backbone ($src) for a minute. Say it again in a moment."; exit 1; fi
        sleep 1
      done
      trap 'rmdir "$lock" 2>/dev/null' EXIT
      export AI_BACKBONE_LOCK_HELD=1
      nobranch=""; git -C "$src" symbolic-ref -q HEAD >/dev/null 2>&1 || nobranch=1
      if [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ] || [ -f "$gd/MERGE_HEAD" ] || { [ -n "$nobranch" ] && [ -z "$inside" ]; }; then
        echo "Nothing written: the backbone in $src is in the middle of a rebase or a merge, or on no branch, and a note written now would be lost. An agent clears that first, then says the note again."; exit 1
      fi
      if [ -z "$nobranch" ] && [ -z "$(git -C "$src" status --short --untracked-files=all 2>/dev/null)" ]; then just _backbone-level "$src" Backbone || true; fi
    fi
    f="$src/docs/backlog.md"
    if [ ! -f "$f" ]; then
      mkdir -p "$src/docs"
      printf '# Backlog\n\nNotes for the backbone from the projects built on it: bugs, gaps, ideas.\n`just backbone-note "one line"` in any project adds one. An agent working in\nthe backbone works through the open lines and ticks them (backbone-dev skill).\n' > "$f"
    fi
    project=$(grep -E '^\| *project *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//' || true); project="${project:-$(basename "$PWD")}"
    [ -n "$(tail -c1 "$f")" ] && echo >> "$f"
    printf -- '- [ ] %s, %s: %s\n' "$(date +%Y-%m-%d)" "$project" "$text" >> "$f"
    echo "  noted   $f"
    # Save and send it from the backbone, so a scheduled agent sees it. Only the
    # backlog file is committed, and every line below says what really happened:
    # "sent" once meant a refused commit, and "not reachable" a refused push.
    if [ -d "$src/.git" ]; then
      ( cd "$src"
        if [ -n "$(git status --short --untracked-files=all | grep -v ' docs/backlog.md$')" ]; then
          echo "  not saved: the backbone has unsaved work of its own. It goes with the backbone's next save."; exit 0
        fi
        # A hook may tidy the file on the first try; the second try takes the tidy file.
        saved=""
        for try in 1 2; do
          git add docs/backlog.md
          if git commit -q -m "docs: backlog note" >/dev/null 2>&1; then saved=1; break; fi
        done
        if [ -z "$saved" ]; then
          echo "  not saved: the backbone's own checks refused the note. It is written in its docs/backlog.md, uncommitted; an agent in the backbone looks at why."; exit 0
        fi
        echo "  saved   in the backbone"
        git remote get-url origin >/dev/null 2>&1 || exit 0
        if [ -n "${AI_BACKBONE_OFFLINE:-}" ]; then echo "  not sent: offline mode is on. It goes out with the next session."; exit 0; fi
        branch=$(git symbolic-ref -q --short HEAD 2>/dev/null || echo "no branch")
        # Inside the backbone, a checkout with no branch (a scheduled run's) or
        # one on cloud pushes nothing: the note rides the run's next push to
        # cloud, and the gate carries it to main (spec 017). The HEAD:main this
        # once pushed would carry the run's untested work with it.
        if [ -n "$inside" ] && { [ "$branch" = "no branch" ] || [ "$branch" = cloud ]; }; then
          echo "  not sent yet: it rides the next push to cloud (step 12 of the brief, or just publish), and the gate carries it to main."; exit 0
        fi
        if [ "$branch" != main ]; then
          echo "  not sent: the backbone in $src is on '$branch', not on main, and notes travel on main. It is saved there."; exit 0
        fi
        # A note sends itself and the notes before it, never somebody's saved,
        # unpublished work that happens to sit under it.
        other=$(git log --format=%s origin/main..HEAD 2>/dev/null | grep -cv '^docs: backlog note' || true)
        if [ "${other:-0}" -gt 0 ]; then
          echo "  not sent: the backbone has saved work of its own that is not published yet. The note is saved there and goes out with it; the agent working there runs just publish."; exit 0
        fi
        if git push -q origin HEAD 2>/dev/null; then
          echo "  sent    to GitHub"
        elif ! git fetch -q origin main 2>/dev/null; then
          echo "  not sent: GitHub not reachable. It is saved in the backbone and goes out with the next note or the next session."
        elif [ "$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)" -eq 0 ]; then
          echo "  not sent: GitHub answered and would not take it, and nothing newer is there. It is saved in the backbone; an agent there runs just publish to read why."
        elif git pull -q --rebase origin main >/dev/null 2>&1 && git push -q origin HEAD 2>/dev/null; then
          echo "  sent    to GitHub, on top of what was new there"
        else
          git rebase --abort >/dev/null 2>&1 || true
          echo "  not sent: GitHub has newer work that this note does not fit on. It is saved in the backbone; the next session there joins them."
        fi )
    fi

# ─────────────────────────── helpers ─────────────────────────
# Underscore recipes are called by the ones above and hidden from `just --list`.

# A line a person reads, in chat_lang from AGENTS.md section 0. English unless a translation exists.
[positional-arguments]
_msg key:
    #!/usr/bin/env bash
    lang=$(grep -E '^\| *chat_lang *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | tr -d ' `'); lang="${lang:-en}"
    if [ "$lang" = tr ]; then
      case "$1" in
        help-save)      echo '  just save "ne değişti"      işini bu bilgisayara kaydet'; exit 0 ;;
        help-undo)      echo '  just undo                   son kayıttan sonraki değişiklikleri at'; exit 0 ;;
        help-publish)   echo "  just publish                kayıtlı işi GitHub'a gönder"; exit 0 ;;
        help-doctor)    echo '  just doctor                 bu bilgisayarda ne eksik'; exit 0 ;;
        help-rest)      echo 'Gerisini ajanın senin için çalıştırır. `just --list` hepsini gösterir.'; exit 0 ;;
        nothing-new)    echo 'Kaydedecek yeni bir şey yok. brain/ içindeki notlar özeldir, kayda girmez.'; exit 0 ;;
        checking)       echo 'Kontrol ediliyor...'; exit 0 ;;
        saved)          echo 'Kaydedildi.'; exit 0 ;;
        not-saved)      echo 'Kaydedilmedi. Yukarıdaki kontrolün dediğini düzelt, sonra yeniden: just save'; exit 0 ;;
        too-big)        echo 'Kaydedilmedi. Bir kayıt için çok büyük (en çok %s KB olabilir):'; exit 0 ;;
        too-big-next)   echo 'Hiçbir şey kaybolmadı. Bu, ajanının işi: bu mesajı ona göster.'
                        echo "Ajan: dosya projeye ait mi? Değilse (derleme çıktısı, indirilen bir dosya, bir video) .gitignore'a ekle; özel bir dosyaysa brain/ içine taşı. Aitse küçült. Küçülmüyorsa .pre-commit-config.yaml içindeki --maxkb değerini yükselt (o dosya bu projenin kendi dosyasıdır) ve nedenini o satıra yaz. Kontrolleri asla atlama. Sonra: just save"; exit 0 ;;
        nothing-to-undo) echo 'Geri alınacak bir şey yok, her şey kayıtlı.'; exit 0 ;;
        undo-confirm)   echo 'Son kayıttan sonraki HER değişiklik silinecek. Devam? [e/H] '; exit 0 ;;
        clean-build-confirm) echo 'Silinsin mi? Bir sonraki derlemede her şey baştan derlenir. [e/H] '; exit 0 ;;
        undone)         echo 'Son kayda dönüldü.'; exit 0 ;;
        undo-kept)      echo 'Hiçbir şey değişmedi.'; exit 0 ;;
        no-remote)      echo 'Henüz bir GitHub adresi yok.'; exit 0 ;;
        create-repo)    echo 'GitHub hesabında özel bir depo açılsın mı? [e/H] '; exit 0 ;;
        nothing-sent)   echo 'Hiçbir şey gönderilmedi.'; exit 0 ;;
        published)      echo "GitHub'a gönderildi."; exit 0 ;;
      esac
    fi
    case "$1" in
      help-save)      echo '  just save "what changed"    save your work on this machine' ;;
      help-undo)      echo '  just undo                   throw away changes since the last save' ;;
      help-publish)   echo '  just publish                send saved work to GitHub' ;;
      help-doctor)    echo '  just doctor                 what is missing on this machine' ;;
      help-rest)      echo 'Everything else your agent runs for you. `just --list` shows it all.' ;;
      nothing-new)    echo 'Nothing new to save. Notes in brain/ are private and never part of a save.' ;;
      checking)       echo 'Checking...' ;;
      saved)          echo 'Saved.' ;;
      not-saved)      echo 'Not saved. Fix what the check above says, then run just save again.' ;;
      too-big)        echo 'Not saved. Too big for a save (%s KB at most):' ;;
      too-big-next)   echo "Nothing is lost. This is your agent's job: show it this message."
                      echo "Agent: does the file belong in the project? If not (a build, a download, a video), add it to .gitignore; move a private file into brain/. If it does, make it smaller. If it cannot be smaller, raise --maxkb in .pre-commit-config.yaml (this project's own file) and say why on that line. Never skip the checks. Then: just save" ;;
      nothing-to-undo) echo 'Nothing to undo. Everything is saved.' ;;
      undo-confirm)   echo 'This throws away EVERY change since the last save. Continue? [y/N] ' ;;
      clean-build-confirm) echo 'Delete it? Everything is built again from nothing the next time. [y/N] ' ;;
      undone)         echo 'Back to the last save.' ;;
      undo-kept)      echo 'Nothing changed.' ;;
      no-remote)      echo 'No GitHub address yet.' ;;
      create-repo)    echo 'Create a private repo under your GitHub account? [y/N] ' ;;
      nothing-sent)   echo 'Nothing sent.' ;;
      published)      echo 'Sent to GitHub.' ;;
      *)              echo "$1" ;;
    esac

# Print every visible root entry that the layout does not allow (docs/01-getting-started.md, "What goes where"). Empty when tidy.
#
# Three kinds of entry are not strays, and each was once reported as one:
#   - the files a repository open to the world keeps in its root, because that is
#     where GitHub and every arriving contributor look for them;
#   - whatever git is already ignoring, which is not in the repository at all and
#     so cannot be in the wrong place in it;
#   - whatever the project's own `stack.just` names in a `_root-allow` recipe. A
#     Rust project's root holds Cargo.toml, a Node one's holds package.json, and
#     the backbone cannot know which language it is looking at. One line:
#         _root-allow:
#             @echo "Cargo.toml Cargo.lock rust-toolchain.toml"
#
# A check that names things that do belong is a check people stop reading, and
# then it cannot tell them about the thing that does not.
_root-strays:
    #!/usr/bin/env bash
    allowed=" README.md AGENTS.md CLAUDE.md GEMINI.md Justfile LICENSE stack.just docs src brain graphify-out "
    # CHANGELOG.md too, in every project and not only here: the session skill asks
    # a project to keep one in its root from its first version on, and doctor
    # called a project's own a stray (measured in a new project, 2026-09-19).
    allowed="$allowed CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md CHANGELOG.md "
    allowed="$allowed $(just _root-allow 2>/dev/null) "
    out=""
    for e in *; do
      [ -e "$e" ] || continue
      case "$allowed" in *" $e "*) continue ;; esac
      git check-ignore -q "$e" 2>/dev/null && continue
      out="$out $e"
    done
    printf '%s' "$out"

# What the backbone has a ready file for, read from the file names in its
# examples folder and from nowhere else: `_examples <backbone> stack` prints
# "flutter rust swift", `_examples <backbone> ci` prints "flutter generic rust".
# Nothing when the folder is not there.
[positional-arguments]
_examples src kind:
    #!/usr/bin/env bash
    ls "$1/.ai-backbone/examples" 2>/dev/null | sed -n "s/^$2-\([a-z0-9]*\)\.[a-z]*$/\1/p" | tr '\n' ' ' | sed 's/ $//'

# ── build output (spec 015) ──
# One machine often builds several projects at once: two or three IDE windows,
# an agent in a terminal. Measured on 2026-09-23, on a 24 GB machine: two Rust
# projects shared one build folder and each waited on the other's lock without a
# word, that folder had grown to 335 GB with nothing ever saying so, and two
# heavy jobs at once had run the machine out of memory four days earlier. The
# backbone cannot know a language's build, so the language layer says it, the
# way it says `_root-allow`: a private `_build-info` recipe in stack.just, one
# line per answer, a key and its value.
#     _build-info:
#         @echo "dir   target"              # the build folder, from the project root or absolute
#         @echo "names cargo rustc"         # the programs a build runs, as the process list names them
#         @echo "jobs  CARGO_BUILD_JOBS"    # the variable that caps a build's parallel jobs
#         @echo "clean clean-build"         # the recipe that clears the folder
#         @echo "set   CARGO_TARGET_DIR"    # the setting that put the folder elsewhere, when one did
# A layer without it is never measured and never waits. Nothing here moves a
# build folder or deletes one: where the output goes is read by the IDE as well
# as by these recipes, and a folder chosen by `just` alone would build every
# crate twice; clearing it is the person's decision, every time.

# Before a heavy build, wait for one already running on this machine. The
# layer's heavy recipes start their build through it:
#     cd {{server_dir}} && env $(just _build-wait) cargo test --workspace
# Its sentences go to stderr, where the person reads them. Stdout carries only
# the cap, when there is one ("CARGO_BUILD_JOBS=7"), and `env` hands it to the
# build; with none, `env` runs the build as it is. A core too old to have this
# recipe prints nothing on stdout either, so the line still builds.
#
# Nothing running: back at once, nothing said. Something running: one line,
# a look every five seconds, and one line when it goes on. After
# BUILD_WAIT_MINUTES (default 20) it goes on anyway, with half the machine's
# cores, because memory at link time is what two builds at once run out of.
# BUILD_WAIT_MINUTES=0 switches it off: a CI runner that builds alone, an agent
# that has already looked.
#
# The process list is POSIX `ps -o comm=`, the same on macOS, Linux and WSL:
# each program's own name, never its arguments. Arguments name the compiler in
# every shell line that starts one, this recipe's own caller among them, and in
# the search itself. Linux keeps the first 15 characters of a name, so a layer
# names short ones. Where `ps` cannot list processes (a minimal container, a
# shell that has another `ps`), there is no answer and no wait: a check that
# cannot see never holds anybody up.
_build-wait:
    #!/usr/bin/env bash
    set -u
    limit=$(awk -v m="${BUILD_WAIT_MINUTES:-20}" 'BEGIN { s = int(m * 60); print (s > 0 ? s : 0) }')
    [ "$limit" -gt 0 ] 2>/dev/null || exit 0
    names=""; jobs=""
    while read -r k v; do
      case "$k" in names) names="$v" ;; jobs) jobs="$v" ;; esac
    done <<< "$(just _build-info 2>/dev/null || true)"
    [ -n "$names" ] || exit 0
    # 0: a build is running. 1: none is. 2: this machine cannot say.
    # This person's own programs, with their state: a build another user runs —
    # a container on a Linux host, a colleague on a shared server — never holds
    # this person's lock, and one stopped with Ctrl-Z in a forgotten terminal is
    # not running (spec 015 review). `stat` is not in POSIX's list, but BSD ps,
    # GNU procps and BusyBox all have it; where the narrower question is refused,
    # every program's name is read instead, as before.
    running() {
      local procs withstat=1 uid
      uid=$(id -u 2>/dev/null) || uid=""
      if [ -n "$uid" ] && procs=$(ps -u "$uid" -o stat= -o comm= 2>/dev/null) && [ -n "$procs" ]; then :
      elif procs=$(ps -A -o comm= 2>/dev/null) && [ -n "$procs" ]; then withstat=0
      else return 2; fi
      awk -v names="$names" -v withstat="$withstat" '
        BEGIN { n = split(names, w, " "); for (i = 1; i <= n; i++) want[w[i]] = 1 }
        { line = $0; sub(/^[ \t]+/, "", line)
          if (withstat) { st = line; sub(/[ \t].*/, "", st); sub(/^[^ \t]+[ \t]*/, "", line); if (st ~ /^T/) next }
          sub(/[ \t]+$/, "", line); sub(/.*\//, "", line); if (line in want) { found = 1; exit } }
        END { exit !found }' <<< "$procs"
    }
    running || exit 0
    span() { if [ $(($1 % 60)) -eq 0 ]; then n=$(($1 / 60)) u=minute; else n=$1 u=second; fi
             if [ "$n" -eq 1 ]; then echo "1 $u"; else echo "$n ${u}s"; fi; }
    echo "Another build is running on this machine ($(echo $names | sed 's/ /, /g')). This one waits for it to finish, up to $(span "$limit") (BUILD_WAIT_MINUTES; 0 switches this off)." >&2
    poll=5; [ "$limit" -ge "$poll" ] || poll=$limit
    waited=0
    while [ "$waited" -lt "$limit" ]; do
      sleep "$poll"; waited=$((waited + poll))
      running; r=$?
      if [ "$r" -eq 1 ]; then echo "The other build has finished. Going on." >&2; exit 0; fi
      if [ "$r" -eq 2 ]; then echo "Going on: the process list can no longer be read." >&2; exit 0; fi
    done
    cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 2)
    case "$cores" in ""|*[!0-9]*) cores=2 ;; esac
    half=$((cores / 2)); [ "$half" -ge 1 ] || half=1
    case "$jobs" in ""|[0-9]*|*[!A-Za-z0-9_]*) jobs="" ;; esac
    if [ -z "$jobs" ]; then
      echo "The other build is still running after $(span "$limit"). Going on anyway." >&2; exit 0
    fi
    # A cap the person set lower is theirs, and stays.
    own="${!jobs:-}"
    case "$own" in ""|*[!0-9]*) own="" ;; esac
    if [ -n "$own" ] && [ "$own" -le "$half" ]; then
      echo "The other build is still running after $(span "$limit"). Going on anyway, with your own $jobs=$own." >&2; exit 0
    fi
    echo "The other build is still running after $(span "$limit"). Going on anyway, with $half of this machine's $cores cores ($jobs=$half), so the two builds together use less memory." >&2
    printf '%s=%s\n' "$jobs" "$half"

# Print a folder's size as kilobytes and in words ("12345678 12 GB"), "timeout"
# when it could not be measured within the seconds given, or nothing when it
# cannot be measured at all. `du -sk` is the one size
# both BSD and GNU du give in the same unit. du reads every file, and a build
# folder of hundreds of gigabytes takes it minutes, so the caller says how long
# it may take: a du still going then is stopped, and says nothing. The watcher
# stops its own sleep too, and writes nowhere: a sleep left holding the
# caller's `$(...)` open would make every call as slow as the limit.
[positional-arguments]
_build-size dir secs="60":
    #!/usr/bin/env bash
    [ -d "$1" ] || exit 0
    secs="${2:-60}"; case "$secs" in ""|*[!0-9]*) secs=60 ;; esac
    out=$(mktemp 2>/dev/null) || exit 0
    # -H: a build folder that is a link (to another disk, often) is measured
    # where it points. Without it both BSD and GNU du measure the link, 0 KB.
    du -H -s -k "$1" > "$out" 2>/dev/null &
    du_pid=$!
    # The watcher sleeps the limit, then stops du. When du ends first, the sleep
    # is stopped by its own number, kept in a file: killing the watcher did not
    # end its sleep under Git Bash, and every doctor in a Rust project waited the
    # full minute (spec 020). The .done file keeps a finished du's number, which
    # may be somebody else's by then, from being killed.
    ( sleep "$secs" & echo "$!" > "$out.sleep"; wait "$!"; [ -e "$out.done" ] || kill "$du_pid" 2>/dev/null ) >/dev/null 2>&1 &
    watch=$!
    wait "$du_pid" 2>/dev/null; rc=$?
    : > "$out.done"
    i=0; until [ -s "$out.sleep" ] || [ "$i" -ge 100 ]; do sleep 0.02; i=$((i + 1)); done
    kill "$(cat "$out.sleep" 2>/dev/null)" 2>/dev/null; wait "$watch" 2>/dev/null; rm -f "$out.sleep" "$out.done"
    # Stopped by the watcher: not "cannot be measured" but "too big to measure
    # in the time given", which is exactly the folder a person needs to hear
    # about. The caller says it in words.
    if [ "$rc" -gt 128 ]; then rm -f "$out"; echo "timeout"; exit 0; fi
    kb=$(awk 'NR == 1 { print $1 }' "$out"); rm -f "$out"
    case "$kb" in ""|*[!0-9]*) exit 0 ;; esac
    awk -v k="$kb" 'BEGIN { g = k / 1048576
      if (g >= 10) h = sprintf("%d GB", g + 0.5); else if (g >= 1) h = sprintf("%.1f GB", g)
      else if (k >= 1024) h = sprintf("%d MB", k / 1024 + 0.5); else h = sprintf("%d KB", k)
      print k, h }'

# Print "yes" when a build folder lies outside this project, where other
# projects can build into it too — whether any does, nothing here can know, so
# what is said about it says "can". Nothing otherwise. Physical paths on both sides:
# /tmp is /private/tmp on one system and not on another, and a target/ that is
# a link to somewhere else is somewhere else. A folder not built yet is read
# from its nearest parent that exists.
[positional-arguments]
_build-shared dir:
    #!/usr/bin/env bash
    d="$1"
    # A Windows path (C:\x or C:/x, what CARGO_TARGET_DIR holds there) is read as
    # Git Bash writes it first: taken as relative, it was always "inside" (spec 020).
    if command -v cygpath >/dev/null 2>&1; then d=$(cygpath -u "$d"); fi
    case "$d" in /*) ;; *) d="$PWD/$d" ;; esac
    rest=""
    while [ ! -d "$d" ] && [ "$d" != / ]; do rest="/$(basename "$d")$rest"; d=$(dirname "$d"); done
    d="$(cd "$d" 2>/dev/null && pwd -P)$rest"
    here=$(pwd -P)
    case "$d/" in "$here"/*) ;; *) echo yes ;; esac

# Where this project's second copy lives: <place>/<project>. Nothing when this
# machine has no place yet.
#
# The place is asked for once per machine, not once per project, so it lives in
# git's own settings for the person (`git config --global ai-backbone.vault-copy
# "<folder>"`), which every project on the machine already reads and no project
# tracks. No recipe sets it: an agent does, after asking the person once.
# `--path` lets git read a leading ~/ the way a shell would (measured on git 2.55).
#
# One folder per project, named like the project's own folder would be: the
# project row of AGENTS.md section 0 through `_slug`. `adopt` fills that row
# with the folder's name from 3.24.1 on, but a project adopted before it still
# says "ai-backbone" there; two of those would share one folder, and their
# vaults would be laid over each other. Such a project is filed under its
# folder's name.
_vault-dest:
    #!/usr/bin/env bash
    place=$(git config --global --get --path ai-backbone.vault-copy 2>/dev/null || true)
    [ -n "$place" ] || exit 0
    project=$(grep -E '^\| *project *\|' AGENTS.md 2>/dev/null | head -1 | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
    if [ "$project" = ai-backbone ] && [ -z "$(just _is-backbone)" ]; then project=""; fi
    name=$(just _slug "${project:-$(basename "$PWD")}")
    printf '%s/%s\n' "${place%/}" "${name:-$(basename "$PWD")}"

# Every file outside brain/ whose name says it is a secret: an .env of any kind
# but the example, an .envrc, and the endings keys and certificates come with.
# Build and dependency folders are not looked into (a node_modules holds other
# people's test keys by the hundred), nor is .references/, which is other
# people's repositories. One list, read twice: `_vault-copy` takes from it what
# git ignores, doctor names the keys in it.
_secret-files:
    #!/usr/bin/env bash
    find . \( -path ./brain -o -path ./.references -o -name .git -o -name node_modules -o -name target \
              -o -name build -o -name dist -o -name .venv -o -name Pods -o -name DerivedData \
              -o -name .dart_tool -o -name .gradle \) -prune \
      -o -type f \( -name .env -o -name '.env.*' -o -name .envrc -o -name '*.pem' -o -name '*.key' \
              -o -name '*.p8' -o -name '*.p12' -o -name '*.pfx' -o -name '*.jks' -o -name '*.keystore' \
              -o -name '*.mobileprovision' \) ! -name .env.example -print 2>/dev/null | sed 's|^\./||' | sort

# The second copy of brain/, and of the secret files git does not hold.
#
# brain/ is ignored by git on purpose, so in every project it existed on one
# disk only. Measured on the maintainer's machine (2026-09-19): eight vaults,
# under 1 MB to about 90 MB, most of it large files that never change, and a
# journal that changes every session. A zip would be written and uploaded whole
# each time; a mirror moves only what changed, leaves exactly one folder per
# project, and rsync is on every Mac (`-a` and `--exclude` measured on openrsync,
# protocol 29, and on rsync 3.4.1).
#
# Never `--delete`: a file lost here by accident is still there. Never into a
# folder git saves: the secret files would be in the next commit of whatever
# project that is, which is how the place that holds the projects (the Desktop)
# is refused when a project's own folder has the name the copy would take.
# A git repository inside brain/ is copied without its .git: a synced folder is
# reported to damage one, and no vault here held one when this was written.
# An .env is copied and never moved: its tool reads it where it is.
#
# The copy is written on this machine. Whether a cloud drive has uploaded it is
# the drive's business, so this says "copied" and nothing about a cloud. It
# never fails its caller, and it copies what is there when it runs: the journal
# entry session-end has just created is still empty, and one written earlier in
# the day is about to grow, which is why it always asks to be run once more.
_vault-copy:
    #!/usr/bin/env bash
    set -uo pipefail
    [ -d brain ] || exit 0
    dest=$(just _vault-dest 2>/dev/null || true)
    if [ -z "$dest" ]; then
      echo "brain/ has no second copy: this machine has no place for one yet. An agent asks the person once for a folder (a cloud drive folder, a second disk), then: git config --global ai-backbone.vault-copy \"<folder>\""
      exit 0
    fi
    place=$(dirname "$dest")
    if [ ! -d "$place" ]; then
      echo "brain/ was not copied: $place is not there (a disk that is not plugged in, a drive that is not signed in?)."; exit 0
    fi
    if ! command -v rsync >/dev/null 2>&1; then echo "brain/ was not copied: rsync is not on this machine."; exit 0; fi
    inside="$place"; if [ -d "$dest" ]; then inside="$dest"; fi
    if [ "$(git -C "$inside" rev-parse --is-inside-work-tree 2>/dev/null || true)" = true ]; then
      echo "brain/ was not copied: $inside is inside a project that git saves, so the secret files would end up in a save. The place for second copies has to be a folder of its own."; exit 0
    fi
    case "$(cd "$place" 2>/dev/null && pwd -P)/" in "$(pwd -P)"/*)
      echo "brain/ was not copied: $place is inside this project. The place for second copies has to be a folder of its own."; exit 0 ;;
    esac
    was=$(sed -n 's/^Written by just session-end, last on .*, from //p' "$dest/about-this-copy.txt" 2>/dev/null || true)
    if [ -n "$was" ] && [ "$was" != "$PWD" ] && [ -d "$was/brain" ]; then
      echo "brain/ was not copied: $dest holds the copy of the project in $was, and this folder has the same project name (a clone, a worktree, a duplicate). Nothing was written over it. If this folder is the real one, remove $dest/about-this-copy.txt and run just session-end again."; exit 0
    fi
    if ! mkdir -p "$dest/brain" 2>/dev/null || [ ! -w "$dest/brain" ]; then
      echo "brain/ was not copied: $dest cannot be written."; exit 0
    fi
    full=1
    if ! rsync -a --exclude='.git' brain/ "$dest/brain/"; then
      echo "brain/ was not copied in full to $dest/brain: what rsync said is above."; full=0
    fi
    repos=$(find brain -name .git -prune -print 2>/dev/null | tr '\n' ' ')
    n=0; names=""
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      git check-ignore -q -- "$s" 2>/dev/null || continue
      mkdir -p "$dest/secrets/$(dirname "./$s")" && rsync -a "./$s" "$dest/secrets/$s" && { n=$((n+1)); names="$names $s"; }
    done < <(just _secret-files)
    project=$(grep -E '^\| *project *\|' AGENTS.md 2>/dev/null | head -1 | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
    {
      echo "${project:-$(basename "$PWD")}: the second copy of what git does not hold."
      echo "Written by just session-end, last on $(date '+%Y-%m-%d %H:%M') on $(hostname 2>/dev/null || echo this machine), from $PWD"
      echo
      echo "brain/     the private vault as it was then. A file deleted in the project is still here."
      echo "secrets/   the secret files git ignores (.env, keys, certificates), each under its own path in the project."
      echo
      echo "On a new disk: get the project from GitHub, copy brain/ into it, and put each file"
      echo "under secrets/ back at the same path. This file says when the copy was written."
      echo "Whether the folder has reached a cloud since is the drive's to say."
    } > "$dest/about-this-copy.txt"
    if [ "$full" -eq 1 ]; then echo "brain/ copied to $dest/brain as it is now. The copy is taken when this command runs: after writing today's entry, run just session-end once more."; fi
    if [ "$n" -gt 0 ]; then echo "Copied beside it, to secrets/, what git ignores and a lost disk would take:$names"; fi
    links=$(find brain -type l 2>/dev/null | while IFS= read -r l; do case "$(readlink "$l")" in (/*) printf '%s ' "$l" ;; esac; done)
    if [ -n "$links" ]; then echo "Copied as links only, not the files they point to outside brain/: $links(put the file itself in brain/ if the copy should hold it)."; fi
    if [ -n "$repos" ]; then echo "Left out: $repos(a synced folder is reported to damage a git repository, so its files were copied and its history was not)."; fi

# A line of `just doctor` that a person reads, in chat_lang (AGENTS.md section 0),
# the way `_msg` does it for save, undo and publish. The rows an agent acts on
# stay English; these are the ones that need the person: where the second copy
# is, a key in the wrong place, and how doctor ends.
[positional-arguments]
_doctor-msg key a="" b="":
    #!/usr/bin/env bash
    lang=$(grep -E '^\| *chat_lang *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | tr -d ' `'); lang="${lang:-en}"
    a="${2:-}"; b="${3:-}"
    if [ "$lang" = tr ]; then
      case "$a" in 0) age="bir günden yeni" ;; *) age="$a günlük" ;; esac
      case "$1" in
        copy-none)        echo "brain/ klasörünün ikinci bir kopyası yok. Ajanına bir klasör söyle (bulut sürücüsünde bir klasör, ikinci bir disk); bu bilgisayar için bir kez sorulur."; exit 0 ;;
        copy-unreachable) echo "ikinci kopyaların yeri bulunamadı: $a  (takılı olmayan bir disk, oturumu kapalı bir sürücü?)"; exit 0 ;;
        copy-never)       echo "brain/ klasörünün ikinci kopyası henüz yazılmadı. Bir sonraki just session-end şuraya yazar: $a"; exit 0 ;;
        copy-age)         echo "brain/ klasörünün ikinci kopyası: $age, yeri $b"; exit 0 ;;
        key-outside)      echo "brain/ dışında bir anahtar ya da sertifika dosyası var:"; exit 0 ;;
        key-where)        echo "yeri brain/05-files/ (AGENTS.md bölüm 7); onu okuyan araca yeni yeri gösterilir"; exit 0 ;;
        end-ok)           echo "Gereken her şey kurulu."; exit 0 ;;
        end-missing)      echo "Eksik bir şey var. Yukarıdaki MISS satırlarını kur, ya da şunu çalıştır: sh .ai-backbone/setup.sh"; exit 0 ;;
        end-language)     echo "Omurganın kendi araçları tamam. Eksik olan, bu projenin dilinin istediği: Language başlığı altındaki MISS satırları her birinin nereden kurulacağını söylüyor. setup.sh bunları kurmaz; ajanın kurar."; exit 0 ;;
        end-both)         echo "setup.sh yalnızca omurganın kendi araçlarını kurar. Dilin istedikleri (Language altındaki MISS satırları) her satırın söylediği yerden kurulur."; exit 0 ;;
      esac
    fi
    case "$a" in 0) age="less than a day old" ;; 1) age="1 day old" ;; *) age="$a days old" ;; esac
    case "$1" in
      copy-none)        echo "brain/ has no second copy. Tell your agent a folder for it (a folder in a cloud drive, a second disk); it is asked once for this machine." ;;
      copy-unreachable) echo "the place for second copies is not there: $a  (a disk that is not plugged in, a drive that is not signed in?)" ;;
      copy-never)       echo "no second copy of brain/ written yet. The next just session-end writes it to $a" ;;
      copy-age)         echo "second copy of brain/: $age, in $b" ;;
      key-outside)      echo "a key or certificate sits outside brain/:" ;;
      key-where)        echo "it belongs in brain/05-files/ (AGENTS.md section 7); whatever reads it is pointed there" ;;
      end-ok)           echo "Everything needed is installed." ;;
      end-missing)      echo "Something is missing. Install the MISS lines above, or run: sh .ai-backbone/setup.sh" ;;
      end-language)     echo "The backbone's own tools are all here. What is missing is what this project's language needs: the MISS lines under Language say where to get each one. setup.sh does not install those; your agent does." ;;
      end-both)         echo "setup.sh installs the backbone's own tools only. What the language needs (the MISS lines under Language) comes from where each line says." ;;
      *)                echo "$1" ;;
    esac

# The week's usage in full: the meter, this machine's tokens by day and model, the cap
[positional-arguments]
_budget *args:
    #!/usr/bin/env bash
    "$(just _py)" .ai-backbone/budget.py "$@"

# Raise this session's subagent cap after the person said yes: just _agent-cap 20 <the folder the refusal names>
[positional-arguments]
_agent-cap n dir:
    #!/usr/bin/env bash
    set -eu
    case "$1" in ""|*[!0-9]*) echo "The cap is a number: just _agent-cap 20 <folder>"; exit 1 ;; esac
    case "$2" in */ai-backbone-agents/*) ;; *) echo "Not a session folder: $2 (the refusal names it)"; exit 1 ;; esac
    mkdir -p "$2"; printf '%s\n' "$1" > "$2/cap"
    s=0; [ -f "$2/started" ] && s=$(wc -l < "$2/started" | tr -d ' ')
    echo "Subagent cap for this session: $1 ($s started so far). For every session on this machine: git config --global ai-backbone.agent-cap $1"

# Print "yes" when this repo is the backbone itself, nothing otherwise
_is-backbone:
    @grep -q '^# ai-backbone' README.md 2>/dev/null && echo yes || true

# Print "yes" when this folder is the top of a git work tree, nothing otherwise.
#
# Asked of git, never of the folder. `[ -d .git ]` stood in nine places, and in a
# linked worktree `.git` is a file: `just save` sent an agent working in one away
# with "No git repo yet". And asked exactly: `git rev-parse --git-dir` also
# succeeds in a plain folder inside somebody else's repository, where the
# `git add -A` of a save would stage that whole repository (measured on git
# 2.55.0). `--show-cdup` prints nothing at the top of a work tree, linked or not,
# `../` below one, and fails outside.
_is-repo:
    @up=$(git rev-parse --show-cdup 2>/dev/null) && [ -z "$up" ] && echo yes || true

# Print the path of a local backbone: AI_BACKBONE, else a sibling ai-backbone up to three levels up. Exit 1 when none.
_backbone:
    #!/usr/bin/env bash
    src="${AI_BACKBONE:-}"
    if [ -z "$src" ]; then
      for up in .. ../.. ../../..; do
        if [ -f "$up/ai-backbone/.ai-backbone/manifest.txt" ]; then src="$up/ai-backbone"; break; fi
      done
    fi
    [ -n "$src" ] && [ -f "$src/.ai-backbone/manifest.txt" ] || exit 1
    cd "$src" && pwd -P

# Bring the local backbone up to date with GitHub (a scheduled agent pushes there). Quiet unless something arrived or is in the way.
[positional-arguments]
_backbone-refresh src:
    #!/usr/bin/env bash
    just _backbone-level "$1" Backbone
    just _backbone-tag "$1"

# Bring a backbone clone level with GitHub: take what is new there, send the notes
# that never went out. There is one of these because there were three pulls, and
# each failed its own way: a clone one note ahead could never fast-forward again
# and said nothing, the backbone's session-start said "up to date" on top of a
# rebase it had left half done, and a refused push was called a dead network
# (all measured, 3.21.0). This one never leaves a rebase behind and never calls a
# clone current that it could not check. `who` is the voice: "GitHub" inside the
# backbone, which says everything; "Backbone" from a project, which is quiet
# when there is nothing to say. It never fails its caller.
[positional-arguments]
_backbone-level src who="Backbone":
    #!/usr/bin/env bash
    src="$1"; who="${2:-Backbone}"
    [ -z "${AI_BACKBONE_OFFLINE:-}" ] || exit 0
    [ -d "$src/.git" ] || exit 0
    g() { git -C "$src" "$@"; }
    g remote get-url origin >/dev/null 2>&1 || exit 0
    if [ "$who" = GitHub ]; then loud=1; place="here"; stale=""
    else loud=""; place="in $src"; stale=" Until an agent clears it, what this project is compared with may be old, and notes may not reach GitHub."; fi
    gd=$(g rev-parse --git-dir 2>/dev/null); case "$gd" in /*|[A-Za-z]:*) ;; *) gd="$src/$gd" ;; esac   # C:/x is whole too, under Git Bash
    # One at a time. Two sessions starting together (several agents of one
    # workflow each run session-start) rebased the same clone at once: measured,
    # that leaves a staged deletion of the newest note, or a note committed on a
    # detached HEAD, and the next note then removes a line on GitHub and says
    # "sent". The second one leaves quietly: the first is doing the work. A lock
    # older than ten minutes belongs to a run that died.
    lock="$gd/backbone-level.lock"
    if [ -z "${AI_BACKBONE_LOCK_HELD:-}" ]; then
      find "$lock" -maxdepth 0 -mmin +10 -exec rmdir {} \; 2>/dev/null || true
      mkdir "$lock" 2>/dev/null || exit 0
      trap 'rmdir "$lock" 2>/dev/null' EXIT
    fi
    if [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ] || [ -f "$gd/MERGE_HEAD" ]; then
      echo "$who: not brought up to date: a rebase or a merge was left half done $place. An agent finishes or aborts it before any other work.$stale"; exit 0
    fi
    if [ -n "$(g status --short)" ]; then
      echo "$who: not brought up to date: there is unsaved work $place. An agent saves it first (just save).$stale"; exit 0
    fi
    branch=$(g symbolic-ref -q --short HEAD 2>/dev/null || echo "no branch")
    # main first, as always. Then cloud, the branch the runs push to (spec 017),
    # tolerated when GitHub has none: an older remote, a project's stand-in.
    if ! g fetch -q origin +refs/heads/main:refs/remotes/origin/main 2>/dev/null; then
      if [ -n "$loud" ]; then echo "$who: not reachable right now."; fi
      exit 0
    fi
    g fetch -q origin +refs/heads/cloud:refs/remotes/origin/cloud 2>/dev/null || true
    has() { g merge-base --is-ancestor "$1" HEAD 2>/dev/null; }
    # Once cloud has been ahead of main for two days, every session hears it,
    # projects included: the one way a gate that stopped reaches a person's
    # agent. The oldest commit is measured, not the tip: the run merges main
    # into cloud daily, so the tip is never old while the same work waits.
    stuck() {
      local n oldest days
      g rev-parse -q --verify origin/cloud >/dev/null 2>&1 || return 0
      n=$(g rev-list --count origin/main..origin/cloud 2>/dev/null || echo 0)
      [ "${n:-0}" -gt 0 ] || return 0
      # The smallest date, not the last line: log order is the walk, not the clock.
      oldest=$(g log --no-merges --format=%ct origin/main..origin/cloud 2>/dev/null | awk 'NR == 1 || $1 < m { m = $1 } END { if (NR) print m }')
      [ -n "$oldest" ] || return 0
      days=$(( ( $(date +%s) - oldest ) / 86400 ))
      [ "$days" -ge 2 ] || return 0
      echo "$who: cloud is $n commit(s) ahead of main, the oldest $days days old, and the gate has not carried them: the last 'gate:' line in docs/routine-log.md on cloud says why."
    }
    # A scheduled run's checkout has no branch at all and is exactly what GitHub
    # has: main, or cloud with main merged in (step 4 of the brief). Telling an
    # agent nobody supervises, as its first fact of the day, that its tree is
    # not current would be untrue.
    if [ "$branch" = "no branch" ] && [ -n "$loud" ]; then
      if [ "$(g rev-parse HEAD 2>/dev/null)" = "$(g rev-parse -q --verify origin/main 2>/dev/null)" ] \
         || { has origin/main && g rev-parse -q --verify origin/cloud >/dev/null 2>&1 && has origin/cloud; }; then
        echo "$who: up to date (a checkout with no branch, as a scheduled run's is)."; stuck; exit 0
      fi
    fi
    # A clone on cloud is an attended session's: levelled with cloud by a merge
    # (a rebase would replay main's notes as twins) and never pushed from here,
    # because a push to cloud is a publish and the gate runs on it. From a
    # project it is left alone and named: what projects copy from it is
    # untested until it is back on main.
    if [ "$branch" = cloud ]; then
      if [ -z "$loud" ]; then
        echo "$who: not brought up to date: the backbone $place is on 'cloud', not on main, and what projects copy from it is untested until an agent there runs git checkout main.$stale"; stuck; exit 0
      fi
      if ! g rev-parse -q --verify origin/cloud >/dev/null 2>&1; then echo "$who: not brought up to date: GitHub has no cloud branch yet."; exit 0; fi
      target=origin/cloud; how=--no-rebase
    elif [ "$branch" != main ]; then
      echo "$who: not brought up to date: the backbone $place is on '$branch', not on main.$stale"; exit 0
    else
      target=origin/main; how=--rebase
    fi
    behind=$(g rev-list --count "HEAD..$target" 2>/dev/null || echo 0)
    ahead=$(g rev-list --count "$target..HEAD" 2>/dev/null || echo 0)
    # Notes are the backbone's own traffic and are moved freely. Any other commit
    # that is ahead is somebody's saved, unpublished work: a project's session
    # never rebases that from outside. Whoever works there does, in their own.
    other=$(g log --format=%s "$target..HEAD" 2>/dev/null | grep -cv '^docs: backlog note' || true)
    if [ "${behind:-0}" -gt 0 ] && [ "${other:-0}" -gt 0 ] && [ -z "$loud" ]; then
      echo "$who: $behind new commit(s) on GitHub, and $other saved but unpublished $place. Left as it is; the agent working there starts a session in it, which joins them.$stale"; exit 0
    fi
    if [ "${behind:-0}" -gt 0 ]; then
      old=$(g rev-parse HEAD)
      # git prints CONFLICT on stdout, so both streams go; the abort is what
      # keeps a failure from becoming the state the next session starts in.
      if g pull -q "$how" origin "${target#origin/}" >/dev/null 2>&1; then
        if [ -n "$loud" ]; then echo "$who: pulled $behind new commit(s) into the backbone:"; g log --format='  %h %s' -"$behind" "$target"
        else echo "$who: pulled $behind new commit(s) from GitHub into $src"; fi
        # The scheduled agent can edit its own brief and the files that hold it
        # back, and no hook looks at them. This machine is the first reader it
        # cannot reach, so this is where a change to them is said out loud.
        rails=$(g diff --name-only "$old" HEAD -- .ai-backbone/routine.md .ai-backbone/gate.sh .github/workflows .gitignore .claude/settings.json .pre-commit-config.yaml 2>/dev/null | tr '\n' ' ')
        if [ -n "$rails" ]; then echo "$who: what came in changed the scheduled agent's own guard rails: $rails-> an agent reads that change before anything is copied from it (just template-update)."; fi
      else
        g rebase --abort >/dev/null 2>&1 || true
        g merge --abort >/dev/null 2>&1 || true
        if [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ] || [ -f "$gd/MERGE_HEAD" ]; then
          echo "$who: $behind new commit(s) on GitHub and $ahead $place do not fit together, and the rebase could not be taken back: it is half done $place. An agent finishes or aborts it before any other work.$stale"
        else
          echo "$who: $behind new commit(s) on GitHub and $ahead $place do not fit together. Nothing was changed; an agent joins them before any other work.$stale"
        fi
        exit 0
      fi
    fi
    ahead=$(g rev-list --count "$target..HEAD" 2>/dev/null || echo 0)
    if [ "${ahead:-0}" -gt 0 ]; then
      # Notes are meant to travel, so the ones that never went out go now. Any
      # other commit was saved and not published on purpose: a push is a public
      # act, and it stays the act of whoever works here. On cloud every push is
      # that act: the gate runs on it.
      other=$(g log --format=%s "$target..HEAD" | grep -cv '^docs: backlog note' || true)
      if [ "${other:-0}" -gt 0 ] || [ "$branch" = cloud ]; then
        if [ -n "$loud" ]; then echo "$who: $ahead commit(s) here are not on GitHub yet -> just publish"
        else echo "$who: $ahead commit(s) $place are saved but not published. The agent working there runs just publish."; fi
      elif g push -q origin HEAD 2>/dev/null; then
        echo "$who: sent $ahead note(s) to GitHub that had not gone out."
      else
        echo "$who: $ahead note(s) $place are not on GitHub yet, and it would not take them just now. It is tried again at the next session."
      fi
    elif [ "${behind:-0}" -eq 0 ] && [ -n "$loud" ]; then
      echo "$who: up to date."
    fi
    stuck
    exit 0

# A scheduled agent can push commits but sometimes not tags. Tag the version in
# core.just on GitHub when it is not there yet. Best effort: it never fails its caller.
[positional-arguments]
_backbone-tag src:
    #!/usr/bin/env bash
    src="$1"
    [ -z "${AI_BACKBONE_OFFLINE:-}" ] || exit 0
    [ -d "$src/.git" ] || exit 0
    git -C "$src" remote get-url origin >/dev/null 2>&1 || exit 0
    # Both the version and the commit are what GitHub's main has, never this
    # folder's files or HEAD: a version bumped in unsaved work was tagged on the
    # commit before it, and a saved, unpublished one was uploaded under its tag
    # (both measured, 3.21.0). A tag on GitHub cannot be taken back by the person.
    # Since spec 017 the gate on GitHub tags at the carry, from the same line of
    # the same commit; this is the backstop for the days it is off, and whichever
    # of the two is first wins, the other finds the tag and leaves it.
    # Git Bash reads origin/main:x/y as a list of paths and hands git
    # origin\main;x\y, so no tag was ever made from Windows (spec 020); the two
    # switches turn that off there and mean nothing anywhere else.
    v=$(MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' git -C "$src" show origin/main:.ai-backbone/core.just 2>/dev/null | grep -m1 -oE 'version [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
    [ -n "$v" ] || exit 0
    # GitHub is what counts, not this machine. A tag that exists only here means
    # an earlier push was refused, so try it again instead of giving up for good.
    # No answer at all is not a refusal: say nothing and try at the next session.
    there=$(git -C "$src" ls-remote --tags origin "refs/tags/v$v" 2>/dev/null) || exit 0
    [ -z "$there" ] || exit 0
    git -C "$src" rev-parse -q --verify "refs/tags/v$v" >/dev/null 2>&1 || git -C "$src" tag "v$v" origin/main 2>/dev/null || exit 0
    if git -C "$src" push -q origin "v$v" 2>/dev/null; then
      echo "Backbone: tagged v$v on GitHub."
    else
      echo "Backbone: v$v is tagged here, but GitHub would not take the tag. Nothing is lost; it is tried again next time."
    fi
    exit 0

# Print "from<TAB>to" for every entry of one manifest section: project | seed | backbone
[positional-arguments]
_manifest file section:
    @awk -v s="[$2]" '/^\[/ {on=($0==s); next} on && !/^#/ && NF { n=split($0, a, / -> /); print a[1] "\t" (n>1 ? a[2] : a[1]) }' "$1"

# Print the Python that runs upstream.py. It reads TOML with tomllib, which came
# in Python 3.11, and a Mac's own python3 is 3.9. uv already keeps a newer one for
# prek and graphify, and finds it without downloading anything; python3 is the
# fallback, and upstream.py says plainly when that one is too old.
_py:
    @uv python find '>=3.11' --no-project --no-python-downloads 2>/dev/null || command -v python3 || echo python3

# The tools row of AGENTS.md section 0 (default: all)
_tools:
    @{ grep -E '^\| *tools *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | tr -d ' `'; } | grep . || echo all

# Exit 1 with a message when a rule copy or skill copy is out of date (used by the pre-commit hook)
_rules-check:
    #!/usr/bin/env bash
    tools=$(just _tools)
    has() { case ",$tools," in *,all,*|*,"$1",*) return 0 ;; *) return 1 ;; esac; }
    bad=0
    for pair in "copilot:.github/copilot-instructions.md" "junie:.junie/guidelines.md"; do
      t="${pair%%:*}"; f="${pair#*:}"
      if has "$t"; then
        if [ ! -f "$f" ] || ! tail -n +5 "$f" | diff -q - AGENTS.md >/dev/null 2>&1; then
          echo "$f is out of date. Run just sync-rules, then stage the result."; bad=1
        fi
      fi
    done
    if has claude; then
      for d in .agents/skills/*/; do
        [ -d "$d" ] || continue; n=$(basename "$d")
        { [ -d ".claude/skills/$n" ] && [ ! -L ".claude/skills/$n" ] && diff -r "$d" ".claude/skills/$n" >/dev/null 2>&1; } \
          || { echo ".claude/skills/$n is out of date. Run just sync-rules, then stage the result."; bad=1; }
      done
    fi
    exit $bad

# A limit accepted on purpose, so that a close reading does not report it as a
# bug. "English" is tested as "no letter outside ASCII", because that is what a
# line of shell can test: a language cannot be told from its letters. Turkish
# typed without its own letters ("fix: kayit ekrani duzeltildi") passes, an
# English word that carries one ("naïve") is refused, and arrows and other signs
# are not letters and pass (all three measured 2026-09-19). The check is here for
# one slip: an agent that talks Turkish with the maintainer writes the commit
# message in Turkish out of habit, and that arrives with ç ğ ı ş in it. The rule
# itself is AGENTS.md section 2, which the agent reads. Telling languages apart
# would take a word list or a detector: a dependency, for a rule already written.
#
# Used by the commit-msg hook: the first line is English and starts with its kind
[positional-arguments]
_commit-msg-check file:
    #!/usr/bin/env bash
    m=$(head -1 "$1")
    case "$m" in Merge\ *|Revert\ *|fixup!*|squash!*) exit 0 ;; esac
    if ! printf '%s' "$m" | grep -qE '^(feat|fix|docs|chore|test|refactor|style|perf|build|ci|revert)(\([^)]*\))?!?: '; then
      echo "Start the commit message with its kind: feat: fix: docs: chore: test: refactor: style:"
      echo "  (just save adds 'chore: ' for you when you leave it out)"; exit 1
    fi
    if ! printf '%s' "$m" | perl -CS -ne 'exit 1 if /(?=[^\x00-\x7F])\p{L}/'; then
      echo "Commit messages are English (code_lang in AGENTS.md). This one has letters like ç ğ ı ş."; exit 1
    fi

# Used by the lint hook: run `just lint` when the project has one.
# A project without a language layer has no lint recipe, and that is not a
# failure; the hook stays quiet until `just stack <lang>` gives it one.
_lint-if-any:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! just --summary 2>/dev/null | tr ' ' '\n' | grep -qx lint; then exit 0; fi
    just lint

# Used by the pre-push hook: run `just test` when the project has one. The same
# answer as `_lint-if-any`, for the same reason: a project with no language
# layer yet has no test recipe, and a hook that ran `just test` there refused
# every push with "justfile does not contain recipe" (spec 015 review).
_test-if-any:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! just --summary 2>/dev/null | tr ' ' '\n' | grep -qx test; then exit 0; fi
    just test

# Put the lint hook in .pre-commit-config.yaml unless it is already there.
# Called by new-project, adopt and stack. The config belongs to the project,
# so this only ever appends, and it undoes the append if prek cannot read the
# result.
_hook-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    f=.pre-commit-config.yaml
    if [ ! -f "$f" ]; then exit 0; fi
    if grep -q '_lint-if-any' "$f"; then exit 0; fi
    backup=$(mktemp); cp "$f" "$backup"
    printf '%s\n' \
      '' \
      '  # Whatever `just lint` runs in this project, before the commit. Without' \
      '  # it a save can leave behind code the language layer rejects, and CI or' \
      '  # the next agent finds it instead. Quiet until stack.just has a lint.' \
      '  - repo: local' \
      '    hooks:' \
      '      - id: lint' \
      '        name: just lint' \
      '        entry: just _lint-if-any' \
      '        language: system' \
      '        pass_filenames: false' \
      '        stages: [pre-commit]' \
      '        exclude: '"'"'(\.md$|^docs/)'"'"'' \
      >> "$f"
    if command -v prek >/dev/null 2>&1 && ! prek validate-config "$f" >/dev/null 2>&1; then
      cp "$backup" "$f"; rm -f "$backup"
      echo "Could not add the lint hook: $f did not survive the change. Nothing was written."
      exit 0
    fi
    rm -f "$backup"
    echo "Added the lint hook to $f: 'just lint' now runs before every commit."

# Put the workflow hook in .pre-commit-config.yaml unless it is already there.
# Called by ci-init. The config belongs to the project, so this only ever
# appends, and it undoes the append if prek cannot read the result.
_hook-ci:
    #!/usr/bin/env bash
    set -euo pipefail
    f=.pre-commit-config.yaml
    if [ ! -f "$f" ]; then exit 0; fi
    if grep -q 'id: ci-check' "$f"; then exit 0; fi
    backup=$(mktemp); cp "$f" "$backup"
    printf '%s\n' \
      '' \
      '  # The lessons in .github/workflows/ cost a day of red builds once. A' \
      '  # file that has dropped one says so here, on the commit, instead of on' \
      '  # a runner next month. Waive one in the workflow itself; just ci-check' \
      '  # prints the line to write.' \
      '  - repo: local' \
      '    hooks:' \
      '      - id: ci-check' \
      '        name: the checks still carry their lessons' \
      '        entry: just ci-check' \
      '        language: system' \
      '        pass_filenames: false' \
      '        stages: [pre-commit]' \
      '        files: '"'"'^\.github/workflows/.*\.(yml|yaml)$'"'"'' \
      >> "$f"
    if command -v prek >/dev/null 2>&1 && ! prek validate-config "$f" >/dev/null 2>&1; then
      cp "$backup" "$f"; rm -f "$backup"
      echo "Could not add the workflow hook: $f did not survive the change. Nothing was written."
      exit 0
    fi
    rm -f "$backup"
    echo "Added the workflow hook to $f: 'just ci-check' now runs before a commit that touches .github/workflows/."

# Print "yes" when .pre-commit-config.yaml has a hook for the pre-push stage,
# nothing otherwise. Comments are dropped first, so the commented example in the
# seed config does not count until somebody uncomments it. Read without a pipe
# into `grep -q`: grep leaves at the first match, and under pipefail the writer's
# SIGPIPE turns a yes into a no.
_push-stage:
    #!/usr/bin/env bash
    set -uo pipefail
    f=.pre-commit-config.yaml
    [ -f "$f" ] || exit 0
    body=$(sed -e 's/^[[:space:]]*#.*$//' -e 's/[[:space:]]#.*$//' "$f")
    if grep -qE '^[[:space:]]*(-[[:space:]]+)?(stages|default_stages|default_install_hook_types):.*pre-push|^[[:space:]]*-[[:space:]]+["'"'"']?pre-push["'"'"']?[[:space:]]*$' <<<"$body"; then echo yes; fi

# The readable part of a failed job's log, read from stdin. Its own recipe so
# that the self-test can feed it a real log and check what comes out: it is the
# one piece of `just ci` that can rot silently, because every format it takes
# apart is GitHub's to change.
_ci-lines:
    #!/usr/bin/env bash
    set -uo pipefail
    clean=$(mktemp); trap 'rm -f "$clean"' EXIT
    # gh hands back three tab-separated columns — job, step, line — and the line
    # itself begins with an ISO timestamp. The first line of a log carries a
    # byte-order mark. Colour arrives as the two literal characters ^ and [ ,
    # because gh sanitises escapes when its output is not a terminal, and no
    # terminal renders them: 1940 of one real job's 2667 lines carried one.
    LC_ALL=C sed 's/\r$//' | cut -f3- \
      | LC_ALL=C sed -E -e $'1s/^\xEF\xBB\xBF//' \
            -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z ?//' \
            -e 's/\^\[\[[0-9;]*m//g' \
            -e 's/^##\[(group|endgroup)\]//' \
      | cat -s > "$clean"
    # GitHub marks the failure itself with ##[error]; everything after it is the
    # runner tidying up, so the last fifteen lines of a failed job are `git
    # version` and `Cleaning up orphan processes` and say nothing about why it
    # failed. A job that was cancelled, timed out or killed while setting up
    # leaves no marker, and then the end of the log is the best there is.
    n=$(grep -n '##\[error\]' "$clean" | tail -1 | cut -d: -f1)
    if [ -n "$n" ]; then
      start=$((n-18)); [ "$start" -lt 1 ] && start=1
      sed -n "${start},${n}p" "$clean"
    else
      tail -20 "$clean"
    fi

# Why a failed job with no step and no log never started, read from stdin: the
# answer of GitHub's check-run annotations, of which the first `failure` one
# carries the reason. Its first sentence is printed; the rest tells the reader
# where to click. Its own recipe for the reason `_ci-lines` is one: the format
# is GitHub's to change, and the self-test feeds it a real answer. Any python3
# will do, a Mac's own 3.9 too — json only. Nothing to read, nothing that
# parses, no python3 at all: silent and exit 0, and `just ci` falls back to the
# line it always printed.
_ci-why:
    #!/usr/bin/env bash
    set -uo pipefail
    python3 -c 'import json, sys
    for a in json.load(sys.stdin):
        if a.get("annotation_level") == "failure":
            print(a.get("message", "").split(". ")[0]); break' 2>/dev/null || true

# Print "yes" when the repo holds program code worth a map, nothing otherwise.
# The list is the languages an app is written in, and on purpose not graphify's
# own: that one (CODE_EXTENSIONS in its detect.py, 102 entries on 0.9.64) counts
# .json and .sh, and every new project has both on the day it is made.
# Dart joined with spec 013. graphify reads it (measured on 0.9.64: swap-smash's
# three Dart files give 6 nodes, and 6 more for what they import), and a Flutter
# project was told "yes" only because of the Swift and Kotlin runner shims
# `flutter create` writes.
# A static site or a schema-only repo has no code to map, and that is normal.
# The reasons, measured on 0.9.64 because the old comment had one of them
# wrong: HTML is a document to graphify and `--code-only` skips it, CSS is not
# read at all, and .sql is on the list but its parser is an extra
# (graphifyy[sql]) that `uv tool install graphifyy` does not bring, so a tree of
# SQL alone ends in "graph is empty" and exit 1.
# `.ai-backbone/` is left out with brain/ and the rest: its upstream.py is the
# backbone's own plumbing, and counting it told every brand-new project, on the
# day it was made, that it had code and no map of it.
_has-code:
    #!/usr/bin/env bash
    find . -type f \
      \( -name '*.rs' -o -name '*.swift' -o -name '*.kt' -o -name '*.dart' -o -name '*.ts' -o -name '*.tsx' \
         -o -name '*.mts' -o -name '*.cts' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \
         -o -name '*.cjs' -o -name '*.py' -o -name '*.pyi' -o -name '*.go' -o -name '*.java' \
         -o -name '*.scala' -o -name '*.rb' -o -name '*.rake' -o -name '*.php' -o -name '*.lua' \
         -o -name '*.cs' -o -name '*.c' -o -name '*.h' -o -name '*.cpp' -o -name '*.cc' \
         -o -name '*.cxx' -o -name '*.hpp' -o -name '*.hh' -o -name '*.hxx' -o -name '*.m' \
         -o -name '*.mm' -o -name '*.metal' -o -name '*.cu' -o -name '*.cuh' \) \
      -not -path './brain/*' -not -path './.references/*' -not -path './.archive/*' \
      -not -path './.ai-backbone/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q . && echo yes || true

# Turn a name into a file-safe slug: "Yapılacaklar Listesi" -> yapilacaklar-listesi
[positional-arguments]
_slug text:
    @printf '%s' "$1" | perl -CS -Mutf8 -pe 'tr/çğıöşüÇĞİÖŞÜ/cgiosucgiosu/; $_=lc; s/[^a-z0-9]+/-/g; s/^-+|-+$//g'

# Replace BRAIN_LANG in a file with brain_lang from AGENTS.md section 0 (default: en)
[positional-arguments]
_stamp-brain-lang file:
    #!/usr/bin/env bash
    set -euo pipefail
    lang=$(grep -E '^\| *brain_lang *\|' AGENTS.md 2>/dev/null | awk -F'|' '{print $3}' | tr -d ' `' || true)
    lang="${lang:-en}"
    if [ -f "$1" ] && grep -q BRAIN_LANG "$1"; then
      tmp=$(mktemp); sed "s/BRAIN_LANG/$lang/g" "$1" > "$tmp"; mv "$tmp" "$1"
    fi
